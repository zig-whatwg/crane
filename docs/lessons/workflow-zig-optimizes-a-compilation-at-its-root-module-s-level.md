# Workflow: Zig optimizes a compilation at its root module's level; a module's own mode is its semantics

**Date**: 2026-10-11
**Lesson**: In Zig 0.16 one compilation has one LLVM pipeline, chosen by its
root module's optimize mode. Every other module's mode decides only its Zig
semantics (`builtin.mode`, runtime safety) and the flags of the C/C++
sources attached to it. So a ReleaseSafe root over Debug modules gives an
optimized binary that keeps every Debug-only check in those modules.

**Why**: `src/codegen/llvm.zig` takes the opt level from
`comp.root_mod.optimize_mode` (Debug: none; any release mode: Aggressive) for
the whole LLVM module, and no function is marked `optnone` because its module
is Debug. std inherits the root's options (`.parent = options.root_mod`),
while a module created with an explicit `.optimize` keeps its own
`builtin.mode`. A C source is compiled with the mode of the module it is
attached to: v8_wrapper.cpp, added to the runner's root, gets -O2 from a
ReleaseSafe root. The C libraries are artifacts of their own and get the mode
they are built with.

**What Happened**: the WPT runner was to be built optimized (the user,
2026-10-11) without losing what the sweeps read. Crane's diagnostics key on
`builtin.mode == .Debug`: the refcount ledger (`refcount.tracking`), the
isolate cleanup validation, a wrapper-cache report. Making every module
ReleaseSafe would have compiled them out, and keeping them would have meant
editing src/dom and the V8 adapter. The `-Dwpt-runner-optimize=ReleaseSafe`
runner that the speed and teardown lanes measured had in fact been this mix
all along: a ReleaseSafe root over the testing graph's Debug modules. That is
why `nm` there showed LLVM's constant merging in src/ code (equal `const`
markers folded into one) while `builtin.mode` in src/ still read Debug.

**Fix**: tests/wpt_runner/build_mode.zig names each part's mode and pins it.
The root is ReleaseSafe, which sets the LLVM pipeline for all of the runner's
Zig and puts v8_wrapper.cpp at -O2. Crane's modules keep -Doptimize's mode.
The runner gets its own C libraries, ReleaseSafe, in a module graph of its
own, and the full C sanitizer stays on in the safe modes. The banner prints
all three modes. Measured against a build with every module ReleaseSafe
(`-Doptimize=ReleaseSafe`), keeping the modules Debug cost nothing. The bars
were 0.97-1.007x (ps-parser-page, ed-qsa and five gc_bench bodies, 7
alternating rounds), and the tampered NodeList files were about 4% slower,
while Debug to this mode was 0.19-0.57x on the same bars.

**Takeaway**: **The root module's mode is the optimizer; every other module's
mode is its semantics. To speed up a binary without losing a module's
Debug-only checks, raise the root and leave the module. To know what a binary
really is, ask about each part - root, modules, C sources, C libraries -
because "a ReleaseSafe build" names only the root.**
