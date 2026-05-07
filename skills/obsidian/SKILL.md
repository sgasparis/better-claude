---
name: obsidian
description: Interact with the user's Obsidian vault — read notes, capture and chunk tasks to inbox or daily note using Obsidian Tasks plugin syntax (priorities, dependencies, tags). Use when the user wants to save something to Obsidian, plan a task, or run the task capture workflow. Triggers on: add this to obsidian, capture this task, add to inbox, put this in my vault, plan this in obsidian, add dependencies, tag this task.
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

## Tasks Plugin Syntax

The Obsidian Tasks community plugin extends `- [ ]` checkboxes with structured metadata on the same line.

### Priority

| Emoji | Level |
|---|---|
| `⏫` | Highest |
| `🔼` | High |
| *(none)* | Normal |
| `🔽` | Low |
| `⏬` | Lowest |

### Dates

```
📅 YYYY-MM-DD   due date
⏳ YYYY-MM-DD   scheduled (earliest to work on)
🛫 YYYY-MM-DD   start date
🔁 every week   recurrence
```

### Dependencies

Each task can carry a unique ID. Other tasks declare they are blocked by it:

```
🆔 <id>         assigns this task an ID (must be unique across the vault)
⛔ <id>         this task is blocked until the task with that ID is complete
```

IDs can be short slugs (`setup-db`, `api-impl`) or random 6-char strings. Make them human-readable when tasks are in the same group so the relationship is obvious.

Multiple blockers: `⛔ id1,id2`

### Tags

Standard Obsidian tags anywhere in the line: `#project #context`

### Full example line

```markdown
- [ ] Build the API endpoint ⛔ setup-db 🆔 api-impl 🔼 📅 2026-05-10 #backend #workflow
```

---

## Task Capture Workflow

This is the primary workflow — use it when the user wants to add, plan, or think through a task.

### Step 1: Brief Conversation (2–3 questions max)

Ask only what you need. Keep it natural, not an interrogation:

- **What is it?** One sentence description of the task.
- **What does done look like?** The concrete outcome — not perfect, just shipped.
- **Tags?** What project or context label should these tasks carry? (e.g. `#work`, `#infra`, `#personal`)
- **Any blockers or context?** External dependencies, unknowns, constraints.

If the task is clearly scoped from context, skip questions and go straight to chunking.

### Step 2: Chunk with tsk Methodology

Break the task into three layers:

**Quick Wins** — under 10 minutes each, zero friction. Priority: `🔽` Low. No dependencies, no IDs needed unless a Deep Work step depends on one.

**Deep Work** — 30–60 minute focused blocks. Priority: Normal or `🔼` High. Assign a `🆔 <slug-id>` to any step that a later step depends on. Chain them with `⛔`.

**Stop Point (v1.0)** — a clear "good enough" line. State it explicitly. The user has permission to stop here. Do not add polish items beyond this line.

Rules:
- If a task exceeds 60 minutes, split it
- Every Deep Work item needs a DoD — no vague outcomes
- The Stop Point is non-negotiable. Name it. Protect it.
- IDs must be unique across the vault — use descriptive slugs tied to the task name

### Step 3: Choose Destination

Ask: **"Inbox or today's daily note?"**

- **Inbox** — for tasks to be prioritized later, ideas, backlog items
- **Daily note** — for tasks the user intends to work on today

### Step 4: Write to Vault

Format the output using Tasks plugin syntax. Every task line gets: priority + IDs/blockers (if any) + tags.

```markdown

## [Task Name]
> Added: {{YYYY-MM-DD}}

### Quick Wins
- [ ] [action] 🔽 #tag
- [ ] [action] 🔽 #tag

### Deep Work
- [ ] [Step 1 — no dependency] 🆔 task-step1 #tag
  > DoD: [specific, verifiable outcome]
- [ ] [Step 2 — depends on step 1] ⛔ task-step1 🆔 task-step2 🔼 #tag
  > DoD: [specific, verifiable outcome]
- [ ] [Step 3 — depends on step 2] ⛔ task-step2 #tag
  > DoD: [specific, verifiable outcome]

### Stop Point (v1.0)
> [One sentence: what "good enough" looks like. Remind the user they have permission to stop here.]
```

**Only add dates if the user mentioned a deadline or target.** Don't invent due dates.

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
