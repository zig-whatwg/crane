# Codegen: An erased IDL distinction needs its mark on every conversion path

**Date**: 2026-10-27
**Lesson**: Codegen maps `double` and `unrestricted double` both to f64, so the restriction lives in a table beside the code - and only the paths that read the table enforced it. Constructors, namespace operations and union arms read none, and took NaN and the infinities for years.

**Why**: WebIDL's `double` conversion is ToNumber then "if x is NaN, +Infinity or -Infinity, throw a TypeError" (3.2.7); `unrestricted double` stops after ToNumber. Blink carries the difference in the TYPE: `NativeValueTraits<IDLDouble>` calls ToRestrictedDouble, `IDLUnrestrictedDouble` calls ToDouble, and every conversion site - argument, constructor, union arm, dictionary member - converts with its type's traits (bindings/core/v8/native_value_traits_impl.h). Crane's Zig type cannot say it, so codegen writes `restricted_floats` (attributes and operations) and `restricted_members` (dictionaries). Each new conversion path had to remember to read a table. Three never did.

**What Happened**: Codex row 128 (Typed OM) found `new CSSUnitValue(NaN, "px")` and `CSS.px(Infinity)` accepted where Chrome and Safari throw (probe Q48). The audit found:
- The constructor path converted through `convertArgReleasingWith`, which applies only the integer branch and the interface; the restricted, ByteString and object checks lived in the operation path's private `convertArg`.
- The namespace binding converted with no table at all, and threw a TypeError over a pending exception.
- A union's numeric arm was converted by plain ToNumber: CSSNumberish's `double` arm and MLNumber's `unrestricted double` arm are both named `double: f64`, so neither the arm's name nor its type could tell them apart.
- `conv.toNumber` itself ignored a throwing valueOf (NumberValue's `FromMaybe(0)`), so "? ToNumber" did not propagate on any path.

**Fix** (lane bindfix1):
1. Codegen writes the mark for every path: `constructor_restricted_floats` (per ConstructorArgs variant), a namespace's `restricted_floats`, and `restricted_arms` INSIDE each generated union (the arm names whose type is restricted).
2. One checked converter, `interface.convertArgChecked`, used by operations, sole and overloaded constructors (overload_resolver), variadic elements and namespaces.
3. `conv.fromV8ValueAs` checks the active arm of any union with `restricted_arms` - so an argument, a nullable, a variadic element, a dictionary member, a sequence element and an attribute value all get it, with no table lookup at the site.
4. `toNumber` runs an object's ToNumber under `v8_RunCatching` and answers ExceptionPending.
Pinned by tests/v8/bindfix1_restricted_float_test.zig, bindfix1_union_arm_restricted_test.zig, bindfix1_to_number_test.zig and tests/codegen/bindfix1_restricted_floats_codegen_test.zig.

**Takeaway**: **When codegen erases an IDL distinction into a shared Zig type, list every path that converts that type and make each one read the mark - and prefer putting the mark on the generated type itself (as `restricted_arms` is on the union), where every converter that sees the type sees the mark.**
