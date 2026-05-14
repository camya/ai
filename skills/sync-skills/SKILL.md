---
name: sync-skills
description: Syncs AI skills across providers. Enables a shared skill library across projects. Creates symlinks or copies. Detects broken and outdated entries on re-run.
metadata:
  version: 1.0.4
  source: https://github.com/camya/ai
---

## What counts as a skill

A skill is a directory that is a **direct child** of a folder named `skills/` and contains a `SKILL.md` file. The path must match exactly `<any-path>/skills/<skill-name>/SKILL.md` — deeper nesting (e.g. `skills/foo/bar/SKILL.md`) is not valid.

## Mode

- **Default (symlink mode):** Creates a relative symbolic link to the source skill directory. No file duplication — changes in the source are reflected immediately. Relative paths stay portable after clone or move as long as the repo structure is preserved.
- **`--copy` mode:** Copies the source skill directory into the destination. Fully self-contained — works even if the source is later deleted. Supports drift detection on re-runs via a `.sync-skills` metadata file written inside each copied directory.

## Destination folder (self-detecting)

Determine the destination by resolving the path of this `SKILL.md` file at runtime:

```
destination = parent(parent(this SKILL.md))
```

Examples of the general rule:
- `<any-folder>/skills/sync-skills/SKILL.md` → destination is `<any-folder>/skills/`

This works with any folder name — standard ones like `.claude/`, `.ai/`, `.agents/`, or completely custom ones like `.ai-shared-company-custom-folder/`. No hardcoded paths.

## Search locations

Find all `SKILL.md` files under paths matching `*/skills/*/SKILL.md`. All path comparisons MUST use canonical (resolved) absolute paths to prevent symlink escapes, duplicate traversal, and false positives in nested mounts. Exclude:
- the destination directory and all of its descendants (compare canonical paths)
- node_modules
- .git
- vendor
- dist
- build
- out
- venv
- .venv
- target
- .cache

## Postfix convention

The target name is the skill directory name, a double-underscore separator, and a source suffix derived from the path from the project root to the folder that directly contains `skills/`, with path separators replaced by `-`, lowercased:

```
<skill-name>__<path-to-skills-parent>-skill
```

The double underscore is an unambiguous delimiter — skill names that themselves contain underscores remain parseable (e.g. `my_tool__agents-skill`).

Examples:
| Source path | Target name |
|---|---|
| `.camya-ai/skills/foo` | `foo__camya-ai-skill` |
| `.ai/skills/foo` | `foo__ai-skill` |
| `.agents/skills/foo` | `foo__agents-skill` |
| `.github/skills/foo` | `foo__github-skill` |
| `.claude/skills/foo` | `foo__claude-skill` |
| `.ai-shared-company-custom-folder/skills/foo` | `foo__ai-shared-company-custom-folder-skill` |
| `src/shared/ai/skills/foo` | `foo__src-shared-ai-skill` |
| `packages/backend/skills/foo` | `foo__packages-backend-skill` |

## Steps

0. Read this `SKILL.md` file's own frontmatter and introduce the skill to the user using the format below. All values must come from the frontmatter - do not hardcode them.

   If `.camya-ai/` does not exist in the project root, print an info notice after the introduction:

   > Info: `.camya-ai/` not found. Run the installer to get future updates: `curl -fsSL https://raw.githubusercontent.com/camya/ai/main/setup/install.sh | bash`

   This is informational only — continue scanning normally.

   ```
   # Skill: **<name>** v<metadata.version>

   <description>

   ---

   **Destination folder:** `<current-skills-folder>`
   **Mode:** symlink|copy

   Now scanning for skills...
   ```

   Also state the active mode: **symlink mode** (default) or **copy mode** (`--copy` was passed).

1. Detect the destination folder by resolving the location of this `SKILL.md` file (parent → parent).
2. Detect the **project root** starting from the directory containing this `SKILL.md`:
   1. Run: `git -C <skill-dir> rev-parse --show-toplevel`
   2. If successful, that path is the **project root**.
   3. Otherwise, walk upward from `<skill-dir>` checking each ancestor for markers in this precedence order: `.git` > `.idea/` > `.vscode/` > `package.json` > `pyproject.toml` > `Cargo.toml` > `go.mod`. Stop at the filesystem root or `~`. If multiple markers exist in the same directory, the highest-precedence one wins.
   4. If a marker is found, its containing directory is the **project root**.
   5. If nothing is found, print `Error: could not detect project root. No .git or recognized project marker found above <skill-dir>.` and stop. Do not run steps 10-12.
3. Find all `SKILL.md` files under the search locations above (excluding the destination folder). If none are found, tell the user and stop.
4. Read the `name` field from each found skill's frontmatter. If two or more skills share the same `name` value, flag them as a **name collision** — list the conflicting paths and warn the user (the skill dispatcher resolves by `name` and will only see one). Collisions do not block syncing.
5. For each found skill, compute its target name (postfix convention) and check the destination folder for its current status:

   **Symlink mode (default):**
   - Target does not exist → *(no marker, ready to link)*
   - Target is a symlink and its resolved path matches the source → `[already linked]`
   - Target is a symlink but its target no longer exists → `[broken — will re-link]`
   - Target is a symlink pointing to a different source → will resolve with `_2`/`_3` suffix
   - A regular directory with the target name exists → `[mode mismatch — copy exists, skipping]`

   **Copy mode (`--copy`):**
   - Target directory does not exist → *(no marker, ready to copy)*
   - Target exists and `SKILL.md` content matches source → `[up to date]`
   - Target exists but `SKILL.md` content differs from source → `[outdated]`
   - A symlink with the target name exists → `[mode mismatch — symlink exists, skipping]`

   Also apply `[name collision]` where applicable (does not block syncing).

   Present the results as a table with columns `#`, `Name`, and `Source — Description`. Example:

   | # | Name | Source — Description |
   |---|------|----------------------|
   | 1 | demo-for-agents | `.agents/skills/demo-for-agents` — **Just a demo agent** `[already linked]` |
   | 2 | demo-for-ai | `.ai/skills/demo-for-ai` — **Describe what this skill does...** `[broken — will re-link]` |
   | 3 | hello-world | `.github/skills/hello-world` — **Say hello to the user** |

   Skills marked `[already linked]` or `[up to date]` are skipped automatically and are not selectable. If no eligible skills remain after filtering, report immediately and stop.

   Ask the user which of the remaining (eligible) skills to sync:

   > Which skills to sync? (`all` / `1,2,5` / `.folder-name`)

   Accepted input:
   - `all` — sync all eligible skills
   - `1,2,5` — sync only the skills at those row numbers (rows marked `[already linked]` or `[up to date]` are ignored even if selected)
   - `.folder-name` — sync all eligible skills whose source path starts with that top-level folder (e.g. `.ai`, `.claude`, `.company-skills`)

6. For each confirmed skill, compute its target name using the postfix convention.
7. If the target already exists and is not the same source: append `_2`, `_3`, etc. until the name is free. Skip mode-mismatch items without renaming.
8. Perform the sync. Each skill is processed independently — a failure on one does not roll back previously synced skills. Report any per-skill failures inline and continue.

   **Symlink mode (default):**
   - If `[broken — will re-link]`: remove the broken symlink first.
   - Compute the relative path from the destination directory to the source directory (e.g. `../../.agents/skills/demo-for-agents`).
   - `ln -s <relative-path-to-source> <destination>/<target-name>`

   **Copy mode (`--copy`):**
   - If `[outdated]`: remove the existing target directory first, then copy fresh.
   - `cp -r <absolute-source-path> <destination>/<target-name>`
   - Write a `.sync-skills` file inside `<destination>/<target-name>/` containing the source path relative to the project root on a single line (e.g. `.agents/skills/demo-for-agents`). This enables drift detection on re-runs and keeps the file portable after clones or moves.

9. Scan the destination folder for stale entries. Only entries created by this tool are eligible — symlinks in symlink mode, and directories containing a `.sync-skills` file in copy mode. Unrelated symlinks or directories are never touched.

   **Symlink mode:** Check each symlink in the destination folder — if `test -e <symlink>` fails (broken symlink), mark it as stale.

   **Copy mode:** For each skill directory containing a `.sync-skills` file, read the recorded relative source path, resolve it against the project root, and check whether it still exists. If it does not, mark it as stale.

   If any stale entries are found, list them and ask the user for confirmation before removing. If none are found, skip this step.

10. Report as a single line. Example: `2 linked, 1 re-linked, 1 skipped (already linked). No stale entries found.`

11. Output a list of all active synced skills. Lead with the session notice, then a header, then one list entry per skill using the skill `name` from frontmatter and its `description`. Example:

    > **Important:** A new chat session is required. Newly synced skills are not available until you start a fresh chat.

    **Available Skills**

    Invoke the listed skills with slash, e.g. `/your-skill-name`

    - `/demo-for-agents`

      Just a demo agent

    - `/demo-for-ai`

      Describe what this skill does and when to use it...

    **Done.**
