## 1. Introduction

*This section is not normative.*

This specification defines two different graphical operations which both
fully or partly hide portions of an object: clipping and masking.

### 1.1. Clipping

A closed vector path, shape or polygon defines a so called [clipping
path]. This
clipping path is a region (in the absence of anti-aliasing) where
everything on the "inside" of this region is allowed to show through but
everything on the outside is "clipped out" and does not appear on the
canvas.

![Example Mask](images/clipping-path.svg){height="260" width="655"}

A clipping path (middle) is applied on a polygon shaded with different
colors (left). This results in a "clipped out" shape (right).

The [clip-path](#propdef-clip-path) property can use specified basic shapes as
clipping path or reference an
[clipPath](#elementdef-clippath) element with [graphics
elements](https://www.w3.org/TR/SVG2/struct.html#graphics-element) to be used as clipping path.

### 1.2. Masking

The effect of applying a mask to a graphical object is as if the
graphical object will be painted onto the background through a mask,
thus completely or partially masking out parts of the graphical object.

![Example Mask](images/luminance-mask.svg){height="260" width="655"}

A luminance mask (middle) is applied on a shape filled with a gradient
(left). This results in a masked shape (right).

Masks are applied using the
[mask-image](#propdef-mask-image) or
[mask-border-source](#propdef-mask-border-source) properties.

The [mask-image](#propdef-mask-image) property may reference a
[mask](#elementdef-mask)
element. The content of the [mask] element
serves as the mask.

Alternatively, for many simple uses, the
[mask-image](#propdef-mask-image) property may refer directly to images to be used
as mask, forgoing the need for an explicit
[mask](#elementdef-mask)
element. This mask can then be sized and positioned just like CSS
background images using the
[mask-position](#propdef-mask-position),
[mask-size](#propdef-mask-size) and other characterizing properties.

The
[mask-border-source](#propdef-mask-border-source) property splits a mask into 9 pieces.
The pieces may be sliced, scaled and stretched in various ways to fit
the size of the [mask border image
area](#mask-border-image-area). The
[mask-border](#propdef-mask-border) property serves as a shorthand property
for [mask-border-source]
and other characterizing properties.

The [mask](#propdef-mask) property serves as a shorthand property for all
[mask-border](#propdef-mask-border) and
[mask-image](#propdef-mask-image) affiliated properties.

Note: While masking gives many possibilities for enhanced graphical
effects and in general provides more control over the "visible portions"
of the content, clipping paths can perform better and basic shapes are
easier to interpolate.

## 2. Module interactions

This specification defines a set of CSS properties that affect the
visual rendering of elements to which those properties are applied.
These effects are applied after elements have been sized and positioned
according to the [Visual formatting
model](https://www.w3.org/TR/CSS2/visuren.html "Visual formatting model")
from [\[CSS21\]](#biblio-css21). Some values of
these properties result in the creation of a [stacking
context](https://www.w3.org/TR/SVG2/render.html#TermStackingContext). Furthermore, this specification replaces the section
[Clipping: the clip
property](https://www.w3.org/TR/CSS2/visufx.html#clipping) from
\[CSS21\].

The compositing model follows the SVG compositing model
[\[SVG11\]](#biblio-svg11): First the element is
styled under absence of filter effects, masking, clipping and opacity.
Then the element and its descendants are drawn on a temporary canvas. In
a last step the following effects are applied to the element in order:
filter effects
[\[FILTER-EFFECTS\]](#biblio-filter-effects),
clipping, masking and opacity.

This specification allows compositing multiple mask layers with the
Porter Duff compositing operators defined in CSS Compositing and
Blending [\[COMPOSITING-1\]](#biblio-compositing-1).

The term [object bounding
box](https://www.w3.org/TR/SVG2/coords.html#TermObjectBoundingBox) follows the definition in SVG 1.1
[\[SVG11\]](#biblio-svg11).

## 3. Values

This specification follows the [CSS property definition
conventions](https://www.w3.org/TR/CSS21/about.html#property-defs) from
[\[CSS21\]](#biblio-css21). Basic shapes are defined
in CSS Shapes Module Level 1
[\[CSS-SHAPES\]](#biblio-css-shapes). Value types
not defined in these specifications are defined in CSS Values and Units
Module Level 3 [\[CSS3VAL\]](#biblio-css3val).

In addition to the property-specific values listed in their definitions,
all properties defined in this specification also accept CSS-wide
keywords such as
[inherit](https://www.w3.org/TR/CSS21/cascade.html#value-def-inherit) as
their property value [\[CSS3VAL\]](#biblio-css3val).
For readability it has not been repeated explicitly.

## 4. Terminology

Definitions of CSS properties and values in this specification are
analogous to definitions in CSS Backgrounds and Borders
[\[CSS3BG\]](#biblio-css3bg). To avoid redundancy,
this specification relies on descriptions and definitions of CSS
Backgrounds and Borders. The following terms in CSS Backgrounds and
Borders have the following meaning in this specification:

Term in CSS Masking

Term in [\[CSS3BG\]](#biblio-css3bg)

[mask layer image](#mask-layer-image)

background images

[mask painting area](#mask-painting-area)

[background painting
area](https://www.w3.org/TR/css-backgrounds-3/#background-painting-area)

[mask-size(#mask-size)]

background-size

[mask-position(#mask-position)]

background-position

[mask positioning
area](#mask-positioning-area)

[background positioning
area](https://www.w3.org/TR/css-backgrounds-3/#background-positioning-area)

[mask border image](#mask-border-image)

border-image

[mask border image
area](#mask-border-image-area)

[border image
area](https://www.w3.org/TR/css-backgrounds-3/#border-image-area)

## 5. Clipping Paths

The clipping path restricts the region to which paint can be applied,
the so-called [clipping region]. Conceptually, any parts of the drawing that
lie outside of this region are not drawn. This includes any content,
background, borders, text decoration, outline and visible scrolling
mechanism of the element to which the clipping path is applied, and
those of its descendants.

An element's ancestors may also clip portions of their content (e.g.,
via their own [clip](#propdef-clip) or
[clip-path](#propdef-clip-path) properties and/or if their
[overflow](https://www.w3.org/TR/css-overflow-3/#propdef-overflow) property is not
[visible](https://www.w3.org/TR/css-overflow-3/#valdef-overflow-visible)). What is rendered is the cumulative
intersection.

If the clipping region exceeds the bounds of the UA's document window,
content may be clipped to that window by the native operating
environment.

A clipping path affects the rendering of an element. It does not affect
the element's inherent geometry. The geometry of a clipped element (i.e.
an element which references a
[clipPath](#elementdef-clippath) element via a
[clip-path](#propdef-clip-path) property, or a child of the referencing element)
must remain the same as if it were not clipped.

Consider a shape that is clipped by a
clipping path applied to an ancestor:

``` highlight
<g clip-path="circle()">
 <path id="shape" d="M0,0 L10,10, L 20,0 z"/>
</g>
```

The shape is referenced by a
[use](https://www.w3.org/TR/SVG2/struct.html#elementdef-use) element:

``` highlight
<use xlink:href="#shape"/>
```

The geometry of the shape is not influenced by the circular clipping
path.

By default,
[pointer-events](https://www.w3.org/TR/SVG2/interact.html#PointerEventsProperty) must not be dispatched on the
clipped-out (non-visible) regions of a shape. For example, an element
with a dimension of 10px to 10px which is clipped to a circle with a
radius of 5px will not receive [click] events outside the
[clipping region](#clipping-region).

### 5.1. Clipping Shape: the [clip-path property]
Name:

[clip-path]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<clip-source\>](#typedef-clip-source)
[\|](https://www.w3.org/TR/css-values-4/#comb-one) \[
[\<basic-shape\>](https://www.w3.org/TR/css-shapes-1/#typedef-basic-shape)
[\|\|](https://www.w3.org/TR/css-values-4/#comb-any)
[\<geometry-box\>](#typedef-geometry-box "Expands to: border-box | content-box | fill-box | margin-box | padding-box | stroke-box | svg viewport origin box | view-box") \] [\|] none

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

none

Applies to:

All elements. In SVG, it applies to [container
elements](https://www.w3.org/TR/SVG2/struct.html#container-element) excluding the
[defs](https://www.w3.org/TR/SVG2/struct.html#elementdef-defs) element, all [graphics
elements](https://www.w3.org/TR/SVG2/struct.html#graphics-element) and the
[use](https://www.w3.org/TR/SVG2/struct.html#elementdef-use) element

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

as specified, but with
[\<url\>](https://www.w3.org/TR/css-values-4/#url-value) values made absolute

Canonical order:

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value

Media:

visual

Specifies a basic shape or references a
[clipPath](#elementdef-clippath) element to create a [clipping
path](#clipping-path).

``` prod
<clip-source> = <url>
```

``` prod
<geometry-box> = <shape-box> | fill-box | stroke-box | view-box
```

[\<basic-shape\>](https://www.w3.org/TR/css-shapes-1/#typedef-basic-shape)

: A basic shape function as defined in the CSS Shapes module
 [\[CSS-SHAPES\]](#biblio-css-shapes). A basic
 shape makes use of the specified reference box to size and position
 the basic shape. If no reference box is specified, the
 [border-box](#valdef-mask-clip-border-box) will be used as reference box.

[\<geometry-box\>](#typedef-geometry-box "Expands to: border-box | content-box | fill-box | margin-box | padding-box | stroke-box | svg viewport origin box | view-box")

: If specified in combination with a
 [\<basic-shape\>](https://www.w3.org/TR/css-shapes-1/#typedef-basic-shape) it provides the reference box for
 the [\<basic-shape\>].

 If specified by itself, uses the edges of the specified box,
 including any corner shaping (e.g. defined by
 [border-radius](https://www.w3.org/TR/css-backgrounds-3/#propdef-border-radius)
 [\[CSS3BG\]](#biblio-css3bg)), as clipping path.
 See also ["Shapes from box
 values"](https://www.w3.org/TR/css-shapes/#shapes-from-box-values)
 [\[CSS-SHAPES\]](#biblio-css-shapes).

[fill-box]

: Uses the [object bounding
 box](https://www.w3.org/TR/SVG2/coords.html#TermObjectBoundingBox) as reference box.

[stroke-box]

: Uses the [stroke bounding
 box](#stroke-bounding-box) as reference box.

[view-box]

: Uses the nearest [SVG
 viewport](https://www.w3.org/TR/SVG11/intro.html#TermSVGViewport) as
 reference box.

 If a
 [viewBox](https://svgwg.org/svg2-draft/coords.html#ViewBoxAttribute) attribute is specified for the [SVG
 viewport](https://www.w3.org/TR/SVG11/intro.html#TermSVGViewport)
 creating element:

 - The reference box is positioned at the origin of the coordinate
 system established by the
 [viewBox](https://svgwg.org/svg2-draft/coords.html#ViewBoxAttribute) attribute.

 - The dimension of the reference box is set to the *width* and
 *height* values of the
 [viewBox](https://svgwg.org/svg2-draft/coords.html#ViewBoxAttribute) attribute.

none

: No [clipping path](#clipping-path) gets created.

For SVG elements without associated CSS layout box, the [used
value](https://www.w3.org/TR/css-cascade-5/#used-value) for
[content-box](#valdef-mask-clip-content-box) and
[padding-box](#valdef-mask-clip-padding-box) is
[fill-box](#valdef-clip-path-fill-box) and for
[border-box](#valdef-mask-clip-border-box) and
[margin-box](https://www.w3.org/TR/css-masking-1/#valuedef-margin-box0) is
[stroke-box](#valdef-clip-path-stroke-box).

For elements with associated CSS layout box, the [used
value](https://www.w3.org/TR/css-cascade-5/#used-value) for
[fill-box](#valdef-clip-path-fill-box) is
[content-box](#valdef-mask-clip-content-box) and for
[stroke-box](#valdef-clip-path-stroke-box) and
[view-box](#valdef-clip-path-view-box) is
[border-box](#valdef-mask-clip-border-box).

A computed value of other than [none] results in the creation of a
[stacking
context](https://www.w3.org/TR/SVG2/render.html#TermStackingContext) [\[CSS21\]](#biblio-css21) the same
way that CSS
[opacity](https://www.w3.org/TR/css-color-4/#propdef-opacity)
[\[CSS3COLOR\]](#biblio-css3color) does for values
other than [1].

If the URI reference is not valid (e.g it points to an object that
doesn't exist or the object is not a
[clipPath](#elementdef-clippath) element), no clipping is applied.

This example demonstrates the use of
the basic shape
[\<polygon()\>](https://www.w3.org/TR/css-shapes-1/#funcdef-polygon) as clipping path. Each space
separated length pair represents one point of the polygon. The
visualized clipping path can be seen in the [introduction](#clipping).

``` highlight
clip-path: polygon(15px 99px, 30px 87px, 65px 99px, 85px 55px,
 122px 57px, 184px 73px, 198px 105px, 199px 150px,
 145px 159px, 155px 139px, 126px 120px, 112px 138px,
 80px 128px, 39px 126px, 24px 104px);
```

In this example, the
[clip-path](#propdef-clip-path) property references an SVG
[clipPath](#elementdef-clippath) element. Each comma separated length pair
represents one point of the polygon. As for the previous example, the
visualized clipping path can be seen in the [introduction](#clipping).

``` highlight
clip-path: url("#clip1");
```

``` highlight
<clipPath id="clip1">
 <polygon points="15,99 30,87 65,99 85,55 122,57 184,73 198,105
 199,150 145,159 155,139 126,120 112,138 80,128 39,126 24,104"/>
</clipPath>
```

The [clip-path](#propdef-clip-path) property is a [presentation
attribute](https://www.w3.org/TR/2011/REC-SVG11-20110816/intro.html#TermPresentationAttribute)
for SVG elements.

## 6. SVG Clipping Path Sources

### 6.1. The [clipPath element]
Name:

[`clipPath`]

Categories:

[container
elements](https://www.w3.org/TR/SVG2/struct.html#container-element), [never-rendered
element](https://svgwg.org/svg2-draft/render.html#TermNeverRenderedElement)

Content model:

Any number of the following elements, in any order:

- [descriptive](https://www.w3.org/TR/2011/REC-SVG11-20110816/intro.html#TermDescriptiveElement)
 [ ---
 [desc](https://www.w3.org/TR/SVG2/struct.html#elementdef-desc),
 [title](https://www.w3.org/TR/SVG2/struct.html#elementdef-title),
 [metadata](https://www.w3.org/TR/SVG2/struct.html#elementdef-metadata)]
- [animation](https://www.w3.org/TR/2011/REC-SVG11-20110816/intro.html#TermAnimationElement)
 [ ---
 [animate](https://www.w3.org/TR/SVG11/animate.html#AnimateElement),
 [animateColor](https://www.w3.org/TR/SVG11/animate.html#AnimateColorElement),
 [animateMotion](https://www.w3.org/TR/SVG11/animate.html#AnimateMotionElement),
 [animateTransform](https://www.w3.org/TR/SVG11/animate.html#AnimateTransformElement),
 [set](https://www.w3.org/TR/SVG11/animate.html#SetElement)]
- [shape](https://www.w3.org/TR/2011/REC-SVG11-20110816/intro.html#TermShapeElement)
 [ ---
 [circle](https://www.w3.org/TR/SVG2/shapes.html#elementdef-circle),
 [ellipse](https://www.w3.org/TR/SVG2/shapes.html#elementdef-ellipse),
 [line](https://www.w3.org/TR/SVG2/shapes.html#elementdef-line),
 [path](https://www.w3.org/TR/SVG2/paths.html#elementdef-path),
 [polygon](https://www.w3.org/TR/SVG2/shapes.html#elementdef-polygon),
 [polyline](https://www.w3.org/TR/SVG2/shapes.html#elementdef-polyline),
 [rect](https://www.w3.org/TR/SVG2/shapes.html#elementdef-rect)]
- [text](https://www.w3.org/TR/SVG2/text.html#elementdef-text)
- [use](https://www.w3.org/TR/SVG2/struct.html#elementdef-use)
- [script](https://www.w3.org/TR/SVG2/interact.html#elementdef-script)

Attributes:

- [conditional processing
 attributes](https://www.w3.org/TR/2011/REC-SVG11-20110816/intro.html#TermConditionalProcessingAttribute)[
 ---
 [['requiredFeatures']](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#RequiredFeaturesAttribute),
 [['requiredExtensions']](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#RequiredExtensionsAttribute),
 [['systemLanguage']](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#SystemLanguageAttribute)]
- [core
 attributes](https://www.w3.org/TR/2011/REC-SVG11-20110816/intro.html#TermCoreAttributes)[
 ---
 [['id']](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#IDAttribute),
 [['xml:base']](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#XMLBaseAttribute),
 [['xml:lang']](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#XMLLangAttribute),
 [['xml:space']](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#XMLSpaceAttribute)]
- [presentation
 attributes](https://www.w3.org/TR/2011/REC-SVG11-20110816/intro.html#TermPresentationAttribute)[
 ---
 [alignment-baseline](https://www.w3.org/TR/css-inline-3/#propdef-alignment-baseline),
 [baseline-shift](https://www.w3.org/TR/css-inline-3/#propdef-baseline-shift),
 [clip](#propdef-clip),
 [clip-path](#propdef-clip-path),
 [clip-rule](#propdef-clip-rule),
 [color](https://www.w3.org/TR/css-color-4/#propdef-color),
 [color-interpolation](https://www.w3.org/TR/SVG2/painting.html#ColorInterpolationProperty),
 [color-interpolation-filters](https://www.w3.org/TR/filter-effects-1/#propdef-color-interpolation-filters),
 [color-profile](https://www.w3.org/TR/SVG11/color.html#ColorProfileProperty),
 [color-rendering](https://www.w3.org/TR/SVG2/painting.html#ColorRenderingProperty),
 [cursor](https://www.w3.org/TR/css-ui-3/#propdef-cursor),
 [direction](https://www.w3.org/TR/css-writing-modes-3/#propdef-direction),
 [display](https://www.w3.org/TR/css-display-3/#propdef-display),
 [dominant-baseline](https://www.w3.org/TR/css-inline-3/#propdef-dominant-baseline),
 [enable-background](https://www.w3.org/TR/SVG11/filters.html#EnableBackgroundProperty),
 [fill](https://www.w3.org/TR/SVG2/painting.html#FillProperty),
 [fill-opacity](https://www.w3.org/TR/SVG2/painting.html#FillOpacityProperty),
 [fill-rule](https://www.w3.org/TR/SVG2/painting.html#FillRuleProperty),
 [filter](https://www.w3.org/TR/filter-effects-1/#propdef-filter),
 [flood-color](https://www.w3.org/TR/filter-effects-1/#propdef-flood-color),
 [flood-opacity](https://www.w3.org/TR/filter-effects-1/#propdef-flood-opacity),
 [font](https://www.w3.org/TR/css-fonts-4/#propdef-font),
 [font-family](https://www.w3.org/TR/css-fonts-4/#propdef-font-family),
 [font-size](https://www.w3.org/TR/css-fonts-5/#descdef-font-face-font-size),
 [font-size-adjust](https://www.w3.org/TR/css-fonts-5/#propdef-font-size-adjust),
 [font-stretch](https://www.w3.org/TR/css-fonts-4/#propdef-font-stretch),
 [font-style](https://www.w3.org/TR/css-fonts-4/#propdef-font-style),
 [font-variant](https://www.w3.org/TR/css-fonts-4/#propdef-font-variant),
 [font-weight](https://www.w3.org/TR/css-fonts-4/#propdef-font-weight),
 [glyph-orientation-horizontal](https://www.w3.org/TR/SVG11/text.html#GlyphOrientationHorizontalProperty),
 [glyph-orientation-vertical](https://www.w3.org/TR/css-writing-modes-4/#propdef-glyph-orientation-vertical),
 [image-rendering](https://www.w3.org/TR/css-images-3/#propdef-image-rendering),
 [kerning](https://www.w3.org/TR/SVG11/text.html#KerningProperty),
 [letter-spacing](https://www.w3.org/TR/css-text-3/#propdef-letter-spacing),
 [lighting-color](https://www.w3.org/TR/filter-effects-1/#propdef-lighting-color),
 [marker](https://www.w3.org/TR/SVG2/painting.html#MarkerProperty),
 [marker-end](https://www.w3.org/TR/SVG2/painting.html#MarkerEndProperty),
 [marker-mid](https://www.w3.org/TR/SVG2/painting.html#MarkerMidProperty),
 [marker-start](https://www.w3.org/TR/SVG2/painting.html#MarkerStartProperty),
 [mask](#propdef-mask),
 [opacity](https://www.w3.org/TR/css-color-4/#propdef-opacity),
 [overflow](https://www.w3.org/TR/css-overflow-3/#propdef-overflow),
 [pointer-events](https://www.w3.org/TR/SVG2/interact.html#PointerEventsProperty),
 [shape-rendering](https://www.w3.org/TR/SVG2/painting.html#ShapeRenderingProperty),
 [stop-color](https://www.w3.org/TR/SVG2/pservers.html#StopColorProperty),
 [stop-opacity](https://www.w3.org/TR/SVG2/pservers.html#StopOpacityProperty),
 [stroke](https://www.w3.org/TR/SVG2/painting.html#StrokeProperty),
 [stroke-dasharray](https://www.w3.org/TR/SVG2/painting.html#StrokeDasharrayProperty),
 [stroke-dashoffset](https://www.w3.org/TR/SVG2/painting.html#StrokeDashoffsetProperty),
 [stroke-linecap](https://www.w3.org/TR/SVG2/painting.html#StrokeLinecapProperty),
 [stroke-linejoin](https://www.w3.org/TR/SVG2/painting.html#StrokeLinejoinProperty),
 [stroke-miterlimit](https://www.w3.org/TR/SVG2/painting.html#StrokeMiterlimitProperty),
 [stroke-opacity](https://www.w3.org/TR/SVG2/painting.html#StrokeOpacityProperty),
 [stroke-width](https://www.w3.org/TR/SVG2/painting.html#StrokeWidthProperty),
 [text-anchor](https://www.w3.org/TR/SVG2/text.html#TextAnchorProperty),
 [text-decoration](https://www.w3.org/TR/css-text-decor-3/#propdef-text-decoration),
 [text-rendering](https://www.w3.org/TR/SVG2/painting.html#TextRenderingProperty),
 [unicode-bidi](https://www.w3.org/TR/css-writing-modes-3/#propdef-unicode-bidi),
 [visibility](https://www.w3.org/TR/CSS2/visufx.html#propdef-visibility),
 [word-spacing](https://www.w3.org/TR/css-text-3/#propdef-word-spacing),
 [writing-mode](https://www.w3.org/TR/css-writing-modes-4/#propdef-writing-mode)]
- [['class']](https://www.w3.org/TR/2011/REC-SVG11-20110816/styling.html#ClassAttribute)
- [['style']](https://www.w3.org/TR/2011/REC-SVG11-20110816/styling.html#StyleAttribute)
- [['externalResourcesRequired']](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#ExternalResourcesRequiredAttribute)
- [['transform']](https://www.w3.org/TR/2011/REC-SVG11-20110816/coords.html#TransformAttribute)
- '[clipPathUnits](#element-attrdef-clippath-clippathunits)'

DOM Interfaces:

[SVGClipPathElement](#InterfaceSVGClipPathElement)

*Attribute definitions:*

[`clipPathUnits`] =
\"[userSpaceOnUse](#valdef-clippathunits-userspaceonuse) \|
[objectBoundingBox](#valdef-clippathunits-objectboundingbox)\"

Defines the coordinate system for the contents of the
[clipPath](#elementdef-clippath).

[userSpaceOnUse]

The contents of the
[clipPath](#elementdef-clippath) represent values in the current [user coordinate
system](https://www.w3.org/TR/css-transforms-1/#user-coordinate-system) in place at the time when the
[clipPath] element is referenced (i.e.,
the [user coordinate system] for the
element referencing the [clipPath]
element via the
[clip-path](#propdef-clip-path) property).

[objectBoundingBox]

The coordinate system has its origin at the top left corner of the
[bounding
box](https://www.w3.org/TR/SVG2/coords.html#bounding-box) of the element to which the clipping path applies to
and the same width and height of this [bounding
box]. [User
coordinates](https://www.w3.org/TR/SVG/coords.html#Units) are sized
equivalently to the CSS
[px](https://www.w3.org/TR/css-values-4/#px) unit.

If attribute
[clipPathUnits](#element-attrdef-clippath-clippathunits) is not specified, then the effect is as if a
value of
[userSpaceOnUse](#valdef-clippathunits-userspaceonuse) were specified.

Animatable: yes.

CSS properties inherit into the
[clipPath](#elementdef-clippath) element from its ancestors; properties do *not*
inherit from the element referencing the
[clipPath] element.

[clipPath](#elementdef-clippath) elements are never rendered directly; their only
usage is as something that can be referenced using the
[clip-path](#propdef-clip-path) property. The
[display](https://www.w3.org/TR/css-display-3/#propdef-display) property does not apply to the
[clipPath] element; thus,
[clipPath] elements are not directly
rendered even if the [display]
property is set to a value other than
[none](https://www.w3.org/TR/css-display-3/#valdef-display-none), and [clipPath]
elements are available for referencing even when the
[display] property on the
[clipPath] element or any of its
ancestors is set to [none].

A [clipPath](#elementdef-clippath) element can contain
[path](https://www.w3.org/TR/SVG2/paths.html#elementdef-path) elements,
[text](https://www.w3.org/TR/SVG2/text.html#elementdef-text) elements, [basic
shapes](https://www.w3.org/TR/SVG2/shapes.html#basic-shape) (such as
[circle](https://www.w3.org/TR/SVG2/shapes.html#elementdef-circle)) or a
[use](https://www.w3.org/TR/SVG2/struct.html#elementdef-use) element. If a [use]
element is a child of a [clipPath]
element, it must directly reference [path],
[text] or [basic
shapes] elements. Indirect references are an
error and the [clipPath] element must be
ignored.

Firefox disables rendering of elements
referencing clipPaths with violated content model. No browser ignores
clipPath on use with indirect reference.
[\<https://github.com/w3c/csswg-drafts/issues/17\>](https://github.com/w3c/csswg-drafts/issues/17)

The raw geometry of each child element exclusive of rendering properties
such as
[fill](https://www.w3.org/TR/SVG2/painting.html#FillProperty),
[stroke](https://www.w3.org/TR/SVG2/painting.html#StrokeProperty),
[stroke-width](https://www.w3.org/TR/SVG2/painting.html#StrokeWidthProperty) within a
[clipPath](#elementdef-clippath) conceptually defines a 1-bit mask (with the
possible exception of anti-aliasing along the edge of the geometry)
which represents the silhouette of the graphics associated with that
element. Anything outside the outline of the object is masked out. If a
child element is made invisible by
[display](https://www.w3.org/TR/css-display-3/#propdef-display) or
[visibility](https://www.w3.org/TR/CSS2/visufx.html#propdef-visibility) it does not contribute to the clipping
path. When the [clipPath] element
contains multiple child elements, the silhouettes of the child elements
are logically OR'd together to create a single silhouette which is then
used to restrict the region onto which paint can be applied. Thus, a
point is inside the clipping path if it is inside any of the children of
the [clipPath].

Define raw geometry with regards to CSS
properties that affect it. Especially on text.
[\<https://github.com/w3c/csswg-drafts/issues/170\>](https://github.com/w3c/csswg-drafts/issues/170)

For a given [graphics
element](https://www.w3.org/TR/SVG2/struct.html#graphics-element), the actual clipping path used will be the intersection
of the clipping path specified by its
[clip-path](#propdef-clip-path) property (if any) with any clipping paths on its
ancestors, as specified by the [clip-path] property on the elements which establish a new viewport. (See
[\[SVG11\]](#biblio-svg11))

A couple of additions:

- The [clipPath](#elementdef-clippath) element itself and its child elements do *not*
 inherit clipping paths from the ancestors of the
 [clipPath] element.

- The [clipPath](#elementdef-clippath) element or any of its children can specify
 property [clip-path](#propdef-clip-path).\
 If a valid [clip-path]
 reference is placed on a [clipPath]
 element, the resulting clipping path is the intersection of the
 contents of the [clipPath] element
 with the referenced clipping path.\
 If a valid [clip-path]
 reference is placed on one of the children of a
 [clipPath] element, then the given
 child element is clipped by the referenced clipping path before OR'ing
 the silhouette of the child element with the silhouettes of the other
 child elements.

- An empty clipping path will completely clip away the element that had
 the [clip-path](#propdef-clip-path) property applied.

### 6.2. Winding Rules: the [clip-rule property]
Name:

[clip-rule]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

nonzero
[\|](https://www.w3.org/TR/css-values-4/#comb-one) evenodd

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

nonzero

Applies to:

Applies to SVG [graphics
elements](https://www.w3.org/TR/SVG2/struct.html#graphics-element)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

yes

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

as specified

Canonical order:

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

Media:

visual

The [clip-rule](#propdef-clip-rule) property indicates the algorithm which
is to be used to determine whether a given point is inside a shape for a
[clipping region](#clipping-region) created with a [graphics
element](https://www.w3.org/TR/SVG2/struct.html#graphics-element). The definition of the algorithms and the
[clip-rule] values follows the
definition of the
[fill-rule](https://www.w3.org/TR/SVG2/painting.html#FillRuleProperty) property. See section ["Fill
Properties"](https://www.w3.org/TR/2011/REC-SVG11-20110816/painting.html#FillProperties)
in SVG 1.1 [\[SVG11\]](#biblio-svg11).

[nonzero]

: See description of
 [fill-rule](https://www.w3.org/TR/SVG2/painting.html#FillRuleProperty) property
 [\[SVG11\]](#biblio-svg11).

[evenodd]

: See description of
 [fill-rule](https://www.w3.org/TR/SVG2/painting.html#FillRuleProperty) property
 [\[SVG11\]](#biblio-svg11).

The [clip-rule](#propdef-clip-rule) property only applies to [graphics
elements](https://www.w3.org/TR/SVG2/struct.html#graphics-element) that are contained within a
[clipPath](#elementdef-clippath) element.

Note: The [clip-rule](#propdef-clip-rule) property does not apply to
[\<basic-shape\>](https://www.w3.org/TR/css-shapes-1/#typedef-basic-shape)s.

The following drawing illustrates the
[nonzero](#valdef-clip-rule-nonzero) rule:

![Shape with nonzero
rule.](images/cliprule-nonzero.svg){style="border: solid black 1px;"
width="450"}

Three shapes from left to right: Star with 5 points drawn in one
continuous, overlapping line; 2 clockwise drawn circles, one contains
the other and both are subpaths of the same shape; 2 circles, one
containing the other with the bigger one drawn in a clockwise direction
and the smaller one in a counter-clockwise direction and both belonging
to the same shape. Only the last shape has a \"hole\".

The following drawing illustrates the
[evenodd](#valdef-clip-rule-evenodd) rule:

![Shape with even-odd
rule.](images/cliprule-evenodd.svg){style="border: solid black 1px;"
width="450"}

Three shapes from left to right: Star with 5 points drawn in one
continuous, overlapping line; 2 clockwise drawn circles, one contains
the other and both are subpaths of the same shape; 2 circles, one
containing the other with the bigger one drawn in a clockwise direction
and the smaller one in a counter-clockwise direction and both belonging
to the same shape. All 3 shapes have a \"hole\".

The following fragment of code will
cause an even-odd clipping rule to be applied to the clipping path
because [clip-rule](#propdef-clip-rule) is specified on the
[path](https://www.w3.org/TR/SVG2/paths.html#elementdef-path) element that defines the clipping shape:

``` highlight
<g clip-rule="nonzero">
 <clipPath id="MyClip">
 <path d="..." clip-rule="evenodd" />
 </clipPath>
 <rect clip-path="url(#MyClip)" ... />
</g>
```

whereas the following fragment of code will *not* cause an evenodd
clipping rule to be applied because the
[clip-rule](#propdef-clip-rule) is specified on the referencing element, not on
the object defining the clipping shape:

``` highlight
<g clip-rule="nonzero">
 <clipPath id="MyClip">
 <path d="..." />
 </clipPath>
 <rect clip-path="url(#MyClip)" clip-rule="evenodd" ... />
</g>
```

The [clip-rule](#propdef-clip-rule) property is a [presentation
attribute](https://www.w3.org/TR/2011/REC-SVG11-20110816/intro.html#TermPresentationAttribute)
for SVG elements.

## 7. Positioned Masks

### 7.1. Mask Image Source: the [mask-image property]
Name:

[mask-image]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<mask-reference\>](#typedef-mask-reference)[\#](https://www.w3.org/TR/css-values-4/#mult-comma)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

none

Applies to:

All elements. In SVG, it applies to [container
elements](https://www.w3.org/TR/SVG2/struct.html#container-element) excluding the
[defs](https://www.w3.org/TR/SVG2/struct.html#elementdef-defs) element, all [graphics
elements](https://www.w3.org/TR/SVG2/struct.html#graphics-element) and the
[use](https://www.w3.org/TR/SVG2/struct.html#elementdef-use) element

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

the keyword [none], a computed
[\<image\>](https://www.w3.org/TR/css-images-3/#typedef-image), or a computed
[\<url\>](https://www.w3.org/TR/css-values-4/#url-value)

Canonical order:

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

Media:

visual

This property sets the [mask layer image] of an element. Where:

``` prod
<mask-reference> = none | <image> | <mask-source>
```

``` prod
<mask-source> = <url>
```

[\<url\>(#valdef-mask-image-url)]

: A URL reference to a
 [mask](#elementdef-mask) element (for example
 [url(commonmasks.svg#mask)]) or to a CSS image.

none

: A value of [none] counts as a transparent black image layer.

A computed value of other than [none] results in the creation of a
[stacking
context](https://www.w3.org/TR/SVG2/render.html#TermStackingContext) [\[CSS21\]](#biblio-css21) the same
way that CSS
[opacity](https://www.w3.org/TR/css-color-4/#propdef-opacity)
[\[CSS3COLOR\]](#biblio-css3color) does for values
other than [1].

A mask reference that is an empty image (zero width or zero height),
that fails to download, is not a reference to an
[mask](#elementdef-mask)
element, is non-existent, or that cannot be displayed (e.g. because it
is not in a supported image format) still counts as an image layer of
transparent black.

See the section ["Mask processing"](#MaskValues) for how to process a
[mask layer image](#mask-layer-image).

Note: A value of [none] in a list of
[\<mask-reference\>](#typedef-mask-reference)s may influence the masking operation
depending on the used compositing operator specified by
[mask-composite](#propdef-mask-composite).

Note: A
[\<mask-source\>](#typedef-mask-source) counts as mask layer and can be
combined in a repeatable
[\<mask-reference\>](#typedef-mask-reference) list with
[\<image\>](https://www.w3.org/TR/css-images-3/#typedef-image) or further
[\<mask-source\>] list items.

Note: An element can also be masked with
[mask-border-source](#propdef-mask-border-source). See
[mask-border-source] for
the interaction of that property with
[mask-image](#propdef-mask-image).

Examples for mask references:

``` highlight
body { mask-image: linear-gradient(black 0%, transparent 100%) }
p { mask-image: none }
div { mask-image: url(resources.svg#mask2) }
```

See the section ["Layering multiple mask layer images"](#layering) for
how [mask-image](#propdef-mask-image) interacts with other comma-separated
mask properties to form each mask layer.

### 7.2. Mask Image Interpretation: the [mask-mode property]
Name:

[mask-mode]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<masking-mode\>](#typedef-masking-mode)[\#](https://www.w3.org/TR/css-values-4/#mult-comma)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

match-source

Applies to:

All elements. In SVG, it applies to [container
elements](https://www.w3.org/TR/SVG2/struct.html#container-element) excluding the
[defs](https://www.w3.org/TR/SVG2/struct.html#elementdef-defs) element, all [graphics
elements](https://www.w3.org/TR/SVG2/struct.html#graphics-element) and the
[use](https://www.w3.org/TR/SVG2/struct.html#elementdef-use) element

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

as specified

Canonical order:

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

Media:

visual

The [mask-mode](#propdef-mask-mode) property indicates whether the
[\<mask-reference\>](#typedef-mask-reference) is treated as luminance mask or alpha
mask. (See [Mask processing](#MaskValues).)

``` prod
<masking-mode> = alpha | luminance | match-source
```

Values have the following meanings:

[alpha]

: A value of
 [alpha](#valdef-mask-mode-alpha) indicates that the alpha values of the [mask
 layer image](#mask-layer-image) should be used as the mask values. See [Calculating
 mask values](#MaskValues).

[luminance]

: A value of
 [luminance](#valdef-mask-mode-luminance) indicates that the luminance values of the
 [mask layer image](#mask-layer-image) should be used as the mask values. See [Calculating
 mask values](#MaskValues).

[match-source]

: If the
 [\<mask-reference\>](#typedef-mask-reference) of the
 [mask-image](#propdef-mask-image) property is of type
 [\<mask-source\>](#typedef-mask-source) the value specified by the
 referenced [mask](#elementdef-mask) element's
 [mask-type](#propdef-mask-type) property must be used.

 If the
 [\<mask-reference\>](#typedef-mask-reference) of the
 [mask-image](#propdef-mask-image) property is of type
 [\<image\>](https://www.w3.org/TR/css-images-3/#typedef-image) the alpha values of the [mask
 layer image](#mask-layer-image) should be used as the mask values.

In the following example, the
[mask-type](#propdef-mask-type) property sets the mask type value for the
[mask](#elementdef-mask)
element to
[alpha](#valdef-mask-type-alpha). The
[mask-image](#propdef-mask-image) property has a reference to this
[mask] element and the
[mask-mode](#propdef-mask-mode) property has a value of
[luminance](#valdef-mask-mode-luminance). The [mask-mode] property will override the definition of
[mask-type] to
[luminance](#valdef-mask-type-luminance).

The [mask-mode](#propdef-mask-mode) property must not affect the masking
mode of
[mask-border-source](#propdef-mask-border-source).

``` highlight
<mask id="SVGMask" mask-type="alpha" maskContentUnits="objectBoundingBox">
 <radialGradient id="radialFill">
 <stop stop-color="white" offset="0"/>
 <stop stop-color="black" offset="1"/>
 </radialGradient>
 <circle fill="url(#radialFill)" cx="0.5" cy="0.5" r="0.5"/>
</mask>

<style>
 rect {
 mask-image: url(#SVGMask);
 mask-mode: luminance;
 }
</style>

<rect width="200" height="200" fill="green"/>
```

See the section ["Layering multiple mask layer images"](#layering) for
how [mask-mode](#propdef-mask-mode) interacts with other comma-separated
mask properties to form each mask layer.

### 7.3. Tiling Mask Images: the [mask-repeat property]
Name:

[mask-repeat]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<repeat-style\>](https://www.w3.org/TR/css-backgrounds-3/#typedef-repeat-style)[\#](https://www.w3.org/TR/css-values-4/#mult-comma)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

repeat

Applies to:

All elements. In SVG, it applies to [container
elements](https://www.w3.org/TR/SVG2/struct.html#container-element) excluding the
[defs](https://www.w3.org/TR/SVG2/struct.html#elementdef-defs) element, all [graphics
elements](https://www.w3.org/TR/SVG2/struct.html#graphics-element) and the
[use](https://www.w3.org/TR/SVG2/struct.html#elementdef-use) element

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

Consists of: two keywords, one per dimension

Canonical order:

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

Media:

visual

Specifies how [mask layer
images](#mask-layer-image)
are tiled after they have been [sized](#the-mask-size) and
[positioned](#the-mask-position).

See
[background-repeat](https://www.w3.org/TR/css-backgrounds-3/#propdef-background-repeat) property
[\[CSS3BG\]](#biblio-css3bg) for the definitions of
the property values.

``` highlight
body {
 background-color: blue;
 mask-image: url(dot-mask.png) luminance;
 mask-repeat: space;
}
```

![Image of an element with a dotted
mask.](images/mask-repeat.svg){style="border: solid black 1px;"
width="240"}

The effect of [space]: the [mask layer
image](#mask-layer-image) of
a dot is tiled to cover the whole [mask painting
area](#mask-painting-area)
and the [mask layer image]s are equally
spaced.

See the section ["Layering multiple mask layer images"](#layering) for
how [mask-repeat](#propdef-mask-repeat) interacts with other comma-separated
mask properties to form each mask layer.

### 7.4. Positioning Mask Images: the [mask-position property]
Name:

[mask-position]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<position\>](https://www.w3.org/TR/css-values-4/#typedef-position)[\#](https://www.w3.org/TR/css-values-4/#mult-comma)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

0% 0%

Applies to:

All elements. In SVG, it applies to [container
elements](https://www.w3.org/TR/SVG2/struct.html#container-element) excluding the
[defs](https://www.w3.org/TR/SVG2/struct.html#elementdef-defs) element, all [graphics
elements](https://www.w3.org/TR/SVG2/struct.html#graphics-element) and the
[use](https://www.w3.org/TR/SVG2/struct.html#elementdef-use) element

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

refer to size of [mask painting
area](#mask-painting-area)
*minus* size of [mask layer
image](#mask-layer-image);
see text
[background-position](https://www.w3.org/TR/css-backgrounds-3/#propdef-background-position)
[\[CSS3BG\]](#biblio-css3bg)

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

Consisting of: two keywords representing the origin and two offsets from
that origin, each given as an absolute length (if given a
[\<length\>](https://www.w3.org/TR/css-values-4/#length-value "Expands to: advance measure | cap | ch | cm | dvb | dvh | dvi | dvmax | dvmin | dvw | em | ex | ic | in | lh | lvb | lvh | lvi | lvmax | lvmin | lvw | mm | pc | pt | px | q | rem | rlh | svb | svh | svi | svmax | svmin | svw | vb | vh | vi | vmax | vmin | vw")), otherwise as a percentage.

Canonical order:

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

repeatable list

Media:

visual

See the
[background-position](https://www.w3.org/TR/css-backgrounds-3/#propdef-background-position) property
[\[CSS3BG\]](#biblio-css3bg) for the definitions of
the property values.

In the example below, the (single)
image is placed in the lower-right corner of the viewport.

``` highlight
body {
 mask-image: url("logo.png");
 mask-position: 100% 100%;
 mask-repeat: no-repeat;
}
```

Mask positions can also be relative to
other corners than the top left. E.g., the following puts the background
image 10px from the bottom and 3em from the right:

``` highlight
mask-position: right 3em bottom 10px
```

See the section ["Layering multiple mask layer images"](#layering) for
how
[mask-position](#propdef-mask-position) interacts with other comma-separated
mask properties to form each mask layer.

### 7.5. Masking Area: the [mask-clip property]
Name:

[mask-clip]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

\[
[\<geometry-box\>](#typedef-geometry-box "Expands to: border-box | content-box | fill-box | margin-box | padding-box | stroke-box | svg viewport origin box | view-box")
[\|](https://www.w3.org/TR/css-values-4/#comb-one) no-clip
\][\#](https://www.w3.org/TR/css-values-4/#mult-comma)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

border-box

Applies to:

All elements. In SVG, it applies to [container
elements](https://www.w3.org/TR/SVG2/struct.html#container-element) excluding the
[defs](https://www.w3.org/TR/SVG2/struct.html#elementdef-defs) element, all [graphics
elements](https://www.w3.org/TR/SVG2/struct.html#graphics-element) and the
[use](https://www.w3.org/TR/SVG2/struct.html#elementdef-use) element

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

as specified

Canonical order:

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

Media:

visual

For [mask layer images](#mask-layer-image) that do not reference a
[mask](#elementdef-mask)
element, [mask-clip](#propdef-mask-clip) determines the [mask painting
area],
which determines the area that is affected by the mask. The painted
content of an element must be restricted to this area.

The [mask-clip](#propdef-mask-clip) property has no affect on a [mask layer
image](#mask-layer-image)
that references a [mask](#elementdef-mask) element. The
[x](#element-attrdef-mask-x),
[y](#element-attrdef-mask-y),
[width](#element-attrdef-mask-width),
[height](#element-attrdef-mask-height) and
[maskUnits](#element-attrdef-mask-maskunits) attributes on the
[mask] element determine the [mask painting
area](#mask-painting-area)
for mask references.

Values have the following meanings:

[content-box]

The painted content is restricted to (clipped to) the *content box*.

[padding-box]

The painted content is restricted to (clipped to) the *padding box*.

[border-box]

The painted content is restricted to (clipped to) the *border box*.

[fill-box]

The painted content is restricted to (clipped to) the [object bounding
box](https://www.w3.org/TR/SVG2/coords.html#TermObjectBoundingBox).

[stroke-box]

The painted content is restricted to (clipped to) the [stroke bounding
box](#stroke-bounding-box).

[view-box]

Uses the nearest [SVG
viewport](https://www.w3.org/TR/SVG11/intro.html#TermSVGViewport) as
reference box.

If a
[viewBox](https://svgwg.org/svg2-draft/coords.html#ViewBoxAttribute) attribute is specified for the [SVG
viewport](https://www.w3.org/TR/SVG11/intro.html#TermSVGViewport)
creating element:

- The reference box is positioned at the origin of the coordinate system
 established by the
 [viewBox](https://svgwg.org/svg2-draft/coords.html#ViewBoxAttribute) attribute.

- The dimension of the reference box is set to the *width* and *height*
 values of the
 [viewBox](https://svgwg.org/svg2-draft/coords.html#ViewBoxAttribute) attribute.

[no-clip]

The painted content is not restricted (not clipped).

For SVG elements without associated CSS layout box, the [used
value](https://www.w3.org/TR/css-cascade-5/#used-value)s for
[content-box](#valdef-mask-clip-content-box) and
[padding-box](#valdef-mask-clip-padding-box) compute to
[fill-box](#valdef-mask-clip-fill-box) and for
[border-box](#valdef-mask-clip-border-box) and
[margin-box](https://www.w3.org/TR/css-masking-1/#valuedef-margin-box0) compute to
[stroke-box](#valdef-mask-clip-stroke-box).

For elements with associated CSS layout box, the [used
value](https://www.w3.org/TR/css-cascade-5/#used-value)s for
[fill-box](#valdef-mask-clip-fill-box) compute to
[content-box](#valdef-mask-clip-content-box) and for
[stroke-box](#valdef-mask-clip-stroke-box) and
[view-box](#valdef-mask-clip-view-box) compute to
[border-box](#valdef-mask-clip-border-box).

See the section ["Layering multiple mask layer images"](#layering) for
how [mask-clip](#propdef-mask-clip) interacts with other comma-separated
mask properties to form each mask layer.

### 7.6. Positioning Area: the [mask-origin property]
Name:

[mask-origin]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<geometry-box\>](#typedef-geometry-box "Expands to: border-box | content-box | fill-box | margin-box | padding-box | stroke-box | svg viewport origin box | view-box")[\#](https://www.w3.org/TR/css-values-4/#mult-comma)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

border-box

Applies to:

All elements. In SVG, it applies to [container
elements](https://www.w3.org/TR/SVG2/struct.html#container-element) excluding the
[defs](https://www.w3.org/TR/SVG2/struct.html#elementdef-defs) element, all [graphics
elements](https://www.w3.org/TR/SVG2/struct.html#graphics-element) and the
[use](https://www.w3.org/TR/SVG2/struct.html#elementdef-use) element

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

as specified

Canonical order:

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

Media:

visual

For elements rendered as a single box, specifies the [mask positioning
area]. For elements rendered as multiple boxes (e.g., inline boxes
on several lines, boxes on several pages) specifies which boxes
[box-decoration-break](https://www.w3.org/TR/css-break-4/#propdef-box-decoration-break) operates on to determine the mask
positioning area.

[content-box]

: The position is relative to the *content box*.

[padding-box]

: The position is relative to the *padding box*. (For single boxes [0
 0] is the upper left corner of the padding edge, [100%
 100%] is the lower right corner.)

[border-box]

: The position is relative to the *border box*.

[fill-box]

: The position is relative to the [object bounding
 box](https://www.w3.org/TR/SVG2/coords.html#TermObjectBoundingBox).

[stroke-box]

: The position is relative to the [stroke bounding
 box](#stroke-bounding-box).

[view-box]

: Uses the nearest [SVG
 viewport](https://www.w3.org/TR/SVG11/intro.html#TermSVGViewport) as
 reference box.

 If a
 [viewBox](https://svgwg.org/svg2-draft/coords.html#ViewBoxAttribute) attribute is specified for the [SVG
 viewport](https://www.w3.org/TR/SVG11/intro.html#TermSVGViewport)
 creating element:

 - The reference box is positioned at the origin of the coordinate
 system established by the
 [viewBox](https://svgwg.org/svg2-draft/coords.html#ViewBoxAttribute) attribute.

 - The dimension of the reference box is set to the *width* and
 *height* values of the
 [viewBox](https://svgwg.org/svg2-draft/coords.html#ViewBoxAttribute) attribute.

For SVG elements without associated CSS layout box, the values
[content-box](#valdef-mask-origin-content-box),
[padding-box](#valdef-mask-origin-padding-box) and
[border-box](#valdef-mask-origin-border-box) compute to
[fill-box](#valdef-mask-origin-fill-box).

For elements with associated CSS layout box, the values
[fill-box](#valdef-mask-origin-fill-box),
[stroke-box](#valdef-mask-origin-stroke-box) and
[view-box](#valdef-mask-origin-view-box) compute to the initial value of
[mask-origin](#propdef-mask-origin).

Note: The
[mask-origin](#propdef-mask-origin) property is similar to the
[background-origin](https://www.w3.org/TR/css-backgrounds-3/#propdef-background-origin) property
[\[CSS3BG\]](#biblio-css3bg), but it has a different
set of values, and a different initial value.

Note: If [mask-clip](#propdef-mask-clip) is
[padding-box](#valdef-mask-origin-padding-box),
[mask-origin](#propdef-mask-origin) is
[border-box](#valdef-mask-origin-border-box),
[mask-position](#propdef-mask-position) is [top left] (the initial value),
and the element has a non-zero border, then the top and left of the
[mask layer image](#mask-layer-image) will be clipped.

See the section ["Layering multiple mask layer images"](#layering) for
how [mask-origin](#propdef-mask-origin) interacts with other comma-separated
mask properties to form each mask layer.

### 7.7. Sizing Mask Images: the [mask-size property]
Name:

[mask-size]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<bg-size\>](https://www.w3.org/TR/css-backgrounds-3/#typedef-bg-size)[\#](https://www.w3.org/TR/css-values-4/#mult-comma)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

auto

Applies to:

All elements. In SVG, it applies to [container
elements](https://www.w3.org/TR/SVG2/struct.html#container-element) excluding the
[defs](https://www.w3.org/TR/SVG2/struct.html#elementdef-defs) element, all [graphics
elements](https://www.w3.org/TR/SVG2/struct.html#graphics-element) and the
[use](https://www.w3.org/TR/SVG2/struct.html#elementdef-use) element

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

as specified, but with lengths made absolute

Canonical order:

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

repeatable list

Media:

visual

Specifies the size of the [mask layer
images](#mask-layer-image).

See
[background-size](https://www.w3.org/TR/css-backgrounds-3/#propdef-background-size) property
[\[CSS3BG\]](#biblio-css3bg) for the definitions of
the property values.

See the section ["Layering multiple mask layer images"](#layering) for
how [mask-size](#propdef-mask-size) interacts with other comma-separated
mask properties to form each mask layer.

### 7.8. Compositing mask layers: the [mask-composite property]
Name:

[mask-composite]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<compositing-operator\>](#typedef-compositing-operator)[\#](https://www.w3.org/TR/css-values-4/#mult-comma)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

add

Applies to:

All elements. In SVG, it applies to [container
elements](https://www.w3.org/TR/SVG2/struct.html#container-element) without the
[defs](https://www.w3.org/TR/SVG2/struct.html#elementdef-defs) element and all [graphics
elements](https://www.w3.org/TR/SVG2/struct.html#graphics-element)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

as specified

Canonical order:

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

Media:

visual

``` prod
<compositing-operator> = add | subtract | intersect | exclude
```

Each keyword represents a Porter-Duff compositing operator
[\[COMPOSITING-1\]](#biblio-compositing-1) which
defines the compositing operation used on the current mask layer with
the mask layers below it.

In the following, the current mask layer is referred to [source], all mask layers below it
(with the corresponding compositing operators applied) are referred to
[destination].

[add]

: The [source](#source) is placed
 over the [destination](#destination). (See Porter-Duff compositing operator [source
 over](https://www.w3.org/TR/compositing-1/#porterduffcompositingoperators_srcover)
 for more details.)

[subtract]

: The [source](#source) is placed,
 where it falls outside of the
 [destination](#destination).
 (See Porter-Duff compositing operator [source
 out](https://www.w3.org/TR/compositing-1/#porterduffcompositingoperators_srcout)
 for more details.)

[intersect]

: The parts of [source](#source)
 that overlap the [destination](#destination), replace the [destination].
 (See Porter-Duff compositing operator [source
 in](https://www.w3.org/TR/compositing-1/#porterduffcompositingoperators_srcin)
 .)

[exclude]

: The non-overlapping regions of [source](#source) and
 [destination](#destination)
 are combined. (See Porter-Duff compositing operator
 [XOR](https://www.w3.org/TR/compositing-1/#porterduffcompositingoperators_xor).)

If there is no further mask layer, the compositing operator must be
ignored. Mask layers must not composite with the element's content or
the content behind the element, instead they must act as if they are
rendered into an isolated group.

All mask layers below the current mask layer must be composited before
applying the compositing operation for the current mask layer.

This example uses two [mask layer
images](#mask-layer-image):
`circle.svg` and `rect.svg`.

![Example of source-over compositing of mask
layers](images/mask-source-destination.svg){height="240" width="440"}

Both [mask layer images](#mask-layer-image) are references with the
[mask-image](#propdef-mask-image) property:

``` highlight
mask-image: circle.svg, rect.svg;
```

The mask layer with `rect.svg` is below the mask layer with
`circle.svg`. That means `circle.svg` is closer to
the user than `rect.svg`.

With the property
[mask-composite](#propdef-mask-composite) the author may choose different ways to
combine multiple mask layers.

- [add](#valdef-mask-composite-add) paints the `circle.svg` on top of
 `rect.svg`. The behavior is described by the compositing
 operator [source
 over](https://www.w3.org/TR/compositing-1/#porterduffcompositingoperators_srcover).

 ``` highlight
 mask-composite: add;
 ```

 ::: figure
 ![Example of source-over compositing of mask
 layers](images/mask-composite-add.svg){height="220" width="220"}
 :::

- [subtract](#valdef-mask-composite-subtract) paints portions of `circle.svg`
 that do not overlap `rect.svg`. The behavior is described
 by the compositing operator [source
 out](https://www.w3.org/TR/compositing-1/#porterduffcompositingoperators_srcout).

 ``` highlight
 mask-composite: subtract;
 ```

 ::: figure
 ![Example of source-over compositing of mask
 layers](images/mask-composite-subtract.svg){height="220" width="220"}
 :::

- [intersect](#valdef-mask-composite-intersect) paints portions of `circle.svg`
 that overlap `rect.svg`. The behavior is described by the
 compositing operator [source
 in](https://www.w3.org/TR/compositing-1/#porterduffcompositingoperators_srcin).

 ``` highlight
 mask-composite: intersect;
 ```

 ::: figure
 ![Example of source-over compositing of mask
 layers](images/mask-composite-intersect.svg){height="220" width="220"}
 :::

- [exclude](#valdef-mask-composite-exclude) paints portions of `circle.svg` and
 `rect.svg` that do not overlap. The behavior is described
 by the compositing operator
 [XOR](https://www.w3.org/TR/compositing-1/#porterduffcompositingoperators_xor).

 ``` highlight
 mask-composite: exclude;
 ```

 ::: figure
 ![Example of source-over compositing of mask
 layers](images/mask-composite-exclude.svg){height="220" width="220"}
 :::

The following example specifies two
mask layers and two compositing operators.

``` highlight
mask-image: rect.svg, circle.svg;
mask-composite: add, exclude;
```

`rect.svg` and `circle.svg` make use of the
[add](#valdef-mask-composite-add) compositing operator. There is no further mask
layer to use
[exclude](#valdef-mask-composite-exclude) and therefore,
[exclude] is ignored.

This is an example of 3 mask layers
with different compositing operators.

``` highlight
mask-image: trapeze.svg, circle.svg, rect.svg;
mask-composite: subtract, add;
```

First, `circle.svg` is "added" to `rect.svg`. In a
second step, only portions of `trapeze.svg` that are not
overlapping the compositing result of the previous two layers is
visible.

![Example of source-over compositing of mask
layers](images/mask-composite-subtract-add.svg){height="240"
width="440"}

See the section ["Layering multiple mask layer images"](#layering) for
how
[mask-composite](#propdef-mask-composite) interacts with other comma-separated
mask properties to form each mask layer.

### 7.9. Mask Shorthand: the [mask property]
Name:

[mask]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<mask-layer\>](#typedef-mask-layer)[\#](https://www.w3.org/TR/css-values-4/#mult-comma)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

see individual properties

Applies to:

All elements. In SVG, it applies to [container
elements](https://www.w3.org/TR/SVG2/struct.html#container-element) excluding the
[defs](https://www.w3.org/TR/SVG2/struct.html#elementdef-defs) element, all [graphics
elements](https://www.w3.org/TR/SVG2/struct.html#graphics-element) and the
[use](https://www.w3.org/TR/SVG2/struct.html#elementdef-use) element

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

see individual properties

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

see individual properties

Canonical order:

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

see individual properties

Media:

visual

``` prod
<mask-layer> = <mask-reference> || <position> [ / <bg-size> ]? ||<repeat-style> || <geometry-box> || [ <geometry-box> | no-clip ] || <compositing-operator> || <masking-mode>
```

If one
[\<geometry-box\>](#typedef-geometry-box "Expands to: border-box | content-box | fill-box | margin-box | padding-box | stroke-box | svg viewport origin box | view-box") value and the
[no-clip](#valdef-mask-clip-no-clip) keyword are present then
[\<geometry-box\>]
sets [mask-origin](#propdef-mask-origin) and
[no-clip] sets
[mask-clip](#propdef-mask-clip) to that value.

If one
[\<geometry-box\>](#typedef-geometry-box "Expands to: border-box | content-box | fill-box | margin-box | padding-box | stroke-box | svg viewport origin box | view-box") value and no
[no-clip](#valdef-mask-clip-no-clip) keyword are present then
[\<geometry-box\>]
sets both
[mask-origin](#propdef-mask-origin) and
[mask-clip](#propdef-mask-clip) to that value.

If two
[\<geometry-box\>](#typedef-geometry-box "Expands to: border-box | content-box | fill-box | margin-box | padding-box | stroke-box | svg viewport origin box | view-box") values are present, then the first
sets [mask-origin](#propdef-mask-origin) and the second
[mask-clip](#propdef-mask-clip).

The [used
value](https://www.w3.org/TR/css-cascade-5/#used-value) of the properties
[mask-repeat](#propdef-mask-repeat),
[mask-position](#propdef-mask-position),
[mask-clip](#propdef-mask-clip),
[mask-origin](#propdef-mask-origin) and
[mask-size](#propdef-mask-size) must have no effect if
[\<mask-reference\>](#typedef-mask-reference) references a
[mask](#elementdef-mask)
element. In this case the element defines position, sizing and clipping
of the [mask layer image](#mask-layer-image).

The [mask](#propdef-mask) shorthand also resets
[mask-border](#propdef-mask-border) to its initial value. It is therefore
recommended that authors use the [mask] shorthand, rather than other shorthands or the individual
properties, to override any mask settings earlier in the cascade. This
will ensure that [mask-border]
has also been reset to allow the new styles to take effect.

### 7.10. The Mask Image Rendering Model

The application of the
[mask-image](#propdef-mask-image) property with a value other than
[none] to an element formatted with the CSS box model establishes
a [stacking
context](https://www.w3.org/TR/SVG2/render.html#TermStackingContext) in the same way that CSS
[opacity](https://www.w3.org/TR/css-color-4/#propdef-opacity)
[\[CSS3COLOR\]](#biblio-css3color) does, and all the
element's descendants are rendered together as a group with the masking
applied to the group as a whole.

The [mask-image](#propdef-mask-image) property has no effect on the geometry
or hit-testing of any element's CSS boxes.

The [mask](#propdef-mask) property is a [presentation
attribute](https://www.w3.org/TR/2011/REC-SVG11-20110816/intro.html#TermPresentationAttribute)
for SVG elements.

#### 7.10.1. Mask processing

In the following section, [mask image] refers either to a [mask layer
image](#mask-layer-image)
or to a [mask border
image](#mask-border-image).

A mask image may be interpreted using one of two different methods with
regards to calculating the mask values that will be multiplied with the
target alpha values.

The first and simplest method of calculating the mask values is to use
the alpha channel of the [mask image](#mask-image). In this case the mask value at a given point is simply
the value of the alpha channel at that point. The color channels do not
contribute to the mask value.

The second method of calculating the mask values is to use the luminance
of the mask image. In this case the mask value at a given point is
computed from the color channel values and alpha channel value using the
following procedure.

1. Compute a luminance value from the color channel values.

 - If the computed value of
 [color-interpolation](https://www.w3.org/TR/SVG2/painting.html#ColorInterpolationProperty) on the
 [mask](#elementdef-mask) element is
 [linearRGB](https://www.w3.org/TR/filter-effects-1/#valdef-color-interpolation-filters-linearrgb), convert the original image color values
 (potentially in the sRGB color space) to the linearRGB color
 space.

 - Then, using non-premultiplied RGB color values, apply the
 luminance-to-alpha coefficients (as defined in the
 [feColorMatrix](https://www.w3.org/TR/filter-effects-1/#elementdef-fecolormatrix) filter primitive
 [\[SVG11\]](#biblio-svg11)) to convert the RGB
 color values to luminance values.

2. Multiply the computed luminance value by the corresponding alpha
 value to produce the mask value.

Regardless of the method used, the procedure for calculating mask values
assumes the content of the mask is a four-channel RGBA graphics object.
For other types of graphics objects, special handling is required as
follows.

For a three-channel RGB graphics object that is used in a mask (e.g.,
when referencing a three-channel image file), the effect is as if the
object were converted into a four-channel RGBA image with the alpha
channel uniformly set to 1.

For a single-channel image that is used in a mask (e.g., when
referencing a single-channel grayscale image file), the effect is as if
the object were converted into a four-channel RGBA image, where the
single channel from the referenced object is used to compute the three
color channels and the alpha channel is uniformly set to 1.

Note: When referencing a grayscale image file, the transfer curve
relating the encoded grayscale values to linear light values must be
taken into account when computing the color channels.

Note: SVG [graphics
elements](https://www.w3.org/TR/SVG2/struct.html#graphics-element) (e.g.,
[circle](https://www.w3.org/TR/SVG2/shapes.html#elementdef-circle) or
[text](https://www.w3.org/TR/SVG2/text.html#elementdef-text)) are all treated as four-channel RGBA images for
the purposes of masking operations.

The effect of a mask is identical to what would have happened if there
were no mask but instead the alpha channel of the given object were
multiplied with the mask's resulting mask values.

Regions not covered by a [mask image](#mask-image) are treated as transparent black. The mask value is 0.

Note: Masks with repeating [mask
image](#mask-image) tiles may have
an offset to each other. The space between the [mask
images] is treated as a transparent black mask.

#### 7.10.2. Layering Multiple Mask Images

The mask of a box can have multiple layers. The number of layers is
determined by the number of comma-separated values for the
[mask-image](#propdef-mask-image) property. A value of [none] in a
list of values with other
[\<mask-reference\>](#typedef-mask-reference)s still creates a layer.

See [Layering Multiple Background
Images](https://www.w3.org/TR/css3-background/#layering)
[\[CSS3BG\]](#biblio-css3bg).

[mask-mode](#propdef-mask-mode) and
[mask-composite](#propdef-mask-composite) do not have counterparts in CSS
Backgrounds and Borders
[\[CSS3BG\]](#biblio-css3bg). Just like for the mask
properties that do have a counterpart, the list of values are matched up
from the first value: excess values at the end are not used. If a
property doesn't have enough comma-separated values to match the number
of layers, the UA must calculate its used value by repeating the list of
values until there are enough.

All [mask layer images](#mask-layer-image) are transformed to alpha masks (if necessary see [Mask
processing](#MaskValues)) and combined by compositing taking the
compositing operators specified by
[mask-composite](#propdef-mask-composite) into account.

## 8. Border-Box Mask

With [mask-border](#propdef-mask-border) an image can be split into nine pieces:
four corners, four edges and the middle piece as demonstrated in the
figure below.

![pieces of a mask border
image](images/mask-box-image-mask.svg){width="240"}

Pieces of a [mask border
image](#mask-border-image).

These pieces may be sliced, scaled and stretched in various ways to fit
the size of the [mask border image
area](#mask-border-image-area). This distorted image is then used as a mask. The
syntax of
[mask-border](#propdef-mask-border) corresponds to the
[border-image](https://www.w3.org/TR/css-backgrounds-3/#propdef-border-image) property of CSS Background and Borders
[\[CSS3BG\]](#biblio-css3bg).

The [mask border
image](#mask-border-image)
in the following example is split into four corners with dimensions of
75 pixels, four edges and the middle piece that is stretched and scaled.

![Example for \'mask-border\'](images/mask-box-image.svg){height="240"
width="720"}

Example for
[mask-border](#propdef-mask-border). The object on the left is the object to
mask. The second image is the alpha mask and the last image the masked
object.

``` highlight
div {
 background: linear-gradient(bottom, #F27BAA 0%, #FCC8AD 100%);
 mask-border-slice: 25 fill;
 mask-border-repeat: stretch;
 mask-border-source: url(mask.png);
}
```

### 8.1. Mask Border Image Source: the [mask-border-source property]
Name:

[mask-border-source]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

none
[\|](https://www.w3.org/TR/css-values-4/#comb-one)
[\<image\>](https://www.w3.org/TR/css-images-3/#typedef-image)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

none

Applies to:

All elements. In SVG, it applies to [container
elements](https://www.w3.org/TR/SVG2/struct.html#container-element) excluding the
[defs](https://www.w3.org/TR/SVG2/struct.html#elementdef-defs) element, all [graphics
elements](https://www.w3.org/TR/SVG2/struct.html#graphics-element) and the
[use](https://www.w3.org/TR/SVG2/struct.html#elementdef-use) element

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

they keyword [none] or the computed
[\<image\>](https://www.w3.org/TR/css-images-3/#typedef-image)

Canonical order:

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

Media:

visual

Specifies an image to be used as [mask border image].

An image that is an empty image (zero width or zero height), that fails
to download, is non-existent, or that cannot be displayed (e.g. because
it is not in a supported image format) is ignored. It still counts as an
[mask border image](#mask-border-image) but does not mask the element.

See "[Mask processing](#MaskValues)" on how to process the [mask border
image](#mask-border-image).

A computed value of other than [none] results in the creation of a
[stacking
context](https://www.w3.org/TR/SVG2/render.html#TermStackingContext) [\[CSS21\]](#biblio-css21) the same
way that CSS
[opacity](https://www.w3.org/TR/css-color-4/#propdef-opacity)
[\[CSS3COLOR\]](#biblio-css3color) does for values
other than [1].

[mask-border-source](#propdef-mask-border-source) and
[mask-image](#propdef-mask-image) can be specified independent of each
other. If both properties have a value other than [none], the
element is masked by both masking operations one after the other.

Note: It does not matter if
[mask-image](#propdef-mask-image) is applied to the element before or
after
[mask-border-source](#propdef-mask-border-source). Both operation orders result in the
same rendering.

### 8.2. Mask Border Image Interpretation: the [mask-border-mode property]
Name:

[mask-border-mode]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

luminance
[\|](https://www.w3.org/TR/css-values-4/#comb-one) alpha

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

alpha

Applies to:

All elements. In SVG, it applies to [container
elements](https://www.w3.org/TR/SVG2/struct.html#container-element) excluding the
[defs](https://www.w3.org/TR/SVG2/struct.html#elementdef-defs) element, all [graphics
elements](https://www.w3.org/TR/SVG2/struct.html#graphics-element) and the
[use](https://www.w3.org/TR/SVG2/struct.html#elementdef-use) element

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

as specified

Canonical order:

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

Media:

visual

The
[mask-border-mode](#propdef-mask-border-mode) property indicates whether the
[\<image\>](https://www.w3.org/TR/css-images-3/#typedef-image) value for
[mask-border-source](#propdef-mask-border-source) is treated as luminance mask or alpha
mask. (See [Mask processing](#MaskValues).)

Values have the following meanings:

[alpha]

: A value of
 [alpha](#valdef-mask-border-mode-alpha) indicates that the alpha values of the [mask
 border image](#mask-border-image) should be used as the mask values. See [Calculating
 mask values](#MaskValues).

[luminance]

: A value of
 [luminance](#valdef-mask-border-mode-luminance) indicates that the luminance values of the
 [mask border image](#mask-border-image) should be used as the mask values. See [Calculating
 mask values](#MaskValues).

The [mask-mode](#propdef-mask-mode) and
[mask-type](#propdef-mask-type) properties must have no affect on the [mask border
image](#mask-border-image)
type.

### 8.3. Mask Border Image Slicing: the [mask-border-slice property]
Name:

[mask-border-slice]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<number-percentage\>](https://www.w3.org/TR/css-values-3/#typedef-number-percentage)[{1,4}](https://www.w3.org/TR/css-values-4/#mult-num-range)
fill[?](https://www.w3.org/TR/css-values-4/#mult-opt)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

0

Applies to:

All elements. In SVG, it applies to [container
elements](https://www.w3.org/TR/SVG2/struct.html#container-element) excluding the
[defs](https://www.w3.org/TR/SVG2/struct.html#elementdef-defs) element, all [graphics
elements](https://www.w3.org/TR/SVG2/struct.html#graphics-element) and the
[use](https://www.w3.org/TR/SVG2/struct.html#elementdef-use) element

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

refer to size of the [mask border
image](#mask-border-image)

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

as specified

Canonical order:

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

Media:

visual

This property specifies inward offsets from the top, right, bottom, and
left edges of the [mask border
image](#mask-border-image), dividing it into nine regions: four corners, four
edges and a middle. The middle image part is discarded and treated as
fully opaque white (the content covered by the middle part is not masked
and shines through) unless the [fill] keyword is present.

See the
[border-image-slice](https://www.w3.org/TR/css-backgrounds-3/#propdef-border-image-slice) property
[\[CSS3BG\]](#biblio-css3bg) for the definitions of
the property values.

### 8.4. Masking Areas: the [mask-border-width property]
Name:

[mask-border-width]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

\[
[\<length-percentage\>](https://www.w3.org/TR/css-values-4/#typedef-length-percentage)
[\|](https://www.w3.org/TR/css-values-4/#comb-one)
[\<number\>](https://www.w3.org/TR/css-values-4/#number-value) [\|] auto
\][{1,4}](https://www.w3.org/TR/css-values-4/#mult-num-range)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

auto

Applies to:

All elements. In SVG, it applies to [container
elements](https://www.w3.org/TR/SVG2/struct.html#container-element) excluding the
[defs](https://www.w3.org/TR/SVG2/struct.html#elementdef-defs) element, all [graphics
elements](https://www.w3.org/TR/SVG2/struct.html#graphics-element) and the
[use](https://www.w3.org/TR/SVG2/struct.html#elementdef-use) element

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

relative to width/height of the [mask border image
area](#mask-border-image-area)

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

all
[\<length\>](https://www.w3.org/TR/css-values-4/#length-value "Expands to: advance measure | cap | ch | cm | dvb | dvh | dvi | dvmax | dvmin | dvw | em | ex | ic | in | lh | lvb | lvh | lvi | lvmax | lvmin | lvw | mm | pc | pt | px | q | rem | rlh | svb | svh | svi | svmax | svmin | svw | vb | vh | vi | vmax | vmin | vw")s made absolute, otherwise as
specified

Canonical order:

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

Media:

visual

The [mask border image](#mask-border-image) is drawn inside an area called the [mask border image
area]. This is an area whose boundaries by default correspond to
the border box, see
[mask-border-outset](#propdef-mask-border-outset).

See the
[border-image-width](https://www.w3.org/TR/css-backgrounds-3/#propdef-border-image-width) property
[\[CSS3BG\]](#biblio-css3bg) for the definitions of
the property values.

Note: For SVG elements without an associated layout box the
[border-width](https://www.w3.org/TR/css-backgrounds-3/#propdef-border-width) is considered to be [0].

### 8.5. Edge Overhang: the [mask-border-outset property]
Name:

[mask-border-outset]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

\[
[\<length\>](https://www.w3.org/TR/css-values-4/#length-value "Expands to: advance measure | cap | ch | cm | dvb | dvh | dvi | dvmax | dvmin | dvw | em | ex | ic | in | lh | lvb | lvh | lvi | lvmax | lvmin | lvw | mm | pc | pt | px | q | rem | rlh | svb | svh | svi | svmax | svmin | svw | vb | vh | vi | vmax | vmin | vw")
[\|](https://www.w3.org/TR/css-values-4/#comb-one)
[\<number\>](https://www.w3.org/TR/css-values-4/#number-value)
\][{1,4}](https://www.w3.org/TR/css-values-4/#mult-num-range)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

0

Applies to:

All elements. In SVG, it applies to [container
elements](https://www.w3.org/TR/SVG2/struct.html#container-element) excluding the
[defs](https://www.w3.org/TR/SVG2/struct.html#elementdef-defs) element, all [graphics
elements](https://www.w3.org/TR/SVG2/struct.html#graphics-element) and the
[use](https://www.w3.org/TR/SVG2/struct.html#elementdef-use) element

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

all
[\<length\>](https://www.w3.org/TR/css-values-4/#length-value "Expands to: advance measure | cap | ch | cm | dvb | dvh | dvi | dvmax | dvmin | dvw | em | ex | ic | in | lh | lvb | lvh | lvi | lvmax | lvmin | lvw | mm | pc | pt | px | q | rem | rlh | svb | svh | svi | svmax | svmin | svw | vb | vh | vi | vmax | vmin | vw")s made absolute, otherwise as
specified

Canonical order:

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

Media:

visual

The values specify the amount by which the [mask border image
area](#mask-border-image-area) extends beyond the border box. If it has four values,
they set the outsets on the top, right, bottom and left sides in that
order. If the left is missing, it is the same as the right; if the
bottom is missing, it is the same as the top; if the right is missing,
it is the same as the top.

As with
[mask-border-width](#propdef-mask-border-width), a
[\<number\>](https://www.w3.org/TR/css-values-4/#number-value) represents a multiple of the
corresponding
[border-width](https://www.w3.org/TR/css-backgrounds-3/#propdef-border-width). Negative values are not allowed for any
of the
[mask-border-outset](#propdef-mask-border-outset) values.

Note: For SVG elements without associated layout box the
[border-width](https://www.w3.org/TR/css-backgrounds-3/#propdef-border-width) is considered to be [0].

### 8.6. Mask Border Image Tiling: the [mask-border-repeat property]
Name:

[mask-border-repeat]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

\[ stretch
[\|](https://www.w3.org/TR/css-values-4/#comb-one) repeat [\|] round
[\|] space
\][{1,2}](https://www.w3.org/TR/css-values-4/#mult-num-range)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

stretch

Applies to:

All elements. In SVG, it applies to [container
elements](https://www.w3.org/TR/SVG2/struct.html#container-element) excluding the
[defs](https://www.w3.org/TR/SVG2/struct.html#elementdef-defs) element, all [graphics
elements](https://www.w3.org/TR/SVG2/struct.html#graphics-element) and the
[use](https://www.w3.org/TR/SVG2/struct.html#elementdef-use) element

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

as specified

Canonical order:

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

Media:

visual

This property specifies how the images for the sides and the middle part
of the [mask border
image](#mask-border-image)
are scaled and tiled. The first keyword applies to the horizontal sides,
the second to the vertical ones. If the second keyword is absent, it is
assumed to be the same as the first.

See the
[border-image-repeat](https://www.w3.org/TR/css-backgrounds-3/#propdef-border-image-repeat) property
[\[CSS3BG\]](#biblio-css3bg) for the definitions of
the property values.

The exact process for scaling and tiling the [mask border
image](#mask-border-image)
parts is given in the section [Masking with the mask border
image](#masking-with-the-mask-border-image)

### 8.7. Mask Border Image Shorthand: the [mask-border property]
Name:

[mask-border]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<\'mask-border-source\'\>](#propdef-mask-border-source)
[\|\|](https://www.w3.org/TR/css-values-4/#comb-any)
[\<\'mask-border-slice\'\>](#propdef-mask-border-slice) \[ /
[\<\'mask-border-width\'\>](#propdef-mask-border-width)[?](https://www.w3.org/TR/css-values-4/#mult-opt) \[ /
[\<\'mask-border-outset\'\>](#propdef-mask-border-outset) \][?]
\][?] [\|\|]
[\<\'mask-border-repeat\'\>](#propdef-mask-border-repeat) [\|\|]
[\<\'mask-border-mode\'\>](#propdef-mask-border-mode)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

See individual properties

Applies to:

See individual properties

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

See individual properties

Canonical order:

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

See individual properties

Media:

visual

This is a shorthand property for setting
[mask-border-source](#propdef-mask-border-source),
[mask-border-slice](#propdef-mask-border-slice),
[mask-border-width](#propdef-mask-border-width),
[mask-border-outset](#propdef-mask-border-outset),
[mask-border-repeat](#propdef-mask-border-repeat) and
[mask-border-mode](#propdef-mask-border-mode). Omitted values are set to their initial
values.

Note: The [mask](#propdef-mask) shorthand resets the properties
[mask-border](#propdef-mask-border),
[mask-border-source](#propdef-mask-border-source),
[mask-border-slice](#propdef-mask-border-slice),
[mask-border-width](#propdef-mask-border-width),
[mask-border-outset](#propdef-mask-border-outset),
[mask-border-repeat](#propdef-mask-border-repeat) and
[mask-border-mode](#propdef-mask-border-mode).

### 8.8. Masking with the mask border image

After the [mask border
image](#mask-border-image)
given by
[mask-border-source](#propdef-mask-border-source) is sliced by the
[mask-border-slice](#propdef-mask-border-slice) values, the resulting nine images are
scaled, positioned, and tiled into their corresponding [mask border
image] regions in four steps as described
in the section [Drawing the Border
Image](https://www.w3.org/TR/css3-background/#border-image-process)
[\[CSS3BG\]](#biblio-css3bg).

The application of the
[mask-border-source](#propdef-mask-border-source) property to an element formatted with
the CSS box model establishes a [stacking
context](https://www.w3.org/TR/SVG2/render.html#TermStackingContext) in the same way that CSS
[opacity](https://www.w3.org/TR/css-color-4/#propdef-opacity)
[\[CSS3COLOR\]](#biblio-css3color) does, and all the
element's descendants are rendered together as a group with the masking
applied to the group as a whole.

The
[mask-border-source](#propdef-mask-border-source) property has no effect on the geometry
or hit-testing of any element's CSS boxes.

## 9. SVG Mask Sources

### 9.1. The [mask element]
Name:

[`mask`]

Categories:

[container
elements](https://www.w3.org/TR/SVG2/struct.html#container-element), [never-rendered
element](https://svgwg.org/svg2-draft/render.html#TermNeverRenderedElement)

Content model:

Any number of the following elements, in any order:

- [animation](https://www.w3.org/TR/2011/REC-SVG11-20110816/intro.html#TermAnimationElement)
 [ ---
 [animate](https://www.w3.org/TR/SVG11/animate.html#AnimateElement),
 [animateColor](https://www.w3.org/TR/SVG11/animate.html#AnimateColorElement),
 [animateMotion](https://www.w3.org/TR/SVG11/animate.html#AnimateMotionElement),
 [animateTransform](https://www.w3.org/TR/SVG11/animate.html#AnimateTransformElement),
 [set](https://www.w3.org/TR/SVG11/animate.html#SetElement)]
- [descriptive](https://www.w3.org/TR/2011/REC-SVG11-20110816/intro.html#TermDescriptiveElement)
 [ ---
 [desc](https://www.w3.org/TR/SVG2/struct.html#elementdef-desc),
 [title](https://www.w3.org/TR/SVG2/struct.html#elementdef-title),
 [metadata](https://www.w3.org/TR/SVG2/struct.html#elementdef-metadata)]
- [shape](https://www.w3.org/TR/2011/REC-SVG11-20110816/intro.html#TermShapeElement)
 [ ---
 [circle](https://www.w3.org/TR/SVG2/shapes.html#elementdef-circle),
 [ellipse](https://www.w3.org/TR/SVG2/shapes.html#elementdef-ellipse),
 [line](https://www.w3.org/TR/SVG2/shapes.html#elementdef-line),
 [path](https://www.w3.org/TR/SVG2/paths.html#elementdef-path),
 [polygon](https://www.w3.org/TR/SVG2/shapes.html#elementdef-polygon),
 [polyline](https://www.w3.org/TR/SVG2/shapes.html#elementdef-polyline),
 [rect](https://www.w3.org/TR/SVG2/shapes.html#elementdef-rect)]
- [structural](https://www.w3.org/TR/2011/REC-SVG11-20110816/intro.html#TermStructuralElement)
 [ ---
 [defs](https://www.w3.org/TR/SVG2/struct.html#elementdef-defs),
 [g](https://www.w3.org/TR/SVG2/struct.html#elementdef-g),
 [svg](https://www.w3.org/TR/SVG2/struct.html#elementdef-svg),
 [symbol](https://www.w3.org/TR/SVG2/struct.html#elementdef-symbol),
 [use](https://www.w3.org/TR/SVG2/struct.html#elementdef-use)]
- [gradient](https://www.w3.org/TR/2011/REC-SVG11-20110816/intro.html#TermGradientElement)
 [ ---
 [linearGradient](https://www.w3.org/TR/SVG2/pservers.html#elementdef-linearGradient),
 [radialGradient](https://www.w3.org/TR/SVG2/pservers.html#elementdef-radialGradient)]
- [a](https://www.w3.org/TR/SVG2/linking.html#elementdef-a)
- [clipPath](#elementdef-clippath)
- [color-profile](https://www.w3.org/TR/SVG11/color.html#ColorProfileElement)
- [cursor](https://www.w3.org/TR/SVG11/interact.html#CursorElement)
- [filter](https://www.w3.org/TR/filter-effects-1/#elementdef-filter)
- [font](https://www.w3.org/TR/SVG11/fonts.html#FontElement)
- [font-face](https://www.w3.org/TR/SVG11/fonts.html#FontFaceElement)
- [foreignObject](https://www.w3.org/TR/SVG2/embedded.html#elementdef-foreignObject)
- [image](https://www.w3.org/TR/SVG2/embedded.html#elementdef-image)
- [marker](https://www.w3.org/TR/SVG2/painting.html#elementdef-marker)
- [mask](#elementdef-mask)
- [pattern](https://www.w3.org/TR/SVG2/pservers.html#elementdef-pattern)
- [script](https://www.w3.org/TR/SVG2/interact.html#elementdef-script)
- [style](https://www.w3.org/TR/SVG2/styling.html#elementdef-style)
- [switch](https://www.w3.org/TR/SVG2/struct.html#elementdef-switch)
- [view](https://www.w3.org/TR/SVG2/linking.html#elementdef-view)
- [text](https://www.w3.org/TR/SVG2/text.html#elementdef-text)
- [altGlyphDef](https://www.w3.org/TR/SVG11/text.html#AlternateGlyphDefinitions)

Attributes:

- [conditional processing
 attributes](https://www.w3.org/TR/2011/REC-SVG11-20110816/intro.html#TermConditionalProcessingAttribute)[
 ---
 [['requiredFeatures']](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#RequiredFeaturesAttribute),
 [['requiredExtensions']](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#RequiredExtensionsAttribute),
 [['systemLanguage']](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#SystemLanguageAttribute)]
- [core
 attributes](https://www.w3.org/TR/2011/REC-SVG11-20110816/intro.html#TermCoreAttributes)[
 ---
 [['id']](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#IDAttribute),
 [['xml:base']](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#XMLBaseAttribute),
 [['xml:lang']](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#XMLLangAttribute),
 [['xml:space']](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#XMLSpaceAttribute)]
- [presentation
 attributes](https://www.w3.org/TR/2011/REC-SVG11-20110816/intro.html#TermPresentationAttribute)[
 ---
 [alignment-baseline](https://www.w3.org/TR/css-inline-3/#propdef-alignment-baseline),
 [baseline-shift](https://www.w3.org/TR/css-inline-3/#propdef-baseline-shift),
 [clip](#propdef-clip),
 [clip-path](#propdef-clip-path),
 [clip-rule](#propdef-clip-rule),
 [color](https://www.w3.org/TR/css-color-4/#propdef-color),
 [color-interpolation](https://www.w3.org/TR/SVG2/painting.html#ColorInterpolationProperty),
 [color-interpolation-filters](https://www.w3.org/TR/filter-effects-1/#propdef-color-interpolation-filters),
 [color-profile](https://www.w3.org/TR/SVG11/color.html#ColorProfileProperty),
 [color-rendering](https://www.w3.org/TR/SVG2/painting.html#ColorRenderingProperty),
 [cursor](https://www.w3.org/TR/css-ui-3/#propdef-cursor),
 [direction](https://www.w3.org/TR/css-writing-modes-3/#propdef-direction),
 [display](https://www.w3.org/TR/css-display-3/#propdef-display),
 [dominant-baseline](https://www.w3.org/TR/css-inline-3/#propdef-dominant-baseline),
 [enable-background](https://www.w3.org/TR/SVG11/filters.html#EnableBackgroundProperty),
 [fill](https://www.w3.org/TR/SVG2/painting.html#FillProperty),
 [fill-opacity](https://www.w3.org/TR/SVG2/painting.html#FillOpacityProperty),
 [fill-rule](https://www.w3.org/TR/SVG2/painting.html#FillRuleProperty),
 [filter](https://www.w3.org/TR/filter-effects-1/#propdef-filter),
 [flood-color](https://www.w3.org/TR/filter-effects-1/#propdef-flood-color),
 [flood-opacity](https://www.w3.org/TR/filter-effects-1/#propdef-flood-opacity),
 [font](https://www.w3.org/TR/css-fonts-4/#propdef-font),
 [font-family](https://www.w3.org/TR/css-fonts-4/#propdef-font-family),
 [font-size](https://www.w3.org/TR/css-fonts-5/#descdef-font-face-font-size),
 [font-size-adjust](https://www.w3.org/TR/css-fonts-5/#propdef-font-size-adjust),
 [font-stretch](https://www.w3.org/TR/css-fonts-4/#propdef-font-stretch),
 [font-style](https://www.w3.org/TR/css-fonts-4/#propdef-font-style),
 [font-variant](https://www.w3.org/TR/css-fonts-4/#propdef-font-variant),
 [font-weight](https://www.w3.org/TR/css-fonts-4/#propdef-font-weight),
 [glyph-orientation-horizontal](https://www.w3.org/TR/SVG11/text.html#GlyphOrientationHorizontalProperty),
 [glyph-orientation-vertical](https://www.w3.org/TR/css-writing-modes-4/#propdef-glyph-orientation-vertical),
 [image-rendering](https://www.w3.org/TR/css-images-3/#propdef-image-rendering),
 [kerning](https://www.w3.org/TR/SVG11/text.html#KerningProperty),
 [letter-spacing](https://www.w3.org/TR/css-text-3/#propdef-letter-spacing),
 [lighting-color](https://www.w3.org/TR/filter-effects-1/#propdef-lighting-color),
 [marker](https://www.w3.org/TR/SVG2/painting.html#MarkerProperty),
 [marker-end](https://www.w3.org/TR/SVG2/painting.html#MarkerEndProperty),
 [marker-mid](https://www.w3.org/TR/SVG2/painting.html#MarkerMidProperty),
 [marker-start](https://www.w3.org/TR/SVG2/painting.html#MarkerStartProperty),
 [mask](#propdef-mask),
 [opacity](https://www.w3.org/TR/css-color-4/#propdef-opacity),
 [overflow](https://www.w3.org/TR/css-overflow-3/#propdef-overflow),
 [pointer-events](https://www.w3.org/TR/SVG2/interact.html#PointerEventsProperty),
 [shape-rendering](https://www.w3.org/TR/SVG2/painting.html#ShapeRenderingProperty),
 [stop-color](https://www.w3.org/TR/SVG2/pservers.html#StopColorProperty),
 [stop-opacity](https://www.w3.org/TR/SVG2/pservers.html#StopOpacityProperty),
 [stroke](https://www.w3.org/TR/SVG2/painting.html#StrokeProperty),
 [stroke-dasharray](https://www.w3.org/TR/SVG2/painting.html#StrokeDasharrayProperty),
 [stroke-dashoffset](https://www.w3.org/TR/SVG2/painting.html#StrokeDashoffsetProperty),
 [stroke-linecap](https://www.w3.org/TR/SVG2/painting.html#StrokeLinecapProperty),
 [stroke-linejoin](https://www.w3.org/TR/SVG2/painting.html#StrokeLinejoinProperty),
 [stroke-miterlimit](https://www.w3.org/TR/SVG2/painting.html#StrokeMiterlimitProperty),
 [stroke-opacity](https://www.w3.org/TR/SVG2/painting.html#StrokeOpacityProperty),
 [stroke-width](https://www.w3.org/TR/SVG2/painting.html#StrokeWidthProperty),
 [text-anchor](https://www.w3.org/TR/SVG2/text.html#TextAnchorProperty),
 [text-decoration](https://www.w3.org/TR/css-text-decor-3/#propdef-text-decoration),
 [text-rendering](https://www.w3.org/TR/SVG2/painting.html#TextRenderingProperty),
 [unicode-bidi](https://www.w3.org/TR/css-writing-modes-3/#propdef-unicode-bidi),
 [visibility](https://www.w3.org/TR/CSS2/visufx.html#propdef-visibility),
 [word-spacing](https://www.w3.org/TR/css-text-3/#propdef-word-spacing),
 [writing-mode](https://www.w3.org/TR/css-writing-modes-4/#propdef-writing-mode)]
- [['class']](https://www.w3.org/TR/2011/REC-SVG11-20110816/styling.html#ClassAttribute)
- [['style']](https://www.w3.org/TR/2011/REC-SVG11-20110816/styling.html#StyleAttribute)
- '[x](#element-attrdef-mask-x)'
- '[y](#element-attrdef-mask-y)'
- '[width](#element-attrdef-mask-width)'
- '[height](#element-attrdef-mask-height)'
- '[maskUnits](#element-attrdef-mask-maskunits)'
- '[maskContentUnits](#element-attrdef-mask-maskcontentunits)'

DOM Interfaces:

[SVGMaskElement](#InterfaceSVGMaskElement)

*Attribute definitions:*

[`maskUnits`] = \"[userSpaceOnUse](#valdef-maskunits-userspaceonuse) \| [objectBoundingBox](#valdef-maskunits-objectboundingbox)\"

: Defines the coordinate system for attributes
 [x](#element-attrdef-mask-x),
 [y](#element-attrdef-mask-y),
 [width](#element-attrdef-mask-width) and
 [height](#element-attrdef-mask-height).

 [userSpaceOnUse]

 : [x](#element-attrdef-mask-x),
 [y](#element-attrdef-mask-y),
 [width](#element-attrdef-mask-width) and
 [height](#element-attrdef-mask-height) represent values in the current [user
 coordinate
 system](https://www.w3.org/TR/css-transforms-1/#user-coordinate-system)
 [\[CSS3-TRANSFORMS\]](#biblio-css3-transforms)
 in place at the time when the
 [mask](#elementdef-mask) element is referenced (i.e., the [user
 coordinate system] for the
 element referencing the [mask]
 element via the [mask](#propdef-mask) property).

 [objectBoundingBox]

 : [x](#element-attrdef-mask-x),
 [y](#element-attrdef-mask-y),
 [width](#element-attrdef-mask-width) and
 [height](#element-attrdef-mask-height) represent fractions or percentages of
 the [object bounding
 box](https://www.w3.org/TR/SVG2/coords.html#TermObjectBoundingBox) of the element to which the mask is applied.
 [User coordinates](https://www.w3.org/TR/SVG/coords.html#Units)
 are sized equivalently to the CSS
 [px](https://www.w3.org/TR/css-values-4/#px) unit.

 If attribute
 [maskUnits](#element-attrdef-mask-maskunits) is not specified, then the effect is as if
 a value of
 [objectBoundingBox](#valdef-maskunits-objectboundingbox) were specified.

 Animatable: yes.

[`maskContentUnits`] = \"[userSpaceOnUse](#valdef-maskcontentunits-userspaceonuse) \| [objectBoundingBox](#valdef-maskcontentunits-objectboundingbox)\"

: Defines the coordinate system for the contents of the
 [mask](#elementdef-mask).

 [userSpaceOnUse]

 : The [user coordinate
 system](https://www.w3.org/TR/css-transforms-1/#user-coordinate-system) for the contents of the
 [mask](#elementdef-mask) element is the current [user coordinate
 system] in place at the time
 when the [mask] element is
 referenced (i.e., the [user coordinate
 system] for the element
 referencing the [mask] element via
 the [mask](#propdef-mask) property).

 [objectBoundingBox]

 : The coordinate system has its origin at the top left corner of
 the [bounding
 box](https://www.w3.org/TR/SVG2/coords.html#bounding-box) of the element to which the clipping path
 applies to and the same width and height of this [bounding
 box]. [User
 coordinates](https://www.w3.org/TR/SVG/coords.html#Units) are
 sized equivalently to the CSS
 [px](https://www.w3.org/TR/css-values-4/#px) unit.

 If attribute
 [maskContentUnits](#element-attrdef-mask-maskcontentunits) is not specified, then the effect is as if
 a value of
 [userSpaceOnUse](#valdef-maskcontentunits-userspaceonuse) were specified.

 Animatable: yes.

[`x`] = \"[\<length-percentage\>](https://www.w3.org/TR/css-values-4/#typedef-length-percentage)\"

: The x-axis coordinate of one corner of the rectangle for the largest
 possible offscreen buffer. If the attribute is not specified but at
 least one of the attributes
 [y](#element-attrdef-mask-y),
 [width](#element-attrdef-mask-width) or
 [height](#element-attrdef-mask-height) are specified, the effect is as if a value
 of [-10%] were specified.

 Animatable: yes.

[`y`] = \"[\<length-percentage\>](https://www.w3.org/TR/css-values-4/#typedef-length-percentage)\"

: The y-axis coordinate of one corner of the rectangle for the largest
 possible offscreen buffer. If the attribute is not specified but at
 least one of the attributes
 [x](#element-attrdef-mask-x),
 [width](#element-attrdef-mask-width) or
 [height](#element-attrdef-mask-height) are specified, the effect is as if a value
 of [-10%] were specified.

 Animatable: yes.

[`width`] = \"[\<length-percentage\>](https://www.w3.org/TR/css-values-4/#typedef-length-percentage)\"

: The width of the largest possible offscreen buffer. A negative value
 or a value of zero disables rendering of the element. If the
 attribute is not specified but at least one of the attributes
 [x](#element-attrdef-mask-x),
 [y](#element-attrdef-mask-y) or
 [height](#element-attrdef-mask-height) are specified, the effect is as if a value
 of [120%] were specified.

 Animatable: yes.

[`height`] = \"[\<length-percentage\>](https://www.w3.org/TR/css-values-4/#typedef-length-percentage)\"

: The height of the largest possible offscreen buffer. A negative
 value or a value of zero disables rendering of the element. If the
 attribute is not specified but at least one of the attributes
 [x](#element-attrdef-mask-x),
 [y](#element-attrdef-mask-y) or
 [width](#element-attrdef-mask-width) are specified, the effect is as if a value
 of [120%] were specified.

 Animatable: yes.

If at least one of the attributes
[x](#element-attrdef-mask-x),
[y](#element-attrdef-mask-y),
[width](#element-attrdef-mask-width) or
[height](#element-attrdef-mask-height) are specified, the given object and the
rectangle defined by [x],
[y],
[width] and
[height] establish a current
clipping path. The rendered content of the mask must be clipped by this
current clipping path.

CSS properties inherit into the
[mask](#elementdef-mask)
element from its ancestors; properties do *not* inherit from the element
referencing the [mask] element.

[mask](#elementdef-mask)
elements are never rendered directly; their only usage is as something
that can be referenced using the
[mask](#propdef-mask) property. The
[opacity](https://www.w3.org/TR/css-color-4/#propdef-opacity),
[filter](https://www.w3.org/TR/filter-effects-1/#propdef-filter) and
[display](https://www.w3.org/TR/css-display-3/#propdef-display) properties do not apply to the
[mask] element; thus,
[mask] elements are not directly rendered
even if the [display] property is
set to a value other than
[none](https://www.w3.org/TR/css-display-3/#valdef-display-none), and [mask] elements
are available for referencing even when the
[display] property on the
[mask] element or any of its ancestors is
set to [none].

### 9.2. Mask Source Interpretation: the [mask-type property]
Name:

[mask-type]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

luminance
[\|](https://www.w3.org/TR/css-values-4/#comb-one) alpha

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

luminance

Applies to:

[mask](#elementdef-mask)
elements

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

as specified

Canonical order:

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

Media:

visual

The [mask-type](#propdef-mask-type) property defines whether the content of
the [mask](#elementdef-mask) element is treated as as luminance mask or alpha
mask, as described in [Calculating mask values](#MaskValues).

Values have the following meanings:

[luminance]

: Indicates that the luminance values of the mask should be used.

[alpha]

: Indicates that the alpha values of the mask should be used.

The [mask-type](#propdef-mask-type) property allows the author of the
[mask](#elementdef-mask)
element to specify the preferred masking mode. However, the author can
override this preference by setting the
[mask-mode](#propdef-mask-mode) value to something different than
[match-source](#valdef-mask-mode-match-source) on the masked content.

In the following example the computed
value of [mask-type](#propdef-mask-type) is
[luminance](#valdef-mask-type-luminance) and the computed value of
[mask-mode](#propdef-mask-mode) is
[match-source](#valdef-mask-mode-match-source). The UA must follow the preferred masking mode
defined on the [mask](#elementdef-mask) element.

``` highlight
<svg>
 <mask style="mask-type: luminance;" id="mask">
 ...
 </mask>
</svg>

<p style="mask-image: url(#mask); mask-mode: auto;">
 This is the masked content.
</p>
```

In the next example the computed value of
[mask-mode](#propdef-mask-mode) is
[alpha](#valdef-mask-mode-alpha) and overrides the preference on the
[mask](#elementdef-mask)
element that is computed to
[luminance](#valdef-mask-type-luminance). The [mask layer
image](#mask-layer-image)
is used as an alpha mask.

``` highlight
lt;svg>
 <mask style="mask-type: luminance;" id="mask2">
 ...
 </mask>
lt;/svg>

lt;p style="mask-image: url(#mask2); mask-mode: alpha;">
 This is the masked content.
lt;/p>
```

The [mask-type](#propdef-mask-type) property is a [presentation
attribute](https://www.w3.org/TR/2011/REC-SVG11-20110816/intro.html#TermPresentationAttribute)
for SVG elements.

## 10. Privacy and Security Considerations

It is important that the timing to the masking operations is independent
of the source and destination pixel. Masking operations must be
implemented in such a way that they always take the same amount of time
regardless of the pixel values. If this rule is not followed, an
attacker could infer information and mount a timing attack.

A timing attack is a method of obtaining information about content that
is otherwise protected, based on studying the amount of time it takes
for an operation to occur. If, for example, red pixels took longer to
draw than green pixels, one might be able to reconstruct a rough image
of the element being rendered, without ever having access to the content
of the element.

[\<mask-source\>](#typedef-mask-source)s and
[\<clip-source\>](#typedef-clip-source)s have special requirements on
fetching resources.

User agents must use the [potentially CORS-enabled
fetch](https://fetch.spec.whatwg.org/#main-fetch) method defined by the
[\[FETCH\]](#biblio-fetch) specification for all
[\<mask-source\>](#typedef-mask-source),
[\<clip-source\>](#typedef-clip-source) and
[\<image\>](https://www.w3.org/TR/css-images-3/#typedef-image) values on the
[mask-image](#propdef-mask-image),
[mask-border-source](#propdef-mask-border-source) and
[clip-path](#propdef-clip-path) properties. When fetching, user agents must use
"Anonymous" mode, set the referrer source to the stylesheet's URL and
set the origin to the URL of the containing document. If this results in
network errors, the effect is as if the value [none] had been
specified.

## [Appendix A: The deprecated [clip](#propdef-clip) property]
Name:

[clip]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[rect()](#funcdef-clip-rect)
[\|](https://www.w3.org/TR/css-values-4/#comb-one)
[auto](https://drafts.csswg.org/css2/#valdef-clip-auto)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

auto

Applies to:

Absolutely positioned elements. In SVG, it applies to [elements which
establish a new
viewport](https://www.w3.org/TR/SVG/coords.html#EstablishingANewSVGViewport),
[pattern](https://www.w3.org/TR/SVG2/pservers.html#elementdef-pattern) elements and
[mask](#elementdef-mask)
elements.

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

as specified

Canonical order:

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by [computed
value](https://drafts.csswg.org/web-animations-1/#animation-type)

Media:

visual

With this specification the [clip](#propdef-clip) property is deprecated. Authors are
encouraged to use the
[clip-path](#propdef-clip-path) property instead. UAs must support the
[clip] property.

The [clip](#propdef-clip) property applies only to absolutely positioned
elements. In SVG, it applies to [elements which establish a new
viewport](https://www.w3.org/TR/SVG/coords.html#EstablishingANewSVGViewport),
[pattern](https://www.w3.org/TR/SVG2/pservers.html#elementdef-pattern) elements and
[mask](#elementdef-mask)
elements. Values have the following meanings:

auto

: The element does not clip.

[rect()] = rect( [\<top\>](#typedef-clip-top), [\<right\>](#typedef-clip-right), [\<bottom\>](#typedef-clip-bottom), [\<left\>](#typedef-clip-left) )

: [\<top\>](#typedef-clip-top) and
 [\<bottom\>](#typedef-clip-bottom) specify offsets from the top
 border edge of the box, and
 [\<right\>](#typedef-clip-right), and
 [\<left\>](#typedef-clip-left) specify offsets from the left
 border edge of the box. Authors should separate offset values with
 commas. User agents must support separation with commas, but may
 also support separation without commas (but not a combination),
 because a previous revision of this specification was ambiguous in
 this respect.

 [\<top\>], [\<right\>],
 [\<bottom\>], and
 [\<left\>] may either have a
 [\<length\>](https://www.w3.org/TR/css-values-4/#length-value "Expands to: advance measure | cap | ch | cm | dvb | dvh | dvi | dvmax | dvmin | dvw | em | ex | ic | in | lh | lvb | lvh | lvi | lvmax | lvmin | lvw | mm | pc | pt | px | q | rem | rlh | svb | svh | svi | svmax | svmin | svw | vb | vh | vi | vmax | vmin | vw") value or
 [auto](https://drafts.csswg.org/css2/#valdef-clip-auto). Negative lengths are permitted. The value
 [auto] means that a given edge of
 the clipping region will be the same as the edge of the element's
 generated border box (i.e., [auto]
 means the same as [0] for
 [\<top\>](#typedef-clip-top) and
 [\<left\>](#typedef-clip-left), the same as the [used
 value](https://www.w3.org/TR/css-cascade-5/#used-value) of the height plus the sum of vertical padding and
 border widths for
 [\<bottom\>](#typedef-clip-bottom), and the same as the used value
 of the width plus the sum of the horizontal padding and border
 widths for
 [\<right\>](#typedef-clip-right), such that four
 [auto] values result in the
 clipping region being the same as the element's border box).

 When coordinates are rounded to pixel coordinates, care should be
 taken that no pixels remain visible when
 [\<left\>](#typedef-clip-left) and
 [\<right\>](#typedef-clip-right) have the same value (or
 [\<top\>](#typedef-clip-top) and
 [\<bottom\>](#typedef-clip-bottom) have the same value), and
 conversely that no pixels within the element's border box remain
 hidden when these values are
 [auto](https://drafts.csswg.org/css2/#valdef-clip-auto).

The [clip](#propdef-clip) property is a [presentation
attribute](https://www.w3.org/TR/2011/REC-SVG11-20110816/intro.html#TermPresentationAttribute)
for SVG elements.

Example: The following two rules:

``` highlight
p#one { clip: rect(5px, 40px, 45px, 5px); }
p#two { clip: rect(5px, 55px, 45px, 5px); }
```

and assuming both Ps are 50 by 55 pixel, will create, respectively, the
rectangular clipping regions delimited by the dashed lines in the
following illustrations:

![Values for rect shape](images/clip.svg){height="300" width="580"}

This diagram illustrates two block boxes, one next to the other, with
rectangular clipping regions of different dimensions. (See [long
description](https://www.w3.org/TR/CSS2/images/longdesc/clip-desc.html).)

## [Appendix B: Compute stroke bounding box]
The algorithm to compute the [stroke bounding box] is as follows, depending
on the type of `element`:

a [graphics element](https://www.w3.org/TR/SVG2/struct.html#graphics-element) without [use](https://www.w3.org/TR/SVG2/struct.html#elementdef-use) or [image](https://www.w3.org/TR/SVG2/embedded.html#elementdef-image)\
an [a](https://www.w3.org/TR/SVG2/linking.html#elementdef-a) element with a [text content element](https://svgwg.org/svg2-draft/text.html#TermTextContentElement)

: 1. Let `box` be a rectangle initialized to the [object
 bounding
 box](https://www.w3.org/TR/SVG2/coords.html#TermObjectBoundingBox) of `element`.

 2. If the [used
 value](https://www.w3.org/TR/css-cascade-5/#used-value) of
 [stroke-width](https://www.w3.org/TR/SVG2/painting.html#StrokeWidthProperty) \<= 0 or the used value of
 [stroke](https://www.w3.org/TR/SVG2/painting.html#StrokeProperty) is [none] return
 `box`.

 3. Let `delta` be the inflation value initialized to the
 half of the
 [stroke-width](https://www.w3.org/TR/SVG2/painting.html#StrokeWidthProperty).

 4. If `element` is not
 [rect](https://www.w3.org/TR/SVG2/shapes.html#elementdef-rect),
 [ellipse](https://www.w3.org/TR/SVG2/shapes.html#elementdef-ellipse),
 [circle](https://www.w3.org/TR/SVG2/shapes.html#elementdef-circle) or
 [image](https://www.w3.org/TR/SVG2/embedded.html#elementdef-image) just follow one of the following conditions
 in the order they apply:

 the used value for [stroke-linejoin](https://www.w3.org/TR/SVG2/painting.html#StrokeLinejoinProperty) is [miter](https://www.w3.org/TR/fill-stroke-3/#valdef-stroke-linejoin-miter)

 : 1. Let `miter` be the used value of
 [stroke-miterlimit](https://www.w3.org/TR/SVG2/painting.html#StrokeMiterlimitProperty).

 2. If `miter` is smaller than the square root of
 2 and if the used value for
 [stroke-linecap](https://www.w3.org/TR/SVG2/painting.html#StrokeLinecapProperty) is
 [square](https://www.w3.org/TR/fill-stroke-3/#valdef-stroke-linecap-square), multiply `delta`
 with the square root of 2. Otherwise, multiply
 `delta` with `miter`.

 the used value for [stroke-linecap](https://www.w3.org/TR/SVG2/painting.html#StrokeLinecapProperty) is [square](https://www.w3.org/TR/fill-stroke-3/#valdef-stroke-linecap-square)

 : 1. Multiply `delta` with the square root of 2.

 5. Inflate `box` with the value of `delta`.

 6. Return `box`.

 Note: The values of the
 [stroke-opacity](https://www.w3.org/TR/SVG2/painting.html#StrokeOpacityProperty),
 [stroke-dasharray](https://www.w3.org/TR/SVG2/painting.html#StrokeDasharrayProperty) and
 [stroke-dashoffset](https://www.w3.org/TR/SVG2/painting.html#StrokeDashoffsetProperty) do not affect the calculation of the
 stroke bounding box.

a [container element](https://www.w3.org/TR/SVG2/struct.html#container-element)\
[use](https://www.w3.org/TR/SVG2/struct.html#elementdef-use)

: 1. Let `parent` be the [container
 element](https://www.w3.org/TR/SVG2/struct.html#container-element) if it is one, or the root of the
 [use](https://www.w3.org/TR/SVG2/struct.html#elementdef-use) element's shadow tree otherwise.

 2. For each child `child` of `parent`

 1. Invoke the stroke bounding box algorithm with
 `child`.

 2. Let `childBox` be the returned box value of the
 invoked algorithm.

 3. Map `childBox` from the coordinate space of
 `child` to the coordinate space of
 `parent`.

 3. Let `box` be the union of all
 `childBox`es.

 4. Return `box`.

[image](https://www.w3.org/TR/SVG2/embedded.html#elementdef-image)

: 1. Return the [object bounding
 box](https://www.w3.org/TR/SVG2/coords.html#TermObjectBoundingBox) of `element`.

Note: A future version of the SVG specification may override this
section.

## [Appendix C: DOM interfaces]
### [Interface SVGClipPathElement]
The [`SVGClipPathElement`] interface corresponds to the
[clipPath](#elementdef-clippath) element.

```
[Exposed=Window]
interface SVGClipPathElement : SVGElement {
 readonly attribute SVGAnimatedEnumeration clipPathUnits;
 readonly attribute SVGAnimatedTransformList transform;
};
```

Attributes:

:

 [`clipPathUnits`], of type [SVGAnimatedEnumeration](https://www.w3.org/TR/SVG2/types.html#InterfaceSVGAnimatedEnumeration), readonly

 : Corresponds to attribute
 [clipPathUnits](#element-attrdef-clippath-clippathunits) on the given
 [clipPath](#elementdef-clippath) element. Takes one of the constants defined
 in
 [SVGUnitTypes](https://www.w3.org/TR/SVG2/types.html#InterfaceSVGUnitTypes).

 [`transform`], of type [SVGAnimatedTransformList](https://www.w3.org/TR/SVG2/coords.html#InterfaceSVGAnimatedTransformList), readonly

 : Corresponds to presentation attribute
 [transform](https://www.w3.org/TR/css-transforms-1/#propdef-transform) on the given element.

### [Interface SVGMaskElement]
The [`SVGMaskElement`] interface corresponds to the
[mask](#elementdef-mask)
element.

```
[Exposed=Window]
interface SVGMaskElement : SVGElement {
 readonly attribute SVGAnimatedEnumeration maskUnits;
 readonly attribute SVGAnimatedEnumeration maskContentUnits;
 readonly attribute SVGAnimatedLength x;
 readonly attribute SVGAnimatedLength y;
 readonly attribute SVGAnimatedLength width;
 readonly attribute SVGAnimatedLength height;
};
```

Attributes:

:

 [`maskUnits`], of type [SVGAnimatedEnumeration](https://www.w3.org/TR/SVG2/types.html#InterfaceSVGAnimatedEnumeration), readonly

 : Corresponds to attribute
 [maskUnits](#element-attrdef-mask-maskunits) on the given
 [mask](#elementdef-mask) element. Takes one of the constants defined
 in
 [SVGUnitTypes](https://www.w3.org/TR/SVG2/types.html#InterfaceSVGUnitTypes).

 [`maskContentUnits`], of type [SVGAnimatedEnumeration](https://www.w3.org/TR/SVG2/types.html#InterfaceSVGAnimatedEnumeration), readonly

 : Corresponds to attribute
 [maskContentUnits](#element-attrdef-mask-maskcontentunits) on the given
 [mask](#elementdef-mask) element. Takes one of the constants defined
 in
 [SVGUnitTypes](https://www.w3.org/TR/SVG2/types.html#InterfaceSVGUnitTypes).

 [`x`], of type [SVGAnimatedLength](https://www.w3.org/TR/SVG2/types.html#InterfaceSVGAnimatedLength), readonly

 : Corresponds to attribute
 [x](#element-attrdef-mask-x) on the given
 [mask](#elementdef-mask) element.

 [`y`], of type [SVGAnimatedLength](https://www.w3.org/TR/SVG2/types.html#InterfaceSVGAnimatedLength), readonly

 : Corresponds to attribute
 [y](#element-attrdef-mask-y) on the given
 [mask](#elementdef-mask) element.

 [`width`], of type [SVGAnimatedLength](https://www.w3.org/TR/SVG2/types.html#InterfaceSVGAnimatedLength), readonly

 : Corresponds to attribute
 [width](#element-attrdef-mask-width) on the given
 [mask](#elementdef-mask) element.

 [`height`], of type [SVGAnimatedLength](https://www.w3.org/TR/SVG2/types.html#InterfaceSVGAnimatedLength), readonly

 : Corresponds to attribute
 [height](#element-attrdef-mask-height) on the given
 [mask](#elementdef-mask) element.

## [Changes since last publication]
The following changes were made since the [26 August 2014 Candidate
Recommendation](https://www.w3.org/TR/2014/CR-css-masking-1-20140826/).

- Allowed the
 [\<\'mask-mode\'\>](#propdef-mask-mode) value in the
 [mask](#propdef-mask) shorthand to appear anywhere other than between
 [\<\'mask-position\'\>](#propdef-mask-position) and
 [\<\'mask-size\'\>](#propdef-mask-size).

- Removed Implements SVGUnitTypes on clipPath and mask elements.

- Apply properties that apply to all graphics elements to the use
 element as well.

- Change initial value of
 [mask-position](#propdef-mask-position) to [0% 0%] and of
 [mask-repeat](#propdef-mask-repeat) to [repeat].

- Remove `margin-box` as possible value from
 [mask-origin](#propdef-mask-origin) and
 [mask-clip](#propdef-mask-clip).

- Clarify that
 [mask-clip](#propdef-mask-clip) has no affect on [mask layer
 image](#mask-layer-image)s that reference a
 [mask](#elementdef-mask) element.

- Clarify [mask](#propdef-mask) shorthand behavior on appearance of one
 [\<geometry-box\>](#typedef-geometry-box "Expands to: border-box | content-box | fill-box | margin-box | padding-box | stroke-box | svg viewport origin box | view-box") and the
 [no-clip](#valdef-mask-clip-no-clip) keyword.

- [mask-mode](#propdef-mask-mode) on a [mask layer
 image](#mask-layer-image)
 that is a reference to a
 [mask](#elementdef-mask) element with a value of
 [match-source](#valdef-mask-mode-match-source) should take the value of the
 [mask-type](#propdef-mask-type) property on this
 [mask] element.

- Mapping of boxes for SVG elements with and without associated CSS
 layout box changed to match mapping in Fill and Stroke spec.

- Editorial changes.

The following changes were made since the [22 May 2014 Working
Draft](https://www.w3.org/TR/2014/WD-css-masking-1-20140522/).

- Change the inital value of
 [mask-size](#propdef-mask-size) from border-box to auto.

The following changes were made since the [13 February 2014 Working
Draft](https://www.w3.org/TR/2014/WD-css-masking-1-20140213/).

- Renamed mask-box\* properties and terms to mask-border\*.

- Added support for multiple mask layers. (Similar to multiple
 background layers for
 [background](https://www.w3.org/TR/css-backgrounds-3/#propdef-background).)

- Added the
 [mask-composite](#propdef-mask-composite) property to control compositing of
 multiple [mask layer
 images](#mask-layer-image) with the keywords
 [add](#valdef-mask-composite-add),
 [subtract](#valdef-mask-composite-subtract),
 [intersect](#valdef-mask-composite-intersect) and
 [exclude](#valdef-mask-composite-exclude).

- [mask-border-slice](#propdef-mask-border-slice) without keyword
 [fill](#valdef-mask-border-slice-fill) does not clip middle piece of content anymore.
 Changed initial value from [0 fill] to [0].

- Better description for
 [clip-rule](#propdef-clip-rule),
 [mask-mode](#propdef-mask-mode) and
 [mask-type](#propdef-mask-type).

- Rename
 [fill](#valdef-mask-border-slice-fill) and [stroke] keywords to
 [fill-box](#valdef-clip-path-fill-box) and
 [stroke-box](#valdef-clip-path-stroke-box).

- Added definition for [stroke bounding
 box](#stroke-bounding-box).

- Better differentiation between mask images: [mask layer
 image](#mask-layer-image)
 and [mask border
 image](#mask-border-image).

The following changes were made since the [29 October 2013 Last Call
Working Draft](https://www.w3.org/TR/2013/WD-css-masking-1-20131029/).

- Remove note that a future version of the spec will allow controlling
 hit testing on clipping.

- Changed order of sections within the document.

- Make clear that the [used
 value](https://www.w3.org/TR/css-cascade-5/#used-value) of the properties
 [mask-image](#propdef-mask-image),
 [mask-repeat](#propdef-mask-repeat),
 [mask-position](#propdef-mask-position),
 [mask-clip](#propdef-mask-clip),
 [mask-origin](#propdef-mask-origin) and
 [mask-size](#propdef-mask-size) must be ignored for
 [\<mask-source\>](#typedef-mask-source), not the properties.

- \"Animatable\" section of
 [mask-size](#propdef-mask-size),
 [mask-position](#propdef-mask-position) described as repeatable list of lists.
 Changed to a single list.

- Computed value of
 [mask-repeat](#propdef-mask-repeat) and
 [mask-position](#propdef-mask-position) was described as list of items.
 Changed to have just one value.

- Change link to ED from <https://drafts.fxtf.org/masking/> to
 <https://drafts.fxtf.org/css-masking-1/>

The following significant changes were made since the [20 June 2013
Working Draft](https://www.w3.org/TR/2013/WD-css-masking-20130620/).

- [mask](#propdef-mask) resets [mask-box] properties.

- Initial values for
 [mask-repeat](#propdef-mask-repeat),
 [mask-position](#propdef-mask-position) and
 [mask-origin](#propdef-mask-origin) changed to [no-repeat],
 [center] and
 [border-box](#valdef-mask-origin-border-box).

- Multiple layers of mask images were deferred to a future level of this
 specification.

- Added security model for pixel operations and fetching of masking and
 clipping resources.

- Deferred \"child\" and select() function to next level.

The following significant changes were made since the [15 November 2012
Working Draft](https://www.w3.org/TR/2012/WD-css-masking-20121115/).

- Better integration with terms and definitions of CSS Backgrounds and
 Borders module.

- Syntax changes on [mask](#propdef-mask) shorthand property to be conform with
 [background](https://www.w3.org/TR/css-backgrounds-3/#propdef-background) shorthand property.

- Define how the implementation can differ between an SVG resource
 ([mask](#elementdef-mask),
 [clipPath](#elementdef-clippath)) and an image resource.

- Added [mask-mode](#propdef-mask-mode) property to alter between luminance
 and alpha mask on
 [mask-image](#propdef-mask-image).

- Adapt IDL definition of SVGMaskElement and SVGClipPathElement to
 WebIDL.

- Further editorial changes.

See detailed list of changes in the [ChangeLog](ChangeLog).

## [Acknowledgments]
Thanks to Elika J. Etemad, Cameron McCormack, Liam R. E. Quin, Björn
Höhrmann, Alan Stearns, Jarek Foksa, David Baron, Boris Zbarsky, Markus
Stange and Sara Soueidan for their careful reviews, comments, and
corrections. Special thanks to CJ Gammon for graphical assets.
