## 1. Introduction

*This section is non-normative.*

This specification introduces a DOM API and associated CSS features that
allow developers to create animated visual transitions, called [view
transitions] between different states of a
[document](https://dom.spec.whatwg.org/#concept-document) or an
[element](https://drafts.csswg.org/css2/#element), or between distinct same-origin documents.

### 1.1. Level 2 Updates

Level 2 defines the following, extending the model in
[\[CSS-VIEW-TRANSITIONS-1\]](#biblio-css-view-transitions-1 "CSS View Transitions Module Level 1"):

- [Cross-document view transitions](#cross-document-view-transitions),
 including the
 [\@view-transition](#at-view-transition-rule) rule and the algorithms that enable the
 cross-document view transition lifecycle.

- [Selective view transitions](#selective-vt), a way to match styles
 based on the existence of an [active view
 transition](#element-active-view-transition), and more specifically based on the active view
 transition being of a certain type.

- [Sharing styles between view transition
 pseudo-elements](#shared-style-with-vt-classes), a way to declare a
 style once, and use it for multiple view transition pseudo-elements.
 This includes the
 [view-transition-class](#propdef-view-transition-class) property, and [additions to named
 pseudo-elements](#pseudo-element-class-additions)

- [Nested view transition groups](#view-transition-group-prop), a way to
 construct deeper hierarchies of view transition pseudo-elements, which
 in turn allows relative transforms and clipping of participating
 elements.

- [Scoped view transitions](#scoped-vt), a way to perform view
 transitions within the scope of a DOM subtree.

### 1.2. Separating Visual Transitions from DOM Updates

Traditionally, creating a visual transition between two document states
required a period where both states were present in the DOM at the same
time. In fact, it usually involved creating a specific DOM structure
that could represent both states. For example, if one element was
"moving" between containers, that element often needed to exist outside
of either container for the period of the transition, to avoid clipping
from either container or their ancestor elements.

This extra in-between state often resulted in UX and accessibility
issues, as the structure of the DOM was compromised for a purely-visual
effect.

[View Transitions](#view-transitions) avoid this troublesome in-between state by allowing the
DOM to switch between states instantaneously, then performing a
customizable visual transition between the two states in another layer,
using a static visual capture of the old state, and a live capture of
the new state. These captures are represented as a tree of
[pseudo-elements](https://drafts.csswg.org/selectors-4/#pseudo-element) (detailed in [§ 5.2 View Transition
Pseudo-elements](#view-transition-pseudos)), where the old visual state
co-exists with the new state, allowing effects such as cross-fading
while animating from the old to new size and position.

### 1.3. View Transition Customization

By default,
`element.`[`startViewTransition()`](#dom-element-startviewtransition) and
`document.`[`startViewTransition()`](#dom-document-startviewtransition) create a [view
transition](#view-transitions) consisting of a cross-fade of the entire [root
element](#viewtransition-root-element) between the two DOM states.

Developers can instead choose which descendant elements are captured
independently using the
[view-transition-name](#propdef-view-transition-name) CSS property, allowing these to be
animated independently of the rest of the page. Since the transitional
state (where both old and new visual captures exist) is represented as
pseudo-elements, developers can customize each transition using familiar
features such as [CSS Animations](https://www.w3.org/TR/css-animations/)
and [Web Animations](https://www.w3.org/TR/web-animations/).

### 1.4. View Transition Lifecycle

A successful [view
transition](#view-transitions) goes through the following phases:

1. Developer calls
 `document.`[`startViewTransition`](#dom-document-startviewtransition)`(`[`updateCallback`](#callbackdef-viewtransitionupdatecallback)`)` or
 `element.`[`startViewTransition`](#dom-element-startviewtransition)`(`[`updateCallback`](#callbackdef-viewtransitionupdatecallback)`)`, which returns a
 [`ViewTransition`](#viewtransition), `viewTransition`.

2. Current state is captured as the "old" state.

3. Rendering is paused within the view transition [root
 element](#viewtransition-root-element).

4. Developer's
 [`updateCallback`](#callbackdef-viewtransitionupdatecallback) function, if provided, is called, which updates the
 document state.

5. `viewTransition``.`[`updateCallbackDone`](#dom-viewtransition-updatecallbackdone) fulfills.

6. Current state is captured as the "new" state.

7. Transition pseudo-elements are created. See [§ 5.2 View Transition
 Pseudo-elements](#view-transition-pseudos) for an overview of this
 structure.

8. Rendering is unpaused, revealing the transition pseudo-elements.

9. `viewTransition``.`[`ready`](#dom-viewtransition-ready) fulfills.

10. Pseudo-elements animate until finished.

11. Transition pseudo-elements removed.

12. `viewTransition``.`[`finished`](#dom-viewtransition-finished) fulfills.

The following set of diagrams demonstrate the transition phases that a
view transition goes through while performing the above steps:

Previous Next

### 1.5. Transitions as an enhancement

A key part of the View Transition API design is that an animated
transition is a visual *enhancement* to an underlying document state
change. That means a failure to create a visual transition, which can
happen due to misconfiguration or device constraints, will not prevent
the developer's
[`ViewTransitionUpdateCallback`](#callbackdef-viewtransitionupdatecallback) being called, even if it's known in advance that the
transition animations cannot happen.

For example, if the developer calls
[`skipTransition()`](#dom-viewtransition-skiptransition) at the start of the [view transition
lifecycle](#lifecycle), the steps relating to the animated transition,
such as creating the [view transition
tree](#view-transition-tree), will not happen. However, the
[`ViewTransitionUpdateCallback`](#callbackdef-viewtransitionupdatecallback) will still be called. It's only the visual transition
that's skipped, not the underlying state change.

 If the DOM change should also be skipped, then that
needs to be handled by another feature.
[`navigateEvent`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#navigateevent)`.`[`signal`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#dom-navigateevent-signal) is an example of a feature developers could use to
handle this.

Although the View Transition API allows DOM changes to be asynchronous
via the
[`ViewTransitionUpdateCallback`](#callbackdef-viewtransitionupdatecallback), the API is not responsible for queuing or otherwise
scheduling DOM changes beyond any scheduling needed for the transition
itself. Some asynchronous DOM changes can happen concurrently (e.g if
they're happening within independent components), whereas others need to
queue, or abort an earlier change. The callback execution order is only
specified for callbacks that result from view transitions on the same
root element, or on elements related by DOM ancestors. In general, the
scheduling order is best left to a feature or framework that has a more
holistic view of the application.

### 1.6. Rendering Model

View Transition works by replicating an element's rendered state using
UA generated pseudo-elements. Aspects of the element's rendering which
apply to the element itself or its descendants, for example visual
effects like
[filter](https://drafts.csswg.org/filter-effects-1/#propdef-filter) or
[opacity](https://drafts.csswg.org/css-color-4/#propdef-opacity) and clipping from
[overflow](https://drafts.csswg.org/css-overflow-3/#propdef-overflow) or
[clip-path](https://drafts.csswg.org/css-masking-1/#propdef-clip-path), are applied when generating its
image in [Capture the
image](#capture-the-image).

However, properties like
[mix-blend-mode](https://drafts.csswg.org/compositing-2/#propdef-mix-blend-mode) which define how the element draws
when it is embedded can't be applied to its image. Such properties are
applied to the element's corresponding
[::view-transition-group()](#selectordef-view-transition-group) pseudo-element, which is meant to generate a box
equivalent to the element.

If the
[::view-transition-group()](#selectordef-view-transition-group) has a corresponding element in the \"new\"
states, the browser keeps the properties copied over to the
[::view-transition-group()] in sync with the DOM element in the \"new\" state. If the
[::view-transition-group()] has corresponding elements both in the \"old\" and \"new\" state,
and the property being copied is interpolatable, the browser also sets
up a default animation to animate the property smoothly.

### 1.7. Examples

Taking a page that already updates its
content using a pattern like this:

```
function spaNavigate(data) {
 updateTheDOMSomehow(data);
}
```

A [view transition](#view-transitions) could be added like this:

```
function spaNavigate(data) {
 // Fallback for browsers that don't support this API:
 if (!document.startViewTransition) {
 updateTheDOMSomehow(data);
 return;
 }

 // With a transition:
 document.startViewTransition(() => updateTheDOMSomehow(data));
}
```

This results in the default transition of a quick cross-fade:

<figure>

</figure>

The cross-fade is achieved using CSS animations on a [tree of
pseudo-elements](#view-transition-pseudos), so customizations can be
made using CSS. For example:

```
::view-transition-old(root),
::view-transition-new(root) {
 animation-duration: 5s;
}
```

This results in a slower transition:

<figure>

</figure>

Building on the previous example,
motion can be added:

```
@keyframes fade-in {
 from { opacity: 0; }
}

@keyframes fade-out {
 to { opacity: 0; }
}

@keyframes slide-from-right {
 from { transform: translateX(30px); }
}

@keyframes slide-to-left {
 to { transform: translateX(-30px); }
}

::view-transition-old(root) {
 animation: 90ms cubic-bezier(0.4, 0, 1, 1) both fade-out,
 300ms cubic-bezier(0.4, 0, 0.2, 1) both slide-to-left;
}

::view-transition-new(root) {
 animation: 210ms cubic-bezier(0, 0, 0.2, 1) 90ms both fade-in,
 300ms cubic-bezier(0.4, 0, 0.2, 1) both slide-from-right;
}
```

Here's the result:

<figure>

</figure>

Building on the previous example, the
simple \"whole document\" transition displayed a visible judder in the
purple heading bar, and had the heading text always slide to the left
even when it was \"moving\" to the right in the 1-\>2 transition. To fix
these issues, the header and text within the header can be given their
own [view-transition-name] for the transition, which creates a
separate
[::view-transition-group()](#selectordef-view-transition-group):

```
.main-header {
 view-transition-name: main-header;
}

.main-header-text {
 view-transition-name: main-header-text;
 /* Give the element a consistent size, assuming identical text: */
 width: fit-content;
}
```

By default, these groups will transition size and position from their
"old" to "new" state, while their visual states cross-fade:

<figure>

</figure>

Building on the previous example,
let's say some pages have a sidebar:

<figure>

</figure>

In this case, things would look better if the sidebar was static if it
was in both the "old" and "new" states. Otherwise, it should animate in
or out.

The
[:only-child](https://drafts.csswg.org/selectors-4/#only-child-pseudo) pseudo-class can be used to create animations
specifically for these states:

```
.sidebar {
 view-transition-name: sidebar;
}

@keyframes slide-to-right {
 to { transform: translateX(30px); }
}

/* Entry transition */
::view-transition-new(sidebar):only-child {
 animation: 300ms cubic-bezier(0, 0, 0.2, 1) both fade-in,
 300ms cubic-bezier(0.4, 0, 0.2, 1) both slide-from-right;
}

/* Exit transition */
::view-transition-old(sidebar):only-child {
 animation: 150ms cubic-bezier(0.4, 0, 1, 1) both fade-out,
 300ms cubic-bezier(0.4, 0, 0.2, 1) both slide-to-right;
}
```

For cases where the sidebar has both an "old" and "new" state, the
default animation is correct.

<figure>

</figure>

Not building from previous examples
this time, let's say we wanted to create a circular reveal from the
user's cursor. This can't be done with CSS alone.

Firstly, in the CSS, allow the "old" and "new" states to layer on top of
one another without the default blending, and prevent the default
cross-fade animation:

```
::view-transition-image-pair(root) {
 isolation: auto;
}

::view-transition-old(root),
::view-transition-new(root) {
 animation: none;
 mix-blend-mode: normal;
}
```

Then, the JavaScript:

```
// Store the last click event
let lastClick;
addEventListener('click', event => (lastClick = event));

function spaNavigate(data) {
 // Fallback for browsers that don't support this API:
 if (!document.startViewTransition) {
 updateTheDOMSomehow(data);
 return;
 }

 // Get the click position, or fallback to the middle of the screen
 const x = lastClick?.clientX ?? innerWidth / 2;
 const y = lastClick?.clientY ?? innerHeight / 2;
 // Get the distance to the furthest corner
 const endRadius = Math.hypot(
 Math.max(x, innerWidth - x),
 Math.max(y, innerHeight - y)
 );

 // Create a transition:
 const transition = document.startViewTransition(() => {
 updateTheDOMSomehow(data);
 });

 // Wait for the pseudo-elements to be created:
 transition.ready.then(() => {
 // Animate the root's new view
 document.documentElement.animate(
 {
 clipPath: [
 \`circle(0 at ${x}px ${y}px)\`,
 \`circle(${endRadius}px at ${x}px ${y}px)\`,
 ],
 },
 {
 duration: 500,
 easing: 'ease-in',
 // Specify which pseudo-element to animate
 pseudoElement: '::view-transition-new(root)',
 }
 );
 });
}
```

And here's the result:

<figure>

</figure>

## 2. API

### [2.1. ][Additions to [`Document`](https://dom.spec.whatwg.org/#document)]
```
partial interface Document {
 ViewTransition startViewTransition(
 optional (ViewTransitionUpdateCallback or StartViewTransitionOptions) callbackOptions =
 );
 readonly attribute ViewTransition? activeViewTransition;
};

callback ViewTransitionUpdateCallback = Promise<any> ();

dictionary StartViewTransitionOptions {
 ViewTransitionUpdateCallback? update = null;
 sequence<DOMString>? types = null;
};
```

[`viewTransition`](#viewtransition)` = `[`document`](https://dom.spec.whatwg.org/#document)`.`[`startViewTransition`](#dom-document-startviewtransition)`(`[`updateCallback`](#callbackdef-viewtransitionupdatecallback)`)`

: Starts a new [view
 transition](#view-transitions) (canceling the
 [`document`](https://dom.spec.whatwg.org/#document)'s existing [active view
 transition](#document-active-view-transition), if any).

 [`updateCallback`](#callbackdef-viewtransitionupdatecallback), if provided, is called asynchronously, once the
 current state of the document is captured. Then, when the promise
 returned by
 [`updateCallback`](#callbackdef-viewtransitionupdatecallback) fulfills, the new state of the document is captured
 and the transition is initiated.

 Note that
 [`updateCallback`](#callbackdef-viewtransitionupdatecallback), if provided, is *always* called, even if the
 transition cannot happen. The transition is an enhancement around
 the state change, so a failure to create a transition never prevents
 the state change. See [§ 1.5 Transitions as an
 enhancement](#transitions-as-enhancements) for more details on this
 principle.

 If the promise returned by
 [`updateCallback`](#callbackdef-viewtransitionupdatecallback) rejects, the transition is skipped.

#### 2.1.1. [`startViewTransition()` Method Steps]
The [method
steps](https://webidl.spec.whatwg.org/#method-steps) for
[`startViewTransition(``callbackOptions``)`] are as
follows:

1. Perform the
 [`Element`](https://dom.spec.whatwg.org/#element)
 [`startViewTransition()`](#dom-element-startviewtransition) [method
 steps](https://webidl.spec.whatwg.org/#method-steps) given `callbackOptions`, but for the
 [document root
 element](https://drafts.csswg.org/css-display-4/#root-element), and return the result.

#### 2.1.2. [`activeViewTransition` Property]
In order to provide ergonomic behavior, the [active view
transition](#element-active-view-transition) is exposed to script via a document property.

[`activeViewTransition`], of type [ViewTransition](#viewtransition), readonly, nullable

: Returns the [active view
 transition](#document-active-view-transition) for the
 [document](https://dom.spec.whatwg.org/#concept-document), or null if there is no active view transition.

 An `element.startViewTransition()` call does not update
`document.activeViewTransition`, but will update
[`activeViewTransition`](#dom-element-activeviewtransition) on the `element`.

### [2.2. ][Additions to [`Element`](https://dom.spec.whatwg.org/#element)]
```
partial interface Element {
 ViewTransition startViewTransition(
 optional (ViewTransitionUpdateCallback or StartViewTransitionOptions) callbackOptions =
 );
 readonly attribute ViewTransition? activeViewTransition;
};
```

[`viewTransition`](#viewtransition)` = `[`el`](https://dom.spec.whatwg.org/#element)`.`[`startViewTransition`](#dom-element-startviewtransition)`(`[`updateCallback`](#callbackdef-viewtransitionupdatecallback)`)`

: Starts a new [view
 transition](#view-transitions) (potentially canceling a conflicting [view
 transition]).

 [`updateCallback`](#callbackdef-viewtransitionupdatecallback), if provided, is called asynchronously, once the
 current state of the element and its subtree is captured. Then, when
 the promise returned by
 [`updateCallback`](#callbackdef-viewtransitionupdatecallback) fulfills, the new state of the element and its
 subtree is captured and the transition is initiated.

 Note that
 [`updateCallback`](#callbackdef-viewtransitionupdatecallback), if provided, is *always* called, even if the
 transition cannot happen. The transition is an enhancement around
 the state change, so a failure to create a transition never prevents
 the state change. See [§ 1.5 Transitions as an
 enhancement](#transitions-as-enhancements) for more details on this
 principle.

 If the promise returned by
 [`updateCallback`](#callbackdef-viewtransitionupdatecallback) rejects, the transition is skipped.

#### 2.2.1. [`startViewTransition()` Method Steps]
The [method
steps](https://webidl.spec.whatwg.org/#method-steps) for
[`startViewTransition(``callbackOptions``)`] are as
follows:

1. Let `document` be
 [this's](https://webidl.spec.whatwg.org/#this) [relevant global
 object's](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global) [associated
 document](https://html.spec.whatwg.org/multipage/nav-history-apis.html#concept-document-window).

2. Let `viewTransition` be a new
 [`ViewTransition`](#viewtransition) object in `document`'s [relevant
 Realm](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-realm), with [root
 element](#viewtransition-root-element) set to
 [this](https://webidl.spec.whatwg.org/#this).

3. If `callbackOptions` is a
 [`ViewTransitionUpdateCallback`](#callbackdef-viewtransitionupdatecallback), set `viewTransition`'s [update
 callback](#viewtransition-update-callback) to `callbackOptions`.

 Otherwise, if `callbackOptions` is a
 [`StartViewTransitionOptions`](#dictdef-startviewtransitionoptions), then set `viewTransition`'s [update
 callback](#viewtransition-update-callback) to `callbackOptions`'s
 [`update`](#dom-startviewtransitionoptions-update).

4. If [this](https://webidl.spec.whatwg.org/#this)'s [principal
 box](https://drafts.csswg.org/css-display-4/#principal-box) is [not
 rendered](https://drafts.csswg.org/css-images-4/#element-not-rendered), or is an [internal table
 box](https://drafts.csswg.org/css-display-3/#internal-table-box) other than
 [table-cell](https://drafts.csswg.org/css-display-4/#valdef-display-table-cell), or is an [internal ruby
 box](https://drafts.csswg.org/css-display-3/#internal-ruby-box) or a
 [non-atomic](https://drafts.csswg.org/css-display-3/#atomic-inline)
 [inline-level](https://drafts.csswg.org/css-display-3/#inline-level) box, then
 [skip](#skip-the-view-transition) `viewTransition` with an
 \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException), and return `viewTransition`.

 This ensures that
 [this](https://webidl.spec.whatwg.org/#this) has a [principal
 box](https://drafts.csswg.org/css-display-4/#principal-box) and qualifies for [layout
 containment](https://drafts.csswg.org/css-contain-2/#layout-containment).

5. If [this](https://webidl.spec.whatwg.org/#this) is not the [document root
 element](https://drafts.csswg.org/css-display-4/#root-element), force [this] to have both [layout
 containment](https://drafts.csswg.org/css-contain-2/#layout-containment) and [view transition
 scoping](#view-transition-scope-view-transition-scoping) for the duration of the transition.

6. If `document`'s [active view
 transition](#element-active-view-transition) is not null and its [outbound post-capture
 steps](#viewtransition-outbound-post-capture-steps) is not null, then:

 1. [Skip](#skip-the-view-transition) `viewTransition` with an
 \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

 The `viewTransition`'s
 [`types`](#dom-viewtransition-types) are ignored here because the transition is
 never activated.

 2. Return `viewTransition`.

 This ensures that a same-document transition that
 started after firing
 [`pageswap`](https://html.spec.whatwg.org/multipage/indices.html#event-pageswap) is skipped.

7. If [this](https://webidl.spec.whatwg.org/#this)'s [active view
 transition](#element-active-view-transition) is not null, then [skip that view
 transition](#skip-the-view-transition) with an
 \"[`AbortError`](https://webidl.spec.whatwg.org/#aborterror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) in [this's] [relevant
 Realm](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-realm).

 This can result in two asynchronous [update
 callbacks](#viewtransition-update-callback) running concurrently (and therefore possibly out of
 sequence): one for the
 [this](https://webidl.spec.whatwg.org/#this)'s current [active view
 transition](#element-active-view-transition), and another for this `viewTransition`.
 As per the [design of this feature](#transitions-as-enhancements),
 it's assumed that the developer is using another feature or
 framework to correctly schedule these DOM changes.

8. Set [this](https://webidl.spec.whatwg.org/#this)'s [active view
 transition](#element-active-view-transition) to `viewTransition`.

9. If [this](https://webidl.spec.whatwg.org/#this) is the [document root
 element](https://drafts.csswg.org/css-display-4/#root-element), set `document`'s [active view
 transition](#document-active-view-transition) to `viewTransition`.

 The [view
 transition](#view-transitions) process continues in [setup view
 transition](#setup-view-transition), via [perform pending transition
 operations](#perform-pending-transition-operations).

10. If `callbackOptions` is a
 [`StartViewTransitionOptions`](#dictdef-startviewtransitionoptions), set `viewTransition`'s [active
 types](#viewtransition-active-types) to a
 [clone](https://infra.spec.whatwg.org/#list-clone) of
 [`types`](#dom-startviewtransitionoptions-types) as a
 [set](https://infra.spec.whatwg.org/#ordered-set).

11. Return `viewTransition`.

#### 2.2.2. [`activeViewTransition` Property]
Similar to [Document.activeViewTransition](#doc-activeviewtransition),
the active view transition of an element is exposed to script via a
property on the element.

[`activeViewTransition`], of type [ViewTransition](#viewtransition), readonly, nullable

: Returns the [active view
 transition](#element-active-view-transition) for the
 [element](https://drafts.csswg.org/css2/#element), or null if there is no active view transition.

### 2.3. The [`ViewTransition` interface]
```
[Exposed=Window]
interface ViewTransition {
 readonly attribute Promise<undefined> updateCallbackDone;
 readonly attribute Promise<undefined> ready;
 readonly attribute Promise<undefined> finished;
 undefined skipTransition();
 [SameObject] readonly attribute ViewTransitionTypeSet types;
 readonly attribute Element transitionRoot;
 undefined waitUntil(Promise<any> promise);
};
```

The [`ViewTransition`](#viewtransition) interface represents and controls a single
same-document [view
transition](#view-transitions), i.e. a transition where the starting and ending
document are the same, possibly with changes to the document's DOM
structure.

[`viewTransition`](#viewtransition)`.`[`updateCallbackDone`](#dom-viewtransition-updatecallbackdone)

: A promise that fulfills when the promise returned by
 [`updateCallback`](#callbackdef-viewtransitionupdatecallback) fulfills, or rejects when it rejects.

 The View Transition API wraps a DOM change and
 creates a visual transition. However, sometimes you don't care about
 the success/failure of the transition animation, you just want to
 know if and when the DOM change happens.
 [`updateCallbackDone`](#dom-viewtransition-updatecallbackdone) is for that use-case.)

[`viewTransition`](#viewtransition)`.`[`ready`](#dom-viewtransition-ready)

: A promise that fulfills once the pseudo-elements for the transition
 are created, and the animation is about to start.

 It rejects if the transition cannot begin. This can be due to
 misconfiguration, e.g. if
 [`updateCallbackDone`](#dom-viewtransition-updatecallbackdone) returns a rejected promise.

 The point that
 [`ready`](#dom-viewtransition-ready) fulfills is the ideal opportunity to animate the
 [view transition
 pseudo-elements](#view-transition-pseudo-elements) with the [Web Animation
 API](https://drafts.csswg.org/web-animations-1/#extensions-to-the-element-interface).

[`viewTransition`](#viewtransition)`.`[`finished`](#dom-viewtransition-finished)

: A promise that fulfills once the end state is fully visible and
 interactive to the user.

 It only rejects if
 [`updateCallback`](#callbackdef-viewtransitionupdatecallback) returns a rejected promise, as this indicates the
 end state wasn't created.

 Otherwise, if a transition fails to begin, or is skipped (by
 [`skipTransition()`](#dom-viewtransition-skiptransition)), the end state is still reached, so
 [`finished`](#dom-viewtransition-finished) fulfills.

[`viewTransition`](#viewtransition)`.`[`skipTransition`](#dom-viewtransition-skiptransition)`()`

: Immediately finish the transition, or prevent it starting.

 This never prevents
 [`updateCallback`](#callbackdef-viewtransitionupdatecallback) being called, as the DOM change is independent of
 the transition. See [§ 1.5 Transitions as an
 enhancement](#transitions-as-enhancements) for more details on this
 principle.

 If this is called before
 [`ready`](#dom-viewtransition-ready) resolves,
 [`ready`](#dom-viewtransition-ready) will reject.

 If
 [`finished`](#dom-viewtransition-finished) hasn't resolved, it will fulfill or reject along
 with
 [`updateCallbackDone`](#dom-viewtransition-updatecallbackdone).

[`viewTransition`](#viewtransition)`.`[`transitionRoot`](#dom-viewtransition-transitionroot)

: The
 [`ViewTransition`](#viewtransition)'s [root
 element](#viewtransition-root-element).

 For [view transitions](#view-transitions) started on the
 [`Document`](https://dom.spec.whatwg.org/#document), this is the [document
 element](https://dom.spec.whatwg.org/#document-element).

[`viewTransition`](#viewtransition)`.`[`waitUntil`](#dom-viewtransition-waituntil)`()`

: Delays view transition finish until the given promise is settled.

A [`ViewTransition`](#viewtransition) has the following:

[named elements]

: a
 [map](https://infra.spec.whatwg.org/#ordered-map), whose keys are [view transition
 names](#view-transition-name) and whose values are [captured
 elements](#captured-element). Initially a new [map].
 Note: Since this is associated to the
 [`ViewTransition`](#viewtransition), it will be cleaned up when [Clear view
 transition](#clear-view-transition) is called.

[phase]

: One of the following ordered phases, initially
 \"`pending-capture`\":

 1. \"`pending-capture`\".

 2. \"`update-callback-called`\".

 3. \"`animating`\".

 4. \"`done`\".

 For the most part, a developer using this API does
 not need to worry about the different phases, since they progress
 automatically. It is, however, important to understand what steps
 happen in each of the phases: when the snapshots are captured, when
 pseudo-element DOM is created, etc. The description of the phases
 below tries to be as precise as possible, with an intent to provide
 an unambiguous set of steps for implementors to follow in order to
 produce a spec-compliant implementation.

[update callback]

: a
 [`ViewTransitionUpdateCallback`](#callbackdef-viewtransitionupdatecallback) or null. Initially null.

[ready promise]

: a
 [`Promise`](https://webidl.spec.whatwg.org/#idl-promise). Initially [a new
 promise](https://webidl.spec.whatwg.org/#a-new-promise) in
 [this's](https://webidl.spec.whatwg.org/#this) [relevant
 Realm](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-realm).

[update callback done promise]

: a
 [`Promise`](https://webidl.spec.whatwg.org/#idl-promise). Initially [a new
 promise](https://webidl.spec.whatwg.org/#a-new-promise) in
 [this's](https://webidl.spec.whatwg.org/#this) [relevant
 Realm](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-realm).

 The [ready
 promise](#viewtransition-ready-promise) and [update callback done
 promise](#viewtransition-update-callback-done-promise) are immediately created, so rejections will cause
 [`unhandledrejection`](https://html.spec.whatwg.org/multipage/indices.html#event-unhandledrejection)s unless they're
 [handled](https://webidl.spec.whatwg.org/#mark-a-promise-as-handled), even if the getters such as
 [`updateCallbackDone`](#dom-viewtransition-updatecallbackdone) are not accessed.

[finished promise]

: a
 [`Promise`](https://webidl.spec.whatwg.org/#idl-promise). Initially [a new
 promise](https://webidl.spec.whatwg.org/#a-new-promise) in
 [this's](https://webidl.spec.whatwg.org/#this) [relevant
 Realm](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-realm), [marked as
 handled](https://webidl.spec.whatwg.org/#mark-a-promise-as-handled).

 This is [marked as
 handled](https://webidl.spec.whatwg.org/#mark-a-promise-as-handled) to prevent duplicate
 [`unhandledrejection`](https://html.spec.whatwg.org/multipage/indices.html#event-unhandledrejection)s, as this promise only ever rejects along with the
 [update callback done
 promise](#viewtransition-update-callback-done-promise).

[initial snapshot containing block size]

: a [tuple](https://infra.spec.whatwg.org/#tuple) of two numbers (width and height), or null.
 Initially null.

 This is used to detect changes in the [snapshot
 containing block
 size](#snapshot-containing-block-size), which causes the transition to
 [skip](#skip-the-view-transition). [Discussion of this
 behavior](https://github.com/w3c/csswg-drafts/issues/8045).

[active types]

: A
 [`ViewTransitionTypeSet`](#viewtransitiontypeset), initially empty.

[outbound post-capture steps]

: Null or a set of steps, initially null.

[root element]

: An
 [`Element`](https://dom.spec.whatwg.org/#element), indicating which element is hosting the
 [`ViewTransition`](#viewtransition).

[wait until promise count]

: An integer, initially 0. Represents the count of promises that have
 been added via
 [`waitUntil()`](#dom-viewtransition-waituntil) and have not settled.

The
[`finished`](#dom-viewtransition-finished) [getter
steps](https://webidl.spec.whatwg.org/#getter-steps) are to return
[this's](https://webidl.spec.whatwg.org/#this) [finished
promise](#viewtransition-finished-promise).

The
[`ready`](#dom-viewtransition-ready) [getter
steps](https://webidl.spec.whatwg.org/#getter-steps) are to return
[this's](https://webidl.spec.whatwg.org/#this) [ready
promise](#viewtransition-ready-promise).

The
[`updateCallbackDone`](#dom-viewtransition-updatecallbackdone) [getter
steps](https://webidl.spec.whatwg.org/#getter-steps) are to return
[this's](https://webidl.spec.whatwg.org/#this) [update callback done
promise](#viewtransition-update-callback-done-promise).

The
[`types`](#dom-viewtransition-types) [getter
steps](https://webidl.spec.whatwg.org/#getter-steps) are to return
[this](https://webidl.spec.whatwg.org/#this)'s [active
types](#viewtransition-active-types).

The
[`transitionRoot`](#dom-viewtransition-transitionroot) [getter
steps](https://webidl.spec.whatwg.org/#getter-steps) are to return
[this](https://webidl.spec.whatwg.org/#this)'s [root
element](#viewtransition-root-element).

#### 2.3.1. The [`ViewTransitionTypeSet` Interface]
```
[Exposed=Window]
interface ViewTransitionTypeSet {
 setlike<DOMString>;
};
```

The
[`ViewTransitionTypeSet`](#viewtransitiontypeset) object represents a
[set](https://infra.spec.whatwg.org/#ordered-set) of strings, without special semantics.

 a
[`ViewTransitionTypeSet`](#viewtransitiontypeset) can contain strings that are invalid for
[:active-view-transition-type], e.g. strings that are not a
[\<custom-ident\>](https://drafts.csswg.org/css-values-4/#identifier-value).

#### 2.3.2. [`skipTransition()` Method Steps]
The [method
steps](https://webidl.spec.whatwg.org/#method-steps) for
[`skipTransition()`] are:

1. If [this](https://webidl.spec.whatwg.org/#this)'s
 [phase](#viewtransition-phase) is not \"`done`\", then [skip the view
 transition](#skip-the-view-transition) for [this] with an
 \"[`AbortError`](https://webidl.spec.whatwg.org/#aborterror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

#### 2.3.3. [`waitUntil()` Method Steps]
The [method
steps](https://webidl.spec.whatwg.org/#method-steps) for
[`waitUntil(``promise``)`] are:

1. [Delay finish for
 promise](#delay-finish-for-promise) given
 [this](https://webidl.spec.whatwg.org/#this) and `promise`.

## 3. CSS properties

### 3.1. Tagging Individually Transitioning Subtrees: the [view-transition-name property]
Name:

[view-transition-name]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

none
[\|](https://drafts.csswg.org/css-values-4/#comb-one)
[\<custom-ident\>](https://drafts.csswg.org/css-values-4/#identifier-value)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

none

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[all
elements](https://www.w3.org/TR/css-pseudo/#generated-content "Includes ::before and ::after pseudo-elements.")

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

as specified

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

 though
[view-transition-name](#propdef-view-transition-name) is [discretely
animatable](https://drafts.csswg.org/web-animations-1/#discrete), animating it doesn't affect the running view
transition. Rather, it's a way to set its value in a way that can change
over time or based on a
[timeline](https://drafts.csswg.org/web-animations-1/#timeline). An example for using this would be to change the
[view-transition-name]
based on [scroll-driven
animations](https://drafts.csswg.org/scroll-animations-1/#scroll-driven-animations).

The
[view-transition-name](#propdef-view-transition-name) property "tags" an element for
[capture in a view
transition](#element-captured-in-a-view-transition), tracking it independently in the [view transition
tree](#view-transition-tree) under the specified [view transition
name]. An element so captured is animated independently of the
rest of the page.

[none]

: The
 [element](https://drafts.csswg.org/css2/#element) will not participate independently in a view
 transition.

[[\<custom-ident\>](https://drafts.csswg.org/css-values-4/#identifier-value)]

: The
 [element](https://drafts.csswg.org/css2/#element) participates independently in a view
 transition---​as either an old or new
 [element]---​with the specified [view transition
 name](#view-transition-name).

 Each [view transition
 name](#view-transition-name) is a [tree-scoped
 name](https://drafts.csswg.org/css-shadow-1/#css-tree-scoped-name).

 The values [none], [auto], and [match-element] are
 excluded from
 [\<custom-ident\>](https://drafts.csswg.org/css-values-4/#identifier-value) here.

 If this name is not unique within a single
 transition (i.e. if two elements simultaneously specify the same
 [view transition
 name](#view-transition-name)) then the [view
 transition](#view-transitions) will abort. It is, however, possible to have
 non-unique [view transition name]s
 as long as the elements with these names are never part of the same
 transition.

 For the purposes of this API, if one element has [view
transition name](#view-transition-name) [foo] in the old state, and another element has
[view transition name] [foo] in
the new state, they are treated as representing different visual states
of the same element, and will be paired in the [view transition
tree](#view-transition-tree). This may be confusing, since the elements themselves
are not necessarily referring to the same object, but it is a useful
model to consider them to be visual states of the same conceptual page
entity.

If the element's [principal
box](https://drafts.csswg.org/css-display-4/#principal-box) is
[fragmented](https://drafts.csswg.org/css-break-4/#fragment),
[skipped](https://drafts.csswg.org/css-contain-2/#skips-its-contents), or [not
rendered](https://drafts.csswg.org/css-images-4/#element-not-rendered), this property has no effect. See [§ 12
Algorithms](#algorithms) for exact details.

To get the [document-scoped view transition
name] for an
[`Element`](https://dom.spec.whatwg.org/#element) `element`:

1. Let `scopedViewTransitionName` be the [computed
 value](https://drafts.csswg.org/css-cascade-5/#computed-value) of
 [view-transition-name](#propdef-view-transition-name) for `element`.

2. If `scopedViewTransitionName` is associated with
 `element`'s [node
 document](https://dom.spec.whatwg.org/#concept-node-document), then return `scopedViewTransitionName`.

3. Otherwise, return
 [none](#valdef-view-transition-name-none).

#### 3.1.1. Rendering Consolidation

[Elements](https://drafts.csswg.org/css2/#element) [captured in a view
transition](#element-captured-in-a-view-transition) during a [view
transition](#view-transitions) or whose
[view-transition-name](#propdef-view-transition-name) [computed
value](https://drafts.csswg.org/css-cascade-5/#computed-value) is not
[none](#valdef-view-transition-name-none) (at any time):

- Form a [stacking
 context](https://www.w3.org/TR/CSS2/visuren.html#x43).

- Are [flattened in 3D
 transforms](https://drafts.csswg.org/css-transforms-2/#grouping-property-values).

- Form a [backdrop
 root](https://drafts.csswg.org/filter-effects-2/#backdrop-root).

### 3.2. Isolating Scoped View Transition Names: the [view-transition-scope property]
Name:

[view-transition-scope]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

none
[\|](https://drafts.csswg.org/css-values-4/#comb-one) all

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

none

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[all
elements](https://www.w3.org/TR/css-pseudo/#generated-content "Includes ::before and ::after pseudo-elements.")

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

as specified

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

 Although
[view-transition-scope](#propdef-view-transition-scope) is [discretely
animatable](https://drafts.csswg.org/web-animations-1/#discrete), it only has an effect during
[view-transition-name](#propdef-view-transition-name) discovery

[none]

: This property has no effect on
 [view-transition-name](#propdef-view-transition-name) discoverability.

[all]

: Discoverability of
 [view-transition-name](#propdef-view-transition-name) is limited to the subtree of
 this element. This is done by applying [view transition
 scoping]. Such scoping means that any transitions that originate
 outside of the element will not discover a non-none
 [view-transition-name] either on this element or in its flat-tree descedants.

 :::
 (#example-53c939c6)
 ```
 <style>
 .scope { view-transition-scope: all; }
 #a { view-transition-name: a; }
 #b { view-transition-name: b; }
 #c { view-transition-name: c; }
 #d { view-transition-name: d; }
 </style>

 <div id=a>
 <div id=b class=scope>
 <div id=c></div>
 </div>
 <div id=d></div>
 </div>

 <script>
 ...
 a.startViewTransition(); // Will discover "a" and "d" view-transition-names
 b.startViewTransition(); // Will discover "b" and "c" view-transition-names
 ...
 </script>
 ```
 :::

 Starting a transition implies that
 [this](https://webidl.spec.whatwg.org/#this) element has [view-transition-scope:
 all](#propdef-view-transition-scope) for the duration of the transition.

 :::
 (#example-2775a2d1)
 ```
 <style>
 #a { view-transition-name: a; }
 #b { view-transition-name: b; }
 #c { view-transition-name: c; }
 #d { view-transition-name: d; }
 </style>

 <div id=a>
 <div id=b>
 <div id=c></div>
 </div>
 <div id=d></div>
 </div>

 <script>
 ...
 b.startViewTransition(); // Will discover "b" and "d" view-transition-names

 // While b's transition is active and running, the following will only discover
 // "a" and "d" view transition names, since b has a forced view-transition-scope: all.
 b.startViewTransition()
 ...
 </script>
 ```
 :::

 Most elements running or planning to run a [scoped view
transition](#scoped-view-transitions) should use [view-transition-scope:
all](#propdef-view-transition-scope), to ensure that their [document-scoped view
transition
names](#document-scoped-view-transition-name) don't accidentally interfere with other [scoped view
transitions] in the ancestor chain.

### 3.3. Nested View Transition Groups: The [view-transition-group property]
Name:

[view-transition-group]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

normal
[\|](https://drafts.csswg.org/css-values-4/#comb-one) contain [\|] nearest
[\|]
[\<custom-ident\>](https://drafts.csswg.org/css-values-4/#identifier-value)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

normal

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[all
elements](https://www.w3.org/TR/css-pseudo/#generated-content "Includes ::before and ::after pseudo-elements.")

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

as specified

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

The
[view-transition-group](#propdef-view-transition-group) property can be used in conjuction
with
[view-transition-name](#propdef-view-transition-name) to generate a hierarchy of [named
view transition
pseudo-element](#named-view-transition-pseudo-elements). This property has no effect if
[view-transition-name] is
[none](#valdef-view-transition-name-none).

[normal]

: The [view-transition-group()]
 [pseudo-element](https://drafts.csswg.org/selectors-4/#pseudo-element) generated by this element is a child of the
 [view-transition-group-children()]
 [pseudo-element] generated by this
 element's nearest [view-transition-group()] generating [flat
 tree](https://drafts.csswg.org/css-shadow-1/#flat-tree) ancestor element with a
 non-[normal](#valdef-view-transition-group-normal)
 [view-transition-group](#propdef-view-transition-group) value, if any. If no such
 element is present, the [view-transition-group()]
 [pseudo-element] generated by this element
 is a direct child of the
 [::view-transition](#selectordef-view-transition) [pseudo-element]
 associated with this view transition.

[contain]

: The [view-transition-group-children()]
 [pseudo-element](https://drafts.csswg.org/selectors-4/#pseudo-element) generated by this element acts as a container for
 its descendants. See
 [normal](#valdef-view-transition-group-normal) for the effect it has on other elements.

[nearest]

: The [view-transition-group()]
 [pseudo-element](https://drafts.csswg.org/selectors-4/#pseudo-element) generated by this element is a child of the
 [view-transition-group-children()]
 [pseudo-element] generated by this
 element's nearest [view-transition-group()] generating [flat
 tree](https://drafts.csswg.org/css-shadow-1/#flat-tree) ancestor element, if any. If no such element is
 present, the [view-transition-group()]
 [pseudo-element] generated by this element
 is a direct child of the
 [::view-transition](#selectordef-view-transition) [pseudo-element]
 associated with this view transition.

[[\<custom-ident\>](https://drafts.csswg.org/css-values-4/#identifier-value)]

: The [view-transition-group()]
 [pseudo-element](https://drafts.csswg.org/selectors-4/#pseudo-element) generated by this element is a child of the
 [view-transition-group()]
 [pseudo-element] generated by this
 element's [flat
 tree](https://drafts.csswg.org/css-shadow-1/#flat-tree) ancestor element with a
 [view-transition-name] value that matches
 \'[\<custom-ident\>](https://drafts.csswg.org/css-values-4/#identifier-value)\', if any. If no such element is
 present, the [view-transition-group()]
 [pseudo-element] generated by this
 element is a direct child of the
 [::view-transition](#selectordef-view-transition) [pseudo-element]
 associated with this view transition.

The [view-transition-group-children()]
[pseudo-element](https://drafts.csswg.org/selectors-4/#pseudo-element) is generated if and only if there is a
[view-transition-group()]
[pseudo-element] attached to it.

The [used
value](https://drafts.csswg.org/css-cascade-5/#used-value) for
[view-transition-group](#propdef-view-transition-group) resolves to a
[view-transition-name](#propdef-view-transition-name) in its ancestor chain, or to
[none](#valdef-view-transition-name-none). When generating the [named view transition
pseudo-element](#named-view-transition-pseudo-elements), the
[::view-transition-group()](#selectordef-view-transition-group) with that name would create a
[::view-transition-group-children()](#selectordef-view-transition-group-children) pseudo-element, which would be the parent of the
[::view-transition-group()] generated for this element's
[view-transition-name].

#### 3.3.1. Nested View Transition Group Explanation

*This section is non-normative.*

By default, setting `view-transition-name` on multiple elements
generates a flat [view transition
tree](#view-transition-tree), where all the
[::view-transition-group()](#selectordef-view-transition-group) pseudo-elements are children of the
[::view-transition](#selectordef-view-transition) pseudo-element. This is sufficient for many
simple use-cases, but there are some styling use-cases that cannot be
achieved with a flat tree. The most prominent use-case is clipping: with
a flat tree, all pseudo-elements are clipped to the [snapshot containing
block](#snapshot-containing-block), so clipping elements in the normal tree would lose
their clipping during the view-transition, resulting in a broken visual
effect. The effects that have can have an unexpected visual effect in a
flat tree:

- Clipping
 ([overflow](https://drafts.csswg.org/css-overflow-3/#propdef-overflow),
 [clip-path](https://drafts.csswg.org/css-masking-1/#propdef-clip-path),
 [border-radius](https://drafts.csswg.org/css-borders-4/#propdef-border-radius)): clipping affects the children
 of the element.

- [opacity](https://drafts.csswg.org/css-color-4/#propdef-opacity),
 [mask-image](https://drafts.csswg.org/css-masking-1/#propdef-mask-image) and
 [filter](https://drafts.csswg.org/filter-effects-1/#propdef-filter): These effects that are designed
 to work on a fully rasterized image of a tree, rather than on each
 item individually.

- 3D transforms
 ([transform-style](https://drafts.csswg.org/css-transforms-2/#propdef-transform-style),
 [transform](https://drafts.csswg.org/css-transforms-1/#propdef-transform),
 [perspective](https://drafts.csswg.org/css-transforms-2/#propdef-perspective)): to display the full range of 3D
 transform animations, some hierarchy needs to be kept.

To enable these use cases, this specification introduces the concept of
nesting view-transition pseudo-elements. By using the
[view-transition-group](#propdef-view-transition-group) CSS property, the author can assign
a \"parent group\" for a generated
[::view-transition-group()](#selectordef-view-transition-group) pseudo-element, creating a hierarchy in the
[view transition
tree](#view-transition-tree).

#### 3.3.2. Examples

This example creates a transition
where the [view transition
tree](#view-transition-tree) is nested instead of flat:

```
<section class="container">
 <article>Content</article>
</section>
```

```
.container {
 view-transition-name: container;
}

.container,
::view-transition-group-children(container) {
 clip-path: circle();
}

article {
 view-transition-name: article;
 view-transition-group: container;
}
```

The pseudo-element tree for this would be as follows:

 ::view-transition
 ├─ ::view-transition-group(container)
 │ ├─ ::view-transition-image-pair(container)
 │ │ ├─ ::view-transition-old(container)
 │ │ └─ ::view-transition-new(container)
 │ └─ ::view-transition-group-children(container)
 │ ├─ ::view-transition-group(article)
 │ │ ├─ ::view-transition-old(article)
 │ │ └─ ::view-transition-new(article)
 │ └─ ...other nested groups...
 └─ …other groups…

By applying the [clip-path] to both the containing element and its
generated
[::view-transition-group-children()](#selectordef-view-transition-group-children) pseudo-element, we preserve the clip during the
transition, and by applying [view-transition-group] to the
internal element referencing the container, we make the tree \"nested\"
in a way that would apply this clipping.

## 4. Scoped View Transitions

In addition to [view
transitions](#view-transitions) triggered on the
[document](https://dom.spec.whatwg.org/#concept-document) itself ([global view
transitions]), individual
[elements](https://drafts.csswg.org/css2/#element) can host their own [scoped view
transitions]. This enables multiple [view
transitions] to run on a page at the same
time, with each animating a different subtree of the document. It also
enables a [view transition] to be affected
by the layout and rendering of its subtree, being affected by scrolling,
filters,
[z-index](https://drafts.csswg.org/css2/#propdef-z-index), etc. (\"Global\" [view
transitions] are always rendered on a
separate, higher rendering layer than the rest of the document.)

In order to host a [scoped view
transition](#scoped-view-transitions), an element must qualify for [layout
containment](https://drafts.csswg.org/css-contain-2/#layout-containment), which will be applied automatically, so its painted
output can be captured as an atomic unit.

[View transitions](#view-transitions) whose [root
element](#viewtransition-root-element) is the [document
element](https://dom.spec.whatwg.org/#document-element) are *not* [scoped view
transitions](#scoped-view-transitions). They're [global view
transitions](#global-view-transitions).

## 5. Pseudo-elements

### 5.1. Pseudo-element Trees

 This is a general definition for trees of
pseudo-elements. If other features need this behavior, these definitions
will be moved to
[\[css-pseudo-4\]](#biblio-css-pseudo-4 "CSS Pseudo-Elements Module Level 4").

A [pseudo-element root] is a type of [tree-abiding
pseudo-element](https://drafts.csswg.org/css-pseudo-4/#tree-abiding) that is the
[root](https://dom.spec.whatwg.org/#concept-tree-root) in a
[tree](https://dom.spec.whatwg.org/#concept-tree) of [tree-abiding
pseudo-elements], known as the [pseudo-element
tree].

The [pseudo-element
tree](#pseudo-element-tree) defines the document order of its
[descendant](https://dom.spec.whatwg.org/#concept-tree-descendant) [tree-abiding
pseudo-elements](https://drafts.csswg.org/css-pseudo-4/#tree-abiding).

When a
[pseudo-element](https://drafts.csswg.org/selectors-4/#pseudo-element)
[participates](https://dom.spec.whatwg.org/#concept-tree-participate) in a [pseudo-element
tree](#pseudo-element-tree), its [originating
pseudo-element](https://drafts.csswg.org/selectors-4/#originating-pseudo-element) is its
[parent](https://dom.spec.whatwg.org/#concept-tree-parent).

If a
[descendant](https://dom.spec.whatwg.org/#concept-tree-descendant) `pseudo` of a [pseudo-element
root](#pseudo-element-root) has no other
[siblings](https://dom.spec.whatwg.org/#concept-tree-sibling), then
[:only-child](https://drafts.csswg.org/selectors-4/#only-child-pseudo) matches that `pseudo`.

 This means that
`::view-transition-new(ident):only-child` will only select
`::view-transition-new(ident)` if the parent
`::view-transition-image-pair(ident)` contains a single
[child](https://dom.spec.whatwg.org/#concept-tree-child). As in, there is no
[sibling](https://dom.spec.whatwg.org/#concept-tree-sibling) `::view-transition-old(ident)`.

### 5.2. View Transition Pseudo-elements

The visualization of a [view
transition](#view-transitions) is represented as a [pseudo-element
tree](#pseudo-element-tree) called the [view transition tree] composed of the [view
transition pseudo-elements] defined below. This tree is
built during the [setup transition
pseudo-elements](#setup-transition-pseudo-elements) step, and is rooted under a
[::view-transition](#selectordef-view-transition) pseudo-element
[originating](https://drafts.csswg.org/selectors-4/#originating-element) from the
[`ViewTransition`](#viewtransition)'s [root
element](#viewtransition-root-element). All of the [view transition
pseudo-elements](#view-transition-pseudo-elements) are selected from their [ultimate originating
element](https://drafts.csswg.org/selectors-4/#ultimate-originating-element), the
[`ViewTransition`](#viewtransition)'s [root
element].

The [view transition
tree](#view-transition-tree) is not exposed to the accessibility tree.

For example, even though a
[::view-transition-group()](#selectordef-view-transition-group) pseudo-element is nested underneath its parent
[::view-transition](#selectordef-view-transition) pseudo-element for styling and layout purposes,
it's selected directly on the element hosting the
[`ViewTransition`](#viewtransition): if you'd use [.foo::view-transition], you'll
also use [.foo::view-transition-group()].

Doing [.foo::view-transition::view-transition-group()] is
incorrect, and won't select anything.

Once the user-agent has captured both the "old" and "new" states of the
document, it creates a structure of pseudo-elements like the following:

 ::view-transition
 ├─ ::view-transition-group(name)
 │ └─ ::view-transition-image-pair(name)
 │ ├─ ::view-transition-old(name)
 │ └─ ::view-transition-new(name)
 └─ …other groups…

Each element with a
[view-transition-name](#propdef-view-transition-name) is captured separately, and a
[::view-transition-group()](#selectordef-view-transition-group) is created for each unique
[view-transition-name].

For convenience, the [document
element](https://dom.spec.whatwg.org/#document-element) is given the
[view-transition-name](#propdef-view-transition-name) \"root\" in the [user-agent style
sheet](#ua-styles).

Either
[::view-transition-old()](#selectordef-view-transition-old) or
[::view-transition-new()](#selectordef-view-transition-new) are absent in cases where the capture does not
have an "old" or "new" state.

Each of the pseudo-elements generated can be targeted by CSS in order to
customize its appearance, behavior and/or add animations. This enables
full customization of the transition.

When using [view-transition-group] property, an additional
[::view-transition-group-children()](#selectordef-view-transition-group-children) pseudo is created that allows for clipping of
descendants and specifying relative transforms.

 ::view-transition
 ├─ ::view-transition-group(name)
 │ ├─ ::view-transition-image-pair(name)
 │ │ ├─ ::view-transition-old(name)
 │ │ └─ ::view-transition-new(name)
 │ └─ ::view-transition-group-children(name)
 │ └─ …groups nested under 'name'…
 └─ …other groups…

[view-transition-group-children()] element can now be customized
to add, for example, clipping with \'overflow: clip\'. This would clip
any [view-transition-group()] pseudo-elements along with their
descendants.

#### 5.2.1. Named View Transition Pseudo-elements

Several of the [view transition
pseudo-elements](#view-transition-pseudo-elements) are [named view transition
pseudo-elements], which are
[functional](https://drafts.csswg.org/selectors-4/#functional-pseudo-element) [fully
styleable](https://drafts.csswg.org/css-pseudo-4/#fully-styleable) [view transition
pseudo-elements] associated
with a [view transition
name](#view-transition-name). These pseudo-elements take a
[\<pt-name-selector\>](#typedef-pt-name-selector) as their argument, and their syntax
follows the pattern:

``` prod
::view-transition-pseudo(<pt-name-selector>)
```

where
[\<pt-name-selector\>](#typedef-pt-name-selector) selects a [view transition
name](#view-transition-name), and has the following syntax definition:

``` prod
<pt-name-selector> = '*' | <custom-ident>
```

A [named view transition
pseudo-element](#named-view-transition-pseudo-elements)
[selector](https://drafts.csswg.org/selectors-4/#selector) only matches a corresponding
[pseudo-element](https://drafts.csswg.org/selectors-4/#pseudo-element) if its
[\<pt-name-selector\>](#typedef-pt-name-selector) matches that
[pseudo-element]'s [view transition
name](#view-transition-name), i.e. if it is either
[\*](https://drafts.csswg.org/selectors-3/#x) or a matching
[\<custom-ident\>](https://drafts.csswg.org/css-values-4/#identifier-value).

 The [view transition
name](#view-transition-name) of a [view transition
pseudo-element](#view-transition-pseudo-elements) is set to the
[view-transition-name](#propdef-view-transition-name) that triggered its creation.

The specificity of a [named view transition
pseudo-element](#named-view-transition-pseudo-elements)
[selector](https://drafts.csswg.org/selectors-4/#selector) with a
[\<custom-ident\>](https://drafts.csswg.org/css-values-4/#identifier-value) argument is equivalent to a [type
selector](https://drafts.csswg.org/selectors-4/#type-selector). The specificity of a [named view transition
pseudo-element]
[selector] with a
[\*](https://drafts.csswg.org/selectors-3/#x) argument is zero.

#### 5.2.2. View Transition Tree Root: the [::view-transition pseudo-element]
The [::view-transition]
[pseudo-element](https://drafts.csswg.org/selectors-4/#pseudo-element) is a [fully styleable
pseudo-element](https://drafts.csswg.org/css-pseudo-4/#fully-styleable) that is also a [pseudo-element
root](#pseudo-element-root). If its [originating
element](https://drafts.csswg.org/selectors-4/#originating-element) is the document's [document
element](https://dom.spec.whatwg.org/#document-element), its [containing
block](https://drafts.csswg.org/css-display-4/#containing-block) is the [snapshot containing
block](#snapshot-containing-block).

 In that case, the position of this element within the
[document
element](https://dom.spec.whatwg.org/#document-element) does not matter, as its [containing
block](https://drafts.csswg.org/css-display-4/#containing-block) is the [snapshot containing
block](#snapshot-containing-block).

An element's
[::view-transition](#selectordef-view-transition) pseudo-element only generates boxes when that
pseudo-element has children.

 This element serves as the
[parent](https://dom.spec.whatwg.org/#concept-tree-parent) of all
[::view-transition-group()](#selectordef-view-transition-group) pseudo-elements.

#### 5.2.3. View Transition Named Subtree Root: the [::view-transition-group() pseudo-element](#::view-transition-group)

The [::view-transition-group()]
[pseudo-element](https://drafts.csswg.org/selectors-4/#pseudo-element) is a [named view transition
pseudo-element](#named-view-transition-pseudo-elements) that represents a matching named [view
transition](#view-transitions) capture. A
[::view-transition-group()](#selectordef-view-transition-group) [pseudo-element] is
generated for each [view transition
name](#view-transition-name) as a
[child](https://dom.spec.whatwg.org/#concept-tree-child) of the
[::view-transition](#selectordef-view-transition) [pseudo-element], and
contains a corresponding
[::view-transition-image-pair()](#selectordef-view-transition-image-pair).

This element initially mirrors the size and position of the "old"
element, or the "new" element if there isn't an "old" element.

If there's both an "old" and "new" state, styles in the [dynamic view
transition style
sheet](#document-dynamic-view-transition-style-sheet) animate this pseudo-element's
[width](https://drafts.csswg.org/css-sizing-3/#propdef-width) and
[height](https://drafts.csswg.org/css-sizing-3/#propdef-height) from the size of the old element's
[border
box](https://drafts.csswg.org/css-box-4/#border-box) to that of the new element's [border
box].

Also the element's
[transform](https://drafts.csswg.org/css-transforms-1/#propdef-transform) is animated from the old element's
screen space transform to the new element's screen space transform.

This style is generated dynamically since the values of animated
properties are determined at the time that the transition begins.

#### 5.2.4. View Transition Image Pair Isolation: the [::view-transition-image-pair() pseudo-element](#::view-transition-image-pair)

The
[::view-transition-image-pair()]
[pseudo-element](https://drafts.csswg.org/selectors-4/#pseudo-element) is a [named view transition
pseudo-element](#named-view-transition-pseudo-elements) that represents a pair of corresponding old/new [view
transition](#view-transitions) captures. This pseudo-element is a
[child](https://dom.spec.whatwg.org/#concept-tree-child) of the corresponding
[::view-transition-group()](#selectordef-view-transition-group) pseudo-element and contains a corresponding
[::view-transition-old()](#selectordef-view-transition-old) pseudo-element and/or a corresponding
[::view-transition-new()](#selectordef-view-transition-new) pseudo-element (in that order).

This element exists to provide [isolation:
isolate](https://drafts.csswg.org/compositing-2/#propdef-isolation) for its children, and is always present as a
[child](https://dom.spec.whatwg.org/#concept-tree-child) of each
[::view-transition-group()](#selectordef-view-transition-group). This isolation allows the image pair to be
blended with non-normal blend modes without affecting other visual
outputs. As such, the developer would typically not need to add custom
styles to the
[::view-transition-image-pair()](#selectordef-view-transition-image-pair) pseudo-element. Instead, a typical design would
involve styling the
[::view-transition-group()],
[::view-transition-old()](#selectordef-view-transition-old), and
[::view-transition-new()](#selectordef-view-transition-new) pseudo-elements.

#### 5.2.5. View Transition Old State Image: the [::view-transition-old() pseudo-element](#::view-transition-old)

The [::view-transition-old()]
[pseudo-element](https://drafts.csswg.org/selectors-4/#pseudo-element) is an empty [named view transition
pseudo-element](#named-view-transition-pseudo-elements) that represents a visual snapshot of the "old" state as
a [replaced
element](https://drafts.csswg.org/css-display-4/#replaced-element); it is omitted if there's no "old" state to represent.
Each
[::view-transition-old()](#selectordef-view-transition-old) pseudo-element is a
[child](https://dom.spec.whatwg.org/#concept-tree-child) of the corresponding
[::view-transition-image-pair()](#selectordef-view-transition-image-pair) pseudo-element.

[:only-child](https://drafts.csswg.org/selectors-4/#only-child-pseudo) can be used to match cases where this element is
the only element in the
[::view-transition-image-pair()](#selectordef-view-transition-image-pair).

The appearance of this element can be manipulated with `object-*`
properties in the same way that other replaced elements can be.

 The content and [natural
dimensions](https://drafts.csswg.org/css-images-3/#natural-dimensions) of the image are captured in [capture the
image](#capture-the-image),
and set in [setup transition
pseudo-elements](#setup-transition-pseudo-elements).

 Additional styles in the [dynamic view transition style
sheet](#document-dynamic-view-transition-style-sheet) added to animate these pseudo-elements are detailed in
[setup transition
pseudo-elements](#setup-transition-pseudo-elements) and [update pseudo-element
styles](#update-pseudo-element-styles).

#### 5.2.6. View Transition New State Image: the [::view-transition-new() pseudo-element](#::view-transition-new)

The [::view-transition-new()]
[pseudo-element](https://drafts.csswg.org/selectors-4/#pseudo-element) (like the analogous
[::view-transition-old()](#selectordef-view-transition-old) pseudo-element) is an empty [named view
transition
pseudo-element](#named-view-transition-pseudo-elements) that represents a visual snapshot of the "new" state as
a [replaced
element](https://drafts.csswg.org/css-display-4/#replaced-element); it is omitted if there's no "new" state to represent.
Each
[::view-transition-new()](#selectordef-view-transition-new) pseudo-element is a
[child](https://dom.spec.whatwg.org/#concept-tree-child) of the corresponding
[::view-transition-image-pair()](#selectordef-view-transition-image-pair) pseudo-element.

 The content and [natural
dimensions](https://drafts.csswg.org/css-images-3/#natural-dimensions) of the image are captured in [capture the
image](#capture-the-image),
then set and updated in [setup transition
pseudo-elements](#setup-transition-pseudo-elements) and [update pseudo-element
styles](#update-pseudo-element-styles).

#### 5.2.7. View Transition Group Children: the [::view-transition-group-children() pseudo-element](#::view-transition-group-children)

The
[::view-transition-group-children()]
[pseudo-element](https://drafts.csswg.org/selectors-4/#pseudo-element) is created when mandated by the
[view-transition-group] property on either the element itself or
on its contained element. It serves as a container for descendant
[view-transition-group()] pseudo-elements. By default, it is sized
to the same size as the corresponding [view-transition-group()]
pseudo element. By default, it has a transparent border that matches the
size and shape of the border on the element that caused this structure
to be created.

 The size and border setting on this pseudo element
allow the developer to enable clipping of the descedant pseudo elements
with a simple [overflow:
clip](https://drafts.csswg.org/css-overflow-3/#propdef-overflow) property. The developer needs to take care if
the original element has non-overscroll scrollbars, since these
scrollbars change the clipping area from the default provided by this
element.

## 6. View Transition Layout

The [view transition
pseudo-elements](#view-transition-pseudo-elements) are styled, laid out, and rendered like normal
elements. [Global view
transitions](#global-view-transitions) originate in the [snapshot containing
block](#snapshot-containing-block) rather than the [initial containing
block](https://drafts.csswg.org/css-display-4/#initial-containing-block) and are painted in the [view transition
layer](#view-transition-layer) above the rest of the document; [scoped view
transitions](#scoped-view-transitions) are simply rendered after and above all other children
of their [root
element](#viewtransition-root-element).

### 6.1. The Snapshot Containing Block

The [snapshot containing block] is a rectangle that covers all
areas of the window that could potentially display page content (and is
therefore consistent regardless of root scrollbars or [interactive
widgets](https://drafts.csswg.org/css-viewport/#interactive-widget)). This makes it likely to be consistent for the
[document
element](https://dom.spec.whatwg.org/#document-element)'s [old
image](#captured-element-old-image) and [new
element](#captured-element-new-element).

Within a [child
navigable](https://html.spec.whatwg.org/multipage/document-sequences.html#child-navigable), the [snapshot containing
block](#snapshot-containing-block) is the union of the navigable's
[viewport](https://drafts.csswg.org/css2/#viewport%E2%91%A0) with any [scrollbar
gutters](https://drafts.csswg.org/css-overflow-3/#scrollbar-gutter).

<figure>
<img src="diagrams/phone-browser.svg" width="200" height="335"
a />
<img src="diagrams/phone-browser-snapshot-root.svg" width="200"
height="335"
a />
<figcaption>An example of the <a href="#snapshot-containing-block"
id="ref-for-snapshot-containing-block⑤" data->snapshot
containing block</a> on a mobile OS. The snapshot includes the URL bar,
as this can be scrolled away. The keyboard is included as this appears
and disappears. The top and bottom bars are part of the OS rather than
the browser, so they’re not included in the snapshot containing
block.</figcaption>
</figure>

<figure>
<img src="diagrams/desktop-browser.svg"
style="height:auto; width: 600px" width="132" height="79"
a />
<img src="diagrams/desktop-browser-snapshot-root.svg"
style="height:auto; width: 600px" width="132" height="79"
a />
<figcaption>An example of the <a href="#snapshot-containing-block"
id="ref-for-snapshot-containing-block⑥" data->snapshot
containing block</a> on a desktop OS. This includes the scrollbars, but
does not include the URL bar, as web content never appears in that
area.</figcaption>
</figure>

The [snapshot containing block origin] refers to the top-left
corner of the [snapshot containing
block](#snapshot-containing-block).

The [snapshot containing block size] refers to the width and
height of the [snapshot containing
block](#snapshot-containing-block) as a
[tuple](https://infra.spec.whatwg.org/#tuple) of two numbers.

The [snapshot containing
block](#snapshot-containing-block) is considered to be an [absolute positioning containing
block](https://drafts.csswg.org/css-position-3/#absolute-positioning-containing-block) and a [fixed positioning containing
block](https://drafts.csswg.org/css-position-3/#fixed-positioning-containing-block) for
[::view-transition](#selectordef-view-transition) and its descendants.

### 6.2. View Transition Painting Order

This specification introduces a new stacking layer, the [view transition
layer](#view-transition-layer), to the end of the painting order established in
[CSS2§E Elaborate Description of Stacking
Contexts](https://www.w3.org/TR/CSS22/zindex.html).
[\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")

Fold this into
[\[CSS-POSITION-4\]](#biblio-css-position-4 "CSS Positioned Layout Module Level 4"),
as the interaction with [top
layers](https://drafts.csswg.org/css-position-4/#document-top-layer) needs to be specified.

For a [global view
transition](#global-view-transitions), the
[::view-transition](#selectordef-view-transition) pseudo-element generates a new stacking context,
called the [view transition layer], which paints after all other
content of the document (including any content rendered in the [top
layer](https://drafts.csswg.org/css-position-4/#document-top-layer)), after any filters and effects that are applied to
such content. (It is not subject to such filters or effects, except
insofar as they affect the rendered contents of the
[::view-transition-old()](#selectordef-view-transition-old) and
[::view-transition-new()](#selectordef-view-transition-new) pseudo-elements.)

 The intent of the feature is to be able to capture the
contents of the page, which includes the top layer elements. In order to
accomplish that, the [view transition
layer](#view-transition-layer) cannot be a part of the captured stacking contexts,
since that results in a circular dependency. Therefore, the [view
transition layer] is a sibling of all
other content.

When an [active view
transition](#document-active-view-transition)'s
[phase](#viewtransition-phase) is \"`animating`\", the boxes generated by any element
with [captured in a view
transition](#element-captured-in-a-view-transition) in that transition and its [element
contents](https://drafts.csswg.org/css-contain-2/#element-contents), except the [inclusive
descendants](https://dom.spec.whatwg.org/#concept-tree-inclusive-descendant) of the
[::view-transition](#selectordef-view-transition)
[pseudo-element](https://drafts.csswg.org/selectors-4/#pseudo-element) on that transition's [root
element](#viewtransition-root-element), are not painted (as if they had [opacity:
0](https://drafts.csswg.org/css-color-4/#propdef-opacity)) and do not respond to hit-testing (as if
they had [pointer-events:
none](https://drafts.csswg.org/css-ui-4/#propdef-pointer-events)).

 Elements participating in a transition need to skip
painting in their DOM location because their image is painted in the
corresponding
[::view-transition-new()](#selectordef-view-transition-new) pseudo-element instead. Similarly, hit-testing
is skipped because the element's DOM location does not correspond to
where its contents are rendered. However, there is no change in how
these elements are accessed by assistive technologies or the
accessibility tree.

### 6.3. Scoped View Transition Layout

For a [scoped view
transition](#scoped-view-transitions), the
[::view-transition](#selectordef-view-transition) pseudo-element is a child of the [root
element](#viewtransition-root-element) in the [box
tree](https://drafts.csswg.org/css-display-4/#box-tree), but with some behaviors that are different from
ordinary children:

- The
 [::view-transition](#selectordef-view-transition) pseudo-element generates a stacking context
 which paints separately from, and on top of, the painting of the [root
 element](#viewtransition-root-element) and its other children.

 A consequence of painting separately is that
 properties on the root element that affect the way the root element is
 painted, such as
 [opacity](https://drafts.csswg.org/css-color-4/#propdef-opacity), do not apply to the
 [::view-transition](#selectordef-view-transition) pseudo-element. However, if the root element
 is captured in a [::view-transition-group] for its own
 transition, such properties will be reflected in the captured image.

- If the [root
 element](#viewtransition-root-element) has a [scrolling
 box](https://drafts.csswg.org/cssom-view-1/#scrolling-box), the
 [::view-transition](#selectordef-view-transition) pseudo-element is not translated by the scroll
 position of the [root
 element].

- If the [root
 element](#viewtransition-root-element) clips its
 [overflow](https://drafts.csswg.org/css-overflow-3/#overflow), the
 [::view-transition](#selectordef-view-transition) pseudo-element is exempted from that clip.

## 7. User Agent Stylesheet

The [global view transition user agent style
sheet] is a [user-agent
origin](https://drafts.csswg.org/css-cascade-5/#cascade-origin-ua) style sheet containing the following rules:

```
:root {
 view-transition-name: root;
}

::view-transition {
 position: absolute;
 inset: 0;
}

::view-transition-group(*) {
 position: absolute;
 top: 0;
 left: 0;

 animation-duration: 0.25s;
 animation-fill-mode: both;
}

::view-transition-image-pair(*) {
 position: absolute;
 inset: 0;
}

::view-transition-old(*),
::view-transition-new(*) {
 position: absolute;
 display: block;
 inset-block-start: 0;
 inline-size: 100%;
 block-size: auto;
}

::view-transition-image-pair(*),
::view-transition-old(*),
::view-transition-new(*) {
 animation-duration: inherit;
 animation-fill-mode: inherit;
 animation-delay: inherit;
 animation-timing-function: inherit;
 animation-iteration-count: inherit;
 animation-direction: inherit;
 animation-play-state: inherit;
}

::view-transition-group-children(*) {
 position: absolute;
 inset: 0;
 border-style: solid;
 border-color: transparent;
}

/* Default cross-fade transition */
@keyframes -ua-view-transition-fade-out {
 to { opacity: 0; }
}
@keyframes -ua-view-transition-fade-in {
 from { opacity: 0; }
}

/* Keyframes for blending when there are 2 images */
@keyframes -ua-mix-blend-mode-plus-lighter {
 from { mix-blend-mode: plus-lighter }
 to { mix-blend-mode: plus-lighter }
}
```

Explanatory Summary

This UA style sheet does several things:

- Lay out [:root::view-transition] to cover the entire [snapshot
 containing
 block](#snapshot-containing-block) so that each [:view-transition-group()] child
 can lay out relative to it. Note: the placement of the [snapshot
 containing block] is similar to
 `position: fixed`.

- For a [scoped view
 transition](#scoped-view-transitions), lay out
 [::view-transition](#selectordef-view-transition) to cover the view transition [root
 element](#viewtransition-root-element).

- Give the [root
 element](https://drafts.csswg.org/css-display-4/#root-element) a default [view transition
 name](#view-transition-name), to allow it to be independently selected.

- Reduce layout interference from the
 [::view-transition-image-pair()](#selectordef-view-transition-image-pair) pseudo-element so that authors can essentially
 treat
 [::view-transition-old()](#selectordef-view-transition-old) and
 [::view-transition-new()](#selectordef-view-transition-new) as direct children of
 [::view-transition-group()](#selectordef-view-transition-group) for most purposes.

- Inherit animation timing through the tree so that by default, the
 animation timing set on a
 [::view-transition-group()](#selectordef-view-transition-group) will dictate the animation timing of all its
 descendants.

- Style the element captures
 [::view-transition-old()](#selectordef-view-transition-old) and
 [::view-transition-new()](#selectordef-view-transition-new) to match the size and position set on
 [::view-transition-group()](#selectordef-view-transition-group) (insofar as possible without breaking their
 aspect ratios) as it interpolates between them. Since the sizing of
 these elements depends on the mapping between logical and physical
 coordinates, [dynamic view transition style
 sheet](#document-dynamic-view-transition-style-sheet) copies relevant styles from the DOM elements.

- Set up a default quarter-second cross-fade animation for each
 [::view-transition-group()](#selectordef-view-transition-group).

Additional styles are dynamically added to the [user-agent
origin](https://drafts.csswg.org/css-cascade-5/#cascade-origin-ua) during a [view
transition](#view-transitions) through the [dynamic view transition style
sheet](#document-dynamic-view-transition-style-sheet).

## 8. Cross-document view transitions

### 8.1. Overview

*This section is non-normative.*

#### 8.1.1. Activation

With same-document view transitions, the author starts a view transition
using JavaScript, by calling
[`startViewTransition`](#dom-document-startviewtransition). In cross-document view transition, what triggers a
view transition is a navigation between two documents, as long as the
following conditions are met:

- Both documents are of the [same
 origin](https://html.spec.whatwg.org/multipage/browsers.html#same-origin);

- The page is visible throughout the entire course of the navigation;

- The user initiates the navigation by interacting with the page, e.g.
 by clicking a link or submitting a form; or by interacting with the
 browser UI to do a
 [`traverse`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#dom-navigationtype-traverse) navigation (back/forward). This excludes, for
 example, navigations initiated by the URL bar;

- the navigation didn't include cross-origin redirects; and

- both documents opted in to cross-document view transitions, using the
 [\@view-transition](#at-view-transition-rule) rule.

See the [lifecycle](#lifecycle) section for more details.

#### 8.1.2. Waiting for the new state to stabilize

In same-document view transitions, the author can indicate when the new
state of the transition is in a stable state by using the callback
passed to
[`startViewTransition`](#dom-document-startviewtransition). Since cross-document view transitions are declarative,
there is no such explicit promise. Instead, the user agent relies on the
[render-blocking
mechanism](https://html.spec.whatwg.org/multipage/dom.html#render-blocking-mechanism) to decide when the document has reached a stable state.
In this way, the author can use the `blocking`{x=""} attribute, to delay
the transition until:

- All expected scripts are executed, by using the script's
 [`blocking`](https://html.spec.whatwg.org/multipage/scripting.html#dom-script-blocking) attribute on required scripts.

- All expected styles are executed, by using the style or link's
 [`blocking`](https://html.spec.whatwg.org/multipage/semantics.html#dom-style-blocking) attribute on required styles.

- All expected HTML elements are seen by the parser, using an
 [`expect`](https://html.spec.whatwg.org/multipage/links.html#link-type-expect)
 [`HTMLLinkElement`](https://html.spec.whatwg.org/multipage/semantics.html#htmllinkelement) element.

 overusing the render-blocking mechanism could make it
so that the old state remains frozen for a long time, resulting in a
jarring user experience. To avoid this, it's advised to ensure that the
render-blocking elements are available in a timely manner.

In this example, the last frame of the old document will be shown, and
the animation will be delayed, until all the following conditions are
met:

- `style.css` is applied, to ensure the new state has the correct styles

- `fixup.js` is run, to ensure the presentation is up to date with
 script-based fixups.

- The `main-article` section is seen and parsed, to ensure enough of the
 content is loaded before allowing the transition to proceed.

```
<!DOCTYPE html>
<html>
 <head>
 < !-- This will be render-blocking by default -->
 <link rel="stylesheet" href="style.css">

 < !-- Since this script fixes up the layout, marking it as render blocking will
 ensure it's run before the view transition is activated -->
 <script async href="fixup.js" blocking="render"></script>

 < !-- Wait until the main-article element is seen and fully parsed before
 activating the transition -->
 <link rel="expect" href="#main-article" blocking="render">
 </head>
 <body>
 <header>...</header>
 <main>
 <article id="main-article">...</article>
 </main>
 <article id="secondary-article">...</article>
 </body>
</html>
```

#### 8.1.3. Customization

The [`ViewTransition`](#viewtransition) object enables customizing the transition in script.
Same-document view transitions use a single
[`ViewTransition`](#viewtransition) object returned from the
[`startViewTransition`](#dom-document-startviewtransition) call for the entire lifecycle. Cross-document view
transitions have two
[`ViewTransition`](#viewtransition) objects, one in the old document and one in the new
document.

##### 8.1.3.1. Handling the view transition in the old document

The
[`pageswap`](https://html.spec.whatwg.org/multipage/indices.html#event-pageswap) event is fired at the last moment before a document is
about to be unloaded and swapped by another document. It can be used to
find out whether a view transition is about to take place, customize it
using
[`types`](#dom-viewtransition-types), make last minute changes to the captured elements, or
skip it if necessary. The
[`PageSwapEvent`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#pageswapevent) interface has a
[`viewTransition`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#dom-pageswapevent-viewtransition) object, which would be non-null when the navigation is
eligible to a view transition, and a
[`activation`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#dom-pageswapevent-activation) object, providing handy information about the
navigation, like the URL after redirects. The transition's
[`finished`](#dom-viewtransition-finished) promise can be used for cleaning up after the
transition, in case the document is later restored from BFCache.

##### 8.1.3.2. Handling the view transition in the new document

The
[`pagereveal`](https://html.spec.whatwg.org/multipage/indices.html#event-pagereveal) event is fired right before presenting the first frame
of the new document. It can be used to find out if the view transition
is still valid, by querying the
[`viewTransition`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#dom-pagerevealevent-viewtransition) attribute. Similar to a same-document view transition,
the author can now select different
[`types`](#dom-viewtransition-types), make last minute changes to the captured elements,
wait for the transition to be
[`ready`](#dom-viewtransition-ready) in order to animate it, or skip it altogether.

#### 8.1.4. Lifecycle

*This section is non-normative.*

A successful cross-document view transition goes through the following
phases:

1. In the old
 [`Document`](https://dom.spec.whatwg.org/#document):

 1. The user initiates a navigation, by clicking a link, submitting
 a form, pressing the browser's back button, etc.

 some navigations do not trigger a
 view-transition, e.g. typing a new address in the URL bar.

 2. When the new
 [`Document`](https://dom.spec.whatwg.org/#document) is ready to be activated, the
 [`pageswap`](https://html.spec.whatwg.org/multipage/indices.html#event-pageswap) event is fired.

 3. If the navigation is [same
 origin](https://html.spec.whatwg.org/multipage/browsers.html#same-origin), has no cross-origin redirects, and the old
 [`Document`](https://dom.spec.whatwg.org/#document) has [opted in to cross-document view
 transitions](#cross-doc-opt-in), the event's
 [`viewTransition`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#dom-pageswapevent-viewtransition) attribute would be a
 [`ViewTransition`](#viewtransition) object.

 4. The author can now customize the transition, e.g. by mutating
 its
 [`types`](#dom-viewtransition-types), or
 [`skip`](#dom-viewtransition-skiptransition) it altogether.

 5. If the
 [`ViewTransition`](#viewtransition) is not skipped, the state of the old document
 is
 [captured](#capture-the-old-state).

 6. The navigation proceeds: the old
 [`Document`](https://dom.spec.whatwg.org/#document) is unloaded, and the new
 [`Document`](https://dom.spec.whatwg.org/#document) is now active.

2. Then, in the new
 [`Document`](https://dom.spec.whatwg.org/#document):

 1. When the new
 [`Document`](https://dom.spec.whatwg.org/#document) is ready for its first [rendering
 opportunity](https://html.spec.whatwg.org/multipage/webappapis.html#rendering-opportunity), an event named
 [`pagereveal`](https://html.spec.whatwg.org/multipage/indices.html#event-pagereveal) is fired on the new
 [`Document`](https://dom.spec.whatwg.org/#document), with a
 [`viewTransition`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#dom-pagerevealevent-viewtransition) attribute.

 2. This
 [`ViewTransition`](#viewtransition)'s
 [`updateCallbackDone`](#dom-viewtransition-updatecallbackdone) promise is already resolved, and its [captured
 elements](#captured-element) are populated from the old
 [`Document`](https://dom.spec.whatwg.org/#document).

 3. This is another opportunity for the author to customize the
 transition, e.g. by mutating its
 [`types`](#dom-viewtransition-types), or
 [`skip`](#dom-viewtransition-skiptransition) it altogether.

 4. The state of the new document is
 [captured](#capture-the-new-state) as the \"new\" state of the transition.

 5. From this point forward, the transition continues in a similar
 fashion to a same-document transition, as per [activate view
 transition](#activate-view-transition).

### 8.2. Examples

To generate the same cross-fade as in
the first example [CSS View Transitions 1 § 1.6
Examples](https://drafts.csswg.org/css-view-transitions-1/#examples),
but across documents, we don't need JavaScript.

Instead, we opt in to triggering view-transitions on navigation in both
page 1 and page 2:

```
// in both documents:
@view-transition {
 navigation: auto;
}
```

A link from page 1 to or from page 2 would generate a crossfade
transition for example 1. To achieve the effect examples 2, 3 & 4,
simply put the CSS for the pseudo-elements in both documents.

Note that the
[\@view-transition](#at-view-transition-rule) rule can be used together with media queries.
For example, this would only perform the transition when the screen
width is greater than:

```
@view-transition {
 navigation: auto;
}

@media (max-width: 600px) {
 navigation: none;
}
```

To achieve the effect in [example
5](https://drafts.csswg.org/css-view-transitions-1/#examples), we have
to do several things:

- Opt-in to navigation-triggered view-transitions in both pages.

- Pass the click location to the new document, e.g. via
 [`sessionStorage`](https://html.spec.whatwg.org/multipage/webstorage.html#dom-sessionstorage).

- Intercept the
 [`ViewTransition`](#viewtransition) object in the new document, using the
 [`pagereveal`](https://html.spec.whatwg.org/multipage/indices.html#event-pagereveal) event.

In both pages:

```
@view-transition {
 navigation: auto;
}
```

In the old page:

```
addEventListener('click', event => {
 sessionStorage.setItem("lastClickX", event.clientX);
 sessionStorage.setItem("lastClickY", event.clientY);
});
```

In the new page:

```
// This would run both on initial load and on reactivation from BFCache.
addEventListener("pagereveal", async event => {
 if (!event.viewTransition)
 return;

 const x = sessionStorage.getItem("lastClickX") ?? innerWidth / 2;
 const y = sessionStorage.getItem("lastClickY") ?? innerHeight / 2;

 const endRadius = Math.hypot(
 Math.max(x, innerWidth - x),
 Math.max(y, innerHeight - y)
 );

 await event.viewTransition.ready;

 // Animate the new document's view
 document.documentElement.animate(
 {
 clipPath: [
 `circle(0 at ${x}px ${y}px)`,
 `circle(${endRadius}px at ${x}px ${y}px)`,
 ],
 },
 {
 duration: 500,
 easing: 'ease-in',
 pseudoElement: '::view-transition-new(root)'
 }
 );
})
```

To choose which elements are captured
based on properties of the navigation, and whether certain images are
loaded:

In the old page:

```
window.addEventListener("pageswap", event => {
 // For example, the page was hidden, or the navigation is cross-document.
 if (!event.viewTransition)
 return;

 // If you don't want view transition for back/forward navigations...
 if (event.activation.navigationType === "traverse") {
 event.viewTransition.skipTransition();
 }

 const newURL = new URL(event.activation.entry.url);
 if (newURL.pathname === "/details" && thumbnail.complete) {
 thumbnail.classList.add("transition-to-hero");

 // This will cleanup the state if the page is restored from BFCache.
 event.viewTransition.finished.then(() => {
 thumbnail.classList.remove("transition-to-hero");
 });
 }

});
```

In the new page:

```
window.addEventListener("pagereveal", event => {
 // For example, the page was hidden, the navigation is cross-document, or the transition was skipped in the old document.
 if (!event.viewTransition)
 return;

 const oldURL = new URL(navigation.activation.from.url);
 if (newURL.pathname === "/list") {
 event.viewTransition.types.add("coming-from-list");

 // This will show the thumbnail until the view transition is finished.
 if (!hero.complete) {
 setToThumbnail(hero);
 event.viewTransition.finished.then(() => {
 setToFullResolution(hero);
 })
 }
 }
});
```

### 8.3. Opting in to cross-document view transitions

#### 8.3.1. The [[\@view-transition] rule]
The
[\@view-transition](#at-view-transition-rule) rule is used by a document to indicate that
cross-document navigations should setup and activate a
[`ViewTransition`](#viewtransition).

The
[\@view-transition](#at-view-transition-rule) rule has the following syntax:

``` prod
@view-transition {
 <declaration-list>
}
```

The
[\@view-transition](#at-view-transition-rule) rule accepts the
[navigation](#view-transition-navigation) and
[types](#view-transition-types) descriptors.

 as per default behavior, the
[\@view-transition](#at-view-transition-rule) rule can be nested inside a [conditional group
rule](https://drafts.csswg.org/css-conditional-3/#conditional-group-rule) such as
[\@media](https://drafts.csswg.org/css-conditional-3/#at-ruledef-media) or
[\@supports](https://drafts.csswg.org/css-conditional-3/#at-ruledef-supports).

When the
[\@view-transition](#at-view-transition-rule) rule changes for
[`Document`](https://dom.spec.whatwg.org/#document) `document`, the user agent must [update the
opt-in state for outbound
transitions](#update-the-opt-in-state-for-outbound-transitions) given `document`.

 this needs to be cached in the boolean because the
result needs to be read [in
parallel](https://html.spec.whatwg.org/multipage/infrastructure.html#in-parallel), when navigating.

#### 8.3.2. The [navigation descriptor]
Name:

[navigation]

For:

[\@view-transition](#at-view-transition-rule)

Value:

auto
[\|](https://drafts.csswg.org/css-values-4/#comb-one) none

Initial:

none

The \'[navigation]\' descriptor opts
in to automatically starting a view transition when performing a
navigation of a certain type. Must be present on both the old and new
document.

[none]

: There will be no transition.

[auto]

: The transition will be enabled if the navigation is same-origin,
 without cross-origin redirects, and whose
 [`NavigationType`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#navigationtype) is

 - [`traverse`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#dom-navigationtype-traverse), or

 - [`push`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#dom-navigationtype-push) or
 [`replace`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#dom-navigationtype-replace), with [user navigation
 involvement](https://html.spec.whatwg.org/multipage/browsing-the-web.html#user-navigation-involvement)
 not equal to `"browser UI"`.

 Navigations excluded from
 [auto](#valdef-view-transition-navigation-auto) are for example, navigating via the URL
 address bar or clicking a bookmark, as well as any form of user or
 script initiated
 [`reload`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#dom-navigationtype-reload).

This at-rule conforms with the forward-compatible parsing requirement of
CSS; conformant parsers that don't understand these rules will ignore
them without error. Any descriptors that are not recognized or
implemented by a given user agent, or whose value does not match the
grammars given here or in a future version of this specification, must
be ignored in their entirety; they do not make the
[\@view-transition](#at-view-transition-rule) rule invalid.

#### 8.3.3. Accessing the [\@view-transition rule using CSSOM]
The
[`CSSViewTransitionRule`](#cssviewtransitionrule) represents a
[\@view-transition](#at-view-transition-rule) rule.

```
[Exposed=Window]
interface CSSViewTransitionRule : CSSRule {
 readonly attribute CSSOMString navigation;
 [SameObject] readonly attribute FrozenArray<CSSOMString> types;
};
```

The
[`navigation`](#dom-cssviewtransitionrule-navigation) getter step is to return the value of the corresponding
[navigation] descriptor if one exists, otherwise the empty string.

The
[`types`](#dom-cssviewtransitionrule-types) getter steps is to return the value of the
corresponding [types] descriptor if one exists, otherwise an empty
[list](https://infra.spec.whatwg.org/#list).

## 9. Selective view transitions

### 9.1. Overview

*This section is non-normative.*

For simple pages, with a single view transition, setting the
[view-transition-name] property on participating elements should
be sufficient. However, in more complex scenarios, the author might want
to declare various view transitions, and only run one of them
simultaneously. For example, sliding the whole page when clicking on the
navigation bar, and sorting a list when one of its items is dragged.

To make sure each view transition only captures what it needs to, and
different transitions don't interfere with each other, this spec
introduces the concept of [active
types](#viewtransition-active-types), alongside the
[:active-view-transition](#active-view-transition-pseudo) and
[:active-view-transition-type()](#active-view-transition-type-pseudo) pseudo-classes.

[:active-view-transition](#active-view-transition-pseudo) matches the [document
element](https://dom.spec.whatwg.org/#document-element) when it has an [active view
transition](#document-active-view-transition), and
[:active-view-transition-type()](#active-view-transition-type-pseudo) matches the [document
element] if the types in the selectors match
the [active view
transition](#element-active-view-transition)'s [active
types](#viewtransition-active-types).

The [`ViewTransition`](#viewtransition)'s [active
types](#viewtransition-active-types) are populated in one of the following ways:

1. Passed as part of the arguments to
 [`startViewTransition(callbackOptions)`](#dom-document-startviewtransition)

2. Mutated at any time, using the transition's
 [`types`](#dom-viewtransition-types)

3. Declared for a cross-document view transition, using the
 [types](#view-transition-types) descriptor.

### 9.2. Examples

For example, the developer might start
a transition in the following manner:

```
document.startViewTransition({update: updateTheDOMSomehow, types: ["slide-in", "reverse"]});
```

This will activate any of the following selectors:

```
:root:active-view-transition-type(slide-in)
:root:active-view-transition-type(reverse)
:root:active-view-transition-type(slide-in, reverse)
:root:active-view-transition-type(slide-in, something-else)
:root:active-view-transition
```

While starting a transition without providing transition types, would
only activate
[:active-view-transition](#active-view-transition-pseudo):

```
document.startViewTransition(updateTheDOMSomehow);
// or
document.startViewTransition({update: updateTheDOMSomehow});
```

```
/* This would be active */
:root
:root:active-view-transition

/* This would not be active */
:root:active-view-transition-type(slide-in)
:root:active-view-transition-type(any-type-at-all-except-star)
```

### 9.3. Selecting based on the active view transition

#### 9.3.1. The [:active-view-transition pseudo-class]
The [:active-view-transition] pseudo-class applies to the
root element of the document, if it has an [active view
transition](#element-active-view-transition).

The
[specificity](https://drafts.csswg.org/selectors-4/#specificity) of an
[:active-view-transition](#active-view-transition-pseudo) is one pseudo-class selector.

An
[:active-view-transition](#active-view-transition-pseudo) pseudo-class matches the [document
element](https://dom.spec.whatwg.org/#document-element) when its [node
document](https://dom.spec.whatwg.org/#concept-node-document) has an non-null [active view
transition](#document-active-view-transition).

#### 9.3.2. The [:active-view-transition-type() pseudo-class]
The [:active-view-transition-type()] pseudo-class
applies to the root element of the document, if it has a matching
[active view
transition](#document-active-view-transition). It has the following syntax definition:

``` prod
:active-view-transition-type(<custom-ident>#)
```

The
[specificity](https://drafts.csswg.org/selectors-4/#specificity) of an
[:active-view-transition-type()](#active-view-transition-type-pseudo) is one pseudo-class selector.

An
[:active-view-transition-type()](#active-view-transition-type-pseudo) pseudo-class matches the [document
element](https://dom.spec.whatwg.org/#document-element) when its [node
document](https://dom.spec.whatwg.org/#concept-node-document) has an non-null [active view
transition](#document-active-view-transition), whose [active
types](#viewtransition-active-types)
[contains](https://infra.spec.whatwg.org/#list-contain) at least one of the
[\<custom-ident\>](https://drafts.csswg.org/css-values-4/#identifier-value) arguments.

### 9.4. Activating the transition type for cross-document view transitions

The [types](#view-transition-types) descriptor

Name:

[types]

For:

[\@view-transition](#at-view-transition-rule)

Value:

none
[\|](https://drafts.csswg.org/css-values-4/#comb-one)
[\<view-transition-type\>](#typedef-view-transition-type)[+](https://drafts.csswg.org/css-values-4/#mult-one-plus)

Initial:

none

The \'[types]\' descriptor sets
the [active
types](#viewtransition-active-types) for the transition when capturing or performing the
transition, equivalent to calling
[`startViewTransition(callbackOptions)`](#dom-document-startviewtransition) with that
[`types`](#dom-startviewtransitionoptions-types).

[none]

: No transition types are set.

[[\<view-transition-type\>](#typedef-view-transition-type)+]

: Sets the [active
 types](#viewtransition-active-types) for the transition to the specified custom
 identifiers.

where [\<view-transition-type\>] is any
[\<custom-ident\>](https://drafts.csswg.org/css-values-4/#identifier-value) other than `none`, and not starting
with the string \"-ua-\".

 the
[types](#view-transition-types) descriptor only applies to the
[`Document`](https://dom.spec.whatwg.org/#document) in which it is defined. The author is responsible for
using their chosen set of types in both documents.

## 10. Sharing styles between view transition pseudo-elements

### 10.1. Overview

*This section is non-normative.*

When styling multiple elements in the DOM in a similar way, it is common
to use the
[class](https://dom.spec.whatwg.org/#concept-class) attribute: setting a name that's shared across multiple
elements, and then using the [class
selector](https://drafts.csswg.org/selectors-4/#class-selector) to declare the shared style.

[The view transition
pseudo-elements](#named-view-transition-pseudo-elements) (e.g. [view-transition-group()]) are not defined
in the DOM, but rather by using the [view-transition-name]
property. For that purpose, the [view-transition-class]\' CSS
property provides view transitions with the equivalent of HTML
[classes](https://dom.spec.whatwg.org/#concept-class). When an element with a [view-transition-name]
also has a [view-transition-class] value, that class would be
selectable by the pseudo-elements, as per the
[examples](#vt-class-example).

### 10.2. Examples

This example creates a transition with
each box participating under its own name, while applying a 1-second
duration to the animation of all the boxes:

```
<div class="box" id="red-box"></div>
<div class="box" id="green-box"></div>
<div class="box" id="yellow-box"></div>
```

```
div.box {
 view-transition-class: any-box;
 width: 100px;
 height: 100px;
}
#red-box {
 view-transition-name: red-box;
 background: red;
}
#green-box {
 view-transition-name: green-box;
 background: green;
}
#yellow-box {
 view-transition-name: yellow-box;
 background: yellow;
}

/* The following style would apply to all the boxes, thanks to 'view-transition-class' */
::view-transition-group(*.any-box) {
 animation-duration: 1s;
}
```

### 10.3. The [view-transition-class property]
Name:

[view-transition-class]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

none
[\|](https://drafts.csswg.org/css-values-4/#comb-one)
[\<custom-ident\>](https://drafts.csswg.org/css-values-4/#identifier-value)[+](https://drafts.csswg.org/css-values-4/#mult-one-plus)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

none

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[all
elements](https://www.w3.org/TR/css-pseudo/#generated-content "Includes ::before and ::after pseudo-elements.")

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

as specified

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

The
[view-transition-class](#propdef-view-transition-class) can be used to apply the same style
rule to multiple [named view transition
pseudo-elements](#named-view-transition-pseudo-elements) which may have a different
[view-transition-name](#propdef-view-transition-name). While
[view-transition-name] is used to match between the element in the old state with
its corresponding element in the new state,
[view-transition-class] is used only to apply styles using the view transition
pseudo-elements
([::view-transition-group()](#selectordef-view-transition-group),
[::view-transition-image-pair()](#selectordef-view-transition-image-pair),
[::view-transition-old()](#selectordef-view-transition-old),
[::view-transition-new()](#selectordef-view-transition-new)).

Note that
[view-transition-class](#propdef-view-transition-class) by itself doesn't mark an element
for capturing, it is only used as an additional way to style an element
that already has a
[view-transition-name](#propdef-view-transition-name).

[none]

: No class would apply to the [named view transition
 pseudo-elements](#named-view-transition-pseudo-elements) generated for this element.

[[\<custom-ident\>](https://drafts.csswg.org/css-values-4/#identifier-value)+]

: All of the specified
 [\<custom-ident\>](https://drafts.csswg.org/css-values-4/#identifier-value) values (apart from [none])
 are applied when used in [named view transition
 pseudo-element](#named-view-transition-pseudo-elements) selectors. [none] is an invalid
 [\<custom-ident\>] for
 [view-transition-class](#propdef-view-transition-class), even when combined with
 another [\<custom-ident\>].

 Each \'view transition class\' is a [tree-scoped
 name](https://drafts.csswg.org/css-shadow-1/#css-tree-scoped-name).

 If the same
 [view-transition-name](#propdef-view-transition-name) is specified for an element
 both in the old and new states of the transition, only the
 [view-transition-class](#propdef-view-transition-class) values from the new state
 apply. This also applies for cross-document view transitions:
 classes from the old document would only apply if their
 corresponding
 [view-transition-name] was not specified in the new document.

### 10.4. Additions to named view transition pseudo-elements

The [named view transition
pseudo-elements](#named-view-transition-pseudo-elements) ([view-transition-group()],
[view-transition-image-pair()], [view-transition-old()],
[view-transition-new()]) are extended to support the following
syntax:

``` prod
::view-transition-group(<pt-name-and-class-selector>)
::view-transition-image-pair(<pt-name-and-class-selector>)
::view-transition-old(<pt-name-and-class-selector>)
::view-transition-new(<pt-name-and-class-selector>)
```

where
[\<pt-name-selector\>](#typedef-pt-name-selector) works as previously defined, and
[\<pt-name-and-class-selector\>](#typedef-pt-name-and-class-selector) has the following syntax definition:

``` prod
<pt-name-and-class-selector> = <pt-name-selector> <pt-class-selector>? | <pt-class-selector>
<pt-class-selector> = ['.' <custom-ident>]+
```

When interpreting the above grammar, white space is forbidden:

- Between
 [\<pt-name-selector\>](#typedef-pt-name-selector) and
 [\<pt-class-selector\>](#typedef-pt-class-selector)

- Between any of the components of
 [\<pt-class-selector\>](#typedef-pt-class-selector).

A [named view transition
pseudo-element](#named-view-transition-pseudo-elements)
[selector](https://drafts.csswg.org/selectors-4/#selector) which has one or more
[\<custom-ident\>](https://drafts.csswg.org/css-values-4/#identifier-value) values in its
[\<pt-class-selector\>](#typedef-pt-class-selector) would only match an element if the
[class
list](#captured-element-class-list) value in [named
elements](#viewtransition-named-elements) for the pseudo-element's
[view-transition-name](#propdef-view-transition-name)
[contains](https://infra.spec.whatwg.org/#list-contain) all of those values.

The
[specificity](https://drafts.csswg.org/selectors-4/#specificity) of a [named view transition
pseudo-element](#named-view-transition-pseudo-elements)
[selector](https://drafts.csswg.org/selectors-4/#selector) with either:

- a
 [\<pt-name-selector\>](#typedef-pt-name-selector) with a
 [\<custom-ident\>](https://drafts.csswg.org/css-values-4/#identifier-value); or

- a
 [\<pt-class-selector\>](#typedef-pt-class-selector) with at least one
 [\<custom-ident\>](https://drafts.csswg.org/css-values-4/#identifier-value),

is equivalent to a [type
selector](https://drafts.csswg.org/selectors-4/#type-selector).

The
[specificity](https://drafts.csswg.org/selectors-4/#specificity) of a [named view transition
pseudo-element](#named-view-transition-pseudo-elements)
[selector](https://drafts.csswg.org/selectors-4/#selector) with a
[\*](https://drafts.csswg.org/selectors-3/#x) argument and with an empty
[\<pt-class-selector\>](#typedef-pt-class-selector) is zero.

## 11. Determining [view-transition-name automatically]
### 11.1. Overview

*This section is non-normative.*

For an element to participate in a view transition, it needs to receive
a unique
[view-transition-name](#propdef-view-transition-name). This can be tedious and verbose
when multiple elements are involved in the same view transition,
especially in cases where many of those are same-element transitions, as
in, the element has the same
[view-transition-name] in the old and new state.

To make this easier, setting the
[view-transition-name](#propdef-view-transition-name) to [auto] would generate a
[view-transition-name] for the element, or take it from the element's
[id](https://dom.spec.whatwg.org/#concept-id) if present.

### 11.2. Examples

In this example, view transition is
used to sort a list in an animated way:

```
<ul>
 <li>Item 1</li>
 <li>Item 2</li>
 <li>Item 3</li>
 <li>Item 4</li>
 ...
</ul>
```

Ordinarily, each of these items would have to receive a unique
[view-transition-name](#propdef-view-transition-name):

```
li:nth-child(1) { view-transition-name: item1; }
li:nth-child(2) { view-transition-name: item2; }
li:nth-child(3) { view-transition-name: item3; }
li:nth-child(4) { view-transition-name: item4; }
...
```

With [auto] or [match-element], this CSS would work:

```
li {
 view-transition-name: auto;
 /* or */
 view-transition-name: match-element;
}
```

The [auto] and [match-element] keywords have a minor
difference, where [auto] would use the element's
[id](https://dom.spec.whatwg.org/#concept-id) as the
[view-transition-name](#propdef-view-transition-name) if it exists, making it potentially
work across documents, while [match-element] only matches based on
element identity.

### 11.3. Additions to [view-transition-name]
In addition to the existing values, the
[view-transition-name](#propdef-view-transition-name) also accepts an
[auto] keyword. To
resolve the [used
value](https://drafts.csswg.org/css-cascade-5/#used-value) of
[view-transition-name] for `element`:

1. Let `computed` be the [computed
 value](https://drafts.csswg.org/css-cascade-5/#computed-value) of
 [view-transition-name](#propdef-view-transition-name).

2. If `computed` is [none], return null.

3. If `computed` is a
 [\<custom-ident\>](https://drafts.csswg.org/css-values-4/#identifier-value), return `computed`.

4. Assert: `computed` is [auto] or
 [match-element].

5. If `computed` is [auto], `element` has
 an associated
 [id](https://dom.spec.whatwg.org/#concept-id), and `computed` is associated with the
 same
 [root](https://dom.spec.whatwg.org/#concept-tree-root) as `element`'s
 [root], then return a unique string
 starting with \"`-ua-`\". Two elements with the same
 [id] must return the same string, regardless
 of their [node
 document](https://dom.spec.whatwg.org/#concept-node-document).

 this means that a
 [::part()](https://drafts.csswg.org/css-shadow-1/#selectordef-part) pseudo-element wouldn't resolve to its
 matching element's
 [id](https://dom.spec.whatwg.org/#concept-id).

6. Return a unique string starting with \"`-ua-`\". The string should
 remain consistent and unique for this element and
 [`Document`](https://dom.spec.whatwg.org/#document), at least for the lifetime of
 `element`'s [node
 document](https://dom.spec.whatwg.org/#concept-node-document)'s [active view
 transition](#element-active-view-transition).

 When used in a cross-document view transition,
 generated [auto] values never match, resulting in separate
 [::view-transition-group()](#selectordef-view-transition-group) pseudo-elements, one exiting and one
 entering.

A
[view-transition-name](#propdef-view-transition-name) generated by [auto] is a
[tree-scoped
name](https://drafts.csswg.org/css-shadow-1/#css-tree-scoped-name).

## 12. Algorithms

### 12.1. Data Structures

#### [12.1.1. ][Additions to [`Document`](https://dom.spec.whatwg.org/#document)]
A
[`Document`](https://dom.spec.whatwg.org/#document) additionally has:

[active view transition]

: a
 [`ViewTransition`](#viewtransition) or null. Initially null.

[rendering suppression for view transitions]

: a boolean. Initially false.

 While a
 [`Document`](https://dom.spec.whatwg.org/#document)'s [rendering suppression for view
 transitions](#document-rendering-suppression-for-view-transitions) is true, all pointer hit testing must target its
 [document
 element](https://dom.spec.whatwg.org/#document-element), ignoring all other
 [elements](https://drafts.csswg.org/css2/#element).

 This does not affect pointers that are
 [captured](https://w3c.github.io/pointerevents/#dfn-pointer-capture).

[dynamic view transition style sheet]

: a [style
 sheet](https://drafts.csswg.org/css-2026/#style-sheet). Initially a new [style
 sheet] in the [user-agent
 origin](https://drafts.csswg.org/css-cascade-5/#cascade-origin-ua), ordered after the [global view transition user
 agent style
 sheet](#global-view-transition-user-agent-style-sheet).

 This is used to hold dynamic styles relating to
 transitions.

[update callback queue]

: A [list](https://infra.spec.whatwg.org/#list), initially empty.

[inbound view transition params]

: a [view transition
 params](#view-transition-params), or null. Initially null.

[can initiate outbound view transition]

: a boolean. Initially false.

 this value can be read [in
 parallel](https://html.spec.whatwg.org/multipage/infrastructure.html#in-parallel) while navigating.

#### 12.1.2. Additions to Elements

[Elements](https://drafts.csswg.org/css2/#element) additionally have:

[active view transition]

: a
 [`ViewTransition`](#viewtransition) or null. Initially null.

[captured in a view transition]

: a boolean. Initially false.

 This spec uses CSS's definition of
[element](https://drafts.csswg.org/css2/#element), which includes
[pseudo-elements](https://drafts.csswg.org/selectors-4/#pseudo-element).

#### 12.1.3. [Captured elements]
A [captured element] is a
[struct](https://infra.spec.whatwg.org/#struct) with the following:

[old image]

: an 2D bitmap or null. Initially null.

[old width]\
[old height]

: an
 [`unrestricted double`](https://webidl.spec.whatwg.org/#idl-unrestricted-double), initially zero.

[old transform]

: a
 [\<transform-function\>](https://drafts.csswg.org/css-transforms-2/#typedef-transform-function), initially the [identity
 transform
 function](https://drafts.csswg.org/css-transforms-1/#identity-transform-function).

[old writing-mode]

: Null or a
 [writing-mode](https://drafts.csswg.org/css-writing-modes-4/#propdef-writing-mode), initially null.

[old direction]

: Null or a
 [direction](https://drafts.csswg.org/css-writing-modes-3/#propdef-direction), initially null.

[old text-orientation]

: Null or a
 [text-orientation](https://drafts.csswg.org/css-writing-modes-4/#propdef-text-orientation), initially null.

[old mix-blend-mode]

: Null or a
 [mix-blend-mode](https://drafts.csswg.org/compositing-2/#propdef-mix-blend-mode), initially null.

[old backdrop-filter]

: Null or a
 [backdrop-filter](https://drafts.csswg.org/filter-effects-2/#propdef-backdrop-filter), initially null.

[old color-scheme]

: Null or a
 [color-scheme](https://drafts.csswg.org/css-color-adjust-1/#propdef-color-scheme), initially null.

[new element]

: an
 [element](https://drafts.csswg.org/css2/#element) or null. Initially null.

[class list]

: a [list](https://infra.spec.whatwg.org/#list) of strings, initially empty.

[containing group name]

: Null or a string, initially null.

[transform from snapshot containing block]

: A
 [matrix](https://drafts.csswg.org/geometry-1/#matrix) or null, initially null.

[old border width]

: [border-width](https://drafts.csswg.org/css-borders-4/#propdef-border-width) [used
 value](https://drafts.csswg.org/css-cascade-5/#used-value) (top, right, bottom and left pixel values) or null,
 initially null.

[duplicate]

: A boolean, initiallly false.

In addition, a [captured
element](#captured-element)
has the following [style
definitions]:

[group keyframes]

: A
 [`CSSKeyframesRule`](https://drafts.csswg.org/css-animations-1/#csskeyframesrule) or null. Initially null.

[group animation name rule]

: A
 [`CSSStyleRule`](https://drafts.csswg.org/cssom-1/#cssstylerule) or null. Initially null.

[group styles rule]

: A
 [`CSSStyleRule`](https://drafts.csswg.org/cssom-1/#cssstylerule) or null. Initially null.

[image pair isolation rule]

: A
 [`CSSStyleRule`](https://drafts.csswg.org/cssom-1/#cssstylerule) or null. Initially null.

[image animation name rule]

: A
 [`CSSStyleRule`](https://drafts.csswg.org/cssom-1/#cssstylerule) or null. Initially null.

 These are used to update, and later remove styles from
a
[document](https://dom.spec.whatwg.org/#concept-document)'s [dynamic view transition style
sheet](#document-dynamic-view-transition-style-sheet).

#### 12.1.4. Serializable [view transition params]
A [view transition params] is a
[struct](https://infra.spec.whatwg.org/#struct) whose purpose is to serialize view transition
information across documents. It has the following
[items](https://infra.spec.whatwg.org/#struct-item):

[named elements]

: a
 [map](https://infra.spec.whatwg.org/#ordered-map), whose keys are strings and whose values are
 [captured elements](#captured-element).

[initial snapshot containing block size]

: a [tuple](https://infra.spec.whatwg.org/#tuple) of two numbers (width and height).

### 12.2. [Perform pending transition operations]
This algorithm is invoked as a part of [update the rendering
loop](https://html.spec.whatwg.org/#event-loop-processing-model:perform-pending-transition-operations)
in the html spec.

To [perform pending transition
operations] given a
[`Document`](https://dom.spec.whatwg.org/#document) `document`, perform the following steps:

1. Let `transitions` be a new
 [list](https://infra.spec.whatwg.org/#list).

2. If `document`'s [active view
 transition](#document-active-view-transition) is not null,
 [append](https://infra.spec.whatwg.org/#list-append) `document`'s [active view
 transition] to
 `transitions`.

3. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `element` in `document`'s
 [flat
 tree](https://drafts.csswg.org/css-shadow-1/#flat-tree), in [tree
 order](https://dom.spec.whatwg.org/#concept-tree-order):

 1. If `element`'s [active view
 transition](#element-active-view-transition) is not null and `transitions` does
 not
 [contain](https://infra.spec.whatwg.org/#list-contain) `element`'s [active view
 transition], then
 [append](https://infra.spec.whatwg.org/#list-append) `element`'s [active view
 transition] to
 `transitions`.

4. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `transition` of
 `transitions`:

 1. If `transition`'s
 [phase](#viewtransition-phase) is \"`done`\", then
 [continue](https://infra.spec.whatwg.org/#iteration-continue).

 2. If `transition`'s
 [phase](#viewtransition-phase) is \"`pending-capture`\", then [setup view
 transition](#setup-view-transition) for `transition`.

 3. Otherwise, if `transition`'s
 [phase](#viewtransition-phase) is \"`animating`\", then [handle transition
 frame](#handle-transition-frame) for `transition`.

### 12.3. Resolving the [\@view-transition rule]
To [resolve \@view-transition rule] for a
[`Document`](https://dom.spec.whatwg.org/#document) `document`:

 this is called in both the old and new document.

1. If `document`'s [visibility
 state](https://html.spec.whatwg.org/multipage/interaction.html#visibility-state) is \"`hidden`\", then return \"`skip transition`\".

2. Let `matchingRule` be the last
 [\@view-transition](#at-view-transition-rule) rule in `document`.

3. If `matchingRule` is not found, then return
 \"`skip transition`\".

4. If `matchingRule`'s
 [navigation](#view-transition-navigation) descriptor's [computed
 value](https://drafts.csswg.org/css-cascade-5/#computed-value) is
 [none](#valdef-view-transition-navigation-none), then return \"`skip transition`\".

5. Assert: `matchingRule`'s
 [navigation](#view-transition-navigation) descriptor's [computed
 value](https://drafts.csswg.org/css-cascade-5/#computed-value) is
 [auto](#valdef-view-transition-navigation-auto).

6. Let `typesDescriptor` be `matchingRule`'s
 [types](#view-transition-types) descriptor.

7. If `typesDescriptor`'s [computed
 value](https://drafts.csswg.org/css-cascade-5/#computed-value) is [none], then return a
 [set](https://infra.spec.whatwg.org/#ordered-set) « ».

8. Return a
 [set](https://infra.spec.whatwg.org/#ordered-set) of strings corresponding to
 `typesDescriptor`'s [computed
 value](https://drafts.csswg.org/css-cascade-5/#computed-value).

### 12.4. [Setup single-document view transition]
To [setup view transition] for a
[`ViewTransition`](#viewtransition) `transition`, perform the following steps:

 This algorithm captures the current state of the
document, calls the transition's
[`ViewTransitionUpdateCallback`](#callbackdef-viewtransitionupdatecallback), then captures the new state of the document.

1. Let `document` be `transition`'s [relevant
 global
 object's](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global) [associated
 document](https://html.spec.whatwg.org/multipage/nav-history-apis.html#concept-document-window).

2. [Flush the update callback
 queue](#flush-the-update-callback-queue).

 this ensures that any changes to the DOM scheduled
 by other skipped transitions are done before the old state for this
 transition is captured.

3. [Capture the old
 state](#capture-the-old-state) for `transition`.

 If failure is returned, then [skip the view
 transition](#skip-the-view-transition) for `transition` with an
 \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) in `transition`'s [relevant
 Realm](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-realm), and return.

4. Set `document`'s [rendering suppression for view
 transitions](#document-rendering-suppression-for-view-transitions) to true.

5. [Queue a global
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-global-task) on the [DOM manipulation task
 source](https://html.spec.whatwg.org/multipage/webappapis.html#dom-manipulation-task-source), given `transition`'s [relevant global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global), to perform the following steps:

 A task is queued here because the texture read back
 in [capturing the
 image](#capture-the-image) may be async, although the render steps in the HTML
 spec act as if it's synchronous.

 1. If `transition`'s
 [phase](#viewtransition-phase) is \"`done`\", then abort these steps.

 This happens if `transition` was
 [skipped](#skip-the-view-transition) before this point.

 2. [schedule the update
 callback](#schedule-the-update-callback) for `transition`.

 3. [Flush the update callback
 queue](#flush-the-update-callback-queue).

To [activate view transition] for a
[`ViewTransition`](#viewtransition) `transition`, perform the following steps:

1. If `transition`'s
 [phase](#viewtransition-phase) is \"`done`\", then return.

 This happens if `transition` was
 [skipped](#skip-the-view-transition) before this point.

2. Set `transition`'s [relevant global
 object's](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global) [associated
 document](https://html.spec.whatwg.org/multipage/nav-history-apis.html#concept-document-window)'s [rendering suppression for view
 transitions](#document-rendering-suppression-for-view-transitions) to false.

3. If `transition`'s [initial snapshot containing block
 size](#viewtransition-initial-snapshot-containing-block-size) is not equal to the [snapshot containing block
 size](#snapshot-containing-block-size), then
 [skip](#skip-the-view-transition) `transition` with an
 \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) in `transition`'s [relevant
 Realm](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-realm), and return.

4. [Capture the new
 state](#capture-the-new-state) for `transition`.

 If failure is returned, then
 [skip](#skip-the-view-transition) `transition` with an
 \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) in `transition`'s [relevant
 Realm](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-realm), and return.

5. [Remove](https://infra.spec.whatwg.org/#list-remove) from `transition`'s [named
 elements](#viewtransition-named-elements) every entry whose value's
 [duplicate](#captured-element-duplicate) is true.

 User agents are encouraged to alert the developer
 that the duplicate was removed, e.g. via a console warning.

6. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `capturedElement` of
 `transition`'s [named
 elements](#viewtransition-named-elements)\'
 [values](https://infra.spec.whatwg.org/#map-getting-the-values):

 1. If `capturedElement`'s [new
 element](#captured-element-new-element) is not null, then set
 `capturedElement`'s [new
 element]'s [captured in
 a view
 transition](#element-captured-in-a-view-transition) to true.

7. [Setup transition
 pseudo-elements](#setup-transition-pseudo-elements) for `transition`.

8. [Update pseudo-element
 styles](#update-pseudo-element-styles) for `transition`.

 If failure is returned, then [skip the view
 transition](#skip-the-view-transition) for `transition` with an
 \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) in `transition`'s [relevant
 Realm](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-realm), and return.

 The above steps will require running document
 lifecycle phases, to compute information calculated during
 style/layout.

9. Set `transition`'s
 [phase](#viewtransition-phase) to \"`animating`\".

10. [Resolve](https://webidl.spec.whatwg.org/#resolve) `transition`'s [ready
 promise](#viewtransition-ready-promise).

#### 12.4.1. [Capture the old state]
To [capture the old state] for
[`ViewTransition`](#viewtransition) `transition`:

1. Let `document` be `transition`'s [relevant
 global
 object's](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global) [associated
 document](https://html.spec.whatwg.org/multipage/nav-history-apis.html#concept-document-window).

2. Let `namedElements` be `transition`'s [named
 elements](#viewtransition-named-elements).

3. Let `captureElements` be a new
 [list](https://infra.spec.whatwg.org/#list) of elements.

4. If the [snapshot containing block
 size](#snapshot-containing-block-size) exceeds an
 [implementation-defined](https://infra.spec.whatwg.org/#implementation-defined) maximum, then return failure.

5. Set `transition`'s [initial snapshot containing block
 size](#viewtransition-initial-snapshot-containing-block-size) to the [snapshot containing block
 size](#snapshot-containing-block-size).

6. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `element` of every
 [element](https://drafts.csswg.org/css2/#element) that is
 [connected](https://dom.spec.whatwg.org/#connected), and has a [node
 document](https://dom.spec.whatwg.org/#concept-node-document) equal to `document`, in [paint
 order](https://drafts.csswg.org/css2/#painting-order):

 We iterate in paint order to ensure that this order
 is cached in `namedElements`. This defines the DOM order
 for ::view-transition-group pseudo-elements, such that the element
 at the bottom of the paint stack generates the first pseudo child of
 ::view-transition.

 1. If any [flat
 tree](https://drafts.csswg.org/css-shadow-1/#flat-tree) ancestor of this `element` [skips
 its
 contents](https://drafts.csswg.org/css-contain-2/#skips-its-contents), then
 [continue](https://infra.spec.whatwg.org/#iteration-continue).

 2. If any [flat
 tree](https://drafts.csswg.org/css-shadow-1/#flat-tree) [inclusive
 ancestor](https://dom.spec.whatwg.org/#concept-tree-inclusive-ancestor) of this `element`, up to but not
 including `transition`'s [root
 element](#viewtransition-root-element), has [view-transition-scope:
 all](#propdef-view-transition-scope),
 [continue](https://infra.spec.whatwg.org/#iteration-continue).

 3. If `element` has more than one [box
 fragment](https://drafts.csswg.org/css-break-4/#box-fragment), then
 [continue](https://infra.spec.whatwg.org/#iteration-continue).

 We might want to enable transitions for
 fragmented elements in future versions. See
 [#8900](https://github.com/w3c/csswg-drafts/issues/8900).

 [box
 fragment](https://drafts.csswg.org/css-break-4/#box-fragment) here does not refer to fragmentation of [inline
 boxes](https://www.w3.org/TR/CSS2/visuren.html#inline-boxes)
 across [line
 boxes](https://www.w3.org/TR/CSS2/visuren.html#line-box). Such
 inlines can participate in a transition.

 4. Let `transitionName` be the `element`'s
 [document-scoped view transition
 name](#document-scoped-view-transition-name).

 5. If `transitionName` is
 [none](#valdef-view-transition-name-none), or `element` is [not
 rendered](https://drafts.csswg.org/css-images-4/#element-not-rendered), then
 [continue](https://infra.spec.whatwg.org/#iteration-continue).

 6. If `namedElements`\[`transitionName`\]
 exists, then set
 `namedElements`\[`transitionName`\]\'s
 [duplicate](#captured-element-duplicate) to true and
 [continue](https://infra.spec.whatwg.org/#iteration-continue).

 7. If *any other* [active view
 transition](#document-active-view-transition) contains `element` in its [captured
 elements](#captured-element), then for each such [active view
 transition](#element-active-view-transition), in [tree
 order](https://dom.spec.whatwg.org/#concept-tree-order) of their corresponding [root
 elements](#viewtransition-root-element),
 [skip](#skip-the-view-transition) that view transition with an
 \"[`AbortError`](https://webidl.spec.whatwg.org/#aborterror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) in `document`'s [relevant
 Realm](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-realm).

 8. Set `element`'s [captured in a view
 transition](#element-captured-in-a-view-transition) to true.

 9. [Append](https://infra.spec.whatwg.org/#list-append) `element` to
 `captureElements`.

 :::
 The algorithm continues in a separate loop to ensure that [captured
 in a view
 transition](#element-captured-in-a-view-transition) is set on all elements participating in this
 capture before it is read by future steps in the algorithm.
 :::

7. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `element` in
 `captureElements`:

 1. Let `capture` be a new [captured
 element](#captured-element) struct.

 2. Set `capture`'s [old
 image](#captured-element-old-image) to the result of [capturing the
 image](#capture-the-image) of `element`.

 3. Let `originalRect` be [snapshot containing
 block](#snapshot-containing-block) if `element` is the [document
 element](https://dom.spec.whatwg.org/#document-element), otherwise, the `element`'s [border
 box](https://drafts.csswg.org/css-box-4/#border-box).

 4. Set `capture`'s [old
 width](#captured-element-old-width) to `originalRect`'s
 [`width`](https://drafts.csswg.org/geometry-1/#dom-domrect-width).

 5. Set `capture`'s [old
 height](#captured-element-old-height) to `originalRect`'s
 [`height`](https://drafts.csswg.org/geometry-1/#dom-domrect-height).

 6. Set `capture`'s [old
 transform](#captured-element-old-transform) to a
 [\<transform-function\>](https://drafts.csswg.org/css-transforms-2/#typedef-transform-function) that would map
 `element`'s [border
 box](https://drafts.csswg.org/css-box-4/#border-box) from the [snapshot containing block
 origin](#snapshot-containing-block-origin) to its current visual position.

 7. Set `capture`'s [old
 writing-mode](#captured-element-old-writing-mode) to the [computed
 value](https://drafts.csswg.org/css-cascade-5/#computed-value) of
 [writing-mode](https://drafts.csswg.org/css-writing-modes-4/#propdef-writing-mode) on `element`.

 8. Set `capture`'s [old
 direction](#captured-element-old-direction) to the [computed
 value](https://drafts.csswg.org/css-cascade-5/#computed-value) of
 [direction](https://drafts.csswg.org/css-writing-modes-3/#propdef-direction) on `element`.

 9. Set `capture`'s [old
 text-orientation](#captured-element-old-text-orientation) to the [computed
 value](https://drafts.csswg.org/css-cascade-5/#computed-value) of
 [text-orientation](https://drafts.csswg.org/css-writing-modes-4/#propdef-text-orientation) on `element`.

 10. Set `capture`'s [old
 mix-blend-mode](#captured-element-old-mix-blend-mode) to the [computed
 value](https://drafts.csswg.org/css-cascade-5/#computed-value) of
 [mix-blend-mode](https://drafts.csswg.org/compositing-2/#propdef-mix-blend-mode) on `element`.

 11. Set `capture`'s [old
 backdrop-filter](#captured-element-old-backdrop-filter) to the [computed
 value](https://drafts.csswg.org/css-cascade-5/#computed-value) of
 [backdrop-filter](https://drafts.csswg.org/filter-effects-2/#propdef-backdrop-filter) on `element`.

 12. Set `capture`'s [old
 color-scheme](#captured-element-old-color-scheme) to the [computed
 value](https://drafts.csswg.org/css-cascade-5/#computed-value) of
 [color-scheme](https://drafts.csswg.org/css-color-adjust-1/#propdef-color-scheme) on `element`.

 13. Let `transitionName` be the [computed
 value](https://drafts.csswg.org/css-cascade-5/#computed-value) of
 [view-transition-name](#propdef-view-transition-name) for `element`.

 14. Set `namedElements`\[`transitionName`\] to
 `capture`.

8. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `element` in
 `captureElements`:

 1. Set `element`'s [captured in a view
 transition](#element-captured-in-a-view-transition) to false.

#### 12.4.2. [Capture the new state]
To [capture the new state] for
[`ViewTransition`](#viewtransition) `transition`:

1. Let `document` be `transition`'s [relevant
 global
 object's](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global) [associated
 document](https://html.spec.whatwg.org/multipage/nav-history-apis.html#concept-document-window).

2. Let `namedElements` be `transition`'s [named
 elements](#viewtransition-named-elements).

3. Let `usedTransitionNames` be a new
 [set](https://infra.spec.whatwg.org/#ordered-set) of strings.

4. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `element` of every
 [element](https://drafts.csswg.org/css2/#element) that is
 [connected](https://dom.spec.whatwg.org/#connected), and has a [node
 document](https://dom.spec.whatwg.org/#concept-node-document) equal to `document`, in [paint
 order](https://drafts.csswg.org/css2/#painting-order):

 1. If any [flat
 tree](https://drafts.csswg.org/css-shadow-1/#flat-tree) ancestor of this `element` [skips
 its
 contents](https://drafts.csswg.org/css-contain-2/#skips-its-contents), then
 [continue](https://infra.spec.whatwg.org/#iteration-continue).

 2. Let `transitionName` be `element`'s
 [document-scoped view transition
 name](#document-scoped-view-transition-name).

 3. If `transitionName` is
 [none](#valdef-view-transition-name-none), or `element` is [not
 rendered](https://drafts.csswg.org/css-images-4/#element-not-rendered), then
 [continue](https://infra.spec.whatwg.org/#iteration-continue).

 4. If `element` has more than one [box
 fragment](https://drafts.csswg.org/css-break-4/#box-fragment), then
 [continue](https://infra.spec.whatwg.org/#iteration-continue).

 5. If `usedTransitionNames`
 [contains](https://infra.spec.whatwg.org/#list-contain) `transitionName`, then return
 failure.

 6. [Append](https://infra.spec.whatwg.org/#set-append) `transitionName` to
 `usedTransitionNames`.

 7. If `namedElements`\[`transitionName`\]
 does not
 [exist](https://infra.spec.whatwg.org/#map-exists), then set
 `namedElements`\[`transitionName`\] to a
 new [captured
 element](#captured-element) struct.

 We intentionally add this struct to the end of
 this ordered map. This implies than names which only exist in
 the new DOM (entry animations) will be painted on top of names
 only in the old DOM (exit animations) and names in both DOMs
 (paired animations). This might not be the right layering for
 all cases. See [issue
 8941](https://github.com/w3c/csswg-drafts/issues/8941).

 8. If `namedElements`\[`transitionName`\]\'s
 [new
 element](#captured-element-new-element) is not null, then set
 `namedElements`\[`transitionName`\]\'s
 [duplicate](#captured-element-duplicate) to true.

 9. Set `namedElements`\[`transitionName`\]\'s
 [new
 element](#captured-element-new-element) to `element`.

#### 12.4.3. [Setup transition pseudo-elements]
To [setup transition pseudo-elements] for a
[`ViewTransition`](#viewtransition) `transition`:

 This algorithm constructs the pseudo-element tree for
the transition, and generates initial styles. The structure of the
pseudo-tree is covered at a higher level in [§ 5.2 View Transition
Pseudo-elements](#view-transition-pseudos).

1. Let `document` be `transition`'s [relevant
 global
 object's](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global) [associated
 document](https://html.spec.whatwg.org/multipage/nav-history-apis.html#concept-document-window).

2. [For
 each](https://infra.spec.whatwg.org/#map-iterate) `transitionName` →
 `capturedElement` of `transition`'s [named
 elements](#viewtransition-named-elements):

 1. Let `group` be a new
 [::view-transition-group()](#selectordef-view-transition-group), with its [view transition
 name](#view-transition-name) set to `transitionName`.

 2. Append `group` to the
 [::view-transition](#selectordef-view-transition)
 [pseudo-element](https://drafts.csswg.org/selectors-4/#pseudo-element) on `transition`'s [root
 element](#viewtransition-root-element).

 3. Let `imagePair` be a new
 [::view-transition-image-pair()](#selectordef-view-transition-image-pair), with its [view transition
 name](#view-transition-name) set to `transitionName`.

 4. Append `imagePair` to `group`.

 5. If `capturedElement`'s [old
 image](#captured-element-old-image) is not null, then:

 1. Let `old` be a new
 [::view-transition-old()](#selectordef-view-transition-old), with its [view transition
 name](#view-transition-name) set to `transitionName`,
 displaying `capturedElement`'s [old
 image](#captured-element-old-image) as its
 [replaced](https://drafts.csswg.org/css-display-4/#replaced-element) content.

 2. Append `old` to `imagePair`.

 6. If `capturedElement`'s [new
 element](#captured-element-new-element) is not null, then:

 1. Let `new` be a new
 [::view-transition-new()](#selectordef-view-transition-new), with its [view transition
 name](#view-transition-name) set to `transitionName`.

 The styling of this pseudo is handled in
 [update pseudo-element
 styles](#update-pseudo-element-styles).

 2. Append `new` to `imagePair`.

 7. If `capturedElement`'s [old
 image](#captured-element-old-image) is null, then:

 1. [Assert](https://infra.spec.whatwg.org/#assert): `capturedElement`'s [new
 element](#captured-element-new-element) is not null.

 2. Set `capturedElement`'s [image animation name
 rule](#captured-element-image-animation-name-rule) to a new
 [`CSSStyleRule`](https://drafts.csswg.org/cssom-1/#cssstylerule) representing the following CSS, and append
 it to `document`'s [dynamic view transition style
 sheet](#document-dynamic-view-transition-style-sheet):

 ``` highlight
 :root::view-transition-new(transitionName) {
 animation-name: -ua-view-transition-fade-in;
 }
 ```

 The above code example contains variables
 to be replaced.

 8. If `capturedElement`'s [new
 element](#captured-element-new-element) is null, then:

 1. [Assert](https://infra.spec.whatwg.org/#assert): `capturedElement`'s [old
 image](#captured-element-old-image) is not null.

 2. Set `capturedElement`'s [image animation name
 rule](#captured-element-image-animation-name-rule) to a new
 [`CSSStyleRule`](https://drafts.csswg.org/cssom-1/#cssstylerule) representing the following CSS, and append
 it to `document`'s [dynamic view transition style
 sheet](#document-dynamic-view-transition-style-sheet):

 ``` highlight
 :root::view-transition-old(transitionName) {
 animation-name: -ua-view-transition-fade-out;
 }
 ```

 The above code example contains variables
 to be replaced.

 9. If both of `capturedElement`'s [old
 image](#captured-element-old-image) and [new
 element](#captured-element-new-element) are not null, then:

 1. Let `transform` be `capturedElement`'s
 [old
 transform](#captured-element-old-transform).

 2. Let `width` be `capturedElement`'s
 [old
 width](#captured-element-old-width).

 3. Let `height` be `capturedElement`'s
 [old
 height](#captured-element-old-height).

 4. Let `backdropFilter` be
 `capturedElement`'s [old
 backdrop-filter](#captured-element-old-backdrop-filter).

 5. Set `capturedElement`'s [group
 keyframes](#captured-element-group-keyframes) to a new
 [`CSSKeyframesRule`](https://drafts.csswg.org/css-animations-1/#csskeyframesrule) representing the following CSS, and append
 it to `document`'s [dynamic view transition style
 sheet](#document-dynamic-view-transition-style-sheet):

 ``` highlight
 @keyframes -ua-view-transition-group-anim-transitionName {
 from {
 transform: transform;
 width: width;
 height: height;
 backdrop-filter: backdropFilter;
 }
 }
 ```

 The above code example contains variables
 to be replaced.

 6. Set `capturedElement`'s [group animation name
 rule](#captured-element-group-animation-name-rule) to a new
 [`CSSStyleRule`](https://drafts.csswg.org/cssom-1/#cssstylerule) representing the following CSS, and append
 it to `document`'s [dynamic view transition style
 sheet](#document-dynamic-view-transition-style-sheet):

 ``` highlight
 :root::view-transition-group(transitionName) {
 animation-name: -ua-view-transition-group-anim-transitionName;
 }
 ```

 The above code example contains variables
 to be replaced.

 7. Set `capturedElement`'s [image pair isolation
 rule](#captured-element-image-pair-isolation-rule) to a new
 [`CSSStyleRule`](https://drafts.csswg.org/cssom-1/#cssstylerule) representing the following CSS, and append
 it to `document`'s [dynamic view transition style
 sheet](#document-dynamic-view-transition-style-sheet):

 ``` highlight
 :root::view-transition-image-pair(transitionName) {
 isolation: isolate;
 }
 ```

 The above code example contains variables
 to be replaced.

 8. Set `capturedElement`'s [image animation name
 rule](#captured-element-image-animation-name-rule) to a new
 [`CSSStyleRule`](https://drafts.csswg.org/cssom-1/#cssstylerule) representing the following CSS, and append
 it to `document`'s [dynamic view transition style
 sheet](#document-dynamic-view-transition-style-sheet):

 ``` highlight
 :root::view-transition-old(transitionName) {
 animation-name: -ua-view-transition-fade-out, -ua-mix-blend-mode-plus-lighter;
 }
 :root::view-transition-new(transitionName) {
 animation-name: -ua-view-transition-fade-in, -ua-mix-blend-mode-plus-lighter;
 }
 ```

 The above code example contains variables
 to be replaced.

 [mix-blend-mode:
 plus-lighter](https://drafts.csswg.org/compositing-2/#propdef-mix-blend-mode) ensures that the blending of
 identical pixels from the old and new images results in the
 same color value as those pixels, and achieves a "correct"
 cross-fade.

### 12.5. Setup cross-document view transition

#### [12.5.1. ][Setting up the view transition in the old [`Document`](https://dom.spec.whatwg.org/#document)]
##### 12.5.1.1. Check eligibility for outbound cross-document view transition

To check if a [navigation can trigger a cross-document
view-transition?] given a
[`Document`](https://dom.spec.whatwg.org/#document) `oldDocument`, a
[`Document`](https://dom.spec.whatwg.org/#document) `newDocument`, a
[`NavigationType`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#navigationtype) `navigationType`, and a boolean
`isBrowserUINavigation`:

 this is called during navigation, potentially [in
parallel](https://html.spec.whatwg.org/multipage/infrastructure.html#in-parallel).

1. If the user agent decides to display an
 [implementation-defined](https://infra.spec.whatwg.org/#implementation-defined) navigation experience, e.g. a gesture-based
 transition for a back navigation, the user agent may ignore the
 author-defined view transition. If that is the case, return false.

2. If `oldDocument`'s [can initiate outbound view
 transition](#document-can-initiate-outbound-view-transition) is false, then return false.

3. If `navigationType` is
 [`reload`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#dom-navigationtype-reload), then return false.

4. If `oldDocument`'s
 [origin](https://dom.spec.whatwg.org/#concept-document-origin) is not [same
 origin](https://html.spec.whatwg.org/multipage/browsers.html#same-origin) as `newDocument`'s
 [origin], then return false.

5. If `newDocument` [was created via cross-origin
 redirects](https://html.spec.whatwg.org/multipage/dom.html#was-created-via-cross-origin-redirects) and `newDocument`'s [latest
 entry](https://html.spec.whatwg.org/multipage/browsing-the-web.html#latest-entry) is null, then return false.

 A
 [Document](https://dom.spec.whatwg.org/#concept-document)'s [latest
 entry](https://html.spec.whatwg.org/multipage/browsing-the-web.html#latest-entry) would be null if this is a new navigation, rather
 than a restore from BFCache.

6. If `navigationType` is
 [`traverse`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#dom-navigationtype-traverse), then return true.

7. If `isBrowserUINavigation` is true, then return false.

8. Return true.

##### 12.5.1.2. Setup the outbound transition when ready to swap pages

To [setup cross-document
view-transition] given a
[`Document`](https://dom.spec.whatwg.org/#document) `oldDocument`, a
[`Document`](https://dom.spec.whatwg.org/#document) `newDocument`, and
`proceedWithNavigation`, which is an algorithm accepting
nothing:

 This is called from the HTML spec.

1. [Assert](https://infra.spec.whatwg.org/#assert): These steps are running as part of a
 [task](https://html.spec.whatwg.org/multipage/webappapis.html#concept-task) queued on `oldDocument`.

2. If `oldDocument`'s [can initiate outbound view
 transition](#document-can-initiate-outbound-view-transition) is false, then return null.

3. Let `transitionTypesFromRule` be the result of [resolving
 the \@view-transition
 rule](#resolve-view-transition-rule) for `oldDocument`.

4. [Assert](https://infra.spec.whatwg.org/#assert): `transitionTypesFromRule` is not
 \"`skip transition`\".

 We don't know yet if `newDocument` has
 opted in, as it might not be parsed yet. We check the opt-in for
 `newDocument` when we fire the
 [`pagereveal`](https://html.spec.whatwg.org/multipage/indices.html#event-pagereveal) event.

5. If `oldDocument`'s [active view
 transition](#element-active-view-transition) is not null, then
 [skip](#skip-the-view-transition) `oldDocument`'s [active view
 transition] with an
 \"[`AbortError`](https://webidl.spec.whatwg.org/#aborterror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) in `oldDocument`'s [relevant
 Realm](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-realm).

 this means that any running transition would be
 skipped when the document is ready to unload.

6. Let `outboundTransition` be a new
 [`ViewTransition`](#viewtransition) object in `oldDocument`'s [relevant
 Realm](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-realm).

7. Set `outboundTransition`'s [active
 types](#viewtransition-active-types) to `transitionTypesFromRule`.

 the [active
 types](#viewtransition-active-types) are not shared between documents. Manipulating the
 [`types`](#dom-viewtransition-types) in the old document does not affect the types in
 `newDocument`, which would be read from the
 [types](#view-transition-types) descriptor once `newDocument` is
 revealed.

 the
 [`ViewTransition`](#viewtransition) is skipped once the old document is hidden.

8. Set `outboundTransition`'s [outbound post-capture
 steps](#viewtransition-outbound-post-capture-steps) to the following steps given a [view transition
 params](#view-transition-params)-or-null `params`:

 1. Set `newDocument`'s [inbound view transition
 params](#document-inbound-view-transition-params) to `params`.

 The inbound transition is activated after the
 dispatch of
 [`pagereveal`](https://html.spec.whatwg.org/multipage/indices.html#event-pagereveal) to ensure mutations made in this event apply to
 the captured new state.

 2. To skip the transition after a timeout, the user agent may
 perform the following steps [in
 parallel](https://html.spec.whatwg.org/multipage/infrastructure.html#in-parallel):

 1. Wait for an
 [implementation-defined](https://infra.spec.whatwg.org/#implementation-defined)
 [duration](https://w3c.github.io/hr-time/#dfn-duration).

 2. [Queue a global
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-global-task) on the [DOM manipulation task
 source](https://html.spec.whatwg.org/multipage/webappapis.html#dom-manipulation-task-source) given `newDocument`'s [relevant
 global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global) to perform the following step:

 1. If `newDocument`'s [inbound view transition
 params](#document-inbound-view-transition-params) is `params`, then set
 `newDocument`'s [inbound view transition
 params]
 to null.

 3. Call `proceedWithNavigation`.

9. Set `oldDocument`'s [active view
 transition](#element-active-view-transition) to `outboundTransition`.

 The process continues in [perform pending
 transition
 operations](#perform-pending-transition-operations).

10. The user agent should display the currently displayed frame until
 either:

 - The
 [`pagereveal`](https://html.spec.whatwg.org/multipage/indices.html#event-pagereveal) event is fired.

 - its [active view
 transition](#document-active-view-transition)'s
 [phase](#viewtransition-phase) is \"`done`\".

 this is to ensure that there are no unintended
 flashes between displaying the old and new state, to keep the
 transition smooth.

11. Return `outboundTransition`.

##### 12.5.1.3. Update the opt-in flag to reflect the current state

To [update the opt-in state for outbound
transitions] for a
[`Document`](https://dom.spec.whatwg.org/#document) `document`:

1. If `document` [has been
 revealed](https://html.spec.whatwg.org/multipage/browsing-the-web.html#has-been-revealed), and the result of [resolving the \@view-transition
 rule](#resolve-view-transition-rule) is not \"`skip transition`\", then set
 `document`'s [can initiate outbound view
 transition](#document-can-initiate-outbound-view-transition) to true.

2. Otherwise, set `document`'s [can initiate outbound view
 transition](#document-can-initiate-outbound-view-transition) to false.

##### 12.5.1.4. Proceed with navigation if view transition is skipped

Append the following steps to [skip the view
transition](#skip-the-view-transition) given a
[`ViewTransition`](#viewtransition) `transition`:

1. If `transition`'s [outbound post-capture
 steps](#viewtransition-outbound-post-capture-steps) is not null, then run `transition`'s
 [outbound post-capture
 steps] with
 null.

 This is written in a monkey-patch manner, and will be
merged into the algorithm once the L1 spec graduates.

##### 12.5.1.5. Proceed with cross-document view transition after capturing the old state

Prepend the following step to the [Perform pending transition
operations](#perform-pending-transition-operations) algorithm given a
[`Document`](https://dom.spec.whatwg.org/#document) `document`:

1. If `document`'s [active view
 transition](#element-active-view-transition) is not null and its [outbound post-capture
 steps](#viewtransition-outbound-post-capture-steps) is not null, then:

 1. Assert: `document`'s [active view
 transition](#element-active-view-transition)'s
 [phase](#viewtransition-phase) is \"`pending-capture`\".

 2. Let `viewTransitionParams` be null;

 3. Set `document`'s [rendering suppression for view
 transitions](#document-rendering-suppression-for-view-transitions) to true.

 (#issue-ca114a78) Though [capture the old
 state](#capture-the-old-state) appears here as a synchronous step, it is in
 fact an asynchronous step as rendering an element into an image
 cannot be done synchronously. This should be more explicit in
 the L1 spec.

 4. [Capture the old
 state](#capture-the-old-state) for `transition`.

 5. If this succeeded, then set `viewTransitionParams` to
 a new [view transition
 params](#view-transition-params) whose [named
 elements](#view-transition-params-named-elements) is a
 [clone](https://infra.spec.whatwg.org/#map-clone) of `transition`'s [named
 elements](#viewtransition-named-elements), and whose [initial snapshot containing block
 size](#view-transition-params-initial-snapshot-containing-block-size) is `transition`'s [initial snapshot
 containing block
 size](#viewtransition-initial-snapshot-containing-block-size).

 6. Set `document`'s [rendering suppression for view
 transitions](#document-rendering-suppression-for-view-transitions) to false.

 7. Call `transition`'s [outbound post-capture
 steps](#viewtransition-outbound-post-capture-steps) given `viewTransitionParams`.

 This is written in a monkey-patch manner, and will be
merged into the algorithm once the L1 spec graduates.

#### [12.5.2. ][Activating the view transition in the new [`Document`](https://dom.spec.whatwg.org/#document)]
To [resolve inbound cross-document
view-transition] for
[`Document`](https://dom.spec.whatwg.org/#document) `document`:

1. [Assert](https://infra.spec.whatwg.org/#assert): `document` is [fully
 active](https://html.spec.whatwg.org/multipage/document-sequences.html#fully-active).

2. [Assert](https://infra.spec.whatwg.org/#assert): `document` [has been
 revealed](https://html.spec.whatwg.org/multipage/browsing-the-web.html#has-been-revealed) is true.

3. [Update the opt-in state for outbound
 transitions](#update-the-opt-in-state-for-outbound-transitions) for `document`.

4. Let `inboundViewTransitionParams` be
 `document`'s [inbound view transition
 params](#document-inbound-view-transition-params).

5. If `inboundViewTransitionParams` is null, then return
 null.

6. Set `document`'s [inbound view transition
 params](#document-inbound-view-transition-params) to null.

7. If `document`'s [active view
 transition](#document-active-view-transition) is not null, then return null.

 this means that starting a same-document transition
 before revealing the document would cancel a pending cross-document
 transition.

8. [Resolve \@view-transition
 rule](#resolve-view-transition-rule) for `document` and let
 `resolvedRule` be the result.

9. If `resolvedRule` is \"`skip transition`\", then return
 null.

10. Let `transition` be a new
 [`ViewTransition`](#viewtransition) in `document`'s [relevant
 Realm](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-realm), whose [named
 elements](#viewtransition-named-elements) is `inboundViewTransitionParams`'s
 [named
 elements](#view-transition-params-named-elements), and [initial snapshot containing block
 size](#viewtransition-initial-snapshot-containing-block-size) is `inboundViewTransitionParams`'s
 [initial snapshot containing block
 size](#view-transition-params-initial-snapshot-containing-block-size).

11. Set `document`'s [active view
 transition](#document-active-view-transition) to `transition`.

12. [Resolve](https://webidl.spec.whatwg.org/#resolve) `transition`'s [update callback done
 promise](#viewtransition-update-callback-done-promise) with undefined.

13. Set `transition`'s
 [phase](#viewtransition-phase) to \"`update-callback-called`\".

14. Set `transition`'s [active
 types](#viewtransition-active-types) to `resolvedRule`.

15. Return `transition`.

#### 12.5.3. Capturing the [view-transition-class]
When capturing the old or new state for an element, perform the
following steps given a [captured
element](#captured-element)
`capture` and an
[element](https://drafts.csswg.org/css2/#element) `element`:

1. Set `capture`'s [class
 list](#captured-element-class-list) to the [computed
 value](https://drafts.csswg.org/css-cascade-5/#computed-value) of `element`'s
 [view-transition-class](#propdef-view-transition-class), if it is associated with
 `element`'s [node
 document](https://dom.spec.whatwg.org/#concept-node-document).

 This is written in a monkey-patch manner, and will be
merged into the algorithm once the L1 spec graduates.

#### 12.5.4. Capturing and applying [view-transition-group]
##### 12.5.4.1. Resolving the [view-transition-group value]
To get the [document-scoped view transition
group] of an
[`Element`](https://dom.spec.whatwg.org/#element) `element`, perform the following steps:

1. Let `computedGroup` be the [computed
 value](https://drafts.csswg.org/css-cascade-5/#computed-value) of element's
 [view-transition-group](#propdef-view-transition-group) property.

2. If `computedGroup` is associated with
 `element`'s [node
 document](https://dom.spec.whatwg.org/#concept-node-document), return `computedGroup`.

3. Return
 [normal](#valdef-view-transition-group-normal).

##### 12.5.4.2. Resolving the containing group name

To resolve the [nearest containing group
name] of an
[`Element`](https://dom.spec.whatwg.org/#element) `element`, perform the following steps given
a [`ViewTransition`](#viewtransition) `viewTransition`:

1. Assert: `element` participates in
 `viewTransition`.

2. Let `ancestorGroup` be `element`'s nearest
 [flat
 tree](https://drafts.csswg.org/css-shadow-1/#flat-tree)
 [ancestor](https://dom.spec.whatwg.org/#concept-tree-ancestor) who participates in `viewTransition` and
 whose [document-scoped view transition
 group](#document-scoped-view-transition-group) is not
 [normal](#valdef-view-transition-group-normal).

3. If `ancestorGroup` exists, return
 `ancestorGroup`'s [document-scoped view transition
 name](#document-scoped-view-transition-name).

4. Return
 [none](#valdef-view-transition-name-none).

##### 12.5.4.3. Resolving the group name

To resolve the [used group name] of an
[`Element`](https://dom.spec.whatwg.org/#element) `element`, perform the following steps given
a [`ViewTransition`](#viewtransition) `transition`:

1. Assert: `element` participates in
 `transition`.

2. Let `group` be `element`'s [document-scoped
 view transition
 group](#document-scoped-view-transition-group).

3. Let `containingGroupName` be `element`'s
 [nearest containing group
 name](#nearest-containing-group-name) given `transition`.

4. Return the first matching statement, switching on
 `group`:

 - [normal](#valdef-view-transition-group-normal),
 [contain](#valdef-view-transition-group-contain): `containingGroupName`. Note:
 an element with
 [contain]
 becomes the [nearest containing group
 name](#nearest-containing-group-name) for its descendants.

 - [nearest](#valdef-view-transition-group-nearest): The [document-scoped view transition
 name](#document-scoped-view-transition-name) of the element's nearest [flat
 tree](https://drafts.csswg.org/css-shadow-1/#flat-tree) ancestor which participates in the
 `transition`.

 - [\<custom-ident\>](#valdef-view-transition-group-custom-ident): `group` if the element has a
 [flat
 tree](https://drafts.csswg.org/css-shadow-1/#flat-tree)
 [ancestor](https://dom.spec.whatwg.org/#concept-tree-ancestor) whose [document-scoped view transition
 name](#document-scoped-view-transition-name) is `group` and participates in
 `transition`; Otherwise
 `containingGroupName`.

##### 12.5.4.4. Compute the old [view-transition-group]
When [capturing the old state for an
element](https://drafts.csswg.org/css-view-transitions-1/#capture-old-state-algorithm),
perform the following steps given a [captured
element](#captured-element)
`capturedElement`, a
[`ViewTransition`](#viewtransition) `transition`, and an
[element](https://drafts.csswg.org/css2/#element) `element`:

1. Set `capturedElement`'s [containing group
 name](#captured-element-containing-group-name) to `element`'s [used group
 name](#used-group-name)
 given `transition`.

2. Set `capturedElement`'s [old border
 width](#captured-element-old-border-width) to `element`'s
 [used](https://drafts.csswg.org/css-cascade-5/#used-value)
 [border-width](https://drafts.csswg.org/css-borders-4/#propdef-border-width).

##### 12.5.4.5. Compute the new [view-transition-group]
When [capturing the new state for an
element](https://drafts.csswg.org/css-view-transitions-1/#capture-new-state-algorithm),
perform the following steps given a [captured
element](#captured-element)
`capturedElement` a
[`ViewTransition`](#viewtransition) `transition`, and an
[element](https://drafts.csswg.org/css2/#element) `element`:

1. Set `capturedElement`'s [containing group
 name](#captured-element-containing-group-name) to `element`'s [used group
 name](#used-group-name)
 given `transition`.

##### 12.5.4.6. Reparent a [::view-transition-group() to its specified containing group]
When [setting up the transition
pseudo-element](https://drafts.csswg.org/css-view-transitions-1/#setup-transition-pseudo-elements-algorithm)
for a [captured element](#captured-element) `capturedElement`, given a
`transitionName` and a `transition`:

1. Let `containingGroupName` be
 `capturedElement`'s [containing group
 name](#captured-element-containing-group-name).

2. If `containingGroupName` is null, return.

3. Let `groupContainerElement` be `transition`'s
 [named
 elements](#viewtransition-named-elements)\[`containingGroupName`\].

4. Let `group` be the
 [::view-transition-group()](#selectordef-view-transition-group), whose [view transition
 name](#view-transition-name) is set to `transitionName`.

5. Let `childrenContainerGroup` be the
 [::view-transition-group-children()](#selectordef-view-transition-group-children) whose [view transition
 name](#view-transition-name) is set to `containingGroupName`.

6. If `childrenContainerGroup` does not exist: Generate it
 and append to the
 [::view-transition-group()](#selectordef-view-transition-group), whose [view transition
 name](#view-transition-name) is set to `containingGroupName`.

7. Append `group` to `childrenContainerGroup`.

8. When setting the animation keyframes given `transform`,
 [adjust](#adjust-nested-view-transition-group-transform) `transform` given
 `groupContainerElement`.

 It is TBD how this is resolved when the old and new
groups mismatch. See [Issue
10631](https://github.com/w3c/csswg-drafts/issues/10631).

##### [12.5.4.7. ][Adjust the group's [transform](https://drafts.csswg.org/css-transforms-1/#propdef-transform) to be relative to its containing [::view-transition-group()](#selectordef-view-transition-group)]
When [updating the style of the transition
pseudo-element](https://drafts.csswg.org/css-view-transitions-1/#style-transition-pseudo-elements-algorithm),
perform the following steps before setting the [group styles
rule](#captured-element-group-styles-rule), given a [captured
element](#captured-element)
`capturedElement`, given a `transform` and a
[`ViewTransition`](#viewtransition) `transition`:

1. Let `childrenTransform` be `transform`.

2. Set `capturedElement`'s [transform from snapshot
 containing
 block](#captured-element-transform-from-snapshot-containing-block) to `transform`.

3. If `capturedElement`'s [containing group
 name](#captured-element-containing-group-name) is not null, then:

 1. Let `groupContainerElement` be
 `transition`'s [named
 elements](#viewtransition-named-elements)\[`capturedElement`'s [containing
 group
 name](#captured-element-containing-group-name).

 2. [Adjust](#adjust-nested-view-transition-group-transform) `transform` given
 `groupContainerElement`.

To [adjust nested view transition group
transform] given a `transform`
and a [captured element](#captured-element) `groupContainerElement`:

1. Let `childrenTransform` be
 `groupContainerElement`'s [transform from snapshot
 containing
 block](#captured-element-transform-from-snapshot-containing-block).

2. If `childrenTransform` is null, set it to
 `groupContainerElement`'s [old
 transform](#captured-element-old-transform).

3. Translate `childrenTransform` by
 `groupContainerElement`'s [old border
 width](#captured-element-old-border-width)'s left and top components.

4. Multiply `transform` by the inverse matrix of
 `childrenTransform`.

### 12.6. [Call the update callback]
To [call the update callback] of a
[`ViewTransition`](#viewtransition) `transition`:

 This is guaranteed to happen for every
[`ViewTransition`](#viewtransition), even if the transition is
[skipped](#skip-the-view-transition). The reasons for this are discussed in [§ 1.5
Transitions as an enhancement](#transitions-as-enhancements).

1. [Assert](https://infra.spec.whatwg.org/#assert): `transition`'s
 [phase](#viewtransition-phase) is \"`done`\", or before
 \"`update-callback-called`\".

2. If `transition`'s
 [phase](#viewtransition-phase) is not \"`done`\", then set
 `transition`'s [phase]
 to \"`update-callback-called`\".

3. Let `callbackPromise` be null.

4. If `transition`'s [update
 callback](#viewtransition-update-callback) is null, then set `callbackPromise` to
 [a promise resolved
 with](https://webidl.spec.whatwg.org/#a-promise-resolved-with) undefined, in `transition`'s [relevant
 Realm](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-realm).

5. Otherwise, set `callbackPromise` to the result of
 [invoking](https://webidl.spec.whatwg.org/#invoke-a-callback-function) `transition`'s [update
 callback](#viewtransition-update-callback).

6. Let `fulfillSteps` be to following steps:

 1. [Resolve](https://webidl.spec.whatwg.org/#resolve) `transition`'s [update callback done
 promise](#viewtransition-update-callback-done-promise) with undefined.

 2. [Activate](#activate-view-transition) `transition`.

7. Let `rejectSteps` be the following steps given
 `reason`:

 1. [Reject](https://webidl.spec.whatwg.org/#reject) `transition`'s [update callback done
 promise](#viewtransition-update-callback-done-promise) with `reason`.

 2. If `transition`'s
 [phase](#viewtransition-phase) is \"`done`\", then return.

 This happens if `transition` was
 [skipped](#skip-the-view-transition) before this point.

 3. [Mark as
 handled](https://webidl.spec.whatwg.org/#mark-a-promise-as-handled) `transition`'s [ready
 promise](#viewtransition-ready-promise).

 `transition`'s [update callback done
 promise](#viewtransition-update-callback-done-promise) will provide the
 [`unhandledrejection`](https://html.spec.whatwg.org/multipage/indices.html#event-unhandledrejection). This step avoids a duplicate.

 4. [Skip the view
 transition](#skip-the-view-transition) `transition` with
 `reason`.

8. [React](https://webidl.spec.whatwg.org/#dfn-perform-steps-once-promise-is-settled) to `callbackPromise` with
 `fulfillSteps` and `rejectSteps`.

9. To skip a transition after a timeout, the user agent may perform the
 following steps [in
 parallel](https://html.spec.whatwg.org/multipage/infrastructure.html#in-parallel):

 1. Wait for an implementation-defined
 [duration](https://w3c.github.io/hr-time/#dfn-duration).

 2. [Queue a global
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-global-task) on the [DOM manipulation task
 source](https://html.spec.whatwg.org/multipage/webappapis.html#dom-manipulation-task-source), given `transition`'s [relevant
 global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global), to perform the following steps:

 1. If `transition`'s
 [phase](#viewtransition-phase) is \"`done`\", then return.

 This happens if `transition` was
 [skipped](#skip-the-view-transition) before this point.

 2. [Skip](#skip-the-view-transition) `transition` with a
 \"[`TimeoutError`](https://webidl.spec.whatwg.org/#timeouterror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

To [schedule the update callback] given a
[`ViewTransition`](#viewtransition) `transition`:

1. [Append](https://infra.spec.whatwg.org/#list-append) `transition` to
 `transition`'s [relevant settings
 object](https://html.spec.whatwg.org/multipage/webappapis.html#relevant-settings-object)'s [update callback
 queue](#document-update-callback-queue).

2. [Queue a global
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-global-task) on the [DOM manipulation task
 source](https://html.spec.whatwg.org/multipage/webappapis.html#dom-manipulation-task-source), given `transition`'s [relevant global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global), to [flush the update callback
 queue](#flush-the-update-callback-queue).

To [flush the update callback queue] given a
[`Document`](https://dom.spec.whatwg.org/#document) `document`:

1. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `transition` in `document`'s
 [update callback
 queue](#document-update-callback-queue), [call the update
 callback](#call-the-update-callback) given `transition`.

2. Set `document`'s [update callback
 queue](#document-update-callback-queue) to an empty list.

### 12.7. [Skip the view transition]
To [skip the view transition] for
[`ViewTransition`](#viewtransition) `transition` with reason
`reason`:

1. Let `document` be `transition`'s [relevant
 global
 object's](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global) [associated
 document](https://html.spec.whatwg.org/multipage/nav-history-apis.html#concept-document-window).

2. [Assert](https://infra.spec.whatwg.org/#assert): `transition`'s
 [phase](#viewtransition-phase) is not \"`done`\".

3. If `transition`'s
 [phase](#viewtransition-phase) is before \"`update-callback-called`\", then
 [schedule the update
 callback](#schedule-the-update-callback) for `transition`.

4. Set [rendering suppression for view
 transitions](#document-rendering-suppression-for-view-transitions) to false.

5. If `transition`'s [root
 element](#viewtransition-root-element)'s [active view
 transition](#element-active-view-transition) is `transition` or
 `document`'s [active view
 transition](#document-active-view-transition) is `transition`, [clear view
 transition](#clear-view-transition) of `transition`.

6. Set `transition`'s
 [phase](#viewtransition-phase) to \"`done`\".

7. [Reject](https://webidl.spec.whatwg.org/#reject) `transition`'s [ready
 promise](#viewtransition-ready-promise) with `reason`.

 The [ready
 promise](#viewtransition-ready-promise) may already be resolved at this point, if
 [`skipTransition()`](#dom-viewtransition-skiptransition) is called after we start animating. In that case,
 this step is a no-op.

8. [Resolve](https://webidl.spec.whatwg.org/#resolve) `transition`'s [finished
 promise](#viewtransition-finished-promise) with the result of
 [reacting](https://webidl.spec.whatwg.org/#dfn-perform-steps-once-promise-is-settled) to `transition`'s [update callback done
 promise](#viewtransition-update-callback-done-promise):

 - If the promise was fulfilled, then return undefined.

 Since the rejection of `transition`'s
 [update callback done
 promise](#viewtransition-update-callback-done-promise) isn't explicitly handled here, if
 `transition`'s [update callback done
 promise]
 rejects, then `transition`'s [finished
 promise](#viewtransition-finished-promise) will reject with the same reason.

### 12.8. View transition page-visibility change steps

The [view transition page-visibility change
steps] given
[`Document`](https://dom.spec.whatwg.org/#document) `document` are:

1. [Queue a global
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-global-task) on the [DOM manipulation task
 source](https://html.spec.whatwg.org/multipage/webappapis.html#dom-manipulation-task-source), given `document`'s [relevant global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global), to perform the following steps:

 1. If `document`'s [visibility
 state](https://html.spec.whatwg.org/multipage/interaction.html#visibility-state) is \"`hidden`\", then:

 1. If `document`'s [active view
 transition](#document-active-view-transition) is not null, then
 [skip](#skip-the-view-transition) `document`'s [active view
 transition](#element-active-view-transition) with an
 \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

 2. Otherwise,
 [assert](https://infra.spec.whatwg.org/#assert): [active view
 transition](#element-active-view-transition) is null.

 3. Set `document`'s [inbound view transition
 params](#document-inbound-view-transition-params) to null.

 this is called from the HTML spec.

### 12.9. [Capture the image]
To [capture the image]
given an
[element](https://drafts.csswg.org/css2/#element) `element`, perform the following steps. They
return an image.

1. If `element` is the [document
 element](https://dom.spec.whatwg.org/#document-element), then:

 1. Render the region of document (including its [canvas
 background](https://drafts.csswg.org/css-backgrounds-3/#canvas-background) and any [top
 layer](https://drafts.csswg.org/css-position-4/#document-top-layer) content) that intersects the [snapshot
 containing
 block](#snapshot-containing-block), on a transparent canvas the size of the
 [snapshot containing
 block], following the
 [capture rendering
 characteristics](#capture-rendering-characteristics), and these additional characteristics:

 - Areas outside `element`'s [scrolling
 box](https://drafts.csswg.org/cssom-view-1/#scrolling-box) should be rendered as if they were scrolled
 to, without moving or resizing the [layout
 viewport](https://drafts.csswg.org/css-viewport/#layout-viewport). This must not trigger events related to
 scrolling or resizing, such as
 [`IntersectionObserver`](https://w3c.github.io/IntersectionObserver/#intersectionobserver)s.

 <figure>
 <img src="diagrams/phone-browser-with-url.svg" width="202" height="297"
 a />
 <img src="diagrams/phone-browser-without-url.svg" width="202"
 height="297"
 a />
 <figcaption>An example of what the user sees compared to the captured
 snapshot. This example assumes the root is the only element with a
 transition name.</figcaption>
 </figure>

 - Areas that cannot be scrolled to (i.e. they are out of
 scrolling bounds), should render the [canvas
 background](https://drafts.csswg.org/css-backgrounds-3/#canvas-background).

 <figure>
 <img src="diagrams/phone-browser-scrolled-to-top-with-url.svg"
 width="202" height="297"
 a />
 <img src="diagrams/phone-browser-scrolled-to-top-without-url.svg"
 width="202" height="297"
 a />
 <figcaption>An example of what the user sees compared to the captured
 snapshot. This example assumes the root is the only element with a
 transition name.</figcaption>
 </figure>

 2. Return this canvas as an image. The natural size of the image is
 equal to the [snapshot containing
 block](#snapshot-containing-block).

2. Otherwise:

 1. Render `element` and its
 [descendants](https://dom.spec.whatwg.org/#concept-tree-descendant), at the same size it appears in its [node
 document](https://dom.spec.whatwg.org/#concept-node-document), over an infinite transparent canvas, following
 the [capture rendering
 characteristics](#capture-rendering-characteristics).

 2. Return the portion of this canvas that includes
 `element`'s [ink overflow
 rectangle](https://drafts.csswg.org/css-overflow-3/#ink-overflow-rectangle) as an image. The [natural
 dimensions](https://drafts.csswg.org/css-images-3/#natural-dimensions) of this image must be those of its
 [principal](https://drafts.csswg.org/css-display-4/#principal-box) [border
 box](https://drafts.csswg.org/css-box-4/#border-box), and its origin must correspond to that [border
 box]'s origin, such that the image
 represents the contents of this [border
 box] and any captured [ink
 overflow](https://drafts.csswg.org/css-overflow-3/#ink-overflow) is represented outside these bounds.

 When this image is rendered as a [replaced
 element](https://drafts.csswg.org/css-display-4/#replaced-element) at its [natural
 size](https://drafts.csswg.org/css-images-3/#natural-size), it will display with the size and contents of
 element's [principal
 box](https://drafts.csswg.org/css-display-4/#principal-box), with any captured [ink
 overflow](https://drafts.csswg.org/css-overflow-3/#ink-overflow) overflowing its [content
 box](https://drafts.csswg.org/css-box-4/#content-box).

#### 12.9.1. [Capture rendering characteristics]
The [capture rendering
characteristics] are as follows:

- If the referenced element has a transform applied to it (or its
 ancestors), then the transform is ignored.

 This transform is applied to the snapshot using the
 `transform` property of the associated [::view-transition-group]
 pseudo-element.

- Effects applied on the element and its descendants, such as
 [opacity](https://drafts.csswg.org/css-color-4/#propdef-opacity) and
 [filter](https://drafts.csswg.org/filter-effects-1/#propdef-filter), are applied to the capture.
 Effects applied to the element from its ancestors are ignored.

- Implementations may clip the rendered contents if the [ink overflow
 rectangle](https://drafts.csswg.org/css-overflow-3/#ink-overflow-rectangle) exceeds some
 [implementation-defined](https://infra.spec.whatwg.org/#implementation-defined) maximum. However, the captured image should include,
 at the very least, the contents of `element` that intersect
 with the [snapshot containing
 block](#snapshot-containing-block). Implementations may adjust the rasterization quality
 to account for elements with a large [ink overflow
 area](https://drafts.csswg.org/css-overflow-3/#ink-overflow-region) that are transformed into view.

- Implementations may also adjust the rasterization quality for elements
 whose [ink overflow
 rectangle](https://drafts.csswg.org/css-overflow-3/#ink-overflow-rectangle) does not intersect with the [snapshot containing
 block](#snapshot-containing-block). To avoid a broken experience if the element ends up
 becoming visible, the captured image should include, at the very
 least, some low-quality representation of the contents rather than
 transparent pixels.

 This allows efficiency in resource usage and
 rasterization performance for elements that are away from the viewport
 and might not become visible at all, while maintaining a visual effect
 close enough to the author's intent.

- [For
 each](https://infra.spec.whatwg.org/#list-iterate) `descendant` of [shadow-including
 descendant](https://dom.spec.whatwg.org/#concept-shadow-including-descendant)
 [`Element`](https://dom.spec.whatwg.org/#element) and
 [pseudo-element](https://drafts.csswg.org/selectors-4/#pseudo-element) of `element`, if `descendant`
 is [captured in a view
 transition](#element-captured-in-a-view-transition), then skip painting `descendant`.

 This is necessary since the descendant will generate
 its own snapshot which will be displayed and animated independently.

To [delay finish for promise], given a
[`ViewTransition`](#viewtransition) `transition` and promise `p`:

1. If `transition`'s
 [phase](#viewtransition-phase) is \"`done`\", abort the remainder of the steps and
 return.

2. If `p` is settled, abort the remainder of the steps and
 return.

3. Increment `transition`'s [wait until promise
 count](#viewtransition-wait-until-promise-count).

4. [Upon
 fulfillment](https://webidl.spec.whatwg.org/#upon-fulfillment) or
 [rejection](https://webidl.spec.whatwg.org/#upon-rejection) of `p`:

 1. Decrement `transition`'s [wait until promise
 count](#viewtransition-wait-until-promise-count).

 If `transition`'s [wait until promise
 count](#viewtransition-wait-until-promise-count) is 0, the transition will finish at the next
 [rendering
 opportunity](https://html.spec.whatwg.org/multipage/webappapis.html#rendering-opportunity).

### 12.10. [Handle transition frame]
To [handle transition frame] given a
[`ViewTransition`](#viewtransition) `transition`:

1. Let `document` be `transition`'s [relevant
 global
 object's](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global) [associated
 document](https://html.spec.whatwg.org/multipage/nav-history-apis.html#concept-document-window).

2. Let `hasActiveAnimations` be a boolean, initially false.

3. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `element` of the [inclusive
 descendants](https://dom.spec.whatwg.org/#concept-tree-inclusive-descendant) of the
 [::view-transition](#selectordef-view-transition)
 [pseudo-element](https://drafts.csswg.org/selectors-4/#pseudo-element) on `transition`'s [root
 element](#viewtransition-root-element):

 1. For each `animation` whose
 [timeline](https://drafts.csswg.org/web-animations-1/#timeline) is a [document
 timeline](https://drafts.csswg.org/web-animations-1/#document-timeline) associated with `document`, and
 contains at least one [associated
 effect](https://drafts.csswg.org/web-animations-1/#animation-associated-effect) whose [effect
 target](https://drafts.csswg.org/web-animations-1/#keyframe-effect-effect-target) is `element`, set
 `hasActiveAnimations` to true if any of the following
 conditions are true:

 - `animation`'s [play
 state](https://drafts.csswg.org/web-animations-1/#animation-play-state) is
 [paused](https://drafts.csswg.org/web-animations-1/#play-state-paused) or
 [running](https://drafts.csswg.org/web-animations-1/#play-state-running).

 - `document`'s [pending animation event
 queue](https://drafts.csswg.org/web-animations-1/#pending-animation-event-queue) has any events associated with
 `animation`.

4. If `hasActiveAnimations` is false and
 `transition`'s [wait until promise
 count](#viewtransition-wait-until-promise-count) is 0:

 1. Set `transition`'s
 [phase](#viewtransition-phase) to \"`done`\".

 2. [Clear view
 transition](#clear-view-transition) `transition`.

 3. [Resolve](https://webidl.spec.whatwg.org/#resolve) `transition`'s [finished
 promise](#viewtransition-finished-promise).

 4. Return.

5. If `transition`'s [initial snapshot containing block
 size](#viewtransition-initial-snapshot-containing-block-size) is not equal to the [snapshot containing block
 size](#snapshot-containing-block-size), then [skip the view
 transition](#skip-the-view-transition) for `transition` with an
 \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) in `transition`'s [relevant
 Realm](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-realm), and return.

6. [Update pseudo-element
 styles](#update-pseudo-element-styles) for `transition`.

 If failure is returned, then [skip the view
 transition](#skip-the-view-transition) for `transition` with an
 \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) in `transition`'s [relevant
 Realm](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-realm), and return.

 The above implies that a change in incoming
 element's size or position will cause a new keyframe to be
 generated. This can cause a visual jump. We could retarget smoothly
 but don't have a use-case to justify the complexity. See [issue
 7813](https://github.com/w3c/csswg-drafts/issues/7813) for details.

### 12.11. [Update pseudo-element styles]
To [update pseudo-element styles] for a
[`ViewTransition`](#viewtransition) `transition`:

1. [For
 each](https://infra.spec.whatwg.org/#map-iterate) `transitionName` →
 `capturedElement` of `transition`'s [named
 elements](#viewtransition-named-elements):

 1. Let `width`, `height`,
 `transform`, `writingMode`,
 `direction`, `textOrientation`,
 `mixBlendMode`, `backdropFilter` and
 `colorScheme` be null.

 2. If `capturedElement`'s [new
 element](#captured-element-new-element) is null, then:

 1. Set `width` to `capturedElement`'s
 [old
 width](#captured-element-old-width).

 2. Set `height` to `capturedElement`'s
 [old
 height](#captured-element-old-height).

 3. Set `transform` to `capturedElement`'s
 [old
 transform](#captured-element-old-transform).

 4. Set `writingMode` to
 `capturedElement`'s [old
 writing-mode](#captured-element-old-writing-mode).

 5. Set `direction` to `capturedElement`'s
 [old
 direction](#captured-element-old-direction).

 6. Set `textOrientation` to
 `capturedElement`'s [old
 text-orientation](#captured-element-old-text-orientation).

 7. Set `mixBlendMode` to
 `capturedElement`'s [old
 mix-blend-mode](#captured-element-old-mix-blend-mode).

 8. Set `backdropFilter` to
 `capturedElement`'s [old
 backdrop-filter](#captured-element-old-backdrop-filter).

 9. Set `colorScheme` to
 `capturedElement`'s [old
 color-scheme](#captured-element-old-color-scheme).

 3. Otherwise:

 1. Return failure if any of the following conditions are true:

 - `capturedElement`'s [new
 element](#captured-element-new-element) has a [flat
 tree](https://drafts.csswg.org/css-shadow-1/#flat-tree) ancestor that [skips its
 contents](https://drafts.csswg.org/css-contain-2/#skips-its-contents).

 - `capturedElement`'s [new
 element](#captured-element-new-element) is [not
 rendered](https://drafts.csswg.org/css-images-4/#element-not-rendered).

 - `capturedElement` has more than one [box
 fragment](https://drafts.csswg.org/css-break-4/#box-fragment).

 Other rendering constraints are enforced
 via `capturedElement`'s [new
 element](#captured-element-new-element) being [captured in a view
 transition](#element-captured-in-a-view-transition).

 2. Let `newRect` be the [snapshot containing
 block](#snapshot-containing-block) if `capturedElement`'s [new
 element](#captured-element-new-element) is the [document
 element](https://dom.spec.whatwg.org/#document-element), otherwise, `capturedElement`'s
 [border
 box](https://drafts.csswg.org/css-box-4/#border-box).

 3. Set `width` to the current width of
 `newRect`.

 4. Set `height` to the current height of
 `newRect`.

 5. Set `transform` to a transform that would map
 `newRect` from the [snapshot containing block
 origin](#snapshot-containing-block-origin) to its current visual position.

 6. Set `writingMode` to the [computed
 value](https://drafts.csswg.org/css-cascade-5/#computed-value) of
 [writing-mode](https://drafts.csswg.org/css-writing-modes-4/#propdef-writing-mode) on
 `capturedElement`'s [new
 element](#captured-element-new-element).

 7. Set `direction` to the [computed
 value](https://drafts.csswg.org/css-cascade-5/#computed-value) of
 [direction](https://drafts.csswg.org/css-writing-modes-3/#propdef-direction) on
 `capturedElement`'s [new
 element](#captured-element-new-element).

 8. Set `textOrientation` to the [computed
 value](https://drafts.csswg.org/css-cascade-5/#computed-value) of
 [text-orientation](https://drafts.csswg.org/css-writing-modes-4/#propdef-text-orientation) on
 `capturedElement`'s [new
 element](#captured-element-new-element).

 9. Set `mixBlendMode` to the [computed
 value](https://drafts.csswg.org/css-cascade-5/#computed-value) of
 [mix-blend-mode](https://drafts.csswg.org/compositing-2/#propdef-mix-blend-mode) on
 `capturedElement`'s [new
 element](#captured-element-new-element).

 10. Set `backdropFilter` to the [computed
 value](https://drafts.csswg.org/css-cascade-5/#computed-value) of
 [backdrop-filter](https://drafts.csswg.org/filter-effects-2/#propdef-backdrop-filter) on
 `capturedElement`'s [new
 element](#captured-element-new-element).

 11. Set `colorScheme` to the [computed
 value](https://drafts.csswg.org/css-cascade-5/#computed-value) of
 [color-scheme](https://drafts.csswg.org/css-color-adjust-1/#propdef-color-scheme) on
 `capturedElement`'s [new
 element](#captured-element-new-element).

 4. If `capturedElement`'s [group styles
 rule](#captured-element-group-styles-rule) is null, then set
 `capturedElement`'s [group styles
 rule] to a new
 [`CSSStyleRule`](https://drafts.csswg.org/cssom-1/#cssstylerule) representing the following CSS, and append it
 to `transition`'s [relevant global
 object's](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global) [associated
 document](https://html.spec.whatwg.org/multipage/nav-history-apis.html#concept-document-window)'s [dynamic view transition style
 sheet](#document-dynamic-view-transition-style-sheet).

 Otherwise, update `capturedElement`'s [group styles
 rule](#captured-element-group-styles-rule) to match the following CSS:

 ``` highlight
 :root::view-transition-group(transitionName) {
 width: width;
 height: height;
 transform: transform;
 writing-mode: writingMode;
 direction: direction;
 text-orientation: textOrientation;
 mix-blend-mode: mixBlendMode;
 backdrop-filter: backdropFilter;
 color-scheme: colorScheme;
 }
 ```

 The above code example contains variables to be
 replaced.

 5. If `capturedElement`'s [new
 element](#captured-element-new-element) is not null, then:

 1. Let `new` be the
 [::view-transition-new()](#selectordef-view-transition-new) with the [view transition
 name](#view-transition-name) `transitionName`.

 2. Set `new`'s [replaced
 element](https://drafts.csswg.org/css-display-4/#replaced-element) content to the result of [capturing the
 image](#capture-the-image) of `capturedElement`'s [new
 element](#captured-element-new-element).

This algorithm must be executed to update styles in [user-agent
origin](https://drafts.csswg.org/css-cascade-5/#cascade-origin-ua) if its effects can be observed by a web API.

 An example of such a web API is
`window.getComputedStyle(document.documentElement, "::view-transition")`.

### 12.12. [Clear view transition]
To [clear view transition] of a
[`ViewTransition`](#viewtransition) `transition`:

1. Let `document` be `transition`'s [relevant
 global
 object's](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global) [associated
 document](https://html.spec.whatwg.org/multipage/nav-history-apis.html#concept-document-window).

2. [Assert](https://infra.spec.whatwg.org/#assert): `transition`'s [root
 element](#viewtransition-root-element)'s [active view
 transition](#element-active-view-transition) is `transition` or
 `document`'s [active view
 transition](#document-active-view-transition) is `transition`.

3. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `capturedElement` of
 `transition`'s [named
 elements](#viewtransition-named-elements)\'
 [values](https://infra.spec.whatwg.org/#map-getting-the-values):

 1. If `capturedElement`'s [new
 element](#captured-element-new-element) is not null, then set
 `capturedElement`'s [new
 element]'s [captured in
 a view
 transition](#element-captured-in-a-view-transition) to false.

 2. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `style` of
 `capturedElement`'s [style
 definitions](#captured-element-style-definitions):

 1. If `style` is not null, and `style` is
 in `document`'s [dynamic view transition style
 sheet](#document-dynamic-view-transition-style-sheet), then remove `style` from
 `document`'s [dynamic view transition style
 sheet].

4. Remove all children of the
 [::view-transition](#selectordef-view-transition)
 [pseudo-element](https://drafts.csswg.org/selectors-4/#pseudo-element) on `transition`'s [root
 element](#viewtransition-root-element).

5. If `transition`'s [root
 element](#viewtransition-root-element) is not null, set `transition`'s [root
 element]'s [active view
 transition](#element-active-view-transition) to null.

6. If `document`'s [active view
 transition](#document-active-view-transition) is `transition`, set
 `document`'s [active view
 transition] to null.

## [Privacy Considerations]
This specification introduces no new privacy considerations.

## [Security Considerations]
The images generated using [capture the
image](#capture-the-image)
algorithm could contain cross-origin data (if the Document is embedding
cross-origin resources) or sensitive information like visited links. The
implementations must ensure this data can not be accessed by the
Document. This should be feasible since access to this data should
already be prevented in the default rendering of the Document.

To prevent cross-origin issues, at this point cross-document view
transitions can only be enabled for same-origin navigations. As
discussed in
[WICG/view-transitions#200](https://github.com/WICG/view-transitions/issues/200),
this still presents two potential threats:

1. The [cross-origin isolated
 capability](https://html.spec.whatwg.org/multipage/webappapis.html#concept-settings-object-cross-origin-isolated-capability) in both documents might be different. This can
 cause a situation where a
 [`Document`](https://dom.spec.whatwg.org/#document) that is [cross-origin
 isolated]
 can read image data from a document that is not cross-origin
 isolated. This is already mitigated in [CSS View Transitions 1 § 
 Security
 Considerations](https://drafts.csswg.org/css-view-transitions-1/#sec),
 as the same restriction applies for captured cross-origin iframes.

2. A same-origin navigation might still occur via a cross-origin
 redirect, e.g. `https://example.com` links to
 `https://auth-provider.com/` which redirects back to
 `https://example.com/loggedin`.

 This can cause a (minor) situation where the cross-origin party
 would redirect the user to an unexpected first-party URL, causing an
 unexpected transition and obfuscating that fact that there was a
 redirect. To mitigate this, currently view transitions are disabled
 for navigations if the
 [`Document`](https://dom.spec.whatwg.org/#document) [was created via cross-origin
 redirects](https://html.spec.whatwg.org/multipage/dom.html#was-created-via-cross-origin-redirects). Note that this check doesn't apply when the
 [`Document`](https://dom.spec.whatwg.org/#document) is being
 [reactivated](https://html.spec.whatwg.org/multipage/browsing-the-web.html#reactivate-a-document), as in that case the cross-origin redirect has
 already taken place.

 this only applies to server-side redirects. A
 client-side redirect, e.g. using \[\^meta/http-equiv/refresh\^\], is
 equivalent to a new navigation.

3. This feature exposes more information to CSS, as so far CSS was not
 aware of anything navigation-related. This can raise concerns around
 safety 3rd-party CSS. However, as a general rule, 3rd-party
 stylesheets should come from trusted sources to begin with, as CSS
 can learn about the document or change it in many ways.

See [Issue #8684](https://github.com/w3c/csswg-drafts/issues/8684) and
[WICG/view-transitions#200](https://github.com/WICG/view-transitions/issues/200)
for detailed discussion.

## [Appendix A. Changes]
This appendix is *informative*.

### [ Changes from [2024-05-16 Working Draft](https://www.w3.org/TR/2024/WD-css-view-transitions-2-20240516/) ]
- Add description of nested view transition groups, which was partially
 missing.

- Update wording to use `opacity: 0` instead of `visibility: hidden`.
 See [issue 12629](https://github.com/w3c/csswg-drafts/issues/12629).

- Replace `contain: view-transition` with `view-transition-scope`
 property ([pending
 #13123](https://github.com/w3c/csswg-drafts/issues/13123))

- Reorder sections, editorial changes, added several issues, updated
 scoped view transition wording.

- Add waitUntil()
 ([#9901](https://github.com/w3c/csswg-drafts/issues/9901))

- First pass at layered capture
 ([#10585](https://github.com/w3c/csswg-drafts/issues/10585))

- Allow transitions when traversing into a document that was created
 using cross-origin redirects
 ([#11063](https://github.com/w3c/csswg-drafts/issues/11063)#11063)

- Clarify a few nesting details
 ([#10780](https://github.com/w3c/csswg-drafts/issues/10780) and
 [#10633](https://github.com/w3c/csswg-drafts/issues/10633))

- Allow `auto` as a keyword for
 [view-transition-name](#propdef-view-transition-name)
 ([#8320](https://github.com/w3c/csswg-drafts/issues/8320))

- Clarify timeout behavior for inbound view transition
 ([#10800](https://github.com/w3c/csswg-drafts/issues/10800))

- When hiding the document, and inbound cross-document view transition
 should be skipped.
 ([#9822](https://github.com/w3c/csswg-drafts/issues/9822))

- Rename UpdateCallback to something more specific.

- Clarify that CSSViewTransitionRule returns an empty string for
 invalid/missing navigation descriptor
 ([#10654](https://github.com/w3c/csswg-drafts/issues/10654))

- Initial spec for nested view transitions
 ([#10334](https://github.com/w3c/csswg-drafts/issues/10334))

- `view-transition-class` is a tree-scoped name
 ([#10529](https://github.com/w3c/csswg-drafts/issues/10529))

- Stop extending CSSRule with obsolete pattern (See
 [#10606](https://github.com/w3c/csswg-drafts/issues/10606))

- Added
 [`activeViewTransition`](#dom-document-activeviewtransition) attribute
 ([#12407](https://github.com/w3c/csswg-drafts/issues/12407))
