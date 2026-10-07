# Testing: Newly reached leaks need a control without the new feature

**Date**: 2026-10-05

**Lesson**: A newly passing setup assertion can expose an older leak farther into a test; isolate the operation and run it without the new feature on both revisions.

**Why**: A zero leak count on the baseline does not prove it executed the allocating path. Failure messages and the control's reachability matter alongside the totals.

**What Happened**: Activating custom elements raised a 248-file targeted run's allocator reports from zero to two. Splitting its leaking shard, then running individual files, isolated custom-elements/reactions/Document.html. Its editable-selection/delete subtest had stopped at the constructor assertion before activation. The same focus, selection collapse and execCommand operations using a plain span leaked twice on both the frozen baseline and the tip. The allocator printed no allocation stack, so the exact allocation site remained unproven.

**Fix**: Keep the sweep's actual increase in the report. Pair the custom-element red with the plain control, identify the owning entry points, and route the repair to their owner if the files are outside the grant. Restore and rerun every subtest after isolation. Do not equate a correct new reaction path with a leak-free browser, or hide the newly exposed count.

**Takeaway**: **Separate a newly reached defect from a newly introduced one with a same-operation control, then report both reachability and measured impact.**
