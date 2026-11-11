# Workflow: A manifest schema change restamps every fetched tree

**Date**: 2026-11-11
**Lesson**: `fw_matrix` stamps each fetched tree with the hash of its whole manifest entry (every field, defaults included), so a new field in `manifest.Suite` - even one a suite leaves at its default - makes every tree stale on every host until `fw_matrix fetch` runs again.

**Why**: fetch.zig `entryHash` is the sha256 of the entry serialized as JSON; a field added with a default (`overlay: []const Overlay = &.{}`) still serializes (`"overlay":[]`), so the hash of jQuery's untouched entry changed. run.zig refuses a tree whose stamp differs (`StaleFetch`), which is the point: a run never uses a tree fetched for another entry.

**What Happened**: Lane fw1 b3 added the manifest's `overlay`, fetched only the four new TodoMVC suites, and started the six-row run: it stopped at once on jQuery with `StaleFetch` (htmx would have too).

**Fix**: after any change to manifest.zig's types, run `fw_matrix fetch --frameworks-dir=...` with no `--suite` on every host that runs suites; downloads are cached by sha256, so only the trees are rewritten.

**Takeaway**: **A schema change to the manifest is a re-fetch of every suite on every run host, before the next run.**
