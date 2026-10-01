# specs/idl - pinned webref snapshot

The generated WebIDL tree under `src/webidl/{interfaces,typedefs,dictionaries,callbacks,mixins,namespaces,enums}/`
is committed, so it must be a pure function of committed inputs. Its inputs are this directory and
`specs/supplementary/`, read together by one codegen invocation.

## Revision

- Source: https://github.com/w3c/webref, directory `ed/idl/`
- Commit: `08fb1a310e343019f154e18521e1612ad6d149c0`
- Commit date: 2025-12-17T00:52:47Z ("Update of ED report from new reffy run")
- Files: 334 `.idl` files, byte-identical to that commit's `ed/idl/` tree

The revision was not recorded when the files were downloaded (webref `main` as fetched by
`zig build setup`; the directory is dated 2026-01-14). It was recovered on 2026-10-01 by matching
the git blob hash of every local file against the `ed/idl/` tree of each webref commit from
2025-11-15 to 2026-01-15: this commit's tree matches all 334 of its files, and the later ones
do not.

Nothing in this directory is Crane's. Crane's own IDL - definitions webref lacks, or that codegen
needs spelled out - lives in `specs/supplementary/`. Seven such files used to sit here beside the
webref ones; they moved there when this snapshot was committed, so that an IDL update cannot drop
them.

## Updating

1. Pick a webref commit and download its `ed/idl/` into this directory, replacing every `.idl`
   file (delete files webref removed):

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
