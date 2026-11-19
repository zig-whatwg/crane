# Spec Compliance: The editing data mixes spec rows and browser rows - diff every editing subtest, and probe Chrome headless

**Date**: 2026-11-19
**Lesson**: The WPT editing data (tests/wpt/editing/data/*.js) holds rows written for the 2011 spec next to rows later updated to what the browsers do. A change that follows the browsers fixes the second kind and breaks the first, so measure every change over the whole editing/ directory subtest by subtest before calling it done.

**Why**: The editing spec is unmaintained. Browser engineers update data rows when they fix their own engine, and leave the others alone. Rows that use one mechanism can disagree with each other. `<s>foo[bar]baz</s>` + strikethrough in CSS mode expects the `<s>` copied (all three browsers pass). `<u>foo[bar]baz</u>` + underline in CSS mode expects the spec's spans, which no browser makes (FFF), and Crane passed it.

**What Happened**: Lane edit2 took the editing/run/ subtests that at least two browsers pass (625 of 2,153). Each cause was first fixed the way the browsers do it. The first targeted run of group 1 gave +111 / -62. Every loss was a row the data keeps at the spec's result and Firefox (or nobody) passes: push-down splitting for bold and background colors, copying b/i/u/strike in CSS mode, a block ancestor split. Narrowing each change to the rows where all three browsers agree gave +463 / -6, and the remaining 6 were two more row families of the same kind. Some causes could not be decided from wpt.fyi at all, because each browser's VALUE follows from its own DOM. For formatBlock's value after the command, Chrome makes one `<div>foo<br>bar</div>` where Crane (and the data) make two divs. A headless Chrome probe showed the exact DOM and selection in seconds:
`"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new --disable-gpu --no-first-run --user-data-dir=<scratch>/profile --allow-file-access-from-files --dump-dom file://<scratch>/probe.html`
The probe page runs the cases with the WPT setup (the [ ] { } markers and data-start/data-end) and writes innerHTML, the selection and queryCommand* into a <pre>. It steals no focus and needs no window.

**Fix**:
1. Per subtest, list the failing rows with Chrome/Firefox/Safari status from the aligned wpt.fyi runs (tmp/scratch/edit2/cmp.py), and group them by cause.
2. Before a change, list the rows the same mechanism decides, and check whether any of them pass in Crane while the browsers fail (FFF/FPF with Crane PASS). Those are the rows the change would trade.
3. After the change, run all editing/ worklist files on the lane runner and diff every subtest against the generation (tmp/scratch/edit2/subdiff.py). Narrow the change until every loss is explained: keep the browsers' mechanism only where the data and all three browsers agree. A remaining trade goes to the integrator as a ruling.
4. When a browser's value depends on its own DOM, probe Chrome headless before designing. Do not reason from the engine's source alone.

**Takeaway**: **In editing, "follow the browsers" is decided row family by row family: a mechanism the browsers share can still be a net loss against the data's spec rows. Diff every editing subtest after each change, and probe Chrome headless for the DOM and selection a value comes from.**
