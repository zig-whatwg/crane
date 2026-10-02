## 1. Introduction

*This section is non-normative.*

This specification introduces a DOM API and associated CSS features that
allow developers to create animated visual transitions, called [view
transitions] between different states of a
[document](https://dom.spec.whatwg.org/#concept-document).

### 1.1. Separating Visual Transitions from DOM Updates

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
[pseudo-elements](https://drafts.csswg.org/selectors-4/#pseudo-element) (detailed in [§ 3.2 View Transition
Pseudo-elements](#view-transition-pseudos)), where the old visual state
co-exists with the new state, allowing effects such as cross-fading
while animating from the old to new size and position.

### 1.2. View Transition Customization

By default,
`document.`[`startViewTransition()`](#dom-document-startviewtransition) creates a [view
transition](#view-transitions) consisting of a page-wide cross-fade between the two
DOM states. Developers can also choose which elements are captured
independently using the
[view-transition-name](#propdef-view-transition-name) CSS property, allowing these to be
animated independently of the rest of the page. Since the transitional
state (where both old and new visual captures exist) is represented as
[pseudo-elements](https://drafts.csswg.org/selectors-4/#pseudo-element), developers can customize each transition using
familiar features such as [CSS
Animations](https://www.w3.org/TR/css-animations/) and [Web
Animations](https://www.w3.org/TR/web-animations/).

### 1.3. View Transition Lifecycle

A successful [view
transition](#view-transitions) goes through the following phases:

1. Developer calls
 `document.`[`startViewTransition`](#dom-document-startviewtransition)`(`[`updateCallback`](#callbackdef-viewtransitionupdatecallback)`)`, which returns a
 [`ViewTransition`](#viewtransition), `viewTransition`.

2. Current state captured as the "old" state.

3. Rendering paused.

4. Developer's
 [`updateCallback`](#callbackdef-viewtransitionupdatecallback) function, if provided, is called, which updates the
 document state.

5. `viewTransition``.`[`updateCallbackDone`](#dom-viewtransition-updatecallbackdone) fulfills.

6. Current state captured as the "new" state.

7. Transition pseudo-elements created. See [§ 3.2 View Transition
 Pseudo-elements](#view-transition-pseudos) for an overview of this
 structure.

8. Rendering unpaused, revealing the transition pseudo-elements.

9. `viewTransition``.`[`ready`](#dom-viewtransition-ready) fulfills.

10. Pseudo-elements animate until finished.

11. Transition pseudo-elements removed.

12. `viewTransition``.`[`finished`](#dom-viewtransition-finished) fulfills.

Previous Next

### 1.4. Transitions as an enhancement

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
[`navigateEvent`](https://wicg.github.io/navigation-api/#navigateevent)`.`[`signal`](https://wicg.github.io/navigation-api/#ref-for-dom-navigateevent-signal①) is an example of a feature developers could use to
handle this.

Although the View Transition API allows DOM changes to be asynchronous
via the
[`ViewTransitionUpdateCallback`](#callbackdef-viewtransitionupdatecallback), the API is not responsible for queuing or otherwise
scheduling DOM changes beyond any scheduling needed for the transition
itself. Some asynchronous DOM changes can happen concurrently (e.g if
they're happening within independent components), whereas others need to
queue, or abort an earlier change. This is best left to a feature or
framework that has a more holistic view of the application.

### 1.5. Rendering Model

View Transition works by replicating an element's rendered state using
UA generated
[pseudo-elements](https://drafts.csswg.org/selectors-4/#pseudo-element). Aspects of the element's rendering which apply to the
element itself or its descendants, for example visual effects like
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

### 1.6. Examples

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
header and text within the header can be given their own
[::view-transition-group()](#selectordef-view-transition-group)s for the transition:

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

## 2. CSS properties

### 2.1. Tagging Individually Transitioning Subtrees: the [view-transition-name property]
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
transition](#captured-in-a-view-transition), tracking it independently in the [view transition
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

 Since currently only document-scoped view
 transitions are supported, only view transition names that are
 associated with the document are respected.

 The values [none], [auto], and [match-element] are
 excluded from
 [\<custom-ident\>](https://drafts.csswg.org/css-values-4/#identifier-value) here.

 If this name is not unique (i.e. if two elements
 simultaneously specify the same [view transition
 name](#view-transition-name)) then the [view
 transition](#view-transitions) will abort.

 For the purposes of this API, if one element has [view
transition name](#view-transition-name) [foo] in the old state, and another element has
[view transition name] [foo] in
the new state, they are treated as representing different visual state
of the same element, and will be paired in the [view transition
tree](#view-transition-tree). This may be confusing, since the elements themselves
are not necessarily referring to the same object, but it is a useful
model to consider them to be visual states of the same conceptual page
entity.

If the element's [principal
box](https://drafts.csswg.org/css-display-4/#principal-box) is
[fragmented](https://drafts.csswg.org/css-break-4/#fragment),
[skipped](https://drafts.csswg.org/css-contain-2/#skips-its-contents), or [not
rendered](https://drafts.csswg.org/css-images-4/#element-not-rendered), this property has no effect. See [§ 7
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

#### 2.1.1. Rendering Consolidation

[Elements](https://drafts.csswg.org/css2/#element) [captured in a view
transition](#captured-in-a-view-transition) during a [view
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

## 3. Pseudo-elements

### 3.1. Pseudo-element Trees

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

### 3.2. View Transition Pseudo-elements

The visualization of a [view
transition](#view-transitions) is represented as a [pseudo-element
tree](#pseudo-element-tree) called the [view transition tree] composed of the [view
transition pseudo-elements] defined below. This tree is
built during the [setup transition
pseudo-elements](#setup-transition-pseudo-elements) step, and is rooted under a
[::view-transition](#selectordef-view-transition)
[pseudo-element](https://drafts.csswg.org/selectors-4/#pseudo-element)
[originating](https://drafts.csswg.org/selectors-4/#originating-element) from the [root
element](https://drafts.csswg.org/css-display-4/#root-element). All of the [view transition
pseudo-elements](#view-transition-pseudo-elements) are selected from their [ultimate originating
element](https://drafts.csswg.org/selectors-4/#ultimate-originating-element), the [document
element](https://dom.spec.whatwg.org/#document-element).

The [view transition
tree](#view-transition-tree) is not exposed to the accessibility tree.

For example, the
[::view-transition-group()](#selectordef-view-transition-group) pseudo-element is attached to the root element
selector directly, as in [:root::view-transition-group()]; it is
not attached to its parent, the
[::view-transition](#selectordef-view-transition) pseudo-element.

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

#### 3.2.1. Named View Transition Pseudo-elements

Several of the [view transition
pseudo-elements](#view-transition-pseudo-elements) are [named view transition
pseudo-elements], which are
[functional](https://drafts.csswg.org/selectors-4/#functional-pseudo-element)
[tree-abiding](https://drafts.csswg.org/css-pseudo-4/#tree-abiding) [view transition
pseudo-elements] associated
with a [view transition
name](#view-transition-name). These
[pseudo-elements](https://drafts.csswg.org/selectors-4/#pseudo-element) take a
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

#### 3.2.2. View Transition Tree Root: the [::view-transition pseudo-element]
The [::view-transition]
[pseudo-element](https://drafts.csswg.org/selectors-4/#pseudo-element) is a [tree-abiding
pseudo-element](https://drafts.csswg.org/css-pseudo-4/#tree-abiding) that is also a [pseudo-element
root](#pseudo-element-root). Its [originating
element](https://drafts.csswg.org/selectors-4/#originating-element) is the document's [document
element](https://dom.spec.whatwg.org/#document-element), and its [containing
block](https://drafts.csswg.org/css-display-3/#containing-block) is the [snapshot containing
block](#snapshot-containing-block).

 This element serves as the
[parent](https://dom.spec.whatwg.org/#concept-tree-parent) of all
[::view-transition-group()](#selectordef-view-transition-group) pseudo-elements.

#### 3.2.3. View Transition Named Subtree Root: the [::view-transition-group() pseudo-element](#::view-transition-group)

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

#### 3.2.4. View Transition Image Pair Isolation: the [::view-transition-image-pair() pseudo-element](#::view-transition-image-pair)

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

#### 3.2.5. View Transition Old State Image: the [::view-transition-old() pseudo-element](#::view-transition-old)

The [::view-transition-old()]
[pseudo-element](https://drafts.csswg.org/selectors-4/#pseudo-element) is an empty [named view transition
pseudo-element](#named-view-transition-pseudo-elements) that represents a visual snapshot of the "old" state as
a [replaced
element](https://drafts.csswg.org/css-display-3/#replaced-element); it is omitted if there's no "old" state to represent.
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

#### 3.2.6. View Transition New State Image: the [::view-transition-new() pseudo-element](#::view-transition-new)

The [::view-transition-new()]
[pseudo-element](https://drafts.csswg.org/selectors-4/#pseudo-element) (like the analogous
[::view-transition-old()](#selectordef-view-transition-old) pseudo-element) is an empty [named view
transition
pseudo-element](#named-view-transition-pseudo-elements) that represents a visual snapshot of the "new" state as
a [replaced
element](https://drafts.csswg.org/css-display-3/#replaced-element); it is omitted if there's no "new" state to represent.
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

## 4. View Transition Layout

The [view transition
pseudo-elements](#view-transition-pseudo-elements) are styled, laid out, and rendered like normal
elements, except that they originate in the [snapshot containing
block](#snapshot-containing-block) rather than the [initial containing
block](https://drafts.csswg.org/css-display-4/#initial-containing-block) and are painted in the [view transition
layer](#view-transition-layer) above the rest of the document.

### 4.1. The Snapshot Containing Block

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
id="ref-for-snapshot-containing-block③" data->snapshot
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
id="ref-for-snapshot-containing-block④" data->snapshot
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

### 4.2. View Transition Painting Order

This specification introduces a new stacking layer, the [view transition
layer](#view-transition-layer), to the end of the painting order established in
[CSS2§E Elaborate Description of Stacking
Contexts](https://www.w3.org/TR/CSS22/zindex.html).
[\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")

The
[::view-transition](#selectordef-view-transition)
[pseudo-element](https://drafts.csswg.org/selectors-4/#pseudo-element) generates a new stacking context, called the [view
transition layer], which paints after all other content of the
document (including any content rendered in the [top
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

When a
[`Document`](https://dom.spec.whatwg.org/#document)'s [active view
transition](#document-active-view-transition)'s
[phase](#viewtransition-phase) is \"`animating`\", the boxes generated by any element
in that
[`Document`](https://dom.spec.whatwg.org/#document) with [captured in a view
transition](#captured-in-a-view-transition) and its [element
contents](https://drafts.csswg.org/css-contain-2/#element-contents), except [transition root
pseudo-element](#viewtransition-transition-root-pseudo-element)'s [inclusive
descendants](https://dom.spec.whatwg.org/#concept-tree-inclusive-descendant), are not painted (as if they had [opacity:
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

## 5. User Agent Stylesheet

The [global view transition user agent style
sheet] is a [user-agent
origin](https://drafts.csswg.org/css-cascade-5/#cascade-origin-ua) style sheet containing the following rules:

```
:root {
 view-transition-name: root;
}

:root::view-transition {
 position: absolute;
 inset: 0;
}

:root::view-transition-group(*) {
 position: absolute;
 top: 0;
 left: 0;

 animation-duration: 0.25s;
 animation-fill-mode: both;
}

:root::view-transition-image-pair(*) {
 position: absolute;
 inset: 0;
}

:root::view-transition-old(*),
:root::view-transition-new(*) {
 position: absolute;
 inset-block-start: 0;
 inline-size: 100%;
 block-size: auto;
}

:root::view-transition-image-pair(*),
:root::view-transition-old(*),
:root::view-transition-new(*) {
 animation-duration: inherit;
 animation-fill-mode: inherit;
 animation-delay: inherit;
 animation-timing-function: inherit;
 animation-iteration-count: inherit;
 animation-direction: inherit;
 animation-play-state: inherit;
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

- Lay out
 [::view-transition](#selectordef-view-transition) to cover the entire [snapshot containing
 block](#snapshot-containing-block) so that each [:view-transition-group()] child
 can lay out relative to it.

- Give the [root
 element](https://drafts.csswg.org/css-display-4/#root-element) a default [view transition
 name](#view-transition-name), to allow it to be independently selected.

- Reduce layout interference from the
 [::view-transition-image-pair()](#selectordef-view-transition-image-pair)
 [pseudo-element](https://drafts.csswg.org/selectors-4/#pseudo-element) so that authors can essentially treat
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

## 6. API

### [6.1. ][Additions to [`Document`](https://dom.spec.whatwg.org/#document)]
```
partial interface Document {
 ViewTransition startViewTransition(optional ViewTransitionUpdateCallback updateCallback);
};

callback ViewTransitionUpdateCallback = Promise<any> ();
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
 transition cannot happen (e.g. due to duplicate
 `view-transition-name` values). The transition is an enhancement
 around the state change, so a failure to create a transition never
 prevents the state change. See [§ 1.4 Transitions as an
 enhancement](#transitions-as-enhancements) for more details on this
 principle.

 If the promise returned by
 [`updateCallback`](#callbackdef-viewtransitionupdatecallback) rejects, the transition is skipped.

#### 6.1.1. [`startViewTransition()` Method Steps]
The [method
steps](https://webidl.spec.whatwg.org/#method-steps) for
[`startViewTransition(``updateCallback``)`] are as
follows:

1. Let `transition` be a new
 [`ViewTransition`](#viewtransition) object in
 [this's](https://webidl.spec.whatwg.org/#this) [relevant
 Realm](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-realm).

2. If `updateCallback` is provided, set
 `transition`'s [update
 callback](#viewtransition-update-callback) to `updateCallback`.

3. Let `document` be
 [this's](https://webidl.spec.whatwg.org/#this) [relevant global
 object's](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global) [associated
 document](https://html.spec.whatwg.org/multipage/nav-history-apis.html#concept-document-window).

4. If `document`'s [visibility
 state](https://html.spec.whatwg.org/multipage/interaction.html#visibility-state) is \"`hidden`\", then
 [skip](#skip-the-view-transition) `transition` with an
 \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException), and return `transition`.

5. If `document`'s [active view
 transition](#document-active-view-transition) is not null, then [skip that view
 transition](#skip-the-view-transition) with an
 \"[`AbortError`](https://webidl.spec.whatwg.org/#aborterror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) in
 [this's](https://webidl.spec.whatwg.org/#this) [relevant
 Realm](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-realm).

 This can result in two asynchronous [update
 callbacks](#viewtransition-update-callback) running concurrently (and therefore possibly out of
 sequence): one for the `document`'s current [active view
 transition](#document-active-view-transition), and another for this `transition`. As
 per the [design of this feature](#transitions-as-enhancements), it's
 assumed that the developer is using another feature or framework to
 correctly schedule these DOM changes.

6. Set `document`'s [active view
 transition](#document-active-view-transition) to `transition`.

 The [view
 transition](#view-transitions) process continues in [setup view
 transition](#setup-view-transition), via [perform pending transition
 operations](#perform-pending-transition-operations).

7. Return `transition`.

### 6.2. The [`ViewTransition` interface]
```
[Exposed=Window]
interface ViewTransition {
 readonly attribute Promise<undefined> updateCallbackDone;
 readonly attribute Promise<undefined> ready;
 readonly attribute Promise<undefined> finished;
 undefined skipTransition();
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

: A promise that fulfills once the
 [pseudo-elements](https://drafts.csswg.org/selectors-4/#pseudo-element) for the transition are created, and the animation
 is about to start.

 It rejects if the transition cannot begin. This can be due to
 misconfiguration, such as duplicate
 [view-transition-name](#propdef-view-transition-name)s, or if
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
 the transition. See [§ 1.4 Transitions as an
 enhancement](#transitions-as-enhancements) for more details on this
 principle.

 If this is called before
 [`ready`](#dom-viewtransition-ready) resolves,
 [`ready`](#dom-viewtransition-ready) will reject.

 If
 [`finished`](#dom-viewtransition-finished) hasn't resolved, it will fulfill or reject along
 with
 [`updateCallbackDone`](#dom-viewtransition-updatecallbackdone).

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

[transition root pseudo-element]

: a
 [::view-transition](#selectordef-view-transition). Initially a new
 [::view-transition].

[initial snapshot containing block size]

: a [tuple](https://infra.spec.whatwg.org/#tuple) of two numbers (width and height), or null.
 Initially null.

 This is used to detect changes in the [snapshot
 containing block
 size](#snapshot-containing-block-size), which causes the transition to
 [skip](#skip-the-view-transition). [Discussion of this
 behavior](https://github.com/w3c/csswg-drafts/issues/8045).

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

#### 6.2.1. [`skipTransition()` Method Steps]
The [method
steps](https://webidl.spec.whatwg.org/#method-steps) for
[`skipTransition()`] are:

1. If [this](https://webidl.spec.whatwg.org/#this)'s
 [phase](#viewtransition-phase) is not \"`done`\", then [skip the view
 transition](#skip-the-view-transition) for [this] with an
 \"[`AbortError`](https://webidl.spec.whatwg.org/#aborterror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

## 7. Algorithms

### 7.1. Data Structures

#### [7.1.1. ][Additions to [`Document`](https://dom.spec.whatwg.org/#document)]
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
 sheet](https://drafts.csswg.org/css-2022/#style-sheet). Initially a new [style
 sheet] in the [user-agent
 origin](https://drafts.csswg.org/css-cascade-5/#cascade-origin-ua), ordered after the [global view transition user
 agent style
 sheet](#global-view-transition-user-agent-style-sheet).

 This is used to hold dynamic styles relating to
 transitions.

[show view transition tree]

: A boolean. Initially false.

 When this is true,
 [this](https://webidl.spec.whatwg.org/#this)'s [active view
 transition](#document-active-view-transition)'s [transition root
 pseudo-element](#viewtransition-transition-root-pseudo-element) renders as a child of [this]'s
 [document
 element](https://dom.spec.whatwg.org/#document-element), with [this]'s [document
 element] being its [originating
 element](https://drafts.csswg.org/selectors-4/#originating-element).

 The position of the [transition root
 pseudo-element](#viewtransition-transition-root-pseudo-element) within the [document
 element](https://dom.spec.whatwg.org/#document-element) does not matter, as the [transition root
 pseudo-element]'s
 [containing
 block](https://drafts.csswg.org/css-display-3/#containing-block) is the [snapshot containing
 block](#snapshot-containing-block).

[update callback queue]

: A [list](https://infra.spec.whatwg.org/#list), initially empty.

#### 7.1.2. Additions to Elements

[Elements](https://drafts.csswg.org/css2/#element) have a [captured in a view
transition] boolean, initially false.

 This spec uses CSS's definition of
[element](https://drafts.csswg.org/css2/#element), which includes
[pseudo-elements](https://drafts.csswg.org/selectors-4/#pseudo-element).

#### 7.1.3. [Captured elements]
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

### 7.2. [Perform pending transition operations]
This algorithm is invoked as a part of [update the rendering
loop](https://html.spec.whatwg.org/#event-loop-processing-model:perform-pending-transition-operations)
in the html spec.

To [perform pending transition
operations] given a
[`Document`](https://dom.spec.whatwg.org/#document) `document`, perform the following steps:

1. If `document`'s [active view
 transition](#document-active-view-transition) is not null, then:

 1. If `document`'s [active view
 transition](#document-active-view-transition)'s
 [phase](#viewtransition-phase) is \"`pending-capture`\", then [setup view
 transition](#setup-view-transition) for `document`'s [active view
 transition].

 2. Otherwise, if `document`'s [active view
 transition](#document-active-view-transition)'s
 [phase](#viewtransition-phase) is \"`animating`\", then [handle transition
 frame](#handle-transition-frame) for `document`'s [active view
 transition].

### 7.3. [Setup view transition]
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

5. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `capturedElement` of
 `transition`'s [named
 elements](#viewtransition-named-elements)\'
 [values](https://infra.spec.whatwg.org/#map-getting-the-values):

 1. If `capturedElement`'s [new
 element](#captured-element-new-element) is not null, then set
 `capturedElement`'s [new
 element]'s [captured in
 a view
 transition](#captured-in-a-view-transition) to true.

6. [Setup transition
 pseudo-elements](#setup-transition-pseudo-elements) for `transition`.

7. [Update pseudo-element
 styles](#update-pseudo-element-styles) for `transition`.

 If failure is returned, then [skip the view
 transition](#skip-the-view-transition) for `transition` with an
 \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) in `transition`'s [relevant
 Realm](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-realm), and return.

 The above steps will require running document
 lifecycle phases, to compute information calculated during
 style/layout.

8. Set `transition`'s
 [phase](#viewtransition-phase) to \"`animating`\".

9. [Resolve](https://webidl.spec.whatwg.org/#resolve) `transition`'s [ready
 promise](#viewtransition-ready-promise).

#### 7.3.1. [Capture the old state]
To [capture the old state] for
[`ViewTransition`](#viewtransition) `transition`:

1. Let `document` be `transition`'s [relevant
 global
 object's](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global) [associated
 document](https://html.spec.whatwg.org/multipage/nav-history-apis.html#concept-document-window).

2. Let `namedElements` be `transition`'s [named
 elements](#viewtransition-named-elements).

3. Let `usedTransitionNames` be a new
 [set](https://infra.spec.whatwg.org/#ordered-set) of strings.

4. Let `captureElements` be a new
 [list](https://infra.spec.whatwg.org/#list) of elements.

5. If the [snapshot containing block
 size](#snapshot-containing-block-size) exceeds an
 [implementation-defined](https://infra.spec.whatwg.org/#implementation-defined) maximum, then return failure.

6. Set `transition`'s [initial snapshot containing block
 size](#viewtransition-initial-snapshot-containing-block-size) to the [snapshot containing block
 size](#snapshot-containing-block-size).

7. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `element` of every
 [element](https://drafts.csswg.org/css2/#element) that is
 [connected](https://dom.spec.whatwg.org/#connected), and has a [node
 document](https://dom.spec.whatwg.org/#concept-node-document) equal to `document`, in [paint
 order](https://drafts.csswg.org/css2/#painting-order):

 :::
 We iterate in paint order to ensure that this order is cached in
 `namedElements`. This defines the DOM order for
 [::view-transition-group]
 [pseudo-elements](https://drafts.csswg.org/selectors-4/#pseudo-element), such that the element at the bottom of the paint
 stack generates the first pseudo child of
 [::view-transition](#selectordef-view-transition).
 :::

 1. If any [flat
 tree](https://drafts.csswg.org/css-shadow-1/#flat-tree) ancestor of this `element` [skips
 its
 contents](https://drafts.csswg.org/css-contain-2/#skips-its-contents), then
 [continue](https://infra.spec.whatwg.org/#iteration-continue).

 2. If `element` has more than one [box
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

 3. Let `transitionName` be the `element`'s
 [document-scoped view transition
 name](#document-scoped-view-transition-name).

 4. If `transitionName` is
 [none](#valdef-view-transition-name-none), or `element` is [not
 rendered](https://drafts.csswg.org/css-images-4/#element-not-rendered), then
 [continue](https://infra.spec.whatwg.org/#iteration-continue).

 5. If `usedTransitionNames`
 [contains](https://infra.spec.whatwg.org/#list-contain) `transitionName`, then:

 1. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `element` in
 `captureElements`:

 1. Set `element`'s [captured in a view
 transition](#captured-in-a-view-transition) to false.

 2. return failure.

 6. [Append](https://infra.spec.whatwg.org/#set-append) `transitionName` to
 `usedTransitionNames`.

 7. Set `element`'s [captured in a view
 transition](#captured-in-a-view-transition) to true.

 8. [Append](https://infra.spec.whatwg.org/#list-append) `element` to
 `captureElements`.

 :::
 The algorithm continues in a separate loop to ensure that [captured
 in a view
 transition](#captured-in-a-view-transition) is set on all elements participating in this
 capture before it is read by future steps in the algorithm.
 :::

8. [For
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

9. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `element` in
 `captureElements`:

 1. Set `element`'s [captured in a view
 transition](#captured-in-a-view-transition) to false.

#### 7.3.2. [Capture the new state]
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

 8. Set `namedElements`\[`transitionName`\]\'s
 [new
 element](#captured-element-new-element) to `element`.

#### 7.3.3. [Setup transition pseudo-elements]
To [setup transition pseudo-elements] for a
[`ViewTransition`](#viewtransition) `transition`:

 This algorithm constructs the [pseudo-element
tree](#pseudo-element-tree) for the transition, and generates initial styles. The
structure of the pseudo-tree is covered at a higher level in [§ 3.2 View
Transition Pseudo-elements](#view-transition-pseudos).

1. Let `document` be `transition`'s [relevant
 global
 object's](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global) [associated
 document](https://html.spec.whatwg.org/multipage/nav-history-apis.html#concept-document-window).

2. Set `document`'s [show view transition
 tree](#document-show-view-transition-tree) to true.

3. [For
 each](https://infra.spec.whatwg.org/#map-iterate) `transitionName` →
 `capturedElement` of `transition`'s [named
 elements](#viewtransition-named-elements):

 1. Let `group` be a new
 [::view-transition-group()](#selectordef-view-transition-group), with its [view transition
 name](#view-transition-name) set to `transitionName`.

 2. Append `group` to `transition`'s
 [transition root
 pseudo-element](#viewtransition-transition-root-pseudo-element).

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
 [replaced](https://drafts.csswg.org/css-display-3/#replaced-element) content.

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

### 7.4. [Call the update callback]
To [call the update callback] of a
[`ViewTransition`](#viewtransition) `transition`:

 This is guaranteed to happen for every
[`ViewTransition`](#viewtransition), even if the transition is
[skipped](#skip-the-view-transition). The reasons for this are discussed in [§ 1.4
Transitions as an enhancement](#transitions-as-enhancements).

1. [Assert](https://infra.spec.whatwg.org/#assert): `transition`'s
 [phase](#viewtransition-phase) is \"`done`\", or before
 \"`update-callback-called`\".

2. If `transition`'s
 [phase](#viewtransition-phase) is not \"`done`\", then set
 `transition`'s [phase] to
 \"`update-callback-called`\".

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

### 7.5. [Skip the view transition]
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

5. If `document`'s [active view
 transition](#document-active-view-transition) is `transition`, [Clear view
 transition](#clear-view-transition) `transition`.

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

### 7.6. View transition page-visibility change steps

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
 transition] with
 an
 \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

 2. Otherwise,
 [assert](https://infra.spec.whatwg.org/#assert): [active view
 transition](#document-active-view-transition) is null.

 this is called from the HTML spec.

### 7.7. [Capture the image]
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
 element](https://drafts.csswg.org/css-display-3/#replaced-element) at its [natural
 size](https://drafts.csswg.org/css-images-3/#natural-size), it will display with the size and contents of
 element's [principal
 box](https://drafts.csswg.org/css-display-4/#principal-box), with any captured [ink
 overflow](https://drafts.csswg.org/css-overflow-3/#ink-overflow) overflowing its [content
 box](https://drafts.csswg.org/css-box-4/#content-box).

#### 7.7.1. [Capture rendering characteristics]
The [capture rendering
characteristics] are as follows:

- If the referenced element has a transform applied to it (or its
 ancestors), then the transform is ignored.

 This transform is applied to the snapshot using the
 `transform` property of the associated [::view-transition-group]
 [pseudo-element](https://drafts.csswg.org/selectors-4/#pseudo-element).

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
 transition](#captured-in-a-view-transition), then skip painting `descendant`.

 This is necessary since the descendant will generate
 its own snapshot which will be displayed and animated independently.

### 7.8. [Handle transition frame]
To [handle transition frame] given a
[`ViewTransition`](#viewtransition) `transition`:

1. Let `document` be `transition`'s [relevant
 global
 object's](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global) [associated
 document](https://html.spec.whatwg.org/multipage/nav-history-apis.html#concept-document-window).

2. Let `hasActiveAnimations` be a boolean, initially false.

3. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `element` of `transition`'s
 [transition root
 pseudo-element](#viewtransition-transition-root-pseudo-element)'s [inclusive
 descendants](https://dom.spec.whatwg.org/#concept-tree-inclusive-descendant):

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

4. If `hasActiveAnimations` is false:

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

### 7.9. [Update pseudo-element styles]
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
 transition](#captured-in-a-view-transition).

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
 element](https://drafts.csswg.org/css-display-3/#replaced-element) content to the result of [capturing the
 image](#capture-the-image) of `capturedElement`'s [new
 element](#captured-element-new-element).

This algorithm must be executed to update styles in [user-agent
origin](https://drafts.csswg.org/css-cascade-5/#cascade-origin-ua) if its effects can be observed by a web API.

 An example of such a web API is
`window.getComputedStyle(document.documentElement, "::view-transition")`.

### 7.10. [Clear view transition]
To [clear view transition] of a
[`ViewTransition`](#viewtransition) `transition`:

1. Let `document` be `transition`'s [relevant
 global
 object's](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global) [associated
 document](https://html.spec.whatwg.org/multipage/nav-history-apis.html#concept-document-window).

2. [Assert](https://infra.spec.whatwg.org/#assert): `document`'s [active view
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
 transition](#captured-in-a-view-transition) to false.

 2. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `style` of
 `capturedElement`'s [style
 definitions](#captured-element-style-definitions):

 1. If `style` is not null, and `style` is
 in `document`'s [dynamic view transition style
 sheet](#document-dynamic-view-transition-style-sheet), then remove `style` from
 `document`'s [dynamic view transition style
 sheet].

4. Set `document`'s [show view transition
 tree](#document-show-view-transition-tree) to false.

5. Set `document`'s [active view
 transition](#document-active-view-transition) to null.

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

## [Appendix A. Changes]
This appendix is *informative*.

### [ Changes from [2024-03-28 Candidate Recommendation Draft](https://www.w3.org/TR/2024/CRD-css-view-transitions-1-20240328/) ]
- Update wording to use `opacity: 0` instead of `visibility: hidden`.
 See [issue 12629](https://github.com/w3c/csswg-drafts/issues/12629).

- Always flush the queue of update callbacks before capturing the old
 state. See [issue
 11922](https://github.com/w3c/csswg-drafts/issues/11292).

- Disallow [match-element] as a custom-ident. See [Issue
 10995](https://github.com/w3c/csswg-drafts/issues/10995).

- Add a non-normative note to explain that
 [::view-transition-image-pair()](#selectordef-view-transition-image-pair) would typically not need custom styling. See
 [issue
 11926](https://github.com/w3c/csswg-drafts/issues/11926#issuecomment-2916977161)

- Inherit more animation properties into [pseudo-element
 tree](#pseudo-element-tree). See [Issue
 11546](https://github.com/w3c/csswg-drafts/issues/11546).

- Use `position: absolute` instead of `position: fixed` on
 [::view-transition](#selectordef-view-transition). See [Issue
 12116](https://github.com/w3c/csswg-drafts/issues/12116).

### [ Changes from [2023-05-30 Working Draft](https://www.w3.org/TR/2023/WD-css-view-transitions-1-20230530/) ]
- Use a keyframe to add plus-lighter blending during cross-fade. See
 [issue 8924](https://github.com/w3c/csswg-drafts/issues/8924).

- Add mix-blend-mode to list of properties copied over to the
 [::view-transition-group]. See [issue
 8962](https://github.com/w3c/csswg-drafts/issues/8962).

- Add text-orientation to list of properties copied over to the
 [::view-transition-group]. See [issue
 8230](https://github.com/w3c/csswg-drafts/issues/8230).

- Refactor the old capture algorithm to properly set [captured in a view
 transition](#captured-in-a-view-transition) before reading the value.

- Make the
 [`startViewTransition()`](#dom-document-startviewtransition) parameter non-nullable. See [issue
 9460](https://github.com/w3c/csswg-drafts/issues/9460).

- Elements participating in a [view
 transition](#view-transitions) are exposed to accessibility tree. See [issue
 9365](https://github.com/w3c/csswg-drafts/issues/9365).

- The [view transition
 tree](#view-transition-tree) is not exposed to accessibility tree. See [issue
 9365](https://github.com/w3c/csswg-drafts/issues/9365).

- Animate back-drop filter similar to transform/size. See [issue
 9358](https://github.com/w3c/csswg-drafts/issues/9358).

- Copy `color-scheme` from DOM element to
 [::view-transition-group()](#selectordef-view-transition-group). See [issue
 9276](https://github.com/w3c/csswg-drafts/issues/9276).

- Expose auto-skip view transition for a
 [`Document`](https://dom.spec.whatwg.org/#document), to allow having outbound cross-document transitions
 preceed programmatic view transiitons. see [issue
 9512](https://github.com/w3c/csswg-drafts/issues/9512).

- Add a note about why
 [view-transition-name](#propdef-view-transition-name) should be animatable.

- `view-transition-name: auto` should be an invalid value. See [issue
 9639](https://github.com/w3c/csswg-drafts/issues/9639).

- Add note to explain paint order for entry animations. See [issue
 9672](https://github.com/w3c/csswg-drafts/issues/9672).

- Add note to explain how the named elements are cleaned up. See [issue
 9669](https://github.com/w3c/csswg-drafts/issues/9669).

- Refactor algorithm to clarify timing, especially of
 \`updateCallbackDone. See [issue
 9762](https://github.com/w3c/csswg-drafts/issues/9762).

- Add animation-delay inherit to UA stylesheet rules for
 (::view-transition) -image-pair, -old, and -new. See [issue
 9817](https://github.com/w3c/csswg-drafts/issues/9817).

- Auto-skip animation when document is hidden. See [issue
 9543](https://github.com/w3c/csswg-drafts/issues/9543).

- Remove references to cross-document view-transitions, to keep the L1
 spec clean. See [Issue
 9886](https://github.com/w3c/csswg-drafts/issues/9886).

- Export an algorithm to skip the active transition when the page is
 hidden. See [issue
 9543](https://github.com/w3c/csswg-drafts/issues/9543).

- Use snapshot containing block when capturing new state for document
 element. See [issue
 #10177](https://github.com/w3c/csswg-drafts/issues/10177).

- Fix algorithm for dispatching updateDOMCallback promise.

- Scope view transition names to matching tree context. See [issue
 10145](https://github.com/w3c/csswg-drafts/issues/10145).

- Fix scoping to match name instead of element. See [issue
 10145](https://github.com/w3c/csswg-drafts/issues/10145).

- Add a rendering characteristics note about out-of-viewport elements.
 See [issue 8282](https://github.com/w3c/csswg-drafts/issues/8282).

- Swap the order of invoking the update callback and setting the phase.
 See [issue 10822](https://github.com/w3c/csswg-drafts/issues/10822).

### [ Changes from [2023-05-25 Working Draft](https://www.w3.org/TR/2023/WD-css-view-transitions-1-20230525/) ]
- Fix typo in ::view-transition-new user agent style sheet. See
 [PR](https://github.com/w3c/csswg-drafts/pull/8879).

### [ Changes from [2022-11-24 Working Draft](https://www.w3.org/TR/2022/WD-css-view-transitions-1-20221124/) ]
- Pointer events resolve to the documentElement when rendering is
 suppressed. See [issue
 7797](https://github.com/w3c/csswg-drafts/issues/7797).

- Add rendering constraints to elements participating in a transition.
 See [issue 8139](https://github.com/w3c/csswg-drafts/issues/8139) and
 [issue 7882](https://github.com/w3c/csswg-drafts/issues/7882).

- Remove html specifics from UA stylesheet to support ViewTransitions on
 SVG Documents.

- Rename updateDOMCallback to
 [`ViewTransitionUpdateCallback`](#callbackdef-viewtransitionupdatecallback). See [issue
 8144](https://github.com/w3c/csswg-drafts/issues/8144).

- Rename snapshot viewport to [snapshot containing
 block](#snapshot-containing-block).

- Skip the transition if viewport size changes. See [issue
 8045](https://github.com/w3c/csswg-drafts/issues/8045).

- Add support for :only-child. See [issue
 8057](https://github.com/w3c/csswg-drafts/issues/8057).

- Add concept of a tree of
 [pseudo-elements](https://drafts.csswg.org/selectors-4/#pseudo-element) under [pseudo-element
 root](#pseudo-element-root). See [issue
 8113](https://github.com/w3c/csswg-drafts/issues/8113).

- When skipping a transition, the
 [`ViewTransitionUpdateCallback`](#callbackdef-viewtransitionupdatecallback) is called in own task rather than synchronously. See
 [issue 7904](https://github.com/w3c/csswg-drafts/issues/7904)

- When capturing images, at least the in-viewport part of the image
 should be captured, downscale if needed. See [issue
 8561](https://github.com/w3c/csswg-drafts/issues/8561).

- Applying the [ink
 overflow](https://drafts.csswg.org/css-overflow-3/#ink-overflow) to the captured image is implementation defined, and
 doesn't affect the image's [natural
 size](https://drafts.csswg.org/css-images-3/#natural-size). See [issue
 8597](https://github.com/w3c/csswg-drafts/issues/8597).

- Fragmented elements don't participate in view transitions. See [issue
 8339](https://github.com/w3c/csswg-drafts/issues/8339).

- Rename \"snapshot root\" to \"snapshot containing block\", and make it
 an [absolute positioning containing
 block](https://drafts.csswg.org/css-position-3/#absolute-positioning-containing-block) and a [fixed positioning containing
 block](https://drafts.csswg.org/css-position-3/#fixed-positioning-containing-block) for its descendants. See [issue
 8505](https://github.com/w3c/csswg-drafts/issues/8505).

### [ Changes from [2022-10-25 Working Draft (FPWD)](https://www.w3.org/TR/2022/WD-css-view-transitions-1-20221025/) ]
- Add [dynamic view transition style
 sheet](#document-dynamic-view-transition-style-sheet) concept for dynamically generated UA styles scoped to
 the current Document.

- Add snapshot viewport concept. See [issue
 7859](https://github.com/w3c/csswg-drafts/issues/7859).

- Clarify timing for resolving/rejecting promises when skipping the
 transition. See [issue
 7956](https://github.com/w3c/csswg-drafts/issues/7956).

- Elements under a content-visibility:auto element that skips its
 contents are ignored. See [issue
 7874](https://github.com/w3c/csswg-drafts/issues/7874).

- UA styles on the pseudo-DOM stay in sync with author DOM for any
 developer observable API. See [issue
 7812](https://github.com/w3c/csswg-drafts/issues/7812).

- Suppress rendering during updateCallback. See [issue
 7784](https://github.com/w3c/csswg-drafts/issues/7784).

- Changes in size/position of elements in the new Document generate new
 UA animation keyframes. See [issue
 7813](https://github.com/w3c/csswg-drafts/issues/7813).

- Scope keyframes to user agent stylesheets using -ua- prefix. See
 [issue 7560](https://github.com/w3c/csswg-drafts/issues/7560).

- Update
 [pseudo-element](https://drafts.csswg.org/selectors-4/#pseudo-element) names to view-transition\*. See [issue
 7960](https://github.com/w3c/csswg-drafts/issues/7960).

- Update selector syntax for
 [pseudo-elements](https://drafts.csswg.org/selectors-4/#pseudo-element). See [issue
 7788](https://github.com/w3c/csswg-drafts/issues/7788).

- Add sections for security/privacy considerations.
