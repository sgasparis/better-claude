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

setup_obsidian() {
  echo ""
  echo "--- Obsidian Vault Setup ---"

  # Check for CLI
  if ! command -v obsidian &>/dev/null && [ ! -f ~/.local/bin/obsidian ]; then
    echo "Skipped: obsidian CLI not found. Install it first, then re-run."
    return
  fi

  local obs_cmd
  obs_cmd=$(command -v obsidian 2>/dev/null || echo ~/.local/bin/obsidian)

  # Check if already configured
  if [ -n "$OBSIDIAN_VAULT" ]; then
    echo "OBSIDIAN_VAULT is already set to: $OBSIDIAN_VAULT"
    read -rp "Reconfigure? [y/N]: " reconf
    [[ ! "$reconf" =~ ^[Yy]$ ]] && return
  fi

  # List available vaults
  echo ""
  echo "Available vaults:"
  "$obs_cmd" vaults verbose 2>/dev/null || echo "(Could not list vaults — is Obsidian running?)"
  echo ""
  read -rp "Vault name to use [exact name from above]: " vault_name
  if [ -z "$vault_name" ]; then
    echo "Skipped: no vault name entered."
    return
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
  echo "Add these to your shell profile:"
  echo "  export OBSIDIAN_VAULT=\"$vault_name\""
  if [ "$inbox_name" != "Inbox" ]; then
    echo "  export OBSIDIAN_INBOX=\"$inbox_name\""
  fi

  if [ -n "$shell_profile" ]; then
    echo ""
    read -rp "Append to $shell_profile automatically? [y/N]: " do_append
    if [[ "$do_append" =~ ^[Yy]$ ]]; then
      {
        echo ""
        echo "# Obsidian vault (added by better-claude)"
        echo "export OBSIDIAN_VAULT=\"$vault_name\""
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
