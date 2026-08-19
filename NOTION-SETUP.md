# Building the Notion side

[DESIGN.md](DESIGN.md) specifies the system. This document is the build procedure: the exact
properties, both copyable formulas, the view filters, and how to collect the identifiers that
`config.local.sh` needs.

Budget 30–60 minutes. You may build the core structure in the Notion UI or ask a Codex session with
the connected Notion plugin to create the pages, databases, formulas, relations, and linked views.
An agent-assisted build must stay inside the new home page until the new AI Agent Guide exists.

The Notion UI is still required to set the one-page relation limit, arrange and nest linked views,
visually verify the homepage, and lock both database structures. Connector-created linked views
append to the end of a page. Creating every heading first and every view afterward produces a
homepage that is technically complete but unusable.

Treat homepage layout as a separate, required setup phase. Do not try to move an existing linked
database by rewriting its `<database>` block through a connector `update_content` call: Notion may
hoist or regroup child blocks instead of preserving the requested position. Place and nest the
views in the Notion UI. If UI control is unavailable, stop after creating the components, report
that layout is incomplete, and give the user the block order in step 5.

For an agent-assisted build, give the agent this document and a unique home-page name. Tell it to
create everything only under that new page, import no Canvas data, stop before destructive cleanup,
and report the created page, database, and data-source identifiers. The agent must fetch the
connected workspace and confirm Notion access before its first mutation.

## 1. Create the home page

Make one page to hold everything. Its name is yours; this document calls it the **home page**. Every
database and child page below lives inside it.

## 2. Create the Stacks database

Add a database named **Stacks** as a child of the home page.

| Property | Type | Configuration |
| --- | --- | --- |
| Name | Title | — |
| Archived | Checkbox | Default unchecked |

The `Tasks` reciprocal relation appears automatically in step 3. Do not create it by hand.

## 3. Create the Tasks database

Add a database named **Tasks** as a child of the home page.

| Property | Type | Configuration |
| --- | --- | --- |
| Name | Title | — |
| Type | Select | Options: `Action`, `Deadline`, `Side Quest` |
| Status | Select | Options: `To do`, `Waiting`, `Doing`, `Done`, `Yeeted` |
| Stack | Relation → Stacks | Enable "Show on Stacks"; limit to one page |
| Due Date | Date | One date or date-time; leave the end date empty |
| Created Time | Created time | — |
| Last Edited Time | Last edited time | — |
| Homepage Section | Formula | See step 4 |
| Show in Completed | Formula | See step 4 |

Three details matter:

- **Status is a Select, not Notion's Status property type.** DESIGN.md treats `Yeeted` as terminal
  alongside `Done`; a Select keeps that explicit and keeps the formula simple.
- **Due Date values must not use an end date.** Notion's Date property always supports ranges at the
  value level; there is no database-wide switch that disables them. Date ranges are outside v1, so
  the AI Agent Guide and automation enforce a single start value.
- Notion does not enforce a Select default through the connector. Agents must set new Tasks to
  `To do`; if you create Tasks manually, set Status explicitly. The v1 formula treats an empty
  Status like unfinished work rather than placing it in Needs Setup, so leaving it blank is a visible
  data-quality gap rather than a supported state.

## 4. Add the formulas

### Homepage Section

Create the `Homepage Section` formula property on Tasks and paste this in.

```
lets(
  taskType, prop("Type"),
  taskStatus, prop("Status"),
  due, dateStart(prop("Due Date")),
  hasDue, not empty(due),
  days, if(
    hasDue,
    dateBetween(
      parseDate(formatDate(due, "YYYY-MM-DD")),
      parseDate(formatDate(now(), "YYYY-MM-DD")),
      "days"
    ),
    0
  ),
  needsSetup, or(
    empty(taskType),
    or(
      and(or(taskType == "Action", taskType == "Deadline"), not hasDue),
      and(taskType == "Side Quest", hasDue)
    )
  ),
  if(or(taskStatus == "Done", taskStatus == "Yeeted"), "",
  if(needsSetup, "Needs Setup",
  if(taskType == "Side Quest", "Side Quest",
  if(days < 0, "Overdue",
  if(days == 0, "Due Today",
  if(and(taskType == "Deadline", and(days >= 1, days <= 7)), "Starting to Matter",
  if(or(
       and(taskType == "Action", and(days >= 1, days <= 14)),
       and(taskType == "Deadline", and(days >= 8, days <= 14))
     ), "Upcoming",
  "")))))))
)
```

### Why it is written this way

The `days` value truncates **both** the Due Date and today to midnight before subtracting, using
`formatDate` then `parseDate`. A plain `dateBetween(due, now(), "days")` counts 24-hour intervals,
so a Task due tomorrow morning would read as 0 days late at night. DESIGN.md requires calendar-date
boundaries that ignore the time of day, and this is what delivers that.

The branch order is the priority order in
[DESIGN.md § Homepage Classification](DESIGN.md#homepage-classification). It matters: terminal
Status wins over everything, `Needs Setup` is checked before any date logic, and the
`Starting to Matter` test runs before `Upcoming` so a Deadline inside seven days lands in the right
one.

### Show in Completed

Create the `Show in Completed` formula property and paste this in.

```
lets(
  taskStatus, prop("Status"),
  due, dateStart(prop("Due Date")),
  edited, prop("Last Edited Time"),
  today, parseDate(formatDate(now(), "YYYY-MM-DD")),
  editedDay, parseDate(formatDate(edited, "YYYY-MM-DD")),
  dueDay, if(empty(due), today, parseDate(formatDate(due, "YYYY-MM-DD"))),
  editedRecently, dateBetween(today, editedDay, "days") <= 7,
  dueTodayOrLater, and(not empty(due), dateBetween(dueDay, today, "days") >= 0),
  if(and(taskStatus == "Done", or(editedRecently, dueTodayOrLater)), "Completed", "")
)
```

This keeps a Done Task visible for seven calendar days after its latest edit. A dated Done Task
stays visible until the later of that window or its Due Date. `Last Edited Time` is deliberately a
low-maintenance proxy: editing a Done Task restarts its seven-day window. Yeeted Tasks return blank.

### Timezone

The formula uses Notion's `now()`, which evaluates in the **viewer's** timezone. Notion formulas
cannot pin an IANA timezone. Set your Notion account timezone to match `AUTOMATION_TIMEZONE` in
`config.local.sh`, or the boundaries will disagree with the changelog dates the automation writes.

### Verify it before trusting it

These formulas were verified in one clean test installation on 2026-08-19. Notion's formula
language can change, so repeat these checks for every new installation rather than assuming
compatibility. Create one throwaway Task per branch and confirm each result:

| Test Task | Expected |
| --- | --- |
| Type empty, with or without a Due Date | `Needs Setup` |
| Action, no Due Date | `Needs Setup` |
| Side Quest with a Due Date | `Needs Setup` |
| Side Quest, no Due Date | `Side Quest` |
| Action due yesterday | `Overdue` |
| Action due today | `Due Today` |
| Timed Action due earlier or later today | `Due Today` |
| Deadline due in 7 days | `Starting to Matter` |
| Deadline due in 8 days | `Upcoming` |
| Action due in 14 days | `Upcoming` |
| Action due in 15 days | blank |
| Waiting or Doing Task | Same date-based section as To do |
| Any Task set to Done or Yeeted | blank Homepage Section |
| Recently edited Done Task | `Completed` in Show in Completed |
| Yeeted Task | blank Show in Completed |

The seven-day expiry cannot be exercised immediately because Last Edited Time is system-managed;
the formula compiling plus the Done and Yeeted cases verifies the branches available during setup.

## 5. Build the homepage

The working views are linked views of the Tasks database on the home page. Their filters use
`Homepage Section = <value>`; the formula has already excluded terminal and malformed Tasks.

| Section | Type | Filter | Sort | Visible properties |
| --- | --- | --- | --- | --- |
| Needs Setup | List | `Needs Setup` | Created Time ascending | Name, Type, Status, Due Date, Stack |
| Today | Gallery | `Overdue` OR `Due Today` OR `Starting to Matter` | Due Date ascending | Name, Stack, Due Date, Status |
| Upcoming | Gallery, grouped by Stack | `Upcoming` | Due Date ascending | Name, Stack, Due Date, Status |
| Overdue (standalone) | Gallery | `Overdue` | Due Date ascending | Name, Stack, Due Date, Status |
| Side Quests | List, grouped by Stack | `Side Quest` | Created Time ascending | Name, Status, Stack, Created Time |
| Completed | Gallery | `Show in Completed = Completed` | Last Edited Time descending | Name, Stack, Due Date, Status |

Today deliberately combines its three formula results into one Gallery. This keeps the decision
surface compact while retaining the urgency order through Due Date sorting. Do not create three
separate Table views: they are much taller and do not match the intended dashboard.

Overdue deliberately appears twice — inside Today as a decision surface, and standalone for focused
cleanup.

Add a Stacks view filtered to `Archived` unchecked, sorted by Name ascending, plus direct links to
the full Tasks and Stacks databases.

### Gallery appearance

The connector can create a Gallery and configure its filter, sort, grouping, and visible
properties. It cannot configure all Gallery presentation controls. Open **Layout** in the Notion UI
for the Today and Upcoming views and set:

| Setting | Value |
| --- | --- |
| Layout | Gallery |
| Show data source title | Off |
| Show page icon | Off |
| Wrap all content | On |
| Open pages in | Center peek |
| Load limit | 25 |
| Card preview | None |
| Card size | Medium |
| Card layout | Compact |

Completed and standalone Overdue are also Galleries, but may use the default card layout. Use the
same visible-property order from the view table above. These are required presentation settings,
not optional polish: Table views and default Gallery cards make the homepage materially taller.

### Required block order

Arrange the homepage in this order. A description belongs directly below its heading, and its
linked view belongs directly below that description. The Stacks and Done linked views are nested
inside their toggles.

1. A callout directing agents to read the live AI Agent Guide before changing the system.
2. A one-line description of the homepage.
3. A callout explaining that the page is a decision surface, not a full task list.
4. **Stacks** toggle: description, then the Active Stacks linked view.
5. **Done** toggle: description, then the Completed linked view.
6. **Today**: description, then the combined Today Gallery.
7. **Upcoming**: description, then its linked view.
8. **Side Quests**: description, then its linked view.
9. Divider.
10. **Needs Setup**: description, then its linked view.
11. **Overdue**: description, then the standalone Overdue linked view.
12. Divider.
13. **Databases** or **Database shortcuts**: direct links to the full Tasks and Stacks databases,
    followed by the AI Agent Guide link.
14. Divider, then the Changelog link.

Create the headings and views in this same sequence when using the connector; each newly created
view appends after the current last block. Use the Notion UI to nest the Stacks and Done views and
to correct any remaining placement. Never remove and reinsert `<database>` or child `<page>` tags
to reorder them: removing a child tag can delete the child, and connector-side reordering is not a
reliable layout operation.

### Homepage completion check

Setup is not complete merely because every view exists. Fetch the home page and inspect it in the
Notion UI. It passes only when all of these statements are true:

- every heading, description, and linked view follows the required order above;
- no headings are detached from their views and no unlabelled views are collected at the bottom;
- the Active Stacks and Completed views are nested inside their toggles;
- each linked view appears exactly once, except that Overdue intentionally has its Today and
  standalone views;
- opening each view shows the intended type, filter, sort, grouping, and property order from the
  table above;
- Today and Upcoming use Medium Compact Gallery cards with no preview, no page icon, no data-source
  title, wrapped content, Center peek, and a load limit of 25; and
- the formula test Tasks appear in the expected views from step 4.

If any check fails, the homepage is still in setup. Correct the layout in the UI and repeat both the
fetch and visual inspection before collecting identifiers or enabling automation.

After every view check passes, delete the throwaway Tasks yourself in the UI. If an agent is doing
the cleanup, explicitly authorise deletion of those exact test Tasks; otherwise set them to Yeeted
and retain them. If a formula branch is wrong, fix it and repeat the checks before continuing.

## 6. Create the AI Agent Guide and Changelog pages

Add two child pages of the home page.

**AI Agent Guide** — the runtime rulebook. Copy
[AI-AGENT-GUIDE-TEMPLATE.md](AI-AGENT-GUIDE-TEMPLATE.md), replace every placeholder with this
installation's URLs, data-source URIs, and timezone, and paste the result into the page. Fetch the
new guide after creating it; from that point onward it is the authority for the installation.

**Changelog** — append-only. Give it a top-level `Pending approval` heading containing an empty
to-do list. The automation appends dated entries beneath `YYYY-MM-DD` headings and files every
deletion it refused to perform under `Pending approval`.

## 7. Collect the identifiers

Fill these into `config.local.sh`.

**Page IDs** (`NOTION_HOME_PAGE_ID`, `NOTION_AGENT_GUIDE_PAGE_ID`, `NOTION_CHANGELOG_PAGE_ID`) are
the 32 hex characters at the end of a Notion URL:

```
https://www.notion.so/Some-Page-Title-0123456789abcdef0123456789abcdef
                                       └────────── this ──────────┘
```

**Database IDs** (`NOTION_TASKS_DATABASE_ID`, `NOTION_STACKS_DATABASE_ID`) come from the database's
own URL the same way. Open it as a full page, not as an inline block.

**Data-source URIs** (`NOTION_TASKS_DATA_SOURCE_URI`, `NOTION_STACKS_DATA_SOURCE_URI`) are not in
any URL. They come from the connector. In an interactive Codex or Claude session with the Notion
tools available, fetch each database and read the `collection://` value from the response:

```
Fetch the Notion database at <url> and report its collection:// data source URI.
```

The value looks like `collection://12345678-90ab-cdef-1234-567890abcdef`. The loader in
`scripts/lib/config.sh` validates the shape, so a malformed paste fails immediately rather than
mid-sync.

## 8. Lock the databases

Once the properties, formula, relation, and views are correct, lock both database structures. Page
and property content stays editable; the schema does not.

Database locking and the one-page relation limit are Notion UI settings the connector cannot reach.
Until you set them by hand, only the AI Agent Guide enforces those rules for agent-driven changes.

## 9. Continue

Return to [README.md](README.md#setup) step 3 and finish configuring the automation.
