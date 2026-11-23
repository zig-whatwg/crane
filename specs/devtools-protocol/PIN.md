# specs/devtools-protocol - pinned Chrome DevTools Protocol definitions

The generated protocol types under `src/devtools/protocol/` are committed, so they must be a pure function
of committed inputs. Their inputs are the two JSON files in this directory, read together by one run of
the devtools protocol generator (`tools/devtools_protocol_gen.zig`; `zig build codegen` runs it,
`zig build codegen-check` checks it).

## Revision

- Source: the `devtools-protocol` npm package, https://www.npmjs.com/package/devtools-protocol
  (repository https://github.com/ChromeDevTools/devtools-protocol), published from Chromium's
  `third_party/blink/public/devtools_protocol/` and `v8/include/js_protocol.pdl` by the Chromium Authors.
- Version: `0.0.1717327` (published 2026-10-13T04:52:54Z; package gitHead
  `52f47482cb75a20e524effae750d51406775460d`). Chrome 157's branch point is Chromium revision 1717349:
  this is the last protocol published before it, so it is the protocol Chrome for Testing 157 speaks -
  the Chrome the CDP part-1 reference runs used (tmp/plans/cdp-part1-design.md, decision D5).
- Tarball: `https://registry.npmjs.org/devtools-protocol/-/devtools-protocol-0.0.1717327.tgz`,
  sha256 `0519309ab4e11b668a7b36b349af1db3ed95612a8246fe7cfc53b59277cb4363`.
- Files, byte-identical to the package's:
  - `browser_protocol.json` (package `json/browser_protocol.json`), sha256
    `4ae35b31432ff53e64cb4292e84662fa95e99404e35f7b62c64cc3a16d80244e`;
  - `js_protocol.json` (package `json/js_protocol.json`), sha256
    `3716f86e2228f9414ffff43551249bc6a5783388c3fbdba5226f14e6941774f1`;
  - `LICENSE` (package `LICENSE`): BSD-3-Clause, Copyright 2014 The Chromium Authors.

- The DevTools front end of that Chrome: Chromium revision `4b3d0dabb8250b6f152d2d85d79e7706e309d087` (the
  `157.0.8103.78` tag's commit). `/json/list`'s devtoolsFrontendUrl names it, as Chrome's DevToolsHttpHandler
  does (kRemoteUrlPattern, `https://chrome-devtools-frontend.appspot.com/serve_rev/@<revision>/inspector.html`);
  it is `frontend_revision` in src/devtools/server.zig and moves with the pin.

Nothing in this directory is Crane's. `GET /json/protocol` serves these two files' domains merged, as
Chrome's DevToolsHttpHandler serves its own compiled-in copy.

## Updating

The pin moves with the Chrome the reference runs use, as specs/idl moves with webref.

1. Pick the version: the last `devtools-protocol` published before the new Chrome's branch point
   (the Chromium revision in https://chromiumdash.appspot.com/branches; npm `time` lists each version's
   publication). Download its tarball into an empty directory of its own and copy the two JSON files and
   the LICENSE here:

   ```bash
   v=<version, e.g. 0.0.1717327>
   d=$(mktemp -d)
   curl -sSfL -o "$d/p.tgz" "https://registry.npmjs.org/devtools-protocol/-/devtools-protocol-$v.tgz"
   shasum -a 256 "$d/p.tgz"
   tar -xzf "$d/p.tgz" -C "$d"
   cp "$d"/package/json/browser_protocol.json "$d"/package/json/js_protocol.json "$d"/package/LICENSE specs/devtools-protocol/
   rm -rf "$d"
   ```

2. Record the version, its publication time and gitHead, and the sha256 of the tarball and of each file
   above. Commit the files alone (fetching a spec is its own commit).
3. Regenerate (`zig build codegen -- --dest-root src/webidl/`, which also runs the devtools protocol
   generator) and commit the regenerated `src/devtools/protocol/` with the handler changes it needs: a
   command or type the generator's part-1 list names that the new protocol renamed or removed stops the
   generator with its name.
4. Build, run `zig build test` (codegen-check compares the committed `src/devtools/protocol/` with a
   regeneration), and run the CDP client tests (tests/devtools) and the framework suites' runners
   against Crane before merging.
