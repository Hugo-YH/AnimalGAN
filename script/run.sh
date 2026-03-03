#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

NUM_GENERATE=5
ENV_NAME=""
WITH_TRAIN_SMOKE=0

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
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if ! [[ "$NUM_GENERATE" =~ ^[0-9]+$ ]] || [[ "$NUM_GENERATE" -lt 1 ]]; then
  echo "--num-generate must be a positive integer" >&2
  exit 1
fi

run_python() {
  if [[ -n "${PY_RUNNER:-}" ]]; then
    # shellcheck disable=SC2086
    $PY_RUNNER "$@"
  else
    python "$@"
  fi
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
    echo "Using conda env: $detected_env"
    return 0
  fi

  return 1
}

cd "$ROOT_DIR"
mkdir -p Results models logs

if select_python_runner; then
  :
else
  echo "Conda env not found or conda unavailable; using current python from PATH."
  if ! python -c "import torch" >/dev/null 2>&1; then
    echo "Current python does not have torch installed." >&2
    echo "Please create env with: conda env create -f environment.yml" >&2
    echo "Then run: bash script/run.sh --env AnimalGAN" >&2
    exit 1
  fi
fi

echo "Running generation demo (num_generate=$NUM_GENERATE)..."
run_python SRC/generate.py --num_generate "$NUM_GENERATE"

RESULT_FILE="Results/generated_data_${NUM_GENERATE}.tsv"
if [[ ! -f "$RESULT_FILE" ]]; then
  echo "Generation finished but result file not found: $RESULT_FILE" >&2
  exit 1
fi

LINE_COUNT=$(wc -l < "$RESULT_FILE")
echo "Demo succeeded. Output: $ROOT_DIR/$RESULT_FILE (lines: $LINE_COUNT)"

if [[ "$WITH_TRAIN_SMOKE" -eq 1 ]]; then
  echo "Running 1-epoch training smoke test..."
  run_python SRC/train_cwgangp.py --n_epochs 1 --interval 1 --batch_size 64
  echo "Training smoke test succeeded. Check models/generator_1"
fi
