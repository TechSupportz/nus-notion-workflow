# Local course notes

Copy to `AGENTS.local.md`, which is gitignored. Agents read it after `AGENTS.md` and `CONTEXT.md`.

Keep Notion and Canvas identifiers in `config.local.sh` instead of here, so there is one source of
truth for them. This file is for prose an agent cannot derive from the API: how a particular course
publishes its deadlines, which documents to trust, and which dates were assumed rather than stated.

## CS101 — Example Module

Canvas course `12345`, section **T02**, **tutorials on Tuesdays**, AY2026/27 Sem 1.

- Stack: https://app.notion.com/p/<notion-page-id>
- `canvas assignments list` returns nothing for this course; the real deadlines are in the syllabus
  `.docx` linked from the weekly schedule page, Canvas file `67890`.
- Assessment weightings: CA1 40%, CA2 20%, final 40%.
- The submission cutoff for CA2 is set by the tutor and is not published anywhere in Canvas. The
  current Task date was assumed from the syllabus phrase "the week following your tutorial" and
  should be corrected once the tutor confirms it.
