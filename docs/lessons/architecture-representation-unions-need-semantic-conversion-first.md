# Architecture: Representation unions need semantic conversion first

**Date**: 2026-10-04
**Lesson**: Convert semantic wrapper types before recursively converting their representation fields.

**Why**: A tagged union may describe storage rather than an API-level choice of types. Converting the active field loses the meaning shared by its variants.

**What Happened**: IndexedDB exposed empty object-store and index names through DOMStringList. Its item method returned an empty string, but indexed access produced undefined. The indexed binding called the generic toV8Value converter, whose union branch preceded its DOMString specialization. DOMString.empty stores void, so generic recursion converted it to undefined. Nonempty owned and interned variants stored byte slices and happened to become strings, concealing the ordering error.

**Fix**: Give DOMString its semantic conversion before generic union dispatch, as the converter already does for JSValue. Test empty, interned and owned representations through the same generic entry point. Do not make callers choose a different representation of the empty string to bypass a broken conversion. The IndexedDB lane reported the adapter change to its owner under Q34; its separate DOMStringList bounds defect must return optional null rather than an empty-string sentinel.

**Takeaway**: **A storage variant's type is not necessarily the value's public type.**
