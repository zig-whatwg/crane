## 1. Introduction

The web's traditional position calculation mechanisms rely on explicit
queries of DOM state that are known to cause (expensive) style
recalculation and layout and, frequently, are a source of significant
performance overhead due to continuous polling for this information.

A body of common practice has evolved that relies on these behaviors,
however, including (but not limited to):

- Building custom pre- and deferred-loading of DOM and data.

- Implementing data-bound high-performance scrolling lists which load
 and render subsets of data sets. These lists are a central mobile
 interaction idiom.

- Calculating element visibility. In particular, [ad networks now
 require reporting of ad \"visibility\" for monetizing
 impressions](http://www.iab.net/iablog/2014/03/viewability-has-arrived-what-you-need-to-know-to-see-through-this-sea-change.html).
 This has led to many sites abusing scroll handlers (causing jank on
 scroll), [synchronous layout invoking
 readbacks](http://gent.ilcore.com/2011/03/how-not-to-trigger-layout-in-webkit.html)
 (causing unnecessary critical work in rAF loops), and resorting to
 exotic plugin-based solutions for computing \"true\" element
 visibility (with all the associated overhead of the plugin
 architecture).

These use-cases have several common properties:

1. They can be represented as passive \"queries\" about the state of
 individual elements with respect to some other element (or the
 global
 [viewport](https://drafts.csswg.org/css2/visuren.html#viewport)).

2. They do not impose hard latency requirements; that is to say, the
 information can be delivered asynchronously (e.g. from another
 thread) without penalty.

3. They are poorly supported by nearly all combinations of existing web
 platform features, requiring extraordinary developer effort despite
 their widespread use.

A notable non-goal is pixel-accurate information about what was actually
displayed (which can be quite difficult to obtain efficiently in certain
browser architectures in the face of filters, webgl, and other
features). In all of these scenarios the information is useful even when
delivered at a slight delay and without perfect compositing-result data.

The Intersection Observer API addresses the above issues by giving
developers a new method to asynchronously query the position of an
element with respect to other elements or the global
[viewport](https://drafts.csswg.org/css2/visuren.html#viewport). The asynchronous delivery eliminates the need for
costly DOM and style queries, continuous polling, and use of custom
plugins. By removing the need for these methods it allows applications
to significantly reduce their CPU, GPU and energy costs.

``` highlight
var observer = new IntersectionObserver(changes => {
 for (const change of changes) {
 console.log(change.time); // Timestamp when the change occurred
 console.log(change.rootBounds); // Unclipped area of root
 console.log(change.boundingClientRect); // target.getBoundingClientRect()
 console.log(change.intersectionRect); // boundingClientRect, clipped by its containing block ancestors, and intersected with rootBounds
 console.log(change.intersectionRatio); // Ratio of intersectionRect area to boundingClientRect area
 console.log(change.target); // the Element target
 }
}, );

// Watch for intersection events on a specific target Element.
observer.observe(target);

// Stop watching for intersection events on a specific target Element.
observer.unobserve(target);

// Stop observing threshold events on all target elements.
observer.disconnect();
```

## 2. Intersection Observer

The [Intersection Observer] API enables developers to understand the
visibility and position of [target]
DOM elements relative to an [intersection
root](#intersectionobserver-intersection-root).

### 2.1. The IntersectionObserverCallback

```
callback IntersectionObserverCallback = undefined (sequence<IntersectionObserverEntry> entries, IntersectionObserver observer);
```

This callback will be invoked when there are changes to a
[target](#intersectionobserver-target)'s intersection with the [intersection
root](#intersectionobserver-intersection-root), as per the [processing
model](#intersection-observer-processing-model).

### 2.2. The IntersectionObserver interface

The
[`IntersectionObserver`](#intersectionobserver) interface can be used to observe changes in the
intersection of an [intersection
root](#intersectionobserver-intersection-root) and one or more
[target](#intersectionobserver-target)
[`Element`](https://dom.spec.whatwg.org/#element)s.

The [intersection root]
for an
[`IntersectionObserver`](#intersectionobserver) is the value of its
[`root`](#dom-intersectionobserver-root) attribute if the attribute is non-`null`; otherwise, it
is the [top-level browsing
context](https://html.spec.whatwg.org/multipage/browsers.html#top-level-browsing-context)'s
[`document`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#dom-document-2) node, referred to as the [implicit
root].

An
[`IntersectionObserver`](#intersectionobserver) with a non-`null`
[`root`](#dom-intersectionobserver-root) is referred to as an [explicit root
observer], and it can
observe any
[target](#intersectionobserver-target)
[`Element`](https://dom.spec.whatwg.org/#element) that is a descendant of the
[`root`](#dom-intersectionobserver-root) in the [containing block
chain](https://drafts.csswg.org/css-display/#containing-block-chain). An
[`IntersectionObserver`](#intersectionobserver) with a `null`
[`root`](#dom-intersectionobserver-root) is referred to as an [implicit root
observer]. Valid
[target]s for an [implicit root
observer](#intersectionobserver-implicit-root-observer) include any
[`Element`](https://dom.spec.whatwg.org/#element) in the [top-level browsing
context](https://html.spec.whatwg.org/multipage/browsers.html#top-level-browsing-context), as well as any
[`Element`](https://dom.spec.whatwg.org/#element) in any [nested browsing
context](https://html.spec.whatwg.org/multipage/browsers.html#nested-browsing-context) which is in the [list of the descendant browsing
contexts](https://html.spec.whatwg.org/multipage/browsers.html#list-of-the-descendant-browsing-contexts) of the [top-level browsing
context].

When dealing with [implicit root
observers](#intersectionobserver-implicit-root-observer), the API makes a distinction between a
[target](#intersectionobserver-target) whose [relevant settings
object](https://html.spec.whatwg.org/multipage/webappapis.html#relevant-settings-object)'s
[origin](https://html.spec.whatwg.org/multipage/origin.html#origin) is [same
origin-domain](https://html.spec.whatwg.org/multipage/browsers.html#same-origin-domain) with the [top-level
origin](https://html.spec.whatwg.org/multipage/webappapis.html#concept-environment-top-level-origin), referred to as a [same-origin-domain
target];
as opposed to a [cross-origin-domain
target].
Any [target] of an [explicit root
observer](#intersectionobserver-explicit-root-observer) is also a [same-origin-domain
target](#intersectionobserver-same-origin-domain-target), since the
[target] must be in the same
[document](https://html.spec.whatwg.org/multipage/dom.html#document) as the [intersection
root](#intersectionobserver-intersection-root).

 In
[`MutationObserver`](https://dom.spec.whatwg.org/#mutationobserver), the
[`MutationObserverInit`](https://dom.spec.whatwg.org/#dictdef-mutationobserverinit) options are passed to
[`observe()`](https://dom.spec.whatwg.org/#dom-mutationobserver-observe) while in
[`IntersectionObserver`](#intersectionobserver) they are passed to the constructor. This is because for
MutationObserver, each
[`Node`](https://dom.spec.whatwg.org/#node) being observed could have a different set of attributes
to filter for. For
[`IntersectionObserver`](#intersectionobserver), developers may choose to use a single observer to
track multiple targets using the same set of options; or they may use a
different observer for each tracked target.
[`rootMargin`](#dom-intersectionobserverinit-rootmargin) or
[`threshold`](#dom-intersectionobserverinit-threshold) values for each
[target](#intersectionobserver-target) seems to introduce more complexity without solving
additional use-cases.
Per-[`observe()`](#dom-intersectionobserver-observe) options could be provided in the future if the need
arises.

```
[Exposed=Window]
interface IntersectionObserver {
 constructor(IntersectionObserverCallback callback, optional IntersectionObserverInit options = );
 readonly attribute (Element or Document)? root;
 readonly attribute DOMString rootMargin;
 readonly attribute DOMString scrollMargin;
 readonly attribute FrozenArray<double> thresholds;
 readonly attribute long delay;
 readonly attribute boolean trackVisibility;
 undefined observe(Element target);
 undefined unobserve(Element target);
 undefined disconnect();
 sequence<IntersectionObserverEntry> takeRecords();
};
```

[` new IntersectionObserver(callback, options)`])"}

: Return the result of running the [initialize a new
 IntersectionObserver](#initialize-a-new-intersectionobserver) algorithm, providing `callback` and
 `options`.

[`observe(target)`]

: Run the [observe a target
 Element](#observe-a-target-element) algorithm, providing `this` and
 `target`.

[`unobserve(target)`]

: Run the [unobserve a target
 Element](#unobserve-a-target-element) algorithm, providing `this` and
 `target`.

 [`MutationObserver`](https://dom.spec.whatwg.org/#mutationobserver) does not implement
 [`unobserve()`](#dom-intersectionobserver-unobserve). For
 [`IntersectionObserver`](#intersectionobserver),
 [`unobserve()`](#dom-intersectionobserver-unobserve) addresses the lazy-loading use case. After loading
 is initiated for `target`, it does not need to be
 tracked. It would be more work to either
 [`disconnect()`](#dom-intersectionobserver-disconnect) all `target`s and
 [`observe()`](#dom-intersectionobserver-observe) the remaining ones, or create a separate
 [`IntersectionObserver`](#intersectionobserver) for each `target`.

[`disconnect()`]

: For each `target` in `this`'s internal
 [`[[ObservationTargets]]`](#dom-intersectionobserver-observationtargets-slot) slot:

 1. Remove the
 [`IntersectionObserverRegistration`](#intersectionobserverregistration) record whose
 [`observer`](#dom-intersectionobserverregistration-observer) property is equal to `this` from
 `target`'s internal
 [`[[RegisteredIntersectionObservers]]`](#dom-element-registeredintersectionobservers-slot) slot.

 2. Remove `target` from `this`'s internal
 [`[[ObservationTargets]]`](#dom-intersectionobserver-observationtargets-slot) slot.

[`takeRecords()`]

: 1. Let `queue` be a copy of `this`'s internal
 [`[[QueuedEntries]]`](#dom-intersectionobserver-queuedentries-slot) slot.

 2. Clear `this`'s internal
 [`[[QueuedEntries]]`](#dom-intersectionobserver-queuedentries-slot) slot.

 3. Return `queue`.

[`root`], of type `(Element or Document)`, readonly, nullable

: The
 [`root`](#dom-intersectionobserverinit-root) provided to the
 [`IntersectionObserver`](#intersectionobserver) constructor, or `null` if none was provided.

[`rootMargin`], of type [DOMString](https://webidl.spec.whatwg.org/#idl-DOMString), readonly

: Offsets applied to the [root intersection
 rectangle](#intersectionobserver-root-intersection-rectangle), effectively growing or shrinking the box that is
 used to calculate intersections. **These offsets are only applied
 when handling [same-origin-domain
 targets](#intersectionobserver-same-origin-domain-target); for [cross-origin-domain
 targets](#intersectionobserver-cross-origin-domain-target) they are ignored.**

 On getting, return the result of serializing the elements of
 [`[[rootMargin]]`](#dom-intersectionobserver-rootmargin-slot) space-separated, where pixel lengths serialize as
 the numeric value followed by \"px\", and percentages serialize as
 the numeric value followed by \"%\". Note that this is not
 guaranteed to be identical to the
 `options`.[`rootMargin`](#dom-intersectionobserverinit-rootmargin) passed to the
 [`IntersectionObserver`](#intersectionobserver) constructor. If no
 [`rootMargin`](#dom-intersectionobserverinit-rootmargin) was passed to the
 [`IntersectionObserver`](#intersectionobserver) constructor, the value of this attribute is \"0px
 0px 0px 0px\".

[`scrollMargin`], of type [DOMString](https://webidl.spec.whatwg.org/#idl-DOMString), readonly

: Offsets are applied to
 [scrollports](https://drafts.csswg.org/css-overflow-3/#scrollport) on the path from [intersection
 root](#intersectionobserver-intersection-root) to
 [target](#intersectionobserver-target), effectively growing or shrinking the clip rects
 used to calculate intersections.

 On getting, return the result of serializing the elements of
 [`[[scrollMargin]]`](#dom-intersectionobserver-scrollmargin-slot) space-separated, where pixel lengths serialize as
 the numeric value followed by \"px\", and percentages serialize as
 the numeric value followed by \"%\". Note that this is not
 guaranteed to be identical to the
 `options`.[`scrollMargin`](#dom-intersectionobserverinit-scrollmargin) passed to the
 [`IntersectionObserver`](#intersectionobserver) constructor. If no
 [`scrollMargin`](#dom-intersectionobserverinit-scrollmargin) was passed to the
 [`IntersectionObserver`](#intersectionobserver) constructor, the value of this attribute is \"0px
 0px 0px 0px\".

[`thresholds`], of type FrozenArray\<[double](https://heycam.github.io/webidl/#idl-double)\>, readonly

: A list of thresholds, sorted in increasing numeric order, where each
 threshold is a ratio of intersection area to bounding box area of an
 observed target. Notifications for a target are generated when any
 of the thresholds are crossed for that target. If no
 `options`.[`threshold`](#dom-intersectionobserverinit-threshold) was provided to the
 [`IntersectionObserver`](#intersectionobserver) constructor, or the sequence is empty, the value of
 this attribute will be \[0\].

[`delay`], of type [long](https://webidl.spec.whatwg.org/#idl-long), readonly

: A number indicating the minimum delay in milliseconds between
 notifications from this observer for a given target.

[`trackVisibility`], of type [boolean](https://webidl.spec.whatwg.org/#idl-boolean), readonly

: A boolean indicating whether this
 [`IntersectionObserver`](#intersectionobserver) will track changes in a target's
 [visibility](#visibility).

[`Element`](https://dom.spec.whatwg.org/#element) is defined as having a [content
clip] if its
computed style has [overflow
properties](https://drafts.csswg.org/css-overflow-3/#overflow-properties) that cause its content to be clipped to the element's
[padding
edge](https://drafts.csswg.org/css-box/#padding-edge).

The [root intersection
rectangle]
for an
[`IntersectionObserver`](#intersectionobserver) is the rectangle we'll use to check against the
targets.

If the [`IntersectionObserver`](#intersectionobserver) is an [implicit root observer](#intersectionobserver-implicit-root-observer),
: it's treated as if the root were the [top-level browsing
 context](https://html.spec.whatwg.org/multipage/browsers.html#top-level-browsing-context)'s
 [`document`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#dom-document-2), according to the following rule for
 [`document`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#dom-document-2).

If the [intersection root](#intersectionobserver-intersection-root) is a [`document`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#dom-document-2),
: it's the size of the
 [`document`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#dom-document-2)'s
 [viewport](https://drafts.csswg.org/css2/visuren.html#viewport) (note that this processing step can only be reached
 if the
 [`document`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#dom-document-2) is [fully
 active](https://html.spec.whatwg.org/multipage/browsers.html#fully-active)).

Otherwise, if the [intersection root](#intersectionobserver-intersection-root) has a [content clip](#intersectionobserver-content-clip),
: it's the element's [padding
 area](https://drafts.csswg.org/css-box/#padding-area).

Otherwise,
: it's the result of [getting the bounding
 box](https://drafts.csswg.org/cssom-view-1/#element-get-the-bounding-box) for the [intersection
 root](#intersectionobserver-intersection-root).

When calculating the [root intersection
rectangle](#intersectionobserver-root-intersection-rectangle) for a [same-origin-domain
target](#intersectionobserver-same-origin-domain-target), the rectangle is then expanded according to the
offsets in the
[`IntersectionObserver`](#intersectionobserver)'s
[`[[rootMargin]]`](#dom-intersectionobserver-rootmargin-slot) slot in a manner similar to CSS's
[margin](https://drafts.csswg.org/css-box-4/#propdef-margin) property, with the four values
indicating the amount the top, right, bottom, and left edges,
respectively, are offset by, with positive lengths indicating an outward
offset. Percentages are resolved relative to the width of the undilated
rectangle.

[`rootMargin`](#dom-intersectionobserver-rootmargin) only applies to the [intersection
root](#intersectionobserver-intersection-root) itself. If a
[target](#intersectionobserver-target)
[`Element`](https://dom.spec.whatwg.org/#element) is clipped by an ancestor other than the [intersection
root], that clipping
is unaffected by
[`rootMargin`](#dom-intersectionobserver-rootmargin).

To [apply scroll margin to a scrollport]

: When calculating a
 [scrollport](https://drafts.csswg.org/css-overflow-3/#scrollport) intersection rectangle for a [same-origin-domain
 target](#intersectionobserver-same-origin-domain-target), the rectangle is expanded according to the offsets
 in the
 [`IntersectionObserver`](#intersectionobserver)'s
 [`[[scrollMargin]]`](#dom-intersectionobserver-scrollmargin-slot) slot in a manner similar to CSS's
 [margin](https://drafts.csswg.org/css-box-4/#propdef-margin) property, with the four values
 indicating the amount the top, right, bottom, and left edges,
 respectively, are offset by, with positive lengths indicating an
 outward offset. Percentages are resolved relative to the width of
 the undilated rectangle.

 **These offsets are only applied when handling [same-origin-domain
 targets](#intersectionobserver-same-origin-domain-target); for [cross-origin-domain
 targets](#intersectionobserver-cross-origin-domain-target) they are ignored.**

 [`scrollMargin`](#dom-intersectionobserver-scrollmargin) affects the clipping of
 [target](#intersectionobserver-target) by all scrollable ancestors up to and including the
 [intersection
 root](#intersectionobserver-intersection-root). Both the
 [`scrollMargin`](#dom-intersectionobserver-scrollmargin) and the
 [`rootMargin`](#dom-intersectionobserver-rootmargin) are applied to a scrollable [intersection
 root's]
 rectangle.

 [Root intersection
rectangle](#intersectionobserver-root-intersection-rectangle) and
[scrollport](https://drafts.csswg.org/css-overflow-3/#scrollport) intersection rectangles are not affected by [pinch
zoom](https://drafts.csswg.org/cssom-view-1/#pinch-zoom) and will report the unadjusted
[viewport](https://drafts.csswg.org/css2/visuren.html#viewport), consistent with the intent of pinch zooming (to act
like a magnifying glass and NOT change layout.)

To [parse a margin] (root or scroll) from an input string
`marginString`, returning either a list of 4 pixel lengths or
percentages, or failure:

1. [Parse a list of component
 values](https://drafts.csswg.org/css-syntax-3/#parse-a-list-of-component-values) `marginString`, storing the result as
 `tokens`.

2. Remove all whitespace tokens from `tokens`.

3. If the length of `tokens` is greater than 4, return
 failure.

4. If there are zero elements in `tokens`, set
 `tokens` to \[\"0px\"\].

5. Replace each `token` in `tokens`:

 - If `token` is an [absolute
 length](https://drafts.csswg.org/css-values-3/#absolute-length)
 [dimension](https://drafts.csswg.org/css-values-3/#dimension) token, replace it with a an equivalent pixel
 length.

 - If `token` is a
 [\<percentage\>](https://drafts.csswg.org/css-values-4/#percentage-value) token, replace it with an
 equivalent percentage.

 - Otherwise, return failure.

6. If there is one element in `tokens`, append three
 duplicates of that element to `tokens`. Otherwise, if
 there are two elements are `tokens`, append a duplicate
 of each element to `tokens`. Otherwise, if there are
 three elements in `tokens`, append a duplicate of the
 second element to `tokens`.

7. Return `tokens`.

### 2.3. The IntersectionObserverEntry interface

```
[Exposed=Window]
interface IntersectionObserverEntry {
 constructor(IntersectionObserverEntryInit intersectionObserverEntryInit);
 readonly attribute DOMHighResTimeStamp time;
 readonly attribute DOMRectReadOnly? rootBounds;
 readonly attribute DOMRectReadOnly boundingClientRect;
 readonly attribute DOMRectReadOnly intersectionRect;
 readonly attribute boolean isIntersecting;
 readonly attribute boolean isVisible;
 readonly attribute double intersectionRatio;
 readonly attribute Element target;
};

dictionary IntersectionObserverEntryInit {
 required DOMHighResTimeStamp time;
 required DOMRectInit? rootBounds;
 required DOMRectInit boundingClientRect;
 required DOMRectInit intersectionRect;
 required boolean isIntersecting;
 required boolean isVisible;
 required double intersectionRatio;
 required Element target;
};
```

[`boundingClientRect`], of type [DOMRectReadOnly](https://drafts.csswg.org/geometry-1/#domrectreadonly), readonly

: A
 [`DOMRectReadOnly`](https://drafts.csswg.org/geometry-1/#domrectreadonly) obtained by [getting the bounding
 box](https://drafts.csswg.org/cssom-view-1/#element-get-the-bounding-box) for
 [`target`](#dom-intersectionobserverentry-target).

[`intersectionRect`], of type [DOMRectReadOnly](https://drafts.csswg.org/geometry-1/#domrectreadonly), readonly

: [`boundingClientRect`](#dom-intersectionobserverentry-boundingclientrect), intersected by each of
 [`target`](#dom-intersectionobserverentry-target)'s ancestors\' clip rects (up to but not including
 [`root`](#dom-intersectionobserver-root)), intersected with the [root intersection
 rectangle](#intersectionobserver-root-intersection-rectangle). This value represents the portion of
 [`target`](#dom-intersectionobserverentry-target) that intersects with the [root intersection
 rectangle].

[`isIntersecting`], of type [boolean](https://webidl.spec.whatwg.org/#idl-boolean), readonly

: True if the
 [`target`](#dom-intersectionobserverentry-target) intersects with the
 [`root`](#dom-intersectionobserver-root); false otherwise. This flag makes it possible to
 distinguish between an
 [`IntersectionObserverEntry`](#intersectionobserverentry) signalling the transition from intersecting to
 not-intersecting; and an
 [`IntersectionObserverEntry`](#intersectionobserverentry) signalling a transition from not-intersecting to
 intersecting with a zero-area intersection rect (as will happen with
 edge-adjacent intersections, or when the
 [`boundingClientRect`](#dom-intersectionobserverentry-boundingclientrect) has zero area).

[`isVisible`], of type [boolean](https://webidl.spec.whatwg.org/#idl-boolean), readonly

: Contains the result of running the
 [visibility](#visibility)
 algorithm on
 [`target`](#dom-intersectionobserverentry-target).

[`intersectionRatio`], of type [double](https://heycam.github.io/webidl/#idl-double), readonly

: If the
 [`boundingClientRect`](#dom-intersectionobserverentry-boundingclientrect) has non-zero area, this will be the ratio of
 [`intersectionRect`](#dom-intersectionobserverentry-intersectionrect) area to
 [`boundingClientRect`](#dom-intersectionobserverentry-boundingclientrect) area. Otherwise, this will be 1 if the
 [`isIntersecting`](#dom-intersectionobserverentry-isintersecting) is true, and 0 if not.

[`rootBounds`], of type [DOMRectReadOnly](https://drafts.csswg.org/geometry-1/#domrectreadonly), readonly, nullable

: For a [same-origin-domain
 target](#intersectionobserver-same-origin-domain-target), this will be the [root intersection
 rectangle](#intersectionobserver-root-intersection-rectangle). Otherwise, this will be `null`. Note that if the
 target is in a different [browsing
 context](https://html.spec.whatwg.org/multipage/browsers.html#browsing-context) than the [intersection
 root](#intersectionobserver-intersection-root), this will be in a different coordinate system than
 [`boundingClientRect`](#dom-intersectionobserverentry-boundingclientrect) and
 [`intersectionRect`](#dom-intersectionobserverentry-intersectionrect).

[`target`], of type [Element](https://dom.spec.whatwg.org/#element), readonly

: The
 [`Element`](https://dom.spec.whatwg.org/#element) whose intersection with the [intersection
 root](#intersectionobserver-intersection-root) changed.

[`time`], of type [DOMHighResTimeStamp](http://www.w3.org/TR/hr-time/#domhighrestimestamp), readonly

: The attribute must return a
 [`DOMHighResTimeStamp`](http://www.w3.org/TR/hr-time/#domhighrestimestamp) that corresponds to the time the intersection was
 recorded, relative to the [time
 origin](http://www.w3.org/TR/hr-time/#time-origin) of the global object associated with the
 IntersectionObserver instance that generated the notification.

### 2.4. The IntersectionObserverInit dictionary

```
dictionary IntersectionObserverInit {
 (Element or Document)? root = null;
 DOMString rootMargin = "0px";
 DOMString scrollMargin = "0px";
 (double or sequence<double>) threshold = 0;
 long delay = 0;
 boolean trackVisibility = false;
};
```

[`root`], of type `(Element or Document)`, nullable, defaulting to `null`

: The
 [`root`](#intersectionobserver) to use for intersection. If not provided, use the
 [implicit
 root](#intersectionobserver-implicit-root).

[`rootMargin`], of type [DOMString](https://webidl.spec.whatwg.org/#idl-DOMString), defaulting to `"0px"`

: Similar to the CSS
 [margin](https://drafts.csswg.org/css-box-4/#propdef-margin) property, this is a string of
 1-4 components, each either an [absolute
 length](https://drafts.csswg.org/css-values-3/#absolute-length) or a percentage.

 ```
 "5px" // all margins set to 5px
 "5px 10px" // top & bottom = 5px, right & left = 10px
 "-10px 5px 8px" // top = -10px, right & left = 5px, bottom = 8px
 "-10px -5px 5px 8px" // top = -10px, right = -5px, bottom = 5px, left = 8px
 ```

[`scrollMargin`], of type [DOMString](https://webidl.spec.whatwg.org/#idl-DOMString), defaulting to `"0px"`

: Similar to
 [`rootMargin`](#dom-intersectionobserverinit-rootmargin), this is a string of 1-4 components, each either an
 [absolute
 length](https://drafts.csswg.org/css-values-3/#absolute-length) or a percentage.

 See
 [`rootMargin`](#dom-intersectionobserverinit-rootmargin) above for the example.

[`threshold`], of type `(double or sequence<double>)`, defaulting to `0`

: List of threshold(s) at which to trigger callback. callback will be
 invoked when intersectionRect's area changes from greater than or
 equal to any threshold to less than that threshold, and vice versa.

 Threshold values must be in the range of \[0, 1.0\] and represent a
 percentage of the area of the rectangle produced by [getting the
 bounding
 box](https://drafts.csswg.org/cssom-view-1/#element-get-the-bounding-box) for
 [target](#intersectionobserver-target).

 0.0 is effectively \"any non-zero number of
 pixels\".

[`delay`], of type [long](https://webidl.spec.whatwg.org/#idl-long), defaulting to `0`

: A number specifying the minimum delay in milliseconds between
 notifications from the observer for a given target.

[`trackVisibility`], of type [boolean](https://webidl.spec.whatwg.org/#idl-boolean), defaulting to `false`

: A boolean indicating whether the observer should track
 [visibility](#visibility).
 Note that tracking [visibility] is likely to
 be a more expensive operation than tracking intersections. It is
 recommended that this option be used only when necessary.

## 3. Processing Model

This section outlines the steps the user agent must take when
implementing the [Intersection
Observer](#intersection-observer) API.

### 3.1. Internal Slot Definitions

#### 3.1.1. Document

Each
[`document`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#dom-document-2) has an
[IntersectionObserverTaskQueued] flag
which is initialized to false.

#### 3.1.2. Element

[`Element`](https://dom.spec.whatwg.org/#element) objects have an internal
[`[[RegisteredIntersectionObservers]]`] slot, which is initialized to an empty list. This list holds
[`IntersectionObserverRegistration`] records,
which have:

- an [`observer`] property holding an
 [`IntersectionObserver`](#intersectionobserver).

- a
 [`previousThresholdIndex`] property holding a number between -1
 and the length of the observer's
 [`thresholds`](#dom-intersectionobserver-thresholds) property (inclusive).

- a
 [`previousIsIntersecting`] property holding a boolean.

- a
 [`lastUpdateTime`] property holding a
 [`DOMHighResTimeStamp`](http://www.w3.org/TR/hr-time/#domhighrestimestamp) value.

- a
 [`previousIsVisible`] property holding a boolean.

#### 3.1.3. IntersectionObserver

[`IntersectionObserver`](#intersectionobserver) objects have the following internal slots:

- A [`[[QueuedEntries]]`] slot initialized to an empty list.

- A
 [`[[ObservationTargets]]`] slot initialized to an empty list.

- A [`[[callback]]`] slot which is initialized by
 [`IntersectionObserver(callback, options)`](#dom-intersectionobserver-intersectionobserver).

- A [`[[rootMargin]]`] slot which is a list of four pixel
 lengths or percentages.

- A [`[[scrollMargin]]`] slot which is a list of four pixel
 lengths or percentages.

- A [`[[thresholds]]`] slot which is initialized by
 [`IntersectionObserver(callback, options)`](#dom-intersectionobserver-intersectionobserver).

- A [`[[delay]]`] slot which is initialized by
 [`IntersectionObserver(callback, options)`](#dom-intersectionobserver-intersectionobserver).

- A
 [`[[trackVisibility]]`] slot which is initialized by
 [`IntersectionObserver(callback, options)`](#dom-intersectionobserver-intersectionobserver).

### 3.2. Algorithms

#### 3.2.1. Initialize a new IntersectionObserver

To [initialize a new
IntersectionObserver], given an
[`IntersectionObserverCallback`](#callbackdef-intersectionobservercallback) `callback` and an
[`IntersectionObserverInit`](#dictdef-intersectionobserverinit) dictionary `options`, run these steps:

1. Let `this` be a new
 [`IntersectionObserver`](#intersectionobserver) object

2. Set `this`'s internal
 [`[[callback]]`](#dom-intersectionobserver-callback-slot) slot to `callback`.

3. Attempt to [parse a margin](#parse-a-margin) from
 `options`.[`rootMargin`](#dom-intersectionobserverinit-rootmargin). If a list is returned, set `this`'s
 internal
 [`[[rootMargin]]`](#dom-intersectionobserver-rootmargin-slot) slot to that. Otherwise,
 [throw](https://heycam.github.io/webidl/#dfn-throw) a
 [`SyntaxError`](https://heycam.github.io/webidl/#dfn-simple-exception) exception.

4. Attempt to [parse a
 margin](#parse-a-margin)
 from
 `options`.[`scrollMargin`](#dom-intersectionobserverinit-scrollmargin). If a list is returned, set `this`'s
 internal
 [`[[scrollMargin]]`](#dom-intersectionobserver-scrollmargin-slot) slot to that. Otherwise,
 [throw](https://heycam.github.io/webidl/#dfn-throw) a
 [`SyntaxError`](https://heycam.github.io/webidl/#dfn-simple-exception) exception.

5. Let `thresholds` be a list equal to
 `options`.[`threshold`](#dom-intersectionobserverinit-threshold).

6. If any value in `thresholds` is less than 0.0 or greater
 than 1.0,
 [throw](https://heycam.github.io/webidl/#dfn-throw) a
 [`RangeError`](https://heycam.github.io/webidl/#dfn-simple-exception) exception.

7. Sort `thresholds` in ascending order.

8. If `thresholds` is empty, append `0` to
 `thresholds`.

9. The
 [`thresholds`](#dom-intersectionobserver-thresholds) attribute getter will return this sorted
 `thresholds` list.

10. Let `delay` be the value of
 `options`.[`delay`](#dom-intersectionobserverinit-delay).

11. If
 `options`.[`trackVisibility`](#dom-intersectionobserverinit-trackvisibility) is true and `delay` is less than `100`,
 set `delay` to `100`.

12. Set `this`'s internal
 [`[[delay]]`](#dom-intersectionobserver-delay-slot) slot to
 `options`.[`delay`](#dom-intersectionobserverinit-delay) to `delay`.

13. Set `this`'s internal
 [`[[trackVisibility]]`](#dom-intersectionobserver-trackvisibility-slot) slot to
 `options`.[`trackVisibility`](#dom-intersectionobserverinit-trackvisibility).

14. Return `this`.

#### 3.2.2. Observe a target Element

To [observe a target Element], given an
[`IntersectionObserver`](#intersectionobserver) `observer` and an
[`Element`](https://dom.spec.whatwg.org/#element) `target`, follow these steps:

1. If `target` is in `observer`'s internal
 [`[[ObservationTargets]]`](#dom-intersectionobserver-observationtargets-slot) slot, return.

2. Let `intersectionObserverRegistration` be an
 [`IntersectionObserverRegistration`](#intersectionobserverregistration) record with an
 [`observer`](#dom-intersectionobserverregistration-observer) property set to `observer`, a
 [`previousThresholdIndex`](#dom-intersectionobserverregistration-previousthresholdindex) property set to `-1`, a
 [`previousIsIntersecting`](#dom-intersectionobserverregistration-previousisintersecting) property set to false, and a
 [`previousIsVisible`](#dom-intersectionobserverregistration-previousisvisible) property set to false.

3. Append `intersectionObserverRegistration` to
 `target`'s internal
 [`[[RegisteredIntersectionObservers]]`](#dom-element-registeredintersectionobservers-slot) slot.

4. Add `target` to `observer`'s internal
 [`[[ObservationTargets]]`](#dom-intersectionobserver-observationtargets-slot) slot.

#### 3.2.3. Unobserve a target Element

To [unobserve a target Element], given an
[`IntersectionObserver`](#intersectionobserver) `observer` and an
[`Element`](https://dom.spec.whatwg.org/#element) `target`, follow these steps:

1. Remove the
 [`IntersectionObserverRegistration`](#intersectionobserverregistration) record whose
 [`observer`](#dom-intersectionobserverregistration-observer) property is equal to `this` from
 `target`'s internal
 [`[[RegisteredIntersectionObservers]]`](#dom-element-registeredintersectionobservers-slot) slot, if present.

2. Remove `target` from `this`'s internal
 [`[[ObservationTargets]]`](#dom-intersectionobserver-observationtargets-slot) slot, if present

#### 3.2.4. Queue an Intersection Observer Task

The [IntersectionObserver task source] is a [task
source](https://html.spec.whatwg.org/multipage/webappapis.html#task-source) used for scheduling tasks to [§ 3.2.5 Notify
Intersection Observers](#notify-intersection-observers-algo).

To [queue an intersection observer
task] for a
[`document`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#dom-document-2) `document`, run these steps:

1. If `document`'s
 [IntersectionObserverTaskQueued](#document-intersectionobservertaskqueued) flag is set to true, return.

2. Set `document`'s
 [IntersectionObserverTaskQueued](#document-intersectionobservertaskqueued) flag to true.

3. [Queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task) on the [IntersectionObserver task
 source](#intersectionobserver-task-source) associated with the
 [`document`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#dom-document-2)'s [event
 loop](https://html.spec.whatwg.org/multipage/webappapis.html#event-loop) to [notify intersection
 observers](#notify-intersection-observers).

#### 3.2.5. Notify Intersection Observers

To [notify intersection observers] for a
[`document`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#dom-document-2) `document`, run these steps:

1. Set `document`'s
 [IntersectionObserverTaskQueued](#document-intersectionobservertaskqueued) flag to false.

2. Let `notify list` be a list of all
 [`IntersectionObserver`](#intersectionobserver)s whose
 [`root`](#dom-intersectionobserver-root) is in the DOM tree of `document`.

3. For each
 [`IntersectionObserver`](#intersectionobserver) object `observer` in
 `notify list`, run these steps:

 1. If `observer`'s internal
 [`[[QueuedEntries]]`](#dom-intersectionobserver-queuedentries-slot) slot is empty, continue.

 2. Let `queue` be a copy of `observer`'s
 internal
 [`[[QueuedEntries]]`](#dom-intersectionobserver-queuedentries-slot) slot.

 3. Clear `observer`'s internal
 [`[[QueuedEntries]]`](#dom-intersectionobserver-queuedentries-slot) slot.

 4. Let `callback` be the value of
 `observer`'s internal
 [`[[callback]]`](#dom-intersectionobserver-callback-slot) slot.

 5. Invoke `callback` with `queue` as the
 first argument, `observer` as the second argument,
 and `observer` as the [callback this
 value](https://html.spec.whatwg.org/multipage/infrastructure.html#dfn-callback-this-value). If this throws an exception, [report the
 exception](https://html.spec.whatwg.org/multipage/webappapis.html#report-the-exception).

#### 3.2.6. Queue an IntersectionObserverEntry

To [queue an
IntersectionObserverEntry] for an
[`IntersectionObserver`](#intersectionobserver) `observer`, given a
[`document`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#dom-document-2) `document`;
[`DOMHighResTimeStamp`](http://www.w3.org/TR/hr-time/#domhighrestimestamp) `time`;
[`DOMRect`](https://drafts.csswg.org/geometry-1/#domrect)s `rootBounds`,
`boundingClientRect`, `intersectionRect`, and
`isIntersecting` flag; and an
[`Element`](https://dom.spec.whatwg.org/#element) `target`; run these steps:

1. Construct an
 [`IntersectionObserverEntry`](#intersectionobserverentry), passing in `time`,
 `rootBounds`, `boundingClientRect`,
 `intersectionRect`, `isIntersecting`, and
 `target`.

2. Append it to `observer`'s internal
 [`[[QueuedEntries]]`](#dom-intersectionobserver-queuedentries-slot) slot.

3. [Queue an intersection observer
 task](#queue-an-intersection-observer-task) for `document`.

#### 3.2.7. Compute the Intersection of a Target Element and the Root

To [compute the intersection] between a
[target](#intersectionobserver-target) `target` and an [intersection
root](#intersectionobserver-intersection-root) `root`, run these steps:

1. Let `intersectionRect` be the result of [getting the
 bounding
 box](https://drafts.csswg.org/cssom-view-1/#element-get-the-bounding-box) for `target`.

2. Let `container` be the [containing
 block](https://drafts.csswg.org/css-box/#containing-block) of `target`.

3. While `container` is not `root`:

 1. If `container` is the
 [`document`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#dom-document-2) of a [nested browsing
 context](https://html.spec.whatwg.org/multipage/browsers.html#nested-browsing-context), update `intersectionRect` by
 clipping to the
 [viewport](https://drafts.csswg.org/css2/visuren.html#viewport) of the
 [`document`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#dom-document-2), and update `container` to be the
 [browsing context
 container](https://html.spec.whatwg.org/multipage/browsers.html#browsing-context-container) of `container`.

 2. Map `intersectionRect` to the coordinate space of
 `container`.

 3. If `container` is a [scroll
 container](https://drafts.csswg.org/css-overflow-3/#scroll-container), apply the
 [`IntersectionObserver`](#intersectionobserver)'s
 [`[[scrollMargin]]`](#dom-intersectionobserver-scrollmargin-slot) to the `container`'s clip rect as
 described in [apply scroll margin to a
 scrollport](#apply-scroll-margin-to-a-scrollport).

 4. If `container` has a [content
 clip](#intersectionobserver-content-clip) or a css
 [clip-path](http://www.w3.org/TR/css-masking-1/#propdef-clip-path) property, update `intersectionRect`
 by applying `container`'s clip.

 5. If `container` is the root element of a [browsing
 context](https://html.spec.whatwg.org/multipage/browsers.html#browsing-context), update `container` to be the
 [browsing context]'s
 [`document`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#dom-document-2); otherwise, update `container` to be
 the [containing
 block](https://drafts.csswg.org/css-box/#containing-block) of `container`.

4. Map `intersectionRect` to the coordinate space of
 `root`.

5. Update `intersectionRect` by intersecting it with the
 [root intersection
 rectangle](#intersectionobserver-root-intersection-rectangle).

6. Map `intersectionRect` to the coordinate space of the
 [viewport](https://drafts.csswg.org/css2/visuren.html#viewport) of the
 [`document`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#dom-document-2) containing `target`.

7. Return `intersectionRect`.

#### 3.2.8. Compute whether a Target is unoccluded, untransformed, unfiltered, and opaque.

To compute the [visibility] of a
[target](#intersectionobserver-target), run these steps:

1. If the `observer`'s
 [`trackVisibility`](#dom-intersectionobserver-trackvisibility) attribute is false, return false.

2. If the
 [target](#intersectionobserver-target) has an [effective transformation
 matrix](#effective-transformation-matrix) other than a 2D translation or proportional 2D
 upscaling, return false.

3. If the
 [target](#intersectionobserver-target), or any element in its [containing block
 chain](https://drafts.csswg.org/css-display/#containing-block-chain), has an effective opacity other than 100%, return
 false.

4. If the
 [target](#intersectionobserver-target), or any element in its [containing block
 chain](https://drafts.csswg.org/css-display/#containing-block-chain), has any filters applied, return false.

5. If the implementation cannot guarantee that the
 [target](#intersectionobserver-target) is completely unoccluded by other page content,
 return false.

 Implementations should use the [ink overflow
rectangle](https://drafts.csswg.org/css-overflow-3/#ink-overflow-rectangle) of page content when determining whether a
[target](#intersectionobserver-target) is occluded. For blur effects, which have theoretically
infinite extent, the [ink overflow
rectangle] is defined by the
finite-area approximation described for the
[blur](https://drafts.fxtf.org/filter-effects/#funcdef-filter-blur) filter function.

6. Return true.

#### 3.2.9. Calculate a [target's Effective Transformation Matrix]
To compute the [effective transformation
matrix] of a
[target](#intersectionobserver-target), run these steps:

1. Let `matrix` be the
 [serialization](https://drafts.csswg.org/css-transforms-1/#serialization-of-the-computed-value) of the [identity transform
 function](https://drafts.csswg.org/css-transforms-1/#identity-transform-function).

2. Let `container` be the target.

3. While `container` is not the [intersection
 root](#intersectionobserver-intersection-root):

 1. Set `t` to `container`'s [transformation
 matrix](https://drafts.csswg.org/css-transforms-1/#transformation-matrix).

 2. Set `matrix` to `t`
 [post-multiplied](https://drafts.csswg.org/css-transforms-1/#post-multiplied) by `matrix`.

 3. If `container` is the root element of a [nested
 browsing
 context](https://html.spec.whatwg.org/multipage/browsers.html#nested-browsing-context), update `container` to be the
 [browsing context
 container](https://html.spec.whatwg.org/multipage/browsers.html#browsing-context-container) of `container`. Otherwise, update
 `container` to be the [containing
 block](https://drafts.csswg.org/css-box/#containing-block) of `container`.

4. Return `matrix`.

#### 3.2.10. Run the Update Intersection Observations Steps

To [run the update intersection observations
steps] for a
[Document](https://html.spec.whatwg.org/multipage/dom.html#document) `document` given a timestamp
`time`, run these steps:

1. Let `observer list` be a list of all
 [`IntersectionObserver`](#intersectionobserver)s whose
 [`root`](#dom-intersectionobserver-root) is in the DOM tree of `document`. For
 the [top-level browsing
 context](https://html.spec.whatwg.org/multipage/browsers.html#top-level-browsing-context), this includes [implicit root
 observers](#intersectionobserver-implicit-root-observer).

2. For each `observer` in `observer list`:

 1. Let `rootBounds` be `observer`'s [root
 intersection
 rectangle](#intersectionobserver-root-intersection-rectangle).

 2. For each `target` in `observer`'s internal
 [`[[ObservationTargets]]`](#dom-intersectionobserver-observationtargets-slot) slot, processed in the same order that
 [`observe()`](#dom-intersectionobserver-observe) was called on each `target`:

 1. Let `registration` be the
 [`IntersectionObserverRegistration`](#intersectionobserverregistration) record in `target`'s internal
 [`[[RegisteredIntersectionObservers]]`](#dom-element-registeredintersectionobservers-slot) slot whose
 [`observer`](#dom-intersectionobserverregistration-observer) property is equal to `observer`.

 2. If
 `(``time`` - ``registration``.`[`lastUpdateTime`](#dom-intersectionobserverregistration-lastupdatetime)` < ``observer``.`[`delay`](#dom-intersectionobserver-delay)`)`, skip further processing for
 `target`.

 3. Set
 `registration`.[`lastUpdateTime`](#dom-intersectionobserverregistration-lastupdatetime) to `time`.

 4. Let:

 - `thresholdIndex` be 0.

 - `isIntersecting` be false.

 - `targetRect` be a
 [`DOMRectReadOnly`](https://drafts.csswg.org/geometry-1/#domrectreadonly) with `x`, `y`,
 `width`, and `height` set to 0.

 - `intersectionRect` be a
 [`DOMRectReadOnly`](https://drafts.csswg.org/geometry-1/#domrectreadonly) with `x`, `y`,
 `width`, and `height` set to 0.

 5. If the [intersection
 root](#intersectionobserver-intersection-root) is not the [implicit
 root](#intersectionobserver-implicit-root), and `target` is not in the same
 [`document`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#dom-document-2) as the [intersection
 root],
 skip to step 11.

 6. If the [intersection
 root](#intersectionobserver-intersection-root) is an
 [`Element`](https://dom.spec.whatwg.org/#element), and `target` is not a
 descendant of the [intersection
 root] in
 the [containing block
 chain](https://drafts.csswg.org/css-display/#containing-block-chain), skip to step 11.

 7. Set `targetRect` to the
 [`DOMRectReadOnly`](https://drafts.csswg.org/geometry-1/#domrectreadonly) obtained by [getting the bounding
 box](https://drafts.csswg.org/cssom-view-1/#element-get-the-bounding-box) for `target`.

 8. Let `intersectionRect` be the result of running
 the [compute the
 intersection](#compute-the-intersection) algorithm on `target` and
 `observer`'s [intersection
 root](#intersectionobserver-intersection-root).

 9. Let `targetArea` be `targetRect`'s
 area.

 10. Let `intersectionArea` be
 `intersectionRect`'s area.

 11. Let `isIntersecting` be true if
 `targetRect` and `rootBounds`
 intersect or are edge-adjacent, even if the intersection has
 zero area (because `rootBounds` or
 `targetRect` have zero area).

 12. If `targetArea` is non-zero, let
 `intersectionRatio` be
 `intersectionArea` divided by
 `targetArea`.\
 Otherwise, let `intersectionRatio` be `1` if
 `isIntersecting` is true, or `0` if
 `isIntersecting` is false.

 13. Set `thresholdIndex` to the index of the first
 entry in
 `observer`.[`thresholds`](#dom-intersectionobserver-thresholds) whose value is greater than
 `intersectionRatio`, or the length of
 `observer`.[`thresholds`](#dom-intersectionobserver-thresholds) if `intersectionRatio` is
 greater than or equal to the last entry in
 `observer`.[`thresholds`](#dom-intersectionobserver-thresholds).

 14. Let `isVisible` be the result of running the
 [visibility](#visibility) algorithm on `target`.

 15. Let `previousThresholdIndex` be the
 `registration`'s
 [`previousThresholdIndex`](#dom-intersectionobserverregistration-previousthresholdindex) property.

 16. Let `previousIsIntersecting` be the
 `registration`'s
 [`previousIsIntersecting`](#dom-intersectionobserverregistration-previousisintersecting) property.

 17. Let `previousIsVisible` be the
 `registration`'s
 [`previousIsVisible`](#dom-intersectionobserverregistration-previousisvisible) property.

 18. If `thresholdIndex` does not equal
 `previousThresholdIndex`, or if
 `isIntersecting` does not equal
 `previousIsIntersecting`, or if
 `isVisible` does not equal
 `previousIsVisible`, [queue an
 IntersectionObserverEntry](#queue-an-intersectionobserverentry), passing in `observer`,
 `time`, `rootBounds`,
 `targetRect`, `intersectionRect`,
 `isIntersecting`, `isVisible`, and
 `target`.

 19. Assign `thresholdIndex` to
 `registration`'s
 [`previousThresholdIndex`](#dom-intersectionobserverregistration-previousthresholdindex) property.

 20. Assign `isIntersecting` to
 `registration`'s
 [`previousIsIntersecting`](#dom-intersectionobserverregistration-previousisintersecting) property.

 21. Assign `isVisible` to `registration`'s
 [`previousIsVisible`](#dom-intersectionobserverregistration-previousisvisible) property.

### 3.3. IntersectionObserver Lifetime

An
[`IntersectionObserver`](#intersectionobserver) will remain alive until both of these conditions hold:

- There are no scripting references to the observer.
- The observer is not observing any targets.

An
[`IntersectionObserver`](#intersectionobserver) will continue observing a target until either the
observer's
[`unobserve()`](#dom-intersectionobserver-unobserve) method is called with the target as argument; or the
observer's
[`disconnect()`](#dom-intersectionobserver-disconnect) is called.

### 3.4. External Spec Integrations

#### 3.4.1. HTML Processing Model: Event Loop

An Intersection Observer processing step exists as a substep within the
\"*Update the rendering*\" step, in the [HTML Event Loops Processing
Model](https://html.spec.whatwg.org/multipage/webappapis.html#event-loop-processing-model).

#### 3.4.2. Pending initial IntersectionObserver targets

A
[`document`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#dom-document-2) is said to have [pending initial IntersectionObserver
targets] if there is at least one
[`IntersectionObserver`](#intersectionobserver) meeting these criteria:

1. The `observer`'s
 [`root`](#intersectionobserver) is in the `document` (for the [top-level
 browsing
 context](https://html.spec.whatwg.org/multipage/browsers.html#top-level-browsing-context), this includes [implicit root
 observers](#intersectionobserver-implicit-root-observer)).
2. The `observer` has at least one `target` in
 its
 [`[[ObservationTargets]]`](#dom-intersectionobserver-observationtargets-slot) slot for which no
 [`IntersectionObserverEntry`](#intersectionobserverentry) has yet been queued.

In the [HTML Event Loops Processing
Model](https://html.spec.whatwg.org/multipage/webappapis.html#event-loop-processing-model), under the \"*Update the rendering*\" step, the
\"*Unnecessary rendering*\" step should be modified to add an additional
requirement for skipping the rendering update:

- The `document` does not have [pending initial
 IntersectionObserver
 targets](#pending-initial-intersectionobserver-targets).

## 4. Accessibility Considerations

*This section is non-normative.*

There are no known accessibility considerations for the core
IntersectionObserver specification (this document). There are, however,
related specifications and proposals that leverage and refer to this
spec, which might have their own accessibility considerations. In
particular, specifications for [HTML § 2.5.7 Lazy loading
attributes](https://html.spec.whatwg.org/multipage/urls-and-fetching.html#lazy-loading-attributes)
and [CSS Containment 2 § 4 Suppressing An Element's Contents Entirely:
the content-visibility
property](https://drafts.csswg.org/css-contain-2/#content-visibility)
may have implications for [HTML § 6.9
Find-in-page](https://html.spec.whatwg.org/multipage/interaction.html#find-in-page),
[HTML § 6.6.3 The tabindex
attribute](https://html.spec.whatwg.org/multipage/interaction.html#the-tabindex-attribute),
and [spatial navigation](https://githumb.com/WICG/spatial-navigation).

## 5. Privacy and Security

*This section is non-normative.*

The main privacy concerns associated with this API relate to the
information it may provide to code running in the context of a
cross-origin iframe (i.e., the [cross-origin-domain
target](#intersectionobserver-cross-origin-domain-target) case). In particular:

- There is no universal consensus on the privacy implications of
 revealing whether an iframe is within the global viewport.

- There is a risk that the API may be used to probe for information
 about the geometry of the global viewport itself, which may be used to
 deduce the user's hardware configuration. The motivation for disabling
 the effects of
 [`rootMargin`](#dom-intersectionobserver-rootmargin) and
 [`scrollMargin`](#dom-intersectionobserver-scrollmargin), and suppressing
 [`rootBounds`](#dom-intersectionobserverentry-rootbounds) for [cross-origin-domain
 targets](#intersectionobserver-cross-origin-domain-target) is to prevent such probing.

It should be noted that prior to
[`IntersectionObserver`](#intersectionobserver), web developers used other API's in very ingenious (and
grotesque) ways to tease out the information available from
[`IntersectionObserver`](#intersectionobserver). As a purely practical matter, this API does not reveal
any information that was not already available by other means.

Another consideration is that
[`IntersectionObserver`](#intersectionobserver) uses
[`DOMHighResTimeStamp`](http://www.w3.org/TR/hr-time/#domhighrestimestamp), which has privacy and security considerations of its
own. It is however unlikely that
[`IntersectionObserver`](#intersectionobserver) is vulnerable to timing-related exploits. Timestamps
are generated at most once per rendering update (see [§ 3.4.1 HTML
Processing Model: Event Loop](#event-loop)), which is far too infrequent
for the familiar kind of timing attack.

## 6. Internationalization

*This section is non-normative.*

There are no known issues concerning internationalization.

## 7. Acknowledgements

Special thanks to [all the
contributors](https://github.com/w3c/IntersectionObserver/graphs/contributors)
for their technical input and suggestions that led to improvements to
this specification.
