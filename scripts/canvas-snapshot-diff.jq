def rows:
  .courses[] as $course
  | ({
      resource: "course",
      key: ("course:" + ($course.id | tostring)),
      course: {id: $course.id, course_code: $course.course_code, name: $course.name},
      id: $course.id,
      value: ($course | del(.assignments, .modules, .pages, .files, .discussions))
    }),
    ($course.assignments[]? | {
      resource: "assignment",
      key: ("course:" + ($course.id | tostring) + ":assignment:" + (.id | tostring)),
      course: {id: $course.id, course_code: $course.course_code, name: $course.name},
      id,
      value: .
    }),
    ($course.modules[]? | {
      resource: "module",
      key: ("course:" + ($course.id | tostring) + ":module:" + (.id | tostring)),
      course: {id: $course.id, course_code: $course.course_code, name: $course.name},
      id,
      value: .
    }),
    ($course.pages[]? | {
      resource: "page",
      key: ("course:" + ($course.id | tostring) + ":page:" + .url),
      course: {id: $course.id, course_code: $course.course_code, name: $course.name},
      id: .page_id,
      value: .
    }),
    ($course.files[]? | {
      resource: "file",
      key: ("course:" + ($course.id | tostring) + ":file:" + (.id | tostring)),
      course: {id: $course.id, course_code: $course.course_code, name: $course.name},
      id,
      value: .
    }),
    ($course.discussions[]? | {
      resource: "discussion",
      key: ("course:" + ($course.id | tostring) + ":discussion:" + (.id | tostring)),
      course: {id: $course.id, course_code: $course.course_code, name: $course.name},
      id,
      value: .
    });

($old[0]) as $old
| ($new[0]) as $new
| ($old | [rows] | INDEX(.key)) as $before
| ($new | [rows] | INDEX(.key)) as $after
| (($before | keys) + ($after | keys) | unique) as $keys
| {
    schema_version: 1,
    generated_at: $new.captured_at,
    previous_captured_at: $old.captured_at,
    current_captured_at: $new.captured_at,
    changes: [
      $keys[] as $key
      | ($before[$key] // null) as $b
      | ($after[$key] // null) as $a
      | select(($b.value // null) != ($a.value // null))
      | {
          change: (if $b == null then "added" elif $a == null then "removed" else "modified" end),
          resource: (($a // $b).resource),
          key: $key,
          course: (($a // $b).course),
          id: (($a // $b).id),
          before: ($b.value // null),
          after: ($a.value // null)
        }
    ]
  }
