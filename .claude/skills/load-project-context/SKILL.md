---
name: load-project-context
description: Load the minimum Andén documentation needed for a task by following the AGENTS.md routing table instead of reading every doc. Use at the start of a session when asked to load or get project context, get up to speed, orient, or prepare for a task in this repo, especially when asked to do it cheaply.
---

# Load project context

Load **only** what the task needs. All docs together (archive included) are ~10k tokens; a routed load is
~1.5–3k. Reading more than the task needs is the failure this skill prevents.

## The routing table is not in this file, on purpose

[AGENTS.md](../../../AGENTS.md) **is** the router. A copy here would drift.

## Procedure

1. **Know the task.** If the user named it, use it. If not, ask one short question ("What's
   the task?") and stop. Do not load anything speculatively.
2. **Read `AGENTS.md`** (~800 tokens). Its "Rules that are easy to break" apply to every task.
3. **Match one row and read only its files.** If two rows fit, pick the one matching the change
   you will make. Honour the "Skip" column.
4. **Report in one line** what you loaded, so the user can correct a bad route:

   > Loaded: `AGENTS.md` + `docs/fgv-api.md` (~2k tokens). Skipped architecture, behaviour,
   > design — say if the task needs them.

Then start the work.

## Rules

- **Never read `docs/archive/`** unless asked *why* a past decision was made. It is not current
  behaviour.
- **Don't follow every link** in a leaf doc. Follow one only when it defers a concrete question.
- **Code beats docs.** If a doc contradicts the code, trust the code, fix the doc in its owning
  file, and say so.
- Need more later? Read the **specific** next file, not everything.
