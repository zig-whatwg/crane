# Spec Compliance: A handler form scope requires a form-associated element

**Date**: 2026-10-17
**Lesson**: Validate the HTML form-associated category before asking for the form owner used by an inline handler.

**Why**: HTML's "get the current value of the event handler" algorithm takes the element's form owner in step 3.5 and inserts its object environment between the document and element in step 3.9.4. An arbitrary element inside a form has no form owner.

**What Happened**: `Element.compileEventHandlerAttribute` supplied null for every form owner even though `engine.compileEventHandler` already supported that scope. Simply calling `html.form_associated.formOwner` for every element would introduce the opposite bug: its existing ancestor walk assumes its caller has validated the category and can return a form for a `div`, `meter`, or `progress`.

**Fix**: Supply the existing lookup only for listed elements or `HTMLImageElement`, and only for an element's own handler. HTML 4.10.2 defines the form-associated category as exactly listed elements plus `img`; `isListed` includes form-associated custom elements. Keep Window-reflecting handlers outside those object scopes. Check explicit form association, negative categories, scope precedence, and a captured form surviving GC. Blink's `JSEventHandlerForContentAttribute::GetCompiledHandler` uses the same document/form/element scope order.

This does not fix compilation timing. Crane's parser currently sets content attributes before form association, and active-document handlers compile eagerly. Parsed handlers need the separate lazy-compilation work; a green test that sets an attribute after association does not prove that upstream parser cases pass.

**Takeaway**: **Form ancestry alone does not establish a form owner, and supplying the right scope does not establish the right compilation time.**
