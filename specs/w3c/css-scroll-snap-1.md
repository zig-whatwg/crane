## 1. Introduction

*This section is not normative.*

Popular UX paradigms for scrollable content frequently employ paging
through content, or sectioning into logical divisions. This is
especially true for touch interactions where it is quicker and easier
for users to quickly pan through a flatly-arranged breadth of content
rather than delving into a hierarchical structure through tap
navigation. For example, it is easier for a user to view many photos in
a photo album by panning through a photo slideshow view rather than
tapping on individual photos in an album.

However, given the imprecise nature of scrolling inputs like touch
panning and mousewheel scrolling, it is difficult for web developers to
guarantee a well-controlled scrolling experience, in particular creating
the effect of paging through content. For instance, it is easy for a
user to land at an awkward scroll position which leaves an item
partially on-screen when panning.

To this end, this module introduces [scroll snap
positions](#scroll-snap-position) which enforce the scroll positions that a [scroll
container's](https://drafts.csswg.org/css-overflow-3/#scroll-container) scrollport may end at after a scrolling operation has
completed.

Also, to offer better control over paging and scroll positioning even
when snapping is off, this module defines the
[scroll-padding](#propdef-scroll-padding) property for use on all [scroll
containers](https://drafts.csswg.org/css-overflow-3/#scroll-container), to adjust the [scroll
container]'s [optimal viewing
region](#optimal-viewing-region) for the purpose of paging and scroll-into-view
operations. Similarly the
[scroll-margin](#propdef-scroll-margin) property can be used on any box to
adjust its visual area for the purpose of scroll-into-view operations.

### 1.1. Module interactions

This module extends the scrolling user interface features defined in
[\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")
section 11.1.

None of the properties in this module apply to the
[::first-line](https://drafts.csswg.org/css-pseudo-4/#selectordef-first-line) and
[::first-letter](https://drafts.csswg.org/css-pseudo-4/#selectordef-first-letter) pseudo-elements.

### 1.2. Value Definitions

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

## 2. Motivating Examples

In this example, a series of images
arranged in a [scroll
container](https://drafts.csswg.org/css-overflow-3/#scroll-container) are used to build a photo gallery. In this example the
[scroll container] is larger than the photos
contained within (such that multiple images may be seen simultaneously),
and the image sizes vary. Using mandatory element-based snap positions,
scrolling will always complete with an image centered in the [scroll
container's] scrollport.

```
img {
 /* Specifies that the center of each photo
 should align with the center of the scroll
 container in the X axis when snapping */
 scroll-snap-align: none center;
}
.photoGallery {
 width: 500px;
 overflow-x: auto;
 overflow-y: hidden;
 white-space: nowrap;
 /* Requires that the scroll position always be
 at a snap position when the scrolling
 operation completes. */
 scroll-snap-type: x mandatory;
}
```

```
<div class="photoGallery">
 <img src="img1.jpg">
 <img src="img2.jpg">
 <img src="img3.jpg">
 <img src="img4.jpg">
 <img src="img5.jpg">
</div>
```

![The layout of the scroll container's contents in the example. The
snapport is represented by the red rectangle, and the snap area is
represented by the yellow rectangle. Since the scroll-snap-align is
"center" in the inline (horizontal) axis, a snap position is established
at each scroll position which aligns the X-center of the snapport
(represented by a red dotted line) with the X-center of a snap area
(represented by a yellow dotted
line).](images/element_snap_positions.png){height="214" width="775"}

This example builds a paginated
document that aligns each page near to (but not exactly on) the edge of
the [scroll
container](https://drafts.csswg.org/css-overflow-3/#scroll-container). This allows the previous page to "peek" in from above
in order to make the user aware that they are not yet at the top of the
document. Using proximity snap positions instead of mandatory snap
positions allows the user to stop halfway through a page (rather than
forcing them to snap one page at a time). However, if a scrolling
operation would finish near a snap position, then the scroll will be
adjusted to align the page as specified.

```
.page {
 /* Defines the top of each page as the
 edge that should be used for snapping */
 scroll-snap-align: start none;
}
.docScroller {
 width: 500px;
 overflow-x: hidden;
 overflow-y: auto;
 /* Specifies that each element’s snap area should
 align with a 100px offset from the top edge. */
 scroll-padding: 100px 0 0;
 /* Encourages scrolling to end at a snap position when the
 operation completes, if it is near a snap position */
 scroll-snap-type: y proximity;
}
```

```
<div class="docScroller">
 <div class="page">Page 1</div>
 <div class="page">Page 2</div>
 <div class="page">Page 3</div>
 <div class="page">Page 4</div>
</div>
```

![The layout of the scroll container's contents in the example. The
snapport is represented by the red rectangle (inset from the top by
100px due to the scroll-padding), and the snap area is represented by
the yellow rectangle. Since the scroll-snap-align is "start" in the Y
axis, a snap position is established at each scroll position which
aligns the Y-start of the snapport (represented by a red dotted line)
with the Y-start of a snap area (represented by a yellow dotted
line).](images/element_snap_positions_offset.png){height="1118"
width="286"}

## 3. Scroll Snap Model

This module defines controls for [scroll snap
positions], which are
scroll positions that produce particular alignments of content within a
scroll container. Using the
[scroll-snap-type](#propdef-scroll-snap-type) property on the relevant [scroll
container](https://drafts.csswg.org/css-overflow-3/#scroll-container), the author can request a particular bias for the
scrollport to land on a [snap
position](#scroll-snap-position) after scrolling operations (including programmatic
scrolls such as the
[`scrollTo()`](https://drafts.csswg.org/cssom-view-1/#dom-window-scrollto) method).

[Snap positions](#scroll-snap-position) are specified as a particular alignment
([scroll-snap-align](#propdef-scroll-snap-align)) of an element's [scroll snap
area](#scroll-snap-area) (its
border bounding box, as modified by
[scroll-margin](#propdef-scroll-margin)) within the [scroll
container](https://drafts.csswg.org/css-overflow-3/#scroll-container)'s [snapport](#scroll-snapport) (its scrollport, as reduced by
[scroll-padding](#propdef-scroll-padding)). This is conceptually equivalent
to specifying the alignment of an [alignment
subject](https://drafts.csswg.org/css-align-3/#alignment-subject) within an [alignment
container](https://drafts.csswg.org/css-align-3/#alignment-container). A scroll position that satisfies the specified
alignment is a [snap position].

The act of adjusting the scroll position of a scroll container's
scrollport such that it is aligned to a snap area is called
[snapping], and a [scroll
container](https://drafts.csswg.org/css-overflow-3/#scroll-container) may be [snapped](#scroll-snap) to a [snap
area](#scroll-snap-area) in
each axis if its scrollport is aligned with that [snap
area] in that axis and there is no active
scrolling operation. When there are multiple valid snap areas, a single
one is chosen for each axis when [snapping]
according to the algorithm for [selecting between multiple aligned snap
areas](#multiple-aligned-snap-areas). The CSS Scroll Snap Module
intentionally does not specify nor mandate any precise animations or
physics used to enforce [snap
positions](#scroll-snap-position); this is left up to the user agent.

[Snap positions](#scroll-snap-position) only affect the nearest ancestor [scroll
container](https://drafts.csswg.org/css-overflow-3/#scroll-container) on the element's [containing block
chain](https://drafts.csswg.org/css-display-4/#containing-block-chain).

## 4. Capturing Scroll Snap Areas: Properties on the scroll container

### 4.1. Scroll Snapping Rules: the [scroll-snap-type property]
Name:

[scroll-snap-type]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

none
[\|](https://drafts.csswg.org/css-values-4/#comb-one) \[ x [\|] y
[\|] block [\|] inline
[\|] both [\|] pair \] \[
mandatory [\|] proximity
\][?](https://drafts.csswg.org/css-values-4/#mult-opt)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

none

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[scroll
containers](https://drafts.csswg.org/css-overflow-3/#scroll-container)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

specified keyword(s)

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

The
[scroll-snap-type](#propdef-scroll-snap-type) property specifies whether a
[scroll
container](https://drafts.csswg.org/css-overflow-3/#scroll-container) is a [scroll snap
container](#scroll-snap-container), how [strictly](#snap-strictness) it
[snaps](#scroll-snap), and [which
axes](#snap-axis) are considered. If no strictness value is specified,
[proximity](#valdef-scroll-snap-type-proximity) is assumed. A [single-axis scroll
container](https://drafts.csswg.org/css-overflow-3/#single-axis-scroll-container) only establishes snap positions in its [scrollable
axis](https://drafts.csswg.org/css-overflow-3/#scrollable-axis); specifying
[scroll-snap-type] for an
axis which is not one of the box's [scrollable
axes] has no effect.

In this example, snapping to headings
is enabled in the [block
axis](https://drafts.csswg.org/css-writing-modes-4/#block-axis) (the y axis for horizontal writing, x axis for vertical
writing):

 html {
 scroll-snap-type: block; /* applied to main document scroller */
 }
 h1, h2, h3, h4, h5, h6 {
 scroll-snap-align: start; /* snap to the start (top) of the viewport */
 }

UAs must apply the
[scroll-snap-type](#propdef-scroll-snap-type) value set on the root element to
the document viewport. Note that, unlike
[overflow](https://drafts.csswg.org/css-overflow-3/#propdef-overflow),
[scroll-snap-type] values
are *not* propagated from HTML
[`body`](https://html.spec.whatwg.org/multipage/sections.html#the-body-element).

#### 4.1.1. Scroll Snap Axis: the [x, [y](#valdef-scroll-snap-type-y), [block](#valdef-scroll-snap-type-block), [inline](#valdef-scroll-snap-type-inline), [both](#valdef-scroll-snap-type-both), and [pair](#valdef-scroll-snap-type-pair) values]
The [axis values] specify what axis(es) are affected by [snap
positions](#scroll-snap-position), and whether [snap
positions] are evaluated independently
per axis, or together as a 2D point. Values are defined as follows:

[x]
: The [scroll
 container](https://drafts.csswg.org/css-overflow-3/#scroll-container) [snaps](#scroll-snap) to [snap
 positions](#scroll-snap-position) in its horizontal axis only.

[y]
: The [scroll
 container](https://drafts.csswg.org/css-overflow-3/#scroll-container) [snaps](#scroll-snap) to [snap
 positions](#scroll-snap-position) in its vertical axis only.

[block]
: The [scroll
 container](https://drafts.csswg.org/css-overflow-3/#scroll-container) [snaps](#scroll-snap) to [snap
 positions](#scroll-snap-position) in its block axis only.

[inline]
: The [scroll
 container](https://drafts.csswg.org/css-overflow-3/#scroll-container) [snaps](#scroll-snap) to [snap
 positions](#scroll-snap-position) in its inline axis only.

[both]
: The [scroll
 container](https://drafts.csswg.org/css-overflow-3/#scroll-container) [snaps](#scroll-snap) to [snap
 positions](#scroll-snap-position) in both of its axes independently (potentially
 snapping to different elements in each axis).

[pair]

: The [scroll
 container](https://drafts.csswg.org/css-overflow-3/#scroll-container) [snaps](#scroll-snap) to [snap
 positions](#scroll-snap-position) in both of its axes together as a single 2D point
 belonging to a single [snap
 area](#scroll-snap-area).

 A [snap area](#scroll-snap-area) is only eligible as a [snap
 position](#scroll-snap-position) in a [scroll
 container](https://drafts.csswg.org/css-overflow-3/#scroll-container) with
 [pair](#valdef-scroll-snap-type-pair) if it specifies an alignment in both axes
 (i.e. neither its block nor inline alignment in
 [scroll-snap-align](#propdef-scroll-snap-align) computes to
 [none](#valdef-scroll-snap-align-none)). [Snap areas]
 that specify alignment in only a single axis are ignored.

#### 4.1.2. Scroll Snap Strictness: the [none, [proximity](#valdef-scroll-snap-type-proximity), and [mandatory](#valdef-scroll-snap-type-mandatory) values]
The [strictness values]
([none](#valdef-scroll-snap-type-none),
[proximity](#valdef-scroll-snap-type-proximity),
[mandatory](#valdef-scroll-snap-type-mandatory)) specify how strictly [snap
positions](#scroll-snap-position) are enforced on the [scroll
container](https://drafts.csswg.org/css-overflow-3/#scroll-container) (by forcing an adjustment to the scroll position).
Values are defined as follows:

[none]
: If specified on a [scroll
 container](https://drafts.csswg.org/css-overflow-3/#scroll-container), the [scroll
 container] must not
 [snap](#scroll-snap).

[mandatory]
: If specified on a [scroll
 container](https://drafts.csswg.org/css-overflow-3/#scroll-container), the [scroll
 container] is required to be
 [snapped](#scroll-snap) to a
 snap position when there are no active scrolling operations. If a
 valid [snap
 position](#scroll-snap-position) exists then the scroll container must
 [snap] at the termination of a scroll (if
 none exist then no [snapping] occurs).

[proximity]
: If specified on a [scroll
 container](https://drafts.csswg.org/css-overflow-3/#scroll-container), the [scroll
 container] may
 [snap](#scroll-snap) to a
 snap position at the termination of a scroll, at the discretion of
 the UA given the parameters of the scroll.

**Authors should use mandatory snap positions with consideration of
varyingly-sized screens and (if applicable) varying-sized content. In
particular, although access to snapped elements larger than the
scrollport is handled by the UA, if authors assign mandatory snapping to
non-adjacent siblings, content in between can become inaccessible in
cases where it is longer than the screen.**

In each axis, a [snap
position](#scroll-snap-position) is \"captured\" by its nearest ancestor [scroll
container](https://drafts.csswg.org/css-overflow-3/#scroll-container) on its associated element's [containing block
chain](https://drafts.csswg.org/css-display-4/#containing-block-chain) that is
[scrollable](https://drafts.csswg.org/css-overflow-3/#scrollable-axis) in that axis---​its [scroll snap
container] for that axis---​and only affects
the scroll position of that [scroll
container] in that axis. (This is true even
if that [scroll snap
container](#scroll-snap-container) has [scroll-snap-type:
none](#propdef-scroll-snap-type) or a
[scroll-snap-type] that
does not snap in that axis; in this case, the [snap
position] simply does not trigger
[snapping](#scroll-snap) in that
axis. It does not look further up the ancestor chain for another [scroll
container] to snap to.)

#### 4.1.3. Re-snapping After Layout Changes

If the content or layout of the document changes (e.g. content is added,
moved, deleted, resized) such that the content of a
[snapport](#scroll-snapport)
changes, the UA must re-evaluate the resulting [scroll
position](https://drafts.csswg.org/css-overflow-3/#scroll-position), and re-snap if required. If the [scroll
container](https://drafts.csswg.org/css-overflow-3/#scroll-container) was [snapped](#scroll-snap) before the content change and those same [snap
areas](#scroll-snap-area)
still exist (e.g. their associated elements were not deleted), the
scroll container must be re-snapped to those same snap areas after the
content change. A [snap area] can be
[snapped] in each axis, following the algorithm
for [selecting between multiple aligned snap
areas](#multiple-aligned-snap-areas). If it is not possible to snap to
both (e.g. if snapping to one resulted in the other being offscreen), it
must prefer the focused box, followed by the targeted box, followed by
the block axis if neither box is focused or targeted.

Scrolling required by a re-snap operation to a new or different box must
behave and animate the same way as any other scroll-into-view operation,
including honoring controls such as
[scroll-behavior](https://drafts.csswg.org/css-overflow-3/#propdef-scroll-behavior). Scrolling behavior for re-snapping
to the same box as before however, is UA-defined. The UA may, for
example, when snapped to the start of a section, choose not to animate
the scroll to the section's new position as content is dynamically added
earlier in the document in order to create the illusion of not
scrolling.

In the following example, the log
console, when initially loaded and as each message is added to the
bottom, remains snapped to the bottom of the content unless the user has
scrolled away from that edge:

```
.log {
 scroll-snap-type: y proximity;
 align-content: end;
}
.log::after {
 display: block;
 content: "";
 scroll-snap-align: end;
}
```

The rules create a single [scroll snap
area](#scroll-snap-area)
represented by the
[::after](https://drafts.csswg.org/css-pseudo-4/#selectordef-after) pseudo-element, positioned at the very bottom of
a [scroll snap
container](#scroll-snap-container). If the user scrolls "near" the bottom, the container
will snap to it. If more content is dynamically added to the container,
it'll remain snapped to it (because scroll containers are required to
re-snap to the same scroll snap area if it still exists after any
changes). However, if the user has scrolled to somewhere else in the
logs, it won't do anything at all.

### 4.2. Scroll Snapport: the [scroll-padding property]
Name:

[scroll-padding]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

\[ auto
[\|](https://drafts.csswg.org/css-values-4/#comb-one) [\<length-percentage
\[0,∞\]\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage)
\][{1,4}](https://drafts.csswg.org/css-values-4/#mult-num-range)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

auto

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[scroll
containers](https://drafts.csswg.org/css-overflow-3/#scroll-container)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

relative to the corresponding dimension of the scroll container's
scrollport

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

per side, either the keyword
[auto](#valdef-scroll-padding-auto) or a computed
[\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage) value

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value type

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

This property specifies (for all [scroll
containers](https://drafts.csswg.org/css-overflow-3/#scroll-container), not just [scroll snap
containers](#scroll-snap-container)) offsets that define the [optimal viewing
region] of a scrollport: the region used as the target region for
placing things in view of the user. This allows the author to exclude
regions of the
[scrollport](https://drafts.csswg.org/css-overflow-3/#scrollport) that are obscured by other content (such as
fixed-positioned toolbars or sidebars) or simply to put more breathing
room between a targeted element and the edges of the scrollport.

The
[scroll-padding](#propdef-scroll-padding) property is a [shorthand
property](https://drafts.csswg.org/css-cascade-5/#shorthand-property) that sets all of the [[scroll-padding-\*]
longhands](#longhands) in one declaration, assigning values to the
longhands representing each side exactly as the
[padding](https://drafts.csswg.org/css-box-4/#propdef-padding) property does for its longhands.
Values have the following meanings:

[[\<length-percentage \[0,∞\]\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage)]

: Defines an inward offset from the corresponding edge of the
 [scrollport](https://drafts.csswg.org/css-overflow-3/#scrollport). When applied to the root viewport, the offset is
 calculated and applied relative to the layout viewport (rather than
 the visual viewport) the same way as the corresponding [inset
 properties](https://drafts.csswg.org/css-logical-1/#inset-properties) on [fixed-positioned
 boxes](https://drafts.csswg.org/css-position-3/#fixed-position); the [optimal viewing
 region](#optimal-viewing-region) is the remaining area that intersects with the
 visual viewport.

[auto]

: Indicates that the offset for the corresponding edge of the
 [scrollport](https://drafts.csswg.org/css-overflow-3/#scrollport) is UA-determined. This should generally default to
 a used length of [0px], but UAs may use heuristics to detect
 when a non-zero value is more appropriate.

 :::
 (#example-71c18b16) For example, a UA could detect
 when a [position:fixed] element is being used as an opaque
 unscrollable "header" that obscures the content below it, and
 resolve the top offset to the height of that element so that a "page
 down" operation (such as pressing [PgDn]) automatically
 scrolls by one "visible page" of content.
 :::

These offsets reduce the region of the
[scrollport](https://drafts.csswg.org/css-overflow-3/#scrollport) that is considered "viewable" *for scrolling
operations*: they have no effect on layout, on the scroll origin or
initial position, or on whether or not an element is considered actually
*visible*, but should affect whether an element or the caret is
considered scrolled into view (e.g. for targeting or focusing
operations), and reduce the amount of scrolling for paging operations
(such as using the [PgUp] and [PgDn] keys or triggering
equivalent operations from the scrollbar) so that within the [optimal
viewing
region](#optimal-viewing-region) of the [scrollport] the user sees
a continuous stream of content.

For a [scroll snap
container](#scroll-snap-container) this region also defines the [scroll
snapport]---​the area of the scrollport that is used as the
[alignment
container](https://drafts.csswg.org/css-align-3/#alignment-container) for the [scroll snap
areas](#scroll-snap-area)
when calculating [snap
positions](#scroll-snap-position).

In this example,
[scroll-padding](#propdef-scroll-padding) is used to center slideshow images
within the portion of the scrollport that is not obscured by a
fixed-position toolbar.

```
html {
 overflow-x: auto;
 overflow-y: hidden;
 scroll-snap-type: x mandatory;
 scroll-padding: 0 500px 0 0;
}
.toolbar {
 position: fixed;
 height: 100%;
 width: 500px;
 right: 0;
}
img {
 scroll-snap-align: none center;
}
```

UAs must apply the
[scroll-padding](#propdef-scroll-padding) values set on the root element to
the document viewport. (Note that, unlike
[overflow](https://drafts.csswg.org/css-overflow-3/#propdef-overflow),
[scroll-padding] values are
*not* propagated from HTML
[`body`](https://html.spec.whatwg.org/multipage/sections.html#the-body-element).)

## 5. Aligning Scroll Snap Areas: Properties on the elements

### 5.1. Scroll Snapping Area: the [scroll-margin property]
Name:

[scroll-margin]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<length\>](https://drafts.csswg.org/css-values-4/#length-value)[{1,4}](https://drafts.csswg.org/css-values-4/#mult-num-range)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

0

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[all
elements](https://www.w3.org/TR/css-pseudo/#generated-content "Includes ::before and ::after pseudo-elements.")

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

per side, an absolute length

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value type

This property is a [shorthand
property](https://drafts.csswg.org/css-cascade-5/#shorthand-property) that sets all of the [[scroll-margin-\*]
longhands](#longhands) in one declaration, assigning values to the
longhands representing each side exactly as the
[margin](https://drafts.csswg.org/css-box-4/#propdef-margin) property does for its longhands.

Values represent outsets defining the [scroll snap
area] that is used for snapping this box to the
snapport. The [scroll snap
area](#scroll-snap-area) is
determined by taking the transformed border box, finding its rectangular
bounding box (axis-aligned in the [scroll
container's](https://drafts.csswg.org/css-overflow-3/#scroll-container) coordinate space), then adding the specified outsets.

 This ensures that the [scroll snap
area](#scroll-snap-area) is
always rectangular and axis-aligned to the [scroll
container's](https://drafts.csswg.org/css-overflow-3/#scroll-container) coordinate space.

If a page is navigated to a fragment that defines a target element (one
that would be matched by
[:target](https://drafts.csswg.org/selectors-4/#target-pseudo), or the target of
[`scrollIntoView()`](https://drafts.csswg.org/cssom-view-1/#dom-element-scrollintoview)), the UA should use the element's [scroll snap
area](#scroll-snap-area),
rather than just its border box, to determine which area of the
[scrollable overflow
area](https://drafts.csswg.org/css-overflow-3/#scrollable-overflow-region) to bring into view, *even when snapping is off or not
applied on this element*.

### 5.2. Scroll Snapping Alignment: the [scroll-snap-align property]
Name:

[scroll-snap-align]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

\[ none
[\|](https://drafts.csswg.org/css-values-4/#comb-one) start [\|] end
[\|] center
\][{1,2}](https://drafts.csswg.org/css-values-4/#mult-num-range)

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

two keywords

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

The
[scroll-snap-align](#propdef-scroll-snap-align) property specifies the box's [snap
position](#scroll-snap-position) as an alignment of its [snap
area](#scroll-snap-area)
(as the [alignment
subject](https://drafts.csswg.org/css-align-3/#alignment-subject)) within its [snap
container's](#scroll-snap-container) [snapport](#scroll-snapport) (as the [alignment
container](https://drafts.csswg.org/css-align-3/#alignment-container)) for each axis. The two values specify the snapping
alignment in the [block
axis](https://drafts.csswg.org/css-writing-modes-4/#block-axis) and [inline
axis](https://drafts.csswg.org/css-writing-modes-4/#inline-axis), respectively, as determined by the [writing
mode](https://drafts.csswg.org/css-writing-modes-4/#writing-mode) of the box's nearest ancestor [scroll
container](https://drafts.csswg.org/css-overflow-3/#scroll-container) on its [containing block
chain](https://drafts.csswg.org/css-display-4/#containing-block-chain). If only one value is specified, the second value
defaults to the same value.

Values are defined as follows:

[none]
: This box does not define a [snap
 position](#scroll-snap-position) in the specified axis.

[start]
: Start alignment of this box's [scroll snap
 area](#scroll-snap-area) within the [scroll
 container](https://drafts.csswg.org/css-overflow-3/#scroll-container)'s
 [snapport](#scroll-snapport) is a [snap
 position](#scroll-snap-position) in the specified axis.

[end]
: End alignment of this box's [scroll snap
 area](#scroll-snap-area) within the [scroll
 container](https://drafts.csswg.org/css-overflow-3/#scroll-container)'s
 [snapport](#scroll-snapport) is a [snap
 position](#scroll-snap-position) in the specified axis.

[center]
: Center alignment of this box's [scroll snap
 area](#scroll-snap-area) within the [scroll
 container](https://drafts.csswg.org/css-overflow-3/#scroll-container)'s
 [snapport](#scroll-snapport) is a [snap
 position](#scroll-snap-position) in the specified axis.

In each axis, start and end alignments are resolved with respect to the
[writing
mode](https://drafts.csswg.org/css-writing-modes-4/#writing-mode) of the [snap
container](#scroll-snap-container) for that axis unless the [scroll snap
area](#scroll-snap-area) is
larger than the [snapport](#scroll-snapport), in which case they are resolved with respect to the
[writing mode] of the box itself. (This allows
items in a container to have consistent snap alignment in general, while
ensuring that
[start](#valdef-scroll-snap-align-start) always aligns the item to allow reading its
contents from the beginning.)

#### 5.2.1. Scoping Valid Snap Positions to Visible Boxes

Since the purpose of scroll snapping is to align content within the
[scrollport](https://drafts.csswg.org/css-overflow-3/#scrollport) for optimal viewing, a scroll position cannot be
considered a valid [snap
position](#scroll-snap-position) if [snapping](#scroll-snap) to it would leave the contributing [snap
area](#scroll-snap-area)
entirely outside the
[snapport](#scroll-snapport),
even if it otherwise satisfies the required alignment of the [snap
area].

For example, a [snap
area](#scroll-snap-area) is
top-aligned to the
[snapport](#scroll-snapport)
if its top edge is coincident with the
[snapport]'s top edge; and this would be
considered a valid [snap
position](#scroll-snap-position) for block-axis start-aligned snapping of that [snap
area] *if at least part of the [snap
area](#scroll-snap-area) is
on-screen*. If the entire [snap area] is
outside the [snapport], however, then the
[scroll
container](https://drafts.csswg.org/css-overflow-3/#scroll-container) cannot be considered to be
[snapped](#scroll-snap) because
the required alignment, though satisfied, would not be relevant to the
viewer.

<figure>
<pre class="ascii-art"><code>╔════viewport════╗┈┈┈┈┈┈┈┈┌──────────────┐
║ ┌─────┐ ┌──┐ ║ │ top-snapping │
║ ├──┐ │ └──┘ ║ │ element │
║ └──┴──┘ ║ │ │
╚════════════════╝ │ │
 └──────────────┘</code></pre>
<figcaption>Alignment of an off-screen element is not considered <a
href="#scroll-snap" id="ref-for-scroll-snap①⑨"
data->snapping</a>.</figcaption>
</figure>

Why limit snapping to only when the element is visible?

As the [WebKit implementers point
out](https://www.webkit.org/blog/4017/scroll-snapping-with-css-snap-points/),
extending a snap edge infinitely across the canvas only allows for
snapping gridded layouts, and produces odd behavior for the user when
off-screen elements do not align with on-screen elements. (If this
requirement is onerous for implementers however, we can default to a
gridded behavior and introduce a switch to get smarter behavior later.)

 Although [scroll-snap-type:
both](#propdef-scroll-snap-type) evaluates [snap
positions](#scroll-snap-position) independently in each axis, [choosing](#choosing) of a
[snap position] in one axis can be
influenced by [snap positions] in the
other axis. For example, snapping in one axis may push off-screen the
[snap area](#scroll-snap-area) that the other axis would otherwise align to, making
its [snap position] invalid and
therefore unchooseable.

#### 5.2.2. Snapping Boxes that Overflow the Scrollport

If the [snap area](#scroll-snap-area) is larger than the
[snapport](#scroll-snapport)
in a particular axis, then any scroll position in which

- the [snap area](#scroll-snap-area) covers the
 [snapport](#scroll-snapport), and

- the distance between the geometrically previous and subsequent
 otherwise-valid [snap
 positions](#scroll-snap-position) in that axis is larger than size of the
 [snapport](#scroll-snapport) in that axis,

is a valid [snap
position](#scroll-snap-position) in that axis.

The UA may use the specified alignment as a more precise target for
certain scroll operations (e.g. explicit paging).

For example, take the first example in
[§ 2 Motivating Examples](#examples), which had a photo as the area. The
author wants mandatory snapping from item to item, but if the item
happens to be larger than your viewport, you want to be able to scroll
around the whole thing once you're over it.

Since the [snap area](#scroll-snap-area) is larger than the
[snapport](#scroll-snapport), while the area fully fills the viewport, the container
can be scrolled arbitrarily and will not try to snap back to its aligned
position. However, if the container is scrolled such that the area no
longer fully fills the viewport in an axis, the area resists outward
scrolling until it is scrolled sufficiently to trigger snapping to a
different [snap
position](#scroll-snap-position).

For another example, mandatory
top-snapping on nested
[`section`](https://html.spec.whatwg.org/multipage/sections.html#the-section-element) elements can produce large snapping areas (from
large top-level sections) potentially filled with smaller snapping areas
(from the subsections). When the subsections are small enough, they snap
normally; when they're longer, the viewer can scroll arbitrarily within
them, or within a large segment of the top-level section that has no
subsections to snap to.

<figure>
<pre class="ascii-art"><code>┌─ top-level section ─┐ ━┓ ┳ 1 (scroll position = 0)
│ │ 1┃ ┃
│ │ ┃ ┃
│ │ ━┩ ┃
│ │ ┆ ╿
│ │ ┆ │
│ │ ┆ │
│┌─── sub-section ───┐│ ╯ ━┓ ┿ 2
│└───────────────────┘│ 2┃ │
│┌─── sub-section ───┐│ ━┓ ┃ ┿ 3
││ ││ 3┃ ━┛ │
│└───────────────────┘│ ┃ │
│┌─── sub-section ───┐│ ━┛ ━┓ ┿ 4
│└───────────────────┘│ 4┃ │
│┌─── sub-section ───┐│ ━┓ ┃ ╈ 5
││ ││ 5┃ ━┛ ┃
││ ││ ┃ ┃
││ ││ ━┩ ┃
││ ││ ┆ ┃
││ ││ ┆ ╹
││ ││ ┆
│└───────────────────┘│ ┆
└─────────────────────┘ ╯</code></pre>
<figcaption>In the figure above, the five numbered viewports represent
the five snap positions associated with the top-level section and its
four subsections. Because the first and last snap positions are part of
ranges taller than the viewport, the viewer is allowed to scroll freely
between the top and bottom of each range.
<p>Any position in that range is a valid <a href="#scroll-snap-position"
id="ref-for-scroll-snap-position③④" data->snap
position</a>, which can be snapped to when it is the nearest position;
however, if the element is targetted directly (such as by a fragment ID
or a scrolling API), the UA will land on the bolded position, which
corresponds to the ideal requested alignment of the element’s <a
href="#scroll-snap-area" id="ref-for-scroll-snap-area②⑧"
data->snap area</a> within the <a href="#scroll-snapport"
id="ref-for-scroll-snapport①⑤"
data->snapport</a>.</p></figcaption>
</figure>

 If the author had instead set mandatory snap positions
on the *headings* of each section (rather than the sections themselves),
the contents of the first and fifth sections would be partially
inaccessible to the user, as the heading snap area does not extend to
cover the whole section. This is why it's a bad idea to use mandatory
snap positions on elements that might be widely spaced apart.

#### 5.2.3. Unreachable Snap Positions

If a [snap
position](#scroll-snap-position) is unreachable as specified, such that aligning to it
would require scrolling the [scroll
container](https://drafts.csswg.org/css-overflow-3/#scroll-container)'s viewport past the edge of its [scrollable overflow
area](https://drafts.csswg.org/css-overflow-3/#scrollable-overflow-region), the *used* [snap
position] for this [snap
area](#scroll-snap-area) is
the position resulting from scrolling *as much as possible* in each
relevant axis toward the desired [snap
position].

### 5.3. Scroll Snap Limits: the [scroll-snap-stop property]
Name:

[scroll-snap-stop]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

normal
[\|](https://drafts.csswg.org/css-values-4/#comb-one) always

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

specified keyword

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

When performing a [relative
scroll](#relative-scroll), the
[scroll
container](https://drafts.csswg.org/css-overflow-3/#scroll-container) can "pass over" several possible [snap
positions](#scroll-snap-position) (that would be valid to snap to, if the scrolling
operation used the same direction but a lesser distance) before reaching
the natural endpoint of the scroll operation and selecting its final
[scroll
position](https://drafts.csswg.org/css-overflow-3/#scroll-position). The
[scroll-snap-stop](#propdef-scroll-snap-stop) property allows such a possible
[snap position] to "trap" the scrolling
operation, forcing the [scroll container]
to stop before the scrolling operation would naturally end.

Values are defined as follows:

[normal]
: The [scroll
 container](https://drafts.csswg.org/css-overflow-3/#scroll-container) may pass over a [snap
 position](#scroll-snap-position) defined by this element during the execution of a
 scrolling operation.

[always]
: The [scroll
 container](https://drafts.csswg.org/css-overflow-3/#scroll-container) must not pass over a [snap
 position](#scroll-snap-position) defined by this element during the execution of a
 scrolling operation; it must instead snap to the first of this
 element's [snap positions].

This property has no effect on non-[relative
scrolling](#relative-scroll)
operations, as they do not conceptually "pass over" any [snap
positions](#scroll-snap-position).

## 6. Snapping Mechanics

The precise model algorithm to select a [snap
position](#scroll-snap-position) to snap to is intentionally left mostly undefined, so
that user agents can take into account sophisticated models of user
intention and interaction and adjust how they respond over time, to best
serve the user.

This section defines some useful concepts to aid in discussing
scroll-snapping mechanics, and provides some guidelines for what an
effective scroll-snapping strategy might look like. User agents are
encouraged to adapt this guidance and apply their own best judgement
when defining their own snapping behavior. It also provides a small
number of behavior requirements, to ensure a minimum reasonable behavior
that authors can depend on when designing their interfaces with
scroll-snapping in mind.

### 6.1. Types of Scrolling Methods

There are many ways to cause a page to scroll, and they differ in their
intent, which affects how scroll snapping and other features should
*respond* to them. The types of scrolling intents are:

[absolute scroll]

: An [absolute scroll](#absolute-scroll) is a scrolling operation that is not intended to
 have any relation with the previous scroll position. Whether the new
 position is before or after the previous scroll position is not
 relevant to the operation; the scroll container just \"goes straight
 there\".

 :::
 (#example-34847a38) Common examples of [absolute
 scrolls](#absolute-scroll) include:
 - manipulating the scrollbar "thumb" explicitly

 - programmatically scrolling via APIs such as
 [`scrollTo()`](https://drafts.csswg.org/cssom-view-1/#dom-window-scrollto)

 - tabbing through the document's focusable elements

 - navigating to an anchor within the page

 - homing operations such as the [Home]/[End] keys
 :::

 Scroll snapping responds to an [absolute
 scroll](#absolute-scroll)
 by finding the nearest valid [snap
 position](#scroll-snap-position), *regardless* of direction.

[relative scroll]

: A [relative scroll](#relative-scroll) is a scrolling operation that does have a
 meaningful relation with the previous scroll position; that is, the
 fact that the new scroll position is before or after the old scroll
 position is an important quality of the scroll.

 Relative scrolls might or might not have an intended end position,
 but they always have an intended *direction*.

 :::
 (#example-0c549e43) Common examples of [relative
 scrolls](#relative-scroll) with both an intended direction and end position
 include:
 - a "fling" gesture, interpreted with momentum

 - a panning gesture, released with or without momentum

 - programmatically scrolling via APIs such as
 [`scrollBy()`](https://drafts.csswg.org/cssom-view-1/#dom-window-scrollby)

 - paging operations such as the [PgUp]/[PgDn] keys (or
 equivalent operations on the scrollbar)

 Common examples of [relative
 scrolls](#relative-scroll) with only an intended direction include:

 - pressing an arrow key on the keyboard

 - pressing an arrow button on the scrollbar

 - a swiping gesture interpreted as a fixed (rather than inertial)
 scroll
 :::

 The intended end point of the scroll prior to intervention from
 features such as snap points is its [natural
 end-point].

 Scroll snapping responds to a [relative
 scroll](#relative-scroll)
 by finding the nearest valid [snap
 position](#scroll-snap-position) *in the intended direction* (if possible), so a
 snapped element can't get \"trapped\" when the [snap
 positions] are far apart.

[stationary scroll]

: A [stationary scroll](#stationary-scroll) is a scrolling operation that isn't \"intending\"
 to move the scroller at all; instead, it's attempting to keep
 something stationary (usually, an element you're focusing on).

 :::
 (#example-c4a7b7b7) Common examples of [stationary
 scrolls](#stationary-scroll) include:
 - scroll anchoring with
 [overflow-anchor](https://drafts.csswg.org/css-scroll-anchoring-1/#propdef-overflow-anchor), when off-screen content
 changes size and would move the current anchor

 - scroll snapping (especially
 [mandatory](#valdef-scroll-snap-type-mandatory)) when another element changes size and
 causes the scroller to no longer be at a valid snap point
 :::

 Scroll snapping responds to a [stationary
 scroll](#stationary-scroll) by finding the nearest valid [snap
 position](#scroll-snap-position), similar to an [absolute
 scroll](#absolute-scroll).

Additionally, because page layouts usually align things vertically
and/or horizontally, UAs sometimes [axis-lock] a scroll when its direction is
sufficiently vertical or horizontal. An
[axis-locked](#axis-lock) scroll is
bound to only scroll along that axis. This prevents less-precise input
mechanisms from drifting in the non-primary axis.

 This specification only applies to scrolling methods
supported by the user agent; it does not require the user agent to
support any particular input or scrolling method.

### 6.2. Choosing Snap Positions

A [scroll
container](https://drafts.csswg.org/css-overflow-3/#scroll-container) can have many [snap
areas](#scroll-snap-area)
scattered throughout its [scrollable overflow
area](https://drafts.csswg.org/css-overflow-3/#scrollable-overflow-region). A naïve algorithm for selecting a [snap
position](#scroll-snap-position) can produce behavior that is unintuitive for users, so
care is required when designing a selection algorithm. Here are a few
pointers that can aid in the selection process:

- [Snap
 positions](#scroll-snap-position) should be chosen to minimize the distance between the
 end-point (or the [natural
 end-point](#natural-end-point)) and the final snapped scroll position, subject to
 the additional constraints listed in this section.

- If a scroll is [axis-locked](#axis-lock), any [snap
 positions](#scroll-snap-position) in the other axis should be ignored during the
 scroll. (However, [snap positions] in
 the other axis can still effect the final scroll position.)

- In order to prevent a far-offscreen element from having
 difficult-to-understand effects on the scroll position, [snap
 positions](#scroll-snap-position) should be ignored if their elements are far outside
 of the "corridor" that the
 [snapport](#scroll-snapport) defines as it moves through the [scrollable overflow
 area](https://drafts.csswg.org/css-overflow-3/#scrollable-overflow-region), or a hypothetical "corridor" in the direction of a
 [relative scroll](#relative-scroll), or the [snapport] after
 an [absolute scroll](#absolute-scroll).

- User agents *must* ensure that a user can "escape" a [snap
 position](#scroll-snap-position), regardless of the scroll method. For example, if the
 snap type is
 [mandatory](#valdef-scroll-snap-type-mandatory) and the next [snap
 position] is more than two
 screen-widths away, a naïve "always snap to nearest" selection
 algorithm might "trap" the user if their end position was only one
 screen-width away. Instead, a smarter algorithm that only returned to
 the starting [snap position] if the
 end-point was a fairly small distance from it, and otherwise ignored
 the starting snap position, would give better behavior.

 (This implies that a [relative
 scroll](#relative-scroll)
 without an intended end position must always ignore the starting [snap
 positions](#scroll-snap-position).)

- If a page is navigated to a fragment that defines a target element
 (e.g. one that would be matched by
 [:target](https://drafts.csswg.org/selectors-4/#target-pseudo), or the target of
 [`scrollIntoView()`](https://drafts.csswg.org/cssom-view-1/#dom-element-scrollintoview)), and that element defines some [snap
 positions](#scroll-snap-position), the user agent must
 [snap](#scroll-snap) to one of
 that element's [snap positions] if
 its nearest [scroll
 container](https://drafts.csswg.org/css-overflow-3/#scroll-container) is a [scroll snap
 container](#scroll-snap-container). The user agent *may* also do this even when the
 [scroll container] has [scroll-snap-type:
 none](#propdef-scroll-snap-type).

- If a scroll by page operation (e.g. Page down / Page up) is being
 performed, eligible [snap
 positions](#scroll-snap-position) that require scrolling less than or equal to the size
 of the [optimal viewing
 region](#optimal-viewing-region) of the [scroll
 container](https://drafts.csswg.org/css-overflow-3/#scroll-container) should be selected before any farther away, ignoring
 the starting [snap positions] so that
 progress is still made in the intended direction.

#### 6.2.1. Selecting between multiple aligned snap areas

When [snapping](#scroll-snap) to
a scroll position that is aligned with multiple [scroll snap
areas](#scroll-snap-area),
the following algorithm procedure is used to determined which box is
[snapped] on the block and inline axes for a
particular [scroll
container](https://drafts.csswg.org/css-overflow-3/#scroll-container):

1. Let `scroll position` be the scroll position of the
 [scroll
 container](https://drafts.csswg.org/css-overflow-3/#scroll-container)

2. Let `inline` be the set of boxes whose [scroll snap
 areas](#scroll-snap-area) are aligned at this `scroll position` in
 the inline axis.

3. Let `block` be the set of boxes whose [scroll snap
 areas](#scroll-snap-area) are aligned at this `scroll position` in
 the block axis.

4. For each `list` of `block` and
 `inline`:

 1. If `list` contains one or more boxes that are focused
 or have a focused descendant, remove all other boxes from
 `list`

 2. Else if `list` contains one or more boxes that are
 targetted or have a targetted descendant, remove all other boxes
 from `list`.

 3. For each `box` in `list`:

 1. Remove any box from `list` which is an ancestor
 of `box`.

5. If `inline` and `block` are overlapping sets:

 1. Replace `inline` with the intersection of
 `inline` and `block`.

 2. Replace `block` with the intersection of
 `inline` and `block`.

6. Select the first element in [tree
 order](https://dom.spec.whatwg.org/#concept-tree-order) from `inline` as the
 [snapped](#scroll-snap)
 inline axis box.

7. Select the first element in [tree
 order](https://dom.spec.whatwg.org/#concept-tree-order) from `block` as the
 [snapped](#scroll-snap)
 block axis box.

## [Appendix A: Longhands]
The physical and logical longhands (and their shorthands) interact as
defined in
[\[CSS-LOGICAL-1\]](#biblio-css-logical-1 "CSS Logical Properties and Values Module Level 1").

### [Physical Longhands for [scroll-padding](#propdef-scroll-padding)]
Name:

[scroll-padding-top],
[scroll-padding-right],
[scroll-padding-bottom],
[scroll-padding-left]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

auto
[\|](https://drafts.csswg.org/css-values-4/#comb-one) [\<length-percentage
\[0,∞\]\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

auto

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[scroll
containers](https://drafts.csswg.org/css-overflow-3/#scroll-container)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

relative to the scroll container's scrollport

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

the keyword
[auto](#valdef-scroll-padding-auto) or a computed
[\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage) value

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value type

[Logical property
group:](https://drafts.csswg.org/css-logical-1/#logical-property-group)

[scroll-padding](#propdef-scroll-padding)

These
[longhands](https://drafts.csswg.org/css-cascade-5/#longhand) of
[scroll-padding](#propdef-scroll-padding) specify the top, right, bottom, and
left edges of the
[snapport](#scroll-snapport), respectively. Negative values are invalid.

### [Flow-relative Longhands for [scroll-padding](#propdef-scroll-padding)]
Name:

[scroll-padding-inline-start],
[scroll-padding-block-start],
[scroll-padding-inline-end],
[scroll-padding-block-end]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

auto
[\|](https://drafts.csswg.org/css-values-4/#comb-one) [\<length-percentage
\[0,∞\]\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

auto

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[scroll
containers](https://drafts.csswg.org/css-overflow-3/#scroll-container)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

relative to the scroll container's scrollport

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

the keyword
[auto](#valdef-scroll-padding-auto) or a computed
[\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage) value

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value type

[Logical property
group:](https://drafts.csswg.org/css-logical-1/#logical-property-group)

[scroll-padding](#propdef-scroll-padding)

These
[longhands](https://drafts.csswg.org/css-cascade-5/#longhand) of
[scroll-padding](#propdef-scroll-padding) specify the block-start,
inline-start, block-end, and inline-end edges of the
[snapport](#scroll-snapport), respectively. Negative values are invalid.

Name:

[scroll-padding-block],
[scroll-padding-inline]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

\[ auto
[\|](https://drafts.csswg.org/css-values-4/#comb-one) [\<length-percentage
\[0,∞\]\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage)
\][{1,2}](https://drafts.csswg.org/css-values-4/#mult-num-range)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

auto

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[scroll
containers](https://drafts.csswg.org/css-overflow-3/#scroll-container)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

relative to the scroll container's scrollport

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

see individual properties

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

These
[shorthands](https://drafts.csswg.org/css-cascade-5/#shorthand-property) of
[scroll-padding-block-start](#propdef-scroll-padding-block-start) +
[scroll-padding-block-end](#propdef-scroll-padding-block-end) and
[scroll-padding-inline-start](#propdef-scroll-padding-inline-start) +
[scroll-padding-inline-end](#propdef-scroll-padding-inline-end) are
[longhands](https://drafts.csswg.org/css-cascade-5/#longhand) of
[scroll-padding](#propdef-scroll-padding), and specify the block-axis and
inline-axis edges of the
[snapport](#scroll-snapport), respectively.

If two values are specified, the first gives the start value and the
second gives the end value.

If only one value is specified, the second value defaults to the same
value.

### [Physical Longhands for [scroll-margin](#propdef-scroll-margin)]
Name:

[scroll-margin-top],
[scroll-margin-right],
[scroll-margin-bottom],
[scroll-margin-left]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<length\>](https://drafts.csswg.org/css-values-4/#length-value)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

0

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[all
elements](https://www.w3.org/TR/css-pseudo/#generated-content "Includes ::before and ::after pseudo-elements.")

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

absolute length

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value type

[Logical property
group:](https://drafts.csswg.org/css-logical-1/#logical-property-group)

[scroll-margin](#propdef-scroll-margin)

These
[longhands](https://drafts.csswg.org/css-cascade-5/#longhand) of
[scroll-margin](#propdef-scroll-margin) specify the top, right, bottom, and
left edges of the [scroll snap
area](#scroll-snap-area),
respectively.

### [Flow-relative Longhands for [scroll-margin](#propdef-scroll-margin)]
Name:

[scroll-margin-block-start],
[scroll-margin-inline-start],
[scroll-margin-block-end],
[scroll-margin-inline-end]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<length\>](https://drafts.csswg.org/css-values-4/#length-value)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

0

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[all
elements](https://www.w3.org/TR/css-pseudo/#generated-content "Includes ::before and ::after pseudo-elements.")

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

absolute length

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value type

[Logical property
group:](https://drafts.csswg.org/css-logical-1/#logical-property-group)

[scroll-margin](#propdef-scroll-margin)

These
[longhands](https://drafts.csswg.org/css-cascade-5/#longhand) of
[scroll-margin](#propdef-scroll-margin) specify the block-start,
inline-start, block-end, and inline-end edges of the [scroll snap
area](#scroll-snap-area),
respectively.

Name:

[scroll-margin-block],
[scroll-margin-inline]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<length\>](https://drafts.csswg.org/css-values-4/#length-value)[{1,2}](https://drafts.csswg.org/css-values-4/#mult-num-range)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

0

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[all
elements](https://www.w3.org/TR/css-pseudo/#generated-content "Includes ::before and ::after pseudo-elements.")

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

see individual properties

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value type

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

These
[shorthands](https://drafts.csswg.org/css-cascade-5/#shorthand-property) of
[scroll-margin-block-start](#propdef-scroll-margin-block-start) +
[scroll-margin-block-end](#propdef-scroll-margin-block-end) and
[scroll-margin-inline-start](#propdef-scroll-margin-inline-start) +
[scroll-margin-inline-end](#propdef-scroll-margin-inline-end) are
[longhands](https://drafts.csswg.org/css-cascade-5/#longhand) of
[scroll-margin](#propdef-scroll-margin), and specify the block-axis and
inline-axis edges of the [scroll snap
area](#scroll-snap-area),
respectively.

If two values are specified, the first gives the start value and the
second gives the end value.

If only one value is specified, the second value defaults to the same
value.

## 7. Privacy Considerations

This specification does not expose any information whatsoever that is
not already exposed to the DOM directly; it just makes scrolling
slightly more functional. There are no new privacy considerations.

## 8. Security Considerations

This specification does not expose any information whatsoever that is
not already exposed to the DOM directly; it just makes scrolling
slightly more functional. There are no new security considerations.

## 9. Acknowledgements

Many thanks to David Baron, Simon Fraser, Håkon Wium Lie, Theresa
O'Connor, François Remy, Majid Valpour, and most especially Robert
O'Callahan for their proposals and recommendations, which have been
incorporated into this document.

## 10. Changes

### 10.1. Changes Since 11 March 2021 CRS

Changes since the [11 March 2021 Candidate Recommendation
Snapshot](https://www.w3.org/TR/2021/CR-css-scroll-snap-1-20210311/)
include:

Fill this out properly.

- [(#change-2021-snap-focus-ancestor) Clarified that
 ancestors of focused or targeted boxes are also prioritized. ([Issue
 13673](https://github.com/w3c/csswg-drafts/issues/13673))]

### 10.2. Changes Since 19 March 2019 CR

Changes since the [19 March 2019 Candidate
Recommendation](https://www.w3.org/TR/2019/CR-css-scroll-snap-1-20190319/)
include:

- [(#change-2019-clarify-writing-mode) Specified which
 writing mode is used to resolve
 [scroll-snap-align](#propdef-scroll-snap-align). ([Issue
 3815](https://github.com/w3c/csswg-drafts/issues/3815))]

- [(#change-2019-resnap-multiple) Define requirements for
 re-snapping when multiple elements coincide. ([Issue
 4651](https://github.com/w3c/csswg-drafts/issues/4651))]

 > If the [scroll
 > container](https://drafts.csswg.org/css-overflow-3/#scroll-container) was [snapped](#scroll-snap) before the content change and that same [snap
 > position](#scroll-snap-position) still exists (e.g. its associated element was not
 > deleted), the scroll container must be re-snapped to that same snap
 > position after the content change. [If multiple boxes were
 > [snapped](#scroll-snap)
 > before and their [snap
 > positions](#scroll-snap-position) no longer coincide, then if one of them is focused
 > or targeted, the [scroll
 > container](https://drafts.csswg.org/css-overflow-3/#scroll-container) must re-snap to that one and otherwise which one to
 > re-snap to is UA-defined. (The UA may, for example, track which
 > element is snapped as layout shifts align and de-align the [snap
 > positions] of other
 > elements.)]

- [(#change-2019-resnap-animation) Require re-snapping to
 a new element to animate the same way as any other scroll-into-view
 operation. ([Issue
 4609](https://github.com/w3c/csswg-drafts/issues/4609))]

 > [Scrolling required by a re-snap operation to a new or different box
 > must behave and animate the same way as any other scroll-into-view
 > operation, including honoring controls such as
 > [scroll-behavior](https://drafts.csswg.org/css-overflow-3/#propdef-scroll-behavior). Scrolling behavior for
 > re-snapping to the same box as before however, is UA-defined. The UA
 > may, for example, when snapped to the start of a section, choose not
 > to animation the scroll to the section's new position as content is
 > dynamically added earlier in the document in order to create the
 > illusion of not scrolling.]

- [(#change-2019-propagation) Defined explicitly that
 [scroll-snap-type](#propdef-scroll-snap-type) and
 [scroll-padding](#propdef-scroll-padding) values are propagated from the
 root element to the document viewport as would be expected. ([Issue
 3740](https://github.com/w3c/csswg-drafts/issues/3740))]

 > [UAs must apply the
 > [scroll-snap-type](#propdef-scroll-snap-type) value set on the root element
 > to the document viewport. Note that, unlike
 > [overflow](https://drafts.csswg.org/css-overflow-3/#propdef-overflow),
 > [scroll-snap-type]
 > values are *not* propagated from HTML
 > [`body`](https://html.spec.whatwg.org/multipage/sections.html#the-body-element).]

 > [UAs must apply the
 > [scroll-padding](#propdef-scroll-padding) values set on the root element
 > to the document viewport. (Note that, unlike
 > [overflow](https://drafts.csswg.org/css-overflow-3/#propdef-overflow),
 > [scroll-padding] values
 > are *not* propagated from HTML
 > [`body`](https://html.spec.whatwg.org/multipage/sections.html#the-body-element).)]

- [(#change-2019-padding-viewport) Clarified that while
 snap alignment is relative to the visual viewport,
 [scroll-padding](#propdef-scroll-padding) is resolved against the layout
 viewport, so that [scroll-padding] and
 [inset](https://drafts.csswg.org/css-position-3/#propdef-inset) are consistent on the root
 viewport. ([Issue
 4393](https://github.com/w3c/csswg-drafts/issues/4393))]

 > Defines an inward offset from the corresponding edge of the
 > [scrollport](https://drafts.csswg.org/css-overflow-3/#scrollport). [When applied to the root viewport, the offset is
 > calculated and applied relative to the layout viewport (rather than
 > the visual viewport) the same way as the corresponding [inset
 > properties](https://drafts.csswg.org/css-logical-1/#inset-properties) on [fixed-positioned
 > boxes](https://drafts.csswg.org/css-position-3/#fixed-position); the [optimal viewing
 > region](#optimal-viewing-region) is the remaining area that intersects with the
 > visual viewport.]

- [(#change-2019-padding-applies-to) Corrected the
 "Applies to" line for
 [scroll-padding-inline](#propdef-scroll-padding-inline) and
 [scroll-padding-block](#propdef-scroll-padding-block). ([Issue
 5845](https://github.com/w3c/csswg-drafts/issues/5845))]

A [Disposition of
Comments](https://drafts.csswg.org/css-scroll-snap-1/issues-cr-2019) is
available.

### 10.3. Changes Since 31 January 2019 CR

Changes since the [31 January 2019 Candidate
Recommendation](https://www.w3.org/TR/2019/CR-css-scroll-snap-1-20190131/)
include:

- [(#change-2019-clarify-nonsnapping) Emphasized that
 [scroll-padding](#propdef-scroll-padding) and
 [scroll-margin](#propdef-scroll-margin) do apply even when scroll
 snapping is off. ([Issue
 3721](https://github.com/w3c/csswg-drafts/issues/3721))]

 > [Also, to offer better control over paging and scroll positioning
 > even when snapping is off, this module defines the
 > [scroll-padding](#propdef-scroll-padding) property for use on all [scroll
 > containers](https://drafts.csswg.org/css-overflow-3/#scroll-container), to adjust the [scroll
 > container]'s [optimal viewing
 > region](#optimal-viewing-region) for the purpose of paging and scroll-into-view
 > operations; similarly the
 > [scroll-margin](#propdef-scroll-margin) property can be used on any box
 > to adjust its visual area for the purpose of scroll-into-view
 > operations.]

 > This property specifies [(for all [scroll
 > containers](https://drafts.csswg.org/css-overflow-3/#scroll-container), not just [scroll snap
 > containers](#scroll-snap-container))] offsets that define the [optimal
 > viewing
 > region](#optimal-viewing-region) of a scrollport...

 > If a page is navigated to a fragment that defines a target element
 > (one that would be matched by
 > [:target](https://drafts.csswg.org/selectors-4/#target-pseudo), or the target of
 > [`scrollIntoView()`](https://drafts.csswg.org/cssom-view-1/#dom-element-scrollintoview)), the UA should use the element's [scroll snap
 > area](#scroll-snap-area), rather than just its border box, to determine
 > which area of the [scrollable overflow
 > area](https://drafts.csswg.org/css-overflow-3/#scrollable-overflow-region) to bring into view [, *even when snapping is off or
 > not applied on this element*] .

### 10.4. Changes Since 14 August 2018 CR

Changes since the [14 August 2018 Candidate
Recommendation](https://www.w3.org/TR/2018/CR-css-scroll-snap-1-20180814/)
include:

- [(#change-2018-padding-initial) Corrected
 [scroll-padding](#propdef-scroll-padding) longhands to list the new
 [auto](#valdef-scroll-padding-auto) keyword in their property definition tables.
 ([Issue
 3189](https://github.com/w3c/csswg-drafts/issues/3189))]
- [(#change-2018-computed-animation) Fixed up "Computed
 value" and "Animation type" lines in the property definition
 tables.]
- [(#change-2018-margin-percentage) Cleaned up stray
 [\<percentage\>](https://drafts.csswg.org/css-values-4/#percentage-value) values in
 [scroll-margin](#propdef-scroll-margin) property definition tables.
 ([3289](https://github.com/w3c/csswg-drafts/issues/3289))]

A [Disposition of Comments is
available](https://drafts.csswg.org/css-scroll-snap-1/issues-cr-2018).

### 10.5. Changes Since 14 December 2017 CR

Changes since the [14 December 2017 Candidate
Recommendation](https://www.w3.org/TR/2017/CR-css-scroll-snap-1-20171214/)
include:

- [(#change-2017-align-values-backwards) Fixed
 [scroll-snap-align](#propdef-scroll-snap-align) shorthand to assign block-axis
 value first, inline-axis value second, accordingly to logical
 shorthand conventions. ([Issue
 2232](https://github.com/w3c/csswg-drafts/issues/2232)]

- [(#change-2017-scroll-padding-auto) Added
 [auto](#valdef-scroll-padding-auto) keyword to \'scroll-padding as its initial
 value to account for UA heuristics. ([Issue
 2728](https://github.com/w3c/csswg-drafts/issues/2728)]

- [(#change-2017-snap-vs-api-scroll) Clarified in the
 definition of
 [scroll-snap-type](#propdef-scroll-snap-type) that programmatic scrolls such as
 [`scrollTo()`](https://drafts.csswg.org/cssom-view-1/#dom-window-scrollto) are also subject to snapping. ([Issue
 2593](https://github.com/w3c/csswg-drafts/issues/2593))]

 > Using the
 > [scroll-snap-type](#propdef-scroll-snap-type) property on the relevant
 > [scroll
 > container](https://drafts.csswg.org/css-overflow-3/#scroll-container), the author can request a particular bias for the
 > scrollport to land on a [snap
 > position](#scroll-snap-position) after scrolling operations [(including programmatic
 > scrolls such as the
 > [`scrollTo()`](https://drafts.csswg.org/cssom-view-1/#dom-window-scrollto) method)] .

- [(#change-2017-clarify-mandatory-visibility) Adjusted
 wording in [§ 5.2.1 Scoping Valid Snap Positions to Visible
 Boxes](#snap-scope) to be clearer---​compared to [old
 version](https://www.w3.org/TR/2017/CR-css-scroll-snap-1-20171214/#snap-scope).
 ([Issue
 2526](https://github.com/w3c/csswg-drafts/issues/2526))]

A [Disposition of
Comments](https://drafts.csswg.org/css-scroll-snap-1/issues-cr-2017-12)
is available.

### 10.6. Changes Since 24 August 2017 CR

Changes since the [24 August 2017 Candidate
Recommendation](https://www.w3.org/TR/2017/CR-css-scroll-snap-1-20170824/)
include:

- [(#change-2017-scroll-margin)
 [:target](https://drafts.csswg.org/selectors-4/#target-pseudo)/[`scrollIntoView()`](https://drafts.csswg.org/cssom-view-1/#dom-element-scrollintoview)/etc should take
 [scroll-margin](#propdef-scroll-margin) into account, regardless of
 whether snapping is turned on or not. ([Issue
 1](https://drafts.csswg.org/css-scroll-snap-1/issues-cr-2016-08#issue-1)]

 > [If a page is navigated to a fragment that defines a target element
 > (one that would be matched by
 > [:target](https://drafts.csswg.org/selectors-4/#target-pseudo), or the target of
 > [`scrollIntoView()`](https://drafts.csswg.org/cssom-view-1/#dom-element-scrollintoview)), the UA should use the element's [scroll snap
 > area](#scroll-snap-area), rather than just its border box, to determine
 > which area of the [scrollable overflow
 > area](https://drafts.csswg.org/css-overflow-3/#scrollable-overflow-region) to bring into view.]

- [(#change-2017-target-snap-must)
 [:target](https://drafts.csswg.org/selectors-4/#target-pseudo)/[`scrollIntoView()`](https://drafts.csswg.org/cssom-view-1/#dom-element-scrollintoview)/etc must (rather than should) use snap positions if
 snapping is turned on. ([Issue
 1](https://drafts.csswg.org/css-scroll-snap-1/issues-cr-2016-08#issue-1)]

 > If a page is navigated to a fragment that defines a target element
 > (one that would be matched by
 > [:target](https://drafts.csswg.org/selectors-4/#target-pseudo), or the target of
 > [`scrollIntoView()`](https://drafts.csswg.org/cssom-view-1/#dom-element-scrollintoview)), and that element defines some [snap
 > positions](#scroll-snap-position), the user agent ~~should~~ [must]
 > [snap](#scroll-snap) to one
 > of that element's [snap positions]
 > [if its nearest [scroll
 > container](https://drafts.csswg.org/css-overflow-3/#scroll-container) is a [scroll snap
 > container](#scroll-snap-container)] . The user agent *may* also do this
 > even when the [scroll
 > container](https://drafts.csswg.org/css-overflow-3/#scroll-container) has [scroll-snap-type:
 > none](#propdef-scroll-snap-type).

- [(#change-2017-rename-scroll-margin) Renamed
 [scroll-snap-margin] to
 [scroll-margin](#propdef-scroll-margin) to reflect its more generic role
 in providing breathing space for scrolling to an element regardless of
 snapping behavior. ([Issue
 4](https://drafts.csswg.org/css-scroll-snap-1/issues-cr-2016-08#issue-4))]

A [Disposition of
Comments](https://drafts.csswg.org/css-scroll-snap-1/issues-cr-2016-08)
is available.

### 10.7. Changes Since 20 October 2016 CR

Changes since the [20 October 2016 Candidate
Recommendation](https://www.w3.org/TR/2016/CR-css-scroll-snap-1-20161020/)
include:

- Restricted
 [scroll-padding](#propdef-scroll-padding) to non-negative values. ([Issue
 1084](https://github.com/w3c/csswg-drafts/issues/1084))

 > Values [must be non-negative and] are interpreted as for
 > [padding](https://drafts.csswg.org/css-box-4/#propdef-padding) ...

- Added paging and homing operations to examples in [§ 6.1 Types of
 Scrolling Methods](#scroll-types). ([Issue
 1605](https://github.com/w3c/csswg-drafts/issues/1605))

- Clarified that snapping in one axis may affect whether snapping to a
 particular snap area is possible in the other axis. ([Issue
 950](https://github.com/w3c/csswg-drafts/issues/950))

 > Although [scroll-snap-type:
 > both](#propdef-scroll-snap-type) evaluates [snap
 > positions](#scroll-snap-position) independently in each axis, [choosing](#choosing)
 > of a [snap position] in one axis
 > may be influenced by [snap
 > positions] in the other axis. For
 > example, snapping in one axis may push off-screen the [snap
 > area](#scroll-snap-area) that the other axis would otherwise align to,
 > making its [snap position] invalid
 > and therefore unchooseable.

- Clarified how the
 [scroll-padding](#propdef-scroll-padding) and
 [scroll-margin](#propdef-scroll-margin) shorthands assign values to their
 longhands. ([Issue
 1050](https://github.com/w3c/csswg-drafts/issues/1050))

- Clarified that scroll snapping does not mandate any particular input
 method. ([Issue
 1305](https://github.com/w3c/csswg-drafts/issues/1305))

 > This specification only applies to scrolling methods supported by
 > the user agent; it does not require the user agent to support any
 > particular input or scrolling method.

- Clarified the intended effects of
 [scroll-snap-stop](#propdef-scroll-snap-stop) on various scrolling operations.
 ([Issue 1552](https://github.com/w3c/csswg-drafts/issues/1552))

- Clarified that
 [scroll-snap-stop](#propdef-scroll-snap-stop) is applied to the [snap
 positions](#scroll-snap-position) defined by the element, not applied to all [snap
 positions] in the [scroll snap
 container](#scroll-snap-container).

- Fixed some syntax errors in examples and added a new one to the
 [scroll-snap-type](#propdef-scroll-snap-type) section. ([Issue
 827](https://github.com/w3c/csswg-drafts/issues/827))

A [Disposition of
Comments](https://drafts.csswg.org/css-scroll-snap-1/issues-cr-2016) is
available.
