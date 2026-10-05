# Spec Compliance: Media source exhaustion is not a media error

**Date**: 2026-10-05
**Lesson**: Resource selection through `src` and through child `source` elements has different failure targets and termination rules.

**Why**: A single generic media-failure path would reject play promises and fire `video.error` for an exhausted child list, although HTML says to wait for another candidate.

**What Happened**: Reading the complete cached HTML 4.8.11.5 algorithm for the media-loading batch exposed two traps in a fetch-plus-error implementation. A present but empty `src` selects attribute mode even when source children exist. Child mode instead raises `error` on the failed source, resumes at stable state, and can wait indefinitely at its live child-list pointer. A parsed MIME type known to be unsupported also rejects a child candidate before fetching; forcing a request merely to satisfy a CSP test would violate that ordering.

**Fix**: Keep the selected mode in the load state. Use dedicated media source failure steps only for attribute/object selection. For children, queue the source event and preserve the live pointer while waiting for insertion. Change `currentSrc` only when the algorithm selects a valid URL or enters object mode. Add tests for empty attribute precedence, source filtering, exhaustion and later insertion.

The pure-model tests and Crane source-failure regression were written before implementation. On 2026-10-05, the exact test-only commit failed because html_core.media was absent; the restored implementation passed all 11 load-state and 2 registry tests on chat.local. The script-visible regression is not yet measured. This lesson records the specification distinction and the model checks, not a WPT conformance gain.

**Takeaway**: **A candidate failure is not necessarily a media-element failure. Preserve the algorithm's selected mode, target and continuation.**

Reference: [HTML resource selection algorithm](https://html.spec.whatwg.org/multipage/media.html#concept-media-load-algorithm), step 14 (attribute/object failure versus children steps 10–26), cached in `specs/whatwg/html.md` on 2026-10-02.
