## 1. Introduction

This specification defines mechanisms for driving the progress of an
animation based on the scroll progress of a scroll container. These
[scroll-driven animations] use a timeline based on scroll position,
rather than one based on clock time. This module provides both an
imperative API building on the Web Animations API as well as a
declarative API building on CSS Animations.
[\[WEB-ANIMATIONS-1\]](#biblio-web-animations-1 "Web Animations")

There are two types of [scroll-driven
timelines]:

- [Scroll Progress Timelines](#scroll-timelines), which are linked to
 the scroll progress of a particular [scroll
 container](https://drafts.csswg.org/css-overflow-3/#scroll-container)

- [View Progress Timelines](#view-timelines), which are linked to the
 view progress of a particular
 [box](https://drafts.csswg.org/css-display-4/#box) through a
 [scrollport](https://drafts.csswg.org/css-overflow-3/#scrollport)

 Scroll-*driven* animations, whose progress is linked to
the scroll position, are distinct from scroll-*triggered* animations,
which are triggered by a scroll position, but whose progress is driven
by time.

### 1.1. Relationship to other specifications

Web Animations
[\[WEB-ANIMATIONS-1\]](#biblio-web-animations-1 "Web Animations")
defines an abstract conceptual model for animations on the Web platform,
with elements of the model including
[animations](https://drafts.csswg.org/web-animations-1/#concept-animation) and their
[timelines](https://drafts.csswg.org/web-animations-1/#timeline), and associated programming interfaces. This
specification extends the Web Animations model by defining
[scroll-driven
timelines](#scroll-driven-timelines) and allowing them to drive progress in
[animations] to create [scroll-driven
animations](#scroll-driven-animations).

This specification introduces both programming interfaces for
interacting with these concepts, as well as CSS properties that apply
these concepts to CSS Animations
[\[CSS-ANIMATIONS-1\]](#biblio-css-animations-1 "CSS Animations Level 1").
To the extent the behavior of these CSS properties is described in terms
of the programming interfaces, [User
agents](https://infra.spec.whatwg.org/#user-agent) that do not support scripting may still conform to this
specification by implementing the CSS features to behave as if the
underlying programming interfaces were in place.

Like most operations in CSS besides
[selector](https://drafts.csswg.org/selectors-4/#selector) matching, features in this specification operate over
the [flattened element
tree](https://drafts.csswg.org/css-shadow-1/#flat-tree).

### 1.2. Relationship to asynchronous scrolling

Some user agents support scrolling that is asynchronous with respect to
layout or script. This specification is intended to be compatible with
such an architecture.

Specifically, this specification allows expressing scroll-driven effects
in a way that does not require script to run each time the effect is
sampled. User agents that support asynchronous scrolling are allowed
(but not required) to sample such effects asynchronously as well.

### 1.3. Value Definitions

This specification follows the [CSS property definition
conventions](https://www.w3.org/TR/CSS2/about.html#property-defs) from
[\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")
using the [value definition
syntax](https://www.w3.org/TR/css-values-3/#value-defs) from
[\[CSS-VALUES-3\]](#biblio-css-values-3 "CSS Values and Units Module Level 3").
Value types not defined in this specification are defined in CSS Values
& Units
[\[CSS-VALUES-3\]](#biblio-css-values-3 "CSS Values and Units Module Level 3").
Combination with other CSS modules may expand the definitions of these
value types.

In addition to the property-specific values listed in their definitions,
all properties defined in this specification also accept the [CSS-wide
keywords](https://drafts.csswg.org/css-values-4/#css-wide-keywords) as their property value. For readability they have not
been repeated explicitly.

## 2. Scroll Progress Timelines

[Scroll progress timelines] are timelines linked to progress in the scroll
position of a [scroll
container](https://drafts.csswg.org/css-overflow-3/#scroll-container) along a [scrollable
axis](https://drafts.csswg.org/css-overflow-3/#scrollable-axis). The startmost scroll position represents 0% progress
and the endmost scroll position represents 100% progress.

[Scroll progress
timelines](#scroll-progress-timelines) can be referenced in
[animation-timeline](https://drafts.csswg.org/css-animations-2/#propdef-animation-timeline) anonymously using the
[scroll()](#funcdef-scroll) [functional
notation](https://drafts.csswg.org/css-values-4/#functional-notation) or by name (see [§ 4.2 Named Timeline Scoping and
Lookup](#timeline-scoping)) after declaring them using the
[scroll-timeline](#propdef-scroll-timeline) properties. In the Web Animations
API, they can be represented anonymously by a
[`ScrollTimeline`](#scrolltimeline) object.

### 2.1. Calculating Progress for a Scroll Progress Timeline

Progress (the [current
time](https://drafts.csswg.org/web-animations-1/#timeline-current-time)) for a [scroll progress
timeline](#scroll-progress-timelines) is calculated as:
[`scroll offset`](https://drafts.csswg.org/css-overflow-3/#scroll-offset) ÷
([`scrollable overflow`](https://drafts.csswg.org/css-overflow-3/#scrollable-overflow)` size` −
[`scroll container`](https://drafts.csswg.org/css-overflow-3/#scroll-container)` size`)

If the 0% position and 100% position coincide (i.e. the denominator in
the [current
time](https://drafts.csswg.org/web-animations-1/#timeline-current-time) formula is zero), the timeline is
[inactive](https://drafts.csswg.org/web-animations-1/#inactive-timeline).

In [paged
media](https://drafts.csswg.org/mediaqueries-5/#paged-media), [scroll progress
timelines](#scroll-progress-timelines) that would otherwise reference the document viewport
are also
[inactive](https://drafts.csswg.org/web-animations-1/#inactive-timeline).

### 2.2. Anonymous Scroll Progress Timelines

#### 2.2.1. The [scroll() notation]
The [scroll()] functional notation can be used as a
[\<single-animation-timeline\>](https://drafts.csswg.org/css-animations-2/#typedef-single-animation-timeline) value in
[animation-timeline](https://drafts.csswg.org/css-animations-2/#propdef-animation-timeline) and specifies a [scroll progress
timeline](#scroll-progress-timelines). Its syntax is

``` prod
<scroll()> = scroll( [ <scroller> || <axis> ]? )
<axis> = block | inline | x | y
<scroller> = root | nearest | self
```

By default, [scroll()](#funcdef-scroll) references the [block
axis](https://drafts.csswg.org/css-writing-modes-4/#block-axis) of the nearest ancestor [block-axis scroll
container](https://drafts.csswg.org/css-overflow-3/#block-axis-scroll-container). Its arguments modify this lookup as follows:

[block]
: Specifies to use the measure of progress along the [block
 axis](https://drafts.csswg.org/css-writing-modes-4/#block-axis) of the [block-axis scroll
 container](https://drafts.csswg.org/css-overflow-3/#block-axis-scroll-container). (Default.)

[inline]
: Specifies to use the measure of progress along the [inline
 axis](https://drafts.csswg.org/css-writing-modes-4/#inline-axis) of the [inline-axis scroll
 container](https://drafts.csswg.org/css-overflow-3/#inline-axis-scroll-container).

[x]
: Specifies to use the measure of progress along the [horizontal
 axis](https://drafts.csswg.org/css-writing-modes-4/#x-axis) of the [x-axis scroll
 container](https://drafts.csswg.org/css-overflow-3/#x-axis-scroll-container).

[y]
: Specifies to use the measure of progress along the [vertical
 axis](https://drafts.csswg.org/css-writing-modes-4/#y-axis) of the [y-axis scroll
 container](https://drafts.csswg.org/css-overflow-3/#y-axis-scroll-container).

[nearest]
: Specifies to use the nearest ancestor [scroll
 container](https://drafts.csswg.org/css-overflow-3/#scroll-container) with an appropriate [scrollable
 axis](https://drafts.csswg.org/css-overflow-3/#scrollable-axis) (Default.)

[root]
: Specifies to use the document viewport as the [scroll
 container](https://drafts.csswg.org/css-overflow-3/#scroll-container).

[self]
: Specifies to use the element's own [principal
 box](https://drafts.csswg.org/css-display-4/#principal-box) as the [scroll
 container](https://drafts.csswg.org/css-overflow-3/#scroll-container). If the [principal box] is
 not a [scroll container] in the
 appropriate axis, then the [scroll progress
 timeline](#scroll-progress-timelines) is
 [inactive](https://drafts.csswg.org/web-animations-1/#inactive-timeline).

 Progress is in reference to the [scroll
origin](https://drafts.csswg.org/css-overflow-3/#scroll-origin), which can flip depending on [writing
mode](https://drafts.csswg.org/css-writing-modes-4/#writing-mode), even when
[x](#valdef-scroll-x)
or [y](#valdef-scroll-y) is specified.

References to the [root
element](https://drafts.csswg.org/css-display-4/#root-element) propagate to the document viewport (which functions as
its [scroll
container](https://drafts.csswg.org/css-overflow-3/#scroll-container)).

Consider the following style sheet and
markup:

```
@keyframes change-background {
 from { background-color: aliceblue; }
 to { background-color: cornflowerblue; }
}

.subject {
 animation: change-background linear both;
 /* Use an anonymous scroll progress timeline to drive the animation */
 animation-timeline: scroll();
}
```

```
<html>
 …
 <body>
 <!-- Note: .scroller is a scrollable box -->
 <div class="scroller">
 …
 <div class="subject">Animation Subject</div>
 …
 </div>
 </body>
</html>
```

The `.subject`'s animation is set up to be driven by an anonymous
[Scroll progress
timeline](#scroll-progress-timelines) created with
[scroll()](#funcdef-scroll). Because no
[\<scroller\>](#typedef-scroller) or
[\<axis\>](#typedef-axis) are passed into the function, the default values of
[nearest](#valdef-scroll-nearest) and
[block](#valdef-scroll-block) respectively are used.

Because `.scroller` is the nearest ancestor [scroll
container](https://drafts.csswg.org/css-overflow-3/#scroll-container), this results in the `.scroller` element driving the
animation: as you scroll `.scroller` up and down, the subject's
animations progress moves forwards or backwards in direct response.

This results in the `background-color` being `aliceblue` when at the
start of the scroller and `cornflowerblue` when scrolled to the very
end. Intermediary scroll positions results in an interpolated value.

Building on the previous example,
changing the
[animation-timeline](https://drafts.csswg.org/css-animations-2/#propdef-animation-timeline) to the following results in the
document viewport driving the animation progress.

```
.subject {
 animation: change-background linear both;
 animation-timeline: scroll(root);
}
```

The following declarations for
[animation-timeline](https://drafts.csswg.org/css-animations-2/#propdef-animation-timeline) are all equivalent but some are
more explicit about what to target:

```
/* These all are equivalent */
animation-timeline: scroll();
animation-timeline: scroll(block);
animation-timeline: scroll(nearest);
animation-timeline: scroll(block nearest);
animation-timeline: scroll(nearest block);
```

This is because the default values for
[\<scroller\>](#typedef-scroller) and
[\<axis\>](#typedef-axis) are
[nearest](#valdef-scroll-nearest) and
[block](#valdef-scroll-block) respectively.

To animate the scroller itself, use
the [self](#valdef-scroll-self) keyword as the
[\<scroller\>](#typedef-scroller)

```
@keyframes change-color {
 from { color: black; }
 to { color: hotpink; }
}

.subject {
 animation: change-color linear both;
 /* Use an anonymous scroll progress timeline to drive the animation */
 animation-timeline: scroll(self);
}
```

Each use of [scroll()](#funcdef-scroll) corresponds to its own instance of
[`ScrollTimeline`](#scrolltimeline) in the Web Animations API, even if multiple elements
use [scroll()] to refer to the same
[scroll
container](https://drafts.csswg.org/css-overflow-3/#scroll-container) with the same arguments.

#### 2.2.2. The [`ScrollTimeline` Interface]
```
enum ScrollAxis {
 "block",
 "inline",
 "x",
 "y"
};

dictionary ScrollTimelineOptions {
 Element? source;
 ScrollAxis axis = "block";
};

[Exposed=Window]
interface ScrollTimeline : AnimationTimeline {
 constructor(optional ScrollTimelineOptions options = );
 readonly attribute Element? source;
 readonly attribute ScrollAxis axis;
};
```

A [`ScrollTimeline`](#scrolltimeline) is an
[`AnimationTimeline`](https://drafts.csswg.org/web-animations-1/#animationtimeline) that represents a [scroll progress
timeline](#scroll-progress-timelines). It can be passed to the
[`Animation`](https://drafts.csswg.org/web-animations-1/#animation) constructor or the
[`animate()`](https://drafts.csswg.org/web-animations-1/#dom-animatable-animate) method to link the animation to a [scroll progress
timeline].

[`source`], of type [Element](https://dom.spec.whatwg.org/#element), readonly, nullable

: The [scroll
 container](https://drafts.csswg.org/css-overflow-3/#scroll-container) element whose scroll position drives the progress
 of the timeline.

[`axis`], of type [ScrollAxis](#enumdef-scrollaxis), readonly

: The axis of scrolling that drives the progress of the timeline. See
 value definitions for
 [\<axis\>](#typedef-axis), above.

Inherited attributes:

[`currentTime`](https://drafts.csswg.org/web-animations-1/#dom-animationtimeline-currenttime) (inherited from [`AnimationTimeline`](https://drafts.csswg.org/web-animations-1/#animationtimeline))

: Represents the scroll progress of the [scroll
 container](https://drafts.csswg.org/css-overflow-3/#scroll-container) as a percentage CSSUnitValue, with 0% representing
 its startmost scroll position (in the [writing
 mode](https://drafts.csswg.org/css-writing-modes-4/#writing-mode) of the [scroll
 container]). Null when the timeline is
 [inactive](https://drafts.csswg.org/web-animations-1/#inactive-timeline).

While 0% will usually represent the
[scroll
container](https://drafts.csswg.org/css-overflow-3/#scroll-container)'s initial scroll position, it might not depending on
its [content
distribution](https://drafts.csswg.org/css-align-3/#content-distribute). See [CSS Box Alignment 3 § 5.3 Alignment Overflow and
Scroll
Containers](https://drafts.csswg.org/css-align-3/#overflow-scroll-position).
Is this what we want?

Add a note about whether
[`currentTime`](https://drafts.csswg.org/web-animations-1/#dom-animationtimeline-currenttime) can be negative or \> 100%.

[`ScrollTimeline(options)`]

: Creates a new
 [`ScrollTimeline`](#scrolltimeline) object using the following procedure:

 1. Let `timeline` be the new
 [`ScrollTimeline`](#scrolltimeline) object.

 2. Set the
 [`source`](#dom-scrolltimeline-source) of `timeline` to:

 If the `source` member of `options` is present,

 : The `source` member of `options`.

 Otherwise,

 : The
 [`scrollingElement`](https://drafts.csswg.org/cssom-view-1/#dom-document-scrollingelement) of the
 [`Document`](https://dom.spec.whatwg.org/#document)
 [associated](https://html.spec.whatwg.org/multipage/window-object.html#concept-document-window) with the
 [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window) that is the [current global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#current-global-object).

 3. Set the
 [`axis`](#dom-scrolltimeline-axis) property of `timeline` to the
 corresponding value from `options`.

If the
[`source`](#dom-scrolltimeline-source) of a
[`ScrollTimeline`](#scrolltimeline) is an element whose [principal
box](https://drafts.csswg.org/css-display-4/#principal-box) does not exist or is not a [scroll
container](https://drafts.csswg.org/css-overflow-3/#scroll-container) in the timeline's axis, or if there is no [scrollable
overflow](https://drafts.csswg.org/css-overflow-3/#scrollable-overflow), then the
[`ScrollTimeline`](#scrolltimeline) is
[inactive](https://drafts.csswg.org/web-animations-1/#inactive-timeline).

A [`ScrollTimeline`](#scrolltimeline)'s
[`duration`](https://drafts.csswg.org/web-animations-2/#dom-animationtimeline-duration) is 100%.

The values of
[`source`](#dom-scrolltimeline-source) and
[`currentTime`](https://drafts.csswg.org/web-animations-1/#dom-animationtimeline-currenttime) are both computed when either is requested or updated.

In the following example, a
[`ScrollTimeline`](#scrolltimeline) instance that tracks the document viewport in the block
direction is created:

```
const myTimeline = new ScrollTimeline({
 source: document.documentElement,
});
```

The created
[`ScrollTimeline`](#scrolltimeline) instance can be used to animate an element as follows:

```
const progressbar = document.querySelector('#progress');

progressbar.animate(
 {
 transform: ['scaleX(0)', 'scaleX(1)'],
 },
 {
 fill: 'forwards',
 timeline: myTimeline,
 }
);
```

This makes the targeted `#progress` element animate from a `scaleX(0)`
transform when at the top of the page to a `scaleX(1)` when at the
bottom of the page.

In this example, the `.scroller`
element is the element whose scroll position drives the progress of the
timeline. The timeline is set to track its scroll offset in the inline
direction.

```
const scroller = document.querySelector('.scroller');

const myTimeline = new ScrollTimeline({
 source: scroller,
 axis: 'inline',
});
```

Scrolling the root scroller has no effect here, it is only when you
scroll the `.scroller` element in the inline direcion that the animation
that uses the timeline will tick.

### 2.3. Named Scroll Progress Timelines

[Scroll progress
timelines](#scroll-progress-timelines) can also be defined on the [scroll
container](https://drafts.csswg.org/css-overflow-3/#scroll-container) itself, and then referenced by name by elements within
the name's scope (see [§ 4.2 Named Timeline Scoping and
Lookup](#timeline-scoping)).

Such [named scroll progress timelines] are declared in the
[coordinated value
list](https://drafts.csswg.org/css-values-4/#coordinated-value-list) constructed from the
[longhands](https://drafts.csswg.org/css-cascade-5/#longhand) of the
[scroll-timeline](#propdef-scroll-timeline) [shorthand
property](https://drafts.csswg.org/css-cascade-5/#shorthand-property), which form a [coordinating list property
group](https://drafts.csswg.org/css-values-4/#coordinating-list-property) with
[scroll-timeline-name](#propdef-scroll-timeline-name) as the [coordinating list base
property](https://drafts.csswg.org/css-values-4/#coordinating-list-base-property). See [CSS Values 4 § A Coordinating List-Valued
Properties](https://drafts.csswg.org/css-values-4/#linked-properties).

In the following example the
`.subject`'s animation is driven by the [named scroll progress
timeline](#named-scroll-progress-timelines) named `--my-scroller`. This timeline is created on its
`.scroller` ancestor and is set up to measure progress along the [inline
axis](https://drafts.csswg.org/css-writing-modes-4/#inline-axis):

```
.scroller {
 scroll-timeline-name: --my-scroller;
 scroll-timeline-axis: inline;
}

.scroller .subject {
 animation: grow linear both;
 /* Use the '--my-scroller' scroll progress timeline to drive the animation */
 animation-timeline: --my-scroller;
}
```

As you scroll horizontally through the `.scroller` element, the `grow`
animation on the contained `.subject` element will move forwards or
backwards in direct response.

#### 2.3.1. Naming a Scroll Progress Timeline: the [scroll-timeline-name property]
Name:

[scroll-timeline-name]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

\[ none
[\|](https://drafts.csswg.org/css-values-4/#comb-one)
[\<dashed-ident\>](https://drafts.csswg.org/css-values-4/#typedef-dashed-ident)
\][\#](https://drafts.csswg.org/css-values-4/#mult-comma)

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

list, each item either a [CSS
identifier](https://drafts.csswg.org/css-values-4/#css-css-identifier) or the keyword [none]

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

not animatable

Specifies names for the [named scroll progress
timelines](#named-scroll-progress-timelines) associated with this element.

#### 2.3.2. Axis of a Scroll Progress Timeline: the [scroll-timeline-axis property]
Name:

[scroll-timeline-axis]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

\[ block
[\|](https://drafts.csswg.org/css-values-4/#comb-one) inline [\|] x
[\|] y
\][\#](https://drafts.csswg.org/css-values-4/#mult-comma)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

block

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[all
elements](https://www.w3.org/TR/css-pseudo/#generated-content "Includes ::before and ::after pseudo-elements.")

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

a list of the keywords specified

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

not animatable

Specifies the axis of any [named scroll progress
timelines](#named-scroll-progress-timelines) sourced from this [scroll
container](https://drafts.csswg.org/css-overflow-3/#scroll-container). If this box is not a [scroll
container] in the specified axis, then the
corresponding [named scroll progress
timeline] is
[inactive](https://drafts.csswg.org/web-animations-1/#inactive-timeline).

Values are as defined for
[scroll()](#funcdef-scroll).

#### 2.3.3. Scroll Timeline Shorthand: the [scroll-timeline shorthand]
Name:

[scroll-timeline]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

\[
[\<\'scroll-timeline-name\'\>](#propdef-scroll-timeline-name)
[\<\'scroll-timeline-axis\'\>](#propdef-scroll-timeline-axis)[?](https://drafts.csswg.org/css-values-4/#mult-opt)
\][\#](https://drafts.csswg.org/css-values-4/#mult-comma)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

see individual properties

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[all
elements](https://www.w3.org/TR/css-pseudo/#generated-content "Includes ::before and ::after pseudo-elements.")

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

see individual properties

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

see individual properties

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

not animatable

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

This property is a
[shorthand](https://drafts.csswg.org/css-cascade-5/#shorthand-property) for setting
[scroll-timeline-name](#propdef-scroll-timeline-name) and
[scroll-timeline-axis](#propdef-scroll-timeline-axis) in a single declaration.

The following two rules are
equivalent:

```
.scroller {
 scroll-timeline-name: --my-scroller;
 scroll-timeline-axis: inline;
}
```

```
.scroller {
 scroll-timeline: --my-scroller inline;
}
```

## 3. View Progress Timelines

Often animations are desired to start and end during the portion of the
[scroll progress
timeline](#scroll-progress-timelines) that a particular box (the [view progress
subject]) is in view within the
[scrollport](https://drafts.csswg.org/css-overflow-3/#scrollport). [View progress timelines] are segments of a [scroll
progress timeline] that are scoped
to the scroll positions in which any part of the subject element's
[principal
box](https://drafts.csswg.org/css-display-4/#principal-box) intersects its nearest ancestor
[scrollport] (or more precisely, the relevant
[view progress visibility
range](#view-progress-visibility-range) of that [scrollport]). The
startmost such scroll position represents 0% progress, and the endmost
such scroll position represents 100% progress; see [§ 3.2 Calculating
Progress for a View Progress Timeline](#view-timeline-progress).

 The 0% and 100% scroll positions are not always
reachable, e.g. if the box is positioned at the start edge of the
[scrollable overflow
rectangle](https://drafts.csswg.org/css-overflow-3/#scrollable-overflow-rectangle), it might not be possible to scroll to \< 32% progress.

[View progress
timelines](#view-progress-timelines) can be referenced anonymously using the
[view()](#funcdef-view)
[functional
notation](https://drafts.csswg.org/css-values-4/#functional-notation) or by name (see [§ 4.2 Named Timeline Scoping and
Lookup](#timeline-scoping)) after declaring them using the
[view-timeline](#propdef-view-timeline) properties on the [view progress
subject](#view-progress-subject). In the Web Animations API, they can be represented
anonymously by a
[`ViewTimeline`](#viewtimeline) object.

### 3.1. View Progress Timeline Ranges

[View progress
timelines](#view-progress-timelines) define the following [named timeline
ranges](#named-timeline-range):

[cover]
: Represents the full range of the [view progress
 timeline](#view-progress-timelines):
 - 0% progress represents the latest position at which the
 [start](https://drafts.csswg.org/css-writing-modes-4/#css-start) [border
 edge](https://drafts.csswg.org/css-box-4/#border-edge) of the element's [principal
 box](https://drafts.csswg.org/css-display-4/#principal-box) coincides with the
 [end](https://drafts.csswg.org/css-writing-modes-4/#css-end) edge of its [view progress visibility
 range](#view-progress-visibility-range).

 - 100% progress represents the earliest position at which the
 [end](https://drafts.csswg.org/css-writing-modes-4/#css-end) [border
 edge](https://drafts.csswg.org/css-box-4/#border-edge) of the element's [principal
 box](https://drafts.csswg.org/css-display-4/#principal-box) coincides with the
 [start](https://drafts.csswg.org/css-writing-modes-4/#css-start) edge of its [view progress visibility
 range](#view-progress-visibility-range).

[contain]
: Represents the range during which the [principal
 box](https://drafts.csswg.org/css-display-4/#principal-box) is either fully contained by, or fully covers, its
 [view progress visibility
 range](#view-progress-visibility-range) within the
 [scrollport](https://drafts.csswg.org/css-overflow-3/#scrollport).
 - 0% progress represents the earliest position at which either:

 - the
 [start](https://drafts.csswg.org/css-writing-modes-4/#css-start) [border
 edge](https://drafts.csswg.org/css-box-4/#border-edge) of the element's [principal
 box](https://drafts.csswg.org/css-display-4/#principal-box) coincides with the [start]
 edge of its [view progress visibility
 range](#view-progress-visibility-range).

 - the
 [end](https://drafts.csswg.org/css-writing-modes-4/#css-end) [border
 edge](https://drafts.csswg.org/css-box-4/#border-edge) of the element's [principal
 box](https://drafts.csswg.org/css-display-4/#principal-box) coincides with the [end]
 edge of its [view progress visibility
 range](#view-progress-visibility-range).

 - 100% progress represents the latest position at which either:

 - the
 [start](https://drafts.csswg.org/css-writing-modes-4/#css-start) [border
 edge](https://drafts.csswg.org/css-box-4/#border-edge) of the element's [principal
 box](https://drafts.csswg.org/css-display-4/#principal-box) coincides with the [start]
 edge of its [view progress visibility
 range](#view-progress-visibility-range).

 - the
 [end](https://drafts.csswg.org/css-writing-modes-4/#css-end) [border
 edge](https://drafts.csswg.org/css-box-4/#border-edge) of the element's [principal
 box](https://drafts.csswg.org/css-display-4/#principal-box) coincides with the [end]
 edge of its [view progress visibility
 range](#view-progress-visibility-range).

[entry]
: Represents the range during which the [principal
 box](https://drafts.csswg.org/css-display-4/#principal-box) is entering the [view progress visibility
 range](#view-progress-visibility-range).
 - 0% is equivalent to 0% of the
 [cover](#valdef-animation-timeline-range-cover) range.

 - 100% is equivalent to 0% of the
 [contain](#valdef-animation-timeline-range-contain) range.

[exit]
: Represents the range during which the [principal
 box](https://drafts.csswg.org/css-display-4/#principal-box) is exiting the [view progress visibility
 range](#view-progress-visibility-range).
 - 0% is equivalent to 100% of the
 [contain](#valdef-animation-timeline-range-contain) range.

 - 100% is equivalent to 100% of the
 [cover](#valdef-animation-timeline-range-cover) range.

[entry-crossing]
: Represents the range during which the [principal
 box](https://drafts.csswg.org/css-display-4/#principal-box) crosses the
 [end](https://drafts.csswg.org/css-writing-modes-4/#css-end) [border
 edge](https://drafts.csswg.org/css-box-4/#border-edge)
 - 0% progress represents the latest position at which the
 [start](https://drafts.csswg.org/css-writing-modes-4/#css-start) [border
 edge](https://drafts.csswg.org/css-box-4/#border-edge) of the element's [principal
 box](https://drafts.csswg.org/css-display-4/#principal-box) coincides with the
 [end](https://drafts.csswg.org/css-writing-modes-4/#css-end) edge of its [view progress visibility
 range](#view-progress-visibility-range).

 - 100% progress represents the earliest position at which the
 [end](https://drafts.csswg.org/css-writing-modes-4/#css-end) [border
 edge](https://drafts.csswg.org/css-box-4/#border-edge) of the element's [principal
 box](https://drafts.csswg.org/css-display-4/#principal-box) coincides with the [end] edge
 of its [view progress visibility
 range](#view-progress-visibility-range).

[exit-crossing]
: Represents the range during which the [principal
 box](https://drafts.csswg.org/css-display-4/#principal-box) crosses the
 [start](https://drafts.csswg.org/css-writing-modes-4/#css-start) [border
 edge](https://drafts.csswg.org/css-box-4/#border-edge)
 - 0% progress represents the latest position at which the
 [start](https://drafts.csswg.org/css-writing-modes-4/#css-start) [border
 edge](https://drafts.csswg.org/css-box-4/#border-edge) of the element's [principal
 box](https://drafts.csswg.org/css-display-4/#principal-box) coincides with the [start]
 edge of its [view progress visibility
 range](#view-progress-visibility-range).

 - 100% progress represents the earliest position at which the
 [end](https://drafts.csswg.org/css-writing-modes-4/#css-end) [border
 edge](https://drafts.csswg.org/css-box-4/#border-edge) of the element's [principal
 box](https://drafts.csswg.org/css-display-4/#principal-box) coincides with the
 [start](https://drafts.csswg.org/css-writing-modes-4/#css-start) edge of its [view progress visibility
 range](#view-progress-visibility-range).

[scroll]
: Represents the full range of the [scroll
 container](https://drafts.csswg.org/css-overflow-3/#scroll-container) on which the [view progress
 timeline](#view-progress-timelines) is defined.
 - 0% progress represents the startmost scroll position of the
 [scroll
 container](https://drafts.csswg.org/css-overflow-3/#scroll-container) underlying the [view progress
 timeline](#view-progress-timelines).

 - 100% progress represents the endmost scroll position of the
 [scroll
 container](https://drafts.csswg.org/css-overflow-3/#scroll-container) underlying the [view progress
 timeline](#view-progress-timelines).

Insert diagrams.

In all cases, the [writing
mode](https://drafts.csswg.org/css-writing-modes-4/#writing-mode) used to resolve the
[start](https://drafts.csswg.org/css-writing-modes-4/#css-start) and
[end](https://drafts.csswg.org/css-writing-modes-4/#css-end) sides is the [writing mode] of
the relevant [scroll
container](https://drafts.csswg.org/css-overflow-3/#scroll-container). [Transforms](http://www.w3.org/TR/css-transforms/) are
ignored, but
[relative](https://www.w3.org/TR/CSS2/visuren.html#x34) and
[absolute](https://drafts.csswg.org/css-position-3/#absolute-position) positioning are accounted for.

 For [sticky-positioned
boxes](https://drafts.csswg.org/css-position-3/#sticky-position) the 0% and 100% progress conditions can sometimes be
satisfied by a range of scroll positions rather than just one. Each
range therefore indicates whether to use the earliest or latest
qualifying position.

[\[CSS-POSITION-3\]](#biblio-css-position-3 "CSS Positioned Layout Module Level 3")
[\[CSS-TRANSFORMS-1\]](#biblio-css-transforms-1 "CSS Transforms Module Level 1")

### 3.2. Calculating Progress for a View Progress Timeline

Progress (the [current
time](https://drafts.csswg.org/web-animations-1/#timeline-current-time)) in a [view progress
timeline](#view-progress-timelines) is calculated as: `distance` ÷
`range` where:

- `distance` is the current [scroll
 offset](https://drafts.csswg.org/css-overflow-3/#scroll-offset) minus the [scroll offset]
 corresponding to the start of the
 [cover](#valdef-animation-timeline-range-cover) range

- `range` is the [scroll
 offset](https://drafts.csswg.org/css-overflow-3/#scroll-offset) corresponding to the end of the
 [cover](#valdef-animation-timeline-range-cover) range minus the [scroll
 offset] corresponding to the start of the
 [cover] range

If the 0% position and 100% position coincide (i.e. the denominator in
the [current
time](https://drafts.csswg.org/web-animations-1/#timeline-current-time) formula is zero), the timeline is
[inactive](https://drafts.csswg.org/web-animations-1/#inactive-timeline).

In [paged
media](https://drafts.csswg.org/mediaqueries-5/#paged-media), [view progress
timelines](#view-progress-timelines) that would otherwise reference the document viewport
are also
[inactive](https://drafts.csswg.org/web-animations-1/#inactive-timeline).

### 3.3. Anonymous View Progress Timelines

#### 3.3.1. The [view() notation]
The [view()] functional notation can be used as a
[\<single-animation-timeline\>](https://drafts.csswg.org/css-animations-2/#typedef-single-animation-timeline) value in
[animation-timeline](https://drafts.csswg.org/css-animations-2/#propdef-animation-timeline) and specifies a [view progress
timeline](#view-progress-timelines) in reference to the nearest ancestor [scroll
container](https://drafts.csswg.org/css-overflow-3/#scroll-container) that's scrollable in the specified axis. Its syntax is

``` prod
<view()> = view( [ <axis> || <'view-timeline-inset'> ]? )
```

By default, [view()](#funcdef-view) references the [block
axis](https://drafts.csswg.org/css-writing-modes-4/#block-axis); as for
[scroll()](#funcdef-scroll), this can be changed by providing an explicit
[\<axis\>](#typedef-axis) value.

The optional
[\<\'view-timeline-inset\'\>](#propdef-view-timeline-inset) value provides an adjustment of
the [view progress visibility
range](#view-progress-visibility-range), as defined for
[view-timeline-inset].

In the following example, each direct
child of the `.scroller` element will reveal itself as it crosses the
scrollport.

```
@keyframes reveal {
 from { opacity: 0; }
}

.scroller > * {
 animation: reveal linear both;
 animation-timeline: view();
}
```

For every element matched by the selector, a [view progress
timeline](#view-progress-timelines) gets created to drive the animation. Because no
arguments are passed into [view()](#funcdef-view) it uses the default values for
[\<axis\>](#typedef-axis) and
[\<\'view-timeline-inset\'\>](#propdef-view-timeline-inset), thus tracking its scroll
position in the [block
axis](https://drafts.csswg.org/css-writing-modes-4/#block-axis).

With the keyframes driven by the [view progress
timeline](#view-progress-timelines), the element will be at `opacity: 0` when it is about
to enter the scrollport, and at `opacity: 1` when it has just left the
scrollport. Any scroll position in between results in an interpolated
value.

 Because matched elements can be positioned at different
offsets within the scroller or can differ in size, every matched element
gets its own unique [view progress
timeline](#view-progress-timelines).

Each use of [view()](#funcdef-view) corresponds to its own instance of
[`ViewTimeline`](#viewtimeline) in the Web Animations API, even if multiple elements
use [view()] to reference the same element
with the same arguments.

#### 3.3.2. The [`ViewTimeline` Interface]
```
dictionary ViewTimelineOptions {
 required Element subject;
 ScrollAxis axis = "block";
 (DOMString or sequence<(CSSNumericValue or CSSKeywordValue)>) inset = "auto";
};

[Exposed=Window]
interface ViewTimeline : ScrollTimeline {
 constructor(ViewTimelineOptions options);
 readonly attribute Element subject;
 readonly attribute CSSNumericValue startOffset;
 readonly attribute CSSNumericValue endOffset;
};
```

A [`ViewTimeline`](#viewtimeline) is an
[`AnimationTimeline`](https://drafts.csswg.org/web-animations-1/#animationtimeline) that specifies a [view progress
timeline](#view-progress-timelines). It can be passed to the
[`Animation`](https://drafts.csswg.org/web-animations-1/#animation) constructor or the
[`animate()`](https://drafts.csswg.org/web-animations-1/#dom-animatable-animate) method to link the animation to a [view progress
timeline].

[`subject`], of type [Element](https://dom.spec.whatwg.org/#element), readonly

: The element whose [principal
 box](https://drafts.csswg.org/css-display-4/#principal-box)'s visibility in the
 [scrollport](https://drafts.csswg.org/css-overflow-3/#scrollport) defines the progress of the timeline.

[`startOffset`], of type [CSSNumericValue](https://drafts.css-houdini.org/css-typed-om-1/#cssnumericvalue), readonly

: Represents the starting (0% progress) scroll position of the [view
 progress
 timeline](#view-progress-timelines) as a length offset (in
 [px](https://drafts.csswg.org/css-values-4/#px)) from the [scroll
 origin](https://drafts.csswg.org/css-overflow-3/#scroll-origin). Null when the timeline is
 [inactive](https://drafts.csswg.org/web-animations-1/#inactive-timeline).

[`endOffset`], of type [CSSNumericValue](https://drafts.css-houdini.org/css-typed-om-1/#cssnumericvalue), readonly

: Represents the ending (100% progress) scroll position of the [view
 progress
 timeline](#view-progress-timelines) as a length offset (in
 [px](https://drafts.csswg.org/css-values-4/#px)) from the [scroll
 origin](https://drafts.csswg.org/css-overflow-3/#scroll-origin). Null when the timeline is
 [inactive](https://drafts.csswg.org/web-animations-1/#inactive-timeline).

 The values of
[`startOffset`](#dom-viewtimeline-startoffset) and
[`endOffset`](#dom-viewtimeline-endoffset) are relative to the [scroll
origin](https://drafts.csswg.org/css-overflow-3/#scroll-origin), not the
[physical](https://drafts.csswg.org/css-writing-modes-4/#physical) top left corner. Depending on the [writing
mode](https://drafts.csswg.org/css-writing-modes-4/#writing-mode) of the [scroll
container](https://drafts.csswg.org/css-overflow-3/#scroll-container), they therefore might not match
[`scrollLeft`](https://drafts.csswg.org/cssom-view-1/#dom-element-scrollleft) or
[`scrollTop`](https://drafts.csswg.org/cssom-view-1/#dom-element-scrolltop) values, for example in the [horizontal
axis](https://drafts.csswg.org/css-writing-modes-4/#x-axis) in a right-to-left
([rtl](https://drafts.csswg.org/css-writing-modes-4/#valdef-direction-rtl)) [writing mode].

Inherited attributes:

[`source`](#dom-scrolltimeline-source) (inherited from [`ScrollTimeline`](#scrolltimeline))

: The nearest ancestor of the
 [`subject`](#dom-viewtimeline-subject) whose [principal
 box](https://drafts.csswg.org/css-display-4/#principal-box) establishes a [scroll
 container](https://drafts.csswg.org/css-overflow-3/#scroll-container) in the specified axis, whose scroll position drives
 the progress of the timeline.

[`axis`](#dom-scrolltimeline-axis) (inherited from [`ScrollTimeline`](#scrolltimeline))

: Specifies the axis of scrolling that drives the progress of the
 timeline. See [\<axis\>](#typedef-axis), above.

[`currentTime`](https://drafts.csswg.org/web-animations-1/#dom-animationtimeline-currenttime) (inherited from [`AnimationTimeline`](https://drafts.csswg.org/web-animations-1/#animationtimeline))

: Represents the current progress of the [view progress
 timeline](#view-progress-timelines) as a percentage
 [`CSSUnitValue`](https://drafts.css-houdini.org/css-typed-om-1/#cssunitvalue) representing its [scroll
 container](https://drafts.csswg.org/css-overflow-3/#scroll-container)'s scroll progress at that position. Null when the
 timeline is
 [inactive](https://drafts.csswg.org/web-animations-1/#inactive-timeline).

<!-- -->

[`ViewTimeline(options)`]

: Creates a new
 [`ViewTimeline`](#viewtimeline) object using the following procedure:

 1. Let `timeline` be the new
 [`ViewTimeline`](#viewtimeline) object.

 2. Set the
 [`subject`](#dom-viewtimeline-subject) and
 [`axis`](#dom-scrolltimeline-axis) properties of `timeline` to the
 corresponding values from `options`.

 3. Set the
 [`source`](#dom-scrolltimeline-source) of `timeline` to the
 [`subject`](#dom-viewtimeline-subject)'s nearest ancestor [scroll
 container](https://drafts.csswg.org/css-overflow-3/#scroll-container) element that's scrollable in the specified
 axis.

 4. If a
 [`DOMString`](https://webidl.spec.whatwg.org/#idl-DOMString) value is provided as an inset, parse it as a
 [\<\'view-timeline-inset\'\>](#propdef-view-timeline-inset) value; if a sequence is
 provided, the first value represents the start inset and the
 second value represents the end inset. If the sequence has only
 one value, it is duplicated. If it has zero values or more than
 two values, or if it contains a
 [`CSSKeywordValue`](https://drafts.css-houdini.org/css-typed-om-1/#csskeywordvalue) whose
 [`value`](https://drafts.css-houdini.org/css-typed-om-1/#dom-csskeywordvalue-value) is not \"auto\", throw a
 [TypeError].

 These insets define the
 [`ViewTimeline`](#viewtimeline)'s [view progress visibility
 range](#view-progress-visibility-range).

If the
[`source`](#dom-scrolltimeline-source) or
[`subject`](#dom-viewtimeline-subject) of a
[`ViewTimeline`](#viewtimeline) is an element whose [principal
box](https://drafts.csswg.org/css-display-4/#principal-box) does not exist, or if its nearest ancestor [scroll
container](https://drafts.csswg.org/css-overflow-3/#scroll-container) has no [scrollable
overflow](https://drafts.csswg.org/css-overflow-3/#scrollable-overflow) or is not scrollable in the specified axis (or if there
is no such ancestor, e.g. in print media), then the
[`ViewTimeline`](#viewtimeline) is
[inactive](https://drafts.csswg.org/web-animations-1/#inactive-timeline).

The values of
[`subject`](#dom-viewtimeline-subject),
[`source`](#dom-scrolltimeline-source), and
[`currentTime`](https://drafts.csswg.org/web-animations-1/#dom-animationtimeline-currenttime) are all computed when any of them is requested or
updated.

In the following example, each child
of the `.scroller` element will reveal itself as it crosses the
scrollport.

```
document.querySelectorAll('.scroller > *').forEach(childElement => {
 const timeline = new ViewTimeline({
 subject: childElement,
 axis: 'block',
 });

 childElement.animate({
 opacity: [ 0, 1 ],
 }, {
 fill: 'both',
 timeline,
 });
});
```

In a vertical scroller, this results in an element going fully
transparent (`opacity: 0`) when its about to enter the scroller from the
bottom edge of the scroller to being fully opaque (`opacity: 1`) when it
has completely entered the scroller.

Scroll positions in between result in an opacity `0` and `1`.

### 3.4. Named View Progress Timelines

[View progress
timelines](#view-progress-timelines) can also be defined declaratively and then referenced
by name by elements within the name's scope (see [§ 4.2 Named Timeline
Scoping and Lookup](#timeline-scoping)).

Such [named view progress timelines] are declared in the
[coordinated value
list](https://drafts.csswg.org/css-values-4/#coordinated-value-list) constructed from the [view-timeline-\*]
properties, which form a [coordinating list property
group](https://drafts.csswg.org/css-values-4/#coordinating-list-property) with
[view-timeline-name](#propdef-view-timeline-name) as the [coordinating list base
property](https://drafts.csswg.org/css-values-4/#coordinating-list-base-property). See [CSS Values 4 § A Coordinating List-Valued
Properties](https://drafts.csswg.org/css-values-4/#linked-properties).

This example behaves exactly the same
[as the previous one](#example-6a3831a1): each child of the `.scroller`
element will reveal itself as it crosses the scrollport.

The difference is that instead of using an
[anonymous](#view-timelines-anonymous) [View progress
timeline](#view-progress-timelines) to drive the animation, it now uses a [named view
progress
timeline](#named-view-progress-timelines) that tracks the `.scroller`.

```
@keyframes reveal {
 from { opacity: 0; }
}

.scroller {
 view-timeline: --my-scroller block;
}

.scroller > * {
 animation: reveal linear both;
 animation-timeline: --my-scroller;
}
```

#### 3.4.1. Naming a View Progress Timeline: the [view-timeline-name property]
Name:

[view-timeline-name]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

\[ none
[\|](https://drafts.csswg.org/css-values-4/#comb-one)
[\<dashed-ident\>](https://drafts.csswg.org/css-values-4/#typedef-dashed-ident)
\][\#](https://drafts.csswg.org/css-values-4/#mult-comma)

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

list, each item either a [CSS
identifier](https://drafts.csswg.org/css-values-4/#css-css-identifier) or the keyword [none]

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

not animatable

Specifies names for the [named view progress
timelines](#named-view-progress-timelines) associated with this element.

#### 3.4.2. Axis of a View Progress Timeline: the [view-timeline-axis property]
Name:

[view-timeline-axis]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

\[ block
[\|](https://drafts.csswg.org/css-values-4/#comb-one) inline [\|] x
[\|] y
\][\#](https://drafts.csswg.org/css-values-4/#mult-comma)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

block

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[all
elements](https://www.w3.org/TR/css-pseudo/#generated-content "Includes ::before and ::after pseudo-elements.")

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

a list of the keywords specified

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

not animatable

Specifies the axis of any [named view progress
timelines](#named-view-progress-timelines) derived from this element's [principal
box](https://drafts.csswg.org/css-display-4/#principal-box).

Values are as defined for [view()](#funcdef-view).

#### 3.4.3. Inset of a View Progress Timeline: the [view-timeline-inset property]
Name:

[view-timeline-inset]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

\[ \[ auto
[\|](https://drafts.csswg.org/css-values-4/#comb-one)
[\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage)
\][{1,2}](https://drafts.csswg.org/css-values-4/#mult-num-range)
\][\#](https://drafts.csswg.org/css-values-4/#mult-comma)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

auto

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[all
elements](https://www.w3.org/TR/css-pseudo/#generated-content "Includes ::before and ::after pseudo-elements.")

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

relative to the corresponding dimension of the relevant scrollport

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

a list consisting of two-value pairs representing the start and end
insets each as either the keyword
[auto](#valdef-view-timeline-inset-auto) or a computed
[\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage) value

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value type

Specifies an inset (positive) or outset (negative) adjustment of the
[scrollport](https://drafts.csswg.org/css-overflow-3/#scrollport) when determining whether the box is in view when
setting the bounds of the corresponding [view progress
timeline](#view-progress-timelines). The first value represents the
[start](https://drafts.csswg.org/css-writing-modes-4/#css-start) inset in the relevant axis; the second value represents
the
[end](https://drafts.csswg.org/css-writing-modes-4/#css-end) inset. If the second value is omitted, it is set to the
first. The resulting range of the [scrollport] is
the [view progress visibility range].

[auto]
: Indicates to use the value of
 [scroll-padding](https://drafts.csswg.org/css-scroll-snap-1/#propdef-scroll-padding).

[[\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage)]
: Like
 [scroll-padding](https://drafts.csswg.org/css-scroll-snap-1/#propdef-scroll-padding), defines an inward offset from
 the corresponding edge of the scrollport.

#### 3.4.4. View Timeline Shorthand: the [view-timeline shorthand]
Name:

[view-timeline]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

\[
[\<\'view-timeline-name\'\>](#propdef-view-timeline-name) \[
[\<\'view-timeline-axis\'\>](#propdef-view-timeline-axis)
[\|\|](https://drafts.csswg.org/css-values-4/#comb-any)
[\<\'view-timeline-inset\'\>](#propdef-view-timeline-inset)
\][?](https://drafts.csswg.org/css-values-4/#mult-opt)
\][\#](https://drafts.csswg.org/css-values-4/#mult-comma)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

see individual properties

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[all
elements](https://www.w3.org/TR/css-pseudo/#generated-content "Includes ::before and ::after pseudo-elements.")

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

see individual properties

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

see individual properties

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

see individual properties

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

see individual properties

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

This property is a
[shorthand](https://drafts.csswg.org/css-cascade-5/#shorthand-property) for setting
[view-timeline-name](#propdef-view-timeline-name),
[view-timeline-axis](#propdef-view-timeline-axis), and
[view-timeline-inset](#propdef-view-timeline-inset) in a single declaration.

## 4. Attaching Animations to [Scroll-driven Timelines]
Animations can be attached to [scroll-driven
timelines](#scroll-driven-timelines) using the
[animation-timeline](https://drafts.csswg.org/css-animations-2/#propdef-animation-timeline) property (in CSS) or the
[`AnimationTimeline`](https://drafts.csswg.org/web-animations-1/#animationtimeline) parameters (in the Web Animations API). The timeline
range to which their [active
interval](https://drafts.csswg.org/web-animations-1/#active-interval) is attached can also be further restricted to a
particular timeline range (see [Attaching Animations to Timeline
Ranges](#named-range-animation-declaration)).

Time-based delays
([animation-delay](https://drafts.csswg.org/css-animations-2/#propdef-animation-delay)) get converted to their respective
proportions as described in [Web Animations 2 § 2.3
Animations](https://drafts.csswg.org/web-animations-2/#animations)

### 4.1. Finite Timeline Calculations

Unlike time-driven timelines, [scroll-driven
timelines](#scroll-driven-timelines) are finite, thus [scroll-driven
animations](#scroll-driven-animations) are always attached to a finite [attachment
range](#animation-attachment-range)---​which may be further limited by
[animation-range](#propdef-animation-range) (see [Appendix A: Timeline
Ranges](#timeline-ranges)). The animation's iterations
([animation-iteration-count](https://drafts.csswg.org/css-animations-1/#propdef-animation-iteration-count)) are set within the limits of this
finite range. If the specified duration is
[auto](https://drafts.csswg.org/css-animations-2/#valdef-animation-duration-auto), then the remaining range is divided by its
[iteration
count](https://drafts.csswg.org/web-animations-1/#iteration-count)
([animation-iteration-count]) to find the
[used](https://drafts.csswg.org/css-cascade-5/#used-value) duration.

 If the animation has an infinite [iteration
count](https://drafts.csswg.org/web-animations-1/#iteration-count), each [iteration
duration](https://drafts.csswg.org/web-animations-1/#iteration-duration)---​and the resulting [active
duration](https://drafts.csswg.org/web-animations-1/#active-duration)---​will be zero.

Animations that include absolutely-positioned keyframes (those pinned to
a specific point on the timeline, e.g. using [named timeline range
keyframe selectors](#named-range-keyframes) in
[\@keyframes](https://drafts.csswg.org/css-animations-1/#at-ruledef-keyframes)) are assumed to have an [iteration
count](https://drafts.csswg.org/web-animations-1/#iteration-count) of 1 for the purpose of finding those keyframes'
positions relative to 0% and 100%; the entire animation is then scaled
to fit the [iteration
duration](https://drafts.csswg.org/web-animations-1/#iteration-duration) and repeated for each iteration.

 It's unclear what the use case might be for combining
absolutely-positioned keyframes with iteration counts above 1; this at
least gives a defined behavior. (An alternative, but perhaps weirder,
behavior would be to take such absolutely-positioned keyframes "out of
flow" while iterating the remaining keyframes.) The editors would be
interested in hearing about any real use cases for multiple iterations
here.

### 4.2. Named Timeline Scoping and Lookup

Timeline names are global by default: An element referring to a named
[scroll progress
timeline](#scroll-progress-timelines) or [view progress
timeline](#view-progress-timelines) can find a [target
timeline](#target-timeline)
defined on itself, defined on an element *before* itself in tree order,
or defined on an element *after* itself in tree order.

The [target timeline] for a given element `element` referencing a
timeline name `name` is:

If `element` defines a timeline matching `name`,

: That timeline.

Otherwise, if `name` is [scoped](#timeline-scope) by `element`, or if `element` is the [document element](https://dom.spec.whatwg.org/#document-element),

: The last defined timeline matching `name` among
 `element`'s [flat
 tree](https://drafts.csswg.org/css-shadow-1/#flat-tree) descendants in [flat tree]
 order, or, if no such timeline exists, an [inactive
 timeline](https://drafts.csswg.org/web-animations-1/#inactive-timeline).

Otherwise,

: The [target timeline](#target-timeline) for `element`'s [flat
 tree](https://drafts.csswg.org/css-shadow-1/#flat-tree) parent referencing `name`.

An element may only define one timeline per name: In case of a name
conflict, names declared later in the naming property
([scroll-timeline-name](#propdef-scroll-timeline-name),
[view-timeline-name](#propdef-view-timeline-name)) take precedence, and [scroll
progress
timelines](#scroll-progress-timelines) take precedence over [view progress
timelines](#view-progress-timelines).

The element `#foo` defines a single
[scroll progress
timeline](#scroll-progress-timelines) in the block direction named `--t`, and no [view
progress
timeline](#view-progress-timelines) at all.

```
#foo {
 scroll-timeline: --t inline, --t block;
 view-timeline: --t;
}
```

An element can refer to timelines
bound to elements that are siblings, cousins, or even descendants. For
example, the following creates an animation on an element that is linked
to a [scroll progress
timeline](#scroll-progress-timelines) defined by the subsequent sibling.

``` highlight
<style>
 @keyframes anim {
 from { color: red; }
 to { color: green; }
 }

 .root {
 /* declares the scope of a '--scroller' timeline to reach all descendants */
 timeline-scope: --scroller;
 }

 .root .animation {
 animation: anim;
 /* references the '--scroller' timeline for driving the progress of 'anim' */
 animation-timeline: --scroller;
 }

 .root .animation + .scroller {
 /* attaches a scroll progress timeline to the timeline named '--scroller' */
 scroll-timeline: --scroller;
 }
</style>
&hellip;
<section class="root">
 <div class="animation">Animating Box</div>
 <div class="scroller">Scrollable Box</div>
</section>
```

### 4.3. Animation Events

[Scroll-driven
animations](#scroll-driven-animations) dispatch all the same animation events as the more
typical time-driven animations as described in [Web Animations § 4.5.18
Animation
events](https://drafts.csswg.org/web-animations-1/#animation-events-section),
[CSS Animations 1 § 5 Animation
Events](https://drafts.csswg.org/css-animations-1/#events), and [CSS
Animations 2 § 5.1 Event
dispatch](https://drafts.csswg.org/css-animations-2/#event-dispatch).

 When scrolling backwards, the `animationstart` event
will fire at the *end* of the [active
interval](https://drafts.csswg.org/web-animations-1/#active-interval), and the `animationend` event will fire at the start of
the [active interval]. However, since the
`finish` event is about entering the [finished play
state](https://drafts.csswg.org/web-animations-1/#play-state-finished), it only fires when scrolling forwards.

## 5. Frame Calculation Details

### 5.1. HTML Processing Model: Event loop

The ability for scrolling to drive the progress of an animation, gives
rise to the possibility of [layout cycles], where a change to a scroll
offset causes an animation's effect to update, which in turn causes a
new change to the scroll offset.

To avoid such [layout cycles](#layout-cycles), animations with a [scroll progress
timeline](#scroll-progress-timelines) update their current time once during step 7.10 of the
[HTML Processing
Model](https://html.spec.whatwg.org/multipage/webappapis.html#processing-model-8)
event loop, as step 1 of [update animations and send
events](https://drafts.csswg.org/web-animations-1/#update-animations-and-send-events).

During step 7.14.1 of the [HTML Processing
Model](https://html.spec.whatwg.org/multipage/webappapis.html#processing-model-8),
any created [scroll progress
timelines](#scroll-progress-timelines) or [view progress
timelines](#view-progress-timelines) are collected into a [stale timelines] set. After step 7.14 if any
timelines\' [named timeline
ranges](#named-timeline-range) have changed, these timelines are added to the [stale
timelines](#stale-timelines)
set. If there are any [stale timelines], they
now update their current time and associated ranges, the set of [stale
timelines] is cleared and we run an
additional step to recalculate styles and update layout.

 We check for layout changes after dispatching any
[`ResizeObserver`](https://drafts.csswg.org/resize-observer-1/#resizeobserver)s intentionally to take programmatically sized elements
into account.

 As we only gather stale timelines during the first
style and layout calculation, this can only directly cause one
additional style recalculation. Other APIs which require another update
should be checked in the same step and be updated at the same time.

 Without this additional round of style and layout,
[initially stale](#stale-timelines) timelines would remain stale (i.e. they would not have
a current time) for the remainder of the frame where the timeline was
created. This means that animations linked to such a timeline would not
produce any [effect
value](https://drafts.csswg.org/web-animations-1/#effect-value) for that frame, which could lead to an undesirable
initial \"flash\" in the rendered output.

 This section has no effect on forced style and layout
calculations triggered by
[`getComputedStyle()`](https://drafts.csswg.org/cssom-1/#dom-window-getcomputedstyle) or similar. In other words, [initially
stale](#stale-timelines)
timelines are visible as such through those APIs.

If the final style and layout update would result in a change in the
time or scope (see
[timeline-scope](#propdef-timeline-scope)) of any [scroll progress
timelines](#scroll-progress-timelines) or [view progress
timelines](#view-progress-timelines), they will not be re-sampled to reflect the new state
until the next update of the rendering.

Nothing in this section is intended to require that scrolling block on
layout or script. If a user agent normally composites frames where
scrolling has occurred but the consequences of scrolling have not been
fully propagated in layout or script (for example, `scroll` event
listeners have not yet run), the user agent may likewise choose not to
sample scroll-driven animations for that composited frame. In such
cases, the rendered scroll offset and the state of a scroll-driven
animation may be inconsistent in the composited frame.

When updating timeline current time, the [start
time](https://drafts.csswg.org/web-animations-1/#animation-start-time) of any attached animation is conditionally updated. For
each attached animation, run the procedure for [calculating an
auto-aligned start
time](https://drafts.csswg.org/web-animations-2/#calculating-an-auto-aligned-start-time).

## 6. Privacy Considerations

There are no known privacy impacts of the features in this
specification.

## 7. Security Considerations

There are no known security impacts of the features in this
specification.

## [Appendix A: Timeline Ranges]
This section should move to
CSS-ANIMATIONS-2 and WEB-ANIMATIONS-2.

This appendix introduces the concepts of [named timeline
ranges](#named-timeline-range) and [animation attachment
ranges](#animation-attachment-range) to [CSS
Animations](https://www.w3.org/TR/css-animations/) and [Web
Animations](https://www.w3.org/TR/web-animations/).

### [Named Timeline Ranges]
A [named timeline range] is a named segment of an animation
[timeline](https://drafts.csswg.org/web-animations-1/#timeline). The start of the segment is represented as 0% progress
through the range; the end of the segment is represented as 100%
progress through the range. Multiple [named timeline
ranges](#named-timeline-range) can be associated with a given
[timeline], and multiple such ranges can overlap.
For example, the [contain] range of a [view progress
timeline](#view-progress-timelines) overlaps with its [cover] range. [Named timeline
ranges] are represented by the
[[\<timeline-range-name\>](#typedef-timeline-range-name)] value type, which indicates
a [CSS
identifier](https://drafts.csswg.org/css-values-4/#css-css-identifier) representing one of the predefined [named timeline
ranges].

 In this specification, [named timeline
ranges](#named-timeline-range) must be defined to exist by a specification such as
[\[SCROLL-ANIMATIONS-1\]](#biblio-scroll-animations-1 "Scroll-driven Animations").
A future level may introduce APIs for authors to declare their own
custom [named timeline ranges].

### [Named Timeline Range Keyframe Selectors]
[Named timeline
range](#named-timeline-range) names and percentages can be used to attach keyframes
to specific progress points within the [named timeline
range]. The CSS
[\@keyframes](https://drafts.csswg.org/css-animations-1/#at-ruledef-keyframes) rule is extended thus:

``` prod
<keyframe-selector> = from | to | <percentage [0,100]> | <timeline-range-name> <percentage>
```

where
[\<timeline-range-name\>](#typedef-timeline-range-name) is the [CSS
identifier](https://drafts.csswg.org/css-values-4/#css-css-identifier) that represents a chosen predefined [named timeline
range](#named-timeline-range), and the
[\<percentage\>](https://drafts.csswg.org/css-values-4/#percentage-value) after it represents the percentage
progress between the start and end of that [named timeline
range].

Keyframes are attached to the specified point in the timeline. If the
timeline does not have a corresponding [named timeline
range](#named-timeline-range), then any keyframes attached to points on that [named
timeline range] are ignored. It is
possible that these attachment points are outside the [active
interval](https://drafts.csswg.org/web-animations-1/#active-interval) of the animation; in these cases the automatic
[from] (0%) and
[to](https://drafts.csswg.org/css-shapes-1/#valdef-shape-to) (100%) keyframes are only generated for
properties that don't have keyframes at or earlier than 0% or at or
after 100% (respectively).

In this example the range information
is included directly in the
[\@keyframes](https://drafts.csswg.org/css-animations-1/#at-ruledef-keyframes) rule:

```
@keyframes animate-in-and-out {
 entry 0% {
 opacity: 0; transform: translateY(100%);
 }
 entry 100% {
 opacity: 1; transform: translateY(0);
 }

 exit 0% {
 opacity: 1; transform: translateY(0);
 }
 exit 100% {
 opacity: 0; transform: translateY(-100%);
 }
}

.scroller > * {
 animation: linear animate-in-and-out;
 animation-timeline: view();
}
```

It has the same outcome as the following snippet which uses two distinct
sets of keyframes combined with
[animation-range](#propdef-animation-range)

```
@keyframes animate-in {
 0% { opacity: 0; transform: translateY(100%); }
 100% { opacity: 1; transform: translateY(0); }
}

@keyframes animate-out {
 0% { opacity: 1; transform: translateY(0); }
 100% { opacity: 0; transform: translateY(-100%); }
}

.scroller > * {
 animation: animate-in linear forwards,
 animate-out linear forwards;
 animation-timeline: view();
 animation-range: entry, exit;
}
```

### [Attaching Animations to Timeline Ranges]
A set of animation keyframes can be attached in reference to an
[animation attachment range],
restricting the animation's [active
interval](https://drafts.csswg.org/web-animations-1/#active-interval) to that range of a timeline, with the
[animation-range](#propdef-animation-range) properties. Delays (see
[animation-delay](https://drafts.csswg.org/css-animations-2/#propdef-animation-delay)) are set within this restricted
range, further reducing the time available for
[auto](https://drafts.csswg.org/css-animations-2/#valdef-animation-duration-auto) durations and
[infinite](https://drafts.csswg.org/css-animations-1/#valdef-animation-iteration-count-infinite) iterations.

[animation-range](#propdef-animation-range) can expand the [attachment
range](#animation-attachment-range) as well as constrict it.

Any frames positioned outside the [attachment
range](#animation-attachment-range) are used for interpolation as needed, but are outside
the [active
interval](https://drafts.csswg.org/web-animations-1/#active-interval) and therefore dropped from the animation itself,
effectively truncating the animation at the end of its [attachment
range].

``` ascii-art
range start┐ ╺┉┉active interval┉┉╸ ┌range end
┄┄┄┄┄┄┄┄┄┄┄├─────────────╊━━━━━━━━━━━━━━━━━━━╉───────────┤┄┄┄┄┄┄┄┄
 ╶┄start delay┄╴ ╶┄end delay┄╴
 ╶┄┄┄┄┄ duration┄┄┄┄┄╴
```

The
[animation-range](#propdef-animation-range) properties are [reset-only
sub-properties](https://drafts.csswg.org/css-cascade-5/#reset-only-sub-property) of the
[animation](https://drafts.csswg.org/css-animations-1/#propdef-animation)
[shorthand](https://drafts.csswg.org/css-cascade-5/#shorthand-property).

These list-valued properties form a [coordinating list property
group](https://drafts.csswg.org/css-values-4/#coordinating-list-property) with
[animation-name](https://drafts.csswg.org/css-animations-1/#propdef-animation-name) as the [coordinating list base
property](https://drafts.csswg.org/css-values-4/#coordinating-list-base-property).

Define application to time-driven
animations.

#### [Examples]
In the following example, each direct
child of the `.scroller` element reveals itself as it enters the
scrollport instead of when entirely crossing it.

This is achieved by setting
[animation-range](#propdef-animation-range) to limit the [active
interval](https://drafts.csswg.org/web-animations-1/#active-interval) to the
[entry](#valdef-animation-timeline-range-entry) range instead of the default
[cover](#valdef-animation-timeline-range-cover) range:

```
@keyframes reveal {
 from { opacity: 0; }
}

.scroller > * {
 animation: reveal linear both;
 animation-timeline: view();
 animation-range: entry;
}
```

In a vertical scroller, this results in an element going fully
transparent (`opacity: 0`) when its about to enter the scroller from the
bottom edge of the scroller to being fully opaque (`opacity: 1`) when it
has completely entered the scroller.

Scroll positions in between result in an opacity `0` and `1`.

A variation of the previous example is
to add both entry and exit effects, each linked to their own
[animation-range](#propdef-animation-range):

```
@keyframes reveal {
 from { opacity: 0; }
 to { opacity: 1; }
}
@keyframes hide {
 from { opacity: 1; }
 to { opacity: 0; }
}

.scroller > * {
 animation: reveal linear both,
 hide linear forwards;
 animation-timeline: view();
 animation-range: entry, exit;
}
```

The `reveal` effect is linked to the
[entry](#valdef-animation-timeline-range-entry) range while the `hide` effect is linked to the
[exit](#valdef-animation-timeline-range-exit) range.

In a vertical scroller, when scrolling down, this results in the element
going from `opacity: 0` to `opacity: 1` as it enters the scrollport from
the bottom edge of the scroller.

When continuing to scroll down, the element will eventually go from
`opacity: 1` to `opacity: 0` as the subject exits the scrollport at the
top edge of the scroller.

The Web Animations API equivalent of
the previous example is the following:

```
document.querySelectorAll('.scroller > *').forEach(childElement => {
 const timeline = new ViewTimeline({
 subject: childElement,
 axis: 'block',
 });

 // Reveal effect on entry
 childElement.animate({
 opacity: [ 0, 1 ],
 }, {
 fill: 'forwards',
 timeline,
 rangeStart: 'entry 0%',
 rangeEnd: 'entry 100%',
 });

 // Hide effect on exit
 childElement.animate({
 opacity: [ 1, 0 ],
 }, {
 fill: 'forwards',
 timeline,
 rangeStart: 'exit 100%',
 rangeEnd: 'exit 100%',
 });
});
```

For every matched element, a single timeline tracking that element is
created. The timeline tracks the element inside its scroller in the
block direction.

The timeline is used to drive two animations added to the element but
the effects are only attached to a part of the range, thanks to the
`rangeStart` and `rangeEnd` options.

The first animation is attached to the
[entry](#valdef-animation-timeline-range-entry) range, animating the element from `opacity: 0`
to `opacity: 1` as it enters the scrollport.

The second animation is attached to the
[exit](#valdef-animation-timeline-range-exit) range, animating the element from `opacity: 1`
to `opacity: 0` as it leaves the scrollport.

#### [Specifying an Animation's Timeline Range: the [animation-range](#propdef-animation-range) shorthand]
Name:

[animation-range]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

\[
[\<\'animation-range-start\'\>](#propdef-animation-range-start)
[\<\'animation-range-end\'\>](#propdef-animation-range-end)[?](https://drafts.csswg.org/css-values-4/#mult-opt)
\][\#](https://drafts.csswg.org/css-values-4/#mult-comma)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

see individual properties

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

see individual properties

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

see individual properties

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

see individual properties

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

see individual properties

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

see individual properties

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

The
[animation-range](#propdef-animation-range) property is a
[shorthand](https://drafts.csswg.org/css-cascade-5/#shorthand-property) that sets
[animation-range-start](#propdef-animation-range-start) and
[animation-range-end](#propdef-animation-range-end) together in a single declaration,
associating the animation with the specified [animation attachment
range](#animation-attachment-range).

If
[\<\'animation-range-end\'\>](#propdef-animation-range-end) is omitted and
[\<\'animation-range-start\'\>](#propdef-animation-range-start) includes a
[\<timeline-range-name\>](#typedef-timeline-range-name) component, then
[animation-range-end]
is set to that same
[\<timeline-range-name\>] and [100%]. Otherwise, any omitted
[longhand](https://drafts.csswg.org/css-cascade-5/#longhand) is set to its [initial
value](https://drafts.csswg.org/css-cascade-5/#initial-value).

The following sets of declarations
show an
[animation-range](#propdef-animation-range)
[shorthand](https://drafts.csswg.org/css-cascade-5/#shorthand-property) declaration followed by its equivalent
[animation-range-start](#propdef-animation-range-start) and
[animation-range-end](#propdef-animation-range-end) declarations:

``` {style="columns: 40ch"}
animation-range: entry 10% exit 90%;
animation-range-start: entry 10%;
animation-range-end: exit 90%;

animation-range: entry;
animation-range-start: entry 0%;
animation-range-end: entry 100%;

animation-range: entry exit;
animation-range-start: entry 0%;
animation-range-end: exit 100%;

animation-range: 10%;
animation-range-start: 10%;
animation-range-end: normal;

animation-range: 10% 90%;
animation-range-start: 10%;
animation-range-end: 90%;

animation-range: entry 10% exit;
animation-range-start: entry 10%;
animation-range-end: exit 100%;

animation-range: 10% exit 90%;
animation-range-start: 10%;
animation-range-end: exit 90%;

animation-range: entry 10% 90%;
animation-range-start: entry 10%;
animation-range-end: 90%;
```

Because
[\<\'animation-range-start\'\>](#propdef-animation-range-start) and
[\<\'animation-range-end\'\>](#propdef-animation-range-end) accept
[\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage)s, it's perfectly fine to do
calculations using
[calc()](https://drafts.csswg.org/css-values-4/#funcdef-calc) for the ranges:

```
#subject {
 animation: anim linear both;
 animation-timeline: view();
 animation-range: entry calc(100% - 100px) exit calc(0% + 100px);
}
```

What's the best way to handle defaulting
of omitted values here? [\[Issue
#8438\]](https://github.com/w3c/csswg-drafts/issues/8438)

#### [Specifying an Animation's Timeline Range Start: the [animation-range-start](#propdef-animation-range-start) property]
Name:

[animation-range-start]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

\[ normal
[\|](https://drafts.csswg.org/css-values-4/#comb-one)
[\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage) [\|]
[\<timeline-range-name\>](#typedef-timeline-range-name)
[\<length-percentage\>][?](https://drafts.csswg.org/css-values-4/#mult-opt)
\][\#](https://drafts.csswg.org/css-values-4/#mult-comma)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

normal

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[all
elements](https://www.w3.org/TR/css-pseudo/#generated-content "Includes ::before and ::after pseudo-elements.")

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

relative to the specified [named timeline
range](#named-timeline-range) if one was specified, else to the entire timeline

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

list, each item either the keyword
[normal](#valdef-animation-range-start-normal) or a timeline range and progress percentage

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

not animatable

Specifies the start of the animations's [attachment
range](#animation-attachment-range), shifting the [start
time](https://drafts.csswg.org/web-animations-1/#animation-start-time) of the animation (i.e. where keyframes mapped to 0%
progress are attached when the iteration count is 1) accordingly.

Values have the following meanings:

[normal]
: The start of the animation's [attachment
 range](#animation-attachment-range) is the start of its associated
 [timeline](https://drafts.csswg.org/web-animations-1/#timeline); the start of the animation's [active
 interval](https://drafts.csswg.org/web-animations-1/#active-interval) is determined as normal.

[[\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage)]
: The [animation attachment
 range](#animation-attachment-range) starts at the specified point on the
 [timeline](https://drafts.csswg.org/web-animations-1/#timeline) measuring from the start of the timeline.

[[\<timeline-range-name\>](#typedef-timeline-range-name) [\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage)?]
: The [animation attachment
 range](#animation-attachment-range) starts at the specified point on the
 [timeline](https://drafts.csswg.org/web-animations-1/#timeline) measuring from the start of the specified [named
 timeline
 range](#named-timeline-range). If the
 [\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage) is omitted, it defaults to 0%.

#### [Specifying an Animation's Timeline Range End: the [animation-range-end](#propdef-animation-range-end) property]
Name:

[animation-range-end]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

\[ normal
[\|](https://drafts.csswg.org/css-values-4/#comb-one)
[\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage) [\|]
[\<timeline-range-name\>](#typedef-timeline-range-name)
[\<length-percentage\>][?](https://drafts.csswg.org/css-values-4/#mult-opt)
\][\#](https://drafts.csswg.org/css-values-4/#mult-comma)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

normal

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[all
elements](https://www.w3.org/TR/css-pseudo/#generated-content "Includes ::before and ::after pseudo-elements.")

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

relative to the specified [named timeline
range](#named-timeline-range) if one was specified, else to the entire timeline

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

list, each item either the keyword
[normal](#valdef-animation-range-end-normal) or a timeline range and progress percentage

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

not animatable

Specifies the end of the animations's [attachment
range](#animation-attachment-range), potentially shifting the [end
time](https://drafts.csswg.org/web-animations-1/#animation-effect-end-time) of the animation (i.e. where keyframes mapped to 100%
progress are attached when the iteration count is 1) and/or truncating
the animation's [active
interval](https://drafts.csswg.org/web-animations-1/#active-interval).

Values have the following meanings:

[normal]
: The end of the animation's [attachment
 range](#animation-attachment-range) is the end of its associated
 [timeline](https://drafts.csswg.org/web-animations-1/#timeline); the end of the animation's [active
 interval](https://drafts.csswg.org/web-animations-1/#active-interval) is determined as normal.

[[\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage)]
: The [animation attachment
 range](#animation-attachment-range) ends at the specified point on the
 [timeline](https://drafts.csswg.org/web-animations-1/#timeline) measuring from the start of the timeline.

[[\<timeline-range-name\>](#typedef-timeline-range-name) [\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage)?]
: The [animation attachment
 range](#animation-attachment-range) ends at the specified point on the
 [timeline](https://drafts.csswg.org/web-animations-1/#timeline) measuring from the start of the specified [named
 timeline
 range](#named-timeline-range). If the
 [\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage) is omitted, it defaults to 100%.

## [Appendix B: Timeline Name Scope]
This section should move to
CSS-ANIMATIONS-2.

This appendix introduces the
[timeline-scope](#propdef-timeline-scope) property, which allows declaring a
timeline name's scope on an ancestor of the timeline's defining element.

### [Declaring a Named Timeline's Scope: the [timeline-scope](#propdef-timeline-scope) property]
Name:

[timeline-scope]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

none
[\|](https://drafts.csswg.org/css-values-4/#comb-one) all [\|]
[\<dashed-ident\>](https://drafts.csswg.org/css-values-4/#typedef-dashed-ident)[\#](https://drafts.csswg.org/css-values-4/#mult-comma)

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

the keyword
[none](#valdef-timeline-scope-none), the keyword
[all](#valdef-timeline-scope-all), or a list of [CSS
identifiers](https://drafts.csswg.org/css-values-4/#css-css-identifier)

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

not animatable

Values have the following meanings:

[none]
: No changes in timeline name scope.

[all]
: Specifies that all timeline names defined by this element or its
 [flat
 tree](https://drafts.csswg.org/css-shadow-1/#flat-tree) descendants---​whose scope is not already limited by
 a descendant using
 [timeline-scope](#propdef-timeline-scope)---​to be in scope only for this
 element's [flat tree] descendants; and limits
 descendants to only match timeline names to elements within this
 subtree.

[[\<dashed-ident\>](https://drafts.csswg.org/css-values-4/#typedef-dashed-ident)]
: Specifies that a matching timeline name defined by this element or
 its [flat
 tree](https://drafts.csswg.org/css-shadow-1/#flat-tree) descendants---​whose scope is not already limited by
 a descendant using
 [timeline-scope](#propdef-timeline-scope)---​to be in scope only for this
 element's [flat tree] descendants; and limits
 descendants to only match timeline names to elements within this
 subtree.

 This property cannot affect or invalidate any timeline
name lookups within the subtree of a descendant element that declares
the same name. See [Declaring a Named Timeline's Scope: the
timeline-scope property](#timeline-scope).

Say you have multiple instances of a
component, each defining a timeline and some element using that
timeline:

```
<div>
 <div class="component">
 <div style="view-timeline: --t /*...*/;"></div>
 <div style="animation-timeline: --t;"></div>
 </div>
 <div class="component">
 <div style="view-timeline: --t /*...*/;"></div>
 <div style="animation-timeline: --t;"></div>
 </div>
</div>
```

Both instances of `animation-timeline:--t` will
[target](#target-timeline)
the *same* timeline, i.e. the last one seen in [flat
tree](https://drafts.csswg.org/css-shadow-1/#flat-tree) order, globally.

If we instead want each instance of `animation-timeline:--t` to
[target](#target-timeline)
the \"locally defined\" `--t`, we can do the following:

```
<style>
 .component {
 timeline-scope: --t;
 }
</style>
```

Now, any lookup of `--t` taking place within a component will only see
timelines defined inside that component.

## 8. Changes

Changes since the ([28 April
2023](https://www.w3.org/TR/2023/WD-scroll-animations-1-20230428/))
Working Draft include:

- Changed named timeline lookup to nearest-ancestor/last-in-tree-order.
 ([Issue 12581](https://github.com/w3c/csswg-drafts/issues/12581)),
 ([Issue 13364](https://github.com/w3c/csswg-drafts/issues/13364))

- Allow
 [all](#valdef-timeline-scope-all) as a value for
 [timeline-scope](#propdef-timeline-scope). ([Issue
 9158](https://github.com/w3c/csswg-drafts/issues/9158))

- Removed [scroll-timeline-attachment] and
 [view-timeline-attachment] in favor of
 [timeline-scope](#propdef-timeline-scope). ([Issue
 7759](https://github.com/w3c/csswg-drafts/issues/7759))

- Switched named timelines to use
 [\<dashed-ident\>](https://drafts.csswg.org/css-values-4/#typedef-dashed-ident) instead of
 [\<custom-ident\>](https://drafts.csswg.org/css-values-4/#identifier-value) in order to avoid name clashes with
 standard CSS keywords. ([Issue
 8746](https://github.com/w3c/csswg-drafts/issues/8746))

- Removed
 [`getCurrentTime()`](https://www.w3.org/TR/scroll-animations-1/#dom-animationtimeline-getcurrenttime) API due to various issues in the design. ([Issue
 8765](https://github.com/w3c/csswg-drafts/issues/8765)) Progress on an
 individual animation can now be retrieved using `Animation.progress`
 ([Issue 8799](https://github.com/w3c/csswg-drafts/issues/8799)) and
 other use cases are deferred to Level 2.

- Allow [none] to be used as part of the value list for
 [scroll-timeline-name](#propdef-scroll-timeline-name) and
 [view-timeline-name](#propdef-view-timeline-name), not just as an alternative to
 it. ([Issue 8843](https://github.com/w3c/csswg-drafts/issues/8843))

See also [Earlier
Changes](https://www.w3.org/TR/2023/WD-scroll-animations-1-20230428/#changes).
