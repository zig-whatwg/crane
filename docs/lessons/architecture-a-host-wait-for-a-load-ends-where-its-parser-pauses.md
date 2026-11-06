# Architecture: A host's wait for a page load ends where its parser pauses, not at a readiness state

**Date**: 2026-11-05
**Lesson**: When an embedder's load became an asynchronous navigation, waiting "until readiness leaves loading" waited through every parser-blocking script and script-blocking style sheet - forever for one nobody answers - and the host never saw a page whose parser was waiting.

**Why**: The old embedder load parsed in place and returned when its parser did: finished, or paused at a pending parsing-blocking script (HTML "an end tag whose tag name is script" spins the event loop there). Tests and the WPT runner were built on that contract. A readiness check is a different, later condition: "interactive" comes only after the blocking script ran.

**What Happened**: lane loadpath1's first agent made Context.loadByNavigating wait for `readyState != "loading"`. p1_parser_wait_two_browsers (two Browsers' parsers must wait at once), rc8_registries (the pending inline script's hold) and nd_new_document_per_load (a load while the parser waits on a style sheet) failed - each needs the page in the state its parser paused in.

**Fix**: LoadWait.met: committed, and readiness is not "loading" OR the document has a pending parsing-blocking script (dom.document_scripts.of(document).pending_parsing_blocking_script). A streamed http body is still waited out: the parser is "loading" with no pending script while bytes arrive.

**Takeaway**: **When a synchronous host call becomes asynchronous, wait for the event the old call's return stood for - here "the parser ran as far as it can" - not the nearest state flag; list what callers did right after the old return before choosing it.**
