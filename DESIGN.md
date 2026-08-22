# Notion Task System — v1 Design

**Status:** Implemented and verified in a clean test installation.

`DESIGN.md` and the live AI Agent Guide
are two representations of the same system specification. Every system-design change must update
both in the same operation and record the change in the Changelog. A change is incomplete while
either representation is stale. If a partial failure temporarily creates a disagreement, the live
guide remains the runtime authority until the repository is reconciled.

## Goal

Use Notion as a low-maintenance dashboard for academic and personal work, with an AI agent handling
most creation and editing through the Notion connection.

The homepage exists to help decide what to do. It is not a system-management or strict daily-planning surface.

## Domain Model

Every row in the Tasks database is a **Task**. Its Type is one of:

- **Action** — a discrete activity due on a particular date or at a particular time.
- **Deadline** — a commitment with a fixed cutoff that may require work beforehand.
- **Side Quest** — useful optional work with no fixed cutoff.

`Task` names the general concept and the database. It is not a Type.

Types are stable identities. The system never changes a Task's Type unless the user explicitly names or confirms the new Type.

## Tasks Database

Use one master **Tasks** database.

### User-maintained properties

| Property | Notion type | Rules |
| --- | --- | --- |
| Name | Title | Required |
| Type | Select | `Action`, `Deadline`, or `Side Quest`; required |
| Status | Select | `To do`, `Waiting`, `Doing`, `Done`, or `Yeeted`; agents set new work to `To do` |
| Stack | Relation to Stacks | Optional; limited to one Stack by convention |
| Due Date | Date | One date or date-time; no ranges |

### Automatic and hidden properties

| Property | Notion type | Purpose |
| --- | --- | --- |
| Created Time | Created time | Orders Side Quests and retained Tasks |
| Last Edited Time | Last edited time | Supplies the low-maintenance retention window for recently completed Tasks |
| Homepage Section | Formula | Assigns each unfinished Task to exactly one homepage section from its Type, Status, and Due Date |
| Show in Completed | Formula | Keeps recently edited Done Tasks visible, and keeps dated Done Tasks visible through their Due Date |

No `Effort`, `Priority`, `Reminder`, `Repeat`, `Completed At`, parent Task, or planning properties exist in v1.

Everything else belongs in the Task page body. Page-body checklists are informal notes: unchecked boxes do not prevent a Deadline from becoming Done.

### Status configuration

Status is a plain Select. The following groupings are conceptual only; Notion does not enforce
them:

- **To-do:** `To do`, `Waiting`
- **In progress:** `Doing`
- **Complete:** `Done`, `Yeeted`

An **unfinished** Task has To do, Waiting, or Doing status.

- `Waiting` remains normally visible and does not reduce urgency.
- `Doing` describes activity but does not affect visibility or ranking.
- `Done` records completed work.
- `Yeeted` records intentionally abandoned work.
- Done and Yeeted Tasks remain in the master database but are hidden from normal views.
- Done Tasks appear in Completed for seven calendar days after their latest edit. A dated Done Task
  remains there until the later of that window or the end of its Due Date.
- Editing an already-Done Task restarts its seven-day window because Last Edited Time is the
  low-maintenance completion-time proxy.
- Yeeted Tasks never appear in Completed.
- A terminal Task may be explicitly reopened. Its Type remains unchanged.
- Delete only accidental entries or duplicates, and only after the user explicitly authorises that
  exact deletion; use Yeeted for real work that was abandoned.

### Type invariants

- Action requires a Due Date.
- Deadline requires a Due Date.
- Side Quest must not have a Due Date.
- Missing Stack is valid and means Miscellaneous.

An unfinished Task belongs in Needs Setup when:

- Type is empty;
- an Action or Deadline has no Due Date; or
- a Side Quest has a Due Date.

The system exposes conflicts for correction and never automatically repairs them by changing Type. A malformed Task belongs only in Needs Setup, not in any normal work view.

### Due Date semantics

- Due Date is a single date or date-time. Date ranges are unsupported in v1.
- For an Action, it is when the activity should happen or be finished.
- For a Deadline, it is the cutoff.
- Natural language containing only a date produces a date-only value.
- Natural language containing a time produces a timed value in the configured timezone (`AUTOMATION_TIMEZONE`), unless another timezone is explicit.
- An agent never invents a time.
- Every Task becomes overdue only after its Due Date's calendar day ends in the configured timezone.
- A time communicates when an Action should happen and controls ordering within the day; passing that time does not move the Task out of Due Today.

Notion can attach a native notification to Due Date, but notification configuration is manual. There is no separate Reminder property.

## Stacks Database

A **Stack** is an organisational bucket such as `CS101`, `CS201`, `Unicorn Startup`, or `Homelab`. There is no distinction between academic modules, projects, and personal Stacks.

### Properties

| Property | Notion type | Rules |
| --- | --- | --- |
| Name | Title | Required; unique by convention |
| Archived | Checkbox | Defaults to false |
| Tasks | Reciprocal relation | Created by the Tasks → Stack relation |

When a name must be reused, qualify it naturally, for example `CS101 — AY26/27 S1`.

Stack page bodies hold links, references, module or project information, and notes. Opening a Stack exposes its related unfinished Tasks. There is no explicit History view; completed Tasks remain searchable in the master Tasks database.

Archiving a Stack:

- removes it from normal Stack navigation;
- does not remove it from existing Tasks;
- does not hide its unfinished Tasks from task views; and
- requires confirmation when unfinished Tasks still relate to it.

An agent asks for confirmation before assigning new work to an archived Stack. A direct manual
assignment remains valid and does not place the Task in Needs Setup.

No Stack means **Miscellaneous**: a valid final organisational state, not an inbox awaiting triage.

## Homepage

### Needs Setup

A compact linked view below the primary working sections, filtered to
`Homepage Section = Needs Setup`. It is empty when there are no conflicts.

Notion cannot dynamically remove the surrounding section heading when a linked view becomes empty; “hidden when empty” therefore means the view contains no rows, not that the entire block disappears.

### Today

Today is a suggestion surface containing four formula classifications:

1. **Overdue** — unfinished, correctly configured Actions and Deadlines whose Due Date has passed.
2. **Due Today** — unfinished, correctly configured Actions and Deadlines due today and not yet overdue.
3. **Closing In** — unfinished, correctly configured Actions and Deadlines due tomorrow through three calendar dates from today.
4. **Starting to Matter** — unfinished, correctly configured Deadlines due on days four through seven from today.

Closing In and Starting to Matter are separate because a single seven-day band flattens two
different situations. Work due within three days needs attention now; work due later in the week
only needs to be known about. Closing In covers both Actions and Deadlines, since a near Action is
as pressing as a near Deadline. Starting to Matter stays Deadline-only: it is preparation time, and
an Action four or more days out belongs in Upcoming.

Sort each group by Due Date ascending, including time. There is no numerical priority score.

Present them in one Gallery filtered to all four values, sorted by Due Date ascending. Use Medium
Compact cards with no preview; show Name, Stack, Due Date, and Status. Combining them avoids the
height and repeated headers of four separate Table views while preserving their urgency order.

### Upcoming

Show unfinished, correctly configured work due in the next 14 days that does not already appear in Today:

- Actions due on days 4 through 14; and
- Deadlines due on days 8 through 14.

Sort by Due Date ascending.

Present Upcoming as a Gallery grouped by Stack. Use Medium Compact cards with no preview; show
Name, Stack, Due Date, and Status.

Upcoming is therefore “future dated work not already surfaced,” rather than a literal list of every Task due within 14 days.

Tasks due more than 14 days away are intentionally absent from the homepage until they cross that boundary. This is an accepted trade-off: the homepage optimises present attention rather than acting as a complete semester overview. The full Tasks database remains available for long-range inspection.

### Overdue

A focused linked view of all unfinished, correctly configured Tasks whose Due Date has passed, sorted by Due Date ascending.

An overdue Task deliberately appears both in Today → Overdue and in this standalone view. Today is the decision surface; the standalone view is for focused cleanup.

### Side Quests

Show correctly configured unfinished Side Quests in a List grouped by Stack, filtering to
`Homepage Section = Side Quest` and sorting by Created Time ascending so the oldest generally rises
first.

Waiting and Doing Side Quests remain in the list. Side Quests never enter Today automatically.

If an old Side Quest is reopened, it retains its original Created Time and therefore returns according to its original age.

### Completed

Show Tasks in a Gallery filtered to `Show in Completed = Completed`, sorted by Last Edited Time descending. The
formula returns `Completed` only for Done Tasks when either:

- Last Edited Time is within the last seven calendar days; or
- Due Date is today or later in the configured timezone.

This is a short retention surface, not a permanent history view. The full Tasks database remains the
source for older Done Tasks. Yeeted Tasks remain hidden.

### Stacks and navigation

Show a compact alphabetical view of non-archived Stacks, plus direct links to the full Tasks and Stacks databases.

Archived Stacks remain accessible through the full Stacks database.

## Changelog

The Changelog is an append-only child page of the workspace home page. It records concrete changes
to the Notion system and the Canvas → Notion automation. Each configured-timezone calendar date is
a `YYYY-MM-DD` toggle heading whose children contain that day's entries. Date toggles are ordered
from most recent to least recent; new dates are inserted directly below **Daily changelog**, while
later runs on an existing date are added inside that date's toggle.

Each automation run triggered by a Canvas diff records:

- the Canvas facts observed;
- safe Notion changes applied;
- useful no-op decisions; and
- deletion-dependent changes that were deferred.

The Canvas snapshot covers assignments, quizzes, announcements, modules, pages, files, and
discussions for every current subject. Announcements are treated as a first-class source: inspect
their content for actionable work, deadline changes, preparation instructions, and durable course
reference information rather than recording only their titles.

The top-level **Pending approval** section is the actionable queue for destructive work. Each
unchecked item identifies the exact target, proposed deletion, reason, and consequence. Equivalent
items are not duplicated. The automation never performs these changes because an unattended run
cannot obtain explicit permission. After the user explicitly authorises an exact item and an agent
completes it, the item is checked off and retained as history rather than erased.

Every diff-triggered run must fetch and verify its Changelog entry. The Canvas baseline advances
only after all safe changes and the Changelog write succeed; otherwise the old baseline is retained
for an idempotent retry.

The user has explicitly authorised automatic approval review for the headless Codex process. It
remains inside the `workspace-write` sandbox, and the Notion app has an `Allow all actions`
override so safe synchronization writes can complete without an interactive prompt. This does not
authorise deletion: every destructive Notion change is still deferred to **Pending approval**.
Locked or otherwise unavailable Canvas files remain in the change bundle with metadata and an
explanatory artifact note instead of failing the run.

## Agent Behaviour

### Creation

An agent may infer Type and Stack when the user's meaning is clear and defaults Status to `To do`.

It must:

- ask when Type is ambiguous;
- never invent a Due Date;
- ask for a Due Date before creating an Action or Deadline when none was supplied; and
- leave Stack empty when no Stack is clear.

Examples:

- “Assignment 2 is due Friday” → infer Deadline; ask only if Friday is ambiguous.
- “Buy batteries tomorrow” → infer Action due tomorrow.
- “Refactor the Unicorn Startup landing page someday” → infer Side Quest in the Unicorn Startup Stack.
- “Buy batteries” → ask for a Due Date rather than silently making it a Side Quest.
- “Remind me tomorrow to buy batteries” → create an Action due tomorrow and report: `Added “Buy batteries” as an Action due tomorrow.` Do not claim that a notification was scheduled.

### Editing

- Never change Type automatically.
- “Make this Side Quest due Friday” requires asking whether it should become an Action or Deadline; make neither edit until confirmed.
- Adding or removing Due Date directly may move a Task into Needs Setup but never triggers automatic reclassification.
- Preserve unrelated manual page content. Append material or edit only the specific content requested.
- Renaming a Stack is safe because relations follow the page rather than its title.

### Deletion protection

- Never delete or archive a Notion page, database, Task, Stack, block, relation, property value, or
  hand-written content without the user's explicit permission for that exact destructive change.
- Removal, unpublishing, renaming, or contradiction in an upstream source is not deletion
  permission.
- Never remove a child `<page>` tag, use `replace_content`, or enable content deletion as part of
  an unattended operation.
- When unattended automation encounters a deletion-dependent change, it skips the change and adds
  it to the Changelog's **Pending approval** queue.

## Database Protection

Lock the Tasks and Stacks database structures after properties, views, formulas, relations, and automations are configured. Normal page and property content remains editable. Unlock only for intentional system maintenance.

Database locking and the one-page relation limit are Notion UI settings unavailable through the connector. Until configured manually, the AI Agent Guide enforces these rules for agent-driven changes.

## Homepage Classification

`Homepage Section` is hidden plumbing, not user-entered metadata. It evaluates in this order so every Task has at most one result:

1. Done or Yeeted → blank
2. Invalid Type/Due Date combination → `Needs Setup`
3. Valid Side Quest → `Side Quest`
4. Due Date before today → `Overdue`
5. Due Date is today → `Due Today`
6. Action or Deadline due tomorrow through day 3 → `Closing In`
7. Deadline due on days 4–7 → `Starting to Matter`
8. Action due on days 4–14, or Deadline due on days 8–14 → `Upcoming`
9. Anything else → blank

All date boundaries use calendar dates in the configured timezone. The formula does not use the current time of day.

The implemented formula, and the reason it truncates both dates to midnight before subtracting, is
in [NOTION-SETUP.md](NOTION-SETUP.md#homepage-section).

## Deliberately Excluded from v1

- Manual priority
- Effort estimates
- Scheduling or daily planning
- Start-by dates
- Subtasks and dependencies
- Separate task databases per Stack
- Waiting-on and follow-up metadata
- Completion analytics or explicit History views
- Reminder properties or MCP-managed Notion notifications
- Date ranges
- Task page templates
- Recurrence

## Deferred: Routines and Recurrence

Routines are outside v1. A future version may introduce a separate daily, weekly, or monthly suggestion surface rather than treating routines as ordinary Tasks.

No decision has been made about whether a Routine is a reusable item, generates Actions, tracks completion, or preserves occurrence history. V1 therefore contains no `Repeat` property, routine view, occurrence model, recurring template, or placeholder automation.

## Implementation Notes Requiring Visual Verification

- Verify that the combined Today Gallery remains compact and useful on the intended iPad layout,
  including Medium Compact cards and the intended visible-property order.
- Verify the cleanest Stack-page presentation for unfinished reciprocal Tasks without introducing Task templates.
