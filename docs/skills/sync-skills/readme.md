# sync-skills

Syncs AI skills across providers in your project. Run it once and skills from any `skills/` folder are linked into your AI's skills directory — no manual copying needed. Works with any AI provider folder: `.claude/skills`, `.github/skills`, or a complete custom location like `company-shared/ai/skills`.

> **Important:** Newly synced skills are available once you start a fresh chat.

## Features

**Symlink mode (default)** - Creates relative symlinks to each skill directory. Changes to the source are reflected immediately, no duplication.

**Copy mode (`--copy`)** - Copies skill directories instead of linking. Fully self-contained; supports drift detection on re-runs so outdated copies are flagged automatically.

## Usage

Open your AI and run:

`/sync-skills`

To copy instead of link:

`/sync-skills --copy`
