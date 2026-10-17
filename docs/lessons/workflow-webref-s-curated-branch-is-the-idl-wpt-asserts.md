# Workflow: webref's curated branch is the IDL WPT asserts

**Date**: 2026-10-17
**Lesson**: WPT's `interfaces/` is synced from the `@webref/idl` package, which webref publishes from its `curated` branch. Its raw `main` branch is not that source. So the IDL that matches a pinned WPT is a curated commit, normally the one tagged `@webref/idl@<version>`.

**Why**: webref's `main` branch holds the raw crawl. `curated` applies webref's patches: duplicate definitions removed (SVG.idl's SVGPathElement, which svg-paths.idl also defines), invalid IDL fixed. The npm package is cut from curated, and the WPT bot imports the package.

**What Happened**: specs/idl had been taken from main (08fb1a310e). Blob-hash matching against the pinned WPT (upstream afe89a5df4, 2026-09-29) gave these results:
- The best main commit: 310 of 334 shared files identical.
- curated bfbec43f44 (@webref/idl@3.84.0, 2026-09-17): 332 identical. Of the rest, cssom.idl differs only by WPT's own CSSOMString preamble, and scroll-animations.idl is a newer file the bot synced alone.
- The files only in WPT are its own `*.tentative.idl`. The files only in webref are four non-web specs that WPT does not import.

**Fix**: Take `ed/idl/` from a curated commit, as specs/idl/WEBREF.md step 1 now says. Choose it by blob hash: `git ls-tree <commit> ed/idl/` against `git ls-tree HEAD interfaces/` in tests/wpt. Scan the `@webref/idl@*` tags first; they are the package releases.

**Takeaway**: **Pin Crane's IDL to the package WPT imports, not to the repository's default branch. Match on blob hashes, and report the residuals file by file.**
