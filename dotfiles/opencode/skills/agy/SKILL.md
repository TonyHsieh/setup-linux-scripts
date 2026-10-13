---
name: agy
description: Run prompts, tasks, deep reasoning, and ecosystem workflows using the Google Antigravity (AGY) CLI (`agy`). Use this skill whenever the user asks to run an agy command, consult Antigravity, delegate complex architectural analysis, or interact with Google Cloud/Antigravity features.
---

# Google Antigravity (AGY) CLI Skill

This skill enables OpenCode to delegate tasks, queries, and deep multi-step reasoning to the **Google Antigravity CLI (`agy`)**.

## Primary Capabilities
- **Deep Architectural & Code Review**: Delegate complex refactoring or multi-file design evaluations to `agy`'s reasoning engine.
- **Google Cloud Platform (GCP) Operations**: Query BigQuery, Cloud Storage, Spanner, and GCP data pipelines using Antigravity's specialized built-in skills.
- **Autonomous Task Execution**: Run background research, code searches, or system verifications.

---

## How to Execute `agy` from OpenCode
OpenCode invokes `agy` using the built-in `bash` tool in non-interactive print mode (`-p` / `--print`).

### 1. Non-Interactive Text Query (Default)
Run a prompt and return the formatted response:
```bash
agy -p "<prompt>" --output-format text
```

### 2. Structured JSON Output
When programmatic parsing of the response is required:
```bash
agy -p "<prompt>" --output-format json
```

### 3. Execution Rules & Best Practices
- **Always specify `-p` (or `--print`)**: Without `-p`, `agy` will attempt to launch an interactive TUI session, which will block or hang OpenCode's bash tool.
- **Auto-Approval of Tool Permissions**: If `agy` needs to run non-interactively without prompting for confirmation on read tools, pass `--dangerously-skip-permissions`:
  ```bash
  agy -p "<prompt>" --dangerously-skip-permissions --output-format text
  ```
- **Timeouts**: For long-running queries, specify a timeout with `--print-timeout <duration>` (e.g. `--print-timeout 180s`).
- **Workspace Directory**: `agy` automatically operates within the current working directory, so it has access to local project files.
- **Context Forwarding**: When delegating a task to `agy`, include relevant file paths or error messages in the prompt argument so `agy` has full context.
