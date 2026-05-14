#!/bin/bash
set -e

REPO_URL="https://github.com/camya/ai"
ARCHIVE_URL="$REPO_URL/archive/refs/heads/main.tar.gz"
INSTALL_DIR=".camya-ai"

if [ -t 1 ]; then
    GREEN='\033[0;32m'
    BLUE='\033[0;34m'
    YELLOW='\033[1;33m'
    NC='\033[0m'
else
    GREEN='' BLUE='' YELLOW='' NC=''
fi

show_installed_skills() {
    local skills_dir="$1"
    [ -d "$skills_dir" ] || return
    echo -e "\nInstalled skills:"
    echo -e ""
    for skill_dir in "$skills_dir"/*/; do
        [ -d "$skill_dir" ] || continue
        local skill_name version
        skill_name="$(basename "$skill_dir")"
        version=$(grep -m1 'version:' "$skill_dir/SKILL.md" 2>/dev/null | awk '{print $2}')
        if [ -n "$version" ]; then
            echo -e "  /$skill_name: ${GREEN}v${version}${NC}"
        else
            echo -e "  /$skill_name: ${YELLOW}(no version)${NC}"
        fi
    done
}

echo -e ""
echo -e "----------------------------------------------------"
echo -e "${BLUE}camya/ai installer${NC}"
echo -e "----------------------------------------------------"

# 1. Project root safety check
if [ ! -d ".git" ] && [ ! -f "package.json" ] && [ ! -f "pyproject.toml" ]; then
    echo -e "${YELLOW}Warning: No project marker (.git, package.json) found.${NC}"
    read -r -p "Install .camya-ai in $(pwd)? (y/n) " -n 1 < /dev/tty
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then exit 1; fi
fi

# 2. Download toolkit (plain files, no .git)
SCRIPT_REAL="$(realpath "${BASH_SOURCE[0]}")"
INSTALL_DIR_REAL="$(realpath "$INSTALL_DIR" 2>/dev/null || true)"

if [[ -n "$INSTALL_DIR_REAL" && "$SCRIPT_REAL" == "$INSTALL_DIR_REAL"/* ]]; then
    echo -e "Using existing ${BLUE}$INSTALL_DIR${NC} (already cloned)..."
else
    if [ -d "$INSTALL_DIR" ]; then
        echo -e "\n${YELLOW}$INSTALL_DIR already exists. Re-downloading...${NC}"
        rm -rf "$INSTALL_DIR"
    fi
    echo -e "\nDownloading toolkit into ${BLUE}$INSTALL_DIR${NC}..."
    mkdir -p "$INSTALL_DIR"
    curl -fsSL "$ARCHIVE_URL" | tar -xz --strip-components=1 -C "$INSTALL_DIR"
fi
echo -e ""
# 3. Identify AI provider
echo -e "Where should we install the sync skill?\n"
echo "1) Claude (.claude/skills)"
echo "2) GitHub Copilot (.github/skills)"
echo "3) Custom path"
echo -e ""
# read -r -p "Select [1-3]: " choice < /dev/tty
echo -ne "Select [1-3]: " > /dev/tty
read -r choice < /dev/tty

case "$choice" in
    1) DEST=".claude/skills" ;;
    2) DEST=".github/skills" ;;
    3)
        read -r -p "Enter custom path: " DEST < /dev/tty
        DEST="${DEST%/}"
        ;;
    *)
        echo "Invalid choice: '$choice'"
        exit 1
        ;;
esac

# 4. Copy skill to provider folder
mkdir -p "$DEST"
TARGET="$DEST/sync-skills__camya-ai-skill"
SRC="$INSTALL_DIR/skills/sync-skills"

if [ -d "$TARGET" ]; then
    echo -e "\n${YELLOW}Skill already exists at $TARGET${NC}"
    echo -e "\n${BLUE}Checking for differences...${NC}\n"

    if diff -r "$TARGET" "$SRC" --quiet >/dev/null 2>&1; then
        echo -e "${GREEN}No differences found${NC}"
    else
        # Show summary of changed files before asking for overwrite.
        diff -r "$TARGET" "$SRC" --brief || true
        echo -e ""
        read -r -p "Overwrite existing skill? (y/n) " -n 1 < /dev/tty
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}Skipped installation. Existing skill preserved.${NC}"
        else
            echo "Updating skill copy..."
            rm -rf "$TARGET"
            mkdir -p "$TARGET"
            cp -r "$SRC"/* "$TARGET"/
        fi
    fi
else
    mkdir -p "$TARGET"
    cp -r "$SRC"/* "$TARGET"/
fi

# 5. Offer to add .camya-ai/ to .gitignore
GITIGNORE_FILE=".gitignore"
GITIGNORE_ENTRY=".camya-ai/"

if ! grep -qF "$GITIGNORE_ENTRY" "$GITIGNORE_FILE" 2>/dev/null; then
    echo -ne "\nAdd '$GITIGNORE_ENTRY' to .gitignore? (y/n) " > /dev/tty
    read -r -n 1 reply < /dev/tty
    echo
    if [[ $reply =~ ^[Yy]$ ]]; then
        echo "$GITIGNORE_ENTRY" >> "$GITIGNORE_FILE"
        echo -e "\n${GREEN}Added $GITIGNORE_ENTRY to .gitignore${NC}\n"
    else
        echo -e "\n${YELLOW}Skipped. Remember to add $GITIGNORE_ENTRY to .gitignore manually.${NC}\n"
    fi
fi

# 6. Success
echo -e "----------------------------------------------------"
echo -e ""
echo -e "${GREEN}camya/ai installed${NC}"

show_installed_skills "$INSTALL_DIR/skills"

echo -e ""
echo -e "Changelog: ${BLUE}${REPO_URL}${NC}"
echo -e ""
echo -e "Next step: Open your AI-Chat and type:"
echo -e ""
echo -e "/sync-skills"
echo -e ""
echo -e "----------------------------------------------------"
