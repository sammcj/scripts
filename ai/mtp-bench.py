from mlx_lm import load
from mlx_lm.generate import stream_generate
from pathlib import Path

result = load(str(Path.home() / ".lmstudio/models/local/Qwen3.5-122B-A10B-MLX-4bit-MTP"))
model, tokenizer = result[0], result[1]

messages = [
    {"role": "user", "content": "Explain the concept of recursion in programming with a simple example."},
]
prompt = tokenizer.apply_chat_template(messages, tokenize=False, add_generation_prompt=True)

# Warm up both paths
for resp in stream_generate(model, tokenizer, prompt=prompt, max_tokens=5):
    pass
for resp in stream_generate(model, tokenizer, prompt=prompt, max_tokens=5, mtp=True):
    pass

# Benchmark no MTP (3 runs)
for i in range(3):
    for resp in stream_generate(model, tokenizer, prompt=prompt, max_tokens=200):
        pass
    print(f"No MTP  run {i + 1}: gen={resp.generation_tps:.1f} tok/s, prompt={resp.prompt_tps:.1f} tok/s")

# Benchmark MTP (3 runs)
for i in range(3):
    for resp in stream_generate(model, tokenizer, prompt=prompt, max_tokens=200, mtp=True):
        pass
    print(f"With MTP run {i + 1}: gen={resp.generation_tps:.1f} tok/s, prompt={resp.prompt_tps:.1f} tok/s")
