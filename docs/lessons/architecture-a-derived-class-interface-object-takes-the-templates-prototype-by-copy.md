# Architecture: A derived-class interface object takes the template's prototype object by copy

**Date**: 2026-11-21
**Lesson**: To give an interface a [[Construct]] that makes no receiver (HTML's [HTMLConstructor] reads NewTarget.prototype only at step 10), make its interface object a derived class from a V8 extension, copy the template function's prototype object onto the class's own prototype object, and point the template function's `prototype` at the class's - a class's `prototype` can never be given an existing object.

**Why**: V8 makes an API function's receiver before its callback (builtins-api.cc HandleApiCallHelper<true> -> ApiNatives::InstantiateObject -> JSFunction::GetDerivedMap, a [[Get]] of a Proxy NewTarget's "prototype"), and no public API skips it - Chrome fails custom-elements/HTMLElement-constructor-customized-builtins.html for that reason. Only a derived class's [[Construct]] makes no receiver (ECMAScript 10.2.2 step 3). But ClassDefinitionEvaluation defines the class's `prototype` as a fresh object, non-writable and non-configurable: no Set, DefineOwnProperty or API call can replace it with the template's prototype object, which every wrapper the instance template makes inherits from.

**What Happened**: Lane blk6's design note for this (option (b)) said the class's `prototype` would be "the FunctionTemplate's prototype object". That is impossible as written; lane blk7 found it before writing code.

**Fix**:
1. The class comes from a v8::Extension (registered once at the platform start; ExtensionConfiguration on every Window context path; V8 never installs extensions into the snapshot). Extension functions are not user JavaScript (Script::Type::kExtension), so Function.prototype.toString prints "function HTMLElement() { [native code] }" and stack traces hide their frames, as for an API function. One class literal per interface, so each has its own SharedFunctionInfo and name; a `native function` declared inside an IIFE hands the context its factory without a global.
2. The template for such an interface skips ReadOnlyPrototype, so the template function's `prototype` stays writable until the swap.
3. In C++ (no JS-observable lookups: read each descriptor field as an own property of the descriptor object, never through %Object.prototype%): copy P's own properties onto the class's prototype Q in P's order (`constructor` = the class), set Q's [[Prototype]] to P's, copy the template function's extra own properties (constants, statics) onto the class, then `template_function.prototype = Q` (JSFunction::SetPrototype gives its initial map Q) and make it read-only.
4. Every wrapper is made after its realm builds the interface object (template_registry.ensureInterfaceObjectBuilt), and an interface under an [HTMLConstructor] one builds its parent first, so V8's Inherit links a child's prototype object to Q, never to the old P.
5. Pin the shapes first (tests/v8/html_constructor_shape_test.zig: toString, name, length, own keys with kinds and attributes per interface, both chains, element prototypes, snapshot-restored and fresh realms).

**Takeaway**: **A class's `prototype` is fixed at creation: when a class must stand in for a template's function, move the template's prototype object's contents to the class's and re-point the template - never try to re-point the class.**
