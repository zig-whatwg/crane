## 1. Introduction

*This section is not normative.*

The CSS [visual formatting
model](https://www.w3.org/TR/CSS2/visuren.html) describes a coordinate
system within each element is positioned. Positions and sizes in this
coordinate space can be thought of as being expressed in pixels,
starting in the origin of point with positive values proceeding to the
right and down.

This coordinate space can be modified with the
[transform](#propdef-transform) property. Using transform, elements can
be translated, rotated and scaled.

### 1.1. Module Interactions

This module defines a set of CSS properties that affect the visual
rendering of elements to which those properties are applied; these
effects are applied after elements have been sized and positioned
according to the [visual formatting
model](https://www.w3.org/TR/CSS2/visuren.html) from
[\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification").
Some values of these properties result in the creation of a [containing
block](https://www.w3.org/TR/CSS2/visuren.html#containing-block), and/or
the creation of a [stacking
context](https://www.w3.org/TR/CSS2/visuren.html#x43).

Transforms affect the rendering of backgrounds on elements with a value
of
[fixed](https://drafts.csswg.org/css-backgrounds-3/#valdef-background-attachment-fixed) for the
[background-attachment](https://drafts.csswg.org/css-backgrounds-3/#propdef-background-attachment) property, which is specified in
[\[CSS3BG\]](#biblio-css3bg "CSS Backgrounds and Borders Module Level 3").

Transforms affect the client rectangles returned by the Element
Interface Extensions
[getClientRects()](https://www.w3.org/TR/cssom-view/#dom-element-getclientrects)
and
[getBoundingClientRect()](https://www.w3.org/TR/cssom-view/#dom-element-getboundingclientrect),
which are specified in
[\[CSSOM-VIEW\]](#biblio-cssom-view "CSSOM View Module").

Transforms affect the computation of the [scrollable overflow
region](https://www.w3.org/TR/css-overflow-3/#scrollable-overflow-region)
as described by
[\[CSS-OVERFLOW-3\]](#biblio-css-overflow-3 "CSS Overflow Module Level 3").

### 1.2. CSS Values

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
been repeated explicitly. Terminology

==========================

When used in this specification, terms have the meanings assigned in
this section.

[transformable element]

: A transformable element is an element in one of these categories:

 - all elements whose layout is governed by the CSS box model except
 for non-replaced inline boxes, table-column boxes, and
 table-column-group boxes
 [\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification"),

 - all SVG [paint server
 elements](https://w3c.github.io/svgwg/svg2-draft/painting.html#TermPaintServerElement), the
 [clipPath](https://drafts.csswg.org/css-masking-1/#elementdef-clippath) element and SVG [renderable
 elements](https://w3c.github.io/svgwg/svg2-draft/render.html#TermRenderableElement) with the exception of any descendant element of
 [text content
 elements](https://w3c.github.io/svgwg/svg2-draft/text.html#TermTextContentElement)
 [\[SVG2\]](#biblio-svg2 "Scalable Vector Graphics (SVG) 2").

[transformed element]

: An element with a computed value other than [none] for the
 [transform](#propdef-transform) property.

[user coordinate system]\
[local coordinate system]

: In general, a coordinate system defines locations and distances on
 the current canvas. The current local coordinate system (also user
 coordinate system) is the coordinate system that is currently active
 and which is used to define how coordinates and lengths are located
 and computed, respectively, on the current canvas. The current user
 coordinate system has its origin at the top-left of a [reference
 box](#reference-box)
 specified by the
 [transform-box](#propdef-transform-box) property. Percentage values are
 relative to the dimension of this reference box. One unit equals one
 CSS pixel.

[transformation matrix]

: A matrix that defines the mathematical mapping from one coordinate
 system into another. It is computed from the values of the
 [transform](#propdef-transform) and
 [transform-origin](#propdef-transform-origin) properties as described
 [below](#transformation-matrix-computation).

[current transformation matrix] (CTM)

: A matrix that defines the mapping from the [local coordinate
 system](#local-coordinate-system) into the [viewport coordinate
 system](https://w3c.github.io/svgwg/svg2-draft/coords.html#TermViewportCoordinateSystem).

[2D matrix]

: A 3x2 transformation matrix, or a 4x4 matrix where the items m~31~,
 m~32~, m~13~, m~23~, m~43~, m~14~, m~24~, m~34~ are equal to
 [0] and m~33~, m~44~ are equal to [1].

[identity transform function]

: A [transform function](#transform-functions) that is equivalent to a
 identity 4x4 matrix (see [Mathematical Description of Transform
 Functions](#mathematical-description)). Examples for identity
 transform functions are [translate(0)], [translateX(0)],
 [translateY(0)], [scale(1)], [scaleX(1)],
 [scaleY(1)], [rotate(0)], [skew(0, 0)],
 [skewX(0)], [skewY(0)] and [matrix(1, 0, 0, 1, 0,
 0)].

[post-multiply]\
[post-multiplied]

: Term `A` post-multiplied by term `B` is equal
 to `A` · `B`.

[pre-multiply]\
[pre-multiplied]

: Term `A` pre-multiplied by term `B` is equal
 to `B` · `A`.

[multiply]

: Multiply term `A` by term `B` is equal to
 `A` · `B`.

## 2. The Transform Rendering Model

*This section is normative.*

Specifying a value other than [none] for the
[transform](#propdef-transform) property establishes a new [local
coordinate
system](#local-coordinate-system) at the element that it is applied to. The mapping from
where the element would have rendered into that local coordinate system
is given by the element's [transformation
matrix](#transformation-matrix).

The [transformation
matrix](#transformation-matrix) is computed from the
[transform](#propdef-transform) and
[transform-origin](#propdef-transform-origin) properties as follows:

1. Start with the identity matrix.

2. Translate by the computed X and Y of
 [transform-origin](#propdef-transform-origin)

3. Multiply by each of the transform functions in
 [transform](#propdef-transform) property from left to right

4. Translate by the negated computed X and Y values of
 [transform-origin](#propdef-transform-origin)

An element has a
[transform](#propdef-transform) property that is not [none].

``` highlight
div {
 transform-origin: 0 0;
 transform: translate(-10px, -20px) scale(2) rotate(45deg);
}
```

The
[transform-origin](#propdef-transform-origin) property is set to [0 0] and
can be omitted. The [transformation
matrix](#transformation-matrix) *TM* gets computed by post-multiplying the
[\<translate()\>](#funcdef-transform-translate),
[\<scale()\>](#funcdef-transform-scale) and
[\<rotate()\>](#funcdef-transform-rotate)
[\<transform-function\>](#typedef-transform-function)s.

![TM = \\begin{bmatrix} 1 & 0 & 0 & -10 \\\\ 0 & 1 & 0 & -20 \\\\ 0 & 0
& 1 & 0 \\\\ 0 & 0 & 0 & 1 \\end{bmatrix} \\cdot \\begin{bmatrix} 2 & 0
& 0 & 0 \\\\ 0 & 2 & 0 & 0 \\\\ 0 & 0 & 1 & 0 \\\\ 0 & 0 & 0 & 1
\\end{bmatrix} \\cdot \\begin{bmatrix} cos(45) & -sin(45) & 0 & 0 \\\\
sin(45) & cos(45) & 0 & 0 \\\\ 0 & 0 & 1 & 0 \\\\ 0 & 0 & 0 & 1
\\end{bmatrix}](images/tm.png){width="627"}

Transforms apply to [transformable
elements](#transformable-element).

The coordinate space is a coordinate system with two axes: the X axis
increases horizontally to the right; the Y axis increases vertically
downwards.

Transformations are cumulative. That is, elements establish their local
coordinate system within the coordinate system of their parent.

To map a point *p~local~* with the coordinate pair *x~local~* and
*y~local~* from the [local coordinate
system](#local-coordinate-system) of an element into the parent's coordinate system,
post-multiply the [transformation
matrix](#transformation-matrix) *TM* of the element by *p~local~*. The result is the
mapped point *p~parent~* with the coordinate pair *x~parent~* and
*y~parent~* in the parent's [local coordinate
system].

![\\begin{bmatrix} x\_{parent} \\\\ y\_{parent} \\\\ 0 \\\\ 1
\\end{bmatrix} = TM \\cdot \\begin{bmatrix} x\_{local} \\\\ y\_{local}
\\\\ 0 \\\\ 1 \\end{bmatrix}](images/tm-map.png){width="276"}

From the perspective of the user, an element effectively accumulates all
the [transform](#propdef-transform) properties of its ancestors as well as
any local transform applied to it. The accumulation of these transforms
defines a [current transformation
matrix](#current-transformation-matrix) (CTM) for the element.

The [current transformation
matrix](#current-transformation-matrix) is computed by post-multiplying all transformation
matrices starting from the [viewport coordinate
system](https://w3c.github.io/svgwg/svg2-draft/coords.html#TermViewportCoordinateSystem) and ending with the [transformation
matrix](#transformation-matrix) of an element.

This example has multiple, nested
elements in an SVG document. Some elements get transformed by a
[transformation
matrix](#transformation-matrix).

``` highlight
<svg xmlns="http://www.w3.org/2000/svg">
 <g transform="translate(-10, 20)">
 <g transform="scale(2)">
 <rect width="200" height="200" transform="rotate(45)"/>
 </g>
 </g>
</svg>
```

- [translate(-10, 20)] computes to the transformation matrix *T1*

- [scale(2)] computes to the transformation matrix *T2*

- [rotate(45)] computes to the transformation matrix *T3*

The CTM for the SVG
[rect](https://w3c.github.io/svgwg/svg2-draft/shapes.html#elementdef-rect) element is the result of multiplying *T1*, *T2* and
*T3* in order.

![CTM = \\begin{bmatrix} 1 & 0 & 0 & -10 \\\\ 0 & 1 & 0 & -20 \\\\ 0 & 0
& 1 & 0 \\\\ 0 & 0 & 0 & 1 \\end{bmatrix} \\cdot \\begin{bmatrix} 2 & 0
& 0 & 0 \\\\ 0 & 2 & 0 & 0 \\\\ 0 & 0 & 1 & 0 \\\\ 0 & 0 & 0 & 1
\\end{bmatrix} \\cdot \\begin{bmatrix} cos(45) & -sin(45) & 0 & 0 \\\\
sin(45) & cos(45) & 0 & 0 \\\\ 0 & 0 & 1 & 0 \\\\ 0 & 0 & 0 & 1
\\end{bmatrix}](images/ctm.png){width="627"}

To map a point *p~local~* with the coordinate pair *x~local~* and
*y~local~* from the [local coordinate
system](#local-coordinate-system) of the SVG
[rect](https://w3c.github.io/svgwg/svg2-draft/shapes.html#elementdef-rect) element into the [viewport coordinate
system](https://w3c.github.io/svgwg/svg2-draft/coords.html#TermViewportCoordinateSystem), post-multiply the [current transformation
matrix](#current-transformation-matrix) *CTM* of the element by *p~local~*. The result is the
mapped point *p~viewport~* with the coordinate pair *x~viewport~* and
*y~viewport~* in the [viewport coordinate
system].

![\\begin{bmatrix} x\_{viewport} \\\\ y\_{viewport} \\\\ 0 \\\\ 1
\\end{bmatrix} = CTM \\cdot \\begin{bmatrix} x\_{local} \\\\ y\_{local}
\\\\ 0 \\\\ 1 \\end{bmatrix}](images/ctm-map.png){width="276"}

 Transformations do affect the visual rendering, but
have no effect on the CSS layout other than affecting overflow.
Transforms are also taken into account when computing client rectangles
exposed via the Element Interface Extensions, namely
[getClientRects()](https://www.w3.org/TR/cssom-view/#dom-element-getclientrects)
and
[getBoundingClientRect()](https://www.w3.org/TR/cssom-view/#dom-element-getboundingclientrect),
which are specified in
[\[CSSOM-VIEW\]](#biblio-cssom-view "CSSOM View Module").

``` highlight
div {
 transform: translate(100px, 100px);
}
```

This transform moves the element by 100 pixels in both the X and Y
directions.

![The 100px translation in X and
Y](examples/translate1.svg){height="250" width="470"}

``` highlight
div {
 height: 100px; width: 100px;
 transform-origin: 50px 50px;
 transform: rotate(45deg);
}
```

The
[transform-origin](#propdef-transform-origin) property moves the point of origin
by 50 pixels in both the X and Y directions. The transform rotates the
element clockwise by 45° about the point of origin. After all transform
functions were applied, the translation of the origin gets translated
back by -50 pixels in both the X and Y directions.

![The point of origin gets translated
temporary](examples/origin1.svg){height="250" width="735"}

``` highlight
div {
 height: 100px; width: 100px;
 transform: translate(80px, 80px) scale(1.5, 1.5) rotate(45deg);
}
```

The visual appearance is as if the
[div](https://html.spec.whatwg.org/multipage/grouping-content.html#the-div-element) element gets translated by 80px to the bottom left
direction, then scaled up by 150% and finally rotated by 45°.

Each
[\<transform-function\>](#typedef-transform-function) can get represented by a
corresponding 4x4 matrix. To map a point from the coordinate space of
the
[div](https://html.spec.whatwg.org/multipage/grouping-content.html#the-div-element) box to the coordinate space of the parent element,
these transforms get multiplied in the reverse order:

1. The rotation matrix gets
 [post-multiplied](#post-multiplied) by the scale matrix.

2. The result of the previous multiplication is then
 [post-multiplied](#post-multiplied) by the translation matrix to create the accumulated
 transformation matrix.

3. Finally, the point to map gets
 [pre-multiplied](#pre-multiplied) with the accumulated transformation matrix.

For more details see [The Transform Function
Lists](#transform-function-lists).

![The transform specified
above](examples/compound_transform.svg){height="270" width="270"}

 The identical rendering can be obtained by nesting
elements with the equivalent transforms:

``` highlight
<div style="transform: translate(80px, 80px)">
 <div style="transform: scale(1.5, 1.5)">
 <div style="transform: rotate(45deg)"></div>
 </div>
</div>
```

For elements whose layout is governed by the CSS box model, the
transform property does not affect the flow of the content surrounding
the transformed element. However, the extent of the overflow area takes
into account transformed elements. This behavior is similar to what
happens when elements are offset via relative positioning. Therefore, if
the value of the
[overflow](https://drafts.csswg.org/css-overflow-3/#propdef-overflow) property is
[scroll](https://drafts.csswg.org/css-overflow-3/#valdef-overflow-scroll) or
[auto](https://drafts.csswg.org/css-overflow-3/#valdef-overflow-auto), scrollbars will appear as needed to see content
that is transformed outside the visible area. Specifically, transforms
can extend (but do not shrink) the size of the overflow area, which is
computed as the union of the bounds of the elements before and after the
application of transforms.

For elements whose layout is governed by the CSS box model, any value
other than [none] for the
[transform](#propdef-transform) property results in the creation of a
stacking context. Implementations must paint the layer it creates,
within its parent stacking context, at the same stacking order that
would be used if it were a positioned element with [z-index:
0](https://drafts.csswg.org/css2/#propdef-z-index). If an element with a transform is
positioned, the [z-index] property
applies as described in
[\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification"),
except that
[auto](https://drafts.csswg.org/css2/#valdef-z-index-auto) is treated as [0] since a new stacking
context is always created.

For elements whose layout is governed by the CSS box model, any value
other than [none] for the
[transform](#propdef-transform) property also causes the element to
establish a [containing block for all
descendants]. Its padding box will be used to layout for
all of its absolute-position descendants, fixed-position descendants,
and descendant fixed background attachments.

To demonstrate the effect of
[containing block for all
descendants](#containing-block-for-all-descendants) on fixed-position descendants, the following code
snippets should behave identically:

``` highlight
<style>
#container {
 width: 300px;
 height: 200px;
 border: 5px dashed black;
 padding: 5px;
 overflow: scroll;
}

#bloat {
 height: 1000px;
}

#child {
 right: 0;
 bottom: 0;
 width: 10%;
 height: 10%;
 background: green;
}
</style>

<div id="container" style="transform:translateX(5px);">
 <div id="bloat"></div>
 <div id="child" style="position:fixed;"></div>
</div>
```

versus

``` highlight
<div id="container" style="position:relative; z-index:0; left:5px;">
 <div id="bloat"></div>
 <div id="child" style="position:absolute;"></div>
</div>
```

When the background of an element is propagated to the canvas (see [CSS
Backgrounds 3 § 2.11.1 The Canvas Background and the Root
Element](https://drafts.csswg.org/css-backgrounds-3/#root-background)
and [CSS Backgrounds 3 § 2.11.2 The Canvas Background and the HTML
\<body\>
Element](https://drafts.csswg.org/css-backgrounds-3/#body-background)),
that background is not affected by any transform specified for that
element or for the root element.

For elements that are effected by a transform (i.e. have a transform
applied to them, or to any of their ancestor elements) and do not have
their background propagated to the canvas, a value of
[fixed](https://drafts.csswg.org/css-backgrounds-3/#valdef-background-attachment-fixed) for the
[background-attachment](https://drafts.csswg.org/css-backgrounds-3/#propdef-background-attachment) property is treated as if it had a
value of
[scroll](https://drafts.csswg.org/css-backgrounds-3/#valdef-background-attachment-scroll). The computed value of
[background-attachment] is not affected.

## 3. The [transform Property]
A transformation is applied to the coordinate system an element renders
into through the
[transform](#propdef-transform) property. This property contains a list
of [transform functions](#transform-functions). The final transformation
value for a coordinate system is obtained by converting each function in
the list to its corresponding matrix like defined in [Mathematical
Description of Transform Functions](#mathematical-description), then
multiplying the matrices.

Name:

[transform]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

none
[\|](https://drafts.csswg.org/css-values-4/#comb-one)
[\<transform-list\>](#typedef-transform-list)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

none

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[transformable
elements](#transformable-element)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

refer to the size of [reference
box](#reference-box)

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

as specified, but with lengths made absolute

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

transform list, see [interpolation rules](#interpolation-of-transforms)

Any computed value other than [none] for the transform affects
containing block and stacking context, as described in [§ 2 The
Transform Rendering Model](#transform-rendering).

``` prod
<transform-list> = <transform-function>+
```

### 3.1. Serialization of [\<transform-function\>s]
To serialize the
[\<transform-function\>](#typedef-transform-function)s, serialize as per their individual
grammars, in the order the grammars are written in, avoiding
[\<calc()\>](https://drafts.csswg.org/css-values-4/#funcdef-calc) expressions where possible,
avoiding [\<calc()\>]
transformations, omitting components when possible without changing the
meaning, joining space-separated tokens with a single space, and
following each serialized comma with a single space.

### 3.2. Resolved value of [transform]
The [transform](#propdef-transform) property is a [resolved value special
case
property](https://drafts.csswg.org/cssom-1/#resolved-value-special-case-property).
[\[CSSOM\]](#biblio-cssom "CSS Object Model (CSSOM)")

When the [computed
value](https://drafts.csswg.org/css-cascade-5/#computed-value) is a
[\<transform-list\>](#typedef-transform-list), the [resolved
value](https://drafts.csswg.org/cssom-1/#resolved-value) is one
[\<matrix()\>](#funcdef-transform-matrix) function computed by the
following algorithm:

1. Let `transform` be a 4x4 matrix initialized to the
 identity matrix. The elements `m11`, `m22`,
 `m33` and `m44` of `transform` must
 be set to [1]; all other elements of `transform`
 must be set to [0].

2. Post-multiply all
 [\<transform-function\>](#typedef-transform-function)s in
 [\<transform-list\>](#typedef-transform-list) to `transform`.

3. Serialize `transform` to a
 [\<matrix()\>](#funcdef-transform-matrix) function.

For other computed values, the [resolved
value](https://drafts.csswg.org/cssom-1/#resolved-value) is the [computed
value](https://drafts.csswg.org/css-cascade-5/#computed-value).

## 4. The [transform-origin Property]
Name:

[transform-origin]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

  \[ left
[\|](https://drafts.csswg.org/css-values-4/#comb-one) center [\|] right
[\|] top [\|] bottom
[\|]
[\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage) \]\
[\|]\
  \[ left [\|] center [\|] right
[\|]
[\<length-percentage\>]
\]\
  \[ top [\|] center [\|]
bottom [\|]
[\<length-percentage\>]
\]
[\<length\>](https://drafts.csswg.org/css-values-4/#length-value)[?](https://drafts.csswg.org/css-values-4/#mult-opt)\
[\|]\
  \[ \[ center [\|] left [\|]
right \]
[&&](https://drafts.csswg.org/css-values-4/#comb-all) \[ center [\|] top
[\|] bottom \] \]
[\<length\>][?]

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

50% 50%

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[transformable
elements](#transformable-element)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

refer to the size of [reference
box](#reference-box)

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

see
[background-position](https://drafts.csswg.org/css-backgrounds-3/#propdef-background-position)

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value

The values of the
[transform](#propdef-transform) and
[transform-origin](#propdef-transform-origin) properties are used to compute the
[transformation
matrix](#transformation-matrix), as described above.

If only one value is specified, the second value is assumed to be
[center](#valdef-transform-origin-center). If one or two values are specified, the third
value is assumed to be [0px].

If two or more values are defined and either no value is a keyword, or
the only used keyword is
[center](#valdef-transform-origin-center), then the first value represents the horizontal
position (or offset) and the second represents the vertical position (or
offset). A third value always represents the Z position (or offset) and
must be of type
[\<length\>](https://drafts.csswg.org/css-values-4/#length-value).

[\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage)

: A percentage for the horizontal offset is relative to the width of
 the [reference box](#reference-box). A percentage for the vertical offset is relative
 to the height of the [reference box]. The
 value for the horizontal and vertical offset represent an offset
 from the top left corner of the [reference
 box].

[\<length\>](https://drafts.csswg.org/css-values-4/#length-value)

: A length value gives a fixed length as the offset. The value for the
 horizontal and vertical offset represent an offset from the top left
 corner of the [reference
 box](#reference-box).

[top]

: Computes to [0%] for the vertical position.

[right]

: Computes to [100%] for the horizontal position.

[bottom]

: Computes to [100%] for the vertical position.

[left]

: Computes to [0%] for the horizontal position.

[center]

: Computes to [50%] ([left 50%]) for the horizontal
 position if the horizontal position is not otherwise specified, or
 [50%] ([top 50%]) for the vertical position if it is.

For SVG elements without associated CSS layout box the initial [used
value](https://drafts.csswg.org/css-cascade-5/#used-value) is [0 0] as if the user agent style sheet
contained:

``` highlight
*:not(svg), *:not(foreignObject) > svg {
 transform-origin: 0 0;
}
```

The
[transform-origin](#propdef-transform-origin) property is a [resolved value
special case
property](https://drafts.csswg.org/cssom-1/#resolved-value-special-case-property) like
[height](https://drafts.csswg.org/css-sizing-3/#propdef-height).
[\[CSSOM\]](#biblio-cssom "CSS Object Model (CSSOM)")

## 5. Transform reference box: the [transform-box property]
Name:

[transform-box]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

content-box
[\|](https://drafts.csswg.org/css-values-4/#comb-one) border-box [\|] fill-box
[\|] stroke-box [\|] view-box

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

view-box

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[transformable
elements](#transformable-element)

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

All transformations defined by the
[transform](#propdef-transform) and
[transform-origin](#propdef-transform-origin) property are relative to the
position and dimensions of the [reference box] of the element. The [reference
box](#reference-box) is
specified by one of the following:

[content-box]

: Uses the content box as reference box. The reference box of a table
 is the border box of its [table wrapper
 box](https://www.w3.org/TR/CSS21/tables.html#model), not its table
 box.

[border-box]

: Uses the border box as reference box. The reference box of a table
 is the border box of its [table wrapper
 box](https://www.w3.org/TR/CSS21/tables.html#model), not its table
 box.

[fill-box]

: Uses the [object bounding
 box](https://w3c.github.io/svgwg/svg2-draft/coords.html#TermObjectBoundingBox) as reference box.

[stroke-box]

: Uses the [stroke bounding
 box](https://w3c.github.io/svgwg/svg2-draft/coords.html#TermStrokeBoundingBox) as reference box.

[view-box]

: Uses the nearest [SVG
 viewport](https://www.w3.org/TR/SVG11/intro.html#TermSVGViewport) as
 reference box.

For the SVG
[`pattern`](https://w3c.github.io/svgwg/svg2-draft/pservers.html#elementdef-pattern) element, the reference box gets defined by the
[`patternUnits`](https://www.w3.org/TR/SVG/pservers.html#PatternElementPatternUnitsAttribute) attribute
[\[SVG2\]](#biblio-svg2 "Scalable Vector Graphics (SVG) 2").

For the SVG
[linearGradient](https://w3c.github.io/svgwg/svg2-draft/pservers.html#elementdef-linearGradient) and
[radialGradient](https://w3c.github.io/svgwg/svg2-draft/pservers.html#elementdef-radialGradient) elements, the reference box gets defined by the
[`gradientUnits`](https://www.w3.org/TR/SVG/pservers.html#LinearGradientElementGradientUnitsAttribute) attribute
[\[SVG2\]](#biblio-svg2 "Scalable Vector Graphics (SVG) 2").

For the SVG
[clipPath](https://drafts.csswg.org/css-masking-1/#elementdef-clippath) element, the reference box gets defined by the
[`clipPathUnits`](https://drafts.csswg.org/css-masking-1/#element-attrdef-clippath-clippathunits) attribute
[\[CSS-MASKING\]](#biblio-css-masking "CSS Masking Module Level 1").

A reference box adds an additional offset to the origin specified by the
[transform-origin](#propdef-transform-origin) property.

For SVG elements without associated CSS layout box, the [used
value](https://drafts.csswg.org/css-cascade-5/#used-value) for
[content-box](#valdef-transform-box-content-box) is
[fill-box](#valdef-transform-box-fill-box) and for
[border-box](#valdef-transform-box-border-box) is
[stroke-box](#valdef-transform-box-stroke-box).

For elements with associated CSS layout box, the [used
value](https://drafts.csswg.org/css-cascade-5/#used-value) for
[fill-box](#valdef-transform-box-fill-box) is
[content-box](#valdef-transform-box-content-box) and for
[stroke-box](#valdef-transform-box-stroke-box) and
[view-box](#valdef-transform-box-view-box) is
[border-box](#valdef-transform-box-border-box).

## [6. ][The SVG [transform](https://www.w3.org/TR/SVG11/coords.html#TransformAttribute) Attribute]
### 6.1. SVG presentation attributes

The
[transform-origin](#propdef-transform-origin) CSS property is also a
[presentation
attribute](https://w3c.github.io/svgwg/svg2-draft/styling.html#TermPresentationAttribute) and extends the list of existing [presentation
attributes]
[\[SVG2\]](#biblio-svg2 "Scalable Vector Graphics (SVG) 2").

SVG 2 defines the
[transform](https://www.w3.org/TR/SVG11/coords.html#TransformAttribute),
[`patternTransform`](https://www.w3.org/TR/SVG11/pservers.html#PatternElementPatternTransformAttribute),
[`gradientTransform`](https://www.w3.org/TR/SVG11/pservers.html#LinearGradientElementGradientTransformAttribute) attributes as [presentation
attributes](https://w3c.github.io/svgwg/svg2-draft/styling.html#TermPresentationAttribute), represented by the CSS
[transform](#propdef-transform) property
[\[SVG2\]](#biblio-svg2 "Scalable Vector Graphics (SVG) 2").

The participation in the CSS cascade is determined by the specificity of
[presentation
attributes](https://w3c.github.io/svgwg/svg2-draft/styling.html#TermPresentationAttribute) in the SVG specification. According to SVG, user agents
conceptually insert a [new author style
sheet](https://www.w3.org/TR/SVG/styling.html#PresentationAttributes)
for presentation attributes, which is the first in the author style
sheet collection
[\[SVG2\]](#biblio-svg2 "Scalable Vector Graphics (SVG) 2").

This example shows the combination of
the [transform](#propdef-transform) style property and the
[transform](https://www.w3.org/TR/SVG11/coords.html#TransformAttribute) attribute.

``` highlight
<svg xmlns="http://www.w3.org/2000/svg">
 <style>
 .container {
 transform: translate(100px, 100px);
 }
 </style>

 <g class="container" transform="translate(200 200)">
 <rect width="100" height="100" fill="blue" />
 </g>
</svg>
```

![Translated SVG container
element.](examples/svg-translate1.svg){height="240" width="470"}

Because of the participation to the CSS cascade, the
[transform](#propdef-transform) style property overrides the
[transform](https://www.w3.org/TR/SVG11/coords.html#TransformAttribute) attribute. Therefore the container gets
translated by [100px] in both the horizontal and the vertical
directions, instead of [200px].

### [6.2. ][Syntax of the SVG [transform](https://www.w3.org/TR/SVG11/coords.html#TransformAttribute) attribute]
For backwards compatibility reasons, the syntax of the
[transform](https://www.w3.org/TR/SVG11/coords.html#TransformAttribute),
[`patternTransform`](https://www.w3.org/TR/SVG11/pservers.html#PatternElementPatternTransformAttribute),
[`gradientTransform`](https://www.w3.org/TR/SVG11/pservers.html#LinearGradientElementGradientTransformAttribute) attributes differ from the syntax of the
[transform](#propdef-transform) CSS property. For the attributes, there
is no support for additional
[\<transform-function\>](#typedef-transform-function)s defined for the CSS
[transform] property.
Specifically,
[\<translateX()\>](#funcdef-transform-translatex),
[\<translateY()\>](#funcdef-transform-translatey),
[\<scaleX()\>](#funcdef-transform-scalex),
[\<scaleY()\>](#funcdef-transform-scaley) and
[\<skew()\>](#funcdef-transform-skew) are not supported by the
[transform],
[`patternTransform`](https://www.w3.org/TR/SVG11/pservers.html#PatternElementPatternTransformAttribute),
[`gradientTransform`](https://www.w3.org/TR/SVG11/pservers.html#LinearGradientElementGradientTransformAttribute) attributes.

The following list uses the Backus-Naur Form (BNF) to define values for
the
[transform](https://www.w3.org/TR/SVG11/coords.html#TransformAttribute),
[patternTransform](https://www.w3.org/TR/SVG11/pservers.html#PatternElementPatternTransformAttribute) and
[gradientTransform](https://www.w3.org/TR/SVG11/pservers.html#LinearGradientElementGradientTransformAttribute) attributes followed by an informative rail
road diagram. The following notation is used:

- \*: 0 or more

- +: 1 or more

- ?: 0 or 1

- (): grouping

- \|: separates alternatives

- double quotes surround literals. Literals consists of
 [letter](https://drafts.csswg.org/css-syntax-3/#letter)s
 [\[CSS-SYNTAX-3\]](#biblio-css-syntax-3 "CSS Syntax Module Level 3"),
 left parenthesis and right parenthesis.

- [\<number-token\>](https://drafts.csswg.org/css-syntax-3/#typedef-number-token) defined by the CSS Syntax module
 [\[CSS-SYNTAX-3\]](#biblio-css-syntax-3 "CSS Syntax Module Level 3").

 The syntax reflects implemented behavior in user agents
and differs from the syntax defined by SVG 1.1.

left parenthesis (
: U+0028 LEFT PARENTHESIS

right parenthesis )
: U+0029 RIGHT PARENTHESIS

comma
: U+002C COMMA.

wsp
: Either a U+000A LINE FEED, U+000D CARRIAGE RETURN, U+0009 CHARACTER
 TABULATION, or U+0020 SPACE.
: ::: railroad
 !(data:image/svg+xml;base64,PHN2ZyBjbGFzcz0icmFpbHJvYWQtZGlhZ3JhbSIgaGVpZ2h0PSIxNTIiIHZpZXdib3g9IjAgMCAxODIuNSAxNTIiIHdpZHRoPSIxODIuNSI+CiAgICAgICA8ZyB0cmFuc2Zvcm09InRyYW5zbGF0ZSguNSAuNSkiPgogICAgICAgIDxnPgogICAgICAgICA8cGF0aCBkPSJNMjAgMjF2MjBtMTAgLTIwdjIwbS0xMCAtMTBoMjAiIC8+CiAgICAgICAgPC9nPgogICAgICAgIDxnPgogICAgICAgICA8cGF0aCBkPSJNNDAgMzFoMC4wIiAvPgogICAgICAgICA8cGF0aCBkPSJNMTQyLjUgMzFoMC4wIiAvPgogICAgICAgICA8cGF0aCBkPSJNNDAuMCAzMWgyMCIgLz4KICAgICAgICAgPGcgY2xhc3M9InRlcm1pbmFsIj4KICAgICAgICAgIDxwYXRoIGQ9Ik02MC4wIDMxaDAuMCIgLz4KICAgICAgICAgIDxwYXRoIGQ9Ik0xMjIuNSAzMWgwLjAiIC8+CiAgICAgICAgICA8cmVjdCBoZWlnaHQ9IjIyIiByeD0iMTAiIHJ5PSIxMCIgd2lkdGg9IjYyLjUiIHg9IjYwIiB5PSIyMCIgLz4KICAgICAgICAgIDx0ZXh0IHg9IjkxLjI1IiB5PSIzNSI+c3BhY2U8L3RleHQ+CiAgICAgICAgIDwvZz4KICAgICAgICAgPHBhdGggZD0iTTEyMi41IDMxaDIwIiAvPgogICAgICAgICA8cGF0aCBkPSJNNDAuMCAzMWExMCAxMCAwIDAgMSAxMCAxMHYxMGExMCAxMCAwIDAgMCAxMCAxMCIgLz4KICAgICAgICAgPGcgY2xhc3M9InRlcm1pbmFsIj4KICAgICAgICAgIDxwYXRoIGQ9Ik02MC4wIDYxaDEyLjc1IiAvPgogICAgICAgICAgPHBhdGggZD0iTTEwOS43NSA2MWgxMi43NSIgLz4KICAgICAgICAgIDxyZWN0IGhlaWdodD0iMjIiIHJ4PSIxMCIgcnk9IjEwIiB3aWR0aD0iMzciIHg9IjcyLjc1IiB5PSI1MCIgLz4KICAgICAgICAgIDx0ZXh0IHg9IjkxLjI1IiB5PSI2NSI+XHQ8L3RleHQ+CiAgICAgICAgIDwvZz4KICAgICAgICAgPHBhdGggZD0iTTEyMi41IDYxYTEwIDEwIDAgMCAwIDEwIC0xMHYtMTBhMTAgMTAgMCAwIDEgMTAgLTEwIiAvPgogICAgICAgICA8cGF0aCBkPSJNNDAuMCAzMWExMCAxMCAwIDAgMSAxMCAxMHY0MGExMCAxMCAwIDAgMCAxMCAxMCIgLz4KICAgICAgICAgPGcgY2xhc3M9InRlcm1pbmFsIj4KICAgICAgICAgIDxwYXRoIGQ9Ik02MC4wIDkxaDEyLjc1IiAvPgogICAgICAgICAgPHBhdGggZD0iTTEwOS43NSA5MWgxMi43NSIgLz4KICAgICAgICAgIDxyZWN0IGhlaWdodD0iMjIiIHJ4PSIxMCIgcnk9IjEwIiB3aWR0aD0iMzciIHg9IjcyLjc1IiB5PSI4MCIgLz4KICAgICAgICAgIDx0ZXh0IHg9IjkxLjI1IiB5PSI5NSI+XHI8L3RleHQ+CiAgICAgICAgIDwvZz4KICAgICAgICAgPHBhdGggZD0iTTEyMi41IDkxYTEwIDEwIDAgMCAwIDEwIC0xMHYtNDBhMTAgMTAgMCAwIDEgMTAgLTEwIiAvPgogICAgICAgICA8cGF0aCBkPSJNNDAuMCAzMWExMCAxMCAwIDAgMSAxMCAxMHY3MGExMCAxMCAwIDAgMCAxMCAxMCIgLz4KICAgICAgICAgPGcgY2xhc3M9InRlcm1pbmFsIj4KICAgICAgICAgIDxwYXRoIGQ9Ik02MC4wIDEyMWgxMi43NSIgLz4KICAgICAgICAgIDxwYXRoIGQ9Ik0xMDkuNzUgMTIxaDEyLjc1IiAvPgogICAgICAgICAgPHJlY3QgaGVpZ2h0PSIyMiIgcng9IjEwIiByeT0iMTAiIHdpZHRoPSIzNyIgeD0iNzIuNzUiIHk9IjExMCIgLz4KICAgICAgICAgIDx0ZXh0IHg9IjkxLjI1IiB5PSIxMjUiPlxmPC90ZXh0PgogICAgICAgICA8L2c+CiAgICAgICAgIDxwYXRoIGQ9Ik0xMjIuNSAxMjFhMTAgMTAgMCAwIDAgMTAgLTEwdi03MGExMCAxMCAwIDAgMSAxMCAtMTAiIC8+CiAgICAgICAgPC9nPgogICAgICAgIDxwYXRoIGQ9Ik0gMTQyLjUgMzEgaCAyMCBtIC0xMCAtMTAgdiAyMCBtIDEwIC0yMCB2IDIwIiAvPgogICAgICAgPC9nPgogICAgICA8L3N2Zz4=)
 :::

comma-wsp

: (wsp+ comma? wsp*) | (comma wsp*)

: ::: railroad
 !(data:image/svg+xml;base64,PHN2ZyBjbGFzcz0icmFpbHJvYWQtZGlhZ3JhbSIgaGVpZ2h0PSIxMjgiIHZpZXdib3g9IjAgMCA0MDMuNSAxMjgiIHdpZHRoPSI0MDMuNSI+CiAgICAgICA8ZyB0cmFuc2Zvcm09InRyYW5zbGF0ZSguNSAuNSkiPgogICAgICAgIDxnPgogICAgICAgICA8cGF0aCBkPSJNMjAgMzB2MjBtMTAgLTIwdjIwbS0xMCAtMTBoMjAiIC8+CiAgICAgICAgPC9nPgogICAgICAgIDxnPgogICAgICAgICA8cGF0aCBkPSJNNDAgNDBoMC4wIiAvPgogICAgICAgICA8cGF0aCBkPSJNMzYzLjUgNDBoMC4wIiAvPgogICAgICAgICA8cGF0aCBkPSJNNDAuMCA0MGgyMCIgLz4KICAgICAgICAgPGc+CiAgICAgICAgICA8cGF0aCBkPSJNNjAuMCA0MGgwLjAiIC8+CiAgICAgICAgICA8cGF0aCBkPSJNMzQzLjUgNDBoMC4wIiAvPgogICAgICAgICAgPGc+CiAgICAgICAgICAgPHBhdGggZD0iTTYwLjAgNDBoMC4wIiAvPgogICAgICAgICAgIDxwYXRoIGQ9Ik0xMjUuNSA0MGgwLjAiIC8+CiAgICAgICAgICAgPHBhdGggZD0iTTYwLjAgNDBoMTAiIC8+CiAgICAgICAgICAgPGcgY2xhc3M9Im5vbi10ZXJtaW5hbCI+CiAgICAgICAgICAgIDxwYXRoIGQ9Ik03MC4wIDQwaDAuMCIgLz4KICAgICAgICAgICAgPHBhdGggZD0iTTExNS41IDQwaDAuMCIgLz4KICAgICAgICAgICAgPHJlY3QgaGVpZ2h0PSIyMiIgd2lkdGg9IjQ1LjUiIHg9IjcwIiB5PSIyOSIgLz4KICAgICAgICAgICAgPHRleHQgeD0iOTIuNzUiIHk9IjQ0Ij53c3A8L3RleHQ+CiAgICAgICAgICAgPC9nPgogICAgICAgICAgIDxwYXRoIGQ9Ik0xMTUuNSA0MGgxMCIgLz4KICAgICAgICAgICA8cGF0aCBkPSJNNzAuMCA0MGExMCAxMCAwIDAgMCAtMTAgMTB2MGExMCAxMCAwIDAgMCAxMCAxMCIgLz4KICAgICAgICAgICA8Zz4KICAgICAgICAgICAgPHBhdGggZD0iTTcwLjAgNjBoNDUuNSIgLz4KICAgICAgICAgICA8L2c+CiAgICAgICAgICAgPHBhdGggZD0iTTExNS41IDYwYTEwIDEwIDAgMCAwIDEwIC0xMHYwYTEwIDEwIDAgMCAwIC0xMCAtMTAiIC8+CiAgICAgICAgICA8L2c+CiAgICAgICAgICA8cGF0aCBkPSJNMTI1LjUgNDBoMTAiIC8+CiAgICAgICAgICA8Zz4KICAgICAgICAgICA8cGF0aCBkPSJNMTM1LjUgNDBoMC4wIiAvPgogICAgICAgICAgIDxwYXRoIGQ9Ik0yMzguMCA0MGgwLjAiIC8+CiAgICAgICAgICAgPHBhdGggZD0iTTEzNS41IDQwYTEwIDEwIDAgMCAwIDEwIC0xMHYwYTEwIDEwIDAgMCAxIDEwIC0xMCIgLz4KICAgICAgICAgICA8Zz4KICAgICAgICAgICAgPHBhdGggZD0iTTE1NS41IDIwaDYyLjUiIC8+CiAgICAgICAgICAgPC9nPgogICAgICAgICAgIDxwYXRoIGQ9Ik0yMTguMCAyMGExMCAxMCAwIDAgMSAxMCAxMHYwYTEwIDEwIDAgMCAwIDEwIDEwIiAvPgogICAgICAgICAgIDxwYXRoIGQ9Ik0xMzUuNSA0MGgyMCIgLz4KICAgICAgICAgICA8ZyBjbGFzcz0ibm9uLXRlcm1pbmFsIj4KICAgICAgICAgICAgPHBhdGggZD0iTTE1NS41IDQwaDAuMCIgLz4KICAgICAgICAgICAgPHBhdGggZD0iTTIxOC4wIDQwaDAuMCIgLz4KICAgICAgICAgICAgPHJlY3QgaGVpZ2h0PSIyMiIgd2lkdGg9IjYyLjUiIHg9IjE1NS41IiB5PSIyOSIgLz4KICAgICAgICAgICAgPHRleHQgeD0iMTg2Ljc1IiB5PSI0NCI+Y29tbWE8L3RleHQ+CiAgICAgICAgICAgPC9nPgogICAgICAgICAgIDxwYXRoIGQ9Ik0yMTguMCA0MGgyMCIgLz4KICAgICAgICAgIDwvZz4KICAgICAgICAgIDxnPgogICAgICAgICAgIDxwYXRoIGQ9Ik0yMzguMCA0MGgwLjAiIC8+CiAgICAgICAgICAgPHBhdGggZD0iTTM0My41IDQwaDAuMCIgLz4KICAgICAgICAgICA8cGF0aCBkPSJNMjM4LjAgNDBhMTAgMTAgMCAwIDAgMTAgLTEwdjBhMTAgMTAgMCAwIDEgMTAgLTEwIiAvPgogICAgICAgICAgIDxnPgogICAgICAgICAgICA8cGF0aCBkPSJNMjU4LjAgMjBoNjUuNSIgLz4KICAgICAgICAgICA8L2c+CiAgICAgICAgICAgPHBhdGggZD0iTTMyMy41IDIwYTEwIDEwIDAgMCAxIDEwIDEwdjBhMTAgMTAgMCAwIDAgMTAgMTAiIC8+CiAgICAgICAgICAgPHBhdGggZD0iTTIzOC4wIDQwaDIwIiAvPgogICAgICAgICAgIDxnPgogICAgICAgICAgICA8cGF0aCBkPSJNMjU4LjAgNDBoMC4wIiAvPgogICAgICAgICAgICA8cGF0aCBkPSJNMzIzLjUgNDBoMC4wIiAvPgogICAgICAgICAgICA8cGF0aCBkPSJNMjU4LjAgNDBoMTAiIC8+CiAgICAgICAgICAgIDxnIGNsYXNzPSJub24tdGVybWluYWwiPgogICAgICAgICAgICAgPHBhdGggZD0iTTI2OC4wIDQwaDAuMCIgLz4KICAgICAgICAgICAgIDxwYXRoIGQ9Ik0zMTMuNSA0MGgwLjAiIC8+CiAgICAgICAgICAgICA8cmVjdCBoZWlnaHQ9IjIyIiB3aWR0aD0iNDUuNSIgeD0iMjY4IiB5PSIyOSIgLz4KICAgICAgICAgICAgIDx0ZXh0IHg9IjI5MC43NSIgeT0iNDQiPndzcDwvdGV4dD4KICAgICAgICAgICAgPC9nPgogICAgICAgICAgICA8cGF0aCBkPSJNMzEzLjUgNDBoMTAiIC8+CiAgICAgICAgICAgIDxwYXRoIGQ9Ik0yNjguMCA0MGExMCAxMCAwIDAgMCAtMTAgMTB2MGExMCAxMCAwIDAgMCAxMCAxMCIgLz4KICAgICAgICAgICAgPGc+CiAgICAgICAgICAgICA8cGF0aCBkPSJNMjY4LjAgNjBoNDUuNSIgLz4KICAgICAgICAgICAgPC9nPgogICAgICAgICAgICA8cGF0aCBkPSJNMzEzLjUgNjBhMTAgMTAgMCAwIDAgMTAgLTEwdjBhMTAgMTAgMCAwIDAgLTEwIC0xMCIgLz4KICAgICAgICAgICA8L2c+CiAgICAgICAgICAgPHBhdGggZD0iTTMyMy41IDQwaDIwIiAvPgogICAgICAgICAgPC9nPgogICAgICAgICA8L2c+CiAgICAgICAgIDxwYXRoIGQ9Ik0zNDMuNSA0MGgyMCIgLz4KICAgICAgICAgPHBhdGggZD0iTTQwLjAgNDBhMTAgMTAgMCAwIDEgMTAgMTB2MjhhMTAgMTAgMCAwIDAgMTAgMTAiIC8+CiAgICAgICAgIDxnPgogICAgICAgICAgPHBhdGggZD0iTTYwLjAgODhoNTIuNzUiIC8+CiAgICAgICAgICA8cGF0aCBkPSJNMjkwLjc1IDg4aDUyLjc1IiAvPgogICAgICAgICAgPGcgY2xhc3M9Im5vbi10ZXJtaW5hbCI+CiAgICAgICAgICAgPHBhdGggZD0iTTExMi43NSA4OGgwLjAiIC8+CiAgICAgICAgICAgPHBhdGggZD0iTTE3NS4yNSA4OGgwLjAiIC8+CiAgICAgICAgICAgPHJlY3QgaGVpZ2h0PSIyMiIgd2lkdGg9IjYyLjUiIHg9IjExMi43NSIgeT0iNzciIC8+CiAgICAgICAgICAgPHRleHQgeD0iMTQ0IiB5PSI5MiI+Y29tbWE8L3RleHQ+CiAgICAgICAgICA8L2c+CiAgICAgICAgICA8cGF0aCBkPSJNMTc1LjI1IDg4aDEwIiAvPgogICAgICAgICAgPGc+CiAgICAgICAgICAgPHBhdGggZD0iTTE4NS4yNSA4OGgwLjAiIC8+CiAgICAgICAgICAgPHBhdGggZD0iTTI5MC43NSA4OGgwLjAiIC8+CiAgICAgICAgICAgPHBhdGggZD0iTTE4NS4yNSA4OGExMCAxMCAwIDAgMCAxMCAtMTB2MGExMCAxMCAwIDAgMSAxMCAtMTAiIC8+CiAgICAgICAgICAgPGc+CiAgICAgICAgICAgIDxwYXRoIGQ9Ik0yMDUuMjUgNjhoNjUuNSIgLz4KICAgICAgICAgICA8L2c+CiAgICAgICAgICAgPHBhdGggZD0iTTI3MC43NSA2OGExMCAxMCAwIDAgMSAxMCAxMHYwYTEwIDEwIDAgMCAwIDEwIDEwIiAvPgogICAgICAgICAgIDxwYXRoIGQ9Ik0xODUuMjUgODhoMjAiIC8+CiAgICAgICAgICAgPGc+CiAgICAgICAgICAgIDxwYXRoIGQ9Ik0yMDUuMjUgODhoMC4wIiAvPgogICAgICAgICAgICA8cGF0aCBkPSJNMjcwLjc1IDg4aDAuMCIgLz4KICAgICAgICAgICAgPHBhdGggZD0iTTIwNS4yNSA4OGgxMCIgLz4KICAgICAgICAgICAgPGcgY2xhc3M9Im5vbi10ZXJtaW5hbCI+CiAgICAgICAgICAgICA8cGF0aCBkPSJNMjE1LjI1IDg4aDAuMCIgLz4KICAgICAgICAgICAgIDxwYXRoIGQ9Ik0yNjAuNzUgODhoMC4wIiAvPgogICAgICAgICAgICAgPHJlY3QgaGVpZ2h0PSIyMiIgd2lkdGg9IjQ1LjUiIHg9IjIxNS4yNSIgeT0iNzciIC8+CiAgICAgICAgICAgICA8dGV4dCB4PSIyMzgiIHk9IjkyIj53c3A8L3RleHQ+CiAgICAgICAgICAgIDwvZz4KICAgICAgICAgICAgPHBhdGggZD0iTTI2MC43NSA4OGgxMCIgLz4KICAgICAgICAgICAgPHBhdGggZD0iTTIxNS4yNSA4OGExMCAxMCAwIDAgMCAtMTAgMTB2MGExMCAxMCAwIDAgMCAxMCAxMCIgLz4KICAgICAgICAgICAgPGc+CiAgICAgICAgICAgICA8cGF0aCBkPSJNMjE1LjI1IDEwOGg0NS41IiAvPgogICAgICAgICAgICA8L2c+CiAgICAgICAgICAgIDxwYXRoIGQ9Ik0yNjAuNzUgMTA4YTEwIDEwIDAgMCAwIDEwIC0xMHYwYTEwIDEwIDAgMCAwIC0xMCAtMTAiIC8+CiAgICAgICAgICAgPC9nPgogICAgICAgICAgIDxwYXRoIGQ9Ik0yNzAuNzUgODhoMjAiIC8+CiAgICAgICAgICA8L2c+CiAgICAgICAgIDwvZz4KICAgICAgICAgPHBhdGggZD0iTTM0My41IDg4YTEwIDEwIDAgMCAwIDEwIC0xMHYtMjhhMTAgMTAgMCAwIDEgMTAgLTEwIiAvPgogICAgICAgIDwvZz4KICAgICAgICA8cGF0aCBkPSJNIDM2My41IDQwIGggMjAgbSAtMTAgLTEwIHYgMjAgbSAxMCAtMjAgdiAyMCIgLz4KICAgICAgIDwvZz4KICAgICAgPC9zdmc+)
 :::

translate

: "translate" wsp* "(" wsp* number ( comma-wsp? number )? wsp* ")"

: ::: railroad
 !(data:image/svg+xml;base64,PHN2ZyBjbGFzcz0icmFpbHJvYWQtZGlhZ3JhbSIgaGVpZ2h0PSIxOTIiIHZpZXdib3g9IjAgMCA2MTQuNSAxOTIiIHdpZHRoPSI2MTQuNSI+CiAgICAgICA8ZyB0cmFuc2Zvcm09InRyYW5zbGF0ZSguNSAuNSkiPgogICAgICAgIDxnPgogICAgICAgICA8cGF0aCBkPSJNMjAgMzB2MjBtMTAgLTIwdjIwbS0xMCAtMTBoMjAiIC8+CiAgICAgICAgPC9nPgogICAgICAgIDxwYXRoIGQ9Ik00MCA0MGgxMCIgLz4KICAgICAgICA8Zz4KICAgICAgICAgPHBhdGggZD0iTTUwIDQwaDAuMCIgLz4KICAgICAgICAgPHBhdGggZD0iTTUwLjAgNDBoMTAiIC8+CiAgICAgICAgIDxnPgogICAgICAgICAgPHBhdGggZD0iTTYwLjAgNDBoNjQuMjUiIC8+CiAgICAgICAgICA8cGF0aCBkPSJNNDkwLjI1IDQwaDY0LjI1IiAvPgogICAgICAgICAgPGcgY2xhc3M9InRlcm1pbmFsIj4KICAgICAgICAgICA8cGF0aCBkPSJNMTI0LjI1IDQwaDAuMCIgLz4KICAgICAgICAgICA8cGF0aCBkPSJNMjIwLjc1IDQwaDAuMCIgLz4KICAgICAgICAgICA8cmVjdCBoZWlnaHQ9IjIyIiByeD0iMTAiIHJ5PSIxMCIgd2lkdGg9Ijk2LjUiIHg9IjEyNC4yNSIgeT0iMjkiIC8+CiAgICAgICAgICAgPHRleHQgeD0iMTcyLjUiIHk9IjQ0Ij50cmFuc2xhdGU8L3RleHQ+CiAgICAgICAgICA8L2c+CiAgICAgICAgICA8cGF0aCBkPSJNMjIwLjc1IDQwaDEwIiAvPgogICAgICAgICAgPGc+CiAgICAgICAgICAgPHBhdGggZD0iTTIzMC43NSA0MGgwLjAiIC8+CiAgICAgICAgICAgPHBhdGggZD0iTTMzNi4yNSA0MGgwLjAiIC8+CiAgICAgICAgICAgPHBhdGggZD0iTTIzMC43NSA0MGExMCAxMCAwIDAgMCAxMCAtMTB2MGExMCAxMCAwIDAgMSAxMCAtMTAiIC8+CiAgICAgICAgICAgPGc+CiAgICAgICAgICAgIDxwYXRoIGQ9Ik0yNTAuNzUgMjBoNjUuNSIgLz4KICAgICAgICAgICA8L2c+CiAgICAgICAgICAgPHBhdGggZD0iTTMxNi4yNSAyMGExMCAxMCAwIDAgMSAxMCAxMHYwYTEwIDEwIDAgMCAwIDEwIDEwIiAvPgogICAgICAgICAgIDxwYXRoIGQ9Ik0yMzAuNzUgNDBoMjAiIC8+CiAgICAgICAgICAgPGc+CiAgICAgICAgICAgIDxwYXRoIGQ9Ik0yNTAuNzUgNDBoMC4wIiAvPgogICAgICAgICAgICA8cGF0aCBkPSJNMzE2LjI1IDQwaDAuMCIgLz4KICAgICAgICAgICAgPHBhdGggZD0iTTI1MC43NSA0MGgxMCIgLz4KICAgICAgICAgICAgPGcgY2xhc3M9Im5vbi10ZXJtaW5hbCI+CiAgICAgICAgICAgICA8cGF0aCBkPSJNMjYwLjc1IDQwaDAuMCIgLz4KICAgICAgICAgICAgIDxwYXRoIGQ9Ik0zMDYuMjUgNDBoMC4wIiAvPgogICAgICAgICAgICAgPHJlY3QgaGVpZ2h0PSIyMiIgd2lkdGg9IjQ1LjUiIHg9IjI2MC43NSIgeT0iMjkiIC8+CiAgICAgICAgICAgICA8dGV4dCB4PSIyODMuNSIgeT0iNDQiPndzcDwvdGV4dD4KICAgICAgICAgICAgPC9nPgogICAgICAgICAgICA8cGF0aCBkPSJNMzA2LjI1IDQwaDEwIiAvPgogICAgICAgICAgICA8cGF0aCBkPSJNMjYwLjc1IDQwYTEwIDEwIDAgMCAwIC0xMCAxMHYwYTEwIDEwIDAgMCAwIDEwIDEwIiAvPgogICAgICAgICAgICA8Zz4KICAgICAgICAgICAgIDxwYXRoIGQ9Ik0yNjAuNzUgNjBoNDUuNSIgLz4KICAgICAgICAgICAgPC9nPgogICAgICAgICAgICA8cGF0aCBkPSJNMzA2LjI1IDYwYTEwIDEwIDAgMCAwIDEwIC0xMHYwYTEwIDEwIDAgMCAwIC0xMCAtMTAiIC8+CiAgICAgICAgICAgPC9nPgogICAgICAgICAgIDxwYXRoIGQ9Ik0zMTYuMjUgNDBoMjAiIC8+CiAgICAgICAgICA8L2c+CiAgICAgICAgICA8cGF0aCBkPSJNMzM2LjI1IDQwaDEwIiAvPgogICAgICAgICAgPGcgY2xhc3M9InRlcm1pbmFsIj4KICAgICAgICAgICA8cGF0aCBkPSJNMzQ2LjI1IDQwaDAuMCIgLz4KICAgICAgICAgICA8cGF0aCBkPSJNMzc0Ljc1IDQwaDAuMCIgLz4KICAgICAgICAgICA8cmVjdCBoZWlnaHQ9IjIyIiByeD0iMTAiIHJ5PSIxMCIgd2lkdGg9IjI4LjUiIHg9IjM0Ni4yNSIgeT0iMjkiIC8+CiAgICAgICAgICAgPHRleHQgeD0iMzYwLjUiIHk9IjQ0Ij4oPC90ZXh0PgogICAgICAgICAgPC9nPgogICAgICAgICAgPHBhdGggZD0iTTM3NC43NSA0MGgxMCIgLz4KICAgICAgICAgIDxnPgogICAgICAgICAgIDxwYXRoIGQ9Ik0zODQuNzUgNDBoMC4wIiAvPgogICAgICAgICAgIDxwYXRoIGQ9Ik00OTAuMjUgNDBoMC4wIiAvPgogICAgICAgICAgIDxwYXRoIGQ9Ik0zODQuNzUgNDBhMTAgMTAgMCAwIDAgMTAgLTEwdjBhMTAgMTAgMCAwIDEgMTAgLTEwIiAvPgogICAgICAgICAgIDxnPgogICAgICAgICAgICA8cGF0aCBkPSJNNDA0Ljc1IDIwaDY1LjUiIC8+CiAgICAgICAgICAgPC9nPgogICAgICAgICAgIDxwYXRoIGQ9Ik00NzAuMjUgMjBhMTAgMTAgMCAwIDEgMTAgMTB2MGExMCAxMCAwIDAgMCAxMCAxMCIgLz4KICAgICAgICAgICA8cGF0aCBkPSJNMzg0Ljc1IDQwaDIwIiAvPgogICAgICAgICAgIDxnPgogICAgICAgICAgICA8cGF0aCBkPSJNNDA0Ljc1IDQwaDAuMCIgLz4KICAgICAgICAgICAgPHBhdGggZD0iTTQ3MC4yNSA0MGgwLjAiIC8+CiAgICAgICAgICAgIDxwYXRoIGQ9Ik00MDQuNzUgNDBoMTAiIC8+CiAgICAgICAgICAgIDxnIGNsYXNzPSJub24tdGVybWluYWwiPgogICAgICAgICAgICAgPHBhdGggZD0iTTQxNC43NSA0MGgwLjAiIC8+CiAgICAgICAgICAgICA8cGF0aCBkPSJNNDYwLjI1IDQwaDAuMCIgLz4KICAgICAgICAgICAgIDxyZWN0IGhlaWdodD0iMjIiIHdpZHRoPSI0NS41IiB4PSI0MTQuNzUiIHk9IjI5IiAvPgogICAgICAgICAgICAgPHRleHQgeD0iNDM3LjUiIHk9IjQ0Ij53c3A8L3RleHQ+CiAgICAgICAgICAgIDwvZz4KICAgICAgICAgICAgPHBhdGggZD0iTTQ2MC4yNSA0MGgxMCIgLz4KICAgICAgICAgICAgPHBhdGggZD0iTTQxNC43NSA0MGExMCAxMCAwIDAgMCAtMTAgMTB2MGExMCAxMCAwIDAgMCAxMCAxMCIgLz4KICAgICAgICAgICAgPGc+CiAgICAgICAgICAgICA8cGF0aCBkPSJNNDE0Ljc1IDYwaDQ1LjUiIC8+CiAgICAgICAgICAgIDwvZz4KICAgICAgICAgICAgPHBhdGggZD0iTTQ2MC4yNSA2MGExMCAxMCAwIDAgMCAxMCAtMTB2MGExMCAxMCAwIDAgMCAtMTAgLTEwIiAvPgogICAgICAgICAgIDwvZz4KICAgICAgICAgICA8cGF0aCBkPSJNNDcwLjI1IDQwaDIwIiAvPgogICAgICAgICAgPC9nPgogICAgICAgICA8L2c+CiAgICAgICAgIDxwYXRoIGQ9Ik01NTQuNSA0MGExMCAxMCAwIDAgMSAxMCAxMHY4YTEwIDEwIDAgMCAxIC0xMCAxMGgtNDk0LjVhMTAgMTAgMCAwIDAgLTEwIDEwdjE2YTEwIDEwIDAgMCAwIDEwIDEwIiAvPgogICAgICAgICA8Zz4KICAgICAgICAgIDxwYXRoIGQ9Ik02MC4wIDEwNGgxMC4wIiAvPgogICAgICAgICAgPHBhdGggZD0iTTU0NC41IDEwNGgxMC4wIiAvPgogICAgICAgICAgPGcgY2xhc3M9Im5vbi10ZXJtaW5hbCI+CiAgICAgICAgICAgPHBhdGggZD0iTTcwLjAgMTA0aDAuMCIgLz4KICAgICAgICAgICA8cGF0aCBkPSJNMjA5LjAgMTA0aDAuMCIgLz4KICAgICAgICAgICA8cmVjdCBoZWlnaHQ9IjIyIiB3aWR0aD0iMTM5IiB4PSI3MCIgeT0iOTMiIC8+CiAgICAgICAgICAgPHRleHQgeD0iMTM5LjUiIHk9IjEwOCI+Jmx0O251bWJlci10b2tlbiZndDs8L3RleHQ+CiAgICAgICAgICA8L2c+CiAgICAgICAgICA8cGF0aCBkPSJNMjA5LjAgMTA0aDEwIiAvPgogICAgICAgICAgPGc+CiAgICAgICAgICAgPHBhdGggZD0iTTIxOS4wIDEwNGgwLjAiIC8+CiAgICAgICAgICAgPHBhdGggZD0iTTU0NC41IDEwNGgwLjAiIC8+CiAgICAgICAgICAgPHBhdGggZD0iTTIxOS4wIDEwNGExMCAxMCAwIDAgMCAxMCAtMTB2LThhMTAgMTAgMCAwIDEgMTAgLTEwIiAvPgogICAgICAgICAgIDxnPgogICAgICAgICAgICA8cGF0aCBkPSJNMjM5LjAgNzZoMjg1LjUiIC8+CiAgICAgICAgICAgPC9nPgogICAgICAgICAgIDxwYXRoIGQ9Ik01MjQuNSA3NmExMCAxMCAwIDAgMSAxMCAxMHY4YTEwIDEwIDAgMCAwIDEwIDEwIiAvPgogICAgICAgICAgIDxwYXRoIGQ9Ik0yMTkuMCAxMDRoMjAiIC8+CiAgICAgICAgICAgPGc+CiAgICAgICAgICAgIDxwYXRoIGQ9Ik0yMzkuMCAxMDRoMC4wIiAvPgogICAgICAgICAgICA8cGF0aCBkPSJNNTI0LjUgMTA0aDAuMCIgLz4KICAgICAgICAgICAgPGc+CiAgICAgICAgICAgICA8cGF0aCBkPSJNMjM5LjAgMTA0aDAuMCIgLz4KICAgICAgICAgICAgIDxwYXRoIGQ9Ik0zNzUuNSAxMDRoMC4wIiAvPgogICAgICAgICAgICAgPHBhdGggZD0iTTIzOS4wIDEwNGExMCAxMCAwIDAgMCAxMCAtMTB2MGExMCAxMCAwIDAgMSAxMCAtMTAiIC8+CiAgICAgICAgICAgICA8Zz4KICAgICAgICAgICAgICA8cGF0aCBkPSJNMjU5LjAgODRoOTYuNSIgLz4KICAgICAgICAgICAgIDwvZz4KICAgICAgICAgICAgIDxwYXRoIGQ9Ik0zNTUuNSA4NGExMCAxMCAwIDAgMSAxMCAxMHYwYTEwIDEwIDAgMCAwIDEwIDEwIiAvPgogICAgICAgICAgICAgPHBhdGggZD0iTTIzOS4wIDEwNGgyMCIgLz4KICAgICAgICAgICAgIDxnIGNsYXNzPSJub24tdGVybWluYWwiPgogICAgICAgICAgICAgIDxwYXRoIGQ9Ik0yNTkuMCAxMDRoMC4wIiAvPgogICAgICAgICAgICAgIDxwYXRoIGQ9Ik0zNTUuNSAxMDRoMC4wIiAvPgogICAgICAgICAgICAgIDxyZWN0IGhlaWdodD0iMjIiIHdpZHRoPSI5Ni41IiB4PSIyNTkiIHk9IjkzIiAvPgogICAgICAgICAgICAgIDx0ZXh0IHg9IjMwNy4yNSIgeT0iMTA4Ij5jb21tYS13c3A8L3RleHQ+CiAgICAgICAgICAgICA8L2c+CiAgICAgICAgICAgICA8cGF0aCBkPSJNMzU1LjUgMTA0aDIwIiAvPgogICAgICAgICAgICA8L2c+CiAgICAgICAgICAgIDxwYXRoIGQ9Ik0zNzUuNSAxMDRoMTAiIC8+CiAgICAgICAgICAgIDxnIGNsYXNzPSJub24tdGVybWluYWwiPgogICAgICAgICAgICAgPHBhdGggZD0iTTM4NS41IDEwNGgwLjAiIC8+CiAgICAgICAgICAgICA8cGF0aCBkPSJNNTI0LjUgMTA0aDAuMCIgLz4KICAgICAgICAgICAgIDxyZWN0IGhlaWdodD0iMjIiIHdpZHRoPSIxMzkiIHg9IjM4NS41IiB5PSI5MyIgLz4KICAgICAgICAgICAgIDx0ZXh0IHg9IjQ1NSIgeT0iMTA4Ij4mbHQ7bnVtYmVyLXRva2VuJmd0OzwvdGV4dD4KICAgICAgICAgICAgPC9nPgogICAgICAgICAgIDwvZz4KICAgICAgICAgICA8cGF0aCBkPSJNNTI0LjUgMTA0aDIwIiAvPgogICAgICAgICAgPC9nPgogICAgICAgICA8L2c+CiAgICAgICAgIDxwYXRoIGQ9Ik01NTQuNSAxMDRhMTAgMTAgMCAwIDEgMTAgMTB2MGExMCAxMCAwIDAgMSAtMTAgMTBoLTQ5NC41YTEwIDEwIDAgMCAwIC0xMCAxMHY4YTEwIDEwIDAgMCAwIDEwIDEwIiAvPgogICAgICAgICA8Zz4KICAgICAgICAgIDxwYXRoIGQ9Ik02MC4wIDE1MmgxNzUuMjUiIC8+CiAgICAgICAgICA8cGF0aCBkPSJNMzc5LjI1IDE1MmgxNzUuMjUiIC8+CiAgICAgICAgICA8Zz4KICAgICAgICAgICA8cGF0aCBkPSJNMjM1LjI1IDE1MmgwLjAiIC8+CiAgICAgICAgICAgPHBhdGggZD0iTTM0MC43NSAxNTJoMC4wIiAvPgogICAgICAgICAgIDxwYXRoIGQ9Ik0yMzUuMjUgMTUyYTEwIDEwIDAgMCAwIDEwIC0xMHYwYTEwIDEwIDAgMCAxIDEwIC0xMCIgLz4KICAgICAgICAgICA8Zz4KICAgICAgICAgICAgPHBhdGggZD0iTTI1NS4yNSAxMzJoNjUuNSIgLz4KICAgICAgICAgICA8L2c+CiAgICAgICAgICAgPHBhdGggZD0iTTMyMC43NSAxMzJhMTAgMTAgMCAwIDEgMTAgMTB2MGExMCAxMCAwIDAgMCAxMCAxMCIgLz4KICAgICAgICAgICA8cGF0aCBkPSJNMjM1LjI1IDE1MmgyMCIgLz4KICAgICAgICAgICA8Zz4KICAgICAgICAgICAgPHBhdGggZD0iTTI1NS4yNSAxNTJoMC4wIiAvPgogICAgICAgICAgICA8cGF0aCBkPSJNMzIwLjc1IDE1MmgwLjAiIC8+CiAgICAgICAgICAgIDxwYXRoIGQ9Ik0yNTUuMjUgMTUyaDEwIiAvPgogICAgICAgICAgICA8ZyBjbGFzcz0ibm9uLXRlcm1pbmFsIj4KICAgICAgICAgICAgIDxwYXRoIGQ9Ik0yNjUuMjUgMTUyaDAuMCIgLz4KICAgICAgICAgICAgIDxwYXRoIGQ9Ik0zMTAuNzUgMTUyaDAuMCIgLz4KICAgICAgICAgICAgIDxyZWN0IGhlaWdodD0iMjIiIHdpZHRoPSI0NS41IiB4PSIyNjUuMjUiIHk9IjE0MSIgLz4KICAgICAgICAgICAgIDx0ZXh0IHg9IjI4OCIgeT0iMTU2Ij53c3A8L3RleHQ+CiAgICAgICAgICAgIDwvZz4KICAgICAgICAgICAgPHBhdGggZD0iTTMxMC43NSAxNTJoMTAiIC8+CiAgICAgICAgICAgIDxwYXRoIGQ9Ik0yNjUuMjUgMTUyYTEwIDEwIDAgMCAwIC0xMCAxMHYwYTEwIDEwIDAgMCAwIDEwIDEwIiAvPgogICAgICAgICAgICA8Zz4KICAgICAgICAgICAgIDxwYXRoIGQ9Ik0yNjUuMjUgMTcyaDQ1LjUiIC8+CiAgICAgICAgICAgIDwvZz4KICAgICAgICAgICAgPHBhdGggZD0iTTMxMC43NSAxNzJhMTAgMTAgMCAwIDAgMTAgLTEwdjBhMTAgMTAgMCAwIDAgLTEwIC0xMCIgLz4KICAgICAgICAgICA8L2c+CiAgICAgICAgICAgPHBhdGggZD0iTTMyMC43NSAxNTJoMjAiIC8+CiAgICAgICAgICA8L2c+CiAgICAgICAgICA8cGF0aCBkPSJNMzQwLjc1IDE1MmgxMCIgLz4KICAgICAgICAgIDxnIGNsYXNzPSJ0ZXJtaW5hbCI+CiAgICAgICAgICAgPHBhdGggZD0iTTM1MC43NSAxNTJoMC4wIiAvPgogICAgICAgICAgIDxwYXRoIGQ9Ik0zNzkuMjUgMTUyaDAuMCIgLz4KICAgICAgICAgICA8cmVjdCBoZWlnaHQ9IjIyIiByeD0iMTAiIHJ5PSIxMCIgd2lkdGg9IjI4LjUiIHg9IjM1MC43NSIgeT0iMTQxIiAvPgogICAgICAgICAgIDx0ZXh0IHg9IjM2NSIgeT0iMTU2Ij4pPC90ZXh0PgogICAgICAgICAgPC9nPgogICAgICAgICA8L2c+CiAgICAgICAgIDxwYXRoIGQ9Ik01NTQuNSAxNTJoMTAiIC8+CiAgICAgICAgIDxwYXRoIGQ9Ik01NjQuNSAxNTJoMC4wIiAvPgogICAgICAgIDwvZz4KICAgICAgICA8cGF0aCBkPSJNNTY0LjUgMTUyaDEwIiAvPgogICAgICAgIDxwYXRoIGQ9Ik0gNTc0LjUgMTUyIGggMjAgbSAtMTAgLTEwIHYgMjAgbSAxMCAtMjAgdiAyMCIgLz4KICAgICAgIDwvZz4KICAgICAgPC9zdmc+)
 :::

scale

: "scale" wsp* "(" wsp* number ( comma-wsp? number )? wsp* ")"

: ::: railroad
 !(data:image/svg+xml;base64,PHN2ZyBjbGFzcz0icmFpbHJvYWQtZGlhZ3JhbSIgaGVpZ2h0PSIxOTIiIHZpZXdib3g9IjAgMCA2MTQuNSAxOTIiIHdpZHRoPSI2MTQuNSI+CiAgICAgICA8ZyB0cmFuc2Zvcm09InRyYW5zbGF0ZSguNSAuNSkiPgogICAgICAgIDxnPgogICAgICAgICA8cGF0aCBkPSJNMjAgMzB2MjBtMTAgLTIwdjIwbS0xMCAtMTBoMjAiIC8+CiAgICAgICAgPC9nPgogICAgICAgIDxwYXRoIGQ9Ik00MCA0MGgxMCIgLz4KICAgICAgICA8Zz4KICAgICAgICAgPHBhdGggZD0iTTUwIDQwaDAuMCIgLz4KICAgICAgICAgPHBhdGggZD0iTTUwLjAgNDBoMTAiIC8+CiAgICAgICAgIDxnPgogICAgICAgICAgPHBhdGggZD0iTTYwLjAgNDBoODEuMjUiIC8+CiAgICAgICAgICA8cGF0aCBkPSJNNDczLjI1IDQwaDgxLjI1IiAvPgogICAgICAgICAgPGcgY2xhc3M9InRlcm1pbmFsIj4KICAgICAgICAgICA8cGF0aCBkPSJNMTQxLjI1IDQwaDAuMCIgLz4KICAgICAgICAgICA8cGF0aCBkPSJNMjAzLjc1IDQwaDAuMCIgLz4KICAgICAgICAgICA8cmVjdCBoZWlnaHQ9IjIyIiByeD0iMTAiIHJ5PSIxMCIgd2lkdGg9IjYyLjUiIHg9IjE0MS4yNSIgeT0iMjkiIC8+CiAgICAgICAgICAgPHRleHQgeD0iMTcyLjUiIHk9IjQ0Ij5zY2FsZTwvdGV4dD4KICAgICAgICAgIDwvZz4KICAgICAgICAgIDxwYXRoIGQ9Ik0yMDMuNzUgNDBoMTAiIC8+CiAgICAgICAgICA8Zz4KICAgICAgICAgICA8cGF0aCBkPSJNMjEzLjc1IDQwaDAuMCIgLz4KICAgICAgICAgICA8cGF0aCBkPSJNMzE5LjI1IDQwaDAuMCIgLz4KICAgICAgICAgICA8cGF0aCBkPSJNMjEzLjc1IDQwYTEwIDEwIDAgMCAwIDEwIC0xMHYwYTEwIDEwIDAgMCAxIDEwIC0xMCIgLz4KICAgICAgICAgICA8Zz4KICAgICAgICAgICAgPHBhdGggZD0iTTIzMy43NSAyMGg2NS41IiAvPgogICAgICAgICAgIDwvZz4KICAgICAgICAgICA8cGF0aCBkPSJNMjk5LjI1IDIwYTEwIDEwIDAgMCAxIDEwIDEwdjBhMTAgMTAgMCAwIDAgMTAgMTAiIC8+CiAgICAgICAgICAgPHBhdGggZD0iTTIxMy43NSA0MGgyMCIgLz4KICAgICAgICAgICA8Zz4KICAgICAgICAgICAgPHBhdGggZD0iTTIzMy43NSA0MGgwLjAiIC8+CiAgICAgICAgICAgIDxwYXRoIGQ9Ik0yOTkuMjUgNDBoMC4wIiAvPgogICAgICAgICAgICA8cGF0aCBkPSJNMjMzLjc1IDQwaDEwIiAvPgogICAgICAgICAgICA8ZyBjbGFzcz0ibm9uLXRlcm1pbmFsIj4KICAgICAgICAgICAgIDxwYXRoIGQ9Ik0yNDMuNzUgNDBoMC4wIiAvPgogICAgICAgICAgICAgPHBhdGggZD0iTTI4OS4yNSA0MGgwLjAiIC8+CiAgICAgICAgICAgICA8cmVjdCBoZWlnaHQ9IjIyIiB3aWR0aD0iNDUuNSIgeD0iMjQzLjc1IiB5PSIyOSIgLz4KICAgICAgICAgICAgIDx0ZXh0IHg9IjI2Ni41IiB5PSI0NCI+d3NwPC90ZXh0PgogICAgICAgICAgICA8L2c+CiAgICAgICAgICAgIDxwYXRoIGQ9Ik0yODkuMjUgNDBoMTAiIC8+CiAgICAgICAgICAgIDxwYXRoIGQ9Ik0yNDMuNzUgNDBhMTAgMTAgMCAwIDAgLTEwIDEwdjBhMTAgMTAgMCAwIDAgMTAgMTAiIC8+CiAgICAgICAgICAgIDxnPgogICAgICAgICAgICAgPHBhdGggZD0iTTI0My43NSA2MGg0NS41IiAvPgogICAgICAgICAgICA8L2c+CiAgICAgICAgICAgIDxwYXRoIGQ9Ik0yODkuMjUgNjBhMTAgMTAgMCAwIDAgMTAgLTEwdjBhMTAgMTAgMCAwIDAgLTEwIC0xMCIgLz4KICAgICAgICAgICA8L2c+CiAgICAgICAgICAgPHBhdGggZD0iTTI5OS4yNSA0MGgyMCIgLz4KICAgICAgICAgIDwvZz4KICAgICAgICAgIDxwYXRoIGQ9Ik0zMTkuMjUgNDBoMTAiIC8+CiAgICAgICAgICA8ZyBjbGFzcz0idGVybWluYWwiPgogICAgICAgICAgIDxwYXRoIGQ9Ik0zMjkuMjUgNDBoMC4wIiAvPgogICAgICAgICAgIDxwYXRoIGQ9Ik0zNTcuNzUgNDBoMC4wIiAvPgogICAgICAgICAgIDxyZWN0IGhlaWdodD0iMjIiIHJ4PSIxMCIgcnk9IjEwIiB3aWR0aD0iMjguNSIgeD0iMzI5LjI1IiB5PSIyOSIgLz4KICAgICAgICAgICA8dGV4dCB4PSIzNDMuNSIgeT0iNDQiPig8L3RleHQ+CiAgICAgICAgICA8L2c+CiAgICAgICAgICA8cGF0aCBkPSJNMzU3Ljc1IDQwaDEwIiAvPgogICAgICAgICAgPGc+CiAgICAgICAgICAgPHBhdGggZD0iTTM2Ny43NSA0MGgwLjAiIC8+CiAgICAgICAgICAgPHBhdGggZD0iTTQ3My4yNSA0MGgwLjAiIC8+CiAgICAgICAgICAgPHBhdGggZD0iTTM2Ny43NSA0MGExMCAxMCAwIDAgMCAxMCAtMTB2MGExMCAxMCAwIDAgMSAxMCAtMTAiIC8+CiAgICAgICAgICAgPGc+CiAgICAgICAgICAgIDxwYXRoIGQ9Ik0zODcuNzUgMjBoNjUuNSIgLz4KICAgICAgICAgICA8L2c+CiAgICAgICAgICAgPHBhdGggZD0iTTQ1My4yNSAyMGExMCAxMCAwIDAgMSAxMCAxMHYwYTEwIDEwIDAgMCAwIDEwIDEwIiAvPgogICAgICAgICAgIDxwYXRoIGQ9Ik0zNjcuNzUgNDBoMjAiIC8+CiAgICAgICAgICAgPGc+CiAgICAgICAgICAgIDxwYXRoIGQ9Ik0zODcuNzUgNDBoMC4wIiAvPgogICAgICAgICAgICA8cGF0aCBkPSJNNDUzLjI1IDQwaDAuMCIgLz4KICAgICAgICAgICAgPHBhdGggZD0iTTM4Ny43NSA0MGgxMCIgLz4KICAgICAgICAgICAgPGcgY2xhc3M9Im5vbi10ZXJtaW5hbCI+CiAgICAgICAgICAgICA8cGF0aCBkPSJNMzk3Ljc1IDQwaDAuMCIgLz4KICAgICAgICAgICAgIDxwYXRoIGQ9Ik00NDMuMjUgNDBoMC4wIiAvPgogICAgICAgICAgICAgPHJlY3QgaGVpZ2h0PSIyMiIgd2lkdGg9IjQ1LjUiIHg9IjM5Ny43NSIgeT0iMjkiIC8+CiAgICAgICAgICAgICA8dGV4dCB4PSI0MjAuNSIgeT0iNDQiPndzcDwvdGV4dD4KICAgICAgICAgICAgPC9nPgogICAgICAgICAgICA8cGF0aCBkPSJNNDQzLjI1IDQwaDEwIiAvPgogICAgICAgICAgICA8cGF0aCBkPSJNMzk3Ljc1IDQwYTEwIDEwIDAgMCAwIC0xMCAxMHYwYTEwIDEwIDAgMCAwIDEwIDEwIiAvPgogICAgICAgICAgICA8Zz4KICAgICAgICAgICAgIDxwYXRoIGQ9Ik0zOTcuNzUgNjBoNDUuNSIgLz4KICAgICAgICAgICAgPC9nPgogICAgICAgICAgICA8cGF0aCBkPSJNNDQzLjI1IDYwYTEwIDEwIDAgMCAwIDEwIC0xMHYwYTEwIDEwIDAgMCAwIC0xMCAtMTAiIC8+CiAgICAgICAgICAgPC9nPgogICAgICAgICAgIDxwYXRoIGQ9Ik00NTMuMjUgNDBoMjAiIC8+CiAgICAgICAgICA8L2c+CiAgICAgICAgIDwvZz4KICAgICAgICAgPHBhdGggZD0iTTU1NC41IDQwYTEwIDEwIDAgMCAxIDEwIDEwdjhhMTAgMTAgMCAwIDEgLTEwIDEwaC00OTQuNWExMCAxMCAwIDAgMCAtMTAgMTB2MTZhMTAgMTAgMCAwIDAgMTAgMTAiIC8+CiAgICAgICAgIDxnPgogICAgICAgICAgPHBhdGggZD0iTTYwLjAgMTA0aDEwLjAiIC8+CiAgICAgICAgICA8cGF0aCBkPSJNNTQ0LjUgMTA0aDEwLjAiIC8+CiAgICAgICAgICA8ZyBjbGFzcz0ibm9uLXRlcm1pbmFsIj4KICAgICAgICAgICA8cGF0aCBkPSJNNzAuMCAxMDRoMC4wIiAvPgogICAgICAgICAgIDxwYXRoIGQ9Ik0yMDkuMCAxMDRoMC4wIiAvPgogICAgICAgICAgIDxyZWN0IGhlaWdodD0iMjIiIHdpZHRoPSIxMzkiIHg9IjcwIiB5PSI5MyIgLz4KICAgICAgICAgICA8dGV4dCB4PSIxMzkuNSIgeT0iMTA4Ij4mbHQ7bnVtYmVyLXRva2VuJmd0OzwvdGV4dD4KICAgICAgICAgIDwvZz4KICAgICAgICAgIDxwYXRoIGQ9Ik0yMDkuMCAxMDRoMTAiIC8+CiAgICAgICAgICA8Zz4KICAgICAgICAgICA8cGF0aCBkPSJNMjE5LjAgMTA0aDAuMCIgLz4KICAgICAgICAgICA8cGF0aCBkPSJNNTQ0LjUgMTA0aDAuMCIgLz4KICAgICAgICAgICA8cGF0aCBkPSJNMjE5LjAgMTA0YTEwIDEwIDAgMCAwIDEwIC0xMHYtOGExMCAxMCAwIDAgMSAxMCAtMTAiIC8+CiAgICAgICAgICAgPGc+CiAgICAgICAgICAgIDxwYXRoIGQ9Ik0yMzkuMCA3NmgyODUuNSIgLz4KICAgICAgICAgICA8L2c+CiAgICAgICAgICAgPHBhdGggZD0iTTUyNC41IDc2YTEwIDEwIDAgMCAxIDEwIDEwdjhhMTAgMTAgMCAwIDAgMTAgMTAiIC8+CiAgICAgICAgICAgPHBhdGggZD0iTTIxOS4wIDEwNGgyMCIgLz4KICAgICAgICAgICA8Zz4KICAgICAgICAgICAgPHBhdGggZD0iTTIzOS4wIDEwNGgwLjAiIC8+CiAgICAgICAgICAgIDxwYXRoIGQ9Ik01MjQuNSAxMDRoMC4wIiAvPgogICAgICAgICAgICA8Zz4KICAgICAgICAgICAgIDxwYXRoIGQ9Ik0yMzkuMCAxMDRoMC4wIiAvPgogICAgICAgICAgICAgPHBhdGggZD0iTTM3NS41IDEwNGgwLjAiIC8+CiAgICAgICAgICAgICA8cGF0aCBkPSJNMjM5LjAgMTA0YTEwIDEwIDAgMCAwIDEwIC0xMHYwYTEwIDEwIDAgMCAxIDEwIC0xMCIgLz4KICAgICAgICAgICAgIDxnPgogICAgICAgICAgICAgIDxwYXRoIGQ9Ik0yNTkuMCA4NGg5Ni41IiAvPgogICAgICAgICAgICAgPC9nPgogICAgICAgICAgICAgPHBhdGggZD0iTTM1NS41IDg0YTEwIDEwIDAgMCAxIDEwIDEwdjBhMTAgMTAgMCAwIDAgMTAgMTAiIC8+CiAgICAgICAgICAgICA8cGF0aCBkPSJNMjM5LjAgMTA0aDIwIiAvPgogICAgICAgICAgICAgPGcgY2xhc3M9Im5vbi10ZXJtaW5hbCI+CiAgICAgICAgICAgICAgPHBhdGggZD0iTTI1OS4wIDEwNGgwLjAiIC8+CiAgICAgICAgICAgICAgPHBhdGggZD0iTTM1NS41IDEwNGgwLjAiIC8+CiAgICAgICAgICAgICAgPHJlY3QgaGVpZ2h0PSIyMiIgd2lkdGg9Ijk2LjUiIHg9IjI1OSIgeT0iOTMiIC8+CiAgICAgICAgICAgICAgPHRleHQgeD0iMzA3LjI1IiB5PSIxMDgiPmNvbW1hLXdzcDwvdGV4dD4KICAgICAgICAgICAgIDwvZz4KICAgICAgICAgICAgIDxwYXRoIGQ9Ik0zNTUuNSAxMDRoMjAiIC8+CiAgICAgICAgICAgIDwvZz4KICAgICAgICAgICAgPHBhdGggZD0iTTM3NS41IDEwNGgxMCIgLz4KICAgICAgICAgICAgPGcgY2xhc3M9Im5vbi10ZXJtaW5hbCI+CiAgICAgICAgICAgICA8cGF0aCBkPSJNMzg1LjUgMTA0aDAuMCIgLz4KICAgICAgICAgICAgIDxwYXRoIGQ9Ik01MjQuNSAxMDRoMC4wIiAvPgogICAgICAgICAgICAgPHJlY3QgaGVpZ2h0PSIyMiIgd2lkdGg9IjEzOSIgeD0iMzg1LjUiIHk9IjkzIiAvPgogICAgICAgICAgICAgPHRleHQgeD0iNDU1IiB5PSIxMDgiPiZsdDtudW1iZXItdG9rZW4mZ3Q7PC90ZXh0PgogICAgICAgICAgICA8L2c+CiAgICAgICAgICAgPC9nPgogICAgICAgICAgIDxwYXRoIGQ9Ik01MjQuNSAxMDRoMjAiIC8+CiAgICAgICAgICA8L2c+CiAgICAgICAgIDwvZz4KICAgICAgICAgPHBhdGggZD0iTTU1NC41IDEwNGExMCAxMCAwIDAgMSAxMCAxMHYwYTEwIDEwIDAgMCAxIC0xMCAxMGgtNDk0LjVhMTAgMTAgMCAwIDAgLTEwIDEwdjhhMTAgMTAgMCAwIDAgMTAgMTAiIC8+CiAgICAgICAgIDxnPgogICAgICAgICAgPHBhdGggZD0iTTYwLjAgMTUyaDE3NS4yNSIgLz4KICAgICAgICAgIDxwYXRoIGQ9Ik0zNzkuMjUgMTUyaDE3NS4yNSIgLz4KICAgICAgICAgIDxnPgogICAgICAgICAgIDxwYXRoIGQ9Ik0yMzUuMjUgMTUyaDAuMCIgLz4KICAgICAgICAgICA8cGF0aCBkPSJNMzQwLjc1IDE1MmgwLjAiIC8+CiAgICAgICAgICAgPHBhdGggZD0iTTIzNS4yNSAxNTJhMTAgMTAgMCAwIDAgMTAgLTEwdjBhMTAgMTAgMCAwIDEgMTAgLTEwIiAvPgogICAgICAgICAgIDxnPgogICAgICAgICAgICA8cGF0aCBkPSJNMjU1LjI1IDEzMmg2NS41IiAvPgogICAgICAgICAgIDwvZz4KICAgICAgICAgICA8cGF0aCBkPSJNMzIwLjc1IDEzMmExMCAxMCAwIDAgMSAxMCAxMHYwYTEwIDEwIDAgMCAwIDEwIDEwIiAvPgogICAgICAgICAgIDxwYXRoIGQ9Ik0yMzUuMjUgMTUyaDIwIiAvPgogICAgICAgICAgIDxnPgogICAgICAgICAgICA8cGF0aCBkPSJNMjU1LjI1IDE1MmgwLjAiIC8+CiAgICAgICAgICAgIDxwYXRoIGQ9Ik0zMjAuNzUgMTUyaDAuMCIgLz4KICAgICAgICAgICAgPHBhdGggZD0iTTI1NS4yNSAxNTJoMTAiIC8+CiAgICAgICAgICAgIDxnIGNsYXNzPSJub24tdGVybWluYWwiPgogICAgICAgICAgICAgPHBhdGggZD0iTTI2NS4yNSAxNTJoMC4wIiAvPgogICAgICAgICAgICAgPHBhdGggZD0iTTMxMC43NSAxNTJoMC4wIiAvPgogICAgICAgICAgICAgPHJlY3QgaGVpZ2h0PSIyMiIgd2lkdGg9IjQ1LjUiIHg9IjI2NS4yNSIgeT0iMTQxIiAvPgogICAgICAgICAgICAgPHRleHQgeD0iMjg4IiB5PSIxNTYiPndzcDwvdGV4dD4KICAgICAgICAgICAgPC9nPgogICAgICAgICAgICA8cGF0aCBkPSJNMzEwLjc1IDE1MmgxMCIgLz4KICAgICAgICAgICAgPHBhdGggZD0iTTI2NS4yNSAxNTJhMTAgMTAgMCAwIDAgLTEwIDEwdjBhMTAgMTAgMCAwIDAgMTAgMTAiIC8+CiAgICAgICAgICAgIDxnPgogICAgICAgICAgICAgPHBhdGggZD0iTTI2NS4yNSAxNzJoNDUuNSIgLz4KICAgICAgICAgICAgPC9nPgogICAgICAgICAgICA8cGF0aCBkPSJNMzEwLjc1IDE3MmExMCAxMCAwIDAgMCAxMCAtMTB2MGExMCAxMCAwIDAgMCAtMTAgLTEwIiAvPgogICAgICAgICAgIDwvZz4KICAgICAgICAgICA8cGF0aCBkPSJNMzIwLjc1IDE1MmgyMCIgLz4KICAgICAgICAgIDwvZz4KICAgICAgICAgIDxwYXRoIGQ9Ik0zNDAuNzUgMTUyaDEwIiAvPgogICAgICAgICAgPGcgY2xhc3M9InRlcm1pbmFsIj4KICAgICAgICAgICA8cGF0aCBkPSJNMzUwLjc1IDE1MmgwLjAiIC8+CiAgICAgICAgICAgPHBhdGggZD0iTTM3OS4yNSAxNTJoMC4wIiAvPgogICAgICAgICAgIDxyZWN0IGhlaWdodD0iMjIiIHJ4PSIxMCIgcnk9IjEwIiB3aWR0aD0iMjguNSIgeD0iMzUwLjc1IiB5PSIxNDEiIC8+CiAgICAgICAgICAgPHRleHQgeD0iMzY1IiB5PSIxNTYiPik8L3RleHQ+CiAgICAgICAgICA8L2c+CiAgICAgICAgIDwvZz4KICAgICAgICAgPHBhdGggZD0iTTU1NC41IDE1MmgxMCIgLz4KICAgICAgICAgPHBhdGggZD0iTTU2NC41IDE1MmgwLjAiIC8+CiAgICAgICAgPC9nPgogICAgICAgIDxwYXRoIGQ9Ik01NjQuNSAxNTJoMTAiIC8+CiAgICAgICAgPHBhdGggZD0iTSA1NzQuNSAxNTIgaCAyMCBtIC0xMCAtMTAgdiAyMCBtIDEwIC0yMCB2IDIwIiAvPgogICAgICAgPC9nPgogICAgICA8L3N2Zz4=)
 :::

rotate

: "rotate" wsp* "(" wsp* number ( comma-wsp? number comma-wsp? number )? wsp* ")"

: ::: railroad
 !(data:image/svg+xml;base64,PHN2ZyBjbGFzcz0icmFpbHJvYWQtZGlhZ3JhbSIgaGVpZ2h0PSIyMTUiIHZpZXdib3g9IjAgMCA2MzQuNSAyMTUiIHdpZHRoPSI2MzQuNSI+CiAgICAgICA8ZyB0cmFuc2Zvcm09InRyYW5zbGF0ZSguNSAuNSkiPgogICAgICAgIDxnPgogICAgICAgICA8cGF0aCBkPSJNMjAgMzB2MjBtMTAgLTIwdjIwbS0xMCAtMTBoMjAiIC8+CiAgICAgICAgPC9nPgogICAgICAgIDxwYXRoIGQ9Ik00MCA0MGgxMCIgLz4KICAgICAgICA8Zz4KICAgICAgICAgPHBhdGggZD0iTTUwIDQwaDAuMCIgLz4KICAgICAgICAgPHBhdGggZD0iTTUwLjAgNDBoMTAiIC8+CiAgICAgICAgIDxnPgogICAgICAgICAgPHBhdGggZD0iTTYwLjAgNDBoODcuMCIgLz4KICAgICAgICAgIDxwYXRoIGQ9Ik00ODcuNSA0MGg4Ny4wIiAvPgogICAgICAgICAgPGcgY2xhc3M9InRlcm1pbmFsIj4KICAgICAgICAgICA8cGF0aCBkPSJNMTQ3LjAgNDBoMC4wIiAvPgogICAgICAgICAgIDxwYXRoIGQ9Ik0yMTguMCA0MGgwLjAiIC8+CiAgICAgICAgICAgPHJlY3QgaGVpZ2h0PSIyMiIgcng9IjEwIiByeT0iMTAiIHdpZHRoPSI3MSIgeD0iMTQ3IiB5PSIyOSIgLz4KICAgICAgICAgICA8dGV4dCB4PSIxODIuNSIgeT0iNDQiPnJvdGF0ZTwvdGV4dD4KICAgICAgICAgIDwvZz4KICAgICAgICAgIDxwYXRoIGQ9Ik0yMTguMCA0MGgxMCIgLz4KICAgICAgICAgIDxnPgogICAgICAgICAgIDxwYXRoIGQ9Ik0yMjguMCA0MGgwLjAiIC8+CiAgICAgICAgICAgPHBhdGggZD0iTTMzMy41IDQwaDAuMCIgLz4KICAgICAgICAgICA8cGF0aCBkPSJNMjI4LjAgNDBhMTAgMTAgMCAwIDAgMTAgLTEwdjBhMTAgMTAgMCAwIDEgMTAgLTEwIiAvPgogICAgICAgICAgIDxnPgogICAgICAgICAgICA8cGF0aCBkPSJNMjQ4LjAgMjBoNjUuNSIgLz4KICAgICAgICAgICA8L2c+CiAgICAgICAgICAgPHBhdGggZD0iTTMxMy41IDIwYTEwIDEwIDAgMCAxIDEwIDEwdjBhMTAgMTAgMCAwIDAgMTAgMTAiIC8+CiAgICAgICAgICAgPHBhdGggZD0iTTIyOC4wIDQwaDIwIiAvPgogICAgICAgICAgIDxnPgogICAgICAgICAgICA8cGF0aCBkPSJNMjQ4LjAgNDBoMC4wIiAvPgogICAgICAgICAgICA8cGF0aCBkPSJNMzEzLjUgNDBoMC4wIiAvPgogICAgICAgICAgICA8cGF0aCBkPSJNMjQ4LjAgNDBoMTAiIC8+CiAgICAgICAgICAgIDxnIGNsYXNzPSJub24tdGVybWluYWwiPgogICAgICAgICAgICAgPHBhdGggZD0iTTI1OC4wIDQwaDAuMCIgLz4KICAgICAgICAgICAgIDxwYXRoIGQ9Ik0zMDMuNSA0MGgwLjAiIC8+CiAgICAgICAgICAgICA8cmVjdCBoZWlnaHQ9IjIyIiB3aWR0aD0iNDUuNSIgeD0iMjU4IiB5PSIyOSIgLz4KICAgICAgICAgICAgIDx0ZXh0IHg9IjI4MC43NSIgeT0iNDQiPndzcDwvdGV4dD4KICAgICAgICAgICAgPC9nPgogICAgICAgICAgICA8cGF0aCBkPSJNMzAzLjUgNDBoMTAiIC8+CiAgICAgICAgICAgIDxwYXRoIGQ9Ik0yNTguMCA0MGExMCAxMCAwIDAgMCAtMTAgMTB2MGExMCAxMCAwIDAgMCAxMCAxMCIgLz4KICAgICAgICAgICAgPGc+CiAgICAgICAgICAgICA8cGF0aCBkPSJNMjU4LjAgNjBoNDUuNSIgLz4KICAgICAgICAgICAgPC9nPgogICAgICAgICAgICA8cGF0aCBkPSJNMzAzLjUgNjBhMTAgMTAgMCAwIDAgMTAgLTEwdjBhMTAgMTAgMCAwIDAgLTEwIC0xMCIgLz4KICAgICAgICAgICA8L2c+CiAgICAgICAgICAgPHBhdGggZD0iTTMxMy41IDQwaDIwIiAvPgogICAgICAgICAgPC9nPgogICAgICAgICAgPHBhdGggZD0iTTMzMy41IDQwaDEwIiAvPgogICAgICAgICAgPGcgY2xhc3M9InRlcm1pbmFsIj4KICAgICAgICAgICA8cGF0aCBkPSJNMzQzLjUgNDBoMC4wIiAvPgogICAgICAgICAgIDxwYXRoIGQ9Ik0zNzIuMCA0MGgwLjAiIC8+CiAgICAgICAgICAgPHJlY3QgaGVpZ2h0PSIyMiIgcng9IjEwIiByeT0iMTAiIHdpZHRoPSIyOC41IiB4PSIzNDMuNSIgeT0iMjkiIC8+CiAgICAgICAgICAgPHRleHQgeD0iMzU3Ljc1IiB5PSI0NCI+KDwvdGV4dD4KICAgICAgICAgIDwvZz4KICAgICAgICAgIDxwYXRoIGQ9Ik0zNzIuMCA0MGgxMCIgLz4KICAgICAgICAgIDxnPgogICAgICAgICAgIDxwYXRoIGQ9Ik0zODIuMCA0MGgwLjAiIC8+CiAgICAgICAgICAgPHBhdGggZD0iTTQ4Ny41IDQwaDAuMCIgLz4KICAgICAgICAgICA8cGF0aCBkPSJNMzgyLjAgNDBhMTAgMTAgMCAwIDAgMTAgLTEwdjBhMTAgMTAgMCAwIDEgMTAgLTEwIiAvPgogICAgICAgICAgIDxnPgogICAgICAgICAgICA8cGF0aCBkPSJNNDAyLjAgMjBoNjUuNSIgLz4KICAgICAgICAgICA8L2c+CiAgICAgICAgICAgPHBhdGggZD0iTTQ2Ny41IDIwYTEwIDEwIDAgMCAxIDEwIDEwdjBhMTAgMTAgMCAwIDAgMTAgMTAiIC8+CiAgICAgICAgICAgPHBhdGggZD0iTTM4Mi4wIDQwaDIwIiAvPgogICAgICAgICAgIDxnPgogICAgICAgICAgICA8cGF0aCBkPSJNNDAyLjAgNDBoMC4wIiAvPgogICAgICAgICAgICA8cGF0aCBkPSJNNDY3LjUgNDBoMC4wIiAvPgogICAgICAgICAgICA8cGF0aCBkPSJNNDAyLjAgNDBoMTAiIC8+CiAgICAgICAgICAgIDxnIGNsYXNzPSJub24tdGVybWluYWwiPgogICAgICAgICAgICAgPHBhdGggZD0iTTQxMi4wIDQwaDAuMCIgLz4KICAgICAgICAgICAgIDxwYXRoIGQ9Ik00NTcuNSA0MGgwLjAiIC8+CiAgICAgICAgICAgICA8cmVjdCBoZWlnaHQ9IjIyIiB3aWR0aD0iNDUuNSIgeD0iNDEyIiB5PSIyOSIgLz4KICAgICAgICAgICAgIDx0ZXh0IHg9IjQzNC43NSIgeT0iNDQiPndzcDwvdGV4dD4KICAgICAgICAgICAgPC9nPgogICAgICAgICAgICA8cGF0aCBkPSJNNDU3LjUgNDBoMTAiIC8+CiAgICAgICAgICAgIDxwYXRoIGQ9Ik00MTIuMCA0MGExMCAxMCAwIDAgMCAtMTAgMTB2MGExMCAxMCAwIDAgMCAxMCAxMCIgLz4KICAgICAgICAgICAgPGc+CiAgICAgICAgICAgICA8cGF0aCBkPSJNNDEyLjAgNjBoNDUuNSIgLz4KICAgICAgICAgICAgPC9nPgogICAgICAgICAgICA8cGF0aCBkPSJNNDU3LjUgNjBhMTAgMTAgMCAwIDAgMTAgLTEwdjBhMTAgMTAgMCAwIDAgLTEwIC0xMCIgLz4KICAgICAgICAgICA8L2c+CiAgICAgICAgICAgPHBhdGggZD0iTTQ2Ny41IDQwaDIwIiAvPgogICAgICAgICAgPC9nPgogICAgICAgICA8L2c+CiAgICAgICAgIDxwYXRoIGQ9Ik01NzQuNSA0MGExMCAxMCAwIDAgMSAxMCAxMHY4YTEwIDEwIDAgMCAxIC0xMCAxMGgtNTE0LjVhMTAgMTAgMCAwIDAgLTEwIDEwdjE2YTEwIDEwIDAgMCAwIDEwIDEwIiAvPgogICAgICAgICA8Zz4KICAgICAgICAgIDxwYXRoIGQ9Ik02MC4wIDEwNGgxMC4wIiAvPgogICAgICAgICAgPHBhdGggZD0iTTU2NC41IDEwNGgxMC4wIiAvPgogICAgICAgICAgPGcgY2xhc3M9Im5vbi10ZXJtaW5hbCI+CiAgICAgICAgICAgPHBhdGggZD0iTTcwLjAgMTA0aDAuMCIgLz4KICAgICAgICAgICA8cGF0aCBkPSJNMjA5LjAgMTA0aDAuMCIgLz4KICAgICAgICAgICA8cmVjdCBoZWlnaHQ9IjIyIiB3aWR0aD0iMTM5IiB4PSI3MCIgeT0iOTMiIC8+CiAgICAgICAgICAgPHRleHQgeD0iMTM5LjUiIHk9IjEwOCI+Jmx0O251bWJlci10b2tlbiZndDs8L3RleHQ+CiAgICAgICAgICA8L2c+CiAgICAgICAgICA8cGF0aCBkPSJNMjA5LjAgMTA0aDEwIiAvPgogICAgICAgICAgPGc+CiAgICAgICAgICAgPHBhdGggZD0iTTIxOS4wIDEwNGgwLjAiIC8+CiAgICAgICAgICAgPHBhdGggZD0iTTU2NC41IDEwNGgwLjAiIC8+CiAgICAgICAgICAgPHBhdGggZD0iTTIxOS4wIDEwNGExMCAxMCAwIDAgMCAxMCAtMTB2LThhMTAgMTAgMCAwIDEgMTAgLTEwIiAvPgogICAgICAgICAgIDxnPgogICAgICAgICAgICA8cGF0aCBkPSJNMjM5LjAgNzZoMzA1LjUiIC8+CiAgICAgICAgICAgPC9nPgogICAgICAgICAgIDxwYXRoIGQ9Ik01NDQuNSA3NmExMCAxMCAwIDAgMSAxMCAxMHY4YTEwIDEwIDAgMCAwIDEwIDEwIiAvPgogICAgICAgICAgIDxwYXRoIGQ9Ik0yMTkuMCAxMDRoMjAiIC8+CiAgICAgICAgICAgPGc+CiAgICAgICAgICAgIDxwYXRoIGQ9Ik0yMzkuMCAxMDRoMC4wIiAvPgogICAgICAgICAgICA8cGF0aCBkPSJNNTQ0LjUgMTA0aDAuMCIgLz4KICAgICAgICAgICAgPHBhdGggZD0iTTIzOS4wIDEwNGgxMCIgLz4KICAgICAgICAgICAgPGc+CiAgICAgICAgICAgICA8cGF0aCBkPSJNMjQ5LjAgMTA0aDAuMCIgLz4KICAgICAgICAgICAgIDxwYXRoIGQ9Ik01MzQuNSAxMDRoMC4wIiAvPgogICAgICAgICAgICAgPGc+CiAgICAgICAgICAgICAgPHBhdGggZD0iTTI0OS4wIDEwNGgwLjAiIC8+CiAgICAgICAgICAgICAgPHBhdGggZD0iTTM4NS41IDEwNGgwLjAiIC8+CiAgICAgICAgICAgICAgPHBhdGggZD0iTTI0OS4wIDEwNGExMCAxMCAwIDAgMCAxMCAtMTB2MGExMCAxMCAwIDAgMSAxMCAtMTAiIC8+CiAgICAgICAgICAgICAgPGc+CiAgICAgICAgICAgICAgIDxwYXRoIGQ9Ik0yNjkuMCA4NGg5Ni41IiAvPgogICAgICAgICAgICAgIDwvZz4KICAgICAgICAgICAgICA8cGF0aCBkPSJNMzY1LjUgODRhMTAgMTAgMCAwIDEgMTAgMTB2MGExMCAxMCAwIDAgMCAxMCAxMCIgLz4KICAgICAgICAgICAgICA8cGF0aCBkPSJNMjQ5LjAgMTA0aDIwIiAvPgogICAgICAgICAgICAgIDxnIGNsYXNzPSJub24tdGVybWluYWwiPgogICAgICAgICAgICAgICA8cGF0aCBkPSJNMjY5LjAgMTA0aDAuMCIgLz4KICAgICAgICAgICAgICAgPHBhdGggZD0iTTM2NS41IDEwNGgwLjAiIC8+CiAgICAgICAgICAgICAgIDxyZWN0IGhlaWdodD0iMjIiIHdpZHRoPSI5Ni41IiB4PSIyNjkiIHk9IjkzIiAvPgogICAgICAgICAgICAgICA8dGV4dCB4PSIzMTcuMjUiIHk9IjEwOCI+Y29tbWEtd3NwPC90ZXh0PgogICAgICAgICAgICAgIDwvZz4KICAgICAgICAgICAgICA8cGF0aCBkPSJNMzY1LjUgMTA0aDIwIiAvPgogICAgICAgICAgICAgPC9nPgogICAgICAgICAgICAgPHBhdGggZD0iTTM4NS41IDEwNGgxMCIgLz4KICAgICAgICAgICAgIDxnIGNsYXNzPSJub24tdGVybWluYWwiPgogICAgICAgICAgICAgIDxwYXRoIGQ9Ik0zOTUuNSAxMDRoMC4wIiAvPgogICAgICAgICAgICAgIDxwYXRoIGQ9Ik01MzQuNSAxMDRoMC4wIiAvPgogICAgICAgICAgICAgIDxyZWN0IGhlaWdodD0iMjIiIHdpZHRoPSIxMzkiIHg9IjM5NS41IiB5PSI5MyIgLz4KICAgICAgICAgICAgICA8dGV4dCB4PSI0NjUiIHk9IjEwOCI+Jmx0O251bWJlci10b2tlbiZndDs8L3RleHQ+CiAgICAgICAgICAgICA8L2c+CiAgICAgICAgICAgIDwvZz4KICAgICAgICAgICAgPHBhdGggZD0iTTUzNC41IDEwNGgxMCIgLz4KICAgICAgICAgICAgPHBhdGggZD0iTTI0OS4wIDEwNGExMCAxMCAwIDAgMCAtMTAgMTB2N2ExMCAxMCAwIDAgMCAxMCAxMCIgLz4KICAgICAgICAgICAgPGcgY2xhc3M9Im5vbi10ZXJtaW5hbCI+CiAgICAgICAgICAgICA8cGF0aCBkPSJNMjQ5LjAgMTMxaDEzNC4yNSIgLz4KICAgICAgICAgICAgIDxwYXRoIGQ9Ik00MDAuMjUgMTMxaDEzNC4yNSIgLz4KICAgICAgICAgICAgIDx0ZXh0IGNsYXNzPSJjb21tZW50IiB4PSIzOTEuNzUiIHk9IjEzNiI+MTwvdGV4dD4KICAgICAgICAgICAgPC9nPgogICAgICAgICAgICA8cGF0aCBkPSJNNTM0LjUgMTMxYTEwIDEwIDAgMCAwIDEwIC0xMHYtN2ExMCAxMCAwIDAgMCAtMTAgLTEwIiAvPgogICAgICAgICAgIDwvZz4KICAgICAgICAgICA8cGF0aCBkPSJNNTQ0LjUgMTA0aDIwIiAvPgogICAgICAgICAgPC9nPgogICAgICAgICA8L2c+CiAgICAgICAgIDxwYXRoIGQ9Ik01NzQuNSAxMDRhMTAgMTAgMCAwIDEgMTAgMTB2MjNhMTAgMTAgMCAwIDEgLTEwIDEwaC01MTQuNWExMCAxMCAwIDAgMCAtMTAgMTB2OGExMCAxMCAwIDAgMCAxMCAxMCIgLz4KICAgICAgICAgPGc+CiAgICAgICAgICA8cGF0aCBkPSJNNjAuMCAxNzVoMTg1LjI1IiAvPgogICAgICAgICAgPHBhdGggZD0iTTM4OS4yNSAxNzVoMTg1LjI1IiAvPgogICAgICAgICAgPGc+CiAgICAgICAgICAgPHBhdGggZD0iTTI0NS4yNSAxNzVoMC4wIiAvPgogICAgICAgICAgIDxwYXRoIGQ9Ik0zNTAuNzUgMTc1aDAuMCIgLz4KICAgICAgICAgICA8cGF0aCBkPSJNMjQ1LjI1IDE3NWExMCAxMCAwIDAgMCAxMCAtMTB2MGExMCAxMCAwIDAgMSAxMCAtMTAiIC8+CiAgICAgICAgICAgPGc+CiAgICAgICAgICAgIDxwYXRoIGQ9Ik0yNjUuMjUgMTU1aDY1LjUiIC8+CiAgICAgICAgICAgPC9nPgogICAgICAgICAgIDxwYXRoIGQ9Ik0zMzAuNzUgMTU1YTEwIDEwIDAgMCAxIDEwIDEwdjBhMTAgMTAgMCAwIDAgMTAgMTAiIC8+CiAgICAgICAgICAgPHBhdGggZD0iTTI0NS4yNSAxNzVoMjAiIC8+CiAgICAgICAgICAgPGc+CiAgICAgICAgICAgIDxwYXRoIGQ9Ik0yNjUuMjUgMTc1aDAuMCIgLz4KICAgICAgICAgICAgPHBhdGggZD0iTTMzMC43NSAxNzVoMC4wIiAvPgogICAgICAgICAgICA8cGF0aCBkPSJNMjY1LjI1IDE3NWgxMCIgLz4KICAgICAgICAgICAgPGcgY2xhc3M9Im5vbi10ZXJtaW5hbCI+CiAgICAgICAgICAgICA8cGF0aCBkPSJNMjc1LjI1IDE3NWgwLjAiIC8+CiAgICAgICAgICAgICA8cGF0aCBkPSJNMzIwLjc1IDE3NWgwLjAiIC8+CiAgICAgICAgICAgICA8cmVjdCBoZWlnaHQ9IjIyIiB3aWR0aD0iNDUuNSIgeD0iMjc1LjI1IiB5PSIxNjQiIC8+CiAgICAgICAgICAgICA8dGV4dCB4PSIyOTgiIHk9IjE3OSI+d3NwPC90ZXh0PgogICAgICAgICAgICA8L2c+CiAgICAgICAgICAgIDxwYXRoIGQ9Ik0zMjAuNzUgMTc1aDEwIiAvPgogICAgICAgICAgICA8cGF0aCBkPSJNMjc1LjI1IDE3NWExMCAxMCAwIDAgMCAtMTAgMTB2MGExMCAxMCAwIDAgMCAxMCAxMCIgLz4KICAgICAgICAgICAgPGc+CiAgICAgICAgICAgICA8cGF0aCBkPSJNMjc1LjI1IDE5NWg0NS41IiAvPgogICAgICAgICAgICA8L2c+CiAgICAgICAgICAgIDxwYXRoIGQ9Ik0zMjAuNzUgMTk1YTEwIDEwIDAgMCAwIDEwIC0xMHYwYTEwIDEwIDAgMCAwIC0xMCAtMTAiIC8+CiAgICAgICAgICAgPC9nPgogICAgICAgICAgIDxwYXRoIGQ9Ik0zMzAuNzUgMTc1aDIwIiAvPgogICAgICAgICAgPC9nPgogICAgICAgICAgPHBhdGggZD0iTTM1MC43NSAxNzVoMTAiIC8+CiAgICAgICAgICA8ZyBjbGFzcz0idGVybWluYWwiPgogICAgICAgICAgIDxwYXRoIGQ9Ik0zNjAuNzUgMTc1aDAuMCIgLz4KICAgICAgICAgICA8cGF0aCBkPSJNMzg5LjI1IDE3NWgwLjAiIC8+CiAgICAgICAgICAgPHJlY3QgaGVpZ2h0PSIyMiIgcng9IjEwIiByeT0iMTAiIHdpZHRoPSIyOC41IiB4PSIzNjAuNzUiIHk9IjE2NCIgLz4KICAgICAgICAgICA8dGV4dCB4PSIzNzUiIHk9IjE3OSI+KTwvdGV4dD4KICAgICAgICAgIDwvZz4KICAgICAgICAgPC9nPgogICAgICAgICA8cGF0aCBkPSJNNTc0LjUgMTc1aDEwIiAvPgogICAgICAgICA8cGF0aCBkPSJNNTg0LjUgMTc1aDAuMCIgLz4KICAgICAgICA8L2c+CiAgICAgICAgPHBhdGggZD0iTTU4NC41IDE3NWgxMCIgLz4KICAgICAgICA8cGF0aCBkPSJNIDU5NC41IDE3NSBoIDIwIG0gLTEwIC0xMCB2IDIwIG0gMTAgLTIwIHYgMjAiIC8+CiAgICAgICA8L2c+CiAgICAgIDwvc3ZnPg==)
 :::

skewX

: "skewX" wsp* "(" wsp* number wsp* ")"

: ::: railroad
 !(data:image/svg+xml;base64,PHN2ZyBjbGFzcz0icmFpbHJvYWQtZGlhZ3JhbSIgaGVpZ2h0PSIxNzYiIHZpZXdib3g9IjAgMCA0NzIuMCAxNzYiIHdpZHRoPSI0NzIuMCI+CiAgICAgICA8ZyB0cmFuc2Zvcm09InRyYW5zbGF0ZSguNSAuNSkiPgogICAgICAgIDxnPgogICAgICAgICA8cGF0aCBkPSJNMjAgMzB2MjBtMTAgLTIwdjIwbS0xMCAtMTBoMjAiIC8+CiAgICAgICAgPC9nPgogICAgICAgIDxwYXRoIGQ9Ik00MCA0MGgxMCIgLz4KICAgICAgICA8Zz4KICAgICAgICAgPHBhdGggZD0iTTUwIDQwaDAuMCIgLz4KICAgICAgICAgPHBhdGggZD0iTTUwLjAgNDBoMTAiIC8+CiAgICAgICAgIDxnPgogICAgICAgICAgPHBhdGggZD0iTTYwLjAgNDBoMTAuMCIgLz4KICAgICAgICAgIDxwYXRoIGQ9Ik00MDIuMCA0MGgxMC4wIiAvPgogICAgICAgICAgPGcgY2xhc3M9InRlcm1pbmFsIj4KICAgICAgICAgICA8cGF0aCBkPSJNNzAuMCA0MGgwLjAiIC8+CiAgICAgICAgICAgPHBhdGggZD0iTTEzMi41IDQwaDAuMCIgLz4KICAgICAgICAgICA8cmVjdCBoZWlnaHQ9IjIyIiByeD0iMTAiIHJ5PSIxMCIgd2lkdGg9IjYyLjUiIHg9IjcwIiB5PSIyOSIgLz4KICAgICAgICAgICA8dGV4dCB4PSIxMDEuMjUiIHk9IjQ0Ij5za2V3WDwvdGV4dD4KICAgICAgICAgIDwvZz4KICAgICAgICAgIDxwYXRoIGQ9Ik0xMzIuNSA0MGgxMCIgLz4KICAgICAgICAgIDxnPgogICAgICAgICAgIDxwYXRoIGQ9Ik0xNDIuNSA0MGgwLjAiIC8+CiAgICAgICAgICAgPHBhdGggZD0iTTI0OC4wIDQwaDAuMCIgLz4KICAgICAgICAgICA8cGF0aCBkPSJNMTQyLjUgNDBhMTAgMTAgMCAwIDAgMTAgLTEwdjBhMTAgMTAgMCAwIDEgMTAgLTEwIiAvPgogICAgICAgICAgIDxnPgogICAgICAgICAgICA8cGF0aCBkPSJNMTYyLjUgMjBoNjUuNSIgLz4KICAgICAgICAgICA8L2c+CiAgICAgICAgICAgPHBhdGggZD0iTTIyOC4wIDIwYTEwIDEwIDAgMCAxIDEwIDEwdjBhMTAgMTAgMCAwIDAgMTAgMTAiIC8+CiAgICAgICAgICAgPHBhdGggZD0iTTE0Mi41IDQwaDIwIiAvPgogICAgICAgICAgIDxnPgogICAgICAgICAgICA8cGF0aCBkPSJNMTYyLjUgNDBoMC4wIiAvPgogICAgICAgICAgICA8cGF0aCBkPSJNMjI4LjAgNDBoMC4wIiAvPgogICAgICAgICAgICA8cGF0aCBkPSJNMTYyLjUgNDBoMTAiIC8+CiAgICAgICAgICAgIDxnIGNsYXNzPSJub24tdGVybWluYWwiPgogICAgICAgICAgICAgPHBhdGggZD0iTTE3Mi41IDQwaDAuMCIgLz4KICAgICAgICAgICAgIDxwYXRoIGQ9Ik0yMTguMCA0MGgwLjAiIC8+CiAgICAgICAgICAgICA8cmVjdCBoZWlnaHQ9IjIyIiB3aWR0aD0iNDUuNSIgeD0iMTcyLjUiIHk9IjI5IiAvPgogICAgICAgICAgICAgPHRleHQgeD0iMTk1LjI1IiB5PSI0NCI+d3NwPC90ZXh0PgogICAgICAgICAgICA8L2c+CiAgICAgICAgICAgIDxwYXRoIGQ9Ik0yMTguMCA0MGgxMCIgLz4KICAgICAgICAgICAgPHBhdGggZD0iTTE3Mi41IDQwYTEwIDEwIDAgMCAwIC0xMCAxMHYwYTEwIDEwIDAgMCAwIDEwIDEwIiAvPgogICAgICAgICAgICA8Zz4KICAgICAgICAgICAgIDxwYXRoIGQ9Ik0xNzIuNSA2MGg0NS41IiAvPgogICAgICAgICAgICA8L2c+CiAgICAgICAgICAgIDxwYXRoIGQ9Ik0yMTguMCA2MGExMCAxMCAwIDAgMCAxMCAtMTB2MGExMCAxMCAwIDAgMCAtMTAgLTEwIiAvPgogICAgICAgICAgIDwvZz4KICAgICAgICAgICA8cGF0aCBkPSJNMjI4LjAgNDBoMjAiIC8+CiAgICAgICAgICA8L2c+CiAgICAgICAgICA8cGF0aCBkPSJNMjQ4LjAgNDBoMTAiIC8+CiAgICAgICAgICA8ZyBjbGFzcz0idGVybWluYWwiPgogICAgICAgICAgIDxwYXRoIGQ9Ik0yNTguMCA0MGgwLjAiIC8+CiAgICAgICAgICAgPHBhdGggZD0iTTI4Ni41IDQwaDAuMCIgLz4KICAgICAgICAgICA8cmVjdCBoZWlnaHQ9IjIyIiByeD0iMTAiIHJ5PSIxMCIgd2lkdGg9IjI4LjUiIHg9IjI1OCIgeT0iMjkiIC8+CiAgICAgICAgICAgPHRleHQgeD0iMjcyLjI1IiB5PSI0NCI+KDwvdGV4dD4KICAgICAgICAgIDwvZz4KICAgICAgICAgIDxwYXRoIGQ9Ik0yODYuNSA0MGgxMCIgLz4KICAgICAgICAgIDxnPgogICAgICAgICAgIDxwYXRoIGQ9Ik0yOTYuNSA0MGgwLjAiIC8+CiAgICAgICAgICAgPHBhdGggZD0iTTQwMi4wIDQwaDAuMCIgLz4KICAgICAgICAgICA8cGF0aCBkPSJNMjk2LjUgNDBhMTAgMTAgMCAwIDAgMTAgLTEwdjBhMTAgMTAgMCAwIDEgMTAgLTEwIiAvPgogICAgICAgICAgIDxnPgogICAgICAgICAgICA8cGF0aCBkPSJNMzE2LjUgMjBoNjUuNSIgLz4KICAgICAgICAgICA8L2c+CiAgICAgICAgICAgPHBhdGggZD0iTTM4Mi4wIDIwYTEwIDEwIDAgMCAxIDEwIDEwdjBhMTAgMTAgMCAwIDAgMTAgMTAiIC8+CiAgICAgICAgICAgPHBhdGggZD0iTTI5Ni41IDQwaDIwIiAvPgogICAgICAgICAgIDxnPgogICAgICAgICAgICA8cGF0aCBkPSJNMzE2LjUgNDBoMC4wIiAvPgogICAgICAgICAgICA8cGF0aCBkPSJNMzgyLjAgNDBoMC4wIiAvPgogICAgICAgICAgICA8cGF0aCBkPSJNMzE2LjUgNDBoMTAiIC8+CiAgICAgICAgICAgIDxnIGNsYXNzPSJub24tdGVybWluYWwiPgogICAgICAgICAgICAgPHBhdGggZD0iTTMyNi41IDQwaDAuMCIgLz4KICAgICAgICAgICAgIDxwYXRoIGQ9Ik0zNzIuMCA0MGgwLjAiIC8+CiAgICAgICAgICAgICA8cmVjdCBoZWlnaHQ9IjIyIiB3aWR0aD0iNDUuNSIgeD0iMzI2LjUiIHk9IjI5IiAvPgogICAgICAgICAgICAgPHRleHQgeD0iMzQ5LjI1IiB5PSI0NCI+d3NwPC90ZXh0PgogICAgICAgICAgICA8L2c+CiAgICAgICAgICAgIDxwYXRoIGQ9Ik0zNzIuMCA0MGgxMCIgLz4KICAgICAgICAgICAgPHBhdGggZD0iTTMyNi41IDQwYTEwIDEwIDAgMCAwIC0xMCAxMHYwYTEwIDEwIDAgMCAwIDEwIDEwIiAvPgogICAgICAgICAgICA8Zz4KICAgICAgICAgICAgIDxwYXRoIGQ9Ik0zMjYuNSA2MGg0NS41IiAvPgogICAgICAgICAgICA8L2c+CiAgICAgICAgICAgIDxwYXRoIGQ9Ik0zNzIuMCA2MGExMCAxMCAwIDAgMCAxMCAtMTB2MGExMCAxMCAwIDAgMCAtMTAgLTEwIiAvPgogICAgICAgICAgIDwvZz4KICAgICAgICAgICA8cGF0aCBkPSJNMzgyLjAgNDBoMjAiIC8+CiAgICAgICAgICA8L2c+CiAgICAgICAgIDwvZz4KICAgICAgICAgPHBhdGggZD0iTTQxMi4wIDQwYTEwIDEwIDAgMCAxIDEwIDEwdjhhMTAgMTAgMCAwIDEgLTEwIDEwaC0zNTIuMGExMCAxMCAwIDAgMCAtMTAgMTB2MGExMCAxMCAwIDAgMCAxMCAxMCIgLz4KICAgICAgICAgPGc+CiAgICAgICAgICA8cGF0aCBkPSJNNjAuMCA4OGgxMDYuNSIgLz4KICAgICAgICAgIDxwYXRoIGQ9Ik0zMDUuNSA4OGgxMDYuNSIgLz4KICAgICAgICAgIDxnIGNsYXNzPSJub24tdGVybWluYWwiPgogICAgICAgICAgIDxwYXRoIGQ9Ik0xNjYuNSA4OGgwLjAiIC8+CiAgICAgICAgICAgPHBhdGggZD0iTTMwNS41IDg4aDAuMCIgLz4KICAgICAgICAgICA8cmVjdCBoZWlnaHQ9IjIyIiB3aWR0aD0iMTM5IiB4PSIxNjYuNSIgeT0iNzciIC8+CiAgICAgICAgICAgPHRleHQgeD0iMjM2IiB5PSI5MiI+Jmx0O251bWJlci10b2tlbiZndDs8L3RleHQ+CiAgICAgICAgICA8L2c+CiAgICAgICAgIDwvZz4KICAgICAgICAgPHBhdGggZD0iTTQxMi4wIDg4YTEwIDEwIDAgMCAxIDEwIDEwdjBhMTAgMTAgMCAwIDEgLTEwIDEwaC0zNTIuMGExMCAxMCAwIDAgMCAtMTAgMTB2OGExMCAxMCAwIDAgMCAxMCAxMCIgLz4KICAgICAgICAgPGc+CiAgICAgICAgICA8cGF0aCBkPSJNNjAuMCAxMzZoMTA0LjAiIC8+CiAgICAgICAgICA8cGF0aCBkPSJNMzA4LjAgMTM2aDEwNC4wIiAvPgogICAgICAgICAgPGc+CiAgICAgICAgICAgPHBhdGggZD0iTTE2NC4wIDEzNmgwLjAiIC8+CiAgICAgICAgICAgPHBhdGggZD0iTTI2OS41IDEzNmgwLjAiIC8+CiAgICAgICAgICAgPHBhdGggZD0iTTE2NC4wIDEzNmExMCAxMCAwIDAgMCAxMCAtMTB2MGExMCAxMCAwIDAgMSAxMCAtMTAiIC8+CiAgICAgICAgICAgPGc+CiAgICAgICAgICAgIDxwYXRoIGQ9Ik0xODQuMCAxMTZoNjUuNSIgLz4KICAgICAgICAgICA8L2c+CiAgICAgICAgICAgPHBhdGggZD0iTTI0OS41IDExNmExMCAxMCAwIDAgMSAxMCAxMHYwYTEwIDEwIDAgMCAwIDEwIDEwIiAvPgogICAgICAgICAgIDxwYXRoIGQ9Ik0xNjQuMCAxMzZoMjAiIC8+CiAgICAgICAgICAgPGc+CiAgICAgICAgICAgIDxwYXRoIGQ9Ik0xODQuMCAxMzZoMC4wIiAvPgogICAgICAgICAgICA8cGF0aCBkPSJNMjQ5LjUgMTM2aDAuMCIgLz4KICAgICAgICAgICAgPHBhdGggZD0iTTE4NC4wIDEzNmgxMCIgLz4KICAgICAgICAgICAgPGcgY2xhc3M9Im5vbi10ZXJtaW5hbCI+CiAgICAgICAgICAgICA8cGF0aCBkPSJNMTk0LjAgMTM2aDAuMCIgLz4KICAgICAgICAgICAgIDxwYXRoIGQ9Ik0yMzkuNSAxMzZoMC4wIiAvPgogICAgICAgICAgICAgPHJlY3QgaGVpZ2h0PSIyMiIgd2lkdGg9IjQ1LjUiIHg9IjE5NCIgeT0iMTI1IiAvPgogICAgICAgICAgICAgPHRleHQgeD0iMjE2Ljc1IiB5PSIxNDAiPndzcDwvdGV4dD4KICAgICAgICAgICAgPC9nPgogICAgICAgICAgICA8cGF0aCBkPSJNMjM5LjUgMTM2aDEwIiAvPgogICAgICAgICAgICA8cGF0aCBkPSJNMTk0LjAgMTM2YTEwIDEwIDAgMCAwIC0xMCAxMHYwYTEwIDEwIDAgMCAwIDEwIDEwIiAvPgogICAgICAgICAgICA8Zz4KICAgICAgICAgICAgIDxwYXRoIGQ9Ik0xOTQuMCAxNTZoNDUuNSIgLz4KICAgICAgICAgICAgPC9nPgogICAgICAgICAgICA8cGF0aCBkPSJNMjM5LjUgMTU2YTEwIDEwIDAgMCAwIDEwIC0xMHYwYTEwIDEwIDAgMCAwIC0xMCAtMTAiIC8+CiAgICAgICAgICAgPC9nPgogICAgICAgICAgIDxwYXRoIGQ9Ik0yNDkuNSAxMzZoMjAiIC8+CiAgICAgICAgICA8L2c+CiAgICAgICAgICA8cGF0aCBkPSJNMjY5LjUgMTM2aDEwIiAvPgogICAgICAgICAgPGcgY2xhc3M9InRlcm1pbmFsIj4KICAgICAgICAgICA8cGF0aCBkPSJNMjc5LjUgMTM2aDAuMCIgLz4KICAgICAgICAgICA8cGF0aCBkPSJNMzA4LjAgMTM2aDAuMCIgLz4KICAgICAgICAgICA8cmVjdCBoZWlnaHQ9IjIyIiByeD0iMTAiIHJ5PSIxMCIgd2lkdGg9IjI4LjUiIHg9IjI3OS41IiB5PSIxMjUiIC8+CiAgICAgICAgICAgPHRleHQgeD0iMjkzLjc1IiB5PSIxNDAiPik8L3RleHQ+CiAgICAgICAgICA8L2c+CiAgICAgICAgIDwvZz4KICAgICAgICAgPHBhdGggZD0iTTQxMi4wIDEzNmgxMCIgLz4KICAgICAgICAgPHBhdGggZD0iTTQyMi4wIDEzNmgwLjAiIC8+CiAgICAgICAgPC9nPgogICAgICAgIDxwYXRoIGQ9Ik00MjIuMCAxMzZoMTAiIC8+CiAgICAgICAgPHBhdGggZD0iTSA0MzIuMCAxMzYgaCAyMCBtIC0xMCAtMTAgdiAyMCBtIDEwIC0yMCB2IDIwIiAvPgogICAgICAgPC9nPgogICAgICA8L3N2Zz4=)
 :::

skewY

: "skewY" wsp* "(" wsp* number wsp* ")"

: ::: railroad
 !(data:image/svg+xml;base64,PHN2ZyBjbGFzcz0icmFpbHJvYWQtZGlhZ3JhbSIgaGVpZ2h0PSIxNzYiIHZpZXdib3g9IjAgMCA0NzIuMCAxNzYiIHdpZHRoPSI0NzIuMCI+CiAgICAgICA8ZyB0cmFuc2Zvcm09InRyYW5zbGF0ZSguNSAuNSkiPgogICAgICAgIDxnPgogICAgICAgICA8cGF0aCBkPSJNMjAgMzB2MjBtMTAgLTIwdjIwbS0xMCAtMTBoMjAiIC8+CiAgICAgICAgPC9nPgogICAgICAgIDxwYXRoIGQ9Ik00MCA0MGgxMCIgLz4KICAgICAgICA8Zz4KICAgICAgICAgPHBhdGggZD0iTTUwIDQwaDAuMCIgLz4KICAgICAgICAgPHBhdGggZD0iTTUwLjAgNDBoMTAiIC8+CiAgICAgICAgIDxnPgogICAgICAgICAgPHBhdGggZD0iTTYwLjAgNDBoMTAuMCIgLz4KICAgICAgICAgIDxwYXRoIGQ9Ik00MDIuMCA0MGgxMC4wIiAvPgogICAgICAgICAgPGcgY2xhc3M9InRlcm1pbmFsIj4KICAgICAgICAgICA8cGF0aCBkPSJNNzAuMCA0MGgwLjAiIC8+CiAgICAgICAgICAgPHBhdGggZD0iTTEzMi41IDQwaDAuMCIgLz4KICAgICAgICAgICA8cmVjdCBoZWlnaHQ9IjIyIiByeD0iMTAiIHJ5PSIxMCIgd2lkdGg9IjYyLjUiIHg9IjcwIiB5PSIyOSIgLz4KICAgICAgICAgICA8dGV4dCB4PSIxMDEuMjUiIHk9IjQ0Ij5za2V3WTwvdGV4dD4KICAgICAgICAgIDwvZz4KICAgICAgICAgIDxwYXRoIGQ9Ik0xMzIuNSA0MGgxMCIgLz4KICAgICAgICAgIDxnPgogICAgICAgICAgIDxwYXRoIGQ9Ik0xNDIuNSA0MGgwLjAiIC8+CiAgICAgICAgICAgPHBhdGggZD0iTTI0OC4wIDQwaDAuMCIgLz4KICAgICAgICAgICA8cGF0aCBkPSJNMTQyLjUgNDBhMTAgMTAgMCAwIDAgMTAgLTEwdjBhMTAgMTAgMCAwIDEgMTAgLTEwIiAvPgogICAgICAgICAgIDxnPgogICAgICAgICAgICA8cGF0aCBkPSJNMTYyLjUgMjBoNjUuNSIgLz4KICAgICAgICAgICA8L2c+CiAgICAgICAgICAgPHBhdGggZD0iTTIyOC4wIDIwYTEwIDEwIDAgMCAxIDEwIDEwdjBhMTAgMTAgMCAwIDAgMTAgMTAiIC8+CiAgICAgICAgICAgPHBhdGggZD0iTTE0Mi41IDQwaDIwIiAvPgogICAgICAgICAgIDxnPgogICAgICAgICAgICA8cGF0aCBkPSJNMTYyLjUgNDBoMC4wIiAvPgogICAgICAgICAgICA8cGF0aCBkPSJNMjI4LjAgNDBoMC4wIiAvPgogICAgICAgICAgICA8cGF0aCBkPSJNMTYyLjUgNDBoMTAiIC8+CiAgICAgICAgICAgIDxnIGNsYXNzPSJub24tdGVybWluYWwiPgogICAgICAgICAgICAgPHBhdGggZD0iTTE3Mi41IDQwaDAuMCIgLz4KICAgICAgICAgICAgIDxwYXRoIGQ9Ik0yMTguMCA0MGgwLjAiIC8+CiAgICAgICAgICAgICA8cmVjdCBoZWlnaHQ9IjIyIiB3aWR0aD0iNDUuNSIgeD0iMTcyLjUiIHk9IjI5IiAvPgogICAgICAgICAgICAgPHRleHQgeD0iMTk1LjI1IiB5PSI0NCI+d3NwPC90ZXh0PgogICAgICAgICAgICA8L2c+CiAgICAgICAgICAgIDxwYXRoIGQ9Ik0yMTguMCA0MGgxMCIgLz4KICAgICAgICAgICAgPHBhdGggZD0iTTE3Mi41IDQwYTEwIDEwIDAgMCAwIC0xMCAxMHYwYTEwIDEwIDAgMCAwIDEwIDEwIiAvPgogICAgICAgICAgICA8Zz4KICAgICAgICAgICAgIDxwYXRoIGQ9Ik0xNzIuNSA2MGg0NS41IiAvPgogICAgICAgICAgICA8L2c+CiAgICAgICAgICAgIDxwYXRoIGQ9Ik0yMTguMCA2MGExMCAxMCAwIDAgMCAxMCAtMTB2MGExMCAxMCAwIDAgMCAtMTAgLTEwIiAvPgogICAgICAgICAgIDwvZz4KICAgICAgICAgICA8cGF0aCBkPSJNMjI4LjAgNDBoMjAiIC8+CiAgICAgICAgICA8L2c+CiAgICAgICAgICA8cGF0aCBkPSJNMjQ4LjAgNDBoMTAiIC8+CiAgICAgICAgICA8ZyBjbGFzcz0idGVybWluYWwiPgogICAgICAgICAgIDxwYXRoIGQ9Ik0yNTguMCA0MGgwLjAiIC8+CiAgICAgICAgICAgPHBhdGggZD0iTTI4Ni41IDQwaDAuMCIgLz4KICAgICAgICAgICA8cmVjdCBoZWlnaHQ9IjIyIiByeD0iMTAiIHJ5PSIxMCIgd2lkdGg9IjI4LjUiIHg9IjI1OCIgeT0iMjkiIC8+CiAgICAgICAgICAgPHRleHQgeD0iMjcyLjI1IiB5PSI0NCI+KDwvdGV4dD4KICAgICAgICAgIDwvZz4KICAgICAgICAgIDxwYXRoIGQ9Ik0yODYuNSA0MGgxMCIgLz4KICAgICAgICAgIDxnPgogICAgICAgICAgIDxwYXRoIGQ9Ik0yOTYuNSA0MGgwLjAiIC8+CiAgICAgICAgICAgPHBhdGggZD0iTTQwMi4wIDQwaDAuMCIgLz4KICAgICAgICAgICA8cGF0aCBkPSJNMjk2LjUgNDBhMTAgMTAgMCAwIDAgMTAgLTEwdjBhMTAgMTAgMCAwIDEgMTAgLTEwIiAvPgogICAgICAgICAgIDxnPgogICAgICAgICAgICA8cGF0aCBkPSJNMzE2LjUgMjBoNjUuNSIgLz4KICAgICAgICAgICA8L2c+CiAgICAgICAgICAgPHBhdGggZD0iTTM4Mi4wIDIwYTEwIDEwIDAgMCAxIDEwIDEwdjBhMTAgMTAgMCAwIDAgMTAgMTAiIC8+CiAgICAgICAgICAgPHBhdGggZD0iTTI5Ni41IDQwaDIwIiAvPgogICAgICAgICAgIDxnPgogICAgICAgICAgICA8cGF0aCBkPSJNMzE2LjUgNDBoMC4wIiAvPgogICAgICAgICAgICA8cGF0aCBkPSJNMzgyLjAgNDBoMC4wIiAvPgogICAgICAgICAgICA8cGF0aCBkPSJNMzE2LjUgNDBoMTAiIC8+CiAgICAgICAgICAgIDxnIGNsYXNzPSJub24tdGVybWluYWwiPgogICAgICAgICAgICAgPHBhdGggZD0iTTMyNi41IDQwaDAuMCIgLz4KICAgICAgICAgICAgIDxwYXRoIGQ9Ik0zNzIuMCA0MGgwLjAiIC8+CiAgICAgICAgICAgICA8cmVjdCBoZWlnaHQ9IjIyIiB3aWR0aD0iNDUuNSIgeD0iMzI2LjUiIHk9IjI5IiAvPgogICAgICAgICAgICAgPHRleHQgeD0iMzQ5LjI1IiB5PSI0NCI+d3NwPC90ZXh0PgogICAgICAgICAgICA8L2c+CiAgICAgICAgICAgIDxwYXRoIGQ9Ik0zNzIuMCA0MGgxMCIgLz4KICAgICAgICAgICAgPHBhdGggZD0iTTMyNi41IDQwYTEwIDEwIDAgMCAwIC0xMCAxMHYwYTEwIDEwIDAgMCAwIDEwIDEwIiAvPgogICAgICAgICAgICA8Zz4KICAgICAgICAgICAgIDxwYXRoIGQ9Ik0zMjYuNSA2MGg0NS41IiAvPgogICAgICAgICAgICA8L2c+CiAgICAgICAgICAgIDxwYXRoIGQ9Ik0zNzIuMCA2MGExMCAxMCAwIDAgMCAxMCAtMTB2MGExMCAxMCAwIDAgMCAtMTAgLTEwIiAvPgogICAgICAgICAgIDwvZz4KICAgICAgICAgICA8cGF0aCBkPSJNMzgyLjAgNDBoMjAiIC8+CiAgICAgICAgICA8L2c+CiAgICAgICAgIDwvZz4KICAgICAgICAgPHBhdGggZD0iTTQxMi4wIDQwYTEwIDEwIDAgMCAxIDEwIDEwdjhhMTAgMTAgMCAwIDEgLTEwIDEwaC0zNTIuMGExMCAxMCAwIDAgMCAtMTAgMTB2MGExMCAxMCAwIDAgMCAxMCAxMCIgLz4KICAgICAgICAgPGc+CiAgICAgICAgICA8cGF0aCBkPSJNNjAuMCA4OGgxMDYuNSIgLz4KICAgICAgICAgIDxwYXRoIGQ9Ik0zMDUuNSA4OGgxMDYuNSIgLz4KICAgICAgICAgIDxnIGNsYXNzPSJub24tdGVybWluYWwiPgogICAgICAgICAgIDxwYXRoIGQ9Ik0xNjYuNSA4OGgwLjAiIC8+CiAgICAgICAgICAgPHBhdGggZD0iTTMwNS41IDg4aDAuMCIgLz4KICAgICAgICAgICA8cmVjdCBoZWlnaHQ9IjIyIiB3aWR0aD0iMTM5IiB4PSIxNjYuNSIgeT0iNzciIC8+CiAgICAgICAgICAgPHRleHQgeD0iMjM2IiB5PSI5MiI+Jmx0O251bWJlci10b2tlbiZndDs8L3RleHQ+CiAgICAgICAgICA8L2c+CiAgICAgICAgIDwvZz4KICAgICAgICAgPHBhdGggZD0iTTQxMi4wIDg4YTEwIDEwIDAgMCAxIDEwIDEwdjBhMTAgMTAgMCAwIDEgLTEwIDEwaC0zNTIuMGExMCAxMCAwIDAgMCAtMTAgMTB2OGExMCAxMCAwIDAgMCAxMCAxMCIgLz4KICAgICAgICAgPGc+CiAgICAgICAgICA8cGF0aCBkPSJNNjAuMCAxMzZoMTA0LjAiIC8+CiAgICAgICAgICA8cGF0aCBkPSJNMzA4LjAgMTM2aDEwNC4wIiAvPgogICAgICAgICAgPGc+CiAgICAgICAgICAgPHBhdGggZD0iTTE2NC4wIDEzNmgwLjAiIC8+CiAgICAgICAgICAgPHBhdGggZD0iTTI2OS41IDEzNmgwLjAiIC8+CiAgICAgICAgICAgPHBhdGggZD0iTTE2NC4wIDEzNmExMCAxMCAwIDAgMCAxMCAtMTB2MGExMCAxMCAwIDAgMSAxMCAtMTAiIC8+CiAgICAgICAgICAgPGc+CiAgICAgICAgICAgIDxwYXRoIGQ9Ik0xODQuMCAxMTZoNjUuNSIgLz4KICAgICAgICAgICA8L2c+CiAgICAgICAgICAgPHBhdGggZD0iTTI0OS41IDExNmExMCAxMCAwIDAgMSAxMCAxMHYwYTEwIDEwIDAgMCAwIDEwIDEwIiAvPgogICAgICAgICAgIDxwYXRoIGQ9Ik0xNjQuMCAxMzZoMjAiIC8+CiAgICAgICAgICAgPGc+CiAgICAgICAgICAgIDxwYXRoIGQ9Ik0xODQuMCAxMzZoMC4wIiAvPgogICAgICAgICAgICA8cGF0aCBkPSJNMjQ5LjUgMTM2aDAuMCIgLz4KICAgICAgICAgICAgPHBhdGggZD0iTTE4NC4wIDEzNmgxMCIgLz4KICAgICAgICAgICAgPGcgY2xhc3M9Im5vbi10ZXJtaW5hbCI+CiAgICAgICAgICAgICA8cGF0aCBkPSJNMTk0LjAgMTM2aDAuMCIgLz4KICAgICAgICAgICAgIDxwYXRoIGQ9Ik0yMzkuNSAxMzZoMC4wIiAvPgogICAgICAgICAgICAgPHJlY3QgaGVpZ2h0PSIyMiIgd2lkdGg9IjQ1LjUiIHg9IjE5NCIgeT0iMTI1IiAvPgogICAgICAgICAgICAgPHRleHQgeD0iMjE2Ljc1IiB5PSIxNDAiPndzcDwvdGV4dD4KICAgICAgICAgICAgPC9nPgogICAgICAgICAgICA8cGF0aCBkPSJNMjM5LjUgMTM2aDEwIiAvPgogICAgICAgICAgICA8cGF0aCBkPSJNMTk0LjAgMTM2YTEwIDEwIDAgMCAwIC0xMCAxMHYwYTEwIDEwIDAgMCAwIDEwIDEwIiAvPgogICAgICAgICAgICA8Zz4KICAgICAgICAgICAgIDxwYXRoIGQ9Ik0xOTQuMCAxNTZoNDUuNSIgLz4KICAgICAgICAgICAgPC9nPgogICAgICAgICAgICA8cGF0aCBkPSJNMjM5LjUgMTU2YTEwIDEwIDAgMCAwIDEwIC0xMHYwYTEwIDEwIDAgMCAwIC0xMCAtMTAiIC8+CiAgICAgICAgICAgPC9nPgogICAgICAgICAgIDxwYXRoIGQ9Ik0yNDkuNSAxMzZoMjAiIC8+CiAgICAgICAgICA8L2c+CiAgICAgICAgICA8cGF0aCBkPSJNMjY5LjUgMTM2aDEwIiAvPgogICAgICAgICAgPGcgY2xhc3M9InRlcm1pbmFsIj4KICAgICAgICAgICA8cGF0aCBkPSJNMjc5LjUgMTM2aDAuMCIgLz4KICAgICAgICAgICA8cGF0aCBkPSJNMzA4LjAgMTM2aDAuMCIgLz4KICAgICAgICAgICA8cmVjdCBoZWlnaHQ9IjIyIiByeD0iMTAiIHJ5PSIxMCIgd2lkdGg9IjI4LjUiIHg9IjI3OS41IiB5PSIxMjUiIC8+CiAgICAgICAgICAgPHRleHQgeD0iMjkzLjc1IiB5PSIxNDAiPik8L3RleHQ+CiAgICAgICAgICA8L2c+CiAgICAgICAgIDwvZz4KICAgICAgICAgPHBhdGggZD0iTTQxMi4wIDEzNmgxMCIgLz4KICAgICAgICAgPHBhdGggZD0iTTQyMi4wIDEzNmgwLjAiIC8+CiAgICAgICAgPC9nPgogICAgICAgIDxwYXRoIGQ9Ik00MjIuMCAxMzZoMTAiIC8+CiAgICAgICAgPHBhdGggZD0iTSA0MzIuMCAxMzYgaCAyMCBtIC0xMCAtMTAgdiAyMCBtIDEwIC0yMCB2IDIwIiAvPgogICAgICAgPC9nPgogICAgICA8L3N2Zz4=)
 :::

matrix

: "matrix" wsp* "(" wsp*
 number comma-wsp?
 number comma-wsp?
 number comma-wsp?
 number comma-wsp?
 number comma-wsp?
 number wsp* ")"

: ::: railroad
 !(data:image/svg+xml;base64,PHN2ZyBjbGFzcz0icmFpbHJvYWQtZGlhZ3JhbSIgaGVpZ2h0PSIyMTUiIHZpZXdib3g9IjAgMCA2MzQuNSAyMTUiIHdpZHRoPSI2MzQuNSI+CiAgICAgICA8ZyB0cmFuc2Zvcm09InRyYW5zbGF0ZSguNSAuNSkiPgogICAgICAgIDxnPgogICAgICAgICA8cGF0aCBkPSJNMjAgMzB2MjBtMTAgLTIwdjIwbS0xMCAtMTBoMjAiIC8+CiAgICAgICAgPC9nPgogICAgICAgIDxwYXRoIGQ9Ik00MCA0MGgxMCIgLz4KICAgICAgICA8Zz4KICAgICAgICAgPHBhdGggZD0iTTUwIDQwaDAuMCIgLz4KICAgICAgICAgPHBhdGggZD0iTTUwLjAgNDBoMTAiIC8+CiAgICAgICAgIDxnPgogICAgICAgICAgPHBhdGggZD0iTTYwLjAgNDBoODcuMCIgLz4KICAgICAgICAgIDxwYXRoIGQ9Ik00ODcuNSA0MGg4Ny4wIiAvPgogICAgICAgICAgPGcgY2xhc3M9InRlcm1pbmFsIj4KICAgICAgICAgICA8cGF0aCBkPSJNMTQ3LjAgNDBoMC4wIiAvPgogICAgICAgICAgIDxwYXRoIGQ9Ik0yMTguMCA0MGgwLjAiIC8+CiAgICAgICAgICAgPHJlY3QgaGVpZ2h0PSIyMiIgcng9IjEwIiByeT0iMTAiIHdpZHRoPSI3MSIgeD0iMTQ3IiB5PSIyOSIgLz4KICAgICAgICAgICA8dGV4dCB4PSIxODIuNSIgeT0iNDQiPm1hdHJpeDwvdGV4dD4KICAgICAgICAgIDwvZz4KICAgICAgICAgIDxwYXRoIGQ9Ik0yMTguMCA0MGgxMCIgLz4KICAgICAgICAgIDxnPgogICAgICAgICAgIDxwYXRoIGQ9Ik0yMjguMCA0MGgwLjAiIC8+CiAgICAgICAgICAgPHBhdGggZD0iTTMzMy41IDQwaDAuMCIgLz4KICAgICAgICAgICA8cGF0aCBkPSJNMjI4LjAgNDBhMTAgMTAgMCAwIDAgMTAgLTEwdjBhMTAgMTAgMCAwIDEgMTAgLTEwIiAvPgogICAgICAgICAgIDxnPgogICAgICAgICAgICA8cGF0aCBkPSJNMjQ4LjAgMjBoNjUuNSIgLz4KICAgICAgICAgICA8L2c+CiAgICAgICAgICAgPHBhdGggZD0iTTMxMy41IDIwYTEwIDEwIDAgMCAxIDEwIDEwdjBhMTAgMTAgMCAwIDAgMTAgMTAiIC8+CiAgICAgICAgICAgPHBhdGggZD0iTTIyOC4wIDQwaDIwIiAvPgogICAgICAgICAgIDxnPgogICAgICAgICAgICA8cGF0aCBkPSJNMjQ4LjAgNDBoMC4wIiAvPgogICAgICAgICAgICA8cGF0aCBkPSJNMzEzLjUgNDBoMC4wIiAvPgogICAgICAgICAgICA8cGF0aCBkPSJNMjQ4LjAgNDBoMTAiIC8+CiAgICAgICAgICAgIDxnIGNsYXNzPSJub24tdGVybWluYWwiPgogICAgICAgICAgICAgPHBhdGggZD0iTTI1OC4wIDQwaDAuMCIgLz4KICAgICAgICAgICAgIDxwYXRoIGQ9Ik0zMDMuNSA0MGgwLjAiIC8+CiAgICAgICAgICAgICA8cmVjdCBoZWlnaHQ9IjIyIiB3aWR0aD0iNDUuNSIgeD0iMjU4IiB5PSIyOSIgLz4KICAgICAgICAgICAgIDx0ZXh0IHg9IjI4MC43NSIgeT0iNDQiPndzcDwvdGV4dD4KICAgICAgICAgICAgPC9nPgogICAgICAgICAgICA8cGF0aCBkPSJNMzAzLjUgNDBoMTAiIC8+CiAgICAgICAgICAgIDxwYXRoIGQ9Ik0yNTguMCA0MGExMCAxMCAwIDAgMCAtMTAgMTB2MGExMCAxMCAwIDAgMCAxMCAxMCIgLz4KICAgICAgICAgICAgPGc+CiAgICAgICAgICAgICA8cGF0aCBkPSJNMjU4LjAgNjBoNDUuNSIgLz4KICAgICAgICAgICAgPC9nPgogICAgICAgICAgICA8cGF0aCBkPSJNMzAzLjUgNjBhMTAgMTAgMCAwIDAgMTAgLTEwdjBhMTAgMTAgMCAwIDAgLTEwIC0xMCIgLz4KICAgICAgICAgICA8L2c+CiAgICAgICAgICAgPHBhdGggZD0iTTMxMy41IDQwaDIwIiAvPgogICAgICAgICAgPC9nPgogICAgICAgICAgPHBhdGggZD0iTTMzMy41IDQwaDEwIiAvPgogICAgICAgICAgPGcgY2xhc3M9InRlcm1pbmFsIj4KICAgICAgICAgICA8cGF0aCBkPSJNMzQzLjUgNDBoMC4wIiAvPgogICAgICAgICAgIDxwYXRoIGQ9Ik0zNzIuMCA0MGgwLjAiIC8+CiAgICAgICAgICAgPHJlY3QgaGVpZ2h0PSIyMiIgcng9IjEwIiByeT0iMTAiIHdpZHRoPSIyOC41IiB4PSIzNDMuNSIgeT0iMjkiIC8+CiAgICAgICAgICAgPHRleHQgeD0iMzU3Ljc1IiB5PSI0NCI+KDwvdGV4dD4KICAgICAgICAgIDwvZz4KICAgICAgICAgIDxwYXRoIGQ9Ik0zNzIuMCA0MGgxMCIgLz4KICAgICAgICAgIDxnPgogICAgICAgICAgIDxwYXRoIGQ9Ik0zODIuMCA0MGgwLjAiIC8+CiAgICAgICAgICAgPHBhdGggZD0iTTQ4Ny41IDQwaDAuMCIgLz4KICAgICAgICAgICA8cGF0aCBkPSJNMzgyLjAgNDBhMTAgMTAgMCAwIDAgMTAgLTEwdjBhMTAgMTAgMCAwIDEgMTAgLTEwIiAvPgogICAgICAgICAgIDxnPgogICAgICAgICAgICA8cGF0aCBkPSJNNDAyLjAgMjBoNjUuNSIgLz4KICAgICAgICAgICA8L2c+CiAgICAgICAgICAgPHBhdGggZD0iTTQ2Ny41IDIwYTEwIDEwIDAgMCAxIDEwIDEwdjBhMTAgMTAgMCAwIDAgMTAgMTAiIC8+CiAgICAgICAgICAgPHBhdGggZD0iTTM4Mi4wIDQwaDIwIiAvPgogICAgICAgICAgIDxnPgogICAgICAgICAgICA8cGF0aCBkPSJNNDAyLjAgNDBoMC4wIiAvPgogICAgICAgICAgICA8cGF0aCBkPSJNNDY3LjUgNDBoMC4wIiAvPgogICAgICAgICAgICA8cGF0aCBkPSJNNDAyLjAgNDBoMTAiIC8+CiAgICAgICAgICAgIDxnIGNsYXNzPSJub24tdGVybWluYWwiPgogICAgICAgICAgICAgPHBhdGggZD0iTTQxMi4wIDQwaDAuMCIgLz4KICAgICAgICAgICAgIDxwYXRoIGQ9Ik00NTcuNSA0MGgwLjAiIC8+CiAgICAgICAgICAgICA8cmVjdCBoZWlnaHQ9IjIyIiB3aWR0aD0iNDUuNSIgeD0iNDEyIiB5PSIyOSIgLz4KICAgICAgICAgICAgIDx0ZXh0IHg9IjQzNC43NSIgeT0iNDQiPndzcDwvdGV4dD4KICAgICAgICAgICAgPC9nPgogICAgICAgICAgICA8cGF0aCBkPSJNNDU3LjUgNDBoMTAiIC8+CiAgICAgICAgICAgIDxwYXRoIGQ9Ik00MTIuMCA0MGExMCAxMCAwIDAgMCAtMTAgMTB2MGExMCAxMCAwIDAgMCAxMCAxMCIgLz4KICAgICAgICAgICAgPGc+CiAgICAgICAgICAgICA8cGF0aCBkPSJNNDEyLjAgNjBoNDUuNSIgLz4KICAgICAgICAgICAgPC9nPgogICAgICAgICAgICA8cGF0aCBkPSJNNDU3LjUgNjBhMTAgMTAgMCAwIDAgMTAgLTEwdjBhMTAgMTAgMCAwIDAgLTEwIC0xMCIgLz4KICAgICAgICAgICA8L2c+CiAgICAgICAgICAgPHBhdGggZD0iTTQ2Ny41IDQwaDIwIiAvPgogICAgICAgICAgPC9nPgogICAgICAgICA8L2c+CiAgICAgICAgIDxwYXRoIGQ9Ik01NzQuNSA0MGExMCAxMCAwIDAgMSAxMCAxMHY4YTEwIDEwIDAgMCAxIC0xMCAxMGgtNTE0LjVhMTAgMTAgMCAwIDAgLTEwIDEwdjE2YTEwIDEwIDAgMCAwIDEwIDEwIiAvPgogICAgICAgICA8Zz4KICAgICAgICAgIDxwYXRoIGQ9Ik02MC4wIDEwNGgxMC4wIiAvPgogICAgICAgICAgPHBhdGggZD0iTTU2NC41IDEwNGgxMC4wIiAvPgogICAgICAgICAgPGcgY2xhc3M9Im5vbi10ZXJtaW5hbCI+CiAgICAgICAgICAgPHBhdGggZD0iTTcwLjAgMTA0aDAuMCIgLz4KICAgICAgICAgICA8cGF0aCBkPSJNMjA5LjAgMTA0aDAuMCIgLz4KICAgICAgICAgICA8cmVjdCBoZWlnaHQ9IjIyIiB3aWR0aD0iMTM5IiB4PSI3MCIgeT0iOTMiIC8+CiAgICAgICAgICAgPHRleHQgeD0iMTM5LjUiIHk9IjEwOCI+Jmx0O251bWJlci10b2tlbiZndDs8L3RleHQ+CiAgICAgICAgICA8L2c+CiAgICAgICAgICA8cGF0aCBkPSJNMjA5LjAgMTA0aDEwIiAvPgogICAgICAgICAgPGc+CiAgICAgICAgICAgPHBhdGggZD0iTTIxOS4wIDEwNGgwLjAiIC8+CiAgICAgICAgICAgPHBhdGggZD0iTTU2NC41IDEwNGgwLjAiIC8+CiAgICAgICAgICAgPHBhdGggZD0iTTIxOS4wIDEwNGExMCAxMCAwIDAgMCAxMCAtMTB2LThhMTAgMTAgMCAwIDEgMTAgLTEwIiAvPgogICAgICAgICAgIDxnPgogICAgICAgICAgICA8cGF0aCBkPSJNMjM5LjAgNzZoMzA1LjUiIC8+CiAgICAgICAgICAgPC9nPgogICAgICAgICAgIDxwYXRoIGQ9Ik01NDQuNSA3NmExMCAxMCAwIDAgMSAxMCAxMHY4YTEwIDEwIDAgMCAwIDEwIDEwIiAvPgogICAgICAgICAgIDxwYXRoIGQ9Ik0yMTkuMCAxMDRoMjAiIC8+CiAgICAgICAgICAgPGc+CiAgICAgICAgICAgIDxwYXRoIGQ9Ik0yMzkuMCAxMDRoMC4wIiAvPgogICAgICAgICAgICA8cGF0aCBkPSJNNTQ0LjUgMTA0aDAuMCIgLz4KICAgICAgICAgICAgPHBhdGggZD0iTTIzOS4wIDEwNGgxMCIgLz4KICAgICAgICAgICAgPGc+CiAgICAgICAgICAgICA8cGF0aCBkPSJNMjQ5LjAgMTA0aDAuMCIgLz4KICAgICAgICAgICAgIDxwYXRoIGQ9Ik01MzQuNSAxMDRoMC4wIiAvPgogICAgICAgICAgICAgPGc+CiAgICAgICAgICAgICAgPHBhdGggZD0iTTI0OS4wIDEwNGgwLjAiIC8+CiAgICAgICAgICAgICAgPHBhdGggZD0iTTM4NS41IDEwNGgwLjAiIC8+CiAgICAgICAgICAgICAgPHBhdGggZD0iTTI0OS4wIDEwNGExMCAxMCAwIDAgMCAxMCAtMTB2MGExMCAxMCAwIDAgMSAxMCAtMTAiIC8+CiAgICAgICAgICAgICAgPGc+CiAgICAgICAgICAgICAgIDxwYXRoIGQ9Ik0yNjkuMCA4NGg5Ni41IiAvPgogICAgICAgICAgICAgIDwvZz4KICAgICAgICAgICAgICA8cGF0aCBkPSJNMzY1LjUgODRhMTAgMTAgMCAwIDEgMTAgMTB2MGExMCAxMCAwIDAgMCAxMCAxMCIgLz4KICAgICAgICAgICAgICA8cGF0aCBkPSJNMjQ5LjAgMTA0aDIwIiAvPgogICAgICAgICAgICAgIDxnIGNsYXNzPSJub24tdGVybWluYWwiPgogICAgICAgICAgICAgICA8cGF0aCBkPSJNMjY5LjAgMTA0aDAuMCIgLz4KICAgICAgICAgICAgICAgPHBhdGggZD0iTTM2NS41IDEwNGgwLjAiIC8+CiAgICAgICAgICAgICAgIDxyZWN0IGhlaWdodD0iMjIiIHdpZHRoPSI5Ni41IiB4PSIyNjkiIHk9IjkzIiAvPgogICAgICAgICAgICAgICA8dGV4dCB4PSIzMTcuMjUiIHk9IjEwOCI+Y29tbWEtd3NwPC90ZXh0PgogICAgICAgICAgICAgIDwvZz4KICAgICAgICAgICAgICA8cGF0aCBkPSJNMzY1LjUgMTA0aDIwIiAvPgogICAgICAgICAgICAgPC9nPgogICAgICAgICAgICAgPHBhdGggZD0iTTM4NS41IDEwNGgxMCIgLz4KICAgICAgICAgICAgIDxnIGNsYXNzPSJub24tdGVybWluYWwiPgogICAgICAgICAgICAgIDxwYXRoIGQ9Ik0zOTUuNSAxMDRoMC4wIiAvPgogICAgICAgICAgICAgIDxwYXRoIGQ9Ik01MzQuNSAxMDRoMC4wIiAvPgogICAgICAgICAgICAgIDxyZWN0IGhlaWdodD0iMjIiIHdpZHRoPSIxMzkiIHg9IjM5NS41IiB5PSI5MyIgLz4KICAgICAgICAgICAgICA8dGV4dCB4PSI0NjUiIHk9IjEwOCI+Jmx0O251bWJlci10b2tlbiZndDs8L3RleHQ+CiAgICAgICAgICAgICA8L2c+CiAgICAgICAgICAgIDwvZz4KICAgICAgICAgICAgPHBhdGggZD0iTTUzNC41IDEwNGgxMCIgLz4KICAgICAgICAgICAgPHBhdGggZD0iTTI0OS4wIDEwNGExMCAxMCAwIDAgMCAtMTAgMTB2N2ExMCAxMCAwIDAgMCAxMCAxMCIgLz4KICAgICAgICAgICAgPGcgY2xhc3M9Im5vbi10ZXJtaW5hbCI+CiAgICAgICAgICAgICA8cGF0aCBkPSJNMjQ5LjAgMTMxaDEzNC4yNSIgLz4KICAgICAgICAgICAgIDxwYXRoIGQ9Ik00MDAuMjUgMTMxaDEzNC4yNSIgLz4KICAgICAgICAgICAgIDx0ZXh0IGNsYXNzPSJjb21tZW50IiB4PSIzOTEuNzUiIHk9IjEzNiI+NDwvdGV4dD4KICAgICAgICAgICAgPC9nPgogICAgICAgICAgICA8cGF0aCBkPSJNNTM0LjUgMTMxYTEwIDEwIDAgMCAwIDEwIC0xMHYtN2ExMCAxMCAwIDAgMCAtMTAgLTEwIiAvPgogICAgICAgICAgIDwvZz4KICAgICAgICAgICA8cGF0aCBkPSJNNTQ0LjUgMTA0aDIwIiAvPgogICAgICAgICAgPC9nPgogICAgICAgICA8L2c+CiAgICAgICAgIDxwYXRoIGQ9Ik01NzQuNSAxMDRhMTAgMTAgMCAwIDEgMTAgMTB2MjNhMTAgMTAgMCAwIDEgLTEwIDEwaC01MTQuNWExMCAxMCAwIDAgMCAtMTAgMTB2OGExMCAxMCAwIDAgMCAxMCAxMCIgLz4KICAgICAgICAgPGc+CiAgICAgICAgICA8cGF0aCBkPSJNNjAuMCAxNzVoMTg1LjI1IiAvPgogICAgICAgICAgPHBhdGggZD0iTTM4OS4yNSAxNzVoMTg1LjI1IiAvPgogICAgICAgICAgPGc+CiAgICAgICAgICAgPHBhdGggZD0iTTI0NS4yNSAxNzVoMC4wIiAvPgogICAgICAgICAgIDxwYXRoIGQ9Ik0zNTAuNzUgMTc1aDAuMCIgLz4KICAgICAgICAgICA8cGF0aCBkPSJNMjQ1LjI1IDE3NWExMCAxMCAwIDAgMCAxMCAtMTB2MGExMCAxMCAwIDAgMSAxMCAtMTAiIC8+CiAgICAgICAgICAgPGc+CiAgICAgICAgICAgIDxwYXRoIGQ9Ik0yNjUuMjUgMTU1aDY1LjUiIC8+CiAgICAgICAgICAgPC9nPgogICAgICAgICAgIDxwYXRoIGQ9Ik0zMzAuNzUgMTU1YTEwIDEwIDAgMCAxIDEwIDEwdjBhMTAgMTAgMCAwIDAgMTAgMTAiIC8+CiAgICAgICAgICAgPHBhdGggZD0iTTI0NS4yNSAxNzVoMjAiIC8+CiAgICAgICAgICAgPGc+CiAgICAgICAgICAgIDxwYXRoIGQ9Ik0yNjUuMjUgMTc1aDAuMCIgLz4KICAgICAgICAgICAgPHBhdGggZD0iTTMzMC43NSAxNzVoMC4wIiAvPgogICAgICAgICAgICA8cGF0aCBkPSJNMjY1LjI1IDE3NWgxMCIgLz4KICAgICAgICAgICAgPGcgY2xhc3M9Im5vbi10ZXJtaW5hbCI+CiAgICAgICAgICAgICA8cGF0aCBkPSJNMjc1LjI1IDE3NWgwLjAiIC8+CiAgICAgICAgICAgICA8cGF0aCBkPSJNMzIwLjc1IDE3NWgwLjAiIC8+CiAgICAgICAgICAgICA8cmVjdCBoZWlnaHQ9IjIyIiB3aWR0aD0iNDUuNSIgeD0iMjc1LjI1IiB5PSIxNjQiIC8+CiAgICAgICAgICAgICA8dGV4dCB4PSIyOTgiIHk9IjE3OSI+d3NwPC90ZXh0PgogICAgICAgICAgICA8L2c+CiAgICAgICAgICAgIDxwYXRoIGQ9Ik0zMjAuNzUgMTc1aDEwIiAvPgogICAgICAgICAgICA8cGF0aCBkPSJNMjc1LjI1IDE3NWExMCAxMCAwIDAgMCAtMTAgMTB2MGExMCAxMCAwIDAgMCAxMCAxMCIgLz4KICAgICAgICAgICAgPGc+CiAgICAgICAgICAgICA8cGF0aCBkPSJNMjc1LjI1IDE5NWg0NS41IiAvPgogICAgICAgICAgICA8L2c+CiAgICAgICAgICAgIDxwYXRoIGQ9Ik0zMjAuNzUgMTk1YTEwIDEwIDAgMCAwIDEwIC0xMHYwYTEwIDEwIDAgMCAwIC0xMCAtMTAiIC8+CiAgICAgICAgICAgPC9nPgogICAgICAgICAgIDxwYXRoIGQ9Ik0zMzAuNzUgMTc1aDIwIiAvPgogICAgICAgICAgPC9nPgogICAgICAgICAgPHBhdGggZD0iTTM1MC43NSAxNzVoMTAiIC8+CiAgICAgICAgICA8ZyBjbGFzcz0idGVybWluYWwiPgogICAgICAgICAgIDxwYXRoIGQ9Ik0zNjAuNzUgMTc1aDAuMCIgLz4KICAgICAgICAgICA8cGF0aCBkPSJNMzg5LjI1IDE3NWgwLjAiIC8+CiAgICAgICAgICAgPHJlY3QgaGVpZ2h0PSIyMiIgcng9IjEwIiByeT0iMTAiIHdpZHRoPSIyOC41IiB4PSIzNjAuNzUiIHk9IjE2NCIgLz4KICAgICAgICAgICA8dGV4dCB4PSIzNzUiIHk9IjE3OSI+KTwvdGV4dD4KICAgICAgICAgIDwvZz4KICAgICAgICAgPC9nPgogICAgICAgICA8cGF0aCBkPSJNNTc0LjUgMTc1aDEwIiAvPgogICAgICAgICA8cGF0aCBkPSJNNTg0LjUgMTc1aDAuMCIgLz4KICAgICAgICA8L2c+CiAgICAgICAgPHBhdGggZD0iTTU4NC41IDE3NWgxMCIgLz4KICAgICAgICA8cGF0aCBkPSJNIDU5NC41IDE3NSBoIDIwIG0gLTEwIC0xMCB2IDIwIG0gMTAgLTIwIHYgMjAiIC8+CiAgICAgICA8L2c+CiAgICAgIDwvc3ZnPg==)
 :::

transform

: matrix
 | translate
 | scale
 | rotate
 | skewX
 | skewY

: ::: railroad
 !(data:image/svg+xml;base64,PHN2ZyBjbGFzcz0icmFpbHJvYWQtZGlhZ3JhbSIgaGVpZ2h0PSIyMTIiIHZpZXdib3g9IjAgMCAyMTYuNSAyMTIiIHdpZHRoPSIyMTYuNSI+CiAgICAgICA8ZyB0cmFuc2Zvcm09InRyYW5zbGF0ZSguNSAuNSkiPgogICAgICAgIDxnPgogICAgICAgICA8cGF0aCBkPSJNMjAgMjF2MjBtMTAgLTIwdjIwbS0xMCAtMTBoMjAiIC8+CiAgICAgICAgPC9nPgogICAgICAgIDxnPgogICAgICAgICA8cGF0aCBkPSJNNDAgMzFoMC4wIiAvPgogICAgICAgICA8cGF0aCBkPSJNMTc2LjUgMzFoMC4wIiAvPgogICAgICAgICA8cGF0aCBkPSJNNDAuMCAzMWgyMCIgLz4KICAgICAgICAgPGcgY2xhc3M9Im5vbi10ZXJtaW5hbCI+CiAgICAgICAgICA8cGF0aCBkPSJNNjAuMCAzMWgwLjAiIC8+CiAgICAgICAgICA8cGF0aCBkPSJNMTU2LjUgMzFoMC4wIiAvPgogICAgICAgICAgPHJlY3QgaGVpZ2h0PSIyMiIgd2lkdGg9Ijk2LjUiIHg9IjYwIiB5PSIyMCIgLz4KICAgICAgICAgIDx0ZXh0IHg9IjEwOC4yNSIgeT0iMzUiPnRyYW5zbGF0ZTwvdGV4dD4KICAgICAgICAgPC9nPgogICAgICAgICA8cGF0aCBkPSJNMTU2LjUgMzFoMjAiIC8+CiAgICAgICAgIDxwYXRoIGQ9Ik00MC4wIDMxYTEwIDEwIDAgMCAxIDEwIDEwdjEwYTEwIDEwIDAgMCAwIDEwIDEwIiAvPgogICAgICAgICA8ZyBjbGFzcz0ibm9uLXRlcm1pbmFsIj4KICAgICAgICAgIDxwYXRoIGQ9Ik02MC4wIDYxaDE3LjAiIC8+CiAgICAgICAgICA8cGF0aCBkPSJNMTM5LjUgNjFoMTcuMCIgLz4KICAgICAgICAgIDxyZWN0IGhlaWdodD0iMjIiIHdpZHRoPSI2Mi41IiB4PSI3NyIgeT0iNTAiIC8+CiAgICAgICAgICA8dGV4dCB4PSIxMDguMjUiIHk9IjY1Ij5zY2FsZTwvdGV4dD4KICAgICAgICAgPC9nPgogICAgICAgICA8cGF0aCBkPSJNMTU2LjUgNjFhMTAgMTAgMCAwIDAgMTAgLTEwdi0xMGExMCAxMCAwIDAgMSAxMCAtMTAiIC8+CiAgICAgICAgIDxwYXRoIGQ9Ik00MC4wIDMxYTEwIDEwIDAgMCAxIDEwIDEwdjQwYTEwIDEwIDAgMCAwIDEwIDEwIiAvPgogICAgICAgICA8ZyBjbGFzcz0ibm9uLXRlcm1pbmFsIj4KICAgICAgICAgIDxwYXRoIGQ9Ik02MC4wIDkxaDEyLjc1IiAvPgogICAgICAgICAgPHBhdGggZD0iTTE0My43NSA5MWgxMi43NSIgLz4KICAgICAgICAgIDxyZWN0IGhlaWdodD0iMjIiIHdpZHRoPSI3MSIgeD0iNzIuNzUiIHk9IjgwIiAvPgogICAgICAgICAgPHRleHQgeD0iMTA4LjI1IiB5PSI5NSI+cm90YXRlPC90ZXh0PgogICAgICAgICA8L2c+CiAgICAgICAgIDxwYXRoIGQ9Ik0xNTYuNSA5MWExMCAxMCAwIDAgMCAxMCAtMTB2LTQwYTEwIDEwIDAgMCAxIDEwIC0xMCIgLz4KICAgICAgICAgPHBhdGggZD0iTTQwLjAgMzFhMTAgMTAgMCAwIDEgMTAgMTB2NzBhMTAgMTAgMCAwIDAgMTAgMTAiIC8+CiAgICAgICAgIDxnIGNsYXNzPSJub24tdGVybWluYWwiPgogICAgICAgICAgPHBhdGggZD0iTTYwLjAgMTIxaDE3LjAiIC8+CiAgICAgICAgICA8cGF0aCBkPSJNMTM5LjUgMTIxaDE3LjAiIC8+CiAgICAgICAgICA8cmVjdCBoZWlnaHQ9IjIyIiB3aWR0aD0iNjIuNSIgeD0iNzciIHk9IjExMCIgLz4KICAgICAgICAgIDx0ZXh0IHg9IjEwOC4yNSIgeT0iMTI1Ij5za2V3WDwvdGV4dD4KICAgICAgICAgPC9nPgogICAgICAgICA8cGF0aCBkPSJNMTU2LjUgMTIxYTEwIDEwIDAgMCAwIDEwIC0xMHYtNzBhMTAgMTAgMCAwIDEgMTAgLTEwIiAvPgogICAgICAgICA8cGF0aCBkPSJNNDAuMCAzMWExMCAxMCAwIDAgMSAxMCAxMHYxMDBhMTAgMTAgMCAwIDAgMTAgMTAiIC8+CiAgICAgICAgIDxnIGNsYXNzPSJub24tdGVybWluYWwiPgogICAgICAgICAgPHBhdGggZD0iTTYwLjAgMTUxaDE3LjAiIC8+CiAgICAgICAgICA8cGF0aCBkPSJNMTM5LjUgMTUxaDE3LjAiIC8+CiAgICAgICAgICA8cmVjdCBoZWlnaHQ9IjIyIiB3aWR0aD0iNjIuNSIgeD0iNzciIHk9IjE0MCIgLz4KICAgICAgICAgIDx0ZXh0IHg9IjEwOC4yNSIgeT0iMTU1Ij5za2V3WTwvdGV4dD4KICAgICAgICAgPC9nPgogICAgICAgICA8cGF0aCBkPSJNMTU2LjUgMTUxYTEwIDEwIDAgMCAwIDEwIC0xMHYtMTAwYTEwIDEwIDAgMCAxIDEwIC0xMCIgLz4KICAgICAgICAgPHBhdGggZD0iTTQwLjAgMzFhMTAgMTAgMCAwIDEgMTAgMTB2MTMwYTEwIDEwIDAgMCAwIDEwIDEwIiAvPgogICAgICAgICA8ZyBjbGFzcz0ibm9uLXRlcm1pbmFsIj4KICAgICAgICAgIDxwYXRoIGQ9Ik02MC4wIDE4MWgxMi43NSIgLz4KICAgICAgICAgIDxwYXRoIGQ9Ik0xNDMuNzUgMTgxaDEyLjc1IiAvPgogICAgICAgICAgPHJlY3QgaGVpZ2h0PSIyMiIgd2lkdGg9IjcxIiB4PSI3Mi43NSIgeT0iMTcwIiAvPgogICAgICAgICAgPHRleHQgeD0iMTA4LjI1IiB5PSIxODUiPm1hdHJpeDwvdGV4dD4KICAgICAgICAgPC9nPgogICAgICAgICA8cGF0aCBkPSJNMTU2LjUgMTgxYTEwIDEwIDAgMCAwIDEwIC0xMHYtMTMwYTEwIDEwIDAgMCAxIDEwIC0xMCIgLz4KICAgICAgICA8L2c+CiAgICAgICAgPHBhdGggZD0iTSAxNzYuNSAzMSBoIDIwIG0gLTEwIC0xMCB2IDIwIG0gMTAgLTIwIHYgMjAiIC8+CiAgICAgICA8L2c+CiAgICAgIDwvc3ZnPg==)
 :::

transforms

: transform
 | transform comma-wsp? transforms

: ::: railroad
 !(data:image/svg+xml;base64,PHN2ZyBjbGFzcz0icmFpbHJvYWQtZGlhZ3JhbSIgaGVpZ2h0PSIxMDEiIHZpZXdib3g9IjAgMCA0NzguMCAxMDEiIHdpZHRoPSI0NzguMCI+CiAgICAgICA8ZyB0cmFuc2Zvcm09InRyYW5zbGF0ZSguNSAuNSkiPgogICAgICAgIDxnPgogICAgICAgICA8cGF0aCBkPSJNMjAgMjF2MjBtMTAgLTIwdjIwbS0xMCAtMTBoMjAiIC8+CiAgICAgICAgPC9nPgogICAgICAgIDxnPgogICAgICAgICA8cGF0aCBkPSJNNDAgMzFoMC4wIiAvPgogICAgICAgICA8cGF0aCBkPSJNNDM4LjAgMzFoMC4wIiAvPgogICAgICAgICA8cGF0aCBkPSJNNDAuMCAzMWgyMCIgLz4KICAgICAgICAgPGcgY2xhc3M9Im5vbi10ZXJtaW5hbCI+CiAgICAgICAgICA8cGF0aCBkPSJNNjAuMCAzMWgxMzAuNzUiIC8+CiAgICAgICAgICA8cGF0aCBkPSJNMjg3LjI1IDMxaDEzMC43NSIgLz4KICAgICAgICAgIDxyZWN0IGhlaWdodD0iMjIiIHdpZHRoPSI5Ni41IiB4PSIxOTAuNzUiIHk9IjIwIiAvPgogICAgICAgICAgPHRleHQgeD0iMjM5IiB5PSIzNSI+dHJhbnNmb3JtPC90ZXh0PgogICAgICAgICA8L2c+CiAgICAgICAgIDxwYXRoIGQ9Ik00MTguMCAzMWgyMCIgLz4KICAgICAgICAgPHBhdGggZD0iTTQwLjAgMzFhMTAgMTAgMCAwIDEgMTAgMTB2MTlhMTAgMTAgMCAwIDAgMTAgMTAiIC8+CiAgICAgICAgIDxnPgogICAgICAgICAgPHBhdGggZD0iTTYwLjAgNzBoMC4wIiAvPgogICAgICAgICAgPHBhdGggZD0iTTQxOC4wIDcwaDAuMCIgLz4KICAgICAgICAgIDxnIGNsYXNzPSJub24tdGVybWluYWwiPgogICAgICAgICAgIDxwYXRoIGQ9Ik02MC4wIDcwaDAuMCIgLz4KICAgICAgICAgICA8cGF0aCBkPSJNMTU2LjUgNzBoMC4wIiAvPgogICAgICAgICAgIDxyZWN0IGhlaWdodD0iMjIiIHdpZHRoPSI5Ni41IiB4PSI2MCIgeT0iNTkiIC8+CiAgICAgICAgICAgPHRleHQgeD0iMTA4LjI1IiB5PSI3NCI+dHJhbnNmb3JtPC90ZXh0PgogICAgICAgICAgPC9nPgogICAgICAgICAgPHBhdGggZD0iTTE1Ni41IDcwaDEwIiAvPgogICAgICAgICAgPGc+CiAgICAgICAgICAgPHBhdGggZD0iTTE2Ni41IDcwaDAuMCIgLz4KICAgICAgICAgICA8cGF0aCBkPSJNMzAzLjAgNzBoMC4wIiAvPgogICAgICAgICAgIDxwYXRoIGQ9Ik0xNjYuNSA3MGExMCAxMCAwIDAgMCAxMCAtMTB2MGExMCAxMCAwIDAgMSAxMCAtMTAiIC8+CiAgICAgICAgICAgPGc+CiAgICAgICAgICAgIDxwYXRoIGQ9Ik0xODYuNSA1MGg5Ni41IiAvPgogICAgICAgICAgIDwvZz4KICAgICAgICAgICA8cGF0aCBkPSJNMjgzLjAgNTBhMTAgMTAgMCAwIDEgMTAgMTB2MGExMCAxMCAwIDAgMCAxMCAxMCIgLz4KICAgICAgICAgICA8cGF0aCBkPSJNMTY2LjUgNzBoMjAiIC8+CiAgICAgICAgICAgPGcgY2xhc3M9Im5vbi10ZXJtaW5hbCI+CiAgICAgICAgICAgIDxwYXRoIGQ9Ik0xODYuNSA3MGgwLjAiIC8+CiAgICAgICAgICAgIDxwYXRoIGQ9Ik0yODMuMCA3MGgwLjAiIC8+CiAgICAgICAgICAgIDxyZWN0IGhlaWdodD0iMjIiIHdpZHRoPSI5Ni41IiB4PSIxODYuNSIgeT0iNTkiIC8+CiAgICAgICAgICAgIDx0ZXh0IHg9IjIzNC43NSIgeT0iNzQiPmNvbW1hLXdzcDwvdGV4dD4KICAgICAgICAgICA8L2c+CiAgICAgICAgICAgPHBhdGggZD0iTTI4My4wIDcwaDIwIiAvPgogICAgICAgICAgPC9nPgogICAgICAgICAgPHBhdGggZD0iTTMwMy4wIDcwaDEwIiAvPgogICAgICAgICAgPGcgY2xhc3M9Im5vbi10ZXJtaW5hbCI+CiAgICAgICAgICAgPHBhdGggZD0iTTMxMy4wIDcwaDAuMCIgLz4KICAgICAgICAgICA8cGF0aCBkPSJNNDE4LjAgNzBoMC4wIiAvPgogICAgICAgICAgIDxyZWN0IGhlaWdodD0iMjIiIHdpZHRoPSIxMDUiIHg9IjMxMyIgeT0iNTkiIC8+CiAgICAgICAgICAgPHRleHQgeD0iMzY1LjUiIHk9Ijc0Ij50cmFuc2Zvcm1zPC90ZXh0PgogICAgICAgICAgPC9nPgogICAgICAgICA8L2c+CiAgICAgICAgIDxwYXRoIGQ9Ik00MTguMCA3MGExMCAxMCAwIDAgMCAxMCAtMTB2LTE5YTEwIDEwIDAgMCAxIDEwIC0xMCIgLz4KICAgICAgICA8L2c+CiAgICAgICAgPHBhdGggZD0iTSA0MzguMCAzMSBoIDIwIG0gLTEwIC0xMCB2IDIwIG0gMTAgLTIwIHYgMjAiIC8+CiAgICAgICA8L2c+CiAgICAgIDwvc3ZnPg==)
 :::

transform-list

: wsp* transforms? wsp*

: ::: railroad
 !(data:image/svg+xml;base64,PHN2ZyBjbGFzcz0icmFpbHJvYWQtZGlhZ3JhbSIgaGVpZ2h0PSI4MCIgdmlld2JveD0iMCAwIDQzNi4wIDgwIiB3aWR0aD0iNDM2LjAiPgogICAgICAgPGcgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoLjUgLjUpIj4KICAgICAgICA8Zz4KICAgICAgICAgPHBhdGggZD0iTTIwIDMwdjIwbTEwIC0yMHYyMG0tMTAgLTEwaDIwIiAvPgogICAgICAgIDwvZz4KICAgICAgICA8Zz4KICAgICAgICAgPHBhdGggZD0iTTQwIDQwaDAuMCIgLz4KICAgICAgICAgPHBhdGggZD0iTTE0NS41IDQwaDAuMCIgLz4KICAgICAgICAgPHBhdGggZD0iTTQwLjAgNDBhMTAgMTAgMCAwIDAgMTAgLTEwdjBhMTAgMTAgMCAwIDEgMTAgLTEwIiAvPgogICAgICAgICA8Zz4KICAgICAgICAgIDxwYXRoIGQ9Ik02MC4wIDIwaDY1LjUiIC8+CiAgICAgICAgIDwvZz4KICAgICAgICAgPHBhdGggZD0iTTEyNS41IDIwYTEwIDEwIDAgMCAxIDEwIDEwdjBhMTAgMTAgMCAwIDAgMTAgMTAiIC8+CiAgICAgICAgIDxwYXRoIGQ9Ik00MC4wIDQwaDIwIiAvPgogICAgICAgICA8Zz4KICAgICAgICAgIDxwYXRoIGQ9Ik02MC4wIDQwaDAuMCIgLz4KICAgICAgICAgIDxwYXRoIGQ9Ik0xMjUuNSA0MGgwLjAiIC8+CiAgICAgICAgICA8cGF0aCBkPSJNNjAuMCA0MGgxMCIgLz4KICAgICAgICAgIDxnIGNsYXNzPSJub24tdGVybWluYWwiPgogICAgICAgICAgIDxwYXRoIGQ9Ik03MC4wIDQwaDAuMCIgLz4KICAgICAgICAgICA8cGF0aCBkPSJNMTE1LjUgNDBoMC4wIiAvPgogICAgICAgICAgIDxyZWN0IGhlaWdodD0iMjIiIHdpZHRoPSI0NS41IiB4PSI3MCIgeT0iMjkiIC8+CiAgICAgICAgICAgPHRleHQgeD0iOTIuNzUiIHk9IjQ0Ij53c3A8L3RleHQ+CiAgICAgICAgICA8L2c+CiAgICAgICAgICA8cGF0aCBkPSJNMTE1LjUgNDBoMTAiIC8+CiAgICAgICAgICA8cGF0aCBkPSJNNzAuMCA0MGExMCAxMCAwIDAgMCAtMTAgMTB2MGExMCAxMCAwIDAgMCAxMCAxMCIgLz4KICAgICAgICAgIDxnPgogICAgICAgICAgIDxwYXRoIGQ9Ik03MC4wIDYwaDQ1LjUiIC8+CiAgICAgICAgICA8L2c+CiAgICAgICAgICA8cGF0aCBkPSJNMTE1LjUgNjBhMTAgMTAgMCAwIDAgMTAgLTEwdjBhMTAgMTAgMCAwIDAgLTEwIC0xMCIgLz4KICAgICAgICAgPC9nPgogICAgICAgICA8cGF0aCBkPSJNMTI1LjUgNDBoMjAiIC8+CiAgICAgICAgPC9nPgogICAgICAgIDxnPgogICAgICAgICA8cGF0aCBkPSJNMTQ1LjUgNDBoMC4wIiAvPgogICAgICAgICA8cGF0aCBkPSJNMjkwLjUgNDBoMC4wIiAvPgogICAgICAgICA8cGF0aCBkPSJNMTQ1LjUgNDBhMTAgMTAgMCAwIDAgMTAgLTEwdjBhMTAgMTAgMCAwIDEgMTAgLTEwIiAvPgogICAgICAgICA8Zz4KICAgICAgICAgIDxwYXRoIGQ9Ik0xNjUuNSAyMGgxMDUuMCIgLz4KICAgICAgICAgPC9nPgogICAgICAgICA8cGF0aCBkPSJNMjcwLjUgMjBhMTAgMTAgMCAwIDEgMTAgMTB2MGExMCAxMCAwIDAgMCAxMCAxMCIgLz4KICAgICAgICAgPHBhdGggZD0iTTE0NS41IDQwaDIwIiAvPgogICAgICAgICA8ZyBjbGFzcz0ibm9uLXRlcm1pbmFsIj4KICAgICAgICAgIDxwYXRoIGQ9Ik0xNjUuNSA0MGgwLjAiIC8+CiAgICAgICAgICA8cGF0aCBkPSJNMjcwLjUgNDBoMC4wIiAvPgogICAgICAgICAgPHJlY3QgaGVpZ2h0PSIyMiIgd2lkdGg9IjEwNSIgeD0iMTY1LjUiIHk9IjI5IiAvPgogICAgICAgICAgPHRleHQgeD0iMjE4IiB5PSI0NCI+dHJhbnNmb3JtczwvdGV4dD4KICAgICAgICAgPC9nPgogICAgICAgICA8cGF0aCBkPSJNMjcwLjUgNDBoMjAiIC8+CiAgICAgICAgPC9nPgogICAgICAgIDxnPgogICAgICAgICA8cGF0aCBkPSJNMjkwLjUgNDBoMC4wIiAvPgogICAgICAgICA8cGF0aCBkPSJNMzk2LjAgNDBoMC4wIiAvPgogICAgICAgICA8cGF0aCBkPSJNMjkwLjUgNDBhMTAgMTAgMCAwIDAgMTAgLTEwdjBhMTAgMTAgMCAwIDEgMTAgLTEwIiAvPgogICAgICAgICA8Zz4KICAgICAgICAgIDxwYXRoIGQ9Ik0zMTAuNSAyMGg2NS41IiAvPgogICAgICAgICA8L2c+CiAgICAgICAgIDxwYXRoIGQ9Ik0zNzYuMCAyMGExMCAxMCAwIDAgMSAxMCAxMHYwYTEwIDEwIDAgMCAwIDEwIDEwIiAvPgogICAgICAgICA8cGF0aCBkPSJNMjkwLjUgNDBoMjAiIC8+CiAgICAgICAgIDxnPgogICAgICAgICAgPHBhdGggZD0iTTMxMC41IDQwaDAuMCIgLz4KICAgICAgICAgIDxwYXRoIGQ9Ik0zNzYuMCA0MGgwLjAiIC8+CiAgICAgICAgICA8cGF0aCBkPSJNMzEwLjUgNDBoMTAiIC8+CiAgICAgICAgICA8ZyBjbGFzcz0ibm9uLXRlcm1pbmFsIj4KICAgICAgICAgICA8cGF0aCBkPSJNMzIwLjUgNDBoMC4wIiAvPgogICAgICAgICAgIDxwYXRoIGQ9Ik0zNjYuMCA0MGgwLjAiIC8+CiAgICAgICAgICAgPHJlY3QgaGVpZ2h0PSIyMiIgd2lkdGg9IjQ1LjUiIHg9IjMyMC41IiB5PSIyOSIgLz4KICAgICAgICAgICA8dGV4dCB4PSIzNDMuMjUiIHk9IjQ0Ij53c3A8L3RleHQ+CiAgICAgICAgICA8L2c+CiAgICAgICAgICA8cGF0aCBkPSJNMzY2LjAgNDBoMTAiIC8+CiAgICAgICAgICA8cGF0aCBkPSJNMzIwLjUgNDBhMTAgMTAgMCAwIDAgLTEwIDEwdjBhMTAgMTAgMCAwIDAgMTAgMTAiIC8+CiAgICAgICAgICA8Zz4KICAgICAgICAgICA8cGF0aCBkPSJNMzIwLjUgNjBoNDUuNSIgLz4KICAgICAgICAgIDwvZz4KICAgICAgICAgIDxwYXRoIGQ9Ik0zNjYuMCA2MGExMCAxMCAwIDAgMCAxMCAtMTB2MGExMCAxMCAwIDAgMCAtMTAgLTEwIiAvPgogICAgICAgICA8L2c+CiAgICAgICAgIDxwYXRoIGQ9Ik0zNzYuMCA0MGgyMCIgLz4KICAgICAgICA8L2c+CiAgICAgICAgPHBhdGggZD0iTSAzOTYuMCA0MCBoIDIwIG0gLTEwIC0xMCB2IDIwIG0gMTAgLTIwIHYgMjAiIC8+CiAgICAgICA8L2c+CiAgICAgIDwvc3ZnPg==)
 :::

### 6.3. SVG transform functions

SVG transform functions of the
[transform](https://www.w3.org/TR/SVG11/coords.html#TransformAttribute),
[`patternTransform`](https://www.w3.org/TR/SVG11/pservers.html#PatternElementPatternTransformAttribute),
[`gradientTransform`](https://www.w3.org/TR/SVG11/pservers.html#LinearGradientElementGradientTransformAttribute) attributes defined by the syntax above are
mapped to CSS
[\<transform-function\>](#typedef-transform-function)s as follows:

SVG transform function

CSS
[\<transform-function\>](#typedef-transform-function)

Additional notes

[translate](#svg-translate)

[\<translate()\>](#funcdef-transform-translate)

Number values interpreted as CSS
[\<length\>](https://drafts.csswg.org/css-values-4/#length-value) types with
[px](https://drafts.csswg.org/css-values-4/#px) units.

[scale](#svg-scale)

[\<scale()\>](#funcdef-transform-scale)

[rotate](#svg-rotate)

[\<rotate()\>](#funcdef-transform-rotate)

Only single value version. Number value interpreted as CSS
[\<angle\>](https://drafts.csswg.org/css-values-4/#angle-value) type with
[deg](https://drafts.csswg.org/css-values-4/#deg) unit.

[skewX](#svg-skewX)

[\<skewX()\>](#funcdef-transform-skewx)

Number value interpreted as CSS
[\<angle\>](https://drafts.csswg.org/css-values-4/#angle-value) type with
[deg](https://drafts.csswg.org/css-values-4/#deg) unit.

[skewY](#svg-skewY)

[\<skewY()\>](#funcdef-transform-skewy)

Number value interpreted as CSS
[\<angle\>](https://drafts.csswg.org/css-values-4/#angle-value) type with
[deg](https://drafts.csswg.org/css-values-4/#deg) unit.

[matrix](#svg-matrix)

[\<matrix()\>](#funcdef-transform-matrix)

The SVG transform function [rotate](#svg-rotate) with 3 values can not
be mapped to a corresponding CSS
[\<transform-function\>](#typedef-transform-function). The 2 optional number values
represent a horizontal translation value [cx] followed by a
vertical translation value [cy]. Both number values get
interpreted as CSS
[\<length\>](https://drafts.csswg.org/css-values-4/#length-value) types with
[px](https://drafts.csswg.org/css-values-4/#px) units and define the origin for rotation. The
behavior is equivalent to an initial translation by [cx],
[cy], a rotation defined by the first number value interpreted as
[\<angle\>](https://drafts.csswg.org/css-values-4/#angle-value) type with
[deg](https://drafts.csswg.org/css-values-4/#deg) unit followed by a translation by [-cx],
[-cy].

A
[transform](https://www.w3.org/TR/SVG11/coords.html#TransformAttribute) attribute can be the start or end value of a
CSS Transition. If the value of a
[transform] attribute is the start or end
value of a CSS Transition and the SVG [transform
list](#svg-transform-list) contains at least one [rotate](#svg-rotate)
transform function with 3 values, the individual SVG transform functions
must get [post-multiplied](#post-multiplied) and the resulting matrix must get mapped to a
[\<matrix()\>](#funcdef-transform-matrix) CSS
[\<transform-function\>](#typedef-transform-function) and used as start/end value of the
CSS Transition.

### 6.4. User coordinate space

For the
[`pattern`](https://w3c.github.io/svgwg/svg2-draft/pservers.html#elementdef-pattern) element, the
[`patternTransform`](https://www.w3.org/TR/SVG11/pservers.html#PatternElementPatternTransformAttribute) attribute and
[transform](#propdef-transform) property define an additional
transformation in the pattern coordinate system. See
[`patternUnits`](https://www.w3.org/TR/SVG/pservers.html#PatternElementPatternUnitsAttribute) attribute for details
[\[SVG2\]](#biblio-svg2 "Scalable Vector Graphics (SVG) 2").

For the
[`linearGradient`](https://w3c.github.io/svgwg/svg2-draft/pservers.html#elementdef-linearGradient) and
[`radialGradient`](https://w3c.github.io/svgwg/svg2-draft/pservers.html#elementdef-radialGradient) elements, the
[`gradientTransform`](https://www.w3.org/TR/SVG11/pservers.html#LinearGradientElementGradientTransformAttribute) attribute and
[transform](#propdef-transform) property define an additional
transformation in the gradient coordinate system. See
[`gradientUnits`](https://www.w3.org/TR/SVG/pservers.html#LinearGradientElementGradientUnitsAttribute) attribute for details
[\[SVG2\]](#biblio-svg2 "Scalable Vector Graphics (SVG) 2").

For the
[`clipPath`](https://drafts.csswg.org/css-masking-1/#elementdef-clippath) element, the
[transform](https://www.w3.org/TR/SVG11/coords.html#TransformAttribute) attribute and
[transform](#propdef-transform) property define an additional
transformation in the clipping path coordinate space. See
[`clipPathUnits`](https://drafts.csswg.org/css-masking-1/#element-attrdef-clippath-clippathunits) attribute for details
[\[CSS-MASKING\]](#biblio-css-masking "CSS Masking Module Level 1").

For all other [transformable
elements](#transformable-element) the
[transform](https://www.w3.org/TR/SVG11/coords.html#TransformAttribute) attribute and
[transform](#propdef-transform) property define a transformation in the
current user coordinate system of the parent. All percentage values of
the [transform] attribute are relative to
the element's [reference box](#reference-box).

The
[transform-origin](#propdef-transform-origin) property on the pattern in the
following example specifies a [50%] translation of the origin in
the horizontal and vertical dimension. The
[transform](#propdef-transform) property specifies a translation as
well, but in absolute lengths.

``` highlight
<svg xmlns="http://www.w3.org/2000/svg">
 <style>
 pattern {
 transform: rotate(45deg);
 transform-origin: 50% 50%;
 }
 </style>

 <defs>
 <pattern id="pattern-1">
 <rect id="rect1" width="100" height="100" fill="blue" />
 </pattern>
 </defs>

 <rect width="200" height="200" fill="url(#pattern-1)" />
</svg>
```

An SVG
[`pattern`](https://w3c.github.io/svgwg/svg2-draft/pservers.html#elementdef-pattern) element doesn't have a bounding box. The [reference
box](#reference-box) of the
referencing
[`rect`](https://w3c.github.io/svgwg/svg2-draft/shapes.html#elementdef-rect) element is used instead to solve the relative
values of the
[transform-origin](#propdef-transform-origin) property. Therefore the point of
origin will get translated by 100 pixels temporarily to rotate the user
space of the
[`pattern`](https://w3c.github.io/svgwg/svg2-draft/pservers.html#elementdef-pattern) elements content.

### [6.5. ][SVG DOM interface for the [transform](https://www.w3.org/TR/SVG11/coords.html#TransformAttribute) attribute]
The SVG specification defines the
\"[SVGAnimatedTransformList](https://www.w3.org/TR/2011/REC-SVG11-20110816/coords.html#InterfaceSVGAnimatedTransformList)\"
interface in the SVG DOM to provide access to the animated and the base
value of the SVG
[transform](https://www.w3.org/TR/SVG11/coords.html#TransformAttribute),
[`gradientTransform`](https://www.w3.org/TR/SVG11/pservers.html#LinearGradientElementGradientTransformAttribute) and
[`patternTransform`](https://www.w3.org/TR/SVG11/pservers.html#PatternElementPatternTransformAttribute) attributes. To ensure backwards compatibility,
this API must still be supported by user agents.

[`baseVal`](https://w3c.github.io/svgwg/svg2-draft/coords.html#__svg__SVGAnimatedPreserveAspectRatio__baseVal) gives the author the possibility to access and modify
the values of the SVG
[transform](https://www.w3.org/TR/SVG11/coords.html#TransformAttribute),
[`patternTransform`](https://www.w3.org/TR/SVG11/pservers.html#PatternElementPatternTransformAttribute),
[`gradientTransform`](https://www.w3.org/TR/SVG11/pservers.html#LinearGradientElementGradientTransformAttribute) attributes. To provide the necessary backwards
compatibility to the SVG DOM,
[`baseVal`](https://w3c.github.io/svgwg/svg2-draft/coords.html#__svg__SVGAnimatedPreserveAspectRatio__baseVal) must reflect the values of this author style sheet. All
modifications to SVG DOM objects of
[`baseVal`](https://w3c.github.io/svgwg/svg2-draft/coords.html#__svg__SVGAnimatedPreserveAspectRatio__baseVal) must affect this author style sheet immediately.

[`animVal`](https://w3c.github.io/svgwg/svg2-draft/coords.html#__svg__SVGAnimatedPreserveAspectRatio__animVal) represents the computed style of the
[transform](#propdef-transform) property. Therefore it includes all
applied [CSS3 Transitions](https://www.w3.org/TR/css3-transitions/),
[CSS3 Animations](https://www.w3.org/TR/css3-animations/) or SVG
Animations if any of those are underway. The computed style and SVG DOM
objects of
[`animVal`](https://w3c.github.io/svgwg/svg2-draft/coords.html#__svg__SVGAnimatedPreserveAspectRatio__animVal) can not be modified.

## 7. The Transform Functions

The value of the
[transform](#propdef-transform) property is a list of
[\<transform-function\>]. The set of allowed transform
functions is given below. In the following functions, a
[\<zero\>](https://drafts.csswg.org/css-values-4/#zero-value) behaves the same as [0deg]
(\"unitless 0\" angles are preserved for legacy compat). A percentage
for horizontal translations is relative to the width of the [reference
box](#reference-box). A
percentage for vertical translations is relative to the height of the
[reference box].

### 7.1. 2D Transform Functions

[[matrix()] = matrix( [\<number\>](https://drafts.csswg.org/css-values-4/#number-value)[#{6}](https://drafts.csswg.org/css-values-4/#mult-comma) )]

: specifies a 2D transformation in the form of a [transformation
 matrix](#MatrixDefined) of the six values a, b, c, d, e, f.

[[translate()] = translate( [\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage) [,](https://drafts.csswg.org/css-values-4/#comb-comma) [\<length-percentage\>][?](https://drafts.csswg.org/css-values-4/#mult-opt) )]

: specifies a [2D translation](#TranslateDefined) by the vector \[tx,
 ty\], where tx is the first translation-value parameter and ty is
 the optional second translation-value parameter. If *\<ty\>* is not
 provided, ty has zero as a value.

[[translateX()] = translateX( [\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage) )]

: specifies a [translation](#TranslateDefined) by the given amount in
 the X direction.

[[translateY()] = translateY( [\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage) )]

: specifies a [translation](#TranslateDefined) by the given amount in
 the Y direction.

[[scale()] = scale( [\<number\>](https://drafts.csswg.org/css-values-4/#number-value) [,](https://drafts.csswg.org/css-values-4/#comb-comma) [\<number\>][?](https://drafts.csswg.org/css-values-4/#mult-opt) )]

: specifies a [2D scale](#ScaleDefined) operation by the \[sx,sy\]
 scaling vector described by the 2 parameters. If the second
 parameter is not provided, it takes a value equal to the first. For
 example, scale(1, 1) would leave an element unchanged, while
 scale(2, 2) would cause it to appear twice as long in both the X and
 Y axes, or four times its typical geometric size.

[[scaleX()] = scaleX( [\<number\>](https://drafts.csswg.org/css-values-4/#number-value) )]

: specifies a [2D scale](#ScaleDefined) operation using the \[sx,1\]
 scaling vector, where sx is given as the parameter.

[[scaleY()] = scaleY( [\<number\>](https://drafts.csswg.org/css-values-4/#number-value) )]

: specifies a [2D scale](#ScaleDefined) operation using the \[1,sy\]
 scaling vector, where sy is given as the parameter.

[[rotate()] = rotate( \[ [\<angle\>](https://drafts.csswg.org/css-values-4/#angle-value) [\|](https://drafts.csswg.org/css-values-4/#comb-one) [\<zero\>](https://drafts.csswg.org/css-values-4/#zero-value) \] )]

: specifies a [2D rotation](#RotateDefined) by the angle specified in
 the parameter about the origin of the element, as defined by the
 [transform-origin](#propdef-transform-origin) property. For example,
 [rotate(90deg)] would cause elements to appear rotated
 one-quarter of a turn in the clockwise direction.

[[skew()] = skew( \[ [\<angle\>](https://drafts.csswg.org/css-values-4/#angle-value) [\|](https://drafts.csswg.org/css-values-4/#comb-one) [\<zero\>](https://drafts.csswg.org/css-values-4/#zero-value) \] [,](https://drafts.csswg.org/css-values-4/#comb-comma) \[ [\<angle\>] [\|] [\<zero\>] \][?](https://drafts.csswg.org/css-values-4/#mult-opt) )]

: specifies a [2D skew](#SkewDefined) by \[ax,ay\] for X and Y. If the
 second parameter is not provided, it has a zero value.

[[skewX()] = skewX( \[ [\<angle\>](https://drafts.csswg.org/css-values-4/#angle-value) [\|](https://drafts.csswg.org/css-values-4/#comb-one) [\<zero\>](https://drafts.csswg.org/css-values-4/#zero-value) \] )]

: specifies a [2D skew transformation along the X axis](#SkewXDefined)
 by the given angle.

[[skewY()] = skewY( \[ [\<angle\>](https://drafts.csswg.org/css-values-4/#angle-value) [\|](https://drafts.csswg.org/css-values-4/#comb-one) [\<zero\>](https://drafts.csswg.org/css-values-4/#zero-value) \] )]

: specifies a [2D skew transformation along the Y axis](#SkewYDefined)
 by the given angle.

### 7.2. Transform function primitives and derivatives

Some transform functions can be represented by more generic transform
functions. These transform functions are called derived transform
functions, and the generic transform functions are called primitive
transform functions. Two-dimensional primitives and their derived
transform functions are:

[translate()](#funcdef-transform-translate)
: for
 [\<translateX()\>](#funcdef-transform-translatex),
 [\<translateY()\>](#funcdef-transform-translatey) and
 [\<translate()\>](#funcdef-transform-translate).

[scale()](#funcdef-transform-scale)
: for
 [\<scaleX()\>](#funcdef-transform-scalex),
 [\<scaleY()\>](#funcdef-transform-scaley) and
 [\<scale()\>](#funcdef-transform-scale).

## 8. The Transform Function Lists

If a list of
[\<transform-function\>](#typedef-transform-function)s is provided, then the net effect is
as if each transform function had been specified separately in the order
provided.

That is, in the absence of other styling that affects position and
dimensions, a nested set of transforms is equivalent to a single list of
transform functions, applied from the coordinate system of the ancestor
to the [local coordinate
system](#local-coordinate-system) of a given element. The resulting transform is the
matrix multiplication of the list of transforms.

For example,

``` highlight
<div style="transform: translate(-10px, -20px) scale(2) rotate(45deg)"/>
```

is functionally equivalent to:

``` highlight
<div style="transform: translate(-10px, -20px)" id="root">
 <div style="transform: scale(2)">
 <div style="transform: rotate(45deg)">
 </div>
 </div>
</div>
```

If a transform function causes the [current transformation
matrix](#current-transformation-matrix) of an object to be non-invertible, the object and its
content do not get displayed.

The object in the following example gets scaled by 0.

``` highlight
<style>
.box {
 transform: scale(0);
}
</style>

<div class="box">
 Not visible
</div>
```

The scaling causes a non-invertible CTM for the coordinate space of the
div box. Therefore neither the div box, nor the text in it get
displayed.

## 9. Interpolation of Transforms

[Interpolation](https://drafts.csswg.org/css-values-4/#interpolation) of transform function lists is performed as follows:

- [(#none-none-interpolation) If both
 `V`~`a`~ and `V`~`b`~ are
 [none]:]
 - `V`~`result`~ is [none].
- [(#transform-interpolation-length-fixup) Treating
 [none] as a list of zero length, if
 `V`~`a`~ or `V`~`b`~
 differ in length:]
 - extend the shorter list to the length of the longer list, setting
 the function at each additional position to the [identity transform
 function](#identity-transform-function) matching the function at the corresponding position
 in the longer list. Both transform function lists are then
 interpolated following the next rule.

 :::
 (#example-fa107865) For example, if
 `V`~`a`~ is [scale(2)] and
 `V`~`b`~ is [none] then the value
 [scale(1)] will be used for `V`~`b`~ and
 interpolation will proceed using the next rule. Similarly, if
 `V`~`a`~ is [scale(1)] and
 `V`~`b`~ is [scale(2) rotate(50deg)] then
 the interpolation will be performed as if
 `V`~`a`~ were [scale(1) rotate(0)].
 :::
- Let `V`~`result`~ be an empty list. Beginning at
 the start of `V`~`a`~ and
 `V`~`b`~, compare the corresponding functions at
 each position:
 - While the functions have either the same name, or are derivatives of
 the same [primitive transform function](#transform-primitives),
 interpolate the corresponding pair of functions as described in
 [§ 10 Interpolation of primitives and derived transform
 functions](#interpolation-of-transform-functions) and append the
 result to `V`~`result`~.

 - If the pair do not have a common name or [primitive transform
 function](#transform-primitives), post-multiply the remaining
 transform functions in each of `V`~`a`~ and
 `V`~`b`~ respectively to produce two 4x4
 matrices.
 [Interpolate](https://drafts.csswg.org/css-values-4/#interpolation) these two matrices as described in [§ 11
 Interpolation of Matrices](#matrix-interpolation), append the result
 to `V`~`result`~, and cease iterating over
 `V`~`a`~ and `V`~`b`~.

 :::
 (#example-922432e3) For example, if
 `V`~`a`~ is [rotate(0deg) scale(1)
 translate(20px)] and `V`~`b`~ is
 [rotate(270deg) translate(10px) scale(2)], the
 [rotate(0deg)] and [rotate(360deg)] functions will be
 interpolated according to [§ 10 Interpolation of primitives and
 derived transform functions](#interpolation-of-transform-functions)
 while the remainder of each list---​[scale(1) translate(20px)]
 and [translate(10px) scale(2)]---​will first be converted to
 equivalent 4x4 matrices and then interpolated as described in [§ 11
 Interpolation of Matrices](#matrix-interpolation).
 A previous version of this specification did not attempt to
 interpolate matching pairs of transform functions unless all functions
 in the list matched. As a result, the two lists in this example would
 be interpolated using matrix interpolation only and the
 [rotate(360deg)] component of the second list would be lost.
 :::

In some cases, an animation might cause a transformation matrix to be
singular or non-invertible. For example, an animation in which scale
moves from 1 to -1. At the time when the matrix is in such a state, the
transformed element is not rendered.

## 10. Interpolation of primitives and derived transform functions

Two transform functions with the same name and the same number of
arguments are interpolated numerically without a former conversion. The
calculated value will be of the same transform function type with the
same number of arguments. Special rules apply to
[\<matrix()\>](#funcdef-transform-matrix).

The two transform functions [translate(0)] and
[translate(100px)] are of the same type, have the same number of
arguments and therefore can get interpolated numerically.
[translateX(100px)] is not of the same type and [translate(100px,
0)] does not have the same number of arguments, therefore these
transform functions can not get interpolated without a former conversion
step.

Two different types of transform functions that share the same
primitive, or transform functions of the same type with different number
of arguments can be interpolated. Both transform functions need a former
conversion to the common primitive first and get interpolated
numerically afterwards. The computed value will be the primitive with
the resulting interpolated arguments.

The following example describes a transition from
[translateX(100px)] to [translateY(100px)] in 3 seconds on
hovering over the div box. Both transform functions derive from the same
primitive
[translate()](#funcdef-transform-translate) and therefore can be interpolated.

``` highlight
div {
 transform: translateX(100px);
}

div:hover {
 transform: translateY(100px);
 transition: transform 3s;
}
```

For the time of the transition both transform functions get transformed
to the common primitive. [translateX(100px)] gets converted to
[translate(100px, 0)] and [translateY(100px)] gets converted
to [translate(0, 100px)]. Both transform functions can then get
interpolated numerically.

If both transform functions share a primitive in the two-dimensional
space, both transform functions get converted to the two-dimensional
primitive. If one or both transform functions are three-dimensional
transform functions, the common three-dimensional primitive is used.

In this example a two-dimensional transform function gets animated to a
three-dimensional transform function. The common primitive is
[translate3d()](https://drafts.csswg.org/css-transforms-2/#funcdef-translate3d).

``` highlight
div {
 transform: translateX(100px);
}

div:hover {
 transform: translateZ(100px);
 transition: transform 3s;
}
```

First [translateX(100px)] gets converted to [translate3d(100px, 0,
0)] and [translateZ(100px)] to [translate3d(0, 0,
100px)] respectively. Then both converted transform functions get
interpolated numerically.

## 11. Interpolation of Matrices

When interpolating between two matrices, each matrix is decomposed into
the corresponding translation, rotation, scale, skew. Each corresponding
component of the decomposed matrices gets interpolated numerically and
recomposed back to a matrix in a final step.

In the following example the element
gets translated by 100 pixel in both the X and Y directions and rotated
by 1170° on hovering. The initial transformation is 45°. With the usage
of transition, an author might expect a animated, clockwise rotation by
three and a quarter turns (1170°).

``` highlight
<style>
div {
 transform: rotate(45deg);
}
div:hover {
 transform: translate(100px, 100px) rotate(1215deg);
 transition: transform 3s;
}
</style>

<div></div>
```

The number of transform functions on the source transform
[rotate(45deg)] differs from the number of transform functions on
the destination transform [translate(100px, 100px)
rotate(1125deg)]. According to the last rule of [Interpolation of
Transforms](#interpolation-of-transforms), both transforms must be
interpolated by matrix interpolation. With converting the transformation
functions to matrices, the information about the three turns gets lost
and the element gets rotated by just a quarter turn (90°).

To achieve the three and a quarter turns for the example above, source
and destination transforms must fulfill the third rule of [Interpolation
of Transforms](#interpolation-of-transforms). Source transform could
look like [translate(0, 0) rotate(45deg)] for a linear
interpolation of the transform functions.

In the following we differ between the [interpolation of two 2D
matrices](#interpolation-of-2d-matrices) and the interpolation of two
matrices where at least one matrix is not a [2D
matrix](#2d-matrix).

If one of the matrices for interpolation is non-invertible, the used
animation function must fall-back to a discrete animation according to
the rules of the respective animation specification.

### 11.1. Supporting functions

The pseudo code in the next subsections make use of the following
supporting functions:

 Supporting functions (point is a 3 component vector, matrix is a 4x4 matrix, vector is a 4 component vector):
 double determinant(matrix) returns the 4x4 determinant of the matrix
 matrix inverse(matrix) returns the inverse of the passed matrix
 matrix transpose(matrix) returns the transpose of the passed matrix
 point multVecMatrix(point, matrix) multiplies the passed point by the passed matrix
 and returns the transformed point
 double length(point) returns the length of the passed vector
 point normalize(point) normalizes the length of the passed point to 1
 double dot(point, point) returns the dot product of the passed points
 double sqrt(double) returns the root square of passed value
 double max(double y, double x) returns the bigger value of the two passed values
 double dot(vector, vector) returns the dot product of the passed vectors
 vector multVector(vector, vector) multiplies the passed vectors
 double sqrt(double) returns the root square of passed value
 double max(double y, double x) returns the bigger value of the two passed values
 double min(double y, double x) returns the smaller value of the two passed values
 double cos(double) returns the cosines of passed value
 double sin(double) returns the sine of passed value
 double acos(double) returns the inverse cosine of passed value
 double abs(double) returns the absolute value of the passed value
 double rad2deg(double) transforms a value in radian to degree and returns it
 double deg2rad(double) transforms a value in degree to radian and returns it

 Decomposition also makes use of the following function:
 point combine(point a, point b, double ascl, double bscl)
 result[0] = (ascl * a[0]) + (bscl * b[0])
 result[1] = (ascl * a[1]) + (bscl * b[1])
 result[2] = (ascl * a[2]) + (bscl * b[2])
 return result

### 11.2. Interpolation of 2D matrices

#### 11.2.1. Decomposing a 2D matrix

The pseudo code below is based upon the \"unmatrix\" method in
\"Graphics Gems II, edited by Jim Arvo\".

Matrices in the pseudo code use the column-major order. The first index
on a matrix entry represents the column and the second index represents
the row.

 Input: matrix ; a 4x4 matrix
 Output: translation ; a 2 component vector
 scale ; a 2 component vector
 angle ; rotation
 m11 ; 1,1 coordinate of 2x2 matrix
 m12 ; 1,2 coordinate of 2x2 matrix
 m21 ; 2,1 coordinate of 2x2 matrix
 m22 ; 2,2 coordinate of 2x2 matrix
 Returns false if the matrix cannot be decomposed, true if it can

 double row0x = matrix[0][0]
 double row0y = matrix[0][1]
 double row1x = matrix[1][0]
 double row1y = matrix[1][1]

 translate[0] = matrix[3][0]
 translate[1] = matrix[3][1]

 scale[0] = sqrt(row0x * row0x + row0y * row0y)
 scale[1] = sqrt(row1x * row1x + row1y * row1y)

 // If determinant is negative, one axis was flipped.
 double determinant = row0x * row1y - row0y * row1x
 if (determinant < 0)
 // Flip axis with minimum unit vector dot product.
 if (row0x < row1y)
 scale[0] = -scale[0]
 else
 scale[1] = -scale[1]

 // Renormalize matrix to remove scale.
 if (scale[0])
 row0x *= 1 / scale[0]
 row0y *= 1 / scale[0]
 if (scale[1])
 row1x *= 1 / scale[1]
 row1y *= 1 / scale[1]

 // Compute rotation and renormalize matrix.
 angle = atan2(row0y, row0x);

 if (angle)
 // Rotate(-angle) = [cos(angle), sin(angle), -sin(angle), cos(angle)]
 // = [row0x, -row0y, row0y, row0x]
 // Thanks to the normalization above.
 double sn = -row0y
 double cs = row0x
 double m11 = row0x
 double m12 = row0y
 double m21 = row1x
 double m22 = row1y
 row0x = cs * m11 + sn * m21
 row0y = cs * m12 + sn * m22
 row1x = -sn * m11 + cs * m21
 row1y = -sn * m12 + cs * m22

 m11 = row0x
 m12 = row0y
 m21 = row1x
 m22 = row1y

 // Convert into degrees because our rotation functions expect it.
 angle = rad2deg(angle)

 return true

#### 11.2.2. Interpolation of decomposed 2D matrix values

Before two decomposed 2D matrix values can be interpolated, the
following

 Input: translationA ; a 2 component vector
 scaleA ; a 2 component vector
 angleA ; rotation
 m11A ; 1,1 coordinate of 2x2 matrix
 m12A ; 1,2 coordinate of 2x2 matrix
 m21A ; 2,1 coordinate of 2x2 matrix
 m22A ; 2,2 coordinate of 2x2 matrix
 translationB ; a 2 component vector
 scaleB ; a 2 component vector
 angleB ; rotation
 m11B ; 1,1 coordinate of 2x2 matrix
 m12B ; 1,2 coordinate of 2x2 matrix
 m21B ; 2,1 coordinate of 2x2 matrix
 m22B ; 2,2 coordinate of 2x2 matrix

 // If x-axis of one is flipped, and y-axis of the other,
 // convert to an unflipped rotation.
 if ((scaleA[0] < 0 && scaleB[1] < 0) || (scaleA[1] < 0 && scaleB[0] < 0))
 scaleA[0] = -scaleA[0]
 scaleA[1] = -scaleA[1]
 angleA += angleA < 0 ? 180 : -180

 // Don't rotate the long way around.
 if (!angleA)
 angleA = 360
 if (!angleB)
 angleB = 360

 if (abs(angleA - angleB) > 180)
 if (angleA > angleB)
 angleA -= 360
 else
 angleB -= 360

Afterwards, each component of the decomposed values translation, scale,
angle, m11 to m22 of the source matrix get linearly interpolated with
each corresponding component of the destination matrix.

#### 11.2.3. Recomposing to a 2D matrix

After interpolation, the resulting values are used to transform the
elements user space. One way to use these values is to recompose them
into a 4x4 matrix. This can be done following the pseudo code below.

Matrices in the pseudo code use the column-major order. The first index
on a matrix entry represents the column and the second index represents
the row.

 Input: translation ; a 2 component vector
 scale ; a 2 component vector
 angle ; rotation
 m11 ; 1,1 coordinate of 2x2 matrix
 m12 ; 1,2 coordinate of 2x2 matrix
 m21 ; 2,1 coordinate of 2x2 matrix
 m22 ; 2,2 coordinate of 2x2 matrix
 Output: matrix ; a 4x4 matrix initialized to identity matrix

 matrix[0][0] = m11
 matrix[0][1] = m12
 matrix[1][0] = m21
 matrix[1][1] = m22

 // Translate matrix.
 matrix[3][0] = translate[0] * m11 + translate[1] * m21
 matrix[3][1] = translate[0] * m12 + translate[1] * m22

 // Rotate matrix.
 angle = deg2rad(angle);
 double cosAngle = cos(angle);
 double sinAngle = sin(angle);

 // New temporary, identity initialized, 4x4 matrix rotateMatrix
 rotateMatrix[0][0] = cosAngle
 rotateMatrix[0][1] = sinAngle
 rotateMatrix[1][0] = -sinAngle
 rotateMatrix[1][1] = cosAngle

 matrix = post-multiply(rotateMatrix, matrix)

 // Scale matrix.
 matrix[0][0] *= scale[0]
 matrix[0][1] *= scale[0]
 matrix[1][0] *= scale[1]
 matrix[1][1] *= scale[1]

## 12. Mathematical Description of Transform Functions

Mathematically, all transform functions can be represented as 4x4
transformation matrices of the following form:

![\\begin{bmatrix} m11 & m21 & m31 & m41 \\\\ m12 & m22 & m32 & m42 \\\\
m13 & m23 & m33 & m43 \\\\ m14 & m24 & m34 & m44
\\end{bmatrix}](images/4x4matrix.png){height="106" width="222"}

One translation unit on a matrix is equivalent to 1 pixel in the local
coordinate system of the element.

- [(#MatrixDefined)]

 A 2D 3x2 matrix with six parameters *a*, *b*, *c*, *d*, *e* and *f* is
 equivalent to the matrix:

 ![\\begin{bmatrix} a & c & 0 & e \\\\ b & d & 0 & f \\\\ 0 & 0 & 1 & 0
 \\\\ 0 & 0 & 0 & 1 \\end{bmatrix}](images/matrix.png){height="106"
 width="108"}

- [(#TranslateDefined)]

 A 2D translation with the parameters *tx* and *ty* is equivalent to a
 3D translation where *tz* has zero as a value.

 ![\\begin{bmatrix} 1 & 0 & 0 & tx \\\\ 0 & 1 & 0 & ty \\\\ 0 & 0 & 1 &
 tz \\\\ 0 & 0 & 0 & 1
 \\end{bmatrix}](images/translate3d.png){height="106" width="114"}

- [(#ScaleDefined)]

 A 2D scaling with the parameters *sx* and *sy* is equivalent to a 3D
 scale where *sz* has one as a value.

 ![\\begin{bmatrix} sx & 0 & 0 & 0 \\\\ 0 & sy & 0 & 0 \\\\ 0 & 0 & sz
 & 0 \\\\ 0 & 0 & 0 & 1
 \\end{bmatrix}](images/scale3d.png){height="106" width="137"}

- [(#RotateDefined)]

 A 2D rotation with the parameter *alpha* is equivalent to a 3D
 rotation with the vector \[x,y,z\] where *x* has zero as a value, *y*
 has zero as a value, *z* has one as a value, and the parameter
 *alpha*.

 ![\\begin{bmatrix} 1 - 2 \\cdot (y\^2 + z\^2) \\cdot sq & 2 \\cdot (x
 \\cdot y \\cdot sq - z \\cdot sc) & 2 \\cdot (x \\cdot z \\cdot sq + y
 \\cdot sc) & 0 \\\\ 2 \\cdot (x \\cdot y \\cdot sq + z \\cdot sc) &
 1 - 2 \\cdot (x\^2 + z\^2) \\cdot sq & 2 \\cdot (y \\cdot z \\cdot
 sq - x \\cdot sc) & 0 \\\\ 2 \\cdot (x \\cdot z \\cdot sq - y \\cdot
 sc) & 2 \\cdot (y \\cdot z \\cdot sq + x \\cdot sc) & 1 - 2 \\cdot
 (x\^2 + y\^2) \\cdot sq & 0 \\\\ 0 & 0 & 0 & 1
 \\end{bmatrix}](images/rotate3dmatrix.png){height="106" width="647"}

 where:

 ![\\newline sc = \\sin (\\alpha/2) \\cdot \\cos (\\alpha/2) \\newline
 sq = \\sin\^2 (\\alpha/2)](images/rotate3dvariables.png){height="50"
 width="221"}

- [(#SkewDefined)]

 A 2D skew like transformation with the parameters *alpha* and *beta*
 is equivalent to the matrix:

 ![\\begin{bmatrix} 1 & \\tan(\\alpha) & 0 & 0 \\\\ \\tan(\\beta) & 1 &
 0 & 0 \\\\ 0 & 0 & 1 & 0 \\\\ 0 & 0 & 0 & 1
 \\end{bmatrix}](images/skew.png){height="106" width="205"}

- [(#SkewXDefined)]

 A 2D skew transformation along the X axis with the parameter *alpha*
 is equivalent to the matrix:

 ![\\begin{bmatrix} 1 & \\tan(\\alpha) & 0 & 0 \\\\ 0 & 1 & 0 & 0 \\\\
 0 & 0 & 1 & 0 \\\\ 0 & 0 & 0 & 1
 \\end{bmatrix}](images/skewX.png){height="106" width="155"}

- [(#SkewYDefined)]

 A 2D skew transformation along the Y axis with the parameter *beta* is
 equivalent to the matrix:

 ![\\begin{bmatrix} 1 & 0 & 0 & 0 \\\\ \\tan(\\beta) & 1 & 0 & 0 \\\\ 0
 & 0 & 1 & 0 \\\\ 0 & 0 & 0 & 1
 \\end{bmatrix}](images/skewY.png){height="106" width="155"}

## 13. Privacy Considerations

UAs must implement transform operations in a way attackers can not infer
information and mount a timing attack.

A timing attack is a method of obtaining information about content that
is otherwise protected, based on studying the amount of time it takes
for an operation to occur.

At this point there are no information about potential privacy concerns
specific to this specification.

## 14. Security Considerations

At this point there are no information about potential security concerns
specific to this specification.

## [Changes]
### [Since the [14 February 2019 Candidate Recommendation](https://www.w3.org/TR/2019/CR-css-transforms-1-20190214/)]
- Relax syntax of
 [transform](https://www.w3.org/TR/SVG11/coords.html#TransformAttribute) attribute: Do not require commas between
 [\<transform-list\>](#typedef-transform-list) items.

- Simplified grammar of transform functions. (No normative impact.)

- Remove animation support of
 [transform](#propdef-transform) from
 [animate](https://svgwg.org/specs/animations/#elementdef-animate) and
 [set](https://svgwg.org/specs/animations/#elementdef-set) elements.

- State that transforms do not transform backgrounds that are propagated
 to the canvas, and clarify some other interactions with background
 propagation.

- Split privacy and security section.

- Editorial changes.

### [Since the [30 November 2018 Working Draft](https://www.w3.org/TR/2018/WD-css-transforms-1-20181130/)]
- No substantive changes

- Boilerplate, styling updates for CR

### [Since the [30 November 2017 Working Draft](https://www.w3.org/TR/2017/WD-css-transforms-1-20171130/) ]
- Remove specification text that makes
 [patternTransform](https://www.w3.org/TR/SVG11/pservers.html#PatternElementPatternTransformAttribute),
 [gradientTransform](https://www.w3.org/TR/SVG11/pservers.html#LinearGradientElementGradientTransformAttribute) presentation attributes representing the
 [transform](#propdef-transform) property. That is going to get
 specified by SVG 2
 [\[SVG2\]](#biblio-svg2 "Scalable Vector Graphics (SVG) 2").

- Added privacy and security section.

- Use
 [\[SVG2\]](#biblio-svg2 "Scalable Vector Graphics (SVG) 2")
 definitions for [transformable
 elements](#transformable-element).

- Added special syntax for
 [transform](https://www.w3.org/TR/SVG11/coords.html#TransformAttribute),
 [`gradientTransform`](https://www.w3.org/TR/SVG11/pservers.html#LinearGradientElementGradientTransformAttribute) and
 [`patternTransform`](https://www.w3.org/TR/SVG11/pservers.html#PatternElementPatternTransformAttribute) attributes.

- Clarify multiplication order by using terms
 [post-multiply](#post-multiply) and
 [pre-multiply](#pre-multiply).

- Clarify index order of matrix entries in pseudo-code.

- Clarify multiplication order in recomposition pseudo-code.

- Clarify behavior of
 [transform](#propdef-transform) on overflow area.

- Remove [translateX(0)], [translateY(0)],
 [scaleX(0)], [scaleY(0)] from the list of neutral
 elements.

- Remove any reference of 3D transformations of transform function
 definitions.

- Specify interpolation between
 [\<transform-list\>](#typedef-transform-list)s to match lengths and avoid matrix
 interpolation for the common prefix of the two lists.

- No [transform](#propdef-transform) on non-replaced inline boxes,
 table-column boxes, and table-column-group boxes.

- Define target coordinate space for transformations on
 [`pattern`](https://w3c.github.io/svgwg/svg2-draft/pservers.html#elementdef-pattern),
 [`linearGradient`](https://w3c.github.io/svgwg/svg2-draft/pservers.html#elementdef-linearGradient),
 [`radialGradient`](https://w3c.github.io/svgwg/svg2-draft/pservers.html#elementdef-radialGradient) and
 [`clipPath`](https://drafts.csswg.org/css-masking-1/#elementdef-clippath) elements.

- Remove 3-value
 [\<rotate()\>](#funcdef-transform-rotate) from transform function
 primitives.

- Be more specific about computation of [transformation
 matrix](#transformation-matrix) and [current transformation
 matrix](#current-transformation-matrix).

- Define reference box for paint servers and
 [`clipPath`](https://drafts.csswg.org/css-masking-1/#elementdef-clippath) element.

- Specify behavior of transform presentation attribute with
 3-value-rotate as start or end value of a transition.

- Add
 [stroke-box](#valdef-transform-box-stroke-box) and
 [content-box](#valdef-transform-box-content-box) to
 [transform-box](#propdef-transform-box). Align box mapping behavior
 across all specifications.

- Editorial changes.

## [Acknowledgments]
The editors would like to thank Robert O'Callahan, Cameron McCormack,
Tab Atkins, Gérard Talbot, L. David Baron, Rik Cabanier, Brian Birtles,
Benoit Jacob, Ken Shoemake, Alan Gresley, Maciej Stochowiak, Sylvain
Galineau, Rafal Pietrak, Shane Stephens, Matt Rakow, XiangHongAi, Fabio
M. Costa, Nivesh Rajbhandari, Rebecca Hauck, Gregg Tavares, Graham
Clift, Erik Dahlström, Alexander Zolotov, Amelia Bellamy-Royds and Boris
Zbarsky for their careful reviews, comments, and corrections.
