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
    echo -e ""
    echo -e "Updated skills:"
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
echo -e "${BLUE}Updating camya/ai...${NC}"
echo -e "----------------------------------------------------"
echo -e ""

# 1. Download fresh toolkit to temp dir
TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT

echo -e "Downloading latest toolkit..."
curl -fsSL "$ARCHIVE_URL" | tar -xz --strip-components=1 -C "$TEMP_DIR"

# 2. Replace .camya-ai/
echo -e "Replacing ${BLUE}$INSTALL_DIR${NC}..."
rm -rf "$INSTALL_DIR"
cp -r "$TEMP_DIR" "$INSTALL_DIR"

# 3. Find and update all *__camya-ai-skill copies in the project
UPDATED=0
SKIPPED=0

while IFS= read -r -d '' target; do
    skill_name=$(basename "$target" | sed 's/__camya-ai-skill//')
    src="$INSTALL_DIR/skills/$skill_name"
    if [ -d "$src" ]; then
        echo -e ""
        echo -e "Checking ${BLUE}$target${NC}..."
        
        # Check if there are differences
        if diff -r "$target" "$src" --quiet >/dev/null 2>&1; then
            echo -e "${GREEN}No differences found${NC}"
            continue
        fi
        
        echo -e "${YELLOW}Differences found${NC}\n"
        diff -r "$target" "$src" --brief || true
        
        echo -e ""
        read -r -p "Update this skill? (y/n) " -n 1 < /dev/tty
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}Skipped${NC}"
            SKIPPED=$((SKIPPED + 1))
        else
            rm -rf "$target"
            mkdir -p "$target"
            cp -r "$src"/* "$target"/
            UPDATED=$((UPDATED + 1))
        fi
    else
        echo -e "${YELLOW}Warning: source skill '$skill_name' not found in new download, skipping $target${NC}"
    fi
done < <(find . -name '*__camya-ai-skill' -type d \
    -not -path './.git/*' \
    -not -path "./$INSTALL_DIR/*" \
    -print0)

# 4. Success
echo -e "----------------------------------------------------"
echo -e ""
echo -e "${GREEN}camya/ai updated${NC}"

show_installed_skills "$INSTALL_DIR/skills"

echo -e ""
echo -e "$UPDATED skill(s) updated in provider folders."
if [ $SKIPPED -gt 0 ]; then
    echo -e "$SKIPPED skill(s) skipped (no changes or user declined)."
fi
echo -e ""
echo -e "Changelog: ${BLUE}${REPO_URL}${NC}"
echo -e ""
echo -e "Open your AI and run ${BLUE}/sync-skills${NC} to re-sync if needed."
echo -e ""
echo -e "----------------------------------------------------"
