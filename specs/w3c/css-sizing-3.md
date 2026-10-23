## 1. Introduction

*This section is not normative.*

CSS layout has several different concepts of automatic sizing that are
used in various layout calculations. This section defines some more
precise terminology to help connect the layout behaviors of this spec to
the calculations used in other modules, and some new keywords for the
[width](#propdef-width) and
[height](#propdef-height) properties to allow authors to assign elements the
dimensions resulting from these size calculations.

Tests

General sizing tests

- [dynamic-available-size-iframe.html](https://wpt.fyi/results/css/css-sizing/dynamic-available-size-iframe.html "css/css-sizing/dynamic-available-size-iframe.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/dynamic-available-size-iframe.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/dynamic-available-size-iframe.html)
- [dynamic-change-inline-size-001.html](https://wpt.fyi/results/css/css-sizing/dynamic-change-inline-size-001.html "css/css-sizing/dynamic-change-inline-size-001.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/dynamic-change-inline-size-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/dynamic-change-inline-size-001.html)
- [dynamic-change-inline-size-002.html](https://wpt.fyi/results/css/css-sizing/dynamic-change-inline-size-002.html "css/css-sizing/dynamic-change-inline-size-002.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/dynamic-change-inline-size-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/dynamic-change-inline-size-002.html)
- [dynamic-change-inline-size-003.html](https://wpt.fyi/results/css/css-sizing/dynamic-change-inline-size-003.html "css/css-sizing/dynamic-change-inline-size-003.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/dynamic-change-inline-size-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/dynamic-change-inline-size-003.html)
- [dynamic-change-inline-size-004.html](https://wpt.fyi/results/css/css-sizing/dynamic-change-inline-size-004.html "css/css-sizing/dynamic-change-inline-size-004.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/dynamic-change-inline-size-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/dynamic-change-inline-size-004.html)
- [frameset-intrinsic-crash.html](https://wpt.fyi/results/css/css-sizing/frameset-intrinsic-crash.html "css/css-sizing/frameset-intrinsic-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/frameset-intrinsic-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/frameset-intrinsic-crash.html)
- [inheritance-001.html](https://wpt.fyi/results/css/css-sizing/inheritance-001.html "css/css-sizing/inheritance-001.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/inheritance-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/inheritance-001.html)
- [inheritance-002.html](https://wpt.fyi/results/css/css-sizing/inheritance-002.html "css/css-sizing/inheritance-002.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/inheritance-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/inheritance-002.html)
- [min-width-max-width-precedence.html](https://wpt.fyi/results/css/css-sizing/min-width-max-width-precedence.html "css/css-sizing/min-width-max-width-precedence.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/min-width-max-width-precedence.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/min-width-max-width-precedence.html)
- [min-width-max-width-precedence.html](https://wpt.fyi/results/css/css-sizing/min-width-max-width-precedence.html "css/css-sizing/min-width-max-width-precedence.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/min-width-max-width-precedence.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/min-width-max-width-precedence.html)
- [replaced-max-size-saturation.html](https://wpt.fyi/results/css/css-sizing/replaced-max-size-saturation.html "css/css-sizing/replaced-max-size-saturation.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/replaced-max-size-saturation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/replaced-max-size-saturation.html)
- [responsive-iframe-no-match-element.html](https://wpt.fyi/results/css/css-sizing/responsive-iframe/responsive-iframe-no-match-element.html "css/css-sizing/responsive-iframe/responsive-iframe-no-match-element.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/responsive-iframe/responsive-iframe-no-match-element.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/responsive-iframe/responsive-iframe-no-match-element.html)
- [textarea-large-padding-crash.html](https://wpt.fyi/results/css/css-sizing/textarea-large-padding-crash.html "css/css-sizing/textarea-large-padding-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/textarea-large-padding-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/textarea-large-padding-crash.html)

------------------------------------------------------------------------

This spec needs illustrations! See
[issue](https://github.com/w3c/csswg-drafts/issues/1938).

### 1.1. Module interactions

This module extends the [width](#propdef-width),
[height](#propdef-height),
[min-width](#propdef-min-width),
[min-height](#propdef-min-height),
[max-width](#propdef-max-width),
[max-height](#propdef-max-height), and
[column-width](https://drafts.csswg.org/css-multicol-2/#propdef-column-width) features defined in
[\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")
chapter 10 and in
[\[CSS3COL\]](#biblio-css3col "CSS Multi-column Layout Module Level 1")

The definition of the
[box-sizing](#propdef-box-sizing) property in this module supersedes the
one in
[\[CSS-UI-3\]](#biblio-css-ui-3 "CSS Basic User Interface Module Level 3 (CSS3 UI)").

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

## 2. Terminology

Some key terminology related to coordinate axises and dimensions is
defined in [CSS Writing Modes 3 § 6 Abstract Box
Terminology](https://drafts.csswg.org/css-writing-modes-3/#abstract-box).

[size]
: A one- or two-dimensional measurement: a [block
 size](#block-size) and/or
 [inline size](#inline-size);
 alternatively a [width](#width)
 and/or [height](#height).
 <figure>
 <img src="images/sizing-ltr-tb.svg" style="max-width: 49%;" width="420"
 height="240"
 a /><img
 src="images/sizing-ttb-rl.svg" style="max-width: 49%;" width="420"
 height="240"
 a />
 <figcaption>Whether the <a href="#width" id="ref-for-width①"
 data->width</a> or <a href="#height" id="ref-for-height①"
 data->height</a> corresponds to an <a href="#inline-size"
 id="ref-for-inline-size①" data->inline size</a> or <a
 href="#block-size" id="ref-for-block-size①" data->block
 size</a> depends on the <a
 href="https://drafts.csswg.org/css-writing-modes-4/#writing-mode"
 id="ref-for-writing-mode" data->writing
 mode</a>.</figcaption>
 </figure>

[inner size]
: The
 [content-box](https://www.w3.org/TR/css2/box.html#box-dimensions)
 [size](#size) of a
 [box](https://drafts.csswg.org/css-display-3/#box).
 ![Inner size](images/inner-size.svg){height="270" width="420"}

[outer size]
: The [margin-box](https://www.w3.org/TR/css2/box.html#box-dimensions)
 [size](#size) of a
 [box](https://drafts.csswg.org/css-display-3/#box).
 ![Outer size](images/outer-size.svg){height="270" width="420"}

[definite size]

: A size that can be determined without performing layout; that is, a
 [\<length\>](https://drafts.csswg.org/css-values-4/#length-value), a measure of text (without
 consideration of line-wrapping), a size of the [initial containing
 block](https://drafts.csswg.org/css-display-4/#initial-containing-block), or a
 [\<percentage\>](https://drafts.csswg.org/css-values-4/#percentage-value) or other formula (such the
 ["stretch-fit" sizing of non-replaced
 blocks](https://www.w3.org/TR/CSS2/visudet.html#blockwidth)
 [\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification"))
 that is resolved solely against
 [definite](#definite) sizes.

 Additionally, the size of the [containing
 block](https://drafts.csswg.org/css-display-4/#containing-block) of an absolutely positioned element is always
 [definite](#definite) with
 respect to that element.

[indefinite size]

: A size that is not [definite](#definite). [Indefinite](#indefinite) [available space](#available) is essentially infinite.

 [intrinsic
 sizing](#intrinsic-sizing) keywords such as
 [max-content](#valdef-width-max-content) are indefinite, even if they can be
 determined without laying out the children e.g. due to [size
 containment](https://drafts.csswg.org/css-contain-2/#size-containment) or lack of children.

[available space]
: A size representing the space into which a box is laid out, as
 determined by the rules of the formatting context in which it
 participates. The space available to a box is usually either a
 measurement of its [containing
 block](https://drafts.csswg.org/css-display-4/#containing-block) (if that is
 [definite](#definite)) or an
 infinite size (when it is
 [indefinite](#indefinite)).
 [Available space](#available)
 can alternatively be either a [min-content
 constraint](#min-content-constraint) or a [max-content
 constraint](#max-content-constraint), which forces boxes laid into it to be laid out
 under that constraint.
 Tests
 - [available-height-for-replaced-content-001.html](https://wpt.fyi/results/css/css-sizing/available-height-for-replaced-content-001.html "css/css-sizing/available-height-for-replaced-content-001.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/available-height-for-replaced-content-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/available-height-for-replaced-content-001.html)
 - [table-percentage-max-width-beside-float.html](https://wpt.fyi/results/css/css-sizing/table-percentage-max-width-beside-float.html "css/css-sizing/table-percentage-max-width-beside-float.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/table-percentage-max-width-beside-float.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/table-percentage-max-width-beside-float.html)
 - [table-percentage-min-width-below-float.html](https://wpt.fyi/results/css/css-sizing/table-percentage-min-width-below-float.html "css/css-sizing/table-percentage-min-width-below-float.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/table-percentage-min-width-below-float.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/table-percentage-min-width-below-float.html)
 - [table-percentage-min-width-beside-float.html](https://wpt.fyi/results/css/css-sizing/table-percentage-min-width-beside-float.html "css/css-sizing/table-percentage-min-width-beside-float.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/table-percentage-min-width-beside-float.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/table-percentage-min-width-beside-float.html)

[stretch fit]

: The [stretch fit](#stretch-fit) into a given size is that size, minus the box's
 computed margins (not collapsed, treating [auto] as zero),
 border, and padding in the given dimension (such that the outer size
 is a perfect fit), and flooring at zero (so that the inner size is
 not negative).

 Note: This is the formula used to calculate the
 [auto](#valdef-width-auto) widths of non-replaced blocks in normal flow in
 [CSS2.1§10.3.3](https://www.w3.org/TR/CSS2/visudet.html#blockwidth).

[fallback size]
: Some sizing algorithms do not work well with an infinite size. In
 these cases, the [fallback size](#fallback) is used instead. Unless otherwise specified, this
 is the size of the [initial containing
 block](https://drafts.csswg.org/css-display-4/#initial-containing-block).

### 2.1. Auto Box Sizes

There are four types of automatically-determined sizes in CSS (sizes
resulting from [auto](#valdef-width-auto) sizing rules, depending on context):

[stretch-fit size]\
[stretch-fit inline size]\
[stretch-fit block size]

: The [size](#size) a box would take
 if its [outer size](#outer-size) filled the [available
 space](#available) in the given
 axis; in other words, the [stretch
 fit](#stretch-fit) into the
 [available space], if that is
 [definite](#definite). Undefined
 if the [available space] is
 [indefinite](#indefinite).

 For the [inline
 axis](https://drafts.csswg.org/css-writing-modes-4/#inline-axis), this is called the "available width" in
 [CSS2.1§10.3.5](https://www.w3.org/TR/CSS2/visudet.html#float-width)
 and computed by the rules in
 [CSS2.1§10.3.3](https://www.w3.org/TR/CSS2/visudet.html#blockwidth).

 Calculations involving this size need to specify a
 fallback behavior for when the [available
 space](#available) is
 [indefinite](#indefinite) if
 that happens to be possible.

[max-content size]

: A box's "ideal" [size](#size) in a
 given axis when given infinite available space. Usually this is the
 smallest [size] the box could take in that axis
 while still fitting around its contents, i.e. minimizing unfilled
 space while avoiding overflow.

 [max-content inline size]

 : The box's "ideal" [size](#size)
 in the [inline
 axis](https://drafts.csswg.org/css-writing-modes-4/#inline-axis). Usually the narrowest [inline
 size](#inline-size) it
 could take while fitting around its contents if *none* of the
 soft wrap opportunities within the box were taken. (See [§ 5
 Intrinsic Size Determination](#intrinsic).)

 This is called the "preferred width" in
 [CSS2.1§10.3.5](https://www.w3.org/TR/CSS2/visudet.html#float-width)
 and the "maximum cell width" in
 [CSS2.1§17.5.2.2](https://www.w3.org/TR/CSS2/tables.html#auto-table-layout).

 [max-content block size]

 : The box's "ideal" [size](#size)
 in the [block
 axis](https://drafts.csswg.org/css-writing-modes-4/#block-axis). Usually the [block
 size](#block-size) of the
 content after layout.

 If the ideal [max-content size](#max-content) would be smaller than the [min-content
 size](#min-content) (e.g. due
 to the use of negative margins) the effective [max-content
 size] is floored by the [min-content
 size].

[min-content size]
: Nominally, the smallest [size](#size) a box could take that doesn't lead to overflow that
 could be avoided by choosing a larger [size].
 Formally, the size of the box when sized under a [min-content
 constraint](#min-content-constraint), see [§ 5 Intrinsic Size
 Determination](#intrinsic).

 [min-content inline size]

 : The [min-content size](#min-content) in the [inline
 axis](https://drafts.csswg.org/css-writing-modes-4/#inline-axis). Typically, the [inline
 size](#inline-size) that
 would fit around its contents if *all* soft wrap opportunities
 within the box were taken.

 This is called the "preferred minimum width" in
 [CSS2.1§10.3.5](https://www.w3.org/TR/CSS2/visudet.html#float-width)
 and the "minimum content width" in
 [CSS2.1§17.5.2.2](https://www.w3.org/TR/CSS2/tables.html#auto-table-layout).

 [min-content block size]

 : The [min-content size](#min-content) in the [block
 axis](https://drafts.csswg.org/css-writing-modes-4/#block-axis). For [block
 containers](https://drafts.csswg.org/css-display-4/#block-container), tables, and [inline
 boxes](https://drafts.csswg.org/css-display-4/#inline-box), this is equivalent to the [max-content block
 size](#max-content-block-size).

[fit-content size]\
[fit-content inline size]\
[fit-content block size]

: If the [available space](#available) in a given axis is
 [definite](#definite), equal to
 `clamp(`[`min-content size`](#min-content)`, `[`stretch-fit size`](#stretch-fit-size)`, `[`max-content size`](#max-content)`)` (i.e.
 `max(`[`min-content size`](#min-content)`, min(`[`max-content size`](#max-content)`, `[`stretch-fit size`](#stretch-fit-size)`))`). When sizing under a [min-content
 constraint](#min-content-constraint), equal to the [min-content
 size](#min-content).
 Otherwise, equal to the [max-content
 size](#max-content) in that
 axis.

 This is called the "shrink-to-fit" width in
 [CSS2.1§10.3.5](https://www.w3.org/TR/CSS2/visudet.html#float-width)
 and [CSS Multi-column Layout §
 3.4](https://www.w3.org/TR/css3-multicol/#pseudo-algorithm).

[intrinsic size]

: A [max-content size](#max-content) or [min-content
 size](#min-content), i.e. a
 size arising primarily from the size of the content. (Some uses of
 this term may refer also to sizes derived primarily from one of
 these two sizes.)

 [Replaced
 elements](https://drafts.csswg.org/css-display-4/#replaced-element) frequently derive their [intrinsic
 size](#intrinsic-size) from
 their [natural
 dimensions](https://drafts.csswg.org/css-images-3/#natural-dimensions).

The following example applies
[fit-content sizing](#fit-content-size) to the width of the inner `<div>`, and places it within
[containing
blocks](https://drafts.csswg.org/css-display-4/#containing-block) of varying sizes:

- In the narrowest containing block ([2ch]), the box takes its
 [min-content size](#min-content)---​overflowing its containing block in order to fully
 contain all its content, which has wrapped as narrowly as possible.

- In the middle containing block ([9ch]), the box takes its
 [stretch-fit size](#stretch-fit-size)---​filling the containing block exactly while its
 content wraps to fit inside.

- In the widest containing block ([16ch]), the box takes its
 [max-content size](#max-content)---​smaller than the containing block, but fitting
 around its unwrapped contents exactly.

``` highlight
<!DOCTYPE html>
<style>div > div { width: fit-content; }</style>
<div style="width: 2ch;">
 <div>abc def ehg</div>
</div>
<div style="width: 9ch;">
 <div>abc def ehg</div>
</div>
<div style="width: 16ch;">
 <div>abc def ehg</div>
</div>
```

!(images/fit-content.png){a
height="80" width="308"}

Using the [min-width](#propdef-min-width) or
[max-width](#propdef-max-width) property in place of
[width](#propdef-width) here would apply these same sizes as the [minimum
width](#min-width) or [maximum
width](#max-width) (respectively),
constraining the [preferred width](#width) to find the [used
width](https://drafts.csswg.org/css-cascade-5/#used-value). See [§ 3 Specifying Box Sizes](#specifying-sizes) and
[§ 3.2 Sizing Values: the \<length-percentage\>, auto \| none, stretch,
min-content, max-content, and fit-content values](#sizing-values).

### 2.2. Intrinsic Size Contributions

[max-content contribution]
: The size that a box contributes to its [containing
 block](https://drafts.csswg.org/css-display-4/#containing-block)'s [max-content
 size](#max-content).

[min-content contribution]
: The size that a box contributes to its [containing
 block](https://drafts.csswg.org/css-display-4/#containing-block)'s [min-content
 size](#min-content).

[intrinsic size contribution]
: A [max-content
 contribution](#max-content-contribution), [min-content
 contribution](#min-content-contribution), or similarly-calculated content-based size
 contribution.

Intrinsic size contributions are based on the [outer
size](#outer-size) of the box; for
this purpose [auto] margins are treated as zero.

If the ideal [max-content
contribution](#max-content-contribution) would be smaller than the [min-content
contribution](#min-content-contribution) (e.g. due to the use of negative margins) the effective
[max-content contribution] is
floored by the [min-content
contribution].

### 2.3. Intrinsic Size Constraints

[max-content constraint]
: A sizing constraint imposed by the box's [containing
 block](https://drafts.csswg.org/css-display-4/#containing-block) that causes it to produce its [max-content
 contribution](#max-content-contribution).

[min-content constraint]
: A sizing constraint imposed by the box's [containing
 block](https://drafts.csswg.org/css-display-4/#containing-block) that causes it to produce its [min-content
 contribution](#min-content-contribution).

[preferred aspect ratio]
: A width:height ratio inherent to a box, which biases various sizing
 algorithms to produce a size consistent with that aspect ratio
 insofar as possible while honoring other sizing inputs. Unless
 otherwise specified, a box's [preferred aspect
 ratio](#preferred-aspect-ratio) is its [natural aspect
 ratio](https://drafts.csswg.org/css-images-3/#natural-aspect-ratio) if it has one and is applied to its [content
 box](https://drafts.csswg.org/css-box-4/#content-box). Most boxes do not have a [preferred aspect
 ratio].
 Tests
 - [replaced-fractional-height-from-aspect-ratio.html](https://wpt.fyi/results/css/css-sizing/replaced-fractional-height-from-aspect-ratio.html "css/css-sizing/replaced-fractional-height-from-aspect-ratio.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/replaced-fractional-height-from-aspect-ratio.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/replaced-fractional-height-from-aspect-ratio.html)

## 3. Specifying Box Sizes

### 3.1. Sizing Properties

This section defines the [sizing properties], which
specify the [preferred](#preferred-size), [minimum](#min-width), and [maximum](#max-width) sizes of the box to which they are applied. Their
potential values are defined in the next section, [§ 3.2 Sizing Values:
the \<length-percentage\>, auto \| none, stretch, min-content,
max-content, and fit-content values](#sizing-values).

The
[flow-relative](https://drafts.csswg.org/css-writing-modes-4/#flow-relative) variants
([inline-size](#propdef-inline-size),
[block-size](#propdef-block-size), etc.) are mapped using the [writing
mode](https://drafts.csswg.org/css-writing-modes-4/#writing-mode) of the element itself, and interact with their
[physical](https://drafts.csswg.org/css-writing-modes-4/#physical) counterparts
([width](#propdef-width),
[height](#propdef-height), etc.) as defined in
[\[CSS-LOGICAL-1\]](#biblio-css-logical-1 "CSS Logical Properties and Values Module Level 1").
See also [CSS Writing Modes 3 § 6 Abstract Box
Terminology](https://drafts.csswg.org/css-writing-modes-3/#abstract-box).

In CSS, while the [minimum](#min-width) and [maximum](#max-width) sizes both constrain the [used
size](https://drafts.csswg.org/css-cascade-5/#used-value), the [minimum size] constraint is
always the strongest constraint. Furthermore, the [inner
size](#inner-size) is always
floored at zero.

#### 3.1.1. Preferred Size Properties: the [width, [height](#propdef-height), [inline-size](#propdef-inline-size), and [block-size](#propdef-block-size) properties]
Name:

[width], [height], [inline-size],
[block-size]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

auto
[\|](https://drafts.csswg.org/css-values-4/#comb-one)
[\<box-size\>](#typedef-box-size)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

auto

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

all elements except
[non-replaced](https://drafts.csswg.org/css-display-4/#non-replaced)
[inlines](https://drafts.csswg.org/css-display-4/#inline)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

relative to width/height of [containing
block](https://drafts.csswg.org/css-display-4/#containing-block)

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

as specified, with
[\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage) values computed

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value type, recursing into
[fit-content()](https://drafts.csswg.org/css-sizing-4/#funcdef-width-fit-content)

[Logical property
group:](https://drafts.csswg.org/css-logical-1/#logical-property-group)

[size](https://drafts.csswg.org/css-sizing-4/#propdef-size)

Tests

- [height-composition.html](https://wpt.fyi/results/css/css-sizing/animation/height-composition.html "css/css-sizing/animation/height-composition.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/animation/height-composition.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/animation/height-composition.html)
- [height-interpolation.html](https://wpt.fyi/results/css/css-sizing/animation/height-interpolation.html "css/css-sizing/animation/height-interpolation.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/animation/height-interpolation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/animation/height-interpolation.html)
- [height-no-interpolation.html](https://wpt.fyi/results/css/css-sizing/animation/height-no-interpolation.html "css/css-sizing/animation/height-no-interpolation.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/animation/height-no-interpolation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/animation/height-no-interpolation.html)
- [width-composition.html](https://wpt.fyi/results/css/css-sizing/animation/width-composition.html "css/css-sizing/animation/width-composition.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/animation/width-composition.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/animation/width-composition.html)
- [width-interpolation.html](https://wpt.fyi/results/css/css-sizing/animation/width-interpolation.html "css/css-sizing/animation/width-interpolation.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/animation/width-interpolation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/animation/width-interpolation.html)
- [percentage-height-replaced-content-in-auto-cb.html](https://wpt.fyi/results/css/css-sizing/percentage-height-replaced-content-in-auto-cb.html "css/css-sizing/percentage-height-replaced-content-in-auto-cb.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/percentage-height-replaced-content-in-auto-cb.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/percentage-height-replaced-content-in-auto-cb.html)
- [height-invalid.html](https://wpt.fyi/results/css/css-sizing/parsing/height-invalid.html "css/css-sizing/parsing/height-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/parsing/height-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/parsing/height-invalid.html)
- [height-valid.html](https://wpt.fyi/results/css/css-sizing/parsing/height-valid.html "css/css-sizing/parsing/height-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/parsing/height-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/parsing/height-valid.html)
- [width-invalid.html](https://wpt.fyi/results/css/css-sizing/parsing/width-invalid.html "css/css-sizing/parsing/width-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/parsing/width-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/parsing/width-invalid.html)
- [width-valid.html](https://wpt.fyi/results/css/css-sizing/parsing/width-valid.html "css/css-sizing/parsing/width-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/parsing/width-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/parsing/width-valid.html)

The [width](#propdef-width) and
[height](#propdef-height)
([physical](https://drafts.csswg.org/css-writing-modes-4/#physical)) and
[inline-size](#propdef-inline-size) and
[block-size](#propdef-block-size)
([flow-relative](https://drafts.csswg.org/css-writing-modes-4/#flow-relative)) are [sizing
properties](#sizing-property)
that specify the [preferred] [width] and
[height] ([physical]) or
[inline size] and [block size]
([flow-relative]) of the box, respectively.

#### 3.1.2. Minimum Size Properties: the [min-width, [min-height](#propdef-min-height), [min-inline-size](#propdef-min-inline-size), and [min-block-size](#propdef-min-block-size) properties]
Name:

[min-width], [min-height],
[min-inline-size], [min-block-size]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

auto
[\|](https://drafts.csswg.org/css-values-4/#comb-one)
[\<box-size\>](#typedef-box-size)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

auto

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

all elements that accept [width](#propdef-width) or
[height](#propdef-height)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

relative to width/height of [containing
block](https://drafts.csswg.org/css-display-4/#containing-block)

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

as specified, with
[\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage) values computed

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value, recursing into
[fit-content()](https://drafts.csswg.org/css-sizing-4/#funcdef-width-fit-content)

[Logical property
group:](https://drafts.csswg.org/css-logical-1/#logical-property-group)

[min-size](https://drafts.csswg.org/css-sizing-4/#propdef-min-size)

Tests

- [min-height-composition.html](https://wpt.fyi/results/css/css-sizing/animation/min-height-composition.html "css/css-sizing/animation/min-height-composition.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/animation/min-height-composition.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/animation/min-height-composition.html)
- [min-height-interpolation.html](https://wpt.fyi/results/css/css-sizing/animation/min-height-interpolation.html "css/css-sizing/animation/min-height-interpolation.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/animation/min-height-interpolation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/animation/min-height-interpolation.html)
- [min-width-composition.html](https://wpt.fyi/results/css/css-sizing/animation/min-width-composition.html "css/css-sizing/animation/min-width-composition.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/animation/min-width-composition.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/animation/min-width-composition.html)
- [min-width-interpolation.html](https://wpt.fyi/results/css/css-sizing/animation/min-width-interpolation.html "css/css-sizing/animation/min-width-interpolation.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/animation/min-width-interpolation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/animation/min-width-interpolation.html)
- [button-min-width.html](https://wpt.fyi/results/css/css-sizing/button-min-width.html "css/css-sizing/button-min-width.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/button-min-width.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/button-min-width.html)
- [grid-item-image-percentage-min-height-computes-as-0.html](https://wpt.fyi/results/css/css-sizing/grid-item-image-percentage-min-height-computes-as-0.html "css/css-sizing/grid-item-image-percentage-min-height-computes-as-0.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/grid-item-image-percentage-min-height-computes-as-0.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/grid-item-image-percentage-min-height-computes-as-0.html)
- [min-height-computed.html](https://wpt.fyi/results/css/css-sizing/parsing/min-height-computed.html "css/css-sizing/parsing/min-height-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/parsing/min-height-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/parsing/min-height-computed.html)
- [min-height-invalid.html](https://wpt.fyi/results/css/css-sizing/parsing/min-height-invalid.html "css/css-sizing/parsing/min-height-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/parsing/min-height-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/parsing/min-height-invalid.html)
- [min-height-valid.html](https://wpt.fyi/results/css/css-sizing/parsing/min-height-valid.html "css/css-sizing/parsing/min-height-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/parsing/min-height-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/parsing/min-height-valid.html)
- [min-width-computed.html](https://wpt.fyi/results/css/css-sizing/parsing/min-width-computed.html "css/css-sizing/parsing/min-width-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/parsing/min-width-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/parsing/min-width-computed.html)
- [min-width-invalid.html](https://wpt.fyi/results/css/css-sizing/parsing/min-width-invalid.html "css/css-sizing/parsing/min-width-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/parsing/min-width-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/parsing/min-width-invalid.html)
- [min-width-valid.html](https://wpt.fyi/results/css/css-sizing/parsing/min-width-valid.html "css/css-sizing/parsing/min-width-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/parsing/min-width-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/parsing/min-width-valid.html)

The [min-width](#propdef-min-width) and
[min-height](#propdef-min-height)
([physical](https://drafts.csswg.org/css-writing-modes-4/#physical)) and
[min-inline-size](#propdef-min-inline-size) and
[min-block-size](#propdef-min-block-size)
([flow-relative](https://drafts.csswg.org/css-writing-modes-4/#flow-relative)) are [sizing
properties](#sizing-property)
that specify the [minimum width] ("min width")
and [minimum height] ("min height") or [minimum
inline size] ("min inline size") and
[minimum block size] ("min block size")
of the box, respectively.

 The initial value of
[auto](#valdef-width-auto) is new; in
[\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")
the initial value was zero.

#### 3.1.3. Maximum Size Properties: the [max-width, [max-height](#propdef-max-height), [max-inline-size](#propdef-max-inline-size), and [max-block-size](#propdef-max-block-size) properties]
Name:

[max-width], [max-height],
[max-inline-size], [max-block-size]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

none
[\|](https://drafts.csswg.org/css-values-4/#comb-one)
[\<box-size\>](#typedef-box-size)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

none

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

all elements that accept [width](#propdef-width) or
[height](#propdef-height)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

relative to width/height of [containing
block](https://drafts.csswg.org/css-display-4/#containing-block)

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

as specified, with
[\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage) values computed

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value, recursing into
[fit-content()](https://drafts.csswg.org/css-sizing-4/#funcdef-width-fit-content)

[Logical property
group:](https://drafts.csswg.org/css-logical-1/#logical-property-group)

[max-size](https://drafts.csswg.org/css-sizing-4/#propdef-max-size)

Tests

- [max-height-composition.html](https://wpt.fyi/results/css/css-sizing/animation/max-height-composition.html "css/css-sizing/animation/max-height-composition.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/animation/max-height-composition.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/animation/max-height-composition.html)
- [max-height-interpolation.html](https://wpt.fyi/results/css/css-sizing/animation/max-height-interpolation.html "css/css-sizing/animation/max-height-interpolation.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/animation/max-height-interpolation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/animation/max-height-interpolation.html)
- [max-width-composition.html](https://wpt.fyi/results/css/css-sizing/animation/max-width-composition.html "css/css-sizing/animation/max-width-composition.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/animation/max-width-composition.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/animation/max-width-composition.html)
- [max-width-interpolation.html](https://wpt.fyi/results/css/css-sizing/animation/max-width-interpolation.html "css/css-sizing/animation/max-width-interpolation.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/animation/max-width-interpolation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/animation/max-width-interpolation.html)
- [block-image-percentage-max-height-inside-inline.html](https://wpt.fyi/results/css/css-sizing/block-image-percentage-max-height-inside-inline.html "css/css-sizing/block-image-percentage-max-height-inside-inline.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/block-image-percentage-max-height-inside-inline.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/block-image-percentage-max-height-inside-inline.html)
- [image-percentage-max-height-in-anonymous-block.html](https://wpt.fyi/results/css/css-sizing/image-percentage-max-height-in-anonymous-block.html "css/css-sizing/image-percentage-max-height-in-anonymous-block.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/image-percentage-max-height-in-anonymous-block.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/image-percentage-max-height-in-anonymous-block.html)
- [nested-flexbox-image-percentage-max-height-computes-as-none.html](https://wpt.fyi/results/css/css-sizing/nested-flexbox-image-percentage-max-height-computes-as-none.html "css/css-sizing/nested-flexbox-image-percentage-max-height-computes-as-none.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/nested-flexbox-image-percentage-max-height-computes-as-none.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/nested-flexbox-image-percentage-max-height-computes-as-none.html)
- [max-height-computed.html](https://wpt.fyi/results/css/css-sizing/parsing/max-height-computed.html "css/css-sizing/parsing/max-height-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/parsing/max-height-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/parsing/max-height-computed.html)
- [max-height-invalid.html](https://wpt.fyi/results/css/css-sizing/parsing/max-height-invalid.html "css/css-sizing/parsing/max-height-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/parsing/max-height-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/parsing/max-height-invalid.html)
- [max-height-valid.html](https://wpt.fyi/results/css/css-sizing/parsing/max-height-valid.html "css/css-sizing/parsing/max-height-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/parsing/max-height-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/parsing/max-height-valid.html)
- [max-width-computed.html](https://wpt.fyi/results/css/css-sizing/parsing/max-width-computed.html "css/css-sizing/parsing/max-width-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/parsing/max-width-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/parsing/max-width-computed.html)
- [max-width-invalid.html](https://wpt.fyi/results/css/css-sizing/parsing/max-width-invalid.html "css/css-sizing/parsing/max-width-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/parsing/max-width-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/parsing/max-width-invalid.html)
- [max-width-valid.html](https://wpt.fyi/results/css/css-sizing/parsing/max-width-valid.html "css/css-sizing/parsing/max-width-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/parsing/max-width-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/parsing/max-width-valid.html)

The [max-width](#propdef-max-width) and
[max-height](#propdef-max-height)
([physical](https://drafts.csswg.org/css-writing-modes-4/#physical)) and
[max-inline-size](#propdef-max-inline-size) and
[max-block-size](#propdef-max-block-size)
([flow-relative](https://drafts.csswg.org/css-writing-modes-4/#flow-relative)) are [sizing
properties](#sizing-property)
that specify the [maximum width] ("max width")
and [maximum height] ("max height") or [maximum
inline size] ("max inline size) and
[maximum block size] ("max block size) of
the box, respectively.

### [3.2. ][ Sizing Values: the [\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage), [auto](#valdef-width-auto) \| [none](#valdef-max-width-none), [stretch](#valdef-width-stretch), [min-content](#valdef-width-min-content), [max-content](#valdef-width-max-content), and [fit-content](#valdef-width-fit-content) values]
The following values are used in the [sizing
properties](#sizing-property). Values other than
[auto](#valdef-width-auto) and
[none](#valdef-max-width-none) are grouped under the
[\<box-size\>](#typedef-box-size) production:

``` prod
<box-size> = <length-percentage [0,∞]> | stretch | min-content | max-content | fit-content
```

 The equivalent of
[\<box-size\>](#typedef-box-size) for Level 2 would be just
[\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage) alone.

[[\<length-percentage \[0,∞\]\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage)]

: Specifies the size of the box using
 [\<length\>](https://drafts.csswg.org/css-values-4/#length-value) and/or
 [\<percentage\>](https://drafts.csswg.org/css-values-4/#percentage-value). The
 [box-sizing](#propdef-box-sizing) property indicates whether the
 [content
 box](https://drafts.csswg.org/css-box-4/#content-box) or [border
 box](https://drafts.csswg.org/css-box-4/#border-box) is measured.

 Percentages are resolved against the width/height, as appropriate,
 of the box's [containing
 block](https://drafts.csswg.org/css-display-4/#containing-block). If, in a particular axis, the [containing
 block's] size depends on the box's
 size, see the relevant layout module for special rules on how to
 resolve percentages.

 Negative values are invalid.

 Tests

 - [thin-element-render.html](https://wpt.fyi/results/css/css-sizing/thin-element-render.html "css/css-sizing/thin-element-render.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/thin-element-render.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/thin-element-render.html)

[auto]

: For [width](#propdef-width)/[height](#propdef-height), specifies an [automatic
 size] ([automatic [block
 size](#block-size)]/[automatic [inline
 size](#inline-size)]). See the relevant layout
 module for how to calculate this.

 For [min-width](#propdef-min-width)/[min-height](#propdef-min-height), specifies an [automatic
 minimum size]. Unless otherwise defined by the relevant
 layout module, however, it resolves to a used value of [0].
 For backwards-compatibility, the [resolved
 value](https://drafts.csswg.org/cssom-1/#resolved-value) of this keyword is zero for boxes of all
 [\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")
 [display
 types](https://drafts.csswg.org/css-display-4/#display-type) (block and inline boxes, inline blocks, and all
 table display types) when
 [aspect-ratio](https://drafts.csswg.org/css-sizing-4/#propdef-aspect-ratio) is
 [auto](https://drafts.csswg.org/css-sizing-4/#valdef-aspect-ratio-auto). It also resolves to zero when no box is
 generated.

[none]
: No limit on the size of the box.

[stretch]
: Applies [stretch-fit
 sizing](#stretch-fit-size), attempting to match the size of the box's [margin
 box](https://drafts.csswg.org/css-box-4/#margin-box) to the size of its [containing
 block](https://drafts.csswg.org/css-display-4/#containing-block). See [§ 4.2 Stretch-fit Sizing: filling the
 containing block](#stretch-fit-sizing).
 Tests
 - [block-height-001.html](https://wpt.fyi/results/css/css-sizing/stretch/block-height-001.html "css/css-sizing/stretch/block-height-001.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/stretch/block-height-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/stretch/block-height-001.html)
 - [flex-line-001.html](https://wpt.fyi/results/css/css-sizing/stretch/flex-line-001.html "css/css-sizing/stretch/flex-line-001.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/stretch/flex-line-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/stretch/flex-line-001.html)
 - [flex-line-002.html](https://wpt.fyi/results/css/css-sizing/stretch/flex-line-002.html "css/css-sizing/stretch/flex-line-002.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/stretch/flex-line-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/stretch/flex-line-002.html)
 - [flex-line-003.html](https://wpt.fyi/results/css/css-sizing/stretch/flex-line-003.html "css/css-sizing/stretch/flex-line-003.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/stretch/flex-line-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/stretch/flex-line-003.html)
 - [flex-line-004.html](https://wpt.fyi/results/css/css-sizing/stretch/flex-line-004.html "css/css-sizing/stretch/flex-line-004.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/stretch/flex-line-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/stretch/flex-line-004.html)
 - [flex-line-005.html](https://wpt.fyi/results/css/css-sizing/stretch/flex-line-005.html "css/css-sizing/stretch/flex-line-005.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/stretch/flex-line-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/stretch/flex-line-005.html)
 - [min-width-1.html](https://wpt.fyi/results/css/css-sizing/stretch/min-width-1.html "css/css-sizing/stretch/min-width-1.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/stretch/min-width-1.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/stretch/min-width-1.html)
 - [parsing.html](https://wpt.fyi/results/css/css-sizing/stretch/parsing.html "css/css-sizing/stretch/parsing.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/stretch/parsing.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/stretch/parsing.html)
 - [positioned-non-replaced-1.html](https://wpt.fyi/results/css/css-sizing/stretch/positioned-non-replaced-1.html "css/css-sizing/stretch/positioned-non-replaced-1.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/stretch/positioned-non-replaced-1.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/stretch/positioned-non-replaced-1.html)
 - [positioned-replaced-1.html](https://wpt.fyi/results/css/css-sizing/stretch/positioned-replaced-1.html "css/css-sizing/stretch/positioned-replaced-1.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/stretch/positioned-replaced-1.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/stretch/positioned-replaced-1.html)
 - [positioned-replaced-2.html](https://wpt.fyi/results/css/css-sizing/stretch/positioned-replaced-2.html "css/css-sizing/stretch/positioned-replaced-2.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/stretch/positioned-replaced-2.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/stretch/positioned-replaced-2.html)
 - [positioned-replaced-3.html](https://wpt.fyi/results/css/css-sizing/stretch/positioned-replaced-3.html "css/css-sizing/stretch/positioned-replaced-3.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/stretch/positioned-replaced-3.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/stretch/positioned-replaced-3.html)
 - [stretch-block-size-001.html](https://wpt.fyi/results/css/css-sizing/stretch/stretch-block-size-001.html "css/css-sizing/stretch/stretch-block-size-001.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/stretch/stretch-block-size-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/stretch/stretch-block-size-001.html)
 - [stretch-block-size-002.html](https://wpt.fyi/results/css/css-sizing/stretch/stretch-block-size-002.html "css/css-sizing/stretch/stretch-block-size-002.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/stretch/stretch-block-size-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/stretch/stretch-block-size-002.html)
 - [stretch-block-size-003.html](https://wpt.fyi/results/css/css-sizing/stretch/stretch-block-size-003.html "css/css-sizing/stretch/stretch-block-size-003.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/stretch/stretch-block-size-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/stretch/stretch-block-size-003.html)
 - [stretch-inline-size-001.html](https://wpt.fyi/results/css/css-sizing/stretch/stretch-inline-size-001.html "css/css-sizing/stretch/stretch-inline-size-001.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/stretch/stretch-inline-size-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/stretch/stretch-inline-size-001.html)
 - [stretch-inline-size-002.html](https://wpt.fyi/results/css/css-sizing/stretch/stretch-inline-size-002.html "css/css-sizing/stretch/stretch-inline-size-002.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/stretch/stretch-inline-size-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/stretch/stretch-inline-size-002.html)
 - [stretch-inline-size-003.html](https://wpt.fyi/results/css/css-sizing/stretch/stretch-inline-size-003.html "css/css-sizing/stretch/stretch-inline-size-003.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/stretch/stretch-inline-size-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/stretch/stretch-inline-size-003.html)
 - [stretch-max-block-size-001.html](https://wpt.fyi/results/css/css-sizing/stretch/stretch-max-block-size-001.html "css/css-sizing/stretch/stretch-max-block-size-001.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/stretch/stretch-max-block-size-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/stretch/stretch-max-block-size-001.html)
 - [stretch-max-inline-size-001.html](https://wpt.fyi/results/css/css-sizing/stretch/stretch-max-inline-size-001.html "css/css-sizing/stretch/stretch-max-inline-size-001.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/stretch/stretch-max-inline-size-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/stretch/stretch-max-inline-size-001.html)
 - [stretch-min-block-size-001.html](https://wpt.fyi/results/css/css-sizing/stretch/stretch-min-block-size-001.html "css/css-sizing/stretch/stretch-min-block-size-001.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/stretch/stretch-min-block-size-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/stretch/stretch-min-block-size-001.html)
 - [stretch-min-inline-size-001.html](https://wpt.fyi/results/css/css-sizing/stretch/stretch-min-inline-size-001.html "css/css-sizing/stretch/stretch-min-inline-size-001.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/stretch/stretch-min-inline-size-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/stretch/stretch-min-inline-size-001.html)
 - [stretch-quirk-001.html](https://wpt.fyi/results/css/css-sizing/stretch/stretch-quirk-001.html "css/css-sizing/stretch/stretch-quirk-001.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/stretch/stretch-quirk-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/stretch/stretch-quirk-001.html)

[min-content]
: Use the [min-content size](#min-content) in the relevant axis; for a box's [block
 size](#block-size), unless
 otherwise specified, this is equivalent to its [automatic
 size](#automatic-size).
 Tests
 - [clone-intrinsic-size.html](https://wpt.fyi/results/css/css-sizing/clone-intrinsic-size.html "css/css-sizing/clone-intrinsic-size.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/clone-intrinsic-size.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/clone-intrinsic-size.html)
 - [clone-nowrap-intrinsic-size-bidi.html](https://wpt.fyi/results/css/css-sizing/clone-nowrap-intrinsic-size-bidi.html "css/css-sizing/clone-nowrap-intrinsic-size-bidi.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/clone-nowrap-intrinsic-size-bidi.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/clone-nowrap-intrinsic-size-bidi.html)
 - [clone-nowrap-intrinsic-size.html](https://wpt.fyi/results/css/css-sizing/clone-nowrap-intrinsic-size.html "css/css-sizing/clone-nowrap-intrinsic-size.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/clone-nowrap-intrinsic-size.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/clone-nowrap-intrinsic-size.html)
 - [min-content-negative-margin-crash.html](https://wpt.fyi/results/css/css-sizing/min-content-negative-margin-crash.html "css/css-sizing/min-content-negative-margin-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/min-content-negative-margin-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/min-content-negative-margin-crash.html)
 - [replaced-max-height-min-content.html](https://wpt.fyi/results/css/css-sizing/replaced-max-height-min-content.html "css/css-sizing/replaced-max-height-min-content.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/replaced-max-height-min-content.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/replaced-max-height-min-content.html)
 - [replaced-max-size-saturation.html](https://wpt.fyi/results/css/css-sizing/replaced-max-size-saturation.html "css/css-sizing/replaced-max-size-saturation.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/replaced-max-size-saturation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/replaced-max-size-saturation.html)
 - [replaced-max-width-min-content.html](https://wpt.fyi/results/css/css-sizing/replaced-max-width-min-content.html "css/css-sizing/replaced-max-width-min-content.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/replaced-max-width-min-content.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/replaced-max-width-min-content.html)
 - [replaced-min-height-min-content.html](https://wpt.fyi/results/css/css-sizing/replaced-min-height-min-content.html "css/css-sizing/replaced-min-height-min-content.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/replaced-min-height-min-content.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/replaced-min-height-min-content.html)
 - [replaced-min-width-min-content.html](https://wpt.fyi/results/css/css-sizing/replaced-min-width-min-content.html "css/css-sizing/replaced-min-width-min-content.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/replaced-min-width-min-content.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/replaced-min-width-min-content.html)
 - [shrink-to-fit-sizing-max-width-min-content.html](https://wpt.fyi/results/css/css-sizing/shrink-to-fit-sizing-max-width-min-content.html "css/css-sizing/shrink-to-fit-sizing-max-width-min-content.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/shrink-to-fit-sizing-max-width-min-content.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/shrink-to-fit-sizing-max-width-min-content.html)
 - [slice-intrinsic-size.html](https://wpt.fyi/results/css/css-sizing/slice-intrinsic-size.html "css/css-sizing/slice-intrinsic-size.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/slice-intrinsic-size.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/slice-intrinsic-size.html)
 - [slice-nowrap-intrinsic-size-bidi.html](https://wpt.fyi/results/css/css-sizing/slice-nowrap-intrinsic-size-bidi.html "css/css-sizing/slice-nowrap-intrinsic-size-bidi.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/slice-nowrap-intrinsic-size-bidi.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/slice-nowrap-intrinsic-size-bidi.html)
 - [slice-nowrap-intrinsic-size.html](https://wpt.fyi/results/css/css-sizing/slice-nowrap-intrinsic-size.html "css/css-sizing/slice-nowrap-intrinsic-size.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/slice-nowrap-intrinsic-size.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/slice-nowrap-intrinsic-size.html)
 - [svg-no-ar-max-height-min-content.html](https://wpt.fyi/results/css/css-sizing/svg-no-ar-max-height-min-content.html "css/css-sizing/svg-no-ar-max-height-min-content.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/svg-no-ar-max-height-min-content.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/svg-no-ar-max-height-min-content.html)
 - [svg-no-ar-min-height-min-content.html](https://wpt.fyi/results/css/css-sizing/svg-no-ar-min-height-min-content.html "css/css-sizing/svg-no-ar-min-height-min-content.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/svg-no-ar-min-height-min-content.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/svg-no-ar-min-height-min-content.html)

[max-content]
: Use the [max-content size](#max-content) in the relevant axis; for a box's [block
 size](#block-size), unless
 otherwise specified, this is equivalent to its [automatic
 size](#automatic-size).

[fit-content]
: Use the [fit-content
 size](#fit-content-size)
 in the relevant axis, i.e.
 `min(`[`max-content`](#valdef-width-max-content)`, max(`[`min-content`](#valdef-width-min-content)`, `[`stretch`](#valdef-width-stretch)`))`.
 Tests
 - [fit-content-block-size-abspos.html](https://wpt.fyi/results/css/css-sizing/fit-content-block-size-abspos.html "css/css-sizing/fit-content-block-size-abspos.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/fit-content-block-size-abspos.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/fit-content-block-size-abspos.html)
 - [fit-content-block-size-fixedpos.html](https://wpt.fyi/results/css/css-sizing/fit-content-block-size-fixedpos.html "css/css-sizing/fit-content-block-size-fixedpos.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/fit-content-block-size-fixedpos.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/fit-content-block-size-fixedpos.html)
 - [fit-content-contribution-001.html](https://wpt.fyi/results/css/css-sizing/fit-content-contribution-001.html "css/css-sizing/fit-content-contribution-001.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/fit-content-contribution-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/fit-content-contribution-001.html)
 - [fit-content-min-inline-size.html](https://wpt.fyi/results/css/css-sizing/fit-content-min-inline-size.html "css/css-sizing/fit-content-min-inline-size.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/fit-content-min-inline-size.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/fit-content-min-inline-size.html)
 - [fit-content-percentage-padding.html](https://wpt.fyi/results/css/css-sizing/fit-content-percentage-padding.html "css/css-sizing/fit-content-percentage-padding.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/fit-content-percentage-padding.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/fit-content-percentage-padding.html)
 - [float-clearance-with-margin-collapse-and-fit-content-and-padding-percentage-001.html](https://wpt.fyi/results/css/css-sizing/float-clearance-with-margin-collapse-and-fit-content-and-padding-percentage-001.html "css/css-sizing/float-clearance-with-margin-collapse-and-fit-content-and-padding-percentage-001.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/float-clearance-with-margin-collapse-and-fit-content-and-padding-percentage-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/float-clearance-with-margin-collapse-and-fit-content-and-padding-percentage-001.html)
 - [float-clearance-with-margin-collapse-and-fit-content-and-padding-percentage-002.html](https://wpt.fyi/results/css/css-sizing/float-clearance-with-margin-collapse-and-fit-content-and-padding-percentage-002.html "css/css-sizing/float-clearance-with-margin-collapse-and-fit-content-and-padding-percentage-002.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/float-clearance-with-margin-collapse-and-fit-content-and-padding-percentage-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/float-clearance-with-margin-collapse-and-fit-content-and-padding-percentage-002.html)
 - [float-clearance-with-margin-collapse-and-fit-content-and-padding-percentage-003.html](https://wpt.fyi/results/css/css-sizing/float-clearance-with-margin-collapse-and-fit-content-and-padding-percentage-003.html "css/css-sizing/float-clearance-with-margin-collapse-and-fit-content-and-padding-percentage-003.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/float-clearance-with-margin-collapse-and-fit-content-and-padding-percentage-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/float-clearance-with-margin-collapse-and-fit-content-and-padding-percentage-003.html)
 - [float-clearance-with-margin-collapse-and-fit-content-and-padding-percentage-004.html](https://wpt.fyi/results/css/css-sizing/float-clearance-with-margin-collapse-and-fit-content-and-padding-percentage-004.html "css/css-sizing/float-clearance-with-margin-collapse-and-fit-content-and-padding-percentage-004.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/float-clearance-with-margin-collapse-and-fit-content-and-padding-percentage-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/float-clearance-with-margin-collapse-and-fit-content-and-padding-percentage-004.html)

Tests

- [block-size-with-min-or-max-content-1a.html](https://wpt.fyi/results/css/css-sizing/block-size-with-min-or-max-content-1a.html "css/css-sizing/block-size-with-min-or-max-content-1a.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/block-size-with-min-or-max-content-1a.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/block-size-with-min-or-max-content-1a.html)
- [block-size-with-min-or-max-content-1b.html](https://wpt.fyi/results/css/css-sizing/block-size-with-min-or-max-content-1b.html "css/css-sizing/block-size-with-min-or-max-content-1b.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/block-size-with-min-or-max-content-1b.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/block-size-with-min-or-max-content-1b.html)
- [block-size-with-min-or-max-content-2.html](https://wpt.fyi/results/css/css-sizing/block-size-with-min-or-max-content-2.html "css/css-sizing/block-size-with-min-or-max-content-2.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/block-size-with-min-or-max-content-2.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/block-size-with-min-or-max-content-2.html)
- [block-size-with-min-or-max-content-3.html](https://wpt.fyi/results/css/css-sizing/block-size-with-min-or-max-content-3.html "css/css-sizing/block-size-with-min-or-max-content-3.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/block-size-with-min-or-max-content-3.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/block-size-with-min-or-max-content-3.html)
- [block-size-with-min-or-max-content-4.html](https://wpt.fyi/results/css/css-sizing/block-size-with-min-or-max-content-4.html "css/css-sizing/block-size-with-min-or-max-content-4.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/block-size-with-min-or-max-content-4.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/block-size-with-min-or-max-content-4.html)
- [block-size-with-min-or-max-content-5.html](https://wpt.fyi/results/css/css-sizing/block-size-with-min-or-max-content-5.html "css/css-sizing/block-size-with-min-or-max-content-5.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/block-size-with-min-or-max-content-5.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/block-size-with-min-or-max-content-5.html)
- [block-size-with-min-or-max-content-6.html](https://wpt.fyi/results/css/css-sizing/block-size-with-min-or-max-content-6.html "css/css-sizing/block-size-with-min-or-max-content-6.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/block-size-with-min-or-max-content-6.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/block-size-with-min-or-max-content-6.html)
- [block-size-with-min-or-max-content-7.html](https://wpt.fyi/results/css/css-sizing/block-size-with-min-or-max-content-7.html "css/css-sizing/block-size-with-min-or-max-content-7.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/block-size-with-min-or-max-content-7.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/block-size-with-min-or-max-content-7.html)
- [block-size-with-min-or-max-content-table-1a.html](https://wpt.fyi/results/css/css-sizing/block-size-with-min-or-max-content-table-1a.html "css/css-sizing/block-size-with-min-or-max-content-table-1a.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/block-size-with-min-or-max-content-table-1a.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/block-size-with-min-or-max-content-table-1a.html)
- [block-size-with-min-or-max-content-table-1b.html](https://wpt.fyi/results/css/css-sizing/block-size-with-min-or-max-content-table-1b.html "css/css-sizing/block-size-with-min-or-max-content-table-1b.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/block-size-with-min-or-max-content-table-1b.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/block-size-with-min-or-max-content-table-1b.html)
- [hori-block-size-small-or-larger-than-container-with-min-or-max-content-1.html](https://wpt.fyi/results/css/css-sizing/hori-block-size-small-or-larger-than-container-with-min-or-max-content-1.html "css/css-sizing/hori-block-size-small-or-larger-than-container-with-min-or-max-content-1.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/hori-block-size-small-or-larger-than-container-with-min-or-max-content-1.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/hori-block-size-small-or-larger-than-container-with-min-or-max-content-1.html)
- [hori-block-size-small-or-larger-than-container-with-min-or-max-content-2a.html](https://wpt.fyi/results/css/css-sizing/hori-block-size-small-or-larger-than-container-with-min-or-max-content-2a.html "css/css-sizing/hori-block-size-small-or-larger-than-container-with-min-or-max-content-2a.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/hori-block-size-small-or-larger-than-container-with-min-or-max-content-2a.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/hori-block-size-small-or-larger-than-container-with-min-or-max-content-2a.html)
- [hori-block-size-small-or-larger-than-container-with-min-or-max-content-2b.html](https://wpt.fyi/results/css/css-sizing/hori-block-size-small-or-larger-than-container-with-min-or-max-content-2b.html "css/css-sizing/hori-block-size-small-or-larger-than-container-with-min-or-max-content-2b.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/hori-block-size-small-or-larger-than-container-with-min-or-max-content-2b.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/hori-block-size-small-or-larger-than-container-with-min-or-max-content-2b.html)
- [image-min-max-content-intrinsic-size-change-001.html](https://wpt.fyi/results/css/css-sizing/image-min-max-content-intrinsic-size-change-001.html "css/css-sizing/image-min-max-content-intrinsic-size-change-001.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/image-min-max-content-intrinsic-size-change-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/image-min-max-content-intrinsic-size-change-001.html)
- [image-min-max-content-intrinsic-size-change-002.html](https://wpt.fyi/results/css/css-sizing/image-min-max-content-intrinsic-size-change-002.html "css/css-sizing/image-min-max-content-intrinsic-size-change-002.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/image-min-max-content-intrinsic-size-change-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/image-min-max-content-intrinsic-size-change-002.html)
- [image-min-max-content-intrinsic-size-change-003.html](https://wpt.fyi/results/css/css-sizing/image-min-max-content-intrinsic-size-change-003.html "css/css-sizing/image-min-max-content-intrinsic-size-change-003.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/image-min-max-content-intrinsic-size-change-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/image-min-max-content-intrinsic-size-change-003.html)
- [image-min-max-content-intrinsic-size-change-004.html](https://wpt.fyi/results/css/css-sizing/image-min-max-content-intrinsic-size-change-004.html "css/css-sizing/image-min-max-content-intrinsic-size-change-004.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/image-min-max-content-intrinsic-size-change-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/image-min-max-content-intrinsic-size-change-004.html)
- [image-min-max-content-intrinsic-size-change-005.html](https://wpt.fyi/results/css/css-sizing/image-min-max-content-intrinsic-size-change-005.html "css/css-sizing/image-min-max-content-intrinsic-size-change-005.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/image-min-max-content-intrinsic-size-change-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/image-min-max-content-intrinsic-size-change-005.html)
- [image-min-max-content-intrinsic-size-change-006.html](https://wpt.fyi/results/css/css-sizing/image-min-max-content-intrinsic-size-change-006.html "css/css-sizing/image-min-max-content-intrinsic-size-change-006.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/image-min-max-content-intrinsic-size-change-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/image-min-max-content-intrinsic-size-change-006.html)
- [image-min-max-content-intrinsic-size-change-007.html](https://wpt.fyi/results/css/css-sizing/image-min-max-content-intrinsic-size-change-007.html "css/css-sizing/image-min-max-content-intrinsic-size-change-007.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/image-min-max-content-intrinsic-size-change-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/image-min-max-content-intrinsic-size-change-007.html)
- [image-min-max-content-intrinsic-size-change-008.html](https://wpt.fyi/results/css/css-sizing/image-min-max-content-intrinsic-size-change-008.html "css/css-sizing/image-min-max-content-intrinsic-size-change-008.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/image-min-max-content-intrinsic-size-change-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/image-min-max-content-intrinsic-size-change-008.html)
- [keyword-sizes-for-intrinsic-contributions.html](https://wpt.fyi/results/css/css-sizing/keyword-sizes-for-intrinsic-contributions.html "css/css-sizing/keyword-sizes-for-intrinsic-contributions.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/keyword-sizes-for-intrinsic-contributions.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/keyword-sizes-for-intrinsic-contributions.html)
- [keyword-sizes-for-intrinsic-contributions-002.html](https://wpt.fyi/results/css/css-sizing/keyword-sizes-for-intrinsic-contributions-002.html "css/css-sizing/keyword-sizes-for-intrinsic-contributions-002.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/keyword-sizes-for-intrinsic-contributions-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/keyword-sizes-for-intrinsic-contributions-002.html)
- [keyword-sizes-on-abspos.html](https://wpt.fyi/results/css/css-sizing/keyword-sizes-on-abspos.html "css/css-sizing/keyword-sizes-on-abspos.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/keyword-sizes-on-abspos.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/keyword-sizes-on-abspos.html)
- [keyword-sizes-on-flex-item-001.html](https://wpt.fyi/results/css/css-sizing/keyword-sizes-on-flex-item-001.html "css/css-sizing/keyword-sizes-on-flex-item-001.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/keyword-sizes-on-flex-item-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/keyword-sizes-on-flex-item-001.html)
- [keyword-sizes-on-flex-item-002.html](https://wpt.fyi/results/css/css-sizing/keyword-sizes-on-flex-item-002.html "css/css-sizing/keyword-sizes-on-flex-item-002.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/keyword-sizes-on-flex-item-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/keyword-sizes-on-flex-item-002.html)
- [keyword-sizes-on-floated-element.html](https://wpt.fyi/results/css/css-sizing/keyword-sizes-on-floated-element.html "css/css-sizing/keyword-sizes-on-floated-element.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/keyword-sizes-on-floated-element.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/keyword-sizes-on-floated-element.html)
- [keyword-sizes-on-inline-block.html](https://wpt.fyi/results/css/css-sizing/keyword-sizes-on-inline-block.html "css/css-sizing/keyword-sizes-on-inline-block.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/keyword-sizes-on-inline-block.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/keyword-sizes-on-inline-block.html)
- [keyword-sizes-on-replaced-element.html](https://wpt.fyi/results/css/css-sizing/keyword-sizes-on-replaced-element.html "css/css-sizing/keyword-sizes-on-replaced-element.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/keyword-sizes-on-replaced-element.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/keyword-sizes-on-replaced-element.html)
- [min-content-min-width-000.html](https://wpt.fyi/results/css/css-sizing/min-content-min-width-000.html "css/css-sizing/min-content-min-width-000.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/min-content-min-width-000.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/min-content-min-width-000.html)
- [percentage-min-width.html](https://wpt.fyi/results/css/css-sizing/percentage-min-width.html "css/css-sizing/percentage-min-width.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/percentage-min-width.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/percentage-min-width.html)
- [vert-block-size-small-or-larger-than-container-with-min-or-max-content-1.html](https://wpt.fyi/results/css/css-sizing/vert-block-size-small-or-larger-than-container-with-min-or-max-content-1.html "css/css-sizing/vert-block-size-small-or-larger-than-container-with-min-or-max-content-1.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/vert-block-size-small-or-larger-than-container-with-min-or-max-content-1.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/vert-block-size-small-or-larger-than-container-with-min-or-max-content-1.html)
- [vert-block-size-small-or-larger-than-container-with-min-or-max-content-2a.html](https://wpt.fyi/results/css/css-sizing/vert-block-size-small-or-larger-than-container-with-min-or-max-content-2a.html "css/css-sizing/vert-block-size-small-or-larger-than-container-with-min-or-max-content-2a.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/vert-block-size-small-or-larger-than-container-with-min-or-max-content-2a.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/vert-block-size-small-or-larger-than-container-with-min-or-max-content-2a.html)
- [vert-block-size-small-or-larger-than-container-with-min-or-max-content-2b.html](https://wpt.fyi/results/css/css-sizing/vert-block-size-small-or-larger-than-container-with-min-or-max-content-2b.html "css/css-sizing/vert-block-size-small-or-larger-than-container-with-min-or-max-content-2b.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/vert-block-size-small-or-larger-than-container-with-min-or-max-content-2b.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/vert-block-size-small-or-larger-than-container-with-min-or-max-content-2b.html)

In all cases, the used value is floored to preserve a non-negative
[inner size](#inner-size).

 The
[stretch](#valdef-width-stretch),
[min-content](#valdef-width-min-content),
[max-content](#valdef-width-max-content), and
[fit-content](#valdef-width-fit-content) values are new in Level 3.

 The
[flex-basis](https://drafts.csswg.org/css-flexbox-2/#propdef-flex-basis) property hereby also gains these
new keywords, as its values are defined by reference to
[\<\'width\'\>](#propdef-width).

#### 3.2.1. "Behaving as [auto"]
To have a common term for both when
[width](#propdef-width)/[height](#propdef-height) computes to
[auto](#valdef-width-auto) and when it is defined to behave as if
[auto] were specified (as in the case
of [block percentage
heights](https://www.w3.org/TR/CSS2/visudet.html#the-height-property)
resolving against an [indefinite](#indefinite) size, see
[CSS2§10.5](https://www.w3.org/TR/CSS2/visudet.html#the-height-property)),
the property is said to [behave as auto] in both of these
cases.

 Legacy spec prose defining layout behavior,
particularly in
[\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification"),
might explicitly refer to
[width](#propdef-width)/[height](#propdef-height) having a computed value of
[auto](#valdef-width-auto) as a condition; some of these cases should be
interpreted as meaning [behaves as
auto](#behave-as-auto), and
reported to the CSSWG for updating.

Tests

- [margin-collapse-with-indefinite-block-size-001.html](https://wpt.fyi/results/css/css-sizing/margin-collapse-with-indefinite-block-size-001.html "css/css-sizing/margin-collapse-with-indefinite-block-size-001.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/margin-collapse-with-indefinite-block-size-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/margin-collapse-with-indefinite-block-size-001.html)
- [margin-collapse-with-indefinite-block-size-002.html](https://wpt.fyi/results/css/css-sizing/margin-collapse-with-indefinite-block-size-002.html "css/css-sizing/margin-collapse-with-indefinite-block-size-002.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/margin-collapse-with-indefinite-block-size-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/margin-collapse-with-indefinite-block-size-002.html)
- [margin-collapse-with-indefinite-block-size-003.html](https://wpt.fyi/results/css/css-sizing/margin-collapse-with-indefinite-block-size-003.html "css/css-sizing/margin-collapse-with-indefinite-block-size-003.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/margin-collapse-with-indefinite-block-size-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/margin-collapse-with-indefinite-block-size-003.html)
- [margin-collapse-with-indefinite-block-size-004.html](https://wpt.fyi/results/css/css-sizing/margin-collapse-with-indefinite-block-size-004.html "css/css-sizing/margin-collapse-with-indefinite-block-size-004.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/margin-collapse-with-indefinite-block-size-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/margin-collapse-with-indefinite-block-size-004.html)
- [margin-collapse-with-indefinite-block-size-005.html](https://wpt.fyi/results/css/css-sizing/margin-collapse-with-indefinite-block-size-005.html "css/css-sizing/margin-collapse-with-indefinite-block-size-005.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/margin-collapse-with-indefinite-block-size-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/margin-collapse-with-indefinite-block-size-005.html)

Replace this section with references to
the new term [automatic size](#automatic-size).

#### 3.2.2. Containing or Excluding Floats

*This section is non-normative.*

Although [block
box](https://drafts.csswg.org/css-display-4/#block-box) boundaries are typically pervious to floats, sometimes
an author needs them to contain their own (descendant) floats or to
exclude floats from outside. For Block layout, specifying [display:
flow-root](https://drafts.csswg.org/css-display-3/#propdef-display) will make the box a [formatting
context](https://drafts.csswg.org/css-display-4/#formatting-context) root, which has this behavior.

 Boxes participating in Flex, Grid, or Table layout will
automatically have this behavior.

### 3.3. Box Edges for Sizing: the [box-sizing property]
Name:

[box-sizing]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

content-box
[\|](https://drafts.csswg.org/css-values-4/#comb-one) border-box

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

content-box

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

all elements that accept
[width](#propdef-width) or
[height](#propdef-height)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

N/A

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

specified keyword

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

Tests

- [box-sizing-replaced-001.xht](https://wpt.fyi/results/css/css-sizing/box-sizing-replaced-001.xht "css/css-sizing/box-sizing-replaced-001.xht")
 [[(live
 test)]](http://wpt.live/css/css-sizing/box-sizing-replaced-001.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/box-sizing-replaced-001.xht)
- [box-sizing-replaced-002.xht](https://wpt.fyi/results/css/css-sizing/box-sizing-replaced-002.xht "css/css-sizing/box-sizing-replaced-002.xht")
 [[(live
 test)]](http://wpt.live/css/css-sizing/box-sizing-replaced-002.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/box-sizing-replaced-002.xht)
- [box-sizing-replaced-003.xht](https://wpt.fyi/results/css/css-sizing/box-sizing-replaced-003.xht "css/css-sizing/box-sizing-replaced-003.xht")
 [[(live
 test)]](http://wpt.live/css/css-sizing/box-sizing-replaced-003.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/box-sizing-replaced-003.xht)
- [box-sizing-computed.html](https://wpt.fyi/results/css/css-sizing/parsing/box-sizing-computed.html "css/css-sizing/parsing/box-sizing-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/parsing/box-sizing-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/parsing/box-sizing-computed.html)
- [box-sizing-invalid.html](https://wpt.fyi/results/css/css-sizing/parsing/box-sizing-invalid.html "css/css-sizing/parsing/box-sizing-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/parsing/box-sizing-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/parsing/box-sizing-invalid.html)
- [box-sizing-valid.html](https://wpt.fyi/results/css/css-sizing/parsing/box-sizing-valid.html "css/css-sizing/parsing/box-sizing-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/parsing/box-sizing-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/parsing/box-sizing-valid.html)

The [box-sizing](#propdef-box-sizing) property defines whether fixed sizes
(such as
[\<length\>](https://drafts.csswg.org/css-values-4/#length-value)s and
[\<percentage\>](https://drafts.csswg.org/css-values-4/#percentage-value)s) are assigned to the [content
box](https://drafts.csswg.org/css-box-4/#content-box) or to the [border
box](https://drafts.csswg.org/css-box-4/#border-box). It affects the interpretation of all [sizing
properties](#sizing-property), including
[flex-basis](https://drafts.csswg.org/css-flexbox-2/#propdef-flex-basis).

Values have the following meanings:

[content-box]

: Sizes specified on [sizing
 properties](#sizing-property) as
 [\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage) represent the box's [inner
 sizes](#inner-size), excluding
 the margins/border/padding: they are applied to the [content
 box](https://drafts.csswg.org/css-box-4/#content-box). The padding and border of the box are laid out and
 drawn *outside* the specified
 [width](#propdef-width) and
 [height](#propdef-height).

 This is the behavior of width and height as
 specified by CSS2.1, and is thus the default.

 Tests

 - [box-sizing-content-box-001.xht](https://wpt.fyi/results/css/css-sizing/box-sizing-content-box-001.xht "css/css-sizing/box-sizing-content-box-001.xht")
 [[(live
 test)]](http://wpt.live/css/css-sizing/box-sizing-content-box-001.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/box-sizing-content-box-001.xht)
 - [box-sizing-content-box-002.xht](https://wpt.fyi/results/css/css-sizing/box-sizing-content-box-002.xht "css/css-sizing/box-sizing-content-box-002.xht")
 [[(live
 test)]](http://wpt.live/css/css-sizing/box-sizing-content-box-002.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/box-sizing-content-box-002.xht)
 - [box-sizing-content-box-003.xht](https://wpt.fyi/results/css/css-sizing/box-sizing-content-box-003.xht "css/css-sizing/box-sizing-content-box-003.xht")
 [[(live
 test)]](http://wpt.live/css/css-sizing/box-sizing-content-box-003.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/box-sizing-content-box-003.xht)

[border-box]

: Any
 [\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage) values in the [sizing
 properties](#sizing-property) are applied to the [border
 box](https://drafts.csswg.org/css-box-4/#border-box), thus representing the box's visually-apparent
 sizes: the
 [padding](https://drafts.csswg.org/css-box-4/#padding) and
 [border](https://drafts.csswg.org/css-box-4/#border) of the box (but not its
 [margins](https://drafts.csswg.org/css-box-4/#margin)) are essentially laid out and drawn *inside* the
 used [width](#propdef-width) and
 [height](#propdef-height), with the [content
 box](https://drafts.csswg.org/css-box-4/#content-box) sized to fill the remaining space. More
 specifically, the [content box]
 [width](#width) and
 [height](#height) are calculated
 by subtracting the [border] and
 [padding] in the corresponding axis from the
 specified
 [\<length-percentage\>], and flooring the result at zero (as the [inner
 size](#inner-size) of a box
 cannot be negative).

 Used values of the [sizing
 properties](#sizing-property), as exposed for instance through
 [`getComputedStyle()`](https://drafts.csswg.org/cssom-1/#dom-window-getcomputedstyle), also refer to the [border
 box](https://drafts.csswg.org/css-box-4/#border-box).

 Tests

 - [border-box-and-max-content-001.html](https://wpt.fyi/results/css/css-sizing/border-box-and-max-content-001.html "css/css-sizing/border-box-and-max-content-001.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/border-box-and-max-content-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/border-box-and-max-content-001.html)
 - [border-box-and-max-content-002.html](https://wpt.fyi/results/css/css-sizing/border-box-and-max-content-002.html "css/css-sizing/border-box-and-max-content-002.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/border-box-and-max-content-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/border-box-and-max-content-002.html)
 - [border-box-and-max-content-003.html](https://wpt.fyi/results/css/css-sizing/border-box-and-max-content-003.html "css/css-sizing/border-box-and-max-content-003.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/border-box-and-max-content-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/border-box-and-max-content-003.html)
 - [box-sizing-border-box-001.xht](https://wpt.fyi/results/css/css-sizing/box-sizing-border-box-001.xht "css/css-sizing/box-sizing-border-box-001.xht")
 [[(live
 test)]](http://wpt.live/css/css-sizing/box-sizing-border-box-001.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/box-sizing-border-box-001.xht)
 - [box-sizing-border-box-002.xht](https://wpt.fyi/results/css/css-sizing/box-sizing-border-box-002.xht "css/css-sizing/box-sizing-border-box-002.xht")
 [[(live
 test)]](http://wpt.live/css/css-sizing/box-sizing-border-box-002.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/box-sizing-border-box-002.xht)
 - [box-sizing-border-box-003.xht](https://wpt.fyi/results/css/css-sizing/box-sizing-border-box-003.xht "css/css-sizing/box-sizing-border-box-003.xht")
 [[(live
 test)]](http://wpt.live/css/css-sizing/box-sizing-border-box-003.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/box-sizing-border-box-003.xht)
 - [box-sizing-border-box-004.xht](https://wpt.fyi/results/css/css-sizing/box-sizing-border-box-004.xht "css/css-sizing/box-sizing-border-box-004.xht")
 [[(live
 test)]](http://wpt.live/css/css-sizing/box-sizing-border-box-004.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/box-sizing-border-box-004.xht)
 - [table-child-percentage-height-with-border-box.html](https://wpt.fyi/results/css/css-sizing/table-child-percentage-height-with-border-box.html "css/css-sizing/table-child-percentage-height-with-border-box.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/table-child-percentage-height-with-border-box.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/table-child-percentage-height-with-border-box.html)

Values affected by
[box-sizing](#propdef-box-sizing) include both raw
[\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage) values and those used in functional
notations such as
[fit-content()](https://drafts.csswg.org/css-sizing-4/#funcdef-width-fit-content)
[\[css-sizing-4\]](#biblio-css-sizing-4 "CSS Box Sizing Module Level 4").
In contrast, non-quantitative values such as
[auto](#valdef-width-auto) and
[min-content](#valdef-width-min-content) are not influenced by the
[box-sizing] property (unless
otherwise specified).

For example, the following properties
set the content-box size of the box to [100px], with the
border-box size calculating to [120px]:

```
.box {
 box-sizing: content-box; /* default */
 width: 100px;
 padding-left: 10px;
 border-left: 10px solid;
}
```

On the other hand, by changing to
[border-box](#valdef-box-sizing-border-box), the border-box is set to [100px], with
the content-box size calculating to [80px]:

```
.box {
 box-sizing: border-box;
 width: 100px;
 padding-left: 10px;
 border-left: 10px solid;
}
```

The [inner size](#inner-size)
can't be less than zero, so if the
[padding](https://drafts.csswg.org/css-box-4/#propdef-padding) +
[border](https://drafts.csswg.org/css-borders-4/#propdef-border) is greater than the specified
border-box size, the box will end up larger than specified. In this
case, the content-box size will floor at [0px] so the border-box
size ends up at [120px], even though [width:
100px](#propdef-width) is specified for the border box:

```
.box {
 box-sizing: border-box;
 width: 100px;
 padding-left: 60px;
 border-left: 60px solid;
 /* padding + border = 120px */
}
```

This example uses box-sizing to evenly
horizontally split two divs with fixed size borders inside a div
container, which would otherwise require additional markup.

sample CSS:

```
div.container {
 width:38em;
 border:1em solid black;
}

div.split {
 box-sizing:border-box;
 width:50%;
 border:1em silver ridge;
 float:left;
}
```

sample HTML fragment:

```
<div class="container">
<div class="split">This div occupies the left half.</div>
<div class="split">This div occupies the right half.</div>
</div>
```

demonstration of sample CSS and HTML:

::::: {style="max-width:38em; border:1em solid black"}
::: {style="box-sizing:border-box; width:50%; border:1em silver ridge; float:left"}
This div should occupy the left half.

::: {style="box-sizing:border-box; width:50%; border:1em silver ridge; float:left"}
This div should occupy the right half.

The two divs above should appear side by side, each (including borders)
50% of the content width of their container. If instead they are stacked
one on top of the other then your browser does not support
[box-sizing](#propdef-box-sizing).

 Certain HTML elements, such as
[`button`](https://html.spec.whatwg.org/multipage/form-elements.html#the-button-element), default to
[border-box](#valdef-box-sizing-border-box) behavior. See HTML for details on which elements
have this behavior.

In legacy CSS specifications, the terms [width](#width), [height](#height),
[minimum (min) width](#min-width),
[minimum (min) height](#min-height), [maximum (max) width](#max-width), and [maximum (max)
height](#max-height) generally
refer to the [inner](#inner-size)
size
([content-box](https://drafts.csswg.org/css-box-4/#content-box) size) of a
[box](https://drafts.csswg.org/css-display-3/#box) unless otherwise indicated.

Refer to [CSS User Interface 3 § 3.1 Changing the Box Model: the
box-sizing property](https://drafts.csswg.org/css-ui-3/#box-sizing) for
an explicit disambiguation of these terms for the [Visual formatting
model details](https://www.w3.org/TR/CSS21/visudet.html) section of
[\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification").

To avoid ambiguities, specification authors should avoid ambiguous uses
of terms such as width or height without further qualification, and
should explicitly refer and link to the
[inner](#inner-size) size, the
[outer](#outer-size) size, the
size of the
[border-box](https://www.w3.org/TR/css2/box.html#box-dimensions), the
[computed
value](https://drafts.csswg.org/css-cascade-5/#computed-value) of the [sizing
properties](#sizing-property), etc, as appropriate for each case.

### 3.4. New Column Sizing Values: the [stretch, [min-content](#valdef-column-width-min-content), [max-content](#valdef-column-width-max-content), and [fit-content](#valdef-column-width-fit-content) values]
Name:

[column-width](https://drafts.csswg.org/css-multicol-2/#propdef-column-width)

[Value:](https://www.w3.org/TR/css-values/#value-defs)

auto
[\|](https://drafts.csswg.org/css-values-4/#comb-one)
[\<box-size\>](#typedef-box-size)

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

as specified, with
[\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage) values computed

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value type

This section is likey to be dropped.
[\[Issue #14574\]](https://github.com/w3c/csswg-drafts/issues/14574)

When used as values for
[column-width](https://drafts.csswg.org/css-multicol-2/#propdef-column-width), the new keywords specify the
optimal column width:

[stretch]
: Specifies the optimal column width as the [stretch-fit inline
 size](#stretch-fit-inline-size) of the multi-column container.

[min-content]
: Specifies the optimal column width as the [min-content inline
 size](#min-content-inline-size) of the multi-column container's contents.

[max-content]
: Specifies the optimal column width as the [max-content inline
 size](#max-content-inline-size) of the multi-column container's contents.

[fit-content]
: Specifies the optimal column width as
 `min(`[`max-content inline size`](#max-content-inline-size)`, max(`[`min-content inline size`](#min-content-inline-size)`, `[`stretch-fit inline size`](#stretch-fit-inline-size)`))`.

 The column width never varies by column. When the
column width is informed by the multi-column container's contents (as in
the keywords above), all of its contents are taken under consideration
and the calculated width is shared by all the columns.

## 4. Extrinsic Size Determination

[Extrinsic sizing] determines sizes based on the context of an element, without
regard for its contents.

### 4.1. Percentage Sizing

Percentages specify sizing of a box with respect to the box's
[containing
block](https://drafts.csswg.org/css-display-4/#containing-block).

For example, in the following markup:

```
<article style="height: 60em">
 <figure style="height: 50%;">
 <img style="height: 50%;">
 </figure>
</article>
```

- the `<figure>` would be [30em] tall = 50% of the
 [definite](#definite) [60em]
 height of the `<article>`

- the `<img>` would be [15em] tall = 50% of the `<figure>`'s
 height (which is itself [definite](#definite) because it's a percentage resolved against a
 [definite] length)

See [§ 5.2.1 Intrinsic Contributions of Percentage-Sized
Boxes](#cyclic-percentage-contribution) for details on how to resolve
percentages when the size of the [containing
block](https://drafts.csswg.org/css-display-4/#containing-block) depends on the size of its content.

Tests

- [percentage-height-in-flexbox.html](https://wpt.fyi/results/css/css-sizing/percentage-height-in-flexbox.html "css/css-sizing/percentage-height-in-flexbox.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/percentage-height-in-flexbox.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/percentage-height-in-flexbox.html)
- [range-percent-intrinsic-size-1.html](https://wpt.fyi/results/css/css-sizing/range-percent-intrinsic-size-1.html "css/css-sizing/range-percent-intrinsic-size-1.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/range-percent-intrinsic-size-1.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/range-percent-intrinsic-size-1.html)
- [range-percent-intrinsic-size-2.html](https://wpt.fyi/results/css/css-sizing/range-percent-intrinsic-size-2.html "css/css-sizing/range-percent-intrinsic-size-2.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/range-percent-intrinsic-size-2.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/range-percent-intrinsic-size-2.html)
- [range-percent-intrinsic-size-2a.html](https://wpt.fyi/results/css/css-sizing/range-percent-intrinsic-size-2a.html "css/css-sizing/range-percent-intrinsic-size-2a.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/range-percent-intrinsic-size-2a.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/range-percent-intrinsic-size-2a.html)

### 4.2. Stretch-fit Sizing: filling the containing block

Stretch-fit sizing tries to set the box's used size to the length
necessary to make its [principal
box](https://drafts.csswg.org/css-display-4/#principal-box)'s [outer size](#outer-size) as close to filling the [containing
block](https://drafts.csswg.org/css-display-4/#containing-block) as possible while still respecting the constraints
imposed by
[min-height](#propdef-min-height)/[min-width](#propdef-min-width)/[max-height](#propdef-max-height)/[max-width](#propdef-max-width).

If used in an axis where percentage sizes can resolve to a [definite](#definite) value

: Sizes the [margin
 box](https://drafts.csswg.org/css-box-4/#margin-box) to fill the [containing
 block](https://drafts.csswg.org/css-display-4/#containing-block) exactly, treating [auto] margins as zero. (If
 this would make the [inner size](#inner-size) negative, it instead sizes the [margin
 box] so that the [inner
 size] is zero.)

 For
 [in-flow](https://drafts.csswg.org/css-display-4/#in-flow) [block-level
 boxes](https://drafts.csswg.org/css-display-4/#block-level-box) that form an [independent formatting
 context](https://drafts.csswg.org/css-display-4/#independent-formatting-context), use the space available to [line
 boxes](https://drafts.csswg.org/css-inline-3/#line-box) (i.e. excluding floats) in place of the [containing
 block](https://drafts.csswg.org/css-display-4/#containing-block)'s [inline size](#inline-size).

 For
 [in-flow](https://drafts.csswg.org/css-display-4/#in-flow) [block-level
 boxes](https://drafts.csswg.org/css-display-4/#block-level-box) when resolving the [block
 axis](https://drafts.csswg.org/css-writing-modes-4/#block-axis) size: if the ancestor element percentages resolve
 against does not have a
 [block-start](https://drafts.csswg.org/css-writing-modes-4/#block-start)
 [border](https://drafts.csswg.org/css-borders-4/#propdef-border) or
 [padding](https://drafts.csswg.org/css-box-4/#propdef-padding) and is not an [independent
 formatting
 context](https://drafts.csswg.org/css-display-4/#independent-formatting-context), treat the element's
 [block-start] margin as zero for the purpose
 of calculating this size. Do the same for the
 [block-end](https://drafts.csswg.org/css-writing-modes-4/#block-end) margin, analogously.

 This simulates the effect of margins collapsing
 with the parent's margin. It doesn't actually suppress the margins,
 so if anything prevents the element from actually collapsing with
 its parent, the [stretch-fit
 size](#stretch-fit-size)
 might actually be too large to fit in the parent perfectly.

Otherwise

: In a [preferred size
 property](#preferred-size-properties), [behaves as
 auto](#behave-as-auto). In
 a [min size
 property](#min-size-properties), behaves as [0]. In a [max size
 property](#max-size-properties), behaves as
 [none](#valdef-max-width-none).

For example, given the following HTML
representing two [block
boxes](https://drafts.csswg.org/css-display-4/#block-box):

``` html
<div class="parent">
 <div class="child">text</div>
</div>
```

In the following case, the [outer
height](#outer-size) of the child
box will exactly match the height of the parent box (200px), but its
[inner height](#inner-size) will
be 20px less, to account for its margins.

 .parent { height: 200px; border: solid; }
 .child { height: stretch; margin: 10px; }

On the other hand, in this case we can assume that the child's margins
will collapse with the parent, so the inner box will be [200px]
tall, exactly filling the parent.

 .outer { height: 200px; margin: 0; }
 .inner { height: stretch; margin: 10px; }

(The top margins will in fact collapse, but the bottom margins do not
collapse, because the bottom margin of a box is not adjoining to the
bottom margin of a parent with a
non-[auto](#valdef-width-auto) height, see [CSS 2 § 8.3.1 Collapsing
margins](https://www.w3.org/TR/CSS2/box.html#collapsing-margins).
Luckily, an overflowing bottom margin doesn't have any visible effect.)

Similarly, [width:
stretch](#propdef-width) causes the box to fill its container, being 20px
narrower than the width of \"some more text\" (due to the 10px margin):

``` html
<div class="parent">
 <div class="child">text</div>
</div>
some more text
```

 .parent { float: left; margin: 0; }
 .child { width: stretch; margin: 10px; }

On the other hand, in this example the
container's height is indefinite, which would cause a percentage height
on the child to [behave as
auto](#behave-as-auto), so
[height: stretch](#propdef-height) [behaves as auto] as
well.

 .parent { height: auto; margin: 0; }
 .child { height: stretch; margin: 10px; }

- [abspos-1.html](https://wpt.fyi/results/css/css-sizing/stretch/abspos-1.html "css/css-sizing/stretch/abspos-1.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/stretch/abspos-1.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/stretch/abspos-1.html)
- [abspos-2.html](https://wpt.fyi/results/css/css-sizing/stretch/abspos-2.html "css/css-sizing/stretch/abspos-2.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/stretch/abspos-2.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/stretch/abspos-2.html)
- [aspect-ratio-1.html](https://wpt.fyi/results/css/css-sizing/stretch/aspect-ratio-1.html "css/css-sizing/stretch/aspect-ratio-1.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/stretch/aspect-ratio-1.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/stretch/aspect-ratio-1.html)
- [aspect-ratio-2.html](https://wpt.fyi/results/css/css-sizing/stretch/aspect-ratio-2.html "css/css-sizing/stretch/aspect-ratio-2.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/stretch/aspect-ratio-2.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/stretch/aspect-ratio-2.html)
- [auto-margins-1.html](https://wpt.fyi/results/css/css-sizing/stretch/auto-margins-1.html "css/css-sizing/stretch/auto-margins-1.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/stretch/auto-margins-1.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/stretch/auto-margins-1.html)
- [auto-margins-2.html](https://wpt.fyi/results/css/css-sizing/stretch/auto-margins-2.html "css/css-sizing/stretch/auto-margins-2.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/stretch/auto-margins-2.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/stretch/auto-margins-2.html)
- [bfc-next-to-float-1.html](https://wpt.fyi/results/css/css-sizing/stretch/bfc-next-to-float-1.html "css/css-sizing/stretch/bfc-next-to-float-1.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/stretch/bfc-next-to-float-1.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/stretch/bfc-next-to-float-1.html)
- [bfc-next-to-float-2.html](https://wpt.fyi/results/css/css-sizing/stretch/bfc-next-to-float-2.html "css/css-sizing/stretch/bfc-next-to-float-2.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/stretch/bfc-next-to-float-2.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/stretch/bfc-next-to-float-2.html)
- [block-height-002.html](https://wpt.fyi/results/css/css-sizing/stretch/block-height-002.html "css/css-sizing/stretch/block-height-002.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/stretch/block-height-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/stretch/block-height-002.html)
- [block-height-003.html](https://wpt.fyi/results/css/css-sizing/stretch/block-height-003.html "css/css-sizing/stretch/block-height-003.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/stretch/block-height-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/stretch/block-height-003.html)
- [block-height-004.html](https://wpt.fyi/results/css/css-sizing/stretch/block-height-004.html "css/css-sizing/stretch/block-height-004.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/stretch/block-height-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/stretch/block-height-004.html)
- [block-height-005.html](https://wpt.fyi/results/css/css-sizing/stretch/block-height-005.html "css/css-sizing/stretch/block-height-005.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/stretch/block-height-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/stretch/block-height-005.html)
- [block-height-006.html](https://wpt.fyi/results/css/css-sizing/stretch/block-height-006.html "css/css-sizing/stretch/block-height-006.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/stretch/block-height-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/stretch/block-height-006.html)
- [block-height-007.html](https://wpt.fyi/results/css/css-sizing/stretch/block-height-007.html "css/css-sizing/stretch/block-height-007.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/stretch/block-height-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/stretch/block-height-007.html)
- [block-height-008.html](https://wpt.fyi/results/css/css-sizing/stretch/block-height-008.html "css/css-sizing/stretch/block-height-008.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/stretch/block-height-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/stretch/block-height-008.html)
- [block-height-009.html](https://wpt.fyi/results/css/css-sizing/stretch/block-height-009.html "css/css-sizing/stretch/block-height-009.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/stretch/block-height-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/stretch/block-height-009.html)
- [block-height-010.html](https://wpt.fyi/results/css/css-sizing/stretch/block-height-010.html "css/css-sizing/stretch/block-height-010.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/stretch/block-height-010.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/stretch/block-height-010.html)
- [cache-miss-001.html](https://wpt.fyi/results/css/css-sizing/stretch/cache-miss-001.html "css/css-sizing/stretch/cache-miss-001.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/stretch/cache-miss-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/stretch/cache-miss-001.html)
- [cache-miss-002.html](https://wpt.fyi/results/css/css-sizing/stretch/cache-miss-002.html "css/css-sizing/stretch/cache-miss-002.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/stretch/cache-miss-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/stretch/cache-miss-002.html)
- [content-contribution-001.html](https://wpt.fyi/results/css/css-sizing/stretch/content-contribution-001.html "css/css-sizing/stretch/content-contribution-001.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/stretch/content-contribution-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/stretch/content-contribution-001.html)
- [fixed-table-1.html](https://wpt.fyi/results/css/css-sizing/stretch/fixed-table-1.html "css/css-sizing/stretch/fixed-table-1.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/stretch/fixed-table-1.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/stretch/fixed-table-1.html)
- [flex-basis-1.html](https://wpt.fyi/results/css/css-sizing/stretch/flex-basis-1.html "css/css-sizing/stretch/flex-basis-1.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/stretch/flex-basis-1.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/stretch/flex-basis-1.html)
- [flexbox-auto-minimum-001.html](https://wpt.fyi/results/css/css-sizing/stretch/flexbox-auto-minimum-001.html "css/css-sizing/stretch/flexbox-auto-minimum-001.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/stretch/flexbox-auto-minimum-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/stretch/flexbox-auto-minimum-001.html)
- [flexbox-auto-minimum-002.html](https://wpt.fyi/results/css/css-sizing/stretch/flexbox-auto-minimum-002.html "css/css-sizing/stretch/flexbox-auto-minimum-002.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/stretch/flexbox-auto-minimum-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/stretch/flexbox-auto-minimum-002.html)
- [flexbox-flex-base-size-001.html](https://wpt.fyi/results/css/css-sizing/stretch/flexbox-flex-base-size-001.html "css/css-sizing/stretch/flexbox-flex-base-size-001.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/stretch/flexbox-flex-base-size-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/stretch/flexbox-flex-base-size-001.html)
- [flexbox-flex-base-size-002.html](https://wpt.fyi/results/css/css-sizing/stretch/flexbox-flex-base-size-002.html "css/css-sizing/stretch/flexbox-flex-base-size-002.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/stretch/flexbox-flex-base-size-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/stretch/flexbox-flex-base-size-002.html)
- [flexbox-stretch-minimum-001.html](https://wpt.fyi/results/css/css-sizing/stretch/flexbox-stretch-minimum-001.html "css/css-sizing/stretch/flexbox-stretch-minimum-001.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/stretch/flexbox-stretch-minimum-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/stretch/flexbox-stretch-minimum-001.html)
- [flexbox-stretch-minimum-002.html](https://wpt.fyi/results/css/css-sizing/stretch/flexbox-stretch-minimum-002.html "css/css-sizing/stretch/flexbox-stretch-minimum-002.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/stretch/flexbox-stretch-minimum-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/stretch/flexbox-stretch-minimum-002.html)
- [indefinite-1.html](https://wpt.fyi/results/css/css-sizing/stretch/indefinite-1.html "css/css-sizing/stretch/indefinite-1.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/stretch/indefinite-1.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/stretch/indefinite-1.html)
- [indefinite-2.html](https://wpt.fyi/results/css/css-sizing/stretch/indefinite-2.html "css/css-sizing/stretch/indefinite-2.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/stretch/indefinite-2.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/stretch/indefinite-2.html)
- [indefinite-3.html](https://wpt.fyi/results/css/css-sizing/stretch/indefinite-3.html "css/css-sizing/stretch/indefinite-3.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/stretch/indefinite-3.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/stretch/indefinite-3.html)
- [indefinite-4.html](https://wpt.fyi/results/css/css-sizing/stretch/indefinite-4.html "css/css-sizing/stretch/indefinite-4.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/stretch/indefinite-4.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/stretch/indefinite-4.html)
- [replaced-next-to-float-1.html](https://wpt.fyi/results/css/css-sizing/stretch/replaced-next-to-float-1.html "css/css-sizing/stretch/replaced-next-to-float-1.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/stretch/replaced-next-to-float-1.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/stretch/replaced-next-to-float-1.html)
- [replaced-next-to-float-2.html](https://wpt.fyi/results/css/css-sizing/stretch/replaced-next-to-float-2.html "css/css-sizing/stretch/replaced-next-to-float-2.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/stretch/replaced-next-to-float-2.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/stretch/replaced-next-to-float-2.html)
- [stretch-table-001.html](https://wpt.fyi/results/css/css-sizing/stretch/stretch-table-001.html "css/css-sizing/stretch/stretch-table-001.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/stretch/stretch-table-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/stretch/stretch-table-001.html)

 The [stretch-fit
size](#stretch-fit-size) is
usually, but not always, equivalent to
[stretch](https://drafts.csswg.org/css-align-3/#valdef-align-self-stretch)
[self-alignment](https://drafts.csswg.org/css-align-3/#self-align). For example, in
[multi-line](https://drafts.csswg.org/css-flexbox-2/#multi-line-flex-container) [flex
layout](https://drafts.csswg.org/css-flexbox-2/#flex-layout), the [stretch-fit size]
resolves against the [containing
block](https://drafts.csswg.org/css-display-4/#containing-block) directly, and contributes that size to the [cross
size](https://drafts.csswg.org/css-flexbox-2/#cross-size) of the line---​whereas
[stretch] contributes the
[fit-content size](#fit-content-size)---​before finally resolving against the [cross
size] of the line.

## 5. Intrinsic Size Determination

[Intrinsic sizing] determines sizes based on the contents of an element, without
regard for its context.

Tests

- [canvas-intrinsic-dynamic.html](https://wpt.fyi/results/css/css-sizing/canvas-intrinsic-dynamic.html "css/css-sizing/canvas-intrinsic-dynamic.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/canvas-intrinsic-dynamic.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/canvas-intrinsic-dynamic.html)
- [intrinsic-percent-replaced-dynamic-001.html](https://wpt.fyi/results/css/css-sizing/intrinsic-percent-replaced-dynamic-001.html "css/css-sizing/intrinsic-percent-replaced-dynamic-001.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/intrinsic-percent-replaced-dynamic-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/intrinsic-percent-replaced-dynamic-001.html)
- [intrinsic-percent-replaced-dynamic-002.html](https://wpt.fyi/results/css/css-sizing/intrinsic-percent-replaced-dynamic-002.html "css/css-sizing/intrinsic-percent-replaced-dynamic-002.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/intrinsic-percent-replaced-dynamic-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/intrinsic-percent-replaced-dynamic-002.html)
- [intrinsic-percent-replaced-dynamic-003.html](https://wpt.fyi/results/css/css-sizing/intrinsic-percent-replaced-dynamic-003.html "css/css-sizing/intrinsic-percent-replaced-dynamic-003.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/intrinsic-percent-replaced-dynamic-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/intrinsic-percent-replaced-dynamic-003.html)
- [intrinsic-percent-replaced-dynamic-004.html](https://wpt.fyi/results/css/css-sizing/intrinsic-percent-replaced-dynamic-004.html "css/css-sizing/intrinsic-percent-replaced-dynamic-004.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/intrinsic-percent-replaced-dynamic-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/intrinsic-percent-replaced-dynamic-004.html)
- [intrinsic-percent-replaced-dynamic-005.html](https://wpt.fyi/results/css/css-sizing/intrinsic-percent-replaced-dynamic-005.html "css/css-sizing/intrinsic-percent-replaced-dynamic-005.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/intrinsic-percent-replaced-dynamic-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/intrinsic-percent-replaced-dynamic-005.html)
- [intrinsic-percent-replaced-dynamic-006.html](https://wpt.fyi/results/css/css-sizing/intrinsic-percent-replaced-dynamic-006.html "css/css-sizing/intrinsic-percent-replaced-dynamic-006.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/intrinsic-percent-replaced-dynamic-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/intrinsic-percent-replaced-dynamic-006.html)
- [intrinsic-percent-replaced-dynamic-007.html](https://wpt.fyi/results/css/css-sizing/intrinsic-percent-replaced-dynamic-007.html "css/css-sizing/intrinsic-percent-replaced-dynamic-007.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/intrinsic-percent-replaced-dynamic-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/intrinsic-percent-replaced-dynamic-007.html)
- [intrinsic-percent-replaced-dynamic-008.html](https://wpt.fyi/results/css/css-sizing/intrinsic-percent-replaced-dynamic-008.html "css/css-sizing/intrinsic-percent-replaced-dynamic-008.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/intrinsic-percent-replaced-dynamic-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/intrinsic-percent-replaced-dynamic-008.html)
- [intrinsic-percent-replaced-dynamic-009.html](https://wpt.fyi/results/css/css-sizing/intrinsic-percent-replaced-dynamic-009.html "css/css-sizing/intrinsic-percent-replaced-dynamic-009.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/intrinsic-percent-replaced-dynamic-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/intrinsic-percent-replaced-dynamic-009.html)
- [intrinsic-percent-replaced-dynamic-010.html](https://wpt.fyi/results/css/css-sizing/intrinsic-percent-replaced-dynamic-010.html "css/css-sizing/intrinsic-percent-replaced-dynamic-010.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/intrinsic-percent-replaced-dynamic-010.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/intrinsic-percent-replaced-dynamic-010.html)
- [intrinsic-percent-replaced-dynamic-011.html](https://wpt.fyi/results/css/css-sizing/intrinsic-percent-replaced-dynamic-011.html "css/css-sizing/intrinsic-percent-replaced-dynamic-011.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/intrinsic-percent-replaced-dynamic-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/intrinsic-percent-replaced-dynamic-011.html)
- [intrinsic-percent-replaced-dynamic-012.html](https://wpt.fyi/results/css/css-sizing/intrinsic-percent-replaced-dynamic-012.html "css/css-sizing/intrinsic-percent-replaced-dynamic-012.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/intrinsic-percent-replaced-dynamic-012.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/intrinsic-percent-replaced-dynamic-012.html)
- [intrinsic-ratio-replaced-box-sizing.html](https://wpt.fyi/results/css/css-sizing/intrinsic-ratio-replaced-box-sizing.html "css/css-sizing/intrinsic-ratio-replaced-box-sizing.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/intrinsic-ratio-replaced-box-sizing.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/intrinsic-ratio-replaced-box-sizing.html)
- [intrinsic-size-fallback-replaced.html](https://wpt.fyi/results/css/css-sizing/intrinsic-size-fallback-replaced.html "css/css-sizing/intrinsic-size-fallback-replaced.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/intrinsic-size-fallback-replaced.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/intrinsic-size-fallback-replaced.html)

### 5.1. Intrinsic Sizes

The [min-content size](#min-content) of a box in each axis is the size it would have if it
was a float given an
[auto](#valdef-width-auto) [preferred
size](#preferred-size) in that
axis (and no [minimum](#min-width)
or [maximum size](#max-width) in
that axis) and if its containing block was *zero*-sized in that axis.
(In other words, the minimum size it has when sized as "shrink-to-fit".)

The [max-content size](#max-content) of a box in each axis is the size it would have if it
was a float given an
[auto](#valdef-width-auto) [preferred
size](#preferred-size) in that
axis (and no [minimum](#min-width)
or [maximum size](#max-width) in
that axis), and if its containing block was *infinitely*-sized in that
axis. (In other words, the maximum size it has when sized as
"shrink-to-fit".)

The [min-content size](#min-content) and [max-content
size](#max-content) are
collectively referred to as the [intrinsic
sizes](#intrinsic-size).

 When the box has a [preferred aspect
ratio](#preferred-aspect-ratio), size constraints in the opposite dimension will
transfer through and can affect the
[auto](#valdef-width-auto) size in the considered one. See
[CSS2§10](https://www.w3.org/TR/CSS2/visudet.html).

This specification does not define how to determine the sizes of floats.
Please refer to
[\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification").
However, the [intrinsic sizes](#intrinsic-size) of [replaced
elements](https://drafts.csswg.org/css-display-4/#replaced-element) without [natural
sizes](https://drafts.csswg.org/css-images-3/#natural-size) are defined below:

If it has a non-degenerate [preferred aspect ratio](#preferred-aspect-ratio):

: For the [min-content size](#min-content), use zero.

 For the [max-content size](#max-content):

 - If the [available space](#available) is [definite](#definite) in the [inline
 axis](https://drafts.csswg.org/css-writing-modes-4/#inline-axis), use the [stretch
 fit](#stretch-fit) into
 that size for the inline size and calculate the block size using
 the aspect ratio.

 - Otherwise if the box has a
 [\<length\>](https://drafts.csswg.org/css-values-4/#length-value) as its [computed
 value](https://drafts.csswg.org/css-cascade-5/#computed-value) for
 [min-width](#propdef-min-width) or
 [min-height](#propdef-min-height), use that size and calculate
 the other dimension using the aspect ratio; if both dimensions
 have a [\<length\>] minimum,
 choose the one that results in the larger overall size.

 This case was previous calculated from a 300x150
 default size, rather than the box's min size. This is believed to
 be a better behavior, and likely to be Web-compatible, but please
 send feedback to the CSSWG if there are any problems.

 Tests

 - [replaced-fractional-height-from-aspect-ratio-2.html](https://wpt.fyi/results/css/css-sizing/replaced-fractional-height-from-aspect-ratio-2.html "css/css-sizing/replaced-fractional-height-from-aspect-ratio-2.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/replaced-fractional-height-from-aspect-ratio-2.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/replaced-fractional-height-from-aspect-ratio-2.html)

 - Otherwise use an [inline size](#inline-size) matching the corresponding dimension of the
 [initial containing
 block](https://drafts.csswg.org/css-display-4/#initial-containing-block) and calculate the other dimension using the
 aspect ratio.

If it has no [preferred aspect ratio](#preferred-aspect-ratio):
: For both the [min-content size](#min-content) and [max-content
 size](#max-content):
 - If the box has a
 [\<length\>](https://drafts.csswg.org/css-values-4/#length-value) as its
 [computed](https://drafts.csswg.org/css-cascade-5/#computed-value) [minimum size](#min-width)
 ([min-width](#propdef-min-width)/[min-height](#propdef-min-height)) in that dimension, use that
 size.

 This author-controllable behavior is made
 possible by the new
 [auto](#valdef-width-auto) value for the [min size
 properties](#min-size-properties). This is believed to be a better behavior, but it
 is not yet clear if it is Web-compatible, so please send feedback
 to the CSSWG if there are any problems.

 - Otherwise, use [300px] for the width and/or [150px]
 for the height as needed.

 This does not imply an aspect ratio.

Since a block-level or inline-level replaced element whose
[height](#propdef-height) or
[width](#propdef-width) [behaves as
auto](#behave-as-auto) is
effectively defined to use its [max-content
size](#max-content)
([CSS2§10.3.2](https://www.w3.org/TR/CSS2/visudet.html#inline-replaced-width)),
this specification applies the rules above to the undefined case of a
replaced element whose [height] and
[width] both [behave as
auto].

 This specification does not define how to determine the
size of a float. Please refer to
[\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification"),
the relevant CSS specification for that display type, and/or existing
implementations for further details. A future specification will define
this in detail, replacing the CSS2 "definition", such as it is.

------------------------------------------------------------------------

Although the [auto](#valdef-width-auto) size of text input controls such as HTML's
`<input type=text>` and `<textarea>` elements is typically a fixed size,
the contents of such elements can be used to determine a content-based
[intrinsic size](#intrinsic-size), as for non-replaced block containers. The
[min-content](#valdef-width-min-content) and
[max-content](#valdef-width-max-content) keywords of the [sizing
properties](#sizing-property)
thus represent content-based sizes for form controls which render their
value as text contained within their box, allowing such controls to size
to fit their visible contents similarly to regular non-replaced
elements.

The content in this case is defined to be the input control's values
(the [raw
value](https://html.spec.whatwg.org/multipage/form-elements.html#concept-textarea-raw-value) in the case of
[`textarea`](https://html.spec.whatwg.org/multipage/form-elements.html#the-textarea-element), or the
[value](https://html.spec.whatwg.org/multipage/form-control-infrastructure.html#concept-fe-value)
in the case of
[`input`](https://html.spec.whatwg.org/multipage/input.html#the-input-element)), possibly transformed to a more human-readable
and/or localized display format, which is then treated as child [text
sequences](https://drafts.csswg.org/css-display-4/#css-text-sequence) of the input control, allowing [soft wrap
opportunities](https://drafts.csswg.org/css-text-4/#soft-wrap-opportunity) only where the input control would actually allow
wrapping (whether keyed off of CSS properties or other, UA-internal
constraints). If the input control has designated placeholder text to be
overlaid in its value display area, then that text is also measured for
the purpose of calculating the content-based size---​whether or not the
placeholder text is visible at the moment. (Thus the content-based
[intrinsic size](#intrinsic-size) of the input control is the larger of the size to fit
the placeholder text and the size to fit the value.)

The UA may enforce a minimum (such as the size required to contain a
single zero-width character, or the smallest usable size of a touch
target) on the form control's
[min-content](#min-content) and
[max-content sizes](#max-content) to ensure sufficient space for the caret and otherwise
maintain usability of the form control.

 This might be extended to
[`iframe`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-iframe-element) or other content-containing replaced elements (see
[discussion](https://github.com/w3c/csswg-drafts/issues/1771)), but text
inputs are a major use-case; and being document-internal, have the least
additional complications.

Tests

- [aspect-ratio-affects-container-width-when-height-changes.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio-affects-container-width-when-height-changes.html "css/css-sizing/aspect-ratio-affects-container-width-when-height-changes.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio-affects-container-width-when-height-changes.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio-affects-container-width-when-height-changes.html)
- [calc-margins-block.html](https://wpt.fyi/results/css/css-sizing/calc-margins-block.html "css/css-sizing/calc-margins-block.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/calc-margins-block.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/calc-margins-block.html)
- [calc-margins-fieldset-content.html](https://wpt.fyi/results/css/css-sizing/calc-margins-fieldset-content.html "css/css-sizing/calc-margins-fieldset-content.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/calc-margins-fieldset-content.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/calc-margins-fieldset-content.html)
- [calc-margins-fieldset-legend.html](https://wpt.fyi/results/css/css-sizing/calc-margins-fieldset-legend.html "css/css-sizing/calc-margins-fieldset-legend.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/calc-margins-fieldset-legend.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/calc-margins-fieldset-legend.html)
- [calc-margins-flex.html](https://wpt.fyi/results/css/css-sizing/calc-margins-flex.html "css/css-sizing/calc-margins-flex.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/calc-margins-flex.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/calc-margins-flex.html)
- [calc-margins-table-caption.html](https://wpt.fyi/results/css/css-sizing/calc-margins-table-caption.html "css/css-sizing/calc-margins-table-caption.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/calc-margins-table-caption.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/calc-margins-table-caption.html)
- [image-fractional-height-with-wide-aspect-ratio.html](https://wpt.fyi/results/css/css-sizing/image-fractional-height-with-wide-aspect-ratio.html "css/css-sizing/image-fractional-height-with-wide-aspect-ratio.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/image-fractional-height-with-wide-aspect-ratio.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/image-fractional-height-with-wide-aspect-ratio.html)
- [intrinsic-fixed-width-with-max-content-height.html](https://wpt.fyi/results/css/css-sizing/intrinsic-fixed-width-with-max-content-height.html "css/css-sizing/intrinsic-fixed-width-with-max-content-height.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/intrinsic-fixed-width-with-max-content-height.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/intrinsic-fixed-width-with-max-content-height.html)
- [intrinsic-fixed-width-with-min-content-height.html](https://wpt.fyi/results/css/css-sizing/intrinsic-fixed-width-with-min-content-height.html "css/css-sizing/intrinsic-fixed-width-with-min-content-height.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/intrinsic-fixed-width-with-min-content-height.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/intrinsic-fixed-width-with-min-content-height.html)
- [intrinsic-percent-replaced-001.html](https://wpt.fyi/results/css/css-sizing/intrinsic-percent-replaced-001.html "css/css-sizing/intrinsic-percent-replaced-001.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/intrinsic-percent-replaced-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/intrinsic-percent-replaced-001.html)
- [intrinsic-percent-replaced-002.html](https://wpt.fyi/results/css/css-sizing/intrinsic-percent-replaced-002.html "css/css-sizing/intrinsic-percent-replaced-002.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/intrinsic-percent-replaced-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/intrinsic-percent-replaced-002.html)
- [intrinsic-percent-replaced-003.html](https://wpt.fyi/results/css/css-sizing/intrinsic-percent-replaced-003.html "css/css-sizing/intrinsic-percent-replaced-003.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/intrinsic-percent-replaced-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/intrinsic-percent-replaced-003.html)
- [intrinsic-percent-replaced-004.html](https://wpt.fyi/results/css/css-sizing/intrinsic-percent-replaced-004.html "css/css-sizing/intrinsic-percent-replaced-004.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/intrinsic-percent-replaced-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/intrinsic-percent-replaced-004.html)
- [intrinsic-percent-replaced-005.html](https://wpt.fyi/results/css/css-sizing/intrinsic-percent-replaced-005.html "css/css-sizing/intrinsic-percent-replaced-005.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/intrinsic-percent-replaced-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/intrinsic-percent-replaced-005.html)
- [intrinsic-percent-replaced-006.html](https://wpt.fyi/results/css/css-sizing/intrinsic-percent-replaced-006.html "css/css-sizing/intrinsic-percent-replaced-006.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/intrinsic-percent-replaced-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/intrinsic-percent-replaced-006.html)
- [intrinsic-percent-replaced-007.html](https://wpt.fyi/results/css/css-sizing/intrinsic-percent-replaced-007.html "css/css-sizing/intrinsic-percent-replaced-007.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/intrinsic-percent-replaced-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/intrinsic-percent-replaced-007.html)
- [intrinsic-percent-replaced-008.html](https://wpt.fyi/results/css/css-sizing/intrinsic-percent-replaced-008.html "css/css-sizing/intrinsic-percent-replaced-008.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/intrinsic-percent-replaced-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/intrinsic-percent-replaced-008.html)
- [intrinsic-percent-replaced-009.html](https://wpt.fyi/results/css/css-sizing/intrinsic-percent-replaced-009.html "css/css-sizing/intrinsic-percent-replaced-009.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/intrinsic-percent-replaced-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/intrinsic-percent-replaced-009.html)
- [intrinsic-percent-replaced-010.html](https://wpt.fyi/results/css/css-sizing/intrinsic-percent-replaced-010.html "css/css-sizing/intrinsic-percent-replaced-010.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/intrinsic-percent-replaced-010.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/intrinsic-percent-replaced-010.html)
- [intrinsic-percent-replaced-011.html](https://wpt.fyi/results/css/css-sizing/intrinsic-percent-replaced-011.html "css/css-sizing/intrinsic-percent-replaced-011.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/intrinsic-percent-replaced-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/intrinsic-percent-replaced-011.html)
- [intrinsic-percent-replaced-012.html](https://wpt.fyi/results/css/css-sizing/intrinsic-percent-replaced-012.html "css/css-sizing/intrinsic-percent-replaced-012.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/intrinsic-percent-replaced-012.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/intrinsic-percent-replaced-012.html)
- [intrinsic-percent-replaced-013.html](https://wpt.fyi/results/css/css-sizing/intrinsic-percent-replaced-013.html "css/css-sizing/intrinsic-percent-replaced-013.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/intrinsic-percent-replaced-013.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/intrinsic-percent-replaced-013.html)
- [intrinsic-percent-replaced-014.html](https://wpt.fyi/results/css/css-sizing/intrinsic-percent-replaced-014.html "css/css-sizing/intrinsic-percent-replaced-014.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/intrinsic-percent-replaced-014.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/intrinsic-percent-replaced-014.html)
- [intrinsic-percent-replaced-015.html](https://wpt.fyi/results/css/css-sizing/intrinsic-percent-replaced-015.html "css/css-sizing/intrinsic-percent-replaced-015.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/intrinsic-percent-replaced-015.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/intrinsic-percent-replaced-015.html)
- [intrinsic-percent-replaced-016.html](https://wpt.fyi/results/css/css-sizing/intrinsic-percent-replaced-016.html "css/css-sizing/intrinsic-percent-replaced-016.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/intrinsic-percent-replaced-016.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/intrinsic-percent-replaced-016.html)
- [intrinsic-percent-replaced-017.html](https://wpt.fyi/results/css/css-sizing/intrinsic-percent-replaced-017.html "css/css-sizing/intrinsic-percent-replaced-017.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/intrinsic-percent-replaced-017.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/intrinsic-percent-replaced-017.html)
- [intrinsic-percent-replaced-018.html](https://wpt.fyi/results/css/css-sizing/intrinsic-percent-replaced-018.html "css/css-sizing/intrinsic-percent-replaced-018.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/intrinsic-percent-replaced-018.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/intrinsic-percent-replaced-018.html)
- [intrinsic-percent-replaced-019.html](https://wpt.fyi/results/css/css-sizing/intrinsic-percent-replaced-019.html "css/css-sizing/intrinsic-percent-replaced-019.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/intrinsic-percent-replaced-019.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/intrinsic-percent-replaced-019.html)
- [intrinsic-percent-replaced-020.html](https://wpt.fyi/results/css/css-sizing/intrinsic-percent-replaced-020.html "css/css-sizing/intrinsic-percent-replaced-020.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/intrinsic-percent-replaced-020.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/intrinsic-percent-replaced-020.html)
- [intrinsic-percent-replaced-021.html](https://wpt.fyi/results/css/css-sizing/intrinsic-percent-replaced-021.html "css/css-sizing/intrinsic-percent-replaced-021.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/intrinsic-percent-replaced-021.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/intrinsic-percent-replaced-021.html)
- [intrinsic-percent-replaced-022.html](https://wpt.fyi/results/css/css-sizing/intrinsic-percent-replaced-022.html "css/css-sizing/intrinsic-percent-replaced-022.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/intrinsic-percent-replaced-022.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/intrinsic-percent-replaced-022.html)
- [intrinsic-percent-replaced-023.html](https://wpt.fyi/results/css/css-sizing/intrinsic-percent-replaced-023.html "css/css-sizing/intrinsic-percent-replaced-023.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/intrinsic-percent-replaced-023.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/intrinsic-percent-replaced-023.html)
- [intrinsic-percent-replaced-024.html](https://wpt.fyi/results/css/css-sizing/intrinsic-percent-replaced-024.html "css/css-sizing/intrinsic-percent-replaced-024.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/intrinsic-percent-replaced-024.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/intrinsic-percent-replaced-024.html)
- [intrinsic-percent-replaced-025.html](https://wpt.fyi/results/css/css-sizing/intrinsic-percent-replaced-025.html "css/css-sizing/intrinsic-percent-replaced-025.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/intrinsic-percent-replaced-025.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/intrinsic-percent-replaced-025.html)
- [intrinsic-percent-replaced-026.html](https://wpt.fyi/results/css/css-sizing/intrinsic-percent-replaced-026.html "css/css-sizing/intrinsic-percent-replaced-026.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/intrinsic-percent-replaced-026.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/intrinsic-percent-replaced-026.html)
- [intrinsic-percent-replaced-027.html](https://wpt.fyi/results/css/css-sizing/intrinsic-percent-replaced-027.html "css/css-sizing/intrinsic-percent-replaced-027.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/intrinsic-percent-replaced-027.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/intrinsic-percent-replaced-027.html)
- [intrinsic-size-fallback-video.html](https://wpt.fyi/results/css/css-sizing/intrinsic-size-fallback-video.html "css/css-sizing/intrinsic-size-fallback-video.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/intrinsic-size-fallback-video.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/intrinsic-size-fallback-video.html)
- [max-content-input-001.html](https://wpt.fyi/results/css/css-sizing/max-content-input-001.html "css/css-sizing/max-content-input-001.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/max-content-input-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/max-content-input-001.html)
- [ortho-writing-mode-001.html](https://wpt.fyi/results/css/css-sizing/ortho-writing-mode-001.html "css/css-sizing/ortho-writing-mode-001.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/ortho-writing-mode-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/ortho-writing-mode-001.html)
- [orthogonal-writing-mode-float-in-inline.html](https://wpt.fyi/results/css/css-sizing/orthogonal-writing-mode-float-in-inline.html "css/css-sizing/orthogonal-writing-mode-float-in-inline.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/orthogonal-writing-mode-float-in-inline.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/orthogonal-writing-mode-float-in-inline.html)
- [replaced-aspect-ratio-intrinsic-size-001.html](https://wpt.fyi/results/css/css-sizing/replaced-aspect-ratio-intrinsic-size-001.html "css/css-sizing/replaced-aspect-ratio-intrinsic-size-001.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/replaced-aspect-ratio-intrinsic-size-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/replaced-aspect-ratio-intrinsic-size-001.html)
- [replaced-aspect-ratio-intrinsic-size-002.html](https://wpt.fyi/results/css/css-sizing/replaced-aspect-ratio-intrinsic-size-002.html "css/css-sizing/replaced-aspect-ratio-intrinsic-size-002.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/replaced-aspect-ratio-intrinsic-size-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/replaced-aspect-ratio-intrinsic-size-002.html)
- [replaced-aspect-ratio-stretch-fit-001.html](https://wpt.fyi/results/css/css-sizing/replaced-aspect-ratio-stretch-fit-001.html "css/css-sizing/replaced-aspect-ratio-stretch-fit-001.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/replaced-aspect-ratio-stretch-fit-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/replaced-aspect-ratio-stretch-fit-001.html)
- [replaced-aspect-ratio-stretch-fit-002.html](https://wpt.fyi/results/css/css-sizing/replaced-aspect-ratio-stretch-fit-002.html "css/css-sizing/replaced-aspect-ratio-stretch-fit-002.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/replaced-aspect-ratio-stretch-fit-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/replaced-aspect-ratio-stretch-fit-002.html)
- [replaced-aspect-ratio-stretch-fit-003.html](https://wpt.fyi/results/css/css-sizing/replaced-aspect-ratio-stretch-fit-003.html "css/css-sizing/replaced-aspect-ratio-stretch-fit-003.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/replaced-aspect-ratio-stretch-fit-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/replaced-aspect-ratio-stretch-fit-003.html)
- [svg-intrinsic-size-001.html](https://wpt.fyi/results/css/css-sizing/svg-intrinsic-size-001.html "css/css-sizing/svg-intrinsic-size-001.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/svg-intrinsic-size-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/svg-intrinsic-size-001.html)
- [svg-intrinsic-size-002.html](https://wpt.fyi/results/css/css-sizing/svg-intrinsic-size-002.html "css/css-sizing/svg-intrinsic-size-002.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/svg-intrinsic-size-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/svg-intrinsic-size-002.html)
- [svg-intrinsic-size-003.html](https://wpt.fyi/results/css/css-sizing/svg-intrinsic-size-003.html "css/css-sizing/svg-intrinsic-size-003.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/svg-intrinsic-size-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/svg-intrinsic-size-003.html)
- [svg-intrinsic-size-004.html](https://wpt.fyi/results/css/css-sizing/svg-intrinsic-size-004.html "css/css-sizing/svg-intrinsic-size-004.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/svg-intrinsic-size-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/svg-intrinsic-size-004.html)
- [svg-intrinsic-size-005.html](https://wpt.fyi/results/css/css-sizing/svg-intrinsic-size-005.html "css/css-sizing/svg-intrinsic-size-005.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/svg-intrinsic-size-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/svg-intrinsic-size-005.html)
- [svg-intrinsic-size-006.html](https://wpt.fyi/results/css/css-sizing/svg-intrinsic-size-006.html "css/css-sizing/svg-intrinsic-size-006.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/svg-intrinsic-size-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/svg-intrinsic-size-006.html)
- [whitespace-and-break.html](https://wpt.fyi/results/css/css-sizing/whitespace-and-break.html "css/css-sizing/whitespace-and-break.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/whitespace-and-break.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/whitespace-and-break.html)

### 5.2. Intrinsic Contributions

A box's [min-content
contribution](#min-content-contribution)/[max-content
contribution](#max-content-contribution) in each axis is the size of the content box of a
hypothetical [auto](#valdef-width-auto)-sized float that contains only that box, if that
hypothetical float's containing block is zero-sized/infinitely-sized.

 This specification does not define precisely how to
determine these sizes. Please refer to
[\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification"),
the relevant CSS specification for that display type, the [rules for
handling percentages](#percentage-sizing) (below), and/or existing
implementations for further details.

Tests

- [intrinsic-percent-non-replaced-001.html](https://wpt.fyi/results/css/css-sizing/intrinsic-percent-non-replaced-001.html "css/css-sizing/intrinsic-percent-non-replaced-001.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/intrinsic-percent-non-replaced-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/intrinsic-percent-non-replaced-001.html)
- [intrinsic-percent-non-replaced-002.html](https://wpt.fyi/results/css/css-sizing/intrinsic-percent-non-replaced-002.html "css/css-sizing/intrinsic-percent-non-replaced-002.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/intrinsic-percent-non-replaced-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/intrinsic-percent-non-replaced-002.html)
- [intrinsic-percent-non-replaced-003.html](https://wpt.fyi/results/css/css-sizing/intrinsic-percent-non-replaced-003.html "css/css-sizing/intrinsic-percent-non-replaced-003.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/intrinsic-percent-non-replaced-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/intrinsic-percent-non-replaced-003.html)
- [intrinsic-percent-non-replaced-004.html](https://wpt.fyi/results/css/css-sizing/intrinsic-percent-non-replaced-004.html "css/css-sizing/intrinsic-percent-non-replaced-004.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/intrinsic-percent-non-replaced-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/intrinsic-percent-non-replaced-004.html)
- [intrinsic-percent-non-replaced-005.html](https://wpt.fyi/results/css/css-sizing/intrinsic-percent-non-replaced-005.html "css/css-sizing/intrinsic-percent-non-replaced-005.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/intrinsic-percent-non-replaced-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/intrinsic-percent-non-replaced-005.html)

For this purpose,
[stretch](https://drafts.csswg.org/css-align-3/#valdef-align-self-stretch)
[self-alignment](https://drafts.csswg.org/css-align-3/#self-align) and [stretch-fit
sizing](#stretch-fit-size)
(when they are able to resolve extrinsically) are considered definite
the same way as resolveable percentages.

#### 5.2.1. Intrinsic Contributions of Percentage-Sized Boxes

Sometimes the size of a percentage-sized box's [containing
block](https://drafts.csswg.org/css-display-4/#containing-block) depends on the [intrinsic size
contribution](#intrinsic-size-contribution) of the box itself, creating a cyclic dependency. When
calculating the [intrinsic size
contribution] of such a box
(including any calculations for a content-based [automatic minimum
size](#automatic-minimum-size)), a percentage value that resolves against a size in
the same axis as the [intrinsic size
contribution] (a [cyclic
percentage size]) is resolved
specially:

a. [(#non-replaced-percentage-contribution) If the box is
 [non-replaced](https://drafts.csswg.org/css-display-4/#non-replaced), then the entire value of any [max size
 property](#max-size-properties) or [preferred size
 property](#preferred-size-properties) ([width](#propdef-width)/[max-width](#propdef-max-width)/[height](#propdef-height)/[max-height](#propdef-max-height)) specified as an expression
 [containing a
 percentage](https://drafts.csswg.org/css-values-4/#css-contain-a-percentage) (such as [10%] or [calc(10px + 0%)])
 that is
 [cyclic](#cyclic-percentage-size) is treated *for the purpose of calculating the
 box's [intrinsic size
 contributions](#intrinsic-size-contribution) only* as that property's [initial
 value](https://drafts.csswg.org/css-cascade-5/#initial-value). For example, given a box with [width: calc(20px +
 50%)], its max-content contribution
 is calculated as if its [width]
 were [auto](#valdef-width-auto). (The percentage is honored as usual, however,
 during the actual sizing of the box itself; see
 below.)]

b. [(#replaced-percentage-max-contribution) Likewise, if
 the box is
 [replaced](https://drafts.csswg.org/css-display-4/#replaced-element), then the entire value of any [max size
 property](#max-size-properties) or [preferred size
 property](#preferred-size-properties) specified as an expression containing a percentage
 that is
 [cyclic](#cyclic-percentage-size) is treated *for the purpose of calculating the
 box's [max-content
 contributions](#max-content-contribution) only* as that property's [initial
 value](https://drafts.csswg.org/css-cascade-5/#initial-value).]

c. [(#replaced-percentage-min-contribution) If the box is
 [replaced](https://drafts.csswg.org/css-display-4/#replaced-element), a [cyclic
 percentage](#cyclic-percentage-size) in the value of any [max size
 property](#max-size-properties) or [preferred size
 property](#preferred-size-properties) ([width](#propdef-width)/[max-width](#propdef-max-width)/[height](#propdef-height)/[max-height](#propdef-max-height)), is resolved against zero when
 calculating the [min-content
 contribution](#min-content-contribution) in the corresponding axis. (See [§ 5.2.2
 Compressible Replaced Elements](#min-content-zero) for a list of
 which elements in HTML this applies to.) If the box also has a
 [preferred aspect
 ratio](#preferred-aspect-ratio), then this [min-content
 contribution] is floored by any
 [\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage) [minimum
 size](#min-width) from the
 opposite axis---​resolving any such percentage against
 zero---​transferred through the [preferred aspect
 ratio].]

 (#issue-1b92b23f) Should we resolve transferred
 percentages against their containing block instead of zero before
 transferring them? See
 [discussion](https://github.com/w3c/csswg-drafts/issues/6341).

 The UA may additionally floor the [min-content
 contribution](#min-content-contribution) based on UI considerations, such as ensuring
 certain UI elements remain visible (for example, the dropdown arrow
 on a
 [`select`](https://html.spec.whatwg.org/multipage/form-elements.html#the-select-element)).

 The [min-content
 contribution](#min-content-contribution) is, as always, also floored by the [minimum
 size](#min-width) in its own
 axis.

 This rule also applies when calculating a content-based [automatic
 minimum
 size](#automatic-minimum-size) or its corresponding size contribution, yielding a
 [definite](#definite)
 "specified size suggestion".

 Tests

 - [intrinsic-percent-replaced-028.html](https://wpt.fyi/results/css/css-sizing/intrinsic-percent-replaced-028.html "css/css-sizing/intrinsic-percent-replaced-028.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/intrinsic-percent-replaced-028.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/intrinsic-percent-replaced-028.html)

 :::
 (#example-b06093ff) For example, an
 [`input`](https://html.spec.whatwg.org/multipage/input.html#the-input-element) assigned [width: calc(50% +
 50px)](#propdef-width) has a [min-content
 contribution](#min-content-contribution) of [50px], plus any horizontal
 margin/border/padding.
 :::

d. [(#min-percentage-contribution) For the [min size
 properties](#min-size-properties), as well as for
 [margins](https://drafts.csswg.org/css-box-4/#margin) and
 [paddings](https://drafts.csswg.org/css-box-4/#padding) (and
 [gutters](https://drafts.csswg.org/css-gaps-1/#gutter)), a [cyclic
 percentage](#cyclic-percentage-size) is resolved against zero for determining [intrinsic
 size
 contributions](#intrinsic-size-contribution).]

Tests

- [inline-intrinsic-size-calc.html](https://wpt.fyi/results/css/css-sizing/inline-intrinsic-size-calc.html "css/css-sizing/inline-intrinsic-size-calc.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/inline-intrinsic-size-calc.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/inline-intrinsic-size-calc.html)
- [intrinsic-percent-non-replaced-006.html](https://wpt.fyi/results/css/css-sizing/intrinsic-percent-non-replaced-006.html "css/css-sizing/intrinsic-percent-non-replaced-006.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/intrinsic-percent-non-replaced-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/intrinsic-percent-non-replaced-006.html)

Summary of the Cyclic-Percentage Intrinsic Size Contribution Rules
(Above)

Element Type

[Replaced](https://drafts.csswg.org/css-display-4/#replaced-element)

[Non-replaced](https://drafts.csswg.org/css-display-4/#non-replaced)

Contribution Type

[min-content](#min-content-contribution)

[max-content](#max-content-contribution)

[min-content](#min-content-contribution)

[max-content](#max-content-contribution)

[min size](#min-size-properties) &
[margin](https://drafts.csswg.org/css-box-4/#margin-properties)/[padding](https://drafts.csswg.org/css-box-4/#padding-properties)

[zeroᵈ](#min-percentage-contribution)

[zeroᵈ](#min-percentage-contribution)

[zeroᵈ](#min-percentage-contribution)

[zeroᵈ](#min-percentage-contribution)

[max](#max-size-properties) & [preferred
size](#preferred-size-properties)

[zeroᶜ](#replaced-percentage-min-contribution)

[initialᵇ](#replaced-percentage-max-contribution)

[initialᵃ](#non-replaced-percentage-contribution)

[initialᵃ](#non-replaced-percentage-contribution)

Then, unless otherwise specified, when calculating the used sizes and
positions of the containing block's *contents*:

- If the cyclic dependency was introduced due to a
 [block-axis](https://drafts.csswg.org/css-writing-modes-4/#block-axis) size other than a [minimum
 size](#min-width) on the
 containing block (i.e. a
 [block-size](#propdef-block-size) or
 [max-block-size](#propdef-max-block-size) in most layout modes, or a
 [flex-basis](https://drafts.csswg.org/css-flexbox-2/#propdef-flex-basis) in [flex
 layout](https://drafts.csswg.org/css-flexbox-2/#flex-layout)) that causes it to depend on the size of its
 contents, the box's percentage is not resolved and instead [behaves as
 auto](#behave-as-auto).

 [Grid
 items](https://drafts.csswg.org/css-grid-2/#grid-item) in both axes, [flex
 items](https://drafts.csswg.org/css-flexbox-2/#flex-item) in the [main
 axis](https://drafts.csswg.org/css-flexbox-2/#main-axis), and children of [flex items] in
 both axes do allow percentages to resolve in this case.

- Otherwise, the percentage is resolved against the containing block's
 size. (The containing block's size is not re-resolved based on the
 resulting size of the box; the contents might thus overflow or
 underflow the containing block).

 These rules specify the previously-undefined behavior
of this cyclic case in
[CSS2§10.2](https://www.w3.org/TR/CSS2/visudet.html#the-width-property),
[CSS2§8.3](https://www.w3.org/TR/CSS2/box.html#margin-properties), and
[CSS2§8.4](https://www.w3.org/TR/CSS2/box.padding-properties). Note
also, the behavior in
[CSS2§10.5](https://www.w3.org/TR/CSS2/visudet.html#the-height-property)
is superseded in their respective specifications for layout modes (such
as [flex layout](http://www.w3.org/TR/css-flexbox/)) not described in
CSS2.

For example, in the following markup:

```
<article style="width: min-content">
 <aside style="width: 50%;">
 LOOOOOOOOOOOOOOOOOOOONG
 </aside>
</article>
```

When calculating the width of the outer `<article>`, the inner `<aside>`
behaves as [width: auto](#propdef-width), so the `<article>` sets itself to the width of
the long word. Since the `<article>`'s width didn't depend on \"real\"
layout, though, it's treated as
[definite](#definite) for resolving
the `<aside>`, whose width resolves to half that of the `<article>`.

In this example,

```
<article style="height:auto">
 <aside style="height: 50%;">
 <div class=block style="height: 150px;"></div>
 </aside>
 <section style="height: 30px;"></section>
</article>
```

because the percentage [block size](#block-size) ([height](#propdef-height), in this case) on block-level
elements is defined to not resolve inside content-sized containing
blocks, the percentage height on the `<aside>` is ignored, that is, it
behaves exactly as if
[auto](#valdef-width-auto) were specified.

Letting percentages still resolve
against a definite [height](#propdef-height) when the min-height is intrinsic is
an open issue. (CSS2 has a general statement about \"height depending on
contents\", which this technically is, even though CSS2 didn't have
content-dependent keywords for
[min-height](#propdef-min-height). Since this is new, we think we could
have this different behavior.)

The following examples illustrate how block-axis percentages resolve
against a containing block whose size depends on its contents.

```
<article style="height:100px; min-height: min-content;">
 <aside style="height: 50%;">
 <div style="height: 150px;"></div>
 </aside>
 <section style="height: 30px;"></section>
</article>
```

The initial height of the `<article>` is 100px, as specified, which
would make the `<aside>` 50px tall when it resolved its percentage.
However, we must calculate the min-height, by substituting it in for
[height](#propdef-height). This causes the percentage on the `<aside>` to
[behave as auto](#behave-as-auto), so the `<aside>` ends up 150px tall. The total height
of the contents is thus 180px. This is larger than the specified 100px
height, so the `<article>` gets adjusted to 180px tall.

Then, since the percentage could *originally* resolve against the
(100px) height, it now resolves against the 180px height, so the
`<aside>` ends up being 90px tall.

```
<article style="height:auto; min-height: min-content;">
 <aside style="height: 50%;">
 <div class=block style="height: 150px;"></div>
 </aside>
 <section style="height: 30px;"></section>
</article>
```

In this case, the percentage on the `<aside>` won't normally resolve,
because the containing block's height is
[auto](#valdef-width-auto) (and thus depends on the size of its contents).
Instead it [behaves as auto](#behave-as-auto), resulting in a height of 150px for the `<aside>`, and
an initial height of 180px for the `<article>` The
[min-height](#propdef-min-height) doesn't change this; [height:
min-content;](#propdef-height) acts similarly to [height:
auto;] and results in the same sizes.

```
<article style="height:100px; min-height: min-content;">
 <aside style="height: 200%;">
 <div style="height: 150px;"></div>
 </aside>
 <section style="height: 30px;"></section>
</article>
```

This is a variation on the first code block, and follows a similar path;
the `<aside>` initially wants to compute to 200px tall (200% of the
100px containing block height). When we calculate the effects of
[min-height](#propdef-min-height), the percentage [behaves as
auto](#behave-as-auto),
causing it to become 150px tall, and the total
[min-content](#valdef-width-min-content) height of the containing block to be 180px tall.
Since this is larger than 100px, the `<article>` gets clamped to 180px,
the percentage resolves against this new height, and the `<aside>` ends
up being 360px tall, overflowing the `<article>`

#### 5.2.2. Compressible Replaced Elements

In addition to the [replaced
elements](https://drafts.csswg.org/css-display-4/#replaced-element) listed in
[HTML§14.4](https://html.spec.whatwg.org/multipage/rendering.html#replaced-elements)
[\[HTML\]](#biblio-html "HTML Standard"), the
following HTML elements are also considered to be [replaced
elements] for the purpose of the
[percentage-sized replaced element
rule](#replaced-percentage-min-contribution) above, and can have their
[min-content
contribution](#min-content-contribution) compressed when their
[width](#propdef-width)/[height](#propdef-height) or
[max-width](#propdef-max-width)/[max-height](#propdef-max-height) is expressed with a cyclic
percentage size:

- [`input`](https://html.spec.whatwg.org/multipage/input.html#the-input-element) with any
 [`type`](https://html.spec.whatwg.org/multipage/input.html#attr-input-type) that is not \"button-like\"; this can vary
 depending on the UA.

 A type is \"button-like\" in a particular UA if it displays similar to
 a
 [`button`](https://html.spec.whatwg.org/multipage/form-elements.html#the-button-element) element, where it can contains actual content
 that determines the layout of the element. In most UAs, the
 \"button\", \"reset\", \"submit\", and \"color\" types are
 button-like; the \"file\" type is also partially button-like in some
 UAs, when it's displayed as a combination of a text input (shrinkable)
 and a button (button-like, and thus not shrinkable).

- [`select`](https://html.spec.whatwg.org/multipage/form-elements.html#the-select-element),
 [`textarea`](https://html.spec.whatwg.org/multipage/form-elements.html#the-textarea-element),
 [`progress`](https://html.spec.whatwg.org/multipage/form-elements.html#the-progress-element),
 [`meter`](https://html.spec.whatwg.org/multipage/form-elements.html#the-meter-element),
 [`marquee`](https://html.spec.whatwg.org/multipage/obsolete.html#the-marquee-element).

Tracking web-compat & implementation
progress of applying this to max-width/height in [Issue
6348](https://github.com/w3c/csswg-drafts/issues/6348). [\[Issue
#6348\]](https://github.com/w3c/csswg-drafts/issues/6348)

## [ Changes]
### [ Recent Changes]
Changes since the [17 December 2021 Working
Draft](https://www.w3.org/TR/2021/WD-css-sizing-3-20211217/) include:

- Moved [fit-content()] to Level 4, pulled
 [fit-content](#valdef-width-fit-content) and
 [stretch](#valdef-width-stretch) from Level 4. ([Issue
 10601](https://github.com/w3c/csswg-drafts/issues/10601))
- Imported definitions of the
 [flow-relative](https://drafts.csswg.org/css-writing-modes-4/#flow-relative) [sizing
 properties](#sizing-property) from
 [\[CSS-LOGICAL-1\]](#biblio-css-logical-1 "CSS Logical Properties and Values Module Level 1").
 ([Issue 10189](https://github.com/w3c/csswg-drafts/issues/10189))
- Clarified details for [stretch-fit
 sizing](#stretch-fit-size). ([Issue
 11044](https://github.com/w3c/csswg-drafts/issues/11044), [Issue
 11006](https://github.com/w3c/csswg-drafts/issues/11006), [Issue
 11076](https://github.com/w3c/csswg-drafts/issues/11076), [Issue
 4028](https://github.com/w3c/csswg-drafts/issues/4028), [Issue
 13260](https://github.com/w3c/csswg-drafts/issues/13260), [Issue
 11489](https://github.com/w3c/csswg-drafts/issues/11489))
- Introduced
 [\<box-size\>](#typedef-box-size) grammar production to consolidate sizing
 values. ([Issue
 13478](https://github.com/w3c/csswg-drafts/issues/13478))
- Clarified that rules for finding the intrinsic size of replaced
 elements with a [preferred aspect
 ratio](#preferred-aspect-ratio) only apply when the aspect ratio is non-degenerate.
 ([Issue 12612](https://github.com/w3c/csswg-drafts/issues/12612))
- Defined that
 [aspect-ratio](https://drafts.csswg.org/css-sizing-4/#propdef-aspect-ratio)
 [\[css-sizing-4\]](#biblio-css-sizing-4 "CSS Box Sizing Module Level 4")
 preserves the [resolved
 value](https://drafts.csswg.org/cssom-1/#resolved-value) of an
 [auto](#valdef-width-auto) [minimum size](#min-width) as [auto]. ([Issue
 11716](https://github.com/w3c/csswg-drafts/issues/11716))
- Clarified that the [max-content
 size](#max-content) and
 [max-content
 contribution](#max-content-contribution) are floored by the [min-content
 size](#min-content)/[min-content
 contribution](#min-content-contribution). ([Issue
 12076](https://github.com/w3c/csswg-drafts/issues/12076))
- Clarified handling of cyclic percentages in intrinsic size
 contribution calculations. ([Issue
 6822](https://github.com/w3c/csswg-drafts/issues/6822))
- Clarified that stretch sizes are handled similarly to percentages for
 the purpose of intrinsic size calculations. ([Issue
 10619](https://github.com/w3c/csswg-drafts/issues/10619))
- Clarified indefiniteness of intrinsic size keywords. ([Issue
 7206](https://github.com/w3c/csswg-drafts/issues/7206))
- Added logical property groups to the [sizing
 properties](#sizing-property). ([Issue
 2822](https://github.com/w3c/csswg-drafts/issues/2822))
- Added Web Platform Tests coverage.
- Various other minor editorial fixes and improvements.

Changes since the [18 December 2020 Working
Draft](https://www.w3.org/TR/2020/WD-css-sizing-3-20201218/) include:

- Fixed the order of
 [contain-intrinsic-size](https://drafts.csswg.org/css-sizing-4/#propdef-contain-intrinsic-size) values when
 [auto](https://drafts.csswg.org/css-sizing-4/#valdef-contain-intrinsic-width-auto) is combined with other values so that parsing
 is unambiguous. ([Issue
 6391](https://github.com/w3c/csswg-drafts/issues/6391))
- Clarified which elements are allowed to not have a last remembered
 size for [contain-intrinsic-size:
 auto](https://drafts.csswg.org/css-sizing-4/#propdef-contain-intrinsic-size). ([Issue
 6220](https://github.com/w3c/csswg-drafts/issues/6220))
- Limited [contain-intrinsic-size:
 auto](https://drafts.csswg.org/css-sizing-4/#propdef-contain-intrinsic-size) to when [content-visibility] is
 [auto](https://drafts.csswg.org/css-contain-2/#valdef-content-visibility-auto). ([Issue
 6308](https://github.com/w3c/csswg-drafts/issues/6308))

Changes since the [18 December 2020 Working
Draft](https://www.w3.org/TR/2020/WD-css-sizing-3-20201218/) include:

- Fixed various errors in definition of max-content sizes of replaced
 elements in [§ 5.1 Intrinsic Sizes](#intrinsic-sizes). ([Issue
 6072](https://github.com/w3c/csswg-drafts/issues/6072))
- Added missing statement handling [min-content
 constraint](#min-content-constraint) to definition of [fit-content
 size](#fit-content-size).
- Renamed replaced element "intrinsic" dimensions to "natural"
 dimensions in order to avoid confusion with [intrinsic
 sizes](#intrinsic-size) (see
 [Issue 4961](https://github.com/w3c/csswg-drafts/issues/4961)).
- Various other minor editorial fixes and improvements.

Major changes since the [22 May 2019 Working
Draft](https://www.w3.org/TR/2019/WD-css-sizing-3-20190522/) include:

- Defined that
 [min-content](#valdef-width-min-content) and
 [max-content](#valdef-width-max-content) do not necessarily behave the same as the
 property's initial value if otherwise specified (by the relevant
 layout module). ([Issue
 3973](https://github.com/w3c/csswg-drafts/issues/3973))
- Switched intrinsic contribution of
 [fit-content()](https://drafts.csswg.org/css-sizing-4/#funcdef-width-fit-content) to treat its argument as that argument would
 be treated alone for intrinsic contribution calculations and resolve
 the fit-content formula accordingly, rather than having special
 behavior for [fit-content()]
 resolution when calculating intrinsic contributions. ([Issue
 3731](https://github.com/w3c/csswg-drafts/issues/3731))
- Changed the [max-content size](#max-content) of replaced boxes without an intrinsic size to use
 their [minimum size](#min-width)
 in place of ICB or 300px×150px only when it is a
 [\<length\>](https://drafts.csswg.org/css-values-4/#length-value), see [§ 5.1 Intrinsic
 Sizes](#intrinsic-sizes). ([Issue
 4217](https://github.com/w3c/csswg-drafts/issues/4217))
- Switched default sizing of an object with a natural aspect ratio to
 use the ICB size instead of 300px×150px. ([Issue
 4218](https://github.com/w3c/csswg-drafts/issues/4218))
- Defined [preferred aspect
 ratio](#preferred-aspect-ratio) and used it in place of "intrinsic aspect ratio"
 where appropriate.
- Miscellaneous minor / editorial fixes.

Major changes since the [4 March 2018 Working
Draft](https://www.w3.org/TR/2018/WD-css-sizing-3-20180304/) include:

- Imported the
 [box-sizing](#propdef-box-sizing) definition from [CSS UI Level
 3](https://www.w3.org/TR/css-ui-3/).
- More rigorously specified handling of [cyclic
 percentages](#cyclic-percentage-size).
 ([#1132](https://github.com/w3c/csswg-drafts/issues/1132),
 [#2384](https://github.com/w3c/csswg-drafts/issues/2384),
 [#2297](https://github.com/w3c/csswg-drafts/issues/2297),
 [#2674](https://github.com/w3c/csswg-drafts/issues/2674))
- Changed the [\*-content] values applied to the bock axis to not
 compute to the property's initial value, but to rather "behave as" the
 property's initial value.
 ([#2708](https://github.com/w3c/csswg-drafts/issues/2708))
- Fixed miscellaneous trivial errors.

Major changes since the [7 February 2017 Working
Draft](https://www.w3.org/TR/2017/WD-css-sizing-3-20170207/) include:

- More accurate definition of min-content and max-content sizes for
 replaced elements.
- Compute new keywords to the initial value, not to a potentially
 non-existent [auto](#valdef-width-auto), when applied to the block axis.
- Specify that percent sizes on replaced elements zero out their
 min-content contribution.
- Fix confusing/wrong definition of percentage sizes resolved against a
 dependent containing block. (This may require further work.)
- Deferred the
 [stretch](#valdef-width-stretch) and
 [fit-content](#valdef-width-fit-content) keywords to Level 4 to allow for further
 consideration of their behavior in
 [indefinite](#indefinite)
 containing blocks.
- Pulled in full definitions for all of the sizing properties (rather
 than diffing them): [width](#propdef-width),
 [height](#propdef-height),
 [min-width](#propdef-min-width),
 [min-height](#propdef-min-height), max-width\',
 [max-height](#propdef-max-height), and
 [box-sizing](#propdef-box-sizing).

### [ Additions since CSS Level 2]
In addition to substantially more detail to the various automatic and
content-based sizing algorithms, the following new features have been
added since
[\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification"):

- The [box-sizing](#propdef-box-sizing) property (originally defined in
 [\[CSS-UI-3\]](#biblio-css-ui-3 "CSS Basic User Interface Module Level 3 (CSS3 UI)"),
 then moved here).
- The [stretch](#valdef-width-stretch),
 [min-content](#valdef-width-min-content),
 [max-content](#valdef-width-max-content), and
 [fit-content](#valdef-width-fit-content) values of the [sizing
 properties](#sizing-property).
- The [auto](#valdef-width-auto) initial value of the
 [min-width](#propdef-min-width) and
 [min-height](#propdef-min-height) properties (originally defined in
 [\[CSS-FLEXBOX-1\]](#biblio-css-flexbox-1 "CSS Flexible Box Layout Module Level 1"),
 then moved here).

## [ Acknowledgments]
Special thanks go to L. David Baron, Aaron Gustafson, Daniel Holbert,
and Mats Palmgren for their contributions to this module.

## [ Privacy Considerations]
In order to support automatic layout, CSS sizes boxes to fit their
contents. In conjunction with various
[\[DOM\]](#biblio-dom "DOM Standard") and
[\[CSSOM\]](#biblio-cssom "CSS Object Model (CSSOM)")
APIs which can return the size of those boxes to script, this can expose
information about those contents. However, this information is more
directly and easily available by inspecting the DOM for the contents,
rather than indirecting through the box's size. Containers that can't
have their contents inspected (such as cross-origin
[`iframe`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-iframe-element)s) also do not expose sizing information to the
outer page, except insofar as [replaced
elements](https://drafts.csswg.org/css-display-4/#replaced-element) such as images expose their natural size and/or aspect
ratio.

## [ Security Considerations]
No new security considerations have been reported on this specification.
