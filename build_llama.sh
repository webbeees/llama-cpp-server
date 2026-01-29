#!/bin/bash

# Build llama.cpp from source with CUDA support
# Only rebuilds if a newer version is available on GitHub

set -e

echo "============================================"
echo "  Building llama.cpp from source"
echo "============================================"

LLAMA_DIR="/llama.cpp"
LLAMA_SERVER="$LLAMA_DIR/build/bin/llama-server"
REPO_URL="https://github.com/ggml-org/llama.cpp.git"

# Check if we need to rebuild
NEED_BUILD=false

if [ -f "$LLAMA_SERVER" ] && [ -d "$LLAMA_DIR/.git" ]; then
    echo "Existing build found. Checking for updates..."
    cd "$LLAMA_DIR"
    
    # Get current local commit
    LOCAL_COMMIT=$(git rev-parse HEAD 2>/dev/null || echo "none")
    
    # Get latest remote commit (without full fetch)
    REMOTE_COMMIT=$(git ls-remote "$REPO_URL" HEAD 2>/dev/null | cut -f1 || echo "unknown")
    
    echo "  Local commit:  ${LOCAL_COMMIT:0:8}"
    echo "  Remote commit: ${REMOTE_COMMIT:0:8}"
    
    if [ "$LOCAL_COMMIT" = "$REMOTE_COMMIT" ]; then
        echo "✅ Already up to date! Skipping rebuild."
        echo "  Binary: $LLAMA_SERVER"
        exit 0
    else
        echo "⬆️  New version available. Rebuilding..."
        NEED_BUILD=true
        rm -rf "$LLAMA_DIR"
    fi
    cd /
else
    echo "No existing build found. Fresh build required."
    NEED_BUILD=true
    if [ -d "$LLAMA_DIR" ]; then
        rm -rf "$LLAMA_DIR"
    fi
fi

echo ""
echo "Cloning latest llama.cpp from GitHub..."
git clone --depth 1 "$REPO_URL" "$LLAMA_DIR"

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
