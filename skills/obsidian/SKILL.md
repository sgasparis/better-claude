---
name: obsidian
description: Interact with the user's Obsidian vault — read notes, capture and chunk tasks to inbox or daily note, search content. Use when the user wants to save something to Obsidian, plan a task, or run the task capture workflow. Triggers on: add this to obsidian, capture this task, add to inbox, put this in my vault, plan this in obsidian.
---

# Obsidian Vault Integration

## Setup

Two environment variables control vault access. Check which are set before running any command:

| Variable | Required | Purpose |
|---|---|---|
| `OBSIDIAN_VAULT` | For CLI mode | Vault name passed to the obsidian CLI |
| `OBSIDIAN_VAULT_PATH` | For file mode | Absolute filesystem path to the vault root |
| `OBSIDIAN_INBOX` | No (default: `Inbox`) | Inbox note name |

**Mode selection — run this check first:**
```bash
if command -v obsidian &>/dev/null || [ -f ~/.local/bin/obsidian ]; then
  echo "CLI mode available"
else
  echo "File mode only — use OBSIDIAN_VAULT_PATH"
fi
```

If neither `OBSIDIAN_VAULT` nor `OBSIDIAN_VAULT_PATH` is set, stop and ask the user to run `install.sh --global` first.

## Core Commands

### CLI Mode (Linux/macOS — obsidian CLI connected to running Obsidian app)

```bash
OBS=$(command -v obsidian 2>/dev/null || echo ~/.local/bin/obsidian)

# Read today's daily note
"$OBS" vault="$OBSIDIAN_VAULT" daily:read

# Append to today's daily note
"$OBS" vault="$OBSIDIAN_VAULT" daily:append content="..."

# Read the inbox
"$OBS" vault="$OBSIDIAN_VAULT" read file="${OBSIDIAN_INBOX:-Inbox}"

# Append to inbox
"$OBS" vault="$OBSIDIAN_VAULT" append file="${OBSIDIAN_INBOX:-Inbox}" content="..."

# Create a new note
"$OBS" vault="$OBSIDIAN_VAULT" create path="<folder>/<name>.md" content="..."

# Search vault
"$OBS" vault="$OBSIDIAN_VAULT" search query="..."
```

### File Mode (WSL / no CLI — direct filesystem access via OBSIDIAN_VAULT_PATH)

```bash
VAULT="${OBSIDIAN_VAULT_PATH}"
INBOX="$VAULT/${OBSIDIAN_INBOX:-Inbox}.md"
TODAY="$VAULT/$(date +%Y-%m-%d).md"  # adjust path if daily notes are in a subfolder

# Read inbox
cat "$INBOX"

# Append to inbox
printf "\n%s" "..." >> "$INBOX"

# Read today's daily note
cat "$TODAY"

# Append to today's daily note
printf "\n%s" "..." >> "$TODAY"

# Create a new note
printf "%s" "..." > "$VAULT/<folder>/<name>.md"

# Search vault
grep -rl "query" "$VAULT" --include="*.md"
```

**Daily note path:** If the user has daily notes in a subfolder (e.g., `Journal/`), use `$VAULT/Journal/$(date +%Y-%m-%d).md`. Ask the user if unsure.

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
| `OBSIDIAN_VAULT` | *(required for CLI mode)* | Vault name passed to obsidian CLI commands |
| `OBSIDIAN_VAULT_PATH` | *(required for file mode)* | Absolute filesystem path to vault root |
| `OBSIDIAN_INBOX` | `Inbox` | Note name used as the inbox |
