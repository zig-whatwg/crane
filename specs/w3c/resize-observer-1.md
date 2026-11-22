## 1. Introduction

*This section is non-normative.*

Responsive Web Components need to respond to
[`Element`](https://dom.spec.whatwg.org/#element)'s size changes. An example is an
[`Element`](https://dom.spec.whatwg.org/#element) that displays a map:

- it displays a map by tiling its content box with
 [`Element`](https://dom.spec.whatwg.org/#element) tiles.

- when resized, it must redo the tiling.

Responsive Web Applications can already respond to
[viewport](https://www.w3.org/TR/CSS2/visuren.html#x1) size changes. This is done with CSS media queries, or
[`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window)'s
[`resize`](https://drafts.csswg.org/cssom-view-1/#eventdef-window-resize) event.

The ResizeObserver API is an interface for observing changes to
Element's size. It is an
[`Element`](https://dom.spec.whatwg.org/#element)'s counterpart to
[`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window)'s
[`resize`](https://drafts.csswg.org/cssom-view-1/#eventdef-window-resize) event.

ResizeObserver's notifications can be used to respond to changes in
[`Element`](https://dom.spec.whatwg.org/#element)'s size. Some interesting facts about these
observations:

- Observation will fire when observation starts.

- Observation will fire when watched Element is inserted/removed from
 DOM.

- Observation will fire when watched Element
 [display](https://www.w3.org/TR/css-display-3/#propdef-display) gets set to none.

- Observations do not fire for non-replaced inline Elements.

- Observations will not be triggered by CSS transforms.

```
<canvas id="ellipse" style="display:block"></canvas>
<div id="menu" style="display:block;width:100px">
 <img src="hamburger.jpg" style="width:24px;height:24px">
 <p class="title">menu title</p>
</div>
```

```
// In response to resize, paint an ellipse inside a canvas
document.querySelector('#ellipse').handleResize = entry => {
 entry.target.width = entry.borderBoxSize[0].inlineSize;
 entry.target.height = entry.borderBoxSize[0].blockSize;
 let rx = Math.floor(entry.target.width / 2);
 let ry = Math.floor(entry.target.height / 2);
 let ctx = entry.target.getContext('2d');
 ctx.beginPath();
 ctx.ellipse(rx, ry, rx, ry, 0, 0, 2 * Math.PI);
 ctx.stroke();
}

// In response to resize, change title visibility depending on width
document.querySelector('#menu').handleResize = entry => {
 let title = entry.target.querySelector('.title');
 if (entry.borderBoxSize[0].inlineSize < 40)
 title.style.display = 'none';
 else
 title.style.display = 'inline-block';
}

let ro = new ResizeObserver(entries => {
 for (let entry of entries) {
 let cs = window.getComputedStyle(entry.target);
 console.log('watching element:', entry.target);
 console.log(entry.contentRect.top, ' is ', cs.paddingTop);
 console.log(entry.contentRect.left, ' is ', cs.paddingLeft);
 console.log(entry.borderBoxSize[0].inlineSize, ' is ', cs.width);
 console.log(entry.borderBoxSize[0].blockSize, ' is ', cs.height);
 if (entry.target.handleResize)
 entry.target.handleResize(entry);
 }
});

ro.observe(document.querySelector('#ellipse'));
ro.observe(document.querySelector('#menu'));
```

## 2. Resize Observer API

### 2.1. ResizeObserver interface

The ResizeObserver interface is used to observe changes to
[`Element`](https://dom.spec.whatwg.org/#element)'s size.

It is modeled after
[`MutationObserver`](https://dom.spec.whatwg.org/#mutationobserver) and
[`IntersectionObserver`](https://www.w3.org/TR/intersection-observer/#intersection-observer-interface).

```
enum ResizeObserverBoxOptions {
 "border-box", "content-box", "device-pixel-content-box"
};
```

ResizeObserver can observe different kinds of CSS sizes:

- [`border-box`](#dom-resizeobserverboxoptions-border-box) : size of [box border
 area](https://www.w3.org/TR/CSS21/box.html#box-border-area) as defined in CSS2.

- [`content-box`](#dom-resizeobserverboxoptions-content-box) : size of [content
 area](https://drafts.csswg.org/css-box-3/#content-area) as defined in CSS2.

- [`device-pixel-content-box`](#dom-resizeobserverboxoptions-device-pixel-content-box) : size of [content
 area](https://drafts.csswg.org/css-box-3/#content-area) as defined in CSS2, in device pixels, before applying
 any CSS transforms on the element or its ancestors. This size must
 contain integer values.

The
[`device-pixel-content-box`](#dom-resizeobserverboxoptions-device-pixel-content-box) can be approximated by multiplying
[devicePixelRatio](https://www.w3.org/TR/cssom-view-1/#dom-window-devicepixelratio) by the
[`content-box`](#dom-resizeobserverboxoptions-content-box) size. However, due to browser-specific subpixel
snapping behavior, authors cannot determine the correct way to round
this scaled
[`content-box`](#dom-resizeobserverboxoptions-content-box) size. How a UA computes the device pixel box for an
element is implementation-dependent. One possible implementation could
be to multiply the box size and position by the device pixel ratio, then
round both the resulting floating-point size and position of the box to
integer values, in a way that maximizes the quality of the rendered
output.

Note that this size can be affected by position changes to the target,
and thus is typically more expensive to observe than the other sizes.

```
dictionary ResizeObserverOptions {
 ResizeObserverBoxOptions box = "content-box";
};
```

This section is non-normative. An author may desire to observe more than
one CSS box. In this case, author will need to use multiple
ResizeObservers.

```
// Observe the content-box
ro.observe(document.querySelector('#menu'), { box: 'content-box' });

// Observe just the border box. Replaces previous observation.
ro1.observe(document.querySelector('#menu'), { box: 'border-box' });
```

This does not have any impact on which box dimensions are returned to
the defined callback when the event is fired, it solely defines which
box the author wishes to observe layout changes on.

```
[Exposed=(Window)]
interface ResizeObserver {
 constructor(ResizeObserverCallback callback);
 undefined observe(Element target, optional ResizeObserverOptions options = );
 undefined unobserve(Element target);
 undefined disconnect();
};
```

[`new ResizeObserver(``callback``)`]

: 1. Let `this` be a new
 [`ResizeObserver`](#resizeobserver) object.

 2. Set
 `this`.[`[[callback]]`](#dom-resizeobserver-callback-slot) internal slot to `callback`.

 3. Set
 `this`.[`[[observationTargets]]`](#dom-resizeobserver-observationtargets-slot) internal slot to an empty list.

 4. Add `this` to
 [`Document`](https://dom.spec.whatwg.org/#document).[`[[resizeObservers]]`](#dom-document-resizeobservers-slot) slot.

[`observe(``target``, ``options``)`]

: Adds target to the list of observed elements.

 1. If `target` is in
 [`[[observationTargets]]`](#dom-resizeobserver-observationtargets-slot) slot, call
 [`unobserve()`](#dom-resizeobserver-unobserve) with argument `target`.

 2. Let `observedBox` be the value of the
 [`box`](#dom-resizeobserveroptions-box) dictionary member of `options`.

 3. Let `resizeObservation` be new
 [`ResizeObservation`](#resizeobservation)(`target`, `observedBox`).

 4. Add the `resizeObservation` to the
 [`[[observationTargets]]`](#dom-resizeobserver-observationtargets-slot) slot.

[`unobserve(``target``)`]

: Removes `target` from the list of observed elements.

 1. Let `observation` be
 [`ResizeObservation`](#resizeobservation) in
 [`[[observationTargets]]`](#dom-resizeobserver-observationtargets-slot) whose target slot is `target`.

 2. If `observation` is not found, return.

 3. Remove `observation` from
 [`[[observationTargets]]`](#dom-resizeobserver-observationtargets-slot).

[`disconnect()`]

: 1. Clear the
 [`[[observationTargets]]`](#dom-resizeobserver-observationtargets-slot) list.

 2. Clear the
 [`[[activeTargets]]`](#dom-resizeobserver-activetargets-slot) list.

### 2.2. ResizeObserverCallback

```
callback ResizeObserverCallback = undefined (sequence<ResizeObserverEntry> entries, ResizeObserver observer);
```

This callback delivers
[`ResizeObserver`](#resizeobserver)'s notifications. It is invoked by a [broadcast active
resize
observations](#broadcast-active-resize-observations) algorithm.

### 2.3. ResizeObserverEntry

```
[Exposed=Window]
interface ResizeObserverEntry {
 readonly attribute Element target;
 readonly attribute DOMRectReadOnly contentRect;
 readonly attribute FrozenArray<ResizeObserverSize> borderBoxSize;
 readonly attribute FrozenArray<ResizeObserverSize> contentBoxSize;
 readonly attribute FrozenArray<ResizeObserverSize> devicePixelContentBoxSize;
};
```

contentRect is from the incubation phase of ResizeObserver and is only
included for current web compat reasons. It may be deprecated in future
levels.

[`target`], of type [Element](https://dom.spec.whatwg.org/#element), readonly

: The
 [`Element`](https://dom.spec.whatwg.org/#element) whose size has changed.

[`contentRect`], of type [DOMRectReadOnly](https://drafts.csswg.org/geometry-1/#domrectreadonly), readonly

: [`Element`](https://dom.spec.whatwg.org/#element)'s [content
 rect](#content-rect) when
 [`ResizeObserverCallback`](#callbackdef-resizeobservercallback) is invoked.

[`borderBoxSize`], of type FrozenArray\<[ResizeObserverSize](#resizeobserversize)\>, readonly

: A
 [`FrozenArray`](https://webidl.spec.whatwg.org/#idl-frozen-array) containing the
 [`Element`](https://dom.spec.whatwg.org/#element)'s [border
 box](https://drafts.csswg.org/css-box-4/#border-box) size when
 [`ResizeObserverCallback`](#callbackdef-resizeobservercallback) is invoked.

[`contentBoxSize`], of type FrozenArray\<[ResizeObserverSize](#resizeobserversize)\>, readonly

: A
 [`FrozenArray`](https://webidl.spec.whatwg.org/#idl-frozen-array) containing the
 [`Element`](https://dom.spec.whatwg.org/#element)'s [content
 rect](#content-rect) size
 when
 [`ResizeObserverCallback`](#callbackdef-resizeobservercallback) is invoked.

[`devicePixelContentBoxSize`], of type FrozenArray\<[ResizeObserverSize](#resizeobserversize)\>, readonly

: A
 [`FrozenArray`](https://webidl.spec.whatwg.org/#idl-frozen-array) containing the
 [`Element`](https://dom.spec.whatwg.org/#element)'s [content
 rect](#content-rect) size in
 integral device pixels when
 [`ResizeObserverCallback`](#callbackdef-resizeobservercallback) is invoked.

The box size properties are exposed as
[`FrozenArray`](https://webidl.spec.whatwg.org/#idl-frozen-array) in order to support elements that have multiple
fragments, which occur in
[multi-column](https://www.w3.org/TR/css3-multicol/#) scenarios. However the current definitions of [content
rect](#content-rect) and [border
box](https://drafts.csswg.org/css-box-4/#border-box) do not mention how those boxes are affected by
[multi-column] layout. In this spec, there will
only be a single ResizeObserverSize returned in the
[`FrozenArray`](https://webidl.spec.whatwg.org/#idl-frozen-array), which will correspond to the dimensions of the first
column. A future version of this spec will extend the returned
[`FrozenArray`](https://webidl.spec.whatwg.org/#idl-frozen-array) to contain the per-fragment size information.

```
[Exposed=Window]
interface ResizeObserverSize {
 readonly attribute unrestricted double inlineSize;
 readonly attribute unrestricted double blockSize;
};
```

## 3. Processing Model

### 3.1. ResizeObservation example struct

This section is non-normative. ResizeObservation is an example struct
that can be used in implementation of Resize Observer. It is being
included here in order to help provide clarity during the processing
model. It effectively holds observation information for a single
[`Element`](https://dom.spec.whatwg.org/#element). This interface is not visible to Javascript.

```
interface ResizeObservation {
 constructor(Element target, ResizeObserverBoxOptions observedBox);
 readonly attribute Element target;
 readonly attribute ResizeObserverBoxOptions observedBox;
 readonly attribute FrozenArray<ResizeObserverSize> lastReportedSizes;
};
```

[`target`], of type [Element](https://dom.spec.whatwg.org/#element), readonly

: The observed
 [`Element`](https://dom.spec.whatwg.org/#element).

[`observedBox`], of type [ResizeObserverBoxOptions](#enumdef-resizeobserverboxoptions), readonly

: Which box is being observed.

[`lastReportedSizes`], of type FrozenArray\<[ResizeObserverSize](#resizeobserversize)\>, readonly

: Ordered array of last reported sizes.

[`new ResizeObservation(target, observedBox)`]

: 1. Let `this` be a new
 [`ResizeObservation`](#resizeobservation) object.

 2. Set `this` internal
 [`target`](#dom-resizeobservation-target) slot to `target`.

 3. Set `this` internal
 [`observedBox`](#dom-resizeobservation-observedbox) slot to `observedBox`.

 4. Set `this` internal
 [`lastReportedSizes`](#dom-resizeobservation-lastreportedsizes) slot to \[(-1,-1)\].

[`isActive()`]

: 1. Set `currentSize` by [calculate box
 size](#calculate-box-size) given `target` and
 `observedBox`.

 2. Return true if `currentSize` is not equal to the
 first entry in
 this.[`lastReportedSizes`](#dom-resizeobservation-lastreportedsizes).

 3. Return false.

### 3.2. Internal Slot Definitions

#### 3.2.1. Document

[Document](https://dom.spec.whatwg.org/#concept-document) has a
[`[[resizeObservers]]`] slot that is a list of
[`ResizeObserver`](#resizeobserver)s in this document. It is initialized to empty.

#### 3.2.2. ResizeObserver

[`ResizeObserver`](#resizeobserver) has a
[`[[callback]]`] slot,
initialized by constructor.

[`ResizeObserver`](#resizeobserver) has an
[`[[observationTargets]]`] slot, which is a list of
[`ResizeObservation`](#resizeobservation)s. It represents all Elements being observed.

[`ResizeObserver`](#resizeobserver) has a
[`[[activeTargets]]`] slot, which is a list of
[`ResizeObservation`](#resizeobservation)s. It represents all Elements whose size has changed
since last observation broadcast that are eligible for broadcast.

[`ResizeObserver`](#resizeobserver) has a
[`[[skippedTargets]]`] slot, which is a list of
[`ResizeObservation`](#resizeobservation)s. It represents all Elements whose size has changed
since last observation broadcast that are **not** eligible for broadcast

### 3.3. CSS Definitions

#### 3.3.1. content rect

DOM [content rect] is a rect whose:

- width is [content
 width](https://www.w3.org/TR/CSS2/box.html#content-width)

- height is [content
 height](https://www.w3.org/TR/CSS2/box.html#content-height)

- top is [padding
 top](https://drafts.csswg.org/css-box-3/#padding-physical)

- left is [padding
 left](https://drafts.csswg.org/css-box-3/#padding-physical)

[content
width](https://www.w3.org/TR/CSS2/box.html#content-width) spec does not mention how
[multi-column](https://www.w3.org/TR/css3-multicol/#) layout affects content box. In this spec, content width
of an
[`Element`](https://dom.spec.whatwg.org/#element) inside [multi-column] is the
result of `getComputedStyle(element).width`. This currently evaluates to
width of the first column.

Having content rect position be padding-top/left is useful for absolute
positioning of target's children. Absolute position coordinate space
origin is topLeft of the padding rect.

Watching content rect means that:

- observation will fire when watched Element is inserted/removed from
 DOM.

- observation will fire when watched Element display gets set to none.

- non-replaced inline Elements will always have an empty content rect.

- observations will not be triggered by CSS transforms.

Web content can also contain SVG elements. SVG elements that do not have
associated CSS layout boxes define [bounding
box](https://www.w3.org/TR/SVG2/coords.html#BoundingBoxes) instead of a content box. Content rect for the
[SVGGraphicsElement](https://www.w3.org/TR/SVG2/types.html#InterfaceSVGGraphicsElement)s without CSS layout boxes is a rect whose:

- width is [bounding
 box](https://www.w3.org/TR/SVG2/coords.html#BoundingBoxes) width

- height is [bounding
 box](https://www.w3.org/TR/SVG2/coords.html#BoundingBoxes) height

- top and left are 0

### 3.4. Algorithms

 The following algorithms are invoked as a part of
[update the
rendering](https://html.spec.whatwg.org/multipage/webappapis.html#update-the-rendering) in the html spec: [gather active resize observations at
depth](#gather-active-resize-observations-at-depth), [has active resize
observations](#has-active-resize-observations), [has skipped resize
observations](#has-skipped-resize-observations), [broadcast active resize
observations](#broadcast-active-resize-observations) and [deliver resize loop error
notification](#deliver-resize-loop-error-notification).

#### 3.4.1. Gather active resize observations at depth

It computes all active resize observations for a `document`.
To [gather active resize observations at
depth],
run these steps:

1. Let `depth` be the depth passed in.

2. For each `observer` in
 [`[[resizeObservers]]`](#dom-document-resizeobservers-slot) run these steps:

 1. Clear `observer`'s
 [`[[activeTargets]]`](#dom-resizeobserver-activetargets-slot), and
 [`[[skippedTargets]]`](#dom-resizeobserver-skippedtargets-slot).

 2. For each `observation` in
 `observer`.[`[[observationTargets]]`](#dom-resizeobserver-observationtargets-slot) run this step:

 1. If
 `observation`.[`isActive()`](#dom-resizeobservation-isactive) is true

 1. Let `targetDepth` be result of [calculate
 depth for
 node](#calculate-depth-for-node) for
 `observation`.[`target`](#dom-resizeobservation-target).

 2. If `targetDepth` is greater than
 `depth` then add `observation` to
 [`[[activeTargets]]`](#dom-resizeobserver-activetargets-slot).

 3. Else add `observation` to
 [`[[skippedTargets]]`](#dom-resizeobserver-skippedtargets-slot).

#### 3.4.2. Has active resize observations

To determine if
[`Document`](https://dom.spec.whatwg.org/#document) [has active resize
observations] run these steps:

1. For each `observer` in
 [`[[resizeObservers]]`](#dom-document-resizeobservers-slot) run this step:

 1. If
 `observer`.[`[[activeTargets]]`](#dom-resizeobserver-activetargets-slot) is not empty, return true.

2. return false.

#### 3.4.3. Has skipped resize observations

To determine if
[`Document`](https://dom.spec.whatwg.org/#document) [has skipped resize
observations] run these steps:

1. For each `observer` in
 [`[[resizeObservers]]`](#dom-document-resizeobservers-slot) run this step:

 1. If
 `observer`.[`[[skippedTargets]]`](#dom-resizeobserver-skippedtargets-slot) is not empty, return true.

2. return false.

#### 3.4.4. Create and populate a ResizeObserverEntry

To [create and populate a
ResizeObserverEntry] for a given
`target`, run these steps:

1. Let `this` be a new
 [`ResizeObserverEntry`](#resizeobserverentry).

2. Set
 `this`.[`target`](#dom-resizeobserverentry-target) slot to `target`.

3. Set
 `this`.[`borderBoxSize`](#dom-resizeobserverentry-borderboxsize) slot to result of [calculating box
 size](#calculate-box-size) given `target` and observedBox of
 [`"border-box"`](#dom-resizeobserverboxoptions-border-box).

4. Set
 `this`.[`contentBoxSize`](#dom-resizeobserverentry-contentboxsize) slot to result of [calculating box
 size](#calculate-box-size) given `target` and observedBox of
 [`"content-box"`](#dom-resizeobserverboxoptions-content-box).

5. Set
 `this`.[`devicePixelContentBoxSize`](#dom-resizeobserverentry-devicepixelcontentboxsize) slot to result of [calculating box
 size](#calculate-box-size) given `target` and observedBox of
 [`"device-pixel-content-box"`](#dom-resizeobserverboxoptions-device-pixel-content-box).

6. Set
 `this`.[`contentRect`](#dom-resizeobserverentry-contentrect) to logical
 `this`.[`contentBoxSize`](#dom-resizeobserverentry-contentboxsize) given `target` and observedBox of
 \"content-box\".

7. If `target` is not an SVG element or `target`
 is an SVG element with an associated CSS layout box do these steps:

 1. Set `this`.`contentRect`.top to
 `target`.[padding
 top](https://drafts.csswg.org/css-box-3/#padding-physical).

 2. Set `this`.`contentRect`.left to
 `target`.[padding
 left](https://drafts.csswg.org/css-box-3/#padding-physical).

8. If `target` is an SVG element without an associated CSS
 layout box do these steps:

 1. Set `this`.`contentRect`.top and
 `this`.contentRect.left to 0.

#### 3.4.5. Broadcast active resize observations

[broadcast active resize
observations] delivers all active resize observations in a
document, and returns the depth of the shallowest broadcast target
depth.

To broadcast active resize observations for a `document`, run
these steps:

1. Let `shallowestTargetDepth` be ∞

2. For each `observer` in
 `document`.[`[[resizeObservers]]`](#dom-document-resizeobservers-slot) run these steps:

 1. If
 `observer`.[`[[activeTargets]]`](#dom-resizeobserver-activetargets-slot) slot is empty, continue.

 2. Let `entries` be an empty list of
 [`ResizeObserverEntry`](#resizeobserverentry)ies.

 3. For each `observation` in
 [`[[activeTargets]]`](#dom-resizeobserver-activetargets-slot) perform these steps:

 1. Let `entry` be the result of running [create and
 populate a
 ResizeObserverEntry](#create-and-populate-a-resizeobserverentry) given
 `observation`.[`target`](#dom-resizeobservation-target).

 2. Add `entry` to `entries`.

 3. Set
 `observation`.[`lastReportedSizes`](#dom-resizeobservation-lastreportedsizes) to matching `entry` sizes.

 1. Matching sizes are
 `entry`.[`borderBoxSize`](#dom-resizeobserverentry-borderboxsize) if
 `observation`.[`observedBox`](#dom-resizeobservation-observedbox) is \"border-box\"

 2. Matching sizes are
 `entry`.[`contentBoxSize`](#dom-resizeobserverentry-contentboxsize) if
 `observation`.[`observedBox`](#dom-resizeobservation-observedbox) is \"content-box\"

 3. Matching sizes are
 `entry`.[`devicePixelContentBoxSize`](#dom-resizeobserverentry-devicepixelcontentboxsize) if
 `observation`.[`observedBox`](#dom-resizeobservation-observedbox) is \"device-pixel-content-box\"

 4. Set `targetDepth` to the result of [calculate
 depth for
 node](#calculate-depth-for-node) for
 `observation`.[`target`](#dom-resizeobservation-target).

 5. Set `shallowestTargetDepth` to
 `targetDepth` if `targetDepth` \<
 `shallowestTargetDepth`

 4. Invoke
 `observer`.[`[[callback]]`](#dom-resizeobserver-callback-slot) with `entries` as the first argument
 and `observer` as the second argument and [callback
 this
 value](https://webidl.spec.whatwg.org/#dfn-callback-this-value). If this throws an exception, [report the
 exception](https://html.spec.whatwg.org/multipage/webappapis.html#report-the-exception).

 5. Clear
 `observer`.[`[[activeTargets]]`](#dom-resizeobserver-activetargets-slot).

3. Return `shallowestTargetDepth`.

#### 3.4.6. Deliver Resize Loop Error

To [deliver resize loop error
notification] run these steps:

1. Create a new
 [`ErrorEvent`](https://html.spec.whatwg.org/multipage/webappapis.html#errorevent).

2. Initialize `event`'s message slot to \"ResizeObserver
 loop completed with undelivered notifications.\".

3. Report the exception `event`.

#### 3.4.7. Calculate depth for node

To [calculate depth for node], given a `node`, run
these steps:

1. Let `p` be the parent-traversal path from
 `node` to a root Element of this element's flattened DOM
 tree.

2. Return number of nodes in `p`.

#### 3.4.8. Calculate box size, given target and observed box

This algorithm computes `target`
[`Element`](https://dom.spec.whatwg.org/#element)'s observed box size. Type of box is described by
[`ResizeObserverBoxOptions`](#enumdef-resizeobserverboxoptions). The SVG elements which don't have associated CSS
layout boxes are an exception. The sizes of these elements are always
their bounding box sizes, because these elements do not use standard CSS
box model.

To [calculate box size], given `target` and
`observedBox`, run these steps:

1. Let `computedSize` be a new
 [`ResizeObserverSize`](#resizeobserversize) object.

2. If `target` is an
 [`SVGGraphicsElement`](https://w3c.github.io/svgwg/svg2-draft/types.html#svggraphicselement) that does not have an associated CSS layout box:

 If `observedBox` is [`"border-box"`](#dom-resizeobserverboxoptions-border-box)\
 If `observedBox` is [`"content-box"`](#dom-resizeobserverboxoptions-content-box)

 : 1. Set `computedSize`'s
 [`inlineSize`](#dom-resizeobserversize-inlinesize) attribute to `target`'s
 [bounding
 box](https://www.w3.org/TR/SVG2/coords.html#BoundingBoxes) inline length.

 2. Set `computedSize`'s
 [`blockSize`](#dom-resizeobserversize-blocksize) attribute to `target`'s
 [bounding
 box](https://www.w3.org/TR/SVG2/coords.html#BoundingBoxes) block length.

 If `observedBox` is [`"device-pixel-content-box"`](#dom-resizeobserverboxoptions-device-pixel-content-box)

 : 1. Set `computedSize`'s
 [`inlineSize`](#dom-resizeobserversize-inlinesize) attribute to `target`'s
 [bounding
 box](https://www.w3.org/TR/SVG2/coords.html#BoundingBoxes) inline length, in integral device pixels.

 2. Set `computedSize`'s
 [`blockSize`](#dom-resizeobserversize-blocksize) attribute to `target`'s
 [bounding
 box](https://www.w3.org/TR/SVG2/coords.html#BoundingBoxes) block length, in integral device pixels.

3. Otherwise:

 If `observedBox` is [`"border-box"`](#dom-resizeobserverboxoptions-border-box)

 : 1. Set `computedSize`'s
 [`inlineSize`](#dom-resizeobserversize-inlinesize) attribute to `target`'s [border
 area](https://drafts.csswg.org/css-box-4/#border-area) inline length.

 2. Set `computedSize`'s
 [`blockSize`](#dom-resizeobserversize-blocksize) attribute to `target`'s [border
 area](https://drafts.csswg.org/css-box-4/#border-area) block length.

 If `observedBox` is [`"content-box"`](#dom-resizeobserverboxoptions-content-box)

 : 1. Set `computedSize`'s
 [`inlineSize`](#dom-resizeobserversize-inlinesize) attribute to `target`'s [content
 area](https://drafts.csswg.org/css-box-3/#content-area) inline length.

 2. Set `computedSize`'s
 [`blockSize`](#dom-resizeobserversize-blocksize) attribute to `target`'s [content
 area](https://drafts.csswg.org/css-box-3/#content-area) block length.

 If `observedBox` is [`"device-pixel-content-box"`](#dom-resizeobserverboxoptions-device-pixel-content-box)

 : 1. Set `computedSize`'s
 [`inlineSize`](#dom-resizeobserversize-inlinesize) attribute to `target`'s [content
 area](https://drafts.csswg.org/css-box-3/#content-area) inline length, in integral device pixels.

 2. Set `computedSize`'s
 [`blockSize`](#dom-resizeobserversize-blocksize) attribute to `target`'s [content
 area](https://drafts.csswg.org/css-box-3/#content-area) block length, in integral device pixels.

4. Return `computedSize`.

### 3.5. ResizeObserver Lifetime

A [`ResizeObserver`](#resizeobserver) will remain alive until both of these conditions are
met:

- there are no scripting references to the observer.

- the observer is not observing any targets.

## [Privacy Considerations]
No new privacy considerations have been reported on this specification.

## [Security Considerations]
No new security considerations have been reported on this specification.
