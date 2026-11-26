# Hermes Kanban Swarm Profile Templates

This directory contains **declarative starter templates** for Hermes Agent profiles used by `jl kanban-swarm`.

> **Prime Directive #3 (State vs. Config):** These files are **templates**—they are copied into `~/.hermes/profiles/<name>/` (writable host state) rather than symlinked read-only from `/nix/store`. Secrets live strictly in `~/.hermes/profiles/<name>/.env` or `~/.bashrc.local` and are never committed to Git.

## Included Profiles

| Profile | Backend / Provider | Default Model | Credentials Needed | Best Role |
| :--- | :--- | :--- | :--- | :--- |
| **`agy-neon-medium`** *(Default)* | Nous Portal loop + `agy -p` (Gemini 4 Neon Medium) | `stealth/space-bunny-alpha` + `agy` | Nous OAuth + `agy` login (zero API keys) | Default all-rounder, Architect, Synthesizer |
| **`claude-api`** | Direct Anthropic API | `claude-sonnet-4-20250514` | `ANTHROPIC_API_KEY` | High-precision Coder, Verifier / Reviewer |
| **`local-opencode`** | Local Ollama + OpenCode CLI | `qwen2.5-coder:7b` | None (`jl up-llm`) | Offline / private coding worker |
| **`local-ollama`** | Local Ollama (direct) | `qwen2.5-coder:7b` | None (`jl up-llm`) | Air-gapped worker / Container `MODE="local"` |
| **`openrouter-fast`** | OpenRouter | `google/gemini-2.5-flash` | `OPENROUTER_API_KEY` | Fast, low-cost parallel workers |

## Setup

```bash
# 1. Seed all sample profiles into ~/.hermes/profiles/ (non-destructive; won't overwrite existing files)
jl kanban-init-profiles

# 2. List installed profiles & available templates
jl kanban-profiles

# 3. Add API tokens for cloud profiles (or export them in ~/.bashrc.local)
cp ~/.hermes/profiles/claude-api/.env.example ~/.hermes/profiles/claude-api/.env
$EDITOR ~/.hermes/profiles/claude-api/.env
```
