# AnimalGAN：用于临床病理评估、可替代动物研究的生成对抗网络模型

本仓库提供论文 **AnimalGAN: A Generative Adversarial Network Model Alternative to Animal Studies for Clinical Pathology Assessment** 的代码实现。

英文文档: [README.md](README.md)

## 快速开始（开箱即用）

### 1. 创建环境（首次执行）

```bash
conda env create -f environment.yml
```

### 2. 一键运行 Demo

在仓库根目录执行：

```bash
bash script/run.sh
```

该命令会自动完成：
- 自动检测 conda 环境（`AnimalGAN` 或 `animalgan`）
- 执行 `SRC/generate.py --num_generate 5`
- 将结果写入 `Results/generated_data_5.tsv`

## 一键脚本参数

```bash
bash script/run.sh --num-generate 20
bash script/run.sh --env AnimalGAN
bash script/run.sh --with-train-smoke
```

- `--num-generate N`：每个处理条件生成 `N` 条记录
- `--env ENV_NAME`：强制使用指定 conda 环境名
- `--with-train-smoke`：在生成后额外执行 1 epoch 训练冒烟测试（`SRC/train_cwgangp.py`）

同时保留兼容入口：

```bash
bash scripts/run.sh
```

## 输出文件解读

默认输出文件：

```text
Results/generated_data_5.tsv
```

文件结构：
- 前 3 列为处理条件：`COMPOUND_NAME`、`SACRI_PERIOD`、`DOSE_LEVEL`
- 后续列为生成的血液学/生化指标

如果使用 `--num-generate N`，则每个处理条件会生成 `N` 条记录。

## 仓库结构

```text
Data/                                # 示例数据
  SDFs/                              # SDF 文件
  Example_Data_training.tsv          # 训练数据示例
  Example_MolecularDescriptors.tsv   # 分子描述符示例
  Example_Treatments_test.tsv        # 待生成处理条件示例
SRC/                                 # 源代码
  model.py                           # 生成器与判别器
  opt.py                             # 超参数解析
  train_cwgangp.py                   # 主训练入口
  train_cwgangp_scale.py             # 训练变体脚本
  train.py                           # 不完整/实验性脚本
  generate.py                        # 基于预训练模型的数据生成脚本
  utils.py                           # 工具函数
script/run.sh                        # 一键 Demo 脚本
scripts/run.sh                       # 兼容包装脚本
```

## 手动命令

### 生成数据

```bash
conda run -n AnimalGAN python SRC/generate.py --num_generate 100
```

### 训练模型

建议使用 `train_cwgangp.py` 作为可执行训练入口：

```bash
conda run -n AnimalGAN python SRC/train_cwgangp.py --n_epochs 1000
```

### 1 epoch 训练冒烟测试

```bash
conda run -n AnimalGAN python SRC/train_cwgangp.py --n_epochs 1 --interval 1 --batch_size 64
```

该测试仅用于验证训练流程是否正常（数据加载、前向/反向、优化器更新、checkpoint 写入），不用于评估模型效果。

## 常见问题

- `ModuleNotFoundError: No module named torch`
  - 先创建环境：`conda env create -f environment.yml`
  - 再指定环境运行：`bash script/run.sh --env AnimalGAN`

- 找不到 `models/AnimalGAN`
  - 生成前请确认预训练模型文件存在于 `models/AnimalGAN`。

- 自动检测到错误环境
  - 显式指定：`bash script/run.sh --env YOUR_ENV_NAME`

## 说明

- 默认预训练模型路径为 `models/AnimalGAN`（本仓库已包含）。
- 生成结果保存在 `Results/`。
- 若你的 conda 环境名不是 `AnimalGAN` / `animalgan`，请使用 `--env YOUR_ENV_NAME`。
