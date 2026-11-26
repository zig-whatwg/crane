## 1. Introduction

::: non-normative
*This section is non-normative.*

Much of the purpose of a web browser is to translate HTML, CSS and image
resources into pixels on a screen for users. Measuring the performance
of a web page often involves measuring the time it takes to perform
these tasks - to render content, whether text or image, to the screen.
There are many different ways to use this timing to make statements
about the performance of a page, or about the user experience of
loading, but fundamentally all of those ways begin with a common means
of measuring time.

This is a foundational document which specifies how to measure paint
timing as a general-purpose mechanism. That foundation is then used to
define the First Paint and First Contentful Paint metrics. Other
specific instances of paint measurement may be specified in other
documents.

Specifically, this specification covers:

- Measuring the time when images are decoded and ready for painting

- Measuring the time when elements are painted

- Measuring the size of the painted elements

- Determining whether a painted element contains any visible content.

### 1.1. First Paint and First Contentful Paint

Load is not a single moment in time --- it's an experience that no one
metric can fully capture. There are multiple moments during the load
experience that can affect whether a user perceives it as \"fast\" or
\"slow\".

First paint (FP) is the first of these key moments, followed by first
contentful paint (FCP). These metrics mark the points in time when the
browser renders a given document. This is important to the user because
it answers the question: is it happening?

The primary difference between the two metrics is FP marks the first
time the browser renders anything for a given document. By contrast, FCP
marks the time when the browser renders the first bit of image or text
content from the DOM.

### 1.2. Usage example

```
const observer = new PerformanceObserver(function(list) {
 const perfEntries = list.getEntries();
 for (const perfEntry of perfEntries) {
 // Process entries
 // report back for analytics and monitoring
 // ...
 }
});

// register observer for paint timing notifications
observer.observe({entryTypes: ["paint"]});
```

## 2. Terminology

[Paint]: the user
agent has performed a \"paint\" (or \"render\") when it has converted
the render tree to pixels on the screen. Formally, we consider the user
agent to have \"rendered\" a document when it has performed the [update
the
rendering](https://html.spec.whatwg.org/multipage/webappapis.html#update-the-rendering) steps of the event loop.

[NOTE:] The rendering pipeline is very complex, and the
timestamp should be the latest timestamp the user agent is able to note
in this pipeline (best effort). Typically the time at which the frame is
submitted to the OS for display is recommended for this API.

A [generated content
pseudo-element](https://drafts.csswg.org/css-pseudo-4#generated-content) is a [paintable
pseudo-element] when all of the following apply:

- The pseudo-element's
 [used](https://drafts.csswg.org/css-cascade-5/#used-value)
 [visibility](https://drafts.csswg.org/css2/#propdef-visibility) is `visible`.

- The pseudo-element's
 [used](https://drafts.csswg.org/css-cascade-5/#used-value)
 [opacity](https://drafts.csswg.org/css-color-3/#opacity) is greater than zero.

- The pseudo-element generates a non-empty
 [box](https://drafts.csswg.org/css-display-4/#box).

A [CSS
image](https://www.w3.org/TR/css-images-3/#typedef-image) `img` is a [contentful
image]
when all of the following apply:

- `img` is [url
 valued](https://www.w3.org/TR/css3-values/#url-value).

- `img` is
 [available](https://html.spec.whatwg.org/multipage/images.html#img-available).

A
[`DOMString`](https://webidl.spec.whatwg.org/#idl-DOMString) is [non-empty] if it contains at least one character
excluding [document white space
characters](https://drafts.csswg.org/css-text-4/#white-space).

An
[element](https://dom.spec.whatwg.org/#concept-element) `target` is [contentful] when one or more of the following
apply:

- `target` has a [text
 node](https://drafts.csswg.org/css-display-4/#text-nodes) child, representing
 [non-empty](#non-empty) text, and
 the node's
 [used](https://drafts.csswg.org/css-cascade-5/#used-value)
 [opacity](https://drafts.csswg.org/css-color-3/#opacity) is greater than zero.

 [NOTE:] this covers the case where a [typographical
 pseudo-element](https://drafts.csswg.org/css-pseudo-4#typographic-pseudos) would override the opacity of the text node.

- `target` is a [replaced
 element](https://drafts.csswg.org/css-display-4/#replaced-element) representing an
 [available](https://html.spec.whatwg.org/multipage/images.html#img-available)
 [image](https://html.spec.whatwg.org/multipage/images.html#images).

- `target` has a
 [background-image](https://www.w3.org/TR/css-backgrounds-3/#propdef-background-image) which is a [contentful
 image](#contentful-image),
 and its
 [used](https://drafts.csswg.org/css-cascade-5/#used-value)
 [background-size](https://www.w3.org/TR/css-backgrounds-3/#background-size) has non-zero width and height values.

- `target` has a
 [border-image-source](https://www.w3.org/TR/css-backgrounds-3/#propdef-border-image-source) which is a [contentful
 image](#contentful-image),
 and its
 [used](https://drafts.csswg.org/css-cascade-5/#used-value)
 [border-image-width](https://www.w3.org/TR/css-backgrounds-3/#border-image-width) has non-zero value.

- `target` is a
 [`canvas`](https://html.spec.whatwg.org/multipage/canvas.html#canvas) with its [context
 mode](https://html.spec.whatwg.org/multipage/canvas.html#concept-canvas-context-mode) set to any value other than `none`.

- `target` is a
 [`video`](https://html.spec.whatwg.org/multipage/media.html#video) element that
 [represents](https://html.spec.whatwg.org/multipage/dom.html#represents) its [poster
 frame](https://html.spec.whatwg.org/multipage/media.html#poster-frame) or the first video frame and the frame is available.

- `target` is an [svg element with rendered
 descendants](https://www.w3.org/TR/SVG2/render.html#Rendered-vs-NonRendered).

- `target` is an
 [`input`](https://html.spec.whatwg.org/multipage/input.html#the-input-element) element with a
 [non-empty](#non-empty)
 [`value`](https://html.spec.whatwg.org/multipage/input.html#attr-input-value) attribute.

- `target` is an [originating
 element](https://drafts.csswg.org/selectors-4/#originating-element) for a [paintable
 pseudo-element](#paintable-pseudo-element) that represents a [contentful
 image](#contentful-image)
 or [non-empty](#non-empty) text.

An
[element](https://dom.spec.whatwg.org/#concept-element) is [timing-eligible] if it is one of the following:

- an
 [`img`](https://html.spec.whatwg.org/multipage/embedded-content.html#the-img-element) element representing a [contentful
 image](#contentful-image).

- an
 [`image`](https://w3c.github.io/svgwg/svg2-draft/embedded.html#elementdef-image) element inside an
 [`svg`](https://w3c.github.io/svgwg/svg2-draft/struct.html#elementdef-svg) element.

- a
 [`video`](https://html.spec.whatwg.org/multipage/media.html#video) element with a [poster
 frame](https://html.spec.whatwg.org/multipage/media.html#poster-frame).

- an element has a
 [background-image](https://www.w3.org/TR/css-backgrounds-3/#propdef-background-image) which is a [contentful
 image](#contentful-image).

- a text node.

To compute the [paintable bounding rect] of
[element](https://dom.spec.whatwg.org/#concept-element) `target`, run the following steps:

1. Let `boundingRect` be the result of running the
 [`getBoundingClientRect()`](https://drafts.csswg.org/cssom-view-1/#dom-element-getboundingclientrect) on `target`.

2. Clip `boundingRect` with the
 [document](https://dom.spec.whatwg.org/#concept-document)'s [scrolling
 area](https://www.w3.org/TR/cssom-view#scrolling-area).

3. Return `boundingRect`.

[NOTE:] elements contained by boxes with
`overflow: scroll` or `overflow: hidden` don't
have their [paintable bounding
rect](#paintable-bounding-rect) clipped, as in both cases the
[element](https://dom.spec.whatwg.org/#concept-element) can become visible by scrolling.

An
[element](https://dom.spec.whatwg.org/#concept-element) `el` is [paintable] when all of the following
apply:

- `el` is [being
 rendered](https://html.spec.whatwg.org/multipage/rendering.html#being-rendered).

- `el`'s
 [used](https://drafts.csswg.org/css-cascade-5/#used-value)
 [visibility](https://drafts.csswg.org/css2/#propdef-visibility) is `visible`.

- `el` and all of its ancestors\'
 [used](https://drafts.csswg.org/css-cascade-5/#used-value)
 [opacity](https://drafts.csswg.org/css-color-3/#opacity) is greater than zero.

 [NOTE:] there could be cases where a `paintable`
 [element](https://dom.spec.whatwg.org/#concept-element) would not be visible to the user, for example in the
 case of text that has the same color as its background. Those elements
 would still be considered as paintable for the purpose of computing
 [first contentful
 paint](#first-contentful-paint).

- `el`'s [paintable bounding
 rect](#paintable-bounding-rect) intersects with the [scrolling
 area](https://www.w3.org/TR/cssom-view#scrolling-area) of the
 [document](https://dom.spec.whatwg.org/#concept-document).

 [NOTE:] This covers the cases where the element is scaled to
 zero size, has `display: none`, or
 `display: contents` where the contents resolve to an empty
 rect.

 [NOTE:] As a general rule, an
 [element](https://dom.spec.whatwg.org/#concept-element) is paintable if it is within the viewport, or can
 potentially be in the viewport as a result of scrolling or zooming.

[First paint]
entry contains a
[`DOMHighResTimeStamp`](https://w3c.github.io/hr-time/#typedefdef-domhighrestimestamp) reporting the time when the user agent first rendered
after navigation. This excludes the default background paint, but
includes non-default background paint and the enclosing box of a
[paintable](#paintable) iframe. This
is the first key moment developers care about in page load -- when the
user agent has started to render the page.

A [browsing
context](https://html.spec.whatwg.org/multipage/browsers.html#browsing-context) `ctx` is [paint-timing
eligible] when one of the following apply:

- `ctx` is a [top-level browsing
 context](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-browsing-context).

- `ctx` is a [nested browsing
 context](https://html.spec.whatwg.org/multipage/browsers.html#nested-browsing-context), and the user agent has configured `ctx`
 to report paint timing.

 [NOTE:] this allows user agents to enable paint-timing only
 for some of the frames, in addition to the main frame, if they so
 choose. For example, a user agent may decide to disable paint-timing
 for cross-origin iframes, as in some scenarios their paint-timing
 might reveal information about the main frame.

## 3. The Paint Timing Mixin

::: non-normative
*This section is non-normative.*

The
[`PaintTimingMixin`](#painttimingmixin) interface exposes timestamps related to the rendering
cycle. It is included in [platform
objects](https://webidl.spec.whatwg.org/#dfn-platform-object) that extend
[`PerformanceEntry`](https://w3c.github.io/performance-timeline/#performanceentry), specifically by
[`PerformanceElementTiming`](https://w3c.github.io/element-timing/#performanceelementtiming),
[`LargestContentfulPaint`](https://w3c.github.io/largest-contentful-paint/#largestcontentfulpaint),
[`PerformanceEventTiming`](https://w3c.github.io/event-timing/#performanceeventtiming),
[`PerformancePaintTiming`](#performancepainttiming), and
[`PerformanceLongAnimationFrameTiming`](https://w3c.github.io/long-animation-frames/#performancelonganimationframetiming).

The
[`paintTime`](#dom-painttimingmixin-painttime) attribute represents the timestamp at the end of the
[update the
rendering](https://html.spec.whatwg.org/multipage/webappapis.html#update-the-rendering) loop while the
[`presentationTime`](#dom-painttimingmixin-presentationtime) represents an implementation-specific timestamp marked
when the frame is presented to the user. The [mark paint
timing](#mark-paint-timing)
algorithm, called from [update the
rendering](https://html.spec.whatwg.org/multipage/webappapis.html#update-the-rendering) in the HTML standard, populates both attributes.

Attributes in entries that rely on paint timing, like
[`LargestContentfulPaint`](https://w3c.github.io/largest-contentful-paint/#largestcontentfulpaint)'s
[`renderTime`](https://w3c.github.io/largest-contentful-paint/#dom-largestcontentfulpaint-rendertime) (as well as its
[`startTime`](https://w3c.github.io/performance-timeline/#dom-performanceentry-starttime)), usually return the [default paint
timestamp](#default-paint-timestamp) rather than one of the specific timestamps, making them
agnostic to the implementation-specific nature of
[`presentationTime`](#dom-painttimingmixin-presentationtime).

### 3.1. The [`PaintTimingMixin` interface]
```
[Exposed=Window]
interface mixin PaintTimingMixin {
 readonly attribute DOMHighResTimeStamp paintTime;
 readonly attribute DOMHighResTimeStamp? presentationTime;
};
```

Objects including the
[`PaintTimingMixin`](#painttimingmixin) interface mixin have an associated [paint timing
info] (null or a [paint
timing info](#paint-timing-info)).

[paint timing info] is a
[struct](https://infra.spec.whatwg.org/#struct). It has the following
[items](https://infra.spec.whatwg.org/#struct-item):

[rendering update end time]

: A
 [`DOMHighResTimeStamp`](https://w3c.github.io/hr-time/#typedefdef-domhighrestimestamp)

[implementation-defined presentation time]

: Null or a
 [`DOMHighResTimeStamp`](https://w3c.github.io/hr-time/#typedefdef-domhighrestimestamp)

The
[`paintTime`](#dom-painttimingmixin-painttime) attribute's getter step is to return
[this](https://webidl.spec.whatwg.org/#this)'s [paint timing
info](#painttimingmixin-paint-timing-info)'s [rendering update end
time](#paint-timing-info-rendering-update-end-time).

The
[`presentationTime`](#dom-painttimingmixin-presentationtime) attribute's getter step, if exists, is to return
[this](https://webidl.spec.whatwg.org/#this)'s [paint timing
info](#painttimingmixin-paint-timing-info)'s [implementation-defined presentation
time](#paint-timing-info-implementation-defined-presentation-time).

To get the [default paint timestamp] for a [paint timing
info](#paint-timing-info)
`paintTimingInfo`, return `paintTimingInfo`'s
[implementation-defined presentation
time](#paint-timing-info-implementation-defined-presentation-time) if it is non-null, otherwise
`paintTimingInfo`'s [rendering update end
time](#paint-timing-info-rendering-update-end-time).

## 4. The [`PerformancePaintTiming` interface]
```
[Exposed=Window]
interface PerformancePaintTiming : PerformanceEntry {
 [Default] object toJSON();
};
PerformancePaintTiming includes PaintTimingMixin;
```

[`PerformancePaintTiming`](#performancepainttiming) extends the following attributes of
[`PerformanceEntry`](https://w3c.github.io/performance-timeline/#performanceentry) interface:

- The
 [`name`](https://w3c.github.io/performance-timeline/#dom-performanceentry-name) attribute's getter must return a
 [`DOMString`](https://webidl.spec.whatwg.org/#idl-DOMString) for minimal frame attribution. Possible values of
 name are:

 - `"first-paint"`: for [first
 paint](#first-paint)

 - `"first-contentful-paint"`: for [first contentful
 paint](#first-contentful-paint)

- The
 [`entryType`](https://w3c.github.io/performance-timeline/#dom-performanceentry-entrytype) attribute's getter must return `"paint"`.

- The
 [`startTime`](https://w3c.github.io/performance-timeline/#dom-performanceentry-starttime) attribute's getter must return a
 [`DOMHighResTimeStamp`](https://w3c.github.io/hr-time/#typedefdef-domhighrestimestamp) of when the paint occurred.

- The
 [`duration`](https://w3c.github.io/performance-timeline/#dom-performanceentry-duration) attribute's getter must return 0.

- When [toJSON] is called,
 run the [default toJSON
 steps](https://webidl.spec.whatwg.org/#default-tojson-steps) for
 [`PerformancePaintTiming`](#performancepainttiming).

[NOTE:] A user agent implementing
[`PerformancePaintTiming`](#performancepainttiming) would need to include `"paint"` in
[`supportedEntryTypes`](https://w3c.github.io/performance-timeline/#dom-performanceobserver-supportedentrytypes) of a [global
object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-realm-global) whose [browsing
context](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window-bc) is [paint-timing
eligible](#paint-timing-eligible). This allows developers to detect support for paint
timing for a particular [browsing
context](https://html.spec.whatwg.org/multipage/browsers.html#browsing-context).

## 5. Processing model

### 5.1. Associated Image Requests

Each
[`Element`](https://dom.spec.whatwg.org/#element) has an [associated image
request] which is an [image
request](https://html.spec.whatwg.org/multipage/images.html#image-request) or null, initially null.

When the processing model for an
[`Element`](https://dom.spec.whatwg.org/#element) *element* of type
[`HTMLImageElement`](https://html.spec.whatwg.org/multipage/embedded-content.html#htmlimageelement),
[`SVGImageElement`](https://w3c.github.io/svgwg/svg2-draft/embedded.html#svgimageelement), or
[`HTMLVideoElement`](https://html.spec.whatwg.org/multipage/media.html#htmlvideoelement) creates a new image resource (e.g., to be displayed as
an image or poster image), *element*'s [associated image
request](#associated-image-request) is set to the [image
request](https://html.spec.whatwg.org/multipage/images.html#image-request) of the created image resource.

 Every image resource that is obtained from a URL whose
[scheme](https://url.spec.whatwg.org/#concept-url-scheme) is equal to \"data\" has an associated [image
request](https://html.spec.whatwg.org/multipage/images.html#image-request) which is not fetched but still needs to be loaded. This
request can be the [associated image
request](#associated-image-request) of an
[`Element`](https://dom.spec.whatwg.org/#element).

 The current language is vague since it does not point
to specific algorithms. This can be made more rigorous when the
corresponding processing models have a more unified processing model.

Every
[`Element`](https://dom.spec.whatwg.org/#element) has a list of [associated background image
requests] which is initially an empty array. When the
processing model for the
[`Element`](https://dom.spec.whatwg.org/#element) *element*'s style requires a new image resource (to be
displayed as background image), the [image
request](https://html.spec.whatwg.org/multipage/images.html#image-request) created by the new resource is appended to *element*'s
[associated background image
requests](#associated-background-image-requests).

[NOTE:] An
[`Element`](https://dom.spec.whatwg.org/#element) can have several [image
requests](https://html.spec.whatwg.org/multipage/images.html#image-request), e.g. if its
[background-image](https://www.w3.org/TR/css-backgrounds-3/#propdef-background-image) property has multiple values. For instance, in the
following example, a single
[background-image](https://www.w3.org/TR/css-backgrounds-3/#propdef-background-image) property produces four [image
requests](https://html.spec.whatwg.org/multipage/images.html#image-request), each of which will be recorded and reported by the
algorithms below.

```
<!DOCTYPE html>
<style>
div {
 background-image: url(https://images.example/background1.png),
 url(https://images.example/background2.png);
}
</style>
<div></div>
<div></div>
```

### 5.2. Recording paint timing

A [pending image record] is a
[struct](https://infra.spec.whatwg.org/#struct) with the following
[items](https://infra.spec.whatwg.org/#struct-item):

- [element], an
 [`Element`](https://dom.spec.whatwg.org/#element)

- [request], an [image
 request](https://html.spec.whatwg.org/multipage/images.html#image-request)

- [loadTime], a
 [`DOMHighResTimeStamp`](https://w3c.github.io/hr-time/#typedefdef-domhighrestimestamp)

Each
[`Element`](https://dom.spec.whatwg.org/#element) has a [set of owned text
nodes], which is an [ordered
set](https://infra.spec.whatwg.org/#ordered-set) of
[`Text`](https://dom.spec.whatwg.org/#text) nodes, initially empty.

Each
[`Document`](https://dom.spec.whatwg.org/#document) has a [set of previously reported
paints], which is an [ordered
set](https://infra.spec.whatwg.org/#ordered-set) of
[strings](https://infra.spec.whatwg.org/#string), initially empty.

Each
[`Document`](https://dom.spec.whatwg.org/#document) has an [images pending
rendering], which is a
[list](https://infra.spec.whatwg.org/#list) of [pending image
records](#pending-image-record), initially empty.

Each
[`Document`](https://dom.spec.whatwg.org/#document) has a [set of elements with rendered
text], which is an [ordered
set](https://infra.spec.whatwg.org/#ordered-set) of
[`Element`](https://dom.spec.whatwg.org/#element)s, initially empty.

#### 5.2.1. Modifications to the CSS specification

Whenever an [image
request](https://html.spec.whatwg.org/multipage/images.html#image-request) in an
[`Element`](https://dom.spec.whatwg.org/#element) *element*'s [associated background image
requests](#associated-background-image-requests) becomes [completely
available](https://html.spec.whatwg.org/multipage/images.html#img-all), run the algorithm to [process an image that finished
loading](#process-an-image-that-finished-loading) with *element* and [image
request](https://html.spec.whatwg.org/multipage/images.html#image-request) as inputs.

#### 5.2.2. Modifications to the HTML specification

When an
[`Element`](https://dom.spec.whatwg.org/#element) *element*'s [associated image
request](#associated-image-request) has become [completely
available](https://html.spec.whatwg.org/multipage/images.html#img-all), run the algorithm to [process an image that finished
loading](#process-an-image-that-finished-loading) passing in *element* and its [associated image
request](#associated-image-request) as inputs.

When the user agent paints a
[`Text`](https://dom.spec.whatwg.org/#text) node `text` for the first time, it should
execute the following steps:

- If `text` will not be painted due to the font face being in
 its [font block
 period](https://drafts.csswg.org/css-fonts-4/#font-block-period), then return.

- Let `element` be the
 [`Element`](https://dom.spec.whatwg.org/#element) which determines the [containing
 block](https://drafts.csswg.org/css-display-4/#containing-block) of `text`.

- [Append](https://infra.spec.whatwg.org/#set-append) `text` to `element`'s [set of
 owned text
 nodes](#set-of-owned-text-nodes).

#### 5.2.3. Process image that finished loading

To [process an image that finished
loading] given an
[`Element`](https://dom.spec.whatwg.org/#element) `element` and an [image
request](https://html.spec.whatwg.org/multipage/images.html#image-request) `imageRequest`:

1. Let `root` be `element`'s
 [root](https://dom.spec.whatwg.org/#concept-tree-root).

2. If `root` is not a
 [`Document`](https://dom.spec.whatwg.org/#document), return.

3. Let `now` be the [current high resolution
 time](https://w3c.github.io/hr-time/#dfn-current-high-resolution-time) given `element`'s [relevant global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global).

4. Let `record` be a [pending image
 record](#pending-image-record) with
 [element](#pending-image-record-element) `element`,
 [request](#pending-image-record-request) `imageRequest` and
 [loadTime](#pending-image-record-loadtime) `now`.

5. Add `record` to `root`'s [images pending
 rendering](#images-pending-rendering).

### 5.3. Reporting paint timing

#### 5.3.1. First Contentful Paint

To know whether
[Document](https://dom.spec.whatwg.org/#concept-document) `document` [should report first contentful
paint], perform the following steps:

1. If `document`'s [set of previously reported
 paints](#set-of-previously-reported-paints) contains `"first-contentful-paint"`,
 then return false.

2. If `document` contains at least one
 [element](https://dom.spec.whatwg.org/#concept-element) that is both
 [paintable](#paintable) and
 [contentful](#contentful), then
 return true.

3. Otherwise, return false.

#### 5.3.2. Mark paint timing

When asked to [mark paint
timing](#mark-paint-timing)
given a
[Document](https://dom.spec.whatwg.org/#concept-document) `document` as input, perform the following
steps:

1. If the
 [document](https://dom.spec.whatwg.org/#concept-document)'s [browsing
 context](https://html.spec.whatwg.org/multipage/document-sequences.html#concept-document-bc) is not [paint-timing
 eligible](#paint-timing-eligible), return.

2. Let `paintTimingInfo` be a new [paint timing
 info](#paint-timing-info), whose [rendering update end
 time](#paint-timing-info-rendering-update-end-time) is the [current high resolution
 time](https://w3c.github.io/hr-time/#dfn-current-high-resolution-time) given `document`'s [relevant global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global).

3. Let `paintedImages` be a new [ordered
 set](https://infra.spec.whatwg.org/#ordered-set)

4. Let `paintedTextNodes` be a new [ordered
 set](https://infra.spec.whatwg.org/#ordered-set)

5. For each `record` in `doc`'s [images pending
 rendering](#images-pending-rendering) list:

 1. If `record`'s
 [request](#pending-image-record-request) is
 [available](https://html.spec.whatwg.org/multipage/images.html#img-available) and ready to be painted, then run the following
 steps:

 1. Append `record` to `paintedImages`.

 2. Remove `record` from `doc`'s [images
 pending
 rendering](#images-pending-rendering) list.

6. For each
 [`Element`](https://dom.spec.whatwg.org/#element) `element` in `doc`'s
 [descendants](https://dom.spec.whatwg.org/#concept-tree-descendant):

 1. If `element` is contained in `doc`'s [set
 of elements with rendered
 text](#set-of-elements-with-rendered-text), continue.

 2. If `element`'s [set of owned text
 nodes](#set-of-owned-text-nodes) is empty, continue.

 3. [Append](https://infra.spec.whatwg.org/#set-append) `element` to `doc`'s [set
 of elements with rendered
 text](#set-of-elements-with-rendered-text).

 4. [Append](https://infra.spec.whatwg.org/#set-append) `element` to
 `paintedTextNodes`.

7. Let `reportedPaints` be the `document`'s [set
 of previously reported
 paints](#set-of-previously-reported-paints).

8. Let `frameTimingInfo` be `document`'s [current
 frame timing
 info](https://w3c.github.io/long-animation-frames/#current-frame-timing-info).

9. Set `document`'s [current frame timing
 info](https://w3c.github.io/long-animation-frames/#current-frame-timing-info) to null.

10. Let `flushPaintTimings` be the following steps:

 1. If `reportedPaints` does not contain
 `"first-paint"`, and the user agent is configured to
 mark [first paint](#first-paint), then [report paint
 timing](#report-paint-timing) given `document`,
 `"first-paint"`, and `paintTimingInfo`.

 [NOTE:] [First
 paint](#first-paint)
 excludes the default background paint, but includes non-default
 background paint.

 (#issue-6cf50d70) This should be turned into a
 normative note.

 2. If `document` [should report first contentful
 paint](#should-report-first-contentful-paint), then:

 1. [Report paint
 timing](#report-paint-timing) given `document`,
 `"first-contentful-paint"`, and
 `paintTimingInfo`.

 [NOTE:] A parent frame should not be aware of the paint
 events from its child iframes, and vice versa. This means that a
 frame that contains just iframes will have [first
 paint](#first-paint) (due
 to the enclosing boxes of the
 [paintable](#paintable)
 iframes) but no [first contentful
 paint](#first-contentful-paint).

 [NOTE:] A
 [document](https://dom.spec.whatwg.org/#concept-document) is not guaranteed to mark
 `"first-paint"` or
 `"first-contentful-paint"`. A completely blank
 [document](https://dom.spec.whatwg.org/#concept-document) may never mark [first
 paint](#first-paint), and
 a
 [document](https://dom.spec.whatwg.org/#concept-document) containing only elements that are not
 [contentful](#contentful)
 may never mark [first contentful
 paint](#first-contentful-paint).

 [NOTE:] The marking of [first
 paint](#first-paint) is
 optional. User-agents implementing paint timing should at the
 very least mark [first contentful
 paint](#first-contentful-paint).

 3. [Report largest contentful
 paint](https://wicg.github.io/largest-contentful-paint/#report-largest-contentful-paint) given `document`,
 `paintTimingInfo`, `paintedImages` and
 `paintedTextNodes`.

 4. [Report element
 timing](https://wicg.github.io/element-timing/#report-element-timing) given `document`,
 `paintTimingInfo`, `paintedImages` and
 `paintedTextNodes`.

 5. If `frameTimingInfo` is not null, then [queue a long
 animation frame
 entry](https://w3c.github.io/long-animation-frames/#queue-a-long-animation-frame-entry) given `document`,
 `frameTimingInfo`, and `paintTimingInfo`.

11. If the user-agent does not support implementation-defined
 presentation times, call `flushPaintTimings` and return.

12. Run the following steps [In
 parallel](https://html.spec.whatwg.org/multipage/infrastructure.html#in-parallel):

 1. Wait until an implementation-defined time when the current frame
 has been presented to the user.

 2. Set `paintTimingInfo`'s [implementation-defined
 presentation
 time](#paint-timing-info-implementation-defined-presentation-time) to the [current high resolution
 time](https://w3c.github.io/hr-time/#dfn-current-high-resolution-time) given `document`'s [relevant global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global).

 3. If `document`'s [cross-origin isolated
 capability](https://html.spec.whatwg.org/multipage/webappapis.html#concept-settings-object-cross-origin-isolated-capability) is false, then:

 1. Coarsen `paintTimingInfo`'s
 [implementation-defined presentation
 time](#paint-timing-info-implementation-defined-presentation-time) to the next multiple of 4 milliseconds, or
 coarser.

 2. Wait until the [current high resolution
 time](https://w3c.github.io/hr-time/#dfn-current-high-resolution-time) is `paintTimingInfo`'s
 [implementation-defined presentation
 time](#paint-timing-info-implementation-defined-presentation-time).

 4. [Queue a global
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-global-task) on the [performance timeline task
 source](https://w3c.github.io/performance-timeline/#dfn-performance-timeline-task-source) given `document`'s [relevant global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global) to run `flushPaintTimings`.

#### 5.3.3. Report paint timing

To [report paint
timing](#report-paint-timing) given `document`, `paintType`,
and a [paint timing
info](#paint-timing-info)
`paintTimingInfo` as arguments, perform the following steps:

1. Create a [new](https://webidl.spec.whatwg.org/#new)
 [`PerformancePaintTiming`](#performancepainttiming) object `newEntry` with
 `document`'s [relevant
 realm](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-realm) and set its attributes as follows:

 1. Set `newEntry`'s
 [`name`](https://w3c.github.io/performance-timeline/#dom-performanceentry-name) attribute to `paintType`.

 2. Set `newEntry`'s
 [`entryType`](https://w3c.github.io/performance-timeline/#dom-performanceentry-entrytype) attribute to `"paint"`.

 3. Set `newEntry`'s
 [`startTime`](https://w3c.github.io/performance-timeline/#dom-performanceentry-starttime) attribute to the [default paint
 timestamp](#default-paint-timestamp) given `paintTimingInfo`.

 4. Set `newEntry`'s
 [`duration`](https://w3c.github.io/performance-timeline/#dom-performanceentry-duration) attribute to 0.

2. Set `newEntry`'s [paint timing
 info](#painttimingmixin-paint-timing-info) to `paintTimingInfo`.

3. [Queue](https://w3c.github.io/performance-timeline/#dfn-queue-a-performanceentry) `newEntry` in `document`'s
 [relevant
 realm](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-realm).

4. [Append](https://infra.spec.whatwg.org/#list-append) `paintType` to `document`'s
 [set of previously reported
 paints](#set-of-previously-reported-paints).

### 5.4. Common algorithms

#### 5.4.1. Exposed for paint timing

To determine whether a
[Node](https://dom.spec.whatwg.org/#concept-node) `node` is [exposed for paint
timing](#exposed-for-paint-timing), given a
[Document](https://dom.spec.whatwg.org/#concept-document) or null `document`, perform the following
steps:

1. If `node` is not
 [connected](https://dom.spec.whatwg.org/#connected), return false.

2. If `document` is null, let `document` be
 `node`'s [relevant settings
 object](https://html.spec.whatwg.org/multipage/webappapis.html#relevant-settings-object)'s [relevant global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global)'s [associated
 document](https://html.spec.whatwg.org/multipage/nav-history-apis.html#concept-document-window).

3. If `document` is not [fully
 active](https://html.spec.whatwg.org/multipage/document-sequences.html#fully-active), return false.

4. If `node`'s
 [root](https://dom.spec.whatwg.org/#concept-tree-root) is not equal to `document`, return
 false.

5. Return true.

## 6. Acknowledgements

Special thanks to [all the
contributors](https://github.com/w3c/paint-timing/graphs/contributors)
for their technical input and suggestions that led to improvements to
this specification.
