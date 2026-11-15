# Testing: A file that asserts nothing happens passes without the feature - run a new worklist file red and green before you count it

**Date**: 2026-11-14
**Lesson**: A test whose assertion is "no transition started" (or "no event", "nothing changed") passes on an engine that does not implement the feature at all, so adding it to the worklist with the feature can turn a pass into a loss.

**Why**: css/css-transitions/starting-style-adjustment.html asserts `document.getAnimations().length == 0`: a legend's @starting-style `display: inline` must blockify, so the starting style equals the after-change style and no display transition starts. An engine with no @starting-style starts no transition either, and passes. The file measures the feature's interaction with another rule (the legend's computed display), not the feature's presence.

**What Happened**: Lane sel1 batch 1 added ten CSS Transitions 2 @starting-style files to the worklist with the feature. On generation 224's runner (no @starting-style) starting-style-adjustment.html was 1/1; on the tip with @starting-style it was 0/1, because Crane followed HTML 15.3.13 and kept a legend's computed display inline. The red run before the gate showed it; the A/B would have shown it as a newly run file at 0/1 with nothing to compare against. A second added file, css/css-cascade/scope-starting-style.html, blocked for a different missing feature (@scope bodies are skipped by the cascade).

**Fix**: Run every file a batch adds to the worklist on the generation's frozen runner (red) and on the tip (green) before the gate, and read both results per file: a file that passes red and fails green is a loss the feature caused; a file that fails green for another feature's gap is a newly blocking file to report. Here the legend's computed display followed Chrome and Safari (golden rule 2), and the @scope file stayed in as an honest blocker with a queue line.

**Takeaway**: **"Nothing happens" passes without the feature: a new worklist file needs a red run and a green run, and a file that passes red is a loss risk, not a free gain.**
