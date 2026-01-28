# llama.cpp Server Docker Image

A Docker image that runs [llama.cpp](https://github.com/ggml-org/llama.cpp) server with NVIDIA CUDA support. **Builds llama.cpp from source at every startup** to ensure you always have the latest version.

## Features

- **Always Latest**: Clones and compiles llama.cpp at container startup
- **CUDA Accelerated**: Full GPU offloading for maximum performance
- **Auto Model Download**: Specify a HuggingFace model ID and it downloads automatically
- **Split GGUF Support**: Handles multi-part GGUF files seamlessly
- **OpenAI Compatible**: Drop-in replacement for OpenAI API

## Quick Start

```bash
docker run -d --gpus all \
  -e MODEL="ggml-org/gemma-3-1b-it-GGUF" \
  -p 8080:8080 \
  ghcr.io/USERNAME/llama-cpp-server:latest
```

Replace `USERNAME` with your GitHub username.

## Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `MODEL` | Yes | - | HuggingFace model ID (see formats below) |
| `HF_TOKEN` | No | - | HuggingFace token for gated models (Llama 3, etc.) |
| `CTX_SIZE` | No | 4096 | Context window size |
| `MAX_TOKENS` | No | 2048 | Max tokens to generate per request |
| `PORT` | No | 8080 | Server port |
| `PARALLEL` | No | 16 | Number of parallel slots (concurrent requests) |
| `BATCH_SIZE` | No | 2048 | Logical batch size for prompt processing |
| `UBATCH_SIZE` | No | 512 | Physical batch size (tokens processed per step) |

## Batching Optimizations

This image uses llama.cpp's default optimizations for high-throughput batch inference:

- **Continuous Batching**: Enabled by default - dynamically batches incoming requests
- **Flash Attention**: Auto mode (default) - automatically enables when beneficial
- **Parallel Slots**: 16 concurrent requests by default (tune with `PARALLEL`)
- **Batch Sizes**: Default 2048/512 - tune `BATCH_SIZE` and `UBATCH_SIZE` for your GPU memory

**Important**: Total KV cache memory = `CTX_SIZE * PARALLEL`. For heavy load with 16 slots and 4096 context, you'll need GPU memory for 65K tokens of KV cache.

## Model Format

The `MODEL` environment variable supports two formats:

### With Quantization Filter
```bash
MODEL="TheBloke/Llama-2-7B-GGUF:Q4_K_M"
```
Downloads only files matching `*Q4_K_M*.gguf`

### Auto-Select
```bash
MODEL="ggml-org/gemma-3-1b-it-GGUF"
```
Downloads all GGUF files and auto-selects the appropriate one.

## API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/v1/chat/completions` | POST | Chat completions (OpenAI compatible) |
| `/v1/completions` | POST | Text completions |
| `/health` | GET | Health check |

## Example: Chat Completion

```bash
curl http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "any",
    "messages": [
      {"role": "user", "content": "Hello!"}
    ]
  }'
```

## Persistent Models

Mount a volume to `/models` to persist downloaded models across container restarts:

```bash
docker run -d --gpus all \
  -e MODEL="TheBloke/Llama-2-7B-GGUF:Q4_K_M" \
  -v ./models:/models \
  -p 8080:8080 \
  ghcr.io/USERNAME/llama-cpp-server:latest
```

## Startup Time

| Phase | Time |
|-------|------|
| CUDA check | ~5 seconds |
| Clone llama.cpp | ~10 seconds |
| Compile llama.cpp | 5-15 minutes |
| Download model | 1-30 minutes (depends on size) |

**First startup total: 6-45 minutes**

Subsequent starts (with persisted models) are faster since models are cached.

## Building Locally

```bash
docker build -t llama-cpp-server .
```

## License

MIT
