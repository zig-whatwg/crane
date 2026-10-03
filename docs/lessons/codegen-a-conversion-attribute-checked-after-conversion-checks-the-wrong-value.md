# Codegen: A conversion attribute checked after the conversion checks the wrong value

**Date**: 2026-10-03
**Lesson**: [EnforceRange] and [Clamp] are steps of ConvertToInt and run on the JavaScript number inside the binding's conversion; a check emitted into the generated function runs on the value the binding already wrapped, so it can neither reject nor clamp correctly.

**Why**: WebIDL 3.2.4.9 ConvertToInt applies [EnforceRange] (step 6: NaN, an infinity or a value outside the type's range is a TypeError) and [Clamp] (step 7: clamp, round half to even) to `x = ToNumber(V)` BEFORE step 8 onwards takes it modulo 2^bitLength. Once the binding has produced a `u64` or an `i32`, -1, 2^53 and NaN have all become ordinary in-range integers, and the information the attribute needs is gone.

**What Happened**: Codegen emitted `if (!runtime.isInRange(T, x)) return error.TypeError;` and a clamp into each generated operation, on the already-converted argument. Every way that could go wrong did:

- a required argument never failed - the modulo had already made it fit;
- an optional argument always failed when omitted - the check saw the Opt wrapper's default, not a missing value (IDBFactory.open(name) threw);
- `isInRange(u64, v)` for v >= 2^63 hit `@intCast` and PANICKED: `AbortSignal.timeout(-1)` and `respond(-1)` crashed the runner;
- [Clamp] clamped after the modulo, so 2^32 + 5 clamped to 5.

Dictionary members carried the same attributes, and the IDL parser dropped a dictionary member's extended attributes entirely, so `IDBGetAllOptions.count` had no check anywhere.

Restricted floats were already right because they were a table the binding read (`restricted_floats`, bit i = argument i). The integer attributes were the odd ones out.

**Fix**:
1. Codegen emits tables, no check: `enforce_range` / `clamp` per operation and setter (a bit per argument), `constructor_enforce_range` / `constructor_clamp`, and a dictionary's `enforce_range_members` / `clamp_members`.
2. The IDL parser keeps a dictionary member's extended attributes.
3. The binding (conversions.zig `convertToIntAs`) runs steps 4-7 on the number, Opt-aware (an omitted or undefined optional argument is not converted), for operations, static operations, constructors, setters and dictionary members; the 64-bit bounds are +-(2^53 - 1).
4. `runtime.isInRange` deleted. Red first: crane/cv-integer-conversions.html CRASH -> 3/3; tests/v8 pins steps 6-7, an omitted optional and the u64 negative.

**Takeaway**: **A WebIDL extended attribute that changes a conversion belongs where the conversion runs - in the binding, read from a codegen table - never as a check in the generated function on the value the conversion already produced; and when one attribute family works and another does not, compare where each one runs.**
