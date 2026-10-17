# specs/idl - pinned webref snapshot

The generated WebIDL tree under `src/webidl/{interfaces,typedefs,dictionaries,callbacks,mixins,namespaces,enums}/`
is committed, so it must be a pure function of committed inputs. Its inputs are this directory and
`specs/supplementary/`, read together by one codegen invocation.

## Revision

- Source: https://github.com/w3c/webref, branch `curated`, directory `ed/idl/`
- Commit: `bfbec43f445931190d9bc68e8c0d7844b7daba65`
- Commit date: 2026-09-17T01:15:12Z ("Publish curated data from 0fe6123fbf356edc918a3ba1eff00ec76057a1e5"),
  the commit tagged `@webref/idl@3.84.0`
- Files: 338 `.idl` files, byte-identical to that commit's `ed/idl/` tree

The source is webref's **curated** branch, not `main`. `main`'s `ed/idl/` is the raw crawl; the
curated branch applies webref's patches and is what the `@webref/idl` package publishes. WPT's
`interfaces/` is synced from that package, and the pinned WPT tests assert it, so Crane's IDL is
taken from the same place.

This commit was chosen on 2026-10-16 by matching the git blob hash of every file in the pinned
WPT's `interfaces/` (tests/wpt at upstream afe89a5df4, 2026-09-29) against the `ed/idl/` tree of
each curated and main commit from 2026-09-01 to 2026-10-02. It matches best:

- 332 files identical;
- `cssom.idl` differs only by WPT's own "GENERATED PREAMBLE" (`typedef DOMString CSSOMString`),
  which Crane defines in `specs/supplementary/CSSTypedefs.idl`;
- `scroll-animations.idl` is the one residual difference: the pinned WPT carries the 3.85.0
  version (curated a4c00dd19, 2026-09-28), where `ViewTimelineOptions.subject` is `required` and
  `ViewTimeline`'s constructor argument is not optional. It is left at this commit's version, so
  the snapshot is one commit;
- 13 files only in WPT: its own `*.tentative.idl` files, `META.yml` and `README.md`;
- 4 files only here: `epub-rs`, `json-ld-api`, `json-ld-framing`, `yaml-ld` (WPT does not sync
  them).

The previous revision was main `08fb1a310e343019f154e18521e1612ad6d149c0` (2025-12-17, 334
files). Its revision was not recorded when the files were downloaded; it was recovered on
2026-10-01 by the same blob-hash matching.

Nothing in this directory is Crane's. Crane's own IDL - definitions webref lacks, or that codegen
needs spelled out - lives in `specs/supplementary/`. Seven such files used to sit here beside the
webref ones; they moved there when this snapshot was committed, so that an IDL update cannot drop
them.

## Updating

1. Pick a commit on webref's `curated` branch (the one whose `ed/idl/` best matches the pinned
   WPT's `interfaces/` by blob hash - normally a commit tagged `@webref/idl@<version>`) and
   download its `ed/idl/` into this directory, replacing every `.idl` file (delete files webref
   removed):

   ```bash
   sha=<full webref commit SHA>
   tmp=$(mktemp -d)
   curl -sL "https://github.com/w3c/webref/archive/$sha.tar.gz" | tar -xz -C "$tmp"
   rm specs/idl/*.idl && cp "$tmp"/webref-$sha/ed/idl/*.idl specs/idl/ && rm -rf "$tmp"
   ```

2. Record the full SHA and its commit date above.
3. Regenerate from both sources in one invocation (see AGENTS.md, "WebIDL codegen"). If codegen
   stops with "duplicate definition of X", a name is now defined in more than one file: find
   webref's `curated` branch commit "Curated data generated from raw data at <sha>", read
   `ed/idlnamesparsed/X.json` (`defined.href` names the defining spec) and add X to `definers` in
   `src/webidl/codegen/duplicates.zig`; drop entries for names no longer duplicated.
4. Diff `src/webidl/impls_tmp/` against `src/webidl/impls/` and merge signature changes into the
   impls by hand.
5. Build, run `zig build test` (which runs the codegen drift check), and run a full WPT worklist
   A/B against the previous main before merging.
