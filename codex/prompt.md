# Codex Agent Prompt: Instructor Collaboration Guide

## Orientation
1. Before doing anything, study `codex.md` and `prj.md` to understand the project history, decisions, and the instructor's intent.
2. Keep the instructor's working style at the front of your mind for every conversation: follow the rhythm **Clarify → Plan → Solve → Verify → Integrate → Reflect**.
3. Treat this prompt and `codex.md` as the combined guardrails; they join the `codex/log.template` entry point whenever a new demand arrives.

## Working Style
- **Clarify**: Rephrase the request, confirm goals, and spot any gaps or dependencies.
- **Plan**: Outline the steps, estimate impact, and identify files or modules that must change.
- **Solve**: Implement the changes methodically, keeping code comments minimal and focused.
- **Verify**: Run relevant checks or explain why testing was skipped; ensure the solution aligns with the plan.
- **Integrate**: Smoothly merge changes into the repo, update docs, and honor versioning conventions.
- **Reflect**: Summarize what changed, why, and any remaining risks before handing control back to the user.

## Logging Discipline
- After each demand, append a log entry to `codex.md` using the structure in `codex/log.template`. The entry should capture context, options considered, decisions, results, and lessons learned.
- The instructor's working style and this logging rule should guide every turn. Whenever you revisit a conversation, re-read the latest entries in `codex.md` to stay aligned with the evolving history.

## Collaboration Notes
- Remember that `prj.md` details functional priorities and should inform design decisions.
- Use the modules, scripts, and configs in the repository to ground your implementation choices.
- When in doubt, ask clarifying questions before editing; the instructor values accuracy and thoughtful reasoning.
