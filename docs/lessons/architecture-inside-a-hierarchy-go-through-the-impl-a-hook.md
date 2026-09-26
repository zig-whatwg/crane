# Architecture: Inside a hierarchy, go through the impl - a hook there is a detour

**Date**: 2026-09-23
**Lesson**: Moving every `NodeImpl.setOwnerDocument` call onto the `node_document` hook was wrong for the callers that ARE Nodes. Text, Attr, Document and the ParentNode mixin reach node-document state through the Node impl directly: it is their ancestor, so it is their own state.

**Why**: A hook is the owner's step made available to code OUTSIDE its hierarchy - DOMImplementation, the HTML parsers, the context manager - which may not import the owner's impl. A subtype routing through it instead of calling its ancestor's impl reaches the state by a side door, which is exactly what the impls boundary exists to stop.

**What Happened**: a review stopped at `Text.zig:249` - `node_document.set(new_node, doc)` in `splitText` - and asked why Text was not going through the impl. The audit found 16 such detours: Document 12, ParentNode 2, Text 1, Attr 1. The remaining 20 hook uses - DOMImplementation, HTMLParser, the src/html parser adapters, the context manager - are outside the Node hierarchy and correct.

**Fix**: the 16 call `NodeImpl.setOwnerDocument` again. The lint now reads each impl's ancestry from the generated interfaces, stops counting references to ancestors, and fails - strictly, with no baseline - on any hook used from inside its owner's hierarchy (hooks declare owners on a `//! lint-impls: hook for <Owner>` line). Reintroducing the Text call fails it at `Text.zig:248`.

**Takeaway**: **"Impls are private" is about other types. Your ancestors are you: go through their impl. Hooks are for strangers.**
