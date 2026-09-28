# Workflow: Before deleting an API, grep for the field as well as its accessor

**Date**: 2026-09-28
**Lesson**: The runtime Engine table was reached through `ctx.getEngine()`, and the audit that listed its callers grepped for that call. FormData.getAll read the field directly, as `instance.ctx.engine orelse ...`, and was on no list.

**Why**: An accessor is a convention, not a boundary. ContextData's `engine` field was public, so any file could skip the accessor. A caller written that way is invisible to a grep for the accessor, and it stays invisible until the field is deleted and the build fails in a file nobody planned to touch. In this case that file belonged to another lane, so the fix needed a grant.

**What Happened**: Part A of the engine-adapter cleanup scoped its grants from `grep -rn 'getEngine()' src tools`. After the runtime callers were ported, a second grep for `ctx.engine` found src/webidl/impls/FormData.zig calling `engine.createStringArray` through the field. That operation has no protocol twin; it became `engine.createSequenceOfValues(...).take()`.

**Fix**: grep for every way to reach the thing being deleted: the accessor, the field (`\.engine\b`, `ctx\.engine`), the type name, and struct-literal initialisations (`\.engine = `). Do it before asking for grants, so the list of files is complete.

**Takeaway**: **A deletion's blast radius is every reference to the storage, not every call of its getter. Grep for the field, the type and the initialiser before you scope the work.**
