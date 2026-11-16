# Spec Compliance: Probe the browsers before trusting an engine-source reading of when a document's loads stop

**Date**: 2026-11-14
**Lesson**: A reading of one engine function ("WebKit stops the old document's loads only at the commit") was wrong twice over; a three-browser probe of the observable behaviour settled it in minutes.

**Why**: Where a document's fetches are cancelled is spread over several engine functions (WebKit's
loadWithDocumentLoader, continueLoadAfterNavigationPolicy, commitProvisionalLoad, stopForBackForwardCache), and a
partial read of a 260 KB file stops at whichever one it saw. The error type a cancelled fetch rejects with is not in
the spec's words at all ("cancel any instances of the fetch algorithm").

**What Happened**: Lane nav4 let fetch() survive navigate step 24.3 because "Chrome and Safari cancel only at the
commit" - read from the first 200 KB of WebKit's FrameLoader.cpp, which did not include
continueLoadAfterNavigationPolicy. Lane flaky3's native test (fl3_refresh_reload_aborts_fetch_test.zig) failed: it
cited exactly that function's stopAllLoaders(), which stops the CURRENT document's loader as soon as the policy check
passes. Separately, Crane rejected every document-aborted fetch with an "AbortError" DOMException (citing Blink's
Loader::Abort), and five Crane tests pinned it. The probe (tmp/nav4/fetch-abort-probe-results.jsonl; headless Chrome
157 and Firefox 159 with throwaway profiles, Safari 27.0 opened with `open -g -j`) showed:

- a navigation's start: Firefox and Safari cancel the fetch, Chrome does not;
- window.stop(), and location.href then document.open(): all three cancel it;
- every cancelled fetch rejects with a TypeError ("Failed to fetch", "NetworkError when attempting to fetch
  resource.", "Load failed") - never an AbortError;
- a body still arriving at window.stop(): Chrome and Safari error it, Firefox lets it finish.

**Fix**: fetch() is cancelled at the navigation's start again (the spec, Firefox, Safari), with a TypeError for
every live document abort; a fetch so cancelled does not make the page unsalvageable (Chrome, Safari keep the page);
the five Crane tests now expect a TypeError, with the probe cited.

**Takeaway**: **When an engine-source reading decides behaviour that script can observe, probe the three browsers
for it (a small local server, the cases side by side, one JSON result per browser) before building on the
reading - and cite the probe, not the function you happened to read.**
