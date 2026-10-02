# Codegen: A generated root is walked as a list of types

**Date**: 2026-10-02
**Lesson**: Adding `pub fn installHooks()` to `src/webidl/interfaces/root.zig` broke the V8 adapter's binding loops, and making every interface call into its impl broke four interfaces that have no impl at all.

**Why**: Code elsewhere iterates `@typeInfo(interfaces).@"struct".decls` and hands every declaration to `@typeInfo(@field(interfaces, name))` (external_references.zig, interface_bindings.zig): it assumes the root holds types and nothing else, so a function there is a compile error in a file the codegen never touches. And `const XImpl = @import("impls").X;` in a generated interface is lazy: SVGFEFunc{A,B,G,R}Element have no impl, and nothing noticed while nothing analysed the alias. A comptime loop that calls every interface's new member analyses all 1,260 of them.

**What Happened**: Instances B0 generated a per-interface `installHooks` (delegating to the impl's, when it declares one) and a root-level loop calling each, so crane.Process installs every src/dom hook once. The first wpt-runner build failed with "expected type 'type', found 'fn () void'" at nine sites in the adapter and "root source file struct 'root' has no member named 'SVGFEFuncAElement'" in four interfaces.

**Fix**: The root's helper is a struct, `pub const process_hooks = struct { pub fn install() void {...} };` - a type without `Meta`, which the adapter's loops already pass over - iterating a private `const members = @This();` (non-pub declarations are not in `decls`). Each interface looks its impl up instead of naming it: `const impls = @import("impls"); if (comptime @hasDecl(impls, "X")) { if (comptime @hasDecl(impls.X, "installHooks")) impls.X.installHooks(); }`.

**Takeaway**: **A generated root is an API that other code walks; add only declarations of the kind it already holds, and never make generated code name something that may not exist - look it up with `@hasDecl`.**
