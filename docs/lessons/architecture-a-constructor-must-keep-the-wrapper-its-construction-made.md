# Architecture: A constructor must keep the wrapper its construction made, and own what it owns natively

**Date**: 2026-10-08
**Lesson**: A constructor that binds its instance to the object V8 made for NewTarget must first ask whether the instance already has a wrapper: replacing it drops every edge drawn on it. And a child whose only owner is a native pointer must be owned natively, not through an edge between two wrappers that either side's collection or replacement breaks.

**Why**: Traced edges (`engine.traceChild`) are private properties on the owner's WRAPPER. Three things broke the template's content edge:
- `DocumentFragment.setTemplateHost` traced from the content to the template, and `traceChild` makes the CHILD's wrapper: a brand-new template script had never seen got a wrapper, and from then on the collector could free it.
- `class X extends HTMLTemplateElement` + `new X()`: the binding's `.created` path bound the template to V8's receiver with `WrapperCache.set`, which REPLACED the wrapper establish had made - and disposed it with its template->content edge (and the element's `customElementRegistry` edge). The content's wrapper was then reachable from nothing; its finalizer freed the parentless fragment while `internal.content` still pointed at it.
- Separately, no constructor path ever set a constructed node's alias (`NodeBase.bound_v8_wrapper`). Node tracing finds a node's wrapper by that alias, so `f.appendChild(new Text())` drew no tree edges, and after a collection `parent.firstChild` of a `new XFoo()` was a plain HTMLElement with its expandos gone.

**What Happened**: The review of row 10 (tmp/analysis/review-parser.md, PR-M1) found the template case by reading; lane lifefix1 wrote the red tests first: tests/html/template_content_lifetime_test.zig (customized built-in `new X()`, a native createElement and a native cloneNode of nested templates - all three freed their content or template under a collection, generation checks red) and tests/v8/constructed_wrapper_test.zig (a constructed Text appended to a constructed fragment lost its expando; a pre-wrapped `.created` element's traced child was freed; `WrapperCache.set` replaced a live wrapper).

**Fix**:
1. The template owns its content natively: `wrapper_cache.engineOwns` also asks `templateOwns` (`dom.template_contents.ownedByLiveTemplate`, default false, pinned by tests/v8/template_owns_predicate_test.zig), so the content's wrapper may die but the fragment stays while the template lives. `HTMLTemplateElement.deinit` frees an unwrapped content, or clears its host (`releaseHost`) and leaves a wrapped one to its wrapper - script may hold `t.content` without `t`. `get_content` checks `content_generation`. No edge from content to template any more (WebKit and Blink: native-to-native).
2. `WrapperCache.set` refuses (`error.AlreadyWrapped`) to replace a live wrapper of the same instance (a realm's Window excepted: its edges hang on its global object). The generic constructor path and `[HTMLConstructor]`'s `.created`/`.upgrading` answers adopt the existing wrapper (`adoptExistingWrapper`: the receiver's prototype goes onto it, and it is the return value - V8 takes an API constructor's object return over its receiver).
3. `WrapperCache.set` sets a node's alias for every wrapper it takes.

**Takeaway**: **An edge between wrappers is only as durable as both wrappers: never let one replace another, never make a wrapper for an object only native code holds, and own natively what the host owns natively.**
