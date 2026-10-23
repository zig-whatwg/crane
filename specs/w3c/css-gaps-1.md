## 1. Introduction

*This section is not normative.*

[CSS Multicol 1 § 4 Column Gaps and
Rules](https://drafts.csswg.org/css-multicol-1/#column-gaps-and-rules)
defined properties that allow authors to control the spacing between
columns in a [multicol
container](https://drafts.csswg.org/css-multicol-2/#multi-column-container), and to paint visible separators such as lines in those
spaces. We refer to these visible separators as [gap
decorations](#gap-decoration).

This specification expands upon the previously defined properties. It
adds equivalent properties for the row direction, applies the full set
of properties to other container types, and gives additional control
over where and how gap decorations are painted.

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

## 2. Gaps Between Boxes

While
[margin](https://drafts.csswg.org/css-box-4/#propdef-margin) and
[padding](https://drafts.csswg.org/css-box-4/#propdef-padding) can be used to specify visual
spacing around individual boxes, it's sometimes more convenient to
globally specify spacing *between* adjacent boxes within a given layout
context, particularly when the spacing is different between sibling
boxes as opposed to between the first/last box and the container's edge.

The [gap](#propdef-gap) property, and its
[row-gap](#propdef-row-gap) and
[column-gap](#propdef-column-gap) sub-properties, provide this
functionality for [multi-column](http://www.w3.org/TR/css3-multicol/),
[flex](http://www.w3.org/TR/css-flexbox/),
[grid](http://www.w3.org/TR/css-grid/), and [grid
lanes](https://www.w3.org/TR/css-grid-3/) layout.

A [gap] is either a
[column gap]
or [row gap],
whose definitions vary by type of container:

[multi-column containers](https://drafts.csswg.org/css-multicol-2/#multi-column-container)

: A [column gap](#column-gap) is
 the [gutter](#gutter) between
 adjacent [column
 boxes](https://drafts.csswg.org/css-multicol-2/#column-box), see
 [\[CSS-MULTICOL-1\]](#biblio-css-multicol-1 "CSS Multi-column Layout Module Level 1").

 A [row gap](#row-gap) is the
 [gutter](#gutter) between the rows
 of [column
 boxes](https://drafts.csswg.org/css-multicol-2/#column-box) established by
 [column-height](https://drafts.csswg.org/css-multicol-2/#propdef-column-height), see
 [\[CSS-MULTICOL-2\]](#biblio-css-multicol-2 "CSS Multi-column Layout Module Level 2").

[flex containers](https://drafts.csswg.org/css-flexbox-2/#flex-container)

: When applied to the [main
 axis](https://drafts.csswg.org/css-flexbox-2/#main-axis) (e.g. [column
 gap](#column-gap) in a
 [row] [flex
 container](https://drafts.csswg.org/css-flexbox-2/#flex-container)), refers to the [gutter](#gutter) between items (as if an additional fixed-size
 margin were inserted between adjacent [flex
 items](https://drafts.csswg.org/css-flexbox-2/#flex-item) in a single line).

 When applied to the [cross
 axis](https://drafts.csswg.org/css-flexbox-2/#cross-axis) (e.g. [row gap](#row-gap) in a [row] [flex
 container](https://drafts.csswg.org/css-flexbox-2/#flex-container)), refers to the [gutter](#gutter) between adjacent [flex
 lines](https://drafts.csswg.org/css-flexbox-2/#flex-line).

[grid containers](https://drafts.csswg.org/css-grid-2/#grid-container) other than [grid lanes containers](https://drafts.csswg.org/css-grid-3/#grid-lanes-container)
: [Row gap](#row-gap) and [column
 gap](#column-gap), in the
 context of a [grid
 container](https://drafts.csswg.org/css-grid-2/#grid-container), refer to the [gutters](#gutter) between [grid
 rows](https://drafts.csswg.org/css-grid-2/#grid-row) and [grid
 columns](https://drafts.csswg.org/css-grid-2/#grid-column), respectively. See [CSS Grid Layout 1 § 10.1
 Gutters: the row-gap, column-gap, and gap
 properties](https://drafts.csswg.org/css-grid-1/#gutters) for
 precise details.

[grid lanes containers](https://drafts.csswg.org/css-grid-3/#grid-lanes-container)

: When applied to the [grid
 axis](https://drafts.csswg.org/css-grid-3/#grid-axis) (e.g. [column
 gap](#column-gap) in a [grid
 lanes
 container](https://drafts.csswg.org/css-grid-3/#grid-lanes-container) with column tracks), refers to the
 [gutter](#gutter) between adjacent
 [grid
 tracks](https://drafts.csswg.org/css-grid-2/#grid-track).

 When applied to the [stacking
 axis](https://drafts.csswg.org/css-grid-3/#stacking-axis) (e.g. [row gap](#row-gap) in a [grid lanes
 container](https://drafts.csswg.org/css-grid-3/#grid-lanes-container) with column tracks), refers to the
 [gutter](#gutter) between items in
 each [grid
 track](https://drafts.csswg.org/css-grid-2/#grid-track).

 See [CSS Grid Layout 3 § 6.1 Gutters: the row-gap, column-gap, and
 gap properties](https://drafts.csswg.org/css-grid-3/#gutters) for
 precise details.

Gutters effect a minimum spacing between items: additional spacing may
be added by
[justify-content](https://drafts.csswg.org/css-align-3/#propdef-justify-content)/[align-content](https://drafts.csswg.org/css-align-3/#propdef-align-content). Such additional space increases
the size of the corresponding [gaps](#gap).

In all cases, the [gap](#gap) disappears
when it coincides with a [fragmentation
break](https://drafts.csswg.org/css-break-4/#fragmentation-break).
[\[CSS-BREAK-3\]](#biblio-css-break-3 "CSS Fragmentation Module Level 3")

 Table boxes do not use the
[gap](#propdef-gap) properties to specify separation between their
cells. Instead, they use the
[border-spacing](https://drafts.csswg.org/css2/#propdef-border-spacing) property, which has slightly
different functionality: it inherits, and it also specifies the
additional spacing between the outermost cells and the border of the
table (similar to
[space-evenly](https://drafts.csswg.org/css-align-3/#valdef-align-content-space-evenly) rather than
[space-between](https://drafts.csswg.org/css-align-3/#valdef-align-content-space-between)).

![[Column gaps](#column-gap) in
orange in a multicol container with a spanner element. Note that [column
gaps] break when they encounter the
spanner.](images/multicol-gaps-2.png){height="236" width="322"}

![Gaps in a multicol container with \`column-wrap: wrap\`; [column
gaps](#column-gap) in orange and
[row gaps](#row-gap) in blue. Note
that [column gaps] in multicol containers do not
overlap [row gaps], similar to
flex.](images/multicol-gaps.png){height="217" width="322"}

![Gaps in a grid container; [column
gaps](#column-gap) in orange and
[row gaps](#row-gap) in blue. Note
the shaded areas where gaps overlap.](images/grid-gaps.png){height="239"
width="358"}

![Gaps in a flex container; [column
gaps](#column-gap) in orange and
[row gaps](#row-gap) in blue. Note
that, unlike in grid, gaps in flex do not
overlap.](images/flex-gaps.png){height="396" width="525"}

![Gaps in a grid lanes container; [column
gaps](#column-gap) in orange and
[row gaps](#row-gap) in blue. Note
that the [row gaps] are staggered between
tracks.](images/grid-lanes-gaps.png){height="402" width="466"}

![[Row gaps](#row-gap) in blue in a
four-column grid lanes container with spanning items. Note that the gap
before full-width item 5 has one segment in each track, as described in
[CSS Grid Layout 3 § 6.1 Gutters: the row-gap, column-gap, and gap
properties](https://drafts.csswg.org/css-grid-3/#gutters).](images/grid-lanes-gaps-span.png){height="402"
width="466"}

![Gaps in a grid lanes container with spanning items; [column
gaps](#column-gap) in orange and
[row gaps](#row-gap) in blue. Note
that the empty spaces due to item placement below items 2 and 3 are not
part of the [row gaps], as described in [CSS Grid
Layout 3 § 6.1 Gutters: the row-gap, column-gap, and gap
properties](https://drafts.csswg.org/css-grid-3/#gutters).](images/grid-lanes-gap-space.png){height="402"
width="466"}

### 2.1. Row and Column Gutters: the [row-gap and [column-gap](#propdef-column-gap) properties]
Name:

[row-gap], [column-gap]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

normal
[\|](https://drafts.csswg.org/css-values-4/#comb-one) [\<length-percentage
\[0,∞\]\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage) [\|]
[\<line-width\>](https://drafts.csswg.org/css-backgrounds-3/#typedef-line-width)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

normal

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[multi-column
containers](https://drafts.csswg.org/css-multicol-2/#multi-column-container), [flex
containers](https://drafts.csswg.org/css-flexbox-2/#flex-container), [grid
containers](https://drafts.csswg.org/css-grid-2/#grid-container), and [grid lanes
containers](https://drafts.csswg.org/css-grid-3/#grid-lanes-container)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

see [§ 2.3 Percentages In gap Properties](#gap-percent)

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

specified keyword, else a computed
[\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage) value

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value type

These properties specify fixed-length [gutters] between items in the
container, adding space between them---​in a manner similar to the
[space-between](https://drafts.csswg.org/css-align-3/#valdef-align-content-space-between) keyword of the [content-distribution
properties](https://drafts.csswg.org/css-align-3/#content-distribution-properties), but of a fixed size instead of as a fraction of
remaining space. The
[column-gap](#propdef-column-gap) property specifies spacing between
"columns", separating boxes in the container's [inline
axis](https://drafts.csswg.org/css-writing-modes-4/#inline-axis) similar to [inline-axis] margin;
while [row-gap](#propdef-row-gap) indicates spacing between "rows",
separating boxes in the container's [block
axis](https://drafts.csswg.org/css-writing-modes-4/#block-axis).

Values have the following meanings:

[\<length-percentage \[0,∞\]\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage)\
[\<line-width\>](https://drafts.csswg.org/css-backgrounds-3/#typedef-line-width)

: Specifies a [row gap](#row-gap)
 or [column gap](#column-gap)
 as defined by the layout modes to which it applies.

 Negative values are invalid. For percentages, see [§ 2.3 Percentages
 In gap Properties](#gap-percent).

[normal]

: The value
 [normal](#valdef-row-gap-normal) represents a used value of [1em] on
 [multi-column
 containers](https://drafts.csswg.org/css-multicol-2/#multi-column-container), and a used value of [0px] in all other
 contexts.

### 2.2. Gap Shorthand: the [gap property]
Name:

[gap]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<\'row-gap\'\>](#propdef-row-gap)
[\<\'column-gap\'\>](#propdef-column-gap)[?](https://drafts.csswg.org/css-values-4/#mult-opt)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

see individual properties

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[multi-column
containers](https://drafts.csswg.org/css-multicol-2/#multi-column-container), [flex
containers](https://drafts.csswg.org/css-flexbox-2/#flex-container), [grid
containers](https://drafts.csswg.org/css-grid-2/#grid-container), and [grid lanes
containers](https://drafts.csswg.org/css-grid-3/#grid-lanes-container)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

refer to corresponding dimension of the content area

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

see individual properties

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value type

This property is a
[shorthand](https://drafts.csswg.org/css-cascade-5/#shorthand-property) that sets
[row-gap](#propdef-row-gap) and
[column-gap](#propdef-column-gap) in one declaration. If
[\<\'column-gap\'\>] is
omitted, it's set to the same value as
[\<\'row-gap\'\>].

!(images/gutters-gaps.svg){a
height="616" width="500"}

 The [gap](#propdef-gap) property is only one component of the
visible "gutter" or "alley" created between boxes. Margins, padding, or
the use of distributed alignment may increase the visible separation
between boxes beyond what is specified in [gap].

### 2.3. Percentages In [gap Properties]
In general, gaps introduced by the
[gap](#propdef-gap) properties are intended to act like an empty
item/track/etc with the gap's size; in other words, an author should be
able to reproduce the effects of [gap]
by just inserting additional empty items/tracks/etc into the container.

[gap](#propdef-gap) always resolves percentages against the
corresponding size of the [content
box](https://drafts.csswg.org/css-box-4/#content-box) of the element. When this size is definite, the
behavior is well-defined and consistent across layout modes. But since
different layout modes treat [cyclic percentage
sizes](https://drafts.csswg.org/css-sizing-3/#cyclic-percentage-size) for items/tracks/etc differently,
[gap] does as well:

In Grid Layout

: [As in the min size properties and
 margins/paddings](https://www.w3.org/TR/css-sizing-3/#percentage-sizing)
 [\[CSS-SIZING-3\]](#biblio-css-sizing-3 "CSS Box Sizing Module Level 3"),
 [cyclic percentage
 sizes](https://drafts.csswg.org/css-sizing-3/#cyclic-percentage-size) resolve against zero for determining intrinsic size
 contributions, but resolve against the box's content box when laying
 out the box's contents.

In Flex Layout

: [Cyclic percentage
 sizes](https://drafts.csswg.org/css-sizing-3/#cyclic-percentage-size) resolve against zero in all cases.

### 2.4. Legacy Gap Properties: the [grid-row-gap, [grid-column-gap](#propdef-grid-column-gap), and [grid-gap](#propdef-grid-gap) properties]
The Grid Layout module was originally written with its own set of
[gutter](#gutter) properties, before
all such properties were unified into the existing
[row-gap](#propdef-row-gap)/[column-gap](#propdef-column-gap) naming. For compatibility with
legacy content, these grid-prefixed names must be supported as follows:

- [grid-row-gap] as a [legacy name
 alias](https://drafts.csswg.org/css-cascade-5/#legacy-name-alias) of the
 [row-gap](#propdef-row-gap) property

- [grid-column-gap] as a [legacy name
 alias](https://drafts.csswg.org/css-cascade-5/#legacy-name-alias) of the
 [column-gap](#propdef-column-gap) property

- [grid-gap] as a [legacy name
 alias](https://drafts.csswg.org/css-cascade-5/#legacy-name-alias) of the [gap](#propdef-gap) property

## 3. Gap decorations

[Gaps](#gap) may contain a [gap
decoration], which is a visible separator (such as a line) painted
between adjacent boxes.

[Gap decorations](#gap-decoration) do not take up space. That is, the presence or width of
a [gap decoration] will not alter the
placement of anything else. If a [gap
decoration] is wider than its gap, any
adjacent boxes will overlap the decoration, and in some cases the
decoration may extend outside the box of the container.

[Gap decorations](#gap-decoration) are painted just above the border of the container. For
scrollable containers, note that while the border and background of the
container aren't scrolled, the decorations need to scroll along with
items in the container.

[Gap decorations](#gap-decoration) follow the definitions of \"column\" and \"row\" laid
out by the container to which the properties are applied. They depend on
the container type taking [writing
mode](https://drafts.csswg.org/css-writing-modes-4/#writing-mode) into account when determining the meanings of these
terms. For examples, see: [CSS Multicol 2 § 3 The multi-column
model](https://drafts.csswg.org/css-multicol-2/#the-multi-column-model),
[CSS Flexbox 1 § 5.1 Flex Flow Direction: the flex-direction
property](https://drafts.csswg.org/css-flexbox-1/#flex-direction-property),
and [CSS Grid Layout 1 § 3 Grid Layout Concepts and
Terminology](https://drafts.csswg.org/css-grid-1/#grid-concepts).

Properties in this specification whose names begin with \"column\" apply
to [column gaps](#column-gap),
and properties in this specification whose names begin with \"row\"
apply to [row gaps](#row-gap).

### 3.1. Geometry

[Gap decorations](#gap-decoration) are painted within a [gap](#gap) as one or more [gap decoration
segments](#gap-decoration-segment).

#### 3.1.1. Segment endpoints

A [segment endpoint] is a point on a [gap's](#gap) centerline where a [gap decoration
segment](#gap-decoration-segment) may start or end. There are two endpoint types:

- [start segment endpoint]: Point closest to the
 [start](https://drafts.csswg.org/css-writing-modes-4/#css-start) side of the [gap](#gap).
- [end segment endpoint]: Point closest to the
 [end](https://drafts.csswg.org/css-writing-modes-4/#css-end) side of the [gap](#gap).

To [create segment endpoints] for a gap `G`:

1. Bounds of a Gap:

 Create endpoints at `G`'s two bounds:

 - At the centerpoint of `G`'s start edge, create a [start
 segment
 endpoint](#start-segment-endpoint).
 - At the centerpoint of `G`'s end edge, create an [end
 segment
 endpoint](#end-segment-endpoint).

 When a gap runs to the content boundary, these endpoints coincide
 with the corresponding content edge.

2. Within a Gap:

 A [gap junction] is a region of `G` where one or more
 [gaps](#gap) abut or overlap
 `G`. Two [segment
 endpoints](#segment-endpoint) are created for each [gap
 junction](#gap-junction):

 - Entering a [gap junction](#gap-junction): At the point where a cross gap appears on at
 least one side of `G`, create an [end segment
 endpoint](#end-segment-endpoint).
 - Exiting a [gap junction](#gap-junction): At the point where no cross gap exists on either
 side of `G`, create a [start segment
 endpoint](#start-segment-endpoint).

 This ordering (end segment endpoint, start segment endpoint)
 reflects that the [gap
 junction](#gap-junction)
 corresponds to the end of one track/item/column and the beginning of
 another.

The following examples illustrate the locations of [segment
endpoints](#segment-endpoint), with a purple [+]{style="color:#72C"} for [start
segment
endpoints](#start-segment-endpoint) and a green [+]{style="color:#285"} for [end segment
endpoints](#end-segment-endpoint) in each case. [Gap
junctions](#gap-junction) are
shown with a dashed box.

.grid-with-spans {
 display: grid;
 grid-template: repeat(4, 100px) / repeat(4, 100px);
 gap: 20px;
 background: rgb(255 255 128);
 }
 .grid > * {
 border: 1px dashed black;
 }

![Locations of [segment
endpoints](#segment-endpoint) and [gap
junctions](#gap-junction) in a
grid with spanning items. [Segment
endpoints] are created at the bounds of each
gap (which coincide with the edges of the container), and within each
gap in an end-start manner where the row and column gaps
overlap.](images/example-grid-segment-endpoints.png){height="505"
width="497"}

.flex {
 display: flex;
 flex-wrap: wrap;
 gap: 20px;
 width: 500px;
 background: rgb(255 255 128);
 }
 .flex > * {
 border: 1px dashed black;
 }

![Locations of [segment
endpoints](#segment-endpoint) and [gap
junctions](#gap-junction) in a
flex container. Column gaps create endpoints at their bounds; some
bounds coincide with the container edges (like the start of the gaps
between #1 and #2, and #2 and #3 which coincide with the top edge of the
container, and the end of the gap between #7 and #8 which coincides with
the bottom edge of the container). Row gaps (between flex lines) create
endpoints at their bounds, which coincide with the left and right edges
of the container. Where column gaps abut row gaps, two endpoints are
created in an end-start
manner.](images/flex-and-segment-endpoints.png){height="373"
width="534"}

.multi-column {
 column-count: 3;
 column-width: 100px;
 column-height: 50px;
 column-wrap: wrap;
 gap: 20px;
 background: rgb(255 255 128);
 }

 .multi-column > * {
 height: 100px;
 border: 1px dashed black;
 }

![Locations of [segment
endpoints](#segment-endpoint) and [gap
junctions](#gap-junction) in a
multi-column container. Column gaps (between column boxes) create
endpoints at their bounds; some bounds coincide with the container edges
(like the starts of the first 2 column gaps which coincide with the top
edge, and the ends of the last 2 column gaps which coincide with the
bottom edge). The row gap (between rows of column boxes) creates
endpoints at its bounds, which coincide with the left and right edges of
the container. Where column gaps abut the row gap, two endpoints are
created in an end-start
manner.](images/multi-col-segment-endpoints.png){height="258"
width="528"}

#### 3.1.2. Gap decoration segments

##### [ Definitions]
A [gap decoration segment] is formed by pairing a [start segment
endpoint](#start-segment-endpoint) with an [end segment
endpoint](#end-segment-endpoint). Each [gap](#gap) forms
a collection of [gap decoration
segments](#gap-decoration-segment).

In this section, we represent a [gap decoration
segment](#gap-decoration-segment) `s` as
`s`` = [``s``.start, ``s``.end]`, where
`s``.start` is the [start segment
endpoint](#start-segment-endpoint) of the segment, and `s``.end` is the [end
segment endpoint](#end-segment-endpoint) of the segment.

Let [UNION](`s1`, `s2`) be equal to
\[`s1`.start, `s2`.end\].

A [gap decoration
segment](#gap-decoration-segment) is [flanked by spanning
items] if, for every [gap
junction](#gap-junction) between
its endpoints, there exist items on opposing sides of the gap that span
across all perpendicular [gaps](#gap)
contributing to that junction.

In the context of a given [gap](#gap), a
pair of [segment
endpoints](#segment-endpoint) `a` and `b` is considered
[discontiguous] if a line segment from `a` to `b`,
with the same width as the [gap], intersects a child
item in the container.

##### [ Algorithms]
To [determine gap decoration
segments] for a given [gap](#gap) `G`:

1. Let `S` be an empty list.

2. Let `endpoints` be the result of [creating segment
 endpoints](#create-segment-endpoints) for `G`, ordered by their position along
 `G`'s centerline from start to end.

 This list is guaranteed to contain an even number
 of elements that strictly alternate between [start segment
 endpoint](#start-segment-endpoint) and [end segment
 endpoint](#end-segment-endpoint), beginning with a [start segment
 endpoint].

3. If `endpoints` is empty, return `S`.

4. Let `break` be the used value of either
 [column-rule-break](#propdef-column-rule-break) or
 [row-rule-break](#propdef-row-rule-break), whichever applies to the gap.

5. If `break` is
 [none](#valdef-column-rule-break-none):
 1. Let `first` be the first item in
 `endpoints`.
 2. Let `last` be the last item in
 `endpoints`.
 3. Create a [gap decoration
 segment](#gap-decoration-segment) `segment` = \[`first`,
 `last`\].
 4. [Apply offsets
 to](#apply-offsets-to-a-segment) `segment`, then append it to
 `S`.
 5. Return `S`.

6. *Empty Check:* If `endpoints` is empty, return
 `S`.

7. Create a [gap decoration
 segment](#gap-decoration-segment) `s` from the first two items in
 `endpoints`. Remove them both from the list.

8. If `s`'s endpoints are
 [discontiguous](#discontiguous), go back to *Empty Check*.

9. While `endpoints` is not empty:
 1. Create a [gap decoration
 segment](#gap-decoration-segment) `next` from the first two items in
 `endpoints`, leaving them both in the list.
 2. Let `candidate` be [UNION](#union)(`s`, `next`).
 3. If `candidate`'s endpoints are
 [discontiguous](#discontiguous), exit this loop.
 4. If `break` is
 [intersection](#valdef-column-rule-break-intersection) and `candidate` is not
 [flanked by spanning
 items](#flanked-by-spanning-items), exit this loop.
 5. Remove the first two items from `endpoints`.
 6. Set `s` to [UNION](#union)(`s`, `next`).

10. [Apply offsets
 to](#apply-offsets-to-a-segment) `s`, then append it to `S`.

11. Go back to *Empty Check*.

To [apply offsets to a segment] `s` =
\[`start`, `end`\]:

1. Offset `start` by the used value of the applicable
 [rule-inset](#inset) property.
2. Offset `end` by the used value of the applicable
 [rule-inset](#inset) property.
3. Update `s` with the adjusted \[`start`,
 `end`\].

![Illustration of [gap decoration
segments](#gap-decoration-segment) (blue and red rectangles) in a grid container. The
segments are drawn between pairs of [segment
endpoints](#segment-endpoint), with [start segment
endpoints](#start-segment-endpoint) marked with purple crosses and [end segment
endpoints](#end-segment-endpoint) marked with green
crosses.](images/grid-gap-decoration-segments.png){height="232"
width="354"}

![Illustration of [gap decoration
segments](#gap-decoration-segment) (blue and red rectangles) in a flex container. The
segments are drawn between pairs of [segment
endpoints](#segment-endpoint), with [start segment
endpoints](#start-segment-endpoint) marked with purple crosses and [end segment
endpoints](#end-segment-endpoint) marked with green
crosses.](images/flex-gap-decoration-segments.png){height="231"
width="311"}

![Illustration of [gap decoration
segments](#gap-decoration-segment) (blue and red rectangles) in a multicol container (with
column-wrap: wrap). The segments are drawn between pairs of [segment
endpoints](#segment-endpoint), with [start segment
endpoints](#start-segment-endpoint) marked with purple crosses and [end segment
endpoints](#end-segment-endpoint) marked with green
crosses.](images/multicol-gap-decoration-segments.png){height="154"
width="234"}

![Illustration of [gap decoration
segments](#gap-decoration-segment) in a [grid lanes
container](https://drafts.csswg.org/css-grid-3/#grid-lanes-container), with [start segment
endpoints](#start-segment-endpoint) marked with purple crosses and [end segment
endpoints](#end-segment-endpoint) marked with green crosses. Note that spanning item 4
has a separate segment in each track it
spans.](images/grid-lanes-spanner-segments.png){height="402"
width="466"}

![Illustration of [gap decoration
segments](#gap-decoration-segment) (blue and red rectangles) in a flex container. The
segments are drawn between pairs of [segment
endpoints](#segment-endpoint), with [start segment
endpoints](#start-segment-endpoint) marked with purple crosses and [end segment
endpoints](#end-segment-endpoint) marked with green
crosses.](images/flex-negative-gap-decoration-segments.png){height="233"
width="312"}

![Illustration of [gap decoration
segments](#gap-decoration-segment) (blue and red rectangles) in a flex container. The
segments are drawn between pairs of [segment
endpoints](#segment-endpoint), with [start segment
endpoints](#start-segment-endpoint) marked with purple crosses and [end segment
endpoints](#end-segment-endpoint) marked with green
crosses.](images/flex-negative-gap-decoration-segments-example-2.png){height="303"
width="617"}

- [flex-gap-decorations-001.html](https://wpt.fyi/results/css/css-gaps/flex/flex-gap-decorations-001.html "css/css-gaps/flex/flex-gap-decorations-001.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/flex/flex-gap-decorations-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/flex/flex-gap-decorations-001.html)
- [flex-gap-decorations-006.html](https://wpt.fyi/results/css/css-gaps/flex/flex-gap-decorations-006.html "css/css-gaps/flex/flex-gap-decorations-006.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/flex/flex-gap-decorations-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/flex/flex-gap-decorations-006.html)
- [flex-gap-decorations-007.html](https://wpt.fyi/results/css/css-gaps/flex/flex-gap-decorations-007.html "css/css-gaps/flex/flex-gap-decorations-007.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/flex/flex-gap-decorations-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/flex/flex-gap-decorations-007.html)
- [flex-gap-decorations-008.html](https://wpt.fyi/results/css/css-gaps/flex/flex-gap-decorations-008.html "css/css-gaps/flex/flex-gap-decorations-008.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/flex/flex-gap-decorations-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/flex/flex-gap-decorations-008.html)
- [flex-gap-decorations-015.html](https://wpt.fyi/results/css/css-gaps/flex/flex-gap-decorations-015.html "css/css-gaps/flex/flex-gap-decorations-015.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/flex/flex-gap-decorations-015.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/flex/flex-gap-decorations-015.html)
- [flex-gap-decorations-016.html](https://wpt.fyi/results/css/css-gaps/flex/flex-gap-decorations-016.html "css/css-gaps/flex/flex-gap-decorations-016.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/flex/flex-gap-decorations-016.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/flex/flex-gap-decorations-016.html)
- [flex-gap-decorations-020.html](https://wpt.fyi/results/css/css-gaps/flex/flex-gap-decorations-020.html "css/css-gaps/flex/flex-gap-decorations-020.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/flex/flex-gap-decorations-020.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/flex/flex-gap-decorations-020.html)
- [flex-gap-decorations-021.html](https://wpt.fyi/results/css/css-gaps/flex/flex-gap-decorations-021.html "css/css-gaps/flex/flex-gap-decorations-021.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/flex/flex-gap-decorations-021.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/flex/flex-gap-decorations-021.html)
- [flex-gap-decorations-022.html](https://wpt.fyi/results/css/css-gaps/flex/flex-gap-decorations-022.html "css/css-gaps/flex/flex-gap-decorations-022.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/flex/flex-gap-decorations-022.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/flex/flex-gap-decorations-022.html)
- [flex-gap-decorations-023.html](https://wpt.fyi/results/css/css-gaps/flex/flex-gap-decorations-023.html "css/css-gaps/flex/flex-gap-decorations-023.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/flex/flex-gap-decorations-023.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/flex/flex-gap-decorations-023.html)
- [flex-gap-decorations-024.html](https://wpt.fyi/results/css/css-gaps/flex/flex-gap-decorations-024.html "css/css-gaps/flex/flex-gap-decorations-024.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/flex/flex-gap-decorations-024.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/flex/flex-gap-decorations-024.html)
- [flex-gap-decorations-025.html](https://wpt.fyi/results/css/css-gaps/flex/flex-gap-decorations-025.html "css/css-gaps/flex/flex-gap-decorations-025.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/flex/flex-gap-decorations-025.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/flex/flex-gap-decorations-025.html)
- [flex-gap-decorations-026-crash.html](https://wpt.fyi/results/css/css-gaps/flex/flex-gap-decorations-026-crash.html "css/css-gaps/flex/flex-gap-decorations-026-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/flex/flex-gap-decorations-026-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/flex/flex-gap-decorations-026-crash.html)
- [flex-gap-decorations-027.html](https://wpt.fyi/results/css/css-gaps/flex/flex-gap-decorations-027.html "css/css-gaps/flex/flex-gap-decorations-027.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/flex/flex-gap-decorations-027.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/flex/flex-gap-decorations-027.html)
- [flex-gap-decorations-032.html](https://wpt.fyi/results/css/css-gaps/flex/flex-gap-decorations-032.html "css/css-gaps/flex/flex-gap-decorations-032.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/flex/flex-gap-decorations-032.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/flex/flex-gap-decorations-032.html)
- [flex-gap-decorations-033.html](https://wpt.fyi/results/css/css-gaps/flex/flex-gap-decorations-033.html "css/css-gaps/flex/flex-gap-decorations-033.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/flex/flex-gap-decorations-033.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/flex/flex-gap-decorations-033.html)
- [flex-gap-decorations-039.html](https://wpt.fyi/results/css/css-gaps/flex/flex-gap-decorations-039.html "css/css-gaps/flex/flex-gap-decorations-039.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/flex/flex-gap-decorations-039.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/flex/flex-gap-decorations-039.html)
- [flex-gap-decorations-040.html](https://wpt.fyi/results/css/css-gaps/flex/flex-gap-decorations-040.html "css/css-gaps/flex/flex-gap-decorations-040.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/flex/flex-gap-decorations-040.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/flex/flex-gap-decorations-040.html)
- [flex-gap-decorations-041.html](https://wpt.fyi/results/css/css-gaps/flex/flex-gap-decorations-041.html "css/css-gaps/flex/flex-gap-decorations-041.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/flex/flex-gap-decorations-041.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/flex/flex-gap-decorations-041.html)
- [flex-gap-decorations-042.html](https://wpt.fyi/results/css/css-gaps/flex/flex-gap-decorations-042.html "css/css-gaps/flex/flex-gap-decorations-042.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/flex/flex-gap-decorations-042.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/flex/flex-gap-decorations-042.html)
- [flex-gap-decorations-043.html](https://wpt.fyi/results/css/css-gaps/flex/flex-gap-decorations-043.html "css/css-gaps/flex/flex-gap-decorations-043.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/flex/flex-gap-decorations-043.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/flex/flex-gap-decorations-043.html)
- [flex-gap-decorations-044.html](https://wpt.fyi/results/css/css-gaps/flex/flex-gap-decorations-044.html "css/css-gaps/flex/flex-gap-decorations-044.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/flex/flex-gap-decorations-044.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/flex/flex-gap-decorations-044.html)
- [flex-gap-decorations-045.html](https://wpt.fyi/results/css/css-gaps/flex/flex-gap-decorations-045.html "css/css-gaps/flex/flex-gap-decorations-045.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/flex/flex-gap-decorations-045.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/flex/flex-gap-decorations-045.html)
- [flex-gap-decorations-046.html](https://wpt.fyi/results/css/css-gaps/flex/flex-gap-decorations-046.html "css/css-gaps/flex/flex-gap-decorations-046.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/flex/flex-gap-decorations-046.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/flex/flex-gap-decorations-046.html)
- [flex-gap-decorations-047.html](https://wpt.fyi/results/css/css-gaps/flex/flex-gap-decorations-047.html "css/css-gaps/flex/flex-gap-decorations-047.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/flex/flex-gap-decorations-047.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/flex/flex-gap-decorations-047.html)
- [flex-gap-decorations-048.html](https://wpt.fyi/results/css/css-gaps/flex/flex-gap-decorations-048.html "css/css-gaps/flex/flex-gap-decorations-048.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/flex/flex-gap-decorations-048.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/flex/flex-gap-decorations-048.html)
- [flex-gap-decorations-049.html](https://wpt.fyi/results/css/css-gaps/flex/flex-gap-decorations-049.html "css/css-gaps/flex/flex-gap-decorations-049.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/flex/flex-gap-decorations-049.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/flex/flex-gap-decorations-049.html)
- [flex-gap-decorations-056.html](https://wpt.fyi/results/css/css-gaps/flex/flex-gap-decorations-056.html "css/css-gaps/flex/flex-gap-decorations-056.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/flex/flex-gap-decorations-056.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/flex/flex-gap-decorations-056.html)
- [flex-gap-decorations-057.html](https://wpt.fyi/results/css/css-gaps/flex/flex-gap-decorations-057.html "css/css-gaps/flex/flex-gap-decorations-057.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/flex/flex-gap-decorations-057.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/flex/flex-gap-decorations-057.html)
- [flex-gap-decorations-058.html](https://wpt.fyi/results/css/css-gaps/flex/flex-gap-decorations-058.html "css/css-gaps/flex/flex-gap-decorations-058.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/flex/flex-gap-decorations-058.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/flex/flex-gap-decorations-058.html)
- [flex-gap-decorations-059.html](https://wpt.fyi/results/css/css-gaps/flex/flex-gap-decorations-059.html "css/css-gaps/flex/flex-gap-decorations-059.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/flex/flex-gap-decorations-059.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/flex/flex-gap-decorations-059.html)
- [flex-gap-decorations-060.html](https://wpt.fyi/results/css/css-gaps/flex/flex-gap-decorations-060.html "css/css-gaps/flex/flex-gap-decorations-060.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/flex/flex-gap-decorations-060.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/flex/flex-gap-decorations-060.html)
- [flex-gap-decorations-061.html](https://wpt.fyi/results/css/css-gaps/flex/flex-gap-decorations-061.html "css/css-gaps/flex/flex-gap-decorations-061.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/flex/flex-gap-decorations-061.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/flex/flex-gap-decorations-061.html)
- [flex-gap-decorations-repaint-on-child-resize.html](https://wpt.fyi/results/css/css-gaps/flex/flex-gap-decorations-repaint-on-child-resize.html "css/css-gaps/flex/flex-gap-decorations-repaint-on-child-resize.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/flex/flex-gap-decorations-repaint-on-child-resize.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/flex/flex-gap-decorations-repaint-on-child-resize.html)
- [flex-gap-decorations-repaint-on-container-shift.html](https://wpt.fyi/results/css/css-gaps/flex/flex-gap-decorations-repaint-on-container-shift.html "css/css-gaps/flex/flex-gap-decorations-repaint-on-container-shift.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/flex/flex-gap-decorations-repaint-on-container-shift.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/flex/flex-gap-decorations-repaint-on-container-shift.html)
- [flex-gap-decorations-writing-mode.html](https://wpt.fyi/results/css/css-gaps/flex/flex-gap-decorations-writing-mode.html "css/css-gaps/flex/flex-gap-decorations-writing-mode.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/flex/flex-gap-decorations-writing-mode.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/flex/flex-gap-decorations-writing-mode.html)
- [grid-gap-decorations-001.html](https://wpt.fyi/results/css/css-gaps/grid/grid-gap-decorations-001.html "css/css-gaps/grid/grid-gap-decorations-001.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/grid-gap-decorations-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/grid-gap-decorations-001.html)
- [grid-gap-decorations-029.html](https://wpt.fyi/results/css/css-gaps/grid/grid-gap-decorations-029.html "css/css-gaps/grid/grid-gap-decorations-029.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/grid-gap-decorations-029.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/grid-gap-decorations-029.html)
- [grid-gap-decorations-030.html](https://wpt.fyi/results/css/css-gaps/grid/grid-gap-decorations-030.html "css/css-gaps/grid/grid-gap-decorations-030.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/grid-gap-decorations-030.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/grid-gap-decorations-030.html)
- [grid-gap-decorations-031.html](https://wpt.fyi/results/css/css-gaps/grid/grid-gap-decorations-031.html "css/css-gaps/grid/grid-gap-decorations-031.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/grid-gap-decorations-031.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/grid-gap-decorations-031.html)
- [grid-gap-decorations-032.html](https://wpt.fyi/results/css/css-gaps/grid/grid-gap-decorations-032.html "css/css-gaps/grid/grid-gap-decorations-032.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/grid-gap-decorations-032.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/grid-gap-decorations-032.html)
- [grid-gap-decorations-033.html](https://wpt.fyi/results/css/css-gaps/grid/grid-gap-decorations-033.html "css/css-gaps/grid/grid-gap-decorations-033.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/grid-gap-decorations-033.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/grid-gap-decorations-033.html)
- [grid-gap-decorations-034.html](https://wpt.fyi/results/css/css-gaps/grid/grid-gap-decorations-034.html "css/css-gaps/grid/grid-gap-decorations-034.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/grid-gap-decorations-034.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/grid-gap-decorations-034.html)
- [grid-gap-decorations-035.html](https://wpt.fyi/results/css/css-gaps/grid/grid-gap-decorations-035.html "css/css-gaps/grid/grid-gap-decorations-035.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/grid-gap-decorations-035.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/grid-gap-decorations-035.html)
- [grid-gap-decorations-036.html](https://wpt.fyi/results/css/css-gaps/grid/grid-gap-decorations-036.html "css/css-gaps/grid/grid-gap-decorations-036.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/grid-gap-decorations-036.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/grid-gap-decorations-036.html)
- [grid-gap-decorations-037.html](https://wpt.fyi/results/css/css-gaps/grid/grid-gap-decorations-037.html "css/css-gaps/grid/grid-gap-decorations-037.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/grid-gap-decorations-037.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/grid-gap-decorations-037.html)
- [grid-gap-decorations-041-crash.html](https://wpt.fyi/results/css/css-gaps/grid/grid-gap-decorations-041-crash.html "css/css-gaps/grid/grid-gap-decorations-041-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/grid-gap-decorations-041-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/grid-gap-decorations-041-crash.html)
- [grid-gap-decorations-042.html](https://wpt.fyi/results/css/css-gaps/grid/grid-gap-decorations-042.html "css/css-gaps/grid/grid-gap-decorations-042.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/grid-gap-decorations-042.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/grid-gap-decorations-042.html)
- [grid-gap-decorations-043-crash.html](https://wpt.fyi/results/css/css-gaps/grid/grid-gap-decorations-043-crash.html "css/css-gaps/grid/grid-gap-decorations-043-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/grid-gap-decorations-043-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/grid-gap-decorations-043-crash.html)
- [grid-gap-decorations-044-crash.html](https://wpt.fyi/results/css/css-gaps/grid/grid-gap-decorations-044-crash.html "css/css-gaps/grid/grid-gap-decorations-044-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/grid-gap-decorations-044-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/grid-gap-decorations-044-crash.html)
- [grid-gap-decorations-045.html](https://wpt.fyi/results/css/css-gaps/grid/grid-gap-decorations-045.html "css/css-gaps/grid/grid-gap-decorations-045.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/grid-gap-decorations-045.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/grid-gap-decorations-045.html)
- [grid-gap-decorations-046.html](https://wpt.fyi/results/css/css-gaps/grid/grid-gap-decorations-046.html "css/css-gaps/grid/grid-gap-decorations-046.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/grid-gap-decorations-046.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/grid-gap-decorations-046.html)
- [grid-gap-decorations-047.html](https://wpt.fyi/results/css/css-gaps/grid/grid-gap-decorations-047.html "css/css-gaps/grid/grid-gap-decorations-047.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/grid-gap-decorations-047.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/grid-gap-decorations-047.html)
- [grid-gap-decorations-066.html](https://wpt.fyi/results/css/css-gaps/grid/grid-gap-decorations-066.html "css/css-gaps/grid/grid-gap-decorations-066.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/grid-gap-decorations-066.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/grid-gap-decorations-066.html)
- [grid-gap-decorations-repaint-on-child-resize.html](https://wpt.fyi/results/css/css-gaps/grid/grid-gap-decorations-repaint-on-child-resize.html "css/css-gaps/grid/grid-gap-decorations-repaint-on-child-resize.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/grid-gap-decorations-repaint-on-child-resize.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/grid-gap-decorations-repaint-on-child-resize.html)
- [grid-gap-decorations-repaint-on-item-position-change.html](https://wpt.fyi/results/css/css-gaps/grid/grid-gap-decorations-repaint-on-item-position-change.html "css/css-gaps/grid/grid-gap-decorations-repaint-on-item-position-change.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/grid-gap-decorations-repaint-on-item-position-change.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/grid-gap-decorations-repaint-on-item-position-change.html)
- [grid-gap-decorations-repaint-on-item-span-change.html](https://wpt.fyi/results/css/css-gaps/grid/grid-gap-decorations-repaint-on-item-span-change.html "css/css-gaps/grid/grid-gap-decorations-repaint-on-item-span-change.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/grid-gap-decorations-repaint-on-item-span-change.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/grid-gap-decorations-repaint-on-item-span-change.html)
- [grid-gap-decorations-writing-mode.html](https://wpt.fyi/results/css/css-gaps/grid/grid-gap-decorations-writing-mode.html "css/css-gaps/grid/grid-gap-decorations-writing-mode.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/grid-gap-decorations-writing-mode.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/grid-gap-decorations-writing-mode.html)
- [subgrid-gap-decorations-001.html](https://wpt.fyi/results/css/css-gaps/grid/subgrid/subgrid-gap-decorations-001.html "css/css-gaps/grid/subgrid/subgrid-gap-decorations-001.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/subgrid/subgrid-gap-decorations-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/subgrid/subgrid-gap-decorations-001.html)
- [subgrid-gap-decorations-002.html](https://wpt.fyi/results/css/css-gaps/grid/subgrid/subgrid-gap-decorations-002.html "css/css-gaps/grid/subgrid/subgrid-gap-decorations-002.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/subgrid/subgrid-gap-decorations-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/subgrid/subgrid-gap-decorations-002.html)
- [subgrid-gap-decorations-003.html](https://wpt.fyi/results/css/css-gaps/grid/subgrid/subgrid-gap-decorations-003.html "css/css-gaps/grid/subgrid/subgrid-gap-decorations-003.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/subgrid/subgrid-gap-decorations-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/subgrid/subgrid-gap-decorations-003.html)
- [subgrid-gap-decorations-009.html](https://wpt.fyi/results/css/css-gaps/grid/subgrid/subgrid-gap-decorations-009.html "css/css-gaps/grid/subgrid/subgrid-gap-decorations-009.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/subgrid/subgrid-gap-decorations-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/subgrid/subgrid-gap-decorations-009.html)
- [subgrid-gap-decorations-010.html](https://wpt.fyi/results/css/css-gaps/grid/subgrid/subgrid-gap-decorations-010.html "css/css-gaps/grid/subgrid/subgrid-gap-decorations-010.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/subgrid/subgrid-gap-decorations-010.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/subgrid/subgrid-gap-decorations-010.html)
- [subgrid-gap-decorations-011.html](https://wpt.fyi/results/css/css-gaps/grid/subgrid/subgrid-gap-decorations-011.html "css/css-gaps/grid/subgrid/subgrid-gap-decorations-011.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/subgrid/subgrid-gap-decorations-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/subgrid/subgrid-gap-decorations-011.html)
- [subgrid-gap-decorations-012.html](https://wpt.fyi/results/css/css-gaps/grid/subgrid/subgrid-gap-decorations-012.html "css/css-gaps/grid/subgrid/subgrid-gap-decorations-012.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/subgrid/subgrid-gap-decorations-012.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/subgrid/subgrid-gap-decorations-012.html)
- [subgrid-gap-decorations-013.html](https://wpt.fyi/results/css/css-gaps/grid/subgrid/subgrid-gap-decorations-013.html "css/css-gaps/grid/subgrid/subgrid-gap-decorations-013.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/subgrid/subgrid-gap-decorations-013.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/subgrid/subgrid-gap-decorations-013.html)
- [subgrid-gap-decorations-014.html](https://wpt.fyi/results/css/css-gaps/grid/subgrid/subgrid-gap-decorations-014.html "css/css-gaps/grid/subgrid/subgrid-gap-decorations-014.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/subgrid/subgrid-gap-decorations-014.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/subgrid/subgrid-gap-decorations-014.html)
- [subgrid-gap-decorations-015.html](https://wpt.fyi/results/css/css-gaps/grid/subgrid/subgrid-gap-decorations-015.html "css/css-gaps/grid/subgrid/subgrid-gap-decorations-015.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/subgrid/subgrid-gap-decorations-015.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/subgrid/subgrid-gap-decorations-015.html)
- [subgrid-gap-decorations-016.html](https://wpt.fyi/results/css/css-gaps/grid/subgrid/subgrid-gap-decorations-016.html "css/css-gaps/grid/subgrid/subgrid-gap-decorations-016.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/subgrid/subgrid-gap-decorations-016.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/subgrid/subgrid-gap-decorations-016.html)
- [subgrid-gap-decorations-018.html](https://wpt.fyi/results/css/css-gaps/grid/subgrid/subgrid-gap-decorations-018.html "css/css-gaps/grid/subgrid/subgrid-gap-decorations-018.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/subgrid/subgrid-gap-decorations-018.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/subgrid/subgrid-gap-decorations-018.html)
- [multicol-gap-decorations-001.html](https://wpt.fyi/results/css/css-gaps/multicol/multicol-gap-decorations-001.html "css/css-gaps/multicol/multicol-gap-decorations-001.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/multicol/multicol-gap-decorations-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/multicol/multicol-gap-decorations-001.html)
- [multicol-gap-decorations-002.html](https://wpt.fyi/results/css/css-gaps/multicol/multicol-gap-decorations-002.html "css/css-gaps/multicol/multicol-gap-decorations-002.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/multicol/multicol-gap-decorations-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/multicol/multicol-gap-decorations-002.html)
- [multicol-gap-decorations-003.html](https://wpt.fyi/results/css/css-gaps/multicol/multicol-gap-decorations-003.html "css/css-gaps/multicol/multicol-gap-decorations-003.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/multicol/multicol-gap-decorations-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/multicol/multicol-gap-decorations-003.html)
- [multicol-gap-decorations-005.html](https://wpt.fyi/results/css/css-gaps/multicol/multicol-gap-decorations-005.html "css/css-gaps/multicol/multicol-gap-decorations-005.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/multicol/multicol-gap-decorations-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/multicol/multicol-gap-decorations-005.html)
- [multicol-gap-decorations-006.html](https://wpt.fyi/results/css/css-gaps/multicol/multicol-gap-decorations-006.html "css/css-gaps/multicol/multicol-gap-decorations-006.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/multicol/multicol-gap-decorations-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/multicol/multicol-gap-decorations-006.html)
- [multicol-gap-decorations-007.html](https://wpt.fyi/results/css/css-gaps/multicol/multicol-gap-decorations-007.html "css/css-gaps/multicol/multicol-gap-decorations-007.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/multicol/multicol-gap-decorations-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/multicol/multicol-gap-decorations-007.html)
- [multicol-gap-decorations-013.html](https://wpt.fyi/results/css/css-gaps/multicol/multicol-gap-decorations-013.html "css/css-gaps/multicol/multicol-gap-decorations-013.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/multicol/multicol-gap-decorations-013.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/multicol/multicol-gap-decorations-013.html)
- [multicol-gap-decorations-015.html](https://wpt.fyi/results/css/css-gaps/multicol/multicol-gap-decorations-015.html "css/css-gaps/multicol/multicol-gap-decorations-015.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/multicol/multicol-gap-decorations-015.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/multicol/multicol-gap-decorations-015.html)
- [multicol-gap-decorations-016.html](https://wpt.fyi/results/css/css-gaps/multicol/multicol-gap-decorations-016.html "css/css-gaps/multicol/multicol-gap-decorations-016.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/multicol/multicol-gap-decorations-016.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/multicol/multicol-gap-decorations-016.html)
- [multicol-gap-decorations-018.html](https://wpt.fyi/results/css/css-gaps/multicol/multicol-gap-decorations-018.html "css/css-gaps/multicol/multicol-gap-decorations-018.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/multicol/multicol-gap-decorations-018.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/multicol/multicol-gap-decorations-018.html)
- [multicol-gap-decorations-024.html](https://wpt.fyi/results/css/css-gaps/multicol/multicol-gap-decorations-024.html "css/css-gaps/multicol/multicol-gap-decorations-024.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/multicol/multicol-gap-decorations-024.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/multicol/multicol-gap-decorations-024.html)
- [multicol-gap-decorations-040.html](https://wpt.fyi/results/css/css-gaps/multicol/multicol-gap-decorations-040.html "css/css-gaps/multicol/multicol-gap-decorations-040.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/multicol/multicol-gap-decorations-040.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/multicol/multicol-gap-decorations-040.html)
- [multicol-gap-decorations-repaint-on-content-resize.html](https://wpt.fyi/results/css/css-gaps/multicol/multicol-gap-decorations-repaint-on-content-resize.html "css/css-gaps/multicol/multicol-gap-decorations-repaint-on-content-resize.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/multicol/multicol-gap-decorations-repaint-on-content-resize.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/multicol/multicol-gap-decorations-repaint-on-content-resize.html)
- [multicol-gap-decorations-writing-mode.html](https://wpt.fyi/results/css/css-gaps/multicol/multicol-gap-decorations-writing-mode.html "css/css-gaps/multicol/multicol-gap-decorations-writing-mode.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/multicol/multicol-gap-decorations-writing-mode.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/multicol/multicol-gap-decorations-writing-mode.html)

### 3.2. Break behaviors at intersections: The [column-rule-break, [row-rule-break](#propdef-row-rule-break), and [rule-break](#propdef-rule-break) properties]
Name:

[column-rule-break], [row-rule-break]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[none](#valdef-column-rule-break-none)
[\|](https://drafts.csswg.org/css-values-4/#comb-one)
[normal](#valdef-column-rule-break-normal) [\|]
[intersection](#valdef-column-rule-break-intersection)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

[normal](#valdef-column-rule-break-normal)

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[grid
containers](https://drafts.csswg.org/css-grid-2/#grid-container), [flex
containers](https://drafts.csswg.org/css-flexbox-2/#flex-container), [multicol
containers](https://drafts.csswg.org/css-multicol-2/#multi-column-container), and [grid lanes
containers](https://drafts.csswg.org/css-grid-3/#grid-lanes-container)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

as specified

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

These properties set the behavior for breaking decorations within a
given gap into segments at visible \"T\" or \"cross\" intersections
formed by items in the container. Precise details for how to apply these
values are given in the steps to [determine gap decoration
segments](#determine-gap-decoration-segments).

[none]
: Gap decorations do not start or end at visible \"T\" or \"cross\"
 intersections. Instead, a single continuous decoration is painted
 from one end of the gap to the other.

[normal]
: Behavior depends on the type of container.

 [Grid containers](https://drafts.csswg.org/css-grid-2/#grid-container)
 : Gap decorations start and end at visible \"T\" intersections but
 continue through visible \"cross\" intersections.

 [Flex containers](https://drafts.csswg.org/css-flexbox-2/#flex-container)
 : Behaves the same as
 [none](#valdef-column-rule-break-none).

 [Multicol containers](https://drafts.csswg.org/css-multicol-2/#multi-column-container)
 : On
 [column-rule-break](#propdef-column-rule-break), behaves the same as
 [intersection](#valdef-column-rule-break-intersection). On
 [row-rule-break](#propdef-row-rule-break), behaves the same as
 [none](#valdef-column-rule-break-none).

 [Grid lanes containers](https://drafts.csswg.org/css-grid-3/#grid-lanes-container)
 : In the [grid
 axis](https://drafts.csswg.org/css-grid-3/#grid-axis), behaves as it does for [grid
 containers](https://drafts.csswg.org/css-grid-2/#grid-container). In the [stacking
 axis](https://drafts.csswg.org/css-grid-3/#stacking-axis), behaves the same as
 [none](#valdef-column-rule-break-none), staying contained within the gutters.

[intersection]
: Gap decorations start and end at visible \"T\" and \"cross\"
 intersections.

Tests

- [flex-gap-decorations-009.html](https://wpt.fyi/results/css/css-gaps/flex/flex-gap-decorations-009.html "css/css-gaps/flex/flex-gap-decorations-009.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/flex/flex-gap-decorations-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/flex/flex-gap-decorations-009.html)
- [flex-gap-decorations-010.html](https://wpt.fyi/results/css/css-gaps/flex/flex-gap-decorations-010.html "css/css-gaps/flex/flex-gap-decorations-010.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/flex/flex-gap-decorations-010.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/flex/flex-gap-decorations-010.html)
- [flex-gap-decorations-028.html](https://wpt.fyi/results/css/css-gaps/flex/flex-gap-decorations-028.html "css/css-gaps/flex/flex-gap-decorations-028.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/flex/flex-gap-decorations-028.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/flex/flex-gap-decorations-028.html)
- [flex-gap-decorations-031.html](https://wpt.fyi/results/css/css-gaps/flex/flex-gap-decorations-031.html "css/css-gaps/flex/flex-gap-decorations-031.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/flex/flex-gap-decorations-031.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/flex/flex-gap-decorations-031.html)
- [flex-gap-decorations-034.html](https://wpt.fyi/results/css/css-gaps/flex/flex-gap-decorations-034.html "css/css-gaps/flex/flex-gap-decorations-034.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/flex/flex-gap-decorations-034.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/flex/flex-gap-decorations-034.html)
- [flex-gap-decorations-035.html](https://wpt.fyi/results/css/css-gaps/flex/flex-gap-decorations-035.html "css/css-gaps/flex/flex-gap-decorations-035.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/flex/flex-gap-decorations-035.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/flex/flex-gap-decorations-035.html)
- [flex-gap-decorations-036.html](https://wpt.fyi/results/css/css-gaps/flex/flex-gap-decorations-036.html "css/css-gaps/flex/flex-gap-decorations-036.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/flex/flex-gap-decorations-036.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/flex/flex-gap-decorations-036.html)
- [flex-gap-decorations-037.html](https://wpt.fyi/results/css/css-gaps/flex/flex-gap-decorations-037.html "css/css-gaps/flex/flex-gap-decorations-037.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/flex/flex-gap-decorations-037.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/flex/flex-gap-decorations-037.html)
- [flex-gap-decorations-050.html](https://wpt.fyi/results/css/css-gaps/flex/flex-gap-decorations-050.html "css/css-gaps/flex/flex-gap-decorations-050.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/flex/flex-gap-decorations-050.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/flex/flex-gap-decorations-050.html)
- [flex-gap-decorations-051.html](https://wpt.fyi/results/css/css-gaps/flex/flex-gap-decorations-051.html "css/css-gaps/flex/flex-gap-decorations-051.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/flex/flex-gap-decorations-051.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/flex/flex-gap-decorations-051.html)
- [flex-gap-decorations-052.html](https://wpt.fyi/results/css/css-gaps/flex/flex-gap-decorations-052.html "css/css-gaps/flex/flex-gap-decorations-052.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/flex/flex-gap-decorations-052.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/flex/flex-gap-decorations-052.html)
- [grid-gap-decorations-006.html](https://wpt.fyi/results/css/css-gaps/grid/grid-gap-decorations-006.html "css/css-gaps/grid/grid-gap-decorations-006.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/grid-gap-decorations-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/grid-gap-decorations-006.html)
- [grid-gap-decorations-007.html](https://wpt.fyi/results/css/css-gaps/grid/grid-gap-decorations-007.html "css/css-gaps/grid/grid-gap-decorations-007.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/grid-gap-decorations-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/grid-gap-decorations-007.html)
- [grid-gap-decorations-008.html](https://wpt.fyi/results/css/css-gaps/grid/grid-gap-decorations-008.html "css/css-gaps/grid/grid-gap-decorations-008.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/grid-gap-decorations-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/grid-gap-decorations-008.html)
- [grid-gap-decorations-009.html](https://wpt.fyi/results/css/css-gaps/grid/grid-gap-decorations-009.html "css/css-gaps/grid/grid-gap-decorations-009.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/grid-gap-decorations-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/grid-gap-decorations-009.html)
- [grid-gap-decorations-040.html](https://wpt.fyi/results/css/css-gaps/grid/grid-gap-decorations-040.html "css/css-gaps/grid/grid-gap-decorations-040.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/grid-gap-decorations-040.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/grid-gap-decorations-040.html)
- [subgrid-gap-decorations-004.html](https://wpt.fyi/results/css/css-gaps/grid/subgrid/subgrid-gap-decorations-004.html "css/css-gaps/grid/subgrid/subgrid-gap-decorations-004.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/subgrid/subgrid-gap-decorations-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/subgrid/subgrid-gap-decorations-004.html)
- [subgrid-gap-decorations-005.html](https://wpt.fyi/results/css/css-gaps/grid/subgrid/subgrid-gap-decorations-005.html "css/css-gaps/grid/subgrid/subgrid-gap-decorations-005.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/subgrid/subgrid-gap-decorations-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/subgrid/subgrid-gap-decorations-005.html)
- [subgrid-gap-decorations-006.html](https://wpt.fyi/results/css/css-gaps/grid/subgrid/subgrid-gap-decorations-006.html "css/css-gaps/grid/subgrid/subgrid-gap-decorations-006.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/subgrid/subgrid-gap-decorations-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/subgrid/subgrid-gap-decorations-006.html)
- [multicol-gap-decorations-014.html](https://wpt.fyi/results/css/css-gaps/multicol/multicol-gap-decorations-014.html "css/css-gaps/multicol/multicol-gap-decorations-014.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/multicol/multicol-gap-decorations-014.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/multicol/multicol-gap-decorations-014.html)
- [multicol-gap-decorations-020.html](https://wpt.fyi/results/css/css-gaps/multicol/multicol-gap-decorations-020.html "css/css-gaps/multicol/multicol-gap-decorations-020.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/multicol/multicol-gap-decorations-020.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/multicol/multicol-gap-decorations-020.html)
- [multicol-gap-decorations-025.html](https://wpt.fyi/results/css/css-gaps/multicol/multicol-gap-decorations-025.html "css/css-gaps/multicol/multicol-gap-decorations-025.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/multicol/multicol-gap-decorations-025.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/multicol/multicol-gap-decorations-025.html)
- [multicol-gap-decorations-026.html](https://wpt.fyi/results/css/css-gaps/multicol/multicol-gap-decorations-026.html "css/css-gaps/multicol/multicol-gap-decorations-026.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/multicol/multicol-gap-decorations-026.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/multicol/multicol-gap-decorations-026.html)
- [multicol-gap-decorations-034.html](https://wpt.fyi/results/css/css-gaps/multicol/multicol-gap-decorations-034.html "css/css-gaps/multicol/multicol-gap-decorations-034.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/multicol/multicol-gap-decorations-034.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/multicol/multicol-gap-decorations-034.html)

Name:

[rule-break]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<\'column-rule-break\'\>](#propdef-column-rule-break)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

see individual properties

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

Same as
[column-rule-break](#propdef-column-rule-break) and
[row-rule-break](#propdef-row-rule-break)

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

This [shorthand
property](https://drafts.csswg.org/css-cascade-5/#shorthand-property) sets
[column-rule-break](#propdef-column-rule-break) and
[row-rule-break](#propdef-row-rule-break) to the same value.

Tests

- [rule-break-computed.html](https://wpt.fyi/results/css/css-gaps/parsing/rule-break-computed.html "css/css-gaps/parsing/rule-break-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/parsing/rule-break-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/parsing/rule-break-computed.html)
- [rule-break-invalid.html](https://wpt.fyi/results/css/css-gaps/parsing/rule-break-invalid.html "css/css-gaps/parsing/rule-break-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/parsing/rule-break-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/parsing/rule-break-invalid.html)
- [rule-break-shorthand.html](https://wpt.fyi/results/css/css-gaps/parsing/rule-break-shorthand.html "css/css-gaps/parsing/rule-break-shorthand.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/parsing/rule-break-shorthand.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/parsing/rule-break-shorthand.html)
- [rule-break-valid.html](https://wpt.fyi/results/css/css-gaps/parsing/rule-break-valid.html "css/css-gaps/parsing/rule-break-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/parsing/rule-break-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/parsing/rule-break-valid.html)

The following examples illustrate various settings for the
[\*-rule-break](#break) properties.

.break-normal-grid {
 display: grid;
 grid-template: repeat(4, 100px) / repeat(4, 100px);
 gap: 20px;
 row-rule: 6px solid red;
 column-rule: 6px solid blue;
 rule-break: normal;
 }

![Default break behavior for [gap
decorations](#gap-decoration)
in a grid. Each decoration stops when it encounters an item spanning
across the gap.](images/example-break-normal-grid.png){height="471"
width="472"}

.break-normal-grid-lanes {
 display: grid-lanes;
 grid-template-columns: repeat(3, 120px);
 gap: 16px;
 row-rule: 10px solid #6aa6dc;
 column-rule: 10px solid #f0673f;
 rule-break: normal;
 }

![Default break behavior for [gap
decorations](#gap-decoration)
in a [grid lanes
container](https://drafts.csswg.org/css-grid-3/#grid-lanes-container). [Grid
axis](https://drafts.csswg.org/css-grid-3/#grid-axis) rules break at a spanner, while [stacking
axis](https://drafts.csswg.org/css-grid-3/#stacking-axis) rules remain separate in each
track.](images/example-break-normal-grid-lanes.png){height="402"
width="466"}

.break-none-grid {
 display: grid;
 grid-template: repeat(4, 100px) / repeat(4, 100px);
 gap: 20px;
 row-rule: 6px solid red;
 column-rule: 6px solid blue;
 rule-break: none;
 }

![Grid [gap decorations](#gap-decoration) with no breaks. Note that the [gap
decorations] extend \"behind\" items placed
in the grid.](images/example-break-none-grid.png){height="475"
width="474"}

.break-intersection-grid {
 display: grid;
 grid-template: repeat(4, 100px) / repeat(4, 100px);
 gap: 20px;
 row-rule: 6px solid red;
 column-rule: 6px solid blue;
 rule-break: intersection;
 }

![Grid [gap decorations](#gap-decoration) contained within each [gap decoration
segment](#gap-decoration-segment) that is not flanked by spanning items on opposing
sides.](images/example-break-intersection-grid.png){height="474"
width="474"}

.break-normal-multicol {
 column-width: 150px;
 column-height: 300px;
 gap: 1em;
 row-rule: 4px solid red;
 column-rule: 4px solid blue;
 rule-break: normal;
 }

![Multicol [gap decorations](#gap-decoration) with rule-break set to
[normal](#valdef-column-rule-break-normal). Note that in the column direction it behaves as
if rule-break were set to
[intersection](#valdef-column-rule-break-intersection), while in the row direction it behaves as if
rule-break were set to
[none](#valdef-column-rule-break-none).](images/example-break-normal-multicol.png){height="628"
width="955"}

.break-intersection-multicol {
 column-width: 150px;
 column-height: 300px;
 gap: 1em;
 row-rule: 4px solid red;
 column-rule: 4px solid blue;
 rule-break: intersection;
 }

![Multicol [gap decorations](#gap-decoration) with rule-break set to
[intersection](#valdef-column-rule-break-intersection).](images/example-break-intersection-multicol.png){height="627"
width="959"}

.break-normal-flex {
 display: flex;
 flex-wrap: wrap;
 gap: 20px;
 row-rule: 6px solid red;
 column-rule: 6px solid blue;
 rule-break: normal;
 }

![Default break behavior for [gap
decorations](#gap-decoration)
in a flex container.](images/example-break-normal-flex.png){height="355"
width="514"}

Note that each flex line has its own distinct
[gaps](#gap) between items. This has two
implications:

1. [Gap decorations](#gap-decoration) in adjacent flex lines are separate from each other
 even if the gaps happen to line up.
2. [none](#valdef-column-rule-break-none) would have the same visual effect as
 [normal](#valdef-column-rule-break-normal).

.break-intersection-flex {
 display: flex;
 flex-wrap: wrap;
 width: 500px;
 gap: 20px;
 row-rule: 6px solid red;
 column-rule: 6px solid blue;
 rule-break: intersection;
 }

![Flexbox [gap decorations](#gap-decoration) contained within each [gap decoration
segment](#gap-decoration-segment).](images/example-break-intersection-flex.png){height="351"
width="512"}

### 3.3. Adjusting gap decoration endpoints: The [rule-inset properties]
Name:

[column-rule-inset-cap-start],
[column-rule-inset-cap-end],
[column-rule-inset-junction-start],
[column-rule-inset-junction-end],
[row-rule-inset-cap-start],
[row-rule-inset-cap-end],
[row-rule-inset-junction-start],
[row-rule-inset-junction-end]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<inset-value\>](#typedef-inset-value)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

[0]

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[grid
containers](https://drafts.csswg.org/css-grid-2/#grid-container), [flex
containers](https://drafts.csswg.org/css-flexbox-2/#flex-container), [multicol
containers](https://drafts.csswg.org/css-multicol-2/#multi-column-container), and [grid lanes
containers](https://drafts.csswg.org/css-grid-3/#grid-lanes-container)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

refer to the [crossing gap
width](#crossing-gap-width)

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

as specified

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value type

``` prod
<inset-value> = <length-percentage> | overlap-join
```

These properties can be used to offset the start and end points of [gap
decorations](#gap-decoration)
relative to the [segment
endpoints](#segment-endpoint) which would normally determine where decorations start
and end.

A [junction segment endpoint] is a [segment
endpoint](#segment-endpoint) at a [gap
junction](#gap-junction) where
one or more other [gap decoration
segments](#gap-decoration-segment) are also present.

A [cap segment endpoint] is any [segment
endpoint](#segment-endpoint) that is not a [junction segment
endpoint](#junction-segment-endpoint). This includes endpoints at the container's content
edges, as well as endpoints at a [gap
junction](#gap-junction) where
no other [gap decoration
segment](#gap-decoration-segment) is present.

.simple-grid {
 rule-break: intersection;
 rule-visibility-items: between;
 }

![In a fully populated grid, every interior [gap
junction](#gap-junction)
produces [junction segment
endpoints](#junction-segment-endpoint) (marked **J**), while the container's content edges
produce [cap segment
endpoints](#cap-segment-endpoint) (marked
**C**).](images/example-cap-junct-simple-grid.png){height="358"
width="355"}

.simple-grid-with-empty-cells {
 rule-break: intersection;
 rule-visibility-items: between;
 }

![When a [gap decoration
segment](#gap-decoration-segment) terminates at an interior [gap
junction](#gap-junction) where
no other [gap decoration segment] is
present, its endpoint is a [cap segment
endpoint](#cap-segment-endpoint).](images/example-cap-junct-less-simple-grid.png){height="358"
width="355"}

.donut-grid-layout {
 rule-break: intersection;
 rule-visibility-items: between;
 }

![In a \"donut\" grid layout, where items surround an empty space in the
middle of the container, endpoints bordering the empty interior region
are [cap segment
endpoints](#cap-segment-endpoint).](images/example-cap-junct-donut-grid.png){height="481"
width="484"}

Percentages are resolved against the [crossing gap
width], defined as follows:

Segment endpoints at a [gap junction](#gap-junction)

: The [crossing gap
 width](#crossing-gap-width) is the size of the [gap
 junction](#gap-junction) in
 the same dimension as the [gap](#gap) in which the [segment
 endpoint](#segment-endpoint) lies (the row dimension for [row
 gaps](#row-gap) and the column
 dimension for [column gaps](#column-gap)).

 Typically, this will be the used value of the
 [column-gap](#propdef-column-gap) or
 [row-gap](#propdef-row-gap) property, whichever applies to the
 intersecting or abutting gap, plus any additional spacing added due
 to
 [justify-content](https://drafts.csswg.org/css-align-3/#propdef-justify-content) or
 [align-content](https://drafts.csswg.org/css-align-3/#propdef-align-content). However, in cases where
 [gaps](#gap) intersect or abut one
 another at overlapping intervals, the [crossing gap
 width](#crossing-gap-width) will be determined by the union of such intervals.
 See [this example](#example-unpaired-endpoints-1) for one such case.

Other segment endpoints
: The [crossing gap
 width](#crossing-gap-width) is [0].

Note: This classification by position is distinct from the [cap segment
endpoint](#cap-segment-endpoint) / [junction segment
endpoint](#junction-segment-endpoint) classification. A [cap segment
endpoint] may sit at a container edge or
at a [gap junction](#gap-junction) (see [this example](#example-cap-junction-donut)).
Hence, [column-rule-inset-cap-start:
50%](#propdef-column-rule-inset-cap-start) resolves to half the [gap
junction] size at an interior cap and [0]
at other caps such as container edges.

The
[column-rule-inset-cap-start](#propdef-column-rule-inset-cap-start) and
[row-rule-inset-cap-start](#propdef-row-rule-inset-cap-start) properties apply to [start segment
endpoints](#start-segment-endpoint) that are [cap segment
endpoints](#cap-segment-endpoint). The
[column-rule-inset-junction-start](#propdef-column-rule-inset-junction-start) and
[row-rule-inset-junction-start](#propdef-row-rule-inset-junction-start) properties apply to [start segment
endpoints] that are [junction segment
endpoints](#junction-segment-endpoint). For these properties, positive values offset in the
[end](https://drafts.csswg.org/css-writing-modes-4/#css-end) direction, and negative values offset in the
[start](https://drafts.csswg.org/css-writing-modes-4/#css-start) direction, along the axis of the gap.

The
[column-rule-inset-cap-end](#propdef-column-rule-inset-cap-end) and
[row-rule-inset-cap-end](#propdef-row-rule-inset-cap-end) properties apply to [end segment
endpoints](#end-segment-endpoint) that are [cap segment
endpoints](#cap-segment-endpoint). The
[column-rule-inset-junction-end](#propdef-column-rule-inset-junction-end) and
[row-rule-inset-junction-end](#propdef-row-rule-inset-junction-end) properties apply to [end segment
endpoints] that are [junction segment
endpoints](#junction-segment-endpoint). For these properties, positive values offset in the
[start](https://drafts.csswg.org/css-writing-modes-4/#css-start) direction, and negative values offset in the
[end](https://drafts.csswg.org/css-writing-modes-4/#css-end) direction, along the axis of the gap.

The [overlap-join] keyword
produces neat joins between [gap
decorations](#gap-decoration)
that meet at the same [gap
junction](#gap-junction):

- At a [junction segment
 endpoint](#junction-segment-endpoint), the [gap
 decoration](#gap-decoration) extends into the [gap
 junction](#gap-junction) by
 half the [crossing gap
 width](#crossing-gap-width), plus half the [used
 value](https://drafts.csswg.org/css-cascade-5/#used-value) of the crossing gap's
 [column-rule-width](#propdef-column-rule-width) or
 [row-rule-width](#propdef-row-rule-width) (whichever applies).
- At a [cap segment
 endpoint](#cap-segment-endpoint),
 [overlap-join](#valdef-inset-value-overlap-join) is treated as [0].

.inset-overlap-join {
 rule-inset: overlap-join;
 rule-break: intersection;
 rule-visibility-items: between;
 }

![With
[overlap-join](#valdef-inset-value-overlap-join), [gap
decorations](#gap-decoration)
at [junction segment
endpoints](#junction-segment-endpoint) extend into the [gap
junction](#gap-junction),
joining adjacent segments. At [cap segment
endpoints](#cap-segment-endpoint),
[overlap-join] is
treated as [0].](images/example-1-overlap-join.png){height="354"
width="351"}

.inset-overlap-join {
 rule-inset: overlap-join;
 rule-break: intersection;
 rule-visibility-items: between;
 }

![In a \"donut\" grid layout, where items surround an empty space in the
middle of the container,
[overlap-join](#valdef-inset-value-overlap-join) joins adjacent segments at the [junction segment
endpoints](#junction-segment-endpoint), extending each [gap
decoration](#gap-decoration)
into the [gap junction](#gap-junction). At the [cap segment
endpoints](#cap-segment-endpoint) bordering the edge of the container and the empty
interior region,
[overlap-join] is
treated as [0].](images/example-2-overlap-join.png){height="477"
width="477"}

.inset-end {
 row-rule: 3px solid red;
 row-rule-break: intersection;
 row-rule-inset-end: 10px;
 }

![Row-direction decorations with asymmetric insets in LTR and RTL
directions and vertical
writing-mode.](images/example-inset-direction.png){height="734"
width="352"}

- [flex-gap-decorations-011.html](https://wpt.fyi/results/css/css-gaps/flex/flex-gap-decorations-011.html "css/css-gaps/flex/flex-gap-decorations-011.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/flex/flex-gap-decorations-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/flex/flex-gap-decorations-011.html)
- [flex-gap-decorations-013.html](https://wpt.fyi/results/css/css-gaps/flex/flex-gap-decorations-013.html "css/css-gaps/flex/flex-gap-decorations-013.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/flex/flex-gap-decorations-013.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/flex/flex-gap-decorations-013.html)
- [flex-gap-decorations-014.html](https://wpt.fyi/results/css/css-gaps/flex/flex-gap-decorations-014.html "css/css-gaps/flex/flex-gap-decorations-014.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/flex/flex-gap-decorations-014.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/flex/flex-gap-decorations-014.html)
- [flex-gap-decorations-029.html](https://wpt.fyi/results/css/css-gaps/flex/flex-gap-decorations-029.html "css/css-gaps/flex/flex-gap-decorations-029.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/flex/flex-gap-decorations-029.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/flex/flex-gap-decorations-029.html)
- [flex-gap-decorations-030.html](https://wpt.fyi/results/css/css-gaps/flex/flex-gap-decorations-030.html "css/css-gaps/flex/flex-gap-decorations-030.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/flex/flex-gap-decorations-030.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/flex/flex-gap-decorations-030.html)
- [flex-gap-decorations-053.html](https://wpt.fyi/results/css/css-gaps/flex/flex-gap-decorations-053.html "css/css-gaps/flex/flex-gap-decorations-053.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/flex/flex-gap-decorations-053.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/flex/flex-gap-decorations-053.html)
- [flex-gap-decorations-054.html](https://wpt.fyi/results/css/css-gaps/flex/flex-gap-decorations-054.html "css/css-gaps/flex/flex-gap-decorations-054.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/flex/flex-gap-decorations-054.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/flex/flex-gap-decorations-054.html)
- [flex-gap-decorations-055.html](https://wpt.fyi/results/css/css-gaps/flex/flex-gap-decorations-055.html "css/css-gaps/flex/flex-gap-decorations-055.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/flex/flex-gap-decorations-055.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/flex/flex-gap-decorations-055.html)
- [flex-gap-decorations-063.html](https://wpt.fyi/results/css/css-gaps/flex/flex-gap-decorations-063.html "css/css-gaps/flex/flex-gap-decorations-063.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/flex/flex-gap-decorations-063.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/flex/flex-gap-decorations-063.html)
- [flex-gap-decorations-064.html](https://wpt.fyi/results/css/css-gaps/flex/flex-gap-decorations-064.html "css/css-gaps/flex/flex-gap-decorations-064.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/flex/flex-gap-decorations-064.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/flex/flex-gap-decorations-064.html)
- [flex-gap-decorations-065.html](https://wpt.fyi/results/css/css-gaps/flex/flex-gap-decorations-065.html "css/css-gaps/flex/flex-gap-decorations-065.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/flex/flex-gap-decorations-065.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/flex/flex-gap-decorations-065.html)
- [flex-gap-decorations-066.html](https://wpt.fyi/results/css/css-gaps/flex/flex-gap-decorations-066.html "css/css-gaps/flex/flex-gap-decorations-066.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/flex/flex-gap-decorations-066.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/flex/flex-gap-decorations-066.html)
- [flex-gap-decorations-067.html](https://wpt.fyi/results/css/css-gaps/flex/flex-gap-decorations-067.html "css/css-gaps/flex/flex-gap-decorations-067.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/flex/flex-gap-decorations-067.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/flex/flex-gap-decorations-067.html)
- [flex-gap-decorations-direction-inset.html](https://wpt.fyi/results/css/css-gaps/flex/flex-gap-decorations-direction-inset.html "css/css-gaps/flex/flex-gap-decorations-direction-inset.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/flex/flex-gap-decorations-direction-inset.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/flex/flex-gap-decorations-direction-inset.html)
- [grid-gap-decorations-010.html](https://wpt.fyi/results/css/css-gaps/grid/grid-gap-decorations-010.html "css/css-gaps/grid/grid-gap-decorations-010.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/grid-gap-decorations-010.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/grid-gap-decorations-010.html)
- [grid-gap-decorations-011.html](https://wpt.fyi/results/css/css-gaps/grid/grid-gap-decorations-011.html "css/css-gaps/grid/grid-gap-decorations-011.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/grid-gap-decorations-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/grid-gap-decorations-011.html)
- [grid-gap-decorations-012.html](https://wpt.fyi/results/css/css-gaps/grid/grid-gap-decorations-012.html "css/css-gaps/grid/grid-gap-decorations-012.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/grid-gap-decorations-012.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/grid-gap-decorations-012.html)
- [grid-gap-decorations-013.html](https://wpt.fyi/results/css/css-gaps/grid/grid-gap-decorations-013.html "css/css-gaps/grid/grid-gap-decorations-013.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/grid-gap-decorations-013.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/grid-gap-decorations-013.html)
- [grid-gap-decorations-014.html](https://wpt.fyi/results/css/css-gaps/grid/grid-gap-decorations-014.html "css/css-gaps/grid/grid-gap-decorations-014.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/grid-gap-decorations-014.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/grid-gap-decorations-014.html)
- [grid-gap-decorations-015.html](https://wpt.fyi/results/css/css-gaps/grid/grid-gap-decorations-015.html "css/css-gaps/grid/grid-gap-decorations-015.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/grid-gap-decorations-015.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/grid-gap-decorations-015.html)
- [grid-gap-decorations-038.html](https://wpt.fyi/results/css/css-gaps/grid/grid-gap-decorations-038.html "css/css-gaps/grid/grid-gap-decorations-038.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/grid-gap-decorations-038.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/grid-gap-decorations-038.html)
- [grid-gap-decorations-052.html](https://wpt.fyi/results/css/css-gaps/grid/grid-gap-decorations-052.html "css/css-gaps/grid/grid-gap-decorations-052.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/grid-gap-decorations-052.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/grid-gap-decorations-052.html)
- [grid-gap-decorations-053.html](https://wpt.fyi/results/css/css-gaps/grid/grid-gap-decorations-053.html "css/css-gaps/grid/grid-gap-decorations-053.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/grid-gap-decorations-053.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/grid-gap-decorations-053.html)
- [grid-gap-decorations-067.html](https://wpt.fyi/results/css/css-gaps/grid/grid-gap-decorations-067.html "css/css-gaps/grid/grid-gap-decorations-067.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/grid-gap-decorations-067.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/grid-gap-decorations-067.html)
- [grid-gap-decorations-068.html](https://wpt.fyi/results/css/css-gaps/grid/grid-gap-decorations-068.html "css/css-gaps/grid/grid-gap-decorations-068.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/grid-gap-decorations-068.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/grid-gap-decorations-068.html)
- [grid-gap-decorations-069.html](https://wpt.fyi/results/css/css-gaps/grid/grid-gap-decorations-069.html "css/css-gaps/grid/grid-gap-decorations-069.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/grid-gap-decorations-069.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/grid-gap-decorations-069.html)
- [grid-gap-decorations-070.html](https://wpt.fyi/results/css/css-gaps/grid/grid-gap-decorations-070.html "css/css-gaps/grid/grid-gap-decorations-070.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/grid-gap-decorations-070.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/grid-gap-decorations-070.html)
- [grid-gap-decorations-071.html](https://wpt.fyi/results/css/css-gaps/grid/grid-gap-decorations-071.html "css/css-gaps/grid/grid-gap-decorations-071.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/grid-gap-decorations-071.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/grid-gap-decorations-071.html)
- [grid-gap-decorations-072.html](https://wpt.fyi/results/css/css-gaps/grid/grid-gap-decorations-072.html "css/css-gaps/grid/grid-gap-decorations-072.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/grid-gap-decorations-072.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/grid-gap-decorations-072.html)
- [grid-gap-decorations-073.html](https://wpt.fyi/results/css/css-gaps/grid/grid-gap-decorations-073.html "css/css-gaps/grid/grid-gap-decorations-073.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/grid-gap-decorations-073.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/grid-gap-decorations-073.html)
- [grid-gap-decorations-074.html](https://wpt.fyi/results/css/css-gaps/grid/grid-gap-decorations-074.html "css/css-gaps/grid/grid-gap-decorations-074.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/grid-gap-decorations-074.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/grid-gap-decorations-074.html)
- [grid-gap-decorations-075.html](https://wpt.fyi/results/css/css-gaps/grid/grid-gap-decorations-075.html "css/css-gaps/grid/grid-gap-decorations-075.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/grid-gap-decorations-075.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/grid-gap-decorations-075.html)
- [grid-gap-decorations-076.html](https://wpt.fyi/results/css/css-gaps/grid/grid-gap-decorations-076.html "css/css-gaps/grid/grid-gap-decorations-076.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/grid-gap-decorations-076.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/grid-gap-decorations-076.html)
- [grid-gap-decorations-077.html](https://wpt.fyi/results/css/css-gaps/grid/grid-gap-decorations-077.html "css/css-gaps/grid/grid-gap-decorations-077.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/grid-gap-decorations-077.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/grid-gap-decorations-077.html)
- [grid-gap-decorations-078.html](https://wpt.fyi/results/css/css-gaps/grid/grid-gap-decorations-078.html "css/css-gaps/grid/grid-gap-decorations-078.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/grid-gap-decorations-078.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/grid-gap-decorations-078.html)
- [grid-gap-decorations-079.html](https://wpt.fyi/results/css/css-gaps/grid/grid-gap-decorations-079.html "css/css-gaps/grid/grid-gap-decorations-079.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/grid-gap-decorations-079.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/grid-gap-decorations-079.html)
- [grid-gap-decorations-080.html](https://wpt.fyi/results/css/css-gaps/grid/grid-gap-decorations-080.html "css/css-gaps/grid/grid-gap-decorations-080.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/grid-gap-decorations-080.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/grid-gap-decorations-080.html)
- [grid-gap-decorations-081.html](https://wpt.fyi/results/css/css-gaps/grid/grid-gap-decorations-081.html "css/css-gaps/grid/grid-gap-decorations-081.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/grid-gap-decorations-081.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/grid-gap-decorations-081.html)
- [grid-gap-decorations-082.html](https://wpt.fyi/results/css/css-gaps/grid/grid-gap-decorations-082.html "css/css-gaps/grid/grid-gap-decorations-082.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/grid-gap-decorations-082.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/grid-gap-decorations-082.html)
- [grid-gap-decorations-090.html](https://wpt.fyi/results/css/css-gaps/grid/grid-gap-decorations-090.html "css/css-gaps/grid/grid-gap-decorations-090.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/grid-gap-decorations-090.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/grid-gap-decorations-090.html)
- [grid-gap-decorations-091.html](https://wpt.fyi/results/css/css-gaps/grid/grid-gap-decorations-091.html "css/css-gaps/grid/grid-gap-decorations-091.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/grid-gap-decorations-091.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/grid-gap-decorations-091.html)
- [grid-gap-decorations-092.html](https://wpt.fyi/results/css/css-gaps/grid/grid-gap-decorations-092.html "css/css-gaps/grid/grid-gap-decorations-092.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/grid-gap-decorations-092.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/grid-gap-decorations-092.html)
- [grid-gap-decorations-direction-inset.html](https://wpt.fyi/results/css/css-gaps/grid/grid-gap-decorations-direction-inset.html "css/css-gaps/grid/grid-gap-decorations-direction-inset.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/grid-gap-decorations-direction-inset.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/grid-gap-decorations-direction-inset.html)
- [subgrid-gap-decorations-007.html](https://wpt.fyi/results/css/css-gaps/grid/subgrid/subgrid-gap-decorations-007.html "css/css-gaps/grid/subgrid/subgrid-gap-decorations-007.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/subgrid/subgrid-gap-decorations-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/subgrid/subgrid-gap-decorations-007.html)
- [subgrid-gap-decorations-008.html](https://wpt.fyi/results/css/css-gaps/grid/subgrid/subgrid-gap-decorations-008.html "css/css-gaps/grid/subgrid/subgrid-gap-decorations-008.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/subgrid/subgrid-gap-decorations-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/subgrid/subgrid-gap-decorations-008.html)
- [multicol-gap-decorations-008.html](https://wpt.fyi/results/css/css-gaps/multicol/multicol-gap-decorations-008.html "css/css-gaps/multicol/multicol-gap-decorations-008.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/multicol/multicol-gap-decorations-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/multicol/multicol-gap-decorations-008.html)
- [multicol-gap-decorations-009.html](https://wpt.fyi/results/css/css-gaps/multicol/multicol-gap-decorations-009.html "css/css-gaps/multicol/multicol-gap-decorations-009.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/multicol/multicol-gap-decorations-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/multicol/multicol-gap-decorations-009.html)
- [multicol-gap-decorations-010.html](https://wpt.fyi/results/css/css-gaps/multicol/multicol-gap-decorations-010.html "css/css-gaps/multicol/multicol-gap-decorations-010.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/multicol/multicol-gap-decorations-010.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/multicol/multicol-gap-decorations-010.html)
- [multicol-gap-decorations-011.html](https://wpt.fyi/results/css/css-gaps/multicol/multicol-gap-decorations-011.html "css/css-gaps/multicol/multicol-gap-decorations-011.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/multicol/multicol-gap-decorations-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/multicol/multicol-gap-decorations-011.html)
- [multicol-gap-decorations-012.html](https://wpt.fyi/results/css/css-gaps/multicol/multicol-gap-decorations-012.html "css/css-gaps/multicol/multicol-gap-decorations-012.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/multicol/multicol-gap-decorations-012.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/multicol/multicol-gap-decorations-012.html)
- [multicol-gap-decorations-017.html](https://wpt.fyi/results/css/css-gaps/multicol/multicol-gap-decorations-017.html "css/css-gaps/multicol/multicol-gap-decorations-017.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/multicol/multicol-gap-decorations-017.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/multicol/multicol-gap-decorations-017.html)
- [multicol-gap-decorations-022.html](https://wpt.fyi/results/css/css-gaps/multicol/multicol-gap-decorations-022.html "css/css-gaps/multicol/multicol-gap-decorations-022.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/multicol/multicol-gap-decorations-022.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/multicol/multicol-gap-decorations-022.html)
- [multicol-gap-decorations-023.html](https://wpt.fyi/results/css/css-gaps/multicol/multicol-gap-decorations-023.html "css/css-gaps/multicol/multicol-gap-decorations-023.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/multicol/multicol-gap-decorations-023.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/multicol/multicol-gap-decorations-023.html)
- [multicol-gap-decorations-033.html](https://wpt.fyi/results/css/css-gaps/multicol/multicol-gap-decorations-033.html "css/css-gaps/multicol/multicol-gap-decorations-033.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/multicol/multicol-gap-decorations-033.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/multicol/multicol-gap-decorations-033.html)
- [multicol-gap-decorations-036.html](https://wpt.fyi/results/css/css-gaps/multicol/multicol-gap-decorations-036.html "css/css-gaps/multicol/multicol-gap-decorations-036.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/multicol/multicol-gap-decorations-036.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/multicol/multicol-gap-decorations-036.html)
- [multicol-gap-decorations-037.html](https://wpt.fyi/results/css/css-gaps/multicol/multicol-gap-decorations-037.html "css/css-gaps/multicol/multicol-gap-decorations-037.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/multicol/multicol-gap-decorations-037.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/multicol/multicol-gap-decorations-037.html)
- [multicol-gap-decorations-038.html](https://wpt.fyi/results/css/css-gaps/multicol/multicol-gap-decorations-038.html "css/css-gaps/multicol/multicol-gap-decorations-038.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/multicol/multicol-gap-decorations-038.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/multicol/multicol-gap-decorations-038.html)
- [multicol-gap-decorations-039.html](https://wpt.fyi/results/css/css-gaps/multicol/multicol-gap-decorations-039.html "css/css-gaps/multicol/multicol-gap-decorations-039.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/multicol/multicol-gap-decorations-039.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/multicol/multicol-gap-decorations-039.html)
- [multicol-gap-decorations-direction-inset.html](https://wpt.fyi/results/css/css-gaps/multicol/multicol-gap-decorations-direction-inset.html "css/css-gaps/multicol/multicol-gap-decorations-direction-inset.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/multicol/multicol-gap-decorations-direction-inset.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/multicol/multicol-gap-decorations-direction-inset.html)
- [rule-inset-cap-start-end-computed.html](https://wpt.fyi/results/css/css-gaps/parsing/rule-inset-cap-start-end-computed.html "css/css-gaps/parsing/rule-inset-cap-start-end-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/parsing/rule-inset-cap-start-end-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/parsing/rule-inset-cap-start-end-computed.html)
- [rule-inset-cap-start-end-invalid.html](https://wpt.fyi/results/css/css-gaps/parsing/rule-inset-cap-start-end-invalid.html "css/css-gaps/parsing/rule-inset-cap-start-end-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/parsing/rule-inset-cap-start-end-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/parsing/rule-inset-cap-start-end-invalid.html)
- [rule-inset-junction-start-end-computed.html](https://wpt.fyi/results/css/css-gaps/parsing/rule-inset-junction-start-end-computed.html "css/css-gaps/parsing/rule-inset-junction-start-end-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/parsing/rule-inset-junction-start-end-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/parsing/rule-inset-junction-start-end-computed.html)
- [rule-inset-junction-start-end-invalid.html](https://wpt.fyi/results/css/css-gaps/parsing/rule-inset-junction-start-end-invalid.html "css/css-gaps/parsing/rule-inset-junction-start-end-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/parsing/rule-inset-junction-start-end-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/parsing/rule-inset-junction-start-end-invalid.html)

#### [3.3.1. ][ [-start] and [-end] shorthands]
These shorthands allow authors to achieve uniform asymmetric
decorations.

.inset-start-8px-end-0px {
 column-rule-inset-start: 8px;
 column-rule-inset-end: 0px;
 }

![A start inset of [8px] recedes the starts of [gap
decorations](#gap-decoration), while an end inset of [0px] aligns the ends of
[gap decorations] with content
edges.](images/example-column-inset-start-end.png){height="355"
width="352"}

Name:

[column-rule-inset-start],
[column-rule-inset-end],
[row-rule-inset-start],
[row-rule-inset-end]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<inset-value\>](#typedef-inset-value)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

see individual properties

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

Same as
[column-rule-inset-cap-start](#propdef-column-rule-inset-cap-start),
[column-rule-inset-junction-start](#propdef-column-rule-inset-junction-start),
[column-rule-inset-cap-end](#propdef-column-rule-inset-cap-end),
[column-rule-inset-junction-end](#propdef-column-rule-inset-junction-end),
[row-rule-inset-cap-start](#propdef-row-rule-inset-cap-start),
[row-rule-inset-junction-start](#propdef-row-rule-inset-junction-start),
[row-rule-inset-cap-end](#propdef-row-rule-inset-cap-end), and
[row-rule-inset-junction-end](#propdef-row-rule-inset-junction-end)

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

These [shorthand
properties](https://drafts.csswg.org/css-cascade-5/#shorthand-property) set the corresponding [-cap-] and
[-junction-] properties to the same value. For example,
[column-rule-inset-start](#propdef-column-rule-inset-start) sets both
[column-rule-inset-cap-start](#propdef-column-rule-inset-cap-start) and
[column-rule-inset-junction-start](#propdef-column-rule-inset-junction-start) to the same value.

Name:

[rule-inset-start]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<\'column-rule-inset-start\'\>](#propdef-column-rule-inset-start)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

see individual properties

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

Same as
[column-rule-inset-start](#propdef-column-rule-inset-start) and
[row-rule-inset-start](#propdef-row-rule-inset-start)

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

This [shorthand
property](https://drafts.csswg.org/css-cascade-5/#shorthand-property) sets
[column-rule-inset-start](#propdef-column-rule-inset-start) and
[row-rule-inset-start](#propdef-row-rule-inset-start) to the same value.

Name:

[rule-inset-end]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<\'column-rule-inset-end\'\>](#propdef-column-rule-inset-end)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

see individual properties

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

Same as
[column-rule-inset-end](#propdef-column-rule-inset-end) and
[row-rule-inset-end](#propdef-row-rule-inset-end)

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

This [shorthand
property](https://drafts.csswg.org/css-cascade-5/#shorthand-property) sets
[column-rule-inset-end](#propdef-column-rule-inset-end) and
[row-rule-inset-end](#propdef-row-rule-inset-end) to the same value.

Tests

- [rule-inset-start-end-bidirectional-shorthand.html](https://wpt.fyi/results/css/css-gaps/parsing/rule-inset-start-end-bidirectional-shorthand.html "css/css-gaps/parsing/rule-inset-start-end-bidirectional-shorthand.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/parsing/rule-inset-start-end-bidirectional-shorthand.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/parsing/rule-inset-start-end-bidirectional-shorthand.html)
- [rule-inset-start-end-computed.html](https://wpt.fyi/results/css/css-gaps/parsing/rule-inset-start-end-computed.html "css/css-gaps/parsing/rule-inset-start-end-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/parsing/rule-inset-start-end-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/parsing/rule-inset-start-end-computed.html)
- [rule-inset-start-end-invalid.html](https://wpt.fyi/results/css/css-gaps/parsing/rule-inset-start-end-invalid.html "css/css-gaps/parsing/rule-inset-start-end-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/parsing/rule-inset-start-end-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/parsing/rule-inset-start-end-invalid.html)
- [rule-inset-start-end-shorthand.html](https://wpt.fyi/results/css/css-gaps/parsing/rule-inset-start-end-shorthand.html "css/css-gaps/parsing/rule-inset-start-end-shorthand.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/parsing/rule-inset-start-end-shorthand.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/parsing/rule-inset-start-end-shorthand.html)
- [rule-inset-start-end-valid.html](https://wpt.fyi/results/css/css-gaps/parsing/rule-inset-start-end-valid.html "css/css-gaps/parsing/rule-inset-start-end-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/parsing/rule-inset-start-end-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/parsing/rule-inset-start-end-valid.html)

#### [3.3.2. ][ [-cap-] and [-junction-] shorthands]
These shorthands allow authors to achieve different treatments at [cap
segment
endpoints](#cap-segment-endpoint) versus [junction segment
endpoints](#junction-segment-endpoint).

.inset-cap-0px-inset-junction-negative-5px {
 column-rule-inset-cap: 0px;
 column-rule-inset-junction: -5px;
 column-rule-break: intersection;
 }

![A junction inset of [-5px] extends the endpoints of [gap
decorations](#gap-decoration)
at [junction segment
endpoints](#junction-segment-endpoint) slightly beyond the edges of adjacent items. A cap
inset of [0px] aligns the endpoints of [gap
decorations] at [cap segment
endpoints](#cap-segment-endpoint) with the content
edges.](images/example-column-inset-junction-5px.png){height="353"
width="349"}

Name:

[column-rule-inset-cap],
[column-rule-inset-junction],
[row-rule-inset-cap],
[row-rule-inset-junction]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<inset-value\>](#typedef-inset-value)
[\<inset-value\>][?](https://drafts.csswg.org/css-values-4/#mult-opt)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

see individual properties

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

Same as
[column-rule-inset-cap-start](#propdef-column-rule-inset-cap-start),
[column-rule-inset-cap-end](#propdef-column-rule-inset-cap-end),
[column-rule-inset-junction-start](#propdef-column-rule-inset-junction-start),
[column-rule-inset-junction-end](#propdef-column-rule-inset-junction-end),
[row-rule-inset-cap-start](#propdef-row-rule-inset-cap-start),
[row-rule-inset-cap-end](#propdef-row-rule-inset-cap-end),
[row-rule-inset-junction-start](#propdef-row-rule-inset-junction-start), and
[row-rule-inset-junction-end](#propdef-row-rule-inset-junction-end)

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

These shorthands set the corresponding [-start] and [-end]
properties. For example,
[column-rule-inset-cap](#propdef-column-rule-inset-cap) sets both
[column-rule-inset-cap-start](#propdef-column-rule-inset-cap-start) and
[column-rule-inset-cap-end](#propdef-column-rule-inset-cap-end). If one value is specified, both
properties are set to that value. If two values are specified,
[-start] is set to the first and [-end] is set to the
second.

Name:

[rule-inset-cap]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<\'column-rule-inset-cap\'\>](#propdef-column-rule-inset-cap)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

see individual properties

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

Same as
[column-rule-inset-cap](#propdef-column-rule-inset-cap) and
[row-rule-inset-cap](#propdef-row-rule-inset-cap)

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

This [shorthand
property](https://drafts.csswg.org/css-cascade-5/#shorthand-property) sets
[column-rule-inset-cap](#propdef-column-rule-inset-cap) and
[row-rule-inset-cap](#propdef-row-rule-inset-cap) to the same value.

Name:

[rule-inset-junction]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<\'column-rule-inset-junction\'\>](#propdef-column-rule-inset-junction)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

see individual properties

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

Same as
[column-rule-inset-junction](#propdef-column-rule-inset-junction) and
[row-rule-inset-junction](#propdef-row-rule-inset-junction)

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

This [shorthand
property](https://drafts.csswg.org/css-cascade-5/#shorthand-property) sets
[column-rule-inset-junction](#propdef-column-rule-inset-junction) and
[row-rule-inset-junction](#propdef-row-rule-inset-junction) to the same value.

Tests

- [rule-inset-cap-bidirectional-shorthand.html](https://wpt.fyi/results/css/css-gaps/parsing/rule-inset-cap-bidirectional-shorthand.html "css/css-gaps/parsing/rule-inset-cap-bidirectional-shorthand.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/parsing/rule-inset-cap-bidirectional-shorthand.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/parsing/rule-inset-cap-bidirectional-shorthand.html)
- [rule-inset-cap-junction-computed.html](https://wpt.fyi/results/css/css-gaps/parsing/rule-inset-cap-junction-computed.html "css/css-gaps/parsing/rule-inset-cap-junction-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/parsing/rule-inset-cap-junction-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/parsing/rule-inset-cap-junction-computed.html)
- [rule-inset-cap-junction-invalid.html](https://wpt.fyi/results/css/css-gaps/parsing/rule-inset-cap-junction-invalid.html "css/css-gaps/parsing/rule-inset-cap-junction-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/parsing/rule-inset-cap-junction-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/parsing/rule-inset-cap-junction-invalid.html)
- [rule-inset-cap-junction-shorthand.html](https://wpt.fyi/results/css/css-gaps/parsing/rule-inset-cap-junction-shorthand.html "css/css-gaps/parsing/rule-inset-cap-junction-shorthand.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/parsing/rule-inset-cap-junction-shorthand.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/parsing/rule-inset-cap-junction-shorthand.html)
- [rule-inset-cap-junction-valid.html](https://wpt.fyi/results/css/css-gaps/parsing/rule-inset-cap-junction-valid.html "css/css-gaps/parsing/rule-inset-cap-junction-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/parsing/rule-inset-cap-junction-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/parsing/rule-inset-cap-junction-valid.html)
- [rule-inset-junction-bidirectional-shorthand.html](https://wpt.fyi/results/css/css-gaps/parsing/rule-inset-junction-bidirectional-shorthand.html "css/css-gaps/parsing/rule-inset-junction-bidirectional-shorthand.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/parsing/rule-inset-junction-bidirectional-shorthand.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/parsing/rule-inset-junction-bidirectional-shorthand.html)

#### 3.3.3. Universal shorthands

These shorthands allow authors to achieve uniform treatments throughout
a container.

.inset-0px {
 column-rule-inset: 0px;
 column-rule-break: intersection;
 }

![An inset of [0px] aligns the ends of [gap
decorations](#gap-decoration)
with adjacent items.](images/example-column-inset-0px.png){height="350"
width="352"}

.inset-positive-5px {
 column-rule-inset: 5px;
 column-rule-break: intersection;
 }

![An inset of [5px] shortens the ends of [gap
decorations](#gap-decoration)
relative to the edges of adjacent
items.](images/example-column-inset-5px.png){height="351" width="352"}

.inset-negative-5px {
 column-rule-inset: -5px;
 column-rule-break: intersection;
 }

![An inset of [-5px] extends the ends of [gap
decorations](#gap-decoration)
slightly beyond the edges of adjacent
items.](images/example-column-inset-minus-5px.png){height="360"
width="356"}

.inset-negative-50percent {
 column-rule-inset: -50%;
 column-rule-break: intersection;
 }

![An inset of [-50%] extends each end of a [gap
decoration](#gap-decoration)
halfway into its intersection. Neighboring [gap
decorations] \"meet in the middle\" to create
a continuous line. Note that at the edges of the container, the
[crossing gap width](#crossing-gap-width) is defined to be [0], so the inset value of
[-50%] resolves to [0] and thus the [gap
decoration] does not extend beyond the bounds
of the container. (Contrast with the previous example, which specified
an inset in [px](https://drafts.csswg.org/css-values-4/#px)
units.)](images/example-column-inset-50percent.png){height="350"
width="351"}

Name:

[column-rule-inset], [row-rule-inset]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<\'column-rule-inset-cap\'\>](#propdef-column-rule-inset-cap) \[ /
[\<\'column-rule-inset-junction\'\>](#propdef-column-rule-inset-junction)
\][?](https://drafts.csswg.org/css-values-4/#mult-opt)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

see individual properties

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

Same as
[column-rule-inset-cap](#propdef-column-rule-inset-cap),
[column-rule-inset-junction](#propdef-column-rule-inset-junction),
[row-rule-inset-cap](#propdef-row-rule-inset-cap), and
[row-rule-inset-junction](#propdef-row-rule-inset-junction)

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

These shorthands set the corresponding cap and junction start and end
values. The order of values is:

``` prod
cap-start cap-end? [/ junction-start junction-end?]?
```

Omitted values are filled in as follows:

1. If the junction values are omitted, they are copied from the cap
 values.
2. Any omitted end value is copied from the corresponding start value.

Name:

[rule-inset]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<\'column-rule-inset\'\>](#propdef-column-rule-inset)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

see individual properties

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

Same as
[column-rule-inset](#propdef-column-rule-inset) and
[row-rule-inset](#propdef-row-rule-inset)

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

This [shorthand
property](https://drafts.csswg.org/css-cascade-5/#shorthand-property) sets
[column-rule-inset](#propdef-column-rule-inset) and
[row-rule-inset](#propdef-row-rule-inset) to the same value.

Tests

- [rule-inset-bidirectional-shorthand.html](https://wpt.fyi/results/css/css-gaps/parsing/rule-inset-bidirectional-shorthand.html "css/css-gaps/parsing/rule-inset-bidirectional-shorthand.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/parsing/rule-inset-bidirectional-shorthand.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/parsing/rule-inset-bidirectional-shorthand.html)
- [rule-inset-computed.html](https://wpt.fyi/results/css/css-gaps/parsing/rule-inset-computed.html "css/css-gaps/parsing/rule-inset-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/parsing/rule-inset-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/parsing/rule-inset-computed.html)
- [rule-inset-invalid.html](https://wpt.fyi/results/css/css-gaps/parsing/rule-inset-invalid.html "css/css-gaps/parsing/rule-inset-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/parsing/rule-inset-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/parsing/rule-inset-invalid.html)
- [rule-inset-shorthand.html](https://wpt.fyi/results/css/css-gaps/parsing/rule-inset-shorthand.html "css/css-gaps/parsing/rule-inset-shorthand.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/parsing/rule-inset-shorthand.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/parsing/rule-inset-shorthand.html)
- [rule-inset-valid.html](https://wpt.fyi/results/css/css-gaps/parsing/rule-inset-valid.html "css/css-gaps/parsing/rule-inset-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/parsing/rule-inset-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/parsing/rule-inset-valid.html)

### 3.4. Gap decoration visibility: The [rule-visibility-items properties]
Name:

[column-rule-visibility-items],
[row-rule-visibility-items]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[all](#valdef-column-rule-visibility-items-all)
[\|](https://drafts.csswg.org/css-values-4/#comb-one)
[around](#valdef-column-rule-visibility-items-around) [\|]
[between](#valdef-column-rule-visibility-items-between) [\|]
[normal](#valdef-column-rule-visibility-items-normal)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

[normal](#valdef-column-rule-visibility-items-normal)

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[grid
containers](https://drafts.csswg.org/css-grid-2/#grid-container) and [multicol
containers](https://drafts.csswg.org/css-multicol-2/#multi-column-container)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

as specified

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

These properties control whether a [gap decoration
segment](#gap-decoration-segment) is painted in portions of [gaps](#gap) adjacent to empty areas.

[all]
: Paint decorations in all gap segments, regardless of whether
 adjacent items are present.

[around]
: Paint decorations in a gap segment if at least one of the two
 adjacent areas is occupied by an item.

[between]
: Paint decorations in a gap segment if both adjacent areas are
 occupied by items.

[normal]
: Behavior depends on the type of container.

 [Grid containers](https://drafts.csswg.org/css-grid-2/#grid-container)
 : Behaves the same as
 [all](#valdef-column-rule-visibility-items-all).

 [Multicol containers](https://drafts.csswg.org/css-multicol-2/#multi-column-container)
 : On
 [column-rule-visibility-items](#propdef-column-rule-visibility-items), behaves the same as
 [between](#valdef-column-rule-visibility-items-between). On
 [row-rule-visibility-items](#propdef-row-rule-visibility-items), behaves the same as
 [all](#valdef-column-rule-visibility-items-all).

Name:

[rule-visibility-items]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<\'column-rule-visibility-items\'\>](#propdef-column-rule-visibility-items)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

see individual properties

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

Same as
[column-rule-visibility-items](#propdef-column-rule-visibility-items) and
[row-rule-visibility-items](#propdef-row-rule-visibility-items)

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

This [shorthand
property](https://drafts.csswg.org/css-cascade-5/#shorthand-property) sets
[column-rule-visibility-items](#propdef-column-rule-visibility-items) and
[row-rule-visibility-items](#propdef-row-rule-visibility-items) to the same value.

.break-normal-with-all-grid {
 display: grid;
 grid-template: repeat(3, 100px) / repeat(3, 100px);
 gap: 20px;
 row-rule: 6px solid red;
 column-rule: 6px solid blue;
 rule-visibility-items: all;
 }

![Gap decorations in Grid with
[normal](#valdef-column-rule-break-normal) rule breaking and
[all](#valdef-column-rule-visibility-items-all)
visibility.](images/example-visibility-all-normal.png){height="354"
width="354"}

.break-normal-with-around-grid {
 display: grid;
 grid-template: repeat(3, 100px) / repeat(3, 100px);
 gap: 20px;
 row-rule: 6px solid red;
 column-rule: 6px solid blue;
 rule-visibility-items: around;
 }

![Gap decorations in Grid with
[normal](#valdef-column-rule-break-normal) rule breaking and
[around](#valdef-column-rule-visibility-items-around)
visibility.](images/example-visibility-around-normal.png){height="357"
width="360"}

.break-normal-with-between-grid {
 display: grid;
 grid-template: repeat(3, 100px) / repeat(3, 100px);
 gap: 20px;
 row-rule: 6px solid red;
 column-rule: 6px solid blue;
 rule-visibility-items: between;
 }

![Gap decorations in Grid with
[normal](#valdef-column-rule-break-normal) rule breaking and
[between](#valdef-column-rule-visibility-items-between)
visibility.](images/example-visibility-between-normal.png){height="353"
width="355"}

- [grid-gap-decorations-fragmentation-025.html](https://wpt.fyi/results/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-025.html "css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-025.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-025.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-025.html)
- [grid-gap-decorations-fragmentation-026.html](https://wpt.fyi/results/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-026.html "css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-026.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-026.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-026.html)
- [grid-gap-decorations-fragmentation-027.html](https://wpt.fyi/results/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-027.html "css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-027.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-027.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-027.html)
- [grid-gap-decorations-054.html](https://wpt.fyi/results/css/css-gaps/grid/grid-gap-decorations-054.html "css/css-gaps/grid/grid-gap-decorations-054.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/grid-gap-decorations-054.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/grid-gap-decorations-054.html)
- [grid-gap-decorations-055.html](https://wpt.fyi/results/css/css-gaps/grid/grid-gap-decorations-055.html "css/css-gaps/grid/grid-gap-decorations-055.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/grid-gap-decorations-055.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/grid-gap-decorations-055.html)
- [grid-gap-decorations-056.html](https://wpt.fyi/results/css/css-gaps/grid/grid-gap-decorations-056.html "css/css-gaps/grid/grid-gap-decorations-056.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/grid-gap-decorations-056.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/grid-gap-decorations-056.html)
- [grid-gap-decorations-057.html](https://wpt.fyi/results/css/css-gaps/grid/grid-gap-decorations-057.html "css/css-gaps/grid/grid-gap-decorations-057.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/grid-gap-decorations-057.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/grid-gap-decorations-057.html)
- [grid-gap-decorations-064.html](https://wpt.fyi/results/css/css-gaps/grid/grid-gap-decorations-064.html "css/css-gaps/grid/grid-gap-decorations-064.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/grid-gap-decorations-064.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/grid-gap-decorations-064.html)
- [grid-gap-decorations-065.html](https://wpt.fyi/results/css/css-gaps/grid/grid-gap-decorations-065.html "css/css-gaps/grid/grid-gap-decorations-065.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/grid-gap-decorations-065.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/grid-gap-decorations-065.html)
- [subgrid-gap-decorations-019.html](https://wpt.fyi/results/css/css-gaps/grid/subgrid/subgrid-gap-decorations-019.html "css/css-gaps/grid/subgrid/subgrid-gap-decorations-019.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/subgrid/subgrid-gap-decorations-019.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/subgrid/subgrid-gap-decorations-019.html)
- [subgrid-gap-decorations-020.html](https://wpt.fyi/results/css/css-gaps/grid/subgrid/subgrid-gap-decorations-020.html "css/css-gaps/grid/subgrid/subgrid-gap-decorations-020.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/subgrid/subgrid-gap-decorations-020.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/subgrid/subgrid-gap-decorations-020.html)
- [subgrid-gap-decorations-021.html](https://wpt.fyi/results/css/css-gaps/grid/subgrid/subgrid-gap-decorations-021.html "css/css-gaps/grid/subgrid/subgrid-gap-decorations-021.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/subgrid/subgrid-gap-decorations-021.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/subgrid/subgrid-gap-decorations-021.html)
- [subgrid-gap-decorations-022.html](https://wpt.fyi/results/css/css-gaps/grid/subgrid/subgrid-gap-decorations-022.html "css/css-gaps/grid/subgrid/subgrid-gap-decorations-022.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/subgrid/subgrid-gap-decorations-022.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/subgrid/subgrid-gap-decorations-022.html)
- [subgrid-gap-decorations-023.html](https://wpt.fyi/results/css/css-gaps/grid/subgrid/subgrid-gap-decorations-023.html "css/css-gaps/grid/subgrid/subgrid-gap-decorations-023.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/subgrid/subgrid-gap-decorations-023.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/subgrid/subgrid-gap-decorations-023.html)
- [subgrid-gap-decorations-024.html](https://wpt.fyi/results/css/css-gaps/grid/subgrid/subgrid-gap-decorations-024.html "css/css-gaps/grid/subgrid/subgrid-gap-decorations-024.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/subgrid/subgrid-gap-decorations-024.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/subgrid/subgrid-gap-decorations-024.html)
- [subgrid-gap-decorations-025.html](https://wpt.fyi/results/css/css-gaps/grid/subgrid/subgrid-gap-decorations-025.html "css/css-gaps/grid/subgrid/subgrid-gap-decorations-025.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/subgrid/subgrid-gap-decorations-025.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/subgrid/subgrid-gap-decorations-025.html)
- [multicol-gap-decorations-027.html](https://wpt.fyi/results/css/css-gaps/multicol/multicol-gap-decorations-027.html "css/css-gaps/multicol/multicol-gap-decorations-027.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/multicol/multicol-gap-decorations-027.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/multicol/multicol-gap-decorations-027.html)
- [multicol-gap-decorations-028.html](https://wpt.fyi/results/css/css-gaps/multicol/multicol-gap-decorations-028.html "css/css-gaps/multicol/multicol-gap-decorations-028.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/multicol/multicol-gap-decorations-028.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/multicol/multicol-gap-decorations-028.html)
- [multicol-gap-decorations-029.html](https://wpt.fyi/results/css/css-gaps/multicol/multicol-gap-decorations-029.html "css/css-gaps/multicol/multicol-gap-decorations-029.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/multicol/multicol-gap-decorations-029.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/multicol/multicol-gap-decorations-029.html)
- [multicol-gap-decorations-030.html](https://wpt.fyi/results/css/css-gaps/multicol/multicol-gap-decorations-030.html "css/css-gaps/multicol/multicol-gap-decorations-030.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/multicol/multicol-gap-decorations-030.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/multicol/multicol-gap-decorations-030.html)
- [multicol-gap-decorations-031.html](https://wpt.fyi/results/css/css-gaps/multicol/multicol-gap-decorations-031.html "css/css-gaps/multicol/multicol-gap-decorations-031.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/multicol/multicol-gap-decorations-031.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/multicol/multicol-gap-decorations-031.html)
- [multicol-gap-decorations-032.html](https://wpt.fyi/results/css/css-gaps/multicol/multicol-gap-decorations-032.html "css/css-gaps/multicol/multicol-gap-decorations-032.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/multicol/multicol-gap-decorations-032.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/multicol/multicol-gap-decorations-032.html)
- [multicol-gap-decorations-035.html](https://wpt.fyi/results/css/css-gaps/multicol/multicol-gap-decorations-035.html "css/css-gaps/multicol/multicol-gap-decorations-035.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/multicol/multicol-gap-decorations-035.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/multicol/multicol-gap-decorations-035.html)
- [rule-visibility-items-computed.html](https://wpt.fyi/results/css/css-gaps/parsing/rule-visibility-items-computed.html "css/css-gaps/parsing/rule-visibility-items-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/parsing/rule-visibility-items-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/parsing/rule-visibility-items-computed.html)
- [rule-visibility-items-invalid.html](https://wpt.fyi/results/css/css-gaps/parsing/rule-visibility-items-invalid.html "css/css-gaps/parsing/rule-visibility-items-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/parsing/rule-visibility-items-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/parsing/rule-visibility-items-invalid.html)
- [rule-visibility-items-shorthand.html](https://wpt.fyi/results/css/css-gaps/parsing/rule-visibility-items-shorthand.html "css/css-gaps/parsing/rule-visibility-items-shorthand.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/parsing/rule-visibility-items-shorthand.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/parsing/rule-visibility-items-shorthand.html)
- [rule-visibility-items-valid.html](https://wpt.fyi/results/css/css-gaps/parsing/rule-visibility-items-valid.html "css/css-gaps/parsing/rule-visibility-items-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/parsing/rule-visibility-items-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/parsing/rule-visibility-items-valid.html)

### 3.5. Gap decoration overlap: The [rule-overlap property]
Name:

[rule-overlap]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[row-over-column](#valdef-rule-overlap-row-over-column)
[\|](https://drafts.csswg.org/css-values-4/#comb-one)
[column-over-row](#valdef-rule-overlap-column-over-row)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

[row-over-column](#valdef-rule-overlap-row-over-column)

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[grid
containers](https://drafts.csswg.org/css-grid-2/#grid-container), [flex
containers](https://drafts.csswg.org/css-flexbox-2/#flex-container), and [grid lanes
containers](https://drafts.csswg.org/css-grid-3/#grid-lanes-container)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

as specified

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

This property sets the paint order for overlapping [gap
decorations](#gap-decoration).

[row-over-column]
: Row-direction decorations are painted above column-direction
 decorations.

[column-over-row]
: Column-direction decorations are painted above row-direction
 decorations.

.row-over-column {
 rule-overlap: row-over-column;
 row-rule: 6px solid red;
 column-rule: 6px solid blue;
 }

![Row-over-column gap decoration
overlap.](images/example-row-over-column.png){height="362" width="359"}

.column-over-row {
 rule-overlap: column-over-row;
 row-rule: 6px solid red;
 column-rule: 6px solid blue;
 }

![Column-over-row gap decoration
overlap.](images/example-column-over-row.png){height="359" width="358"}

- [flex-gap-decorations-012.html](https://wpt.fyi/results/css/css-gaps/flex/flex-gap-decorations-012.html "css/css-gaps/flex/flex-gap-decorations-012.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/flex/flex-gap-decorations-012.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/flex/flex-gap-decorations-012.html)
- [grid-gap-decorations-023.html](https://wpt.fyi/results/css/css-gaps/grid/grid-gap-decorations-023.html "css/css-gaps/grid/grid-gap-decorations-023.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/grid-gap-decorations-023.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/grid-gap-decorations-023.html)
- [subgrid-gap-decorations-017.html](https://wpt.fyi/results/css/css-gaps/grid/subgrid/subgrid-gap-decorations-017.html "css/css-gaps/grid/subgrid/subgrid-gap-decorations-017.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/subgrid/subgrid-gap-decorations-017.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/subgrid/subgrid-gap-decorations-017.html)
- [rule-overlap-computed.html](https://wpt.fyi/results/css/css-gaps/parsing/rule-overlap-computed.html "css/css-gaps/parsing/rule-overlap-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/parsing/rule-overlap-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/parsing/rule-overlap-computed.html)
- [rule-overlap-invalid.html](https://wpt.fyi/results/css/css-gaps/parsing/rule-overlap-invalid.html "css/css-gaps/parsing/rule-overlap-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/parsing/rule-overlap-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/parsing/rule-overlap-invalid.html)
- [rule-overlap-valid.html](https://wpt.fyi/results/css/css-gaps/parsing/rule-overlap-valid.html "css/css-gaps/parsing/rule-overlap-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/parsing/rule-overlap-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/parsing/rule-overlap-valid.html)

### 3.6. Fragmentation

{spec-section="#column-row-gap"} specifies that gaps disappear where
they coincide with a [fragmentation
break](https://drafts.csswg.org/css-break-4/#fragmentation-break). Because there is no gap in such locations, no [gap
decoration](#gap-decoration)
is drawn in them either.

Tests

- [flex-gap-decorations-fragmentation-001.html](https://wpt.fyi/results/css/css-gaps/flex/fragmentation/flex-gap-decorations-fragmentation-001.html "css/css-gaps/flex/fragmentation/flex-gap-decorations-fragmentation-001.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/flex/fragmentation/flex-gap-decorations-fragmentation-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/flex/fragmentation/flex-gap-decorations-fragmentation-001.html)
- [flex-gap-decorations-fragmentation-002.html](https://wpt.fyi/results/css/css-gaps/flex/fragmentation/flex-gap-decorations-fragmentation-002.html "css/css-gaps/flex/fragmentation/flex-gap-decorations-fragmentation-002.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/flex/fragmentation/flex-gap-decorations-fragmentation-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/flex/fragmentation/flex-gap-decorations-fragmentation-002.html)
- [flex-gap-decorations-fragmentation-003.html](https://wpt.fyi/results/css/css-gaps/flex/fragmentation/flex-gap-decorations-fragmentation-003.html "css/css-gaps/flex/fragmentation/flex-gap-decorations-fragmentation-003.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/flex/fragmentation/flex-gap-decorations-fragmentation-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/flex/fragmentation/flex-gap-decorations-fragmentation-003.html)
- [flex-gap-decorations-fragmentation-004.html](https://wpt.fyi/results/css/css-gaps/flex/fragmentation/flex-gap-decorations-fragmentation-004.html "css/css-gaps/flex/fragmentation/flex-gap-decorations-fragmentation-004.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/flex/fragmentation/flex-gap-decorations-fragmentation-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/flex/fragmentation/flex-gap-decorations-fragmentation-004.html)
- [flex-gap-decorations-fragmentation-005.html](https://wpt.fyi/results/css/css-gaps/flex/fragmentation/flex-gap-decorations-fragmentation-005.html "css/css-gaps/flex/fragmentation/flex-gap-decorations-fragmentation-005.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/flex/fragmentation/flex-gap-decorations-fragmentation-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/flex/fragmentation/flex-gap-decorations-fragmentation-005.html)
- [flex-gap-decorations-fragmentation-006.html](https://wpt.fyi/results/css/css-gaps/flex/fragmentation/flex-gap-decorations-fragmentation-006.html "css/css-gaps/flex/fragmentation/flex-gap-decorations-fragmentation-006.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/flex/fragmentation/flex-gap-decorations-fragmentation-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/flex/fragmentation/flex-gap-decorations-fragmentation-006.html)
- [flex-gap-decorations-fragmentation-007.html](https://wpt.fyi/results/css/css-gaps/flex/fragmentation/flex-gap-decorations-fragmentation-007.html "css/css-gaps/flex/fragmentation/flex-gap-decorations-fragmentation-007.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/flex/fragmentation/flex-gap-decorations-fragmentation-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/flex/fragmentation/flex-gap-decorations-fragmentation-007.html)
- [flex-gap-decorations-fragmentation-008.html](https://wpt.fyi/results/css/css-gaps/flex/fragmentation/flex-gap-decorations-fragmentation-008.html "css/css-gaps/flex/fragmentation/flex-gap-decorations-fragmentation-008.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/flex/fragmentation/flex-gap-decorations-fragmentation-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/flex/fragmentation/flex-gap-decorations-fragmentation-008.html)
- [flex-gap-decorations-fragmentation-009.html](https://wpt.fyi/results/css/css-gaps/flex/fragmentation/flex-gap-decorations-fragmentation-009.html "css/css-gaps/flex/fragmentation/flex-gap-decorations-fragmentation-009.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/flex/fragmentation/flex-gap-decorations-fragmentation-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/flex/fragmentation/flex-gap-decorations-fragmentation-009.html)
- [flex-gap-decorations-fragmentation-010.html](https://wpt.fyi/results/css/css-gaps/flex/fragmentation/flex-gap-decorations-fragmentation-010.html "css/css-gaps/flex/fragmentation/flex-gap-decorations-fragmentation-010.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/flex/fragmentation/flex-gap-decorations-fragmentation-010.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/flex/fragmentation/flex-gap-decorations-fragmentation-010.html)
- [flex-gap-decorations-fragmentation-011.html](https://wpt.fyi/results/css/css-gaps/flex/fragmentation/flex-gap-decorations-fragmentation-011.html "css/css-gaps/flex/fragmentation/flex-gap-decorations-fragmentation-011.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/flex/fragmentation/flex-gap-decorations-fragmentation-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/flex/fragmentation/flex-gap-decorations-fragmentation-011.html)
- [flex-gap-decorations-fragmentation-012.html](https://wpt.fyi/results/css/css-gaps/flex/fragmentation/flex-gap-decorations-fragmentation-012.html "css/css-gaps/flex/fragmentation/flex-gap-decorations-fragmentation-012.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/flex/fragmentation/flex-gap-decorations-fragmentation-012.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/flex/fragmentation/flex-gap-decorations-fragmentation-012.html)
- [flex-gap-decorations-fragmentation-013.html](https://wpt.fyi/results/css/css-gaps/flex/fragmentation/flex-gap-decorations-fragmentation-013.html "css/css-gaps/flex/fragmentation/flex-gap-decorations-fragmentation-013.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/flex/fragmentation/flex-gap-decorations-fragmentation-013.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/flex/fragmentation/flex-gap-decorations-fragmentation-013.html)
- [flex-gap-decorations-fragmentation-014.html](https://wpt.fyi/results/css/css-gaps/flex/fragmentation/flex-gap-decorations-fragmentation-014.html "css/css-gaps/flex/fragmentation/flex-gap-decorations-fragmentation-014.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/flex/fragmentation/flex-gap-decorations-fragmentation-014.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/flex/fragmentation/flex-gap-decorations-fragmentation-014.html)
- [flex-gap-decorations-fragmentation-015.html](https://wpt.fyi/results/css/css-gaps/flex/fragmentation/flex-gap-decorations-fragmentation-015.html "css/css-gaps/flex/fragmentation/flex-gap-decorations-fragmentation-015.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/flex/fragmentation/flex-gap-decorations-fragmentation-015.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/flex/fragmentation/flex-gap-decorations-fragmentation-015.html)
- [flex-gap-decorations-fragmentation-016.html](https://wpt.fyi/results/css/css-gaps/flex/fragmentation/flex-gap-decorations-fragmentation-016.html "css/css-gaps/flex/fragmentation/flex-gap-decorations-fragmentation-016.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/flex/fragmentation/flex-gap-decorations-fragmentation-016.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/flex/fragmentation/flex-gap-decorations-fragmentation-016.html)
- [flex-gap-decorations-fragmentation-017.html](https://wpt.fyi/results/css/css-gaps/flex/fragmentation/flex-gap-decorations-fragmentation-017.html "css/css-gaps/flex/fragmentation/flex-gap-decorations-fragmentation-017.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/flex/fragmentation/flex-gap-decorations-fragmentation-017.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/flex/fragmentation/flex-gap-decorations-fragmentation-017.html)
- [flex-gap-decorations-fragmentation-018.html](https://wpt.fyi/results/css/css-gaps/flex/fragmentation/flex-gap-decorations-fragmentation-018.html "css/css-gaps/flex/fragmentation/flex-gap-decorations-fragmentation-018.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/flex/fragmentation/flex-gap-decorations-fragmentation-018.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/flex/fragmentation/flex-gap-decorations-fragmentation-018.html)
- [flex-gap-decorations-fragmentation-019.html](https://wpt.fyi/results/css/css-gaps/flex/fragmentation/flex-gap-decorations-fragmentation-019.html "css/css-gaps/flex/fragmentation/flex-gap-decorations-fragmentation-019.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/flex/fragmentation/flex-gap-decorations-fragmentation-019.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/flex/fragmentation/flex-gap-decorations-fragmentation-019.html)
- [flex-gap-decorations-fragmentation-020.html](https://wpt.fyi/results/css/css-gaps/flex/fragmentation/flex-gap-decorations-fragmentation-020.html "css/css-gaps/flex/fragmentation/flex-gap-decorations-fragmentation-020.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/flex/fragmentation/flex-gap-decorations-fragmentation-020.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/flex/fragmentation/flex-gap-decorations-fragmentation-020.html)
- [flex-gap-decorations-fragmentation-021.html](https://wpt.fyi/results/css/css-gaps/flex/fragmentation/flex-gap-decorations-fragmentation-021.html "css/css-gaps/flex/fragmentation/flex-gap-decorations-fragmentation-021.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/flex/fragmentation/flex-gap-decorations-fragmentation-021.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/flex/fragmentation/flex-gap-decorations-fragmentation-021.html)
- [flex-gap-decorations-fragmentation-022-crash.html](https://wpt.fyi/results/css/css-gaps/flex/fragmentation/flex-gap-decorations-fragmentation-022-crash.html "css/css-gaps/flex/fragmentation/flex-gap-decorations-fragmentation-022-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/flex/fragmentation/flex-gap-decorations-fragmentation-022-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/flex/fragmentation/flex-gap-decorations-fragmentation-022-crash.html)
- [flex-gap-decorations-fragmentation-026.html](https://wpt.fyi/results/css/css-gaps/flex/fragmentation/flex-gap-decorations-fragmentation-026.html "css/css-gaps/flex/fragmentation/flex-gap-decorations-fragmentation-026.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/flex/fragmentation/flex-gap-decorations-fragmentation-026.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/flex/fragmentation/flex-gap-decorations-fragmentation-026.html)
- [grid-gap-decorations-fragmentation-001.html](https://wpt.fyi/results/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-001.html "css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-001.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-001.html)
- [grid-gap-decorations-fragmentation-002.html](https://wpt.fyi/results/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-002.html "css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-002.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-002.html)
- [grid-gap-decorations-fragmentation-003.html](https://wpt.fyi/results/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-003.html "css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-003.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-003.html)
- [grid-gap-decorations-fragmentation-004.html](https://wpt.fyi/results/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-004.html "css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-004.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-004.html)
- [grid-gap-decorations-fragmentation-005.html](https://wpt.fyi/results/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-005.html "css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-005.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-005.html)
- [grid-gap-decorations-fragmentation-006.html](https://wpt.fyi/results/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-006.html "css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-006.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-006.html)
- [grid-gap-decorations-fragmentation-007.html](https://wpt.fyi/results/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-007.html "css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-007.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-007.html)
- [grid-gap-decorations-fragmentation-008.html](https://wpt.fyi/results/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-008.html "css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-008.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-008.html)
- [grid-gap-decorations-fragmentation-009.html](https://wpt.fyi/results/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-009.html "css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-009.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-009.html)
- [grid-gap-decorations-fragmentation-010.html](https://wpt.fyi/results/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-010.html "css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-010.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-010.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-010.html)
- [grid-gap-decorations-fragmentation-011.html](https://wpt.fyi/results/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-011.html "css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-011.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-011.html)
- [grid-gap-decorations-fragmentation-012.html](https://wpt.fyi/results/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-012.html "css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-012.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-012.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-012.html)
- [grid-gap-decorations-fragmentation-013.html](https://wpt.fyi/results/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-013.html "css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-013.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-013.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-013.html)
- [grid-gap-decorations-fragmentation-014.html](https://wpt.fyi/results/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-014.html "css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-014.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-014.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-014.html)
- [grid-gap-decorations-fragmentation-015.html](https://wpt.fyi/results/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-015.html "css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-015.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-015.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-015.html)
- [grid-gap-decorations-fragmentation-016.html](https://wpt.fyi/results/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-016.html "css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-016.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-016.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-016.html)
- [grid-gap-decorations-fragmentation-017.html](https://wpt.fyi/results/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-017.html "css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-017.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-017.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-017.html)
- [grid-gap-decorations-fragmentation-018-crash.html](https://wpt.fyi/results/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-018-crash.html "css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-018-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-018-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-018-crash.html)
- [grid-gap-decorations-fragmentation-019-crash.html](https://wpt.fyi/results/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-019-crash.html "css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-019-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-019-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-019-crash.html)
- [grid-gap-decorations-fragmentation-020.html](https://wpt.fyi/results/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-020.html "css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-020.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-020.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-020.html)
- [grid-gap-decorations-fragmentation-021.html](https://wpt.fyi/results/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-021.html "css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-021.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-021.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-021.html)
- [grid-gap-decorations-fragmentation-022.html](https://wpt.fyi/results/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-022.html "css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-022.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-022.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-022.html)
- [grid-gap-decorations-fragmentation-023.html](https://wpt.fyi/results/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-023.html "css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-023.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-023.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-023.html)
- [grid-gap-decorations-fragmentation-024.html](https://wpt.fyi/results/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-024.html "css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-024.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-024.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-024.html)
- [grid-gap-decorations-fragmentation-025.html](https://wpt.fyi/results/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-025.html "css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-025.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-025.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-025.html)
- [grid-gap-decorations-fragmentation-026.html](https://wpt.fyi/results/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-026.html "css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-026.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-026.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-026.html)
- [grid-gap-decorations-fragmentation-027.html](https://wpt.fyi/results/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-027.html "css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-027.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-027.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-027.html)
- [grid-gap-decorations-fragmentation-028.html](https://wpt.fyi/results/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-028.html "css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-028.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-028.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-028.html)
- [grid-gap-decorations-fragmentation-029.html](https://wpt.fyi/results/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-029.html "css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-029.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-029.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-029.html)
- [grid-gap-decorations-fragmentation-030.html](https://wpt.fyi/results/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-030.html "css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-030.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-030.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-030.html)
- [grid-gap-decorations-fragmentation-031.html](https://wpt.fyi/results/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-031.html "css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-031.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-031.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-031.html)
- [grid-gap-decorations-fragmentation-032.html](https://wpt.fyi/results/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-032.html "css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-032.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-032.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-032.html)
- [grid-gap-decorations-fragmentation-033.html](https://wpt.fyi/results/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-033.html "css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-033.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-033.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-033.html)
- [grid-gap-decorations-fragmentation-036.html](https://wpt.fyi/results/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-036.html "css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-036.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-036.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-036.html)
- [grid-gap-decorations-fragmentation-037.html](https://wpt.fyi/results/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-037.html "css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-037.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-037.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/fragmentation/grid-gap-decorations-fragmentation-037.html)
- [subgrid-gap-decorations-fragmentation-001.html](https://wpt.fyi/results/css/css-gaps/grid/subgrid/fragmentation/subgrid-gap-decorations-fragmentation-001.html "css/css-gaps/grid/subgrid/fragmentation/subgrid-gap-decorations-fragmentation-001.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/subgrid/fragmentation/subgrid-gap-decorations-fragmentation-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/subgrid/fragmentation/subgrid-gap-decorations-fragmentation-001.html)
- [subgrid-gap-decorations-fragmentation-002.html](https://wpt.fyi/results/css/css-gaps/grid/subgrid/fragmentation/subgrid-gap-decorations-fragmentation-002.html "css/css-gaps/grid/subgrid/fragmentation/subgrid-gap-decorations-fragmentation-002.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/subgrid/fragmentation/subgrid-gap-decorations-fragmentation-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/subgrid/fragmentation/subgrid-gap-decorations-fragmentation-002.html)
- [subgrid-gap-decorations-fragmentation-003.html](https://wpt.fyi/results/css/css-gaps/grid/subgrid/fragmentation/subgrid-gap-decorations-fragmentation-003.html "css/css-gaps/grid/subgrid/fragmentation/subgrid-gap-decorations-fragmentation-003.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/subgrid/fragmentation/subgrid-gap-decorations-fragmentation-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/subgrid/fragmentation/subgrid-gap-decorations-fragmentation-003.html)
- [subgrid-gap-decorations-fragmentation-004.html](https://wpt.fyi/results/css/css-gaps/grid/subgrid/fragmentation/subgrid-gap-decorations-fragmentation-004.html "css/css-gaps/grid/subgrid/fragmentation/subgrid-gap-decorations-fragmentation-004.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/subgrid/fragmentation/subgrid-gap-decorations-fragmentation-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/subgrid/fragmentation/subgrid-gap-decorations-fragmentation-004.html)
- [subgrid-gap-decorations-fragmentation-005.html](https://wpt.fyi/results/css/css-gaps/grid/subgrid/fragmentation/subgrid-gap-decorations-fragmentation-005.html "css/css-gaps/grid/subgrid/fragmentation/subgrid-gap-decorations-fragmentation-005.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/subgrid/fragmentation/subgrid-gap-decorations-fragmentation-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/subgrid/fragmentation/subgrid-gap-decorations-fragmentation-005.html)
- [subgrid-gap-decorations-fragmentation-006.html](https://wpt.fyi/results/css/css-gaps/grid/subgrid/fragmentation/subgrid-gap-decorations-fragmentation-006.html "css/css-gaps/grid/subgrid/fragmentation/subgrid-gap-decorations-fragmentation-006.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/subgrid/fragmentation/subgrid-gap-decorations-fragmentation-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/subgrid/fragmentation/subgrid-gap-decorations-fragmentation-006.html)
- [subgrid-gap-decorations-fragmentation-007.html](https://wpt.fyi/results/css/css-gaps/grid/subgrid/fragmentation/subgrid-gap-decorations-fragmentation-007.html "css/css-gaps/grid/subgrid/fragmentation/subgrid-gap-decorations-fragmentation-007.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/subgrid/fragmentation/subgrid-gap-decorations-fragmentation-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/subgrid/fragmentation/subgrid-gap-decorations-fragmentation-007.html)
- [subgrid-gap-decorations-fragmentation-008.html](https://wpt.fyi/results/css/css-gaps/grid/subgrid/fragmentation/subgrid-gap-decorations-fragmentation-008.html "css/css-gaps/grid/subgrid/fragmentation/subgrid-gap-decorations-fragmentation-008.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/subgrid/fragmentation/subgrid-gap-decorations-fragmentation-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/subgrid/fragmentation/subgrid-gap-decorations-fragmentation-008.html)
- [subgrid-gap-decorations-fragmentation-009.html](https://wpt.fyi/results/css/css-gaps/grid/subgrid/fragmentation/subgrid-gap-decorations-fragmentation-009.html "css/css-gaps/grid/subgrid/fragmentation/subgrid-gap-decorations-fragmentation-009.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/subgrid/fragmentation/subgrid-gap-decorations-fragmentation-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/subgrid/fragmentation/subgrid-gap-decorations-fragmentation-009.html)
- [subgrid-gap-decorations-fragmentation-010.html](https://wpt.fyi/results/css/css-gaps/grid/subgrid/fragmentation/subgrid-gap-decorations-fragmentation-010.html "css/css-gaps/grid/subgrid/fragmentation/subgrid-gap-decorations-fragmentation-010.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/subgrid/fragmentation/subgrid-gap-decorations-fragmentation-010.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/subgrid/fragmentation/subgrid-gap-decorations-fragmentation-010.html)
- [subgrid-gap-decorations-fragmentation-011.html](https://wpt.fyi/results/css/css-gaps/grid/subgrid/fragmentation/subgrid-gap-decorations-fragmentation-011.html "css/css-gaps/grid/subgrid/fragmentation/subgrid-gap-decorations-fragmentation-011.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/subgrid/fragmentation/subgrid-gap-decorations-fragmentation-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/subgrid/fragmentation/subgrid-gap-decorations-fragmentation-011.html)
- [subgrid-gap-decorations-fragmentation-012.html](https://wpt.fyi/results/css/css-gaps/grid/subgrid/fragmentation/subgrid-gap-decorations-fragmentation-012.html "css/css-gaps/grid/subgrid/fragmentation/subgrid-gap-decorations-fragmentation-012.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/subgrid/fragmentation/subgrid-gap-decorations-fragmentation-012.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/subgrid/fragmentation/subgrid-gap-decorations-fragmentation-012.html)
- [subgrid-gap-decorations-fragmentation-013.html](https://wpt.fyi/results/css/css-gaps/grid/subgrid/fragmentation/subgrid-gap-decorations-fragmentation-013.html "css/css-gaps/grid/subgrid/fragmentation/subgrid-gap-decorations-fragmentation-013.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/subgrid/fragmentation/subgrid-gap-decorations-fragmentation-013.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/subgrid/fragmentation/subgrid-gap-decorations-fragmentation-013.html)
- [subgrid-gap-decorations-fragmentation-014.html](https://wpt.fyi/results/css/css-gaps/grid/subgrid/fragmentation/subgrid-gap-decorations-fragmentation-014.html "css/css-gaps/grid/subgrid/fragmentation/subgrid-gap-decorations-fragmentation-014.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/subgrid/fragmentation/subgrid-gap-decorations-fragmentation-014.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/subgrid/fragmentation/subgrid-gap-decorations-fragmentation-014.html)
- [subgrid-gap-decorations-fragmentation-015.html](https://wpt.fyi/results/css/css-gaps/grid/subgrid/fragmentation/subgrid-gap-decorations-fragmentation-015.html "css/css-gaps/grid/subgrid/fragmentation/subgrid-gap-decorations-fragmentation-015.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/subgrid/fragmentation/subgrid-gap-decorations-fragmentation-015.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/subgrid/fragmentation/subgrid-gap-decorations-fragmentation-015.html)
- [subgrid-gap-decorations-fragmentation-016.html](https://wpt.fyi/results/css/css-gaps/grid/subgrid/fragmentation/subgrid-gap-decorations-fragmentation-016.html "css/css-gaps/grid/subgrid/fragmentation/subgrid-gap-decorations-fragmentation-016.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/subgrid/fragmentation/subgrid-gap-decorations-fragmentation-016.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/subgrid/fragmentation/subgrid-gap-decorations-fragmentation-016.html)
- [subgrid-gap-decorations-fragmentation-017.html](https://wpt.fyi/results/css/css-gaps/grid/subgrid/fragmentation/subgrid-gap-decorations-fragmentation-017.html "css/css-gaps/grid/subgrid/fragmentation/subgrid-gap-decorations-fragmentation-017.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/subgrid/fragmentation/subgrid-gap-decorations-fragmentation-017.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/subgrid/fragmentation/subgrid-gap-decorations-fragmentation-017.html)
- [subgrid-gap-decorations-fragmentation-018.html](https://wpt.fyi/results/css/css-gaps/grid/subgrid/fragmentation/subgrid-gap-decorations-fragmentation-018.html "css/css-gaps/grid/subgrid/fragmentation/subgrid-gap-decorations-fragmentation-018.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/subgrid/fragmentation/subgrid-gap-decorations-fragmentation-018.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/subgrid/fragmentation/subgrid-gap-decorations-fragmentation-018.html)
- [subgrid-gap-decorations-fragmentation-019.html](https://wpt.fyi/results/css/css-gaps/grid/subgrid/fragmentation/subgrid-gap-decorations-fragmentation-019.html "css/css-gaps/grid/subgrid/fragmentation/subgrid-gap-decorations-fragmentation-019.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/subgrid/fragmentation/subgrid-gap-decorations-fragmentation-019.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/subgrid/fragmentation/subgrid-gap-decorations-fragmentation-019.html)
- [subgrid-gap-decorations-fragmentation-020.html](https://wpt.fyi/results/css/css-gaps/grid/subgrid/fragmentation/subgrid-gap-decorations-fragmentation-020.html "css/css-gaps/grid/subgrid/fragmentation/subgrid-gap-decorations-fragmentation-020.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/subgrid/fragmentation/subgrid-gap-decorations-fragmentation-020.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/subgrid/fragmentation/subgrid-gap-decorations-fragmentation-020.html)
- [subgrid-gap-decorations-fragmentation-021.html](https://wpt.fyi/results/css/css-gaps/grid/subgrid/fragmentation/subgrid-gap-decorations-fragmentation-021.html "css/css-gaps/grid/subgrid/fragmentation/subgrid-gap-decorations-fragmentation-021.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/subgrid/fragmentation/subgrid-gap-decorations-fragmentation-021.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/subgrid/fragmentation/subgrid-gap-decorations-fragmentation-021.html)
- [subgrid-gap-decorations-fragmentation-022.html](https://wpt.fyi/results/css/css-gaps/grid/subgrid/fragmentation/subgrid-gap-decorations-fragmentation-022.html "css/css-gaps/grid/subgrid/fragmentation/subgrid-gap-decorations-fragmentation-022.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/subgrid/fragmentation/subgrid-gap-decorations-fragmentation-022.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/subgrid/fragmentation/subgrid-gap-decorations-fragmentation-022.html)

## 4. Color, style, and width

Property definitions in this section supersede the definitions of
properties with the same names in
[\[CSS-MULTICOL-1\]](#biblio-css-multicol-1 "CSS Multi-column Layout Module Level 1").

### 4.1. Gap decoration color: The [column-rule-color, [row-rule-color](#propdef-row-rule-color), and [rule-color](#propdef-rule-color) properties]
Name:

[column-rule-color], [row-rule-color]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<line-color-list\>](#typedef-line-color-list)
[\|](https://drafts.csswg.org/css-values-4/#comb-one)
[\<auto-line-color-list\>](#typedef-auto-line-color-list)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

currentcolor

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[grid
containers](https://drafts.csswg.org/css-grid-2/#grid-container), [flex
containers](https://drafts.csswg.org/css-flexbox-2/#flex-container), [multicol
containers](https://drafts.csswg.org/css-multicol-2/#multi-column-container), and [grid lanes
containers](https://drafts.csswg.org/css-grid-3/#grid-lanes-container)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

as specified

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

repeatable list, see [§ 4.7 Interpolation of list
values](#interpolation-behavior).

``` prod
<line-color-list> = <line-color-or-repeat>#

<auto-line-color-list> = <line-color-or-repeat>#? ,
 <auto-repeat-line-color> ,
 <line-color-or-repeat>#?

<line-color-or-repeat> = [ <color> | <repeat-line-color> ]

<repeat-line-color> = repeat( [ <integer [1,∞]> ] , [ <color> ]# )

<auto-repeat-line-color> = repeat( auto , [ <color> ]# )
```

These properties set the color of [gap
decorations](#gap-decoration).

Name:

[rule-color]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<\'column-rule-color\'\>](#propdef-column-rule-color)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

see individual properties

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

Same as
[column-rule-color](#propdef-column-rule-color) and
[row-rule-color](#propdef-row-rule-color)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

see individual properties

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

see individual properties

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

see individual properties

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

This [shorthand
property](https://drafts.csswg.org/css-cascade-5/#shorthand-property) sets
[column-rule-color](#propdef-column-rule-color) and
[row-rule-color](#propdef-row-rule-color) to the same value.

Tests

- [gap-decorations-003.html](https://wpt.fyi/results/css/css-gaps/agnostic/gap-decorations-003.html "css/css-gaps/agnostic/gap-decorations-003.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/agnostic/gap-decorations-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/agnostic/gap-decorations-003.html)
- [gap-decorations-004.html](https://wpt.fyi/results/css/css-gaps/agnostic/gap-decorations-004.html "css/css-gaps/agnostic/gap-decorations-004.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/agnostic/gap-decorations-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/agnostic/gap-decorations-004.html)
- [gap-decorations-010-crash.html](https://wpt.fyi/results/css/css-gaps/agnostic/gap-decorations-010-crash.html "css/css-gaps/agnostic/gap-decorations-010-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/agnostic/gap-decorations-010-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/agnostic/gap-decorations-010-crash.html)
- [flex-gap-decorations-multi-value-direction.html](https://wpt.fyi/results/css/css-gaps/flex/flex-gap-decorations-multi-value-direction.html "css/css-gaps/flex/flex-gap-decorations-multi-value-direction.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/flex/flex-gap-decorations-multi-value-direction.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/flex/flex-gap-decorations-multi-value-direction.html)
- [flex-gap-decorations-multi-value-writing-mode.html](https://wpt.fyi/results/css/css-gaps/flex/flex-gap-decorations-multi-value-writing-mode.html "css/css-gaps/flex/flex-gap-decorations-multi-value-writing-mode.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/flex/flex-gap-decorations-multi-value-writing-mode.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/flex/flex-gap-decorations-multi-value-writing-mode.html)
- [grid-gap-decorations-022.html](https://wpt.fyi/results/css/css-gaps/grid/grid-gap-decorations-022.html "css/css-gaps/grid/grid-gap-decorations-022.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/grid-gap-decorations-022.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/grid-gap-decorations-022.html)
- [grid-gap-decorations-024.html](https://wpt.fyi/results/css/css-gaps/grid/grid-gap-decorations-024.html "css/css-gaps/grid/grid-gap-decorations-024.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/grid-gap-decorations-024.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/grid-gap-decorations-024.html)
- [grid-gap-decorations-025.html](https://wpt.fyi/results/css/css-gaps/grid/grid-gap-decorations-025.html "css/css-gaps/grid/grid-gap-decorations-025.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/grid-gap-decorations-025.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/grid-gap-decorations-025.html)
- [grid-gap-decorations-026.html](https://wpt.fyi/results/css/css-gaps/grid/grid-gap-decorations-026.html "css/css-gaps/grid/grid-gap-decorations-026.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/grid-gap-decorations-026.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/grid-gap-decorations-026.html)
- [grid-gap-decorations-027.html](https://wpt.fyi/results/css/css-gaps/grid/grid-gap-decorations-027.html "css/css-gaps/grid/grid-gap-decorations-027.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/grid-gap-decorations-027.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/grid-gap-decorations-027.html)
- [grid-gap-decorations-028.html](https://wpt.fyi/results/css/css-gaps/grid/grid-gap-decorations-028.html "css/css-gaps/grid/grid-gap-decorations-028.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/grid-gap-decorations-028.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/grid-gap-decorations-028.html)
- [grid-gap-decorations-048.html](https://wpt.fyi/results/css/css-gaps/grid/grid-gap-decorations-048.html "css/css-gaps/grid/grid-gap-decorations-048.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/grid-gap-decorations-048.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/grid-gap-decorations-048.html)
- [grid-gap-decorations-049.html](https://wpt.fyi/results/css/css-gaps/grid/grid-gap-decorations-049.html "css/css-gaps/grid/grid-gap-decorations-049.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/grid-gap-decorations-049.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/grid-gap-decorations-049.html)
- [grid-gap-decorations-050.html](https://wpt.fyi/results/css/css-gaps/grid/grid-gap-decorations-050.html "css/css-gaps/grid/grid-gap-decorations-050.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/grid-gap-decorations-050.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/grid-gap-decorations-050.html)
- [grid-gap-decorations-051.html](https://wpt.fyi/results/css/css-gaps/grid/grid-gap-decorations-051.html "css/css-gaps/grid/grid-gap-decorations-051.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/grid-gap-decorations-051.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/grid-gap-decorations-051.html)
- [grid-gap-decorations-multi-value-direction.html](https://wpt.fyi/results/css/css-gaps/grid/grid-gap-decorations-multi-value-direction.html "css/css-gaps/grid/grid-gap-decorations-multi-value-direction.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/grid-gap-decorations-multi-value-direction.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/grid-gap-decorations-multi-value-direction.html)
- [grid-gap-decorations-multi-value-writing-mode.html](https://wpt.fyi/results/css/css-gaps/grid/grid-gap-decorations-multi-value-writing-mode.html "css/css-gaps/grid/grid-gap-decorations-multi-value-writing-mode.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/grid-gap-decorations-multi-value-writing-mode.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/grid-gap-decorations-multi-value-writing-mode.html)
- [grid-gap-decorations-visited-alpha-clamp.html](https://wpt.fyi/results/css/css-gaps/grid/grid-gap-decorations-visited-alpha-clamp.html "css/css-gaps/grid/grid-gap-decorations-visited-alpha-clamp.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/grid-gap-decorations-visited-alpha-clamp.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/grid-gap-decorations-visited-alpha-clamp.html)
- [multicol-gap-decorations-019.html](https://wpt.fyi/results/css/css-gaps/multicol/multicol-gap-decorations-019.html "css/css-gaps/multicol/multicol-gap-decorations-019.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/multicol/multicol-gap-decorations-019.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/multicol/multicol-gap-decorations-019.html)
- [multicol-gap-decorations-multi-value-direction.html](https://wpt.fyi/results/css/css-gaps/multicol/multicol-gap-decorations-multi-value-direction.html "css/css-gaps/multicol/multicol-gap-decorations-multi-value-direction.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/multicol/multicol-gap-decorations-multi-value-direction.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/multicol/multicol-gap-decorations-multi-value-direction.html)
- [multicol-gap-decorations-multi-value-writing-mode.html](https://wpt.fyi/results/css/css-gaps/multicol/multicol-gap-decorations-multi-value-writing-mode.html "css/css-gaps/multicol/multicol-gap-decorations-multi-value-writing-mode.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/multicol/multicol-gap-decorations-multi-value-writing-mode.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/multicol/multicol-gap-decorations-multi-value-writing-mode.html)
- [gap-decorations-color-computed.html](https://wpt.fyi/results/css/css-gaps/parsing/gap-decorations-color-computed.html "css/css-gaps/parsing/gap-decorations-color-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/parsing/gap-decorations-color-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/parsing/gap-decorations-color-computed.html)
- [gap-decorations-color-invalid.html](https://wpt.fyi/results/css/css-gaps/parsing/gap-decorations-color-invalid.html "css/css-gaps/parsing/gap-decorations-color-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/parsing/gap-decorations-color-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/parsing/gap-decorations-color-invalid.html)
- [gap-decorations-color-valid.html](https://wpt.fyi/results/css/css-gaps/parsing/gap-decorations-color-valid.html "css/css-gaps/parsing/gap-decorations-color-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/parsing/gap-decorations-color-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/parsing/gap-decorations-color-valid.html)

### 4.2. Gap decoration style: The [column-rule-style, [row-rule-style](#propdef-row-rule-style), and [rule-style](#propdef-rule-style) properties]
Name:

[column-rule-style], [row-rule-style]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<line-style-list\>](#typedef-line-style-list)
[\|](https://drafts.csswg.org/css-values-4/#comb-one)
[\<auto-line-style-list\>](#typedef-auto-line-style-list)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

none

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[grid
containers](https://drafts.csswg.org/css-grid-2/#grid-container), [flex
containers](https://drafts.csswg.org/css-flexbox-2/#flex-container), [multicol
containers](https://drafts.csswg.org/css-multicol-2/#multi-column-container), and [grid lanes
containers](https://drafts.csswg.org/css-grid-3/#grid-lanes-container)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

as specified

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

``` prod
<line-style-list> = <line-style-or-repeat>#

<auto-line-style-list> = <line-style-or-repeat>#? ,
 <auto-repeat-line-style> ,
 <line-style-or-repeat>#?

<line-style-or-repeat> = [ <line-style> | <repeat-line-style> ]

<repeat-line-style> = repeat( [ <integer [1,∞]> ] , [ <line-style> ]# )

<auto-repeat-line-style> = repeat( auto , [ <line-style> ]# )
```

These properties set the styles of [gap
decorations](#gap-decoration). The
[\<line-style\>](https://drafts.csswg.org/css-backgrounds-3/#typedef-line-style) values apply the same as for
[border-style](https://drafts.csswg.org/css-backgrounds-3/#propdef-border-style).

Name:

[rule-style]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<\'column-rule-style\'\>](#propdef-column-rule-style)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

see individual properties

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

Same as
[column-rule-style](#propdef-column-rule-style) and
[row-rule-style](#propdef-row-rule-style)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

see individual properties

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

see individual properties

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

see individual properties

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

This [shorthand
property](https://drafts.csswg.org/css-cascade-5/#shorthand-property) sets
[column-rule-style](#propdef-column-rule-style) and
[row-rule-style](#propdef-row-rule-style) to the same value.

Tests

- [flex-gap-decorations-002.html](https://wpt.fyi/results/css/css-gaps/flex/flex-gap-decorations-002.html "css/css-gaps/flex/flex-gap-decorations-002.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/flex/flex-gap-decorations-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/flex/flex-gap-decorations-002.html)
- [flex-gap-decorations-003.html](https://wpt.fyi/results/css/css-gaps/flex/flex-gap-decorations-003.html "css/css-gaps/flex/flex-gap-decorations-003.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/flex/flex-gap-decorations-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/flex/flex-gap-decorations-003.html)
- [flex-gap-decorations-004.html](https://wpt.fyi/results/css/css-gaps/flex/flex-gap-decorations-004.html "css/css-gaps/flex/flex-gap-decorations-004.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/flex/flex-gap-decorations-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/flex/flex-gap-decorations-004.html)
- [flex-gap-decorations-005.html](https://wpt.fyi/results/css/css-gaps/flex/flex-gap-decorations-005.html "css/css-gaps/flex/flex-gap-decorations-005.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/flex/flex-gap-decorations-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/flex/flex-gap-decorations-005.html)
- [flex-gap-decorations-017.html](https://wpt.fyi/results/css/css-gaps/flex/flex-gap-decorations-017.html "css/css-gaps/flex/flex-gap-decorations-017.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/flex/flex-gap-decorations-017.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/flex/flex-gap-decorations-017.html)
- [flex-gap-decorations-018.html](https://wpt.fyi/results/css/css-gaps/flex/flex-gap-decorations-018.html "css/css-gaps/flex/flex-gap-decorations-018.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/flex/flex-gap-decorations-018.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/flex/flex-gap-decorations-018.html)
- [grid-gap-decorations-002.html](https://wpt.fyi/results/css/css-gaps/grid/grid-gap-decorations-002.html "css/css-gaps/grid/grid-gap-decorations-002.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/grid-gap-decorations-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/grid-gap-decorations-002.html)
- [grid-gap-decorations-003.html](https://wpt.fyi/results/css/css-gaps/grid/grid-gap-decorations-003.html "css/css-gaps/grid/grid-gap-decorations-003.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/grid-gap-decorations-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/grid-gap-decorations-003.html)
- [grid-gap-decorations-004.html](https://wpt.fyi/results/css/css-gaps/grid/grid-gap-decorations-004.html "css/css-gaps/grid/grid-gap-decorations-004.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/grid-gap-decorations-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/grid-gap-decorations-004.html)
- [grid-gap-decorations-005.html](https://wpt.fyi/results/css/css-gaps/grid/grid-gap-decorations-005.html "css/css-gaps/grid/grid-gap-decorations-005.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/grid-gap-decorations-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/grid-gap-decorations-005.html)
- [grid-gap-decorations-016.html](https://wpt.fyi/results/css/css-gaps/grid/grid-gap-decorations-016.html "css/css-gaps/grid/grid-gap-decorations-016.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/grid-gap-decorations-016.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/grid-gap-decorations-016.html)
- [grid-gap-decorations-017.html](https://wpt.fyi/results/css/css-gaps/grid/grid-gap-decorations-017.html "css/css-gaps/grid/grid-gap-decorations-017.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/grid-gap-decorations-017.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/grid-gap-decorations-017.html)
- [grid-gap-decorations-020.html](https://wpt.fyi/results/css/css-gaps/grid/grid-gap-decorations-020.html "css/css-gaps/grid/grid-gap-decorations-020.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/grid-gap-decorations-020.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/grid-gap-decorations-020.html)
- [grid-gap-decorations-021.html](https://wpt.fyi/results/css/css-gaps/grid/grid-gap-decorations-021.html "css/css-gaps/grid/grid-gap-decorations-021.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/grid-gap-decorations-021.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/grid-gap-decorations-021.html)
- [grid-gap-decorations-039.html](https://wpt.fyi/results/css/css-gaps/grid/grid-gap-decorations-039.html "css/css-gaps/grid/grid-gap-decorations-039.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/grid-gap-decorations-039.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/grid-gap-decorations-039.html)
- [gap-decorations-style-computed.html](https://wpt.fyi/results/css/css-gaps/parsing/gap-decorations-style-computed.html "css/css-gaps/parsing/gap-decorations-style-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/parsing/gap-decorations-style-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/parsing/gap-decorations-style-computed.html)
- [gap-decorations-style-invalid.html](https://wpt.fyi/results/css/css-gaps/parsing/gap-decorations-style-invalid.html "css/css-gaps/parsing/gap-decorations-style-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/parsing/gap-decorations-style-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/parsing/gap-decorations-style-invalid.html)
- [gap-decorations-style-valid.html](https://wpt.fyi/results/css/css-gaps/parsing/gap-decorations-style-valid.html "css/css-gaps/parsing/gap-decorations-style-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/parsing/gap-decorations-style-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/parsing/gap-decorations-style-valid.html)

### 4.3. Gap decoration width: The [column-rule-width, [row-rule-width](#propdef-row-rule-width), and [rule-width](#propdef-rule-width) properties]
Name:

[column-rule-width], [row-rule-width]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<line-width-list\>](#typedef-line-width-list)
[\|](https://drafts.csswg.org/css-values-4/#comb-one)
[\<auto-line-width-list\>](#typedef-auto-line-width-list)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

medium

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[grid
containers](https://drafts.csswg.org/css-grid-2/#grid-container), [flex
containers](https://drafts.csswg.org/css-flexbox-2/#flex-container), [multicol
containers](https://drafts.csswg.org/css-multicol-2/#multi-column-container), and [grid lanes
containers](https://drafts.csswg.org/css-grid-3/#grid-lanes-container)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

list of absolute lengths, [snapped as a border
width](https://drafts.csswg.org/css-values-4/#snap-as-a-line-width)

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

repeatable list, see [§ 4.7 Interpolation of list
values](#interpolation-behavior).

``` prod
<line-width-list> = <line-width-or-repeat>#

<auto-line-width-list> = <line-width-or-repeat>#? ,
 <auto-repeat-line-width> ,
 <line-width-or-repeat>#?

<line-width-or-repeat> = [ <line-width> | <repeat-line-width> ]

<repeat-line-width> = repeat( [ <integer [1,∞]> ] , [ <line-width> ]# )

<auto-repeat-line-width> = repeat( auto , [ <line-width> ]# )
```

These properties set the widths of [gap
decorations](#gap-decoration). Negative values are not allowed.

Name:

[rule-width]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<\'column-rule-width\'\>](#propdef-column-rule-width)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

see individual properties

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

Same as
[column-rule-width](#propdef-column-rule-width) and
[row-rule-width](#propdef-row-rule-width)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

see individual properties

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

see individual properties

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

see individual properties

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

This [shorthand
property](https://drafts.csswg.org/css-cascade-5/#shorthand-property) sets
[column-rule-width](#propdef-column-rule-width) and
[row-rule-width](#propdef-row-rule-width) to the same value.

Tests

- [gap-decorations-009-crash.html](https://wpt.fyi/results/css/css-gaps/agnostic/gap-decorations-009-crash.html "css/css-gaps/agnostic/gap-decorations-009-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/agnostic/gap-decorations-009-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/agnostic/gap-decorations-009-crash.html)
- [grid-gap-decorations-018.html](https://wpt.fyi/results/css/css-gaps/grid/grid-gap-decorations-018.html "css/css-gaps/grid/grid-gap-decorations-018.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/grid-gap-decorations-018.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/grid-gap-decorations-018.html)
- [grid-gap-decorations-019.html](https://wpt.fyi/results/css/css-gaps/grid/grid-gap-decorations-019.html "css/css-gaps/grid/grid-gap-decorations-019.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/grid-gap-decorations-019.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/grid-gap-decorations-019.html)
- [multicol-gap-decorations-004.html](https://wpt.fyi/results/css/css-gaps/multicol/multicol-gap-decorations-004.html "css/css-gaps/multicol/multicol-gap-decorations-004.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/multicol/multicol-gap-decorations-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/multicol/multicol-gap-decorations-004.html)
- [gap-decorations-col-rule-width.html](https://wpt.fyi/results/css/css-gaps/parsing/gap-decorations-col-rule-width.html "css/css-gaps/parsing/gap-decorations-col-rule-width.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/parsing/gap-decorations-col-rule-width.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/parsing/gap-decorations-col-rule-width.html)
- [gap-decorations-width-computed.html](https://wpt.fyi/results/css/css-gaps/parsing/gap-decorations-width-computed.html "css/css-gaps/parsing/gap-decorations-width-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/parsing/gap-decorations-width-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/parsing/gap-decorations-width-computed.html)
- [gap-decorations-width-invalid.html](https://wpt.fyi/results/css/css-gaps/parsing/gap-decorations-width-invalid.html "css/css-gaps/parsing/gap-decorations-width-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/parsing/gap-decorations-width-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/parsing/gap-decorations-width-invalid.html)
- [gap-decorations-width-valid.html](https://wpt.fyi/results/css/css-gaps/parsing/gap-decorations-width-valid.html "css/css-gaps/parsing/gap-decorations-width-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/parsing/gap-decorations-width-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/parsing/gap-decorations-width-valid.html)

### 4.4. Gap decoration shorthands: The [column-rule, [row-rule](#propdef-row-rule), and [rule](#propdef-rule) properties]
Name:

[column-rule], [row-rule]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<gap-rule-list\>](#typedef-gap-rule-list)
[\|](https://drafts.csswg.org/css-values-4/#comb-one)
[\<gap-auto-rule-list\>](#typedef-gap-auto-rule-list)

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

``` prod
<gap-rule-list> = <gap-rule-or-repeat>#

<gap-auto-rule-list> = <gap-rule-or-repeat>#? ,
 <gap-auto-repeat-rule> ,
 <gap-rule-or-repeat>#?

<gap-rule-or-repeat> = <gap-rule> | <gap-repeat-rule>

<gap-repeat-rule> = repeat( <integer [1,∞]> , <gap-rule># )

<gap-auto-repeat-rule> = repeat( auto , <gap-rule># )

<gap-rule> = <line-width> || <line-style> || <color>
```

These [shorthand
properties](https://drafts.csswg.org/css-cascade-5/#shorthand-property) set values for the
[column-rule-width](#propdef-column-rule-width),
[column-rule-style](#propdef-column-rule-style), and
[column-rule-color](#propdef-column-rule-color) properties, or the
[row-rule-width](#propdef-row-rule-width),
[row-rule-style](#propdef-row-rule-style), and
[row-rule-color](#propdef-row-rule-color) properties, respectively.

Name:

[rule]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<\'column-rule\'\>](#propdef-column-rule)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

see individual properties

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

Same as
[column-rule](#propdef-column-rule) and
[row-rule](#propdef-row-rule)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

see individual properties

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

see individual properties

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

see individual properties

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

This [shorthand
property](https://drafts.csswg.org/css-cascade-5/#shorthand-property) sets
[column-rule](#propdef-column-rule) and
[row-rule](#propdef-row-rule) to the same values.

Tests

- [flex-gap-decorations-019.html](https://wpt.fyi/results/css/css-gaps/flex/flex-gap-decorations-019.html "css/css-gaps/flex/flex-gap-decorations-019.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/flex/flex-gap-decorations-019.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/flex/flex-gap-decorations-019.html)
- [gap-decorations-bidirectional-shorthands.html](https://wpt.fyi/results/css/css-gaps/parsing/gap-decorations-bidirectional-shorthands.html "css/css-gaps/parsing/gap-decorations-bidirectional-shorthands.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/parsing/gap-decorations-bidirectional-shorthands.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/parsing/gap-decorations-bidirectional-shorthands.html)
- [gap-decorations-rule-initial-value-crash.html](https://wpt.fyi/results/css/css-gaps/parsing/gap-decorations-rule-initial-value-crash.html "css/css-gaps/parsing/gap-decorations-rule-initial-value-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/parsing/gap-decorations-rule-initial-value-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/parsing/gap-decorations-rule-initial-value-crash.html)
- [gap-decorations-rule-shorthand-computed.html](https://wpt.fyi/results/css/css-gaps/parsing/gap-decorations-rule-shorthand-computed.html "css/css-gaps/parsing/gap-decorations-rule-shorthand-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/parsing/gap-decorations-rule-shorthand-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/parsing/gap-decorations-rule-shorthand-computed.html)
- [gap-decorations-rule-shorthand-invalid.html](https://wpt.fyi/results/css/css-gaps/parsing/gap-decorations-rule-shorthand-invalid.html "css/css-gaps/parsing/gap-decorations-rule-shorthand-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/parsing/gap-decorations-rule-shorthand-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/parsing/gap-decorations-rule-shorthand-invalid.html)
- [gap-decorations-rule-shorthand-valid.html](https://wpt.fyi/results/css/css-gaps/parsing/gap-decorations-rule-shorthand-valid.html "css/css-gaps/parsing/gap-decorations-rule-shorthand-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/parsing/gap-decorations-rule-shorthand-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/parsing/gap-decorations-rule-shorthand-valid.html)
- [gap-decorations-rule-shorthand.html](https://wpt.fyi/results/css/css-gaps/parsing/gap-decorations-rule-shorthand.html "css/css-gaps/parsing/gap-decorations-rule-shorthand.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/parsing/gap-decorations-rule-shorthand.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/parsing/gap-decorations-rule-shorthand.html)

### 4.5. Lists of values and the [repeat() notation]
Each of the properties in this section accepts a comma-separated list of
values. Setting multiple values in this way allows for varying [gap
decorations](#gap-decoration)
within a given container.

An author might specify alternating
red and blue column rules as follows:

 column-rule-width: 1px;
 column-rule-style: solid;
 column-rule-color: red, blue;

Such a list may contain [repeat()] notations. Similar to [CSS Grid Layout 1
§ 7.2.3 Repeating Rows and Columns: the repeat()
notation](https://drafts.csswg.org/css-grid-1/#repeat-notation), these
notations allow a series of [gap
decorations](#gap-decoration)
that exhibit a recurring pattern to be written in a more compact form.

The generic form of the
[repeat()](#funcdef-repeat-line-color-repeat) syntax is, approximately,

``` prod
repeat( [ <integer [1,∞]> | auto ] , <value># )
```

The first argument to
[repeat()](#funcdef-repeat-line-color-repeat) specifies the number of repetitions.

[\<integer\>](https://drafts.csswg.org/css-values-4/#integer-value)
: Specifies an [integer repeater]. An [integer
 repeater](#integer-repeater) expands out to the list of values in the second
 argument, repeated as many times as specified by the first argument.
 :::
 (#example-b40c902d) An author may write:
 column-rule-color: gray, red, blue, red, blue, red, blue, gray;

 Or shorten to the following, which produces the same sequence of
 colors:
 column-rule-color: gray, repeat(3, red, blue), gray;
 :::

[auto]
: Specifies an [auto repeater]. An [auto
 repeater](#auto-repeater)
 will be used to fill in values for gaps that would not otherwise
 receive values from other parts of the list. At most one
 [repeat()](#funcdef-repeat-line-color-repeat) in a given list of values may be an [auto
 repeater].
 :::
 (#example-de4d6aa9) Continuing from the previous
 example, if the author does not know how many columns will be in the
 final layout, they might instead write:
 column-rule-color: gray, repeat(auto, red, blue), gray;

 Which will produce a gray decoration in the first and last column
 gaps, and alternating red and blue decorations in the in-between
 column gaps.
 :::

The second argument to
[repeat()](#funcdef-repeat-line-color-repeat) is a comma-separated list of values that would
be accepted by the property in which the
[repeat()] appears.

### 4.6. Assigning gap decoration values to gaps

Gap decorations are
[assigned](#assign-gap-decoration-values) after [gutter
collapsing](https://drafts.csswg.org/css-grid-2/#collapsed-gutter) has been applied. A given set of [collapsed
gutters] consume exactly one [gap
decoration](#gap-decoration);
the next [gap decoration] is applied to the
next gutter (or set of [collapsed gutters]).
Therefore, [collapsed gutters] are treated
as a single [gap](#gap) for decoration
purposes.

A gap that is suppressed due to [fragmentation](#fragmentation) still
consumes a gap decoration value from the pattern, even though no
decoration is drawn there. This preserves a consistent association
between gaps and decorations across fragmented and unfragmented
contexts.

Similarly, when a [flex
container](https://drafts.csswg.org/css-flexbox-2/#flex-container) wraps into multiple flex lines, the decoration pattern
is assigned to gaps sequentially across the flexbox and does not restart
at the beginning of each flex line.

In [flex
containers](https://drafts.csswg.org/css-flexbox-2/#flex-container), [grid
containers](https://drafts.csswg.org/css-grid-2/#grid-container), and [grid lanes
containers](https://drafts.csswg.org/css-grid-3/#grid-lanes-container), values are assigned starting at the side where
placement begins and proceeding in the placement direction. Placement
reversals, such as
[row-reverse](https://drafts.csswg.org/css-flexbox-2/#valdef-flex-direction-row-reverse),
[column-reverse](https://drafts.csswg.org/css-flexbox-2/#valdef-flex-direction-column-reverse), or
[wrap-reverse](https://drafts.csswg.org/css-flexbox-2/#valdef-flex-wrap-wrap-reverse), can make this differ from the [writing
mode](https://drafts.csswg.org/css-writing-modes-4/#writing-mode) direction.

In the [stacking
axis](https://drafts.csswg.org/css-grid-3/#stacking-axis) of a [grid lanes
container](https://drafts.csswg.org/css-grid-3/#grid-lanes-container), values are assigned independently in each [grid
track](https://drafts.csswg.org/css-grid-2/#grid-track), restarting the value list and expanding
[repeat()](#funcdef-repeat-line-color-repeat) for that track. [Gaps](#gap) before a spanning item take values from their
respective track sequences and can therefore differ.

To [assign gap decoration values] to a list of `gaps`
using a list of `values`:

1. Replace any [integer
 repeaters](#integer-repeater) in `values` with their expanded-out
 equivalents.
2. If the list contains no [auto
 repeater](#auto-repeater),
 then:
 1. Beginning from the first item in `values` and the
 first item in `gaps`, assign each value to the
 corresponding gap. If there are fewer values than gaps, repeat
 beginning from the first item in `values`, as many
 times as needed.
 2. End this algorithm.
3. `values` contains an [auto
 repeater](#auto-repeater).
 Let `leading count` be the number of items in
 `values` before the [auto
 repeater]. Let `trailing count`
 be the number of items in `values` after the [auto
 repeater].
4. Partition `gaps` as follows:
 1. Let `leading gaps` contain the first
 `leading count` items in `gaps`.
 2. Let `trailing gaps` contain the last
 `trailing count` items in `gaps`,
 excluding any items in `leading gaps`.
 3. Let `auto gaps` contain any items in
 `gaps` that are not in either
 `leading gaps` or `trailing gaps`.
5. If `leading gaps` is non-empty, [assign gap decoration
 values](#assign-gap-decoration-values) to `leading gaps` using the first
 `leading count` items in `values`.
6. If `trailing gaps` is non-empty, [assign gap decoration
 values](#assign-gap-decoration-values) to `trailing gaps` using the first
 `trailing count` items in `values`.
7. If `auto gaps` is non-empty, [assign gap decoration
 values](#assign-gap-decoration-values) to `auto gaps` using the list of values
 in the second argument of the [auto
 repeater](#auto-repeater).

![Assignment of a three-value
[row-rule-color](#propdef-row-rule-color) list in a [grid lanes
container](https://drafts.csswg.org/css-grid-3/#grid-lanes-container). Note that each track restarts the list, so the two
[gaps](#gap) before spanning item 6 get
different values.](images/grid-lanes-list-assignment.png){height="402"
width="466"}

- [gap-decorations-011-crash.html](https://wpt.fyi/results/css/css-gaps/agnostic/gap-decorations-011-crash.html "css/css-gaps/agnostic/gap-decorations-011-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/agnostic/gap-decorations-011-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/agnostic/gap-decorations-011-crash.html)
- [grid-gap-decorations-058-crash.html](https://wpt.fyi/results/css/css-gaps/grid/grid-gap-decorations-058-crash.html "css/css-gaps/grid/grid-gap-decorations-058-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/grid-gap-decorations-058-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/grid-gap-decorations-058-crash.html)
- [grid-gap-decorations-059-crash.html](https://wpt.fyi/results/css/css-gaps/grid/grid-gap-decorations-059-crash.html "css/css-gaps/grid/grid-gap-decorations-059-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/grid-gap-decorations-059-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/grid-gap-decorations-059-crash.html)
- [grid-gap-decorations-060-crash.html](https://wpt.fyi/results/css/css-gaps/grid/grid-gap-decorations-060-crash.html "css/css-gaps/grid/grid-gap-decorations-060-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/grid-gap-decorations-060-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/grid-gap-decorations-060-crash.html)
- [grid-gap-decorations-061.html](https://wpt.fyi/results/css/css-gaps/grid/grid-gap-decorations-061.html "css/css-gaps/grid/grid-gap-decorations-061.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/grid-gap-decorations-061.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/grid-gap-decorations-061.html)
- [grid-gap-decorations-062.html](https://wpt.fyi/results/css/css-gaps/grid/grid-gap-decorations-062.html "css/css-gaps/grid/grid-gap-decorations-062.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/grid-gap-decorations-062.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/grid-gap-decorations-062.html)
- [grid-gap-decorations-063.html](https://wpt.fyi/results/css/css-gaps/grid/grid-gap-decorations-063.html "css/css-gaps/grid/grid-gap-decorations-063.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/grid-gap-decorations-063.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/grid-gap-decorations-063.html)
- [grid-gap-decorations-collapsed-all-auto-fit.html](https://wpt.fyi/results/css/css-gaps/grid/grid-gap-decorations-collapsed-all-auto-fit.html "css/css-gaps/grid/grid-gap-decorations-collapsed-all-auto-fit.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/grid-gap-decorations-collapsed-all-auto-fit.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/grid-gap-decorations-collapsed-all-auto-fit.html)
- [grid-gap-decorations-collapsed-leading-auto-fit.html](https://wpt.fyi/results/css/css-gaps/grid/grid-gap-decorations-collapsed-leading-auto-fit.html "css/css-gaps/grid/grid-gap-decorations-collapsed-leading-auto-fit.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/grid-gap-decorations-collapsed-leading-auto-fit.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/grid-gap-decorations-collapsed-leading-auto-fit.html)
- [grid-gap-decorations-collapsed-leading-spanner.html](https://wpt.fyi/results/css/css-gaps/grid/grid-gap-decorations-collapsed-leading-spanner.html "css/css-gaps/grid/grid-gap-decorations-collapsed-leading-spanner.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/grid-gap-decorations-collapsed-leading-spanner.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/grid-gap-decorations-collapsed-leading-spanner.html)
- [grid-gap-decorations-collapsed-middle-auto-fit.html](https://wpt.fyi/results/css/css-gaps/grid/grid-gap-decorations-collapsed-middle-auto-fit.html "css/css-gaps/grid/grid-gap-decorations-collapsed-middle-auto-fit.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/grid-gap-decorations-collapsed-middle-auto-fit.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/grid-gap-decorations-collapsed-middle-auto-fit.html)
- [grid-gap-decorations-collapsed-middle-spanner.html](https://wpt.fyi/results/css/css-gaps/grid/grid-gap-decorations-collapsed-middle-spanner.html "css/css-gaps/grid/grid-gap-decorations-collapsed-middle-spanner.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/grid-gap-decorations-collapsed-middle-spanner.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/grid-gap-decorations-collapsed-middle-spanner.html)
- [grid-gap-decorations-collapsed-trailing-auto-fit.html](https://wpt.fyi/results/css/css-gaps/grid/grid-gap-decorations-collapsed-trailing-auto-fit.html "css/css-gaps/grid/grid-gap-decorations-collapsed-trailing-auto-fit.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/grid-gap-decorations-collapsed-trailing-auto-fit.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/grid-gap-decorations-collapsed-trailing-auto-fit.html)
- [grid-gap-decorations-collapsed-trailing-spanner.html](https://wpt.fyi/results/css/css-gaps/grid/grid-gap-decorations-collapsed-trailing-spanner.html "css/css-gaps/grid/grid-gap-decorations-collapsed-trailing-spanner.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/grid/grid-gap-decorations-collapsed-trailing-spanner.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/grid/grid-gap-decorations-collapsed-trailing-spanner.html)

### 4.7. Interpolation of list values

When interpolating
[repeat()](#funcdef-repeat-line-color-repeat) values, or lists of values for
[rule-color](#propdef-rule-color) or
[rule-width](#propdef-rule-width), the interpolation proceeds in two
steps:

1. *Expansion:* Expand any [integer
 repeater](#integer-repeater) into its equivalent list of values.
2. *List Interpolation:* Apply the [repeatable
 list](https://drafts.csswg.org/web-animations-1/#repeatable-list) interpolation algorithm to the expanded lists,
 interpolating each item against its counterpart.

```
@keyframes example {
 from { column-rule-width: 10px; }
 to { column-rule-width: 20px, 40px; }
}
```

Interpolation of the above values would result in expansion of the
\"from\" and \"to\" values to create lists of equal lengths:

 From: 10px, 10px
 At 50%: 15px, 25px
 To: 20px, 40px

```
@keyframes example {
 from { column-rule-width: repeat(2, 5px, 10px); }
 to { column-rule-width: repeat(2, 15px, 20px); }
}
```

Interpolation of the above values would result in expansion of the
\"from\" and \"to\" values to create lists of equal lengths:

 From: 5px, 10px, 5px, 10px
 At 50%: 10px, 15px, 10px, 15px
 To: 15px, 20px, 15px, 20px

```
@keyframes example {
 from { column-rule-width: repeat(2, 10px, 20px); }
 to { column-rule-width: 20px; }
}
```

Interpolation of the above values would result in expansion of the
\"from\" and \"to\" values to create lists of equal lengths:

 From: 10px, 20px, 10px, 20px
 At 50%: 15px, 20px, 15px, 20px
 To: 20px, 20px, 20px, 20px

```
@keyframes example {
 from { column-rule-width: repeat(2, 10px, 20px); }
 to { column-rule-width: 20px, 30px; }
}
```

Interpolation of the above values would result in expansion of the
\"from\" and \"to\" values to create lists of equal lengths:

 From: 10px, 20px, 10px, 20px
 At 50%: 15px, 25px, 15px, 25px
 To: 20px, 30px, 20px, 30px

When either of the lists we are interpolating between (`from`
and `to`) include an [auto
repeater](#auto-repeater):

1. Split each of `from` and `to` into segments,
 similar to how we [assign gap decoration
 values](#assign-gap-decoration-values):
 1. Let `leading values` be the values before the [auto
 repeater](#auto-repeater).
 2. Let `trailing values` be the values after the [auto
 repeater](#auto-repeater).
 3. Let `auto values` be the values inside the [auto
 repeater](#auto-repeater).
2. If only one of `from` or `to` contains an
 auto-repeater, we fall back to
 [discrete](https://drafts.csswg.org/web-animations-1/#discrete) interpolation.
3. Expand any integer repeaters on each segment.
4. If the length of `leading values` in `from`
 and `leading values` in `to` don't match, we
 fall back to
 [discrete](https://drafts.csswg.org/web-animations-1/#discrete) interpolation. If the length of
 `trailing values` in `from` and
 `trailing values` in `to` don't match, we fall
 back to [discrete] interpolation.
5. When both `from` and `to` contain
 auto-repeaters, and the length of their segments match as described
 above, apply [repeatable
 list](https://drafts.csswg.org/web-animations-1/#repeatable-list) interpolation to the lists of values in each
 `auto values`.

```
@keyframes example {
 from { column-rule-width: 10px, repeat(auto, 20px), 30px }
 to { column-rule-width: 20px, repeat(auto, 40px), 40px }
}
```

Length of the `leading values` and
`trailing values` across `from` and
`to` match, so we can apply the [repeatable
list](https://drafts.csswg.org/web-animations-1/#repeatable-list) algorithm to each segment.

 From: 10px, repeat(auto, 20px), 30px
 At 50%: 15px, repeat(auto, 30px), 35px
 To: 20px, repeat(auto, 40px), 40px

```
@keyframes example {
 from { column-rule-width: 10px, 20px, repeat(auto, 20px), 30px }
 to { column-rule-width: 20px, 30px, repeat(auto, 40px, 50px), 40px }
}
```

Length of the `leading values` and
`trailing values` across `from` and
`to` match, so we can apply the [repeatable
list](https://drafts.csswg.org/web-animations-1/#repeatable-list) algorithm to each segment.

 From: 10px, 20px, repeat(auto, 20px, 20px), 30px
 At 50%: 15px, 25px, repeat(auto, 30px, 35px), 35px
 To: 20px, 30px, repeat(auto, 40px, 50px), 40px

```
@keyframes example {
 from { column-rule-width: 10px, repeat(auto, 20px) }
 to { column-rule-width: 20px, 30px, repeat(auto, 40px, 50px) }
}
```

Length of the `from` `leading values` and
`to` `leading values` don't match, so we fall back
to
[discrete](https://drafts.csswg.org/web-animations-1/#discrete) interpolation.

```
@keyframes example {
 from { column-rule-width: 10px, repeat(auto, 20px), 30px }
 to { column-rule-width: 20px, repeat(auto, 40px), 40px, 50px }
}
```

Length of the `from` `trailing values` and
`to` `trailing values` don't match, so we fall
back to
[discrete](https://drafts.csswg.org/web-animations-1/#discrete) interpolation.

```
@keyframes example {
 from { column-rule-width: 10px, repeat(auto, 20px), 30px }
 to { column-rule-width: 20px }
}
```

Only `from` contains an [auto
repeater](#auto-repeater), so
we fall back to
[discrete](https://drafts.csswg.org/web-animations-1/#discrete) interpolation.

- [column-rule-inset-interpolation.html](https://wpt.fyi/results/css/css-gaps/animation/column-rule-inset-interpolation.html "css/css-gaps/animation/column-rule-inset-interpolation.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/animation/column-rule-inset-interpolation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/animation/column-rule-inset-interpolation.html)
- [gap-decorations-color-neutral-keyframe-001.html](https://wpt.fyi/results/css/css-gaps/animation/gap-decorations-color-neutral-keyframe-001.html "css/css-gaps/animation/gap-decorations-color-neutral-keyframe-001.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/animation/gap-decorations-color-neutral-keyframe-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/animation/gap-decorations-color-neutral-keyframe-001.html)
- [gap-decorations-color-neutral-keyframe-002.html](https://wpt.fyi/results/css/css-gaps/animation/gap-decorations-color-neutral-keyframe-002.html "css/css-gaps/animation/gap-decorations-color-neutral-keyframe-002.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/animation/gap-decorations-color-neutral-keyframe-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/animation/gap-decorations-color-neutral-keyframe-002.html)
- [gap-decorations-color-neutral-keyframe-003.html](https://wpt.fyi/results/css/css-gaps/animation/gap-decorations-color-neutral-keyframe-003.html "css/css-gaps/animation/gap-decorations-color-neutral-keyframe-003.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/animation/gap-decorations-color-neutral-keyframe-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/animation/gap-decorations-color-neutral-keyframe-003.html)
- [gap-decorations-color-neutral-keyframe-004.html](https://wpt.fyi/results/css/css-gaps/animation/gap-decorations-color-neutral-keyframe-004.html "css/css-gaps/animation/gap-decorations-color-neutral-keyframe-004.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/animation/gap-decorations-color-neutral-keyframe-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/animation/gap-decorations-color-neutral-keyframe-004.html)
- [gap-decorations-color-neutral-keyframe-005.html](https://wpt.fyi/results/css/css-gaps/animation/gap-decorations-color-neutral-keyframe-005.html "css/css-gaps/animation/gap-decorations-color-neutral-keyframe-005.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/animation/gap-decorations-color-neutral-keyframe-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/animation/gap-decorations-color-neutral-keyframe-005.html)
- [gap-decorations-inset-neutral-keyframe-001.html](https://wpt.fyi/results/css/css-gaps/animation/gap-decorations-inset-neutral-keyframe-001.html "css/css-gaps/animation/gap-decorations-inset-neutral-keyframe-001.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/animation/gap-decorations-inset-neutral-keyframe-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/animation/gap-decorations-inset-neutral-keyframe-001.html)
- [gap-decorations-inset-neutral-keyframe-002.html](https://wpt.fyi/results/css/css-gaps/animation/gap-decorations-inset-neutral-keyframe-002.html "css/css-gaps/animation/gap-decorations-inset-neutral-keyframe-002.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/animation/gap-decorations-inset-neutral-keyframe-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/animation/gap-decorations-inset-neutral-keyframe-002.html)
- [gap-decorations-width-neutral-keyframe-001.html](https://wpt.fyi/results/css/css-gaps/animation/gap-decorations-width-neutral-keyframe-001.html "css/css-gaps/animation/gap-decorations-width-neutral-keyframe-001.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/animation/gap-decorations-width-neutral-keyframe-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/animation/gap-decorations-width-neutral-keyframe-001.html)
- [gap-decorations-width-neutral-keyframe-002.html](https://wpt.fyi/results/css/css-gaps/animation/gap-decorations-width-neutral-keyframe-002.html "css/css-gaps/animation/gap-decorations-width-neutral-keyframe-002.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/animation/gap-decorations-width-neutral-keyframe-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/animation/gap-decorations-width-neutral-keyframe-002.html)
- [gap-decorations-width-neutral-keyframe-003.html](https://wpt.fyi/results/css/css-gaps/animation/gap-decorations-width-neutral-keyframe-003.html "css/css-gaps/animation/gap-decorations-width-neutral-keyframe-003.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/animation/gap-decorations-width-neutral-keyframe-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/animation/gap-decorations-width-neutral-keyframe-003.html)
- [gap-decorations-width-neutral-keyframe-004.html](https://wpt.fyi/results/css/css-gaps/animation/gap-decorations-width-neutral-keyframe-004.html "css/css-gaps/animation/gap-decorations-width-neutral-keyframe-004.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/animation/gap-decorations-width-neutral-keyframe-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/animation/gap-decorations-width-neutral-keyframe-004.html)
- [gap-decorations-width-neutral-keyframe-005.html](https://wpt.fyi/results/css/css-gaps/animation/gap-decorations-width-neutral-keyframe-005.html "css/css-gaps/animation/gap-decorations-width-neutral-keyframe-005.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/animation/gap-decorations-width-neutral-keyframe-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/animation/gap-decorations-width-neutral-keyframe-005.html)
- [row-rule-color-interpolation.html](https://wpt.fyi/results/css/css-gaps/animation/row-rule-color-interpolation.html "css/css-gaps/animation/row-rule-color-interpolation.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/animation/row-rule-color-interpolation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/animation/row-rule-color-interpolation.html)
- [row-rule-inset-interpolation.html](https://wpt.fyi/results/css/css-gaps/animation/row-rule-inset-interpolation.html "css/css-gaps/animation/row-rule-inset-interpolation.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/animation/row-rule-inset-interpolation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/animation/row-rule-inset-interpolation.html)
- [row-rule-width-interpolation.html](https://wpt.fyi/results/css/css-gaps/animation/row-rule-width-interpolation.html "css/css-gaps/animation/row-rule-width-interpolation.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/animation/row-rule-width-interpolation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/animation/row-rule-width-interpolation.html)
- [rule-color-interpolation-conversion-001.html](https://wpt.fyi/results/css/css-gaps/animation/rule-color-interpolation-conversion-001.html "css/css-gaps/animation/rule-color-interpolation-conversion-001.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/animation/rule-color-interpolation-conversion-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/animation/rule-color-interpolation-conversion-001.html)
- [rule-color-interpolation-conversion-002.html](https://wpt.fyi/results/css/css-gaps/animation/rule-color-interpolation-conversion-002.html "css/css-gaps/animation/rule-color-interpolation-conversion-002.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/animation/rule-color-interpolation-conversion-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/animation/rule-color-interpolation-conversion-002.html)
- [rule-color-interpolation-conversion-crash.html](https://wpt.fyi/results/css/css-gaps/animation/rule-color-interpolation-conversion-crash.html "css/css-gaps/animation/rule-color-interpolation-conversion-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/animation/rule-color-interpolation-conversion-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/animation/rule-color-interpolation-conversion-crash.html)
- [rule-color-interpolation-multiple-values-001.html](https://wpt.fyi/results/css/css-gaps/animation/rule-color-interpolation-multiple-values-001.html "css/css-gaps/animation/rule-color-interpolation-multiple-values-001.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/animation/rule-color-interpolation-multiple-values-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/animation/rule-color-interpolation-multiple-values-001.html)
- [rule-color-interpolation-repeaters-001.html](https://wpt.fyi/results/css/css-gaps/animation/rule-color-interpolation-repeaters-001.html "css/css-gaps/animation/rule-color-interpolation-repeaters-001.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/animation/rule-color-interpolation-repeaters-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/animation/rule-color-interpolation-repeaters-001.html)
- [rule-width-interpolation-conversion-001.html](https://wpt.fyi/results/css/css-gaps/animation/rule-width-interpolation-conversion-001.html "css/css-gaps/animation/rule-width-interpolation-conversion-001.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/animation/rule-width-interpolation-conversion-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/animation/rule-width-interpolation-conversion-001.html)
- [rule-width-interpolation-conversion-002.html](https://wpt.fyi/results/css/css-gaps/animation/rule-width-interpolation-conversion-002.html "css/css-gaps/animation/rule-width-interpolation-conversion-002.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/animation/rule-width-interpolation-conversion-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/animation/rule-width-interpolation-conversion-002.html)
- [rule-width-interpolation-multiple-values-001.html](https://wpt.fyi/results/css/css-gaps/animation/rule-width-interpolation-multiple-values-001.html "css/css-gaps/animation/rule-width-interpolation-multiple-values-001.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/animation/rule-width-interpolation-multiple-values-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/animation/rule-width-interpolation-multiple-values-001.html)
- [rule-width-interpolation-multiple-values-002.html](https://wpt.fyi/results/css/css-gaps/animation/rule-width-interpolation-multiple-values-002.html "css/css-gaps/animation/rule-width-interpolation-multiple-values-002.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/animation/rule-width-interpolation-multiple-values-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/animation/rule-width-interpolation-multiple-values-002.html)
- [rule-width-interpolation-repeaters.html](https://wpt.fyi/results/css/css-gaps/animation/rule-width-interpolation-repeaters.html "css/css-gaps/animation/rule-width-interpolation-repeaters.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/animation/rule-width-interpolation-repeaters.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/animation/rule-width-interpolation-repeaters.html)

### 4.8. Serialization

The [column-rule](#propdef-column-rule),
[row-rule](#propdef-row-rule), and [rule](#propdef-rule) shorthands are serialized from
component longhand properties only if the longhand properties are
[repeater aligned](#repeater-aligned). If the longhand properties are not [repeater
aligned], the shorthand serializes as an
empty string.

Let `W`, `S` and `C` be the values for
the width, style, and color longhand properties respectively. Recall
that each is a list of items, where an item is either a single value or
a
[repeat()](#funcdef-repeat-line-color-repeat) notation. The longhand properties are [repeater
aligned]
if and only if all of the following are true:

1. `W`, `S` and `C` all have the same
 number of items.
2. For each item index `i`,
 `W`\[`i`\], `S`\[`i`\]
 and `C`\[`i`\] all have the same shape:
 1. they are either all non-repeat values, all [integer
 repeaters](#integer-repeater), or all [auto
 repeaters](#auto-repeater).
 2. If they are [integer
 repeaters](#integer-repeater), the
 [\<integer\>](https://drafts.csswg.org/css-values-4/#integer-value) values are equal.
 3. Each
 [repeat()](#funcdef-repeat-line-color-repeat) notation contains the same number of
 values.

This shorthand declaration:

 column-rule: 1px solid red, 2px dashed green, 3px dotted blue;

Breaks down to the following longhand values:

 column-rule-width: 1px, 2px, 3px;
 column-rule-style: solid, dashed, dotted;
 column-rule-color: red, green, blue;

Which serialize back to the same original shorthand value, because the
longhands are [repeater
aligned](#repeater-aligned):
all three properties have the same number of items (3), and each item is
a single value (not a repeater).

The same behavior would occur if the three longhands were specified
directly rather than coming from a shorthand.

This shorthand declaration:

 column-rule: 1px solid red, repeat(2, 2px dashed green);

Breaks down to the following longhand values:

 column-rule-width: 1px, repeat(2, 2px);
 column-rule-style: solid, repeat(2, dashed);
 column-rule-color: red, repeat(2, green);

Which serialize back to the same original shorthand value, because the
longhands are [repeater
aligned](#repeater-aligned):
all three properties have the same number of items (2), and at each
index the items have matching types (single values at index 0, integer
repeaters at index 1), the integer repeaters have the same repeat count
(2), and the integer repeaters contain the same number of values (1).

The same behavior would occur if the three longhands were specified
directly rather than coming from a shorthand.

This shorthand declaration:

 column-rule: repeat(auto, 1px solid red, 2px dashed green);

Breaks down to the following longhand values:

 column-rule-width: repeat(auto, 1px, 2px);
 column-rule-style: repeat(auto, solid, dashed);
 column-rule-color: repeat(auto, red, green);

Which serialize back to the same original shorthand value, because the
longhands are [repeater
aligned](#repeater-aligned):
all three properties have the same number of items (1), each item is an
auto repeater, and the auto repeaters contain the same number of values
(2).

The same behavior would occur if the three longhands were specified
directly rather than coming from a shorthand.

These declarations:

 column-rule: repeat(auto, 1px solid red, 2px dashed green);
 column-rule-width: repeat(auto, 3px, 4px, 5px);

Break down to the following longhand values:

 column-rule-width: repeat(auto, 3px, 4px, 5px);
 column-rule-style: repeat(auto, solid, dashed);
 column-rule-color: repeat(auto, red, green);

The [column-rule](#propdef-column-rule) shorthand will serialize as an
empty string because the longhands are not [repeater
aligned](#repeater-aligned):
the auto repeaters contain different numbers of values.

The same behavior would occur if the three longhands were specified
directly rather than coming from a shorthand.

These declarations:

 column-rule: repeat(2, 1px solid red, 2px dashed green);
 column-rule-style: dashed, dotted, solid;

Break down to the following longhand values:

 column-rule-width: repeat(2, 1px, 2px);
 column-rule-style: dashed, dotted, solid;
 column-rule-color: repeat(2, red, green);

The [column-rule](#propdef-column-rule) shorthand will serialize as an
empty string because the longhands are not [repeater
aligned](#repeater-aligned):
the items at index 0 have mismatched types (integer repeater for width
and color, single value for style).

The same behavior would occur if the three longhands were specified
directly rather than coming from a shorthand.

These declarations:

 column-rule: repeat(2, 1px solid red, 2px dashed green);
 column-rule-color: repeat(4, red, cyan);

Break down to the following longhand values:

 column-rule-width: repeat(2, 1px, 2px);
 column-rule-style: repeat(2, solid, dashed);
 column-rule-color: repeat(4, red, cyan);

The [column-rule](#propdef-column-rule) shorthand will serialize as an
empty string because the longhands are not [repeater
aligned](#repeater-aligned):
the integer repeaters have different repeat counts.

The same behavior would occur if the three longhands were specified
directly rather than coming from a shorthand.

- [gap-decorations-007-crash.html](https://wpt.fyi/results/css/css-gaps/agnostic/gap-decorations-007-crash.html "css/css-gaps/agnostic/gap-decorations-007-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/agnostic/gap-decorations-007-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/agnostic/gap-decorations-007-crash.html)
- [gap-decorations-008-crash.html](https://wpt.fyi/results/css/css-gaps/agnostic/gap-decorations-008-crash.html "css/css-gaps/agnostic/gap-decorations-008-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/agnostic/gap-decorations-008-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/agnostic/gap-decorations-008-crash.html)
- [multicol-gap-decorations-021.html](https://wpt.fyi/results/css/css-gaps/multicol/multicol-gap-decorations-021.html "css/css-gaps/multicol/multicol-gap-decorations-021.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/multicol/multicol-gap-decorations-021.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/multicol/multicol-gap-decorations-021.html)
- [gap-decorations-important.html](https://wpt.fyi/results/css/css-gaps/parsing/gap-decorations-important.html "css/css-gaps/parsing/gap-decorations-important.html")
 [[(live
 test)]](http://wpt.live/css/css-gaps/parsing/gap-decorations-important.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-gaps/parsing/gap-decorations-important.html)

## 5. Acknowledgements

Many thanks to Sam Davis Omekara Jr. and Javier Contreras Tenorio who
contributed a significant amount of normative text, examples, and WPT
coverage to this specification.

Mats Palmgren's earlier
[proposal](https://matspalmgren.github.io/css-gap-decorations/Overview.html)
for Gap Decorations helped inform the direction of this specification.

Additional feedback that helped shape this specification was contributed
by many people, including: Ahmad Shadeed, Alison Maher, Benoît Rouleau,
Elika Etemad, Ian Kilpatrick, Josh Tumath, Kurt Catti-Schmidt, Lea
Verou, Oliver Williams, Rachel Andrew, Sebastian Zartner, Tab
Atkins-Bittner, and the CSS Working Group members.

## 6. Privacy Considerations

Support for the [gap
decoration](#gap-decoration)
properties is observable through
[\@supports](https://drafts.csswg.org/css-conditional-3/#at-ruledef-supports) and can contribute, in aggregate, to browser
fingerprinting.

[Gap decoration](#gap-decoration) painting affected by
[:visited](https://drafts.csswg.org/selectors-4/#visited-pseudo) is subject to considerations for user agents to
preserve user privacy in [Selectors 4 § 8.2 The Link History
Pseudo-classes: :link and
:visited](https://drafts.csswg.org/selectors-4/#link).

## 7. Security Considerations

No new security considerations have been reported on this specification.

## 8. Changes

### [8.1. ][ Changes since the [24 June 2026 Working Draft](https://www.w3.org/TR/2026/WD-css-gaps-1-20260624/)]
- Defined the
 [normal](#valdef-column-rule-break-normal) break behavior for [gap
 decorations](#gap-decoration) in [grid lanes
 containers](https://drafts.csswg.org/css-grid-3/#grid-lanes-container). ([Issue
 14169](https://github.com/w3c/csswg-drafts/issues/14169))
- Defined the direction in which values are [assigned](#assigning) to
 [gaps](#gap), and specified that a
 [grid lanes
 container](https://drafts.csswg.org/css-grid-3/#grid-lanes-container) assigns values independently in each [grid
 track](https://drafts.csswg.org/css-grid-2/#grid-track). ([Issue
 14156](https://github.com/w3c/csswg-drafts/issues/14156))
- Defined [gaps](#gaps) for [grid lanes
 containers](https://drafts.csswg.org/css-grid-3/#grid-lanes-container) and added them to the applicability of the
 [gap](#propdef-gap),
 [row-gap](#propdef-row-gap), and
 [column-gap](#propdef-column-gap) properties. ([Issue
 14153](https://github.com/w3c/csswg-drafts/issues/14153), [Issue
 14154](https://github.com/w3c/csswg-drafts/issues/14154))
- Updated the Privacy Considerations section to call out feature
 detection and :visited link considerations.

### [8.2. ][ Changes since the [27 February 2026 Working Draft](https://www.w3.org/TR/2026/WD-css-gaps-1-20260227/)]
- Added the
 [normal](#valdef-column-rule-visibility-items-normal) value to
 [\*-rule-visibility-items](#visibility) and made it the new initial
 value. ([Issue
 13477](https://github.com/w3c/csswg-drafts/issues/13477))
- Clarified applicability of writing mode and text decoration to gap
 decorations. ([Issue
 13648](https://github.com/w3c/csswg-drafts/issues/13648), [Issue
 13649](https://github.com/w3c/csswg-drafts/issues/13649))
- Moved the [gap](#gaps) properties from
 [\[CSS-ALIGN-3\]](#biblio-css-align-3 "CSS Box Alignment Module Level 3")
 to this specification. ([Issue
 13089](https://github.com/w3c/csswg-drafts/issues/13089))
- Updated edge and interior insets to be cap and junction insets.
 ([Issue 13697](https://github.com/w3c/csswg-drafts/issues/13697))
- Clarified that gaps suppressed due to fragmentation still consume gap
 decoration values. ([Issue
 13754](https://github.com/w3c/csswg-drafts/issues/13754))
- Added the
 [overlap-join](#valdef-inset-value-overlap-join) value to the [rule-inset](#inset) properties.
 ([Issue 13137](https://github.com/w3c/csswg-drafts/issues/13137))
- Clarified that decoration patterns do not restart at the beginning of
 each flex line. ([Issue
 13663](https://github.com/w3c/csswg-drafts/issues/13663))
- Updated the Abstract and Introduction to reflect changes.
- Updated with links to additional WPTs.
- Updated the Acknowledgements section.

### [8.3. ][ Changes since the [17 April 2025 Working Draft](https://www.w3.org/TR/2025/WD-css-gaps-1-20250417/)]
- Specified the behavior when gaps are coincident due to track
 collapsing. ([Issue
 11814](https://github.com/w3c/csswg-drafts/issues/11814))
- Renamed [rule-paint-order] to
 [rule-overlap](#propdef-rule-overlap). ([Issue
 12540](https://github.com/w3c/csswg-drafts/issues/12540))
- Updated the definition for intersections to use
 [gutter](#gutter). ([Issue
 12084](https://github.com/w3c/csswg-drafts/issues/12084))
- Updated trailing gap decoration assignment to use values in forward
 order. ([Issue
 12527](https://github.com/w3c/csswg-drafts/issues/12527))
- Specified the interpolation behavior for values which may contain
 repeaters. ([Issue
 12431](https://github.com/w3c/csswg-drafts/issues/12431))
- Removed the special case of
 [column-rule-width](#propdef-column-rule-width) having a computed value of
 [0] when
 [column-rule-style](#propdef-column-rule-style) is
 [none](https://drafts.csswg.org/css-backgrounds-3/#valdef-line-style-none) or
 [hidden](https://drafts.csswg.org/css-backgrounds-3/#valdef-line-style-hidden). ([Issue
 11494](https://github.com/w3c/csswg-drafts/issues/11494))
- Changed the rule-outset properties to [rule-inset](#inset) and
 introduced related properties. ([Issue
 12603](https://github.com/w3c/csswg-drafts/issues/12603), [Issue
 12848](https://github.com/w3c/csswg-drafts/issues/12848), [Issue
 8402](https://github.com/w3c/csswg-drafts/issues/8402))
- Updated the initial value of the [inset](#inset) properties to
 [0] and removed the auto keyword. ([Issue
 13137](https://github.com/w3c/csswg-drafts/issues/13137))
- Added a paragraph clarifying that gap decorations are not drawn where
 gaps are suppressed due to fragment breaks. ([Issue
 11520](https://github.com/w3c/csswg-drafts/issues/11520))
- Updated the behavior for when gaps are coincident due to track
 collapsing. ([Issue
 11814](https://github.com/w3c/csswg-drafts/issues/11814))
- Added a section for serializing shorthands from separate longhands.
 ([Issue 12201](https://github.com/w3c/csswg-drafts/issues/12201))
- Updated the color, width, and style longhand properties to use
 comma-separated lists instead of space-separated lists. ([Issue
 12201](https://github.com/w3c/csswg-drafts/issues/12201))
- Added section for gap decorations next to empty grid areas. ([Issue
 12602](https://github.com/w3c/csswg-drafts/issues/12602))
- Clarified that alignment space contributes to gap size. ([Issue
 12922](https://github.com/w3c/csswg-drafts/issues/12922))
- Renamed the [break](#break) value [spanning-item] to
 [normal](#valdef-column-rule-break-normal). ([Issue
 13127](https://github.com/w3c/csswg-drafts/issues/13127))
- Refreshed examples to reflect changes to the specification.
- Added links to WPT suite.
- Added Acknowledgements section.
