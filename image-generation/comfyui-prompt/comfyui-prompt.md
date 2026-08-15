---
description: Generate and run a ComfyUI image from a natural-language request
argument-hint: [description of the image you want to generate]
allowed-tools:
  - Bash
  - Read
  - Write
  - mcp__eden-memory__eden_recall
  - mcp__eden-memory__eden_remember
---

# /comfyui-prompt

Generate a ComfyUI API prompt from the user's description and submit it to the configured ComfyUI server.

## Steps

1. Parse `$ARGUMENTS` as the image-generation request. If empty, ask the user what they want to generate.
2. **Recall the last seed** by calling `mcp__eden-memory__eden_recall` with query `comfyui_last_seed`.
3. Ask the user:
   - "Last seed was **<last-seed>**. Use [last], enter a new seed, or [random]?"
   - If no last seed exists, say: "No previous seed. I'll use a random seed unless you enter one."
4. Resolve the seed:
   - "last" / blank / reuse → use the recalled seed.
   - A number → use that number and remember it as `comfyui_last_seed`.
   - "random" / "new" → generate a random positive 32-bit integer and remember it as `comfyui_last_seed`.
5. Determine the workflow source:
   - If the user mentions a template or workflow file (e.g. "z-image-turbo template"), try to load it:
     - A path supplied in the arguments.
     - `.claude/comfyui-workflows/<name>.json` in the current project.
     - ComfyUI built-in templates via `/api/workflow_templates`.
     - ComfyUI userdata workflows.
   - If the template cannot be found, ask the user to provide the workflow JSON file.
   - If no template is mentioned, use the built-in minimal graph from the skill.
6. Build or patch the workflow:
   - Set the positive prompt text from the user's description.
   - Set a sensible negative prompt.
   - Set width/height (default 512x768, landscape 768x512 if the scene calls for it).
   - Set sampler parameters: steps 20, cfg 7.0, sampler_name `euler`, scheduler `normal`, batch_size 1.
   - Inject the resolved seed.
   - Preserve all node wiring.
7. If the workflow needs a checkpoint/model name and the user did not supply one, use a placeholder and warn the user.
8. Write the final prompt graph to `/tmp/comfy_prompt.json`.
9. Submit to ComfyUI:
   ```bash
   CLIENT_ID="claude-$(date +%s)"
   curl -s -X POST ${COMFYUI_BASE_URL:-http://localhost:8188}/prompt \
     -H "Content-Type: application/json" \
     -d "{\"prompt\": $(cat /tmp/comfy_prompt.json), \"client_id\": \"${CLIENT_ID}\"}" \
     | python3 -m json.tool
   ```
10. Parse `prompt_id` from the response. If the server returned an error, report it and stop.
11. Poll `/history` for up to 10 minutes until the prompt completes or errors.
12. Report:
    - Chosen seed and how it was selected.
    - Workflow/template used.
    - `prompt_id` and queue number.
    - Final status and output file names.
    - Any errors encountered.
13. After a successful run, call `mcp__eden-memory__eden_remember` with `comfyui_last_seed` set to the seed actually used.

## Example interaction

```text
/comfyui-prompt a polar bear sitting in a 60s diner eating a burger and fries
```

Assistant:
> Last seed was **987654321**. Use [last], enter a new seed, or [random]?

User replies: `random`

Assistant runs the workflow and reports:

```
Seed: 2847391021 (random)
Workflow: z-image-turbo
Resolution: 1024x1024, steps: 8, cfg: 1.0, sampler: res_multistep/simple
Submitted: prompt_id=abc-123, queue number 0
Status: completed
Outputs: polar-diner_00001_.png
```
