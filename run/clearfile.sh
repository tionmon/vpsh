#!/usr/bin/env bash
set -euo pipefail

# 默认参数
TARGET_DIR=""
SIZE_LT="3G"                     # 小于此大小的文件会被删除。支持 K/M/G, 如: 500M, 3G
LOG_FILE="/var/log/clean_smallfiles.log"
DRY_RUN=false
YES=false
QUIET=false

# 排除项（可多次传入）
EXCL_DIRS=()                    # 排除目录（支持通配符, 相对或绝对路径均可）
EXCL_EXTS=()                    # 排除后缀（不带点，如 mp4, srt）
EXCL_NAMES=()                   # 排除文件名通配（如 "*sample*"）

usage() {
  cat <<'USAGE'
用法:
  clean_smallfiles.sh -p <路径> [-s <大小阈值>] [选项]

必选参数:
  -p, --path PATH              目标路径 (如: /volume1/CloudNAS/CloudDrive/gd/file/videos/jav)

可选参数:
  -s, --size SIZE              删除小于 SIZE 的文件 (默认: 3G; 支持 K/M/G, 例: 500M, 2G)
  -x, --exclude-ext EXT        排除后缀(可多次)，不带点，如: -x srt -x ass -x "txt"
  -n, --exclude-name GLOB      排除文件名通配(可多次)，例: -n "*sample*" -n "demo_*"
  -d, --exclude-dir GLOB       排除目录通配(可多次)，例: -d "*@eaDir*" -d "*backup*"
  -l, --log FILE               日志文件路径 (默认: /var/log/clean_smallfiles.log)
  -t, --dry-run                试运行，仅打印将删除的目标，不执行删除
  -y, --yes                    不询问，直接执行
  -q, --quiet                  静默模式（减少标准输出）
  -h, --help                   显示帮助

功能说明:
  1) 删除小于 SIZE 的文件（排除规则后）
  2) 删除清理后产生的空目录（同样应用排除的目录剪枝）
  3) 所有操作会写入日志(除非你修改或关闭)

示例:
  # 目标目录，阈值3G，排除字幕与文本后缀、排除含sample的文件名、排除@eaDir目录，先试运行
  clean_smallfiles.sh -p /volume1/CloudNAS/CloudDrive/gd/file/videos/jav \
      -s 3G -x srt -x ass -x txt -n "*sample*" -d "*@eaDir*" -t

  # 确认无误后真正执行并跳过确认
  clean_smallfiles.sh -p /volume1/CloudNAS/CloudDrive/gd/file/videos/jav \
      -s 3G -x srt -x ass -x txt -n "*sample*" -d "*@eaDir*" -y
USAGE
}

log() {
  local msg="$1"
  # 始终写日志
  echo "$(date '+%F %T') | $msg" >> "$LOG_FILE"
  # 不是静默模式时也打印到控制台
  if [ "$QUIET" = false ]; then
    echo "$msg"
  fi
}

# 解析参数
if [ $# -eq 0 ]; then usage; exit 1; fi
while (( $# )); do
  case "$1" in
    -p|--path)          TARGET_DIR="${2:-}"; shift 2 ;;
    -s|--size)          SIZE_LT="${2:-}"; shift 2 ;;
    -x|--exclude-ext)   EXCL_EXTS+=("${2:-}"); shift 2 ;;
    -n|--exclude-name)  EXCL_NAMES+=("${2:-}"); shift 2 ;;
    -d|--exclude-dir)   EXCL_DIRS+=("${2:-}"); shift 2 ;;
    -l|--log)           LOG_FILE="${2:-}"; shift 2 ;;
    -t|--dry-run)       DRY_RUN=true; shift ;;
    -y|--yes)           YES=true; shift ;;
    -q|--quiet)         QUIET=true; shift ;;
    -h|--help)          usage; exit 0 ;;
    *) echo "未知参数: $1"; usage; exit 1 ;;
  esac
done

if [ -z "${TARGET_DIR}" ]; then
  echo "错误: 必须指定 --path"; usage; exit 1
fi
if [ ! -d "$TARGET_DIR" ]; then
  echo "错误: 路径不存在或不可访问: $TARGET_DIR" >&2
  exit 1
fi

# 确认提示
if [ "$YES" = false ]; then
  echo "即将对以下路径进行清理："
  echo "  路径: $TARGET_DIR"
  echo "  删除阈值: 小于 $SIZE_LT 的文件"
  [ "${#EXCL_EXTS[@]}" -gt 0 ]  && echo "  排除后缀: ${EXCL_EXTS[*]}"
  [ "${#EXCL_NAMES[@]}" -gt 0 ] && echo "  排除文件名: ${EXCL_NAMES[*]}"
  [ "${#EXCL_DIRS[@]}" -gt 0 ]  && echo "  排除目录: ${EXCL_DIRS[*]}"
  echo "  模式: $([ "$DRY_RUN" = true ] && echo "试运行" || echo "实际删除")"
  read -r -p "确认执行？[y/N] " ans
  case "${ans:-N}" in
    y|Y) ;;
    *) echo "已取消。"; exit 0 ;;
  esac
fi

# 准备 find 参数（使用数组，避免 eval）
FIND_CMD=(find "$TARGET_DIR")

# 目录剪枝（排除目录）
if [ "${#EXCL_DIRS[@]}" -gt 0 ]; then
  FIND_CMD+=( \( -type d )
  # 构建  -ipath "*/pat1/*" -o -ipath "*/pat2/*" ...
  FIRST=true
  for pat in "${EXCL_DIRS[@]}"; do
    if $FIRST; then
      FIND_CMD+=( -ipath "$TARGET_DIR/$pat" )
      FIRST=false
    else
      FIND_CMD+=( -o -ipath "$TARGET_DIR/$pat" )
    fi
  done
  FIND_CMD+=( -prune \) -o )
fi

# 文件匹配（小文件 + 排除文件名/后缀）
FIND_CMD+=( \( -type f -size "-$SIZE_LT" )

# 排除文件名通配
if [ "${#EXCL_NAMES[@]}" -gt 0 ]; then
  for namepat in "${EXCL_NAMES[@]}"; do
    FIND_CMD+=( ! -iname "$namepat" )
  done
fi

# 排除后缀
if [ "${#EXCL_EXTS[@]}" -gt 0 ]; then
  for ext in "${EXCL_EXTS[@]}"; do
    # 统一去掉可能的前导点
    clean_ext="${ext#.}"
    FIND_CMD+=( ! -iname "*.${clean_ext}" )
  done
fi

FIND_CMD+=( \) )

# 执行：删除小文件
if [ "$DRY_RUN" = true ]; then
  log "DRY-RUN: 将删除的小文件列表："
  "${FIND_CMD[@]}" -print | tee -a "$LOG_FILE"
else
  log "开始删除小于 $SIZE_LT 的文件（路径：$TARGET_DIR）"
  "${FIND_CMD[@]}" -print -delete | tee -a "$LOG_FILE"
fi

# 删除空目录（复用剪枝逻辑，避免进入被排除目录）
FIND_DIRS=(find "$TARGET_DIR")
if [ "${#EXCL_DIRS[@]}" -gt 0 ]; then
  FIND_DIRS+=( \( -type d )
  FIRST=true
  for pat in "${EXCL_DIRS[@]}"; do
    if $FIRST; then
      FIND_DIRS+=( -ipath "$TARGET_DIR/$pat" )
      FIRST=false
    else
      FIND_DIRS+=( -o -ipath "$TARGET_DIR/$pat" )
    fi
  done
  FIND_DIRS+=( -prune \) -o )
fi
FIND_DIRS+=( -type d -empty )

if [ "$DRY_RUN" = true ]; then
  log "DRY-RUN: 将删除的空目录列表："
  "${FIND_DIRS[@]}" -print | tee -a "$LOG_FILE"
else
  log "开始删除空目录"
  "${FIND_DIRS[@]}" -print -delete | tee -a "$LOG_FILE"
fi

log "清理完成。"
[ "$QUIET" = false ] && echo "完成 ✅ 日志: $LOG_FILE"
