# Ringbloom agent guide

This repo (`~/GitHub/ringbloom`) is the canonical source for Ringbloom. As of
`v1.5-b9` (2 Sep 2026 audit) it matches the App Store's live 1.5 build 9 exactly.

`~/GitHub/Gaming Benchmark/GPT5.6 Sol Ultra - Ringbloom/` is a benchmark-run snapshot,
not a source of truth — it is not a git repo. If it ever gets ahead of this repo again
(check `MARKETING_VERSION`/`CURRENT_PROJECT_VERSION` in `project.yml` against `asc
status --app 6789952808`), sync it back in here rather than working from it directly.

## Physical iPhone testing

Use the helper described in the global `~/.claude/CLAUDE.md` ("Physical iPhone
testing"). Don't duplicate its instructions here — that file is the single source for
how the `test-on-iphone.sh` helper works and how to handle a locked `AI-Build`
keychain.
