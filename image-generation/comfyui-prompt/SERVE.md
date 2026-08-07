---
description: Serve generated example images from this project on a local HTTP server
argument-hint: [port, defaults to 8765]
allowed-tools:
  - Bash
  - Read
  - Write
---

# /serve-examples

Start a lightweight local HTTP server so you can browse example outputs in a browser. This is **opt-in**; nothing is served unless you run this command.

## Steps

1. Parse `$ARGUMENTS` for an optional port number. Default is `8765`.
2. Check whether a server is already running on that port.
3. If not, start `python3 -m http.server <port>` from the project root.
4. Report:
   - The root URL, e.g. `http://localhost:8765/`
   - The URL to the comfyui-prompt examples, e.g. `http://localhost:8765/image-generation/comfyui-prompt/examples/`
   - How to stop it: `kill $(cat /tmp/claude-things-http.pid)`

## Notes

- Serves the whole project root, not just examples. Useful for browsing any file in the repo.
- Stops when Claude Code exits unless you detach it manually.
- Do not expose this port to the public internet.

## Example

```text
/serve-examples 8765
```

Assistant:

```
Local server running at http://localhost:8765/
Browse examples: http://localhost:8765/image-generation/comfyui-prompt/examples/
Stop: kill $(cat /tmp/claude-things-http.pid)
```
