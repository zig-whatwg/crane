# Testing: A node dropped in the frame that named it is not dropped

**Date**: 2026-11-16
**Lesson**: A lifetime test that removes a node, "drops every reference" and collects in ONE JavaScript function has not dropped it: the temporary that named the node stays in a register of that function's frame, and a collection under the frame keeps it. Drop the node in a function of its own, and check the test against a control that takes the protection out.

**Why**: V8's interpreter keeps each function's temporaries in the frame's register file and does not clear a register when its value is dead. `document.getElementById('host').remove()` leaves the host's wrapper in the register that held the call's receiver; the collector scans the whole frame, so `collect()` on the next line finds the wrapper alive. An async function's frame lives across its awaits, with its registers.

**What Happened**: Lane ev2's red test for "the event path counts a TouchEvent's touch targets" had the target's listener remove the shadow host, collect, make 500 new nodes and collect again, then read the touch's target in later listeners. Under lane lk1's mutation (the teardown queue runs at every binding exit) it was expected to read the freed host on main. It passed, on server1 and on chat2.local: the listener's own frame kept the host. A second cause hid behind the first: once the event's own touch target list was counted, that list named the same host as the path's lists, so the path's references were never the only ones. The test proved nothing about the code it was written for until both were fixed.

**Fix**:
1. Do the drop in a function of its own (`dropInner()`), and build the tree in a function that has returned before the dispatch: no live frame's register names the node, its shadow root or its host.
2. Make the scenario one where ONLY the protection under test names the node. Here: nested shadow trees and a capturing listener at the window, which runs while the event's own list names the outer host and only the path's first run names the inner one.
3. Run the control before trusting the test: the protection taken out (in a pool mirror only) with the other protection's mutation on. The test must fail there - this one then read `target:NEWCOMER:false` - and pass with the protection back.
4. Say in the test's header what the control showed, on which host, and why the drop is in its own function.

**Takeaway**: **"Script dropped it" is true only once the frame that named it has returned: drop in a function of its own, and trust a lifetime test only after its control - the protection removed - has failed.**
