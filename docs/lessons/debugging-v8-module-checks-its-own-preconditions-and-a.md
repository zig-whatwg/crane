# Debugging: `v8::Module` CHECKs its own preconditions, and a failed CHECK is SIGTRAP

**Date**: 2026-09-22
**Lesson**: `IsGraphAsync`, `GetModuleNamespace` and `Evaluate` all require a
module that is at least `kInstantiated`, and enforce it with a CHECK.

**Why**: The doc comments read as advice ("Must be called after module
instantiation"). They are not. V8 aborts:

    # Fatal error in v8::Module::IsGraphAsync
    # v8::Module::IsGraphAsync must be used on an instantiated module

**What Happened**: `script_execution.runModuleFromSource` asks
`engine.hasTopLevelAwait(module)` immediately after compiling, to choose between
the sync and async evaluation paths - before anything instantiates. So EVERY
module script killed the process, including inline ones with no imports, which
is why the first hypothesis (unresolvable imports) fit the failing set well
enough to be believed and was wrong. The journal only records
`.{ .signal = .TRAP }`; the message is on the child's stderr and the runner
swallows it unless you run the one file by hand.

**Fix**: guard at the FFI boundary, where "V8 will abort" becomes a value Zig
can see - `if (local_module->GetStatus() < Module::kInstantiated) return ...`.
False for `IsGraphAsync` is the safe answer, because the caller then evaluates
synchronously and `Evaluate()` on a top-level-await module returns a promise
anyway.

**Takeaway**: **Run the one crashing file by hand before theorising. A
`.{ .signal = .TRAP }` in the journal is V8 telling you exactly what is wrong on
a stderr nobody is reading.**
