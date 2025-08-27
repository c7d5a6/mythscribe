# Verify everything is working
import torch

print(f"PyTorch: {torch.__version__}")
print(f"CUDA available: {torch.cuda.is_available()}")

try:
    import pyannote.audio
    print("pyannote.audio is installed.")
except ImportError:
    print("pyannote.audio is NOT installed.")