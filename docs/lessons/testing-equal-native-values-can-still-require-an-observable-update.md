# Testing: Equal Native Values Can Still Require an Observable Update

**Date**: 2026-10-29
**Lesson**: Test equal-value setters against both serialized attributes and mutation records; native equality does not prove the public operation is a no-op.

**Why**: The parsed declaration and the raw style attribute are separate observable representations. A successful setter may need to canonicalize the attribute and notify observers even when its native value already compares equal. A test starting from an empty element does not exercise that path.

**What Happened**: Typed OM property maps used the native declaration setter's `changed` flag to decide whether to update the element's style attribute. Setting an empty CSSUnparsedValue over a raw `--foo:` declaration therefore retained that spelling instead of producing `--foo: ;`. Starting from the canonical spelling exposed the second defect: no attributes mutation record. A fresh fourteen-case regression reproduced nine failures across empty and nonempty custom values, unit strings, keywords, CSS-wide values and shorthands.

Chrome 156 and Safari 27 agreed in three probes each that successful equal-value sets queue one record; Firefox 158 did not ship attributeStyleMap. Their shorthand text split was settled by the integrator in favor of uniform reserialization. Evidence: `tmp/probes/q178/RESULT.md`, row 128 ANSWER Q178. Invalid sets and zero-argument append calls remained no-ops.

**Fix**:
1. Seed each case with its exact raw attribute before observing the setter.
2. Cover both noncanonical and already-canonical initial text; the latter detects missing notifications independently of serialization.
3. Assert the result text and the mutation record's count, old value, name, namespace and target.
4. Keep invalid-input and empty-operation controls beside the successful cases.
5. In the Typed OM inline setter, perform the existing attribute-update step after every successful assignment. Retain the native `changed` flag where it governs rule-sheet invalidation.

**Takeaway**: **Equal stored values do not imply an unobservable setter. Test the representation and notification contracts separately.**
