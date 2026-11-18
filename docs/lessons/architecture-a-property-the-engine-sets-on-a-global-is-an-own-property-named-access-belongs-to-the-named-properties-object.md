# Architecture: A property the engine sets on a global is an own property - named access belongs to the named properties object

**Date**: 2026-11-18
**Lesson**: Never answer a Window's named access by setting `window[name]` on the global: the result is an own data property no browser has, and it outlives the thing it named.

**Why**: WebIDL 3.7.4 puts a [Global] interface's named properties on its named properties object (WindowProperties), on the prototype chain, answered on every lookup from the live state (the document-tree child navigables, the named elements). An ordinary `[[Set]]` on the global instead makes an own, writable, enumerable, configurable data property: `Object.getOwnPropertyDescriptor(window, name)` returns it, `Object.keys(window)` lists it, a later name change never reaches it, and removing the frame leaves the old WindowProxy behind it.

**What Happened**: `dom.navigables.registerNamedProperty` (lane blk3 found it, 2026-11-18) ran `engine.setProperty(parent_window, name, child_window)` whenever an iframe, frame, object or embed with a name made its navigable, because its comment believed V8's named interceptors "do not survive snapshot restore". WindowProperties is made at realm creation, after the restore, and already answered `window.<iframe name>`. html/browsers/the-window-object/length-attribute.window.js failed in Crane alone (Chrome, Firefox and Safari pass): after `frame.remove()` the removed frame's Window still answered `frameW.x`, an own property pointing at the grandchild's old WindowProxy. A probe printing `Object.getOwnPropertyDescriptor(frameW, "x")` before any access showed the own property; a read-only search for property writes on globals found the setter.

**Fix**: Delete `registerNamedProperty` and its three callers; keep `integration.setName` (the navigable's target name). Window's named getter answers child navigable names through WindowProperties alone.

**Takeaway**: **A named property of a [Global] interface is answered by its named properties object on every lookup; a probe of `Object.getOwnPropertyDescriptor(window, name)` that returns a descriptor is the sign that something set it on the global instead - an invented path to delete, not to keep in sync.**
