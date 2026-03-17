#!/usr/bin/env python3
"""
SRT 字幕转语音脚本 v2
====================
读取 SRT 字幕文件，使用 edge-tts 逐条生成语音，
自动调整语速使音频时长匹配字幕时间窗口，
最终用 ffmpeg 拼装输出完整的、与字幕时间表对齐的音频文件。

v2 改进:
  - 分块拼装，避免内存溢出 (OOM)
  - 多线程并发生成 + 指数退避重试，提高成功率
  - 失败条目二次重试
  - 实时进度显示

用法:
    python3 srt_to_speech.py input.srt -o output.mp3
    python3 srt_to_speech.py input.srt -o output.mp3 -v zh-CN-YunxiNeural
    python3 srt_to_speech.py input.srt -o output.mp3 -v zh-CN-XiaoxiaoNeural -c 8

依赖:
    pip install edge-tts pysrt pydub
    apt install ffmpeg
"""

import asyncio
import argparse
import os
import sys
import shutil
import tempfile
import subprocess
import time
import json
from pathlib import Path

try:
    import pysrt
except ImportError:
    print("错误: 缺少 pysrt 库，请运行: pip install pysrt", file=sys.stderr)
    sys.exit(1)

try:
    import edge_tts
except ImportError:
    print("错误: 缺少 edge-tts 库，请运行: pip install edge-tts", file=sys.stderr)
    sys.exit(1)

try:
    from pydub import AudioSegment
except ImportError:
    print("错误: 缺少 pydub 库，请运行: pip install pydub", file=sys.stderr)
    sys.exit(1)


# ============================================================
# 工具函数
# ============================================================

def srt_time_to_ms(srt_time) -> int:
    """将 pysrt 的时间对象转换为毫秒。"""
    return (srt_time.hours * 3600 + srt_time.minutes * 60 +
            srt_time.seconds) * 1000 + srt_time.milliseconds


def format_duration(ms: int) -> str:
    """将毫秒格式化为可读的时间字符串。"""
    if ms < 0:
        return "0.0s"
    s = ms / 1000
    if s < 60:
        return f"{s:.1f}s"
    m = int(s // 60)
    s = s % 60
    if m < 60:
        return f"{m}m{s:.1f}s"
    h = m // 60
    m = m % 60
    return f"{h}h{m}m{s:.0f}s"


def get_audio_duration_ms(audio_path: str) -> int:
    """使用 ffprobe 获取音频时长（毫秒），比 pydub 更省内存。"""
    try:
        result = subprocess.run(
            ["ffprobe", "-v", "quiet", "-show_entries",
             "format=duration", "-of", "csv=p=0", audio_path],
            capture_output=True, text=True, timeout=10
        )
        duration_sec = float(result.stdout.strip())
        return int(duration_sec * 1000)
    except Exception:
        # fallback 到 pydub
        audio = AudioSegment.from_file(audio_path)
        duration = len(audio)
        del audio
        return duration


def calculate_rate_percent(actual_ms: int, target_ms: int) -> int:
    """
    计算需要的语速百分比调整。
    edge-tts 的 rate 参数范围大约是 -50% 到 +200%
    """
    if target_ms <= 0 or actual_ms <= 0:
        return 0
    ratio = actual_ms / target_ms
    rate = int((ratio - 1) * 100)
    rate = max(-50, min(200, rate))
    return rate


class ProgressTracker:
    """线程安全的进度跟踪器。"""
    def __init__(self, total: int, label: str = "进度"):
        self.total = total
        self.label = label
        self.done = 0
        self.success = 0
        self.failed = 0
        self._lock = asyncio.Lock()
        self._start_time = time.time()

    async def update(self, is_success: bool):
        async with self._lock:
            self.done += 1
            if is_success:
                self.success += 1
            else:
                self.failed += 1
            self._print_progress()

    def _print_progress(self):
        elapsed = time.time() - self._start_time
        pct = (self.done / self.total) * 100
        rate = self.done / elapsed if elapsed > 0 else 0
        eta = (self.total - self.done) / rate if rate > 0 else 0

        bar_len = 30
        filled = int(bar_len * self.done / self.total)
        bar = "█" * filled + "░" * (bar_len - filled)

        print(
            f"\r  {self.label} |{bar}| {self.done}/{self.total} "
            f"({pct:.0f}%) ✓{self.success} ✗{self.failed} "
            f"ETA:{format_duration(int(eta*1000))}   ",
            end="", flush=True
        )
        if self.done == self.total:
            print()  # 换行


# ============================================================
# 核心 TTS 生成
# ============================================================

async def generate_single_tts(
    text: str,
    output_path: str,
    voice: str,
    rate: str = "+0%",
    volume: str = "+0%",
    pitch: str = "+0Hz",
    retries: int = 3,
    backoff_base: float = 2.0,
) -> bool:
    """
    使用 edge-tts 生成单条语音，带指数退避重试。
    """
    for attempt in range(retries + 1):
        try:
            communicate = edge_tts.Communicate(
                text=text,
                voice=voice,
                rate=rate,
                volume=volume,
                pitch=pitch,
            )
            await communicate.save(output_path)
            # 验证文件有效
            if os.path.exists(output_path) and os.path.getsize(output_path) > 100:
                return True
        except Exception:
            pass

        if attempt < retries:
            wait = backoff_base ** attempt + (asyncio.get_event_loop().time() % 1)
            await asyncio.sleep(wait)

    return False


async def generate_tts_with_rate_fit(
    text: str,
    target_duration_ms: int,
    output_path: str,
    voice: str,
    volume: str = "+0%",
    pitch: str = "+0Hz",
    max_rate_retries: int = 2,
    tolerance: float = 0.15,
    tts_retries: int = 3,
) -> bool:
    """
    生成语音并调整语速以适配目标时长。
    max_rate_retries: 语速调整的重试次数（不含首次）
    tts_retries: 每次 TTS 调用的网络重试次数
    """
    rate_str = "+0%"

    for attempt in range(max_rate_retries + 1):
        success = await generate_single_tts(
            text=text,
            output_path=output_path,
            voice=voice,
            rate=rate_str,
            volume=volume,
            pitch=pitch,
            retries=tts_retries,
        )

        if not success:
            return False

        actual_ms = get_audio_duration_ms(output_path)
        if target_duration_ms <= 0:
            return True

        diff_ratio = abs(actual_ms - target_duration_ms) / target_duration_ms

        if diff_ratio <= tolerance:
            return True

        if attempt == max_rate_retries:
            return True  # 用当前结果

        # 计算新语速
        rate_percent = calculate_rate_percent(actual_ms, target_duration_ms)
        rate_str = f"+{rate_percent}%" if rate_percent >= 0 else f"{rate_percent}%"

    return True


# ============================================================
# 分块拼装（解决 OOM）
# ============================================================

CHUNK_DURATION_MS = 30_000  # 每块 30 秒

def assemble_audio_chunked(
    segments: list,
    total_duration_ms: int,
    output_path: str,
    tmp_dir: str,
):
    """
    分块拼装音频，避免内存溢出。

    将总时长切分为 30 秒的块，每块独立处理后用 ffmpeg concat 拼接。
    内存占用从 O(总时长) 降为 O(30秒)。
    """
    # 按 start_ms 排序
    segments_sorted = sorted(segments, key=lambda s: s["start_ms"])

    chunk_dir = os.path.join(tmp_dir, "chunks")
    os.makedirs(chunk_dir, exist_ok=True)

    chunk_files = []
    total_chunks = (total_duration_ms + CHUNK_DURATION_MS - 1) // CHUNK_DURATION_MS

    print(f"  分为 {total_chunks} 个块处理 (每块 {CHUNK_DURATION_MS//1000}s)")

    # 预处理: 为每个 chunk 找到涉及的 segments
    # 用指针避免每个 chunk 都遍历全部 segments
    seg_idx_start = 0

    for chunk_num in range(total_chunks):
        chunk_start = chunk_num * CHUNK_DURATION_MS
        chunk_end = min(chunk_start + CHUNK_DURATION_MS, total_duration_ms)
        chunk_duration = chunk_end - chunk_start

        # 创建静音块
        chunk_audio = AudioSegment.silent(duration=chunk_duration, frame_rate=24000)

        # 找到与此块有交集的 segments
        overlapping = 0
        for i in range(seg_idx_start, len(segments_sorted)):
            seg = segments_sorted[i]
            seg_start = seg["start_ms"]
            seg_end = seg["end_ms"]

            # segment 完全在此块之前 → 下次从这里开始
            if seg_end <= chunk_start:
                seg_idx_start = i + 1
                continue

            # segment 完全在此块之后 → 此块处理完毕
            if seg_start >= chunk_end:
                break

            # 有交集 → overlay
            audio_path = seg["audio_path"]
            if not os.path.exists(audio_path):
                continue

            try:
                clip = AudioSegment.from_file(audio_path)

                # 如果 segment 从当前块之前就开始了，裁掉前面部分
                clip_offset = 0
                if seg_start < chunk_start:
                    clip_offset = chunk_start - seg_start
                    clip = clip[clip_offset:]

                # 在块中的位置
                position_in_chunk = max(0, seg_start - chunk_start)

                # 裁掉超出块尾的部分
                remaining = chunk_duration - position_in_chunk
                if len(clip) > remaining:
                    clip = clip[:remaining]

                # 裁掉超出字幕窗口的部分
                target_ms = seg_end - seg_start - clip_offset
                if len(clip) > target_ms:
                    clip = clip[:target_ms]

                chunk_audio = chunk_audio.overlay(clip, position=position_in_chunk)
                overlapping += 1
                del clip
            except Exception as e:
                print(f"\n  ⚠ 加载片段失败 {audio_path}: {e}")

        # 导出此块
        chunk_path = os.path.join(chunk_dir, f"chunk_{chunk_num:05d}.mp3")
        chunk_audio.export(chunk_path, format="mp3", bitrate="192k")
        chunk_files.append(chunk_path)
        del chunk_audio

        # 进度
        pct = (chunk_num + 1) / total_chunks * 100
        print(f"\r  拼装进度: {chunk_num+1}/{total_chunks} ({pct:.0f}%) "
              f"[本块含 {overlapping} 个片段]   ", end="", flush=True)

    print()  # 换行

    # 用 ffmpeg concat 拼接所有块
    print(f"  正在用 ffmpeg 拼接 {len(chunk_files)} 个块...")
    list_file = os.path.join(chunk_dir, "concat_list.txt")
    with open(list_file, "w") as f:
        for cf in chunk_files:
            f.write(f"file '{cf}'\n")

    result = subprocess.run(
        ["ffmpeg", "-y", "-f", "concat", "-safe", "0",
         "-i", list_file, "-c", "copy", output_path],
        capture_output=True, text=True
    )

    if result.returncode != 0:
        print(f"  ⚠ ffmpeg concat 错误: {result.stderr[:500]}")
        # fallback: 用 ffmpeg 重新编码
        subprocess.run(
            ["ffmpeg", "-y", "-f", "concat", "-safe", "0",
             "-i", list_file, "-b:a", "192k", output_path],
            capture_output=True, text=True
        )


# ============================================================
# 主流程
# ============================================================

async def process_srt(
    srt_path: str,
    output_path: str,
    voice: str,
    volume: str = "+0%",
    pitch: str = "+0Hz",
    max_retries: int = 2,
    tolerance: float = 0.15,
    concurrency: int = 5,
    tts_retries: int = 3,
):
    """处理完整的 SRT 文件。"""

    # 1. 解析 SRT
    print(f"📂 正在解析字幕文件: {srt_path}")
    subs = pysrt.open(srt_path, encoding="utf-8")

    if not subs:
        print("错误: 字幕文件为空或格式不正确！", file=sys.stderr)
        return False

    print(f"📝 共 {len(subs)} 条字幕")

    # 计算总时长
    total_duration_ms = srt_time_to_ms(subs[-1].end) + 500
    print(f"⏱ 总时长: {format_duration(total_duration_ms)}")

    # 2. 创建临时目录
    tmp_dir = tempfile.mkdtemp(prefix="srt_tts_")
    print(f"📁 临时目录: {tmp_dir}")

    # 准备所有任务数据
    all_tasks = []
    for idx, sub in enumerate(subs):
        text = sub.text.replace("\n", " ").strip()
        if not text:
            continue
        start_ms = srt_time_to_ms(sub.start)
        end_ms = srt_time_to_ms(sub.end)
        target_ms = end_ms - start_ms
        audio_file = os.path.join(tmp_dir, f"seg_{idx:05d}.mp3")
        all_tasks.append({
            "idx": idx,
            "text": text,
            "start_ms": start_ms,
            "end_ms": end_ms,
            "target_ms": target_ms,
            "audio_path": audio_file,
        })

    total_tasks = len(all_tasks)
    print(f"📋 有效字幕条目: {total_tasks}")

    # ──────────────────────────────────────────
    # 3. 第一轮: 并发生成
    # ──────────────────────────────────────────
    print(f"\n🎙 第一轮生成（并发={concurrency}, 网络重试={tts_retries}）...")
    semaphore = asyncio.Semaphore(concurrency)
    progress = ProgressTracker(total_tasks, "生成")

    segments = []
    failed_tasks = []

    async def process_one(task_info):
        async with semaphore:
            success = await generate_tts_with_rate_fit(
                text=task_info["text"],
                target_duration_ms=task_info["target_ms"],
                output_path=task_info["audio_path"],
                voice=voice,
                volume=volume,
                pitch=pitch,
                max_rate_retries=max_retries,
                tolerance=tolerance,
                tts_retries=tts_retries,
            )

            ok = success and os.path.exists(task_info["audio_path"])
            await progress.update(ok)
            return task_info, ok

    results = await asyncio.gather(
        *[process_one(t) for t in all_tasks],
        return_exceptions=True
    )

    for r in results:
        if isinstance(r, Exception):
            continue
        task_info, ok = r
        if ok:
            segments.append({
                "start_ms": task_info["start_ms"],
                "end_ms": task_info["end_ms"],
                "audio_path": task_info["audio_path"],
            })
        else:
            failed_tasks.append(task_info)

    print(f"\n  第一轮结果: ✓{len(segments)} ✗{len(failed_tasks)}")

    # ──────────────────────────────────────────
    # 4. 第二轮: 重试失败的条目
    # ──────────────────────────────────────────
    if failed_tasks:
        print(f"\n🔄 第二轮重试 {len(failed_tasks)} 条失败条目（降低并发=2, 增加重试=5）...")
        semaphore2 = asyncio.Semaphore(2)  # 降低并发
        progress2 = ProgressTracker(len(failed_tasks), "重试")

        still_failed = []

        async def retry_one(task_info):
            async with semaphore2:
                # 增加等待，避免限速
                await asyncio.sleep(1.0)

                success = await generate_tts_with_rate_fit(
                    text=task_info["text"],
                    target_duration_ms=task_info["target_ms"],
                    output_path=task_info["audio_path"],
                    voice=voice,
                    volume=volume,
                    pitch=pitch,
                    max_rate_retries=1,
                    tolerance=tolerance,
                    tts_retries=5,  # 更多重试
                )

                ok = success and os.path.exists(task_info["audio_path"])
                await progress2.update(ok)
                return task_info, ok

        retry_results = await asyncio.gather(
            *[retry_one(t) for t in failed_tasks],
            return_exceptions=True
        )

        recovered = 0
        for r in retry_results:
            if isinstance(r, Exception):
                continue
            task_info, ok = r
            if ok:
                segments.append({
                    "start_ms": task_info["start_ms"],
                    "end_ms": task_info["end_ms"],
                    "audio_path": task_info["audio_path"],
                })
                recovered += 1
            else:
                still_failed.append(task_info)

        print(f"\n  第二轮结果: 恢复 {recovered} 条, 仍失败 {len(still_failed)} 条")

        # 保存失败列表到文件
        if still_failed:
            fail_log = os.path.join(os.path.dirname(output_path) or ".", "failed_segments.json")
            with open(fail_log, "w", encoding="utf-8") as f:
                json.dump(
                    [{"idx": t["idx"], "text": t["text"][:50],
                      "time": f"{format_duration(t['start_ms'])}→{format_duration(t['end_ms'])}"}
                     for t in still_failed],
                    f, ensure_ascii=False, indent=2
                )
            print(f"  💾 失败清单已保存到: {fail_log}")

    print(f"\n{'='*60}")
    print(f"✅ 最终成功: {len(segments)}/{total_tasks} 条语音片段")

    if not segments:
        print("错误: 没有成功生成任何语音片段！", file=sys.stderr)
        shutil.rmtree(tmp_dir, ignore_errors=True)
        return False

    # ──────────────────────────────────────────
    # 5. 分块拼装
    # ──────────────────────────────────────────
    print(f"\n🔧 正在拼装最终音频（分块模式，避免内存溢出）...")
    try:
        assemble_audio_chunked(
            segments=segments,
            total_duration_ms=total_duration_ms,
            output_path=output_path,
            tmp_dir=tmp_dir,
        )
    except Exception as e:
        print(f"\n❌ 拼装失败: {e}", file=sys.stderr)
        print(f"   临时文件保留在: {tmp_dir}", file=sys.stderr)
        return False

    output_size = os.path.getsize(output_path)
    print(f"\n🎉 完成！输出文件: {output_path}")
    print(f"   文件大小: {output_size / 1024 / 1024:.1f} MB")
    print(f"   总时长: {format_duration(total_duration_ms)}")
    print(f"   成功率: {len(segments)}/{total_tasks} ({len(segments)/total_tasks*100:.1f}%)")

    # 清理
    shutil.rmtree(tmp_dir, ignore_errors=True)
    print(f"🧹 已清理临时文件")
    return True


async def list_voices(language: str = None):
    """列出可用的声音。"""
    voices = await edge_tts.list_voices()

    if language:
        voices = [v for v in voices if v["Locale"].startswith(language)]

    print(f"\n可用声音列表" + (f" (语言: {language})" if language else "") + ":")
    print(f"{'='*70}")
    print(f"{'ShortName':<35} {'性别':<8} {'语言':<10}")
    print(f"{'-'*70}")

    for v in voices:
        gender = "女" if v["Gender"] == "Female" else "男"
        print(f"{v['ShortName']:<35} {gender:<8} {v['Locale']:<10}")

    print(f"\n共 {len(voices)} 个声音")


def main():
    parser = argparse.ArgumentParser(
        description="SRT 字幕转语音 v2 — 使用 edge-tts 生成与字幕时间表对齐的音频",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
示例:
  # 基本用法（默认使用中文男声 YunxiNeural）
  python3 srt_to_speech.py subtitles.srt -o output.mp3

  # 指定声音
  python3 srt_to_speech.py subtitles.srt -o output.mp3 -v zh-CN-XiaoxiaoNeural

  # 增大并发（推荐 5~8，过高会被限速）
  python3 srt_to_speech.py subtitles.srt -o output.mp3 -c 8

  # 列出所有中文声音
  python3 srt_to_speech.py --list-voices zh-CN
        """,
    )

    parser.add_argument("srt_file", nargs="?", help="输入的 SRT 字幕文件路径")
    parser.add_argument("-o", "--output", default="output.mp3",
                        help="输出音频文件路径（默认: output.mp3）")
    parser.add_argument("-v", "--voice", default="zh-CN-YunxiNeural",
                        help="TTS 声音名称（默认: zh-CN-YunxiNeural）")
    parser.add_argument("-c", "--concurrency", type=int, default=5,
                        help="并发请求数（默认: 5, 推荐 3~8）")
    parser.add_argument("--volume", default="+0%",
                        help="音量调整（默认: +0%%）")
    parser.add_argument("--pitch", default="+0Hz",
                        help="音调调整（默认: +0Hz）")
    parser.add_argument("--max-retries", type=int, default=2,
                        help="每条字幕的语速调整重试次数（默认: 2）")
    parser.add_argument("--tts-retries", type=int, default=3,
                        help="每次 TTS 调用的网络重试次数（默认: 3）")
    parser.add_argument("--tolerance", type=float, default=0.15,
                        help="允许的时长误差比例, 0.15=15%%（默认: 0.15）")
    parser.add_argument("--list-voices", nargs="?", const="", default=None,
                        metavar="LANGUAGE",
                        help="列出可用声音（可选指定语言代码，如 zh-CN, en-US）")

    args = parser.parse_args()

    # 列出声音模式
    if args.list_voices is not None:
        lang = args.list_voices if args.list_voices else None
        asyncio.run(list_voices(lang))
        return

    # 检查输入文件
    if not args.srt_file:
        parser.error("请指定 SRT 字幕文件路径")

    if not os.path.exists(args.srt_file):
        print(f"错误: 文件不存在: {args.srt_file}", file=sys.stderr)
        sys.exit(1)

    # 检查 ffmpeg
    if not shutil.which("ffmpeg"):
        print("错误: 未安装 ffmpeg，请运行: sudo apt install ffmpeg", file=sys.stderr)
        sys.exit(1)

    print(f"""
╔══════════════════════════════════════════════════════════╗
║          SRT 字幕转语音 v2 (edge-tts)                   ║
╚══════════════════════════════════════════════════════════╝

  输入文件:     {args.srt_file}
  输出文件:     {args.output}
  声音:         {args.voice}
  并发数:       {args.concurrency}
  音量/音调:    {args.volume} / {args.pitch}
  语速调整:     最多 {args.max_retries} 次, 容差 {args.tolerance*100:.0f}%
  网络重试:     {args.tts_retries} 次 (指数退避)
""")

    success = asyncio.run(
        process_srt(
            srt_path=args.srt_file,
            output_path=args.output,
            voice=args.voice,
            volume=args.volume,
            pitch=args.pitch,
            max_retries=args.max_retries,
            tolerance=args.tolerance,
            concurrency=args.concurrency,
            tts_retries=args.tts_retries,
        )
    )

    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
