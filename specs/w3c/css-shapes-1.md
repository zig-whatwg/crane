## 1. Introduction

*This section is not normative.*

Shapes define arbitrary geometries that can be used as CSS values. This
specification defines properties to control the geometry of an element's
[float area](#float-area). The
[shape-outside](#propdef-shape-outside) property uses shape values to
define the [float area] for a float.

 Future levels of CSS Shapes will allow use of shapes on
elements other than floats. Other CSS modules can make use of shapes as
well, such as CSS Masking
[\[CSS-MASKING\]](#biblio-css-masking "CSS Masking Module Level 1")
and CSS Exclusions
[\[CSS3-EXCLUSIONS\]](#biblio-css3-exclusions "CSS Exclusions Module Level 1").

 If a user agent implements both CSS Shapes and CSS
Exclusions, the
[shape-outside](#propdef-shape-outside) property defines the exclusion area
for an exclusion.

 A future level of CSS Shapes will define a shape-inside
property, which will define a shape to [wrap](#wrap) content within the element.

### 1.1. Module Interactions

This module extends the float features defined in
[\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")
chapter 9.

### 1.2. Values

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

### 1.3. Terminology

[Wrap]

This specification uses the term [wrap](#wrap) to refer to flowing content around the sides of a
[float area](#float-area), defined
in
[\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")
chapter 9. Content [wraps] around the right side of a
left-floated box, and content [wraps] around the left
side of a right-floated box. One result of this
[wrapping] is that line boxes next to a float are
shortened as necessary to avoid intersections with the [float
area].

[Float area]

The area used for [wrapping](#wrap)
content around a float element. The rules for float behavior use the
sides of the [float area](#float-area) to determine where content flows. By default, the
[float area] is the float element's [margin
box](https://drafts.csswg.org/css-box-4/#margin-box) (note this can be different than the [float
area] produced by the
[margin-box](#valdef-shape-box-margin-box) value, which includes border-radius curvature).
This specification's
[shape-outside](#propdef-shape-outside) and
[shape-margin](#propdef-shape-margin) properties can be used to define an
arbitrary, non-rectangular [float area].

[direction-agnostic size] The [direction-agnostic
size](#direction-agnostic-size) of a box is equal to the length of the diagonal of the
box, divided by sqrt(2).

 This is a method of averaging the width and height of a
box used by SVG in some cases, when a percentage of a box's size is
desired but the context doesn't specifically favor the width or the
height. For square boxes, this is the same as the width/height.

## 2. Relation to the box model and float behavior

While the boundaries used for [wrapping](#wrap) inline flow content outside a float can be defined
using shapes, the actual box model does not change. If the element has
specified margins, borders or padding they will be computed and rendered
according to the
[\[CSS3BOX\]](#biblio-css3box "CSS Box Model Module Level 3")
module. Also, float positioning and stacking are not affected by
defining a [float area](#float-area) with a shape.

When a shape is used to define a [float
area](#float-area), the shape is
clipped to the float's margin box. In other words, a shape can only ever
reduce a [float area], not increase it. A reduced
[float area] may have no effect on some line
boxes that would normally be affected by the float. If a shape does not
enclose any area, the shape's edges are still used to define the [float
area].

A [float area](#float-area)
defined by a shape may reduce the normal [float
area] on all sides, but this does not allow
content to [wrap](#wrap) on both sides
of a float. Left floats with a
[shape-outside](#propdef-shape-outside) still only allow content
[wrapping] on the right side, and right floats only
allow [wrapping] on the left.

In the following example the left and right floating `img`
elements specify a triangular shape using the
[shape-outside](#propdef-shape-outside) property.

 <img class="left" src="hand.svg"/>
 <img class="right" src="hand.svg"/>
 <p>
 Sometimes a web page's text content appears to be
 funneling your attention towards a spot on the page
 to drive you to follow a particular link. Sometimes
 you don't notice.
 </p>

 <style type="text/css">
 .left {
 shape-outside: polygon(0 0, 100% 100%, 0 100%);
 float: left;
 width: 40%;
 height: 12ex;
 transform: scaleX(-1);
 }

 .right {
 shape-outside: polygon(100% 0, 100% 100%, 0 100%);
 float: right;
 width: 40%;
 height: 12ex;
 }

 p {
 text-align: center;
 }
 </style>

![Using the shape-outside property with
floats](images/hand-funnel.png)

Since shapes are clipped to the float's margin box, adding this shape to
the left float above would result in the same rendering.

 shape-outside: polygon(0 0, 500% 500%, 0 500%);

A shape that does not enclose any area still has edges that contribute
to the [float area](#float-area).

This inset shape is a vertical line positioned at the midpoint of the
reference box. This midpoint edge is used as the edge of the float area
for wrapping content.

 shape-outside: inset(0% 50% 0% 50%);

If inset values add up to more than the width, [CSS Backgrounds 3 § 4.5
Overlapping
Curves](https://drafts.csswg.org/css-backgrounds-3/#corner-overlap)
rules are used to determine the edges of the rectangle. This shape
results in a vertical edge 25% from the left side of the reference box.

 shape-outside: inset(0% 150% 50% 0%);

If the shape is only a horizontal line, then it is an empty float area
and has no effect on wrapping. Note that in this example shape-margin
must be 0px (otherwise the line would expand to enclose an area).

 shape-outside: inset(50% 0% 0% 50%);
 shape-margin: 0px;

A
[shape-outside](#propdef-shape-outside) can create open areas on both the
left and right of a [float area](#float-area). Content still [wraps](#wrap) only on one side of a float in this case. In the
picture, the shape is rendered in blue, and the content area outside the
shape in mauve.

 shape-outside: polygon(50px 0px, 100px 100px, 0px 100px);

![wrapping around right side of a left-float float
area](images/float-side-example.png)

The following styling creates a shape much smaller than the float's
content area, and adds a margin-top to the float. In the picture, the
shape is rendered in blue, the content area outside the shape in mauve,
and the margin area of the float box in yellow. The inline content only
[wraps](#wrap) around the shape, and
otherwise overlays the rest of the float margin box.

 .float-left {
 shape-outside: polygon(0% 50%, 50% 100%, 0 100%);
 float: left;
 width: 100px;
 height: 100px;
 margin-top: 20px;
 }

![Adding margin-top to a float with a small
shape-outside](images/float-margin-example.png)

The next picture shows a possible result if two of these floats were
stacked next to each other. Note that the floats are positioned using
their margin boxes, not the [float
area](#float-area).

![Stacking two floats with a small
shape-outside](images/stacked-float-example.png)

## 3. Basic Shapes

The [\<basic-shape\>] type can be specified using basic shape
functions.

``` prod
<basic-shape> = <basic-shape-rect> | <circle()> | <ellipse()> | <polygon()> | <path()> | <shape()>
```

When using this syntax to define shapes, the [reference
box] is defined by each
property that uses
[\<basic-shape\>](#typedef-basic-shape) values. The coordinate system for the
shape has its origin on the top-left corner of the [reference
box](#basic-shape-reference-box) with the x-axis running to the right and the y-axis
running downwards. All the lengths expressed in percentages are resolved
from the used dimensions of the [reference
box].

### 3.1. Supported Shapes

The
[\<basic-shape\>](#typedef-basic-shape) functions are:

``` prod
<inset()> = inset(
 <length-percentage>{1,4}
 [ round <'border-radius'> ]?
)

<xywh()> = xywh(
 <length-percentage>{2} <length-percentage [0,∞]>{2}
 [ round <'border-radius'> ]?
)

<rect()> = rect(
 [ <length-percentage> | auto ]{4}
 [ round <'border-radius'> ]?
)

<basic-shape-rect> = <inset()> | <rect()> | <xywh()>

<circle()> = circle(
 <radial-size>?
 [ at <position> ]?
)

<ellipse()> = ellipse(
 <radial-size>?
 [ at <position> ]?
)

<polygon()> = polygon(
 <'fill-rule'>?
 [ round <length> ]? ,
 [<length-percentage> <length-percentage>]#
)

<path()> = path(
 <'fill-rule'>? ,
 <string>
)

<shape()> = shape(
 <'fill-rule'>?
 from <position> ,
 <shape-command>#
)
```

[inset()]

: Defines an inset rectangle via insets from each edge of the
 [reference
 box](#basic-shape-reference-box).

 If less than four
 [\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage) values are provided, the omitted
 values default in the same way as the
 [margin](https://drafts.csswg.org/css2/#propdef-margin) shorthand: an omitted second or
 third value defaults to the first, and an omitted fourth value
 defaults to the second.

 The four
 [\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage)s define the position of the top,
 right, bottom, and left edges of a rectangle, respectively, as
 insets from the corresponding edges of the [reference
 box](#basic-shape-reference-box).

 A pair of insets in either dimension that add up to more than the
 used dimension (such as left and right insets of 75% apiece) use the
 [CSS Backgrounds 3 § 4.5 Overlapping
 Curves](https://drafts.csswg.org/css-backgrounds-3/#corner-overlap)
 rules to proportionally reduce the inset effect to 100%.

 :::
 (#example-4a20658e) For example, specifying [inset(75%
 0 50% 0)] has the top+bottom edges summing to 125% of the
 [reference
 box's](#basic-shape-reference-box) height. They're proportionally reduced to sum to
 100%, identical to specifying [inset(60% 0 40% 0)].
 :::

 The optional
 [\<\'border-radius\'\>](https://drafts.csswg.org/css-backgrounds-3/#propdef-border-radius) argument(s) define rounded
 corners for the rectangle using the
 [border-radius] shorthand
 syntax.

 Tests

 - [inset-function-computed.html](https://wpt.fyi/results/css/css-shapes/shape-functions/inset-function-computed.html "css/css-shapes/shape-functions/inset-function-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-functions/inset-function-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-functions/inset-function-computed.html)
 - [inset-function-invalid.html](https://wpt.fyi/results/css/css-shapes/shape-functions/inset-function-invalid.html "css/css-shapes/shape-functions/inset-function-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-functions/inset-function-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-functions/inset-function-invalid.html)
 - [inset-function-valid.html](https://wpt.fyi/results/css/css-shapes/shape-functions/inset-function-valid.html "css/css-shapes/shape-functions/inset-function-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-functions/inset-function-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-functions/inset-function-valid.html)

[xywh()]

: Defines a rectangle via offsets from the top and left edge of the
 [reference
 box](#basic-shape-reference-box), and a specified width and height.

 The four
 [\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage)s define, respectively, the inset
 from the left edge of the [reference
 box](#basic-shape-reference-box), the inset from the top edge of the [reference
 box], the width of the
 rectangle, and the height of the rectangle.

 This syntax is inspired by the
 [`viewBox`](https://w3c.github.io/svgwg/svg2-draft/coords.html#TermViewBox) attribute from SVG.

 The optional
 [\<\'border-radius\'\>](https://drafts.csswg.org/css-backgrounds-3/#propdef-border-radius) argument(s) define rounded
 corners for the inset rectangle using the
 [border-radius] shorthand
 syntax.

 Tests

 - [xywh-function-computed.html](https://wpt.fyi/results/css/css-shapes/shape-functions/xywh-function-computed.html "css/css-shapes/shape-functions/xywh-function-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-functions/xywh-function-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-functions/xywh-function-computed.html)
 - [xywh-function-invalid.html](https://wpt.fyi/results/css/css-shapes/shape-functions/xywh-function-invalid.html "css/css-shapes/shape-functions/xywh-function-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-functions/xywh-function-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-functions/xywh-function-invalid.html)
 - [xywh-function-valid.html](https://wpt.fyi/results/css/css-shapes/shape-functions/xywh-function-valid.html "css/css-shapes/shape-functions/xywh-function-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-functions/xywh-function-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-functions/xywh-function-valid.html)

[rect()]

: Defines a rectangle via insets from the top and left edges of the
 [reference
 box](#basic-shape-reference-box).

 The four
 [\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage)s define the position of the top,
 right, bottom, and left edges of a rectangle, respectively, as
 insets from the top edge of the [reference
 box](#basic-shape-reference-box) (for the first and third values) or the left edge
 of the [reference box] (for
 the second and fourth values).

 An [auto] value makes the edge of the box coincide with the
 corresponding edge of the [reference
 box](#basic-shape-reference-box): it's equivalent to [0%] as the first (top)
 or fourth (left) value, and equivalent to [100%] as the second
 (right) or third (bottom) value.

 The second (right) and third (bottom) values are floored by the
 fourth (left) and second (top) values, respectively.

 :::
 (#example-203cf4f2) For example, specifying [rect(10px
 0 0 20px)] would place the bottom edge higher than the top
 edge, and the right edge further left than the left edge, so both
 are corrected to not cross over the other edge, identical to
 specifying [rect(10px 20px 10px 20px)].
 :::

 This syntax is similar, but not quite identical, to
 the legacy
 [rect()](#funcdef-basic-shape-rect) function used solely by the
 [clip](https://drafts.csswg.org/css-masking-1/#propdef-clip) property.

 The optional
 [\<\'border-radius\'\>](https://drafts.csswg.org/css-backgrounds-3/#propdef-border-radius) argument(s) define rounded
 corners for the rectangle using the
 [border-radius] shorthand
 syntax.)

 Tests

 - [rect-function-computed.html](https://wpt.fyi/results/css/css-shapes/shape-functions/rect-function-computed.html "css/css-shapes/shape-functions/rect-function-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-functions/rect-function-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-functions/rect-function-computed.html)
 - [rect-function-invalid.html](https://wpt.fyi/results/css/css-shapes/shape-functions/rect-function-invalid.html "css/css-shapes/shape-functions/rect-function-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-functions/rect-function-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-functions/rect-function-invalid.html)
 - [rect-function-valid.html](https://wpt.fyi/results/css/css-shapes/shape-functions/rect-function-valid.html "css/css-shapes/shape-functions/rect-function-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-functions/rect-function-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-functions/rect-function-valid.html)

[circle()]

: - The
 [\<radial-size\>](https://drafts.csswg.org/css-images-3/#typedef-radial-size) argument defines the circle's
 radius. Rather than referring to the [gradient
 box](https://drafts.csswg.org/css-images-4/#gradient-box), values are resolved against the [reference
 box](#basic-shape-reference-box). Two
 [\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage) values are invalid. If omitted
 it defaults to [closest-side].

 - The
 [\<position\>](https://drafts.csswg.org/css-values-5/#typedef-position) argument defines the center of
 the circle. Unless otherwise specified, this defaults to
 [center] if omitted.

 Tests
 - [circle-function-computed.html](https://wpt.fyi/results/css/css-shapes/shape-functions/circle-function-computed.html "css/css-shapes/shape-functions/circle-function-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-functions/circle-function-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-functions/circle-function-computed.html)
 - [circle-function-invalid.html](https://wpt.fyi/results/css/css-shapes/shape-functions/circle-function-invalid.html "css/css-shapes/shape-functions/circle-function-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-functions/circle-function-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-functions/circle-function-invalid.html)
 - [circle-function-valid.html](https://wpt.fyi/results/css/css-shapes/shape-functions/circle-function-valid.html "css/css-shapes/shape-functions/circle-function-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-functions/circle-function-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-functions/circle-function-valid.html)

[ellipse()]

: - The
 [\<radial-size\>](https://drafts.csswg.org/css-images-3/#typedef-radial-size) argument defines the horizontal
 and vertical radiuses of the ellipse. Rather than referring to the
 [gradient
 box](https://drafts.csswg.org/css-images-4/#gradient-box), values are resolved against the [reference
 box](#basic-shape-reference-box). If omitted it defaults to [closest-side].

 - The
 [\<position\>](https://drafts.csswg.org/css-values-5/#typedef-position) argument defines the center of
 the ellipse. Unless otherwise specified, this defaults to
 [center] if omitted.

 Tests
 - [ellipse-function-computed.html](https://wpt.fyi/results/css/css-shapes/shape-functions/ellipse-function-computed.html "css/css-shapes/shape-functions/ellipse-function-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-functions/ellipse-function-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-functions/ellipse-function-computed.html)
 - [ellipse-function-invalid.html](https://wpt.fyi/results/css/css-shapes/shape-functions/ellipse-function-invalid.html "css/css-shapes/shape-functions/ellipse-function-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-functions/ellipse-function-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-functions/ellipse-function-invalid.html)
 - [ellipse-function-valid.html](https://wpt.fyi/results/css/css-shapes/shape-functions/ellipse-function-valid.html "css/css-shapes/shape-functions/ellipse-function-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-functions/ellipse-function-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-functions/ellipse-function-valid.html)

[polygon()]

: - The
 [\<\'fill-rule\'\>](https://w3c.github.io/svgwg/svg2-draft/painting.html#FillRuleProperty) specifies the filling rule
 used to determine the interior. Defaults to
 [nonzero](https://drafts.csswg.org/css-masking-1/#valdef-clip-rule-nonzero) if omitted.

 - An optional
 [\<length\>](https://drafts.csswg.org/css-values-4/#length-value) after a [round] keyword
 defines rounding for each vertex of the polygon. The length is the
 radius of a circle whose center lies on the bisector of the
 smaller angle of the vertex, and that is tangential to both sides
 of the vertex.

 :::
 (#example-1217097f)
 ![Rounding polygon vertices that are both convex and
 concave.](images/vertex-rounding.png){a
 height="1134" width="1328"}
 :::

 To avoid rounding more than half of any line segment, the rounding
 of each vertex must be clamped separately such that the radius is
 never more than the smaller of `tan(angle/2) segment / 2`
 evaluated against both vertex line segments.

 :::
 (#example-f443dfa5)
 ![This diagram shows the intent of the clamping
 formula.](images/clamp-explanation.png){a
 height="401" width="921"}
 :::

 - Each
 [\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage) pair specifies a vertex of the
 polygon, as a horizontal and vertical offset from the left and top
 edges of the [reference
 box](#basic-shape-reference-box).

 The UA must close a polygon by connecting the last vertex with the
 first vertex of the list.

 Tests

 - [polygon-function-computed.html](https://wpt.fyi/results/css/css-shapes/shape-functions/polygon-function-computed.html "css/css-shapes/shape-functions/polygon-function-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-functions/polygon-function-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-functions/polygon-function-computed.html)
 - [polygon-function-invalid.html](https://wpt.fyi/results/css/css-shapes/shape-functions/polygon-function-invalid.html "css/css-shapes/shape-functions/polygon-function-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-functions/polygon-function-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-functions/polygon-function-invalid.html)
 - [polygon-function-valid.html](https://wpt.fyi/results/css/css-shapes/shape-functions/polygon-function-valid.html "css/css-shapes/shape-functions/polygon-function-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-functions/polygon-function-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-functions/polygon-function-valid.html)

[path()]

: - The
 [\<\'fill-rule\'\>](https://w3c.github.io/svgwg/svg2-draft/painting.html#FillRuleProperty) specifies the filling rule
 used to determine the interior. Defaults to
 [nonzero](https://drafts.csswg.org/css-masking-1/#valdef-clip-rule-nonzero) if omitted, unless the function is being
 used in a context such as SVG shapes where the
 [fill-rule] property is
 relevant. In that case an omitted value will use the computed
 value of the [fill-rule]
 property.

 - The
 [\<string\>](https://drafts.csswg.org/css-values-4/#string-value) represents an [SVG Path data
 string](https://www.w3.org/TR/SVG11/paths.html#PathData). A path
 data string that does not conform to the to the grammar and
 parsing rules of SVG 1.1, or that does conform but defines an
 empty path, is
 [invalid](https://drafts.csswg.org/css-syntax-3/#css-invalid) and causes the entire
 [path()](#funcdef-basic-shape-path) to be [invalid].

 The initial position is defined by the first "move to" argument in
 the path string. For the initial direction follow SVG 1.1.

 The UA must close a path with an implicit closepath command (\"z\"
 or \"Z\") if it is not present in the string for properties that
 require a closed loop (such as
 [shape-outside](#propdef-shape-outside) and
 [clip-path](https://drafts.csswg.org/css-masking-1/#propdef-clip-path)).

 Tests

 - [path-function-computed.html](https://wpt.fyi/results/css/css-shapes/shape-functions/path-function-computed.html "css/css-shapes/shape-functions/path-function-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-functions/path-function-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-functions/path-function-computed.html)
 - [path-function-invalid.html](https://wpt.fyi/results/css/css-shapes/shape-functions/path-function-invalid.html "css/css-shapes/shape-functions/path-function-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-functions/path-function-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-functions/path-function-invalid.html)
 - [path-function-valid.html](https://wpt.fyi/results/css/css-shapes/shape-functions/path-function-valid.html "css/css-shapes/shape-functions/path-function-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-functions/path-function-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-functions/path-function-valid.html)

[shape()]
: See [The shape() function](#shape-function).
 Tests
 - [shape-function-computed.html](https://wpt.fyi/results/css/css-shapes/shape-functions/shape-function-computed.html "css/css-shapes/shape-functions/shape-function-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-functions/shape-function-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-functions/shape-function-computed.html)
 - [shape-function-invalid.html](https://wpt.fyi/results/css/css-shapes/shape-functions/shape-function-invalid.html "css/css-shapes/shape-functions/shape-function-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-functions/shape-function-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-functions/shape-function-invalid.html)
 - [shape-function-valid.html](https://wpt.fyi/results/css/css-shapes/shape-functions/shape-function-valid.html "css/css-shapes/shape-functions/shape-function-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-functions/shape-function-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-functions/shape-function-valid.html)

#### 3.1.1. The [shape() Function]
While the
[path()](#funcdef-basic-shape-path) function allows reuse of the SVG path syntax to
define more arbitrary shapes than allowed by more specialized shape
functions, it requires writing a path as a single string (which is not
compatible with, for example, building a path piecemeal with
[var()](https://drafts.csswg.org/css-variables-2/#funcdef-var)), and inherits a number of limitations from SVG,
such as implicitly only allowing the
[px](https://drafts.csswg.org/css-values-4/#px) unit.

The
[shape()](#funcdef-basic-shape-shape) function uses a set of commands roughly
equivalent to the ones used by
[path()](#funcdef-basic-shape-path), but does so with more standard CSS syntax, and
allows the full range of CSS functionality, such as additional units and
math functions. The commands used by
[shape()] are dynamically
turned into path segments when it is used for rendering, e.g., when
computing the rendered
[clip-path](https://drafts.csswg.org/css-masking-1/#propdef-clip-path).

In that sense,
[shape()](#funcdef-basic-shape-shape) is a superset of
[path()](#funcdef-basic-shape-path). A [path()] can be easily converted to a
[shape()], but to convert a
[shape()] back to a
[path()] or to SVG requires
information about the CSS environment (e.g. current values of CSS custom
properties, current font size for
[em](https://drafts.csswg.org/css-values-4/#em) units, etc).

The
[\<\'fill-rule\'\>](https://w3c.github.io/svgwg/svg2-draft/painting.html#FillRuleProperty) is interpreted identically to the
same argument in
[path()](#funcdef-basic-shape-path).

The rest of the arguments define a list of path data commands, identical
to that of an [SVG
Path](https://www.w3.org/TR/SVG11/paths.html#PathData), which the
function represents.

The [from
[\<coordinate-pair\>](#typedef-shape-coordinate-pair)] represents the starting point
for the first shape-command. It adds an initial [absolute
moveto](https://www.w3.org/TR/SVG/paths.html#PathDataMovetoCommands) to
the list of path data commands.

The sequence of
[[\<shape-command\>](#typedef-shape-command)]s represent further [path data
commands](https://www.w3.org/TR/SVG11/paths.html#PathData). Each
command's starting point is the previous command's ending point.

``` prod
<shape-command> = <move-command> | <line-command> | close |
 <horizontal-line-command> | <vertical-line-command> |
 <curve-command> | <smooth-command> | <arc-command>

<move-command> = move <command-end-point>
<line-command> = line <command-end-point>
<horizontal-line-command> = hline
 [ to [ <length-percentage> | left | center | right | x-start | x-end ]
 | by <length-percentage> ]
<vertical-line-command> = vline
 [ to [ <length-percentage> | top | center | bottom | y-start | y-end ]
 | by <length-percentage> ]
<curve-command> = curve
 [ [ to <position> with <control-point> [ / <control-point> ]? ]
 | [ by <coordinate-pair> with <relative-control-point> [ / <relative-control-point> ]? ] ]
<smooth-command> = smooth
 [ [ to <position> [ with <control-point> ]? ]
 | [ by <coordinate-pair> [ with <relative-control-point> ]? ] ]
<arc-command> = arc <command-end-point>
 [ [ of <length-percentage>{1,2} ]
 && <arc-sweep>? && <arc-size>? && [rotate <angle>]? ]

<command-end-point> = [ to <position> | by <coordinate-pair> ]
<control-point> = [ <position> | <relative-control-point> ]
<relative-control-point> = <coordinate-pair> [ from [ start | end | origin ] ]?
<coordinate-pair> = <length-percentage>{2}
<arc-sweep> = cw | ccw
<arc-size> = large | small
```

[[\<coordinate-pair\>](#typedef-shape-coordinate-pair)] = [\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage){2}
: Defines a pair of coordinates, representing a rightward and downward
 offset, respectively, from a specified reference point. Percentages
 are resolved against the width or height, respectively, of the
 [reference
 box](#basic-shape-reference-box).

[[\<command-end-point\>](#typedef-shape-command-end-point)] = \[ [to] [\<position\>](https://drafts.csswg.org/css-values-5/#typedef-position) \| [by] [\<coordinate-pair\>](#typedef-shape-coordinate-pair) \]

: Every command can be specified in \"absolute\" or \"relative\"
 coordinates, determined by their
 [by](#valdef-shape-by) or
 [to](#valdef-shape-to) component. [to]
 indicates that any
 [\<coordinate-pair\>](#typedef-shape-coordinate-pair)s in the command are relative to
 the top-left corner of the [reference
 box](#basic-shape-reference-box), while [by]
 indicates that the
 [\<coordinate-pair\>]s are relative to the command's starting point.

 [\<relative-control-point\>](#typedef-shape-relative-control-point) defines how
 [by](#valdef-shape-by) and
 [to](#valdef-shape-to) are interpreted for curve control points, while
 [\<horizontal-line-command\>](#typedef-shape-horizontal-line-command) and
 [\<vertical-line-command\>](#typedef-shape-vertical-line-command) define how
 [by] and
 [to] are interpreted for horizontal
 and vertical lines, respectively.

 When [to](#valdef-shape-to) is used, the coordinates can be specified as
 [\<position\>](https://drafts.csswg.org/css-values-5/#typedef-position)s instead of
 [\<coordinate-pair\>](#typedef-shape-coordinate-pair)s.

 In either case,
 [\<percentage\>](https://drafts.csswg.org/css-values-4/#percentage-value) values in
 [\<coordinate-pair\>](#typedef-shape-coordinate-pair)s are always computed relative to
 the [reference
 box's](#basic-shape-reference-box) size.

[[\<move-command\>](#typedef-shape-move-command)] = [move] [\<command-end-point\>](#typedef-shape-command-end-point)

: Adds a
 [moveto](https://www.w3.org/TR/SVG/paths.html#PathDataMovetoCommands)
 command to the list of path data commands, with an ending point
 specified by the
 [\<coordinate-pair\>](#typedef-shape-coordinate-pair).

 This draws nothing, and merely \"moves the pen\" for the next
 command.

 This starts a new subpath, for the purpose of the
 [close](#valdef-shape-close) command.

[[\<line-command\>](#typedef-shape-line-command)] = [line] [\<command-end-point\>](#typedef-shape-command-end-point)

: Adds a
 [lineto](https://www.w3.org/TR/SVG/paths.html#PathDataLinetoCommands)
 command to the list of path data commands, with an ending point
 specified by the
 [\<coordinate-pair\>](#typedef-shape-coordinate-pair).

 This draws a straight line from the command's starting point to its
 ending point.

[[\<horizontal-line-command\>](#typedef-shape-horizontal-line-command)] = hline \[ to \[ [\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage) \| left \| center \| right \| x-start \| x-end \] \| by [\<length-percentage\>] \]

: Adds a horizontal
 [lineto](https://www.w3.org/TR/SVG/paths.html#PathDataLinetoCommands)
 command to the list of path data commands.

 This is equivalent to a
 [line](#valdef-shape-line) command with the
 [\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage) given as the horizontal component
 of the
 [\<coordinate-pair\>](#typedef-shape-coordinate-pair). Specifying the horizontal
 component of
 [\<position\>](https://drafts.csswg.org/css-values-5/#typedef-position) instead of a
 [\<length-percentage\>]
 ([left](https://drafts.csswg.org/css-values-5/#valdef-position-left),
 [center](https://drafts.csswg.org/css-values-5/#valdef-position-center),
 [right](https://drafts.csswg.org/css-values-5/#valdef-position-right),
 [x-start](https://drafts.csswg.org/css-values-5/#valdef-position-x-start), or
 [x-end](https://drafts.csswg.org/css-values-5/#valdef-position-x-end)), would draw a line to that
 [\<position\>], with the
 [\<position\>]'s vertical
 component remaining the same as the starting point.

[[\<vertical-line-command\>](#typedef-shape-vertical-line-command)] = vline \[ to \[ [\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage) \| top \| center \| bottom \| y-start \| y-end \] \| by [\<length-percentage\>] \]

: Adds a vertical
 [lineto](https://www.w3.org/TR/SVG/paths.html#PathDataLinetoCommands)
 command to the list of path data commands.

 This is equivalent to a
 [line](#valdef-shape-line) command with the
 [\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage) given as the vertical component
 of the
 [\<coordinate-pair\>](#typedef-shape-coordinate-pair). Specifying the horizontal
 component of
 [\<position\>](https://drafts.csswg.org/css-values-5/#typedef-position)
 ([top](https://drafts.csswg.org/css-values-5/#valdef-position-top),
 [center](https://drafts.csswg.org/css-values-5/#valdef-position-center),
 [bottom](https://drafts.csswg.org/css-values-5/#valdef-position-bottom),
 [y-start](https://drafts.csswg.org/css-values-5/#valdef-position-y-start), or
 [y-end](https://drafts.csswg.org/css-values-5/#valdef-position-y-end)) instead of a
 [\<length-percentage\>], would draw a line to that
 [\<position\>], with the
 [\<position\>]'s horizontal
 component remaining the same as the starting point.

[[\<curve-command\>](#typedef-shape-curve-command)] = [curve] \[ \[ to [\<position\>](https://drafts.csswg.org/css-values-5/#typedef-position) with [\<control-point\>](#typedef-shape-control-point) \[ / [\<control-point\>] \]? \] \| \[ by [\<coordinate-pair\>](#typedef-shape-coordinate-pair) with [\<relative-control-point\>](#typedef-shape-relative-control-point) \[ / [\<relative-control-point\>] \]? \] \]

: Adds a Bézier curve command to the list of path data commands,
 ending at the point specified by the
 [\<position\>](https://drafts.csswg.org/css-values-5/#typedef-position) following the
 [to](#valdef-shape-to) keyword, or the
 [\<coordinate-pair\>](#typedef-shape-coordinate-pair) following the
 [by](#valdef-shape-by) keyword, as specified by
 [\<command-end-point\>](#typedef-shape-command-end-point).

 The [with] component specifies control points for the curve:
 if a single
 [\<control-point\>](#typedef-shape-control-point) or
 [\<relative-control-point\>](#typedef-shape-relative-control-point) is provided, the command
 specifies a [quadratic
 curve](https://www.w3.org/TR/SVG/paths.html#PathDataQuadraticBezierCommands);
 if two [\<control-point\>]s or
 [\<relative-control-point\>]s are provided, it specifies a [cubic
 curve](https://www.w3.org/TR/SVG/paths.html#PathDataCubicBezierCommands).

[[\<smooth-command\>](#typedef-shape-smooth-command)] = [smooth] \[ \[ to [\<position\>](https://drafts.csswg.org/css-values-5/#typedef-position) \[with [\<control-point\>](#typedef-shape-control-point) \]? \] \| \[ by [\<coordinate-pair\>](#typedef-shape-coordinate-pair) \[ with [\<relative-control-point\>](#typedef-shape-relative-control-point) \]? \] \]

: Adds a smooth Bézier curve command to the list of path data
 commands, ending at the point specified by the
 [\<position\>](https://drafts.csswg.org/css-values-5/#typedef-position) following the
 [to](#valdef-shape-to) keyword, or the
 [\<coordinate-pair\>](#typedef-shape-coordinate-pair) following the
 [by](#valdef-shape-by) keyword, as specified by
 [\<command-end-point\>](#typedef-shape-command-end-point). The [with] component
 specifies control points for the curve: if it's omitted, the command
 specifies a [smooth quadratic
 curve](https://www.w3.org/TR/SVG/paths.html#PathDataQuadraticBezierCommands);
 if it's provided, if specifies a [smooth cubic
 curve](https://www.w3.org/TR/SVG/paths.html#PathDataCubicBezierCommands).

 A
 [smooth](#valdef-shape-smooth) command is equivalent to a
 [curve](#valdef-shape-curve) command with the first control point
 automatically specified as the reflection of the previous curve's
 second control point around the starting point, or as the starting
 point if the previous path data command wasn't a curve. This ensures
 G1 continuity with the previous command, so the curve appears to
 smoothly continue from the previous command, rather than possibly
 making a sudden direction change.

[[\<control-point\>](#typedef-shape-control-point)] = \[ [\<position\>](https://drafts.csswg.org/css-values-5/#typedef-position) \| [\<relative-control-point\>](#typedef-shape-relative-control-point) \]
: Provides a control point to a quadratic or cubic Bézier curve.

[[\<relative-control-point\>](#typedef-shape-relative-control-point)] = [\<coordinate-pair\>](#typedef-shape-coordinate-pair) \[ from \[ start \| end \| origin \] \]?
: Provides a control point to a quadratic or cubic Bézier curve. When
 a [from] keyword is specified followed by [start],
 [end], or [origin], the given
 [\<coordinate-pair\>](#typedef-shape-coordinate-pair) is relative to the command's
 starting point, the command's end point, or the [reference
 box](#basic-shape-reference-box), respectively. If such component is not provided,
 the [\<coordinate-pair\>] is relative to the segment's start.

[[\<arc-command\>](#typedef-shape-arc-command)] = [arc] [\<command-end-point\>](#typedef-shape-command-end-point) \[of [\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage){1,2}\] && [\<arc-sweep\>](#typedef-shape-arc-sweep)? && [\<arc-size\>](#typedef-shape-arc-size)? && rotate [\<angle\>](https://drafts.csswg.org/css-values-4/#angle-value)? \]

: Add an [elliptical
 arc](https://www.w3.org/TR/SVG/paths.html#PathDataEllipticalArcCommands)
 command to the list of path data commands, ending at the
 [\<command-end-point\>](#typedef-shape-command-end-point).

 The [of] component specifies the size of the ellipse that the
 arc is taken from. The first
 [\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage) provides the horizontal radius of
 the ellipse and the second provides the vertical radius. Like for
 [\<coordinate-pair\>](#typedef-shape-coordinate-pair)s,
 [\<percentage\>](https://drafts.csswg.org/css-values-4/#percentage-value) values are resolved against the
 width or height of the [reference
 box](#basic-shape-reference-box), as appropriate.

 If only one
 [\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage) is provided, both radiuses use
 the provided value. In that case,
 [\<percentage\>](https://drafts.csswg.org/css-values-4/#percentage-value) values are resolved against the
 [direction-agnostic
 size](#direction-agnostic-size) of the [reference
 box](#basic-shape-reference-box) (similar to the
 [circle()](#funcdef-basic-shape-circle) function).

 :::
 Note that SVG has [some specific error-handling for the ellipse
 radiuses](https://w3c.github.io/svgwg/svg2-draft/paths.html#ArcOutOfRangeParameters):
 - if the endpoint is the same as the starting point, the command
 does nothing

 - if either radius is zero, the command is equivalent to a
 [\<line-command\>](#typedef-shape-line-command) to the ending point

 - if either radius is negative, its absolute value is used instead

 - if the radiuses don't describe an ellipse large enough to
 intersect both the starting point and ending point (after rotation
 by the specified
 [\<angle\>](https://drafts.csswg.org/css-values-4/#angle-value)), they are scaled up uniformly
 until the ellipse is just large enough to reach.
 :::

 The ellipse described by the specified radiuses defaults to being
 axis-aligned, but can be rotated by specifying an
 [\<angle\>](https://drafts.csswg.org/css-values-4/#angle-value). Similar to the
 [rotate()](https://drafts.csswg.org/css-transforms-1/#funcdef-transform-rotate) transform function, positive angles specify
 a clockwise rotation, and negative angles specify a counterclockwise
 rotation. If omitted, this defaults to [0deg].

 The ending point, radiuses, and angle, taken together, usually
 define two possible ellipses that intersect the starting point and
 ending point, and each ellipse can be traced in either direction,
 for a total of four possible arcs. The
 [\<arc-sweep\>](#typedef-shape-arc-sweep) and
 [\<arc-size\>](#typedef-shape-arc-size) components specify which of these
 arcs is desired:

 - [[\<arc-sweep\>](#typedef-shape-arc-sweep)] can
 be [cw] or
 [ccw], indicating
 that the arc that is traced around the ellipse clockwise or
 counter-clockwise from the center, respectively, must be chosen.
 If omitted, this defaults to
 [ccw](#valdef-shape-ccw).

 In the SVG arc command,
 [cw](#valdef-shape-cw) corresponds to the value 1 for the sweep flag,
 and [ccw](#valdef-shape-ccw) to the value 0.

 - [[\<arc-size\>](#typedef-shape-arc-size)] can
 be [large] or
 [small], indicating
 that the larger or smaller, respectively, of the two possible arcs
 must be chosen. If omitted, this defaults to
 [small](#valdef-shape-small).

 In the SVG arc command,
 [large](#valdef-shape-large) corresponds to the value 1 for the large flag,
 and [small](#valdef-shape-small) to the 0.

 If the starting and ending points are on exactly
 opposite sides of the ellipse, both possible arcs are the same
 size, but also there is only one possible ellipse. In this case,
 the
 [\<arc-sweep\>](#typedef-shape-arc-sweep) distinguishes which of the two
 possible arcs will be chosen, and
 [\<arc-size\>](#typedef-shape-arc-size) has no effect.

 ![A depiction of the two possible ellipses, and four possible arcs,
 that can be chosen
 between.](images/four-arcs.svg){a}

[close]

: Adds a
 [closepath](https://www.w3.org/TR/SVG/paths.html#PathDataClosePathCommand)
 command to the list of path data commands.

 This is similar to a
 [line](#valdef-shape-line) command with its ending point set to the starting
 point of the subpath. When specifying a raw shape, they're
 identical, but if the path is stroked, the ending point of the
 [close](#valdef-shape-close) command is smoothly joined with the start of the
 subpath, which affects how line-joins and line-caps are rendered.

##### 3.1.1.1. Using [shape() to create responsive, parametric speech bubble]
The
[shape()](#funcdef-basic-shape-shape) function enables shapes that are responsive,
rather than scalable. While the
[polygon()](#funcdef-basic-shape-polygon) shape is also responsive, it only support simple
rounded corners and not complex curves.

To demonstrate, let's start with a speech bubble, such as the following:

![A speech bubble shape](images/bubble.svg){style="background: unset"
width="300"}

Using this shape with a [clip-path] can be done by using the
[path()](#funcdef-basic-shape-path) function:

``` highlight
.bubble { clip-path: path("m 5 0 H 95 Q 100 0 100 5 V 92 Q 100 97 95 97 H 70 l -2 3 l -2 -3 H 5 Q 0 97 0 92 V 5 Q 0 0 5 0") };
```

Altohugh this path can easily scale, the scaled results are not always
desirable. e.g. when scaled to a small balloon, the arrow and corners
are scaled to become almost invisible:

![scled-down speech bubble
shape](images/bubble.svg){style="background: unset" width="100"}

To construct this shape using the
[shape()](#funcdef-basic-shape-shape) function, let's start by turning all the pixel
values from the [path] function to percentages. Note that the
[shape()] function begins
with [from]:

``` highlight
.bubble { clip-path: shape( from 5% 0%,
 hline to 95%,
 curve to 100% 5% with 100% 0%,
 vline to 92%,
 curve to 95% 97% with 100% 97%,
 hline to 70%,
 line by -2% 3%,
 line by -2% -3%,
 hline to 5%,
 curve to 0% 92% with 0% 97%,
 vline to 5%,
 curve to 5% 0% with 0% 0%); }
```

To make this path responsive, as in, respond well to size changes, we
will convert some of its units to
[px](https://drafts.csswg.org/css-values-4/#px) values, specifically the ones the control the curves
and arrows:

``` highlight
.bubble { clip-path: shape( from 5px 0%,
 hline to calc(100% - 5px),
 curve to 100% 5px with 100% 0%,
 vline to calc(100% - 8px),
 curve to calc(100% - 5px) calc(100% - 3px) with 100% calc(100% - 3px),
 hline to 70%,
 line by -2px 3px,
 line by -2px -3px,
 hline to 5px,
 curve to 0% calc(100% - 8px) with 0% calc(100% - 3px),
 vline to 5px,
 curve to 5px 0% with 0% 0%); }
```

When applied as [clip-path], it would looks like the following:

![A speech bubble shape, using
clip-path](images/bubble-50.svg){style="background: unset" width="150"}

The whole speech bubble is scaled to the reference box, while the curves
and arrows stay more constant.

Since
[shape()](#funcdef-basic-shape-shape) uses CSS units, we can replace some of the edges
with [position] values:

``` highlight
.bubble { clip-path: shape(from 5px 0,
 hline to calc(100% - 5px),
 curve to right 5px with right top,
 vline to calc(100% - 8px),
 curve to calc(100% - 5px) calc(100% - 3px) with right calc(100% - 3px),
 hline to 70%,
 line by -2px 3px,
 line by -2px -3px,
 hline to 5px,
 curve to left calc(100% - 8px) with left calc(100% - 3px),
 vline to 5px,
 curve to 5px top with left top); }
```

Another useful feature of
[shape()](#funcdef-basic-shape-shape) is that it can be used alongside CSS properties.
In this case, we can make the arrow and radius parametric:

``` highlight
:root {
 --radius: 5px;
 --arrow-length: 3px;
 --arrow-half-width: 2px;
 --arrow-position: 70%;
 --arrow-bottom-offset: calc(100% - var(--radius) - var(--arrow-length));
}

.bubble {
 animation: bubble 100ms;
 clip-path: shape(from var(---radius) top,
 hline to calc(100% - var(---radius)),
 curve to right var(---radius) with right top,
 vline to var(---arrow-bottom-offset),
 curve to calc(100% - var(---radius)) calc(100% - var(---arrow-length))
 with right calc(100% - var(---arrow-length)),
 hline to var(---arrow-position),
 line by var(---arrow-half-width) var(---arrow-length),
 line by var(---arrow-half-width) calc(0px - var(---arrow-length)),
 hline to var(---radius),
 curve to left var(---arrow-bottom-offset) with left calc(100% - var(---arrow-length)),
 vline to var(---radius),
 curve to var(---radius) top with left top); }
```

##### 3.1.1.2. Interpolating the [shape() Function]
[shape()](#funcdef-basic-shape-shape) and
[path()](#funcdef-basic-shape-path) functions can be
[interpolated](https://drafts.csswg.org/css-values-4/#interpolation) with each other if their associated list of path data
commands is the same length and has the same commands, in order, with
the first command of the [path()] function interpolating with the initial
[\<coordinate-pair\>](#typedef-shape-coordinate-pair) in the
[shape()] function.

 The first command of a
[path()](#funcdef-basic-shape-path) function is guaranteed to be a
[move](#valdef-shape-move), see
[moveTo](https://www.w3.org/TR/SVG2/paths.html#PathDataMovetoCommands)
in the SVG spec.

If the starting and ending values are both
[path()](#funcdef-basic-shape-path) functions, the interpolated value is a
[path()] function; otherwise
it's a
[shape()](#funcdef-basic-shape-shape) function. In either case, the interpolated value
must represent the same list of path data commands, with each command
having its numerical components interpolated between the corresponding
components of the starting and ending list.

For this purpose, commands are \"the same\" if they use the same command
keyword, and use the same [\<by-to\>] keyword. For
[curve](#valdef-shape-curve) and
[smooth](#valdef-shape-smooth), they also must have the same number of control
points.

If an [arc](#valdef-shape-arc) command has different
[\<arc-sweep\>](#typedef-shape-arc-sweep) between its starting and ending list,
then the interpolated result uses
[cw](#valdef-shape-cw)
for any progress value between 0 and 1. If it has different
[\<arc-size\>](#typedef-shape-arc-size) keywords, then the interpolated
result uses [large](#valdef-shape-large) for any progress value between 0 and 1.

 The [arc](#valdef-shape-arc) keyword interpolation rules are meant to match
existing SVG
[`path`](https://svgwg.org/specs/paths/#elementdef-path) interpolation rules.

### 3.2. Computed Values of Basic Shapes

The values in a
[\<basic-shape\>](#typedef-basic-shape) function are computed as specified,
with these exceptions:

- Omitted values are included and compute to their defaults.

- A
 [\<position\>](https://drafts.csswg.org/css-values-5/#typedef-position) value in
 [circle()](#funcdef-basic-shape-circle) or
 [ellipse()](#funcdef-basic-shape-ellipse) is computed as a pair of offsets (horizontal
 then vertical) from the top left origin, each given as a
 [\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage).

- A
 [\<\'border-radius\'\>](https://drafts.csswg.org/css-backgrounds-3/#propdef-border-radius) value in a
 [\<basic-shape-rect\>](#typedef-basic-shape-rect) function is computed as an expanded
 list of all eight
 [\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage) values.

- All
 [\<basic-shape-rect\>](#typedef-basic-shape-rect) functions compute to the equivalent
 [inset()](#funcdef-basic-shape-inset) function.

 Given [rect(t r b l)], the equivalent function
 is [inset(t calc(100% - r) calc(100% - b) l)]. Given [xywh(x y w
 h)], the equivalent function is [inset(y calc(100% - x - w)
 calc(100% - y - h) x)].

Tests

- [shape-image-threshold-computed.html](https://wpt.fyi/results/css/css-shapes/parsing/shape-image-threshold-computed.html "css/css-shapes/parsing/shape-image-threshold-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/parsing/shape-image-threshold-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/parsing/shape-image-threshold-computed.html)
- [shape-margin-computed.html](https://wpt.fyi/results/css/css-shapes/parsing/shape-margin-computed.html "css/css-shapes/parsing/shape-margin-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/parsing/shape-margin-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/parsing/shape-margin-computed.html)
- [shape-outside-computed.html](https://wpt.fyi/results/css/css-shapes/parsing/shape-outside-computed.html "css/css-shapes/parsing/shape-outside-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/parsing/shape-outside-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/parsing/shape-outside-computed.html)
- [circle-function-computed.html](https://wpt.fyi/results/css/css-shapes/shape-functions/circle-function-computed.html "css/css-shapes/shape-functions/circle-function-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-functions/circle-function-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-functions/circle-function-computed.html)
- [ellipse-function-computed.html](https://wpt.fyi/results/css/css-shapes/shape-functions/ellipse-function-computed.html "css/css-shapes/shape-functions/ellipse-function-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-functions/ellipse-function-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-functions/ellipse-function-computed.html)
- [inset-function-computed.html](https://wpt.fyi/results/css/css-shapes/shape-functions/inset-function-computed.html "css/css-shapes/shape-functions/inset-function-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-functions/inset-function-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-functions/inset-function-computed.html)
- [path-function-computed.html](https://wpt.fyi/results/css/css-shapes/shape-functions/path-function-computed.html "css/css-shapes/shape-functions/path-function-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-functions/path-function-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-functions/path-function-computed.html)
- [polygon-function-computed.html](https://wpt.fyi/results/css/css-shapes/shape-functions/polygon-function-computed.html "css/css-shapes/shape-functions/polygon-function-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-functions/polygon-function-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-functions/polygon-function-computed.html)
- [rect-function-computed.html](https://wpt.fyi/results/css/css-shapes/shape-functions/rect-function-computed.html "css/css-shapes/shape-functions/rect-function-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-functions/rect-function-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-functions/rect-function-computed.html)
- [xywh-function-computed.html](https://wpt.fyi/results/css/css-shapes/shape-functions/xywh-function-computed.html "css/css-shapes/shape-functions/xywh-function-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-functions/xywh-function-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-functions/xywh-function-computed.html)
- [shape-outside-computed-shape-000.html](https://wpt.fyi/results/css/css-shapes/shape-outside/values/shape-outside-computed-shape-000.html "css/css-shapes/shape-outside/values/shape-outside-computed-shape-000.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/values/shape-outside-computed-shape-000.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/values/shape-outside-computed-shape-000.html)
- [shape-outside-computed-shape-001.html](https://wpt.fyi/results/css/css-shapes/shape-outside/values/shape-outside-computed-shape-001.html "css/css-shapes/shape-outside/values/shape-outside-computed-shape-001.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/values/shape-outside-computed-shape-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/values/shape-outside-computed-shape-001.html)

### 3.3. Serialization of Basic Shapes

To serialize the
[\<basic-shape\>](#typedef-basic-shape) functions, serialize as per their
individual grammars, in the order the grammars are written in, joining
space-separated tokens with a single space, and following each
serialized comma with a single space. For serializing [computed
values](https://drafts.csswg.org/css-cascade-5/#computed-value), component values are
[computed], and omitted when possible without
changing the meaning.

As [specified
value](https://drafts.csswg.org/css-cascade-5/#specified-value) serialization of the shape functions are relatively
trivial, here are some examples of [computed
value](https://drafts.csswg.org/css-cascade-5/#computed-value) serializations for
[circle()](#funcdef-basic-shape-circle) notations when used in
[shape-outside](#propdef-shape-outside):

- [\<position\>](https://drafts.csswg.org/css-values-5/#typedef-position) [serialization
 rules](https://drafts.csswg.org/css-values-4/#position-serialization)
 mean that keywords [compute
 to](https://drafts.csswg.org/css-cascade-5/#computed-value) percentages, and serialize in horizontal-vertical
 order.

 circle(at bottom left)
 /* serializes to */
 circle(at 0% 100%)

- Omitting optional components means that default values do not show up
 in the serialization.

 circle(closest-side at center)
 /* serializes to */
 circle()

- Value [computation](https://drafts.csswg.org/css-cascade-5/#computed)
 means that some functions [canonicalize to a different
 form](#basic-shape-computed-values).

 rect(10px 20px 30px 40px)
 /* serializes to */
 inset(10px calc(100% - 20px) calc(100% - 30px) 40px)

- [basic-shape-circle-ellipse-serialization.html](https://wpt.fyi/results/css/css-shapes/basic-shape-circle-ellipse-serialization.html "css/css-shapes/basic-shape-circle-ellipse-serialization.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/basic-shape-circle-ellipse-serialization.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/basic-shape-circle-ellipse-serialization.html)

### 3.4. Interpolation of Basic Shapes

For interpolating between one basic shape and a second, the rules below
are applied. The values in the shape functions interpolate [by computed
value](https://www.w3.org/TR/web-animations-1/#by-computed-value). The
list values interpolate as length, percentage, or calc where possible.
If list values are not one of those types but are identical (such as
finding
[nonzero](https://drafts.csswg.org/css-masking-1/#valdef-clip-rule-nonzero) in the same list position in both lists) those
values do interpolate.

- Both shapes must use the same [reference
 box](#basic-shape-reference-box).
- If both shapes are the same type, that type is
 [ellipse()](#funcdef-basic-shape-ellipse) or
 [circle()](#funcdef-basic-shape-circle), and the radiuses are specified as
 [\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage) (rather than keywords), interpolate
 between each value in the shape functions.
- If both shapes are of type
 [inset()](#funcdef-basic-shape-inset), interpolate between each value in the shape
 functions.
- If both shapes are of type
 [polygon()](#funcdef-basic-shape-polygon), both polygons have the same number of
 vertices, and use the same
 [\<\'fill-rule\'\>](https://w3c.github.io/svgwg/svg2-draft/painting.html#FillRuleProperty), interpolate between each value
 in the shape functions.
- In all other cases no interpolation is specified.

Tests

- [shape-image-threshold-interpolation.html](https://wpt.fyi/results/css/css-shapes/animation/shape-image-threshold-interpolation.html "css/css-shapes/animation/shape-image-threshold-interpolation.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/animation/shape-image-threshold-interpolation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/animation/shape-image-threshold-interpolation.html)
- [shape-margin-composition.html](https://wpt.fyi/results/css/css-shapes/animation/shape-margin-composition.html "css/css-shapes/animation/shape-margin-composition.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/animation/shape-margin-composition.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/animation/shape-margin-composition.html)
- [shape-margin-interpolation.html](https://wpt.fyi/results/css/css-shapes/animation/shape-margin-interpolation.html "css/css-shapes/animation/shape-margin-interpolation.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/animation/shape-margin-interpolation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/animation/shape-margin-interpolation.html)
- [shape-outside-composition.html](https://wpt.fyi/results/css/css-shapes/animation/shape-outside-composition.html "css/css-shapes/animation/shape-outside-composition.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/animation/shape-outside-composition.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/animation/shape-outside-composition.html)
- [shape-outside-interpolation.html](https://wpt.fyi/results/css/css-shapes/animation/shape-outside-interpolation.html "css/css-shapes/animation/shape-outside-interpolation.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/animation/shape-outside-interpolation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/animation/shape-outside-interpolation.html)
- [basic-shape-interpolation.html](https://wpt.fyi/results/css/css-shapes/basic-shape-interpolation.html "css/css-shapes/basic-shape-interpolation.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/basic-shape-interpolation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/basic-shape-interpolation.html)

## 4. Shapes from Image

Another way of defining shapes is by specifying a source
[\<image\>](https://drafts.csswg.org/css-images-3/#typedef-image) whose alpha channel is used to
compute the shape. The shape is computed to be the path or paths that
enclose the area(s) where the opacity of the specified image is greater
than the
[shape-image-threshold](#propdef-shape-image-threshold) value. The absence of any pixels
with an alpha value greater than the specified threshold results in an
empty float area that will not affect wrapping. If the
[shape-image-threshold] is not specified, the initial value to be considered is 0.0.

The image is sized and positioned as if it were a replaced element whose
specified width and height are the same as the element's used content
box size.

For animated raster image formats (such as
[GIF](http://www.w3.org/Graphics/GIF/spec-gif89a.txt)), the first frame
of the animation sequence is used.

An image is floating to the left of a paragraph. The image shows the 3D
version of the CSS logo over a transparent background. The logo has a
shadow using an alpha-channel.

The image defines its [float area](#float-area) through the
[shape-outside](#propdef-shape-outside) property.

 <p>
 <img id="CSSlogo" src="CSS-logo1s.png"/>
 blah blah blah blah...
 </p>

 <style>
 #CSSlogo {
 float: left;
 shape-outside: attr(src url);
 shape-image-threshold: 0.1;
 }
 </style>

The
[shape-outside](#propdef-shape-outside) property re-uses the url from the
src attribute of the img element.

It is perfectly possible to display an image and use a different image
for its [float area](#float-area).

In the figure below, the alpha-channel threshold is represented by the
dotted line around the CSS logo.

It's then possible to affect where the lines of the paragraph start in
three ways:

1. Modifying the alpha channel in the image
2. Changing the value of the
 [shape-image-threshold](#propdef-shape-image-threshold) property
3. Changing the value of the
 [shape-margin](#propdef-shape-margin) property (see example 8)

![A float shape around an image using its
alpha-channel.](images/shape-outside-image.png){a
height="251" style="width:70%" width="582"}

- [shape-image-threshold-interpolation.html](https://wpt.fyi/results/css/css-shapes/animation/shape-image-threshold-interpolation.html "css/css-shapes/animation/shape-image-threshold-interpolation.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/animation/shape-image-threshold-interpolation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/animation/shape-image-threshold-interpolation.html)
- [shape-image-threshold-computed.html](https://wpt.fyi/results/css/css-shapes/parsing/shape-image-threshold-computed.html "css/css-shapes/parsing/shape-image-threshold-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/parsing/shape-image-threshold-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/parsing/shape-image-threshold-computed.html)
- [shape-image-threshold-invalid.html](https://wpt.fyi/results/css/css-shapes/parsing/shape-image-threshold-invalid.html "css/css-shapes/parsing/shape-image-threshold-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/parsing/shape-image-threshold-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/parsing/shape-image-threshold-invalid.html)
- [shape-image-threshold-valid.html](https://wpt.fyi/results/css/css-shapes/parsing/shape-image-threshold-valid.html "css/css-shapes/parsing/shape-image-threshold-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/parsing/shape-image-threshold-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/parsing/shape-image-threshold-valid.html)
- [float-retry-push-image.html](https://wpt.fyi/results/css/css-shapes/shape-outside/assorted/float-retry-push-image.html "css/css-shapes/shape-outside/assorted/float-retry-push-image.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/assorted/float-retry-push-image.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/assorted/float-retry-push-image.html)
- [shape-outside-linear-gradient-001.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-001.html "css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-001.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-001.html)
- [shape-outside-linear-gradient-002.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-002.html "css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-002.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-002.html)
- [shape-outside-linear-gradient-003.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-003.html "css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-003.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-003.html)
- [shape-outside-linear-gradient-004.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-004.html "css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-004.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-004.html)
- [shape-outside-linear-gradient-005.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-005.html "css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-005.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-005.html)
- [shape-outside-linear-gradient-006.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-006.html "css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-006.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-006.html)
- [shape-outside-linear-gradient-007.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-007.html "css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-007.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-007.html)
- [shape-outside-linear-gradient-008.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-008.html "css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-008.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-008.html)
- [shape-outside-linear-gradient-009.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-009.html "css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-009.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-009.html)
- [shape-outside-linear-gradient-010.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-010.html "css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-010.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-010.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-010.html)
- [shape-outside-linear-gradient-011.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-011.html "css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-011.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-011.html)
- [shape-outside-linear-gradient-012.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-012.html "css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-012.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-012.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-012.html)
- [shape-outside-linear-gradient-013.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-013.html "css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-013.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-013.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-013.html)
- [shape-outside-linear-gradient-014.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-014.html "css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-014.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-014.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-014.html)
- [shape-outside-linear-gradient-015.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-015.html "css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-015.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-015.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-015.html)
- [shape-outside-linear-gradient-016.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-016.html "css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-016.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-016.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-016.html)
- [shape-outside-radial-gradient-001.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-radial-gradient-001.html "css/css-shapes/shape-outside/shape-image/gradients/shape-outside-radial-gradient-001.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-radial-gradient-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-radial-gradient-001.html)
- [shape-outside-radial-gradient-002.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-radial-gradient-002.html "css/css-shapes/shape-outside/shape-image/gradients/shape-outside-radial-gradient-002.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-radial-gradient-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-radial-gradient-002.html)
- [shape-outside-radial-gradient-003.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-radial-gradient-003.html "css/css-shapes/shape-outside/shape-image/gradients/shape-outside-radial-gradient-003.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-radial-gradient-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-radial-gradient-003.html)
- [shape-outside-radial-gradient-004.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-radial-gradient-004.html "css/css-shapes/shape-outside/shape-image/gradients/shape-outside-radial-gradient-004.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-radial-gradient-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-radial-gradient-004.html)
- [shape-image-000.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-image/shape-image-000.html "css/css-shapes/shape-outside/shape-image/shape-image-000.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-image/shape-image-000.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-image/shape-image-000.html)
- [shape-image-001.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-image/shape-image-001.html "css/css-shapes/shape-outside/shape-image/shape-image-001.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-image/shape-image-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-image/shape-image-001.html)
- [shape-image-002.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-image/shape-image-002.html "css/css-shapes/shape-outside/shape-image/shape-image-002.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-image/shape-image-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-image/shape-image-002.html)
- [shape-image-003.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-image/shape-image-003.html "css/css-shapes/shape-outside/shape-image/shape-image-003.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-image/shape-image-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-image/shape-image-003.html)
- [shape-image-004.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-image/shape-image-004.html "css/css-shapes/shape-outside/shape-image/shape-image-004.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-image/shape-image-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-image/shape-image-004.html)
- [shape-image-005.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-image/shape-image-005.html "css/css-shapes/shape-outside/shape-image/shape-image-005.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-image/shape-image-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-image/shape-image-005.html)
- [shape-image-006.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-image/shape-image-006.html "css/css-shapes/shape-outside/shape-image/shape-image-006.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-image/shape-image-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-image/shape-image-006.html)
- [shape-image-007.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-image/shape-image-007.html "css/css-shapes/shape-outside/shape-image/shape-image-007.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-image/shape-image-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-image/shape-image-007.html)
- [shape-image-008.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-image/shape-image-008.html "css/css-shapes/shape-outside/shape-image/shape-image-008.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-image/shape-image-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-image/shape-image-008.html)
- [shape-image-009.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-image/shape-image-009.html "css/css-shapes/shape-outside/shape-image/shape-image-009.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-image/shape-image-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-image/shape-image-009.html)
- [shape-image-010.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-image/shape-image-010.html "css/css-shapes/shape-outside/shape-image/shape-image-010.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-image/shape-image-010.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-image/shape-image-010.html)
- [shape-image-011.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-image/shape-image-011.html "css/css-shapes/shape-outside/shape-image/shape-image-011.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-image/shape-image-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-image/shape-image-011.html)
- [shape-image-012.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-image/shape-image-012.html "css/css-shapes/shape-outside/shape-image/shape-image-012.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-image/shape-image-012.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-image/shape-image-012.html)
- [shape-image-013.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-image/shape-image-013.html "css/css-shapes/shape-outside/shape-image/shape-image-013.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-image/shape-image-013.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-image/shape-image-013.html)
- [shape-image-014.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-image/shape-image-014.html "css/css-shapes/shape-outside/shape-image/shape-image-014.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-image/shape-image-014.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-image/shape-image-014.html)
- [shape-image-015.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-image/shape-image-015.html "css/css-shapes/shape-outside/shape-image/shape-image-015.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-image/shape-image-015.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-image/shape-image-015.html)
- [shape-image-016.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-image/shape-image-016.html "css/css-shapes/shape-outside/shape-image/shape-image-016.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-image/shape-image-016.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-image/shape-image-016.html)
- [shape-image-017.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-image/shape-image-017.html "css/css-shapes/shape-outside/shape-image/shape-image-017.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-image/shape-image-017.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-image/shape-image-017.html)
- [shape-image-018.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-image/shape-image-018.html "css/css-shapes/shape-outside/shape-image/shape-image-018.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-image/shape-image-018.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-image/shape-image-018.html)
- [shape-image-019.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-image/shape-image-019.html "css/css-shapes/shape-outside/shape-image/shape-image-019.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-image/shape-image-019.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-image/shape-image-019.html)
- [shape-image-020.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-image/shape-image-020.html "css/css-shapes/shape-outside/shape-image/shape-image-020.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-image/shape-image-020.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-image/shape-image-020.html)
- [shape-image-021.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-image/shape-image-021.html "css/css-shapes/shape-outside/shape-image/shape-image-021.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-image/shape-image-021.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-image/shape-image-021.html)
- [shape-image-022.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-image/shape-image-022.html "css/css-shapes/shape-outside/shape-image/shape-image-022.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-image/shape-image-022.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-image/shape-image-022.html)
- [shape-image-023.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-image/shape-image-023.html "css/css-shapes/shape-outside/shape-image/shape-image-023.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-image/shape-image-023.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-image/shape-image-023.html)
- [shape-image-024.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-image/shape-image-024.html "css/css-shapes/shape-outside/shape-image/shape-image-024.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-image/shape-image-024.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-image/shape-image-024.html)
- [shape-image-025.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-image/shape-image-025.html "css/css-shapes/shape-outside/shape-image/shape-image-025.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-image/shape-image-025.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-image/shape-image-025.html)
- [shape-image-026.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-image/shape-image-026.html "css/css-shapes/shape-outside/shape-image/shape-image-026.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-image/shape-image-026.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-image/shape-image-026.html)
- [shape-image-027.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-image/shape-image-027.html "css/css-shapes/shape-outside/shape-image/shape-image-027.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-image/shape-image-027.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-image/shape-image-027.html)
- [shape-image-028.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-image/shape-image-028.html "css/css-shapes/shape-outside/shape-image/shape-image-028.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-image/shape-image-028.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-image/shape-image-028.html)
- [shape-image-029.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-image/shape-image-029.html "css/css-shapes/shape-outside/shape-image/shape-image-029.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-image/shape-image-029.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-image/shape-image-029.html)

## 5. Shapes from Box Values

Shapes can be defined by reference to edges in the [CSS Box
Model](https://www.w3.org/TR/css-box-3/#box-model). These edges include
[border-radius
curvature](https://www.w3.org/TR/css3-background/#corner-shaping)
[\[CSS3BG\]](#biblio-css3bg "CSS Backgrounds and Borders Module Level 3")
from the used border-radius values. The
[\<shape-box\>](#typedef-shape-box) value extends the
[\<visual-box\>](https://drafts.csswg.org/css-box-4/#typedef-visual-box) value to include
[margin-box](#valdef-shape-box-margin-box). Its syntax is:

``` prod
<shape-box> = <visual-box> | margin-box | half-border-box
```

The definitions of the values are:

The [margin-box] value
defines the shape enclosed by the outside margin edge. The corner radii
of this shape are determined by the corresponding border-radius and
margin values. If the ratio of `border-radius/margin` is 1 or more, or
margin is negative or zero, then the margin box corner radius is
`max(border-radius + margin, 0)`. The margin box's corners are
[outset-adjusted](https://drafts.csswg.org/css-backgrounds-3/#outset-adjusted-border-radius) given the element's [border
box](https://drafts.csswg.org/css-box-4/#border-box),
[border-radius](https://drafts.csswg.org/css-backgrounds-3/#propdef-border-radius), and the margin.

The [border-box] value
defines the shape enclosed by the outside border edge. This shape
follows all of the normal border radius shaping rules for the outside of
the border.

The [padding-box] value
defines the shape enclosed by the outside padding edge. This shape
follows all of the normal border radius shaping rules for the inside of
the border.

The [content-box] value
defines the shape enclosed by the outside content edge. Each corner
radius of this box is the larger of 0 or
`border-radius - border-width - padding`.

The [half-border-box] value defines the shape enclosed by a box that is in the
middle between the
[padding-box](#valdef-shape-box-padding-box) and the
[border-box](#valdef-shape-box-border-box).

Given the 100px square below with 10px padding, border and margins, the
box values define these shapes:

- [margin-box](#valdef-shape-box-margin-box): the shape containing all of the yellow pixels
- [border-box](#valdef-shape-box-border-box): the shape containing all of the black pixels
- [padding-box](#valdef-shape-box-padding-box): the shape containing all of the mauve pixels
- [content-box](#valdef-shape-box-content-box): the shape containing all of the blue pixels

![Simple CSS Box Model
Edges](images/box-edges-simple.png){a
height="177" width="178"}

And the same definitions apply to a more complex example with the same
100px square, but with these border, padding and margin properties:

 border-radius: 20px 20px 20px 40px;
 border-width: 30px 10px 20px 10px;
 padding: 10px 20px 10px 10px;
 margin: 20px 10px 10px 10px;

![Complex CSS Box Model
Edges](images/box-edges-complex.png){a
height="217" width="189"}

The difference between normal float wrapping and wrapping around the
shape defined by the margin-box value is that the margin-box shape
includes corner shaping. Take the 100px square with 10px padding, border
and margins, but with a border-radius of 60px. If you make a left float
out of it, content normally wraps in this manner:

![Normal float
wrapping](images/normal-wrap.png){a
height="172" width="311"}

If you add a margin-box shape to the float, then content wraps around
the rounded margin-box corners.

 shape-outside: margin-box;

![Float wrapping with
margin-box](images/margin-box-wrap.png){a
height="173" width="303"}

- [shape-outside-border-box-001.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-box/shape-outside-border-box-001.html "css/css-shapes/shape-outside/shape-box/shape-outside-border-box-001.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-box/shape-outside-border-box-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-box/shape-outside-border-box-001.html)
- [shape-outside-border-box-002.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-box/shape-outside-border-box-002.html "css/css-shapes/shape-outside/shape-box/shape-outside-border-box-002.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-box/shape-outside-border-box-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-box/shape-outside-border-box-002.html)
- [shape-outside-border-box-003.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-box/shape-outside-border-box-003.html "css/css-shapes/shape-outside/shape-box/shape-outside-border-box-003.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-box/shape-outside-border-box-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-box/shape-outside-border-box-003.html)
- [shape-outside-border-box-border-radius-001.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-box/shape-outside-border-box-border-radius-001.html "css/css-shapes/shape-outside/shape-box/shape-outside-border-box-border-radius-001.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-box/shape-outside-border-box-border-radius-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-box/shape-outside-border-box-border-radius-001.html)
- [shape-outside-border-box-border-radius-002.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-box/shape-outside-border-box-border-radius-002.html "css/css-shapes/shape-outside/shape-box/shape-outside-border-box-border-radius-002.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-box/shape-outside-border-box-border-radius-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-box/shape-outside-border-box-border-radius-002.html)
- [shape-outside-border-box-border-radius-003.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-box/shape-outside-border-box-border-radius-003.html "css/css-shapes/shape-outside/shape-box/shape-outside-border-box-border-radius-003.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-box/shape-outside-border-box-border-radius-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-box/shape-outside-border-box-border-radius-003.html)
- [shape-outside-border-box-border-radius-004.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-box/shape-outside-border-box-border-radius-004.html "css/css-shapes/shape-outside/shape-box/shape-outside-border-box-border-radius-004.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-box/shape-outside-border-box-border-radius-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-box/shape-outside-border-box-border-radius-004.html)
- [shape-outside-border-box-border-radius-005.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-box/shape-outside-border-box-border-radius-005.html "css/css-shapes/shape-outside/shape-box/shape-outside-border-box-border-radius-005.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-box/shape-outside-border-box-border-radius-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-box/shape-outside-border-box-border-radius-005.html)
- [shape-outside-border-box-border-radius-006.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-box/shape-outside-border-box-border-radius-006.html "css/css-shapes/shape-outside/shape-box/shape-outside-border-box-border-radius-006.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-box/shape-outside-border-box-border-radius-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-box/shape-outside-border-box-border-radius-006.html)
- [shape-outside-border-box-border-radius-007.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-box/shape-outside-border-box-border-radius-007.html "css/css-shapes/shape-outside/shape-box/shape-outside-border-box-border-radius-007.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-box/shape-outside-border-box-border-radius-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-box/shape-outside-border-box-border-radius-007.html)
- [shape-outside-border-box-border-radius-008.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-box/shape-outside-border-box-border-radius-008.html "css/css-shapes/shape-outside/shape-box/shape-outside-border-box-border-radius-008.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-box/shape-outside-border-box-border-radius-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-box/shape-outside-border-box-border-radius-008.html)
- [shape-outside-border-box-border-radius-009.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-box/shape-outside-border-box-border-radius-009.html "css/css-shapes/shape-outside/shape-box/shape-outside-border-box-border-radius-009.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-box/shape-outside-border-box-border-radius-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-box/shape-outside-border-box-border-radius-009.html)
- [shape-outside-border-box-border-radius-010.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-box/shape-outside-border-box-border-radius-010.html "css/css-shapes/shape-outside/shape-box/shape-outside-border-box-border-radius-010.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-box/shape-outside-border-box-border-radius-010.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-box/shape-outside-border-box-border-radius-010.html)
- [shape-outside-border-box-border-radius-011.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-box/shape-outside-border-box-border-radius-011.html "css/css-shapes/shape-outside/shape-box/shape-outside-border-box-border-radius-011.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-box/shape-outside-border-box-border-radius-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-box/shape-outside-border-box-border-radius-011.html)
- [shape-outside-border-box-border-radius-012.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-box/shape-outside-border-box-border-radius-012.html "css/css-shapes/shape-outside/shape-box/shape-outside-border-box-border-radius-012.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-box/shape-outside-border-box-border-radius-012.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-box/shape-outside-border-box-border-radius-012.html)
- [shape-outside-box-002.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-box/shape-outside-box-002.html "css/css-shapes/shape-outside/shape-box/shape-outside-box-002.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-box/shape-outside-box-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-box/shape-outside-box-002.html)
- [shape-outside-box-003.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-box/shape-outside-box-003.html "css/css-shapes/shape-outside/shape-box/shape-outside-box-003.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-box/shape-outside-box-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-box/shape-outside-box-003.html)
- [shape-outside-box-004.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-box/shape-outside-box-004.html "css/css-shapes/shape-outside/shape-box/shape-outside-box-004.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-box/shape-outside-box-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-box/shape-outside-box-004.html)
- [shape-outside-box-006.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-box/shape-outside-box-006.html "css/css-shapes/shape-outside/shape-box/shape-outside-box-006.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-box/shape-outside-box-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-box/shape-outside-box-006.html)
- [shape-outside-box-007.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-box/shape-outside-box-007.html "css/css-shapes/shape-outside/shape-box/shape-outside-box-007.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-box/shape-outside-box-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-box/shape-outside-box-007.html)
- [shape-outside-box-008.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-box/shape-outside-box-008.html "css/css-shapes/shape-outside/shape-box/shape-outside-box-008.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-box/shape-outside-box-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-box/shape-outside-box-008.html)
- [shape-outside-box-009.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-box/shape-outside-box-009.html "css/css-shapes/shape-outside/shape-box/shape-outside-box-009.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-box/shape-outside-box-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-box/shape-outside-box-009.html)
- [shape-outside-content-box-001.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-box/shape-outside-content-box-001.html "css/css-shapes/shape-outside/shape-box/shape-outside-content-box-001.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-box/shape-outside-content-box-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-box/shape-outside-content-box-001.html)
- [shape-outside-content-box-002.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-box/shape-outside-content-box-002.html "css/css-shapes/shape-outside/shape-box/shape-outside-content-box-002.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-box/shape-outside-content-box-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-box/shape-outside-content-box-002.html)
- [shape-outside-content-box-003.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-box/shape-outside-content-box-003.html "css/css-shapes/shape-outside/shape-box/shape-outside-content-box-003.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-box/shape-outside-content-box-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-box/shape-outside-content-box-003.html)
- [shape-outside-content-box-border-radius-001.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-box/shape-outside-content-box-border-radius-001.html "css/css-shapes/shape-outside/shape-box/shape-outside-content-box-border-radius-001.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-box/shape-outside-content-box-border-radius-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-box/shape-outside-content-box-border-radius-001.html)
- [shape-outside-content-box-border-radius-002.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-box/shape-outside-content-box-border-radius-002.html "css/css-shapes/shape-outside/shape-box/shape-outside-content-box-border-radius-002.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-box/shape-outside-content-box-border-radius-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-box/shape-outside-content-box-border-radius-002.html)
- [shape-outside-margin-box-001.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-001.html "css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-001.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-001.html)
- [shape-outside-margin-box-002.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-002.html "css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-002.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-002.html)
- [shape-outside-margin-box-border-radius-001.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-border-radius-001.html "css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-border-radius-001.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-border-radius-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-border-radius-001.html)
- [shape-outside-margin-box-border-radius-002.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-border-radius-002.html "css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-border-radius-002.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-border-radius-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-border-radius-002.html)
- [shape-outside-margin-box-border-radius-003.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-border-radius-003.html "css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-border-radius-003.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-border-radius-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-border-radius-003.html)
- [shape-outside-margin-box-border-radius-004.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-border-radius-004.html "css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-border-radius-004.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-border-radius-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-border-radius-004.html)
- [shape-outside-margin-box-border-radius-005.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-border-radius-005.html "css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-border-radius-005.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-border-radius-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-border-radius-005.html)
- [shape-outside-margin-box-border-radius-006.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-border-radius-006.html "css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-border-radius-006.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-border-radius-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-border-radius-006.html)
- [shape-outside-margin-box-border-radius-007.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-border-radius-007.html "css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-border-radius-007.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-border-radius-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-border-radius-007.html)
- [shape-outside-margin-box-border-radius-008.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-border-radius-008.html "css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-border-radius-008.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-border-radius-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-border-radius-008.html)
- [shape-outside-padding-box-001.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-box/shape-outside-padding-box-001.html "css/css-shapes/shape-outside/shape-box/shape-outside-padding-box-001.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-box/shape-outside-padding-box-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-box/shape-outside-padding-box-001.html)
- [shape-outside-padding-box-002.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-box/shape-outside-padding-box-002.html "css/css-shapes/shape-outside/shape-box/shape-outside-padding-box-002.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-box/shape-outside-padding-box-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-box/shape-outside-padding-box-002.html)
- [shape-outside-padding-box-003.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-box/shape-outside-padding-box-003.html "css/css-shapes/shape-outside/shape-box/shape-outside-padding-box-003.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-box/shape-outside-padding-box-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-box/shape-outside-padding-box-003.html)
- [shape-outside-padding-box-border-radius-001.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-box/shape-outside-padding-box-border-radius-001.html "css/css-shapes/shape-outside/shape-box/shape-outside-padding-box-border-radius-001.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-box/shape-outside-padding-box-border-radius-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-box/shape-outside-padding-box-border-radius-001.html)
- [shape-outside-padding-box-border-radius-002.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-box/shape-outside-padding-box-border-radius-002.html "css/css-shapes/shape-outside/shape-box/shape-outside-padding-box-border-radius-002.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-box/shape-outside-padding-box-border-radius-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-box/shape-outside-padding-box-border-radius-002.html)
- [shape-outside-box-000.html](https://wpt.fyi/results/css/css-shapes/shape-outside/values/shape-outside-box-000.html "css/css-shapes/shape-outside/values/shape-outside-box-000.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/values/shape-outside-box-000.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/values/shape-outside-box-000.html)
- [shape-outside-shape-box-pair-000.html](https://wpt.fyi/results/css/css-shapes/shape-outside/values/shape-outside-shape-box-pair-000.html "css/css-shapes/shape-outside/values/shape-outside-shape-box-pair-000.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/values/shape-outside-shape-box-pair-000.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/values/shape-outside-shape-box-pair-000.html)

## 6. Declaring Shapes

Shapes are declared with the
[shape-outside](#propdef-shape-outside) property, with possible
modifications from the
[shape-margin](#propdef-shape-margin) property. The shape defined by the
[shape-outside] and
[shape-margin] properties
changes the geometry of a float element's [float
area](#float-area).

### 6.1. Float Area Shape: the [shape-outside property]
Name:

[shape-outside]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

none
[\|](https://drafts.csswg.org/css-values-4/#comb-one) \[
[\<basic-shape\>](#typedef-basic-shape)
[\|\|](https://drafts.csswg.org/css-values-4/#comb-any)
[\<shape-box\>](#typedef-shape-box) \] [\|]
[\<image\>](https://drafts.csswg.org/css-images-3/#typedef-image)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

none

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

floats and [initial letter
boxes](https://drafts.csswg.org/css-inline-3/#initial-letter)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

as [defined](#basic-shape-computed-values) for
[\<basic-shape\>](#typedef-basic-shape) (with
[\<shape-box\>](#typedef-shape-box) following, if supplied); else the computed
[\<image\>](https://drafts.csswg.org/css-images-3/#typedef-image); else the keyword as specified

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

as [defined](#basic-shape-interpolation) for
[\<basic-shape\>](#typedef-basic-shape), otherwise discrete

The values of this property have the following meanings:

[none]
: The [float area](#float-area)
 is unaffected.

[\<shape-box\>](#typedef-shape-box)
: If one of these values is specified by itself the shape is computed
 based on one of
 [margin-box](#valdef-shape-box-margin-box),
 [border-box](#valdef-shape-box-border-box),
 [padding-box](#valdef-shape-box-padding-box) or
 [content-box](#valdef-shape-box-content-box) which use their respective boxes including
 curvature from border-radius, similar to
 [background-clip](https://drafts.csswg.org/css-backgrounds-3/#propdef-background-clip)
 [\[CSS3BG\]](#biblio-css3bg "CSS Backgrounds and Borders Module Level 3").

[[\<basic-shape\>](#typedef-basic-shape)]
: The shape is computed based on one of the
 [\<basic-shape\>](#typedef-basic-shape) functions. If a
 [\<shape-box\>](#typedef-shape-box) is also supplied, this defines the
 [reference
 box](#basic-shape-reference-box) for the
 [\<basic-shape\>]
 function. If [\<shape-box\>] is not supplied, then the [reference
 box] defaults to
 [margin-box](#valdef-shape-box-margin-box).

[[\<image\>](https://drafts.csswg.org/css-images-3/#typedef-image)]

: The shape is extracted and computed based on the alpha channel of
 the specified
 [\<image\>](https://drafts.csswg.org/css-images-3/#typedef-image) as defined by
 [shape-image-threshold](#propdef-shape-image-threshold).

 User agents must use the [CORS
 protocol](https://fetch.spec.whatwg.org/#http-cors-protocol) defined
 by the
 [\[FETCH\]](#biblio-fetch "Fetch Standard")
 specification for all URLs in a
 [shape-outside](#propdef-shape-outside) value. When fetching, user
 agents must use \"Anonymous\" mode, set the referrer source to the
 stylesheet's URL and set the origin to the URL of the containing
 document. If this results in network errors such that there is no
 valid fallback image, the effect is as if the value
 [none](#valdef-shape-outside-none) had been specified.

Tests

- [shape-outside-composition.html](https://wpt.fyi/results/css/css-shapes/animation/shape-outside-composition.html "css/css-shapes/animation/shape-outside-composition.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/animation/shape-outside-composition.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/animation/shape-outside-composition.html)
- [shape-outside-interpolation.html](https://wpt.fyi/results/css/css-shapes/animation/shape-outside-interpolation.html "css/css-shapes/animation/shape-outside-interpolation.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/animation/shape-outside-interpolation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/animation/shape-outside-interpolation.html)
- [inheritance.html](https://wpt.fyi/results/css/css-shapes/inheritance.html "css/css-shapes/inheritance.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/inheritance.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/inheritance.html)
- [shape-outside-computed.html](https://wpt.fyi/results/css/css-shapes/parsing/shape-outside-computed.html "css/css-shapes/parsing/shape-outside-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/parsing/shape-outside-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/parsing/shape-outside-computed.html)
- [shape-outside-invalid-position.html](https://wpt.fyi/results/css/css-shapes/parsing/shape-outside-invalid-position.html "css/css-shapes/parsing/shape-outside-invalid-position.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/parsing/shape-outside-invalid-position.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/parsing/shape-outside-invalid-position.html)
- [shape-outside-valid-position.html](https://wpt.fyi/results/css/css-shapes/parsing/shape-outside-valid-position.html "css/css-shapes/parsing/shape-outside-valid-position.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/parsing/shape-outside-valid-position.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/parsing/shape-outside-valid-position.html)
- [shape-outside-infinite-crash.html](https://wpt.fyi/results/css/css-shapes/shape-outside-infinite-crash.html "css/css-shapes/shape-outside-infinite-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside-infinite-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside-infinite-crash.html)
- [shape-outside-invalid-001.html](https://wpt.fyi/results/css/css-shapes/shape-outside-invalid-001.html "css/css-shapes/shape-outside-invalid-001.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside-invalid-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside-invalid-001.html)
- [shape-outside-invalid-circle-000.html](https://wpt.fyi/results/css/css-shapes/shape-outside-invalid-circle-000.html "css/css-shapes/shape-outside-invalid-circle-000.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside-invalid-circle-000.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside-invalid-circle-000.html)
- [shape-outside-invalid-circle-001.html](https://wpt.fyi/results/css/css-shapes/shape-outside-invalid-circle-001.html "css/css-shapes/shape-outside-invalid-circle-001.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside-invalid-circle-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside-invalid-circle-001.html)
- [shape-outside-invalid-circle-002.html](https://wpt.fyi/results/css/css-shapes/shape-outside-invalid-circle-002.html "css/css-shapes/shape-outside-invalid-circle-002.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside-invalid-circle-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside-invalid-circle-002.html)
- [shape-outside-invalid-circle-003.html](https://wpt.fyi/results/css/css-shapes/shape-outside-invalid-circle-003.html "css/css-shapes/shape-outside-invalid-circle-003.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside-invalid-circle-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside-invalid-circle-003.html)
- [shape-outside-invalid-ellipse-001.html](https://wpt.fyi/results/css/css-shapes/shape-outside-invalid-ellipse-001.html "css/css-shapes/shape-outside-invalid-ellipse-001.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside-invalid-ellipse-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside-invalid-ellipse-001.html)
- [shape-outside-invalid-ellipse-002.html](https://wpt.fyi/results/css/css-shapes/shape-outside-invalid-ellipse-002.html "css/css-shapes/shape-outside-invalid-ellipse-002.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside-invalid-ellipse-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside-invalid-ellipse-002.html)
- [shape-outside-invalid-ellipse-003.html](https://wpt.fyi/results/css/css-shapes/shape-outside-invalid-ellipse-003.html "css/css-shapes/shape-outside-invalid-ellipse-003.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside-invalid-ellipse-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside-invalid-ellipse-003.html)
- [shape-outside-invalid-ellipse-004.html](https://wpt.fyi/results/css/css-shapes/shape-outside-invalid-ellipse-004.html "css/css-shapes/shape-outside-invalid-ellipse-004.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside-invalid-ellipse-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside-invalid-ellipse-004.html)
- [shape-outside-invalid-ellipse-005.html](https://wpt.fyi/results/css/css-shapes/shape-outside-invalid-ellipse-005.html "css/css-shapes/shape-outside-invalid-ellipse-005.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside-invalid-ellipse-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside-invalid-ellipse-005.html)
- [shape-outside-invalid-ellipse-006.html](https://wpt.fyi/results/css/css-shapes/shape-outside-invalid-ellipse-006.html "css/css-shapes/shape-outside-invalid-ellipse-006.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside-invalid-ellipse-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside-invalid-ellipse-006.html)
- [shape-outside-invalid-inset-001.html](https://wpt.fyi/results/css/css-shapes/shape-outside-invalid-inset-001.html "css/css-shapes/shape-outside-invalid-inset-001.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside-invalid-inset-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside-invalid-inset-001.html)
- [shape-outside-invalid-inset-002.html](https://wpt.fyi/results/css/css-shapes/shape-outside-invalid-inset-002.html "css/css-shapes/shape-outside-invalid-inset-002.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside-invalid-inset-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside-invalid-inset-002.html)
- [shape-outside-invalid-inset-003.html](https://wpt.fyi/results/css/css-shapes/shape-outside-invalid-inset-003.html "css/css-shapes/shape-outside-invalid-inset-003.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside-invalid-inset-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside-invalid-inset-003.html)
- [shape-outside-invalid-inset-004.html](https://wpt.fyi/results/css/css-shapes/shape-outside-invalid-inset-004.html "css/css-shapes/shape-outside-invalid-inset-004.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside-invalid-inset-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside-invalid-inset-004.html)
- [float-retry-push-circle.html](https://wpt.fyi/results/css/css-shapes/shape-outside/assorted/float-retry-push-circle.html "css/css-shapes/shape-outside/assorted/float-retry-push-circle.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/assorted/float-retry-push-circle.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/assorted/float-retry-push-circle.html)
- [float-retry-push-image.html](https://wpt.fyi/results/css/css-shapes/shape-outside/assorted/float-retry-push-image.html "css/css-shapes/shape-outside/assorted/float-retry-push-image.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/assorted/float-retry-push-image.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/assorted/float-retry-push-image.html)
- [float-retry-push-inset.html](https://wpt.fyi/results/css/css-shapes/shape-outside/assorted/float-retry-push-inset.html "css/css-shapes/shape-outside/assorted/float-retry-push-inset.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/assorted/float-retry-push-inset.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/assorted/float-retry-push-inset.html)
- [float-retry-push-polygon.html](https://wpt.fyi/results/css/css-shapes/shape-outside/assorted/float-retry-push-polygon.html "css/css-shapes/shape-outside/assorted/float-retry-push-polygon.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/assorted/float-retry-push-polygon.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/assorted/float-retry-push-polygon.html)
- [float-should-push.html](https://wpt.fyi/results/css/css-shapes/shape-outside/assorted/float-should-push.html "css/css-shapes/shape-outside/assorted/float-should-push.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/assorted/float-should-push.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/assorted/float-should-push.html)
- [shape-outside-border-box-001.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-box/shape-outside-border-box-001.html "css/css-shapes/shape-outside/shape-box/shape-outside-border-box-001.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-box/shape-outside-border-box-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-box/shape-outside-border-box-001.html)
- [shape-outside-border-box-002.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-box/shape-outside-border-box-002.html "css/css-shapes/shape-outside/shape-box/shape-outside-border-box-002.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-box/shape-outside-border-box-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-box/shape-outside-border-box-002.html)
- [shape-outside-border-box-003.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-box/shape-outside-border-box-003.html "css/css-shapes/shape-outside/shape-box/shape-outside-border-box-003.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-box/shape-outside-border-box-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-box/shape-outside-border-box-003.html)
- [shape-outside-border-box-border-radius-001.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-box/shape-outside-border-box-border-radius-001.html "css/css-shapes/shape-outside/shape-box/shape-outside-border-box-border-radius-001.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-box/shape-outside-border-box-border-radius-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-box/shape-outside-border-box-border-radius-001.html)
- [shape-outside-border-box-border-radius-002.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-box/shape-outside-border-box-border-radius-002.html "css/css-shapes/shape-outside/shape-box/shape-outside-border-box-border-radius-002.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-box/shape-outside-border-box-border-radius-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-box/shape-outside-border-box-border-radius-002.html)
- [shape-outside-border-box-border-radius-003.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-box/shape-outside-border-box-border-radius-003.html "css/css-shapes/shape-outside/shape-box/shape-outside-border-box-border-radius-003.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-box/shape-outside-border-box-border-radius-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-box/shape-outside-border-box-border-radius-003.html)
- [shape-outside-border-box-border-radius-004.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-box/shape-outside-border-box-border-radius-004.html "css/css-shapes/shape-outside/shape-box/shape-outside-border-box-border-radius-004.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-box/shape-outside-border-box-border-radius-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-box/shape-outside-border-box-border-radius-004.html)
- [shape-outside-border-box-border-radius-005.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-box/shape-outside-border-box-border-radius-005.html "css/css-shapes/shape-outside/shape-box/shape-outside-border-box-border-radius-005.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-box/shape-outside-border-box-border-radius-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-box/shape-outside-border-box-border-radius-005.html)
- [shape-outside-border-box-border-radius-006.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-box/shape-outside-border-box-border-radius-006.html "css/css-shapes/shape-outside/shape-box/shape-outside-border-box-border-radius-006.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-box/shape-outside-border-box-border-radius-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-box/shape-outside-border-box-border-radius-006.html)
- [shape-outside-border-box-border-radius-007.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-box/shape-outside-border-box-border-radius-007.html "css/css-shapes/shape-outside/shape-box/shape-outside-border-box-border-radius-007.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-box/shape-outside-border-box-border-radius-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-box/shape-outside-border-box-border-radius-007.html)
- [shape-outside-border-box-border-radius-008.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-box/shape-outside-border-box-border-radius-008.html "css/css-shapes/shape-outside/shape-box/shape-outside-border-box-border-radius-008.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-box/shape-outside-border-box-border-radius-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-box/shape-outside-border-box-border-radius-008.html)
- [shape-outside-border-box-border-radius-009.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-box/shape-outside-border-box-border-radius-009.html "css/css-shapes/shape-outside/shape-box/shape-outside-border-box-border-radius-009.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-box/shape-outside-border-box-border-radius-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-box/shape-outside-border-box-border-radius-009.html)
- [shape-outside-border-box-border-radius-010.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-box/shape-outside-border-box-border-radius-010.html "css/css-shapes/shape-outside/shape-box/shape-outside-border-box-border-radius-010.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-box/shape-outside-border-box-border-radius-010.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-box/shape-outside-border-box-border-radius-010.html)
- [shape-outside-border-box-border-radius-011.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-box/shape-outside-border-box-border-radius-011.html "css/css-shapes/shape-outside/shape-box/shape-outside-border-box-border-radius-011.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-box/shape-outside-border-box-border-radius-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-box/shape-outside-border-box-border-radius-011.html)
- [shape-outside-border-box-border-radius-012.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-box/shape-outside-border-box-border-radius-012.html "css/css-shapes/shape-outside/shape-box/shape-outside-border-box-border-radius-012.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-box/shape-outside-border-box-border-radius-012.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-box/shape-outside-border-box-border-radius-012.html)
- [shape-outside-box-002.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-box/shape-outside-box-002.html "css/css-shapes/shape-outside/shape-box/shape-outside-box-002.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-box/shape-outside-box-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-box/shape-outside-box-002.html)
- [shape-outside-box-003.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-box/shape-outside-box-003.html "css/css-shapes/shape-outside/shape-box/shape-outside-box-003.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-box/shape-outside-box-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-box/shape-outside-box-003.html)
- [shape-outside-box-004.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-box/shape-outside-box-004.html "css/css-shapes/shape-outside/shape-box/shape-outside-box-004.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-box/shape-outside-box-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-box/shape-outside-box-004.html)
- [shape-outside-box-006.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-box/shape-outside-box-006.html "css/css-shapes/shape-outside/shape-box/shape-outside-box-006.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-box/shape-outside-box-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-box/shape-outside-box-006.html)
- [shape-outside-box-007.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-box/shape-outside-box-007.html "css/css-shapes/shape-outside/shape-box/shape-outside-box-007.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-box/shape-outside-box-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-box/shape-outside-box-007.html)
- [shape-outside-box-008.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-box/shape-outside-box-008.html "css/css-shapes/shape-outside/shape-box/shape-outside-box-008.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-box/shape-outside-box-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-box/shape-outside-box-008.html)
- [shape-outside-box-009.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-box/shape-outside-box-009.html "css/css-shapes/shape-outside/shape-box/shape-outside-box-009.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-box/shape-outside-box-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-box/shape-outside-box-009.html)
- [shape-outside-content-box-001.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-box/shape-outside-content-box-001.html "css/css-shapes/shape-outside/shape-box/shape-outside-content-box-001.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-box/shape-outside-content-box-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-box/shape-outside-content-box-001.html)
- [shape-outside-content-box-002.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-box/shape-outside-content-box-002.html "css/css-shapes/shape-outside/shape-box/shape-outside-content-box-002.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-box/shape-outside-content-box-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-box/shape-outside-content-box-002.html)
- [shape-outside-content-box-003.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-box/shape-outside-content-box-003.html "css/css-shapes/shape-outside/shape-box/shape-outside-content-box-003.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-box/shape-outside-content-box-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-box/shape-outside-content-box-003.html)
- [shape-outside-content-box-border-radius-001.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-box/shape-outside-content-box-border-radius-001.html "css/css-shapes/shape-outside/shape-box/shape-outside-content-box-border-radius-001.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-box/shape-outside-content-box-border-radius-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-box/shape-outside-content-box-border-radius-001.html)
- [shape-outside-content-box-border-radius-002.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-box/shape-outside-content-box-border-radius-002.html "css/css-shapes/shape-outside/shape-box/shape-outside-content-box-border-radius-002.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-box/shape-outside-content-box-border-radius-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-box/shape-outside-content-box-border-radius-002.html)
- [shape-outside-margin-box-001.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-001.html "css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-001.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-001.html)
- [shape-outside-margin-box-002.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-002.html "css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-002.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-002.html)
- [shape-outside-margin-box-border-radius-001.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-border-radius-001.html "css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-border-radius-001.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-border-radius-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-border-radius-001.html)
- [shape-outside-margin-box-border-radius-002.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-border-radius-002.html "css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-border-radius-002.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-border-radius-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-border-radius-002.html)
- [shape-outside-margin-box-border-radius-003.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-border-radius-003.html "css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-border-radius-003.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-border-radius-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-border-radius-003.html)
- [shape-outside-margin-box-border-radius-004.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-border-radius-004.html "css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-border-radius-004.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-border-radius-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-border-radius-004.html)
- [shape-outside-margin-box-border-radius-005.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-border-radius-005.html "css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-border-radius-005.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-border-radius-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-border-radius-005.html)
- [shape-outside-margin-box-border-radius-006.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-border-radius-006.html "css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-border-radius-006.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-border-radius-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-border-radius-006.html)
- [shape-outside-margin-box-border-radius-007.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-border-radius-007.html "css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-border-radius-007.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-border-radius-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-border-radius-007.html)
- [shape-outside-margin-box-border-radius-008.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-border-radius-008.html "css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-border-radius-008.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-border-radius-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-border-radius-008.html)
- [shape-outside-padding-box-001.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-box/shape-outside-padding-box-001.html "css/css-shapes/shape-outside/shape-box/shape-outside-padding-box-001.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-box/shape-outside-padding-box-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-box/shape-outside-padding-box-001.html)
- [shape-outside-padding-box-002.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-box/shape-outside-padding-box-002.html "css/css-shapes/shape-outside/shape-box/shape-outside-padding-box-002.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-box/shape-outside-padding-box-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-box/shape-outside-padding-box-002.html)
- [shape-outside-padding-box-003.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-box/shape-outside-padding-box-003.html "css/css-shapes/shape-outside/shape-box/shape-outside-padding-box-003.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-box/shape-outside-padding-box-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-box/shape-outside-padding-box-003.html)
- [shape-outside-padding-box-border-radius-001.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-box/shape-outside-padding-box-border-radius-001.html "css/css-shapes/shape-outside/shape-box/shape-outside-padding-box-border-radius-001.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-box/shape-outside-padding-box-border-radius-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-box/shape-outside-padding-box-border-radius-001.html)
- [shape-outside-padding-box-border-radius-002.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-box/shape-outside-padding-box-border-radius-002.html "css/css-shapes/shape-outside/shape-box/shape-outside-padding-box-border-radius-002.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-box/shape-outside-padding-box-border-radius-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-box/shape-outside-padding-box-border-radius-002.html)
- [shape-outside-linear-gradient-001.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-001.html "css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-001.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-001.html)
- [shape-outside-linear-gradient-002.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-002.html "css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-002.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-002.html)
- [shape-outside-linear-gradient-003.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-003.html "css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-003.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-003.html)
- [shape-outside-linear-gradient-004.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-004.html "css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-004.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-004.html)
- [shape-outside-linear-gradient-005.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-005.html "css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-005.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-005.html)
- [shape-outside-linear-gradient-006.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-006.html "css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-006.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-006.html)
- [shape-outside-linear-gradient-007.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-007.html "css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-007.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-007.html)
- [shape-outside-linear-gradient-008.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-008.html "css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-008.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-008.html)
- [shape-outside-linear-gradient-009.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-009.html "css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-009.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-009.html)
- [shape-outside-linear-gradient-010.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-010.html "css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-010.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-010.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-010.html)
- [shape-outside-linear-gradient-011.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-011.html "css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-011.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-011.html)
- [shape-outside-linear-gradient-012.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-012.html "css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-012.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-012.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-012.html)
- [shape-outside-linear-gradient-013.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-013.html "css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-013.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-013.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-013.html)
- [shape-outside-linear-gradient-014.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-014.html "css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-014.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-014.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-014.html)
- [shape-outside-linear-gradient-015.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-015.html "css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-015.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-015.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-015.html)
- [shape-outside-linear-gradient-016.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-016.html "css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-016.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-016.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-linear-gradient-016.html)
- [shape-outside-radial-gradient-001.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-radial-gradient-001.html "css/css-shapes/shape-outside/shape-image/gradients/shape-outside-radial-gradient-001.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-radial-gradient-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-radial-gradient-001.html)
- [shape-outside-radial-gradient-002.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-radial-gradient-002.html "css/css-shapes/shape-outside/shape-image/gradients/shape-outside-radial-gradient-002.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-radial-gradient-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-radial-gradient-002.html)
- [shape-outside-radial-gradient-003.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-radial-gradient-003.html "css/css-shapes/shape-outside/shape-image/gradients/shape-outside-radial-gradient-003.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-radial-gradient-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-radial-gradient-003.html)
- [shape-outside-radial-gradient-004.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-radial-gradient-004.html "css/css-shapes/shape-outside/shape-image/gradients/shape-outside-radial-gradient-004.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-radial-gradient-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-image/gradients/shape-outside-radial-gradient-004.html)
- [shape-image-000.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-image/shape-image-000.html "css/css-shapes/shape-outside/shape-image/shape-image-000.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-image/shape-image-000.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-image/shape-image-000.html)
- [shape-image-001.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-image/shape-image-001.html "css/css-shapes/shape-outside/shape-image/shape-image-001.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-image/shape-image-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-image/shape-image-001.html)
- [shape-image-002.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-image/shape-image-002.html "css/css-shapes/shape-outside/shape-image/shape-image-002.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-image/shape-image-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-image/shape-image-002.html)
- [shape-image-003.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-image/shape-image-003.html "css/css-shapes/shape-outside/shape-image/shape-image-003.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-image/shape-image-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-image/shape-image-003.html)
- [shape-image-004.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-image/shape-image-004.html "css/css-shapes/shape-outside/shape-image/shape-image-004.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-image/shape-image-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-image/shape-image-004.html)
- [shape-image-005.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-image/shape-image-005.html "css/css-shapes/shape-outside/shape-image/shape-image-005.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-image/shape-image-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-image/shape-image-005.html)
- [shape-image-006.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-image/shape-image-006.html "css/css-shapes/shape-outside/shape-image/shape-image-006.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-image/shape-image-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-image/shape-image-006.html)
- [shape-image-007.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-image/shape-image-007.html "css/css-shapes/shape-outside/shape-image/shape-image-007.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-image/shape-image-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-image/shape-image-007.html)
- [shape-image-008.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-image/shape-image-008.html "css/css-shapes/shape-outside/shape-image/shape-image-008.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-image/shape-image-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-image/shape-image-008.html)
- [shape-image-009.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-image/shape-image-009.html "css/css-shapes/shape-outside/shape-image/shape-image-009.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-image/shape-image-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-image/shape-image-009.html)
- [shape-image-010.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-image/shape-image-010.html "css/css-shapes/shape-outside/shape-image/shape-image-010.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-image/shape-image-010.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-image/shape-image-010.html)
- [shape-image-011.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-image/shape-image-011.html "css/css-shapes/shape-outside/shape-image/shape-image-011.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-image/shape-image-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-image/shape-image-011.html)
- [shape-image-012.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-image/shape-image-012.html "css/css-shapes/shape-outside/shape-image/shape-image-012.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-image/shape-image-012.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-image/shape-image-012.html)
- [shape-image-013.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-image/shape-image-013.html "css/css-shapes/shape-outside/shape-image/shape-image-013.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-image/shape-image-013.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-image/shape-image-013.html)
- [shape-image-014.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-image/shape-image-014.html "css/css-shapes/shape-outside/shape-image/shape-image-014.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-image/shape-image-014.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-image/shape-image-014.html)
- [shape-image-015.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-image/shape-image-015.html "css/css-shapes/shape-outside/shape-image/shape-image-015.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-image/shape-image-015.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-image/shape-image-015.html)
- [shape-image-016.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-image/shape-image-016.html "css/css-shapes/shape-outside/shape-image/shape-image-016.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-image/shape-image-016.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-image/shape-image-016.html)
- [shape-image-017.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-image/shape-image-017.html "css/css-shapes/shape-outside/shape-image/shape-image-017.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-image/shape-image-017.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-image/shape-image-017.html)
- [shape-image-018.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-image/shape-image-018.html "css/css-shapes/shape-outside/shape-image/shape-image-018.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-image/shape-image-018.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-image/shape-image-018.html)
- [shape-image-019.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-image/shape-image-019.html "css/css-shapes/shape-outside/shape-image/shape-image-019.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-image/shape-image-019.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-image/shape-image-019.html)
- [shape-image-020.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-image/shape-image-020.html "css/css-shapes/shape-outside/shape-image/shape-image-020.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-image/shape-image-020.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-image/shape-image-020.html)
- [shape-image-021.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-image/shape-image-021.html "css/css-shapes/shape-outside/shape-image/shape-image-021.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-image/shape-image-021.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-image/shape-image-021.html)
- [shape-image-022.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-image/shape-image-022.html "css/css-shapes/shape-outside/shape-image/shape-image-022.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-image/shape-image-022.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-image/shape-image-022.html)
- [shape-image-023.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-image/shape-image-023.html "css/css-shapes/shape-outside/shape-image/shape-image-023.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-image/shape-image-023.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-image/shape-image-023.html)
- [shape-image-024.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-image/shape-image-024.html "css/css-shapes/shape-outside/shape-image/shape-image-024.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-image/shape-image-024.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-image/shape-image-024.html)
- [shape-image-025.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-image/shape-image-025.html "css/css-shapes/shape-outside/shape-image/shape-image-025.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-image/shape-image-025.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-image/shape-image-025.html)
- [shape-image-026.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-image/shape-image-026.html "css/css-shapes/shape-outside/shape-image/shape-image-026.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-image/shape-image-026.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-image/shape-image-026.html)
- [shape-image-027.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-image/shape-image-027.html "css/css-shapes/shape-outside/shape-image/shape-image-027.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-image/shape-image-027.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-image/shape-image-027.html)
- [shape-image-028.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-image/shape-image-028.html "css/css-shapes/shape-outside/shape-image/shape-image-028.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-image/shape-image-028.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-image/shape-image-028.html)
- [shape-image-029.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-image/shape-image-029.html "css/css-shapes/shape-outside/shape-image/shape-image-029.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-image/shape-image-029.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-image/shape-image-029.html)
- [shape-outside-circle-013.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-013.html "css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-013.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-013.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-013.html)
- [shape-outside-circle-014.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-014.html "css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-014.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-014.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-014.html)
- [shape-outside-circle-015.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-015.html "css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-015.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-015.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-015.html)
- [shape-outside-circle-016.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-016.html "css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-016.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-016.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-016.html)
- [shape-outside-circle-017.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-017.html "css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-017.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-017.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-017.html)
- [shape-outside-circle-018.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-018.html "css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-018.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-018.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-018.html)
- [shape-outside-circle-019.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-019.html "css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-019.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-019.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-019.html)
- [shape-outside-circle-020.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-020.html "css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-020.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-020.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-020.html)
- [shape-outside-circle-021.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-021.html "css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-021.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-021.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-021.html)
- [shape-outside-circle-022.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-022.html "css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-022.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-022.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-022.html)
- [shape-outside-circle-024.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-024.html "css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-024.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-024.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-024.html)
- [shape-outside-circle-025.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-025.html "css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-025.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-025.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-025.html)
- [shape-outside-circle-026.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-026.html "css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-026.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-026.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-026.html)
- [shape-outside-circle-027.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-027.html "css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-027.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-027.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-027.html)
- [shape-outside-circle-028.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-028.html "css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-028.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-028.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-028.html)
- [shape-outside-circle-029.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-029.html "css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-029.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-029.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-029.html)
- [shape-outside-circle-030.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-030.html "css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-030.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-030.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-030.html)
- [shape-outside-circle-031.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-031.html "css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-031.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-031.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-031.html)
- [shape-outside-circle-032.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-032.html "css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-032.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-032.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-032.html)
- [shape-outside-circle-033.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-033.html "css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-033.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-033.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-033.html)
- [shape-outside-circle-034.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-034.html "css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-034.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-034.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-034.html)
- [shape-outside-circle-035.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-035.html "css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-035.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-035.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-035.html)
- [shape-outside-circle-036.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-036.html "css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-036.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-036.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-036.html)
- [shape-outside-circle-037.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-037.html "css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-037.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-037.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-037.html)
- [shape-outside-circle-038.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-038.html "css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-038.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-038.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-038.html)
- [shape-outside-circle-041.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-041.html "css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-041.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-041.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-041.html)
- [shape-outside-circle-042.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-042.html "css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-042.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-042.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-042.html)
- [shape-outside-circle-043.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-043.html "css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-043.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-043.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-043.html)
- [shape-outside-circle-044.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-044.html "css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-044.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-044.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-044.html)
- [shape-outside-circle-047.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-047.html "css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-047.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-047.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-047.html)
- [shape-outside-circle-048.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-048.html "css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-048.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-048.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-048.html)
- [shape-outside-circle-049.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-049.html "css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-049.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-049.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-049.html)
- [shape-outside-circle-050.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-050.html "css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-050.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-050.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-050.html)
- [shape-outside-circle-051.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-051.html "css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-051.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-051.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-051.html)
- [shape-outside-circle-052.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-052.html "css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-052.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-052.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-052.html)
- [shape-outside-circle-053.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-053.html "css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-053.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-053.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-053.html)
- [shape-outside-circle-054.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-054.html "css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-054.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-054.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-054.html)
- [shape-outside-circle-055.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-055.html "css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-055.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-055.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-055.html)
- [shape-outside-circle-056.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-056.html "css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-056.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-056.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-056.html)
- [shape-outside-circle-integer-overflow-crash.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-integer-overflow-crash.html "css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-integer-overflow-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-integer-overflow-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/circle/shape-outside-circle-integer-overflow-crash.html)
- [shape-outside-ellipse-013.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-013.html "css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-013.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-013.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-013.html)
- [shape-outside-ellipse-014.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-014.html "css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-014.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-014.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-014.html)
- [shape-outside-ellipse-015.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-015.html "css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-015.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-015.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-015.html)
- [shape-outside-ellipse-016.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-016.html "css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-016.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-016.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-016.html)
- [shape-outside-ellipse-017.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-017.html "css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-017.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-017.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-017.html)
- [shape-outside-ellipse-018.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-018.html "css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-018.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-018.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-018.html)
- [shape-outside-ellipse-019.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-019.html "css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-019.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-019.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-019.html)
- [shape-outside-ellipse-020.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-020.html "css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-020.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-020.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-020.html)
- [shape-outside-ellipse-021.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-021.html "css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-021.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-021.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-021.html)
- [shape-outside-ellipse-022.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-022.html "css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-022.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-022.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-022.html)
- [shape-outside-ellipse-023.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-023.html "css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-023.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-023.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-023.html)
- [shape-outside-ellipse-024.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-024.html "css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-024.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-024.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-024.html)
- [shape-outside-ellipse-025.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-025.html "css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-025.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-025.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-025.html)
- [shape-outside-ellipse-030.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-030.html "css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-030.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-030.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-030.html)
- [shape-outside-ellipse-031.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-031.html "css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-031.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-031.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-031.html)
- [shape-outside-ellipse-032.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-032.html "css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-032.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-032.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-032.html)
- [shape-outside-ellipse-033.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-033.html "css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-033.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-033.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-033.html)
- [shape-outside-ellipse-034.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-034.html "css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-034.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-034.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-034.html)
- [shape-outside-ellipse-035.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-035.html "css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-035.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-035.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-035.html)
- [shape-outside-ellipse-036.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-036.html "css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-036.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-036.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-036.html)
- [shape-outside-ellipse-037.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-037.html "css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-037.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-037.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-037.html)
- [shape-outside-ellipse-038.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-038.html "css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-038.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-038.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-038.html)
- [shape-outside-ellipse-039.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-039.html "css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-039.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-039.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-039.html)
- [shape-outside-ellipse-040.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-040.html "css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-040.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-040.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-040.html)
- [shape-outside-ellipse-041.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-041.html "css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-041.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-041.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-041.html)
- [shape-outside-ellipse-042.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-042.html "css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-042.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-042.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-042.html)
- [shape-outside-ellipse-043.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-043.html "css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-043.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-043.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-043.html)
- [shape-outside-ellipse-044.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-044.html "css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-044.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-044.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-044.html)
- [shape-outside-ellipse-045.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-045.html "css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-045.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-045.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-045.html)
- [shape-outside-ellipse-046.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-046.html "css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-046.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-046.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-046.html)
- [shape-outside-ellipse-047.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-047.html "css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-047.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-047.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-047.html)
- [shape-outside-ellipse-048.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-048.html "css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-048.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-048.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-048.html)
- [shape-outside-ellipse-049.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-049.html "css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-049.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-049.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-049.html)
- [shape-outside-ellipse-050.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-050.html "css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-050.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-050.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-050.html)
- [shape-outside-ellipse-051.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-051.html "css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-051.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-051.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-051.html)
- [shape-outside-ellipse-052.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-052.html "css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-052.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-052.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-052.html)
- [shape-outside-ellipse-integer-overflow-crash.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-integer-overflow-crash.html "css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-integer-overflow-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-integer-overflow-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/ellipse/shape-outside-ellipse-integer-overflow-crash.html)
- [shape-outside-inset-010.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/inset/shape-outside-inset-010.html "css/css-shapes/shape-outside/supported-shapes/inset/shape-outside-inset-010.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/inset/shape-outside-inset-010.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/inset/shape-outside-inset-010.html)
- [shape-outside-inset-011.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/inset/shape-outside-inset-011.html "css/css-shapes/shape-outside/supported-shapes/inset/shape-outside-inset-011.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/inset/shape-outside-inset-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/inset/shape-outside-inset-011.html)
- [shape-outside-inset-012.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/inset/shape-outside-inset-012.html "css/css-shapes/shape-outside/supported-shapes/inset/shape-outside-inset-012.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/inset/shape-outside-inset-012.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/inset/shape-outside-inset-012.html)
- [shape-outside-inset-013.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/inset/shape-outside-inset-013.html "css/css-shapes/shape-outside/supported-shapes/inset/shape-outside-inset-013.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/inset/shape-outside-inset-013.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/inset/shape-outside-inset-013.html)
- [shape-outside-inset-014.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/inset/shape-outside-inset-014.html "css/css-shapes/shape-outside/supported-shapes/inset/shape-outside-inset-014.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/inset/shape-outside-inset-014.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/inset/shape-outside-inset-014.html)
- [shape-outside-inset-015.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/inset/shape-outside-inset-015.html "css/css-shapes/shape-outside/supported-shapes/inset/shape-outside-inset-015.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/inset/shape-outside-inset-015.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/inset/shape-outside-inset-015.html)
- [shape-outside-inset-016.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/inset/shape-outside-inset-016.html "css/css-shapes/shape-outside/supported-shapes/inset/shape-outside-inset-016.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/inset/shape-outside-inset-016.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/inset/shape-outside-inset-016.html)
- [shape-outside-inset-017.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/inset/shape-outside-inset-017.html "css/css-shapes/shape-outside/supported-shapes/inset/shape-outside-inset-017.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/inset/shape-outside-inset-017.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/inset/shape-outside-inset-017.html)
- [shape-outside-inset-020.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/inset/shape-outside-inset-020.html "css/css-shapes/shape-outside/supported-shapes/inset/shape-outside-inset-020.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/inset/shape-outside-inset-020.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/inset/shape-outside-inset-020.html)
- [shape-outside-inset-021.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/inset/shape-outside-inset-021.html "css/css-shapes/shape-outside/supported-shapes/inset/shape-outside-inset-021.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/inset/shape-outside-inset-021.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/inset/shape-outside-inset-021.html)
- [shape-outside-inset-022.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/inset/shape-outside-inset-022.html "css/css-shapes/shape-outside/supported-shapes/inset/shape-outside-inset-022.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/inset/shape-outside-inset-022.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/inset/shape-outside-inset-022.html)
- [shape-outside-inset-023.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/inset/shape-outside-inset-023.html "css/css-shapes/shape-outside/supported-shapes/inset/shape-outside-inset-023.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/inset/shape-outside-inset-023.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/inset/shape-outside-inset-023.html)
- [shape-outside-inset-024.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/inset/shape-outside-inset-024.html "css/css-shapes/shape-outside/supported-shapes/inset/shape-outside-inset-024.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/inset/shape-outside-inset-024.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/inset/shape-outside-inset-024.html)
- [shape-outside-inset-025.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/inset/shape-outside-inset-025.html "css/css-shapes/shape-outside/supported-shapes/inset/shape-outside-inset-025.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/inset/shape-outside-inset-025.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/inset/shape-outside-inset-025.html)
- [shape-outside-inset-026.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/inset/shape-outside-inset-026.html "css/css-shapes/shape-outside/supported-shapes/inset/shape-outside-inset-026.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/inset/shape-outside-inset-026.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/inset/shape-outside-inset-026.html)
- [shape-outside-inset-027.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/inset/shape-outside-inset-027.html "css/css-shapes/shape-outside/supported-shapes/inset/shape-outside-inset-027.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/inset/shape-outside-inset-027.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/inset/shape-outside-inset-027.html)
- [shape-outside-inset-028.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/inset/shape-outside-inset-028.html "css/css-shapes/shape-outside/supported-shapes/inset/shape-outside-inset-028.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/inset/shape-outside-inset-028.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/inset/shape-outside-inset-028.html)
- [shape-outside-inset-029.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/inset/shape-outside-inset-029.html "css/css-shapes/shape-outside/supported-shapes/inset/shape-outside-inset-029.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/inset/shape-outside-inset-029.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/inset/shape-outside-inset-029.html)
- [shape-outside-inset-030.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/inset/shape-outside-inset-030.html "css/css-shapes/shape-outside/supported-shapes/inset/shape-outside-inset-030.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/inset/shape-outside-inset-030.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/inset/shape-outside-inset-030.html)
- [shape-outside-inset-031.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/inset/shape-outside-inset-031.html "css/css-shapes/shape-outside/supported-shapes/inset/shape-outside-inset-031.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/inset/shape-outside-inset-031.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/inset/shape-outside-inset-031.html)
- [shape-outside-inset-refcrash.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/inset/shape-outside-inset-refcrash.html "css/css-shapes/shape-outside/supported-shapes/inset/shape-outside-inset-refcrash.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/inset/shape-outside-inset-refcrash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/inset/shape-outside-inset-refcrash.html)
- [shape-outside-polygon-007.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/polygon/shape-outside-polygon-007.html "css/css-shapes/shape-outside/supported-shapes/polygon/shape-outside-polygon-007.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/polygon/shape-outside-polygon-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/polygon/shape-outside-polygon-007.html)
- [shape-outside-polygon-008.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/polygon/shape-outside-polygon-008.html "css/css-shapes/shape-outside/supported-shapes/polygon/shape-outside-polygon-008.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/polygon/shape-outside-polygon-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/polygon/shape-outside-polygon-008.html)
- [shape-outside-polygon-009.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/polygon/shape-outside-polygon-009.html "css/css-shapes/shape-outside/supported-shapes/polygon/shape-outside-polygon-009.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/polygon/shape-outside-polygon-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/polygon/shape-outside-polygon-009.html)
- [shape-outside-polygon-010.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/polygon/shape-outside-polygon-010.html "css/css-shapes/shape-outside/supported-shapes/polygon/shape-outside-polygon-010.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/polygon/shape-outside-polygon-010.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/polygon/shape-outside-polygon-010.html)
- [shape-outside-polygon-011.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/polygon/shape-outside-polygon-011.html "css/css-shapes/shape-outside/supported-shapes/polygon/shape-outside-polygon-011.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/polygon/shape-outside-polygon-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/polygon/shape-outside-polygon-011.html)
- [shape-outside-polygon-012.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/polygon/shape-outside-polygon-012.html "css/css-shapes/shape-outside/supported-shapes/polygon/shape-outside-polygon-012.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/polygon/shape-outside-polygon-012.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/polygon/shape-outside-polygon-012.html)
- [shape-outside-polygon-013.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/polygon/shape-outside-polygon-013.html "css/css-shapes/shape-outside/supported-shapes/polygon/shape-outside-polygon-013.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/polygon/shape-outside-polygon-013.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/polygon/shape-outside-polygon-013.html)
- [shape-outside-polygon-014.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/polygon/shape-outside-polygon-014.html "css/css-shapes/shape-outside/supported-shapes/polygon/shape-outside-polygon-014.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/polygon/shape-outside-polygon-014.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/polygon/shape-outside-polygon-014.html)
- [shape-outside-polygon-015.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/polygon/shape-outside-polygon-015.html "css/css-shapes/shape-outside/supported-shapes/polygon/shape-outside-polygon-015.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/polygon/shape-outside-polygon-015.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/polygon/shape-outside-polygon-015.html)
- [shape-outside-polygon-016.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/polygon/shape-outside-polygon-016.html "css/css-shapes/shape-outside/supported-shapes/polygon/shape-outside-polygon-016.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/polygon/shape-outside-polygon-016.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/polygon/shape-outside-polygon-016.html)
- [shape-outside-polygon-017.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/polygon/shape-outside-polygon-017.html "css/css-shapes/shape-outside/supported-shapes/polygon/shape-outside-polygon-017.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/polygon/shape-outside-polygon-017.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/polygon/shape-outside-polygon-017.html)
- [shape-outside-polygon-018.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/polygon/shape-outside-polygon-018.html "css/css-shapes/shape-outside/supported-shapes/polygon/shape-outside-polygon-018.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/polygon/shape-outside-polygon-018.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/polygon/shape-outside-polygon-018.html)
- [shape-outside-polygon-019.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/polygon/shape-outside-polygon-019.html "css/css-shapes/shape-outside/supported-shapes/polygon/shape-outside-polygon-019.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/polygon/shape-outside-polygon-019.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/polygon/shape-outside-polygon-019.html)
- [shape-outside-polygon-020.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/polygon/shape-outside-polygon-020.html "css/css-shapes/shape-outside/supported-shapes/polygon/shape-outside-polygon-020.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/polygon/shape-outside-polygon-020.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/polygon/shape-outside-polygon-020.html)
- [shape-outside-polygon-021.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/polygon/shape-outside-polygon-021.html "css/css-shapes/shape-outside/supported-shapes/polygon/shape-outside-polygon-021.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/polygon/shape-outside-polygon-021.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/polygon/shape-outside-polygon-021.html)
- [shape-outside-polygon-022.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/polygon/shape-outside-polygon-022.html "css/css-shapes/shape-outside/supported-shapes/polygon/shape-outside-polygon-022.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/polygon/shape-outside-polygon-022.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/polygon/shape-outside-polygon-022.html)
- [shape-outside-polygon-023.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/polygon/shape-outside-polygon-023.html "css/css-shapes/shape-outside/supported-shapes/polygon/shape-outside-polygon-023.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/polygon/shape-outside-polygon-023.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/polygon/shape-outside-polygon-023.html)
- [shape-outside-polygon-024.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/polygon/shape-outside-polygon-024.html "css/css-shapes/shape-outside/supported-shapes/polygon/shape-outside-polygon-024.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/polygon/shape-outside-polygon-024.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/polygon/shape-outside-polygon-024.html)
- [shape-outside-polygon-025.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/polygon/shape-outside-polygon-025.html "css/css-shapes/shape-outside/supported-shapes/polygon/shape-outside-polygon-025.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/polygon/shape-outside-polygon-025.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/polygon/shape-outside-polygon-025.html)
- [shape-outside-polygon-032.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/polygon/shape-outside-polygon-032.html "css/css-shapes/shape-outside/supported-shapes/polygon/shape-outside-polygon-032.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/polygon/shape-outside-polygon-032.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/polygon/shape-outside-polygon-032.html)
- [shape-outside-polygon-crash.html](https://wpt.fyi/results/css/css-shapes/shape-outside/supported-shapes/polygon/shape-outside-polygon-crash.html "css/css-shapes/shape-outside/supported-shapes/polygon/shape-outside-polygon-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/supported-shapes/polygon/shape-outside-polygon-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/supported-shapes/polygon/shape-outside-polygon-crash.html)
- [shape-image-threshold-000.html](https://wpt.fyi/results/css/css-shapes/shape-outside/values/shape-image-threshold-000.html "css/css-shapes/shape-outside/values/shape-image-threshold-000.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/values/shape-image-threshold-000.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/values/shape-image-threshold-000.html)
- [shape-image-threshold-001.html](https://wpt.fyi/results/css/css-shapes/shape-outside/values/shape-image-threshold-001.html "css/css-shapes/shape-outside/values/shape-image-threshold-001.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/values/shape-image-threshold-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/values/shape-image-threshold-001.html)
- [shape-image-threshold-002.html](https://wpt.fyi/results/css/css-shapes/shape-outside/values/shape-image-threshold-002.html "css/css-shapes/shape-outside/values/shape-image-threshold-002.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/values/shape-image-threshold-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/values/shape-image-threshold-002.html)
- [shape-image-threshold-003.html](https://wpt.fyi/results/css/css-shapes/shape-outside/values/shape-image-threshold-003.html "css/css-shapes/shape-outside/values/shape-image-threshold-003.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/values/shape-image-threshold-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/values/shape-image-threshold-003.html)
- [shape-margin-000.html](https://wpt.fyi/results/css/css-shapes/shape-outside/values/shape-margin-000.html "css/css-shapes/shape-outside/values/shape-margin-000.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/values/shape-margin-000.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/values/shape-margin-000.html)
- [shape-margin-001.html](https://wpt.fyi/results/css/css-shapes/shape-outside/values/shape-margin-001.html "css/css-shapes/shape-outside/values/shape-margin-001.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/values/shape-margin-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/values/shape-margin-001.html)
- [shape-margin-002.html](https://wpt.fyi/results/css/css-shapes/shape-outside/values/shape-margin-002.html "css/css-shapes/shape-outside/values/shape-margin-002.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/values/shape-margin-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/values/shape-margin-002.html)
- [shape-margin-003.html](https://wpt.fyi/results/css/css-shapes/shape-outside/values/shape-margin-003.html "css/css-shapes/shape-outside/values/shape-margin-003.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/values/shape-margin-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/values/shape-margin-003.html)
- [shape-margin-004.html](https://wpt.fyi/results/css/css-shapes/shape-outside/values/shape-margin-004.html "css/css-shapes/shape-outside/values/shape-margin-004.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/values/shape-margin-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/values/shape-margin-004.html)
- [shape-margin-005.html](https://wpt.fyi/results/css/css-shapes/shape-outside/values/shape-margin-005.html "css/css-shapes/shape-outside/values/shape-margin-005.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/values/shape-margin-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/values/shape-margin-005.html)
- [shape-outside-box-000.html](https://wpt.fyi/results/css/css-shapes/shape-outside/values/shape-outside-box-000.html "css/css-shapes/shape-outside/values/shape-outside-box-000.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/values/shape-outside-box-000.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/values/shape-outside-box-000.html)
- [shape-outside-circle-000.html](https://wpt.fyi/results/css/css-shapes/shape-outside/values/shape-outside-circle-000.html "css/css-shapes/shape-outside/values/shape-outside-circle-000.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/values/shape-outside-circle-000.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/values/shape-outside-circle-000.html)
- [shape-outside-circle-001.html](https://wpt.fyi/results/css/css-shapes/shape-outside/values/shape-outside-circle-001.html "css/css-shapes/shape-outside/values/shape-outside-circle-001.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/values/shape-outside-circle-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/values/shape-outside-circle-001.html)
- [shape-outside-circle-002.html](https://wpt.fyi/results/css/css-shapes/shape-outside/values/shape-outside-circle-002.html "css/css-shapes/shape-outside/values/shape-outside-circle-002.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/values/shape-outside-circle-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/values/shape-outside-circle-002.html)
- [shape-outside-circle-003.html](https://wpt.fyi/results/css/css-shapes/shape-outside/values/shape-outside-circle-003.html "css/css-shapes/shape-outside/values/shape-outside-circle-003.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/values/shape-outside-circle-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/values/shape-outside-circle-003.html)
- [shape-outside-circle-004.html](https://wpt.fyi/results/css/css-shapes/shape-outside/values/shape-outside-circle-004.html "css/css-shapes/shape-outside/values/shape-outside-circle-004.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/values/shape-outside-circle-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/values/shape-outside-circle-004.html)
- [shape-outside-circle-005.html](https://wpt.fyi/results/css/css-shapes/shape-outside/values/shape-outside-circle-005.html "css/css-shapes/shape-outside/values/shape-outside-circle-005.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/values/shape-outside-circle-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/values/shape-outside-circle-005.html)
- [shape-outside-circle-006.html](https://wpt.fyi/results/css/css-shapes/shape-outside/values/shape-outside-circle-006.html "css/css-shapes/shape-outside/values/shape-outside-circle-006.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/values/shape-outside-circle-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/values/shape-outside-circle-006.html)
- [shape-outside-circle-007.html](https://wpt.fyi/results/css/css-shapes/shape-outside/values/shape-outside-circle-007.html "css/css-shapes/shape-outside/values/shape-outside-circle-007.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/values/shape-outside-circle-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/values/shape-outside-circle-007.html)
- [shape-outside-circle-008.html](https://wpt.fyi/results/css/css-shapes/shape-outside/values/shape-outside-circle-008.html "css/css-shapes/shape-outside/values/shape-outside-circle-008.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/values/shape-outside-circle-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/values/shape-outside-circle-008.html)
- [shape-outside-circle-009.html](https://wpt.fyi/results/css/css-shapes/shape-outside/values/shape-outside-circle-009.html "css/css-shapes/shape-outside/values/shape-outside-circle-009.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/values/shape-outside-circle-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/values/shape-outside-circle-009.html)
- [shape-outside-circle-010.html](https://wpt.fyi/results/css/css-shapes/shape-outside/values/shape-outside-circle-010.html "css/css-shapes/shape-outside/values/shape-outside-circle-010.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/values/shape-outside-circle-010.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/values/shape-outside-circle-010.html)
- [shape-outside-circle-011.html](https://wpt.fyi/results/css/css-shapes/shape-outside/values/shape-outside-circle-011.html "css/css-shapes/shape-outside/values/shape-outside-circle-011.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/values/shape-outside-circle-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/values/shape-outside-circle-011.html)
- [shape-outside-computed-shape-000.html](https://wpt.fyi/results/css/css-shapes/shape-outside/values/shape-outside-computed-shape-000.html "css/css-shapes/shape-outside/values/shape-outside-computed-shape-000.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/values/shape-outside-computed-shape-000.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/values/shape-outside-computed-shape-000.html)
- [shape-outside-computed-shape-001.html](https://wpt.fyi/results/css/css-shapes/shape-outside/values/shape-outside-computed-shape-001.html "css/css-shapes/shape-outside/values/shape-outside-computed-shape-001.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/values/shape-outside-computed-shape-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/values/shape-outside-computed-shape-001.html)
- [shape-outside-ellipse-000.html](https://wpt.fyi/results/css/css-shapes/shape-outside/values/shape-outside-ellipse-000.html "css/css-shapes/shape-outside/values/shape-outside-ellipse-000.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/values/shape-outside-ellipse-000.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/values/shape-outside-ellipse-000.html)
- [shape-outside-ellipse-001.html](https://wpt.fyi/results/css/css-shapes/shape-outside/values/shape-outside-ellipse-001.html "css/css-shapes/shape-outside/values/shape-outside-ellipse-001.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/values/shape-outside-ellipse-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/values/shape-outside-ellipse-001.html)
- [shape-outside-ellipse-002.html](https://wpt.fyi/results/css/css-shapes/shape-outside/values/shape-outside-ellipse-002.html "css/css-shapes/shape-outside/values/shape-outside-ellipse-002.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/values/shape-outside-ellipse-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/values/shape-outside-ellipse-002.html)
- [shape-outside-ellipse-003.html](https://wpt.fyi/results/css/css-shapes/shape-outside/values/shape-outside-ellipse-003.html "css/css-shapes/shape-outside/values/shape-outside-ellipse-003.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/values/shape-outside-ellipse-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/values/shape-outside-ellipse-003.html)
- [shape-outside-ellipse-004.html](https://wpt.fyi/results/css/css-shapes/shape-outside/values/shape-outside-ellipse-004.html "css/css-shapes/shape-outside/values/shape-outside-ellipse-004.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/values/shape-outside-ellipse-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/values/shape-outside-ellipse-004.html)
- [shape-outside-ellipse-005.html](https://wpt.fyi/results/css/css-shapes/shape-outside/values/shape-outside-ellipse-005.html "css/css-shapes/shape-outside/values/shape-outside-ellipse-005.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/values/shape-outside-ellipse-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/values/shape-outside-ellipse-005.html)
- [shape-outside-ellipse-006.html](https://wpt.fyi/results/css/css-shapes/shape-outside/values/shape-outside-ellipse-006.html "css/css-shapes/shape-outside/values/shape-outside-ellipse-006.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/values/shape-outside-ellipse-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/values/shape-outside-ellipse-006.html)
- [shape-outside-ellipse-007.html](https://wpt.fyi/results/css/css-shapes/shape-outside/values/shape-outside-ellipse-007.html "css/css-shapes/shape-outside/values/shape-outside-ellipse-007.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/values/shape-outside-ellipse-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/values/shape-outside-ellipse-007.html)
- [shape-outside-ellipse-008.html](https://wpt.fyi/results/css/css-shapes/shape-outside/values/shape-outside-ellipse-008.html "css/css-shapes/shape-outside/values/shape-outside-ellipse-008.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/values/shape-outside-ellipse-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/values/shape-outside-ellipse-008.html)
- [shape-outside-ellipse-009.html](https://wpt.fyi/results/css/css-shapes/shape-outside/values/shape-outside-ellipse-009.html "css/css-shapes/shape-outside/values/shape-outside-ellipse-009.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/values/shape-outside-ellipse-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/values/shape-outside-ellipse-009.html)
- [shape-outside-ellipse-010.html](https://wpt.fyi/results/css/css-shapes/shape-outside/values/shape-outside-ellipse-010.html "css/css-shapes/shape-outside/values/shape-outside-ellipse-010.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/values/shape-outside-ellipse-010.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/values/shape-outside-ellipse-010.html)
- [shape-outside-ellipse-011.html](https://wpt.fyi/results/css/css-shapes/shape-outside/values/shape-outside-ellipse-011.html "css/css-shapes/shape-outside/values/shape-outside-ellipse-011.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/values/shape-outside-ellipse-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/values/shape-outside-ellipse-011.html)
- [shape-outside-inset-000.html](https://wpt.fyi/results/css/css-shapes/shape-outside/values/shape-outside-inset-000.html "css/css-shapes/shape-outside/values/shape-outside-inset-000.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/values/shape-outside-inset-000.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/values/shape-outside-inset-000.html)
- [shape-outside-inset-001.html](https://wpt.fyi/results/css/css-shapes/shape-outside/values/shape-outside-inset-001.html "css/css-shapes/shape-outside/values/shape-outside-inset-001.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/values/shape-outside-inset-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/values/shape-outside-inset-001.html)
- [shape-outside-inset-0010.html](https://wpt.fyi/results/css/css-shapes/shape-outside/values/shape-outside-inset-0010.html "css/css-shapes/shape-outside/values/shape-outside-inset-0010.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/values/shape-outside-inset-0010.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/values/shape-outside-inset-0010.html)
- [shape-outside-inset-002.html](https://wpt.fyi/results/css/css-shapes/shape-outside/values/shape-outside-inset-002.html "css/css-shapes/shape-outside/values/shape-outside-inset-002.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/values/shape-outside-inset-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/values/shape-outside-inset-002.html)
- [shape-outside-inset-003.html](https://wpt.fyi/results/css/css-shapes/shape-outside/values/shape-outside-inset-003.html "css/css-shapes/shape-outside/values/shape-outside-inset-003.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/values/shape-outside-inset-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/values/shape-outside-inset-003.html)
- [shape-outside-inset-004.html](https://wpt.fyi/results/css/css-shapes/shape-outside/values/shape-outside-inset-004.html "css/css-shapes/shape-outside/values/shape-outside-inset-004.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/values/shape-outside-inset-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/values/shape-outside-inset-004.html)
- [shape-outside-inset-005.html](https://wpt.fyi/results/css/css-shapes/shape-outside/values/shape-outside-inset-005.html "css/css-shapes/shape-outside/values/shape-outside-inset-005.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/values/shape-outside-inset-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/values/shape-outside-inset-005.html)
- [shape-outside-inset-006.html](https://wpt.fyi/results/css/css-shapes/shape-outside/values/shape-outside-inset-006.html "css/css-shapes/shape-outside/values/shape-outside-inset-006.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/values/shape-outside-inset-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/values/shape-outside-inset-006.html)
- [shape-outside-inset-007.html](https://wpt.fyi/results/css/css-shapes/shape-outside/values/shape-outside-inset-007.html "css/css-shapes/shape-outside/values/shape-outside-inset-007.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/values/shape-outside-inset-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/values/shape-outside-inset-007.html)
- [shape-outside-inset-008.html](https://wpt.fyi/results/css/css-shapes/shape-outside/values/shape-outside-inset-008.html "css/css-shapes/shape-outside/values/shape-outside-inset-008.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/values/shape-outside-inset-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/values/shape-outside-inset-008.html)
- [shape-outside-inset-009.html](https://wpt.fyi/results/css/css-shapes/shape-outside/values/shape-outside-inset-009.html "css/css-shapes/shape-outside/values/shape-outside-inset-009.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/values/shape-outside-inset-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/values/shape-outside-inset-009.html)
- [shape-outside-polygon-000.html](https://wpt.fyi/results/css/css-shapes/shape-outside/values/shape-outside-polygon-000.html "css/css-shapes/shape-outside/values/shape-outside-polygon-000.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/values/shape-outside-polygon-000.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/values/shape-outside-polygon-000.html)
- [shape-outside-polygon-001.html](https://wpt.fyi/results/css/css-shapes/shape-outside/values/shape-outside-polygon-001.html "css/css-shapes/shape-outside/values/shape-outside-polygon-001.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/values/shape-outside-polygon-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/values/shape-outside-polygon-001.html)
- [shape-outside-polygon-002.html](https://wpt.fyi/results/css/css-shapes/shape-outside/values/shape-outside-polygon-002.html "css/css-shapes/shape-outside/values/shape-outside-polygon-002.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/values/shape-outside-polygon-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/values/shape-outside-polygon-002.html)
- [shape-outside-polygon-003.html](https://wpt.fyi/results/css/css-shapes/shape-outside/values/shape-outside-polygon-003.html "css/css-shapes/shape-outside/values/shape-outside-polygon-003.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/values/shape-outside-polygon-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/values/shape-outside-polygon-003.html)
- [shape-outside-polygon-004.html](https://wpt.fyi/results/css/css-shapes/shape-outside/values/shape-outside-polygon-004.html "css/css-shapes/shape-outside/values/shape-outside-polygon-004.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/values/shape-outside-polygon-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/values/shape-outside-polygon-004.html)
- [shape-outside-polygon-005.html](https://wpt.fyi/results/css/css-shapes/shape-outside/values/shape-outside-polygon-005.html "css/css-shapes/shape-outside/values/shape-outside-polygon-005.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/values/shape-outside-polygon-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/values/shape-outside-polygon-005.html)
- [shape-outside-polygon-006.html](https://wpt.fyi/results/css/css-shapes/shape-outside/values/shape-outside-polygon-006.html "css/css-shapes/shape-outside/values/shape-outside-polygon-006.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/values/shape-outside-polygon-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/values/shape-outside-polygon-006.html)
- [shape-outside-shape-arguments-000.html](https://wpt.fyi/results/css/css-shapes/shape-outside/values/shape-outside-shape-arguments-000.html "css/css-shapes/shape-outside/values/shape-outside-shape-arguments-000.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/values/shape-outside-shape-arguments-000.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/values/shape-outside-shape-arguments-000.html)
- [shape-outside-shape-arguments-001.html](https://wpt.fyi/results/css/css-shapes/shape-outside/values/shape-outside-shape-arguments-001.html "css/css-shapes/shape-outside/values/shape-outside-shape-arguments-001.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/values/shape-outside-shape-arguments-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/values/shape-outside-shape-arguments-001.html)
- [shape-outside-shape-box-pair-000.html](https://wpt.fyi/results/css/css-shapes/shape-outside/values/shape-outside-shape-box-pair-000.html "css/css-shapes/shape-outside/values/shape-outside-shape-box-pair-000.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/values/shape-outside-shape-box-pair-000.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/values/shape-outside-shape-box-pair-000.html)
- [shape-outside-shape-inherit-000.html](https://wpt.fyi/results/css/css-shapes/shape-outside/values/shape-outside-shape-inherit-000.html "css/css-shapes/shape-outside/values/shape-outside-shape-inherit-000.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/values/shape-outside-shape-inherit-000.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/values/shape-outside-shape-inherit-000.html)
- [shape-outside-shape-initial-000.html](https://wpt.fyi/results/css/css-shapes/shape-outside/values/shape-outside-shape-initial-000.html "css/css-shapes/shape-outside/values/shape-outside-shape-initial-000.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/values/shape-outside-shape-initial-000.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/values/shape-outside-shape-initial-000.html)
- [shape-outside-shape-none-000.html](https://wpt.fyi/results/css/css-shapes/shape-outside/values/shape-outside-shape-none-000.html "css/css-shapes/shape-outside/values/shape-outside-shape-none-000.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/values/shape-outside-shape-none-000.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/values/shape-outside-shape-none-000.html)
- [shape-outside-shape-notation-000.html](https://wpt.fyi/results/css/css-shapes/shape-outside/values/shape-outside-shape-notation-000.html "css/css-shapes/shape-outside/values/shape-outside-shape-notation-000.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/values/shape-outside-shape-notation-000.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/values/shape-outside-shape-notation-000.html)
- [shape-outside-001.html](https://wpt.fyi/results/css/css-shapes/spec-examples/shape-outside-001.html "css/css-shapes/spec-examples/shape-outside-001.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/spec-examples/shape-outside-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/spec-examples/shape-outside-001.html)
- [shape-outside-002.html](https://wpt.fyi/results/css/css-shapes/spec-examples/shape-outside-002.html "css/css-shapes/spec-examples/shape-outside-002.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/spec-examples/shape-outside-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/spec-examples/shape-outside-002.html)
- [shape-outside-003.html](https://wpt.fyi/results/css/css-shapes/spec-examples/shape-outside-003.html "css/css-shapes/spec-examples/shape-outside-003.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/spec-examples/shape-outside-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/spec-examples/shape-outside-003.html)
- [shape-outside-004.html](https://wpt.fyi/results/css/css-shapes/spec-examples/shape-outside-004.html "css/css-shapes/spec-examples/shape-outside-004.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/spec-examples/shape-outside-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/spec-examples/shape-outside-004.html)
- [shape-outside-005.html](https://wpt.fyi/results/css/css-shapes/spec-examples/shape-outside-005.html "css/css-shapes/spec-examples/shape-outside-005.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/spec-examples/shape-outside-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/spec-examples/shape-outside-005.html)
- [shape-outside-006.html](https://wpt.fyi/results/css/css-shapes/spec-examples/shape-outside-006.html "css/css-shapes/spec-examples/shape-outside-006.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/spec-examples/shape-outside-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/spec-examples/shape-outside-006.html)
- [shape-outside-007.html](https://wpt.fyi/results/css/css-shapes/spec-examples/shape-outside-007.html "css/css-shapes/spec-examples/shape-outside-007.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/spec-examples/shape-outside-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/spec-examples/shape-outside-007.html)
- [shape-outside-008.html](https://wpt.fyi/results/css/css-shapes/spec-examples/shape-outside-008.html "css/css-shapes/spec-examples/shape-outside-008.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/spec-examples/shape-outside-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/spec-examples/shape-outside-008.html)
- [shape-outside-010.html](https://wpt.fyi/results/css/css-shapes/spec-examples/shape-outside-010.html "css/css-shapes/spec-examples/shape-outside-010.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/spec-examples/shape-outside-010.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/spec-examples/shape-outside-010.html)
- [shape-outside-011.html](https://wpt.fyi/results/css/css-shapes/spec-examples/shape-outside-011.html "css/css-shapes/spec-examples/shape-outside-011.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/spec-examples/shape-outside-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/spec-examples/shape-outside-011.html)
- [shape-outside-012.html](https://wpt.fyi/results/css/css-shapes/spec-examples/shape-outside-012.html "css/css-shapes/spec-examples/shape-outside-012.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/spec-examples/shape-outside-012.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/spec-examples/shape-outside-012.html)
- [shape-outside-013.html](https://wpt.fyi/results/css/css-shapes/spec-examples/shape-outside-013.html "css/css-shapes/spec-examples/shape-outside-013.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/spec-examples/shape-outside-013.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/spec-examples/shape-outside-013.html)
- [shape-outside-014.html](https://wpt.fyi/results/css/css-shapes/spec-examples/shape-outside-014.html "css/css-shapes/spec-examples/shape-outside-014.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/spec-examples/shape-outside-014.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/spec-examples/shape-outside-014.html)
- [shape-outside-015.html](https://wpt.fyi/results/css/css-shapes/spec-examples/shape-outside-015.html "css/css-shapes/spec-examples/shape-outside-015.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/spec-examples/shape-outside-015.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/spec-examples/shape-outside-015.html)
- [shape-outside-016.html](https://wpt.fyi/results/css/css-shapes/spec-examples/shape-outside-016.html "css/css-shapes/spec-examples/shape-outside-016.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/spec-examples/shape-outside-016.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/spec-examples/shape-outside-016.html)
- [shape-outside-017.html](https://wpt.fyi/results/css/css-shapes/spec-examples/shape-outside-017.html "css/css-shapes/spec-examples/shape-outside-017.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/spec-examples/shape-outside-017.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/spec-examples/shape-outside-017.html)
- [shape-outside-018.html](https://wpt.fyi/results/css/css-shapes/spec-examples/shape-outside-018.html "css/css-shapes/spec-examples/shape-outside-018.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/spec-examples/shape-outside-018.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/spec-examples/shape-outside-018.html)
- [shape-outside-019.html](https://wpt.fyi/results/css/css-shapes/spec-examples/shape-outside-019.html "css/css-shapes/spec-examples/shape-outside-019.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/spec-examples/shape-outside-019.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/spec-examples/shape-outside-019.html)

### 6.2. Choosing Image Pixels: the [shape-image-threshold property]
The
[shape-image-threshold](#propdef-shape-image-threshold) defines the alpha channel threshold
used to extract the shape using an image. A value of 0.5 means that the
shape will enclose all the pixels that are more than 50% opaque.

Name:

[shape-image-threshold]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<opacity-value\>](https://drafts.csswg.org/css-color-4/#typedef-opacity-opacity-value)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

0

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

floats

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

specified number, clamped to the range \[0,1\]

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value

The values of this property have the following meanings:

[[\<number\>](https://drafts.csswg.org/css-values-4/#number-value)]
: Sets the threshold used for extracting a shape from an image. The
 shape is defined by the pixels whose alpha value is greater than the
 threshold. A threshold value outside the range 0.0 (fully
 transparent) to 1.0 (fully opaque) will be clamped to this range.

 A future level of CSS Shapes may define a switch to use
the luminance data from an image instead of the alpha data. When this
happens, shape-image-threshold will be extended to apply its threshold
to either alpha or luminance, depending on the switch state.

Tests

- [shape-image-threshold-interpolation.html](https://wpt.fyi/results/css/css-shapes/animation/shape-image-threshold-interpolation.html "css/css-shapes/animation/shape-image-threshold-interpolation.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/animation/shape-image-threshold-interpolation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/animation/shape-image-threshold-interpolation.html)
- [inheritance.html](https://wpt.fyi/results/css/css-shapes/inheritance.html "css/css-shapes/inheritance.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/inheritance.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/inheritance.html)
- [shape-image-threshold-computed.html](https://wpt.fyi/results/css/css-shapes/parsing/shape-image-threshold-computed.html "css/css-shapes/parsing/shape-image-threshold-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/parsing/shape-image-threshold-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/parsing/shape-image-threshold-computed.html)
- [shape-image-threshold-invalid.html](https://wpt.fyi/results/css/css-shapes/parsing/shape-image-threshold-invalid.html "css/css-shapes/parsing/shape-image-threshold-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/parsing/shape-image-threshold-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/parsing/shape-image-threshold-invalid.html)
- [shape-image-threshold-valid.html](https://wpt.fyi/results/css/css-shapes/parsing/shape-image-threshold-valid.html "css/css-shapes/parsing/shape-image-threshold-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/parsing/shape-image-threshold-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/parsing/shape-image-threshold-valid.html)
- [shape-image-threshold-000.html](https://wpt.fyi/results/css/css-shapes/shape-outside/values/shape-image-threshold-000.html "css/css-shapes/shape-outside/values/shape-image-threshold-000.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/values/shape-image-threshold-000.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/values/shape-image-threshold-000.html)
- [shape-image-threshold-001.html](https://wpt.fyi/results/css/css-shapes/shape-outside/values/shape-image-threshold-001.html "css/css-shapes/shape-outside/values/shape-image-threshold-001.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/values/shape-image-threshold-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/values/shape-image-threshold-001.html)
- [shape-image-threshold-002.html](https://wpt.fyi/results/css/css-shapes/shape-outside/values/shape-image-threshold-002.html "css/css-shapes/shape-outside/values/shape-image-threshold-002.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/values/shape-image-threshold-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/values/shape-image-threshold-002.html)
- [shape-image-threshold-003.html](https://wpt.fyi/results/css/css-shapes/shape-outside/values/shape-image-threshold-003.html "css/css-shapes/shape-outside/values/shape-image-threshold-003.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/values/shape-image-threshold-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/values/shape-image-threshold-003.html)

### 6.3. Expanding a Shape: the [shape-margin property]
The [shape-margin](#propdef-shape-margin) property adds a margin to a
[shape-outside](#propdef-shape-outside). This defines a new shape that is
the smallest contour (in the shrink-wrap sense) that includes all the
points that are the [shape-margin] distance outward in the perpendicular direction from a point
on the underlying shape. This includes any edge or line sections from
the underlying shape. Note that at points where a perpendicular is not
defined (e.g. sharp points or line ends) take all points on the circle
centered at the point and with a radius of
[shape-margin].

The new shape produced by applying
[shape-outside](#propdef-shape-outside) is what determines the [float
area](#float-area), and must be
constructed before making any [wrap](#wrap) decisions.

This property takes only non-negative values.

Name:

[shape-margin]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<length-percentage
\[0,∞\]\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

0

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

floats and [initial letter
boxes](https://drafts.csswg.org/css-inline-3/#initial-letter)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

refer to the [inline
size](https://drafts.csswg.org/css-sizing-3/#inline-size) of the containing block

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

computed
[\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage) value

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value

[[\<length-percentage \[0,∞\]\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage)]
: Sets the margin of the shape to the specified value.

 Adding a shape-margin does NOT allow a float area to
extend outside a float's margin box. Extra margin may need to be applied
along with shape-margin to avoid clipping.

A [shape-margin](#propdef-shape-margin) creating an offset from a polygonal
[shape-outside](#propdef-shape-outside). The lighter blue area shows the
shape in a 100x100px float, and the darker blue area shows the 10px
offset.

 .float {
 width: 100px;
 height: 100px;
 shape-outside: polygon(10px 10px, 90px 50px, 40px 50px, 90px 90px, 10px 90px);
 shape-margin: 10px;
 }

![Example of a shape-margin
offset](images/nepal-flag-shape.png){height="280" width="634"}

If shape-margin is added to the CSS logo from example 6, the line boxes
[wrapping](#wrap) around the shape are
shortened further. In case the image's alpha channel runs up to the
right edge of the image, some extra margin-right should be applied to
ensure the shape is not clipped by the margin box.

 #CSSlogo {
 shape-margin: 35px;
 margin-right: 35px;
 }

![A float shape around an image using its alpha-channel with a 35-pixel
[shape-margin](#propdef-shape-margin)](images/shape-outside-image-with-margin.png){a
height="251" style="width:70%" width="634"}

- [shape-margin-composition.html](https://wpt.fyi/results/css/css-shapes/animation/shape-margin-composition.html "css/css-shapes/animation/shape-margin-composition.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/animation/shape-margin-composition.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/animation/shape-margin-composition.html)
- [shape-margin-interpolation.html](https://wpt.fyi/results/css/css-shapes/animation/shape-margin-interpolation.html "css/css-shapes/animation/shape-margin-interpolation.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/animation/shape-margin-interpolation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/animation/shape-margin-interpolation.html)
- [inheritance.html](https://wpt.fyi/results/css/css-shapes/inheritance.html "css/css-shapes/inheritance.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/inheritance.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/inheritance.html)
- [shape-margin-computed.html](https://wpt.fyi/results/css/css-shapes/parsing/shape-margin-computed.html "css/css-shapes/parsing/shape-margin-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/parsing/shape-margin-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/parsing/shape-margin-computed.html)
- [shape-margin-invalid.html](https://wpt.fyi/results/css/css-shapes/parsing/shape-margin-invalid.html "css/css-shapes/parsing/shape-margin-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/parsing/shape-margin-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/parsing/shape-margin-invalid.html)
- [shape-margin-valid.html](https://wpt.fyi/results/css/css-shapes/parsing/shape-margin-valid.html "css/css-shapes/parsing/shape-margin-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/parsing/shape-margin-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/parsing/shape-margin-valid.html)
- [shape-outside-margin-box-001.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-001.html "css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-001.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-001.html)
- [shape-outside-margin-box-002.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-002.html "css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-002.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-002.html)
- [shape-outside-margin-box-border-radius-001.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-border-radius-001.html "css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-border-radius-001.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-border-radius-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-border-radius-001.html)
- [shape-outside-margin-box-border-radius-002.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-border-radius-002.html "css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-border-radius-002.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-border-radius-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-border-radius-002.html)
- [shape-outside-margin-box-border-radius-003.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-border-radius-003.html "css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-border-radius-003.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-border-radius-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-border-radius-003.html)
- [shape-outside-margin-box-border-radius-004.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-border-radius-004.html "css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-border-radius-004.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-border-radius-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-border-radius-004.html)
- [shape-outside-margin-box-border-radius-005.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-border-radius-005.html "css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-border-radius-005.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-border-radius-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-border-radius-005.html)
- [shape-outside-margin-box-border-radius-006.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-border-radius-006.html "css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-border-radius-006.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-border-radius-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-border-radius-006.html)
- [shape-outside-margin-box-border-radius-007.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-border-radius-007.html "css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-border-radius-007.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-border-radius-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-border-radius-007.html)
- [shape-outside-margin-box-border-radius-008.html](https://wpt.fyi/results/css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-border-radius-008.html "css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-border-radius-008.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-border-radius-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/shape-box/shape-outside-margin-box-border-radius-008.html)
- [shape-margin-000.html](https://wpt.fyi/results/css/css-shapes/shape-outside/values/shape-margin-000.html "css/css-shapes/shape-outside/values/shape-margin-000.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/values/shape-margin-000.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/values/shape-margin-000.html)
- [shape-margin-001.html](https://wpt.fyi/results/css/css-shapes/shape-outside/values/shape-margin-001.html "css/css-shapes/shape-outside/values/shape-margin-001.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/values/shape-margin-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/values/shape-margin-001.html)
- [shape-margin-002.html](https://wpt.fyi/results/css/css-shapes/shape-outside/values/shape-margin-002.html "css/css-shapes/shape-outside/values/shape-margin-002.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/values/shape-margin-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/values/shape-margin-002.html)
- [shape-margin-003.html](https://wpt.fyi/results/css/css-shapes/shape-outside/values/shape-margin-003.html "css/css-shapes/shape-outside/values/shape-margin-003.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/values/shape-margin-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/values/shape-margin-003.html)
- [shape-margin-004.html](https://wpt.fyi/results/css/css-shapes/shape-outside/values/shape-margin-004.html "css/css-shapes/shape-outside/values/shape-margin-004.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/values/shape-margin-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/values/shape-margin-004.html)
- [shape-margin-005.html](https://wpt.fyi/results/css/css-shapes/shape-outside/values/shape-margin-005.html "css/css-shapes/shape-outside/values/shape-margin-005.html")
 [[(live
 test)]](http://wpt.live/css/css-shapes/shape-outside/values/shape-margin-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-shapes/shape-outside/values/shape-margin-005.html)

## 7. Privacy Considerations

No privacy concerns have been raised against this specification.

## 8. Security Considerations

Since the
[\<image\>](https://drafts.csswg.org/css-images-3/#typedef-image) value of
[shape-outside](#propdef-shape-outside) can expose some image data in a new
way, use is limited to images with CORS approval.

## [ Acknowledgments]
This specification is made possible by input from Tab Atkins Jr., Amelia
Bellamy-Royds, Oriol Brufau, Andrei Bucur, Alexandru Chiculita, Boris
Chiou, Emilio Cobos Álvarez, Elika Etemad, Arron Eicholz, Sylvain
Galineau, Daniel Glazman, Arno Gourdol, Zoltan Horvath, Chris Jones, Bem
Jones-Bey, Ian Kilpatrick, Guillaume Lebas, Ting-Yu Lin, Eric Meyer,
Marcus Mielke, Alex Mogilevsky, Hans Muller, Mihnea Ovidenie, Virgil
Palanciuc, Noam Rosenthal, Robert Sanderson, Dirk Schulze, Jen Simmons,
Peter Sorotokin, Bear Travis, Lea Verou, Eugene Veselov, Brad Werth,
Stephen Zilles and the CSS Working Group members.

## [ Change Log]
### [ Since [2 June 2025](https://www.w3.org/TR/2025/CRD-css-shapes-1-20250612/)]
- none

### [ Since [15 November 2022](https://www.w3.org/TR/2022/CRD-css-shapes-1-20221115/)]
- Added Web Platform Test annotations
- Changed fill-rule default for path() in SVG shapes
- Clarified shape-margin and float area interaction
- Added polygon rounding examples
- Included all basic shapes in property prose for [issue
 #9728](https://github.com/w3c/csswg-drafts/issues/9728)
- Added start of polygon vertex rounding
- Used opacity-value (the value) not opacity (the property) as value of
 shape-image-threshold for [issue
 #8311](https://github.com/w3c/csswg-drafts/issues/8311)
- Replaced \<alpha-value\> with
 \<[opacity](https://drafts.csswg.org/css-color-4/#propdef-opacity)\>
- Clarified that shape-outside applies to initial letter boxes for
 [issue #5160](https://github.com/w3c/csswg-drafts/issues/5160)
- Rebased ellipse()/circle() definitions on top of \<radial-size\> from
 Images, for [issue
 #824](https://github.com/w3c/csswg-drafts/issues/824)
- Made it clear that the position defaulting can be overridden by other
 specs (like Motion).
- Targeted fix of shape serialization section, fixed examples, for
 [issue #8695](https://github.com/w3c/csswg-drafts/issues/8695)
- Fixed xywh() computed value for [issue
 #9053](https://github.com/w3c/csswg-drafts/issues/9053)
- Rewrote syntax with implicitly optional comma [PR
 #9650](https://github.com/w3c/csswg-drafts/pull/9650)
- Cleanup \<\*-box\> definitions [PR
 #9505](https://github.com/w3c/csswg-drafts/pull/9505)
- Added range notation in property definitions
- Added vertex rounding for polygon() for [issue
 #9843](https://github.com/w3c/csswg-drafts/issues/9843)
- Updated shape-outside prose to include all
 [\<basic-shape\>](#typedef-basic-shape)s for [issue
 #9728](https://github.com/w3c/csswg-drafts/issues/9728)
- Clarified the shape-margin contribution to float areas for [issue
 #2949](https://github.com/w3c/csswg-drafts/issues/2949)
- Added fill-rule default handling for SVG shapes from [issue
 #3468](https://github.com/w3c/csswg-drafts/issues/3468)
- Moved \'shape()\' from level 2

### [ Since [March 20th 2014](https://www.w3.org/TR/2014/CR-css-shapes-1-20140320/)]
- Clarified shape-margin computed value
- Clarified serialization of default position values, for [issue
 #402](https://github.com/w3c/csswg-drafts/issues/402)
- Clarified empty circles and ellipses for [issue
 #850](https://github.com/w3c/csswg-drafts/issues/850)
- Dropped the \"Media:\" entry from propdef tables, as with all CSS
 modules
- Updated box model references from CSS 2 to CSS Box Model 3
- Updated Computed Value and Animation Type in propdef tables
- Clarified computed value of shape-outside property, for [issue
 #4042](https://github.com/w3c/csswg-drafts/issues/4042)
- Clarified that shape-image-threshold can take a percentage value, like
 any alpha value, for [issue
 #4102](https://github.com/w3c/csswg-drafts/issues/4102)
- Moved path() back from level 2
- Added handling of negative margins for margin-box, for [issue
 #675](https://github.com/w3c/csswg-drafts/issues/675)
- Removed special-case serialization of position values, for [issue
 #2301](https://github.com/w3c/csswg-drafts/issues/2301)
- Added clarifications to shape-margin examples
- Added margin=0 case for margin-box shape, for [issue
 #675](https://github.com/w3c/csswg-drafts/issues/675)
- Changed rules about degenerate shapes to use shape edges, for [issue
 #2375](https://github.com/w3c/csswg-drafts/issues/2375)
- Clarified that invalid path strings make the
 [path()](#funcdef-basic-shape-path) invalid, for [issue
 #392](https://github.com/w3c/fxtf-drafts/issues/392)
- Rewrote definition of inset rectangles, added auto value, added
 examples
- Clarified computed value of basic shape rect functions
- Assorted markup fixes, including use of range notation and exporting
 defined terms for use in other specifications
- Split Privacy and Security considerations into separate sections

### [ Since [February 11th 2014](https://www.w3.org/TR/2014/WD-css-shapes-1-20140211/)]
- Replaced divs with images in the first example
- Add 0px to last serialization example

### [ Since [December 3rd 2013](https://www.w3.org/TR/2013/WD-css-shapes-1-20131203/)]
- Updated computed value and serialization of basic shapes
- Added a margin-box example
- Change auto to none for shape-outside
- Defined shape-box instead of redefining box
- Clarified that shape from image may produce more than one path

### [ Since [June 20th 2013](https://www.w3.org/TR/2013/WD-css-shapes-1-20130620/)]
- Added shape from box value section
- Updated basic-shape interpolation
- Allow negative insets, disallow negative radii
- Changed relevant to reference
- Remove box-sizing dependency, add relevant box keywords
- Changed circle() and ellipse() to use radial gradient syntax
- Postponed rectangle() to level 2
- Clarified shape-from-image sizing and positioning
- Change inset-rectangle() to inset()
- Future-proof shape-image-threshold to possibly apply to luminance
- Added CORS fetching to shape-outside URLs
- Changed shape-outside value from \<uri\> to \<image\>
- Remove \'percentages based on auto-sizing resolve to 0\'
- Change initial value of shape-image-threshold to 0.0
- Change float positioning to be unaffected by shape-outside
- Shapes on floats clipped to float's margin box

### [ Since [May 3rd 2012](https://www.w3.org/TR/2012/WD-css3-exclusions-20120503/)]
- Postpone shapes from SVG elements to a future Shapes level
- Postpone shape-inside to a future Shapes level
- split exclusions from shapes into separate modules
- added inset-rectangle() to basic shapes
- Changed shape-inside overflow diagrams to show exclusion behavior
- Changed shape-inside to contribute to the wrapping context
- Defined exclusion edges relative to wrapping content's writing mode
- Made use of start, end, before and after consistent
- Added interpolation for basic shapes
- Changed basic shapes to depend on box specified with box-sizing
- Added overflow behavior for shape-inside.
- Added wrap-flow:minimum.
- Clarified processing model.
- Changed wrap-margin and wrap-padding to shape-margin and
 shape-padding.
- Removed wrap shorthand.

### [ Since [December 13th 2011](https://www.w3.org/TR/2011/WD-css3-exclusions-20111213/)]
- Clarified processing model.
- Clarified interaction with floats.
- Clarified that an exclusion element establishes a new block formatting
 context.
