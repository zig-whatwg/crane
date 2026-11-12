## 1. Introduction

Today, users of the web are often distracted by content moving around
due to changes that occur outside the viewport. Examples include script
inserting an iframe containing an ad, or non-sized images loading on a
slow network.

Historically the browser's default behavior has been to preserve the
absolute scroll position when such changes occur. This means that to
avoid shifting content, the webpage can attempt to reserve space on the
page for anything that will load later. In practice, few websites do
this consistently.

Scroll anchoring aims to minimize surprising content shifts. It does
this by adjusting the scroll position to compensate for the changes
outside the viewport.

The [explainer
document](https://github.com/WICG/ScrollAnchoring/blob/master/explainer.md)
gives an informal overview of scroll anchoring.

### 1.1. Value Definitions

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

## 2. Description

Scroll anchoring attempts to keep the user's view of the document stable
across layout changes. It works by selecting a DOM node (the [anchor
node]) whose movement is
used to determine adjustments to the scroll position.

However, if the scroll container is currently
[snapped](https://drafts.csswg.org/css-scroll-snap-1/#scroll-snap) to an element, (see
[\[CSS-SCROLL-SNAP-1\]](#biblio-css-scroll-snap-1 "CSS Scroll Snap Module Level 1"))
scroll anchoring is limited to adjustments that would be allowed by
[re-snapping](https://drafts.csswg.org/css-scroll-snap-1/#re-snap).

### 2.1. Anchor Node Selection

Each [scrolling
box](https://drafts.csswg.org/cssom-view-1/#scrolling-box) aims to select an [anchor
node](#scroll-anchoring-anchor-node) that is deep in the DOM and either should be
prioritized as an important DOM node or is close to the block start edge
of its [optimal viewing
region](https://drafts.csswg.org/css-scroll-snap-1/#optimal-viewing-region).

 If the user agent does not support the
[scroll-padding](https://drafts.csswg.org/css-scroll-snap-1/#propdef-scroll-padding) property, the optimal viewing
region of the scrolling box is equivalent to its [content
area](https://drafts.csswg.org/css-box-4/#content-area).

An anchor node can be any
[box](https://drafts.csswg.org/css-display-4/#box) except one for a non-[atomic
inline](https://drafts.csswg.org/css-display-4/#atomic-inline). The anchor node is always a
[descendant](https://dom.spec.whatwg.org/#concept-tree-descendant) of the [scrolling
box](https://drafts.csswg.org/cssom-view-1/#scrolling-box). In some cases, a scrolling box may not select any
anchor node.

An element `C` is a [viable
candidate] for becoming a scroll anchor for a scrolling box
`S` if it meets all of the following criteria:

- `C` is an element that is not a non-[atomic
 inline](https://drafts.csswg.org/css-display-4/#atomic-inline).

- `C` is [partially
 visible](#partially-visible) or [fully
 visible](#fully-visible) in
 `S`

- `C` is a descendant of `S`

- `C` is not in an [excluded
 subtree](#excluded-subtree)

- None of the ancestors of `C` up to `S` are in an
 [excluded subtree](#excluded-subtree)

Some elements are considered to be [anchor priority
candidates]
for anchor selection:

1. The [DOM
 anchor](https://html.spec.whatwg.org/multipage/interaction.html#dom-anchor) of the [focused area of the
 document](https://html.spec.whatwg.org/multipage/interaction.html#focused-area-of-the-document), if such an anchor is text editable
 ([editable](https://w3c.github.io/editing/docs/execCommand/index.html#editable), [editing
 host](https://html.spec.whatwg.org/multipage/interaction.html#editing-host),
 [mutable](https://html.spec.whatwg.org/multipage/form-control-infrastructure.html#concept-fe-mutable)
 [`textarea`](https://html.spec.whatwg.org/multipage/form-elements.html#the-textarea-element), or [mutable]
 [`input`](https://html.spec.whatwg.org/multipage/input.html#the-input-element) with a type that allows text entry).

2. An element containing the current [active
 match](https://html.spec.whatwg.org/multipage/interaction.html#fip-active-match) of the find-in-page user-agent algorithm. If the
 match spans multiple elements, then consider only the first such
 element.

Note that if the [priority
candidate](#anchor-priority-candidates) is a non-[atomic
inline](https://drafts.csswg.org/css-display-4/#atomic-inline) element, then instead consider its nearest ancestor
element that is not a non-atomic inline element as the priority
candidate.

The [anchor node selection algorithm] for a scrolling box
`S` is as follows:

1. If `S` is generated by an element whose computed value of
 the
 [overflow-anchor](#propdef-overflow-anchor) property is
 [none](#valdef-overflow-anchor-none), then do not select an anchor node for
 `S`.

2. If `S` is not scrolled away from the origin of its
 [scrolling
 area](https://drafts.csswg.org/cssom-view-1/#scrolling-area) in its [block flow
 direction](https://drafts.csswg.org/css-writing-modes-4/#block-flow-direction), then do not select an anchor node for
 `S`.

3. Otherwise, for each [priority
 candidate](#anchor-priority-candidates) `PC` in order specified, check if
 `PC` is a [viable
 candidate](#anchor-viable-candidate) in `S`. If so, perform the [candidate
 examination
 algorithm](#candidate-examination) for `PC` in `S` and
 terminate.

 Since the priority candidate itself is checked to
 be viable, the [candidate examination
 algorithm](#candidate-examination) is guaranteed to select at least the candidate node
 itself.

4. Otherwise, for each DOM child `N` of the element or
 document associated with `S`, perform the [candidate
 examination
 algorithm](#candidate-examination) for `N` in `S`, and terminate
 if it selects an anchor node.

The [candidate examination algorithm] for a candidate DOM node
`N` in a scrolling box `S` is as follows:

1. If `N` is an [excluded
 subtree](#excluded-subtree), or if `N` is [fully
 clipped](#fully-clipped) in
 `S`, then do nothing (`N` and its descendants
 are skipped).

2. If `N` is [fully
 visible](#fully-visible) in
 `S`, select `N` as the anchor node.

3. If N is [partially
 visible](#partially-visible):

 1. For each DOM child `C` of `N`, perform the
 [candidate examination
 algorithm](#candidate-examination) for `C` in `S`, and
 terminate if it selects an anchor node.

 2. For each absolutely-positioned element `A` whose
 [containing
 block](https://drafts.csswg.org/css-display-4/#containing-block) is `N`, but whose DOM parent is not
 `N`, perform the [candidate examination
 algorithm](#candidate-examination) for `A` in `S`, and
 terminate if it selects an anchor node.

 3. Select `N` as the anchor node. (If this step is
 reached, no suitable anchor node was found among
 `N`'s descendants.)

 Deeper nodes are preferred to minimize the
 possibility of content changing inside the anchor node but outside
 the viewport, which would cause visible content to shift without
 triggering any scroll anchoring adjustment.

A DOM node `N` is an [excluded subtree] if it is an element and
any of the following conditions holds:

- `N`'s computed value of the
 [display](https://drafts.csswg.org/css-display-4/#propdef-display) property is
 [none](https://drafts.csswg.org/css-display-4/#valdef-display-none).

- `N`'s computed value of the
 [position](https://drafts.csswg.org/css-position-3/#propdef-position) property is
 [fixed](https://drafts.csswg.org/css-position-3/#valdef-position-fixed).

- `N`'s computed value of the
 [position](https://drafts.csswg.org/css-position-3/#propdef-position) property is
 [sticky](https://drafts.csswg.org/css-position-3/#valdef-position-sticky).

- `N`'s computed value of the
 [position](https://drafts.csswg.org/css-position-3/#propdef-position) property is
 [absolute](https://drafts.csswg.org/css-position-3/#valdef-position-absolute) and `N`'s [containing
 block](https://drafts.csswg.org/css-display-4/#containing-block) is an ancestor of the scrolling box.

- `N`'s computed value of the
 [overflow-anchor](#propdef-overflow-anchor) property is
 [none](#valdef-overflow-anchor-none).

A DOM node `N` is [fully visible] in a scrolling box
`S` if `N`'s [scroll anchoring bounding
rect](#scroll-anchoring-bounding-rect) is entirely within the [optimal viewing
region](https://drafts.csswg.org/css-scroll-snap-1/#optimal-viewing-region) of `S`.

A DOM node `N` is [fully clipped] in a scrolling box
`S` if `N`'s [scroll anchoring bounding
rect](#scroll-anchoring-bounding-rect) is entirely outside the [optimal viewing
region](https://drafts.csswg.org/css-scroll-snap-1/#optimal-viewing-region) of `S`.

A DOM node `N` is [partially visible] in a scrolling box
`S` if `N` is neither [fully
visible](#fully-visible) in
`S` nor [fully
clipped](#fully-clipped) in
`S`.

The [scroll anchoring bounding rect] of a DOM node
`N` is `N`'s [scrollable overflow
rectangle](https://drafts.csswg.org/css-overflow-3/#scrollable-overflow-rectangle).

#### 2.1.1. Invalidation

An anchor node is considered valid for a [scrolling
box](https://drafts.csswg.org/cssom-view-1/#scrolling-box) until any of the following occur:

- The scroll position of the [scrolling
 box](https://drafts.csswg.org/cssom-view-1/#scrolling-box) changes (excluding adjustments originating from
 scroll anchoring).

- A [suppression
 trigger](#suppression-trigger) suppresses a scroll adjustment.

- The [anchor
 node](#scroll-anchoring-anchor-node) is removed from the DOM.

Once an anchor node has become invalid, the [anchor node selection
algorithm](#anchoring-algorithm) must be run again to compute the anchor node

As a performance optimization, implementations may wait until the
[anchor
node](#scroll-anchoring-anchor-node) is needed before computing it.

### 2.2. Scroll Adjustment

If an anchor node was selected, then when the anchor node moves, the
browser computes the previous offset `y0`, and the current offset `y1`,
of the block start edge of the anchor node's [scroll anchoring bounding
rect](#scroll-anchoring-bounding-rect), relative to the block start edge of the scrolling
content in the [block flow
direction](https://drafts.csswg.org/css-writing-modes-4/#block-flow-direction) of the scroller.

It then queues an adjustment to the scroll position of `y1 - y0`, in the
block flow direction, to be performed at the end of the [suppression
window](#suppression-window).

The scroll adjustment is a type of
[scrolling](https://drafts.csswg.org/cssom-view-1/#scrolling-events) as
defined by
[\[CSSOM-VIEW\]](#biblio-cssom-view "CSSOM View Module"),
and generates [scroll
events](https://drafts.csswg.org/cssom-view-1/#eventdef-document-scroll) in the manner described there.

#### 2.2.1. Suppression Window

Every movement of an anchor node occurs within a window of time called
the [suppression window], defined as follows:

- The suppression window begins at the start of the current iteration of
 the [HTML Processing
 Model](https://html.spec.whatwg.org/multipage/webappapis.html#processing-model-8)
 event loop, or at the end of the most recently completed suppression
 window, whichever is more recent.

- The suppression window ends at the end of the current iteration of the
 [HTML Processing
 Model](https://html.spec.whatwg.org/multipage/webappapis.html#processing-model-8)
 event loop, or immediately before the next operation whose result or
 side effects would differ as a result of a change in the scroll
 position (for example, an invocation of
 [`getBoundingClientRect()`](https://drafts.csswg.org/cssom-view-1/#dom-element-getboundingclientrect)), whichever comes sooner.

 The suppression window boundaries should be
incorporated into the HTML standard once the scroll anchoring API is
stabilized.

More than one anchor node movement may occur within the same suppression
window.

At the end of a suppression window, the user agent performs all scroll
adjustments that were queued during the window and not suppressed by any
[suppression
trigger](#suppression-trigger) during the window.

#### 2.2.2. Suppression Triggers

A [suppression trigger] is an operation that suppresses the scroll
anchoring adjustment for an anchor node movement, if it occurs within
the suppression window for that movement. These triggers are:

- Any change to the computed value of any of the following properties,
 on any element in the path from the anchor node to the scrollable
 element (or document), inclusive of both:

 - [top](https://drafts.csswg.org/css-position-3/#propdef-top),
 [left](https://drafts.csswg.org/css-position-3/#propdef-left),
 [right](https://drafts.csswg.org/css-position-3/#propdef-right), or
 [bottom](https://drafts.csswg.org/css-position-3/#propdef-bottom)

 - [margin](https://drafts.csswg.org/css-box-4/#propdef-margin) or its longhands

 - [padding](https://drafts.csswg.org/css-box-4/#propdef-padding) or its longhands

 - [width](https://drafts.csswg.org/css-sizing-3/#propdef-width),
 [height](https://drafts.csswg.org/css-sizing-3/#propdef-height),
 [min-width](https://drafts.csswg.org/css-sizing-3/#propdef-min-width),
 [max-width](https://drafts.csswg.org/css-sizing-3/#propdef-max-width),
 [min-height](https://drafts.csswg.org/css-sizing-3/#propdef-min-height), or
 [max-height](https://drafts.csswg.org/css-sizing-3/#propdef-max-height)

 - [position](https://drafts.csswg.org/css-position-3/#propdef-position)

 - [transform](https://drafts.csswg.org/css-transforms-1/#propdef-transform)

- Any change to the computed value of the
 [position](https://drafts.csswg.org/css-position-3/#propdef-position) property on any element within
 the scrollable element (or document), such that the element becomes or
 stops being absolutely positioned. Note that this trigger applies
 regardless of whether the modified element is on the path from the
 anchor node to the scrollable element.

- The scroll offset of the scrollable element being zero.

 Suppression triggers exist for compatibility with
existing web content that has negative interactions with scroll
anchoring due to shifting content in scroll event handlers.

## 3. Exclusion API

Scroll anchoring aims to be the default mode of behavior when launched,
so that users benefit from it even on legacy content.
[overflow-anchor](#propdef-overflow-anchor) can disable scroll anchoring in
part or all of a webpage (opt out), or exclude portions of the DOM from
the anchor node selection algorithm.

Name:

[overflow-anchor]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

auto
[\|](https://drafts.csswg.org/css-values-4/#comb-one) none

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

auto

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[all
elements](https://www.w3.org/TR/css-pseudo/#generated-content "Includes ::before and ::after pseudo-elements.")

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

specified keyword

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

Values are defined as follows:

[auto]

: Declares that the element is potentially eligible to participate in
 the [anchor node selection
 algorithm](#anchoring-algorithm) for any scrolling box created by the element or an
 ancestor.

[none]

: Declares that the element and its descendants (that aren't nested
 inside of another scrolling element) are *not* eligible to
 participate in the [anchor node selection
 algorithm](#anchoring-algorithm) for any scrolling box created by the element or an
 ancestor.

 It is not possible to turn scroll anchoring \"back on\"
for descendants of a [overflow-anchor:
none](#propdef-overflow-anchor) element. However, descendant [scroll
containers](https://drafts.csswg.org/css-overflow-3/#scroll-container) automatically \"turn it back on\" (for their own
scrolling box) unless they explicitly have [overflow-anchor:
none] set on them as well.

 The `overflow-anchor` property was also proposed (with
different values) for [CSS Sticky
Scrollbars](http://tabatkins.github.io/specs/css-sticky-scrollbars/),
which has now been
[superseded](https://tabatkins.github.io/specs/css-sticky-scrollbars/#intro).

## [Privacy Considerations]
This specification, as it only adjusts how we compute scroll positions,
introduces no new privacy considerations.

## [Security Considerations]
This specification, as it only adjusts how we compute scroll positions,
introduces no new security considerations.

## [ Changes]
### [ Changes Since the Feb 11 2020 Working Draft]
- Added definitions of [viable
 candidate](#anchor-viable-candidate) and [priority
 candidate](#anchor-priority-candidates).

- Clarified interaction between scroll anchoring and [scroll
 snapping](https://drafts.csswg.org/css-scroll-snap-1/#scroll-snap).

- Added a step to run [candidate examination
 algorithm](#candidate-examination) on viable priority candidates.
