# Workflow: A recently fetched spec cache can hold old text

**Date**: 2026-10-05
**Lesson**: When a cached algorithm conflicts with both WPT and an engine, compare that algorithm with the upstream Editor's Draft even if the cache was fetched recently.

**Why**: A fetch date says when bytes arrived, not which revision those bytes describe. A recently written cache can still contain an older published algorithm.

**What Happened**: The Mixed Content cache fetched on October 2 excluded CORS media from upgrades and did not exclude IP-address hosts. Both Blink and WPT did the opposite. The initial integrator ruling followed the cache. A worklist image test exposed the disagreement again; comparing the upstream Editor's Draft revealed that the cache held older text. The current 4.1 upgrades CORS media and excludes IP-address hosts. Section 3.1 still contains old CORS prose, so reading only that paragraph would also mislead.

**Fix**: Fetch the complete spec with `specs/get https://w3c.github.io/webappsec-mixed-content/ specs/w3c`, check the upstream date line (Editor's Draft, 23 February 2023), and commit the cache alone. The cleanup strips that date line, so record it with the source URL in the commit or report. Pin the corrected algorithm decisions in tests, observe them failing against the old implementation, then update the implementation with current step numbers. Correct the report and handoff so an obsolete ruling does not become the next batch's premise.

**Takeaway**: **A cache fresh by date can hold an old TR text: specs/get the Editor's Draft URL and check its date line.**
