---
name: obsidian
description: Interact with the user's Obsidian vault — read notes, capture and chunk tasks to inbox or daily note, search content. Use when the user wants to save something to Obsidian, plan a task, or run the task capture workflow. Triggers on: add this to obsidian, capture this task, add to inbox, put this in my vault, plan this in obsidian.
---

# Obsidian Vault Integration

## Setup

The CLI binary is at `~/.local/bin/obsidian`.

Always target the vault using the `OBSIDIAN_VAULT` environment variable:

```bash
obsidian vault="$OBSIDIAN_VAULT" <command>
```

If `OBSIDIAN_VAULT` is not set, run `obsidian vaults verbose` and ask the user to choose. Never assume the active vault.

The inbox note name comes from `OBSIDIAN_INBOX` (default: `Inbox`).

## Core Commands

```bash
# Read today's daily note
obsidian vault="$OBSIDIAN_VAULT" daily:read

# Append to today's daily note
obsidian vault="$OBSIDIAN_VAULT" daily:append content="..."

# Read the inbox (vault path + filesystem)
VAULT_PATH=$(obsidian vault="$OBSIDIAN_VAULT" vault info=path)
cat "$VAULT_PATH/${OBSIDIAN_INBOX:-Inbox}.md"

# Append to inbox
obsidian vault="$OBSIDIAN_VAULT" append file="${OBSIDIAN_INBOX:-Inbox}" content="..."

# Create a new note
obsidian vault="$OBSIDIAN_VAULT" create path="<folder>/<name>.md" content="..."

# Search vault
obsidian vault="$OBSIDIAN_VAULT" search query="..."

# List files
obsidian vault="$OBSIDIAN_VAULT" files

# Get vault path (useful for reading arbitrary files)
obsidian vault="$OBSIDIAN_VAULT" vault info=path
```

## Task Capture Workflow

This is the primary workflow — use it when the user wants to add, plan, or think through a task.

### Step 1: Brief Conversation (2–3 questions max)

Ask only what you need. Keep it natural, not an interrogation:

- **What is it?** One sentence description of the task.
- **What does done look like?** The concrete outcome — not perfect, just shipped.
- **Any blockers or context?** Dependencies, unknowns, constraints.

If the task is clearly scoped from context, skip questions and go straight to chunking.

### Step 2: Chunk with tsk Methodology

Break the task into three layers:

**Quick Wins** — under 10 minutes each, zero friction. The goal is to start moving, not to accomplish everything.

**Deep Work** — 30–60 minute focused blocks. Each must have a specific Definition of Done (DoD) so the user knows exactly when to stop.

**Stop Point (v1.0)** — a clear "good enough" line. State it explicitly. The user has permission to stop here. Do not add polish items beyond this line.

Rules:
- If a task exceeds 60 minutes, split it
- Every Deep Work item needs a DoD — no vague outcomes
- The Stop Point is non-negotiable. Name it. Protect it.

### Step 3: Choose Destination

Ask: **"Inbox or today's daily note?"**

- **Inbox** — for tasks to be prioritized later, ideas, backlog items
- **Daily note** — for tasks the user intends to work on today

### Step 4: Write to Vault

Format the output as a section in the note:

```markdown

## [Task Name]
> Added: {{YYYY-MM-DD}}

### Quick Wins
- [ ] ...
- [ ] ...

### Deep Work
- [ ] [Step] (DoD: [specific outcome])
- [ ] [Step] (DoD: [specific outcome])

### Stop Point (v1.0)
[One sentence describing "good enough". Remind the user they have permission to stop here.]
```

Use `\n` for line breaks in CLI content arguments.

**To inbox:**
```bash
obsidian vault="$OBSIDIAN_VAULT" append file="${OBSIDIAN_INBOX:-Inbox}" content="$(printf '...')"
```

**To daily note:**
```bash
obsidian vault="$OBSIDIAN_VAULT" daily:append content="$(printf '...')"
```

## Anti-Perfectionism Protocol

If the user starts expanding scope mid-capture ("oh and also we should..."):
1. Write the new idea as a **separate inbox item** — don't fold it into the current task
2. Protect the original Stop Point
3. Say so directly: "I've added that as a separate inbox item to keep this one focused."

If the user pushes back on the Stop Point:
- Acknowledge the impulse
- Hold the line: "That's v2.0. Let's ship v1.0 first."

## Environment Variables

| Variable | Default | Purpose |
|---|---|---|
| `OBSIDIAN_VAULT` | *(required)* | Vault name passed to every CLI command |
| `OBSIDIAN_INBOX` | `Inbox` | Note name used as the inbox |
