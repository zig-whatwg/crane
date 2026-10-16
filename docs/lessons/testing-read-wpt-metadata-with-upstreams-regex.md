# Testing: Read a test's META lines with upstream's regex, and stop where upstream stops

**Date**: 2026-10-16
**Lesson**: The WPT runner matched `// META:` as a literal prefix, so `//META: global=worker` (workers/Worker-constructor-proto.any.js) was no metadata: the file got the `.any.js` defaults and ran a window variant that MANIFEST.json does not list - a TIMEOUT that blocked the file.

**Why**: Upstream reads metadata with `js_meta_re` (`//\s*META:\s*(\w*)=(.*)$`, matched from the line's first byte) and stops at the first line that does not match (`read_script_metadata`). It takes the FIRST `global` line, and expands each name through `_any_variants`: `worker` is the dedicated, shared AND service worker, `shadowrealm` six variants. A runner that approximates any of these runs a different set of URLs than wpt.fyi and the manifest list.

**What Happened**: Comparing the old parser with upstream's rules over the 10,035-file worklist (and checking upstream's model against MANIFEST.json, which it matched for every worklist `.any.js`) found one file whose run set changed. It also found thirteen `global=worker` files whose single run went unlabelled, because only one global was declared. `wpt_test_ids.pickManifestUrl` therefore gave their results the manifest's first URL, `.any.serviceworker.html`.

**Fix**: `test_parser.parseMetaComments` implements the regex, the stop rule, first-global-wins, the empty-value defaults and `GlobalType.expand` (upstream's longhands). It adds `window-module` and `jsshell` as declared-never-run globals. Unit tests pin the declared set and the run set for each global combination (workers4, 752f26d57ce).

**Takeaway**: **The runner's variant set must be upstream's manifest, not an approximation of it: port the regex and the expansion table, and before changing the parser, diff its run set against MANIFEST.json for the whole worklist.**
