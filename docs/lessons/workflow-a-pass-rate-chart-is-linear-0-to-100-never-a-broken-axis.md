# Workflow: A pass-rate chart is linear from 0% to 100% - never a zoomed or broken axis

**Date**: 2026-11-14
**Lesson**: On Crane's report pages a pass rate is drawn on one linear 0-100% scale, whatever the rates are; never zoom the axis, break it, or add an inset or second scale to separate close values.

**Why**: The user, 8:15 PM ET, about the published /frameworks/ chart: "Do not compress the 99th percentile. The horizontal is 0% - 100% linear." Rates of 99.4% and 99.7% are meant to sit almost on top of each other: the reader sees at once that both are nearly everything, and the exact numbers stand beside the bars. A zoomed or broken axis makes a 0.3-point gap look like a chasm and asks the reader to decode two scales.

**What Happened**: Batch 8 built mockup A's dumbbell chart with an axis zoomed to where the rates clustered (66-69% | 99-100%), broken between the two, with a note explaining the zoom. The user rejected it on sight; batch 9 replaced it with the progress page's meters (green passed, red failed) on one 0-100% scale, ticks at 0, 25, 50, 75 and 100%, and `report.zig` pins it with a test (a meter's green width is the rate, no break, no zoom, no axis note).

**Fix**: Draw rates with `xOf(rate) = rate / 100` only; put the exact rate and counts beside each bar instead of stretching the scale. Close values that look equal are the honest picture.

**Takeaway**: **A pass rate's chart is 0% to 100%, linear, every time. Close rates are shown by their numbers, never by zooming, breaking or doubling the axis.**
