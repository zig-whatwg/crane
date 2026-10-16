# Codegen: A generated default runs a src/dom algorithm, not an impls helper

**Date**: 2026-10-12
**Lesson**: When codegen supplies a member's implementation by default, the generated accessor calls a spec algorithm in src/dom (the generated modules import `dom`), never a helper file in src/webidl/impls/; what the IDL fixes - the attribute's name - is decided at compile time, so the default costs nothing the hand-written member did not.

**Why**: AGENTS.md's impls boundary, rule 3: shared helpers do not live in src/webidl/impls/. A helper there is
reached by `@import("impls").x` from every generated file, so the final module-graph step (impls batch B11,
`impls` imported only by the generated layers) would keep a second door into impls open, and the lint does not
count lower-case helper files (design 1.2). [Reflect]'s default set the precedent the wrong way:
`@import("impls").reflection`.

**What Happened**: Impls batch B5 (lane implsb5) made every EventHandler, OnErrorEventHandler and
OnBeforeUnloadEventHandler attribute's getter and setter a codegen default (HTML 8.1.8.1 gives them all the same
steps; WebKit's generator does the same, CodeGeneratorJS.pm's IsEventHandlerType branch). The first draft
followed the reflection precedent: `@import("impls").event_handler_attributes`, which took the impl as a
comptime parameter so GlobalEventHandlers could supply "determining the target of an event handler" (a body or
frameset element's window-reflecting handlers are its Window's). The integrator redirected it before the
regeneration: the design names `dom.event_handlers.value` / `setValue`. Moving it showed the impl parameter was
never needed - "determining the target" reads only interfaces (the receiver's brand, its node document, the
document's window), so it went into dom.event_handlers with the rest, and impls/event_handler_target.zig (a
shared helper in impls/) went too. Its step 2 ("if name is not ... in the Window-reflecting set, return
eventTarget") depends only on the attribute's name, which the generated call passes as a comptime string: for
every handler outside the set the step compiles away, so `el.onclick` costs one hook call where it used to cost
two brand checks.

**Fix**:
1. `build.zig`: `interfaces_mod.addImport("dom", dom_mod)` and `mixins_mod.addImport("dom", dom_mod)` - the
   generated layers may call src/dom, as impls do.
2. The default in `writer.zig` is `if (comptime @hasDecl(Impl, "get_onload")) return try Impl.get_onload(instance);`
   then `return event_handlers.value(EventHandler, instance, "onload");` with
   `const event_handlers = @import("dom").event_handlers;` declared once per file.
3. `dom.event_handlers.value(Handler, this, comptime name)`: `if (comptime !isWindowReflecting(name)) return this`
   before the runtime brand checks; the map stays EventTarget's, through the steps it installs.
4. Impl stubs (impls_tmp) skip the accessor, as they skip a reflected one, or a stub would override the default.

**Takeaway**: **A generated default is a spec algorithm the generated layer calls: put it in src/dom, decide what
the IDL fixes at compile time, and hook only what needs an impl's own state.** impls/reflection.zig is the same
debt, waiting to move.

**Status (2026-10-13)**: the reflection debt is paid - Codex row 28 moved impls/reflection.zig to src/dom/reflection.zig and the [Reflect] default now calls dom.reflection (merge e2671295b9).
