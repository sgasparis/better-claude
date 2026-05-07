#!/bin/bash
set -e

MODE=${1:-""}
PROJECT_PATH=""

usage() {
  echo "Usage: bash install.sh [--global | --project [--path <dir>]]"
  echo ""
  echo "  --global        Install agents, skills, and CLAUDE.md to ~/.claude/ (affects all projects)"
  echo "  --project       Install agents and skills into a project directory"
  echo "  --path <dir>    Target directory for project install (default: current directory)"
  echo ""
  echo "If no flag is provided, you will be prompted to choose."
}

if [ "$MODE" = "--help" ] || [ "$MODE" = "-h" ]; then
  usage
  exit 0
fi

# Parse flags
while [ $# -gt 0 ]; do
  case "$1" in
    --global)  MODE="--global"; shift ;;
    --project) MODE="--project"; shift ;;
    --path)    PROJECT_PATH="$2"; shift 2 ;;
    --help|-h) usage; exit 0 ;;
    *)         echo "Unknown option: $1"; usage; exit 1 ;;
  esac
done

if [ -z "$MODE" ]; then
  echo "Where would you like to install?"
  echo "  1) Global (~/.claude/) — available in all projects"
  echo "  2) Project (.claude/)  — specific project directory"
  read -rp "Choose [1/2]: " choice
  case "$choice" in
    1) MODE="--global" ;;
    2)
      MODE="--project"
      read -rp "Project path [default: current directory]: " input_path
      if [ -n "$input_path" ]; then
        PROJECT_PATH="$input_path"
      fi
      ;;
    *) echo "Invalid choice."; exit 1 ;;
  esac
fi

# Resolve project target dir
if [ "$MODE" = "--project" ]; then
  if [ -z "$PROJECT_PATH" ]; then
    PROJECT_DIR="$(pwd)"
  else
    PROJECT_DIR="$(realpath "$PROJECT_PATH")"
  fi
fi

install_agents() {
  local dest="$1"
  if [ -d "agency-agents" ]; then
    if [ "$dest" = "global" ]; then
      mkdir -p ~/.claude/agents
      cd agency-agents && bash scripts/install.sh --tool claude-code 2>&1 | grep -E "OK|Error|agents" && cd ..
    else
      mkdir -p "$PROJECT_DIR/.claude/agents"
      cp -r agency-agents/engineering agency-agents/design agency-agents/marketing \
            agency-agents/product agency-agents/testing agency-agents/specialized \
            "$PROJECT_DIR/.claude/agents/" 2>/dev/null || true
      echo "[OK] Agents -> $PROJECT_DIR/.claude/agents/"
    fi
  else
    echo "Warning: agency-agents submodule not found. Run: git submodule update --init"
  fi
}

install_skills() {
  local dest="$1"
  local target
  if [ "$dest" = "global" ]; then
    target=~/.claude/skills
  else
    target="$PROJECT_DIR/.claude/skills"
  fi
  mkdir -p "$target"
  for skill_dir in skills/*/; do
    skill_name=$(basename "$skill_dir")
    mkdir -p "$target/$skill_name"
    cp "$skill_dir/SKILL.md" "$target/$skill_name/SKILL.md"
    echo "[OK] Skill: $skill_name -> $target/$skill_name"
  done
}

install_claude_md() {
  local dest="$1"
  if [ ! -f "CLAUDE.md" ]; then return; fi

  if [ "$dest" = "global" ]; then
    if [ -f ~/.claude/CLAUDE.md ]; then
      echo ""
      echo "Warning: ~/.claude/CLAUDE.md already exists."
      read -rp "Overwrite? [y/N]: " confirm
      if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Skipped CLAUDE.md"
        return
      fi
    fi
    cp CLAUDE.md ~/.claude/CLAUDE.md
    echo "[OK] CLAUDE.md -> ~/.claude/CLAUDE.md"
  else
    local project_claude_md="$PROJECT_DIR/.claude/CLAUDE.md"
    local project_root_claude_md="$PROJECT_DIR/CLAUDE.md"
    if [ -f "$project_claude_md" ] || [ -f "$project_root_claude_md" ]; then
      echo ""
      echo "Warning: A CLAUDE.md already exists in $PROJECT_DIR."
      read -rp "Overwrite? [y/N]: " confirm
      if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Skipped CLAUDE.md"
        return
      fi
    fi
    mkdir -p "$PROJECT_DIR/.claude"
    cp CLAUDE.md "$project_claude_md"
    echo "[OK] CLAUDE.md -> $project_claude_md"
  fi
}

install_ralph() {
  mkdir -p ~/.local/bin
  cp ralph ~/.local/bin/ralph
  chmod +x ~/.local/bin/ralph
  echo "[OK] ralph -> ~/.local/bin/ralph"
  if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    echo ""
    echo "Note: Add ~/.local/bin to your PATH:"
    echo '  export PATH="$HOME/.local/bin:$PATH"'
  fi
}

_is_wsl() {
  grep -qi "microsoft\|WSL" /proc/version 2>/dev/null
}

_find_obsidian_json() {
  # Linux snap
  if [ -f "$HOME/snap/obsidian/current/.config/obsidian/obsidian.json" ]; then
    echo "$HOME/snap/obsidian/current/.config/obsidian/obsidian.json"; return
  fi
  # Linux standard / flatpak
  if [ -f "$HOME/.config/obsidian/obsidian.json" ]; then
    echo "$HOME/.config/obsidian/obsidian.json"; return
  fi
  # macOS
  if [ -f "$HOME/Library/Application Support/obsidian/obsidian.json" ]; then
    echo "$HOME/Library/Application Support/obsidian/obsidian.json"; return
  fi
  # WSL — read from Windows AppData
  if _is_wsl; then
    local win_user
    win_user=$(cmd.exe /c "echo %USERNAME%" 2>/dev/null | tr -d '\r\n')
    local win_config="/mnt/c/Users/$win_user/AppData/Roaming/obsidian/obsidian.json"
    [ -f "$win_config" ] && echo "$win_config"
  fi
}

setup_obsidian() {
  echo ""
  echo "--- Obsidian Vault Setup ---"

  # Check if already configured
  if [ -n "$OBSIDIAN_VAULT" ]; then
    echo "OBSIDIAN_VAULT is already set to: $OBSIDIAN_VAULT"
    read -rp "Reconfigure? [y/N]: " reconf
    [[ ! "$reconf" =~ ^[Yy]$ ]] && return
  fi

  local is_wsl=false
  _is_wsl && is_wsl=true

  local obsidian_json
  obsidian_json=$(_find_obsidian_json)

  # List vaults and capture name→path pairs
  echo ""
  echo "Available vaults:"
  local vault_list=""
  if [ -n "$obsidian_json" ] && command -v python3 &>/dev/null; then
    vault_list=$(python3 - "$obsidian_json" "$is_wsl" <<'PYEOF'
import json, sys, os, re

obsidian_json, is_wsl_str = sys.argv[1], sys.argv[2]
is_wsl = is_wsl_str == "true"

def win_to_wsl(path):
    path = path.replace("\\", "/")
    m = re.match(r"^([A-Za-z]):/(.+)", path)
    return f"/mnt/{m.group(1).lower()}/{m.group(2)}" if m else path

data = json.load(open(obsidian_json))
for v in data.get("vaults", {}).values():
    raw = v.get("path", "")
    resolved = win_to_wsl(raw) if is_wsl else raw
    name = os.path.basename(raw.replace("\\", "/"))
    print(f"{name}\t{resolved}")
PYEOF
)
    echo "$vault_list" | awk '{printf "  %-20s %s\n", $1, $2}'
  elif [ -d "$HOME/Obsidian Notebook" ]; then
    vault_list=$(find "$HOME/Obsidian Notebook" -maxdepth 3 -name ".obsidian" -type d | while read -r d; do
      vp=$(dirname "$d"); echo "$(basename "$vp")\t$vp"
    done)
    echo "$vault_list" | awk '{printf "  %-20s %s\n", $1, $2}'
  else
    echo "  (Could not detect vaults — enter details manually)"
  fi

  echo ""
  read -rp "Vault name [exact name from above]: " vault_name
  if [ -z "$vault_name" ]; then
    echo "Skipped: no vault name entered."
    return
  fi

  # Resolve the filesystem path for this vault name
  local vault_path=""
  if [ -n "$vault_list" ]; then
    vault_path=$(echo "$vault_list" | awk -F'\t' -v name="$vault_name" '$1 == name {print $2}')
  fi

  read -rp "Inbox note name [default: Inbox]: " inbox_name
  inbox_name="${inbox_name:-Inbox}"

  # Detect shell profile
  local shell_profile=""
  if [ -f "$HOME/.zshrc" ]; then
    shell_profile="$HOME/.zshrc"
  elif [ -f "$HOME/.bashrc" ]; then
    shell_profile="$HOME/.bashrc"
  elif [ -f "$HOME/.bash_profile" ]; then
    shell_profile="$HOME/.bash_profile"
  fi

  echo ""
  echo "Variables to add to your shell profile:"
  echo "  export OBSIDIAN_VAULT=\"$vault_name\""
  [ -n "$vault_path" ] && echo "  export OBSIDIAN_VAULT_PATH=\"$vault_path\""
  [ "$inbox_name" != "Inbox" ] && echo "  export OBSIDIAN_INBOX=\"$inbox_name\""
  $is_wsl && echo ""
  $is_wsl && echo "  Note: OBSIDIAN_VAULT_PATH is set to the WSL-translated path."
  $is_wsl && echo "  The obsidian CLI may not connect to Obsidian on Windows — direct"
  $is_wsl && echo "  file access via OBSIDIAN_VAULT_PATH will be used as fallback."

  if [ -n "$shell_profile" ]; then
    echo ""
    read -rp "Append to $shell_profile automatically? [y/N]: " do_append
    if [[ "$do_append" =~ ^[Yy]$ ]]; then
      {
        echo ""
        echo "# Obsidian vault (added by better-claude)"
        echo "export OBSIDIAN_VAULT=\"$vault_name\""
        [ -n "$vault_path" ] && echo "export OBSIDIAN_VAULT_PATH=\"$vault_path\""
        [ "$inbox_name" != "Inbox" ] && echo "export OBSIDIAN_INBOX=\"$inbox_name\""
      } >> "$shell_profile"
      echo "[OK] Written to $shell_profile"
      echo "     Run: source $shell_profile"
    fi
  fi

  echo "[OK] Obsidian vault configured: $vault_name"
}

echo "Installing better-claude..."
echo ""

if [ "$MODE" = "--global" ]; then
  install_agents global
  install_skills global
  install_claude_md global
  install_ralph
  setup_obsidian
elif [ "$MODE" = "--project" ]; then
  echo "Target: $PROJECT_DIR"
  echo ""
  install_agents project
  install_skills project
  install_claude_md project
  install_ralph
else
  usage
  exit 1
fi

echo ""
echo "Done! Restart Claude Code to pick up new skills and agents."
