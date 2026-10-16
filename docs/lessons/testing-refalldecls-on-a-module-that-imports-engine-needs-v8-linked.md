# Testing: refAllDecls on a module that imports the engine needs V8 linked

**Date**: 2026-10-16
**Lesson**: A module that imports `engine` can keep native (non-V8) tests only if they never reference a function that reaches the protocol. `std.testing.refAllDecls` takes the address of every function, which references them all.

**Why**: build.zig binds `engine` to the V8 adapter in the testing graph too. V8 is linked per artifact (`linkV8` in `addTestRoot`), not through the module. So a native test binary links only when nothing it references calls an adapter function. Zig analyzes lazily, so an import alone costs nothing. But `refAllDecls(@This())` in a root test takes `&` of every public declaration and pulls in each function body, all the way to the `v8_*` externs.

**What Happened**: Lane regexop made URLPattern's components real ECMAScript regexps (src/urlpattern/regexp.zig calls `engine.regExpCreateCheck` / `regExpBuiltinExecCaptures`), so `urlpattern` now imports `engine`. Its root's `test { std.testing.refAllDecls(@This()); }` would have referenced `testMatch`, `exec` and `URLPattern.create`, and through them the adapter. Every test that constructs or matches a pattern needs a realm anyway.

**Fix**:
1. In the module root, call refAllDecls only on the engine-free namespaces (tokenizer, parser, regex_generator, pattern_string, process_init, canonicalize).
2. Move every test that reaches the engine to tests/v8, which links V8 and can make an agent and a realm. Give them a shared helper (tests/v8/urlpattern_realm.zig) imported by relative path.
3. Keep the in-file tests of engine-dependent files out of the file, with a comment naming where they went.

**Takeaway**: **Once a module imports `engine`, its native tests must not reference anything that reaches the protocol - scope refAllDecls, and run the rest in tests/v8.**
