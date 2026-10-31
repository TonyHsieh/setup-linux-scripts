---
name: save-current-context
description: >-
  Captures all session progress, architectural changes, environment state, and prioritized next steps into a standalone <YYYY-MM-DD-HHMM>-context.html report in the context/ directory for seamless tomorrow/future session resumption.
  Use when the user asks to "save context", "save current context", "checkpoint progress", "save session for tomorrow", or "prepare for resumption".
---

# Save Current Context Skill

This skill captures the complete technical context, architecture decisions, solved problems, active service endpoints, and actionable next steps of the current work session into an attractive, standalone HTML document formatted as `<YYYY-MM-DD-HHMM>-context.html` in the `context/` directory of the workspace (`context/<YYYY-MM-DD-HHMM>-context.html`).

This document serves as the single source of truth for the user and future AI agent sessions to resume work without losing context or momentum.

---

## Workflow & Step-by-Step Procedure

### Step 1: Collect System & Project State
Run non-destructive diagnostic commands to collect the exact environment state:
1. **Timestamp:** `date +"%Y-%m-%d-%H%M"` and human-readable timestamp (e.g., `2026-10-31 01:25 (US/Pacific)`).
2. **Git Metadata:**
   - Current branch and working directory clean/dirty state (`git status -s`).
   - Latest commit SHA (`git rev-parse --short HEAD`) and recent commit summary (`git log -n 5 --oneline`).
3. **Host & Runtime Environment:**
   - User name (`whoami`), host machine (`hostname` or `/etc/hostname`), OS distribution (`cat /etc/os-release` or WSL indicator).
   - Package manager and toolchains (e.g., Nix Flakes, Home Manager, Podman, Docker, Devenv).
4. **Active Services & Containers:**
   - Running container services, exposed ports, and health status (`podman ps` or `docker compose ps`).
   - Remote mesh or ingress endpoints (e.g., Tailscale MagicDNS addresses, local `*.localhost` domains).

### Step 2: Synthesize Accomplishments & Solved Incidents
Extract from the current conversation and git diff:
1. **Critical Milestones Achieved:** Features built, services deployed, configuration changes applied.
2. **Technical Incidents / Root Cause Resolutions:**
   - Specific failure mechanisms diagnosed (e.g., PTY recursion, missing compose profiles, Docker credential helper mismatches, port 80/443 refusals).
   - Permanent code/architecture fixes implemented to prevent recurrence.
3. **Configuration & Parameterization Updates:**
   - Environment variables introduced or updated (`TS_MACHINE_ID`, `.env`, `serve-*.json`).
   - Declarative package updates (`flake.nix`, `home-manager`).

### Step 3: Establish Prioritized Resumption Plan
Review existing project roadmaps (`plan.md`, `ROADMAP.md`, `TODO.md`), or formulate the concrete next steps:
1. **High Priority (Immediate Next Step):** The exact task to execute upon resumption, including copy-paste shell commands and verification steps.
2. **Medium Priority (Quality of Life / Testing):** Integration tests, multi-device verification, or workflow optimizations.
3. **Lower Priority / Future Milestones:** Cross-machine synchronization, documentation, or downstream features.

### Step 4: Generate `context/<YYYY-MM-DD-HHMM>-context.html`
Ensure the `context/` directory exists (`mkdir -p context`). Write the file directly into `context/<YYYY-MM-DD-HHMM>-context.html`. The HTML file must be **self-contained** (inline CSS, embedded Google Fonts via CDN, no external local asset dependencies) so it renders identically in any browser.

#### Required HTML Layout & Structure:
* **Typography:** `Inter` for body text, `JetBrains Mono` for monospace code.
* **Theme:** Professional dark slate palette (`#0f172a` primary, `#1e293b` cards, `#38bdf8` accent blue, `#34d399` emerald green, `#818cf8` indigo).
* **Section 1: Header & Status Badge:** Session title, timestamp, host metadata, and high-level health badge.
* **Section 2: System Overview & Metrics Grid:** 3-column card grid showing Workspace Environment, Declarative Stack, and Multi-Machine Matrix.
* **Section 3: Incident Report / Key Technical Accomplishments:** Alert boxes and structured tables detailing root causes and permanent fixes.
* **Section 4: Feature Status & Endpoints Matrix:** Complete table of local and remote URLs, container names, and security/auth status.
* **Section 5: Prioritized Resumption Checklist:** Numbered step cards with priority badges (`HIGH`, `MEDIUM`, `NEXT MACHINE`) and copy-paste shell command blocks.
* **Section 6: Git Commit & File Audit:** Table of recent commit SHAs, commit messages, and key changed files.
* **Footer:** Generation timestamp and tool signature.

### Step 5: Verification & User Confirmation
1. Verify the file exists in the `context/` directory and is non-empty.
2. Provide the user with a clickable link to `[context/<date>-<time>-context.html](file:///<path-to-workspace>/context/<date>-<time>-context.html)`.
3. Provide a concise 3-bullet summary of where things stand and the #1 recommended action item for tomorrow.
