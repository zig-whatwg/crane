# Architecture: A document's body ends in a networking task of its own

**Date**: 2026-11-07
**Lesson**: When a parser can consume its whole input in one task, EOF and "the end" must still come from a later networking task, or a task queued by the document's own scripts - a planned form navigation - runs after the parser has stopped, and HTML's "abort a parser" has nothing left to abort.

**Why**: In a browser the body's bytes and its end reach the parser as separate network events: Blink's DocumentLoader::BodyDataReceived and BodyLoadingFinished are different tasks even for a body that came in one chunk, and WebKit's dataReceived and finishedLoading are too. HTML's "the end" runs only once the parser has processed EOF. So while a document's inline scripts run, the parser is active, and a navigation that one of those scripts queues finds it active when the task runs. Crane parsed a fully received body, and processed EOF, in the commit's own task.

**What Happened**: replace-before-load/form-submit.html, form-requestsubmit.html and form-submit-button-click.html pass in Chrome, Firefox and Safari, and failed in Crane. The frame's first load event was for the document that submitted the form, not for its replacement. A trace showed the planned navigation's task running after DOMContentLoaded and load had been queued by "the end". Its "abort a document" found no active parser, so DOMContentLoaded and load still fired, and so did the iframe's load event.
- The first fix moved EOF into its own task in DocumentParser.readArrived, the streamed path. It fixed only the file whose body was still arriving at the commit. The 4,413-file pair moved 2 files.
- A body that had fully arrived before the navigation responded (a fast server) was committed whole and parsed by createComplete with complete input. It needed the same treatment.
- The integrator's question was "is this the root?". A special case in "abort a document" that treated queued-but-unrun DOMContentLoaded/load tasks "as an active parser" would have been a copy of the parser's state kept in sync by hand.

**Fix**:
1. readArrived: a read that takes bytes and finds the body ended parses those bytes, then queues the EOF as the next networking task. The encoding sniffing wait ends there.
2. createComplete: a response Fetch made (NavigationFetchResult.fetched: HTTP(S), and the scheme fetches of blob:, data: and file:) starts with its input not complete. A queued EofTask processes the EOF. Documents HTML makes without a fetch keep the one-run parse: srcdoc, about:blank, javascript: results, document.open, and the embedder's markup.
3. An aborted parser's EofTask does nothing: an aborted parser never runs "the end".

**Takeaway**: **When the engine does in one task what the browser receives as several network events, keep the event boundaries the page's scripts can observe: the body's end is its own task. Before patching the step that comes too late, ask which state the browser is still in at that moment, and reproduce that state rather than imitating its effects.**
