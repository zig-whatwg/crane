# Spec Compliance: A special operation with an identifier is also a regular operation

**Date**: 2026-09-27
**Lesson**: WebIDL 2.5.3: "If an operation has an identifier, then it is a regular operation" as well as a special one. Codegen's method tables took named getters and setters but not deleters, so `Storage.prototype.removeItem` did not exist.

**Why**: The three method tables (`methods`, `own_methods`, `inherited_methods`) filtered on `op.special == null or .getter or .setter`. The rule the spec states is about the identifier, not the keyword. The filter listed the keywords someone had needed, and left `deleter` (Storage's `removeItem`) and named stringifiers out.

**What Happened**: `localStorage.removeItem` was undefined. webstorage/missing_arguments.window.js "passed" its two `removeItem()` subtests, because calling undefined throws a TypeError too. When removeItem appeared, those two subtests went red. They had been testing a later step that did not exist yet: a missing required argument must throw.

**Fix**: `writer.isRegularOperation(op)` is `op.name != null`, and all three tables use it. Test first: tests/codegen/named_special_operations_test.zig.

**Takeaway**: **Filter operations by whether they have an identifier, never by the special keyword. A keyword list is wrong by default for the keyword nobody needed yet.**
