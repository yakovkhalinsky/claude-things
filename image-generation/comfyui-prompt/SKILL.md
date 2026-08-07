---
name: comfyui-prompt
title: ComfyUI Prompt Builder + Runner
description: Build valid ComfyUI API prompt JSON from natural-language requests, load workflow templates, and submit them directly to a running ComfyUI server.
version: 2.1.0
tags: [comfyui, image-generation, prompt-engineering, api, json, workflow]
harness: claude-code
tools:
  discoverable: true
  list:
    - Bash
    - Read
    - Write
---

# ComfyUI Prompt Builder + Runner

Help the user generate and **run** ComfyUI API prompts against the local ComfyUI instance at `http://localhost:8188`.

## What this skill does

- Translates a natural-language image-generation request into a valid ComfyUI prompt JSON graph.
- Loads an existing workflow template and patches the prompt text and parameters into it.
- Submits the prompt directly to ComfyUI via `/prompt`.
- Polls queue/history until the job finishes and reports the resulting `prompt_id`, outputs, and any errors.
- Remembers the last-used seed and asks whether to reuse, change, or randomise it.

## Base URL

Default: `http://localhost:8188`

Override per machine by setting `COMFYUI_BASE_URL` in a `.env.local` file at the project root. The skill and command use this value when present.

Example `.env.local`:
```bash
COMFYUI_BASE_URL=http://your-comfyui-host:8188
```

Do not commit `.env.local` to git.

## Required models for the bundled `z-image-turbo` workflow

The workflow `workflows/z-image-turbo.json` expects these files (relative to the ComfyUI root):

- `models/diffusion_models/z_image_turbo_bf16.safetensors`
- `models/vae/ae.safetensors`
- `models/clip/qwen_3_4b.safetensors`

If a user's local filenames differ, prompt them to edit the workflow or pass the correct names. Do not download copyrighted or unlicensed model files for the user; point them to official Hugging Face / Civitai sources.

## Seed policy

Every run must respect the user's choice for the random seed:

1. Before building the prompt, recall the most recent `comfyui_last_seed` memory from Eden-memory.
2. Present the last seed to the user and ask: **"Use last seed (<N>), enter a new seed, or randomise?"**
3. Act on their answer:
   - **"last" / reuse / blank / default** → use the recalled seed.
   - **A specific number** → use that number and remember it as `comfyui_last_seed`.
   - **"random" / "new"** → generate a new random positive 32-bit integer, use it, and remember it as `comfyui_last_seed`.
4. After the run succeeds, call `mcp__eden-memory__eden_remember` to store `comfyui_last_seed` with the seed actually used.

If no previous seed exists, generate a random one and tell the user what was chosen.

## Modes

### 1. Built-in minimal graph

If the user does not specify a template, build this graph:

- `CheckpointLoaderSimple`
- `CLIPTextEncode` (positive)
- `CLIPTextEncode` (negative)
- `EmptyLatentImage`
- `KSampler`
- `VAEDecode`
- `SaveImage`

Defaults:
- width: 512, height: 768 (or 768x512 for landscape subjects)
- steps: 20
- cfg: 7.0
- sampler_name: `euler`
- scheduler: `normal`
- seed: resolved via seed policy
- batch_size: 1

### 2. Workflow template

If the user says they are using a saved workflow or template (e.g. "z-image-turbo template"), locate the workflow JSON and load it. Workflow sources, in order of preference:

1. Path supplied by the user (project-relative or absolute).
2. A file inside `.claude/comfyui-workflows/` in the current project.
3. A ComfyUI built-in template fetched from `/api/workflow_templates/<namespace>/<name>`.
4. The ComfyUI `userdata` workflows directory.

If none of those resolve the template, ask the user to export/share the workflow JSON file.

## Patching a workflow template

Once a workflow JSON is loaded, patch the following fields based on the user's request:

1. Find text-encode nodes (`CLIPTextEncode`, `CLIPTextEncodeSDXL`, `TextEncodeZImageOmni`, etc.) and set their prompt string to the positive description.
2. Find any negative-prompt text-encode node and set it to a sensible negative prompt. If the template has no dedicated negative node, skip this step.
3. Find latent/image size nodes (`EmptyLatentImage`, `EmptySDXLLatentImage`, etc.) and set width, height, and batch_size.
4. Find the sampler/scheduler node (`KSampler`, `SamplerCustomAdvanced`, `SDTurboScheduler`, etc.) and set steps, cfg, sampler_name, scheduler, and seed if applicable.
5. If the workflow contains a checkpoint/UNET/model loader with a placeholder or missing model name and the user has not specified one, set it to `<your-model-name>` and warn the user.

Always preserve the original wiring (`["node_id", output_index]` references) when only changing input values.

## Image-to-image / editing workflows

When the user wants to edit or restyle an existing image:

1. Load the source image with `LoadImage`.
2. Encode it to latent space with `VAEEncode` (or `VAEEncodeForInpaint` if a mask is involved).
3. Feed the latent into the `KSampler` in place of `EmptyLatentImage`.
4. Set `denoise` between 0.3 (subtle) and 0.75 (strong restyle).
5. Keep the original prompt and adjust it to describe the desired edit.
6. Preserve the model/CLIP/VAE from the original workflow.

## Direct execution

To submit a prompt and wait for completion, use this procedure:

1. Write the final prompt graph to a temporary JSON file.
2. Generate a unique `client_id`, e.g. `claude-<timestamp>`.
3. POST to `/prompt`:
   ```bash
   curl -s -X POST ${COMFYUI_BASE_URL:-http://localhost:8188}/prompt \
     -H "Content-Type: application/json" \
     -d @- <<'JSON'
   {"prompt": <prompt_json>, "client_id": "<client_id>"}
   JSON
   ```
4. Parse `prompt_id` and `number` from the response. If the response contains `error`, report it and stop.
5. Poll `/history` until the prompt_id appears, or until a timeout (default 10 minutes). A job is done when the entry has `status.status === "completed"`, `status.completed === true`, or outputs are present. If `status.status === "error"` or `status.exception`, report the error.
6. Summarise outputs: filename prefixes, image count, and any saved file paths returned by `SaveImage` outputs.

## Inspect the server

Useful endpoints:

```bash
# System and device info
curl -s ${COMFYUI_BASE_URL:-http://localhost:8188}/system_stats | python3 -m json.tool

# All available node classes and their inputs/outputs
curl -s ${COMFYUI_BASE_URL:-http://localhost:8188}/object_info | python3 -m json.tool

# Specific node schema
curl -s ${COMFYUI_BASE_URL:-http://localhost:8188}/object_info/CheckpointLoaderSimple | python3 -m json.tool
curl -s ${COMFYUI_BASE_URL:-http://localhost:8188}/object_info/KSampler | python3 -m json.tool

# Installed models (may be empty for Comfy Desktop shared paths)
curl -s ${COMFYUI_BASE_URL:-http://localhost:8188}/api/models/checkpoints | python3 -m json.tool
curl -s ${COMFYUI_BASE_URL:-http://localhost:8188}/api/models/loras | python3 -m json.tool

# Built-in workflow templates
curl -s ${COMFYUI_BASE_URL:-http://localhost:8188}/api/workflow_templates | python3 -m json.tool

# Queue and history
curl -s ${COMFYUI_BASE_URL:-http://localhost:8188}/queue | python3 -m json.tool
curl -s ${COMFYUI_BASE_URL:-http://localhost:8188}/history | python3 -m json.tool
```

## Connection syntax

Node input references are `["node_id", output_index]`.

## Output format

When the user asks to generate an image, return:

1. The chosen seed and how it was chosen (last/new/random).
2. Summary of the workflow/template used and assumptions (model, sampler, resolution).
3. The final JSON prompt (optional — omit if very large and the user only wants the result).
4. The `prompt_id` and queue number from the submission.
5. Final status and output file names after polling completes.
6. Any errors encountered.
