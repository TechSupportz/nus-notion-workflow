# AI Agent Guide template

Copy the content below into the installation's **AI Agent Guide** page. Replace every
`<placeholder>` with a value from that installation before the guide becomes authoritative. Keep
this template, [DESIGN.md](DESIGN.md), and established live guides aligned when the system design
changes.

---

Use this guide whenever an AI agent creates, edits, completes, reorganises, or queries work in this
Notion system. Preserve the existing schema and views unless the user explicitly requests system
maintenance.

This live guide and the repository's `DESIGN.md` represent the same system specification. A
system-design change is complete only when both are updated and a dated Changelog entry records the
change. If they temporarily disagree, this live guide is the runtime authority.

## Locate the system

- **Tasks:** [open database](<tasks-database-url>) — `<tasks-data-source-uri>`
- **Stacks:** [open database](<stacks-database-url>) — `<stacks-data-source-uri>`
- **Changelog:** [open page](<changelog-page-url>)
- **Timezone:** `<automation-timezone>`

Fetch the relevant data source before every mutation. Use its current schema and exact property
names rather than this cached reference.

## Vocabulary

- **Task** — any tracked item and the name of the database. It is not a Type.
- **Action**, **Deadline**, **Side Quest** — the three Types.
- **Stack** — the optional bucket grouping related work.
- **Miscellaneous** — a Task with no Stack; this is a valid final state.
- **Needs Setup** — a Task whose Type and Due Date conflict, waiting on a human decision.
- **Yeeted** — intentionally abandoned work retained in history.
- **Starting to Matter** — an unfinished Deadline due within seven days.
- **Waiting** — progress depends on something else.
- **Doing** — current activity.
- **Unfinished** — Status `To do`, `Waiting`, or `Doing`.

Use these terms in names, page bodies, and reports.

## Operating workflow

1. Resolve the target Task or Stack. Ask when multiple records could match.
2. Classify the requested change against the invariants below.
3. Ask only for information required to produce a valid record. Infer Type or Stack only when the
   wording is clear.
4. Apply the smallest property or page-body edit that completes the request.
5. Fetch the changed record. For Tasks, verify its user-editable properties, `Homepage Section`,
   and `Show in Completed`.
6. Report the concrete operation and any unresolved Needs Setup state.

Completion means the intended record exists with valid properties, unrelated content is preserved,
and the fetched result matches the requested change.

## Tasks

User-editable properties are:

- **Name**
- **Type:** `Action`, `Deadline`, or `Side Quest`
- **Status:** `To do`, `Waiting`, `Doing`, `Done`, or `Yeeted`
- **Stack:** zero or one related Stack
- **Due Date:** one date or date-time; no ranges

`Created Time`, `Last Edited Time`, `Homepage Section`, and `Show in Completed` are system-managed.
Read them; do not write them.

### Type and date invariants

- An Action is discrete work and requires a Due Date.
- A Deadline is a fixed cutoff and requires a Due Date.
- A Side Quest is optional work and must not have a Due Date.
- Type is stable. Change it only when the user explicitly names or confirms the new Type.
- No Stack means Miscellaneous and requires no triage.
- Set a new Task's Status to `To do`.
- Missing Type, a missing required Due Date, or a dated Side Quest belongs in Needs Setup. Surface
  the conflict instead of silently changing Type.
- Preserve date-only wording as a date-only value. Store a time only when the user supplies one.
- Use the configured timezone unless another timezone is explicit.
- Never invent a Due Date or time, and never create a date range.
- A timed Task remains Due Today for its entire calendar date and becomes Overdue the next day.
- When a date is derived from a syllabus rather than officially published, quote the source wording
  in the Task body.

### Status and retention

- Waiting and Doing do not alter date ranking.
- Done and Yeeted are terminal and disappear from working views.
- Done Tasks appear in Completed for seven calendar days after their latest edit. A dated Done Task
  remains until the later of that window or the end of its Due Date.
- Editing an already-Done Task restarts the seven-day window.
- Yeeted Tasks remain hidden from Completed.
- Retain Done and Yeeted Tasks. Delete only accidental entries or duplicates after the user
  explicitly authorises that exact deletion.
- Reopening a Task is an explicit Status change and preserves its Type.

## Stacks

- Properties are **Name**, **Archived**, and the reciprocal **Tasks** relation.
- Names are unique by convention. Search before creating one.
- Confirm before assigning new work to an archived Stack.
- Archiving preserves relations and does not hide unfinished Tasks.
- Store links, references, and notes in the Stack page body.

## Editing guardrails

- Preserve unrelated page-body content. Use `insert_content` or an `update_content` scoped to the
  smallest exact region.
- Removing a child `<page>` tag deletes that child page. Preserve child tags while reorganising.
- Do not use connector Markdown rewrites to move existing linked `<database>` blocks. They may be
  hoisted or regrouped unexpectedly. Use the Notion UI for dashboard layout changes, then fetch and
  visually verify the result.
- Preserve database names, schema, formulas, relations, views, and dashboard layout during ordinary
  Task work.
- Treat schema and view changes as explicit system maintenance.
- Assign at most one Stack.
- Before archiving a Stack with unfinished Tasks, warn the user and obtain confirmation.
- Delete or archive Notion content only after the user explicitly authorises that exact destructive
  change. Unattended automation records the proposal under Changelog → Pending approval instead.

## Changelog

Keep the Changelog append-only and organise entries by calendar date in the configured timezone.
The top-level **Pending approval** section is the queue for destructive work. Each unchecked item
identifies the exact target, proposed deletion, reason, and consequence. After an explicitly
authorised item is completed, check it off and retain it as history.

## Homepage classification

`Homepage Section` is mutually exclusive:

1. Done or Yeeted → blank
2. Invalid Type/Due Date combination → `Needs Setup`
3. Valid Side Quest → `Side Quest`
4. Due before today → `Overdue`
5. Due today → `Due Today`
6. Deadline due tomorrow through day 7 → `Starting to Matter`
7. Action due tomorrow through day 14, or Deadline due on days 8–14 → `Upcoming`
8. Anything else → blank

Completed is separate. It shows only Done Tasks where `Show in Completed` returns `Completed`.

## Homepage presentation

- Today is one Gallery covering Overdue, Due Today, and Starting to Matter, sorted by Due Date.
- Upcoming is a Gallery grouped by Stack and sorted by Due Date.
- Today and Upcoming use Medium Compact cards with no preview. Show Name, Stack, Due Date, and
  Status; hide the data-source title and page icon, wrap content, open in Center peek, and load 25.
- Completed is a Gallery sorted by Last Edited Time descending.
- Side Quests and Needs Setup are Lists; Side Quests is grouped by Stack.
- Treat a fallback Table or a default-card Today/Upcoming Gallery as incomplete setup. These
  presentation controls require visual verification in the Notion UI.

## Outside v1

Recurrence, routines, effort, manual priority, reminder properties, date ranges, subtasks,
completion analytics, automatic Type conversion, and occurrence history are system-design changes,
not ordinary Task edits.
