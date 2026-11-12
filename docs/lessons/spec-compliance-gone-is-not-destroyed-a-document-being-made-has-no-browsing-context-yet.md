# Spec Compliance: "Gone" is not "destroyed", and a Window's own Document is not where detachment shows

**Date**: 2026-11-12
**Lesson**: To make a removed frame's subtree read as detached at once, test the CONTAINER's side (the container left its document, or the container's node document was destroyed). Testing the Window's own Document (`document_activity` "gone", or even "destroyed") also fires for a Window in mid-replacement.

**Why**: Two Crane states look like a detached frame without being one.
- `document_activity.activity` answers the event loop's run/keep/drop question. Its `.gone` covers a destroyed or freed document, and also one that has no browsing context yet.
- A Window kept for the document that replaces its initial about:blank still points at the old about:blank Document. That document is already DESTROYED and is still the navigable's active document while the new document is made. Engine hooks that run then (a service worker client's creation) read the Window's `parent` and `opener`.

**What Happened**: Lane nav2 batch 9 (3a3ddd1dd3a) made Window.zig's `navigableOf` return null when the Window's associated Document was `.gone`, so that iframe-synchronously-discard.html's grandchild Window answers `parent` null at once. The FULL A/B against generation 216 showed 6 service-worker files newly blocking, and windowclient-navigate fell from 20 to 12: `WindowClient.frameType` was "top-level" where "nested" or "auxiliary" was expected.
- The first fix (3299311a6b4) narrowed the check to "destroyed". The probe still failed: hypothesis 1 disproved.
- A diagnostic runner (log lines in navigableOf, get_parent and service_worker/realm.zig `frameTypeOf`) showed `frameTypeOf` running twice per frame Window. The second call came during the replacement, with the Window's document destroyed and equal to the navigable's active document. So `parent` and `opener` read null, and "top-level" was cached.

**Fix**: e463817a97f: `navigableOf` returns null when the navigable's container is disconnected, or when the container's node document is destroyed (`document_lifecycle.isDestroyed`, a hook Document installs). It never looks at the Window's own Document. This covers the removed child (its iframe left the document) and the grandchild (its iframe sits in the destroyed child document). A Window in mid-replacement keeps its navigable.

**Takeaway**: **Name the exact spec state you need and read it where the spec event actually happens. Detachment happens to the container, not to the Window's document. A FULL A/B catches the cross-area reader that a probe of your own files misses. When a narrowed fix still fails, measure the consumer's inputs before guessing again.**
