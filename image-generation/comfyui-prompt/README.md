# comfyui-prompt

A Claude Code skill that turns natural-language image-generation requests into ComfyUI API prompt JSON and runs them.

## What it does

- Builds a minimal ComfyUI graph from a description, or patches an existing workflow template.
- Submits the prompt to a running ComfyUI server.
- Polls the queue/history until the job finishes.
- Remembers the last seed and lets you reuse, change, or randomise it.

## Requirements

- Claude Code launched from this project directory.
- A ComfyUI server reachable at `http://localhost:8188` by default, or configure a different host via `COMFYUI_BASE_URL` in `.env.local`.
- For the bundled `z-image-turbo` template, the model files listed below.

## Setup

### 1. Install ComfyUI

Download and run ComfyUI for your platform:

- Desktop: https://comfy.org/download
- Git / manual: https://github.com/comfyanonymous/ComfyUI

### 2. Get the model files for the `z-image-turbo` workflow

Place each file in the folder shown (paths are relative to the ComfyUI root):

| File | What it is | Where to put it |
|------|------------|-----------------|
| `z_image_turbo_bf16.safetensors` | AuraFlow / Lumina2-style turbo diffusion model | `models/diffusion_models/` |
| `ae.safetensors` | Autoencoder used by the turbo model | `models/vae/` |
| `qwen_3_4b.safetensors` | Qwen CLIP text encoder | `models/clip/` |

Search Hugging Face / Civitai for the exact filenames. Typical sources:

- `z_image_turbo_bf16.safetensors` — look for Kijai's z-image-turbo release.
- `ae.safetensors` — Stable Diffusion 3 / Flux autoencoder.
- `qwen_3_4b.safetensors` — Qwen 2.5-VL or Lumina2-compatible CLIP.

If the filenames in your local install differ, edit `workflows/z-image-turbo.json` or tell the skill/command which model names to use.

### 3. Start ComfyUI

Launch ComfyUI so it is reachable at `http://localhost:8188`. If your host is different (for example, ComfyUI on another machine), create a `.env.local` file at the project root:

```bash
COMFYUI_BASE_URL=http://your-comfyui-host:8188
```

The skill and command will use this value automatically. Do not commit `.env.local` to git.

### 4. Load the project into Claude Code

Open this project directory in Claude Code, then restart it so the local skill and command are registered.

## Files

| File | Purpose |
|------|---------|
| `SKILL.md` | Claude Code skill definition |
| `command.md` | Claude Code slash command `/comfy-prompt` |
| `command-serve-output.md` | Claude Code slash command `/comfyui-serve-output` (opt-in local file server) |
| `workflows/z-image-turbo.json` | Example AuraFlow/Lumina2 turbo workflow |
| `examples/` | Local example outputs (not committed; generated on demand) |

## Usage

Restart Claude Code so the project-local skill is loaded, then ask:

```text
Generate a polar bear in a 1950s diner using the z-image-turbo template.
```

Or use the companion slash command:

```text
/comfy-prompt a polar bear in a 1950s diner eating a burger and fries
```

## See also

- `command.md` — the slash-command version in this same asset folder.
