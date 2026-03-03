# AnimalGAN: A Generative Adversarial Network Model Alternative to Animal Studies for Clinical Pathology Assessment

This repository contains code for the paper **AnimalGAN: A Generative Adversarial Network Model Alternative to Animal Studies for Clinical Pathology Assessment**.

中文文档: [README.zh-CN.md](README.zh-CN.md)

## Quick Start (Out-of-the-box)

### 1. Create environment (first time only)

```bash
conda env create -f environment.yml
```

### 2. Run one-click demo

From repo root:

```bash
bash script/run.sh
```

This command will:
- auto-detect conda env (`AnimalGAN` or `animalgan`)
- run `SRC/generate.py` with `--num_generate 5`
- write output to `Results/generated_data_5.tsv`

## One-click Script Options

```bash
bash script/run.sh --num-generate 20
bash script/run.sh --env AnimalGAN
bash script/run.sh --with-train-smoke
```

- `--num-generate N`: number of records generated per treatment condition
- `--env ENV_NAME`: force a specific conda env name
- `--with-train-smoke`: additionally run a 1-epoch training smoke test (`SRC/train_cwgangp.py`)

Compatibility entrypoint is also available:

```bash
bash scripts/run.sh
```

## Output File Interpretation

By default, generation writes:

```text
Results/generated_data_5.tsv
```

The file contains:
- first 3 columns: treatment condition (`COMPOUND_NAME`, `SACRI_PERIOD`, `DOSE_LEVEL`)
- remaining columns: generated hematology/biochemistry measurements

If `--num-generate N` is used, each treatment condition gets `N` generated records.

## Repository Structure

```text
Data/                                # Example data
  SDFs/                              # SDF files
  Example_Data_training.tsv          # Example training data
  Example_MolecularDescriptors.tsv   # Example molecular descriptors
  Example_Treatments_test.tsv        # Example treatment conditions
SRC/                                 # Source code
  model.py                           # Generator and Discriminator
  opt.py                             # Hyperparameter parser
  train_cwgangp.py                   # Main training entrypoint
  train_cwgangp_scale.py             # Variant training script
  train.py                           # Incomplete/experimental script
  generate.py                        # Data generation with pretrained model
  utils.py                           # Utilities
script/run.sh                        # One-click demo script
scripts/run.sh                       # Compatibility wrapper
```

## Manual Commands

### Generate data

```bash
conda run -n AnimalGAN python SRC/generate.py --num_generate 100
```

### Train model

Use `train_cwgangp.py` as the executable training entrypoint:

```bash
conda run -n AnimalGAN python SRC/train_cwgangp.py --n_epochs 1000
```

### 1-epoch training smoke test

```bash
conda run -n AnimalGAN python SRC/train_cwgangp.py --n_epochs 1 --interval 1 --batch_size 64
```

This is for pipeline validation only (data loading, forward/backward, optimizer step, checkpoint write), not model quality.

## Troubleshooting

- `ModuleNotFoundError: No module named torch`
  - Install env first: `conda env create -f environment.yml`
  - Then run with env: `bash script/run.sh --env AnimalGAN`

- `models/AnimalGAN` not found
  - Ensure pretrained model file exists at `models/AnimalGAN` before running generation.

- Env auto-detect picked wrong env
  - Force env name: `bash script/run.sh --env YOUR_ENV_NAME`

## Notes

- Pretrained model file is expected at `models/AnimalGAN` (already present in this repo).
- Generated files are saved under `Results/`.
- If your conda env name is not `AnimalGAN`/`animalgan`, pass `--env YOUR_ENV_NAME`.
