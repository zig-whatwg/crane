# Chapter 13: Painting: Filling, Stroking and Marker Symbols

::: }}
[Overview](Overview.html) · [Previous](embedded.html) ·
[Next](pservers.html) · [Elements](eltindex.html) ·
[Attributes](attindex.html) · [Properties](propidx.html)

## Contents

1. 1. [[13.1.] Introduction](painting.html#Introduction)
 1. [[13.1.1.] Definitions](painting.html#Definitions)
 2. [[13.2.] Specifying
 paint](painting.html#SpecifyingPaint)
 3. [[13.3.] The effect of the '[color]'
 property](painting.html#ColorProperty)
 4. [[13.4.] Fill properties](painting.html#FillProperties)
 1. [[13.4.1.] Specifying fill paint: the
 '[fill]'
 property](painting.html#SpecifyingFillPaint)
 2. [[13.4.2.] Winding rule: the
 '[fill-rule]'
 property](painting.html#WindingRule)
 3. [[13.4.3.] Fill paint opacity: the
 '[fill-opacity]'
 property](painting.html#FillOpacity)
 5. [[13.5.] Stroke
 properties](painting.html#StrokeProperties)
 1. [[13.5.1.] Specifying stroke paint: the
 '[stroke]'
 property](painting.html#SpecifyingStrokePaint)
 2. [[13.5.2.] Stroke paint opacity: the
 '[stroke-opacity]'
 property](painting.html#StrokeOpacity)
 3. [[13.5.3.] Stroke width: the
 '[stroke-width]'
 property](painting.html#StrokeWidth)
 4. [[13.5.4.] Drawing caps at the ends of strokes: the
 '[stroke-linecap]'
 property](painting.html#LineCaps)
 5. [[13.5.5.] Controlling line joins: the
 '[stroke-linejoin]' and
 '[stroke-miterlimit]'
 properties](painting.html#LineJoin)
 6. [[13.5.6.] Dashing strokes: the
 '[stroke-dasharray]' and
 '[stroke-dashoffset]'
 properties](painting.html#StrokeDashing)
 7. [[13.5.7.] Computing the shape of the
 stroke](painting.html#StrokeShape)
 8. [[13.5.8.] Computing the circles for the
 [arcs]
 \'stroke-linejoin\'](painting.html#CurvatureCalculation)
 9. [[13.5.9.] Adjusting the circles for the
 [arcs] \'stroke-linejoin\' when the initial
 circles do not
 intersect](painting.html#ArcsLinejoinFallback)
 6. [[13.6.] Vector
 effects](painting.html#PaintingVectorEffects)
 7. [[13.7.] Markers](painting.html#Markers)
 1. [[13.7.1.] The ['marker']
 element](painting.html#MarkerElement)
 2. [[13.7.2.] Vertex markers: the
 '[marker-start]', '[marker-mid]' and
 '[marker-end]'
 properties](painting.html#VertexMarkerProperties)
 3. [[13.7.3.] Marker shorthand: the
 '[marker]'
 property](painting.html#MarkerShorthand)
 4. [[13.7.4.] Rendering
 markers](painting.html#RenderingMarkers)
 8. [[13.8.] Controlling paint operation order: the
 '[paint-order]' property](painting.html#PaintOrder)
 9. [[13.9.] Color space for interpolation: the
 '[color-interpolation]'
 property](painting.html#ColorInterpolation)
 10. [[13.10.] Rendering hints](painting.html#RenderingHints)
 1. [[13.10.1.] The '[shape-rendering]'
 property](painting.html#ShapeRendering)
 2. [[13.10.2.] The '[text-rendering]'
 property](painting.html#TextRendering)
 3. [[13.10.3.] The '[image-rendering]'
 property](painting.html#ImageRendering)
 11. [[13.11.] The effect of the '[will-change]'
 property](painting.html#WillChange)
 12. [[13.12.] DOM interfaces](painting.html#DOMInterfaces)
 1. [[13.12.1.] Interface
 SVGMarkerElement](painting.html#InterfaceSVGMarkerElement)

:::::::::::::::::::::::::: ready-for-wider-review
## 13.1. Introduction
### 13.1.1. Definitions
[fill]
: The operation of [painting](painting.html#TermPaint) the interior of
 a [shape](shapes.html#TermShapeElement) or the interior of the
 character glyphs in a text string.

[stroke]
: The operation of [painting](painting.html#TermPaint) the outline of
 a [shape](shapes.html#TermShapeElement) or the outline of character
 glyphs in a text string.

Graphical elements that define a shape
-- ['[path](paths.html#PathElement)'] elements, [basic
shapes](shapes.html#TermBasicShapeElement), and [text content
elements](text.html#TermTextContentElement) -- are rendered by being
**filled**, which is painting the interior of the object, and
**stroked**, which is painting along the outline of the object. Filling
and stroking are both **painting** operations. SVG 2 supports a number
of different paints that the fill and stroke of a graphical element can
be painted with:

- a single color,
- a gradient (linear or radial)
- a pattern (vector or raster, possibly tiled),
- other images as specified using CSS Image Value syntax
 \[[css-images-3](refs.html#ref-css-images-3)\].

The paint to use for filling and stroking an element is specified using
the [fill](painting.html#FillProperty) and
[stroke](painting.html#StrokeProperty) properties. The
following section describes the different values that can be used for
these properties.

Other properties, such as
[fill-opacity](painting.html#FillOpacityProperty) and
[stroke-width](painting.html#StrokeWidthProperty), also have
an effect on the way fill and stroke paint is applied to the canvas. The
[Fill properties](#FillProperties) and [Stroke
properties](#StrokeProperties) sections below describe these properties.

Some graphics elements
-- ['[path](paths.html#PathElement)'] elements and [basic
shapes](shapes.html#TermBasicShapeElement) -- can also have **marker
symbols** drawn at their vertices or at other positions along the path
that they describe. The [Markers](#Markers) section below describes how
markers can be defined and used.

SVG 2 adds markers on shapes. Resolved at [Tokyo
F2F](http://www.w3.org/2013/06/03-svg-minutes.html#item03).

## 13.2. Specifying paint
 -------------------- -----------------------------------------------------------------------------------------------------------------------------------------
 SVG 2 Requirement: Add new paint values for referencing current fill paint, stroke paint, etc.
 Resolution: [We will add new paint values currentFillPaint, currentStrokePaint etc. to SVG 2](http://www.w3.org/2011/07/29-svg-minutes.html#item02)
 Purpose: Among other things, to provide an easy way to match marker color to stroke color.
 Owner: Chris ([ACTION-3094](http://www.w3.org/Graphics/SVG/WG/track/actions/3094))
 -------------------- -----------------------------------------------------------------------------------------------------------------------------------------

 ----------------- -----------------------------------------------------------------------------------------------------------------------------------
 SVG 2 Addition: Allow multiple paints in fill and stroke.
 Resolution: [We will allow multiple paints in the fill and stroke properties in SVG 2.](http://www.w3.org/2013/06/03-svg-minutes.html#item10)
 Purpose: Useful for creating cross hatchings, putting a partially transparent pattern on top of a solid fill, etc.
 Owner: Tav ([ACTION-3500](http://www.w3.org/Graphics/SVG/WG/track/actions/3500))
 Deferred: This was dropped for SVG 2, but will be added later in sync with [CSS Fill and Stroke Level 3](https://drafts.fxtf.org/paint/)
 ----------------- -----------------------------------------------------------------------------------------------------------------------------------

The [fill](painting.html#FillProperty) and
[stroke](painting.html#StrokeProperty) properties, defined
below, are used to specify the [paint] used to render the interior of and the stroke around shapes
and text. A paint specification describes a way of putting color values
on to the canvas and is composed of one or more paint layers. Four types
of paints within these paint layers are supported: [solid
colors](https://www.w3.org/TR/css3-values/#colors),
[gradients](pservers.html#Gradients), and
[patterns](pservers.html#Patterns).

A [\<paint\>](painting.html#SpecifyingPaint) value is defined as
follows:

[\<paint\>] = none \|
[\<color\>](https://www.w3.org/TR/css3-values/#colors) \|
[\<url\>](https://www.w3.org/TR/css3-values/#url-value) \[none \|
[\<color\>](https://www.w3.org/TR/css3-values/#colors)\]? \|
context-fill \| context-stroke

With the possible values:

none
: No paint is applied in this layer.

[\<url\>](https://www.w3.org/TR/css3-values/#url-value) \[none \| [\<color\>](https://www.w3.org/TR/css3-values/#colors)\]?
: A URL reference to a [paint server element], which is an element that defines a
 [paint server](pservers.html):
 ['[linearGradient](pservers.html#LinearGradientElement)'],
 ['[pattern](pservers.html#PatternElement)'] and
 ['[radialGradient](pservers.html#RadialGradientElement)'],
 optionally followed by a fall-back value that is used if the paint
 server reference cannot be resolved.

[\<color\>](https://www.w3.org/TR/css3-values/#colors)
: A solid color paint.

context-fill
: Use the paint value of [fill](painting.html#FillProperty)
 from a [context element](painting.html#TermContextElement).

context-stroke
: Use the paint value of
 [stroke](painting.html#StrokeProperty) from a [context
 element](painting.html#TermContextElement).

A [\<paint\>](painting.html#SpecifyingPaint) allows a paint server
reference, to be optionally followed by a
[\<color\>](https://www.w3.org/TR/css3-values/#colors) or the keyword
[none]. When this optional value is given, the
[\<color\>](https://www.w3.org/TR/css3-values/#colors) value or the
value [none] is a fallback value to use if the paint server
reference in the layer is invalid (due to pointing to an element that
does not exist or which is not a valid paint server).

Note that this is slightly different from CSS background syntax, where a
background image and color specified in the final layer of a
[background](https://drafts.csswg.org/css-backgrounds-3/#background)
value will result in both the image and color being rendered.

If a paint server reference in a
[\<paint\>](painting.html#SpecifyingPaint) is invalid, and no fall-back
value is given, no paint is rendered for that layer.

This is changed from SVG 1.1 behavior where the document is in error if
a paint server reference is invalid and there is no fallback color
specified.

 <rect width="100" height="100" fill="url(#MyHatch) powderblue">

![An example with a fallback solid paint
fill.](images/painting/fallback_paint.svg)

The left rectangle shows the expected fill if MyHatch is defined. The
right rectangle shows the expected fill if MyHatch is missing.

For any [\<color\>](https://www.w3.org/TR/css3-values/#colors) value,
all color syntaxes defined in [CSS Color Module Level
3](https://www.w3.org/TR/css-color-3/#colorunits) must be supported,
including [rgb()], [rgba()],
[hsl()], [hsla()], the [extended color
keywords](https://www.w3.org/TR/css-color-3/#svg-color) and the
[currentColor] value.

The [context-fill] and [context-stroke] values
are a reference to the paint layers generated for the
[fill](painting.html#FillProperty) or
[stroke](painting.html#StrokeProperty) property,
respectively, of the [context element] of the element being painted. The context
element of an element is defined as follows:

- If the element is within a
 ['[marker](painting.html#MarkerElement)'], and is being
 rendered as part of that marker due to being referenced via a [marker
 property](painting.html#TermMarkerProperties), then the context
 element is the element referencing that
 ['[marker](painting.html#MarkerElement)'].
- If the element is within a sub-tree that is instantiated with a
 ['[use](struct.html#UseElement)'] element, then the
 context element is that
 ['[use](struct.html#UseElement)'] element.
- Otherwise, there is no context element.

If there is no context element and these keywords are used, then no
paint is applied.

When the context paint layers include paint server references, then the
coordinate space and the bounding box used to scale the paint server
elements and content are those of the [context
element](painting.html#TermContextElement). In other words, any
gradients and patterns referenced with these keywords should be
continuous from the main shape to the markers, or from one element
within a [use-element shadow tree](struct.html#TermUseElementShadowTree)
to another.

If the referenced value of [fill](painting.html#FillProperty)
or [stroke](painting.html#StrokeProperty) is a
[context-fill] and [context-stroke] value,
then those contextual referencing is recursive.

 <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
 <style>
 path {
 fill: none;
 stroke-width: 4px;
 marker: url(#diamond);
 }
 </style>
 <path d="M 10,50 v -20 h 40 v -20" stroke="red"/>
 <path d="M 30,70 v -20 h 40 v -20" stroke="green"/>
 <path d="M 50,90 v -20 h 40 v -20" stroke="blue"/>
 <marker id="diamond" markerWidth="12" markerHeight="12" refX="6" refY="6"
 markerUnits="userSpaceOnUse">
 <circle cx="6" cy="6" r="3"
 fill="white" stroke="context-stroke" stroke-width="2"/>
 </marker>
 </svg>

![An example of the content-stroke keyword used in a
marker](images/painting/marker-context.svg11.svg){height="200"}

The marker is defined using a shape whose
[stroke](painting.html#StrokeProperty) is set to
[context-stroke]. This causes the marker to take on the
color of each ['[path](paths.html#PathElement)'] element
that uses the marker.

## 13.3. The effect of the '[color]' property
See the CSS Color Module Level 3 specification for the definition of
[color](painting.html#ColorProperty).
\[[css-color-3](refs.html#ref-css-color-3)\]

The [color](painting.html#ColorProperty) property is used to
provide a potential indirect value, [currentColor], for the
[fill](painting.html#FillProperty),
[stroke](painting.html#StrokeProperty),
[stop-color](pservers.html#StopColorProperty),
[flood-color](https://drafts.fxtf.org/filter-effects/#FloodColorProperty)
and
[lighting-color](https://drafts.fxtf.org/filter-effects/#LightingColorProperty)
properties. The property has no other effect on SVG elements.

The following example shows how the inherited value of the
[color](painting.html#ColorProperty) property from an HTML
document can be used to set the color of SVG text in an inline SVG
fragment.

 <!DOCTYPE html>
 <style>
 body { color: #468; font: 16px sans-serif }
 svg { border: 1px solid #888; background-color: #eee }
 </style>
 <p>Please see the diagram below:</p>
 <svg width="200" height="100">
 <g fill="currentColor">
 <text x="70" y="55" text-anchor="end">START</text>
 <text x="130" y="55">STOP</text>
 <path d="M 85,45 h 25 v -5 l 10,10 -10,10 v -5 h -25 z"/>
 </g>
 </svg>

Please see the diagram below:

!(data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIyMDAiIGhlaWdodD0iMTAwIiBzdHlsZT0iYm9yZGVyOiAxcHggc29saWQgIzg4ODsgYmFja2dyb3VuZC1jb2xvcjogI2VlZSI+CiAgICAgICAgPGcgZmlsbD0iY3VycmVudENvbG9yIj4KICAgICAgICAgIDx0ZXh0IHg9IjcwIiB5PSI1NSIgdGV4dC1hbmNob3I9ImVuZCI+U1RBUlQ8L3RleHQ+CiAgICAgICAgICA8dGV4dCB4PSIxMzAiIHk9IjU1Ij5TVE9QPC90ZXh0PgogICAgICAgICAgPHBhdGggZD0iTSA4NSw0NSBoIDI1IHYgLTUgbCAxMCwxMCAtMTAsMTAgdiAtNSBoIC0yNSB6IiAvPgogICAgICAgIDwvZz4KICAgICAgPC9zdmc+)

The text and arrow in the SVG fragment are filled with the same color as
the inherited [color](painting.html#ColorProperty) property.

## 13.4. Fill properties
### 13.4.1. Specifying fill paint: the '[fill]' property
 --------------------------------------------------------------------------- --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Name: [fill]
 Value: [\<paint\>](painting.html#SpecifyingPaint)
 Initial: black
 Applies to: [shapes](shapes.html#TermShapeElement) and [text content elements](text.html#TermTextContentElement)
 Inherited: yes
 Percentages: N/A
 Media: visual
 Computed value: as specified, but with [\<color\>](https://www.w3.org/TR/css3-values/#colors) values computed and [\<url\>](https://www.w3.org/TR/css3-values/#url-value) values made absolute
 [Animation type](https://www.w3.org/TR/web-animations-1/#animation-type): by computed value
 --------------------------------------------------------------------------- --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

The [fill](painting.html#FillProperty) property paints the
interior of the given graphical element. The area to be painted consists
of any areas inside the outline of the shape. To determine the inside of
the shape, all subpaths are considered, and the interior is determined
according to the rules associated with the current value of the
[fill-rule](painting.html#FillRuleProperty) property. The
zero-width geometric outline of a shape is included in the area to be
painted.

The fill operation fills [open subpaths](paths.html#TermClosedSubpath)
by performing the fill operation as if an additional \"closepath\"
command were added to the path to connect the last point of the subpath
with the first point of the subpath. Thus, fill operations apply to both
[open subpaths](paths.html#TermClosedSubpath) within
['[path](paths.html#PathElement)'] elements (i.e.,
subpaths without a closepath command) and
['[polyline](shapes.html#PolylineElement)'] elements.

### 13.4.2. Winding rule: the '[fill-rule]' property
 --------------------------------------------------------------------------- ------------------------------------------------------------------------------------------------------
 Name: [fill-rule]
 Value: nonzero \| evenodd
 Initial: nonzero
 Applies to: [shapes](shapes.html#TermShapeElement) and [text content elements](text.html#TermTextContentElement)
 Inherited: yes
 Percentages: N/A
 Media: visual
 Computed value: as specified
 [Animation type](https://www.w3.org/TR/web-animations-1/#animation-type): discrete
 --------------------------------------------------------------------------- ------------------------------------------------------------------------------------------------------

The [fill-rule](painting.html#FillRuleProperty) property
indicates the algorithm (or *winding rule*) which is to be used to
determine what parts of the canvas are included inside the shape. For a
simple, non-intersecting path, it is intuitively clear what region lies
\"inside\"; however, for a more complex path, such as a path that
intersects itself or where one subpath encloses another, the
interpretation of \"inside\" is not so obvious.

The [fill-rule](painting.html#FillRuleProperty) property
provides two options for how the inside of a shape is determined:

[nonzero]

: This rule determines the \"insideness\" of a point on the canvas by
 drawing a ray from that point to infinity in any direction and then
 examining the places where a segment of the shape crosses the ray.
 Starting with a count of zero, add one each time a path segment
 crosses the ray from left to right and subtract one each time a path
 segment crosses the ray from right to left. After counting the
 crossings, if the result is zero then the point is *outside* the
 path. Otherwise, it is *inside*. The following drawing illustrates
 the [nonzero] rule:

 ::: figure
 ![Image showing nonzero fill
 rule](images/painting/fillrule-nonzero.svg)
 The effect of a nonzero fill rule on paths with self-intersections
 and enclosed subpaths.
 :::

[evenodd]

: This rule determines the \"insideness\" of a point on the canvas by
 drawing a ray from that point to infinity in any direction and
 counting the number of path segments from the given shape that the
 ray crosses. If this number is odd, the point is inside; if even,
 the point is outside. The following drawing illustrates the
 [evenodd] rule:

 ::: figure
 ![Image showing evenodd fill
 rule](images/painting/fillrule-evenodd.svg)
 The effect of an evenodd fill rule on paths with self-intersections
 and enclosed subpaths.
 :::

The above descriptions do not specify what to do if a path segment
coincides with or is tangent to the ray. Since any ray will do, one may
simply choose a different ray that does not have such problem
intersections.

### 13.4.3. Fill paint opacity: the '[fill-opacity]' property
 --------------------------------------------------------------------------- ------------------------------------------------------------------------------------------------------
 Name: [fill-opacity]
 Value: \<'[opacity](render.html#ObjectAndGroupOpacityProperties)'\>
 Initial: 1
 Applies to: [shapes](shapes.html#TermShapeElement) and [text content elements](text.html#TermTextContentElement)
 Inherited: yes
 Percentages: N/A
 Media: visual
 Computed value: the specified value converted to a number, clamped to the range \[0,1\]
 [Animation type](https://www.w3.org/TR/web-animations-1/#animation-type): by computed value
 --------------------------------------------------------------------------- ------------------------------------------------------------------------------------------------------

[fill-opacity](painting.html#FillOpacityProperty) specifies
the opacity of the painting operation used to paint the fill the current
object. (See [Painting shapes and
text](render.html#PaintingShapesAndText)).

[\<number\>]
: The opacity of the fill. Any values outside the range 0 (fully
 transparent) to 1 (fully opaque) must be clamped to this range.

[\<percentage\>]
: The opacity of the fill expressed as a percentage of the range 0 to
 1.

See also the
[opacity](render.html#ObjectAndGroupOpacityProperties)
property, which specifies group opacity.

## 13.5. Stroke properties
 ----------------------------------- ------------------------------------------------------------------
 SVG 2 Requirement: Support non-scaling stroke.

 Resolutions: [SVG 2 will include non-scaling
 stroke.](http://www.w3.org/2011/10/28-svg-irc#T17-46-34)\
 [SVG 2 will have the '[vector-effect]'
 property.](http://www.w3.org/2012/02/02-svg-minutes.html#item05)

 Purpose: To support strokes whose width does not change when zooming a
 page, as common for example in maps.

 Owner: Chris or Erik (no action)

 Note: Note that this could be part of more generic non-scaling features.
 ----------------------------------- ------------------------------------------------------------------

In this section, we define a number of properties that allow the author
to control different aspects of a stroke, including its paint,
thickness, use of dashing, and joining and capping of path segments.

In all cases, all stroking properties which are affected by
directionality, such as those having to do with dash patterns, must be
rendered such that the stroke operation starts at the same point at
which the graphics element starts. In particular, for
['[path](paths.html#PathElement)'] elements, the start of
the path is the first point of the initial \"moveto\" command.

For stroking properties such as dash patterns whose computations are
dependent on progress along the outline of the graphics element,
distance calculations are required to utilize the SVG user agent\'s
standard [Distance along a path](paths.html#DistanceAlongAPath)
algorithms.

When stroking is performed using a complex paint server, such as a
gradient or a pattern, the stroke operation must be identical to the
result that would have occurred if the geometric shape defined by the
geometry of the current graphics element and its associated stroking
properties were converted to an equivalent
['[path](paths.html#PathElement)'] element and then
filled using the given paint server.

### 13.5.1. Specifying stroke paint: the '[stroke]' property
 --------------------------------------------------------------------------- --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Name: [stroke]
 Value: [\<paint\>](painting.html#SpecifyingPaint)
 Initial: none
 Applies to: [shapes](shapes.html#TermShapeElement) and [text content elements](text.html#TermTextContentElement)
 Inherited: yes
 Percentages: N/A
 Media: visual
 Computed value: as specified, but with [\<color\>](https://www.w3.org/TR/css3-values/#colors) values computed and [\<url\>](https://www.w3.org/TR/css3-values/#url-value) values made absolute
 [Animation type](https://www.w3.org/TR/web-animations-1/#animation-type): by computed value
 --------------------------------------------------------------------------- --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

The [stroke](painting.html#StrokeProperty) property paints
along the outline of the given graphical element.

Note that when stroking a
['[path](paths.html#PathElement)'] element, any subpath
consisting of a [moveto](paths.html#PathDataMovetoCommands) but no
following line drawing command will not be stroked. Any other type of
zero-length subpath, such as [\'M 10,10 L 10,10\'] or [\'M
30,30 Z\'] will also not be stroked if the
[stroke-linecap](painting.html#StrokeLinecapProperty)
property has a value of [butt]. See the definition of the
[stroke shape](painting.html#TermStrokeShape) below for the details of
computing the stroke of a path.

 -------------------- ---------------------------------------------------------------------------------------------------------
 SVG 2 Requirement: Include a way to specify stroke position.
 Resolution: [SVG 2 shall include a way to specify stroke position.](http://www.w3.org/2011/10/28-svg-irc#T18-09-48)
 Purpose: To allow a stroke to be inside or outside the path.
 Owner: Cameron ([ACTION-3162](http://www.w3.org/Graphics/SVG/WG/track/actions/3162))
 Note: See [proposal page](http://www.w3.org/Graphics/SVG/WG/wiki/Proposals/Stroke_position).
 -------------------- ---------------------------------------------------------------------------------------------------------

### 13.5.2. Stroke paint opacity: the '[stroke-opacity]' property
 --------------------------------------------------------------------------- ------------------------------------------------------------------------------------------------------
 Name: [stroke-opacity]
 Value: \<'[opacity](render.html#ObjectAndGroupOpacityProperties)'\>
 Initial: 1
 Applies to: [shapes](shapes.html#TermShapeElement) and [text content elements](text.html#TermTextContentElement)
 Inherited: yes
 Percentages: N/A
 Media: visual
 Computed value: the specified value converted to a number, clamped to the range \[0,1\]
 [Animation type](https://www.w3.org/TR/web-animations-1/#animation-type): by computed value
 --------------------------------------------------------------------------- ------------------------------------------------------------------------------------------------------

The [stroke-opacity](painting.html#StrokeOpacityProperty)
property specifies the opacity of the painting operation used to stroke
the current object. (See [Painting shapes and
text](render.html#PaintingShapesAndText).) As with
[fill-opacity](painting.html#FillOpacityProperty).

[\<number\>]
: The opacity of the stroke. Any values outside the range 0 (fully
 transparent) to 1 (fully opaque) must be clamped to this range.

[\<percentage\>]
: The opacity of the stroke expressed as a percentage of the range 0
 to 1.

See also the
[opacity](render.html#ObjectAndGroupOpacityProperties)
property, which specifies group opacity.

### 13.5.3. Stroke width: the '[stroke-width]' property
 --------------------------------------------------------------------------- --------------------------------------------------------------------------------------------------------------------------------------------------
 Name: [stroke-width]
 Value: [\<length-percentage\>](https://www.w3.org/TR/css-values/#typedef-length-percentage) \| [\<number\>](https://www.w3.org/TR/css3-values/#numbers)
 Initial: 1px
 Applies to: [shapes](shapes.html#TermShapeElement) and [text content elements](text.html#TermTextContentElement)
 Inherited: yes
 Percentages: refer to the normalized diagonal of the current SVG viewport (see [Units](coords.html#Units))
 Media: visual
 Computed value: an absolute length or percentage, numbers converted to absolute lengths first
 [Animation type](https://www.w3.org/TR/web-animations-1/#animation-type): by computed value
 --------------------------------------------------------------------------- --------------------------------------------------------------------------------------------------------------------------------------------------

This property specifies the width of the stroke on the current object. A
zero value causes no stroke to be painted. A negative value is
[invalid](types.html#TermInvalidValue). A
[\<number\>](https://www.w3.org/TR/css3-values/#numbers) value
represents a value in [user units](coords.html#TermUserUnits).

### 13.5.4. Drawing caps at the ends of strokes: the '[stroke-linecap]' property
 --------------------------------------------------------------------------- ------------------------------------------------------------------------------------------------------
 Name: [stroke-linecap]
 Value: butt \| round \| square
 Initial: butt
 Applies to: [shapes](shapes.html#TermShapeElement) and [text content elements](text.html#TermTextContentElement)
 Inherited: yes
 Percentages: N/A
 Media: visual
 Computed value: as specified
 [Animation type](https://www.w3.org/TR/web-animations-1/#animation-type): discrete
 --------------------------------------------------------------------------- ------------------------------------------------------------------------------------------------------

[stroke-linecap](painting.html#StrokeLinecapProperty)
specifies the shape to be used at the end of [open
subpaths](paths.html#TermClosedSubpath) when they are stroked, [ and the
shape to be drawn for zero length subpaths whether they are open or
closed.] The possible values are:

[butt]
: This value indicates that the stroke for each subpath does not
 extend beyond its two endpoints. A zero length subpath will
 therefore not have any stroke.

[round]

: This value indicates that at each end of each subpath, the shape
 representing the stroke will be extended by a half circle with a
 diameter equal to the stroke width. If a subpath, [whether open or
 closed,] has zero length, then the
 resulting effect is that the stroke for that subpath consists solely
 of a full circle centered at the subpath\'s point.

[square]

: This value indicates that at the end of each subpath, the shape
 representing the stroke will be extended by a rectangle with the
 same width as the stroke width and whose length is half of the
 stroke width. If a subpath, [whether open or
 closed,] has zero length, then the
 resulting effect is that the stroke for that subpath consists solely
 of a square with side length equal to the stroke width, centered at
 the subpath\'s point, and oriented such that two of its sides are
 parallel to the effective tangent at that subpath\'s point. See
 [['path'] element implementation
 notes](paths.html#PathElementImplementationNotes) for details on how
 to determine the tangent at a zero-length subpath.

![Image showing three paths, each with a different line
cap.](images/painting/linecap.svg)

The three types of line caps.

See the definition of the [cap shape](painting.html#TermCapShape) below
for a more precise description of the shape a line cap will have.

### 13.5.5. Controlling line joins: the '[stroke-linejoin]' and '[stroke-miterlimit]' properties
The values [miter-clip] and
[arcs] of the
[stroke-linejoin](painting.html#StrokeLinejoinProperty)
property are at risk. There are no known browser implementations. See
issue [GitHub issue #592](https://github.com/w3c/svgwg/issues/592).

 ----------------- ------------------------------------------------------------------------------------------------------
 Name: [stroke-linejoin]
 Value: miter \| miter-clip \| round \| bevel \| arcs
 Initial: miter
 Applies to: [shapes](shapes.html#TermShapeElement) and [text content elements](text.html#TermTextContentElement)
 Inherited: yes
 Percentages: N/A
 Media: visual
 Computed value: as specified
 Animation Type: discrete
 ----------------- ------------------------------------------------------------------------------------------------------

[stroke-linejoin](painting.html#StrokeLinejoinProperty)
specifies the shape to be used at the corners of paths or basic shapes
when they are stroked. For further details see the [path implementation
notes](paths.html#PathElementImplementationNotes).

[miter]
: This value indicates that a sharp corner is to be used to join path
 segments. The corner is formed by extending the outer edges of the
 stroke at the tangents of the path segments until they intersect. If
 the
 [stroke-miterlimit](painting.html#StrokeMiterlimitProperty)
 is exceeded, the line join falls back to [bevel] (see
 below).

[miter-clip]
: This value is the same as [miter] but if the
 [stroke-miterlimit](painting.html#StrokeMiterlimitProperty)
 is exceeded, the miter is clipped at a distance equal to half the
 [stroke-miterlimit](painting.html#StrokeMiterlimitProperty)
 value multiplied by the stroke width from the intersection of the
 path segments (see below).

[round]
: This value indicates that a round corner is to be used to join path
 segments. The corner is a circular sector centered on the join
 point.

[bevel]
: This value indicates that a bevelled corner is to be used to join
 path segments. The bevel shape is a triangle that fills the area
 between the two stroked segments.

[arcs]
: This value indicates that an arcs corner is to be used to join path
 segments. The arcs shape is formed by extending the outer edges of
 the stroke at the join point with arcs that have the same curvature
 as the outer edges at the join point.

The [miter-clip] and [arcs] values are new in
SVG 2. The [miter-clip] value offers a more consistent
presentation for a path with multiple joins as well as better behavior
when a path is animated. The [arcs] value provides a better
looking join when the path segments at the join are curved.

Adding \'arcs\' line join was resolved at the [Rigi Kaltbad group
meeting](http://www.w3.org/2012/09/19-svg-minutes.html#item08).

Adding \'miter-clip\' line join was resolved at the [Sydney (2015) group
meeting](http://www.w3.org/2015/02/12-svg-minutes.html#item03).

![Image showing four paths, each with a different line
join.](images/painting/linejoin-four.svg)

Four types of line joins.

 --------------------------------------------------------------------------- ------------------------------------------------------------------------------------------------------
 Name: [stroke-miterlimit]
 Value: [\<number\>](https://www.w3.org/TR/css3-values/#numbers)
 Initial: 4
 Applies to: [shapes](shapes.html#TermShapeElement) and [text content elements](text.html#TermTextContentElement)
 Inherited: yes
 Percentages: N/A
 Media: visual
 Computed value: as specified
 [Animation type](https://www.w3.org/TR/web-animations-1/#animation-type): by computed value
 --------------------------------------------------------------------------- ------------------------------------------------------------------------------------------------------

When two line segments meet at a sharp angle and a value of
[miter], [miter-clip], or [arcs]
has been specified for
[stroke-linejoin](painting.html#StrokeLinejoinProperty), it
is possible for the join to extend far beyond the thickness of the line
stroking the path. The
[stroke-miterlimit](painting.html#StrokeMiterlimitProperty)
imposes a limit on the extent of the line join.

[\<number\>]
: The limit on the extent of a [miter],
 [miter-clip], or [arcs] line join as a
 multiple of the
 [stroke-width](painting.html#StrokeWidthProperty) value.
 A negative value for
 [stroke-miterlimit](painting.html#StrokeMiterlimitProperty)
 is [invalid](types.html#TermInvalidValue) and must be
 [ignored](https://drafts.csswg.org/css-syntax/#css-ignored).

Previous versions of the SVG specification also stated that values
between 0 and 1 were in error, but this was not well implemented by user
agent\'s CSS parsers. In practice, any miter join will exceed a miter
limit between 0 and 1.

For the [miter] or the [miter-clip] values,
given the angle `θ` between the segments in user coordinate
system, the miter length is calculated by:

::: { aria-describedby="math-miter-length"}
$${miter\ length} = \frac{‘stroke-width’}{\sin\frac{\theta}{2}}$$

```
miter length = stroke-width / sin(theta / 2)
```

Historically, the miter length is defined as the distance from the
inside stroke edge of the intersecting path segments to the tip of the
miter. In practice, this is followed only for straight path segments.
The above definition of miter length based on angles depends only on the
tangents to the path segments at the join and thus gives consistent
results independent of the curvature of the path segments. To be
consistent with this definition, the clipping point of the
[miter-clip] and [arcs] line joins is at a
distance or arc length equal to half the
[stroke-miterlimit](painting.html#StrokeMiterlimitProperty)
times the stroke width from the point the two path segments join.

![Image showing the definition of the stroke miter length and
consistency of clipping between different shaped path
segments.](images/painting/miter-limit-def.svg)

Left: Historical definition of miter length. Right: Two different paths
with the same tangents to the path at the point where the path segments
join. The behavior of the miter join (fallback to bevel or clipping
position) is the same for both paths. It does not depend on the position
where the inside stroked edges intersect.

If the miter length divided by the stroke width exceeds the
[stroke-miterlimit](painting.html#StrokeMiterlimitProperty)
then for the value:

[miter]
: the join is converted to a bevel;

[miter-clip]
: the miter is clipped by a line perpendicular to the line bisecting
 the angle between the two path segments at a distance of half the
 value of miter length from the intersection of the two path
 segments.

![Image showing resulting stroke when stroke miter limit is
exceeded.](images/painting/miter-limit.svg)

Effect on line join when
[stroke-miterlimit](painting.html#StrokeMiterlimitProperty)
is exceeded. The olive-green dashed lines shows the position of the
miter limit when the
[stroke-miterlimit](painting.html#StrokeMiterlimitProperty)
value is 3. The gray regions shows what the joins would look like
without a miter limit.

For the [arcs] value, the *miter length* is calculated
along a circular arc that is tangent to the line bisecting the angle
between the two segments at the point the two segments intersect and
passes through the end point of the join. The line join is clipped, if
necessary, by a line perpendicular to this arc at an arc length from the
intersection point equal to half the value of the
[stroke-miterlimit](painting.html#StrokeMiterlimitProperty)
value multiplied by the stroke width.

The effect of \'stroke-miterlimit\' on an \'arcs\' line join was
resolved at [Sydney (2015) group
meeting](http://www.w3.org/2015/02/12-svg-minutes.html#item12).

See the definition of the [line join
shape](painting.html#TermLineJoinShape) below for a more precise
description of the shape a line join will have.

### 13.5.6. Dashing strokes: the '[stroke-dasharray]' and '[stroke-dashoffset]' properties
 --------------------------------------------------------------------------- -------------------------------------------------------------------------------------------------------------------------------
 Name: [stroke-dasharray]
 Value: none \| [\<dasharray\>](painting.html#DataTypeDasharray)
 Initial: none
 Applies to: [shapes](shapes.html#TermShapeElement) and [text content elements](text.html#TermTextContentElement)
 Inherited: yes
 Percentages: refer to the normalized diagonal of the current SVG viewport (see [Units](coords.html#Units))
 Media: visual
 Computed value: as comma separated list of absolute lengths or percentages, numbers converted to absolute lengths first, or keyword specified
 [Animation type](https://www.w3.org/TR/web-animations-1/#animation-type): See prose
 --------------------------------------------------------------------------- -------------------------------------------------------------------------------------------------------------------------------

where:

[\<dasharray\>] = \[
\[
[\<length-percentage\>](https://www.w3.org/TR/css-values/#typedef-length-percentage)
\| [\<number\>](https://www.w3.org/TR/css3-values/#numbers) \]+ \]#

The [stroke-dasharray](painting.html#StrokeDasharrayProperty)
property controls the pattern of dashes and gaps used to form the shape
of a path\'s stroke.

[none]
: Indicates that no dashing is used.

[\<dasharray\>]

: Specifies a dashing pattern to use. A
 [\<dasharray\>](painting.html#DataTypeDasharray) is a list of comma
 and/or white space separated
 [\<number\>](https://www.w3.org/TR/css3-values/#numbers) or
 [\<length-percentage\>](https://www.w3.org/TR/css-values/#typedef-length-percentage)
 values. A [\<number\>](https://www.w3.org/TR/css3-values/#numbers)
 value represents a value in [user units](coords.html#TermUserUnits).
 Each value specifies a length along the path for which the stroke is
 to be painted (a *dash*) and not painted (a *gap*). The first value
 and every second value in the list after it specifies the length of
 a dash, and every other value specifies the length of a gap between
 the dashes. If the list has an odd number of values, then it is
 repeated to yield an even number of values. (Thus, the rendering
 behavior of [stroke-dasharray: 5,3,2] is equivalent to
 [stroke-dasharray: 5,3,2,5,3,2].)

 The resulting even-length dashing pattern is repeated along each
 subpath. The dashing pattern is reset and begins again at the start
 of each subpath.

 If any value in the list is negative, the
 [\<dasharray\>](painting.html#DataTypeDasharray) value is
 [invalid](types.html#TermInvalidValue). If all of the values in the
 list are zero, then the stroke is rendered as a solid line without
 any dashing.

![Image showing a thick, dashed
stroke.](images/painting/dashes.svg)

A dashed stroke. The dashing pattern is [20,10]. The red
line shows the actual path that is stroked.

The ['[pathLength](paths.html#PathLengthAttribute)']
attribute on a ['[path](paths.html#PathElement)'] element
affects
[stroke-dasharray](painting.html#StrokeDasharrayProperty):
each dash and gap length is interpreted relative to the author\'s path
length as specified by
['[pathLength](paths.html#PathLengthAttribute)'].

[stroke-dasharray](painting.html#StrokeDasharrayProperty)
values are [not
additive](https://drafts.csswg.org/css-values-4/#not-additive). For
interpolation,
[stroke-dasharray](painting.html#StrokeDasharrayProperty)
values are combined as follows:

If either `start` or `end` compute to [none] or are invalid
: `start` or `end` are combined using the
 discrete animation type.

Otherwise
: repeat both dash patterns of `start` and `end`
 value list until the length of elements in both value lists match.
 Each item is then combined by computed value.

The two
[stroke-dasharray](painting.html#StrokeDasharrayProperty)
value lists in the following example have different number of elements:

 path {
 stroke-dasharray: 20 40 10;
 }

 path:hover {
 transition-property: stroke-dasharray;
 transition-duration: 0.5s;
 stroke-dasharray: 40 20;
 }

To interpolate the two value lists the dash pattern gets repeated on
both lists first:

 stroke-dasharray: 20 40 10 20 40 10;
 stroke-dasharray: 40 20 40 20 40 20;

After that, each item is then combined by computed value.

 --------------------------------------------------------------------------- --------------------------------------------------------------------------------------------------------------------------------------------------
 Name: [stroke-dashoffset]
 Value: [\<length-percentage\>](https://www.w3.org/TR/css-values/#typedef-length-percentage) \| [\<number\>](https://www.w3.org/TR/css3-values/#numbers)
 Initial: 0
 Applies to: [shapes](shapes.html#TermShapeElement) and [text content elements](text.html#TermTextContentElement)
 Inherited: yes
 Percentages: refer to the normalized diagonal of the current SVG viewport (see [Units](coords.html#Units))
 Media: visual
 Computed value: an absolute length or percentage, numbers converted to absolute lengths first
 [Animation type](https://www.w3.org/TR/web-animations-1/#animation-type): by computed value
 --------------------------------------------------------------------------- --------------------------------------------------------------------------------------------------------------------------------------------------

The
[stroke-dashoffset](painting.html#StrokeDashoffsetProperty)
property specifies the distance into the repeated dash pattern to start
the stroke dashing at the beginning of the path. If the value is
negative, then the effect is the same as dash offset `d`:

::: { aria-describedby="math-dashoffset"}
$$d = s - |{‘stroke-dashoffset’}|\operatorname{mod}s$$

```
d = s - (abs(stroke-dashoffset) mod s)
```

where `s` is the sum of the dash array values.

![Image showing a thick, dashed stroke with a non-zero dash
offset.](images/painting/dashoffset.svg)

A dashed stroke with a non-zero dash offset. The dashing pattern is
[20,10] and the dash offset is [15]. The red
line shows the actual path that is stroked.

[stroke-dasharray](painting.html#StrokeDasharrayProperty),
[stroke-dashoffset](painting.html#StrokeDashoffsetProperty)
is interpreted relative to the author\'s path length as specified by the
['[pathLength](paths.html#PathLengthAttribute)'] attribute
on a ['[path](paths.html#PathElement)'] element.

The example below shows how a
['[pathLength](paths.html#PathLengthAttribute)'] that is
greatly different from the actual path length can be used to control
stroke dashing more easily.

 <svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink"
 width="300" height="150">
 <defs>
 <path id="p" d="M -50,0 A 50,50 0 0 0 50,0 A 50,50 0 0 0 -50,0 z"
 pathLength="80"/>
 <g id="chip" stroke-width="10">
 <circle cy="5" r="55" fill="#000" fill-opacity="0.15" stroke="none"/>
 <use xlink:href="#p"/>
 <use xlink:href="#p" fill="none" stroke="#eee" stroke-width="10"
 stroke-dasharray="10 10" stroke-dashoffset="5"/>
 <g fill="none" stroke-width="5" stroke-dasharray="0 20" stroke-linecap="round">
 <use xlink:href="#p" stroke="#eee" stroke-dashoffset="10"/>
 <use xlink:href="#p" stroke-dashoffset="0"/>
 </g>
 <circle r="40" fill="#000" fill-opacity="0.15"
 stroke-width="2" stroke="white"/>
 </g>
 </defs>
 <rect width="100%" height="100%" fill="#063"/>
 <use xlink:href="#chip" x="140" y="75" fill="#00c" stroke="#00c"/>
 <use xlink:href="#chip" x="160" y="85" fill="#000" stroke="#000"/>
 <use xlink:href="#chip" x="170" y="65" fill="#c00" stroke="#c00"/>
 </svg>

![Image of three casino chips, each of which has a patterned border
produced using stroke dashing.](images/painting/dash-pathlength.svg)

The four broad white dashes and the eight small circular dashes around
each chip are placed relative to an author specified
['[pathLength](paths.html#PathLengthAttribute)'] of
[\'80\'], which makes the desired
[stroke-dasharray](painting.html#StrokeDasharrayProperty) and
[stroke-dashoffset](painting.html#StrokeDashoffsetProperty)
values easy to compute.

See the definition of [dash positions](painting.html#TermDashPositions)
below for a more precise description of positions along a path that
dashes will be placed.

::::::::::::::::::: ready-for-wider-review
### 13.5.7. Computing the shape of the stroke
 -------------------- ------------------------------------------------------------------------------------------------------
 SVG 2 Requirement: Specify stroke dashing more precisely.
 Resolution: [SVG 2 shall specify stroke dashing more precisely.](http://www.w3.org/2011/10/28-svg-irc#T18-14-14)
 Purpose: To define dash starting point on basic shapes and path segments.
 Owner: Cameron (no action)
 -------------------- ------------------------------------------------------------------------------------------------------

::::: ready-for-wider-review
The [stroke shape] of an
element is the shape that is filled by the
[stroke](painting.html#StrokeProperty) property. Since
['[text](text.html#TextElement)'] elements can be
rendered in multiple chunks, each chunk has its own [stroke
shape](painting.html#TermStrokeShape). The following algorithm describes
the ideal stroke shape of a
['[path](paths.html#PathElement)'], [basic
shape](shapes.html#TermBasicShapeElement) or individual
['[text](text.html#TextElement)'] chunk is, taking into
account the stroking properties above. The ideal stroke shape described
defines a best case implementation, but implementations are given some
leeway to deviate from this description for performance reasons.

Authors should be aware that the shape of a stroke may in some cases,
such as at extremely tight curves, differ across platforms.

![Image showing how stroke shape differs across platforms. One example
is as described by the algorithm in this specification, the other is
different and overall looks less correct. It is distinct in that the
geometry created to describe the left and right sides of the stroke are
distorted due to the proximity of the end of the curve to the section of
high
curvature.](images/painting/stroke-tight-corner-render-examples.png)

An example of how the shape painted for stroke may differ across
platforms.

The above example shows the possible rendered results for the following
two SVG paths:

 <svg viewBox="0 0 10 10" xmlns="http://www.w3.org/2000/svg">
 <path d="M 1,3 C 8,2 8,6 7,6" stroke-width="4" fill="none" stroke="skyblue"/>
 <path d="M 1,3 C 8,2 8,6 7,6" stroke-width="0.075" fill="none" stroke="black"/>
 </svg>

The ideal stroke shape is determined as follows:

1. Let `shape` be an empty shape.
2. If [stroke-width](painting.html#StrokeWidthProperty) \>
 0, then:
 1. Let `scale` be a scale factor for the dash pattern.
 If we are computing the stroke shape of a
 ['[text](text.html#TextElement)'] chunk, or if
 the ['[pathLength](paths.html#PathLengthAttribute)']
 attribute is not present on the element, then `scale`
 is 1. Otherwise, it is determined as follows:
 1. Let `length` be the user agent\'s computed length
 of the ['[path](paths.html#PathElement)'] or
 [equivalent path](paths.html#TermEquivalentPath) for a
 [basic shape](shapes.html#TermBasicShapeElement).
 2. Let `authorlength` be the value of the
 ['[pathLength](paths.html#PathLengthAttribute)']
 attribute on the [shape](shapes.html#TermShapeElement).
 3. `scale` is `authorlength` /
 `length`.
 2. Let `path` be the [equivalent
 path](paths.html#TermEquivalentPath) of the element (or the
 individual chunk of a
 ['[text](text.html#TextElement)'] element).
 3. For each subpath of `path`:
 1. Let `positions` be the [dash
 positions](painting.html#TermDashPositions) for the subpath.
 2. For each pair \<`start`, `end`\> in
 `positions`:
 1. Scale `start` and `end` by
 `scale`.

 2. Let `dash` be the shape that includes, for
 all distances between `start` and
 `end` along the subpath, all points that lie
 on the line perpendicular to the subpath at that
 distance and which are within distance
 [stroke-width](painting.html#StrokeWidthProperty)
 of the point on the subpath at that position.

 3. Set `dash` to be the union of
 `dash` and the starting [cap
 shape](painting.html#TermCapShape) for the subpath at
 position `start`.

 4. Set `dash` to be the union of
 `dash` and the ending [cap
 shape](painting.html#TermCapShape) for the subpath at
 position `end`.

 5. Let `index` and `last` be the
 indexes of the path segments in the subpath at distance
 `start` and `end` along the
 subpath.

 It does not matter whether any zero length segments are
 included when choosing `index` and
 `last`.

 6. While `index` \< `last`:
 1. Set `dash` to be the union of
 `dash` and the [line join
 shape](painting.html#TermLineJoinShape) for the
 subpath at segment index `index`.
 2. Set `index` to `index` + 1.

 7. Set `shape` to be the union of
 `shape` and `stroke`.
3. Return `shape`.

The [dash positions]
for a given subpath of the [equivalent
path](paths.html#TermEquivalentPath) of a
['[path](paths.html#PathElement)'] or [basic
shape](shapes.html#TermBasicShapeElement) is a sequence of pairs of
values, which represent the starting and ending distance along the
subpath for each of the dashes that form the subpath\'s stroke. It is
determined as follows:

1. Let `pathlength` be the length of the subpath.
2. Let `dashes` be the list of values of
 [stroke-dasharray](painting.html#StrokeDasharrayProperty)
 on the element, converted to user units, repeated if necessary so
 that it has an even number of elements; if the property has the
 value [none], then the list has a single value 0.
3. Let `count` be the number of values in
 `dashes`.
4. Let `sum` be the sum of the values in
 `dashes`.
5. If `sum` = 0, then return a sequence with the single pair
 \<0, `pathlength`\>.
6. Let `positions` be an empty sequence.
7. Let `offset` be the value of the
 [stroke-dashoffset](painting.html#StrokeDashoffsetProperty)
 property on the element.
8. If `offset` is negative, then set `offset` to
 `sum` − abs(`offset`).
9. Set `offset` to `offset` mod `sum`.
10. Let `index` be the smallest integer such that
 sum(`dashes`~`i`~, 0 ≤ `i` ≤
 `index`) ≥ `offset`.
11. Let `dashlength` be
 min(sum(`dashes`~`i`~, 0 ≤ `i` ≤
 `index`) − `offset`, `pathlength`).
12. If `index` mod 2 = 0, then append to
 `positions` the pair \<0, `dashlength`\>.
13. Let `position` be `dashlength`.
14. While `position` \< `pathlength`:
 1. Set `index` to (`index` + 1) mod
 `count`.
 2. Let `dashlength` be
 min(`dashes`~`index`~,
 `pathlength` − `position`).
 3. If `index` mod 2 = 0, then append to
 `positions` the pair \<`position`,
 `position` + `dashlength`\>.
 4. Set `position` to `position` +
 `dashlength`.
15. Return `positions`.

The starting and ending [cap shapes] at a given `position` along a subpath are
determined as follows:

1. If [stroke-linecap](painting.html#StrokeLinecapProperty)
 is [butt], then return an empty shape.
2. Otherwise, if
 [stroke-linecap](painting.html#StrokeLinecapProperty) is
 [round], then:
 1. If this is a starting cap, then return a semicircle of diameter
 [stroke-width](painting.html#StrokeWidthProperty)
 positioned such that:
 - The subpath that the semicircle is relative to is the subpath
 starting at distance `position`.
 - Its straight edge is parallel to the line perpendicular to the
 subpath at distance `position` along it.
 - The midpoint of its straight edge is at the point that is
 along the subpath at distance `position`.
 - The direction from the midpoint of its arc to the midpoint of
 its straight edge is the same as the direction of the subpath
 at distance `position`.
 2. Otherwise, this is an ending cap. Return a semicircle of
 diameter
 [stroke-width](painting.html#StrokeWidthProperty)
 positioned such that:
 - The subpath that the semicircle is relative to is the subpath
 ending at distance `position`.
 - Its straight edge is parallel to the line perpendicular to the
 subpath at distance `position` along it.
 - The midpoint of its straight edge is at the point that is
 along the subpath at distance `position`.
 - The direction from the midpoint of its straight edge to the
 midpoint of its arc is the same as the direction of the
 subpath.
3. Otherwise,
 [stroke-linecap](painting.html#StrokeLinecapProperty) is
 [square]:
 1. If this is a starting cap, then return a rectangle with side
 lengths
 [stroke-width](painting.html#StrokeWidthProperty) and
 [stroke-width](painting.html#StrokeWidthProperty) / 2
 positioned such that:
 - Its longer edges, `A` and `B`, are
 parallel to the line perpendicular to the subpath at distance
 `position` along it.
 - The midpoint of `A` is at `start`.
 - The direction from the midpoint of `B` to the
 midpoint of `A` is the same as the direction of the
 subpath at distance `position` along it.
 2. Otherwise, this is an ending cap. Return a rectangle with side
 lengths
 [stroke-width](painting.html#StrokeWidthProperty) and
 [stroke-width](painting.html#StrokeWidthProperty) / 2
 positioned such that:
 - Its longer edges, `A` and `B`, are
 parallel to the line perpendicular to the subpath at distance
 `position` along it.
 - The midpoint of `A` is at `end`.
 - The direction from the midpoint of `A` to the
 midpoint of `B` is the same as the direction of the
 subpath at distance `position` along it.

![Image showing how to construct the three types of line
caps](images/painting/linecap-construction.svg)

The three different
[stroke-linecap](painting.html#StrokeLinecapProperty) values
used on paths with a single, non-zero length subpath. The white line is
the path itself and the thick gray area is the stroke. On the top row,
the green lines indicate the perpendicular to the tangent at the path
endpoints and the pink areas are the caps. The bottom row shows the
stroke without the perpendicular and cap highlighting.

The [line join shape]
for a given segment of a subpath is determined as follows:

1. Let `P` be the point at the end of the segment.

2. If the unit tangent vector at the end of the segment and the unit
 tangent vector at the start of the following segment are equal, then
 return an empty shape.

 This means for example that [\'M 100,100 h 100 h 100\']
 would not produce a line join shape between the two straight line
 segment, but [\'M 100,100 h 100 h -100\'] would.

3. Let `A` be the line parallel to the tangent at the end of
 the segment.

4. Let `B` be the line parallel to the tangent at the start
 of the following segment.

5. Let `A`~`left`~ and
 `A`~`right`~ be lines parallel to
 `A` at a distance of
 [stroke-width](painting.html#StrokeWidthProperty) / 2 to
 the left and to the right of `A` relative to the subpath
 direction, respectively.

6. Let `B`~`left`~ and
 `B`~`right`~ be lines parallel to
 `B` at a distance of
 [stroke-width](painting.html#StrokeWidthProperty) / 2 to
 the left and to the right of `B`, relative to the subpath
 direction, respectively.

7. Let `P`~1~, `P`~2~ and `P`~3~ be
 points determined as follows:
 1. If the smaller angle between `A` and `B`
 is on the right of these lines, considering the direction of the
 subpath, then `P`~1~ and `P`~2~ are the
 points on `A`~`left`~ and
 `B`~`left`~ closest to `P`, and
 `P`~3~ is the intersection of
 `A`~`left`~ and
 `B`~`left`~.
 2. Otherwise, `P`~1~ and `P`~2~ are the
 points on `A`~`right`~ and
 `B`~`right`~ closest to `P`,
 and `P`~3~ is the intersection of
 `A`~`right`~ and
 `B`~`right`~.

8. Let `bevel` be the triangle formed from the three points
 `P`, `P`~1~ and `P`~2~.

9. If
 [stroke-linejoin](painting.html#StrokeLinejoinProperty)
 is [round], then return the union of `bevel`
 and a circular sector of diameter
 [stroke-width](painting.html#StrokeWidthProperty),
 centered on `P`, and which has `P`~1~ and
 `P`~2~ as the two endpoints of the arc.

10. If
 [stroke-linejoin](painting.html#StrokeLinejoinProperty)
 is [arcs], then find the circles that are tangent to
 the stroke edges at `P`~1~ and `P`~2~ with the
 same curvature as the edges at those points (see below). If both
 curvatures are zero fall through to [miter-clip]. If
 either curvature is greater than 2/(stroke width), fallback to
 [round]. Extend the stroke edges using these circles
 (or a line, in the case of zero curvature). If the two circles (or
 circle and line) do not intersect, adjust the radii of the two
 circles by an equal amount (or just the circle in case of a circle
 and line) until they do intersect (see below). The line join region
 is defined by the lines that connect `P` with
 `P`~1~ and `P`~2~ and the arcs defined by the
 circles (or arc and line) between the closest intersection point to
 `P`, and `P`~1~ and `P`~2~. Next
 calculate the *miter limit* as defined in the
 [stroke-miterlimit](painting.html#StrokeMiterlimitProperty)
 section. Clip any part of the line join region that extends past the
 miter limit. Return the resulting region. Note that the curvatures
 are calculated in user-space before any transforms are applied.

11. If
 [stroke-linejoin](painting.html#StrokeLinejoinProperty)
 is [miter] or [miter-clip] then the line
 join region is the union of `bevel` and the triangle
 formed from the three points `P`~1~, `P`~2~
 and `P`~3~.

12. Let `θ` be the angle between `A` and
 `B`. If 1 / sin(`θ` / 2) ≤
 [stroke-miterlimit](painting.html#StrokeMiterlimitProperty),
 then return the line join region.

13. If
 [stroke-linejoin](painting.html#StrokeLinejoinProperty)
 is [miter-clip], then clip any part of the line join
 region that extends past the miter limit and return this region.

14. Return `bevel`.

![Image showing the lines and points computed to construct a round line
join.](images/painting/linejoin-construction.svg)

Construction of a round line join shape, shown in pink. The white line
is the original path, which has two segments that come to a point, and
the gray region is the stroke.

![Image showing the lines and points computed to construct an arcs line
join.](images/painting/linejoin-construction-arcs.svg)

Construction of an arcs line join shape, shown in pink. The white line
is the original path, which has two segments that come to a point, and
the dark gray region is the stroke. The dashed lines show circles that
are tangent to and have the curvature of the segments at the join. The
olive-green circles (concentric with the dashed circles) define the join
shape.

### 13.5.8. Computing the circles for the [arcs] \'stroke-linejoin\'
The [arcs]
[stroke-linejoin](painting.html#StrokeLinejoinProperty)
requires finding circles that are both tangent to and have the same
curvatures as the outer stroke edges at the ends of path segments. To
find one of these circles, first calculate the curvature `κ`
of the path segment at its end (see below). Next, find the radius of a
circle corresponding to this curvature: `r` =
1/`κ`. Increase or decrease the radius by one half of the
stroke width to account for the stroke: `r`~`c`~ =
`r` ± ½ stroke-width. The center of the circle will be on a
line normal to the path end a distance of `r`~`c`~
away from the outer stroke edge at the end.

For a line: the curvature is zero. Extend the outer stroke edge by a
line.

For an elliptical arc:

::: { aria-describedby="math-curvature-of-ellipse"}
$$\kappa(t) = \frac{r_{x}r_{y}}{(r_{x}^{2}\sin^{2}t + r_{y}^{2}\cos^{2}t)^{3/2}}$$

```
$$\kappa(t) = {{r_x r_y}\over{(r_x^2 \sin^2 t + r_y^2 \cos^2 t)^{3/2}}}$$
```

where:

::: { aria-describedby="math-curvature-t"}
$$t = \arctan\left( {\frac{r_{y}}{r_{x}}\tan\theta} \right)$$

```
$$t = \arctan \left( {r_y \over r_x} \tan \theta \right)$$
```

The parameter `θ` at the beginning or end of an arc segment
can be found by using the formulas in the [Elliptical arc implementation
notes](implnote.html#ArcImplementationNotes). (Note, some renderers
convert elliptical arcs to cubic Béziers prior to rendering so the
equations here may not be needed.)

For a quadratic Bézier:

::: { aria-describedby="math-quadratic-start"}
$$\kappa(0) = \frac{1}{2}\frac{(P_{1} - P_{0}) \times (P_{2} - P_{1})}{|P_{1} - P_{0}|^{3}}$$

```
$$\kappa(0) = {2\over3}{(P_1-P_0)\times((P_0-P_1)+(P_2-P_1))\over|P_1-P_0|^3}$$
```

::: { aria-describedby="math-quadratic-end"}
$$\kappa(1) = \frac{1}{2}\frac{(P_{2} - P_{1}) \times (P_{0} - P_{1})}{|P_{2} - P_{1}|^{3}}$$

```
$$\kappa(0) = {2\over3}{(P_1-P_0)\times((P_0-P_1)+(P_2-P_1))\over|P_1-P_0|^3}$$
```

Where `κ(0)` and `κ(1)` are the signed curvatures
at the start and end of the path segment respectively, and the
`P`\'s are the three points that define the quadratic Bézier.

For a cubic Bézier:

::: { aria-describedby="math-cubic-start"}
$$\kappa(0) = \frac{2}{3}\frac{(P_{1} - P_{0}) \times (P_{2} - P_{1})}{|P_{1} - P_{0}|^{3}}$$

```
$$\kappa(0) = {2\over3}{(P_1-P_0)\times((P_0-P_1)+(P_2-P_1))\over|P_1-P_0|^3}$$
```

::: { aria-describedby="math-cubic-end"}
$$\kappa(1) = \frac{2}{3}\frac{(P_{3} - P_{2}) \times (P_{1} - P_{2})}{|P_{3} - P_{2}|^{3}}$$

```
$$\kappa(1) = {2\over3}{(P_3-P_2)\times((P_1-P_2)+(P_3-P_2))\over|P_3-P_2|^3}$$
```

Where `κ(0)` and `κ(1)` are the signed curvatures
at the start and end of the path segment respectively, and the
`P`\'s are the four points that define the cubic Bézier.
Note, if `P`~`0`~ and
`P`~`1`~, or `P`~`2`~ and
`P`~`3`~ are degenerate, the curvature will be
infinite and a line should be used in constructing the join.

### 13.5.9. Adjusting the circles for the [arcs] \'stroke-linejoin\' when the initial circles do not intersect
The fallback behavior was resolved at the [Sydney 2016
F2F](https://www.w3.org/2016/02/03-svg-minutes.html#item02). It gives a
smooth transition between the fallback and non-fallback states.

When the initial circles calculated for the [arcs]
[stroke-linejoin](painting.html#StrokeLinejoinProperty) do
not intersect, they need to be adjusted by changing both radii by the
same magnitude (moving the circle centers to keep the circles tangent to
the offset paths) until the circles just touch. There are two cases to
consider. The first is when one circle encloses the other circle. In
this case the larger circle is reduced in size while the smaller circle
is increased in size:

![Image showing the lines and points computed to construct an arcs line
join when the original offset circles do not
intersect.](images/painting/linejoin-construction-fallback.svg)

Construction of an arcs line join shape, shown in pink. The white line
is the original path and the dark gray region is the stroke. The dashed
lines show circles that are tangent to and have the curvature of the
segments at the join. Note the circles do not intersect. Two new circles
are constructed by adjusting the radii of the original circles by the
same magnitude with the larger circle being made smaller and the smaller
circle being made larger until the new circles just touch as shown by
the olive-green circles. These new circles then define the join shape.

The second case is when there is no overlap between the circles. In this
case the radii of both circles are increased by the same amount:

![Image showing the lines and points computed to construct an arcs line
join when the original offset circles do not
intersect.](images/painting/linejoin-construction-fallback2.svg)

Construction of an arcs line join shape, shown in pink. The white line
is the original path and the dark gray region is the stroke. The dashed
lines show circles that are tangent to and have the curvature of the
segments at the join. Note they do not intersect. Two new circles are
constructed by increasing the radii of the original circles by the same
amount until the new circles just touch as shown by the olive-green
circles. These new circles then define the join shape.

If in this latter case, the tangents of the offset paths at the line
join are parallel, the circles cannot be adjusted so that they touch.
The line join should then be constructed as a rectangle whose width is
the stroke width and whose length is the stroke width times one half of
the value of the
[stroke-miterlimit](painting.html#StrokeMiterlimitProperty):

![Image showing the lines and points computed to construct an arcs line
join when the original offset circles do not
intersect.](images/painting/linejoin-construction-fallback3.svg)

Construction of an arcs line join shape, shown in pink. The white line
is the original path, which has two segments that come to a point, and
the dark gray region is the stroke. The dashed lines show circles that
are tangent to and have the curvature of the segments at the join. Note
they do not intersect. Even if the radii of the circles are increased to
infinity, the circles will not intersect. The line join is then a
rectangle with the length determined by the miter limit (shown as a
vertical dashed line).

There are a couple of ways to implement the fallback algorithm. The
first way is by recursive trial and error on the magnitude of the radius
change. The second is by an exact calculation utilizing the *touching
circle condition* and the constraints that the centers of the circles
must remain on lines normal to the path segments at the join. This leads
to a quadratic equation where one solution is the required radius
change.

## 13.6. Vector effects
This chapter explains
[vector-effect](coords.html#VectorEffectProperty) related to
Painting. Please refer to [this](coords.html#VectorEffects) for the
perspective of
[vector-effect](coords.html#VectorEffectProperty).

non-scaling-stroke
: Modifies the way an object is stroked. Normally stroking involves
 calculating stroke outline of the shape\'s path in current [user
 coordinate
 system](https://drafts.csswg.org/css-transforms/#user-coordinate-system)
 and filling that outline with the stroke paint (color or gradient).
 With the non-scaling-stroke vector effect, stroke outline shall be
 calculated in the \"host\" coordinate space instead of [user
 coordinate
 system](https://drafts.csswg.org/css-transforms/#user-coordinate-system).
 More precisely: the [viewport coordinate
 system](coords.html#TermViewportCoordinateSystem) of the [furthest
 ancestral SVG
 viewport](coords.html#TermFurthestAncestorSVGViewport). The stroke
 outline is calculated in the following manner: first, the shape\'s
 path is transformed into the host coordinate space. Stroke outline
 is calculated in the host coordinate space. The resulting outline is
 transformed back to the [user coordinate
 system](https://drafts.csswg.org/css-transforms/#user-coordinate-system).
 (Stroke outline is always filled with stroke paint in the current
 user coordinate system). The resulting visual effect of this
 modification is that stroke width is not dependent on the
 transformations of the element (including non-uniform scaling and
 shear transformations) and zoom level.

::::::::::::: ready-for-wider-review
## 13.7. Markers
 -------------------- --------------------------------------------------------------------------------------
 SVG 2 Requirement: Improve markers.
 Resolution: [We will improve markers for SVG 2.](http://www.w3.org/2011/10/27-svg-irc#T18-12-30)
 Purpose: To solve the common problems authors have with SVG markers.
 Owner: Cameron ([ACTION-3286](http://www.w3.org/Graphics/SVG/WG/track/actions/3286))
 -------------------- --------------------------------------------------------------------------------------

A marker is a graphical object that is painted at particular positions
along any [shape](shapes.html#TermShapeElement) element.

The [marker-start](painting.html#MarkerStartProperty) and
[marker-end](painting.html#MarkerEndProperty) properties can
be used to place markers at the first and last vertex of a
[shape](shapes.html#TermShapeElement), and the
[marker-mid](painting.html#MarkerMidProperty) property can be
used to place markers at all other vertices (aside from the first and
last). The [marker-start](painting.html#MarkerStartProperty)
and [marker-end](painting.html#MarkerEndProperty) can be used
for example to add arrowheads to paths. Markers placed using these
properties are known as [vertex markers].

In SVG 2, vertex markers are the only kind of markers available. Other
specifications will add new types of markers.

The graphics for a marker are defined by a
['[marker](painting.html#MarkerElement)'] element. The
[marker-start](painting.html#MarkerStartProperty),
[marker-end](painting.html#MarkerEndProperty) and
[marker-mid](painting.html#MarkerMidProperty) properties,
together known as the [marker properties], reference
['[marker](painting.html#MarkerElement)'] elements.

Markers can be animated, and as with
['[use](struct.html#UseElement)'] elements, the animated
effects will show on all current uses of the markers within the
document.

Markers on a given element are painted in the following order, from
bottom to top:

- any marker specified by
 [marker-start](painting.html#MarkerStartProperty)
- the [marker-mid](painting.html#MarkerMidProperty) markers,
 in order of their position along the path
- any marker specified by
 [marker-end](painting.html#MarkerEndProperty)

### 13.7.1. The ['marker'] element
:::: element-summary
::: element-summary-name
['[marker]']

Categories:
: [Container element](struct.html#TermContainerElement),
 [never-rendered element](render.html#TermNeverRenderedElement)

Content model:
: Any number of the following elements, in any order:
 - [animation
 elements](https://svgwg.org/specs/animations/#TermAnimationElement)[
 ---
 ['[animate](https://svgwg.org/specs/animations/#AnimateElement)'],
 ['[animateMotion](https://svgwg.org/specs/animations/#AnimateMotionElement)'],
 ['[animateTransform](https://svgwg.org/specs/animations/#AnimateTransformElement)'],
 ['[set](https://svgwg.org/specs/animations/#SetElement)']]
 - [descriptive elements](struct.html#TermDescriptiveElement)[ ---
 ['[desc](struct.html#DescElement)'],
 ['[title](struct.html#TitleElement)'],
 ['[metadata](struct.html#MetadataElement)']]
 - [paint server elements](painting.html#TermPaintServerElement)[ ---
 ['[linearGradient](pservers.html#LinearGradientElement)'],
 ['[radialGradient](pservers.html#RadialGradientElement)'],
 ['[pattern](pservers.html#PatternElement)']]
 - [shape elements](shapes.html#TermShapeElement)[ ---
 ['[circle](shapes.html#CircleElement)'],
 ['[ellipse](shapes.html#EllipseElement)'],
 ['[line](shapes.html#LineElement)'],
 ['[path](paths.html#PathElement)'],
 ['[polygon](shapes.html#PolygonElement)'],
 ['[polyline](shapes.html#PolylineElement)'],
 ['[rect](shapes.html#RectElement)']]
 - [structural elements](struct.html#TermStructuralElement)[ ---
 ['[defs](struct.html#DefsElement)'],
 ['[g](struct.html#GElement)'],
 ['[svg](struct.html#SVGElement)'],
 ['[symbol](struct.html#SymbolElement)'],
 ['[use](struct.html#UseElement)']]

 [[a](linking.html#AElement)],
 [[clipPath](https://drafts.fxtf.org/css-masking-1/#ClipPathElement)],
 [[filter](https://drafts.fxtf.org/filter-effects/#FilterElement)],
 [[foreignObject](embedded.html#ForeignObjectElement)],
 [[image](embedded.html#ImageElement)],
 [[marker](painting.html#MarkerElement)],
 [[mask](https://drafts.fxtf.org/css-masking-1/#MaskElement)],
 [[script](interact.html#ScriptElement)],
 [[style](styling.html#StyleElement)],
 [[switch](struct.html#SwitchElement)],
 [[text](text.html#TextElement)],
 [[view](linking.html#ViewElement)]

Attributes:

: - [core attributes](struct.html#TermCoreAttribute)[ ---
 ['[id](struct.html#IDAttribute)'],
 ['[tabindex](struct.html#SVGElementTabindexAttribute)'],
 ['[autofocus](struct.html#SVGElementAutofocusAttribute)'],
 ['[lang](struct.html#LangAttribute)'],
 ['[xml:space](struct.html#XMLSpaceAttribute)'],
 ['[class](styling.html#ClassAttribute)'],
 ['[style](styling.html#StyleAttribute)']]
 - [global event
 attributes](https://html.spec.whatwg.org/multipage/webappapis.html#globaleventhandlers)[
 --- ['[oncancel](interact.html#EventAttributes)'],
 ['[oncanplay](interact.html#EventAttributes)'],
 ['[oncanplaythrough](interact.html#EventAttributes)'],
 ['[onchange](interact.html#EventAttributes)'],
 ['[onclick](interact.html#EventAttributes)'],
 ['[onclose](interact.html#EventAttributes)'],
 ['[oncopy](interact.html#EventAttributes)'],
 ['[oncuechange](interact.html#EventAttributes)'],
 ['[oncut](interact.html#EventAttributes)'],
 ['[ondblclick](interact.html#EventAttributes)'],
 ['[ondrag](interact.html#EventAttributes)'],
 ['[ondragend](interact.html#EventAttributes)'],
 ['[ondragenter](interact.html#EventAttributes)'],
 ['[ondragexit](interact.html#EventAttributes)'],
 ['[ondragleave](interact.html#EventAttributes)'],
 ['[ondragover](interact.html#EventAttributes)'],
 ['[ondragstart](interact.html#EventAttributes)'],
 ['[ondrop](interact.html#EventAttributes)'],
 ['[ondurationchange](interact.html#EventAttributes)'],
 ['[onemptied](interact.html#EventAttributes)'],
 ['[onended](interact.html#EventAttributes)'],
 ['[onerror](interact.html#EventAttributes)'],
 ['[onfocus](interact.html#EventAttributes)'],
 ['[oninput](interact.html#EventAttributes)'],
 ['[oninvalid](interact.html#EventAttributes)'],
 ['[onkeydown](interact.html#EventAttributes)'],
 ['[onkeypress](interact.html#EventAttributes)'],
 ['[onkeyup](interact.html#EventAttributes)'],
 ['[onload](interact.html#EventAttributes)'],
 ['[onloadeddata](interact.html#EventAttributes)'],
 ['[onloadedmetadata](interact.html#EventAttributes)'],
 ['[onloadstart](interact.html#EventAttributes)'],
 ['[onmousedown](interact.html#EventAttributes)'],
 ['[onmouseenter](interact.html#EventAttributes)'],
 ['[onmouseleave](interact.html#EventAttributes)'],
 ['[onmousemove](interact.html#EventAttributes)'],
 ['[onmouseout](interact.html#EventAttributes)'],
 ['[onmouseover](interact.html#EventAttributes)'],
 ['[onmouseup](interact.html#EventAttributes)'],
 ['[onpaste](interact.html#EventAttributes)'],
 ['[onpause](interact.html#EventAttributes)'],
 ['[onplay](interact.html#EventAttributes)'],
 ['[onplaying](interact.html#EventAttributes)'],
 ['[onprogress](interact.html#EventAttributes)'],
 ['[onratechange](interact.html#EventAttributes)'],
 ['[onreset](interact.html#EventAttributes)'],
 ['[onresize](interact.html#EventAttributes)'],
 ['[onscroll](interact.html#EventAttributes)'],
 ['[onseeked](interact.html#EventAttributes)'],
 ['[onseeking](interact.html#EventAttributes)'],
 ['[onselect](interact.html#EventAttributes)'],
 ['[onshow](interact.html#EventAttributes)'],
 ['[onstalled](interact.html#EventAttributes)'],
 ['[onsubmit](interact.html#EventAttributes)'],
 ['[onsuspend](interact.html#EventAttributes)'],
 ['[ontimeupdate](interact.html#EventAttributes)'],
 ['[ontoggle](interact.html#EventAttributes)'],
 ['[onvolumechange](interact.html#EventAttributes)'],
 ['[onwaiting](interact.html#EventAttributes)'],
 ['[onwheel](interact.html#EventAttributes)']]
 - [presentation attributes](styling.html#TermPresentationAttribute)[
 --- ]
 - ['[viewBox](coords.html#ViewBoxAttribute)']
 - ['[preserveAspectRatio](coords.html#PreserveAspectRatioAttribute)']
 - ['[refX](painting.html#MarkerElementRefXAttribute)']
 - ['[refY](painting.html#MarkerElementRefYAttribute)']
 - ['[markerUnits](painting.html#MarkerUnitsAttribute)']
 - ['[markerWidth](painting.html#MarkerWidthAttribute)']
 - ['[markerHeight](painting.html#MarkerHeightAttribute)']
 - ['[orient](painting.html#OrientAttribute)']

DOM Interfaces:

: - [SVGMarkerElement](painting.html#InterfaceSVGMarkerElement)

The ['[marker](painting.html#MarkerElement)'] element
defines the graphics that are to be used for drawing markers on a
[shape](shapes.html#TermShapeElement).

*Attribute definitions:*

 Name Value Initial value Animatable
 ---------------------------------------------------------------------------------------------- ------------------------------- --------------- ------------
 [markerUnits] strokeWidth \| userSpaceOnUse strokeWidth yes

The ['[markerUnits](painting.html#MarkerUnitsAttribute)']
attribute defines the coordinate system for attributes
['[markerWidth](painting.html#MarkerWidthAttribute)'],
['[markerHeight](painting.html#MarkerHeightAttribute)'] and
the contents of the
['[marker](painting.html#MarkerElement)']. Values have
the following meanings:

[strokeWidth]
: ['[markerWidth](painting.html#MarkerWidthAttribute)'],
 ['[markerHeight](painting.html#MarkerHeightAttribute)']
 and the contents of the
 ['[marker](painting.html#MarkerElement)'] have values
 in a coordinate system which has a single unit equal to the size in
 user units of the painted stroke width of the element referencing
 the marker.

[userSpaceOnUse]
: ['[markerWidth](painting.html#MarkerWidthAttribute)'],
 ['[markerHeight](painting.html#MarkerHeightAttribute)']
 and the contents of the
 ['[marker](painting.html#MarkerElement)'] have values
 in the current user coordinate system in place for the element
 referencing the marker.

When ['[markerUnits](painting.html#MarkerUnitsAttribute)']
has the value [strokeWidth], the size of the marker is
relative to the
[stroke-width](painting.html#StrokeWidthProperty) after it
has had any transforms applied that affect the width of the stroke in
the [user coordinate
system](https://drafts.csswg.org/css-transforms/#user-coordinate-system)
for the stroke. This means that, for example, the
[vector-effect](coords.html#VectorEffectProperty) attribute
with a value of [non-scaling-stroke] will result in the
markers also being non scaling.

 Name Value Initial value Animatable
 ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- -------------------------------------------------------------------------------------------------------------------------------------------------- --------------- ------------
 [markerWidth], [markerHeight] [\<length-percentage\>](https://www.w3.org/TR/css-values/#typedef-length-percentage) \| [\<number\>](https://www.w3.org/TR/css3-values/#numbers) 3 yes

The ['[markerWidth](painting.html#MarkerWidthAttribute)']
and ['[markerHeight](painting.html#MarkerHeightAttribute)']
attributes represent the size of the SVG viewport into which the marker
is to be fitted according to the
['[viewBox](coords.html#ViewBoxAttribute)'] and
['[preserveAspectRatio](coords.html#PreserveAspectRatioAttribute)']
attributes. A value of zero for either attribute results in nothing
being rendered for the marker. A negative value for either attribute is
an error (see [Error processing](conform.html#ErrorProcessing)).

 Name Value Initial value Animatable
 --------------------------------------------------------------------------------------------- ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- --------------- ------------
 [refX] [\<length-percentage\>](https://www.w3.org/TR/css-values/#typedef-length-percentage) \| [\<number\>](https://www.w3.org/TR/css3-values/#numbers) \| left \| center \| right 0 yes
 [refY] [\<length-percentage\>](https://www.w3.org/TR/css-values/#typedef-length-percentage) \| [\<number\>](https://www.w3.org/TR/css3-values/#numbers) \| top \| center \| bottom 0 yes

New in SVG 2: geometric keywords (matches use in
['[symbol](struct.html#SymbolElement)']).

We will add top/center/bottom, left/center/right keywords to refX/refY
on marker/symbol. Resolved at [London
F2F](http://www.w3.org/2014/08/26-svg-minutes.html#item07). Values
inspired by
[\'background-position\'](https://www.w3.org/TR/css3-background/#the-background-position).

The ['[refX](painting.html#MarkerElementRefXAttribute)'] and
['[refY](painting.html#MarkerElementRefYAttribute)']
attributes define the reference point of the marker, which is to be
placed exactly at the marker\'s position on the
[shape](shapes.html#TermShapeElement). Lengths and numbers must be
interpreted as being in the coordinate system of the marker contents,
after application of the
['[viewBox](coords.html#ViewBoxAttribute)'] and
['[preserveAspectRatio](coords.html#PreserveAspectRatioAttribute)']
attributes. Percentage values must be interpreted as being a percentage
of the ['[viewBox](coords.html#ViewBoxAttribute)'] width for
['[refX](painting.html#MarkerElementRefXAttribute)'] or a
percentage of the
['[viewBox](coords.html#ViewBoxAttribute)'] height for
['[refY](painting.html#MarkerElementRefYAttribute)'].

The keyword values must evaluate to the following percentages:

 keyword percentage equivalent
 --------- -----------------------
 left 0%
 center 50%
 right 100%
 top 0%
 bottom 100%

 : Mapping of refX and refY keywords to percentages.

 Name Value Initial value Animatable
 ------------------------------------------------------------------------------------ ------------------------------------------------------------------------------------------------------------------------------------------------- --------------- --------------------
 [orient] auto \| auto-start-reverse \| [\<angle\>](https://www.w3.org/TR/css-values/#angles) \| [\<number\>](https://www.w3.org/TR/css3-values/#numbers) 0 yes (non-additive)

The ['[orient](painting.html#OrientAttribute)'] attribute
indicates how the marker is rotated when it is placed at its position on
the [shape](shapes.html#TermShapeElement). Values have the following
meanings:

[\'auto\']

: The marker is oriented such that its positive x-axis is pointing in
 a direction relative to the path at the position the marker is
 placed (See [Rendering Markers](#RenderingMarkers)).

<!-- -->

[\'auto-start-reverse\']

: If placed by
 [marker-start](painting.html#MarkerStartProperty), the
 marker is oriented 180° different from the orientation that would be
 used if [\'auto\'] where specified. For all other
 markers, [\'auto-start-reverse\'] means the same as
 [\'auto\'].

 This allows a single arrowhead marker to be defined that can be used
 for both the start and end of a path, i.e. which points outwards
 from both ends.

<!-- -->

[[\<angle\>](https://www.w3.org/TR/css-values/#angles)]\
[[\<number\>](https://www.w3.org/TR/css3-values/#numbers)]

: The marker is oriented such that the specified angle is that
 measured between the [shape](shapes.html#TermShapeElement)\'s
 positive x-axis and the marker\'s positive x-axis. A
 [\<number\>](https://www.w3.org/TR/css3-values/#numbers) value
 specifies an angle in degrees.

 For example, if a value of [\'45\'] is given, then the
 marker\'s positive x-axis would be pointing down and right in the
 [shape](shapes.html#TermShapeElement)\'s coordinate system.

### 13.7.2. Vertex markers: the '[marker-start]', '[marker-mid]' and '[marker-end]' properties
 --------------------------------------------------------------------------- -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Name: [marker-start], [marker-mid], [marker-end]
 Value: none \| [\<marker-ref\>](painting.html#DataTypeMarkerRef)
 Initial: none
 Applies to: [shapes](shapes.html#TermShapeElement)
 Inherited: yes
 Percentages: N/A
 Media: visual
 Computed value: as specified, but with [\<url\>](https://www.w3.org/TR/css3-values/#url-value) values (that are part of a [\<marker-ref\>](painting.html#DataTypeMarkerRef)) made absolute
 [Animation type](https://www.w3.org/TR/web-animations-1/#animation-type): discrete
 --------------------------------------------------------------------------- -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

where:

[\<marker-ref\>] =
[\<url\>](https://www.w3.org/TR/css3-values/#url-value)

The [marker-start](painting.html#MarkerStartProperty) and
[marker-end](painting.html#MarkerEndProperty) properties are
used to specify the marker that will be drawn at the first and last
vertices of the given [shape](shapes.html#TermShapeElement),
respectively. [marker-mid](painting.html#MarkerMidProperty)
is used to specify the marker that will be drawn at all other vertices
(i.e., every vertex except the first and last). Possible values for
[marker-start](painting.html#MarkerStartProperty),
[marker-mid](painting.html#MarkerMidProperty) and
[marker-end](painting.html#MarkerEndProperty) are:

[none]
: Indicates that no marker symbol will be drawn at the given vertex or
 vertices.

[\<marker-ref\>]
: Indicates that the
 ['[marker](painting.html#MarkerElement)'] element
 referenced by the [\<marker-ref\>](painting.html#DataTypeMarkerRef)
 value will be drawn at the given vertex or vertices. If the
 reference is not valid, then no marker will be drawn at the given
 vertex or vertices.

For all [shapes](shapes.html#TermShapeElement), the path that must be
used when calculating marker positions is the [equivalent
path](paths.html#TermEquivalentPath).

::::: ready-for-wider-review
For all [shape](shapes.html#TermShapeElement) elements, except
['[polyline](shapes.html#PolylineElement)'] and
['[path](paths.html#PathElement)'], the last vertex is
the same as the first vertex. In this case, if the value of
[marker-start](painting.html#MarkerStartProperty) and
[marker-end](painting.html#MarkerEndProperty) are both not
[none], then two markers will be rendered on that final
vertex. For ['[path](paths.html#PathElement)'] elements,
for each [closed subpath](paths.html#TermOpenSubpath), the last vertex
is the same as the first vertex.
[marker-start](painting.html#MarkerStartProperty) must only
be rendered on the first vertex of the [path data](paths.html#PathData).
[marker-end](painting.html#MarkerEndProperty) must only be
rendered on the final vertex of the [path data](paths.html#PathData).
[marker-mid](painting.html#MarkerMidProperty) must be
rendered on every vertex other than the first vertex of the [path
data](paths.html#PathData) and the last vertex of the [path
data](paths.html#PathData).

 <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 30">
 <defs>
 <marker id="m1" viewBox="0 0 10 10" refX="5" refY="5"
 markerWidth="8" markerHeight="8">
 <circle cx="5" cy="5" r="5" fill="green"/>
 </marker>
 <marker id="m2" viewBox="0 0 10 10" refX="5" refY="5"
 markerWidth="6.5" markerHeight="6.5">
 <circle cx="5" cy="5" r="5" fill="skyblue" opacity="0.9"/>
 </marker>
 <marker id="m3" viewBox="0 0 10 10" refX="5" refY="5"
 markerWidth="5" markerHeight="5">
 <circle cx="5" cy="5" r="5" fill="maroon" opacity="0.85"/>
 </marker>
 </defs>

 <path d="M10,10 h10 v10 z m20,0 h10 v10 z m20,0 h10 v10 z"
 fill="none" stroke="black"
 marker-start="url(#m1)"
 marker-mid="url(#m2)"
 marker-end="url(#m3)"
 />
 </svg>

![Image showing that for closed subpaths, two markers are painted at the
start of each subpath.](images/painting/marker-doubled.svg)

For [path data](paths.html#PathData) containing [closed
subpaths](paths.html#TermOpenSubpath), two markers are drawn at the
first/last vertex of each [closed subpath](paths.html#TermOpenSubpath).
For the leftmost [closed subpath](paths.html#TermOpenSubpath), a
[marker-mid](painting.html#MarkerMidProperty) is drawn over
the [marker-start](painting.html#MarkerStartProperty). For
the middle [closed subpath](paths.html#TermOpenSubpath), two
[marker-mid](painting.html#MarkerMidProperty) are drawn on
top of one another. For the rightmost [closed
subpath](paths.html#TermOpenSubpath),
[marker-end](painting.html#MarkerEndProperty) is drawn over
[marker-mid](painting.html#MarkerMidProperty).

Note that [marker-start](painting.html#MarkerStartProperty)
and [marker-end](painting.html#MarkerEndProperty) refer to
the first and last vertex of the entire path, not each subpath.

::::: ready-for-wider-review

The following example shows a triangular marker symbol used as a [vertex
marker](painting.html#TermVertexMarker) to form an arrowhead at the end
of two paths.

 <svg xmlns="http://www.w3.org/2000/svg"
 width="275" height="200" viewBox="0 0 275 200">
 <defs>
 <marker id="Triangle" viewBox="0 0 10 10" refX="1" refY="5"
 markerUnits="strokeWidth" markerWidth="4" markerHeight="3"
 orient="auto">
 <path d="M 0 0 L 10 5 L 0 10 z" fill="context-stroke"/>
 </marker>
 </defs>

 <g fill="none" stroke-width="10" marker-end="url(#Triangle)">
 <path stroke="crimson" d="M 100,75 C 125,50 150,50 175,75"/>
 <path stroke="olivedrab" d="M 175,125 C 150,150 125,150 100,125"/>
 </g>
 </svg>

![Image showing the use of an automatically oriented
marker.](images/painting/marker-rendering.svg)

The triangle is placed at the end of the path and oriented automatically
so that it points in the right direction. The use of
[context-stroke] ensures the fill of the triangle matches
the stroke of each ['[path](paths.html#PathElement)'].

### 13.7.3. Marker shorthand: the '[marker]' property
 --------------------------------------------------------------------------- --------------------------------------------------------------
 Name: [marker]
 Value: none \| [\<marker-ref\>](painting.html#DataTypeMarkerRef)
 Initial: not defined for shorthand properties
 Applies to: [shapes](shapes.html#TermShapeElement)
 Inherited: yes
 Percentages: N/A
 Media: visual
 Computed value: see individual properties
 [Animation type](https://www.w3.org/TR/web-animations-1/#animation-type): discrete
 --------------------------------------------------------------------------- --------------------------------------------------------------

The [marker](painting.html#MarkerProperty) property sets
values for the
[marker-start](painting.html#MarkerStartProperty),
[marker-mid](painting.html#MarkerMidProperty) and
[marker-end](painting.html#MarkerEndProperty) properties. The
value of the [marker](painting.html#MarkerProperty) is used
directly for all three of the corresponding longhand properties.

### 13.7.4. Rendering markers
When orienting a marker automatically, due to specifying
['[orient](painting.html#OrientAttribute)'] as
[\'auto\'], the following rules are used:

- If the vertex is the start or end of an [open
 subpath](paths.html#TermClosedSubpath), then the marker is oriented in
 the [path direction](paths.html#TermPathDirection).
- Otherwise, the marker is oriented in a direction half way between the
 [direction at the end of the preceding
 segment](paths.html#TermPathSegmentEndDirection) and the [direction at
 the start of the following
 segment](paths.html#TermPathSegmentStartDirection).

For each marker that is drawn, a temporary new user coordinate system is
established so that the marker will be positioned and sized correctly,
as follows:

- The axes of the temporary new user coordinate system are aligned
 according to the
 ['[orient](painting.html#OrientAttribute)'] attribute on
 the ['[marker](painting.html#MarkerElement)'] element.
- A temporary new coordinate system is established by attribute
 ['[markerUnits](painting.html#MarkerUnitsAttribute)']. If
 ['[markerUnits](painting.html#MarkerUnitsAttribute)']
 equals [\'strokeWidth\'], then the temporary new user
 coordinate system is the result of scaling the current user coordinate
 system by the current value of property
 [stroke-width](painting.html#StrokeWidthProperty). If
 ['[markerUnits](painting.html#MarkerUnitsAttribute)']
 equals [\'userSpaceOnUse\'], then no extra scale
 transformation is applied.
- An additional set of transformations might occur if the
 ['[marker](painting.html#MarkerElement)'] element
 includes a ['[viewBox](coords.html#ViewBoxAttribute)']
 attribute, in which case additional transformations are set up to
 produce the necessary result due to attributes
 ['[viewBox](coords.html#ViewBoxAttribute)'] and
 ['[preserveAspectRatio](coords.html#PreserveAspectRatioAttribute)'].
- If the [overflow](render.html#OverflowAndClipProperties)
 property on the
 ['[marker](painting.html#MarkerElement)'] element
 indicates that the marker needs to be clipped to its SVG viewport,
 then an implicit clipping path is established at the bounds of the SVG
 viewport.

Note that the [user agent style sheet](styling.html#UAStyleSheet) sets
the [overflow](render.html#OverflowAndClipProperties)
property for ['[marker](painting.html#MarkerElement)']
elements to [hidden], which causes a rectangular clipping
path to be created at the bounds of marker\'s SVG viewport by default.

Properties do not inherit from the element referencing the
['[marker](painting.html#MarkerElement)'] into the
contents of the marker. However, by using the
[context-stroke] value for the
[fill](painting.html#FillProperty) or
[stroke](painting.html#StrokeProperty) on elements in its
definition, a single marker can be designed to match the style of the
element referencing the marker.

Markers cannot be interacted with. Events such as click or mouseover,
for example, are not dispatched to a
['[marker](painting.html#MarkerElement)'] or its children
when the mouse is clicked or moved over a rendered marker.

Markers are not rendered directly and must be referenced by one of the
[marker properties](painting.html#TermMarkerProperties) to be rendered.
The [display](render.html#VisibilityControl) value for the
['[marker](painting.html#MarkerElement)'] element must
always be set to [none] by the [user agent style
sheet](styling.html#UAStyleSheet), and this declaration must have
importance over any other CSS rule or presentation attribute.
['[marker](painting.html#MarkerElement)'] elements are
available for referencing even when the
[display](render.html#VisibilityControl) property on the
['[marker](painting.html#MarkerElement)'] element or any
of its ancestors is set to [none].

The rendering effect of a marker is as if the contents of the referenced
['[marker](painting.html#MarkerElement)'] element were
deeply cloned into a separate non-exposed DOM tree for each instance of
the marker. Because the cloned DOM tree is non-exposed, the SVG DOM does
not show the cloned instance of the marker.

The conceptual deep cloning of the referenced
['[marker](painting.html#MarkerElement)'] element into a
non-exposed DOM tree also copies any property values resulting from [the
CSS cascade](https://www.w3.org/TR/2011/REC-CSS2-20110607/cascade.html)
(\[[CSS2](refs.html#ref-css2)\], chapter 6) and property inheritance on
the referenced element and its contents. CSS selectors can be applied to
the original (i.e., referenced) elements because they are part of the
formal document structure. CSS selectors cannot be applied to the
(conceptually) cloned DOM tree because its contents are not part of the
formal document structure.

For illustrative purposes, we\'ll repeat the marker example shown
earlier:

 <?xml version="1.0" standalone="no"?>
 <svg width="4in" height="2in"
 viewBox="0 0 4000 2000"
 xmlns="http://www.w3.org/2000/svg">
 <defs>
 <marker id="Triangle"
 viewBox="0 0 10 10" refX="0" refY="5"
 markerUnits="strokeWidth"
 markerWidth="4" markerHeight="3"
 orient="auto">
 <path d="M 0 0 L 10 5 L 0 10 z" />
 </marker>
 </defs>
 <rect x="10" y="10" width="3980" height="1980"
 fill="none" stroke="blue" stroke-width="10" />
 <desc>Placing an arrowhead at the end of a path.
 </desc>
 <path d="M 1000 750 L 2000 750 L 2500 1250"
 fill="none" stroke="black" stroke-width="100"
 marker-end="url(#Triangle)" />
 </svg>

The rendering effect of the above file will be visually identical to the
following:

 <?xml version="1.0" standalone="no"?>
 <svg width="4in" height="2in"
 viewBox="0 0 4000 2000"
 xmlns="http://www.w3.org/2000/svg">
 <desc>File which produces the same effect
 as the marker example file, but without
 using markers.
 </desc>
 <rect x="10" y="10" width="3980" height="1980"
 fill="none" stroke="blue" stroke-width="10" />
 <!-- The path draws as before, but without the marker properties -->
 <path d="M 1000 750 L 2000 750 L 2500 1250"
 fill="none" stroke="black" stroke-width="100" />
 <!-- The following logic simulates drawing a marker
 at final vertex of the path. -->
 <!-- First off, move the origin of the user coordinate system
 so that the origin is now aligned with the end point of the path. -->
 <g transform="translate(2500,1250)" >
 <!-- Rotate the coordinate system 45 degrees because
 the marker specified orient="auto" and the final segment
 of the path is going in the direction of 45 degrees. -->
 <g transform="rotate(45)" >
 <!-- Scale the coordinate system to match the coordinate system
 indicated by the 'markerUnits' attributes, which in this case has
 a value of 'strokeWidth'. Therefore, scale the coordinate system
 by the current value of the 'stroke-width' property, which is 100. -->
 <g transform="scale(100)" >
 <!-- Translate the coordinate system by
 (-refX*viewBoxToMarkerUnitsScaleX, -refY*viewBoxToMarkerUnitsScaleY)
 in order that (refX,refY) within the marker will align with the vertex.
 In this case, we use the default value for preserveAspectRatio
 ('xMidYMid meet'), which means find a uniform scale factor
 (i.e., viewBoxToMarkerUnitsScaleX=viewBoxToMarkerUnitsScaleY)
 such that the viewBox fits entirely within the SVG viewport ('meet') and
 is center-aligned ('xMidYMid'). In this case, the uniform scale factor
 is markerHeight/viewBoxHeight=3/10=.3. Therefore, translate by
 (-refX*.3,-refY*.3)=(0*.3,-5*.3)=(0,-1.5). -->
 <g transform="translate(0,-1.5)" >
 <!-- There is an implicit clipping path because the user agent style
 sheet says that the 'overflow' property for markers has the value
 'hidden'. To achieve this, create a clipping path at the bounds
 of the SVG viewport. Note that in this case the SVG viewport extends
 0.5 units to the left and right of the viewBox due to
 a uniform scale factor, different ratios for markerWidth/viewBoxWidth
 and markerHeight/viewBoxHeight, and 'xMidYMid' alignment -->
 <clipPath id="cp1" >
 <rect x="-0.5" y="0" width="4" height="3" />
 </clipPath>
 <g clip-path="url(#cp1)" >
 <!-- Scale the coordinate system by the uniform scale factor
 markerHeight/viewBoxHeight=3/10=.3 to set the coordinate
 system to viewBox units. -->
 <g transform="scale(.3)" >
 <!-- This 'g' element carries all property values that result from
 cascading and inheritance of properties on the original 'marker' element.
 In this example, neither fill nor stroke was specified on the 'marker'
 element or any ancestors of the 'marker', so the initial values of
 "black" and "none" are used, respectively. -->
 <g fill="black" stroke="none" >
 <!-- Expand out the contents of the 'marker' element. -->
 <path d="M 0 0 L 10 5 L 0 10 z" />
 </g>
 </g>
 </g>
 </g>
 </g>
 </g>
 </g>
 </svg>

[View this example as SVG (SVG-enabled browsers
only)](images/painting/marker-simulated.svg)

:::::: ready-for-wider-review
## 13.8. Controlling paint operation order: the '[paint-order]' property
 -------------------- ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 SVG 2 Requirement: Support control of the order of filling, stroke and painting markers on shapes.
 Resolution: [SVG 2 will adopt the '[paint-order]' property proposal, though possibly with a different name.](http://www.w3.org/2012/05/07-svg-minutes#item03) The property name is now resolved, see [15 Nov 2013 minutes](http://www.w3.org/2013/11/15-svg-minutes.html#item12).
 Purpose: To address the common desire to paint strokes below fills without having to duplicate an element.
 Owner: Cameron ([ACTION-3285](http://www.w3.org/Graphics/SVG/WG/track/actions/3285))
 -------------------- ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

 --------------------------------------------------------------------------- ------------------------------------------------------------------------------------------------------
 Name: [paint-order]
 Value: normal \| \[ fill \|\| stroke \|\| markers \]
 Initial: normal
 Applies to: [shapes](shapes.html#TermShapeElement) and [text content elements](text.html#TermTextContentElement)
 Inherited: yes
 Percentages: N/A
 Media: visual
 Computed value: as specified
 [Animation type](https://www.w3.org/TR/web-animations-1/#animation-type): discrete
 --------------------------------------------------------------------------- ------------------------------------------------------------------------------------------------------

New in SVG 2. Added primarily to allow painting the stroke of text below
its fill without needing to duplicate the
['[text](text.html#TextElement)'] element.

The [paint-order](painting.html#PaintOrderProperty) property
controls the order that the three paint operations that
[shapes](shapes.html#TermShapeElement) and text are rendered with: their
fill, their stroke and any markers they might have.

When the value of this property is [normal], the element is
painted with the standard order of painting operations: the fill is
painted first, then its stroke and finally its markers.

When any of the other keywords are used, the order of the paint
operations for painting the element is as given, from left to right. If
any of the three keywords are omitted, they are painted last, in the
order they would be painted with [paint-order: normal].

This means that, for example, [paint-order: stroke] has the
same rendering behavior as [paint-order: stroke fill
markers].

The following example shows how the
[paint-order](painting.html#PaintOrderProperty) property can
be used to render stroked text in a more aesthetically pleasing manner.

 <svg xmlns="http://www.w3.org/2000/svg"
 width="600" height="150" viewBox="0 0 600 150">

 <style>
 text {
 font: 80px bold sans-serif; stroke-linejoin: round;
 text-anchor: middle; fill: peachpuff; stroke: crimson;
 }
 </style>

 <text x="150" y="100" style="stroke-width: 6px;">pizazz</text>
 <text x="450" y="100" style="stroke-width: 12px; paint-order: stroke;">pizazz</text>
 </svg>

![Image showing the effect of
paint-order.](images/painting/paintorder.svg)

Text painted with its stroke below the fill.

::: ready-for-wider-review
## 13.9. Color space for interpolation: the '[color-interpolation]' property
 --------------------------------------------------------------------------- -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Name: [color-interpolation]
 Value: auto \| sRGB \| linearRGB
 Initial: sRGB
 Applies to: [container elements](struct.html#TermContainerElement), [graphics elements](struct.html#TermGraphicsElement), [gradient elements](pservers.html#TermGradientElement), ['[use](struct.html#UseElement)'] and ['[animate](https://svgwg.org/specs/animations/#AnimateElement)']
 Inherited: yes
 Percentages: N/A
 Media: visual
 Computed value: as specified
 [Animation type](https://www.w3.org/TR/web-animations-1/#animation-type): discrete
 --------------------------------------------------------------------------- -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

The SVG user agent performs color interpolations and compositing at
various points as it processes SVG content. The
[color-interpolation](painting.html#ColorInterpolationProperty)
property controls which color space is used for the following graphics
operations:

- interpolating between [gradient](pservers.html#Gradients) stops,
- interpolating color when performing color animations with
 ['[animate](https://svgwg.org/specs/animations/#AnimateElement)'],
- and [compositing and blending](render.html#PaintersModel) of [graphics
 elements](struct.html#TermGraphicsElement) into the current
 background.

For [filter effects](https://www.w3.org/TR/filter-effects/), the
[color-interpolation-filters](https://drafts.fxtf.org/filter-effects/#ColorInterpolationFiltersProperty)
property controls which color space is used.
\[[filter-effects-1](refs.html#ref-filter-effects-1)\]

:::::: ready-for-wider-review
The
[color-interpolation](painting.html#ColorInterpolationProperty)
property chooses between color operations occurring in the sRGB color
space or in a (light energy linear) linearized RGB color space. Having
chosen the appropriate color space, component-wise linear interpolation
is used. Values for
[color-interpolation](painting.html#ColorInterpolationProperty)
have the following meanings:

[auto]
: Indicates that the user agent can choose either the
 [sRGB] or [linearRGB] spaces for color
 interpolation. This option indicates that the author doesn\'t
 require that color interpolation occur in a particular color space.

[sRGB]
: Indicates that color interpolation occurs in the sRGB color space.

[linearRGB]
: Indicates that color interpolation occurs in the linearized RGB
 color space as described below.

The conversion formulas between the sRGB color space (i.e., nonlinear
with 2.2 gamma curve) and the linearized RGB color space (i.e., color
values expressed as sRGB tristimulus values without a gamma curve) can
be found in [the sRGB
specification](https://webstore.iec.ch/publication/6168)
\[[SRGB](refs.html#ref-srgb)\]. For illustrative purposes, the following
formula shows the conversion from sRGB to linearized RGB, where
`C`~`srgb`~ is one of the three sRGB color
components, `C`~`linear`~ is the corresponding
linearized RGB color component, and all color values are between 0 and
1:

::: { aria-describedby="math-linearRGB"}
$$C_{linear} = \begin{cases}
\frac{C_{srgb}}{12.92} & {\text{if~}C_{srgb} \leq 0.04045} \\
\left( \frac{C_{srgb} + 0.055}{1.055} \right)^{2.4} & {\text{if~}C_{srgb} > 0.04045}
\end{cases}$$

```

if C_srgb <= 0.04045
 C_linear = C_srgb / 12.92
else if c_srgb > 0.04045
 C_linear = ((C_srgb + 0.055) / 1.055) ^ 2.4
```

Out-of-range color values, if supported by the user agent, also are
converted using the above formulas.

When a child element is blended into a background, the value of the
[color-interpolation](painting.html#ColorInterpolationProperty)
property on the child determines the type of blending, not the value of
the
[color-interpolation](painting.html#ColorInterpolationProperty)
on the parent. For [gradients](pservers.html#Gradients) which make use
of the ['href'] attribute to reference another gradient, the
gradient uses the
[color-interpolation](painting.html#ColorInterpolationProperty)
property value from the gradient element which is directly referenced by
the [fill](painting.html#FillProperty) or
[stroke](painting.html#StrokeProperty) property. When
animating colors, color interpolation is performed according to the
value of the
[color-interpolation](painting.html#ColorInterpolationProperty)
property on the element being animated.

## 13.10. Rendering hints
### 13.10.1. The '[shape-rendering]' property
 --------------------------------------------------------------------------- -------------------------------------------------------------------------------
 Name: [shape-rendering]
 Value: auto \| optimizeSpeed \| crispEdges \| geometricPrecision
 Initial: auto
 Applies to: [shapes](shapes.html#TermShapeElement)
 Inherited: yes
 Percentages: N/A
 Media: visual
 Computed value: as specified
 [Animation type](https://www.w3.org/TR/web-animations-1/#animation-type): discrete
 --------------------------------------------------------------------------- -------------------------------------------------------------------------------

The [shape-rendering](painting.html#ShapeRenderingProperty)
property provides a hint to the implementation about what tradeoffs to
make as it renders vector graphics elements such as
['[path](paths.html#PathElement)'] elements and [basic
shapes](shapes.html) such as circles and rectangles. Values have the
following meanings:

[auto]
: Indicates that the user agent shall make appropriate tradeoffs to
 balance speed, crisp edges and geometric precision, but with
 geometric precision given more importance than speed and crisp
 edges.

[optimizeSpeed]
: Indicates that the user agent shall emphasize rendering speed over
 geometric precision and crisp edges. This option will sometimes
 cause the user agent to turn off shape anti-aliasing.

[crispEdges]
: Indicates that the user agent shall attempt to emphasize the
 contrast between clean edges of artwork over rendering speed and
 geometric precision. To achieve crisp edges, the user agent might
 turn off anti-aliasing for all lines and curves or possibly just for
 straight lines which are close to vertical or horizontal. Also, the
 user agent might adjust line positions and line widths to align
 edges with device pixels.

[geometricPrecision]
: Indicates that the user agent shall emphasize geometric precision
 over speed and crisp edges.

### 13.10.2. The '[text-rendering]' property
 --------------------------------------------------------------------------- -----------------------------------------------------------------------------
 Name: [text-rendering]
 Value: auto \| optimizeSpeed \| optimizeLegibility \| geometricPrecision
 Initial: auto
 Applies to: ['[text](text.html#TextElement)']
 Inherited: yes
 Percentages: N/A
 Media: visual
 Computed value: as specified
 [Animation type](https://www.w3.org/TR/web-animations-1/#animation-type): discrete
 --------------------------------------------------------------------------- -----------------------------------------------------------------------------

The [text-rendering](painting.html#TextRenderingProperty)
property provides a hint to the implementation about what tradeoffs to
make as it renders text. Values have the following meanings:

[auto]
: Indicates that the user agent shall make appropriate tradeoffs to
 balance speed, legibility and geometric precision, but with
 legibility given more importance than speed and geometric precision.

[optimizeSpeed]
: Indicates that the user agent shall emphasize rendering speed over
 legibility and geometric precision. This option will sometimes cause
 the user agent to turn off text anti-aliasing.

[optimizeLegibility]
: Indicates that the user agent shall emphasize legibility over
 rendering speed and geometric precision. The user agent will often
 choose whether to apply anti-aliasing techniques, built-in font
 hinting or both to produce the most legible text.

[geometricPrecision]
: Indicates that the user agent shall emphasize geometric precision
 over legibility and rendering speed. This option will usually cause
 the user agent to suspend the use of hinting so that glyph outlines
 are drawn with comparable geometric precision to the rendering of
 path data.

### 13.10.3. The '[image-rendering]' property
 --------------------------------------------------------------------------- -------------------------------------------------------------------------------
 Name: [image-rendering]
 Value: auto \| optimizeQuality \| optimizeSpeed
 Initial: auto
 Applies to: images
 Inherited: yes
 Percentages: N/A
 Media: visual
 Computed value: as specified
 [Animation type](https://www.w3.org/TR/web-animations-1/#animation-type): discrete
 --------------------------------------------------------------------------- -------------------------------------------------------------------------------

The [CSS Image Values and Replacement Content Module Level
4](http://dev.w3.org/csswg/css-images/#the-image-rendering) may in the
future redefine this property. In particular it should allow the choice
between smoothing and keeping a pixelated look when upscaling.

The [image-rendering](painting.html#ImageRenderingProperty)
property provides a hint to the implementation about how to make speed
vs. quality tradeoffs as it performs image processing. Values have the
following meanings:

[auto]
: Indicates that the user agent shall make appropriate tradeoffs to
 balance speed and quality, but quality shall be given more
 importance than speed. The user agent shall employ a resampling
 algorithm at least as good as nearest neighbor resampling, but
 bilinear resampling is strongly preferred. For [conforming
 high-quality SVG viewers](conform.html#ConformingSVGViewers), the
 user agent shall employ a resampling algorithm at least as good as
 bilinear resampling.

[optimizeQuality]
: Indicates that the user agent shall emphasize quality over rendering
 speed. The user agent shall employ a resampling algorithm at least
 as good as bilinear resampling.

[optimizeSpeed]
: Indicates that the user agent shall emphasize rendering speed over
 quality. The user agent should use a resampling algorithm which
 achieves the goal of fast rendering, with the requirement that the
 resampling algorithm shall be at least as good as nearest neighbor
 resampling. If performance goals can be achieved with higher quality
 algorithms, then the user agent should use the higher quality
 algorithms instead of nearest neighbor resampling.

In all cases, resampling must be done in a truecolor (e.g., 24-bit)
color space even if the original data and/or the target device is
indexed color. High quality SVG viewers should perform image resampling
using a linear color space.

## 13.11. The effect of the '[will-change]' property
See the CSS Will Change Module Level 1 specification for the definition
of
[will-change](https://drafts.csswg.org/css-will-change/#will-change).

The
[will-change](https://drafts.csswg.org/css-will-change/#will-change)
property is used to provide a hint to the user agent as to the types of
changes that will be made to content, giving the user agent a better
chance at performing rendering optimizations for a given element.

The
[will-change](https://drafts.csswg.org/css-will-change/#will-change)
property applies to all SVG [graphics
elements](struct.html#TermGraphicsElement), however since SVG elements
do not support scrolling, the [scroll-position] value will
have no effect on them.

The following example demonstrates how
[will-change](https://drafts.csswg.org/css-will-change/#will-change)
can be used to forewarn the user agent that an element will have its
[transform](coords.html#TransformProperty) property changed,
with the potential result of the user agent rendering the element into
its own GPU layer so that the scripted
[transform](coords.html#TransformProperty) changes appear
smooth.

 <svg xmlns="http://www.w3.org/2000/svg">
 <style>
 #background { fill: lemonchiffon; }
 #star {
 fill: cornflowerblue;
 stroke: navy; stroke-width: 5px; stroke-linejoin: round;
 paint-order: stroke fill;
 will-change: transform;
 }
 text { font: 24px sans-serif; user-select: none; }
 </style>
 <g onmousemove="drag(evt.clientX, evt.clientY);"
 onmouseup="dragging = false;">
 <rect id="background" width="100%" height="100%"/>
 <text x="10" y="30">Drag the star!</text>
 <path id="star" transform="translate(200,150)"
 d="M 0.00,-40.00 -11.76,-16.18 -38.04,-12.36 -19.02,6.18 -23.51,32.36
 0.00,20.00 23.51,32.36 19.02,6.18 38.04,-12.36 11.76,-16.18 z"
 onmousedown="dragging = true;"/>
 </g>
 <script>
 var dragging = false;
 var star = document.getElementById("star");
 function drag(x, y) {
 if (dragging) {
 star.setAttribute("transform", "translate(" + x + "," + y + ")");
 }
 }
 </script>
 </svg>

![A blue star with the text \"Drag the star!\"
above.](images/painting/will-change-image.svg)

In a user agent that supports
[will-change](https://drafts.csswg.org/css-will-change/#will-change)
on SVG elements, the star might be rendered into a layer so that it can
be composited quickly when it is dragged around the canvas. [View
interactive SVG document.](images/painting/will-change.svg)

[will-change](https://drafts.csswg.org/css-will-change/#will-change)
property replaces the '[buffered-rendering]' property defined
in SVG Tiny 1.2.

::: ready-for-wider-review
## 13.12. DOM interfaces
### 13.12.1. Interface SVGMarkerElement
An
[SVGMarkerElement](painting.html#InterfaceSVGMarkerElement)
object represents a
['[marker](painting.html#MarkerElement)'] element in the
DOM.

``` idl
[Exposed=Window]
interface SVGMarkerElement : SVGElement {

 // Marker Unit Types
 const unsigned short SVG_MARKERUNITS_UNKNOWN = 0;
 const unsigned short SVG_MARKERUNITS_USERSPACEONUSE = 1;
 const unsigned short SVG_MARKERUNITS_STROKEWIDTH = 2;

 // Marker Orientation Types
 const unsigned short SVG_MARKER_ORIENT_UNKNOWN = 0;
 const unsigned short SVG_MARKER_ORIENT_AUTO = 1;
 const unsigned short SVG_MARKER_ORIENT_ANGLE = 2;
 const unsigned short SVG_MARKER_ORIENT_AUTO_START_REVERSE = 3;

 [SameObject] readonly attribute SVGAnimatedLength refX;
 [SameObject] readonly attribute SVGAnimatedLength refY;
 [SameObject] readonly attribute SVGAnimatedEnumeration markerUnits;
 [SameObject] readonly attribute SVGAnimatedLength markerWidth;
 [SameObject] readonly attribute SVGAnimatedLength markerHeight;
 [SameObject] readonly attribute SVGAnimatedEnumeration orientType;
 [SameObject] readonly attribute SVGAnimatedAngle orientAngle;
 attribute DOMString orient;

 undefined setOrientToAuto();
 undefined setOrientToAngle(SVGAngle angle);
};

SVGMarkerElement includes SVGFitToViewBox;
```

The numeric marker unit type constants defined on
[SVGMarkerElement](painting.html#InterfaceSVGMarkerElement)
are used to represent the keyword values that the
['[markerUnits](painting.html#MarkerUnitsAttribute)']
attribute can take. Their meanings are as follows:

 Constant Meaning
 ------------------------------------ --------------------------------------------
 **SVG_MARKERUNITS_USERSPACEONUSE** The [userSpaceOnUse] keyword.
 **SVG_MARKERUNITS_STROKEWIDTH** The [strokeWidth] keyword.
 **SVG_MARKERUNITS_UNKNOWN** Some other value.

The numeric marker orientation type constants defined on
[SVGMarkerElement](painting.html#InterfaceSVGMarkerElement)
are used to represent the types of values that the
['[orient](painting.html#OrientAttribute)'] attribute can
take. Their meanings are as follows:

 Constant Meaning
 ------------------------------------------ --------------------------------------------------------------------------------------------------------------------------------------------------------------
 **SVG_MARKER_ORIENT_AUTO** The [auto] keyword.
 **SVG_MARKER_ORIENT_AUTO_START_REVERSE** The [auto-start-reverse] keyword.
 **SVG_MARKER_ORIENT_ANGLE** An [\<angle\>](https://www.w3.org/TR/css-values/#angles) or [\<number\>](https://www.w3.org/TR/css3-values/#numbers) value indicating the orientation angle.
 **SVG_MARKER_ORIENT_UNKNOWN** Some other value.

The **markerUnits** IDL attribute [reflects](types.html#TermReflect) the
['[markerUnits](painting.html#MarkerUnitsAttribute)']
content attribute. The [numeric type
values](types.html#TermNumericTypeValue) for
['[markerUnits](painting.html#MarkerUnitsAttribute)'] are as
described above in the numeric marker unit type constant table.

The **orientType**, **orientAngle** and **orient** IDL attributes all
reflect the ['[orient](painting.html#OrientAttribute)']
content attribute. The [numeric type
values](types.html#TermNumericTypeValue) for
['[orient](painting.html#OrientAttribute)'] are as follows:

 Value Numeric type value
 ------------------------------------------------------------------------------------------------------------------- ---------------------------------------------------------------------------------------------------------------------
 [auto] [SVG_MARKER_ORIENT_AUTO](painting.html#__svg__SVGMarkerElement__SVG_MARKER_ORIENT_AUTO)
 [auto-start-reverse] [SVG_MARKER_ORIENT_AUTO_START_REVERSE](painting.html#__svg__SVGMarkerElement__SVG_MARKER_ORIENT_AUTO_START_REVERSE)
 [\<angle\>](https://www.w3.org/TR/css-values/#angles) \| [\<number\>](https://www.w3.org/TR/css3-values/#numbers) [SVG_MARKER_ORIENT_ANGLE](painting.html#__svg__SVGMarkerElement__SVG_MARKER_ORIENT_ANGLE)

The **refX**, **refY**, **markerWidth** and **markerHeight** IDL
attributes reflect the
['[refX](painting.html#MarkerElementRefXAttribute)'],
['[refY](painting.html#MarkerElementRefYAttribute)'],
['[markerWidth](painting.html#MarkerWidthAttribute)'] and
['[markerHeight](painting.html#MarkerHeightAttribute)']
content attributes, respectively.

The **setOrientToAuto** method is used to set the value of the
['[orient](painting.html#OrientAttribute)'] attribute to
[\'auto\']. When setOrientToAuto() is called, the
['[orient](painting.html#OrientAttribute)'] attribute is
simply set to [\'auto\'].

The **setOrientToAngle** method is used to set the value of the
['[orient](painting.html#OrientAttribute)'] attribute to a
specific angle value. When setOrientToAngle(`angle`) is
called, the ['[orient](painting.html#OrientAttribute)']
attribute is [reserialized](types.html#TermReserialize) using
`angle` as the value.
