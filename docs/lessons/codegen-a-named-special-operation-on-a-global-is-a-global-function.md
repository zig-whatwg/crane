# Codegen: A named special operation on a [Global] interface is a global function

**Date**: 2026-10-19
**Lesson**: An identifier on a WebIDL special operation also declares a regular operation of that name, and on a [Global] interface a regular operation is an own property of the global object - so Crane's supplementary `getter WindowProxy? item(unsigned long index)` on Window made `window.item` a function no browser has, and it shadows every element with id or name "item".

**Why**: WebIDL 2.5.6: "If [a special operation] has an identifier, then ... the operation is also a regular operation". For an interface declared [Global] (Window), each regular operation is a property of the single global object itself, so a bare `item` in script finds the function before the Window's named properties object (which is where `id="item"` lives) is consulted. The supplementary IDL (specs/supplementary/WindowIndexedGetter.idl) exists only so that Crane can answer WindowProxy's indexed access on Window; nothing in HTML names that getter.

**What Happened**: Lane style4 looked at html/dom/elements/the-innertext-and-outertext-properties/getter-first-letter-marker-multicol.html, which failed with "innerText expected PASS but got undefined". The inner_text collector was right (`document.getElementById("item").innerText` is "PASS" in Crane): the test reads `item.innerText`, and in Crane `typeof window.item` is "function" - an own data property `function item() { [native code] }` of the global, from the generated Window's `methods` table (`.{ "item", "call_item", 1 }`). Chrome, Firefox and Safari pass the file: `item` is the element there.

**Fix**: (not this lane's files - recorded for the binding/codegen owner) make the supplementary getter anonymous, `getter WindowProxy? (unsigned long index);`, so it is only a special operation; regenerate (the anonymous getters number by merge order: html.idl's named getter first, then this one); rename WindowImpl's delegate to the name the generated file then calls; pin with a Crane test that `"item" in window` is false and that an element with id "item" is `window.item`.

**Takeaway**: **A supplementary IDL member must not add a script-visible name the browsers lack - on a [Global] interface, a named special operation is a global function that shadows named access.**
