## 1. Introduction

Text and SVG graphical elements that define a
shape---​[`path`](https://w3c.github.io/svgwg/svg2-draft/paths.html#elementdef-path) elements, basic shapes such as
[`rect`](https://w3c.github.io/svgwg/svg2-draft/shapes.html#elementdef-rect)---​are rendered by being [filled], which is painting the interior
of the object, and [stroked], which is painting along the outline of the object.

This specification describes how text and SVG graphical elements are
filled and stroked, by defining a number of properties that control the
appearance and shape of an element's fill and stroke.

Insert [Specifying Paint from
SVG2](https://svgwg.org/svg2-draft/painting.html#SpecifyingPaint).

Deal with text decoration. See
[issue](https://www.w3.org/mid/20160422204811.GA17804@pescadero.dbaron.org)
and [other
issue](https://www.w3.org/mid/1400592192.22096.52.camel@localhost.localdomain).

## 2. Paint

Paint is what makes abstract geometries visible. It consists of colors,
patterns, images, gradients, and other 2D graphics. The
[\<color\>](https://drafts.csswg.org/css-color-5/#typedef-color) type represents 0-dimensional paint;
it is defined in
[\[CSS3-COLOR\]](#biblio-css3-color "CSS Color Module Level 3").
The [\<paint\>](#typedef-paint) type represents 2-dimensional paint, and its syntax
is:

``` prod
<paint> = none | <image> | <svg-paint>
```

[none]

: Indicates no paint is applied.

[\<image\>](https://drafts.csswg.org/css-images-3/#typedef-image)

: Defined in
 [\[CSS3-IMAGES\]](#biblio-css3-images "CSS Images Module Level 3")
 and includes image references and gradients.

[\<svg-paint\>](#typedef-svg-paint)

: References SVG paint servers, and is defined in [§ 2.1 SVG-Specific
 Paints](#svg-paint). A
 [\<url\>](https://drafts.csswg.org/css-values-4/#url-value) value here is treated as an
 [ambiguous image
 URL](https://drafts.csswg.org/css-images-3/#css-ambiguous-image-url).

### 2.1. SVG-Specific Paints

``` prod
<svg-paint> = child | child( <integer> )
```

[child]

: Refers to the last child [paint server
 element](https://w3c.github.io/svgwg/svg2-draft/painting.html#TermPaintServerElement) of the element being painted.

 If there is no such child, behaves as
 [none](#valdef-paint-none).

[child([\<integer\>](https://drafts.csswg.org/css-values-4/#integer-value))]

: This [functional
 notation](https://drafts.csswg.org/css-values-4/#functional-notation), which accepts a positive integer as its argument,
 refers to the nth child [paint server
 element](https://w3c.github.io/svgwg/svg2-draft/painting.html#TermPaintServerElement) (1-indexed, as for [::nth-child()]) of the
 element being painted.

 If there is no such child, behaves as
 [none](#valdef-paint-none).

 Arguments less than 1 are invalid.

[w3c/csswg-drafts/383](https://github.com/w3c/csswg-drafts/issues/383)[\[css-images\]\[css-masking\]\[paint\]
Ambiguities in handling
url()](https://github.com/w3c/csswg-drafts/issues/383)

[context-fill] and
[context-stroke] need to be worked into the spec, but they belong
as keywords on each individual
[stroke](#propdef-stroke) and [fill](#propdef-fill) sub-property, not as a
[\<paint\>](#typedef-paint) value. Needs more WG discussion, and confirmation that
this is an SVG2 feature that will be kept, before we do the relatively
substantial edits for it.

[CSS Images 4 § 2.7.1 Paint
Sources](https://drafts.csswg.org/css-images-4/#paint-sources) defines
how to handle SVG paint server coordinate spaces. Copy, ref, or
something else here?

## 3. Fills

A [fill] paints
within the outlines of an SVG shape or the glyphs of an inline (or SVG
text) box. Similar to backgrounds
[\[CSS3BG\]](#biblio-css3bg "CSS Backgrounds and Borders Module Level 3"),
[fills](#fill) can be a solid color
([fill-color](#propdef-fill-color)) and/or an image pattern
([fill-image](#propdef-fill-image) etc.).

**It is strongly recommended to use the
[fill](#propdef-fill) shorthand when setting
[fills](#fill). The individual [painting
longhands](#fill-paint) should only be used when it's needed to alter
one individual aspect.**

Add a [box-break] property that is
a shorthand for
[box-decoration-break](https://drafts.csswg.org/css-break-4/#propdef-box-decoration-break),
[fill-break](#propdef-fill-break), and
[stroke-break](#propdef-stroke-break)?

### 3.1. Layering Multiple Fills

The fill of a box can have multiple layers. The number of layers is
determined by the number of comma-separated values for the
[fill-image](#propdef-fill-image) property. A value of [none] still
creates a layer.

List-valued properties interact exactly as for background images,
defined in [CSS Backgrounds 3 § 2.1 Layering Multiple Background
Images](https://drafts.csswg.org/css-backgrounds-3/#layering).

### 3.2. Fill Geometry

#### 3.2.1. Winding Rule for SVG shapes: the [fill-rule property]
Name:

[fill-rule]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

nonzero
[\|](https://drafts.csswg.org/css-values-4/#comb-one) evenodd

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

nonzero

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

SVG shapes

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

yes

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

N/A

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

as specified

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

Media:

visual

The [fill-rule](#propdef-fill-rule) property indicates the rule used to
determine what parts of the canvas are included inside the shape. For a
simple, non-intersecting path, it is intuitively clear what region lies
"inside"; however, for a more complex path, such as a path that
intersects itself or where one subpath encloses another, the
interpretation of "inside" is not so obvious.

The [fill-rule](#propdef-fill-rule) property provides two options for how
the inside of a shape is determined:

[nonzero]
: This rule determines the "insideness" of a point on the canvas by
 drawing a ray from that point to infinity in any direction and then
 examining the places where a segment of the shape crosses the ray.
 Starting with a count of zero, add one each time a path segment
 crosses the ray from left to right and subtract one each time a path
 segment crosses the ray from right to left. After counting the
 crossings, if the result is zero then the point is outside the path.
 Otherwise, it is inside.
 ![The effect of a nonzero fill rule on paths with self-intersections
 and enclosed subpaths.](images/fillrule-nonzero.svg){height="151"
 width="454"}

[evenodd]
: This rule determines the "insideness" of a point on the canvas by
 drawing a ray from that point to infinity in any direction and
 counting the number of path segments from the given shape that the
 ray crosses. If this number is odd, the point is inside; if even,
 the point is outside.
 ![The effect of an evenodd fill rule on paths with
 self-intersections and enclosed
 subpaths.](images/fillrule-evenodd.svg){height="151" width="454"}

 The above descriptions do not specify what to do if a
path segment coincides with or is tangent to the ray. Since any ray will
do, one may simply choose a different ray that does not have such
problem intersections.

This property does not apply to text (whether SVG or CSS), as the
"inside" of a text glyph is intrinsically defined.

Should this be layerized?

#### 3.2.2. Fragmented Fills: the [fill-break property]
Name:

[fill-break]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

bounding-box
[\|](https://drafts.csswg.org/css-values-4/#comb-one) slice [\|] clone

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

bounding-box

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[all
elements](https://www.w3.org/TR/css-pseudo/#generated-content "Includes ::before and ::after pseudo-elements.")

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

yes?

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

N/A

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

as specified

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

Media:

visual

This property specifies how the geometry of a
[fragmented](https://drafts.csswg.org/css-break-3/#fragment) box is treated for [fills](#fill).

Values have the following meanings: COPY FROM FRAGMENTATION

### 3.3. Fill Paint

#### 3.3.1. Fill Color: the [fill-color property]
Name:

[fill-color]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<color\>](https://drafts.csswg.org/css-color-5/#typedef-color)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

currentcolor

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

text and [SVG shapes]

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

yes

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

N/A

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

the computed color

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value

Media:

visual

This property sets the fill color of an element. This color is drawn
behind any fill images.

**It's recommended that authors use the
[color](https://drafts.csswg.org/css-color-4/#propdef-color) property to set the color of text,
rather than
[fill-color](#propdef-fill-color).**

Unlike
[background-color](https://drafts.csswg.org/css-backgrounds-3/#propdef-background-color), the fill color must only be drawn
if the final layer of
[fill-image](#propdef-fill-image) is [none] or an [invalid
image](https://drafts.csswg.org/css-images-4/#invalid-image). If it's a [valid image], the
fill color must not be drawn.

 This is required to match the legacy behavior of SVG's
[fill](#propdef-fill) property, which built in a \"fallback color\" to
the single-layer image syntax. In CSS this is better achieved with the
[image()](https://drafts.csswg.org/css-images-5/#funcdef-image) function, which makes fallback explicit.

[fill-color](#propdef-fill-color) should be layerized, like
[stroke-color](#propdef-stroke-color), so the two sets of properties are
maximally consistent.

SVG user agents must include the following rules (or their equivalent)
in their [user agent style sheet]:

```
@namespace svg "http://www.w3.org/2000/svg";
svg:svg:root, *|*:not(svg|*) > svg:svg {
 fill-color: black;
}
```

#### 3.3.2. Fill Image Sources: the [fill-image property]
Name:

[fill-image]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<paint\>](#typedef-paint)[\#](https://drafts.csswg.org/css-values-4/#mult-comma)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

none

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

text and [SVG shapes]

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

yes

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

N/A

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

as specified, with any
[\<image\>](https://drafts.csswg.org/css-images-3/#typedef-image) computed

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

repeatable list

Media:

visual

This property sets the fill images of an element. Images are drawn with
the first specified one on top (closest to the user) and each subsequent
image behind the previous one. Values are interpreted identically to
[background-image](https://drafts.csswg.org/css-backgrounds-3/#propdef-background-image), mutatis mutandi.

#### 3.3.3. Fill Positioning Area: the [fill-origin property]
Name:

[fill-origin]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

match-parent
[\|](https://drafts.csswg.org/css-values-4/#comb-one) fill-box [\|] stroke-box
[\|] content-box [\|]
padding-box [\|] border-box

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

match-parent

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[all
elements](https://www.w3.org/TR/css-pseudo/#generated-content "Includes ::before and ::after pseudo-elements.")

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

N/A

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

as specified

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

Media:

visual

This property specifies the coordinate system of the
[fill](#fill), setting the [fill
positioning area]. Values have the following meanings:

[match-parent]
: Use the same [fill positioning
 area](#fill-positioning-area) as the parent. If it has no parent, use the
 [initial containing
 block](https://drafts.csswg.org/css-display-4/#initial-containing-block).

[content-box]\
[padding-box]\
[border-box]
: Use the box's own content-box/padding-box/border-box as the [fill
 positioning
 area](#fill-positioning-area). For [SVG shapes],
 [content-box](#valdef-fill-origin-content-box) and
 [padding-box](#valdef-fill-origin-padding-box) are treated as
 [fill-box](#valdef-fill-origin-fill-box), while
 [border-box](#valdef-fill-origin-border-box) is treated as
 [stroke-box](#valdef-fill-origin-stroke-box).

[fill-box]
: For [SVG shapes] or SVG text, use the [object
 bounding
 box](https://w3c.github.io/svgwg/svg2-draft/coords.html#TermObjectBoundingBox) of the element. For CSS boxes, use the bounding box
 of the text glyph outlines of the element and all in-flow or floated
 descendants.

[stroke-box]
: For [SVG shapes] or SVG text, use the [stroke
 bounding
 box](https://w3c.github.io/svgwg/svg2-draft/coords.html#TermStrokeBoundingBox) of the element. For CSS boxes, use the bounding box
 of the text glyph stroke outlines of the element and all in-flow or
 floated descendants.

The SVG UA style sheet is amended to include the following rules:

```
svg:svg {
 fill-origin: content-box;
}
```

The [fill painting area] is infinite in size. When painting, the fill
color/images are intersected with the glyph areas of the affected text,
or the fill geometry of the affected [SVG shape].

SVG paint servers carry around their own
originator information in \*Units attributes, but maybe SVGWG can add a
new value that makes them pay attention to the CSS originator.
Alternately, we can add an [auto] initial value here, which defers
to the paint server's information if you're referring to one, and
otherwise is
[match-parent](#valdef-fill-origin-match-parent).

#### 3.3.4. Positioning Fill Images: the [fill-position property]
Name:

[fill-position]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<position\>](https://drafts.csswg.org/css-values-4/#typedef-position)[\#](https://drafts.csswg.org/css-values-4/#mult-comma)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

0% 0%

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

text and [SVG shapes]

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

yes

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

A list, each item consisting of: a pair of offsets (horizontal and
vertical) from the top left origin each given as a combination of an
absolute length and a percentage

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

repeatable list

Media:

visual

If fill images have been specified, this property specifies their
initial position (after any resizing) within their corresponding [fill
positioning
area](#fill-positioning-area). Values are interpreted identically to
[background-position](https://drafts.csswg.org/css-backgrounds-3/#propdef-background-position), mutatis mutandi.

#### 3.3.5. Sizing Fill Images: the [fill-size property]
Name:

[fill-size]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<bg-size\>](https://drafts.csswg.org/css-backgrounds-3/#typedef-bg-size)[\#](https://drafts.csswg.org/css-values-4/#mult-comma)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

auto

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

text and [SVG shapes]

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

yes

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

as specified, but with lengths made absolute and omitted
[auto](https://drafts.csswg.org/css-backgrounds-3/#valdef-background-size-auto) keywords filled in

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

repeatable list

Media:

visual

Specifies the size of the fill images. Values are interpreted
identically to
[background-size](https://drafts.csswg.org/css-backgrounds-3/#propdef-background-size), mutatis mutandi.

#### 3.3.6. Tiling Fill Images: the [fill-repeat property]
Name:

[fill-repeat]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<repeat-style\>](https://drafts.csswg.org/css-backgrounds-3/#typedef-repeat-style)[\#](https://drafts.csswg.org/css-values-4/#mult-comma)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

repeat

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

text and [SVG shapes]

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

yes

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

A list, each item consisting of: two keywords, one per dimension

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

Media:

visual

Specifies how fill images are tiled after they have been sized and
positioned. Values are interpreted identically to
[background-repeat](https://drafts.csswg.org/css-backgrounds-3/#propdef-background-repeat), mutatis mutandi.

#### 3.3.7. Fill Shorthand: the [fill property]
Name:

[fill]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<\'background\'\>](https://drafts.csswg.org/css-backgrounds-3/#propdef-background) with modifications

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

See individual properties

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

See individual properties

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

See individual properties

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

N/A

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

See individual properties

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

See individual properties

Media:

visual

This property is a
[shorthand](https://drafts.csswg.org/css-cascade-5/#shorthand-property) that sets all of the fill painting
properties---​[fill-color](#propdef-fill-color),
[fill-image](#propdef-fill-image),
[fill-origin](#propdef-fill-origin),
[fill-position](#propdef-fill-position),
[fill-size](#propdef-fill-size), and
[fill-repeat](#propdef-fill-repeat)---​in one declaration. Omitted values are
set to their initial value, except that an omitted
[fill-color] is set to
[transparent](https://drafts.csswg.org/css-color-4/#valdef-color-transparent), and an omitted
[fill-origin] is set to
[fill-box](#valdef-fill-origin-fill-box).

What should be the default value for
fill-origin when set via this shorthand? content-box or fill-box?
fill-box works better for fancy/overflowing fonts like Zapfino, but it's
much more expensive to calculate than content-box.

SVG has special color fallback
syntax---​a color following an image is only drawn if the image fails.
This conflicts with our desire to match
[background](https://drafts.csswg.org/css-backgrounds-3/#propdef-background), because [fill: url(#foo)
red;](#propdef-fill)
does \*not\* fill with red and then draw #foo. Compromise: fill-color is
a fallback color, but both [none] and [invalid
images](https://drafts.csswg.org/css-images-4/#invalid-image) trigger the fallback. So [fill: url(#foo)
red;] will only draw the red if there is no
#foo (like SVG), but [fill: url(#foo), red]
(equivalent to [none red] on the last layer) will draw the red
*and* the #foo (like [background]).

### 3.4. Fill Transparency

#### 3.4.1. Fill Opacity: the [fill-opacity property]
Name:

[fill-opacity]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<\'opacity\'\>](https://drafts.csswg.org/css-color-4/#propdef-opacity)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

1

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

text and [SVG shapes]

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

yes

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

N/A

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

the specified value converted to a
[\<number\>](https://drafts.csswg.org/css-values-4/#number-value), clamped to the range \[0,1\]

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value

Media:

visual

The [fill-opacity](#propdef-fill-opacity) property specifies the opacity of
the painting operation used to fill the element. As with
[opacity](https://drafts.csswg.org/css-color-4/#propdef-opacity), a value of [0] or [0%]
means fully transparent, and a value of [1] or [100%] means
fully opaque.

## 4. Strokes (Outlines)

A [stroke] draws a
border along the outlines of an SVG shape or the glyphs of an inline (or
SVG text) box. The resulting area can be filled similar to the
[fill](#fill) area.
[Strokes](#stroke) can be a solid color
([stroke-color](#propdef-stroke-color)) and/or an image pattern
([stroke-image](#propdef-stroke-image) etc.).

**It is strongly recommended to use the
[stroke](#propdef-stroke) shorthand when setting
[strokes](#stroke). The individual
[painting longhands](#stroke-paint) should only be used when it's needed
to alter one individual aspect.**

By default, [strokes](#stroke) are
drawn on top of [fills](#fill); the
drawing order is controlled by the
[paint-order](https://w3c.github.io/svgwg/svg2-draft/painting.html#PaintOrderProperty) property.

### 4.1. Layering Multiple Strokes

The stroke of a box can have multiple layers. The number of layers is
determined by the larger of the number of comma-separated values for the
[stroke-image](#propdef-stroke-image) property and the number of
comma-separated values for the
[stroke-color](#propdef-stroke-color) property. A value of [none]
still creates a layer.

If the two properties have different lengths, the values are aligned
from the end, with missing front values for
[stroke-color](#propdef-stroke-color) defaulting to
[transparent](https://drafts.csswg.org/css-color-4/#valdef-color-transparent), and missing front values for
[stroke-image](#propdef-stroke-image) defaulting to [none].

List-valued properties interact exactly as for background images,
defined in [CSS Backgrounds 3 § 2.1 Layering Multiple Background
Images](https://drafts.csswg.org/css-backgrounds-3/#layering).

[stroke-color](#propdef-stroke-color) must front-fill with
[transparent](https://drafts.csswg.org/css-color-4/#valdef-color-transparent), otherwise multiple image layers will randomly
fall back to solid colors if the image fails to load. Do we want to have
strokes and fills front-fill with initial values in general, or should
the rest of these properties repeat their lists as they do for
backgrounds?

### 4.2. Stroke Geometry

We currently layerize the stroke paint
props, and
[stroke-width](#propdef-stroke-width), per SVGWG resolution. Should we
layerize the other geometry properties? They have similar use-cases,
albeit somewhat more niche, and consistency in API is important. Worth
the implementation/testing effort? Hard case:
[stroke-dasharray](#propdef-stroke-dasharray), because it has \"commas anywhere
lol\" syntax.

#### 4.2.1. Stroke Thickness: the [stroke-width property]
Name:

[stroke-width]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

\[
[\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage)
[\|](https://drafts.csswg.org/css-values-4/#comb-one)
[\<line-width\>](https://drafts.csswg.org/css-backgrounds-3/#typedef-line-width)
\][\#](https://drafts.csswg.org/css-values-4/#mult-comma)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

1px

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

text and [SVG shapes]

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

yes

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

relative to the [scaled viewport
size](#scaled-viewport-size)

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

the absolute length, or percentage

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value

Media:

visual

This property specifies the width of the strokes on the outline. A zero
value causes no stroke to be painted for that layer. Negative values are
invalid.

The [scaled viewport size] is the geometric mean of the viewport width
and height.

#### 4.2.2. Stroke Positioning: the [stroke-align property]
Name:

[stroke-align]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

center
[\|](https://drafts.csswg.org/css-values-4/#comb-one) inset [\|] outset

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

center

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

text and [SVG shapes]

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

yes

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

N/A

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

as specified

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

Media:

visual

This property allows the author to align a
[stroke](#stroke) along the outline.

[center]
: The stroke for each subpath is centered on the outline.

[inset]

: The stroke for each subpath lies on the "inside" of the outline
 (into the fill area).

 The
 [stroke-linejoin](#propdef-stroke-linejoin) property must be ignored.

 (#issue-1627f4e7) Why is
 [stroke-linejoin](#propdef-stroke-linejoin) ignored? It's still needed for
 interior corners.

[outset]
: The stroke for each subpath lies on the "outside" of the outline
 (outside the fill area).

Text is easy, as are simple closed,
non-self-intersecting paths, but the other categories exist and need
good definitions.

How does this apply to open path segments? One suggestion is to alias
[outset](#valdef-stroke-align-outset) to [left] and
[inset](#valdef-stroke-align-inset) to [right] for open paths. How are end
caps handled?

![Stroke with
[stroke-align](#propdef-stroke-align)
[center](#valdef-stroke-align-center) value.Fill region.Stroke with
[stroke-align](#propdef-stroke-align)
[inset](#valdef-stroke-align-inset) value per spec (? stroke only paints inside fill
region).Stroke with
[stroke-align](#propdef-stroke-align)
[outset](#valdef-stroke-align-outset) value (implemented by blocking out fill
region).Stroke with
[stroke-align](#propdef-stroke-align)
[inset](#valdef-stroke-align-inset) value, alternative interpretation.Stroke with
[stroke-align](#propdef-stroke-align)
[outset](#valdef-stroke-align-outset) value per spec (?).Stroke with
[stroke-align](#propdef-stroke-align) alternative [left] value;
pink shows round
line-cap.](images/stroke-align-open-path.svg){height="600" width="600"}

How does this apply to paths with loops? Is the region inside the red
circle in the below figure part of the stroked (as shown)? Are internal
edges stroked if the fill rule is
[nonzero](#valdef-fill-rule-nonzero); if so how? (Shown without stroking below.)

![Top row: Normal stroke. Stroke left. Stroke right.Middle row: Fill
rule
[nonzero](#valdef-fill-rule-nonzero), no stroke. Stroke outside. Stroke inside.Bottom
row: Fill rule
[evenodd](#valdef-fill-rule-evenodd), no stroke. Stroke outside. Stroke
inside.](images/stroke-align-intersecting-path.svg){height="600"
width="600"}

How are dashes handled? Are they based on original path?

![Normal dash pattern.Dash pattern based on dash pattern or original
path. Note light-gray region which is from inside dash part (simply
using clipping path does not yield proper result).Dash pattern based on
center of offset path. Light gray represents dash pattern based on
center of inset path.](images/stroke-align-dashes.svg){height="400"
width="600"}

#### 4.2.3. Stroke End Shapes: the [stroke-linecap property]
Name:

[stroke-linecap]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

butt
[\|](https://drafts.csswg.org/css-values-4/#comb-one) round [\|] square

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

butt

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

text and [SVG shapes]

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

yes

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

N/A

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

as specified

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

Media:

visual

[stroke-linecap](#propdef-stroke-linecap) specifies the shape to be used at
the end of open subpaths (such as the segments of a dashed stroke, or an
unclosed
[`path`](https://w3c.github.io/svgwg/svg2-draft/paths.html#elementdef-path) element) when they are stroked. The possible values
are:

[butt]
: The stroke for each subpath does not extend beyond its two
 endpoints. (A zero length subpath will therefore not have any
 stroke.)

[round]
: At each end of each subpath, the stroke is extended by a half circle
 with a radius equal to half the stroke width. (The stroke for a
 zero-length subpath is a full circle centered at the subpath's
 point.)

[square]

: At the end of each subpath, the stroke is extended by a rectangle
 with the same width as the stroke width and whose length is half of
 the stroke width. (The stroke for a zero-length subpath is a square
 with side length equal to the stroke width, centered at the
 subpath's point, and oriented such that two of its sides are
 parallel to the effective tangent at that subpath's point. See
 [§ 4.6 Computing the Shape of the Stroke](#path-notes) for details
 on how to determine the tangent at a zero-length subpath.)

 (#issue-f2ad6e96) Adding a rectangle to the end of
 dashes on a curved outline looks bad. It should just extend the dash
 by
 [stroke-width](#propdef-stroke-width)/2, following the outline.

![The three types of line caps.](images/linecap.svg){height="110"
width="600"}

See the definition of the [cap shape](#cap-shapes) below for a more precise description of the shape a
line cap will have.

#### 4.2.4. Stroke Corner Shapes: the [stroke-linejoin property]
Name:

[stroke-linejoin]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

\[ crop
[\|](https://drafts.csswg.org/css-values-4/#comb-one) arcs [\|] miter \]
[\|\|](https://drafts.csswg.org/css-values-4/#comb-any) \[ bevel [\|] round
[\|] fallback \]

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

miter

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

text and [SVG shapes]

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

yes

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

N/A

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

as specified

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

Media:

visual

[stroke-linejoin](#propdef-stroke-linejoin) specifies the shape to be used at
the corners of paths or basic shapes when they are stroked. It has two
parts: [\[ crop \| arcs \| miter \]] specifies whether or not, and
how, to extend the corner of the stroke; [\[ bevel \| round \| fallback
\]] specifies how to render the \"cap\" of the corner when it's
limited in length by
[stroke-miterlimit](#propdef-stroke-miterlimit).

[crop]

: The stroke extends the minimal amount past the corner necessary to
 form a convex corner.

 This acts identically to
 [miter](#valdef-stroke-linejoin-miter), but forces
 [stroke-miterlimit](#propdef-stroke-miterlimit) to behave as if it had its
 minimum value of [1].

[miter]
: A sharp corner is used to join path segments. The corner is formed
 by extending the outer edges of the stroke at the tangents of the
 path segments until they intersect.

[arcs]
: An arcs corner is used to join path segments. The arcs shape is
 formed by extending the outer edges of the stroke at the join point
 with arcs that have the same curvature as the outer edges at the
 join point.

[bevel]
: The corner is cropped at the
 [stroke-miterlimit](#propdef-stroke-miterlimit) by the perpendicular to its
 [diagonal](#--corner-diagonal).

[round]
: The corner is cropped as for
 [bevel](#valdef-stroke-linejoin-bevel), and a filled arc tangent to the truncated
 stroke edges is appended to round the corner.

[fallback]

: When the
 [stroke-miterlimit](#propdef-stroke-miterlimit) is exceeded, this behaves as if
 [crop bevel] were specified.

 (#issue-4eb049cf) Can we just remove
 [fallback](#valdef-stroke-linejoin-fallback)? It's a stupid value, useful only because we
 didn't have the clip-at-miterlimit behavior in SVG1. Question is if
 people are mostly just \*accidentally\* getting the bevel behavior
 right now, and would be okay with their joins extending up to the
 miterlimit and only getting the excess corners clipped, or if they
 actually wanted the discontinuous behavior currently specified. [The
 breakpoint is between 29 and 30
 degrees.](http://software.hixie.ch/utilities/js/live-dom-viewer/?%3C!DOCTYPE%20html%3E%0A%3Csvg%3E%0A%20%20%3Cpath%20fill%3Dnone%20stroke%3Dblack%20stroke-width%3D10%20d%3D%22M%2010%2010%20h%20100%20l%20-100%2055%22%20%2F%3E%0A%20%20%3Cpath%20fill%3Dnone%20stroke%3Dblack%20stroke-width%3D10%20d%3D%22M%2010%2050%20h%20100%20l%20-100%2056deg%22%20%2F%3E)

If [\[ crop \| arcs \| miter \]] is omitted, it defaults to
[crop](#valdef-stroke-linejoin-crop). If [\[ bevel \| round \| fallback \]] is
omitted, it defaults to
[fallback](#valdef-stroke-linejoin-fallback).

![Four types of line joins](images/linejoin-four.svg){height="180"
width="800"}

![A more detailed look at precisely how each type of join is shaped. For
each, the dashed white line is the path being stroked, and the black is
the stroke itself, before applying the linejoin. The pink area is the
additional stroke added at the corner for bevel, round, and miter
linejoins.](data:image/svg+xml;base64,PHN2ZyBzdHlsZT0iIHdpZHRoOiA2MDBweDsgaGVpZ2h0OiAxODBweDsgY29sb3Itc2NoZW1lOiBsaWdodCBkYXJrOyI+CiAgICAgPGcgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoMCwgMCkiPgogICAgICA8cGF0aCBkPSJNIDEwIDUwIGggMTAwIiBmaWxsPSJub25lIiBzdHJva2U9ImJsYWNrIiBzdHJva2Utd2lkdGg9IjEwMCIgLz4KICAgICAgPHBhdGggZD0iTSAxMTAgNTAgbCAtNTAgMTAwIiBmaWxsPSJub25lIiBzdHJva2U9ImJsYWNrIiBzdHJva2Utd2lkdGg9IjEwMCIgLz4KICAgICAgPHBhdGggZD0iTSAxMCA1MCBoIDEwMCBsIC0xMDAgMjAwIiBmaWxsPSJub25lIiBzdHJva2U9IndoaXRlIiBzdHJva2UtZGFzaGFycmF5PSI1IDMiIHN0cm9rZS13aWR0aD0iMSIgLz4KICAgICAgPHBhdGggZD0iTSAxMTAgNTAgdiAtNTAgbCA0NC43MiA3Mi4zNiB6IiBmaWxsPSJoc2xhKDAsIDUwJSwgNzAlLCAxKSIgLz4KICAgICA8L2c+CiAgICAgPGcgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoMjAwLDApIj4KICAgICAgPHBhdGggZD0iTSAxMCA1MCBoIDEwMCIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJibGFjayIgc3Ryb2tlLXdpZHRoPSIxMDAiIC8+CiAgICAgIDxwYXRoIGQ9Ik0gMTEwIDUwIGwgLTUwIDEwMCIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJibGFjayIgc3Ryb2tlLXdpZHRoPSIxMDAiIC8+CiAgICAgIDxwYXRoIGQ9Ik0gMTAgNTAgaCAxMDAgbCAtMTAwIDIwMCIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJ3aGl0ZSIgc3Ryb2tlLWRhc2hhcnJheT0iNSAzIiBzdHJva2Utd2lkdGg9IjEiIC8+CiAgICAgIDxwYXRoIGQ9Ik0gMTEwIDUwIHYgLTUwIGEgNTAgNTAgMCAwIDEgNDQuNzIgNzIuMzYgeiIgZmlsbD0iaHNsYSgwLCA1MCUsIDcwJSwgMSkiIC8+CiAgICAgPC9nPgogICAgIDxnIHRyYW5zZm9ybT0idHJhbnNsYXRlKDQwMCwgMCkiPgogICAgICA8cGF0aCBkPSJNIDEwIDUwIGggMTAwIiBmaWxsPSJub25lIiBzdHJva2U9ImJsYWNrIiBzdHJva2Utd2lkdGg9IjEwMCIgLz4KICAgICAgPHBhdGggZD0iTSAxMTAgNTAgbCAtNTAgMTAwIiBmaWxsPSJub25lIiBzdHJva2U9ImJsYWNrIiBzdHJva2Utd2lkdGg9IjEwMCIgLz4KICAgICAgPHBhdGggZD0iTSAxMCA1MCBoIDEwMCBsIC0xMDAgMjAwIiBmaWxsPSJub25lIiBzdHJva2U9IndoaXRlIiBzdHJva2UtZGFzaGFycmF5PSI1IDMiIHN0cm9rZS13aWR0aD0iMSIgLz4KICAgICAgPHBhdGggZD0iTSAxMTAgNTAgdiAtNTAgaCA4MCBMIDE1NC43MiA3Mi4zNiB6IiBmaWxsPSJoc2xhKDAsIDUwJSwgNzAlLCAxKSIgLz4KICAgICA8L2c+CiAgICA8L3N2Zz4=)

#### 4.2.5. Stroke Corner Limits: the [stroke-miterlimit property]
Name:

[stroke-miterlimit]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<number\>](https://drafts.csswg.org/css-values-4/#number-value)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

4

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

text and [SVG shapes]

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

yes

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

N/A

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

a number

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

Media:

visual

This property specifies the maximum size of a
[miter](#valdef-stroke-linejoin-miter) or
[arcs](#valdef-stroke-linejoin-arcs) join when two stroke segments meet at a corner.
(The apparent "size" of the join---​the distance between the inner and
outer corner---​approaches infinity as the angle decreases.)

This property has no effect when
[stroke-align](#propdef-stroke-align) is
[inset](#valdef-stroke-align-inset).

Values have the following meanings:

[[\<number\>](https://drafts.csswg.org/css-values-4/#number-value)]

: Specifies the limit on the join's size as a ratio of its
 [diagonal] to the
 [stroke-width](#propdef-stroke-width). Values less than 1 are invalid
 (and make the declaration
 [invalid](https://drafts.csswg.org/css-syntax-3/#css-invalid)).

 For a
 [miter](#valdef-stroke-linejoin-miter) linejoin, the length of the
 [diagonal](#--corner-diagonal) is calculated from the angle between the two
 segments as
 [`stroke-width`](#propdef-stroke-width)` / sin(θ/2)`. The linejoin is
 clipped perpendicular to the line bisecting the angle between the
 two path segments.

 For an
 [arcs](#valdef-stroke-linejoin-arcs) linejoin, the length of the
 [diagonal](#--corner-diagonal) is calculated along a circular arc that is tangent
 to the line bisecting the angle between the two segments at the
 point the two segments intersect and passes through the end point of
 the join. The linejoin is clipped perpendicular to this arc.

Should we add angles? The miterlimit
number has physical justification, but it's difficult to understand
without experimentation.

#### 4.2.6. Fragmented Strokes: the [stroke-break property]
Name:

[stroke-break]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

bounding-box
[\|](https://drafts.csswg.org/css-values-4/#comb-one) slice [\|] clone

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

bounding-box

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[all
elements](https://www.w3.org/TR/css-pseudo/#generated-content "Includes ::before and ::after pseudo-elements.")

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

?

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

N/A

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

as specified

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

Media:

visual

This property specifies how the geometry of a
[fragmented](https://drafts.csswg.org/css-break-3/#fragment) box is treated for [strokes](#stroke).

Values have the following meanings: COPY FROM FRAGMENTATION

### 4.3. Stroke Dashing

#### 4.3.1. Stroke Dash Patterns: the [stroke-dasharray property]
Name:

[stroke-dasharray]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

none
[\|](https://drafts.csswg.org/css-values-4/#comb-one)
[\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage)[+](https://drafts.csswg.org/css-values-4/#mult-one-plus)[\#](https://drafts.csswg.org/css-values-4/#mult-comma)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

none

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

text and [SVG shapes]

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

yes

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

relative to the [scaled viewport
size](#scaled-viewport-size)

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

as specified

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

repeatable list

Media:

visual

This property controls the pattern of dashes and gaps used to stroke
paths.

[none]
: No dashing: the stroke is drawn continuously.

[[\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage)+#]

: Specifies a dashing pattern to use. Each
 [\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage) value represents the length of
 the next dash or gap (beginning with the first dash and alternating
 from there) of the stroke. The pattern repeats over the length of
 the stroke. (If the number of values is odd, the pattern behaves as
 if it was duplicated to yield an even number of values.) The dashing
 pattern is reset and begins anew at the start of each subpath.

 Negative values are invalid. If all values are zero, it is treated
 as
 [none](#valdef-stroke-dasharray-none).

SVG allows comma separation. Do we need
to allow this in CSS for back-compat? (Please say no.)

Need a way to specify dash lengths
relative to the width of the stroke. (For instance, to do square
dashes.)

Need a way to specify dash lengths
relative to the length of the path. (For instance, to do the
\"self-drawing SVG\" thing without script.)

![A dashed stroke. The dashing pattern is [20 10]. The red line
shows the actual path that is stroked.](images/dashes.svg){height="150"
width="300"}

#### 4.3.2. Stroke Dash Start Position: the [stroke-dashoffset property]
Name:

[stroke-dashoffset]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

0

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

text and [SVG shapes]

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

yes

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

relative to the [scaled viewport
size](#scaled-viewport-size)

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

as specified

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

repeatable list

Media:

visual

This property specifies the distance into the repeated dash pattern to
start dashing at the beginning of the path. Values can be negative.

![A dashed stroke with a non-zero dash offset. The dashing pattern is
[20 10] and the dash offset is [15]. The red line shows the
actual path that is stroked.](images/dashoffset.svg){height="150"
width="300"}

See [§ 4.6.3 Dash Positions](#algo-dash-positions) for a more precise
description of positions along a path that dashes will be placed.

#### 4.3.3. Corner Control: the [stroke-dash-corner and [stroke-dash-justify](#propdef-stroke-dash-justify) properties]
Name:

[stroke-dash-corner]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

none
[\|](https://drafts.csswg.org/css-values-4/#comb-one)
[\<length\>](https://drafts.csswg.org/css-values-4/#length-value)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

none

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

text and [SVG shapes]

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

yes

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

N/A

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

specified value, with lengths made absolute

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value if
[\<length\>](https://drafts.csswg.org/css-values-4/#length-value), otherwise discrete

Media:

visual

The
[stroke-dash-corner](#propdef-stroke-dash-corner) property controls whether a dash is
always painted at the vertices of a stroked shape. The points at which a
dash corner is painted include the start and end points of every segment
within the shape's [equivalent
path](https://w3c.github.io/svgwg/svg2-draft/paths.html#TermEquivalentPath).

[none]

: This property has no special effect on dashing: the dashes are
 positioned/sized continuously along the path.

[\<length\>](https://drafts.csswg.org/css-values-4/#length-value)

: A dash of the given
 [\<length\>](https://drafts.csswg.org/css-values-4/#length-value) must be painted at each vertex of
 the shape. For an open shape, the first corner dash is positioned so
 that it begins at the start of the path, and the last corner dash so
 that it ends at the end of the path. The other corner dashes of an
 open shape, and all corner dashes of a closed shape, are positioned
 so that they are centered on their vertex.

Should the corner dash at the first and
last vertex of an open shape be half the length of the others? Should
this be author controllable?

Should there be a way to specify a
padding, so that any dash pattern between the corner dashes does not not
run up against them?

The corner needs to take over the role
of the first dash in the dash pattern, so the \"interior\" of each
segment starts and ends with a gap. Automatically skip the first dash in
the pattern in each segment?

Keyword to use the length of the first
dash as the corner.

When
[stroke-dash-corner](#propdef-stroke-dash-corner) is not
[none](#valdef-stroke-dash-corner-none), dash patterns (as specified by
[stroke-dasharray]) are repeated separately on each path segment,
in the space between the segment's corner dashes.

Need to define what happens when corner
dashes would overlap.

Should we auto-trigger justification
when this property is active? Without it, you'll get some dumb-looking
results by default.

![A rectangle painted with a dashed stroke and with corner dashes, set
with [stroke-dasharray: 0 8px; stroke-dash-corner:
32px;](#propdef-stroke-dasharray).](images/dashcorner.svg){a
height="150" width="300"}

Name:

[stroke-dash-justify]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

none
[\|](https://drafts.csswg.org/css-values-4/#comb-one) \[ stretch [\|] compress \]
[\|\|](https://drafts.csswg.org/css-values-4/#comb-any) \[ dashes [\|\|] gaps \]

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

none

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

text and [SVG shapes]

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

yes

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

N/A

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

specified value, with lengths made absolute

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

Media:

visual

The
[stroke-dash-justify](#propdef-stroke-dash-justify) property specifies whether and how
a stroke's dash pattern will be adjusted so that it is repeated a whole
number of times along each of an element's subpaths.

[none]

: No adjustment of the dash pattern is made: it's clipped at the end
 of the subpath with however much progress it made to that point.

[stretch]

: Indicates that when the dash pattern does not fit into a subpath a
 whole number times, the dashes or gaps (or both) will be lengthened
 so that it does.

[compress]

: Indicates that when the dash pattern does not fit into a subpath a
 whole number times, the dashes or gaps (or both) will be shortened
 so that it does.

[dashes]

: Indicates that when a dash pattern is to be stretched or compressed,
 the length of the dashes will be adjusted.

[gaps]

: Indicates that when a dash pattern is to be stretched or compressed,
 the length of the gaps will be adjusted.

If neither
[stretch](#valdef-stroke-dash-justify-stretch) nor
[compress](#valdef-stroke-dash-justify-compress) is specified, it defaults to whichever would
result in less adjustment.

If neither
[dashes](#valdef-stroke-dash-justify-dashes) nor
[gaps](#valdef-stroke-dash-justify-gaps) is specified, it defaults to ???.

Default should probably be to adjust the
gaps only.

The target length that a dash pattern will be adjusted to depends on the
value of the
[stroke-dash-corner](#propdef-stroke-dash-corner) property:

- If
 [stroke-dash-corner](#propdef-stroke-dash-corner) is
 [none](#valdef-stroke-dash-corner-none), then the dash pattern will be adjusted to fit
 within the length of the subpath a whole number of times.

- If
 [stroke-dash-corner](#propdef-stroke-dash-corner) has any other value, including a
 zero length, then the dash pattern will be adjusted differently for
 each path segment of the subpath such that it fits between the two
 corner dashes at the ends of the segment a whole number of times.

The adjustment of dash and gap length in a dash pattern is done by
scaling the lengths by a factor, which is the number closest to 1 that
will result in the dash pattern fitting in the target length a whole
number of times. If
[stretch](#valdef-stroke-dash-justify-stretch) is used, the factor is a number between 1 and 2,
while if
[compress](#valdef-stroke-dash-justify-compress) is used, the factor is a number between 0 and 1.

If
[stretch](#valdef-stroke-dash-justify-stretch) is specified, but the dash pattern is longer
than the target length, no adjustment is performed.

Should it center the segment when it's
too long?

If
[compress](#valdef-stroke-dash-justify-compress) is specified, but the adjustable parts of the
dash pattern can't be compressed enough to fit the dash pattern into the
target length, the compressible parts must be set to zero.

Do we want to allow control of whether
the stroke ends with a dash or with a gap? For a closed path, you
probably want a gap at the end, while for an open path, a dash at the
end is probably better. Maybe omit control for this, and just do it
automatically based on whether the path is closed?

![The same dash stroke used on three different paths, adjusted to fit a
whole number of times on each.](images/dashadjust.svg){height="200"
width="600"}

### 4.4. Stroke Paint

#### 4.4.1. Stroke Color: the [stroke-color property]
Name:

[stroke-color]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<color\>](https://drafts.csswg.org/css-color-5/#typedef-color)[\#](https://drafts.csswg.org/css-values-4/#mult-comma)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

transparent

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

text and [SVG shapes]

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

yes

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

N/A

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

the computed color

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value

Media:

visual

This property sets the stroke colors of an element. Like
[stroke-image](#propdef-stroke-image), stroke colors are drawn with the
first specified one on top (closest to the user) and each subsequent
color behind the previous one.

Stroke colors are only drawn if the
[stroke-image](#propdef-stroke-image) on the corresponding layer is
[none] or an [invalid
image](https://drafts.csswg.org/css-images-4/#invalid-image). (In other words, each layer draws *either* an image or
a color, with images winning if both are specified.)

 This is required to match the legacy behavior of SVG's
[stroke](#propdef-stroke) property, which built in a \"fallback color\" to
the single-layer image syntax. In CSS this is better achieved with the
[image()](https://drafts.csswg.org/css-images-5/#funcdef-image) function, which makes fallback explicit.

#### 4.4.2. Stroke Image Sources: the [stroke-image property]
Name:

[stroke-image]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<paint\>](#typedef-paint)[\#](https://drafts.csswg.org/css-values-4/#mult-comma)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

none

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

text and [SVG shapes]

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

yes

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

N/A

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

as specified, with any
[\<image\>](https://drafts.csswg.org/css-images-3/#typedef-image) computed

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

repeatable list

Media:

visual

This property sets the stroke images of an element. Images are drawn
with the first specified one on top (closest to the user) and each
subsequent image behind the previous one. Values are interpreted
identically to
[background-image](https://drafts.csswg.org/css-backgrounds-3/#propdef-background-image), mutatis mutandi.

#### 4.4.3. Stroke Positioning Area: the [stroke-origin property]
Name:

[stroke-origin]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

match-parent
[\|](https://drafts.csswg.org/css-values-4/#comb-one) fill-box [\|] stroke-box
[\|] content-box [\|]
padding-box [\|] border-box

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

match-parent

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[all
elements](https://www.w3.org/TR/css-pseudo/#generated-content "Includes ::before and ::after pseudo-elements.")

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

N/A

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

as specified

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

Media:

visual

This property specifies the coordinate system of the
[stroke](#stroke), setting the [stroke
positioning area]. Values have the following meanings:

[match-parent]
: Use the same [stroke positioning
 area](#stroke-positioning-area) as the parent. If it has no parent, use the
 [initial containing
 block](https://drafts.csswg.org/css-display-4/#initial-containing-block).

[content-box]\
[padding-box]\
[border-box]
: Use the box's own content-box/padding-box/border-box as the [stroke
 positioning
 area](#stroke-positioning-area). For [SVG shapes],
 [content-box](#valdef-stroke-origin-content-box) and
 [padding-box](#valdef-stroke-origin-padding-box) are treated as
 [fill-box](#valdef-stroke-origin-fill-box), while
 [border-box](#valdef-stroke-origin-border-box) is treated as
 [stroke-box](#valdef-stroke-origin-stroke-box).

[fill-box]
: For [SVG shapes] or SVG text, use the [object
 bounding
 box](https://w3c.github.io/svgwg/svg2-draft/coords.html#TermObjectBoundingBox) of the element. For CSS boxes, use the bounding box
 of the text glyph outlines of the element and all in-flow or floated
 descendants.

[stroke-box]
: For [SVG shapes] or SVG text, use the [stroke
 bounding
 box](https://w3c.github.io/svgwg/svg2-draft/coords.html#TermStrokeBoundingBox) of the element. For CSS boxes, use the bounding box
 of the text glyph stroke outlines of the element and all in-flow or
 floated descendants.

The SVG UA style sheet is amended to include the following rules:

```
svg:svg {
 stroke-origin: content-box;
}
```

The [stroke painting area] is infinite in size. When painting, the stroke
color/images are intersected with the glyph strokes of the affected
text, or the stroke geometry of the affected [SVG
shape].

(#issue-8b7a4ffb①) SVG paint servers carry around their
own originator information in \*Units attributes, but maybe SVGWG can
add a new value that makes them pay attention to the CSS originator.
Alternately, we can add an [auto] initial value here, which defers
to the paint server's information if you're referring to one, and
otherwise is
[match-parent](#valdef-stroke-origin-match-parent).

#### 4.4.4. Positioning Stroke Images: the [stroke-position property]
Name:

[stroke-position]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<position\>](https://drafts.csswg.org/css-values-4/#typedef-position)[\#](https://drafts.csswg.org/css-values-4/#mult-comma)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

0% 0%

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

text and [SVG shapes]

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

yes

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

A list, each item consisting of: a pair of offsets (horizontal and
vertical) from the top left origin each given as a combination of an
absolute length and a percentage

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

repeatable list

Media:

visual

If stroke images have been specified, this property specifies their
initial position (after any resizing) within their corresponding [stroke
positioning
area](#stroke-positioning-area). Values are interpreted identically to
[background-position](https://drafts.csswg.org/css-backgrounds-3/#propdef-background-position), mutatis mutandi.

#### 4.4.5. Sizing Stroke Images: the [stroke-size property]
Name:

[stroke-size]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<bg-size\>](https://drafts.csswg.org/css-backgrounds-3/#typedef-bg-size)[\#](https://drafts.csswg.org/css-values-4/#mult-comma)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

auto

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

text and [SVG shapes]

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

yes

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

as specified, but with lengths made absolute and omitted
[auto](https://drafts.csswg.org/css-backgrounds-3/#valdef-background-size-auto) keywords filled in

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

repeatable list

Media:

visual

Specifies the size of the stroke images. Values are interpreted
identically to
[background-size](https://drafts.csswg.org/css-backgrounds-3/#propdef-background-size), mutatis mutandi.

#### 4.4.6. Tiling Stroke Images: the [stroke-repeat property]
Name:

[stroke-repeat]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<repeat-style\>](https://drafts.csswg.org/css-backgrounds-3/#typedef-repeat-style)[\#](https://drafts.csswg.org/css-values-4/#mult-comma)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

repeat

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

text and [SVG shapes]

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

yes

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

A list, each item consisting of: two keywords, one per dimension

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

Media:

visual

Specifies how stroke fill images are tiled after they have been sized
and positioned. Values are interpreted identically to
[background-repeat](https://drafts.csswg.org/css-backgrounds-3/#propdef-background-repeat), mutatis mutandi.

#### 4.4.7. Stroke Shorthand: the [stroke property]
Name:

[stroke]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<\'background\'\>](https://drafts.csswg.org/css-backgrounds-3/#propdef-background) with modifications

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

See individual properties

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

See individual properties

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

See individual properties

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

N/A

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

See individual properties

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

See individual properties

Media:

visual

This property is a
[shorthand](https://drafts.csswg.org/css-cascade-5/#shorthand-property) that sets all of the stroke painting
properties---​[stroke-color](#propdef-stroke-color),
[stroke-image](#propdef-stroke-image),
[stroke-origin](#propdef-stroke-origin),
[stroke-position](#propdef-stroke-position),
[stroke-size](#propdef-stroke-size), and
[stroke-repeat](#propdef-stroke-repeat)---​in one declaration. Omitted
values are set to their initial value, except that an omitted
[stroke-color] is set to
[transparent](https://drafts.csswg.org/css-color-4/#valdef-color-transparent), and an omitted
[stroke-origin] is set to
[stroke-box](#valdef-stroke-origin-stroke-box).

### 4.5. Stroke Transparency

#### 4.5.1. Stroke Opacity: the [stroke-opacity property]
Name:

[stroke-opacity]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<\'opacity\'\>](https://drafts.csswg.org/css-color-4/#propdef-opacity)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

1

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

text and [SVG shapes]

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

yes

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

N/A

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

the specified value converted to a
[\<number\>](https://drafts.csswg.org/css-values-4/#number-value), clamped to the range \[0,1\]

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value

Media:

visual

The
[stroke-opacity](#propdef-stroke-opacity) property specifies the opacity of
the painting operation used to stroke the current object. As with
[opacity](https://drafts.csswg.org/css-color-4/#propdef-opacity), a value of [0] or [0%]
means fully transparent, and a value of [1] or [100%] means
fully opaque.

### 4.6. Computing the Shape of the Stroke

#### 4.6.1. Stroke Paths

In all cases, all stroking properties which are affected by
directionality, such as those having to do with dash patterns, must be
rendered such that the stroke operation starts at the same point at
which the graphics element starts. In particular, for
[`path`](https://w3c.github.io/svgwg/svg2-draft/paths.html#elementdef-path) elements, the start of the path is the first point
of the initial "moveto" command.

For stroking properties such as dash patterns whose computations are
dependent on progress along the outline of the graphics element,
distance calculations are required to utilize the SVG user agent's
standard [Distance along a path
algorithms](https://svgwg.org/svg2-draft/paths.html#DistanceAlongAPath).

When stroking is performed using a complex paint server, such as a
gradient or a
[`pattern`](https://w3c.github.io/svgwg/svg2-draft/pservers.html#elementdef-pattern), the stroke operation must be identical to the
result that would have occurred if the geometric shape defined by the
geometry of the current graphics element and its associated stroking
properties were converted to an equivalent
[`path`](https://w3c.github.io/svgwg/svg2-draft/paths.html#elementdef-path) element and then filled using the given paint
server.

A subpath consisting of a single "moveto" shall not be stroked. Any zero
length subpath shall not be stroked if the
[stroke-linecap](#propdef-stroke-linecap) property has a value of
[butt](#valdef-stroke-linecap-butt) but shall be stroked if the
[stroke-linecap] property
has a value of
[round](#valdef-stroke-linecap-round) or
[square](#valdef-stroke-linecap-square), producing respectively a circle or a square
centered at the given point. Examples of zero-length subpaths include
`'M 10,10 L 10,10'`, `'M 20,20 h 0'`, `'M 30,30 z'`, and
`'M 40,40 c 0,0 0,0 0,0'`.

This should be redundant with the stroke
shape computation requirements below. In this section, we should phrase
the requirements descriptively rather than normatively.

#### 4.6.2. Stroke Shape

The [stroke shape] of an element is the shape that is filled by the
[stroke](#propdef-stroke) property. The following algorithm describes what
the stroke shape of text, a
[`path`](https://w3c.github.io/svgwg/svg2-draft/paths.html#elementdef-path), or basic shape is, taking into account the
stroking properties above:

1. Let `shape` be an empty shape.

2. Let `path` be the [equivalent
 path](https://w3c.github.io/svgwg/svg2-draft/paths.html#TermEquivalentPath) of the element.

3. For each `subpath` of `path`:

 1. Let `positions` be the [dash
 positions](#dash-positions) for the `subpath`.

 2. For each pair (`start`, `end`) in
 `positions`:

 1. Let `dash` be the shape that includes, for all
 distances between `start` and `end`
 along the `subpath`, all points that lie on the
 line perpendicular to the `subpath` at that
 distance and which are within distance stroke-width of the
 point on the `subpath` at that position.

 2. Set `dash` to be the union of `dash`
 and the starting [cap
 shape](#cap-shapes)
 for the subpath at position `start`.

 3. Set `dash` to be the union of `dash`
 and the ending [cap shape](#cap-shapes) for the subpath at position
 `end`.

 4. Let `index` and `last` be the indexes
 of the path segments in the subpath at distance start and
 end along the subpath.

 It does not matter whether any zero length
 segments are included when choosing index and last.

 5. While `index` \< `last`:

 1. Set `dash` to be the union of
 `dash` and the [line join
 shape](#line-join-shape) for the subpath at segment index
 `index`.

 2. Set `index` to index + 1.

 6. Set `shape` to be the union of `shape`
 and `dash`.

4. Return `shape`.

#### 4.6.3. Dash Positions

This section doesn't handle
[stroke-dash-corner](#propdef-stroke-dash-corner) and
[stroke-dash-justify](#propdef-stroke-dash-justify) yet.

The [dash positions] for a given subpath of the equivalent path of a
[`path`](https://w3c.github.io/svgwg/svg2-draft/paths.html#elementdef-path) or basic shape is a sequence of pairs of values,
which represent the starting and ending distance along the subpath for
each of the dashes that form the subpath's stroke. It is determined as
follows:

1. Let `pathlength` be the length of the subpath.

2. Let `dashes` be the list of values of
 [stroke-dasharray](#propdef-stroke-dasharray) on the element, repeated if
 necessary so that it has an even number of elements; if the property
 has the value none, then the list has a single value [0].

3. Let `count` be the number of values in
 `dashes`.

4. Let `sum` be the sum of the values in
 `dashes`.

5. If `sum` = 0, then return a sequence with the single pair
 (0, `pathlength`).

6. Let `positions` be an empty sequence.

7. Let `offset` be the value of the
 [stroke-dashoffset](#propdef-stroke-dashoffset) property on the element.

8. If `offset` is negative, then set `offset` to
 `sum`` − abs(``offset``)`.

9. Set `offset` to
 `offset`` mod ``sum`.

10. Let `index` be the smallest integer such that
 `sum(``dashes`~`i`~`, 0 ≤ i ≤ ``index``) ≥ ``offset`.

11. Let `dashlength` be
 `min(sum(``dashes`~`i`~`, 0 ≤ i ≤ ``index``) − ``offset``, ``pathlength``)`.

12. If `index`` mod 2 = 0`, then append to
 `positions` the pair (0, `dashlength`).

13. Let `position` be `dashlength`.

14. While `position` \< `pathlength`:

 1. Set `index` to
 `(``index`` + 1) mod ``count`.

 2. Let `dashlength` be
 `min(``dashes`~`index`~`, ``pathlength`` − ``position``)`.

 3. If `index` mod 2 = 0, then append to
 `positions` the pair (`position`,
 `position` + `dashlength`).

 4. Set `position` to
 `position`` + ``dashlength`.

15. Return `positions`.

#### 4.6.4. Cap Shapes

The starting and ending [cap shapes] at a given `position` along a
subpath are determined as follows:

1. If
 [stroke-linecap](#propdef-stroke-linecap) is
 [butt](#valdef-stroke-linecap-butt), then return an empty shape.

2. Otherwise, if
 [stroke-linecap](#propdef-stroke-linecap) is
 [round](#valdef-stroke-linecap-round), then:

 1. If this is a starting cap, then return a semicircle of radius
 [stroke-width](#propdef-stroke-width) positioned such that:

 - Its straight edge is parallel to the line perpendicular to the
 subpath at distance `position` along it.

 - The midpoint of its straight edge is at the point that is
 along the subpath at distance `position`.

 - The direction from the midpoint of its arc to the midpoint of
 its straight edge is the same as the direction of the subpath
 at distance `position` along it.

 2. Otherwise, this is an ending cap. Return a semicircle of radius
 stroke-width positioned such that:

 - Its straight edge is parallel to the line perpendicular to the
 subpath at distance `position` along it.

 - The midpoint of its straight edge is at the point that is
 along the subpath at distance `position`.

 - The direction from the midpoint of its straight edge to the
 midpoint of its arc is the same as the direction of the
 subpath at distance `position` along it.

3. Otherwise,
 [stroke-linecap](#propdef-stroke-linecap) is
 [square](#valdef-stroke-linecap-square):

 1. If this is a starting cap, then return a rectangle with side
 lengths
 [stroke-width](#propdef-stroke-width) and
 [stroke-width] / 2
 positioned such that:

 - Its longer edges, A and B, are parallel to the line
 perpendicular to the subpath at distance `position`
 along it.

 - The midpoint of A is at `start`.

 - The direction from the midpoint of B to the midpoint of A is
 the same as the direction of the subpath at distance
 `position` along it.

 2. Otherwise, this is an ending cap. Return a rectangle with side
 lengths
 [stroke-width](#propdef-stroke-width) and
 [stroke-width] / 2
 positioned such that:

 - Its longer edges, A and B, are parallel to the line
 perpendicular to the subpath at distance `position`
 along it.

 - The midpoint of A is at `end`.

 - The direction from the midpoint of A to the midpoint of B is
 the same as the direction of the subpath at distance
 `position` along it.

![The three different stroke-linecap values used on paths with a single,
non-zero length subpath. The white line is the path itself and the thick
gray area is the stroke.\
On the top row, the green lines indicate the perpendicular to the
tangent at the path endpoints and the pink areas are the caps. The
bottom row shows the stroke without the perpendicular and cap
highlighting.](images/linecap-construction.svg){height="350"
width="600"}

#### 4.6.5. Line Join Shape

The [line join shape] for a given segment of a subpath is determined as follows:

1. Let `P` be the point at the end of the segment.

2. Let `A` be the line parallel to the tangent at the end of
 the segment.

3. Let `B` be the line parallel to the tangent at the start
 of the following segment.

4. If `A` and `B` are the same line, then return
 an empty shape.

5. Let \|A~left~\| and \|A~right~\| be lines parallel to `A`
 at a distance of
 [stroke-width](#propdef-stroke-width) / 2 to the left and to the
 right of `A` relative to the subpath direction,
 respectively.

6. Let \|B~left~\| and \|B~right~\| be lines parallel to `B`
 at a distance of
 [stroke-width](#propdef-stroke-width) / 2 to the left and to the
 right of `B` relative to the subpath direction,
 respectively.

7. Let \|P~1~\|, \|P~2~\| and \|P~3~\| be points determined as follows:

 1. If the smaller angle between `A` and `B`
 is on the right of these lines, considering the direction of the
 subpath, then \|P~1~\| and \|P~2~\| are the points on
 \|A~left~\| and \|B~left~\| closest to `P`, and
 \|P~3~\| is the intersection of \|A~left~\| and \|B~left~\|.

 2. Otherwise, \|P~1~\| and \|P~2~\| are the points on \|A~right~\|
 and \|B~right~\| closest to `P`, and \|P~3~\| is the
 intersection of \|A~right~\| and \|B~right~\|.

8. Let `bevel` be the triangle formed from the three points
 `P`, \|P~1~\| and \|P~2~\|.

9. If
 [stroke-linejoin](#propdef-stroke-linejoin) is
 [round](#valdef-stroke-linejoin-round), then return the union of `bevel`
 and a circular sector of radius
 [stroke-width](#propdef-stroke-width), centered on `P`,
 and which has \|P~1~\| and \|P~2~\| as the two endpoints of the arc.

10. If
 [stroke-linejoin](#propdef-stroke-linejoin) is
 [arcs](#valdef-stroke-linejoin-arcs), then find the circles that are tangent to
 the stroke edges at \|P~1~\| and \|P~2~\| with the same curvature as
 the edges at those points (see below). If both curvatures are zero,
 fall through to [miter-clip].

 Extend the stroke edges using these circles (or a line, in the case
 of zero curvature):

 - If the two circles (or circle and line) do not intersect, fall
 through to [miter-clip].

 - If the two circles (or circle and line) intersect, the line join
 region is defined by the lines that connect `P` with
 \|P~1~\| and \|P~2~\| and the arcs defined by the circles (or arc
 and line) between the closest intersection point to
 `P`, and \|P~1~\| and \|P~2~\|.

 Next, calculate the `miter limit` as defined in
 [§ 4.2.5 Stroke Corner Limits: the stroke-miterlimit
 property](#stroke-miterlimit). Clip any part of the line join
 region that extends past the `miter limit`. Return the
 resulting region.

 Note that the curvatures are calculated in
 user-space before any transforms are applied.

11. If
 [stroke-linejoin](#propdef-stroke-linejoin) is
 [miter](#valdef-stroke-linejoin-miter) or [miter-clip] then the line join
 region is the union of `bevel` and the triangle formed
 from the three points \|P~1~\|, \|P~2~\| and \|P~3~\|.

12. Let θ be the angle between A and B. If
 `1 / sin(θ / 2) ≤ `[`stroke-miterlimit`](#propdef-stroke-miterlimit), then return the line join
 region.

13. If
 [stroke-linejoin](#propdef-stroke-linejoin) is [miter-clip], then
 clip any part of the line join region that extends past the miter
 limit and return this region.

14. Return bevel.

![Construction of a round line join shape, shown in pink. The white line
is the original path, which has two segments that come to a point, and
the gray region is the
stroke.](images/linejoin-construction.svg){height="200" width="500"}

![Construction of an arcs line join shape, shown in pink. The white line
is the original path, which has two segments that come to a point, and
the gray region is the stroke. The dashed lines show circles that are
tangent to and have the curvature of the segments at the join. The
olive-green circles (concentric with the dashed circles) define the join
shape.](images/linejoin-construction-arcs.svg){height="200" width="500"}

#### 4.6.6. Arcs Linejoin

The [arcs linejoin] requires finding circles that are both tangent to and have
the same curvatures as the outer stroke edges at the ends of path
segments. To find one of these circles, first calculate the curvature κ
of the path segment at its end (see below). Next, find the radius of a
circle corresponding to this curvature: r = 1/κ. Increase or decrease
the radius by
[stroke-width](#propdef-stroke-width) / 2 to account for the stroke: rc =
r ± stroke-width/2. The center of the circle will be on a line normal to
the path end a distance of rc away from the outer stroke edge at the
end.

For a line:
: The curvature is infinite. Extend the outer stroke edge by a line.

For an elliptical arc:

: :::
 :::

 where:

 :::
 :::

 The parameter θ at the beginning or end of an arc segment can be
 found by using the formulas in the [Elliptical arc implementation
 notes](https://svgwg.org/svg2-draft/implnote.html#ArcImplementationNotes).
 (Note, some renderers convert elliptical arcs to cubic Béziers prior
 to rendering so the equations here may not be needed.)

For a quadratic Bézier:

: :::
 :::

 :::
 :::

 Where κ(0) and κ(1) are the signed curvatures at the start and end
 of the path segment respectively, and the P's are the three points
 that define the quadratic Bézier.

For a cubic Bézier:

: :::
 :::

 :::
 :::

 Where κ(0) and κ(1) are the signed curvatures at the start and end
 of the path segment respectively, and the P's are the four points
 that define the cubic Bézier. Note, if P0 and P1, or P2 and P3, are
 degenerate, the curvature will be infinite and a line should be used
 in constructing the join.

### 4.7. Perfect-World Syntax

The [stroke-\*] properties and values from SVG inherit SVG's
somewhat incoherent naming schemes. We'd name them differently if they
were being designed today. We should see how much we can move toward
this, perhaps with alias/shorthands.

Old Syntax

New Syntax

stroke

stroke-paint

[stroke](#propdef-stroke) shorthand

stroke-alignment

stroke-align: inset \| outset \| center

stroke-opacity

no change

stroke-width

no change

stroke-linecap

stroke-cap: none \| round \| square

stroke-linejoin

stroke-corner-shape: bevel \| round \| \[ arc \| miter \] \[ bevel \|
round \]?

stroke-miterlimit

stroke-corner-limit

stroke-dasharray

stroke-dash-array

stroke-dashoffset

stroke-dash-offset

stroke-dashcorner

stroke-dash-corner

stroke-dashadjust

stroke-dash-justify: none \| \[ stretch \| compress \] \|\| \[ dashes \|
gaps \]

stroke-dash shorthand

## 5. Text Decoration Fills and Strokes

For handling fills and strokes on text decorations, two sets of
[fill](#propdef-fill) and
[stroke](#propdef-stroke) properties are defined: one prefixed with
[text-decoration-\*] for [line
decorations](https://drafts.csswg.org/css-text-decor-3/#line-decoration)
and one prefixed with [text-emphasis-\*] for [emphasis
marks](https://drafts.csswg.org/css-text-decor-3/#emphasis-marks). These
properties are exactly analogous to the [fill] and [stroke] properties
above, except that:

- (like
 [text-decoration](https://drafts.csswg.org/css-text-decor-4/#propdef-text-decoration) itself) the
 [text-decoration-\*] variants do not inherit.

- the initial value of each such property is a [match-text]
 keyword which takes the value from the element's corresponding
 [fill-\*]/[stroke-\*] property.

These should definitely be at-risk,
possibly deferred to the next level.

## 6. Privacy Considerations

No new privacy considerations have been reported on this specification.

## 7. Security Considerations

No new security considerations have been reported on this specification.
