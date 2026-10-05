# Debugging: A value that reads back only on the object it was set on is an expando

**Date**: 2026-10-05
**Lesson**: sessionStorage looked as if each document had its own, but the store was fine: `sessionStorage.x = v` never reached it, because the binding made a plain JS property on the Storage wrapper instead of calling the named property setter.

**Why**: Storage and DOMStringMap have named property setters (WebIDL "legacy platform object [[Set]]"). When the binding does not intercept the assignment, V8 stores an own data property on the wrapper. Reading the value back through the same wrapper finds that property, so a test that writes and then reads in one document passes. Anything that reads from a different object fails: a new document's Storage, `getItem`, or the attribute behind `dataset`.

**What Happened**: resource-timing/nested-context-navigations-iframe.html timed out. Its popup sets `sessionStorage.navigated = true`, navigates away and back, and checks the flag. A replica in a Crane debug page looped about 60 times in 3 s: every restored page read `navigated` as undefined and navigated again.
- A debug print showed the same session storage key (top-level browsing context id plus origin) before and after the navigation, so the store was not to blame.
- `setItem`/`getItem` survived the navigation; `.named = v` came back null from `getItem("named")`.
- The same failure explained trusted-types/inheriting-csp-for-local-schemes.html: `iframe.dataset.inherits = true` never set data-inherits, and reading it back gave the boolean, not "true".

**Fix**: None in the navigation lane. It belongs to the V8 adapter's named-property interceptors (reported to the integrator). The files record it as their cause.

**Takeaway**: **When state set through a property "disappears" across objects, write it with the method form (`setItem`, `setAttribute`) before suspecting the store: if the method survives and the property does not, the binding never called the setter.**
