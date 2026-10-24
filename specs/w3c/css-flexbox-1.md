## 1. Introduction

*This section is not normative.*

CSS 2.1 defined four layout modes --- algorithms which determine the
size and position of boxes based on their relationships with their
sibling and ancestor boxes:

- block layout, designed for laying out documents

- inline layout, designed for laying out text

- table layout, designed for laying out 2D data in a tabular format

- positioned layout, designed for very explicit positioning without much
 regard for other elements in the document

This module introduces a new layout mode, [flex layout], which is designed for
laying out more complex applications and webpages.

### 1.1. Overview

*This section is not normative.*

Flex layout is superficially similar to block layout. It lacks many of
the more complex text- or document-centric properties that can be used
in block layout, such as
[floats](https://www.w3.org/TR/CSS2/visuren.html#floats) and
[columns](https://www.w3.org/TR/css3-multicol/). In return it gains
simple and powerful tools for distributing space and aligning content in
ways that web apps and complex web pages often need. The contents of a
flex container:

- can be laid out in any [flow direction](#flex-direction-property)
 (leftwards, rightwards, downwards, or even upwards!)

- can have their display order
 [reversed](#valdef-flex-direction-row-reverse) or \'order\|rearranged\' at the style layer
 (i.e., visual order can be independent of source and speech order)

- can be laid out linearly along a single
 ([main](#main-axis)) axis or
 [wrapped](#flex-wrap-property) into multiple lines along a secondary
 ([cross](#cross-axis)) axis

- can ["flex" their sizes](#flexibility) to respond to the available
 space

- can be [aligned](#alignment) with respect to their container or each
 other on the secondary ([cross](#cross-axis))

- can be dynamically [collapsed](#visibility-collapse) or uncollapsed
 along the [main axis](#main-axis)
 while preserving the container's [cross
 size](#cross-size)

Here's an example of a catalog where
each item has a title, a photo, a description, and a purchase button.
The designer's intention is that each entry has the same overall size,
that the photo be above the text, and that the purchase buttons are
aligned at the bottom, regardless of the length of the item's
description. Flex layout makes many aspects of this design easy:

- The catalog uses flex layout to lay out rows of items horizontally,
 and to ensure that items within a row are all equal-height. Each entry
 is then itself a column flex container, laying out its contents
 vertically.

- Within each entry, the source document content is ordered logically
 with the title first, followed by the description and the photo. This
 provides a sensible ordering for speech rendering and in non-CSS
 browsers. For a more compelling visual presentation, however,
 [order](https://drafts.csswg.org/css-display-4/#propdef-order) is used to pull the image up from
 later in the content to the top, and
 [align-self](#propdef-align-self) is used to center it horizontally.

- An [[auto] margin](#auto-margins) above the purchase button
 forces it to the bottom within each entry box, regardless of the
 height of that item's description.

```
#deals {
 display: flex; /* Flex layout so items have equal height */
 flex-flow: row wrap; /* Allow items to wrap into multiple lines */
}
.sale-item {
 display: flex; /* Lay out each item using flex layout */
 flex-flow: column; /* Lay out item's contents vertically */
}
.sale-item > img {
 order: -1; /* Shift image before other content (in visual order) */
 align-self: center; /* Center the image cross-wise (horizontally) */
}
.sale-item > button {
 margin-top: auto; /* Auto top margin pushes button to bottom */
}
```

```
<section id="deals">
 <section class="sale-item">
 <h1>Computer Starter Kit</h1>
 <p>This is the best computer money can buy, if you don’t have much money.
 <ul>
 <li>Computer
 <li>Monitor
 <li>Keyboard
 <li>Mouse
 </ul>
 <img src="images/computer.jpg"
 a>
 <button>BUY NOW</button>
 </section>
 <section class="sale-item">
 …
 </section>
 …
</section>
```

<figure>
<div id="overview-example">
<div class="col">

</div>
<div class="col">

</div>
<div class="desc">
<img src="images/computer.jpg" width="250" height="188"
a />
<h1 id="quiet-pubrules-1" style="font-size: 1.4em;">Computer Starter
Kit</h1>
<p>This is the best computer money can buy, if you don’t have much
money.</p>
<ul>
<li>Computer</li>
<li>Monitor</li>
<li>Keyboard</li>
<li>Mouse</li>
</ul>
</div>
<div class="desc">
<img src="images/printer.png" width="159" height="188"
a />
<h1 id="quiet-pubrules-2" style="font-size: 1.4em;">Printer</h1>
<p>Only capable of printing ASCII art.</p>
<ul>
<li>Paper and ink not included.</li>
</ul>
</div>
<div class="buttons">
<div>
BUY NOW
</div>
<div>
BUY NOW
</div>
</div>
</div>
<figcaption>An example rendering of the code above.</figcaption>
</figure>

### 1.2. Module interactions

This module extends the definition of the
[display](https://drafts.csswg.org/css-display-4/#propdef-display) property
[\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification"),
adding a new block-level and new inline-level display type, and defining
a new type of formatting context along with properties to control its
layout. None of the properties defined in this module apply to the
[::first-line](https://drafts.csswg.org/css-pseudo-4/#selectordef-first-line) or
[::first-letter](https://drafts.csswg.org/css-pseudo-4/#selectordef-first-letter) pseudo-elements.

The [CSS Box Alignment Module](http://www.w3.org/TR/css-align/) extends
and supersedes the definitions of the alignment properties
([justify-content](#propdef-justify-content),
[align-items](#propdef-align-items),
[align-self](#propdef-align-self),
[align-content](#propdef-align-content)) introduced here.

Tests

- [flexbox_first-letter.html](https://wpt.fyi/results/css/css-flexbox/flexbox_first-letter.html "css/css-flexbox/flexbox_first-letter.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_first-letter.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_first-letter.html)
- [flexbox_first-line.html](https://wpt.fyi/results/css/css-flexbox/flexbox_first-line.html "css/css-flexbox/flexbox_first-line.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_first-line.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_first-line.html)
- [flexbox-ignores-first-letter.html](https://wpt.fyi/results/css/css-flexbox/flexbox-ignores-first-letter.html "css/css-flexbox/flexbox-ignores-first-letter.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-ignores-first-letter.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-ignores-first-letter.html)

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

## 2. Flex Layout Box Model and Terminology

A [flex container] is the box generated by an element with a computed
[display](https://drafts.csswg.org/css-display-4/#propdef-display) of
[flex](#valdef-display-flex) or
[inline-flex](#valdef-display-inline-flex).
[In-flow](https://drafts.csswg.org/css-display-4/#in-flow) children of a flex container are called [flex
items] and are laid out using the flex layout model.

Unlike block and inline layout, whose layout calculations are biased to
the [block and inline flow
directions](https://www.w3.org/TR/css3-writing-modes/#abstract-box),
flex layout is biased to the [flex directions]. To make it
easier to talk about flex layout, this section defines a set of flex
flow--relative terms. The
[flex-flow](#propdef-flex-flow) value and the [writing
mode](https://drafts.csswg.org/css-writing-modes-4/#writing-mode) determine how these terms map to physical directions
(top/right/bottom/left), axes (vertical/horizontal), and sizes
(width/height).

![An illustration of the various directions and sizing terms as applied
to a
[row](#valdef-flex-direction-row) flex
container.](images/flex-direction-terms.svg){height="277" width="665"}

main axis\
main dimension
: The [main axis] of a flex container is the
 primary axis along which [flex items](#flex-item) are laid out. It extends in the [main
 dimension].

main-start\
main-end
: The [flex items](#flex-item)
 are placed within the container starting on the
 [main-start]
 side and going toward the [main-end] side.

main size\
main size property

: The [main size] of a [flex
 container](#flex-container)
 or [flex item](#flex-item)
 refers to its
 [width](https://drafts.csswg.org/css-sizing-3/#width) or
 [height](https://drafts.csswg.org/css-sizing-3/#height), whichever is in the [main
 dimension](#main-dimension). Its [main size property] is either its
 [width](https://drafts.csswg.org/css-sizing-3/#propdef-width) or
 [height](https://drafts.csswg.org/css-sizing-3/#propdef-height) property, whichever is in the
 [main dimension]. Likewise, its
 [min] and [max main size
 properties] are its
 [min-width](https://drafts.csswg.org/css2/#propdef-min-width)/[max-width](https://drafts.csswg.org/css2/#propdef-max-width) or
 [min-height](https://drafts.csswg.org/css2/#propdef-min-height)/[max-height](https://drafts.csswg.org/css2/#propdef-max-height) properties, whichever are in
 the [main dimension], and determine its
 [min]/[max main size].

 In [flex layout](#flex-layout), the [main size](#main-size) is controlled by the
 [flex](#propdef-flex) property rather than directly by the [main
 size property](#main-size-property).

 This means any references to a flex item's used
 size in the [main
 dimension](#main-dimension)
 ([width](https://drafts.csswg.org/css-sizing-3/#width),
 [height](https://drafts.csswg.org/css-sizing-3/#height), [inline
 size](https://drafts.csswg.org/css-sizing-3/#inline-size), [block
 size](https://drafts.csswg.org/css-sizing-3/#block-size)) refers to its post-flexing [main
 size](#main-size).

<!-- -->

cross axis\
cross dimension
: The axis perpendicular to the [main
 axis](#main-axis) is called the
 [cross axis]. It extends in the [cross
 dimension].

cross-start\
cross-end
: [Flex lines](#flex-line) are
 filled with items and placed into the container starting on the
 [cross-start] side of the flex container and going toward the
 [cross-end]
 side.

cross size\
cross size property
: The [cross size] of a [flex
 container](#flex-container) or [flex item](#flex-item) refers to its
 [width](https://drafts.csswg.org/css-sizing-3/#width) or
 [height](https://drafts.csswg.org/css-sizing-3/#height), whichever is in the [cross
 dimension](#cross-dimension). Its [cross size property] is either its
 [width](https://drafts.csswg.org/css-sizing-3/#propdef-width) or
 [height](https://drafts.csswg.org/css-sizing-3/#propdef-height) property, whichever is in the
 [cross dimension]. Likewise, its
 [min] and [max cross size
 properties] are its
 [min-width](https://drafts.csswg.org/css2/#propdef-min-width)/[max-width](https://drafts.csswg.org/css2/#propdef-max-width) or
 [min-height](https://drafts.csswg.org/css2/#propdef-min-height)/[max-height](https://drafts.csswg.org/css2/#propdef-max-height) properties, whichever are in
 the [cross dimension], and determine its
 [min]/[max cross size].

Additional sizing terminology used in this specification is defined in
[CSS Intrinsic and Extrinsic
Sizing](http://www.w3.org/TR/CSS-SIZING-3/).
[\[CSS-SIZING-3\]](#biblio-css-sizing-3 "CSS Box Sizing Module Level 3")

Tests

- [box-sizing-min-max-sizes-001.html](https://wpt.fyi/results/css/css-flexbox/box-sizing-min-max-sizes-001.html "css/css-flexbox/box-sizing-min-max-sizes-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/box-sizing-min-max-sizes-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/box-sizing-min-max-sizes-001.html)

## 3. Flex Containers: the [flex and [inline-flex](#valdef-display-inline-flex) [display](https://drafts.csswg.org/css-display-4/#propdef-display) values]
Name:

[display](https://drafts.csswg.org/css-display-4/#propdef-display)

[New values:](https://www.w3.org/TR/css-values/#value-defs)

flex
[\|](https://drafts.csswg.org/css-values-4/#comb-one) inline-flex

- [inheritance.html](https://wpt.fyi/results/css/css-flexbox/inheritance.html "css/css-flexbox/inheritance.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/inheritance.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/inheritance.html)

[flex]
: This value causes an element to generate a [flex
 container](#flex-container) box that is
 [block-level](https://drafts.csswg.org/css-display-4/#block-level) when placed in [flow
 layout](https://drafts.csswg.org/css-display-4/#flow-layout).
 Tests
 - [baseline-synthesis-001.html](https://wpt.fyi/results/css/css-flexbox/baseline-synthesis-001.html "css/css-flexbox/baseline-synthesis-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/baseline-synthesis-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/baseline-synthesis-001.html)
 - [baseline-synthesis-002.html](https://wpt.fyi/results/css/css-flexbox/baseline-synthesis-002.html "css/css-flexbox/baseline-synthesis-002.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/baseline-synthesis-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/baseline-synthesis-002.html)
 - [baseline-synthesis-003.html](https://wpt.fyi/results/css/css-flexbox/baseline-synthesis-003.html "css/css-flexbox/baseline-synthesis-003.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/baseline-synthesis-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/baseline-synthesis-003.html)
 - [baseline-synthesis-004.html](https://wpt.fyi/results/css/css-flexbox/baseline-synthesis-004.html "css/css-flexbox/baseline-synthesis-004.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/baseline-synthesis-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/baseline-synthesis-004.html)
 - [baseline-synthesis-vert-lr-line-under.html](https://wpt.fyi/results/css/css-flexbox/baseline-synthesis-vert-lr-line-under.html "css/css-flexbox/baseline-synthesis-vert-lr-line-under.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/baseline-synthesis-vert-lr-line-under.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/baseline-synthesis-vert-lr-line-under.html)
 - [display-flex-001.htm](https://wpt.fyi/results/css/css-flexbox/display-flex-001.htm "css/css-flexbox/display-flex-001.htm")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/display-flex-001.htm)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/display-flex-001.htm)
 - [dynamic-change-simplified-layout-002.html](https://wpt.fyi/results/css/css-flexbox/dynamic-change-simplified-layout-002.html "css/css-flexbox/dynamic-change-simplified-layout-002.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/dynamic-change-simplified-layout-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/dynamic-change-simplified-layout-002.html)
 - [dynamic-change-simplified-layout.html](https://wpt.fyi/results/css/css-flexbox/dynamic-change-simplified-layout.html "css/css-flexbox/dynamic-change-simplified-layout.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/dynamic-change-simplified-layout.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/dynamic-change-simplified-layout.html)
 - [fixedpos-video-in-abspos-quirk-crash.html](https://wpt.fyi/results/css/css-flexbox/fixedpos-video-in-abspos-quirk-crash.html "css/css-flexbox/fixedpos-video-in-abspos-quirk-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/fixedpos-video-in-abspos-quirk-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/fixedpos-video-in-abspos-quirk-crash.html)
 - [flexbox_flex-0-0-0.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-0-0-0.html "css/css-flexbox/flexbox_flex-0-0-0.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-0-0-0.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-0-0-0.html)
 - [flexbox_flex-0-0-0-unitless.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-0-0-0-unitless.html "css/css-flexbox/flexbox_flex-0-0-0-unitless.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-0-0-0-unitless.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-0-0-0-unitless.html)
 - [flexbox_flex-0-0-1-unitless-basis.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-0-0-1-unitless-basis.html "css/css-flexbox/flexbox_flex-0-0-1-unitless-basis.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-0-0-1-unitless-basis.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-0-0-1-unitless-basis.html)
 - [flexbox_flex-0-0-auto.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-0-0-auto.html "css/css-flexbox/flexbox_flex-0-0-auto.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-0-0-auto.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-0-0-auto.html)
 - [flexbox_flex-0-0-auto-shrink.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-0-0-auto-shrink.html "css/css-flexbox/flexbox_flex-0-0-auto-shrink.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-0-0-auto-shrink.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-0-0-auto-shrink.html)
 - [flexbox_flex-0-0.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-0-0.html "css/css-flexbox/flexbox_flex-0-0.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-0-0.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-0-0.html)
 - [flexbox_flex-0-0-N.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-0-0-N.html "css/css-flexbox/flexbox_flex-0-0-N.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-0-0-N.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-0-0-N.html)
 - [flexbox_flex-0-0-Npercent.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-0-0-Npercent.html "css/css-flexbox/flexbox_flex-0-0-Npercent.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-0-0-Npercent.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-0-0-Npercent.html)
 - [flexbox_flex-0-0-Npercent-shrink.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-0-0-Npercent-shrink.html "css/css-flexbox/flexbox_flex-0-0-Npercent-shrink.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-0-0-Npercent-shrink.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-0-0-Npercent-shrink.html)
 - [flexbox_flex-0-0-N-shrink.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-0-0-N-shrink.html "css/css-flexbox/flexbox_flex-0-0-N-shrink.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-0-0-N-shrink.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-0-0-N-shrink.html)
 - [flexbox_flex-0-0-N-unitless-basis.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-0-0-N-unitless-basis.html "css/css-flexbox/flexbox_flex-0-0-N-unitless-basis.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-0-0-N-unitless-basis.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-0-0-N-unitless-basis.html)
 - [flexbox_flex-0-1-0.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-0-1-0.html "css/css-flexbox/flexbox_flex-0-1-0.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-0-1-0.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-0-1-0.html)
 - [flexbox_flex-0-1-0-unitless.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-0-1-0-unitless.html "css/css-flexbox/flexbox_flex-0-1-0-unitless.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-0-1-0-unitless.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-0-1-0-unitless.html)
 - [flexbox_flex-0-1-1-unitless-basis.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-0-1-1-unitless-basis.html "css/css-flexbox/flexbox_flex-0-1-1-unitless-basis.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-0-1-1-unitless-basis.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-0-1-1-unitless-basis.html)
 - [flexbox_flex-0-1-auto.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-0-1-auto.html "css/css-flexbox/flexbox_flex-0-1-auto.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-0-1-auto.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-0-1-auto.html)
 - [flexbox_flex-0-1-auto-shrink.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-0-1-auto-shrink.html "css/css-flexbox/flexbox_flex-0-1-auto-shrink.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-0-1-auto-shrink.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-0-1-auto-shrink.html)
 - [flexbox_flex-0-1.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-0-1.html "css/css-flexbox/flexbox_flex-0-1.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-0-1.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-0-1.html)
 - [flexbox_flex-0-1-N.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-0-1-N.html "css/css-flexbox/flexbox_flex-0-1-N.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-0-1-N.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-0-1-N.html)
 - [flexbox_flex-0-1-Npercent.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-0-1-Npercent.html "css/css-flexbox/flexbox_flex-0-1-Npercent.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-0-1-Npercent.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-0-1-Npercent.html)
 - [flexbox_flex-0-1-Npercent-shrink.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-0-1-Npercent-shrink.html "css/css-flexbox/flexbox_flex-0-1-Npercent-shrink.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-0-1-Npercent-shrink.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-0-1-Npercent-shrink.html)
 - [flexbox_flex-0-1-N-shrink.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-0-1-N-shrink.html "css/css-flexbox/flexbox_flex-0-1-N-shrink.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-0-1-N-shrink.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-0-1-N-shrink.html)
 - [flexbox_flex-0-1-N-unitless-basis.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-0-1-N-unitless-basis.html "css/css-flexbox/flexbox_flex-0-1-N-unitless-basis.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-0-1-N-unitless-basis.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-0-1-N-unitless-basis.html)
 - [flexbox_flex-0-auto.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-0-auto.html "css/css-flexbox/flexbox_flex-0-auto.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-0-auto.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-0-auto.html)
 - [flexbox_flex-0-N-0.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-0-N-0.html "css/css-flexbox/flexbox_flex-0-N-0.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-0-N-0.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-0-N-0.html)
 - [flexbox_flex-0-N-0-unitless.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-0-N-0-unitless.html "css/css-flexbox/flexbox_flex-0-N-0-unitless.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-0-N-0-unitless.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-0-N-0-unitless.html)
 - [flexbox_flex-0-N-auto.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-0-N-auto.html "css/css-flexbox/flexbox_flex-0-N-auto.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-0-N-auto.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-0-N-auto.html)
 - [flexbox_flex-0-N-auto-shrink.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-0-N-auto-shrink.html "css/css-flexbox/flexbox_flex-0-N-auto-shrink.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-0-N-auto-shrink.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-0-N-auto-shrink.html)
 - [flexbox_flex-0-N.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-0-N.html "css/css-flexbox/flexbox_flex-0-N.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-0-N.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-0-N.html)
 - [flexbox_flex-0-N-N.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-0-N-N.html "css/css-flexbox/flexbox_flex-0-N-N.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-0-N-N.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-0-N-N.html)
 - [flexbox_flex-0-N-Npercent.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-0-N-Npercent.html "css/css-flexbox/flexbox_flex-0-N-Npercent.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-0-N-Npercent.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-0-N-Npercent.html)
 - [flexbox_flex-0-N-Npercent-shrink.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-0-N-Npercent-shrink.html "css/css-flexbox/flexbox_flex-0-N-Npercent-shrink.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-0-N-Npercent-shrink.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-0-N-Npercent-shrink.html)
 - [flexbox_flex-0-N-N-shrink.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-0-N-N-shrink.html "css/css-flexbox/flexbox_flex-0-N-N-shrink.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-0-N-N-shrink.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-0-N-N-shrink.html)
 - [flexbox_flex-1-0-0.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-1-0-0.html "css/css-flexbox/flexbox_flex-1-0-0.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-1-0-0.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-1-0-0.html)
 - [flexbox_flex-1-0-0-unitless.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-1-0-0-unitless.html "css/css-flexbox/flexbox_flex-1-0-0-unitless.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-1-0-0-unitless.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-1-0-0-unitless.html)
 - [flexbox_flex-1-0-auto.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-1-0-auto.html "css/css-flexbox/flexbox_flex-1-0-auto.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-1-0-auto.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-1-0-auto.html)
 - [flexbox_flex-1-0-auto-shrink.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-1-0-auto-shrink.html "css/css-flexbox/flexbox_flex-1-0-auto-shrink.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-1-0-auto-shrink.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-1-0-auto-shrink.html)
 - [flexbox_flex-1-0.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-1-0.html "css/css-flexbox/flexbox_flex-1-0.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-1-0.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-1-0.html)
 - [flexbox_flex-1-0-N.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-1-0-N.html "css/css-flexbox/flexbox_flex-1-0-N.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-1-0-N.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-1-0-N.html)
 - [flexbox_flex-1-0-Npercent.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-1-0-Npercent.html "css/css-flexbox/flexbox_flex-1-0-Npercent.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-1-0-Npercent.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-1-0-Npercent.html)
 - [flexbox_flex-1-0-Npercent-shrink.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-1-0-Npercent-shrink.html "css/css-flexbox/flexbox_flex-1-0-Npercent-shrink.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-1-0-Npercent-shrink.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-1-0-Npercent-shrink.html)
 - [flexbox_flex-1-0-N-shrink.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-1-0-N-shrink.html "css/css-flexbox/flexbox_flex-1-0-N-shrink.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-1-0-N-shrink.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-1-0-N-shrink.html)
 - [flexbox_flex-1-1-0.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-1-1-0.html "css/css-flexbox/flexbox_flex-1-1-0.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-1-1-0.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-1-1-0.html)
 - [flexbox_flex-1-1-0-unitless.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-1-1-0-unitless.html "css/css-flexbox/flexbox_flex-1-1-0-unitless.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-1-1-0-unitless.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-1-1-0-unitless.html)
 - [flexbox_flex-1-1-auto.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-1-1-auto.html "css/css-flexbox/flexbox_flex-1-1-auto.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-1-1-auto.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-1-1-auto.html)
 - [flexbox_flex-1-1-auto-shrink.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-1-1-auto-shrink.html "css/css-flexbox/flexbox_flex-1-1-auto-shrink.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-1-1-auto-shrink.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-1-1-auto-shrink.html)
 - [flexbox_flex-1-1.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-1-1.html "css/css-flexbox/flexbox_flex-1-1.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-1-1.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-1-1.html)
 - [flexbox_flex-1-1-N.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-1-1-N.html "css/css-flexbox/flexbox_flex-1-1-N.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-1-1-N.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-1-1-N.html)
 - [flexbox_flex-1-1-Npercent.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-1-1-Npercent.html "css/css-flexbox/flexbox_flex-1-1-Npercent.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-1-1-Npercent.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-1-1-Npercent.html)
 - [flexbox_flex-1-1-Npercent-shrink.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-1-1-Npercent-shrink.html "css/css-flexbox/flexbox_flex-1-1-Npercent-shrink.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-1-1-Npercent-shrink.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-1-1-Npercent-shrink.html)
 - [flexbox_flex-1-1-N-shrink.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-1-1-N-shrink.html "css/css-flexbox/flexbox_flex-1-1-N-shrink.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-1-1-N-shrink.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-1-1-N-shrink.html)
 - [flexbox_flex-1-N-0.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-1-N-0.html "css/css-flexbox/flexbox_flex-1-N-0.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-1-N-0.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-1-N-0.html)
 - [flexbox_flex-1-N-0-unitless.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-1-N-0-unitless.html "css/css-flexbox/flexbox_flex-1-N-0-unitless.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-1-N-0-unitless.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-1-N-0-unitless.html)
 - [flexbox_flex-1-N-auto.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-1-N-auto.html "css/css-flexbox/flexbox_flex-1-N-auto.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-1-N-auto.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-1-N-auto.html)
 - [flexbox_flex-1-N-auto-shrink.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-1-N-auto-shrink.html "css/css-flexbox/flexbox_flex-1-N-auto-shrink.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-1-N-auto-shrink.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-1-N-auto-shrink.html)
 - [flexbox_flex-1-N.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-1-N.html "css/css-flexbox/flexbox_flex-1-N.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-1-N.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-1-N.html)
 - [flexbox_flex-1-N-N.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-1-N-N.html "css/css-flexbox/flexbox_flex-1-N-N.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-1-N-N.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-1-N-N.html)
 - [flexbox_flex-1-N-Npercent.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-1-N-Npercent.html "css/css-flexbox/flexbox_flex-1-N-Npercent.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-1-N-Npercent.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-1-N-Npercent.html)
 - [flexbox_flex-1-N-Npercent-shrink.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-1-N-Npercent-shrink.html "css/css-flexbox/flexbox_flex-1-N-Npercent-shrink.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-1-N-Npercent-shrink.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-1-N-Npercent-shrink.html)
 - [flexbox_flex-1-N-N-shrink.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-1-N-N-shrink.html "css/css-flexbox/flexbox_flex-1-N-N-shrink.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-1-N-N-shrink.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-1-N-N-shrink.html)
 - [flexbox_flex-N-0-0.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-N-0-0.html "css/css-flexbox/flexbox_flex-N-0-0.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-N-0-0.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-N-0-0.html)
 - [flexbox_flex-N-0-0-unitless.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-N-0-0-unitless.html "css/css-flexbox/flexbox_flex-N-0-0-unitless.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-N-0-0-unitless.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-N-0-0-unitless.html)
 - [flexbox_flex-N-0-auto.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-N-0-auto.html "css/css-flexbox/flexbox_flex-N-0-auto.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-N-0-auto.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-N-0-auto.html)
 - [flexbox_flex-N-0-auto-shrink.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-N-0-auto-shrink.html "css/css-flexbox/flexbox_flex-N-0-auto-shrink.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-N-0-auto-shrink.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-N-0-auto-shrink.html)
 - [flexbox_flex-N-0.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-N-0.html "css/css-flexbox/flexbox_flex-N-0.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-N-0.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-N-0.html)
 - [flexbox_flex-N-0-N.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-N-0-N.html "css/css-flexbox/flexbox_flex-N-0-N.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-N-0-N.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-N-0-N.html)
 - [flexbox_flex-N-0-Npercent.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-N-0-Npercent.html "css/css-flexbox/flexbox_flex-N-0-Npercent.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-N-0-Npercent.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-N-0-Npercent.html)
 - [flexbox_flex-N-0-Npercent-shrink.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-N-0-Npercent-shrink.html "css/css-flexbox/flexbox_flex-N-0-Npercent-shrink.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-N-0-Npercent-shrink.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-N-0-Npercent-shrink.html)
 - [flexbox_flex-N-0-N-shrink.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-N-0-N-shrink.html "css/css-flexbox/flexbox_flex-N-0-N-shrink.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-N-0-N-shrink.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-N-0-N-shrink.html)
 - [flexbox_flex-N-1-0.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-N-1-0.html "css/css-flexbox/flexbox_flex-N-1-0.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-N-1-0.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-N-1-0.html)
 - [flexbox_flex-N-1-0-unitless.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-N-1-0-unitless.html "css/css-flexbox/flexbox_flex-N-1-0-unitless.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-N-1-0-unitless.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-N-1-0-unitless.html)
 - [flexbox_flex-N-1-auto.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-N-1-auto.html "css/css-flexbox/flexbox_flex-N-1-auto.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-N-1-auto.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-N-1-auto.html)
 - [flexbox_flex-N-1-auto-shrink.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-N-1-auto-shrink.html "css/css-flexbox/flexbox_flex-N-1-auto-shrink.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-N-1-auto-shrink.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-N-1-auto-shrink.html)
 - [flexbox_flex-N-1.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-N-1.html "css/css-flexbox/flexbox_flex-N-1.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-N-1.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-N-1.html)
 - [flexbox_flex-N-1-N.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-N-1-N.html "css/css-flexbox/flexbox_flex-N-1-N.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-N-1-N.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-N-1-N.html)
 - [flexbox_flex-N-1-Npercent.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-N-1-Npercent.html "css/css-flexbox/flexbox_flex-N-1-Npercent.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-N-1-Npercent.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-N-1-Npercent.html)
 - [flexbox_flex-N-1-Npercent-shrink.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-N-1-Npercent-shrink.html "css/css-flexbox/flexbox_flex-N-1-Npercent-shrink.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-N-1-Npercent-shrink.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-N-1-Npercent-shrink.html)
 - [flexbox_flex-N-1-N-shrink.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-N-1-N-shrink.html "css/css-flexbox/flexbox_flex-N-1-N-shrink.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-N-1-N-shrink.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-N-1-N-shrink.html)
 - [flexbox_flex-N-N-0.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-N-N-0.html "css/css-flexbox/flexbox_flex-N-N-0.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-N-N-0.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-N-N-0.html)
 - [flexbox_flex-N-N-0-unitless.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-N-N-0-unitless.html "css/css-flexbox/flexbox_flex-N-N-0-unitless.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-N-N-0-unitless.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-N-N-0-unitless.html)
 - [flexbox_flex-N-N-auto.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-N-N-auto.html "css/css-flexbox/flexbox_flex-N-N-auto.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-N-N-auto.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-N-N-auto.html)
 - [flexbox_flex-N-N-auto-shrink.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-N-N-auto-shrink.html "css/css-flexbox/flexbox_flex-N-N-auto-shrink.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-N-N-auto-shrink.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-N-N-auto-shrink.html)
 - [flexbox_flex-N-N.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-N-N.html "css/css-flexbox/flexbox_flex-N-N.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-N-N.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-N-N.html)
 - [flexbox_flex-N-N-N.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-N-N-N.html "css/css-flexbox/flexbox_flex-N-N-N.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-N-N-N.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-N-N-N.html)
 - [flexbox_flex-N-N-Npercent.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-N-N-Npercent.html "css/css-flexbox/flexbox_flex-N-N-Npercent.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-N-N-Npercent.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-N-N-Npercent.html)
 - [flexbox_flex-N-N-Npercent-shrink.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-N-N-Npercent-shrink.html "css/css-flexbox/flexbox_flex-N-N-Npercent-shrink.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-N-N-Npercent-shrink.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-N-N-Npercent-shrink.html)
 - [flexbox_flex-N-N-N-shrink.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-N-N-N-shrink.html "css/css-flexbox/flexbox_flex-N-N-N-shrink.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-N-N-N-shrink.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-N-N-N-shrink.html)
 - [flexbox_flex-formatting-interop.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-formatting-interop.html "css/css-flexbox/flexbox_flex-formatting-interop.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-formatting-interop.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-formatting-interop.html)
 - [flexbox_generated-flex.html](https://wpt.fyi/results/css/css-flexbox/flexbox_generated-flex.html "css/css-flexbox/flexbox_generated-flex.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_generated-flex.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_generated-flex.html)
 - [flexbox_generated.html](https://wpt.fyi/results/css/css-flexbox/flexbox_generated.html "css/css-flexbox/flexbox_generated.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_generated.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_generated.html)
 - [flexbox_generated-nested-flex.html](https://wpt.fyi/results/css/css-flexbox/flexbox_generated-nested-flex.html "css/css-flexbox/flexbox_generated-nested-flex.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_generated-nested-flex.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_generated-nested-flex.html)
 - [flexbox-iframe-intrinsic-size-001.html](https://wpt.fyi/results/css/css-flexbox/flexbox-iframe-intrinsic-size-001.html "css/css-flexbox/flexbox-iframe-intrinsic-size-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-iframe-intrinsic-size-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-iframe-intrinsic-size-001.html)
 - [flexbox_item-bottom-float.html](https://wpt.fyi/results/css/css-flexbox/flexbox_item-bottom-float.html "css/css-flexbox/flexbox_item-bottom-float.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_item-bottom-float.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_item-bottom-float.html)
 - [flexbox_item-clear.html](https://wpt.fyi/results/css/css-flexbox/flexbox_item-clear.html "css/css-flexbox/flexbox_item-clear.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_item-clear.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_item-clear.html)
 - [flexbox_item-float.html](https://wpt.fyi/results/css/css-flexbox/flexbox_item-float.html "css/css-flexbox/flexbox_item-float.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_item-float.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_item-float.html)
 - [flexbox_item-top-float.html](https://wpt.fyi/results/css/css-flexbox/flexbox_item-top-float.html "css/css-flexbox/flexbox_item-top-float.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_item-top-float.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_item-top-float.html)
 - [flexbox_item-vertical-align.html](https://wpt.fyi/results/css/css-flexbox/flexbox_item-vertical-align.html "css/css-flexbox/flexbox_item-vertical-align.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_item-vertical-align.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_item-vertical-align.html)
 - [flexbox_block.html](https://wpt.fyi/results/css/css-flexbox/flexbox_block.html "css/css-flexbox/flexbox_block.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_block.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_block.html)
 - [flexbox_box-clear.html](https://wpt.fyi/results/css/css-flexbox/flexbox_box-clear.html "css/css-flexbox/flexbox_box-clear.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_box-clear.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_box-clear.html)
 - [flexbox_display.html](https://wpt.fyi/results/css/css-flexbox/flexbox_display.html "css/css-flexbox/flexbox_display.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_display.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_display.html)
 - [flexbox_fbfc2.html](https://wpt.fyi/results/css/css-flexbox/flexbox_fbfc2.html "css/css-flexbox/flexbox_fbfc2.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_fbfc2.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_fbfc2.html)
 - [flexbox_fbfc.html](https://wpt.fyi/results/css/css-flexbox/flexbox_fbfc.html "css/css-flexbox/flexbox_fbfc.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_fbfc.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_fbfc.html)
 - [flexbox_nested-flex.html](https://wpt.fyi/results/css/css-flexbox/flexbox_nested-flex.html "css/css-flexbox/flexbox_nested-flex.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_nested-flex.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_nested-flex.html)
 - [flexbox-root-node-001a.html](https://wpt.fyi/results/css/css-flexbox/flexbox-root-node-001a.html "css/css-flexbox/flexbox-root-node-001a.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-root-node-001a.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-root-node-001a.html)
 - [flexbox-root-node-001b.html](https://wpt.fyi/results/css/css-flexbox/flexbox-root-node-001b.html "css/css-flexbox/flexbox-root-node-001b.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-root-node-001b.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-root-node-001b.html)
 - [flexbox_stf-fixpos.html](https://wpt.fyi/results/css/css-flexbox/flexbox_stf-fixpos.html "css/css-flexbox/flexbox_stf-fixpos.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_stf-fixpos.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_stf-fixpos.html)
 - [flexbox_stf-float.html](https://wpt.fyi/results/css/css-flexbox/flexbox_stf-float.html "css/css-flexbox/flexbox_stf-float.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_stf-float.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_stf-float.html)
 - [flexbox_stf-inline-block.html](https://wpt.fyi/results/css/css-flexbox/flexbox_stf-inline-block.html "css/css-flexbox/flexbox_stf-inline-block.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_stf-inline-block.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_stf-inline-block.html)
 - [flexbox_stf-table-caption.html](https://wpt.fyi/results/css/css-flexbox/flexbox_stf-table-caption.html "css/css-flexbox/flexbox_stf-table-caption.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_stf-table-caption.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_stf-table-caption.html)
 - [flexbox_stf-table-cell.html](https://wpt.fyi/results/css/css-flexbox/flexbox_stf-table-cell.html "css/css-flexbox/flexbox_stf-table-cell.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_stf-table-cell.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_stf-table-cell.html)
 - [flexbox_stf-table.html](https://wpt.fyi/results/css/css-flexbox/flexbox_stf-table.html "css/css-flexbox/flexbox_stf-table.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_stf-table.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_stf-table.html)
 - [flexbox_stf-table-row-group.html](https://wpt.fyi/results/css/css-flexbox/flexbox_stf-table-row-group.html "css/css-flexbox/flexbox_stf-table-row-group.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_stf-table-row-group.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_stf-table-row-group.html)
 - [flexbox_stf-table-row.html](https://wpt.fyi/results/css/css-flexbox/flexbox_stf-table-row.html "css/css-flexbox/flexbox_stf-table-row.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_stf-table-row.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_stf-table-row.html)
 - [flexbox_stf-table-singleline-2.html](https://wpt.fyi/results/css/css-flexbox/flexbox_stf-table-singleline-2.html "css/css-flexbox/flexbox_stf-table-singleline-2.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_stf-table-singleline-2.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_stf-table-singleline-2.html)
 - [flexbox_stf-table-singleline.html](https://wpt.fyi/results/css/css-flexbox/flexbox_stf-table-singleline.html "css/css-flexbox/flexbox_stf-table-singleline.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_stf-table-singleline.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_stf-table-singleline.html)
 - [flexbox_table-fixed-layout.html](https://wpt.fyi/results/css/css-flexbox/flexbox_table-fixed-layout.html "css/css-flexbox/flexbox_table-fixed-layout.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_table-fixed-layout.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_table-fixed-layout.html)
 - [flexbox-with-multi-column-property.html](https://wpt.fyi/results/css/css-flexbox/flexbox-with-multi-column-property.html "css/css-flexbox/flexbox-with-multi-column-property.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-with-multi-column-property.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-with-multi-column-property.html)
 - [flexbox_computedstyle_display.html](https://wpt.fyi/results/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_display.html "css/css-flexbox/getcomputedstyle/flexbox_computedstyle_display.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_display.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_display.html)
 - [grid-flex-item-001.html](https://wpt.fyi/results/css/css-flexbox/grid-flex-item-001.html "css/css-flexbox/grid-flex-item-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/grid-flex-item-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/grid-flex-item-001.html)
 - [grid-flex-item-002.html](https://wpt.fyi/results/css/css-flexbox/grid-flex-item-002.html "css/css-flexbox/grid-flex-item-002.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/grid-flex-item-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/grid-flex-item-002.html)
 - [grid-flex-item-003.html](https://wpt.fyi/results/css/css-flexbox/grid-flex-item-003.html "css/css-flexbox/grid-flex-item-003.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/grid-flex-item-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/grid-flex-item-003.html)
 - [grid-flex-item-004.html](https://wpt.fyi/results/css/css-flexbox/grid-flex-item-004.html "css/css-flexbox/grid-flex-item-004.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/grid-flex-item-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/grid-flex-item-004.html)
 - [grid-flex-item-005.html](https://wpt.fyi/results/css/css-flexbox/grid-flex-item-005.html "css/css-flexbox/grid-flex-item-005.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/grid-flex-item-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/grid-flex-item-005.html)
 - [grid-flex-item-006.html](https://wpt.fyi/results/css/css-flexbox/grid-flex-item-006.html "css/css-flexbox/grid-flex-item-006.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/grid-flex-item-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/grid-flex-item-006.html)
 - [grid-flex-item-007.html](https://wpt.fyi/results/css/css-flexbox/grid-flex-item-007.html "css/css-flexbox/grid-flex-item-007.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/grid-flex-item-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/grid-flex-item-007.html)
 - [flexbox_interactive_flex-transitions.html (manual test)
 ][[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/interactive/flexbox_interactive_flex-transitions.html)
 - [flexbox_interactive_order-transitions-2.html (manual test)
 ][[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/interactive/flexbox_interactive_order-transitions-2.html)
 - [flexbox_interactive_order-transitions.html (manual test)
 ][[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/interactive/flexbox_interactive_order-transitions.html)
 - [nested-flex-image-loading-invalidates-intrinsic-sizes.html](https://wpt.fyi/results/css/css-flexbox/nested-flex-image-loading-invalidates-intrinsic-sizes.html "css/css-flexbox/nested-flex-image-loading-invalidates-intrinsic-sizes.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/nested-flex-image-loading-invalidates-intrinsic-sizes.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/nested-flex-image-loading-invalidates-intrinsic-sizes.html)
 - [percentage-margins-001.html](https://wpt.fyi/results/css/css-flexbox/percentage-margins-001.html "css/css-flexbox/percentage-margins-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/percentage-margins-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/percentage-margins-001.html)
 - [stretch-after-sibling-size-change.html](https://wpt.fyi/results/css/css-flexbox/stretch-after-sibling-size-change.html "css/css-flexbox/stretch-after-sibling-size-change.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/stretch-after-sibling-size-change.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/stretch-after-sibling-size-change.html)
 - [stretched-child-in-nested-flexbox-001.html](https://wpt.fyi/results/css/css-flexbox/stretched-child-in-nested-flexbox-001.html "css/css-flexbox/stretched-child-in-nested-flexbox-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/stretched-child-in-nested-flexbox-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/stretched-child-in-nested-flexbox-001.html)
 - [stretched-child-in-nested-flexbox-002.html](https://wpt.fyi/results/css/css-flexbox/stretched-child-in-nested-flexbox-002.html "css/css-flexbox/stretched-child-in-nested-flexbox-002.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/stretched-child-in-nested-flexbox-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/stretched-child-in-nested-flexbox-002.html)
 - [stretched-child-in-nested-flexbox-003.html](https://wpt.fyi/results/css/css-flexbox/stretched-child-in-nested-flexbox-003.html "css/css-flexbox/stretched-child-in-nested-flexbox-003.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/stretched-child-in-nested-flexbox-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/stretched-child-in-nested-flexbox-003.html)
 - [stretched-child-shrink-on-relayout.html](https://wpt.fyi/results/css/css-flexbox/stretched-child-shrink-on-relayout.html "css/css-flexbox/stretched-child-shrink-on-relayout.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/stretched-child-shrink-on-relayout.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/stretched-child-shrink-on-relayout.html)
 - [stretch-flex-item-checkbox-input.html](https://wpt.fyi/results/css/css-flexbox/stretch-flex-item-checkbox-input.html "css/css-flexbox/stretch-flex-item-checkbox-input.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/stretch-flex-item-checkbox-input.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/stretch-flex-item-checkbox-input.html)
 - [stretch-flex-item-radio-input.html](https://wpt.fyi/results/css/css-flexbox/stretch-flex-item-radio-input.html "css/css-flexbox/stretch-flex-item-radio-input.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/stretch-flex-item-radio-input.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/stretch-flex-item-radio-input.html)
 - [stretching-orthogonal-flows.html](https://wpt.fyi/results/css/css-flexbox/stretching-orthogonal-flows.html "css/css-flexbox/stretching-orthogonal-flows.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/stretching-orthogonal-flows.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/stretching-orthogonal-flows.html)
 - [table-with-percent-intrinsic-width.html](https://wpt.fyi/results/css/css-flexbox/table-with-percent-intrinsic-width.html "css/css-flexbox/table-with-percent-intrinsic-width.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/table-with-percent-intrinsic-width.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/table-with-percent-intrinsic-width.html)

[inline-flex]
: This value causes an element to generate a [flex
 container](#flex-container) box that is
 [inline-level](https://drafts.csswg.org/css-display-4/#inline-level) when placed in [flow
 layout](https://drafts.csswg.org/css-display-4/#flow-layout).
 Tests
 - [flexbox_inline.html](https://wpt.fyi/results/css/css-flexbox/flexbox_inline.html "css/css-flexbox/flexbox_inline.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_inline.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_inline.html)
 - [flex-inline.html](https://wpt.fyi/results/css/css-flexbox/flex-inline.html "css/css-flexbox/flex-inline.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-inline.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-inline.html)
 - [flexbox_inline-float.html](https://wpt.fyi/results/css/css-flexbox/flexbox_inline-float.html "css/css-flexbox/flexbox_inline-float.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_inline-float.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_inline-float.html)
 - [inline-flexbox-absurd-block-size-crash.html](https://wpt.fyi/results/css/css-flexbox/inline-flexbox-absurd-block-size-crash.html "css/css-flexbox/inline-flexbox-absurd-block-size-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/inline-flexbox-absurd-block-size-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/inline-flexbox-absurd-block-size-crash.html)
 - [inline-flexbox-wrap-vertically-width-calculation.html](https://wpt.fyi/results/css/css-flexbox/inline-flexbox-wrap-vertically-width-calculation.html "css/css-flexbox/inline-flexbox-wrap-vertically-width-calculation.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/inline-flexbox-wrap-vertically-width-calculation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/inline-flexbox-wrap-vertically-width-calculation.html)
 - [inline-flex-editing-crash.html](https://wpt.fyi/results/css/css-flexbox/inline-flex-editing-crash.html "css/css-flexbox/inline-flex-editing-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/inline-flex-editing-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/inline-flex-editing-crash.html)
 - [inline-flex-editing-with-updating-text-crash.html](https://wpt.fyi/results/css/css-flexbox/inline-flex-editing-with-updating-text-crash.html "css/css-flexbox/inline-flex-editing-with-updating-text-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/inline-flex-editing-with-updating-text-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/inline-flex-editing-with-updating-text-crash.html)
 - [inline-flex-frameset-main-axis-crash.html](https://wpt.fyi/results/css/css-flexbox/inline-flex-frameset-main-axis-crash.html "css/css-flexbox/inline-flex-frameset-main-axis-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/inline-flex-frameset-main-axis-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/inline-flex-frameset-main-axis-crash.html)
 - [inline-flex.html](https://wpt.fyi/results/css/css-flexbox/inline-flex.html "css/css-flexbox/inline-flex.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/inline-flex.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/inline-flex.html)
 - [inline-flex-min-content-height.html](https://wpt.fyi/results/css/css-flexbox/inline-flex-min-content-height.html "css/css-flexbox/inline-flex-min-content-height.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/inline-flex-min-content-height.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/inline-flex-min-content-height.html)
 - [flexbox_computedstyle_display-inline.html](https://wpt.fyi/results/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_display-inline.html "css/css-flexbox/getcomputedstyle/flexbox_computedstyle_display-inline.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_display-inline.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_display-inline.html)
 - [intrinsic-width-orthogonal-writing-mode.html](https://wpt.fyi/results/css/css-flexbox/intrinsic-width-orthogonal-writing-mode.html "css/css-flexbox/intrinsic-width-orthogonal-writing-mode.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/intrinsic-width-orthogonal-writing-mode.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/intrinsic-width-orthogonal-writing-mode.html)

A [flex container](#flex-container) establishes a new [flex formatting
context] for its contents. This is the same as establishing a block
formatting context, except that flex layout is used instead of block
layout. For example, floats do not intrude into the flex container, and
the flex container's margins do not collapse with the margins of its
contents. [Flex containers] form a containing
block for their contents [exactly like block containers
do](https://www.w3.org/TR/CSS2/visudet.html#containing-block-details).
[\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")
The
[overflow](https://drafts.csswg.org/css-overflow-3/#propdef-overflow) property applies to [flex
containers].

Tests

- [flexbox-overflow-horiz-001.html](https://wpt.fyi/results/css/css-flexbox/flexbox-overflow-horiz-001.html "css/css-flexbox/flexbox-overflow-horiz-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-overflow-horiz-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-overflow-horiz-001.html)
- [flexbox-overflow-horiz-002.html](https://wpt.fyi/results/css/css-flexbox/flexbox-overflow-horiz-002.html "css/css-flexbox/flexbox-overflow-horiz-002.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-overflow-horiz-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-overflow-horiz-002.html)
- [flexbox-overflow-horiz-003.html](https://wpt.fyi/results/css/css-flexbox/flexbox-overflow-horiz-003.html "css/css-flexbox/flexbox-overflow-horiz-003.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-overflow-horiz-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-overflow-horiz-003.html)
- [flexbox-overflow-horiz-004.html](https://wpt.fyi/results/css/css-flexbox/flexbox-overflow-horiz-004.html "css/css-flexbox/flexbox-overflow-horiz-004.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-overflow-horiz-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-overflow-horiz-004.html)
- [flexbox-overflow-horiz-005.html](https://wpt.fyi/results/css/css-flexbox/flexbox-overflow-horiz-005.html "css/css-flexbox/flexbox-overflow-horiz-005.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-overflow-horiz-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-overflow-horiz-005.html)
- [flexbox-overflow-padding-001.html](https://wpt.fyi/results/css/css-flexbox/flexbox-overflow-padding-001.html "css/css-flexbox/flexbox-overflow-padding-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-overflow-padding-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-overflow-padding-001.html)
- [flexbox-overflow-padding-002.html](https://wpt.fyi/results/css/css-flexbox/flexbox-overflow-padding-002.html "css/css-flexbox/flexbox-overflow-padding-002.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-overflow-padding-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-overflow-padding-002.html)
- [flexbox-overflow-vert-001.html](https://wpt.fyi/results/css/css-flexbox/flexbox-overflow-vert-001.html "css/css-flexbox/flexbox-overflow-vert-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-overflow-vert-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-overflow-vert-001.html)
- [flexbox-overflow-vert-002.html](https://wpt.fyi/results/css/css-flexbox/flexbox-overflow-vert-002.html "css/css-flexbox/flexbox-overflow-vert-002.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-overflow-vert-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-overflow-vert-002.html)
- [flexbox-overflow-vert-003.html](https://wpt.fyi/results/css/css-flexbox/flexbox-overflow-vert-003.html "css/css-flexbox/flexbox-overflow-vert-003.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-overflow-vert-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-overflow-vert-003.html)
- [flexbox-overflow-vert-004.html](https://wpt.fyi/results/css/css-flexbox/flexbox-overflow-vert-004.html "css/css-flexbox/flexbox-overflow-vert-004.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-overflow-vert-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-overflow-vert-004.html)
- [flexbox-overflow-vert-005.html](https://wpt.fyi/results/css/css-flexbox/flexbox-overflow-vert-005.html "css/css-flexbox/flexbox-overflow-vert-005.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-overflow-vert-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-overflow-vert-005.html)
- [flexbox_rowspan-overflow-automatic.html](https://wpt.fyi/results/css/css-flexbox/flexbox_rowspan-overflow-automatic.html "css/css-flexbox/flexbox_rowspan-overflow-automatic.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_rowspan-overflow-automatic.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_rowspan-overflow-automatic.html)
- [flexbox_rowspan-overflow.html](https://wpt.fyi/results/css/css-flexbox/flexbox_rowspan-overflow.html "css/css-flexbox/flexbox_rowspan-overflow.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_rowspan-overflow.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_rowspan-overflow.html)
- [flexbox-safe-overflow-position-001.html](https://wpt.fyi/results/css/css-flexbox/flexbox-safe-overflow-position-001.html "css/css-flexbox/flexbox-safe-overflow-position-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-safe-overflow-position-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-safe-overflow-position-001.html)
- [flexbox-safe-overflow-position-002.html](https://wpt.fyi/results/css/css-flexbox/flexbox-safe-overflow-position-002.html "css/css-flexbox/flexbox-safe-overflow-position-002.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-safe-overflow-position-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-safe-overflow-position-002.html)
- [flexbox-safe-overflow-position-003.html](https://wpt.fyi/results/css/css-flexbox/flexbox-safe-overflow-position-003.html "css/css-flexbox/flexbox-safe-overflow-position-003.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-safe-overflow-position-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-safe-overflow-position-003.html)
- [flexbox-safe-overflow-position-004.html](https://wpt.fyi/results/css/css-flexbox/flexbox-safe-overflow-position-004.html "css/css-flexbox/flexbox-safe-overflow-position-004.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-safe-overflow-position-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-safe-overflow-position-004.html)
- [flexbox-safe-overflow-position-005.html](https://wpt.fyi/results/css/css-flexbox/flexbox-safe-overflow-position-005.html "css/css-flexbox/flexbox-safe-overflow-position-005.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-safe-overflow-position-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-safe-overflow-position-005.html)
- [flexbox-safe-overflow-position-006.html](https://wpt.fyi/results/css/css-flexbox/flexbox-safe-overflow-position-006.html "css/css-flexbox/flexbox-safe-overflow-position-006.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-safe-overflow-position-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-safe-overflow-position-006.html)
- [flexbox_width-overflow.html](https://wpt.fyi/results/css/css-flexbox/flexbox_width-overflow.html "css/css-flexbox/flexbox_width-overflow.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_width-overflow.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_width-overflow.html)
- [min-size-auto-overflow-clip.html](https://wpt.fyi/results/css/css-flexbox/min-size-auto-overflow-clip.html "css/css-flexbox/min-size-auto-overflow-clip.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/min-size-auto-overflow-clip.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/min-size-auto-overflow-clip.html)
- [negative-overflow-002.html](https://wpt.fyi/results/css/css-flexbox/negative-overflow-002.html "css/css-flexbox/negative-overflow-002.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/negative-overflow-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/negative-overflow-002.html)
- [negative-overflow-003.html](https://wpt.fyi/results/css/css-flexbox/negative-overflow-003.html "css/css-flexbox/negative-overflow-003.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/negative-overflow-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/negative-overflow-003.html)
- [negative-overflow-004-no-padding.html](https://wpt.fyi/results/css/css-flexbox/negative-overflow-004-no-padding.html "css/css-flexbox/negative-overflow-004-no-padding.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/negative-overflow-004-no-padding.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/negative-overflow-004-no-padding.html)
- [negative-overflow.html](https://wpt.fyi/results/css/css-flexbox/negative-overflow.html "css/css-flexbox/negative-overflow.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/negative-overflow.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/negative-overflow.html)
- [overflow-area-001.html](https://wpt.fyi/results/css/css-flexbox/overflow-area-001.html "css/css-flexbox/overflow-area-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/overflow-area-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/overflow-area-001.html)
- [overflow-area-002.html](https://wpt.fyi/results/css/css-flexbox/overflow-area-002.html "css/css-flexbox/overflow-area-002.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/overflow-area-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/overflow-area-002.html)
- [overflow-area-003.html](https://wpt.fyi/results/css/css-flexbox/overflow-area-003.html "css/css-flexbox/overflow-area-003.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/overflow-area-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/overflow-area-003.html)
- [overflow-auto-001.html](https://wpt.fyi/results/css/css-flexbox/overflow-auto-001.html "css/css-flexbox/overflow-auto-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/overflow-auto-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/overflow-auto-001.html)
- [overflow-auto-002.html](https://wpt.fyi/results/css/css-flexbox/overflow-auto-002.html "css/css-flexbox/overflow-auto-002.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/overflow-auto-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/overflow-auto-002.html)
- [overflow-auto-003.html](https://wpt.fyi/results/css/css-flexbox/overflow-auto-003.html "css/css-flexbox/overflow-auto-003.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/overflow-auto-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/overflow-auto-003.html)
- [overflow-auto-004.html](https://wpt.fyi/results/css/css-flexbox/overflow-auto-004.html "css/css-flexbox/overflow-auto-004.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/overflow-auto-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/overflow-auto-004.html)
- [overflow-auto-005.html](https://wpt.fyi/results/css/css-flexbox/overflow-auto-005.html "css/css-flexbox/overflow-auto-005.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/overflow-auto-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/overflow-auto-005.html)
- [overflow-auto-006.html](https://wpt.fyi/results/css/css-flexbox/overflow-auto-006.html "css/css-flexbox/overflow-auto-006.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/overflow-auto-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/overflow-auto-006.html)
- [overflow-auto-007.html](https://wpt.fyi/results/css/css-flexbox/overflow-auto-007.html "css/css-flexbox/overflow-auto-007.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/overflow-auto-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/overflow-auto-007.html)
- [overflow-auto-008.html](https://wpt.fyi/results/css/css-flexbox/overflow-auto-008.html "css/css-flexbox/overflow-auto-008.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/overflow-auto-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/overflow-auto-008.html)
- [overflow-top-left.html](https://wpt.fyi/results/css/css-flexbox/overflow-top-left.html "css/css-flexbox/overflow-top-left.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/overflow-top-left.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/overflow-top-left.html)
- [padding-overflow.html](https://wpt.fyi/results/css/css-flexbox/padding-overflow.html "css/css-flexbox/padding-overflow.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/padding-overflow.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/padding-overflow.html)
- [select-as-flex-item-child-with-overflow.html](https://wpt.fyi/results/css/css-flexbox/select-as-flex-item-child-with-overflow.html "css/css-flexbox/select-as-flex-item-child-with-overflow.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/select-as-flex-item-child-with-overflow.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/select-as-flex-item-child-with-overflow.html)
- [select-as-flex-item-with-overflow.html](https://wpt.fyi/results/css/css-flexbox/select-as-flex-item-with-overflow.html "css/css-flexbox/select-as-flex-item-with-overflow.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/select-as-flex-item-with-overflow.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/select-as-flex-item-with-overflow.html)
- [text-overflow-on-flexbox-001.html](https://wpt.fyi/results/css/css-flexbox/text-overflow-on-flexbox-001.html "css/css-flexbox/text-overflow-on-flexbox-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/text-overflow-on-flexbox-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/text-overflow-on-flexbox-001.html)
- [synthesize-vrl-baseline.html](https://wpt.fyi/results/css/css-flexbox/synthesize-vrl-baseline.html "css/css-flexbox/synthesize-vrl-baseline.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/synthesize-vrl-baseline.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/synthesize-vrl-baseline.html)

Flex containers are not block containers, and so some properties that
were designed with the assumption of block layout don't apply in the
context of flex layout. In particular:

- [float](https://drafts.csswg.org/css2/#propdef-float) and
 [clear](https://drafts.csswg.org/css2/#propdef-clear) do not create floating or
 clearance of [flex item](#flex-item), and do not take it
 [out-of-flow](https://drafts.csswg.org/css-display-4/#out-of-flow).

- [vertical-align](https://drafts.csswg.org/css-inline-3/#propdef-vertical-align) has no effect on a flex item.

- the
 [::first-line](https://drafts.csswg.org/css-pseudo-4/#selectordef-first-line) and
 [::first-letter](https://drafts.csswg.org/css-pseudo-4/#selectordef-first-letter) pseudo-elements do not apply to [flex
 containers](#flex-container), and [flex containers] do
 not contribute a [first formatted
 line](https://drafts.csswg.org/css-pseudo-4/#first-formatted-line) or [first letter] to their
 ancestors.

Tests

- [align-content-wrap-004.html](https://wpt.fyi/results/css/css-flexbox/align-content-wrap-004.html "css/css-flexbox/align-content-wrap-004.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/align-content-wrap-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/align-content-wrap-004.html)
- [align-items-baseline-column-vert-lr-table-item.html](https://wpt.fyi/results/css/css-flexbox/align-items-baseline-column-vert-lr-table-item.html "css/css-flexbox/align-items-baseline-column-vert-lr-table-item.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/align-items-baseline-column-vert-lr-table-item.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/align-items-baseline-column-vert-lr-table-item.html)
- [align-items-baseline-vert-lr-column-horz-table-item.html](https://wpt.fyi/results/css/css-flexbox/align-items-baseline-vert-lr-column-horz-table-item.html "css/css-flexbox/align-items-baseline-vert-lr-column-horz-table-item.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/align-items-baseline-vert-lr-column-horz-table-item.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/align-items-baseline-vert-lr-column-horz-table-item.html)
- [align-items-baseline-vert-rl-column-horz-table-item.html](https://wpt.fyi/results/css/css-flexbox/align-items-baseline-vert-rl-column-horz-table-item.html "css/css-flexbox/align-items-baseline-vert-rl-column-horz-table-item.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/align-items-baseline-vert-rl-column-horz-table-item.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/align-items-baseline-vert-rl-column-horz-table-item.html)
- [flexbox_box-clear.html](https://wpt.fyi/results/css/css-flexbox/flexbox_box-clear.html "css/css-flexbox/flexbox_box-clear.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_box-clear.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_box-clear.html)
- [flexbox_first-letter.html](https://wpt.fyi/results/css/css-flexbox/flexbox_first-letter.html "css/css-flexbox/flexbox_first-letter.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_first-letter.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_first-letter.html)
- [flexbox_first-line.html](https://wpt.fyi/results/css/css-flexbox/flexbox_first-line.html "css/css-flexbox/flexbox_first-line.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_first-line.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_first-line.html)
- [flexbox-ignores-first-letter.html](https://wpt.fyi/results/css/css-flexbox/flexbox-ignores-first-letter.html "css/css-flexbox/flexbox-ignores-first-letter.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-ignores-first-letter.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-ignores-first-letter.html)
- [flexbox_item-vertical-align.html](https://wpt.fyi/results/css/css-flexbox/flexbox_item-vertical-align.html "css/css-flexbox/flexbox_item-vertical-align.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_item-vertical-align.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_item-vertical-align.html)
- [flexbox-with-pseudo-elements-001.html](https://wpt.fyi/results/css/css-flexbox/flexbox-with-pseudo-elements-001.html "css/css-flexbox/flexbox-with-pseudo-elements-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-with-pseudo-elements-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-with-pseudo-elements-001.html)
- [flexbox-with-pseudo-elements-002.html](https://wpt.fyi/results/css/css-flexbox/flexbox-with-pseudo-elements-002.html "css/css-flexbox/flexbox-with-pseudo-elements-002.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-with-pseudo-elements-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-with-pseudo-elements-002.html)
- [flexbox-with-pseudo-elements-003.html](https://wpt.fyi/results/css/css-flexbox/flexbox-with-pseudo-elements-003.html "css/css-flexbox/flexbox-with-pseudo-elements-003.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-with-pseudo-elements-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-with-pseudo-elements-003.html)
- [flexible-box-float.html](https://wpt.fyi/results/css/css-flexbox/flexible-box-float.html "css/css-flexbox/flexible-box-float.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexible-box-float.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexible-box-float.html)
- [flex-item-vertical-align.html](https://wpt.fyi/results/css/css-flexbox/flex-item-vertical-align.html "css/css-flexbox/flex-item-vertical-align.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-item-vertical-align.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-item-vertical-align.html)
- [flex-vertical-align-effect.html](https://wpt.fyi/results/css/css-flexbox/flex-vertical-align-effect.html "css/css-flexbox/flex-vertical-align-effect.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-vertical-align-effect.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-vertical-align-effect.html)
- [hittest-before-pseudo.html](https://wpt.fyi/results/css/css-flexbox/hittest-before-pseudo.html "css/css-flexbox/hittest-before-pseudo.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/hittest-before-pseudo.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/hittest-before-pseudo.html)

If an element's specified
[display](https://drafts.csswg.org/css-display-4/#propdef-display) is
[inline-flex](#valdef-display-inline-flex), then its [display] property computes to
[flex](#valdef-display-flex) in certain circumstances: the table in [CSS 2.1
Section 9.7](https://www.w3.org/TR/CSS2/visuren.html#dis-pos-flo) is
amended to contain an additional row, with
[inline-flex] in the
\"Specified Value\" column and [flex] in the \"Computed Value\" column.

## 4. Flex Items

Loosely speaking, the [flex items](#flex-item) of a [flex
container](#flex-container)
are boxes representing its
[in-flow](https://drafts.csswg.org/css-display-4/#in-flow) contents.

Each
[in-flow](https://drafts.csswg.org/css-display-4/#in-flow) child of a [flex
container](#flex-container)
becomes a [flex item](#flex-item),
and each child [text
sequence](https://drafts.csswg.org/css-display-4/#css-text-sequence) is wrapped in an
[anonymous](https://drafts.csswg.org/css-display-4/#anonymous) [block
container](https://drafts.csswg.org/css-display-4/#block-container) [flex item]. However, if the
entire [text sequences] contains only
[document white space
characters](https://drafts.csswg.org/css-text-4/#white-space) (i.e. characters that can be affected by the
[white-space](https://drafts.csswg.org/css-text-4/#propdef-white-space) property) it is instead not
rendered (just as if its [text
nodes](https://drafts.csswg.org/css-display-4/#text-nodes) were [display:none]).

Tests

- [anonymous-block.html](https://wpt.fyi/results/css/css-flexbox/anonymous-block.html "css/css-flexbox/anonymous-block.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/anonymous-block.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/anonymous-block.html)
- [anonymous-flex-item-001.html](https://wpt.fyi/results/css/css-flexbox/anonymous-flex-item-001.html "css/css-flexbox/anonymous-flex-item-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/anonymous-flex-item-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/anonymous-flex-item-001.html)
- [anonymous-flex-item-002.html](https://wpt.fyi/results/css/css-flexbox/anonymous-flex-item-002.html "css/css-flexbox/anonymous-flex-item-002.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/anonymous-flex-item-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/anonymous-flex-item-002.html)
- [anonymous-flex-item-003.html](https://wpt.fyi/results/css/css-flexbox/anonymous-flex-item-003.html "css/css-flexbox/anonymous-flex-item-003.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/anonymous-flex-item-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/anonymous-flex-item-003.html)
- [anonymous-flex-item-004.html](https://wpt.fyi/results/css/css-flexbox/anonymous-flex-item-004.html "css/css-flexbox/anonymous-flex-item-004.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/anonymous-flex-item-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/anonymous-flex-item-004.html)
- [anonymous-flex-item-005.html](https://wpt.fyi/results/css/css-flexbox/anonymous-flex-item-005.html "css/css-flexbox/anonymous-flex-item-005.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/anonymous-flex-item-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/anonymous-flex-item-005.html)
- [anonymous-flex-item-006.html](https://wpt.fyi/results/css/css-flexbox/anonymous-flex-item-006.html "css/css-flexbox/anonymous-flex-item-006.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/anonymous-flex-item-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/anonymous-flex-item-006.html)
- [anonymous-flex-item-document-white-space-crash.html](https://wpt.fyi/results/css/css-flexbox/anonymous-flex-item-document-white-space-crash.html "css/css-flexbox/anonymous-flex-item-document-white-space-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/anonymous-flex-item-document-white-space-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/anonymous-flex-item-document-white-space-crash.html)
- [anonymous-flex-item-restyle.html](https://wpt.fyi/results/css/css-flexbox/anonymous-flex-item-restyle.html "css/css-flexbox/anonymous-flex-item-restyle.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/anonymous-flex-item-restyle.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/anonymous-flex-item-restyle.html)
- [canvas-dynamic-change-001.html](https://wpt.fyi/results/css/css-flexbox/canvas-dynamic-change-001.html "css/css-flexbox/canvas-dynamic-change-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/canvas-dynamic-change-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/canvas-dynamic-change-001.html)
- [column-flex-child-with-max-width.html](https://wpt.fyi/results/css/css-flexbox/column-flex-child-with-max-width.html "css/css-flexbox/column-flex-child-with-max-width.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/column-flex-child-with-max-width.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/column-flex-child-with-max-width.html)
- [flexbox-whitespace-handling-001a.xhtml](https://wpt.fyi/results/css/css-flexbox/flexbox-whitespace-handling-001a.xhtml "css/css-flexbox/flexbox-whitespace-handling-001a.xhtml")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-whitespace-handling-001a.xhtml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-whitespace-handling-001a.xhtml)
- [flexbox-whitespace-handling-001b.xhtml](https://wpt.fyi/results/css/css-flexbox/flexbox-whitespace-handling-001b.xhtml "css/css-flexbox/flexbox-whitespace-handling-001b.xhtml")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-whitespace-handling-001b.xhtml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-whitespace-handling-001b.xhtml)
- [flexbox-whitespace-handling-002.xhtml](https://wpt.fyi/results/css/css-flexbox/flexbox-whitespace-handling-002.xhtml "css/css-flexbox/flexbox-whitespace-handling-002.xhtml")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-whitespace-handling-002.xhtml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-whitespace-handling-002.xhtml)
- [hittest-anonymous-box.html](https://wpt.fyi/results/css/css-flexbox/hittest-anonymous-box.html "css/css-flexbox/hittest-anonymous-box.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/hittest-anonymous-box.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/hittest-anonymous-box.html)
- [percentage-descendant-of-anonymous-flex-item.html](https://wpt.fyi/results/css/css-flexbox/percentage-descendant-of-anonymous-flex-item.html "css/css-flexbox/percentage-descendant-of-anonymous-flex-item.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/percentage-descendant-of-anonymous-flex-item.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/percentage-descendant-of-anonymous-flex-item.html)
- [percentage-size-subitems-001.html](https://wpt.fyi/results/css/css-flexbox/percentage-size-subitems-001.html "css/css-flexbox/percentage-size-subitems-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/percentage-size-subitems-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/percentage-size-subitems-001.html)
- [whitespace-in-flexitem-001.html](https://wpt.fyi/results/css/css-flexbox/whitespace-in-flexitem-001.html "css/css-flexbox/whitespace-in-flexitem-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/whitespace-in-flexitem-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/whitespace-in-flexitem-001.html)

Examples of flex items:

```
<div style="display:flex">

 <!-- flex item: block child -->
 <div id="item1">block</div>

 <!-- flex item: floated element; floating is ignored -->
 <div id="item2" style="float: left;">float</div>

 <!-- flex item: anonymous block box around inline content -->
 anonymous item 3

 <!-- flex item: inline child -->
 <span>
 item 4
 <!-- flex items do not split around blocks -->
 <q style="display: block" id=not-an-item>item 4</q>
 item 4
 </span>
</div>
```

<figure>
<ol>
<li>Flex item containing <samp>block</samp>.</li>
<li>Flex item containing <samp>float</samp>.</li>
<li>(Anonymous, unstyleable) flex item containing <samp>anonymous item
3</samp>.</li>
<li>Flex item containing three blocks in succession:
<ul>
<li>Anonymous block containing <samp>item 4</samp>.</li>
<li><code>&lt;q&gt;</code> element block containing <samp>item
4</samp>.</li>
<li>Anonymous block containing <samp>item 4</samp>.</li>
</ul></li>
</ol>
<figcaption>Flex items determined from above code block</figcaption>
</figure>

Note that the inter-element white space disappears: it does not become
its own flex item, even though the inter-element text *does* get wrapped
in an anonymous flex item.

Note also that the anonymous item's box is unstyleable, since there is
no element to assign style rules to. Its contents will however inherit
styles (such as font settings) from the flex container.

A [flex item](#flex-item)
[establishes an independent formatting
context](https://drafts.csswg.org/css-display-4/#establish-an-independent-formatting-context) for its contents. However, flex items themselves are
[flex-level]
boxes, not block-level boxes: they participate in their container's flex
formatting context, not in a block formatting context.

------------------------------------------------------------------------

 Authors reading this spec may want to [skip past the
following box-generation and static position details](#item-margins).

If the
[computed](https://drafts.csswg.org/css-cascade-5/#computed-value)
[display](https://drafts.csswg.org/css-display-4/#propdef-display) value of an element's nearest
ancestor element (skipping [display:contents] ancestors) is
[flex](#valdef-display-flex) or
[inline-flex](#valdef-display-inline-flex), the element's own
[display] value is
[blockified](https://drafts.csswg.org/css-display-4/#blockify). (See
[CSS2.1§9.7](https://www.w3.org/TR/CSS2/visuren.html#dis-pos-flo)
[\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")
and [CSS Display 3 § 2.7 Automatic Box Type
Transformations](https://drafts.csswg.org/css-display-3/#transformations)
for details on this type of [display] value conversion.)

 Blockification still occurs even when the
[flex](#valdef-display-flex) or
[inline-flex](#valdef-display-inline-flex) element does not end up generating a [flex
container](#flex-container)
box, e.g. when it is
[replaced](https://drafts.csswg.org/css-display-4/#replaced-element) or in a [display:
none](https://drafts.csswg.org/css-display-4/#propdef-display) subtree.

 Some values of
[display](https://drafts.csswg.org/css-display-4/#propdef-display) normally trigger the creation of
anonymous boxes around the original box. If such a box is a [flex
item](#flex-item), it is blockified
first, and so anonymous box creation will not happen. For example, two
contiguous [flex items] with [display:
table-cell] will become two separate
[display: block] [flex
items], instead of being wrapped into a single
anonymous table.

In the case of flex items with [display:
table](https://drafts.csswg.org/css-display-4/#propdef-display), the table wrapper box becomes the [flex
item](#flex-item), so the
[align-self](#propdef-align-self) property applies to it. The contents of
any caption boxes contribute to the calculation of the table wrapper
box's min-content and max-content sizes. However, like
[width](https://drafts.csswg.org/css-sizing-3/#propdef-width) and
[height](https://drafts.csswg.org/css-sizing-3/#propdef-height), the
[flex](#propdef-flex) longhands apply to the table box as follows: the
[flex item]'s final size is calculated by
performing layout as if the distance between the table wrapper box's
edges and the table box's content edges were all part of the table box's
border+padding area, and the table box were the [flex
item].

Tests

- [flexbox-table-fixup-001.xhtml](https://wpt.fyi/results/css/css-flexbox/flexbox-table-fixup-001.xhtml "css/css-flexbox/flexbox-table-fixup-001.xhtml")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-table-fixup-001.xhtml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-table-fixup-001.xhtml)

### 4.1. Absolutely-Positioned Flex Children

As it is
[out-of-flow](https://drafts.csswg.org/css-display-4/#out-of-flow), an absolutely-positioned child of a [flex
container](#flex-container)
does not participate in flex layout.

The [cross-axis](#cross-axis)
edges of the [static-position
rectangle](https://drafts.csswg.org/css-position-3/#static-position-rectangle) of an absolutely-positioned child of a [flex
container](#flex-container)
are the [content
edges](https://drafts.csswg.org/css-box-4/#content-edge) of the [flex container]. The
[main-axis](#main-axis) edges of
the [static-position rectangle] are
where the [margin
edges](https://drafts.csswg.org/css-box-4/#margin-edge) of the child would be positioned if it were the sole
[flex item](#flex-item) in the
[flex container], assuming both the child and
the flex container were fixed-size boxes of their used size. (For this
purpose, the child's [auto] margins are treated as zero.)

Tests

- [abspos-autopos-htb-ltr.html](https://wpt.fyi/results/css/css-flexbox/abspos/abspos-autopos-htb-ltr.html "css/css-flexbox/abspos/abspos-autopos-htb-ltr.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/abspos/abspos-autopos-htb-ltr.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/abspos/abspos-autopos-htb-ltr.html)
- [abspos-autopos-htb-rtl.html](https://wpt.fyi/results/css/css-flexbox/abspos/abspos-autopos-htb-rtl.html "css/css-flexbox/abspos/abspos-autopos-htb-rtl.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/abspos/abspos-autopos-htb-rtl.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/abspos/abspos-autopos-htb-rtl.html)
- [abspos-autopos-vlr-ltr.html](https://wpt.fyi/results/css/css-flexbox/abspos/abspos-autopos-vlr-ltr.html "css/css-flexbox/abspos/abspos-autopos-vlr-ltr.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/abspos/abspos-autopos-vlr-ltr.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/abspos/abspos-autopos-vlr-ltr.html)
- [abspos-autopos-vlr-rtl.html](https://wpt.fyi/results/css/css-flexbox/abspos/abspos-autopos-vlr-rtl.html "css/css-flexbox/abspos/abspos-autopos-vlr-rtl.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/abspos/abspos-autopos-vlr-rtl.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/abspos/abspos-autopos-vlr-rtl.html)
- [abspos-autopos-vrl-ltr.html](https://wpt.fyi/results/css/css-flexbox/abspos/abspos-autopos-vrl-ltr.html "css/css-flexbox/abspos/abspos-autopos-vrl-ltr.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/abspos/abspos-autopos-vrl-ltr.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/abspos/abspos-autopos-vrl-ltr.html)
- [abspos-autopos-vrl-rtl.html](https://wpt.fyi/results/css/css-flexbox/abspos/abspos-autopos-vrl-rtl.html "css/css-flexbox/abspos/abspos-autopos-vrl-rtl.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/abspos/abspos-autopos-vrl-rtl.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/abspos/abspos-autopos-vrl-rtl.html)
- [dynamic-align-self-001.html](https://wpt.fyi/results/css/css-flexbox/abspos/dynamic-align-self-001.html "css/css-flexbox/abspos/dynamic-align-self-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/abspos/dynamic-align-self-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/abspos/dynamic-align-self-001.html)
- [flex-abspos-staticpos-align-self-safe-002.html](https://wpt.fyi/results/css/css-flexbox/abspos/flex-abspos-staticpos-align-self-safe-002.html "css/css-flexbox/abspos/flex-abspos-staticpos-align-self-safe-002.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/abspos/flex-abspos-staticpos-align-self-safe-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/abspos/flex-abspos-staticpos-align-self-safe-002.html)
- [flex-abspos-staticpos-align-self-safe-003.html](https://wpt.fyi/results/css/css-flexbox/abspos/flex-abspos-staticpos-align-self-safe-003.html "css/css-flexbox/abspos/flex-abspos-staticpos-align-self-safe-003.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/abspos/flex-abspos-staticpos-align-self-safe-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/abspos/flex-abspos-staticpos-align-self-safe-003.html)
- [abspos-descendent-001.html](https://wpt.fyi/results/css/css-flexbox/abspos/abspos-descendent-001.html "css/css-flexbox/abspos/abspos-descendent-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/abspos/abspos-descendent-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/abspos/abspos-descendent-001.html)
- [flex-abspos-staticpos-align-content-001.html](https://wpt.fyi/results/css/css-flexbox/abspos/flex-abspos-staticpos-align-content-001.html "css/css-flexbox/abspos/flex-abspos-staticpos-align-content-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/abspos/flex-abspos-staticpos-align-content-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/abspos/flex-abspos-staticpos-align-content-001.html)
- [flex-abspos-staticpos-align-self-001.html](https://wpt.fyi/results/css/css-flexbox/abspos/flex-abspos-staticpos-align-self-001.html "css/css-flexbox/abspos/flex-abspos-staticpos-align-self-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/abspos/flex-abspos-staticpos-align-self-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/abspos/flex-abspos-staticpos-align-self-001.html)
- [flex-abspos-staticpos-align-self-002.html](https://wpt.fyi/results/css/css-flexbox/abspos/flex-abspos-staticpos-align-self-002.html "css/css-flexbox/abspos/flex-abspos-staticpos-align-self-002.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/abspos/flex-abspos-staticpos-align-self-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/abspos/flex-abspos-staticpos-align-self-002.html)
- [flex-abspos-staticpos-align-self-003.html](https://wpt.fyi/results/css/css-flexbox/abspos/flex-abspos-staticpos-align-self-003.html "css/css-flexbox/abspos/flex-abspos-staticpos-align-self-003.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/abspos/flex-abspos-staticpos-align-self-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/abspos/flex-abspos-staticpos-align-self-003.html)
- [flex-abspos-staticpos-align-self-004.html](https://wpt.fyi/results/css/css-flexbox/abspos/flex-abspos-staticpos-align-self-004.html "css/css-flexbox/abspos/flex-abspos-staticpos-align-self-004.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/abspos/flex-abspos-staticpos-align-self-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/abspos/flex-abspos-staticpos-align-self-004.html)
- [flex-abspos-staticpos-align-self-005.html](https://wpt.fyi/results/css/css-flexbox/abspos/flex-abspos-staticpos-align-self-005.html "css/css-flexbox/abspos/flex-abspos-staticpos-align-self-005.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/abspos/flex-abspos-staticpos-align-self-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/abspos/flex-abspos-staticpos-align-self-005.html)
- [flex-abspos-staticpos-align-self-006.html](https://wpt.fyi/results/css/css-flexbox/abspos/flex-abspos-staticpos-align-self-006.html "css/css-flexbox/abspos/flex-abspos-staticpos-align-self-006.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/abspos/flex-abspos-staticpos-align-self-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/abspos/flex-abspos-staticpos-align-self-006.html)
- [flex-abspos-staticpos-align-self-007.html](https://wpt.fyi/results/css/css-flexbox/abspos/flex-abspos-staticpos-align-self-007.html "css/css-flexbox/abspos/flex-abspos-staticpos-align-self-007.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/abspos/flex-abspos-staticpos-align-self-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/abspos/flex-abspos-staticpos-align-self-007.html)
- [flex-abspos-staticpos-align-self-008.html](https://wpt.fyi/results/css/css-flexbox/abspos/flex-abspos-staticpos-align-self-008.html "css/css-flexbox/abspos/flex-abspos-staticpos-align-self-008.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/abspos/flex-abspos-staticpos-align-self-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/abspos/flex-abspos-staticpos-align-self-008.html)
- [flex-abspos-staticpos-align-self-rtl-001.html](https://wpt.fyi/results/css/css-flexbox/abspos/flex-abspos-staticpos-align-self-rtl-001.html "css/css-flexbox/abspos/flex-abspos-staticpos-align-self-rtl-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/abspos/flex-abspos-staticpos-align-self-rtl-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/abspos/flex-abspos-staticpos-align-self-rtl-001.html)
- [flex-abspos-staticpos-align-self-rtl-002.html](https://wpt.fyi/results/css/css-flexbox/abspos/flex-abspos-staticpos-align-self-rtl-002.html "css/css-flexbox/abspos/flex-abspos-staticpos-align-self-rtl-002.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/abspos/flex-abspos-staticpos-align-self-rtl-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/abspos/flex-abspos-staticpos-align-self-rtl-002.html)
- [flex-abspos-staticpos-align-self-rtl-003.html](https://wpt.fyi/results/css/css-flexbox/abspos/flex-abspos-staticpos-align-self-rtl-003.html "css/css-flexbox/abspos/flex-abspos-staticpos-align-self-rtl-003.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/abspos/flex-abspos-staticpos-align-self-rtl-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/abspos/flex-abspos-staticpos-align-self-rtl-003.html)
- [flex-abspos-staticpos-align-self-rtl-004.html](https://wpt.fyi/results/css/css-flexbox/abspos/flex-abspos-staticpos-align-self-rtl-004.html "css/css-flexbox/abspos/flex-abspos-staticpos-align-self-rtl-004.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/abspos/flex-abspos-staticpos-align-self-rtl-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/abspos/flex-abspos-staticpos-align-self-rtl-004.html)
- [flex-abspos-staticpos-align-self-safe-001.html](https://wpt.fyi/results/css/css-flexbox/abspos/flex-abspos-staticpos-align-self-safe-001.html "css/css-flexbox/abspos/flex-abspos-staticpos-align-self-safe-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/abspos/flex-abspos-staticpos-align-self-safe-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/abspos/flex-abspos-staticpos-align-self-safe-001.html)
- [flex-abspos-staticpos-align-self-vertWM-001.html](https://wpt.fyi/results/css/css-flexbox/abspos/flex-abspos-staticpos-align-self-vertWM-001.html "css/css-flexbox/abspos/flex-abspos-staticpos-align-self-vertWM-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/abspos/flex-abspos-staticpos-align-self-vertWM-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/abspos/flex-abspos-staticpos-align-self-vertWM-001.html)
- [flex-abspos-staticpos-align-self-vertWM-002.html](https://wpt.fyi/results/css/css-flexbox/abspos/flex-abspos-staticpos-align-self-vertWM-002.html "css/css-flexbox/abspos/flex-abspos-staticpos-align-self-vertWM-002.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/abspos/flex-abspos-staticpos-align-self-vertWM-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/abspos/flex-abspos-staticpos-align-self-vertWM-002.html)
- [flex-abspos-staticpos-align-self-vertWM-003.html](https://wpt.fyi/results/css/css-flexbox/abspos/flex-abspos-staticpos-align-self-vertWM-003.html "css/css-flexbox/abspos/flex-abspos-staticpos-align-self-vertWM-003.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/abspos/flex-abspos-staticpos-align-self-vertWM-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/abspos/flex-abspos-staticpos-align-self-vertWM-003.html)
- [flex-abspos-staticpos-align-self-vertWM-004.html](https://wpt.fyi/results/css/css-flexbox/abspos/flex-abspos-staticpos-align-self-vertWM-004.html "css/css-flexbox/abspos/flex-abspos-staticpos-align-self-vertWM-004.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/abspos/flex-abspos-staticpos-align-self-vertWM-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/abspos/flex-abspos-staticpos-align-self-vertWM-004.html)
- [flex-abspos-staticpos-fallback-justify-content-001.html](https://wpt.fyi/results/css/css-flexbox/abspos/flex-abspos-staticpos-fallback-justify-content-001.html "css/css-flexbox/abspos/flex-abspos-staticpos-fallback-justify-content-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/abspos/flex-abspos-staticpos-fallback-justify-content-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/abspos/flex-abspos-staticpos-fallback-justify-content-001.html)
- [flex-abspos-staticpos-justify-content-001.html](https://wpt.fyi/results/css/css-flexbox/abspos/flex-abspos-staticpos-justify-content-001.html "css/css-flexbox/abspos/flex-abspos-staticpos-justify-content-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/abspos/flex-abspos-staticpos-justify-content-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/abspos/flex-abspos-staticpos-justify-content-001.html)
- [flex-abspos-staticpos-justify-content-002.html](https://wpt.fyi/results/css/css-flexbox/abspos/flex-abspos-staticpos-justify-content-002.html "css/css-flexbox/abspos/flex-abspos-staticpos-justify-content-002.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/abspos/flex-abspos-staticpos-justify-content-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/abspos/flex-abspos-staticpos-justify-content-002.html)
- [flex-abspos-staticpos-justify-content-003.html](https://wpt.fyi/results/css/css-flexbox/abspos/flex-abspos-staticpos-justify-content-003.html "css/css-flexbox/abspos/flex-abspos-staticpos-justify-content-003.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/abspos/flex-abspos-staticpos-justify-content-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/abspos/flex-abspos-staticpos-justify-content-003.html)
- [flex-abspos-staticpos-justify-content-004.html](https://wpt.fyi/results/css/css-flexbox/abspos/flex-abspos-staticpos-justify-content-004.html "css/css-flexbox/abspos/flex-abspos-staticpos-justify-content-004.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/abspos/flex-abspos-staticpos-justify-content-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/abspos/flex-abspos-staticpos-justify-content-004.html)
- [flex-abspos-staticpos-justify-content-005.html](https://wpt.fyi/results/css/css-flexbox/abspos/flex-abspos-staticpos-justify-content-005.html "css/css-flexbox/abspos/flex-abspos-staticpos-justify-content-005.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/abspos/flex-abspos-staticpos-justify-content-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/abspos/flex-abspos-staticpos-justify-content-005.html)
- [flex-abspos-staticpos-justify-content-006.html](https://wpt.fyi/results/css/css-flexbox/abspos/flex-abspos-staticpos-justify-content-006.html "css/css-flexbox/abspos/flex-abspos-staticpos-justify-content-006.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/abspos/flex-abspos-staticpos-justify-content-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/abspos/flex-abspos-staticpos-justify-content-006.html)
- [flex-abspos-staticpos-justify-content-007.html](https://wpt.fyi/results/css/css-flexbox/abspos/flex-abspos-staticpos-justify-content-007.html "css/css-flexbox/abspos/flex-abspos-staticpos-justify-content-007.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/abspos/flex-abspos-staticpos-justify-content-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/abspos/flex-abspos-staticpos-justify-content-007.html)
- [flex-abspos-staticpos-justify-content-008.html](https://wpt.fyi/results/css/css-flexbox/abspos/flex-abspos-staticpos-justify-content-008.html "css/css-flexbox/abspos/flex-abspos-staticpos-justify-content-008.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/abspos/flex-abspos-staticpos-justify-content-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/abspos/flex-abspos-staticpos-justify-content-008.html)
- [flex-abspos-staticpos-justify-content-rtl-001.html](https://wpt.fyi/results/css/css-flexbox/abspos/flex-abspos-staticpos-justify-content-rtl-001.html "css/css-flexbox/abspos/flex-abspos-staticpos-justify-content-rtl-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/abspos/flex-abspos-staticpos-justify-content-rtl-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/abspos/flex-abspos-staticpos-justify-content-rtl-001.html)
- [flex-abspos-staticpos-justify-content-rtl-002.html](https://wpt.fyi/results/css/css-flexbox/abspos/flex-abspos-staticpos-justify-content-rtl-002.html "css/css-flexbox/abspos/flex-abspos-staticpos-justify-content-rtl-002.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/abspos/flex-abspos-staticpos-justify-content-rtl-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/abspos/flex-abspos-staticpos-justify-content-rtl-002.html)
- [flex-abspos-staticpos-justify-content-vertWM-001.html](https://wpt.fyi/results/css/css-flexbox/abspos/flex-abspos-staticpos-justify-content-vertWM-001.html "css/css-flexbox/abspos/flex-abspos-staticpos-justify-content-vertWM-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/abspos/flex-abspos-staticpos-justify-content-vertWM-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/abspos/flex-abspos-staticpos-justify-content-vertWM-001.html)
- [flex-abspos-staticpos-justify-content-vertWM-002.html](https://wpt.fyi/results/css/css-flexbox/abspos/flex-abspos-staticpos-justify-content-vertWM-002.html "css/css-flexbox/abspos/flex-abspos-staticpos-justify-content-vertWM-002.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/abspos/flex-abspos-staticpos-justify-content-vertWM-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/abspos/flex-abspos-staticpos-justify-content-vertWM-002.html)
- [flex-abspos-staticpos-justify-self-001.html](https://wpt.fyi/results/css/css-flexbox/abspos/flex-abspos-staticpos-justify-self-001.html "css/css-flexbox/abspos/flex-abspos-staticpos-justify-self-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/abspos/flex-abspos-staticpos-justify-self-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/abspos/flex-abspos-staticpos-justify-self-001.html)
- [flex-abspos-staticpos-margin-001.html](https://wpt.fyi/results/css/css-flexbox/abspos/flex-abspos-staticpos-margin-001.html "css/css-flexbox/abspos/flex-abspos-staticpos-margin-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/abspos/flex-abspos-staticpos-margin-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/abspos/flex-abspos-staticpos-margin-001.html)
- [flex-abspos-staticpos-margin-002.html](https://wpt.fyi/results/css/css-flexbox/abspos/flex-abspos-staticpos-margin-002.html "css/css-flexbox/abspos/flex-abspos-staticpos-margin-002.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/abspos/flex-abspos-staticpos-margin-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/abspos/flex-abspos-staticpos-margin-002.html)
- [flex-abspos-staticpos-margin-003.html](https://wpt.fyi/results/css/css-flexbox/abspos/flex-abspos-staticpos-margin-003.html "css/css-flexbox/abspos/flex-abspos-staticpos-margin-003.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/abspos/flex-abspos-staticpos-margin-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/abspos/flex-abspos-staticpos-margin-003.html)
- [flexbox_absolute-atomic.html](https://wpt.fyi/results/css/css-flexbox/abspos/flexbox_absolute-atomic.html "css/css-flexbox/abspos/flexbox_absolute-atomic.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/abspos/flexbox_absolute-atomic.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/abspos/flexbox_absolute-atomic.html)
- [flexbox-abspos-child-001a.html](https://wpt.fyi/results/css/css-flexbox/abspos/flexbox-abspos-child-001a.html "css/css-flexbox/abspos/flexbox-abspos-child-001a.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/abspos/flexbox-abspos-child-001a.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/abspos/flexbox-abspos-child-001a.html)
- [flexbox-abspos-child-001b.html](https://wpt.fyi/results/css/css-flexbox/abspos/flexbox-abspos-child-001b.html "css/css-flexbox/abspos/flexbox-abspos-child-001b.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/abspos/flexbox-abspos-child-001b.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/abspos/flexbox-abspos-child-001b.html)
- [flexbox-abspos-child-002.html](https://wpt.fyi/results/css/css-flexbox/abspos/flexbox-abspos-child-002.html "css/css-flexbox/abspos/flexbox-abspos-child-002.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/abspos/flexbox-abspos-child-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/abspos/flexbox-abspos-child-002.html)
- [flexbox_inline-abspos.html](https://wpt.fyi/results/css/css-flexbox/abspos/flexbox_inline-abspos.html "css/css-flexbox/abspos/flexbox_inline-abspos.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/abspos/flexbox_inline-abspos.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/abspos/flexbox_inline-abspos.html)
- [position-absolute-001.html](https://wpt.fyi/results/css/css-flexbox/abspos/position-absolute-001.html "css/css-flexbox/abspos/position-absolute-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/abspos/position-absolute-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/abspos/position-absolute-001.html)
- [position-absolute-002.html](https://wpt.fyi/results/css/css-flexbox/abspos/position-absolute-002.html "css/css-flexbox/abspos/position-absolute-002.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/abspos/position-absolute-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/abspos/position-absolute-002.html)
- [position-absolute-003.html](https://wpt.fyi/results/css/css-flexbox/abspos/position-absolute-003.html "css/css-flexbox/abspos/position-absolute-003.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/abspos/position-absolute-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/abspos/position-absolute-003.html)
- [position-absolute-004.html](https://wpt.fyi/results/css/css-flexbox/abspos/position-absolute-004.html "css/css-flexbox/abspos/position-absolute-004.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/abspos/position-absolute-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/abspos/position-absolute-004.html)
- [position-absolute-005.html](https://wpt.fyi/results/css/css-flexbox/abspos/position-absolute-005.html "css/css-flexbox/abspos/position-absolute-005.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/abspos/position-absolute-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/abspos/position-absolute-005.html)
- [position-absolute-006.html](https://wpt.fyi/results/css/css-flexbox/abspos/position-absolute-006.html "css/css-flexbox/abspos/position-absolute-006.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/abspos/position-absolute-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/abspos/position-absolute-006.html)
- [position-absolute-007.html](https://wpt.fyi/results/css/css-flexbox/abspos/position-absolute-007.html "css/css-flexbox/abspos/position-absolute-007.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/abspos/position-absolute-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/abspos/position-absolute-007.html)
- [position-absolute-008.html](https://wpt.fyi/results/css/css-flexbox/abspos/position-absolute-008.html "css/css-flexbox/abspos/position-absolute-008.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/abspos/position-absolute-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/abspos/position-absolute-008.html)
- [position-absolute-009.html](https://wpt.fyi/results/css/css-flexbox/abspos/position-absolute-009.html "css/css-flexbox/abspos/position-absolute-009.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/abspos/position-absolute-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/abspos/position-absolute-009.html)
- [position-absolute-010.html](https://wpt.fyi/results/css/css-flexbox/abspos/position-absolute-010.html "css/css-flexbox/abspos/position-absolute-010.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/abspos/position-absolute-010.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/abspos/position-absolute-010.html)
- [position-absolute-011.html](https://wpt.fyi/results/css/css-flexbox/abspos/position-absolute-011.html "css/css-flexbox/abspos/position-absolute-011.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/abspos/position-absolute-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/abspos/position-absolute-011.html)
- [position-absolute-012.html](https://wpt.fyi/results/css/css-flexbox/abspos/position-absolute-012.html "css/css-flexbox/abspos/position-absolute-012.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/abspos/position-absolute-012.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/abspos/position-absolute-012.html)
- [position-absolute-013.html](https://wpt.fyi/results/css/css-flexbox/abspos/position-absolute-013.html "css/css-flexbox/abspos/position-absolute-013.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/abspos/position-absolute-013.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/abspos/position-absolute-013.html)
- [position-absolute-014.html](https://wpt.fyi/results/css/css-flexbox/abspos/position-absolute-014.html "css/css-flexbox/abspos/position-absolute-014.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/abspos/position-absolute-014.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/abspos/position-absolute-014.html)
- [position-absolute-015.html](https://wpt.fyi/results/css/css-flexbox/abspos/position-absolute-015.html "css/css-flexbox/abspos/position-absolute-015.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/abspos/position-absolute-015.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/abspos/position-absolute-015.html)
- [position-absolute-containing-block-001.html](https://wpt.fyi/results/css/css-flexbox/abspos/position-absolute-containing-block-001.html "css/css-flexbox/abspos/position-absolute-containing-block-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/abspos/position-absolute-containing-block-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/abspos/position-absolute-containing-block-001.html)
- [position-absolute-containing-block-002.html](https://wpt.fyi/results/css/css-flexbox/abspos/position-absolute-containing-block-002.html "css/css-flexbox/abspos/position-absolute-containing-block-002.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/abspos/position-absolute-containing-block-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/abspos/position-absolute-containing-block-002.html)
- [flex-content-alignment-with-abspos-001.html](https://wpt.fyi/results/css/css-flexbox/alignment/flex-content-alignment-with-abspos-001.html "css/css-flexbox/alignment/flex-content-alignment-with-abspos-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/alignment/flex-content-alignment-with-abspos-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/alignment/flex-content-alignment-with-abspos-001.html)
- [dynamic-grid-flex-abspos.html](https://wpt.fyi/results/css/css-flexbox/dynamic-grid-flex-abspos.html "css/css-flexbox/dynamic-grid-flex-abspos.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/dynamic-grid-flex-abspos.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/dynamic-grid-flex-abspos.html)
- [flexbox_stf-abspos.html](https://wpt.fyi/results/css/css-flexbox/flexbox_stf-abspos.html "css/css-flexbox/flexbox_stf-abspos.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_stf-abspos.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_stf-abspos.html)
- [flex-item-position-relative-001.html](https://wpt.fyi/results/css/css-flexbox/flex-item-position-relative-001.html "css/css-flexbox/flex-item-position-relative-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-item-position-relative-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-item-position-relative-001.html)

The effect of this is that if you set,
for example, [align-self:
center;](#propdef-align-self) on an absolutely-positioned child of a [flex
container](#flex-container),
auto offsets on the child will center it in the [flex
container's] [cross
axis](#cross-axis).

### 4.2. Flex Item Margins and Paddings

The margins of adjacent [flex items](#flex-item) do not
[collapse](https://www.w3.org/TR/CSS2/box.html#collapsing-margins).

Percentage margins and paddings on [flex
items](#flex-item), like those on
[block
boxes](https://drafts.csswg.org/css-display-4/#block-box), are resolved against the [inline
size](https://drafts.csswg.org/css-sizing-3/#inline-size) of their [containing
block](https://drafts.csswg.org/css-display-4/#containing-block), e.g. left/right/top/bottom percentages all resolve
against their [containing block]'s *width*
in horizontal [writing
modes](https://drafts.csswg.org/css-writing-modes-4/#writing-mode).

Auto margins expand to absorb extra space in the corresponding
dimension. They can be used for alignment, or to push adjacent flex
items apart. See [Aligning with [auto] margins](#auto-margins).

Tests

- [empty-flex-box-and-margin-collapsing.html](https://wpt.fyi/results/css/css-flexbox/empty-flex-box-and-margin-collapsing.html "css/css-flexbox/empty-flex-box-and-margin-collapsing.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/empty-flex-box-and-margin-collapsing.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/empty-flex-box-and-margin-collapsing.html)
- [flex-container-margin.html](https://wpt.fyi/results/css/css-flexbox/flex-container-margin.html "css/css-flexbox/flex-container-margin.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-container-margin.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-container-margin.html)
- [flexitem-no-margin-collapsing.html](https://wpt.fyi/results/css/css-flexbox/flexitem-no-margin-collapsing.html "css/css-flexbox/flexitem-no-margin-collapsing.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexitem-no-margin-collapsing.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexitem-no-margin-collapsing.html)
- [flex-margin-no-collapse.html](https://wpt.fyi/results/css/css-flexbox/flex-margin-no-collapse.html "css/css-flexbox/flex-margin-no-collapse.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-margin-no-collapse.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-margin-no-collapse.html)
- [negative-margins-001.html](https://wpt.fyi/results/css/css-flexbox/negative-margins-001.html "css/css-flexbox/negative-margins-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/negative-margins-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/negative-margins-001.html)

### 4.3. Flex Item Z-Ordering

[Flex items](#flex-item) paint
exactly the same as inline blocks
[\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification"),
except that
[order](https://drafts.csswg.org/css-display-4/#propdef-order)-modified document order is used in
place of raw document order, and
[z-index](https://drafts.csswg.org/css2/#propdef-z-index) values other than
[auto](https://drafts.csswg.org/css2/#valdef-z-index-auto) create a stacking context even if
[position](https://drafts.csswg.org/css-position-3/#propdef-position) is
[static](https://drafts.csswg.org/css-position-3/#valdef-position-static) (behaving exactly as if
[position] were
[relative](https://drafts.csswg.org/css-position-3/#valdef-position-relative)).

 Descendants that are positioned outside a flex item
still participate in any stacking context established by the flex item.

Tests

- [flexbox-paint-ordering-001.xhtml](https://wpt.fyi/results/css/css-flexbox/flexbox-paint-ordering-001.xhtml "css/css-flexbox/flexbox-paint-ordering-001.xhtml")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-paint-ordering-001.xhtml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-paint-ordering-001.xhtml)
- [flexbox-paint-ordering-002.xhtml](https://wpt.fyi/results/css/css-flexbox/flexbox-paint-ordering-002.xhtml "css/css-flexbox/flexbox-paint-ordering-002.xhtml")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-paint-ordering-002.xhtml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-paint-ordering-002.xhtml)
- [flexbox-paint-ordering-003.html](https://wpt.fyi/results/css/css-flexbox/flexbox-paint-ordering-003.html "css/css-flexbox/flexbox-paint-ordering-003.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-paint-ordering-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-paint-ordering-003.html)
- [flex-item-z-ordering-001.html](https://wpt.fyi/results/css/css-flexbox/flex-item-z-ordering-001.html "css/css-flexbox/flex-item-z-ordering-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-item-z-ordering-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-item-z-ordering-001.html)
- [flex-item-z-ordering-002.html](https://wpt.fyi/results/css/css-flexbox/flex-item-z-ordering-002.html "css/css-flexbox/flex-item-z-ordering-002.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-item-z-ordering-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-item-z-ordering-002.html)
- [flexbox-items-as-stacking-contexts-001.xhtml](https://wpt.fyi/results/css/css-flexbox/flexbox-items-as-stacking-contexts-001.xhtml "css/css-flexbox/flexbox-items-as-stacking-contexts-001.xhtml")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-items-as-stacking-contexts-001.xhtml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-items-as-stacking-contexts-001.xhtml)
- [flexbox-items-as-stacking-contexts-002.html](https://wpt.fyi/results/css/css-flexbox/flexbox-items-as-stacking-contexts-002.html "css/css-flexbox/flexbox-items-as-stacking-contexts-002.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-items-as-stacking-contexts-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-items-as-stacking-contexts-002.html)
- [flexbox-items-as-stacking-contexts-003.html](https://wpt.fyi/results/css/css-flexbox/flexbox-items-as-stacking-contexts-003.html "css/css-flexbox/flexbox-items-as-stacking-contexts-003.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-items-as-stacking-contexts-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-items-as-stacking-contexts-003.html)
- [hittest-overlapping-margin.html](https://wpt.fyi/results/css/css-flexbox/hittest-overlapping-margin.html "css/css-flexbox/hittest-overlapping-margin.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/hittest-overlapping-margin.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/hittest-overlapping-margin.html)
- [hittest-overlapping-order.html](https://wpt.fyi/results/css/css-flexbox/hittest-overlapping-order.html "css/css-flexbox/hittest-overlapping-order.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/hittest-overlapping-order.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/hittest-overlapping-order.html)
- [hittest-overlapping-relative.html](https://wpt.fyi/results/css/css-flexbox/hittest-overlapping-relative.html "css/css-flexbox/hittest-overlapping-relative.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/hittest-overlapping-relative.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/hittest-overlapping-relative.html)

### 4.4. Collapsed Items

Specifying [visibility:collapse] on a flex item causes it to
become a [collapsed flex item], producing an effect
similar to [visibility:collapse] on a table-row or table-column:
the [collapsed flex
item](#collapsed-flex-item) is removed from rendering entirely, but leaves behind a
\"strut\" that keeps the flex line's cross-size stable. Thus, if a flex
container has only one flex line, dynamically collapsing or uncollapsing
items may change the [flex
container](#flex-container)'s
[main size](#main-size), but is
guaranteed to have no effect on its [cross
size](#cross-size) and won't cause
the rest of the page's layout to \"wobble\". Flex line wrapping *is*
re-done after collapsing, however, so the cross size of a flex container
with multiple lines might or might not change.

Though [collapsed flex
items](#collapsed-flex-item) aren't rendered, they do appear in the [formatting
structure](https://www.w3.org/TR/CSS2/intro.html#formatting-structure).
Therefore, unlike on [display:none] items
[\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification"),
effects that depend on a box appearing in the formatting structure (like
incrementing counters or running animations and transitions) still
operate on collapsed items.

Tests

- [flexbox_visibility-collapse.html](https://wpt.fyi/results/css/css-flexbox/flexbox_visibility-collapse.html "css/css-flexbox/flexbox_visibility-collapse.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_visibility-collapse.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_visibility-collapse.html)
- [flexbox_visibility-collapse-line-wrapping.html](https://wpt.fyi/results/css/css-flexbox/flexbox_visibility-collapse-line-wrapping.html "css/css-flexbox/flexbox_visibility-collapse-line-wrapping.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_visibility-collapse-line-wrapping.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_visibility-collapse-line-wrapping.html)

In the following example, a sidebar is
sized to fit its content. [visibility:
collapse](https://drafts.csswg.org/css-display-4/#propdef-visibility) is used to dynamically hide parts of a
navigation sidebar without affecting its width, even though the widest
item ("Architecture") is in a collapsed section.

<figure>
<div id="visibility-collapse-example">
<ul>
<li><span id="nav-about"><a href="#nav-about">About</a></span>
<ul>
<li><a href="#">History</a></li>
<li><a href="#">Mission</a></li>
<li><a href="#">People</a></li>
</ul></li>
<li><span id="nav-projects"><a href="#nav-projects">Projects</a></span>
<ul>
<li><a href="#">Art</a></li>
<li><a href="#">Architecture</a></li>
<li><a href="#">Music</a></li>
</ul></li>
<li><span id="nav-interact"><a href="#nav-interact">Interact</a></span>
<ul>
<li><a href="#">Blog</a></li>
<li><a href="#">Forums</a></li>
</ul></li>
</ul>
Hover over the menu to the left: each section expands to show its
sub-items. In order to keep the sidebar width (and this main area width)
stable, <a
href="https://drafts.csswg.org/css-display-4/#propdef-visibility"
id="ref-for-propdef-visibility①" class="css"
data->visibility: collapse</a> is used instead of <a
href="https://drafts.csswg.org/css-display-4/#propdef-display"
id="ref-for-propdef-display①④" class="css"
data->display: none</a>. This results in a sidebar
that is always wide enough for the word “Architecture”, even though it
is not always visible.
</div>
<figcaption>Sample live rendering for example code below</figcaption>
</figure>

```
@media (min-width: 60em) {
 /* two column layout only when enough room (relative to default text size) */
 div { display: flex; }
 #main {
 flex: 1; /* Main takes up all remaining space */
 order: 1; /* Place it after (to the right of) the navigation */
 min-width: 12em; /* Optimize main content area sizing */
 }
}
/* menu items use flex layout so that visibility:collapse will work */
nav > ul > li {
 display: flex;
 flex-flow: column;
}
/* dynamically collapse submenus when not targeted */
nav > ul > li:not(:target):not(:hover) > ul {
 visibility: collapse;
}
```

```
<div>
 <article id="main">
 Interesting Stuff to Read
 </article>
 <nav>
 <ul>
 <li id="nav-about"><a href="#nav-about">About</a>
 …
 <li id="nav-projects"><a href="#nav-projects">Projects</a>
 <ul>
 <li><a href="…">Art</a>
 <li><a href="…">Architecture</a>
 <li><a href="…">Music</a>
 </ul>
 <li id="nav-interact"><a href="#nav-interact">Interact</a>
 …
 </ul>
 </nav>
</div>
<footer>
…
```

To compute the size of the strut, flex layout is first performed with
all items uncollapsed, and then re-run with each [collapsed flex
item](#collapsed-flex-item) replaced by a strut that maintains the original [cross
size](#cross-size) of the item's
original line. See the [Flex Layout Algorithm](#layout-algorithm) for
the normative definition of how [visibility:collapse] interacts
with flex layout.

 Using [visibility:collapse] on any flex items
will cause the flex layout algorithm to repeat partway through,
re-running the most expensive steps. It's recommended that authors
continue to use [display:none] to hide items if the items will not
be dynamically collapsed and uncollapsed, as that is more efficient for
the layout engine. (Since only part of the steps need to be repeated
when
[visibility](https://drafts.csswg.org/css-display-4/#propdef-visibility) is changed, however, \'visibility:
collapse\' is still recommended for dynamic cases.)

### 4.5. Automatic Minimum Size of Flex Items

 The
[auto](https://drafts.csswg.org/css-sizing-3/#valdef-width-auto) keyword, representing an [automatic minimum
size](https://drafts.csswg.org/css-sizing-3/#automatic-minimum-size), is the new initial value of the
[min-width](https://drafts.csswg.org/css2/#propdef-min-width) and
[min-height](https://drafts.csswg.org/css2/#propdef-min-height) properties. The keyword was
previously defined in this specification, but is now defined in the [CSS
Sizing](#biblio-css-sizing-3 "CSS Box Sizing Module Level 3")
module.

To provide a more reasonable default [minimum
size](https://drafts.csswg.org/css-sizing-3/#min-width) for [flex items](#flex-item), the used value of a [main
axis](#main-axis) [automatic
minimum
size](https://drafts.csswg.org/css-sizing-3/#automatic-minimum-size) on a [flex item] whose
[computed](https://drafts.csswg.org/css-cascade-5/#computed-value)
[overflow](https://drafts.csswg.org/css-overflow-3/#propdef-overflow) value is
[non-scrollable](https://drafts.csswg.org/css-overflow-3/#non-scrollable-overflow-value) is its [content-based minimum
size](#content-based-minimum-size); for [main-axis scroll
containers](https://drafts.csswg.org/css-overflow-3/#block-axis-scroll-container) the [automatic minimum
size] is zero, as usual.

The [content-based minimum size] of a [flex
item](#flex-item) differs
depending on whether the [flex item] is
[replaced](https://drafts.csswg.org/css-display-4/#replaced-element) or not:

For [replaced elements](https://drafts.csswg.org/css-display-4/#replaced-element)

: Use the smaller of the [content size
 suggestion](#content-size-suggestion) and the [transferred size
 suggestion](#transferred-size-suggestion) (if one exists), capped by the [specified size
 suggestion](#specified-size-suggestion) (if one exists).

For [non-replaced elements](https://drafts.csswg.org/css-display-4/#non-replaced)

: Use the larger of the [content size
 suggestion](#content-size-suggestion) and the [transferred size
 suggestion](#transferred-size-suggestion) (if one exists), capped by the [specified size
 suggestion](#specified-size-suggestion) (if one exists).

In either case, the size is clamped by the
[maximum](https://drafts.csswg.org/css-sizing-3/#max-width) [main size](#main-size) if it's [definite](#definite).

Tests

- [image-items-flake-001.html](https://wpt.fyi/results/css/css-flexbox/image-items-flake-001.html "css/css-flexbox/image-items-flake-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/image-items-flake-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/image-items-flake-001.html)

The [content size
suggestion](#content-size-suggestion), [specified size
suggestion](#specified-size-suggestion), and [transferred size
suggestion](#transferred-size-suggestion) used in this calculation account for the relevant
min/max/preferred size properties so that the [content-based minimum
size](#content-based-minimum-size) does not interfere with any author-provided
constraints, and are defined below:

[specified size suggestion]
: If the item's
 [preferred](https://drafts.csswg.org/css-sizing-3/#preferred-size) [main size](#main-size) is [definite](#definite) and not
 [automatic](https://drafts.csswg.org/css-sizing-3/#automatic-size), then the [specified size
 suggestion](#specified-size-suggestion) is that size. It is otherwise undefined.

[transferred size suggestion]
: If the item has a [preferred aspect
 ratio](https://drafts.csswg.org/css-sizing-4/#preferred-aspect-ratio) and its
 [preferred](https://drafts.csswg.org/css-sizing-3/#preferred-size) [cross size](#cross-size) is [definite](#definite), then the [transferred size
 suggestion](#transferred-size-suggestion) is that size (clamped by its
 [minimum](https://drafts.csswg.org/css-sizing-3/#min-width) and
 [maximum](https://drafts.csswg.org/css-sizing-3/#max-width) [cross sizes] if they are
 [definite]), converted through the aspect ratio.
 It is otherwise undefined.

[content size suggestion]
: The [content size
 suggestion](#content-size-suggestion) is the [min-content
 size](https://drafts.csswg.org/css-sizing-3/#min-content) in the [main axis](#main-axis), clamped, if it has a [preferred aspect
 ratio](https://drafts.csswg.org/css-sizing-4/#preferred-aspect-ratio), by any [definite](#definite)
 [minimum](https://drafts.csswg.org/css-sizing-3/#min-width) and
 [maximum](https://drafts.csswg.org/css-sizing-3/#max-width) [cross sizes](#cross-size) converted through the aspect ratio.

Tests

- [content-height-with-scrollbars.html](https://wpt.fyi/results/css/css-flexbox/content-height-with-scrollbars.html "css/css-flexbox/content-height-with-scrollbars.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/content-height-with-scrollbars.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/content-height-with-scrollbars.html)
- [fieldset-as-item-dynamic.html](https://wpt.fyi/results/css/css-flexbox/fieldset-as-item-dynamic.html "css/css-flexbox/fieldset-as-item-dynamic.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/fieldset-as-item-dynamic.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/fieldset-as-item-dynamic.html)
- [fieldset-as-item-overflow.html](https://wpt.fyi/results/css/css-flexbox/fieldset-as-item-overflow.html "css/css-flexbox/fieldset-as-item-overflow.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/fieldset-as-item-overflow.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/fieldset-as-item-overflow.html)
- [flex-aspect-ratio-img-column-001.html](https://wpt.fyi/results/css/css-flexbox/flex-aspect-ratio-img-column-001.html "css/css-flexbox/flex-aspect-ratio-img-column-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-aspect-ratio-img-column-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-aspect-ratio-img-column-001.html)
- [flex-aspect-ratio-img-column-002.html](https://wpt.fyi/results/css/css-flexbox/flex-aspect-ratio-img-column-002.html "css/css-flexbox/flex-aspect-ratio-img-column-002.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-aspect-ratio-img-column-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-aspect-ratio-img-column-002.html)
- [flex-aspect-ratio-img-column-003.html](https://wpt.fyi/results/css/css-flexbox/flex-aspect-ratio-img-column-003.html "css/css-flexbox/flex-aspect-ratio-img-column-003.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-aspect-ratio-img-column-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-aspect-ratio-img-column-003.html)
- [flex-aspect-ratio-img-column-004.html](https://wpt.fyi/results/css/css-flexbox/flex-aspect-ratio-img-column-004.html "css/css-flexbox/flex-aspect-ratio-img-column-004.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-aspect-ratio-img-column-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-aspect-ratio-img-column-004.html)
- [flex-aspect-ratio-img-column-005.html](https://wpt.fyi/results/css/css-flexbox/flex-aspect-ratio-img-column-005.html "css/css-flexbox/flex-aspect-ratio-img-column-005.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-aspect-ratio-img-column-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-aspect-ratio-img-column-005.html)
- [flex-aspect-ratio-img-column-006.html](https://wpt.fyi/results/css/css-flexbox/flex-aspect-ratio-img-column-006.html "css/css-flexbox/flex-aspect-ratio-img-column-006.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-aspect-ratio-img-column-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-aspect-ratio-img-column-006.html)
- [flex-aspect-ratio-img-column-007.html](https://wpt.fyi/results/css/css-flexbox/flex-aspect-ratio-img-column-007.html "css/css-flexbox/flex-aspect-ratio-img-column-007.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-aspect-ratio-img-column-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-aspect-ratio-img-column-007.html)
- [flex-aspect-ratio-img-column-008.html](https://wpt.fyi/results/css/css-flexbox/flex-aspect-ratio-img-column-008.html "css/css-flexbox/flex-aspect-ratio-img-column-008.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-aspect-ratio-img-column-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-aspect-ratio-img-column-008.html)
- [flex-aspect-ratio-img-column-009.html](https://wpt.fyi/results/css/css-flexbox/flex-aspect-ratio-img-column-009.html "css/css-flexbox/flex-aspect-ratio-img-column-009.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-aspect-ratio-img-column-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-aspect-ratio-img-column-009.html)
- [flex-aspect-ratio-img-column-010.html](https://wpt.fyi/results/css/css-flexbox/flex-aspect-ratio-img-column-010.html "css/css-flexbox/flex-aspect-ratio-img-column-010.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-aspect-ratio-img-column-010.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-aspect-ratio-img-column-010.html)
- [flex-aspect-ratio-img-column-011.html](https://wpt.fyi/results/css/css-flexbox/flex-aspect-ratio-img-column-011.html "css/css-flexbox/flex-aspect-ratio-img-column-011.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-aspect-ratio-img-column-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-aspect-ratio-img-column-011.html)
- [flex-aspect-ratio-img-column-012.html](https://wpt.fyi/results/css/css-flexbox/flex-aspect-ratio-img-column-012.html "css/css-flexbox/flex-aspect-ratio-img-column-012.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-aspect-ratio-img-column-012.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-aspect-ratio-img-column-012.html)
- [flex-aspect-ratio-img-column-013.html](https://wpt.fyi/results/css/css-flexbox/flex-aspect-ratio-img-column-013.html "css/css-flexbox/flex-aspect-ratio-img-column-013.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-aspect-ratio-img-column-013.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-aspect-ratio-img-column-013.html)
- [flex-aspect-ratio-img-column-014.html](https://wpt.fyi/results/css/css-flexbox/flex-aspect-ratio-img-column-014.html "css/css-flexbox/flex-aspect-ratio-img-column-014.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-aspect-ratio-img-column-014.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-aspect-ratio-img-column-014.html)
- [flex-aspect-ratio-img-column-015.html](https://wpt.fyi/results/css/css-flexbox/flex-aspect-ratio-img-column-015.html "css/css-flexbox/flex-aspect-ratio-img-column-015.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-aspect-ratio-img-column-015.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-aspect-ratio-img-column-015.html)
- [flex-aspect-ratio-img-column-016.html](https://wpt.fyi/results/css/css-flexbox/flex-aspect-ratio-img-column-016.html "css/css-flexbox/flex-aspect-ratio-img-column-016.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-aspect-ratio-img-column-016.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-aspect-ratio-img-column-016.html)
- [flex-aspect-ratio-img-column-017.html](https://wpt.fyi/results/css/css-flexbox/flex-aspect-ratio-img-column-017.html "css/css-flexbox/flex-aspect-ratio-img-column-017.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-aspect-ratio-img-column-017.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-aspect-ratio-img-column-017.html)
- [flex-aspect-ratio-img-column-018.html](https://wpt.fyi/results/css/css-flexbox/flex-aspect-ratio-img-column-018.html "css/css-flexbox/flex-aspect-ratio-img-column-018.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-aspect-ratio-img-column-018.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-aspect-ratio-img-column-018.html)
- [flex-aspect-ratio-img-row-001.html](https://wpt.fyi/results/css/css-flexbox/flex-aspect-ratio-img-row-001.html "css/css-flexbox/flex-aspect-ratio-img-row-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-aspect-ratio-img-row-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-aspect-ratio-img-row-001.html)
- [flex-aspect-ratio-img-row-002.html](https://wpt.fyi/results/css/css-flexbox/flex-aspect-ratio-img-row-002.html "css/css-flexbox/flex-aspect-ratio-img-row-002.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-aspect-ratio-img-row-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-aspect-ratio-img-row-002.html)
- [flex-aspect-ratio-img-row-003.html](https://wpt.fyi/results/css/css-flexbox/flex-aspect-ratio-img-row-003.html "css/css-flexbox/flex-aspect-ratio-img-row-003.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-aspect-ratio-img-row-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-aspect-ratio-img-row-003.html)
- [flex-aspect-ratio-img-row-004.html](https://wpt.fyi/results/css/css-flexbox/flex-aspect-ratio-img-row-004.html "css/css-flexbox/flex-aspect-ratio-img-row-004.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-aspect-ratio-img-row-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-aspect-ratio-img-row-004.html)
- [flex-aspect-ratio-img-row-005.html](https://wpt.fyi/results/css/css-flexbox/flex-aspect-ratio-img-row-005.html "css/css-flexbox/flex-aspect-ratio-img-row-005.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-aspect-ratio-img-row-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-aspect-ratio-img-row-005.html)
- [flex-aspect-ratio-img-row-006.html](https://wpt.fyi/results/css/css-flexbox/flex-aspect-ratio-img-row-006.html "css/css-flexbox/flex-aspect-ratio-img-row-006.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-aspect-ratio-img-row-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-aspect-ratio-img-row-006.html)
- [flex-aspect-ratio-img-row-007.html](https://wpt.fyi/results/css/css-flexbox/flex-aspect-ratio-img-row-007.html "css/css-flexbox/flex-aspect-ratio-img-row-007.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-aspect-ratio-img-row-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-aspect-ratio-img-row-007.html)
- [flex-aspect-ratio-img-row-008.html](https://wpt.fyi/results/css/css-flexbox/flex-aspect-ratio-img-row-008.html "css/css-flexbox/flex-aspect-ratio-img-row-008.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-aspect-ratio-img-row-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-aspect-ratio-img-row-008.html)
- [flex-aspect-ratio-img-row-009.html](https://wpt.fyi/results/css/css-flexbox/flex-aspect-ratio-img-row-009.html "css/css-flexbox/flex-aspect-ratio-img-row-009.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-aspect-ratio-img-row-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-aspect-ratio-img-row-009.html)
- [flex-aspect-ratio-img-row-010.html](https://wpt.fyi/results/css/css-flexbox/flex-aspect-ratio-img-row-010.html "css/css-flexbox/flex-aspect-ratio-img-row-010.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-aspect-ratio-img-row-010.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-aspect-ratio-img-row-010.html)
- [flex-aspect-ratio-img-row-011.html](https://wpt.fyi/results/css/css-flexbox/flex-aspect-ratio-img-row-011.html "css/css-flexbox/flex-aspect-ratio-img-row-011.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-aspect-ratio-img-row-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-aspect-ratio-img-row-011.html)
- [flex-aspect-ratio-img-row-012.html](https://wpt.fyi/results/css/css-flexbox/flex-aspect-ratio-img-row-012.html "css/css-flexbox/flex-aspect-ratio-img-row-012.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-aspect-ratio-img-row-012.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-aspect-ratio-img-row-012.html)
- [flex-aspect-ratio-img-row-013.html](https://wpt.fyi/results/css/css-flexbox/flex-aspect-ratio-img-row-013.html "css/css-flexbox/flex-aspect-ratio-img-row-013.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-aspect-ratio-img-row-013.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-aspect-ratio-img-row-013.html)
- [flex-aspect-ratio-img-row-014.html](https://wpt.fyi/results/css/css-flexbox/flex-aspect-ratio-img-row-014.html "css/css-flexbox/flex-aspect-ratio-img-row-014.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-aspect-ratio-img-row-014.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-aspect-ratio-img-row-014.html)
- [flex-aspect-ratio-img-row-015.html](https://wpt.fyi/results/css/css-flexbox/flex-aspect-ratio-img-row-015.html "css/css-flexbox/flex-aspect-ratio-img-row-015.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-aspect-ratio-img-row-015.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-aspect-ratio-img-row-015.html)
- [flex-aspect-ratio-img-row-016.html](https://wpt.fyi/results/css/css-flexbox/flex-aspect-ratio-img-row-016.html "css/css-flexbox/flex-aspect-ratio-img-row-016.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-aspect-ratio-img-row-016.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-aspect-ratio-img-row-016.html)
- [flex-aspect-ratio-img-row-017.html](https://wpt.fyi/results/css/css-flexbox/flex-aspect-ratio-img-row-017.html "css/css-flexbox/flex-aspect-ratio-img-row-017.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-aspect-ratio-img-row-017.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-aspect-ratio-img-row-017.html)
- [flex-aspect-ratio-img-vert-lr.html](https://wpt.fyi/results/css/css-flexbox/flex-aspect-ratio-img-vert-lr.html "css/css-flexbox/flex-aspect-ratio-img-vert-lr.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-aspect-ratio-img-vert-lr.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-aspect-ratio-img-vert-lr.html)
- [flexbox-definite-cross-size-constrained-percentage.html](https://wpt.fyi/results/css/css-flexbox/flexbox-definite-cross-size-constrained-percentage.html "css/css-flexbox/flexbox-definite-cross-size-constrained-percentage.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-definite-cross-size-constrained-percentage.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-definite-cross-size-constrained-percentage.html)
- [flexbox-min-height-auto-001.html](https://wpt.fyi/results/css/css-flexbox/flexbox-min-height-auto-001.html "css/css-flexbox/flexbox-min-height-auto-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-min-height-auto-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-min-height-auto-001.html)
- [flexbox-min-height-auto-002a.html](https://wpt.fyi/results/css/css-flexbox/flexbox-min-height-auto-002a.html "css/css-flexbox/flexbox-min-height-auto-002a.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-min-height-auto-002a.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-min-height-auto-002a.html)
- [flexbox-min-height-auto-002b.html](https://wpt.fyi/results/css/css-flexbox/flexbox-min-height-auto-002b.html "css/css-flexbox/flexbox-min-height-auto-002b.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-min-height-auto-002b.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-min-height-auto-002b.html)
- [flexbox-min-height-auto-002c.html](https://wpt.fyi/results/css/css-flexbox/flexbox-min-height-auto-002c.html "css/css-flexbox/flexbox-min-height-auto-002c.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-min-height-auto-002c.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-min-height-auto-002c.html)
- [flexbox-min-height-auto-003.html](https://wpt.fyi/results/css/css-flexbox/flexbox-min-height-auto-003.html "css/css-flexbox/flexbox-min-height-auto-003.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-min-height-auto-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-min-height-auto-003.html)
- [flexbox-min-height-auto-004.html](https://wpt.fyi/results/css/css-flexbox/flexbox-min-height-auto-004.html "css/css-flexbox/flexbox-min-height-auto-004.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-min-height-auto-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-min-height-auto-004.html)
- [flexbox-min-width-auto-001.html](https://wpt.fyi/results/css/css-flexbox/flexbox-min-width-auto-001.html "css/css-flexbox/flexbox-min-width-auto-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-min-width-auto-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-min-width-auto-001.html)
- [flexbox-min-width-auto-002a.html](https://wpt.fyi/results/css/css-flexbox/flexbox-min-width-auto-002a.html "css/css-flexbox/flexbox-min-width-auto-002a.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-min-width-auto-002a.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-min-width-auto-002a.html)
- [flexbox-min-width-auto-002b.html](https://wpt.fyi/results/css/css-flexbox/flexbox-min-width-auto-002b.html "css/css-flexbox/flexbox-min-width-auto-002b.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-min-width-auto-002b.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-min-width-auto-002b.html)
- [flexbox-min-width-auto-002c.html](https://wpt.fyi/results/css/css-flexbox/flexbox-min-width-auto-002c.html "css/css-flexbox/flexbox-min-width-auto-002c.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-min-width-auto-002c.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-min-width-auto-002c.html)
- [flexbox-min-width-auto-003.html](https://wpt.fyi/results/css/css-flexbox/flexbox-min-width-auto-003.html "css/css-flexbox/flexbox-min-width-auto-003.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-min-width-auto-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-min-width-auto-003.html)
- [flexbox-min-width-auto-004.html](https://wpt.fyi/results/css/css-flexbox/flexbox-min-width-auto-004.html "css/css-flexbox/flexbox-min-width-auto-004.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-min-width-auto-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-min-width-auto-004.html)
- [flexbox-min-width-auto-005.html](https://wpt.fyi/results/css/css-flexbox/flexbox-min-width-auto-005.html "css/css-flexbox/flexbox-min-width-auto-005.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-min-width-auto-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-min-width-auto-005.html)
- [flexbox-min-width-auto-006.html](https://wpt.fyi/results/css/css-flexbox/flexbox-min-width-auto-006.html "css/css-flexbox/flexbox-min-width-auto-006.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-min-width-auto-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-min-width-auto-006.html)
- [flex-item-compressible-001.html](https://wpt.fyi/results/css/css-flexbox/flex-item-compressible-001.html "css/css-flexbox/flex-item-compressible-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-item-compressible-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-item-compressible-001.html)
- [flex-item-compressible-002.html](https://wpt.fyi/results/css/css-flexbox/flex-item-compressible-002.html "css/css-flexbox/flex-item-compressible-002.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-item-compressible-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-item-compressible-002.html)
- [flexitem-stretch-image.html](https://wpt.fyi/results/css/css-flexbox/flexitem-stretch-image.html "css/css-flexbox/flexitem-stretch-image.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexitem-stretch-image.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexitem-stretch-image.html)
- [flexitem-stretch-range.html](https://wpt.fyi/results/css/css-flexbox/flexitem-stretch-range.html "css/css-flexbox/flexitem-stretch-range.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexitem-stretch-range.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexitem-stretch-range.html)
- [flex-minimum-height-flex-items-001.xht](https://wpt.fyi/results/css/css-flexbox/flex-minimum-height-flex-items-001.xht "css/css-flexbox/flex-minimum-height-flex-items-001.xht")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-minimum-height-flex-items-001.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-minimum-height-flex-items-001.xht)
- [flex-minimum-height-flex-items-002.xht](https://wpt.fyi/results/css/css-flexbox/flex-minimum-height-flex-items-002.xht "css/css-flexbox/flex-minimum-height-flex-items-002.xht")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-minimum-height-flex-items-002.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-minimum-height-flex-items-002.xht)
- [flex-minimum-height-flex-items-003.xht](https://wpt.fyi/results/css/css-flexbox/flex-minimum-height-flex-items-003.xht "css/css-flexbox/flex-minimum-height-flex-items-003.xht")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-minimum-height-flex-items-003.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-minimum-height-flex-items-003.xht)
- [flex-minimum-height-flex-items-004.xht](https://wpt.fyi/results/css/css-flexbox/flex-minimum-height-flex-items-004.xht "css/css-flexbox/flex-minimum-height-flex-items-004.xht")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-minimum-height-flex-items-004.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-minimum-height-flex-items-004.xht)
- [flex-minimum-height-flex-items-005.xht](https://wpt.fyi/results/css/css-flexbox/flex-minimum-height-flex-items-005.xht "css/css-flexbox/flex-minimum-height-flex-items-005.xht")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-minimum-height-flex-items-005.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-minimum-height-flex-items-005.xht)
- [flex-minimum-height-flex-items-006.xht](https://wpt.fyi/results/css/css-flexbox/flex-minimum-height-flex-items-006.xht "css/css-flexbox/flex-minimum-height-flex-items-006.xht")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-minimum-height-flex-items-006.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-minimum-height-flex-items-006.xht)
- [flex-minimum-height-flex-items-007.xht](https://wpt.fyi/results/css/css-flexbox/flex-minimum-height-flex-items-007.xht "css/css-flexbox/flex-minimum-height-flex-items-007.xht")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-minimum-height-flex-items-007.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-minimum-height-flex-items-007.xht)
- [flex-minimum-height-flex-items-008.xht](https://wpt.fyi/results/css/css-flexbox/flex-minimum-height-flex-items-008.xht "css/css-flexbox/flex-minimum-height-flex-items-008.xht")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-minimum-height-flex-items-008.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-minimum-height-flex-items-008.xht)
- [flex-minimum-height-flex-items-009.html](https://wpt.fyi/results/css/css-flexbox/flex-minimum-height-flex-items-009.html "css/css-flexbox/flex-minimum-height-flex-items-009.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-minimum-height-flex-items-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-minimum-height-flex-items-009.html)
- [flex-minimum-height-flex-items-010.html](https://wpt.fyi/results/css/css-flexbox/flex-minimum-height-flex-items-010.html "css/css-flexbox/flex-minimum-height-flex-items-010.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-minimum-height-flex-items-010.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-minimum-height-flex-items-010.html)
- [flex-minimum-height-flex-items-011.xht](https://wpt.fyi/results/css/css-flexbox/flex-minimum-height-flex-items-011.xht "css/css-flexbox/flex-minimum-height-flex-items-011.xht")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-minimum-height-flex-items-011.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-minimum-height-flex-items-011.xht)
- [flex-minimum-height-flex-items-012.html](https://wpt.fyi/results/css/css-flexbox/flex-minimum-height-flex-items-012.html "css/css-flexbox/flex-minimum-height-flex-items-012.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-minimum-height-flex-items-012.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-minimum-height-flex-items-012.html)
- [flex-minimum-height-flex-items-013.html](https://wpt.fyi/results/css/css-flexbox/flex-minimum-height-flex-items-013.html "css/css-flexbox/flex-minimum-height-flex-items-013.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-minimum-height-flex-items-013.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-minimum-height-flex-items-013.html)
- [flex-minimum-height-flex-items-014.html](https://wpt.fyi/results/css/css-flexbox/flex-minimum-height-flex-items-014.html "css/css-flexbox/flex-minimum-height-flex-items-014.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-minimum-height-flex-items-014.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-minimum-height-flex-items-014.html)
- [flex-minimum-height-flex-items-015.html](https://wpt.fyi/results/css/css-flexbox/flex-minimum-height-flex-items-015.html "css/css-flexbox/flex-minimum-height-flex-items-015.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-minimum-height-flex-items-015.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-minimum-height-flex-items-015.html)
- [flex-minimum-height-flex-items-016.html](https://wpt.fyi/results/css/css-flexbox/flex-minimum-height-flex-items-016.html "css/css-flexbox/flex-minimum-height-flex-items-016.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-minimum-height-flex-items-016.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-minimum-height-flex-items-016.html)
- [flex-minimum-height-flex-items-017.html](https://wpt.fyi/results/css/css-flexbox/flex-minimum-height-flex-items-017.html "css/css-flexbox/flex-minimum-height-flex-items-017.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-minimum-height-flex-items-017.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-minimum-height-flex-items-017.html)
- [flex-minimum-height-flex-items-018.html](https://wpt.fyi/results/css/css-flexbox/flex-minimum-height-flex-items-018.html "css/css-flexbox/flex-minimum-height-flex-items-018.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-minimum-height-flex-items-018.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-minimum-height-flex-items-018.html)
- [flex-minimum-height-flex-items-019.html](https://wpt.fyi/results/css/css-flexbox/flex-minimum-height-flex-items-019.html "css/css-flexbox/flex-minimum-height-flex-items-019.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-minimum-height-flex-items-019.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-minimum-height-flex-items-019.html)
- [flex-minimum-height-flex-items-020.html](https://wpt.fyi/results/css/css-flexbox/flex-minimum-height-flex-items-020.html "css/css-flexbox/flex-minimum-height-flex-items-020.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-minimum-height-flex-items-020.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-minimum-height-flex-items-020.html)
- [flex-minimum-height-flex-items-021.html](https://wpt.fyi/results/css/css-flexbox/flex-minimum-height-flex-items-021.html "css/css-flexbox/flex-minimum-height-flex-items-021.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-minimum-height-flex-items-021.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-minimum-height-flex-items-021.html)
- [flex-minimum-height-flex-items-022.html](https://wpt.fyi/results/css/css-flexbox/flex-minimum-height-flex-items-022.html "css/css-flexbox/flex-minimum-height-flex-items-022.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-minimum-height-flex-items-022.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-minimum-height-flex-items-022.html)
- [flex-minimum-height-flex-items-023.html](https://wpt.fyi/results/css/css-flexbox/flex-minimum-height-flex-items-023.html "css/css-flexbox/flex-minimum-height-flex-items-023.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-minimum-height-flex-items-023.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-minimum-height-flex-items-023.html)
- [flex-minimum-height-flex-items-024.html](https://wpt.fyi/results/css/css-flexbox/flex-minimum-height-flex-items-024.html "css/css-flexbox/flex-minimum-height-flex-items-024.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-minimum-height-flex-items-024.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-minimum-height-flex-items-024.html)
- [flex-minimum-height-flex-items-025.html](https://wpt.fyi/results/css/css-flexbox/flex-minimum-height-flex-items-025.html "css/css-flexbox/flex-minimum-height-flex-items-025.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-minimum-height-flex-items-025.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-minimum-height-flex-items-025.html)
- [flex-minimum-height-flex-items-026.html](https://wpt.fyi/results/css/css-flexbox/flex-minimum-height-flex-items-026.html "css/css-flexbox/flex-minimum-height-flex-items-026.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-minimum-height-flex-items-026.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-minimum-height-flex-items-026.html)
- [flex-minimum-height-flex-items-027.html](https://wpt.fyi/results/css/css-flexbox/flex-minimum-height-flex-items-027.html "css/css-flexbox/flex-minimum-height-flex-items-027.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-minimum-height-flex-items-027.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-minimum-height-flex-items-027.html)
- [flex-minimum-height-flex-items-028.html](https://wpt.fyi/results/css/css-flexbox/flex-minimum-height-flex-items-028.html "css/css-flexbox/flex-minimum-height-flex-items-028.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-minimum-height-flex-items-028.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-minimum-height-flex-items-028.html)
- [flex-minimum-height-flex-items-029.html](https://wpt.fyi/results/css/css-flexbox/flex-minimum-height-flex-items-029.html "css/css-flexbox/flex-minimum-height-flex-items-029.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-minimum-height-flex-items-029.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-minimum-height-flex-items-029.html)
- [flex-minimum-height-flex-items-030.html](https://wpt.fyi/results/css/css-flexbox/flex-minimum-height-flex-items-030.html "css/css-flexbox/flex-minimum-height-flex-items-030.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-minimum-height-flex-items-030.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-minimum-height-flex-items-030.html)
- [flex-minimum-height-flex-items-031.html](https://wpt.fyi/results/css/css-flexbox/flex-minimum-height-flex-items-031.html "css/css-flexbox/flex-minimum-height-flex-items-031.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-minimum-height-flex-items-031.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-minimum-height-flex-items-031.html)
- [flex-minimum-size-001.html](https://wpt.fyi/results/css/css-flexbox/flex-minimum-size-001.html "css/css-flexbox/flex-minimum-size-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-minimum-size-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-minimum-size-001.html)
- [flex-minimum-size-002.html](https://wpt.fyi/results/css/css-flexbox/flex-minimum-size-002.html "css/css-flexbox/flex-minimum-size-002.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-minimum-size-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-minimum-size-002.html)
- [flex-minimum-size-003.html](https://wpt.fyi/results/css/css-flexbox/flex-minimum-size-003.html "css/css-flexbox/flex-minimum-size-003.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-minimum-size-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-minimum-size-003.html)
- [flex-minimum-width-flex-items-001.xht](https://wpt.fyi/results/css/css-flexbox/flex-minimum-width-flex-items-001.xht "css/css-flexbox/flex-minimum-width-flex-items-001.xht")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-minimum-width-flex-items-001.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-minimum-width-flex-items-001.xht)
- [flex-minimum-width-flex-items-002.xht](https://wpt.fyi/results/css/css-flexbox/flex-minimum-width-flex-items-002.xht "css/css-flexbox/flex-minimum-width-flex-items-002.xht")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-minimum-width-flex-items-002.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-minimum-width-flex-items-002.xht)
- [flex-minimum-width-flex-items-003.xht](https://wpt.fyi/results/css/css-flexbox/flex-minimum-width-flex-items-003.xht "css/css-flexbox/flex-minimum-width-flex-items-003.xht")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-minimum-width-flex-items-003.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-minimum-width-flex-items-003.xht)
- [flex-minimum-width-flex-items-004.xht](https://wpt.fyi/results/css/css-flexbox/flex-minimum-width-flex-items-004.xht "css/css-flexbox/flex-minimum-width-flex-items-004.xht")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-minimum-width-flex-items-004.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-minimum-width-flex-items-004.xht)
- [flex-minimum-width-flex-items-005.xht](https://wpt.fyi/results/css/css-flexbox/flex-minimum-width-flex-items-005.xht "css/css-flexbox/flex-minimum-width-flex-items-005.xht")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-minimum-width-flex-items-005.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-minimum-width-flex-items-005.xht)
- [flex-minimum-width-flex-items-006.xht](https://wpt.fyi/results/css/css-flexbox/flex-minimum-width-flex-items-006.xht "css/css-flexbox/flex-minimum-width-flex-items-006.xht")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-minimum-width-flex-items-006.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-minimum-width-flex-items-006.xht)
- [flex-minimum-width-flex-items-007.xht](https://wpt.fyi/results/css/css-flexbox/flex-minimum-width-flex-items-007.xht "css/css-flexbox/flex-minimum-width-flex-items-007.xht")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-minimum-width-flex-items-007.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-minimum-width-flex-items-007.xht)
- [flex-minimum-width-flex-items-008.xht](https://wpt.fyi/results/css/css-flexbox/flex-minimum-width-flex-items-008.xht "css/css-flexbox/flex-minimum-width-flex-items-008.xht")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-minimum-width-flex-items-008.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-minimum-width-flex-items-008.xht)
- [flex-minimum-width-flex-items-009.html](https://wpt.fyi/results/css/css-flexbox/flex-minimum-width-flex-items-009.html "css/css-flexbox/flex-minimum-width-flex-items-009.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-minimum-width-flex-items-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-minimum-width-flex-items-009.html)
- [flex-minimum-width-flex-items-010.html](https://wpt.fyi/results/css/css-flexbox/flex-minimum-width-flex-items-010.html "css/css-flexbox/flex-minimum-width-flex-items-010.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-minimum-width-flex-items-010.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-minimum-width-flex-items-010.html)
- [flex-minimum-width-flex-items-011.html](https://wpt.fyi/results/css/css-flexbox/flex-minimum-width-flex-items-011.html "css/css-flexbox/flex-minimum-width-flex-items-011.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-minimum-width-flex-items-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-minimum-width-flex-items-011.html)
- [flex-minimum-width-flex-items-012.html](https://wpt.fyi/results/css/css-flexbox/flex-minimum-width-flex-items-012.html "css/css-flexbox/flex-minimum-width-flex-items-012.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-minimum-width-flex-items-012.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-minimum-width-flex-items-012.html)
- [flex-minimum-width-flex-items-013.html](https://wpt.fyi/results/css/css-flexbox/flex-minimum-width-flex-items-013.html "css/css-flexbox/flex-minimum-width-flex-items-013.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-minimum-width-flex-items-013.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-minimum-width-flex-items-013.html)
- [flex-minimum-width-flex-items-014.html](https://wpt.fyi/results/css/css-flexbox/flex-minimum-width-flex-items-014.html "css/css-flexbox/flex-minimum-width-flex-items-014.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-minimum-width-flex-items-014.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-minimum-width-flex-items-014.html)
- [flex-minimum-width-flex-items-015.html](https://wpt.fyi/results/css/css-flexbox/flex-minimum-width-flex-items-015.html "css/css-flexbox/flex-minimum-width-flex-items-015.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-minimum-width-flex-items-015.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-minimum-width-flex-items-015.html)
- [flex-minimum-width-flex-items-016.html](https://wpt.fyi/results/css/css-flexbox/flex-minimum-width-flex-items-016.html "css/css-flexbox/flex-minimum-width-flex-items-016.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-minimum-width-flex-items-016.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-minimum-width-flex-items-016.html)
- [checkbox-percentage-width-in-flex.html](https://wpt.fyi/results/css/css-flexbox/checkbox-percentage-width-in-flex.html "css/css-flexbox/checkbox-percentage-width-in-flex.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/checkbox-percentage-width-in-flex.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/checkbox-percentage-width-in-flex.html)
- [flexbox_computedstyle_min-auto-size.html](https://wpt.fyi/results/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_min-auto-size.html "css/css-flexbox/getcomputedstyle/flexbox_computedstyle_min-auto-size.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_min-auto-size.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_min-auto-size.html)
- [flexbox_computedstyle_min-height-auto.html](https://wpt.fyi/results/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_min-height-auto.html "css/css-flexbox/getcomputedstyle/flexbox_computedstyle_min-height-auto.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_min-height-auto.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_min-height-auto.html)
- [flexbox_computedstyle_min-width-auto.html](https://wpt.fyi/results/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_min-width-auto.html "css/css-flexbox/getcomputedstyle/flexbox_computedstyle_min-width-auto.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_min-width-auto.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_min-width-auto.html)
- [select-element-zero-height-001.html](https://wpt.fyi/results/css/css-flexbox/select-element-zero-height-001.html "css/css-flexbox/select-element-zero-height-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/select-element-zero-height-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/select-element-zero-height-001.html)
- [select-element-zero-height-002.html](https://wpt.fyi/results/css/css-flexbox/select-element-zero-height-002.html "css/css-flexbox/select-element-zero-height-002.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/select-element-zero-height-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/select-element-zero-height-002.html)

 The [content-based minimum
size](#content-based-minimum-size) is a type of [intrinsic size
contribution](https://drafts.csswg.org/css-sizing-3/#intrinsic-size-contribution), and thus the cyclic percentage provisions in [CSS
Sizing 3 § 5.2 Intrinsic
Contributions](https://drafts.csswg.org/css-sizing-3/#intrinsic-contribution)
apply.

For the purpose of calculating an intrinsic size of the box (e.g. the
box's [min-content
size](https://drafts.csswg.org/css-sizing-3/#min-content)), a [content-based minimum
size](#content-based-minimum-size) causes the box's size in that axis to become indefinite
(even if e.g. its
[width](https://drafts.csswg.org/css-sizing-3/#propdef-width) property specifies a
[definite](#definite) size). Note
this means that percentages calculated against this size will [behave as
auto](https://drafts.csswg.org/css-sizing-3/#behave-as-auto).

For any purpose *other than* calculating intrinsic sizes, a
[content-based minimum
size](#content-based-minimum-size) (unlike an explicit
[min-content](https://drafts.csswg.org/css-sizing-3/#valdef-width-min-content)/etc [minimum
size](https://drafts.csswg.org/css-sizing-3/#min-width)) does not force the box's size to become indefinite.
However, if a percentage resolved against the box's size *before* this
minimum was applied, it must be re-resolved against the new size after
it is applied.

Note that while a content-based minimum
size is often appropriate, and helps prevent content from overlapping or
spilling outside its container, in some cases it is not:

In particular, if flex sizing is being used for a major content area of
a document, it is better to set an explicit font-relative minimum width
such as [min-width:
12em](https://drafts.csswg.org/css2/#propdef-min-width). A content-based minimum width could result
in a large table or large image stretching the size of the entire
content area into an overflow zone, and thereby making lines of text
gratuitously long and hard to read.

Note also, when content-based sizing is used on an item with large
amounts of content, the layout engine must traverse all of this content
before finding its minimum size, whereas if the author sets an explicit
minimum, this is not necessary. (For items with small amounts of
content, however, this traversal is trivial and therefore not a
performance concern.)

- [aspect-ratio-intrinsic-size-001.html](https://wpt.fyi/results/css/css-flexbox/aspect-ratio-intrinsic-size-001.html "css/css-flexbox/aspect-ratio-intrinsic-size-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/aspect-ratio-intrinsic-size-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/aspect-ratio-intrinsic-size-001.html)
- [aspect-ratio-intrinsic-size-002.html](https://wpt.fyi/results/css/css-flexbox/aspect-ratio-intrinsic-size-002.html "css/css-flexbox/aspect-ratio-intrinsic-size-002.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/aspect-ratio-intrinsic-size-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/aspect-ratio-intrinsic-size-002.html)
- [aspect-ratio-intrinsic-size-003.html](https://wpt.fyi/results/css/css-flexbox/aspect-ratio-intrinsic-size-003.html "css/css-flexbox/aspect-ratio-intrinsic-size-003.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/aspect-ratio-intrinsic-size-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/aspect-ratio-intrinsic-size-003.html)
- [aspect-ratio-intrinsic-size-004.html](https://wpt.fyi/results/css/css-flexbox/aspect-ratio-intrinsic-size-004.html "css/css-flexbox/aspect-ratio-intrinsic-size-004.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/aspect-ratio-intrinsic-size-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/aspect-ratio-intrinsic-size-004.html)
- [aspect-ratio-intrinsic-size-005.html](https://wpt.fyi/results/css/css-flexbox/aspect-ratio-intrinsic-size-005.html "css/css-flexbox/aspect-ratio-intrinsic-size-005.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/aspect-ratio-intrinsic-size-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/aspect-ratio-intrinsic-size-005.html)
- [aspect-ratio-intrinsic-size-006.html](https://wpt.fyi/results/css/css-flexbox/aspect-ratio-intrinsic-size-006.html "css/css-flexbox/aspect-ratio-intrinsic-size-006.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/aspect-ratio-intrinsic-size-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/aspect-ratio-intrinsic-size-006.html)
- [aspect-ratio-intrinsic-size-007.html](https://wpt.fyi/results/css/css-flexbox/aspect-ratio-intrinsic-size-007.html "css/css-flexbox/aspect-ratio-intrinsic-size-007.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/aspect-ratio-intrinsic-size-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/aspect-ratio-intrinsic-size-007.html)
- [aspect-ratio-intrinsic-size-008.html](https://wpt.fyi/results/css/css-flexbox/aspect-ratio-intrinsic-size-008.html "css/css-flexbox/aspect-ratio-intrinsic-size-008.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/aspect-ratio-intrinsic-size-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/aspect-ratio-intrinsic-size-008.html)
- [aspect-ratio-intrinsic-size-009.html](https://wpt.fyi/results/css/css-flexbox/aspect-ratio-intrinsic-size-009.html "css/css-flexbox/aspect-ratio-intrinsic-size-009.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/aspect-ratio-intrinsic-size-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/aspect-ratio-intrinsic-size-009.html)
- [aspect-ratio-intrinsic-size-010.html](https://wpt.fyi/results/css/css-flexbox/aspect-ratio-intrinsic-size-010.html "css/css-flexbox/aspect-ratio-intrinsic-size-010.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/aspect-ratio-intrinsic-size-010.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/aspect-ratio-intrinsic-size-010.html)
- [aspect-ratio-transferred-max-size.html](https://wpt.fyi/results/css/css-flexbox/aspect-ratio-transferred-max-size.html "css/css-flexbox/aspect-ratio-transferred-max-size.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/aspect-ratio-transferred-max-size.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/aspect-ratio-transferred-max-size.html)
- [flex-item-content-is-min-width-max-content.html](https://wpt.fyi/results/css/css-flexbox/flex-item-content-is-min-width-max-content.html "css/css-flexbox/flex-item-content-is-min-width-max-content.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-item-content-is-min-width-max-content.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-item-content-is-min-width-max-content.html)

## 5. Ordering and Orientation

The contents of a flex container can be laid out in any direction and in
any order. This allows an author to trivially achieve effects that would
previously have required complex or fragile methods, such as hacks using
the
[float](https://drafts.csswg.org/css2/#propdef-float) and
[clear](https://drafts.csswg.org/css2/#propdef-clear) properties. This functionality is
exposed through the
[flex-direction](#propdef-flex-direction),
[flex-wrap](#propdef-flex-wrap), and
[order](https://drafts.csswg.org/css-display-4/#propdef-order) properties.

 The reordering capabilities of flex layout
intentionally affect *only the visual rendering*, leaving speech order
and navigation based on the source order. This allows authors to
manipulate the visual presentation while leaving the source order intact
for non-CSS UAs and for linear models such as speech and sequential
navigation. See [CSS Display 3 § 3.1 Reordering and
Accessibility](https://drafts.csswg.org/css-display-3/#order-accessibility)
and the [Flex Layout Overview](#overview) for examples that use this
dichotomy to improve accessibility.

**Authors *must not* use
[order](https://drafts.csswg.org/css-display-4/#propdef-order) or the [\*-reverse] values of
[flex-flow](#propdef-flex-flow)/[flex-direction](#propdef-flex-direction) as a substitute for correct source
ordering, as that can ruin the accessibility of the document.**

### 5.1. Flex Flow Direction: the [flex-direction property]
Name:

[flex-direction]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

row
[\|](https://drafts.csswg.org/css-values-4/#comb-one) row-reverse [\|] column
[\|] column-reverse

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

row

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[flex containers](#flex-container)

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

The
[flex-direction](#propdef-flex-direction) property specifies how [flex
items](#flex-item) are placed in
the flex container, by setting the direction of the flex container's
[main axis](#main-axis). This
determines the direction in which flex items are laid out.

[row]
: The flex container's [main axis](#main-axis) has the same orientation as the [inline
 axis](https://drafts.csswg.org/css-writing-modes-4/#inline-axis) of the current [writing
 mode](https://drafts.csswg.org/css-writing-modes-4/#writing-mode). The [main-start](#main-start) and [main-end](#main-end) directions are equivalent to the
 [inline-start](https://drafts.csswg.org/css-writing-modes-4/#inline-start) and
 [inline-end](https://drafts.csswg.org/css-writing-modes-4/#inline-end) directions, respectively, of the current [writing
 mode].
 Tests
 - [flex-child-percent-basis-resize-1.html](https://wpt.fyi/results/css/css-flexbox/flex-child-percent-basis-resize-1.html "css/css-flexbox/flex-child-percent-basis-resize-1.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-child-percent-basis-resize-1.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-child-percent-basis-resize-1.html)
 - [flexbox-flex-basis-content-001a.html](https://wpt.fyi/results/css/css-flexbox/flexbox-flex-basis-content-001a.html "css/css-flexbox/flexbox-flex-basis-content-001a.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-flex-basis-content-001a.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-flex-basis-content-001a.html)
 - [flexbox-flex-basis-content-001b.html](https://wpt.fyi/results/css/css-flexbox/flexbox-flex-basis-content-001b.html "css/css-flexbox/flexbox-flex-basis-content-001b.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-flex-basis-content-001b.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-flex-basis-content-001b.html)
 - [flexbox-flex-direction-row.htm](https://wpt.fyi/results/css/css-flexbox/flexbox-flex-direction-row.htm "css/css-flexbox/flexbox-flex-direction-row.htm")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-flex-direction-row.htm)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-flex-direction-row.htm)
 - [flexbox_justifycontent-left-001.html](https://wpt.fyi/results/css/css-flexbox/flexbox_justifycontent-left-001.html "css/css-flexbox/flexbox_justifycontent-left-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_justifycontent-left-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_justifycontent-left-001.html)
 - [flexbox-writing-mode-010.html](https://wpt.fyi/results/css/css-flexbox/flexbox-writing-mode-010.html "css/css-flexbox/flexbox-writing-mode-010.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-writing-mode-010.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-writing-mode-010.html)
 - [flexbox-writing-mode-011.html](https://wpt.fyi/results/css/css-flexbox/flexbox-writing-mode-011.html "css/css-flexbox/flexbox-writing-mode-011.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-writing-mode-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-writing-mode-011.html)
 - [flexbox-writing-mode-012.html](https://wpt.fyi/results/css/css-flexbox/flexbox-writing-mode-012.html "css/css-flexbox/flexbox-writing-mode-012.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-writing-mode-012.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-writing-mode-012.html)
 - [flexbox-writing-mode-016.html](https://wpt.fyi/results/css/css-flexbox/flexbox-writing-mode-016.html "css/css-flexbox/flexbox-writing-mode-016.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-writing-mode-016.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-writing-mode-016.html)
 - [percentage-size.html](https://wpt.fyi/results/css/css-flexbox/percentage-size.html "css/css-flexbox/percentage-size.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/percentage-size.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/percentage-size.html)

[row-reverse]
: Same as
 [row](#valdef-flex-direction-row), except the
 [main-start](#main-start) and
 [main-end](#main-end) directions
 are swapped.
 Tests
 - [flexbox_direction-row-reverse.html](https://wpt.fyi/results/css/css-flexbox/flexbox_direction-row-reverse.html "css/css-flexbox/flexbox_direction-row-reverse.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_direction-row-reverse.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_direction-row-reverse.html)
 - [flexbox-mbp-horiz-001-reverse.xhtml](https://wpt.fyi/results/css/css-flexbox/flexbox-mbp-horiz-001-reverse.xhtml "css/css-flexbox/flexbox-mbp-horiz-001-reverse.xhtml")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-mbp-horiz-001-reverse.xhtml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-mbp-horiz-001-reverse.xhtml)
 - [flexbox-mbp-horiz-001-rtl-reverse.xhtml](https://wpt.fyi/results/css/css-flexbox/flexbox-mbp-horiz-001-rtl-reverse.xhtml "css/css-flexbox/flexbox-mbp-horiz-001-rtl-reverse.xhtml")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-mbp-horiz-001-rtl-reverse.xhtml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-mbp-horiz-001-rtl-reverse.xhtml)
 - [multi-line-wrap-with-row-reverse.html](https://wpt.fyi/results/css/css-flexbox/flex-lines/multi-line-wrap-with-row-reverse.html "css/css-flexbox/flex-lines/multi-line-wrap-with-row-reverse.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-lines/multi-line-wrap-with-row-reverse.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-lines/multi-line-wrap-with-row-reverse.html)
 - [flexbox_justifycontent-right-001.html](https://wpt.fyi/results/css/css-flexbox/flexbox_justifycontent-right-001.html "css/css-flexbox/flexbox_justifycontent-right-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_justifycontent-right-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_justifycontent-right-001.html)
 - [flexbox_justifycontent-start.html](https://wpt.fyi/results/css/css-flexbox/flexbox_justifycontent-start.html "css/css-flexbox/flexbox_justifycontent-start.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_justifycontent-start.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_justifycontent-start.html)
 - [flexbox_justifycontent-start-rtl.html](https://wpt.fyi/results/css/css-flexbox/flexbox_justifycontent-start-rtl.html "css/css-flexbox/flexbox_justifycontent-start-rtl.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_justifycontent-start-rtl.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_justifycontent-start-rtl.html)

[column]
: The flex container's [main axis](#main-axis) has the same orientation as the [block
 axis](https://drafts.csswg.org/css-writing-modes-4/#block-axis) of the current [writing
 mode](https://drafts.csswg.org/css-writing-modes-4/#writing-mode). The [main-start](#main-start) and [main-end](#main-end) directions are equivalent to the
 [block-start](https://drafts.csswg.org/css-writing-modes-4/#block-start) and
 [block-end](https://drafts.csswg.org/css-writing-modes-4/#block-end) directions, respectively, of the current [writing
 mode].
 Tests
 - [columns-height-set-via-top-bottom.html](https://wpt.fyi/results/css/css-flexbox/columns-height-set-via-top-bottom.html "css/css-flexbox/columns-height-set-via-top-bottom.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/columns-height-set-via-top-bottom.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/columns-height-set-via-top-bottom.html)
 - [dynamic-bsize-change.html](https://wpt.fyi/results/css/css-flexbox/dynamic-bsize-change.html "css/css-flexbox/dynamic-bsize-change.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/dynamic-bsize-change.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/dynamic-bsize-change.html)
 - [flexbox_direction-column.html](https://wpt.fyi/results/css/css-flexbox/flexbox_direction-column.html "css/css-flexbox/flexbox_direction-column.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_direction-column.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_direction-column.html)
 - [flexbox_direction-column-reverse.html](https://wpt.fyi/results/css/css-flexbox/flexbox_direction-column-reverse.html "css/css-flexbox/flexbox_direction-column-reverse.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_direction-column-reverse.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_direction-column-reverse.html)
 - [flexbox_rtl-flow.html](https://wpt.fyi/results/css/css-flexbox/flexbox_rtl-flow.html "css/css-flexbox/flexbox_rtl-flow.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_rtl-flow.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_rtl-flow.html)
 - [flex-column-relayout-assert.html](https://wpt.fyi/results/css/css-flexbox/flex-column-relayout-assert.html "css/css-flexbox/flex-column-relayout-assert.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-column-relayout-assert.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-column-relayout-assert.html)
 - [flex-item-max-height-min-content.html](https://wpt.fyi/results/css/css-flexbox/flex-item-max-height-min-content.html "css/css-flexbox/flex-item-max-height-min-content.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-item-max-height-min-content.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-item-max-height-min-content.html)
 - [flex-item-transferred-sizes-padding-border-sizing.html](https://wpt.fyi/results/css/css-flexbox/flex-item-transferred-sizes-padding-border-sizing.html "css/css-flexbox/flex-item-transferred-sizes-padding-border-sizing.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-item-transferred-sizes-padding-border-sizing.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-item-transferred-sizes-padding-border-sizing.html)
 - [flex-item-transferred-sizes-padding-content-sizing.html](https://wpt.fyi/results/css/css-flexbox/flex-item-transferred-sizes-padding-content-sizing.html "css/css-flexbox/flex-item-transferred-sizes-padding-content-sizing.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-item-transferred-sizes-padding-content-sizing.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-item-transferred-sizes-padding-content-sizing.html)
 - [flex-outer-flexbox-column-recalculate-height-on-resize-001.html](https://wpt.fyi/results/css/css-flexbox/flex-outer-flexbox-column-recalculate-height-on-resize-001.html "css/css-flexbox/flex-outer-flexbox-column-recalculate-height-on-resize-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-outer-flexbox-column-recalculate-height-on-resize-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-outer-flexbox-column-recalculate-height-on-resize-001.html)
 - [image-nested-within-definite-column-flexbox.html](https://wpt.fyi/results/css/css-flexbox/image-nested-within-definite-column-flexbox.html "css/css-flexbox/image-nested-within-definite-column-flexbox.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/image-nested-within-definite-column-flexbox.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/image-nested-within-definite-column-flexbox.html)
 - [layout-with-inline-svg-001.html](https://wpt.fyi/results/css/css-flexbox/layout-with-inline-svg-001.html "css/css-flexbox/layout-with-inline-svg-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/layout-with-inline-svg-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/layout-with-inline-svg-001.html)
 - [nested-orthogonal-flexbox-relayout.html](https://wpt.fyi/results/css/css-flexbox/nested-orthogonal-flexbox-relayout.html "css/css-flexbox/nested-orthogonal-flexbox-relayout.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/nested-orthogonal-flexbox-relayout.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/nested-orthogonal-flexbox-relayout.html)
 - [percentage-max-width-cross-axis.html](https://wpt.fyi/results/css/css-flexbox/percentage-max-width-cross-axis.html "css/css-flexbox/percentage-max-width-cross-axis.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/percentage-max-width-cross-axis.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/percentage-max-width-cross-axis.html)
 - [percentage-size.html](https://wpt.fyi/results/css/css-flexbox/percentage-size.html "css/css-flexbox/percentage-size.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/percentage-size.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/percentage-size.html)

[column-reverse]
: Same as
 [column](#valdef-flex-direction-column), except the
 [main-start](#main-start) and
 [main-end](#main-end) directions
 are swapped.
 Tests
 - [column-reverse-gap.html](https://wpt.fyi/results/css/css-flexbox/column-reverse-gap.html "css/css-flexbox/column-reverse-gap.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/column-reverse-gap.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/column-reverse-gap.html)
 - [flexbox_rtl-direction.html](https://wpt.fyi/results/css/css-flexbox/flexbox_rtl-direction.html "css/css-flexbox/flexbox_rtl-direction.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_rtl-direction.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_rtl-direction.html)
 - [multi-line-wrap-with-column-reverse.html](https://wpt.fyi/results/css/css-flexbox/flex-lines/multi-line-wrap-with-column-reverse.html "css/css-flexbox/flex-lines/multi-line-wrap-with-column-reverse.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-lines/multi-line-wrap-with-column-reverse.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-lines/multi-line-wrap-with-column-reverse.html)

 The reverse values do not reverse box ordering: like
[writing-mode](https://drafts.csswg.org/css-writing-modes-4/#propdef-writing-mode) and
[direction](https://drafts.csswg.org/css-writing-modes-3/#propdef-direction)
[\[CSS3-WRITING-MODES\]](#biblio-css3-writing-modes "CSS Writing Modes Level 3"),
they only change the direction of flow. Painting order, speech order,
and sequential navigation orders are not affected.

 Depending on the value of
[justify-content](#propdef-justify-content), the reverse values of
[flex-direction](#propdef-flex-direction) can alter the initial scroll
position on [flex containers](#flex-container) that are also [scroll
containers](https://drafts.csswg.org/css-overflow-3/#scroll-container). See [CSS Box Alignment 3 § 5.3 Alignment Overflow and
Scroll
Containers](https://drafts.csswg.org/css-align-3/#overflow-scroll-position).

Tests

- [discrete-no-interpolation.html](https://wpt.fyi/results/css/css-flexbox/animation/discrete-no-interpolation.html "css/css-flexbox/animation/discrete-no-interpolation.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/animation/discrete-no-interpolation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/animation/discrete-no-interpolation.html)
- [change-column-flex-width.html](https://wpt.fyi/results/css/css-flexbox/change-column-flex-width.html "css/css-flexbox/change-column-flex-width.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/change-column-flex-width.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/change-column-flex-width.html)
- [column-flex-child-with-max-width.html](https://wpt.fyi/results/css/css-flexbox/column-flex-child-with-max-width.html "css/css-flexbox/column-flex-child-with-max-width.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/column-flex-child-with-max-width.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/column-flex-child-with-max-width.html)
- [column-flex-child-with-overflow-scroll.html](https://wpt.fyi/results/css/css-flexbox/column-flex-child-with-overflow-scroll.html "css/css-flexbox/column-flex-child-with-overflow-scroll.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/column-flex-child-with-overflow-scroll.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/column-flex-child-with-overflow-scroll.html)
- [cross-axis-scrollbar.html](https://wpt.fyi/results/css/css-flexbox/cross-axis-scrollbar.html "css/css-flexbox/cross-axis-scrollbar.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/cross-axis-scrollbar.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/cross-axis-scrollbar.html)
- [dynamic-orthogonal-flex-item.html](https://wpt.fyi/results/css/css-flexbox/dynamic-orthogonal-flex-item.html "css/css-flexbox/dynamic-orthogonal-flex-item.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/dynamic-orthogonal-flex-item.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/dynamic-orthogonal-flex-item.html)
- [flexbox-writing-mode-001.html](https://wpt.fyi/results/css/css-flexbox/flexbox-writing-mode-001.html "css/css-flexbox/flexbox-writing-mode-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-writing-mode-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-writing-mode-001.html)
- [flexbox-writing-mode-002.html](https://wpt.fyi/results/css/css-flexbox/flexbox-writing-mode-002.html "css/css-flexbox/flexbox-writing-mode-002.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-writing-mode-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-writing-mode-002.html)
- [flexbox-writing-mode-003.html](https://wpt.fyi/results/css/css-flexbox/flexbox-writing-mode-003.html "css/css-flexbox/flexbox-writing-mode-003.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-writing-mode-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-writing-mode-003.html)
- [flexbox-writing-mode-004.html](https://wpt.fyi/results/css/css-flexbox/flexbox-writing-mode-004.html "css/css-flexbox/flexbox-writing-mode-004.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-writing-mode-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-writing-mode-004.html)
- [flexbox-writing-mode-005.html](https://wpt.fyi/results/css/css-flexbox/flexbox-writing-mode-005.html "css/css-flexbox/flexbox-writing-mode-005.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-writing-mode-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-writing-mode-005.html)
- [flexbox-writing-mode-006.html](https://wpt.fyi/results/css/css-flexbox/flexbox-writing-mode-006.html "css/css-flexbox/flexbox-writing-mode-006.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-writing-mode-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-writing-mode-006.html)
- [flexbox-writing-mode-007.html](https://wpt.fyi/results/css/css-flexbox/flexbox-writing-mode-007.html "css/css-flexbox/flexbox-writing-mode-007.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-writing-mode-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-writing-mode-007.html)
- [flexbox-writing-mode-008.html](https://wpt.fyi/results/css/css-flexbox/flexbox-writing-mode-008.html "css/css-flexbox/flexbox-writing-mode-008.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-writing-mode-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-writing-mode-008.html)
- [flexbox-writing-mode-009.html](https://wpt.fyi/results/css/css-flexbox/flexbox-writing-mode-009.html "css/css-flexbox/flexbox-writing-mode-009.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-writing-mode-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-writing-mode-009.html)
- [flexbox-writing-mode-010.html](https://wpt.fyi/results/css/css-flexbox/flexbox-writing-mode-010.html "css/css-flexbox/flexbox-writing-mode-010.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-writing-mode-010.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-writing-mode-010.html)
- [flexbox-writing-mode-011.html](https://wpt.fyi/results/css/css-flexbox/flexbox-writing-mode-011.html "css/css-flexbox/flexbox-writing-mode-011.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-writing-mode-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-writing-mode-011.html)
- [flexbox-writing-mode-012.html](https://wpt.fyi/results/css/css-flexbox/flexbox-writing-mode-012.html "css/css-flexbox/flexbox-writing-mode-012.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-writing-mode-012.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-writing-mode-012.html)
- [flexbox-writing-mode-013.html](https://wpt.fyi/results/css/css-flexbox/flexbox-writing-mode-013.html "css/css-flexbox/flexbox-writing-mode-013.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-writing-mode-013.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-writing-mode-013.html)
- [flexbox-writing-mode-014.html](https://wpt.fyi/results/css/css-flexbox/flexbox-writing-mode-014.html "css/css-flexbox/flexbox-writing-mode-014.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-writing-mode-014.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-writing-mode-014.html)
- [flexbox-writing-mode-015.html](https://wpt.fyi/results/css/css-flexbox/flexbox-writing-mode-015.html "css/css-flexbox/flexbox-writing-mode-015.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-writing-mode-015.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-writing-mode-015.html)
- [flexbox-writing-mode-016.html](https://wpt.fyi/results/css/css-flexbox/flexbox-writing-mode-016.html "css/css-flexbox/flexbox-writing-mode-016.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-writing-mode-016.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-writing-mode-016.html)
- [flexbox-writing-mode-slr.html](https://wpt.fyi/results/css/css-flexbox/flexbox-writing-mode-slr.html "css/css-flexbox/flexbox-writing-mode-slr.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-writing-mode-slr.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-writing-mode-slr.html)
- [flexbox-writing-mode-slr-row-mix.html](https://wpt.fyi/results/css/css-flexbox/flexbox-writing-mode-slr-row-mix.html "css/css-flexbox/flexbox-writing-mode-slr-row-mix.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-writing-mode-slr-row-mix.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-writing-mode-slr-row-mix.html)
- [flexbox-writing-mode-slr-rtl.html](https://wpt.fyi/results/css/css-flexbox/flexbox-writing-mode-slr-rtl.html "css/css-flexbox/flexbox-writing-mode-slr-rtl.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-writing-mode-slr-rtl.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-writing-mode-slr-rtl.html)
- [flexbox-writing-mode-srl.html](https://wpt.fyi/results/css/css-flexbox/flexbox-writing-mode-srl.html "css/css-flexbox/flexbox-writing-mode-srl.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-writing-mode-srl.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-writing-mode-srl.html)
- [flexbox-writing-mode-srl-row-mix.html](https://wpt.fyi/results/css/css-flexbox/flexbox-writing-mode-srl-row-mix.html "css/css-flexbox/flexbox-writing-mode-srl-row-mix.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-writing-mode-srl-row-mix.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-writing-mode-srl-row-mix.html)
- [flexbox-writing-mode-srl-rtl.html](https://wpt.fyi/results/css/css-flexbox/flexbox-writing-mode-srl-rtl.html "css/css-flexbox/flexbox-writing-mode-srl-rtl.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-writing-mode-srl-rtl.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-writing-mode-srl-rtl.html)
- [flexbox_object.html](https://wpt.fyi/results/css/css-flexbox/flexbox_object.html "css/css-flexbox/flexbox_object.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_object.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_object.html)
- [flexbox_writing_mode_vertical_lays_out_contents_from_top_to_bottom.html](https://wpt.fyi/results/css/css-flexbox/flexbox_writing_mode_vertical_lays_out_contents_from_top_to_bottom.html "css/css-flexbox/flexbox_writing_mode_vertical_lays_out_contents_from_top_to_bottom.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_writing_mode_vertical_lays_out_contents_from_top_to_bottom.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_writing_mode_vertical_lays_out_contents_from_top_to_bottom.html)
- [flexbox_computedstyle_flex-direction-column.html](https://wpt.fyi/results/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-direction-column.html "css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-direction-column.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-direction-column.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-direction-column.html)
- [flexbox_computedstyle_flex-direction-column-reverse.html](https://wpt.fyi/results/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-direction-column-reverse.html "css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-direction-column-reverse.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-direction-column-reverse.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-direction-column-reverse.html)
- [flexbox_computedstyle_flex-direction-invalid.html](https://wpt.fyi/results/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-direction-invalid.html "css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-direction-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-direction-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-direction-invalid.html)
- [flexbox_computedstyle_flex-direction-row.html](https://wpt.fyi/results/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-direction-row.html "css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-direction-row.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-direction-row.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-direction-row.html)
- [flexbox_computedstyle_flex-direction-row-reverse.html](https://wpt.fyi/results/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-direction-row-reverse.html "css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-direction-row-reverse.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-direction-row-reverse.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-direction-row-reverse.html)

### 5.2. Flex Line Wrapping: the [flex-wrap property]
Name:

[flex-wrap]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

nowrap
[\|](https://drafts.csswg.org/css-values-4/#comb-one) wrap [\|] wrap-reverse

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

nowrap

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[flex containers](#flex-container)

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

The [flex-wrap](#propdef-flex-wrap) property controls whether the flex
container is
[single-line](#single-line-flex-container) or
[multi-line](#multi-line-flex-container), and the direction of the
[cross-axis](#cross-axis), which
determines the direction new lines are stacked in.

[nowrap]
: The flex container is
 [single-line](#single-line-flex-container).

[wrap]
: The flex container is
 [multi-line](#multi-line-flex-container).

[wrap-reverse]
: Same as
 [wrap](#valdef-flex-wrap-wrap).

For the values that are not
[wrap-reverse](#valdef-flex-wrap-wrap-reverse), the
[cross-start](#cross-start)
direction is equivalent to either the
[inline-start](https://drafts.csswg.org/css-writing-modes-4/#inline-start) or
[block-start](https://drafts.csswg.org/css-writing-modes-4/#block-start) direction of the current [writing
mode](https://drafts.csswg.org/css-writing-modes-4/#writing-mode) (whichever is in the [cross
axis](#cross-axis)) and the
[cross-end](#cross-end) direction is
the opposite direction of [cross-start]. When
[flex-wrap](#propdef-flex-wrap) is
[wrap-reverse], the
[cross-start] and
[cross-end] directions are swapped.

 Depending on the value of
[align-content](#propdef-align-content), the
[wrap-reverse](#valdef-flex-wrap-wrap-reverse) value of
[flex-wrap](#propdef-flex-wrap) can alter the initial scroll position on
[flex containers](#flex-container) that are also [scroll
containers](https://drafts.csswg.org/css-overflow-3/#scroll-container). See [CSS Box Alignment 3 § 5.3 Alignment Overflow and
Scroll
Containers](https://drafts.csswg.org/css-align-3/#overflow-scroll-position).

Tests

- [discrete-no-interpolation.html](https://wpt.fyi/results/css/css-flexbox/animation/discrete-no-interpolation.html "css/css-flexbox/animation/discrete-no-interpolation.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/animation/discrete-no-interpolation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/animation/discrete-no-interpolation.html)
- [flexbox-flex-wrap-default.htm](https://wpt.fyi/results/css/css-flexbox/flexbox-flex-wrap-default.htm "css/css-flexbox/flexbox-flex-wrap-default.htm")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-flex-wrap-default.htm)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-flex-wrap-default.htm)
- [flexbox-flex-wrap-flexing-002.html](https://wpt.fyi/results/css/css-flexbox/flexbox-flex-wrap-flexing-002.html "css/css-flexbox/flexbox-flex-wrap-flexing-002.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-flex-wrap-flexing-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-flex-wrap-flexing-002.html)
- [flexbox-flex-wrap-flexing-003.html](https://wpt.fyi/results/css/css-flexbox/flexbox-flex-wrap-flexing-003.html "css/css-flexbox/flexbox-flex-wrap-flexing-003.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-flex-wrap-flexing-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-flex-wrap-flexing-003.html)
- [flexbox-flex-wrap-flexing.html](https://wpt.fyi/results/css/css-flexbox/flexbox-flex-wrap-flexing.html "css/css-flexbox/flexbox-flex-wrap-flexing.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-flex-wrap-flexing.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-flex-wrap-flexing.html)
- [flexbox-flex-wrap-horiz-001.html](https://wpt.fyi/results/css/css-flexbox/flexbox-flex-wrap-horiz-001.html "css/css-flexbox/flexbox-flex-wrap-horiz-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-flex-wrap-horiz-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-flex-wrap-horiz-001.html)
- [flexbox-flex-wrap-horiz-002.html](https://wpt.fyi/results/css/css-flexbox/flexbox-flex-wrap-horiz-002.html "css/css-flexbox/flexbox-flex-wrap-horiz-002.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-flex-wrap-horiz-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-flex-wrap-horiz-002.html)
- [flexbox-flex-wrap-nowrap.htm](https://wpt.fyi/results/css/css-flexbox/flexbox-flex-wrap-nowrap.htm "css/css-flexbox/flexbox-flex-wrap-nowrap.htm")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-flex-wrap-nowrap.htm)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-flex-wrap-nowrap.htm)
- [flexbox-flex-wrap-vert-001.html](https://wpt.fyi/results/css/css-flexbox/flexbox-flex-wrap-vert-001.html "css/css-flexbox/flexbox-flex-wrap-vert-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-flex-wrap-vert-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-flex-wrap-vert-001.html)
- [flexbox-flex-wrap-vert-002.html](https://wpt.fyi/results/css/css-flexbox/flexbox-flex-wrap-vert-002.html "css/css-flexbox/flexbox-flex-wrap-vert-002.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-flex-wrap-vert-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-flex-wrap-vert-002.html)
- [flexbox-flex-wrap-wrap.htm](https://wpt.fyi/results/css/css-flexbox/flexbox-flex-wrap-wrap.htm "css/css-flexbox/flexbox-flex-wrap-wrap.htm")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-flex-wrap-wrap.htm)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-flex-wrap-wrap.htm)
- [flexbox-flex-wrap-wrap-reverse.htm](https://wpt.fyi/results/css/css-flexbox/flexbox-flex-wrap-wrap-reverse.htm "css/css-flexbox/flexbox-flex-wrap-wrap-reverse.htm")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-flex-wrap-wrap-reverse.htm)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-flex-wrap-wrap-reverse.htm)
- [flexbox_rowspan.html](https://wpt.fyi/results/css/css-flexbox/flexbox_rowspan.html "css/css-flexbox/flexbox_rowspan.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_rowspan.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_rowspan.html)
- [flexbox_rtl-flow.html](https://wpt.fyi/results/css/css-flexbox/flexbox_rtl-flow.html "css/css-flexbox/flexbox_rtl-flow.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_rtl-flow.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_rtl-flow.html)
- [flexbox_rtl-flow-reverse.html](https://wpt.fyi/results/css/css-flexbox/flexbox_rtl-flow-reverse.html "css/css-flexbox/flexbox_rtl-flow-reverse.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_rtl-flow-reverse.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_rtl-flow-reverse.html)
- [flexbox_rtl-order.html](https://wpt.fyi/results/css/css-flexbox/flexbox_rtl-order.html "css/css-flexbox/flexbox_rtl-order.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_rtl-order.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_rtl-order.html)
- [flex-box-wrap.html](https://wpt.fyi/results/css/css-flexbox/flex-box-wrap.html "css/css-flexbox/flex-box-wrap.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-box-wrap.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-box-wrap.html)
- [flexbox_wrap.html](https://wpt.fyi/results/css/css-flexbox/flexbox_wrap.html "css/css-flexbox/flexbox_wrap.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_wrap.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_wrap.html)
- [flexbox_wrap-long.html](https://wpt.fyi/results/css/css-flexbox/flexbox_wrap-long.html "css/css-flexbox/flexbox_wrap-long.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_wrap-long.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_wrap-long.html)
- [flexbox_wrap-reverse.html](https://wpt.fyi/results/css/css-flexbox/flexbox_wrap-reverse.html "css/css-flexbox/flexbox_wrap-reverse.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_wrap-reverse.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_wrap-reverse.html)
- [multi-line-wrap-reverse-column-reverse.html](https://wpt.fyi/results/css/css-flexbox/flex-lines/multi-line-wrap-reverse-column-reverse.html "css/css-flexbox/flex-lines/multi-line-wrap-reverse-column-reverse.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-lines/multi-line-wrap-reverse-column-reverse.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-lines/multi-line-wrap-reverse-column-reverse.html)
- [multi-line-wrap-reverse-row-reverse.html](https://wpt.fyi/results/css/css-flexbox/flex-lines/multi-line-wrap-reverse-row-reverse.html "css/css-flexbox/flex-lines/multi-line-wrap-reverse-row-reverse.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-lines/multi-line-wrap-reverse-row-reverse.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-lines/multi-line-wrap-reverse-row-reverse.html)
- [flexbox_computedstyle_flex-wrap-invalid.html](https://wpt.fyi/results/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-wrap-invalid.html "css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-wrap-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-wrap-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-wrap-invalid.html)
- [flexbox_computedstyle_flex-wrap-nowrap.html](https://wpt.fyi/results/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-wrap-nowrap.html "css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-wrap-nowrap.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-wrap-nowrap.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-wrap-nowrap.html)
- [flexbox_computedstyle_flex-wrap-wrap.html](https://wpt.fyi/results/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-wrap-wrap.html "css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-wrap-wrap.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-wrap-wrap.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-wrap-wrap.html)
- [flexbox_computedstyle_flex-wrap-wrap-reverse.html](https://wpt.fyi/results/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-wrap-wrap-reverse.html "css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-wrap-wrap-reverse.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-wrap-wrap-reverse.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-wrap-wrap-reverse.html)
- [multiline-min-preferred-width.html](https://wpt.fyi/results/css/css-flexbox/multiline-min-preferred-width.html "css/css-flexbox/multiline-min-preferred-width.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/multiline-min-preferred-width.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/multiline-min-preferred-width.html)
- [multiline-reverse-wrap-baseline.html](https://wpt.fyi/results/css/css-flexbox/multiline-reverse-wrap-baseline.html "css/css-flexbox/multiline-reverse-wrap-baseline.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/multiline-reverse-wrap-baseline.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/multiline-reverse-wrap-baseline.html)

### 5.3. Flex Direction and Wrap: the [flex-flow shorthand]
Name:

[flex-flow]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<\'flex-direction\'\>](#propdef-flex-direction)
[\|\|](https://drafts.csswg.org/css-values-4/#comb-any)
[\<\'flex-wrap\'\>](#propdef-flex-wrap)

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

Tests

- [box-sizing-001.html](https://wpt.fyi/results/css/css-flexbox/box-sizing-001.html "css/css-flexbox/box-sizing-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/box-sizing-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/box-sizing-001.html)
- [button-column-wrap-crash.html](https://wpt.fyi/results/css/css-flexbox/button-column-wrap-crash.html "css/css-flexbox/button-column-wrap-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/button-column-wrap-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/button-column-wrap-crash.html)
- [column-intrinsic-size-aspect-ratio-crash.html](https://wpt.fyi/results/css/css-flexbox/column-intrinsic-size-aspect-ratio-crash.html "css/css-flexbox/column-intrinsic-size-aspect-ratio-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/column-intrinsic-size-aspect-ratio-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/column-intrinsic-size-aspect-ratio-crash.html)
- [css-flexbox-row.html](https://wpt.fyi/results/css/css-flexbox/css-flexbox-row.html "css/css-flexbox/css-flexbox-row.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/css-flexbox-row.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/css-flexbox-row.html)
- [css-flexbox-row-reverse.html](https://wpt.fyi/results/css/css-flexbox/css-flexbox-row-reverse.html "css/css-flexbox/css-flexbox-row-reverse.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/css-flexbox-row-reverse.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/css-flexbox-row-reverse.html)
- [css-flexbox-row-reverse-wrap.html](https://wpt.fyi/results/css/css-flexbox/css-flexbox-row-reverse-wrap.html "css/css-flexbox/css-flexbox-row-reverse-wrap.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/css-flexbox-row-reverse-wrap.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/css-flexbox-row-reverse-wrap.html)
- [css-flexbox-row-reverse-wrap-reverse.html](https://wpt.fyi/results/css/css-flexbox/css-flexbox-row-reverse-wrap-reverse.html "css/css-flexbox/css-flexbox-row-reverse-wrap-reverse.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/css-flexbox-row-reverse-wrap-reverse.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/css-flexbox-row-reverse-wrap-reverse.html)
- [css-flexbox-row-wrap.html](https://wpt.fyi/results/css/css-flexbox/css-flexbox-row-wrap.html "css/css-flexbox/css-flexbox-row-wrap.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/css-flexbox-row-wrap.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/css-flexbox-row-wrap.html)
- [css-flexbox-row-wrap-reverse.html](https://wpt.fyi/results/css/css-flexbox/css-flexbox-row-wrap-reverse.html "css/css-flexbox/css-flexbox-row-wrap-reverse.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/css-flexbox-row-wrap-reverse.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/css-flexbox-row-wrap-reverse.html)
- [css-flexbox-test1.html](https://wpt.fyi/results/css/css-flexbox/css-flexbox-test1.html "css/css-flexbox/css-flexbox-test1.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/css-flexbox-test1.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/css-flexbox-test1.html)
- [flexbox-flex-direction-column.htm](https://wpt.fyi/results/css/css-flexbox/flexbox-flex-direction-column.htm "css/css-flexbox/flexbox-flex-direction-column.htm")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-flex-direction-column.htm)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-flex-direction-column.htm)
- [flexbox-flex-direction-column-percentage-ignored.html](https://wpt.fyi/results/css/css-flexbox/flexbox-flex-direction-column-percentage-ignored.html "css/css-flexbox/flexbox-flex-direction-column-percentage-ignored.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-flex-direction-column-percentage-ignored.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-flex-direction-column-percentage-ignored.html)
- [flexbox-flex-direction-column-reverse.htm](https://wpt.fyi/results/css/css-flexbox/flexbox-flex-direction-column-reverse.htm "css/css-flexbox/flexbox-flex-direction-column-reverse.htm")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-flex-direction-column-reverse.htm)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-flex-direction-column-reverse.htm)
- [flexbox-flex-direction-default.htm](https://wpt.fyi/results/css/css-flexbox/flexbox-flex-direction-default.htm "css/css-flexbox/flexbox-flex-direction-default.htm")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-flex-direction-default.htm)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-flex-direction-default.htm)
- [flexbox-flex-direction-row.htm](https://wpt.fyi/results/css/css-flexbox/flexbox-flex-direction-row.htm "css/css-flexbox/flexbox-flex-direction-row.htm")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-flex-direction-row.htm)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-flex-direction-row.htm)
- [flexbox-flex-direction-row-reverse.htm](https://wpt.fyi/results/css/css-flexbox/flexbox-flex-direction-row-reverse.htm "css/css-flexbox/flexbox-flex-direction-row-reverse.htm")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-flex-direction-row-reverse.htm)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-flex-direction-row-reverse.htm)
- [flex-direction-column-001-visual.html (visual test)
 ][[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-direction-column-001-visual.html)
- [flex-direction-column.html](https://wpt.fyi/results/css/css-flexbox/flex-direction-column.html "css/css-flexbox/flex-direction-column.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-direction-column.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-direction-column.html)
- [flex-direction-column-overlap-001.html](https://wpt.fyi/results/css/css-flexbox/flex-direction-column-overlap-001.html "css/css-flexbox/flex-direction-column-overlap-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-direction-column-overlap-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-direction-column-overlap-001.html)
- [flex-direction-column-reverse-001-visual.html (visual test)
 ][[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-direction-column-reverse-001-visual.html)
- [flex-direction-column-reverse-002-visual.html (visual test)
 ][[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-direction-column-reverse-002-visual.html)
- [flex-direction-column-reverse.html](https://wpt.fyi/results/css/css-flexbox/flex-direction-column-reverse.html "css/css-flexbox/flex-direction-column-reverse.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-direction-column-reverse.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-direction-column-reverse.html)
- [flex-direction.html](https://wpt.fyi/results/css/css-flexbox/flex-direction.html "css/css-flexbox/flex-direction.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-direction.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-direction.html)
- [flex-direction-modify.html](https://wpt.fyi/results/css/css-flexbox/flex-direction-modify.html "css/css-flexbox/flex-direction-modify.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-direction-modify.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-direction-modify.html)
- [flex-direction-row-001-visual.html (visual test)
 ][[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-direction-row-001-visual.html)
- [flex-direction-row-002-visual.html (visual test)
 ][[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-direction-row-002-visual.html)
- [flex-direction-row-reverse-001-visual.html (visual test)
 ][[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-direction-row-reverse-001-visual.html)
- [flex-direction-row-reverse-002-visual.html (visual test)
 ][[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-direction-row-reverse-002-visual.html)
- [flex-direction-row-reverse.html](https://wpt.fyi/results/css/css-flexbox/flex-direction-row-reverse.html "css/css-flexbox/flex-direction-row-reverse.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-direction-row-reverse.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-direction-row-reverse.html)
- [flex-direction-row-vertical.html](https://wpt.fyi/results/css/css-flexbox/flex-direction-row-vertical.html "css/css-flexbox/flex-direction-row-vertical.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-direction-row-vertical.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-direction-row-vertical.html)
- [flex-direction-with-element-insert.html](https://wpt.fyi/results/css/css-flexbox/flex-direction-with-element-insert.html "css/css-flexbox/flex-direction-with-element-insert.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-direction-with-element-insert.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-direction-with-element-insert.html)
- [flexbox-flex-flow-001.html](https://wpt.fyi/results/css/css-flexbox/flexbox-flex-flow-001.html "css/css-flexbox/flexbox-flex-flow-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-flex-flow-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-flex-flow-001.html)
- [flexbox-flex-flow-002.html](https://wpt.fyi/results/css/css-flexbox/flexbox-flex-flow-002.html "css/css-flexbox/flexbox-flex-flow-002.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-flex-flow-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-flex-flow-002.html)
- [flexbox_flow-column-reverse-wrap.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flow-column-reverse-wrap.html "css/css-flexbox/flexbox_flow-column-reverse-wrap.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flow-column-reverse-wrap.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flow-column-reverse-wrap.html)
- [flexbox_flow-column-reverse-wrap-reverse.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flow-column-reverse-wrap-reverse.html "css/css-flexbox/flexbox_flow-column-reverse-wrap-reverse.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flow-column-reverse-wrap-reverse.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flow-column-reverse-wrap-reverse.html)
- [flexbox_flow-column-wrap.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flow-column-wrap.html "css/css-flexbox/flexbox_flow-column-wrap.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flow-column-wrap.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flow-column-wrap.html)
- [flexbox_flow-column-wrap-reverse.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flow-column-wrap-reverse.html "css/css-flexbox/flexbox_flow-column-wrap-reverse.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flow-column-wrap-reverse.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flow-column-wrap-reverse.html)
- [flexbox_flow-row-wrap.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flow-row-wrap.html "css/css-flexbox/flexbox_flow-row-wrap.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flow-row-wrap.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flow-row-wrap.html)
- [flexbox_flow-row-wrap-reverse.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flow-row-wrap-reverse.html "css/css-flexbox/flexbox_flow-row-wrap-reverse.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flow-row-wrap-reverse.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flow-row-wrap-reverse.html)
- [flex-flow-001.html](https://wpt.fyi/results/css/css-flexbox/flex-flow-001.html "css/css-flexbox/flex-flow-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-flow-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-flow-001.html)
- [flex-flow-002.html](https://wpt.fyi/results/css/css-flexbox/flex-flow-002.html "css/css-flexbox/flex-flow-002.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-flow-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-flow-002.html)
- [flex-flow-003.html](https://wpt.fyi/results/css/css-flexbox/flex-flow-003.html "css/css-flexbox/flex-flow-003.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-flow-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-flow-003.html)
- [flex-flow-004.html](https://wpt.fyi/results/css/css-flexbox/flex-flow-004.html "css/css-flexbox/flex-flow-004.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-flow-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-flow-004.html)
- [flex-flow-005.html](https://wpt.fyi/results/css/css-flexbox/flex-flow-005.html "css/css-flexbox/flex-flow-005.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-flow-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-flow-005.html)
- [flex-flow-006.html](https://wpt.fyi/results/css/css-flexbox/flex-flow-006.html "css/css-flexbox/flex-flow-006.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-flow-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-flow-006.html)
- [flex-flow-007.html](https://wpt.fyi/results/css/css-flexbox/flex-flow-007.html "css/css-flexbox/flex-flow-007.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-flow-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-flow-007.html)
- [flex-flow-008.html](https://wpt.fyi/results/css/css-flexbox/flex-flow-008.html "css/css-flexbox/flex-flow-008.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-flow-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-flow-008.html)
- [flex-flow-009.html](https://wpt.fyi/results/css/css-flexbox/flex-flow-009.html "css/css-flexbox/flex-flow-009.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-flow-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-flow-009.html)
- [flex-flow-010.html](https://wpt.fyi/results/css/css-flexbox/flex-flow-010.html "css/css-flexbox/flex-flow-010.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-flow-010.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-flow-010.html)
- [flex-flow-011.html](https://wpt.fyi/results/css/css-flexbox/flex-flow-011.html "css/css-flexbox/flex-flow-011.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-flow-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-flow-011.html)
- [flex-flow-012.html](https://wpt.fyi/results/css/css-flexbox/flex-flow-012.html "css/css-flexbox/flex-flow-012.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-flow-012.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-flow-012.html)
- [flex-flow-013.html](https://wpt.fyi/results/css/css-flexbox/flex-flow-013.html "css/css-flexbox/flex-flow-013.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-flow-013.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-flow-013.html)
- [flex-wrap-002.html](https://wpt.fyi/results/css/css-flexbox/flex-wrap-002.html "css/css-flexbox/flex-wrap-002.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-wrap-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-wrap-002.html)
- [flex-wrap-003.html](https://wpt.fyi/results/css/css-flexbox/flex-wrap-003.html "css/css-flexbox/flex-wrap-003.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-wrap-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-wrap-003.html)
- [flex-wrap-004.html](https://wpt.fyi/results/css/css-flexbox/flex-wrap-004.html "css/css-flexbox/flex-wrap-004.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-wrap-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-wrap-004.html)
- [flex-wrap-005.html](https://wpt.fyi/results/css/css-flexbox/flex-wrap-005.html "css/css-flexbox/flex-wrap-005.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-wrap-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-wrap-005.html)
- [flex-wrap-006.html](https://wpt.fyi/results/css/css-flexbox/flex-wrap-006.html "css/css-flexbox/flex-wrap-006.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-wrap-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-wrap-006.html)
- [flexbox_computedstyle_flex-flow-column.html](https://wpt.fyi/results/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-flow-column.html "css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-flow-column.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-flow-column.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-flow-column.html)
- [flexbox_computedstyle_flex-flow-column-nowrap.html](https://wpt.fyi/results/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-flow-column-nowrap.html "css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-flow-column-nowrap.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-flow-column-nowrap.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-flow-column-nowrap.html)
- [flexbox_computedstyle_flex-flow-column-reverse.html](https://wpt.fyi/results/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-flow-column-reverse.html "css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-flow-column-reverse.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-flow-column-reverse.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-flow-column-reverse.html)
- [flexbox_computedstyle_flex-flow-column-reverse-nowrap.html](https://wpt.fyi/results/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-flow-column-reverse-nowrap.html "css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-flow-column-reverse-nowrap.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-flow-column-reverse-nowrap.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-flow-column-reverse-nowrap.html)
- [flexbox_computedstyle_flex-flow-column-reverse-wrap.html](https://wpt.fyi/results/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-flow-column-reverse-wrap.html "css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-flow-column-reverse-wrap.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-flow-column-reverse-wrap.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-flow-column-reverse-wrap.html)
- [flexbox_computedstyle_flex-flow-column-wrap.html](https://wpt.fyi/results/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-flow-column-wrap.html "css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-flow-column-wrap.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-flow-column-wrap.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-flow-column-wrap.html)
- [flexbox_computedstyle_flex-flow-column-wrap-reverse.html](https://wpt.fyi/results/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-flow-column-wrap-reverse.html "css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-flow-column-wrap-reverse.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-flow-column-wrap-reverse.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-flow-column-wrap-reverse.html)
- [flexbox_computedstyle_flex-flow-nowrap.html](https://wpt.fyi/results/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-flow-nowrap.html "css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-flow-nowrap.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-flow-nowrap.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-flow-nowrap.html)
- [flexbox_computedstyle_flex-flow-row.html](https://wpt.fyi/results/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-flow-row.html "css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-flow-row.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-flow-row.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-flow-row.html)
- [flexbox_computedstyle_flex-flow-row-nowrap.html](https://wpt.fyi/results/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-flow-row-nowrap.html "css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-flow-row-nowrap.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-flow-row-nowrap.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-flow-row-nowrap.html)
- [flexbox_computedstyle_flex-flow-row-reverse.html](https://wpt.fyi/results/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-flow-row-reverse.html "css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-flow-row-reverse.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-flow-row-reverse.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-flow-row-reverse.html)
- [flexbox_computedstyle_flex-flow-row-reverse-nowrap.html](https://wpt.fyi/results/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-flow-row-reverse-nowrap.html "css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-flow-row-reverse-nowrap.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-flow-row-reverse-nowrap.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-flow-row-reverse-nowrap.html)
- [flexbox_computedstyle_flex-flow-row-reverse-wrap.html](https://wpt.fyi/results/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-flow-row-reverse-wrap.html "css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-flow-row-reverse-wrap.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-flow-row-reverse-wrap.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-flow-row-reverse-wrap.html)
- [flexbox_computedstyle_flex-flow-row-reverse-wrap-reverse.html](https://wpt.fyi/results/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-flow-row-reverse-wrap-reverse.html "css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-flow-row-reverse-wrap-reverse.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-flow-row-reverse-wrap-reverse.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-flow-row-reverse-wrap-reverse.html)
- [flexbox_computedstyle_flex-flow-row-wrap.html](https://wpt.fyi/results/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-flow-row-wrap.html "css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-flow-row-wrap.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-flow-row-wrap.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-flow-row-wrap.html)
- [flexbox_computedstyle_flex-flow-row-wrap-reverse.html](https://wpt.fyi/results/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-flow-row-wrap-reverse.html "css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-flow-row-wrap-reverse.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-flow-row-wrap-reverse.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-flow-row-wrap-reverse.html)
- [flexbox_computedstyle_flex-flow-wrap.html](https://wpt.fyi/results/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-flow-wrap.html "css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-flow-wrap.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-flow-wrap.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-flow-wrap.html)
- [multiline-column-max-height.html](https://wpt.fyi/results/css/css-flexbox/multiline-column-max-height.html "css/css-flexbox/multiline-column-max-height.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/multiline-column-max-height.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/multiline-column-max-height.html)
- [flex-direction-computed.html](https://wpt.fyi/results/css/css-flexbox/parsing/flex-direction-computed.html "css/css-flexbox/parsing/flex-direction-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/parsing/flex-direction-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/parsing/flex-direction-computed.html)
- [flex-direction-invalid.html](https://wpt.fyi/results/css/css-flexbox/parsing/flex-direction-invalid.html "css/css-flexbox/parsing/flex-direction-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/parsing/flex-direction-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/parsing/flex-direction-invalid.html)
- [flex-direction-valid.html](https://wpt.fyi/results/css/css-flexbox/parsing/flex-direction-valid.html "css/css-flexbox/parsing/flex-direction-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/parsing/flex-direction-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/parsing/flex-direction-valid.html)
- [flex-flow-computed.html](https://wpt.fyi/results/css/css-flexbox/parsing/flex-flow-computed.html "css/css-flexbox/parsing/flex-flow-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/parsing/flex-flow-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/parsing/flex-flow-computed.html)
- [flex-flow-invalid.html](https://wpt.fyi/results/css/css-flexbox/parsing/flex-flow-invalid.html "css/css-flexbox/parsing/flex-flow-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/parsing/flex-flow-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/parsing/flex-flow-invalid.html)
- [flex-flow-shorthand.html](https://wpt.fyi/results/css/css-flexbox/parsing/flex-flow-shorthand.html "css/css-flexbox/parsing/flex-flow-shorthand.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/parsing/flex-flow-shorthand.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/parsing/flex-flow-shorthand.html)
- [flex-flow-valid.html](https://wpt.fyi/results/css/css-flexbox/parsing/flex-flow-valid.html "css/css-flexbox/parsing/flex-flow-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/parsing/flex-flow-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/parsing/flex-flow-valid.html)
- [flex-wrap-computed.html](https://wpt.fyi/results/css/css-flexbox/parsing/flex-wrap-computed.html "css/css-flexbox/parsing/flex-wrap-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/parsing/flex-wrap-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/parsing/flex-wrap-computed.html)
- [flex-wrap-invalid.html](https://wpt.fyi/results/css/css-flexbox/parsing/flex-wrap-invalid.html "css/css-flexbox/parsing/flex-wrap-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/parsing/flex-wrap-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/parsing/flex-wrap-invalid.html)
- [flex-wrap-valid.html](https://wpt.fyi/results/css/css-flexbox/parsing/flex-wrap-valid.html "css/css-flexbox/parsing/flex-wrap-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/parsing/flex-wrap-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/parsing/flex-wrap-valid.html)

The [flex-flow](#propdef-flex-flow) property is a shorthand for setting the
[flex-direction](#propdef-flex-direction) and
[flex-wrap](#propdef-flex-wrap) properties, which together define the
flex container's main and cross axes.

Some examples of valid flows in an
English (left-to-right, horizontal writing mode) document:

```
div { flex-flow: row; }
/* Initial value. Main-axis is inline, no wrapping.
 (Items will either shrink to fit or overflow.) */
```

!(images/flex-flow1.svg){height="46" width="205"}

```
div { flex-flow: column wrap; }
/* Main-axis is block-direction (top to bottom)
 and lines wrap in the inline direction (rightwards). */
```

!(images/flex-flow2.svg){height="160" width="89"}

```
div { flex-flow: row-reverse wrap-reverse; }
/* Main-axis is the opposite of inline direction
 (right to left). New lines wrap upwards. */
```

!(images/flex-flow3.svg){height="89" width="160"}

Note that the
[flex-flow](#propdef-flex-flow) directions are [writing
mode](https://drafts.csswg.org/css-writing-modes-4/#writing-mode) sensitive. In vertical Japanese, for example, a
[row](#valdef-flex-direction-row) flex container lays out its contents from top to
bottom, as seen in this example:

English

Japanese

```
flex-flow: row wrap;
writing-mode: horizontal-tb;
```

```
flex-flow: row wrap;
writing-mode: vertical-rl;
```

!(images/flex-flow-english.svg){height="89" width="160"}

!(images/flex-flow-japanese.svg){height="160" width="89"}

### [5.4. ][ Reordering and Accessibility: the [order](https://drafts.csswg.org/css-display-4/#propdef-order) property]
[Flex items](#flex-item) are, by
default, displayed and laid out in the same order as they appear in the
source document, which represents their logical ordering. This same
order is used in rendering to non-visual media (such as
[speech](https://www.w3.org/TR/css-speech/)), in the default traversal
order of sequential navigation modes (such as cycling through links, see
e.g.
[`tabindex`](https://html.spec.whatwg.org/multipage/interaction.html#attr-tabindex)
[\[HTML\]](#biblio-html "HTML Standard")), and when
content is represented in non-CSS UAs.

The
[order](https://drafts.csswg.org/css-display-4/#propdef-order) property can be used to change flex
items' ordering, laying them out in [order-modified document
order](https://drafts.csswg.org/css-display-4/#order-modified-document-order) instead, in order to make their spatial arrangement on
the 2D visual canvas differ from their logical order in linear
presentations such as speech and sequential navigation. See [CSS Display
3 § 3 Display Order: the order
property](https://drafts.csswg.org/css-display-3/#order-property).
[\[CSS-DISPLAY-3\]](#biblio-css-display-3 "CSS Display Module Level 3")

 Since visual perception is two-dimensional and
non-linear, the desired box order is not always the same logical order
used by non-visual media and non-CSS UAs.

**Authors *must* use
[order](https://drafts.csswg.org/css-display-4/#propdef-order) only for visual, not logical,
reordering of content. Style sheets that use
[order] to perform logical reordering
are non-conforming.**

Many web pages have a similar shape in
the markup, with a header on top, a footer on bottom, and then a content
area and one or two additional columns in the middle. Generally, it's
desirable that the content come first in the page's source code, before
the additional columns. However, this makes many common designs, such as
simply having the additional columns on the left and the content area on
the right, difficult to achieve. This has been addressed in many ways
over the years, often going by the name \"Holy Grail Layout\" when there
are two additional columns.
[order](https://drafts.csswg.org/css-display-4/#propdef-order) makes this trivial. For example,
take the following sketch of a page's code and desired layout:

::::: code-and-figure

```
<!DOCTYPE html>
<header>...</header>
<main>
 <article>...</article>
 <nav>...</nav>
 <aside>...</aside>
</main>
<footer>...</footer>
```

![In this page the header is at the top and the footer at the bottom,
but the article is in the center, flanked by the nav on the right and
the aside on the left.](images/flex-order-page.svg){height="360"
width="400"}

This layout can be easily achieved with flex layout:

```
main { display: flex; }
main > article { order: 2; min-width: 12em; flex:1; }
main > nav { order: 1; width: 200px; }
main > aside { order: 3; width: 200px; }
```

As an added bonus, the columns will all be
[equal-height](#valdef-align-items-stretch) by default, and the main content will be as wide
as necessary to fill the screen. Additionally, this can then be combined
with media queries to switch to an all-vertical layout on narrow
screens:

```
@media all and (max-width: 600px) {
 /* Too narrow to support three columns */
 main { flex-flow: column; }
 main > article, main > nav, main > aside {
 /* Return them to document order */
 order: 0; width: auto;
 }
}
```

[(Further use of multi-line flex containers to achieve even more
intelligent wrapping left as an exercise for the reader.)]

## 6. Flex Lines

[Flex items](#flex-item) in a
[flex container](#flex-container) are laid out and aligned within [flex lines], hypothetical
containers used for grouping and alignment by the layout algorithm. A
flex container can be either
[single-line](#single-line-flex-container) or
[multi-line](#multi-line-flex-container), depending on the
[flex-wrap](#propdef-flex-wrap) property:

- A [single-line flex container] (i.e.
 one with [flex-wrap:
 nowrap](#propdef-flex-wrap)) lays out all of its children in a single line,
 even if that would cause its contents to overflow.

- A [multi-line flex container] (i.e. one
 with [flex-wrap: wrap](#propdef-flex-wrap) or [flex-wrap:
 wrap-reverse]) breaks its [flex
 items](#flex-item) across
 multiple lines, similar to how text is broken onto a new line when it
 gets too wide to fit on the existing line. When additional lines are
 created, they are stacked in the flex container along the [cross
 axis](#cross-axis) according to
 the [flex-wrap] property.
 Every line contains at least one [flex item],
 unless the flex container itself is completely empty.

This example shows four buttons that
do not fit side-by-side horizontally, and therefore will wrap into
multiple lines.

```
#flex {
 display: flex;
 flex-flow: row wrap;
 width: 300px;
}
.item {
 width: 80px;
}
```

```
<div id="flex">
 <div class="item">1</div>
 <div class="item">2</div>
 <div class="item">3</div>
 <div class="item">4</div>
</div>
```

Since the container is 300px wide, only three of the items fit onto a
single line. They take up 240px, with 60px left over of remaining space.
Because the [flex-flow](#propdef-flex-flow) property specifies a
[multi-line](#multi-line-flex-container) flex container (due to the
[wrap](#valdef-flex-wrap-wrap) keyword appearing in its value), the flex container
will create an additional line to contain the last item.

![An example rendering of the multi-line flex
container.](images/multiline-no-flex.svg){height="89" width="300"}

Once content is broken into lines, each line is laid out independently;
flexible lengths and the
[justify-content](#propdef-justify-content) and
[align-self](#propdef-align-self) properties only consider the items on a
single line at a time.

In a
[multi-line](#multi-line-flex-container) [flex
container](#flex-container)
(even one with only a single line), the [cross
size](#cross-size) of each line is
the minimum size necessary to contain the [flex
items](#flex-item) on the line
(after alignment due to
[align-self](#propdef-align-self)), and the lines are aligned within the
flex container with the
[align-content](#propdef-align-content) property. In a
[single-line](#single-line-flex-container) [flex container], the [cross
size] of the line is the [cross
size] of the flex container, and
[align-content] has no
effect. The [main size](#main-size)
of a line is always the same as the [main size] of
the flex container's content box.

Tests

- [align-content-001.htm](https://wpt.fyi/results/css/css-flexbox/align-content-001.htm "css/css-flexbox/align-content-001.htm")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/align-content-001.htm)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/align-content-001.htm)
- [align-content-002.htm](https://wpt.fyi/results/css/css-flexbox/align-content-002.htm "css/css-flexbox/align-content-002.htm")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/align-content-002.htm)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/align-content-002.htm)
- [align-content-003.htm](https://wpt.fyi/results/css/css-flexbox/align-content-003.htm "css/css-flexbox/align-content-003.htm")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/align-content-003.htm)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/align-content-003.htm)
- [align-content-004.htm](https://wpt.fyi/results/css/css-flexbox/align-content-004.htm "css/css-flexbox/align-content-004.htm")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/align-content-004.htm)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/align-content-004.htm)
- [align-content-005.htm](https://wpt.fyi/results/css/css-flexbox/align-content-005.htm "css/css-flexbox/align-content-005.htm")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/align-content-005.htm)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/align-content-005.htm)
- [align-content-006.htm](https://wpt.fyi/results/css/css-flexbox/align-content-006.htm "css/css-flexbox/align-content-006.htm")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/align-content-006.htm)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/align-content-006.htm)
- [align-content-007.htm](https://wpt.fyi/results/css/css-flexbox/align-content-007.htm "css/css-flexbox/align-content-007.htm")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/align-content-007.htm)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/align-content-007.htm)
- [flex-wrap-column-grow.html](https://wpt.fyi/results/css/css-flexbox/flex-wrap-column-grow.html "css/css-flexbox/flex-wrap-column-grow.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-wrap-column-grow.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-wrap-column-grow.html)
- [flexbox-lines-must-be-stretched-by-default.html](https://wpt.fyi/results/css/css-flexbox/flexbox-lines-must-be-stretched-by-default.html "css/css-flexbox/flexbox-lines-must-be-stretched-by-default.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-lines-must-be-stretched-by-default.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-lines-must-be-stretched-by-default.html)

Here's the same example as the
previous, except that the flex items have all been given [flex:
auto](#propdef-flex).
The first line has 60px of remaining space, and all of the items have
the same flexibility, so each of the three items on that line will
receive 20px of extra width, each ending up 100px wide. The remaining
item is on a line of its own and will stretch to the entire width of the
line, i.e. 300px.

![A rendering of the same as above, but with the items all given [flex:
auto](#propdef-flex).](images/multiline-flex.svg){height="89"
width="300"}

## 7. Flexibility

The defining aspect of flex layout is the ability to make the [flex
items](#flex-item) "flex",
altering their width/height to fill the available space in the [main
dimension](#main-dimension).
This is done with the [flex](#propdef-flex) property. A flex container distributes
free space to its items (proportional to their [flex grow
factor](#flex-flex-grow-factor)) to fill the container, or shrinks them (proportional
to their [flex shrink
factor](#flex-flex-shrink-factor)) to prevent overflow.

A [flex item](#flex-item) is
[fully inflexible] if both its
[flex-grow](#propdef-flex-grow) and
[flex-shrink](#propdef-flex-shrink) values are zero, and
[flexible]
otherwise.

Tests

- [flex-factor-less-than-one.html](https://wpt.fyi/results/css/css-flexbox/flex-factor-less-than-one.html "css/css-flexbox/flex-factor-less-than-one.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-factor-less-than-one.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-factor-less-than-one.html)

### 7.1. The [flex Shorthand]
Name:

[flex]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

none
[\|](https://drafts.csswg.org/css-values-4/#comb-one) \[
[\<\'flex-grow\'\>](#propdef-flex-grow)
[\<\'flex-shrink\'\>](#propdef-flex-shrink)[?](https://drafts.csswg.org/css-values-4/#mult-opt)
[\|\|](https://drafts.csswg.org/css-values-4/#comb-any)
[\<\'flex-basis\'\>](#propdef-flex-basis) \]

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

0 1 auto

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[flex items](#flex-item)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

see individual properties

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

see individual properties

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value type

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

Tests

- [flexbox-dyn-resize-001.html](https://wpt.fyi/results/css/css-flexbox/flexbox-dyn-resize-001.html "css/css-flexbox/flexbox-dyn-resize-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-dyn-resize-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-dyn-resize-001.html)
- [flex-item-max-width-min-content.html](https://wpt.fyi/results/css/css-flexbox/flex-item-max-width-min-content.html "css/css-flexbox/flex-item-max-width-min-content.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-item-max-width-min-content.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-item-max-width-min-content.html)
- [flex-item-min-height-min-content.html](https://wpt.fyi/results/css/css-flexbox/flex-item-min-height-min-content.html "css/css-flexbox/flex-item-min-height-min-content.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-item-min-height-min-content.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-item-min-height-min-content.html)
- [flex-item-min-width-min-content.html](https://wpt.fyi/results/css/css-flexbox/flex-item-min-width-min-content.html "css/css-flexbox/flex-item-min-width-min-content.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-item-min-width-min-content.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-item-min-width-min-content.html)
- [flex-shorthand-calc.html](https://wpt.fyi/results/css/css-flexbox/flex-shorthand-calc.html "css/css-flexbox/flex-shorthand-calc.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-shorthand-calc.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-shorthand-calc.html)
- [flex-computed.html](https://wpt.fyi/results/css/css-flexbox/parsing/flex-computed.html "css/css-flexbox/parsing/flex-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/parsing/flex-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/parsing/flex-computed.html)
- [flex-invalid.html](https://wpt.fyi/results/css/css-flexbox/parsing/flex-invalid.html "css/css-flexbox/parsing/flex-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/parsing/flex-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/parsing/flex-invalid.html)
- [flex-shorthand.html](https://wpt.fyi/results/css/css-flexbox/parsing/flex-shorthand.html "css/css-flexbox/parsing/flex-shorthand.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/parsing/flex-shorthand.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/parsing/flex-shorthand.html)
- [flex-valid.html](https://wpt.fyi/results/css/css-flexbox/parsing/flex-valid.html "css/css-flexbox/parsing/flex-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/parsing/flex-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/parsing/flex-valid.html)

The [flex](#propdef-flex) property specifies the components of a flexible
size: the [flex factors]
([grow](#flex-flex-grow-factor) and
[shrink](#flex-flex-shrink-factor)) and the [flex
basis](#flex-flex-basis). When
a box is a [flex item](#flex-item), [flex] is consulted
*instead of* the [main size
property](#main-size-property) to determine the [main
size](#main-size) of the box. If a
box is not a [flex item],
[flex] has no effect.

 The initial values of the
[flex](#propdef-flex) longhands are equivalent to [flex: 0 1
auto](#flex-initial). This differs from their defaults when
omitted in the [flex] shorthand
(effectively [1 1 0px]) so that the [flex] shorthand can better accommodate [the most common
cases](#flex-common).

[[\<\'flex-grow\'\>](#propdef-flex-grow)]

: This [\<number
 \[0,∞\]\>](https://drafts.csswg.org/css-values-4/#number-value) component sets
 [flex-grow](#propdef-flex-grow) [longhand](#flex-components) and
 specifies the [flex grow factor], which
 determines how much the [flex item](#flex-item) will grow relative to the rest of the [flex
 items] in the flex container when positive
 free space is distributed. When omitted, it is set to [1].

 Tests

 - [flex-grow-interpolation.html](https://wpt.fyi/results/css/css-flexbox/animation/flex-grow-interpolation.html "css/css-flexbox/animation/flex-grow-interpolation.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/animation/flex-grow-interpolation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/animation/flex-grow-interpolation.html)
 - [flex-001.htm](https://wpt.fyi/results/css/css-flexbox/flex-001.htm "css/css-flexbox/flex-001.htm")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-001.htm)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-001.htm)
 - [flex-003.htm](https://wpt.fyi/results/css/css-flexbox/flex-003.htm "css/css-flexbox/flex-003.htm")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-003.htm)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-003.htm)
 - [flex-grow-001.xht](https://wpt.fyi/results/css/css-flexbox/flex-grow-001.xht "css/css-flexbox/flex-grow-001.xht")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-grow-001.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-grow-001.xht)
 - [flex-grow-002.html](https://wpt.fyi/results/css/css-flexbox/flex-grow-002.html "css/css-flexbox/flex-grow-002.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-grow-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-grow-002.html)
 - [flex-grow-003.html](https://wpt.fyi/results/css/css-flexbox/flex-grow-003.html "css/css-flexbox/flex-grow-003.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-grow-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-grow-003.html)
 - [flex-grow-004.html](https://wpt.fyi/results/css/css-flexbox/flex-grow-004.html "css/css-flexbox/flex-grow-004.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-grow-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-grow-004.html)
 - [flex-grow-005.html](https://wpt.fyi/results/css/css-flexbox/flex-grow-005.html "css/css-flexbox/flex-grow-005.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-grow-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-grow-005.html)
 - [flex-grow-006.html](https://wpt.fyi/results/css/css-flexbox/flex-grow-006.html "css/css-flexbox/flex-grow-006.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-grow-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-grow-006.html)
 - [flex-grow-007.html](https://wpt.fyi/results/css/css-flexbox/flex-grow-007.html "css/css-flexbox/flex-grow-007.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-grow-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-grow-007.html)
 - [flex-grow-008.html](https://wpt.fyi/results/css/css-flexbox/flex-grow-008.html "css/css-flexbox/flex-grow-008.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-grow-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-grow-008.html)
 - [flexbox_flex-natural.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-natural.html "css/css-flexbox/flexbox_flex-natural.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-natural.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-natural.html)
 - [flexbox_flex-natural-mixed-basis-auto.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-natural-mixed-basis-auto.html "css/css-flexbox/flexbox_flex-natural-mixed-basis-auto.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-natural-mixed-basis-auto.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-natural-mixed-basis-auto.html)
 - [flexbox_flex-natural-mixed-basis.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-natural-mixed-basis.html "css/css-flexbox/flexbox_flex-natural-mixed-basis.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-natural-mixed-basis.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-natural-mixed-basis.html)
 - [flexbox_flex-natural-variable-auto-basis.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-natural-variable-auto-basis.html "css/css-flexbox/flexbox_flex-natural-variable-auto-basis.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-natural-variable-auto-basis.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-natural-variable-auto-basis.html)
 - [flexbox_flex-natural-variable-zero-basis.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-natural-variable-zero-basis.html "css/css-flexbox/flexbox_flex-natural-variable-zero-basis.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-natural-variable-zero-basis.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-natural-variable-zero-basis.html)
 - [flexbox_flex-none.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-none.html "css/css-flexbox/flexbox_flex-none.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-none.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-none.html)
 - [flexbox_flex-none-wrappable-content.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-none-wrappable-content.html "css/css-flexbox/flexbox_flex-none-wrappable-content.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-none-wrappable-content.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-none-wrappable-content.html)
 - [flex-factor-less-than-one.html](https://wpt.fyi/results/css/css-flexbox/flex-factor-less-than-one.html "css/css-flexbox/flex-factor-less-than-one.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-factor-less-than-one.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-factor-less-than-one.html)
 - [flexbox_computedstyle_flex-shorthand-0-auto.html](https://wpt.fyi/results/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-shorthand-0-auto.html "css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-shorthand-0-auto.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-shorthand-0-auto.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-shorthand-0-auto.html)
 - [flexbox_computedstyle_flex-shorthand-auto.html](https://wpt.fyi/results/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-shorthand-auto.html "css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-shorthand-auto.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-shorthand-auto.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-shorthand-auto.html)
 - [flexbox_computedstyle_flex-shorthand.html](https://wpt.fyi/results/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-shorthand.html "css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-shorthand.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-shorthand.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-shorthand.html)
 - [flexbox_computedstyle_flex-shorthand-initial.html](https://wpt.fyi/results/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-shorthand-initial.html "css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-shorthand-initial.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-shorthand-initial.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-shorthand-initial.html)
 - [flexbox_computedstyle_flex-shorthand-invalid.html](https://wpt.fyi/results/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-shorthand-invalid.html "css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-shorthand-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-shorthand-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-shorthand-invalid.html)
 - [flexbox_computedstyle_flex-shorthand-none.html](https://wpt.fyi/results/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-shorthand-none.html "css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-shorthand-none.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-shorthand-none.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-shorthand-none.html)
 - [flexbox_computedstyle_flex-shorthand-number.html](https://wpt.fyi/results/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-shorthand-number.html "css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-shorthand-number.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-shorthand-number.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-shorthand-number.html)
 - [flexbox_computedstyle_flex-grow-0.html](https://wpt.fyi/results/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-grow-0.html "css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-grow-0.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-grow-0.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-grow-0.html)
 - [flexbox_computedstyle_flex-grow-invalid.html](https://wpt.fyi/results/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-grow-invalid.html "css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-grow-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-grow-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-grow-invalid.html)
 - [flexbox_computedstyle_flex-grow-number.html](https://wpt.fyi/results/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-grow-number.html "css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-grow-number.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-grow-number.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-grow-number.html)
 - [flexbox_interactive_flex-grow-transitions.html (manual test)
 ][[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/interactive/flexbox_interactive_flex-grow-transitions.html)
 - [flex-grow-computed.html](https://wpt.fyi/results/css/css-flexbox/parsing/flex-grow-computed.html "css/css-flexbox/parsing/flex-grow-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/parsing/flex-grow-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/parsing/flex-grow-computed.html)
 - [flex-grow-invalid.html](https://wpt.fyi/results/css/css-flexbox/parsing/flex-grow-invalid.html "css/css-flexbox/parsing/flex-grow-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/parsing/flex-grow-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/parsing/flex-grow-invalid.html)
 - [flex-grow-valid.html](https://wpt.fyi/results/css/css-flexbox/parsing/flex-grow-valid.html "css/css-flexbox/parsing/flex-grow-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/parsing/flex-grow-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/parsing/flex-grow-valid.html)
 - [table-item-flex-percentage-min-width.html](https://wpt.fyi/results/css/css-flexbox/table-item-flex-percentage-min-width.html "css/css-flexbox/table-item-flex-percentage-min-width.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/table-item-flex-percentage-min-width.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/table-item-flex-percentage-min-width.html)
 - [table-item-flex-percentage-width.html](https://wpt.fyi/results/css/css-flexbox/table-item-flex-percentage-width.html "css/css-flexbox/table-item-flex-percentage-width.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/table-item-flex-percentage-width.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/table-item-flex-percentage-width.html)
 - [flex-rounding.html](https://wpt.fyi/results/css/css-flexbox/flex-rounding.html "css/css-flexbox/flex-rounding.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-rounding.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-rounding.html)

 Flex values between 0 and 1 have a somewhat special behavior: when
 the sum of the flex values on the line is less than 1, they will
 take up less than 100% of the free space.

 An item's
 [flex-grow](#propdef-flex-grow) value is effectively a request for
 some proportion of the free space, with [1] meaning "100% of
 the free space"; then if the items on the line are requesting more
 than 100% in total, the requests are rebalanced to keep the same
 ratio but use up exactly 100% of it. However, if the items request
 *less* than the full amount (such as three items that are each
 [flex-grow: .25]) then they'll
 each get exactly what they request (25% of the free space to each,
 with the final 25% left unfilled). See [§ 9.7 Resolving Flexible
 Lengths](#resolve-flexible-lengths) for the exact details of how
 free space is distributed.

 This pattern is required for continuous behavior as
 [flex-grow](#propdef-flex-grow) approaches zero (which means the
 item wants *none* of the free space). Without this, a [flex-grow:
 1] item would take all of the free
 space; but so would a [flex-grow: 0.1] item, and a [flex-grow: 0.01] item, etc., until finally the value is small enough to
 underflow to zero and the item suddenly takes up none of the free
 space. With this behavior, the item instead gradually takes less of
 the free space as [flex-grow] shrinks below [1], smoothly transitioning to taking
 none of the free space at zero.

 Unless this "partial fill" behavior is *specifically* what's
 desired, authors should stick to values ≥ 1; for example, using
 [1] and [2] is usually better than using [.33] and
 [.67], as they're more likely to behave as intended if items
 are added, removed, or line-wrapped.

[[\<\'flex-shrink\'\>](#propdef-flex-shrink)]

: This [\<number
 \[0,∞\]\>](https://drafts.csswg.org/css-values-4/#number-value) component sets
 [flex-shrink](#propdef-flex-shrink) [longhand](#flex-components)
 and specifies the [flex shrink factor], which
 determines how much the [flex item](#flex-item) will shrink relative to the rest of the [flex
 items] in the flex container when negative
 free space is distributed. When omitted, it is set to [1].

 Tests

 - [flex-shrink-interpolation.html](https://wpt.fyi/results/css/css-flexbox/animation/flex-shrink-interpolation.html "css/css-flexbox/animation/flex-shrink-interpolation.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/animation/flex-shrink-interpolation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/animation/flex-shrink-interpolation.html)
 - [flex-002.htm](https://wpt.fyi/results/css/css-flexbox/flex-002.htm "css/css-flexbox/flex-002.htm")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-002.htm)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-002.htm)
 - [flex-004.htm](https://wpt.fyi/results/css/css-flexbox/flex-004.htm "css/css-flexbox/flex-004.htm")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-004.htm)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-004.htm)
 - [flex-factor-less-than-one.html](https://wpt.fyi/results/css/css-flexbox/flex-factor-less-than-one.html "css/css-flexbox/flex-factor-less-than-one.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-factor-less-than-one.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-factor-less-than-one.html)
 - [flex-shrink-001.html](https://wpt.fyi/results/css/css-flexbox/flex-shrink-001.html "css/css-flexbox/flex-shrink-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-shrink-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-shrink-001.html)
 - [flex-shrink-002.html](https://wpt.fyi/results/css/css-flexbox/flex-shrink-002.html "css/css-flexbox/flex-shrink-002.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-shrink-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-shrink-002.html)
 - [flex-shrink-003.html](https://wpt.fyi/results/css/css-flexbox/flex-shrink-003.html "css/css-flexbox/flex-shrink-003.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-shrink-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-shrink-003.html)
 - [flex-shrink-004.html](https://wpt.fyi/results/css/css-flexbox/flex-shrink-004.html "css/css-flexbox/flex-shrink-004.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-shrink-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-shrink-004.html)
 - [flex-shrink-005.html](https://wpt.fyi/results/css/css-flexbox/flex-shrink-005.html "css/css-flexbox/flex-shrink-005.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-shrink-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-shrink-005.html)
 - [flex-shrink-006.html](https://wpt.fyi/results/css/css-flexbox/flex-shrink-006.html "css/css-flexbox/flex-shrink-006.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-shrink-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-shrink-006.html)
 - [flex-shrink-007.html](https://wpt.fyi/results/css/css-flexbox/flex-shrink-007.html "css/css-flexbox/flex-shrink-007.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-shrink-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-shrink-007.html)
 - [flex-shrink-008.html](https://wpt.fyi/results/css/css-flexbox/flex-shrink-008.html "css/css-flexbox/flex-shrink-008.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-shrink-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-shrink-008.html)
 - [flex-shrink-large-value-crash.html](https://wpt.fyi/results/css/css-flexbox/flex-shrink-large-value-crash.html "css/css-flexbox/flex-shrink-large-value-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-shrink-large-value-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-shrink-large-value-crash.html)
 - [flexbox_computedstyle_flex-shrink-0.html](https://wpt.fyi/results/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-shrink-0.html "css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-shrink-0.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-shrink-0.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-shrink-0.html)
 - [flexbox_computedstyle_flex-shrink-invalid.html](https://wpt.fyi/results/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-shrink-invalid.html "css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-shrink-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-shrink-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-shrink-invalid.html)
 - [flexbox_computedstyle_flex-shrink-number.html](https://wpt.fyi/results/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-shrink-number.html "css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-shrink-number.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-shrink-number.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-shrink-number.html)
 - [flexbox_interactive_flex-shrink-transitions.html (manual test)
 ][[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/interactive/flexbox_interactive_flex-shrink-transitions.html)
 - [flexbox_interactive_flex-shrink-transitions-invalid.html (manual
 test)
 ][[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/interactive/flexbox_interactive_flex-shrink-transitions-invalid.html)
 - [flex-shrink-computed.html](https://wpt.fyi/results/css/css-flexbox/parsing/flex-shrink-computed.html "css/css-flexbox/parsing/flex-shrink-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/parsing/flex-shrink-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/parsing/flex-shrink-computed.html)
 - [flex-shrink-invalid.html](https://wpt.fyi/results/css/css-flexbox/parsing/flex-shrink-invalid.html "css/css-flexbox/parsing/flex-shrink-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/parsing/flex-shrink-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/parsing/flex-shrink-invalid.html)
 - [flex-shrink-valid.html](https://wpt.fyi/results/css/css-flexbox/parsing/flex-shrink-valid.html "css/css-flexbox/parsing/flex-shrink-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/parsing/flex-shrink-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/parsing/flex-shrink-valid.html)
 - [table-item-flex-percentage-min-width.html](https://wpt.fyi/results/css/css-flexbox/table-item-flex-percentage-min-width.html "css/css-flexbox/table-item-flex-percentage-min-width.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/table-item-flex-percentage-min-width.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/table-item-flex-percentage-min-width.html)
 - [table-item-flex-percentage-width.html](https://wpt.fyi/results/css/css-flexbox/table-item-flex-percentage-width.html "css/css-flexbox/table-item-flex-percentage-width.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/table-item-flex-percentage-width.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/table-item-flex-percentage-width.html)

 The [flex shrink
 factor](#flex-flex-shrink-factor) is multiplied by the [flex base
 size](#flex-base-size) when
 distributing negative space. This distributes negative space in
 proportion to how much the item is able to shrink, so that e.g. a
 small item won't shrink to zero before a larger item has been
 noticeably reduced.

 Tests

 - [flex-item-max-width-min-content-002.html](https://wpt.fyi/results/css/css-flexbox/flex-item-max-width-min-content-002.html "css/css-flexbox/flex-item-max-width-min-content-002.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-item-max-width-min-content-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-item-max-width-min-content-002.html)

[[\<\'flex-basis\'\>](#propdef-flex-basis)]

: This component sets the
 [flex-basis](#propdef-flex-basis) [longhand](#flex-components), which
 specifies the [flex basis]: the initial [main
 size](#main-size) of the [flex
 item](#flex-item), before free
 space is distributed according to the flex factors.

 Tests

 - [flex-basis-composition.html](https://wpt.fyi/results/css/css-flexbox/animation/flex-basis-composition.html "css/css-flexbox/animation/flex-basis-composition.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/animation/flex-basis-composition.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/animation/flex-basis-composition.html)
 - [flex-basis-content-crash.html](https://wpt.fyi/results/css/css-flexbox/animation/flex-basis-content-crash.html "css/css-flexbox/animation/flex-basis-content-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/animation/flex-basis-content-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/animation/flex-basis-content-crash.html)
 - [flex-basis-interpolation.html](https://wpt.fyi/results/css/css-flexbox/animation/flex-basis-interpolation.html "css/css-flexbox/animation/flex-basis-interpolation.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/animation/flex-basis-interpolation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/animation/flex-basis-interpolation.html)
 - [dynamic-isize-change-001.html](https://wpt.fyi/results/css/css-flexbox/dynamic-isize-change-001.html "css/css-flexbox/dynamic-isize-change-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/dynamic-isize-change-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/dynamic-isize-change-001.html)
 - [dynamic-isize-change-002.html](https://wpt.fyi/results/css/css-flexbox/dynamic-isize-change-002.html "css/css-flexbox/dynamic-isize-change-002.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/dynamic-isize-change-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/dynamic-isize-change-002.html)
 - [dynamic-isize-change-003.html](https://wpt.fyi/results/css/css-flexbox/dynamic-isize-change-003.html "css/css-flexbox/dynamic-isize-change-003.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/dynamic-isize-change-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/dynamic-isize-change-003.html)
 - [dynamic-isize-change-004.html](https://wpt.fyi/results/css/css-flexbox/dynamic-isize-change-004.html "css/css-flexbox/dynamic-isize-change-004.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/dynamic-isize-change-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/dynamic-isize-change-004.html)
 - [flex-basis-001.html](https://wpt.fyi/results/css/css-flexbox/flex-basis-001.html "css/css-flexbox/flex-basis-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-basis-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-basis-001.html)
 - [flex-basis-002.html](https://wpt.fyi/results/css/css-flexbox/flex-basis-002.html "css/css-flexbox/flex-basis-002.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-basis-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-basis-002.html)
 - [flex-basis-003.html](https://wpt.fyi/results/css/css-flexbox/flex-basis-003.html "css/css-flexbox/flex-basis-003.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-basis-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-basis-003.html)
 - [flex-basis-004.html](https://wpt.fyi/results/css/css-flexbox/flex-basis-004.html "css/css-flexbox/flex-basis-004.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-basis-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-basis-004.html)
 - [flex-basis-005.html](https://wpt.fyi/results/css/css-flexbox/flex-basis-005.html "css/css-flexbox/flex-basis-005.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-basis-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-basis-005.html)
 - [flex-basis-006.html](https://wpt.fyi/results/css/css-flexbox/flex-basis-006.html "css/css-flexbox/flex-basis-006.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-basis-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-basis-006.html)
 - [flex-basis-007.html](https://wpt.fyi/results/css/css-flexbox/flex-basis-007.html "css/css-flexbox/flex-basis-007.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-basis-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-basis-007.html)
 - [flex-basis-008.html](https://wpt.fyi/results/css/css-flexbox/flex-basis-008.html "css/css-flexbox/flex-basis-008.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-basis-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-basis-008.html)
 - [flex-basis-009.html](https://wpt.fyi/results/css/css-flexbox/flex-basis-009.html "css/css-flexbox/flex-basis-009.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-basis-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-basis-009.html)
 - [flex-basis-010.html](https://wpt.fyi/results/css/css-flexbox/flex-basis-010.html "css/css-flexbox/flex-basis-010.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-basis-010.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-basis-010.html)
 - [flex-basis-011.html](https://wpt.fyi/results/css/css-flexbox/flex-basis-011.html "css/css-flexbox/flex-basis-011.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-basis-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-basis-011.html)
 - [flex-basis-012.html](https://wpt.fyi/results/css/css-flexbox/flex-basis-012.html "css/css-flexbox/flex-basis-012.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-basis-012.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-basis-012.html)
 - [flex-basis-013.html](https://wpt.fyi/results/css/css-flexbox/flex-basis-013.html "css/css-flexbox/flex-basis-013.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-basis-013.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-basis-013.html)
 - [flex-basis-intrinsics-001.html](https://wpt.fyi/results/css/css-flexbox/flex-basis-intrinsics-001.html "css/css-flexbox/flex-basis-intrinsics-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-basis-intrinsics-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-basis-intrinsics-001.html)
 - [flex-basis-item-margins-001.html](https://wpt.fyi/results/css/css-flexbox/flex-basis-item-margins-001.html "css/css-flexbox/flex-basis-item-margins-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-basis-item-margins-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-basis-item-margins-001.html)
 - [flexbox-flex-basis-content-001a.html](https://wpt.fyi/results/css/css-flexbox/flexbox-flex-basis-content-001a.html "css/css-flexbox/flexbox-flex-basis-content-001a.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-flex-basis-content-001a.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-flex-basis-content-001a.html)
 - [flexbox-flex-basis-content-001b.html](https://wpt.fyi/results/css/css-flexbox/flexbox-flex-basis-content-001b.html "css/css-flexbox/flexbox-flex-basis-content-001b.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-flex-basis-content-001b.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-flex-basis-content-001b.html)
 - [flexbox-flex-basis-content-002a.html](https://wpt.fyi/results/css/css-flexbox/flexbox-flex-basis-content-002a.html "css/css-flexbox/flexbox-flex-basis-content-002a.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-flex-basis-content-002a.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-flex-basis-content-002a.html)
 - [flexbox-flex-basis-content-002b.html](https://wpt.fyi/results/css/css-flexbox/flexbox-flex-basis-content-002b.html "css/css-flexbox/flexbox-flex-basis-content-002b.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-flex-basis-content-002b.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-flex-basis-content-002b.html)
 - [flexbox-flex-basis-content-003a.html](https://wpt.fyi/results/css/css-flexbox/flexbox-flex-basis-content-003a.html "css/css-flexbox/flexbox-flex-basis-content-003a.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-flex-basis-content-003a.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-flex-basis-content-003a.html)
 - [flexbox-flex-basis-content-003b.html](https://wpt.fyi/results/css/css-flexbox/flexbox-flex-basis-content-003b.html "css/css-flexbox/flexbox-flex-basis-content-003b.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-flex-basis-content-003b.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-flex-basis-content-003b.html)
 - [flexbox-flex-basis-content-004a.html](https://wpt.fyi/results/css/css-flexbox/flexbox-flex-basis-content-004a.html "css/css-flexbox/flexbox-flex-basis-content-004a.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-flex-basis-content-004a.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-flex-basis-content-004a.html)
 - [flexbox-flex-basis-content-004b.html](https://wpt.fyi/results/css/css-flexbox/flexbox-flex-basis-content-004b.html "css/css-flexbox/flexbox-flex-basis-content-004b.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-flex-basis-content-004b.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-flex-basis-content-004b.html)
 - [flexbox_flex-basis.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-basis.html "css/css-flexbox/flexbox_flex-basis.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-basis.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-basis.html)
 - [flexbox_flex-basis-shrink.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-basis-shrink.html "css/css-flexbox/flexbox_flex-basis-shrink.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-basis-shrink.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-basis-shrink.html)
 - [flex-one-sets-flex-basis-to-zero-px.html](https://wpt.fyi/results/css/css-flexbox/flex-one-sets-flex-basis-to-zero-px.html "css/css-flexbox/flex-one-sets-flex-basis-to-zero-px.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-one-sets-flex-basis-to-zero-px.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-one-sets-flex-basis-to-zero-px.html)
 - [flex-shorthand-flex-basis-middle.html](https://wpt.fyi/results/css/css-flexbox/flex-shorthand-flex-basis-middle.html "css/css-flexbox/flex-shorthand-flex-basis-middle.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-shorthand-flex-basis-middle.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-shorthand-flex-basis-middle.html)
 - [flexbox_computedstyle_flex-basis-0.html](https://wpt.fyi/results/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-basis-0.html "css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-basis-0.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-basis-0.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-basis-0.html)
 - [flexbox_computedstyle_flex-basis-0percent.html](https://wpt.fyi/results/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-basis-0percent.html "css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-basis-0percent.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-basis-0percent.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-basis-0percent.html)
 - [flexbox_computedstyle_flex-basis-auto.html](https://wpt.fyi/results/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-basis-auto.html "css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-basis-auto.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-basis-auto.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-basis-auto.html)
 - [flexbox_computedstyle_flex-basis-percent.html](https://wpt.fyi/results/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-basis-percent.html "css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-basis-percent.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-basis-percent.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-basis-percent.html)
 - [flexbox_interactive_flex-basis-transitions.html (manual test)
 ][[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/interactive/flexbox_interactive_flex-basis-transitions.html)
 - [flex-basis-computed.html](https://wpt.fyi/results/css/css-flexbox/parsing/flex-basis-computed.html "css/css-flexbox/parsing/flex-basis-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/parsing/flex-basis-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/parsing/flex-basis-computed.html)
 - [flex-basis-invalid.html](https://wpt.fyi/results/css/css-flexbox/parsing/flex-basis-invalid.html "css/css-flexbox/parsing/flex-basis-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/parsing/flex-basis-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/parsing/flex-basis-invalid.html)
 - [flex-basis-valid.html](https://wpt.fyi/results/css/css-flexbox/parsing/flex-basis-valid.html "css/css-flexbox/parsing/flex-basis-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/parsing/flex-basis-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/parsing/flex-basis-valid.html)
 - [table-as-item-percent-width-cell-001.html](https://wpt.fyi/results/css/css-flexbox/table-as-item-percent-width-cell-001.html "css/css-flexbox/table-as-item-percent-width-cell-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/table-as-item-percent-width-cell-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/table-as-item-percent-width-cell-001.html)

 [\<\'flex-basis\'\>](#propdef-flex-basis) accepts the same values as
 the
 [width](https://drafts.csswg.org/css-sizing-3/#propdef-width) and
 [height](https://drafts.csswg.org/css-sizing-3/#propdef-height) properties (except that
 [auto](#valdef-flex-basis-auto) is treated differently) plus the
 [content](#valdef-flex-basis-content) keyword:

 [auto]
 : When specified on a [flex item](#flex-item), the
 [auto](#valdef-flex-basis-auto) keyword retrieves the value of the [main
 size property](#main-size-property) as the used
 [flex-basis](#propdef-flex-basis). If that value is itself
 [auto], then the used
 value is
 [content](#valdef-flex-basis-content).

 [content]

 : Indicates an [automatic
 size](https://drafts.csswg.org/css-sizing-3/#automatic-size) based on the [flex
 item](#flex-item)'s
 content. (This is typically equivalent to the [max-content
 size](https://drafts.csswg.org/css-sizing-3/#max-content), but with adjustments to handle [preferred
 aspect
 ratios](https://drafts.csswg.org/css-sizing-4/#preferred-aspect-ratio), intrinsic sizing constraints, and orthogonal
 flows; see [details](#algo-main-item) in [§ 9 Flex Layout
 Algorithm](#layout-algorithm).)

 This value was not present in the initial
 release of Flexible Box Layout, and thus some older
 implementations will not support it. The equivalent effect can
 be achieved by using [auto] together with a main size
 ([width](https://drafts.csswg.org/css-sizing-3/#propdef-width) or
 [height](https://drafts.csswg.org/css-sizing-3/#propdef-height)) of
 [auto](https://drafts.csswg.org/css-sizing-3/#valdef-width-auto).

 [\<\'width\'\>](https://drafts.csswg.org/css-sizing-3/#propdef-width)
 : For all other values,
 [flex-basis](#propdef-flex-basis) is resolved the same way as
 for
 [width](https://drafts.csswg.org/css-sizing-3/#propdef-width) and
 [height](https://drafts.csswg.org/css-sizing-3/#propdef-height).

 When omitted from the [flex](#propdef-flex) shorthand, its specified value
 is [0].

[none]
: The keyword [none](#valdef-flex-none) expands to [0 0 auto].

![A diagram showing the difference between \"absolute\" flex (starting
from a basis of zero) and \"relative\" flex (starting from a basis of
the item's content size). The three items have flex factors of
[1], [1], and [2], respectively: notice that the item
with a flex factor of [2] grows twice as fast as the
others.](images/rel-vs-abs-flex.svg){height="240" width="504"}

A unitless zero that is not already preceded by two flex factors must be
interpreted as a flex factor. To avoid misinterpretation or invalid
declarations, authors must specify a zero
[\<\'flex-basis\'\>](#propdef-flex-basis) component with a unit or precede
it by two flex factors.

#### 7.1.1. Basic Values of [flex]
*This section is informative.*

The list below summarizes the effects of the four
[flex](#propdef-flex) values that represent most commonly-desired
effects:

[flex: initial](#propdef-flex)
: Equivalent to [flex: 0 1
 auto](#propdef-flex). (This is the initial value.) Sizes the item
 based on the
 [width](https://drafts.csswg.org/css-sizing-3/#propdef-width)/[height](https://drafts.csswg.org/css-sizing-3/#propdef-height) properties. (If the item's
 [main size
 property](#main-size-property) computes to
 [auto](https://drafts.csswg.org/css-sizing-3/#valdef-width-auto), this will size the flex item based on its
 contents.) Makes the flex item inflexible when there is positive
 free space, but allows it to shrink to its minimum size when there
 is insufficient space. The [alignment abilities](#alignment) or
 [[auto] margins](#auto-margins) can be used to align flex
 items along the [main axis](#main-axis).

[flex: auto](#propdef-flex)
: Equivalent to [flex: 1 1
 auto](#propdef-flex). Sizes the item based on the
 [width](https://drafts.csswg.org/css-sizing-3/#propdef-width)/[height](https://drafts.csswg.org/css-sizing-3/#propdef-height) properties, but makes them
 fully flexible, so that they absorb any free space along the [main
 axis](#main-axis). If all
 items are either [flex: auto], [flex:
 initial], or [flex:
 none], any positive free space after
 the items have been sized will be distributed evenly to the items
 with [flex: auto].

[flex: none](#propdef-flex)
: Equivalent to [flex: 0 0
 auto](#propdef-flex). This value sizes the item according to the
 [width](https://drafts.csswg.org/css-sizing-3/#propdef-width)/[height](https://drafts.csswg.org/css-sizing-3/#propdef-height) properties, but makes the flex
 item [fully inflexible](#fully-inflexible). This is similar to
 [initial](https://drafts.csswg.org/css-cascade-5/#valdef-all-initial), except that flex items are not allowed to
 shrink, even in overflow situations.

[flex: \<number \[1,∞\]\>](#propdef-flex)
: Equivalent to [flex: \<number \[1,∞\]\> 1
 0](#propdef-flex). Makes the flex item flexible and sets the
 [flex basis](#flex-flex-basis) to zero, resulting in an item that receives the
 specified proportion of the free space in the flex container. If all
 items in the flex container use this pattern, their sizes will be
 proportional to the specified flex factor.

Tests

- [flexbox_flex-auto.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-auto.html "css/css-flexbox/flexbox_flex-auto.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-auto.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-auto.html)
- [flexbox_flex-initial-2.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-initial-2.html "css/css-flexbox/flexbox_flex-initial-2.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-initial-2.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-initial-2.html)
- [flexbox_flex-initial.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-initial.html "css/css-flexbox/flexbox_flex-initial.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-initial.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-initial.html)
- [radiobutton-min-size.html](https://wpt.fyi/results/css/css-flexbox/radiobutton-min-size.html "css/css-flexbox/radiobutton-min-size.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/radiobutton-min-size.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/radiobutton-min-size.html)

By default, flex items won't shrink below their minimum content size
(the length of the longest word or fixed-size element). To change this,
set the
[min-width](https://drafts.csswg.org/css2/#propdef-min-width) or
[min-height](https://drafts.csswg.org/css2/#propdef-min-height) property. (See [§ 4.5 Automatic
Minimum Size of Flex Items](#min-size-auto).)

### 7.2. Components of Flexibility

Individual components of flexibility can be controlled by independent
longhand properties.

**Authors are encouraged to control flexibility using the
[flex](#propdef-flex) shorthand rather than with its longhand properties
directly, as the shorthand correctly resets any unspecified components
to accommodate [common uses](#flex-common).**

#### 7.2.1. The [flex-grow property]
Name:

[flex-grow]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<number
\[0,∞\]\>](https://drafts.csswg.org/css-values-4/#number-value)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

0

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[flex items](#flex-item)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

specified number

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value type

Tests

- [flex-grow-interpolation.html](https://wpt.fyi/results/css/css-flexbox/animation/flex-grow-interpolation.html "css/css-flexbox/animation/flex-grow-interpolation.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/animation/flex-grow-interpolation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/animation/flex-grow-interpolation.html)
- [flex-001.htm](https://wpt.fyi/results/css/css-flexbox/flex-001.htm "css/css-flexbox/flex-001.htm")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-001.htm)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-001.htm)
- [flex-003.htm](https://wpt.fyi/results/css/css-flexbox/flex-003.htm "css/css-flexbox/flex-003.htm")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-003.htm)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-003.htm)
- [flex-grow-001.xht](https://wpt.fyi/results/css/css-flexbox/flex-grow-001.xht "css/css-flexbox/flex-grow-001.xht")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-grow-001.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-grow-001.xht)
- [flex-grow-002.html](https://wpt.fyi/results/css/css-flexbox/flex-grow-002.html "css/css-flexbox/flex-grow-002.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-grow-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-grow-002.html)
- [flex-grow-003.html](https://wpt.fyi/results/css/css-flexbox/flex-grow-003.html "css/css-flexbox/flex-grow-003.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-grow-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-grow-003.html)
- [flex-grow-004.html](https://wpt.fyi/results/css/css-flexbox/flex-grow-004.html "css/css-flexbox/flex-grow-004.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-grow-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-grow-004.html)
- [flex-grow-005.html](https://wpt.fyi/results/css/css-flexbox/flex-grow-005.html "css/css-flexbox/flex-grow-005.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-grow-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-grow-005.html)
- [flex-grow-006.html](https://wpt.fyi/results/css/css-flexbox/flex-grow-006.html "css/css-flexbox/flex-grow-006.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-grow-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-grow-006.html)
- [flex-grow-007.html](https://wpt.fyi/results/css/css-flexbox/flex-grow-007.html "css/css-flexbox/flex-grow-007.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-grow-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-grow-007.html)
- [flex-grow-008.html](https://wpt.fyi/results/css/css-flexbox/flex-grow-008.html "css/css-flexbox/flex-grow-008.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-grow-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-grow-008.html)
- [flexbox_computedstyle_flex-grow-0.html](https://wpt.fyi/results/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-grow-0.html "css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-grow-0.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-grow-0.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-grow-0.html)
- [flexbox_computedstyle_flex-grow-invalid.html](https://wpt.fyi/results/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-grow-invalid.html "css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-grow-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-grow-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-grow-invalid.html)
- [flexbox_computedstyle_flex-grow-number.html](https://wpt.fyi/results/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-grow-number.html "css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-grow-number.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-grow-number.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-grow-number.html)
- [flexbox_interactive_flex-grow-transitions.html (manual test)
 ][[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/interactive/flexbox_interactive_flex-grow-transitions.html)
- [flex-grow-computed.html](https://wpt.fyi/results/css/css-flexbox/parsing/flex-grow-computed.html "css/css-flexbox/parsing/flex-grow-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/parsing/flex-grow-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/parsing/flex-grow-computed.html)
- [flex-grow-invalid.html](https://wpt.fyi/results/css/css-flexbox/parsing/flex-grow-invalid.html "css/css-flexbox/parsing/flex-grow-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/parsing/flex-grow-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/parsing/flex-grow-invalid.html)
- [flex-grow-valid.html](https://wpt.fyi/results/css/css-flexbox/parsing/flex-grow-valid.html "css/css-flexbox/parsing/flex-grow-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/parsing/flex-grow-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/parsing/flex-grow-valid.html)

**Authors are encouraged to control flexibility using the
[flex](#propdef-flex) shorthand rather than with
[flex-grow](#propdef-flex-grow) directly, as the shorthand correctly
resets any unspecified components to accommodate [common
uses](#flex-common).**

The [flex-grow](#propdef-flex-grow) property sets the [flex grow
factor](#flex-flex-grow-factor) to the provided
[[\<number\>](https://drafts.csswg.org/css-values-4/#number-value)]. Negative
values are not allowed.

#### 7.2.2. The [flex-shrink property]
Name:

[flex-shrink]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<number
\[0,∞\]\>](https://drafts.csswg.org/css-values-4/#number-value)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

1

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[flex items](#flex-item)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

specified value

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

number

Tests

- [flex-shrink-interpolation.html](https://wpt.fyi/results/css/css-flexbox/animation/flex-shrink-interpolation.html "css/css-flexbox/animation/flex-shrink-interpolation.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/animation/flex-shrink-interpolation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/animation/flex-shrink-interpolation.html)
- [flex-002.htm](https://wpt.fyi/results/css/css-flexbox/flex-002.htm "css/css-flexbox/flex-002.htm")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-002.htm)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-002.htm)
- [flex-004.htm](https://wpt.fyi/results/css/css-flexbox/flex-004.htm "css/css-flexbox/flex-004.htm")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-004.htm)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-004.htm)
- [flex-shrink-001.html](https://wpt.fyi/results/css/css-flexbox/flex-shrink-001.html "css/css-flexbox/flex-shrink-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-shrink-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-shrink-001.html)
- [flex-shrink-002.html](https://wpt.fyi/results/css/css-flexbox/flex-shrink-002.html "css/css-flexbox/flex-shrink-002.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-shrink-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-shrink-002.html)
- [flex-shrink-003.html](https://wpt.fyi/results/css/css-flexbox/flex-shrink-003.html "css/css-flexbox/flex-shrink-003.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-shrink-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-shrink-003.html)
- [flex-shrink-004.html](https://wpt.fyi/results/css/css-flexbox/flex-shrink-004.html "css/css-flexbox/flex-shrink-004.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-shrink-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-shrink-004.html)
- [flex-shrink-005.html](https://wpt.fyi/results/css/css-flexbox/flex-shrink-005.html "css/css-flexbox/flex-shrink-005.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-shrink-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-shrink-005.html)
- [flex-shrink-006.html](https://wpt.fyi/results/css/css-flexbox/flex-shrink-006.html "css/css-flexbox/flex-shrink-006.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-shrink-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-shrink-006.html)
- [flex-shrink-007.html](https://wpt.fyi/results/css/css-flexbox/flex-shrink-007.html "css/css-flexbox/flex-shrink-007.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-shrink-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-shrink-007.html)
- [flex-shrink-008.html](https://wpt.fyi/results/css/css-flexbox/flex-shrink-008.html "css/css-flexbox/flex-shrink-008.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-shrink-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-shrink-008.html)
- [flex-shrink-large-value-crash.html](https://wpt.fyi/results/css/css-flexbox/flex-shrink-large-value-crash.html "css/css-flexbox/flex-shrink-large-value-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-shrink-large-value-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-shrink-large-value-crash.html)
- [flexbox_computedstyle_flex-shrink-0.html](https://wpt.fyi/results/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-shrink-0.html "css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-shrink-0.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-shrink-0.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-shrink-0.html)
- [flexbox_computedstyle_flex-shrink-invalid.html](https://wpt.fyi/results/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-shrink-invalid.html "css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-shrink-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-shrink-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-shrink-invalid.html)
- [flexbox_computedstyle_flex-shrink-number.html](https://wpt.fyi/results/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-shrink-number.html "css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-shrink-number.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-shrink-number.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-shrink-number.html)
- [flexbox_interactive_flex-shrink-transitions.html (manual test)
 ][[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/interactive/flexbox_interactive_flex-shrink-transitions.html)
- [flexbox_interactive_flex-shrink-transitions-invalid.html (manual
 test)
 ][[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/interactive/flexbox_interactive_flex-shrink-transitions-invalid.html)
- [flex-shrink-computed.html](https://wpt.fyi/results/css/css-flexbox/parsing/flex-shrink-computed.html "css/css-flexbox/parsing/flex-shrink-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/parsing/flex-shrink-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/parsing/flex-shrink-computed.html)
- [flex-shrink-invalid.html](https://wpt.fyi/results/css/css-flexbox/parsing/flex-shrink-invalid.html "css/css-flexbox/parsing/flex-shrink-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/parsing/flex-shrink-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/parsing/flex-shrink-invalid.html)
- [flex-shrink-valid.html](https://wpt.fyi/results/css/css-flexbox/parsing/flex-shrink-valid.html "css/css-flexbox/parsing/flex-shrink-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/parsing/flex-shrink-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/parsing/flex-shrink-valid.html)

**Authors are encouraged to control flexibility using the
[flex](#propdef-flex) shorthand rather than with
[flex-shrink](#propdef-flex-shrink) directly, as the shorthand correctly
resets any unspecified components to accommodate [common
uses](#flex-common).**

The [flex-shrink](#propdef-flex-shrink) property sets the [flex shrink
factor](#flex-flex-shrink-factor) to the provided
[[\<number\>](https://drafts.csswg.org/css-values-4/#number-value)]. Negative
values are not allowed.

#### 7.2.3. The [flex-basis property]
Name:

[flex-basis]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

content
[\|](https://drafts.csswg.org/css-values-4/#comb-one)
[\<\'width\'\>](https://drafts.csswg.org/css-sizing-3/#propdef-width)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

auto

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[flex items](#flex-item)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

relative to the [flex
container's](#flex-container)
inner [main size](#main-size)

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

specified keyword or a computed
[\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage) value

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value type

Tests

- [flex-basis-composition.html](https://wpt.fyi/results/css/css-flexbox/animation/flex-basis-composition.html "css/css-flexbox/animation/flex-basis-composition.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/animation/flex-basis-composition.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/animation/flex-basis-composition.html)
- [flex-basis-content-crash.html](https://wpt.fyi/results/css/css-flexbox/animation/flex-basis-content-crash.html "css/css-flexbox/animation/flex-basis-content-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/animation/flex-basis-content-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/animation/flex-basis-content-crash.html)
- [flex-basis-interpolation.html](https://wpt.fyi/results/css/css-flexbox/animation/flex-basis-interpolation.html "css/css-flexbox/animation/flex-basis-interpolation.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/animation/flex-basis-interpolation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/animation/flex-basis-interpolation.html)
- [dynamic-isize-change-001.html](https://wpt.fyi/results/css/css-flexbox/dynamic-isize-change-001.html "css/css-flexbox/dynamic-isize-change-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/dynamic-isize-change-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/dynamic-isize-change-001.html)
- [dynamic-isize-change-002.html](https://wpt.fyi/results/css/css-flexbox/dynamic-isize-change-002.html "css/css-flexbox/dynamic-isize-change-002.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/dynamic-isize-change-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/dynamic-isize-change-002.html)
- [dynamic-isize-change-003.html](https://wpt.fyi/results/css/css-flexbox/dynamic-isize-change-003.html "css/css-flexbox/dynamic-isize-change-003.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/dynamic-isize-change-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/dynamic-isize-change-003.html)
- [dynamic-isize-change-004.html](https://wpt.fyi/results/css/css-flexbox/dynamic-isize-change-004.html "css/css-flexbox/dynamic-isize-change-004.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/dynamic-isize-change-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/dynamic-isize-change-004.html)
- [flex-basis-001.html](https://wpt.fyi/results/css/css-flexbox/flex-basis-001.html "css/css-flexbox/flex-basis-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-basis-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-basis-001.html)
- [flex-basis-002.html](https://wpt.fyi/results/css/css-flexbox/flex-basis-002.html "css/css-flexbox/flex-basis-002.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-basis-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-basis-002.html)
- [flex-basis-003.html](https://wpt.fyi/results/css/css-flexbox/flex-basis-003.html "css/css-flexbox/flex-basis-003.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-basis-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-basis-003.html)
- [flex-basis-004.html](https://wpt.fyi/results/css/css-flexbox/flex-basis-004.html "css/css-flexbox/flex-basis-004.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-basis-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-basis-004.html)
- [flex-basis-005.html](https://wpt.fyi/results/css/css-flexbox/flex-basis-005.html "css/css-flexbox/flex-basis-005.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-basis-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-basis-005.html)
- [flex-basis-006.html](https://wpt.fyi/results/css/css-flexbox/flex-basis-006.html "css/css-flexbox/flex-basis-006.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-basis-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-basis-006.html)
- [flex-basis-007.html](https://wpt.fyi/results/css/css-flexbox/flex-basis-007.html "css/css-flexbox/flex-basis-007.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-basis-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-basis-007.html)
- [flex-basis-008.html](https://wpt.fyi/results/css/css-flexbox/flex-basis-008.html "css/css-flexbox/flex-basis-008.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-basis-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-basis-008.html)
- [flex-basis-009.html](https://wpt.fyi/results/css/css-flexbox/flex-basis-009.html "css/css-flexbox/flex-basis-009.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-basis-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-basis-009.html)
- [flex-basis-010.html](https://wpt.fyi/results/css/css-flexbox/flex-basis-010.html "css/css-flexbox/flex-basis-010.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-basis-010.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-basis-010.html)
- [flex-basis-011.html](https://wpt.fyi/results/css/css-flexbox/flex-basis-011.html "css/css-flexbox/flex-basis-011.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-basis-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-basis-011.html)
- [flex-basis-012.html](https://wpt.fyi/results/css/css-flexbox/flex-basis-012.html "css/css-flexbox/flex-basis-012.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-basis-012.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-basis-012.html)
- [flex-basis-013.html](https://wpt.fyi/results/css/css-flexbox/flex-basis-013.html "css/css-flexbox/flex-basis-013.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-basis-013.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-basis-013.html)
- [flex-basis-content-percentage-height.html](https://wpt.fyi/results/css/css-flexbox/flex-basis-content-percentage-height.html "css/css-flexbox/flex-basis-content-percentage-height.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-basis-content-percentage-height.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-basis-content-percentage-height.html)
- [flex-basis-intrinsics-001.html](https://wpt.fyi/results/css/css-flexbox/flex-basis-intrinsics-001.html "css/css-flexbox/flex-basis-intrinsics-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-basis-intrinsics-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-basis-intrinsics-001.html)
- [flex-basis-item-margins-001.html](https://wpt.fyi/results/css/css-flexbox/flex-basis-item-margins-001.html "css/css-flexbox/flex-basis-item-margins-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-basis-item-margins-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-basis-item-margins-001.html)
- [flexbox-flex-basis-content-001a.html](https://wpt.fyi/results/css/css-flexbox/flexbox-flex-basis-content-001a.html "css/css-flexbox/flexbox-flex-basis-content-001a.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-flex-basis-content-001a.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-flex-basis-content-001a.html)
- [flexbox-flex-basis-content-001b.html](https://wpt.fyi/results/css/css-flexbox/flexbox-flex-basis-content-001b.html "css/css-flexbox/flexbox-flex-basis-content-001b.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-flex-basis-content-001b.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-flex-basis-content-001b.html)
- [flexbox-flex-basis-content-002a.html](https://wpt.fyi/results/css/css-flexbox/flexbox-flex-basis-content-002a.html "css/css-flexbox/flexbox-flex-basis-content-002a.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-flex-basis-content-002a.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-flex-basis-content-002a.html)
- [flexbox-flex-basis-content-002b.html](https://wpt.fyi/results/css/css-flexbox/flexbox-flex-basis-content-002b.html "css/css-flexbox/flexbox-flex-basis-content-002b.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-flex-basis-content-002b.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-flex-basis-content-002b.html)
- [flexbox-flex-basis-content-003a.html](https://wpt.fyi/results/css/css-flexbox/flexbox-flex-basis-content-003a.html "css/css-flexbox/flexbox-flex-basis-content-003a.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-flex-basis-content-003a.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-flex-basis-content-003a.html)
- [flexbox-flex-basis-content-003b.html](https://wpt.fyi/results/css/css-flexbox/flexbox-flex-basis-content-003b.html "css/css-flexbox/flexbox-flex-basis-content-003b.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-flex-basis-content-003b.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-flex-basis-content-003b.html)
- [flexbox-flex-basis-content-004a.html](https://wpt.fyi/results/css/css-flexbox/flexbox-flex-basis-content-004a.html "css/css-flexbox/flexbox-flex-basis-content-004a.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-flex-basis-content-004a.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-flex-basis-content-004a.html)
- [flexbox-flex-basis-content-004b.html](https://wpt.fyi/results/css/css-flexbox/flexbox-flex-basis-content-004b.html "css/css-flexbox/flexbox-flex-basis-content-004b.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-flex-basis-content-004b.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-flex-basis-content-004b.html)
- [flexbox_flex-basis.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-basis.html "css/css-flexbox/flexbox_flex-basis.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-basis.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-basis.html)
- [flexbox_flex-basis-shrink.html](https://wpt.fyi/results/css/css-flexbox/flexbox_flex-basis-shrink.html "css/css-flexbox/flexbox_flex-basis-shrink.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_flex-basis-shrink.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_flex-basis-shrink.html)
- [flex-one-sets-flex-basis-to-zero-px.html](https://wpt.fyi/results/css/css-flexbox/flex-one-sets-flex-basis-to-zero-px.html "css/css-flexbox/flex-one-sets-flex-basis-to-zero-px.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-one-sets-flex-basis-to-zero-px.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-one-sets-flex-basis-to-zero-px.html)
- [flex-shorthand-flex-basis-middle.html](https://wpt.fyi/results/css/css-flexbox/flex-shorthand-flex-basis-middle.html "css/css-flexbox/flex-shorthand-flex-basis-middle.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-shorthand-flex-basis-middle.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-shorthand-flex-basis-middle.html)
- [flexbox_computedstyle_flex-basis-0.html](https://wpt.fyi/results/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-basis-0.html "css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-basis-0.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-basis-0.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-basis-0.html)
- [flexbox_computedstyle_flex-basis-0percent.html](https://wpt.fyi/results/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-basis-0percent.html "css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-basis-0percent.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-basis-0percent.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-basis-0percent.html)
- [flexbox_computedstyle_flex-basis-auto.html](https://wpt.fyi/results/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-basis-auto.html "css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-basis-auto.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-basis-auto.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-basis-auto.html)
- [flexbox_computedstyle_flex-basis-percent.html](https://wpt.fyi/results/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-basis-percent.html "css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-basis-percent.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-basis-percent.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_flex-basis-percent.html)
- [flexbox_interactive_flex-basis-transitions.html (manual test)
 ][[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/interactive/flexbox_interactive_flex-basis-transitions.html)
- [flex-basis-computed.html](https://wpt.fyi/results/css/css-flexbox/parsing/flex-basis-computed.html "css/css-flexbox/parsing/flex-basis-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/parsing/flex-basis-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/parsing/flex-basis-computed.html)
- [flex-basis-invalid.html](https://wpt.fyi/results/css/css-flexbox/parsing/flex-basis-invalid.html "css/css-flexbox/parsing/flex-basis-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/parsing/flex-basis-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/parsing/flex-basis-invalid.html)
- [flex-basis-valid.html](https://wpt.fyi/results/css/css-flexbox/parsing/flex-basis-valid.html "css/css-flexbox/parsing/flex-basis-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/parsing/flex-basis-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/parsing/flex-basis-valid.html)

**Authors are encouraged to control flexibility using the
[flex](#propdef-flex) shorthand rather than with
[flex-basis](#propdef-flex-basis) directly, as the shorthand correctly
resets any unspecified components to accommodate [common
uses](#flex-common).**

The [flex-basis](#propdef-flex-basis) property sets the [flex
basis](#flex-flex-basis). It
accepts the same values as the
[width](https://drafts.csswg.org/css-sizing-3/#propdef-width) and
[height](https://drafts.csswg.org/css-sizing-3/#propdef-height) property, plus
[content](#valdef-flex-basis-content).

For all values other than
[auto](#valdef-flex-basis-auto) and
[content](#valdef-flex-basis-content) (defined above),
[flex-basis](#propdef-flex-basis) is resolved the same way as
[width](https://drafts.csswg.org/css-sizing-3/#propdef-width) in horizontal writing modes
[\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification"),
except that if a value would resolve to
[auto](https://drafts.csswg.org/css-sizing-3/#valdef-width-auto) for [width],
it instead resolves to [content] for [flex-basis]. For
example, percentage values of [flex-basis] are resolved against the flex item's containing block (i.e.
its [flex container](#flex-container)); and if that containing block's size is
[indefinite](#definite), the used
value for [flex-basis] is
[content]. As another
corollary, [flex-basis]
determines the size of the content box, unless otherwise specified such
as by
[box-sizing](https://drafts.csswg.org/css-sizing-3/#propdef-box-sizing)
[\[CSS3UI\]](#biblio-css3ui "CSS Basic User Interface Module Level 3 (CSS3 UI)").

## 8. Alignment

After a flex container's contents have finished their flexing and the
dimensions of all flex items are finalized, they can then be aligned
within the flex container.

The
[margin](https://drafts.csswg.org/css2/#propdef-margin) properties can be used to align
items in a manner similar to, but more powerful than, what margins can
do in block layout. [Flex items](#flex-item) also respect the alignment properties from [CSS Box
Alignment](https://www.w3.org/TR/css3-align/), which allow easy
keyword-based alignment of items in both the [main
axis](#main-axis) and [cross
axis](#cross-axis). These
properties make many common types of alignment trivial, including some
things that were very difficult in CSS 2.1, like horizontal and vertical
centering.

 While the alignment properties are defined in [CSS Box
Alignment](https://www.w3.org/TR/css3-align/)
[\[CSS-ALIGN-3\]](#biblio-css-align-3 "CSS Box Alignment Module Level 3"),
Flexible Box Layout reproduces the definitions of the relevant ones here
so as to not create a normative dependency that may slow down
advancement of the spec. These properties apply only to flex layout
until [CSS Box Alignment Level 3](https://www.w3.org/TR/css3-align/) is
finished and defines their effect for other layout modes. Additionally,
any new values defined in the Box Alignment module will apply to
Flexible Box Layout; in other words, the Box Alignment module, once
completed, will supersede the definitions here.

Tests

- [baseline-outside-flex-item.html](https://wpt.fyi/results/css/css-flexbox/baseline-outside-flex-item.html "css/css-flexbox/baseline-outside-flex-item.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/baseline-outside-flex-item.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/baseline-outside-flex-item.html)
- [fieldset-baseline-alignment.html](https://wpt.fyi/results/css/css-flexbox/fieldset-baseline-alignment.html "css/css-flexbox/fieldset-baseline-alignment.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/fieldset-baseline-alignment.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/fieldset-baseline-alignment.html)

### [8.1. ][ Aligning with [auto] margins]
*This section is non-normative. The normative definition of how margins
affect flex items is in the [Flex Layout Algorithm](#layout-algorithm)
section.*

Auto margins on flex items have an effect very similar to auto margins
in block flow:

- During calculations of flex bases and flexible lengths, auto margins
 are treated as [0].

- Prior to alignment via
 [justify-content](#propdef-justify-content) and
 [align-self](#propdef-align-self), any positive free space is
 distributed to auto margins in that dimension.

- Overflowing boxes ignore their auto margins and overflow in the
 [end](https://drafts.csswg.org/css-writing-modes-3/#css-end) direction.

Tests

- [auto-height-column-with-border-and-padding.html](https://wpt.fyi/results/css/css-flexbox/auto-height-column-with-border-and-padding.html "css/css-flexbox/auto-height-column-with-border-and-padding.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/auto-height-column-with-border-and-padding.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/auto-height-column-with-border-and-padding.html)
- [auto-height-with-flex.html](https://wpt.fyi/results/css/css-flexbox/auto-height-with-flex.html "css/css-flexbox/auto-height-with-flex.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/auto-height-with-flex.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/auto-height-with-flex.html)
- [auto-margins-001.html](https://wpt.fyi/results/css/css-flexbox/auto-margins-001.html "css/css-flexbox/auto-margins-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/auto-margins-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/auto-margins-001.html)
- [auto-margins-002.html](https://wpt.fyi/results/css/css-flexbox/auto-margins-002.html "css/css-flexbox/auto-margins-002.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/auto-margins-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/auto-margins-002.html)
- [auto-margins-003.html](https://wpt.fyi/results/css/css-flexbox/auto-margins-003.html "css/css-flexbox/auto-margins-003.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/auto-margins-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/auto-margins-003.html)
- [flexbox-margin-auto-horiz-001.xhtml](https://wpt.fyi/results/css/css-flexbox/flexbox-margin-auto-horiz-001.xhtml "css/css-flexbox/flexbox-margin-auto-horiz-001.xhtml")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-margin-auto-horiz-001.xhtml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-margin-auto-horiz-001.xhtml)
- [flexbox-margin-auto-horiz-002.xhtml](https://wpt.fyi/results/css/css-flexbox/flexbox-margin-auto-horiz-002.xhtml "css/css-flexbox/flexbox-margin-auto-horiz-002.xhtml")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-margin-auto-horiz-002.xhtml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-margin-auto-horiz-002.xhtml)
- [flexbox_margin-auto.html](https://wpt.fyi/results/css/css-flexbox/flexbox_margin-auto.html "css/css-flexbox/flexbox_margin-auto.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_margin-auto.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_margin-auto.html)
- [flexbox_margin-auto-overflow.html](https://wpt.fyi/results/css/css-flexbox/flexbox_margin-auto-overflow.html "css/css-flexbox/flexbox_margin-auto-overflow.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_margin-auto-overflow.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_margin-auto-overflow.html)
- [main-axis-margin-rounding.html](https://wpt.fyi/results/css/css-flexbox/main-axis-margin-rounding.html "css/css-flexbox/main-axis-margin-rounding.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/main-axis-margin-rounding.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/main-axis-margin-rounding.html)

 If free space is distributed to auto margins, the
alignment properties will have no effect in that dimension because the
margins will have stolen all the free space left over after flexing.

One use of [auto] margins in the
main axis is to separate flex items into distinct \"groups\". The
following example shows how to use this to reproduce a common UI
pattern - a single bar of actions with some aligned on the left and
others aligned on the right.

<figure>
<ul>
<li><a href="#">About</a></li>
<li><a href="#">Projects</a></li>
<li><a href="#">Interact</a></li>
<li><span id="login"><a href="#">Login</a></span></li>
</ul>
<figcaption>Sample rendering of the code below.</figcaption>
</figure>

```
nav > ul {
 display: flex;
}
nav > ul > #login {
 margin-left: auto;
}
```

```
<nav>
 <ul>
 <li><a href=/about>About</a>
 <li><a href=/projects>Projects</a>
 <li><a href=/interact>Interact</a>
 <li id="login"><a href=/login>Login</a>
 </ul>
</nav>
```

The figure below illustrates the
difference in cross-axis alignment in overflow situations between using
[[auto] margins](#auto-margins) and using the [alignment
properties](#propdef-align-items).

<figure>
<div style="display:table; margin: 0 auto 1em;">
<div class="cross-auto-figure"
style="display:table-cell; padding-right: 50px;">
<div>
<div>
About
</div>
<div>
Authoritarianism
</div>
<div>
Blog
</div>
</div>
</div>
<div class="cross-auto-figure"
style="display:table-cell; padding-left: 50px;">
<div>
<div>
About
</div>
<div style="margin-left: -31px;">
Authoritarianism
</div>
<div>
Blog
</div>
</div>
</div>
</div>
<figcaption>The items in the figure on the left are centered with
margins, while those in the figure on the right are centered with <a
href="#propdef-align-self" id="ref-for-propdef-align-self⑨"
class="css property" data->align-self</a>. If this
column flex container was placed against the left edge of the page, the
margin behavior would be more desirable, as the long item would be fully
readable. In other circumstances, the true centering behavior might be
better.</figcaption>
</figure>

### 8.2. Axis Alignment: the [justify-content property]
Name:

[justify-content]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

flex-start
[\|](https://drafts.csswg.org/css-values-4/#comb-one) flex-end [\|] center
[\|] space-between [\|]
space-around

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

flex-start

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[flex containers](#flex-container)

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

Tests

- [dynamic-isize-change-001.html](https://wpt.fyi/results/css/css-flexbox/dynamic-isize-change-001.html "css/css-flexbox/dynamic-isize-change-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/dynamic-isize-change-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/dynamic-isize-change-001.html)
- [dynamic-isize-change-002.html](https://wpt.fyi/results/css/css-flexbox/dynamic-isize-change-002.html "css/css-flexbox/dynamic-isize-change-002.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/dynamic-isize-change-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/dynamic-isize-change-002.html)
- [dynamic-isize-change-003.html](https://wpt.fyi/results/css/css-flexbox/dynamic-isize-change-003.html "css/css-flexbox/dynamic-isize-change-003.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/dynamic-isize-change-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/dynamic-isize-change-003.html)
- [dynamic-isize-change-004.html](https://wpt.fyi/results/css/css-flexbox/dynamic-isize-change-004.html "css/css-flexbox/dynamic-isize-change-004.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/dynamic-isize-change-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/dynamic-isize-change-004.html)
- [flexbox_justifycontent-center.html](https://wpt.fyi/results/css/css-flexbox/flexbox_justifycontent-center.html "css/css-flexbox/flexbox_justifycontent-center.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_justifycontent-center.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_justifycontent-center.html)
- [flexbox_justifycontent-center-overflow.html](https://wpt.fyi/results/css/css-flexbox/flexbox_justifycontent-center-overflow.html "css/css-flexbox/flexbox_justifycontent-center-overflow.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_justifycontent-center-overflow.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_justifycontent-center-overflow.html)
- [flexbox_justifycontent-end.html](https://wpt.fyi/results/css/css-flexbox/flexbox_justifycontent-end.html "css/css-flexbox/flexbox_justifycontent-end.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_justifycontent-end.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_justifycontent-end.html)
- [flexbox_justifycontent-end-rtl.html](https://wpt.fyi/results/css/css-flexbox/flexbox_justifycontent-end-rtl.html "css/css-flexbox/flexbox_justifycontent-end-rtl.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_justifycontent-end-rtl.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_justifycontent-end-rtl.html)
- [flexbox_justifycontent-flex-end.html](https://wpt.fyi/results/css/css-flexbox/flexbox_justifycontent-flex-end.html "css/css-flexbox/flexbox_justifycontent-flex-end.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_justifycontent-flex-end.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_justifycontent-flex-end.html)
- [flexbox_justifycontent-flex-start.html](https://wpt.fyi/results/css/css-flexbox/flexbox_justifycontent-flex-start.html "css/css-flexbox/flexbox_justifycontent-flex-start.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_justifycontent-flex-start.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_justifycontent-flex-start.html)
- [flexbox-justify-content-horiz-001a.xhtml](https://wpt.fyi/results/css/css-flexbox/flexbox-justify-content-horiz-001a.xhtml "css/css-flexbox/flexbox-justify-content-horiz-001a.xhtml")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-justify-content-horiz-001a.xhtml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-justify-content-horiz-001a.xhtml)
- [flexbox-justify-content-horiz-001b.xhtml](https://wpt.fyi/results/css/css-flexbox/flexbox-justify-content-horiz-001b.xhtml "css/css-flexbox/flexbox-justify-content-horiz-001b.xhtml")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-justify-content-horiz-001b.xhtml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-justify-content-horiz-001b.xhtml)
- [flexbox-justify-content-horiz-002.xhtml](https://wpt.fyi/results/css/css-flexbox/flexbox-justify-content-horiz-002.xhtml "css/css-flexbox/flexbox-justify-content-horiz-002.xhtml")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-justify-content-horiz-002.xhtml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-justify-content-horiz-002.xhtml)
- [flexbox-justify-content-horiz-003.xhtml](https://wpt.fyi/results/css/css-flexbox/flexbox-justify-content-horiz-003.xhtml "css/css-flexbox/flexbox-justify-content-horiz-003.xhtml")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-justify-content-horiz-003.xhtml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-justify-content-horiz-003.xhtml)
- [flexbox-justify-content-horiz-004.xhtml](https://wpt.fyi/results/css/css-flexbox/flexbox-justify-content-horiz-004.xhtml "css/css-flexbox/flexbox-justify-content-horiz-004.xhtml")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-justify-content-horiz-004.xhtml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-justify-content-horiz-004.xhtml)
- [flexbox-justify-content-horiz-005.xhtml](https://wpt.fyi/results/css/css-flexbox/flexbox-justify-content-horiz-005.xhtml "css/css-flexbox/flexbox-justify-content-horiz-005.xhtml")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-justify-content-horiz-005.xhtml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-justify-content-horiz-005.xhtml)
- [flexbox-justify-content-horiz-006.xhtml](https://wpt.fyi/results/css/css-flexbox/flexbox-justify-content-horiz-006.xhtml "css/css-flexbox/flexbox-justify-content-horiz-006.xhtml")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-justify-content-horiz-006.xhtml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-justify-content-horiz-006.xhtml)
- [flexbox_justifycontent-left-001.html](https://wpt.fyi/results/css/css-flexbox/flexbox_justifycontent-left-001.html "css/css-flexbox/flexbox_justifycontent-left-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_justifycontent-left-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_justifycontent-left-001.html)
- [flexbox_justifycontent-left-002.html](https://wpt.fyi/results/css/css-flexbox/flexbox_justifycontent-left-002.html "css/css-flexbox/flexbox_justifycontent-left-002.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_justifycontent-left-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_justifycontent-left-002.html)
- [flexbox_justifycontent-right-001.html](https://wpt.fyi/results/css/css-flexbox/flexbox_justifycontent-right-001.html "css/css-flexbox/flexbox_justifycontent-right-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_justifycontent-right-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_justifycontent-right-001.html)
- [flexbox_justifycontent-right-002.html](https://wpt.fyi/results/css/css-flexbox/flexbox_justifycontent-right-002.html "css/css-flexbox/flexbox_justifycontent-right-002.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_justifycontent-right-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_justifycontent-right-002.html)
- [flexbox_justifycontent-rtl-001.html](https://wpt.fyi/results/css/css-flexbox/flexbox_justifycontent-rtl-001.html "css/css-flexbox/flexbox_justifycontent-rtl-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_justifycontent-rtl-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_justifycontent-rtl-001.html)
- [flexbox_justifycontent-rtl-002.html](https://wpt.fyi/results/css/css-flexbox/flexbox_justifycontent-rtl-002.html "css/css-flexbox/flexbox_justifycontent-rtl-002.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_justifycontent-rtl-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_justifycontent-rtl-002.html)
- [flexbox_justifycontent-spacearound.html](https://wpt.fyi/results/css/css-flexbox/flexbox_justifycontent-spacearound.html "css/css-flexbox/flexbox_justifycontent-spacearound.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_justifycontent-spacearound.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_justifycontent-spacearound.html)
- [flexbox_justifycontent-spacearound-negative.html](https://wpt.fyi/results/css/css-flexbox/flexbox_justifycontent-spacearound-negative.html "css/css-flexbox/flexbox_justifycontent-spacearound-negative.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_justifycontent-spacearound-negative.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_justifycontent-spacearound-negative.html)
- [flexbox_justifycontent-spacearound-only.html](https://wpt.fyi/results/css/css-flexbox/flexbox_justifycontent-spacearound-only.html "css/css-flexbox/flexbox_justifycontent-spacearound-only.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_justifycontent-spacearound-only.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_justifycontent-spacearound-only.html)
- [flexbox_justifycontent-spacebetween.html](https://wpt.fyi/results/css/css-flexbox/flexbox_justifycontent-spacebetween.html "css/css-flexbox/flexbox_justifycontent-spacebetween.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_justifycontent-spacebetween.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_justifycontent-spacebetween.html)
- [flexbox_justifycontent-spacebetween-negative.html](https://wpt.fyi/results/css/css-flexbox/flexbox_justifycontent-spacebetween-negative.html "css/css-flexbox/flexbox_justifycontent-spacebetween-negative.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_justifycontent-spacebetween-negative.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_justifycontent-spacebetween-negative.html)
- [flexbox_justifycontent-spacebetween-only.html](https://wpt.fyi/results/css/css-flexbox/flexbox_justifycontent-spacebetween-only.html "css/css-flexbox/flexbox_justifycontent-spacebetween-only.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_justifycontent-spacebetween-only.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_justifycontent-spacebetween-only.html)
- [flexbox_justifycontent-start.html](https://wpt.fyi/results/css/css-flexbox/flexbox_justifycontent-start.html "css/css-flexbox/flexbox_justifycontent-start.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_justifycontent-start.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_justifycontent-start.html)
- [flexbox_justifycontent-start-rtl.html](https://wpt.fyi/results/css/css-flexbox/flexbox_justifycontent-start-rtl.html "css/css-flexbox/flexbox_justifycontent-start-rtl.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_justifycontent-start-rtl.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_justifycontent-start-rtl.html)
- [flexbox_justifycontent-stretch.html](https://wpt.fyi/results/css/css-flexbox/flexbox_justifycontent-stretch.html "css/css-flexbox/flexbox_justifycontent-stretch.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_justifycontent-stretch.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_justifycontent-stretch.html)
- [flexbox-justify-content-vert-001a.xhtml](https://wpt.fyi/results/css/css-flexbox/flexbox-justify-content-vert-001a.xhtml "css/css-flexbox/flexbox-justify-content-vert-001a.xhtml")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-justify-content-vert-001a.xhtml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-justify-content-vert-001a.xhtml)
- [flexbox-justify-content-vert-001b.xhtml](https://wpt.fyi/results/css/css-flexbox/flexbox-justify-content-vert-001b.xhtml "css/css-flexbox/flexbox-justify-content-vert-001b.xhtml")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-justify-content-vert-001b.xhtml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-justify-content-vert-001b.xhtml)
- [flexbox-justify-content-vert-002.xhtml](https://wpt.fyi/results/css/css-flexbox/flexbox-justify-content-vert-002.xhtml "css/css-flexbox/flexbox-justify-content-vert-002.xhtml")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-justify-content-vert-002.xhtml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-justify-content-vert-002.xhtml)
- [flexbox-justify-content-vert-003.xhtml](https://wpt.fyi/results/css/css-flexbox/flexbox-justify-content-vert-003.xhtml "css/css-flexbox/flexbox-justify-content-vert-003.xhtml")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-justify-content-vert-003.xhtml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-justify-content-vert-003.xhtml)
- [flexbox-justify-content-vert-004.xhtml](https://wpt.fyi/results/css/css-flexbox/flexbox-justify-content-vert-004.xhtml "css/css-flexbox/flexbox-justify-content-vert-004.xhtml")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-justify-content-vert-004.xhtml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-justify-content-vert-004.xhtml)
- [flexbox-justify-content-vert-005.xhtml](https://wpt.fyi/results/css/css-flexbox/flexbox-justify-content-vert-005.xhtml "css/css-flexbox/flexbox-justify-content-vert-005.xhtml")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-justify-content-vert-005.xhtml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-justify-content-vert-005.xhtml)
- [flexbox-justify-content-vert-006.xhtml](https://wpt.fyi/results/css/css-flexbox/flexbox-justify-content-vert-006.xhtml "css/css-flexbox/flexbox-justify-content-vert-006.xhtml")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-justify-content-vert-006.xhtml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-justify-content-vert-006.xhtml)
- [flexbox-justify-content-wmvert-001.xhtml](https://wpt.fyi/results/css/css-flexbox/flexbox-justify-content-wmvert-001.xhtml "css/css-flexbox/flexbox-justify-content-wmvert-001.xhtml")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-justify-content-wmvert-001.xhtml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-justify-content-wmvert-001.xhtml)
- [flexbox-justify-content-wmvert-002.html](https://wpt.fyi/results/css/css-flexbox/flexbox-justify-content-wmvert-002.html "css/css-flexbox/flexbox-justify-content-wmvert-002.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-justify-content-wmvert-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-justify-content-wmvert-002.html)
- [flexbox-justify-content-wmvert-003.html](https://wpt.fyi/results/css/css-flexbox/flexbox-justify-content-wmvert-003.html "css/css-flexbox/flexbox-justify-content-wmvert-003.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-justify-content-wmvert-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-justify-content-wmvert-003.html)
- [flexbox_margin.html](https://wpt.fyi/results/css/css-flexbox/flexbox_margin.html "css/css-flexbox/flexbox_margin.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_margin.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_margin.html)
- [flexbox_margin-left-ex.html](https://wpt.fyi/results/css/css-flexbox/flexbox_margin-left-ex.html "css/css-flexbox/flexbox_margin-left-ex.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_margin-left-ex.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_margin-left-ex.html)
- [flexbox_computedstyle_justify-content-center.html](https://wpt.fyi/results/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_justify-content-center.html "css/css-flexbox/getcomputedstyle/flexbox_computedstyle_justify-content-center.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_justify-content-center.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_justify-content-center.html)
- [flexbox_computedstyle_justify-content-flex-end.html](https://wpt.fyi/results/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_justify-content-flex-end.html "css/css-flexbox/getcomputedstyle/flexbox_computedstyle_justify-content-flex-end.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_justify-content-flex-end.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_justify-content-flex-end.html)
- [flexbox_computedstyle_justify-content-flex-start.html](https://wpt.fyi/results/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_justify-content-flex-start.html "css/css-flexbox/getcomputedstyle/flexbox_computedstyle_justify-content-flex-start.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_justify-content-flex-start.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_justify-content-flex-start.html)
- [flexbox_computedstyle_justify-content-space-around.html](https://wpt.fyi/results/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_justify-content-space-around.html "css/css-flexbox/getcomputedstyle/flexbox_computedstyle_justify-content-space-around.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_justify-content-space-around.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_justify-content-space-around.html)
- [flexbox_computedstyle_justify-content-space-between.html](https://wpt.fyi/results/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_justify-content-space-between.html "css/css-flexbox/getcomputedstyle/flexbox_computedstyle_justify-content-space-between.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_justify-content-space-between.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_justify-content-space-between.html)
- [justify-content-001.htm](https://wpt.fyi/results/css/css-flexbox/justify-content-001.htm "css/css-flexbox/justify-content-001.htm")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/justify-content-001.htm)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/justify-content-001.htm)
- [justify-content-002.htm](https://wpt.fyi/results/css/css-flexbox/justify-content-002.htm "css/css-flexbox/justify-content-002.htm")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/justify-content-002.htm)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/justify-content-002.htm)
- [justify-content-003.htm](https://wpt.fyi/results/css/css-flexbox/justify-content-003.htm "css/css-flexbox/justify-content-003.htm")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/justify-content-003.htm)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/justify-content-003.htm)
- [justify-content-004.htm](https://wpt.fyi/results/css/css-flexbox/justify-content-004.htm "css/css-flexbox/justify-content-004.htm")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/justify-content-004.htm)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/justify-content-004.htm)
- [justify-content-005.htm](https://wpt.fyi/results/css/css-flexbox/justify-content-005.htm "css/css-flexbox/justify-content-005.htm")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/justify-content-005.htm)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/justify-content-005.htm)
- [justify-content-006.html](https://wpt.fyi/results/css/css-flexbox/justify-content-006.html "css/css-flexbox/justify-content-006.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/justify-content-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/justify-content-006.html)
- [justify-content-007.html](https://wpt.fyi/results/css/css-flexbox/justify-content-007.html "css/css-flexbox/justify-content-007.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/justify-content-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/justify-content-007.html)
- [justify-content_center.html (visual test)
 ][[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/justify-content_center.html)
- [justify-content_flex-end.html (visual test)
 ][[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/justify-content_flex-end.html)
- [justify-content_flex-start.html (visual test)
 ][[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/justify-content_flex-start.html)
- [justify-content-sideways-001.html](https://wpt.fyi/results/css/css-flexbox/justify-content-sideways-001.html "css/css-flexbox/justify-content-sideways-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/justify-content-sideways-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/justify-content-sideways-001.html)
- [justify-content_space-around.html (visual test)
 ][[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/justify-content_space-around.html)
- [justify-content_space-between-001.html (visual test)
 ][[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/justify-content_space-between-001.html)
- [justify-content_space-between-002.html](https://wpt.fyi/results/css/css-flexbox/justify-content_space-between-002.html "css/css-flexbox/justify-content_space-between-002.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/justify-content_space-between-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/justify-content_space-between-002.html)
- [scrollbars-auto.html](https://wpt.fyi/results/css/css-flexbox/scrollbars-auto.html "css/css-flexbox/scrollbars-auto.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/scrollbars-auto.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/scrollbars-auto.html)
- [scrollbars.html](https://wpt.fyi/results/css/css-flexbox/scrollbars.html "css/css-flexbox/scrollbars.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/scrollbars.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/scrollbars.html)
- [scrollbars-no-margin.html](https://wpt.fyi/results/css/css-flexbox/scrollbars-no-margin.html "css/css-flexbox/scrollbars-no-margin.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/scrollbars-no-margin.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/scrollbars-no-margin.html)
- [justify-content-rounding.html](https://wpt.fyi/results/css/css-flexbox/justify-content-rounding.html "css/css-flexbox/justify-content-rounding.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/justify-content-rounding.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/justify-content-rounding.html)

The
[justify-content](#propdef-justify-content) property aligns [flex
items](#flex-item) along the [main
axis](#main-axis) of the current
line of the flex container. This is done *after* any flexible lengths
and any [auto margins](#auto-margins) have been resolved. Typically it
helps distribute extra free space leftover when either all the [flex
items] on a line are inflexible, or are flexible
but have reached their maximum size. It also exerts some control over
the alignment of items when they overflow the line.

[flex-start]
: [Flex items](#flex-item) are
 packed toward the start of the line. The
 [main-start](#main-start)
 margin edge of the first [flex item] on the
 line is placed flush with the [main-start]
 edge of the line, and each subsequent [flex
 item] is placed flush with the preceding item.
 Tests
 - [flexbox_justifycontent-start.html](https://wpt.fyi/results/css/css-flexbox/flexbox_justifycontent-start.html "css/css-flexbox/flexbox_justifycontent-start.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_justifycontent-start.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_justifycontent-start.html)
 - [flexbox_justifycontent-start-rtl.html](https://wpt.fyi/results/css/css-flexbox/flexbox_justifycontent-start-rtl.html "css/css-flexbox/flexbox_justifycontent-start-rtl.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_justifycontent-start-rtl.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_justifycontent-start-rtl.html)

[flex-end]
: [Flex items](#flex-item) are
 packed toward the end of the line. The
 [main-end](#main-end) margin
 edge of the last [flex item] is placed flush
 with the [main-end] edge of the line, and each
 preceding [flex item] is placed flush with the
 subsequent item.
 Tests
 - [css-box-justify-content.html](https://wpt.fyi/results/css/css-flexbox/css-box-justify-content.html "css/css-flexbox/css-box-justify-content.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/css-box-justify-content.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/css-box-justify-content.html)
 - [flexbox_justifycontent-end.html](https://wpt.fyi/results/css/css-flexbox/flexbox_justifycontent-end.html "css/css-flexbox/flexbox_justifycontent-end.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_justifycontent-end.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_justifycontent-end.html)
 - [flexbox_justifycontent-end-rtl.html](https://wpt.fyi/results/css/css-flexbox/flexbox_justifycontent-end-rtl.html "css/css-flexbox/flexbox_justifycontent-end-rtl.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_justifycontent-end-rtl.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_justifycontent-end-rtl.html)
 - [flexbox_justifycontent-flex-end.html](https://wpt.fyi/results/css/css-flexbox/flexbox_justifycontent-flex-end.html "css/css-flexbox/flexbox_justifycontent-flex-end.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_justifycontent-flex-end.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_justifycontent-flex-end.html)

[center]
: [Flex items](#flex-item) are
 packed toward the center of the line. The [flex
 items] on the line are placed flush with each
 other and aligned in the center of the line, with equal amounts of
 space between the [main-start](#main-start) edge of the line and the first item on the line and
 between the [main-end](#main-end) edge of the line and the last item on the line. (If
 the leftover free-space is negative, the [flex
 items] will overflow equally in both
 directions.)
 Tests
 - [flexbox_justifycontent-center.html](https://wpt.fyi/results/css/css-flexbox/flexbox_justifycontent-center.html "css/css-flexbox/flexbox_justifycontent-center.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_justifycontent-center.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_justifycontent-center.html)
 - [flexbox_justifycontent-center-overflow.html](https://wpt.fyi/results/css/css-flexbox/flexbox_justifycontent-center-overflow.html "css/css-flexbox/flexbox_justifycontent-center-overflow.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_justifycontent-center-overflow.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_justifycontent-center-overflow.html)

[space-between]
: [Flex items](#flex-item) are
 evenly distributed in the line. If the leftover free-space is
 negative or there is only a single [flex item]
 on the line, this value falls back to [safe flex-start].
 Otherwise, the [main-start](#main-start) margin edge of the first [flex
 item] on the line is placed flush with the
 [main-start] edge of the line, the
 [main-end](#main-end) margin
 edge of the last [flex item] on the line is
 placed flush with the [main-end] edge of the
 line, and the remaining [flex items] on the
 line are distributed so that the spacing between any two adjacent
 items is the same.
 Tests
 - [flexbox_justifycontent-spacebetween.html](https://wpt.fyi/results/css/css-flexbox/flexbox_justifycontent-spacebetween.html "css/css-flexbox/flexbox_justifycontent-spacebetween.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_justifycontent-spacebetween.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_justifycontent-spacebetween.html)
 - [flexbox_justifycontent-spacebetween-negative.html](https://wpt.fyi/results/css/css-flexbox/flexbox_justifycontent-spacebetween-negative.html "css/css-flexbox/flexbox_justifycontent-spacebetween-negative.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_justifycontent-spacebetween-negative.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_justifycontent-spacebetween-negative.html)
 - [flexbox_justifycontent-spacebetween-only.html](https://wpt.fyi/results/css/css-flexbox/flexbox_justifycontent-spacebetween-only.html "css/css-flexbox/flexbox_justifycontent-spacebetween-only.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_justifycontent-spacebetween-only.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_justifycontent-spacebetween-only.html)

[space-around]
: [Flex items](#flex-item) are
 evenly distributed in the line, with half-size spaces on either end.
 If the leftover free-space is negative or there is only a single
 [flex item] on the line, this value falls back
 to [safe center]. Otherwise, the [flex
 items] on the line are distributed such that
 the spacing between any two adjacent [flex
 items] on the line is the same, and the
 spacing between the first/last [flex items]
 and the [flex container](#flex-container) edges is half the size of the spacing between [flex
 items].
 Tests
 - [flexbox-column-row-gap-001.html](https://wpt.fyi/results/css/css-flexbox/flexbox-column-row-gap-001.html "css/css-flexbox/flexbox-column-row-gap-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-column-row-gap-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-column-row-gap-001.html)
 - [flexbox-column-row-gap-002.html](https://wpt.fyi/results/css/css-flexbox/flexbox-column-row-gap-002.html "css/css-flexbox/flexbox-column-row-gap-002.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-column-row-gap-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-column-row-gap-002.html)
 - [flexbox-column-row-gap-003.html](https://wpt.fyi/results/css/css-flexbox/flexbox-column-row-gap-003.html "css/css-flexbox/flexbox-column-row-gap-003.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-column-row-gap-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-column-row-gap-003.html)
 - [flexbox-column-row-gap-004.html](https://wpt.fyi/results/css/css-flexbox/flexbox-column-row-gap-004.html "css/css-flexbox/flexbox-column-row-gap-004.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-column-row-gap-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-column-row-gap-004.html)
 - [flexbox_columns-flexitems-2.html](https://wpt.fyi/results/css/css-flexbox/flexbox_columns-flexitems-2.html "css/css-flexbox/flexbox_columns-flexitems-2.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_columns-flexitems-2.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_columns-flexitems-2.html)
 - [flexbox_columns-flexitems.html](https://wpt.fyi/results/css/css-flexbox/flexbox_columns-flexitems.html "css/css-flexbox/flexbox_columns-flexitems.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_columns-flexitems.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_columns-flexitems.html)
 - [flexbox_justifycontent-spacearound.html](https://wpt.fyi/results/css/css-flexbox/flexbox_justifycontent-spacearound.html "css/css-flexbox/flexbox_justifycontent-spacearound.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_justifycontent-spacearound.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_justifycontent-spacearound.html)
 - [flexbox_justifycontent-spacearound-negative.html](https://wpt.fyi/results/css/css-flexbox/flexbox_justifycontent-spacearound-negative.html "css/css-flexbox/flexbox_justifycontent-spacearound-negative.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_justifycontent-spacearound-negative.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_justifycontent-spacearound-negative.html)
 - [flexbox_justifycontent-spacearound-only.html](https://wpt.fyi/results/css/css-flexbox/flexbox_justifycontent-spacearound-only.html "css/css-flexbox/flexbox_justifycontent-spacearound-only.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_justifycontent-spacearound-only.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_justifycontent-spacearound-only.html)

!(images/flex-pack.svg){height="270" width="504"}

An illustration of the five
[justify-content](#propdef-justify-content) keywords and their effects on a
flex container with three colored items.

### 8.3. Cross-axis Alignment: the [align-items and [align-self](#propdef-align-self) properties]
Name:

[align-items]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

flex-start
[\|](https://drafts.csswg.org/css-values-4/#comb-one) flex-end [\|] center
[\|] baseline [\|] stretch

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

stretch

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[flex containers](#flex-container)

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

Tests

- [align-items-007.html](https://wpt.fyi/results/css/css-flexbox/align-items-007.html "css/css-flexbox/align-items-007.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/align-items-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/align-items-007.html)
- [align-items-008.html](https://wpt.fyi/results/css/css-flexbox/align-items-008.html "css/css-flexbox/align-items-008.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/align-items-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/align-items-008.html)
- [align-items-009.html](https://wpt.fyi/results/css/css-flexbox/align-items-009.html "css/css-flexbox/align-items-009.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/align-items-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/align-items-009.html)
- [align-items-baseline-column-horz.html](https://wpt.fyi/results/css/css-flexbox/align-items-baseline-column-horz.html "css/css-flexbox/align-items-baseline-column-horz.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/align-items-baseline-column-horz.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/align-items-baseline-column-horz.html)
- [align-items-baseline-column-vert.html](https://wpt.fyi/results/css/css-flexbox/align-items-baseline-column-vert.html "css/css-flexbox/align-items-baseline-column-vert.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/align-items-baseline-column-vert.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/align-items-baseline-column-vert.html)
- [align-items-baseline-column-vert-lr-flexbox-item.html](https://wpt.fyi/results/css/css-flexbox/align-items-baseline-column-vert-lr-flexbox-item.html "css/css-flexbox/align-items-baseline-column-vert-lr-flexbox-item.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/align-items-baseline-column-vert-lr-flexbox-item.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/align-items-baseline-column-vert-lr-flexbox-item.html)
- [align-items-baseline-column-vert-lr-grid-item.html](https://wpt.fyi/results/css/css-flexbox/align-items-baseline-column-vert-lr-grid-item.html "css/css-flexbox/align-items-baseline-column-vert-lr-grid-item.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/align-items-baseline-column-vert-lr-grid-item.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/align-items-baseline-column-vert-lr-grid-item.html)
- [align-items-baseline-column-vert-lr-items.html](https://wpt.fyi/results/css/css-flexbox/align-items-baseline-column-vert-lr-items.html "css/css-flexbox/align-items-baseline-column-vert-lr-items.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/align-items-baseline-column-vert-lr-items.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/align-items-baseline-column-vert-lr-items.html)
- [align-items-baseline-column-vert-lr-table-item.html](https://wpt.fyi/results/css/css-flexbox/align-items-baseline-column-vert-lr-table-item.html "css/css-flexbox/align-items-baseline-column-vert-lr-table-item.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/align-items-baseline-column-vert-lr-table-item.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/align-items-baseline-column-vert-lr-table-item.html)
- [align-items-baseline-column-vert-rl-flexbox-item.html](https://wpt.fyi/results/css/css-flexbox/align-items-baseline-column-vert-rl-flexbox-item.html "css/css-flexbox/align-items-baseline-column-vert-rl-flexbox-item.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/align-items-baseline-column-vert-rl-flexbox-item.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/align-items-baseline-column-vert-rl-flexbox-item.html)
- [align-items-baseline-column-vert-rl-grid-item.html](https://wpt.fyi/results/css/css-flexbox/align-items-baseline-column-vert-rl-grid-item.html "css/css-flexbox/align-items-baseline-column-vert-rl-grid-item.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/align-items-baseline-column-vert-rl-grid-item.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/align-items-baseline-column-vert-rl-grid-item.html)
- [align-items-baseline-column-vert-rl-items.html](https://wpt.fyi/results/css/css-flexbox/align-items-baseline-column-vert-rl-items.html "css/css-flexbox/align-items-baseline-column-vert-rl-items.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/align-items-baseline-column-vert-rl-items.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/align-items-baseline-column-vert-rl-items.html)
- [align-items-baseline-column-vert-rl-table-item.html](https://wpt.fyi/results/css/css-flexbox/align-items-baseline-column-vert-rl-table-item.html "css/css-flexbox/align-items-baseline-column-vert-rl-table-item.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/align-items-baseline-column-vert-rl-table-item.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/align-items-baseline-column-vert-rl-table-item.html)
- [align-items-baseline-overflow-non-visible.html](https://wpt.fyi/results/css/css-flexbox/align-items-baseline-overflow-non-visible.html "css/css-flexbox/align-items-baseline-overflow-non-visible.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/align-items-baseline-overflow-non-visible.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/align-items-baseline-overflow-non-visible.html)
- [align-items-baseline-row-horz.html](https://wpt.fyi/results/css/css-flexbox/align-items-baseline-row-horz.html "css/css-flexbox/align-items-baseline-row-horz.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/align-items-baseline-row-horz.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/align-items-baseline-row-horz.html)
- [align-items-baseline-row-vert.html](https://wpt.fyi/results/css/css-flexbox/align-items-baseline-row-vert.html "css/css-flexbox/align-items-baseline-row-vert.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/align-items-baseline-row-vert.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/align-items-baseline-row-vert.html)
- [align-items-baseline-vert-lr-column-horz-flexbox-item.html](https://wpt.fyi/results/css/css-flexbox/align-items-baseline-vert-lr-column-horz-flexbox-item.html "css/css-flexbox/align-items-baseline-vert-lr-column-horz-flexbox-item.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/align-items-baseline-vert-lr-column-horz-flexbox-item.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/align-items-baseline-vert-lr-column-horz-flexbox-item.html)
- [align-items-baseline-vert-lr-column-horz-grid-item.html](https://wpt.fyi/results/css/css-flexbox/align-items-baseline-vert-lr-column-horz-grid-item.html "css/css-flexbox/align-items-baseline-vert-lr-column-horz-grid-item.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/align-items-baseline-vert-lr-column-horz-grid-item.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/align-items-baseline-vert-lr-column-horz-grid-item.html)
- [align-items-baseline-vert-lr-column-horz-items.html](https://wpt.fyi/results/css/css-flexbox/align-items-baseline-vert-lr-column-horz-items.html "css/css-flexbox/align-items-baseline-vert-lr-column-horz-items.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/align-items-baseline-vert-lr-column-horz-items.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/align-items-baseline-vert-lr-column-horz-items.html)
- [align-items-baseline-vert-lr-column-horz-table-item.html](https://wpt.fyi/results/css/css-flexbox/align-items-baseline-vert-lr-column-horz-table-item.html "css/css-flexbox/align-items-baseline-vert-lr-column-horz-table-item.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/align-items-baseline-vert-lr-column-horz-table-item.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/align-items-baseline-vert-lr-column-horz-table-item.html)
- [align-items-baseline-vert-rl-column-horz-flexbox-item.html](https://wpt.fyi/results/css/css-flexbox/align-items-baseline-vert-rl-column-horz-flexbox-item.html "css/css-flexbox/align-items-baseline-vert-rl-column-horz-flexbox-item.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/align-items-baseline-vert-rl-column-horz-flexbox-item.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/align-items-baseline-vert-rl-column-horz-flexbox-item.html)
- [align-items-baseline-vert-rl-column-horz-grid-item.html](https://wpt.fyi/results/css/css-flexbox/align-items-baseline-vert-rl-column-horz-grid-item.html "css/css-flexbox/align-items-baseline-vert-rl-column-horz-grid-item.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/align-items-baseline-vert-rl-column-horz-grid-item.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/align-items-baseline-vert-rl-column-horz-grid-item.html)
- [align-items-baseline-vert-rl-column-horz-items.html](https://wpt.fyi/results/css/css-flexbox/align-items-baseline-vert-rl-column-horz-items.html "css/css-flexbox/align-items-baseline-vert-rl-column-horz-items.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/align-items-baseline-vert-rl-column-horz-items.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/align-items-baseline-vert-rl-column-horz-items.html)
- [align-items-baseline-vert-rl-column-horz-table-item.html](https://wpt.fyi/results/css/css-flexbox/align-items-baseline-vert-rl-column-horz-table-item.html "css/css-flexbox/align-items-baseline-vert-rl-column-horz-table-item.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/align-items-baseline-vert-rl-column-horz-table-item.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/align-items-baseline-vert-rl-column-horz-table-item.html)
- [multiline-align-self.html](https://wpt.fyi/results/css/css-flexbox/alignment/multiline-align-self.html "css/css-flexbox/alignment/multiline-align-self.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/alignment/multiline-align-self.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/alignment/multiline-align-self.html)
- [column-flex-child-with-max-width.html](https://wpt.fyi/results/css/css-flexbox/column-flex-child-with-max-width.html "css/css-flexbox/column-flex-child-with-max-width.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/column-flex-child-with-max-width.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/column-flex-child-with-max-width.html)
- [dynamic-stretch-change.html](https://wpt.fyi/results/css/css-flexbox/dynamic-stretch-change.html "css/css-flexbox/dynamic-stretch-change.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/dynamic-stretch-change.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/dynamic-stretch-change.html)
- [flexbox_align-items-baseline.html](https://wpt.fyi/results/css/css-flexbox/flexbox_align-items-baseline.html "css/css-flexbox/flexbox_align-items-baseline.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_align-items-baseline.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_align-items-baseline.html)
- [flexbox_align-items-center-2.html](https://wpt.fyi/results/css/css-flexbox/flexbox_align-items-center-2.html "css/css-flexbox/flexbox_align-items-center-2.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_align-items-center-2.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_align-items-center-2.html)
- [flexbox_align-items-center-3.html](https://wpt.fyi/results/css/css-flexbox/flexbox_align-items-center-3.html "css/css-flexbox/flexbox_align-items-center-3.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_align-items-center-3.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_align-items-center-3.html)
- [flexbox_align-items-center.html](https://wpt.fyi/results/css/css-flexbox/flexbox_align-items-center.html "css/css-flexbox/flexbox_align-items-center.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_align-items-center.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_align-items-center.html)
- [flexbox-align-items-center-nested-001.html](https://wpt.fyi/results/css/css-flexbox/flexbox-align-items-center-nested-001.html "css/css-flexbox/flexbox-align-items-center-nested-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-align-items-center-nested-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-align-items-center-nested-001.html)
- [flexbox_align-items-flexend-2.html](https://wpt.fyi/results/css/css-flexbox/flexbox_align-items-flexend-2.html "css/css-flexbox/flexbox_align-items-flexend-2.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_align-items-flexend-2.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_align-items-flexend-2.html)
- [flexbox_align-items-flexend.html](https://wpt.fyi/results/css/css-flexbox/flexbox_align-items-flexend.html "css/css-flexbox/flexbox_align-items-flexend.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_align-items-flexend.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_align-items-flexend.html)
- [flexbox_align-items-flexstart-2.html](https://wpt.fyi/results/css/css-flexbox/flexbox_align-items-flexstart-2.html "css/css-flexbox/flexbox_align-items-flexstart-2.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_align-items-flexstart-2.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_align-items-flexstart-2.html)
- [flexbox_align-items-flexstart.html](https://wpt.fyi/results/css/css-flexbox/flexbox_align-items-flexstart.html "css/css-flexbox/flexbox_align-items-flexstart.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_align-items-flexstart.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_align-items-flexstart.html)
- [flexbox_align-items-stretch-2.html](https://wpt.fyi/results/css/css-flexbox/flexbox_align-items-stretch-2.html "css/css-flexbox/flexbox_align-items-stretch-2.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_align-items-stretch-2.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_align-items-stretch-2.html)
- [flexbox_align-items-stretch-3.html](https://wpt.fyi/results/css/css-flexbox/flexbox_align-items-stretch-3.html "css/css-flexbox/flexbox_align-items-stretch-3.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_align-items-stretch-3.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_align-items-stretch-3.html)
- [flexbox_align-items-stretch-4.html](https://wpt.fyi/results/css/css-flexbox/flexbox_align-items-stretch-4.html "css/css-flexbox/flexbox_align-items-stretch-4.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_align-items-stretch-4.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_align-items-stretch-4.html)
- [flexbox_align-items-stretch.html](https://wpt.fyi/results/css/css-flexbox/flexbox_align-items-stretch.html "css/css-flexbox/flexbox_align-items-stretch.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_align-items-stretch.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_align-items-stretch.html)
- [flexbox_computedstyle_align-items-baseline.html](https://wpt.fyi/results/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_align-items-baseline.html "css/css-flexbox/getcomputedstyle/flexbox_computedstyle_align-items-baseline.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_align-items-baseline.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_align-items-baseline.html)
- [flexbox_computedstyle_align-items-center.html](https://wpt.fyi/results/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_align-items-center.html "css/css-flexbox/getcomputedstyle/flexbox_computedstyle_align-items-center.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_align-items-center.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_align-items-center.html)
- [flexbox_computedstyle_align-items-flex-end.html](https://wpt.fyi/results/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_align-items-flex-end.html "css/css-flexbox/getcomputedstyle/flexbox_computedstyle_align-items-flex-end.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_align-items-flex-end.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_align-items-flex-end.html)
- [flexbox_computedstyle_align-items-flex-start.html](https://wpt.fyi/results/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_align-items-flex-start.html "css/css-flexbox/getcomputedstyle/flexbox_computedstyle_align-items-flex-start.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_align-items-flex-start.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_align-items-flex-start.html)
- [flexbox_computedstyle_align-items-invalid.html](https://wpt.fyi/results/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_align-items-invalid.html "css/css-flexbox/getcomputedstyle/flexbox_computedstyle_align-items-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_align-items-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_align-items-invalid.html)
- [flexbox_computedstyle_align-items-stretch.html](https://wpt.fyi/results/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_align-items-stretch.html "css/css-flexbox/getcomputedstyle/flexbox_computedstyle_align-items-stretch.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_align-items-stretch.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_align-items-stretch.html)
- [position-relative-percentage-top-001.html](https://wpt.fyi/results/css/css-flexbox/position-relative-percentage-top-001.html "css/css-flexbox/position-relative-percentage-top-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/position-relative-percentage-top-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/position-relative-percentage-top-001.html)
- [position-relative-percentage-top-002.html](https://wpt.fyi/results/css/css-flexbox/position-relative-percentage-top-002.html "css/css-flexbox/position-relative-percentage-top-002.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/position-relative-percentage-top-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/position-relative-percentage-top-002.html)
- [position-relative-percentage-top-003.html](https://wpt.fyi/results/css/css-flexbox/position-relative-percentage-top-003.html "css/css-flexbox/position-relative-percentage-top-003.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/position-relative-percentage-top-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/position-relative-percentage-top-003.html)
- [relayout-align-items.html](https://wpt.fyi/results/css/css-flexbox/relayout-align-items.html "css/css-flexbox/relayout-align-items.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/relayout-align-items.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/relayout-align-items.html)
- [stretch-input-in-column.html](https://wpt.fyi/results/css/css-flexbox/stretch-input-in-column.html "css/css-flexbox/stretch-input-in-column.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/stretch-input-in-column.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/stretch-input-in-column.html)
- [stretch-requires-computed-auto-size.html](https://wpt.fyi/results/css/css-flexbox/stretch-requires-computed-auto-size.html "css/css-flexbox/stretch-requires-computed-auto-size.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/stretch-requires-computed-auto-size.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/stretch-requires-computed-auto-size.html)
- [table-as-item-stretch-cross-size-2.html](https://wpt.fyi/results/css/css-flexbox/table-as-item-stretch-cross-size-2.html "css/css-flexbox/table-as-item-stretch-cross-size-2.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/table-as-item-stretch-cross-size-2.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/table-as-item-stretch-cross-size-2.html)
- [table-as-item-stretch-cross-size-3.html](https://wpt.fyi/results/css/css-flexbox/table-as-item-stretch-cross-size-3.html "css/css-flexbox/table-as-item-stretch-cross-size-3.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/table-as-item-stretch-cross-size-3.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/table-as-item-stretch-cross-size-3.html)
- [table-as-item-stretch-cross-size-4.html](https://wpt.fyi/results/css/css-flexbox/table-as-item-stretch-cross-size-4.html "css/css-flexbox/table-as-item-stretch-cross-size-4.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/table-as-item-stretch-cross-size-4.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/table-as-item-stretch-cross-size-4.html)
- [table-as-item-stretch-cross-size-5.html](https://wpt.fyi/results/css/css-flexbox/table-as-item-stretch-cross-size-5.html "css/css-flexbox/table-as-item-stretch-cross-size-5.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/table-as-item-stretch-cross-size-5.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/table-as-item-stretch-cross-size-5.html)
- [table-as-item-stretch-cross-size.html](https://wpt.fyi/results/css/css-flexbox/table-as-item-stretch-cross-size.html "css/css-flexbox/table-as-item-stretch-cross-size.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/table-as-item-stretch-cross-size.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/table-as-item-stretch-cross-size.html)

Name:

[align-self]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

auto
[\|](https://drafts.csswg.org/css-values-4/#comb-one) flex-start [\|] flex-end
[\|] center [\|] baseline
[\|] stretch

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

auto

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[flex items](#flex-item)

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

Tests

- [align-self-006.html (visual test)
 ][[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/align-self-006.html)
- [align-self-010.html (visual test)
 ][[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/align-self-010.html)
- [align-self-013.html](https://wpt.fyi/results/css/css-flexbox/align-self-013.html "css/css-flexbox/align-self-013.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/align-self-013.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/align-self-013.html)
- [align-self-014.html](https://wpt.fyi/results/css/css-flexbox/align-self-014.html "css/css-flexbox/align-self-014.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/align-self-014.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/align-self-014.html)
- [align-self-015.html](https://wpt.fyi/results/css/css-flexbox/align-self-015.html "css/css-flexbox/align-self-015.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/align-self-015.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/align-self-015.html)
- [align-self-016.html](https://wpt.fyi/results/css/css-flexbox/align-self-016.html "css/css-flexbox/align-self-016.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/align-self-016.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/align-self-016.html)
- [flexbox_align-self-auto.html](https://wpt.fyi/results/css/css-flexbox/flexbox_align-self-auto.html "css/css-flexbox/flexbox_align-self-auto.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_align-self-auto.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_align-self-auto.html)
- [flexbox-align-self-baseline-compatability.html](https://wpt.fyi/results/css/css-flexbox/flexbox-align-self-baseline-compatability.html "css/css-flexbox/flexbox-align-self-baseline-compatability.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-align-self-baseline-compatability.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-align-self-baseline-compatability.html)
- [flexbox-align-self-baseline-horiz-001a.xhtml](https://wpt.fyi/results/css/css-flexbox/flexbox-align-self-baseline-horiz-001a.xhtml "css/css-flexbox/flexbox-align-self-baseline-horiz-001a.xhtml")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-align-self-baseline-horiz-001a.xhtml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-align-self-baseline-horiz-001a.xhtml)
- [flexbox-align-self-baseline-horiz-001b.xhtml](https://wpt.fyi/results/css/css-flexbox/flexbox-align-self-baseline-horiz-001b.xhtml "css/css-flexbox/flexbox-align-self-baseline-horiz-001b.xhtml")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-align-self-baseline-horiz-001b.xhtml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-align-self-baseline-horiz-001b.xhtml)
- [flexbox-align-self-baseline-horiz-002.xhtml](https://wpt.fyi/results/css/css-flexbox/flexbox-align-self-baseline-horiz-002.xhtml "css/css-flexbox/flexbox-align-self-baseline-horiz-002.xhtml")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-align-self-baseline-horiz-002.xhtml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-align-self-baseline-horiz-002.xhtml)
- [flexbox-align-self-baseline-horiz-003.xhtml](https://wpt.fyi/results/css/css-flexbox/flexbox-align-self-baseline-horiz-003.xhtml "css/css-flexbox/flexbox-align-self-baseline-horiz-003.xhtml")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-align-self-baseline-horiz-003.xhtml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-align-self-baseline-horiz-003.xhtml)
- [flexbox-align-self-baseline-horiz-004.xhtml](https://wpt.fyi/results/css/css-flexbox/flexbox-align-self-baseline-horiz-004.xhtml "css/css-flexbox/flexbox-align-self-baseline-horiz-004.xhtml")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-align-self-baseline-horiz-004.xhtml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-align-self-baseline-horiz-004.xhtml)
- [flexbox-align-self-baseline-horiz-005.xhtml](https://wpt.fyi/results/css/css-flexbox/flexbox-align-self-baseline-horiz-005.xhtml "css/css-flexbox/flexbox-align-self-baseline-horiz-005.xhtml")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-align-self-baseline-horiz-005.xhtml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-align-self-baseline-horiz-005.xhtml)
- [flexbox-align-self-baseline-horiz-006.xhtml](https://wpt.fyi/results/css/css-flexbox/flexbox-align-self-baseline-horiz-006.xhtml "css/css-flexbox/flexbox-align-self-baseline-horiz-006.xhtml")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-align-self-baseline-horiz-006.xhtml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-align-self-baseline-horiz-006.xhtml)
- [flexbox-align-self-baseline-horiz-007.xhtml](https://wpt.fyi/results/css/css-flexbox/flexbox-align-self-baseline-horiz-007.xhtml "css/css-flexbox/flexbox-align-self-baseline-horiz-007.xhtml")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-align-self-baseline-horiz-007.xhtml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-align-self-baseline-horiz-007.xhtml)
- [flexbox-align-self-baseline-horiz-008.xhtml](https://wpt.fyi/results/css/css-flexbox/flexbox-align-self-baseline-horiz-008.xhtml "css/css-flexbox/flexbox-align-self-baseline-horiz-008.xhtml")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-align-self-baseline-horiz-008.xhtml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-align-self-baseline-horiz-008.xhtml)
- [flexbox_align-self-baseline.html](https://wpt.fyi/results/css/css-flexbox/flexbox_align-self-baseline.html "css/css-flexbox/flexbox_align-self-baseline.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_align-self-baseline.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_align-self-baseline.html)
- [flexbox_align-self-center.html](https://wpt.fyi/results/css/css-flexbox/flexbox_align-self-center.html "css/css-flexbox/flexbox_align-self-center.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_align-self-center.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_align-self-center.html)
- [flexbox_align-self-flexend.html](https://wpt.fyi/results/css/css-flexbox/flexbox_align-self-flexend.html "css/css-flexbox/flexbox_align-self-flexend.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_align-self-flexend.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_align-self-flexend.html)
- [flexbox_align-self-flexstart.html](https://wpt.fyi/results/css/css-flexbox/flexbox_align-self-flexstart.html "css/css-flexbox/flexbox_align-self-flexstart.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_align-self-flexstart.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_align-self-flexstart.html)
- [flexbox-align-self-horiz-001-block.xhtml](https://wpt.fyi/results/css/css-flexbox/flexbox-align-self-horiz-001-block.xhtml "css/css-flexbox/flexbox-align-self-horiz-001-block.xhtml")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-align-self-horiz-001-block.xhtml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-align-self-horiz-001-block.xhtml)
- [flexbox-align-self-horiz-001-table.xhtml](https://wpt.fyi/results/css/css-flexbox/flexbox-align-self-horiz-001-table.xhtml "css/css-flexbox/flexbox-align-self-horiz-001-table.xhtml")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-align-self-horiz-001-table.xhtml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-align-self-horiz-001-table.xhtml)
- [flexbox-align-self-horiz-002.xhtml](https://wpt.fyi/results/css/css-flexbox/flexbox-align-self-horiz-002.xhtml "css/css-flexbox/flexbox-align-self-horiz-002.xhtml")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-align-self-horiz-002.xhtml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-align-self-horiz-002.xhtml)
- [flexbox-align-self-horiz-003.xhtml](https://wpt.fyi/results/css/css-flexbox/flexbox-align-self-horiz-003.xhtml "css/css-flexbox/flexbox-align-self-horiz-003.xhtml")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-align-self-horiz-003.xhtml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-align-self-horiz-003.xhtml)
- [flexbox-align-self-horiz-004.xhtml](https://wpt.fyi/results/css/css-flexbox/flexbox-align-self-horiz-004.xhtml "css/css-flexbox/flexbox-align-self-horiz-004.xhtml")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-align-self-horiz-004.xhtml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-align-self-horiz-004.xhtml)
- [flexbox-align-self-horiz-005.xhtml](https://wpt.fyi/results/css/css-flexbox/flexbox-align-self-horiz-005.xhtml "css/css-flexbox/flexbox-align-self-horiz-005.xhtml")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-align-self-horiz-005.xhtml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-align-self-horiz-005.xhtml)
- [flexbox_align-self-stretch.html](https://wpt.fyi/results/css/css-flexbox/flexbox_align-self-stretch.html "css/css-flexbox/flexbox_align-self-stretch.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_align-self-stretch.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_align-self-stretch.html)
- [flexbox-align-self-stretch-vert-001.html](https://wpt.fyi/results/css/css-flexbox/flexbox-align-self-stretch-vert-001.html "css/css-flexbox/flexbox-align-self-stretch-vert-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-align-self-stretch-vert-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-align-self-stretch-vert-001.html)
- [flexbox-align-self-stretch-vert-002.html](https://wpt.fyi/results/css/css-flexbox/flexbox-align-self-stretch-vert-002.html "css/css-flexbox/flexbox-align-self-stretch-vert-002.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-align-self-stretch-vert-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-align-self-stretch-vert-002.html)
- [flexbox-align-self-vert-001.xhtml](https://wpt.fyi/results/css/css-flexbox/flexbox-align-self-vert-001.xhtml "css/css-flexbox/flexbox-align-self-vert-001.xhtml")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-align-self-vert-001.xhtml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-align-self-vert-001.xhtml)
- [flexbox-align-self-vert-002.xhtml](https://wpt.fyi/results/css/css-flexbox/flexbox-align-self-vert-002.xhtml "css/css-flexbox/flexbox-align-self-vert-002.xhtml")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-align-self-vert-002.xhtml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-align-self-vert-002.xhtml)
- [flexbox-align-self-vert-003.xhtml](https://wpt.fyi/results/css/css-flexbox/flexbox-align-self-vert-003.xhtml "css/css-flexbox/flexbox-align-self-vert-003.xhtml")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-align-self-vert-003.xhtml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-align-self-vert-003.xhtml)
- [flexbox-align-self-vert-004.xhtml](https://wpt.fyi/results/css/css-flexbox/flexbox-align-self-vert-004.xhtml "css/css-flexbox/flexbox-align-self-vert-004.xhtml")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-align-self-vert-004.xhtml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-align-self-vert-004.xhtml)
- [flexbox-align-self-vert-rtl-001.xhtml](https://wpt.fyi/results/css/css-flexbox/flexbox-align-self-vert-rtl-001.xhtml "css/css-flexbox/flexbox-align-self-vert-rtl-001.xhtml")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-align-self-vert-rtl-001.xhtml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-align-self-vert-rtl-001.xhtml)
- [flexbox-align-self-vert-rtl-002.xhtml](https://wpt.fyi/results/css/css-flexbox/flexbox-align-self-vert-rtl-002.xhtml "css/css-flexbox/flexbox-align-self-vert-rtl-002.xhtml")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-align-self-vert-rtl-002.xhtml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-align-self-vert-rtl-002.xhtml)
- [flexbox-align-self-vert-rtl-003.xhtml](https://wpt.fyi/results/css/css-flexbox/flexbox-align-self-vert-rtl-003.xhtml "css/css-flexbox/flexbox-align-self-vert-rtl-003.xhtml")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-align-self-vert-rtl-003.xhtml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-align-self-vert-rtl-003.xhtml)
- [flexbox-align-self-vert-rtl-004.xhtml](https://wpt.fyi/results/css/css-flexbox/flexbox-align-self-vert-rtl-004.xhtml "css/css-flexbox/flexbox-align-self-vert-rtl-004.xhtml")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-align-self-vert-rtl-004.xhtml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-align-self-vert-rtl-004.xhtml)
- [flexbox-align-self-vert-rtl-005.xhtml](https://wpt.fyi/results/css/css-flexbox/flexbox-align-self-vert-rtl-005.xhtml "css/css-flexbox/flexbox-align-self-vert-rtl-005.xhtml")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-align-self-vert-rtl-005.xhtml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-align-self-vert-rtl-005.xhtml)
- [flexbox_computedstyle_align-self-baseline.html](https://wpt.fyi/results/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_align-self-baseline.html "css/css-flexbox/getcomputedstyle/flexbox_computedstyle_align-self-baseline.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_align-self-baseline.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_align-self-baseline.html)
- [flexbox_computedstyle_align-self-center.html](https://wpt.fyi/results/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_align-self-center.html "css/css-flexbox/getcomputedstyle/flexbox_computedstyle_align-self-center.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_align-self-center.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_align-self-center.html)
- [flexbox_computedstyle_align-self-flex-end.html](https://wpt.fyi/results/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_align-self-flex-end.html "css/css-flexbox/getcomputedstyle/flexbox_computedstyle_align-self-flex-end.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_align-self-flex-end.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_align-self-flex-end.html)
- [flexbox_computedstyle_align-self-flex-start.html](https://wpt.fyi/results/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_align-self-flex-start.html "css/css-flexbox/getcomputedstyle/flexbox_computedstyle_align-self-flex-start.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_align-self-flex-start.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_align-self-flex-start.html)
- [flexbox_computedstyle_align-self-invalid.html](https://wpt.fyi/results/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_align-self-invalid.html "css/css-flexbox/getcomputedstyle/flexbox_computedstyle_align-self-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_align-self-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_align-self-invalid.html)
- [flexbox_computedstyle_align-self-stretch.html](https://wpt.fyi/results/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_align-self-stretch.html "css/css-flexbox/getcomputedstyle/flexbox_computedstyle_align-self-stretch.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_align-self-stretch.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_align-self-stretch.html)

[Flex items](#flex-item) can be
aligned in the [cross axis](#cross-axis) of the current line of the flex container, similar to
[justify-content](#propdef-justify-content) but in the perpendicular direction.
[align-items](#propdef-align-items) sets the default alignment for all of
the flex container's [items], including anonymous
[flex items].
[align-self](#propdef-align-self) allows this default alignment to be
overridden for individual [flex items]. (For
anonymous flex items, [align-self] always matches the value of
[align-items] on their
associated flex container.)

If either of the [flex item's](#flex-item) cross-axis margins are [auto],
[align-self](#propdef-align-self) has no effect.

Values have the following meanings:

[auto]
: Defers [cross-axis](#cross-axis) alignment control to the value of
 [align-items](#propdef-align-items) on the parent box. (This is the
 initial value of
 [align-self](#propdef-align-self).)
 Tests
 - [align-self-007.html](https://wpt.fyi/results/css/css-flexbox/align-self-007.html "css/css-flexbox/align-self-007.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/align-self-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/align-self-007.html)
 - [align-self-008.html](https://wpt.fyi/results/css/css-flexbox/align-self-008.html "css/css-flexbox/align-self-008.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/align-self-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/align-self-008.html)
 - [align-self-009.html](https://wpt.fyi/results/css/css-flexbox/align-self-009.html "css/css-flexbox/align-self-009.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/align-self-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/align-self-009.html)
 - [align-self-011.html](https://wpt.fyi/results/css/css-flexbox/align-self-011.html "css/css-flexbox/align-self-011.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/align-self-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/align-self-011.html)
 - [align-self-012.html](https://wpt.fyi/results/css/css-flexbox/align-self-012.html "css/css-flexbox/align-self-012.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/align-self-012.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/align-self-012.html)

[flex-start]
: The [cross-start](#cross-start) margin edge of the [flex
 item](#flex-item) is placed
 flush with the [cross-start] edge of the
 line.
 Tests
 - [align-items-002.htm](https://wpt.fyi/results/css/css-flexbox/align-items-002.htm "css/css-flexbox/align-items-002.htm")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/align-items-002.htm)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/align-items-002.htm)
 - [align-items-006.html](https://wpt.fyi/results/css/css-flexbox/align-items-006.html "css/css-flexbox/align-items-006.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/align-items-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/align-items-006.html)
 - [align-self-001.html](https://wpt.fyi/results/css/css-flexbox/align-self-001.html "css/css-flexbox/align-self-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/align-self-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/align-self-001.html)

[flex-end]
: The [cross-end](#cross-end)
 margin edge of the [flex item](#flex-item) is placed flush with the
 [cross-end] edge of the line.
 Tests
 - [align-items-003.htm](https://wpt.fyi/results/css/css-flexbox/align-items-003.htm "css/css-flexbox/align-items-003.htm")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/align-items-003.htm)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/align-items-003.htm)
 - [align-self-002.html](https://wpt.fyi/results/css/css-flexbox/align-self-002.html "css/css-flexbox/align-self-002.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/align-self-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/align-self-002.html)

[center]
: The [flex item](#flex-item)'s
 margin box is centered in the [cross
 axis](#cross-axis) within the
 line. (If the [cross size](#cross-size) of the flex line is less than that of the [flex
 item], it will overflow equally in both
 directions.)
 Tests
 - [align-items-001.htm](https://wpt.fyi/results/css/css-flexbox/align-items-001.htm "css/css-flexbox/align-items-001.htm")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/align-items-001.htm)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/align-items-001.htm)
 - [align-self-003.html](https://wpt.fyi/results/css/css-flexbox/align-self-003.html "css/css-flexbox/align-self-003.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/align-self-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/align-self-003.html)

[baseline]
: The [flex item](#flex-item)
 [participates in baseline alignment]: all participating [flex items]
 on the line are aligned such that their baselines align, and the
 item with the largest distance between its baseline and its
 [cross-start](#cross-start)
 margin edge is placed flush against the
 [cross-start] edge of the line. If the item
 does not have a baseline in the necessary axis, then one is
 [synthesized](https://drafts.csswg.org/css-align-3/#synthesize-baseline) from the [flex item]'s border
 box.
 Tests
 - [align-items-004.htm](https://wpt.fyi/results/css/css-flexbox/align-items-004.htm "css/css-flexbox/align-items-004.htm")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/align-items-004.htm)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/align-items-004.htm)
 - [align-baseline.html](https://wpt.fyi/results/css/css-flexbox/align-baseline.html "css/css-flexbox/align-baseline.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/align-baseline.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/align-baseline.html)
 - [dynamic-baseline-change.html](https://wpt.fyi/results/css/css-flexbox/dynamic-baseline-change.html "css/css-flexbox/dynamic-baseline-change.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/dynamic-baseline-change.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/dynamic-baseline-change.html)
 - [dynamic-baseline-change-nested.html](https://wpt.fyi/results/css/css-flexbox/dynamic-baseline-change-nested.html "css/css-flexbox/dynamic-baseline-change-nested.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/dynamic-baseline-change-nested.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/dynamic-baseline-change-nested.html)

[stretch]

: If the [cross size
 property](#cross-size-property) of the [flex item](#flex-item) computes to
 [auto](https://drafts.csswg.org/css-sizing-3/#valdef-width-auto), and neither of the
 [cross-axis](#cross-axis)
 margins are [auto], the [flex item] is
 [stretched]. Its used value is the length necessary to make the
 [cross size](#cross-size) of
 the item's margin box as close to the same size as the line as
 possible, while still respecting the constraints imposed by
 [min-height](https://drafts.csswg.org/css2/#propdef-min-height)/[min-width](https://drafts.csswg.org/css2/#propdef-min-width)/[max-height](https://drafts.csswg.org/css2/#propdef-max-height)/[max-width](https://drafts.csswg.org/css2/#propdef-max-width).

 If the flex container's height is constrained this
 value may cause the contents of the [flex
 item](#flex-item) to overflow
 the item.

 The [cross-start](#cross-start) margin edge of the [flex
 item](#flex-item) is placed
 flush with the [cross-start] edge of the
 line.

 Tests

 - [align-items-005.htm](https://wpt.fyi/results/css/css-flexbox/align-items-005.htm "css/css-flexbox/align-items-005.htm")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/align-items-005.htm)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/align-items-005.htm)
 - [align-self-004.html](https://wpt.fyi/results/css/css-flexbox/align-self-004.html "css/css-flexbox/align-self-004.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/align-self-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/align-self-004.html)
 - [align-self-005.html](https://wpt.fyi/results/css/css-flexbox/align-self-005.html "css/css-flexbox/align-self-005.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/align-self-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/align-self-005.html)
 - [css-flexbox-height-animation-stretch.html (manual test)
 ][[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/css-flexbox-height-animation-stretch.html)

!(images/flex-align.svg){height="377" width="508"}

An illustration of the five
[align-items](#propdef-align-items) keywords and their effects on a flex
container with four colored items.

### 8.4. Packing Flex Lines: the [align-content property]
Name:

[align-content]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

flex-start
[\|](https://drafts.csswg.org/css-values-4/#comb-one) flex-end [\|] center
[\|] space-between [\|]
space-around [\|] stretch

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

stretch

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[multi-line](#multi-line-flex-container) [flex
containers](#flex-container)

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

The
[align-content](#propdef-align-content) property aligns a flex container's
lines within the flex container when there is extra space in the
[cross-axis](#cross-axis),
similar to how
[justify-content](#propdef-justify-content) aligns individual items within the
[main-axis](#main-axis). Note,
this property has no effect on a
[single-line](#single-line-flex-container) [flex
container](#flex-container).
Values have the following meanings:

[flex-start]
: Lines are packed toward the start of the flex container. The
 [cross-start](#cross-start)
 edge of the first line in the flex container is placed flush with
 the [cross-start] edge of the flex
 container, and each subsequent line is placed flush with the
 preceding line.

[flex-end]
: Lines are packed toward the end of the flex container. The
 [cross-end](#cross-end) edge of
 the last line is placed flush with the
 [cross-end] edge of the flex container, and
 each preceding line is placed flush with the subsequent line.

[center]
: Lines are packed toward the center of the flex container. The lines
 in the flex container are placed flush with each other and aligned
 in the center of the flex container, with equal amounts of space
 between the [cross-start](#cross-start) content edge of the flex container and the first
 line in the flex container, and between the
 [cross-end](#cross-end) content
 edge of the flex container and the last line in the flex container.
 (If the leftover free-space is negative, the lines will overflow
 equally in both directions.)

[space-between]
: Lines are evenly distributed in the flex container. If the leftover
 free-space is negative or there is only a single [flex
 line](#flex-line) in the flex
 container, this value falls back to [safe flex-start].
 Otherwise, the [cross-start](#cross-start) edge of the first line in the flex container is
 placed flush with the [cross-start] content
 edge of the flex container, the
 [cross-end](#cross-end) edge of
 the last line in the flex container is placed flush with the
 [cross-end] content edge of the flex container,
 and the remaining lines in the flex container are distributed so
 that the spacing between any two adjacent lines is the same.

[space-around]
: Lines are evenly distributed in the flex container, with half-size
 spaces on either end. If the leftover free-space is negative this
 value falls back to [safe center]. Otherwise, the lines in the
 flex container are distributed such that the spacing between any two
 adjacent lines is the same, and the spacing between the first/last
 lines and the [flex
 container](#flex-container) edges is half the size of the spacing between [flex
 lines](#flex-line).

[stretch]
: Lines stretch to take up the remaining space. If the leftover
 free-space is negative, this value falls back to
 [flex-start](#valdef-align-content-flex-start). Otherwise, the free-space is split equally
 between all of the lines, increasing their cross size.

 Only
[multi-line](#multi-line-flex-container) [flex
containers](#flex-container)
ever have free space in the
[cross-axis](#cross-axis) for
lines to be aligned in, because in a
[single-line](#single-line-flex-container) flex container the sole line automatically stretches to
fill the space.

!(images/align-content-example.svg){height="508" width="612"}

An illustration of the
[align-content](#propdef-align-content) keywords and their effects on a
[multi-line](#multi-line-flex-container) flex container.

- [align-content_center.html](https://wpt.fyi/results/css/css-flexbox/align-content_center.html "css/css-flexbox/align-content_center.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/align-content_center.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/align-content_center.html)
- [align-content_flex-end.html](https://wpt.fyi/results/css/css-flexbox/align-content_flex-end.html "css/css-flexbox/align-content_flex-end.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/align-content_flex-end.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/align-content_flex-end.html)
- [align-content_flex-start.html](https://wpt.fyi/results/css/css-flexbox/align-content_flex-start.html "css/css-flexbox/align-content_flex-start.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/align-content_flex-start.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/align-content_flex-start.html)
- [align-content-horiz-001a.html](https://wpt.fyi/results/css/css-flexbox/align-content-horiz-001a.html "css/css-flexbox/align-content-horiz-001a.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/align-content-horiz-001a.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/align-content-horiz-001a.html)
- [align-content-horiz-001b.html](https://wpt.fyi/results/css/css-flexbox/align-content-horiz-001b.html "css/css-flexbox/align-content-horiz-001b.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/align-content-horiz-001b.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/align-content-horiz-001b.html)
- [align-content-horiz-002.html](https://wpt.fyi/results/css/css-flexbox/align-content-horiz-002.html "css/css-flexbox/align-content-horiz-002.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/align-content-horiz-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/align-content-horiz-002.html)
- [align-content-stretch-rounding.html](https://wpt.fyi/results/css/css-flexbox/align-content-stretch-rounding.html "css/css-flexbox/align-content-stretch-rounding.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/align-content-stretch-rounding.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/align-content-stretch-rounding.html)
- [align-content_space-around.html](https://wpt.fyi/results/css/css-flexbox/align-content_space-around.html "css/css-flexbox/align-content_space-around.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/align-content_space-around.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/align-content_space-around.html)
- [align-content_space-between.html](https://wpt.fyi/results/css/css-flexbox/align-content_space-between.html "css/css-flexbox/align-content_space-between.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/align-content_space-between.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/align-content_space-between.html)
- [align-content_stretch.html](https://wpt.fyi/results/css/css-flexbox/align-content_stretch.html "css/css-flexbox/align-content_stretch.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/align-content_stretch.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/align-content_stretch.html)
- [align-content-vert-001a.html](https://wpt.fyi/results/css/css-flexbox/align-content-vert-001a.html "css/css-flexbox/align-content-vert-001a.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/align-content-vert-001a.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/align-content-vert-001a.html)
- [align-content-vert-001b.html](https://wpt.fyi/results/css/css-flexbox/align-content-vert-001b.html "css/css-flexbox/align-content-vert-001b.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/align-content-vert-001b.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/align-content-vert-001b.html)
- [align-content-vert-002.html](https://wpt.fyi/results/css/css-flexbox/align-content-vert-002.html "css/css-flexbox/align-content-vert-002.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/align-content-vert-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/align-content-vert-002.html)
- [align-content-wmvert-001.html](https://wpt.fyi/results/css/css-flexbox/align-content-wmvert-001.html "css/css-flexbox/align-content-wmvert-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/align-content-wmvert-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/align-content-wmvert-001.html)
- [align-content-wrap-001.html](https://wpt.fyi/results/css/css-flexbox/align-content-wrap-001.html "css/css-flexbox/align-content-wrap-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/align-content-wrap-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/align-content-wrap-001.html)
- [align-content-wrap-002.html](https://wpt.fyi/results/css/css-flexbox/align-content-wrap-002.html "css/css-flexbox/align-content-wrap-002.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/align-content-wrap-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/align-content-wrap-002.html)
- [align-content-wrap-003.html](https://wpt.fyi/results/css/css-flexbox/align-content-wrap-003.html "css/css-flexbox/align-content-wrap-003.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/align-content-wrap-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/align-content-wrap-003.html)
- [align-content-wrap-004.html](https://wpt.fyi/results/css/css-flexbox/align-content-wrap-004.html "css/css-flexbox/align-content-wrap-004.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/align-content-wrap-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/align-content-wrap-004.html)
- [align-content-wrap-005.html](https://wpt.fyi/results/css/css-flexbox/align-content-wrap-005.html "css/css-flexbox/align-content-wrap-005.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/align-content-wrap-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/align-content-wrap-005.html)
- [flex-align-content-center.html](https://wpt.fyi/results/css/css-flexbox/flex-align-content-center.html "css/css-flexbox/flex-align-content-center.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-align-content-center.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-align-content-center.html)
- [flex-align-content-end.html](https://wpt.fyi/results/css/css-flexbox/flex-align-content-end.html "css/css-flexbox/flex-align-content-end.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-align-content-end.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-align-content-end.html)
- [flex-align-content-space-around.html](https://wpt.fyi/results/css/css-flexbox/flex-align-content-space-around.html "css/css-flexbox/flex-align-content-space-around.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-align-content-space-around.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-align-content-space-around.html)
- [flex-align-content-space-between.html](https://wpt.fyi/results/css/css-flexbox/flex-align-content-space-between.html "css/css-flexbox/flex-align-content-space-between.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-align-content-space-between.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-align-content-space-between.html)
- [flex-align-content-start.html](https://wpt.fyi/results/css/css-flexbox/flex-align-content-start.html "css/css-flexbox/flex-align-content-start.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-align-content-start.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-align-content-start.html)
- [flexbox_align-content-center.html](https://wpt.fyi/results/css/css-flexbox/flexbox_align-content-center.html "css/css-flexbox/flexbox_align-content-center.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_align-content-center.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_align-content-center.html)
- [flexbox_align-content-flexend.html](https://wpt.fyi/results/css/css-flexbox/flexbox_align-content-flexend.html "css/css-flexbox/flexbox_align-content-flexend.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_align-content-flexend.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_align-content-flexend.html)
- [flexbox_align-content-flexstart.html](https://wpt.fyi/results/css/css-flexbox/flexbox_align-content-flexstart.html "css/css-flexbox/flexbox_align-content-flexstart.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_align-content-flexstart.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_align-content-flexstart.html)
- [flexbox_align-content-spacearound.html](https://wpt.fyi/results/css/css-flexbox/flexbox_align-content-spacearound.html "css/css-flexbox/flexbox_align-content-spacearound.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_align-content-spacearound.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_align-content-spacearound.html)
- [flexbox_align-content-spacebetween.html](https://wpt.fyi/results/css/css-flexbox/flexbox_align-content-spacebetween.html "css/css-flexbox/flexbox_align-content-spacebetween.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_align-content-spacebetween.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_align-content-spacebetween.html)
- [flexbox_align-content-stretch-2.html](https://wpt.fyi/results/css/css-flexbox/flexbox_align-content-stretch-2.html "css/css-flexbox/flexbox_align-content-stretch-2.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_align-content-stretch-2.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_align-content-stretch-2.html)
- [flexbox_align-content-stretch.html](https://wpt.fyi/results/css/css-flexbox/flexbox_align-content-stretch.html "css/css-flexbox/flexbox_align-content-stretch.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_align-content-stretch.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_align-content-stretch.html)
- [flexbox_computedstyle_align-content-center.html](https://wpt.fyi/results/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_align-content-center.html "css/css-flexbox/getcomputedstyle/flexbox_computedstyle_align-content-center.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_align-content-center.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_align-content-center.html)
- [flexbox_computedstyle_align-content-flex-end.html](https://wpt.fyi/results/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_align-content-flex-end.html "css/css-flexbox/getcomputedstyle/flexbox_computedstyle_align-content-flex-end.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_align-content-flex-end.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_align-content-flex-end.html)
- [flexbox_computedstyle_align-content-flex-start.html](https://wpt.fyi/results/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_align-content-flex-start.html "css/css-flexbox/getcomputedstyle/flexbox_computedstyle_align-content-flex-start.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_align-content-flex-start.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_align-content-flex-start.html)
- [flexbox_computedstyle_align-content-space-around.html](https://wpt.fyi/results/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_align-content-space-around.html "css/css-flexbox/getcomputedstyle/flexbox_computedstyle_align-content-space-around.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_align-content-space-around.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_align-content-space-around.html)
- [flexbox_computedstyle_align-content-space-between.html](https://wpt.fyi/results/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_align-content-space-between.html "css/css-flexbox/getcomputedstyle/flexbox_computedstyle_align-content-space-between.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_align-content-space-between.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/getcomputedstyle/flexbox_computedstyle_align-content-space-between.html)
- [align-content-rounding.html](https://wpt.fyi/results/css/css-flexbox/align-content-rounding.html "css/css-flexbox/align-content-rounding.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/align-content-rounding.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/align-content-rounding.html)

### 8.5. Flex Container Baselines

In order for a [flex
container](#flex-container)
to itself [participate in baseline
alignment](#baseline-participation)
(e.g. when the [flex container] is itself a
[flex item](#flex-item) in an
outer [flex container]), it needs to submit
the position of the baselines that will best represent its contents. To
this end, the baselines of a flex container are determined as follows
(after reordering with
[order](https://drafts.csswg.org/css-display-4/#propdef-order), and taking
[flex-direction](#propdef-flex-direction) into account):

first/last [ main-axis baseline set]

: When the [inline
 axis](https://drafts.csswg.org/css-writing-modes-4/#inline-axis) of the [flex
 container](#flex-container) matches its [main
 axis](#main-axis), its
 baselines are determined as follows:

 1. If any of the [flex items](#flex-item) on the flex container's
 [startmost](https://drafts.csswg.org/css-writing-modes-4/#css-start) [flex line](#flex-line) participate in first [baseline
 alignment](https://drafts.csswg.org/css-align-3/#baseline-alignment) along the [main
 axis](#main-axis),
 [generate](https://drafts.csswg.org/css-align-3/#generate-baselines) a [baseline
 set](https://drafts.csswg.org/css-align-3/#baseline-set) from their shared [alignment
 baseline](https://drafts.csswg.org/css-align-3/#alignment-baseline) and the [flex
 container's](#flex-container) [first available
 font](https://drafts.csswg.org/css-fonts-4/#first-available-font).

 2. Otherwise, if any of the [flex
 items](#flex-item) on the
 flex container's
 [startmost](https://drafts.csswg.org/css-writing-modes-4/#css-start) [flex line](#flex-line) participate in last [baseline
 alignment](https://drafts.csswg.org/css-align-3/#baseline-alignment) along the [main
 axis](#main-axis),
 [generate](https://drafts.csswg.org/css-align-3/#generate-baselines) a [baseline
 set](https://drafts.csswg.org/css-align-3/#baseline-set) from their shared [alignment
 baseline](https://drafts.csswg.org/css-align-3/#alignment-baseline) and the [flex
 container's](#flex-container) [first available
 font](https://drafts.csswg.org/css-fonts-4/#first-available-font).

 3. Otherwise, if any [flex items](#flex-item) in the
 [startmost](https://drafts.csswg.org/css-writing-modes-4/#css-start) [flex line](#flex-line) have a [baseline
 set](https://drafts.csswg.org/css-align-3/#baseline-set) along the [main
 axis](#main-axis), take
 the [baseline set] from the first such
 [flex item] in [order-modified document
 order](https://drafts.csswg.org/css-display-4/#order-modified-document-order).

 4. Otherwise, if there are any [flex
 items](#flex-item) at all,
 [synthesize](https://drafts.csswg.org/css-align-3/#synthesize-baseline) a [baseline
 set](https://drafts.csswg.org/css-align-3/#baseline-set) from the
 [startmost](https://drafts.csswg.org/css-writing-modes-4/#css-start) [flex item] on the
 [startmost] line.

 5. Otherwise, the [flex
 container](#flex-container) has no first
 [main-axis](#main-axis)
 [baseline
 set](https://drafts.csswg.org/css-align-3/#baseline-set). (One is
 [synthesized](https://drafts.csswg.org/css-align-3/#synthesize-baseline) from the [flex
 container] itself if needed,
 according to the rules of its [alignment
 context](https://drafts.csswg.org/css-align-3/#shared-alignment-context).)

 Last baselines are analogous (with "first"/"last" and "start"/"end"
 inverted).

first/last [ cross-axis baseline set]
: When the [inline
 axis](https://drafts.csswg.org/css-writing-modes-4/#inline-axis) of the [flex
 container](#flex-container) matches its [cross
 axis](#cross-axis), its
 baselines are determined as follows:
 1. If the flex container has at least one [flex
 item](#flex-item), the
 flex container's first/last [cross-axis baseline
 set](#cross-axis-baseline) is
 [generated](https://drafts.csswg.org/css-align-3/#generate-baselines) from the [alignment
 baseline](https://drafts.csswg.org/css-align-3/#alignment-baseline) of the
 [startmost](https://drafts.csswg.org/css-writing-modes-4/#css-start)/[endmost](https://drafts.csswg.org/css-writing-modes-4/#css-end) [flex item]. (If that
 item has no [alignment baseline]
 parallel to the flex container's [cross
 axis](#cross-axis), then
 one is first
 [synthesized](https://drafts.csswg.org/css-align-3/#synthesize-baseline) from its border edges.)

 2. Otherwise, the flex container has no first/last cross-axis
 [baseline
 set](https://drafts.csswg.org/css-align-3/#baseline-set), and one is
 [synthesized](https://drafts.csswg.org/css-align-3/#synthesize-baseline) if needed according to the rules of its
 [alignment
 context](https://drafts.csswg.org/css-align-3/#shared-alignment-context).

When calculating the baseline according to the above rules, if the box
contributing a baseline has an
[overflow](https://drafts.csswg.org/css-overflow-3/#propdef-overflow) value that allows scrolling, the
box must be treated as being in its initial scroll position for the
purpose of determining its baseline.

When [determining the baseline of a table
cell](https://www.w3.org/TR/CSS2/tables.html#height-layout), a flex
container provides a baseline just as a line box or table-row does.
[\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")

See [CSS Writing Modes 3 § 4.1 Introduction to
Baselines](https://drafts.csswg.org/css-writing-modes-3/#intro-baselines)
and [CSS Box Alignment 3 § 9 Baseline Alignment
Details](https://drafts.csswg.org/css-align-3/#baseline-rules) for more
information on baselines.

Tests

- [flex-align-baseline-001.html](https://wpt.fyi/results/css/css-flexbox/alignment/flex-align-baseline-001.html "css/css-flexbox/alignment/flex-align-baseline-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/alignment/flex-align-baseline-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/alignment/flex-align-baseline-001.html)
- [flex-align-baseline-002.html](https://wpt.fyi/results/css/css-flexbox/alignment/flex-align-baseline-002.html "css/css-flexbox/alignment/flex-align-baseline-002.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/alignment/flex-align-baseline-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/alignment/flex-align-baseline-002.html)
- [flex-align-baseline-003.html](https://wpt.fyi/results/css/css-flexbox/alignment/flex-align-baseline-003.html "css/css-flexbox/alignment/flex-align-baseline-003.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/alignment/flex-align-baseline-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/alignment/flex-align-baseline-003.html)
- [flex-align-baseline-004.html](https://wpt.fyi/results/css/css-flexbox/alignment/flex-align-baseline-004.html "css/css-flexbox/alignment/flex-align-baseline-004.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/alignment/flex-align-baseline-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/alignment/flex-align-baseline-004.html)
- [flex-align-baseline-005.html](https://wpt.fyi/results/css/css-flexbox/alignment/flex-align-baseline-005.html "css/css-flexbox/alignment/flex-align-baseline-005.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/alignment/flex-align-baseline-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/alignment/flex-align-baseline-005.html)
- [flex-align-baseline-006.html](https://wpt.fyi/results/css/css-flexbox/alignment/flex-align-baseline-006.html "css/css-flexbox/alignment/flex-align-baseline-006.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/alignment/flex-align-baseline-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/alignment/flex-align-baseline-006.html)
- [flex-align-baseline-007.html](https://wpt.fyi/results/css/css-flexbox/alignment/flex-align-baseline-007.html "css/css-flexbox/alignment/flex-align-baseline-007.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/alignment/flex-align-baseline-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/alignment/flex-align-baseline-007.html)
- [flex-align-baseline-column-rtl-direction.html](https://wpt.fyi/results/css/css-flexbox/alignment/flex-align-baseline-column-rtl-direction.html "css/css-flexbox/alignment/flex-align-baseline-column-rtl-direction.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/alignment/flex-align-baseline-column-rtl-direction.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/alignment/flex-align-baseline-column-rtl-direction.html)
- [flex-align-baseline-column-vert-lr-rtl-wrap-reverse.html](https://wpt.fyi/results/css/css-flexbox/alignment/flex-align-baseline-column-vert-lr-rtl-wrap-reverse.html "css/css-flexbox/alignment/flex-align-baseline-column-vert-lr-rtl-wrap-reverse.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/alignment/flex-align-baseline-column-vert-lr-rtl-wrap-reverse.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/alignment/flex-align-baseline-column-vert-lr-rtl-wrap-reverse.html)
- [flex-align-baseline-column-vert-rl-rtl-wrap-reverse.html](https://wpt.fyi/results/css/css-flexbox/alignment/flex-align-baseline-column-vert-rl-rtl-wrap-reverse.html "css/css-flexbox/alignment/flex-align-baseline-column-vert-rl-rtl-wrap-reverse.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/alignment/flex-align-baseline-column-vert-rl-rtl-wrap-reverse.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/alignment/flex-align-baseline-column-vert-rl-rtl-wrap-reverse.html)
- [flex-align-baseline-fieldset-001.html](https://wpt.fyi/results/css/css-flexbox/alignment/flex-align-baseline-fieldset-001.html "css/css-flexbox/alignment/flex-align-baseline-fieldset-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/alignment/flex-align-baseline-fieldset-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/alignment/flex-align-baseline-fieldset-001.html)
- [flex-align-baseline-fieldset-002.html](https://wpt.fyi/results/css/css-flexbox/alignment/flex-align-baseline-fieldset-002.html "css/css-flexbox/alignment/flex-align-baseline-fieldset-002.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/alignment/flex-align-baseline-fieldset-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/alignment/flex-align-baseline-fieldset-002.html)
- [flex-align-baseline-fieldset-003.html](https://wpt.fyi/results/css/css-flexbox/alignment/flex-align-baseline-fieldset-003.html "css/css-flexbox/alignment/flex-align-baseline-fieldset-003.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/alignment/flex-align-baseline-fieldset-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/alignment/flex-align-baseline-fieldset-003.html)
- [flex-align-baseline-flex-001.html](https://wpt.fyi/results/css/css-flexbox/alignment/flex-align-baseline-flex-001.html "css/css-flexbox/alignment/flex-align-baseline-flex-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/alignment/flex-align-baseline-flex-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/alignment/flex-align-baseline-flex-001.html)
- [flex-align-baseline-flex-002.html](https://wpt.fyi/results/css/css-flexbox/alignment/flex-align-baseline-flex-002.html "css/css-flexbox/alignment/flex-align-baseline-flex-002.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/alignment/flex-align-baseline-flex-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/alignment/flex-align-baseline-flex-002.html)
- [flex-align-baseline-flex-003.html](https://wpt.fyi/results/css/css-flexbox/alignment/flex-align-baseline-flex-003.html "css/css-flexbox/alignment/flex-align-baseline-flex-003.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/alignment/flex-align-baseline-flex-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/alignment/flex-align-baseline-flex-003.html)
- [flex-align-baseline-flex-004.html](https://wpt.fyi/results/css/css-flexbox/alignment/flex-align-baseline-flex-004.html "css/css-flexbox/alignment/flex-align-baseline-flex-004.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/alignment/flex-align-baseline-flex-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/alignment/flex-align-baseline-flex-004.html)
- [flex-align-baseline-grid-001.html](https://wpt.fyi/results/css/css-flexbox/alignment/flex-align-baseline-grid-001.html "css/css-flexbox/alignment/flex-align-baseline-grid-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/alignment/flex-align-baseline-grid-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/alignment/flex-align-baseline-grid-001.html)
- [flex-align-baseline-grid-002.html](https://wpt.fyi/results/css/css-flexbox/alignment/flex-align-baseline-grid-002.html "css/css-flexbox/alignment/flex-align-baseline-grid-002.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/alignment/flex-align-baseline-grid-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/alignment/flex-align-baseline-grid-002.html)
- [flex-align-baseline-grid-003.html](https://wpt.fyi/results/css/css-flexbox/alignment/flex-align-baseline-grid-003.html "css/css-flexbox/alignment/flex-align-baseline-grid-003.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/alignment/flex-align-baseline-grid-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/alignment/flex-align-baseline-grid-003.html)
- [flex-align-baseline-multicol-001.html](https://wpt.fyi/results/css/css-flexbox/alignment/flex-align-baseline-multicol-001.html "css/css-flexbox/alignment/flex-align-baseline-multicol-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/alignment/flex-align-baseline-multicol-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/alignment/flex-align-baseline-multicol-001.html)
- [flex-align-baseline-multicol-002.html](https://wpt.fyi/results/css/css-flexbox/alignment/flex-align-baseline-multicol-002.html "css/css-flexbox/alignment/flex-align-baseline-multicol-002.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/alignment/flex-align-baseline-multicol-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/alignment/flex-align-baseline-multicol-002.html)
- [flex-align-baseline-multicol-003.html](https://wpt.fyi/results/css/css-flexbox/alignment/flex-align-baseline-multicol-003.html "css/css-flexbox/alignment/flex-align-baseline-multicol-003.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/alignment/flex-align-baseline-multicol-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/alignment/flex-align-baseline-multicol-003.html)
- [flex-align-baseline-overflow-001.html](https://wpt.fyi/results/css/css-flexbox/alignment/flex-align-baseline-overflow-001.html "css/css-flexbox/alignment/flex-align-baseline-overflow-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/alignment/flex-align-baseline-overflow-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/alignment/flex-align-baseline-overflow-001.html)
- [flex-align-baseline-overflow-002.html](https://wpt.fyi/results/css/css-flexbox/alignment/flex-align-baseline-overflow-002.html "css/css-flexbox/alignment/flex-align-baseline-overflow-002.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/alignment/flex-align-baseline-overflow-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/alignment/flex-align-baseline-overflow-002.html)
- [flex-align-baseline-overflow-003.html](https://wpt.fyi/results/css/css-flexbox/alignment/flex-align-baseline-overflow-003.html "css/css-flexbox/alignment/flex-align-baseline-overflow-003.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/alignment/flex-align-baseline-overflow-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/alignment/flex-align-baseline-overflow-003.html)
- [flex-align-baseline-table-001.html](https://wpt.fyi/results/css/css-flexbox/alignment/flex-align-baseline-table-001.html "css/css-flexbox/alignment/flex-align-baseline-table-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/alignment/flex-align-baseline-table-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/alignment/flex-align-baseline-table-001.html)
- [flex-align-baseline-table-002.html](https://wpt.fyi/results/css/css-flexbox/alignment/flex-align-baseline-table-002.html "css/css-flexbox/alignment/flex-align-baseline-table-002.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/alignment/flex-align-baseline-table-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/alignment/flex-align-baseline-table-002.html)
- [flex-align-baseline-table-003.html](https://wpt.fyi/results/css/css-flexbox/alignment/flex-align-baseline-table-003.html "css/css-flexbox/alignment/flex-align-baseline-table-003.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/alignment/flex-align-baseline-table-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/alignment/flex-align-baseline-table-003.html)
- [flex-baseline-overflow-hidden.html](https://wpt.fyi/results/css/css-flexbox/flex-baseline-overflow-hidden.html "css/css-flexbox/flex-baseline-overflow-hidden.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-baseline-overflow-hidden.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-baseline-overflow-hidden.html)
- [flex-order-last-baseline.html](https://wpt.fyi/results/css/css-flexbox/flex-order-last-baseline.html "css/css-flexbox/flex-order-last-baseline.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-order-last-baseline.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-order-last-baseline.html)
- [flex-order-last-baseline-multiple.html](https://wpt.fyi/results/css/css-flexbox/flex-order-last-baseline-multiple.html "css/css-flexbox/flex-order-last-baseline-multiple.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-order-last-baseline-multiple.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-order-last-baseline-multiple.html)
- [flex-order-wrap-reverse-baseline.html](https://wpt.fyi/results/css/css-flexbox/flex-order-wrap-reverse-baseline.html "css/css-flexbox/flex-order-wrap-reverse-baseline.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-order-wrap-reverse-baseline.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-order-wrap-reverse-baseline.html)
- [flexbox-baseline-align-self-baseline-horiz-001.html](https://wpt.fyi/results/css/css-flexbox/flexbox-baseline-align-self-baseline-horiz-001.html "css/css-flexbox/flexbox-baseline-align-self-baseline-horiz-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-baseline-align-self-baseline-horiz-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-baseline-align-self-baseline-horiz-001.html)
- [flexbox-baseline-align-self-baseline-vert-001.html](https://wpt.fyi/results/css/css-flexbox/flexbox-baseline-align-self-baseline-vert-001.html "css/css-flexbox/flexbox-baseline-align-self-baseline-vert-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-baseline-align-self-baseline-vert-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-baseline-align-self-baseline-vert-001.html)
- [flexbox-baseline-empty-001a.html](https://wpt.fyi/results/css/css-flexbox/flexbox-baseline-empty-001a.html "css/css-flexbox/flexbox-baseline-empty-001a.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-baseline-empty-001a.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-baseline-empty-001a.html)
- [flexbox-baseline-empty-001b.html](https://wpt.fyi/results/css/css-flexbox/flexbox-baseline-empty-001b.html "css/css-flexbox/flexbox-baseline-empty-001b.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-baseline-empty-001b.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-baseline-empty-001b.html)
- [flexbox-baseline-multi-item-horiz-001a.html](https://wpt.fyi/results/css/css-flexbox/flexbox-baseline-multi-item-horiz-001a.html "css/css-flexbox/flexbox-baseline-multi-item-horiz-001a.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-baseline-multi-item-horiz-001a.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-baseline-multi-item-horiz-001a.html)
- [flexbox-baseline-multi-item-horiz-001b.html](https://wpt.fyi/results/css/css-flexbox/flexbox-baseline-multi-item-horiz-001b.html "css/css-flexbox/flexbox-baseline-multi-item-horiz-001b.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-baseline-multi-item-horiz-001b.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-baseline-multi-item-horiz-001b.html)
- [flexbox-baseline-multi-item-vert-001a.html](https://wpt.fyi/results/css/css-flexbox/flexbox-baseline-multi-item-vert-001a.html "css/css-flexbox/flexbox-baseline-multi-item-vert-001a.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-baseline-multi-item-vert-001a.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-baseline-multi-item-vert-001a.html)
- [flexbox-baseline-multi-item-vert-001b.html](https://wpt.fyi/results/css/css-flexbox/flexbox-baseline-multi-item-vert-001b.html "css/css-flexbox/flexbox-baseline-multi-item-vert-001b.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-baseline-multi-item-vert-001b.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-baseline-multi-item-vert-001b.html)
- [flexbox-baseline-multi-line-horiz-001.html](https://wpt.fyi/results/css/css-flexbox/flexbox-baseline-multi-line-horiz-001.html "css/css-flexbox/flexbox-baseline-multi-line-horiz-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-baseline-multi-line-horiz-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-baseline-multi-line-horiz-001.html)
- [flexbox-baseline-multi-line-horiz-002.html](https://wpt.fyi/results/css/css-flexbox/flexbox-baseline-multi-line-horiz-002.html "css/css-flexbox/flexbox-baseline-multi-line-horiz-002.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-baseline-multi-line-horiz-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-baseline-multi-line-horiz-002.html)
- [flexbox-baseline-multi-line-horiz-003.html](https://wpt.fyi/results/css/css-flexbox/flexbox-baseline-multi-line-horiz-003.html "css/css-flexbox/flexbox-baseline-multi-line-horiz-003.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-baseline-multi-line-horiz-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-baseline-multi-line-horiz-003.html)
- [flexbox-baseline-multi-line-horiz-004.html](https://wpt.fyi/results/css/css-flexbox/flexbox-baseline-multi-line-horiz-004.html "css/css-flexbox/flexbox-baseline-multi-line-horiz-004.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-baseline-multi-line-horiz-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-baseline-multi-line-horiz-004.html)
- [flexbox-baseline-multi-line-vert-001.html](https://wpt.fyi/results/css/css-flexbox/flexbox-baseline-multi-line-vert-001.html "css/css-flexbox/flexbox-baseline-multi-line-vert-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-baseline-multi-line-vert-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-baseline-multi-line-vert-001.html)
- [flexbox-baseline-multi-line-vert-002.html](https://wpt.fyi/results/css/css-flexbox/flexbox-baseline-multi-line-vert-002.html "css/css-flexbox/flexbox-baseline-multi-line-vert-002.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-baseline-multi-line-vert-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-baseline-multi-line-vert-002.html)
- [flexbox-baseline-nested-001.html](https://wpt.fyi/results/css/css-flexbox/flexbox-baseline-nested-001.html "css/css-flexbox/flexbox-baseline-nested-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-baseline-nested-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-baseline-nested-001.html)
- [flexbox-baseline-single-item-001a.html](https://wpt.fyi/results/css/css-flexbox/flexbox-baseline-single-item-001a.html "css/css-flexbox/flexbox-baseline-single-item-001a.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-baseline-single-item-001a.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-baseline-single-item-001a.html)
- [flexbox-baseline-single-item-001b.html](https://wpt.fyi/results/css/css-flexbox/flexbox-baseline-single-item-001b.html "css/css-flexbox/flexbox-baseline-single-item-001b.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-baseline-single-item-001b.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-baseline-single-item-001b.html)

## 9. Flex Layout Algorithm

This section contains normative algorithms detailing the exact layout
behavior of a flex container and its contents. The algorithms here are
written to optimize readability and theoretical simplicity, and may not
necessarily be the most efficient. Implementations may use whatever
actual algorithms they wish, but must produce the same results as the
algorithms described here.

 This section is mainly intended for implementors.
Authors writing web pages should generally be served well by the
individual property descriptions, and do not need to read this section
unless they have a deep-seated urge to understand arcane details of CSS
layout.

The following sections define the algorithm for laying out a flex
container and its contents.

 Flex layout works with the [flex
items](#flex-item) in
[order-modified document
order](https://drafts.csswg.org/css-display-4/#order-modified-document-order), not their original document order.

Tests

- [flexbox-basic-block-horiz-001v.xhtml](https://wpt.fyi/results/css/css-flexbox/flexbox-basic-block-horiz-001v.xhtml "css/css-flexbox/flexbox-basic-block-horiz-001v.xhtml")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-basic-block-horiz-001v.xhtml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-basic-block-horiz-001v.xhtml)
- [flexbox-basic-block-horiz-001.xhtml](https://wpt.fyi/results/css/css-flexbox/flexbox-basic-block-horiz-001.xhtml "css/css-flexbox/flexbox-basic-block-horiz-001.xhtml")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-basic-block-horiz-001.xhtml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-basic-block-horiz-001.xhtml)
- [flexbox-basic-block-vert-001v.xhtml](https://wpt.fyi/results/css/css-flexbox/flexbox-basic-block-vert-001v.xhtml "css/css-flexbox/flexbox-basic-block-vert-001v.xhtml")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-basic-block-vert-001v.xhtml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-basic-block-vert-001v.xhtml)
- [flexbox-basic-block-vert-001.xhtml](https://wpt.fyi/results/css/css-flexbox/flexbox-basic-block-vert-001.xhtml "css/css-flexbox/flexbox-basic-block-vert-001.xhtml")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-basic-block-vert-001.xhtml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-basic-block-vert-001.xhtml)
- [flexbox-basic-canvas-horiz-001v.xhtml](https://wpt.fyi/results/css/css-flexbox/flexbox-basic-canvas-horiz-001v.xhtml "css/css-flexbox/flexbox-basic-canvas-horiz-001v.xhtml")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-basic-canvas-horiz-001v.xhtml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-basic-canvas-horiz-001v.xhtml)
- [flexbox-basic-canvas-horiz-001.xhtml](https://wpt.fyi/results/css/css-flexbox/flexbox-basic-canvas-horiz-001.xhtml "css/css-flexbox/flexbox-basic-canvas-horiz-001.xhtml")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-basic-canvas-horiz-001.xhtml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-basic-canvas-horiz-001.xhtml)
- [flexbox-basic-canvas-vert-001v.xhtml](https://wpt.fyi/results/css/css-flexbox/flexbox-basic-canvas-vert-001v.xhtml "css/css-flexbox/flexbox-basic-canvas-vert-001v.xhtml")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-basic-canvas-vert-001v.xhtml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-basic-canvas-vert-001v.xhtml)
- [flexbox-basic-canvas-vert-001.xhtml](https://wpt.fyi/results/css/css-flexbox/flexbox-basic-canvas-vert-001.xhtml "css/css-flexbox/flexbox-basic-canvas-vert-001.xhtml")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-basic-canvas-vert-001.xhtml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-basic-canvas-vert-001.xhtml)
- [flexbox-basic-fieldset-horiz-001.xhtml](https://wpt.fyi/results/css/css-flexbox/flexbox-basic-fieldset-horiz-001.xhtml "css/css-flexbox/flexbox-basic-fieldset-horiz-001.xhtml")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-basic-fieldset-horiz-001.xhtml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-basic-fieldset-horiz-001.xhtml)
- [flexbox-basic-fieldset-vert-001.xhtml](https://wpt.fyi/results/css/css-flexbox/flexbox-basic-fieldset-vert-001.xhtml "css/css-flexbox/flexbox-basic-fieldset-vert-001.xhtml")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-basic-fieldset-vert-001.xhtml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-basic-fieldset-vert-001.xhtml)
- [flexbox-basic-iframe-horiz-001.xhtml](https://wpt.fyi/results/css/css-flexbox/flexbox-basic-iframe-horiz-001.xhtml "css/css-flexbox/flexbox-basic-iframe-horiz-001.xhtml")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-basic-iframe-horiz-001.xhtml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-basic-iframe-horiz-001.xhtml)
- [flexbox-basic-iframe-vert-001.xhtml](https://wpt.fyi/results/css/css-flexbox/flexbox-basic-iframe-vert-001.xhtml "css/css-flexbox/flexbox-basic-iframe-vert-001.xhtml")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-basic-iframe-vert-001.xhtml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-basic-iframe-vert-001.xhtml)
- [flexbox-basic-img-horiz-001.xhtml](https://wpt.fyi/results/css/css-flexbox/flexbox-basic-img-horiz-001.xhtml "css/css-flexbox/flexbox-basic-img-horiz-001.xhtml")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-basic-img-horiz-001.xhtml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-basic-img-horiz-001.xhtml)
- [flexbox-basic-img-vert-001.xhtml](https://wpt.fyi/results/css/css-flexbox/flexbox-basic-img-vert-001.xhtml "css/css-flexbox/flexbox-basic-img-vert-001.xhtml")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-basic-img-vert-001.xhtml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-basic-img-vert-001.xhtml)
- [flexbox-basic-textarea-horiz-001.xhtml](https://wpt.fyi/results/css/css-flexbox/flexbox-basic-textarea-horiz-001.xhtml "css/css-flexbox/flexbox-basic-textarea-horiz-001.xhtml")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-basic-textarea-horiz-001.xhtml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-basic-textarea-horiz-001.xhtml)
- [flexbox-basic-textarea-vert-001.xhtml](https://wpt.fyi/results/css/css-flexbox/flexbox-basic-textarea-vert-001.xhtml "css/css-flexbox/flexbox-basic-textarea-vert-001.xhtml")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-basic-textarea-vert-001.xhtml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-basic-textarea-vert-001.xhtml)
- [flexbox-basic-video-horiz-001.xhtml](https://wpt.fyi/results/css/css-flexbox/flexbox-basic-video-horiz-001.xhtml "css/css-flexbox/flexbox-basic-video-horiz-001.xhtml")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-basic-video-horiz-001.xhtml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-basic-video-horiz-001.xhtml)
- [flexbox-basic-video-vert-001.xhtml](https://wpt.fyi/results/css/css-flexbox/flexbox-basic-video-vert-001.xhtml "css/css-flexbox/flexbox-basic-video-vert-001.xhtml")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-basic-video-vert-001.xhtml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-basic-video-vert-001.xhtml)
- [flexbox-dyn-resize-001.html](https://wpt.fyi/results/css/css-flexbox/flexbox-dyn-resize-001.html "css/css-flexbox/flexbox-dyn-resize-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-dyn-resize-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-dyn-resize-001.html)
- [flexbox-mbp-horiz-001-rtl.xhtml](https://wpt.fyi/results/css/css-flexbox/flexbox-mbp-horiz-001-rtl.xhtml "css/css-flexbox/flexbox-mbp-horiz-001-rtl.xhtml")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-mbp-horiz-001-rtl.xhtml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-mbp-horiz-001-rtl.xhtml)
- [flexbox-mbp-horiz-001.xhtml](https://wpt.fyi/results/css/css-flexbox/flexbox-mbp-horiz-001.xhtml "css/css-flexbox/flexbox-mbp-horiz-001.xhtml")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-mbp-horiz-001.xhtml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-mbp-horiz-001.xhtml)
- [flexbox-mbp-horiz-002a.xhtml](https://wpt.fyi/results/css/css-flexbox/flexbox-mbp-horiz-002a.xhtml "css/css-flexbox/flexbox-mbp-horiz-002a.xhtml")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-mbp-horiz-002a.xhtml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-mbp-horiz-002a.xhtml)
- [flexbox-mbp-horiz-002b.xhtml](https://wpt.fyi/results/css/css-flexbox/flexbox-mbp-horiz-002b.xhtml "css/css-flexbox/flexbox-mbp-horiz-002b.xhtml")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-mbp-horiz-002b.xhtml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-mbp-horiz-002b.xhtml)
- [flexbox-mbp-horiz-002v.xhtml](https://wpt.fyi/results/css/css-flexbox/flexbox-mbp-horiz-002v.xhtml "css/css-flexbox/flexbox-mbp-horiz-002v.xhtml")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-mbp-horiz-002v.xhtml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-mbp-horiz-002v.xhtml)
- [flexbox-mbp-horiz-003-reverse.xhtml](https://wpt.fyi/results/css/css-flexbox/flexbox-mbp-horiz-003-reverse.xhtml "css/css-flexbox/flexbox-mbp-horiz-003-reverse.xhtml")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-mbp-horiz-003-reverse.xhtml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-mbp-horiz-003-reverse.xhtml)
- [flexbox-mbp-horiz-003v.xhtml](https://wpt.fyi/results/css/css-flexbox/flexbox-mbp-horiz-003v.xhtml "css/css-flexbox/flexbox-mbp-horiz-003v.xhtml")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-mbp-horiz-003v.xhtml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-mbp-horiz-003v.xhtml)
- [flexbox-mbp-horiz-003.xhtml](https://wpt.fyi/results/css/css-flexbox/flexbox-mbp-horiz-003.xhtml "css/css-flexbox/flexbox-mbp-horiz-003.xhtml")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-mbp-horiz-003.xhtml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-mbp-horiz-003.xhtml)
- [flexbox-mbp-horiz-004.xhtml](https://wpt.fyi/results/css/css-flexbox/flexbox-mbp-horiz-004.xhtml "css/css-flexbox/flexbox-mbp-horiz-004.xhtml")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-mbp-horiz-004.xhtml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-mbp-horiz-004.xhtml)
- [flexbox-sizing-horiz-001.xhtml](https://wpt.fyi/results/css/css-flexbox/flexbox-sizing-horiz-001.xhtml "css/css-flexbox/flexbox-sizing-horiz-001.xhtml")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-sizing-horiz-001.xhtml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-sizing-horiz-001.xhtml)
- [flexbox-sizing-horiz-002.xhtml](https://wpt.fyi/results/css/css-flexbox/flexbox-sizing-horiz-002.xhtml "css/css-flexbox/flexbox-sizing-horiz-002.xhtml")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-sizing-horiz-002.xhtml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-sizing-horiz-002.xhtml)
- [flexbox-sizing-vert-001.xhtml](https://wpt.fyi/results/css/css-flexbox/flexbox-sizing-vert-001.xhtml "css/css-flexbox/flexbox-sizing-vert-001.xhtml")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-sizing-vert-001.xhtml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-sizing-vert-001.xhtml)
- [flexbox-sizing-vert-002.xhtml](https://wpt.fyi/results/css/css-flexbox/flexbox-sizing-vert-002.xhtml "css/css-flexbox/flexbox-sizing-vert-002.xhtml")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-sizing-vert-002.xhtml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-sizing-vert-002.xhtml)
- [percentage-max-height-001.html](https://wpt.fyi/results/css/css-flexbox/percentage-max-height-001.html "css/css-flexbox/percentage-max-height-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/percentage-max-height-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/percentage-max-height-001.html)
- [percentage-max-height-002.html](https://wpt.fyi/results/css/css-flexbox/percentage-max-height-002.html "css/css-flexbox/percentage-max-height-002.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/percentage-max-height-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/percentage-max-height-002.html)
- [percentage-max-height-003.html](https://wpt.fyi/results/css/css-flexbox/percentage-max-height-003.html "css/css-flexbox/percentage-max-height-003.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/percentage-max-height-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/percentage-max-height-003.html)
- [percentage-max-height-004.html](https://wpt.fyi/results/css/css-flexbox/percentage-max-height-004.html "css/css-flexbox/percentage-max-height-004.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/percentage-max-height-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/percentage-max-height-004.html)
- [percentage-max-height-005.html](https://wpt.fyi/results/css/css-flexbox/percentage-max-height-005.html "css/css-flexbox/percentage-max-height-005.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/percentage-max-height-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/percentage-max-height-005.html)
- [percent-height-flex-items-cross-sizes-with-mutations.html](https://wpt.fyi/results/css/css-flexbox/percent-height-flex-items-cross-sizes-with-mutations.html "css/css-flexbox/percent-height-flex-items-cross-sizes-with-mutations.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/percent-height-flex-items-cross-sizes-with-mutations.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/percent-height-flex-items-cross-sizes-with-mutations.html)
- [table-as-item-auto-min-width.html](https://wpt.fyi/results/css/css-flexbox/table-as-item-auto-min-width.html "css/css-flexbox/table-as-item-auto-min-width.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/table-as-item-auto-min-width.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/table-as-item-auto-min-width.html)
- [table-as-item-change-cell.html](https://wpt.fyi/results/css/css-flexbox/table-as-item-change-cell.html "css/css-flexbox/table-as-item-change-cell.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/table-as-item-change-cell.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/table-as-item-change-cell.html)
- [table-as-item-fixed-min-width-2.html](https://wpt.fyi/results/css/css-flexbox/table-as-item-fixed-min-width-2.html "css/css-flexbox/table-as-item-fixed-min-width-2.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/table-as-item-fixed-min-width-2.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/table-as-item-fixed-min-width-2.html)
- [table-as-item-fixed-min-width-3.html](https://wpt.fyi/results/css/css-flexbox/table-as-item-fixed-min-width-3.html "css/css-flexbox/table-as-item-fixed-min-width-3.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/table-as-item-fixed-min-width-3.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/table-as-item-fixed-min-width-3.html)
- [table-as-item-fixed-min-width.html](https://wpt.fyi/results/css/css-flexbox/table-as-item-fixed-min-width.html "css/css-flexbox/table-as-item-fixed-min-width.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/table-as-item-fixed-min-width.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/table-as-item-fixed-min-width.html)
- [table-as-item-narrow-content-2.html](https://wpt.fyi/results/css/css-flexbox/table-as-item-narrow-content-2.html "css/css-flexbox/table-as-item-narrow-content-2.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/table-as-item-narrow-content-2.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/table-as-item-narrow-content-2.html)
- [table-as-item-narrow-content.html](https://wpt.fyi/results/css/css-flexbox/table-as-item-narrow-content.html "css/css-flexbox/table-as-item-narrow-content.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/table-as-item-narrow-content.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/table-as-item-narrow-content.html)
- [table-as-item-specified-height.html](https://wpt.fyi/results/css/css-flexbox/table-as-item-specified-height.html "css/css-flexbox/table-as-item-specified-height.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/table-as-item-specified-height.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/table-as-item-specified-height.html)
- [table-as-item-specified-width.html](https://wpt.fyi/results/css/css-flexbox/table-as-item-specified-width.html "css/css-flexbox/table-as-item-specified-width.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/table-as-item-specified-width.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/table-as-item-specified-width.html)
- [table-as-item-specified-width-vertical.html](https://wpt.fyi/results/css/css-flexbox/table-as-item-specified-width-vertical.html "css/css-flexbox/table-as-item-specified-width-vertical.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/table-as-item-specified-width-vertical.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/table-as-item-specified-width-vertical.html)

### 9.1. Initial Setup

1. [(#algo-anon-box) **Generate anonymous flex items** as
 described in [§ 4 Flex Items](#flex-items).]

### 9.2. Line Length Determination

1. [(#algo-available) **Determine the available main and
 cross space for the flex items.** For each dimension, if that
 dimension of the [flex
 container](#flex-container)'s content box is a [definite
 size](#definite), use that; if
 that dimension of the [flex container] is
 being sized under a
 [min](https://drafts.csswg.org/css-sizing-3/#min-content-constraint) or [max-content
 constraint](https://drafts.csswg.org/css-sizing-3/#max-content-constraint), the available space in that dimension is that
 constraint; otherwise, subtract the [flex
 container]'s margin, border, and padding
 from the space available to the flex container in that dimension and
 use that value. [This might result in an infinite
 value.]]

 :::
 (#example-34f93ad9)
 For example, the [available
 space](https://drafts.csswg.org/css-sizing-3/#available) to a flex item in a
 [floated](https://www.w3.org/TR/CSS2/visuren.html#floats)
 [auto](https://drafts.csswg.org/css-sizing-3/#valdef-width-auto)-sized [flex
 container](#flex-container) is:

 - the width of the [flex
 container](#flex-container)'s containing block minus the [flex
 container]'s margin, border, and
 padding in the horizontal dimension
 - infinite in the vertical dimension
 :::

2. [(#algo-main-item) **Determine the [flex base
 size]
 and [hypothetical main size] of each
 item:**]

 Tests

 - [flex-item-percentage-height-img-001.html](https://wpt.fyi/results/css/css-flexbox/flex-item-percentage-height-img-001.html "css/css-flexbox/flex-item-percentage-height-img-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-item-percentage-height-img-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-item-percentage-height-img-001.html)
 - [image-as-flexitem-size-001.html](https://wpt.fyi/results/css/css-flexbox/image-as-flexitem-size-001.html "css/css-flexbox/image-as-flexitem-size-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/image-as-flexitem-size-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/image-as-flexitem-size-001.html)
 - [image-as-flexitem-size-001v.html](https://wpt.fyi/results/css/css-flexbox/image-as-flexitem-size-001v.html "css/css-flexbox/image-as-flexitem-size-001v.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/image-as-flexitem-size-001v.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/image-as-flexitem-size-001v.html)
 - [image-as-flexitem-size-002.html](https://wpt.fyi/results/css/css-flexbox/image-as-flexitem-size-002.html "css/css-flexbox/image-as-flexitem-size-002.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/image-as-flexitem-size-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/image-as-flexitem-size-002.html)
 - [image-as-flexitem-size-002v.html](https://wpt.fyi/results/css/css-flexbox/image-as-flexitem-size-002v.html "css/css-flexbox/image-as-flexitem-size-002v.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/image-as-flexitem-size-002v.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/image-as-flexitem-size-002v.html)
 - [image-as-flexitem-size-003.html](https://wpt.fyi/results/css/css-flexbox/image-as-flexitem-size-003.html "css/css-flexbox/image-as-flexitem-size-003.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/image-as-flexitem-size-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/image-as-flexitem-size-003.html)
 - [image-as-flexitem-size-003v.html](https://wpt.fyi/results/css/css-flexbox/image-as-flexitem-size-003v.html "css/css-flexbox/image-as-flexitem-size-003v.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/image-as-flexitem-size-003v.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/image-as-flexitem-size-003v.html)
 - [image-as-flexitem-size-004.html](https://wpt.fyi/results/css/css-flexbox/image-as-flexitem-size-004.html "css/css-flexbox/image-as-flexitem-size-004.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/image-as-flexitem-size-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/image-as-flexitem-size-004.html)
 - [image-as-flexitem-size-004v.html](https://wpt.fyi/results/css/css-flexbox/image-as-flexitem-size-004v.html "css/css-flexbox/image-as-flexitem-size-004v.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/image-as-flexitem-size-004v.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/image-as-flexitem-size-004v.html)
 - [image-as-flexitem-size-005.html](https://wpt.fyi/results/css/css-flexbox/image-as-flexitem-size-005.html "css/css-flexbox/image-as-flexitem-size-005.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/image-as-flexitem-size-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/image-as-flexitem-size-005.html)
 - [image-as-flexitem-size-005v.html](https://wpt.fyi/results/css/css-flexbox/image-as-flexitem-size-005v.html "css/css-flexbox/image-as-flexitem-size-005v.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/image-as-flexitem-size-005v.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/image-as-flexitem-size-005v.html)
 - [image-as-flexitem-size-006.html](https://wpt.fyi/results/css/css-flexbox/image-as-flexitem-size-006.html "css/css-flexbox/image-as-flexitem-size-006.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/image-as-flexitem-size-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/image-as-flexitem-size-006.html)
 - [image-as-flexitem-size-006v.html](https://wpt.fyi/results/css/css-flexbox/image-as-flexitem-size-006v.html "css/css-flexbox/image-as-flexitem-size-006v.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/image-as-flexitem-size-006v.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/image-as-flexitem-size-006v.html)
 - [image-as-flexitem-size-007.html](https://wpt.fyi/results/css/css-flexbox/image-as-flexitem-size-007.html "css/css-flexbox/image-as-flexitem-size-007.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/image-as-flexitem-size-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/image-as-flexitem-size-007.html)
 - [image-as-flexitem-size-007v.html](https://wpt.fyi/results/css/css-flexbox/image-as-flexitem-size-007v.html "css/css-flexbox/image-as-flexitem-size-007v.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/image-as-flexitem-size-007v.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/image-as-flexitem-size-007v.html)
 - [item-with-table-with-infinite-max-intrinsic-width.html](https://wpt.fyi/results/css/css-flexbox/item-with-table-with-infinite-max-intrinsic-width.html "css/css-flexbox/item-with-table-with-infinite-max-intrinsic-width.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/item-with-table-with-infinite-max-intrinsic-width.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/item-with-table-with-infinite-max-intrinsic-width.html)
 - [multiline-min-max.html](https://wpt.fyi/results/css/css-flexbox/multiline-min-max.html "css/css-flexbox/multiline-min-max.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/multiline-min-max.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/multiline-min-max.html)
 - [orthogonal-writing-modes-and-intrinsic-sizing.html](https://wpt.fyi/results/css/css-flexbox/orthogonal-writing-modes-and-intrinsic-sizing.html "css/css-flexbox/orthogonal-writing-modes-and-intrinsic-sizing.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/orthogonal-writing-modes-and-intrinsic-sizing.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/orthogonal-writing-modes-and-intrinsic-sizing.html)
 - [svg-root-as-flex-item-001.html](https://wpt.fyi/results/css/css-flexbox/svg-root-as-flex-item-001.html "css/css-flexbox/svg-root-as-flex-item-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/svg-root-as-flex-item-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/svg-root-as-flex-item-001.html)
 - [svg-root-as-flex-item-002.html](https://wpt.fyi/results/css/css-flexbox/svg-root-as-flex-item-002.html "css/css-flexbox/svg-root-as-flex-item-002.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/svg-root-as-flex-item-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/svg-root-as-flex-item-002.html)
 - [svg-root-as-flex-item-003.html](https://wpt.fyi/results/css/css-flexbox/svg-root-as-flex-item-003.html "css/css-flexbox/svg-root-as-flex-item-003.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/svg-root-as-flex-item-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/svg-root-as-flex-item-003.html)
 - [svg-root-as-flex-item-004.html](https://wpt.fyi/results/css/css-flexbox/svg-root-as-flex-item-004.html "css/css-flexbox/svg-root-as-flex-item-004.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/svg-root-as-flex-item-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/svg-root-as-flex-item-004.html)
 - [svg-root-as-flex-item-005.html](https://wpt.fyi/results/css/css-flexbox/svg-root-as-flex-item-005.html "css/css-flexbox/svg-root-as-flex-item-005.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/svg-root-as-flex-item-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/svg-root-as-flex-item-005.html)
 - [svg-root-as-flex-item-006.html](https://wpt.fyi/results/css/css-flexbox/svg-root-as-flex-item-006.html "css/css-flexbox/svg-root-as-flex-item-006.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/svg-root-as-flex-item-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/svg-root-as-flex-item-006.html)
 - [table-as-item-min-height-1.html](https://wpt.fyi/results/css/css-flexbox/table-as-item-min-height-1.html "css/css-flexbox/table-as-item-min-height-1.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/table-as-item-min-height-1.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/table-as-item-min-height-1.html)
 - [table-as-item-wide-content.html](https://wpt.fyi/results/css/css-flexbox/table-as-item-wide-content.html "css/css-flexbox/table-as-item-wide-content.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/table-as-item-wide-content.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/table-as-item-wide-content.html)
 - [table-with-infinite-max-intrinsic-width.html](https://wpt.fyi/results/css/css-flexbox/table-with-infinite-max-intrinsic-width.html "css/css-flexbox/table-with-infinite-max-intrinsic-width.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/table-with-infinite-max-intrinsic-width.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/table-with-infinite-max-intrinsic-width.html)

 A. If the item has a [definite](#definite) used [flex
 basis](#flex-flex-basis), that's the [flex base
 size](#flex-base-size).

 B. If the flex item has \...
 - a [preferred aspect
 ratio](https://drafts.csswg.org/css-sizing-4/#preferred-aspect-ratio),
 - a used [flex
 basis](#flex-flex-basis) of
 [content](#valdef-flex-basis-content), and
 - a [definite](#definite)
 [cross size](#cross-size),

 then the [flex base
 size](#flex-base-size)
 is calculated from its
 [used](https://drafts.csswg.org/css-cascade-5/#used-value) [cross size](#cross-size) and the [flex
 item](#flex-item)'s aspect
 ratio.

 C. If the used [flex
 basis](#flex-flex-basis) is
 [content](#valdef-flex-basis-content) or depends on its [available
 space](https://drafts.csswg.org/css-sizing-3/#available), and the flex container is being sized under a
 min-content or max-content constraint (e.g. when performing
 [automatic table
 layout](https://www.w3.org/TR/CSS2/tables.html#auto-table-layout)
 [\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")),
 size the item under that constraint. The [flex base
 size](#flex-base-size)
 is the item's resulting [main
 size](#main-size).

 D. Otherwise, if the used [flex
 basis](#flex-flex-basis) is
 [content](#valdef-flex-basis-content) or depends on its [available
 space](https://drafts.csswg.org/css-sizing-3/#available), the available main size is infinite, and the
 flex item's inline axis is parallel to the main axis, lay the
 item out using [the rules for a box in an orthogonal
 flow](https://www.w3.org/TR/css3-writing-modes/#orthogonal-flows)
 [\[CSS3-WRITING-MODES\]](#biblio-css3-writing-modes "CSS Writing Modes Level 3").
 The [flex base size](#flex-base-size) is the item's max-content [main
 size](#main-size).

 This case occurs, for example, in an English
 document (horizontal [writing
 mode](https://drafts.csswg.org/css-writing-modes-4/#writing-mode)) containing a column flex container containing
 a vertical Japanese (vertical [writing
 mode]) [flex
 item](#flex-item).

 E. Otherwise, size the item into the [available
 space](https://drafts.csswg.org/css-sizing-3/#available) using its used [flex
 basis](#flex-flex-basis) in place of its [main
 size](#main-size),
 treating a value of
 [content](#valdef-flex-basis-content) as
 [max-content](https://drafts.csswg.org/css-sizing-3/#valdef-width-max-content). If a [cross
 size](#cross-size) is
 needed to determine the [main size] (e.g.
 when the [flex item](#flex-item)'s [main size] is in its
 block axis, or when it has a [preferred aspect
 ratio](https://drafts.csswg.org/css-sizing-4/#preferred-aspect-ratio)) and the [flex item]'s
 cross size is
 [auto](#valdef-flex-basis-auto) and not
 [definite](#definite), in
 this calculation use
 [fit-content](https://drafts.csswg.org/css-sizing-3/#valdef-width-fit-content) as the [flex
 item]'s [cross
 size]. The [flex base
 size](#flex-base-size)
 is the item's resulting [main size].
 Tests
 - [css-flexbox-img-expand-evenly.html](https://wpt.fyi/results/css/css-flexbox/css-flexbox-img-expand-evenly.html "css/css-flexbox/css-flexbox-img-expand-evenly.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/css-flexbox-img-expand-evenly.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/css-flexbox-img-expand-evenly.html)
 - [fit-content-item-001.html](https://wpt.fyi/results/css/css-flexbox/fit-content-item-001.html "css/css-flexbox/fit-content-item-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/fit-content-item-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/fit-content-item-001.html)
 - [fit-content-item-002.html](https://wpt.fyi/results/css/css-flexbox/fit-content-item-002.html "css/css-flexbox/fit-content-item-002.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/fit-content-item-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/fit-content-item-002.html)
 - [fit-content-item-003.html](https://wpt.fyi/results/css/css-flexbox/fit-content-item-003.html "css/css-flexbox/fit-content-item-003.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/fit-content-item-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/fit-content-item-003.html)
 - [fit-content-item-004.html](https://wpt.fyi/results/css/css-flexbox/fit-content-item-004.html "css/css-flexbox/fit-content-item-004.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/fit-content-item-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/fit-content-item-004.html)
 - [flexbox-vert-lr-with-img.html](https://wpt.fyi/results/css/css-flexbox/flexbox-vert-lr-with-img.html "css/css-flexbox/flexbox-vert-lr-with-img.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-vert-lr-with-img.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-vert-lr-with-img.html)
 - [flex-container-max-content-001.html](https://wpt.fyi/results/css/css-flexbox/flex-container-max-content-001.html "css/css-flexbox/flex-container-max-content-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-container-max-content-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-container-max-content-001.html)
 - [flex-container-min-content-001.html](https://wpt.fyi/results/css/css-flexbox/flex-container-min-content-001.html "css/css-flexbox/flex-container-min-content-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-container-min-content-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-container-min-content-001.html)
 - [flex-height-min-content.html](https://wpt.fyi/results/css/css-flexbox/flex-height-min-content.html "css/css-flexbox/flex-height-min-content.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-height-min-content.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-height-min-content.html)

 When determining the [flex base
 size](#flex-base-size),
 the item's min and max [main sizes](#main-size) are ignored (no clamping occurs). Furthermore, the
 sizing calculations that floor the content box size at zero when
 applying
 [box-sizing](https://drafts.csswg.org/css-sizing-3/#propdef-box-sizing) are also ignored. (For example,
 an item with a specified size of zero, positive padding, and
 [box-sizing: border-box] will
 have an outer [flex base size] of
 zero---​and hence a negative inner [flex base
 size].)

 The [hypothetical main
 size](#hypothetical-main-size) is the item's [flex base
 size](#flex-base-size)
 clamped according to its
 [used](https://drafts.csswg.org/css-cascade-5/#used-value) min and max [main
 sizes](#main-size) (and
 flooring the content box size at zero).

 Tests

 - [text-as-flexitem-size-001.html](https://wpt.fyi/results/css/css-flexbox/text-as-flexitem-size-001.html "css/css-flexbox/text-as-flexitem-size-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/text-as-flexitem-size-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/text-as-flexitem-size-001.html)

3. [(#algo-main-container) **Determine the [main
 size](#main-size) of the flex
 container** using the rules of the formatting context in which it
 participates.]

 :::
 The [automatic block
 size](https://drafts.csswg.org/css-sizing-3/#automatic-block-size) of a
 [block-level](https://drafts.csswg.org/css-display-4/#block-level) [flex
 container](#flex-container) is its [max-content
 size](https://drafts.csswg.org/css-sizing-3/#max-content).
 The Block Layout spec should define this equivalency, but it doesn't
 exist yet.
 :::

### 9.3. Main Size Determination

1. [(#algo-line-break) **Collect flex items into flex
 lines:**]
 - If the flex container is
 [single-line](#single-line-flex-container), collect all the flex items into a single flex
 line.

 - Otherwise, starting from the first uncollected item, collect
 consecutive items one by one until the first time that the *next*
 collected item would not fit into the flex container's
 [inner](https://drafts.csswg.org/css-sizing-3/#inner-size) main size (or until a forced break is
 encountered, see [§ 10 Fragmenting Flex Layout](#pagination)). If
 the very first uncollected item wouldn't fit, collect just it into
 the line.

 For this step, the size of a flex item is its
 [outer](https://drafts.csswg.org/css-sizing-3/#outer-size) [hypothetical main
 size](#hypothetical-main-size). [(Note: This can be negative.)]

 Repeat until all flex items have been collected into flex lines.

 Note that the \"collect as many\" line will collect zero-sized
 flex items onto the end of the previous line even if the last
 non-zero item exactly \"filled up\" the line.
2. [(#algo-flex) **[Resolve the flexible
 lengths](#resolve-flexible-lengths)** of all the flex items to find
 their used [main size](#main-size). See [§ 9.7 Resolving Flexible
 Lengths](#resolve-flexible-lengths).]

Tests

- [flexbox_quirks_body.html](https://wpt.fyi/results/css/css-flexbox/flexbox_quirks_body.html "css/css-flexbox/flexbox_quirks_body.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_quirks_body.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_quirks_body.html)
- [ortho-table-item-001.html](https://wpt.fyi/results/css/css-flexbox/ortho-table-item-001.html "css/css-flexbox/ortho-table-item-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/ortho-table-item-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/ortho-table-item-001.html)
- [percentage-heights-000.html](https://wpt.fyi/results/css/css-flexbox/percentage-heights-000.html "css/css-flexbox/percentage-heights-000.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/percentage-heights-000.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/percentage-heights-000.html)
- [percentage-heights-001.html](https://wpt.fyi/results/css/css-flexbox/percentage-heights-001.html "css/css-flexbox/percentage-heights-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/percentage-heights-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/percentage-heights-001.html)
- [percentage-heights-002.html](https://wpt.fyi/results/css/css-flexbox/percentage-heights-002.html "css/css-flexbox/percentage-heights-002.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/percentage-heights-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/percentage-heights-002.html)
- [percentage-heights-003.html](https://wpt.fyi/results/css/css-flexbox/percentage-heights-003.html "css/css-flexbox/percentage-heights-003.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/percentage-heights-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/percentage-heights-003.html)
- [percentage-heights-004.html](https://wpt.fyi/results/css/css-flexbox/percentage-heights-004.html "css/css-flexbox/percentage-heights-004.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/percentage-heights-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/percentage-heights-004.html)
- [percentage-heights-005.html](https://wpt.fyi/results/css/css-flexbox/percentage-heights-005.html "css/css-flexbox/percentage-heights-005.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/percentage-heights-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/percentage-heights-005.html)
- [percentage-heights-006.html](https://wpt.fyi/results/css/css-flexbox/percentage-heights-006.html "css/css-flexbox/percentage-heights-006.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/percentage-heights-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/percentage-heights-006.html)
- [percentage-heights-007.html](https://wpt.fyi/results/css/css-flexbox/percentage-heights-007.html "css/css-flexbox/percentage-heights-007.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/percentage-heights-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/percentage-heights-007.html)
- [percentage-heights-008.html](https://wpt.fyi/results/css/css-flexbox/percentage-heights-008.html "css/css-flexbox/percentage-heights-008.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/percentage-heights-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/percentage-heights-008.html)
- [percentage-heights-009.html](https://wpt.fyi/results/css/css-flexbox/percentage-heights-009.html "css/css-flexbox/percentage-heights-009.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/percentage-heights-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/percentage-heights-009.html)
- [percentage-heights-010.html](https://wpt.fyi/results/css/css-flexbox/percentage-heights-010.html "css/css-flexbox/percentage-heights-010.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/percentage-heights-010.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/percentage-heights-010.html)
- [percentage-heights-011.html](https://wpt.fyi/results/css/css-flexbox/percentage-heights-011.html "css/css-flexbox/percentage-heights-011.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/percentage-heights-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/percentage-heights-011.html)
- [percentage-heights-012.html](https://wpt.fyi/results/css/css-flexbox/percentage-heights-012.html "css/css-flexbox/percentage-heights-012.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/percentage-heights-012.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/percentage-heights-012.html)
- [percentage-heights-013.html](https://wpt.fyi/results/css/css-flexbox/percentage-heights-013.html "css/css-flexbox/percentage-heights-013.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/percentage-heights-013.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/percentage-heights-013.html)
- [percentage-heights-014.html](https://wpt.fyi/results/css/css-flexbox/percentage-heights-014.html "css/css-flexbox/percentage-heights-014.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/percentage-heights-014.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/percentage-heights-014.html)
- [percentage-heights-015.html](https://wpt.fyi/results/css/css-flexbox/percentage-heights-015.html "css/css-flexbox/percentage-heights-015.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/percentage-heights-015.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/percentage-heights-015.html)
- [percentage-heights-016.html](https://wpt.fyi/results/css/css-flexbox/percentage-heights-016.html "css/css-flexbox/percentage-heights-016.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/percentage-heights-016.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/percentage-heights-016.html)
- [percentage-heights-017.html](https://wpt.fyi/results/css/css-flexbox/percentage-heights-017.html "css/css-flexbox/percentage-heights-017.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/percentage-heights-017.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/percentage-heights-017.html)
- [percentage-heights-018.html](https://wpt.fyi/results/css/css-flexbox/percentage-heights-018.html "css/css-flexbox/percentage-heights-018.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/percentage-heights-018.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/percentage-heights-018.html)
- [percentage-heights-019.html](https://wpt.fyi/results/css/css-flexbox/percentage-heights-019.html "css/css-flexbox/percentage-heights-019.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/percentage-heights-019.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/percentage-heights-019.html)
- [percentage-heights-020.html](https://wpt.fyi/results/css/css-flexbox/percentage-heights-020.html "css/css-flexbox/percentage-heights-020.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/percentage-heights-020.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/percentage-heights-020.html)
- [percentage-heights-021.html](https://wpt.fyi/results/css/css-flexbox/percentage-heights-021.html "css/css-flexbox/percentage-heights-021.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/percentage-heights-021.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/percentage-heights-021.html)
- [percentage-heights-022.html](https://wpt.fyi/results/css/css-flexbox/percentage-heights-022.html "css/css-flexbox/percentage-heights-022.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/percentage-heights-022.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/percentage-heights-022.html)
- [percentage-heights-023.html](https://wpt.fyi/results/css/css-flexbox/percentage-heights-023.html "css/css-flexbox/percentage-heights-023.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/percentage-heights-023.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/percentage-heights-023.html)

### 9.4. Cross Size Determination

1. [(#algo-cross-item) **Determine the [hypothetical
 cross size] of each item** by performing layout as
 if it were an
 [in-flow](https://drafts.csswg.org/css-display-4/#in-flow) [block-level
 box](https://drafts.csswg.org/css-display-4/#block-level-box) with the used [main
 size](#main-size) and the
 given available space, treating
 [auto](https://drafts.csswg.org/css-sizing-3/#valdef-width-auto) as
 [fit-content](https://drafts.csswg.org/css-sizing-3/#valdef-width-fit-content).]
 Tests
 - [canvas-contain-size.html](https://wpt.fyi/results/css/css-flexbox/canvas-contain-size.html "css/css-flexbox/canvas-contain-size.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/canvas-contain-size.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/canvas-contain-size.html)
 - [inline-flex-column-image-load.html](https://wpt.fyi/results/css/css-flexbox/inline-flex-column-image-load.html "css/css-flexbox/inline-flex-column-image-load.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/inline-flex-column-image-load.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/inline-flex-column-image-load.html)

2. [(#algo-cross-line) **Calculate the cross size of each
 flex line.**]

 If the flex container is
 [single-line](#single-line-flex-container) and has a [definite](#definite) [cross size](#cross-size), the [cross size] of the
 [flex line](#flex-line) is the
 [flex container](#flex-container)'s inner [cross size].

 Otherwise, for each flex line:

 1. Collect all the flex items whose inline-axis is parallel to the
 main-axis, whose
 [align-self](#propdef-align-self) is
 [baseline](#valdef-align-items-baseline), and whose cross-axis margins are both
 non-[auto]. Find the largest of the
 distances between each item's baseline and its hypothetical
 outer cross-start edge, and the largest of the distances between
 each item's baseline and its hypothetical outer cross-end edge,
 and sum these two values.

 2. Among all the items not collected by the previous step, find the
 largest outer [hypothetical cross
 size](#hypothetical-cross-size).

 3. The used [cross size](#cross-size) of the [flex
 line](#flex-line) is the
 largest of the numbers found in the previous two steps and zero.

 If the flex container is
 [single-line](#single-line-flex-container), then clamp the line's cross-size to be within
 the container's computed min and max cross sizes. [Note that if
 CSS 2.1's definition of min/max-width/height applied more
 generally, this behavior would fall out automatically.]

 Tests

 - [flexbox-single-line-clamp-1.html](https://wpt.fyi/results/css/css-flexbox/flexbox-single-line-clamp-1.html "css/css-flexbox/flexbox-single-line-clamp-1.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-single-line-clamp-1.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-single-line-clamp-1.html)
 - [flexbox-single-line-clamp-2.html](https://wpt.fyi/results/css/css-flexbox/flexbox-single-line-clamp-2.html "css/css-flexbox/flexbox-single-line-clamp-2.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-single-line-clamp-2.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-single-line-clamp-2.html)
 - [flexbox-single-line-clamp-3.html](https://wpt.fyi/results/css/css-flexbox/flexbox-single-line-clamp-3.html "css/css-flexbox/flexbox-single-line-clamp-3.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-single-line-clamp-3.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-single-line-clamp-3.html)
 - [flex-item-contains-size-layout-001.html](https://wpt.fyi/results/css/css-flexbox/flex-item-contains-size-layout-001.html "css/css-flexbox/flex-item-contains-size-layout-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-item-contains-size-layout-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-item-contains-size-layout-001.html)
 - [flex-item-contains-strict.html](https://wpt.fyi/results/css/css-flexbox/flex-item-contains-strict.html "css/css-flexbox/flex-item-contains-strict.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-item-contains-strict.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-item-contains-strict.html)
 - [layout-algorithm_algo-cross-line-001.html](https://wpt.fyi/results/css/css-flexbox/layout-algorithm_algo-cross-line-001.html "css/css-flexbox/layout-algorithm_algo-cross-line-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/layout-algorithm_algo-cross-line-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/layout-algorithm_algo-cross-line-001.html)
 - [layout-algorithm_algo-cross-line-002.html](https://wpt.fyi/results/css/css-flexbox/layout-algorithm_algo-cross-line-002.html "css/css-flexbox/layout-algorithm_algo-cross-line-002.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/layout-algorithm_algo-cross-line-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/layout-algorithm_algo-cross-line-002.html)

3. [(#algo-line-stretch) **Handle \'align-content:
 stretch\'.** If the flex container has a
 [definite](#definite) [cross
 size](#cross-size),
 [align-content](#propdef-align-content) is
 [stretch](#valdef-align-content-stretch), and the sum of the flex lines\' cross sizes
 is less than the flex container's inner cross size, increase the
 cross size of each flex line by equal amounts such that the sum of
 their cross sizes exactly equals the flex container's inner cross
 size.]

4. [(#algo-visibility) **Collapse
 [visibility:collapse] items.** If any flex items have
 [visibility:
 collapse](https://drafts.csswg.org/css-display-4/#propdef-visibility), note the [cross
 size](#cross-size) of the
 line they're in as the item's `strut size`, and restart
 layout from the beginning.]

 In this second layout round, when [collecting items into
 lines](#algo-line-break), treat the collapsed items as having zero
 [main size](#main-size). For
 the rest of the algorithm following that step, ignore the collapsed
 items entirely (as if they were [display:none]) except that
 after [calculating the cross size of the lines](#algo-cross-line),
 if any line's cross size is less than the largest
 `strut size` among all the collapsed items in the line,
 set its cross size to that `strut size`.

 Skip this step in the second layout round.

 Tests

 - [flexbox-collapsed-item-baseline-001.html](https://wpt.fyi/results/css/css-flexbox/flexbox-collapsed-item-baseline-001.html "css/css-flexbox/flexbox-collapsed-item-baseline-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-collapsed-item-baseline-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-collapsed-item-baseline-001.html)
 - [flexbox-collapsed-item-horiz-001.html](https://wpt.fyi/results/css/css-flexbox/flexbox-collapsed-item-horiz-001.html "css/css-flexbox/flexbox-collapsed-item-horiz-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-collapsed-item-horiz-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-collapsed-item-horiz-001.html)
 - [flexbox-collapsed-item-horiz-002.html](https://wpt.fyi/results/css/css-flexbox/flexbox-collapsed-item-horiz-002.html "css/css-flexbox/flexbox-collapsed-item-horiz-002.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-collapsed-item-horiz-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-collapsed-item-horiz-002.html)
 - [flexbox-collapsed-item-horiz-003.html](https://wpt.fyi/results/css/css-flexbox/flexbox-collapsed-item-horiz-003.html "css/css-flexbox/flexbox-collapsed-item-horiz-003.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-collapsed-item-horiz-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-collapsed-item-horiz-003.html)

5. [(#algo-stretch) **Determine the used cross size of
 each flex item.** If a flex item's [cross
 size](#cross-size) depends on
 the available space in the [cross
 axis](#cross-axis),
 recalculate its cross size using the [flex
 line's](#flex-line) [cross
 size] (rather than the [flex
 container's](#flex-container)) as the available space. Otherwise, the used cross
 size is the item's [hypothetical cross
 size](#hypothetical-cross-size).]

 If the flex item's [cross size](#cross-size) changed as a result, redo layout for its contents,
 treating this used size as its definite cross size so that
 percentage-sized children can be resolved.

 Tests

 - [table-as-item-cross-size.html](https://wpt.fyi/results/css/css-flexbox/table-as-item-cross-size.html "css/css-flexbox/table-as-item-cross-size.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/table-as-item-cross-size.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/table-as-item-cross-size.html)

 This step does not affect the [main
 size](#main-size) of the flex
 item, even if it has a [preferred aspect
 ratio](https://drafts.csswg.org/css-sizing-4/#preferred-aspect-ratio).

Tests

- [flex-item-and-percentage-abspos.html](https://wpt.fyi/results/css/css-flexbox/flex-item-and-percentage-abspos.html "css/css-flexbox/flex-item-and-percentage-abspos.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-item-and-percentage-abspos.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-item-and-percentage-abspos.html)

### 9.5. Main-Axis Alignment

1. [(#algo-main-align) **Distribute any remaining free
 space.** For each flex line:]
 1. If the remaining free space is positive and at least one
 main-axis margin on this line is [auto],
 distribute the free space equally among these margins.
 Otherwise, set all auto margins to zero.
 2. Align the items along the main-axis per
 [justify-content](#propdef-justify-content).

### 9.6. Cross-Axis Alignment

1. [(#algo-cross-margins) **Resolve cross-axis
 [auto] margins.** If a flex item has
 [auto] cross-axis
 margins:]
 - If its outer cross size (treating those [auto] margins as zero) is less than the cross size of
 its flex line, distribute the difference in those sizes equally to
 the auto margins.
 - Otherwise, if the
 [block-start](https://drafts.csswg.org/css-writing-modes-4/#block-start) or
 [inline-start](https://drafts.csswg.org/css-writing-modes-4/#inline-start) margin (whichever is in the cross axis) is
 [auto], set it to zero. Set the opposite
 margin so that the outer cross size of the item equals the cross
 size of its flex line.
2. [(#algo-cross-align) **Align all flex items along the
 cross-axis** per
 [align-self](#propdef-align-self), if neither of the item's cross-axis
 margins are [auto].]
3. [(#algo-cross-container) **Determine the flex
 container's used cross size** using the rules of the [formatting
 context](https://drafts.csswg.org/css-display-4/#formatting-context) in which it participates. If a content-based [cross
 size](#cross-size) is needed,
 use the sum of the [flex lines](#flex-line)\' [cross
 sizes].]
4. [(#algo-line-align) **Align all flex lines** per
 [align-content](#propdef-align-content).]

### 9.7. Resolving Flexible Lengths

To resolve the flexible lengths of the items within a flex line:

1. **Determine the used flex factor**. Sum the outer hypothetical main
 sizes of all items on the line. If the sum is less than the flex
 container's inner [main size](#main-size), use the flex grow factor for the rest of this
 algorithm; otherwise, use the flex shrink factor.

2. Each item in the flex line has a [target main
 size], initially set to its [flex base
 size](#flex-base-size).
 Each item is initially *unfrozen* and may become *frozen*.

 An item's [target main
 size](#target-main-size)
 doesn't change after freezing.

3. **Size inflexible items.** Freeze, setting its [target main
 size](#target-main-size)
 to its [hypothetical main
 size](#hypothetical-main-size)...
 - any item that has a flex factor of zero
 - if using the [flex grow
 factor](#flex-flex-grow-factor): any item that has a [flex base
 size](#flex-base-size)
 greater than its [hypothetical main
 size](#hypothetical-main-size)
 - if using the [flex shrink
 factor](#flex-flex-shrink-factor): any item that has a [flex base
 size](#flex-base-size)
 smaller than its [hypothetical main
 size](#hypothetical-main-size)

4. **Calculate [initial free space].** Sum the outer sizes of
 all items on the line, and subtract this from the flex container's
 inner [main size](#main-size).
 For frozen items, use their outer [target main
 size](#target-main-size); for other items, use their outer [flex base
 size](#flex-base-size).

5. Loop:
 a. **Check for flexible items.** If all the flex items on the line
 are frozen, exit this loop.

 b. **Calculate the [remaining free space]** as for [initial
 free space](#initial-free-space), above. If the sum of the unfrozen flex items'
 flex factors is less than one, multiply the [initial free
 space] by this sum. If the
 magnitude of this value is less than the magnitude of the
 [remaining free
 space](#remaining-free-space), use this as the [remaining free
 space].

 c. If the [remaining free
 space](#remaining-free-space) is non-zero, **distribute it proportional to
 the flex factors**:

 If using the [flex grow factor](#flex-flex-grow-factor)
 : For every unfrozen item on the line, find the ratio of the
 item's flex grow factor to the sum of the flex grow factors
 of all unfrozen items on the line. Set the item's [target
 main size](#target-main-size) to its [flex base
 size](#flex-base-size) plus a fraction of the [remaining free
 space](#remaining-free-space) proportional to the ratio.

 If using the [flex shrink factor](#flex-flex-shrink-factor)
 : For every unfrozen item on the line, multiply its flex
 shrink factor by its inner [flex base
 size](#flex-base-size), and note this as its [scaled flex shrink
 factor]. Find the ratio of the item's
 [scaled flex shrink
 factor](#scaled-flex-shrink-factor) to the sum of the [scaled flex shrink
 factors] of all
 unfrozen items on the line. Set the item's [target main
 size](#target-main-size) to its [flex base
 size] minus a fraction of the
 absolute value of the [remaining free
 space](#remaining-free-space) proportional to the ratio. [Note this may
 result in a negative inner [main
 size](#main-size); it
 will be corrected in the next step.]

 d. **Fix min/max violations.** Clamp each non-frozen item's [target
 main size](#target-main-size) by its
 [used](https://drafts.csswg.org/css-cascade-5/#used-value) min and max [main
 sizes](#main-size) and
 floor its content-box size at zero. If the item's [target main
 size] was made smaller by this, it's
 a max violation. If the item's [target main
 size] was made larger by this, it's
 a min violation.

 e. **Freeze over-flexed items.** The total violation is the sum of
 the adjustments from the previous step
 `∑(clamped size - unclamped size)`. If the total violation is:

 Zero
 : Freeze all items.

 Positive
 : Freeze all the items with min violations.

 Negative
 : Freeze all the items with max violations.

 This freezes at least one item, ensuring that
 the loop makes progress and eventually terminates.

 f. Return to the start of this loop.

6. Set each item's used [main size](#main-size) to its [target main
 size](#target-main-size).

Tests

- [item-with-max-height-and-scrollbar.html](https://wpt.fyi/results/css/css-flexbox/item-with-max-height-and-scrollbar.html "css/css-flexbox/item-with-max-height-and-scrollbar.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/item-with-max-height-and-scrollbar.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/item-with-max-height-and-scrollbar.html)
- [item-with-max-height-and-scrollbar.html](https://wpt.fyi/results/css/css-flexbox/item-with-max-height-and-scrollbar.html "css/css-flexbox/item-with-max-height-and-scrollbar.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/item-with-max-height-and-scrollbar.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/item-with-max-height-and-scrollbar.html)
- [max-width-violation.html](https://wpt.fyi/results/css/css-flexbox/max-width-violation.html "css/css-flexbox/max-width-violation.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/max-width-violation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/max-width-violation.html)
- [relayout-image-load.html](https://wpt.fyi/results/css/css-flexbox/relayout-image-load.html "css/css-flexbox/relayout-image-load.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/relayout-image-load.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/relayout-image-load.html)
- [table-as-item-inflexible-in-column-1.html](https://wpt.fyi/results/css/css-flexbox/table-as-item-inflexible-in-column-1.html "css/css-flexbox/table-as-item-inflexible-in-column-1.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/table-as-item-inflexible-in-column-1.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/table-as-item-inflexible-in-column-1.html)
- [table-as-item-inflexible-in-column-2.html](https://wpt.fyi/results/css/css-flexbox/table-as-item-inflexible-in-column-2.html "css/css-flexbox/table-as-item-inflexible-in-column-2.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/table-as-item-inflexible-in-column-2.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/table-as-item-inflexible-in-column-2.html)
- [table-as-item-inflexible-in-row-1.html](https://wpt.fyi/results/css/css-flexbox/table-as-item-inflexible-in-row-1.html "css/css-flexbox/table-as-item-inflexible-in-row-1.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/table-as-item-inflexible-in-row-1.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/table-as-item-inflexible-in-row-1.html)
- [table-as-item-inflexible-in-row-2.html](https://wpt.fyi/results/css/css-flexbox/table-as-item-inflexible-in-row-2.html "css/css-flexbox/table-as-item-inflexible-in-row-2.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/table-as-item-inflexible-in-row-2.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/table-as-item-inflexible-in-row-2.html)
- [total-min-max-violation-zero.html](https://wpt.fyi/results/css/css-flexbox/total-min-max-violation-zero.html "css/css-flexbox/total-min-max-violation-zero.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/total-min-max-violation-zero.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/total-min-max-violation-zero.html)

### 9.8. Definite and Indefinite Sizes

Although CSS Sizing
[\[CSS-SIZING-3\]](#biblio-css-sizing-3 "CSS Box Sizing Module Level 3")
defines
[definite](https://drafts.csswg.org/css-sizing-3/#definite) and
[indefinite](https://drafts.csswg.org/css-sizing-3/#indefinite) lengths, Flexbox has several additional cases where a
length can be considered [definite]:

1. If the [flex container](#flex-container) has a [definite](#definite) [main size](#main-size), then the post-flexing [main
 sizes] of its [flex
 items](#flex-item) are treated
 as [definite].

2. If a [flex item's](#flex-item) [flex
 basis](#flex-flex-basis)
 is [definite](#definite), then
 its post-flexing [main size](#main-size) is also [definite].

3. If a
 [single-line](#single-line-flex-container) [flex
 container](#flex-container) has a definite [cross
 size](#cross-size), the
 [automatic](https://drafts.csswg.org/css-sizing-3/#automatic-size)
 [preferred](https://drafts.csswg.org/css-sizing-3/#preferred-size)
 [outer](https://drafts.csswg.org/css-sizing-3/#outer-size) [cross size] of any
 [stretched](#stretched) [flex
 items](#flex-item) is the
 flex container's inner [cross size] (clamped
 to the [flex item]'s min and max [cross
 size]) and is considered
 [definite](#definite).

4. Once the cross size of a flex line has been determined, the cross
 sizes of items in auto-sized flex containers are also considered
 definite for the purpose of layout; see [step 11](#algo-stretch).

Tests

- [flexbox-definite-cross-size-constrained-percentage.html](https://wpt.fyi/results/css/css-flexbox/flexbox-definite-cross-size-constrained-percentage.html "css/css-flexbox/flexbox-definite-cross-size-constrained-percentage.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-definite-cross-size-constrained-percentage.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-definite-cross-size-constrained-percentage.html)
- [flexbox-definite-sizes-001.html](https://wpt.fyi/results/css/css-flexbox/flexbox-definite-sizes-001.html "css/css-flexbox/flexbox-definite-sizes-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-definite-sizes-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-definite-sizes-001.html)
- [flexbox-definite-sizes-002.html](https://wpt.fyi/results/css/css-flexbox/flexbox-definite-sizes-002.html "css/css-flexbox/flexbox-definite-sizes-002.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-definite-sizes-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-definite-sizes-002.html)
- [flexbox-definite-sizes-003.html](https://wpt.fyi/results/css/css-flexbox/flexbox-definite-sizes-003.html "css/css-flexbox/flexbox-definite-sizes-003.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-definite-sizes-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-definite-sizes-003.html)
- [flexbox-definite-sizes-004.html](https://wpt.fyi/results/css/css-flexbox/flexbox-definite-sizes-004.html "css/css-flexbox/flexbox-definite-sizes-004.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-definite-sizes-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-definite-sizes-004.html)
- [flexbox-definite-sizes-005.html](https://wpt.fyi/results/css/css-flexbox/flexbox-definite-sizes-005.html "css/css-flexbox/flexbox-definite-sizes-005.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-definite-sizes-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-definite-sizes-005.html)
- [flexbox-definite-sizes-006.html](https://wpt.fyi/results/css/css-flexbox/flexbox-definite-sizes-006.html "css/css-flexbox/flexbox-definite-sizes-006.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-definite-sizes-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-definite-sizes-006.html)
- [height-percentage-with-dynamic-container-size.html](https://wpt.fyi/results/css/css-flexbox/height-percentage-with-dynamic-container-size.html "css/css-flexbox/height-percentage-with-dynamic-container-size.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/height-percentage-with-dynamic-container-size.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/height-percentage-with-dynamic-container-size.html)
- [percentage-size-quirks-003.html](https://wpt.fyi/results/css/css-flexbox/percentage-size-quirks-003.html "css/css-flexbox/percentage-size-quirks-003.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/percentage-size-quirks-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/percentage-size-quirks-003.html)
- [percentage-size-quirks-004.html](https://wpt.fyi/results/css/css-flexbox/percentage-size-quirks-004.html "css/css-flexbox/percentage-size-quirks-004.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/percentage-size-quirks-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/percentage-size-quirks-004.html)
- [percentage-size-quirks-005.html](https://wpt.fyi/results/css/css-flexbox/percentage-size-quirks-005.html "css/css-flexbox/percentage-size-quirks-005.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/percentage-size-quirks-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/percentage-size-quirks-005.html)
- [percentage-widths-001.html](https://wpt.fyi/results/css/css-flexbox/percentage-widths-001.html "css/css-flexbox/percentage-widths-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/percentage-widths-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/percentage-widths-001.html)
- [position-fixed-001.html](https://wpt.fyi/results/css/css-flexbox/position-fixed-001.html "css/css-flexbox/position-fixed-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/position-fixed-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/position-fixed-001.html)
- [position-relative-percentage-top-004.html](https://wpt.fyi/results/css/css-flexbox/position-relative-percentage-top-004.html "css/css-flexbox/position-relative-percentage-top-004.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/position-relative-percentage-top-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/position-relative-percentage-top-004.html)
- [position-relative-stretch-height-001.html](https://wpt.fyi/results/css/css-flexbox/position-relative-stretch-height-001.html "css/css-flexbox/position-relative-stretch-height-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/position-relative-stretch-height-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/position-relative-stretch-height-001.html)
- [stretch-obeys-min-max-001.html](https://wpt.fyi/results/css/css-flexbox/stretch-obeys-min-max-001.html "css/css-flexbox/stretch-obeys-min-max-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/stretch-obeys-min-max-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/stretch-obeys-min-max-001.html)
- [stretch-obeys-min-max-002.html](https://wpt.fyi/results/css/css-flexbox/stretch-obeys-min-max-002.html "css/css-flexbox/stretch-obeys-min-max-002.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/stretch-obeys-min-max-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/stretch-obeys-min-max-002.html)
- [stretch-obeys-min-max-003.html](https://wpt.fyi/results/css/css-flexbox/stretch-obeys-min-max-003.html "css/css-flexbox/stretch-obeys-min-max-003.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/stretch-obeys-min-max-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/stretch-obeys-min-max-003.html)

 This means that within [flex
layout](#flex-layout), "definite"
sizes can require performing layout. This was done to allow percentages
inside of [flex items](#flex-item) to resolve where authors expected them to resolve.

### 9.9. Intrinsic Sizes

The [intrinsic
sizing](https://drafts.csswg.org/css-sizing-3/#intrinsic-sizing) of a [flex
container](#flex-container)
is used to produce various types of content-based automatic sizing, such
as shrink-to-fit logical widths (which use the
[fit-content](https://drafts.csswg.org/css-sizing-3/#valdef-width-fit-content) formula) and content-based logical heights
(which use the [max-content
size](https://drafts.csswg.org/css-sizing-3/#max-content)). For these computations, [auto] margins on flex items are treated as [0].

See
[\[CSS-SIZING-3\]](#biblio-css-sizing-3 "CSS Box Sizing Module Level 3")
for a definition of the terms in this section.

Tests

- [flexbox-gap-position-absolute.html](https://wpt.fyi/results/css/css-flexbox/flexbox-gap-position-absolute.html "css/css-flexbox/flexbox-gap-position-absolute.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox-gap-position-absolute.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox-gap-position-absolute.html)
- [gap-001-lr.html](https://wpt.fyi/results/css/css-flexbox/gap-001-lr.html "css/css-flexbox/gap-001-lr.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/gap-001-lr.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/gap-001-lr.html)
- [gap-001-ltr.html](https://wpt.fyi/results/css/css-flexbox/gap-001-ltr.html "css/css-flexbox/gap-001-ltr.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/gap-001-ltr.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/gap-001-ltr.html)
- [gap-001-rl.html](https://wpt.fyi/results/css/css-flexbox/gap-001-rl.html "css/css-flexbox/gap-001-rl.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/gap-001-rl.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/gap-001-rl.html)
- [gap-001-rtl.html](https://wpt.fyi/results/css/css-flexbox/gap-001-rtl.html "css/css-flexbox/gap-001-rtl.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/gap-001-rtl.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/gap-001-rtl.html)
- [gap-002-lr.html](https://wpt.fyi/results/css/css-flexbox/gap-002-lr.html "css/css-flexbox/gap-002-lr.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/gap-002-lr.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/gap-002-lr.html)
- [gap-002-ltr.html](https://wpt.fyi/results/css/css-flexbox/gap-002-ltr.html "css/css-flexbox/gap-002-ltr.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/gap-002-ltr.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/gap-002-ltr.html)
- [gap-002-rl.html](https://wpt.fyi/results/css/css-flexbox/gap-002-rl.html "css/css-flexbox/gap-002-rl.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/gap-002-rl.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/gap-002-rl.html)
- [gap-002-rtl.html](https://wpt.fyi/results/css/css-flexbox/gap-002-rtl.html "css/css-flexbox/gap-002-rtl.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/gap-002-rtl.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/gap-002-rtl.html)
- [gap-003-lr.html](https://wpt.fyi/results/css/css-flexbox/gap-003-lr.html "css/css-flexbox/gap-003-lr.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/gap-003-lr.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/gap-003-lr.html)
- [gap-003-ltr.html](https://wpt.fyi/results/css/css-flexbox/gap-003-ltr.html "css/css-flexbox/gap-003-ltr.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/gap-003-ltr.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/gap-003-ltr.html)
- [gap-003-rl.html](https://wpt.fyi/results/css/css-flexbox/gap-003-rl.html "css/css-flexbox/gap-003-rl.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/gap-003-rl.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/gap-003-rl.html)
- [gap-003-rtl.html](https://wpt.fyi/results/css/css-flexbox/gap-003-rtl.html "css/css-flexbox/gap-003-rtl.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/gap-003-rtl.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/gap-003-rtl.html)
- [gap-004-lr.html](https://wpt.fyi/results/css/css-flexbox/gap-004-lr.html "css/css-flexbox/gap-004-lr.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/gap-004-lr.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/gap-004-lr.html)
- [gap-004-ltr.html](https://wpt.fyi/results/css/css-flexbox/gap-004-ltr.html "css/css-flexbox/gap-004-ltr.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/gap-004-ltr.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/gap-004-ltr.html)
- [gap-004-rl.html](https://wpt.fyi/results/css/css-flexbox/gap-004-rl.html "css/css-flexbox/gap-004-rl.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/gap-004-rl.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/gap-004-rl.html)
- [gap-004-rtl.html](https://wpt.fyi/results/css/css-flexbox/gap-004-rtl.html "css/css-flexbox/gap-004-rtl.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/gap-004-rtl.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/gap-004-rtl.html)
- [gap-005-lr.html](https://wpt.fyi/results/css/css-flexbox/gap-005-lr.html "css/css-flexbox/gap-005-lr.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/gap-005-lr.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/gap-005-lr.html)
- [gap-005-ltr.html](https://wpt.fyi/results/css/css-flexbox/gap-005-ltr.html "css/css-flexbox/gap-005-ltr.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/gap-005-ltr.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/gap-005-ltr.html)
- [gap-005-rl.html](https://wpt.fyi/results/css/css-flexbox/gap-005-rl.html "css/css-flexbox/gap-005-rl.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/gap-005-rl.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/gap-005-rl.html)
- [gap-005-rtl.html](https://wpt.fyi/results/css/css-flexbox/gap-005-rtl.html "css/css-flexbox/gap-005-rtl.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/gap-005-rtl.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/gap-005-rtl.html)
- [gap-006-lr.html](https://wpt.fyi/results/css/css-flexbox/gap-006-lr.html "css/css-flexbox/gap-006-lr.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/gap-006-lr.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/gap-006-lr.html)
- [gap-006-ltr.html](https://wpt.fyi/results/css/css-flexbox/gap-006-ltr.html "css/css-flexbox/gap-006-ltr.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/gap-006-ltr.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/gap-006-ltr.html)
- [gap-006-rl.html](https://wpt.fyi/results/css/css-flexbox/gap-006-rl.html "css/css-flexbox/gap-006-rl.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/gap-006-rl.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/gap-006-rl.html)
- [gap-006-rtl.html](https://wpt.fyi/results/css/css-flexbox/gap-006-rtl.html "css/css-flexbox/gap-006-rtl.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/gap-006-rtl.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/gap-006-rtl.html)
- [gap-007-lr.html](https://wpt.fyi/results/css/css-flexbox/gap-007-lr.html "css/css-flexbox/gap-007-lr.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/gap-007-lr.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/gap-007-lr.html)
- [gap-007-ltr.html](https://wpt.fyi/results/css/css-flexbox/gap-007-ltr.html "css/css-flexbox/gap-007-ltr.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/gap-007-ltr.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/gap-007-ltr.html)
- [gap-007-rl.html](https://wpt.fyi/results/css/css-flexbox/gap-007-rl.html "css/css-flexbox/gap-007-rl.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/gap-007-rl.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/gap-007-rl.html)
- [gap-007-rtl.html](https://wpt.fyi/results/css/css-flexbox/gap-007-rtl.html "css/css-flexbox/gap-007-rtl.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/gap-007-rtl.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/gap-007-rtl.html)
- [gap-008-ltr.html](https://wpt.fyi/results/css/css-flexbox/gap-008-ltr.html "css/css-flexbox/gap-008-ltr.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/gap-008-ltr.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/gap-008-ltr.html)
- [gap-009-ltr.html](https://wpt.fyi/results/css/css-flexbox/gap-009-ltr.html "css/css-flexbox/gap-009-ltr.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/gap-009-ltr.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/gap-009-ltr.html)
- [gap-010-ltr.html](https://wpt.fyi/results/css/css-flexbox/gap-010-ltr.html "css/css-flexbox/gap-010-ltr.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/gap-010-ltr.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/gap-010-ltr.html)
- [gap-011.html](https://wpt.fyi/results/css/css-flexbox/gap-011.html "css/css-flexbox/gap-011.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/gap-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/gap-011.html)
- [gap-012.html](https://wpt.fyi/results/css/css-flexbox/gap-012.html "css/css-flexbox/gap-012.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/gap-012.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/gap-012.html)
- [gap-013.html](https://wpt.fyi/results/css/css-flexbox/gap-013.html "css/css-flexbox/gap-013.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/gap-013.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/gap-013.html)
- [gap-014.html](https://wpt.fyi/results/css/css-flexbox/gap-014.html "css/css-flexbox/gap-014.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/gap-014.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/gap-014.html)
- [gap-015.html](https://wpt.fyi/results/css/css-flexbox/gap-015.html "css/css-flexbox/gap-015.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/gap-015.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/gap-015.html)
- [gap-016.html](https://wpt.fyi/results/css/css-flexbox/gap-016.html "css/css-flexbox/gap-016.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/gap-016.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/gap-016.html)
- [gap-017.html](https://wpt.fyi/results/css/css-flexbox/gap-017.html "css/css-flexbox/gap-017.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/gap-017.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/gap-017.html)
- [gap-018.html](https://wpt.fyi/results/css/css-flexbox/gap-018.html "css/css-flexbox/gap-018.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/gap-018.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/gap-018.html)
- [gap-019.html](https://wpt.fyi/results/css/css-flexbox/gap-019.html "css/css-flexbox/gap-019.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/gap-019.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/gap-019.html)
- [gap-020.html](https://wpt.fyi/results/css/css-flexbox/gap-020.html "css/css-flexbox/gap-020.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/gap-020.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/gap-020.html)
- [gap-021.html](https://wpt.fyi/results/css/css-flexbox/gap-021.html "css/css-flexbox/gap-021.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/gap-021.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/gap-021.html)
- [auto-min-size-001.html](https://wpt.fyi/results/css/css-flexbox/intrinsic-size/auto-min-size-001.html "css/css-flexbox/intrinsic-size/auto-min-size-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/intrinsic-size/auto-min-size-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/intrinsic-size/auto-min-size-001.html)
- [col-wrap-001.html](https://wpt.fyi/results/css/css-flexbox/intrinsic-size/col-wrap-001.html "css/css-flexbox/intrinsic-size/col-wrap-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/intrinsic-size/col-wrap-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/intrinsic-size/col-wrap-001.html)
- [col-wrap-002.html](https://wpt.fyi/results/css/css-flexbox/intrinsic-size/col-wrap-002.html "css/css-flexbox/intrinsic-size/col-wrap-002.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/intrinsic-size/col-wrap-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/intrinsic-size/col-wrap-002.html)
- [col-wrap-003.html](https://wpt.fyi/results/css/css-flexbox/intrinsic-size/col-wrap-003.html "css/css-flexbox/intrinsic-size/col-wrap-003.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/intrinsic-size/col-wrap-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/intrinsic-size/col-wrap-003.html)
- [col-wrap-004.html](https://wpt.fyi/results/css/css-flexbox/intrinsic-size/col-wrap-004.html "css/css-flexbox/intrinsic-size/col-wrap-004.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/intrinsic-size/col-wrap-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/intrinsic-size/col-wrap-004.html)
- [col-wrap-005.html](https://wpt.fyi/results/css/css-flexbox/intrinsic-size/col-wrap-005.html "css/css-flexbox/intrinsic-size/col-wrap-005.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/intrinsic-size/col-wrap-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/intrinsic-size/col-wrap-005.html)
- [col-wrap-006.html](https://wpt.fyi/results/css/css-flexbox/intrinsic-size/col-wrap-006.html "css/css-flexbox/intrinsic-size/col-wrap-006.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/intrinsic-size/col-wrap-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/intrinsic-size/col-wrap-006.html)
- [col-wrap-007.html](https://wpt.fyi/results/css/css-flexbox/intrinsic-size/col-wrap-007.html "css/css-flexbox/intrinsic-size/col-wrap-007.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/intrinsic-size/col-wrap-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/intrinsic-size/col-wrap-007.html)
- [col-wrap-008.html](https://wpt.fyi/results/css/css-flexbox/intrinsic-size/col-wrap-008.html "css/css-flexbox/intrinsic-size/col-wrap-008.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/intrinsic-size/col-wrap-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/intrinsic-size/col-wrap-008.html)
- [col-wrap-009.html](https://wpt.fyi/results/css/css-flexbox/intrinsic-size/col-wrap-009.html "css/css-flexbox/intrinsic-size/col-wrap-009.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/intrinsic-size/col-wrap-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/intrinsic-size/col-wrap-009.html)
- [col-wrap-010.html](https://wpt.fyi/results/css/css-flexbox/intrinsic-size/col-wrap-010.html "css/css-flexbox/intrinsic-size/col-wrap-010.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/intrinsic-size/col-wrap-010.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/intrinsic-size/col-wrap-010.html)
- [col-wrap-011.html](https://wpt.fyi/results/css/css-flexbox/intrinsic-size/col-wrap-011.html "css/css-flexbox/intrinsic-size/col-wrap-011.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/intrinsic-size/col-wrap-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/intrinsic-size/col-wrap-011.html)
- [col-wrap-012.html](https://wpt.fyi/results/css/css-flexbox/intrinsic-size/col-wrap-012.html "css/css-flexbox/intrinsic-size/col-wrap-012.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/intrinsic-size/col-wrap-012.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/intrinsic-size/col-wrap-012.html)
- [col-wrap-013.html](https://wpt.fyi/results/css/css-flexbox/intrinsic-size/col-wrap-013.html "css/css-flexbox/intrinsic-size/col-wrap-013.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/intrinsic-size/col-wrap-013.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/intrinsic-size/col-wrap-013.html)
- [col-wrap-014.html](https://wpt.fyi/results/css/css-flexbox/intrinsic-size/col-wrap-014.html "css/css-flexbox/intrinsic-size/col-wrap-014.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/intrinsic-size/col-wrap-014.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/intrinsic-size/col-wrap-014.html)
- [col-wrap-015.html](https://wpt.fyi/results/css/css-flexbox/intrinsic-size/col-wrap-015.html "css/css-flexbox/intrinsic-size/col-wrap-015.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/intrinsic-size/col-wrap-015.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/intrinsic-size/col-wrap-015.html)
- [col-wrap-016.html](https://wpt.fyi/results/css/css-flexbox/intrinsic-size/col-wrap-016.html "css/css-flexbox/intrinsic-size/col-wrap-016.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/intrinsic-size/col-wrap-016.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/intrinsic-size/col-wrap-016.html)
- [col-wrap-017.html](https://wpt.fyi/results/css/css-flexbox/intrinsic-size/col-wrap-017.html "css/css-flexbox/intrinsic-size/col-wrap-017.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/intrinsic-size/col-wrap-017.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/intrinsic-size/col-wrap-017.html)
- [col-wrap-018.html](https://wpt.fyi/results/css/css-flexbox/intrinsic-size/col-wrap-018.html "css/css-flexbox/intrinsic-size/col-wrap-018.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/intrinsic-size/col-wrap-018.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/intrinsic-size/col-wrap-018.html)
- [col-wrap-019.html](https://wpt.fyi/results/css/css-flexbox/intrinsic-size/col-wrap-019.html "css/css-flexbox/intrinsic-size/col-wrap-019.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/intrinsic-size/col-wrap-019.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/intrinsic-size/col-wrap-019.html)
- [col-wrap-020.html](https://wpt.fyi/results/css/css-flexbox/intrinsic-size/col-wrap-020.html "css/css-flexbox/intrinsic-size/col-wrap-020.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/intrinsic-size/col-wrap-020.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/intrinsic-size/col-wrap-020.html)
- [col-wrap-crash.html](https://wpt.fyi/results/css/css-flexbox/intrinsic-size/col-wrap-crash.html "css/css-flexbox/intrinsic-size/col-wrap-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/intrinsic-size/col-wrap-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/intrinsic-size/col-wrap-crash.html)
- [row-001.html](https://wpt.fyi/results/css/css-flexbox/intrinsic-size/row-001.html "css/css-flexbox/intrinsic-size/row-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/intrinsic-size/row-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/intrinsic-size/row-001.html)
- [row-002.html](https://wpt.fyi/results/css/css-flexbox/intrinsic-size/row-002.html "css/css-flexbox/intrinsic-size/row-002.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/intrinsic-size/row-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/intrinsic-size/row-002.html)
- [row-003.html](https://wpt.fyi/results/css/css-flexbox/intrinsic-size/row-003.html "css/css-flexbox/intrinsic-size/row-003.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/intrinsic-size/row-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/intrinsic-size/row-003.html)
- [row-004.html](https://wpt.fyi/results/css/css-flexbox/intrinsic-size/row-004.html "css/css-flexbox/intrinsic-size/row-004.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/intrinsic-size/row-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/intrinsic-size/row-004.html)
- [row-005.html](https://wpt.fyi/results/css/css-flexbox/intrinsic-size/row-005.html "css/css-flexbox/intrinsic-size/row-005.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/intrinsic-size/row-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/intrinsic-size/row-005.html)
- [row-006.html](https://wpt.fyi/results/css/css-flexbox/intrinsic-size/row-006.html "css/css-flexbox/intrinsic-size/row-006.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/intrinsic-size/row-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/intrinsic-size/row-006.html)
- [row-007.html](https://wpt.fyi/results/css/css-flexbox/intrinsic-size/row-007.html "css/css-flexbox/intrinsic-size/row-007.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/intrinsic-size/row-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/intrinsic-size/row-007.html)
- [row-008.html](https://wpt.fyi/results/css/css-flexbox/intrinsic-size/row-008.html "css/css-flexbox/intrinsic-size/row-008.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/intrinsic-size/row-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/intrinsic-size/row-008.html)
- [row-compat-001.html](https://wpt.fyi/results/css/css-flexbox/intrinsic-size/row-compat-001.html "css/css-flexbox/intrinsic-size/row-compat-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/intrinsic-size/row-compat-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/intrinsic-size/row-compat-001.html)
- [row-use-cases-001.html](https://wpt.fyi/results/css/css-flexbox/intrinsic-size/row-use-cases-001.html "css/css-flexbox/intrinsic-size/row-use-cases-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/intrinsic-size/row-use-cases-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/intrinsic-size/row-use-cases-001.html)
- [row-wrap-001.html](https://wpt.fyi/results/css/css-flexbox/intrinsic-size/row-wrap-001.html "css/css-flexbox/intrinsic-size/row-wrap-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/intrinsic-size/row-wrap-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/intrinsic-size/row-wrap-001.html)
- [multiline-shrink-to-fit.html](https://wpt.fyi/results/css/css-flexbox/multiline-shrink-to-fit.html "css/css-flexbox/multiline-shrink-to-fit.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/multiline-shrink-to-fit.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/multiline-shrink-to-fit.html)
- [svg-no-natural-size-grandchild.html](https://wpt.fyi/results/css/css-flexbox/svg-no-natural-size-grandchild.html "css/css-flexbox/svg-no-natural-size-grandchild.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/svg-no-natural-size-grandchild.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/svg-no-natural-size-grandchild.html)
- [relayout-intrinsic-block-size.html](https://wpt.fyi/results/css/css-flexbox/relayout-intrinsic-block-size.html "css/css-flexbox/relayout-intrinsic-block-size.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/relayout-intrinsic-block-size.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/relayout-intrinsic-block-size.html)

#### 9.9.1. Flex Container Intrinsic Main Sizes

The
**[max-content](https://drafts.csswg.org/css-sizing-3/#max-content) [main size](#main-size) of a [flex
container](#flex-container)**
is, theoretically, the smallest size the [flex
container](#flex-container)
can take such that when flex layout is run with that container size,
each [flex item](#flex-item) ends
up at least as large as its [max-content
contribution](#intrinsic-item-contributions), to the extent allowed by
the items' flexibility.

The
**[min-content](https://drafts.csswg.org/css-sizing-3/#min-content) [main size](#main-size) of a [flex
container](#flex-container)**
is, theoretically, the smallest size the [flex
container](#flex-container)
can take such that no items overflow it, and no item's contents overflow
the item---​setting aside the cases in which the boxes layouts are
*defined* to overflow (for example with negative margins or percentage
sizes that add up to more than 100%).

Tests

- [flex-container-max-content-001.html](https://wpt.fyi/results/css/css-flexbox/flex-container-max-content-001.html "css/css-flexbox/flex-container-max-content-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-container-max-content-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-container-max-content-001.html)
- [flex-container-min-content-001.html](https://wpt.fyi/results/css/css-flexbox/flex-container-min-content-001.html "css/css-flexbox/flex-container-min-content-001.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flex-container-min-content-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flex-container-min-content-001.html)

For the min-content size of a multi-line flex container, see [§ 9.9.1.3
Multi-line Min-content Algorithm](#intrinsic-main-sizes-multiline). For
max-content sizes and for single-line min-content sizes, an
implementation is conformant to CSS Flexible Box Layout if it conforms
to either the Ideal Algorithm or the Web-compatible Algorithm, as
defined below.

##### 9.9.1.1. Ideal Algorithm: Max-content Size and Min-content Single-line Size

 The following algorithm calculates the [flex
container](#flex-container)'s
ideal intrinsic [main sizes](#main-size). However, because it was not implemented correctly
initially, and existing content became dependent on the (unfortunately
consistent) incorrect implemented behavior, [it is not
Web-compatible](https://github.com/w3c/csswg-drafts/issues/8884).
Implementers and the CSS Working Group are investigating to what extent
Web browser implementations can safely approach this behavior, and
further experimentation is welcome.

Considering only
non-[collapsed](#collapsed-flex-item) [flex items](#flex-item);

1. For each [flex item](#flex-item), subtract its outer [flex base
 size](#flex-base-size)
 from its [max-content contribution](#intrinsic-item-contributions)
 size. If that result is positive, divide it by the item's [flex grow
 factor](#flex-flex-grow-factor) if the [flex grow
 factor] is ≥ 1, or multiply it by
 the [flex grow factor] if the [flex
 grow factor] is \< 1; if the result
 is negative, divide it by the item's [scaled flex shrink
 factor](#scaled-flex-shrink-factor) (if dividing by zero, treat the result as negative
 infinity). This is the item's `desired flex fraction`.

2. Place all [flex items](#flex-item) into lines of infinite length. Within each line,
 find the greatest (most positive) `desired flex fraction`
 among all the [flex items]. This is the
 line's `chosen flex fraction`.

3. If the `chosen flex fraction` is positive, and the sum of
 the line's [flex grow
 factors](#flex-flex-grow-factor) is less than 1, divide the
 `chosen flex fraction` by that sum.

 If the `chosen flex fraction` is negative, and the sum of
 the line's [flex shrink
 factors](#flex-flex-shrink-factor) is less than 1, multiply the
 `chosen flex fraction` by that sum.

4. Add each item's [flex base
 size](#flex-base-size) to
 the product of its [flex grow
 factor](#flex-flex-grow-factor) ([scaled flex shrink
 factor](#scaled-flex-shrink-factor), if shrinking) and the
 `chosen flex fraction`, then clamp that result by the
 [max main size](#max-main-size) floored by the [min main
 size](#min-main-size).

5. The [flex container](#flex-container)'s [max-content
 size](https://drafts.csswg.org/css-sizing-3/#max-content) is the largest sum (among all the lines) of the
 afore-calculated sizes of all items within a single line.

The
**[min-content](https://drafts.csswg.org/css-sizing-3/#min-content) [main size](#main-size)** of a
*[single-line](#single-line-flex-container)* flex container is calculated identically to the
[max-content](https://drafts.csswg.org/css-sizing-3/#max-content) [main size](#main-size), except that the [flex
items](#flex-item)' [min-content
contributions](#intrinsic-item-contributions) are used instead of their
[max-content contributions](#intrinsic-item-contributions).

Implications of this algorithm when the sum of flex is less than 1

The above algorithm is designed to give the correct behavior for two
cases in particular, and make the [flex
container's](#flex-container)
size continuous as you transition between the two:

1. If all items are inflexible, the [flex
 container](#flex-container) is sized to the sum of their [flex base
 size](#flex-base-size).
 (An inflexible [flex base size] basically
 substitutes for a
 [width](https://drafts.csswg.org/css-sizing-3/#propdef-width)/[height](https://drafts.csswg.org/css-sizing-3/#propdef-height), which, when specified, is what
 a [max-content
 contribution](https://drafts.csswg.org/css-sizing-3/#max-content-contribution) is based on in Block Layout.)

2. When all items are flexible with [flex
 factors](#flex-factor) ≥ 1,
 the [flex container](#flex-container) is sized to the sum of the [max-content
 contributions](https://drafts.csswg.org/css-sizing-3/#max-content-contribution) of its items (or perhaps a slightly larger size, so
 that every flex item is *at least* the size of its [max-content
 contribution], but also has the
 correct ratio of its size to the size of the other items, as
 determined by its flexibility).

For example, if a [flex
container](#flex-container)
has a single [flex item](#flex-item) with [flex-basis:
100px;](#propdef-flex-basis) but a max-content size of [200px], then when
the item is [flex-grow:
0](#propdef-flex-grow), the [flex container]
(and [flex item]) is [100px] wide, but when
the item is [flex-grow: 1] or higher,
the [flex container] (and flex item) is
[200px] wide.

There are several possible ways to make the overall behavior continuous
between these two cases, but all of them have drawbacks. We chose one we
feel has the least bad implications; unfortunately, it
\"double-applies\" the flexibility in cases with [flex
factors](#flex-factor) that are
\< 1. In the above example, if the item has [flex-grow:
.5](#propdef-flex-grow), then the [flex
container](#flex-container)
ends up [150px] wide, but the item then sizes normally into that
available space, ending up [125px] wide.

Even more involved notes on the specific behavior chosen

Principles:

1. Don't explode any sizes, whether growing or shrinking, as inputs
 approach zero.

2. When flex factors are all \>=1, return the minimum size necessary
 for every item to be \>= max-content size.

3. Items with a zero flex shouldn't affect the sizes at all.

4. Keep it continuous over variance of flex factors and item sizes.

5. Keep sizing variance as linear as possible with respect to linear
 changes to any input variable (size, flex factor).

6. When the sum of flex factors is \>=1, return the minimum size
 necessary for every item to be \>= max-content size.

To get these all to work together, we have to apply some correction when
either flex factors or the sum of flex factors on a line is \< 1.

For shrink our behavior is somewhat easier; since the explosive case of
0 shrink results in a negative infinity desired fraction which we'll
never choose (since we always take the largest), we can just apply the
correction at the line level, giving us double-application only when the
sum is \< 1.

For positives it's more complicated. 0 grow naively explodes into
\*positive\* infinity, which we'd choose, so we need to apply the
correction at the individual item level. We do that by multiplying the
space by the factor when factor is \<1. Leaving it at that would result
in a double-application for items \< 1 but sum \>= 1, but a
\*triple\*-application when the sum is \< 1. To avoid \*that\*
ridiculousness, we apply a \*reverse\* correction when the sum is 1,
dividing by the sum instead. This leaves us with a double correction in
all cases for items with factors \< 1.

We can't eliminate the double-applications entirely without giving up
other, more important principles (in particular, principle 3 ---​try to
come up with rules that don't double-apply when you have two items with
[flex-grow: .5](#propdef-flex-grow), but also don't give a [flex-grow:
0] item any power over a [flex-grow:
1] sibling; you can't, as far as we
can tell.)

##### 9.9.1.2. Web-compatible Intrinsic Sizing Algorithm: Max-content Size and Min-content Single-line Size

 The following algorithm has been demonstrated to be
Web-compatible. It may be altered in the future to bring it closer to
the ideal algorithm above, if possible.

- For the [max-content
 size](https://drafts.csswg.org/css-sizing-3/#max-content) of a [flex
 container](#flex-container), take the sum of the [max-content
 contributions](#intrinsic-item-contributions) of all the
 non-[collapsed](#collapsed-flex-item) [flex items](#flex-item) in the [flex container].

- For the [min-content
 size](https://drafts.csswg.org/css-sizing-3/#min-content) of a
 *[single-line](#single-line-flex-container)* container, take the sum of the [min-content
 contributions](#intrinsic-item-contributions) of all the
 non-[collapsed](#collapsed-flex-item) [flex items](#flex-item) in the [flex
 container](#flex-container).

##### 9.9.1.3. Multi-line Min-content Algorithm

For a
*[multi-line](#multi-line-flex-container)* container, the
[min-content](https://drafts.csswg.org/css-sizing-3/#min-content) [main size](#main-size) is simply the largest [min-content
contribution](#intrinsic-item-contributions) of all the
non-[collapsed](#collapsed-flex-item) [flex items](#flex-item) in the [flex
container](#flex-container).

#### 9.9.2. Flex Container Intrinsic Cross Sizes

The
**[min-content](https://drafts.csswg.org/css-sizing-3/#min-content)/[max-content](https://drafts.csswg.org/css-sizing-3/#max-content) [cross size](#cross-size)** of a
*[single-line](#single-line-flex-container)* [flex
container](#flex-container)
is the largest [min-content
contribution](https://drafts.csswg.org/css-sizing-3/#min-content-contribution)/[max-content
contribution](https://drafts.csswg.org/css-sizing-3/#max-content-contribution) (respectively) of its [flex
items](#flex-item).

For a
*[multi-line](#multi-line-flex-container)* [flex
container](#flex-container),
the behavior depends on whether it's a row or column flexbox:

[row](#valdef-flex-direction-row) [multi-line](#multi-line-flex-container) [flex container](#flex-container) [cross size](#cross-size)

: The
 [min-content](https://drafts.csswg.org/css-sizing-3/#min-content)/[max-content](https://drafts.csswg.org/css-sizing-3/#max-content) [cross size](#cross-size) is the sum of the flex line cross sizes resulting
 from sizing the flex container under a
 [cross-axis](#cross-axis)
 [min-content
 constraint](https://drafts.csswg.org/css-sizing-3/#min-content-constraint)/[max-content
 constraint](https://drafts.csswg.org/css-sizing-3/#max-content-constraint) (respectively).

[column](#valdef-flex-direction-column) [multi-line](#multi-line-flex-container) [flex container](#flex-container) [cross size](#cross-size)

: The
 [min-content](https://drafts.csswg.org/css-sizing-3/#min-content) [cross size](#cross-size) is the largest [min-content
 contribution](https://drafts.csswg.org/css-sizing-3/#min-content-contribution) among all of its [flex
 items](#flex-item).

 This heuristic effectively assumes a single flex
 line, in order to guarantee that the [min-content
 size](https://drafts.csswg.org/css-sizing-3/#min-content) is smaller than the [max-content
 size](https://drafts.csswg.org/css-sizing-3/#max-content). If the flex container has a height constraint,
 this will result in overflow, but if the [flex
 container](#flex-container) is also a [main-axis scroll
 container](https://drafts.csswg.org/css-overflow-3/#block-axis-scroll-container), it will at least be large enough to fit any given
 column entirely within its
 [scrollport](https://drafts.csswg.org/css-overflow-3/#scrollport).

 The
 [max-content](https://drafts.csswg.org/css-sizing-3/#max-content) [cross size](#cross-size) is the sum of the [flex
 line](#flex-line) cross sizes
 resulting from sizing the [flex
 container](#flex-container) under a
 [cross-axis](#cross-axis)
 [max-content
 constraint](https://drafts.csswg.org/css-sizing-3/#max-content-constraint), using the largest
 [max-content](https://drafts.csswg.org/css-sizing-3/#max-content-contribution) cross-size contribution among the [flex
 items](#flex-item) as the
 [available
 space](https://drafts.csswg.org/css-sizing-3/#available) in the [cross axis] for each
 of the [flex items] during layout.

 This heuristic gives a reasonable approximation of
 the size that the [flex
 container](#flex-container) should be, with each [flex
 item](#flex-item) laid out at
 its [max-content
 contribution](https://drafts.csswg.org/css-sizing-3/#max-content-contribution) or larger, and each [flex
 line](#flex-line) no larger
 than its largest [flex item]. It's not a
 *perfect* fit in some cases, but doing it completely correct is
 insanely expensive, and this works reasonably well.

Tests

- [flexbox_width-change-and-relayout-children.html](https://wpt.fyi/results/css/css-flexbox/flexbox_width-change-and-relayout-children.html "css/css-flexbox/flexbox_width-change-and-relayout-children.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_width-change-and-relayout-children.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_width-change-and-relayout-children.html)
- [table-as-flex-item-max-content.html](https://wpt.fyi/results/css/css-flexbox/table-as-flex-item-max-content.html "css/css-flexbox/table-as-flex-item-max-content.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/table-as-flex-item-max-content.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/table-as-flex-item-max-content.html)
- [table-as-item-flex-cross-size.html](https://wpt.fyi/results/css/css-flexbox/table-as-item-flex-cross-size.html "css/css-flexbox/table-as-item-flex-cross-size.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/table-as-item-flex-cross-size.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/table-as-item-flex-cross-size.html)

#### 9.9.3. Flex Item Intrinsic Size Contributions

The **main-size [min-content
contribution](https://drafts.csswg.org/css-sizing-3/#min-content-contribution) of a [flex item](#flex-item)** is the larger of its *outer* [min-content
size](https://drafts.csswg.org/css-sizing-3/#min-content) and outer [preferred
size](https://drafts.csswg.org/css-sizing-3/#preferred-size) if that is not an [automatic
size](https://drafts.csswg.org/css-sizing-3/#automatic-size).

The **main-size [max-content
contribution](https://drafts.csswg.org/css-sizing-3/#max-content-contribution) of a [flex item](#flex-item)** is the larger of its *outer* [max-content
size](https://drafts.csswg.org/css-sizing-3/#max-content) and outer [preferred
size](https://drafts.csswg.org/css-sizing-3/#preferred-size) if that is not an [automatic
size](https://drafts.csswg.org/css-sizing-3/#automatic-size).

For this purpose, each contribution is capped by the item's [flex base
size](#flex-base-size) if the
item is not growable, floored by the item's [flex base
size] if the item is not shrinkable, and then
further clamped by the item's
[min](#min-main-size)/[max main
size](#max-main-size).

## 10. Fragmenting Flex Layout

Flex containers can break across pages between items, between lines of
items (in
[multi-line](#multi-line-flex-container) mode), and inside items. The
[break-\*](https://drafts.csswg.org/css-break-3/#propdef-break-before) properties apply to flex containers as normal
for block-level or inline-level boxes. This section defines how they
apply to flex items and the contents of flex items. See the [CSS
Fragmentation Module](http://www.w3.org/TR/css-break/) for more context
[\[CSS3-BREAK\]](#biblio-css3-break "CSS Fragmentation Module Level 3").

The following breaking rules refer to the [fragmentation
container](https://drafts.csswg.org/css-break-4/#fragmentation-container) as the "page". The same rules apply in any other
[fragmentation
context](https://drafts.csswg.org/css-break-4/#fragmentation-context). (Substitute "page" with the appropriate [fragmentation
container] type as needed.) For
readability, in this section the terms \"row\" and \"column\" refer to
the relative orientation of the [flex
container](#flex-container)
with respect to the block flow direction of the [fragmentation
context], rather than to that of the
[flex container] itself.

The exact layout of a fragmented flex container is not defined in this
level of Flexible Box Layout. However, breaks inside a flex container
are subject to the following rules (interpreted using [order-modified
document
order](https://drafts.csswg.org/css-display-4/#order-modified-document-order)):

- In a row flex container, the
 [break-before](https://drafts.csswg.org/css-break-3/#propdef-break-before) and
 [break-after](https://drafts.csswg.org/css-break-3/#propdef-break-after) values on flex items are
 propagated to the flex line. The
 [break-before] values on the
 first line and the [break-after] values on the last line are propagated to the flex
 container.

 Break propagation (like
 [text-decoration](https://drafts.csswg.org/css-text-decor-4/#propdef-text-decoration) propagation) does not affect
 [computed
 values](https://drafts.csswg.org/css-cascade-5/#computed-value).

- In a column flex container, the
 [break-before](https://drafts.csswg.org/css-break-3/#propdef-break-before) values on the first item and the
 [break-after](https://drafts.csswg.org/css-break-3/#propdef-break-after) values on the last item are
 propagated to the flex container. Forced breaks on other items are
 applied to the item itself.

- A forced break inside a flex item effectively increases the size of
 its contents; it does not trigger a forced break inside sibling items.

- In a row flex container, [Class A break
 opportunities](https://www.w3.org/TR/css3-break/#btw-blocks) occur
 between sibling flex lines, and [Class C break
 opportunities](https://www.w3.org/TR/css3-break/#end-block) occur
 between the first/last flex line and the flex container's content
 edges. In a column flex container, [Class A break
 opportunities](https://www.w3.org/TR/css3-break/#btw-blocks) occur
 between sibling flex items, and [Class C break
 opportunities](https://www.w3.org/TR/css3-break/#end-block) occur
 between the first/last flex items on a line and the flex container's
 content edges.
 [\[CSS3-BREAK\]](#biblio-css3-break "CSS Fragmentation Module Level 3")

- When a flex container is continued after a break, the space available
 to its [flex items](#flex-item)
 (in the block flow direction of the fragmentation context) is reduced
 by the space consumed by flex container fragments on previous pages.
 The space consumed by a flex container fragment is the size of its
 content box on that page. If as a result of this adjustment the
 available space becomes negative, it is set to zero.

- If the first fragment of the flex container is not at the top of the
 page, and none of its flex items fit in the remaining space on the
 page, the entire fragment is moved to the next page.

- When breaking a
 [multi-line](#multi-line-flex-container) column flex container, the UA may organize each
 fragment into its own "stack" of flex lines---​just like each fragment
 of a multi-column container has its own row of column boxes---​in order
 to ensure that content presented on earlier pages corresponds to
 content earlier in the box order.

- Aside from the rearrangement of items imposed by the previous point,
 UAs should attempt to minimize distortion of the flex container with
 respect to unfragmented flow.

Tests

- [flexbox_interactive_break-after-column-item.html (manual test)
 ][[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/interactive/flexbox_interactive_break-after-column-item.html)
- [flexbox_interactive_break-after-column-lastitem.html (manual test)
 ][[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/interactive/flexbox_interactive_break-after-column-lastitem.html)
- [flexbox_interactive_break-after-container.html (manual test)
 ][[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/interactive/flexbox_interactive_break-after-container.html)
- [flexbox_interactive_break-after-item.html (manual test)
 ][[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/interactive/flexbox_interactive_break-after-item.html)
- [flexbox_interactive_break-after-line.html (manual test)
 ][[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/interactive/flexbox_interactive_break-after-line.html)
- [flexbox_interactive_break-after-line-order.html (manual test)
 ][[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/interactive/flexbox_interactive_break-after-line-order.html)
- [flexbox_interactive_break-after-multiline.html (manual test)
 ][[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/interactive/flexbox_interactive_break-after-multiline.html)
- [flexbox_interactive_break-before-column-firstitem.html (manual test)
 ][[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/interactive/flexbox_interactive_break-before-column-firstitem.html)
- [flexbox_interactive_break-before-column-item.html (manual test)
 ][[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/interactive/flexbox_interactive_break-before-column-item.html)
- [flexbox_interactive_break-before-container.html (manual test)
 ][[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/interactive/flexbox_interactive_break-before-container.html)
- [flexbox_interactive_break-before-item.html (manual test)
 ][[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/interactive/flexbox_interactive_break-before-item.html)
- [flexbox_interactive_break-before-multiline.html (manual test)
 ][[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/interactive/flexbox_interactive_break-before-multiline.html)
- [flexbox_interactive_break-natural.html (manual test)
 ][[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/interactive/flexbox_interactive_break-natural.html)

### 10.1. Sample Flex Fragmentation Algorithm

This informative section presents a possible fragmentation algorithm for
flex containers. Implementors are encouraged to improve on this
algorithm and [provide feedback to the CSS Working Group](#sotd).

This algorithm assumes that pagination always proceeds only in the
forward direction; therefore, in the algorithms below, alignment is
mostly ignored prior to pagination. Advanced layout engines may be able
to honor alignment across fragments.

[single-line](#single-line-flex-container) column flex container

: 1. Run the flex layout algorithm (without regards to pagination)
 through [Cross Sizing Determination](#cross-sizing).
 2. Lay out as many consecutive flex items or item fragments as
 possible (but at least one or a fragment thereof), starting from
 the first, until there is no more room on the page or a forced
 break is encountered.
 3. If the previous step ran out of room and the free space is
 positive, the UA may reduce the distributed free space on this
 page (down to, but not past, zero) in order to make room for the
 next unbreakable flex item or fragment. Otherwise, the item or
 fragment that does not fit is pushed to the next page. The UA
 should pull up if more than 50% of the fragment would have fit
 in the remaining space and should push otherwise.
 4. If there are any flex items or fragments not laid out by the
 previous steps, rerun the flex layout algorithm from [Line
 Length Determination](#line-sizing) through [Cross Sizing
 Determination](#cross-sizing) with the next page's size and
 *all* the contents (including those already laid out), and
 return to the previous step, but starting from the first item or
 fragment not already laid out.
 5. For each fragment of the flex container, continue the flex
 layout algorithm from [Main-Axis Alignment](#main-alignment) to
 its finish.

 It is the intent of this algorithm that column-direction
 [single-line](#single-line-flex-container) flex containers paginate very similarly to block
 flow. As a test of the intent, a flex container with
 [justify-content:start] and no flexible items should paginate
 identically to a block with
 [in-flow](https://drafts.csswg.org/css-display-4/#in-flow) children with same content, same used size and same
 used margins.

[multi-line](#multi-line-flex-container) column flex container

: 1. Run the flex layout algorithm *with* regards to pagination
 (limiting the flex container's maximum line length to the space
 left on the page) through [Cross Sizing
 Determination](#cross-sizing).
 2. Lay out as many flex lines as possible (but at least one) until
 there is no more room in the flex container in the cross
 dimension or a forced break is encountered:
 1. Lay out as many consecutive flex items as possible (but at
 least one), starting from the first, until there is no more
 room on the page or a forced break is encountered. Forced
 breaks *within* flex items are ignored.
 2. If this is the first flex container fragment, this line
 contains only a single flex item that is larger than the
 space left on the page, and the flex container is not at the
 top of the page already, move the flex container to the next
 page and restart flex container layout entirely.
 3. If there are any flex items not laid out by the first step,
 rerun the flex layout algorithm from [Main Sizing
 Determination](#main-sizing) through [Cross Sizing
 Determination](#cross-sizing) using only the items not laid
 out on a previous line, and return to the previous step,
 starting from the first item not already laid out.
 3. If there are any flex items not laid out by the previous step,
 rerun the flex layout algorithm from [Line Sizing
 Determination](#line-sizing) through [Cross Sizing
 Determination](#cross-sizing) with the next page's size and only
 the items not already laid out, and return to the previous step,
 but starting from the first item not already laid out.
 4. For each fragment of the flex container, continue the flex
 layout algorithm from [Main-Axis Alignment](#main-alignment) to
 its finish.

 A shortcoming of this sample algorithm is that if a flex item does
 not entirely fit on a single page, it will *not* be paginated in
 [multi-line](#multi-line-flex-container) column flex containers.

[single-line](#single-line-flex-container) row flex container

: 1. Run the entire flex layout algorithm (without regards to
 pagination), except treat any
 [align-self](#propdef-align-self) other than
 [flex-start](#valdef-align-items-flex-start) or
 [baseline](#valdef-align-items-baseline) as
 [flex-start].

 2. If an unbreakable item doesn't fit within the space left on the
 page, and the flex container is not at the top of the page, move
 the flex container to the next page and restart flex container
 layout entirely.

 3. For each item, lay out as much of its contents as will fit in
 the space left on the page, and fragment the remaining content
 onto the next page, rerunning the flex layout algorithm from
 [Line Length Determination](#line-sizing) through [Main-Axis
 Alignment](#main-alignment) into the new page size using *all*
 the contents (including items completed on previous pages).

 Any flex items that fit entirely into previous fragments still
 take up space in the main axis in later fragments.

 4. For each fragment of the flex container, rerun the flex layout
 algorithm from [Cross-Axis Alignment](#cross-alignment) to its
 finish. For all fragments besides the first, treat
 [align-self](#propdef-align-self) and
 [align-content](#propdef-align-content) as being
 [flex-start](#valdef-align-items-flex-start) for all item fragments and lines.

 5. If any item, when aligned according to its original
 [align-self](#propdef-align-self) value into the combined
 [cross size](#cross-size)
 of all the flex container fragments, would fit entirely within a
 single flex container fragment, it may be shifted into that
 fragment and aligned appropriately.

[multi-line](#multi-line-flex-container) row flex container

: 1. Run the flex layout algorithm (without regards to pagination),
 through [Cross Sizing Determination](#cross-sizing).

 2. Lay out as many flex lines as possible (but at least one),
 starting from the first, until there is no more room on the page
 or a forced break is encountered.

 If a line doesn't fit on the page, and the line is not at the
 top of the page, move the line to the next page and restart the
 flex layout algorithm entirely, using only the items in and
 following this line.

 If a flex item itself causes a forced break, rerun the flex
 layout algorithm from [Main Sizing Determination](#main-sizing)
 through [Main-Axis Alignment](#main-alignment), using only the
 items on this and following lines, but with the item causing the
 break automatically starting a new line in the [line breaking
 step](#algo-line-break), then continue with this step. Forced
 breaks *within* flex items are ignored.

 3. If there are any flex items not laid out by the previous step,
 rerun the flex layout algorithm from [Line Length
 Determination](#line-sizing) through [Main-Axis
 Alignment](#main-alignment) with the next page's size and only
 the items not already laid out. Return to the previous step, but
 starting from the first line not already laid out.

 4. For each fragment of the flex container, continue the flex
 layout algorithm from [Cross Axis Alignment](#cross-alignment)
 to its finish.

## [ Appendix A: Axis Mappings]
*This appendix is non-normative.*

Axis Mappings for
[ltr](https://drafts.csswg.org/css-writing-modes-4/#valdef-direction-ltr) +
[horizontal-tb](https://drafts.csswg.org/css-writing-modes-4/#valdef-writing-mode-horizontal-tb) [Writing
Mode](https://drafts.csswg.org/css-writing-modes-4/#writing-mode) (e.g. English)

[flex-flow](#propdef-flex-flow)

[main axis](#main-axis)

[start](https://drafts.csswg.org/css-writing-modes-3/#css-start)

[end](https://drafts.csswg.org/css-writing-modes-3/#css-end)

[cross axis](#cross-axis)

[start](https://drafts.csswg.org/css-writing-modes-3/#css-start)

[end](https://drafts.csswg.org/css-writing-modes-3/#css-end)

[row](#valdef-flex-direction-row) +
[nowrap](#valdef-flex-wrap-nowrap)/[wrap](#valdef-flex-wrap-wrap)

horizontal

left

right

vertical

top

bottom

[row-reverse](#valdef-flex-direction-row-reverse) +
[nowrap](#valdef-flex-wrap-nowrap)/[wrap](#valdef-flex-wrap-wrap)

right

left

[row](#valdef-flex-direction-row) +
[wrap-reverse](#valdef-flex-wrap-wrap-reverse)

left

right

bottom

top

[row-reverse](#valdef-flex-direction-row-reverse) +
[wrap-reverse](#valdef-flex-wrap-wrap-reverse)

right

left

[column](#valdef-flex-direction-column) +
[nowrap](#valdef-flex-wrap-nowrap)/[wrap](#valdef-flex-wrap-wrap)

vertical

top

bottom

horizontal

left

right

[column-reverse](#valdef-flex-direction-column-reverse) +
[nowrap](#valdef-flex-wrap-nowrap)/[wrap](#valdef-flex-wrap-wrap)

bottom

top

[column](#valdef-flex-direction-column) +
[wrap-reverse](#valdef-flex-wrap-wrap-reverse)

top

bottom

right

left

[column-reverse](#valdef-flex-direction-column-reverse) +
[wrap-reverse](#valdef-flex-wrap-wrap-reverse)

bottom

top

Axis Mappings for
[rtl](https://drafts.csswg.org/css-writing-modes-4/#valdef-direction-rtl) +
[horizontal-tb](https://drafts.csswg.org/css-writing-modes-4/#valdef-writing-mode-horizontal-tb) [Writing
Mode](https://drafts.csswg.org/css-writing-modes-4/#writing-mode) (e.g. Farsi)

[flex-flow](#propdef-flex-flow)

[main axis](#main-axis)

[main-start](#main-start)

[main-end](#main-end)

[cross axis](#cross-axis)

[cross-start](#cross-start)

[cross-end](#cross-end)

[row](#valdef-flex-direction-row) +
[nowrap](#valdef-flex-wrap-nowrap)/[wrap](#valdef-flex-wrap-wrap)

horizontal

right

left

vertical

top

bottom

[row-reverse](#valdef-flex-direction-row-reverse) +
[nowrap](#valdef-flex-wrap-nowrap)/[wrap](#valdef-flex-wrap-wrap)

left

right

[row](#valdef-flex-direction-row) +
[wrap-reverse](#valdef-flex-wrap-wrap-reverse)

right

left

bottom

top

[row-reverse](#valdef-flex-direction-row-reverse) +
[wrap-reverse](#valdef-flex-wrap-wrap-reverse)

left

right

[column](#valdef-flex-direction-column) +
[nowrap](#valdef-flex-wrap-nowrap)/[wrap](#valdef-flex-wrap-wrap)

vertical

top

bottom

horizontal

right

left

[column-reverse](#valdef-flex-direction-column-reverse) +
[nowrap](#valdef-flex-wrap-nowrap)/[wrap](#valdef-flex-wrap-wrap)

bottom

top

[column](#valdef-flex-direction-column) +
[wrap-reverse](#valdef-flex-wrap-wrap-reverse)

top

bottom

left

right

[column-reverse](#valdef-flex-direction-column-reverse) +
[wrap-reverse](#valdef-flex-wrap-wrap-reverse)

bottom

top

Axis Mappings for
[ltr](https://drafts.csswg.org/css-writing-modes-4/#valdef-direction-ltr) +
[vertical-rl](https://drafts.csswg.org/css-writing-modes-4/#valdef-writing-mode-vertical-rl) [Writing
Mode](https://drafts.csswg.org/css-writing-modes-4/#writing-mode) (e.g. Japanese)

[flex-flow](#propdef-flex-flow)

[main axis](#main-axis)

[[start]](#main-start)

[[end]](#main-end)

[cross axis](#cross-axis)

[[start]](#cross-start)

[[end]](#cross-end)

[row](#valdef-flex-direction-row) +
[nowrap](#valdef-flex-wrap-nowrap)/[wrap](#valdef-flex-wrap-wrap)

vertical

top

bottom

horizontal

right

left

[row-reverse](#valdef-flex-direction-row-reverse) +
[nowrap](#valdef-flex-wrap-nowrap)/[wrap](#valdef-flex-wrap-wrap)

bottom

top

[row](#valdef-flex-direction-row) +
[wrap-reverse](#valdef-flex-wrap-wrap-reverse)

top

bottom

left

right

[row-reverse](#valdef-flex-direction-row-reverse) +
[wrap-reverse](#valdef-flex-wrap-wrap-reverse)

bottom

top

[column](#valdef-flex-direction-column) +
[nowrap](#valdef-flex-wrap-nowrap)/[wrap](#valdef-flex-wrap-wrap)

vertical

right

left

horizontal

top

bottom

[column-reverse](#valdef-flex-direction-column-reverse) +
[nowrap](#valdef-flex-wrap-nowrap)/[wrap](#valdef-flex-wrap-wrap)

left

right

[column](#valdef-flex-direction-column) +
[wrap-reverse](#valdef-flex-wrap-wrap-reverse)

right

left

bottom

top

[column-reverse](#valdef-flex-direction-column-reverse) +
[wrap-reverse](#valdef-flex-wrap-wrap-reverse)

left

right

## [ Appendix B: `-webkit-` Legacy Properties]
*This appendix is normative.*

**These aliases are *deprecated* and authors *should not* use them
unless their content needs to support actively-used legacy UAs.**

For compatibility with general Web content, UAs that are Web browsers
must and other UAs may implement the following [legacy name
aliases](https://drafts.csswg.org/css-cascade-5/#legacy-name-alias):

Alias

Standard

-webkit-align-content

align-content

-webkit-align-items

align-items

-webkit-align-self

align-self

-webkit-flex

flex

-webkit-flex-basis

flex-basis

-webkit-flex-direction

flex-direction

-webkit-flex-flow

flex-flow

-webkit-flex-grow

flex-grow

-webkit-flex-shrink

flex-shrink

-webkit-flex-wrap

flex-wrap

-webkit-justify-content

justify-content

-webkit-order

order

Tests

- [flexbox_width-wrapping-column.html](https://wpt.fyi/results/css/css-flexbox/flexbox_width-wrapping-column.html "css/css-flexbox/flexbox_width-wrapping-column.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/flexbox_width-wrapping-column.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/flexbox_width-wrapping-column.html)
- [webkit-aliases.html](https://wpt.fyi/results/css/css-flexbox/parsing/webkit-aliases.html "css/css-flexbox/parsing/webkit-aliases.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/parsing/webkit-aliases.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/parsing/webkit-aliases.html)
- [webkit-box-vertical-writing-mode.html](https://wpt.fyi/results/css/css-flexbox/webkit-box-vertical-writing-mode.html "css/css-flexbox/webkit-box-vertical-writing-mode.html")
 [[(live
 test)]](http://wpt.live/css/css-flexbox/webkit-box-vertical-writing-mode.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-flexbox/webkit-box-vertical-writing-mode.html)

## [Acknowledgments]
Thanks for feedback and contributions to

Erik Anderson, Christian Biesinger, Tony Chang, Phil Cupp, Arron
Eicholz, James Elmore, Andrew Fedoniouk, Brian Heuston, Shinichiro
Hamaji, Daniel Holbert, Ben Horst, John Jansen, Brad Kemper, Kang-hao
Lu, Markus Mielke, Peter Moulder, Robert O'Callahan, Christoph Päper,
Ning Rogers, Peter Salas, Elliott Sprehn, Morten Stenshorne, Christian
Stockwell, Ojan Vafai, Eugene Veselov, Greg Whitworth, Boris Zbarsky.

## [Changes]
This section documents the changes since previous publications.

### [ Changes since the [14 October 2025 CRD](https://www.w3.org/TR/2025/CRD-css-flexbox-1-20251014/) ]
- [(#change-2025-scroll-axis) When appropriate, mention
 [scrollable
 axises](https://drafts.csswg.org/css-overflow-3/#scrollable-axis). ([Issue
 12289](https://github.com/w3c/csswg-drafts/issues/12289))]
- [(#change-2025-web-compat-intrinsic) Defined the
 web-compatible intrinsic sizing algo in [§ 9.9.1.2 Web-compatible
 Intrinsic Sizing Algorithm: Max-content Size and Min-content
 Single-line Size](#intrinsic-main-sizes-compat). ([Issue
 8884](https://github.com/w3c/csswg-drafts/issues/8884#issuecomment-1636311498))]
- [(#change-2025-cross-size-recalc) Clarified that the
 used cross size of an item is recalculated with the line's cross size
 as its available space. ([Issue
 11784](https://github.com/w3c/csswg-drafts/issues/11784))]

### [ Changes since the [19 November 2018 CR](https://www.w3.org/TR/2018/CR-css-flexbox-1-20181119/)]
A [Disposition of
Comments](https://drafts.csswg.org/css-flexbox-1/issues-cr-2018) is
available. Significant changes include:

- [(#change-2018-intrinsic-main-size-compat) Identify
 parts of [§ 9.9.1 Flex Container Intrinsic Main
 Sizes](#intrinsic-main-sizes) as ideal but not Web-compatible, and
 mark a refined Web-compatible algorithm as an ongoing investigation.
 ([Issue
 8884](https://github.com/w3c/csswg-drafts/issues/8884))]

- [(#change-2018-intrinsic-main-size-errors) Fix errors in
 the flexing rules in [§ 9.9.1 Flex Container Intrinsic Main
 Sizes](#intrinsic-main-sizes) to closer match the actual layout
 algorithm and avoid dividing by zero or exploding sizes as inputs
 approach zero. ([Issue
 7189](https://github.com/w3c/csswg-drafts/issues/7189#issuecomment-1172771501))]

- [(#change-2018-min-content-column-size-compat) Reform
 the [cross-size intrinsic sizing rules](#intrinsic-cross-sizes) for
 column wrap flex containers to yield better results. (Issue
 [6777](https://github.com/w3c/csswg-drafts/issues/6777))]

- [(#change-2018-static-pos-align-content) Use the
 [content
 edges](https://drafts.csswg.org/css-box-4/#content-edge) of the [flex
 container](#flex-container)
 for determining the [static-position
 rectangle](https://drafts.csswg.org/css-position-3/#static-position-rectangle) of flex container children, rather than doing extra
 layout work. This will result in ignoring
 [align-content](#propdef-align-content) on the flex container, but allow
 [align-self](#propdef-align-self) on the box itself to still take
 effect. ([Issue
 5843](https://github.com/w3c/csswg-drafts/issues/5843),
 [7596](https://github.com/w3c/csswg-drafts/issues/7596))]

- [(#change-2018-correctly-ignore-auto) Correctly ignore
 [auto](https://drafts.csswg.org/css-sizing-3/#valdef-width-auto) [preferred
 sizes](https://drafts.csswg.org/css-sizing-3/#preferred-size) in both min *and* max size contribution calculations.
 (It was accidentally omitted from the max, though it shows up
 correctly in the [changelog](#change-2017-flex-min-contribution)\...)
 ([Issue
 6455](https://github.com/w3c/csswg-drafts/issues/6455))]

- [(#change-2018-move-order) Moved the
 [order](https://drafts.csswg.org/css-display-4/#propdef-order) property definition to
 [\[CSS-DISPLAY-3\]](#biblio-css-display-3 "CSS Display Module Level 3").
 See [§ 5.4 Reordering and Accessibility: the order
 property](#order-property) for remaining explanation. ([Issue
 5865](https://github.com/w3c/csswg-drafts/issues/5865))]

- [(#change-2018-definite-basis-definite) Made [main
 size](#main-size) always
 [definite](#definite) for [flex
 items](#flex-item) with a
 [definite] [flex
 basis](#flex-flex-basis),
 to match implementations. ([Issue
 4311](https://github.com/w3c/csswg-drafts/issues/4311))]

 > 1. If the [flex
 > container](#flex-container) has a [definite](#definite) [main size](#main-size), [then the post-flexing [main
 > sizes](#main-size) of its
 > [flex items](#flex-item)
 > are treated as [definite](#definite)] ~~a [flex
 > item](#flex-item)'s
 > post-flexing [main size](#main-size) is treated as
 > [definite](#definite), even
 > though it can rely on the [indefinite]
 > sizes of any flex items in the same line~~ .
 > 2. [If a [flex item's](#flex-item) [flex
 > basis](#flex-flex-basis) is [definite](#definite), then its post-flexing [main
 > size](#main-size) is also
 > [definite].]

 > ~~Note: The main size of a [fully
 > inflexible](#fully-inflexible) item with a
 > [definite](https://drafts.csswg.org/css-sizing-3/#definite) [flex
 > basis](#flex-flex-basis)
 > is, by definition, [definite].~~
 >
 > [Note: This means that within [flex
 > layout](#flex-layout),
 > "definite" sizes can require performing layout. This was done to
 > allow percentages inside of [flex
 > items](#flex-item) to resolve
 > where authors expected them to resolve.]

- [(#change-2018-flex-column-wrap-fragmentation) Made the
 re-arrangement of [flex items](#flex-item) into independent stacks of flex lines on each page
 optional, and identified shortcomings in the sample algorithm.
 ([6855](https://github.com/w3c/csswg-drafts/issues/6855))]

- [(#change-2018-bracket-range-notation) Updated value
 syntax in property definition tables to use newer [CSS bracketed range
 notation](https://drafts.csswg.org/css-values-4/#css-bracketed-range-notation) reflecting the prose restrictions on negative values.
 (Editorial.)]

- [(#change-2018-preferred-aspect-ratio) Updated aspect
 ratio terminology to use the term [preferred aspect
 ratio](https://drafts.csswg.org/css-sizing-4/#preferred-aspect-ratio), and clarify any uses that are specific to [replaced
 elements](https://drafts.csswg.org/css-display-4/#replaced-element), in order to accommodate forthcoming
 [aspect-ratio](https://drafts.csswg.org/css-sizing-4/#propdef-aspect-ratio)
 property.]

- [(#change-2018-auto-min-aspect-ratio) Define interaction
 of
 [aspect-ratio](https://drafts.csswg.org/css-sizing-4/#propdef-aspect-ratio) and the [automatic minimum
 size](https://drafts.csswg.org/css-sizing-3/#automatic-minimum-size) by applying its effect to the [transferred size
 suggestion](#transferred-size-suggestion) and excluding it from the definiteness of the
 [specified size
 suggestion](#specified-size-suggestion). (Issues
 [6069](https://github.com/w3c/csswg-drafts/issues/6069) and
 [6794](https://github.com/w3c/csswg-drafts/issues/6794), [changeset
 A](https://github.com/w3c/csswg-drafts/pull/11690) and [changeset
 B](https://github.com/w3c/csswg-drafts/commit/ca4dc9e0a3815be0306645dab03f8ca52434baf9))]

- [(#change-2018-auto-min-size-overflow) Pin [automatic
 minimum
 size](https://drafts.csswg.org/css-sizing-3/#automatic-minimum-size) conditional on [computed
 value](https://drafts.csswg.org/css-cascade-5/#computed-value) of
 [overflow](https://drafts.csswg.org/css-overflow-3/#propdef-overflow) rather than on being a [scroll
 container](https://drafts.csswg.org/css-overflow-3/#scroll-container) to avoid cases such as [replaced
 elements](https://drafts.csswg.org/css-display-4/#replaced-element) whose computed [scrollable overflow
 values](https://drafts.csswg.org/css-overflow-3/#scrollable-overflow-value) resolve to
 [non-scrollable](https://drafts.csswg.org/css-overflow-3/#non-scrollable-overflow-value) [used
 values](https://drafts.csswg.org/css-cascade-5/#used-value).
 ([7714](https://github.com/w3c/csswg-drafts/issues/7714))]

- [(#change-2018-indefinite-min-intrinsic) Clarify that
 the rule exempting [content-based minimum
 sizes](#content-based-minimum-size) from making an item's size to be indefinite is
 limited to
 [auto](https://drafts.csswg.org/css-sizing-3/#valdef-width-auto), and does not affect other intrinsic sizing
 keywords. ([Issue
 6457](https://github.com/w3c/csswg-drafts/issues/6457))]

- [(#change-2018-collapsed-intrinsic-container) Explicitly
 excluded [collapsed flex
 items](#collapsed-flex-item) from the [intrinsic main size
 calculations](#intrinsic-main-sizes). ([Issue
 5985](https://github.com/w3c/csswg-drafts/issues/5985))]

 > The
 > **[max-content](https://drafts.csswg.org/css-sizing-3/#max-content) [main size](#main-size) of a [flex
 > container](#flex-container)** is the smallest size the [flex
 > container](#flex-container) can take while maintaining the [max-content
 > contributions](#intrinsic-item-contributions) of its [flex
 > items](#flex-item), insofar
 > as allowed by the items' own flexibility. [Considering only
 > non-[collapsed](#collapsed-flex-item) [flex items](#flex-item):]

 > However, for a
 > *[multi-line](#multi-line-flex-container)* container, it is simply the largest [min-content
 > contribution](#intrinsic-item-contributions) of all the
 > [non-[collapsed](#collapsed-flex-item)] [flex
 > items](#flex-item) in the
 > [flex container](#flex-container).

- [(#change-2018-used-cross-size) Clarified that the [flex
 base size](#flex-base-size)
 calculations rely on the *used* [cross
 size](#cross-size). ([Issue
 3736](https://github.com/w3c/csswg-drafts/issues/3736))]

 > ... then the flex base size is calculated from its
 > [used] inner cross size and the flex item's intrinsic
 > aspect ratio.

- [(#change-2018-flexible-length-text) Slightly
 restructured the prose in [§ 9.7 Resolving Flexible
 Lengths](#resolve-flexible-lengths) to fix errors. ([Issue
 5179](https://github.com/w3c/csswg-drafts/issues/5179))]

- [(#change-2018-cross-layout) Clarified that "performing
 layout" means using the block-level layout rules. ([Issue
 5188](https://github.com/w3c/csswg-drafts/issues/5188))]

 > **Determine the hypothetical cross size of each item** by performing
 > layout [as if it were an
 > [in-flow](https://drafts.csswg.org/css-display-4/#in-flow) [block-level
 > box](https://drafts.csswg.org/css-display-4/#block-level-box)] with the used [main
 > size](#main-size) and the
 > [given] available space ...

- [(#change-2018-cross-sizing) Rewrote flex-contain
 cross-sizing step to depend on the rules of whatever formatting
 context it's in, rather than assuming block-layout rules. ([Issue
 5190](https://github.com/w3c/csswg-drafts/issues/5190))]

 > **Determine the flex container's used cross size** [using the rules
 > of the [formatting
 > context](https://drafts.csswg.org/css-display-4/#formatting-context) in which it participates. If a content-based [cross
 > size](#cross-size) is needed,
 > use the sum of the [flex lines](#flex-line)\' [cross
 > sizes].]
 >
 > - If the cross size property is a
 > [definite](#definite) size,
 > use that, clamped by the used min and max [cross
 > sizes](#cross-size) of the
 > [flex container](#flex-container).
 > - Otherwise, use the sum of the flex lines\' cross sizes, clamped by
 > the used min and max [cross
 > sizes](#cross-size) of the
 > [flex container](#flex-container).

- [(#change-2018-aspect-ratio-box) Removed explicit
 mention of which box to use for calculating aspect-ratio, to allow for
 behavior introduced by the new
 [aspect-ratio](https://drafts.csswg.org/css-sizing-4/#propdef-aspect-ratio) property in
 [\[css-sizing-4\]](#biblio-css-sizing-4 "CSS Box Sizing Module Level 4").
 ([Issue
 5246](https://github.com/w3c/csswg-drafts/issues/5246/))]

 > then the flex base size is calculated from its used ~~inner~~ cross
 > size and the flex item's intrinsic aspect ratio.

- [(#change-2018-auto-min-contribution) Clarified that the
 [content-based minimum
 size](#content-based-minimum-size) of a flex item is a type of [intrinsic size
 contribution](https://drafts.csswg.org/css-sizing-3/#intrinsic-size-contribution), and thus impacted by associated rules in
 [\[CSS-SIZING-3\]](#biblio-css-sizing-3 "CSS Box Sizing Module Level 3").
 ([Issue
 5665](https://github.com/w3c/csswg-drafts/issues/5665#issuecomment-738391191))]

 > Note: The [content-based minimum
 > size](#content-based-minimum-size) is a type of [intrinsic size
 > contribution](https://drafts.csswg.org/css-sizing-3/#intrinsic-size-contribution), and thus the provisions in [CSS Sizing 3 § 5.2
 > Intrinsic
 > Contributions](https://drafts.csswg.org/css-sizing-3/#intrinsic-contribution)
 > apply.

- [(#change-2018-safe-fallback) Made the fallback
 alignment (in case of negative free space) for the [space-\*]
 keywords apply [safe]. ([Issue
 10154](https://github.com/w3c/csswg-drafts/issues/10154))]

- [(#change-2018-content-based-editorial) Redrafted the
 definition of [content-based minimum
 size](#content-based-minimum-size) for easier reading.
 (Editorial)]

- [(#change-2018-webkit-aliases) Added [Appendix B:
 -webkit- Legacy Properties](#webkit-aliases) to document `-webkit-`
 aliases of flex layout properties that are necessary for Web-compat.
 ([Issue
 5634](https://github.com/w3c/csswg-drafts/issues/5634))]

- [(#change-2018-blockification) Rephrased blockification
 rules in terms of [computed
 values](https://drafts.csswg.org/css-cascade-5/#computed-value). ([Issue
 4065](https://github.com/w3c/csswg-drafts/issues/4065))]

- Various minor editorial fixes and clarifications,

### [ Changes since the 16 October 2017 CR]
A [Disposition of
Comments](https://drafts.csswg.org/css-flexbox-1/issues-cr-2017) is also
available.

- [(#change-2017-margin-padding-percent) Removed the
 option for flex-item block-axis margins and paddings to be resolved
 against the block dimension; they must be resolved against the inline
 dimension, as for blocks. ([Issue
 2085](https://github.com/w3c/csswg-drafts/issues/2085))]

- [(#change-2017-flex-min-contribution) Floored [flex
 item](#flex-item)'s
 [min-content
 contribution](https://drafts.csswg.org/css-sizing-3/#min-content-contribution) by their [preferred
 size](https://drafts.csswg.org/css-sizing-3/#preferred-size) ([Issue
 2353](https://github.com/w3c/csswg-drafts/issues/2353)) and cleaned up
 associated wording to be more
 precise.]

 > The main-size [min-content
 > contribution](https://drafts.csswg.org/css-sizing-3/#min-content-contribution) of a [flex item](#flex-item) is the larger of its *outer* [min-content
 > size](https://drafts.csswg.org/css-sizing-3/#min-content) [and outer [preferred
 > size](https://drafts.csswg.org/css-sizing-3/#preferred-size) (its
 > [width](https://drafts.csswg.org/css-sizing-3/#propdef-width)/[height](https://drafts.csswg.org/css-sizing-3/#propdef-height) as appropriate) if that is not
 > [auto](https://drafts.csswg.org/css-sizing-3/#valdef-width-auto)] , clamped by its [flex base
 > size](#flex-base-size) as
 > a maximum (if it is not growable) and/or as a minimum (if it is not
 > shrinkable), and then further clamped by its
 > [min](#min-main-size-property)/[max main size
 > properties](#max-main-size-property).
 >
 > The main-size [max-content
 > contribution](https://drafts.csswg.org/css-sizing-3/#max-content-contribution) of a [flex item](#flex-item) is the larger of its *outer* [max-content
 > size](https://drafts.csswg.org/css-sizing-3/#max-content) and [outer] ~~specified~~
 > [preferred] size (its
 > [width](https://drafts.csswg.org/css-sizing-3/#propdef-width)/[height](https://drafts.csswg.org/css-sizing-3/#propdef-height) as appropriate ~~,~~
 > [)] if that is ~~definite~~ [not
 > [auto](https://drafts.csswg.org/css-sizing-3/#valdef-width-auto)] , clamped by its [flex base
 > size](#flex-base-size) as
 > a maximum (if it is not growable) and/or as a minimum (if it is not
 > shrinkable), and then further clamped by its
 > [min](#min-main-size-property)/[max main size
 > properties](#max-main-size-property).

- [(#change-2017-content-desc) Added some (effectively
 informative) prose and a cross-reference to more clearly define
 [flex-basis:
 content](#propdef-flex-basis).]

 > Indicates ~~automatic sizing~~ [an [automatic
 > size](#algo-main-item)] based on the [flex
 > item](#flex-item)'s content.
 > [(It is typically equivalent to the [max-content
 > size](https://drafts.csswg.org/css-sizing-3/#max-content), but with adjustments to handle aspect ratios,
 > intrinsic sizing constraints, and orthogonal flows; see
 > [details](#algo-main-item) in [§ 9 Flex Layout
 > Algorithm](#layout-algorithm).)]

- [(#change-2017-min-size-auto) Moved the definition of
 the
 [auto](https://drafts.csswg.org/css-sizing-3/#valdef-width-auto) keyword for
 [min-width](https://drafts.csswg.org/css2/#propdef-min-width) and
 [min-height](https://drafts.csswg.org/css2/#propdef-min-height) to
 [\[CSS-SIZING-3\]](#biblio-css-sizing-3 "CSS Box Sizing Module Level 3").
 The definition of what an [automatic minimum
 size](https://drafts.csswg.org/css-sizing-3/#automatic-minimum-size) for flex items is remains here. ([Issue
 1920](https://github.com/w3c/csswg-drafts/issues/1920), [Issue
 2103](https://github.com/w3c/csswg-drafts/issues/2103))]

- [(#change-2017-min-size-auto-computation) Altered the
 computation of
 [auto](https://drafts.csswg.org/css-sizing-3/#valdef-width-auto) in
 [min-width](https://drafts.csswg.org/css2/#propdef-min-width) and
 [min-height](https://drafts.csswg.org/css2/#propdef-min-height) such that it always computes to
 itself---​although its [resolved
 value](https://drafts.csswg.org/cssom-1/#resolved-value) remains zero on CSS2 display types. ([Issue
 2230](https://github.com/w3c/csswg-drafts/issues/2230), [Issue
 2248](https://github.com/w3c/csswg-drafts/issues/2248))]

- [(#change-2017-used-min-sizes) Clarified that min/max
 clamping is according to the [used
 value](https://drafts.csswg.org/css-cascade-5/#used-value) of the min/max size properties---​which in the case of
 tables with
 [auto](https://drafts.csswg.org/css2/#valdef-table-layout-auto) layout, is floored by the table's [min-content
 size](https://drafts.csswg.org/css-sizing-3/#min-content). ([Issue
 2442](https://github.com/w3c/csswg-drafts/issues/2442))]

- [(#change-2017-break-propagation) Clarified that break
 propagation does not affect computed values and that [order-modified
 document
 order](https://drafts.csswg.org/css-display-4/#order-modified-document-order) is used. ([Issue
 2614](https://github.com/w3c/csswg-drafts/issues/2614))]

 > The exact layout of a fragmented flex container is not defined in
 > this level of Flexible Box Layout. However, breaks inside a flex
 > container are subject to the following rules [(interpreted using
 > [order-modified document
 > order](https://drafts.csswg.org/css-display-4/#order-modified-document-order))] :
 >
 > - In a row flex container, the
 > [break-before](https://drafts.csswg.org/css-break-3/#propdef-break-before) and
 > [break-after](https://drafts.csswg.org/css-break-3/#propdef-break-after) values on flex items are
 > propagated to the flex line. The
 > [break-before] values on
 > the first line and the [break-after] values on the last line are propagated to the flex
 > container.
 >
 > Break propagation (like
 > [text-decoration](https://drafts.csswg.org/css-text-decor-4/#propdef-text-decoration) propagation) does not affect
 > [computed
 > values](https://drafts.csswg.org/css-cascade-5/#computed-value).

- [(#change-2017-auto-min-zero) Clarified that if the
 [automatic minimum
 size](https://drafts.csswg.org/css-sizing-3/#automatic-minimum-size) resolves directly to zero rather than being a
 [content-based minimum
 size](#content-based-minimum-size), it does not cause
 indefiniteness.]

 > For the purpose of calculating an intrinsic size of the element
 > (e.g. the element's [min-content
 > size](https://drafts.csswg.org/css-sizing-3/#min-content)), ~~this value~~ [a content-based minimum
 > size] causes the element's size in that axis to become
 > indefinite (even if e.g. its
 > [width](https://drafts.csswg.org/css-sizing-3/#propdef-width) property specifies a
 > [definite](#definite) size).

- [(#change-2017-auto-min-size) Editorial improvements to
 the [automatic minimum size](#min-size-auto). ([Issue
 2385](https://github.com/w3c/csswg-drafts/issues/2385))]

- Some minor editorial fixes and clarifications, including updates to
 vocabulary to match updates to other CSS modules.

### [ Changes since the 26 May 2016 CR]
A [Disposition of
Comments](https://drafts.csswg.org/css-flexbox-1/issues-cr-20160526) is
also available.

#### [ Substantive Changes and Bugfixes]
- [(#change-2016-box-sizing-basis) To allow flex factors
 to actually represent absolute ratios of flex item sizes as was
 originally intended (see various examples), removed the flooring of
 content-box sizes at zero for the purpose of finding the item's [flex
 base size](#flex-base-size), since this type of ratio requires a [flex base
 size] of zero, which would otherwise only
 be possible if margins, borders, and padding are also all zero. (The
 flooring remains in effect, alongside the min and max size
 constraints, in calculating the hypothetical and final sizes of the
 item.) ([Issue
 316](https://github.com/w3c/csswg-drafts/issues/316))]

 > When determining the [flex base
 > size](#flex-base-size),
 > the item's min and max main size properties are ignored (no clamping
 > occurs). [Furthermore, the sizing calculations that floor the
 > content box size at zero when applying
 > [box-sizing](https://drafts.csswg.org/css-sizing-3/#propdef-box-sizing) are also ignored. (For example,
 > an item with a specified size of zero, positive padding, and
 > [box-sizing: border-box] will
 > have an outer [flex base
 > size](#flex-base-size) of
 > zero---​and hence a negative inner [flex base
 > size].)]
 >
 > The [hypothetical main
 > size](#hypothetical-main-size) is the item's [flex base
 > size](#flex-base-size)
 > clamped according to its min and max main size properties [(and
 > flooring the content box size at zero)] .

 > **Fix min/max violations.** Clamp each non-frozen item's [target
 > main size](#target-main-size) by its min and max main size properties [and floor
 > its content-box size at zero] . If the item's [target
 > main size] was made smaller by this,
 > it's a max violation. If the item's [target main
 > size] was made larger by this,

- [(#change-2016-max-contribution) To prevent empty flex
 items in shrink-to-fit containers from collapsing to zero even when
 given a specified size, the specified size is now accounted for in
 calculating its [max-content
 contribution](https://drafts.csswg.org/css-sizing-3/#max-content-contribution) in [§ 9.9.3 Flex Item Intrinsic Size
 Contributions](#intrinsic-item-contributions). ([Issue
 1435](https://github.com/w3c/csswg-drafts/issues/1435))]

 > The **main-size [max-content
 > contribution](https://drafts.csswg.org/css-sizing-3/#max-content-contribution) of a [flex item](#flex-item)** is [the larger of] its *outer*
 > [max-content
 > size](https://drafts.csswg.org/css-sizing-3/#max-content) [and specified size (its
 > [width](https://drafts.csswg.org/css-sizing-3/#propdef-width)/[height](https://drafts.csswg.org/css-sizing-3/#propdef-height) as appropriate, if that is
 > [definite](#definite))] , clamped by its [flex base
 > size](#flex-base-size) as
 > a maximum (if it is not growable) and/or as a minimum (if it is not
 > shrinkable), and then further clamped by its
 > [min](#min-main-size-property)/[max main size
 > properties](#max-main-size-property).

- [(#change-2016-definite-basis) Since at least two
 implementations ended up allowing percentages inside flex items with
 indefinite flex basis to resolve anyway, removed the condition
 requiring definite flex basis. ([Issue
 1679](https://github.com/w3c/csswg-drafts/issues/1679))]

 > If ~~a [flex item](#flex-item) has a [definite](#definite) [flex
 > basis](#flex-flex-basis)
 > and~~ the [flex
 > container](#flex-container) has a [definite](#definite) [main size](#main-size), ~~its~~ [a [flex
 > item](#flex-item)'s] post-flexing main size is treated as
 > [definite] (even though it might technically
 > rely on the ~~sizes of [indefinite](#definite) siblings to resolve its flexed main size~~ the
 > [indefinite] sizes of any flex items in the
 > same line).

- [(#change-2016-align-self-as-specified) For ease of
 implementation,
 [auto](#valdef-align-items-auto) value of
 [align-self](#propdef-align-self) now computes to itself always. See
 [related previous change](#change-2015-align-self-auto) requiring this
 computation for absolutely-positioned elements. ([Issue
 440](https://github.com/w3c/csswg-drafts/issues/440), [Issue
 644](https://github.com/w3c/csswg-drafts/issues/644))]

 > Computed value:
 >
 > ~~[auto](#valdef-align-items-auto) computes to parent's
 > [align-items](#propdef-align-items) value; otherwise~~ as specified
 >
 > ...
 >
 > ~~On absolutely positioned elements, a value of
 > [auto](#valdef-align-items-auto) computes to itself. On all other elements, a
 > value of [auto] for
 > [align-self](#propdef-align-self) computes to the value of
 > [align-items](#propdef-align-items) on the element's parent, or
 > [stretch](#valdef-align-items-stretch) if the element has no parent.~~

- [(#change-2016-baseline-alignment) Change [flex
 items](#flex-item) in
 orthogonal flows and [flex items] without a
 baseline to both synthesize their alignment baseline from the [flex
 item]'s border box. ([Issue
 373](https://github.com/w3c/csswg-drafts/issues/373))]

- [(#change-2016-main-cross-baseline) Fix main/cross error
 in definition of [cross-axis baseline
 set](#cross-axis-baseline). ([Issue
 792](https://github.com/w3c/csswg-drafts/issues/792))]

 > Otherwise, the flex container has no first/last ~~main~~
 > [cross] -axis baseline set...

- [(#change-2016-table-wrapper) Restore
 accidentally-deleted text about tables as flex items. See [anonymous
 box change](#change-2015-anonymous-fixup). ([Issue
 547](https://github.com/w3c/csswg-drafts/issues/547))]

 > In the case of flex items with [display:
 > table](https://drafts.csswg.org/css-display-4/#propdef-display), the table wrapper box becomes the [flex
 > item](#flex-item), and the
 > [order](https://drafts.csswg.org/css-display-4/#propdef-order) and
 > [align-self](#propdef-align-self) properties apply to it. The contents
 > of any caption boxes contribute to the calculation of the table
 > wrapper box's min-content and max-content sizes. However, like
 > [width](https://drafts.csswg.org/css-sizing-3/#propdef-width) and
 > [height](https://drafts.csswg.org/css-sizing-3/#propdef-height), the
 > [flex](#propdef-flex) longhands apply to the table box as follows:
 > the [flex item]'s final size is calculated by
 > performing layout as if the distance between the table wrapper box's
 > edges and the table box's content edges were all part of the table
 > box's border+padding area, and the table box were the [flex
 > item].

- [(#change-2016-auto-margin-abspos) Clarified that auto
 margins are treated as zero for the purpose of calculating a
 absolutely-positioned flex container child's static position. ([Issue
 665](https://github.com/w3c/csswg-drafts/issues/665))]

 > For this purpose, a value of [align-self:
 > auto](#propdef-align-self) is treated identically to
 > [start](https://drafts.csswg.org/css-align-3/#valdef-self-position-start) [, and [auto] margins are treated as
 > zero] .

- [(#change-2016-floor-intrinsic-size) When clamping by
 the [max main size
 property](#max-main-size-property) in the [calculation of the flex container's intrinsic
 size](#intrinsic-main-sizes), be sure to floor by the [min main size
 property](#min-main-size-property). ([Issue
 361](https://github.com/w3c/csswg-drafts/issues/361))]

 > Within each line, find the largest
 > `max-content flex fraction` among all the [flex
 > items](#flex-item). Add each
 > item's [flex base size](#flex-base-size) to the product of its [flex grow
 > factor](#flex-flex-grow-factor) (or [scaled flex shrink
 > factor](#scaled-flex-shrink-factor), if the chosen
 > `max-content flex fraction` was negative) and the chosen
 > `max-content flex fraction`, then clamp that result [ing
 > item size according to] ~~by~~ the max [and
 > min] main size propert ~~y~~ [ies] .

- [(#change-2016-abspos-no-order-fix) Added missing edits
 for [change](#change-2016-abspos-no-order) that made
 [order](https://drafts.csswg.org/css-display-4/#propdef-order) not apply to
 absolutely-positioned children of a flex container. ([Issue
 1439](https://github.com/w3c/csswg-drafts/issues/1439))]

 > Applies to:
 >
 > [flex items](#flex-item)
 > ~~and absolutely-positioned children of [flex
 > containers](#flex-container)~~
 >
 > The
 > [order](https://drafts.csswg.org/css-display-4/#propdef-order) property controls the order in
 > which ~~children of a flex container~~ [flex items]
 > appear within the flex container, by assigning them to ordinal
 > groups. ...
 >
 > [Absolutely-positioned children of a [flex
 > container](#flex-container) are treated as having [order:
 > 0](https://drafts.csswg.org/css-display-4/#propdef-order) for the purpose of determining their
 > painting order relative to [flex
 > items](#flex-item).]

 > Unless otherwise specified by a future specification, this property
 > has no effect on boxes that are not ~~children of a [flex
 > container](#flex-container)~~ [[flex items](#flex-item)] .

- [(#change-2016-flex-direction-baseline) Take
 [flex-direction](#propdef-flex-direction) into account when determining
 first/last baseline of the flex container. ([Issue
 995](https://github.com/w3c/csswg-drafts/issues/995))]

 > To this end, the baselines of a flex container are determined as
 > follows (after reordering with
 > [order](https://drafts.csswg.org/css-display-4/#propdef-order) [, and taking
 > [flex-direction](#propdef-flex-direction) into account] ):
 >
 > ...
 >
 > 1. If any of the [flex items](#flex-item) on the flex container's ~~first/last~~
 > [startmost/endmost] [flex
 > line](#flex-line)
 > [participate in baseline
 > alignment](#baseline-participation),
 > the flex container's first/last [main-axis baseline
 > set](#main-axis-baseline) ...
 > 2. Otherwise, if the flex container has at least one [flex
 > item](#flex-item), the
 > flex container's first/last [main-axis baseline
 > set](#main-axis-baseline) is
 > [generated](https://drafts.csswg.org/css-align-3/#generate-baselines) from the [alignment
 > baseline](https://drafts.csswg.org/css-align-3/#alignment-baseline) of the ~~first/last~~
 > [startmost/endmost] [flex
 > item]. ...
 > 3. Otherwise, the flex container has no first/last main-axis
 > [baseline
 > set](https://drafts.csswg.org/css-align-3/#baseline-set), ...
 >
 > ...
 >
 > 1. If the flex container has at least one [flex
 > item](#flex-item), the
 > flex container's first/last [cross-axis baseline
 > set](#cross-axis-baseline) is
 > [generated](https://drafts.csswg.org/css-align-3/#generate-baselines) from the [alignment
 > baseline](https://drafts.csswg.org/css-align-3/#alignment-baseline) of the ~~first/last~~
 > [startmost/endmost] [flex
 > item]. ...

- [(#change-2016-space-between-single-line) Define
 [align-content:
 space-between](#propdef-align-content) handling of a single [flex
 line](#flex-line) as equivalent
 to
 [start](https://drafts.csswg.org/css-align-3/#valdef-self-position-start). ([Issue
 718](https://github.com/w3c/csswg-drafts/issues/718))]

 > Lines are evenly distributed in the flex container. If the leftover
 > free-space is negative [or there is only a single [flex
 > line](#flex-line) in the flex
 > container,] this value is identical to
 > [flex-start](#valdef-align-content-flex-start).

- [(#change-2016-axis-error) Fixed error in [axis mapping
 table](#axis-mapping). ([Issue
 205](https://github.com/w3c/csswg-drafts/issues/205))]

- [(#change-2016-reword-min-auto-fix) Restored definition
 of the [automatic minimum
 size](https://drafts.csswg.org/css-sizing-3/#automatic-minimum-size) of boxes with neither [specified
 size](https://drafts.csswg.org/css-images-3/#specified-size) nor aspect ratio, which was lost in earlier
 [rewrite](#change-2016-reword-min-auto). ([Issue
 671](https://github.com/w3c/csswg-drafts/issues/671))]

#### [ Clarifications]
- [(#change-2016-main-cross-def) Made sure that [main
 size](#main-size) and [cross
 size](#cross-size) are defined
 for [flex containers](#flex-container) as well as for [flex
 items](#flex-item). ([Issue
 981](https://github.com/w3c/csswg-drafts/issues/981))]

- [(#change-2016-broken-spatial-note) Tweaked final
 clarifying sentence of note about spatial navigation. ([Issue
 1677](https://github.com/w3c/csswg-drafts/issues/1677))]

 > User agents, including browsers, accessible technology, and
 > extensions, may offer spatial navigation features. This section does
 > not preclude respecting the
 > [order](https://drafts.csswg.org/css-display-4/#propdef-order) property when determining
 > element ordering in such spatial navigation modes; indeed it would
 > need to be considered for such a feature to work. ~~However a UA
 > that uses
 > [order](https://drafts.csswg.org/css-display-4/#propdef-order) in determining sequential
 > navigation, but does not otherwise account for spatial relationships
 > among elements (as expressed by the various layout features of CSS
 > including and not limited to flex layout), is non-conforming.~~ [But
 > [order](https://drafts.csswg.org/css-display-4/#propdef-order) is not the only (or even the
 > primary) CSS property that would need to be considered for such a
 > spatial navigation feature. A well-implemented spatial navigation
 > feature would need to consider all the layout features of CSS that
 > modify spatial relationships.]

- Miscellaneous trivial editorial improvements.

### [ Changes since the 1 March 2016 CR]
A [Disposition of
Comments](https://drafts.csswg.org/css-flexbox-1/issues-cr-20160301) is
also available.

#### [ Substantive Changes and Bugfixes]
- [(#change-2016-intrinsic-percentage) Define how
 percentages are handled when calculating intrinsic [automatic minimum
 sizes](https://drafts.csswg.org/css-sizing-3/#automatic-minimum-size). ([Issue
 3](https://drafts.csswg.org/css-flexbox-1/issues-cr-20160301#issue-3))]

 > For the purpose of calculating an intrinsic size of the element
 > (e.g. the element's [min-content
 > size](https://drafts.csswg.org/css-sizing-3/#min-content)), this value causes the element's size in that axis
 > to become indefinite (even if e.g. its
 > [width](https://drafts.csswg.org/css-sizing-3/#propdef-width) property specifies a
 > [definite](#definite) size).
 > Note this means that percentages calculated against this size will
 > be treated as
 > [auto](https://drafts.csswg.org/css-sizing-3/#valdef-width-auto).
 >
 > [Nonetheless,] although this may require an additional
 > layout pass to re-resolve percentages in some cases, this value
 > (like the
 > [min-content](https://drafts.csswg.org/css-sizing-3/#valdef-width-min-content),
 > [max-content](https://drafts.csswg.org/css-sizing-3/#valdef-width-max-content), and
 > [fit-content](https://drafts.csswg.org/css-sizing-3/#valdef-width-fit-content) values defined in
 > [\[CSS-SIZING-3\]](#biblio-css-sizing-3 "CSS Box Sizing Module Level 3"))
 > does not prevent the resolution of percentage sizes within the item.

- [(#change-2016-definite-indefinite) Switched
 [definite](#definite) and
 [indefinite] to refer to the (more correct)
 definitions in
 [\[CSS-SIZING-3\]](#biblio-css-sizing-3 "CSS Box Sizing Module Level 3")
 instead of defining them inline in this module. ([Issue
 10](https://drafts.csswg.org/css-flexbox-1/issues-cr-20160301#issue-10))]

- [(#change-2016-abspos-no-order) Abspos children of a
 flexbox no longer respond to the
 [order](https://drafts.csswg.org/css-display-4/#propdef-order) property. ([Issue
 12](https://drafts.csswg.org/css-flexbox-1/issues-cr-20160301#issue-12))]

- [(#change-2016-baseline-sets) Updated [§ 8.5 Flex
 Container Baselines](#flex-baselines) to account for [baseline
 sets](https://drafts.csswg.org/css-align-3/#baseline-set) and [last-baseline
 alignment](https://drafts.csswg.org/css-align-3/#last-baseline-alignment). ([Issue
 13](https://drafts.csswg.org/css-flexbox-1/issues-cr-20160301#issue-13)))]

#### [ Clarifications]
- [(#change-2016-spatial-nav) Clarify that spatial
 navigation modes are allowed to handle
 [order](https://drafts.csswg.org/css-display-4/#propdef-order). ([Issue
 1](https://drafts.csswg.org/css-flexbox-1/issues-cr-20160301#issue-1))]

 > User agents, including browsers, accessible technology, and
 > extensions, may offer spatial navigation features. This section does
 > not preclude respecting the
 > [order](https://drafts.csswg.org/css-display-4/#propdef-order) property when determining
 > element ordering in such spatial navigation modes; indeed it would
 > need to be considered for such a feature to work. However a UA that
 > uses [order] in determining
 > sequential navigation, but does not otherwise account for spatial
 > relationships among elements (as expressed by the various layout
 > features of CSS including and not limited to flex layout), is
 > non-conforming.

- [(#change-2016-definite-3) Cross-reference an additional
 case of definiteness in [§ 9.8 Definite and Indefinite
 Sizes](#definite-sizes) ([Issue
 2](https://drafts.csswg.org/css-flexbox-1/issues-cr-20160301#issue-2))]

 > Once the cross size of a flex line has been determined, items in
 > auto-sized flex containers are also considered definite for the
 > purpose of layout; see [step 11](#algo-stretch).

- [(#change-2016-auto-content-wording) Improve wording for
 how unresolveable percentage [flex
 basis](#flex-flex-basis)
 values transmute to
 [content](#valdef-flex-basis-content). ([Issue
 6](https://drafts.csswg.org/css-flexbox-1/issues-cr-20160301#issue-6))]

 > For all values other than
 > [auto](#valdef-flex-basis-auto) and
 > [content](#valdef-flex-basis-content) (defined above),
 > [flex-basis](#propdef-flex-basis) is resolved the same way as
 > [width](https://drafts.csswg.org/css-sizing-3/#propdef-width) in horizontal writing modes
 > [\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification"),
 > [except that if a value would resolve to
 > [auto](https://drafts.csswg.org/css-sizing-3/#valdef-width-auto) for
 > [width](https://drafts.csswg.org/css-sizing-3/#propdef-width), it instead resolves to
 > [content](#valdef-flex-basis-content) for
 > [flex-basis](#propdef-flex-basis)] . For example,
 > percentage values of [flex-basis] are resolved against the flex item's containing block
 > (i.e. its [flex
 > container](#flex-container)); and if that containing block's size is
 > [indefinite](#definite), ~~the
 > result is the same as a [main size](#main-size) of
 > [auto](https://drafts.csswg.org/css-sizing-3/#valdef-width-auto) (which in this case is treated as
 > [content](#valdef-flex-basis-content))~~ [the used value for
 > [flex-basis](#propdef-flex-basis) is
 > [content](#valdef-flex-basis-content)] .

- [(#change-2016-inflexible-definite) Clarify that
 inflexible items with a [definite](#definite) [flex
 basis](#flex-flex-basis)
 have a [definite size]. ([Issue
 8](https://drafts.csswg.org/css-flexbox-1/issues-cr-20160301#issue-8),
 [Issue
 11](https://drafts.csswg.org/css-flexbox-1/issues-cr-20160301#issue-11))]

 > A [flex item](#flex-item) is
 > [fully inflexible](#fully-inflexible) if both its
 > [flex-grow](#propdef-flex-grow) and
 > [flex-shrink](#propdef-flex-shrink) values are zero, and
 > [flexible](#flexible) otherwise.

 > The main size of a [fully
 > inflexible](#fully-inflexible) item with a
 > [definite](#definite) [flex
 > basis](#flex-flex-basis)
 > is, by definition, [definite].

- [(#change-2016-reword-min-auto) Reworded definition of
 the
 [auto](https://drafts.csswg.org/css-sizing-3/#valdef-width-auto) value to be easier to understand. ([Issue
 9](https://drafts.csswg.org/css-flexbox-1/issues-cr-20160301#issue-9))]

 > On a [flex item](#flex-item)
 > whose
 > [overflow](https://drafts.csswg.org/css-overflow-3/#propdef-overflow) is
 > [visible](https://drafts.csswg.org/css-overflow-3/#valdef-overflow-visible) in the [main
 > axis](#main-axis), when
 > specified on the [flex item's] main-axis
 > min-size property, ~~the following table gives the minimum size
 > ...~~ [specifies an [automatic minimum
 > size](https://drafts.csswg.org/css-sizing-3/#automatic-minimum-size).]
 >
 > In general, the [automatic minimum
 > size](https://drafts.csswg.org/css-sizing-3/#automatic-minimum-size) ... defined below:

- [(#change-2016-clarify-staticpos) Slightly reworded the
 section on determining the static position of absolutely-positioned
 children to be clearer.]

- [(#change-2016-animation-type) Adjusted format of
 Animatable lines to be clearer about animating
 keywords.]

- Miscellaneous trivial editorial improvements.

### [ Changes since the 14 May 2015 LCWD]
A [Disposition of
Comments](https://drafts.csswg.org/css-flexbox-1/issues-lc-20150514) is
also available.

#### [ Substantive Changes and Bugfixes]
- [(#change-2015-flex-basis-zero) Revert
 [flex](#propdef-flex) shorthand [change](#change-2012-flex-basis-zero)
 of omitted
 [flex-basis](#propdef-flex-basis) back to [0], since that was a
 hacky way of solving an intrinsic size problem, and isn't needed (and
 gives bad results) given a correct implementation of [§ 9.9 Intrinsic
 Sizes](#intrinsic-sizes). ([Issue
 13](https://drafts.csswg.org/css-flexbox-1/issues-lc-20150514#issue-13))]

 > When omitted from the [flex](#propdef-flex) shorthand, its specified value
 > is [0~~%~~].

 >
 >
 > [flex: \<positive-number\>](#propdef-flex)
 > : Equivalent to [flex: \<positive-number\> 1
 > 0~~%~~](#propdef-flex).

- [(#change-2015-anonymous-fixup) Changed [flex item
 determination](#flex-item) to operate on each
 element directly, and not on its anonymous wrapper box, if any.
 ([Issue
 6](https://drafts.csswg.org/css-flexbox-1/issues-lc-20150514#issue-6))]

 > - ~~[float](https://drafts.csswg.org/css2/#propdef-float) and
 > [clear](https://drafts.csswg.org/css2/#propdef-clear) have no effect on a [flex
 > item](#flex-item),~~
 > [[float](https://drafts.csswg.org/css2/#propdef-float) and
 > [clear](https://drafts.csswg.org/css2/#propdef-clear) do not create floating or
 > clearance of [flex item](#flex-item),] and do not take it out-of-flow.
 > ~~However, the
 > [float](https://drafts.csswg.org/css2/#propdef-float) property can still affect box
 > generation by influencing the
 > [display](https://drafts.csswg.org/css-display-4/#propdef-display) property's computed value.~~

 > Some values of
 > [display](https://drafts.csswg.org/css-display-4/#propdef-display) trigger the creation of
 > anonymous boxes around the original box. It's the outermost
 > box---the direct child of the [flex
 > container](#flex-container) box---that becomes a [flex
 > item](#flex-item). For
 > example, given two contiguous child elements with [display:
 > table-cell], the [anonymous table
 > wrapper box generated around
 > them](https://www.w3.org/TR/CSS2/tables.html#anonymous-boxes)
 > [\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")
 > becomes the [flex item].
 >
 > In the case of flex items with [display:
 > table](https://drafts.csswg.org/css-display-4/#propdef-display), the table wrapper box becomes the [flex
 > item](#flex-item), and the
 > [order](https://drafts.csswg.org/css-display-4/#propdef-order) and
 > [align-self](#propdef-align-self) properties apply to it. The contents
 > of any caption boxes contribute to the calculation of the table
 > wrapper box's min-content and max-content sizes. However, like
 > [width](https://drafts.csswg.org/css-sizing-3/#propdef-width) and
 > [height](https://drafts.csswg.org/css-sizing-3/#propdef-height), the
 > [flex](#propdef-flex) longhands apply to the table box as follows:
 > the [flex item]'s final size is calculated by
 > performing layout as if the distance between the table wrapper box's
 > edges and the table box's content edges were all part of the table
 > box's border+padding area, and the table box were the [flex
 > item].
 >
 > Note: Some values of
 > [display](https://drafts.csswg.org/css-display-4/#propdef-display) normally trigger the creation
 > of anonymous boxes around the original box. If such a box is a [flex
 > item](#flex-item), it is
 > blockified first, and so anonymous box creation will not happen. For
 > example, two contiguous [flex items] with
 > [display: table-cell] will become
 > two separate [display: block] [flex
 > items], instead of being wrapped into a
 > single anonymous table.

- [(#change-2015-min-auto-intrinsic-percentages) Defined
 that any size adjustment imposed by a box's [min-width: auto] is
 consulted when percentage-sizing any of its contents. ([Issue
 3](https://drafts.csswg.org/css-flexbox-1/issues-lc-20150514#issue-3))]

 > ~~In order to prevent cycling sizing, the
 > [auto](#valdef-flex-basis-auto) value of
 > [min-height](https://drafts.csswg.org/css2/#propdef-min-height) and
 > [max-height](https://drafts.csswg.org/css2/#propdef-max-height) does not factor into the
 > percentage size resolution of the box's contents. For example, a
 > percentage-height block whose flex item parent has [height: 120em;
 > min-height:
 > auto](https://drafts.csswg.org/css-sizing-3/#propdef-height) will size itself against [height:
 > 120em] regardless of the impact that
 > [min-height] might have on
 > the used size of the flex item.~~
 >
 > [Although this may require an additional layout pass to re-resolve
 > percentages in some cases, the
 > [auto](https://drafts.csswg.org/css-sizing-3/#valdef-width-auto) value of
 > [min-width](https://drafts.csswg.org/css2/#propdef-min-width) and
 > [min-height](https://drafts.csswg.org/css2/#propdef-min-height) (like the
 > [min-content](https://drafts.csswg.org/css-sizing-3/#valdef-width-min-content),
 > [max-content](https://drafts.csswg.org/css-sizing-3/#valdef-width-max-content), and
 > [fit-content](https://drafts.csswg.org/css-sizing-3/#valdef-width-fit-content) values defined in
 > [\[CSS-SIZING-3\]](#biblio-css-sizing-3 "CSS Box Sizing Module Level 3"))
 > does not prevent the resolution of percentage sizes within the
 > item.]

- [(#change-2015-intrinsic-items) Correct intrinsic sizing
 rules to handle inflexible items. ([Issue
 1](https://drafts.csswg.org/css-flexbox-1/issues-lc-20150514#issue-1))]

 > The main-size
 > [min-content](https://drafts.csswg.org/css-sizing-3/#min-content-contribution)/[max-content
 > contribution](https://drafts.csswg.org/css-sizing-3/#max-content-contribution) of a [flex item](#flex-item) is its outer ~~[hypothetical main
 > size](#hypothetical-main-size) when sized under a
 > [min-content](https://drafts.csswg.org/css-sizing-3/#min-content-constraint)/[max-content
 > constraint](https://drafts.csswg.org/css-sizing-3/#max-content-constraint) (respectively)~~ [The **main-size
 > [min-content](https://drafts.csswg.org/css-sizing-3/#min-content-contribution)/[max-content
 > contribution](https://drafts.csswg.org/css-sizing-3/#max-content-contribution) of a [flex item](#flex-item)** is its *outer*
 > [min-content](https://drafts.csswg.org/css-sizing-3/#min-content)/[max-content
 > size](https://drafts.csswg.org/css-sizing-3/#max-content), clamped by its [flex base
 > size](#flex-base-size) as
 > a maximum (if it is not growable) and/or as a minimum (if it is not
 > shrinkable), and then further clamped by its
 > [min](#min-main-size-property)/[max main size
 > properties](#max-main-size-property)] .

- [(#change-2015-intrinsic-main-container) Correct errors
 in [flex container](#flex-container) main-axis intrinsic sizing. ([Issue
 1](https://drafts.csswg.org/css-flexbox-1/issues-lc-20150514#issue-1))]

 > The
 > [max-content](https://drafts.csswg.org/css-sizing-3/#max-content) [main size](#main-size) of a [flex
 > container](#flex-container) is the smallest size the [flex
 > container] can take while maintaining the
 > [max-content
 > contributions](https://drafts.csswg.org/css-sizing-3/#max-content-contribution) of its [flex
 > items](#flex-item):
 >
 > 1. For each [flex item](#flex-item), subtract its [outer] [flex base
 > size](#flex-base-size) from its [max-content
 > contribution](https://drafts.csswg.org/css-sizing-3/#max-content-contribution) size ~~, then divide by its [flex grow
 > factor](#flex-flex-grow-factor), floored at 1, or by its [scaled flex shrink
 > factor](#scaled-flex-shrink-factor) (if the result was negative, flooring the [flex
 > shrink
 > factor](#flex-flex-shrink-factor) at 1 if necessary)~~ . [If that result is not
 > zero, divide it by (if the result was positive) its [flex grow
 > factor](#flex-flex-grow-factor) floored at 1, or (if the result was negative)
 > by its [scaled flex shrink
 > factor](#scaled-flex-shrink-factor), having floored the [flex shrink
 > factor](#flex-flex-shrink-factor) at 1.] This is the item's
 > `max-content flex fraction`.

- [(#change-2015-intrinsic-cross-container) Correct errors
 in [flex container](#flex-container) cross-axis intrinsic sizing, and specify
 commonly-implemented min-content sizing heuristic for multi-line
 column flex containers. ([Issue
 12](https://drafts.csswg.org/css-flexbox-1/issues-lc-20150514#issue-12))]

 > The
 > [min-content](https://drafts.csswg.org/css-sizing-3/#min-content) [cross size](#cross-size) and
 > [max-content](https://drafts.csswg.org/css-sizing-3/#max-content) [cross size] of a flex
 > container are the [cross size] of the flex
 > container after performing layout into the given available
 > [main-axis](#main-axis) space
 > and infinite available
 > [cross-axis](#cross-axis)
 > space.
 >
 > The
 > [min-content](https://drafts.csswg.org/css-sizing-3/#min-content)/[max-content](https://drafts.csswg.org/css-sizing-3/#max-content) [cross size](#cross-size) of a
 > *[single-line](#single-line-flex-container)* [flex
 > container](#flex-container) is the largest [min-content
 > contribution](https://drafts.csswg.org/css-sizing-3/#min-content-contribution)/[max-content
 > contribution](https://drafts.csswg.org/css-sizing-3/#max-content-contribution) (respectively) of its [flex
 > items](#flex-item).
 >
 > For a
 > *[multi-line](#multi-line-flex-container)* [flex
 > container](#flex-container), the
 > [min-content](https://drafts.csswg.org/css-sizing-3/#min-content)/[max-content](https://drafts.csswg.org/css-sizing-3/#max-content) [cross size](#cross-size) is the sum of the flex line cross sizes resulting
 > from sizing the flex container under a
 > [cross-axis](#cross-axis)
 > [min-content
 > constraint](https://drafts.csswg.org/css-sizing-3/#min-content-constraint)/[max-content
 > constraint](https://drafts.csswg.org/css-sizing-3/#max-content-constraint) (respectively). However, if the [flex
 > container] is [flex-flow: column
 > wrap;](#propdef-flex-flow), then it's sized by first finding the largest
 > [min-content](https://drafts.csswg.org/css-sizing-3/#min-content-contribution)/[max-content]
 > cross-size contribution among the [flex
 > items](#flex-item)
 > (respectively), then using that size as the [available
 > space](https://drafts.csswg.org/css-sizing-3/#available) in the [cross axis] for each
 > of the [flex items] during layout.
 >
 > This heuristic for [column wrap] [flex
 > containers](#flex-container) gives a reasonable approximation of the size that
 > the [flex container] should be, with
 > each flex item ending up as min(`item’s own max-content`,
 > `maximum min-content among all items`), and each [flex
 > line](#flex-line) no larger
 > than its largest [flex item](#flex-item). It's not a *perfect* fit in some cases, but doing
 > it completely correct is insanely expensive, and this works
 > reasonably well.

- [(#change-2015-a11y-tools) Add explicit conformance
 criteria on authoring tools to keep presentation and DOM order in sync
 unless author explicitly indicates a desire to make them out-of-sync.
 ([Issue
 8](https://drafts.csswg.org/css-flexbox-1/issues-lc-20150514#issue-8))]

 > In order to preserve the author's intended ordering in all
 > presentation modes, authoring tools---including WYSIWYG editors as
 > well as Web-based authoring aids---​must reorder the underlying
 > document source and not use
 > [order](https://drafts.csswg.org/css-display-4/#propdef-order) to perform reordering unless
 > the author has explicitly indicated that the underlying document
 > order (which determines speech and navigation order) should be
 > *out-of-sync* with the visual order.
 >
 > :::
 > (#example-a11y-tools) For example, a tool might offer
 > both drag-and-drop reordering of flex items as well as handling of
 > media queries for alternate layouts per screen size range.
 > Since most of the time, reordering should affect all screen ranges
 > as well as navigation and speech order, the tool would perform
 > drag-and-drop reordering at the DOM layer. In some cases, however,
 > the author may want different visual orderings per screen size. The
 > tool could offer this functionality by using
 > [order](https://drafts.csswg.org/css-display-4/#propdef-order) together with media queries,
 > but also tie the smallest screen size's ordering to the underlying
 > DOM order (since this is most likely to be a logical linear
 > presentation order) while using [order] to determine the visual presentation order in other size
 > ranges.
 >
 > This tool would be conformant, whereas a tool that only ever used
 > [order](https://drafts.csswg.org/css-display-4/#propdef-order) to handle drag-and-drop
 > reordering (however convenient it might be to implement it that way)
 > would be non-conformant.
 > :::

- [(#change-2015-align-self-auto) Defined that an
 [align-self](#propdef-align-self) or
 [justify-self](https://drafts.csswg.org/css-align-3/#propdef-justify-self) value of
 [auto](#valdef-align-items-auto) computes to itself on absolutely-positioned
 elements, for consistency with future extensions of these properties
 in
 [\[CSS-ALIGN-3\]](#biblio-css-align-3 "CSS Box Alignment Module Level 3").
 ([Issue
 5](https://drafts.csswg.org/css-flexbox-1/issues-lc-20150514#issue-5))]

 > [On absolutely positioned elements, a value of
 > [auto](#valdef-align-items-auto) computes to itself. On all other elements,
 > a] ~~A~~ value of
 > [auto](#valdef-align-items-auto) for
 > [align-self](#propdef-align-self) computes to the value of
 > [align-items](#propdef-align-items) on the element's parent, or
 > [stretch](#valdef-align-items-stretch) if the element has no parent.

- [(#change-2015-percentage-margins) Revert change to make
 percentage margins and padding relative to their own axes; instead
 allow both behaviors. ([Issue
 11](https://drafts.csswg.org/css-flexbox-1/issues-lc-20150514#issue-11),
 [Issue
 16](https://drafts.csswg.org/css-flexbox-1/issues-lc-20150514#issue-16))]

 > Percentage margins and paddings on [flex
 > items](#flex-item) are always
 > resolved against their respective dimensions; unlike blocks, they do
 > not always resolve against the inline dimension of their containing
 > block.
 >
 > Percentage margins and paddings on [flex
 > items](#flex-item) can be
 > resolved against either:
 >
 > - their own axis (left/right percentages resolve against width,
 > top/bottom resolve against height), or,
 > - the inline axis (left/right/top/bottom percentages all resolve
 > against width)
 >
 > A user agent must choose one of these two behaviors.
 >
 > Note: This variance sucks, but it accurately captures the current
 > state of the world (no consensus among implementations, and no
 > consensus within the CSSWG). It is the CSSWG's intention that
 > browsers will converge on one of the behaviors, at which time the
 > spec will be amended to require that.
 >
 > Authors should avoid using percentages in paddings or margins on
 > [flex items](#flex-item)
 > entirely, as they will get different behavior in different browsers.

- [(#change-2015-min-max-constraint) Handle min/max
 constraints in sizing flex items.]

 > - **Determine the available main and cross space for the flex
 > items.** For each dimension, if that dimension of the [flex
 > container](#flex-container)'s content box is a [definite
 > size](#definite), use that;
 > [if that dimension of the [flex
 > container](#flex-container) is being sized under a
 > [min](https://drafts.csswg.org/css-sizing-3/#min-content-constraint) or [max-content
 > constraint](https://drafts.csswg.org/css-sizing-3/#max-content-constraint), the available space in that dimension is that
 > constraint;] otherwise, subtract the [flex
 > container]'s margin, border, and
 > padding from the space available to the flex container in that
 > dimension and use that value.

- [(#changes-2015-first-fragment) Correct negation in flex
 container fragmentation rule: previous definition implied
 [break-inside:
 avoid](https://drafts.csswg.org/css-break-3/#propdef-break-inside) behavior in all cases. ([Issue
 5](https://drafts.csswg.org/css-flexbox-1/issues-lc-20150514#issue-5))]

 > - If the first fragment of the flex container is not at the top of
 > the page, and ~~some~~ [none] of its flex items
 > ~~don't~~ fit in the remaining space on the page, the entire
 > fragment is moved to the next page.

#### [ Clarifications]
- Miscellaneous minor editorial improvements and fixes to errors in
 examples.

### [ Changes since the 25 September 2014 LCWD]
A [Disposition of
Comments](https://drafts.csswg.org/css-flexbox-1/issues-lc-20140925) is
also available.

#### [ Substantive Changes and Bugfixes]
- [(#change-201409-content) Reverted [flex-basis:
 auto](#propdef-flex-basis) to its original meaning. Added [flex-basis:
 content] keyword to explicitly
 specify automatic content-based sizing. (Issue
 [10](https://drafts.csswg.org/css-flexbox-1/issues-lc-20140925#issue-10))]

- [(#change-201409-align-content-wrapping) Made
 applicability of
 [align-content](#propdef-align-content) depend on wrappability rather
 than number of resulting flex lines. (Issue
 [4](https://drafts.csswg.org/css-flexbox-1/issues-lc-20140925#issue-4))]

 > ~~When a flex container has multiple lines,~~ [In a
 > [multi-line](#multi-line-flex-container) [flex
 > container](#flex-container) (even one with only a single line),]
 > the [cross size](#cross-size)
 > of each line is the minimum size necessary \[\...\] ~~When a flex
 > container (even a
 > [multi-line](#multi-line-flex-container) one) has only one line,~~ [In a
 > [single-line](#single-line-flex-container) [flex
 > container](#flex-container),] the [cross
 > size] of the line is the [cross
 > size] of the flex container, and
 > [align-content](#propdef-align-content) has no effect.

 > Note, this property has no effect ~~when the flex container has only
 > a single line.~~ [on a
 > [single-line](#single-line-flex-container) [flex
 > container](#flex-container).]

 > Only ~~flex containers with multiple lines~~
 > [[multi-line](#multi-line-flex-container) [flex
 > containers](#flex-container)] ever have free space in the
 > [cross-axis](#cross-axis) for
 > lines to be aligned in, because in a ~~flex container with a single
 > line~~
 > [[single-line](#single-line-flex-container) flex container] the sole line
 > automatically stretches to fill the space.

 > If the flex container ~~has only one [flex
 > line](#flex-line) (even if
 > it's a
 > [multi-line](#multi-line-flex-container) [flex
 > container](#flex-container))~~ [is
 > [single-line](#single-line-flex-container)] and has a
 > [definite](#definite) [cross
 > size](#cross-size), the
 > [cross size] of the [flex
 > line](#flex-line) is the [flex
 > container](#flex-container)'s inner [cross size].

 > If the flex container ~~has only one flex line (even if it's a
 > multi-line flex container),~~ [is
 > [single-line](#single-line-flex-container),] then clamp the line's [cross
 > size](#cross-size) to be
 > within the container's computed min and max cross-size properties.

- [(#change-201409-algo-breaks) Removed text that asserted
 forced breaking behavior, replaced with reference to fragmentation
 section. This resolves a conflict in the spec. (Issue
 [18](https://drafts.csswg.org/css-flexbox-1/issues-lc-20140925#issue-18))]

 > collect consecutive items one by one until the first time that the
 > next collected item would not fit into the flex container's inner
 > main size, [(] or until a forced break is encountered [,
 > see [§ 10 Fragmenting Flex Layout](#pagination))] .
 > \[\...\] ~~A break is forced wherever the CSS2.1
 > [page-break-before](https://drafts.csswg.org/css2/#propdef-page-break-before)/[page-break-after](https://drafts.csswg.org/css2/#propdef-page-break-after)
 > [\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")
 > or the CSS3
 > [break-before](https://drafts.csswg.org/css-break-3/#propdef-break-before)/[break-after](https://drafts.csswg.org/css-break-3/#propdef-break-after)
 > [\[CSS3-BREAK\]](#biblio-css3-break "CSS Fragmentation Module Level 3")
 > properties specify a fragmentation break.~~

- [(#change-201409-inner-base-size) Change the [flex
 shrink
 factor](#flex-flex-shrink-factor) to multiply by the *inner* (not outer) [flex base
 size](#flex-base-size).
 (Issue
 [9](https://drafts.csswg.org/css-flexbox-1/issues-lc-20140925#issue-9))]

 > For every unfrozen item on the line, multiply its flex shrink factor
 > by its ~~outer~~ [inner] flex base size, and note this
 > as its [scaled flex shrink
 > factor](#scaled-flex-shrink-factor).

- [(#change-201409-neither) Add back in missing "n" in
 "neither"\... (Issue
 [6](https://drafts.csswg.org/css-flexbox-1/issues-lc-20140925#issue-6))]

 > If the [cross size
 > property](#cross-size-property) of the [flex
 > item](#flex-item) computes to
 > [auto](https://drafts.csswg.org/css-sizing-3/#valdef-width-auto), and [n] either of the
 > [cross-axis](#cross-axis)
 > margins are [auto], the [flex item] is
 > [stretched](#stretched).

- [(#change-201409-flexed-definite-container) Specify that
 the [flex container](#flex-container)'s [main size](#main-size) must also be
 [definite](#definite) for a flex
 item's flexed main size to be [definite]. (Issue
 [20](https://drafts.csswg.org/css-flexbox-1/issues-lc-20140925#issue-20))]

 > \[If\] \... the [flex item](#flex-item) has a [definite](#definite) [flex
 > basis](#flex-flex-basis), [and the [flex
 > container](#flex-container) has a [definite](#definite) [main size](#main-size),] the [flex
 > item's] [main
 > size](#main-size) must be
 > treated as [definite] \...

- [(#change-201409-min-auto-specified-size) Remove the
 requirement that the [flex
 basis](#flex-flex-basis)
 be
 [content](#valdef-flex-basis-content) for the [specified
 size](https://drafts.csswg.org/css-images-3/#specified-size) to be defined. The specified size should always win
 if it is smaller than the intrinsic size. This is particularly
 important to maintain author expectations for, e.g.
 `<img src="…" width=40 height=40 title="100x100 image">`. (Issue
 [25](https://drafts.csswg.org/css-flexbox-1/issues-lc-20140925#issue-25))]

 > If the item's ~~computed
 > [flex-basis](#propdef-flex-basis) is
 > [content](#valdef-flex-basis-content) and its~~ computed [main size
 > property](#main-size-property) is [definite](#definite), then the [specified
 > size](https://drafts.csswg.org/css-images-3/#specified-size) is that size

- [(#change-2014-blockify) Remove the requirement that
 anonymous block creation (for things like [display:
 table-cell](https://drafts.csswg.org/css-display-4/#propdef-display)) occur *before* [flex
 item](#flex-item)
 blockification. (Instead, all children now blockify immediately,
 consistent with abspos/float behavior.)]

#### [ Clarifications]
- [(#change-201409-unclamped-size) Clarify that [flex base
 size](#flex-base-size) is
 unclamped. (Issue
 [21](https://drafts.csswg.org/css-flexbox-1/issues-lc-20140925#issue-21))]

 > [When determining the [flex base
 > size](#flex-base-size),
 > the item's min and max main size properties are ignored (no clamping
 > occurs).]
 >
 > The [hypothetical main
 > size](#hypothetical-main-size) is the item's [flex base
 > size](#flex-base-size)
 > clamped according to its min and max main size properties.

- [(#change-201409-table-wrappers) Restored normative
 status of note about table wrapper boxes normative; it had been
 accidentally changed in the previous draft. (Issue
 [2](https://drafts.csswg.org/css-flexbox-1/issues-lc-20140925#issue-2))]

- [(#change-201409-display-longhands) Removed references
 to
 [display](https://drafts.csswg.org/css-display-4/#propdef-display) property longhands, since they
 will be removed from CSS Display Level
 3.]

- [(#change-201409-layout-vs-size) Change wording to not
 imply an unnecessary layout pass. (Issue
 [22](https://drafts.csswg.org/css-flexbox-1/issues-lc-20140925#issue-22))]

 > Otherwise, ~~lay out~~ [size] the item into the
 > [available
 > space](https://drafts.csswg.org/css-sizing-3/#available) using its used [flex
 > basis](#flex-flex-basis)
 > in place of its [main size](#main-size), treating a value of
 > [content](#valdef-flex-basis-content) as
 > [max-content](https://drafts.csswg.org/css-sizing-3/#valdef-width-max-content).

- [(#change-201409-clamped-specified) Renamed "clamped
 size" to "specified size" in the definition of [height:
 auto].]

- Various trivial fixes.

### [ Changes since the 25 March 2014 LCWD]
A [Disposition of
Comments](https://drafts.csswg.org/css-flexbox-1/issues-lc-20140325) is
also available.

#### [ Substantive Changes and Bugfixes]
The following significant changes were made since the [25 March 2014
Last Call Working
Draft](https://www.w3.org/TR/2014/WD-css-flexbox-1-20140325/)

- [(#change-201403-min-auto-not) Fixed errors (missing
 negation, unspecified axis) in definition of [min-width: auto].
 (Issues
 [11](https://drafts.csswg.org/css-flexbox-1/issues-lc-20140325#issue-11),
 [18](https://drafts.csswg.org/css-flexbox-1/issues-lc-20140325#issue-18),
 [30](https://drafts.csswg.org/css-flexbox-1/issues-lc-20140325#issue-30))]

 > On a [flex item](#flex-item)
 > whose
 > [overflow](https://drafts.csswg.org/css-overflow-3/#propdef-overflow) is ~~not~~
 > [visible](https://drafts.csswg.org/css-overflow-3/#valdef-overflow-visible) [in the [main
 > axis](#main-axis)]
 > ,

- [(#change-201403-min-auto-ratio) Expanded and rewrote
 definition of [min-width: auto] to add special handling of items
 with intrinsic ratios. (Issues
 [16](https://drafts.csswg.org/css-flexbox-1/issues-lc-20140325#issue-16)
 and
 [28](https://drafts.csswg.org/css-flexbox-1/issues-lc-20140325#issue-28))]

 > On a [flex item](#flex-item)
 > whose
 > [overflow](https://drafts.csswg.org/css-overflow-3/#propdef-overflow) is not
 > [visible](https://drafts.csswg.org/css-overflow-3/#valdef-overflow-visible), [the following table gives the minimum
 > size: [**\[see
 > table\]**](https://drafts.csswg.org/css-sizing-3/#valdef-width-auto)]\
 > ~~this keyword specifies as the minimum size the smaller of:~~
 >
 > - the [min-content
 > size](https://drafts.csswg.org/css-sizing-3/#min-content), or
 > - the computed
 > [width](https://drafts.csswg.org/css-sizing-3/#propdef-width)/[height](https://drafts.csswg.org/css-sizing-3/#propdef-height), if that value is
 > [definite](#definite).

- [(#change-201403-min-auto-main-size-basis) Adjusted
 [min-width: auto] to only apply the computed main size as a
 minimum in cases where the flex basis was retrieved from the main size
 property. (Issue
 [19](https://drafts.csswg.org/css-flexbox-1/issues-lc-20140325#issue-19))]

 > ... is defined if [the item's computed flex-basis is
 > [auto](#valdef-align-items-auto) and] its computed main size
 > property is definite ...

- [(#change-201403-min-auto-intrinsic-percentages) Defined
 that any size adjustment imposed by a box's [min-width: auto] is
 not consulted when percentage-sizing any of its contents. (Issue
 [27](https://drafts.csswg.org/css-flexbox-1/issues-lc-20140325#issue-27))
 This change was later reverted with an [opposite
 definition](#change-2015-min-auto-intrinsic-percentages).]

 > In order to prevent cycling sizing, the
 > [auto](#valdef-flex-basis-auto) value of
 > [min-height](https://drafts.csswg.org/css2/#propdef-min-height) and
 > [max-height](https://drafts.csswg.org/css2/#propdef-max-height) does not factor into the
 > percentage size resolution of the box's contents. For example, a
 > percentage-height block whose flex item parent has [height: 120em;
 > min-height:
 > auto](https://drafts.csswg.org/css-sizing-3/#propdef-height) will size itself against [height:
 > 120em] regardless of the impact that
 > [min-height] might have on
 > the used size of the flex item.

- [(#change-201403-flex-basis-auto) Introduced extra
 [main-size] keyword to
 [flex-basis](#propdef-flex-basis) so that "lookup from main-size
 property" and "automatic sizing" behaviors could each be explicitly
 specified. (Issue
 [20](https://drafts.csswg.org/css-flexbox-1/issues-lc-20140325#issue-20))
 This change was later reverted with an alternative proposal solving
 the same problem by instead introducing the
 [content](#valdef-flex-basis-content) keyword.]

- [(#change-201403-definite-flexing) Defined [flex
 items](#flex-item) with a
 [definite](#definite) [flex
 basis](#flex-flex-basis)
 to also be [definite] in the [main
 axis](#main-axis), allowing
 resolution of percentage-sized children even when the item itself is
 flexible. (Issue
 [26](https://drafts.csswg.org/css-flexbox-1/issues-lc-20140325#issue-26))]

 > If a percentage is going to be resolved against a flex item's main
 > size, and the flex item has a definite flex basis, the main size
 > must be treated as definite for the purpose of resolving the
 > percentage, and the percentage must resolve against the flexed main
 > size of the flex item (that is, after the layout algorithm below has
 > been completed for the flex item's flex container, and the flex item
 > has acquired its final size).

- [(#change-201403-clamp-single-line) Clamp a single line
 flexbox's line [cross size](#cross-size) to the container's own min/max, even when the
 container's size is indefinite. (Issue
 [9](https://drafts.csswg.org/css-flexbox-1/issues-lc-20140325#issue-9))]

 > - The used [cross size](#cross-size) of the [flex
 > line](#flex-line) is the
 > largest of the numbers found in the previous two steps and zero.
 >
 > [If the flex container has only one flex line (even if it's a
 > multi-line flex container), then clamp the line's [cross
 > size](#cross-size) to be
 > within the container's computed min and max cross-size properties.
 > [Note that if CSS 2.1's definition of min/max-width/height applied
 > more generally, this behavior would fall out
 > automatically.]]

- [(#change-201403-resolve-flex) Fixed various errors in
 the new [Resolving Flexible Lengths](#resolve-flexible-lengths)
 section (see [March 2014 rewrite to create continuity between [flex:
 0] and [flex: 1]](#change-2012-flex-continuity)) and
 reverted the editorial structure to match the old Candidate
 Recommendation. (Issues
 [3](https://drafts.csswg.org/css-flexbox-1/issues-lc-20140325#issue-3),
 [4](https://drafts.csswg.org/css-flexbox-1/issues-lc-20140325#issue-4),
 [8](https://drafts.csswg.org/css-flexbox-1/issues-lc-20140325#issue-8),
 [10](https://drafts.csswg.org/css-flexbox-1/issues-lc-20140325#issue-10),
 [15](https://drafts.csswg.org/css-flexbox-1/issues-lc-20140325#issue-15))]

- [(#change-201403-max-intrinsic) Fixed [max-content
 sizing of flex containers](#intrinsic-sizes) to account for flexing
 behavior by normalizing per flex fraction rather than merely summing
 the max-content sizes of the flex items. (Issue
 [39](https://drafts.csswg.org/css-flexbox-1/issues-lc-20140325#issue-39))]

- [(#change-201403-flex-animation) Updated
 [flex](#propdef-flex) property to accept animations always, now that
 the discontinuity between 0 and non-0 values has been
 [fixed](#change-2012-flex-continuity). (Issue
 [5](https://drafts.csswg.org/css-flexbox-1/issues-lc-20140325#issue-5))]

#### [ Clarifications]
The following significant changes were made since the [25 March 2014
Last Call Working
Draft](https://www.w3.org/TR/2014/WD-css-flexbox-1-20140325/)

- [(#change-201403-css21-staticpos) Clarified how the
 static position of an absolutely-positioned child of a flex container
 is calculated by introducing an explanation of the effect more closely
 tied with CSS2.1 concepts and terminology. (Issue
 [12](https://drafts.csswg.org/css-flexbox-1/issues-lc-20140325#issue-12))]

 > ~~Its~~ [The] static position [of an
 > absolutely-positioned child of a flex container] is
 > ~~calculated by first doing full flex layout without the
 > absolutely-positioned children, then positioning each
 > absolutely-positioned child~~ [determined such that the child is
 > positioned] as if it were the sole flex item in the flex
 > container, assuming both the child and the flex container were
 > fixed-size boxes of their used size.
 >
 > [In other words, the static position of an absolutely positioned
 > child of a flex container is determined *after flex layout* by
 > setting the child's [static-position
 > rectangle](https://drafts.csswg.org/css-position-3/#static-position-rectangle) to the flex container's content box, then aligning
 > the absolutely positioned child within this rectangle according to
 > the
 > [justify-content](#propdef-justify-content) value of the flex container and
 > the [align-self](#propdef-align-self) value of the child
 > itself.]

- [(#change-201403-abspos-ordering) Clarified application
 of
 [order](https://drafts.csswg.org/css-display-4/#propdef-order) to absolutely-positioned children
 of the [flex container](#flex-container). (Note, this behavior was later
 [rescinded](#change-2016-abspos-no-order).)]

 > An absolutely-positioned child of a flex container does not
 > participate in flex layout ~~beyond the reordering step~~ .
 > [However, it does participate in the reordering step (see
 > [order](https://drafts.csswg.org/css-display-4/#propdef-order)), which has an effect in their
 > painting order.]

 > The order property controls the order in which ~~flex items~~
 > [children of a flex container] appear within their flex
 > container...
 >
 > Unless otherwise specified by a future specification, this property
 > has no effect on boxes that are not ~~flex items~~ [children of a
 > flex container] .

 > Note: Absolutely-positioned children of a flex container do not
 > participate in flex layout, but are reordered together with any flex
 > item children.

- [(#change-201403-clarify-stretched) Clarified what a
 [stretched](#stretched) flex item
 is for the purposes of special behavior (like definiteness). (Issue
 [25](https://drafts.csswg.org/css-flexbox-1/issues-lc-20140325#issue-25))]

 > If the [cross size](#cross-size) property of the flex item computes to auto, [and
 > either of the cross-axis margins are auto, the flex item is
 > stretched. Its] ~~its~~ used value ...

### [ Changes since the 18 September 2012 Candidate Recommendation]
A [Disposition of
Comments](https://drafts.csswg.org/css-flexbox-1/issues-cr-2012) is also
available.

#### [ Substantive Changes and Bugfixes]
The following significant changes were made since the [18 September 2012
Candidate
Recommendation](https://www.w3.org/TR/2012/CR-css3-flexbox-20120918/):

- [(#change-2012-min-width) Changed the behavior of the
 new
 [auto](https://drafts.csswg.org/css-sizing-3/#valdef-width-auto) initial value of
 [min-width](https://drafts.csswg.org/css2/#propdef-min-width)/[min-height](https://drafts.csswg.org/css2/#propdef-min-height) to]

 - Take into account whether
 [overflow](https://drafts.csswg.org/css-overflow-3/#propdef-overflow) is
 [visible](https://drafts.csswg.org/css-overflow-3/#valdef-overflow-visible), since when
 [overflow] is explicitly
 handled, it is confusing (and unnecessary) to force enough size to
 show all the content.
 - Take into account the specified
 [width](https://drafts.csswg.org/css-sizing-3/#propdef-width)/[height](https://drafts.csswg.org/css-sizing-3/#propdef-height), so that the implied minimum is
 never greater than the specified size.
 - Compute to itself (not to
 [min-content](https://drafts.csswg.org/css-sizing-3/#valdef-width-min-content)) on flex items, since they are no longer
 equivalent (due to above changes).

 ([Issue
 19](https://drafts.csswg.org/css-flexbox-1/issues-cr-2012#issue-19))

 >
 >
 > auto
 >
 > : When used as the value of a flex item's min main size property,
 > this keyword indicates a minimum of the min-content size, to
 > help ensure that the item is large enough to fit its contents.
 >
 > It is intended that this will compute to the
 > [min-content](https://drafts.csswg.org/css-sizing-3/#valdef-width-min-content) keyword when the specification defining
 > it
 > ([\[CSS-SIZING-3\]](#biblio-css-sizing-3 "CSS Box Sizing Module Level 3"))
 > is sufficiently mature.
 >
 > On a [flex item](#flex-item) whose
 > [overflow](https://drafts.csswg.org/css-overflow-3/#propdef-overflow) is not
 > [visible](https://drafts.csswg.org/css-overflow-3/#valdef-overflow-visible), this keyword specifies as the minimum
 > size the smaller of:
 >
 > - the [min-content
 > size](https://drafts.csswg.org/css-sizing-3/#min-content), or
 > - the computed
 > [width](https://drafts.csswg.org/css-sizing-3/#propdef-width)/[height](https://drafts.csswg.org/css-sizing-3/#propdef-height), if that value is
 > [definite](#definite).

- [(#change-2012-percent-margins) Specified that
 percentage margins/paddings on flex items are resolved against their
 respective dimensions, not the inline dimension of the containing
 block like blocks do. ([Issue
 16](https://drafts.csswg.org/css-flexbox-1/issues-cr-2012#issue-16))]

 > Percentage margins and paddings on [flex
 > items](#flex-item) are always
 > resolved against their respective dimensions; unlike blocks, they do
 > not always resolve against the inline dimension of their containing
 > block.

- [(#change-2012-stretch-definite) Pass definiteness of a
 single-line flex container's size through to any stretched items.
 ([Issue
 3](https://drafts.csswg.org/css-flexbox-1/issues-cr-2012#issue-3))]

 > As a special case for handling stretched [flex
 > items](#flex-item), if a
 > [single-line](#single-line-flex-container) [flex
 > container](#flex-container) has a definite [cross
 > size](#cross-size), the outer
 > [cross size] of any [flex
 > items] with [align-self:
 > stretch](#propdef-align-self) is the flex container's inner [cross
 > size] (clamped to the [flex
 > item]'s min and max [cross
 > size]) and is considered
 > [definite](#definite).

- [(#change-2012-stretch-auto) Allow percentages inside a
 stretched auto-height flex item to resolve by requiring a relayout
 pass. ([Issue
 3](https://drafts.csswg.org/css-flexbox-1/issues-cr-2012#issue-3))]

 > If the flex item has [align-self:
 > stretch](#propdef-align-self), redo layout for its contents, treating this
 > used size as its definite [cross
 > size](#cross-size) so that
 > percentage-sized children can be resolved.
 >
 > Note that this step does not affect the main size of the flex item,
 > even if it has an intrinsic aspect ratio.

- [(#change-2012-intrinsic-ratio) Allow intrinsic aspect
 ratios to inform the [main-size calculation.](#algo-main-item) ([Issue
 8](https://drafts.csswg.org/css-flexbox-1/issues-cr-2012#issue-8))]

 > If the flex item has \...
 >
 > - an intrinsic aspect ratio,
 > - a [flex basis](#flex-flex-basis) of
 > [auto](https://drafts.csswg.org/css-sizing-3/#valdef-width-auto), and
 > - a definite [cross size](#cross-size)
 >
 > then the [flex base size](#flex-base-size) is calculated from its inner [cross
 > size](#cross-size) and the
 > [flex item](#flex-item)'s
 > intrinsic aspect ratio.

- [(#change-2012-main-depend-cross) Define [hypothetical
 main size](#hypothetical-main-size) when the [main size](#main-size) depends on the [cross
 size](#cross-size). ([Issue
 23](https://drafts.csswg.org/css-flexbox-1/issues-cr-2012#issue-23))]

 > [If a [cross size](#cross-size) is needed to determine the [main
 > size](#main-size) (e.g. when
 > the [flex item](#flex-item)'s
 > [main size] is in its block axis) and the
 > [flex item]'s [cross
 > size] is
 > [auto](#valdef-flex-basis-auto) and not
 > [definite](#definite), in this
 > calculation use
 > [fit-content](https://drafts.csswg.org/css-sizing-3/#valdef-width-fit-content) as the [flex item]'s
 > [cross size].]

- [(#change-2012-intrinsic-sizes) Defined the [intrinsic
 sizes of flex
 containers.](#intrinsic-sizes)]

 > **Determine the main size of the flex container** using its main
 > size property. ~~In this calculation, the min content main size of
 > the flex container is the maximum of the flex container's items\'
 > min-content size contributions, and the max content main size of the
 > flex container is the sum of the flex container's items\'
 > max-content size contributions. The min-content/max-content main
 > size contribution of an item is its outer hypothetical main size
 > when sized under a min-content/max-content constraint
 > (respectively).~~ For this computation, 'auto' margins on flex items
 > are treated as '0'.

 > The
 > [max-content](https://drafts.csswg.org/css-sizing-3/#max-content) [main size](#main-size) of a [flex
 > container](#flex-container) is the sum of the flex container's items\'
 > [max-content
 > contributions](https://drafts.csswg.org/css-sizing-3/#max-content-contribution) in the [main axis](#main-axis). The
 > [min-content](https://drafts.csswg.org/css-sizing-3/#min-content) [main size] of a
 > [single-line](#single-line-flex-container) flex container is the sum of the flex container's
 > items\' [min-content
 > contributions](https://drafts.csswg.org/css-sizing-3/#min-content-contribution) in the [main axis]; for a
 > [multi-line](#multi-line-flex-container) container, it is the largest of those
 > contributions.
 >
 > The
 > [min-content](https://drafts.csswg.org/css-sizing-3/#min-content) [cross size](#cross-size) and
 > [max-content](https://drafts.csswg.org/css-sizing-3/#max-content) [cross size] of a flex
 > container are the [cross size] of the flex
 > container after performing layout into the given available
 > [main-axis](#main-axis) space
 > and infinite available
 > [cross-axis](#cross-axis)
 > space.
 >
 > The main-size
 > [min-content](https://drafts.csswg.org/css-sizing-3/#min-content-contribution)/[max-content
 > contribution](https://drafts.csswg.org/css-sizing-3/#max-content-contribution) of a [flex item](#flex-item) is its outer [hypothetical main
 > size](#hypothetical-main-size) when sized under a
 > [min-content](https://drafts.csswg.org/css-sizing-3/#min-content-constraint)/[max-content
 > constraint](https://drafts.csswg.org/css-sizing-3/#max-content-constraint) (respectively).
 >
 > See
 > [\[CSS-SIZING-3\]](#biblio-css-sizing-3 "CSS Box Sizing Module Level 3")
 > for a definition of the terms in this section.

- [(#change-2012-flex-line-bug) Correct an omission in the
 flex-line size determination, so a
 [single-line](#single-line-flex-container) flexbox will size to its contents if it doesn't have
 a definite size.]

 > If the flex container has only one [flex
 > line](#flex-line) (even if
 > it's a
 > [multi-line](#multi-line-flex-container) [flex
 > container](#flex-container)) [and has a
 > [definite](#definite) [cross
 > size](#cross-size)] , the [cross
 > size](#cross-size) of the
 > [flex line] is the [flex
 > container]'s inner [cross
 > size].

- [(#change-2012-flex-line-floor) Flex lines have their
 size floored at 0. ([Issue
 2](https://drafts.csswg.org/css-flexbox-1/issues-cr-2012#issue-2))]

 > The used [cross size](#cross-size) of the [flex line](#flex-line) is the ~~larger~~ [largest] of the
 > numbers found in the previous two steps [and zero] .

- [(#change-2012-atomic-painting) Flex items paint like
 inline blocks rather than blocks. ([Issue
 18](https://drafts.csswg.org/css-flexbox-1/issues-cr-2012#issue-18))]

 > [Flex items](#flex-item)
 > paint exactly the same as ~~block-level elements in the normal
 > flow~~ [inline blocks
 > [\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")]
 > .

- [(#change-2012-flex-basis-zero) An omitted
 [flex-basis](#propdef-flex-basis) component of the
 [flex](#propdef-flex) shorthand now resolves to [0%] instead of
 [0px]. Because percentages resolved against indefinite sizes
 behave as
 [auto](#valdef-align-items-auto), this gives better behavior in shrink-wrapped
 flex containers. ([Issue
 20](https://drafts.csswg.org/css-flexbox-1/issues-cr-2012#issue-20))]

 > When omitted from the [flex](#propdef-flex) shorthand, its specified value
 > is [[0%]] ~~the length zero~~ .

 >
 >
 > [flex: \<positive-number\>](#propdef-flex)
 > : Equivalent to [flex: \<positive-number\> 1
 > ~~0px~~[0%]](#propdef-flex).

 Note: This change was [reverted](#change-2015-flex-basis-zero).

- [(#change-2012-unresolvable-basis) Defined that an
 unresolvable percentage [flex base
 size](#flex-base-size) is
 treated as
 [auto](https://drafts.csswg.org/css-sizing-3/#valdef-width-auto).]

 > percentage values of
 > [flex-basis](#propdef-flex-basis) are resolved against the flex item's
 > containing block, i.e. its flex container, and if that containing
 > block's size is [indefinite](#definite), the result is ~~undefined~~ [the same as a [main
 > size](#main-size) of
 > [auto](https://drafts.csswg.org/css-sizing-3/#valdef-width-auto)] .

- [(#change-2012-static-pos) Simplified the static
 position of abspos children of [flex
 containers](#flex-container) to be consistent with Grid Layout. ([Issue
 6](https://drafts.csswg.org/css-flexbox-1/issues-cr-2012#issue-6))]

 > An absolutely-positioned child of a [flex
 > container](#flex-container) does not participate in flex layout beyond the
 > reordering step.
 >
 > However, if both
 > [left](https://drafts.csswg.org/css-position-3/#propdef-left) and
 > [right](https://drafts.csswg.org/css-position-3/#propdef-right) or both
 > [top](https://drafts.csswg.org/css-position-3/#propdef-top) and
 > [bottom](https://drafts.csswg.org/css-position-3/#propdef-bottom) are
 > [auto](#valdef-align-items-auto), then the used value of those properties are
 > computed from its static position, as follows:
 >
 > If both
 > [left](https://drafts.csswg.org/css-position-3/#propdef-left) and
 > [right](https://drafts.csswg.org/css-position-3/#propdef-right) are
 > [auto](#valdef-align-items-auto), the [flex
 > item](#flex-item) must be
 > positioned so that its
 > [main-start](#main-start) or
 > [cross-start](#cross-start)
 > edge (whichever is in the horizontal axis) is aligned with the
 > [static
 > position](https://drafts.csswg.org/css-position-3/#static-position). If both
 > [top](https://drafts.csswg.org/css-position-3/#propdef-top) and
 > [bottom](https://drafts.csswg.org/css-position-3/#propdef-bottom) are
 > [auto], the [flex
 > item] must be positioned so that its
 > [main-start] or
 > [cross-start] edge (whichever is in the
 > vertical axis) is aligned with the [static
 > position].
 >
 > In the [main axis](#main-axis),
 >
 > 1. If there is a subsequent in-flow [flex
 > item](#flex-item) on the
 > same [flex line](#flex-line), the [static
 > position](https://drafts.csswg.org/css-position-3/#static-position) is the outer
 > [main-start](#main-start)
 > edge of that [flex item].
 > 2. Otherwise, if there is a preceding in-flow [flex
 > item](#flex-item) on the
 > same [flex line](#flex-line), the [static
 > position](https://drafts.csswg.org/css-position-3/#static-position) is the outer
 > [main-end](#main-end) edge
 > of that [flex item].
 > 3. Otherwise, the [static
 > position](https://drafts.csswg.org/css-position-3/#static-position) is determined by the value of
 > [justify-content](#propdef-justify-content) on the [flex
 > container](#flex-container) as if the [static
 > position] were represented by a
 > zero-sized flex item.
 >
 > In the [cross axis](#cross-axis),
 >
 > 1. If there is a preceding in-flow [flex
 > item](#flex-item), the
 > [static
 > position](https://drafts.csswg.org/css-position-3/#static-position) is the
 > [cross-start](#cross-start) edge of the [flex
 > line](#flex-line) that
 > item is in.
 > 2. Otherwise, the [static
 > position](https://drafts.csswg.org/css-position-3/#static-position) is the
 > [cross-start](#cross-start) edge of the first [flex
 > line](#flex-line).
 >
 > The static position is intended to more-or-less match the position
 > of an anonymous 0×0 in-flow
 > [flex-start](#valdef-align-items-flex-start)-aligned flex item that participates in flex
 > layout, the primary difference being that any packing spaces due to
 > [justify-content:
 > space-around](#propdef-justify-content) or [justify-content:
 > space-between] are
 > suppressed around the hypothetical item: between it and the next
 > item if there is a real item after it, else between it and the
 > previous item (if any) if there isn't.
 >
 > Its static position is calculated by first doing full flex layout
 > without the absolutely-positioned children, then positioning each
 > absolutely-positioned child as if it were the sole [flex
 > item](#flex-item) in the
 > [flex container](#flex-container), assuming both the child and the [flex
 > container] were fixed size boxes of
 > their used size.
 >
 > :::
 > (#example-0e6abe14) For example, by default, the
 > static position of an absolutely positioned child aligns it to the
 > main-start/cross-start corner, corresponding to the default values
 > of
 > [justify-content](#propdef-justify-content) and
 > [align-content](#propdef-align-content) on the [flex
 > container](#flex-container). Setting [justify-content:center] on the
 > [flex container], however, would center
 > it in the main axis.
 > :::

- [(#change-2012-flex-continuity) Changed algorithm for
 [resolving flexible lengths](#resolve-flexible-lengths) to make
 behavior continuous as the sum of the flex factors approaches zero.
 (No change for a sum ≥ 1.) ([Issue
 30](https://drafts.csswg.org/css-flexbox-1/issues-cr-2012#issue-30))
 Replaces [this
 section](https://www.w3.org/TR/2012/CR-css3-flexbox-20120918/#resolve-flexible-lengths)
 with [this
 one](#resolve-flexible-lengths).]

#### [ Clarifications]
The following significant clarifications were also made:

- [(#clarify-2012-abspos-items) Absolutely positioned
 children of a flex container are no longer called \"flex items\" (to
 avoid terminology confusion). (??)]

 > Name:
 > order
 > Applies to:
 > [flex items](#flex-item) [and
 > absolutely-positioned children of [flex
 > containers](#flex-container)]

 > Re-order the flex items [and absolutely positioned flex container
 > children] according to their
 > [order](https://drafts.csswg.org/css-display-4/#propdef-order).

- [(#clarify-2012-float-display) Clarified that
 [float](https://drafts.csswg.org/css2/#propdef-float) still affects the computed
 [display](https://drafts.csswg.org/css-display-4/#propdef-display) (which may affect box-fixup rules
 that run prior to flex item determination). ([Issue
 7](https://drafts.csswg.org/css-flexbox-1/issues-cr-2012#issue-7))]

 > [float](https://drafts.csswg.org/css2/#propdef-float) and
 > [clear](https://drafts.csswg.org/css2/#propdef-clear) have no effect on a [flex
 > item](#flex-item) [, and do
 > not take it out-of-flow. However, the
 > [float](https://drafts.csswg.org/css2/#propdef-float) property can still affect box
 > generation by influencing the
 > [display](https://drafts.csswg.org/css-display-4/#propdef-display) property's computed
 > value.]

- [(#clarify-2012-white-space) Clarify what is meant by
 "white space". ([Issue
 26](https://drafts.csswg.org/css-flexbox-1/issues-cr-2012#issue-26))]

 > However, an anonymous flex item that contains only [white
 > space](https://www.w3.org/TR/CSS2/text.html#white-space-prop) [(i.e.
 > characters that can be affected by the
 > [white-space](https://drafts.csswg.org/css-text-4/#propdef-white-space) property)] is not
 > rendered, as if it were [display:none].

- [(#clarify-2012-table-anon-boxes) Clarified that table
 anonymous box generation occurs in place of computed value conversion
 for internal table elements.]

- [(#clarify-2012-display-blockification) Clarified
 interaction of flex item determination with [display-inside] /
 [display-outside] (the new longhands of
 [display](https://drafts.csswg.org/css-display-4/#propdef-display) defined in the [CSS Display
 Module Level
 3](https://www.w3.org/TR/css-display/)).]

 > If the specified [display-outside] of an in-flow child of an
 > element that generates a [flex
 > container](#flex-container) is [inline-level], it computes to
 > [block-level]. (This effectively converts any inline
 > [display](https://drafts.csswg.org/css-display-4/#propdef-display) values to their block
 > equivalents.)

 Note: This change was [reverted](#change-201409-display-longhands).

- [(#clarify-2012-overflow-flex-containers) Clarified that
 [overflow](https://drafts.csswg.org/css-overflow-3/#propdef-overflow) applies to flex
 containers.]

- [(#clarify-2012-first-line-letter) Clarified that
 [::first-line](https://drafts.csswg.org/css-pseudo-4/#selectordef-first-line) and
 [::first-letter](https://drafts.csswg.org/css-pseudo-4/#selectordef-first-letter) pseudo-elements do not apply to flex
 containers (because they are not block
 containers).]

- [(#clarify-2012-stretch-computed-auto) Clarify that
 [stretch](#valdef-align-items-stretch) checks for the *computed* value of the
 cross-size property being
 [auto](https://drafts.csswg.org/css-sizing-3/#valdef-width-auto), which means that percentage [cross
 sizes](#cross-size) that behave
 as [auto] (because they don't resolve
 against definite sizes) aren't stretched. ([Issue
 5](https://drafts.csswg.org/css-flexbox-1/issues-cr-2012#issue-5))]

 >
 >
 > stretch
 >
 > : If the [cross size
 > property](#cross-size-property) of the [flex
 > item](#flex-item) ~~is~~
 > [computes to]
 > [auto](https://drafts.csswg.org/css-sizing-3/#valdef-width-auto), its used value is ...

 > **Determine the used cross size of each flex item.** If a flex item
 > has [align-self:
 > stretch](#propdef-align-self), its [computed] cross size
 > property is
 > [auto](https://drafts.csswg.org/css-sizing-3/#valdef-width-auto), and ...

- [(#clarify-2012-flex-container-sizing) Clarify that the
 rules of the formatting context are used for determining the flex
 container's main size.]

 > **Determine the main size of the flex container** using [the rules
 > of the formatting context in which it participates]
 > ~~its main size property~~ .

- [(#clarify-2012-painting-order) Clarified that
 [order](https://drafts.csswg.org/css-display-4/#propdef-order)-modified document order is used
 instead of raw document order when painting. (This was already stated
 in the [order] section, but not in
 the section explicitly about painting
 order.)]

- [(#clarify-2012-line-breaking) Clarified line-breaking
 to precisely handle negatively-sized flex items and zero-size items at
 the end of a line. ([Issue
 1](https://drafts.csswg.org/css-flexbox-1/issues-cr-2012#issue-1))]

 > Otherwise, starting from the first uncollected item, collect
 > [consecutive items one by one until the first time that the *next*
 > collected item would not fit into the flex container's inner main
 > size, or until a forced break is encountered. If the very first
 > uncollected item wouldn't fit, collect just it into the
 > line] ~~as many consecutive flex items as will fit or
 > until a forced break is encountered (but collect at least one) into
 > the flex container's inner main size into a flex line~~ .

 > Note that ~~items with zero main size will never start a line unless
 > they're the very first items in the flex container, or they're
 > preceded by a forced break.~~ The \"collect as many\" line will
 > collect ~~them~~ [zero-sized flex items] onto the end of
 > the previous line even if the last non-zero item exactly \"filled
 > up\" the line.

- [(#clarify-2012-clamping) Clarified that flex container
 cross sizes are still clamped by the flex container's min/max
 properties. ([Issue
 24](https://drafts.csswg.org/css-flexbox-1/issues-cr-2012#issue-24))]

 > - If the cross size property is a
 > [definite](#definite) size,
 > use that, [clamped by the min and max cross size properties of the
 > [flex container](#flex-container)] .
 > - Otherwise, use the sum of the flex lines\' cross sizes, [clamped
 > by the min and max cross size properties of the [flex
 > container](#flex-container)] .

## [Privacy Considerations]
No new privacy considerations have been reported on this specification.

## [Security Considerations]
No new security considerations have been reported on this specification.
