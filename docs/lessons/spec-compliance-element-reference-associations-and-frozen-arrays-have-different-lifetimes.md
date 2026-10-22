# Spec Compliance: Element reference associations and frozen arrays have different lifetimes

**Date**: 2026-10-21
**Lesson**: An Element's explicitly set ARIA association is weak, but the FrozenArray returned by its getter keeps its elements alive.

**Why**: HTML's element-reference reflection has two independent pieces of state: the explicit association and the previously returned frozen array. Treating both as one native list either roots a weak target or lets a script-held snapshot lose an element. ElementInternals' private reflection is a separate algorithm and is not a template for Element's ownership.

**What Happened**: Implementing Element's missing reference accessors required both collection of a removed explicit target and survival of an older returned array after the source and target were removed. A getter also has to reuse its previous array when the current sequence is identical. Clearing the content attribute's explicit association does not by itself invalidate that cached identity.

**Fix**: Keep generation-checked weak identities for explicit associations. Filter them by scope without erasing out-of-scope targets. Cache the getter's frozen engine array through an owner-traced value; the array holds its elements, and a script-held array can outlive its source. Test these lifetimes separately, dropping all other script references before collection, and exercise frame removal and document teardown. Follow HTML 2.6.1's same-value attribute reset as well as ordinary attribute changes.

Blink's [Element reference accessors](https://github.com/chromium/chromium/blob/main/third_party/blink/renderer/core/dom/element.cc) and WebKit's [Element reference accessors](https://github.com/WebKit/WebKit/blob/main/Source/WebCore/dom/Element.cpp) use this separation. The implementations informed the ownership design; no browser source was copied.

**Takeaway**: **A weak association and a strong returned snapshot are different holders; model and test each lifetime independently.**
