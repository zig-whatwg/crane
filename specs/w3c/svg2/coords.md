# Chapter 8: Coordinate Systems, Transformations and Units

::: }}
[Overview](./) · [Previous](geometry.html) · [Next](paths.html) ·
[Elements](eltindex.html) · [Attributes](attindex.html) ·
[Properties](propidx.html)

## Contents

1. 1. [[8.1.] Introduction](coords.html#Introduction)
 2. [[8.2.] Computing the equivalent transform of an SVG
 viewport](coords.html#ComputingAViewportsTransform)
 3. [[8.3.] The initial viewport](coords.html#ViewportSpace)
 4. [[8.4.] The initial coordinate
 system](coords.html#InitialCoordinateSystem)
 5. [[8.5.] The '[transform]'
 property](coords.html#TransformProperty)
 6. [[8.6.] The ['viewBox']
 attribute](coords.html#ViewBoxAttribute)
 7. [[8.7.] The ['preserveAspectRatio']
 attribute](coords.html#PreserveAspectRatioAttribute)
 8. [[8.8.] Establishing a new SVG
 viewport](coords.html#EstablishingANewSVGViewport)
 9. [[8.9.] Units](coords.html#Units)
 10. [[8.10.] Bounding boxes](coords.html#BoundingBoxes)
 11. [[8.11.] Object bounding box
 units](coords.html#ObjectBoundingBoxUnits)
 12. [[8.12.] Intrinsic sizing properties of SVG
 content](coords.html#SizingSVGInCSS)
 13. [[8.13.] Vector effects](coords.html#VectorEffects)
 1. [[8.13.1.] Computing the vector
 effects](coords.html#VectorEffectsCalculation)
 2. [[8.13.2.] Computing the vector effects for nested
 viewport coordinate
 systems](coords.html#NestedVectorEffectsCalculation)
 3. [[8.13.3.] Examples of vector
 effects](coords.html#VectorEffectsExamples)
 14. [[8.14.] DOM interfaces](coords.html#DOMInterfaces)
 1. [[8.14.1.] Interface
 SVGTransform](coords.html#InterfaceSVGTransform)
 2. [[8.14.2.] Interface
 SVGTransformList](coords.html#InterfaceSVGTransformList)
 3. [[8.14.3.] Interface
 SVGAnimatedTransformList](coords.html#InterfaceSVGAnimatedTransformList)
 4. [[8.14.4.] Interface
 SVGPreserveAspectRatio](coords.html#InterfaceSVGPreserveAspectRatio)
 5. [[8.14.5.] Interface
 SVGAnimatedPreserveAspectRatio](coords.html#InterfaceSVGAnimatedPreserveAspectRatio)

## 8.1. Introduction
::: ready-for-wider-review
All SVG content is drawn inside [SVG viewports]. Every SVG viewport defines a drawing region
characterized by a size (width, height), and an origin, measured in
abstract [user units].

Note that the term SVG viewport is distinct from the
[\"viewport\"](https://www.w3.org/TR/2011/REC-CSS2-20110607/visuren.html#viewport)
term used in CSS.

The [initial viewport] is a top-level SVG viewport that establishes a mapping
between the coordinate system used by the containing environment (for
example, CSS pixels in web browsers) and [user
units](coords.html#TermUserUnits). Establishing an initial viewport is
described in more detail in [The initial viewport](#ViewportSpace).

SVG viewports are only established by elements. See [Establishing a new
SVG viewport](#EstablishingANewSVGViewport) for information on which
elements generate viewports.

Each SVG viewport generates a [viewport coordinate
system] and
a [user coordinate system], initially identical. Providing a
['[viewBox](coords.html#ViewBoxAttribute)'] on a viewport\'s
element transforms the user coordinate system relative to the viewport
coordinate system as described in The
['[viewBox](coords.html#ViewBoxAttribute)'] attribute. Child
elements of a viewport can further modify the [user coordinate
system](https://drafts.csswg.org/css-transforms/#user-coordinate-system),
for example by specifying the
[transform](coords.html#TransformProperty) property.

SVG viewports can be nested. Percentage units are resolved with
reference to the user coordinate system of the nearest ancestral
viewport-defining element, as defined in [the section on Units](#Units).
Hence, nesting SVG viewports provides an opportunity to redefine the
meaning of percentage units and provide a new reference rectangle for
\"fitting\" a graphic relative to a particular rectangular area. The [
furthest ancestral SVG viewport] is the top most root SVG viewport with out
leaving the [SVG context](coords.html#TermSVGContext). An ancestor SVG
viewport might not be independent of the DOM tree order. E.g. for
['[linearGradient](pservers.html#LinearGradientElement)'],
['[radialGradient](pservers.html#RadialGradientElement)'],
['[pattern](pservers.html#PatternElement)'],
['[mask](https://drafts.csswg.org/css-masking-1/#MaskElement)'],
['[clipPath](https://drafts.csswg.org/css-masking-1/#ClipPathElement)']
['[symbol](struct.html#SymbolElement)'] or
['[use](struct.html#UseElement)'] elements.

An [SVG context] is a
document fragment where all elements within the fragment have the
[SVGElement](types.html#InterfaceSVGElement) as
prototype.

The width, height and origin of SVG viewports is established by a
negotiation process between the SVG document fragment generating the SVG
viewport, and the parent of that fragment (whether real or implicit).
See [Establishing a new SVG viewport](#EstablishingANewSVGViewport) for
a description of this negotiation process.

By default, a nested SVG viewport\'s [viewport coordinate
system](coords.html#TermViewportCoordinateSystem) is equivalent to the
local coordinate system of the parent element, translated by the origin
of the SVG viewport\'s element. However, a
[transform](coords.html#TransformProperty) property on an SVG
viewport\'s element will modify the [viewport coordinate
system](coords.html#TermViewportCoordinateSystem) relative to the parent
element\'s user coordinate system.

Abstractly, all SVG viewports are embedded in the [canvas], a drawing region that is infinitely
large in all relevant dimensions.

## 8.2. Computing the equivalent transform of an SVG viewport
This process converts the min-x, min-y, width and height values of a
viewBox attribute, the position and size of the element on which the
viewBox attribute is defined, and the value of the preserveAspectRatio
attribute on that element into a translation and a scale that is applied
to content contained by the element.

1. Let `vb-x`, `vb-y`, `vb-width`,
 `vb-height` be the min-x, min-y, width and height values
 of the viewBox attribute respectively.
2. Let `e-x`, `e-y`, `e-width`,
 `e-height` be the position and size of the element
 respectively.
3. Let `align` be the align value of preserveAspectRatio, or
 \'xMidYMid\' if preserveAspectRatio is not defined.
4. Let `meetOrSlice` be the meetOrSlice value of
 preserveAspectRatio, or \'meet\' if preserveAspectRatio is not
 defined or if meetOrSlice is missing from this value.
5. Initialize `scale-x` to
 `e-width`/`vb-width`.
6. Initialize `scale-y` to
 `e-height`/`vb-height`.
7. If `align` is not \'none\' and `meetOrSlice`
 is \'meet\', set the larger of `scale-x` and
 `scale-y` to the smaller.
8. Otherwise, if `align` is not \'none\' and
 `meetOrSlice` is \'slice\', set the smaller of
 `scale-x` and `scale-y` to the larger.
9. Initialize `translate-x` to `e-x` -
 (`vb-x` \* scale-x).
10. Initialize `translate-y` to `e-y` -
 (`vb-y` \* scale-y)
11. If `align` contains \'xMid\', add (`e-width` -
 `vb-width` \* `scale-x`) / 2 to
 `translate-x`.
12. If `align` contains \'xMax\', add (`e-width` -
 `vb-width` \* `scale-x`) to
 `translate-x`.
13. If `align` contains \'YMid\', add
 (`e-height` - `vb-height` \*
 `scale-y`) / 2 to `translate-y`.
14. If `align` contains \'YMax\', add
 (`e-height` - `vb-height` \*
 `scale-y`) to `translate-y.`

The transform applied to content contained by the element is given by
translate(`translate-x`, `translate-y`)
scale(`scale-x`, `scale-y`).

## 8.3. The initial viewport
The initial viewport\'s width, must be the value of the
[width](geometry.html#Sizing) presentation attribute on the
[outermost svg element](struct.html#TermOutermostSVGElement), unless the
following conditions are met:

- the SVG content is a separately stored resource that is embedded by
 reference (such as the ['object'] element in HTML), or
 the SVG content is embedded inline within a containing document;
- and the referencing element or containing document is styled using CSS
 \[[CSS2](refs.html#ref-css2)\];
- and there are [CSS-compatible positioning
 properties](https://www.w3.org/TR/2011/REC-CSS2-20110607/visuren.html#positioning-scheme)
 (\[[CSS2](refs.html#ref-css2)\], section 9.3) specified on the
 referencing element (e.g., the ['object'] element) or
 on the containing document\'s [outermost svg
 element](struct.html#TermOutermostSVGElement) that are sufficient to
 establish the width of the viewport.

Under these conditions, the viewport\'s width must be established via
the positioning properties.

Similarly, if there are [positioning
properties](https://www.w3.org/TR/2011/REC-CSS2-20110607/visuren.html#positioning-scheme)
specified on the referencing element or on the [outermost svg
element](struct.html#TermOutermostSVGElement) that are sufficient to
establish the height of the viewport, then these positioning properties
must establish the viewport\'s height; otherwise, the initial
viewport\'s height must be the value of the
[height](geometry.html#Sizing) presentation attribute on the
[outermost svg element](struct.html#TermOutermostSVGElement).

If the [width](geometry.html#Sizing) or
[height](geometry.html#Sizing) presentation attributes on the
[outermost svg element](struct.html#TermOutermostSVGElement) are in
[user units](coords.html#TermUserUnits) (i.e., no unit identifier has
been provided), then the value is assumed to be equivalent to the same
number of \"px\" units (see [Units](coords.html#Units)).

In the following example, an SVG graphic is embedded inline within a
parent XML document which is formatted using CSS layout rules. Since CSS
positioning properties are not provided on the [outermost svg
element](struct.html#TermOutermostSVGElement), the
[width=\"100px\"] and [height=\"200px\"]
attributes determine the size of the initial viewport:

 <?xml version="1.0" standalone="yes"?>
 <parent xmlns="http://some.url">

 <!-- SVG graphic -->
 <svg xmlns='http://www.w3.org/2000/svg'
 width="100px" height="200px">
 <path d="M100,100 Q200,400,300,100"/>
 <!-- rest of SVG graphic would go here -->
 </svg>

 </parent>

## 8.4. The initial coordinate system
For the [outermost svg element](struct.html#TermOutermostSVGElement),
the SVG user agent must determine an initial [viewport coordinate
system](coords.html#TermViewportCoordinateSystem) and an initial [user
coordinate
system](https://drafts.csswg.org/css-transforms/#user-coordinate-system)
such that the two coordinates systems are identical. The origin of both
coordinate systems must be at the origin of the SVG viewport, and one
unit in the initial coordinate system must equal one [CSS 2.1
px](https://www.w3.org/TR/2011/REC-CSS2-20110607/syndata.html#length-units)
(\[[CSS2](refs.html#ref-css2)\], section 4.3.2) in the SVG viewport. In
stand-alone SVG documents and in SVG document fragments embedded (by
reference or inline) within parent documents where the parent\'s layout
is determined by CSS \[[CSS2](refs.html#ref-css2)\], the initial
viewport coordinate system (and therefore the initial user coordinate
system) must have its origin at the top/left of the viewport, with the
positive x-axis pointing towards the right, the positive y-axis pointing
down, and text rendered with an \"upright\" orientation, which means
glyphs are oriented such that Roman characters and full-size ideographic
characters for Asian scripts have the top edge of the corresponding
glyphs oriented upwards and the right edge of the corresponding glyphs
oriented to the right.

If the SVG implementation is part of a user agent which supports styling
documents using CSS 2.1 compatible *px* units, then the SVG user agent
should set its initial value for the size of a *px* unit in real world
units to match the value used for other styling operations; otherwise,
if the user agent can determine the size of a *px* unit from its
environment, it should use that value; otherwise, it should choose an
appropriate size for one *px* unit. In all cases, the size of a *px*
must be in conformance with [the rules described in CSS
2.1](https://www.w3.org/TR/CSS2/syndata.html#length-units)
(\[[CSS2](refs.html#ref-css2)\], section 4.3.2).

[Example InitialCoords] below shows that the initial
coordinate system has the origin at the top/left with the x-axis
pointing to the right and the y-axis pointing down. The initial user
coordinate system has one user unit equal to the parent (implicit or
explicit) user agent\'s \"pixel\".

``` xml
<?xml version="1.0" standalone="no"?>
<svg width="300px" height="100px" version="1.1"
 xmlns="http://www.w3.org/2000/svg">
 <desc>Example InitialCoords - SVG's initial coordinate system</desc>

 <g fill="none" stroke="black" stroke-width="3" >
 <line x1="0" y1="1.5" x2="300" y2="1.5" />
 <line x1="1.5" y1="0" x2="1.5" y2="100" />
 </g>
 <g fill="red" stroke="none" >
 <rect x="0" y="0" width="3" height="3" />
 <rect x="297" y="0" width="3" height="3" />
 <rect x="0" y="97" width="3" height="3" />
 </g>
 <g font-size="14" font-family="Verdana" >
 <text x="10" y="20">(0,0)</text>
 <text x="240" y="20">(300,0)</text>
 <text x="10" y="90">(0,100)</text>
 </g>
</svg>
```

![Example InitialCoords --- SVG\'s initial coordinate
system](images/coords/InitialCoords.png)

Example InitialCoords

[View this example as SVG (SVG-enabled browsers
only)](images/coords/InitialCoords.svg)

:::::::::::: ready-for-wider-review
## 8.5. The '[transform]' property
User agents must support the
[transform](coords.html#TransformProperty) property and
presentation attribute as defined in
\[[css-transforms-1](refs.html#ref-css-transforms-1)\].

## 8.6. The ['viewBox'] attribute
 Name Value Initial value Animatable
 ------------------------------------------------------------------------------ ---------------------------------------------------------------------------------------------------------------- ---------------------- ------------
 [viewBox] \[[\<min-x\>],? [\<min-y\>],? [\<width\>],? [\<height\>]\] As if not specified. yes

 <min-x>, <min-y>, <width>, <height> = <number>

Transform on the ['[svg](struct.html#SVGElement)']
element is a bit special due to the
['[viewBox](coords.html#ViewBoxAttribute)'] attribute. The
transform should be applied as if the
['[svg](struct.html#SVGElement)'] had a parent element
with that transform set.\
\
[RESOLUTION: transform property applies conceptually to the outside of
the \'svg\' element and there is no difference between presentation
attribute and style
property](https://www.w3.org/2015/01/08-svg-minutes.html) (in terms of
the visual result).

The ['[viewBox](coords.html#ViewBoxAttribute)'] attribute,
in conjunction with the
['[preserveAspectRatio](coords.html#PreserveAspectRatioAttribute)']
attribute, provides the capability to stretch an SVG viewport to fit a
particular container element.

The value of the ['[viewBox](coords.html#ViewBoxAttribute)']
attribute is a list of four numbers [\<min-x\>],
[\<min-y\>], [\<width\>] and
[\<height\>], separated by whitespace and/or a comma, that
specify a rectangle in user space that should be mapped to the bounds of
the SVG viewport established by the given element, taking into account
the
['[preserveAspectRatio](coords.html#PreserveAspectRatioAttribute)']
attribute. The presence of the
['[viewBox](coords.html#ViewBoxAttribute)'] attribute
results in a transformation being applied to the viewport coordinate
system as described in [Computing the equivalent transform of an SVG
viewport](#ComputingAViewportsTransform).

A negative value for [\<width\>] or
[\<height\>] is an error: the
['[viewBox](coords.html#ViewBoxAttribute)'] attribute is
[invalid](types.html#TermInvalidValue) and must be treated as if it had
not been specified, so no viewBox transformation is applied. A value of
zero for [\<width\>] or [\<height\>] disables
rendering of the element, consistent with the treatment of other
zero-sized viewports.

[Example ViewBox] illustrates the use of the
['[viewBox](coords.html#ViewBoxAttribute)'] attribute on the
[outermost svg element](struct.html#TermOutermostSVGElement) to specify
that the SVG content should stretch to fit bounds of the SVG viewport.

 <?xml version="1.0" standalone="no"?>
 <svg width="300px" height="200px"
 viewBox="0 0 1500 1000" preserveAspectRatio="none"
 xmlns="http://www.w3.org/2000/svg">
 <desc>Example ViewBox - uses the viewBox
 attribute to automatically create an initial user coordinate
 system which causes the graphic to scale to fit into the
 SVG viewport no matter what size the SVG viewport is.</desc>
 <!-- This rectangle goes from (0,0) to (1500,1000) in user coordinate system.
 Because of the viewBox attribute above,
 the rectangle will end up filling the entire area
 reserved for the SVG content. -->
 <rect x="0" y="0" width="1500" height="1000"
 fill="yellow" stroke="blue" stroke-width="12" />
 <!-- A large, red triangle -->
 <path fill="red" d="M 750,100 L 250,900 L 1250,900 z"/>
 <!-- A text string that spans most of the SVG viewport -->
 <text x="100" y="600" font-size="200" font-family="Verdana" >
 Stretch to fit
 </text>
 </svg>

 ----------------------------------------------------------------------------------------------------------------------------
 Rendered into\       Rendered into\
 SVG viewport with\ SVG viewport with\
 width=300px,\ width=150px,\
 height=200px height=200px
 --------------------------------------------- ----------------------- ------------------------------------------------------
 ![Example ViewBox - stretch to fit 300 by       ![Example ViewBox - stretch to fit 150 by
 200](images/coords/ViewBox.png){width="300" 200](images/coords/ViewBox-Width150.png){width="150"
 height="200"} height="200"}

 ----------------------------------------------------------------------------------------------------------------------------

 : Example ViewBox

[View this example as SVG (SVG-enabled browsers
only)](images/coords/ViewBox.svg)\
 

The effect of the
['[viewBox](coords.html#ViewBoxAttribute)'] attribute is
that the user agent automatically supplies the appropriate
transformation matrix to map the specified rectangle in user coordinate
system to the bounds of a designated region (often, the SVG viewport).
To achieve the effect of the example on the left, with SVG viewport
dimensions of 300 by 200 pixels, the user agent needs to automatically
insert a transformation which scales both X and Y by 0.2. The effect is
equivalent to having an SVG viewport of size 300px by 200px and the
following supplemental transformation in the document, as follows:

 <?xml version="1.0" standalone="no"?>
 <svg width="300px" height="200px"
 xmlns="http://www.w3.org/2000/svg">
 <g transform="scale(0.2)">
 <!-- Rest of document goes here -->
 </g>
 </svg>

To achieve the effect of the example on the right, with SVG viewport
dimensions of 150 by 200 pixels, the user agent needs to automatically
insert a transformation which scales X by 0.1 and Y by 0.2. The effect
is equivalent to having an SVG viewport of size 150px by 200px and the
following supplemental transformation in the document, as follows:

 <?xml version="1.0" standalone="no"?>
 <svg width="150px" height="200px"
 xmlns="http://www.w3.org/2000/svg">
 <g transform="scale(0.1 0.2)">
 <!-- Rest of document goes here -->
 </g>
 </svg>

Note that in some cases the user agent will need to supply a
**translate** transformation in addition to a **scale** transformation.
For example, on an [outermost svg
element](struct.html#TermOutermostSVGElement), a **translate**
transformation will be needed if the
['[viewBox](coords.html#ViewBoxAttribute)'] attributes
specifies values other than zero for [\<min-x\>] or
[\<min-y\>].

If both [transform](coords.html#TransformProperty) (or
['[patternTransform](pservers.html#PatternElementPatternTransformAttribute)'])
and ['[viewBox](coords.html#ViewBoxAttribute)'] are applied
to an element two new coordinate systems are established.
[transform](coords.html#TransformProperty) establishes the
first new coordinate system for the element.
['[viewBox](coords.html#ViewBoxAttribute)'] establishes a
second coordinate system for all descendants of the element. The first
coordinate system is post-multiplied by the second coordinate system.

Unlike the [transform](coords.html#TransformProperty)
property, the automatic transformation that is created due to a
['[viewBox](coords.html#ViewBoxAttribute)'] does not affect
the ['x'], ['y'], ['width'] and
['height'] attributes (or in the case of the
['[marker](painting.html#MarkerElement)'] element, the
['[markerWidth](painting.html#MarkerWidthAttribute)'] and
['[markerHeight](painting.html#MarkerHeightAttribute)']
attributes) on the element with the
['[viewBox](coords.html#ViewBoxAttribute)'] attribute. Thus,
in the example above which shows an
['[svg](struct.html#SVGElement)'] element which has
[width](geometry.html#Sizing) and
[height](geometry.html#Sizing) presentation attributes and a
['[viewBox](coords.html#ViewBoxAttribute)'] attribute, the
[width](geometry.html#Sizing) and
[height](geometry.html#Sizing) represent values in the
coordinate system that exists *before* the
['[viewBox](coords.html#ViewBoxAttribute)'] transformation
is applied. On the other hand, like the
[transform](coords.html#TransformProperty) property, it does
establish a new coordinate system for all other attributes and for
descendant elements.

## 8.7. The ['preserveAspectRatio'] attribute
 Name Value Initial value Animatable
 ------------------------------------------------------------------------------------------------------ ---------------------------------------------------------- --------------- ------------
 [preserveAspectRatio] [\<align\>] [\<meetOrSlice\>]? xMidYMid meet yes

 <align> =
 none
 | xMinYMin | xMidYMin | xMaxYMin
 | xMinYMid | xMidYMid | xMaxYMid
 | xMinYMax | xMidYMax | xMaxYMax

 <meetOrSlice> = meet | slice

Indicates whether or not to force uniform scaling. Applies to all
elements that establish a new SVG viewport (see [elements that establish
SVG viewports](coords.html#ElementsThatEstablishViewports)), plus the
['[image](embedded.html#ImageElement)'],
['[marker](painting.html#MarkerElement)'],
['[pattern](pservers.html#PatternElement)'] and
['[view](linking.html#ViewElement)'] elements

In some cases, typically when using the
['[viewBox](coords.html#ViewBoxAttribute)'] attribute, it is
desirable that the graphics stretch to fit non-uniformly to take up the
entire SVG viewport. In other cases, it is desirable that uniform
scaling be used for the purposes of preserving the aspect ratio of the
graphics.

For elements that establish a new SVG viewport (see [elements that
establish SVG viewports](coords.html#ElementsThatEstablishViewports)),
plus the ['[marker](painting.html#MarkerElement)'],
['[pattern](pservers.html#PatternElement)'] and
['[view](linking.html#ViewElement)'] elements,
['[preserveAspectRatio](coords.html#PreserveAspectRatioAttribute)']
only applies when a value has been provided for
['[viewBox](coords.html#ViewBoxAttribute)'] on the same
element. For these elements, if attribute
['[viewBox](coords.html#ViewBoxAttribute)'] is not provided,
then
['[preserveAspectRatio](coords.html#PreserveAspectRatioAttribute)']
is ignored.

For ['[image](embedded.html#ImageElement)'] elements,
['[preserveAspectRatio](coords.html#PreserveAspectRatioAttribute)']
indicates how referenced images should be fitted with respect to the
reference rectangle and whether the aspect ratio of the referenced image
should be preserved with respect to the current user coordinate system.

The [\<align\>] parameter indicates whether to force
uniform scaling and, if so, the alignment method to use in case the
aspect ratio of the
['[viewBox](coords.html#ViewBoxAttribute)'] doesn\'t match
the aspect ratio of the SVG viewport. The [\<align\>]
parameter must be one of the following strings:

- [none] - Do not force uniform scaling. Scale the graphic
 content of the given element non-uniformly if necessary such that the
 element\'s bounding box exactly matches the SVG viewport rectangle.\
 (Note: if [\<align\>] is [none], then the
 optional [\<meetOrSlice\>] value is ignored.)
- [xMinYMin] - Force uniform scaling.\
 Align the [\<min-x\>] of the element\'s
 ['[viewBox](coords.html#ViewBoxAttribute)'] with the
 smallest X value of the SVG viewport.\
 Align the [\<min-y\>] of the element\'s
 ['[viewBox](coords.html#ViewBoxAttribute)'] with the
 smallest Y value of the SVG viewport.
- [xMidYMin] - Force uniform scaling.\
 Align the midpoint X value of the element\'s
 ['[viewBox](coords.html#ViewBoxAttribute)'] with the
 midpoint X value of the SVG viewport.\
 Align the [\<min-y\>] of the element\'s
 ['[viewBox](coords.html#ViewBoxAttribute)'] with the
 smallest Y value of the SVG viewport.
- [xMaxYMin] - Force uniform scaling.\
 Align the [\<min-x\>+\<width\>] of the element\'s
 ['[viewBox](coords.html#ViewBoxAttribute)'] with the
 maximum X value of the SVG viewport.\
 Align the [\<min-y\>] of the element\'s
 ['[viewBox](coords.html#ViewBoxAttribute)'] with the
 smallest Y value of the SVG viewport.
- [xMinYMid] - Force uniform scaling.\
 Align the [\<min-x\>] of the element\'s
 ['[viewBox](coords.html#ViewBoxAttribute)'] with the
 smallest X value of the SVG viewport.\
 Align the midpoint Y value of the element\'s
 ['[viewBox](coords.html#ViewBoxAttribute)'] with the
 midpoint Y value of the SVG viewport.
- [xMidYMid] (the [initial
 value](types.html#TermInitialValue)) - Force uniform scaling.\
 Align the midpoint X value of the element\'s
 ['[viewBox](coords.html#ViewBoxAttribute)'] with the
 midpoint X value of the SVG viewport.\
 Align the midpoint Y value of the element\'s
 ['[viewBox](coords.html#ViewBoxAttribute)'] with the
 midpoint Y value of the SVG viewport.
- [xMaxYMid] - Force uniform scaling.\
 Align the [\<min-x\>+\<width\>] of the element\'s
 ['[viewBox](coords.html#ViewBoxAttribute)'] with the
 maximum X value of the SVG viewport.\
 Align the midpoint Y value of the element\'s
 ['[viewBox](coords.html#ViewBoxAttribute)'] with the
 midpoint Y value of the SVG viewport.
- [xMinYMax] - Force uniform scaling.\
 Align the [\<min-x\>] of the element\'s
 ['[viewBox](coords.html#ViewBoxAttribute)'] with the
 smallest X value of the SVG viewport.\
 Align the [\<min-y\>+\<height\>] of the element\'s
 ['[viewBox](coords.html#ViewBoxAttribute)'] with the
 maximum Y value of the SVG viewport.
- [xMidYMax] - Force uniform scaling.\
 Align the midpoint X value of the element\'s
 ['[viewBox](coords.html#ViewBoxAttribute)'] with the
 midpoint X value of the SVG viewport.\
 Align the [\<min-y\>+\<height\>] of the element\'s
 ['[viewBox](coords.html#ViewBoxAttribute)'] with the
 maximum Y value of the SVG viewport.
- [xMaxYMax] - Force uniform scaling.\
 Align the [\<min-x\>+\<width\>] of the element\'s
 ['[viewBox](coords.html#ViewBoxAttribute)'] with the
 maximum X value of the SVG viewport.\
 Align the [\<min-y\>+\<height\>] of the element\'s
 ['[viewBox](coords.html#ViewBoxAttribute)'] with the
 maximum Y value of the SVG viewport.

The [\<meetOrSlice\>] parameter is optional and, if
provided, is separated from the [\<align\>] value by one or
more spaces and then must be one of the following strings:

- [meet] (the default) - Scale the graphic such that:

 - aspect ratio is preserved
 - the entire ['[viewBox](coords.html#ViewBoxAttribute)']
 is visible within the SVG viewport
 - the ['[viewBox](coords.html#ViewBoxAttribute)'] is
 scaled up as much as possible, while still meeting the other
 criteria

 In this case, if the aspect ratio of the graphic does not match the
 SVG viewport, some of the SVG viewport will extend beyond the bounds
 of the ['[viewBox](coords.html#ViewBoxAttribute)'] (i.e.,
 the area into which the
 ['[viewBox](coords.html#ViewBoxAttribute)'] will draw will
 be smaller than the SVG viewport).

- [slice] - Scale the graphic such that:

 - aspect ratio is preserved
 - the entire SVG viewport is covered by the
 ['[viewBox](coords.html#ViewBoxAttribute)']
 - the ['[viewBox](coords.html#ViewBoxAttribute)'] is
 scaled down as much as possible, while still meeting the other
 criteria

 In this case, if the aspect ratio of the
 ['[viewBox](coords.html#ViewBoxAttribute)'] does not match
 the SVG viewport, some of the
 ['[viewBox](coords.html#ViewBoxAttribute)'] will extend
 beyond the bounds of the SVG viewport (i.e., the area into which the
 ['[viewBox](coords.html#ViewBoxAttribute)'] will draw is
 larger than the SVG viewport).

[Example PreserveAspectRatio] illustrates the various
options on
['[preserveAspectRatio](coords.html#PreserveAspectRatioAttribute)'].
The example creates several new SVG viewports by including
['[svg](struct.html#SVGElement)'] sub-elements embedded
inside the [outermost svg element](struct.html#TermOutermostSVGElement)
(see [Establishing a new SVG
viewport](coords.html#EstablishingANewSVGViewport)).

 ﻿<svg width="450px" height="300px" xmlns="http://www.w3.org/2000/svg">

 <desc>Example PreserveAspectRatio - illustrates preserveAspectRatio attribute</desc>

 <style type="text/css">
 text { font-size: 9; }
 rect { fill: none; stroke: blue; }
 </style>

 <defs>
 <g id="smile">
 <rect x='.5' y='.5' width='29' height='39' style="fill:black;stroke:red"/>
 <circle cx='15' cy='20' r='10' fill='yellow'/>
 <circle cx='12' cy='17' r='1.5' fill='black'/>
 <circle cx='17' cy='17' r='1.5' fill='black'/>
 <path d='M 10 24 A 8 8 0 0 0 20 24' stroke='black' stroke-width='2'/>
 </g>
 </defs>

 <rect x="1" y="1" width="448" height="298"/>

 <text x="10" y="30">SVG to fit</text>
 <g transform="translate(20,40)"><use href="#smile" /></g>

 <text x="10" y="110">Viewport 1</text>
 <g transform="translate(10,120)"><rect x='.5' y='.5' width='49' height='29'/></g>

 <text x="10" y="180">Viewport 2</text>
 <g transform="translate(20,190)"><rect x='.5' y='.5' width='29' height='59'/></g>

 <g id="meet-group-1" transform="translate(100, 60)">
 <text x="0" y="-30">--------------- meet ---------------</text>
 <g>
 <text y="-10">xMin*</text>
 <rect x='.5' y='.5' width='49' height='29'/>
 <svg preserveAspectRatio="xMinYMin meet" viewBox="0 0 30 40" width="50" height="30">
 <use href="#smile" />
 </svg>
 </g>
 <g transform="translate(70,0)">
 <text y="-10">xMid*</text>
 <rect x='.5' y='.5' width='49' height='29'/>
 <svg preserveAspectRatio="xMidYMid meet" viewBox="0 0 30 40" width="50" height="30">
 <use href="#smile" />
 </svg>
 </g>
 <g transform="translate(0,70)">
 <text y="-10">xMax*</text>
 <rect x='.5' y='.5' width='49' height='29'/>
 <svg preserveAspectRatio="xMaxYMax meet" viewBox="0 0 30 40" width="50" height="30">
 <use href="#smile" />
 </svg>
 </g>
 </g>

 <g id="meet-group-2" transform="translate(250, 60)">
 <text x="0" y="-30">---------- meet ----------</text>
 <g>
 <text y="-10">*YMin</text>
 <rect x='.5' y='.5' width='29' height='59'/>
 <svg preserveAspectRatio="xMinYMin meet" viewBox="0 0 30 40" width="30" height="60">
 <use href="#smile" />
 </svg>
 </g>
 <g transform="translate(50, 0)">
 <text y="-10">*YMid</text>
 <rect x='.5' y='.5' width='29' height='59'/>
 <svg preserveAspectRatio="xMidYMid meet" viewBox="0 0 30 40" width="30" height="60">
 <use href="#smile" />
 </svg>
 </g>
 <g transform="translate(100, 0)">
 <text y="-10">*YMax</text>
 <rect x='.5' y='.5' width='29' height='59'/>
 <svg preserveAspectRatio="xMaxYMax meet" viewBox="0 0 30 40" width="30" height="60">
 <use href="#smile" />
 </svg>
 </g>
 </g>

 <g id="slice-group-1" transform="translate(100, 220)">
 <text x="0" y="-30">---------- slice ----------</text>
 <g>
 <text y="-10">xMin*</text>
 <rect x='.5' y='.5' width='29' height='59'/>
 <svg preserveAspectRatio="xMinYMin slice" viewBox="0 0 30 40" width="30" height="60">
 <use href="#smile" />
 </svg>
 </g>
 <g transform="translate(50,0)">
 <text y="-10">xMid*</text>
 <rect x='.5' y='.5' width='29' height='59'/>
 <svg preserveAspectRatio="xMidYMid slice" viewBox="0 0 30 40" width="30" height="60">
 <use href="#smile" />
 </svg>
 </g>
 <g transform="translate(100,0)">
 <text y="-10">xMax*</text>
 <rect x='.5' y='.5' width='29' height='59'/>
 <svg preserveAspectRatio="xMaxYMax slice" viewBox="0 0 30 40" width="30" height="60">
 <use href="#smile" />
 </svg>
 </g>
 </g>

 <g id="slice-group-2" transform="translate(250, 220)">
 <text x="0" y="-30">--------------- slice ---------------</text>
 <g>
 <text y="-10">*YMin</text>
 <rect x='.5' y='.5' width='49' height='29'/>
 <svg preserveAspectRatio="xMinYMin slice" viewBox="0 0 30 40"
 width="50" height="30">
 <use href="#smile" />
 </svg>
 </g>
 <g transform="translate(70,0)">
 <text y="-10">*YMid</text>
 <rect x='.5' y='.5' width='49' height='29'/>
 <svg preserveAspectRatio="xMidYMid slice" viewBox="0 0 30 40" width="50" height="30">
 <use href="#smile" />
 </svg>
 </g>
 <g transform="translate(140,0)">
 <text y="-10">*YMax</text>
 <rect x='.5' y='.5' width='49' height='29'/>
 <svg preserveAspectRatio="xMaxYMax slice" viewBox="0 0 30 40" width="50" height="30">
 <use href="#smile" />
 </svg>
 </g>
 </g>
 </svg>

![Example PreserveAspectRatio --- demonstrate available
options](images/coords/PreserveAspectRatio.png)

Example PreserveAspectRatio

## 8.8. Establishing a new SVG viewport
Including an ['[svg](struct.html#SVGElement)'] element
inside SVG content creates a new SVG viewport into which all contained
graphics are drawn; this implicitly establishes both a new viewport
coordinate system and a new user coordinate system. Additionally, there
is a new meaning for percentage units therein, because a new SVG
viewport has been established (see [Units](coords.html#Units)).

The bounds of the new SVG viewport are defined by the ['x'],
['y'], ['width'] and ['height']
attributes on the element establishing the new SVG viewport, such as an
['[svg](struct.html#SVGElement)'] element. Both the new
viewport coordinate system and the new user coordinate system have their
origins at (['x'], ['y']), where
['x'] and ['y'] represent the value of the
corresponding attributes on the element establishing the SVG viewport.
The orientation of the new viewport coordinate system and the new user
coordinate system correspond to the orientation of the current user
coordinate system for the element establishing the SVG viewport. A
single unit in the new viewport coordinate system and the new user
coordinate system are the same size as a single unit in the current user
coordinate system for the element establishing the SVG viewport.

Here is an example:

 <?xml version="1.0" standalone="no"?>
 <svg width="4in" height="3in"
 xmlns="http://www.w3.org/2000/svg">
 <desc>This SVG drawing embeds another one,
 thus establishing a new SVG viewport
 </desc>
 <!-- The following statement establishing a new SVG viewport
 and renders SVG drawing B into that SVG viewport -->
 <svg x="25%" y="25%" width="50%" height="50%">
 <!-- drawing B goes here -->
 </svg>
 </svg>

For an extensive example of creating new SVG viewports, see [Example
PreserveAspectRatio](coords.html#ExamplePreserveAspectRatio).

The following elements establish new SVG viewports:

- The ['[svg](struct.html#SVGElement)'] element
- A ['[symbol](struct.html#SymbolElement)'] element that
 is instanced by a ['[use](struct.html#UseElement)']
 element.

For historical reasons, the
['[pattern](pservers.html#PatternElement)'] and
['[marker](painting.html#MarkerElement)'] elements do not
create a new viewport, despite accepting a
['[viewBox](coords.html#ViewBoxAttribute)'] attribute.
Neither do the
['[clipPath](https://drafts.csswg.org/css-masking-1/#ClipPathElement)']
or
['[mask](https://drafts.csswg.org/css-masking-1/#MaskElement)']
elements. Percentage lengths within the content of these elements are
not proportional to the dimensions of the graphical effect region.

The
['[foreignObject](embedded.html#ForeignObjectElement)']
element establishes a new [CSS containing
block](https://www.w3.org/TR/css-position-3/#def-cb) for its child
content. This has some effects similar to a new viewport, resetting the
scope of layout for child content. However, in order to render SVG
elements that are descendents of
['[foreignObject](embedded.html#ForeignObjectElement)'],
a new ['[svg](struct.html#SVGElement)'] element must
establish an SVG document fragment and SVG viewport.

An ['[image](embedded.html#ImageElement)'] creates a new
[document viewport](https://www.w3.org/TR/css-position-3/#vp) for the
referenced document. If the referenced document is a SVG file, it will
of course establish its own SVG viewport.

Whether a new SVG viewport also establishes a new additional clipping
path is determined by the value of the
[overflow](render.html#OverflowAndClipProperties) property on
the element that establishes the new SVG viewport.

## 8.9. Units
SVG follows the description and definition of common values and units
from the CSS Values and Units Module
\[[css-values](refs.html#ref-css-values-3)\] for attributes,
presentation attributes and CSS properties. Each attribute and property
must specify the used component value type. Subsequent or extending
specifications published by the CSS WG or SVG WG may extend basic data
types or add new data types.

For [\<percentage\>](https://www.w3.org/TR/css3-values/#percentages)
values that are defined to be relative to the size of SVG viewport:

- For any x-coordinate value or width value expressed as a percentage of
 the [SVG viewport](coords.html#TermSVGViewport), the value to use must
 be the percentage, in user units, of the width parameter of the
 ['[viewBox](coords.html#ViewBoxAttribute)'] applied to
 that viewport. If no
 ['[viewBox](coords.html#ViewBoxAttribute)'] is specified,
 then the value to use must be the percentage, in user units, of the
 width of the [SVG viewport](coords.html#TermSVGViewport).
- For any y-coordinate value or height value expressed as a percentage
 of the [SVG viewport](coords.html#TermSVGViewport), the value to use
 must be the percentage, in user units, of the height parameter of the
 ['[viewBox](coords.html#ViewBoxAttribute)'] applied to
 that viewport. If no
 ['[viewBox](coords.html#ViewBoxAttribute)'] is specified,
 then the value to use must be the percentage, in user units, of the
 height of the [SVG viewport](coords.html#TermSVGViewport).
- [For any other length value expressed as a percentage of the [SVG
 viewport](coords.html#TermSVGViewport), the percentage must be
 calculated as a percentage of the normalized diagonal of the
 ['[viewBox](coords.html#ViewBoxAttribute)'] applied to
 that viewport. If no
 ['[viewBox](coords.html#ViewBoxAttribute)'] is specified,
 then the normalized diagonal of the [SVG
 viewport](coords.html#TermSVGViewport) must be used. The normalized
 diagonal length must be calculated with
 `sqrt((`*`width`*`)**2 + (`*`height`*`)**2)/sqrt(2)`.]

[Example Units] below illustrates some of the processing
rules for different types of units.

 <?xml version="1.0" standalone="no"?>
 <svg width="400px" height="200px" viewBox="0 0 4000 2000"
 xmlns="http://www.w3.org/2000/svg">
 <title>Example Units</title>
 <desc>Illustrates various units options</desc>

 <!-- Frame the picture -->
 <rect x="5" y="5" width="3990" height="1990"
 fill="none" stroke="blue" stroke-width="10"/>

 <g fill="blue" stroke="red" font-family="Verdana" font-size="150">
 <!-- Absolute unit specifiers -->
 <g transform="translate(400,0)">
 <text x="-50" y="300" fill="black" stroke="none">Abs. units:</text>
 <rect x="0" y="400" width="4in" height="2in" stroke-width=".4in"/>
 <rect x="0" y="750" width="384" height="192" stroke-width="38.4"/>
 <g transform="scale(2)">
 <rect x="0" y="600" width="4in" height="2in" stroke-width=".4in"/>
 </g>
 </g>

 <!-- Relative unit specifiers -->
 <g transform="translate(1600,0)">
 <text x="-50" y="300" fill="black" stroke="none">Rel. units:</text>
 <rect x="0" y="400" width="2.5em" height="1.25em" stroke-width=".25em"/>
 <rect x="0" y="750" width="375" height="187.5" stroke-width="37.5"/>
 <g transform="scale(2)">
 <rect x="0" y="600" width="2.5em" height="1.25em" stroke-width=".25em"/>
 </g>
 </g>

 <!-- Percentages -->
 <g transform="translate(2800,0)">
 <text x="-50" y="300" fill="black" stroke="none">Percentages:</text>
 <rect x="0" y="400" width="10%" height="10%" stroke-width="1%"/>
 <rect x="0" y="750" width="400" height="200" stroke-width="31.62"/>
 <g transform="scale(2)">
 <rect x="0" y="600" width="10%" height="10%" stroke-width="1%"/>
 </g>
 </g>
 </g>
 </svg>

![Example Units --- demonstrate available
options](images/coords/Units.png)

Example Units

The three rectangles on the left demonstrate the use of one of the
absolute unit identifiers, the \"in\" unit (inch). CSS defines 1 inch to
be equal to 96 pixels. Therefore, the topmost rectangle, which is
specified in inches, is exactly the same size as the middle rectangle,
which is specified in user units such that there are 96 user units for
each corresponding inch in the topmost rectangle. The bottom rectangle
of the group illustrates what happens when values specified in inches
are scaled.

The three rectangles in the middle demonstrate the use of one of the
relative unit identifiers, the \"em\" unit. Because the
[font-size](https://www.w3.org/TR/css-fonts-3/#font-size-prop)
property has been set to [150] on the outermost
['[g](struct.html#GElement)'] element, each \"em\" unit
is equal to 150 user units. The topmost rectangle, which is specified in
\"em\" units, is exactly the same size as the middle rectangle, which is
specified in user units such that there are 150 user units for each
corresponding \"em\" unit in the topmost rectangle. The bottom rectangle
of the group illustrates what happens when values specified in \"em\"
units are scaled.

The three rectangles on the right demonstrate the use of percentages.
Note that the width and height of the SVG viewport in the user
coordinate system for the SVG viewport element (in this case, the
[outermost svg element](struct.html#TermOutermostSVGElement)) are 4000
and 2000, respectively, because processing the
['[viewBox](coords.html#ViewBoxAttribute)'] attribute
results in a transformed user coordinate system. The topmost rectangle,
which is specified in percentage units, is exactly the same size as the
middle rectangle, which is specified in equivalent user units. In
particular, note that the
[stroke-width](painting.html#StrokeWidthProperty) property in
the middle rectangle is set to 1% of the
`sqrt((`*`actual-width`*`)**2 + (`*`actual-height`*`)**2) / sqrt(2)`,
which in this case is .01\*sqrt(4000\*4000+2000\*2000)/sqrt(2), or
31.62. The bottom rectangle of the group illustrates what happens when
values specified in percentage units are scaled.

## 8.10. Bounding boxes
[bounding box]

: The bounding box (or \"bbox\") of an element is the tightest fitting
 rectangle aligned with the axes of that element\'s user coordinate
 system that entirely encloses it and its descendants.

Three kinds of bounding boxes can be computed for an element:

1. The [object bounding box] is the bounding box that contains only an element\'s
 geometric shape. For [basic
 shapes](shapes.html#TermBasicShapeElement), this is the area that is
 filled. Unless otherwise specified, this is what is meant by the
 unqualified term \"bounding box\".
2. The [stroke bounding box] is the bounding box that contains an element\'s geometric
 shape and its [stroke shape](painting.html#TermStrokeShape).
3. The [decorated bounding box] is the bounding box that contains an
 element\'s geometric shape, its [stroke
 shape](painting.html#TermStrokeShape) and its
 [markers](painting.html#Markers).

Note that the values of the
[opacity](render.html#ObjectAndGroupOpacityProperties),
[visibility](render.html#VisibilityControl),
[fill](painting.html#FillProperty),
[fill-opacity](painting.html#FillOpacityProperty),
[fill-rule](painting.html#FillRuleProperty),
[stroke-dasharray](painting.html#StrokeDasharrayProperty) and
[stroke-dashoffset](painting.html#StrokeDashoffsetProperty)
properties on an element have no effect on the bounding box of an
element.

For curved shapes, the bounding box must enclose all portions of the
shape along the edge, not just end points. Note that control points for
a curve which are not defined as lying along the line of the resulting
curve (e.g., the second coordinate pair of a Cubic Bézier command) must
not contribute to the dimensions of the bounding box (though those
points may fall within the area of the bounding box, if they lie within
the shape itself, or along or close to the curve). For example, control
points of a curve that are at a further distance than the curve edge,
from the non-enclosing side of the curve edge, must be excluded from the
bounding box.

![Image showing the object bounding box of a quadratic Bézier
curve.](images/coords/bbox01.svg)

The path [\'M20,50 L35,100 H120 V50 Q70,10 20,50\'] is
shown in light blue. On the left, a correct object bounding box of the
path is shown. Note that it does not include the top-most control point
of the curve, but it does include all of the blue shape, even the parts
that lie outside of the convex hull of the control points.

Even if an element is not in the [rendering
tree](render.html#RenderingTree) -- due to it being [\'display:
none\'], within a
['[defs](struct.html#DefsElement)'] element, not usually
rendered like a ['[symbol](struct.html#SymbolElement)']
element or not currently present in the document tree -- it still has a
bounding box. A call to
[getBBox](types.html#__svg__SVGGraphicsElement__getBBox) on the element
will return the same rectangle as if the element were rendered. However,
an element that is not in the [rendering
tree](render.html#RenderingTree) does not contribute to the bounding box
of any ancestor element.

The following example defines a number of elements. The expected [object
bounding box](coords.html#TermObjectBoundingBox) for each element with
an ID is shown below.

 <svg xmlns="http://www.w3.org/2000/svg">

 <title>Bounding Box Calculation</title>
 <desc>Examples of elements with different bounding box results based on context.</desc>

 <defs id="defs-1">
 <rect id="rect-1" x="20" y="20" width="40" height="40" fill="blue" />
 </defs>

 <g id="group-1">
 <use id="use-1" href="#rect-1" x="10" y="10" />

 <g id="group-2" display="none">
 <rect id="rect-2" x="10" y="10" width="100" height="100" fill="red" />
 </g>
 </g>
 </svg>

 Element ID Bounding Box Result
 --------------- ---------------------
 \"`defs-1`\" {0, 0, 0, 0}
 \"`rect-1`\" {20, 20, 40, 40}
 \"`group-1`\" {30, 30, 40, 40}
 \"`use-1`\" {30, 30, 40, 40}
 \"`group-2`\" {10, 10, 100, 100}
 \"`rect-2`\" {10, 10, 100, 100}

For [text content elements](text.html#TermTextContentElement), for the
purposes of the bounding box calculation, each glyph must be treated as
a separate graphics element. The calculations must assume that all
glyphs occupy the [full glyph cell](coords.html#TermFullGlyphCell). [
The [full glyph cell]
must have width equal to the horizontal advance and height equal to the
EM box for horizontal text. For vertical text that is typeset sideways,
the [full glyph cell](coords.html#TermFullGlyphCell) must have width
equal to the EM box and height equal to the horizontal advance. For
other vertical text, the [full glyph
cell](coords.html#TermFullGlyphCell) must have width equal to the EM box
and height equal to the vertical advance, or height equal to the height
of the EM box if no vertical advance is defined in the font.
] For example, for horizontal text, the
calculations must assume that each glyph extends vertically to the full
ascent and descent values for the font.

Because declarative or scripted animation can change the shape, size,
and position of an element, the bounding box is mutable. Thus, the
bounding box for an element shall reflect the current values for the
element at the snapshot in time at which the bounding box is requested,
whether through a script call or as part of a declarative or linking
syntax.

An element which has zero width, zero height, or both (such as a
vertical or horizontal line, or a
['[rect](shapes.html#RectElement)'] element with a zero
[width](geometry.html#Sizing) or
[height](geometry.html#Sizing)) still has a bounding box,
with a positive value for the positive dimension, or with
[\'0\'] for both the width and height if no positive
dimension is specified. Similarly, subpaths segments of a
['[path](paths.html#PathElement)'] element with zero
width and height must be included in that element\'s geometry for the
sake of the bounding box.

An element with no position specified (such as a
['[path](paths.html#PathElement)'] element with a value
of [none] for the [d](paths.html#DProperty)
property) is positioned at the point (0,0) for the purposes of
calculating a bounding box.

Note that elements whose DOM object does not derive from
[SVGGraphicsElement](types.html#InterfaceSVGGraphicsElement)
(such as gradient elements) do not have a bounding box, and thus have no
interface to request a bounding box.

Elements in the [rendering tree](render.html#RenderingTree) which
reference unresolved resources shall still have a bounding box, defined
by the position and dimensions specified in their attributes, or by the
[initial value](types.html#TermInitialValue) for those attributes if no
values are supplied. For example, the element
`<use href="#bad" x="10" y="10"/>` would have a bounding box with an x
and y of 10 and a width and height of 0.

The following algorithm defines how to compute a bounding box for a
given element. The inputs to the algorithm are:

- `element`, the element we are computing a bounding box for;
- `space`, a coordinate space in which the bounding box will
 be computed;
- `fill`, a boolean indicating whether the bounding box
 includes the geometry of the element and its descendants;
- `stroke`, a boolean indicating whether the bounding box
 includes the stroke of the element and its descendants;
- `markers`, a boolean indicating whether the bounding box
 includes the markers of the element and its descendants; and
- `clipped`, a boolean indicating whether the bounding box is
 affected by any clipping paths applied to the element and its
 descendants.

The algorithm to compute the bounding box is as follows, depending on
the type of `element`:

a [shape](shapes.html#TermShapeElement)\
a [text content element](text.html#TermTextContentElement)\
an ['[a](linking.html#AElement)'] element within a [text content element](text.html#TermTextContentElement)

: 1. Let `box` be a rectangle initialized to (0, 0, 0, 0).

 2. Let `fill-shape` be the [equivalent
 path](paths.html#TermEquivalentPath) of `element` if
 it is a [shape](shapes.html#TermShapeElement), or a shape that
 includes each of the glyph cells corresponding to the text
 within the elements otherwise.

 3. If `fill` is true, then set `box` to the
 tightest rectangle in the coordinate system `space`
 that contains `fill-shape`.

 The values of the [fill](painting.html#FillProperty),
 [fill-opacity](painting.html#FillOpacityProperty) and
 [fill-rule](painting.html#FillRuleProperty)
 properties do not affect `fill-shape`.

 4. If `stroke` is true and the element\'s
 [stroke](painting.html#StrokeProperty) is anything
 other than [none], then set `box` to be
 the union of `box` and the tightest rectangle in
 coordinate system `space` that contains the [stroke
 shape](painting.html#StrokeShape) of the element, with the
 assumption that the element has no dash pattern.

 The values of the
 [stroke-opacity](painting.html#StrokeOpacityProperty),
 [stroke-dasharray](painting.html#StrokeDasharrayProperty)
 and
 [stroke-dashoffset](painting.html#StrokeDashoffsetProperty)
 do not affect the calculation of the stroke shape.

 5. If `markers` is true, then for each marker
 `marker` rendered on the element:
 1. For each descendant [graphics
 element](struct.html#TermGraphicsElement) `child`
 of the
 ['[marker](painting.html#MarkerElement)']
 element that defines `marker`\'s content:
 1. If `child` has an ancestor element within the
 ['[marker](painting.html#MarkerElement)']
 that is [\'display: none\'], has a failing
 [conditional processing
 attribute](struct.html#TermConditionalProcessingAttribute),
 or is not an
 ['[a](linking.html#AElement)'],
 ['[g](struct.html#GElement)'],
 ['[svg](struct.html#SVGElement)'] or
 ['[switch](struct.html#SwitchElement)']
 element, then continue to the next descendant [graphics
 element](struct.html#TermGraphicsElement).
 2. Otherwise, set `box` to be the union of
 `box` and the result of invoking the
 algorithm to compute a bounding box with
 `child` as the element, `space` as
 the target coordinate space, true for `fill`,
 `stroke` and `markers`, and
 `clipped` for `clipped`.

 6. If `clipped` is true and the value of
 [clip-path](https://drafts.csswg.org/css-masking-1/#the-clip-path)
 on `element` is not [none], then set
 `box` to be the tightest rectangle in coordinate
 system `space` that contains the intersection of
 `box` and the clipping path.

 7. Return `box`.

a [container element](struct.html#TermContainerElement)\
['[use](struct.html#UseElement)']

: 1. Let `box` be a rectangle initialized to (0, 0, 0, 0).
 2. Let `parent` be the [container
 element](struct.html#TermContainerElement) if it is one, or the
 root of the ['[use](struct.html#UseElement)']
 element\'s shadow tree otherwise.
 3. For each descendant [graphics
 element](struct.html#TermGraphicsElement) `child` of
 `parent`:
 1. If `child` is [not
 rendered](render.html#Rendered-vs-NonRendered) then continue
 to the next descendant [graphics
 element](struct.html#TermGraphicsElement).
 2. Otherwise, set `box` to be the union of
 `box` and the result of invoking the algorithm to
 compute a bounding box with `child` as the
 element and the same values for `space`,
 `fill`, `stroke`, `markers`
 and `clipped` as the corresponding algorithm
 input values.
 4. If `clipped` is true:
 - If the value of
 [clip-path](https://drafts.csswg.org/css-masking-1/#the-clip-path)
 on `element` is not [none], then set
 `box` to be the tightest rectangle in coordinate
 system `space` that contains the intersection of
 `box` and the clipping path.
 - If the
 [overflow](render.html#OverflowAndClipProperties)
 property applies to the `element` and does not have
 a value of [visible], then set `box`
 to be the tightest rectangle in coordinate system
 `space` that contains the intersection of
 `box` and the element\'s overflow bounds.
 - If the
 [clip](https://drafts.csswg.org/css-masking-1/#propdef-clip)
 property applies to the `element` and does not have
 a value of [auto], then set `box` to
 be the tightest rectangle in coordinate system
 `space` that contains the intersection of
 `box` and the rectangle specified by
 [clip](https://drafts.csswg.org/css-masking-1/#propdef-clip).
 5. Return `box`.

['[foreignObject](embedded.html#ForeignObjectElement)']\
['[image](embedded.html#ImageElement)']

: 1. Let `box` be the tightest rectangle in coordinate
 space `space` that contains the [positioning
 rectangle](embedded.html#TermPositioningRectangle) defined by
 the ['x'], ['y'], ['width']
 and ['height'] geometric properties of the element.

 The `fill`, `stroke` and
 `markers` input arguments to this algorithm do not
 affect the bounding box returned for these elements.

 2. If `clipped` is true and the value of
 [clip-path](https://drafts.csswg.org/css-masking-1/#the-clip-path)
 on `element` is not [none], then set
 `box` to be the tightest rectangle in coordinate
 system `space` that contains the intersection of
 `box` and the clipping path.

 3. Return `box`.

The union `box` with a value of (0, 0, 0, 0) and an empty
shape is `box`.

The [object bounding box](coords.html#TermObjectBoundingBox), [stroke
bounding box](coords.html#TermStrokeBoundingBox) or [decorated bounding
box](coords.html#TermDecoratedBoundingBox) of an element is the result
of invoking the bounding box computation algorithm above with the
following arguments: `element` is the element itself;
`space` is the element\'s user coordinate system;
`fill` is true; `stroke` is true if we are
computing the [stroke bounding box](coords.html#TermStrokeBoundingBox)
or [decorated bounding box](coords.html#TermDecoratedBoundingBox), and
false otherwise; `markers` is true if we are computing the
[decorated bounding box](coords.html#TermDecoratedBoundingBox), and
false otherwise; and `clipped` is false.

## 8.11. Object bounding box units
The following elements offer the option of expressing coordinate values
and lengths as fractions (and, in some cases, percentages) of the
[object bounding box](coords.html#TermObjectBoundingBox), by setting a
specified attribute to [\'objectBoundingBox\'] on the given
element:

 Element Attribute Effect
 ---------------------------------------------------------------------------------------- -------------------------------------------------------------------------------------------------------------------- ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 ['[linearGradient](pservers.html#LinearGradientElement)'] ['[gradientUnits](pservers.html#LinearGradientElementGradientUnitsAttribute)'] Indicates that the attributes which specify the gradient vector (['[x1](pservers.html#LinearGradientElementX1Attribute)'], ['[y1](pservers.html#LinearGradientElementY1Attribute)'], ['[x2](pservers.html#LinearGradientElementX2Attribute)'], ['[y2](pservers.html#LinearGradientElementY2Attribute)']) represent fractions or percentages of the bounding box of the element to which the gradient is applied.
 ['[radialGradient](pservers.html#RadialGradientElement)'] ['[gradientUnits](pservers.html#RadialGradientElementGradientUnitsAttribute)'] Indicates that the attributes which specify the center (['[cx](pservers.html#RadialGradientElementCXAttribute)'], ['[cy](pservers.html#RadialGradientElementCYAttribute)']), the radius (['[r](pservers.html#RadialGradientElementRAttribute)']) and focus (['[fx](pservers.html#RadialGradientElementFXAttribute)'], ['[fy](pservers.html#RadialGradientElementFYAttribute)']) represent fractions or percentages of the bounding box of the element to which the gradient is applied.
 ['[pattern](pservers.html#PatternElement)'] ['[patternUnits](pservers.html#PatternElementPatternUnitsAttribute)'] Indicates that the attributes which define how to tile the pattern (['[x](pservers.html#PatternElementXAttribute)'], ['[y](pservers.html#PatternElementYAttribute)'], ['[width](pservers.html#PatternElementWidthAttribute)'], ['[height](pservers.html#PatternElementHeightAttribute)']) are established using the bounding box of the element to which the pattern is applied.
 ['[pattern](pservers.html#PatternElement)'] ['[patternContentUnits](pservers.html#PatternElementPatternContentUnitsAttribute)'] Indicates that the user coordinate system for the contents of the pattern is established using the bounding box of the element to which the pattern is applied.
 ['[clipPath](https://drafts.csswg.org/css-masking-1/#ClipPathElement)'] ['[clipPathUnits](https://drafts.csswg.org/css-masking-1/#element-attrdef-clippath-clippathunits)'] Indicates that the user coordinate system for the contents of the ['[clipPath](https://drafts.csswg.org/css-masking-1/#ClipPathElement)'] element is established using the bounding box of the element to which the clipping path is applied.
 ['[mask](https://drafts.csswg.org/css-masking-1/#MaskElement)'] ['[maskUnits](https://drafts.csswg.org/css-masking-1/#element-attrdef-mask-maskunits)'] Indicates that the attributes which define the masking region (['[x](https://drafts.csswg.org/css-masking-1/#element-attrdef-mask-x)'], ['[y](https://drafts.csswg.org/css-masking-1/#element-attrdef-mask-y)'], ['[width](https://drafts.csswg.org/css-masking-1/#element-attrdef-mask-width)'], ['[height](https://drafts.csswg.org/css-masking-1/#element-attrdef-mask-height)']) is established using the bounding box of the element to which the mask is applied.
 ['[mask](https://drafts.csswg.org/css-masking-1/#MaskElement)'] ['[maskContentUnits](https://drafts.csswg.org/css-masking-1/#element-attrdef-mask-maskcontentunits)'] Indicates that the user coordinate system for the contents of the ['[mask](https://drafts.csswg.org/css-masking-1/#MaskElement)'] element are established using the bounding box of the element to which the mask is applied.
 ['[filter](https://drafts.csswg.org/filter-effects-1/#FilterElement)'] ['[filterUnits](https://drafts.csswg.org/filter-effects-1/#element-attrdef-filter-filterunits)'] Indicates that the attributes which define the [filter effects region](https://drafts.csswg.org/filter-effects-1/#FilterPrimitiveSubRegion) (['[x](https://drafts.csswg.org/filter-effects-1/#element-attrdef-filter-x)'], ['[y](https://drafts.csswg.org/filter-effects-1/#element-attrdef-filter-y)'], ['[width](https://drafts.csswg.org/filter-effects-1/#element-attrdef-filter-width)'], ['[height](https://drafts.csswg.org/filter-effects-1/#element-attrdef-filter-height)']) represent fractions or percentages of the bounding box of the element to which the filter is applied.
 ['[filter](https://drafts.csswg.org/filter-effects-1/#FilterElement)'] ['[primitiveUnits](https://drafts.csswg.org/filter-effects-1/#element-attrdef-filter-primitiveunits)'] Indicates that the various length values within the filter primitives represent fractions or percentages of the bounding box of the element to which the filter is applied.

In the discussion that follows, the term *applicable element* is the
element to which the given effect applies. For gradients and patterns,
the applicable element is the [graphics
element](struct.html#TermGraphicsElement) which has its
[fill](painting.html#FillProperty) or
[stroke](painting.html#StrokeProperty) property referencing
the given gradient or pattern. (For special rules concerning [text
elements](text.html), see the discussion of [object bounding box units
and text elements](text.html#ObjectBoundingBoxUnitsTextObjects).) For
clipping paths, masks and filters, the applicable element can be either
a [container element](struct.html#TermContainerElement) or a [graphics
element](struct.html#TermGraphicsElement).

When keyword [objectBoundingBox] is used, then the effect
is as if a supplemental transformation matrix were inserted into the
list of nested transformation matrices to create a new user coordinate
system.

First, the (**minx**,**miny**) and (**maxx**,**maxy**) coordinates are
determined by the extends of the [object bounding
box](coords.html#TermObjectBoundingBox) of the applicable element.

Then, coordinate (0,0) in the new user coordinate system is mapped to
the (minx,miny) corner of the tight bounding box within the user
coordinate system of the applicable element and coordinate (1,1) in the
new user coordinate system is mapped to the (maxx,maxy) corner of the
tight bounding box of the applicable element. In most situations, the
following transformation matrix produces the correct effect:

 [ (maxx-minx) 0 0 (maxy-miny) minx miny ]

When percentages are used with attributes that define the gradient
vector, the pattern tile, the filter region or the masking region, a
percentage represents the same value as the corresponding decimal value
(e.g., 50% means the same as 0.5). If percentages are used within the
content of a ['[pattern](pservers.html#PatternElement)'],
['[clipPath](https://drafts.csswg.org/css-masking-1/#ClipPathElement)'],
['[mask](https://drafts.csswg.org/css-masking-1/#MaskElement)']
or
['[filter](https://drafts.csswg.org/filter-effects-1/#FilterElement)']
element, these values are treated according to the processing rules for
percentages as defined in [Units](coords.html#Units).

Any numeric value can be specified for values expressed as a fraction or
percentage of object bounding box units. In particular, fractions less
than zero or greater than one and percentages less than 0% or greater
than 100% can be specified.

Keyword [objectBoundingBox] should not be used when the
geometry of the applicable element has no width or no height, such as
the case of a horizontal or vertical line, even when the line has actual
thickness when viewed due to having a non-zero stroke width since stroke
width is ignored for bounding box calculations. When the geometry of the
applicable element has no width or height and
[objectBoundingBox] is specified, then the given effect
(e.g., a gradient or a filter) will be ignored.

::: ready-for-wider-review
## 8.12. Intrinsic sizing properties of SVG content
To enable inclusion of SVG in host documents formatted with CSS, a
[concrete object
size](https://www.w3.org/TR/css3-images#concrete-object-size) must be
calculated. The [concrete object
size](https://www.w3.org/TR/css3-images#concrete-object-size) must be
calculated using the [Default Sizing
Algorithm](https://www.w3.org/TR/css3-images/#default-sizing-algorithm)
defined in CSS Images 3 \[[css-images-3](refs.html#ref-css-images-3)\],
with the following inputs:

The [specified size](https://www.w3.org/TR/css3-images#specified-size)
must be determined from the used values for the
[width](geometry.html#Sizing) and
[height](geometry.html#Sizing) sizing properties of the
['[svg](struct.html#SVGElement)'] element.

The [intrinsic
dimensions](https://www.w3.org/TR/css3-images#intrinsic-dimensions) must
also be determined from the [width](geometry.html#Sizing) and
[height](geometry.html#Sizing) sizing properties. If either
[width](geometry.html#Sizing) or
[height](geometry.html#Sizing) are not specified, the used
value is the initial value [\'auto\'].
[\'auto\'] and percentage lengths must not be used to
determine an [intrinsic
width](https://www.w3.org/TR/css3-images#intrinsic-width) or [intrinsic
height](https://www.w3.org/TR/css3-images#intrinsic-height).

With bitmap image formats, the [intrinsic
dimensions](https://www.w3.org/TR/css3-images#intrinsic-dimensions) are
fixed in the image file, and the specified size is defined in the host
document as needed to scale the image. SVG, being inherently scalable,
adapts the [intrinsic
width](https://www.w3.org/TR/css3-images#intrinsic-width) and [intrinsic
height](https://www.w3.org/TR/css3-images#intrinsic-height) to be the
width and height of the [specified
size](https://www.w3.org/TR/css3-images#specified-size). Therefore, when
specified as a length, the [width](geometry.html#Sizing) and
[height](geometry.html#Sizing) sizing properties of the
['[svg](struct.html#SVGElement)'] element control the
[intrinsic
dimensions](https://www.w3.org/TR/css3-images#intrinsic-dimensions) of
the SVG image and the [specified
size](https://www.w3.org/TR/css3-images#specified-size) that is used
when placing the SVG image in a host document.

The [intrinsic aspect
ratio](https://www.w3.org/TR/css3-images#intrinsic-aspect-ratio) must be
calculated using the following algorithm. If the algorithm returns null,
then there is no intrinsic aspect ratio.

1. If the [width](geometry.html#Sizing) and
 [height](geometry.html#Sizing) sizing properties on the
 ['[svg](struct.html#SVGElement)'] element are both
 absolute values:
 1. return width / height
2. If an [SVG View](linking.html#LinksIntoSVG) is active:
 1. let `viewbox` be the viewbox defined by the active
 SVG View
 2. return `viewbox`.width / `viewbox`.height
3. If the ['[viewBox](coords.html#ViewBoxAttribute)'] on
 the ['[svg](struct.html#SVGElement)'] element is
 correctly specified:
 1. let `viewbox` be the viewbox defined by the
 ['[viewBox](coords.html#ViewBoxAttribute)']
 attribute on the
 ['[svg](struct.html#SVGElement)'] element
 2. return `viewbox`.width / `viewbox`.height
4. return null

The behaviour defined in this section is specific to CSS, but may be
adapted to other host contexts. In all host contexts, the [intrinsic
aspect ratio](https://www.w3.org/TR/css3-images#intrinsic-aspect-ratio),
where available, must be respected when sizing the SVG viewport.

Examples:

**Example:** Intrinsic Aspect Ratio 1

 <svg xmlns="http://www.w3.org/2000/svg"
 width="10cm" height="5cm">
 ...
 </svg>

In this example the intrinsic aspect ratio of the [SVG
viewport](coords.html#TermSVGViewport) is 2:1. The intrinsic width is
10cm and the intrinsic height is 5cm.

**Example:** Intrinsic Aspect Ratio 2

 <svg xmlns="http://www.w3.org/2000/svg"
 width="100%" height="50%" viewBox="0 0 200 200">
 ...
 </svg>

In this example the intrinsic aspect ratio of the outermost [SVG
viewport](coords.html#TermSVGViewport) is 1:1. An aspect ratio
calculation in this case allows embedding in an object within a
containing block that is only constrained in one direction.

**Example:** Intrinsic Aspect Ratio 3

 <svg xmlns="http://www.w3.org/2000/svg"
 width="10cm" viewBox="0 0 200 200">
 ...
 </svg>

In this case the intrinsic aspect ratio is 1:1.

**Example:** Intrinsic Aspect Ratio 4

 <svg xmlns="http://www.w3.org/2000/svg"
 width="75%" height="10cm" viewBox="0 0 200 200">
 ...
 </svg>

In this example, the intrinsic aspect ratio is 1:1.

Add more examples for the new auto value? E.g.
some of the
[examples](https://docs.google.com/presentation/d/1POUiroOBbLmXYlQKf0pIR8zVkHWH9jRVN-w8A4aNsIk/)
provided by David Vest.

## 8.13. Vector effects
 -------------------- -------------------------------------------------------------------------------------------------------------------------------------------------------------------
 SVG 2 Requirement: [SVG 2 will have constrained transformations based on SVG 1.2 Tiny.](https://www.w3.org/Graphics/SVG/WG/wiki/SVG2_Requirements_Input#Constrained_Transformations)
 Resolution: [Add vector effects extension proposal to SVG 2 specification.](https://www.w3.org/2014/04/09-svg-minutes.html#item06)
 Purpose: To include non-scaling features (non-scaling part of the object, and non-scaling entire object
 Owner: Satoru Takagi ([ACTION-3619](https://www.w3.org/Graphics/SVG/WG/track/actions/3619))
 -------------------- -------------------------------------------------------------------------------------------------------------------------------------------------------------------

Sometimes it is of interest to let the outline of an object keep its
original width or to let the position of an object fix no matter which
transforms are applied to it. For example, in a map with a 2px wide line
representing roads it is of interest to keep the roads 2px wide even
when the user zooms into the map, or introductory notes on the graphic
chart in which panning is possible.

To offer such effects regarding special coordinate transformations and
graphic drawings, SVG Tiny 1.2 introduced the
[vector-effect](coords.html#VectorEffectProperty) property.
Although SVG Tiny 1.2 introduced only non-scaling stroke behavior, this
version introduces a number of additional effects. Furthermore, since
these effects can be specified in combination, they show more various
effects. And, future versions of the SVG language will allow for more
powerful vector effects through this property.

Values of
[vector-effect](coords.html#VectorEffectProperty) other than
[non-scaling-stroke] and [none] are at risk of
being dropped from SVG 2 due to a lack of implementations. Feedback from
implementers is requested, regarding the practicality of implementing
them as currently specified, during the implementation period.

 --------------------------------------------------------------------------- -----------------------------------------------------------------------------------------------------------
 Name: [vector-effect]
 Value: none \| non-scaling-stroke \| non-scaling-size \| non-rotation \| fixed-position
 Initial: none
 Applies to: [graphics elements](struct.html#TermGraphicsElement) and ['[use](struct.html#UseElement)']
 Inherited: no
 Percentages: N/A
 Media: visual
 Computed value: as specified
 [Animation type](https://www.w3.org/TR/web-animations-1/#animation-type): discrete
 --------------------------------------------------------------------------- -----------------------------------------------------------------------------------------------------------

none
: Specifies that no vector effect shall be applied, i.e. the default
 rendering behaviour from SVG 1.1 is used which is to first fill the
 geometry of a shape with a specified paint, then stroke the outline
 with a specified paint.

non-scaling-stroke
: Please refer to [this description](painting.html#non-scaling-stroke)
 of vector effect on painting.

non-scaling-size
: Specifies special [user coordinate
 system](https://drafts.csswg.org/css-transforms/#user-coordinate-system)
 toward this element and its descendant by constrained
 transformations with the following characteristics. The scale of the
 [user coordinate
 system](https://drafts.csswg.org/css-transforms/#user-coordinate-system)
 do not change in spite of change of
 [CTM](https://www.w3.org/TR/css-transforms-1/#current-transformation-matrix)s
 from a `host coordinate space`. However, it does not
 specify the suppression of rotation and skew. Also, it does not
 specify the fixation of placement of [user coordinate
 system](https://drafts.csswg.org/css-transforms/#user-coordinate-system).
 Since non-scaling-size suppresses scaling of [user coordinate
 system](https://drafts.csswg.org/css-transforms/#user-coordinate-system),
 it also has the characteristic of non-scaling-stroke. The
 transformation formula and the example behavior are indicated to the
 following chapter.

non-rotation
: Specifies special [user coordinate
 system](https://drafts.csswg.org/css-transforms/#user-coordinate-system)
 toward this element and its descendant by constrained
 transformations with the following characteristics. The rotation and
 skew of the [user coordinate
 system](https://drafts.csswg.org/css-transforms/#user-coordinate-system)
 is suppressed in spite of change of
 [CTM](https://www.w3.org/TR/css-transforms-1/#current-transformation-matrix)s
 from a `host coordinate space`. However, it does not
 specify the suppression of scaling. Also, it does not specify the
 fixation of placement of [user coordinate
 system](https://drafts.csswg.org/css-transforms/#user-coordinate-system).
 The transformation formula and the example behavior are indicated to
 the following chapter.

fixed-position
: Specifies special [user coordinate
 system](https://drafts.csswg.org/css-transforms/#user-coordinate-system)
 toward this element and its descendant by constrained
 transformations with the following characteristics. The placement of
 [user coordinate
 system](https://drafts.csswg.org/css-transforms/#user-coordinate-system)
 is fixed in spite of change of
 [CTM](https://www.w3.org/TR/css-transforms-1/#current-transformation-matrix)s
 from a `host coordinate space`. However, it does not
 specify the suppression of rotation, skew and scaling. When the
 element that has fixed-position effect and also has
 [transform](coords.html#TransformProperty) property, that
 property is consumed for this effect. The shift components
 `e` and `f` of matrix of
 [transform](coords.html#TransformProperty) property are
 used to transfer the origin of fixed [user coordinate
 system](https://drafts.csswg.org/css-transforms/#user-coordinate-system).
 The transformation formula and the example behavior are indicated to
 the following chapter.

These values can be enumerated. Thereby, the effect which has these
characteristics simultaneously can be specified.

The host coordinate space for
[vector-effect](coords.html#VectorEffectProperty) is the
[viewport coordinate system](coords.html#TermViewportCoordinateSystem)
of the [furthest ancestral SVG
viewport](coords.html#TermFurthestAncestorSVGViewport).

Note: Future versions of SVG may allow ways to specify the device
coordinate system.

### 8.13.1. Computing the vector effects
This section shows the list of transformation formulas regarding
combinations of the values for clarification of the behavior of vector
effects excluding [non-scaling-stroke] which has clear
implications.

The [vector-effect](coords.html#VectorEffectProperty)
property has no effect on transformations performed in a [3d rendering
context](https://drafts.csswg.org/css-transforms-2/#3d-rendering-contexts).

The normal coordinate transformation formula from [user coordinate
system](https://drafts.csswg.org/css-transforms/#user-coordinate-system)
to [viewport coordinate
system](coords.html#TermViewportCoordinateSystem) is as follows.

$$\begin{array}{l}
{\left\lbrack \begin{array}{l}
x_{viewport} \\
y_{viewport} \\
1
\end{array} \right\rbrack = \text{CTM} \cdot \left\lbrack \begin{array}{l}
x_{userspace} \\
y_{userspace} \\
1
\end{array} \right\rbrack} \\
{\text{CTM} = \left\lbrack \begin{array}{lll}
a_{ctm} & c_{ctm} & e_{ctm} \\
b_{ctm} & d_{ctm} & f_{ctm} \\
0 & 0 & 1
\end{array} \right\rbrack}
\end{array}$$

``` xml

<circle vector-effect="veValue" transform="translate(xo yo)" cx="xf" cy="yf" r=".."/>
```

When the [vector-effect](coords.html#VectorEffectProperty) is
added to an element like the above, the transformation formula for user
coordinate to the device coordinate changes as follows. Here,
`x`~`f`~ and `y`~`f`~ are
user coordinate of the corresponding element and its descendant. And,
`x`~`o`~ and `y`~`o`~ are
matrix element `e` and `f` of the transform
attribute which the corresponding element has. In addition,
**\|det(CTM)\|** is absolute value of the determinants of
[CTM](https://www.w3.org/TR/css-transforms-1/#current-transformation-matrix).
When this value becomes 0 and [non-scaling-size] is
appointed, [vector-effect](coords.html#VectorEffectProperty)
becomes invalidity namely [none].

$${\text{det}\left( \text{CTM} \right)} = a_{ctm} \cdot d_{ctm} - b_{ctm} \cdot c_{ctm}$$

+-----------------------------------+----------------------------------------------------------------------------------------------------------------------+
| veValue | Formula |
+===================================+======================================================================================================================+
| [non-scaling-size] | ::: |
| | $$\begin{bmatrix} |
| | x_{viewport} \\ |
| | y_{viewport} \\ |
| | 1 |
| | \end{bmatrix} = {\text{CTM} \cdot \begin{bmatrix} |
| | \text{0} \\ |
| | \text{0} \\ |
| | 1 |
| | \end{bmatrix} + \frac{\text{CTM}}{\sqrt{\left| {\text{det}\left( \text{CTM} \right)} \right|}} \cdot \begin{bmatrix} |
| | 1 & 0 & 0 \\ |
| | 0 & 1 & 0 \\ |
| | 0 & 0 & 0 |
| | \end{bmatrix} \cdot \begin{bmatrix} |
| | x_{f} \\ |
| | y_{f} \\ |
| | 1 |
| | \end{bmatrix}}$$ |
| | ::: |
+-----------------------------------+----------------------------------------------------------------------------------------------------------------------+
| [non-rotation] | ::: |
| | $$\begin{bmatrix} |
| | x_{viewport} \\ |
| | y_{viewport} \\ |
| | 1 |
| | \end{bmatrix} = {\text{CTM} \cdot \begin{bmatrix} |
| | \text{0} \\ |
| | \text{0} \\ |
| | 1 |
| | \end{bmatrix} + \sqrt{\left| {\text{det}\left( \text{CTM} \right)} \right|} \cdot \begin{bmatrix} |
| | 1 & 0 & 0 \\ |
| | 0 & 1 & 0 \\ |
| | 0 & 0 & 0 |
| | \end{bmatrix} \cdot \begin{bmatrix} |
| | x_{f} \\ |
| | y_{f} \\ |
| | 1 |
| | \end{bmatrix}}$$ |
| | ::: |
+-----------------------------------+----------------------------------------------------------------------------------------------------------------------+
| [non-scaling-size] | ::: |
| [non-rotation] | $$\begin{bmatrix} |
| | x_{viewport} \\ |
| | y_{viewport} \\ |
| | 1 |
| | \end{bmatrix} = {\text{CTM} \cdot \begin{bmatrix} |
| | \text{0} \\ |
| | \text{0} \\ |
| | 1 |
| | \end{bmatrix} + \begin{bmatrix} |
| | 1 & 0 & 0 \\ |
| | 0 & 1 & 0 \\ |
| | 0 & 0 & 0 |
| | \end{bmatrix} \cdot \begin{bmatrix} |
| | x_{f} \\ |
| | y_{f} \\ |
| | 1 |
| | \end{bmatrix}}$$ |
| | ::: |
+-----------------------------------+----------------------------------------------------------------------------------------------------------------------+
| [fixed-position] | ::: |
| | $$\begin{bmatrix} |
| | x_{viewport} \\ |
| | y_{viewport} \\ |
| | 1 |
| | \end{bmatrix} = {\begin{bmatrix} |
| | x_{o} \\ |
| | y_{o} \\ |
| | 1 |
| | \end{bmatrix} + \text{CTM} \cdot \begin{bmatrix} |
| | 1 & 0 & 0 \\ |
| | 0 & 1 & 0 \\ |
| | 0 & 0 & 0 |
| | \end{bmatrix} \cdot \begin{bmatrix} |
| | x_{f} \\ |
| | y_{f} \\ |
| | 1 |
| | \end{bmatrix}}$$ |
| | ::: |
+-----------------------------------+----------------------------------------------------------------------------------------------------------------------+
| [fixed-position] | ::: |
| [non-scaling-size] | $$\begin{bmatrix} |
| | x_{viewport} \\ |
| | y_{viewport} \\ |
| | 1 |
| | \end{bmatrix} = {\begin{bmatrix} |
| | x_{o} \\ |
| | y_{o} \\ |
| | 1 |
| | \end{bmatrix} + \frac{\text{CTM}}{\sqrt{\left| {\text{det}\left( \text{CTM} \right)} \right|}} \cdot \begin{bmatrix} |
| | 1 & 0 & 0 \\ |
| | 0 & 1 & 0 \\ |
| | 0 & 0 & 0 |
| | \end{bmatrix} \cdot \begin{bmatrix} |
| | x_{f} \\ |
| | y_{f} \\ |
| | 1 |
| | \end{bmatrix}}$$ |
| | ::: |
+-----------------------------------+----------------------------------------------------------------------------------------------------------------------+
| [fixed-position] | ::: |
| [non-rotation] | $$\begin{bmatrix} |
| | x_{viewport} \\ |
| | y_{viewport} \\ |
| | 1 |
| | \end{bmatrix} = {\begin{bmatrix} |
| | x_{o} \\ |
| | y_{o} \\ |
| | 1 |
| | \end{bmatrix} + \sqrt{\left| {\text{det}\left( \text{CTM} \right)} \right|} \cdot \begin{bmatrix} |
| | 1 & 0 & 0 \\ |
| | 0 & 1 & 0 \\ |
| | 0 & 0 & 0 |
| | \end{bmatrix} \cdot \begin{bmatrix} |
| | x_{f} \\ |
| | y_{f} \\ |
| | 1 |
| | \end{bmatrix}}$$ |
| | ::: |
+-----------------------------------+----------------------------------------------------------------------------------------------------------------------+
| [fixed-position] | ::: |
| [non-scaling-size] | $$\begin{bmatrix} |
| [non-rotation] | x_{viewport} \\ |
| | y_{viewport} \\ |
| | 1 |
| | \end{bmatrix} = {\begin{bmatrix} |
| | x_{o} \\ |
| | y_{o} \\ |
| | 1 |
| | \end{bmatrix} + \begin{bmatrix} |
| | 1 & 0 & 0 \\ |
| | 0 & 1 & 0 \\ |
| | 0 & 0 & 0 |
| | \end{bmatrix} \cdot \begin{bmatrix} |
| | x_{f} \\ |
| | y_{f} \\ |
| | 1 |
| | \end{bmatrix}}$$ |
| | ::: |
+-----------------------------------+----------------------------------------------------------------------------------------------------------------------+

### 8.13.2. Computing the vector effects for nested viewport coordinate systems
Below is normal coordinate transformation formula for nested viewport
coordinate systems without vector effects. **x~viewport(UA)~** and
**y~viewport(UA)~** are coordinates which under the immediate control of
[user agent](conform.html#TermUserAgent). **CTM~this~** is
[CTM](https://www.w3.org/TR/css-transforms-1/#current-transformation-matrix)
for the transformation matrix from [user coordinate
system](https://drafts.csswg.org/css-transforms/#user-coordinate-system)
of an target graphic to [viewport coordinate
system](coords.html#TermViewportCoordinateSystem) to which it belongs.
**CTM~parent~** is
[CTM](https://www.w3.org/TR/css-transforms-1/#current-transformation-matrix)
for the transformation matrix from aforementioned [viewport coordinate
system](coords.html#TermViewportCoordinateSystem) to [viewport
coordinate system](coords.html#TermViewportCoordinateSystem) of the
parent of that. And, **CTM~root~** is
[CTM](https://www.w3.org/TR/css-transforms-1/#current-transformation-matrix)
for rootmost viewport coordinate system (UA).

$$\begin{bmatrix}
x_{viewport(UA)} \\
y_{viewport(UA)} \\
1
\end{bmatrix} = \text{CTM}_{root} \cdot \text \cdot \text{CTM}_{parent} \cdot \text{CTM}_{this} \cdot \begin{bmatrix}
x_{userspace} \\
y_{userspace} \\
1
\end{bmatrix}$$

When applying seven formulas of the preceding section to nested viewport
coordinate systems, the application way of those formulas changes as
follows by whether [viewport] or [screen] is
specified as the additional value of
[vector-effect](coords.html#VectorEffectProperty).

When [viewport] value is specified, [user
agent](conform.html#TermUserAgent) computes coordinates combining either
of seven formulas of the preceding chapter, and the following formulas.

$$\begin{array}{l}
{\left\lbrack \begin{array}{l}
x_{{viewport}({UA})} \\
y_{{viewport}({UA})} \\
1
\end{array} \right\rbrack = \text{CTM}_{\text{root}} \cdot \text \cdot \text{CTM}_{\text{parent}} \cdot \left\lbrack \begin{array}{l}
x_{viewport} \\
y_{viewport} \\
1
\end{array} \right\rbrack} \\
{\text{CTM} = \text{CTM}_{\text{this}}}
\end{array}$$

When [screen] value is specified, [user
agent](conform.html#TermUserAgent) computes coordinates combining either
of seven formulas of the preceding chapter, and the following formulas.

$$\begin{array}{l}
{\left\lbrack \begin{array}{l}
x_{{viewport}({UA})} \\
y_{{viewport}({UA})} \\
1
\end{array} \right\rbrack = \left\lbrack \begin{array}{l}
x_{viewport} \\
y_{viewport} \\
1
\end{array} \right\rbrack} \\
{\text{CTM} = \text{CTM}_{\text{root}} \cdot \text \cdot \text{CTM}_{\text{parent}} \cdot \text{CTM}_{\text{this}}}
\end{array}$$

### 8.13.3. Examples of vector effects
Below is an example of the [non-scaling-stroke]
[vector-effect](coords.html#VectorEffectProperty).

 <?xml version="1.0"?>
 <svg xmlns="http://www.w3.org/2000/svg"
 width="6cm" height="4cm" viewBox="0 0 600 400"
 viewport-fill="rgb(255,150,200)">

 <desc>Example non-scaling stroke</desc>
 <rect x="1" y="1" width="598" height="398" fill="none" stroke="black"/>

 <g transform="scale(9,1)">
 <line stroke="black" stroke-width="5" x1="10" y1="50" x2="10" y2="350"/>
 <line vector-effect="non-scaling-stroke" stroke="black" stroke-width="5"
 x1="32" y1="50" x2="32" y2="350"/>
 <line vector-effect="none" stroke="black" stroke-width="5"
 x1="55" y1="50" x2="55" y2="350"/>
 </g>

 </svg>

Below is an example of the [none]
[vector-effect](coords.html#VectorEffectProperty) (no vector
effect).

 ---------------------------------------------------------------------------------------------- -------------------------------------------------------------------------------------------
 Before changing CTM After changing CTM
 ![Image showing none vector effect](images/painting/vectorEffects/ve-initial.svg) ![Image showing none vector effect](images/painting/vectorEffects/ve-none.svg)
 ---------------------------------------------------------------------------------------------- -------------------------------------------------------------------------------------------

Source code

 <svg xmlns="http://www.w3.org/2000/svg" viewBox="-50,-50,500,500" height="500" width="500">

 <rect x="-50" y="-50" width="500" height="500" stroke="orange" stroke-width="3" fill="none"/>

 <!-- Nested user coordinate system is transformed by this transform attribute -->
 <g transform="matrix(2.1169438081370817,0.3576047954311102,-0.3576047954311102,1.4700998667618626,0,0)
 translate(-50,-50)">
 <svg viewBox="-50,-50,500,500" height="500" width="500">
 <!-- Graph paper on the this svg's base user coordinate system -->
 <g stroke="green" stroke-width="1" fill="none">
 <circle cx="0" cy="0" r="10"/>
 <circle cx="150" cy="150" r="7"/>
 <path fill="green" stroke="none" d="M0,-3 L30,-3 25,-10 50,0 25,10 30,3 0,3z"/>

 <line x1="-100" y1="-100" x2="600" y2="-100" stroke-dasharray="5,5"/>
 <line x1="-100" y1="000" x2="600" y2="000"/>
 <line x1="-100" y1="100" x2="600" y2="100" stroke-dasharray="5,5"/>
 <line x1="-100" y1="200" x2="600" y2="200" stroke-dasharray="5,5"/>
 <line x1="-100" y1="300" x2="600" y2="300" stroke-dasharray="5,5"/>
 <line x1="-100" y1="400" x2="600" y2="400" stroke-dasharray="5,5"/>
 <line x1="-100" y1="500" x2="600" y2="500" stroke-dasharray="5,5"/>

 <line y1="-100" x1="-100" y2="600" x2="-100" stroke-dasharray="5,5"/>
 <line y1="-100" x1="000" y2="600" x2="000"/>
 <line y1="-100" x1="100" y2="600" x2="100" stroke-dasharray="5,5"/>
 <line y1="-100" x1="200" y2="600" x2="200" stroke-dasharray="5,5"/>
 <line y1="-100" x1="300" y2="600" x2="300" stroke-dasharray="5,5"/>
 <line y1="-100" x1="400" y2="600" x2="400" stroke-dasharray="5,5"/>
 <line y1="-100" x1="500" y2="600" x2="500" stroke-dasharray="5,5"/>
 </g>

 <!-- Figure having vector effect -->
 <!-- A thick red right arrow and small rectangle on this figure's nested
 user coordinate system origin -->
 <path id="ve" vector-effect="none"
 stroke="red" stroke-width="3" fill="none"
 transform="matrix(1,0,0,1,150,150)"
 d="M-50,-50 L50,-50 50,-100 150,0 50,100 50,50 -50,50 -50,-50z M5 0 L0 -5 -5 0 0 5z"/>
 </svg>
 </g>
 </svg>

Below is an example of the [non-scaling-size].

 ---------------------------------------------------------------------------------------------------------------------------------------- -----------------------------------------------------------------------------------------------------------------
 Before changing CTM After changing CTM
 ![Image showing appearance before the effect of the vector effect showing up](images/painting/vectorEffects/ve-initial.svg) ![Image showing non-scaling-size vector effect](images/painting/vectorEffects/ve-nonScalingSize.svg)
 ---------------------------------------------------------------------------------------------------------------------------------------- -----------------------------------------------------------------------------------------------------------------

 <path id="ve" vector-effect="non-scaling-size"
 stroke="red" stroke-width="3" fill="none"
 transform="matrix(1,0,0,1,150,150)"
 d="M-50,-50 L50,-50 50,-100 150,0 50,100 50,50 -50,50 -50,-50z M5 0 L0 -5 -5 0 0 5z"/>

Below is an example of the [non-rotation].

 ---------------------------------------------------------------------------------------------------------------------------------------- ----------------------------------------------------------------------------------------------------------
 Before changing CTM After changing CTM
 ![Image showing appearance before the effect of the vector effect showing up](images/painting/vectorEffects/ve-initial.svg) ![Image showing non-rotation vector effect](images/painting/vectorEffects/ve-nonRotation.svg)
 ---------------------------------------------------------------------------------------------------------------------------------------- ----------------------------------------------------------------------------------------------------------

 <path id="ve" vector-effect="non-rotation"
 stroke="red" stroke-width="3" fill="none"
 transform="matrix(1,0,0,1,150,150)"
 d="M-50,-50 L50,-50 50,-100 150,0 50,100 50,50 -50,50 -50,-50z M5 0 L0 -5 -5 0 0 5z"/>

Below is an example of the [non-scaling-size]
[non-rotation].

 ---------------------------------------------------------------------------------------------------------------------------------------- ------------------------------------------------------------------------------------------------------------------------------------------
 Before changing CTM After changing CTM
 ![Image showing appearance before the effect of the vector effect showing up](images/painting/vectorEffects/ve-initial.svg) ![Image showing non-scaling-size non-rotation vector effect](images/painting/vectorEffects/ve-nonScalingSize-nonRotation.svg)
 ---------------------------------------------------------------------------------------------------------------------------------------- ------------------------------------------------------------------------------------------------------------------------------------------

 <path id="ve" vector-effect="non-scaling-size non-rotation"
 stroke="red" stroke-width="3" fill="none"
 transform="matrix(1,0,0,1,150,150)"
 d="M-50,-50 L50,-50 50,-100 150,0 50,100 50,50 -50,50 -50,-50z M5 0 L0 -5 -5 0 0 5z"/>

Below is an example of the [fixed-position].

 ---------------------------------------------------------------------------------------------------------------------------------------- --------------------------------------------------------------------------------------------------------------
 Before changing CTM After changing CTM
 ![Image showing appearance before the effect of the vector effect showing up](images/painting/vectorEffects/ve-initial.svg) ![Image showing fixed-position vector effect](images/painting/vectorEffects/ve-fixedPosition.svg)
 ---------------------------------------------------------------------------------------------------------------------------------------- --------------------------------------------------------------------------------------------------------------

 <path id="ve" vector-effect="fixed-position"
 stroke="red" stroke-width="3" fill="none"
 transform="matrix(1,0,0,1,150,150)"
 d="M-50,-50 L50,-50 50,-100 150,0 50,100 50,50 -50,50 -50,-50z M5 0 L0 -5 -5 0 0 5z"/>

Below is an example of the [non-scaling-size]
[fixed-position].

 ---------------------------------------------------------------------------------------------------------------------------------------- ----------------------------------------------------------------------------------------------------------------------------------------------
 Before changing CTM After changing CTM
 ![Image showing appearance before the effect of the vector effect showing up](images/painting/vectorEffects/ve-initial.svg) ![Image showing non-scaling-size fixed-position vector effect](images/painting/vectorEffects/ve-nonScalingSize-fixedPosition.svg)
 ---------------------------------------------------------------------------------------------------------------------------------------- ----------------------------------------------------------------------------------------------------------------------------------------------

 <path id="ve" vector-effect="non-scaling-size fixed-position"
 stroke="red" stroke-width="3" fill="none"
 transform="matrix(1,0,0,1,150,150)"
 d="M-50,-50 L50,-50 50,-100 150,0 50,100 50,50 -50,50 -50,-50z M5 0 L0 -5 -5 0 0 5z"/>

Below is an example of the [non-rotation]
[fixed-position].

 ---------------------------------------------------------------------------------------------------------------------------------------- ---------------------------------------------------------------------------------------------------------------------------------------
 Before changing CTM After changing CTM
 ![Image showing appearance before the effect of the vector effect showing up](images/painting/vectorEffects/ve-initial.svg) ![Image showing non-rotation fixed-position vector effect](images/painting/vectorEffects/ve-nonRotation-fixedPosition.svg)
 ---------------------------------------------------------------------------------------------------------------------------------------- ---------------------------------------------------------------------------------------------------------------------------------------

 <path id="ve" vector-effect="non-rotation fixed-position"
 stroke="red" stroke-width="3" fill="none"
 transform="matrix(1,0,0,1,150,150)"
 d="M-50,-50 L50,-50 50,-100 150,0 50,100 50,50 -50,50 -50,-50z M5 0 L0 -5 -5 0 0 5z"/>

Below is an example of the [non-scaling-size]
[non-rotation] [fixed-position].

 ---------------------------------------------------------------------------------------------------------------------------------------- -----------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Before changing CTM After changing CTM
 ![Image showing appearance before the effect of the vector effect showing up](images/painting/vectorEffects/ve-initial.svg) ![Image showing non-scaling-size non-rotation fixed-position vector effect](images/painting/vectorEffects/ve-nonScalingSize-nonRotation-fixedPosition.svg)
 ---------------------------------------------------------------------------------------------------------------------------------------- -----------------------------------------------------------------------------------------------------------------------------------------------------------------------

 <path id="ve" vector-effect="non-scaling-size non-rotation fixed-position"
 stroke="red" stroke-width="3" fill="none"
 transform="matrix(1,0,0,1,150,150)"
 d="M-50,-50 L50,-50 50,-100 150,0 50,100 50,50 -50,50 -50,-50z M5 0 L0 -5 -5 0 0 5z"/>

:::::: ready-for-wider-review
## 8.14. DOM interfaces
### 8.14.1. Interface SVGTransform
The [SVGTransform](coords.html#InterfaceSVGTransform)
interface is used to represent
[\<transform-function\>](https://drafts.csswg.org/css-transforms-1/#typedef-transform-function)
values that appear in the
[transform](coords.html#TransformProperty) property and its
presentation attributes ['transform'],
['[gradientTransform](pservers.html#LinearGradientElementGradientTransformAttribute)']
and
['[patternTransform](pservers.html#PatternElementPatternTransformAttribute)'].
An [SVGTransform](coords.html#InterfaceSVGTransform)
represents a single component in a transform list, such as a single
[scale(...)] or [matrix(...)] value.

An [SVGTransform](coords.html#InterfaceSVGTransform)
object can be designated as *read only*, which means that attempts to
modify the object will result in an exception being thrown, as described
below.

An [SVGTransform](coords.html#InterfaceSVGTransform)
object can be *associated* with a particular element. The associated
element is used to determine which element\'s ['transform']
presentation attribute to update if the object
[reflects](types.html#TermReflect) that attribute. Unless otherwise
described, an
[SVGTransform](coords.html#InterfaceSVGTransform) object
is not associated with any element.

::: ready-for-wider-review
Every [SVGTransform](coords.html#InterfaceSVGTransform)
object operates in one of two modes. It can:

1. *reflect an element of a presentation attribute value* (being
 exposed through the methods on the
 [baseVal](#__svg__SVGAnimatedTransformList__baseVal) member of an
 [SVGAnimatedTransformList](coords.html#InterfaceSVGAnimatedTransformList)),
2. *be detached*, which is the case for
 [SVGTransform](coords.html#InterfaceSVGTransform)
 objects created with
 [createSVGTransform](struct.html#__svg__SVGSVGElement__createSVGTransform)
 and
 [createSVGTransformFromMatrix](struct.html#__svg__SVGSVGElement__createSVGTransformFromMatrix).

An [SVGTransform](coords.html#InterfaceSVGTransform)
object maintains an internal
[\<transform-function\>](https://drafts.csswg.org/css-transforms-1/#typedef-transform-function)
value, which is called its [value].
It also maintains a
[SVGMatrix](https://drafts.csswg.org/geometry-1/#dommatrix)
object, which is called its [matrix object], which is the object returned from the
[matrix](#__svg__SVGTransform__matrix) IDL attribute. An
[SVGTransform](coords.html#InterfaceSVGTransform)
object\'s [matrix object](#TransformMatrixObject) is always kept
synchronized with its [value](#TransformValue).

``` idl
[Exposed=Window]
interface SVGTransform {

 // Transform Types
 const unsigned short SVG_TRANSFORM_UNKNOWN = 0;
 const unsigned short SVG_TRANSFORM_MATRIX = 1;
 const unsigned short SVG_TRANSFORM_TRANSLATE = 2;
 const unsigned short SVG_TRANSFORM_SCALE = 3;
 const unsigned short SVG_TRANSFORM_ROTATE = 4;
 const unsigned short SVG_TRANSFORM_SKEWX = 5;
 const unsigned short SVG_TRANSFORM_SKEWY = 6;

 readonly attribute unsigned short type;
 [SameObject] readonly attribute SVGMatrix matrix;
 readonly attribute float angle;

 undefined setMatrix(optional DOMMatrix2DInit matrix = );
 undefined setTranslate(float tx, float ty);
 undefined setScale(float sx, float sy);
 undefined setRotate(float angle, float cx, float cy);
 undefined setSkewX(float angle);
 undefined setSkewY(float angle);
};
```

The numeric transform type constants defined on
[SVGTransform](coords.html#InterfaceSVGTransform) are
used to represent the type of an
[SVGTransform](coords.html#InterfaceSVGTransform)\'s
[value](#TransformValue). Their meanings are as follows:

 Constant Meaning
 ----------------------------- ----------------------------------------
 **SVG_TRANSFORM_MATRIX** A [matrix(...)] value.
 **SVG_TRANSFORM_TRANSLATE** A [translate(...)] value.
 **SVG_TRANSFORM_SCALE** A [scale(...)] value.
 **SVG_TRANSFORM_ROTATE** A [rotate(...)] value.
 **SVG_TRANSFORM_SKEWX** A [skewX(...)] value.
 **SVG_TRANSFORM_SKEWY** A [skewY(...)] value.
 **SVG_TRANSFORM_UNKNOWN** Some other type of value.

The use of numeric transform type constants is an anti-pattern and new
constant values will not be introduced for any transform types supported
by [SVGTransform](coords.html#InterfaceSVGTransform). If
other types of transforms are supported and used, the
[SVGTransform](coords.html#InterfaceSVGTransform) uses
the [SVG_TRANSFORM_UNKNOWN](#__svg__SVGTransform__SVG_TRANSFORM_UNKNOWN)
type. See below for details on how the other properties of an
[SVGTransform](coords.html#InterfaceSVGTransform) operate
with these types of transforms.

The **type** IDL attribute represents the type of transform item that
the [SVGTransform](coords.html#InterfaceSVGTransform)\'s
[value](#TransformValue) is. On getting
[type](#__svg__SVGTransform__type), the following steps are run:

1. If the
 [SVGTransform](coords.html#InterfaceSVGTransform)\'s
 [value](#TransformValue) is a [matrix(...)],
 [translate(...)], [scale(...)],
 [rotate(...)], [skewX(...)] or
 [skewY(...)] function, then return the corresponding
 constant value from the transform type table above.

2. Otherwise, return
 [SVG_TRANSFORM_UNKNOWN](#__svg__SVGTransform__SVG_TRANSFORM_UNKNOWN).

 For example, for a [scaleX(...)] or
 [translate3d(...)] transform,
 [SVG_TRANSFORM_UNKNOWN](#__svg__SVGTransform__SVG_TRANSFORM_UNKNOWN)
 would be returned.

The **matrix** IDL attribute represents the transform as a 4x4
homogeneous matrix, and on getting returns the
[SVGTransform](coords.html#InterfaceSVGTransform)\'s
[matrix object](#TransformMatrixObject). When the [matrix
object](#TransformMatrixObject) is first created, its values are set to
match the
[SVGTransform](coords.html#InterfaceSVGTransform)\'s
transform function [value](#TransformValue), and is set to [reflects the
SVGTransform](#MatrixMode).

See the [CSS
Transforms](https://drafts.csswg.org/css-transforms-1/#mathematical-description)
specification for a description of how the different transform function
types correspond to particular matrix values.

The **angle** IDL attribute represents the angle parameter of a
[rotate(...)], [skewX(...)] or
[skewY(...)] transform function. On getting, the following
steps are run:

1. If the
 [SVGTransform](coords.html#InterfaceSVGTransform)
 object\'s [value](#TransformValue) is a [rotate(...)],
 [skewX(...)] or [skewY(...)] function,
 return its angle argument in degrees.
2. Otherwise, return 0.

The **setMatrix** method is used to set the
[SVGTransform](coords.html#InterfaceSVGTransform) to a
given matrix value. When setMatrix(`matrix`) is called, the
following steps are run:

1. If the
 [SVGTransform](coords.html#InterfaceSVGTransform)
 object is [read only](#ReadOnlyTransform), then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [NoModificationAllowedError](https://webidl.spec.whatwg.org/#nomodificationallowederror).
2. Let `newMatrix` be the result of
 [`DOMMatrixReadOnly`](https://drafts.csswg.org/geometry-1/#dommatrixreadonly)`.fromMatrix(``matrix``)`,
 including the [validate and
 fix-up](https://drafts.csswg.org/geometry-1/#dommatrixinit-dictionary)
 steps for missing values. If that method throws an error, then
 re-throw that error and abort these steps.
3. If `newMatrix`.is2D() would return true, then set the
 [SVGTransform](coords.html#InterfaceSVGTransform)
 object\'s [value](#TransformValue) to a [matrix(...)]
 value that represents the same matrix as `newMatrix`.
4. Otherwise, set the
 [SVGTransform](coords.html#InterfaceSVGTransform)
 object\'s [value](#TransformValue) to a [matrix3d(...)]
 value that represents the same matrix as `newMatrix`.
5. In either case, [matrix object](#TransformMatrixObject) gets
 synchronized to the
 [SVGTransform](coords.html#InterfaceSVGTransform)
 object\'s [value](#TransformValue).
6. If the
 [SVGTransform](coords.html#InterfaceSVGTransform)
 object [reflects a presentation attribute value of an
 element](#TransformMode), then
 [reserialize](types.html#TermReserialize) the reflected attribute.

The **setTranslate**, **setScale**, **setRotate**, **setSkewX** and
**setSkewY** methods are used to set the
[SVGTransform](coords.html#InterfaceSVGTransform) to a
new transform function value. When one of these methods is called, the
following steps are run:

1. If the
 [SVGTransform](coords.html#InterfaceSVGTransform)
 object is [read only](#ReadOnlyTransform), then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [NoModificationAllowedError](https://webidl.spec.whatwg.org/#nomodificationallowederror).
2. Set the
 [SVGTransform](coords.html#InterfaceSVGTransform)
 object\'s [value](#TransformValue) to a new transform function
 value, depending on which method was called:

 setTranslate(`tx`, `ty`)
 : the new transform function value is [translate(`tx`,
 `ty`)]

 setScale(`sx`, `sy`)
 : the new transform function value is [scale(`sx`,
 `sy`)]

 setRotate(`angle`, `cx`, `cy`)
 : the new transform function value is [rotate(`angle`,
 `cx`, `cy`)]

 setSkewX(`angle`)
 : the new transform function value is
 [skewX(`angle`)]

 setSkewY(`angle`)
 : the new transform function value is
 [skewY(`angle`)]
3. Set the components of the
 [SVGTransform](coords.html#InterfaceSVGTransform)
 object\'s [matrix object](#TransformMatrixObject) to match the new
 transform function [value](#TransformValue).
4. If the
 [SVGTransform](coords.html#InterfaceSVGTransform)
 object [reflects an element of a presentation attribute
 value](#TransformMode), then
 [reserialize](types.html#TermReserialize) the reflected attribute.

This specification imposes additional requirements on the behavior of
[SVGMatrix](https://drafts.csswg.org/geometry-1/#dommatrix)
objects beyond those described in the [Geometry
Interfaces](https://drafts.csswg.org/geometry-1/) specification, so that
they can be used to reflect presentation attributes that take transform
values.

Every
[SVGMatrix](https://drafts.csswg.org/geometry-1/#dommatrix)
object operates in one of two modes. It can:

1. *reflect an
 [SVGTransform](coords.html#InterfaceSVGTransform)*
 (being exposed through the [matrix](#__svg__SVGTransform__matrix)
 IDL attribute on an
 [SVGTransform](coords.html#InterfaceSVGTransform)),
 or
2. *be detached*, which is the case for
 [SVGMatrix](https://drafts.csswg.org/geometry-1/#dommatrix)
 objects created using their constructor or with
 [createSVGMatrix](struct.html#__svg__SVGSVGElement__createSVGMatrix).

A
[SVGMatrix](https://drafts.csswg.org/geometry-1/#dommatrix)
can be designated as *read only*, which means that attempts to modify
the object will result in an exception being thrown. When assigning to
any of a read only
[SVGMatrix](https://drafts.csswg.org/geometry-1/#dommatrix)\'s
IDL attributes, or when invoking any of its mutable transform methods, a
[NoModificationAllowedError](https://webidl.spec.whatwg.org/#nomodificationallowederror)
exception will be [thrown](https://webidl.spec.whatwg.org/#dfn-throw)
instead of updating the internal value.

Note that per [svgwg#706](https://github.com/w3c/svgwg/issues/706)
(2019-10 WG resolutions) SVG 2 reverts to the SVG 1.1 idiom: there is no
separate read-only-variant interface. An
[SVGMatrix](https://drafts.csswg.org/geometry-1/#dommatrix)
may be designated read-only via an internal flag; writes throw
[NoModificationAllowedError](https://webidl.spec.whatwg.org/#nomodificationallowederror)
on the same interface.

When assigning to any of a writable
[SVGMatrix](https://drafts.csswg.org/geometry-1/#dommatrix)\'s
IDL attributes, or when invoking any of its mutable transform methods,
the following steps are run after updating the internal matrix value:

1. If the
 [SVGMatrix](https://drafts.csswg.org/geometry-1/#dommatrix)
 [reflects an SVGTransform](#MatrixMode), then:
 1. If the
 [SVGMatrix](https://drafts.csswg.org/geometry-1/#dommatrix)
 would return true from its
 [is2d](https://drafts.csswg.org/geometry-1/#dom-dommatrixreadonly-is2d)
 method, then set the
 [SVGTransform](coords.html#InterfaceSVGTransform)
 object\'s [value](#TransformValue) to a
 [matrix(...)] value that represents the same matrix
 as the
 [SVGMatrix](https://drafts.csswg.org/geometry-1/#dommatrix).
 2. Otherwise, set the
 [SVGTransform](coords.html#InterfaceSVGTransform)
 object\'s [value](#TransformValue) to a
 [matrix3d(...)] value that represents the same
 matrix as the
 [SVGMatrix](https://drafts.csswg.org/geometry-1/#dommatrix).
 3. If the
 [SVGTransform](coords.html#InterfaceSVGTransform)
 object [reflects an element of a presentation attribute
 value](#TransformMode), then
 [reserialize](types.html#TermReserialize) the reflected
 attribute.

### 8.14.2. Interface SVGTransformList
The
[SVGTransformList](coords.html#InterfaceSVGTransformList)
interface is a [list interface](types.html#TermListInterface) whose
elements are
[SVGTransform](coords.html#InterfaceSVGTransform)
objects. An
[SVGTransformList](coords.html#InterfaceSVGTransformList)
represents a value that the
[transform](coords.html#TransformProperty) property can take,
namely either a
[\<transform-list\>](https://drafts.csswg.org/css-transforms-1/#typedef-transform-list)
or the keyword [none].

``` idl
[Exposed=Window]
interface SVGTransformList {

 readonly attribute unsigned long length;
 readonly attribute unsigned long numberOfItems;

 undefined clear();
 SVGTransform initialize(SVGTransform newItem);
 getter SVGTransform getItem(unsigned long index);
 SVGTransform insertItemBefore(SVGTransform newItem, unsigned long index);
 SVGTransform replaceItem(SVGTransform newItem, unsigned long index);
 SVGTransform removeItem(unsigned long index);
 SVGTransform appendItem(SVGTransform newItem);
 setter undefined (unsigned long index, SVGTransform newItem);

 // Additional methods not common to other list interfaces.
 SVGTransform createSVGTransformFromMatrix(optional DOMMatrix2DInit matrix = );
 SVGTransform? consolidate();
};
```

The **createSVGTransformFromMatrix** method is used to create a new
[SVGTransform](coords.html#InterfaceSVGTransform) object
from a matrix object. When the
createSVGTransformFromMatrix(`matrix`) method is called, the
following steps are run:

1. Let `transform` be a newly created
 [SVGTransform](coords.html#InterfaceSVGTransform)
 object that is [detached](#TransformMode).
2. Follow the steps that would be run if the
 [setMatrix](#__svg__SVGTransform__setMatrix) method on
 `transform` were called, passing `matrix` as
 its argument.
3. Return `transform`.

The **consolidate** method is used to convert the transform list into an
equivalent transformation using a single transform function. When the
consolidate() method is called, the following steps are run:

1. If the
 [SVGTransformList](coords.html#InterfaceSVGTransformList)
 object is [read only](types.html#ReadOnlyList), then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [NoModificationAllowedError](https://webidl.spec.whatwg.org/#nomodificationallowederror).
2. If the list is empty, return null.
3. [Detach](types.html#TermDetach) and then remove all elements in the
 list.
4. Let `transform` be a newly created
 [SVGTransform](coords.html#InterfaceSVGTransform)
 object.
5. Let `matrix` be the matrix value obtained by beginning
 with an identity matrix, and then post-multiplying the value of the
 [matrix object](#TransformMatrixObject) for each
 [SVGTransform](coords.html#InterfaceSVGTransform) in
 the list, in order.
6. Set the components of `transform`\'s [matrix
 object](#TransformMatrixObject) to the component values in
 `matrix`.
7. If `transform`\'s [matrix object](#TransformMatrixObject)
 would return true from its
 [is2d](https://drafts.csswg.org/geometry-1/#dom-dommatrixreadonly-is2d)
 method, then set `transform`\'s [value](#TransformValue)
 to a [matrix(...)] value that represents the same
 matrix as the [matrix object](#TransformMatrixObject).
8. Otherwise, set `transform`\'s [value](#TransformValue) to
 a [matrix3d(...)] value that represents the same matrix
 as the [matrix object](#TransformMatrixObject).
9. [Attach](types.html#TermAttach) `transform` to this
 [SVGTransformList](coords.html#InterfaceSVGTransformList).
10. Append `transform` to this list.
11. If the list [reflects](types.html#TermReflect) a presentation
 attribute, then [reserialize](types.html#TermReserialize) the
 reflected attribute.
12. Return `transform`.

The behavior of all other interface members of
[SVGLengthList](types.html#InterfaceSVGLengthList) are
defined in [List interfaces](types.html#ListInterfaces).

### 8.14.3. Interface SVGAnimatedTransformList
An
[SVGAnimatedTransformList](coords.html#InterfaceSVGAnimatedTransformList)
object is used to [reflect](types.html#TermReflect) the
[transform](coords.html#TransformProperty) property and its
corresponding presentation attribute (which, depending on the element,
is ['transform'],
['[gradientTransform](pservers.html#LinearGradientElementGradientTransformAttribute)']
or
['[patternTransform](pservers.html#PatternElementPatternTransformAttribute)']).

``` idl
[Exposed=Window]
interface SVGAnimatedTransformList {
 [SameObject] readonly attribute SVGTransformList baseVal;
 [SameObject] readonly attribute SVGTransformList animVal;
};
```

The **baseVal** and **animVal** IDL attributes represent the value of
the reflected presentation attribute. On getting
[baseVal](#__svg__SVGAnimatedTransformList__baseVal) or
[animVal](#__svg__SVGAnimatedTransformList__animVal), an
[SVGTransformList](coords.html#InterfaceSVGTransformList)
object is returned that reflects the given presentation attribute.

### 8.14.4. Interface SVGPreserveAspectRatio
The
[SVGPreserveAspectRatio](coords.html#InterfaceSVGPreserveAspectRatio)
interface is used to represent values for the
['[preserveAspectRatio](coords.html#PreserveAspectRatioAttribute)']
attribute.

An
[SVGPreserveAspectRatio](coords.html#InterfaceSVGPreserveAspectRatio)
object can be designated as *read only*, which means that attempts to
modify the object will result in an exception being thrown, as described
below.

Every
[SVGPreserveAspectRatio](coords.html#InterfaceSVGPreserveAspectRatio)
object *reflects the base value* of a
[reflected](types.html#TermReflect)
['[preserveAspectRatio](coords.html#PreserveAspectRatioAttribute)']
attribute (being exposed through the methods on the
[baseVal](#__svg__SVGAnimatedPreserveAspectRatio__baseVal) or
[animVal](#__svg__SVGAnimatedPreserveAspectRatio__animVal) member of an
[SVGAnimatedPreserveAspectRatio](coords.html#InterfaceSVGAnimatedPreserveAspectRatio)).

``` idl
[Exposed=Window]
interface SVGPreserveAspectRatio {

 // Alignment Types
 const unsigned short SVG_PRESERVEASPECTRATIO_UNKNOWN = 0;
 const unsigned short SVG_PRESERVEASPECTRATIO_NONE = 1;
 const unsigned short SVG_PRESERVEASPECTRATIO_XMINYMIN = 2;
 const unsigned short SVG_PRESERVEASPECTRATIO_XMIDYMIN = 3;
 const unsigned short SVG_PRESERVEASPECTRATIO_XMAXYMIN = 4;
 const unsigned short SVG_PRESERVEASPECTRATIO_XMINYMID = 5;
 const unsigned short SVG_PRESERVEASPECTRATIO_XMIDYMID = 6;
 const unsigned short SVG_PRESERVEASPECTRATIO_XMAXYMID = 7;
 const unsigned short SVG_PRESERVEASPECTRATIO_XMINYMAX = 8;
 const unsigned short SVG_PRESERVEASPECTRATIO_XMIDYMAX = 9;
 const unsigned short SVG_PRESERVEASPECTRATIO_XMAXYMAX = 10;

 // Meet-or-slice Types
 const unsigned short SVG_MEETORSLICE_UNKNOWN = 0;
 const unsigned short SVG_MEETORSLICE_MEET = 1;
 const unsigned short SVG_MEETORSLICE_SLICE = 2;

 attribute unsigned short align;
 attribute unsigned short meetOrSlice;
};
```

The numeric alignment type constants defined on
[SVGPreserveAspectRatio](coords.html#InterfaceSVGPreserveAspectRatio)
are used to represent the alignment keyword values that
['[preserveAspectRatio](coords.html#PreserveAspectRatioAttribute)']
can take. Their meanings are as follows:

 Constant Meaning
 -------------------------------------- --------------------------------------
 **SVG_PRESERVEASPECTRATIO_NONE** The [none] keyword.
 **SVG_PRESERVEASPECTRATIO_XMINYMIN** The [xMinYMin] keyword.
 **SVG_PRESERVEASPECTRATIO_XMIDYMIN** The [xMidYMin] keyword.
 **SVG_PRESERVEASPECTRATIO_XMAXYMIN** The [xMaxYMin] keyword.
 **SVG_PRESERVEASPECTRATIO_XMINYMID** The [xMinYMid] keyword.
 **SVG_PRESERVEASPECTRATIO_XMIDYMID** The [xMidYMid] keyword.
 **SVG_PRESERVEASPECTRATIO_XMAXYMID** The [xMaxYMid] keyword.
 **SVG_PRESERVEASPECTRATIO_XMINYMAX** The [xMinYMax] keyword.
 **SVG_PRESERVEASPECTRATIO_XMIDYMAX** The [xMidYMax] keyword.
 **SVG_PRESERVEASPECTRATIO_XMAXYMAX** The [xMaxYMax] keyword.
 **SVG_PRESERVEASPECTRATIO_UNKNOWN** Some other type of value.

Similarly, the numeric meet-or-slice type constants defined on
[SVGPreserveAspectRatio](coords.html#InterfaceSVGPreserveAspectRatio)
are used to represent the meet-or-slice keyword values that
['[preserveAspectRatio](coords.html#PreserveAspectRatioAttribute)']
can take. Their meanings are as follows:

 Constant Meaning
 ----------------------------- -----------------------------------
 **SVG_MEETORSLICE_MEET** The [meet] keyword.
 **SVG_MEETORSLICE_SLICE** The [slice] keyword.
 **SVG_MEETORSLICE_UNKNOWN** Some other type of value.

The **align** IDL attribute represents the alignment keyword part of the
['[preserveAspectRatio](coords.html#PreserveAspectRatioAttribute)']
value. On getting, the following steps are run:

::: ready-for-wider-review
1. Let `value` [reflect the base
 value](#PreserveAspectRatioMode) of a
 ['[preserveAspectRatio](coords.html#PreserveAspectRatioAttribute)']
 attribute. `value` is the current non-animated value of
 the attribute (using the attribute\'s [initial
 value](types.html#TermInitialValue) if it is not present or
 invalid).
2. Return the constant value as specified in the alignment constant
 table above for the alignment keyword in `value`.

On setting [align](#__svg__SVGPreserveAspectRatio__align), the following
steps are run:

1. If the
 [SVGPreserveAspectRatio](coords.html#InterfaceSVGPreserveAspectRatio)
 is [read only](#ReadOnlyPreserveAspectRatio), then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [NoModificationAllowedError](https://webidl.spec.whatwg.org/#nomodificationallowederror).
2. If `value` is
 [SVG_PRESERVEASPECTRATIO_UNKNOWN](#__svg__SVGPreserveAspectRatio__SVG_PRESERVEASPECTRATIO_UNKNOWN)
 or does not have a corresponding entry in the alignment keyword
 table above, then throw a
 [TypeError](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).
3. Let `string` be the corresponding keyword in the
 alignment keyword table above for `value`.
4. Append a single U+0020 SPACE character to `string`.
5. Let `meet or slice` be the value that would be returned
 from the [meetOrSlice](#__svg__SVGPreserveAspectRatio__meetOrSlice)
 member on this
 [SVGPreserveAspectRatio](coords.html#InterfaceSVGPreserveAspectRatio).
6. Append to `string` the corresponding keyword in the
 meet-or-slice keyword table above for `meet or slice`.
7. Set the reflected
 ['[preserveAspectRatio](coords.html#PreserveAspectRatioAttribute)']
 attribute to `string`.

The **meetOrSlice** IDL attribute represents the alignment keyword part
of the
['[preserveAspectRatio](coords.html#PreserveAspectRatioAttribute)']
value. On getting, the following steps are run:

::: ready-for-wider-review
1. Let `value` be a
 ['[preserveAspectRatio](coords.html#PreserveAspectRatioAttribute)']
 value that [reflects the base value](#PreserveAspectRatioMode) of a
 ['[preserveAspectRatio](coords.html#PreserveAspectRatioAttribute)']
 attribute `value` is the current non-animated value of
 the attribute.
2. If the meet-or-slice value is not present in `value`,
 then return
 [SVG_MEETORSLICE_MEET](#__svg__SVGPreserveAspectRatio__SVG_MEETORSLICE_MEET).
3. Otherwise, the meet-or-slice value is present. Return the constant
 value as specified in the meet-or-slice constant table above for the
 meet-or-slice keyword in `value`.

On setting [meetOrSlice](#__svg__SVGPreserveAspectRatio__meetOrSlice),
the following steps are run:

1. If the
 [SVGPreserveAspectRatio](coords.html#InterfaceSVGPreserveAspectRatio)
 is [read only](#ReadOnlyPreserveAspectRatio), then
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [NoModificationAllowedError](https://webidl.spec.whatwg.org/#nomodificationallowederror).
2. If `value` is
 [SVG_MEETORSLICE_UNKNOWN](#__svg__SVGPreserveAspectRatio__SVG_MEETORSLICE_UNKNOWN)
 or does not have a corresponding entry in the meet-or-slice keyword
 table above, then throw a
 [TypeError](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).
3. Let `align` be the value that would be returned from the
 [align](#__svg__SVGPreserveAspectRatio__align) member on this
 [SVGPreserveAspectRatio](coords.html#InterfaceSVGPreserveAspectRatio).
4. Let `string` be the corresponding keyword in the
 alignment keyword table above for `align`.
5. Append a single U+0020 SPACE character to `string`.
6. Append to `string` the corresponding keyword in the
 meet-or-slice keyword table above for `value`.
7. Set the reflected
 ['[preserveAspectRatio](coords.html#PreserveAspectRatioAttribute)']
 attribute to `string`.

### 8.14.5. Interface SVGAnimatedPreserveAspectRatio
An
[SVGAnimatedPreserveAspectRatio](coords.html#InterfaceSVGAnimatedPreserveAspectRatio)
object is used to [reflect](types.html#TermReflect) the
['[preserveAspectRatio](coords.html#PreserveAspectRatioAttribute)']
attribute.

``` idl
[Exposed=Window]
interface SVGAnimatedPreserveAspectRatio {
 [SameObject] readonly attribute SVGPreserveAspectRatio baseVal;
 [SameObject] readonly attribute SVGPreserveAspectRatio animVal;
};
```

The **baseVal** and **animVal** IDL attributes represent the current
non-animated value of the reflected
['[preserveAspectRatio](coords.html#PreserveAspectRatioAttribute)']
attribute. On getting
[baseVal](#__svg__SVGAnimatedPreserveAspectRatio__baseVal) or
[animVal](#__svg__SVGAnimatedPreserveAspectRatio__animVal), an
[SVGPreserveAspectRatio](coords.html#InterfaceSVGPreserveAspectRatio)
object is returned that [reflects the base
value](#PreserveAspectRatioMode) of the
['[preserveAspectRatio](coords.html#PreserveAspectRatioAttribute)']
attribute on the SVG element that the object with the reflecting IDL
attribute of type
[SVGAnimatedPreserveAspectRatio](coords.html#InterfaceSVGAnimatedPreserveAspectRatio)
was obtained from.
