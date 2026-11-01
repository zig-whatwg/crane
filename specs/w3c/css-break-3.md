## 1. Introduction

::: non-normative
*This section is not normative.*

In [paged
media](https://drafts.csswg.org/mediaqueries-5/#paged-media) (e.g., paper, transparencies, photo album pages, pages
displayed on computer screens as printed output simulations), as opposed
to [continuous
media](https://drafts.csswg.org/mediaqueries-5/#continuous-media), the content of the document is split into one or more
discrete display surfaces. In order to avoid awkward breaks (such as
halfway through a line of text), the layout engine must be able to shift
around content that would fall across the page break. This process is
called [pagination].

In CSS, in addition to [paged
media](https://drafts.csswg.org/mediaqueries-5/#paged-media), certain layout features such as
[regions](https://www.w3.org/TR/css3-regions/)
[\[CSS3-REGIONS\]](#biblio-css3-regions "CSS Regions Module Level 1")
and [multi-column layout](https://www.w3.org/TR/css3-multicol/)
[\[CSS3COL\]](#biblio-css3col "CSS Multi-column Layout Module Level 1")
create a similarly fragmented environment. The generic term for breaking
content across containers is
[fragmentation](#fragmentation).
This module explains how content breaks across [fragmentation
containers](#fragmentation-container)
([fragmentainers](#fragmentainer)) such as pages and columns and how such breaks can be
[controlled by the author](#breaking-controls).

### 1.1. Module Interactions

This module replaces and extends the pagination controls defined in
[\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")
[section 13.3](https://www.w3.org/TR/CSS21/page.html#page-breaks) and in
[\[CSS3PAGE\]](#biblio-css3page "CSS Paged Media Module Level 3").

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

## 2. Fragmentation Model and Terminology

[fragmentation container] ([fragmentainer])
: A box---such as a page box, column box, or region---that contains a
 portion (or all) of a [fragmented
 flow](#fragmented-flow).
 Fragmentainers can be pre-defined, or generated as needed. When
 breakable content would overflow a fragmentainer in the block
 dimension, it breaks into the next container in its [fragmentation
 context](#fragmentation-context) instead.

[fragmentation context]
: An ordered series of
 [fragmentainers](#fragmentainer), such as created by a [multi-column
 container](https://www.w3.org/TR/css3-multicol/), a chain of [CSS
 regions](https://www.w3.org/TR/css3-regions), or a [paged
 media](https://drafts.csswg.org/mediaqueries-5/#paged-media) display. A given fragmentation context can only
 have one block flow direction across all its
 [fragmentainers]. (Descendants of the
 [fragmentation
 root](#fragmentation-root) may have other block flow directions, but
 fragmentation proceeds according to the block flow direction applied
 to the [fragmentation root].)

[fragmented flow]
: Content that is being laid out in a [fragmentation
 context](#fragmentation-context). The [fragmented
 flow](#fragmented-flow)
 consists of the content of a (possibly anonymous) box called the
 [fragmentation root].

[fragmentation direction]
: The block flow direction of the [fragmentation
 context](#fragmentation-context), i.e. the direction in which content is fragmented.
 (In this level of CSS, content only fragments in one dimension.)

[fragmentation]
: The process of splitting a content flow across the
 [fragmentainers](#fragmentainer) that form a [fragmentation
 context](#fragmentation-context).

[box fragment] or [fragment]
: The portion of a box that belongs to exactly one
 [fragmentainer](#fragmentainer). A box in continuous flow always consists of only
 one fragment. A box in a fragmented flow consists of one or more
 fragments. Each fragment has its own share of the box's border,
 padding, and margin, and therefore has its own [padding
 area](https://drafts.csswg.org/css-box-4/#padding-area), [border
 area](https://drafts.csswg.org/css-box-4/#border-area), and [margin
 area](https://drafts.csswg.org/css-box-4/#margin-area). (See
 [box-decoration-break](#propdef-box-decoration-break), which controls how these are
 affected by fragmentation.)

[remaining fragmentainer extent]
: The remaining
 [block-axis](https://drafts.csswg.org/css-writing-modes-4/#block-axis) space in the
 [fragmentainer](#fragmentainer) available to a given element, i.e. between the end
 of preceding content in [fragmentainer] and
 the edge of the [fragmentainer].

Each [fragmentation break] (hereafter,
[break](#fragmentation-break)) ends layout of the fragmented box in the current
[fragmentainer](#fragmentainer)
and causes the remaining content to be laid out in the next
[fragmentainer], in some cases causing a new
[fragmentainer] to be generated to hold the
deferred content.

Breaking inline content into lines is another form of fragmentation, and
similarly creates box fragments when it breaks [inline
boxes](https://www.w3.org/TR/CSS21/visuren.html#inline-boxes) across
[line boxes](https://www.w3.org/TR/CSS21/visuren.html#line-box).
However, inline breaking is not covered here; see
[\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")/[\[CSS3TEXT\]](#biblio-css3text "CSS Text Module Level 3").

A box can be broken into multiple
[fragments](#fragment) also due to
bidi reordering of text (see [Applying the Bidirectional Reordering
Algorithm](https://drafts.csswg.org/css-writing-modes-3/#bidi-algo) in
[CSS Writing
Modes](https://drafts.csswg.org/css-writing-modes-3/#text-direction)) or
higher-level [display
type](https://drafts.csswg.org/css-display-4/#display-type) box splitting, e.g. [block-in-inline
splitting](https://www.w3.org/TR/CSS2/visuren.html#img-anon-block) (see
[CSS2§9.2](https://www.w3.org/TR/CSS2/visuren.html#box-gen)) or
[column-spanner-in-block](https://www.w3.org/TR/css-multicol-1/#spanning-columns)
splitting (see [CSS Multi-column
Layout](https://www.w3.org/TR/css-multicol-1/#spanning-columns)). The
division into [box fragments](#box-fragment) in these cases does not depend on layout
(sizing/positioning of content).

### 2.1. Parallel Fragmentation Flows

When multiple [formatting
contexts](https://drafts.csswg.org/css-display-4/#formatting-context) are laid out parallel to each other, fragmentation is
performed independently in each [formatting
context]. For example, if an element is
floated, then a forced break inside the float will not affect the
content outside the float (except insofar as it may increase the height
of the float). UAs *may* (but are not required to) adjust the placement
of [unforced breaks](#unforced-break) in parallel [formatting
contexts] to visually balance such
side-by-side content, but *must not* do so to match a [forced
break](#forced-break).

The following are examples of parallel flows whose contents will
fragment independently:

- The contents of a float vs. the content wrapping outside the float.
- The contents of a float vs. the contents of an adjacent float.
- The contents of each table cell in a single table row.
- The contents of each grid item in a single grid row.
- The contents of each flex item in a flex layout row.
- The contents of absolutely-positioned elements that cover the same
 range of their containing block's fragmentation context.

Content overflowing the content edge of a fixed-size box is considered
parallel to the content after the fixed-size box and follows the normal
fragmentation rules. Although overflowing content doesn't affect the
size of the [fragmentation
root](#fragmentation-root)
box, it does increase the length of the [fragmented
flow](#fragmented-flow),
spilling into or generating additional
[fragmentainers](#fragmentainer) as necessary.

### 2.2. Nested Fragmentation Flows

Breaking a [fragmentainer](#fragmentainer) `F` effectively splits the
[fragmentainer] into two
[fragmentainers]
(`F`~`1`~ and `F`~`2`~). The
only difference is that, with regards to the content of
[fragmentainer] `F`, the type of
break between the two pieces `F`~`1`~ and
`F`~`2`~ is the [type of break](#break-types)
created by the [fragmentation
context](#fragmentation-context) that split `F`, not the type of break
normally created by `F`'s own [fragmentation
context].

For example, if a region box is broken
at a page boundary, then the content of the region will be affected by a
page break at that point (but not by a region break).

Note that when a multi-column container breaks across pages, it
generates a new row of columns on the next page for the rest of its
content, so that a page break within a multi-column container is always
both a page break and a column break.

## 3. Controlling Breaks

The following sections explain how breaks are controlled in a
[fragmented flow](#fragmented-flow). A page/column/region break opportunity between two
boxes is under the influence of the containing block's
[break-inside](#propdef-break-inside) property, the
[break-after](#propdef-break-after) property of the preceding element, and
the [break-before](#propdef-break-before) property of the following element.
A page/column/region break opportunity between line boxes is under the
influence of the containing block's
[break-inside],
[widows](#propdef-widows), and
[orphans](#propdef-orphans) properties. A fragmentation break can be allowed,
forced, or discouraged depending on the values of these properties. A
forced break overrides any break restrictions acting at that break
point. In the case of forced page breaks, the author can also specify on
which page ([left or
right](https://www.w3.org/TR/css3-page/#left-right-first)) the
subsequent content should resume.

See the section on [rules for breaking](#breaking-rules) for the exact
rules on how these properties affect fragmentation.

### 3.1. Breaks Between Boxes: the [break-before and [break-after](#propdef-break-after) properties]
Name:

[break-before], [break-after]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

auto
[\|](https://drafts.csswg.org/css-values-4/#comb-one) avoid [\|] avoid-page
[\|] page [\|] left
[\|] right [\|] recto
[\|] verso [\|] avoid-column
[\|] column [\|] avoid-region
[\|] region

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

auto

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

block-level boxes, grid items, flex items, table row groups, table rows
(but see prose)

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

These properties specify page/column/region break behavior before/after
the generated box. The [forced break values]
[left](#valdef-break-before-left),
[right](#valdef-break-before-right),
[recto](#valdef-break-before-recto),
[verso](#valdef-break-before-verso),
[page](#valdef-break-before-page),
[column](#valdef-break-before-column) and
[region](#valdef-break-before-region) create a [forced break](#forced-breaks) in the
flow while the [avoid break values]
[avoid](#valdef-break-before-avoid),
[avoid-page](#valdef-break-before-avoid-page),
[avoid-column](#valdef-break-before-avoid-column) and
[avoid-region](#valdef-break-before-avoid-region) indicate that content should be kept together.

Values for
[break-before](#propdef-break-before) and
[break-after](#propdef-break-after) are defined in the sub-sections below.
User agents must apply these properties to boxes in the normal flow of
the [fragmentation
root](#fragmentation-root). User agents should also apply these properties to
floated boxes whose containing block is in the normal flow of the root
fragmented element. User agents may also apply these properties to other
boxes. User agents must not apply these properties to
absolutely-positioned boxes.

#### [ Generic Break Values]
These values have an effect regardless of the type of fragmented context
containing the flow.

[auto]
: Neither force nor forbid a break before/after the [principal
 box](https://www.w3.org/TR/CSS21/visuren.html#block-boxes).

[avoid]
: Avoid a break before/after the [principal
 box](https://www.w3.org/TR/CSS21/visuren.html#block-boxes).

#### [ Page Break Values]
These values only have an effect in paginated contexts; if the flow is
not paginated, they have no effect.

[avoid-page]
: Avoid a page break before/after the [principal
 box](https://www.w3.org/TR/CSS21/visuren.html#block-boxes).

[page]
: Always force a page break before/after the [principal
 box](https://www.w3.org/TR/CSS21/visuren.html#block-boxes).

[left]
: Force one or two page breaks before/after the [principal
 box](https://www.w3.org/TR/CSS21/visuren.html#block-boxes) so that
 the next page is formatted as a left page.

[right]
: Force one or two page breaks before/after the [principal
 box](https://www.w3.org/TR/CSS21/visuren.html#block-boxes) so that
 the next page is formatted as a right page.

[recto]
: Force one or two page breaks before/after the [principal
 box](https://www.w3.org/TR/CSS21/visuren.html#block-boxes) so that
 the next page is formatted as either a left page or a right page,
 whichever is second (according to the [page
 progression](https://drafts.csswg.org/css-page-3/#page-progression)) in a page spread.

[verso]
: Force one or two page breaks before/after the [principal
 box](https://www.w3.org/TR/CSS21/visuren.html#block-boxes) so that
 the next page is formatted as either a left page or a right page,
 whichever is first (according to the [page
 progression](https://drafts.csswg.org/css-page-3/#page-progression)) in a page spread.

#### [ Column Break Values]
These values only have an effect in multi-column contexts; if the flow
is not within a multi-column context, they have no effect.

[avoid-column]
: Avoid a column break before/after the [principal
 box](https://www.w3.org/TR/CSS21/visuren.html#block-boxes).

[column]
: Always force a column break before/after the [principal
 box](https://www.w3.org/TR/CSS21/visuren.html#block-boxes).

#### [ Region Break Values]
These values only have an effect in multi-region contexts; if the flow
is not linked across multiple regions, these values have no effect.

[avoid-region]
: Avoid a region break before/after the [principal
 box](https://www.w3.org/TR/CSS21/visuren.html#block-boxes).

[region]
: Always force a region break before/after the [principal
 box](https://www.w3.org/TR/CSS21/visuren.html#block-boxes).

#### 3.1.1. Child→Parent Break Propagation

Since breaks are only allowed between siblings, not between a box and
its container (see [Possible Break Points](#possible-breaks)), break
values applied to children at the start/end of a parent are
[propagated] to the parent, where they can
take effect.

Specifically---​except in layout modes which define more specific rules
to account for reordering and parallel layout (e.g. in [flex
layout](http://www.w3.org/TR/css-flexbox-1/#pagination)
[\[CSS-FLEXBOX-1\]](#biblio-css-flexbox-1 "CSS Flexible Box Layout Module Level 1")
or [grid layout](http://www.w3.org/TR/css-grid-1/#pagination)
[\[CSS-GRID-1\]](#biblio-css-grid-1 "CSS Grid Layout Module Level 1"))---​a
[break-before](#propdef-break-before) value on a first
[in-flow](https://drafts.csswg.org/css-display-4/#in-flow) child box is
[propagated](#propagate) to its
container. Likewise a
[break-after](#propdef-break-after) value on a last
[in-flow] child box is
[propagated] to its container. (Conflicting values
[combine](#forced-breaks) as defined below.) This propagation stops
before it breaks through the nearest matching fragmentation context.

Break [propagation](#propagate)
does not affect [computed
values](https://drafts.csswg.org/css-cascade-5/#computed-value); it is part of interpreting the elements' computed
values for layout.

### 3.2. Breaks Within Boxes: the [break-inside property]
Name:

[break-inside]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

auto
[\|](https://drafts.csswg.org/css-values-4/#comb-one) avoid [\|] avoid-page
[\|] avoid-column [\|]
avoid-region

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

auto

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

all elements except inline-level boxes, internal ruby boxes, table
column boxes, table column group boxes, absolutely-positioned boxes

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

This property specifies page/column/region break behavior within the
element's principal box. Values have the following meanings:

[auto]
: Impose no additional breaking constraints within the box.

[avoid]
: Avoid breaks within the box.

[avoid-page]
: Avoid a page break within the box.

[avoid-column]
: Avoid a column break within the box.

[avoid-region]
: Avoid a region break within the box.

### 3.3. Breaks Between Lines: [orphans, [widows](#propdef-widows)]
Name:

[orphans], [widows]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<integer
\[1,∞\]\>](https://drafts.csswg.org/css-values-4/#integer-value)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

2

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[block
containers](https://drafts.csswg.org/css-display-4/#block-container) that establish an [inline formatting
context](https://drafts.csswg.org/css-display-4/#inline-formatting-context)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

yes

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

specified integer

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value type

The [orphans](#propdef-orphans) property specifies the minimum number of line
boxes in a block container that must be left in a
[fragment](#fragment) *before* a
fragmentation break. The
[widows](#propdef-widows) property specifies the minimum number of line
boxes of a block container that must be left in a
[fragment] *after* a break. Examples of how they are
used to control fragmentation breaks are given
[below](#widows-orphans-example).

Tests

- [widows-001.html](https://wpt.fyi/results/css/css-break/widows-001.html "css/css-break/widows-001.html")
 [[(live
 test)]](http://wpt.live/css/css-break/widows-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-break/widows-001.html)
- [widows-orphans-001.html](https://wpt.fyi/results/css/css-break/widows-orphans-001.html "css/css-break/widows-orphans-001.html")
 [[(live
 test)]](http://wpt.live/css/css-break/widows-orphans-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-break/widows-orphans-001.html)
- [widows-orphans-002.html](https://wpt.fyi/results/css/css-break/widows-orphans-002.html "css/css-break/widows-orphans-002.html")
 [[(live
 test)]](http://wpt.live/css/css-break/widows-orphans-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-break/widows-orphans-002.html)
- [widows-orphans-003.html](https://wpt.fyi/results/css/css-break/widows-orphans-003.html "css/css-break/widows-orphans-003.html")
 [[(live
 test)]](http://wpt.live/css/css-break/widows-orphans-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-break/widows-orphans-003.html)
- [widows-orphans-004.html](https://wpt.fyi/results/css/css-break/widows-orphans-004.html "css/css-break/widows-orphans-004.html")
 [[(live
 test)]](http://wpt.live/css/css-break/widows-orphans-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-break/widows-orphans-004.html)
- [widows-orphans-005.html](https://wpt.fyi/results/css/css-break/widows-orphans-005.html "css/css-break/widows-orphans-005.html")
 [[(live
 test)]](http://wpt.live/css/css-break/widows-orphans-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-break/widows-orphans-005.html)
- [widows-orphans-006.html](https://wpt.fyi/results/css/css-break/widows-orphans-006.html "css/css-break/widows-orphans-006.html")
 [[(live
 test)]](http://wpt.live/css/css-break/widows-orphans-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-break/widows-orphans-006.html)
- [widows-orphans-007.html](https://wpt.fyi/results/css/css-break/widows-orphans-007.html "css/css-break/widows-orphans-007.html")
 [[(live
 test)]](http://wpt.live/css/css-break/widows-orphans-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-break/widows-orphans-007.html)
- [widows-orphans-008.html](https://wpt.fyi/results/css/css-break/widows-orphans-008.html "css/css-break/widows-orphans-008.html")
 [[(live
 test)]](http://wpt.live/css/css-break/widows-orphans-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-break/widows-orphans-008.html)
- [widows-orphans-009.html](https://wpt.fyi/results/css/css-break/widows-orphans-009.html "css/css-break/widows-orphans-009.html")
 [[(live
 test)]](http://wpt.live/css/css-break/widows-orphans-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-break/widows-orphans-009.html)
- [widows-orphans-010.html](https://wpt.fyi/results/css/css-break/widows-orphans-010.html "css/css-break/widows-orphans-010.html")
 [[(live
 test)]](http://wpt.live/css/css-break/widows-orphans-010.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-break/widows-orphans-010.html)
- [widows-orphans-011.html](https://wpt.fyi/results/css/css-break/widows-orphans-011.html "css/css-break/widows-orphans-011.html")
 [[(live
 test)]](http://wpt.live/css/css-break/widows-orphans-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-break/widows-orphans-011.html)
- [widows-orphans-012.html](https://wpt.fyi/results/css/css-break/widows-orphans-012.html "css/css-break/widows-orphans-012.html")
 [[(live
 test)]](http://wpt.live/css/css-break/widows-orphans-012.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-break/widows-orphans-012.html)
- [widows-orphans-013.html](https://wpt.fyi/results/css/css-break/widows-orphans-013.html "css/css-break/widows-orphans-013.html")
 [[(live
 test)]](http://wpt.live/css/css-break/widows-orphans-013.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-break/widows-orphans-013.html)
- [widows-orphans-014.html](https://wpt.fyi/results/css/css-break/widows-orphans-014.html "css/css-break/widows-orphans-014.html")
 [[(live
 test)]](http://wpt.live/css/css-break/widows-orphans-014.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-break/widows-orphans-014.html)
- [widows-orphans-015.html](https://wpt.fyi/results/css/css-break/widows-orphans-015.html "css/css-break/widows-orphans-015.html")
 [[(live
 test)]](http://wpt.live/css/css-break/widows-orphans-015.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-break/widows-orphans-015.html)
- [widows-orphans-016.html](https://wpt.fyi/results/css/css-break/widows-orphans-016.html "css/css-break/widows-orphans-016.html")
 [[(live
 test)]](http://wpt.live/css/css-break/widows-orphans-016.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-break/widows-orphans-016.html)
- [widows-orphans-017.html](https://wpt.fyi/results/css/css-break/widows-orphans-017.html "css/css-break/widows-orphans-017.html")
 [[(live
 test)]](http://wpt.live/css/css-break/widows-orphans-017.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-break/widows-orphans-017.html)
- [widows-orphans-018.html](https://wpt.fyi/results/css/css-break/widows-orphans-018.html "css/css-break/widows-orphans-018.html")
 [[(live
 test)]](http://wpt.live/css/css-break/widows-orphans-018.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-break/widows-orphans-018.html)

Only positive integers are allowed as values of
[orphans](#propdef-orphans) and
[widows](#propdef-widows). Negative values and zero are invalid and must
cause the declaration to be
[ignored](https://www.w3.org/TR/CSS21/conform.html#ignore).

If a block contains fewer lines than the value of
[widows](#propdef-widows) or
[orphans](#propdef-orphans), the rule simply becomes that all lines in the
block must be kept together.

### [3.4. ][ Page Break Aliases: the [page-break-before](https://drafts.csswg.org/css2/#propdef-page-break-before), [page-break-after](https://drafts.csswg.org/css2/#propdef-page-break-after), and [page-break-inside](https://drafts.csswg.org/css2/#propdef-page-break-inside) properties]
For compatibility with [CSS Level
2](https://www.w3.org/TR/CSS21/page.html), UAs that conform to
[\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")
must alias the
[page-break-before](https://drafts.csswg.org/css2/#propdef-page-break-before),
[page-break-after](https://drafts.csswg.org/css2/#propdef-page-break-after), and
[page-break-inside](https://drafts.csswg.org/css2/#propdef-page-break-inside) properties to
[break-before](#propdef-break-before),
[break-after](#propdef-break-after), and
[break-inside](#propdef-break-inside) by treating the
[page-break-\*] properties as [legacy
shorthands](https://drafts.csswg.org/css-cascade-5/#legacy-shorthand) for the [break-\*] properties with the following
value mappings:

Shorthand ([page-break-\*]) Values

Longhand ([break-\*]) Values

[auto \| left \| right \| avoid]

[auto \| left \| right \| avoid]

[always]

[page]

## 4. Rules for Breaking

A [fragmented flow](#fragmented-flow) may be broken across
[fragmentainers](#fragmentainer) at a number of [possible break
points](#possible-breaks). In the case of [forced
breaks](#forced-breaks), the UA is required to break the flow at that
point. In the case of [unforced breaks](#unforced-breaks), the UA has to
choose among the possible breaks that are allowed.

To guarantee progress, fragmentainers are assumed to have a minimum
[block
size](https://drafts.csswg.org/css-sizing-3/#block-size) of 1px regardless of their used size.

### 4.1. Possible Break Points

Fragmentation splits boxes in the block flow dimension. In
block-and-inline flow, breaks may occur at the following places:

Class A
: Between sibling boxes of the following types:

 Block-parallel Fragmentation
 : When the block flow direction of the siblings\' containing block
 is parallel to that of the fragmentation context:
 [in-flow](https://www.w3.org/TR/2011/REC-CSS2-20110607/visuren.html#positioning-scheme)
 block-level boxes, a float and an immediately-adjacent in-flow
 or floated box, table row group boxes, table row boxes,
 multi-column column row boxes.

 Block-perpendicular Fragmentation
 : When the block flow direction of the siblings\' containing block
 is perpendicular to that of the fragmentation context: table
 column group boxes, table column boxes, multi-column column
 boxes.

Class B
: Between line boxes inside a block container box.

Class C
: Between the content edge of a block container box and the outer
 edges of its child content (margin edges of block-level children or
 line box edges for inline-level children) *if* there is a (non-zero)
 gap between them.

There is no inherent prioritization among these classes of break points.
However, individual break points may be prioritized or de-prioritized by
using the [breaking controls](#breaking-controls).

Other layout models may add breakpoints to the above classes. For
example,
[\[CSS-FLEXBOX-1\]](#biblio-css-flexbox-1 "CSS Flexible Box Layout Module Level 1")
adds certain points within a flex formatting context to classes A and C.

Some content is not fragmentable, for example many types of [replaced
elements](https://www.w3.org/TR/CSS21/conform.html#replaced-element)
[\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")
(such as images or video), scrollable elements, or a single line of text
content. Such content is considered [monolithic]: it contains no possible break
points. Any forced breaks within such boxes therefore cannot split the
box, and must therefore also be ignored by the box's own fragmentation
context.

In addition to any content which is not generally fragmentable, UAs may
consider as [monolithic](#monolithic) any elements with
[overflow](https://drafts.csswg.org/css-overflow-3/#propdef-overflow) set to
[auto](https://drafts.csswg.org/css-overflow-3/#valdef-overflow-auto) or
[scroll](https://drafts.csswg.org/css-overflow-3/#valdef-overflow-scroll) and any elements with [overflow:
hidden] and a
non-[auto](https://drafts.csswg.org/css-sizing-3/#valdef-width-auto) [logical
height](https://www.w3.org/TR/css3-writing-modes/#block-size) (and no
specified maximum logical height).

Since line boxes contain no possible break points,
[inline-block](https://drafts.csswg.org/css-display-4/#valdef-display-inline-block) and
[inline-table](https://drafts.csswg.org/css-display-4/#valdef-display-inline-table) boxes (and other inline-level [display
types](https://drafts.csswg.org/css-display-4/#display-type) that establish an [independent formatting
context](https://drafts.csswg.org/css-display-4/#independent-formatting-context)) may also be considered
[monolithic](#monolithic): that
is, in the cases where a single line box is too large to fit within its
fragmentainer even by itself and the UA chooses to split the line box,
it may fragment such boxes or it may treat them as monolithic.

### 4.2. Types of Breaks

There are different types of breaks in CSS, defined based on the type of
fragmentainers they span:

[page break]
: A break between two [page
 boxes](https://www.w3.org/TR/css3-page/#page-box).
 [\[CSS3PAGE\]](#biblio-css3page "CSS Paged Media Module Level 3")

[spread break]
: A break between two page boxes that are not associated with [facing
 pages](https://www.w3.org/TR/css3-page/#facing-pages). A spread
 break is always also a page break.
 [\[CSS3PAGE\]](#biblio-css3page "CSS Paged Media Module Level 3")

[column break]
: A break between two [column
 boxes](https://www.w3.org/TR/css3-multicol/#column-box). Note that
 if the column boxes are on different pages, then the break is also a
 [page break](#page-break).
 Similarly, if the column boxes are in different regions, then the
 break is also a [region break](#region-break).
 [\[CSS3COL\]](#biblio-css3col "CSS Multi-column Layout Module Level 1")

[region break]
: A break between two
 [regions](https://www.w3.org/TR/css3-regions/#regions). Note that if
 the region boxes are on different pages, then the break is also a
 [page break](#page-break).
 [\[CSS3-REGIONS\]](#biblio-css3-regions "CSS Regions Module Level 1")

A fifth type of break is the [line
break](https://drafts.csswg.org/css-text-4/#line-break), which is a break between two [line
boxes](https://www.w3.org/TR/CSS21/visuren.html#line-box). These are not
covered in this specification; see
[\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")
[\[CSS3TEXT\]](#biblio-css3text "CSS Text Module Level 3").

### 4.3. Forced Breaks

A [forced break] is one explicitly indicated by the style sheet author. A
[forced break](#forced-break)
occurs at a [class A break point](#btw-blocks) if, among the
[break-after](#propdef-break-after) properties specified on or
[propagated](#propagate) to the
earlier sibling box and the
[break-before](#propdef-break-before) properties specified on or
[propagated] to the later sibling box there is at
least one with a [forced break
value](#forced-break-values). (Thus a [forced break
value] effectively overrides any [avoid
break value](#avoid-break-values) that also applies at that break point.)

When multiple [forced break
values](#forced-break-values) apply to a single break point, they combine such that
all types of break are honored. When
[left](#valdef-break-before-left),
[right](#valdef-break-before-right),
[recto](#valdef-break-before-recto), and/or
[verso](#valdef-break-before-verso) are combined, the value specified on the latest
element in the flow wins.

A forced page break must also occur at a [class A break
point](#btw-blocks) if the last line box above this margin and the first
one below it do not have the same value for
[page](https://drafts.csswg.org/css-page-3/#propdef-page). See
[\[CSS3PAGE\]](#biblio-css3page "CSS Paged Media Module Level 3")

When a forced break occurs, it forces ensuing content into the next
fragmentainer of the type associated with the break, breaking through as
many fragmentation contexts as necessary until the specified break types
are all satisfied. If the forced break is not contained within a
matching type of fragmentation context, then the forced break has no
effect.

### 4.4. Unforced Breaks

While [breaking controls](#breaking-controls) can force breaks, they can
also discourage them. An [unforced break] is one that is inserted
automatically by the UA in order to prevent content from overflowing the
[fragmentainer](#fragmentainer). The following rules control whether unforced breaking
at a [possible break point](#possible-breaks) is allowed:

Rule 1
: A [fragmented flow](#fragmented-flow) may break at a [class A break point](#btw-blocks)
 only if all the
 [break-after](#propdef-break-after) and
 [break-before](#propdef-break-before) values applicable to this break
 point allow it, which is when at least one of them forces a break or
 when none of them forbid it
 ([avoid](#valdef-break-before-avoid) or
 [avoid-page](#valdef-break-before-avoid-page)/[avoid-column](#valdef-break-before-avoid-column)/[avoid-region](#valdef-break-before-avoid-region), depending on the [break
 type](#break-types)).

Rule 2
: However, if all of them are
 [auto](#valdef-break-before-auto) and a common ancestor of all the elements
 has a
 [break-inside](#propdef-break-inside) value of
 [avoid](#valdef-break-inside-avoid), then breaking here is not allowed.

Rule 3
: Breaking at a [class B break point](#btw-lines) is allowed only if
 the number of line boxes between the break and the start of the
 enclosing block box is the value of
 [orphans](#propdef-orphans) or more, and the number of line boxes between
 the break and the end of the box is the value of
 [widows](#propdef-widows) or more.

Rule 4
: Additionally, breaking at [class B](#btw-blocks) or [class
 C](#end-block) break points is allowed only if the
 [break-inside](#propdef-break-inside) property of all ancestors is
 [auto](#valdef-break-inside-auto).

If the above doesn't provide enough break points to keep content from
overflowing the [fragmentainer](#fragmentainer), then rule 3 is dropped to provide more break points.

If that still does not lead to sufficient break points, then rules 1, 2
and 4 are dropped in order to find additional breakpoints. In this case
the UA may use the [avoid]s that are in effect at those points to
weigh the appropriateness of the new breakpoints; however, this
specification does not suggest a precise algorithm.

If even that does not lead to sufficient break points, [cloned
margins/border/padding](#valdef-box-decoration-break-clone)
at the
[block-end](https://drafts.csswg.org/css-writing-modes-4/#block-end) side are truncated; and if more room is still needed,
[cloned
margins/border/padding](#valdef-box-decoration-break-clone)
are truncated at the
[block-start](https://drafts.csswg.org/css-writing-modes-4/#block-start) side as well.

Finally, if there are no possible break points below the top of the
fragmentainer, and not all the content fits, the UA may break anywhere
in order to avoid losing content off the edge of the fragmentainer.
 In such cases, the UA may also fragment the
contents of [monolithic](#monolithic) elements by slicing the element's graphical
representation. However, the UA must not break at the top of the page,
i.e. it must place at least some content on each fragmentainer, so that
each fragmentainer has a non-zero amount of content, in order to
guarantee progress through the content.

### 4.5. Optimizing Unforced Breaks

While CSS3 requires that a [fragmented
flow](#fragmented-flow) must
break at allowed break points in order to avoid overflowing the
fragmentainers in its fragmentation context, it does not define whether
content breaks at a particular [allowed break](#unforced-breaks).
However, it is recommended that user agents observe the following
guidelines (while recognizing that they are sometimes contradictory):

- Break as few times as possible.
- Make all fragmentainers that don't end with a forced break appear to
 be equally filled with content.
- Avoid breaking inside a replaced element.

Suppose, for example, that the style sheet contains [orphans : 4],
[widows : 2], and there is space for 20 lines (line boxes)
available at the bottom of the current page, and the next block in
normal flow is considered for placement:

- If the block contains 20 line boxes or fewer, it should be placed on
 the current page.
- If the block contains 21 or 22 line boxes, the second fragment of the
 paragraph must not violate the
 [widows](#propdef-widows) constraint, and so the second fragment must
 contain at least two line boxes; likewise the first fragment must
 contain at least four line boxes.
- If the block contains 23 line boxes or more, the first fragment should
 contain 20 lines and the second fragment the remaining lines. But if
 any fragment of the block is placed on the current page, that fragment
 must contain at least four line boxes and the second fragment at least
 two line boxes.

Now suppose that [orphans](#propdef-orphans) is [10],
[widows](#propdef-widows) is [20], and there are 8 lines available at
the bottom of the current page:

- If the block contains 8 lines or fewer, it should be placed on the
 current page.
- If the block contains 9 lines or more, it must NOT be split (that
 would violate the
 [orphans](#propdef-orphans) constraint), so it must move as a block to the
 next page.

Additionally, CSS imposes one requirement: a zero-sized [box
fragment](#box-fragment), since
it does not take up space, must appear on the earlier side of a
[fragmentation
break](#fragmentation-break) if it is able to fit within the
[fragmentainer](#fragmentainer).

 A zero-sized [box
fragment](#box-fragment) will be
pushed to the next
[fragmentainer](#fragmentainer) if it is placed immediately after content that itself
overflows the [fragmentainer].

## 5. Box Model for Breaking

The sizing terminology used in this section is defined in
[\[CSS3-SIZING\]](#biblio-css3-sizing "CSS Box Sizing Module Level 3").

### 5.1. Breaking into Varying-size Fragmentainers

When a flow is fragmented into varying-size fragmentainers, the
following rules are observed for adapting layout:

- Layout is performed per-fragmentainer, with each fragmentainer
 continuing progress from the breakpoint on the previous, but
 recalculating sizes and positions using its own size as if the entire
 element were fragmented across fragmentainers of this size. Progress
 is measured in percentages (not absolute lengths) of used/remaining
 fragmentainer extent and in amount of used/remaining content. However,
 when laying out [monolithic](#monolithic) elements, the UA may instead maintain a consistent
 [inline
 size](https://drafts.csswg.org/css-sizing-3/#inline-size) and resolved [block
 size](https://drafts.csswg.org/css-sizing-3/#block-size) across fragmentainers.
- Intrinsic sizes are calculated and maintained across the entire
 element. Where an initial containing block size is needed to resolve
 an intrinsic size, assume the size of the first fragmentainer defining
 a fragmentation context.
- Fragments of boxes that began on a previous fragmentainer must obey
 placement rules with the additional constraint that fragments must not
 be positioned above the
 [block-start](https://drafts.csswg.org/css-writing-modes-4/#block-start) edge of the fragmentainer. If this results in a box's
 continuation fragment shifting away from the
 [block-start] edge of the fragmentainer, then
 [box-decoration-break:
 clone](#propdef-box-decoration-break), if specified, wraps the fragment with the
 box's margin in addition to its padding and border.

 ::: figure
 ![Illustration: Breaking in varying-size
 fragmentainers](images/Varying-Size-Fragmentainers.svg){style="width: 75%"
 width="576"}

 Illustration of breaking in varying-size fragmentainers.
 :::

Since document order of elements doesn't change during fragmentation,
fragments are processed following the same rules that apply to
continuous media. In particular, the order of floats is preserved across
all fragments and follows the same rules as defined in CSS 2.1 9.5.

Below are listed (informatively) some implications of these rules:

- Boxes (including tables) fulfilling layout constraints at their
 [stretch-fit](https://drafts.csswg.org/css-sizing-3/#stretch-fit-size) or percentage-based size may change [inline
 size](https://drafts.csswg.org/css-sizing-3/#inline-size) across pages.
- Boxes (including tables) fulfilling layout constraints at their
 [min-content](https://drafts.csswg.org/css-sizing-3/#min-content),
 [max-content](https://drafts.csswg.org/css-sizing-3/#max-content), or absolute-length size will maintain their [inline
 size](https://drafts.csswg.org/css-sizing-3/#inline-size) across pages.
- A block-level continuation fragment may be placed below the top of the
 page if, e.g. it establishes a block formatting context and is placed
 beside a float and both it and the float continue onto a narrower page
 that is too narrow to hold both of them side-by-side.
- An element adjacent to a preceding float on one page may wind up above
 the float's continuation on the next page if, e.g. that float is
 pushed down because it no longer fits side-by-side with an earlier
 float that also continues onto this narrower page.
- A left float may appear on a page *before* the remaining fragments of
 a preceding right float if that right float does not fit on the
 earlier page. However another right float will be forced down until
 the preceding right float's remaining fragment can be placed.

Here is an example that shows the use of percentage-based progress:
Suppose we have an absolutely-positioned element that is positioned
[top: calc(150% +
30px)](https://drafts.csswg.org/css-position-3/#propdef-top) and has [height: calc(100% -
10px)](https://drafts.csswg.org/css-sizing-3/#propdef-height). If it is placed into a paginated context
with a first page height of 400px, a second page of 200px, and a third
page of 600px, its layout progresses as follows:

- First, the top position is resolved against the height of the first
 page. This results in 630px. Since the first page has a height of only
 400px, layout moves to the second page, recording progress of 400/630
 = 63.49% with 36.51% left to go.
- Now on the second page, the top position is again resolved, this time
 against the height of the second page. This results in 330px. The
 remaining 36.51% of progress thus resolves to 120.5px, placing the top
 edge of the element 120.5px down the second page.
- Now the height is resolved against the second page; it resolves to
 190px. Since there are only 79.5px left on the page, layout moves to
 the third page, recording progress of 79.5/190 = 41.84%, with 58.16%
 left to go.
- On the third page, the height resolves to 590px. The remaining 58.16%
 of progress thus resolves to 343.1px, which fits on this page and
 completes the element.

### 5.2. Adjoining Margins at Breaks

When an unforced break occurs before or after a block-level box, any
margins adjoining the break are truncated to zero. When a forced break
occurs there, adjoining margins before the break are truncated, but
margins after the break are preserved. [Cloned
margins](#valdef-box-decoration-break-clone)
are always truncated to zero on block-level boxes.

 CSS Fragmentation Level 4 will introduce control over
margin truncation at breaks.

### 5.3. Splitting Boxes

When a box breaks, its content box extends to fill any [remaining
fragmentainer
extent](#remaining-fragmentainer-extent) (leaving room for any margins/borders/padding applied
by [box-decoration-break:
clone](#propdef-box-decoration-break)) before the content resumes on the next
[fragmentainer](#fragmentainer). (A [fragmentation
break](#fragmentation-break) that pushes content to the next
[fragmentainer] effectively increases the
[block
size](https://drafts.csswg.org/css-sizing-3/#block-size) of a box's contents.)

The extra [block
size](https://drafts.csswg.org/css-sizing-3/#block-size) contributed by fragmenting the box (i.e. the distance
from the break point to the edge of the
[fragmentainer](#fragmentainer)) contributes progress towards any specified limits on
the box's [block size].

![Illustration: Filling remaining fragmentainer
extent](images/Remaining-Fragmentainer-Extent.svg){style="width: 80%"
width="300"}

Illustration of filling the [remaining fragmentainer
extent](#remaining-fragmentainer-extent).

### 5.4. Fragmented Borders and Backgrounds: the [box-decoration-break property]
Name:

[box-decoration-break]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

slice
[\|](https://drafts.csswg.org/css-values-4/#comb-one) clone

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

slice

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

When a break (page/column/region/line) splits a box, the
[box-decoration-break](#propdef-box-decoration-break) property controls

- whether the box's margins, borders, padding, and other decorations
 wrap the broken edges of the box fragments
- how the
 (https://www.w3.org/TR/css3-background/#background-positioning-area)[background
 positioning
 area](https://drafts.csswg.org/css-backgrounds-3/#background-positioning-area)
 [\[CSS3BG\]](#biblio-css3bg "CSS Backgrounds and Borders Module Level 3")
 (and [mask positioning
 area](https://drafts.csswg.org/css-masking-1/#mask-positioning-area)
 [\[CSS-MASKING-1\]](#biblio-css-masking-1 "CSS Masking Module Level 1"),
 shape [reference
 box](https://drafts.csswg.org/css-shapes-1/#basic-shape-reference-box)
 [\[CSS-SHAPES-1\]](#biblio-css-shapes-1 "CSS Shapes Module Level 1"),
 etc.) is derived from or duplicated across the box fragments and how
 the element's background is drawn within them.

Values have the following meanings:

[clone]

: Each box fragment is independently wrapped with the border, padding,
 and margin. The
 [border-radius](https://drafts.csswg.org/css-borders-4/#propdef-border-radius) and
 [border-image](https://drafts.csswg.org/css-borders-4/#propdef-border-image) and
 [box-shadow](https://drafts.csswg.org/css-borders-4/#propdef-box-shadow), if any, are applied to each
 fragment independently. The background is drawn independently in
 each fragment of the element. A no-repeat background image will thus
 be rendered once in each fragment of the element.

 Cloned margins are [truncated](#break-margins) on
 block-level boxes.

[slice]

: The effect is as though the element were rendered with no breaks
 present, and then sliced by the breaks afterward: no border and no
 padding are inserted at a break; no box-shadow is drawn at a broken
 edge; and backgrounds,
 [border-radius](https://drafts.csswg.org/css-borders-4/#propdef-border-radius), and the
 [border-image](https://drafts.csswg.org/css-borders-4/#propdef-border-image) are applied to the geometry of
 the whole box as if it were unbroken.

![Illustration: (1) a single box cut in two in between two lines of text
by a page break and (2) two boxes, one before and one after the page
break, both with a border all around and their own background
image](images/box-break.png){width="450"}

Two possibilities for
[box-decoration-break](#propdef-box-decoration-break): on the left, the value
[slice](#valdef-box-decoration-break-slice), on the right the value
[clone](#valdef-box-decoration-break-clone).

UAs should also apply
[box-decoration-break](#propdef-box-decoration-break) to control rendering at
bidi-imposed breaks---​i.e. when bidi reordering causes an inline to
split into non-contiguous fragments---​and/or at display-type--imposed
breaks---​i.e. when a higher-level [display
type](https://drafts.csswg.org/css-display-4/#display-type) (such as a [block-level
box](https://drafts.csswg.org/css-display-4/#block-level-box) / [column
spanner](https://www.w3.org/TR/css-multicol-1/#spanning-columns)) splits
an incompatible ancestor (such as an [inline
box](https://drafts.csswg.org/css-display-4/#inline-box) / [block
container](https://drafts.csswg.org/css-display-4/#block-container)). Otherwise such breaks must be handled as
[slice](#valdef-box-decoration-break-slice). See [Applying the Bidirectional Reordering
Algorithm](https://drafts.csswg.org/css-writing-modes-3/#bidi-algo) in
[CSS Writing
Modes](https://drafts.csswg.org/css-writing-modes-3/#text-direction),
[CSS2§9.2 Block-level elements and block
boxes](https://www.w3.org/TR/CSS2/visuren.html#box-gen), and [CSS
Multi-column Layout §6 Spanning
Columns](https://www.w3.org/TR/css-multicol-1/#spanning-columns).

For inline elements, which side of a fragment is considered the broken
edge is determined by the parent element's inline progression direction.
For example, if an inline element whose parent has [direction:
rtl](https://drafts.csswg.org/css-writing-modes-3/#propdef-direction) breaks across two lines, the *left* edge of
the fragment on the first line will be the broken edge. (Note in
particular that neither the element's own
[direction] nor its containing
block's [direction] is used.) See
[\[CSS3-WRITING-MODES\]](#biblio-css3-writing-modes "CSS Writing Modes Level 3").

#### 5.4.1. Joining Boxes for [slice]
For [box-decoration-break:
slice](#propdef-box-decoration-break), backgrounds (and
[border-image](https://drafts.csswg.org/css-borders-4/#propdef-border-image)) are drawn as if applied to a
composite box consisting of all of the box's fragments reassembled in
visual order. This theoretical assembly occurs after the element has
been laid out (including any justification, bidi reordering, page
breaks, etc.). To assemble the composite box\...

For boxes broken across lines
: First, fragments on the same line are connected in visual order.
 Then, fragments on subsequent lines are ordered according to the
 element's [inline base
 direction](https://drafts.csswg.org/css-writing-modes-4/#inline-base-direction) and aligned on the element's dominant baseline. For
 example, in a left-to-right containing block
 ([direction](https://drafts.csswg.org/css-writing-modes-3/#propdef-direction) is
 [ltr](https://drafts.csswg.org/css-writing-modes-4/#valdef-direction-ltr)), the first fragment is the leftmost
 fragment on the first line and fragments from subsequent lines are
 put to the right of it. In a right-to-left containing block, the
 first fragment is the rightmost on the first line and subsequent
 fragments are put to the left of it.

For boxes broken across columns
: Fragments are connected as if the column boxes were glued together
 in the [block flow
 direction](https://drafts.csswg.org/css-writing-modes-4/#block-flow-direction) of the multi-column container.

For boxes broken across pages
: Fragments are connected as if page content areas were glued together
 in the [block flow
 direction](https://drafts.csswg.org/css-writing-modes-4/#block-flow-direction) of the root element.

For boxes broken across regions
: Fragments are connected as if region content areas were glued
 together in the [block flow
 direction](https://drafts.csswg.org/css-writing-modes-4/#block-flow-direction) of the [principal writing
 mode](https://drafts.csswg.org/css-writing-modes-4/#principal-writing-mode) of the [region
 chain](https://drafts.csswg.org/css-regions-1/#region-chain).

If the box fragments have different widths (heights, if the fragments
are joined horizontally), then each piece draws its portion of the
background assuming that the whole element has the same width (height)
as this piece. However, if the used height (width) of an image is
derived from the width (height) of the box, then it is calculated using
the widest fragment's width and maintained as a fixed size. This ensures
that right-aligned images stay aligned to the right edge, left-aligned
images stay aligned to the left edge, centered images stay centered, and
stretched images cover the background area as intended while preserving
continuity across fragments.

### 5.5. Transforms, Positioning, and Pagination

Fragmentation interacts with layout, and thus occurs *before* relative
positioning
[\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification"),
transforms
[\[CSS3-TRANSFORMS\]](#biblio-css3-transforms "CSS Transforms Module Level 1"),
and any other graphical effects. Such effects are applied per fragment:
for example, rotation applied to a fragmented box will calculate a
rotation origin for each fragment and independently rotate that fragment
around its origin. (The origin of an overflow-only fragment is
determined as if that content were overflowing an empty box with zero
margins/borders/padding at the start of the fragmentainer.) However, in
order to reduce dataloss when printing, the separation and transfer of
page boxes *should* occur last; thus a transformed fragment that spans
pages *should* be sliced at the page breaks and print in its entirety
rather than being clipped by its originating page.

![Illustration: Transformed overflow
fragmentation](images/fragmented-transforms.png){width="144"}

A fixed-height box spanning 2.5 pages with overflow content spanning to
a total of 4 pages. The transform origin of each fragment is the center
of its border box; the fragment without a border box assumes a
zero-height box at the start of the overflow.

Absolute positioning affects layout and thus interacts with
fragmentation. Both the coordinate system and absolutely-positioned
boxes belonging to a containing block will fragment across
fragmentainers in the same fragmentation flow as the containing block.

UAs are not required to correctly position boxes that span a
[fragmentation
break](#fragmentation-break) and whose
[block-start](https://drafts.csswg.org/css-writing-modes-4/#block-start) edge position depends on where the box's content
fragments.

UAs with memory constraints that prevent them from manipulating an
entire document in memory are not required to correctly position
absolutely-positioned elements that end up on a previously-rendered
page.

## [ Changes]
The following significant changes were made since the [4 December 2018
Candidate
Recommendation](https://www.w3.org/TR/2018/CR-css-break-3-20181204/):

- [(#bugfix-2018-drop-cloned) Fixed mistaken reference to
 "block-end" to "block-start" in rules for dropping cloned
 margins/border/padding. ([Issue
 5070](https://github.com/w3c/csswg-drafts/issues/5070))]

The following significant changes were made since the [14 January 2016
Candidate
Recommendation](https://www.w3.org/TR/2016/CR-css-break-3-20160114/):

- [(#change-2018-aliasing) Clarified the mechanism of
 aliasing for the page-break-\* properties. ([Issue
 866](https://github.com/w3c/csswg-drafts/issues/866))]

 > by treating the [page-break-\*] properties as ~~shorthands~~
 > [[legacy
 > shorthands](https://drafts.csswg.org/css-cascade-5/#legacy-shorthand)] for the [break-\*] properties

- [(#change-2017-propagation) Clarified that break
 propagation does not affect computed values and that other layout
 modes (e.g. flex and grid) make adjustments to the basic break
 propagation rules, and corrected child-to-parent propagation to ignore
 [out-of-flow](https://drafts.csswg.org/css-display-4/#out-of-flow) children. ([Issue
 2614](https://github.com/w3c/csswg-drafts/issues/2614)) See [§ 3.1.1
 Child→Parent Break
 Propagation](#break-propagation).]

- [(#change-2017-widows-applies-to) Clarified that
 [widows](#propdef-widows) and
 [orphans](#propdef-orphans) have no effect on block containers that do not
 directly contain line boxes. ([Issue
 1823](https://github.com/w3c/csswg-drafts/issues/1823))]

 > Applies to: block containers [that establish a new inline formatting
 > context]

- [(#change-2018-truncate-margins) Clarified that margins
 adjoining a Class C break are also truncated in the same way as
 margins between siblings (Class A). ([Issue
 3073](https://github.com/w3c/csswg-drafts/issues/3073))]

 > When an unforced break occurs ~~between~~ [before or after
 > a] block-level box ~~es~~ , any margins adjoining the
 > break ~~truncate to the [remaining fragmentainer
 > extent](#remaining-fragmentainer-extent) before the break, and~~ are truncated to zero
 > ~~after the break~~ .

- [(#change-2017-inline-block-fragmentation) Clarified
 what it means if a UA chooses not to treat atomic inlines as not
 [monolithic](#monolithic).
 ([Issue
 1111](https://github.com/w3c/csswg-drafts/issues/1111))]

 > Since line boxes contain no possible break points,
 > [inline-block](https://drafts.csswg.org/css-display-4/#valdef-display-inline-block) and
 > [inline-table](https://drafts.csswg.org/css-display-4/#valdef-display-inline-table) boxes (and other inline-level [display
 > types](https://drafts.csswg.org/css-display-4/#display-type) that establish an [independent formatting
 > context](https://drafts.csswg.org/css-display-4/#independent-formatting-context)) may also be considered
 > [monolithic](#monolithic)
 > [that is, in the cases where a single line box is too large to fit
 > within its fragmentainer even by itself and the UA chooses to split
 > the line box, it may fragment such boxes or it may treat them as
 > monolithic] .

- [(#change-2017-zero-fragment) Added requirement that
 zero-sized fragments must stay on the previous fragmentainer. ([Issue
 1529](https://github.com/w3c/csswg-drafts/issues/1529))]

 > Additionally, CSS imposes one requirement: a zero-sized [box
 > fragment](#box-fragment),
 > since it does not take up space, must appear on the earlier side of
 > a [fragmentation
 > break](#fragmentation-break) if it is able to fit within the
 > [fragmentainer](#fragmentainer).
 >
 > A zero-sized [box fragment](#box-fragment) can be pushed to the next
 > [fragmentainer](#fragmentainer) if it is placed immediately after content that
 > itself overflows the [fragmentainer].

- [(#change-2018-bidi-split-breaks) Clarify that
 bidi-imposed breaks and block-in-inline breaks create fragments, and
 that their formatting should be controlled by
 [box-decoration-break](#propdef-box-decoration-break). ([Issue
 1706](https://github.com/w3c/csswg-drafts/issues/1706))]

 > A box can be broken into multiple
 > [fragments](#fragment) also due
 > to bidi reordering of text (see [Applying the Bidirectional
 > Reordering
 > Algorithm](https://drafts.csswg.org/css-writing-modes-3/#bidi-algo)
 > in [CSS Writing
 > Modes](https://drafts.csswg.org/css-writing-modes-3/#text-direction))
 > or higher-level [display
 > type](https://drafts.csswg.org/css-display-4/#display-type) box splitting, e.g. [block-in-inline
 > splitting](https://www.w3.org/TR/CSS2/visuren.html#img-anon-block)
 > (see [CSS2§9.2](https://www.w3.org/TR/CSS2/visuren.html#box-gen)) or
 > [column-spanner-in-block](https://www.w3.org/TR/css-multicol-1/#spanning-columns)
 > splitting (see [CSS Multi-column
 > Layout](https://www.w3.org/TR/css-multicol-1/#spanning-columns)).
 > The division into [box
 > fragments](#box-fragment) in
 > these cases does not depend on layout (sizing/positioning of
 > content).

 > UAs ~~may~~ [should] also apply
 > [box-decoration-break](#propdef-box-decoration-break) to control rendering at
 > bidi-imposed breaks---​i.e. when bidi reordering causes an inline to
 > split into non-contiguous fragments [---​and/or at
 > display-type--imposed breaks---​i.e. when a higher-level [display
 > type](https://drafts.csswg.org/css-display-4/#display-type) (such as a [block-level
 > box](https://drafts.csswg.org/css-display-4/#block-level-box) / [column
 > spanner](https://www.w3.org/TR/css-multicol-1/#spanning-columns))
 > splits an incompatible ancestor (such as an [inline
 > box](https://drafts.csswg.org/css-display-4/#inline-box) / [block
 > container](https://drafts.csswg.org/css-display-4/#block-container))] . Otherwise such breaks must be
 > handled as
 > [slice](#valdef-box-decoration-break-slice). [See [Applying the Bidirectional Reordering
 > Algorithm](https://drafts.csswg.org/css-writing-modes-3/#bidi-algo)
 > in [CSS Writing
 > Modes](https://drafts.csswg.org/css-writing-modes-3/#text-direction),
 > [CSS2§9.2 Block-level elements and block
 > boxes](https://www.w3.org/TR/CSS2/visuren.html#box-gen), and [CSS
 > Multi-column Layout §6 Spanning
 > Columns](https://www.w3.org/TR/css-multicol-1/#spanning-columns).]

- [(#change-2017-trivial) Made a handful of trivial
 wording fixes.]
