# Verify everything is working
import torch
import nemo.collections.asr as nemo_asr

print(f"PyTorch: {torch.__version__}")
print(f"CUDA available: {torch.cuda.is_available()}")
print(f"NeMo ASR imported successfully")