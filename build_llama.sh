#!/bin/bash

# Build llama.cpp from source with CUDA support
# This script runs at container startup to ensure latest version

set -e

echo "============================================"
echo "  Building llama.cpp from source"
echo "============================================"

LLAMA_DIR="/llama.cpp"

# Always rebuild from scratch for latest version
if [ -d "$LLAMA_DIR" ]; then
    echo "Removing existing llama.cpp directory..."
    rm -rf "$LLAMA_DIR"
fi

echo ""
echo "Cloning latest llama.cpp from GitHub..."
git clone --depth 1 https://github.com/ggml-org/llama.cpp.git "$LLAMA_DIR"

cd "$LLAMA_DIR"

# Get commit info
COMMIT=$(git rev-parse --short HEAD)
echo "Building commit: $COMMIT"

echo ""
echo "Configuring build with CUDA support and optimizations..."
# GGML_CUDA=ON: Enable CUDA backend for GPU acceleration
# LLAMA_CURL=ON: Enable curl for downloading models
# GGML_CUDA_FA_ALL_QUANTS=ON: Enable flash attention for all quantization types
cmake -B build \
    -DGGML_CUDA=ON \
    -DLLAMA_CURL=ON \
    -DGGML_CUDA_FA_ALL_QUANTS=ON \
    -DCMAKE_BUILD_TYPE=Release

echo ""
echo "Compiling (this may take 5-15 minutes)..."
START_TIME=$(date +%s)

cmake --build build --config Release -j$(nproc)

END_TIME=$(date +%s)
BUILD_TIME=$((END_TIME - START_TIME))

echo ""
echo "============================================"
echo "  Build complete!"
echo "  Time: ${BUILD_TIME} seconds"
echo "  Commit: $COMMIT"
echo "============================================"

# Verify binary exists
if [ ! -f "$LLAMA_DIR/build/bin/llama-server" ]; then
    echo "❌ ERROR: llama-server binary not found!"
    exit 1
fi

echo "✅ llama-server binary ready at $LLAMA_DIR/build/bin/llama-server"
