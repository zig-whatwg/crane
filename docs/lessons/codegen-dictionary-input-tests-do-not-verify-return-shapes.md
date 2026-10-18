# Codegen: Dictionary Input Tests Do Not Verify Return Shapes

**Date**: 2026-10-16
**Status** (2026-10-17): the bindings owner's part is done - the output converter writes a defaulted or present-null member and flattens an inherited dictionary in WebIDL order (lane binding4; [A dictionary member with a default always exists](codegen-a-dictionary-member-with-a-default-always-exists.md)).
**Lesson**: A dictionary's native representation can convert correctly from JavaScript while its return conversion loses nullable members or exposes inheritance storage.

**Why**: Optional Zig fields commonly encode absence with null. A nullable IDL member also needs null as a present value. Derived dictionaries store inherited members in `base`, although JavaScript dictionaries expose those members directly. Input and output converters must both understand these distinctions.

**What Happened**: Implementing Sanitizer exposed three separate cases. An element namespace with a non-null default could not distinguish omission from explicit null. A native attribute namespace that was null disappeared from `get()`'s JavaScript result. An element's inherited name and namespace appeared inside a `base` property. Correct native configuration tests could detect neither return-shape defect. The existing Opt input conversion did preserve omission, undefined, null and strings without leaking.

The actual-process `leaks --atExit` comparison then found 5,687 additional 16-byte Global allocations in the configuration test. Sequence entries whose type was a union, and dictionary members wrapped in Opt, were converted to new objects or strings but excluded by a type-only release predicate. Input cleanup and the native allocator tests had both passed. The active value determines ownership for these output shapes.

**Fix**: Preserve presence for the narrowly granted nullable, non-null-default fields and pin that rule and its unchanged default cases. Test Opt dictionary conversion and cleanup with the actual adapter. Keep the native sanitizer model correct and add JavaScript regressions for null output and inherited fields; the general output-conversion fixes remain with the bindings owner. Do not hand-edit generated structs, substitute an empty string for null, or add feature-specific serialization exceptions.

Gate nested union/Opt output conversion on stable live-handle counts and an actual-process leak comparison as well. Its owner must prove which converted values are newly allocated and which are borrowed; a feature implementation must not compensate with custom serialization.

**Takeaway**: **Test dictionary round trips in JavaScript, including present null and inherited members; native values and input-only tests cannot establish the return shape.**
