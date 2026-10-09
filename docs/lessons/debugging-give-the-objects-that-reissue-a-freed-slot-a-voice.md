# Debugging: Give the objects that reissue a freed slot a voice

**Date**: 2026-10-09
**Lesson**: A use-after-free test is strongest when the objects it makes to take the freed slot are observable - a listener that logs "wrong", a distinct expando or text - so a dangling read shows up as a wrong answer naming the impostor, not as silence or a flaky crash.

**Why**: A freed slab slot is reissued to the next object of a similar size. A holder that kept only the address then acts on the newcomer: wraps it, reads it, fires an event at it. If the newcomer is inert, the read returns something plausible or nothing at all, and the defect hides until a sweep crashes somewhere else.

**What Happened**: Lane edges' crane/ed-svg-script-removed-gc.html runs a script-inserted external SVG script that removes its own element, lets every reference go and collects, then makes 2,000 SVG script elements each with a load listener that logs "wrong". The queued task held only the element's address and generation, checked before the script ran; on the base runner the log read `["ran", "wrong"]` - the load event meant for the collected element was dispatched to one of the newcomers. The same pattern made the static NodeList and StaticRange reds unambiguous: `list[0].id` read "" (a churned span), `range.startContainer.data` read "churn".

**Fix**: In each lifetime test: make the held object distinctive (an expando, unique text), drop every reference inside a function frame, collect (TestUtils.gc()), then churn objects of the same type that are visibly different (or log when touched), and only then read the holder.

**Takeaway**: **Make the impostor talk: churn objects that announce themselves, so a reissued slot fails the assertion with its name instead of passing or crashing elsewhere.**
