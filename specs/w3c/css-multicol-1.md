## 1. Introduction

(This section is not normative.)

This module describes [multi-column layout] in CSS. By using functionality
described in this document, style sheets can declare that the content of
an element is to be laid out in multiple columns.

Other layout methods in CSS, when applied to a parent element, change
the display properties of the direct children. For example if a three
column grid layout is created, the direct children of the [grid
container](https://drafts.csswg.org/css-grid-2/#grid-container) become [grid
items](https://drafts.csswg.org/css-grid-2/#grid-item) and are placed into the column tracks, one element per
cell with additional rows created as needed.

The child elements of a [multi-column
container](#multi-column-container) however continue in normal flow, that flow is arranged
into a number of columns. These columns have a flexible inline size, and
therefore respond to available space by changing the size or number of
columns displayed.

Multi-column layouts are easy to describe in CSS. Here is a simple
example:

``` highlight
body { column-width: 12em }
```

In this example, the `body` element is set to have columns at
least [12em] wide. The exact number of columns will depend on the
available space.

The number of columns can also be set explicitly in the style sheet:

``` highlight
body { column-count: 2 }
```

In this case, the number of columns is fixed and the column widths will
vary depending on the available width.

The shorthand [columns](#propdef-columns) property can be used to set either, or
both, properties in one declaration.

In these examples, the number of
columns, the width of columns, and both the number and width are set,
respectively:

``` highlight
body { columns: 2 }
body { columns: 12em }
body { columns: 2 12em }
```

Another group of properties introduced in this module describe gaps and
rules between columns.

``` highlight
body {
 column-gap: 1em;
 column-rule: thin solid black;
}
```

The first declaration in the example above sets the gap between two
adjacent columns to be 1em. Column gaps are similar to padding areas. In
the middle of the gap there will be a rule which is described by the
[column-rule](#propdef-column-rule) property.

The values of the
[column-rule](#propdef-column-rule) property are similar to those of the CSS
[border](https://drafts.csswg.org/css-backgrounds-3/#propdef-border) properties. Like
[border],
[column-rule] is a shorthand
property.

In this example, the shorthand
[column-rule](#propdef-column-rule) declaration from the above example has
been expanded:

``` highlight
body {
 column-gap: 1em;
 column-rule-width: thin;
 column-rule-style: solid;
 column-rule-color: black;
}
```

The [column-fill](#propdef-column-fill) and
[column-span](#propdef-column-span) properties give style sheets a wider
range of visual expressions in multi-column layouts.

In this example, columns are set to be
balanced, i.e., to have approximately the same length. Also, `h2`
elements are set to span across all columns.

``` highlight
div { column-fill: balance }
h2 { column-span: all }
```

- [multicol-fill-balance-029.html](https://wpt.fyi/results/css/css-multicol/multicol-fill-balance-029.html "css/css-multicol/multicol-fill-balance-029.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-fill-balance-029.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-fill-balance-029.html)

This specification introduces ten new properties, all of which are used
in the examples above.

If all column properties have their initial value, the layout of an
element will be identical to a multi-column layout with only one column.

[Column
gaps](#column-gap) (diagonal
hatching) and [column rules](#column-rule) are shown in this sample rendition of a multi-column
container with padding (cross hatching). The hatched areas are present
for illustrational purposes only. In actual implementations these areas
will be determined by the background, the second image shows a rendering
of a [multi-column
container](#multi-column-container) with column-rules.

<figure>
<img src="images/initial-example.svg"
a /> <img
src="images/invisible-elements.svg"
a />
<figcaption>A multi-column layout with the non-visible column-span and
padding inside the multicol container highlighted.</figcaption>
</figure>

![The same layout as in the first image, as it would be displayed by an
implementation.](images/initial-example-b.svg){a}

### 1.1. Value Definitions

This specification follows the [CSS property definition
conventions](https://www.w3.org/TR/CSS2/about.html#property-defs) from
[\[CSS21\]](#biblio-css21 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")
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

## 2. The Multi-Column Model

An element whose
[column-width](#propdef-column-width) or
[column-count](#propdef-column-count) property is not
[auto](#valdef-column-width-auto) establishes a [multi-column container] (or *multicol container*
for short), and therefore acts as a container for [multi-column
layout](#multi-column-layout).

Tests

Basic multicol tests.

- [multicol-basic-002.html](https://wpt.fyi/results/css/css-multicol/multicol-basic-002.html "css/css-multicol/multicol-basic-002.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-basic-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-basic-002.html)
- [multicol-basic-004.html](https://wpt.fyi/results/css/css-multicol/multicol-basic-004.html "css/css-multicol/multicol-basic-004.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-basic-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-basic-004.html)

------------------------------------------------------------------------

Tests demonstrating that auto values do not create a multicol container.

- [multicol-count-computed-004.xht](https://wpt.fyi/results/css/css-multicol/multicol-count-computed-004.xht "css/css-multicol/multicol-count-computed-004.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-count-computed-004.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-count-computed-004.xht)

------------------------------------------------------------------------

Multicol properties do not inherit.

- [inheritance.html](https://wpt.fyi/results/css/css-multicol/inheritance.html "css/css-multicol/inheritance.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/inheritance.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/inheritance.html)

------------------------------------------------------------------------

Multicol with scrolled columns.

- [multicol-scroll-content.html](https://wpt.fyi/results/css/css-multicol/multicol-scroll-content.html "css/css-multicol/multicol-scroll-content.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-scroll-content.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-scroll-content.html)

------------------------------------------------------------------------

Multicol with zero height.

- [multicol-zero-height-001.xht](https://wpt.fyi/results/css/css-multicol/multicol-zero-height-001.xht "css/css-multicol/multicol-zero-height-001.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-zero-height-001.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-zero-height-001.xht)
- [multicol-zero-height-002.html](https://wpt.fyi/results/css/css-multicol/multicol-zero-height-002.html "css/css-multicol/multicol-zero-height-002.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-zero-height-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-zero-height-002.html)
- [multicol-zero-height-003.html](https://wpt.fyi/results/css/css-multicol/multicol-zero-height-003.html "css/css-multicol/multicol-zero-height-003.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-zero-height-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-zero-height-003.html)

------------------------------------------------------------------------

In the traditional CSS box model, the content of an element is flowed
into the content box of the corresponding element. Multi-column layout
introduces a [fragmentation
context](https://drafts.csswg.org/css-break-4/#fragmentation-context) formed of
[anonymous](https://drafts.csswg.org/css-display-4/#anonymous) [fragmentation
containers](https://drafts.csswg.org/css-break-4/#fragmentation-container) called [column boxes] (or
*columns* for short). These [column
boxes](#column-box) establish an
independent [block formatting
context](https://drafts.csswg.org/css-display-4/#block-formatting-context) into which the multi-column container's content flows,
and form the [containing
block](https://drafts.csswg.org/css-display-4/#containing-block) for its non-positioned children.

In this example, the width of the
image is set with these rules:

``` highlight
img {
 display: block;
 width: 100%;
}
```

Given that the column box creates a new [block formatting
context](https://drafts.csswg.org/css-display-4/#block-formatting-context), the
[width](https://drafts.csswg.org/css-sizing-3/#propdef-width) is calculated relative to the
column box. Therefore the image will not overflow the column box:

![The image is constrained by the column box that it is displayed
in.](images/image-inside-column.svg){a}

Given that the column box creates a
new [block formatting
context](https://drafts.csswg.org/css-display-4/#block-formatting-context), a top margin set on the first child element of a
multicol container will not collapse with the margins of the multicol
container.

![The margin above the first paragraph has not collapsed, leaving a
[1em] margin above the first line in the multicol
container.](images/margins-do-not-collapse.svg){a}

- [multicol-margin-001.xht](https://wpt.fyi/results/css/css-multicol/multicol-margin-001.xht "css/css-multicol/multicol-margin-001.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-margin-001.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-margin-001.xht)
- [multicol-margin-002.xht](https://wpt.fyi/results/css/css-multicol/multicol-margin-002.xht "css/css-multicol/multicol-margin-002.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-margin-002.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-margin-002.xht)
- [multicol-margin-003.html](https://wpt.fyi/results/css/css-multicol/multicol-margin-003.html "css/css-multicol/multicol-margin-003.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-margin-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-margin-003.html)
- [multicol-margin-child-001.xht](https://wpt.fyi/results/css/css-multicol/multicol-margin-child-001.xht "css/css-multicol/multicol-margin-child-001.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-margin-child-001.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-margin-child-001.xht)
- [multicol-nested-margin-001.xht](https://wpt.fyi/results/css/css-multicol/multicol-nested-margin-001.xht "css/css-multicol/multicol-nested-margin-001.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-nested-margin-001.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-nested-margin-001.xht)
- [multicol-nested-margin-002.xht](https://wpt.fyi/results/css/css-multicol/multicol-nested-margin-002.xht "css/css-multicol/multicol-nested-margin-002.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-nested-margin-002.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-nested-margin-002.xht)
- [multicol-nested-margin-003.xht](https://wpt.fyi/results/css/css-multicol/multicol-nested-margin-003.xht "css/css-multicol/multicol-nested-margin-003.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-nested-margin-003.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-nested-margin-003.xht)
- [multicol-nested-margin-004.xht](https://wpt.fyi/results/css/css-multicol/multicol-nested-margin-004.xht "css/css-multicol/multicol-nested-margin-004.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-nested-margin-004.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-nested-margin-004.xht)
- [multicol-nested-margin-005.xht](https://wpt.fyi/results/css/css-multicol/multicol-nested-margin-005.xht "css/css-multicol/multicol-nested-margin-005.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-nested-margin-005.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-nested-margin-005.xht)
- [multicol-collapsing-001.xht](https://wpt.fyi/results/css/css-multicol/multicol-collapsing-001.xht "css/css-multicol/multicol-collapsing-001.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-collapsing-001.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-collapsing-001.xht)

Floats that appear inside multi-column layouts are positioned with
regard to the [column box](#column-box) where the float appears.

In this example, this CSS fragment
describes the presentation of the image:

``` highlight
img {
 display: block;
 float: right;
}
```

In the HTML, the image appears after the sentence ending, \"the leg of a
chicken\".

![The image is floated inside the column box it appears
in.](images/image-floated-in-column.svg){a}

Content overflowing a [column box](#column-box) in the [block
axis](https://drafts.csswg.org/css-writing-modes-4/#block-axis)
[fragments](https://drafts.csswg.org/css-break-4/#fragment) and continues in the next [column
box].

 Column boxes, which are [anonymous
boxes](https://drafts.csswg.org/css-display-4/#anonymous), do not become the [containing
block](https://drafts.csswg.org/css-display-4/#containing-block) for [absolutely positioned
boxes](https://drafts.csswg.org/css-position-3/#absolute-position). The
[position](https://drafts.csswg.org/css-position-3/#propdef-position) property, which establishes a
containing block for such boxes, applies to the [multicol
container](#multi-column-container), it being the [principal
box](https://drafts.csswg.org/css-display-4/#principal-box).

Tests

- [multicol-containing-001.xht](https://wpt.fyi/results/css/css-multicol/multicol-containing-001.xht "css/css-multicol/multicol-containing-001.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-containing-001.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-containing-001.xht)
- [multicol-containing-002.xht](https://wpt.fyi/results/css/css-multicol/multicol-containing-002.xht "css/css-multicol/multicol-containing-002.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-containing-002.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-containing-002.xht)
- [multicol-containing-003.html](https://wpt.fyi/results/css/css-multicol/multicol-containing-003.html "css/css-multicol/multicol-containing-003.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-containing-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-containing-003.html)
- [multicol-contained-absolute.html](https://wpt.fyi/results/css/css-multicol/multicol-contained-absolute.html "css/css-multicol/multicol-contained-absolute.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-contained-absolute.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-contained-absolute.html)
- [abspos-autopos-contained-by-viewport-000.html](https://wpt.fyi/results/css/css-multicol/abspos-autopos-contained-by-viewport-000.html "css/css-multicol/abspos-autopos-contained-by-viewport-000.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/abspos-autopos-contained-by-viewport-000.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/abspos-autopos-contained-by-viewport-000.html)
- [abspos-autopos-contained-by-viewport-001.html](https://wpt.fyi/results/css/css-multicol/abspos-autopos-contained-by-viewport-001.html "css/css-multicol/abspos-autopos-contained-by-viewport-001.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/abspos-autopos-contained-by-viewport-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/abspos-autopos-contained-by-viewport-001.html)
- [abspos-multicol-in-second-outer-clipped.html](https://wpt.fyi/results/css/css-multicol/abspos-multicol-in-second-outer-clipped.html "css/css-multicol/abspos-multicol-in-second-outer-clipped.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/abspos-multicol-in-second-outer-clipped.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/abspos-multicol-in-second-outer-clipped.html)

In this example, the [multi-column
container](#multi-column-container) has [position:
relative](https://drafts.csswg.org/css-position-3/#propdef-position) thus becoming the containing block. The image
is a direct child of the [multi-column
container] and has [position:
absolute]. It takes positioning from
the [multi-column container] and not
from the [column box](#column-box).

``` highlight
.container {
 position: relative;
 column-count: 3;
}
img {
 position: absolute;
 top: 20px;
 left: 40px;
}
```

![The figure demonstrates that the absolutely positioned image is
positioned by reference to the multicol container and not the column
box.](images/column-not-containing-block.svg){a}

[Out-of-flow](https://drafts.csswg.org/css-display-4/#out-of-flow) descendants of a [multi-column
container](#multi-column-container) do affect column balancing, and the block-size of the
[multi-column container].

Tests

- [multicol-oof-inline-cb-001.html](https://wpt.fyi/results/css/css-multicol/multicol-oof-inline-cb-001.html "css/css-multicol/multicol-oof-inline-cb-001.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-oof-inline-cb-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-oof-inline-cb-001.html)
- [multicol-oof-inline-cb-002.html](https://wpt.fyi/results/css/css-multicol/multicol-oof-inline-cb-002.html "css/css-multicol/multicol-oof-inline-cb-002.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-oof-inline-cb-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-oof-inline-cb-002.html)

The column boxes are ordered in the [inline base
direction](https://drafts.csswg.org/css-writing-modes-4/#inline-base-direction) of the multicol container and arranged into [multicol
lines].
The [column width] is the length of the column box in the inline direction. The
[column height] is the length of the column box in the block direction. All
column boxes in a line have the same column width, and all column boxes
in a line have the same column height.

Tests

The following tests relate to baseline alignment of the content of
columns, though this is not defined in this specification.

- [baseline-000.html](https://wpt.fyi/results/css/css-multicol/baseline-000.html "css/css-multicol/baseline-000.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/baseline-000.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/baseline-000.html)
- [baseline-001.html](https://wpt.fyi/results/css/css-multicol/baseline-001.html "css/css-multicol/baseline-001.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/baseline-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/baseline-001.html)
- [baseline-002.html](https://wpt.fyi/results/css/css-multicol/baseline-002.html "css/css-multicol/baseline-002.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/baseline-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/baseline-002.html)
- [baseline-003.html](https://wpt.fyi/results/css/css-multicol/baseline-003.html "css/css-multicol/baseline-003.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/baseline-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/baseline-003.html)
- [baseline-004.html](https://wpt.fyi/results/css/css-multicol/baseline-004.html "css/css-multicol/baseline-004.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/baseline-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/baseline-004.html)
- [baseline-005.html](https://wpt.fyi/results/css/css-multicol/baseline-005.html "css/css-multicol/baseline-005.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/baseline-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/baseline-005.html)
- [baseline-006.html](https://wpt.fyi/results/css/css-multicol/baseline-006.html "css/css-multicol/baseline-006.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/baseline-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/baseline-006.html)
- [baseline-007.html](https://wpt.fyi/results/css/css-multicol/baseline-007.html "css/css-multicol/baseline-007.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/baseline-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/baseline-007.html)
- [baseline-008.html](https://wpt.fyi/results/css/css-multicol/baseline-008.html "css/css-multicol/baseline-008.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/baseline-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/baseline-008.html)
- [as-baseline-aligned-grid-item.html](https://wpt.fyi/results/css/css-multicol/crashtests/as-baseline-aligned-grid-item.html "css/css-multicol/crashtests/as-baseline-aligned-grid-item.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/as-baseline-aligned-grid-item.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/as-baseline-aligned-grid-item.html)

------------------------------------------------------------------------

The following tests check the behavior of list items that are also
muticol containers.

- [multicol-list-item-001.xht](https://wpt.fyi/results/css/css-multicol/multicol-list-item-001.xht "css/css-multicol/multicol-list-item-001.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-list-item-001.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-list-item-001.xht)
- [multicol-list-item-002.html](https://wpt.fyi/results/css/css-multicol/multicol-list-item-002.html "css/css-multicol/multicol-list-item-002.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-list-item-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-list-item-002.html)
- [multicol-list-item-003.html](https://wpt.fyi/results/css/css-multicol/multicol-list-item-003.html "css/css-multicol/multicol-list-item-003.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-list-item-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-list-item-003.html)
- [multicol-list-item-004.html](https://wpt.fyi/results/css/css-multicol/multicol-list-item-004.html "css/css-multicol/multicol-list-item-004.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-list-item-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-list-item-004.html)
- [multicol-list-item-005.html](https://wpt.fyi/results/css/css-multicol/multicol-list-item-005.html "css/css-multicol/multicol-list-item-005.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-list-item-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-list-item-005.html)
- [multicol-list-item-006.html](https://wpt.fyi/results/css/css-multicol/multicol-list-item-006.html "css/css-multicol/multicol-list-item-006.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-list-item-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-list-item-006.html)
- [multicol-list-item-007.html](https://wpt.fyi/results/css/css-multicol/multicol-list-item-007.html "css/css-multicol/multicol-list-item-007.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-list-item-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-list-item-007.html)
- [multicol-list-item-008.html](https://wpt.fyi/results/css/css-multicol/multicol-list-item-008.html "css/css-multicol/multicol-list-item-008.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-list-item-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-list-item-008.html)

------------------------------------------------------------------------

Testing grid items inside multicol

- [balance-grid-001.html](https://wpt.fyi/results/css/css-multicol/balance-grid-001.html "css/css-multicol/balance-grid-001.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/balance-grid-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/balance-grid-001.html)

------------------------------------------------------------------------

The following tests check the behavior of table elements.

- [multicol-table-cell-001.xht](https://wpt.fyi/results/css/css-multicol/table/multicol-table-cell-001.xht "css/css-multicol/table/multicol-table-cell-001.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/table/multicol-table-cell-001.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/table/multicol-table-cell-001.xht)
- [multicol-table-cell-height-001.xht](https://wpt.fyi/results/css/css-multicol/table/multicol-table-cell-height-001.xht "css/css-multicol/table/multicol-table-cell-height-001.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/table/multicol-table-cell-height-001.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/table/multicol-table-cell-height-001.xht)
- [multicol-table-cell-height-002.xht](https://wpt.fyi/results/css/css-multicol/table/multicol-table-cell-height-002.xht "css/css-multicol/table/multicol-table-cell-height-002.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/table/multicol-table-cell-height-002.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/table/multicol-table-cell-height-002.xht)
- [multicol-table-cell-vertical-align-001.xht](https://wpt.fyi/results/css/css-multicol/table/multicol-table-cell-vertical-align-001.xht "css/css-multicol/table/multicol-table-cell-vertical-align-001.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/table/multicol-table-cell-vertical-align-001.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/table/multicol-table-cell-vertical-align-001.xht)
- [table-cell-as-multicol.html](https://wpt.fyi/results/css/css-multicol/table/table-cell-as-multicol.html "css/css-multicol/table/table-cell-as-multicol.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/table/table-cell-as-multicol.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/table/table-cell-as-multicol.html)
- [table-cell-content-change-000.html](https://wpt.fyi/results/css/css-multicol/table/table-cell-content-change-000.html "css/css-multicol/table/table-cell-content-change-000.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/table/table-cell-content-change-000.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/table/table-cell-content-change-000.html)
- [table-cell-content-change-001.html](https://wpt.fyi/results/css/css-multicol/table/table-cell-content-change-001.html "css/css-multicol/table/table-cell-content-change-001.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/table/table-cell-content-change-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/table/table-cell-content-change-001.html)
- [table-cell-multicol-nested-001.html](https://wpt.fyi/results/css/css-multicol/table/table-cell-multicol-nested-001.html "css/css-multicol/table/table-cell-multicol-nested-001.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/table/table-cell-multicol-nested-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/table/table-cell-multicol-nested-001.html)
- [table-cell-multicol-nested-002.html](https://wpt.fyi/results/css/css-multicol/table/table-cell-multicol-nested-002.html "css/css-multicol/table/table-cell-multicol-nested-002.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/table/table-cell-multicol-nested-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/table/table-cell-multicol-nested-002.html)
- [table-cell-multicol-nested-003.html](https://wpt.fyi/results/css/css-multicol/table/table-cell-multicol-nested-003.html "css/css-multicol/table/table-cell-multicol-nested-003.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/table/table-cell-multicol-nested-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/table/table-cell-multicol-nested-003.html)
- [break-before-multicol-caption.html](https://wpt.fyi/results/css/css-multicol/crashtests/break-before-multicol-caption.html "css/css-multicol/crashtests/break-before-multicol-caption.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/break-before-multicol-caption.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/break-before-multicol-caption.html)
- [repeated-table-column.html](https://wpt.fyi/results/css/css-multicol/crashtests/repeated-table-column.html "css/css-multicol/crashtests/repeated-table-column.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/repeated-table-column.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/repeated-table-column.html)
- [table-cell-writing-mode-root.html](https://wpt.fyi/results/css/css-multicol/crashtests/table-cell-writing-mode-root.html "css/css-multicol/crashtests/table-cell-writing-mode-root.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/table-cell-writing-mode-root.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/table-cell-writing-mode-root.html)
- [balance-breakafter-before-table-section-crash.html](https://wpt.fyi/results/css/css-multicol/table/balance-breakafter-before-table-section-crash.html "css/css-multicol/table/balance-breakafter-before-table-section-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/table/balance-breakafter-before-table-section-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/table/balance-breakafter-before-table-section-crash.html)
- [balance-table-with-border-spacing.html](https://wpt.fyi/results/css/css-multicol/table/balance-table-with-border-spacing.html "css/css-multicol/table/balance-table-with-border-spacing.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/table/balance-table-with-border-spacing.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/table/balance-table-with-border-spacing.html)
- [balance-table-with-fractional-height-row.html](https://wpt.fyi/results/css/css-multicol/table/balance-table-with-fractional-height-row.html "css/css-multicol/table/balance-table-with-fractional-height-row.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/table/balance-table-with-fractional-height-row.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/table/balance-table-with-fractional-height-row.html)

------------------------------------------------------------------------

The following tests check that paint order is correct.

- [float-and-block.html](https://wpt.fyi/results/css/css-multicol/float-and-block.html "css/css-multicol/float-and-block.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/float-and-block.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/float-and-block.html)
- [move-with-text-after-paint.html](https://wpt.fyi/results/css/css-multicol/move-with-text-after-paint.html "css/css-multicol/move-with-text-after-paint.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/move-with-text-after-paint.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/move-with-text-after-paint.html)
- [resize-with-text-after-paint.html](https://wpt.fyi/results/css/css-multicol/resize-with-text-after-paint.html "css/css-multicol/resize-with-text-after-paint.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/resize-with-text-after-paint.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/resize-with-text-after-paint.html)

------------------------------------------------------------------------

The following tests relate to animation or transformation of multicol
properties.

- [column-width-interpolation.html](https://wpt.fyi/results/css/css-multicol/animation/column-width-interpolation.html "css/css-multicol/animation/column-width-interpolation.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/animation/column-width-interpolation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/animation/column-width-interpolation.html)
- [discrete-no-interpolation.html](https://wpt.fyi/results/css/css-multicol/animation/discrete-no-interpolation.html "css/css-multicol/animation/discrete-no-interpolation.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/animation/discrete-no-interpolation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/animation/discrete-no-interpolation.html)
- [multicol-overflow-positioned-transform-001.html](https://wpt.fyi/results/css/css-multicol/multicol-overflow-positioned-transform-001.html "css/css-multicol/multicol-overflow-positioned-transform-001.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-overflow-positioned-transform-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-overflow-positioned-transform-001.html)
- [multicol-overflow-transform-001.html](https://wpt.fyi/results/css/css-multicol/multicol-overflow-transform-001.html "css/css-multicol/multicol-overflow-transform-001.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-overflow-transform-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-overflow-transform-001.html)
- [resize-multicol-with-fixed-size-children.html](https://wpt.fyi/results/css/css-multicol/resize-multicol-with-fixed-size-children.html "css/css-multicol/resize-multicol-with-fixed-size-children.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/resize-multicol-with-fixed-size-children.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/resize-multicol-with-fixed-size-children.html)
- [resize-multicol-with-fixed-size-children-002.html](https://wpt.fyi/results/css/css-multicol/resize-multicol-with-fixed-size-children-002.html "css/css-multicol/resize-multicol-with-fixed-size-children-002.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/resize-multicol-with-fixed-size-children-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/resize-multicol-with-fixed-size-children-002.html)
- [resize-multicol-with-fixed-size-children-003.html](https://wpt.fyi/results/css/css-multicol/resize-multicol-with-fixed-size-children-003.html "css/css-multicol/resize-multicol-with-fixed-size-children-003.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/resize-multicol-with-fixed-size-children-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/resize-multicol-with-fixed-size-children-003.html)
- [resize-in-strict-containment-nested.html](https://wpt.fyi/results/css/css-multicol/resize-in-strict-containment-nested.html "css/css-multicol/resize-in-strict-containment-nested.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/resize-in-strict-containment-nested.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/resize-in-strict-containment-nested.html)
- [remove-child-in-strict-containment-also-spanner.html](https://wpt.fyi/results/css/css-multicol/remove-child-in-strict-containment-also-spanner.html "css/css-multicol/remove-child-in-strict-containment-also-spanner.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/remove-child-in-strict-containment-also-spanner.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/remove-child-in-strict-containment-also-spanner.html)
- [composited-under-clip-under-multicol.html](https://wpt.fyi/results/css/css-multicol/composited-under-clip-under-multicol.html "css/css-multicol/composited-under-clip-under-multicol.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/composited-under-clip-under-multicol.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/composited-under-clip-under-multicol.html)
- [change-intrinsic-width.html](https://wpt.fyi/results/css/css-multicol/change-intrinsic-width.html "css/css-multicol/change-intrinsic-width.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/change-intrinsic-width.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/change-intrinsic-width.html)
- [change-fragmentainer-size-000.html](https://wpt.fyi/results/css/css-multicol/change-fragmentainer-size-000.html "css/css-multicol/change-fragmentainer-size-000.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/change-fragmentainer-size-000.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/change-fragmentainer-size-000.html)
- [change-fragmentainer-size-001.html](https://wpt.fyi/results/css/css-multicol/change-fragmentainer-size-001.html "css/css-multicol/change-fragmentainer-size-001.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/change-fragmentainer-size-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/change-fragmentainer-size-001.html)
- [change-fragmentainer-size-002.html](https://wpt.fyi/results/css/css-multicol/change-fragmentainer-size-002.html "css/css-multicol/change-fragmentainer-size-002.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/change-fragmentainer-size-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/change-fragmentainer-size-002.html)
- [change-fragmentainer-size-003.html](https://wpt.fyi/results/css/css-multicol/change-fragmentainer-size-003.html "css/css-multicol/change-fragmentainer-size-003.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/change-fragmentainer-size-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/change-fragmentainer-size-003.html)
- [hit-test-child-under-perspective.html](https://wpt.fyi/results/css/css-multicol/hit-test-child-under-perspective.html "css/css-multicol/hit-test-child-under-perspective.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/hit-test-child-under-perspective.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/hit-test-child-under-perspective.html)
- [hit-test-transformed-child.html](https://wpt.fyi/results/css/css-multicol/hit-test-transformed-child.html "css/css-multicol/hit-test-transformed-child.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/hit-test-transformed-child.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/hit-test-transformed-child.html)

------------------------------------------------------------------------

Tests related to implementation bugs, not linked to specific normative
text.

- [multicol-with-monolithic-oof-with-multicol-with-oof.html](https://wpt.fyi/results/css/css-multicol/crashtests/multicol-with-monolithic-oof-with-multicol-with-oof.html "css/css-multicol/crashtests/multicol-with-monolithic-oof-with-multicol-with-oof.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/multicol-with-monolithic-oof-with-multicol-with-oof.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/multicol-with-monolithic-oof-with-multicol-with-oof.html)
- [chrome-bug-1293905.html](https://wpt.fyi/results/css/css-multicol/crashtests/chrome-bug-1293905.html "css/css-multicol/crashtests/chrome-bug-1293905.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/chrome-bug-1293905.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/chrome-bug-1293905.html)
- [chrome-bug-1297118.html](https://wpt.fyi/results/css/css-multicol/crashtests/chrome-bug-1297118.html "css/css-multicol/crashtests/chrome-bug-1297118.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/chrome-bug-1297118.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/chrome-bug-1297118.html)
- [chrome-bug-1301281.html](https://wpt.fyi/results/css/css-multicol/crashtests/chrome-bug-1301281.html "css/css-multicol/crashtests/chrome-bug-1301281.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/chrome-bug-1301281.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/chrome-bug-1301281.html)
- [chrome-bug-1303256.html](https://wpt.fyi/results/css/css-multicol/crashtests/chrome-bug-1303256.html "css/css-multicol/crashtests/chrome-bug-1303256.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/chrome-bug-1303256.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/chrome-bug-1303256.html)
- [chrome-bug-1314866.html](https://wpt.fyi/results/css/css-multicol/crashtests/chrome-bug-1314866.html "css/css-multicol/crashtests/chrome-bug-1314866.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/chrome-bug-1314866.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/chrome-bug-1314866.html)
- [dynamic-simplified-layout-break-propagation.html](https://wpt.fyi/results/css/css-multicol/crashtests/dynamic-simplified-layout-break-propagation.html "css/css-multicol/crashtests/dynamic-simplified-layout-break-propagation.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/dynamic-simplified-layout-break-propagation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/dynamic-simplified-layout-break-propagation.html)
- [float-multicol-crash.html](https://wpt.fyi/results/css/css-multicol/crashtests/float-multicol-crash.html "css/css-multicol/crashtests/float-multicol-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/float-multicol-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/float-multicol-crash.html)
- [change-abspos-width-in-second-column-crash.html](https://wpt.fyi/results/css/css-multicol/change-abspos-width-in-second-column-crash.html "css/css-multicol/change-abspos-width-in-second-column-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/change-abspos-width-in-second-column-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/change-abspos-width-in-second-column-crash.html)
- [change-out-of-flow-type-and-remove-inner-multicol-crash.html](https://wpt.fyi/results/css/css-multicol/change-out-of-flow-type-and-remove-inner-multicol-crash.html "css/css-multicol/change-out-of-flow-type-and-remove-inner-multicol-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/change-out-of-flow-type-and-remove-inner-multicol-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/change-out-of-flow-type-and-remove-inner-multicol-crash.html)
- [monolithic-oof-in-clipped-container.html](https://wpt.fyi/results/css/css-multicol/crashtests/monolithic-oof-in-clipped-container.html "css/css-multicol/crashtests/monolithic-oof-in-clipped-container.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/monolithic-oof-in-clipped-container.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/monolithic-oof-in-clipped-container.html)
- [move-linebreak-to-different-column.html](https://wpt.fyi/results/css/css-multicol/crashtests/move-linebreak-to-different-column.html "css/css-multicol/crashtests/move-linebreak-to-different-column.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/move-linebreak-to-different-column.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/move-linebreak-to-different-column.html)
- [move-newline-pre-text.html](https://wpt.fyi/results/css/css-multicol/crashtests/move-newline-pre-text.html "css/css-multicol/crashtests/move-newline-pre-text.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/move-newline-pre-text.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/move-newline-pre-text.html)
- [multicol-at-page-boundary-print.html](https://wpt.fyi/results/css/css-multicol/crashtests/multicol-at-page-boundary-print.html "css/css-multicol/crashtests/multicol-at-page-boundary-print.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/multicol-at-page-boundary-print.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/multicol-at-page-boundary-print.html)
- [multicol-block-in-inline-crash.html](https://wpt.fyi/results/css/css-multicol/crashtests/multicol-block-in-inline-crash.html "css/css-multicol/crashtests/multicol-block-in-inline-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/multicol-block-in-inline-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/multicol-block-in-inline-crash.html)
- [multicol-cached-consumed-bsize-crash.html](https://wpt.fyi/results/css/css-multicol/crashtests/multicol-cached-consumed-bsize-crash.html "css/css-multicol/crashtests/multicol-cached-consumed-bsize-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/multicol-cached-consumed-bsize-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/multicol-cached-consumed-bsize-crash.html)
- [multicol-column-change-crash.html](https://wpt.fyi/results/css/css-multicol/crashtests/multicol-column-change-crash.html "css/css-multicol/crashtests/multicol-column-change-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/multicol-column-change-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/multicol-column-change-crash.html)
- [multicol-dynamic-contain-crash.html](https://wpt.fyi/results/css/css-multicol/crashtests/multicol-dynamic-contain-crash.html "css/css-multicol/crashtests/multicol-dynamic-contain-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/multicol-dynamic-contain-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/multicol-dynamic-contain-crash.html)
- [multicol-dynamic-transform-crash.html](https://wpt.fyi/results/css/css-multicol/crashtests/multicol-dynamic-transform-crash.html "css/css-multicol/crashtests/multicol-dynamic-transform-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/multicol-dynamic-transform-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/multicol-dynamic-transform-crash.html)
- [multicol-floats-in-ifc.html](https://wpt.fyi/results/css/css-multicol/crashtests/multicol-floats-in-ifc.html "css/css-multicol/crashtests/multicol-floats-in-ifc.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/multicol-floats-in-ifc.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/multicol-floats-in-ifc.html)
- [multicol-parallel-flow-after-spanner-in-inline.html](https://wpt.fyi/results/css/css-multicol/crashtests/multicol-parallel-flow-after-spanner-in-inline.html "css/css-multicol/crashtests/multicol-parallel-flow-after-spanner-in-inline.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/multicol-parallel-flow-after-spanner-in-inline.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/multicol-parallel-flow-after-spanner-in-inline.html)
- [outline-move-oof-with-inline.html](https://wpt.fyi/results/css/css-multicol/crashtests/outline-move-oof-with-inline.html "css/css-multicol/crashtests/outline-move-oof-with-inline.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/outline-move-oof-with-inline.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/outline-move-oof-with-inline.html)
- [relpos-inline-with-abspos-multicol-gets-block-child.html](https://wpt.fyi/results/css/css-multicol/crashtests/relpos-inline-with-abspos-multicol-gets-block-child.html "css/css-multicol/crashtests/relpos-inline-with-abspos-multicol-gets-block-child.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/relpos-inline-with-abspos-multicol-gets-block-child.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/relpos-inline-with-abspos-multicol-gets-block-child.html)
- [size-containment-become-multicol-add-inline-child.html](https://wpt.fyi/results/css/css-multicol/crashtests/size-containment-become-multicol-add-inline-child.html "css/css-multicol/crashtests/size-containment-become-multicol-add-inline-child.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/size-containment-become-multicol-add-inline-child.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/size-containment-become-multicol-add-inline-child.html)
- [sticky-in-abs-in-sticky.html](https://wpt.fyi/results/css/css-multicol/crashtests/sticky-in-abs-in-sticky.html "css/css-multicol/crashtests/sticky-in-abs-in-sticky.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/sticky-in-abs-in-sticky.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/sticky-in-abs-in-sticky.html)
- [text-box-trim-end-and-widows.html](https://wpt.fyi/results/css/css-multicol/crashtests/text-box-trim-end-and-widows.html "css/css-multicol/crashtests/text-box-trim-end-and-widows.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/text-box-trim-end-and-widows.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/text-box-trim-end-and-widows.html)
- [vertical-rl-column-rules-wide-columns.html](https://wpt.fyi/results/css/css-multicol/crashtests/vertical-rl-column-rules-wide-columns.html "css/css-multicol/crashtests/vertical-rl-column-rules-wide-columns.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/vertical-rl-column-rules-wide-columns.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/vertical-rl-column-rules-wide-columns.html)
- [video-container-become-multicol.html](https://wpt.fyi/results/css/css-multicol/crashtests/video-container-become-multicol.html "css/css-multicol/crashtests/video-container-become-multicol.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/video-container-become-multicol.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/video-container-become-multicol.html)
- [dynamic-become-multicol-add-oof-inside-inline-crash.html](https://wpt.fyi/results/css/css-multicol/dynamic-become-multicol-add-oof-inside-inline-crash.html "css/css-multicol/dynamic-become-multicol-add-oof-inside-inline-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/dynamic-become-multicol-add-oof-inside-inline-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/dynamic-become-multicol-add-oof-inside-inline-crash.html)
- [extremely-tall-multicol-with-extremely-tall-child-crash.html](https://wpt.fyi/results/css/css-multicol/extremely-tall-multicol-with-extremely-tall-child-crash.html "css/css-multicol/extremely-tall-multicol-with-extremely-tall-child-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/extremely-tall-multicol-with-extremely-tall-child-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/extremely-tall-multicol-with-extremely-tall-child-crash.html)
- [file-control-crash.html](https://wpt.fyi/results/css/css-multicol/file-control-crash.html "css/css-multicol/file-control-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/file-control-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/file-control-crash.html)
- [img-alt-as-multicol-crash.html](https://wpt.fyi/results/css/css-multicol/img-alt-as-multicol-crash.html "css/css-multicol/img-alt-as-multicol-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/img-alt-as-multicol-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/img-alt-as-multicol-crash.html)
- [multicol-loads-indefinitely-001-crash.html](https://wpt.fyi/results/css/css-multicol/multicol-loads-indefinitely-001-crash.html "css/css-multicol/multicol-loads-indefinitely-001-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-loads-indefinitely-001-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-loads-indefinitely-001-crash.html)
- [multicol-on-broken-image-alt-text.html](https://wpt.fyi/results/css/css-multicol/multicol-on-broken-image-alt-text.html "css/css-multicol/multicol-on-broken-image-alt-text.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-on-broken-image-alt-text.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-on-broken-image-alt-text.html)
- [overflow-scroll-in-multicol-crash.html](https://wpt.fyi/results/css/css-multicol/overflow-scroll-in-multicol-crash.html "css/css-multicol/overflow-scroll-in-multicol-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/overflow-scroll-in-multicol-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/overflow-scroll-in-multicol-crash.html)
- [remove-block-sibling-of-inline-with-block-crash.html](https://wpt.fyi/results/css/css-multicol/remove-block-sibling-of-inline-with-block-crash.html "css/css-multicol/remove-block-sibling-of-inline-with-block-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/remove-block-sibling-of-inline-with-block-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/remove-block-sibling-of-inline-with-block-crash.html)
- [subpixel-column-progression.html](https://wpt.fyi/results/css/css-multicol/subpixel-column-progression.html "css/css-multicol/subpixel-column-progression.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/subpixel-column-progression.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/subpixel-column-progression.html)
- [subpixel-scroll-crash.html](https://wpt.fyi/results/css/css-multicol/subpixel-scroll-crash.html "css/css-multicol/subpixel-scroll-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/subpixel-scroll-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/subpixel-scroll-crash.html)
- [text-child-crash.html](https://wpt.fyi/results/css/css-multicol/text-child-crash.html "css/css-multicol/text-child-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/text-child-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/text-child-crash.html)
- [with-custom-layout-on-same-element-crash.https.html](https://wpt.fyi/results/css/css-multicol/with-custom-layout-on-same-element-crash.https.html "css/css-multicol/with-custom-layout-on-same-element-crash.https.html")
 [[(live
 test)]](https://wpt.live/css/css-multicol/with-custom-layout-on-same-element-crash.https.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/with-custom-layout-on-same-element-crash.https.html)
- [oof-in-area-001.html](https://wpt.fyi/results/css/css-multicol/crashtests/oof-in-area-001.html "css/css-multicol/crashtests/oof-in-area-001.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/oof-in-area-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/oof-in-area-001.html)
- [oof-in-area-002.html](https://wpt.fyi/results/css/css-multicol/crashtests/oof-in-area-002.html "css/css-multicol/crashtests/oof-in-area-002.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/oof-in-area-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/oof-in-area-002.html)
- [oof-in-area-003.html](https://wpt.fyi/results/css/css-multicol/crashtests/oof-in-area-003.html "css/css-multicol/crashtests/oof-in-area-003.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/oof-in-area-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/oof-in-area-003.html)
- [oof-in-oof-multicol-in-multicol-spanner-in-multicol.html](https://wpt.fyi/results/css/css-multicol/crashtests/oof-in-oof-multicol-in-multicol-spanner-in-multicol.html "css/css-multicol/crashtests/oof-in-oof-multicol-in-multicol-spanner-in-multicol.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/oof-in-oof-multicol-in-multicol-spanner-in-multicol.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/oof-in-oof-multicol-in-multicol-spanner-in-multicol.html)
- [oof-in-oof-multicol-in-relpos-in-oof-in-multicol-in-multicol.html](https://wpt.fyi/results/css/css-multicol/crashtests/oof-in-oof-multicol-in-relpos-in-oof-in-multicol-in-multicol.html "css/css-multicol/crashtests/oof-in-oof-multicol-in-relpos-in-oof-in-multicol-in-multicol.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/oof-in-oof-multicol-in-relpos-in-oof-in-multicol-in-multicol.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/oof-in-oof-multicol-in-relpos-in-oof-in-multicol-in-multicol.html)
- [oof-in-oof-multicol-in-relpos-spanner-in-multicol-in-relpos-multicol-in-multicol.html](https://wpt.fyi/results/css/css-multicol/crashtests/oof-in-oof-multicol-in-relpos-spanner-in-multicol-in-relpos-multicol-in-multicol.html "css/css-multicol/crashtests/oof-in-oof-multicol-in-relpos-spanner-in-multicol-in-relpos-multicol-in-multicol.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/oof-in-oof-multicol-in-relpos-spanner-in-multicol-in-relpos-multicol-in-multicol.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/oof-in-oof-multicol-in-relpos-spanner-in-multicol-in-relpos-multicol-in-multicol.html)
- [oof-in-oof-multicol-in-relpos-spanner-in-spanner-multicol-in-multicol-in-multicol.html](https://wpt.fyi/results/css/css-multicol/crashtests/oof-in-oof-multicol-in-relpos-spanner-in-spanner-multicol-in-multicol-in-multicol.html "css/css-multicol/crashtests/oof-in-oof-multicol-in-relpos-spanner-in-spanner-multicol-in-multicol-in-multicol.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/oof-in-oof-multicol-in-relpos-spanner-in-spanner-multicol-in-multicol-in-multicol.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/oof-in-oof-multicol-in-relpos-spanner-in-spanner-multicol-in-multicol-in-multicol.html)
- [oof-in-oof-multicol-in-spanner-in-multicol-in-spanner-in-nested-multicol.html](https://wpt.fyi/results/css/css-multicol/crashtests/oof-in-oof-multicol-in-spanner-in-multicol-in-spanner-in-nested-multicol.html "css/css-multicol/crashtests/oof-in-oof-multicol-in-spanner-in-multicol-in-spanner-in-nested-multicol.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/oof-in-oof-multicol-in-spanner-in-multicol-in-spanner-in-nested-multicol.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/oof-in-oof-multicol-in-spanner-in-multicol-in-spanner-in-nested-multicol.html)
- [oof-in-oof-multicol-in-spanner-in-nested-multicol.html](https://wpt.fyi/results/css/css-multicol/crashtests/oof-in-oof-multicol-in-spanner-in-nested-multicol.html "css/css-multicol/crashtests/oof-in-oof-multicol-in-spanner-in-nested-multicol.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/oof-in-oof-multicol-in-spanner-in-nested-multicol.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/oof-in-oof-multicol-in-spanner-in-nested-multicol.html)
- [oof-in-relpos-in-oof-multicol-in-oof-in-relpos-in-oof-multicol-in-multicol.html](https://wpt.fyi/results/css/css-multicol/crashtests/oof-in-relpos-in-oof-multicol-in-oof-in-relpos-in-oof-multicol-in-multicol.html "css/css-multicol/crashtests/oof-in-relpos-in-oof-multicol-in-oof-in-relpos-in-oof-multicol-in-multicol.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/oof-in-relpos-in-oof-multicol-in-oof-in-relpos-in-oof-multicol-in-multicol.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/oof-in-relpos-in-oof-multicol-in-oof-in-relpos-in-oof-multicol-in-multicol.html)
- [oof-in-relpos-in-oof-multicol-in-relpos-in-oof-multicol-in-relpos-multicol.html](https://wpt.fyi/results/css/css-multicol/crashtests/oof-in-relpos-in-oof-multicol-in-relpos-in-oof-multicol-in-relpos-multicol.html "css/css-multicol/crashtests/oof-in-relpos-in-oof-multicol-in-relpos-in-oof-multicol-in-relpos-multicol.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/oof-in-relpos-in-oof-multicol-in-relpos-in-oof-multicol-in-relpos-multicol.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/oof-in-relpos-in-oof-multicol-in-relpos-in-oof-multicol-in-relpos-multicol.html)
- [floated-input-in-inline-next-column.html](https://wpt.fyi/results/css/css-multicol/crashtests/floated-input-in-inline-next-column.html "css/css-multicol/crashtests/floated-input-in-inline-next-column.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/floated-input-in-inline-next-column.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/floated-input-in-inline-next-column.html)
- [inline-float-parallel-flow.html](https://wpt.fyi/results/css/css-multicol/crashtests/inline-float-parallel-flow.html "css/css-multicol/crashtests/inline-float-parallel-flow.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/inline-float-parallel-flow.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/inline-float-parallel-flow.html)
- [table-caption-in-clipped-overflow.html](https://wpt.fyi/results/css/css-multicol/crashtests/table-caption-in-clipped-overflow.html "css/css-multicol/crashtests/table-caption-in-clipped-overflow.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/table-caption-in-clipped-overflow.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/table-caption-in-clipped-overflow.html)
- [text-in-inline-interrupted-by-float.html](https://wpt.fyi/results/css/css-multicol/crashtests/text-in-inline-interrupted-by-float.html "css/css-multicol/crashtests/text-in-inline-interrupted-by-float.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/text-in-inline-interrupted-by-float.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/text-in-inline-interrupted-by-float.html)
- [increase-prev-sibling-height.html](https://wpt.fyi/results/css/css-multicol/increase-prev-sibling-height.html "css/css-multicol/increase-prev-sibling-height.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/increase-prev-sibling-height.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/increase-prev-sibling-height.html)
- [interleaved-bfc-crash.html](https://wpt.fyi/results/css/css-multicol/crashtests/interleaved-bfc-crash.html "css/css-multicol/crashtests/interleaved-bfc-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/interleaved-bfc-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/interleaved-bfc-crash.html)
- [relayout-fixedpos-in-abspos-in-relpos-in-nested-multicol.html](https://wpt.fyi/results/css/css-multicol/crashtests/relayout-fixedpos-in-abspos-in-relpos-in-nested-multicol.html "css/css-multicol/crashtests/relayout-fixedpos-in-abspos-in-relpos-in-nested-multicol.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/relayout-fixedpos-in-abspos-in-relpos-in-nested-multicol.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/relayout-fixedpos-in-abspos-in-relpos-in-nested-multicol.html)
- [inline-become-oof-container-make-oof-inflow.html](https://wpt.fyi/results/css/css-multicol/crashtests/inline-become-oof-container-make-oof-inflow.html "css/css-multicol/crashtests/inline-become-oof-container-make-oof-inflow.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/inline-become-oof-container-make-oof-inflow.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/inline-become-oof-container-make-oof-inflow.html)
- [multicol-dynamic-change-inside-break-inside-avoid-001.html](https://wpt.fyi/results/css/css-multicol/multicol-dynamic-change-inside-break-inside-avoid-001.html "css/css-multicol/multicol-dynamic-change-inside-break-inside-avoid-001.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-dynamic-change-inside-break-inside-avoid-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-dynamic-change-inside-break-inside-avoid-001.html)
- [multicol-dynamic-add-001.html](https://wpt.fyi/results/css/css-multicol/multicol-dynamic-add-001.html "css/css-multicol/multicol-dynamic-add-001.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-dynamic-add-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-dynamic-add-001.html)
- [multicol-dynamic-add-002.html](https://wpt.fyi/results/css/css-multicol/multicol-dynamic-add-002.html "css/css-multicol/multicol-dynamic-add-002.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-dynamic-add-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-dynamic-add-002.html)
- [multicol-dynamic-add-003.html](https://wpt.fyi/results/css/css-multicol/multicol-dynamic-add-003.html "css/css-multicol/multicol-dynamic-add-003.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-dynamic-add-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-dynamic-add-003.html)
- [multicol-dynamic-add-004.html](https://wpt.fyi/results/css/css-multicol/multicol-dynamic-add-004.html "css/css-multicol/multicol-dynamic-add-004.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-dynamic-add-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-dynamic-add-004.html)
- [scroll-width-height.tentative.html](https://wpt.fyi/results/css/css-multicol/scroll-width-height.tentative.html "css/css-multicol/scroll-width-height.tentative.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/scroll-width-height.tentative.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/scroll-width-height.tentative.html)
- [filter-with-abspos.html](https://wpt.fyi/results/css/css-multicol/filter-with-abspos.html "css/css-multicol/filter-with-abspos.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/filter-with-abspos.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/filter-with-abspos.html)
- [add-list-item-marker.html](https://wpt.fyi/results/css/css-multicol/crashtests/add-list-item-marker.html "css/css-multicol/crashtests/add-list-item-marker.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/add-list-item-marker.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/add-list-item-marker.html)
- [block-in-inline-with-abspos-after-spanner.html](https://wpt.fyi/results/css/css-multicol/crashtests/block-in-inline-with-abspos-after-spanner.html "css/css-multicol/crashtests/block-in-inline-with-abspos-after-spanner.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/block-in-inline-with-abspos-after-spanner.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/block-in-inline-with-abspos-after-spanner.html)
- [block-in-inline-with-spanner-in-overflowed-parent.html](https://wpt.fyi/results/css/css-multicol/crashtests/block-in-inline-with-spanner-in-overflowed-parent.html "css/css-multicol/crashtests/block-in-inline-with-spanner-in-overflowed-parent.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/block-in-inline-with-spanner-in-overflowed-parent.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/block-in-inline-with-spanner-in-overflowed-parent.html)
- [block-in-inline-with-spanner-in-overflowed-parent-nested-multicol.html](https://wpt.fyi/results/css/css-multicol/crashtests/block-in-inline-with-spanner-in-overflowed-parent-nested-multicol.html "css/css-multicol/crashtests/block-in-inline-with-spanner-in-overflowed-parent-nested-multicol.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/block-in-inline-with-spanner-in-overflowed-parent-nested-multicol.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/block-in-inline-with-spanner-in-overflowed-parent-nested-multicol.html)
- [first-letter-column-span-fieldset.html](https://wpt.fyi/results/css/css-multicol/crashtests/first-letter-column-span-fieldset.html "css/css-multicol/crashtests/first-letter-column-span-fieldset.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/first-letter-column-span-fieldset.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/first-letter-column-span-fieldset.html)
- [triply-nested-partial-relayout.html](https://wpt.fyi/results/css/css-multicol/crashtests/triply-nested-partial-relayout.html "css/css-multicol/crashtests/triply-nested-partial-relayout.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/triply-nested-partial-relayout.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/triply-nested-partial-relayout.html)
- [float-beside-whitespace-ruby.html](https://wpt.fyi/results/css/css-multicol/crashtests/float-beside-whitespace-ruby.html "css/css-multicol/crashtests/float-beside-whitespace-ruby.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/float-beside-whitespace-ruby.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/float-beside-whitespace-ruby.html)
- [flex-grid-item-insert-001-crash.html](https://wpt.fyi/results/css/css-multicol/flex-grid-item-insert-001-crash.html "css/css-multicol/flex-grid-item-insert-001-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/flex-grid-item-insert-001-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/flex-grid-item-insert-001-crash.html)
- [flex-grid-item-insert-002-crash.html](https://wpt.fyi/results/css/css-multicol/flex-grid-item-insert-002-crash.html "css/css-multicol/flex-grid-item-insert-002-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/flex-grid-item-insert-002-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/flex-grid-item-insert-002-crash.html)

------------------------------------------------------------------------

Tests related to printing and paged media as related to multicol.

- [auto-fill-auto-size-001-print.html](https://wpt.fyi/results/css/css-multicol/auto-fill-auto-size-001-print.html "css/css-multicol/auto-fill-auto-size-001-print.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/auto-fill-auto-size-001-print.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/auto-fill-auto-size-001-print.html)
- [auto-fill-auto-size-002-print.html](https://wpt.fyi/results/css/css-multicol/auto-fill-auto-size-002-print.html "css/css-multicol/auto-fill-auto-size-002-print.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/auto-fill-auto-size-002-print.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/auto-fill-auto-size-002-print.html)
- [multicol-height-002-print.xht](https://wpt.fyi/results/css/css-multicol/multicol-height-002-print.xht "css/css-multicol/multicol-height-002-print.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-height-002-print.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-height-002-print.xht)
- [named-page.html](https://wpt.fyi/results/css/css-multicol/named-page.html "css/css-multicol/named-page.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/named-page.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/named-page.html)
- [page-property-ignored.html](https://wpt.fyi/results/css/css-multicol/page-property-ignored.html "css/css-multicol/page-property-ignored.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/page-property-ignored.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/page-property-ignored.html)

------------------------------------------------------------------------

 In text set using a vertical writing mode, the block
direction runs horizontally. In a vertical writing mode columns are laid
out horizontally, and the direction of the flow of blocks may be right
to left, or left to right. The
[column-width](#propdef-column-width) property therefore refers to the
inline size of the column, and not the physical horizontal width.

![A diagram showing the different ways columns may be arranged due to
writing mode.\
From left to right: horizontal-tb, vertical-rl,
vertical-lr.](images/writing-modes.svg){a}

Tests regarding vertical writing modes.

- [orthogonal-writing-mode-shrink-to-fit.html](https://wpt.fyi/results/css/css-multicol/orthogonal-writing-mode-shrink-to-fit.html "css/css-multicol/orthogonal-writing-mode-shrink-to-fit.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/orthogonal-writing-mode-shrink-to-fit.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/orthogonal-writing-mode-shrink-to-fit.html)
- [multicol-under-vertical-rl-scroll.html](https://wpt.fyi/results/css/css-multicol/multicol-under-vertical-rl-scroll.html "css/css-multicol/multicol-under-vertical-rl-scroll.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-under-vertical-rl-scroll.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-under-vertical-rl-scroll.html)
- [hit-test-in-vertical-rl.html](https://wpt.fyi/results/css/css-multicol/hit-test-in-vertical-rl.html "css/css-multicol/hit-test-in-vertical-rl.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/hit-test-in-vertical-rl.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/hit-test-in-vertical-rl.html)

------------------------------------------------------------------------

Within each [multicol
line](#multi-column-line) in
the multi-column container, adjacent column boxes are separated by a
[column gap],
which may contain a [column rule]. All column gaps in the same multi-column
container are equal. All column rules in the same multi-column container
are also equal, if they appear; column rules only appear between columns
that both have content.

In the simplest case a multicol container will contain only one line of
columns, and the height of each column will be equivalent to the used
height of the multi-column container's content box. However,
[fragmentation](https://drafts.csswg.org/css-break-4/#fragmentation) or
[spanners](#multi-column-spanner) can split the content of the [multi-column
container](#multi-column-container) into multiple [multicol
lines](#multi-column-line).

If the multi-column container is paginated, the height of each column is
constrained by the page and the content continues in a new line of
column boxes on the next page; a column box never splits across pages.

The same effect occurs when a *spanning element* divides the
multi-column container: the columns before the spanning element are
balanced and shortened to fit their content. Content after the spanning
element then flows into a new, subsequent line of column boxes.

![A demonstration of how the spanning element divides the multicol
container.](images/simple-span-example.svg){a}

A [multi-column
container](#multi-column-container) therefore is a regular [block
container](https://drafts.csswg.org/css-display-4/#block-container) that establishes a new [independent formatting
context](https://drafts.csswg.org/css-display-4/#independent-formatting-context) whose contents consist of a series of [multicol
lines](#multi-column-line)
and multicol spanners. Each [multi-column
line] acts as a [block-level
box](https://drafts.csswg.org/css-display-4/#block-level-box) that establishes a [multi-column formatting
context] for its [column
boxes](#column-box); and each
[spanner](#multi-column-spanner) acts as a [block-level box]
that establishes an [independent formatting
context] with its type
depending on its
[display](https://drafts.csswg.org/css-display-3/#propdef-display) value as usual.

Nested multi-column containers are allowed, but there may be
implementation-specific limits.

Tests

- [multicol-nested-002.xht](https://wpt.fyi/results/css/css-multicol/multicol-nested-002.xht "css/css-multicol/multicol-nested-002.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-nested-002.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-nested-002.xht)
- [multicol-nested-005.xht](https://wpt.fyi/results/css/css-multicol/multicol-nested-005.xht "css/css-multicol/multicol-nested-005.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-nested-005.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-nested-005.xht)
- [multicol-nested-006.html](https://wpt.fyi/results/css/css-multicol/multicol-nested-006.html "css/css-multicol/multicol-nested-006.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-nested-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-nested-006.html)
- [multicol-nested-007.html](https://wpt.fyi/results/css/css-multicol/multicol-nested-007.html "css/css-multicol/multicol-nested-007.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-nested-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-nested-007.html)
- [multicol-nested-008.html](https://wpt.fyi/results/css/css-multicol/multicol-nested-008.html "css/css-multicol/multicol-nested-008.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-nested-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-nested-008.html)
- [multicol-nested-009.html](https://wpt.fyi/results/css/css-multicol/multicol-nested-009.html "css/css-multicol/multicol-nested-009.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-nested-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-nested-009.html)
- [multicol-nested-010.html](https://wpt.fyi/results/css/css-multicol/multicol-nested-010.html "css/css-multicol/multicol-nested-010.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-nested-010.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-nested-010.html)
- [multicol-nested-011.html](https://wpt.fyi/results/css/css-multicol/multicol-nested-011.html "css/css-multicol/multicol-nested-011.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-nested-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-nested-011.html)
- [multicol-nested-012.html](https://wpt.fyi/results/css/css-multicol/multicol-nested-012.html "css/css-multicol/multicol-nested-012.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-nested-012.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-nested-012.html)
- [multicol-nested-013.html](https://wpt.fyi/results/css/css-multicol/multicol-nested-013.html "css/css-multicol/multicol-nested-013.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-nested-013.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-nested-013.html)
- [multicol-nested-014.html](https://wpt.fyi/results/css/css-multicol/multicol-nested-014.html "css/css-multicol/multicol-nested-014.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-nested-014.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-nested-014.html)
- [multicol-nested-015.html](https://wpt.fyi/results/css/css-multicol/multicol-nested-015.html "css/css-multicol/multicol-nested-015.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-nested-015.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-nested-015.html)
- [multicol-nested-016.html](https://wpt.fyi/results/css/css-multicol/multicol-nested-016.html "css/css-multicol/multicol-nested-016.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-nested-016.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-nested-016.html)
- [multicol-nested-017.html](https://wpt.fyi/results/css/css-multicol/multicol-nested-017.html "css/css-multicol/multicol-nested-017.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-nested-017.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-nested-017.html)
- [multicol-nested-018.html](https://wpt.fyi/results/css/css-multicol/multicol-nested-018.html "css/css-multicol/multicol-nested-018.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-nested-018.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-nested-018.html)
- [multicol-nested-019.html](https://wpt.fyi/results/css/css-multicol/multicol-nested-019.html "css/css-multicol/multicol-nested-019.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-nested-019.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-nested-019.html)
- [multicol-nested-020.html](https://wpt.fyi/results/css/css-multicol/multicol-nested-020.html "css/css-multicol/multicol-nested-020.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-nested-020.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-nested-020.html)
- [multicol-nested-021.html](https://wpt.fyi/results/css/css-multicol/multicol-nested-021.html "css/css-multicol/multicol-nested-021.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-nested-021.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-nested-021.html)
- [multicol-nested-022.html](https://wpt.fyi/results/css/css-multicol/multicol-nested-022.html "css/css-multicol/multicol-nested-022.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-nested-022.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-nested-022.html)
- [multicol-nested-023.html](https://wpt.fyi/results/css/css-multicol/multicol-nested-023.html "css/css-multicol/multicol-nested-023.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-nested-023.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-nested-023.html)
- [multicol-nested-024.html](https://wpt.fyi/results/css/css-multicol/multicol-nested-024.html "css/css-multicol/multicol-nested-024.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-nested-024.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-nested-024.html)
- [multicol-nested-025.html](https://wpt.fyi/results/css/css-multicol/multicol-nested-025.html "css/css-multicol/multicol-nested-025.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-nested-025.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-nested-025.html)
- [multicol-nested-026.html](https://wpt.fyi/results/css/css-multicol/multicol-nested-026.html "css/css-multicol/multicol-nested-026.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-nested-026.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-nested-026.html)
- [multicol-nested-027.html](https://wpt.fyi/results/css/css-multicol/multicol-nested-027.html "css/css-multicol/multicol-nested-027.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-nested-027.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-nested-027.html)
- [multicol-nested-028.html](https://wpt.fyi/results/css/css-multicol/multicol-nested-028.html "css/css-multicol/multicol-nested-028.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-nested-028.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-nested-028.html)
- [multicol-nested-029.html](https://wpt.fyi/results/css/css-multicol/multicol-nested-029.html "css/css-multicol/multicol-nested-029.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-nested-029.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-nested-029.html)
- [multicol-nested-030.html](https://wpt.fyi/results/css/css-multicol/multicol-nested-030.html "css/css-multicol/multicol-nested-030.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-nested-030.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-nested-030.html)
- [multicol-nested-031.html](https://wpt.fyi/results/css/css-multicol/multicol-nested-031.html "css/css-multicol/multicol-nested-031.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-nested-031.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-nested-031.html)
- [multicol-nested-032.html](https://wpt.fyi/results/css/css-multicol/multicol-nested-032.html "css/css-multicol/multicol-nested-032.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-nested-032.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-nested-032.html)
- [multicol-nested-033.html](https://wpt.fyi/results/css/css-multicol/multicol-nested-033.html "css/css-multicol/multicol-nested-033.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-nested-033.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-nested-033.html)
- [nested-as-balanced-legend.html](https://wpt.fyi/results/css/css-multicol/crashtests/nested-as-balanced-legend.html "css/css-multicol/crashtests/nested-as-balanced-legend.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/nested-as-balanced-legend.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/nested-as-balanced-legend.html)
- [nested-as-nested-balanced-legend.html](https://wpt.fyi/results/css/css-multicol/crashtests/nested-as-nested-balanced-legend.html "css/css-multicol/crashtests/nested-as-nested-balanced-legend.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/nested-as-nested-balanced-legend.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/nested-as-nested-balanced-legend.html)
- [nested-floated-multicol-with-tall-margin.html](https://wpt.fyi/results/css/css-multicol/crashtests/nested-floated-multicol-with-tall-margin.html "css/css-multicol/crashtests/nested-floated-multicol-with-tall-margin.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/nested-floated-multicol-with-tall-margin.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/nested-floated-multicol-with-tall-margin.html)
- [nested-multicol-and-float-with-tall-padding-before-float.html](https://wpt.fyi/results/css/css-multicol/crashtests/nested-multicol-and-float-with-tall-padding-before-float.html "css/css-multicol/crashtests/nested-multicol-and-float-with-tall-padding-before-float.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/nested-multicol-and-float-with-tall-padding-before-float.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/nested-multicol-and-float-with-tall-padding-before-float.html)
- [nested-multicol-and-float-with-tall-padding.html](https://wpt.fyi/results/css/css-multicol/crashtests/nested-multicol-and-float-with-tall-padding.html "css/css-multicol/crashtests/nested-multicol-and-float-with-tall-padding.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/nested-multicol-and-float-with-tall-padding.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/nested-multicol-and-float-with-tall-padding.html)
- [nested-multicol-fieldset-tall-trailing-border-freeze.html](https://wpt.fyi/results/css/css-multicol/crashtests/nested-multicol-fieldset-tall-trailing-border-freeze.html "css/css-multicol/crashtests/nested-multicol-fieldset-tall-trailing-border-freeze.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/nested-multicol-fieldset-tall-trailing-border-freeze.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/nested-multicol-fieldset-tall-trailing-border-freeze.html)
- [nested-multicol-fieldset-tall-trailing-padding.html](https://wpt.fyi/results/css/css-multicol/crashtests/nested-multicol-fieldset-tall-trailing-padding.html "css/css-multicol/crashtests/nested-multicol-fieldset-tall-trailing-padding.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/nested-multicol-fieldset-tall-trailing-padding.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/nested-multicol-fieldset-tall-trailing-padding.html)
- [nested-multicol-in-svg-foreignobject.html](https://wpt.fyi/results/css/css-multicol/crashtests/nested-multicol-in-svg-foreignobject.html "css/css-multicol/crashtests/nested-multicol-in-svg-foreignobject.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/nested-multicol-in-svg-foreignobject.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/nested-multicol-in-svg-foreignobject.html)
- [nested-multicol-nested-flex.html](https://wpt.fyi/results/css/css-multicol/crashtests/nested-multicol-nested-flex.html "css/css-multicol/crashtests/nested-multicol-nested-flex.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/nested-multicol-nested-flex.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/nested-multicol-nested-flex.html)
- [nested-multicol-with-float-between.html](https://wpt.fyi/results/css/css-multicol/crashtests/nested-multicol-with-float-between.html "css/css-multicol/crashtests/nested-multicol-with-float-between.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/nested-multicol-with-float-between.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/nested-multicol-with-float-between.html)
- [nested-oof-multicol-with-monolithic-child.html](https://wpt.fyi/results/css/css-multicol/crashtests/nested-oof-multicol-with-monolithic-child.html "css/css-multicol/crashtests/nested-oof-multicol-with-monolithic-child.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/nested-oof-multicol-with-monolithic-child.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/nested-oof-multicol-with-monolithic-child.html)
- [nested-oof-multicol-with-oof-needing-additional-columns.html](https://wpt.fyi/results/css/css-multicol/crashtests/nested-oof-multicol-with-oof-needing-additional-columns.html "css/css-multicol/crashtests/nested-oof-multicol-with-oof-needing-additional-columns.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/nested-oof-multicol-with-oof-needing-additional-columns.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/nested-oof-multicol-with-oof-needing-additional-columns.html)
- [nested-oof-multicol-with-padding.html](https://wpt.fyi/results/css/css-multicol/crashtests/nested-oof-multicol-with-padding.html "css/css-multicol/crashtests/nested-oof-multicol-with-padding.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/nested-oof-multicol-with-padding.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/nested-oof-multicol-with-padding.html)
- [nested-with-fragmented-oof-negative-top-offset.html](https://wpt.fyi/results/css/css-multicol/crashtests/nested-with-fragmented-oof-negative-top-offset.html "css/css-multicol/crashtests/nested-with-fragmented-oof-negative-top-offset.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/nested-with-fragmented-oof-negative-top-offset.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/nested-with-fragmented-oof-negative-top-offset.html)
- [nested-with-multicol-table-caption.html](https://wpt.fyi/results/css/css-multicol/crashtests/nested-with-multicol-table-caption.html "css/css-multicol/crashtests/nested-with-multicol-table-caption.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/nested-with-multicol-table-caption.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/nested-with-multicol-table-caption.html)
- [multicol-table-caption-parallel-flow-after-spanner-in-inline.html](https://wpt.fyi/results/css/css-multicol/crashtests/multicol-table-caption-parallel-flow-after-spanner-in-inline.html "css/css-multicol/crashtests/multicol-table-caption-parallel-flow-after-spanner-in-inline.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/multicol-table-caption-parallel-flow-after-spanner-in-inline.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/multicol-table-caption-parallel-flow-after-spanner-in-inline.html)
- [nested-with-multicol-table-cell.html](https://wpt.fyi/results/css/css-multicol/crashtests/nested-with-multicol-table-cell.html "css/css-multicol/crashtests/nested-with-multicol-table-cell.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/nested-with-multicol-table-cell.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/nested-with-multicol-table-cell.html)
- [nested-with-oof-inside-fixed-width.html](https://wpt.fyi/results/css/css-multicol/crashtests/nested-with-oof-inside-fixed-width.html "css/css-multicol/crashtests/nested-with-oof-inside-fixed-width.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/nested-with-oof-inside-fixed-width.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/nested-with-oof-inside-fixed-width.html)
- [nested-with-percentage-size-and-oof.html](https://wpt.fyi/results/css/css-multicol/crashtests/nested-with-percentage-size-and-oof.html "css/css-multicol/crashtests/nested-with-percentage-size-and-oof.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/nested-with-percentage-size-and-oof.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/nested-with-percentage-size-and-oof.html)
- [nested-with-tall-padding-and-oof.html](https://wpt.fyi/results/css/css-multicol/crashtests/nested-with-tall-padding-and-oof.html "css/css-multicol/crashtests/nested-with-tall-padding-and-oof.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/nested-with-tall-padding-and-oof.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/nested-with-tall-padding-and-oof.html)
- [nested-with-tall-padding.html](https://wpt.fyi/results/css/css-multicol/crashtests/nested-with-tall-padding.html "css/css-multicol/crashtests/nested-with-tall-padding.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/nested-with-tall-padding.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/nested-with-tall-padding.html)
- [oof-in-nested-line-float.html](https://wpt.fyi/results/css/css-multicol/crashtests/oof-in-nested-line-float.html "css/css-multicol/crashtests/oof-in-nested-line-float.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/oof-in-nested-line-float.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/oof-in-nested-line-float.html)
- [oof-nested-multicol-inside-oof.html](https://wpt.fyi/results/css/css-multicol/crashtests/oof-nested-multicol-inside-oof.html "css/css-multicol/crashtests/oof-nested-multicol-inside-oof.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/oof-nested-multicol-inside-oof.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/oof-nested-multicol-inside-oof.html)
- [relayout-nested-with-oof.html](https://wpt.fyi/results/css/css-multicol/crashtests/relayout-nested-with-oof.html "css/css-multicol/crashtests/relayout-nested-with-oof.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/relayout-nested-with-oof.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/relayout-nested-with-oof.html)
- [repeated-section-in-nested-table-nested-multicol.html](https://wpt.fyi/results/css/css-multicol/crashtests/repeated-section-in-nested-table-nested-multicol.html "css/css-multicol/crashtests/repeated-section-in-nested-table-nested-multicol.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/repeated-section-in-nested-table-nested-multicol.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/repeated-section-in-nested-table-nested-multicol.html)
- [repeated-table-footer-in-caption-nested-multicol.html](https://wpt.fyi/results/css/css-multicol/crashtests/repeated-table-footer-in-caption-nested-multicol.html "css/css-multicol/crashtests/repeated-table-footer-in-caption-nested-multicol.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/repeated-table-footer-in-caption-nested-multicol.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/repeated-table-footer-in-caption-nested-multicol.html)
- [nested-balanced-monolithic-multicol-crash.html](https://wpt.fyi/results/css/css-multicol/nested-balanced-monolithic-multicol-crash.html "css/css-multicol/nested-balanced-monolithic-multicol-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/nested-balanced-monolithic-multicol-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/nested-balanced-monolithic-multicol-crash.html)
- [nested-balanced-very-tall-content-crash.html](https://wpt.fyi/results/css/css-multicol/nested-balanced-very-tall-content-crash.html "css/css-multicol/nested-balanced-very-tall-content-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/nested-balanced-very-tall-content-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/nested-balanced-very-tall-content-crash.html)
- [nested-floated-shape-outside-multicol-with-monolithic-child-crash.html](https://wpt.fyi/results/css/css-multicol/nested-floated-shape-outside-multicol-with-monolithic-child-crash.html "css/css-multicol/nested-floated-shape-outside-multicol-with-monolithic-child-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/nested-floated-shape-outside-multicol-with-monolithic-child-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/nested-floated-shape-outside-multicol-with-monolithic-child-crash.html)
- [nested-with-overflowing-padding-crash.html](https://wpt.fyi/results/css/css-multicol/nested-with-overflowing-padding-crash.html "css/css-multicol/nested-with-overflowing-padding-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/nested-with-overflowing-padding-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/nested-with-overflowing-padding-crash.html)
- [triply-nested-with-fixedpos-in-abspos-crash.html](https://wpt.fyi/results/css/css-multicol/triply-nested-with-fixedpos-in-abspos-crash.html "css/css-multicol/triply-nested-with-fixedpos-in-abspos-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/triply-nested-with-fixedpos-in-abspos-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/triply-nested-with-fixedpos-in-abspos-crash.html)
- [fixed-in-nested-multicol-with-transform-container.html](https://wpt.fyi/results/css/css-multicol/fixed-in-nested-multicol-with-transform-container.html "css/css-multicol/fixed-in-nested-multicol-with-transform-container.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/fixed-in-nested-multicol-with-transform-container.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/fixed-in-nested-multicol-with-transform-container.html)
- [fixed-in-nested-multicol-with-viewport-container.html](https://wpt.fyi/results/css/css-multicol/fixed-in-nested-multicol-with-viewport-container.html "css/css-multicol/fixed-in-nested-multicol-with-viewport-container.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/fixed-in-nested-multicol-with-viewport-container.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/fixed-in-nested-multicol-with-viewport-container.html)
- [fixed-in-nested-multicol.html](https://wpt.fyi/results/css/css-multicol/fixed-in-nested-multicol.html "css/css-multicol/fixed-in-nested-multicol.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/fixed-in-nested-multicol.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/fixed-in-nested-multicol.html)
- [nested-after-float-clearance.html](https://wpt.fyi/results/css/css-multicol/nested-after-float-clearance.html "css/css-multicol/nested-after-float-clearance.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/nested-after-float-clearance.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/nested-after-float-clearance.html)
- [nested-at-outer-boundary-as-fieldset.html](https://wpt.fyi/results/css/css-multicol/nested-at-outer-boundary-as-fieldset.html "css/css-multicol/nested-at-outer-boundary-as-fieldset.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/nested-at-outer-boundary-as-fieldset.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/nested-at-outer-boundary-as-fieldset.html)
- [nested-at-outer-boundary-as-float.html](https://wpt.fyi/results/css/css-multicol/nested-at-outer-boundary-as-float.html "css/css-multicol/nested-at-outer-boundary-as-float.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/nested-at-outer-boundary-as-float.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/nested-at-outer-boundary-as-float.html)
- [nested-at-outer-boundary-as-legend.html](https://wpt.fyi/results/css/css-multicol/nested-at-outer-boundary-as-legend.html "css/css-multicol/nested-at-outer-boundary-as-legend.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/nested-at-outer-boundary-as-legend.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/nested-at-outer-boundary-as-legend.html)
- [nested-floated-multicol-with-monolithic-child.html](https://wpt.fyi/results/css/css-multicol/nested-floated-multicol-with-monolithic-child.html "css/css-multicol/nested-floated-multicol-with-monolithic-child.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/nested-floated-multicol-with-monolithic-child.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/nested-floated-multicol-with-monolithic-child.html)
- [nested-oofs-in-relative-multicol.html](https://wpt.fyi/results/css/css-multicol/nested-oofs-in-relative-multicol.html "css/css-multicol/nested-oofs-in-relative-multicol.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/nested-oofs-in-relative-multicol.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/nested-oofs-in-relative-multicol.html)
- [nested-past-fragmentation-line.html](https://wpt.fyi/results/css/css-multicol/nested-past-fragmentation-line.html "css/css-multicol/nested-past-fragmentation-line.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/nested-past-fragmentation-line.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/nested-past-fragmentation-line.html)
- [nested-with-too-tall-line.html](https://wpt.fyi/results/css/css-multicol/nested-with-too-tall-line.html "css/css-multicol/nested-with-too-tall-line.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/nested-with-too-tall-line.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/nested-with-too-tall-line.html)
- [oof-nested-in-single-column.html](https://wpt.fyi/results/css/css-multicol/oof-nested-in-single-column.html "css/css-multicol/oof-nested-in-single-column.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/oof-nested-in-single-column.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/oof-nested-in-single-column.html)
- [nested-non-auto-inline-size-offset-top.html](https://wpt.fyi/results/css/css-multicol/nested-non-auto-inline-size-offset-top.html "css/css-multicol/nested-non-auto-inline-size-offset-top.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/nested-non-auto-inline-size-offset-top.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/nested-non-auto-inline-size-offset-top.html)
- [fixedpos-static-pos-with-viewport-cb-001.html](https://wpt.fyi/results/css/css-multicol/fixedpos-static-pos-with-viewport-cb-001.html "css/css-multicol/fixedpos-static-pos-with-viewport-cb-001.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/fixedpos-static-pos-with-viewport-cb-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/fixedpos-static-pos-with-viewport-cb-001.html)
- [fixedpos-static-pos-with-viewport-cb-002.html](https://wpt.fyi/results/css/css-multicol/fixedpos-static-pos-with-viewport-cb-002.html "css/css-multicol/fixedpos-static-pos-with-viewport-cb-002.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/fixedpos-static-pos-with-viewport-cb-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/fixedpos-static-pos-with-viewport-cb-002.html)
- [fixedpos-static-pos-with-viewport-cb-003.html](https://wpt.fyi/results/css/css-multicol/fixedpos-static-pos-with-viewport-cb-003.html "css/css-multicol/fixedpos-static-pos-with-viewport-cb-003.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/fixedpos-static-pos-with-viewport-cb-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/fixedpos-static-pos-with-viewport-cb-003.html)
- [multicol-height-block-child-001.xht](https://wpt.fyi/results/css/css-multicol/multicol-height-block-child-001.xht "css/css-multicol/multicol-height-block-child-001.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-height-block-child-001.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-height-block-child-001.xht)

 It is not possible to set properties/values on column
boxes. For example, the background of a certain column box cannot be set
and a column box has no concept of padding, margin or borders. Future
specifications may add additional functionality. For example, columns of
different widths and different backgrounds may be supported.

 Multicol containers with column heights larger than the
viewport may pose accessibility issues. See [Accessibility
Considerations](#a11y) for more details.

## 3. The Number and Width of Columns

Finding the number and width of columns is fundamental when laying out
multi-column content. These properties are used to set the number and
width of columns:

- [column-count](#propdef-column-count)
- [column-width](#propdef-column-width)

A third property, [columns](#propdef-columns), is a shorthand property which sets
both
[column-width](#propdef-column-width) and
[column-count](#propdef-column-count).

Other factors, such as explicit column breaks, content, and height
constraints, may influence the actual number and width of columns.

### 3.1. The Inline Size of Columns: the [column-width property]
Name:

[column-width]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

auto
[\|](https://drafts.csswg.org/css-values-4/#comb-one) [\<length
\[0,∞\]\>](https://drafts.csswg.org/css-values-4/#length-value)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

auto

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[block
containers](https://drafts.csswg.org/css-display-4/#block-container) except [table wrapper
boxes](https://drafts.csswg.org/css-tables-3/#table-wrapper-box)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

N/A

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

the keyword
[auto](#valdef-column-width-auto) or an absolute length

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value type

This property describes the width of columns in multicol containers.

[auto]
: means that the column width will be determined by other properties
 (e.g.,
 [column-count](#propdef-column-count), if it has a non-auto value).

[[\<length \[0,∞\]\>](https://drafts.csswg.org/css-values-4/#length-value)]
: describes the optimal column width. The actual column width may be
 wider (to fill the available space), or narrower (only if the
 available space is smaller than the specified column width).
 Negative values are not allowed. Used values will be clamped to a
 minimum of [1px].
 Tests
 - [zero-column-width-computed-style.html](https://wpt.fyi/results/css/css-multicol/zero-column-width-computed-style.html "css/css-multicol/zero-column-width-computed-style.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/zero-column-width-computed-style.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/zero-column-width-computed-style.html)
 - [zero-column-width-layout.html](https://wpt.fyi/results/css/css-multicol/zero-column-width-layout.html "css/css-multicol/zero-column-width-layout.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/zero-column-width-layout.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/zero-column-width-layout.html)

Tests

- [multicol-basic-003.html](https://wpt.fyi/results/css/css-multicol/multicol-basic-003.html "css/css-multicol/multicol-basic-003.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-basic-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-basic-003.html)
- [multicol-basic-008.xht](https://wpt.fyi/results/css/css-multicol/multicol-basic-008.xht "css/css-multicol/multicol-basic-008.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-basic-008.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-basic-008.xht)
- [multicol-reduce-000.xht](https://wpt.fyi/results/css/css-multicol/multicol-reduce-000.xht "css/css-multicol/multicol-reduce-000.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-reduce-000.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-reduce-000.xht)
- [multicol-width-001.xht](https://wpt.fyi/results/css/css-multicol/multicol-width-001.xht "css/css-multicol/multicol-width-001.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-width-001.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-width-001.xht)
- [multicol-width-002.xht](https://wpt.fyi/results/css/css-multicol/multicol-width-002.xht "css/css-multicol/multicol-width-002.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-width-002.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-width-002.xht)
- [multicol-width-003.xht](https://wpt.fyi/results/css/css-multicol/multicol-width-003.xht "css/css-multicol/multicol-width-003.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-width-003.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-width-003.xht)
- [multicol-width-005.html](https://wpt.fyi/results/css/css-multicol/multicol-width-005.html "css/css-multicol/multicol-width-005.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-width-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-width-005.html)
- [multicol-width-ch-001.html](https://wpt.fyi/results/css/css-multicol/multicol-width-ch-001.html "css/css-multicol/multicol-width-ch-001.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-width-ch-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-width-ch-001.html)
- [multicol-width-negative-001.xht](https://wpt.fyi/results/css/css-multicol/multicol-width-negative-001.xht "css/css-multicol/multicol-width-negative-001.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-width-negative-001.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-width-negative-001.xht)
- [multicol-width-invalid-001.xht](https://wpt.fyi/results/css/css-multicol/multicol-width-invalid-001.xht "css/css-multicol/multicol-width-invalid-001.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-width-invalid-001.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-width-invalid-001.xht)
- [multicol-width-large-001.xht](https://wpt.fyi/results/css/css-multicol/multicol-width-large-001.xht "css/css-multicol/multicol-width-large-001.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-width-large-001.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-width-large-001.xht)
- [multicol-width-large-002.xht](https://wpt.fyi/results/css/css-multicol/multicol-width-large-002.xht "css/css-multicol/multicol-width-large-002.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-width-large-002.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-width-large-002.xht)
- [multicol-inherit-003.xht](https://wpt.fyi/results/css/css-multicol/multicol-inherit-003.xht "css/css-multicol/multicol-inherit-003.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-inherit-003.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-inherit-003.xht)
- [column-width-computed.html](https://wpt.fyi/results/css/css-multicol/parsing/column-width-computed.html "css/css-multicol/parsing/column-width-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/parsing/column-width-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/parsing/column-width-computed.html)
- [column-width-invalid.html](https://wpt.fyi/results/css/css-multicol/parsing/column-width-invalid.html "css/css-multicol/parsing/column-width-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/parsing/column-width-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/parsing/column-width-invalid.html)
- [column-width-valid.html](https://wpt.fyi/results/css/css-multicol/parsing/column-width-valid.html "css/css-multicol/parsing/column-width-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/parsing/column-width-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/parsing/column-width-valid.html)
- [multicol-width-small-001.xht](https://wpt.fyi/results/css/css-multicol/multicol-width-small-001.xht "css/css-multicol/multicol-width-small-001.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-width-small-001.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-width-small-001.xht)

For example, consider this style
sheet:

``` highlight
div {
 width: 100px;
 column-width: 45px;
 column-gap: 0;
 column-rule: none;
}
```

There is room for two [45px] wide columns inside the [100px]
wide element. In order to fill the available space the actual column
width will be increased to [50px].

Also, consider this style sheet:

``` highlight
div {
 width: 40px;
 column-width: 45px;
 column-gap: 0;
 column-rule: none;
}
```

The available space is smaller than the specified column width and the
actual column width will therefore be decreased.

To ensure that
[column-width](#propdef-column-width) can be used with vertical text,
column width means the length of the line boxes inside the columns.

 The reason for making
[column-width](#propdef-column-width) somewhat flexible is to achieve
scalable designs that can fit many screen sizes. To set an exact column
width, the column gap and the width of the multicol container (assuming
horizontal text) must also be specified.

### 3.2. The Number of Columns: the [column-count property]
Name:

[column-count]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

auto
[\|](https://drafts.csswg.org/css-values-4/#comb-one) [\<integer
\[1,∞\]\>](https://drafts.csswg.org/css-values-4/#integer-value)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

auto

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[block
containers](https://drafts.csswg.org/css-display-4/#block-container) except [table wrapper
boxes](https://drafts.csswg.org/css-tables-3/#table-wrapper-box)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

N/A

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

specified value

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value

This property describes the number of columns of a [multicol
container](#multi-column-container).

[auto]
: means that the number of columns will be determined by other
 properties (e.g.,
 [column-width](#propdef-column-width), if it has a non-auto value).

[[\<integer \[1,∞\]\>](https://drafts.csswg.org/css-values-4/#integer-value)]
: describes the optimal number of columns into which the content of
 the element will be flowed. Values must be greater than 0. If both
 [column-width](#propdef-column-width) and
 [column-count](#propdef-column-count) have non-auto values, the
 integer value describes the maximum number of columns.

Tests

- [multicol-count-001.xht](https://wpt.fyi/results/css/css-multicol/multicol-count-001.xht "css/css-multicol/multicol-count-001.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-count-001.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-count-001.xht)
- [multicol-count-002.xht](https://wpt.fyi/results/css/css-multicol/multicol-count-002.xht "css/css-multicol/multicol-count-002.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-count-002.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-count-002.xht)
- [multicol-basic-006.xht](https://wpt.fyi/results/css/css-multicol/multicol-basic-006.xht "css/css-multicol/multicol-basic-006.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-basic-006.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-basic-006.xht)
- [multicol-width-count-001.xht](https://wpt.fyi/results/css/css-multicol/multicol-width-count-001.xht "css/css-multicol/multicol-width-count-001.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-width-count-001.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-width-count-001.xht)
- [multicol-width-count-002.xht](https://wpt.fyi/results/css/css-multicol/multicol-width-count-002.xht "css/css-multicol/multicol-width-count-002.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-width-count-002.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-width-count-002.xht)
- [multicol-columns-toolong-001.xht](https://wpt.fyi/results/css/css-multicol/multicol-columns-toolong-001.xht "css/css-multicol/multicol-columns-toolong-001.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-columns-toolong-001.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-columns-toolong-001.xht)
- [multicol-count-negative-001.xht](https://wpt.fyi/results/css/css-multicol/multicol-count-negative-001.xht "css/css-multicol/multicol-count-negative-001.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-count-negative-001.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-count-negative-001.xht)
- [multicol-count-negative-002.xht](https://wpt.fyi/results/css/css-multicol/multicol-count-negative-002.xht "css/css-multicol/multicol-count-negative-002.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-count-negative-002.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-count-negative-002.xht)
- [multicol-count-non-integer-001.xht](https://wpt.fyi/results/css/css-multicol/multicol-count-non-integer-001.xht "css/css-multicol/multicol-count-non-integer-001.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-count-non-integer-001.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-count-non-integer-001.xht)
- [multicol-count-non-integer-002.xht](https://wpt.fyi/results/css/css-multicol/multicol-count-non-integer-002.xht "css/css-multicol/multicol-count-non-integer-002.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-count-non-integer-002.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-count-non-integer-002.xht)
- [multicol-count-non-integer-003.xht](https://wpt.fyi/results/css/css-multicol/multicol-count-non-integer-003.xht "css/css-multicol/multicol-count-non-integer-003.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-count-non-integer-003.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-count-non-integer-003.xht)
- [multicol-inherit-001.xht](https://wpt.fyi/results/css/css-multicol/multicol-inherit-001.xht "css/css-multicol/multicol-inherit-001.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-inherit-001.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-inherit-001.xht)
- [multicol-inherit-002.xht](https://wpt.fyi/results/css/css-multicol/multicol-inherit-002.xht "css/css-multicol/multicol-inherit-002.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-inherit-002.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-inherit-002.xht)
- [column-count-invalid.html](https://wpt.fyi/results/css/css-multicol/parsing/column-count-invalid.html "css/css-multicol/parsing/column-count-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/parsing/column-count-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/parsing/column-count-invalid.html)
- [column-count-valid.html](https://wpt.fyi/results/css/css-multicol/parsing/column-count-valid.html "css/css-multicol/parsing/column-count-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/parsing/column-count-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/parsing/column-count-valid.html)
- [column-count-computed.html](https://wpt.fyi/results/css/css-multicol/parsing/column-count-computed.html "css/css-multicol/parsing/column-count-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/parsing/column-count-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/parsing/column-count-computed.html)
- [column-count-interpolation.html](https://wpt.fyi/results/css/css-multicol/animation/column-count-interpolation.html "css/css-multicol/animation/column-count-interpolation.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/animation/column-count-interpolation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/animation/column-count-interpolation.html)
- [large-actual-column-count.html](https://wpt.fyi/results/css/css-multicol/large-actual-column-count.html "css/css-multicol/large-actual-column-count.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/large-actual-column-count.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/large-actual-column-count.html)
- [with-custom-layout-on-same-element.https.html](https://wpt.fyi/results/css/css-multicol/with-custom-layout-on-same-element.https.html "css/css-multicol/with-custom-layout-on-same-element.https.html")
 [[(live
 test)]](https://wpt.live/css/css-multicol/with-custom-layout-on-same-element.https.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/with-custom-layout-on-same-element.https.html)

Example:

``` highlight
body { column-count: 3 }
```

### 3.3. The [column-width and [column-count](#propdef-column-count) Shorthand: The [columns](#propdef-columns) Property]
Name:

[columns]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<\'column-width\'\>](#propdef-column-width)
[\|\|](https://drafts.csswg.org/css-values-4/#comb-any)
[\<\'column-count\'\>](#propdef-column-count)

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

This is a shorthand property for setting
[column-width](#propdef-column-width) and
[column-count](#propdef-column-count). Omitted values are set to their
initial values.

Here are some valid declarations using
the [columns](#propdef-columns) property:

``` highlight
columns: 12em; /* column-width: 12em; column-count: auto */
columns: auto 12em; /* column-width: 12em; column-count: auto */
columns: 2; /* column-width: auto; column-count: 2 */
columns: 2 auto; /* column-width: auto; column-count: 2 */
columns: auto; /* column-width: auto; column-count: auto */
columns: auto auto; /* column-width: auto; column-count: auto */
```

- [columns-interpolation.html](https://wpt.fyi/results/css/css-multicol/animation/columns-interpolation.html "css/css-multicol/animation/columns-interpolation.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/animation/columns-interpolation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/animation/columns-interpolation.html)
- [multicol-columns-001.xht](https://wpt.fyi/results/css/css-multicol/multicol-columns-001.xht "css/css-multicol/multicol-columns-001.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-columns-001.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-columns-001.xht)
- [multicol-columns-002.xht](https://wpt.fyi/results/css/css-multicol/multicol-columns-002.xht "css/css-multicol/multicol-columns-002.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-columns-002.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-columns-002.xht)
- [multicol-columns-003.xht](https://wpt.fyi/results/css/css-multicol/multicol-columns-003.xht "css/css-multicol/multicol-columns-003.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-columns-003.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-columns-003.xht)
- [multicol-columns-004.xht](https://wpt.fyi/results/css/css-multicol/multicol-columns-004.xht "css/css-multicol/multicol-columns-004.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-columns-004.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-columns-004.xht)
- [multicol-columns-005.xht](https://wpt.fyi/results/css/css-multicol/multicol-columns-005.xht "css/css-multicol/multicol-columns-005.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-columns-005.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-columns-005.xht)
- [multicol-columns-006.xht](https://wpt.fyi/results/css/css-multicol/multicol-columns-006.xht "css/css-multicol/multicol-columns-006.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-columns-006.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-columns-006.xht)
- [multicol-columns-007.xht](https://wpt.fyi/results/css/css-multicol/multicol-columns-007.xht "css/css-multicol/multicol-columns-007.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-columns-007.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-columns-007.xht)
- [multicol-columns-invalid-001.xht](https://wpt.fyi/results/css/css-multicol/multicol-columns-invalid-001.xht "css/css-multicol/multicol-columns-invalid-001.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-columns-invalid-001.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-columns-invalid-001.xht)
- [multicol-columns-invalid-002.xht](https://wpt.fyi/results/css/css-multicol/multicol-columns-invalid-002.xht "css/css-multicol/multicol-columns-invalid-002.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-columns-invalid-002.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-columns-invalid-002.xht)
- [multicol-basic-001.html](https://wpt.fyi/results/css/css-multicol/multicol-basic-001.html "css/css-multicol/multicol-basic-001.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-basic-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-basic-001.html)
- [multicol-basic-003.html](https://wpt.fyi/results/css/css-multicol/multicol-basic-003.html "css/css-multicol/multicol-basic-003.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-basic-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-basic-003.html)
- [multicol-basic-005.xht](https://wpt.fyi/results/css/css-multicol/multicol-basic-005.xht "css/css-multicol/multicol-basic-005.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-basic-005.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-basic-005.xht)
- [multicol-basic-007.xht](https://wpt.fyi/results/css/css-multicol/multicol-basic-007.xht "css/css-multicol/multicol-basic-007.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-basic-007.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-basic-007.xht)
- [columns-computed.html](https://wpt.fyi/results/css/css-multicol/parsing/columns-computed.html "css/css-multicol/parsing/columns-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/parsing/columns-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/parsing/columns-computed.html)
- [columns-invalid.html](https://wpt.fyi/results/css/css-multicol/parsing/columns-invalid.html "css/css-multicol/parsing/columns-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/parsing/columns-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/parsing/columns-invalid.html)
- [columns-valid.html](https://wpt.fyi/results/css/css-multicol/parsing/columns-valid.html "css/css-multicol/parsing/columns-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/parsing/columns-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/parsing/columns-valid.html)

### 3.4. The Pseudo-algorithm

The pseudo-algorithm below determines the used values for
[column-count](#propdef-column-count) (N) and
[column-width](#propdef-column-width) (W). There is one other variable in
the pseudo-algorithm: U is the used width of the multi-column container.

 The used width U of the multi-column container can
depend on the element's contents, in which case it also depends on the
computed values of the
[column-count](#propdef-column-count) and
[column-width](#propdef-column-width) properties. This specification does
not define how U is calculated. Another module (probably the Basic Box
Model
[\[CSS3BOX\]](#biblio-css3box "CSS Box Model Module Level 3")
or the Box Sizing Module
[\[CSS3-SIZING\]](#biblio-css3-sizing "CSS Box Sizing Module Level 3"))
is expected to define this.

Tests

- [intrinsic-size-001.html](https://wpt.fyi/results/css/css-multicol/intrinsic-size-001.html "css/css-multicol/intrinsic-size-001.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/intrinsic-size-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/intrinsic-size-001.html)
- [intrinsic-size-002.html](https://wpt.fyi/results/css/css-multicol/intrinsic-size-002.html "css/css-multicol/intrinsic-size-002.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/intrinsic-size-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/intrinsic-size-002.html)
- [intrinsic-size-003.html](https://wpt.fyi/results/css/css-multicol/intrinsic-size-003.html "css/css-multicol/intrinsic-size-003.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/intrinsic-size-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/intrinsic-size-003.html)
- [intrinsic-size-004.html](https://wpt.fyi/results/css/css-multicol/intrinsic-size-004.html "css/css-multicol/intrinsic-size-004.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/intrinsic-size-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/intrinsic-size-004.html)
- [intrinsic-size-005.html](https://wpt.fyi/results/css/css-multicol/intrinsic-size-005.html "css/css-multicol/intrinsic-size-005.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/intrinsic-size-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/intrinsic-size-005.html)
- [as-column-flex-item.html](https://wpt.fyi/results/css/css-multicol/as-column-flex-item.html "css/css-multicol/as-column-flex-item.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/as-column-flex-item.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/as-column-flex-item.html)
- [intrinsic-width-change-column-count.html](https://wpt.fyi/results/css/css-multicol/intrinsic-width-change-column-count.html "css/css-multicol/intrinsic-width-change-column-count.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/intrinsic-width-change-column-count.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/intrinsic-width-change-column-count.html)

The `floor(X)` function returns the largest integer Y ≤ X.

 (01) if ((column-width = auto) and (column-count = auto)) then
 (02) exit; /* not a multicol container */
 (03) if column-width = auto then
 (04) N := column-count
 (05) else if column-count = auto then
 (06) N := max(1,
 (07) floor((U + column-gap)/(column-width + column-gap)))
 (08) else
 (09) N := min(column-count, max(1,
 (10) floor((U + column-gap)/(column-width + column-gap))))

And:

 (11) W := max(0, (U + column-gap)/N - column-gap)

For the purpose of finding the number of auto-repeated columns, the UA
must floor the column size to a UA-specified value to avoid division by
zero. It is suggested that this floor be 1px or less.

In fragmented contexts such as in [paged
media](https://drafts.csswg.org/mediaqueries-5/#paged-media), user agents may perform this calculation on a
per-fragment basis.

The used value for
[column-count](#propdef-column-count) is calculated without regard for
explicit column breaks or constrained column heights, while the actual
value takes these into consideration.

Tests

- [column-count-used-001.html](https://wpt.fyi/results/css/css-multicol/column-count-used-001.html "css/css-multicol/column-count-used-001.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/column-count-used-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/column-count-used-001.html)

In this example, the actual
column-count is higher than the used column-count due to explicit column
breaks:

``` highlight
div {
 width: 40em;
 columns: 20em;
 column-gap: 0;
}

p {
 break-after: column;
}
```

``` highlight
<div>
 <p>one
 <p>two
 <p>three
</div>
```

![The computed column-count is auto, the used column-count is 2 and the
actual column-count is
3.](images/column-count-higher-than-used-count.svg){a}

The actual column-count may be lower
than the used column-count. Consider this example:

``` highlight
div {
 width: 80em;
 height: 10em;
 columns: 20em;
 column-gap: 0;
 column-fill: auto;
}
```

``` highlight
<div>foo</div>
```

The computed column-count is auto, the used column-count is 4, and the
actual column-count is 1.

### 3.5. Stacking Context

All column boxes in a multi-column container are in the same stacking
context and the drawing order of their contents is as specified in CSS
2.1. Column boxes do not establish new stacking contexts.

Tests

- [multicol-rule-stacking-001.xht](https://wpt.fyi/results/css/css-multicol/multicol-rule-stacking-001.xht "css/css-multicol/multicol-rule-stacking-001.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-rule-stacking-001.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-rule-stacking-001.xht)

## 4. Column Gaps and Rules

Column gaps and rules are placed between columns in the same [multicol
container](#multi-column-container). The length of the column gaps and column rules is
equal to the column height. Column gaps take up space. That is, column
gaps will push apart content in adjacent columns (within the same
[multicol container]).

Tests

- [column-rule-001.html](https://wpt.fyi/results/css/css-multicol/column-rule-001.html "css/css-multicol/column-rule-001.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/column-rule-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/column-rule-001.html)
- [column-rule-002.html](https://wpt.fyi/results/css/css-multicol/column-rule-002.html "css/css-multicol/column-rule-002.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/column-rule-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/column-rule-002.html)
- [multicol-height-001.xht](https://wpt.fyi/results/css/css-multicol/multicol-height-001.xht "css/css-multicol/multicol-height-001.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-height-001.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-height-001.xht)
- [multicol-nested-column-rule-001.xht](https://wpt.fyi/results/css/css-multicol/multicol-nested-column-rule-001.xht "css/css-multicol/multicol-nested-column-rule-001.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-nested-column-rule-001.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-nested-column-rule-001.xht)
- [multicol-nested-column-rule-002.html](https://wpt.fyi/results/css/css-multicol/multicol-nested-column-rule-002.html "css/css-multicol/multicol-nested-column-rule-002.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-nested-column-rule-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-nested-column-rule-002.html)
- [multicol-nested-column-rule-003.html](https://wpt.fyi/results/css/css-multicol/multicol-nested-column-rule-003.html "css/css-multicol/multicol-nested-column-rule-003.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-nested-column-rule-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-nested-column-rule-003.html)
- [multicol-rule-nested-balancing-001.html](https://wpt.fyi/results/css/css-multicol/multicol-rule-nested-balancing-001.html "css/css-multicol/multicol-rule-nested-balancing-001.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-rule-nested-balancing-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-rule-nested-balancing-001.html)
- [multicol-rule-nested-balancing-002.html](https://wpt.fyi/results/css/css-multicol/multicol-rule-nested-balancing-002.html "css/css-multicol/multicol-rule-nested-balancing-002.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-rule-nested-balancing-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-rule-nested-balancing-002.html)
- [multicol-rule-nested-balancing-003.html](https://wpt.fyi/results/css/css-multicol/multicol-rule-nested-balancing-003.html "css/css-multicol/multicol-rule-nested-balancing-003.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-rule-nested-balancing-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-rule-nested-balancing-003.html)
- [multicol-rule-nested-balancing-004.html](https://wpt.fyi/results/css/css-multicol/multicol-rule-nested-balancing-004.html "css/css-multicol/multicol-rule-nested-balancing-004.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-rule-nested-balancing-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-rule-nested-balancing-004.html)

A [column rule](#column-rule) is
drawn in the middle of the [column
gap](#column-gap) with the
endpoints at opposing content edges of the [multicol
container](#multi-column-container). Column rules do not take up space. That is, the
presence or thickness of a [column rule] will not
alter the placement of anything else. If a [column
rule] is wider than its gap, the adjacent column
boxes will overlap the rule, and the rule may possibly extend outside
the box of the [multicol container].
Column rules are painted just above the border of the [multicol
container]. For scrollable multicol
containers, note that while the border and background of the [multicol
container] obviously aren't scrolled,
the rules need to scroll along with the columns. Column rules are only
drawn between two columns that both have content.

Tests

Basic column rule tests

- [multicol-rule-003.xht](https://wpt.fyi/results/css/css-multicol/multicol-rule-003.xht "css/css-multicol/multicol-rule-003.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-rule-003.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-rule-003.xht)
- [multicol-rule-004.xht](https://wpt.fyi/results/css/css-multicol/multicol-rule-004.xht "css/css-multicol/multicol-rule-004.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-rule-004.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-rule-004.xht)
- [multicol-rule-fraction-002.xht](https://wpt.fyi/results/css/css-multicol/multicol-rule-fraction-002.xht "css/css-multicol/multicol-rule-fraction-002.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-rule-fraction-002.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-rule-fraction-002.xht)

------------------------------------------------------------------------

If a column rule is wider than its gap, adjacent boxes overlap.

- [multicol-rule-001.xht](https://wpt.fyi/results/css/css-multicol/multicol-rule-001.xht "css/css-multicol/multicol-rule-001.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-rule-001.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-rule-001.xht)
- [multicol-rule-large-001.xht](https://wpt.fyi/results/css/css-multicol/multicol-rule-large-001.xht "css/css-multicol/multicol-rule-large-001.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-rule-large-001.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-rule-large-001.xht)
- [multicol-rule-large-002.xht (visual test)
 ][[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-rule-large-002.xht)

------------------------------------------------------------------------

Column rules are only drawn between two columns that have content.

- [multicol-count-computed-003.xht](https://wpt.fyi/results/css/css-multicol/multicol-count-computed-003.xht "css/css-multicol/multicol-count-computed-003.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-count-computed-003.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-count-computed-003.xht)
- [multicol-count-computed-005.xht](https://wpt.fyi/results/css/css-multicol/multicol-count-computed-005.xht "css/css-multicol/multicol-count-computed-005.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-count-computed-005.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-count-computed-005.xht)
- [broken-column-rule-1.html](https://wpt.fyi/results/css/css-multicol/broken-column-rule-1.html "css/css-multicol/broken-column-rule-1.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/broken-column-rule-1.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/broken-column-rule-1.html)

------------------------------------------------------------------------

Tests for behavior of backgrounds and column rules.

- [multicol-breaking-000.html](https://wpt.fyi/results/css/css-multicol/multicol-breaking-000.html "css/css-multicol/multicol-breaking-000.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-breaking-000.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-breaking-000.html)
- [multicol-breaking-001.html](https://wpt.fyi/results/css/css-multicol/multicol-breaking-001.html "css/css-multicol/multicol-breaking-001.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-breaking-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-breaking-001.html)
- [multicol-breaking-002.html](https://wpt.fyi/results/css/css-multicol/multicol-breaking-002.html "css/css-multicol/multicol-breaking-002.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-breaking-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-breaking-002.html)
- [multicol-breaking-003.html](https://wpt.fyi/results/css/css-multicol/multicol-breaking-003.html "css/css-multicol/multicol-breaking-003.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-breaking-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-breaking-003.html)
- [multicol-breaking-004.html](https://wpt.fyi/results/css/css-multicol/multicol-breaking-004.html "css/css-multicol/multicol-breaking-004.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-breaking-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-breaking-004.html)
- [multicol-breaking-005.html](https://wpt.fyi/results/css/css-multicol/multicol-breaking-005.html "css/css-multicol/multicol-breaking-005.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-breaking-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-breaking-005.html)
- [multicol-breaking-006.html](https://wpt.fyi/results/css/css-multicol/multicol-breaking-006.html "css/css-multicol/multicol-breaking-006.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-breaking-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-breaking-006.html)
- [multicol-breaking-nobackground-000.html](https://wpt.fyi/results/css/css-multicol/multicol-breaking-nobackground-000.html "css/css-multicol/multicol-breaking-nobackground-000.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-breaking-nobackground-000.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-breaking-nobackground-000.html)
- [multicol-breaking-nobackground-001.html](https://wpt.fyi/results/css/css-multicol/multicol-breaking-nobackground-001.html "css/css-multicol/multicol-breaking-nobackground-001.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-breaking-nobackground-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-breaking-nobackground-001.html)
- [multicol-breaking-nobackground-002.html](https://wpt.fyi/results/css/css-multicol/multicol-breaking-nobackground-002.html "css/css-multicol/multicol-breaking-nobackground-002.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-breaking-nobackground-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-breaking-nobackground-002.html)
- [multicol-breaking-nobackground-003.html](https://wpt.fyi/results/css/css-multicol/multicol-breaking-nobackground-003.html "css/css-multicol/multicol-breaking-nobackground-003.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-breaking-nobackground-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-breaking-nobackground-003.html)
- [multicol-breaking-nobackground-004.html](https://wpt.fyi/results/css/css-multicol/multicol-breaking-nobackground-004.html "css/css-multicol/multicol-breaking-nobackground-004.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-breaking-nobackground-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-breaking-nobackground-004.html)
- [multicol-breaking-nobackground-005.html](https://wpt.fyi/results/css/css-multicol/multicol-breaking-nobackground-005.html "css/css-multicol/multicol-breaking-nobackground-005.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-breaking-nobackground-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-breaking-nobackground-005.html)

------------------------------------------------------------------------

### [4.1. ][Gutters Between Columns: the [column-gap](https://drafts.csswg.org/css-gaps-1/#propdef-column-gap) property]
The
[column-gap](https://drafts.csswg.org/css-gaps-1/#propdef-column-gap) property is defined in
[\[CSS-GAPS-1\]](#biblio-css-gaps-1 "CSS Gaps Module Level 1").

In a [multi-column formatting
context](#multi-column-formatting-context) the used value of
[normal](https://drafts.csswg.org/css-gaps-1/#valdef-row-gap-normal) for the
[column-gap](https://drafts.csswg.org/css-gaps-1/#propdef-column-gap) property is [1em]. This
ensures columns are readable when the initial values are used. If there
is a column rule between columns, it will appear in the middle of the
gap.

Tests

- [multicol-gap-fraction-001.xht](https://wpt.fyi/results/css/css-multicol/multicol-gap-fraction-001.xht "css/css-multicol/multicol-gap-fraction-001.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-gap-fraction-001.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-gap-fraction-001.xht)
- [multicol-gap-fraction-002.html](https://wpt.fyi/results/css/css-multicol/multicol-gap-fraction-002.html "css/css-multicol/multicol-gap-fraction-002.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-gap-fraction-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-gap-fraction-002.html)
- [multicol-gap-large-001.xht](https://wpt.fyi/results/css/css-multicol/multicol-gap-large-001.xht "css/css-multicol/multicol-gap-large-001.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-gap-large-001.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-gap-large-001.xht)
- [multicol-gap-large-002.xht](https://wpt.fyi/results/css/css-multicol/multicol-gap-large-002.xht "css/css-multicol/multicol-gap-large-002.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-gap-large-002.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-gap-large-002.xht)
- [multicol-gap-negative-001.xht](https://wpt.fyi/results/css/css-multicol/multicol-gap-negative-001.xht "css/css-multicol/multicol-gap-negative-001.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-gap-negative-001.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-gap-negative-001.xht)
- [multicol-gap-000.xht](https://wpt.fyi/results/css/css-multicol/multicol-gap-000.xht "css/css-multicol/multicol-gap-000.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-gap-000.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-gap-000.xht)
- [multicol-gap-002.xht](https://wpt.fyi/results/css/css-multicol/multicol-gap-002.xht "css/css-multicol/multicol-gap-002.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-gap-002.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-gap-002.xht)
- [multicol-gap-percentage-001.html](https://wpt.fyi/results/css/css-multicol/multicol-gap-percentage-001.html "css/css-multicol/multicol-gap-percentage-001.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-gap-percentage-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-gap-percentage-001.html)
- [multicol-gap-001.xht](https://wpt.fyi/results/css/css-multicol/multicol-gap-001.xht "css/css-multicol/multicol-gap-001.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-gap-001.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-gap-001.xht)
- [multicol-gap-003.xht](https://wpt.fyi/results/css/css-multicol/multicol-gap-003.xht "css/css-multicol/multicol-gap-003.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-gap-003.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-gap-003.xht)

Tests that the gap is animatable.

- [multicol-gap-animation-001.html](https://wpt.fyi/results/css/css-multicol/multicol-gap-animation-001.html "css/css-multicol/multicol-gap-animation-001.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-gap-animation-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-gap-animation-001.html)
- [multicol-gap-animation-002.html](https://wpt.fyi/results/css/css-multicol/multicol-gap-animation-002.html "css/css-multicol/multicol-gap-animation-002.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-gap-animation-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-gap-animation-002.html)
- [multicol-gap-animation-003.html](https://wpt.fyi/results/css/css-multicol/multicol-gap-animation-003.html "css/css-multicol/multicol-gap-animation-003.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-gap-animation-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-gap-animation-003.html)

------------------------------------------------------------------------

### 4.2. The Color of Column Rules: the [column-rule-color property]
Name:

[column-rule-color]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<color\>](https://drafts.csswg.org/css-color-5/#typedef-color)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

currentcolor

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

multicol containers

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

N/A

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

computed color

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value type

[[\<color\>](https://drafts.csswg.org/css-color-5/#typedef-color)]
: Specifies the color of the [column
 rule](#column-rule).

Tests

- [multicol-rule-color-001.xht](https://wpt.fyi/results/css/css-multicol/multicol-rule-color-001.xht "css/css-multicol/multicol-rule-color-001.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-rule-color-001.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-rule-color-001.xht)
- [multicol-rule-color-inherit-001.xht](https://wpt.fyi/results/css/css-multicol/multicol-rule-color-inherit-001.xht "css/css-multicol/multicol-rule-color-inherit-001.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-rule-color-inherit-001.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-rule-color-inherit-001.xht)
- [multicol-rule-color-inherit-002.xht](https://wpt.fyi/results/css/css-multicol/multicol-rule-color-inherit-002.xht "css/css-multicol/multicol-rule-color-inherit-002.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-rule-color-inherit-002.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-rule-color-inherit-002.xht)
- [column-rule-color-computed.html](https://wpt.fyi/results/css/css-multicol/parsing/column-rule-color-computed.html "css/css-multicol/parsing/column-rule-color-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/parsing/column-rule-color-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/parsing/column-rule-color-computed.html)
- [column-rule-color-valid.html](https://wpt.fyi/results/css/css-multicol/parsing/column-rule-color-valid.html "css/css-multicol/parsing/column-rule-color-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/parsing/column-rule-color-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/parsing/column-rule-color-valid.html)
- [column-rule-color-invalid.html](https://wpt.fyi/results/css/css-multicol/parsing/column-rule-color-invalid.html "css/css-multicol/parsing/column-rule-color-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/parsing/column-rule-color-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/parsing/column-rule-color-invalid.html)
- [column-rule-color-interpolation.html](https://wpt.fyi/results/css/css-multicol/animation/column-rule-color-interpolation.html "css/css-multicol/animation/column-rule-color-interpolation.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/animation/column-rule-color-interpolation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/animation/column-rule-color-interpolation.html)

### 4.3. The Style Of Column Rules: the [column-rule-style property]
Name:

[column-rule-style]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<line-style\>](https://drafts.csswg.org/css-backgrounds-3/#typedef-line-style)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

none

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

multicol containers

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

The
[column-rule-style](#propdef-column-rule-style) property sets the style of the rule
between columns of an element. The
[\<line-style\>](https://drafts.csswg.org/css-backgrounds-3/#typedef-line-style) values are interpreted as in the
[collapsing border
model](https://www.w3.org/TR/CSS2/tables.html#collapsing-borders).

Tests

- [column-rule-style-computed.html](https://wpt.fyi/results/css/css-multicol/parsing/column-rule-style-computed.html "css/css-multicol/parsing/column-rule-style-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/parsing/column-rule-style-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/parsing/column-rule-style-computed.html)
- [column-rule-style-valid.html](https://wpt.fyi/results/css/css-multicol/parsing/column-rule-style-valid.html "css/css-multicol/parsing/column-rule-style-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/parsing/column-rule-style-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/parsing/column-rule-style-valid.html)
- [column-rule-style-invalid.html](https://wpt.fyi/results/css/css-multicol/parsing/column-rule-style-invalid.html "css/css-multicol/parsing/column-rule-style-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/parsing/column-rule-style-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/parsing/column-rule-style-invalid.html)

The
[none](https://drafts.csswg.org/css-backgrounds-3/#valdef-line-style-none) and
[hidden](https://drafts.csswg.org/css-backgrounds-3/#valdef-line-style-hidden) values force the used value of
[column-rule-width](#propdef-column-rule-width) to be [0].

### 4.4. The Width Of Column Rules: the [column-rule-width property]
Name:

[column-rule-width]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<line-width\>](https://drafts.csswg.org/css-backgrounds-3/#typedef-line-width)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

medium

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

multicol containers

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

N/A

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

absolute length, [snapped as a border
width](https://drafts.csswg.org/css-values-4/#snap-as-a-line-width)

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value type

This property sets the width of the rule between columns. Negative
values are not allowed.

Tests

- [multicol-rule-fraction-001.xht](https://wpt.fyi/results/css/css-multicol/multicol-rule-fraction-001.xht "css/css-multicol/multicol-rule-fraction-001.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-rule-fraction-001.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-rule-fraction-001.xht)
- [multicol-rule-fraction-003.xht](https://wpt.fyi/results/css/css-multicol/multicol-rule-fraction-003.xht "css/css-multicol/multicol-rule-fraction-003.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-rule-fraction-003.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-rule-fraction-003.xht)
- [multicol-rule-px-001.xht](https://wpt.fyi/results/css/css-multicol/multicol-rule-px-001.xht "css/css-multicol/multicol-rule-px-001.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-rule-px-001.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-rule-px-001.xht)
- [multicol-rule-percent-001.xht](https://wpt.fyi/results/css/css-multicol/multicol-rule-percent-001.xht "css/css-multicol/multicol-rule-percent-001.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-rule-percent-001.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-rule-percent-001.xht)
- [subpixel-column-rule-width.tentative.html](https://wpt.fyi/results/css/css-multicol/subpixel-column-rule-width.tentative.html "css/css-multicol/subpixel-column-rule-width.tentative.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/subpixel-column-rule-width.tentative.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/subpixel-column-rule-width.tentative.html)
- [column-rule-width-computed.html](https://wpt.fyi/results/css/css-multicol/parsing/column-rule-width-computed.html "css/css-multicol/parsing/column-rule-width-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/parsing/column-rule-width-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/parsing/column-rule-width-computed.html)
- [column-rule-width-invalid.html](https://wpt.fyi/results/css/css-multicol/parsing/column-rule-width-invalid.html "css/css-multicol/parsing/column-rule-width-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/parsing/column-rule-width-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/parsing/column-rule-width-invalid.html)
- [column-rule-width-valid.html](https://wpt.fyi/results/css/css-multicol/parsing/column-rule-width-valid.html "css/css-multicol/parsing/column-rule-width-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/parsing/column-rule-width-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/parsing/column-rule-width-valid.html)
- [column-rule-width-interpolation.html](https://wpt.fyi/results/css/css-multicol/animation/column-rule-width-interpolation.html "css/css-multicol/animation/column-rule-width-interpolation.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/animation/column-rule-width-interpolation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/animation/column-rule-width-interpolation.html)

### 4.5. Column Rule Shorthand: the [column-rule property]
Name:

[column-rule]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<\'column-rule-width\'\>](#propdef-column-rule-width)
[\|\|](https://drafts.csswg.org/css-values-4/#comb-any)
[\<\'column-rule-style\'\>](#propdef-column-rule-style) [\|\|]
[\<\'column-rule-color\'\>](#propdef-column-rule-color)

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

This property is a shorthand for setting
[column-rule-width](#propdef-column-rule-width),
[column-rule-style](#propdef-column-rule-style), and
[column-rule-color](#propdef-column-rule-color) at the same place in the style
sheet. Omitted values are set to their initial values.

Tests

- [multicol-shorthand-001.xht](https://wpt.fyi/results/css/css-multicol/multicol-shorthand-001.xht "css/css-multicol/multicol-shorthand-001.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-shorthand-001.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-shorthand-001.xht)
- [multicol-rule-shorthand-001.xht](https://wpt.fyi/results/css/css-multicol/multicol-rule-shorthand-001.xht "css/css-multicol/multicol-rule-shorthand-001.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-rule-shorthand-001.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-rule-shorthand-001.xht)
- [multicol-rule-shorthand-2.xht](https://wpt.fyi/results/css/css-multicol/multicol-rule-shorthand-2.xht "css/css-multicol/multicol-rule-shorthand-2.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-rule-shorthand-2.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-rule-shorthand-2.xht)
- [multicol-rule-000.xht](https://wpt.fyi/results/css/css-multicol/multicol-rule-000.xht "css/css-multicol/multicol-rule-000.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-rule-000.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-rule-000.xht)
- [multicol-rule-002.xht](https://wpt.fyi/results/css/css-multicol/multicol-rule-002.xht "css/css-multicol/multicol-rule-002.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-rule-002.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-rule-002.xht)
- [multicol-rule-dashed-000.xht](https://wpt.fyi/results/css/css-multicol/multicol-rule-dashed-000.xht "css/css-multicol/multicol-rule-dashed-000.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-rule-dashed-000.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-rule-dashed-000.xht)
- [multicol-rule-dotted-000.xht](https://wpt.fyi/results/css/css-multicol/multicol-rule-dotted-000.xht "css/css-multicol/multicol-rule-dotted-000.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-rule-dotted-000.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-rule-dotted-000.xht)
- [multicol-rule-double-000.xht](https://wpt.fyi/results/css/css-multicol/multicol-rule-double-000.xht "css/css-multicol/multicol-rule-double-000.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-rule-double-000.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-rule-double-000.xht)
- [multicol-rule-outset-000.xht](https://wpt.fyi/results/css/css-multicol/multicol-rule-outset-000.xht "css/css-multicol/multicol-rule-outset-000.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-rule-outset-000.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-rule-outset-000.xht)
- [multicol-rule-none-000.xht](https://wpt.fyi/results/css/css-multicol/multicol-rule-none-000.xht "css/css-multicol/multicol-rule-none-000.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-rule-none-000.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-rule-none-000.xht)
- [multicol-rule-hidden-000.xht](https://wpt.fyi/results/css/css-multicol/multicol-rule-hidden-000.xht "css/css-multicol/multicol-rule-hidden-000.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-rule-hidden-000.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-rule-hidden-000.xht)
- [multicol-rule-inset-000.xht](https://wpt.fyi/results/css/css-multicol/multicol-rule-inset-000.xht "css/css-multicol/multicol-rule-inset-000.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-rule-inset-000.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-rule-inset-000.xht)
- [multicol-rule-groove-000.xht](https://wpt.fyi/results/css/css-multicol/multicol-rule-groove-000.xht "css/css-multicol/multicol-rule-groove-000.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-rule-groove-000.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-rule-groove-000.xht)
- [multicol-rule-ridge-000.xht](https://wpt.fyi/results/css/css-multicol/multicol-rule-ridge-000.xht "css/css-multicol/multicol-rule-ridge-000.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-rule-ridge-000.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-rule-ridge-000.xht)
- [multicol-rule-solid-000.xht](https://wpt.fyi/results/css/css-multicol/multicol-rule-solid-000.xht "css/css-multicol/multicol-rule-solid-000.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-rule-solid-000.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-rule-solid-000.xht)
- [column-rule-computed.html](https://wpt.fyi/results/css/css-multicol/parsing/column-rule-computed.html "css/css-multicol/parsing/column-rule-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/parsing/column-rule-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/parsing/column-rule-computed.html)
- [column-rule-invalid.html](https://wpt.fyi/results/css/css-multicol/parsing/column-rule-invalid.html "css/css-multicol/parsing/column-rule-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/parsing/column-rule-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/parsing/column-rule-invalid.html)
- [column-rule-valid.html](https://wpt.fyi/results/css/css-multicol/parsing/column-rule-valid.html "css/css-multicol/parsing/column-rule-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/parsing/column-rule-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/parsing/column-rule-valid.html)
- [column-rule-shorthand.html](https://wpt.fyi/results/css/css-multicol/parsing/column-rule-shorthand.html "css/css-multicol/parsing/column-rule-shorthand.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/parsing/column-rule-shorthand.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/parsing/column-rule-shorthand.html)

In this example, the [column
rule](#column-rule) and the
[column gap](#column-gap) have the
same width. Therefore, they will occupy exactly the same space.

``` highlight
body {
 column-gap: 35px;
 column-rule-width: 35px;
 column-rule-style: solid;
 column-rule-color: black;
}
```

![The column rule and column gap occupy the same
space.](images/rule-same-width-as-gap.svg){a}

Tests

- [equal-gap-and-rule.html](https://wpt.fyi/results/css/css-multicol/equal-gap-and-rule.html "css/css-multicol/equal-gap-and-rule.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/equal-gap-and-rule.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/equal-gap-and-rule.html)
- [multicol-rule-samelength-001.xht](https://wpt.fyi/results/css/css-multicol/multicol-rule-samelength-001.xht "css/css-multicol/multicol-rule-samelength-001.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-rule-samelength-001.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-rule-samelength-001.xht)
- [fixed-size-child-with-overflow.html](https://wpt.fyi/results/css/css-multicol/fixed-size-child-with-overflow.html "css/css-multicol/fixed-size-child-with-overflow.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/fixed-size-child-with-overflow.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/fixed-size-child-with-overflow.html)

## 5. Column Breaks

When content is laid out in multiple columns, the user agent must
determine where column breaks are placed. The problem of breaking
content into columns is similar to breaking content into pages, which is
described in CSS 2.1, section 13.3.3
[\[CSS21\]](#biblio-css21 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification").

Three new properties are introduced to allow column breaks to be
described in the same properties as page breaks:
[break-before](https://drafts.csswg.org/css-break-3/#propdef-break-before),
[break-after](https://drafts.csswg.org/css-break-3/#propdef-break-after), and
[break-inside](https://drafts.csswg.org/css-break-3/#propdef-break-inside).

### [5.1. ][Controlling Fragmentation: the [break-before](https://drafts.csswg.org/css-break-3/#propdef-break-before), [break-after](https://drafts.csswg.org/css-break-3/#propdef-break-after), [break-inside](https://drafts.csswg.org/css-break-3/#propdef-break-inside) properties]
[break-before](https://drafts.csswg.org/css-break-3/#propdef-break-before),
[break-after](https://drafts.csswg.org/css-break-3/#propdef-break-after), and
[break-inside](https://drafts.csswg.org/css-break-3/#propdef-break-inside) are defined in
[\[CSS3-BREAK\]](#biblio-css3-break "CSS Fragmentation Module Level 3").

Tests

- [multicol-break-000.xht](https://wpt.fyi/results/css/css-multicol/multicol-break-000.xht "css/css-multicol/multicol-break-000.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-break-000.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-break-000.xht)
- [multicol-break-001.xht](https://wpt.fyi/results/css/css-multicol/multicol-break-001.xht "css/css-multicol/multicol-break-001.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-break-001.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-break-001.xht)
- [multicol-br-inside-avoidcolumn-001.xht](https://wpt.fyi/results/css/css-multicol/multicol-br-inside-avoidcolumn-001.xht "css/css-multicol/multicol-br-inside-avoidcolumn-001.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-br-inside-avoidcolumn-001.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-br-inside-avoidcolumn-001.xht)
- [moz-multicol3-column-balancing-break-inside-avoid-1.html (manual
 test)
 ][[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/moz-multicol3-column-balancing-break-inside-avoid-1.html)
- [balance-break-inside-avoid-on-root.html](https://wpt.fyi/results/css/css-multicol/crashtests/balance-break-inside-avoid-on-root.html "css/css-multicol/crashtests/balance-break-inside-avoid-on-root.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/balance-break-inside-avoid-on-root.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/balance-break-inside-avoid-on-root.html)

## 6. Spanning Columns

The [column-span](#propdef-column-span) property makes it possible for an
element to span across several columns.

### 6.1. Spanning An Element Across Columns: the [column-span property]
Name:

[column-span]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

none
[\|](https://drafts.csswg.org/css-values-4/#comb-one) all

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

none

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[in-flow](https://drafts.csswg.org/css-display-4/#in-flow) block-level elements

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

- [column-span-invalid.html](https://wpt.fyi/results/css/css-multicol/parsing/column-span-invalid.html "css/css-multicol/parsing/column-span-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/parsing/column-span-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/parsing/column-span-invalid.html)

This property describes how many columns an element spans across. Values
are:

[none]
: The element does not span multiple columns.
 Tests
 - [multicol-span-none-001.xht](https://wpt.fyi/results/css/css-multicol/multicol-span-none-001.xht "css/css-multicol/multicol-span-none-001.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-span-none-001.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-span-none-001.xht)

[all]

: The element forces a column break and is taken [out of
 flow](https://drafts.csswg.org/css-display-4/#out-of-flow) to span across all columns of the nearest multicol
 ancestor in the same [block formatting
 context](https://drafts.csswg.org/css-display-4/#block-formatting-context). Content in the normal flow that appears before the
 element is automatically balanced across all columns in the
 immediately preceding [multi-column
 line](#multi-column-line) before the element appears, and any subsequent
 content flows into a new [multi-column
 line] after the element. The element
 establishes an [independent formatting
 context](https://drafts.csswg.org/css-display-4/#independent-formatting-context).

 Whether the element establishes a new [formatting
 context](https://drafts.csswg.org/css-display-4/#formatting-context) does not depend on whether the element is a
 descendant of a multicol or not. When
 [column-span](#propdef-column-span) is
 [all](#valdef-column-span-all), it always does. This helps with robustness of
 designs to later revisions that remove the multicol, or when media
 queries turn the multicol off in some situations.

 Tests

 - [multicol-span-000.xht](https://wpt.fyi/results/css/css-multicol/multicol-span-000.xht "css/css-multicol/multicol-span-000.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-span-000.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-span-000.xht)
 - [multicol-span-all-001.xht](https://wpt.fyi/results/css/css-multicol/multicol-span-all-001.xht "css/css-multicol/multicol-span-all-001.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-span-all-001.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-span-all-001.xht)
 - [multicol-span-all-003.xht](https://wpt.fyi/results/css/css-multicol/multicol-span-all-003.xht "css/css-multicol/multicol-span-all-003.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-span-all-003.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-span-all-003.xht)
 - [multicol-span-all-block-sibling-003.xht](https://wpt.fyi/results/css/css-multicol/multicol-span-all-block-sibling-003.xht "css/css-multicol/multicol-span-all-block-sibling-003.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-span-all-block-sibling-003.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-span-all-block-sibling-003.xht)
 - [multicol-span-all-margin-001.xht](https://wpt.fyi/results/css/css-multicol/multicol-span-all-margin-001.xht "css/css-multicol/multicol-span-all-margin-001.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-span-all-margin-001.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-span-all-margin-001.xht)
 - [multicol-span-all-margin-002.xht](https://wpt.fyi/results/css/css-multicol/multicol-span-all-margin-002.xht "css/css-multicol/multicol-span-all-margin-002.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-span-all-margin-002.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-span-all-margin-002.xht)
 - [multicol-span-all-margin-003.html](https://wpt.fyi/results/css/css-multicol/multicol-span-all-margin-003.html "css/css-multicol/multicol-span-all-margin-003.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-span-all-margin-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-span-all-margin-003.html)
 - [multicol-span-all-margin-bottom-001.xht](https://wpt.fyi/results/css/css-multicol/multicol-span-all-margin-bottom-001.xht "css/css-multicol/multicol-span-all-margin-bottom-001.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-span-all-margin-bottom-001.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-span-all-margin-bottom-001.xht)
 - [multicol-span-all-margin-nested-001.xht](https://wpt.fyi/results/css/css-multicol/multicol-span-all-margin-nested-001.xht "css/css-multicol/multicol-span-all-margin-nested-001.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-span-all-margin-nested-001.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-span-all-margin-nested-001.xht)
 - [multicol-span-all-margin-nested-002.xht](https://wpt.fyi/results/css/css-multicol/multicol-span-all-margin-nested-002.xht "css/css-multicol/multicol-span-all-margin-nested-002.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-span-all-margin-nested-002.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-span-all-margin-nested-002.xht)
 - [multicol-span-all-margin-nested-firstchild-001.xht](https://wpt.fyi/results/css/css-multicol/multicol-span-all-margin-nested-firstchild-001.xht "css/css-multicol/multicol-span-all-margin-nested-firstchild-001.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-span-all-margin-nested-firstchild-001.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-span-all-margin-nested-firstchild-001.xht)
 - [multicol-span-float-001.xht](https://wpt.fyi/results/css/css-multicol/multicol-span-float-001.xht "css/css-multicol/multicol-span-float-001.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-span-float-001.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-span-float-001.xht)
 - [multicol-span-float-002.html](https://wpt.fyi/results/css/css-multicol/multicol-span-float-002.html "css/css-multicol/multicol-span-float-002.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-span-float-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-span-float-002.html)
 - [multicol-span-float-003.html](https://wpt.fyi/results/css/css-multicol/multicol-span-float-003.html "css/css-multicol/multicol-span-float-003.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-span-float-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-span-float-003.html)
 - [multicol-span-float-004.html](https://wpt.fyi/results/css/css-multicol/multicol-span-float-004.html "css/css-multicol/multicol-span-float-004.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-span-float-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-span-float-004.html)
 - [inline-block-and-column-span-all.html](https://wpt.fyi/results/css/css-multicol/inline-block-and-column-span-all.html "css/css-multicol/inline-block-and-column-span-all.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/inline-block-and-column-span-all.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/inline-block-and-column-span-all.html)
 - [multicol-span-all-dynamic-remove-001.html](https://wpt.fyi/results/css/css-multicol/multicol-span-all-dynamic-remove-001.html "css/css-multicol/multicol-span-all-dynamic-remove-001.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-span-all-dynamic-remove-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-span-all-dynamic-remove-001.html)
 - [multicol-span-all-dynamic-add-001.html](https://wpt.fyi/results/css/css-multicol/multicol-span-all-dynamic-add-001.html "css/css-multicol/multicol-span-all-dynamic-add-001.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-span-all-dynamic-add-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-span-all-dynamic-add-001.html)
 - [multicol-span-all-dynamic-remove-002.html](https://wpt.fyi/results/css/css-multicol/multicol-span-all-dynamic-remove-002.html "css/css-multicol/multicol-span-all-dynamic-remove-002.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-span-all-dynamic-remove-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-span-all-dynamic-remove-002.html)
 - [multicol-span-all-dynamic-add-002.html](https://wpt.fyi/results/css/css-multicol/multicol-span-all-dynamic-add-002.html "css/css-multicol/multicol-span-all-dynamic-add-002.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-span-all-dynamic-add-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-span-all-dynamic-add-002.html)
 - [multicol-span-all-dynamic-remove-003.html](https://wpt.fyi/results/css/css-multicol/multicol-span-all-dynamic-remove-003.html "css/css-multicol/multicol-span-all-dynamic-remove-003.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-span-all-dynamic-remove-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-span-all-dynamic-remove-003.html)
 - [multicol-span-all-dynamic-add-003.html](https://wpt.fyi/results/css/css-multicol/multicol-span-all-dynamic-add-003.html "css/css-multicol/multicol-span-all-dynamic-add-003.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-span-all-dynamic-add-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-span-all-dynamic-add-003.html)
 - [multicol-span-all-dynamic-remove-004.html](https://wpt.fyi/results/css/css-multicol/multicol-span-all-dynamic-remove-004.html "css/css-multicol/multicol-span-all-dynamic-remove-004.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-span-all-dynamic-remove-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-span-all-dynamic-remove-004.html)
 - [multicol-span-all-dynamic-add-004.html](https://wpt.fyi/results/css/css-multicol/multicol-span-all-dynamic-add-004.html "css/css-multicol/multicol-span-all-dynamic-add-004.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-span-all-dynamic-add-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-span-all-dynamic-add-004.html)
 - [multicol-span-all-dynamic-add-005.html](https://wpt.fyi/results/css/css-multicol/multicol-span-all-dynamic-add-005.html "css/css-multicol/multicol-span-all-dynamic-add-005.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-span-all-dynamic-add-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-span-all-dynamic-add-005.html)
 - [multicol-span-all-dynamic-remove-005.html](https://wpt.fyi/results/css/css-multicol/multicol-span-all-dynamic-remove-005.html "css/css-multicol/multicol-span-all-dynamic-remove-005.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-span-all-dynamic-remove-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-span-all-dynamic-remove-005.html)
 - [multicol-span-all-dynamic-remove-006.html](https://wpt.fyi/results/css/css-multicol/multicol-span-all-dynamic-remove-006.html "css/css-multicol/multicol-span-all-dynamic-remove-006.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-span-all-dynamic-remove-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-span-all-dynamic-remove-006.html)
 - [multicol-span-all-dynamic-add-006.html](https://wpt.fyi/results/css/css-multicol/multicol-span-all-dynamic-add-006.html "css/css-multicol/multicol-span-all-dynamic-add-006.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-span-all-dynamic-add-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-span-all-dynamic-add-006.html)
 - [multicol-span-all-dynamic-remove-007.html](https://wpt.fyi/results/css/css-multicol/multicol-span-all-dynamic-remove-007.html "css/css-multicol/multicol-span-all-dynamic-remove-007.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-span-all-dynamic-remove-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-span-all-dynamic-remove-007.html)
 - [multicol-span-all-dynamic-add-007.html](https://wpt.fyi/results/css/css-multicol/multicol-span-all-dynamic-add-007.html "css/css-multicol/multicol-span-all-dynamic-add-007.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-span-all-dynamic-add-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-span-all-dynamic-add-007.html)
 - [multicol-span-all-dynamic-add-008.html](https://wpt.fyi/results/css/css-multicol/multicol-span-all-dynamic-add-008.html "css/css-multicol/multicol-span-all-dynamic-add-008.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-span-all-dynamic-add-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-span-all-dynamic-add-008.html)
 - [multicol-span-all-dynamic-add-009.html](https://wpt.fyi/results/css/css-multicol/multicol-span-all-dynamic-add-009.html "css/css-multicol/multicol-span-all-dynamic-add-009.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-span-all-dynamic-add-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-span-all-dynamic-add-009.html)
 - [multicol-span-all-dynamic-add-010.html](https://wpt.fyi/results/css/css-multicol/multicol-span-all-dynamic-add-010.html "css/css-multicol/multicol-span-all-dynamic-add-010.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-span-all-dynamic-add-010.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-span-all-dynamic-add-010.html)
 - [multicol-span-all-dynamic-add-011.html](https://wpt.fyi/results/css/css-multicol/multicol-span-all-dynamic-add-011.html "css/css-multicol/multicol-span-all-dynamic-add-011.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-span-all-dynamic-add-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-span-all-dynamic-add-011.html)
 - [multicol-span-all-dynamic-add-012.html](https://wpt.fyi/results/css/css-multicol/multicol-span-all-dynamic-add-012.html "css/css-multicol/multicol-span-all-dynamic-add-012.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-span-all-dynamic-add-012.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-span-all-dynamic-add-012.html)
 - [multicol-span-all-dynamic-add-013.html](https://wpt.fyi/results/css/css-multicol/multicol-span-all-dynamic-add-013.html "css/css-multicol/multicol-span-all-dynamic-add-013.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-span-all-dynamic-add-013.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-span-all-dynamic-add-013.html)
 - [multicol-span-all-dynamic-add-014.html](https://wpt.fyi/results/css/css-multicol/multicol-span-all-dynamic-add-014.html "css/css-multicol/multicol-span-all-dynamic-add-014.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-span-all-dynamic-add-014.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-span-all-dynamic-add-014.html)
 - [multicol-span-all-children-height-001.html](https://wpt.fyi/results/css/css-multicol/multicol-span-all-children-height-001.html "css/css-multicol/multicol-span-all-children-height-001.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-span-all-children-height-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-span-all-children-height-001.html)
 - [multicol-span-all-children-height-002.html](https://wpt.fyi/results/css/css-multicol/multicol-span-all-children-height-002.html "css/css-multicol/multicol-span-all-children-height-002.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-span-all-children-height-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-span-all-children-height-002.html)
 - [multicol-span-all-children-height-003.html](https://wpt.fyi/results/css/css-multicol/multicol-span-all-children-height-003.html "css/css-multicol/multicol-span-all-children-height-003.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-span-all-children-height-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-span-all-children-height-003.html)
 - [multicol-span-all-children-height-004a.html](https://wpt.fyi/results/css/css-multicol/multicol-span-all-children-height-004a.html "css/css-multicol/multicol-span-all-children-height-004a.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-span-all-children-height-004a.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-span-all-children-height-004a.html)
 - [multicol-span-all-children-height-004b.html](https://wpt.fyi/results/css/css-multicol/multicol-span-all-children-height-004b.html "css/css-multicol/multicol-span-all-children-height-004b.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-span-all-children-height-004b.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-span-all-children-height-004b.html)
 - [multicol-span-all-children-height-005.html](https://wpt.fyi/results/css/css-multicol/multicol-span-all-children-height-005.html "css/css-multicol/multicol-span-all-children-height-005.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-span-all-children-height-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-span-all-children-height-005.html)
 - [multicol-span-all-children-height-006.html](https://wpt.fyi/results/css/css-multicol/multicol-span-all-children-height-006.html "css/css-multicol/multicol-span-all-children-height-006.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-span-all-children-height-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-span-all-children-height-006.html)
 - [multicol-span-all-children-height-007.html](https://wpt.fyi/results/css/css-multicol/multicol-span-all-children-height-007.html "css/css-multicol/multicol-span-all-children-height-007.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-span-all-children-height-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-span-all-children-height-007.html)
 - [multicol-span-all-children-height-008.html](https://wpt.fyi/results/css/css-multicol/multicol-span-all-children-height-008.html "css/css-multicol/multicol-span-all-children-height-008.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-span-all-children-height-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-span-all-children-height-008.html)
 - [multicol-span-all-children-height-009.html](https://wpt.fyi/results/css/css-multicol/multicol-span-all-children-height-009.html "css/css-multicol/multicol-span-all-children-height-009.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-span-all-children-height-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-span-all-children-height-009.html)
 - [multicol-span-all-children-height-010.html](https://wpt.fyi/results/css/css-multicol/multicol-span-all-children-height-010.html "css/css-multicol/multicol-span-all-children-height-010.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-span-all-children-height-010.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-span-all-children-height-010.html)
 - [multicol-span-all-children-height-011.html](https://wpt.fyi/results/css/css-multicol/multicol-span-all-children-height-011.html "css/css-multicol/multicol-span-all-children-height-011.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-span-all-children-height-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-span-all-children-height-011.html)
 - [multicol-span-all-children-height-012.html](https://wpt.fyi/results/css/css-multicol/multicol-span-all-children-height-012.html "css/css-multicol/multicol-span-all-children-height-012.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-span-all-children-height-012.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-span-all-children-height-012.html)
 - [multicol-span-all-children-height-013.html](https://wpt.fyi/results/css/css-multicol/multicol-span-all-children-height-013.html "css/css-multicol/multicol-span-all-children-height-013.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-span-all-children-height-013.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-span-all-children-height-013.html)
 - [multicol-span-all-004.html](https://wpt.fyi/results/css/css-multicol/multicol-span-all-004.html "css/css-multicol/multicol-span-all-004.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-span-all-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-span-all-004.html)
 - [multicol-span-all-005.html](https://wpt.fyi/results/css/css-multicol/multicol-span-all-005.html "css/css-multicol/multicol-span-all-005.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-span-all-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-span-all-005.html)
 - [multicol-span-all-006.html](https://wpt.fyi/results/css/css-multicol/multicol-span-all-006.html "css/css-multicol/multicol-span-all-006.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-span-all-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-span-all-006.html)
 - [multicol-span-all-007.html](https://wpt.fyi/results/css/css-multicol/multicol-span-all-007.html "css/css-multicol/multicol-span-all-007.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-span-all-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-span-all-007.html)
 - [multicol-span-all-008.html](https://wpt.fyi/results/css/css-multicol/multicol-span-all-008.html "css/css-multicol/multicol-span-all-008.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-span-all-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-span-all-008.html)
 - [multicol-span-all-009.html](https://wpt.fyi/results/css/css-multicol/multicol-span-all-009.html "css/css-multicol/multicol-span-all-009.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-span-all-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-span-all-009.html)
 - [multicol-span-all-010.html](https://wpt.fyi/results/css/css-multicol/multicol-span-all-010.html "css/css-multicol/multicol-span-all-010.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-span-all-010.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-span-all-010.html)
 - [multicol-span-all-011.html](https://wpt.fyi/results/css/css-multicol/multicol-span-all-011.html "css/css-multicol/multicol-span-all-011.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-span-all-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-span-all-011.html)
 - [multicol-span-all-012.html](https://wpt.fyi/results/css/css-multicol/multicol-span-all-012.html "css/css-multicol/multicol-span-all-012.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-span-all-012.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-span-all-012.html)
 - [multicol-span-all-013.html](https://wpt.fyi/results/css/css-multicol/multicol-span-all-013.html "css/css-multicol/multicol-span-all-013.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-span-all-013.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-span-all-013.html)
 - [multicol-span-all-014.html](https://wpt.fyi/results/css/css-multicol/multicol-span-all-014.html "css/css-multicol/multicol-span-all-014.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-span-all-014.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-span-all-014.html)
 - [multicol-span-all-015.html](https://wpt.fyi/results/css/css-multicol/multicol-span-all-015.html "css/css-multicol/multicol-span-all-015.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-span-all-015.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-span-all-015.html)
 - [multicol-span-all-016.html](https://wpt.fyi/results/css/css-multicol/multicol-span-all-016.html "css/css-multicol/multicol-span-all-016.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-span-all-016.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-span-all-016.html)
 - [multicol-span-all-017.html](https://wpt.fyi/results/css/css-multicol/multicol-span-all-017.html "css/css-multicol/multicol-span-all-017.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-span-all-017.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-span-all-017.html)
 - [multicol-span-all-018.html](https://wpt.fyi/results/css/css-multicol/multicol-span-all-018.html "css/css-multicol/multicol-span-all-018.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-span-all-018.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-span-all-018.html)
 - [multicol-span-all-019.html](https://wpt.fyi/results/css/css-multicol/multicol-span-all-019.html "css/css-multicol/multicol-span-all-019.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-span-all-019.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-span-all-019.html)
 - [multicol-span-all-020.html](https://wpt.fyi/results/css/css-multicol/multicol-span-all-020.html "css/css-multicol/multicol-span-all-020.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-span-all-020.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-span-all-020.html)
 - [multicol-span-all-rule-001.html](https://wpt.fyi/results/css/css-multicol/multicol-span-all-rule-001.html "css/css-multicol/multicol-span-all-rule-001.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-span-all-rule-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-span-all-rule-001.html)
 - [multicol-span-all-rule-002.html](https://wpt.fyi/results/css/css-multicol/multicol-span-all-rule-002.html "css/css-multicol/multicol-span-all-rule-002.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-span-all-rule-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-span-all-rule-002.html)
 - [multicol-span-all-button-001.html](https://wpt.fyi/results/css/css-multicol/multicol-span-all-button-001.html "css/css-multicol/multicol-span-all-button-001.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-span-all-button-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-span-all-button-001.html)
 - [multicol-span-all-button-002.html](https://wpt.fyi/results/css/css-multicol/multicol-span-all-button-002.html "css/css-multicol/multicol-span-all-button-002.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-span-all-button-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-span-all-button-002.html)
 - [multicol-span-all-button-003.html](https://wpt.fyi/results/css/css-multicol/multicol-span-all-button-003.html "css/css-multicol/multicol-span-all-button-003.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-span-all-button-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-span-all-button-003.html)
 - [multicol-span-all-fieldset-001.html](https://wpt.fyi/results/css/css-multicol/multicol-span-all-fieldset-001.html "css/css-multicol/multicol-span-all-fieldset-001.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-span-all-fieldset-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-span-all-fieldset-001.html)
 - [multicol-span-all-fieldset-002.html](https://wpt.fyi/results/css/css-multicol/multicol-span-all-fieldset-002.html "css/css-multicol/multicol-span-all-fieldset-002.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-span-all-fieldset-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-span-all-fieldset-002.html)
 - [multicol-span-all-fieldset-003.html](https://wpt.fyi/results/css/css-multicol/multicol-span-all-fieldset-003.html "css/css-multicol/multicol-span-all-fieldset-003.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-span-all-fieldset-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-span-all-fieldset-003.html)
 - [multicol-span-all-restyle-001.html](https://wpt.fyi/results/css/css-multicol/multicol-span-all-restyle-001.html "css/css-multicol/multicol-span-all-restyle-001.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-span-all-restyle-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-span-all-restyle-001.html)
 - [multicol-span-all-restyle-002.html](https://wpt.fyi/results/css/css-multicol/multicol-span-all-restyle-002.html "css/css-multicol/multicol-span-all-restyle-002.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-span-all-restyle-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-span-all-restyle-002.html)
 - [multicol-span-all-restyle-003.html](https://wpt.fyi/results/css/css-multicol/multicol-span-all-restyle-003.html "css/css-multicol/multicol-span-all-restyle-003.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-span-all-restyle-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-span-all-restyle-003.html)
 - [multicol-span-all-restyle-004.html](https://wpt.fyi/results/css/css-multicol/multicol-span-all-restyle-004.html "css/css-multicol/multicol-span-all-restyle-004.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-span-all-restyle-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-span-all-restyle-004.html)
 - [multicol-span-all-list-item-001.html](https://wpt.fyi/results/css/css-multicol/multicol-span-all-list-item-001.html "css/css-multicol/multicol-span-all-list-item-001.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-span-all-list-item-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-span-all-list-item-001.html)
 - [multicol-span-all-list-item-002.html](https://wpt.fyi/results/css/css-multicol/multicol-span-all-list-item-002.html "css/css-multicol/multicol-span-all-list-item-002.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-span-all-list-item-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-span-all-list-item-002.html)
 - [multicol-span-auto-size-in-vertical-writing-mode-001.html](https://wpt.fyi/results/css/css-multicol/multicol-span-auto-size-in-vertical-writing-mode-001.html "css/css-multicol/multicol-span-auto-size-in-vertical-writing-mode-001.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-span-auto-size-in-vertical-writing-mode-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-span-auto-size-in-vertical-writing-mode-001.html)
 - [multicol-span-auto-size-in-vertical-writing-mode-002.html](https://wpt.fyi/results/css/css-multicol/multicol-span-auto-size-in-vertical-writing-mode-002.html "css/css-multicol/multicol-span-auto-size-in-vertical-writing-mode-002.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-span-auto-size-in-vertical-writing-mode-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-span-auto-size-in-vertical-writing-mode-002.html)
 - [float-with-line-after-spanner.html](https://wpt.fyi/results/css/css-multicol/float-with-line-after-spanner.html "css/css-multicol/float-with-line-after-spanner.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/float-with-line-after-spanner.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/float-with-line-after-spanner.html)
 - [parallel-flow-after-spanner-001.html](https://wpt.fyi/results/css/css-multicol/parallel-flow-after-spanner-001.html "css/css-multicol/parallel-flow-after-spanner-001.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/parallel-flow-after-spanner-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/parallel-flow-after-spanner-001.html)
 - [parallel-flow-after-spanner-002.html](https://wpt.fyi/results/css/css-multicol/parallel-flow-after-spanner-002.html "css/css-multicol/parallel-flow-after-spanner-002.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/parallel-flow-after-spanner-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/parallel-flow-after-spanner-002.html)
 - [margin-and-break-before-child-spanner.html](https://wpt.fyi/results/css/css-multicol/crashtests/margin-and-break-before-child-spanner.html "css/css-multicol/crashtests/margin-and-break-before-child-spanner.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/margin-and-break-before-child-spanner.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/margin-and-break-before-child-spanner.html)
 - [multicol-width-004.html](https://wpt.fyi/results/css/css-multicol/multicol-width-004.html "css/css-multicol/multicol-width-004.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-width-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-width-004.html)

An element that spans more than one column is called a [multi-column
spanning element] and the box it
creates is called a [multi-column spanner].

The [containing
block](https://drafts.csswg.org/css-display-4/#containing-block) of the
[spanner](#multi-column-spanner) is the [multicol
container](#multi-column-container) itself. Consequently, in cases where the spanner itself
does not establish a [containing block] for
[absolutely positioned
boxes](https://drafts.csswg.org/css-position-3/#absolute-position) inside the spanner, their [containing block
chain](https://drafts.csswg.org/css-display-4/#containing-block-chain) skips directly to the [multicol
container] (skipping any ancestors
between the [spanner] and the [multicol
container]).

Although the spanner is taken
[out-of-flow](https://drafts.csswg.org/css-display-4/#out-of-flow), this does not affect the [painting
order](https://www.w3.org/TR/CSS2/zindex.html)
[\[CSS21\]](#biblio-css21 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")
of the spanning element.

In this example, an `h2` element has
been added to the sample document after the sixth sentence (i.e., after
the words \"the leg of a\"). This styling applies:

``` highlight
h2 { column-span: all; background: silver }
```

By setting
[column-span](#propdef-column-span) to
[all](#valdef-column-span-all), all content that appears before the `h2` element is
shown above the `h2` element.

![The h2 element is set to column-span:
all](images/h2-spanner.svg){a}

Note that because the spanner splits the [multi-column
line](#multi-column-line),
it also interrupts any [column
rules](#column-rule) (which are
only drawn between [columns](#column-box) in a [multi-column line]).

A spanning element may be lower than the first level of descendants as
long as they are part of the same [formatting
context](https://drafts.csswg.org/css-display-4/#formatting-context), and there is nothing between the spanning element and
[multicol
container](#multi-column-container) that establishes a containing block for fixed position
descendants.

In this example, the element with
[column-span: all](#propdef-column-span) is inside an element with [transform:
rotate(90deg)](https://drafts.csswg.org/css-transforms-1/#propdef-transform). The transform establishes a containing block
for fixed position descendents, therefore a spanner will not be created.

``` highlight
<article>
 <section>
 <div class="spanner">Attempted spanner</div>
 </section>
</article>
```

``` highlight
article {
 columns: 2;
}

section {
 transform: rotate(90deg);
}

.spanner {
 column-span: all;
 background: silver;
}
```

- [fixed-in-multicol-with-transform-container.html](https://wpt.fyi/results/css/css-multicol/fixed-in-multicol-with-transform-container.html "css/css-multicol/fixed-in-multicol-with-transform-container.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/fixed-in-multicol-with-transform-container.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/fixed-in-multicol-with-transform-container.html)
- [change-transform-in-nested.html](https://wpt.fyi/results/css/css-multicol/change-transform-in-nested.html "css/css-multicol/change-transform-in-nested.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/change-transform-in-nested.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/change-transform-in-nested.html)
- [change-transform-in-second-column.html](https://wpt.fyi/results/css/css-multicol/change-transform-in-second-column.html "css/css-multicol/change-transform-in-second-column.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/change-transform-in-second-column.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/change-transform-in-second-column.html)
- [change-transform.html](https://wpt.fyi/results/css/css-multicol/change-transform.html "css/css-multicol/change-transform.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/change-transform.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/change-transform.html)
- [ancestor-toggle-spanner-001.html](https://wpt.fyi/results/css/css-multicol/ancestor-toggle-spanner-001.html "css/css-multicol/ancestor-toggle-spanner-001.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/ancestor-toggle-spanner-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/ancestor-toggle-spanner-001.html)
- [ancestor-toggle-spanner-002.html](https://wpt.fyi/results/css/css-multicol/ancestor-toggle-spanner-002.html "css/css-multicol/ancestor-toggle-spanner-002.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/ancestor-toggle-spanner-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/ancestor-toggle-spanner-002.html)
- [ancestor-toggle-spanner-remove-child.html](https://wpt.fyi/results/css/css-multicol/crashtests/ancestor-toggle-spanner-remove-child.html "css/css-multicol/crashtests/ancestor-toggle-spanner-remove-child.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/ancestor-toggle-spanner-remove-child.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/ancestor-toggle-spanner-remove-child.html)

If the fragment before the spanner is empty, nothing special happens;
the top margin/border/padding is above the spanning element, as an empty
[fragment](https://drafts.csswg.org/css-break-4/#fragment).

In this example the [multicol
container](#multi-column-container) is the `article` element. Inside this parent is a
paragraph and then a section element. The section contains an `h2`
heading set to
[all](#valdef-column-span-all) this spans all three columns while the containing
section remains inside the column boxes.

The `h2` is the first child of the section. This means that the margin,
border (shown in red in the diagram) and padding on this section appear
before the spanning `h2` as an empty fragment.

``` highlight
<article>
 <p>...</p>
 <section>
 <h2>An h2 element</h2>
 <p>...</p>
 </section>
</article>
```

``` highlight
section {
 border: 2px solid red;
 margin-top: 65px;
 padding-top: 20px;
}

h2 {
 column-span: all;
 background: silver
}
```

![The `h2` element is set to [column-span:
all](#propdef-column-span), the section has a red border and top padding and
margin](images/nested-spanner.svg){a}

- [spanner-fragmentation-000.html](https://wpt.fyi/results/css/css-multicol/spanner-fragmentation-000.html "css/css-multicol/spanner-fragmentation-000.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/spanner-fragmentation-000.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/spanner-fragmentation-000.html)
- [spanner-fragmentation-001.html](https://wpt.fyi/results/css/css-multicol/spanner-fragmentation-001.html "css/css-multicol/spanner-fragmentation-001.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/spanner-fragmentation-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/spanner-fragmentation-001.html)
- [spanner-fragmentation-002.html](https://wpt.fyi/results/css/css-multicol/spanner-fragmentation-002.html "css/css-multicol/spanner-fragmentation-002.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/spanner-fragmentation-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/spanner-fragmentation-002.html)
- [spanner-fragmentation-003.html](https://wpt.fyi/results/css/css-multicol/spanner-fragmentation-003.html "css/css-multicol/spanner-fragmentation-003.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/spanner-fragmentation-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/spanner-fragmentation-003.html)
- [spanner-fragmentation-004.html](https://wpt.fyi/results/css/css-multicol/spanner-fragmentation-004.html "css/css-multicol/spanner-fragmentation-004.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/spanner-fragmentation-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/spanner-fragmentation-004.html)
- [spanner-fragmentation-005.html](https://wpt.fyi/results/css/css-multicol/spanner-fragmentation-005.html "css/css-multicol/spanner-fragmentation-005.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/spanner-fragmentation-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/spanner-fragmentation-005.html)
- [spanner-fragmentation-006.html](https://wpt.fyi/results/css/css-multicol/spanner-fragmentation-006.html "css/css-multicol/spanner-fragmentation-006.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/spanner-fragmentation-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/spanner-fragmentation-006.html)
- [spanner-fragmentation-007.html](https://wpt.fyi/results/css/css-multicol/spanner-fragmentation-007.html "css/css-multicol/spanner-fragmentation-007.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/spanner-fragmentation-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/spanner-fragmentation-007.html)
- [spanner-fragmentation-008.html](https://wpt.fyi/results/css/css-multicol/spanner-fragmentation-008.html "css/css-multicol/spanner-fragmentation-008.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/spanner-fragmentation-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/spanner-fragmentation-008.html)
- [spanner-fragmentation-009.html](https://wpt.fyi/results/css/css-multicol/spanner-fragmentation-009.html "css/css-multicol/spanner-fragmentation-009.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/spanner-fragmentation-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/spanner-fragmentation-009.html)
- [spanner-fragmentation-010.html](https://wpt.fyi/results/css/css-multicol/spanner-fragmentation-010.html "css/css-multicol/spanner-fragmentation-010.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/spanner-fragmentation-010.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/spanner-fragmentation-010.html)
- [spanner-fragmentation-011.html](https://wpt.fyi/results/css/css-multicol/spanner-fragmentation-011.html "css/css-multicol/spanner-fragmentation-011.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/spanner-fragmentation-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/spanner-fragmentation-011.html)
- [spanner-fragmentation-012.html](https://wpt.fyi/results/css/css-multicol/spanner-fragmentation-012.html "css/css-multicol/spanner-fragmentation-012.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/spanner-fragmentation-012.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/spanner-fragmentation-012.html)

A spanning element takes up more space than the element would take up
otherwise. When space is limited, it may be impossible to find room for
the spanning element. In these cases, user agents may treat the element
as if [none](#valdef-column-span-none) had been specified on this property.

In this example, the `h2` element
appears later in the content, and the height of the multicol container
is constrained. Therefore, the `h2` element appears in the overflow and
there is not room to make the element spanning. As a result, the element
appears as if [column-span:
none](#propdef-column-span) was specified.

![The h2 element is in an overflow column and appears as if column-span
none is
specified](images/h2-in-the-overflow-no-span.svg){a
style="max-height: 107px;"}

This example is similar to the
previous example, except that the H2 element appears naturally in the
last column. Still, there is not enough room to make the element
spanning.

![The h2 element is in the final column and appears as if column-span
none is
specified](images/h2-in-the-last-column-no-span.svg){a
style="max-height: 107px;"}

- [multicol-span-all-002.xht](https://wpt.fyi/results/css/css-multicol/multicol-span-all-002.xht "css/css-multicol/multicol-span-all-002.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-span-all-002.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-span-all-002.xht)

In fragmented contexts spanning
elements are honored in all fragments. In this example, we are in [paged
media](https://drafts.csswg.org/mediaqueries-5/#paged-media), and the first three paragraphs have column breaks
after them. A spanning `H2` element appears after the fourth paragraph.

![This would appear on the first
page](images/spanner-page-break1.svg){a}

![This would appear on the second
page](images/spanner-page-break2.svg){a}

Spanners are block-level boxes therefore the margins of two adjacent
spanners will collapse with each other. The margins of two spanners
separated only by an absolutely positioned item will collapse with each
other, as absolutely positioned items do not create column boxes. As
column boxes establish a new [block formatting
context](https://drafts.csswg.org/css-display-4/#block-formatting-context), margins on elements inside a column box will not
collapse with the margin of a spanner.

Tests

- [non-adjacent-spanners-000.html](https://wpt.fyi/results/css/css-multicol/non-adjacent-spanners-000.html "css/css-multicol/non-adjacent-spanners-000.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/non-adjacent-spanners-000.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/non-adjacent-spanners-000.html)
- [non-adjacent-spanners-001.html](https://wpt.fyi/results/css/css-multicol/non-adjacent-spanners-001.html "css/css-multicol/non-adjacent-spanners-001.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/non-adjacent-spanners-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/non-adjacent-spanners-001.html)

Spanners establish new [formatting
contexts](https://drafts.csswg.org/css-display-4/#formatting-context), but their margins can be changed by their
surroundings. In this example, two spanners naturally end up at the top
of a page. The top margin of the first spanner is truncated due to
adjoining an unforced break. The margins between the two spanners
collapse with each other. However, the bottom margin of the second
spanner does not collapse with the top margin of the subsequent element.

``` highlight
h2 {
 margin: 16px 0;
 column-span: all;
 background: silver
}
p { margin-top: 16px }
```

![Margins collapse between two spanning elements, but not the bottom
margin of a spanner and top margin of next
element.](images/two-spanners-margin-no-collapse.svg){a}

Additional tests relating to spanners.

- [abspos-in-multicol-with-spanner-crash.html](https://wpt.fyi/results/css/css-multicol/abspos-in-multicol-with-spanner-crash.html "css/css-multicol/abspos-in-multicol-with-spanner-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/abspos-in-multicol-with-spanner-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/abspos-in-multicol-with-spanner-crash.html)
- [body-becomes-spanner-html-becomes-vertical-rl.html](https://wpt.fyi/results/css/css-multicol/crashtests/body-becomes-spanner-html-becomes-vertical-rl.html "css/css-multicol/crashtests/body-becomes-spanner-html-becomes-vertical-rl.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/body-becomes-spanner-html-becomes-vertical-rl.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/body-becomes-spanner-html-becomes-vertical-rl.html)
- [fit-content-with-spanner-and-auto-scrollbar-sibling.html](https://wpt.fyi/results/css/css-multicol/crashtests/fit-content-with-spanner-and-auto-scrollbar-sibling.html "css/css-multicol/crashtests/fit-content-with-spanner-and-auto-scrollbar-sibling.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/fit-content-with-spanner-and-auto-scrollbar-sibling.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/fit-content-with-spanner-and-auto-scrollbar-sibling.html)
- [float-becomes-non-float-spanner-surprises-inside.html](https://wpt.fyi/results/css/css-multicol/crashtests/float-becomes-non-float-spanner-surprises-inside.html "css/css-multicol/crashtests/float-becomes-non-float-spanner-surprises-inside.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/float-becomes-non-float-spanner-surprises-inside.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/float-becomes-non-float-spanner-surprises-inside.html)
- [float-becomes-spanner.html](https://wpt.fyi/results/css/css-multicol/crashtests/float-becomes-spanner.html "css/css-multicol/crashtests/float-becomes-spanner.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/float-becomes-spanner.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/float-becomes-spanner.html)
- [float-becomes-spanner-remove-child.html](https://wpt.fyi/results/css/css-multicol/crashtests/float-becomes-spanner-remove-child.html "css/css-multicol/crashtests/float-becomes-spanner-remove-child.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/float-becomes-spanner-remove-child.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/float-becomes-spanner-remove-child.html)
- [float-cannot-be-spanner.html](https://wpt.fyi/results/css/css-multicol/crashtests/float-cannot-be-spanner.html "css/css-multicol/crashtests/float-cannot-be-spanner.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/float-cannot-be-spanner.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/float-cannot-be-spanner.html)
- [multicol-floats-after-column-span-crash.html](https://wpt.fyi/results/css/css-multicol/crashtests/multicol-floats-after-column-span-crash.html "css/css-multicol/crashtests/multicol-floats-after-column-span-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/multicol-floats-after-column-span-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/multicol-floats-after-column-span-crash.html)
- [negative-margin-on-column-spanner.html](https://wpt.fyi/results/css/css-multicol/crashtests/negative-margin-on-column-spanner.html "css/css-multicol/crashtests/negative-margin-on-column-spanner.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/negative-margin-on-column-spanner.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/negative-margin-on-column-spanner.html)
- [nested-spanner-with-negative-margin.html](https://wpt.fyi/results/css/css-multicol/crashtests/nested-spanner-with-negative-margin.html "css/css-multicol/crashtests/nested-spanner-with-negative-margin.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/nested-spanner-with-negative-margin.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/nested-spanner-with-negative-margin.html)
- [oof-becomes-spanner.html](https://wpt.fyi/results/css/css-multicol/crashtests/oof-becomes-spanner.html "css/css-multicol/crashtests/oof-becomes-spanner.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/oof-becomes-spanner.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/oof-becomes-spanner.html)
- [oof-in-additional-column-before-spanner.html](https://wpt.fyi/results/css/css-multicol/crashtests/oof-in-additional-column-before-spanner.html "css/css-multicol/crashtests/oof-in-additional-column-before-spanner.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/oof-in-additional-column-before-spanner.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/oof-in-additional-column-before-spanner.html)
- [oof-in-spanner-in-relpos-in-multicol-in-relpos-multicol-001.html](https://wpt.fyi/results/css/css-multicol/crashtests/oof-in-spanner-in-relpos-in-multicol-in-relpos-multicol-001.html "css/css-multicol/crashtests/oof-in-spanner-in-relpos-in-multicol-in-relpos-multicol-001.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/oof-in-spanner-in-relpos-in-multicol-in-relpos-multicol-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/oof-in-spanner-in-relpos-in-multicol-in-relpos-multicol-001.html)
- [oof-in-spanner-in-relpos-in-multicol-in-relpos-multicol-002.html](https://wpt.fyi/results/css/css-multicol/crashtests/oof-in-spanner-in-relpos-in-multicol-in-relpos-multicol-002.html "css/css-multicol/crashtests/oof-in-spanner-in-relpos-in-multicol-in-relpos-multicol-002.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/oof-in-spanner-in-relpos-in-multicol-in-relpos-multicol-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/oof-in-spanner-in-relpos-in-multicol-in-relpos-multicol-002.html)
- [relpos-spanner-with-spanner-child-becomes-regular.html](https://wpt.fyi/results/css/css-multicol/crashtests/relpos-spanner-with-spanner-child-becomes-regular.html "css/css-multicol/crashtests/relpos-spanner-with-spanner-child-becomes-regular.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/relpos-spanner-with-spanner-child-becomes-regular.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/relpos-spanner-with-spanner-child-becomes-regular.html)
- [remove-spanner-after-spanner-in-inline-before-inline.html](https://wpt.fyi/results/css/css-multicol/crashtests/remove-spanner-after-spanner-in-inline-before-inline.html "css/css-multicol/crashtests/remove-spanner-after-spanner-in-inline-before-inline.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/remove-spanner-after-spanner-in-inline-before-inline.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/remove-spanner-after-spanner-in-inline-before-inline.html)
- [remove-spanner-in-table-caption-nested-multicol.html](https://wpt.fyi/results/css/css-multicol/crashtests/remove-spanner-in-table-caption-nested-multicol.html "css/css-multicol/crashtests/remove-spanner-in-table-caption-nested-multicol.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/remove-spanner-in-table-caption-nested-multicol.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/remove-spanner-in-table-caption-nested-multicol.html)
- [remove-transform-descendant-becomes-spanner-remove-spanner-child.html](https://wpt.fyi/results/css/css-multicol/crashtests/remove-transform-descendant-becomes-spanner-remove-spanner-child.html "css/css-multicol/crashtests/remove-transform-descendant-becomes-spanner-remove-spanner-child.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/remove-transform-descendant-becomes-spanner-remove-spanner-child.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/remove-transform-descendant-becomes-spanner-remove-spanner-child.html)
- [restricted-height-bottom-border-overflow-and-spanner.html](https://wpt.fyi/results/css/css-multicol/crashtests/restricted-height-bottom-border-overflow-and-spanner.html "css/css-multicol/crashtests/restricted-height-bottom-border-overflow-and-spanner.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/restricted-height-bottom-border-overflow-and-spanner.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/restricted-height-bottom-border-overflow-and-spanner.html)
- [scrollable-spanner-in-nested.html](https://wpt.fyi/results/css/css-multicol/crashtests/scrollable-spanner-in-nested.html "css/css-multicol/crashtests/scrollable-spanner-in-nested.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/scrollable-spanner-in-nested.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/scrollable-spanner-in-nested.html)
- [spanner-after-parallel-flow.html](https://wpt.fyi/results/css/css-multicol/crashtests/spanner-after-parallel-flow.html "css/css-multicol/crashtests/spanner-after-parallel-flow.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/spanner-after-parallel-flow.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/spanner-after-parallel-flow.html)
- [spanner-in-inline-after-very-tall-content-001.html](https://wpt.fyi/results/css/css-multicol/crashtests/spanner-in-inline-after-very-tall-content-001.html "css/css-multicol/crashtests/spanner-in-inline-after-very-tall-content-001.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/spanner-in-inline-after-very-tall-content-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/spanner-in-inline-after-very-tall-content-001.html)
- [spanner-in-inline-after-very-tall-content-002.html](https://wpt.fyi/results/css/css-multicol/crashtests/spanner-in-inline-after-very-tall-content-002.html "css/css-multicol/crashtests/spanner-in-inline-after-very-tall-content-002.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/spanner-in-inline-after-very-tall-content-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/spanner-in-inline-after-very-tall-content-002.html)
- [spanner-in-overflowed-container-before-float.html](https://wpt.fyi/results/css/css-multicol/crashtests/spanner-in-overflowed-container-before-float.html "css/css-multicol/crashtests/spanner-in-overflowed-container-before-float.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/spanner-in-overflowed-container-before-float.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/spanner-in-overflowed-container-before-float.html)
- [spanner-in-relpos-in-abspos-multicol-in-multicol.html](https://wpt.fyi/results/css/css-multicol/crashtests/spanner-in-relpos-in-abspos-multicol-in-multicol.html "css/css-multicol/crashtests/spanner-in-relpos-in-abspos-multicol-in-multicol.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/spanner-in-relpos-in-abspos-multicol-in-multicol.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/spanner-in-relpos-in-abspos-multicol-in-multicol.html)
- [nested-with-tall-padding-and-spanner-and-content.html](https://wpt.fyi/results/css/css-multicol/crashtests/nested-with-tall-padding-and-spanner-and-content.html "css/css-multicol/crashtests/nested-with-tall-padding-and-spanner-and-content.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/nested-with-tall-padding-and-spanner-and-content.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/nested-with-tall-padding-and-spanner-and-content.html)
- [specified-height-with-just-spanner-and-oof.html](https://wpt.fyi/results/css/css-multicol/crashtests/specified-height-with-just-spanner-and-oof.html "css/css-multicol/crashtests/specified-height-with-just-spanner-and-oof.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/specified-height-with-just-spanner-and-oof.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/specified-height-with-just-spanner-and-oof.html)
- [trailing-parent-padding-between-spanners.html](https://wpt.fyi/results/css/css-multicol/crashtests/trailing-parent-padding-between-spanners.html "css/css-multicol/crashtests/trailing-parent-padding-between-spanners.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/trailing-parent-padding-between-spanners.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/trailing-parent-padding-between-spanners.html)
- [table-caption-change-descendant-display-type.html](https://wpt.fyi/results/css/css-multicol/crashtests/table-caption-change-descendant-display-type.html "css/css-multicol/crashtests/table-caption-change-descendant-display-type.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/table-caption-change-descendant-display-type.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/table-caption-change-descendant-display-type.html)
- [table-caption-inline-block-remove-child.html](https://wpt.fyi/results/css/css-multicol/crashtests/table-caption-inline-block-remove-child.html "css/css-multicol/crashtests/table-caption-inline-block-remove-child.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/table-caption-inline-block-remove-child.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/table-caption-inline-block-remove-child.html)
- [remove-block-beside-spanner-in-inline-crash.html](https://wpt.fyi/results/css/css-multicol/remove-block-beside-spanner-in-inline-crash.html "css/css-multicol/remove-block-beside-spanner-in-inline-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/remove-block-beside-spanner-in-inline-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/remove-block-beside-spanner-in-inline-crash.html)
- [remove-inline-with-block-beside-spanners-crash.html](https://wpt.fyi/results/css/css-multicol/remove-inline-with-block-beside-spanners-crash.html "css/css-multicol/remove-inline-with-block-beside-spanners-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/remove-inline-with-block-beside-spanners-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/remove-inline-with-block-beside-spanners-crash.html)
- [remove-spanner-beside-spanner-in-inline-crash.html](https://wpt.fyi/results/css/css-multicol/remove-spanner-beside-spanner-in-inline-crash.html "css/css-multicol/remove-spanner-beside-spanner-in-inline-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/remove-spanner-beside-spanner-in-inline-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/remove-spanner-beside-spanner-in-inline-crash.html)
- [remove-transform-descendant-becomes-spanner.html](https://wpt.fyi/results/css/css-multicol/remove-transform-descendant-becomes-spanner.html "css/css-multicol/remove-transform-descendant-becomes-spanner.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/remove-transform-descendant-becomes-spanner.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/remove-transform-descendant-becomes-spanner.html)
- [spanning-legend-000-crash.html](https://wpt.fyi/results/css/css-multicol/spanning-legend-000-crash.html "css/css-multicol/spanning-legend-000-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/spanning-legend-000-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/spanning-legend-000-crash.html)
- [spanning-legend-001-crash.html](https://wpt.fyi/results/css/css-multicol/spanning-legend-001-crash.html "css/css-multicol/spanning-legend-001-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/spanning-legend-001-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/spanning-legend-001-crash.html)
- [toggle-spanner-float-crash.html](https://wpt.fyi/results/css/css-multicol/toggle-spanner-float-crash.html "css/css-multicol/toggle-spanner-float-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/toggle-spanner-float-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/toggle-spanner-float-crash.html)
- [abspos-after-spanner-static-pos.html](https://wpt.fyi/results/css/css-multicol/abspos-after-spanner-static-pos.html "css/css-multicol/abspos-after-spanner-static-pos.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/abspos-after-spanner-static-pos.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/abspos-after-spanner-static-pos.html)
- [abspos-after-spanner.html](https://wpt.fyi/results/css/css-multicol/abspos-after-spanner.html "css/css-multicol/abspos-after-spanner.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/abspos-after-spanner.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/abspos-after-spanner.html)
- [abspos-containing-block-outside-spanner.html](https://wpt.fyi/results/css/css-multicol/abspos-containing-block-outside-spanner.html "css/css-multicol/abspos-containing-block-outside-spanner.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/abspos-containing-block-outside-spanner.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/abspos-containing-block-outside-spanner.html)
- [change-transform-in-spanner.html](https://wpt.fyi/results/css/css-multicol/change-transform-in-spanner.html "css/css-multicol/change-transform-in-spanner.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/change-transform-in-spanner.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/change-transform-in-spanner.html)
- [nested-with-padding-and-spanner.html](https://wpt.fyi/results/css/css-multicol/nested-with-padding-and-spanner.html "css/css-multicol/nested-with-padding-and-spanner.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/nested-with-padding-and-spanner.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/nested-with-padding-and-spanner.html)
- [orthogonal-writing-mode-spanner.html](https://wpt.fyi/results/css/css-multicol/orthogonal-writing-mode-spanner.html "css/css-multicol/orthogonal-writing-mode-spanner.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/orthogonal-writing-mode-spanner.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/orthogonal-writing-mode-spanner.html)
- [remove-inline-with-block-beside-spanners.html](https://wpt.fyi/results/css/css-multicol/remove-inline-with-block-beside-spanners.html "css/css-multicol/remove-inline-with-block-beside-spanners.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/remove-inline-with-block-beside-spanners.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/remove-inline-with-block-beside-spanners.html)
- [replaced-content-spanner-auto-width.html](https://wpt.fyi/results/css/css-multicol/replaced-content-spanner-auto-width.html "css/css-multicol/replaced-content-spanner-auto-width.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/replaced-content-spanner-auto-width.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/replaced-content-spanner-auto-width.html)
- [spanner-in-child-after-parallel-flow-001.html](https://wpt.fyi/results/css/css-multicol/spanner-in-child-after-parallel-flow-001.html "css/css-multicol/spanner-in-child-after-parallel-flow-001.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/spanner-in-child-after-parallel-flow-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/spanner-in-child-after-parallel-flow-001.html)
- [spanner-in-child-after-parallel-flow-002.html](https://wpt.fyi/results/css/css-multicol/spanner-in-child-after-parallel-flow-002.html "css/css-multicol/spanner-in-child-after-parallel-flow-002.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/spanner-in-child-after-parallel-flow-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/spanner-in-child-after-parallel-flow-002.html)
- [spanner-in-child-after-parallel-flow-003.html](https://wpt.fyi/results/css/css-multicol/spanner-in-child-after-parallel-flow-003.html "css/css-multicol/spanner-in-child-after-parallel-flow-003.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/spanner-in-child-after-parallel-flow-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/spanner-in-child-after-parallel-flow-003.html)
- [spanner-in-child-after-parallel-flow-004.html](https://wpt.fyi/results/css/css-multicol/spanner-in-child-after-parallel-flow-004.html "css/css-multicol/spanner-in-child-after-parallel-flow-004.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/spanner-in-child-after-parallel-flow-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/spanner-in-child-after-parallel-flow-004.html)
- [spanner-in-opacity.html](https://wpt.fyi/results/css/css-multicol/spanner-in-opacity.html "css/css-multicol/spanner-in-opacity.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/spanner-in-opacity.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/spanner-in-opacity.html)
- [going-out-of-flow-after-spanner.html](https://wpt.fyi/results/css/css-multicol/going-out-of-flow-after-spanner.html "css/css-multicol/going-out-of-flow-after-spanner.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/going-out-of-flow-after-spanner.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/going-out-of-flow-after-spanner.html)
- [inline-with-spanner-in-overflowed-container-before-multicol-float.html](https://wpt.fyi/results/css/css-multicol/crashtests/inline-with-spanner-in-overflowed-container-before-multicol-float.html "css/css-multicol/crashtests/inline-with-spanner-in-overflowed-container-before-multicol-float.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/inline-with-spanner-in-overflowed-container-before-multicol-float.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/inline-with-spanner-in-overflowed-container-before-multicol-float.html)
- [spanner-in-overflowed-clipped-container.html](https://wpt.fyi/results/css/css-multicol/crashtests/spanner-in-overflowed-clipped-container.html "css/css-multicol/crashtests/spanner-in-overflowed-clipped-container.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/spanner-in-overflowed-clipped-container.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/spanner-in-overflowed-clipped-container.html)
- [spanner-in-overflowed-container-before-inline-content.html](https://wpt.fyi/results/css/css-multicol/crashtests/spanner-in-overflowed-container-before-inline-content.html "css/css-multicol/crashtests/spanner-in-overflowed-container-before-inline-content.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/spanner-in-overflowed-container-before-inline-content.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/spanner-in-overflowed-container-before-inline-content.html)
- [spanner-inside-inline-in-overflowed-container.html](https://wpt.fyi/results/css/css-multicol/crashtests/spanner-inside-inline-in-overflowed-container.html "css/css-multicol/crashtests/spanner-inside-inline-in-overflowed-container.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/spanner-inside-inline-in-overflowed-container.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/spanner-inside-inline-in-overflowed-container.html)
- [column-span-valid.html](https://wpt.fyi/results/css/css-multicol/parsing/column-span-valid.html "css/css-multicol/parsing/column-span-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/parsing/column-span-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/parsing/column-span-valid.html)
- [column-span-computed.html](https://wpt.fyi/results/css/css-multicol/parsing/column-span-computed.html "css/css-multicol/parsing/column-span-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/parsing/column-span-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/parsing/column-span-computed.html)
- [getclientrects-000.html](https://wpt.fyi/results/css/css-multicol/getclientrects-000.html "css/css-multicol/getclientrects-000.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/getclientrects-000.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/getclientrects-000.html)
- [getclientrects-001.html](https://wpt.fyi/results/css/css-multicol/getclientrects-001.html "css/css-multicol/getclientrects-001.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/getclientrects-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/getclientrects-001.html)

------------------------------------------------------------------------

## 7. Filling Columns

There are two strategies for filling columns: columns can either be
balanced, or not. If columns are balanced, user agents should try to
minimize variations in column height, while honoring forced breaks,
[widows](https://drafts.csswg.org/css-break-4/#propdef-widows) and
[orphans](https://drafts.csswg.org/css-break-3/#propdef-orphans), and other properties that may
affect column heights. If columns are not balanced, they are filled
sequentially; some columns may end up partially filled, or with no
content at all.

### 7.1. Column Balancing: the [column-fill property]
Name:

[column-fill]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

auto
[\|](https://drafts.csswg.org/css-values-4/#comb-one) balance [\|] balance-all

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

balance

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

multicol containers

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

This property specifies whether content in a [multi-column
line](#multi-column-line)
that does *not* immediately precede a
[spanner](#multi-column-spanner) is balanced across columns or not.

Tests

- [always-balancing-before-column-span.html](https://wpt.fyi/results/css/css-multicol/always-balancing-before-column-span.html "css/css-multicol/always-balancing-before-column-span.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/always-balancing-before-column-span.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/always-balancing-before-column-span.html)
- [no-balancing-after-column-span.html](https://wpt.fyi/results/css/css-multicol/no-balancing-after-column-span.html "css/css-multicol/no-balancing-after-column-span.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/no-balancing-after-column-span.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/no-balancing-after-column-span.html)

The values are:

[balance]
: Balance content equally between columns, as far as possible. In
 fragmented contexts, only the last fragment is balanced.
 Tests
 - [multicol-fill-000.xht](https://wpt.fyi/results/css/css-multicol/multicol-fill-000.xht "css/css-multicol/multicol-fill-000.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-fill-000.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-fill-000.xht)
 - [multicol-fill-001.xht](https://wpt.fyi/results/css/css-multicol/multicol-fill-001.xht "css/css-multicol/multicol-fill-001.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-fill-001.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-fill-001.xht)
 - [column-fill-invalid.html](https://wpt.fyi/results/css/css-multicol/parsing/column-fill-invalid.html "css/css-multicol/parsing/column-fill-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/parsing/column-fill-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/parsing/column-fill-invalid.html)
 - [column-fill-valid.html](https://wpt.fyi/results/css/css-multicol/parsing/column-fill-valid.html "css/css-multicol/parsing/column-fill-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/parsing/column-fill-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/parsing/column-fill-valid.html)
 - [column-fill-computed.html](https://wpt.fyi/results/css/css-multicol/parsing/column-fill-computed.html "css/css-multicol/parsing/column-fill-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/parsing/column-fill-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/parsing/column-fill-computed.html)
 - [column-fill-balance-orthog-block-001.html](https://wpt.fyi/results/css/css-multicol/column-fill-balance-orthog-block-001.html "css/css-multicol/column-fill-balance-orthog-block-001.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/column-fill-balance-orthog-block-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/column-fill-balance-orthog-block-001.html)
 - [column-balancing-paged-001-print.html](https://wpt.fyi/results/css/css-multicol/column-balancing-paged-001-print.html "css/css-multicol/column-balancing-paged-001-print.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/column-balancing-paged-001-print.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/column-balancing-paged-001-print.html)
 - [multicol-fill-balance-001.xht](https://wpt.fyi/results/css/css-multicol/multicol-fill-balance-001.xht "css/css-multicol/multicol-fill-balance-001.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-fill-balance-001.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-fill-balance-001.xht)
 - [multicol-fill-balance-002.html](https://wpt.fyi/results/css/css-multicol/multicol-fill-balance-002.html "css/css-multicol/multicol-fill-balance-002.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-fill-balance-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-fill-balance-002.html)
 - [multicol-fill-balance-003.html](https://wpt.fyi/results/css/css-multicol/multicol-fill-balance-003.html "css/css-multicol/multicol-fill-balance-003.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-fill-balance-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-fill-balance-003.html)
 - [multicol-fill-balance-004.html](https://wpt.fyi/results/css/css-multicol/multicol-fill-balance-004.html "css/css-multicol/multicol-fill-balance-004.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-fill-balance-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-fill-balance-004.html)
 - [multicol-fill-balance-005.html](https://wpt.fyi/results/css/css-multicol/multicol-fill-balance-005.html "css/css-multicol/multicol-fill-balance-005.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-fill-balance-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-fill-balance-005.html)
 - [multicol-fill-balance-006.html](https://wpt.fyi/results/css/css-multicol/multicol-fill-balance-006.html "css/css-multicol/multicol-fill-balance-006.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-fill-balance-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-fill-balance-006.html)
 - [multicol-fill-balance-007.html](https://wpt.fyi/results/css/css-multicol/multicol-fill-balance-007.html "css/css-multicol/multicol-fill-balance-007.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-fill-balance-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-fill-balance-007.html)
 - [multicol-fill-balance-008.html](https://wpt.fyi/results/css/css-multicol/multicol-fill-balance-008.html "css/css-multicol/multicol-fill-balance-008.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-fill-balance-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-fill-balance-008.html)
 - [multicol-fill-balance-009.html](https://wpt.fyi/results/css/css-multicol/multicol-fill-balance-009.html "css/css-multicol/multicol-fill-balance-009.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-fill-balance-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-fill-balance-009.html)
 - [multicol-fill-balance-010.html](https://wpt.fyi/results/css/css-multicol/multicol-fill-balance-010.html "css/css-multicol/multicol-fill-balance-010.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-fill-balance-010.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-fill-balance-010.html)
 - [multicol-fill-balance-011.html](https://wpt.fyi/results/css/css-multicol/multicol-fill-balance-011.html "css/css-multicol/multicol-fill-balance-011.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-fill-balance-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-fill-balance-011.html)
 - [multicol-fill-balance-012.html](https://wpt.fyi/results/css/css-multicol/multicol-fill-balance-012.html "css/css-multicol/multicol-fill-balance-012.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-fill-balance-012.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-fill-balance-012.html)
 - [multicol-fill-balance-013.html](https://wpt.fyi/results/css/css-multicol/multicol-fill-balance-013.html "css/css-multicol/multicol-fill-balance-013.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-fill-balance-013.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-fill-balance-013.html)
 - [multicol-fill-balance-014.html](https://wpt.fyi/results/css/css-multicol/multicol-fill-balance-014.html "css/css-multicol/multicol-fill-balance-014.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-fill-balance-014.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-fill-balance-014.html)
 - [multicol-fill-balance-015.html](https://wpt.fyi/results/css/css-multicol/multicol-fill-balance-015.html "css/css-multicol/multicol-fill-balance-015.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-fill-balance-015.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-fill-balance-015.html)
 - [multicol-fill-balance-016.html](https://wpt.fyi/results/css/css-multicol/multicol-fill-balance-016.html "css/css-multicol/multicol-fill-balance-016.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-fill-balance-016.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-fill-balance-016.html)
 - [multicol-fill-balance-018.html](https://wpt.fyi/results/css/css-multicol/multicol-fill-balance-018.html "css/css-multicol/multicol-fill-balance-018.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-fill-balance-018.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-fill-balance-018.html)
 - [multicol-fill-balance-019.html](https://wpt.fyi/results/css/css-multicol/multicol-fill-balance-019.html "css/css-multicol/multicol-fill-balance-019.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-fill-balance-019.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-fill-balance-019.html)
 - [multicol-fill-balance-020.html](https://wpt.fyi/results/css/css-multicol/multicol-fill-balance-020.html "css/css-multicol/multicol-fill-balance-020.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-fill-balance-020.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-fill-balance-020.html)
 - [multicol-fill-balance-021.html](https://wpt.fyi/results/css/css-multicol/multicol-fill-balance-021.html "css/css-multicol/multicol-fill-balance-021.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-fill-balance-021.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-fill-balance-021.html)
 - [multicol-fill-balance-022.html](https://wpt.fyi/results/css/css-multicol/multicol-fill-balance-022.html "css/css-multicol/multicol-fill-balance-022.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-fill-balance-022.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-fill-balance-022.html)
 - [multicol-fill-balance-023.html](https://wpt.fyi/results/css/css-multicol/multicol-fill-balance-023.html "css/css-multicol/multicol-fill-balance-023.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-fill-balance-023.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-fill-balance-023.html)
 - [multicol-fill-balance-024.html](https://wpt.fyi/results/css/css-multicol/multicol-fill-balance-024.html "css/css-multicol/multicol-fill-balance-024.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-fill-balance-024.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-fill-balance-024.html)
 - [multicol-fill-balance-025.html](https://wpt.fyi/results/css/css-multicol/multicol-fill-balance-025.html "css/css-multicol/multicol-fill-balance-025.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-fill-balance-025.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-fill-balance-025.html)
 - [multicol-fill-balance-026.html](https://wpt.fyi/results/css/css-multicol/multicol-fill-balance-026.html "css/css-multicol/multicol-fill-balance-026.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-fill-balance-026.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-fill-balance-026.html)
 - [multicol-fill-balance-027.html](https://wpt.fyi/results/css/css-multicol/multicol-fill-balance-027.html "css/css-multicol/multicol-fill-balance-027.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-fill-balance-027.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-fill-balance-027.html)
 - [multicol-fill-balance-028.html](https://wpt.fyi/results/css/css-multicol/multicol-fill-balance-028.html "css/css-multicol/multicol-fill-balance-028.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-fill-balance-028.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-fill-balance-028.html)
 - [multicol-fill-balance-030.html](https://wpt.fyi/results/css/css-multicol/multicol-fill-balance-030.html "css/css-multicol/multicol-fill-balance-030.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-fill-balance-030.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-fill-balance-030.html)
 - [multicol-fill-balance-031.html](https://wpt.fyi/results/css/css-multicol/multicol-fill-balance-031.html "css/css-multicol/multicol-fill-balance-031.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-fill-balance-031.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-fill-balance-031.html)
 - [multicol-fill-balance-032.html](https://wpt.fyi/results/css/css-multicol/multicol-fill-balance-032.html "css/css-multicol/multicol-fill-balance-032.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-fill-balance-032.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-fill-balance-032.html)
 - [multicol-fill-balance-033.html](https://wpt.fyi/results/css/css-multicol/multicol-fill-balance-033.html "css/css-multicol/multicol-fill-balance-033.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-fill-balance-033.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-fill-balance-033.html)
 - [multicol-fill-balance-034.html](https://wpt.fyi/results/css/css-multicol/multicol-fill-balance-034.html "css/css-multicol/multicol-fill-balance-034.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-fill-balance-034.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-fill-balance-034.html)
 - [multicol-fill-balance-035.html](https://wpt.fyi/results/css/css-multicol/multicol-fill-balance-035.html "css/css-multicol/multicol-fill-balance-035.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-fill-balance-035.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-fill-balance-035.html)
 - [multicol-fill-balance-036.html](https://wpt.fyi/results/css/css-multicol/multicol-fill-balance-036.html "css/css-multicol/multicol-fill-balance-036.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-fill-balance-036.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-fill-balance-036.html)
 - [multicol-fill-balance-037.html](https://wpt.fyi/results/css/css-multicol/multicol-fill-balance-037.html "css/css-multicol/multicol-fill-balance-037.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-fill-balance-037.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-fill-balance-037.html)
 - [multicol-fill-balance-038.html](https://wpt.fyi/results/css/css-multicol/multicol-fill-balance-038.html "css/css-multicol/multicol-fill-balance-038.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-fill-balance-038.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-fill-balance-038.html)
 - [multicol-fill-balance-039.html](https://wpt.fyi/results/css/css-multicol/multicol-fill-balance-039.html "css/css-multicol/multicol-fill-balance-039.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-fill-balance-039.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-fill-balance-039.html)
 - [multicol-fill-balance-040.html](https://wpt.fyi/results/css/css-multicol/multicol-fill-balance-040.html "css/css-multicol/multicol-fill-balance-040.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-fill-balance-040.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-fill-balance-040.html)
 - [multicol-fill-balance-041.html](https://wpt.fyi/results/css/css-multicol/multicol-fill-balance-041.html "css/css-multicol/multicol-fill-balance-041.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-fill-balance-041.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-fill-balance-041.html)
 - [multicol-fill-balance-nested-000.html](https://wpt.fyi/results/css/css-multicol/multicol-fill-balance-nested-000.html "css/css-multicol/multicol-fill-balance-nested-000.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-fill-balance-nested-000.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-fill-balance-nested-000.html)

[balance-all]
: Balance content equally between columns, as far as possible. In
 fragmented contexts, all fragments are balanced.

[auto]
: fill columns sequentially
 Tests
 - [multicol-fill-auto-001.xht](https://wpt.fyi/results/css/css-multicol/multicol-fill-auto-001.xht "css/css-multicol/multicol-fill-auto-001.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-fill-auto-001.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-fill-auto-001.xht)
 - [multicol-fill-auto-002.xht](https://wpt.fyi/results/css/css-multicol/multicol-fill-auto-002.xht "css/css-multicol/multicol-fill-auto-002.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-fill-auto-002.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-fill-auto-002.xht)
 - [multicol-fill-auto-003.xht](https://wpt.fyi/results/css/css-multicol/multicol-fill-auto-003.xht "css/css-multicol/multicol-fill-auto-003.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-fill-auto-003.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-fill-auto-003.xht)
 - [multicol-fill-auto-004.html](https://wpt.fyi/results/css/css-multicol/multicol-fill-auto-004.html "css/css-multicol/multicol-fill-auto-004.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-fill-auto-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-fill-auto-004.html)
 - [multicol-fill-auto-block-children-001.xht](https://wpt.fyi/results/css/css-multicol/multicol-fill-auto-block-children-001.xht "css/css-multicol/multicol-fill-auto-block-children-001.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-fill-auto-block-children-001.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-fill-auto-block-children-001.xht)
 - [multicol-fill-auto-block-children-002.xht](https://wpt.fyi/results/css/css-multicol/multicol-fill-auto-block-children-002.xht "css/css-multicol/multicol-fill-auto-block-children-002.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-fill-auto-block-children-002.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-fill-auto-block-children-002.xht)
 - [multicol-fill-auto-block-children-003.html](https://wpt.fyi/results/css/css-multicol/multicol-fill-auto-block-children-003.html "css/css-multicol/multicol-fill-auto-block-children-003.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-fill-auto-block-children-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-fill-auto-block-children-003.html)
 - [columnfill-auto-max-height-001.html](https://wpt.fyi/results/css/css-multicol/columnfill-auto-max-height-001.html "css/css-multicol/columnfill-auto-max-height-001.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/columnfill-auto-max-height-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/columnfill-auto-max-height-001.html)
 - [columnfill-auto-max-height-002.html](https://wpt.fyi/results/css/css-multicol/columnfill-auto-max-height-002.html "css/css-multicol/columnfill-auto-max-height-002.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/columnfill-auto-max-height-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/columnfill-auto-max-height-002.html)
 - [columnfill-auto-max-height-003.html](https://wpt.fyi/results/css/css-multicol/columnfill-auto-max-height-003.html "css/css-multicol/columnfill-auto-max-height-003.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/columnfill-auto-max-height-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/columnfill-auto-max-height-003.html)
 - [max-height-stretch-relayout.html](https://wpt.fyi/results/css/css-multicol/max-height-stretch-relayout.html "css/css-multicol/max-height-stretch-relayout.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/max-height-stretch-relayout.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/max-height-stretch-relayout.html)
 - [multicol-fill-auto-005.html](https://wpt.fyi/results/css/css-multicol/multicol-fill-auto-005.html "css/css-multicol/multicol-fill-auto-005.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-fill-auto-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-fill-auto-005.html)

In continuous contexts, this property does not have any effect when
there are overflow columns.

In this example, an article only has
one short paragraph which fits on three lines. The three lines are
displayed in three different columns due to column balancing.

``` highlight
article {
 width: 60em;
 height: auto;
 columns: 4;
 column-fill: balance;
}
```

![Three lines displayed in three columns due to column
balancing.](images/column-balancing-one-paragraph.svg){a}

In this example, column balancing is
turned off, and the article has a height:

``` highlight
article {
 width: 60em;
 height: 4em;
 columns: 4;
 column-fill: auto;
}
```

As a result, the first column is filled with all content:

![No balancing so the whole text is shown in one
paragraph.](images/no-column-balancing-one-paragraph.svg){a}

In this example, an article has two
paragraphs: first a long one, then a shorter one. This code is applied:

``` highlight
article {
 width: 60em;
 height: auto;
 columns: 4;
 column-fill: balance;
}

p {
 break-after: column;
}
```

The shortest column height possible contains five lines of text. After
the column height has been established, columns are filled sequentially.
As a result, the third column is as high as the first two columns, while
the last column ends up being significantly shorter.

![Once column height is established, columns are filled
sequentially.](images/column-balancing-with-column-break.svg){a}

``` highlight
article {
 width: 60em;
 height: auto;
 columns: 4;
 column-fill: balance;
}
```

In this example, an article starts with an unbreakable figure which sets
the column height. Subsequent content is filled sequentially into the
remaining columns:

![Column height is established by the
figure.](images/column-balancing-with-figure.svg){a}

Tests relating to column balancing in combination with out-of-flow
elements.

- [column-balancing-with-span-and-oof-001.html](https://wpt.fyi/results/css/css-multicol/column-balancing-with-span-and-oof-001.html "css/css-multicol/column-balancing-with-span-and-oof-001.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/column-balancing-with-span-and-oof-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/column-balancing-with-span-and-oof-001.html)
- [column-balancing-with-span-and-oof-002.html](https://wpt.fyi/results/css/css-multicol/column-balancing-with-span-and-oof-002.html "css/css-multicol/column-balancing-with-span-and-oof-002.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/column-balancing-with-span-and-oof-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/column-balancing-with-span-and-oof-002.html)
- [forced-break-in-oof-in-column-balancing-nested.html](https://wpt.fyi/results/css/css-multicol/crashtests/forced-break-in-oof-in-column-balancing-nested.html "css/css-multicol/crashtests/forced-break-in-oof-in-column-balancing-nested.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/forced-break-in-oof-in-column-balancing-nested.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/forced-break-in-oof-in-column-balancing-nested.html)
- [forced-break-in-oof-in-column-balancing.html](https://wpt.fyi/results/css/css-multicol/crashtests/forced-break-in-oof-in-column-balancing.html "css/css-multicol/crashtests/forced-break-in-oof-in-column-balancing.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/forced-break-in-oof-in-column-balancing.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/forced-break-in-oof-in-column-balancing.html)

------------------------------------------------------------------------

Other tests relating to balancing

- [balance-extremely-tall-monolithic-content-crash.html](https://wpt.fyi/results/css/css-multicol/balance-extremely-tall-monolithic-content-crash.html "css/css-multicol/balance-extremely-tall-monolithic-content-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/balance-extremely-tall-monolithic-content-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/balance-extremely-tall-monolithic-content-crash.html)
- [column-balancing-with-overflow-auto-crash.html](https://wpt.fyi/results/css/css-multicol/column-balancing-with-overflow-auto-crash.html "css/css-multicol/column-balancing-with-overflow-auto-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/column-balancing-with-overflow-auto-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/column-balancing-with-overflow-auto-crash.html)
- [balance-break-avoidance-000.html](https://wpt.fyi/results/css/css-multicol/balance-break-avoidance-000.html "css/css-multicol/balance-break-avoidance-000.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/balance-break-avoidance-000.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/balance-break-avoidance-000.html)
- [balance-break-avoidance-001.html](https://wpt.fyi/results/css/css-multicol/balance-break-avoidance-001.html "css/css-multicol/balance-break-avoidance-001.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/balance-break-avoidance-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/balance-break-avoidance-001.html)
- [balance-break-avoidance-002.html](https://wpt.fyi/results/css/css-multicol/balance-break-avoidance-002.html "css/css-multicol/balance-break-avoidance-002.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/balance-break-avoidance-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/balance-break-avoidance-002.html)
- [balance-grid-container.html](https://wpt.fyi/results/css/css-multicol/balance-grid-container.html "css/css-multicol/balance-grid-container.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/balance-grid-container.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/balance-grid-container.html)
- [balance-orphans-widows-000.html](https://wpt.fyi/results/css/css-multicol/balance-orphans-widows-000.html "css/css-multicol/balance-orphans-widows-000.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/balance-orphans-widows-000.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/balance-orphans-widows-000.html)
- [balance-with-forced-break.html](https://wpt.fyi/results/css/css-multicol/crashtests/balance-with-forced-break.html "css/css-multicol/crashtests/balance-with-forced-break.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/balance-with-forced-break.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/balance-with-forced-break.html)
- [balancing-flex-item-trailing-margin-freeze.html](https://wpt.fyi/results/css/css-multicol/crashtests/balancing-flex-item-trailing-margin-freeze.html "css/css-multicol/crashtests/balancing-flex-item-trailing-margin-freeze.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/balancing-flex-item-trailing-margin-freeze.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/balancing-flex-item-trailing-margin-freeze.html)
- [balancing-tall-borders-freeze.html](https://wpt.fyi/results/css/css-multicol/crashtests/balancing-tall-borders-freeze.html "css/css-multicol/crashtests/balancing-tall-borders-freeze.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/crashtests/balancing-tall-borders-freeze.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/crashtests/balancing-tall-borders-freeze.html)

------------------------------------------------------------------------

## 8. Overflow

### 8.1. Overflow Inside Multicol Containers

Except for cases where this would cause a column break, content that
extends outside column boxes visibly overflows and is not clipped to the
[column box](#column-box).

 See [§ 5 Column Breaks](#column-breaks) for column
breaks and [§ 8.2 Pagination and Overflow Outside Multicol
Containers](#pagination-and-overflow-outside-multicol) for whether it is
clipped to the multi-column container's content box.

In this example, the image is wider
than the column:

![Content visibly overflows and is not clipped to the column
box.](images/image-overflow-not-clipped.svg){a}

- [multicol-block-no-clip-001.xht](https://wpt.fyi/results/css/css-multicol/multicol-block-no-clip-001.xht "css/css-multicol/multicol-block-no-clip-001.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-block-no-clip-001.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-block-no-clip-001.xht)
- [multicol-block-no-clip-002.xht](https://wpt.fyi/results/css/css-multicol/multicol-block-no-clip-002.xht "css/css-multicol/multicol-block-no-clip-002.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-block-no-clip-002.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-block-no-clip-002.xht)
- [multicol-clip-001.xht](https://wpt.fyi/results/css/css-multicol/multicol-clip-001.xht "css/css-multicol/multicol-clip-001.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-clip-001.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-clip-001.xht)
- [multicol-clip-002.xht](https://wpt.fyi/results/css/css-multicol/multicol-clip-002.xht "css/css-multicol/multicol-clip-002.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-clip-002.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-clip-002.xht)
- [multicol-clip-scrolled-content-001.html](https://wpt.fyi/results/css/css-multicol/multicol-clip-scrolled-content-001.html "css/css-multicol/multicol-clip-scrolled-content-001.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-clip-scrolled-content-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-clip-scrolled-content-001.html)
- [multicol-overflow-clip-auto-sized.html](https://wpt.fyi/results/css/css-multicol/multicol-overflow-clip-auto-sized.html "css/css-multicol/multicol-overflow-clip-auto-sized.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-overflow-clip-auto-sized.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-overflow-clip-auto-sized.html)
- [multicol-overflow-clip-positioned.html](https://wpt.fyi/results/css/css-multicol/multicol-overflow-clip-positioned.html "css/css-multicol/multicol-overflow-clip-positioned.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-overflow-clip-positioned.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-overflow-clip-positioned.html)
- [multicol-overflow-clip.html](https://wpt.fyi/results/css/css-multicol/multicol-overflow-clip.html "css/css-multicol/multicol-overflow-clip.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-overflow-clip.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-overflow-clip.html)
- [relative-child-overflowing-column-gap.html](https://wpt.fyi/results/css/css-multicol/relative-child-overflowing-column-gap.html "css/css-multicol/relative-child-overflowing-column-gap.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/relative-child-overflowing-column-gap.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/relative-child-overflowing-column-gap.html)
- [relative-child-overflowing-container.html](https://wpt.fyi/results/css/css-multicol/relative-child-overflowing-container.html "css/css-multicol/relative-child-overflowing-container.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/relative-child-overflowing-container.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/relative-child-overflowing-container.html)

### 8.2. Pagination and Overflow Outside Multicol Containers

Content and column rules that extend outside column boxes at the edges
of the multi-column container are clipped according to the
[overflow](https://drafts.csswg.org/css-overflow-3/#propdef-overflow) property.

A multicol container can have more columns than it has room for due to:

- a declaration that constrains the column height (e.g., using
 [height](https://drafts.csswg.org/css-sizing-3/#propdef-height) or
 [max-height](https://drafts.csswg.org/css-sizing-3/#propdef-max-height)). In this case, additional column
 boxes are created in the inline direction
- the size of the page. In this case, additional column boxes are moved
 to the next page(s).
- explicit column breaks. In this case, additional column boxes are
 created in the inline direction for continuous contexts and additional
 column boxes are moved to the next fragment(s) for fragmented media.
-

Tests

- [multicol-overflow-000.xht](https://wpt.fyi/results/css/css-multicol/multicol-overflow-000.xht "css/css-multicol/multicol-overflow-000.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-overflow-000.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-overflow-000.xht)
- [multicol-overflowing-001.xht](https://wpt.fyi/results/css/css-multicol/multicol-overflowing-001.xht "css/css-multicol/multicol-overflowing-001.xht")
 [[(live
 test)]](http://wpt.live/css/css-multicol/multicol-overflowing-001.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/multicol-overflowing-001.xht)

Tests to check that a scrollable container isn\'t split across multiple
columns.

- [overflow-unsplittable-001.html](https://wpt.fyi/results/css/css-multicol/overflow-unsplittable-001.html "css/css-multicol/overflow-unsplittable-001.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/overflow-unsplittable-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/overflow-unsplittable-001.html)
- [overflow-unsplittable-002.html](https://wpt.fyi/results/css/css-multicol/overflow-unsplittable-002.html "css/css-multicol/overflow-unsplittable-002.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/overflow-unsplittable-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/overflow-unsplittable-002.html)
- [overflow-unsplittable-003.html](https://wpt.fyi/results/css/css-multicol/overflow-unsplittable-003.html "css/css-multicol/overflow-unsplittable-003.html")
 [[(live
 test)]](http://wpt.live/css/css-multicol/overflow-unsplittable-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-multicol/overflow-unsplittable-003.html)

------------------------------------------------------------------------

Columns that appear outside the multicol container in continuous
contexts are called [overflow columns]. Overflow columns can affect the
height of the multicol container.

In this example, the height of the
multi-column container has been constrained to a maximum height. Also,
the style sheet specifies that overflowing content should be visible:

``` highlight
div {
 max-height: 5em;
 overflow: visible;
}
```

As a result, the number of columns is increased.

![An overflow column is created in the inline
direction.](images/height-constraint-overflow-inline.svg){a}

In continuous contexts overflow columns can affect the height of the
multicol container. In this example a column appears in the overflow
which has four lines of text. The multicol container is made tall enough
to accommodate this column.

![The final column is an overflow column yet is taller than the others.
The container is tall enough for this
column.](images/overflow-column-effects-height.svg){a}

In fragmented contexts, the overflow
content goes into columns in subsequent fragments. Given the same
content as in example 31 and a page box that only has room for five
lines of formatted text, this would appear on the first page:

![The first three paragraphs appear on page
one.](images/pagination-overflow-page1.svg){a}

Assuming column balancing, this would appear on the second page:

![The overflow column is moved onto page
two.](images/pagination-overflow-page2.svg){a}

In this example, explicit column
breaks are generated after paragraphs:

``` highlight
p {
 break-after: column;
}
```

As a result, the number of columns increases and the extra columns are
added in the inline direction:

![An overflow column is created in the inline
direction.](images/height-constraint-column-break-overflow-inline.svg){a}

In [paged
media](https://drafts.csswg.org/mediaqueries-5/#paged-media), extra columns are shown on the next page. Given the
same code as the previous example, the last paragraph appears on the
second page. This would appear on the first page:

![The first three paragraphs appear on page
one.](images/pagination-column-break-overflow-page1.svg){a}

This would appear on the second page:

![The overflow column is moved onto page
two.](images/pagination-column-break-overflow-page2.svg){a}

Due to column balancing, the last paragraph is split across three
columns.

## [Appendix B. Changes]
This appendix is *informative*.

### [Changes from the [Candidate Recommendation (CR) of 16 May 2024](https://www.w3.org/TR/2024/CR-css-multicol-1-20240516/)]
- Removed the special case of
 [column-rule-width](#propdef-column-rule-width) having a computed value of
 [0] when
 [column-rule-style](#propdef-column-rule-style) is
 [none](https://drafts.csswg.org/css-backgrounds-3/#valdef-line-style-none) or
 [hidden](https://drafts.csswg.org/css-backgrounds-3/#valdef-line-style-hidden). ([Issue
 11494](https://github.com/w3c/csswg-drafts/issues/11494))

### [Changes from the [Candidate Recommendation (CR) of 12 October 2021](https://www.w3.org/TR/2021/CR-css-multicol-1-20211012/)]
- Added the text \"and there is nothing between the spanning element and
 [multicol
 container](#multi-column-container) that establishes a containing block for fixed
 position descendants.\" [Resolved 9 Mar
 2022](https://github.com/w3c/csswg-drafts/issues/6805#issuecomment-1063159219)

### [Changes from the [Working Draft (WD) of 12 February 2021](https://www.w3.org/TR/2021/WD-css-multicol-1-20210212/)]
- Added the text \"Out-of-flow descendants of a multi-column container
 do affect column balancing, and the block-size of the multi-column
 container.\" [Resolved 12 May
 2021](https://github.com/w3c/csswg-drafts/issues/6279#issuecomment-839912199)
- Added the text, \"The margins of two spanners separated only by an
 absolutely positioned item will collapse with each other, as
 absolutely positioned items do not create column boxes.\" [Resolved 12
 May
 2021](https://github.com/w3c/csswg-drafts/issues/6265#issuecomment-839909999)
- Adds an accessibility considerations section. [Request from APA after
 review.](https://github.com/w3c/csswg-drafts/issues/6283)
- Adds a note and example to make clear the manner in which columns are
 laid out in vertical writing modes. [Request from i18n WG after
 review.](https://github.com/w3c/csswg-drafts/issues/6301)

### [Changes from the [Working Draft (WD) of 15 October 2019](https://www.w3.org/TR/2019/WD-css-multicol-1-20191015/)]
- Added the text \"The spanner becomes the containing block for
 absolutely positioned boxes inside the spanner where the spanning
 element establishes a containing block, otherwise the containing block
 chain goes to the multicol container.\". [Resolved 23 Oct
 2020](https://github.com/w3c/csswg-drafts/issues/5612#issuecomment-715369246)
- Adding the text \"This property specifies whether content in a
 multi-column line that does *not* immediately precede a spanner is
 balanced across columns or not.\" [Resolved 29 April
 2020](https://github.com/w3c/csswg-drafts/issues/4689#issuecomment-621281467)

### [Changes from the [Working Draft (WD) of 28 May 2018](https://www.w3.org/TR/2018/WD-css-multicol-1-20180528/)]
- Removed the non-normative text \"However, as described below, setting
 both the width and number of columns rarely makes sense.\" Editorial
 16 Sep 2019, [issue
 4291](https://github.com/w3c/csswg-drafts/issues/4291).
- Added the paragraph, \"Spanners are block-level boxes therefore the
 margins of two adjacent spanners will collapse with each other. As
 column boxes establish a new [block formatting
 context](https://drafts.csswg.org/css-display-4/#block-formatting-context), margins on elements inside a column box will not
 collapse with the margin of a spanner.\" [Resolved 22 Oct
 2018](https://github.com/w3c/csswg-drafts/issues/2203#issuecomment-431783027),
 see also the resolution for [issue
 2582](https://github.com/w3c/csswg-drafts/issues/2582#issuecomment-402619872).
- Clarified the spec to explain that a spanning element is taken
 out-of-flow, leaving a forced break. Added the paragraph, \"A spanning
 element is taken out-of-flow, leaving a forced break. This does not
 affect the painting order of the spanning element.\" [Resolved 28 Feb
 2019](https://github.com/w3c/csswg-drafts/issues/1072#issuecomment-468087733).
- Moved the definition of the
 [column-gap](https://drafts.csswg.org/css-gaps-1/#propdef-column-gap) property to
 [\[CSS3-ALIGN\]](#biblio-css3-align "CSS Box Alignment Module Level 3")
 and added a paragraph detailing the specifics of
 [column-gap] in multicol:\
 \"In a multi-column formatting context the used value of normal for
 the column-gap property is 1em. This ensures columns are readable when
 the initial values are used. If there is a column rule between
 columns, it will appear in the middle of the gap.\" [Resolved 4 June
 2019.](https://github.com/w3c/csswg-drafts/issues/3641)
- Reworded the section [The multi-column
 model](#the-multi-column-model), based on input from Morten Stenshorne
 in [issue
 2203](https://github.com/w3c/csswg-drafts/issues/2203#issuecomment-431695940).
- Removed the at-risk marker from the length-percentage value for
 [column-gap](https://drafts.csswg.org/css-gaps-1/#propdef-column-gap). [Resolved 4 June
 2019.](https://github.com/w3c/csswg-drafts/issues/3988)
- Updated the introduction to remove mention of the benefits of multicol
 over using tables for layout and instead refer to the unique
 characteristics of multicol. Editorial change referenced in [issue
 3654](https://github.com/w3c/csswg-drafts/issues/3654).
- Changed the sentence added in the pseudo-algorithm section after the 7
 Jan 2016 resolution, to refer to *columns* and not *tracks* as tracks
 are not defined in this specification. Resolved [13 March
 2019](https://github.com/w3c/csswg-drafts/issues/3649#issuecomment-472505520).
- Changes and clarifications to the SVG images used in the
 specification.
- Changed syntax to use bracketed range notation to reflect the prose
 restrictions on negative/non-zero values.

### [Changes from the [Working Draft (WD) of 5 October 2017](https://www.w3.org/TR/2017/WD-css-multicol-1-20171005/)]
- Changed references to paged media to refer to fragmented contexts.
 Resolved [12 Apr
 2018](https://github.com/w3c/csswg-drafts/issues/1746#issuecomment-380731574).
- Changed a line regarding the `column-fill` property:\
 "In continuous media, this property does not have any effect in
 overflow columns."\
 To:\
 "In continuous media, this property does not have any effect when
 there are overflow columns." [Resolved: 12 Apr
 2018](https://github.com/w3c/csswg-drafts/issues/2549)
- Add a line of text plus an example to show that overflow columns can
 affect the multicol container height. [Resolved: 12 Apr
 2018](https://github.com/w3c/csswg-drafts/issues/1745)
- Replaced the HTML mock-up examples with SVG versions, as the examples
 were unclear. [Issue
 1087](https://github.com/w3c/csswg-drafts/issues/1087).
- Changed the value of normal for column-gap to be 1em, rather than a
 UA-specified length with a suggestion of 1em. [Resolved: 4 Apr
 2018](https://github.com/w3c/csswg-drafts/issues/2145#issuecomment-378781507)
- Clarified that negative values are not allowed for column-width, and
 that while 0 may be specified, used values will be clamped to a
 minimum of 1px. [Resolved: 14 Mar
 2018](https://github.com/w3c/csswg-drafts/issues/1741#issuecomment-373091628)
- Clarified that where there is a spanning element content is
 automatically balanced across all columns in the immediately preceding
 column row before the element appears. [Resolved: 9 Nov
 2017](https://github.com/w3c/csswg-drafts/issues/1075)
- Added clarification plus an additional example that spanning elements
 may be lower the first level of descendants, and that in the case of
 margins, borders and padding on the element containing the spanning,
 this would be drawn above the spanner. [Resolved: 8 Nov
 2017](https://github.com/w3c/csswg-drafts/issues/1072#issuecomment-342668025)
- Changed the sentence "Column rules are painted in the inline content
 layer, but below all inline content inside the multicol element." to
 "Column rules are painted just above the border of the multicol
 element. For scrollable multicol elements, note that while the border
 and background of the multicol element obviously aren't scrolled, the
 rules need to scroll along with the columns." [Resolved: 7 Nov
 2017](https://github.com/w3c/csswg-drafts/issues/1739#issuecomment-342659978)
- Under section The Multi-column Model, removed two sentences "That is,
 column boxes behave like block-level, table cell, and inline-block
 boxes as per CSS 2.1, section 10.1, item 2 CSS21. However, column
 boxes do not establish block container boxes for elements with
 [position: fixed or position:
 absolute](https://drafts.csswg.org/css-position-3/#propdef-position).". These were replaced with a clarification
 about the principal box and a new example showing how abspos elements
 refer to the multicol container. [Resolved: 7 Nov
 2017](https://github.com/w3c/csswg-drafts/issues/1738#issuecomment-342661881)
- Removed the sentence \"To indicate where column breaks should (or
 should not) appear, new keyword values are introduced.\" and following
 example (Example 7 in the WD published [5 Oct
 2017](https://www.w3.org/TR/2017/WD-css-multicol-1-20171005/)) as the
 multicol specification no longer introduces these properties.
 [Editorial](https://github.com/w3c/csswg-drafts/issues/1966)
- Changed how we reference the element we have applied multicol to from
 multi-column or multicol "element" to multi-column or multicol
 "container". [Resolved: 22 November
 2017](https://github.com/w3c/csswg-drafts/issues/1965)
- Removed the example which stated \"If a tall image is moved to a
 column on the next page to find room for it, its natural column may be
 left empty. If so, the column is still considered to have content for
 the purpose of deciding if the column rule should be drawn.\"
 [Resolved: 7 September
 2017](https://github.com/w3c/csswg-drafts/issues/1740)

### [Changes from the [Candidate Recommendation (CR) of 12 April 2011](https://www.w3.org/TR/2011/CR-css3-multicol-20110412/).]
- Added July 2016 resolution to change the track size floor to a
 required UA-specified value, consistent with the CSS Grid spec.
 [Resolved: 7 Jan
 2016](https://lists.w3.org/Archives/Public/www-style/2016Jan/0031.html)
- Remove the restriction about overflow columns only being in continuous
 media in the statement that
 [column-fill](#propdef-column-fill) has no effect on overflow columns.
 [Resolved: September
 2013](https://lists.w3.org/Archives/Public/www-style/2013Sep/0471.html).
- Added keyword balance-all and examples to demonstrate how this should
 work. [Resolved: September
 2013](https://lists.w3.org/Archives/Public/www-style/2013Sep/0471.html).
- The pseudo-algorithm has been revised on a number of occasions.
 [Latest change Feb
 2013](https://lists.w3.org/Archives/Public/www-style/2013Feb/0471.html).
- Clarified that properties
 [columns](#propdef-columns),
 [column-width](#propdef-column-width),
 [column-count](#propdef-column-count) \"apply to block containers\".
 [Ref: Feb
 2013](https://lists.w3.org/Archives/Public/www-style/2013Feb/0536.html).
- Breaking properties have been moved from this specification to the
 [CSS Fragmentation Module](https://www.w3.org/TR/css-break-3/).
- Change to
 [column-fill](#propdef-column-fill) wording to clarify that
 [column-fill] is honored
 before page breaks. [Ref: Jan
 2012](https://lists.w3.org/Archives/Public/www-style/2012Jan/0393.html).
- Amended example and text to clarify what happens with margin
 collapsing and spanning elements. [Ref: Oct
 2013](https://lists.w3.org/Archives/Public/www-style/2013Oct/0247.html).
- Clarification that
 [column-rule-width](#propdef-column-rule-width) does not alter the size or
 placement of columns. [Ref: Sep
 2013](https://lists.w3.org/Archives/Public/www-style/2013Sep/0550.html).
- Added that each column spanning element establishes a separate BFC
 margins between them collapse. [Ref: Dec
 2011](https://lists.w3.org/Archives/Public/www-style/2011Dec/0262.html).
- Column rules are painted in the inline content layer, but below all
 inline content inside the multicol. [Ref: Feb
 2013](https://lists.w3.org/Archives/Public/www-style/2013Feb/0363.html).
- Clarify that
 [column-span](#propdef-column-span) causes the element to establish a
 formatting context even if it is not in a multicol.
- Column spanners do not always establish a *block* formatting context.
- Allow
 [column-gap](https://drafts.csswg.org/css-gaps-1/#propdef-column-gap) to accept
 [\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage) instead of just
 [\<length\>](https://drafts.csswg.org/css-values-4/#length-value)
- [column-width](#propdef-column-width) and
 [column-count](#propdef-column-count) applies to [block
 containers](https://drafts.csswg.org/css-display-4/#block-container) except [table wrapper
 boxes](https://drafts.csswg.org/css-tables-3/#table-wrapper-box).
- Content that overflows columns is not clipped.

## [Privacy Considerations]
Multicol introduces no new privacy leaks.

## [Security Considerations]
Multicol introduces no new security considerations.

## [Accessibility Considerations]
Setting container height and line length can pose challenges for people
with visual or cognitive disabilities. See [WCAG Success Criterion
1.4.10 Reflow](https://www.w3.org/WAI/WCAG21/Understanding/reflow.html)
and [WCAG 1.4.8 Visual
Presentation](https://www.w3.org/WAI/WCAG21/quickref/#visual-presentation)
to understand user needs.

## [ Acknowledgments]
This document is based on several older proposals and comments on older
proposals. Contributors include:

Alex Mogilevsky, Andy Clarke, Anton Prowse, Bert Bos, Björn Höhrmann,
Cédric Savarese, Chris Lilley, Chris Wilson, Daniel Glazman and Dave
Raggett, David Hyatt, David Singer, David Woolley, Elika Etemad,
Giovanni Campagna, Ian Hickson. Joost de Valk, Kevin Lawver, L. David
Baron, Markus Mielke, Melinda Grant, Michael Day, Morten Stenshorne,
Øyvind Stenhaug, Peter Linss, Peter-Paul Koch, Robert O'Callahan, Robert
Stevahn, Sergey Genkin, Shelby Moore, Steve Zilles, Sylvain Galineau,
Tantek Çelik, Till Halbach
