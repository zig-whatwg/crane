# Architecture: A value the spec calls COMPUTED must not be cached

**Date**: 2026-09-22
**Lesson**: Four getters in a row returned null or "" because they read a field
somebody had to remember to set, where the spec defines the value as derived
from the tree.

**Why**: the caches are filled by the PARSER paths only - `HTMLParser`,
`dom_tree_adapter`, `scripted_parser`, `context_manager`. Anything built through
the DOM API skips all four, so the field stays null and every getter downstream
of it answers null too.

    documentElement   read internal.document_element   -> null for DOM-built docs
    body / head       derived from documentElement     -> null with it
    doctype           read internal.doctype            -> null
    nodeName          read Node's internal.local_name  -> "" for EVERY element

`nodeName` is the same shape as the CharacterData bug fixed in c36582d40: an
element's local name lives in ELEMENT's state, not Node's, so Node's copy is
always null. It now delegates to `Element.tagName`, which DOM 4.9 already
defines as the HTML-uppercased qualified name `nodeName` is supposed to return.

**What Happened**: `document.implementation.createHTMLDocument("")` returned a
document whose `.body` was null, even though the constructor had correctly
created and appended html/head/body. The cost was not one API: `dom/common.js`
builds its fixtures inside `setup()`, and testharness RETHROWS out of `setup()`,
so a single null turns the whole FILE into a harness ERROR with zero subtests.

**Fix**: compute from the tree, keep the cache only as a fallback so paths that
set it without linking the tree still work. A cache also goes stale - removing
or replacing the root left the old pointer in place.

**Takeaway**: **When a spec says "the first X child", store nothing.** Walking a
document's children costs nothing; a cache that only one code path fills is a
null waiting for the other paths to find it. Grep for `internal.<thing> orelse
return null` in a getter whose spec text begins "the first".
