#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

NUM_GENERATE=5
ENV_NAME=""
WITH_TRAIN_SMOKE=0
PY_RUNNER=""
RUNTIME_LABEL=""

if [[ -t 1 ]]; then
  C_RESET=$'\033[0m'
  C_BOLD=$'\033[1m'
  C_DIM=$'\033[2m'
  C_BLUE=$'\033[34m'
  C_GREEN=$'\033[32m'
  C_YELLOW=$'\033[33m'
  C_RED=$'\033[31m'
else
  C_RESET=''
  C_BOLD=''
  C_DIM=''
  C_BLUE=''
  C_GREEN=''
  C_YELLOW=''
  C_RED=''
fi

usage() {
  cat <<'USAGE'
One-click demo runner for AnimalGAN.

Usage:
  bash script/run.sh [--num-generate N] [--env ENV_NAME] [--with-train-smoke]

Options:
  --num-generate N   Number of records to generate per treatment (default: 5)
  --env ENV_NAME     Conda env name to use (default: auto-detect AnimalGAN/animalgan)
  --with-train-smoke Run 1-epoch training smoke test after generation
  -h, --help         Show this help message
USAGE
}

print_banner() {
  echo
  echo "${C_BOLD}${C_BLUE}========================================${C_RESET}"
  echo "${C_BOLD}${C_BLUE}        AnimalGAN Demo Runner          ${C_RESET}"
  echo "${C_BOLD}${C_BLUE}========================================${C_RESET}"
}

print_progress() {
  local current="$1"
  local total="$2"
  local title="$3"
  local width=24
  local filled=$(( current * width / total ))
  local empty=$(( width - filled ))
  local bar
  bar="$(printf '%*s' "$filled" '' | tr ' ' '#')$(printf '%*s' "$empty" '' | tr ' ' '-')"
  echo
  echo "${C_BOLD}[${current}/${total}]${C_RESET} ${title}"
  echo "${C_DIM}[${bar}]${C_RESET}"
}

info() {
  echo "${C_BLUE}INFO${C_RESET}  $*"
}

ok() {
  echo "${C_GREEN}OK${C_RESET}    $*"
}

warn() {
  echo "${C_YELLOW}WARN${C_RESET}  $*"
}

die() {
  echo "${C_RED}ERR${C_RESET}   $*" >&2
  exit 1
}

run_python() {
  if [[ -n "$PY_RUNNER" ]]; then
    # shellcheck disable=SC2086
    $PY_RUNNER "$@"
  else
    python "$@"
  fi
}

run_task() {
  local title="$1"
  local logfile="$2"
  shift 2
  local start_ts
  local end_ts

  info "Current task: ${title}"
  : > "$logfile"
  start_ts=$(date +%s)

  set +e
  "$@" >"$logfile" 2>&1 &
  local pid=$!
  if [[ -t 1 ]]; then
    local spin='|/-\\'
    local i=0
    while kill -0 "$pid" >/dev/null 2>&1; do
      i=$(( (i + 1) % 4 ))
      printf "\r${C_DIM}Working ${spin:$i:1} ${title}${C_RESET}"
      sleep 0.1
    done
    printf "\r%-80s\n" ""
  fi
  wait "$pid"
  local rc=$?
  set -e

  end_ts=$(date +%s)
  local elapsed=$(( end_ts - start_ts ))

  if [[ "$rc" -ne 0 ]]; then
    warn "Task failed. Last 20 log lines:"
    tail -n 20 "$logfile" >&2 || true
    return "$rc"
  fi

  ok "Done: ${title} (${elapsed}s)"
}

select_python_runner() {
  if ! command -v conda >/dev/null 2>&1; then
    return 1
  fi

  local detected_env=""
  if [[ -n "$ENV_NAME" ]]; then
    detected_env="$ENV_NAME"
  else
    if conda env list | awk '{print $1}' | grep -qx 'AnimalGAN'; then
      detected_env='AnimalGAN'
    elif conda env list | awk '{print $1}' | grep -qx 'animalgan'; then
      detected_env='animalgan'
    fi
  fi

  if [[ -n "$detected_env" ]]; then
    PY_RUNNER="conda run -n $detected_env python"
    RUNTIME_LABEL="conda:$detected_env"
    ok "Using conda env: $detected_env"
    return 0
  fi

  return 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --num-generate)
      NUM_GENERATE="$2"
      shift 2
      ;;
    --env)
      ENV_NAME="$2"
      shift 2
      ;;
    --with-train-smoke)
      WITH_TRAIN_SMOKE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "Unknown option: $1"
      ;;
  esac
done

if ! [[ "$NUM_GENERATE" =~ ^[0-9]+$ ]] || [[ "$NUM_GENERATE" -lt 1 ]]; then
  die "--num-generate must be a positive integer"
fi

TOTAL_STEPS=5
if [[ "$WITH_TRAIN_SMOKE" -eq 1 ]]; then
  TOTAL_STEPS=6
fi

print_banner
cd "$ROOT_DIR"
SCRIPT_START_TS=$(date +%s)

print_progress 1 "$TOTAL_STEPS" "Preparing workspace"
mkdir -p Results models logs
ok "Workspace ready: $ROOT_DIR"

print_progress 2 "$TOTAL_STEPS" "Selecting Python runtime"
if select_python_runner; then
  :
else
  warn "Conda env not found or conda unavailable; using current python from PATH"
  if ! python -c "import torch" >/dev/null 2>&1; then
    die "Current python does not have torch. Run: conda env create -f environment.yml"
  fi
  RUNTIME_LABEL="python:$(command -v python)"
  ok "Using python from PATH: $(command -v python)"
fi

print_progress 3 "$TOTAL_STEPS" "Generating synthetic records"
run_task "Generate data (num_generate=$NUM_GENERATE)" "logs/run_generate.log" \
  run_python SRC/generate.py --num_generate "$NUM_GENERATE"

print_progress 4 "$TOTAL_STEPS" "Validating output"
RESULT_FILE="Results/generated_data_${NUM_GENERATE}.tsv"
[[ -f "$RESULT_FILE" ]] || die "Result file not found: $RESULT_FILE"
LINE_COUNT=$(wc -l < "$RESULT_FILE")
ok "Output file: $ROOT_DIR/$RESULT_FILE"
ok "Line count : $LINE_COUNT"

print_progress 5 "$TOTAL_STEPS" "Previewing generated content"
head -n 2 "$RESULT_FILE"
ok "Preview displayed (header + first row)"

if [[ "$WITH_TRAIN_SMOKE" -eq 1 ]]; then
  print_progress 6 "$TOTAL_STEPS" "Running 1-epoch training smoke test"
  run_task "Train smoke test (1 epoch)" "logs/run_train_smoke.log" \
    run_python SRC/train_cwgangp.py --n_epochs 1 --interval 1 --batch_size 64
  ok "Training smoke test complete. Check models/generator_1"
fi

SCRIPT_END_TS=$(date +%s)
TOTAL_ELAPSED=$(( SCRIPT_END_TS - SCRIPT_START_TS ))

echo
echo "${C_GREEN}${C_BOLD}All steps completed successfully.${C_RESET}"
echo "${C_BOLD}========================================${C_RESET}"
echo "${C_BOLD}Summary${C_RESET}"
echo "  Runtime        : $RUNTIME_LABEL"
echo "  num_generate   : $NUM_GENERATE"
echo "  Train smoke    : $([[ $WITH_TRAIN_SMOKE -eq 1 ]] && echo enabled || echo disabled)"
echo "  Output         : $ROOT_DIR/$RESULT_FILE"
echo "  Output lines   : $LINE_COUNT"
echo "  Generate log   : $ROOT_DIR/logs/run_generate.log"
if [[ "$WITH_TRAIN_SMOKE" -eq 1 ]]; then
  echo "  Train log      : $ROOT_DIR/logs/run_train_smoke.log"
fi
echo "  Total elapsed  : ${TOTAL_ELAPSED}s"
echo "${C_BOLD}========================================${C_RESET}"
