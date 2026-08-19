# Personal Work Management

Language for a low-maintenance system that helps its owner choose and track academic and personal work.

## Language

**Task**:
Any item tracked by the system, classified as an Action, Deadline, or Side Quest.
_Avoid_: Work item, entry

**Action**:
A discrete activity due on a particular date or at a particular time.
_Avoid_: Task, event

**Deadline**:
A commitment with a fixed cutoff that may require meaningful work before it is due.
_Avoid_: Project, assignment, deliverable

**Side Quest**:
Useful optional work with no fixed cutoff.
_Avoid_: Backlog item, someday task

**Miscellaneous**:
The valid organisational pile for Tasks that do not belong to a Stack; it does not imply that the Tasks await triage.
_Avoid_: Inbox, Unstacked

**Stack**:
An optional organisational bucket that groups related work under a shared subject or endeavour.
_Avoid_: Module, project, category, area

**Due Date**:
The single date or time by which an Action should be done or a Deadline reached. It is required for Actions and Deadlines and absent from Side Quests; date ranges are outside the model.
_Avoid_: Date, schedule

**Needs Setup**:
A Task whose properties conflict with the rules of its Type and therefore requires an explicit human decision. It is exposed for correction rather than automatically reclassified.
_Avoid_: Invalid, broken

**Yeeted**:
A terminal status for intentionally abandoned Tasks. Yeeted Tasks remain in history but are hidden from normal working views.
_Avoid_: Dropped, cancelled, deleted

**Starting to Matter**:
An unfinished Deadline whose Due Date is within the next seven days, shown early enough to invite preparation.
_Avoid_: Urgent, priority

**Waiting**:
An unfinished status indicating that progress currently depends on something else. It does not reduce a Task's date-based visibility.
_Avoid_: Blocked

**Doing**:
An unfinished status indicating current activity. It does not increase a Task's date-based visibility.
_Avoid_: In progress

**Unfinished**:
Any Task whose Status is To do, Waiting, or Doing.
_Avoid_: Active, open

**Archived Stack**:
A Stack retired from normal navigation while retaining its relationship to historical and unfinished Tasks.
_Avoid_: Deleted Stack, completed Stack
