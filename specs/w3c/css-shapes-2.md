## 1. Introduction

*This section is not normative.*

Level 1 of this specification defined properties to control the geometry
of an element's [float area](#float-area). This level defines how shapes apply to exclusions. It
also includes a
[shape-inside](#propdef-shape-inside) property for applying a shape to an
element's content area. Finally, it defines new ways of specifying
shapes for all of these applications.

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

## 2. Terminology

[exclusion area]

: The area used for excluding inline flow content around an exclusion
 box. The [exclusion area](#exclusion-area) is equivalent to the [border
 box](https://drafts.csswg.org/css-box-4/#border-box) for an exclusion box. This specification's
 [shape-outside](https://drafts.csswg.org/css-shapes-1/#propdef-shape-outside) property can be used to define
 arbitrary, non-rectangular [exclusion
 areas]. The
 [shape-inside](#propdef-shape-inside) property also defines an
 [exclusion area], but in this case it is
 the area outside the shape that inline content avoids.

[float area]

: The area used for wrapping content around a float element. By
 default, the float area is the float element's [margin
 box](https://drafts.csswg.org/css-box-4/#margin-box). This specification's
 [shape-outside](https://drafts.csswg.org/css-shapes-1/#propdef-shape-outside) property can be used to define
 arbitrary, non-rectangular float areas.

[content area]

: The [content area](#content-area) is normally used for layout of the inline flow
 content of a box.

## 3. Shapes

Shapes define arbitrary geometric contours around which inline content
flows. The shape-outside property defines the [float
area](#float-area) for a float,
and the [exclusion area](#exclusion-area) for an exclusion.

## 4. Basic Shapes

Add the final [level
1](https://www.w3.org/TR/css-shapes/#basic-shape-functions) section.

This level extends the
[\<basic-shape\>](https://drafts.csswg.org/css-shapes-1/#typedef-basic-shape) functions to include
[shape()](https://drafts.csswg.org/css-shapes-1/#funcdef-basic-shape-shape):

``` prod
<basic-shape> = <basic-shape-rect> | <circle()> | <ellipse()> | <polygon()> | <path()> | <shape()>
```

### 4.1. Supported Shapes

Add the final [level
1](https://www.w3.org/TR/css-shapes/#basic-shape-functions) sections.

#### [4.1.1. ][ The [shape()](https://drafts.csswg.org/css-shapes-1/#funcdef-basic-shape-shape) Function]
Add the final [level
1](https://drafts.csswg.org/css-shapes-1/#shape-function) section.

## 5. Referencing SVG shapes

An SVG shape can be referenced using the `url()` syntax. The shape can
be any of the [SVG basic shapes](https://www.w3.org/TR/SVG/shapes.html)
or a [path element](https://www.w3.org/TR/SVG/paths.html).

![results of referencing SVG
shapes](images/svg-shape-reference.png){height="350"
style="float: right" width="166"}

``` highlight
<style>
div {
 height: 400px;
 width: 400px;
}
.in-a-circle {
 shape-outside: url(#circle_shape);
}

.in-a-path {
 shape-outside: url(#path-shape);
}
</style>

<svg ...>
 <circle id="circle_shape" cx="50%" cy="50%" r="50%" />
 <path id="path-shape" d="M 100 100 L 300 100 L 200 300 z" />
</svg>

<div class="around-a-circle">...</div>
<div class="around-a-path">...</div>
```

## 6. Shapes from Image

Add the final [level
1](https://www.w3.org/TR/css-shapes/#shapes-from-image) section.

One
[suggestion](https://www.w3.org/Bugs/Public/show_bug.cgi?id=16716) is to
define a shape based on an element's rendered content. This could have
security implications.

Another
[suggestion](http://lists.w3.org/Archives/Public/www-style/2014Mar/0120.html)
is to add something to an image() function that determines the relevant
pixels to use (both for defining a shape and for display).

## 7. Fetching external shapes

To [fetch an external resource for a
shape], either an SVG or an image, given a [CSS
declaration
block](https://drafts.csswg.org/cssom-1/#css-declaration-block) `declaration`, [fetch a style
resource](https://drafts.csswg.org/css-values-4/#fetch-a-style-resource) given a
[\<url\>](https://drafts.csswg.org/css-values-4/#url-value) value, with ruleOrDeclaration being
`declaration`, destination \"image\", CORS mode \"cors\", and
processResponse being the following steps given
[response](https://fetch.spec.whatwg.org/#concept-response) `res` and null, failure or a byte stream
`byteStream`: If `byteStream` is a byte stream,
apply the image or SVG to the appropriate shape-accepting property.

 shapes require CORS mode as their effect is detected by
the document.

## 8. Shapes from Box Values

Add the final [level
1](https://www.w3.org/TR/css-shapes/#shapes-from-box-values) section.

## 9. Declaring Shapes

A shape can be declared with the
[shape-outside](https://drafts.csswg.org/css-shapes-1/#propdef-shape-outside) property, with possible
modifications from the
[shape-margin](https://drafts.csswg.org/css-shapes-1/#propdef-shape-margin) property. The shape defined by the
[shape-outside] and
[shape-margin] properties
changes the geometry of a float element's [float
area](#float-area) and an
exclusion element's [exclusion
area](#exclusion-area).

A shape can be declared with the
[shape-inside](#propdef-shape-inside) property, with possible
modifications from the
[shape-padding](#propdef-shape-padding) property. The shape defined by the
[shape-inside] and
[shape-padding] properties
defines an [exclusion area](#exclusion-area) that contributes to the element's [wrapping
context](https://www.w3.org/TR/css3-exclusions/#wrapping-context). The [shape-inside] property applies to all block-level elements.

The red box illustrates an exclusion
element's content box, which is unmodified and subject to normal CSS
positioning (here absolute positioning).

``` highlight
<style type="text/css">
.exclusion {
 wrap-flow: both;
 position: absolute;
 top: 25%;
 left: 25%;
 width: 50%;
 height: 50%;
 shape-outside: circle(50% at 50% 50%);
 border: 1px solid red;
}
</style>

<div style=”position: relative;”>
 <div class=”exclusion”></div>
 Lorem ipsum dolor sit amet...
</div>
```

![Example rendering of circle shape and box
model.](images/shapes_CSS2.1_MBP.png)

### [9.1. ][ The [shape-outside](https://drafts.csswg.org/css-shapes-1/#propdef-shape-outside) Property]
Add the final [level
1](https://www.w3.org/TR/css-shapes/#shape-outside-property) section
with the change that shape-outside applies to block-level elements and
has an effect if the element is an exclusion.

### 9.2. The [shape-inside Property]
The [shape-inside](#propdef-shape-inside) property adds one or more exclusion
areas to the element's wrapping context. This modifies the normal
rectangular shape of the content area to a possibly non-rectangular
wrapping area. The exclusion areas are defined by subtracting the shape
from the element's content area. Any part of the shape outside the
element's content area has no effect.

Name:

[shape-inside]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

auto
[\|](https://drafts.csswg.org/css-values-4/#comb-one) outside-shape [\|] \[
[\<basic-shape\>](https://drafts.csswg.org/css-shapes-1/#typedef-basic-shape)
[\|\|](https://drafts.csswg.org/css-values-4/#comb-any) shape-box \] [\|]
[\<image\>](https://drafts.csswg.org/css-images-3/#typedef-image) [\|] display

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

auto

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

block-level elements

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

computed lengths for
[\<basic-shape\>](https://drafts.csswg.org/css-shapes-1/#typedef-basic-shape), the absolute URL for
[\<url\>](https://drafts.csswg.org/css-values-4/#url-value), otherwise as specified

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

as defined for
[\<basic-shape\>](https://drafts.csswg.org/css-shapes-1/#typedef-basic-shape), otherwise discrete

The values of this property have the following meanings:

[auto]
: The shape is computed based on the content box of the element.

[outside-shape]
: The shape is computed based on the shape defined by the
 shape-outside and shape-margin properties.

[[\<basic-shape\>](https://drafts.csswg.org/css-shapes-1/#typedef-basic-shape)]
: The shape is computed based on the values of one of the
 [\<basic-shape\>](https://drafts.csswg.org/css-shapes-1/#typedef-basic-shape) functions.

[[\<url\>](https://drafts.csswg.org/css-values-4/#url-value)]

: If the \<uri\> references an SVG shape element, that element defines
 the shape. Otherwise, if the \<uri\> references an image, the shape
 is extracted and computed based on the alpha channel of the
 specified image.

 If the \<uri\> does not reference an SVG shape element or an image,
 the effect is as if the value
 [auto](#valdef-shape-inside-auto) had been specified.

[display]
: The shape is computed based on the shape of the display as described
 in [css-round-display](https://drafts.csswg.org/css-round-display).

The [shape-inside](#propdef-shape-inside) property applies to floats.

The [shape-inside](#propdef-shape-inside) property may not apply on some
elements such as elements with a computed
[display](https://drafts.csswg.org/css-display-4/#propdef-display) value of
[table](https://drafts.csswg.org/css-display-3/#valdef-display-table).

![Effect of shape-inside on inline
content.](images/shape-inside-content.png){a
height="349" width="743"}

Overflow content avoids the exclusion area(s) added by
[shape-inside](#propdef-shape-inside) and
[shape-padding](#propdef-shape-padding) (as well as any other exclusion
areas in the element's wrapping context). In other words, overflow
continues outside the rectangular bounds of the element.

<figure>
<img src="images/rounded-rect-overflow.png"
style="display:inline-block;vertical-align:top" width="311" height="297"
a /> <img
src="images/ellipse-overflow.png"
style="display:inline-block;vertical-align:top" width="311" height="297"
a />
<figcaption>Overflow interacting with exclusion areas defined by <a
href="#propdef-shape-inside" id="ref-for-propdef-shape-inside①⓪"
class="css property" data->shape-inside</a> and <a
href="#propdef-shape-padding" id="ref-for-propdef-shape-padding③"
class="css property"
data->shape-padding</a>.</figcaption>
</figure>

improve the illustration above, using
text to show overflow instead of grey boxes.

When a shape-inside has a definite size (no percentages used in the
shape's definition) an auto-sized element should use the shape as a
constraint in determining its maximum size.

### [9.3. ][ The [shape-image-threshold](https://drafts.csswg.org/css-shapes-1/#propdef-shape-image-threshold) Property]
Add the final [level
1](https://www.w3.org/TR/css-shapes/#shape-image-threshold-property)
section with the change that it applies to both
[shape-inside](#propdef-shape-inside) and
[shape-outside](https://drafts.csswg.org/css-shapes-1/#propdef-shape-outside).

### [9.4. ][ The [shape-image-source-type] Property]
Should we add an alpha/luminance switch to determine which values we use
from the shape-image source? This could just be a keyword on the
shape-image-threshold property. Whatever we go with should be compatible
with the alpha/luminance switch from mask sources.

### [9.5. ][ The [shape-margin](https://drafts.csswg.org/css-shapes-1/#propdef-shape-margin) property]
Add the final [level
1](https://www.w3.org/TR/css-shapes/#shape-margin-property) section with
the change that it applies to exclusions.

### 9.6. The [shape-padding Property]
The
[shape-padding](#propdef-shape-padding) property adds padding to a
shape-inside. This defines a new shape where every point is the
specified distance from the shape-inside. This property takes on
positive values only.

Name:

[shape-padding]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<length-percentage
\[0,∞\]\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

0

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

block-level elements

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
: Sets the padding of the shape to the specified value.

![A
[shape-padding](#propdef-shape-padding) creating an offset from a circular
[shape-inside](#propdef-shape-inside). The light blue rectangles
represent inline content affected by the shape created by the
padding.](images/shape-padding.png){a
height="222" width="222"}

[shape-padding](#propdef-shape-padding) property only affects layout of
content inside the element it applies to while the
[shape-margin](https://drafts.csswg.org/css-shapes-1/#propdef-shape-margin) property only affects layout of
content outside the element.

## [Privacy Considerations]
No new privacy considerations have been reported on this specification.

## [Security Considerations]
No new security considerations have been reported on this specification.
