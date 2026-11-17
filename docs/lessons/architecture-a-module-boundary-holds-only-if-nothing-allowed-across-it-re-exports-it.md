# Architecture: A module boundary holds only if nothing allowed across it re-exports it

**Date**: 2026-11-17
**Lesson**: Cutting `impls` out of every import table but the generated layer's did not by itself make an impl unreachable: every generated mixin module declared `pub const impl = @import("impls").X;`, and browser and both lib_exports modules import the mixins - so `@import("mixins").ParentNode.impl` reached an impl from outside, past the cut.

**Why**: A module edge is a boundary for what a module can NAME, not for what it can REACH. Anything on the allowed side that publishes a declaration of the protected module (a `pub const` alias, a re-exported type that is the module itself) hands it to every importer of the allowed side. The lint never counted it either: it starts at `@import("impls")` and at file imports, not at another module's re-export (the same blind spot as workflow-a-module-that-re-exports-impls-hides-its-users-from-lint-impls.md).

**What Happened**: Lane impls9 removed `impls` from 14 import sites (dom, html, browser, whatwg, lib_exports, crane, the engine adapter, the test graphs, the WPT runner's root). Before trusting it, it grepped the generated layer for public declarations whose value names the impls - `grep 'pub const [A-Za-z_]* = @import("impls")'` - and found the 99 mixin aliases. The interfaces used them in exactly one place: 8 overload tables asked `@hasDecl(mixins.X.impl, "call_x__1")`.

**Fix**:
1. Codegen writes the mixin's alias as `const impl` (generator.writeMixinPrelude); the overload tables ask `@hasDecl(@import("impls").X, ...)` - the interface imports the impls itself.
2. A compile-failure case pins it: `@import("mixins").ParentNode.impl` in a module with a copy of browser's imports must fail with "'impl' is not marked 'pub'" (build.zig check-impls-boundary).
3. Then the boundary went one level down (design 5.3 4b): each impl is a module of its own, so an impl reaching another - by name or by path - is a compile error too ("no module named 'Node' available within module 'root'", "file exists in modules 'Node' and 'Attr'"). Zig lets a file belong to one module only: a per-file module is file-level privacy the compiler checks.

**Takeaway**: **Before calling a module cut a boundary, list every `pub` declaration on the allowed side whose value is the protected module (or one of its files), and close each one - then pin the compiler's refusal with a case.**
