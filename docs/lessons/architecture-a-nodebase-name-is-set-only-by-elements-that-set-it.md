# Architecture: A NodeBase's node_name is set only by the elements that set it

**Date**: 2026-09-29
**Lesson**: DOM mutation callbacks (insertion steps, post-connection steps, children changed steps) get a `*NodeBase`. For most elements `node.node_name` is the empty string, so a callback that filters on it never matches them.

**Why**: `Element.setLocalName` is what createElement, the tree builder's DOM adapter and the fragment parser call. It stores the element's local name in Element's own state and never touches the NodeBase. Only `Node.setLocalName` writes `node_base.node_name` (uppercased), and only some elements' own init paths call it. An iframe's and a script's NodeBase have names. A meta element's, a div's and a head's do not.

**What Happened**: `<meta http-equiv=refresh>` was implemented as HTMLMetaElement insertion steps, modelled on HTMLScriptElement's: `if (!std.ascii.eqlIgnoreCase(node.node_name, "meta")) return;`. No meta refresh ever ran. The Crane test, dynamic-append.html and navigate-meta-refresh.html all timed out. A `std.log.err` placed right after the name check printed nothing, even with piped output. A `std.debug.print` before the check showed the callback running for every inserted node: 20 elements with `name=` empty, 3 `SCRIPT`, 2 `IFRAME`.

**Fix** (ca64b1124): brand-check the instance, not the name. `instance_bridge.getInstance(node)` is a field read. `instance.stateAs(HTMLMetaElement.State)` walks the vtable's ancestry and returns null for anything that is not a meta element.

**Takeaway**: **In a mutation callback, identify the element by its instance's state (`stateAs`), never by `node.node_name`.** The name is filled in only where some init happened to set it, and a check that never matches fails silently.
