#!/usr/bin/env python3
"""
SRT 字幕转语音 — Web UI 版本
============================
Flask Web 服务器，提供上传 SRT、配置参数、实时进度、下载结果的功能。
依赖 srt_to_speech.py 中的核心 TTS 函数。

用法:
    python3 web_srt_tts.py
    python3 web_srt_tts.py --port 8080 --host 0.0.0.0
"""

import asyncio
import argparse
import json
import os
import shutil
import subprocess
import tempfile
import threading
import time
import uuid

import edge_tts
import pysrt
from pydub import AudioSegment
from flask import Flask, request, jsonify, send_file, Response, make_response

# ============================================================
# 配置
# ============================================================

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
UPLOAD_DIR = os.path.join(BASE_DIR, "uploads")
OUTPUT_DIR = os.path.join(BASE_DIR, "output")
os.makedirs(UPLOAD_DIR, exist_ok=True)
os.makedirs(OUTPUT_DIR, exist_ok=True)

CHUNK_DURATION_MS = 30_000

app = Flask(__name__)
app.config["MAX_CONTENT_LENGTH"] = 32 * 1024 * 1024  # 32 MB

# ============================================================
# 任务存储
# ============================================================

tasks = {}

def update_task(task_id, **kwargs):
    if task_id in tasks:
        tasks[task_id].update(kwargs)

def update_progress(task_id, **kwargs):
    if task_id in tasks:
        tasks[task_id]["progress"].update(kwargs)

# ============================================================
# 核心工具函数
# ============================================================

def srt_time_to_ms(t):
    return (t.hours * 3600 + t.minutes * 60 + t.seconds) * 1000 + t.milliseconds

def format_duration(ms):
    if ms < 0: return "0s"
    s = ms / 1000
    if s < 60: return f"{s:.1f}s"
    m = int(s // 60); s %= 60
    if m < 60: return f"{m}m{s:.0f}s"
    h = m // 60; m %= 60
    return f"{h}h{m}m"

def get_audio_duration_ms(path):
    try:
        r = subprocess.run(
            ["ffprobe", "-v", "quiet", "-show_entries", "format=duration",
             "-of", "csv=p=0", path],
            capture_output=True, text=True, timeout=10,
        )
        return int(float(r.stdout.strip()) * 1000)
    except Exception:
        a = AudioSegment.from_file(path)
        d = len(a); del a; return d

def calculate_rate_percent(actual_ms, target_ms):
    if target_ms <= 0 or actual_ms <= 0: return 0
    return max(-50, min(200, int((actual_ms / target_ms - 1) * 100)))

# ============================================================
# TTS 生成
# ============================================================

async def generate_single_tts(text, output_path, voice, rate="+0%",
                               volume="+0%", pitch="+0Hz", retries=3):
    for attempt in range(retries + 1):
        try:
            c = edge_tts.Communicate(text=text, voice=voice,
                                     rate=rate, volume=volume, pitch=pitch)
            await c.save(output_path)
            if os.path.exists(output_path) and os.path.getsize(output_path) > 100:
                return True
        except Exception:
            pass
        if attempt < retries:
            await asyncio.sleep(2 ** attempt + (time.time() % 1))
    return False

async def generate_tts_with_rate_fit(text, target_ms, output_path, voice,
                                      volume="+0%", pitch="+0Hz",
                                      max_rate_retries=2, tolerance=0.15,
                                      tts_retries=3):
    rate_str = "+0%"
    for attempt in range(max_rate_retries + 1):
        ok = await generate_single_tts(text, output_path, voice,
                                        rate=rate_str, volume=volume,
                                        pitch=pitch, retries=tts_retries)
        if not ok: return False
        if target_ms <= 0: return True
        actual = get_audio_duration_ms(output_path)
        if abs(actual - target_ms) / target_ms <= tolerance: return True
        if attempt == max_rate_retries: return True
        rp = calculate_rate_percent(actual, target_ms)
        rate_str = f"+{rp}%" if rp >= 0 else f"{rp}%"
    return True

# ============================================================
# 分块拼装
# ============================================================

def assemble_audio_chunked(segments, total_duration_ms, output_path, tmp_dir,
                            task_id=None):
    segments_sorted = sorted(segments, key=lambda s: s["start_ms"])
    chunk_dir = os.path.join(tmp_dir, "chunks")
    os.makedirs(chunk_dir, exist_ok=True)
    total_chunks = (total_duration_ms + CHUNK_DURATION_MS - 1) // CHUNK_DURATION_MS
    chunk_files = []
    seg_idx_start = 0

    for cn in range(total_chunks):
        cs = cn * CHUNK_DURATION_MS
        ce = min(cs + CHUNK_DURATION_MS, total_duration_ms)
        chunk = AudioSegment.silent(duration=ce - cs, frame_rate=24000)

        for i in range(seg_idx_start, len(segments_sorted)):
            seg = segments_sorted[i]
            if seg["end_ms"] <= cs:
                seg_idx_start = i + 1; continue
            if seg["start_ms"] >= ce: break
            if not os.path.exists(seg["audio_path"]): continue
            try:
                clip = AudioSegment.from_file(seg["audio_path"])
                clip_off = 0
                if seg["start_ms"] < cs:
                    clip_off = cs - seg["start_ms"]
                    clip = clip[clip_off:]
                pos = max(0, seg["start_ms"] - cs)
                rem = (ce - cs) - pos
                if len(clip) > rem: clip = clip[:rem]
                tw = seg["end_ms"] - seg["start_ms"] - clip_off
                if len(clip) > tw: clip = clip[:tw]
                chunk = chunk.overlay(clip, position=pos)
                del clip
            except Exception:
                pass

        cp = os.path.join(chunk_dir, f"chunk_{cn:05d}.mp3")
        chunk.export(cp, format="mp3", bitrate="192k")
        chunk_files.append(cp)
        del chunk
        if task_id:
            update_progress(task_id,
                            message=f"拼装中 {cn+1}/{total_chunks}",
                            percent=int((cn + 1) / total_chunks * 100))

    lf = os.path.join(chunk_dir, "list.txt")
    with open(lf, "w") as f:
        for c in chunk_files:
            f.write(f"file '{c}'\n")
    subprocess.run(["ffmpeg", "-y", "-f", "concat", "-safe", "0",
                     "-i", lf, "-c", "copy", output_path],
                    capture_output=True)

# ============================================================
# Web 版后台处理
# ============================================================

async def process_srt_web(task_id, srt_path, output_path, params):
    task = tasks[task_id]
    voice = params["voice"]
    concurrency = params.get("concurrency", 5)
    volume = params.get("volume", "+0%")
    pitch = params.get("pitch", "+0Hz")
    tolerance = params.get("tolerance", 0.15)
    max_retries = params.get("max_retries", 2)
    tts_retries = params.get("tts_retries", 3)

    subs = pysrt.open(srt_path, encoding="utf-8")
    if not subs:
        update_task(task_id, status="error", error="字幕文件为空或格式不正确")
        return

    total_duration_ms = srt_time_to_ms(subs[-1].end) + 500
    tmp_dir = tempfile.mkdtemp(prefix="srt_web_")

    # 准备任务列表
    all_items = []
    for idx, sub in enumerate(subs):
        text = sub.text.replace("\n", " ").strip()
        if not text: continue
        sm = srt_time_to_ms(sub.start)
        em = srt_time_to_ms(sub.end)
        all_items.append({
            "idx": idx, "text": text, "start_ms": sm, "end_ms": em,
            "target_ms": em - sm,
            "audio_path": os.path.join(tmp_dir, f"seg_{idx:05d}.mp3"),
        })

    total = len(all_items)
    update_progress(task_id, phase="generating", total=total, done=0,
                    success=0, failed=0, percent=0,
                    message=f"开始生成 {total} 条语音...")

    # ── 第一轮 ──
    sem = asyncio.Semaphore(concurrency)
    done_count = [0, 0, 0]  # done, success, failed

    async def gen_one(item):
        async with sem:
            ok = await generate_tts_with_rate_fit(
                item["text"], item["target_ms"], item["audio_path"],
                voice, volume, pitch, max_retries, tolerance, tts_retries)
            ok = ok and os.path.exists(item["audio_path"])
            done_count[0] += 1
            done_count[1 if ok else 2] += 1
            pct = int(done_count[0] / total * 100)
            update_progress(task_id, done=done_count[0], success=done_count[1],
                            failed=done_count[2], percent=pct,
                            message=f"第一轮 {done_count[0]}/{total}")
            return item, ok

    results = await asyncio.gather(*[gen_one(it) for it in all_items],
                                    return_exceptions=True)
    segments = []
    failed = []
    for r in results:
        if isinstance(r, Exception): continue
        item, ok = r
        if ok:
            segments.append({"start_ms": item["start_ms"], "end_ms": item["end_ms"],
                             "audio_path": item["audio_path"]})
        else:
            failed.append(item)

    # ── 第二轮重试 ──
    if failed:
        update_progress(task_id, phase="retrying",
                        message=f"第二轮重试 {len(failed)} 条...")
        sem2 = asyncio.Semaphore(2)
        retry_done = [0, 0]  # recovered, still_failed

        async def retry_one(item):
            async with sem2:
                await asyncio.sleep(1.0)
                ok = await generate_tts_with_rate_fit(
                    item["text"], item["target_ms"], item["audio_path"],
                    voice, volume, pitch, 1, tolerance, 5)
                ok = ok and os.path.exists(item["audio_path"])
                retry_done[0 if ok else 1] += 1
                update_progress(task_id,
                    message=f"重试中 {sum(retry_done)}/{len(failed)}")
                return item, ok

        retry_results = await asyncio.gather(*[retry_one(it) for it in failed],
                                              return_exceptions=True)
        still_failed = []
        for r in retry_results:
            if isinstance(r, Exception): continue
            item, ok = r
            if ok:
                segments.append({"start_ms": item["start_ms"], "end_ms": item["end_ms"],
                                 "audio_path": item["audio_path"]})
            else:
                still_failed.append(item)
        failed = still_failed

    if not segments:
        update_task(task_id, status="error", error="没有成功生成任何语音片段")
        shutil.rmtree(tmp_dir, ignore_errors=True)
        return

    # ── 拼装 ──
    update_progress(task_id, phase="assembling", percent=0,
                    message="正在拼装音频...")
    try:
        assemble_audio_chunked(segments, total_duration_ms, output_path,
                                tmp_dir, task_id)
    except Exception as e:
        update_task(task_id, status="error", error=f"拼装失败: {e}")
        shutil.rmtree(tmp_dir, ignore_errors=True)
        return

    file_size = os.path.getsize(output_path) if os.path.exists(output_path) else 0
    failed_info = [{"idx": f["idx"], "text": f["text"][:40],
                     "time": f"{format_duration(f['start_ms'])}→{format_duration(f['end_ms'])}"}
                    for f in failed]

    update_task(task_id, status="done")
    update_progress(task_id, phase="done", percent=100,
                    message="完成!")
    tasks[task_id]["result"] = {
        "file_size": file_size,
        "duration": format_duration(total_duration_ms),
        "success_count": len(segments),
        "total_count": total,
        "failed_segments": failed_info,
    }
    shutil.rmtree(tmp_dir, ignore_errors=True)


def run_task_thread(task_id, srt_path, output_path, params):
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)
    try:
        loop.run_until_complete(
            process_srt_web(task_id, srt_path, output_path, params))
    except Exception as e:
        update_task(task_id, status="error", error=str(e))
    finally:
        loop.close()

# ============================================================
# 声音缓存
# ============================================================

_voice_cache = None
_voice_cache_ts = 0

def get_cached_voices():
    global _voice_cache, _voice_cache_ts
    if _voice_cache is None or time.time() - _voice_cache_ts > 3600:
        loop = asyncio.new_event_loop()
        try:
            _voice_cache = loop.run_until_complete(edge_tts.list_voices())
            _voice_cache_ts = time.time()
        finally:
            loop.close()
    return _voice_cache

# ============================================================
# Flask 路由
# ============================================================

@app.route("/")
def index():
    # 兼容两种部署方式: index.html 在 templates/ 或在脚本同目录
    for candidate in [
        os.path.join(BASE_DIR, "templates", "index.html"),
        os.path.join(BASE_DIR, "index.html"),
    ]:
        if os.path.exists(candidate):
            with open(candidate, "r", encoding="utf-8") as f:
                resp = make_response(f.read())
                resp.headers["Content-Type"] = "text/html; charset=utf-8"
                return resp
    return "<h1>错误: 找不到 index.html</h1><p>请将 index.html 放在脚本同目录或 templates/ 子目录中</p>", 404

@app.route("/api/voices")
def api_voices():
    lang = request.args.get("lang", "")
    voices = get_cached_voices()
    if lang:
        voices = [v for v in voices if v["Locale"].startswith(lang)]
    return jsonify([{"name": v["ShortName"], "gender": v["Gender"],
                      "locale": v["Locale"]} for v in voices])

@app.route("/api/start", methods=["POST"])
def api_start():
    if "file" not in request.files:
        return jsonify({"error": "请上传 SRT 文件"}), 400
    f = request.files["file"]
    if not f.filename.lower().endswith(".srt"):
        return jsonify({"error": "仅支持 .srt 文件"}), 400

    task_id = uuid.uuid4().hex[:8]
    # 用上传文件名作为输出文件名前缀
    orig_stem = os.path.splitext(os.path.basename(f.filename))[0]
    download_name = f"{orig_stem}_{task_id}.mp3"

    srt_path = os.path.join(UPLOAD_DIR, f"{task_id}.srt")
    f.save(srt_path)
    output_path = os.path.join(OUTPUT_DIR, f"{task_id}.mp3")

    vol_val = int(request.form.get("volume", 0))
    pit_val = int(request.form.get("pitch", 0))
    params = {
        "voice": request.form.get("voice", "zh-CN-YunxiNeural"),
        "concurrency": int(request.form.get("concurrency", 5)),
        "volume": f"+{vol_val}%" if vol_val >= 0 else f"{vol_val}%",
        "pitch": f"+{pit_val}Hz" if pit_val >= 0 else f"{pit_val}Hz",
        "tolerance": float(request.form.get("tolerance", 15)) / 100,
        "max_retries": int(request.form.get("maxRetries", 2)),
        "tts_retries": int(request.form.get("ttsRetries", 3)),
    }

    tasks[task_id] = {
        "id": task_id, "status": "processing",
        "srt_path": srt_path, "output_path": output_path,
        "download_name": download_name,
        "progress": {"phase": "preparing", "total": 0, "done": 0,
                      "success": 0, "failed": 0, "percent": 0,
                      "message": "准备中..."},
        "result": None, "error": None,
    }

    threading.Thread(target=run_task_thread,
                      args=(task_id, srt_path, output_path, params),
                      daemon=True).start()
    return jsonify({"taskId": task_id})

@app.route("/api/progress/<task_id>")
def api_progress(task_id):
    def generate():
        prev = None
        while True:
            t = tasks.get(task_id)
            if not t:
                yield f"data: {json.dumps({'status':'error','error':'任务不存在'})}\n\n"
                break
            d = json.dumps({"status": t["status"], "progress": t["progress"],
                             "result": t.get("result"), "error": t.get("error")},
                            ensure_ascii=False)
            if d != prev:
                yield f"data: {d}\n\n"
                prev = d
            if t["status"] in ("done", "error"):
                break
            time.sleep(0.5)
    return Response(generate(), mimetype="text/event-stream",
                     headers={"Cache-Control": "no-cache",
                              "X-Accel-Buffering": "no"})

@app.route("/api/download/<task_id>")
def api_download(task_id):
    t = tasks.get(task_id)
    if not t or t["status"] != "done":
        return jsonify({"error": "文件不可用"}), 404
    p = t["output_path"]
    if not os.path.exists(p):
        return jsonify({"error": "文件不存在"}), 404
    dl_name = t.get("download_name", f"srt_audio_{task_id}.mp3")
    return send_file(p, as_attachment=True,
                      download_name=dl_name,
                      mimetype="audio/mpeg")

@app.route("/api/failed/<task_id>")
def api_failed(task_id):
    t = tasks.get(task_id)
    if not t or not t.get("result", {}).get("failed_segments"):
        return jsonify([])
    return jsonify(t["result"]["failed_segments"])

# ============================================================
# 入口
# ============================================================

if __name__ == "__main__":
    p = argparse.ArgumentParser(description="SRT 字幕转语音 Web UI")
    p.add_argument("--host", default="0.0.0.0", help="监听地址")
    p.add_argument("--port", type=int, default=5000, help="监听端口")
    args = p.parse_args()
    print(f"\n🌐 SRT 字幕转语音 Web UI")
    print(f"   http://{args.host}:{args.port}\n")
    app.run(host=args.host, port=args.port, threaded=True, debug=False)
