# Testing: Compare an accessibility tree with Chrome after setting its user-agent shadow nodes apart

**Date**: 2026-11-23
**Lesson**: Chrome's CDP accessibility tree contains objects for its form controls' user-agent shadow trees (a text field's inner editor and its text, a date input's fields, a meter's bars, details' slots, a select's pop-up), each with a real backendDOMNodeId; a Chrome-trace comparison must record which ids those are and set them apart, or every node after the first control is misnamed.

**Why**: The comparison renames ids by first appearance (Chrome's DOMNodeIds are not Crane's). Crane has no user-agent shadow DOM, so any extra Chrome node shifts every later name, and one difference becomes hundreds.

**What Happened**: Lane a11y1's first Chrome 157 trace of nine pages showed 680 differing lines; nearly all came from a `<input value=value>`'s generic inner editor and StaticText 'value', the date input's spinbuttons ('Month Month'), and the select's `MenuListPopup` - none of which a page's DOM has. Blink's AXID is the node's DOMNodeId (AXObjectCacheImpl::CreateAndInit), so these look like ordinary DOM-backed objects in the answer.

**Fix**: At record time, after each page's commands, call `DOM.getDocument {depth: -1, pierce: true}` and write the backendNodeIds found under `shadowRootType: "user-agent"` roots as a `ua` line (tests/devtools/a11y1_chrome_trace_test.zig `userAgentIds`). At compare time (`userAgentNodes`), drop those nodes from Chrome's answers, give their page-DOM descendants (options, slotted content) to the nearest kept ancestor, drop their nodeless descendants, and keep only the select's pop-up, made nodeless - which is how Crane answers it. Keep a page-level map: a partial answer names a pop-up parent only by id. Also record a `dom` line (each backendNodeId's tag, id and class) so a recording can be read.

**Takeaway**: **Before comparing any CDP tree with Chrome, find out which of Chrome's nodes come from DOM the engine under test does not have, and record that set beside the trace - never guess it from roles or shapes.**
