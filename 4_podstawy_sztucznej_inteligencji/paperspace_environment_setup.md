# LiDAR Tree Segmentation – DL Environment Setup

## Environment

| | |
|---|---|
| Machine | Paperspace Gradient "Start from Scratch" |
| GPU | Quadro RTX 5000 (Ampere, sm_86, 16GB) |
| CUDA | 12.4 |
| Persistent storage | `/notebooks` |

> **Note:** Everything is installed under `/notebooks/miniconda` so it survives machine restarts. After a restart, the only thing you need to do is re-activate the conda environment (see [After Restart](#after-restart)).

---

## Step 1 – Install Miniconda to persistent storage

```bash
wget -q https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
bash Miniconda3-latest-Linux-x86_64.sh -b -p /notebooks/miniconda
rm Miniconda3-latest-Linux-x86_64.sh
source /notebooks/miniconda/etc/profile.d/conda.sh
conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main
conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r
conda --version
```

---

## Step 2 – Create conda environment

```bash
source /notebooks/miniconda/etc/profile.d/conda.sh
```
```bash
conda create -n treeseg python=3.10 -y
```
```bash
conda activate treeseg
```
```bash
which python
# Expected: /notebooks/miniconda/envs/treeseg/bin/python
```

---

## Step 3 – Install PyTorch (CUDA 12.1 wheels, compatible with CUDA 12.4)

```bash
pip install torch==2.1.0 torchvision==0.16.0 torchaudio==2.1.0 \
    --index-url https://download.pytorch.org/whl/cu121
```

Verify:
```bash
python -c "import torch; print(torch.__version__); print(torch.cuda.is_available()); print(torch.cuda.get_device_name(0))"
# Expected: 2.1.0+cu121 / True / Quadro RTX 5000
```

---

## Step 4 – Install general dependencies

```bash
pip install ninja h5py pyyaml sharedarray tensorboard tensorboardx \
    yapf addict einops scipy plyfile termcolor timm
```

---

## Step 5 – Pin NumPy (required for scipy compatibility)

```bash
pip install "numpy>=1.19.5,<1.27.0"
```

---

## Step 6 – Install spconv

```bash
pip install spconv-cu120
```

---

## Step 7 – Install PyG libraries

```bash
pip install torch-scatter torch-sparse torch-cluster \
    -f https://data.pyg.org/whl/torch-2.1.0+cu121.html
pip install torch-geometric
```

---

## Step 8 – Install remaining libraries

```bash
pip install "laspy[lazrs]" torchmetrics pandas
pip install open3d==0.19.0
```

```bash
pip install seaborn==0.13.2
```

> **Notes:**
> - `laspy` is installed without the `[lazrs]` extra because `lazrs` requires Python ≥ 3.9. This means compressed `.laz` files are not supported, only `.las`.
> - `open3d` is optional (visualization only). If installation fails, skip it — PTv3 core functionality is unaffected.

---

## Step 9 – Clone repository (with submodules)

```bash
git clone --recurse-submodules \
    https://github.com/pointcept/pointtransformerv3.git \
    /notebooks/Pointcept

ls /notebooks/Pointcept/Pointcept/libs/pointops
# Expected: __init__.py  functions  setup.py  src
```

> **Important:** The repo uses a git submodule (`Pointcept @ df36980`). Without `--recurse-submodules` the `libs/pointops` directory will be empty.

---

## Step 10 – Compile pointops (custom CUDA extension)
```bash
pip install "setuptools<70.0.0"
```

```bash
export CUDA_HOME=/usr/local/cuda
export TORCH_CUDA_ARCH_LIST="8.6"   # Quadro RTX 5000 = Ampere sm_86
cd /notebooks/Pointcept/Pointcept/libs/pointops
python setup.py install
```

---

## Step 11 – Install wandb

```bash
pip install wandb
```

---

## Step 12 – Register Jupyter kernel

```bash
pip install ipykernel
python -m ipykernel install --user \
    --name treeseg --display-name "LiDAR Tree Seg"
echo "Done!"
```

---

## Step 13 – Switch kernel in notebook

Refresh the Paperspace page, then in the top-right corner:

```
Kernel → Change Kernel → LiDAR Tree Seg
```

---

## Step 14 – Verify installation (run in notebook)

```python
import sys
sys.path.insert(0, "/notebooks/miniconda/envs/treeseg/lib/python3.10/site-packages")
sys.path.insert(0, "/notebooks/Pointcept/Pointcept")

import importlib

checks = [
    ('torch',           lambda m: f"v{m.__version__} | CUDA: {m.cuda.is_available()} | GPU: {m.cuda.get_device_name(0)}"),
    ('spconv',          lambda m: f"v{m.__version__}"),
    ('torch_geometric', lambda m: f"v{m.__version__}"),
    ('torch_scatter',   lambda m: 'OK'),
    ('torch_sparse',    lambda m: 'OK'),
    ('torch_cluster',   lambda m: 'OK'),
    ('laspy',           lambda m: f"v{m.__version__}"),
    ('open3d',          lambda m: f"v{m.__version__}"),
    ('torchmetrics',    lambda m: f"v{m.__version__}"),
    ('pointops',        lambda m: 'OK'),
]

print('=== VERIFICATION ===\n')
ok, fail = 0, 0
for name, info_fn in checks:
    try:
        mod = importlib.import_module(name)
        print(f'  ✅  {name:<20} {info_fn(mod)}')
        ok += 1
    except Exception as e:
        print(f'  ❌  {name:<20} ERROR: {e}')
        fail += 1

print(f'\nResult: {ok} OK, {fail} errors')
print('\n🎉 All good!' if fail == 0 else '\n⚠️  Check errors above.')
```

---

## After Restart

The installation persists in `/notebooks`. After a machine restart, just run in terminal:

```bash
source /notebooks/miniconda/etc/profile.d/conda.sh
conda activate treeseg
```

---

```bash
/notebooks/miniconda/envs/treeseg/bin/python -m ipykernel install --user \
    --name treeseg --display-name "LiDAR Tree Seg"
```

---

Then select the `LiDAR Tree Seg` kernel in your notebook as usual.

---

## Known Issues

| Issue | Cause | Fix |
|---|---|---|
| `conda activate` fails with `Run 'conda init' first` | Shell not initialized | Use `source /notebooks/miniconda/etc/profile.d/conda.sh` before activating |
| `libs/pointops` directory empty after clone | Repo uses git submodules | Clone with `--recurse-submodules` |
| `torch_scatter` / `torch_sparse` fail to load | PyTorch version mismatch | Ensure torch==2.1.0 is installed before PyG libs |

| `scipy` broken, numpy warning | NumPy ≥ 1.27 incompatible | Pin with `pip install "numpy>=1.19.5,<1.27.0"` |
| Wrong torch version in notebook (e.g. 2.10) | Notebook using system Python, not conda env | Re-register kernel: `python -m ipykernel install --user --name treeseg` |

---

## Flash Attention

PTv3 supports FlashAttention but it requires CUDA ≥ 11.6 and a supported architecture. The Quadro RTX 5000 (sm_86) should be compatible. To enable:

```bash
pip install flash-attn --no-build-isolation
```

To disable FlashAttention when running PTv3:
```bash
python tools/train.py --config configs/YOUR_CONFIG.py --options model.flash=false
```
