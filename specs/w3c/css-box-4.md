## 1. Introduction

*This subsection is not normative.*

CSS describes how each element and each string of text in a source
document is laid out by transforming the [element
tree](https://drafts.csswg.org/css-display-4/#element-tree) into a set of
[boxes](https://drafts.csswg.org/css-display-4/#box), whose size, position, and stacking level on the
[canvas](https://w3c.github.io/svgwg/svg2-draft/coords.html#TermCanvas) depend on the values of their CSS properties.

 [CSS Cascading and
Inheritance](https://www.w3.org/TR/css-cascade/) describes how
properties are assigned to elements in the box tree, while [CSS Display
3 § 1 Introduction](https://drafts.csswg.org/css-display-3/#intro)
describes how the [element
tree](https://drafts.csswg.org/css-display-4/#element-tree) is transformed into the [box
tree](https://drafts.csswg.org/css-display-4/#box-tree).

Each CSS
[box](https://drafts.csswg.org/css-display-4/#box) has a rectangular content area, a band of padding
around the content, a border around the padding, and a margin outside
the border. The [sizing
properties](https://drafts.csswg.org/css-sizing-3/#sizing-property)
[\[css-sizing-3\]](#biblio-css-sizing-3 "CSS Box Sizing Module Level 3"),
together with various other properties that control layout, define the
size of the content area. The box styling
properties---​[padding](#propdef-padding) and its longhands,
[border](https://drafts.csswg.org/css-borders-4/#propdef-border) and its longhands, and
[margin](#propdef-margin) and its longhands---​define the sizes of these
other areas. Margins and padding are defined in this module; borders are
defined in
[\[css-backgrounds-3\]](#biblio-css-backgrounds-3 "CSS Backgrounds and Borders Module Level 3").

 This module [originally
contained](https://www.w3.org/TR/2018/WD-css3-box-20180731/) the CSS
Level 3 specification prose relating to box generation (now defined in
[\[css-display-3\]](#biblio-css-display-3 "CSS Display Module Level 3")),
the box model (defined here), as well as block layout (now only defined
in
[\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")
Chapters 9 and 10). Since its maintenance was put aside during the
development of CSS2.1, its prose was severely outdated by the time CSS2
Revision 1 was finally completed. Therefore, the block layout portion of
the prose has been retired, to be re-synched to
[CSS2](https://www.w3.org/TR/CSS2) and updated as input to a new Block
Layout module at some point in the future. It is being split apart from
this module and from the [CSS Display
Module](https://www.w3.org/TR/css-display/) both because of the
practical concern that it would be a huge amount of work and also in
recognition that CSS now has multiple layout models ([Flex
Layout](https://www.w3.org/TR/css-flexbox/), [Grid
Layout](https://www.w3.org/TR/css-grid/), [Positioned
Layout](https://www.w3.org/TR/css-position/), and [Table
Layout](https://www.w3.org/TR/css-tables/), in addition to Block Layout)
which each deserve their own parallel module.

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

### 1.2. Module Interactions

This module replaces the definitions of the margin and padding
properties defined in
[\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")
sections 8.1, 8.2, 8.3 (but not 8.3.1), and 8.4.

All properties in this module apply to the
[::first-line](https://drafts.csswg.org/css-pseudo-4/#selectordef-first-line) and
[::first-letter](https://drafts.csswg.org/css-pseudo-4/#selectordef-first-letter) pseudo-elements.

## 2. The CSS Box Model

Each box has a [content area] (which contains its content---​text, descendant
boxes, an image or other [replaced
element](https://drafts.csswg.org/css-display-4/#replaced-element) content, etc.) and optional surrounding
[padding], [border], and [margin
areas]; the size of each area is specified by corresponding
properties, and can be zero (or in the case of margins, negative). The
following diagram shows how these areas relate and the terminology used
to refer to the various parts of the box:

![Diagram of a typical box, showing the content, padding, border and
margin areas](images/box.png){width="461"}

The various areas and edges of a typical box.

The background of the content, padding, and border areas of a box is
specified by its
[background](https://drafts.csswg.org/css-backgrounds-3/#propdef-background) properties. The border area can
additionally be painted with a border style using the
[border](https://drafts.csswg.org/css-borders-4/#propdef-border) properties. Margins are always
transparent. See
[\[css-backgrounds-3\]](#biblio-css-backgrounds-3 "CSS Backgrounds and Borders Module Level 3").

The margin, border, and padding can be broken down into top, right,
bottom, and left segments, each of which can be controlled independently
by its corresponding property.

### 2.1. Boxes and Edges

The perimeter of each of the four areas (content, padding, border, and
margin) is called an [edge], and each
[edge](#box-box-edge) can be
broken down into a top, right, bottom, and left side. Thus each
[box](https://drafts.csswg.org/css-display-4/#box) has four [edges] each composed
of four sides:

[content edge] or [inner edge]
: The content edge surrounds the rectangle given by the width and
 height of the box, which often depend on the element's content
 and/or its [containing
 block](https://drafts.csswg.org/css-display-4/#containing-block) size. The four sides of the [content
 edge](#content-edge) together
 define the box's [content box].

[padding edge]
: The padding edge surrounds the box's padding. If the padding has
 zero width on a given side, the padding edge coincides with the
 content edge on that side. The four sides of the [padding
 edge](#padding-edge) together
 define the box's [padding box], which contains both the
 [content](#content-area) and
 [padding areas](#padding-area).

[border edge]
: The border edge surrounds the box's border. If the border has zero
 width on a given side, the border edge coincides with the padding
 edge on that side. The four sides of the [border
 edge](#border-edge) together
 define the box's [border box], which contains the box's
 [content](#content-area),
 [padding](#padding-area),
 and [border areas](#border-area).

[margin edge] or [outer edge]
: The margin edge surrounds the box's margin. If the margin has zero
 width on a given side, the margin edge coincides with the border
 edge on that side. The four sides of the [margin
 edge](#margin-edge) together
 define the box's [margin box], which contains the all of the box's
 [content](#content-area),
 [padding](#padding-area),
 [border](#border-area), and
 [margin areas](#margin-area).

Properties like
[border-radius](https://drafts.csswg.org/css-borders-4/#propdef-border-radius) can change the shape of the box's
[edges](#box-box-edge) as used
for painting and clipping (see [CSS Backgrounds 3 § 4.3 Corner
Clipping](https://drafts.csswg.org/css-backgrounds-3/#corner-clipping));
these effects typically do not affect layout however. To distinguish,
specifications can refer to the relevant [shaped edge]
or [unshaped edge]

### 2.2. Fragmentation

When a box
[fragments](https://www.w3.org/TR/css-break-4/#fragmentation-model)---​is
broken, as across lines or across pages, into separate [box
fragments](https://drafts.csswg.org/css-break-4/#box-fragment)---​each of its boxes ([content
box](#content-box), [padding
box](#padding-box), [border
box](#border-box), [margin
box](#margin-box)) also fragments.
How the content/padding/border/margin areas react to fragmentation is
specified in
[\[css-break-4\]](#biblio-css-break-4 "CSS Fragmentation Module Level 4")
and controlled by the
[box-decoration-break](https://drafts.csswg.org/css-break-4/#propdef-box-decoration-break) property.

### 2.3. Box-edge Keywords

The following [[\<box\>](#typedef-box)] CSS keywords are defined for use in
properties (such as
[transform-box](https://drafts.csswg.org/css-transforms-1/#propdef-transform-box) and
[background-clip](https://drafts.csswg.org/css-backgrounds-3/#propdef-background-clip)) that need to refer to various box
edges:

[content-box]
: Refers to the [content box](#content-box) or [content
 edge](#content-edge). (In an
 SVG context, treated as
 [fill-box](#valdef-box-fill-box).)

[padding-box]
: Refers to the [padding box](#padding-box) or [padding
 edge](#padding-edge). (In an
 SVG context, treated as
 [fill-box](#valdef-box-fill-box).)

[border-box]
: Refers to the [border box](#border-box) or [border
 edge](#border-edge). (In an
 SVG context, treated as
 [stroke-box](#valdef-box-stroke-box).)

[margin-box]
: Refers to the [margin box](#margin-box) or [margin
 edge](#margin-edge). (In an
 SVG context, treated as
 [stroke-box](#valdef-box-stroke-box).)

[fill-box]
: Refers to the [object bounding
 box](https://w3c.github.io/svgwg/svg2-draft/coords.html#TermObjectBoundingBox) or its edges. (In a CSS box context, treated as
 [content-box](#valdef-box-content-box).)

[stroke-box]
: Refers to the [stroke bounding
 box](https://w3c.github.io/svgwg/svg2-draft/coords.html#TermStrokeBoundingBox) or its edges. (In a CSS box context, treated as
 [border-box](#valdef-box-border-box).)

[view-box]

: Refers to the nearest [SVG
 viewport](https://w3c.github.io/svgwg/svg2-draft/coords.html#TermSVGViewport)'s [origin box], which is a rectangle with
 the width and height of the [SVG
 viewport], positioned such that its top
 left corner is anchored at the coordinate system origin. (In a CSS
 box context, treated as
 [border-box](#valdef-box-border-box).)

 When the [SVG
 viewport](https://w3c.github.io/svgwg/svg2-draft/coords.html#TermSVGViewport) is not itself anchored at the origin, this [origin
 box](#svg-viewport-origin-box) does not actually correspond to the [SVG
 viewport]!

For convenience, the following value types are defined to represents
commonly used subsets of [\<box\>](#typedef-box):

``` prod
<visual-box> = content-box | padding-box | border-box
<layout-box> = <visual-box> | margin-box
<paint-box> = <visual-box> | fill-box | stroke-box
<coord-box> = <paint-box> | view-box
```

## 3. Margins

[Margins] surround the border edge of a box, providing spacing
between boxes. The [margin properties] specify the thickness of the
[margin area](#margin-area) of a
box. The [margin](#propdef-margin) [shorthand
property](https://drafts.csswg.org/css-cascade-5/#shorthand-property) sets the margin for all four sides while the margin
[longhand
properties](https://drafts.csswg.org/css-cascade-5/#longhand) only set their respective side. This specification
defines the
[physical](https://drafts.csswg.org/css-writing-modes-4/#physical) [margin]
[longhands]; [CSS Logical Properties 1 § 4.2
Flow-Relative Margins: the margin-block-start, margin-block-end,
margin-inline-start, margin-inline-end properties and margin-block and
margin-inline
shorthands](https://drafts.csswg.org/css-logical-1/#margin-properties)
additionally defines
[flow-relative](https://drafts.csswg.org/css-writing-modes-4/#flow-relative) [margin]
[longhands]. Both sets of properties control the
same set of margins: they are just different ways of indexing each side.

 Adjoining margins in [block
layout](https://drafts.csswg.org/css-display-4/#block-layout) *collapse*. See [CSS2§8.3.1 Collapsing
Margins](https://www.w3.org/TR/CSS2/box.html#collapsing-margins) for
details. Also, margins adjoining a [fragmentation
break](https://drafts.csswg.org/css-break-4/#fragmentation-break) are sometimes truncated. See [CSS Fragmentation 4 § 5.2
Adjoining Margins at Breaks: the margin-break
property](https://drafts.csswg.org/css-break-4/#break-margins) for
details.

### 3.1. Page-relative (Physical) Margin Properties: the [margin-top, [margin-right](#propdef-margin-right), [margin-bottom](#propdef-margin-bottom), and [margin-left](#propdef-margin-left) properties]
Name:

[margin-top], [margin-right],
[margin-bottom], [margin-left]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage)
[\|](https://drafts.csswg.org/css-values-4/#comb-one) auto

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

0

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

all elements except [internal table
elements](https://drafts.csswg.org/css-display-4/#internal-table-element), [ruby base
containers](https://drafts.csswg.org/css-ruby-1/#ruby-base-container-box), and [ruby annotation
containers](https://drafts.csswg.org/css-ruby-1/#ruby-annotation-container-box)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

refer to [logical
width](https://drafts.csswg.org/css-writing-modes-4/#logical-width) of containing block

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

the keyword [auto] or a computed
[\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage) value

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value type

[Logical property
group:](https://drafts.csswg.org/css-logical-1/#logical-property-group)

[margin](#propdef-margin)

These properties set the top, right, bottom, and left
[margin](#margin) of a
[box](https://drafts.csswg.org/css-display-4/#box), respectively.

Negative values for margin properties are allowed, but there may be
implementation-specific limits.

### 3.2. Margin Shorthand: the [margin property]
Name:

[margin]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<\'margin-top\'\>](#propdef-margin-top)[{1,4}](https://drafts.csswg.org/css-values-4/#mult-num-range)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

0

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

all elements except [internal table
elements](https://drafts.csswg.org/css-display-4/#internal-table-element), [ruby base
containers](https://drafts.csswg.org/css-ruby-1/#ruby-base-container-box), and [ruby annotation
containers](https://drafts.csswg.org/css-ruby-1/#ruby-annotation-container-box)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

refer to [logical
width](https://drafts.csswg.org/css-writing-modes-4/#logical-width) of containing block

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

see individual properties

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value type

The [margin](#propdef-margin) property is a shorthand property for setting
[margin-top](#propdef-margin-top),
[margin-right](#propdef-margin-right),
[margin-bottom](#propdef-margin-bottom), and
[margin-left](#propdef-margin-left) in a single declaration.

If there is only one component value, it applies to all sides. If there
are two values, the top and bottom margins are set to the first value
and the right and left margins are set to the second. If there are three
values, the top is set to the first value, the left and right are set to
the second, and the bottom is set to the third. If there are four values
they apply to the top, right, bottom, and left, respectively.

The following code demonstrates some
possible [margin](#propdef-margin) declarations.

 body { margin: 2em } /* all margins set to 2em */
 body { margin: 1em 2em } /* top & bottom = 1em, right & left = 2em */
 body { margin: 1em 2em 3em } /* top=1em, right=2em, bottom=3em, left=2em */

The last rule of the example above is equivalent to the example below:

 body {
 margin-top: 1em;
 margin-right: 2em;
 margin-bottom: 3em;
 margin-left: 2em; /* copied from opposite side (right) */
 }

### 3.3. Margins at Container Edges: the [margin-trim property]
Name:

[margin-trim]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

none
[\|](https://drafts.csswg.org/css-values-4/#comb-one) block [\|] \[ block-start
[\|\|](https://drafts.csswg.org/css-values-4/#comb-any) block-end \]

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

none

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[block
containers](https://drafts.csswg.org/css-display-4/#block-container), [multi-column
containers](https://drafts.csswg.org/css-multicol-2/#multi-column-container)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

N/A

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

a set of zero to two keywords indicating which sides to trim

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

Oftentimes, margins are desired between siblings, but not at the
start/end of the container where spacing can be controlled with padding.
This property allows the container to trim the margins of its children
where they adjoin the container's edges. Values have the following
meanings:

[none]

: Margins are not trimmed by the container.

 However, in block layout, child margins can
 collapse with their parent. See [CSS2§8.3.1: Collapsing
 Margins](https://www.w3.org/TR/CSS2/box.html#collapsing-margins).

[block-start]\
[block-end]
: For
 [in-flow](https://drafts.csswg.org/css-display-4/#in-flow) boxes contained by this box, margins adjacent to
 the box's specified edges are truncated to zero. It also truncates
 any descendant margins collapsed with such a margin (but not its
 own, its siblings', or its ancestors').

[block]
: Computes to [block-start block-end].

 Following the shortest-serialization principle,
[computed
values](https://drafts.csswg.org/css-cascade-5/#computed-value) equivalent to
[block](#valdef-margin-trim-block) will serialize as that keyword.

Adjacency is not sensitive to space governed by box alignment
[\[CSS-ALIGN-3\]](#biblio-css-align-3 "CSS Box Alignment Module Level 3").

 See also the
[margin-break](https://drafts.csswg.org/css-break-4/#propdef-margin-break) property, which applies to the
box's own margins when they adjoin a [fragmentation
break](https://drafts.csswg.org/css-break-4/#fragmentation-break) (page break / column break / etc.).

Define how this property affects margins
at breaks if the box establishes a [fragmentation
context](https://drafts.csswg.org/css-break-4/#fragmentation-context). See also [Issue
3314](https://github.com/w3c/csswg-drafts/issues/3314).

 This property has no effect on the margins of floats
when specified on a [block
container](https://drafts.csswg.org/css-display-4/#block-container); a future level of this module may introduce specific
controls for floats.

#### 3.3.1. Trimming Block Container Content

For [block
containers](https://drafts.csswg.org/css-display-4/#block-container) specifically,
[margin-trim](#propdef-margin-trim) discards:

- The block-start margin of a block-level first child, when trimming at
 the block-start edge.
- The block-end margin of a block-level last child, when trimming at the
 block-end edge.
- Any margin collapsed with these margins.

It has no effect on any margins of
[inline-level](https://drafts.csswg.org/css-display-4/#inline-level) descendants.

## 4. Padding

[Padding] is
inserted between the content edge and the padding edge of a box,
providing spacing between the content and the border. The [padding
properties] specify the thickness of the [padding
area](#padding-area) of a box.
The [padding](#propdef-padding) [shorthand
property](https://drafts.csswg.org/css-cascade-5/#shorthand-property) sets the padding for all four sides while the padding
[longhand
properties](https://drafts.csswg.org/css-cascade-5/#longhand) only set their respective side. This specification
defines the
[physical](https://drafts.csswg.org/css-writing-modes-4/#physical) [padding]
[longhands]; [CSS Logical Properties 1 § 4.4
Flow-Relative Padding: the padding-block-start, padding-block-end,
padding-inline-start, padding-inline-end properties and padding-block
and padding-inline
shorthands](https://drafts.csswg.org/css-logical-1/#padding-properties)
additionally defines
[flow-relative](https://drafts.csswg.org/css-writing-modes-4/#flow-relative) [padding]
[longhands]. Both sets of properties control the
same set of padding: they are just different ways of indexing each side.

 Backgrounds specified on the box are by default laid
out and painted within the padding edges. (They are additionally painted
underneath the border, in the [border
area](#border-area).) This
behavior can be adjusted using the
[background-origin](https://drafts.csswg.org/css-backgrounds-3/#propdef-background-origin) and
[background-clip](https://drafts.csswg.org/css-backgrounds-3/#propdef-background-clip) properties.

### 4.1. Page-relative (Physical) Padding Properties: the [padding-top, [padding-right](#propdef-padding-right), [padding-bottom](#propdef-padding-bottom), and [padding-left](#propdef-padding-left) properties]
Name:

[padding-top], [padding-right],
[padding-bottom], [padding-left]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<length-percentage
\[0,∞\]\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

0

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

all elements except: [internal table
elements](https://drafts.csswg.org/css-display-4/#internal-table-element) other than table cells, [ruby base
containers](https://drafts.csswg.org/css-ruby-1/#ruby-base-container-box), and [ruby annotation
containers](https://drafts.csswg.org/css-ruby-1/#ruby-annotation-container-box)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

refer to [logical
width](https://drafts.csswg.org/css-writing-modes-4/#logical-width) of containing block

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

a computed
[\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage) value

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value type

[Logical property
group:](https://drafts.csswg.org/css-logical-1/#logical-property-group)

[padding](#propdef-padding)

These properties set the top, right, bottom, and left
[padding](#padding) of a
[box](https://drafts.csswg.org/css-display-4/#box), respectively.

Negative values for padding properties are invalid.

### 4.2. Padding Shorthand: the [padding property]
Name:

[padding]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<\'padding-top\'\>](#propdef-padding-top)[{1,4}](https://drafts.csswg.org/css-values-4/#mult-num-range)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

0

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

all elements except: [internal table
elements](https://drafts.csswg.org/css-display-4/#internal-table-element) other than table cells, [ruby base
containers](https://drafts.csswg.org/css-ruby-1/#ruby-base-container-box), and [ruby annotation
containers](https://drafts.csswg.org/css-ruby-1/#ruby-annotation-container-box)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

refer to [logical
width](https://drafts.csswg.org/css-writing-modes-4/#logical-width) of containing block

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

see individual properties

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value type

The [padding](#propdef-padding) property is a shorthand property for setting
[padding-top](#propdef-padding-top),
[padding-right](#propdef-padding-right),
[padding-bottom](#propdef-padding-bottom), and
[padding-left](#propdef-padding-left) in a single declaration.

If there is only one component value, it applies to all sides. If there
are two values, the top and bottom padding are set to the first value
and the right and left padding are set to the second. If there are three
values, the top is set to the first value, the left and right are set to
the second, and the bottom is set to the third.

The following code demonstrates some
possible [padding](#propdef-padding) declarations.

 body { padding: 2em } /* all padding set to 2em */
 body { padding: 1em 2em } /* top & bottom = 1em, right & left = 2em */
 body { padding: 1em 2em 3em } /* top=1em, right=2em, bottom=3em, left=2em */

The last rule of the example above is equivalent to the example below:

 body {
 padding-top: 1em;
 padding-right: 2em;
 padding-bottom: 3em;
 padding-left: 2em; /* copied from opposite side (right) */
 }

## 5. Borders

[Borders] fill the [border area](#border-area), to visually delineate the edges of the box, The
[border properties] specify the thickness of the [border
area] of a box, as well as its drawing style and
color. See [CSS Backgrounds 3 § 3
Borders](https://drafts.csswg.org/css-backgrounds-3/#borders) for the
definition of the physical variants of these properties; [CSS Logical
Properties 1 § 4.5 Flow-Relative
Borders](https://drafts.csswg.org/css-logical-1/#border-properties)
additionally defines
[flow-relative](https://drafts.csswg.org/css-writing-modes-4/#flow-relative) border
[longhands](https://drafts.csswg.org/css-cascade-5/#longhand). Both sets of properties control the same set of
borders: they are just different ways of indexing each side.

## 6. Recent Changes

Changes since the [1 April 2024 Working
Draft](https://www.w3.org/TR/2024/WD-css-box-4-20240401/) include:

- Allowing combining the
 [block](#valdef-margin-trim-block) and
 [inline](https://www.w3.org/TR/css-box-4/#valdef-margin-trim-inline) keywords of
 [margin-trim](#propdef-margin-trim). ([Issue
 7884](https://github.com/w3c/csswg-drafts/issues/7884))

- Introducing the [shaped edge](#shaped-edge) and [unshaped
 edge](#unshaped-edge) terms
 for easier cross-referencing of those concepts. ([Issue
 5132](https://github.com/w3c/csswg-drafts/issues/5132))

Changes since the [3 November 2022 Working
Draft](https://www.w3.org/TR/2022/WD-css-box-4-20221103/) include:

- Removing the effect of
 [margin-trim](#propdef-margin-trim) on floats, because there are use cases
 for both trimming and not trimming their margins, and it is
 complicated to implement. ([Issue
 8547](https://github.com/w3c/csswg-drafts/issues/8547))

- Clarifying that only descendant margins are trimmed by
 [margin-trim](#propdef-margin-trim) even if self or sibling margins would
 have collapsed with the trimmed margin.

- Introducing terms for the [shaped](#shaped-edge) and
 [unshaped](#unshaped-edge)
 [edges](#box-box-edge) of a
 [box](https://drafts.csswg.org/css-display-4/#box). ([Issue
 5132](https://github.com/w3c/csswg-drafts/issues/5132))

## 7. Changes Since CSS Level 3

The following changes have been made to this module since [Level
3](https://www.w3.org/TR/css-box-3/):

- Adding the
 [margin-trim](#propdef-margin-trim) property.

## 8. Changes Since CSS Level 2

The following changes have been made to this module since [Level
2](https://www.w3.org/TR/CSS2/box.html):

- Adapting the prose slightly to account for vertical [writing
 modes](https://drafts.csswg.org/css-writing-modes-4/#writing-mode).
- Defining the applicability of
 [margin](#propdef-margin),
 [padding](#propdef-padding) and their longhands to [ruby base
 containers](https://drafts.csswg.org/css-ruby-1/#ruby-base-container-box) and [ruby annotation
 containers](https://drafts.csswg.org/css-ruby-1/#ruby-annotation-container-box)

## 9. Privacy Considerations

No privacy considerations have been reported on this module.

## 10. Security Considerations

No security considerations have been reported on this module.
