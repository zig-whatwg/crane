# Architecture: An empty `MaybeLocal` from a V8 callback is a promise, not a return value

**Date**: 2026-09-22
**Lesson**: `v8::Module::ResolveModuleCallback` returning empty means "I have
already thrown". Returning empty without throwing kills the process.

**Why**: V8 cannot represent "no module and no reason". Its internals `CHECK`
that an exception is scheduled whenever a resolve callback comes back empty, and
a failed `CHECK` is `IMMEDIATE_CRASH()` - SIGTRAP on arm64, with no Zig frame in
the trace because nothing Zig wrote is on the stack.

**What Happened**: `v8_Module_SetResolveCallback` is **never called from Zig**.
`moduleResolveCallback` exists in `script_execution.zig` and nothing installs
it, so `g_module_resolve_callback` was always null and
`V8ModuleResolveCallback` returned `MaybeLocal<Module>()` for every import in
the process. Every `<script type=module>` containing an `import` took the
runner down. In `html/semantics/scripting-1/` that was 47 of 59 measured
crashes, all in `the-script-element/module/`, plus `json-module/`,
`import-attributes/` and `microtasks/` - and it read as "modules crash",
which is a much larger-sounding problem than one missing `ThrowException`.

A `TryCatch` does NOT help here. It catches a thrown exception; it cannot catch
a `CHECK` inside V8.

**Fix**: throw before returning empty - a TypeError, which is also what the HTML
spec's "resolve a module specifier" produces on failure - and skip the throw if
`isolate->HasPendingException()` so a real cause is not clobbered. Separately,
`v8_Module_Compile`, `v8_Module_Instantiate` and `v8_Module_Evaluate` (the
non-`_Safe` trio) had no `TryCatch` at all, so a syntax error left an exception
pending that detonated at the next unrelated V8 call.

**Takeaway**: **Every V8 API that can return "empty" documents what it wants
alongside it. Read the contract, not the signature - the signature will compile
either way and the violation surfaces as a process death somewhere else.**
