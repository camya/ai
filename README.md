# camya/ai

A universal bridge for AI skills.

Sync and manage portable capabilities across Claude Code, GitHub Copilot, and custom agent environments.

Use the `/sync-skills` wizard to choose which skills to sync and which to skip.

## Why

Different AI providers look for skills in different folders — `.claude/skills`, `.github/skills`, and so on. Maintaining separate copies causes drift. **camya/ai** gives you a single source of truth and a `/sync-skills` command to link it wherever needed.

## Use case - Shared AI skills repository

Ever thought about organizing your shared AI skills in a dedicated repository? Add them to their own repo, run the installer in your project, and sync them with `/sync-skills`.

## Install camya/ai

Run from your project root:

```bash
git clone https://github.com/camya/ai.git .camya-ai

bash .camya-ai/setup/install.sh
```

The script downloads the toolkit into `.camya-ai/`, asks which AI provider to target, and copies the skills into your provider folder.

**Git ignore:** Add `.camya-ai/` to your project's `.gitignore`; this folder is temporary and can be re-downloaded, while the copied skills are what you commit.

**Sync your skills:** Open your AI chat and run `/sync-skills`.

Alternative: If you prefer installing using curl, you can do it like this:

```bash
curl -fsSL https://raw.githubusercontent.com/camya/ai/main/setup/install.sh | bash
```

## Update camya/ai

```bash
bash .camya-ai/setup/update.sh
```

The update script re-downloads the toolkit, checks each `*__camya-ai-skill` copy for differences, and asks before overwriting when changes are found. Commit the changed files afterwards.

## Provided skills

### sync-skills

Syncs AI skills across providers in your project. Creates symlinks or optional copies.

Open your AI chat and run:

`/sync-skills`

Read the [skill documentation](docs/skills/sync-skills/readme.md)

## Changelog

### 2026-05-15

- Initial release
