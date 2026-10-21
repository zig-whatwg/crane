# Debugging: Missing event handlers can start with the element factory

**Date**: 2026-10-21
**Lesson**: When a group of inherited properties is missing, verify the receiver's interface before changing the shared getter.

**Why**: A property read that returns `undefined` may never reach the getter. Giving an object a namespace and local name does not give it the corresponding interface or prototype chain.

**What Happened**: Row 108's `html/webappapis/scripting/events/event-handler-all-global-events.html` had 75 default-value failures. Each expected null but saw undefined on an `Element` instance. The fixture creates both an HTML span and an SVG g. `src/html/custom_elements/creation.zig` specializes SVG script and a, then constructs other SVG names through `interfaces.Element.init`; the parser's `createForeignElement` has the same gap. The generated SVG handler accessors and `src/dom/event_handlers.zig` therefore never run for that g. Changing the handler map or adding accessors to `Element.prototype` would repair the symptom in the wrong layer and violate the test's separate placement checks.

**Fix**: Isolate interface identity and an inherited accessor in separate assertions (`crane/wa1-svg-handler-interface.html`). Route the missing SVG construction map to its owner, together with parser parity, construction/destruction validation and the existing full WPT file. First inspect the target interface: SVGGElement and SVGGraphicsElement still have stub init functions that allocate directly, so replacing Element.init with SVGGElement.init alone would skip the parent initialization chain. Leave shared handler behavior alone when its input is the wrong object type. This batch records the gap; it does not implement the factory repair.

**Takeaway**: **Check the receiver's interface before debugging a getter that may never have been called.**
