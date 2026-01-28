# llama.cpp Server Docker Image
# Builds llama.cpp from source at container startup for latest version
# CUDA-enabled for NVIDIA GPUs

FROM nvidia/cuda:12.4.1-devel-ubuntu22.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install build dependencies and tools
RUN apt-get update && apt-get install -y \
    git \
    cmake \
    build-essential \
    curl \
    wget \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Install huggingface-cli for model downloads
RUN pip install --no-cache-dir "huggingface_hub[hf_transfer]"

# Enable HF transfer for faster downloads
ENV HF_HUB_ENABLE_HF_TRANSFER=1

# Create directories
RUN mkdir -p /models /scripts

# Set working directory
WORKDIR /

# Copy scripts
COPY build_llama.sh /scripts/build_llama.sh
COPY download_model.sh /scripts/download_model.sh
COPY entrypoint.sh /entrypoint.sh

# Make scripts executable
RUN chmod +x /scripts/build_llama.sh /scripts/download_model.sh /entrypoint.sh

# Expose llama-server default port
EXPOSE 8080

# Default environment variables
# Optimized for high throughput (16-32 concurrent requests)
ENV MODEL="" \
    HF_TOKEN="" \
    CTX_SIZE=4096 \
    MAX_TOKENS=2048 \
    PORT=8080 \
    PARALLEL=16 \
    BATCH_SIZE=2048 \
    UBATCH_SIZE=512

CMD ["/entrypoint.sh"]
