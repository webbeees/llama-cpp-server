#!/bin/bash

# llama.cpp Server Entrypoint
# 1. Check CUDA availability
# 2. Build llama.cpp from source (latest version)
# 3. Download model from HuggingFace
# 4. Start llama-server

set -e

echo "============================================"
echo "  llama.cpp Server - Starting Up"
echo "============================================"
echo ""

# ============================================
# CUDA Check
# ============================================
echo "Checking CUDA availability..."

python3 -c "
import subprocess
import sys

# Check nvidia-smi
try:
    result = subprocess.run(['nvidia-smi', '--query-gpu=name,memory.total', '--format=csv,noheader'], 
                          capture_output=True, text=True, timeout=10)
    if result.returncode == 0:
        print('✅ NVIDIA GPU detected:')
        print(result.stdout.strip())
        sys.exit(0)
    else:
        print('❌ nvidia-smi failed')
        sys.exit(1)
except FileNotFoundError:
    print('❌ nvidia-smi not found')
    sys.exit(1)
except Exception as e:
    print(f'❌ GPU check failed: {e}')
    sys.exit(1)
"

if [ $? -ne 0 ]; then
    echo ""
    echo "❌ ERROR: CUDA/GPU is required but not available"
    echo "Make sure to run with --gpus all"
    exit 1
fi

echo ""

# ============================================
# Build llama.cpp
# ============================================
/scripts/build_llama.sh

echo ""

# ============================================
# Download Model
# ============================================
/scripts/download_model.sh

# Load model path
if [ -f /tmp/model_path.env ]; then
    source /tmp/model_path.env
else
    echo "❌ ERROR: Model path not set"
    exit 1
fi

if [ -z "$MODEL_PATH" ]; then
    echo "❌ ERROR: MODEL_PATH is empty"
    exit 1
fi

echo ""
echo "============================================"
echo "  Starting llama-server"
echo "============================================"
echo ""
echo "Configuration:"
echo "  Model: $MODEL_PATH"
echo "  Context Size: ${CTX_SIZE:-4096}"
echo "  Max Tokens: ${MAX_TOKENS:-2048}"
echo "  Port: ${PORT:-8080}"
echo "  Parallel Slots: ${PARALLEL:-16}"
echo "  Batch Size: ${BATCH_SIZE:-2048} (default)"
echo "  Ubatch Size: ${UBATCH_SIZE:-512} (default)"
echo "  GPU Layers: 999 (all)"
echo "  Flash Attention: auto (default)"
echo "  Continuous Batching: enabled (default)"
echo ""
echo "API Endpoints:"
echo "  POST /v1/chat/completions  - Chat completions"
echo "  POST /v1/completions       - Text completions"
echo "  GET  /health               - Health check"
echo ""
echo "============================================"
echo ""

# Start llama-server with batching optimizations
# Defaults already optimized for batching:
#   - Continuous batching: enabled by default
#   - Flash attention: 'auto' by default (enables when beneficial)
#   - Batch size: 2048, Ubatch size: 512
exec /llama.cpp/build/bin/llama-server \
    --model "$MODEL_PATH" \
    --ctx-size "${CTX_SIZE:-4096}" \
    --n-predict "${MAX_TOKENS:-2048}" \
    --port "${PORT:-8080}" \
    --parallel "${PARALLEL:-16}" \
    --batch-size "${BATCH_SIZE:-2048}" \
    --ubatch-size "${UBATCH_SIZE:-512}" \
    --n-gpu-layers 999 \
    --host 0.0.0.0
