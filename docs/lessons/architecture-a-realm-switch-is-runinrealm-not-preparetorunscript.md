# Architecture: A realm switch inside a task is runInRealm, not prepareToRunScript

**Date**: 2026-09-27
**Lesson**: `engine.prepareToRunScript` pushes an execution context, so every callback run inside it stops checkpointing microtasks between listeners; engine code that only needs a realm entered to fire an event uses `engine.runInRealm` (or `runTaskInRealm` for a whole task).

**Why**: HTML "prepare to run script" pushes the realm's execution context onto the JavaScript execution context stack, and "clean up after running a callback" performs a microtask checkpoint only when that stack is empty. On V8 the adapter counts prepared scopes (`protocol_scripts.prepared_depth`) and checkpoints only at depth 0. A popstate fired inside a prepared scope therefore runs all its listeners before any of their microtasks - where a browser, firing it from a task with an empty stack, runs each listener's microtasks before the next listener.

**What Happened**: Moving `History.zig` onto the protocol, `sameDocumentTraversal` replaced `v8.JsScope.init(window.ctx)` - a HandleScope and an entered context, no execution context - with `prepareToRunScript`/`cleanUpAfterRunningScript`, following the recipe's "scope-shaped code that cannot become a callback". It compiled and read naturally, but it changed when microtasks run between popstate listeners, and it pushed the window onto the adapter's accessor stack as a side effect.

**Fix**: Turn the body into steps and run them with `engine.runInRealm(window.ctx, steps, data)` - the traversal task is already running and only switches realm per navigable. A task the host event loop runs (hashchange, a lifecycle event) uses `engine.runTaskInRealm`. Keep `prepareToRunScript` for what the spec calls "prepare to run script": evaluating a script.

**Takeaway**: **`JsScope` translates to `runInRealm`/`runTaskInRealm`; `prepareToRunScript` is for running script, and around event dispatch it silently moves microtask checkpoints.**
