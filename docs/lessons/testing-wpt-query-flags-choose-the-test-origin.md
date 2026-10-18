# Testing: WPT query flags choose the test origin

**Date**: 2026-10-17
**Lesson**: Check the document origin selected by a WPT variant before changing the API that fails inside it.

**Why**: WPT can put server features in query parameters. A filename without `.https.` can still require HTTPS through `wpt_flags=https`. Appending that query after choosing the listener does not apply the feature.

**What Happened**: `websockets/cookies/006.html?wss&wpt_flags=https` expected a Secure cookie set through `document.cookie` to reach a WSS handshake. Crane's runner chose HTTP from the filename alone, so the page tried to set the cookie from an insecure origin. A new origin assertion failed, while a separate `.https.html` control successfully stored and echoed the Secure cookie over WSS. The backend already recognized the secure transport; changing its cookie policy would have concealed the runner defect.

**Fix**: Pin filename, query and plain-HTTP listener selection in an allocator-backed native test. Read the query before its fragment, match decoded parameter names and values exactly, and select TLS for `wpt_flags=https` while preserving the URL and existing HTTP/2 filename precedence. Test repeated and encoded flags, unrelated parameter names, fragments and generated worker wrappers. The source of the routing contract is WPT's `tools/manifest/item.py`: `URLManifestItem` unions filename flags with `parse_qs(query).get("wpt_flags", [])`, and its `https` property checks that set. Keep cookie storage and WSS transmission as a separate control.

**Takeaway**: **A test's query flags can change its origin; verify that origin before diagnosing a secure-context or cookie failure.**
