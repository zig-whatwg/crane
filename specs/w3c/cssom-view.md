## 1. Background

Many of the features defined in this specification have been supported
by browsers for a long period of time. The goal of this specification is
to define these features in such a way that they can be implemented by
all browsers in an interoperable manner. The specification also defines
a some new features which allow for scroll customization.

Tests

Basic IDL tests

- [idlharness.html](https://wpt.fyi/results/css/cssom-view/idlharness.html "css/cssom-view/idlharness.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/idlharness.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/idlharness.html)

------------------------------------------------------------------------

## 2. Terminology

Terminology used in this specification is from DOM, CSSOM and HTML.
[\[DOM\]](#biblio-dom "DOM Standard")
[\[CSSOM\]](#biblio-cssom "CSS Object Model (CSSOM)")
[\[HTML\]](#biblio-html "HTML Standard")

An element `body` (which will be [the `body`
element](https://html.spec.whatwg.org/multipage/dom.html#the-body-element-2)) is [potentially scrollable] in an axis if all of the
following conditions are true:

- `body` has an associated
 [box](https://drafts.csswg.org/css-display-4/#box).

- `body`'s [parent
 element](https://dom.spec.whatwg.org/#parent-element)'s computed value of the
 [overflow-x](https://drafts.csswg.org/css-overflow-3/#propdef-overflow-x) or
 [overflow-y](https://drafts.csswg.org/css-overflow-3/#propdef-overflow-y) properties (whichever is in the
 given axis) is neither
 [visible](https://drafts.csswg.org/css-overflow-3/#valdef-overflow-visible) nor
 [clip](https://drafts.csswg.org/css-overflow-3/#valdef-overflow-clip).

- `body`'s computed value of the
 [overflow-x](https://drafts.csswg.org/css-overflow-3/#propdef-overflow-x) or
 [overflow-y](https://drafts.csswg.org/css-overflow-3/#propdef-overflow-y) properties (whichever is in the
 given axis) is neither
 [visible](https://drafts.csswg.org/css-overflow-3/#valdef-overflow-visible) nor
 [clip](https://drafts.csswg.org/css-overflow-3/#valdef-overflow-clip).

 A
[`body`](https://html.spec.whatwg.org/multipage/sections.html#the-body-element) element that is [potentially
scrollable](#potentially-scrollable) might not have a [scrolling
box](#scrolling-box). For
instance, it could have a used value of
[overflow](https://drafts.csswg.org/css-overflow-3/#propdef-overflow) being
[auto](https://drafts.csswg.org/css-overflow-3/#valdef-overflow-auto) but not have its content overflowing its content
area.

A [scrolling box] of a
[viewport](https://drafts.csswg.org/css2/#viewport%E2%91%A0) or element has two [overflow
directions], which are the
[block-end](https://drafts.csswg.org/css-writing-modes-4/#block-end) and
[inline-end](https://drafts.csswg.org/css-writing-modes-4/#inline-end) directions for that viewport or element. Note that the
initial scroll position might not be aligned with the [scrolling area
origin](#scrolling-area-origin) depending on the [content-distribution
properties](https://drafts.csswg.org/css-align-3/#content-distribution-properties), see [CSS Box Alignment 3 § 5.3 Alignment Overflow and
Scroll
Containers](https://drafts.csswg.org/css-align-3/#overflow-scroll-position).

The term [scrolling area] refers to a box of a
[viewport](https://drafts.csswg.org/css2/#viewport%E2%91%A0) or an element that has the following edges, depending
on the [viewport]'s or element's [scrolling
box](#scrolling-box)'s
[overflow directions](#overflow-directions).

If the [overflow
directions](#overflow-directions) are...

For a
[viewport](https://drafts.csswg.org/css2/#viewport%E2%91%A0)

For an element

rightward and downward

top edge
: The top edge of the [initial containing
 block](https://drafts.csswg.org/css-display-4/#initial-containing-block).

right edge
: The right-most edge of the right edge of the [initial containing
 block](https://drafts.csswg.org/css-display-4/#initial-containing-block) and the right [margin
 edge](https://drafts.csswg.org/css-box-4/#margin-edge) of all of the
 [viewport's](https://drafts.csswg.org/css2/#viewport%E2%91%A0) descendants\' boxes.

bottom edge
: The bottom-most edge of the bottom edge of the [initial containing
 block](https://drafts.csswg.org/css-display-4/#initial-containing-block) and the bottom [margin
 edge](https://drafts.csswg.org/css-box-4/#margin-edge) of all of the
 [viewport's](https://drafts.csswg.org/css2/#viewport%E2%91%A0) descendants\' boxes.

left edge
: The left edge of the [initial containing
 block](https://drafts.csswg.org/css-display-4/#initial-containing-block).

<!-- -->

top edge
: The element's top [padding
 edge](https://drafts.csswg.org/css-box-4/#padding-edge).

right edge
: The right-most edge of the element's right [padding
 edge](https://drafts.csswg.org/css-box-4/#padding-edge) and the right [margin
 edge](https://drafts.csswg.org/css-box-4/#margin-edge) of all of the element's descendants\' boxes,
 excluding boxes that have an ancestor of the element as their
 containing block.

bottom edge
: The bottom-most edge of the element's bottom [padding
 edge](https://drafts.csswg.org/css-box-4/#padding-edge) and the bottom [margin
 edge](https://drafts.csswg.org/css-box-4/#margin-edge) of all of the element's descendants\' boxes,
 excluding boxes that have an ancestor of the element as their
 containing block.

left edge
: The element's left [padding
 edge](https://drafts.csswg.org/css-box-4/#padding-edge).

leftward and downward

top edge
: The top edge of the [initial containing
 block](https://drafts.csswg.org/css-display-4/#initial-containing-block).

right edge
: The right edge of the [initial containing
 block](https://drafts.csswg.org/css-display-4/#initial-containing-block).

bottom edge
: The bottom-most edge of the bottom edge of the [initial containing
 block](https://drafts.csswg.org/css-display-4/#initial-containing-block) and the bottom [margin
 edge](https://drafts.csswg.org/css-box-4/#margin-edge) of all of the
 [viewport's](https://drafts.csswg.org/css2/#viewport%E2%91%A0) descendants\' boxes.

left edge
: The left-most edge of the left edge of the [initial containing
 block](https://drafts.csswg.org/css-display-4/#initial-containing-block) and the left [margin
 edge](https://drafts.csswg.org/css-box-4/#margin-edge) of all of the
 [viewport's](https://drafts.csswg.org/css2/#viewport%E2%91%A0) descendants\' boxes.

<!-- -->

top edge
: The element's top [padding
 edge](https://drafts.csswg.org/css-box-4/#padding-edge).

right edge
: The element's right [padding
 edge](https://drafts.csswg.org/css-box-4/#padding-edge).

bottom edge
: The bottom-most edge of the element's bottom [padding
 edge](https://drafts.csswg.org/css-box-4/#padding-edge) and the bottom [margin
 edge](https://drafts.csswg.org/css-box-4/#margin-edge) of all of the element's descendants\' boxes,
 excluding boxes that have an ancestor of the element as their
 containing block.

left edge
: The left-most edge of the element's left [padding
 edge](https://drafts.csswg.org/css-box-4/#padding-edge) and the left [margin
 edge](https://drafts.csswg.org/css-box-4/#margin-edge) of all of the element's descendants\' boxes,
 excluding boxes that have an ancestor of the element as their
 containing block.

leftward and upward

top edge
: The top-most edge of the top edge of the [initial containing
 block](https://drafts.csswg.org/css-display-4/#initial-containing-block) and the top [margin
 edge](https://drafts.csswg.org/css-box-4/#margin-edge) of all of the
 [viewport's](https://drafts.csswg.org/css2/#viewport%E2%91%A0) descendants\' boxes.

right edge
: The right edge of the [initial containing
 block](https://drafts.csswg.org/css-display-4/#initial-containing-block).

bottom edge
: The bottom edge of the [initial containing
 block](https://drafts.csswg.org/css-display-4/#initial-containing-block).

left edge
: The left-most edge of the left edge of the [initial containing
 block](https://drafts.csswg.org/css-display-4/#initial-containing-block) and the left [margin
 edge](https://drafts.csswg.org/css-box-4/#margin-edge) of all of the
 [viewport's](https://drafts.csswg.org/css2/#viewport%E2%91%A0) descendants\' boxes.

<!-- -->

top edge
: The top-most edge of the element's top [padding
 edge](https://drafts.csswg.org/css-box-4/#padding-edge) and the top [margin
 edge](https://drafts.csswg.org/css-box-4/#margin-edge) of all of the element's descendants\' boxes,
 excluding boxes that have an ancestor of the element as their
 containing block.

right edge
: The element's right [padding
 edge](https://drafts.csswg.org/css-box-4/#padding-edge).

bottom edge
: The element's bottom [padding
 edge](https://drafts.csswg.org/css-box-4/#padding-edge).

left edge
: The left-most edge of the element's left [padding
 edge](https://drafts.csswg.org/css-box-4/#padding-edge) and the left [margin
 edge](https://drafts.csswg.org/css-box-4/#margin-edge) of all of the element's descendants\' boxes,
 excluding boxes that have an ancestor of the element as their
 containing block.

rightward and upward

top edge
: The top-most edge of the top edge of the [initial containing
 block](https://drafts.csswg.org/css-display-4/#initial-containing-block) and the top [margin
 edge](https://drafts.csswg.org/css-box-4/#margin-edge) of all of the
 [viewport's](https://drafts.csswg.org/css2/#viewport%E2%91%A0) descendants\' boxes.

right edge
: The right-most edge of the right edge of the [initial containing
 block](https://drafts.csswg.org/css-display-4/#initial-containing-block) and the right [margin
 edge](https://drafts.csswg.org/css-box-4/#margin-edge) of all of the
 [viewport's](https://drafts.csswg.org/css2/#viewport%E2%91%A0) descendants\' boxes.

bottom edge
: The bottom edge of the [initial containing
 block](https://drafts.csswg.org/css-display-4/#initial-containing-block).

left edge
: The left edge of the [initial containing
 block](https://drafts.csswg.org/css-display-4/#initial-containing-block).

<!-- -->

top edge
: The top-most edge of the element's top [padding
 edge](https://drafts.csswg.org/css-box-4/#padding-edge) and the top [margin
 edge](https://drafts.csswg.org/css-box-4/#margin-edge) of all of the element's descendants\' boxes,
 excluding boxes that have an ancestor of the element as their
 containing block.

right edge
: The right-most edge of the element's right [padding
 edge](https://drafts.csswg.org/css-box-4/#padding-edge) and the right [margin
 edge](https://drafts.csswg.org/css-box-4/#margin-edge) of all of the element's descendants\' boxes,
 excluding boxes that have an ancestor of the element as their
 containing block.

bottom edge
: The element's bottom [padding
 edge](https://drafts.csswg.org/css-box-4/#padding-edge).

left edge
: The element's left [padding
 edge](https://drafts.csswg.org/css-box-4/#padding-edge).

The [origin] of a [scrolling
area](#scrolling-area) is the
origin of the [initial containing
block](https://drafts.csswg.org/css-display-4/#initial-containing-block) if the [scrolling area] is a
[viewport](https://drafts.csswg.org/css2/#viewport%E2%91%A0), and otherwise the top left padding edge of the element
when the element has its default scroll position. The x-coordinate
increases rightwards, and the y-coordinate increases downwards.

The [beginning edges] of a particular set of edges of a box or element are the
following edges:

If the [overflow directions](#overflow-directions) are rightward and downward
: The top and left edges.

If the [overflow directions](#overflow-directions) are leftward and downward
: The top and right edges.

If the [overflow directions](#overflow-directions) are leftward and upward
: The bottom and right edges.

If the [overflow directions](#overflow-directions) are rightward and upward
: The bottom and left edges.

The [ending edges] of a particular set of edges of a box or element are the
following edges:

If the [overflow directions](#overflow-directions) are rightward and downward
: The bottom and right edges.

If the [overflow directions](#overflow-directions) are leftward and downward
: The bottom and left edges.

If the [overflow directions](#overflow-directions) are leftward and upward
: The top and left edges.

If the [overflow directions](#overflow-directions) are rightward and upward
: The top and right edges.

The [`VisualViewport`](#visualviewport) object has an [associated
document], which is a
[`Document`](https://dom.spec.whatwg.org/#document) object. It is the [associated document] of
the owner
[`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window) of
[`VisualViewport`](#visualviewport). The [layout
viewport](https://drafts.csswg.org/css-viewport/#layout-viewport) is the owner
[`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window)'s
[viewport](https://drafts.csswg.org/css2/#viewport%E2%91%A0).

For the purpose of the requirements in this specification, elements that
have a computed value of the
[display](https://drafts.csswg.org/css-display-4/#propdef-display) property that is
[table-column](https://drafts.csswg.org/css-display-4/#valdef-display-table-column) or
[table-column-group](https://drafts.csswg.org/css-display-4/#valdef-display-table-column-group) must be considered to have an associated
[box](https://drafts.csswg.org/css-display-4/#box) (the column or column group, respectively).

The term [SVG layout box] refers to a
[box](https://drafts.csswg.org/css-display-4/#box) generated by an SVG element which does not correspond
to a CSS-defined
[display](https://drafts.csswg.org/css-display-4/#propdef-display) type. (Such as the
[box] generated by a
[`rect`](https://w3c.github.io/svgwg/svg2-draft/shapes.html#elementdef-rect) element.)

The term [transforms] refers to SVG transforms and CSS transforms.
[\[SVG11\]](#biblio-svg11 "Scalable Vector Graphics (SVG) 1.1 (Second Edition)")
[\[CSS-TRANSFORMS-1\]](#biblio-css-transforms-1 "CSS Transforms Module Level 1")

When a method or an attribute is said to call another method or
attribute, the user agent must invoke its internal API for that
attribute or method so that e.g. the author can't change the behavior by
overriding attributes or methods with custom properties or functions in
ECMAScript.

Unless otherwise stated, all string comparisons use
[is](https://infra.spec.whatwg.org/#string-is).

### 2.1. CSS pixels

All coordinates and dimensions for the APIs defined in this
specification are in [CSS
pixels](https://drafts.csswg.org/css-values-4/#px), unless otherwise specified.
[\[CSS-VALUES\]](#biblio-css-values "CSS Values and Units Module Level 4")

 This does not apply to e.g.
[`matchMedia()`](#dom-window-matchmedia) as the units are explicitly given there.

### 2.2. Zooming

There are two kinds of zoom, [page zoom] which affects the size of the initial
viewport, and the visual viewport [scale
factor](https://drafts.csswg.org/css-viewport/#scale-factor) which acts like a magnifying glass and does not affect
the initial viewport or actual viewport.
[\[CSS-DEVICE-ADAPT\]](#biblio-css-device-adapt "CSS Viewport Module Level 1")

 The \"scale factor\" is often referred to as
\"pinch-zoom\"; however, it can be affected through means other than
pinch-zooming. e.g. The user agent may zooms in on a focused input
element to make it legible.

### 2.3. Web-exposed screen information

User agents may choose to hide information about the screen of the
output device, in order to protect the user's privacy. In order to do so
in a consistent manner across APIs, this specification defines the
following terms, each having a width and a height, the origin being the
top left corner, and the x- and y-coordinates increase rightwards and
downwards, respectively.

The [Web-exposed screen area] must return the result of the following
algorithm:

1. Let `target` be
 [this](https://webidl.spec.whatwg.org/#this)'s [relevant global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global)'s [browsing
 context](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window-bc).

2. Let `emulated screen area` be the [WebDriver BiDi
 emulated total screen
 area](https://w3c.github.io/webdriver-bidi/#webdriver-bidi-emulated-total-screen-area) of `target`.

3. If `emulated screen area` is not null, return
 `emulated screen area`.

4. Otherwise, return one of the following:

 - The area of the output device, in [CSS
 pixels](https://drafts.csswg.org/css-values-4/#px).

 - The area of the
 [viewport](https://drafts.csswg.org/css2/#viewport%E2%91%A0), in [CSS
 pixels](https://drafts.csswg.org/css-values-4/#px).

The [Web-exposed available screen
area] must return the result of the following
algorithm:

1. Let `target` be
 [this](https://webidl.spec.whatwg.org/#this)'s [relevant global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global)'s [browsing
 context](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window-bc).

2. Let `emulated screen area` be the [WebDriver BiDi
 emulated available screen
 area](https://w3c.github.io/webdriver-bidi/#webdriver-bidi-emulated-available-screen-area) for `target`.

3. If `emulated screen area` is not null, return
 `emulated screen area`.

4. Otherwise, return one of the following:

 - The available area of the rendering surface of the output device,
 in [CSS
 pixels](https://drafts.csswg.org/css-values-4/#px).

 - The area of the output device, in [CSS
 pixels](https://drafts.csswg.org/css-values-4/#px).

 - The area of the
 [viewport](https://drafts.csswg.org/css2/#viewport%E2%91%A0), in [CSS
 pixels](https://drafts.csswg.org/css-values-4/#px).

## 3. Common Infrastructure

This specification depends on the WHATWG Infra standard.
[\[INFRA\]](#biblio-infra "Infra Standard")

### 3.1. Scrolling

When a user agent is to [perform a scroll] of a [scrolling
box](#scrolling-box)
`box`, to a given position `position`, an
associated element or
[pseudo-element](https://drafts.csswg.org/selectors-4/#pseudo-element) `element` and optionally a scroll behavior
`behavior` (which is \"`auto`\" if omitted), the following
steps must be run:

1. [Abort](#smooth-scroll-aborted) any ongoing [smooth
 scroll](#concept-smooth-scroll) for `box`.

2. Resolve all pending scroll
 [`Promise`](https://webidl.spec.whatwg.org/#idl-promise)s whose scroll container is `box`.

3. Let `scrollPromise` be a new
 [`Promise`](https://webidl.spec.whatwg.org/#idl-promise).

4. Return `scrollPromise`, and run the remaining steps [in
 parallel](https://html.spec.whatwg.org/multipage/infrastructure.html#in-parallel).

5. If the user agent honors the
 [scroll-behavior](https://drafts.csswg.org/css-overflow-3/#propdef-scroll-behavior) property and one of the
 following is true:

 - `behavior` is \"`auto`\" and `element` is
 not null and its computed value of the
 [scroll-behavior](https://drafts.csswg.org/css-overflow-3/#propdef-scroll-behavior) property is
 [smooth](https://drafts.csswg.org/css-overflow-3/#valdef-scroll-behavior-smooth), or
 - `behavior` is `smooth`

 then perform a [smooth
 scroll](#concept-smooth-scroll) of `box` to `position`;
 otherwise, perform an [instant
 scroll](#concept-instant-scroll) of `box` to `position`.

6. Wait until either the position has finished updating, or
 `scrollPromise` has been resolved.

7. If `scrollPromise` is still in the pending state:

 1. If the scroll position changed as a result of this call, emit
 the
 [scrollend](#eventdef-document-scrollend) event.

 2. Resolve `scrollPromise`.

 `behavior: "instant"` always performs an [instant
scroll](#concept-instant-scroll) by this algorithm.

 If the scroll position did not change as a result of
the user interaction or programmatic invocation, where no translations
were applied as a result, then no
[scrollend](#eventdef-document-scrollend) event fires because no scrolling occurred.

When a user agent is to [perform a scroll] of a
[viewport](https://drafts.csswg.org/css2/#viewport%E2%91%A0) to a given position `position` and
optionally a scroll behavior `behavior` (which is \"`auto`\"
if omitted) it must perform a coordinated viewport scroll by following
these steps:

1. Let `doc` be the
 [viewport's](https://drafts.csswg.org/css2/#viewport%E2%91%A0) associated
 [`Document`](https://dom.spec.whatwg.org/#document).

2. Let `vv` be the
 [`VisualViewport`](#visualviewport) whose [associated document] is
 `doc`.

3. Let `maxX` be the difference between
 [viewport](https://drafts.csswg.org/css2/#viewport%E2%91%A0)'s [scrolling
 box](#scrolling-box)'s
 width and the value of `vv`'s
 [width](#dom-visualviewport-width) attribute.

4. Let `maxY` be the difference between
 [viewport](https://drafts.csswg.org/css2/#viewport%E2%91%A0)'s [scrolling
 box](#scrolling-box)'s
 height and the value of `vv`'s
 [height](#dom-visualviewport-height) attribute.

5. Let `dx` be the horizontal component of
 `position` - the value `vv`'s
 [pageLeft](#dom-visualviewport-pageleft) attribute

6. Let `dy` be the vertical component of
 `position` - the value of `vv`'s
 [pageTop](#dom-visualviewport-pagetop) attribute

7. Let `visual x` be the value of `vv`'s
 [offsetLeft](#dom-visualviewport-offsetleft) attribute.

8. Let `visual y` be the value of `vv`'s
 [offsetTop](#dom-visualviewport-offsettop) attribute.

9. Let `visual dx` be min(`maxX`, max(0,
 `visual x` + `dx`)) - `visual x`.

10. Let `visual dy` be min(`maxY`, max(0,
 `visual y` + `dy`)) - `visual y`.

11. Let `layout dx` be `dx` -
 `visual dx`

12. Let `layout dy` be `dy` -
 `visual dy`

13. Let `element` be `doc`'s root element if there
 is one, null otherwise.

14. [Perform a scroll](#perform-a-scroll) of the
 [viewport](https://drafts.csswg.org/css2/#viewport%E2%91%A0)'s [scrolling
 box](#scrolling-box) to its
 current scroll position + (`layout dx`,
 `layout dy`) with `element` as the associated
 element, and `behavior` as the scroll behavior. Let
 `scrollPromise1` be the
 [`Promise`](https://webidl.spec.whatwg.org/#idl-promise) returned from this step.

15. [Perform a scroll](#perform-a-scroll) of `vv`'s [scrolling
 box](#scrolling-box) to its
 current scroll position + (`visual dx`,
 `visual dy`) with `element` as the associated
 element, and `behavior` as the scroll behavior. Let
 `scrollPromise2` be the
 [`Promise`](https://webidl.spec.whatwg.org/#idl-promise) returned from this step.

16. Let `scrollPromise` be a new
 [`Promise`](https://webidl.spec.whatwg.org/#idl-promise).

17. Return `scrollPromise`, and run the remaining steps [in
 parallel](https://html.spec.whatwg.org/multipage/infrastructure.html#in-parallel).

18. Resolve `scrollPromise` when both
 `scrollPromise1` and `scrollPromise2` have
 settled.

 Conceptually, the visual viewport is scrolled until it
\"bumps up\" against the layout viewport edge and then \"pushes\" the
layout viewport by applying the scroll delta to the layout viewport.
However, the scrolls in the steps above are computed ahead of time and
applied in the opposite order so that the layout viewport is scrolled
before the visual viewport. This is done for historical reasons to
ensure consistent scroll event ordering. See the
[example](https://drafts.csswg.org/css-viewport/#example-vvanimation)
for a visual depiction.

The user pinch-zooms into the document
and ticks their mouse wheel, requesting the user agent scroll the
document down by 50px. Because the document is pinch-zoomed in, the
visual viewport has 20px of room to scroll. The user agent distributes
the scroll by scrolling the visual viewport down by 20px and the layout
viewport by 30px.

The user is viewing a document in a
mobile user agent. The document focuses an offscreen text input element,
showing a virtual keyboard which shrinks the visual viewport. The user
agent must now bring the element into view in the visual viewport. The
user agent scrolls the layout viewport so that the element is visible
within it, then the visual viewport so that the element is visible to
the user.

Scroll is [completed] when the scroll position has no more
pending updates or translations and the user has completed their
gesture. Scroll position updates include smooth or instant mouse wheel
scrolling, keyboard scrolling, scroll-snap events, or other APIs and
gestures which cause the scroll position to update and possibly
interpolate. User gestures like touch panning or trackpad scrolling
aren't complete until pointers or keys have released.

When a user agent is to perform a [smooth scroll] of a [scrolling
box](#scrolling-box)
`box` to `position`, it must update the scroll
position of `box` in a user-agent-defined fashion over a
user-agent-defined amount of time. When the scroll is
[completed], the scroll position of
`box` must be `position`. The scroll can also be
[aborted], either by an algorithm or by the
user.

When a user agent is to perform an [instant
scroll] of a [scrolling
box](#scrolling-box)
`box` to `position`, it must update the scroll
position of `box` to `position`.

To [scroll to the beginning of the
document] for a document `document`, follow
these steps:

1. Let `viewport` be the
 [viewport](https://drafts.csswg.org/css2/#viewport%E2%91%A0) that is associated with `document`.
2. Let `position` be the scroll position
 `viewport` would have by aligning the [beginning
 edges](#beginning-edges)
 of the [scrolling area](#scrolling-area) with the [beginning
 edges] of `viewport`.
3. If `position` is the same as `viewport`'s
 current scroll position, and `viewport` does not have an
 ongoing [smooth
 scroll](#concept-smooth-scroll), abort these steps.
4. [Perform a
 scroll](#viewport-perform-a-scroll) of `viewport` to `position`,
 and `document`'s [root
 element](https://drafts.csswg.org/css-display-4/#root-element) as the associated element, if there is one, or null
 otherwise.

 This algorithm is used when navigating to the `#top`
fragment identifier, as defined in HTML.
[\[HTML\]](#biblio-html "HTML Standard")

Tests

- [interrupt-hidden-smooth-scroll.html](https://wpt.fyi/results/css/cssom-view/interrupt-hidden-smooth-scroll.html "css/cssom-view/interrupt-hidden-smooth-scroll.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/interrupt-hidden-smooth-scroll.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/interrupt-hidden-smooth-scroll.html)
- [long_scroll_composited.html](https://wpt.fyi/results/css/cssom-view/long_scroll_composited.html "css/cssom-view/long_scroll_composited.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/long_scroll_composited.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/long_scroll_composited.html)
- [scroll-back-to-initial-position.html](https://wpt.fyi/results/css/cssom-view/scroll-back-to-initial-position.html "css/cssom-view/scroll-back-to-initial-position.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/scroll-back-to-initial-position.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/scroll-back-to-initial-position.html)
- [scrolling-no-browsing-context.html](https://wpt.fyi/results/css/cssom-view/scrolling-no-browsing-context.html "css/cssom-view/scrolling-no-browsing-context.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/scrolling-no-browsing-context.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/scrolling-no-browsing-context.html)
- [scrolling-quirks-vs-nonquirks.html](https://wpt.fyi/results/css/cssom-view/scrolling-quirks-vs-nonquirks.html "css/cssom-view/scrolling-quirks-vs-nonquirks.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/scrolling-quirks-vs-nonquirks.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/scrolling-quirks-vs-nonquirks.html)
- [smooth-scroll-in-load-event.html](https://wpt.fyi/results/css/cssom-view/smooth-scroll-in-load-event.html "css/cssom-view/smooth-scroll-in-load-event.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/smooth-scroll-in-load-event.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/smooth-scroll-in-load-event.html)
- [smooth-scroll-nonstop.html](https://wpt.fyi/results/css/cssom-view/smooth-scroll-nonstop.html "css/cssom-view/smooth-scroll-nonstop.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/smooth-scroll-nonstop.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/smooth-scroll-nonstop.html)

### 3.2. WebIDL values

When asked to [normalize non-finite values] for a value
`x`, if `x` is one of the three special floating
point literal values (`Infinity`, `-Infinity` or `NaN`), then
`x` must be changed to the value `0`.
[\[WEBIDL\]](#biblio-webidl "Web IDL Standard")

## [4. ][Extensions to the [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window) Interface]
```
enum ScrollBehavior { "auto", "instant", "smooth" };

dictionary ScrollOptions {
 ScrollBehavior behavior = "auto";
};
dictionary ScrollToOptions : ScrollOptions {
 unrestricted double left;
 unrestricted double top;
};

partial interface Window {
 [NewObject] MediaQueryList matchMedia(CSSOMString query);
 [SameObject, Replaceable] readonly attribute Screen screen;
 [SameObject, Replaceable] readonly attribute VisualViewport? visualViewport;

 // browsing context
 undefined moveTo(long x, long y);
 undefined moveBy(long x, long y);
 undefined resizeTo(long width, long height);
 undefined resizeBy(long x, long y);

 // viewport
 [Replaceable] readonly attribute long innerWidth;
 [Replaceable] readonly attribute long innerHeight;

 // viewport scrolling
 [Replaceable] readonly attribute double scrollX;
 [Replaceable] readonly attribute double pageXOffset;
 [Replaceable] readonly attribute double scrollY;
 [Replaceable] readonly attribute double pageYOffset;
 Promise<undefined> scroll(optional ScrollToOptions options = );
 Promise<undefined> scroll(unrestricted double x, unrestricted double y);
 Promise<undefined> scrollTo(optional ScrollToOptions options = );
 Promise<undefined> scrollTo(unrestricted double x, unrestricted double y);
 Promise<undefined> scrollBy(optional ScrollToOptions options = );
 Promise<undefined> scrollBy(unrestricted double x, unrestricted double y);

 // client
 [Replaceable] readonly attribute long screenX;
 [Replaceable] readonly attribute long screenLeft;
 [Replaceable] readonly attribute long screenY;
 [Replaceable] readonly attribute long screenTop;
 [Replaceable] readonly attribute long outerWidth;
 [Replaceable] readonly attribute long outerHeight;
 [Replaceable] readonly attribute double devicePixelRatio;
};
```

Should the scroll methods above return a
result object and if so what information should they provide? #12495

When the [`matchMedia(``query``)`] method is invoked these steps must be run:

1. Let `parsed media query list` be the result of
 [parsing](https://drafts.csswg.org/cssom-1/#parse-a-media-query-list) `query`.
2. Return a new
 [`MediaQueryList`](#mediaquerylist) object, with
 [this](https://webidl.spec.whatwg.org/#this)'s [associated
 `Document`](#associated-document) as the
 [document](#mediaquerylist-document), with `parsed media query list` as its
 associated [media query
 list](#mediaquerylist-media-query-list).

Tests

- [matchMedia-display-none-iframe.html](https://wpt.fyi/results/css/cssom-view/matchMedia-display-none-iframe.html "css/cssom-view/matchMedia-display-none-iframe.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/matchMedia-display-none-iframe.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/matchMedia-display-none-iframe.html)
- [matchMedia.html](https://wpt.fyi/results/css/cssom-view/matchMedia.html "css/cssom-view/matchMedia.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/matchMedia.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/matchMedia.html)

The [`screen`] attribute must return
the [`Screen`](#screen) object
associated with the
[`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window) object.

 Accessing
[`screen`](#dom-window-screen) through a
[`WindowProxy`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#windowproxy) object might yield different results when the
[`Document`](https://dom.spec.whatwg.org/#document) is navigated.

If the [associated
document](#associated-document) is [fully
active](https://html.spec.whatwg.org/multipage/document-sequences.html#fully-active), the [`visualViewport`]
attribute must return the
[`VisualViewport`](#visualviewport) object associated with the
[`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window) object's [associated
document]. Otherwise, it must return
null.

 the VisualViewport object is only returned and useful
for a window whose Document is currently being presented. If a reference
is retained to a VisualViewport whose associated Document is not being
currently presented, the values in that VisualViewport must not reveal
any information about the browsing context.

Tests

- [window-screen-height-immutable.html](https://wpt.fyi/results/css/cssom-view/window-screen-height-immutable.html "css/cssom-view/window-screen-height-immutable.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/window-screen-height-immutable.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/window-screen-height-immutable.html)
- [window-screen-height.html](https://wpt.fyi/results/css/cssom-view/window-screen-height.html "css/cssom-view/window-screen-height.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/window-screen-height.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/window-screen-height.html)
- [window-screen-width-immutable.html](https://wpt.fyi/results/css/cssom-view/window-screen-width-immutable.html "css/cssom-view/window-screen-width-immutable.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/window-screen-width-immutable.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/window-screen-width-immutable.html)
- [window-screen-width.html](https://wpt.fyi/results/css/cssom-view/window-screen-width.html "css/cssom-view/window-screen-width.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/window-screen-width.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/window-screen-width.html)

The [`moveTo(``x``, ``y``)`] method must follow these steps:

1. Optionally, return.

2. Let `target` be
 [this](https://webidl.spec.whatwg.org/#this)'s [relevant global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global)'s [browsing
 context](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window-bc).

3. If `target` is not an [auxiliary browsing
 context](https://html.spec.whatwg.org/multipage/document-sequences.html#auxiliary-browsing-context) that was created by a script (as opposed to by an
 action of the user), then return.

4. If `target`'s [top-level
 traversable](https://html.spec.whatwg.org/multipage/document-sequences.html#bc-traversable)'s [Is Document Picture-in-Picture]
 boolean is `true`, then return.

5. Optionally, clamp `x` and `y` in a
 user-agent-defined manner so that the window does not move outside
 the available space.

6. Move `target`'s window such that the window's top left
 corner is at coordinates (`x`, `y`) relative
 to the top left corner of the output device, measured in [CSS
 pixels](https://drafts.csswg.org/css-values-4/#px) of `target`. The positive axes are
 rightward and downward.

The [`moveBy(``x``, ``y``)`] method must follow these steps:

1. Optionally, return.

2. Let `target` be
 [this](https://webidl.spec.whatwg.org/#this)'s [relevant global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global)'s [browsing
 context](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window-bc).

3. If `target` is not an [auxiliary browsing
 context](https://html.spec.whatwg.org/multipage/document-sequences.html#auxiliary-browsing-context) that was created by a script (as opposed to by an
 action of the user), then return.

4. If `target`'s [top-level
 traversable](https://html.spec.whatwg.org/multipage/document-sequences.html#bc-traversable)'s [Is Document Picture-in-Picture]
 boolean is `true`, then return.

5. Optionally, clamp `x` and `y` in a
 user-agent-defined manner so that the window does not move outside
 the available space.

6. Move `target`'s window `x` [CSS
 pixels](https://drafts.csswg.org/css-values-4/#px) of `target` rightward and
 `y` [CSS pixels] of `target`
 downward.

The
[`resizeTo(``width``, ``height``)`] method must follow these steps:

1. Optionally, return.

2. Let `target` be
 [this](https://webidl.spec.whatwg.org/#this)'s [relevant global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global)'s [browsing
 context](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window-bc).

3. If `target` is not an [auxiliary browsing
 context](https://html.spec.whatwg.org/multipage/document-sequences.html#auxiliary-browsing-context) that was created by a script (as opposed to by an
 action of the user), then return.

4. If `target`'s [top-level
 traversable](https://html.spec.whatwg.org/multipage/document-sequences.html#bc-traversable)'s [Is Document Picture-in-Picture]
 boolean is `true`, then:

 1. If [this](https://webidl.spec.whatwg.org/#this)'s [relevant global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global) does not have [transient
 activation](https://html.spec.whatwg.org/multipage/interaction.html#transient-activation), throw a
 \"[`NotAllowedError`](https://webidl.spec.whatwg.org/#notallowederror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

 2. [Consume user
 activation](https://html.spec.whatwg.org/multipage/interaction.html#consume-user-activation) given
 [this](https://webidl.spec.whatwg.org/#this)'s [relevant global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global).

5. Optionally, clamp `width` and `height` in a
 user-agent-defined manner so that the window does not get too small
 or bigger than the available space.

6. Resize `target`'s window by moving its right and bottom
 edges such that the distance between the left and right edges of the
 viewport are `width` [CSS
 pixels](https://drafts.csswg.org/css-values-4/#px) of `target` and the distance between
 the top and bottom edges of the viewport are `height`
 [CSS pixels] of `target`.

7. Optionally, move `target`'s window in a
 user-agent-defined manner so that it does not grow outside the
 available space.

Tests

- [resizeTo-negative.html](https://wpt.fyi/results/css/cssom-view/resizeTo-negative.html "css/cssom-view/resizeTo-negative.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/resizeTo-negative.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/resizeTo-negative.html)

The
[`resizeBy(``x``, ``y``)`] method must follow these steps:

1. Optionally, return.

2. Let `target` be
 [this](https://webidl.spec.whatwg.org/#this)'s [relevant global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global)'s [browsing
 context](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window-bc).

3. If `target` is not an [auxiliary browsing
 context](https://html.spec.whatwg.org/multipage/document-sequences.html#auxiliary-browsing-context) that was created by a script (as opposed to by an
 action of the user), then return.

4. If `target`'s [top-level
 traversable](https://html.spec.whatwg.org/multipage/document-sequences.html#bc-traversable)'s [Is Document Picture-in-Picture]
 boolean is `true`, then:

 1. If [this](https://webidl.spec.whatwg.org/#this)'s [relevant global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global) does not have [transient
 activation](https://html.spec.whatwg.org/multipage/interaction.html#transient-activation), throw a
 \"[`NotAllowedError`](https://webidl.spec.whatwg.org/#notallowederror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

 2. [Consume user
 activation](https://html.spec.whatwg.org/multipage/interaction.html#consume-user-activation) given
 [this](https://webidl.spec.whatwg.org/#this)'s [relevant global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global).

5. Optionally, clamp `x` and `y` in a
 user-agent-defined manner so that the window does not get too small
 or bigger than the available space.

6. Resize `target`'s window by moving its right edge
 `x` [CSS
 pixels](https://drafts.csswg.org/css-values-4/#px) of `target` rightward and its
 bottom edge `y` [CSS pixels] of
 `target` downward.

7. Optionally, move `target`'s window in a
 user-agent-defined manner so that it does not grow outside the
 available space.

The [`innerWidth`] attribute must return
the
[viewport](https://drafts.csswg.org/css2/#viewport%E2%91%A0) width including the size of a rendered scroll bar (if
any), or zero if there is no [viewport].

The following snippet shows how to
obtain the width of the viewport:

 var viewportWidth = innerWidth

The [`innerHeight`] attribute must return
the
[viewport](https://drafts.csswg.org/css2/#viewport%E2%91%A0) height including the size of a rendered scroll bar (if
any), or zero if there is no [viewport].

The [`scrollX`] attribute must return
the x-coordinate, relative to the [initial containing
block](https://drafts.csswg.org/css-display-4/#initial-containing-block) origin, of the left of the
[viewport](https://drafts.csswg.org/css2/#viewport%E2%91%A0), or zero if there is no
[viewport].

The [`pageXOffset`] attribute must return
the value returned by the
[`scrollX`](#dom-window-scrollx) attribute.

The [`scrollY`] attribute must return
the y-coordinate, relative to the [initial containing
block](https://drafts.csswg.org/css-display-4/#initial-containing-block) origin, of the top of the
[viewport](https://drafts.csswg.org/css2/#viewport%E2%91%A0), or zero if there is no
[viewport].

The [`pageYOffset`] attribute must return
the value returned by the
[`scrollY`](#dom-window-scrolly) attribute.

When the [`scroll()`] method is invoked these
steps must be run:

1. If invoked with one argument, follow these substeps:

 1. Let `options` be the argument.

 2. Let `x` be the value of the
 [`left`](#dom-scrolltooptions-left) dictionary member of `options`, if
 present, or the
 [viewport's](https://drafts.csswg.org/css2/#viewport%E2%91%A0) current scroll position on the x axis
 otherwise.

 3. Let `y` be the value of the
 [`top`](#dom-scrolltooptions-top) dictionary member of `options`, if
 present, or the
 [viewport's](https://drafts.csswg.org/css2/#viewport%E2%91%A0) current scroll position on the y axis
 otherwise.

2. If invoked with two arguments, follow these substeps:

 1. Let `options` be null
 [converted](https://webidl.spec.whatwg.org/#dfn-convert-ecmascript-to-idl-value) to a
 [`ScrollToOptions`](#dictdef-scrolltooptions) dictionary.
 [\[WEBIDL\]](#biblio-webidl "Web IDL Standard")

 2. Let `x` and `y` be the arguments,
 respectively.

3. [Normalize non-finite
 values](#normalize-non-finite-values) for `x` and `y`.

4. If there is no
 [viewport](https://drafts.csswg.org/css2/#viewport%E2%91%A0), return a resolved
 [`Promise`](https://webidl.spec.whatwg.org/#idl-promise) and abort the remaining steps.

5. Let `viewport width` be the width of the
 [viewport](https://drafts.csswg.org/css2/#viewport%E2%91%A0) excluding the width of the scroll bar, if any.

6. Let `viewport height` be the height of the
 [viewport](https://drafts.csswg.org/css2/#viewport%E2%91%A0) excluding the height of the scroll bar, if any.

7.

 If the [viewport](https://drafts.csswg.org/css2/#viewport%E2%91%A0) has rightward [overflow direction](#overflow-directions)
 : Let `x` be max(0, min(`x`,
 [viewport](https://drafts.csswg.org/css2/#viewport%E2%91%A0) [scrolling
 area](#scrolling-area)
 width - `viewport width`)).

 If the [viewport](https://drafts.csswg.org/css2/#viewport%E2%91%A0) has leftward [overflow direction](#overflow-directions)
 : Let `x` be min(0, max(`x`,
 `viewport width` -
 [viewport](https://drafts.csswg.org/css2/#viewport%E2%91%A0) [scrolling
 area](#scrolling-area)
 width)).

8.

 If the [viewport](https://drafts.csswg.org/css2/#viewport%E2%91%A0) has downward [overflow direction](#overflow-directions)
 : Let `y` be max(0, min(`y`,
 [viewport](https://drafts.csswg.org/css2/#viewport%E2%91%A0) [scrolling
 area](#scrolling-area)
 height - `viewport height`)).

 If the [viewport](https://drafts.csswg.org/css2/#viewport%E2%91%A0) has upward [overflow direction](#overflow-directions)
 : Let `y` be min(0, max(`y`,
 `viewport height` -
 [viewport](https://drafts.csswg.org/css2/#viewport%E2%91%A0) [scrolling
 area](#scrolling-area)
 height)).

9. Let `position` be the scroll position the
 [viewport](https://drafts.csswg.org/css2/#viewport%E2%91%A0) would have by aligning the x-coordinate
 `x` of the [viewport]
 [scrolling area](#scrolling-area) with the left of the
 [viewport] and aligning the
 y-coordinate `y` of the
 [viewport] [scrolling
 area] with the top of the
 [viewport].

10. If `position` is the same as the
 [viewport's](https://drafts.csswg.org/css2/#viewport%E2%91%A0) current scroll position, and the
 [viewport] does not have an ongoing
 [smooth
 scroll](#concept-smooth-scroll), return a resolved
 [`Promise`](https://webidl.spec.whatwg.org/#idl-promise) and abort the remaining steps.

11. Let `document` be the
 [viewport's](https://drafts.csswg.org/css2/#viewport%E2%91%A0) associated
 [`Document`](https://dom.spec.whatwg.org/#document).

12. [Perform a
 scroll](#viewport-perform-a-scroll) of the
 [viewport](https://drafts.csswg.org/css2/#viewport%E2%91%A0) to `position`, `document`'s
 [root
 element](https://drafts.csswg.org/css-display-4/#root-element) as the associated element, if there is one, or null
 otherwise, and the scroll behavior being the value of the
 [`behavior`](#dom-scrolloptions-behavior) dictionary member of `options`. Let
 `scrollPromise` be the
 [`Promise`](https://webidl.spec.whatwg.org/#idl-promise) returned from this step.

13. Return `scrollPromise`.

 (#issue-1e98b401) User agents do not agree whether
 this uses the (coordinated)
 [viewport](https://drafts.csswg.org/css2/#viewport%E2%91%A0) [perform a
 scroll](#viewport-perform-a-scroll) or the [scrolling
 box](#scrolling-box)
 [perform a scroll](#perform-a-scroll) on the layout viewport's scrolling box.

Tests

- [add-background-attachment-fixed-during-smooth-scroll.html](https://wpt.fyi/results/css/cssom-view/add-background-attachment-fixed-during-smooth-scroll.html "css/cssom-view/add-background-attachment-fixed-during-smooth-scroll.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/add-background-attachment-fixed-during-smooth-scroll.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/add-background-attachment-fixed-during-smooth-scroll.html)
- [HTMLBody-ScrollArea_quirksmode.html](https://wpt.fyi/results/css/cssom-view/HTMLBody-ScrollArea_quirksmode.html "css/cssom-view/HTMLBody-ScrollArea_quirksmode.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/HTMLBody-ScrollArea_quirksmode.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/HTMLBody-ScrollArea_quirksmode.html)
- [window-scroll-arguments.html](https://wpt.fyi/results/css/cssom-view/window-scroll-arguments.html "css/cssom-view/window-scroll-arguments.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/window-scroll-arguments.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/window-scroll-arguments.html)
- [window-scroll-promise-interruption.html](https://wpt.fyi/results/css/cssom-view/window-scroll-promise-interruption.html "css/cssom-view/window-scroll-promise-interruption.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/window-scroll-promise-interruption.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/window-scroll-promise-interruption.html)
- [window-scroll-promises.html](https://wpt.fyi/results/css/cssom-view/window-scroll-promises.html "css/cssom-view/window-scroll-promises.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/window-scroll-promises.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/window-scroll-promises.html)

When the [`scrollTo()`] method is invoked, the
user agent must act as if the
[`scroll()`](#dom-window-scroll) method was invoked with the same arguments.

Tests

- [background-change-during-smooth-scroll.html](https://wpt.fyi/results/css/cssom-view/background-change-during-smooth-scroll.html "css/cssom-view/background-change-during-smooth-scroll.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/background-change-during-smooth-scroll.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/background-change-during-smooth-scroll.html)
- [scrollTo-zoom.html](https://wpt.fyi/results/css/cssom-view/scrollTo-zoom.html "css/cssom-view/scrollTo-zoom.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/scrollTo-zoom.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/scrollTo-zoom.html)

When the [`scrollBy()`] method is invoked, the
user agent must run these steps:

1. If invoked with two arguments, follow these substeps:

 1. Let `options` be null
 [converted](https://webidl.spec.whatwg.org/#dfn-convert-ecmascript-to-idl-value) to a
 [`ScrollToOptions`](#dictdef-scrolltooptions) dictionary.
 [\[WEBIDL\]](#biblio-webidl "Web IDL Standard")

 2. Let `x` and `y` be the arguments,
 respectively.

 3. Let the
 [`left`](#dom-scrolltooptions-left) dictionary member of `options` have
 the value `x`.

 4. Let the
 [`top`](#dom-scrolltooptions-top) dictionary member of `options` have
 the value `y`.

2. [Normalize non-finite
 values](#normalize-non-finite-values) for the
 [`left`](#dom-scrolltooptions-left) and
 [`top`](#dom-scrolltooptions-top) dictionary members of `options`.

3. Add the value of
 [`scrollX`](#dom-window-scrollx) to the
 [`left`](#dom-scrolltooptions-left) dictionary member.

4. Add the value of
 [`scrollY`](#dom-window-scrolly) to the
 [`top`](#dom-scrolltooptions-top) dictionary member.

5. Return the
 [`Promise`](https://webidl.spec.whatwg.org/#idl-promise) returned from
 [`scroll()`](#dom-window-scroll) after the method is invoked with
 `options` as the only argument.

The [`screenX`] and
[`screenLeft`] attributes must return
the x-coordinate, relative to the origin of the [Web-exposed screen
area](#web-exposed-screen-area), of the left of the client window as number of [CSS
pixels](https://drafts.csswg.org/css-values-4/#px), or zero if there is no such thing.

Tests

- [screenLeftTop.html](https://wpt.fyi/results/css/cssom-view/screenLeftTop.html "css/cssom-view/screenLeftTop.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/screenLeftTop.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/screenLeftTop.html)

The [`screenY`] and
[`screenTop`] attributes must return
the y-coordinate, relative to the origin of the screen of the
[Web-exposed screen
area](#web-exposed-screen-area), of the top of the client window as number of [CSS
pixels](https://drafts.csswg.org/css-values-4/#px), or zero if there is no such thing.

The [`outerWidth`] attribute must return
the width of the client window. If there is no client window this
attribute must return zero.

The [`outerHeight`] attribute must return
the height of the client window. If there is no client window this
attribute must return zero.

The [`devicePixelRatio`] attribute must return the result of the
following [determine the device pixel
ratio] algorithm:

1. If there is no output device, return 1 and abort these steps.

2. Let `CSS pixel size` be the size of a [CSS
 pixel](https://drafts.csswg.org/css-values-4/#px) at the current [page
 zoom](#page-zoom) and using a
 [scale
 factor](https://drafts.csswg.org/css-viewport/#scale-factor) of 1.0.

3. Let `device pixel size` be the vertical size of a device
 pixel of the output device.

4. Return the result of dividing `CSS pixel size` by
 `device pixel size`.

### [4.1. ][The `features` argument to the [`open()`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#dom-open) method](#the-features-argument-to-the-open()-method)

HTML defines the
[`open()`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#dom-open) method. This section defines behavior for position and
size given in the `features` argument.
[\[HTML\]](#biblio-html "HTML Standard")

To [set up browsing context features] for a browsing context
`target` given a
[map](https://infra.spec.whatwg.org/#ordered-map) `tokenizedFeatures`:

1. Let `x` be null.

2. Let `y` be null.

3. Let `width` be null.

4. Let `height` be null.

5. If
 `tokenizedFeatures`\[\"[left](#supported-open-feature-name-left)\"\]
 [exists](https://infra.spec.whatwg.org/#map-exists):

 1. Set `x` to the result of invoking the [rules for
 parsing
 integers](https://html.spec.whatwg.org/multipage/common-microsyntaxes.html#rules-for-parsing-integers) on
 `tokenizedFeatures`\[\"[left](#supported-open-feature-name-left)\"\].

 2. If `x` is an error, set `x` to 0.

 3. Optionally, clamp `x` in a user-agent-defined manner
 so that the window does not move outside the [Web-exposed
 available screen
 area](#web-exposed-available-screen-area).

 4. Optionally, move `target`'s window such that the
 window's left edge is at the horizontal coordinate
 `x` relative to the left edge of the [Web-exposed
 screen
 area](#web-exposed-screen-area), measured in [CSS
 pixels](https://drafts.csswg.org/css-values-4/#px) of `target`. The positive
 axis is rightward.

6. If
 `tokenizedFeatures`\[\"[top](#supported-open-feature-name-top)\"\]
 [exists](https://infra.spec.whatwg.org/#map-exists):

 1. Set `y` to the result of invoking the [rules for
 parsing
 integers](https://html.spec.whatwg.org/multipage/common-microsyntaxes.html#rules-for-parsing-integers) on
 `tokenizedFeatures`\[\"[top](#supported-open-feature-name-top)\"\].

 2. If `y` is an error, set `y` to 0.

 3. Optionally, clamp `y` in a user-agent-defined manner
 so that the window does not move outside the [Web-exposed
 available screen
 area](#web-exposed-available-screen-area).

 4. Optionally, move `target`'s window such that the
 window's top edge is at the vertical coordinate `y`
 relative to the top edge of the [Web-exposed screen
 area](#web-exposed-screen-area), measured in [CSS
 pixels](https://drafts.csswg.org/css-values-4/#px) of `target`. The positive
 axis is downward.

7. If
 `tokenizedFeatures`\[\"[width](#supported-open-feature-name-width)\"\]
 [exists](https://infra.spec.whatwg.org/#map-exists):

 1. Set `width` to the result of invoking the [rules for
 parsing
 integers](https://html.spec.whatwg.org/multipage/common-microsyntaxes.html#rules-for-parsing-integers) on
 `tokenizedFeatures`\[\"[width](#supported-open-feature-name-width)\"\].

 2. If `width` is an error, set `width` to 0.

 3. If `width` is not 0:

 1. Optionally, clamp `width` in a user-agent-defined
 manner so that the window does not get too small or bigger
 than the [Web-exposed available screen
 area](#web-exposed-available-screen-area).

 2. Optionally, size `target`'s window by moving its
 right edge such that the distance between the left and right
 edges of the viewport are `width` [CSS
 pixels](https://drafts.csswg.org/css-values-4/#px) of `target`.

 3. Optionally, move `target`'s window in a
 user-agent-defined manner so that it does not grow outside
 the [Web-exposed available screen
 area](#web-exposed-available-screen-area).

8. If
 `tokenizedFeatures`\[\"[height](#supported-open-feature-name-height)\"\]
 [exists](https://infra.spec.whatwg.org/#map-exists):

 1. Set `height` to the result of invoking the [rules for
 parsing
 integers](https://html.spec.whatwg.org/multipage/common-microsyntaxes.html#rules-for-parsing-integers) on
 `tokenizedFeatures`\[\"[height](#supported-open-feature-name-height)\"\].

 2. If `height` is an error, set `height` to
 0.

 3. If `height` is not 0:

 1. Optionally, clamp `height` in a
 user-agent-defined manner so that the window does not get
 too small or bigger than the [Web-exposed available screen
 area](#web-exposed-available-screen-area).

 2. Optionally, size `target`'s window by moving its
 bottom edge such that the distance between the top and
 bottom edges of the viewport are `height` [CSS
 pixels](https://drafts.csswg.org/css-values-4/#px) of `target`.

 3. Optionally, move `target`'s window in a
 user-agent-defined manner so that it does not grow outside
 the [Web-exposed available screen
 area](#web-exposed-available-screen-area).

A [supported `open()` feature name] is one of the following:

[width]
: The width of the viewport.

[height]
: The height of the viewport.

[left]
: The left position of the window.

[top]
: The top position of the window.

### 4.2. The [`MediaQueryList` Interface]
This section integrates with the [event
loop](https://html.spec.whatwg.org/multipage/webappapis.html#event-loop) defined in HTML.
[\[HTML\]](#biblio-html "HTML Standard")

A [`MediaQueryList`](#mediaquerylist) object has an associated [media query
list] and an associated
[document] set on creation.

A [`MediaQueryList`](#mediaquerylist) object has an associated [media]
which is the
[serialized](https://drafts.csswg.org/cssom-1/#serialize-a-media-query-list) form of the associated [media query
list](#mediaquerylist-media-query-list).

A [`MediaQueryList`](#mediaquerylist) object has an associated [matches
state] which is true if
the associated [media query
list](#mediaquerylist-media-query-list) matches the state of the
[document](#mediaquerylist-document), and false otherwise.

When asked to [evaluate media queries and report
changes] for a
[`Document`](https://dom.spec.whatwg.org/#document) `doc`, run these steps:

1. For each
 [`MediaQueryList`](#mediaquerylist) object `target` that has
 `doc` as its
 [document](#mediaquerylist-document), in the order they were created, oldest first, run
 these substeps:

 1. If `target`'s [matches
 state](#mediaquerylist-matches-state) has changed since the last time these steps
 were run, [fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire) named
 [change](#eventdef-mediaquerylist-change) at `target` using
 [`MediaQueryListEvent`](#mediaquerylistevent), with its
 [`isTrusted`](https://dom.spec.whatwg.org/#dom-event-istrusted) attribute initialized to true, its
 [`media`](#dom-mediaquerylist-media) attribute initialized to `target`'s
 [media], and its
 [`matches`](#dom-mediaquerylistevent-matches) attribute initialized to `target`'s
 [matches state].

A simple piece of code that detects
changes in the orientation of the viewport can be written as follows:

``` highlight
function handleOrientationChange(event) {
 if(event.matches) // landscape
 …
 else
 …
}
var mql = matchMedia("(orientation:landscape)");
mql.onchange = handleOrientationChange;
```

```
[Exposed=Window]
interface MediaQueryList : EventTarget {
 readonly attribute CSSOMString media;
 readonly attribute boolean matches;
 undefined addListener(EventListener? callback);
 undefined removeListener(EventListener? callback);
 attribute EventHandler onchange;
};
```

The [`media`] attribute must
return the associated [media].

The [`matches`] attribute must
return the associated [matches
state](#mediaquerylist-matches-state).

The
[`addListener(``callback``)`] method, when invoked, must run these steps:

1. [Add an event
 listener](https://dom.spec.whatwg.org/#add-an-event-listener) with
 [this](https://webidl.spec.whatwg.org/#this) and an [event
 listener](https://dom.spec.whatwg.org/#concept-event-listener) whose
 [type](https://dom.spec.whatwg.org/#event-listener-type) is `change`, and
 [callback](https://dom.spec.whatwg.org/#event-listener-callback) is `callback`.

The
[`removeListener(``callback``)`] method, when invoked, must run these steps:

1. If [this](https://webidl.spec.whatwg.org/#this)'s [event listener
 list](https://dom.spec.whatwg.org/#eventtarget-event-listener-list)
 [contains](https://infra.spec.whatwg.org/#list-contain) an [event
 listener](https://dom.spec.whatwg.org/#concept-event-listener) whose
 [type](https://dom.spec.whatwg.org/#event-listener-type) is `change`,
 [callback](https://dom.spec.whatwg.org/#event-listener-callback) is `callback`, and
 [capture](https://dom.spec.whatwg.org/#event-listener-capture) is false, then [remove an event
 listener](https://dom.spec.whatwg.org/#remove-an-event-listener) with [this] and that [event
 listener].

 This specification initially had a custom callback
mechanism with
[`addListener()`](#dom-mediaquerylist-addlistener) and
[`removeListener()`](#dom-mediaquerylist-removelistener), and the callback was invoked with the associated media
query list as argument. Now the normal event mechanism is used instead.
For backwards compatibility, the
[`addListener()`](#dom-mediaquerylist-addlistener) and
[`removeListener()`](#dom-mediaquerylist-removelistener) methods are basically aliases for
[`addEventListener()`](https://dom.spec.whatwg.org/#dom-eventtarget-addeventlistener) and
[`removeEventListener()`](https://dom.spec.whatwg.org/#dom-eventtarget-removeeventlistener), respectively, and the `change` event masquerades as a
[`MediaQueryList`](#mediaquerylist).

The following are the [event
handlers](https://html.spec.whatwg.org/multipage/webappapis.html#event-handlers) (and their corresponding [event handler event
types](https://html.spec.whatwg.org/multipage/webappapis.html#event-handler-event-type)) that must be supported, as [event handler IDL
attributes](https://html.spec.whatwg.org/multipage/webappapis.html#event-handler-idl-attributes), by all objects implementing the
[`MediaQueryList`](#mediaquerylist) interface:

[Event
handler](https://html.spec.whatwg.org/multipage/webappapis.html#event-handlers)

[Event handler event
type](https://html.spec.whatwg.org/multipage/webappapis.html#event-handler-event-type)

[`onchange`]

[change](#eventdef-mediaquerylist-change)

Tests

- [MediaQueryList-addListener-handleEvent.html](https://wpt.fyi/results/css/cssom-view/MediaQueryList-addListener-handleEvent.html "css/cssom-view/MediaQueryList-addListener-handleEvent.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/MediaQueryList-addListener-handleEvent.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/MediaQueryList-addListener-handleEvent.html)
- [MediaQueryList-addListener-removeListener.html](https://wpt.fyi/results/css/cssom-view/MediaQueryList-addListener-removeListener.html "css/cssom-view/MediaQueryList-addListener-removeListener.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/MediaQueryList-addListener-removeListener.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/MediaQueryList-addListener-removeListener.html)
- [MediaQueryList-change-event-matches-value.html](https://wpt.fyi/results/css/cssom-view/MediaQueryList-change-event-matches-value.html "css/cssom-view/MediaQueryList-change-event-matches-value.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/MediaQueryList-change-event-matches-value.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/MediaQueryList-change-event-matches-value.html)
- [MediaQueryList-extends-EventTarget-interop.html](https://wpt.fyi/results/css/cssom-view/MediaQueryList-extends-EventTarget-interop.html "css/cssom-view/MediaQueryList-extends-EventTarget-interop.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/MediaQueryList-extends-EventTarget-interop.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/MediaQueryList-extends-EventTarget-interop.html)
- [MediaQueryList-extends-EventTarget.html](https://wpt.fyi/results/css/cssom-view/MediaQueryList-extends-EventTarget.html "css/cssom-view/MediaQueryList-extends-EventTarget.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/MediaQueryList-extends-EventTarget.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/MediaQueryList-extends-EventTarget.html)
- [MediaQueryListEvent.html](https://wpt.fyi/results/css/cssom-view/MediaQueryListEvent.html "css/cssom-view/MediaQueryListEvent.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/MediaQueryListEvent.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/MediaQueryListEvent.html)

```
[Exposed=Window]
interface MediaQueryListEvent : Event {
 constructor(CSSOMString type, optional MediaQueryListEventInit eventInitDict = );
 readonly attribute CSSOMString media;
 readonly attribute boolean matches;
};

dictionary MediaQueryListEventInit : EventInit {
 CSSOMString media = "";
 boolean matches = false;
};
```

The [`media`] attribute
must return the value it was initialized to.

The [`matches`]
attribute must return the value it was initialized to.

#### 4.2.1. Event summary

*This section is non-normative.*

Event

Interface

Interesting targets

Description

[`change`]

[`MediaQueryListEvent`](#mediaquerylistevent)

[`MediaQueryList`](#mediaquerylist)

Fired at the
[`MediaQueryList`](#mediaquerylist) when the [matches
state](#mediaquerylist-matches-state) changes.

### 4.3. The [`Screen` Interface]
As its name suggests, the [`Screen`](#screen) interface represents information about the screen of
the output device.

```
[Exposed=Window]
interface Screen {
 readonly attribute long availWidth;
 readonly attribute long availHeight;
 readonly attribute long width;
 readonly attribute long height;
 readonly attribute unsigned long colorDepth;
 readonly attribute unsigned long pixelDepth;
};
```

The [`availWidth`] attribute must return
the width of the [Web-exposed available screen
area](#web-exposed-available-screen-area).

The [`availHeight`] attribute must return
the height of the [Web-exposed available screen
area](#web-exposed-available-screen-area).

The [`width`] attribute must return
the width of the [Web-exposed screen
area](#web-exposed-screen-area).

The [`height`] attribute must return
the height of the [Web-exposed screen
area](#web-exposed-screen-area).

The [`colorDepth`] and
[`pixelDepth`] attributes should
return the number of bits allocated to colors for a pixel in the output
device, excluding the alpha channel. If the user agent is not able to
return the number of bits used by the output device, it should return
the closest estimation such as, for example, the number of bits used by
the frame buffer sent to the display or any internal representation that
would be the closest to the value the output device would use. The user
agent must return a value for these attributes at least equal to the
value of the
[color](https://drafts.csswg.org/mediaqueries-5/#descdef-media-color) media feature multiplied by three. If
the different color components are not represented with the same number
of bits, the returned value may be greater than three times the value of
the [color] media feature. If
the user agent does not know the color depth or does not want to return
it for privacy considerations, it should return 24.

 The
[`colorDepth`](#dom-screen-colordepth) and
[`pixelDepth`](#dom-screen-pixeldepth) attributes return the same value for compatibility
reasons.

 Some non-conforming implementations are known to return
32 instead of 24.

Tests

- [cssom-view-window-screen-interface.html](https://wpt.fyi/results/css/cssom-view/cssom-view-window-screen-interface.html "css/cssom-view/cssom-view-window-screen-interface.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/cssom-view-window-screen-interface.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/cssom-view-window-screen-interface.html)
- [screen-detached-frame.html](https://wpt.fyi/results/css/cssom-view/screen-detached-frame.html "css/cssom-view/screen-detached-frame.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/screen-detached-frame.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/screen-detached-frame.html)
- [Screen-pixelDepth-Screen-colorDepth001.html](https://wpt.fyi/results/css/cssom-view/Screen-pixelDepth-Screen-colorDepth001.html "css/cssom-view/Screen-pixelDepth-Screen-colorDepth001.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/Screen-pixelDepth-Screen-colorDepth001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/Screen-pixelDepth-Screen-colorDepth001.html)

## [5. ][Extensions to the [`Document`](https://dom.spec.whatwg.org/#document) Interface]
```
partial interface Document {
 Element? elementFromPoint(double x, double y);
 sequence<Element> elementsFromPoint(double x, double y);
 CaretPosition? caretPositionFromPoint(double x, double y, optional CaretPositionFromPointOptions options = );
 readonly attribute Element? scrollingElement;
};

dictionary CaretPositionFromPointOptions {
 sequence<ShadowRoot> shadowRoots = ;
};
```

The
[`elementFromPoint(``x``, ``y``)`] method must follow these steps:

1. If either argument is negative, `x` is greater than the
 [viewport](https://drafts.csswg.org/css2/#viewport%E2%91%A0) width excluding the size of a rendered scroll bar
 (if any), or `y` is greater than the
 [viewport] height excluding the size
 of a rendered scroll bar (if any), or there is no
 [viewport] associated with the
 document, return null and terminate these steps.

2. If there is a
 [box](https://drafts.csswg.org/css-display-4/#box) in the
 [viewport](https://drafts.csswg.org/css2/#viewport%E2%91%A0) that would be a target for hit testing at
 coordinates `x`,`y`, when applying the
 [transforms](#transforms) that
 apply to the descendants of the
 [viewport], return the associated
 element and terminate these steps.

3. If the document has a [root
 element](https://drafts.csswg.org/css-display-4/#root-element), return the [root element]
 and terminate these steps.

4. Return null.

 The
[`elementFromPoint()`](#dom-document-elementfrompoint) method does not necessarily return the top-most painted
element. For instance, an element can be excluded from being a target
for hit testing by using the
[pointer-events](https://drafts.csswg.org/css-ui-4/#propdef-pointer-events) CSS property.

Tests

- [elementFromPoint-001.html](https://wpt.fyi/results/css/cssom-view/elementFromPoint-001.html "css/cssom-view/elementFromPoint-001.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/elementFromPoint-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/elementFromPoint-001.html)
- [elementFromPoint-002.html](https://wpt.fyi/results/css/cssom-view/elementFromPoint-002.html "css/cssom-view/elementFromPoint-002.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/elementFromPoint-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/elementFromPoint-002.html)
- [elementFromPoint-003.html](https://wpt.fyi/results/css/cssom-view/elementFromPoint-003.html "css/cssom-view/elementFromPoint-003.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/elementFromPoint-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/elementFromPoint-003.html)
- [elementFromPoint-dynamic-anon-box.html](https://wpt.fyi/results/css/cssom-view/elementFromPoint-dynamic-anon-box.html "css/cssom-view/elementFromPoint-dynamic-anon-box.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/elementFromPoint-dynamic-anon-box.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/elementFromPoint-dynamic-anon-box.html)
- [elementFromPoint-ellipsis-in-inline-box.html](https://wpt.fyi/results/css/cssom-view/elementFromPoint-ellipsis-in-inline-box.html "css/cssom-view/elementFromPoint-ellipsis-in-inline-box.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/elementFromPoint-ellipsis-in-inline-box.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/elementFromPoint-ellipsis-in-inline-box.html)
- [elementFromPoint-float-in-relative.html](https://wpt.fyi/results/css/cssom-view/elementFromPoint-float-in-relative.html "css/cssom-view/elementFromPoint-float-in-relative.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/elementFromPoint-float-in-relative.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/elementFromPoint-float-in-relative.html)
- [elementFromPoint-float-in-table.html](https://wpt.fyi/results/css/cssom-view/elementFromPoint-float-in-table.html "css/cssom-view/elementFromPoint-float-in-table.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/elementFromPoint-float-in-table.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/elementFromPoint-float-in-table.html)
- [elementFromPoint-list-001.html](https://wpt.fyi/results/css/cssom-view/elementFromPoint-list-001.html "css/cssom-view/elementFromPoint-list-001.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/elementFromPoint-list-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/elementFromPoint-list-001.html)
- [elementFromPoint-mixed-font-sizes.html](https://wpt.fyi/results/css/cssom-view/elementFromPoint-mixed-font-sizes.html "css/cssom-view/elementFromPoint-mixed-font-sizes.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/elementFromPoint-mixed-font-sizes.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/elementFromPoint-mixed-font-sizes.html)
- [elementFromPoint-parameters.html](https://wpt.fyi/results/css/cssom-view/elementFromPoint-parameters.html "css/cssom-view/elementFromPoint-parameters.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/elementFromPoint-parameters.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/elementFromPoint-parameters.html)
- [elementFromPoint-subpixel.html](https://wpt.fyi/results/css/cssom-view/elementFromPoint-subpixel.html "css/cssom-view/elementFromPoint-subpixel.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/elementFromPoint-subpixel.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/elementFromPoint-subpixel.html)
- [elementFromPoint-visibility-hidden-resizer.html](https://wpt.fyi/results/css/cssom-view/elementFromPoint-visibility-hidden-resizer.html "css/cssom-view/elementFromPoint-visibility-hidden-resizer.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/elementFromPoint-visibility-hidden-resizer.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/elementFromPoint-visibility-hidden-resizer.html)
- [elementFromPoint.html](https://wpt.fyi/results/css/cssom-view/elementFromPoint.html "css/cssom-view/elementFromPoint.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/elementFromPoint.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/elementFromPoint.html)
- [elementFromPosition.html](https://wpt.fyi/results/css/cssom-view/elementFromPosition.html "css/cssom-view/elementFromPosition.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/elementFromPosition.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/elementFromPosition.html)
- [negativeMargins.html](https://wpt.fyi/results/css/cssom-view/negativeMargins.html "css/cssom-view/negativeMargins.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/negativeMargins.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/negativeMargins.html)

The
[`elementsFromPoint(``x``, ``y``)`] method must follow these steps:

1. Let `sequence` be a new empty sequence.

2. If either argument is negative, `x` is greater than the
 [viewport](https://drafts.csswg.org/css2/#viewport%E2%91%A0) width excluding the size of a rendered scroll bar
 (if any), or `y` is greater than the
 [viewport] height excluding the size
 of a rendered scroll bar (if any), or there is no
 [viewport] associated with the
 document, return `sequence` and terminate these steps.

3. For each
 [box](https://drafts.csswg.org/css-display-4/#box) in the
 [viewport](https://drafts.csswg.org/css2/#viewport%E2%91%A0), in paint order, starting with the topmost box,
 that would be a target for hit testing at coordinates
 `x`,`y` even if nothing would be overlapping
 it, when applying the [transforms](#transforms) that apply to the descendants of the
 [viewport], append the associated
 element to `sequence`.

4. If the document has a [root
 element](https://drafts.csswg.org/css-display-4/#root-element), and the last item in `sequence` is not
 the [root element], append the [root
 element] to `sequence`.

5. Return `sequence`.

Tests

- [elementsFromPoint-iframes.html](https://wpt.fyi/results/css/cssom-view/elementsFromPoint-iframes.html "css/cssom-view/elementsFromPoint-iframes.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/elementsFromPoint-iframes.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/elementsFromPoint-iframes.html)
- [elementsFromPoint-inline-htb-ltr.html](https://wpt.fyi/results/css/cssom-view/elementsFromPoint-inline-htb-ltr.html "css/cssom-view/elementsFromPoint-inline-htb-ltr.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/elementsFromPoint-inline-htb-ltr.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/elementsFromPoint-inline-htb-ltr.html)
- [elementsFromPoint-inline-htb-rtl.html](https://wpt.fyi/results/css/cssom-view/elementsFromPoint-inline-htb-rtl.html "css/cssom-view/elementsFromPoint-inline-htb-rtl.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/elementsFromPoint-inline-htb-rtl.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/elementsFromPoint-inline-htb-rtl.html)
- [elementsFromPoint-inline-nested.html](https://wpt.fyi/results/css/cssom-view/elementsFromPoint-inline-nested.html "css/cssom-view/elementsFromPoint-inline-nested.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/elementsFromPoint-inline-nested.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/elementsFromPoint-inline-nested.html)
- [elementsFromPoint-inline-vlr-ltr.html](https://wpt.fyi/results/css/cssom-view/elementsFromPoint-inline-vlr-ltr.html "css/cssom-view/elementsFromPoint-inline-vlr-ltr.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/elementsFromPoint-inline-vlr-ltr.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/elementsFromPoint-inline-vlr-ltr.html)
- [elementsFromPoint-inline-vlr-rtl.html](https://wpt.fyi/results/css/cssom-view/elementsFromPoint-inline-vlr-rtl.html "css/cssom-view/elementsFromPoint-inline-vlr-rtl.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/elementsFromPoint-inline-vlr-rtl.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/elementsFromPoint-inline-vlr-rtl.html)
- [elementsFromPoint-inline-vrl-ltr.html](https://wpt.fyi/results/css/cssom-view/elementsFromPoint-inline-vrl-ltr.html "css/cssom-view/elementsFromPoint-inline-vrl-ltr.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/elementsFromPoint-inline-vrl-ltr.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/elementsFromPoint-inline-vrl-ltr.html)
- [elementsFromPoint-inline-vrl-rtl.html](https://wpt.fyi/results/css/cssom-view/elementsFromPoint-inline-vrl-rtl.html "css/cssom-view/elementsFromPoint-inline-vrl-rtl.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/elementsFromPoint-inline-vrl-rtl.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/elementsFromPoint-inline-vrl-rtl.html)
- [elementsFromPoint-invalid-cases.html](https://wpt.fyi/results/css/cssom-view/elementsFromPoint-invalid-cases.html "css/cssom-view/elementsFromPoint-invalid-cases.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/elementsFromPoint-invalid-cases.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/elementsFromPoint-invalid-cases.html)
- [elementsFromPoint-shadowroot.html](https://wpt.fyi/results/css/cssom-view/elementsFromPoint-shadowroot.html "css/cssom-view/elementsFromPoint-shadowroot.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/elementsFromPoint-shadowroot.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/elementsFromPoint-shadowroot.html)
- [elementsFromPoint-simple.html](https://wpt.fyi/results/css/cssom-view/elementsFromPoint-simple.html "css/cssom-view/elementsFromPoint-simple.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/elementsFromPoint-simple.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/elementsFromPoint-simple.html)
- [elementsFromPoint-svg-text.html](https://wpt.fyi/results/css/cssom-view/elementsFromPoint-svg-text.html "css/cssom-view/elementsFromPoint-svg-text.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/elementsFromPoint-svg-text.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/elementsFromPoint-svg-text.html)
- [elementsFromPoint-svg.html](https://wpt.fyi/results/css/cssom-view/elementsFromPoint-svg.html "css/cssom-view/elementsFromPoint-svg.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/elementsFromPoint-svg.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/elementsFromPoint-svg.html)
- [elementsFromPoint-table.html](https://wpt.fyi/results/css/cssom-view/elementsFromPoint-table.html "css/cssom-view/elementsFromPoint-table.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/elementsFromPoint-table.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/elementsFromPoint-table.html)
- [elementsFromPoint.html](https://wpt.fyi/results/css/cssom-view/elementsFromPoint.html "css/cssom-view/elementsFromPoint.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/elementsFromPoint.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/elementsFromPoint.html)

The
[`caretPositionFromPoint(``x``, ``y``, ``options``)`]
method must return the result of running these steps:

1. If there is no
 [viewport](https://drafts.csswg.org/css2/#viewport%E2%91%A0) associated with the document, return null.

2. If either argument is negative, `x` is greater than the
 [viewport](https://drafts.csswg.org/css2/#viewport%E2%91%A0) width excluding the size of a rendered scroll bar
 (if any), `y` is greater than the
 [viewport] height excluding the size
 of a rendered scroll bar (if any) return null.

3. If at the coordinates `x`,`y` in the
 [viewport](https://drafts.csswg.org/css2/#viewport%E2%91%A0) no text insertion point indicator would have been
 inserted when applying the
 [transforms](#transforms) that
 apply to the descendants of the
 [viewport], return null.

4. If at the coordinates `x`,`y` in the
 [viewport](https://drafts.csswg.org/css2/#viewport%E2%91%A0) a text insertion point indicator would have been
 inserted in a text entry widget which is also a replaced element,
 when applying the [transforms](#transforms) that apply to the descendants of the
 [viewport], return a [caret
 position](#caret-position)
 with its properties set as follows:

 [caret node](#caret-node)
 : The node corresponding to the text entry widget.

 [caret offset](#caret-offset)
 : The amount of 16-bit units to the left of where the text
 insertion point indicator would have inserted.

5. Otherwise:

 1. Let `caretPosition` be a
 [tuple](https://infra.spec.whatwg.org/#tuple) consisting of a `caretPositionNode`
 (a
 [node](https://dom.spec.whatwg.org/#concept-node)) and a `caretPositionOffset` (a
 non-negative integer) for the position where the text insertion
 point indicator would have been inserted when applying the
 [transforms](#transforms)
 that apply to the descendants of the
 [viewport](https://drafts.csswg.org/css2/#viewport%E2%91%A0).

 2. Let `startNode` be the `caretPositionNode`
 of the `caretPosition`, and let
 `startOffset` be the `caretPositionOffset`
 of the `caretPosition`.

 3. While `startNode` is a
 [node](https://dom.spec.whatwg.org/#boundary-point-node), `startNode`'s
 [root](https://dom.spec.whatwg.org/#concept-tree-root) is a [shadow root], and
 `startNode`'s [root] is
 not a [shadow-including inclusive
 ancestor](https://dom.spec.whatwg.org/#concept-shadow-including-inclusive-ancestor) of any of
 `options`\[\"[`shadowRoots`](#dom-caretpositionfrompointoptions-shadowroots)\"\], repeat these steps:

 1. Set `startOffset` to
 [index](https://dom.spec.whatwg.org/#concept-tree-index) of `startNode`'s
 [root](https://dom.spec.whatwg.org/#concept-tree-root)'s
 [host](https://dom.spec.whatwg.org/#concept-documentfragment-host).

 2. Set `startNode` to `startNode`'s
 [root](https://dom.spec.whatwg.org/#concept-tree-root)'s
 [host](https://dom.spec.whatwg.org/#concept-documentfragment-host)'s
 [parent](https://dom.spec.whatwg.org/#concept-tree-parent).

 4. Return a [caret
 position](#caret-position) with its properties set as follows:

 1. [caret node](#caret-node) is set to `startNode`.

 2. [caret offset](#caret-offset) is set to `startOffset`.

 This [caret
position](#caret-position) is
not
[live](https://html.spec.whatwg.org/multipage/infrastructure.html#live).

 The specifics of hit testing are out of scope of this
specification and therefore the exact details of
[`elementFromPoint()`](#dom-document-elementfrompoint) and
[`caretPositionFromPoint()`](#dom-document-caretpositionfrompoint) are therefore too. Hit testing will hopefully be
defined in a future revision of CSS or HTML.

The [`scrollingElement`] attribute, on getting, must run these
steps:

1. If the
 [`Document`](https://dom.spec.whatwg.org/#document) is in [quirks
 mode](https://dom.spec.whatwg.org/#concept-document-quirks), follow these substeps:

 1. If [the `body`
 element](https://html.spec.whatwg.org/multipage/dom.html#the-body-element-2) exists, and it is not [potentially
 scrollable](#potentially-scrollable) in either axis, return [the `body`
 element] and abort these steps.

 For this purpose, a value of [overflow:clip] on the [the
 `body`
 element](https://html.spec.whatwg.org/multipage/dom.html#the-body-element-2)'s parent element must be treated as
 [overflow:hidden].

 2. Return null and abort these steps.

2. If there is a [root
 element](https://drafts.csswg.org/css-display-4/#root-element), return the [root element]
 and abort these steps.

3. Return null.

 For non-conforming user agents that always use the
[quirks
mode](https://dom.spec.whatwg.org/#concept-document-quirks) behavior for
[`scrollTop`](#dom-element-scrolltop) and
[`scrollLeft`](#dom-element-scrollleft), the
[`scrollingElement`](#dom-document-scrollingelement) attribute is expected to also always return [the `body`
element](https://html.spec.whatwg.org/multipage/dom.html#the-body-element-2) (or null if it does not exist). This API exists so that
Web developers can use it to get the right element to use for scrolling
APIs, without making assumptions about a particular user agent's
behavior or having to invoke a scroll to see which element scrolls the
viewport.

 [the `body`
element](https://html.spec.whatwg.org/multipage/dom.html#the-body-element-2) is different from HTML's `document.body` in that the
latter can return a `frameset` element.

Tests

- [scroll-overflow-clip-quirks-001.html](https://wpt.fyi/results/css/cssom-view/scroll-overflow-clip-quirks-001.html "css/cssom-view/scroll-overflow-clip-quirks-001.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/scroll-overflow-clip-quirks-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/scroll-overflow-clip-quirks-001.html)
- [scroll-overflow-clip-quirks-002.html](https://wpt.fyi/results/css/cssom-view/scroll-overflow-clip-quirks-002.html "css/cssom-view/scroll-overflow-clip-quirks-002.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/scroll-overflow-clip-quirks-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/scroll-overflow-clip-quirks-002.html)
- [scrollingElement-quirks-dynamic-001.html](https://wpt.fyi/results/css/cssom-view/scrollingElement-quirks-dynamic-001.html "css/cssom-view/scrollingElement-quirks-dynamic-001.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/scrollingElement-quirks-dynamic-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/scrollingElement-quirks-dynamic-001.html)
- [scrollingElement-quirks-dynamic-002.html](https://wpt.fyi/results/css/cssom-view/scrollingElement-quirks-dynamic-002.html "css/cssom-view/scrollingElement-quirks-dynamic-002.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/scrollingElement-quirks-dynamic-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/scrollingElement-quirks-dynamic-002.html)
- [scrollingElement.html](https://wpt.fyi/results/css/cssom-view/scrollingElement.html "css/cssom-view/scrollingElement.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/scrollingElement.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/scrollingElement.html)

### 5.1. The [`CaretPosition` Interface]
A [caret position] gives the position of a text insertion point indicator. It
always has an associated [caret node] and [caret offset]. It is represented by a
[`CaretPosition`](#caretposition) object.

```
[Exposed=Window]
interface CaretPosition {
 readonly attribute Node offsetNode;
 readonly attribute unsigned long offset;
 [NewObject] DOMRect? getClientRect();
};
```

The [`offsetNode`]
attribute must return the [caret node](#caret-node).

The [`offset`] attribute must
return the [caret offset](#caret-offset).

The [`getClientRect()`] method must follow these steps, aborting on the first step
that returns a value:

1. If [caret node](#caret-node)
 is a text entry widget that is a replaced element, and that is in
 the document, return a
 [scaled](https://drafts.csswg.org/css-viewport/#scaled)
 [`DOMRect`](https://drafts.csswg.org/geometry-1/#domrect) object for the caret in the widget as represented
 by the [caret offset](#caret-offset) value. The
 [transforms](#transforms) that
 apply to the element and its ancestors are applied.

2. Otherwise:

 1. Let `caretRange` be a collapsed
 [`Range`](https://dom.spec.whatwg.org/#range) object whose [start
 node](https://dom.spec.whatwg.org/#concept-range-start-node) and [end
 node](https://dom.spec.whatwg.org/#concept-range-end-node) are set to [caret
 node](#caret-node), and
 whose [start
 offset](https://dom.spec.whatwg.org/#concept-range-start-offset) and [end
 offset](https://dom.spec.whatwg.org/#concept-range-end-offset) are set to [caret
 offset](#caret-offset).

 2. Return the
 [`DOMRect`](https://drafts.csswg.org/geometry-1/#domrect) object which is the result of invoking the
 [`getBoundingClientRect()`](#dom-range-getboundingclientrect) method on `caretRange`.

 This
[`DOMRect`](https://drafts.csswg.org/geometry-1/#domrect) object is not
[live](https://html.spec.whatwg.org/multipage/infrastructure.html#live).

Tests

- [CaretPosition-001.html](https://wpt.fyi/results/css/cssom-view/CaretPosition-001.html "css/cssom-view/CaretPosition-001.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/CaretPosition-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/CaretPosition-001.html)

## [6. ][ Extensions to the [`Element`](https://dom.spec.whatwg.org/#element) Interface]
```
enum ScrollLogicalPosition { "start", "center", "end", "nearest" };
dictionary ScrollIntoViewOptions : ScrollOptions {
 ScrollLogicalPosition block = "start";
 ScrollLogicalPosition inline = "nearest";
 ScrollIntoViewContainer container = "all";
};

enum ScrollIntoViewContainer { "all", "nearest" };

dictionary CheckVisibilityOptions {
 boolean checkOpacity = false;
 boolean checkVisibilityCSS = false;
 boolean contentVisibilityAuto = false;
 boolean opacityProperty = false;
 boolean visibilityProperty = false;
};

partial interface Element {
 DOMRectList getClientRects();
 [NewObject] DOMRect getBoundingClientRect();

 boolean checkVisibility(optional CheckVisibilityOptions options = );

 Promise<undefined> scrollIntoView(optional (boolean or ScrollIntoViewOptions) arg = );
 Promise<undefined> scroll(optional ScrollToOptions options = );
 Promise<undefined> scroll(unrestricted double x, unrestricted double y);
 Promise<undefined> scrollTo(optional ScrollToOptions options = );
 Promise<undefined> scrollTo(unrestricted double x, unrestricted double y);
 Promise<undefined> scrollBy(optional ScrollToOptions options = );
 Promise<undefined> scrollBy(unrestricted double x, unrestricted double y);
 attribute unrestricted double scrollTop;
 attribute unrestricted double scrollLeft;
 readonly attribute long scrollWidth;
 readonly attribute long scrollHeight;
 readonly attribute long clientTop;
 readonly attribute long clientLeft;
 readonly attribute long clientWidth;
 readonly attribute long clientHeight;
 readonly attribute double currentCSSZoom;
};
```

(#issue-6482f18b①) Should the scroll methods above return
a result object and if so what information should they provide? #12495

 The
[`checkOpacity`](#dom-checkvisibilityoptions-checkopacity) and
[`checkVisibilityCSS`](#dom-checkvisibilityoptions-checkvisibilitycss) properties are historical names. These properties have
aliases that match the new naming scheme, namely
[`opacityProperty`](#dom-checkvisibilityoptions-opacityproperty) and
[`visibilityProperty`](#dom-checkvisibilityoptions-visibilityproperty).

The [`getClientRects()`] method, when
invoked, must return the result of the following algorithm:

1. If the element on which it was invoked does not have an associated
 [box](https://drafts.csswg.org/css-display-4/#box) return an empty
 [`DOMRectList`](https://drafts.csswg.org/geometry-1/#domrectlist) object and stop this algorithm.

2. If the element has an associated [SVG layout
 box](#svg-layout-box)
 return a
 [scaled](https://drafts.csswg.org/css-viewport/#scaled)
 [`DOMRectList`](https://drafts.csswg.org/geometry-1/#domrectlist) object containing a single
 [`DOMRect`](https://drafts.csswg.org/geometry-1/#domrect) object that describes the bounding box of the
 element as defined by the SVG specification, applying the
 [transforms](#transforms) that
 apply to the element and its ancestors.

3. Return a
 [`DOMRectList`](https://drafts.csswg.org/geometry-1/#domrectlist) object containing
 [`DOMRect`](https://drafts.csswg.org/geometry-1/#domrect) objects in content order, one for each [box
 fragment](https://drafts.csswg.org/css-break-4/#box-fragment), describing its border area (including those with a
 height or width of zero) with the following constraints:

 - Apply the [transforms](#transforms) that apply to the element and its ancestors.

 - If the element on which the method was invoked has a computed
 value for the
 [display](https://drafts.csswg.org/css-display-4/#propdef-display) property of
 [table](https://drafts.csswg.org/css-display-4/#valdef-display-table) or
 [inline-table](https://drafts.csswg.org/css-display-4/#valdef-display-inline-table) include both the table box and the caption
 box, if any, but not the anonymous container box.

 - Replace each
 [anonymous](https://drafts.csswg.org/css-display-4/#anonymous) [block
 box](https://drafts.csswg.org/css-display-4/#block-box) with its child box(es) and repeat this until no
 anonymous block boxes are left in the final list.

 The
[`DOMRect`](https://drafts.csswg.org/geometry-1/#domrect) objects returned by
[`getClientRects()`](#dom-element-getclientrects) are not
[live](https://html.spec.whatwg.org/multipage/infrastructure.html#live).

Tests

- [cssom-getClientRects-002.html](https://wpt.fyi/results/css/cssom-view/cssom-getClientRects-002.html "css/cssom-view/cssom-getClientRects-002.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/cssom-getClientRects-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/cssom-getClientRects-002.html)
- [cssom-getClientRects.html](https://wpt.fyi/results/css/cssom-view/cssom-getClientRects.html "css/cssom-view/cssom-getClientRects.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/cssom-getClientRects.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/cssom-getClientRects.html)
- [DOMRectList.html](https://wpt.fyi/results/css/cssom-view/DOMRectList.html "css/cssom-view/DOMRectList.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/DOMRectList.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/DOMRectList.html)
- [getClientRects-br-htb-ltr.html](https://wpt.fyi/results/css/cssom-view/getClientRects-br-htb-ltr.html "css/cssom-view/getClientRects-br-htb-ltr.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/getClientRects-br-htb-ltr.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/getClientRects-br-htb-ltr.html)
- [getClientRects-br-htb-rtl.html](https://wpt.fyi/results/css/cssom-view/getClientRects-br-htb-rtl.html "css/cssom-view/getClientRects-br-htb-rtl.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/getClientRects-br-htb-rtl.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/getClientRects-br-htb-rtl.html)
- [getClientRects-br-vlr-ltr.html](https://wpt.fyi/results/css/cssom-view/getClientRects-br-vlr-ltr.html "css/cssom-view/getClientRects-br-vlr-ltr.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/getClientRects-br-vlr-ltr.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/getClientRects-br-vlr-ltr.html)
- [getClientRects-br-vlr-rtl.html](https://wpt.fyi/results/css/cssom-view/getClientRects-br-vlr-rtl.html "css/cssom-view/getClientRects-br-vlr-rtl.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/getClientRects-br-vlr-rtl.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/getClientRects-br-vlr-rtl.html)
- [getClientRects-br-vrl-ltr.html](https://wpt.fyi/results/css/cssom-view/getClientRects-br-vrl-ltr.html "css/cssom-view/getClientRects-br-vrl-ltr.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/getClientRects-br-vrl-ltr.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/getClientRects-br-vrl-ltr.html)
- [getClientRects-br-vrl-rtl.html](https://wpt.fyi/results/css/cssom-view/getClientRects-br-vrl-rtl.html "css/cssom-view/getClientRects-br-vrl-rtl.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/getClientRects-br-vrl-rtl.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/getClientRects-br-vrl-rtl.html)
- [getClientRects-inline-atomic-child.html](https://wpt.fyi/results/css/cssom-view/getClientRects-inline-atomic-child.html "css/cssom-view/getClientRects-inline-atomic-child.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/getClientRects-inline-atomic-child.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/getClientRects-inline-atomic-child.html)
- [getClientRects-inline-inline-child.html](https://wpt.fyi/results/css/cssom-view/getClientRects-inline-inline-child.html "css/cssom-view/getClientRects-inline-inline-child.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/getClientRects-inline-inline-child.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/getClientRects-inline-inline-child.html)
- [getClientRects-inline-with-block-child.html](https://wpt.fyi/results/css/cssom-view/getClientRects-inline-with-block-child.html "css/cssom-view/getClientRects-inline-with-block-child.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/getClientRects-inline-with-block-child.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/getClientRects-inline-with-block-child.html)
- [getClientRects-inline.html](https://wpt.fyi/results/css/cssom-view/getClientRects-inline.html "css/cssom-view/getClientRects-inline.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/getClientRects-inline.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/getClientRects-inline.html)
- [getClientRects-zoom.html](https://wpt.fyi/results/css/cssom-view/getClientRects-zoom.html "css/cssom-view/getClientRects-zoom.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/getClientRects-zoom.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/getClientRects-zoom.html)
- [historical.html](https://wpt.fyi/results/css/cssom-view/historical.html "css/cssom-view/historical.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/historical.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/historical.html)
- [ttwf-js-cssomview-getclientrects-length.html](https://wpt.fyi/results/css/cssom-view/ttwf-js-cssomview-getclientrects-length.html "css/cssom-view/ttwf-js-cssomview-getclientrects-length.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/ttwf-js-cssomview-getclientrects-length.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/ttwf-js-cssomview-getclientrects-length.html)

The [`getBoundingClientRect()`] method, when invoked on an element
`element`, must return the result of [getting the bounding
box](#element-get-the-bounding-box) for `element`.

To [get the bounding box] for
`element`, run the following steps:

1. Let `list` be the result of invoking
 [`getClientRects()`](#dom-element-getclientrects) on `element`.

2. If the `list` is empty return a
 [`DOMRect`](https://drafts.csswg.org/geometry-1/#domrect) object whose
 [`x`](https://drafts.csswg.org/geometry-1/#dom-domrect-x),
 [`y`](https://drafts.csswg.org/geometry-1/#dom-domrect-y),
 [`width`](https://drafts.csswg.org/geometry-1/#dom-domrect-width) and
 [`height`](https://drafts.csswg.org/geometry-1/#dom-domrect-height) members are zero.

3. If all rectangles in `list` have zero width or height,
 return the first rectangle in `list`.

4. Otherwise, return a
 [`DOMRect`](https://drafts.csswg.org/geometry-1/#domrect) object describing the smallest rectangle that
 includes all of the rectangles in `list` of which the
 height or width is not zero.

[`DOMRect`](https://drafts.csswg.org/geometry-1/#domrect) object returned by
[`getBoundingClientRect()`](#dom-element-getboundingclientrect) is not
[live](https://html.spec.whatwg.org/multipage/infrastructure.html#live).

The following snippet gets the
dimensions of the first `div` element in a document:

``` highlight
var example = document.getElementsByTagName("div")[0].getBoundingClientRect();
var exampleWidth = example.width;
var exampleHeight = example.height;
```

- [cssom-getBoundingClientRect-001.html](https://wpt.fyi/results/css/cssom-view/cssom-getBoundingClientRect-001.html "css/cssom-view/cssom-getBoundingClientRect-001.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/cssom-getBoundingClientRect-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/cssom-getBoundingClientRect-001.html)
- [cssom-getBoundingClientRect-002.html](https://wpt.fyi/results/css/cssom-view/cssom-getBoundingClientRect-002.html "css/cssom-view/cssom-getBoundingClientRect-002.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/cssom-getBoundingClientRect-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/cssom-getBoundingClientRect-002.html)
- [cssom-getBoundingClientRect-003.html](https://wpt.fyi/results/css/cssom-view/cssom-getBoundingClientRect-003.html "css/cssom-view/cssom-getBoundingClientRect-003.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/cssom-getBoundingClientRect-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/cssom-getBoundingClientRect-003.html)
- [cssom-getBoundingClientRect-vertical-rl.html](https://wpt.fyi/results/css/cssom-view/cssom-getBoundingClientRect-vertical-rl.html "css/cssom-view/cssom-getBoundingClientRect-vertical-rl.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/cssom-getBoundingClientRect-vertical-rl.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/cssom-getBoundingClientRect-vertical-rl.html)
- [getBoundingClientRect-content-visibility-hidden.html](https://wpt.fyi/results/css/cssom-view/getBoundingClientRect-content-visibility-hidden.html "css/cssom-view/getBoundingClientRect-content-visibility-hidden.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/getBoundingClientRect-content-visibility-hidden.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/getBoundingClientRect-content-visibility-hidden.html)
- [getBoundingClientRect-empty-inline-002.html](https://wpt.fyi/results/css/cssom-view/getBoundingClientRect-empty-inline-002.html "css/cssom-view/getBoundingClientRect-empty-inline-002.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/getBoundingClientRect-empty-inline-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/getBoundingClientRect-empty-inline-002.html)
- [getBoundingClientRect-empty-inline.html](https://wpt.fyi/results/css/cssom-view/getBoundingClientRect-empty-inline.html "css/cssom-view/getBoundingClientRect-empty-inline.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/getBoundingClientRect-empty-inline.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/getBoundingClientRect-empty-inline.html)
- [getBoundingClientRect-newline.html](https://wpt.fyi/results/css/cssom-view/getBoundingClientRect-newline.html "css/cssom-view/getBoundingClientRect-newline.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/getBoundingClientRect-newline.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/getBoundingClientRect-newline.html)
- [getBoundingClientRect-scroll.html](https://wpt.fyi/results/css/cssom-view/getBoundingClientRect-scroll.html "css/cssom-view/getBoundingClientRect-scroll.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/getBoundingClientRect-scroll.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/getBoundingClientRect-scroll.html)
- [getBoundingClientRect-shy.html](https://wpt.fyi/results/css/cssom-view/getBoundingClientRect-shy.html "css/cssom-view/getBoundingClientRect-shy.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/getBoundingClientRect-shy.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/getBoundingClientRect-shy.html)
- [getBoundingClientRect-svg.html](https://wpt.fyi/results/css/cssom-view/getBoundingClientRect-svg.html "css/cssom-view/getBoundingClientRect-svg.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/getBoundingClientRect-svg.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/getBoundingClientRect-svg.html)
- [getBoundingClientRect-zoom.html](https://wpt.fyi/results/css/cssom-view/getBoundingClientRect-zoom.html "css/cssom-view/getBoundingClientRect-zoom.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/getBoundingClientRect-zoom.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/getBoundingClientRect-zoom.html)
- [GetBoundingRect.html](https://wpt.fyi/results/css/cssom-view/GetBoundingRect.html "css/cssom-view/GetBoundingRect.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/GetBoundingRect.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/GetBoundingRect.html)

Note: The
[`checkVisibility()`](#dom-element-checkvisibility) method provides a set of simple checks for whether an
element is potentially \"visible\". It defaults to a very simple and
straightforward method based on the [box
tree](https://drafts.csswg.org/css-display-4/#box-tree), but allows for several additional checks to be opted
into, depending on what precise notion of \"visibility\" is desired.

The
[`checkVisibility(``options``)`] method must
run these steps, when called on an element `this`:

1. If `this` does not have an associated
 [box](https://drafts.csswg.org/css-display-4/#box), return false.

2. If an ancestor of `this` in the [flat
 tree](https://drafts.csswg.org/css-shadow-1/#flat-tree) has [content-visibility:
 hidden](https://drafts.csswg.org/css-contain-2/#propdef-content-visibility), return false.

3. If either the
 [`opacityProperty`](#dom-checkvisibilityoptions-opacityproperty) or the
 [`checkOpacity`](#dom-checkvisibilityoptions-checkopacity) dictionary members of `options` are
 true, and `this`, or an ancestor of `this` in
 the [flat
 tree](https://drafts.csswg.org/css-shadow-1/#flat-tree), has a computed
 [opacity](https://drafts.csswg.org/css-color-4/#propdef-opacity) value of [0], return
 false.

4. If either the
 [`visibilityProperty`](#dom-checkvisibilityoptions-visibilityproperty) or the
 [`checkVisibilityCSS`](#dom-checkvisibilityoptions-checkvisibilitycss) dictionary members of `options` are
 true, and `this` is [invisible], return
 false.

5. If the
 [`contentVisibilityAuto`](#dom-checkvisibilityoptions-contentvisibilityauto) dictionary member of `options` is true
 and an ancestor of `this` in the [flat
 tree](https://drafts.csswg.org/css-shadow-1/#flat-tree) [skips its
 contents](https://drafts.csswg.org/css-contain-2/#skips-its-contents) due to [content-visibility:
 auto](https://drafts.csswg.org/css-contain-2/#propdef-content-visibility), return false.

6. Return true.

- [checkVisibility.html](https://wpt.fyi/results/css/cssom-view/checkVisibility.html "css/cssom-view/checkVisibility.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/checkVisibility.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/checkVisibility.html)

The [`scrollIntoView(``arg``)`]
method must run these steps:

1. Let `behavior` be \"`auto`\".

2. Let `block` be \"`start`\".

3. Let `inline` be \"`nearest`\".

4. Let `container` be `null`.

5. If `arg` is a
 [`ScrollIntoViewOptions`](#dictdef-scrollintoviewoptions) dictionary, then:

 1. Set `behavior` to the
 [`behavior`](#dom-scrolloptions-behavior) dictionary member of `options`.

 2. Set `block` to the
 [`block`](#dom-scrollintoviewoptions-block) dictionary member of `options`.

 3. Set `inline` to the
 [`inline`](#dom-scrollintoviewoptions-inline) dictionary member of `options`.

 4. If the
 [`container`](#dom-scrollintoviewoptions-container) dictionary member of `options` is
 \"`nearest`\", set `container` to the element.

6. Otherwise, if `arg` is false, then set `block`
 to \"`end`\".

7. If the element does not have any associated
 [box](https://drafts.csswg.org/css-display-4/#box), or is not available to user-agent features, then
 return a resolved
 [`Promise`](https://webidl.spec.whatwg.org/#idl-promise) and abort the remaining steps.

8. [Scroll the element into
 view](#scroll-a-target-into-view) with `behavior`, `block`,
 `inline`, and `container`. Let
 `scrollPromise` be the
 [`Promise`](https://webidl.spec.whatwg.org/#idl-promise) returned from this step

9. Optionally perform some other action that brings the element to the
 user's attention.

10. Return `scrollPromise`.

A component can use scrollIntoView to
scroll content of interest into the specified alignment:

``` highlight
<style>
 .scroller { overflow: auto; scroll-padding: 8px; }
 .slide { scroll-margin: 16px; scroll-snap-align: center; }
</style>
<div class="carousel">
 <div class="slides scroller">
 <div id="s1" class="slide">
 <div id="s2" class="slide">
 <div id="s3" class="slide">
 </div>
 <div class="markers">
 <button >1</button>
 <button >2</button>
 <button >3</button>
 </div>
</div>
<script>
 document.querySelector('.markers').addEventListener('click', (evt) => {
 const target = document.getElementById(evt.target.dataset.target);
 if (!target) return;
 // scrollIntoView correctly aligns target item respecting scroll-snap-align,
 // scroll-margin, and the scroll container's scroll-padding.
 target.scrollIntoView({
 // Only scroll the nearest scroll container.
 container: 'nearest',
 behavior: 'smooth'
 });
 });
</script>
```

- [scrollIntoView-align-scrollport-covering-child.html](https://wpt.fyi/results/css/cssom-view/scrollIntoView-align-scrollport-covering-child.html "css/cssom-view/scrollIntoView-align-scrollport-covering-child.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/scrollIntoView-align-scrollport-covering-child.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/scrollIntoView-align-scrollport-covering-child.html)
- [scrollIntoView-container.html](https://wpt.fyi/results/css/cssom-view/scrollIntoView-container.html "css/cssom-view/scrollIntoView-container.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/scrollIntoView-container.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/scrollIntoView-container.html)
- [scrollintoview-containingblock-chain.html](https://wpt.fyi/results/css/cssom-view/scrollintoview-containingblock-chain.html "css/cssom-view/scrollintoview-containingblock-chain.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/scrollintoview-containingblock-chain.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/scrollintoview-containingblock-chain.html)
- [scrollIntoView-fixed-outside-of-viewport.html](https://wpt.fyi/results/css/cssom-view/scrollIntoView-fixed-outside-of-viewport.html "css/cssom-view/scrollIntoView-fixed-outside-of-viewport.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/scrollIntoView-fixed-outside-of-viewport.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/scrollIntoView-fixed-outside-of-viewport.html)
- [scrollIntoView-fixed.html](https://wpt.fyi/results/css/cssom-view/scrollIntoView-fixed.html "css/cssom-view/scrollIntoView-fixed.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/scrollIntoView-fixed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/scrollIntoView-fixed.html)
- [scrollIntoView-horizontal-partially-visible.html](https://wpt.fyi/results/css/cssom-view/scrollIntoView-horizontal-partially-visible.html "css/cssom-view/scrollIntoView-horizontal-partially-visible.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/scrollIntoView-horizontal-partially-visible.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/scrollIntoView-horizontal-partially-visible.html)
- [scrollIntoView-horizontal-tb-writing-mode-and-rtl-direction.html](https://wpt.fyi/results/css/cssom-view/scrollIntoView-horizontal-tb-writing-mode-and-rtl-direction.html "css/cssom-view/scrollIntoView-horizontal-tb-writing-mode-and-rtl-direction.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/scrollIntoView-horizontal-tb-writing-mode-and-rtl-direction.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/scrollIntoView-horizontal-tb-writing-mode-and-rtl-direction.html)
- [scrollIntoView-horizontal-tb-writing-mode.html](https://wpt.fyi/results/css/cssom-view/scrollIntoView-horizontal-tb-writing-mode.html "css/cssom-view/scrollIntoView-horizontal-tb-writing-mode.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/scrollIntoView-horizontal-tb-writing-mode.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/scrollIntoView-horizontal-tb-writing-mode.html)
- [scrollIntoView-iframes.html](https://wpt.fyi/results/css/cssom-view/scrollIntoView-iframes.html "css/cssom-view/scrollIntoView-iframes.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/scrollIntoView-iframes.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/scrollIntoView-iframes.html)
- [scrollIntoView-inline-image.html](https://wpt.fyi/results/css/cssom-view/scrollIntoView-inline-image.html "css/cssom-view/scrollIntoView-inline-image.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/scrollIntoView-inline-image.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/scrollIntoView-inline-image.html)
- [scrollIntoView-multiple-nested.html](https://wpt.fyi/results/css/cssom-view/scrollIntoView-multiple-nested.html "css/cssom-view/scrollIntoView-multiple-nested.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/scrollIntoView-multiple-nested.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/scrollIntoView-multiple-nested.html)
- [scrollIntoView-multiple.html](https://wpt.fyi/results/css/cssom-view/scrollIntoView-multiple.html "css/cssom-view/scrollIntoView-multiple.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/scrollIntoView-multiple.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/scrollIntoView-multiple.html)
- [scrollIntoView-nearest-visible-element.html](https://wpt.fyi/results/css/cssom-view/scrollIntoView-nearest-visible-element.html "css/cssom-view/scrollIntoView-nearest-visible-element.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/scrollIntoView-nearest-visible-element.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/scrollIntoView-nearest-visible-element.html)
- [scrollIntoView-root-overflow-clip.html](https://wpt.fyi/results/css/cssom-view/scrollIntoView-root-overflow-clip.html "css/cssom-view/scrollIntoView-root-overflow-clip.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/scrollIntoView-root-overflow-clip.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/scrollIntoView-root-overflow-clip.html)
- [scrollIntoView-scrolling-container.html](https://wpt.fyi/results/css/cssom-view/scrollIntoView-scrolling-container.html "css/cssom-view/scrollIntoView-scrolling-container.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/scrollIntoView-scrolling-container.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/scrollIntoView-scrolling-container.html)
- [scrollIntoView-scrolling-box-with-large-border.html](https://wpt.fyi/results/css/cssom-view/scrollIntoView-scrolling-box-with-large-border.html "css/cssom-view/scrollIntoView-scrolling-box-with-large-border.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/scrollIntoView-scrolling-box-with-large-border.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/scrollIntoView-scrolling-box-with-large-border.html)
- [scrollIntoView-scrollMargin.html](https://wpt.fyi/results/css/cssom-view/scrollIntoView-scrollMargin.html "css/cssom-view/scrollIntoView-scrollMargin.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/scrollIntoView-scrollMargin.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/scrollIntoView-scrollMargin.html)
- [scrollIntoView-scrollPadding.html](https://wpt.fyi/results/css/cssom-view/scrollIntoView-scrollPadding.html "css/cssom-view/scrollIntoView-scrollPadding.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/scrollIntoView-scrollPadding.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/scrollIntoView-scrollPadding.html)
- [scrollIntoView-shadow.html](https://wpt.fyi/results/css/cssom-view/scrollIntoView-shadow.html "css/cssom-view/scrollIntoView-shadow.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/scrollIntoView-shadow.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/scrollIntoView-shadow.html)
- [scrollIntoView-should-treat-slot-as-scroll-container.html](https://wpt.fyi/results/css/cssom-view/scrollIntoView-should-treat-slot-as-scroll-container.html "css/cssom-view/scrollIntoView-should-treat-slot-as-scroll-container.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/scrollIntoView-should-treat-slot-as-scroll-container.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/scrollIntoView-should-treat-slot-as-scroll-container.html)
- [scrollIntoView-sideways-lr-writing-mode-and-rtl-direction.html](https://wpt.fyi/results/css/cssom-view/scrollIntoView-sideways-lr-writing-mode-and-rtl-direction.html "css/cssom-view/scrollIntoView-sideways-lr-writing-mode-and-rtl-direction.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/scrollIntoView-sideways-lr-writing-mode-and-rtl-direction.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/scrollIntoView-sideways-lr-writing-mode-and-rtl-direction.html)
- [scrollIntoView-sideways-lr-writing-mode.html](https://wpt.fyi/results/css/cssom-view/scrollIntoView-sideways-lr-writing-mode.html "css/cssom-view/scrollIntoView-sideways-lr-writing-mode.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/scrollIntoView-sideways-lr-writing-mode.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/scrollIntoView-sideways-lr-writing-mode.html)
- [scrollIntoView-sideways-rl-writing-mode-and-rtl-direction.html](https://wpt.fyi/results/css/cssom-view/scrollIntoView-sideways-rl-writing-mode-and-rtl-direction.html "css/cssom-view/scrollIntoView-sideways-rl-writing-mode-and-rtl-direction.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/scrollIntoView-sideways-rl-writing-mode-and-rtl-direction.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/scrollIntoView-sideways-rl-writing-mode-and-rtl-direction.html)
- [scrollIntoView-sideways-rl-writing-mode.html](https://wpt.fyi/results/css/cssom-view/scrollIntoView-sideways-rl-writing-mode.html "css/cssom-view/scrollIntoView-sideways-rl-writing-mode.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/scrollIntoView-sideways-rl-writing-mode.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/scrollIntoView-sideways-rl-writing-mode.html)
- [scrollIntoView-smooth.html](https://wpt.fyi/results/css/cssom-view/scrollIntoView-smooth.html "css/cssom-view/scrollIntoView-smooth.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/scrollIntoView-smooth.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/scrollIntoView-smooth.html)
- [scrollIntoView-stuck.tentative.html](https://wpt.fyi/results/css/cssom-view/scrollIntoView-stuck.tentative.html "css/cssom-view/scrollIntoView-stuck.tentative.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/scrollIntoView-stuck.tentative.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/scrollIntoView-stuck.tentative.html)
- [scrollIntoView-svg-shape.html](https://wpt.fyi/results/css/cssom-view/scrollIntoView-svg-shape.html "css/cssom-view/scrollIntoView-svg-shape.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/scrollIntoView-svg-shape.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/scrollIntoView-svg-shape.html)
- [scrollIntoView-vertical-lr-writing-mode-and-rtl-direction.html](https://wpt.fyi/results/css/cssom-view/scrollIntoView-vertical-lr-writing-mode-and-rtl-direction.html "css/cssom-view/scrollIntoView-vertical-lr-writing-mode-and-rtl-direction.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/scrollIntoView-vertical-lr-writing-mode-and-rtl-direction.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/scrollIntoView-vertical-lr-writing-mode-and-rtl-direction.html)
- [scrollIntoView-vertical-lr-writing-mode.html](https://wpt.fyi/results/css/cssom-view/scrollIntoView-vertical-lr-writing-mode.html "css/cssom-view/scrollIntoView-vertical-lr-writing-mode.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/scrollIntoView-vertical-lr-writing-mode.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/scrollIntoView-vertical-lr-writing-mode.html)
- [scrollIntoView-vertical-rl-writing-mode.html](https://wpt.fyi/results/css/cssom-view/scrollIntoView-vertical-rl-writing-mode.html "css/cssom-view/scrollIntoView-vertical-rl-writing-mode.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/scrollIntoView-vertical-rl-writing-mode.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/scrollIntoView-vertical-rl-writing-mode.html)
- [scrollintoview-zero-height-item.html](https://wpt.fyi/results/css/cssom-view/scrollintoview-zero-height-item.html "css/cssom-view/scrollintoview-zero-height-item.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/scrollintoview-zero-height-item.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/scrollintoview-zero-height-item.html)
- [scrollintoview.html](https://wpt.fyi/results/css/cssom-view/scrollintoview.html "css/cssom-view/scrollintoview.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/scrollintoview.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/scrollintoview.html)
- [smooth-scrollIntoView-with-smooth-fragment-scroll.html](https://wpt.fyi/results/css/cssom-view/smooth-scrollIntoView-with-smooth-fragment-scroll.html "css/cssom-view/smooth-scrollIntoView-with-smooth-fragment-scroll.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/smooth-scrollIntoView-with-smooth-fragment-scroll.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/smooth-scrollIntoView-with-smooth-fragment-scroll.html)
- [smooth-scrollIntoView-with-unrelated-gesture-scroll.html](https://wpt.fyi/results/css/cssom-view/smooth-scrollIntoView-with-unrelated-gesture-scroll.html "css/cssom-view/smooth-scrollIntoView-with-unrelated-gesture-scroll.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/smooth-scrollIntoView-with-unrelated-gesture-scroll.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/smooth-scrollIntoView-with-unrelated-gesture-scroll.html)
- [visual-scrollIntoView-001.html](https://wpt.fyi/results/css/cssom-view/visual-scrollIntoView-001.html "css/cssom-view/visual-scrollIntoView-001.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/visual-scrollIntoView-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/visual-scrollIntoView-001.html)
- [visual-scrollIntoView-002.html](https://wpt.fyi/results/css/cssom-view/visual-scrollIntoView-002.html "css/cssom-view/visual-scrollIntoView-002.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/visual-scrollIntoView-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/visual-scrollIntoView-002.html)
- [visual-scrollIntoView-003.html](https://wpt.fyi/results/css/cssom-view/visual-scrollIntoView-003.html "css/cssom-view/visual-scrollIntoView-003.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/visual-scrollIntoView-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/visual-scrollIntoView-003.html)

The [`scroll()`] method must run these steps:

1. If invoked with one argument, follow these substeps:

 1. Let `options` be the argument.

 2. [Normalize non-finite
 values](#normalize-non-finite-values) for
 [`left`](#dom-scrolltooptions-left) and
 [`top`](#dom-scrolltooptions-top) dictionary members of `options`, if
 present.

 3. Let `x` be the value of the
 [`left`](#dom-scrolltooptions-left) dictionary member of `options`, if
 present, or the element's current scroll position on the x axis
 otherwise.

 4. Let `y` be the value of the
 [`top`](#dom-scrolltooptions-top) dictionary member of `options`, if
 present, or the element's current scroll position on the y axis
 otherwise.

2. If invoked with two arguments, follow these substeps:

 1. Let `options` be null
 [converted](https://webidl.spec.whatwg.org/#dfn-convert-ecmascript-to-idl-value) to a
 [`ScrollToOptions`](#dictdef-scrolltooptions) dictionary.
 [\[WEBIDL\]](#biblio-webidl "Web IDL Standard")

 2. Let `x` and `y` be the arguments,
 respectively.

 3. [Normalize non-finite
 values](#normalize-non-finite-values) for `x` and `y`.

 4. Let the
 [`left`](#dom-scrolltooptions-left) dictionary member of `options` have
 the value `x`.

 5. Let the
 [`top`](#dom-scrolltooptions-top) dictionary member of `options` have
 the value `y`.

3. Let `document` be the element's [node
 document](https://dom.spec.whatwg.org/#concept-node-document).

4. If `document` is not the [active
 document](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-document), return a resolved
 [`Promise`](https://webidl.spec.whatwg.org/#idl-promise) and abort the remaining steps.

5. Let `window` be the value of `document`'s
 [`defaultView`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#dom-document-defaultview) attribute.

6. If `window` is null, return a resolved
 [`Promise`](https://webidl.spec.whatwg.org/#idl-promise) and abort the remaining steps.

7. If the element is the [root
 element](https://drafts.csswg.org/css-display-4/#root-element) and `document` is in [quirks
 mode](https://dom.spec.whatwg.org/#concept-document-quirks), return a resolved
 [`Promise`](https://webidl.spec.whatwg.org/#idl-promise) and abort the remaining steps.

8. If the element is the [root
 element](https://drafts.csswg.org/css-display-4/#root-element), return the
 [`Promise`](https://webidl.spec.whatwg.org/#idl-promise) returned by
 [`scroll()`](#dom-window-scroll) on `window` after the method is invoked
 with
 [`scrollX`](#dom-window-scrollx) on `window` as first argument and
 `y` as second argument, and abort the remaining steps.

9. If the element is [the `body`
 element](https://html.spec.whatwg.org/multipage/dom.html#the-body-element-2), `document` is in [quirks
 mode](https://dom.spec.whatwg.org/#concept-document-quirks), and the element is not [potentially
 scrollable](#potentially-scrollable) in either axis, return the
 [`Promise`](https://webidl.spec.whatwg.org/#idl-promise) returned by
 [`scroll()`](#dom-window-scroll) on `window` after the method is invoked
 with `options` as the only argument, and abort the
 remaining steps.

10. If the element does not have any associated
 [box](https://drafts.csswg.org/css-display-4/#box), the element has no associated [scrolling
 box](#scrolling-box), or
 the element has no overflow, return a resolved
 [`Promise`](https://webidl.spec.whatwg.org/#idl-promise) and abort the remaining steps.

11. [Scroll the element](#scroll-an-element) to `x`,`y`, with the scroll
 behavior being the value of the
 [`behavior`](#dom-scrolloptions-behavior) dictionary member of `options`. Let
 `scrollPromise` be the
 [`Promise`](https://webidl.spec.whatwg.org/#idl-promise) returned from this step.

12. Return `scrollPromise`.

Tests

- [element-scroll-arguments.html](https://wpt.fyi/results/css/cssom-view/element-scroll-arguments.html "css/cssom-view/element-scroll-arguments.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/element-scroll-arguments.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/element-scroll-arguments.html)
- [element-scroll-promise-interruption.html](https://wpt.fyi/results/css/cssom-view/element-scroll-promise-interruption.html "css/cssom-view/element-scroll-promise-interruption.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/element-scroll-promise-interruption.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/element-scroll-promise-interruption.html)
- [element-scroll-promises.html](https://wpt.fyi/results/css/cssom-view/element-scroll-promises.html "css/cssom-view/element-scroll-promises.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/element-scroll-promises.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/element-scroll-promises.html)

When the [`scrollTo()`] method is invoked, the
user agent must act as if the
[`scroll()`](#dom-element-scroll) method was invoked with the same arguments.

When the [`scrollBy()`] method is invoked, the
user agent must run these steps:

1. If invoked with one argument, follow these substeps:

 1. Let `options` be the argument.

 2. [Normalize non-finite
 values](#normalize-non-finite-values) for
 [`left`](#dom-scrolltooptions-left) and
 [`top`](#dom-scrolltooptions-top) dictionary members of `options`, if
 present.

2. If invoked with two arguments, follow these substeps:

 1. Let `options` be null
 [converted](https://webidl.spec.whatwg.org/#dfn-convert-ecmascript-to-idl-value) to a
 [`ScrollToOptions`](#dictdef-scrolltooptions) dictionary.
 [\[WEBIDL\]](#biblio-webidl "Web IDL Standard")

 2. Let `x` and `y` be the arguments,
 respectively.

 3. [Normalize non-finite
 values](#normalize-non-finite-values) for `x` and `y`.

 4. Let the
 [`left`](#dom-scrolltooptions-left) dictionary member of `options` have
 the value `x`.

 5. Let the
 [`top`](#dom-scrolltooptions-top) dictionary member of `options` have
 the value `y`.

3. Add the value of
 [`scrollLeft`](#dom-element-scrollleft) to the
 [`left`](#dom-scrolltooptions-left) dictionary member.

4. Add the value of
 [`scrollTop`](#dom-element-scrolltop) to the
 [`top`](#dom-scrolltooptions-top) dictionary member.

5. Return the
 [`Promise`](https://webidl.spec.whatwg.org/#idl-promise) returned by
 [`scroll()`](#dom-element-scroll) after the method is invoked with
 `options` as the only argument.

Tests

- [window-scrollBy-display-change.html](https://wpt.fyi/results/css/cssom-view/window-scrollBy-display-change.html "css/cssom-view/window-scrollBy-display-change.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/window-scrollBy-display-change.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/window-scrollBy-display-change.html)

The [`scrollTop`] attribute, on getting,
must return the result of running these steps:

1. Let `document` be the element's [node
 document](https://dom.spec.whatwg.org/#concept-node-document).

2. If `document` is not the [active
 document](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-document), return zero and terminate these steps.

3. Let `window` be the value of `document`'s
 [`defaultView`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#dom-document-defaultview) attribute.

4. If `window` is null, return zero and terminate these
 steps.

5. If the element is the [root
 element](https://drafts.csswg.org/css-display-4/#root-element) and `document` is in [quirks
 mode](https://dom.spec.whatwg.org/#concept-document-quirks), return zero and terminate these steps.

6. If the element is the [root
 element](https://drafts.csswg.org/css-display-4/#root-element) return the value of
 [`scrollY`](#dom-window-scrolly) on `window`.

7. If the element is [the `body`
 element](https://html.spec.whatwg.org/multipage/dom.html#the-body-element-2), `document` is in [quirks
 mode](https://dom.spec.whatwg.org/#concept-document-quirks), and the element is not [potentially
 scrollable](#potentially-scrollable) in at least one axis, return the value of
 [`scrollY`](#dom-window-scrolly) on `window`.

8. If the element does not have any associated
 [box](https://drafts.csswg.org/css-display-4/#box), return zero and terminate these steps.

9. Return the y-coordinate of the [scrolling
 area](#scrolling-area) at
 the alignment point with the top of the [padding
 edge](https://drafts.csswg.org/css-box-4/#padding-edge) of the element.

When setting the
[`scrollTop`](#dom-element-scrolltop) attribute these steps must be run:

1. Let `y` be the given value.

2. [Normalize non-finite
 values](#normalize-non-finite-values) for `y`.

3. Let `document` be the element's [node
 document](https://dom.spec.whatwg.org/#concept-node-document).

4. If `document` is not the [active
 document](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-document), terminate these steps.

5. Let `window` be the value of `document`'s
 [`defaultView`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#dom-document-defaultview) attribute.

6. If `window` is null, terminate these steps.

7. If the element is the [root
 element](https://drafts.csswg.org/css-display-4/#root-element) and `document` is in [quirks
 mode](https://dom.spec.whatwg.org/#concept-document-quirks), terminate these steps.

8. If the element is the [root
 element](https://drafts.csswg.org/css-display-4/#root-element) invoke
 [`scroll()`](#dom-window-scroll) on `window` with
 [`scrollX`](#dom-window-scrollx) on `window` as first argument and
 `y` as second argument, and terminate these steps.

9. If the element is [the `body`
 element](https://html.spec.whatwg.org/multipage/dom.html#the-body-element-2), `document` is in [quirks
 mode](https://dom.spec.whatwg.org/#concept-document-quirks), and the element is not [potentially
 scrollable](#potentially-scrollable) in at least one axis, invoke
 [`scroll()`](#dom-window-scroll) on `window` with
 [`scrollX`](#dom-window-scrollx) as first argument and `y` as second
 argument, and terminate these steps.

10. If the element does not have any associated
 [box](https://drafts.csswg.org/css-display-4/#box), the element has no associated [scrolling
 box](#scrolling-box), or
 the element has no overflow, terminate these steps.

11. [Scroll the element](#scroll-an-element) to
 [`scrollLeft`](#dom-element-scrollleft),`y`, with the scroll behavior being
 \"`auto`\".

Tests

- [dom-element-scroll.html](https://wpt.fyi/results/css/cssom-view/dom-element-scroll.html "css/cssom-view/dom-element-scroll.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/dom-element-scroll.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/dom-element-scroll.html)
- [elementScroll-002.html](https://wpt.fyi/results/css/cssom-view/elementScroll-002.html "css/cssom-view/elementScroll-002.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/elementScroll-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/elementScroll-002.html)
- [elementScroll.html](https://wpt.fyi/results/css/cssom-view/elementScroll.html "css/cssom-view/elementScroll.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/elementScroll.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/elementScroll.html)
- [scroll-no-layout-box.html](https://wpt.fyi/results/css/cssom-view/scroll-no-layout-box.html "css/cssom-view/scroll-no-layout-box.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/scroll-no-layout-box.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/scroll-no-layout-box.html)
- [scroll-offsets-fractional-zoom.html](https://wpt.fyi/results/css/cssom-view/scroll-offsets-fractional-zoom.html "css/cssom-view/scroll-offsets-fractional-zoom.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/scroll-offsets-fractional-zoom.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/scroll-offsets-fractional-zoom.html)
- [scroll-zoom.html](https://wpt.fyi/results/css/cssom-view/scroll-zoom.html "css/cssom-view/scroll-zoom.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/scroll-zoom.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/scroll-zoom.html)
- [scrollTop-display-change.html](https://wpt.fyi/results/css/cssom-view/scrollTop-display-change.html "css/cssom-view/scrollTop-display-change.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/scrollTop-display-change.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/scrollTop-display-change.html)
- [table-scroll-props.html](https://wpt.fyi/results/css/cssom-view/table-scroll-props.html "css/cssom-view/table-scroll-props.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/table-scroll-props.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/table-scroll-props.html)

The [`scrollLeft`] attribute, on getting,
must return the result of running these steps:

1. Let `document` be the element's [node
 document](https://dom.spec.whatwg.org/#concept-node-document).

2. If `document` is not the [active
 document](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-document), return zero and terminate these steps.

3. Let `window` be the value of `document`'s
 [`defaultView`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#dom-document-defaultview) attribute.

4. If `window` is null, return zero and terminate these
 steps.

5. If the element is the [root
 element](https://drafts.csswg.org/css-display-4/#root-element) and `document` is in [quirks
 mode](https://dom.spec.whatwg.org/#concept-document-quirks), return zero and terminate these steps.

6. If the element is the [root
 element](https://drafts.csswg.org/css-display-4/#root-element) return the value of
 [`scrollX`](#dom-window-scrollx) on `window`.

7. If the element is [the `body`
 element](https://html.spec.whatwg.org/multipage/dom.html#the-body-element-2), `document` is in [quirks
 mode](https://dom.spec.whatwg.org/#concept-document-quirks), and the element is not [potentially
 scrollable](#potentially-scrollable) in at least one axis, return the value of
 [`scrollX`](#dom-window-scrollx) on `window`.

8. If the element does not have any associated
 [box](https://drafts.csswg.org/css-display-4/#box), return zero and terminate these steps.

9. Return the x-coordinate of the [scrolling
 area](#scrolling-area) at
 the alignment point with the left of the [padding
 edge](https://drafts.csswg.org/css-box-4/#padding-edge) of the element.

When setting the
[`scrollLeft`](#dom-element-scrollleft) attribute these steps must be run:

1. Let `x` be the given value.

2. [Normalize non-finite
 values](#normalize-non-finite-values) for `x`.

3. Let `document` be the element's [node
 document](https://dom.spec.whatwg.org/#concept-node-document).

4. If `document` is not the [active
 document](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-document), terminate these steps.

5. Let `window` be the value of `document`'s
 [`defaultView`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#dom-document-defaultview) attribute.

6. If `window` is null, terminate these steps.

7. If the element is the [root
 element](https://drafts.csswg.org/css-display-4/#root-element) and `document` is in [quirks
 mode](https://dom.spec.whatwg.org/#concept-document-quirks), terminate these steps.

8. If the element is the [root
 element](https://drafts.csswg.org/css-display-4/#root-element) invoke
 [`scroll()`](#dom-window-scroll) on `window` with `x` as first
 argument and
 [`scrollY`](#dom-window-scrolly) on `window` as second argument, and
 terminate these steps.

9. If the element is [the `body`
 element](https://html.spec.whatwg.org/multipage/dom.html#the-body-element-2), `document` is in [quirks
 mode](https://dom.spec.whatwg.org/#concept-document-quirks), and the element is not [potentially
 scrollable](#potentially-scrollable) in at least one axis, invoke
 [`scroll()`](#dom-window-scroll) on `window` with `x` as first
 argument and
 [`scrollY`](#dom-window-scrolly) on `window` as second argument, and
 terminate these steps.

10. If the element does not have any associated
 [box](https://drafts.csswg.org/css-display-4/#box), the element has no associated [scrolling
 box](#scrolling-box), or
 the element has no overflow, terminate these steps.

11. [Scroll the element](#scroll-an-element) to
 `x`,[`scrollTop`](#dom-element-scrolltop), with the scroll behavior being \"`auto`\".

Tests

- [scrollLeft-of-scroller-with-wider-scrollbar.html](https://wpt.fyi/results/css/cssom-view/scrollLeft-of-scroller-with-wider-scrollbar.html "css/cssom-view/scrollLeft-of-scroller-with-wider-scrollbar.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/scrollLeft-of-scroller-with-wider-scrollbar.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/scrollLeft-of-scroller-with-wider-scrollbar.html)
- [scrollLeftTop.html](https://wpt.fyi/results/css/cssom-view/scrollLeftTop.html "css/cssom-view/scrollLeftTop.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/scrollLeftTop.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/scrollLeftTop.html)

The [`scrollWidth`] attribute must return
the result of running these steps:

1. Let `document` be the element's [node
 document](https://dom.spec.whatwg.org/#concept-node-document).

2. If `document` is not the [active
 document](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-document), return zero and terminate these steps.

3. Let `viewport width` be the width of the
 [viewport](https://drafts.csswg.org/css2/#viewport%E2%91%A0) excluding the width of the scroll bar, if any, or
 zero if there is no [viewport].

4. If the element is the [root
 element](https://drafts.csswg.org/css-display-4/#root-element) and `document` is not in [quirks
 mode](https://dom.spec.whatwg.org/#concept-document-quirks) return
 max([viewport](https://drafts.csswg.org/css2/#viewport%E2%91%A0) [scrolling
 area](#scrolling-area)
 width, `viewport width`).

5. If the element is [the `body`
 element](https://html.spec.whatwg.org/multipage/dom.html#the-body-element-2), `document` is in [quirks
 mode](https://dom.spec.whatwg.org/#concept-document-quirks) and the element is not [potentially
 scrollable](#potentially-scrollable) in the x axis, return
 max([viewport](https://drafts.csswg.org/css2/#viewport%E2%91%A0) [scrolling
 area](#scrolling-area)
 width, `viewport width`).

6. If the element does not have any associated
 [box](https://drafts.csswg.org/css-display-4/#box) return zero and terminate these steps.

7. Return the width of the element's [scrolling
 area](#scrolling-area).

Tests

- [pt-to-px-width.html](https://wpt.fyi/results/css/cssom-view/pt-to-px-width.html "css/cssom-view/pt-to-px-width.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/pt-to-px-width.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/pt-to-px-width.html)
- [scrollWidthHeight-contain-layout.html](https://wpt.fyi/results/css/cssom-view/scrollWidthHeight-contain-layout.html "css/cssom-view/scrollWidthHeight-contain-layout.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/scrollWidthHeight-contain-layout.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/scrollWidthHeight-contain-layout.html)
- [scrollWidthHeight-negative-margin-001.html](https://wpt.fyi/results/css/cssom-view/scrollWidthHeight-negative-margin-001.html "css/cssom-view/scrollWidthHeight-negative-margin-001.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/scrollWidthHeight-negative-margin-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/scrollWidthHeight-negative-margin-001.html)
- [scrollWidthHeight-negative-margin-002.html](https://wpt.fyi/results/css/cssom-view/scrollWidthHeight-negative-margin-002.html "css/cssom-view/scrollWidthHeight-negative-margin-002.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/scrollWidthHeight-negative-margin-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/scrollWidthHeight-negative-margin-002.html)
- [scrollWidthHeight-overflow-visible-margin-collapsing.html](https://wpt.fyi/results/css/cssom-view/scrollWidthHeight-overflow-visible-margin-collapsing.html "css/cssom-view/scrollWidthHeight-overflow-visible-margin-collapsing.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/scrollWidthHeight-overflow-visible-margin-collapsing.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/scrollWidthHeight-overflow-visible-margin-collapsing.html)
- [scrollWidthHeight-overflow-visible-negative-margins.html](https://wpt.fyi/results/css/cssom-view/scrollWidthHeight-overflow-visible-negative-margins.html "css/cssom-view/scrollWidthHeight-overflow-visible-negative-margins.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/scrollWidthHeight-overflow-visible-negative-margins.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/scrollWidthHeight-overflow-visible-negative-margins.html)
- [scrollWidthHeight.xht](https://wpt.fyi/results/css/cssom-view/scrollWidthHeight.xht "css/cssom-view/scrollWidthHeight.xht")
 [[(live
 test)]](http://wpt.live/css/cssom-view/scrollWidthHeight.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/scrollWidthHeight.xht)
- [scrollWidthHeightWhenNotScrollable.xht](https://wpt.fyi/results/css/cssom-view/scrollWidthHeightWhenNotScrollable.xht "css/cssom-view/scrollWidthHeightWhenNotScrollable.xht")
 [[(live
 test)]](http://wpt.live/css/cssom-view/scrollWidthHeightWhenNotScrollable.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/scrollWidthHeightWhenNotScrollable.xht)

The [`scrollHeight`] attribute
must return the result of running these steps:

1. Let `document` be the element's [node
 document](https://dom.spec.whatwg.org/#concept-node-document).

2. If `document` is not the [active
 document](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-document), return zero and terminate these steps.

3. Let `viewport height` be the height of the
 [viewport](https://drafts.csswg.org/css2/#viewport%E2%91%A0) excluding the height of the scroll bar, if any, or
 zero if there is no [viewport].

4. If the element is the [root
 element](https://drafts.csswg.org/css-display-4/#root-element) and `document` is not in [quirks
 mode](https://dom.spec.whatwg.org/#concept-document-quirks) return
 max([viewport](https://drafts.csswg.org/css2/#viewport%E2%91%A0) [scrolling
 area](#scrolling-area)
 height, `viewport height`).

5. If the element is [the `body`
 element](https://html.spec.whatwg.org/multipage/dom.html#the-body-element-2), `document` is in [quirks
 mode](https://dom.spec.whatwg.org/#concept-document-quirks) and the element is not [potentially
 scrollable](#potentially-scrollable) in the y axis, return
 max([viewport](https://drafts.csswg.org/css2/#viewport%E2%91%A0) [scrolling
 area](#scrolling-area)
 height, `viewport height`).

6. If the element does not have any associated
 [box](https://drafts.csswg.org/css-display-4/#box) return zero and terminate these steps.

7. Return the height of the element's [scrolling
 area](#scrolling-area).

The [`clientTop`] attribute must run
these steps:

1. If the element has no associated
 [box](https://drafts.csswg.org/css-display-4/#box) or if the [box] is inline, return
 zero.

2. Return the
 [unscaled](https://drafts.csswg.org/css-viewport/#unscaled) computed value of the
 [border-top-width](https://drafts.csswg.org/css-borders-4/#propdef-border-top-width) property plus the height of any
 scrollbar rendered between the top [padding
 edge](https://drafts.csswg.org/css-box-4/#padding-edge) and the top [border
 edge](https://drafts.csswg.org/css-box-4/#border-edge), ignoring any
 [transforms](#transforms) that
 apply to the element and its ancestors.

Tests

- [client-props-inline-list-item.html](https://wpt.fyi/results/css/cssom-view/client-props-inline-list-item.html "css/cssom-view/client-props-inline-list-item.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/client-props-inline-list-item.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/client-props-inline-list-item.html)
- [client-props-input.html](https://wpt.fyi/results/css/cssom-view/client-props-input.html "css/cssom-view/client-props-input.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/client-props-input.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/client-props-input.html)
- [client-props-root.html](https://wpt.fyi/results/css/cssom-view/client-props-root.html "css/cssom-view/client-props-root.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/client-props-root.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/client-props-root.html)
- [client-props-zoom.html](https://wpt.fyi/results/css/cssom-view/client-props-zoom.html "css/cssom-view/client-props-zoom.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/client-props-zoom.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/client-props-zoom.html)
- [outer-svg.html](https://wpt.fyi/results/css/cssom-view/outer-svg.html "css/cssom-view/outer-svg.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/outer-svg.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/outer-svg.html)
- [table-client-props.html](https://wpt.fyi/results/css/cssom-view/table-client-props.html "css/cssom-view/table-client-props.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/table-client-props.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/table-client-props.html)

The [`clientLeft`] attribute must run
these steps:

1. If the element has no associated
 [box](https://drafts.csswg.org/css-display-4/#box) or if the [box] is inline, return
 zero.

2. Return the
 [unscaled](https://drafts.csswg.org/css-viewport/#unscaled) computed value of the
 [border-left-width](https://drafts.csswg.org/css-borders-4/#propdef-border-left-width) property plus the width of any
 scrollbar rendered between the left [padding
 edge](https://drafts.csswg.org/css-box-4/#padding-edge) and the left [border
 edge](https://drafts.csswg.org/css-box-4/#border-edge), ignoring any
 [transforms](#transforms) that
 apply to the element and its ancestors.

The [`clientWidth`] attribute must run
these steps:

1. If the element has no associated
 [box](https://drafts.csswg.org/css-display-4/#box) or if the [box] is inline, return
 zero.

2. If the element is the [root
 element](https://drafts.csswg.org/css-display-4/#root-element) and the element's [node
 document](https://dom.spec.whatwg.org/#concept-node-document) is not in [quirks
 mode](https://dom.spec.whatwg.org/#concept-document-quirks), or if the element is [the `body`
 element](https://html.spec.whatwg.org/multipage/dom.html#the-body-element-2) and the element's [node
 document] *is* in [quirks
 mode], return the
 [viewport](https://drafts.csswg.org/css2/#viewport%E2%91%A0) width excluding the size of a rendered scroll bar
 (if any).

3. Return the
 [unscaled](https://drafts.csswg.org/css-viewport/#unscaled) width of the [padding
 edge](https://drafts.csswg.org/css-box-4/#padding-edge) excluding the width of any rendered scrollbar
 between the [padding edge] and the [border
 edge](https://drafts.csswg.org/css-box-4/#border-edge), ignoring any
 [transforms](#transforms) or
 that apply to the element and its ancestors.

The [`clientHeight`] attribute
must run these steps:

1. If the element has no associated
 [box](https://drafts.csswg.org/css-display-4/#box) or if the [box] is inline, return
 zero.

2. If the element is the [root
 element](https://drafts.csswg.org/css-display-4/#root-element) and the element's [node
 document](https://dom.spec.whatwg.org/#concept-node-document) is not in [quirks
 mode](https://dom.spec.whatwg.org/#concept-document-quirks), or if the element is [the `body`
 element](https://html.spec.whatwg.org/multipage/dom.html#the-body-element-2) and the element's [node
 document] *is* in [quirks
 mode], return the
 [viewport](https://drafts.csswg.org/css2/#viewport%E2%91%A0) height excluding the size of a rendered scroll bar
 (if any).

3. Return the
 [unscaled](https://drafts.csswg.org/css-viewport/#unscaled) height of the [padding
 edge](https://drafts.csswg.org/css-box-4/#padding-edge) excluding the height of any rendered scrollbar
 between the [padding edge] and the [border
 edge](https://drafts.csswg.org/css-box-4/#border-edge), ignoring any
 [transforms](#transforms)
 that apply to the element and its ancestors.

The [`currentCSSZoom`] attribute
must return the [effective
zoom](https://drafts.csswg.org/css-viewport/#effective-zoom) of the element, or 1.0 if the element isn't [being
rendered](https://html.spec.whatwg.org/multipage/rendering.html#being-rendered).

Tests

- [Element-currentCSSZoom.html](https://wpt.fyi/results/css/cssom-view/Element-currentCSSZoom.html "css/cssom-view/Element-currentCSSZoom.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/Element-currentCSSZoom.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/Element-currentCSSZoom.html)
- [table-border-collapse-client-width-height.html](https://wpt.fyi/results/css/cssom-view/table-border-collapse-client-width-height.html "css/cssom-view/table-border-collapse-client-width-height.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/table-border-collapse-client-width-height.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/table-border-collapse-client-width-height.html)
- [table-border-separate-client-width-height.html](https://wpt.fyi/results/css/cssom-view/table-border-separate-client-width-height.html "css/cssom-view/table-border-separate-client-width-height.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/table-border-separate-client-width-height.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/table-border-separate-client-width-height.html)
- [table-with-border-client-width-height.html](https://wpt.fyi/results/css/cssom-view/table-with-border-client-width-height.html "css/cssom-view/table-with-border-client-width-height.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/table-with-border-client-width-height.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/table-with-border-client-width-height.html)

### [6.1. ][[`Element`](https://dom.spec.whatwg.org/#element) Scrolling Members]
To [determine the scroll-into-view
position] of a `target`, which is an
[Element](https://dom.spec.whatwg.org/#concept-element),
[pseudo-element](https://drafts.csswg.org/selectors-4/#pseudo-element), or
[Range](https://dom.spec.whatwg.org/#concept-range), with a scroll behavior `behavior`, a block
flow direction position `block`, an inline base direction
position `inline`, and a [scrolling
box](#scrolling-box)
`scrolling box`, run the following steps:

1. Let `target bounding border box` be the box represented
 by the return value of invoking Element's
 [`getBoundingClientRect()`](#dom-element-getboundingclientrect), if `target` is an
 [Element](https://dom.spec.whatwg.org/#concept-element), or Range's
 [`getBoundingClientRect()`](#dom-range-getboundingclientrect), if `target` is a
 [Range](https://dom.spec.whatwg.org/#concept-range).

2. Let `scrolling box edge A` be the [beginning
 edge](#beginning-edges)
 in the [block flow
 direction](https://drafts.csswg.org/css-writing-modes-4/#block-flow-direction) of `scrolling box`, and let
 `element edge A` be
 `target bounding border box`'s edge on the same physical
 side as that of `scrolling box edge A`.

3. Let `scrolling box edge B` be the [ending
 edge](#ending-edges) in the
 [block flow
 direction](https://drafts.csswg.org/css-writing-modes-4/#block-flow-direction) of `scrolling box`, and let
 `element edge B` be
 `target bounding border box`'s edge on the same physical
 side as that of `scrolling box edge B`.

4. Let `scrolling box edge C` be the [beginning
 edge](#beginning-edges)
 in the [inline base
 direction](https://drafts.csswg.org/css-writing-modes-4/#inline-base-direction) of `scrolling box`, and let
 `element edge C` be
 `target bounding border box`'s edge on the same physical
 side as that of `scrolling box edge C`.

5. Let `scrolling box edge D` be the [ending
 edge](#ending-edges) in the
 [inline base
 direction](https://drafts.csswg.org/css-writing-modes-4/#inline-base-direction) of `scrolling box`, and let
 `element edge D` be
 `target bounding border box`'s edge on the same physical
 side as that of `scrolling box edge D`.

6. Let `element height` be the distance between
 `element edge A` and `element edge B`.

7. Let `scrolling box height` be the distance between
 `scrolling box edge A` and
 `scrolling box edge B`.

8. Let `element width` be the distance between
 `element edge C` and `element edge D`.

9. Let `scrolling box width` be the distance between
 `scrolling box edge C` and
 `scrolling box edge D`.

10. Let `position` be the scroll position
 `scrolling box` would have by following these steps:

 1. If `block` is \"`start`\", then align
 `element edge A` with
 `scrolling box edge A`.

 2. Otherwise, if `block` is \"`end`\", then align
 `element edge B` with
 `scrolling box edge B`.

 3. Otherwise, if `block` is \"`center`\", then align the
 center of `target bounding border box` with the
 center of `scrolling box` in
 `scrolling box`'s [block flow
 direction](https://drafts.csswg.org/css-writing-modes-4/#block-flow-direction).

 4. Otherwise, `block` is \"`nearest`\":

 If `element edge A` and `element edge B` are both outside `scrolling box edge A` and `scrolling box edge B`
 : Do nothing.

 If `element edge A` is outside `scrolling box edge A` and `element height` is less than `scrolling box height`\
 If `element edge B` is outside `scrolling box edge B` and `element height` is greater than `scrolling box height`
 : Align `element edge A` with
 `scrolling box edge A`.

 If `element edge A` is outside `scrolling box edge A` and `element height` is greater than `scrolling box height`\
 If `element edge B` is outside `scrolling box edge B` and `element height` is less than `scrolling box height`
 : Align `element edge B` with
 `scrolling box edge B`.

 5. If `inline` is \"`start`\", then align
 `element edge C` with
 `scrolling box edge C`.

 6. Otherwise, if `inline` is \"`end`\", then align
 `element edge D` with
 `scrolling box edge D`.

 7. Otherwise, if `inline` is \"`center`\", then align
 the center of `target bounding border box` with the
 center of `scrolling box` in
 `scrolling box`'s [inline base
 direction](https://drafts.csswg.org/css-writing-modes-4/#inline-base-direction).

 8. Otherwise, `inline` is \"`nearest`\":

 If `element edge C` and `element edge D` are both outside `scrolling box edge C` and `scrolling box edge D`
 : Do nothing.

 If `element edge C` is outside `scrolling box edge C` and `element width` is less than `scrolling box width`\
 If `element edge D` is outside `scrolling box edge D` and `element width` is greater than `scrolling box width`
 : Align `element edge C` with
 `scrolling box edge C`.

 If `element edge C` is outside `scrolling box edge C` and `element width` is greater than `scrolling box width`\
 If `element edge D` is outside `scrolling box edge D` and `element width` is less than `scrolling box width`
 : Align `element edge D` with
 `scrolling box edge D`.

 9. If `target` is an
 [Element](https://dom.spec.whatwg.org/#concept-element), and the target element defines some [scroll
 snap
 positions](https://drafts.csswg.org/css-scroll-snap-1/#scroll-snap-position), then the user agent must [scroll
 snap](https://drafts.csswg.org/css-scroll-snap-1/#scroll-snap) the resulting `position` to one of
 that element's [scroll snap
 positions] if its nearest
 [scroll
 container](https://drafts.csswg.org/css-overflow-3/#scroll-container) is a [scroll snap
 container](https://drafts.csswg.org/css-scroll-snap-1/#scroll-snap-container). The user agent *may* also do this even when
 the [scroll container] has
 [scroll-snap-type:
 none](https://drafts.csswg.org/css-scroll-snap-1/#propdef-scroll-snap-type).

 10. Return `position`.

To [scroll a target into view] `target`, which is an
[Element](https://dom.spec.whatwg.org/#concept-element),
[pseudo-element](https://drafts.csswg.org/selectors-4/#pseudo-element), or
[Range](https://dom.spec.whatwg.org/#concept-range), with a scroll behavior `behavior`, a block
flow direction position `block`, an inline base direction
position `inline`, and an optional containing
[Element](https://dom.spec.whatwg.org/#concept-attribute-element) to stop scrolling after reaching
`container`, means to run these steps:

1. Let `ancestorPromises` be an empty set of
 [`Promise`](https://webidl.spec.whatwg.org/#idl-promise)s.

2. For each ancestor element or
 [viewport](https://drafts.csswg.org/css2/#viewport%E2%91%A0) that establishes a [scrolling
 box](#scrolling-box)
 `scrolling box`, in order of innermost to outermost
 [scrolling box], run these substeps:

 1. If the
 [`Document`](https://dom.spec.whatwg.org/#document) associated with `target` is not
 [same
 origin](https://html.spec.whatwg.org/multipage/browsers.html#same-origin) with the
 [`Document`](https://dom.spec.whatwg.org/#document) associated with the element or
 [viewport](https://drafts.csswg.org/css2/#viewport%E2%91%A0) associated with `scrolling box`,
 abort any remaining iteration of this loop.

 2. Let `position` be the scroll position resulting from
 running the steps to [determine the scroll-into-view
 position](#determine-the-scroll-into-view-position) of `target` with
 `behavior` as the `scroll behavior`,
 `block` as the `block flow position`,
 `inline` as the
 `inline base direction position` and
 `scrolling box` as the `scrolling box`.

 3. If `position` is not the same as
 `scrolling box`'s current scroll position, or
 `scrolling box` has an ongoing [smooth
 scroll](#concept-smooth-scroll),

 1.

 If `scrolling box` is associated with an element
 : [Perform a
 scroll](#perform-a-scroll) of the element's
 `scrolling box` to `position`,
 with the element as the associated element and
 `behavior` as the scroll behavior. Add the
 [`Promise`](https://webidl.spec.whatwg.org/#idl-promise) retured from this step to the set
 `ancestorPromises`.

 If `scrolling box` is associated with a [viewport](https://drafts.csswg.org/css2/#viewport%E2%91%A0)

 : 1. Let `document` be the
 [viewport's](https://drafts.csswg.org/css2/#viewport%E2%91%A0) associated
 [`Document`](https://dom.spec.whatwg.org/#document).

 2. Let `root element` be
 `document`'s [root
 element](https://drafts.csswg.org/css-display-4/#root-element), if there is one, or null
 otherwise.

 3. [Perform a
 scroll](#viewport-perform-a-scroll) of the
 [viewport](https://drafts.csswg.org/css2/#viewport%E2%91%A0) to `position`, with
 `root element` as the associated element
 and `behavior` as the scroll behavior.
 Add the
 [`Promise`](https://webidl.spec.whatwg.org/#idl-promise) retured from this step in the set
 `ancestorPromises`.

 4. If `container` is not null and either
 `scrolling box` is a [shadow-including inclusive
 ancestor](https://dom.spec.whatwg.org/#concept-shadow-including-inclusive-ancestor) of `container` or is a
 [viewport](https://drafts.csswg.org/css2/#viewport%E2%91%A0) whose
 [document](https://dom.spec.whatwg.org/#concept-document) is a [shadow-including inclusive
 ancestor]
 of `container`, abort any remaining iteration of this
 loop.

3. Let `scrollPromise` be a new
 [`Promise`](https://webidl.spec.whatwg.org/#idl-promise).

4. Return `scrollPromise`, and run the remaining steps [in
 parallel](https://html.spec.whatwg.org/multipage/infrastructure.html#in-parallel).

5. Resolve `scrollPromise` when all
 [`Promise`](https://webidl.spec.whatwg.org/#idl-promise)s in `ancestorPromises` have settled.

To [scroll an element] (or
[pseudo-element](https://drafts.csswg.org/selectors-4/#pseudo-element)) `element` to `x`,`y`
optionally with a scroll behavior `behavior` (which is
\"`auto`\" if omitted) means to:

1. Let `box` be `element`'s associated [scrolling
 box](#scrolling-box).

2.

 If `box` has rightward [overflow direction](#overflow-directions)
 : Let `x` be max(0, min(`x`,
 `element` [scrolling
 area](#scrolling-area) width - `element` [padding
 edge](https://drafts.csswg.org/css-box-4/#padding-edge) width)).

 If `box` has leftward [overflow direction](#overflow-directions)
 : Let `x` be min(0, max(`x`,
 `element` [padding
 edge](https://drafts.csswg.org/css-box-4/#padding-edge) width - `element` [scrolling
 area](#scrolling-area) width)).

3.

 If `box` has downward [overflow direction](#overflow-directions)
 : Let `y` be max(0, min(`y`,
 `element` [scrolling
 area](#scrolling-area) height - `element` [padding
 edge](https://drafts.csswg.org/css-box-4/#padding-edge) height)).

 If `box` has upward [overflow direction](#overflow-directions)
 : Let `y` be min(0, max(`y`,
 `element` [padding
 edge](https://drafts.csswg.org/css-box-4/#padding-edge) height - `element` [scrolling
 area](#scrolling-area) height)).

4. Let `position` be the scroll position `box`
 would have by aligning [scrolling
 area](#scrolling-area)
 x-coordinate `x` with the left of `box` and
 aligning [scrolling area] y-coordinate
 `y` with the top of `box`.

5. If `position` is the same as `box`'s current
 scroll position, and `box` does not have an ongoing
 [smooth
 scroll](#concept-smooth-scroll), return a resolved
 [`Promise`](https://webidl.spec.whatwg.org/#idl-promise) and abort the remaining steps.

6. [Perform a scroll](#perform-a-scroll) of `box` to `position`,
 `element` as the associated element and
 `behavior` as the scroll behavior. Let
 `scrollPromise` be the
 [`Promise`](https://webidl.spec.whatwg.org/#idl-promise) returned from this step.

7. Return `scrollPromise`.

## [7. ][Extensions to the [`HTMLElement`](https://html.spec.whatwg.org/multipage/dom.html#htmlelement) Interface]
```
partial interface HTMLElement {
 readonly attribute Element? scrollParent;
 readonly attribute Element? offsetParent;
 readonly attribute long offsetTop;
 readonly attribute long offsetLeft;
 readonly attribute long offsetWidth;
 readonly attribute long offsetHeight;
};
```

The [`scrollParent`]
attribute must return the result of running these steps:

1. If any of the following holds true, return null and terminate this
 algorithm:

 - The element does not have an associated
 [box](https://drafts.csswg.org/css-display-4/#box).

 - The element is the [root
 element](https://drafts.csswg.org/css-display-4/#root-element).

 - The element is [the `body`
 element](https://html.spec.whatwg.org/multipage/dom.html#the-body-element-2).

 - The element's computed value of the
 [position](https://drafts.csswg.org/css-position-3/#propdef-position) property is
 [fixed](https://drafts.csswg.org/css-position-3/#valdef-position-fixed) and no ancestor establishes a fixed
 position [containing
 block](https://drafts.csswg.org/css-display-4/#containing-block).

2. Let `ancestor` be the [containing
 block](https://drafts.csswg.org/css-display-4/#containing-block) of the element in the [flat
 tree](https://drafts.csswg.org/css-shadow-1/#flat-tree) and repeat these substeps:

 1. If `ancestor` is the [initial containing
 block](https://drafts.csswg.org/css-display-4/#initial-containing-block), return the
 [`scrollingElement`](#dom-document-scrollingelement) for the element's document if it is not
 [closed-shadow-hidden](https://dom.spec.whatwg.org/#concept-closed-shadow-hidden) from the element, otherwise return null.

 2. If `ancestor` is not
 [closed-shadow-hidden](https://dom.spec.whatwg.org/#concept-closed-shadow-hidden) from the element, and is a [scroll
 container](https://drafts.csswg.org/css-overflow-3/#scroll-container), terminate this algorithm and return
 `ancestor`.

 3. If the computed value of the
 [position](https://drafts.csswg.org/css-position-3/#propdef-position) property of
 `ancestor` is
 [fixed](https://drafts.csswg.org/css-position-3/#valdef-position-fixed), and no ancestor establishes a fixed
 position [containing
 block](https://drafts.csswg.org/css-display-4/#containing-block), terminate this algorithm and return null.

 4. Let `ancestor` be the [containing
 block](https://drafts.csswg.org/css-display-4/#containing-block) of `ancestor` in the [flat
 tree](https://drafts.csswg.org/css-shadow-1/#flat-tree).

Tests

- [scrollParent-quirks-mode.html](https://wpt.fyi/results/css/cssom-view/scrollParent-quirks-mode.html "css/cssom-view/scrollParent-quirks-mode.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/scrollParent-quirks-mode.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/scrollParent-quirks-mode.html)
- [scrollParent-shadow-tree.html](https://wpt.fyi/results/css/cssom-view/scrollParent-shadow-tree.html "css/cssom-view/scrollParent-shadow-tree.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/scrollParent-shadow-tree.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/scrollParent-shadow-tree.html)
- [scrollParent.html](https://wpt.fyi/results/css/cssom-view/scrollParent.html "css/cssom-view/scrollParent.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/scrollParent.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/scrollParent.html)

The [`offsetParent`]
attribute must return the result of running these steps:

1. If any of the following holds true return null and terminate this
 algorithm:

 - The element does not have an associated
 [box](https://drafts.csswg.org/css-display-4/#box).

 - The element is the [root
 element](https://drafts.csswg.org/css-display-4/#root-element).

 - The element is [the `body`
 element](https://html.spec.whatwg.org/multipage/dom.html#the-body-element-2).

 - The element's computed value of the
 [position](https://drafts.csswg.org/css-position-3/#propdef-position) property is
 [fixed](https://drafts.csswg.org/css-position-3/#valdef-position-fixed) and no ancestor establishes a fixed
 position [containing
 block](https://drafts.csswg.org/css-display-4/#containing-block).

2. Let `ancestor` be the parent of the element in the [flat
 tree](https://drafts.csswg.org/css-shadow-1/#flat-tree) and repeat these substeps:

 1. If `ancestor` is
 [closed-shadow-hidden](https://dom.spec.whatwg.org/#concept-closed-shadow-hidden) from the element, its computed value of the
 [position](https://drafts.csswg.org/css-position-3/#propdef-position) property is
 [fixed](https://drafts.csswg.org/css-position-3/#valdef-position-fixed), and no ancestor establishes a fixed
 position [containing
 block](https://drafts.csswg.org/css-display-4/#containing-block), terminate this algorithm and return null.

 2. If `ancestor` is not
 [closed-shadow-hidden](https://dom.spec.whatwg.org/#concept-closed-shadow-hidden) from the element and satisfies at least one of
 the following, terminate this algorithm and return
 `ancestor`.

 - The element is in a fixed position [containing
 block](https://drafts.csswg.org/css-display-4/#containing-block), and `ancestor` is a containing
 block for fixed-positioned descendants.

 - The element is not in a fixed position [containing
 block](https://drafts.csswg.org/css-display-4/#containing-block), and:

 - `ancestor` is a containing block of
 absolutely-positioned descendants (regardless of whether
 there are any absolutely-positioned descendants).

 - It is [the `body`
 element](https://html.spec.whatwg.org/multipage/dom.html#the-body-element-2).

 - The computed value of the
 [position](https://drafts.csswg.org/css-position-3/#propdef-position) property of the element
 is
 [static](https://drafts.csswg.org/css-position-3/#valdef-position-static) and the ancestor is one of the
 following [HTML
 elements](https://html.spec.whatwg.org/multipage/infrastructure.html#html-elements): `td`, `th`, or `table`.

 - The element has a different [effective
 zoom](https://drafts.csswg.org/css-viewport/#effective-zoom) than `ancestor`.

 3. If there is no more parent of `ancestor` in the [flat
 tree](https://drafts.csswg.org/css-shadow-1/#flat-tree), terminate this algorithm and return null.

 4. Let `ancestor` be the parent of `ancestor`
 in the [flat
 tree](https://drafts.csswg.org/css-shadow-1/#flat-tree).

Tests

- [offsetParent-body-and-html.html](https://wpt.fyi/results/css/cssom-view/offsetParent-body-and-html.html "css/cssom-view/offsetParent-body-and-html.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/offsetParent-body-and-html.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/offsetParent-body-and-html.html)
- [offsetParent_element_test.html](https://wpt.fyi/results/css/cssom-view/offsetParent_element_test.html "css/cssom-view/offsetParent_element_test.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/offsetParent_element_test.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/offsetParent_element_test.html)
- [offsetParent-block-in-inline.html](https://wpt.fyi/results/css/cssom-view/offsetParent-block-in-inline.html "css/cssom-view/offsetParent-block-in-inline.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/offsetParent-block-in-inline.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/offsetParent-block-in-inline.html)
- [offsetParent-fixed.html](https://wpt.fyi/results/css/cssom-view/offsetParent-fixed.html "css/cssom-view/offsetParent-fixed.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/offsetParent-fixed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/offsetParent-fixed.html)

The [`offsetTop`] attribute must
return the result of running these steps:

1. If the element is [the `body`
 element](https://html.spec.whatwg.org/multipage/dom.html#the-body-element-2) or does not have any associated
 [box](https://drafts.csswg.org/css-display-4/#box) return zero and terminate this algorithm.

2. If the
 [`offsetParent`](#dom-htmlelement-offsetparent) of the element is null return the
 [unscaled](https://drafts.csswg.org/css-viewport/#unscaled) y-coordinate of the top [border
 edge](https://drafts.csswg.org/css-box-4/#border-edge) of the first
 [box](https://drafts.csswg.org/css-display-4/#box) associated with the element, relative to the
 [initial containing
 block](https://drafts.csswg.org/css-display-4/#initial-containing-block) origin, ignoring any
 [transforms](#transforms)that
 apply to the element and its ancestors and terminate this algorithm.

3. Return the
 [unscaled](https://drafts.csswg.org/css-viewport/#unscaled) result of subtracting the y-coordinate of the top
 [padding
 edge](https://drafts.csswg.org/css-box-4/#padding-edge) of the first
 [box](https://drafts.csswg.org/css-display-4/#box) associated with the
 [`offsetParent`](#dom-htmlelement-offsetparent) of the element from the y-coordinate of the top
 [border
 edge](https://drafts.csswg.org/css-box-4/#border-edge) of the first [box] associated with
 the element, relative to the [initial containing
 block](https://drafts.csswg.org/css-display-4/#initial-containing-block) origin, ignoring any
 [transforms](#transforms)
 that apply to the element and its ancestors.

 An inline element that consists of multiple line
 boxes will only have its first
 [box](https://drafts.csswg.org/css-display-4/#box) considered.

Tests

- [offsetTop-offsetLeft-nested-offsetParents.html](https://wpt.fyi/results/css/cssom-view/offsetTop-offsetLeft-nested-offsetParents.html "css/cssom-view/offsetTop-offsetLeft-nested-offsetParents.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/offsetTop-offsetLeft-nested-offsetParents.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/offsetTop-offsetLeft-nested-offsetParents.html)
- [offsetTop-offsetLeft-with-zoom.html](https://wpt.fyi/results/css/cssom-view/offsetTop-offsetLeft-with-zoom.html "css/cssom-view/offsetTop-offsetLeft-with-zoom.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/offsetTop-offsetLeft-with-zoom.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/offsetTop-offsetLeft-with-zoom.html)
- [offsetTopLeft-border-box.html](https://wpt.fyi/results/css/cssom-view/offsetTopLeft-border-box.html "css/cssom-view/offsetTopLeft-border-box.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/offsetTopLeft-border-box.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/offsetTopLeft-border-box.html)
- [offsetTopLeft-empty-inline-offset.html](https://wpt.fyi/results/css/cssom-view/offsetTopLeft-empty-inline-offset.html "css/cssom-view/offsetTopLeft-empty-inline-offset.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/offsetTopLeft-empty-inline-offset.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/offsetTopLeft-empty-inline-offset.html)
- [offsetTopLeft-empty-inline.html](https://wpt.fyi/results/css/cssom-view/offsetTopLeft-empty-inline.html "css/cssom-view/offsetTopLeft-empty-inline.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/offsetTopLeft-empty-inline.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/offsetTopLeft-empty-inline.html)
- [offsetTopLeft-inline.html](https://wpt.fyi/results/css/cssom-view/offsetTopLeft-inline.html "css/cssom-view/offsetTopLeft-inline.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/offsetTopLeft-inline.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/offsetTopLeft-inline.html)
- [offsetTopLeft-leading-space-inline.html](https://wpt.fyi/results/css/cssom-view/offsetTopLeft-leading-space-inline.html "css/cssom-view/offsetTopLeft-leading-space-inline.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/offsetTopLeft-leading-space-inline.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/offsetTopLeft-leading-space-inline.html)
- [offsetTopLeft-table-caption.html](https://wpt.fyi/results/css/cssom-view/offsetTopLeft-table-caption.html "css/cssom-view/offsetTopLeft-table-caption.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/offsetTopLeft-table-caption.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/offsetTopLeft-table-caption.html)
- [offsetTopLeft-trailing-space-inline.html](https://wpt.fyi/results/css/cssom-view/offsetTopLeft-trailing-space-inline.html "css/cssom-view/offsetTopLeft-trailing-space-inline.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/offsetTopLeft-trailing-space-inline.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/offsetTopLeft-trailing-space-inline.html)
- [offsetTopLeftInScrollableParent.html](https://wpt.fyi/results/css/cssom-view/offsetTopLeftInScrollableParent.html "css/cssom-view/offsetTopLeftInScrollableParent.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/offsetTopLeftInScrollableParent.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/offsetTopLeftInScrollableParent.html)
- [table-offset-props.html](https://wpt.fyi/results/css/cssom-view/table-offset-props.html "css/cssom-view/table-offset-props.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/table-offset-props.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/table-offset-props.html)

The [`offsetLeft`]
attribute must return the result of running these steps:

1. If the element is [the `body`
 element](https://html.spec.whatwg.org/multipage/dom.html#the-body-element-2) or does not have any associated
 [box](https://drafts.csswg.org/css-display-4/#box) return zero and terminate this algorithm.

2. If the
 [`offsetParent`](#dom-htmlelement-offsetparent) of the element is null return the
 [unscaled](https://drafts.csswg.org/css-viewport/#unscaled) x-coordinate of the left [border
 edge](https://drafts.csswg.org/css-box-4/#border-edge) of the first
 [box](https://drafts.csswg.org/css-display-4/#box) associated with the element, relative to the
 [initial containing
 block](https://drafts.csswg.org/css-display-4/#initial-containing-block) origin, ignoring any
 [transforms](#transforms)
 that apply to the element and its ancestors, and terminate this
 algorithm.

3. Return the
 [unscaled](https://drafts.csswg.org/css-viewport/#unscaled) result of subtracting the x-coordinate of the left
 [padding
 edge](https://drafts.csswg.org/css-box-4/#padding-edge) of the first
 [box](https://drafts.csswg.org/css-display-4/#box) associated with the
 [`offsetParent`](#dom-htmlelement-offsetparent) of the element from the x-coordinate of the left
 [border
 edge](https://drafts.csswg.org/css-box-4/#border-edge) of the first [box] associated with
 the element, relative to the [initial containing
 block](https://drafts.csswg.org/css-display-4/#initial-containing-block) origin, ignoring any
 [transforms](#transforms)
 that apply to the element and its ancestors.

The [`offsetWidth`]
attribute must return the result of running these steps:

1. If the element does not have any associated
 [box](https://drafts.csswg.org/css-display-4/#box) return zero and terminate this algorithm.

2. Return the
 [unscaled](https://drafts.csswg.org/css-viewport/#unscaled) width of the axis-aligned bounding box of the
 [border
 boxes](https://drafts.csswg.org/css-box-4/#border-box) of all fragments generated by the element's
 [principal
 box](https://drafts.csswg.org/css-display-4/#principal-box), ignoring any
 [transforms](#transforms)
 that apply to the element and its ancestors.

 If the element's [principal
 box](https://drafts.csswg.org/css-display-4/#principal-box) is an [inline-level
 box](https://drafts.csswg.org/css-display-4/#inline-level-box) which was \"split\" by a
 [block-level](https://drafts.csswg.org/css-display-4/#block-level) descendant, also include fragments generated by the
 [block-level] descendants, unless they are
 zero width or height.

Tests

- [htmlelement-offset-width-001.html](https://wpt.fyi/results/css/cssom-view/htmlelement-offset-width-001.html "css/cssom-view/htmlelement-offset-width-001.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/htmlelement-offset-width-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/htmlelement-offset-width-001.html)

The [`offsetHeight`]
attribute must return the result of running these steps:

1. If the element does not have any associated
 [box](https://drafts.csswg.org/css-display-4/#box) return zero and terminate this algorithm.

2. Return the
 [unscaled](https://drafts.csswg.org/css-viewport/#unscaled) height of the axis-aligned bounding box of the
 [border
 boxes](https://drafts.csswg.org/css-box-4/#border-box) of all fragments generated by the element's
 [principal
 box](https://drafts.csswg.org/css-display-4/#principal-box), ignoring any
 [transforms](#transforms)
 that apply to the element and its ancestors.

 If the element's [principal
 box](https://drafts.csswg.org/css-display-4/#principal-box) is an [inline-level
 box](https://drafts.csswg.org/css-display-4/#inline-level-box) which was \"split\" by a
 [block-level](https://drafts.csswg.org/css-display-4/#block-level) descendant, also include fragments generated by the
 [block-level] descendants, unless they are
 zero width or height.

## [8. ][Extensions to the [`HTMLImageElement`](https://html.spec.whatwg.org/multipage/embedded-content.html#htmlimageelement) Interface]
```
partial interface HTMLImageElement {
 readonly attribute long x;
 readonly attribute long y;
};
```

The [`x`] attribute, on
getting, must return the
[scaled](https://drafts.csswg.org/css-viewport/#scaled) x-coordinate of the left [border
edge](https://drafts.csswg.org/css-box-4/#border-edge) of the first
[box](https://drafts.csswg.org/css-display-4/#box) associated with the element, relative to the [initial
containing
block](https://drafts.csswg.org/css-display-4/#initial-containing-block) origin, ignoring any
[transforms](#transforms) that
apply to the element and its ancestors, or zero if there is no
[box].

The [`y`] attribute, on
getting, must return the
[scaled](https://drafts.csswg.org/css-viewport/#scaled) y-coordinate of the top [border
edge](https://drafts.csswg.org/css-box-4/#border-edge) of the first
[box](https://drafts.csswg.org/css-display-4/#box) associated with the element, relative to the [initial
containing
block](https://drafts.csswg.org/css-display-4/#initial-containing-block) origin, ignoring any
[transforms](#transforms) that
apply to the element and its ancestors, or zero if there is no
[box].

Tests

- [cssom-view-img-attributes-001.html](https://wpt.fyi/results/css/cssom-view/cssom-view-img-attributes-001.html "css/cssom-view/cssom-view-img-attributes-001.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/cssom-view-img-attributes-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/cssom-view-img-attributes-001.html)
- [image-x-y-zoom.html](https://wpt.fyi/results/css/cssom-view/image-x-y-zoom.html "css/cssom-view/image-x-y-zoom.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/image-x-y-zoom.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/image-x-y-zoom.html)
- [HTMLImageElement-x-and-y-ignore-transforms.html](https://wpt.fyi/results/css/cssom-view/HTMLImageElement-x-and-y-ignore-transforms.html "css/cssom-view/HTMLImageElement-x-and-y-ignore-transforms.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/HTMLImageElement-x-and-y-ignore-transforms.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/HTMLImageElement-x-and-y-ignore-transforms.html)

## [9. ][Extensions to the [`Range`](https://dom.spec.whatwg.org/#range) Interface]
```
partial interface Range {
 DOMRectList getClientRects();
 [NewObject] DOMRect getBoundingClientRect();
};
```

The [`getClientRects()`] method, when
invoked, must return an empty
[`DOMRectList`](https://drafts.csswg.org/geometry-1/#domrectlist) object if the range is not in the document and
otherwise a
[`DOMRectList`](https://drafts.csswg.org/geometry-1/#domrectlist) object containing a list of
[`DOMRect`](https://drafts.csswg.org/geometry-1/#domrect) objects in content order that matches the following
constraints:

- For each element selected by the range, whose parent is not selected
 by the range, include the border areas returned by invoking
 [`getClientRects()`](#dom-element-getclientrects) on the element.

- For each
 [`Text`](https://dom.spec.whatwg.org/#text) node selected or partially selected by the range
 (including when the boundary-points are identical), include
 [scaled](https://drafts.csswg.org/css-viewport/#scaled)
 [`DOMRect`](https://drafts.csswg.org/geometry-1/#domrect) object (for the part that is selected, not the whole
 line box). The bounds of these
 [`DOMRect`](https://drafts.csswg.org/geometry-1/#domrect) objects are computed using font metrics; thus, for
 horizontal writing, the vertical dimension of each box is determined
 by the font ascent and descent, and the horizontal dimension by the
 text advance width. If the range covers a partial [typographic
 character
 unit](https://drafts.csswg.org/css-text-4/#typographic-character-unit) (e.g. half a surrogate pair or part of a grapheme
 cluster), the full [typographic character
 unit] must be included for the
 purpose of computing the bounds of the relevant
 [`DOMRect`](https://drafts.csswg.org/geometry-1/#domrect).
 [\[CSS-TEXT-3\]](#biblio-css-text-3 "CSS Text Module Level 3")
 The [transforms](#transforms)
 that apply to the ancestors are applied.

 The
[`DOMRect`](https://drafts.csswg.org/geometry-1/#domrect) objects returned by
[`getClientRects()`](#dom-range-getclientrects) are not
[live](https://html.spec.whatwg.org/multipage/infrastructure.html#live).

Tests

- [range-bounding-client-rect-with-nested-text.html](https://wpt.fyi/results/css/cssom-view/range-bounding-client-rect-with-nested-text.html "css/cssom-view/range-bounding-client-rect-with-nested-text.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/range-bounding-client-rect-with-nested-text.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/range-bounding-client-rect-with-nested-text.html)
- [range-client-rects-surrogate-indexing.html](https://wpt.fyi/results/css/cssom-view/range-client-rects-surrogate-indexing.html "css/cssom-view/range-client-rects-surrogate-indexing.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/range-client-rects-surrogate-indexing.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/range-client-rects-surrogate-indexing.html)

The [`getBoundingClientRect()`]
method, when invoked, must return the result of the following algorithm:

1. Let `list` be the result of invoking
 [`getClientRects()`](#dom-range-getclientrects) on the same range this method was invoked on.

2. If `list` is empty return a
 [`DOMRect`](https://drafts.csswg.org/geometry-1/#domrect) object whose
 [`x`](https://drafts.csswg.org/geometry-1/#dom-domrect-x),
 [`y`](https://drafts.csswg.org/geometry-1/#dom-domrect-y),
 [`width`](https://drafts.csswg.org/geometry-1/#dom-domrect-width) and
 [`height`](https://drafts.csswg.org/geometry-1/#dom-domrect-height) members are zero.

3. If all rectangles in `list` have zero width or height,
 return the first rectangle in `list`.

4. Otherwise, return a
 [`DOMRect`](https://drafts.csswg.org/geometry-1/#domrect) object describing the smallest rectangle that
 includes all of the rectangles in `list` of which the
 height or width is not zero.

 The
[`DOMRect`](https://drafts.csswg.org/geometry-1/#domrect) object returned by
[`getBoundingClientRect()`](#dom-range-getboundingclientrect) is not
[live](https://html.spec.whatwg.org/multipage/infrastructure.html#live).

Tests

- [range-bounding-client-rect-with-display-contents.html](https://wpt.fyi/results/css/cssom-view/range-bounding-client-rect-with-display-contents.html "css/cssom-view/range-bounding-client-rect-with-display-contents.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/range-bounding-client-rect-with-display-contents.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/range-bounding-client-rect-with-display-contents.html)

## [10. ][Extensions to the [`MouseEvent`](https://w3c.github.io/pointerevents/#dom-mouseevent) Interface]
The object IDL fragment redefines some
members. Can we resolve this somehow?

```
partial interface MouseEvent {
 readonly attribute double screenX;
 readonly attribute double screenY;
 readonly attribute double pageX;
 readonly attribute double pageY;
 readonly attribute double clientX;
 readonly attribute double clientY;
 readonly attribute double x;
 readonly attribute double y;
 readonly attribute double offsetX;
 readonly attribute double offsetY;
};

partial dictionary MouseEventInit {
 double screenX = 0.0;
 double screenY = 0.0;
 double clientX = 0.0;
 double clientY = 0.0;
};
```

Tests

- [mouseEvent.html](https://wpt.fyi/results/css/cssom-view/mouseEvent.html "css/cssom-view/mouseEvent.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/mouseEvent.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/mouseEvent.html)

The [`screenX`] attribute must
return the x-coordinate of the position where the event occurred
relative to the origin of the [Web-exposed screen
area](#web-exposed-screen-area).

The [`screenY`] attribute must
return the y-coordinate of the position where the event occurred
relative to the origin of the [Web-exposed screen
area](#web-exposed-screen-area).

The [`pageX`] attribute must
follow these steps:

1. If the event's [dispatch
 flag](https://dom.spec.whatwg.org/#dispatch-flag) is set, return the horizontal coordinate of the
 position where the event occurred relative to the origin of the
 [initial containing
 block](https://drafts.csswg.org/css-display-4/#initial-containing-block) and terminate these steps.

2. Let `offset` be the value of the
 [`scrollX`](#dom-window-scrollx) attribute of the event's associated
 [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window) object, if there is one, or zero otherwise.

3. Return the sum of `offset` and the value of the event's
 [`clientX`](#dom-mouseevent-clientx) attribute.

The [`pageY`] attribute must
follow these steps:

1. If the event's [dispatch
 flag](https://dom.spec.whatwg.org/#dispatch-flag) is set, return the vertical coordinate of the
 position where the event occurred relative to the origin of the
 [initial containing
 block](https://drafts.csswg.org/css-display-4/#initial-containing-block) and terminate these steps.

2. Let `offset` be the value of the
 [`scrollY`](#dom-window-scrolly) attribute of the event's associated
 [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window) object, if there is one, or zero otherwise.

3. Return the sum of `offset` and the value of the event's
 [`clientY`](#dom-mouseevent-clienty) attribute.

The [`clientX`] attribute must
return the x-coordinate of the position where the event occurred
relative to the origin of the
[viewport](https://drafts.csswg.org/css2/#viewport%E2%91%A0).

The [`clientY`] attribute must
return the y-coordinate of the position where the event occurred
relative to the origin of the
[viewport](https://drafts.csswg.org/css2/#viewport%E2%91%A0).

The [`x`] attribute must
return the value of
[`clientX`](#dom-mouseevent-clientx).

The [`y`] attribute must
return the value of
[`clientY`](#dom-mouseevent-clienty).

The [`offsetX`] attribute must
follow these steps:

1. If the event's [dispatch
 flag](https://dom.spec.whatwg.org/#dispatch-flag) is set, return the x-coordinate of the position
 where the event occurred relative to the origin of the [padding
 edge](https://drafts.csswg.org/css-box-4/#padding-edge) of the target node, ignoring the
 [transforms](#transforms)
 that apply to the element and its ancestors, and terminate these
 steps.

2. Return the value of the event's
 [`pageX`](#dom-mouseevent-pagex) attribute.

Tests

- [mouseEvent-offsetXY-svg.html](https://wpt.fyi/results/css/cssom-view/mouseEvent-offsetXY-svg.html "css/cssom-view/mouseEvent-offsetXY-svg.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/mouseEvent-offsetXY-svg.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/mouseEvent-offsetXY-svg.html)

The [`offsetY`] attribute must
follow these steps:

1. If the event's [dispatch
 flag](https://dom.spec.whatwg.org/#dispatch-flag) is set, return the y-coordinate of the position
 where the event occurred relative to the origin of the [padding
 edge](https://drafts.csswg.org/css-box-4/#padding-edge) of the target node, ignoring the
 [transforms](#transforms)
 that apply to the element and its ancestors, and terminate these
 steps.

2. Return the value of the event's
 [`pageY`](#dom-mouseevent-pagey) attribute.

## 11. Geometry

### 11.1. The [`GeometryUtils` Interface]
```
enum CSSBoxType { "margin", "border", "padding", "content" };
dictionary BoxQuadOptions {
 CSSBoxType box = "border";
 GeometryNode relativeTo;
};

dictionary ConvertCoordinateOptions {
 CSSBoxType fromBox = "border";
 CSSBoxType toBox = "border";
};

interface mixin GeometryUtils {
 sequence<DOMQuad> getBoxQuads(optional BoxQuadOptions options = );
 DOMQuad convertQuadFromNode(DOMQuadInit quad, GeometryNode from, optional ConvertCoordinateOptions options = );
 DOMQuad convertRectFromNode(DOMRectReadOnly rect, GeometryNode from, optional ConvertCoordinateOptions options = );
 DOMPoint convertPointFromNode(DOMPointInit point, GeometryNode from, optional ConvertCoordinateOptions options = );
};

Text includes GeometryUtils; // like Range
Element includes GeometryUtils;
CSSPseudoElement includes GeometryUtils;
Document includes GeometryUtils;

typedef (Text or Element or CSSPseudoElement or Document) GeometryNode;
```

The [`GeometryUtils`](#geometryutils) methods operate on a node's local box geometry. The
[`getBoxQuads()`](#dom-geometryutils-getboxquads) method returns one
[`DOMQuad`](https://drafts.csswg.org/geometry-1/#domquad) per relevant box fragment, in [flat
tree](https://drafts.csswg.org/css-shadow-1/#flat-tree) order. Unless
[`relativeTo`](#dom-boxquadoptions-relativeto) is specified, the returned coordinates are expressed
relative to the [layout
viewport](https://drafts.csswg.org/css-viewport/#layout-viewport).

For the purpose of the
[`GeometryUtils`](#geometryutils) methods, the [associated
document] of a
[`Document`](https://dom.spec.whatwg.org/#document) is itself, the associated document of a
[`CSSPseudoElement`](https://drafts.csswg.org/css-pseudo-4/#csspseudoelement) is its
[`element`](https://drafts.csswg.org/css-pseudo-4/#dom-csspseudoelement-element)'s [node
document](https://dom.spec.whatwg.org/#concept-node-document), and the associated document of any other
[`GeometryNode`](#typedefdef-geometrynode) is its [node
document].

To [check the documents for coordinate
conversion] given two
[`GeometryNode`](#typedefdef-geometrynode)s `node` and `from`:

1. Let `nodeDocuments` be a
 [list](https://infra.spec.whatwg.org/#list) containing `node`'s [associated
 document](#geometryutils-associated-document). While the last document in
 `nodeDocuments` has a [container
 document](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-container-document), append that container document to
 `nodeDocuments`.

2. Let `fromDocuments` be a
 [list](https://infra.spec.whatwg.org/#list) constructed in the same way for `from`.

3. Let `documents` contain the shortest prefixes of
 `nodeDocuments` and `fromDocuments` that end
 with a document common to both lists. If there is no such document,
 let `documents` contain only the first item of each list.

4. If any document in `documents` is not [same
 origin](https://html.spec.whatwg.org/multipage/browsers.html#same-origin) with the [associated
 document](#geometryutils-associated-document) of `node`, then throw a
 [`SecurityError`](https://webidl.spec.whatwg.org/#securityerror).

For a
[`CSSPseudoElement`](https://drafts.csswg.org/css-pseudo-4/#csspseudoelement), the
[`GeometryUtils`](#geometryutils) methods operate on the boxes generated by the
pseudo-element itself. This includes the boxes of generated content
pseudo-elements such as
[::before](https://drafts.csswg.org/css-pseudo-4/#selectordef-before) and
[::after](https://drafts.csswg.org/css-pseudo-4/#selectordef-after), including when those boxes are out-of-flow, for
example due to absolute positioning. If the
[`CSSPseudoElement`](https://drafts.csswg.org/css-pseudo-4/#csspseudoelement) is a
[sub-pseudo-element](https://drafts.csswg.org/selectors-4/#sub-pseudo-element), the methods operate on the sub-pseudo-element's own
boxes and fragments. If the pseudo-element generates no boxes,
[`getBoxQuads()`](#dom-geometryutils-getboxquads) returns an empty list.

To [get the complete transform] of a
[`GeometryNode`](#typedefdef-geometrynode) `node` relative to a
[`GeometryNode`](#typedefdef-geometrynode) `ancestor`, run the following steps:

1. Let `current` be `node`.

2. Let `transformationMatrix` be a new
 [`DOMMatrix`](https://drafts.csswg.org/geometry-1/#dommatrix).

3. While `current` is not null:

 1. If `current` is `ancestor`, return
 `transformationMatrix`.

 2. Let `nextAncestor` be null.

 3. If `current` is an
 [`Element`](https://dom.spec.whatwg.org/#element), then:

 1. Let `currentTransformationMatrix` be a new
 [`DOMMatrix`](https://drafts.csswg.org/geometry-1/#dommatrix) representing the [current transformation
 matrix](https://drafts.csswg.org/css-transforms-1/#current-transformation-matrix) of `current`.
 [\[CSS-TRANSFORMS-1\]](#biblio-css-transforms-1 "CSS Transforms Module Level 1")

 2. Set `transformationMatrix` to the result of
 multiplying `currentTransformationMatrix` by
 `transformationMatrix`.

 3. If there is an element that establishes the [containing
 block](https://drafts.csswg.org/css-display-4/#containing-block) of `current`, let
 `nextAncestor` be that element. Otherwise, let
 `nextAncestor` be `current`'s [node
 document](https://dom.spec.whatwg.org/#concept-node-document).

 4. If `nextAncestor` is a
 [`Document`](https://dom.spec.whatwg.org/#document), let `offsetX` be the horizontal
 offset and `offsetY` be the vertical offset from
 the [border
 edge](https://drafts.csswg.org/css-box-4/#border-edge) of `current` to the origin of
 the [initial containing
 block](https://drafts.csswg.org/css-display-4/#initial-containing-block), ignoring any
 [transforms](#transforms) that apply to `current` and its
 ancestors. Otherwise, let `offsetX` be the
 horizontal offset and `offsetY` be the vertical
 offset from the [border edge] of
 `current` to the [border
 edge] of `nextAncestor`,
 ignoring any [transforms] that apply
 to `current` and its ancestors.

 5. Let `translationMatrix` be a new
 [`DOMMatrix`](https://drafts.csswg.org/geometry-1/#dommatrix) representing a translation by
 `offsetX` and `offsetY`.

 6. Set `transformationMatrix` to the result of
 multiplying `translationMatrix` by
 `transformationMatrix`.

 4. Otherwise, if `current` is a
 [`Text`](https://dom.spec.whatwg.org/#text), set `nextAncestor` to
 `current`'s [parent
 element](https://dom.spec.whatwg.org/#parent-element).

 5. Otherwise, if `current` is a
 [`CSSPseudoElement`](https://drafts.csswg.org/css-pseudo-4/#csspseudoelement), set `nextAncestor` to
 `current`'s
 [`parent`](https://drafts.csswg.org/css-pseudo-4/#dom-csspseudoelement-parent).

 6. Set `current` to `nextAncestor`.

4. Return `transformationMatrix`.

To [adjust a point to the border box] given a
[`DOMPoint`](https://drafts.csswg.org/geometry-1/#dompoint) `point`, a
[`GeometryNode`](#typedefdef-geometrynode) `node`, and a
[`CSSBoxType`](#enumdef-cssboxtype) `box`, run the following steps:

1. Let `adjustedPoint` be a new
 [`DOMPoint`](https://drafts.csswg.org/geometry-1/#dompoint) with the same
 [`x`](https://drafts.csswg.org/geometry-1/#dom-dompointreadonly-x) and
 [`y`](https://drafts.csswg.org/geometry-1/#dom-dompointreadonly-y) as `point`.

2. If `node` is a
 [`Document`](https://dom.spec.whatwg.org/#document) or a
 [`Text`](https://dom.spec.whatwg.org/#text), return `adjustedPoint`.

3. If `box` is
 [`"margin"`](#dom-cssboxtype-margin), adjust `adjustedPoint` so that it
 refers to the same physical point in `node`'s local
 coordinate space, but with coordinates measured from the top-left
 corner of `node`'s [border
 box](https://drafts.csswg.org/css-box-4/#border-box) rather than the top-left corner of its [margin
 box](https://drafts.csswg.org/css-box-4/#margin-box).

4. If `box` is
 [`"padding"`](#dom-cssboxtype-padding), adjust `adjustedPoint` so that it
 refers to the same physical point in `node`'s local
 coordinate space, but with coordinates measured from the top-left
 corner of `node`'s [border
 box](https://drafts.csswg.org/css-box-4/#border-box) rather than the top-left corner of its [padding
 box](https://drafts.csswg.org/css-box-4/#padding-box).

5. If `box` is
 [`"content"`](#dom-cssboxtype-content), adjust `adjustedPoint` so that it
 refers to the same physical point in `node`'s local
 coordinate space, but with coordinates measured from the top-left
 corner of `node`'s [border
 box](https://drafts.csswg.org/css-box-4/#border-box) rather than the top-left corner of its [content
 box](https://drafts.csswg.org/css-box-4/#content-box).

6. Return `adjustedPoint`.

To [adjust a point from the border
box] given a
[`DOMPoint`](https://drafts.csswg.org/geometry-1/#dompoint) `point`, a
[`GeometryNode`](#typedefdef-geometrynode) `node`, and a
[`CSSBoxType`](#enumdef-cssboxtype) `box`, run the following steps:

1. Let `adjustedPoint` be a new
 [`DOMPoint`](https://drafts.csswg.org/geometry-1/#dompoint) with the same
 [`x`](https://drafts.csswg.org/geometry-1/#dom-dompointreadonly-x) and
 [`y`](https://drafts.csswg.org/geometry-1/#dom-dompointreadonly-y) as `point`.

2. If `node` is a
 [`Document`](https://dom.spec.whatwg.org/#document) or a
 [`Text`](https://dom.spec.whatwg.org/#text), return `adjustedPoint`.

3. If `box` is
 [`"margin"`](#dom-cssboxtype-margin), adjust `adjustedPoint` so that it
 refers to the same physical point in `node`'s local
 coordinate space, but with coordinates measured from the top-left
 corner of `node`'s [margin
 box](https://drafts.csswg.org/css-box-4/#margin-box) rather than the top-left corner of its [border
 box](https://drafts.csswg.org/css-box-4/#border-box).

4. If `box` is
 [`"padding"`](#dom-cssboxtype-padding), adjust `adjustedPoint` so that it
 refers to the same physical point in `node`'s local
 coordinate space, but with coordinates measured from the top-left
 corner of `node`'s [padding
 box](https://drafts.csswg.org/css-box-4/#padding-box) rather than the top-left corner of its [border
 box](https://drafts.csswg.org/css-box-4/#border-box).

5. If `box` is
 [`"content"`](#dom-cssboxtype-content), adjust `adjustedPoint` so that it
 refers to the same physical point in `node`'s local
 coordinate space, but with coordinates measured from the top-left
 corner of `node`'s [content
 box](https://drafts.csswg.org/css-box-4/#content-box) rather than the top-left corner of its [border
 box](https://drafts.csswg.org/css-box-4/#border-box).

6. Return `adjustedPoint`.

[`getBoxQuads(``options``)`] method must run the
following steps:

1. Let `node` be
 [this](https://webidl.spec.whatwg.org/#this).

2. If `node` is a
 [`Document`](https://dom.spec.whatwg.org/#document), let `document` be `node`.

3. Otherwise, if `node` is a
 [`CSSPseudoElement`](https://drafts.csswg.org/css-pseudo-4/#csspseudoelement), let `document` be `node`'s
 [`element`](https://drafts.csswg.org/css-pseudo-4/#dom-csspseudoelement-element)'s [node
 document](https://dom.spec.whatwg.org/#concept-node-document).

4. Otherwise, let `document` be `node`'s [node
 document](https://dom.spec.whatwg.org/#concept-node-document).

5. If
 `options`.[`relativeTo`](#dom-boxquadoptions-relativeto) is specified, let `relativeTo` be
 `options`.[`relativeTo`](#dom-boxquadoptions-relativeto). Otherwise, let `relativeTo` be
 `document`.

6. Let `result` be an empty
 [list](https://tc39.es/ecma262/multipage/ecmascript-data-types-and-values.html#sec-list-and-record-specification-type) of
 [`DOMQuad`](https://drafts.csswg.org/geometry-1/#domquad) objects.

7. If `node` is a
 [`Document`](https://dom.spec.whatwg.org/#document), then:

 1. Let `rect` be a
 [`DOMRect`](https://drafts.csswg.org/geometry-1/#domrect) whose
 [`x`](https://drafts.csswg.org/geometry-1/#dom-domrect-x) and
 [`y`](https://drafts.csswg.org/geometry-1/#dom-domrect-y) are 0, and whose
 [`width`](https://drafts.csswg.org/geometry-1/#dom-domrect-width) and
 [`height`](https://drafts.csswg.org/geometry-1/#dom-domrect-height) are the width and height of the [layout
 viewport](https://drafts.csswg.org/css-viewport/#layout-viewport).

 2. Let `quad` be the result of invoking
 [`fromRect()`](https://drafts.csswg.org/geometry-1/#dom-domquad-fromrect) with `rect`.

 3. [Append](https://infra.spec.whatwg.org/#list-append) the result of invoking the
 [`convertQuadFromNode()`](#dom-geometryutils-convertquadfromnode) method on `relativeTo` with
 `quad` and `document` to
 `result`.

8. Otherwise, if `node` is a
 [`Text`](https://dom.spec.whatwg.org/#text), then:

 1. For each
 [`DOMRect`](https://drafts.csswg.org/geometry-1/#domrect) `rect` returned by invoking the
 [`getClientRects()`](#dom-range-getclientrects) method on a
 [`Range`](https://dom.spec.whatwg.org/#range) whose boundary-points select exactly
 `node`, in content order:

 1. Let `quad` be the result of invoking
 [`fromRect()`](https://drafts.csswg.org/geometry-1/#dom-domquad-fromrect) with `rect`.

 2. [Append](https://infra.spec.whatwg.org/#list-append) the result of invoking the
 [`convertQuadFromNode()`](#dom-geometryutils-convertquadfromnode) method on `relativeTo` with
 `quad` and `document` to
 `result`.

9. Otherwise, for each [box
 fragment](https://drafts.csswg.org/css-break-4/#box-fragment) of `node`, in [flat
 tree](https://drafts.csswg.org/css-shadow-1/#flat-tree) order, run the following steps:

 1. Let `rect` be a
 [`DOMRect`](https://drafts.csswg.org/geometry-1/#domrect) describing the [border
 area](https://drafts.csswg.org/css-box-4/#border-area) of the [box
 fragment](https://drafts.csswg.org/css-break-4/#box-fragment), positioned in the fragment's local coordinate
 space with its [border
 edge](https://drafts.csswg.org/css-box-4/#border-edge) at
 [`x`](https://drafts.csswg.org/geometry-1/#dom-domrect-x) = 0 and
 [`y`](https://drafts.csswg.org/geometry-1/#dom-domrect-y) = 0.

 2. If
 `options`.[`box`](#dom-boxquadoptions-box) is
 [`"margin"`](#dom-cssboxtype-margin), let `rect` instead be a
 [`DOMRect`](https://drafts.csswg.org/geometry-1/#domrect) describing the fragment's [margin
 area](https://drafts.csswg.org/css-box-4/#margin-area) in the same local coordinate space, with the
 fragment's [border
 edge](https://drafts.csswg.org/css-box-4/#border-edge) still at
 [`x`](https://drafts.csswg.org/geometry-1/#dom-domrect-x) = 0 and
 [`y`](https://drafts.csswg.org/geometry-1/#dom-domrect-y) = 0.

 3. If
 `options`.[`box`](#dom-boxquadoptions-box) is
 [`"padding"`](#dom-cssboxtype-padding), let `rect` instead be a
 [`DOMRect`](https://drafts.csswg.org/geometry-1/#domrect) describing the fragment's [padding
 area](https://drafts.csswg.org/css-box-4/#padding-area) in the same local coordinate space, with the
 fragment's [border
 edge](https://drafts.csswg.org/css-box-4/#border-edge) still at
 [`x`](https://drafts.csswg.org/geometry-1/#dom-domrect-x) = 0 and
 [`y`](https://drafts.csswg.org/geometry-1/#dom-domrect-y) = 0.

 4. If
 `options`.[`box`](#dom-boxquadoptions-box) is
 [`"content"`](#dom-cssboxtype-content), let `rect` instead be a
 [`DOMRect`](https://drafts.csswg.org/geometry-1/#domrect) describing the fragment's [content
 area](https://drafts.csswg.org/css-box-4/#content-area) in the same local coordinate space, with the
 fragment's [border
 edge](https://drafts.csswg.org/css-box-4/#border-edge) still at
 [`x`](https://drafts.csswg.org/geometry-1/#dom-domrect-x) = 0 and
 [`y`](https://drafts.csswg.org/geometry-1/#dom-domrect-y) = 0.

 5. Let `quad` be the result of invoking
 [`fromRect()`](https://drafts.csswg.org/geometry-1/#dom-domquad-fromrect) with `rect`.

 6. [Append](https://infra.spec.whatwg.org/#list-append) the result of invoking the
 [`convertQuadFromNode()`](#dom-geometryutils-convertquadfromnode) method on `relativeTo` with
 `quad` and `node` to `result`.

10. Return `result`.

 The points are flattened (3D transforms project to
 z=0), similar to
 [`getClientRects()`](#dom-element-getclientrects).
 [`p1`](https://drafts.csswg.org/geometry-1/#dom-domquad-p1) is always the physical top-left corner of the box,
 even in right-to-left writing modes. For
 [`Document`](https://dom.spec.whatwg.org/#document) and
 [`Text`](https://dom.spec.whatwg.org/#text) nodes, all four values of
 [`box`](#dom-boxquadoptions-box) return the same geometry. If a transformation
 matrix is not invertible (e.g. due to a
 [scale()](https://drafts.csswg.org/css-transforms-1/#funcdef-transform-scale) of 0), the resulting coordinates are
 implementation-defined.

Tests

- [cssom-getBoxQuads-001.html](https://wpt.fyi/results/css/cssom-view/cssom-getBoxQuads-001.html "css/cssom-view/cssom-getBoxQuads-001.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/cssom-getBoxQuads-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/cssom-getBoxQuads-001.html)
- [cssom-getBoxQuads-002.html](https://wpt.fyi/results/css/cssom-view/cssom-getBoxQuads-002.html "css/cssom-view/cssom-getBoxQuads-002.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/cssom-getBoxQuads-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/cssom-getBoxQuads-002.html)

The
[`convertQuadFromNode(``quad``, ``from``, ``options``)`]
method must run the following steps:

1. Let `node` be
 [this](https://webidl.spec.whatwg.org/#this).

2. Let `convertedQuad` be the result of invoking
 [`fromQuad()`](https://drafts.csswg.org/geometry-1/#dom-domquad-fromquad) with `quad`.

3. Let `p1` be the result of invoking
 [`convertPointFromNode()`](#dom-geometryutils-convertpointfromnode) on `node` with
 `convertedQuad`.[`p1`](https://drafts.csswg.org/geometry-1/#dom-domquad-p1), `from`, and `options`.

4. Let `p2` be the result of invoking
 [`convertPointFromNode()`](#dom-geometryutils-convertpointfromnode) on `node` with
 `convertedQuad`.[`p2`](https://drafts.csswg.org/geometry-1/#dom-domquad-p2), `from`, and `options`.

5. Let `p3` be the result of invoking
 [`convertPointFromNode()`](#dom-geometryutils-convertpointfromnode) on `node` with
 `convertedQuad`.[`p3`](https://drafts.csswg.org/geometry-1/#dom-domquad-p3), `from`, and `options`.

6. Let `p4` be the result of invoking
 [`convertPointFromNode()`](#dom-geometryutils-convertpointfromnode) on `node` with
 `convertedQuad`.[`p4`](https://drafts.csswg.org/geometry-1/#dom-domquad-p4), `from`, and `options`.

7. Return a new
 [`DOMQuad`](https://drafts.csswg.org/geometry-1/#domquad) with `p1`, `p2`,
 `p3`, and `p4`.

The
[`convertRectFromNode(``rect``, ``from``, ``options``)`]
method must run the following steps:

1. Let `node` be
 [this](https://webidl.spec.whatwg.org/#this).

2. Let `quad` be the result of invoking
 [`fromRect()`](https://drafts.csswg.org/geometry-1/#dom-domquad-fromrect) with `rect`.

3. Return the result of invoking
 [`convertQuadFromNode()`](#dom-geometryutils-convertquadfromnode) on `node` with `quad`,
 `from`, and `options`.

The
[`convertPointFromNode(``point``, ``from``, ``options``)`]
method returns a point flattened to 2D and must run the following steps,
ignoring the
[`z`](https://drafts.csswg.org/geometry-1/#dom-dompointinit-z) and
[`w`](https://drafts.csswg.org/geometry-1/#dom-dompointinit-w) members of `point`:

1. Let `node` be
 [this](https://webidl.spec.whatwg.org/#this).

2. [Check the documents for coordinate
 conversion](#check-the-documents-for-coordinate-conversion) given `node` and `from`.

3. Let `thisTransformToViewport` be the result of [getting
 the complete
 transform](#get-the-complete-transform) of `node` relative to null.

4. Let `fromTransformToViewport` be the result of [getting
 the complete
 transform](#get-the-complete-transform) of `from` relative to null.

5. Let `adjustedPoint` be the result of [adjusting a point
 to the border
 box](#adjust-a-point-to-the-border-box) given `point`, `from`, and
 `options`.[`fromBox`](#dom-convertcoordinateoptions-frombox).

6. Set `adjustedPoint` to the result of transforming
 `adjustedPoint` by `fromTransformToViewport`.

7. Set `adjustedPoint` to the result of transforming
 `adjustedPoint` by the inverse of
 `thisTransformToViewport`.

8. Return the result of [adjusting a point from the border
 box](#adjust-a-point-from-the-border-box) given `adjustedPoint`,
 `node`, and
 `options`.[`toBox`](#dom-convertcoordinateoptions-tobox).

## 12. VisualViewport

### 12.1. The [`VisualViewport` Interface]
```
[Exposed=Window]
interface VisualViewport : EventTarget {
 readonly attribute double offsetLeft;
 readonly attribute double offsetTop;

 readonly attribute double pageLeft;
 readonly attribute double pageTop;

 readonly attribute double width;
 readonly attribute double height;

 readonly attribute double scale;

 attribute EventHandler onresize;
 attribute EventHandler onscroll;
 attribute EventHandler onscrollend;
};
```

The [`offsetLeft`]
attribute must run these steps:

1. If the [visual
 viewport](https://drafts.csswg.org/css-viewport/#visual-viewport)'s [associated document] is not [fully
 active](https://html.spec.whatwg.org/multipage/document-sequences.html#fully-active), return 0.

2. Otherwise, return the offset of the left edge of the [visual
 viewport](https://drafts.csswg.org/css-viewport/#visual-viewport) from the left edge of the [layout
 viewport](https://drafts.csswg.org/css-viewport/#layout-viewport).

The [`offsetTop`]
attribute must run these steps:

1. If the [visual
 viewport](https://drafts.csswg.org/css-viewport/#visual-viewport)'s [associated document] is not [fully
 active](https://html.spec.whatwg.org/multipage/document-sequences.html#fully-active), return 0.

2. Otherwise, return the offset of the top edge of the [visual
 viewport](https://drafts.csswg.org/css-viewport/#visual-viewport) from the top edge of the [layout
 viewport](https://drafts.csswg.org/css-viewport/#layout-viewport).

The [`pageLeft`]
attribute must run these steps:

1. If the [visual
 viewport](https://drafts.csswg.org/css-viewport/#visual-viewport)'s [associated document] is not [fully
 active](https://html.spec.whatwg.org/multipage/document-sequences.html#fully-active), return 0.

2. Otherwise, return the offset of the left edge of the [visual
 viewport](https://drafts.csswg.org/css-viewport/#visual-viewport) from the left edge of the [initial containing
 block](https://drafts.csswg.org/css-display-4/#initial-containing-block) of the [layout
 viewport](https://drafts.csswg.org/css-viewport/#layout-viewport)'s
 [document](https://dom.spec.whatwg.org/#concept-document).

The [`pageTop`] attribute must
run these steps:

1. If the [visual
 viewport](https://drafts.csswg.org/css-viewport/#visual-viewport)'s [associated document] is not [fully
 active](https://html.spec.whatwg.org/multipage/document-sequences.html#fully-active), return 0.

2. Otherwise, return the offset of the top edge of the [visual
 viewport](https://drafts.csswg.org/css-viewport/#visual-viewport) from the top edge of the [initial containing
 block](https://drafts.csswg.org/css-display-4/#initial-containing-block) of the [layout
 viewport](https://drafts.csswg.org/css-viewport/#layout-viewport)'s
 [document](https://dom.spec.whatwg.org/#concept-document).

The [`width`] attribute must
run these steps:

1. If the [visual
 viewport](https://drafts.csswg.org/css-viewport/#visual-viewport)'s [associated document] is not [fully
 active](https://html.spec.whatwg.org/multipage/document-sequences.html#fully-active), return 0.

2. Otherwise, return the width of the [visual
 viewport](https://drafts.csswg.org/css-viewport/#visual-viewport) excluding the width of any rendered vertical
 [classic
 scrollbar](https://drafts.csswg.org/css-overflow-3/#classic-scrollbars) that is fixed to the visual viewport.

 Since this value is returned in CSS pixels, the value
will decrease in magnitude if either [page
zoom](#page-zoom) or the [scale
factor](https://drafts.csswg.org/css-viewport/#scale-factor) is increased.

 A scrollbar that is fixed to the visual viewport is one
that does not change size or location as the visual viewport is zoomed
and panned. Because this value is in CSS pixels, when excluding the
scrollbar width the UA must account for how large the scrollbar is as
measured in CSS pixels. That is, the amount excluded decreases when
zooming in and increases when zooming out.

The [`height`] attribute must
run these steps:

1. If the [visual
 viewport](https://drafts.csswg.org/css-viewport/#visual-viewport)'s [associated document] is not [fully
 active](https://html.spec.whatwg.org/multipage/document-sequences.html#fully-active), return 0.

2. Otherwise, return the height of the [visual
 viewport](https://drafts.csswg.org/css-viewport/#visual-viewport) excluding the height of any rendered horizontal
 [classic
 scrollbar](https://drafts.csswg.org/css-overflow-3/#classic-scrollbars) that is fixed to the visual viewport.

The [`scale`] attribute must
run these steps:

1. If the [visual
 viewport](https://drafts.csswg.org/css-viewport/#visual-viewport)'s [associated document] is not [fully
 active](https://html.spec.whatwg.org/multipage/document-sequences.html#fully-active), return 0 and abort these steps.

2. If there is no output device, return 1 and abort these steps.

3. Otherwise, return the [visual
 viewport](https://drafts.csswg.org/css-viewport/#visual-viewport)'s [scale
 factor](https://drafts.csswg.org/css-viewport/#scale-factor).

[`onresize`] is the [event
handler IDL
attribute](https://html.spec.whatwg.org/multipage/webappapis.html#event-handler-idl-attributes) for the
[resize](#eventdef-window-resize) event.

[`onscroll`] is the [event
handler IDL
attribute](https://html.spec.whatwg.org/multipage/webappapis.html#event-handler-idl-attributes) for the
[scroll](#eventdef-document-scroll) event.

[`onscrollend`] is
the [event handler IDL
attribute](https://html.spec.whatwg.org/multipage/webappapis.html#event-handler-idl-attributes) for the
[scrollend](#eventdef-document-scrollend) event.

## 13. Events

### 13.1. Resizing viewports

This section integrates with the [event
loop](https://html.spec.whatwg.org/multipage/webappapis.html#event-loop) defined in HTML.
[\[HTML\]](#biblio-html "HTML Standard")

When asked to [run the resize steps] for a
[`Document`](https://dom.spec.whatwg.org/#document) `doc`, run these steps:

1. If `doc`'s
 [viewport](https://drafts.csswg.org/css2/#viewport%E2%91%A0) has had its width or height changed (e.g. as a
 result of the user resizing the browser window, or changing page
 zoom, or an `iframe` element's dimensions are changed) since the
 last time these steps were run, [fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire) named
 [resize](#eventdef-window-resize) at the
 [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window) object associated with `doc`.

2. If the
 [`VisualViewport`](#visualviewport) associated with `doc` has had its
 [scale](#dom-visualviewport-scale),
 [width](#dom-visualviewport-width), or
 [height](#dom-visualviewport-height) properties changed since the last
 time these steps were run, [fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire) named
 [resize](#eventdef-window-resize) at the
 [`VisualViewport`](#visualviewport).

Tests

- [resize-event-on-initial-layout-001.html](https://wpt.fyi/results/css/cssom-view/resize-event-on-initial-layout-001.html "css/cssom-view/resize-event-on-initial-layout-001.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/resize-event-on-initial-layout-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/resize-event-on-initial-layout-001.html)
- [resize-event-on-initial-layout-002.html](https://wpt.fyi/results/css/cssom-view/resize-event-on-initial-layout-002.html "css/cssom-view/resize-event-on-initial-layout-002.html")
 [[(live
 test)]](http://wpt.live/css/cssom-view/resize-event-on-initial-layout-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/cssom-view/resize-event-on-initial-layout-002.html)

### 13.2. Scrolling

This section integrates with the [event
loop](https://html.spec.whatwg.org/multipage/webappapis.html#event-loop) defined in HTML.
[\[HTML\]](#biblio-html "HTML Standard")

Each
[`Document`](https://dom.spec.whatwg.org/#document) has an associated list of [pending scroll
events], which stores pairs of
([`EventTarget`](https://dom.spec.whatwg.org/#eventtarget),
[`DOMString`](https://webidl.spec.whatwg.org/#idl-DOMString)), initially empty.

Whenever a
[viewport](https://drafts.csswg.org/css2/#viewport%E2%91%A0) gets scrolled (whether in response to user interaction
or by an API), the user agent must run these steps:

1. Let `doc` be the
 [viewport's](https://drafts.csswg.org/css2/#viewport%E2%91%A0) associated
 [`Document`](https://dom.spec.whatwg.org/#document).

2. If `doc` is a [snap
 container](https://drafts.csswg.org/css-scroll-snap-1/#scroll-snap-container), run the steps to [update scrollsnapchanging
 targets](https://drafts.csswg.org/css-scroll-snap-2/#document-update-scrollsnapchanging-targets) for `doc` with `doc`'s
 [eventual snap
 target](https://drafts.csswg.org/css-scroll-snap-2/#eventual-snap-target) in the block axis as newBlockTarget and
 `doc`'s [eventual snap
 target] in the inline axis as
 newInlineTarget.

3. If (`doc`, `"scroll"`) is already in `doc`'s
 [pending scroll
 events](#document-pending-scroll-events), abort these steps.

4. Append (`doc`, `"scroll"`) to `doc`'s [pending
 scroll
 events](#document-pending-scroll-events).

Whenever an element gets scrolled (whether in response to user
interaction or by an API), the user agent must run these steps:

1. Let `doc` be the element's [node
 document](https://dom.spec.whatwg.org/#concept-node-document).

2. If the element is a [snap
 container](https://drafts.csswg.org/css-scroll-snap-1/#scroll-snap-container), run the steps to [update scrollsnapchanging
 targets](https://drafts.csswg.org/css-scroll-snap-2/#document-update-scrollsnapchanging-targets) for the element with the element's [eventual snap
 target](https://drafts.csswg.org/css-scroll-snap-2/#eventual-snap-target) in the block axis as newBlockTarget and the
 element's [eventual snap target] in
 the inline axis as newInlineTarget.

3. If (`element`, `"scroll"`) is already in
 `doc`'s [pending scroll
 events](#document-pending-scroll-events), abort these steps.

4. Append (`element`, `"scroll"`) to `doc`'s
 [pending scroll
 events](#document-pending-scroll-events).

Whenever a [visual
viewport](https://drafts.csswg.org/css-viewport/#visual-viewport) gets scrolled (whether in response to user interaction
or by an API), the user agent must run these steps:

1. Let `vv` be the
 [`VisualViewport`](#visualviewport) object that was scrolled.

2. Let `doc` be `vv`'s [associated
 document].

3. If (`vv`, `"scroll"`) is already in `doc`'s
 [pending scroll
 events](#document-pending-scroll-events), abort these steps.

4. Append (`vv`, `"scroll"`) to `doc`'s [pending
 scroll
 events](#document-pending-scroll-events).

When asked to [run the scroll steps] for a
[`Document`](https://dom.spec.whatwg.org/#document) `doc`, run these steps:

In what order are scrollend events
dispatched? Ordered based on scroll start or scroll completion?

1. For each scrolling box `box` that was scrolled:

 1. If `box` belongs to a
 [viewport](https://drafts.csswg.org/css2/#viewport%E2%91%A0), let `doc` be the
 [viewport's] associated
 [`Document`](https://dom.spec.whatwg.org/#document) and `target` be the
 [viewport]. If `box`
 belongs to a
 [`VisualViewport`](#visualviewport), let `doc` be the
 [`VisualViewport`](#visualviewport)'s [associated document] and
 `target` be the
 [`VisualViewport`](#visualviewport). Otherwise, `box` belongs to an
 element and let `doc` be the element's [node
 document](https://dom.spec.whatwg.org/#concept-node-document) and `target` be the element.

 2. If `box` belongs to a [snap
 container](https://drafts.csswg.org/css-scroll-snap-1/#scroll-snap-container), `snapcontainer`, run the [update
 scrollsnapchange
 targets](https://drafts.csswg.org/css-scroll-snap-2/#document-update-scrollsnapchange-targets) steps for `snapcontainer`.

 3. If (`target`, `"scrollend"`) is already in
 `doc`'s [pending scroll
 events](#document-pending-scroll-events), abort these steps.

 4. Append (`target`, `"scrollend"`) to
 `doc`'s [pending scroll
 events](#document-pending-scroll-events).

2. For each item (`target`, `type`) in
 `doc`'s [pending scroll
 events](#document-pending-scroll-events), in the order they were added to the list, run
 these substeps:

 1. If `target` is a
 [`Document`](https://dom.spec.whatwg.org/#document), and `type` is `"scroll"` or
 `"scrollend"`, [fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire) named `type` that bubbles at
 `target`.

 2. Otherwise, if `type` is `"scrollsnapchange"`, then:

 1. Let `blockTarget` and `inlineTarget`
 be null initially.

 2. If the
 [scrollsnapchangeTargetBlock](https://drafts.csswg.org/css-scroll-snap-2/#scrollsnapchangetargetblock) associated with `target` is a
 pseudo-element, set `blockTarget` to the owning
 element of that
 [scrollsnapchangeTargetBlock].

 3. Otherwise, set `blockTarget` to that
 [scrollsnapchangeTargetBlock](https://drafts.csswg.org/css-scroll-snap-2/#scrollsnapchangetargetblock).

 4. If the
 [scrollsnapchangeTargetInline](https://drafts.csswg.org/css-scroll-snap-2/#scrollsnapchangetargetinline) associated with `target` is a
 pseudo-element, set `inlineTarget` to the owning
 element of that
 [scrollsnapchangeTargetInline].

 5. Otherwise, Set `inlineTarget` to that
 [scrollsnapchangeTargetInline](https://drafts.csswg.org/css-scroll-snap-2/#scrollsnapchangetargetinline).

 6. Fire a
 [`SnapEvent`](https://drafts.csswg.org/css-scroll-snap-2/#snapevent), `snapevent`, named
 [`scrollsnapchange`](https://drafts.csswg.org/css-scroll-snap-2/#eventdef-snapevent-scrollsnapchange) at `target` and let
 `snapevent`'s
 [`snapTargetBlock`](https://drafts.csswg.org/css-scroll-snap-2/#dom-snapevent-snaptargetblock) and
 [`snapTargetInline`](https://drafts.csswg.org/css-scroll-snap-2/#dom-snapevent-snaptargetinline) attributes be `blockTarget` and
 `inlineTarget` respectively.

 3. Otherwise, if `type` is `"scrollsnapchanging"`, then:

 1. Let `blockTarget` and `inlineTarget`
 be null initially.

 2. If the [scrollsnapchanging block-axis target]
 associated with `target` is a pseudo-element, set
 `blockTarget` to the owning element of that
 [scrollsnapchanging block-axis target].

 3. Otherwise, set `blockTarget` to that
 [scrollsnapchanging block-axis target].

 4. If the [scrollsnapchanging inline-axis target]
 associated with `target` is a pseudo-element, set
 `inlineTarget` to the owning element of that
 [scrollsnapchanging inline-axis target].

 5. Otherwise, set `inlineTarget` to that
 [scrollsnapchanging inline-axis target].

 6. Fire a
 [`SnapEvent`](https://drafts.csswg.org/css-scroll-snap-2/#snapevent), `snapevent`, named
 [`scrollsnapchanging`](https://drafts.csswg.org/css-scroll-snap-2/#eventdef-snapevent-scrollsnapchanging) at `target` and let
 `snapevent`'s
 [`snapTargetBlock`](https://drafts.csswg.org/css-scroll-snap-2/#dom-snapevent-snaptargetblock) and
 [`snapTargetInline`](https://drafts.csswg.org/css-scroll-snap-2/#dom-snapevent-snaptargetinline) attributes be `blockTarget` and
 `inlineTarget`, respectively.

 4. Otherwise, [fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire) named `type` at `target`.

3. Empty `doc`'s [pending scroll
 events](#document-pending-scroll-events).

### 13.3. Event summary

*This section is non-normative.*

Event

Interface

Interesting targets

Description

[`resize`]

[`Event`](https://dom.spec.whatwg.org/#event)

[`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window),
[`VisualViewport`](#visualviewport)

Fired at the
[`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window) when the
[viewport](https://drafts.csswg.org/css2/#viewport%E2%91%A0) is resized. Fired at
[`VisualViewport`](#visualviewport) when the [visual
viewport](https://drafts.csswg.org/css-viewport/#visual-viewport) is resized or the [layout
viewport](https://drafts.csswg.org/css-viewport/#layout-viewport) is scaled.

[`scroll`]

[`Event`](https://dom.spec.whatwg.org/#event)

[`VisualViewport`](#visualviewport),
[`Document`](https://dom.spec.whatwg.org/#document), elements

Fired at the
[`VisualViewport`](#visualviewport),
[`Document`](https://dom.spec.whatwg.org/#document) or element when the
[`VisualViewport`](#visualviewport),
[viewport](https://drafts.csswg.org/css2/#viewport%E2%91%A0), or element is scrolled, respectively.

[`scrollend`]

[`Event`](https://dom.spec.whatwg.org/#event)

[`Document`](https://dom.spec.whatwg.org/#document), elements,
[`VisualViewport`](#visualviewport)

Fired at the
[`VisualViewport`](#visualviewport),
[`Document`](https://dom.spec.whatwg.org/#document), or element when a scroll is
[completed](#scroll-completed): the
[`VisualViewport`](#visualviewport),
[viewport](https://drafts.csswg.org/css2/#viewport%E2%91%A0), or element has been scrolled, the scroll sequence has
ended and any scroll offset changes have been applied.

## 14. Post-Layout State Snapshotting

Some CSS features use post-layout state, like scroll position, as input
to the next style and layout update.

When asked to [run snapshot post-layout state
steps] for a
[`Document`](https://dom.spec.whatwg.org/#document) `doc`, run these steps:

1. For each CSS feature that needs to snapshot post-layout state, take
 a snapshot of the relevant state in `doc`.

The state that is snapshot is defined in other specifications. These
steps must not invalidate `doc` or any other
[`Document`](https://dom.spec.whatwg.org/#document)s in such a way that other post-layout snapshotting
steps can observe that such snapshotting happened. It follows that the
order of which such snapshotting takes place must not matter.

## 15. Privacy Considerations

The [`Screen`](#screen)
interface exposes information about the user's display configuration,
which maybe be used as input to fingerprinting algorithms. User agents
may choose to hide or quantize information about the screen size or
configuration, in order to protect the user's privacy.

[`MouseEvent`](https://w3c.github.io/pointerevents/#dom-mouseevent) contains information about the screen-relative
coordinates of the event. User agents may set these properties to values
that obscure the actual screen-relative location of the event, in order
to protect the user's privacy.

## 16. Security Considerations

No new security considerations have been reported on this specification.

## 17. Changes

This section documents some of the changes between publications of this
specification. This section is not exhaustive. Bug fixes and editorial
changes are generally not listed.

### [ Changes since the [17 March 2016 Working Draft](https://www.w3.org/TR/2016/WD-cssom-view-1-20160317/)]
- Added Simon Fraser and Emilio Cobos Álvarez as current editors and
 moved Simon Pieters to former editors.

- Clarified how
 [`getClientRects()`](#dom-range-getclientrects) handles [typographic character
 unit](https://drafts.csswg.org/css-text-4/#typographic-character-unit)s.

- Changed how
 [`getBoundingClientRect()`](#dom-element-getboundingclientrect) of
 [`Element`](https://dom.spec.whatwg.org/#element) and
 [`getBoundingClientRect()`](#dom-range-getboundingclientrect) of
 [`Range`](https://dom.spec.whatwg.org/#range) handle empty rectangles.

- Changed definition of
 [`offsetParent`](#dom-htmlelement-offsetparent) for Shadow DOM.

- Allowed UAs to lie about [`Screen`](#screen) properties for privacy reasons.

- Changed
 [`colorDepth`](#dom-screen-colordepth) and
 [`pixelDepth`](#dom-screen-pixeldepth) to return real values.

- Changed \'CSS pixels\' to refer to
 [\[CSS-VALUES\]](#biblio-css-values "CSS Values and Units Module Level 4").

- Changed default values for
 [`ScrollIntoViewOptions`](#dictdef-scrollintoviewoptions) to `start` and `nearest` and slightly changed
 behavior of
 [`scrollIntoView()`](#dom-element-scrollintoview)

- Added
 [`screenLeft`](#dom-window-screenleft) and
 [`screenTop`](#dom-window-screentop) as aliases for
 [`screenX`](#dom-window-screenx) and
 [`screenY`](#dom-window-screeny).

- Defined overflow directions in terms of
 [block-end](https://drafts.csswg.org/css-writing-modes-4/#block-end) and
 [inline-end](https://drafts.csswg.org/css-writing-modes-4/#inline-end).

- Renamed the arguments to
 [`resizeTo()`](#dom-window-resizeto) to be `width` and `height`

- Added script-triggered scroll-snap to list of scrolls affected by
 [scroll-behavior](https://drafts.csswg.org/css-overflow-3/#propdef-scroll-behavior).

- Fixed a logical error in the Terminology section.

- Added the \"Security Considerations\" and \"Privacy Considerations\"
 sections

- Moved the
 [scroll-behavior](https://drafts.csswg.org/css-overflow-3/#propdef-scroll-behavior) property to
 [\[CSS-OVERFLOW-3\]](#biblio-css-overflow-3 "CSS Overflow Module Level 3")

- Adjusted the algorithm for
 [`offsetWidth`](#dom-htmlelement-offsetwidth) and
 [`offsetHeight`](#dom-htmlelement-offsetheight).

- Added
 [`checkVisibility()`](#dom-element-checkvisibility) method to
 [`Element`](https://dom.spec.whatwg.org/#element).

- Moved the
 [scrollend](#eventdef-document-scrollend) event from [WICG
 overscroll-scrollend-events](https://wicg.github.io/overscroll-scrollend-events/)
 to
 [\[CSSOM-VIEW-1\]](#biblio-cssom-view-1 "CSSOM View Module")
 and added details for handling them.

- Added a \"get the bounding box\" algorithm to
 [`getBoundingClientRect()`](#dom-element-getboundingclientrect).

- Introduced the
 [`VisualViewport`](#visualviewport) API and related concepts.

- Extended scroll into view algorithm to also work on
 [`Ranges`](https://dom.spec.whatwg.org/#range).

- Clarified whether scaled or unscaled dimensions are returned by
 various APIs in relation to the
 [zoom](https://drafts.csswg.org/css-viewport/#propdef-zoom) property.

- Took scroll snapping and scroll target into account for various
 scrolling APIs.

- Added
 [`currentCSSZoom`](#dom-element-currentcsszoom) attribute to
 [`Element`](https://dom.spec.whatwg.org/#element).

- Added options parameter to
 [`caretPositionFromPoint()`](#dom-document-caretpositionfrompoint) method.

- Removed caret range concept from CaretPosition interface.

- Defined post-layout snapshotting.

- Made the various scrolling algorithms accept a pseudo-element.

- Added [container] option to
 [`ScrollIntoViewOptions`](#dictdef-scrollintoviewoptions).

- Added the
 [`scrollParent`](#dom-htmlelement-scrollparent) attribute.

- Pinch zoom got renamed to [scale
 factor](https://drafts.csswg.org/css-viewport/#scale-factor).

### [ Changes since the [17 December 2013 Working Draft](https://www.w3.org/TR/2013/WD-cssom-view-20131217/)]
- The
 [`scrollIntoView()`](#dom-element-scrollintoview) method on
 [`Element`](https://dom.spec.whatwg.org/#element) was changed and extended.

- The
 [`scrollTop`](#dom-element-scrolltop) and
 [`scrollLeft`](#dom-element-scrollleft) IDL attributes on
 [`Element`](https://dom.spec.whatwg.org/#element) changed to no longer take an object; the
 [`scroll()`](#dom-element-scroll),
 [`scrollTo()`](#dom-element-scrollto) and
 [`scrollBy()`](#dom-element-scrollby) methods were added instead.

- The
 [`scrollWidth`](#dom-element-scrollwidth),
 [`scrollHeight`](#dom-element-scrollheight),
 [`clientTop`](#dom-element-clienttop),
 [`clientLeft`](#dom-element-clientleft),
 [`clientWidth`](#dom-element-clientwidth) and
 [`clientHeight`](#dom-element-clientheight) IDL attributes on
 [`Element`](https://dom.spec.whatwg.org/#element) were changed back to return integers.

- The `DOMRectList` interface was removed.

- The
 [`scrollingElement`](#dom-document-scrollingelement) IDL attribute on
 [`Document`](https://dom.spec.whatwg.org/#document) was added.

- Some readonly attributes on
 [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window) were annotated with `[Replaceable]` IDL extended
 attribute.

- [`MediaQueryList`](#mediaquerylist),
 [scroll](#eventdef-document-scroll) event and
 [resize](#eventdef-window-resize) event are integrated with the [event
 loop](https://html.spec.whatwg.org/multipage/webappapis.html#event-loop) in HTML so they are synchronized with animation
 frames.

- The `instant` value of
 [scroll-behavior](https://drafts.csswg.org/css-overflow-3/#propdef-scroll-behavior) was renamed to
 [auto](https://drafts.csswg.org/css-overflow-3/#valdef-scroll-behavior-auto).

- The origin of
 [`scrollLeft`](#dom-element-scrollleft) on
 [`Element`](https://dom.spec.whatwg.org/#element) was changed (for RTL).

- The
 [`scrollIntoView()`](#dom-element-scrollintoview) method on
 [`Element`](https://dom.spec.whatwg.org/#element) and
 [`scroll()`](#dom-window-scroll),
 [`scrollTo()`](#dom-window-scrollto) and
 [`scrollBy()`](#dom-window-scrollby) methods on
 [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window) take the relevant dictionary as the first argument.

- The
 [`MediaQueryList`](#mediaquerylist) interface was changed to use regular event API and
 define
 [`addListener()`](#dom-mediaquerylist-addlistener) in terms of that.

- Added \"Change History\" section.

- Moved Glenn Adams to former editors.

### [ Changes since the [04 August 2011 Working Draft](https://www.w3.org/TR/2011/WD-cssom-view-20110804/)]
- Added Simon Pieters and Glenn Adams as editors and moved Anne van
 Kesteren to former editors.

- Introduced
 [scroll-behavior](https://drafts.csswg.org/css-overflow-3/#propdef-scroll-behavior) CSS property.

- Added [Block flow
 direction](https://drafts.csswg.org/css-writing-modes-4/#block-flow-direction) and [inline base
 direction](https://drafts.csswg.org/css-writing-modes-4/#inline-base-direction) from
 [\[CSS-WRITING-MODES-3\]](#biblio-css-writing-modes-3 "CSS Writing Modes Level 3")
 to terminology.

- Added section about zooming.

- Added
 [`moveTo()`](#dom-window-moveto),
 [`moveBy()`](#dom-window-moveby),
 [`resizeTo()`](#dom-window-resizeto), and
 [`resizeBy()`](#dom-window-resizeby) methods to
 [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window).

- Added
 [`devicePixelRatio`](#dom-window-devicepixelratio) attribute to
 [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window).

- Introduced
 [`ScrollOptions`](#dictdef-scrolloptions) dictionary and added an [options]
 parameter to scrolling methods.

- Added
 [`devicePixelRatio`](#dom-window-devicepixelratio) attribute to
 [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window).

- Added [features] parameter to
 [`open()`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#dom-open) method.

- Added
 [`elementsFromPoint()`](#dom-document-elementsfrompoint) method to
 [`Document`](https://dom.spec.whatwg.org/#document).

- Added
 [`getClientRect()`](#dom-caretposition-getclientrect) method to
 [`CaretPosition`](#caretposition).

- Introduced initial draft of
 [`GeometryUtils`](#geometryutils) interface.

- Changed
 [`innerWidth`](#dom-window-innerwidth),
 [`innerHeight`](#dom-window-innerheight), etc. to use
 [double](https://drafts.csswg.org/css-backgrounds-3/#valdef-line-style-double).

- CSS [transforms](#transforms)
 are now acknowledged.

- Replaced `ClientRect` by
 [`DOMRect`](https://drafts.csswg.org/geometry-1/#domrect).

- Defined the firing behavior of
 [scroll](#eventdef-document-scroll) and
 [resize](#eventdef-window-resize) events.

- Changed
 [`colorDepth`](#dom-screen-colordepth) and
 [`pixelDepth`](#dom-screen-pixeldepth) to always return 24.

### [ Changes since the [04 August 2009 Working Draft](https://www.w3.org/TR/2009/WD-cssom-view-20090804/)]
- Removed redundant definition of terminology of other specifications,
 explicitly defining units (e.g. CSS pixels) and content/document
 content distinction.

- Introduced
 [`MediaQueryList`](#mediaquerylist) interface.

- Moved the `matchMedium()` method of the `Media` to the
 [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window) interface, renamed it to
 [`matchMedia()`](#dom-window-matchmedia), and changed its return type to
 [`MediaQueryList`](#mediaquerylist).

- Removed the `AbstractView` and `Media` interfaces.

- Removed the `DocumentView` interface and moved methods
 [`elementFromPoint()`](#dom-document-elementfrompoint) and `caretRangeFromPoint()` to the
 [`Document`](https://dom.spec.whatwg.org/#document) interface.

- Renamed the `caretRangeFromPoint()` method to
 [`caretPositionFromPoint()`](#dom-document-caretpositionfrompoint).

- Introduced
 [`CaretPosition`](#caretposition) interface and changed the return type of
 [`caretPositionFromPoint()`](#dom-document-caretpositionfrompoint) to [CaretPosition].

- Added the
 [`scrollIntoView()`](#dom-element-scrollintoview) method to the
 [`Element`](https://dom.spec.whatwg.org/#element) interface.

### [ Changes since the [22 February 2008 Working Draft](https://www.w3.org/TR/2008/WD-cssom-view-20080222/)]
- Removed the `WindowView` interface and moved its attributes and
 methods to an `AbstractView` and inheriting `ScreenView` interface.

- Added the `document` IDL attribute to `AbstractView`.

- Added the
 [`scroll()`](#dom-window-scroll),
 [`scrollTo()`](#dom-window-scrollto), and
 [`scrollBy()`](#dom-window-scrollby) methods to the `ScreenView` interface.

- Removed the `ElementView` interface and moved its attributes and
 methods to the
 [`Element`](https://dom.spec.whatwg.org/#element) and
 [`HTMLElement`](https://html.spec.whatwg.org/multipage/dom.html#htmlelement) interfaces.

- Added the
 [`defaultView`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#dom-document-defaultview) IDL attribute and `caretRangeFromPoint()` method to
 the `DocumentView` interface.

- Removed `RangeView` interface and instead directly extended the
 [`Range`](https://dom.spec.whatwg.org/#range) interface.

- Removed the `MouseEventView` interface and instead directly extended
 the
 [`MouseEvent`](https://w3c.github.io/pointerevents/#dom-mouseevent) interface.

- Renamed the `TextRectangleList` interface to `ClientRectList` and
 turned the `item()` method into an indexed getter.

- Renamed the `TextRectangle` interface to `ClientRect` and added the
 `width` and `height` attributes.

## 18. Acknowledgements

The editors would like to thank Alan Stearns, Alexey Feldgendler,
Antonio Gomes, Björn Höhrmann, Boris Zbarsky, Chris Rebert, Corey
Farwell, Dan Bates, David Vest, Elliott Sprehn, Garrett Smith, Henrik
Andersson, Hallvord R. M. Steen, Kang-Hao Lu, Koji Ishii, Leif Arne
Storset, Luiz Agostini, Maciej Stachowiak, Michael Dyck, Mike Wilson,
Morten Stenshorne, Olli Pettay, Pavel Curtis, Peter-Paul Koch, Rachel
Kmetz, Rick Byers, Robert O'Callahan, Sam Weinig, Scott Johnson,
Sebastian Zartner, Stewart Brodie, Sylvain Galineau, Tab Atkins, Tarquin
Wilton-Jones, Thomas Moore, Thomas Shinnick, and Xiaomei Ji for their
contributions to this document.

Special thanks to the Microsoft employees who first implemented many of
the features specified in this draft, which were first widely deployed
by the Windows Internet Explorer browser.
