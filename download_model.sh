#!/bin/bash

# Download GGUF model from HuggingFace
# Supports: owner/repo:quantization or owner/repo (auto-selects first GGUF)
# Handles split GGUFs automatically
# Supports HF_TOKEN for gated models (Llama 3, etc.)

set -e

echo "============================================"
echo "  Downloading Model from HuggingFace"
echo "============================================"

# Set HuggingFace token if provided (for gated models)
if [ -n "$HF_TOKEN" ]; then
    echo "✅ HF_TOKEN detected - gated models supported"
    export HUGGING_FACE_HUB_TOKEN="$HF_TOKEN"
fi

if [ -z "$MODEL" ]; then
    echo "❌ ERROR: MODEL environment variable is required"
    echo "Examples:"
    echo "  MODEL=TheBloke/Llama-2-7B-GGUF:Q4_K_M"
    echo "  MODEL=ggml-org/gemma-3-1b-it-GGUF"
    exit 1
fi

# Parse MODEL into repo and optional quantization
# Format: owner/repo:quantization or owner/repo
if [[ "$MODEL" == *":"* ]]; then
    REPO="${MODEL%%:*}"
    QUANT="${MODEL##*:}"
    echo "Repository: $REPO"
    echo "Quantization filter: $QUANT"
else
    REPO="$MODEL"
    QUANT=""
    echo "Repository: $REPO"
    echo "Quantization filter: (auto-select)"
fi

MODEL_DIR="/models/$REPO"

# Check if model already exists (including subfolders)
EXISTING_GGUF=$(find "$MODEL_DIR" -name "*.gguf" -type f 2>/dev/null | head -1)
if [ -n "$EXISTING_GGUF" ]; then
    echo "✅ Model already exists at $MODEL_DIR"
    find "$MODEL_DIR" -name "*.gguf" -type f -exec ls -lh {} \;
    
    # Export the model path for entrypoint
    GGUF_FILE=$(find "$MODEL_DIR" -name "*.gguf" -type f | head -1)
    echo "MODEL_PATH=$GGUF_FILE" > /tmp/model_path.env
    exit 0
fi

echo ""
echo "Downloading from HuggingFace..."

mkdir -p "$MODEL_DIR"

# Download model files using Python directly (most reliable)
if [ -n "$QUANT" ]; then
    # Download specific quantization pattern
    # Support both flat files and subfolders (e.g., unsloth repos use IQ1_S/*.gguf)
    echo "Looking for files matching: *${QUANT}* (including subfolders)"
    python3 << PYEOF
from huggingface_hub import snapshot_download
snapshot_download(
    repo_id="$REPO",
    allow_patterns=["*${QUANT}*/*.gguf", "*${QUANT}*.gguf", "${QUANT}/*.gguf"],
    local_dir="$MODEL_DIR"
)
PYEOF
else
    # Download all GGUF files (for split models or single file)
    echo "Downloading all GGUF files..."
    python3 << PYEOF
from huggingface_hub import snapshot_download
snapshot_download(
    repo_id="$REPO",
    allow_patterns=["*.gguf"],
    local_dir="$MODEL_DIR"
)
PYEOF
fi

echo ""
echo "============================================"
echo "  Download complete!"
echo "============================================"

# List downloaded files
echo "Downloaded files:"
ls -lh "$MODEL_DIR"/*.gguf 2>/dev/null || ls -lh "$MODEL_DIR"/**/*.gguf 2>/dev/null || true

# Find the GGUF file to use
# For split models, use the first part (llama.cpp handles the rest)
# For single files, use that file
# Priority: match quant pattern, then -00001-of-, then any .gguf

find_model_file() {
    local dir="$1"
    local quant="$2"
    
    # If quant specified, find matching file
    if [ -n "$quant" ]; then
        find "$dir" -name "*${quant}*.gguf" -type f 2>/dev/null | head -1
        return
    fi
    
    # For split models, find the first part
    SPLIT_FILE=$(find "$dir" -name "*-00001-of-*.gguf" -type f 2>/dev/null | head -1)
    if [ -n "$SPLIT_FILE" ]; then
        echo "$SPLIT_FILE"
        return
    fi
    
    # Otherwise, just get the first GGUF
    find "$dir" -name "*.gguf" -type f 2>/dev/null | head -1
}

GGUF_FILE=$(find_model_file "$MODEL_DIR" "$QUANT")

if [ -z "$GGUF_FILE" ]; then
    echo "❌ ERROR: No GGUF file found after download!"
    exit 1
fi

echo ""
echo "✅ Model file: $GGUF_FILE"
echo "MODEL_PATH=$GGUF_FILE" > /tmp/model_path.env
