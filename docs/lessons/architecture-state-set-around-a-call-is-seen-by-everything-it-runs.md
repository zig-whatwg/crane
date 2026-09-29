# Architecture: State set around a call is seen by everything the call runs

**Date**: 2026-09-28
**Lesson**: A thread-local that a parser sets around "prepare the script element", to hand the embedder's script loader to one script, was also seen by every script that script inserted while it ran.

**Why**: Preparing a parser-inserted inline script executes it, inside prepare. That script can create and insert more script elements, and each of those is prepared, and fetched, before the outer prepare returns. A value scoped to "the duration of this call" is therefore scoped to everything the call reaches, including other elements' algorithms. The WPT runner's loader resolves a src as a path relative to the test file. It knows nothing of `<base href>` or data: URLs, so a script-inserted script given it fetched the wrong URL, or nothing.

**What Happened**: The loader used to prefetch at the script's end tag, before prepare's type and nomodule checks. That meant scripts prepare declines were fetched: speculative-parsing/document-write script-src-nomodule and script-src-unsupported-type went 1 -> 0 once document.write's scripts went through the same callback. Moving the loader into prepare's fetch step, through a thread-local set around the call, fixed those two. It broke three others: execution-timing/020 (a DOM-inserted data: URL script never ran), crane/script-base-url (src resolved against the document URL, not `<base>`), and crane/script-mark-as-ready-task (async=false scripts timed out). All three are scripts that a parser-inserted inline script inserts.

**Fix**: record the element the value is for next to the value (`ScopedParserScriptLoader{element, loader}`), and have the consumer check that it is preparing that element (`parserScriptLoaderFor(script_element)`). Anything else prepared during the call takes the ordinary path. When the loader has no answer (a data: URL), fall back to "fetch a classic script" as before.

**Takeaway**: **A value set around a call is visible to every callee, including ones working on other objects. Key it to the object it is for, not to the time it is set.**
