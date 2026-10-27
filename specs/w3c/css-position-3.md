## 1. Introduction

*This section is not normative.*

The CSS layout algorithms, by default, size and position boxes in
relation to each other so that nothing overlaps.

This specification defines several ways to violate these assumptions
when needed, moving elements around in ways that can make them overlap
other content:

- [Relative positioning](#relative-position), which visually shifts a box relative to its laid-out
 location.

- [Sticky positioning](#sticky-position), which visually shifts a box relative to its laid-out
 location in order to keep it visible when a scrollable ancestor would
 otherwise scroll it out of sight.

- [Absolute positioning](#absolute-position), which ignores normal layout entirely, pulling the
 element [out of
 flow](https://drafts.csswg.org/css-display-4/#out-of-flow) and positioning it relative to its [containing
 block](https://drafts.csswg.org/css-display-4/#containing-block) with no regard for other content.

- [Fixed positioning](#fixed-position), which absolutely positions the box and affixes it to
 the viewport or page frame so that it is always visible.

These [positioning
schemes](#positioning-scheme), controlled by the
[position](#propdef-position) property and the [inset
properties](#inset-properties), are powerful but easy to misuse. With appropriate
care, they allow many interesting and useful layouts that couldn't
otherwise be achieved with standard layout rules; without, they allow a
page to be laid out in an unusable overlapping jumble of content.

### 1.1. Module Interactions

This module replaces and extends the [positioning
scheme](#positioning-scheme) features defined in
[\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")
sections:

- [9.1.2 Containing
 blocks](https://www.w3.org/TR/CSS2/visuren.html#containing-block)
- [9.3 Positioning
 schemes](https://www.w3.org/TR/CSS2/visuren.html#positioning-scheme)
- [9.4.3 Relative
 positioning](https://www.w3.org/TR/CSS2/visuren.html#relative-positioning)
- [9.6 Absolute
 positioning](https://www.w3.org/TR/CSS2/visuren.html#absolute-positioning)
- [9.7 Relationships between display, position, and
 float](https://www.w3.org/TR/CSS2/visuren.html#dis-pos-flo)
- [9.8 Comparison of normal flow, floats, and absolute
 positioning](https://www.w3.org/TR/CSS2/visuren.html#comparison)
- [10.1 Definition of \"containing
 block\"](https://www.w3.org/TR/CSS2/visudet.html#containing-block-details)
- [10.3.7 Absolutely positioned, non-replaced
 elements](https://www.w3.org/TR/CSS2/visudet.html#abs-non-replaced-width)
- [10.3.8 Absolutely positioned, replaced
 elements](https://www.w3.org/TR/CSS2/visudet.html#abs-replaced-width)
- [10.6.4 Absolutely positioned, non-replaced
 elements](https://www.w3.org/TR/CSS2/visudet.html#abs-non-replaced-height)
- [10.6.5 Absolutely positioned replaced
 elements](https://www.w3.org/TR/CSS2/visudet.html#abs-replaced-height)

It also replaces and supersedes the [inset\*] property definitions
in
[\[CSS-LOGICAL-1\]](#biblio-css-logical-1 "CSS Logical Properties and Values Module Level 1")
([CSS Logical Properties 1 § 4.3 Flow-Relative Offsets: the
inset-block-start, inset-block-end, inset-inline-start, inset-inline-end
properties and inset-block, inset-inline, and inset
shorthands](https://drafts.csswg.org/css-logical-1/#position-properties)).

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

## 2. Choosing A Positioning Scheme: [position property]
Name:

[position]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

static
[\|](https://drafts.csswg.org/css-values-4/#comb-one) relative [\|] absolute
[\|] sticky [\|] fixed

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

static

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

all elements except table-column-group and table-column

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

The [position](#propdef-position) property determines which of the
[positioning schemes] is used to calculate
the position of a box. Values other than
[static](#valdef-position-static) make the box a [positioned box],
and cause it to establish an [absolute positioning containing
block] for its descendants. Values have the following
meanings:

[static]
: The box is not a [positioned
 box](#positioned-box), and
 is laid out according to the rules of its parent [formatting
 context](https://drafts.csswg.org/css-display-4/#formatting-context). The [inset
 properties](#inset-properties) do not apply.

[relative]

: The box is laid out as for
 [static](#valdef-position-static), then offset from the resulting position
 with the [inset
 properties](#inset-properties). This offsetting is a purely visual effect, and,
 unless otherwise specified, does not affect the size or position of
 any other non-descendant box except insofar as it increases the
 [scrollable overflow
 area](https://drafts.csswg.org/css-overflow-3/#scrollable-overflow-region) of its ancestors. This [positioning
 scheme](#positioning-scheme) is called [relative positioning].

 See [§ 3.3 Relative Positioning](#relpos-insets) for more details.

[sticky]

: Same as
 [relative](#valdef-position-relative), except the offsets are calculated
 *automatically* to keep the element in view as the user scrolls.
 This [positioning
 scheme](#positioning-scheme) is called [sticky positioning].

 See [§ 3.4 Sticky positioning](#stickypos-insets) for more details.

[absolute]

: The box is taken [out of
 flow](https://drafts.csswg.org/css-display-4/#out-of-flow) such that it has no impact on the size or position
 of its siblings and ancestors, and does not participate in its
 parent's [formatting
 context](https://drafts.csswg.org/css-display-4/#formatting-context).

 Instead, the box is positioned and sized solely in reference to its
 [absolute positioning containing
 block](#absolute-positioning-containing-block), as modified by the box's [inset
 properties](#inset-properties), see [§ 4 Absolute Positioning Layout
 Model](#abspos-layout) and [§ 3.5 Absolute (and Fixed)
 Positioning](#abspos-insets). It can overlap
 [in-flow](https://drafts.csswg.org/css-display-4/#in-flow) content or other [absolutely
 positioned](#absolute-position) elements, and is included in the [scrollable
 overflow
 area](https://drafts.csswg.org/css-overflow-3/#scrollable-overflow-region) of the box that generates is [containing
 block](https://drafts.csswg.org/css-display-4/#containing-block). This [positioning
 scheme](#positioning-scheme) is called [absolute positioning].

[fixed]
: Same as
 [absolute](#valdef-position-absolute), except the box is positioned and sized
 relative to a [fixed positioning containing
 block](#fixed-positioning-containing-block) (usually the
 [viewport](https://www.w3.org/TR/CSS2/visuren.html#x1) in [continuous
 media](https://drafts.csswg.org/mediaqueries-5/#continuous-media), or the [page
 area](https://drafts.csswg.org/css-page-3/#page-area) in [paged
 media](https://drafts.csswg.org/mediaqueries-5/#paged-media)). The box's position is fixed with respect to this
 reference rectangle: when attached to the [viewport]
 it does not move when the document is scrolled, and when attached to
 the [page area] is replicated on every page
 when the document is paginated. This [positioning
 scheme](#positioning-scheme) is called [fixed positioning] and
 is considered a subset of [absolute
 positioning](#absolute-position).
 :::
 (#example-d41e8cfe) Authors may wish to specify
 [fixed](#valdef-position-fixed) in a media-dependent way. For instance, an author
 may want a box to remain at the top of the
 [viewport](https://www.w3.org/TR/CSS2/visuren.html#x1) on the screen, but not at the top of each printed
 page. The two specifications may be separated by using an
 [\'@media\'](https://www.w3.org/TR/CSS2/media.html#at-media-rule)
 rule, as in:
 ``` highlight
 @media screen {
 h1#first { position: fixed }
 }
 @media print {
 h1#first { position: static }
 }
 ```
 :::

A [position](#propdef-position) value of
[absolute](#valdef-position-absolute) or
[fixed](#valdef-position-fixed)
[blockifies](https://drafts.csswg.org/css-display-4/#blockify) the box, causes
[float](https://drafts.csswg.org/css2/#propdef-float) to compute to
[none](https://drafts.csswg.org/css2/#valdef-float-none), and forces the box to [establish an independent
formatting
context](https://drafts.csswg.org/css-display-4/#establish-an-independent-formatting-context).

### 2.1. Containing Blocks of Positioned Boxes

The [containing
block](https://drafts.csswg.org/css-display-4/#containing-block) of a
[static](#valdef-position-static),
[relative](#valdef-position-relative), or
[sticky](#valdef-position-sticky)
[box](https://drafts.csswg.org/css-display-4/#box) is as defined by its [formatting
context](https://drafts.csswg.org/css-display-4/#formatting-context). For
[fixed](#valdef-position-fixed) and
[absolute](#valdef-position-absolute) boxes, it is defined as follows:

If the box has [position: absolute](#propdef-position):

: The [containing
 block](https://drafts.csswg.org/css-display-4/#containing-block) is established by the nearest ancestor box that
 establishes an [absolute positioning containing
 block](#absolute-positioning-containing-block), in the following way:

 If the ancestor is not an [inline box](https://drafts.csswg.org/css-display-4/#inline-box),
 : the [containing
 block](https://drafts.csswg.org/css-display-4/#containing-block) is formed by the [padding
 edge](https://drafts.csswg.org/css-box-4/#padding-edge) of the ancestor, unless otherwise specified
 (for example, see [CSS Grid Layout 1 § 9.1 With a Grid Container
 as Containing
 Block](https://drafts.csswg.org/css-grid-1/#abspos-items)).

 If the ancestor is an [inline box](https://drafts.csswg.org/css-display-4/#inline-box), using the [writing mode](https://drafts.csswg.org/css-writing-modes-4/#writing-mode) of that box,

 : the [containing
 block](https://drafts.csswg.org/css-display-4/#containing-block) is formed by forming a rectangle from the
 [start](https://drafts.csswg.org/css-writing-modes-4/#css-start)-most [content
 edges](https://drafts.csswg.org/css-box-4/#content-edge) (in both axes) of the first [box
 fragment](https://drafts.csswg.org/css-break-4/#box-fragment) of the ancestor, and the
 [end](https://drafts.csswg.org/css-writing-modes-4/#css-end)-most [content edges] of
 the [end]-most [box
 fragment](s) of the ancestor in each
 axis. If there are multiple fragments on the same line (e.g. due
 to [bidi
 reordering](https://drafts.csswg.org/css-writing-modes-3/#bidi-box-model)),
 take the [start]-most fragment as the first
 fragment.

 (#issue-d9a49098) What is a useful containing
 block to form when the box is fragmented across multiple lines?
 [\[Issue
 #8284\]](https://github.com/w3c/csswg-drafts/issues/8284)

 The [containing
 block](https://drafts.csswg.org/css-display-4/#containing-block) formed by a fragmented [inline
 box](https://drafts.csswg.org/css-display-4/#inline-box) was undefined in
 [\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification").

 If no ancestor establishes one, the [absolute positioning containing
 block](#absolute-positioning-containing-block) is the [initial containing
 block](https://drafts.csswg.org/css-display-4/#initial-containing-block).

 Properties that can cause a box to establish an
 [absolute positioning containing
 block](#absolute-positioning-containing-block) include
 [position](#propdef-position),
 [transform](https://drafts.csswg.org/css-transforms-1/#propdef-transform),
 [will-change](https://drafts.csswg.org/css-will-change-1/#propdef-will-change),
 [contain](https://drafts.csswg.org/css-contain-2/#propdef-contain)...

If the box has [position: fixed](#propdef-position):

: The [containing
 block](https://drafts.csswg.org/css-display-4/#containing-block) is established by the nearest ancestor box that
 establishes an [fixed positioning containing
 block], with the bounds of the [containing
 block] determined identically to the
 [absolute positioning containing
 block](#absolute-positioning-containing-block).

 Properties that can cause a box to establish a
 [fixed positioning containing
 block](#fixed-positioning-containing-block) include
 [transform](https://drafts.csswg.org/css-transforms-1/#propdef-transform),
 [will-change](https://drafts.csswg.org/css-will-change-1/#propdef-will-change),
 [contain](https://drafts.csswg.org/css-contain-2/#propdef-contain)...

 If no ancestor establishes one, the box's [fixed positioning
 containing
 block](#fixed-positioning-containing-block) is the [initial fixed containing
 block]:

 - in [continuous
 media](https://drafts.csswg.org/mediaqueries-5/#continuous-media), the [layout
 viewport](https://drafts.csswg.org/css-viewport/#layout-viewport) (whose size matches the [dynamic viewport
 size](https://drafts.csswg.org/css-values-4/#dynamic-viewport-size)); as a result,
 [fixed](#fixed-position)
 boxes do not move when the document is scrolled.

 In this respect, they are similar to [fixed
 background
 images](https://drafts.csswg.org/css-backgrounds-3/#background-attachment)
 ([background-attachment:
 fixed](https://drafts.csswg.org/css-backgrounds-3/#propdef-background-attachment)).

 - in [paged
 media](https://drafts.csswg.org/mediaqueries-5/#paged-media), the [page
 area](https://drafts.csswg.org/css-page-3/#page-area) of each page; [fixed
 positioned](#fixed-position)
 [boxes](https://drafts.csswg.org/css-display-4/#box) are thus replicated on every page. (They are
 fixed with respect to the page box only, and are not affected by
 being seen through a
 [viewport](https://www.w3.org/TR/CSS2/visuren.html#x1); as in the case of print preview, for example.)

 As a result, parts of [fixed-positioned
 boxes](#fixed-position)
 that extend outside the [layout
 viewport](https://drafts.csswg.org/css-viewport/#layout-viewport)/[page
 area](https://drafts.csswg.org/css-page-3/#page-area) cannot be scrolled to and will not print.

 The [initial fixed containing
 block](#initial-fixed-containing-block) is the parent of the [initial containing
 block](https://drafts.csswg.org/css-display-4/#initial-containing-block) in the [containing block
 chain](https://drafts.csswg.org/css-display-4/#containing-block-chain).

With no positioning, the containing blocks (C.B.) in the following
document:

``` highlight
<!DOCTYPE html>
<html>
 <head>
 <title>Illustration of containing blocks</title>
 </head>
 <body id="body">
 <div id="div1">
 <p id="p1">This is text in the first paragraph...</p>
 <p id="p2">This is text <em id="em1"> in the
 <strong id="strong1">second</strong> paragraph.</em></p>
 </div>
 </body>
</html>
```

are established as follows:

For box generated by

C.B. is established by

html

initial C.B. (UA-dependent)

body

html

div1

body

p1

div1

p2

div1

em1

p2

strong1

p2

If we position \"div1\":

``` highlight
#div1 { position: absolute; left: 50px; top: 50px }
```

its containing block is no longer \"body\"; it becomes the initial
containing block (since there are no other positioned ancestor boxes).

If we position \"em1\" as well:

``` highlight
#div1 { position: absolute; left: 50px; top: 50px }
#em1 { position: absolute; left: 100px; top: 100px }
```

the table of containing blocks becomes:

For box generated by

C.B. is established by

html

initial C.B. (UA-dependent)

body

html

div1

initial C.B.

p1

div1

p2

div1

em1

div1

strong1

em1

By positioning \"em1\", its containing block becomes the nearest
positioned ancestor box (i.e., that generated by \"div1\").

#### 2.1.1. Further Adjustments to the Containing Block

Some features can alter the effective [containing
block](https://drafts.csswg.org/css-display-4/#containing-block) rectangle of [absolutely
positioned](#absolute-position) boxes. These are applied in the following order, with
earlier steps modifying the [containing
block] that later steps see:

1. The [grid-placement
 properties](https://drafts.csswg.org/css-grid-2/#grid-placement-property) on an [absolutely positioned
 box](#absolute-position) whose [containing
 block](https://drafts.csswg.org/css-display-4/#containing-block) is generated by a [grid
 container](https://drafts.csswg.org/css-grid-2/#grid-container) can change the [containing
 block] rectangle to a specified [grid
 area](https://drafts.csswg.org/css-grid-2/#grid-area). See [CSS Grid Layout 1 § 9.1 With a Grid Container
 as Containing
 Block](https://drafts.csswg.org/css-grid-1/#abspos-items).

2. The
 [position-area](https://drafts.csswg.org/css-anchor-position-1/#propdef-position-area) and
 [position-try](https://drafts.csswg.org/css-anchor-position-1/#propdef-position-try) properties can change the
 [containing
 block](https://drafts.csswg.org/css-display-4/#containing-block) rectangle to a specified area of an [position-area
 grid](https://drafts.csswg.org/css-anchor-position-1/#position-area-grid). See [CSS Anchor Positioning 1 § 3.1 The
 position-area
 Property](https://drafts.csswg.org/css-anchor-position-1/#position-area).

The element's [original containing block] is its [containing
block](https://drafts.csswg.org/css-display-4/#containing-block) before applying any of these effects.

### 2.2. Painting Order and Stacking Contexts

The
[z-index](https://drafts.csswg.org/css2/#propdef-z-index) property applies to all [positioned
boxes](#positioned-box). When
[z-index] is
[auto](https://drafts.csswg.org/css2/#valdef-z-index-auto):

- [Fixed](#fixed-position) and
 [sticky](#sticky-position)
 [positioned boxes](#positioned-box) nonetheless form a [stacking
 context](https://drafts.csswg.org/css2/#stacking-context).

- [Relative](#relative-position) and
 [absolute](#absolute-position) [positioned
 boxes](#positioned-box) do
 not form a [stacking
 context](https://drafts.csswg.org/css2/#stacking-context), but are painted as if those elements did generated
 new [stacking contexts], except that their
 [positioned] descendants and any would-be
 child [stacking contexts] take part in the
 current [stacking context].

 The [root
element](https://drafts.csswg.org/css-display-4/#root-element) always forms a [stacking
context](https://drafts.csswg.org/css2/#stacking-context) regardless.

See [CSS2 § 9.9 Layered
presentation](https://www.w3.org/TR/CSS2/visuren.html#layers) and
[Appendix E:  Elaborate description of Stacking
Contexts](https://www.w3.org/TR/CSS2/zindex.html) for details about
[z-index](https://drafts.csswg.org/css2/#propdef-z-index), [stacking
contexts](https://drafts.csswg.org/css2/#stacking-context), and painting order.

## 3. Positioning Coordinates

The precise location of a [positioned
box](#positioned-box) is
controlled by the [inset properties]: the
[physical](https://drafts.csswg.org/css-writing-modes-4/#physical) [inset
properties](#inset-properties) [top](#propdef-top), [right](#propdef-right),
[bottom](#propdef-bottom), [left](#propdef-left); the
[flow-relative](https://drafts.csswg.org/css-writing-modes-4/#flow-relative) [inset properties]
[inset-block-start](#propdef-inset-block-start),
[inset-inline-start](#propdef-inset-inline-start),
[inset-block-end](#propdef-inset-block-end), and
[inset-inline-end](#propdef-inset-inline-end); and their
[shorthands](https://drafts.csswg.org/css-cascade-5/#shorthand-property),
[inset-block](#propdef-inset-block),
[inset-inline](#propdef-inset-inline), and
[inset](#propdef-inset).

The interpretation of these [inset
properties](#inset-properties) varies by [positioning
scheme](#positioning-scheme):

- for [absolute
 positioning](#absolute-position), they represent insets from the containing block.

- for [relative
 positioning](#relative-position), they represent insets from the box's original margin
 edge.

- for [sticky positioning](#sticky-position), they represent insets from the
 [scrollport](https://drafts.csswg.org/css-overflow-3/#scrollport) edge.

### 3.1. Box Insets: the [top, [right](#propdef-right), [bottom](#propdef-bottom), [left](#propdef-left), [inset-block-start](#propdef-inset-block-start), [inset-inline-start](#propdef-inset-inline-start), [inset-block-end](#propdef-inset-block-end), and [inset-inline-end](#propdef-inset-inline-end) properties ]
Name:

[top], [right], [bottom], [left],
[inset-block-start],
[inset-inline-start],
[inset-block-end],
[inset-inline-end]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

auto
[\|](https://drafts.csswg.org/css-values-4/#comb-one)
[\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

auto

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

positioned elements

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

refer to size of [containing
block](https://drafts.csswg.org/css-display-4/#containing-block); see prose

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

the keyword [auto](#valdef-top-auto) or a computed
[\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage) value

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value type

[Logical property
group:](https://drafts.csswg.org/css-logical-1/#logical-property-group)

[inset](#propdef-inset)

These [inset properties](#inset-properties) represent an inward "inset" on the corresponding side
of the box (with respect to the box's own [writing
mode](https://drafts.csswg.org/css-writing-modes-4/#writing-mode); see [CSS Writing Modes 3 § 6 Abstract Box
Terminology](https://drafts.csswg.org/css-writing-modes-3/#abstract-box)).
For example, [top](#propdef-top) represents a downward inset of the top edge. The
[physical](https://drafts.csswg.org/css-writing-modes-4/#physical) and
[flow-relative](https://drafts.csswg.org/css-writing-modes-4/#flow-relative) properties interact as defined in
[\[CSS-LOGICAL-1\]](#biblio-css-logical-1 "CSS Logical Properties and Values Module Level 1").
Values have the following meanings:

[\<length\>]
: The inset is a fixed distance from the reference edge. Negative
 values are allowed.

[\<percentage\>]
: The inset is a percentage relative to the [containing
 block](https://drafts.csswg.org/css-display-4/#containing-block)'s size in the corresponding axis (e.g. width for
 [left](#propdef-left) or
 [right](#propdef-right), height for
 [top](#propdef-top) and
 [bottom](#propdef-bottom)). For [sticky
 positioned](#sticky-position) boxes, the inset is instead relative to the
 relevant
 [scrollport](https://drafts.csswg.org/css-overflow-3/#scrollport)'s size. Negative values are allowed.

[auto]
: Represents an unconstrained inset; the exact meaning depends on the
 [positioning
 scheme](#positioning-scheme).

 For [fixed
positioned](#fixed-position)
elements, using large values or negative values can easily move elements
outside the
[viewport](https://www.w3.org/TR/CSS2/visuren.html#x1) and make the contents unreachable through scrolling or
other means.

### 3.2. Box Insets Shorthands: the [inset-block, [inset-inline](#propdef-inset-inline), and [inset](#propdef-inset) properties]
Name:

[inset-block], [inset-inline]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<\'top\'\>](#propdef-top)[{1,2}](https://drafts.csswg.org/css-values-4/#mult-num-range)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

auto

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

positioned elements

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

see individual properties

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

see individual properties

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value type

The [inset-block](#propdef-inset-block) and
[inset-inline](#propdef-inset-inline) properties are [shorthand
properties](https://drafts.csswg.org/css-cascade-5/#shorthand-property) for setting
[inset-block-start](#propdef-inset-block-start) +
[inset-block-end](#propdef-inset-block-end) or
[inset-inline-start](#propdef-inset-inline-start) +
[inset-inline-end](#propdef-inset-inline-end), respectively, in a single
declaration. The first component value sets the
[start](https://drafts.csswg.org/css-writing-modes-4/#css-start) side, the second sets the
[end](https://drafts.csswg.org/css-writing-modes-4/#css-end); if omitted, the second value defaults to the first.

Name:

[inset]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<\'top\'\>](#propdef-top)[{1,4}](https://drafts.csswg.org/css-values-4/#mult-num-range)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

auto

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

positioned elements

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

see individual properties

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

see individual properties

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value type

The [inset](#propdef-inset) property is a [shorthand
property](https://drafts.csswg.org/css-cascade-5/#shorthand-property) that sets all of the [inset
properties](#inset-properties) in a single declaration, assigning values to the
longhands representing each side exactly as the
[margin](https://drafts.csswg.org/css-box-4/#propdef-margin) property does for its longhands.

By default, the [inset](#propdef-inset) property values are assigned to the
corresponding
*[physical](https://drafts.csswg.org/css-writing-modes-4/#physical)* [longhand
properties](https://drafts.csswg.org/css-cascade-5/#longhand)---​[top](#propdef-top),
[right](#propdef-right),
[bottom](#propdef-bottom), and [left](#propdef-left)---​which for historical reasons do
not have an [inset-] prefix. This matches the behavior of other
\"4 values assigned to sides\" properties, such as
[margin](https://drafts.csswg.org/css-box-4/#propdef-margin).

Allowing properties such as this to resolve to the
[flow-relative](https://drafts.csswg.org/css-writing-modes-4/#flow-relative)
[longhands](https://drafts.csswg.org/css-cascade-5/#longhand) is under discussion in
[\[CSS-LOGICAL-1\]](#biblio-css-logical-1 "CSS Logical Properties and Values Module Level 1").

Yes, we understand it's a little confusing that
[inset](#propdef-inset) doesn't expand to any [inset-\*] properties.

### 3.3. Relative Positioning

For a [relatively
positioned](#relative-position) box, the [inset
properties](#inset-properties) move the box inward from the respective edge, without
changing its size. [left](#propdef-left) moves the box to the right,
[right](#propdef-right) moves it to the left, etc. Since boxes are not
split or stretched as a result of [relative
positioning] opposing [used
values](https://drafts.csswg.org/css-cascade-5/#used-value) in a given axis must be negations of each other:

- If opposing [inset
 properties](#inset-properties) in an axis both compute to
 [auto](#valdef-top-auto) (their [initial
 values](https://drafts.csswg.org/css-cascade-5/#initial-value)), their [used
 values](https://drafts.csswg.org/css-cascade-5/#used-value) are zero (i.e., the boxes stay in their original
 position in that axis).
- If only one is [auto](#valdef-top-auto), its [used
 value](https://drafts.csswg.org/css-cascade-5/#used-value) becomes the negation of the other, and the box is
 shifted by the specified amount.
- If neither is [auto](#valdef-top-auto), the position is over-constrained; (with respect to
 the [writing
 mode](https://drafts.csswg.org/css-writing-modes-4/#writing-mode) of its [containing
 block](https://drafts.csswg.org/css-display-4/#containing-block)) the
 [computed](https://drafts.csswg.org/css-cascade-5/#computed-value)
 [end](https://drafts.csswg.org/css-writing-modes-4/#css-end) side value is ignored, and its [used
 value](https://drafts.csswg.org/css-cascade-5/#used-value) becomes the negation of the
 [start](https://drafts.csswg.org/css-writing-modes-4/#css-start) side.

The following three rules are equivalent, and shift the box [1em]
to the left:

``` highlight
div.a8 { position: relative; direction: ltr; left: -1em; right: auto }
div.a8 { position: relative; direction: ltr; left: auto; right: 1em }
div.a8 { position: relative; direction: ltr; left: -1em; right: 5em }
```

If specified on a
[table-row-group](https://drafts.csswg.org/css-display-4/#valdef-display-table-row-group),
[table-header-group](https://drafts.csswg.org/css-display-4/#valdef-display-table-header-group),
[table-footer-group](https://drafts.csswg.org/css-display-4/#valdef-display-table-footer-group), or
[table-row](https://drafts.csswg.org/css-display-4/#valdef-display-table-row)
[box](https://drafts.csswg.org/css-display-4/#box) the shift affects all the contents of the box,
including all [table
cells](https://drafts.csswg.org/css-display-4/#valdef-display-table-cell) that originate in the affected row, but not
those that don't.

 Since
[position](#propdef-position) does not apply to
[table-column-group](https://drafts.csswg.org/css-display-4/#valdef-display-table-column-group) or
[table-column](https://drafts.csswg.org/css-display-4/#valdef-display-table-column) boxes, they are not affected by [relative
positioning](#relative-position).

### 3.4. Sticky positioning

[Sticky positioning](#sticky-position) is similar to [relative
positioning](#relative-position) except the offsets are automatically calculated in
reference to the [nearest
scrollport](https://www.w3.org/TR/css-overflow-3/#nearest-scrollport).

For a [sticky positioned](#sticky-position)
[box](https://drafts.csswg.org/css-display-4/#box), the [inset
properties](#inset-properties) represent insets from the respective edges of the
[scrollport](https://drafts.csswg.org/css-overflow-3/#scrollport) of the nearest [scroll
container](https://drafts.csswg.org/css-overflow-3/#scroll-container) with a matching [scrollable
axis](https://drafts.csswg.org/css-overflow-3/#scrollable-axis), defining the [sticky view
rectangle] used to constrain the box's position. (The [sticky view
rectangle](#sticky-view-rectangle) can be constructed from edges of two different
[scrollports], if the nearest [scroll
container] is a [single-axis scroll
container](https://drafts.csswg.org/css-overflow-3/#single-axis-scroll-container).)

If *both* [inset
properties](#inset-properties) in a given axis are
[auto](#valdef-top-auto), no offsets are added in that axis; the element stays
where it was laid out in that axis. Otherwise,
[auto] insets represent zero insets.

If this results in a [sticky view
rectangle](#sticky-view-rectangle) size in any axis less than the size of the [border
box](https://drafts.csswg.org/css-box-4/#border-box) of the
[sticky](#sticky-position)
box in that axis, then the effective
[end](https://drafts.csswg.org/css-writing-modes-4/#css-end)-edge inset in the affected axis is reduced (possibly
becoming negative) to bring the [sticky view
rectangle]'s size up to the size of the
[border box] in that axis (where
[end] is interpreted relative to the [writing
mode](https://drafts.csswg.org/css-writing-modes-4/#writing-mode) of the [containing
block](https://drafts.csswg.org/css-display-4/#containing-block)).

For example, if the [nearest
scrollport](https://www.w3.org/TR/css-overflow-3/#nearest-scrollport) is [300px] tall, the
[sticky](#sticky-position)
box's [border
box](https://drafts.csswg.org/css-box-4/#border-box) is [200px] tall, and it has [top:
20px](#propdef-top),
then the top-edge inset of the [nearest
scrollport] is [20px], and the
bottom-edge inset is [0px], yielding a [sticky view
rectangle](#sticky-view-rectangle) that is [280px] tall.

But if the [nearest
scrollport](https://www.w3.org/TR/css-overflow-3/#nearest-scrollport) were only [100px] tall, then the effective
bottom-edge inset becomes [-120px], resulting in a [sticky view
rectangle](#sticky-view-rectangle) that's [200px] tall, enough to fully contain the
[margin
box](https://drafts.csswg.org/css-box-4/#margin-box) of the
[sticky](#sticky-position)
box.

For each side of the box, if the corresponding [inset
property](#inset-properties) is not
[auto](#valdef-top-auto), and the corresponding [border
edge](https://drafts.csswg.org/css-box-4/#border-edge) of the box would be outside the corresponding edge of
the [sticky view
rectangle](#sticky-view-rectangle), then the box must be visually shifted ([as for
relative positioning](#relpos-insets)) to be inward of that [sticky view
rectangle] edge, insofar as it can
while its [position box](#position-box) remains contained within its [containing
block](https://drafts.csswg.org/css-display-4/#containing-block). The [position box] is its [margin
box](https://drafts.csswg.org/css-box-4/#margin-box), except that for any side for which the distance
between its [margin
edge](https://drafts.csswg.org/css-box-4/#margin-edge) and the corresponding edge of its [containing
block] is less than its corresponding
[margin](https://drafts.csswg.org/css-box-4/#margin), that distance is used in place of that
[margin].

 A sticky positioned element with a
non-[auto](#valdef-top-auto) [top](#propdef-top) value and an
[auto]
[bottom](#propdef-bottom) value will only ever be pushed down by sticky
positioning; it will never be offset upwards.

 Multiple [sticky
positioned](#sticky-position) boxes in the same container are offset independently,
and therefore might overlap.

#### 3.4.1. Scroll Position of Sticky-Positioned Boxes

For the purposes of any operation targeting the scroll position of a
sticky positioned element (or one of its descendants), the sticky
positioned element must be considered to be at its offsetted position.

For example, if a user clicks a link
targeting a
[sticky-positioned](#sticky-position) element, if the element's [nearest
scrollport](https://www.w3.org/TR/css-overflow-3/#nearest-scrollport) is currently scrolled such that the [sticky
positioned] element is offset from its
initial position, the [scroll
container](https://drafts.csswg.org/css-overflow-3/#scroll-container) will be scrolled back only the minimum necessary to
bring it into its desired position in the
[scrollport](https://drafts.csswg.org/css-overflow-3/#scrollport) (rather than scrolling all the way back to target its
original, non-offsetted position).

### 3.5. Absolute (and Fixed) Positioning

For an [absolutely
positioned](#absolute-position) box, the [inset
properties](#inset-properties) effectively reduce the [containing
block](https://drafts.csswg.org/css-display-4/#containing-block) into which it is sized and positioned by the specified
amounts. The resulting rectangle is called the [inset-modified
containing block]. (For disambiguation, the actual [containing
block] of an [absolutely positioned
box] can also be called the
[absolute-position containing block].)

An [absolutely positioned
box](#absolute-position)
is sized and positioned into the [inset-modified containing
block](#inset-modified-containing-block) as described in [§ 4 Absolute Positioning Layout
Model](#abspos-layout).

#### 3.5.1. Resolving [auto Insets]
If only one [inset
property](#inset-properties) in a given axis is
[auto](#valdef-top-auto), it is set to zero.

If both [inset
properties](#inset-properties) in a given axis are
[auto](#valdef-top-auto), then, depending on the box's [self-alignment
property](https://drafts.csswg.org/css-align-3/#self-alignment-properties) in the relevant axis:

for [self-start](https://drafts.csswg.org/css-align-3/#valdef-self-position-self-start) alignment or its equivalent
: Set its start-edge [inset
 property](#inset-properties) to the [static
 position](#static-position), and its end-edge [inset
 property] to zero.

for [self-end](https://drafts.csswg.org/css-align-3/#valdef-self-position-self-end) alignment or its equivalent
: Set its end-edge [inset
 property](#inset-properties) to the [static
 position](#static-position), and its start-edge [inset
 property] to zero.

for [center](https://drafts.csswg.org/css-align-3/#valdef-self-position-center) alignment
: Let `start distance` be the distance from the center of
 its [static-position
 rectangle](#static-position-rectangle) to the start edge of its [containing
 block](https://drafts.csswg.org/css-display-4/#containing-block), and `end distance` be the distance from
 the center of its [static-position
 rectangle] to the end edge of
 its [containing block]. If
 `start distance` is less than or equal to
 `end distance`, then set the start-edge [inset
 property](#inset-properties) to zero, and set the end-edge [inset
 property] to
 (`containing block size` - 2 ×
 \|`start distance`\|); otherwise, set the end-edge [inset
 property] to zero and the start-edge
 [inset property] to
 (`containing block size` - 2 ×
 \|`end distance`\|).

For the rules above, ignore [overflow
alignment](https://drafts.csswg.org/css-align-3/#overflow-alignment), and treat
[normal](https://drafts.csswg.org/css-align-3/#valdef-align-self-normal) as
[start](https://drafts.csswg.org/css-align-3/#valdef-self-position-start) and any
[baseline](https://drafts.csswg.org/css-align-3/#baseline-alignment) or
[stretch](https://drafts.csswg.org/css-align-3/#valdef-align-self-stretch) alignment value as its fallback alignment.

#### 3.5.2. Resolving Overconstrained Insets

If the [inset-modified containing
block](#inset-modified-containing-block) size in any axis is less than zero, then the [weaker
inset](#weaker-inset) in the
affected axis is reduced (possibly becoming negative) to bring that size
up to zero. In the case that only one inset is
[auto](#valdef-top-auto), that is the [weaker inset] (whose opposite inset is the
[stronger inset]); otherwise the [weaker inset] is
the inset of the
[end](https://drafts.csswg.org/css-writing-modes-4/#css-end) edge (where [end] is interpreted
relative to the [writing
mode](https://drafts.csswg.org/css-writing-modes-4/#writing-mode) of the [containing
block](https://drafts.csswg.org/css-display-4/#containing-block)).

If its [self-alignment
property](https://drafts.csswg.org/css-align-3/#self-alignment-properties) in an axis is
[normal](https://drafts.csswg.org/css-align-3/#valdef-align-self-normal), then the [resolved
value](https://drafts.csswg.org/cssom-1/#resolved-value) of its [weaker
inset](#weaker-inset) in that
axis is the value necessary to match that edge of its [inset-modified
containing
block](#inset-modified-containing-block) to the corresponding edge of its [margin
box](https://drafts.csswg.org/css-box-4/#margin-box) after [layout](#abspos-layout). (Otherwise the
[resolved value] is the [used
value](https://drafts.csswg.org/css-cascade-5/#used-value) described above.)

#### 3.5.3. Calculating the Static Position and the "Static-Position Rectangle"

When both [inset
properties](#inset-properties) in a given axis are
[auto](#valdef-top-auto), they are resolved into a [static
position]
by aligning the box into its [static-position
rectangle], an [alignment
container](https://drafts.csswg.org/css-align-3/#alignment-container) derived from the [formatting
context](https://drafts.csswg.org/css-display-4/#formatting-context) the box would have participated in if it were
[position: static](#propdef-position) (independent of its actual containing block). The
[static position](#static-position) represents an approximation of the position the box
would have had if it were [position: static].

Block Layout

: The [static positions](#static-position) of a [block-level
 box](https://drafts.csswg.org/css-display-4/#block-level-box) are defined in
 [\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")
 Chapter 10. The [static-position
 rectangle](#static-position-rectangle) is a zero-thickness rectangle spanning between the
 inline-axis sides of the box's [static-position containing
 block](#static-position-containing-block) and positioned at its
 [block-start](https://drafts.csswg.org/css-writing-modes-4/#block-start) [static position] (see
 [CSS2§10.6.4](https://www.w3.org/TR/CSS2/visudet.html#abs-non-replaced-height)).

 In block layout the [static-position
 rectangle](#static-position-rectangle) corresponds to the position of the "hypothetical
 box" described in
 [CSS2.1§10.3.7](https://www.w3.org/TR/CSS2/visudet.html#abs-non-replaced-width).
 Since it has no alignment properties, CSS2.1 always uses a
 [block-start](https://drafts.csswg.org/css-writing-modes-4/#block-start)
 [inline-start](https://drafts.csswg.org/css-writing-modes-4/#inline-start) alignment of the absolutely-positioned box within
 the [static-position
 rectangle].

Inline Layout
: The [static positions](#static-position) of an [inline-level
 box](https://drafts.csswg.org/css-display-4/#inline-level-box) are defined in
 [\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")
 Chapter 10. The [static-position
 rectangle](#static-position-rectangle) is a zero-thickness rectangle spanning between the
 [line-over](https://drafts.csswg.org/css-writing-modes-4/#line-over)/[line-under](https://drafts.csswg.org/css-writing-modes-4/#line-under) sides of the [line
 box](https://drafts.csswg.org/css-inline-3/#line-box) that would have contained its "hypothetical box"
 (see
 [CSS2§10.3.7](https://www.w3.org/TR/CSS2/visudet.html#abs-non-replaced-width));
 and positioned at its
 [inline-start](https://drafts.csswg.org/css-writing-modes-4/#inline-start) [static position].

Flex Layout
: The [static-position
 rectangle](#static-position-rectangle) of the child of a [flex
 container](https://drafts.csswg.org/css-flexbox-2/#flex-container) corresponds to the [content
 edges](https://drafts.csswg.org/css-box-4/#content-edge) of the [flex container]
 in the [cross
 axis](https://drafts.csswg.org/css-flexbox-2/#cross-axis), and to the [outer
 edges](https://drafts.csswg.org/css-box-4/#outer-edge) of its hypothetical position in the [main
 axis](https://drafts.csswg.org/css-flexbox-2/#main-axis). See [static position of a flex container
 child](https://www.w3.org/TR/css-flexbox-1/#abspos-items) in
 [\[CSS-FLEXBOX-1\]](#biblio-css-flexbox-1 "CSS Flexible Box Layout Module Level 1").

Grid Layout
: By default, the [static-position
 rectangle](#static-position-rectangle) of the child of a [grid
 container](https://drafts.csswg.org/css-grid-2/#grid-container) corresponds to the [content
 edges](https://drafts.csswg.org/css-box-4/#content-edge) of the [grid container].
 However, if that [grid container] also
 establishes the box's actual [containing
 block](https://drafts.csswg.org/css-display-4/#containing-block), then the [grid
 area](https://drafts.csswg.org/css-grid-2/#grid-area) specified by the [grid-placement
 properties](https://drafts.csswg.org/css-grid-2/#grid-placement-property) establishes its [static-position
 rectangle] instead. See the
 [static position of a grid container
 child](https://www.w3.org/TR/css-grid-1/#static-position) in
 [\[CSS-GRID-1\]](#biblio-css-grid-1 "CSS Grid Layout Module Level 1").

Finding the [static
position](#static-position)
and the [static-position
rectangle](#static-position-rectangle) assumes that both
[float](https://drafts.csswg.org/css2/#propdef-float) and
[clear](https://drafts.csswg.org/css2/#propdef-clear) (as well as
[position](#propdef-position)) have their [initial
values](https://drafts.csswg.org/css-cascade-5/#initial-value), and can consequently require assuming a different
hypothetical value for
[display](https://drafts.csswg.org/css-display-4/#propdef-display) as well. (The [containing
block](https://drafts.csswg.org/css-display-4/#containing-block) the element would have had under these conditions is
the [static-position containing block].) To the extent the [box
alignment
properties](https://drafts.csswg.org/css-align-3/#box-alignment-properties) have an effect, they use the [static-position
containing
block](#static-position-containing-block) as the effective [containing
block], including using its [writing
mode](https://drafts.csswg.org/css-writing-modes-4/#writing-mode) for resolving alignment axes and directions.
Additionally, the [containing block] of
[fixed positioned](#fixed-position) elements is assumed to be the [initial containing
block](https://drafts.csswg.org/css-display-4/#initial-containing-block) instead of the
[viewport](https://www.w3.org/TR/CSS2/visuren.html#x1), and all [scroll
containers](https://drafts.csswg.org/css-overflow-3/#scroll-container) should be assumed to be scrolled to their [initial
scroll
position](https://drafts.csswg.org/css-overflow-3/#initial-scroll-position). Lastly, all [auto] margins on the box itself are
treated as zero.

Boxes in the [top
layer](https://drafts.csswg.org/css-position-4/#document-top-layer) always use the [initial containing
block](https://drafts.csswg.org/css-display-4/#initial-containing-block) as their [static-position
rectangle](#static-position-rectangle).

## 4. Absolute Positioning Layout Model

[Absolute positioning](#absolute-position) not only takes a box [out of
flow](https://drafts.csswg.org/css-display-4/#out-of-flow), but also lays it out in its [containing
block](https://drafts.csswg.org/css-display-4/#containing-block) (after the final size of the [containing
block] has been determined) according to
the [absolute positioning layout model]:

1. First, its [inset-modified containing
 block](#inset-modified-containing-block) is calculated, defining its [available
 space](https://drafts.csswg.org/css-sizing-3/#available). (See [§ 3.5 Absolute (and Fixed)
 Positioning](#abspos-insets).)

 Because an [absolutely positioned
 box](#absolute-position) does not affect the size of its [containing
 block](https://drafts.csswg.org/css-display-4/#containing-block), its [available
 space](https://drafts.csswg.org/css-sizing-3/#available) is always
 [definite](https://drafts.csswg.org/css-sizing-3/#definite).

2. Next, its width and height are resolved against this
 [definite](https://drafts.csswg.org/css-sizing-3/#definite) [available
 space](https://drafts.csswg.org/css-sizing-3/#available), as its [preferred
 size](https://drafts.csswg.org/css-sizing-3/#preferred-size) capped by its [maximum
 size](https://drafts.csswg.org/css-sizing-3/#max-width) (if any), floored by its [minimum
 size](https://drafts.csswg.org/css-sizing-3/#min-width). See [§ 4.1 Automatic Sizes of
 Absolutely-Positioned Boxes](#abspos-auto-size). Percentages,
 however, are resolved against the [absolute-position containing
 block](#absolute-position-containing-block) size.

3. Then, the value of any [auto] margins are calculated, see
 [§ 4.2 Auto Margins of Absolutely-Positioned
 Boxes](#abspos-margins).

4. Lastly, its [margin
 box](https://drafts.csswg.org/css-box-4/#margin-box) is aligned within the [inset-modified containing
 block](#inset-modified-containing-block), see [§ 4.3 Self-Alignment of Absolutely Positioned
 Boxes](#abspos-alignment).

### 4.1. Automatic Sizes of Absolutely-Positioned Boxes

The [automatic
size](https://drafts.csswg.org/css-sizing-3/#automatic-size) of an [absolutely positioned
box](#absolute-position)
is resolved against its [inset-modified containing
block](#inset-modified-containing-block) as follows:

If its [self-alignment property](https://drafts.csswg.org/css-align-3/#self-alignment-properties) in the relevant axis is [stretch](https://drafts.csswg.org/css-align-3/#valdef-align-self-stretch) and neither of its [inset properties](#inset-properties) in that axis are [auto](#valdef-top-auto)\
Or if it is [normal](https://drafts.csswg.org/css-align-3/#valdef-align-self-normal) and the box is [non-replaced](https://drafts.csswg.org/css-display-4/#non-replaced), not a [table wrapper box](https://drafts.csswg.org/css-tables-3/#table-wrapper-box), and has no [auto](#valdef-top-auto) [inset](#inset-properties) in the relevant axis

: Its [automatic
 size](https://drafts.csswg.org/css-sizing-3/#automatic-size) is its [stretch-fit
 size](https://drafts.csswg.org/css-sizing-3/#stretch-fit-size).

Otherwise

: Its [automatic
 size](https://drafts.csswg.org/css-sizing-3/#automatic-size) is its [fit-content
 size](https://drafts.csswg.org/css-sizing-3/#fit-content-size).

However, if the box has an aspect-ratio, then an [automatic
size](https://drafts.csswg.org/css-sizing-3/#automatic-size) in the [ratio-dependent
axis](https://drafts.csswg.org/css-sizing-4/#ratio-dependent-axis) is instead resolved as a [max-content
size](https://drafts.csswg.org/css-sizing-3/#max-content). When both axes have an [automatic
size], if only one axis has an
[auto](#valdef-top-auto)
[inset](#inset-properties)
then that axis is the [ratio-dependent
axis], else the [block
axis](https://drafts.csswg.org/css-writing-modes-4/#block-axis) is the [ratio-dependent
axis]. An [automatic
size] in the [ratio-determining
axis](https://drafts.csswg.org/css-sizing-4/#ratio-determining-axis) is determined as above.

For the purpose of computing these sizes, any [auto]
[margins](https://drafts.csswg.org/css-box-4/#margin) are treated as zero.

The [automatic minimum
size](https://drafts.csswg.org/css-sizing-3/#automatic-minimum-size) of an absolutely-positioned box is always zero.

 To the extent that form controls can be resized (and
are not directly representing [replaced
elements](https://drafts.csswg.org/css-display-4/#replaced-element) such as images), they are expected to be treated as
[non-replaced](https://drafts.csswg.org/css-display-4/#non-replaced) here. In HTML, all form controls other than
`<input type=image>` are treated as
[non-replaced].

### 4.2. Auto Margins of Absolutely-Positioned Boxes

If either [inset
property](#inset-properties) in the relevant axis is
[auto](#valdef-top-auto), then any [auto]
[margins](https://drafts.csswg.org/css-box-4/#margin) resolve to zero.

Otherwise, the `remaining space` is calculated as the size of
its [inset-modified containing
block](#inset-modified-containing-block) in the relevant axis minus the box's used size in the
relevant axis, and this `remaining space` is divided among
any [auto] margins in the relevant axis. However, (all with
respect to the [writing
mode](https://drafts.csswg.org/css-writing-modes-4/#writing-mode) of the [containing
block](https://drafts.csswg.org/css-display-4/#containing-block)), if in the [inline
axis](https://drafts.csswg.org/css-writing-modes-4/#inline-axis) the `remaining space` is negative and both
margins are [auto], the
[start](https://drafts.csswg.org/css-writing-modes-4/#inline-start) margin resolves to zero and the
[end](https://drafts.csswg.org/css-writing-modes-4/#inline-end) margin receives the `remaining space`.

 Unlike typical
[in-flow](https://drafts.csswg.org/css-display-4/#in-flow) layout, the space distributed to [auto]
[margins](https://drafts.csswg.org/css-box-4/#margin) can be negative in [absolute
positioning](#absolute-position).

What should happen in "negatively-sized"
containing blocks? CSS2.1 and this draft currently conflict. [\[Issue
#11478\]](https://github.com/w3c/csswg-drafts/issues/11478)

### 4.3. Self-Alignment of Absolutely Positioned Boxes

If the [computed
value](https://drafts.csswg.org/css-cascade-5/#computed-value) of either [inset
property](#inset-properties) in an axis is
[auto](#valdef-top-auto), then its [margin
box](https://drafts.csswg.org/css-box-4/#margin-box) is aligned to the edge of the [inset-modified
containing
block](#inset-modified-containing-block) corresponding to its [stronger
inset](#stronger-inset) (even
if this would overflow its [containing
block](https://drafts.csswg.org/css-display-4/#containing-block)).

Otherwise, if either
[margin](https://drafts.csswg.org/css-box-4/#margin) is [auto], its position is resolved according to
[§ 4.2 Auto Margins of Absolutely-Positioned Boxes](#abspos-margins).

Otherwise, the box is aligned as specified by its [self-alignment
property](https://drafts.csswg.org/css-align-3/#self-alignment-properties) in the relevant axis (as defined by the [writing
mode](https://drafts.csswg.org/css-writing-modes-4/#writing-mode) of the [containing
block](https://drafts.csswg.org/css-display-4/#containing-block)), using its [margin
box](https://drafts.csswg.org/css-box-4/#margin-box) as the [alignment
subject](https://drafts.csswg.org/css-align-3/#alignment-subject) and the [inset-modified containing
block](#inset-modified-containing-block) as the [alignment
container](https://drafts.csswg.org/css-align-3/#alignment-container). However, if an explicit [overflow
alignment](https://drafts.csswg.org/css-align-3/#overflow-alignment) is not specified and its [margin
box] overflows the [inset-modified containing
block], its alignment is
adjusted to minimize overflow as specified in [CSS Box Alignment 3
§ 4.4.1.2 Self-Alignment for Absolutely Positioned
Boxes](https://drafts.csswg.org/css-align-3/#auto-safety-position).

### 4.4. Fragmenting Absolutely-positioned Elements

In a [fragmented
flow](https://drafts.csswg.org/css-break-4/#fragmented-flow), an [absolutely positioned
box](#absolute-position)
is positioned relative to its [containing
block](https://drafts.csswg.org/css-display-4/#containing-block) ignoring any [fragmentation
breaks](https://drafts.csswg.org/css-break-4/#fragmentation-break) (as if the flow were continuous). The box may
subsequently be broken over several [fragmentation
containers](https://drafts.csswg.org/css-break-4/#fragmentation-container).

For absolutely positioned content in [paged
media](https://drafts.csswg.org/mediaqueries-5/#paged-media) that resolves to a position on a page other than the
page being laid out (the current page), or resolves to a position on the
current page that has already been rendered for printing, printers may
place the content:

- on the current page,
- on a subsequent page, or
- may omit it altogether.

 A
[block-level](https://drafts.csswg.org/css-display-4/#block-level) element that is split over several pages can have a
different width on each page, and there may be device-specific limits.

User agents must not paginate the content of [fixed-positioned
boxes](#fixed-position).

 User agents might print invisible content in other
ways. See [CSS Paged Media 3 § 3.2 Content outside the page
box](https://drafts.csswg.org/css-page-3/#content-outside-box).

## 5. Old Absolute Positioning Layout Model

This section is being replaced with the
new [§ 4 Absolute Positioning Layout Model](#abspos-layout) section. It
is preserved here for comparison: both models should yield the same
result in [horizontal writing
modes](https://drafts.csswg.org/css-writing-modes-4/#horizontal-writing-mode) when the box's
[self-alignment](https://drafts.csswg.org/css-align-3/#self-align) is
[normal](https://drafts.csswg.org/css-align-3/#valdef-align-self-normal).

### 5.1. The Width of Absolutely-Positioned, Non-Replaced Elements

The constraint that determines the used values for these elements is:

` `[`left`](#propdef-left)` + `[`margin-left`](https://drafts.csswg.org/css-box-4/#propdef-margin-left)` + `[`border-left-width`](https://drafts.csswg.org/css-backgrounds-3/#propdef-border-left-width)` + `[`padding-left`](https://drafts.csswg.org/css-box-4/#propdef-padding-left)` + `[`width`](https://drafts.csswg.org/css-sizing-3/#propdef-width)` + `[`padding-right`](https://drafts.csswg.org/css-box-4/#propdef-padding-right)` + `[`border-right-width`](https://drafts.csswg.org/css-backgrounds-3/#propdef-border-right-width)` + `[`margin-right`](https://drafts.csswg.org/css-box-4/#propdef-margin-right)` + `[`right`](#propdef-right)` = width of containing block `

If all three of [left](#propdef-left),
[width](https://drafts.csswg.org/css-sizing-3/#propdef-width), and
[right](#propdef-right) are
[auto](#valdef-top-auto): First set any [auto] values for
[margin-left](https://drafts.csswg.org/css-box-4/#propdef-margin-left) and
[margin-right](https://drafts.csswg.org/css-box-4/#propdef-margin-right) to [0]. Then, if the
[direction](https://drafts.csswg.org/css-writing-modes-3/#propdef-direction) property of the element
establishing the static-position [containing
block](https://drafts.csswg.org/css-display-4/#containing-block) is
[ltr](https://drafts.csswg.org/css-writing-modes-4/#valdef-direction-ltr) set [left] to
the static position and apply rule number *three* below; otherwise, set
[right] to the static-position and
apply rule number *one* below.

If none of the three is
[auto](#valdef-top-auto): If both
[margin-left](https://drafts.csswg.org/css-box-4/#propdef-margin-left) and
[margin-right](https://drafts.csswg.org/css-box-4/#propdef-margin-right) are [auto], solve the
equation under the extra constraint that the two margins get equal
values, unless this would make them negative, in which case when
direction of the containing block is
[ltr](https://drafts.csswg.org/css-writing-modes-4/#valdef-direction-ltr)
([rtl](https://drafts.csswg.org/css-writing-modes-4/#valdef-direction-rtl)), set
[margin-left]
([margin-right]) to [0]
and solve for [margin-right]
([margin-left]). If one of
[margin-left] or
[margin-right] is
[auto], solve the equation for that value. If the values are
over-constrained, ignore the value for
[left](#propdef-left) (in case the
[direction](https://drafts.csswg.org/css-writing-modes-3/#propdef-direction) property of the [containing
block](https://drafts.csswg.org/css-display-4/#containing-block) is [rtl]) or
[right](#propdef-right) (in case [direction] is [ltr]) and solve for
that value.

Otherwise, set [auto] values for
[margin-left](https://drafts.csswg.org/css-box-4/#propdef-margin-left) and
[margin-right](https://drafts.csswg.org/css-box-4/#propdef-margin-right) to [0], and pick one of the
following six rules that apply.

1. If [left](#propdef-left) and
 [width](https://drafts.csswg.org/css-sizing-3/#propdef-width) are
 [auto](#valdef-top-auto) and
 [right](#propdef-right) is not [auto], then the width is shrink-to-fit. Then solve for
 [left].
2. If [left](#propdef-left) and
 [right](#propdef-right) are
 [auto](#valdef-top-auto) and
 [width](https://drafts.csswg.org/css-sizing-3/#propdef-width) is not
 [auto](https://drafts.csswg.org/css-sizing-3/#valdef-width-auto), then if the
 [direction](https://drafts.csswg.org/css-writing-modes-3/#propdef-direction) property of the element
 establishing the static-position [containing
 block](https://drafts.csswg.org/css-display-4/#containing-block) is
 [ltr](https://drafts.csswg.org/css-writing-modes-4/#valdef-direction-ltr) set [left] to the static-position, otherwise set
 [right] to the static-position.
 Then solve for [left] (if
 [direction] is
 [rtl](https://drafts.csswg.org/css-writing-modes-4/#valdef-direction-rtl)) or [right] (if [direction] is
 [ltr]).
3. If
 [width](https://drafts.csswg.org/css-sizing-3/#propdef-width) and
 [right](#propdef-right) are
 [auto](https://drafts.csswg.org/css-sizing-3/#valdef-width-auto) and
 [left](#propdef-left) is not
 [auto](#valdef-top-auto), then the width is shrink-to-fit. Then solve for
 [right].
4. If [left](#propdef-left) is
 [auto](#valdef-top-auto),
 [width](https://drafts.csswg.org/css-sizing-3/#propdef-width) and
 [right](#propdef-right) are not
 [auto](https://drafts.csswg.org/css-sizing-3/#valdef-width-auto), then solve for
 [left].
5. If
 [width](https://drafts.csswg.org/css-sizing-3/#propdef-width) is
 [auto](https://drafts.csswg.org/css-sizing-3/#valdef-width-auto),
 [left](#propdef-left) and
 [right](#propdef-right) are not
 [auto](#valdef-top-auto), then solve for [width].
6. If [right](#propdef-right) is
 [auto](#valdef-top-auto), [left](#propdef-left) and
 [width](https://drafts.csswg.org/css-sizing-3/#propdef-width) are not
 [auto], then solve for
 [right].

Summary of rules for `dir=ltr` in horizontal writing modes

Is auto?

Result

[left](#propdef-left)

[width](https://drafts.csswg.org/css-sizing-3/#propdef-width)

[right](#propdef-right)

[margin-left](https://drafts.csswg.org/css-box-4/#propdef-margin-left)

[margin-right](https://drafts.csswg.org/css-box-4/#propdef-margin-right)

✔

✔

✔

any

- auto margins → zero
- left → static pos
- width → shrink-to-fit
- right → solve

✘

✘

✘

✔

✘

auto margin → free space

✘

✔

✔

✔

- margins split positive free space
- right margin gets negative free space

✘

✘

treat [right](#propdef-right) as
[auto](#valdef-top-auto)

✔

✘

✔

any

- auto margins → zero
- left → static pos
- width → as specified
- right → solve

✔

✔

✘

any

- auto margins → zero
- left → solve
- width → shrink-to-fit
- right → as specified

✘

✔

✔

any

- auto margins → zero
- left → as specified
- width → shrink-to-fit
- right → solve

✔

✘

✘

any

- auto margins → zero
- solve for auto

✘

✘

✔

✘

✔

✘

### 5.2. The width of absolute or fixed positioned, replaced elements

If
[height](https://drafts.csswg.org/css-sizing-3/#propdef-height) and
[width](https://drafts.csswg.org/css-sizing-3/#propdef-width) both have computed values of
[auto] and the element also has an intrinsic width, then that
intrinsic width is the used value of [width].

If
[height](https://drafts.csswg.org/css-sizing-3/#propdef-height) and
[width](https://drafts.csswg.org/css-sizing-3/#propdef-width) both have computed values of
[auto] and the element has no intrinsic width, but does have an
intrinsic height and intrinsic ratio; or if
[width] has a computed value of
[auto], [height] has some
other computed value, and the element does have an intrinsic ratio; then
the used value of [width] is:

`(used height) * (intrinsic ratio)`

If
[height](https://drafts.csswg.org/css-sizing-3/#propdef-height) and
[width](https://drafts.csswg.org/css-sizing-3/#propdef-width) both have computed values of
[auto], the element has an intrinsic ratio but no intrinsic height
or width, and the [containing
block's](https://drafts.csswg.org/css-display-4/#containing-block) width does not itself depend on the replaced element's
width, then the used value of [width] is calculated from the constraint equation used for
[block-level, non-replaced elements in normal
flow](https://www.w3.org/TR/CSS21/visudet.html#blockwidth).

Otherwise, if
[width](https://drafts.csswg.org/css-sizing-3/#propdef-width) has a computed value of
[auto], and the element has an intrinsic width, then that
intrinsic width is the used value of [width].

Otherwise, if
[width](https://drafts.csswg.org/css-sizing-3/#propdef-width) has a computed value of
[auto], but none of the conditions above are met, and then the
used value of [width] becomes
[300px]. If [300px] is too wide to fit the device, user
agents should use the width of the largest rectangle that has a 2:1
ratio and fits the device instead.

After establishing the
[width](https://drafts.csswg.org/css-sizing-3/#propdef-width), in order to position the replaced
element, apply the following rules as appropriate.

1. If both [left](#propdef-left) and
 [right](#propdef-right) have the value [auto], and if the
 [direction](https://drafts.csswg.org/css-writing-modes-3/#propdef-direction) property of the element
 establishing the static-position [containing
 block](https://drafts.csswg.org/css-display-4/#containing-block) is
 [ltr](https://drafts.csswg.org/css-writing-modes-4/#valdef-direction-ltr), set [left] to the static position and solve for
 [right]; else if
 [direction] is
 [rtl](https://drafts.csswg.org/css-writing-modes-4/#valdef-direction-rtl), set [right] to the static position and solve for
 [left].
2. If [left](#propdef-left) is [auto] and
 [right](#propdef-right) is not [auto], replace any [auto]
 on
 [margin-left](https://drafts.csswg.org/css-box-4/#propdef-margin-left) or
 [margin-right](https://drafts.csswg.org/css-box-4/#propdef-margin-right) with [0], then solve for
 [left].
3. If [right](#propdef-right) is [auto] and
 [left](#propdef-left) is not [auto], replace any [auto]
 on
 [margin-left](https://drafts.csswg.org/css-box-4/#propdef-margin-left) or
 [margin-right](https://drafts.csswg.org/css-box-4/#propdef-margin-right) with [0], then solve for
 [right].
4. If at this point both
 [margin-left](https://drafts.csswg.org/css-box-4/#propdef-margin-left) and
 [margin-right](https://drafts.csswg.org/css-box-4/#propdef-margin-right) are still [auto], solve
 the equation under the extra constraint that the two margins must
 get equal values, unless this would make them negative, in which
 case when the direction of the [containing
 block](https://drafts.csswg.org/css-display-4/#containing-block) is
 [ltr](https://drafts.csswg.org/css-writing-modes-4/#valdef-direction-ltr)
 ([rtl](https://drafts.csswg.org/css-writing-modes-4/#valdef-direction-rtl)), set
 [margin-left]
 ([margin-right]) to
 [0] and solve for
 [margin-right]
 ([margin-left]).
5. If at this point there is an [auto] remaining, solve the
 equation for that value.
6. If at this point the values are over-constrained, ignore the value
 for either [left](#propdef-left) (in case the
 [direction](https://drafts.csswg.org/css-writing-modes-3/#propdef-direction) property of the [containing
 block](https://drafts.csswg.org/css-display-4/#containing-block) is
 [rtl](https://drafts.csswg.org/css-writing-modes-4/#valdef-direction-rtl)) or
 [right](#propdef-right) (in case
 [direction] is
 [ltr](https://drafts.csswg.org/css-writing-modes-4/#valdef-direction-ltr)) and solve for that value.

### 5.3. The Height Of Absolutely Positioned, Non-Replaced Elements

For absolutely positioned elements, the used values of the vertical
dimensions must satisfy this constraint:

` `[`top`](#propdef-top)` + `[`margin-top`](https://drafts.csswg.org/css-box-4/#propdef-margin-top)` + `[`border-top-width`](https://drafts.csswg.org/css-backgrounds-3/#propdef-border-top-width)` + `[`padding-top`](https://drafts.csswg.org/css-box-4/#propdef-padding-top)` + `[`height`](https://drafts.csswg.org/css-sizing-3/#propdef-height)` + `[`padding-bottom`](https://drafts.csswg.org/css-box-4/#propdef-padding-bottom)` + `[`border-bottom-width`](https://drafts.csswg.org/css-backgrounds-3/#propdef-border-bottom-width)` + `[`margin-bottom`](https://drafts.csswg.org/css-box-4/#propdef-margin-bottom)` + `[`bottom`](#propdef-bottom)` = ``height of containing block`` `

If all three of [top](#propdef-top),
[height](https://drafts.csswg.org/css-sizing-3/#propdef-height), and
[bottom](#propdef-bottom) are
[auto](#valdef-top-auto): First set any [auto] values for
[margin-top](https://drafts.csswg.org/css-box-4/#propdef-margin-top) and
[margin-bottom](https://drafts.csswg.org/css-box-4/#propdef-margin-bottom) to [0], then set
[top] to the static position, and
finally apply rule number *three* below.

If none of the three are
[auto](#valdef-top-auto): If both
[margin-top](https://drafts.csswg.org/css-box-4/#propdef-margin-top) and
[margin-bottom](https://drafts.csswg.org/css-box-4/#propdef-margin-bottom) are
[auto], solve the equation under the
extra constraint that the two margins get equal values. If one of
[margin-top] or
[margin-bottom] is
[auto], solve the equation for that
value. If the values are over-constrained, ignore the value for
[bottom](#propdef-bottom) and solve for that value.

Otherwise, set [auto](#valdef-top-auto) values for
[margin-top](https://drafts.csswg.org/css-box-4/#propdef-margin-top) and
[margin-bottom](https://drafts.csswg.org/css-box-4/#propdef-margin-bottom) to [0], and pick one of the
following six rules that apply.

1. If [top](#propdef-top) and
 [height](https://drafts.csswg.org/css-sizing-3/#propdef-height) are
 [auto](#valdef-top-auto) and
 [bottom](#propdef-bottom) is not [auto], then the height is based on the [Auto heights for block
 formatting context
 roots](https://www.w3.org/TR/CSS2/visudet.html#root-height), and
 solve for [top].

2. If [top](#propdef-top) and
 [bottom](#propdef-bottom) are
 [auto](#valdef-top-auto) and
 [height](https://drafts.csswg.org/css-sizing-3/#propdef-height) is not
 [auto], then set
 [top] to the static position, then
 solve for [bottom].

3. If
 [height](https://drafts.csswg.org/css-sizing-3/#propdef-height) and
 [bottom](#propdef-bottom) are
 [auto](#valdef-top-auto) and [top](#propdef-top) is not
 [auto], then the height is based on
 the [Auto heights for block formatting context
 roots](https://www.w3.org/TR/CSS2/visudet.html#root-height), and
 solve for [bottom].

4. If [top](#propdef-top) is
 [auto](#valdef-top-auto),
 [height](https://drafts.csswg.org/css-sizing-3/#propdef-height) and
 [bottom](#propdef-bottom) are not [auto], then solve for [top].

5. If
 [height](https://drafts.csswg.org/css-sizing-3/#propdef-height) is
 [auto](#valdef-top-auto), [top](#propdef-top) and
 [bottom](#propdef-bottom) are not [auto], then solve for [height].

6. If [bottom](#propdef-bottom) is
 [auto](#valdef-top-auto), [top](#propdef-top) and
 [height](https://drafts.csswg.org/css-sizing-3/#propdef-height) are not
 [auto], then solve for
 [bottom].

### 5.4. The Height Of Absolutely Positioned, Replaced Elements

If
[height](https://drafts.csswg.org/css-sizing-3/#propdef-height) and
[width](https://drafts.csswg.org/css-sizing-3/#propdef-width) both have computed values of
[auto](#valdef-top-auto) and the element also has an intrinsic height, then
that intrinsic height is the used value of
[height].

Otherwise, if
[height](https://drafts.csswg.org/css-sizing-3/#propdef-height) has a computed value of
[auto](#valdef-top-auto) and the element has an intrinsic ratio then the used
value of [height] is:

`(used width) / (intrinsic ratio)`

Otherwise, if
[height](https://drafts.csswg.org/css-sizing-3/#propdef-height) has a computed value of
[auto](#valdef-top-auto) and the element has an intrinsic height, then that
intrinsic height is the used value of [height].

Otherwise, if
[height](https://drafts.csswg.org/css-sizing-3/#propdef-height) has a computed value of
[auto](#valdef-top-auto), but none of the conditions above are met, then the
used value of [height] must be set
to the height of the largest rectangle that has a 2:1 ratio, has a
height not greater than [150px], and has a width not greater than
the device width.

After establishing the
[height](https://drafts.csswg.org/css-sizing-3/#propdef-height), in order to position the replaced
element, apply the following rules as appropriate.

1. If both [top](#propdef-top) and
 [bottom](#propdef-bottom) have the value
 [auto](#valdef-top-auto), replace [top]
 with the element's static position.

2. If [bottom](#propdef-bottom) is
 [auto](#valdef-top-auto), replace any [auto] on
 [margin-top](https://drafts.csswg.org/css-box-4/#propdef-margin-top) or
 [margin-bottom](https://drafts.csswg.org/css-box-4/#propdef-margin-bottom) with [0].

3. If at this point both
 [margin-top](https://drafts.csswg.org/css-box-4/#propdef-margin-top) and
 [margin-bottom](https://drafts.csswg.org/css-box-4/#propdef-margin-bottom) are still
 [auto](#valdef-top-auto), solve the equation under the extra constraint
 that the two margins must get equal values.

4. If at this point there is only one
 [auto](#valdef-top-auto) remaining, solve the equation for that value.

5. If at this point the values are over-constrained, ignore the value
 for [bottom](#propdef-bottom) and solve for that value.

## 6. Informative Comparison of Normal Flow, Floats, and Positioning

*This section is not normative.*

To illustrate the differences between [normal
flow](https://www.w3.org/TR/CSS2/visuren.html#normal-flow), [relative
positioning](#relative-position),
[floats](https://drafts.csswg.org/css-page-floats-3/#float), and [absolute
positioning](#absolute-position), we provide a series of examples based on the following
HTML:

```
<!DOCTYPE html>
<html>
 <head>
 <title>Comparison of positioning schemes</title>
 <style>
 body { display: block; font-size:12px; line-height: 200%;
 width: 400px; height: 400px }
 p { display: block }
 span { display: inline }
 </style>
 </head>
 <body>
 <p>
 Beginning of p contents.
 <span id="outer"> Start of outer contents.
 <span id="inner"> Inner contents.</span>
 End of outer contents.</span>
 End of p contents.
 </p>
 </body>
</html>
```

The final positions of boxes generated by the *outer* and *inner*
elements vary in each example. In each illustration, the numbers to the
left of the illustration indicate the [normal
flow](https://www.w3.org/TR/CSS2/visuren.html#normal-flow) position of the double-spaced (for clarity) lines.

 The diagrams in this section are illustrative and not
to scale. They are meant to highlight the differences between the
various [positioning
schemes](#positioning-scheme), and are not intended to be reference renderings of the
examples given.

### 6.1. Normal Flow Example

Consider the following CSS declarations for *outer* and *inner* that do
not alter the [normal
flow](https://www.w3.org/TR/CSS2/visuren.html#normal-flow) of boxes:

```
#outer { color: red }
#inner { color: blue }
```

The P element contains all inline content: [anonymous inline
text](https://www.w3.org/TR/CSS2/visuren.html#anonymous) and two SPAN
elements. Therefore, all of the content will be laid out in an inline
formatting context, within a [containing
block](https://drafts.csswg.org/css-display-4/#containing-block) established by the P element, producing something like:

![All of the text within the P's containing block flows together as
continuous text, even though it's located in separated nested
elements.](images/flow-generic.png){a
height="342" width="326"}

### 6.2. Relative Positioning Example

To see the effect of [relative
positioning](#relative-position), we specify:

```
#outer { position: relative; top: -12px; color: red }
#inner { position: relative; top: 12px; color: blue }
```

Text flows normally up to the *outer* element. The *outer* text is then
flowed into its [normal
flow](https://www.w3.org/TR/CSS2/visuren.html#normal-flow) position and dimensions at the end of line 1. Then, the
inline boxes containing the text (distributed over three lines) are
shifted as a unit by [-12px] (upwards).

The contents of *inner*, as a child of *outer*, would normally flow
immediately after the words \"of outer contents\" (on line 1.5).
However, the *inner* contents are themselves offset relative to the
*outer* contents by [12px] (downwards), back to their original
position on line 2.

Note that the content following *outer* is not affected by the relative
positioning of *outer*.

![The result is identical to normal flow, except that the \"outer\" text
is shifted 12px upward, without affecting the flow of the \"body\" or
\"inner\" text.](images/flow-relative.png){height="342" width="326"}

Note also that had the offset of *outer* been [-24px], the text of
*outer* and the body text would have overlapped.

### 6.3. Floating Example

Now consider the effect of
[floating](https://www.w3.org/TR/CSS2/visuren.html#floats) the *inner*
element's text to the right by means of the following rules:

```
#outer { color: red }
#inner { float: right; width: 130px; color: blue }
```

Text flows normally up to the *inner* box, which is pulled out of the
flow and
[floated](https://drafts.csswg.org/css-page-floats-3/#float) to the right margin (its
[width](https://drafts.csswg.org/css-sizing-3/#propdef-width) has been assigned explicitly). Line
boxes to the left of the float are shortened, and the document's
remaining text flows into them.

![The \"inner\" text lays out in an independent box on the right,
causing the remaining \"body\" and \"outer\" text to flow around
it.](images/flow-float.png){a
height="342" width="326"}

To show the effect of the
[clear](https://drafts.csswg.org/css2/#propdef-clear) property, we add a *sibling*
element to the example:

```
<!DOCTYPE html>
<html>
 <head>
 <title>Comparison of positioning schemes II</title>
 <style>
 #inner { float: right; width: 130px; color: blue }
 #sibling { color: red }
 </style>
 </head>
 <body>
 <p>
 Beginning of p contents.
 <span id="outer"> Start of outer contents.
 <span id="inner"> Inner contents.</span>
 <span id="sibling"> Sibling contents.</span>
 End of outer contents.</span>
 End of p contents.
 </p>
 </body>
</html>
```

These styles cause the *inner* box to float to the right, as before, and
the document's remaining text to flow into the vacated space:

![Identical to the previous example, save that there is now \"sibling\"
text flowing with the \"body\" and \"outer\"
text.](images/flow-clear.png){a
height="342" width="326"}

However, if the
[clear](https://drafts.csswg.org/css2/#propdef-clear) property on the *sibling* element
is set to [right](#propdef-right) (i.e., the generated *sibling* box will
not accept a position next to
[floating](https://drafts.csswg.org/css-page-floats-3/#float) boxes to its right), the *sibling* content begins to
flow below the float:

```
#inner { float: right; width: 130px; color: blue }
#sibling { clear: right; color: red }
```

![Now the \"sibling\" text moves down to below the \"inner\" text's box,
leaving blank space behind. The text following the \"sibling\" text
flows after it as
normal.](images/flow-clear2.png){a
height="342" width="326"}

### 6.4. Absolute Positioning Example

Next, we consider the effect of absolute positioning. Consider the
following CSS declarations for *outer* and *inner*:

```
#outer {
 position: absolute;
 top: 200px; left: 200px;
 width: 200px;
 color: red;
}
#inner { color: blue }
```

which cause the top of the *outer* box to be positioned with respect to
its [containing
block](https://drafts.csswg.org/css-display-4/#containing-block). The [containing block]
for a positioned box is established by the nearest positioned ancestor
(or, if none exists, the initial containing block, as in our example).
The top side of the *outer* box is [200px] below the top of the
[containing block] and the left side is
[200px] from the left side. The child box of *outer* is flowed
normally with respect to its parent.

![All of the text within #outer (the \"outer\" and \"inner\" text) moves
down to an independent box in the lower right corner. The two halves of
\"body\" text flow
together.](images/flow-absolute.png){a
height="342" width="326"}

The following example shows an absolutely positioned box that is a child
of a relatively positioned box. Although the parent *outer* box is not
actually offset, setting its
[position](#propdef-position) property to
[relative](#valdef-position-relative) means that its box may serve as the containing
block for positioned descendants. Since the *outer* box is an inline box
that is split across several lines, the first inline box's top and left
edges (depicted by thick dashed lines in the illustration below) serve
as references for [top](#propdef-top) and
[left](#propdef-left) offsets.

```
#outer {
 position: relative;
 color: red
}
#inner {
 position: absolute;
 top: 200px; left: -100px;
 height: 130px; width: 130px;
 color: blue;
}
```

This results in something like the following:

![The \"inner\" text is positioned in an independent box, relative to
the top-left corner of the start of the \"outer\"
text.](images/flow-abs-rel.png){a
height="345" width="385"}

If we do not position the *outer* box:

```
#outer { color: red }
#inner {
 position: absolute;
 top: 200px; left: -100px;
 height: 130px; width: 130px;
 color: blue;
}
```

the [containing
block](https://drafts.csswg.org/css-display-4/#containing-block) for *inner* becomes the initial containing block (in
our example). The following illustration shows where the *inner* box
would end up in this case.

![Same as before, except now the \"inner text\" is positioned relative
to the top-left corner of the page
itself.](images/flow-static.png){a
height="342" width="326"}

Relative and absolute positioning may be used to implement change bars,
as shown in the following example. The following fragment:

```
<p style="position: relative; margin-right: 10px; left: 10px;">
 I used two red hyphens to serve as a change bar. They
 will "float" to the left of the line containing THIS
 <span style="position: absolute; top: auto; left: -1em; color: red;">--</span>
 word.
</p>
```

might result in something like:

![The two red hyphens, indicating a change, sit in the left margin of
the page on the line containing the word \"THIS\", regardless of what
line that ends up
being.](images/changebar.png){a
height="141" width="243"}

First, the paragraph (whose [containing
block](https://drafts.csswg.org/css-display-4/#containing-block) sides are shown in the illustration) is flowed
normally. Then it is offset [10px] from the left edge of the
[containing block] (thus, a right margin of
[10px] has been reserved in anticipation of the offset). The two
hyphens acting as change bars are taken out of the flow and positioned
at the current line (due to \'top: auto\'), [-1em] from the left
edge of its containing block (established by the P in its final
position). The result is that the change bars seem to \"float\" to the
left of the current line.

## 7. Acknowledgments

This module would not have been possible without input and support from
many helpful people. Thanks to Rossen Atanassov, Bert Bos, Oriol Brufau,
Tantek Çelik, Arron Eicholz Sylvain Galineau, John Jansen, Chris Jones,
Ian Kilpatrick, Anton Prowse.

## [Changes]
Significant changes since the [7 October 2025 Working
Draft](https://www.w3.org/TR/2025/WD-css-position-3-20251007/):

- Auto margins do not suppress stretch alignment. ([Issue
 11195](https://github.com/w3c/csswg-drafts/issues/11195))

Significant changes since the [11 March 2025 Working
Draft](ttps://www.w3.org/TR/2025/WD-css-position-3-20250311/#changes):

- Defined the [initial fixed containing
 block](#initial-fixed-containing-block) and its relationship to the [initial containing
 block](https://drafts.csswg.org/css-display-4/#initial-containing-block), to give this concept a name.

See also [Previous
Changes](https://www.w3.org/TR/2025/WD-css-position-3-20250311/#changes).

## [ Privacy Considerations]
This specification introduces no new privacy considerations.

## [ Security Considerations]
If an attacker is able to inject arbitrary CSS, positioned layout can
make it easier to position elements the attacker has control of over
arbitrary other elements of the page, potentially tricking users of the
page. (There are many routes to this attack: negative
[margin](https://drafts.csswg.org/css-box-4/#propdef-margin),
[transform](https://drafts.csswg.org/css-transforms-1/#propdef-transform), etc. Don't let people apply
arbitrary CSS to bits of your page.)

[position: fixed](#propdef-position) can allow a page to emulate modal dialogs,
potentially tricking a user into thinking they're interacting with the
user agent and entering in sensitive information that they page can then
capture. User agents must ensure that their native dialogs are
positioned in ways that the page cannot emulate; in particular, that at
least some of the dialog is outside the \"poisoned pixels\" that web
content can paint to.
