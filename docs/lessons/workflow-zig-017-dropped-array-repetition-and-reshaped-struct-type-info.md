# Workflow: Zig 0.17 dropped array repetition and reshaped a struct's type info

**Date**: 2026-11-05
**Lesson**: Zig 0.17 has no `**` operator (`"ab" ** 32` is a parse error), and `@typeInfo(T).@"struct"` has `field_names` and `field_types` instead of a `fields` list of structs.

**Why**: Both were common Zig idioms before 0.17 - string repetition for test fixtures (a 64-character hash, a long payload) and `inline for (@typeInfo(T).@"struct".fields) |f|` with `f.name` for generic key=value readers - and both appear in older code and examples, so they are written by habit.

**What Happened**: Lane perf0 wrote tools/perf_bench with `"ab" ** 32` fixtures in five files and a pin-file reader iterating `.fields`. `zig ast-check` on the Mac caught the first in seconds ("binary operator '*' has whitespace on one side, but not the other": the parser reads `**` as two `*`); the second only failed in the pool compile ("no field named 'fields' in struct 'lang.Type.Struct'").

**Fix**:
1. Write the repeated literal out (a 64-hex-digit hash spelled in full), or build it with a comptime loop.
2. Iterate `@typeInfo(T).@"struct".field_names` (and `field_types` beside it): `inline for (@typeInfo(@TypeOf(s)).@"struct".field_names) |name| @field(s, name) ...`.
3. Run `zig ast-check` on every new file before a pool compile: it is allowed on the Mac (no compile) and catches the syntax half at once.

**Takeaway**: **On 0.17, no `**` and no `.fields`: spell repeated literals out and iterate `field_names`; `zig ast-check` locally before spending a pool run on syntax.**
