# Workflow: WindowOrWorkerGlobalScope is inherited; its includer state goes through `dom.global_settings`

**Date**: 2026-09-24
**Lesson**: When a mixin's members read state each includer owns, and the spec defines that state through the includer ("this's relevant settings object"), the includers install their answers into a `src/dom/` hook keyed by an `owns` predicate, and the mixin impl asks the hook. This is `global_settings.zig` for origin, isSecureContext, crossOriginIsolated, indexedDB, caches and performance.

**Takeaway**: **A mixin with includer state is still implemented once.** The state stays with each includer and reaches the mixin through a hook, never through the includer's impl.
