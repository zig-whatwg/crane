# Codegen: Find dead generated fields with a compile proof - drop them all, compile everything, read the errors

**Date**: 2026-11-10
**Lesson**: To learn which generated State slots anything reads, drop every slot in a scratch regeneration and compile every artifact (both runners, every test binary with a filter that runs nothing, test-browser, gc_bench, the console): each compile error is one reader, and everything else is dead.

**Why**: Grepping `.own.<name>` cannot attribute a read to an interface (attribute names repeat across hundreds of interfaces, and a descendant reads its ancestor's slot through `base`), and Zig compiles only what is referenced, so a single binary proves nothing about code another binary uses. One scratch compile of everything is exact and takes one build.

**What Happened**: Lane cg1 step 2. The codegen gave 829 generated States (mixin modules included) 3,603 attribute slots, 44,954 bytes of own levels. With every slot dropped (a scratch `implKeepsAttributeStorage` that answered true, never committed), the compile of everything named 220 (file, slot) errors in 47 impls and one test, on 44 interfaces. A per-attribute table of those in the codegen, then the same compile, named 23 more: Zig reports one error per function body, so an init that wrote five slots had shown only its first (Event's descendants write `cancelBubble`, `returnValue` and `defaultPrevented` after `type`). The second round, grepped for `own.<slot>` in the same impls before recompiling, left 223 slots kept and 3,380 removed. Reflection over `own` (`std.meta.fieldNames`, `@field(state.own, name)`) compiles either way, so it was grepped for separately (ElementInternals' deinit loop, DOMQuad).

**Fix**:
1. A scratch patch that drops every slot; regenerate in a scratch mirror; compile `wpt-runner wpt-runner-bug-finding test -Dtest-filter=<matches nothing> test-browser gc-bench repl-exe`.
2. Collect `<file>:<line>: error: no field named '<slot>'`, map each to the interface whose level declares the slot.
3. Encode the readers in the codegen, and before recompiling grep each reader impl for its other `own.<slot>` uses: one error per function body hides the rest.
4. Regenerate for real; the full compile of the same set, with no error left, is the proof.

**Takeaway**: **The compiler is the exact reader index: drop every generated field in a scratch build of everything, and the error list is the set of fields that are read.**
