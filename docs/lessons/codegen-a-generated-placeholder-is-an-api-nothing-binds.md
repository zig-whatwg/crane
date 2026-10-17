# Codegen: A generated placeholder is an API nothing binds

**Date**: 2026-10-17
**Lesson**: Codegen wrote every namespace attribute as `pub const <name>: T = undefined`, and the binding installed nothing for it, so `CSS.paintWorklet` was undefined in every realm - and 211 worklist files failed it as "addModule is not available", an observation that read like a missing worklet implementation.

**Why**: A namespace's readonly attributes (WebIDL 3.13.1: accessor properties of the namespace object) had no path through codegen and the V8 namespace binding: generateNamespace emitted a typed placeholder that compiled, nothing referenced, and no lint flagged - while the impl (`src/webidl/impls/CSS.zig`) had no `get_` function to write because no generated file would call it.

**What Happened**: The worklets lane found it while wiring `Worklet.addModule`: every generated security-features test calls `CSS.paintWorklet.addModule(url)` (common.sub.js `get_worklet`), and the TypeError "Cannot read properties of undefined (reading 'addModule')" came from the namespace, not the worklet. The fix then met a second defect on the same object: `registerNamespacesGeneric` ended with `v8_Object_PreventExtensions`, whose C++ calls `SetIntegrityLevel(kSealed)` - every namespace member was non-configurable and the object non-extensible, which WebIDL 3.13.1 (OrdinaryObjectCreate, configurable members) and idlharness (`Object.isExtensible(namespaceObject)`) contradict.

**Fix**:
1. generateNamespace writes `get_<name>(ctx)` delegates (the impl's getter steps with the current realm; NotImplemented until the impl declares them) and `Meta.attributes` with whether the impl implements each.
2. V8Namespace installs the implemented ones as accessor properties (getter, enumerable, configurable) and registers their external references; an unimplemented one stays absent, as before.
3. The namespace object is no longer sealed.
4. tests/codegen/namespace_attributes_test.zig pins the emission; crane/wl-addmodule pins the descriptor.

**Takeaway**: **A generated declaration that compiles but that nothing binds is a missing API, not a stub - and an FFI name that says less than its call does (PreventExtensions that seals) hides a second one. When a whole family of tests fails on one undefined property, find who should have defined it before implementing what it returns.**
