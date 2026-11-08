# Workflow: A crashed Safari tab stalls every later probe case

**Date**: 2026-11-08
**Lesson**: In a three-browser probe whose cases can crash the content process, Safari (background tab, `open -g -j`) stops making progress after its first crash and every later case reads as a hang; run the cases Safari must answer in one synchronous page per launch, the crashing ones last or not at all.

**Why**: After a web content process crash Safari reloads the tab, and a probe that resumes with a setTimeout chain from a background, hidden tab barely runs (timers in hidden tabs are throttled); closing and reopening tabs by AppleScript did not recover it. Chrome and Firefox headless, relaunched per stall, recovered fine.

**What Happened**: Lane crash1's depth probe (148 cases, report-home server, tmp/crash1/probe/) got Safari's first 20 cases, then one NOEND per case at the 90 s stall timeout from case 21 on, though case 21 (75 nested :nth-child(of)) is instant in every browser. A second page (probe2.html?only=...) that ran the needed cases synchronously in one task, with a sync XHR report before and after each, answered all 17 in under a second.

**Fix**: Give the probe an `only=` list and run it synchronously; send Safari the cases you need it for, after the ones that crash elsewhere are known; keep the stall-and-relaunch driver for Chrome and Firefox.

**Takeaway**: **A probe case that crashes a browser poisons the rest of that browser's run: isolate the crashing cases, and give Safari a synchronous page of only the cases it must answer.**
