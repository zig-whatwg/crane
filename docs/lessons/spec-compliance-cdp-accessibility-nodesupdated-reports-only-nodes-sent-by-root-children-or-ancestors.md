# Spec Compliance: CDP's Accessibility.nodesUpdated reports only nodes sent by getRootAXNode, getChildAXNodes or getAXNodeAndAncestors

**Date**: 2026-11-24
**Lesson**: Chrome 157 sends Accessibility.nodesUpdated only for objects its agent has in nodes_requested_. getRootAXNode, getChildAXNodes and getAXNodeAndAncestors add to that set; getFullAXTree, getPartialAXTree and queryAXTree do not. A load's loadComplete resets the set to the new root. An object that is no longer in the tree is dropped silently: display:none removes its AXObject.

**Why**: InspectorAccessibilityAgent::MarkAXObjectDirty returns at once for an AXID outside nodes_requested_. The set is filled in GetRootAXNode, GetAXNodeAndAncestors and GetChildAXNodes, and reset in AXReadyCallback after kLoadComplete. ProcessPendingDirtyNodes skips detached objects (third_party/blink/renderer/modules/accessibility/inspector_accessibility_agent.cc, Chromium 157.0.8103.78).

**What Happened**: Lane a11y1's first event recording called getFullAXTree and then changed text, aria-label, children and style. Chrome for Testing 157 sent no nodesUpdated at all, so the steps tested nothing. With root, children and ancestors steps first, Chrome sent exactly the requested nodes whose serialization changed:
- the button for a text change;
- the region for an aria-label;
- the list for an append;
- the paragraph for a removal;
- the body, but not the now display:none paragraph, for a hide;
- the link for focus;
- the textbox for a value.
Separately, Chrome's backendNodeIds start again in a document a data: URL navigation makes: the new root was 2, an id the first document had used. So the comparison's id names must start again at a navigation step.

**Fix**: The agent keeps each requested node's last-sent serialization (ids and bytes, never nodes). A DOM probe, a focus change (dom.focused_area.set) or a control value change arms Chrome's 260 ms one-shot. When it fires, at most once per 250 ms, the agent:
- rebuilds those nodes;
- sends the ones whose bytes changed;
- drops the ones whose object is gone or no longer included in the tree.
loadComplete re-seeds the set with the root. The trace test's `events` step collects the events after a wait and compares them as one sorted set, because Blink iterates a hash set and batching is timing. Its `navigate` step restarts the id names (src/devtools/domains/accessibility.zig, tests/devtools/a11y1_chrome_trace_test.zig).

**Takeaway**: **To test CDP events, first find what makes an object eligible for them in Chrome's agent (here nodes_requested_, filled only by three of the six tree commands), then drive exactly those commands. A recording with no events is a test of nothing.**
