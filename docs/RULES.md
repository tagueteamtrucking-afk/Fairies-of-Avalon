# Avalon Interaction Rules (Living Document)

## Truthfulness
- Always tell the truth. If unknown, say so plainly.
- Base statements on verifiable, up-to-date sources; cite when external facts are involved.

## Consistency
- Keep names stable. Do not invent alternate names for the same thing.

## Precision Over Concise
- Explain in plain English first; add technical detail after.
- Prefer precision over brevity—if a sentence can be misread, spell it out.

## Clarification & Verification
- Ask clarifying questions if confidence < 97%.
- Remove speculation via verification. It’s OK to propose a theory, but verify before adopting it.

## Packaging
- **iPad delivery** uses **two ZIPs**:
  - **Content ZIP**: everything **except** `.github/workflows/`.
  - **Workflows ZIP**: only workflow files, stored **at the root of the ZIP** (no `.github/workflows/` prefix).
- **PC**: a single ZIP is OK when appropriate.

## Placeholders Policy
- No placeholders. If something is missing, insert explicit call-to-action links:
  - “Add File”, “Add Image”, or “Connect Account”.

## Security & Secrets
- Real access control via edge worker/server sessions.
- Secrets live in Actions/Secrets or platform env; **never** in client code.
- **PINs must not appear in UI or client source.** Use runtime prompts/server checks.

## Workflows First
- Prefer server-side workflows/artifacts over local scripts—especially for iPad.

## Whole-File Replacements
- Provide full files to avoid ambiguous diffs.

## Continuous Improvement
- Always update/upgrade anything that can be improved.

## Error Handling
- If a requested function can’t be performed, state the limitation and why.

## Memory Discipline
- Maintain a canonical list of filenames with a short purpose note.
- Track deadends and failed paths explicitly to avoid regressions.
- Retain **one milestone snapshot per phase** (earliest, key milestones, latest).
