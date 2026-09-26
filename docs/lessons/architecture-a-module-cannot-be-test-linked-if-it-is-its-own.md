# Architecture: A module cannot be test-linked if it is its own dependency

**Date**: 2026-09-21
**Lesson**: `zig test` collects test blocks from the ROOT module only, and a module that is its own transitive dependency cannot be cloned into a test root.

**Why**: Two separate walls, both measured rather than guessed:

* **Cloning it** (same root file, own link objects) fails when the module
  appears twice in one compile. `build.zig:1850` does
  `impls_mod.addImport("html", html_mod)`, so `html_mod` depends on itself
  transitively and the command line carries both `-Mroot=src/html/full.zig` and
  `-Mhtml=src/html/full.zig`:
  `error: file exists in modules 'root' and 'html'`.
* **Linking V8 into it in place** produces **844** `duplicate symbol definition`
  errors, because a module's link objects belong to every artifact downstream of
  it, and four of them already compile `v8_wrapper.cpp`.
* A generated root doing `_ = @import("html")` does not help either: test blocks
  are collected from the root module only, never from an imported one.

**What Happened**: `src/html/`'s module-root test target has no V8 link. It is
GREEN today and stays green only while Zig's lazy analysis never walks from an
`src/html/` test block into a `v8_*` extern. The same latency applies to
`dom_mod`, `intl_mod` and `platform_mod`.

**Fix**: Either break the cycle - have `src/webidl/impls/**` reach HTML through
`html_core`, as it already does for DOMParser, innerHTML and Window - or keep
every V8-reaching HTML test under `tests/html/`, which IS V8-linked.

**Takeaway**: **"It has no V8 link" and "it is red" are different states.** The
gap is latent until something references across it - the same shape as the
re-export lesson ([architecture-a-re-export-does-not-mean-the-code-is-compiled](architecture-a-re-export-does-not-mean-the-code-is-compiled.md)).
