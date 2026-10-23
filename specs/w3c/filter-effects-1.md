## 1. Introduction

*This section is not normative*

A filter effect is a graphical operation that is applied to an element
as it is drawn into the document. It is an image-based effect, in that
it takes zero or more images as input, a number of parameters specific
to the effect, and then produces an image as output. The output image is
either rendered into the document instead of the original element, used
as an input image to another filter effect, or provided as a CSS image
value.

A simple example of a filter effect is a "flood". It takes no image
inputs but has a parameter defining a color. The effect produces an
output image that is completely filled with the given color. A slightly
more complex example is an "inversion" which takes a single image input
(typically an image of the element as it would normally be rendered into
its parent) and adjusts each pixel such that they have the opposite
color values.

Filter effects are exposed with two levels of complexity:

1. A small set of canned filter functions that are given by name. While
 not particularly powerful, these are convenient and easily
 understood and provide a simple approach to achieving common
 effects, such as blurring. The canned filters can also be animated
 by
 [\[CSS3-ANIMATIONS\]](#biblio-css3-animations).

2. A graph of individual filter effects described in markup that define
 an overall effect. The graph is agnostic to its input in that the
 effect can be applied to any content. While such graphs are the
 combination of effects that may be simple in isolation, the graph as
 a whole can produce complex effects. An example is given below.

In this example, an image is filtered
with the
[\<grayscale()\>](#funcdef-filter-grayscale) filter function.

``` highlight
#image {
 filter: grayscale(100%);
}
```

![Example for grayscale filter applied to
image](images/grayscale.svg){height="260" width="451"}

An image without filter (left) and the same filter with a 100% grayscale
filter (right).

The following shows an example of
graph of individual filter effects.

![Example Filter](examples/filters01.png)

Initial example for a filtered object.

[View this example as SVG](examples/filters01.svg)

The filter effect used in the example above is repeated here with
reference numbers in the left column before each of the six filter
primitives:

\
\
1\
2\
3\
\
\
\
\
4\
5\
\
6\
\
\

```
<filter id="MyFilter" filterUnits="userSpaceOnUse" x="0" y="0" width="200" height="120">
 <desc>Produces a 3D lighting effect.</desc>
 <feGaussianBlur in="SourceAlpha" stdDeviation="4" resu/>
 <feOffset in="blur" dx="4" dy="4" resu/>
 <feSpecularLighting in="blur" surfaceScale="5" specularConstant=".75"
 specularExponent="20" lighting-color="#bbbbbb"
 resu>
 <fePointLight x="-5000" y="-10000" z="20000"/>
 </feSpecularLighting>
 <feComposite in="specOut" in2="SourceAlpha" operator="in" resu/>
 <feComposite in="SourceGraphic" in2="specOut" operator="arithmetic"
 k1="0" k2="1" k3="1" k4="0" resu/>
 <feMerge>
 <feMergeNode in="offsetBlur"/>
 <feMergeNode in="litPaint"/>
 </feMerge>
</filter>
```

The following pictures show the intermediate image results from each of
the six filter elements:

![filters01 - original source
graphic](examples/filters01-0.png){height="70" width="115"}

Source graphic

![filters01 - after filter element
1](examples/filters01-1.png){height="70" width="115"}

After filter primitive 1

![filters01 - after filter element
2](examples/filters01-2.png){height="70" width="115"}

After filter primitive 2

![filters01 - after filter element
3](examples/filters01-3.png){height="70" width="115"}

After filter primitive 3

![filters01 - after filter element
4](examples/filters01-4.png){height="70" width="115"}

After filter primitive 4

![filters01 - after filter element
5](examples/filters01-5.png){height="70" width="115"}

After filter primitive 5

![filters01 - after filter element
6](examples/filters01-6.png){height="70" width="115"}

After filter primitive 6

1. Filter primitive
 [feGaussianBlur](#elementdef-fegaussianblur) takes input
 [SourceAlpha](#attr-valuedef-in-sourcealpha), which is the alpha channel of the source
 graphic. The result is stored in a temporary buffer named \"blur\".
 Note that \"blur\" is used as input to both filter primitives 2 and
 3.

2. Filter primitive
 [feOffset](#elementdef-feoffset) takes buffer \"blur\", shifts the result in a
 positive direction in both x and y, and creates a new buffer named
 \"offsetBlur\". The effect is that of a drop shadow.

3. Filter primitive
 [feSpecularLighting](#elementdef-fespecularlighting), uses buffer \"blur\" as a model of a surface
 elevation and generates a lighting effect from a single point
 source. The result is stored in buffer \"specOut\".

4. Filter primitive
 [feComposite](#elementdef-fecomposite) masks out the result of filter primitive 3 by
 the original source graphics alpha channel so that the intermediate
 result is no bigger than the original source graphic.

5. Filter primitive
 [feComposite](#elementdef-fecomposite) composites the result of the specular lighting
 with the original source graphic.

6. Filter primitive
 [feMerge](#elementdef-femerge) composites two layers together. The lower layer
 consists of the drop shadow result from filter primitive 2. The
 upper layer consists of the specular lighting result from filter
 primitive 5.

## 2. Module interactions

This specification defines a set of CSS properties that affect the
visual rendering of elements to which those properties are applied;
these effects are applied after elements have been sized and positioned
according to the [Visual formatting
model](https://www.w3.org/TR/CSS2/visuren.html) from
[\[CSS21\]](#biblio-css21). Some values of these
properties result in the creation of a [containing
block](https://www.w3.org/TR/css-display-3/#containing-block), and/or the creation of a [stacking
context](https://www.w3.org/TR/css3-positioning/#stacking-context).

The compositing model follows the SVG compositing model
[\[SVG11\]](#biblio-svg11): first any filter effect
is applied, then any clipping, masking and opacity
[\[CSS3COLOR\]](#biblio-css3color). These effects
all apply after any other CSS effects such as
[border](https://www.w3.org/TR/css3-background/#propdef-border)
[\[CSS3BG\]](#biblio-css3bg).

Some property and element definitions in this specification require an
SVG 1.1 implementation [\[SVG11\]](#biblio-svg11).
UAs without support for SVG must not implement the
[color-interpolation-filters](#propdef-color-interpolation-filters),
[flood-color](#propdef-flood-color),
[flood-opacity](#propdef-flood-opacity) and
[lighting-color](#propdef-lighting-color) properties as well as the
[filter](#elementdef-filter) element, the
[feMergeNode](#elementdef-femergenode) element, the [transfer function
elements](#transfer-function-element) and the [filter
primitive](#filter-primitive)
elements.

## 3. Values

This specification follows the [CSS property definition
conventions](https://www.w3.org/TR/CSS21/about.html#property-defs) from
[\[CSS21\]](#biblio-css21). Value types not defined
in these specifications are defined in CSS Values and Units Module Level
3 [\[CSS3VAL\]](#biblio-css3val).

In addition to the property-specific values listed in their definitions,
all properties defined in this specification also accept the
[inherit](https://www.w3.org/TR/CSS21/cascade.html#value-def-inherit)
keyword as their property value. For readability it has not been
repeated explicitly.

## 4. Terminology

When used in this specification, terms have the meanings assigned in
this section.

[filter primitive], [`filter-primitive`]

: The set of elements that control the output of a
 [filter](#elementdef-filter) element, particularly:
 [feSpotLight](#elementdef-fespotlight),
 [feBlend](#elementdef-feblend),
 [feColorMatrix](#elementdef-fecolormatrix),
 [feComponentTransfer](#elementdef-fecomponenttransfer),
 [feComposite](#elementdef-fecomposite),
 [feConvolveMatrix](#elementdef-feconvolvematrix),
 [feDiffuseLighting](#elementdef-fediffuselighting),
 [feDisplacementMap](#elementdef-fedisplacementmap),
 [feDropShadow](#elementdef-fedropshadow),
 [feFlood](#elementdef-feflood),
 [feGaussianBlur](#elementdef-fegaussianblur),
 [feImage](#elementdef-feimage),
 [feMerge](#elementdef-femerge),
 [feMorphology](#elementdef-femorphology),
 [feOffset](#elementdef-feoffset),
 [feSpecularLighting](#elementdef-fespecularlighting),
 [feTile](#elementdef-fetile),
 [feTurbulence](#elementdef-feturbulence).

[pass through filter]

: The pass through filter output is equal to the primary input of the
 filter primitive.

## 5. Graphic filters: the [filter property]
The description of the
[filter](#propdef-filter) property is as follows:

Name:

[filter]

[Value:](https://drafts.csswg.org/css-values/#value-defs)

none
[\|](https://www.w3.org/TR/css-values-4/#comb-one)
[\<filter-value-list\>](#typedef-filter-value-list)

[Initial:](https://drafts.csswg.org/css-cascade/#initial-values)

none

Applies to:

All elements. In SVG, it applies to [container
elements](https://www.w3.org/TR/svg2/struct.html#container-element) without the
[defs](https://www.w3.org/TR/svg2/struct.html#elementdef-defs) element, all [graphics
elements](https://www.w3.org/TR/svg2/struct.html#graphics-element) and the
[use](https://www.w3.org/TR/svg2/struct.html#elementdef-use) element.

[Inherited:](https://drafts.csswg.org/css-cascade/#inherited-property)

no

[Percentages:](https://drafts.csswg.org/css-values/#percentages)

n/a

[Computed value:](https://drafts.csswg.org/css-cascade/#computed)

as specified

Canonical order:

per grammar

Media:

visual

[Animatable:](https://drafts.csswg.org/web-animations/#animation-type)

See prose in [Animation of Filters](#animation-of-filters).

``` prod
<filter-value-list> = [ <filter-function> | <url> ]+
```

[\<url\>]

: A filter reference to a
 [filter](#elementdef-filter) element. For example
 [url(commonfilters.svg#filter)]. If the filter references a
 non-existent object or the referenced object is not a
 [filter] element, then the whole filter
 chain is ignored. No filter is applied to the object.

[\<filter-function\>](#typedef-filter-function)

: See [Filter Functions](#filter-functions).

none

: No filter effect gets applied.

A value other than [none] for the
[filter](#propdef-filter) property results in the creation of a [containing
block](https://www.w3.org/TR/css-display-3/#containing-block) for absolute and fixed positioned descendants unless
the element it applies to is a document root element in the current
[browsing
context](https://html.spec.whatwg.org/multipage/browsers.html#browsing-context). The list of functions are applied in the order
provided.

The first filter function or
[filter](#elementdef-filter) reference in the list takes the element
([SourceGraphic](#attr-valuedef-in-sourcegraphic)) as the input image. Subsequent operations take
the output from the previous filter function or
[filter] reference as the input image.
[filter] element reference functions can
specify an alternate input, but still uses the previous output as its
[SourceGraphic].

[color-interpolation-filters](#propdef-color-interpolation-filters) has no affect for Filter Functions.
Filter Functions must operate in the sRGB color space.

A computed value of other than [none] results in the creation of a
[stacking context](https://www.w3.org/TR/CSS21/zindex.html)
[\[CSS21\]](#biblio-css21) the same way that CSS
[opacity](https://www.w3.org/TR/css-color-4/#propdef-opacity) does. All the elements descendants are
rendered together as a group with the filter effect applied to the group
as a whole.

The [filter](#propdef-filter) property has no effect on the geometry of the
target element's CSS boxes, even though
[filter] can cause painting outside
of an element's border box.

Conceptually, any parts of the drawing are effected by filter
operations. This includes any content, background, borders, text
decoration, outline and visible scrolling mechanism of the element to
which the filter is applied, and those of its descendants. The filter
operations are applied in the element's [local coordinate
system](https://www.w3.org/TR/css-transforms-1/#local-coordinate-system).

The compositing model follows the [SVG compositing
model](https://www.w3.org/TR/SVG11/render.html#Introduction)
[\[SVG11\]](#biblio-svg11): first any filter effect
is applied, then any clipping, masking and opacity. As per SVG, the
application of [filter](#propdef-filter) has no effect on hit-testing.

The [filter](#propdef-filter) property is a [presentation
attribute](https://www.w3.org/TR/2011/REC-SVG11-20110816/intro.html#TermPresentationAttribute)
for SVG elements.

How does filter behave on fixed
background images?
[\<https://github.com/w3c/csswg-drafts/issues/238\>](https://github.com/w3c/csswg-drafts/issues/238)

## 6. Filter Functions

### 6.1. Supported Filter Functions

``` prod
<filter-function> = <blur()> | <brightness()> | <contrast()> | <drop-shadow()> |
<grayscale()> | <hue-rotate()> | <invert()> | <opacity()> | <sepia()> | <saturate()>
```

Unless defined otherwise, omitted values default to the [initial
value](https://svgwg.org/svg2-draft/types.html#TermInitialValue) for interpolation.

Note: For some filter functions the default value for omitted values
differes from their [initial
value](https://svgwg.org/svg2-draft/types.html#TermInitialValue) for interpolation. For the convenience of content
creators, the default value for omitted values for
[\<grayscale()\>](#funcdef-filter-grayscale),
[\<sepia()\>](#funcdef-filter-sepia) and
[\<invert()\>](#funcdef-filter-invert) is [1] (apply the effect to
100%) while the [initial value] for
interpolation is [0] (no effect).

``` prod
blur() = blur( <length>? )
```

Applies a Gaussian blur to the input image. The passed parameter defines
the value of the standard deviation to the Gaussian function. The
parameter is specified a CSS length, but does not accept percentage
values. The markup equivalent of this function is [given
below](#blurEquivalent).

Negative values are not allowed.

Default value when omitted is [0px].

The [initial
value](https://svgwg.org/svg2-draft/types.html#TermInitialValue) for interpolation is [0px].

Note: Standard deviation is different to
[box-shadow](https://www.w3.org/TR/css3-background/#propdef-box-shadow) s blur radius.

``` prod
brightness() = brightness( <number-percentage>? )
```

Applies a linear multiplier to input image, making it appear more or
less bright. A value of [0%] will create an image that is
completely black. A value of [100%] leaves the input unchanged.
Other values are linear multipliers on the effect. Values of amount over
100% are allowed, providing brighter results. The markup equivalent of
this function is [given below](#brightnessEquivalent).

Negative values are not allowed.

Default value when omitted is [1].

The [initial
value](https://svgwg.org/svg2-draft/types.html#TermInitialValue) for interpolation is [1].

``` prod
contrast() = contrast( <number-percentage>? )
```

Adjusts the contrast of the input. A value of [0%] will create an
image that is completely gray. A value of [100%] leaves the input
unchanged. Values of amount over 100% are allowed, providing results
with more contrast. The markup equivalent of this function is [given
below](#contrastEquivalent).

Negative values are not allowed.

Default value when omitted is [1].

The [initial
value](https://svgwg.org/svg2-draft/types.html#TermInitialValue) for interpolation is [1].

``` prod
drop-shadow() = drop-shadow( <color>? && <length>{2,3} )
```

Applies a drop shadow effect to the input image. A drop shadow is
effectively a blurred, offset version of the input image's alpha mask
drawn in a particular color, composited below the image. Values are
interpreted as for
[box-shadow](https://www.w3.org/TR/css3-background/#propdef-box-shadow)
[\[CSS3BG\]](#biblio-css3bg) but with the optional
3rd
[\<length\>](https://www.w3.org/TR/css3-values/#length-value "Expands to: em | vb | ch | cm | vh | vi | in | ex | vw | ic | pt | px | lh | pc | rem | rlh | vmax | advance measure | vmin | mm | cap | q") value being the standard deviation
instead of blur radius. The markup equivalent of this function is [given
below](#dropshadowEquivalent).

The default value for omitted values is missing length values set to
[0] and the missing used color is taken from the color property.

The [initial
value](https://svgwg.org/svg2-draft/types.html#TermInitialValue) for interpolation is all length values set to [0]
and the used color set to
[transparent](https://www.w3.org/TR/css-color-4/#valdef-color-transparent).

Note: Spread values or multiple shadows are not accepted for this level
of the specification.

Note: Standard deviation is different to
[box-shadow](https://www.w3.org/TR/css3-background/#propdef-box-shadow) s blur radius.

``` prod
grayscale() = grayscale( <number-percentage>? )
```

Converts the input image to grayscale. The passed parameter defines the
proportion of the conversion. A value of [100%] is completely
grayscale. A value of [0%] leaves the input unchanged. Values
between [0%] and [100%] are linear multipliers on the
effect. Values of amount over [100%] are allowed but UAs must
clamp the values to [1]. The markup equivalent of this function is
[given below](#grayscaleEquivalent).

Negative values are not allowed.

Default value when omitted is [1].

The [initial
value](https://svgwg.org/svg2-draft/types.html#TermInitialValue) for interpolation is [0].

``` prod
hue-rotate() = hue-rotate( [ <angle> | <zero> ]? )
```

Applies a hue rotation on the input image. The passed parameter defines
the number of degrees around the color circle the input samples will be
adjusted. A value of [0deg] leaves the input unchanged.
Implementations must not normalize this value in order to allow
animations beyond [360deg]. The markup equivalent of this function
is [given below](#huerotateEquivalent).

The unit identifier may be omitted if the
[\<angle\>](https://www.w3.org/TR/css3-values/#angle-value "Expands to: turn | rad | grad | deg") is zero.

Default value when omitted is [0deg].

The [initial
value](https://svgwg.org/svg2-draft/types.html#TermInitialValue) for interpolation is [0deg].

``` prod
invert() = invert( <number-percentage>? )
```

Inverts the samples in the input image. The passed parameter defines the
proportion of the conversion. A value of 100% is completely inverted. A
value of [0%] leaves the input unchanged. Values between
[0%] and [100%] are linear multipliers on the effect. Values
of amount over [100%] are allowed but UAs must clamp the values to
[1]. The markup equivalent of this function is [given
below](#invertEquivalent).

Negative values are not allowed.

Default value when omitted is [1].

The [initial
value](https://svgwg.org/svg2-draft/types.html#TermInitialValue) for interpolation is [0].

``` prod
opacity() = opacity( <number-percentage>? )
```

Applies transparency to the samples in the input image. The passed
parameter defines the proportion of the conversion. A value of
[0%] is completely transparent. A value of [100%] leaves the
input unchanged. Values between [0%] and [100%] are linear
multipliers on the effect. This is equivalent to multiplying the input
image samples by amount. Values of amount over [100%] are allowed
but UAs must clamp the values to [1]. The markup equivalent of
this function is [given below](#opacityEquivalent).

Negative values are not allowed.

Default value when omitted is [1].

The [initial
value](https://svgwg.org/svg2-draft/types.html#TermInitialValue) for interpolation is [1].

Note: The opacity filter function is not meant to be a shorthand of the
[opacity](https://www.w3.org/TR/css-color-4/#propdef-opacity) property. Furthermore, it allows setting
the transparency of intermediate filter primitive results before passing
to the next filter primitive. If the opacity filter function is set as
last filter primitive, the value of the
[opacity] property is multiplied on
top of the value of the filter function, which may result in a more
transparent content.

``` prod
saturate() = saturate( <number-percentage>? )
```

Saturates the input image. The passed parameter defines the proportion
of the conversion. A value of [0%] is completely un-saturated. A
value of [100%] leaves the input unchanged. Other values are
linear multipliers on the effect. Values of amount over [100%] are
allowed, providing super-saturated results. The markup equivalent of
this function is [given below](#saturateEquivalent).

Negative values are not allowed.

Default value when omitted is [1].

The [initial
value](https://svgwg.org/svg2-draft/types.html#TermInitialValue) for interpolation is [1].

``` prod
sepia() = sepia( <number-percentage>? )
```

Converts the input image to sepia. The passed parameter defines the
proportion of the conversion. A value of [100%] is completely
sepia. A value of [0%] leaves the input unchanged. Values between
0% and 100% are linear multipliers on the effect. Values of amount over
[100%] are allowed but UAs must clamp the values to [1]. The
markup equivalent of this function is [given below](#sepiaEquivalent).

Negative values are not allowed.

Default value when omitted is [1].

The [initial
value](https://svgwg.org/svg2-draft/types.html#TermInitialValue) for interpolation is [0].

### 6.2. Computed Values of Filter Functions

The values in a
[\<filter-function\>](#typedef-filter-function) are computed as specified, with these
exceptions:

- Omitted values are included and compute to their defaults.

- [\<drop-shadow()\>](#funcdef-filter-drop-shadow) starts with the computed value
 of
 [\<color\>](https://www.w3.org/TR/css3-color/#valuea-def-color "Expands to: indigo | gold | firebrick | indianred | yellow | darkolivegreen | darkseagreen | slategrey | darkslategrey | mediumvioletred | mediumorchid | transparent | chartreuse | mediumslateblue | black | springgreen | crimson | lightsalmon | brown | turquoise | olivedrab | cyan | silver | skyblue | gray | darkturquoise | goldenrod | darkgreen | darkviolet | darkgray | lightpink | teal | darkmagenta | lightgoldenrodyellow | lavender | yellowgreen | thistle | violet | navy | dimgrey | orchid | blue | ghostwhite | honeydew | cornflowerblue | darkblue | darkkhaki | mediumpurple | cornsilk | red | bisque | slategray | darkcyan | khaki | wheat | deepskyblue | rebeccapurple | darkred | steelblue | aliceblue | lightslategrey | gainsboro | mediumturquoise | floralwhite | coral | purple | lightgrey | lightcyan | darksalmon | beige | azure | lightsteelblue | oldlace | greenyellow | royalblue | lightseagreen | mistyrose | sienna | lightcoral | orangered | navajowhite | lime | palegreen | burlywood | seashell | mediumspringgreen | fuchsia | papayawhip | blanchedalmond | peru | aquamarine | white | darkslategray | tomato | ivory | dodgerblue | currentcolor | lemonchiffon | chocolate | orange | forestgreen | darkgrey | olive | mintcream | antiquewhite | darkorange | cadetblue | moccasin | limegreen | saddlebrown | grey | darkslateblue | lightskyblue | deeppink | plum | aqua | darkgoldenrod | maroon | sandybrown | magenta | tan | rosybrown | pink | lightblue | palevioletred | mediumseagreen | slateblue | dimgray | powderblue | seagreen | snow | mediumblue | midnightblue | paleturquoise | palegoldenrod | whitesmoke | darkorchid | salmon | lightslategray | lawngreen | lightgreen | lightgray | hotpink | lightyellow | lavenderblush | linen | mediumaquamarine | green | blueviolet | peachpuff") followed by the computed value of
 the
 [\<length\>](https://www.w3.org/TR/css3-values/#length-value "Expands to: em | vb | ch | cm | vh | vi | in | ex | vw | ic | pt | px | lh | pc | rem | rlh | vmax | advance measure | vmin | mm | cap | q") values.

### 6.3. Serialization of Filter Functions

To serialize the
[\<filter-function\>](#typedef-filter-function), serialize as per their individual
grammars, in the order the grammars are written in, avoiding
[\<calc()\>](https://www.w3.org/TR/css-values-4/#funcdef-calc) expressions where possible,
serialize filter arguments as specified, avoiding
[\<calc()\>] transformations,
joining space-separated tokens with a single space, and following each
serialized comma with a single space.

### 6.4. Interpolation of Filter Functions

For interpolation of values in
[\<filter-function\>](#typedef-filter-function)s, the steps corresponding to the
first matching condition in the following list must be run:

[\<blur()\>](#funcdef-filter-blur)

: Interpolate values as length [by computed
 value](https://drafts.csswg.org/web-animations-1/#by-computed-value).

[\<brightness()\>](#funcdef-filter-brightness)\
[\<contrast()\>](#funcdef-filter-contrast)\
[\<grayscale()\>](#funcdef-filter-grayscale)\
[\<invert()\>](#funcdef-filter-invert)\
[\<opacity()\>](#funcdef-filter-opacity)\
[\<saturate()\>](#funcdef-filter-saturate)\
[\<sepia()\>](#funcdef-filter-sepia)

: Convert percentage values to numbers with 0% being relative to 0 and
 100% relative to 1. Interpolate values as number [by computed
 value](https://drafts.csswg.org/web-animations-1/#by-computed-value)
 .

[\<hue-rotate()\>](#funcdef-filter-hue-rotate)

: Interpolate values as number [by computed
 value](https://drafts.csswg.org/web-animations-1/#by-computed-value).

[\<drop-shadow()\>](#funcdef-filter-drop-shadow)

: Interpolate values as shadow list as [repeatable
 list](https://drafts.csswg.org/web-animations-1/#repeatable-list).

## 7. SVG Filter Sources: the [filter element]
Name:

[`filter`]

Categories:

None.

Content model:

Any number of the following elements, in any order:

- [descriptive](https://www.w3.org/TR/2011/REC-SVG11-20110816/intro.html#TermDescriptiveElement)
 [ ---
 [desc](https://www.w3.org/TR/svg2/struct.html#elementdef-desc),
 [title](https://www.w3.org/TR/svg2/struct.html#elementdef-title),
 [metadata](https://www.w3.org/TR/svg2/struct.html#elementdef-metadata)]
- [filter
 primitive](#elementdef-filter-primitive)
 [ --- [feBlend](#elementdef-feblend),
 [feFlood](#elementdef-feflood),
 [feColorMatrix](#elementdef-fecolormatrix),
 [feComponentTransfer](#elementdef-fecomponenttransfer),
 [feComposite](#elementdef-fecomposite),
 [feConvolveMatrix](#elementdef-feconvolvematrix),
 [feDiffuseLighting](#elementdef-fediffuselighting),
 [feDisplacementMap](#elementdef-fedisplacementmap),
 [feDropShadow](#elementdef-fedropshadow),
 [feGaussianBlur](#elementdef-fegaussianblur),
 [feImage](#elementdef-feimage),
 [feMerge](#elementdef-femerge),
 [feMorphology](#elementdef-femorphology),
 [feOffset](#elementdef-feoffset),
 [feSpecularLighting](#elementdef-fespecularlighting),
 [feTile](#elementdef-fetile),
 [feTurbulence](#elementdef-feturbulence)]
- [animate](https://www.w3.org/TR/SVG11/animate.html#AnimateElement)
- [script](https://www.w3.org/TR/svg2/interact.html#elementdef-script)
- [set](https://www.w3.org/TR/SVG11/animate.html#SetElement)

Attributes:

- [core
 attributes](https://www.w3.org/TR/2011/REC-SVG11-20110816/intro.html#TermCoreAttributes)[
 ---
 [[id]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#IDAttribute),
 [[xml:base]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#XMLBaseAttribute),
 [[xml:lang]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#XMLLangAttribute),
 [[xml:space]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#XMLSpaceAttribute)]
- [presentation
 attributes](https://www.w3.org/TR/2008/REC-SVGTiny12-20081222/intro.html#TermPresentationAttribute)[
 ---
 [alignment-baseline](https://www.w3.org/TR/SVG11/text.html#AlignmentBaselineProperty),
 [baseline-shift](https://www.w3.org/TR/SVG11/text.html#BaselineShiftProperty),
 [clip](https://www.w3.org/TR/css-masking-1/#propdef-clip),
 [clip-path](https://www.w3.org/TR/css-masking-1/#propdef-clip-path),
 [clip-rule](https://www.w3.org/TR/css-masking-1/#propdef-clip-rule),
 [color](https://www.w3.org/TR/css3-color/#color0),
 [color-interpolation](https://www.w3.org/TR/svg2/painting.html#ColorInterpolationProperty),
 [color-interpolation-filters](#propdef-color-interpolation-filters),
 [color-rendering](https://www.w3.org/TR/svg2/painting.html#ColorRenderingProperty),
 [cursor](https://www.w3.org/TR/css3-ui/#propdef-cursor),
 [direction](https://www.w3.org/TR/css-writing-modes-3/#propdef-direction),
 [display](https://www.w3.org/TR/css-display-3/#propdef-display),
 [dominant-baseline](https://www.w3.org/TR/SVG11/text.html#DominantBaselineProperty),
 [enable-background](https://www.w3.org/TR/SVG11/filters.html#EnableBackgroundProperty),
 [fill](https://www.w3.org/TR/svg2/painting.html#FillProperty),
 [fill-opacity](https://www.w3.org/TR/svg2/painting.html#FillOpacityProperty),
 [fill-rule](https://www.w3.org/TR/svg2/painting.html#FillRuleProperty),
 [filter](#propdef-filter),
 [flood-color](#propdef-flood-color),
 [flood-opacity](#propdef-flood-opacity),
 [font](https://www.w3.org/TR/css-fonts-3/#propdef-font),
 [font-family](https://www.w3.org/TR/css-fonts-3/#propdef-font-family),
 [font-size](https://www.w3.org/TR/css-fonts-3/#propdef-font-size),
 [font-size-adjust](https://www.w3.org/TR/css-fonts-4/#propdef-font-size-adjust),
 [font-stretch](https://www.w3.org/TR/css-fonts-3/#propdef-font-stretch),
 [font-style](https://www.w3.org/TR/css-fonts-3/#propdef-font-style),
 [font-variant](https://www.w3.org/TR/css-fonts-3/#propdef-font-variant),
 [font-weight](https://www.w3.org/TR/css-fonts-3/#propdef-font-weight),
 [glyph-orientation-horizontal](https://www.w3.org/TR/SVG11/text.html#GlyphOrientationHorizontalProperty),
 [glyph-orientation-vertical](https://www.w3.org/TR/SVG11/text.html#GlyphOrientationVerticalProperty),
 [image-rendering](https://drafts.csswg.org/css-images-3/#propdef-image-rendering),
 [isolation](https://www.w3.org/TR/compositing-1/#propdef-isolation),
 [kerning](https://www.w3.org/TR/SVG11/text.html#KerningProperty),
 [letter-spacing](https://www.w3.org/TR/css-text-3/#propdef-letter-spacing),
 [lighting-color](#propdef-lighting-color),
 [marker](https://www.w3.org/TR/svg2/painting.html#MarkerProperty),
 [marker-end](https://www.w3.org/TR/svg2/painting.html#MarkerEndProperty),
 [marker-mid](https://www.w3.org/TR/svg2/painting.html#MarkerMidProperty),
 [marker-start](https://www.w3.org/TR/svg2/painting.html#MarkerStartProperty),
 [mask](https://www.w3.org/TR/css-masking-1/#propdef-mask),
 [opacity](https://www.w3.org/TR/css-color-4/#propdef-opacity),
 [overflow](https://www.w3.org/TR/css-overflow-3/#propdef-overflow),
 [pointer-events](https://www.w3.org/TR/svg2/interact.html#PointerEventsProperty),
 [shape-rendering](https://www.w3.org/TR/svg2/painting.html#ShapeRenderingProperty),
 [stop-color](https://www.w3.org/TR/svg2/pservers.html#StopColorProperty),
 [stop-opacity](https://www.w3.org/TR/svg2/pservers.html#StopOpacityProperty),
 [stroke](https://www.w3.org/TR/svg2/painting.html#StrokeProperty),
 [stroke-dasharray](https://www.w3.org/TR/svg2/painting.html#StrokeDasharrayProperty),
 [stroke-dashoffset](https://www.w3.org/TR/svg2/painting.html#StrokeDashoffsetProperty),
 [stroke-linecap](https://www.w3.org/TR/svg2/painting.html#StrokeLinecapProperty),
 [stroke-linejoin](https://www.w3.org/TR/svg2/painting.html#StrokeLinejoinProperty),
 [stroke-miterlimit](https://www.w3.org/TR/svg2/painting.html#StrokeMiterlimitProperty),
 [stroke-opacity](https://www.w3.org/TR/svg2/painting.html#StrokeOpacityProperty),
 [stroke-width](https://www.w3.org/TR/svg2/painting.html#StrokeWidthProperty),
 [text-anchor](https://www.w3.org/TR/svg2/text.html#TextAnchorProperty),
 [text-decoration](https://www.w3.org/TR/css-text-decor-3/#propdef-text-decoration),
 [text-rendering](https://www.w3.org/TR/svg2/painting.html#TextRenderingProperty),
 [unicode-bidi](https://www.w3.org/TR/css-writing-modes-3/#propdef-unicode-bidi),
 [visibility](https://www.w3.org/TR/CSS21/visufx.html#propdef-visibility),
 [word-spacing](https://www.w3.org/TR/css-text-3/#propdef-word-spacing),
 [writing-mode](https://www.w3.org/TR/css-writing-modes-4/#propdef-writing-mode)]
- [[class]](https://www.w3.org/TR/2011/REC-SVG11-20110816/styling.html#ClassAttribute)
- [[style]](https://www.w3.org/TR/2011/REC-SVG11-20110816/styling.html#StyleAttribute)
- [[externalResourcesRequired]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#ExternalResourcesRequiredAttribute)
- [x](#element-attrdef-filter-x)
- [y](#element-attrdef-filter-y)
- [width](#element-attrdef-filter-width)
- [height](#element-attrdef-filter-height)
- [filterUnits](#element-attrdef-filter-filterunits)
- [primitiveUnits](#element-attrdef-filter-primitiveunits)

DOM Interfaces:

[SVGFilterElement](#InterfaceSVGFilterElement)

The description of the
[filter](#elementdef-filter) element follows:

[\<number-optional-number\>] =
[\<number\>](https://www.w3.org/TR/css3-values/#number-value) [\<number\>]?

*Attribute definitions:*

[`filterUnits`] = \"[`userSpaceOnUse`] \| [`objectBoundingBox`]\"

: See [filter region](#filter-region).

[`primitiveUnits`] = \"[`userSpaceOnUse`] \| [`objectBoundingBox`]\"

: Specifies the coordinate system for the various length values within
 the [filter
 primitives](#filter-primitive) and for the attributes that define the [filter
 primitive
 subregion](#filter-primitive-subregion).

 If
 [primitiveUnits](#element-attrdef-filter-primitiveunits) is equal to
 [userSpaceOnUse](#attr-valuedef-primitiveunits-userspaceonuse), any length values within the filter
 definitions represent values in the current [local coordinate
 system](https://www.w3.org/TR/css-transforms-1/#local-coordinate-system) in place at the time when the
 [filter](#elementdef-filter) element is referenced (i.e., the user
 coordinate system for the element referencing the
 [filter] element via a
 [filter](#propdef-filter) property).

 If
 [primitiveUnits](#element-attrdef-filter-primitiveunits) is equal to
 [objectBoundingBox](#attr-valuedef-primitiveunits-objectboundingbox), then any length values within the filter
 definitions represent fractions or percentages of the bounding box
 on the referencing element (see [object bounding box
 units](https://svgwg.org/svg2-draft/coords.html#ObjectBoundingBoxUnits)). Note that if only one number was specified in a
 [\<number-optional-number\>](#typedef-number-optional-number) value this number is expanded out
 before the
 [primitiveUnits]
 computation takes place.

 The [initial
 value](https://svgwg.org/svg2-draft/types.html#TermInitialValue) for
 [primitiveUnits](#element-attrdef-filter-primitiveunits) is
 [userSpaceOnUse](#attr-valuedef-primitiveunits-userspaceonuse).

 Animatable: yes.

[`x`] = \"[\<length-percentage\>](https://www.w3.org/TR/css-values-4/#typedef-length-percentage)\"

: See [filter region](#filter-region).

[`y`] = \"[\<length-percentage\>](https://www.w3.org/TR/css-values-4/#typedef-length-percentage)\"

: See [filter region](#filter-region).

[`width`] = \"[\<length-percentage\>](https://www.w3.org/TR/css-values-4/#typedef-length-percentage)\"

: See [filter region](#filter-region).

[`height`] = \"[\<length-percentage\>](https://www.w3.org/TR/css-values-4/#typedef-length-percentage)\"

: See [filter region](#filter-region).

[`filterRes`(#element-attrdef-filter-filterres)] = \"[\<number-optional-number\>](#typedef-number-optional-number)\"

: The *filterRes* attribute was removed from the specification. See
 SVG 1.1 specification for the defintion
 [\[SVG11\]](#biblio-svg11).

Properties inherit into the
[filter](#elementdef-filter) element from its ancestors; properties do *not*
inherit from the element referencing the
[filter] element.

[filter](#elementdef-filter) elements are never rendered directly; their only
usage is as something that can be referenced using the
[filter](#propdef-filter) property. The
[display](https://www.w3.org/TR/css-display-3/#propdef-display) property does not apply to the
[filter] element; thus,
[filter] elements are not directly
rendered even if the [display]
property is set to a value other than [none], and
[filter] elements are available for
referencing even when the [display]
property on the [filter] element or any of
its ancestors is set to [none].

## 8. Filter Region

A [filter](#elementdef-filter) element can define a [filter region] on the canvas to which a
given filter effect applies and can provide a resolution for any
intermediate continuous tone images used to process any raster-based
[filter primitives](#filter-primitive). The [filter] element has
the following attributes which work together to define the filter
region:

[filterUnits](#element-attrdef-filter-filterunits)

: Defines the coordinate system for attributes
 [x](#element-attrdef-filter-x),
 [y](#element-attrdef-filter-y),
 [width](#element-attrdef-filter-width),
 [height](#element-attrdef-filter-height).

 If
 [filterUnits](#element-attrdef-filter-filterunits) is equal to
 [userSpaceOnUse](#attr-valuedef-filterunits-userspaceonuse),
 [x](#element-attrdef-filter-x),
 [y](#element-attrdef-filter-y),
 [width](#element-attrdef-filter-width),
 [height](#element-attrdef-filter-height) represent values in the current user
 coordinate system in place at the time when the
 [filter](#elementdef-filter) element is referenced (i.e., the user
 coordinate system for the element referencing the
 [filter] element via a
 [filter](#propdef-filter) property).

 If
 [filterUnits](#element-attrdef-filter-filterunits) is equal to
 [objectBoundingBox](#attr-valuedef-filterunits-objectboundingbox), then
 [x](#element-attrdef-filter-x),
 [y](#element-attrdef-filter-y),
 [width](#element-attrdef-filter-width),
 [height](#element-attrdef-filter-height) represent fractions or percentages of the
 bounding box on the referencing element (see [object bounding box
 units](https://svgwg.org/svg2-draft/coords.html#ObjectBoundingBoxUnits)).

 The [initial
 value](https://svgwg.org/svg2-draft/types.html#TermInitialValue) for
 [filterUnits](#element-attrdef-filter-filterunits) is
 [objectBoundingBox](#attr-valuedef-filterunits-objectboundingbox).

 Animatable: yes.

[x](#element-attrdef-filter-x), [y](#element-attrdef-filter-y), [width](#element-attrdef-filter-width), [height](#element-attrdef-filter-height)

: These attributes define a rectangular region on the canvas to which
 this filter applies.

 The coordinate system for these attributes depends on the value for
 attribute
 [filterUnits](#element-attrdef-filter-filterunits).

 The bounds of this rectangle act as a hard clipping region for each
 [filter primitive](#filter-primitive) included with a given
 [filter](#elementdef-filter) element; thus, if the effect of a given filter
 primitive would extend beyond the bounds of the rectangle (this
 sometimes happens when using a
 [feGaussianBlur](#elementdef-fegaussianblur) filter primitive with a very large
 [stdDeviation](#element-attrdef-fegaussianblur-stddeviation)), parts of the effect will get clipped.

 The [initial
 value](https://svgwg.org/svg2-draft/types.html#TermInitialValue) for
 [x](#element-attrdef-filter-x) and
 [y](#element-attrdef-filter-y) is [-10%].

 The [initial
 value](https://svgwg.org/svg2-draft/types.html#TermInitialValue) for
 [width](#element-attrdef-filter-width) and
 [height](#element-attrdef-filter-height) is [120%].

 ng of the element which referenced the filter.

 Animatable: yes.

Note: Both of the two possible value for
[filterUnits](#element-attrdef-filter-filterunits) (i.e.,
[objectBoundingBox](#attr-valuedef-filterunits-objectboundingbox) and
[userSpaceOnUse](#attr-valuedef-filterunits-userspaceonuse)) result in a [filter
region](#filter-region) whose
coordinate system has its X-axis and Y-axis each parallel to the X-axis
and Y-axis, respectively, of the [local coordinate
system](https://www.w3.org/TR/css-transforms-1/#local-coordinate-system) for the element to which the filter will be applied.

Note: Sometimes implementers can achieve faster performance when the
filter region can be mapped directly to device pixels; thus, for best
performance on display devices, it is suggested that authors define
their region such that the user agent can align the [filter
region](#filter-region)
pixel-for-pixel with the background. In particular, for best filter
effects performance, avoid rotating or skewing the user coordinate
system.

Note: It is often necessary to provide padding space because the filter
effect might impact bits slightly outside the tight-fitting [bounding
box](https://www.w3.org/TR/svg2/coords.html#bounding-box) on a given object. For these purposes, it is possible
to provide negative percentage values for
[x](#element-attrdef-filter-x),
[y](#element-attrdef-filter-y) and percentages values greater than
[100%] for
[width](#element-attrdef-filter-width),
[height](#element-attrdef-filter-height). This, for example, is why the defaults for
the filter region are `x="-10%" y="-10%" width="120%" height="120%"`.

## 9. Filter primitives

### 9.1. Overview

This section describes the various filter primitives that can be
assembled to achieve a particular filter effect.

Unless otherwise stated, all image filters operate on premultiplied RGBA
samples. Some filters like
[feColorMatrix](#elementdef-fecolormatrix) and
[feComponentTransfer](#elementdef-fecomponenttransfer) work more naturally on non-premultiplied data. For
the time of the filter operation, all color values must temporarily be
transformed to the required color multiplication of the current filter.

Note: All input images are assumed to be in premultiplied RGBA. User
agents may optimize performance by using non-premultiplied data
buffering.

All raster effect filtering operations take 1 to N input RGBA images,
additional attributes as parameters, and produce a single output RGBA
image.

The RGBA result from each filter primitive will be clamped into the
allowable ranges for colors and opacity values. Thus, for example, the
result from a given [filter
primitive](#filter-primitive) will have any negative color values or opacity values
adjusted up to color/opacity of zero.

The color space in which a particular [filter
primitive](#filter-primitive) performs its operations is determined by the value of
the property
[color-interpolation-filters](#propdef-color-interpolation-filters) on the given [filter
primitive]. A different property,
[color-interpolation](https://www.w3.org/TR/svg2/painting.html#ColorInterpolationProperty) determines the color space for other
color operations. Because these two properties have different initial
values
([color-interpolation-filters] has an initial value of
[linearRGB](#valdef-color-interpolation-filters-linearrgb) whereas
[color-interpolation]
has an initial value of
[sRGB](#valdef-color-interpolation-filters-srgb)), in some cases to achieve certain results
(e.g., when coordinating gradient interpolation with a filtering
operation) it will be necessary to explicitly set
[color-interpolation] to
[linearRGB]
or
[color-interpolation-filters] to [sRGB] on particular elements. Note that the examples below do not
explicitly set either
[color-interpolation] or
[color-interpolation-filters], so the initial values for these properties apply to the
examples.

Sometimes [filter
primitives](#filter-primitive) result in undefined pixels. For example, filter
primitive [feOffset](#elementdef-feoffset) can shift an image down and to the right, leaving
undefined pixels at the top and left. In these cases, the undefined
pixels are set to transparent black.

To provide high quality rendering, all filter primitives should operate
in a device dependent coordinate space, the [operating coordinate
space], taking device pixel density, user space transformations
and zooming into account. To provide a platform independent alignment,
attribute and property values are often relative to a coordinate system
described by the
[primitiveUnits](#element-attrdef-filter-primitiveunits) attribute. User agents must scale these
relative attributes and properties to the [operating coordinate
space](#operating-coordinate-space).

Note: On high resolution devices, attribute and property values that are
relative to the
[primitiveUnits](#element-attrdef-filter-primitiveunits) usually need to be scaled up. User agents may
reduce the resolution of filter primitives on limited platform
resources.

Note: Some attribute or property values from the filter primitives
[feConvolveMatrix](#elementdef-feconvolvematrix) and [light
sources](#light-source) can not
be mapped from the coordinate space defined by the
[primitiveUnits](#element-attrdef-filter-primitiveunits) attribute to the [operating coordinate
space](#operating-coordinate-space).

### 9.2. Common filter primitive attributes

The following [filter primitive attributes] are available for all
filter primitives:

*Attribute definitions:*

[`x`] = \"[\<length-percentage\>](https://www.w3.org/TR/css-values-4/#typedef-length-percentage)\"

: The minimum x coordinate for the subregion which restricts
 calculation and rendering of the given [filter
 primitive](#filter-primitive). See [filter primitive
 subregion](#filter-primitive-subregion).

 The [initial
 value](https://svgwg.org/svg2-draft/types.html#TermInitialValue) for
 [x](#element-attrdef-filter-primitive-x) is [0%].

 Animatable: yes.

[`y`] = \"[\<length-percentage\>](https://www.w3.org/TR/css-values-4/#typedef-length-percentage)\"

: The minimum y coordinate for the subregion which restricts
 calculation and rendering of the given [filter
 primitive](#filter-primitive). See [filter primitive
 subregion](#filter-primitive-subregion).

 The [initial
 value](https://svgwg.org/svg2-draft/types.html#TermInitialValue) for
 [y](#element-attrdef-filter-primitive-y) is [0%].

 Animatable: yes.

[`width`] = \"[\<length-percentage\>](https://www.w3.org/TR/css-values-4/#typedef-length-percentage)\"

: The width of the subregion which restricts calculation and rendering
 of the given [filter
 primitive](#filter-primitive). See [filter primitive
 subregion](#filter-primitive-subregion).

 A negative or zero value disables the effect of the given filter
 primitive (i.e., the result is a transparent black image).

 The [initial
 value](https://svgwg.org/svg2-draft/types.html#TermInitialValue) for
 [width](#element-attrdef-filter-primitive-width) is [100%].

 Animatable: yes.

[`height`] = \"[\<length-percentage\>](https://www.w3.org/TR/css-values-4/#typedef-length-percentage)\"

: The height of the subregion which restricts calculation and
 rendering of the given [filter
 primitive](#filter-primitive). See [filter primitive
 subregion](#filter-primitive-subregion).

 A negative or zero value must disable the effect of the given filter
 primitive (i.e., the result is a transparent black image).

 The [initial
 value](https://svgwg.org/svg2-draft/types.html#TermInitialValue) for
 [height](#element-attrdef-filter-primitive-height) is [100%].

 Animatable: yes.

[`result`] = \"*[\<filter-primitive-reference\>]*\"

: [\<filter-primitive-reference\>](#typedef-result-filter-primitive-reference) is an
 [\<custom-ident\>](https://www.w3.org/TR/css-values-4/#identifier-value)
 [\[CSS3VAL\]](#biblio-css3val) and an assigned
 name for this [filter
 primitive](#filter-primitive). If supplied, then graphics that result from
 processing this [filter primitive] can
 be referenced by an
 [in](#element-attrdef-filter-primitive-in) attribute on a subsequent filter primitive
 within the same
 [filter](#elementdef-filter) element. If no value is provided, the output
 will only be available for re-use as the implicit input into the
 next [filter primitive] if that [filter
 primitive] provides no value for its
 [in] attribute.

Most filter primitives take other filter primitives as input. The
following attribute is representative for all input attributes to
reference other filter primitives:

*Attribute definitions:*

[`in`] = \"*[SourceGraphic](#attr-valuedef-in-sourcegraphic) \| [SourceAlpha](#attr-valuedef-in-sourcealpha) \| [BackgroundImage](#attr-valuedef-in-backgroundimage) \| [BackgroundAlpha](#attr-valuedef-in-backgroundalpha) \| [FillPaint](#attr-valuedef-in-fillpaint) \| [StrokePaint](#attr-valuedef-in-strokepaint) \| [\<filter-primitive-reference\>](#typedef-result-filter-primitive-reference)*\"

: Identifies input for the given filter primitive. The value can be
 either one of six keywords or can be a string which matches a
 previous
 [result](#element-attrdef-filter-primitive-result) attribute value within the same
 [filter](#elementdef-filter) element. If no value is provided and this is
 the first [filter
 primitive](#filter-primitive), then this [filter
 primitive] will use
 [SourceGraphic](#attr-valuedef-in-sourcegraphic) as its input. If no value is provided and
 this is a subsequent [filter
 primitive], then this [filter
 primitive] will use the result from the
 previous [filter primitive] as its
 input.

 If the value for
 [result](#element-attrdef-filter-primitive-result) appears multiple times within a given
 [filter](#elementdef-filter) element, then a reference to that result will
 use the closest preceding [filter
 primitive](#filter-primitive) with the given value for attribute
 [result].

 Forward references to results are not allowed, and will be treated
 as if no result was specified.

 References to non-existent results will be treated as if no result
 was specified.

 Definitions for the six keywords:

 [`SourceGraphic`]

 : This keyword represents the graphics elements that were the
 original input into the
 [filter](#elementdef-filter) element. For raster effects [filter
 primitives](#filter-primitive), the graphics elements will be rasterized into
 an initially clear RGBA raster in image space. Pixels left
 untouched by the original graphic will be left clear. The image
 is specified to be rendered in linear RGBA pixels. The alpha
 channel of this image captures any anti-aliasing specified by
 SVG. (Since the raster is linear, the alpha channel of this
 image will represent the exact percent coverage of each pixel.)

 [`SourceAlpha`]

 : This keyword represents the graphics elements that were the
 original input into the
 [filter](#elementdef-filter) element.
 [SourceAlpha](#attr-valuedef-in-sourcealpha) has all of the same rules as
 [SourceGraphic](#attr-valuedef-in-sourcegraphic) except that only the alpha channel is
 used. The input image is an RGBA image consisting of implicitly
 black color values for the RGB channels, but whose alpha channel
 is the same as
 [SourceGraphic].

 Note: If this option is used, then some implementations might
 need to rasterize the graphics elements in order to extract the
 alpha channel.

 [`BackgroundImage`]

 : This keyword represents the back drop defined by the current
 isolation group behind the [filter
 region](#filter-region)
 at the time that the
 [filter](#elementdef-filter) element was invoked. See
 [isolation](https://www.w3.org/TR/compositing-1/#propdef-isolation) property
 [\[COMPOSITING-1\]](#biblio-compositing-1).

 [`BackgroundAlpha`]

 : Same as
 [BackgroundImage](#attr-valuedef-in-backgroundimage) except only the alpha channel is used.
 See
 [SourceAlpha](#attr-valuedef-in-sourcealpha) and the
 [isolation](https://www.w3.org/TR/compositing-1/#propdef-isolation) property
 [\[COMPOSITING-1\]](#biblio-compositing-1).

 [`FillPaint`]

 : This keyword represents the value of the
 [fill](https://www.w3.org/TR/svg2/painting.html#FillProperty) property on the target element
 for the filter effect. The
 [FillPaint](#attr-valuedef-in-fillpaint) image has conceptually infinite extent.
 Frequently this image is opaque everywhere, but it might not be
 if the \"paint\" itself has alpha, as in the case of a gradient
 or pattern which itself includes transparent or semi-transparent
 parts. If [fill] references a
 paint server, then the coordinate space of the paint server is
 the coordinate space defined for the filtered object. E.g if the
 paint server requires to use the
 [objectBoundingBox](#attr-valuedef-primitiveunits-objectboundingbox) of the object, the object bounding box
 of the filtered object defines the reference size of the paint
 server. If the paint server requires to use the
 [userSpaceOnUse](#attr-valuedef-primitiveunits-userspaceonuse), the nearest viewport in the [local
 coordinate
 system](https://www.w3.org/TR/css-transforms-1/#local-coordinate-system) of the filtered object defines the reference
 size of the paint server.

 [`StrokePaint`]

 : This keyword represents the value of the
 [stroke](https://www.w3.org/TR/svg2/painting.html#StrokeProperty) property on the target element
 for the filter effect. The
 [StrokePaint](#attr-valuedef-in-strokepaint) image has conceptually infinite extent.
 See
 [FillPaint](#attr-valuedef-in-fillpaint) above for more details.

 Animatable: yes.

### 9.3. Filter primitive tree

Filter primitives with no or one filter primitive input can be linked
together to a filter chain. E.g. the filter primitive representation of
a
[\<filter-value-list\>](#typedef-filter-value-list) with two or more
[\<filter-function\>](#typedef-filter-function)s is an example of a filter chain.
Every filter primitive takes the result of the previous filter primitive
as input.

A simple example of a
[filter](#elementdef-filter) element with its filter primitive children.

``` highlight
<filter id="filter">
 <feColorMatrix type="hueRotate" values="45"/>
 <feOffset dx="10" dy="10"/>
 <feGaussianBlur stdDeviation="3"/>
</filter>
```

[feColorMatrix](#elementdef-fecolormatrix),
[feOffset](#elementdef-feoffset) and
[feGaussianBlur](#elementdef-fegaussianblur) create a filter chain.

[feColorMatrix](#elementdef-fecolormatrix) takes [SourceGraphic] as input. The result is
the input of
[feOffset](#elementdef-feoffset) with its result being the input of
[feGaussianBlur](#elementdef-fegaussianblur).

Some filter primitives may have more than one filter primitive inputs.
With the use of the
[in](#element-attrdef-filter-primitive-in) and
[result](#element-attrdef-filter-primitive-result) attributes it is possible to combine multiple
filter primitives to a complex filter structure. Due to the non-forward
reference restriction of filter primitives, every filter structure can
be represented as a tree, the [filter primitive
tree(#filter-primitive-tree)]. The root filter primitive of the filter
primitive tree is the most subsequential primitive of
[filter](#elementdef-filter) elements filter primitive children.

A filter chain is one possible filter structure that can also be
represented in a filter primitive tree. Therefore, filter chains are
referred to as filter primitive trees onwards as well.

A [filter](#elementdef-filter) element may have one or more filter primitive
trees. The filter primitive tree whose subsequent filter primitive is
the last filter primitive child of the
[filter] elements is the [primary filter
primitive
tree(#primary-filter-primitive-tree)].

Only the primary filter primitive tree contributes to the filter
process. Implementations may chose to ignore all other possible filter
primitive trees.

If a [filter](#elementdef-filter) element has no filter primitive tree then the
element the filter applies to does not get rendered.

An example of multiple filter
primitive trees:

``` highlight
<filter id="filter">
 <-- The first filter primitive tree. Ignored for filter process. -->
 <feColorMatrix type="hueRotate" values="45"/>
 <feOffset dx="10" dy="10"/>
 <feGaussianBlur stdDeviation="3"/>
 <-- The primary filter primitive tree. -->
 <feFlood flood-color="green" resu/>
 <feComposite operator="in" in="SourceAlpha" in2="flood"/>
</filter>
```

The above filter has 2 filter primitive trees with the filter
primitives:

1. [feColorMatrix](#elementdef-fecolormatrix),
 [feOffset](#elementdef-feoffset) and
 [feGaussianBlur](#elementdef-fegaussianblur) (with
 [feGaussianBlur] being the root
 filter primitive of the tree) as well as

2. [feFlood](#elementdef-feflood) and
 [feComposite](#elementdef-fecomposite) (with
 [feComposite] as the root filter
 primitive of the tree).

Both filter primitive trees are not connected. Only the 2nd, the primary
filter primitive tree contributes to the filter process. The first tree
can get ignored by implementations.

### 9.4. Filter primitive subregion

All [filter primitives](#filter-primitive) have attributes
[x](#element-attrdef-filter-primitive-x),
[y](#element-attrdef-filter-primitive-y),
[width](#element-attrdef-filter-primitive-width) and
[height](#element-attrdef-filter-primitive-height) which together identify a [filter primitive
subregion] which restricts calculation and rendering of the given
[filter primitive]. The
[x],
[y],
[width] and
[height] attributes
are defined according to the same rules as other [filter
primitives] coordinate and length
attributes and thus represent values in the coordinate system
established by attribute
[primitiveUnits](#element-attrdef-filter-primitiveunits) on the
[filter](#elementdef-filter) element.

[x](#element-attrdef-filter-primitive-x),
[y](#element-attrdef-filter-primitive-y),
[width](#element-attrdef-filter-primitive-width) and
[height](#element-attrdef-filter-primitive-height) default to the union (i.e., tightest fitting
bounding box) of the subregions defined for all referenced nodes. If
there are no referenced nodes (e.g., for
[feImage](#elementdef-feimage) or
[feTurbulence](#elementdef-feturbulence)), or one or more of the referenced nodes is a
standard input (one of
[SourceGraphic](#attr-valuedef-in-sourcegraphic),
[SourceAlpha](#attr-valuedef-in-sourcealpha),
[BackgroundImage](#attr-valuedef-in-backgroundimage),
[BackgroundAlpha](#attr-valuedef-in-backgroundalpha),
[FillPaint](#attr-valuedef-in-fillpaint) or
[StrokePaint](#attr-valuedef-in-strokepaint)), or for
[feTile](#elementdef-fetile) (which is special because its principal function is
to replicate the referenced node in X and Y and thereby produce a
usually larger result), the default subregion is [0%, 0%, 100%,
100%], where as a special-case the percentages are relative to the
dimensions of the [filter
region](#filter-region), thus
making the default [filter primitive
subregion](#filter-primitive-subregion) equal to the [filter region].

If the [filter primitive
subregion](#filter-primitive-subregion) has a negative or zero width or height, the effect of
the filter primitive is disabled.

The [filter region](#filter-region) acts as a hard clip clipping rectangle on the filter
primitive's input image(s).

The [filter primitive
subregion](#filter-primitive-subregion) acts as a hard clip clipping rectangle on the filter
primitive result.

All intermediate offscreens are defined to not exceed the intersection
of the [filter primitive
subregion](#filter-primitive-subregion) with the [filter
region](#filter-region). The
[filter region] and any of the filter
primitive subregions are to be set up such that all offscreens are made
big enough to accommodate any pixels which even partly intersect with
either the [filter region] or the filter
primitive subregions.

[feTile](#elementdef-fetile) references a previous filter primitive and then
stitches the tiles together based on the [filter primitive
subregion](#filter-primitive-subregion) of the referenced filter primitive in order to fill its
own [filter primitive subregion].

``` highlight
<svg width="400" height="400" xmlns="http://www.w3.org/2000/svg">
 <defs>
 <filter id="flood" x="0" y="0" width="100%" height="100%" primitiveUnits="objectBoundingBox">
 <feFlood x="25%" y="25%" width="50%" height="50%"
 flood-color="green" flood-opacity="0.75"/>
 </filter>
 <filter id="blend" primitiveUnits="objectBoundingBox">
 <feBlend x="25%" y="25%" width="50%" height="50%"
 in2="SourceGraphic" mode="multiply"/>
 </filter>
 <filter id="merge" primitiveUnits="objectBoundingBox">
 <feMerge x="25%" y="25%" width="50%" height="50%">
 <feMergeNode in="SourceGraphic"/>
 <feMergeNode in="FillPaint"/>
 </feMerge>
 </filter>
 </defs>

 <g fill="none" stroke="blue" stroke-width="4">
 <rect width="200" height="200"/>
 <line x2="200" y2="200"/>
 <line x1="200" y2="200"/>
 </g>
 <circle fill="green" filter="url(#flood)" cx="100" cy="100" r="90"/>

 <g transform="translate(200 0)">
 <g fill="none" stroke="blue" stroke-width="4">
 <rect width="200" height="200"/>
 <line x2="200" y2="200"/>
 <line x1="200" y2="200"/>
 </g>
 <circle fill="green" filter="url(#blend)" cx="100" cy="100" r="90"/>
 </g>

 <g transform="translate(0 200)">
 <g fill="none" stroke="blue" stroke-width="4">
 <rect width="200" height="200"/>
 <line x2="200" y2="200"/>
 <line x1="200" y2="200"/>
 </g>
 <circle fill="green" fill-opacity="0.5" filter="url(#merge)" cx="100" cy="100" r="90"/>
 </g>
</svg>
```

![Example for subregions](examples/filtersubregion00.png)

Example for subregions

[View this example as SVG](examples/filtersubregion00.svg)

In the example above there are three rectangles that each have a cross
and a circle in them. The circle element in each one has a different
filter applied, but with the same [filter primitive
subregion](#filter-primitive-subregion). The filter output should be limited to the [filter
primitive subregion] so you
should never see the circles themselves, just the rectangles that make
up the [filter primitive
subregion].

- The upper left rectangle shows an
 [feFlood](#elementdef-feflood) with [flood-opacity:
 75%](#propdef-flood-opacity) so the cross should be visible through the green
 rect in the middle.

- The lower left rectangle shows an
 [feMerge](#elementdef-femerge) that merges
 [SourceGraphic](#attr-valuedef-in-sourcegraphic) with
 [FillPaint](#attr-valuedef-in-fillpaint). Since the circle has `fill-opacity="0.5"` it
 will also be transparent so that the cross is visible through the
 green rect in the middle.

- The upper right rectangle shows an
 [feBlend](#elementdef-feblend) that has `mode="multiply"`. Since the circle in
 this case isn't transparent the result is totally opaque. The rect
 should be dark green and the cross should not be visible through it.

### 9.5. Filter primitive [feBlend]
Name:

[`feBlend`]

Categories:

[filter primitive](#filter-primitive)

Content model:

Any number of [descriptive
elements](https://www.w3.org/TR/svg2/struct.html#TermDescriptiveElement),
[animate](https://www.w3.org/TR/SVG11/animate.html#AnimateElement),
[script](https://www.w3.org/TR/svg2/interact.html#elementdef-script),
[set](https://www.w3.org/TR/SVG11/animate.html#SetElement) elements, in any order.

Attributes:

- [core
 attributes](https://www.w3.org/TR/2011/REC-SVG11-20110816/intro.html#TermCoreAttributes)[
 ---
 [[id]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#IDAttribute),
 [[xml:base]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#XMLBaseAttribute),
 [[xml:lang]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#XMLLangAttribute),
 [[xml:space]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#XMLSpaceAttribute)]
- [presentation
 attributes](https://www.w3.org/TR/2008/REC-SVGTiny12-20081222/intro.html#TermPresentationAttribute)[
 ---
 [alignment-baseline](https://www.w3.org/TR/SVG11/text.html#AlignmentBaselineProperty),
 [baseline-shift](https://www.w3.org/TR/SVG11/text.html#BaselineShiftProperty),
 [clip](https://www.w3.org/TR/css-masking-1/#propdef-clip),
 [clip-path](https://www.w3.org/TR/css-masking-1/#propdef-clip-path),
 [clip-rule](https://www.w3.org/TR/css-masking-1/#propdef-clip-rule),
 [color](https://www.w3.org/TR/css3-color/#color0),
 [color-interpolation](https://www.w3.org/TR/svg2/painting.html#ColorInterpolationProperty),
 [color-interpolation-filters](#propdef-color-interpolation-filters),
 [color-rendering](https://www.w3.org/TR/svg2/painting.html#ColorRenderingProperty),
 [cursor](https://www.w3.org/TR/css3-ui/#propdef-cursor),
 [direction](https://www.w3.org/TR/css-writing-modes-3/#propdef-direction),
 [display](https://www.w3.org/TR/css-display-3/#propdef-display),
 [dominant-baseline](https://www.w3.org/TR/SVG11/text.html#DominantBaselineProperty),
 [enable-background](https://www.w3.org/TR/SVG11/filters.html#EnableBackgroundProperty),
 [fill](https://www.w3.org/TR/svg2/painting.html#FillProperty),
 [fill-opacity](https://www.w3.org/TR/svg2/painting.html#FillOpacityProperty),
 [fill-rule](https://www.w3.org/TR/svg2/painting.html#FillRuleProperty),
 [filter](#propdef-filter),
 [flood-color](#propdef-flood-color),
 [flood-opacity](#propdef-flood-opacity),
 [font](https://www.w3.org/TR/css-fonts-3/#propdef-font),
 [font-family](https://www.w3.org/TR/css-fonts-3/#propdef-font-family),
 [font-size](https://www.w3.org/TR/css-fonts-3/#propdef-font-size),
 [font-size-adjust](https://www.w3.org/TR/css-fonts-4/#propdef-font-size-adjust),
 [font-stretch](https://www.w3.org/TR/css-fonts-3/#propdef-font-stretch),
 [font-style](https://www.w3.org/TR/css-fonts-3/#propdef-font-style),
 [font-variant](https://www.w3.org/TR/css-fonts-3/#propdef-font-variant),
 [font-weight](https://www.w3.org/TR/css-fonts-3/#propdef-font-weight),
 [glyph-orientation-horizontal](https://www.w3.org/TR/SVG11/text.html#GlyphOrientationHorizontalProperty),
 [glyph-orientation-vertical](https://www.w3.org/TR/SVG11/text.html#GlyphOrientationVerticalProperty),
 [image-rendering](https://drafts.csswg.org/css-images-3/#propdef-image-rendering),
 [isolation](https://www.w3.org/TR/compositing-1/#propdef-isolation),
 [kerning](https://www.w3.org/TR/SVG11/text.html#KerningProperty),
 [letter-spacing](https://www.w3.org/TR/css-text-3/#propdef-letter-spacing),
 [lighting-color](#propdef-lighting-color),
 [marker](https://www.w3.org/TR/svg2/painting.html#MarkerProperty),
 [marker-end](https://www.w3.org/TR/svg2/painting.html#MarkerEndProperty),
 [marker-mid](https://www.w3.org/TR/svg2/painting.html#MarkerMidProperty),
 [marker-start](https://www.w3.org/TR/svg2/painting.html#MarkerStartProperty),
 [mask](https://www.w3.org/TR/css-masking-1/#propdef-mask),
 [opacity](https://www.w3.org/TR/css-color-4/#propdef-opacity),
 [overflow](https://www.w3.org/TR/css-overflow-3/#propdef-overflow),
 [pointer-events](https://www.w3.org/TR/svg2/interact.html#PointerEventsProperty),
 [shape-rendering](https://www.w3.org/TR/svg2/painting.html#ShapeRenderingProperty),
 [stop-color](https://www.w3.org/TR/svg2/pservers.html#StopColorProperty),
 [stop-opacity](https://www.w3.org/TR/svg2/pservers.html#StopOpacityProperty),
 [stroke](https://www.w3.org/TR/svg2/painting.html#StrokeProperty),
 [stroke-dasharray](https://www.w3.org/TR/svg2/painting.html#StrokeDasharrayProperty),
 [stroke-dashoffset](https://www.w3.org/TR/svg2/painting.html#StrokeDashoffsetProperty),
 [stroke-linecap](https://www.w3.org/TR/svg2/painting.html#StrokeLinecapProperty),
 [stroke-linejoin](https://www.w3.org/TR/svg2/painting.html#StrokeLinejoinProperty),
 [stroke-miterlimit](https://www.w3.org/TR/svg2/painting.html#StrokeMiterlimitProperty),
 [stroke-opacity](https://www.w3.org/TR/svg2/painting.html#StrokeOpacityProperty),
 [stroke-width](https://www.w3.org/TR/svg2/painting.html#StrokeWidthProperty),
 [text-anchor](https://www.w3.org/TR/svg2/text.html#TextAnchorProperty),
 [text-decoration](https://www.w3.org/TR/css-text-decor-3/#propdef-text-decoration),
 [text-rendering](https://www.w3.org/TR/svg2/painting.html#TextRenderingProperty),
 [unicode-bidi](https://www.w3.org/TR/css-writing-modes-3/#propdef-unicode-bidi),
 [visibility](https://www.w3.org/TR/CSS21/visufx.html#propdef-visibility),
 [word-spacing](https://www.w3.org/TR/css-text-3/#propdef-word-spacing),
 [writing-mode](https://www.w3.org/TR/css-writing-modes-4/#propdef-writing-mode)]
- [filter primitive
 attributes](#filter-primitive-attributes)
 [
 ---[x](#element-attrdef-filter-primitive-x),
 [y](#element-attrdef-filter-primitive-y),
 [width](#element-attrdef-filter-primitive-width),
 [height](#element-attrdef-filter-primitive-height),
 [result](#element-attrdef-filter-primitive-result) ]
- [[class]](https://www.w3.org/TR/2011/REC-SVG11-20110816/styling.html#ClassAttribute)
- [[style]](https://www.w3.org/TR/2011/REC-SVG11-20110816/styling.html#StyleAttribute)
- [in](#element-attrdef-filter-primitive-in)
- [in2](#element-attrdef-feblend-in2)
- [mode](#element-attrdef-feblend-mode)

DOM Interfaces:

[SVGFEBlendElement](#InterfaceSVGFEBlendElement)

This filter blends two objects together using commonly used imaging
software blending modes. It performs a pixel-wise combination of two
input images. (See
[\[COMPOSITING-1\]](#biblio-compositing-1).)

*Attribute definitions:*

[`mode`] = \"[\<blend-mode\>](https://www.w3.org/TR/compositing-1/#ltblendmodegt "Expands to: hue | saturation | darken | exclusion | hard-light | normal | color | luminosity | lighten | overlay | multiply | color-burn | color-dodge | difference | screen | soft-light")\"

: One of the blend modes defined by "Compositing and Blending Level 1"
 [\[COMPOSITING-1\]](#biblio-compositing-1) with
 the input
 [in](#element-attrdef-filter-primitive-in) representing the source `Cs` and the
 second input
 [in2](#element-attrdef-feblend-in2) representing the
 [backdrop](https://www.w3.org/TR/compositing-1/#backdrop) `Cb`. The output of this filter primitive `Cm` is
 the result of blending `Cs` with `Cb`.

 The [initial
 value](https://svgwg.org/svg2-draft/types.html#TermInitialValue) for
 [mode](#element-attrdef-feblend-mode) is
 [normal](https://www.w3.org/TR/compositing-1/#valdef-blend-mode-normal).

 Animatable: yes.

[`no-composite`] = \"[`no-composite`(#attr-valuedef-no-composite-no-composite)]\"

: If the
 [no-composite](#element-attrdef-feblend-no-composite) attribute is present, the specified blend
 mode must not apply alpha compositing. See
 [Blending](https://www.w3.org/TR/compositing-1/#blending)
 [\[COMPOSITING-1\]](#biblio-compositing-1) for
 the \"mixing\" formula without compositing. Otherwise,
 implementations must combine the blend mode specified by
 [mode](#element-attrdef-feblend-mode) with the [Source
 Over](https://www.w3.org/TR/compositing-1/#porterduffcompositingoperators_srcover)
 composite operator. See
 [Blending](https://www.w3.org/TR/compositing-1/#blending)
 \[COMPOSITING-1\] for the \"mixing\" formula with compositing.

 Note: This attribute is an addition to the
 [feBlend](#elementdef-feblend) element defintion in SVG 1.1.
 [no-composite](#element-attrdef-feblend-no-composite), when specified, is meant to avoid
 \"double-compositing\" effects when blending an input source with
 the backdrop of the filtered object (E.g. using the
 [BackgroundImage](#attr-valuedef-in-backgroundimage) filter primitive). For the majority of use
 cases authors will not need to specify the
 [no-composite]
 attribute.

 Animatable: no.

[`in2`] = \"*(see [in](#element-attrdef-filter-primitive-in) attribute)*\"

: The second input image to the blending operation.

 Animatable: yes.

The
[normal](https://www.w3.org/TR/compositing-1/#valdef-blend-mode-normal) blend mode with alpha compositing is equivalent
to `operator="over"` on the
[feComposite](#elementdef-fecomposite) filter primitive, matches the blending method used
by [feMerge](#elementdef-femerge) and matches the [simple alpha
compositing](https://www.w3.org/TR/SVG11/masking.html#SimpleAlphaBlending) technique used in SVG for all compositing outside of
filter effects.

``` highlight
<svg width="5cm" height="5cm" viewBox="0 0 500 500"
 xmlns="http://www.w3.org/2000/svg">
 <title>Example feBlend - Examples of feBlend modes</title>
 <desc>Five text strings blended into a gradient,
 with one text string for each of the five feBlend modes.</desc>
 <defs>
 <linearGradient id="MyGradient" gradientUnits="userSpaceOnUse"
 x1="100" y1="0" x2="300" y2="0">
 <stop offset="0" stop-color="#000000" />
 <stop offset=".33" stop-color="#ffffff" />
 <stop offset=".67" stop-color="#ff0000" />
 <stop offset="1" stop-color="#808080" />
 </linearGradient>
 <filter id="Normal">
 <feBlend mode="normal" in2="BackgroundImage" in="SourceGraphic"/>
 </filter>
 <filter id="Multiply">
 <feBlend mode="multiply" in2="BackgroundImage" in="SourceGraphic"/>
 </filter>
 <filter id="Screen">
 <feBlend mode="screen" in2="BackgroundImage" in="SourceGraphic"/>
 </filter>
 <filter id="Darken">
 <feBlend mode="darken" in2="BackgroundImage" in="SourceGraphic"/>
 </filter>
 <filter id="Lighten">
 <feBlend mode="lighten" in2="BackgroundImage" in="SourceGraphic"/>
 </filter>
 </defs>
 <rect fill="none" stroke="blue"
 x="1" y="1" width="498" height="498"/>
 <g isolation="isolate" >
 <rect x="100" y="20" width="300" height="460" fill="url(#MyGradient)" />
 <g font-family="Verdana" font-size="75" fill="#888888" fill-opacity=".6" >
 <text x="50" y="90" filter="url(#Normal)" >Normal</text>
 <text x="50" y="180" filter="url(#Multiply)" >Multiply</text>
 <text x="50" y="270" filter="url(#Screen)" >Screen</text>
 <text x="50" y="360" filter="url(#Darken)" >Darken</text>
 <text x="50" y="450" filter="url(#Lighten)" >Lighten</text>
 </g>
 </g>
</svg>
```

![Example of feBlend](examples/feBlend.png)

Example of feBlend

[View this example as SVG](examples/feBlend.svg)

### 9.6. Filter primitive [feColorMatrix]
Name:

[`feColorMatrix`]

Categories:

[filter primitive](#filter-primitive)

Content model:

Any number of [descriptive
elements](https://www.w3.org/TR/svg2/struct.html#TermDescriptiveElement),
[animate](https://www.w3.org/TR/SVG11/animate.html#AnimateElement),
[script](https://www.w3.org/TR/svg2/interact.html#elementdef-script),
[set](https://www.w3.org/TR/SVG11/animate.html#SetElement) elements, in any order.

Attributes:

- [core
 attributes](https://www.w3.org/TR/2011/REC-SVG11-20110816/intro.html#TermCoreAttributes)[
 ---
 [[id]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#IDAttribute),
 [[xml:base]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#XMLBaseAttribute),
 [[xml:lang]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#XMLLangAttribute),
 [[xml:space]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#XMLSpaceAttribute)]
- [presentation
 attributes](https://www.w3.org/TR/2008/REC-SVGTiny12-20081222/intro.html#TermPresentationAttribute)[
 ---
 [alignment-baseline](https://www.w3.org/TR/SVG11/text.html#AlignmentBaselineProperty),
 [baseline-shift](https://www.w3.org/TR/SVG11/text.html#BaselineShiftProperty),
 [clip](https://www.w3.org/TR/css-masking-1/#propdef-clip),
 [clip-path](https://www.w3.org/TR/css-masking-1/#propdef-clip-path),
 [clip-rule](https://www.w3.org/TR/css-masking-1/#propdef-clip-rule),
 [color](https://www.w3.org/TR/css3-color/#color0),
 [color-interpolation](https://www.w3.org/TR/svg2/painting.html#ColorInterpolationProperty),
 [color-interpolation-filters](#propdef-color-interpolation-filters),
 [color-rendering](https://www.w3.org/TR/svg2/painting.html#ColorRenderingProperty),
 [cursor](https://www.w3.org/TR/css3-ui/#propdef-cursor),
 [direction](https://www.w3.org/TR/css-writing-modes-3/#propdef-direction),
 [display](https://www.w3.org/TR/css-display-3/#propdef-display),
 [dominant-baseline](https://www.w3.org/TR/SVG11/text.html#DominantBaselineProperty),
 [enable-background](https://www.w3.org/TR/SVG11/filters.html#EnableBackgroundProperty),
 [fill](https://www.w3.org/TR/svg2/painting.html#FillProperty),
 [fill-opacity](https://www.w3.org/TR/svg2/painting.html#FillOpacityProperty),
 [fill-rule](https://www.w3.org/TR/svg2/painting.html#FillRuleProperty),
 [filter](#propdef-filter),
 [flood-color](#propdef-flood-color),
 [flood-opacity](#propdef-flood-opacity),
 [font](https://www.w3.org/TR/css-fonts-3/#propdef-font),
 [font-family](https://www.w3.org/TR/css-fonts-3/#propdef-font-family),
 [font-size](https://www.w3.org/TR/css-fonts-3/#propdef-font-size),
 [font-size-adjust](https://www.w3.org/TR/css-fonts-4/#propdef-font-size-adjust),
 [font-stretch](https://www.w3.org/TR/css-fonts-3/#propdef-font-stretch),
 [font-style](https://www.w3.org/TR/css-fonts-3/#propdef-font-style),
 [font-variant](https://www.w3.org/TR/css-fonts-3/#propdef-font-variant),
 [font-weight](https://www.w3.org/TR/css-fonts-3/#propdef-font-weight),
 [glyph-orientation-horizontal](https://www.w3.org/TR/SVG11/text.html#GlyphOrientationHorizontalProperty),
 [glyph-orientation-vertical](https://www.w3.org/TR/SVG11/text.html#GlyphOrientationVerticalProperty),
 [image-rendering](https://drafts.csswg.org/css-images-3/#propdef-image-rendering),
 [isolation](https://www.w3.org/TR/compositing-1/#propdef-isolation),
 [kerning](https://www.w3.org/TR/SVG11/text.html#KerningProperty),
 [letter-spacing](https://www.w3.org/TR/css-text-3/#propdef-letter-spacing),
 [lighting-color](#propdef-lighting-color),
 [marker](https://www.w3.org/TR/svg2/painting.html#MarkerProperty),
 [marker-end](https://www.w3.org/TR/svg2/painting.html#MarkerEndProperty),
 [marker-mid](https://www.w3.org/TR/svg2/painting.html#MarkerMidProperty),
 [marker-start](https://www.w3.org/TR/svg2/painting.html#MarkerStartProperty),
 [mask](https://www.w3.org/TR/css-masking-1/#propdef-mask),
 [opacity](https://www.w3.org/TR/css-color-4/#propdef-opacity),
 [overflow](https://www.w3.org/TR/css-overflow-3/#propdef-overflow),
 [pointer-events](https://www.w3.org/TR/svg2/interact.html#PointerEventsProperty),
 [shape-rendering](https://www.w3.org/TR/svg2/painting.html#ShapeRenderingProperty),
 [stop-color](https://www.w3.org/TR/svg2/pservers.html#StopColorProperty),
 [stop-opacity](https://www.w3.org/TR/svg2/pservers.html#StopOpacityProperty),
 [stroke](https://www.w3.org/TR/svg2/painting.html#StrokeProperty),
 [stroke-dasharray](https://www.w3.org/TR/svg2/painting.html#StrokeDasharrayProperty),
 [stroke-dashoffset](https://www.w3.org/TR/svg2/painting.html#StrokeDashoffsetProperty),
 [stroke-linecap](https://www.w3.org/TR/svg2/painting.html#StrokeLinecapProperty),
 [stroke-linejoin](https://www.w3.org/TR/svg2/painting.html#StrokeLinejoinProperty),
 [stroke-miterlimit](https://www.w3.org/TR/svg2/painting.html#StrokeMiterlimitProperty),
 [stroke-opacity](https://www.w3.org/TR/svg2/painting.html#StrokeOpacityProperty),
 [stroke-width](https://www.w3.org/TR/svg2/painting.html#StrokeWidthProperty),
 [text-anchor](https://www.w3.org/TR/svg2/text.html#TextAnchorProperty),
 [text-decoration](https://www.w3.org/TR/css-text-decor-3/#propdef-text-decoration),
 [text-rendering](https://www.w3.org/TR/svg2/painting.html#TextRenderingProperty),
 [unicode-bidi](https://www.w3.org/TR/css-writing-modes-3/#propdef-unicode-bidi),
 [visibility](https://www.w3.org/TR/CSS21/visufx.html#propdef-visibility),
 [word-spacing](https://www.w3.org/TR/css-text-3/#propdef-word-spacing),
 [writing-mode](https://www.w3.org/TR/css-writing-modes-4/#propdef-writing-mode)]
- [filter primitive
 attributes](#filter-primitive-attributes)
 [
 ---[x](#element-attrdef-filter-primitive-x),
 [y](#element-attrdef-filter-primitive-y),
 [width](#element-attrdef-filter-primitive-width),
 [height](#element-attrdef-filter-primitive-height),
 [result](#element-attrdef-filter-primitive-result) ]
- [[class]](https://www.w3.org/TR/2011/REC-SVG11-20110816/styling.html#ClassAttribute)
- [[style]](https://www.w3.org/TR/2011/REC-SVG11-20110816/styling.html#StyleAttribute)
- [in](#element-attrdef-filter-primitive-in)
- [type](#element-attrdef-fecolormatrix-type)
- [values](#element-attrdef-fecolormatrix-values)

DOM Interfaces:

[SVGFEColorMatrixElement](#InterfaceSVGFEColorMatrixElement)

This filter applies a matrix transformation:

$\begin{bmatrix}
{R'} \\
{G'} \\
{B'} \\
{A'} \\
1
\end{bmatrix} = {\begin{bmatrix}
a_{00} & a_{01} & a_{02} & a_{03} & a_{04} \\
a_{10} & a_{11} & a_{12} & a_{13} & a_{14} \\
a_{20} & a_{21} & a_{22} & a_{23} & a_{24} \\
a_{30} & a_{31} & a_{32} & a_{33} & a_{34} \\
0 & 0 & 0 & 0 & 1
\end{bmatrix} \cdot \begin{bmatrix}
R \\
G \\
B \\
A \\
1
\end{bmatrix}}$

on the RGBA color and alpha values of every pixel on the input graphics
to produce a result with a new set of RGBA color and alpha values.

The calculations are performed on non-premultiplied color values.

*Attribute definitions:*

[`type`] = \"[`matrix`] \| [`saturate`] \| [`hueRotate`] \| [`luminanceToAlpha`]\"

: Indicates the type of matrix operation. The keyword
 [matrix](#attr-valuedef-type-matrix) indicates that a full 5x4 matrix of values
 will be provided. The other keywords represent convenience shortcuts
 to allow commonly used color operations to be performed without
 specifying a complete matrix.

 The [initial
 value](https://svgwg.org/svg2-draft/types.html#TermInitialValue) for
 [type](#element-attrdef-fecolormatrix-type) is
 [matrix](#attr-valuedef-type-matrix).

 Animatable: yes.

[`values`] = \"*list of [\<number\>](https://www.w3.org/TR/css3-values/#number-value)s*\"

: The contents of
 [values](#element-attrdef-fecolormatrix-values) depends on the value of attribute
 [type](#element-attrdef-fecolormatrix-type):

 - For `type="matrix"`,
 [values](#element-attrdef-fecolormatrix-values) is a list of 20 matrix values (a00 a01
 a02 a03 a04 a10 a11 \... a34), separated by whitespace and/or a
 comma. For example, the identity matrix could be expressed as:

 type="matrix"
 values="1 0 0 0 0 0 1 0 0 0 0 0 1 0 0 0 0 0 1 0"

 - For `type="saturate"`,
 [values](#element-attrdef-fecolormatrix-values) is a single real number value. A
 [saturate](#attr-valuedef-type-saturate) operation is equivalent to the following
 matrix operation:

 $\begin{bmatrix}
 {R'} \\
 {G'} \\
 {B'} \\
 {A'} \\
 1
 \end{bmatrix} = {\begin{bmatrix}
 {0.213 + 0.787s} & {0.715 - 0.715s} & {0.072 - 0.072s} & 0 & 0 \\
 {0.213 - 0.213s} & {0.715 + 0.285s} & {0.072 - 0.072s} & 0 & 0 \\
 {0.213 - 0.213s} & {0.715 - 0.715s} & {0.072 + 0.928s} & 0 & 0 \\
 0 & 0 & 0 & 1 & 0 \\
 0 & 0 & 0 & 0 & 1
 \end{bmatrix} \cdot \begin{bmatrix}
 R \\
 G \\
 B \\
 A \\
 1
 \end{bmatrix}}$

 Note: A value of [0] produces a fully desaturated
 (grayscale) filter result, while a value of [1] passes the
 filter input image through unchanged. Values outside the 0..1
 range under- or oversaturates the filter input image respectively.

 Note: The precision of the luminance coefficients increased in
 comparison to previous specification texts
 [\[Cmam\]](#biblio-cmam).

 - For `type="hueRotate"`,
 [values](#element-attrdef-fecolormatrix-values) is a single one real number value
 (degrees). A
 [hueRotate](#attr-valuedef-type-huerotate) operation is equivalent to the following
 matrix operation:

 $\begin{bmatrix}
 {R'} \\
 {G'} \\
 {B'} \\
 {A'} \\
 1
 \end{bmatrix} = {\begin{bmatrix}
 a_{00} & a_{01} & a_{02} & 0 & 0 \\
 a_{10} & a_{11} & a_{12} & 0 & 0 \\
 a_{20} & a_{21} & a_{22} & 0 & 0 \\
 0 & 0 & 0 & 1 & 0 \\
 0 & 0 & 0 & 0 & 1
 \end{bmatrix} \cdot \begin{bmatrix}
 R \\
 G \\
 B \\
 A \\
 1
 \end{bmatrix}}$

 where the terms a00, a01, etc. are calculated as follows:

 ${\begin{bmatrix}
 a_{00} & a_{01} & a_{02} \\
 a_{10} & a_{11} & a_{12} \\
 a_{20} & a_{21} & a_{22}
 \end{bmatrix} = {\begin{bmatrix}
 {+ 0.213} & {+ 0.715} & {+ 0.072} \\
 {+ 0.213} & {+ 0.715} & {+ 0.072} \\
 {+ 0.213} & {+ 0.715} & {+ 0.072}
 \end{bmatrix} + \cos}}{{{({\mathit{hueRotate}\mathit{value}})} \cdot \begin{bmatrix}
 {+ 0.787} & {- 0.715} & {- 0.072} \\
 {- 0.213} & {+ 0.285} & {- 0.072} \\
 {- 0.213} & {- 0.715} & {+ 0.928}
 \end{bmatrix}} + \sin}{{({\mathit{hueRotate}\mathit{value}})} \cdot \begin{bmatrix}
 {- 0.213} & {- 0.715} & {+ 0.928} \\
 {+ 0.143} & {+ 0.140} & {- 0.283} \\
 {- 0.787} & {+ 0.715} & {+ 0.072}
 \end{bmatrix}}$

 Thus, the upper left term of the hue matrix turns out to be:

 ${a_{00} = {0.2127 + \cos}}{{{({\mathit{hueRotate}\mathit{value}})} \cdot 0.7873} - \sin}{{({\mathit{hueRotate}\mathit{value}})} \cdot 0.2127}$

 - For `type="luminanceToAlpha"`,
 [values](#element-attrdef-fecolormatrix-values) is not applicable. A
 [luminanceToAlpha](#attr-valuedef-type-luminancetoalpha) operation is equivalent to the following
 matrix operation:

 $\begin{bmatrix}
 {R'} \\
 {G'} \\
 {B'} \\
 {A'} \\
 1
 \end{bmatrix} = {\begin{bmatrix}
 0 & 0 & 0 & 0 & 0 \\
 0 & 0 & 0 & 0 & 0 \\
 0 & 0 & 0 & 0 & 0 \\
 0.2126 & 0.7152 & 0.0722 & 0 & 0 \\
 0 & 0 & 0 & 0 & 1
 \end{bmatrix} \cdot \begin{bmatrix}
 R \\
 G \\
 B \\
 A \\
 1
 \end{bmatrix}}$

 The [initial
 value](https://svgwg.org/svg2-draft/types.html#TermInitialValue) for
 [values](#element-attrdef-fecolormatrix-values)

 if `type="matrix"`

 : defaults to the identity matrix

 if `type="saturate"`

 : defaults to the value [1]

 if `type="hueRotate"`

 : defaults to the value [0] which results in the identity
 matrix.

 If the number of entries in the
 [values](#element-attrdef-fecolormatrix-values) list does not match the required number of
 entries by the
 [type](#element-attrdef-fecolormatrix-type), the filter primitive acts as a [pass
 through filter](#pass-through-filter).

 Animatable: yes.

``` highlight
<svg width="8cm" height="5cm" viewBox="0 0 800 500"
 xmlns="http://www.w3.org/2000/svg">
 <title>Example feColorMatrix - Examples of feColorMatrix operations</title>
 <desc>Five text strings showing the effects of feColorMatrix:
 an unfiltered text string acting as a reference,
 use of the feColorMatrix matrix option to convert to grayscale,
 use of the feColorMatrix saturate option,
 use of the feColorMatrix hueRotate option,
 and use of the feColorMatrix luminanceToAlpha option.</desc>
 <defs>
 <linearGradient id="MyGradient" gradientUnits="userSpaceOnUse"
 x1="100" y1="0" x2="500" y2="0">
 <stop offset="0" stop-color="#ff00ff" />
 <stop offset=".33" stop-color="#88ff88" />
 <stop offset=".67" stop-color="#2020ff" />
 <stop offset="1" stop-color="#d00000" />
 </linearGradient>
 <filter id="Matrix" filterUnits="objectBoundingBox"
 x="0%" y="0%" width="100%" height="100%">
 <feColorMatrix type="matrix" in="SourceGraphic"
 values=".33 .33 .33 0 0
 .33 .33 .33 0 0
 .33 .33 .33 0 0
 .33 .33 .33 0 0"/>
 </filter>
 <filter id="Saturate40" filterUnits="objectBoundingBox"
 x="0%" y="0%" width="100%" height="100%">
 <feColorMatrix type="saturate" in="SourceGraphic" values="0.4"/>
 </filter>
 <filter id="HueRotate90" filterUnits="objectBoundingBox"
 x="0%" y="0%" width="100%" height="100%">
 <feColorMatrix type="hueRotate" in="SourceGraphic" values="90"/>
 </filter>
 <filter id="LuminanceToAlpha" filterUnits="objectBoundingBox"
 x="0%" y="0%" width="100%" height="100%">
 <feColorMatrix type="luminanceToAlpha" in="SourceGraphic" resu/>
 <feComposite in="SourceGraphic" in2="a" operator="in" />
 </filter>
 </defs>
 <rect fill="none" stroke="blue"
 x="1" y="1" width="798" height="498"/>
 <g font-family="Verdana" font-size="75"
 font-weight="bold" fill="url(#MyGradient)" >
 <rect x="100" y="0" width="500" height="20" />
 <text x="100" y="90">Unfiltered</text>
 <text x="100" y="190" filter="url(#Matrix)" >Matrix</text>
 <text x="100" y="290" filter="url(#Saturate40)" >Saturate</text>
 <text x="100" y="390" filter="url(#HueRotate90)" >HueRotate</text>
 <text x="100" y="490" filter="url(#LuminanceToAlpha)" >Luminance</text>
 </g>
</svg>
```

![Example ](examples/feColorMatrix.png)

Example of feColorMatrix

[View this example as SVG](examples/feColorMatrix.svg)

### 9.7. Filter primitive [feComponentTransfer]
Name:

[`feComponentTransfer`]

Categories:

[filter primitive](#filter-primitive)

Content model:

Any number of [descriptive
elements](https://www.w3.org/TR/svg2/struct.html#TermDescriptiveElement),
[feFuncR](#elementdef-fefuncr),
[feFuncG](#elementdef-fefuncg),
[feFuncB](#elementdef-fefuncb),
[feFuncA](#elementdef-fefunca),
[script](https://www.w3.org/TR/svg2/interact.html#elementdef-script) elements, in any order.

Attributes:

- [core
 attributes](https://www.w3.org/TR/2011/REC-SVG11-20110816/intro.html#TermCoreAttributes)[
 ---
 [[id]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#IDAttribute),
 [[xml:base]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#XMLBaseAttribute),
 [[xml:lang]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#XMLLangAttribute),
 [[xml:space]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#XMLSpaceAttribute)]
- [presentation
 attributes](https://www.w3.org/TR/2008/REC-SVGTiny12-20081222/intro.html#TermPresentationAttribute)[
 ---
 [alignment-baseline](https://www.w3.org/TR/SVG11/text.html#AlignmentBaselineProperty),
 [baseline-shift](https://www.w3.org/TR/SVG11/text.html#BaselineShiftProperty),
 [clip](https://www.w3.org/TR/css-masking-1/#propdef-clip),
 [clip-path](https://www.w3.org/TR/css-masking-1/#propdef-clip-path),
 [clip-rule](https://www.w3.org/TR/css-masking-1/#propdef-clip-rule),
 [color](https://www.w3.org/TR/css3-color/#color0),
 [color-interpolation](https://www.w3.org/TR/svg2/painting.html#ColorInterpolationProperty),
 [color-interpolation-filters](#propdef-color-interpolation-filters),
 [color-rendering](https://www.w3.org/TR/svg2/painting.html#ColorRenderingProperty),
 [cursor](https://www.w3.org/TR/css3-ui/#propdef-cursor),
 [direction](https://www.w3.org/TR/css-writing-modes-3/#propdef-direction),
 [display](https://www.w3.org/TR/css-display-3/#propdef-display),
 [dominant-baseline](https://www.w3.org/TR/SVG11/text.html#DominantBaselineProperty),
 [enable-background](https://www.w3.org/TR/SVG11/filters.html#EnableBackgroundProperty),
 [fill](https://www.w3.org/TR/svg2/painting.html#FillProperty),
 [fill-opacity](https://www.w3.org/TR/svg2/painting.html#FillOpacityProperty),
 [fill-rule](https://www.w3.org/TR/svg2/painting.html#FillRuleProperty),
 [filter](#propdef-filter),
 [flood-color](#propdef-flood-color),
 [flood-opacity](#propdef-flood-opacity),
 [font](https://www.w3.org/TR/css-fonts-3/#propdef-font),
 [font-family](https://www.w3.org/TR/css-fonts-3/#propdef-font-family),
 [font-size](https://www.w3.org/TR/css-fonts-3/#propdef-font-size),
 [font-size-adjust](https://www.w3.org/TR/css-fonts-4/#propdef-font-size-adjust),
 [font-stretch](https://www.w3.org/TR/css-fonts-3/#propdef-font-stretch),
 [font-style](https://www.w3.org/TR/css-fonts-3/#propdef-font-style),
 [font-variant](https://www.w3.org/TR/css-fonts-3/#propdef-font-variant),
 [font-weight](https://www.w3.org/TR/css-fonts-3/#propdef-font-weight),
 [glyph-orientation-horizontal](https://www.w3.org/TR/SVG11/text.html#GlyphOrientationHorizontalProperty),
 [glyph-orientation-vertical](https://www.w3.org/TR/SVG11/text.html#GlyphOrientationVerticalProperty),
 [image-rendering](https://drafts.csswg.org/css-images-3/#propdef-image-rendering),
 [isolation](https://www.w3.org/TR/compositing-1/#propdef-isolation),
 [kerning](https://www.w3.org/TR/SVG11/text.html#KerningProperty),
 [letter-spacing](https://www.w3.org/TR/css-text-3/#propdef-letter-spacing),
 [lighting-color](#propdef-lighting-color),
 [marker](https://www.w3.org/TR/svg2/painting.html#MarkerProperty),
 [marker-end](https://www.w3.org/TR/svg2/painting.html#MarkerEndProperty),
 [marker-mid](https://www.w3.org/TR/svg2/painting.html#MarkerMidProperty),
 [marker-start](https://www.w3.org/TR/svg2/painting.html#MarkerStartProperty),
 [mask](https://www.w3.org/TR/css-masking-1/#propdef-mask),
 [opacity](https://www.w3.org/TR/css-color-4/#propdef-opacity),
 [overflow](https://www.w3.org/TR/css-overflow-3/#propdef-overflow),
 [pointer-events](https://www.w3.org/TR/svg2/interact.html#PointerEventsProperty),
 [shape-rendering](https://www.w3.org/TR/svg2/painting.html#ShapeRenderingProperty),
 [stop-color](https://www.w3.org/TR/svg2/pservers.html#StopColorProperty),
 [stop-opacity](https://www.w3.org/TR/svg2/pservers.html#StopOpacityProperty),
 [stroke](https://www.w3.org/TR/svg2/painting.html#StrokeProperty),
 [stroke-dasharray](https://www.w3.org/TR/svg2/painting.html#StrokeDasharrayProperty),
 [stroke-dashoffset](https://www.w3.org/TR/svg2/painting.html#StrokeDashoffsetProperty),
 [stroke-linecap](https://www.w3.org/TR/svg2/painting.html#StrokeLinecapProperty),
 [stroke-linejoin](https://www.w3.org/TR/svg2/painting.html#StrokeLinejoinProperty),
 [stroke-miterlimit](https://www.w3.org/TR/svg2/painting.html#StrokeMiterlimitProperty),
 [stroke-opacity](https://www.w3.org/TR/svg2/painting.html#StrokeOpacityProperty),
 [stroke-width](https://www.w3.org/TR/svg2/painting.html#StrokeWidthProperty),
 [text-anchor](https://www.w3.org/TR/svg2/text.html#TextAnchorProperty),
 [text-decoration](https://www.w3.org/TR/css-text-decor-3/#propdef-text-decoration),
 [text-rendering](https://www.w3.org/TR/svg2/painting.html#TextRenderingProperty),
 [unicode-bidi](https://www.w3.org/TR/css-writing-modes-3/#propdef-unicode-bidi),
 [visibility](https://www.w3.org/TR/CSS21/visufx.html#propdef-visibility),
 [word-spacing](https://www.w3.org/TR/css-text-3/#propdef-word-spacing),
 [writing-mode](https://www.w3.org/TR/css-writing-modes-4/#propdef-writing-mode)]
- [filter primitive
 attributes](#filter-primitive-attributes)
 [
 ---[x](#element-attrdef-filter-primitive-x),
 [y](#element-attrdef-filter-primitive-y),
 [width](#element-attrdef-filter-primitive-width),
 [height](#element-attrdef-filter-primitive-height),
 [result](#element-attrdef-filter-primitive-result) ]
- [[class]](https://www.w3.org/TR/2011/REC-SVG11-20110816/styling.html#ClassAttribute)
- [[style]](https://www.w3.org/TR/2011/REC-SVG11-20110816/styling.html#StyleAttribute)
- [in](#element-attrdef-filter-primitive-in)

DOM Interfaces:

[SVGFEComponentTransferElement](#InterfaceSVGFEComponentTransferElement)

This filter primitive performs component-wise remapping of data as
follows:

 R' = feFuncR( R )G' = feFuncG( G )
 B' = feFuncB( B )
 A' = feFuncA( A )

for every pixel. It allows operations like brightness adjustment,
contrast adjustment, color balance or thresholding.

The calculations are performed on non-premultiplied color values.

The child elements of a
[feComponentTransfer](#elementdef-fecomponenttransfer) element specify the transfer functions for the four
channels:

- [feFuncR](#elementdef-fefuncr) - transfer function for the red component of the
 input graphic

- [feFuncG](#elementdef-fefuncg) - transfer function for the green component of
 the input graphic

- [feFuncB](#elementdef-fefuncb) - transfer function for the blue component of the
 input graphic

- [feFuncA](#elementdef-fefunca) - transfer function for the alpha component of
 the input graphic

The set of [feFuncR](#elementdef-fefuncr),
[feFuncG](#elementdef-fefuncg),
[feFuncB](#elementdef-fefuncb),
[feFuncA](#elementdef-fefunca) elements are also called [transfer function
element]s.

The following rules apply to the processing of the
[feComponentTransfer](#elementdef-fecomponenttransfer) element:

- If more than one [transfer function
 element](#transfer-function-element) of the same kind is specified, the last occurrence is
 to be used.

- If any of the [transfer function
 elements](#transfer-function-element) are unspecified, the
 [feComponentTransfer](#elementdef-fecomponenttransfer) must be processed as if those [transfer function
 elements] were specified with
 their
 [type](#element-attrdef-fecomponenttransfer-type) attributes set to [identity].

#### 9.7.1. Transfer function [feFuncR]
Name:

[`feFuncR`]

Categories:

[transfer function
element](#transfer-function-element)

Content model:

Any number of [descriptive
elements](https://www.w3.org/TR/svg2/struct.html#TermDescriptiveElement),
[animate](https://www.w3.org/TR/SVG11/animate.html#AnimateElement),
[script](https://www.w3.org/TR/svg2/interact.html#elementdef-script),
[set](https://www.w3.org/TR/SVG11/animate.html#SetElement) elements, in any order.

Attributes:

- [core
 attributes](https://www.w3.org/TR/2011/REC-SVG11-20110816/intro.html#TermCoreAttributes)[
 ---
 [[id]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#IDAttribute),
 [[xml:base]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#XMLBaseAttribute),
 [[xml:lang]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#XMLLangAttribute),
 [[xml:space]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#XMLSpaceAttribute)]
- [transfer function element
 attributes](#transfer-function-element-attributes)[
 ---
 [type](#element-attrdef-fecomponenttransfer-type),
 [tableValues](#element-attrdef-fecomponenttransfer-tablevalues),
 [slope](#element-attrdef-fecomponenttransfer-slope),
 [intercept](#element-attrdef-fecomponenttransfer-intercept),
 [amplitude](#element-attrdef-fecomponenttransfer-amplitude),
 [exponent](#element-attrdef-fecomponenttransfer-exponent),
 [offset](#element-attrdef-fecomponenttransfer-offset)]

DOM Interfaces:

[SVGFEFuncRElement](#InterfaceSVGFEFuncRElement)

The attributes below are the [transfer function element
attributes], which apply to the [transfer function
elements](#transfer-function-element).

*Attribute definitions:*

[`type`] = \"[identity](#attr-valuedef-type-identity) \| [table](#attr-valuedef-type-table) \| [discrete](#attr-valuedef-type-discrete) \| [linear](#attr-valuedef-type-linear) \| [gamma](#attr-valuedef-type-gamma)\"

: Indicates the type of component transfer function. The type of
 function determines the applicability of the other attributes.

 In the following, C is the initial component (e.g.,
 [feFuncR](#elementdef-fefuncr)), C\' is the remapped component; both in the
 closed interval \[0,1\].

 - For [`identity`]:

 C' = C

 - For [`table`], the function is
 defined by linear interpolation between values given in the
 attribute
 [tableValues](#element-attrdef-fecomponenttransfer-tablevalues). The table has *n+1* values (i.e., v~0~
 to v~n~) specifying the start and end values for *n* evenly sized
 interpolation regions. Interpolations use the following formula:

 For a value `C < 1` find `k` such that:

 `k/n <= C < (k+1)/n`

 The result `C'` is given by:

 `C' = v`~`k`~` + (C - k/n)*n * (v`~`k+1`~` - v`~`k`~`)`

 If `C = 1` then:

 `C' = v`~`n`~`.`

 - For [`discrete`], the function is
 defined by the step function given in the attribute
 [tableValues](#element-attrdef-fecomponenttransfer-tablevalues), which provides a list of *n* values
 (i.e., v~0~ to v~n-1~) in order to identify a step function
 consisting of *n* steps. The step function is defined by the
 following formula:

 For a value `C < 1` find `k` such that:

 `k/n <= C < (k+1)/n`

 The result `C'` is given by:

 `C' = v`~`k`~

 If `C = 1` then:

 `C' = v`~`n-1`~`.`

 - For [`linear`], the function is
 defined by the following linear equation:

 `C' = `[`slope`](#element-attrdef-fecomponenttransfer-slope)` * C + `[`intercept`](#element-attrdef-fecomponenttransfer-intercept)

 - For [`gamma`], the function is
 defined by the following exponential function:

 `C' = `[`amplitude`](#element-attrdef-fecomponenttransfer-amplitude)` * pow(C, `[`exponent`](#element-attrdef-fecomponenttransfer-exponent)`) + `[`offset`](#element-attrdef-fecomponenttransfer-offset)

 The [initial
 value](https://svgwg.org/svg2-draft/types.html#TermInitialValue) for
 [type](#element-attrdef-fecomponenttransfer-type) is
 [identity](#attr-valuedef-type-identity).

 Animatable: yes.

[`tableValues`] = \"*(list of [\<number\>](https://www.w3.org/TR/css3-values/#number-value)s)*\"

: When `type="table"`, the list of
 [\<number\>](https://www.w3.org/TR/css3-values/#number-value) s *v0,v1,\...vn*, separated by
 white space and/or a comma, which define the lookup table. An empty
 list results in an identity transfer function.

 If the attribute is not specified, then the effect is as if an empty
 list were provided.

 Animatable: yes.

[`slope`] = \"*[\<number\>](https://www.w3.org/TR/css3-values/#number-value)*\"

: When `type="linear"`, the slope of the linear function.

 The [initial
 value](https://svgwg.org/svg2-draft/types.html#TermInitialValue) for
 [slope](#element-attrdef-fecomponenttransfer-slope) is [1].

 Animatable: yes.

[`intercept`] = \"*[\<number\>](https://www.w3.org/TR/css3-values/#number-value)*\"

: When `type="linear"`, the intercept of the linear function.

 The [initial
 value](https://svgwg.org/svg2-draft/types.html#TermInitialValue) for
 [intercept](#element-attrdef-fecomponenttransfer-intercept) is [0].

 Animatable: yes.

[`amplitude`] = \"*[\<number\>](https://www.w3.org/TR/css3-values/#number-value)*\"

: When `type="gamma"`, the amplitude of the gamma function.

 The [initial
 value](https://svgwg.org/svg2-draft/types.html#TermInitialValue) for
 [amplitude](#element-attrdef-fecomponenttransfer-amplitude) is [1].

 Animatable: yes.

[`exponent`] = \"*[\<number\>](https://www.w3.org/TR/css3-values/#number-value)*\"

: When `type="gamma"`, the exponent of the gamma function.

 The [initial
 value](https://svgwg.org/svg2-draft/types.html#TermInitialValue) for
 [exponent](#element-attrdef-fecomponenttransfer-exponent) is [1].

 Animatable: yes.

[`offset`] = \"*[\<number\>](https://www.w3.org/TR/css3-values/#number-value)*\"

: When `type="gamma"`, the offset of the gamma function.

 The [initial
 value](https://svgwg.org/svg2-draft/types.html#TermInitialValue) for
 [offset](#element-attrdef-fecomponenttransfer-offset) is [0].

 Animatable: yes.

``` highlight
<svg width="8cm" height="4cm" viewBox="0 0 800 400"
 xmlns="http://www.w3.org/2000/svg">
 <title>Example feComponentTransfer - Examples of feComponentTransfer operations</title>
 <desc>Four text strings showing the effects of feComponentTransfer:
 an identity function acting as a reference,
 use of the feComponentTransfer table option,
 use of the feComponentTransfer linear option,
 and use of the feComponentTransfer gamma option.</desc>
 <defs>
 <linearGradient id="MyGradient" gradientUnits="userSpaceOnUse"
 x1="100" y1="0" x2="600" y2="0">
 <stop offset="0" stop-color="#ff0000" />
 <stop offset=".33" stop-color="#00ff00" />
 <stop offset=".67" stop-color="#0000ff" />
 <stop offset="1" stop-color="#000000" />
 </linearGradient>
 <filter id="Identity" filterUnits="objectBoundingBox"
 x="0%" y="0%" width="100%" height="100%">
 <feComponentTransfer>
 <feFuncR type="identity"/>
 <feFuncG type="identity"/>
 <feFuncB type="identity"/>
 <feFuncA type="identity"/>
 </feComponentTransfer>
 </filter>
 <filter id="Table" filterUnits="objectBoundingBox"
 x="0%" y="0%" width="100%" height="100%">
 <feComponentTransfer>
 <feFuncR type="table" tableValues="0 0 1 1"/>
 <feFuncG type="table" tableValues="1 1 0 0"/>
 <feFuncB type="table" tableValues="0 1 1 0"/>
 </feComponentTransfer>
 </filter>
 <filter id="Linear" filterUnits="objectBoundingBox"
 x="0%" y="0%" width="100%" height="100%">
 <feComponentTransfer>
 <feFuncR type="linear" slope=".5" intercept=".25"/>
 <feFuncG type="linear" slope=".5" intercept="0"/>
 <feFuncB type="linear" slope=".5" intercept=".5"/>
 </feComponentTransfer>
 </filter>
 <filter id="Gamma" filterUnits="objectBoundingBox"
 x="0%" y="0%" width="100%" height="100%">
 <feComponentTransfer>
 <feFuncR type="gamma" amplitude="2" exponent="5" offset="0"/>
 <feFuncG type="gamma" amplitude="2" exponent="3" offset="0"/>
 <feFuncB type="gamma" amplitude="2" exponent="1" offset="0"/>
 </feComponentTransfer>
 </filter>
 </defs>
 <rect fill="none" stroke="blue"
 x="1" y="1" width="798" height="398"/>
 <g font-family="Verdana" font-size="75"
 font-weight="bold" fill="url(#MyGradient)" >
 <rect x="100" y="0" width="600" height="20" />
 <text x="100" y="90">Identity</text>
 <text x="100" y="190" filter="url(#Table)" >TableLookup</text>
 <text x="100" y="290" filter="url(#Linear)" >LinearFunc</text>
 <text x="100" y="390" filter="url(#Gamma)" >GammaFunc</text>
 </g>
</svg>
```

![Example for feComponentTransfer](examples/feComponentTransfer.png)

Example for feComponentTransfer

[View this example as SVG](examples/feComponentTransfer.svg)

#### 9.7.2. Transfer function [feFuncG]
Name:

[`feFuncG`]

Categories:

[transfer function
element](#transfer-function-element)

Content model:

Any number of [descriptive
elements](https://www.w3.org/TR/svg2/struct.html#TermDescriptiveElement),
[animate](https://www.w3.org/TR/SVG11/animate.html#AnimateElement),
[script](https://www.w3.org/TR/svg2/interact.html#elementdef-script),
[set](https://www.w3.org/TR/SVG11/animate.html#SetElement) elements, in any order.

Attributes:

- [core
 attributes](https://www.w3.org/TR/2011/REC-SVG11-20110816/intro.html#TermCoreAttributes)[
 ---
 [[id]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#IDAttribute),
 [[xml:base]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#XMLBaseAttribute),
 [[xml:lang]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#XMLLangAttribute),
 [[xml:space]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#XMLSpaceAttribute)]
- [transfer function element
 attributes](#transfer-function-element-attributes)[
 ---
 [type](#element-attrdef-fecomponenttransfer-type),
 [tableValues](#element-attrdef-fecomponenttransfer-tablevalues),
 [slope](#element-attrdef-fecomponenttransfer-slope),
 [intercept](#element-attrdef-fecomponenttransfer-intercept),
 [amplitude](#element-attrdef-fecomponenttransfer-amplitude),
 [exponent](#element-attrdef-fecomponenttransfer-exponent),
 [offset](#element-attrdef-fecomponenttransfer-offset)]

DOM Interfaces:

[SVGFEFuncGElement](#InterfaceSVGFEFuncGElement)

See [feFuncR](#elementdef-fefuncr) for the definitions of the attribute values.

#### 9.7.3. Transfer function [feFuncB]
Name:

[`feFuncB`]

Categories:

[transfer function
element](#transfer-function-element)

Content model:

Any number of [descriptive
elements](https://www.w3.org/TR/svg2/struct.html#TermDescriptiveElement),
[animate](https://www.w3.org/TR/SVG11/animate.html#AnimateElement),
[script](https://www.w3.org/TR/svg2/interact.html#elementdef-script),
[set](https://www.w3.org/TR/SVG11/animate.html#SetElement) elements, in any order.

Attributes:

- [core
 attributes](https://www.w3.org/TR/2011/REC-SVG11-20110816/intro.html#TermCoreAttributes)[
 ---
 [[id]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#IDAttribute),
 [[xml:base]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#XMLBaseAttribute),
 [[xml:lang]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#XMLLangAttribute),
 [[xml:space]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#XMLSpaceAttribute)]
- [transfer function element
 attributes](#transfer-function-element-attributes)[
 ---
 [type](#element-attrdef-fecomponenttransfer-type),
 [tableValues](#element-attrdef-fecomponenttransfer-tablevalues),
 [slope](#element-attrdef-fecomponenttransfer-slope),
 [intercept](#element-attrdef-fecomponenttransfer-intercept),
 [amplitude](#element-attrdef-fecomponenttransfer-amplitude),
 [exponent](#element-attrdef-fecomponenttransfer-exponent),
 [offset](#element-attrdef-fecomponenttransfer-offset)]

DOM Interfaces:

[SVGFEFuncBElement](#InterfaceSVGFEFuncBElement)

See [feFuncR](#elementdef-fefuncr) for the definitions of the attribute values.

#### 9.7.4. Transfer function [feFuncA]
Name:

[`feFuncA`]

Categories:

[transfer function
element](#transfer-function-element)

Content model:

Any number of [descriptive
elements](https://www.w3.org/TR/svg2/struct.html#TermDescriptiveElement),
[animate](https://www.w3.org/TR/SVG11/animate.html#AnimateElement),
[script](https://www.w3.org/TR/svg2/interact.html#elementdef-script),
[set](https://www.w3.org/TR/SVG11/animate.html#SetElement) elements, in any order.

Attributes:

- [core
 attributes](https://www.w3.org/TR/2011/REC-SVG11-20110816/intro.html#TermCoreAttributes)[
 ---
 [[id]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#IDAttribute),
 [[xml:base]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#XMLBaseAttribute),
 [[xml:lang]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#XMLLangAttribute),
 [[xml:space]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#XMLSpaceAttribute)]
- [transfer function element
 attributes](#transfer-function-element-attributes)[
 ---
 [type](#element-attrdef-fecomponenttransfer-type),
 [tableValues](#element-attrdef-fecomponenttransfer-tablevalues),
 [slope](#element-attrdef-fecomponenttransfer-slope),
 [intercept](#element-attrdef-fecomponenttransfer-intercept),
 [amplitude](#element-attrdef-fecomponenttransfer-amplitude),
 [exponent](#element-attrdef-fecomponenttransfer-exponent),
 [offset](#element-attrdef-fecomponenttransfer-offset)]

DOM Interfaces:

[SVGFEFuncAElement](#InterfaceSVGFEFuncAElement)

See [feFuncR](#elementdef-fefuncr) for the definitions of the attribute values.

### 9.8. Filter primitive [feComposite]
Name:

[`feComposite`]

Categories:

[filter primitive](#filter-primitive)

Content model:

Any number of [descriptive
elements](https://www.w3.org/TR/svg2/struct.html#TermDescriptiveElement),
[animate](https://www.w3.org/TR/SVG11/animate.html#AnimateElement),
[script](https://www.w3.org/TR/svg2/interact.html#elementdef-script),
[set](https://www.w3.org/TR/SVG11/animate.html#SetElement) elements, in any order.

Attributes:

- [core
 attributes](https://www.w3.org/TR/2011/REC-SVG11-20110816/intro.html#TermCoreAttributes)[
 ---
 [[id]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#IDAttribute),
 [[xml:base]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#XMLBaseAttribute),
 [[xml:lang]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#XMLLangAttribute),
 [[xml:space]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#XMLSpaceAttribute)]
- [presentation
 attributes](https://www.w3.org/TR/2008/REC-SVGTiny12-20081222/intro.html#TermPresentationAttribute)[
 ---
 [alignment-baseline](https://www.w3.org/TR/SVG11/text.html#AlignmentBaselineProperty),
 [baseline-shift](https://www.w3.org/TR/SVG11/text.html#BaselineShiftProperty),
 [clip](https://www.w3.org/TR/css-masking-1/#propdef-clip),
 [clip-path](https://www.w3.org/TR/css-masking-1/#propdef-clip-path),
 [clip-rule](https://www.w3.org/TR/css-masking-1/#propdef-clip-rule),
 [color](https://www.w3.org/TR/css3-color/#color0),
 [color-interpolation](https://www.w3.org/TR/svg2/painting.html#ColorInterpolationProperty),
 [color-interpolation-filters](#propdef-color-interpolation-filters),
 [color-rendering](https://www.w3.org/TR/svg2/painting.html#ColorRenderingProperty),
 [cursor](https://www.w3.org/TR/css3-ui/#propdef-cursor),
 [direction](https://www.w3.org/TR/css-writing-modes-3/#propdef-direction),
 [display](https://www.w3.org/TR/css-display-3/#propdef-display),
 [dominant-baseline](https://www.w3.org/TR/SVG11/text.html#DominantBaselineProperty),
 [enable-background](https://www.w3.org/TR/SVG11/filters.html#EnableBackgroundProperty),
 [fill](https://www.w3.org/TR/svg2/painting.html#FillProperty),
 [fill-opacity](https://www.w3.org/TR/svg2/painting.html#FillOpacityProperty),
 [fill-rule](https://www.w3.org/TR/svg2/painting.html#FillRuleProperty),
 [filter](#propdef-filter),
 [flood-color](#propdef-flood-color),
 [flood-opacity](#propdef-flood-opacity),
 [font](https://www.w3.org/TR/css-fonts-3/#propdef-font),
 [font-family](https://www.w3.org/TR/css-fonts-3/#propdef-font-family),
 [font-size](https://www.w3.org/TR/css-fonts-3/#propdef-font-size),
 [font-size-adjust](https://www.w3.org/TR/css-fonts-4/#propdef-font-size-adjust),
 [font-stretch](https://www.w3.org/TR/css-fonts-3/#propdef-font-stretch),
 [font-style](https://www.w3.org/TR/css-fonts-3/#propdef-font-style),
 [font-variant](https://www.w3.org/TR/css-fonts-3/#propdef-font-variant),
 [font-weight](https://www.w3.org/TR/css-fonts-3/#propdef-font-weight),
 [glyph-orientation-horizontal](https://www.w3.org/TR/SVG11/text.html#GlyphOrientationHorizontalProperty),
 [glyph-orientation-vertical](https://www.w3.org/TR/SVG11/text.html#GlyphOrientationVerticalProperty),
 [image-rendering](https://drafts.csswg.org/css-images-3/#propdef-image-rendering),
 [isolation](https://www.w3.org/TR/compositing-1/#propdef-isolation),
 [kerning](https://www.w3.org/TR/SVG11/text.html#KerningProperty),
 [letter-spacing](https://www.w3.org/TR/css-text-3/#propdef-letter-spacing),
 [lighting-color](#propdef-lighting-color),
 [marker](https://www.w3.org/TR/svg2/painting.html#MarkerProperty),
 [marker-end](https://www.w3.org/TR/svg2/painting.html#MarkerEndProperty),
 [marker-mid](https://www.w3.org/TR/svg2/painting.html#MarkerMidProperty),
 [marker-start](https://www.w3.org/TR/svg2/painting.html#MarkerStartProperty),
 [mask](https://www.w3.org/TR/css-masking-1/#propdef-mask),
 [opacity](https://www.w3.org/TR/css-color-4/#propdef-opacity),
 [overflow](https://www.w3.org/TR/css-overflow-3/#propdef-overflow),
 [pointer-events](https://www.w3.org/TR/svg2/interact.html#PointerEventsProperty),
 [shape-rendering](https://www.w3.org/TR/svg2/painting.html#ShapeRenderingProperty),
 [stop-color](https://www.w3.org/TR/svg2/pservers.html#StopColorProperty),
 [stop-opacity](https://www.w3.org/TR/svg2/pservers.html#StopOpacityProperty),
 [stroke](https://www.w3.org/TR/svg2/painting.html#StrokeProperty),
 [stroke-dasharray](https://www.w3.org/TR/svg2/painting.html#StrokeDasharrayProperty),
 [stroke-dashoffset](https://www.w3.org/TR/svg2/painting.html#StrokeDashoffsetProperty),
 [stroke-linecap](https://www.w3.org/TR/svg2/painting.html#StrokeLinecapProperty),
 [stroke-linejoin](https://www.w3.org/TR/svg2/painting.html#StrokeLinejoinProperty),
 [stroke-miterlimit](https://www.w3.org/TR/svg2/painting.html#StrokeMiterlimitProperty),
 [stroke-opacity](https://www.w3.org/TR/svg2/painting.html#StrokeOpacityProperty),
 [stroke-width](https://www.w3.org/TR/svg2/painting.html#StrokeWidthProperty),
 [text-anchor](https://www.w3.org/TR/svg2/text.html#TextAnchorProperty),
 [text-decoration](https://www.w3.org/TR/css-text-decor-3/#propdef-text-decoration),
 [text-rendering](https://www.w3.org/TR/svg2/painting.html#TextRenderingProperty),
 [unicode-bidi](https://www.w3.org/TR/css-writing-modes-3/#propdef-unicode-bidi),
 [visibility](https://www.w3.org/TR/CSS21/visufx.html#propdef-visibility),
 [word-spacing](https://www.w3.org/TR/css-text-3/#propdef-word-spacing),
 [writing-mode](https://www.w3.org/TR/css-writing-modes-4/#propdef-writing-mode)]
- [filter primitive
 attributes](#filter-primitive-attributes)
 [
 ---[x](#element-attrdef-filter-primitive-x),
 [y](#element-attrdef-filter-primitive-y),
 [width](#element-attrdef-filter-primitive-width),
 [height](#element-attrdef-filter-primitive-height),
 [result](#element-attrdef-filter-primitive-result) ]
- [[class]](https://www.w3.org/TR/2011/REC-SVG11-20110816/styling.html#ClassAttribute)
- [[style]](https://www.w3.org/TR/2011/REC-SVG11-20110816/styling.html#StyleAttribute)
- [in](#element-attrdef-filter-primitive-in)
- [in2](#element-attrdef-fecomposite-in2)
- [operator](#element-attrdef-fecomposite-operator)
- [k1](#element-attrdef-fecomposite-k1)
- [k2](#element-attrdef-fecomposite-k2)
- [k3](#element-attrdef-fecomposite-k3)
- [k4](#element-attrdef-fecomposite-k4)

DOM Interfaces:

[SVGFECompositeElement](#InterfaceSVGFECompositeElement)

This filter performs the combination of the two input images pixel-wise
in image space using one of the Porter-Duff
[\[PORTERDUFF\]](#biblio-porterduff) compositing
operations:
[over](#attr-valuedef-operator-over), [in], [atop], [out],
[xor], [lighter]
[\[COMPOSITING-1\]](#biblio-compositing-1).
Additionally, a component-wise *arithmetic* operation (with the result
clamped between \[0..1\]) can be applied.

The *arithmetic* operation is useful for combining the output from the
[feDiffuseLighting](#elementdef-fediffuselighting) and
[feSpecularLighting](#elementdef-fespecularlighting) filters with texture data. It is also useful for
implementing *dissolve*. If the *arithmetic* operation is chosen, each
result pixel is computed using the following formula:

 result = k1*i1*i2 + k2*i1 + k3*i2 + k4

where:

- `i1` and `i2` indicate the corresponding pixel channel values of the
 input image, which map to
 [in](#element-attrdef-filter-primitive-in) and
 [in2](#element-attrdef-fecomposite-in2) respectively

- `k1, k2, k3` and `k4` indicate the values of the attributes with the
 same name

For this filter primitive, the extent of the resulting image might grow
as described in the section that describes the [filter primitive
subregion](#filter-primitive-subregion).

*Attribute definitions:*

[`operator`] = \"[`over`] \| [`in`] \| [`out`] \| [`atop`] \| [`xor`] \| [`lighter`(#attr-valuedef-operator-lighter)] \| [`arithmetic`]\"

: The compositing operation that is to be performed. All of the
 [operator](#element-attrdef-fecomposite-operator) types except [arithmetic] match the
 corresponding operation as described in
 [\[COMPOSITING-1\]](#biblio-compositing-1) with
 [in](#element-attrdef-filter-primitive-in) representing the source and
 [in2](#element-attrdef-fecomposite-in2) representing the destination. The
 [arithmetic] operator is described above.

 The [initial
 value](https://svgwg.org/svg2-draft/types.html#TermInitialValue) for
 [operator](#element-attrdef-fecomposite-operator) is
 [over](#attr-valuedef-operator-over).

 Animatable: yes.

[`k1`] = \"[\<number\>](https://www.w3.org/TR/css3-values/#number-value)\"

: Only applicable if `operator="arithmetic"`.

 The [initial
 value](https://svgwg.org/svg2-draft/types.html#TermInitialValue) for
 [k1](#element-attrdef-fecomposite-k1) is [0].

 Animatable: yes.

[`k2`] = \"*[\<number\>](https://www.w3.org/TR/css3-values/#number-value)*\"

: Only applicable if `operator="arithmetic"`.

 The [initial
 value](https://svgwg.org/svg2-draft/types.html#TermInitialValue) for
 [k2](#element-attrdef-fecomposite-k2) is [0].

 Animatable: yes.

[`k3`] = \"[\<number\>](https://www.w3.org/TR/css3-values/#number-value)\"

: Only applicable if `operator="arithmetic"`.

 The [initial
 value](https://svgwg.org/svg2-draft/types.html#TermInitialValue) for
 [k3](#element-attrdef-fecomposite-k3) is [0].

 Animatable: yes.

[`k4`] = \"[\<number\>](https://www.w3.org/TR/css3-values/#number-value)\"

: Only applicable if `operator="arithmetic"`.

 The [initial
 value](https://svgwg.org/svg2-draft/types.html#TermInitialValue) for
 [k4](#element-attrdef-fecomposite-k4) is [0].

 Animatable: yes.

[`in2`] = \"*(see [in](#element-attrdef-filter-primitive-in) attribute)*\"

: The second input image to the compositing operation.

 Animatable: yes.

Note: Compositing and Blending
[\[COMPOSITING-1\]](#biblio-compositing-1) defines
more compositing keywords. The functionality of the additional keywords
can be archived by switching the input filter primitives
[in](#element-attrdef-filter-primitive-in) and
[in2](#element-attrdef-fecomposite-in2).

``` highlight
<svg width="330" height="195" viewBox="0 0 1100 650"
 xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
 <title>Example feComposite - Examples of feComposite operations</title>
 <desc>Four rows of six pairs of overlapping triangles depicting
 the six different feComposite operators under different
 opacity values and different clearing of the background.</desc>
 <defs>
 <desc>Define two sets of six filters for each of the six compositing operators.
 The first set wipes out the background image by flooding with opaque white.
 The second set does not wipe out the background, with the result
 that the background sometimes shines through and is other cases
 is blended into itself (i.e., "double-counting").</desc>
 <filter id="overFlood" filterUnits="objectBoundingBox" x="-5%" y="-5%" width="110%" height="110%">
 <feFlood flood-color="#ffffff" flood-opacity="1" resu/>
 <feComposite in="SourceGraphic" in2="BackgroundImage" operator="over" resu/>
 <feMerge> <feMergeNode in="flood"/> <feMergeNode in="comp"/> </feMerge>
 </filter>
 <filter id="inFlood" filterUnits="objectBoundingBox" x="-5%" y="-5%" width="110%" height="110%">
 <feFlood flood-color="#ffffff" flood-opacity="1" resu/>
 <feComposite in="SourceGraphic" in2="BackgroundImage" operator="in" resu/>
 <feMerge> <feMergeNode in="flood"/> <feMergeNode in="comp"/> </feMerge>
 </filter>
 <filter id="outFlood" filterUnits="objectBoundingBox" x="-5%" y="-5%" width="110%" height="110%">
 <feFlood flood-color="#ffffff" flood-opacity="1" resu/>
 <feComposite in="SourceGraphic" in2="BackgroundImage" operator="out" resu/>
 <feMerge> <feMergeNode in="flood"/> <feMergeNode in="comp"/> </feMerge>
 </filter>
 <filter id="atopFlood" filterUnits="objectBoundingBox" x="-5%" y="-5%" width="110%" height="110%">
 <feFlood flood-color="#ffffff" flood-opacity="1" resu/>
 <feComposite in="SourceGraphic" in2="BackgroundImage" operator="atop" resu/>
 <feMerge> <feMergeNode in="flood"/> <feMergeNode in="comp"/> </feMerge>
 </filter>
 <filter id="xorFlood" filterUnits="objectBoundingBox" x="-5%" y="-5%" width="110%" height="110%">
 <feFlood flood-color="#ffffff" flood-opacity="1" resu/>
 <feComposite in="SourceGraphic" in2="BackgroundImage" operator="xor" resu/>
 <feMerge> <feMergeNode in="flood"/> <feMergeNode in="comp"/> </feMerge>
 </filter>
 <filter id="arithmeticFlood" filterUnits="objectBoundingBox"
 x="-5%" y="-5%" width="110%" height="110%">
 <feFlood flood-color="#ffffff" flood-opacity="1" resu/>
 <feComposite in="SourceGraphic" in2="BackgroundImage" resu
 operator="arithmetic" k1=".5" k2=".5" k3=".5" k4=".5"/>
 <feMerge> <feMergeNode in="flood"/> <feMergeNode in="comp"/> </feMerge>
 </filter>
 <filter id="overNoFlood" filterUnits="objectBoundingBox" x="-5%" y="-5%" width="110%" height="110%">
 <feComposite in="SourceGraphic" in2="BackgroundImage" operator="over" resu/>
 </filter>
 <filter id="inNoFlood" filterUnits="objectBoundingBox" x="-5%" y="-5%" width="110%" height="110%">
 <feComposite in="SourceGraphic" in2="BackgroundImage" operator="in" resu/>
 </filter>
 <filter id="outNoFlood" filterUnits="objectBoundingBox" x="-5%" y="-5%" width="110%" height="110%">
 <feComposite in="SourceGraphic" in2="BackgroundImage" operator="out" resu/>
 </filter>
 <filter id="atopNoFlood" filterUnits="objectBoundingBox" x="-5%" y="-5%" width="110%" height="110%">
 <feComposite in="SourceGraphic" in2="BackgroundImage" operator="atop" resu/>
 </filter>
 <filter id="xorNoFlood" filterUnits="objectBoundingBox" x="-5%" y="-5%" width="110%" height="110%">
 <feComposite in="SourceGraphic" in2="BackgroundImage" operator="xor" resu/>
 </filter>
 <filter id="arithmeticNoFlood" filterUnits="objectBoundingBox"
 x="-5%" y="-5%" width="110%" height="110%">
 <feComposite in="SourceGraphic" in2="BackgroundImage" resu
 operator="arithmetic" k1=".5" k2=".5" k3=".5" k4=".5"/>
 </filter>
 <path id="Blue100" d="M 0 0 L 100 0 L 100 100 z" fill="#00ffff" />
 <path id="Red100" d="M 0 0 L 0 100 L 100 0 z" fill="#ff00ff" />
 <path id="Blue50" d="M 0 125 L 100 125 L 100 225 z" fill="#00ffff" fill-opacity=".5" />
 <path id="Red50" d="M 0 125 L 0 225 L 100 125 z" fill="#ff00ff" fill-opacity=".5" />
 <g id="TwoBlueTriangles">
 <use xlink:href="#Blue100"/>
 <use xlink:href="#Blue50"/>
 </g>
 <g id="BlueTriangles">
 <use transform="translate(275,25)" xlink:href="#TwoBlueTriangles"/>
 <use transform="translate(400,25)" xlink:href="#TwoBlueTriangles"/>
 <use transform="translate(525,25)" xlink:href="#TwoBlueTriangles"/>
 <use transform="translate(650,25)" xlink:href="#TwoBlueTriangles"/>
 <use transform="translate(775,25)" xlink:href="#TwoBlueTriangles"/>
 <use transform="translate(900,25)" xlink:href="#TwoBlueTriangles"/>
 </g>
 </defs>

 <rect fill="none" stroke="blue" x="1" y="1" width="1098" height="648"/>
 <g font-family="Verdana" font-size="40" shape-rendering="crispEdges">
 <desc>Render the examples using the filters that draw on top of
 an opaque white surface, thus obliterating the background.</desc>
 <g isolation="isolate">
 <text x="15" y="75">opacity 1.0</text>
 <text x="15" y="115" font-size="27">(with feFlood)</text>
 <text x="15" y="200">opacity 0.5</text>
 <text x="15" y="240" font-size="27">(with feFlood)</text>
 <use xlink:href="#BlueTriangles"/>
 <g transform="translate(275,25)">
 <use xlink:href="#Red100" filter="url(#overFlood)" />
 <use xlink:href="#Red50" filter="url(#overFlood)" />
 <text x="5" y="275">over</text>
 </g>
 <g transform="translate(400,25)">
 <use xlink:href="#Red100" filter="url(#inFlood)" />
 <use xlink:href="#Red50" filter="url(#inFlood)" />
 <text x="35" y="275">in</text>
 </g>
 <g transform="translate(525,25)">
 <use xlink:href="#Red100" filter="url(#outFlood)" />
 <use xlink:href="#Red50" filter="url(#outFlood)" />
 <text x="15" y="275">out</text>
 </g>
 <g transform="translate(650,25)">
 <use xlink:href="#Red100" filter="url(#atopFlood)" />
 <use xlink:href="#Red50" filter="url(#atopFlood)" />
 <text x="10" y="275">atop</text>
 </g>
 <g transform="translate(775,25)">
 <use xlink:href="#Red100" filter="url(#xorFlood)" />
 <use xlink:href="#Red50" filter="url(#xorFlood)" />
 <text x="15" y="275">xor</text>
 </g>
 <g transform="translate(900,25)">
 <use xlink:href="#Red100" filter="url(#arithmeticFlood)" />
 <use xlink:href="#Red50" filter="url(#arithmeticFlood)" />
 <text x="-25" y="275">arithmetic</text>
 </g>
 </g>
 <g transform="translate(0,325)" isolation="isolate">
 <desc>Render the examples using the filters that do not obliterate
 the background, thus sometimes causing the background to continue
 to appear in some cases, and in other cases the background
 image blends into itself ("double-counting").</desc>
 <text x="15" y="75">opacity 1.0</text>
 <text x="15" y="115" font-size="27">(without feFlood)</text>
 <text x="15" y="200">opacity 0.5</text>
 <text x="15" y="240" font-size="27">(without feFlood)</text>
 <use xlink:href="#BlueTriangles"/>
 <g transform="translate(275,25)">
 <use xlink:href="#Red100" filter="url(#overNoFlood)" />
 <use xlink:href="#Red50" filter="url(#overNoFlood)" />
 <text x="5" y="275">over</text>
 </g>
 <g transform="translate(400,25)">
 <use xlink:href="#Red100" filter="url(#inNoFlood)" />
 <use xlink:href="#Red50" filter="url(#inNoFlood)" />
 <text x="35" y="275">in</text>
 </g>
 <g transform="translate(525,25)">
 <use xlink:href="#Red100" filter="url(#outNoFlood)" />
 <use xlink:href="#Red50" filter="url(#outNoFlood)" />
 <text x="15" y="275">out</text>
 </g>
 <g transform="translate(650,25)">
 <use xlink:href="#Red100" filter="url(#atopNoFlood)" />
 <use xlink:href="#Red50" filter="url(#atopNoFlood)" />
 <text x="10" y="275">atop</text>
 </g>
 <g transform="translate(775,25)">
 <use xlink:href="#Red100" filter="url(#xorNoFlood)" />
 <use xlink:href="#Red50" filter="url(#xorNoFlood)" />
 <text x="15" y="275">xor</text>
 </g>
 <g transform="translate(900,25)">
 <use xlink:href="#Red100" filter="url(#arithmeticNoFlood)" />
 <use xlink:href="#Red50" filter="url(#arithmeticNoFlood)" />
 <text x="-25" y="275">arithmetic</text>
 </g>
 </g>
 </g>
</svg>
```

![Example of feComposite](examples/feComposite.png)

Example of feComposite

[View this example as SVG](examples/feComposite.svg)

### 9.9. Filter primitive [feConvolveMatrix]
Name:

[`feConvolveMatrix`]

Categories:

[filter primitive](#filter-primitive)

Content model:

Any number of [descriptive
elements](https://www.w3.org/TR/svg2/struct.html#TermDescriptiveElement),
[animate](https://www.w3.org/TR/SVG11/animate.html#AnimateElement),
[script](https://www.w3.org/TR/svg2/interact.html#elementdef-script),
[set](https://www.w3.org/TR/SVG11/animate.html#SetElement) elements, in any order.

Attributes:

- [core
 attributes](https://www.w3.org/TR/2011/REC-SVG11-20110816/intro.html#TermCoreAttributes)[
 ---
 [[id]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#IDAttribute),
 [[xml:base]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#XMLBaseAttribute),
 [[xml:lang]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#XMLLangAttribute),
 [[xml:space]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#XMLSpaceAttribute)]
- [presentation
 attributes](https://www.w3.org/TR/2008/REC-SVGTiny12-20081222/intro.html#TermPresentationAttribute)[
 ---
 [alignment-baseline](https://www.w3.org/TR/SVG11/text.html#AlignmentBaselineProperty),
 [baseline-shift](https://www.w3.org/TR/SVG11/text.html#BaselineShiftProperty),
 [clip](https://www.w3.org/TR/css-masking-1/#propdef-clip),
 [clip-path](https://www.w3.org/TR/css-masking-1/#propdef-clip-path),
 [clip-rule](https://www.w3.org/TR/css-masking-1/#propdef-clip-rule),
 [color](https://www.w3.org/TR/css3-color/#color0),
 [color-interpolation](https://www.w3.org/TR/svg2/painting.html#ColorInterpolationProperty),
 [color-interpolation-filters](#propdef-color-interpolation-filters),
 [color-rendering](https://www.w3.org/TR/svg2/painting.html#ColorRenderingProperty),
 [cursor](https://www.w3.org/TR/css3-ui/#propdef-cursor),
 [direction](https://www.w3.org/TR/css-writing-modes-3/#propdef-direction),
 [display](https://www.w3.org/TR/css-display-3/#propdef-display),
 [dominant-baseline](https://www.w3.org/TR/SVG11/text.html#DominantBaselineProperty),
 [enable-background](https://www.w3.org/TR/SVG11/filters.html#EnableBackgroundProperty),
 [fill](https://www.w3.org/TR/svg2/painting.html#FillProperty),
 [fill-opacity](https://www.w3.org/TR/svg2/painting.html#FillOpacityProperty),
 [fill-rule](https://www.w3.org/TR/svg2/painting.html#FillRuleProperty),
 [filter](#propdef-filter),
 [flood-color](#propdef-flood-color),
 [flood-opacity](#propdef-flood-opacity),
 [font](https://www.w3.org/TR/css-fonts-3/#propdef-font),
 [font-family](https://www.w3.org/TR/css-fonts-3/#propdef-font-family),
 [font-size](https://www.w3.org/TR/css-fonts-3/#propdef-font-size),
 [font-size-adjust](https://www.w3.org/TR/css-fonts-4/#propdef-font-size-adjust),
 [font-stretch](https://www.w3.org/TR/css-fonts-3/#propdef-font-stretch),
 [font-style](https://www.w3.org/TR/css-fonts-3/#propdef-font-style),
 [font-variant](https://www.w3.org/TR/css-fonts-3/#propdef-font-variant),
 [font-weight](https://www.w3.org/TR/css-fonts-3/#propdef-font-weight),
 [glyph-orientation-horizontal](https://www.w3.org/TR/SVG11/text.html#GlyphOrientationHorizontalProperty),
 [glyph-orientation-vertical](https://www.w3.org/TR/SVG11/text.html#GlyphOrientationVerticalProperty),
 [image-rendering](https://drafts.csswg.org/css-images-3/#propdef-image-rendering),
 [isolation](https://www.w3.org/TR/compositing-1/#propdef-isolation),
 [kerning](https://www.w3.org/TR/SVG11/text.html#KerningProperty),
 [letter-spacing](https://www.w3.org/TR/css-text-3/#propdef-letter-spacing),
 [lighting-color](#propdef-lighting-color),
 [marker](https://www.w3.org/TR/svg2/painting.html#MarkerProperty),
 [marker-end](https://www.w3.org/TR/svg2/painting.html#MarkerEndProperty),
 [marker-mid](https://www.w3.org/TR/svg2/painting.html#MarkerMidProperty),
 [marker-start](https://www.w3.org/TR/svg2/painting.html#MarkerStartProperty),
 [mask](https://www.w3.org/TR/css-masking-1/#propdef-mask),
 [opacity](https://www.w3.org/TR/css-color-4/#propdef-opacity),
 [overflow](https://www.w3.org/TR/css-overflow-3/#propdef-overflow),
 [pointer-events](https://www.w3.org/TR/svg2/interact.html#PointerEventsProperty),
 [shape-rendering](https://www.w3.org/TR/svg2/painting.html#ShapeRenderingProperty),
 [stop-color](https://www.w3.org/TR/svg2/pservers.html#StopColorProperty),
 [stop-opacity](https://www.w3.org/TR/svg2/pservers.html#StopOpacityProperty),
 [stroke](https://www.w3.org/TR/svg2/painting.html#StrokeProperty),
 [stroke-dasharray](https://www.w3.org/TR/svg2/painting.html#StrokeDasharrayProperty),
 [stroke-dashoffset](https://www.w3.org/TR/svg2/painting.html#StrokeDashoffsetProperty),
 [stroke-linecap](https://www.w3.org/TR/svg2/painting.html#StrokeLinecapProperty),
 [stroke-linejoin](https://www.w3.org/TR/svg2/painting.html#StrokeLinejoinProperty),
 [stroke-miterlimit](https://www.w3.org/TR/svg2/painting.html#StrokeMiterlimitProperty),
 [stroke-opacity](https://www.w3.org/TR/svg2/painting.html#StrokeOpacityProperty),
 [stroke-width](https://www.w3.org/TR/svg2/painting.html#StrokeWidthProperty),
 [text-anchor](https://www.w3.org/TR/svg2/text.html#TextAnchorProperty),
 [text-decoration](https://www.w3.org/TR/css-text-decor-3/#propdef-text-decoration),
 [text-rendering](https://www.w3.org/TR/svg2/painting.html#TextRenderingProperty),
 [unicode-bidi](https://www.w3.org/TR/css-writing-modes-3/#propdef-unicode-bidi),
 [visibility](https://www.w3.org/TR/CSS21/visufx.html#propdef-visibility),
 [word-spacing](https://www.w3.org/TR/css-text-3/#propdef-word-spacing),
 [writing-mode](https://www.w3.org/TR/css-writing-modes-4/#propdef-writing-mode)]
- [filter primitive
 attributes](#filter-primitive-attributes)
 [
 ---[x](#element-attrdef-filter-primitive-x),
 [y](#element-attrdef-filter-primitive-y),
 [width](#element-attrdef-filter-primitive-width),
 [height](#element-attrdef-filter-primitive-height),
 [result](#element-attrdef-filter-primitive-result) ]
- [[class]](https://www.w3.org/TR/2011/REC-SVG11-20110816/styling.html#ClassAttribute)
- [[style]](https://www.w3.org/TR/2011/REC-SVG11-20110816/styling.html#StyleAttribute)
- [in](#element-attrdef-filter-primitive-in)
- [order](#element-attrdef-order)
- [kernelMatrix](#element-attrdef-feconvolvematrix-kernelmatrix)
- [divisor](#element-attrdef-feconvolvematrix-divisor)
- [bias](#element-attrdef-feconvolvematrix-bias)
- [targetX](#element-attrdef-feconvolvematrix-targetx)
- [targetY](#element-attrdef-feconvolvematrix-targety)
- [edgeMode](#element-attrdef-feconvolvematrix-edgemode)
- [kernelUnitLength](#element-attrdef-feconvolvematrix-kernelunitlength)
- [preserveAlpha](#element-attrdef-feconvolvematrix-preservealpha)

DOM Interfaces:

[SVGFEConvolveMatrixElement](#InterfaceSVGFEConvolveMatrixElement)

feConvolveMatrix applies a matrix convolution filter effect. A
convolution combines pixels in the input image with neighboring pixels
to produce a resulting image. A wide variety of imaging operations can
be achieved through convolutions, including blurring, edge detection,
sharpening, embossing and beveling.

A matrix convolution is based on an n-by-m matrix (the convolution
kernel) which describes how a given pixel value in the input image is
combined with its neighboring pixel values to produce a resulting pixel
value. Each result pixel is determined by applying the kernel matrix to
the corresponding source pixel and its neighboring pixels. The basic
convolution formula which is applied to each color value for a given
pixel is:

${color}_{X,Y} = {\frac{{\sum\limits_{i = 0}^{{orderY} - 1}{\sum\limits_{j = 0}^{{orderX} - 1}{source}_{{{x - {targetX}} + j},{{y - \mathit{targetY}} + i}}}} \cdot {kernalMatrix}_{{{{orderX} - j} - 1,}{{{orderY} - i} - 1}}}{divisor} + {{bias} \cdot {alpha}_{x,y}}}$

where \"orderX\" and \"orderY\" represent the X and Y values for the
[order](#element-attrdef-order) attribute, \"targetX\" represents the value of
the
[targetX](#element-attrdef-feconvolvematrix-targetx) attribute, \"targetY\" represents the value of
the
[targetY](#element-attrdef-feconvolvematrix-targety) attribute, \"kernelMatrix\" represents the
value of the
[kernelMatrix](#element-attrdef-feconvolvematrix-kernelmatrix) attribute, \"divisor\" represents the value of
the
[divisor](#element-attrdef-feconvolvematrix-divisor) attribute, and \"bias\" represents the value
of the
[bias](#element-attrdef-feconvolvematrix-bias) attribute.

In the above formulas the values in the kernel matrix are applied such
that the kernel matrix is rotated 180 degrees relative to the source and
destination images in order to match convolution theory as described in
many computer graphics textbooks.

To illustrate, suppose you have a input image which is 5 pixels by 5
pixels, whose color values for one of the color channels are as follows:

$\begin{bmatrix}
0 & 20 & 40 & 235 & 235 \\
100 & 120 & 140 & 235 & 235 \\
200 & 220 & 240 & 235 & 235 \\
255 & 255 & 255 & 255 & 255 \\
255 & 255 & 255 & 255 & 255
\end{bmatrix}$

and you define a 3-by-3 convolution kernel as follows:

$\begin{bmatrix}
1 & 2 & 3 \\
4 & 5 & 6 \\
7 & 8 & 9
\end{bmatrix}$

Let's focus on the color value at the second row and second column of
the image (source pixel value is 120). Assuming the simplest case (where
the input image's pixel grid aligns perfectly with the kernel's pixel
grid) and assuming default values for attributes
[divisor](#element-attrdef-feconvolvematrix-divisor),
[targetX](#element-attrdef-feconvolvematrix-targetx) and
[targetY](#element-attrdef-feconvolvematrix-targety), then resulting color value will be:

${resultChannel}_{2,2} = \frac{{{{{{{{{9 \cdot 0} + {8 \cdot 20}} + {7 \cdot 40}} + {6 \cdot 100}} + {5 \cdot 120}} + {4 \cdot 140}} + {3 \cdot 200}} + {2 \cdot 220}} + {1 \cdot 240}}{{{{{{{{9 + 8} + 7} + 6} + 5} + 4} + 3} + 2} + 1}$

Because they operate on pixels, matrix convolutions are inherently
resolution-dependent. To make
[feConvolveMatrix](#elementdef-feconvolvematrix) produce resolution-independent results, an explicit
value should be provided for the attribute
[kernelUnitLength](#element-attrdef-feconvolvematrix-kernelunitlength).

[kernelUnitLength](#element-attrdef-feconvolvematrix-kernelunitlength), in combination with the other attributes,
defines an implicit pixel grid in the filter effects coordinate system
(i.e., the coordinate system established by the
[primitiveUnits](#element-attrdef-filter-primitiveunits) attribute). The input image will be
temporarily rescaled to match its pixels with
[kernelUnitLength].
The convolution happens on the resampled image. After applying the
convolution, the image is resampled back to the original resolution.

When the image must be resampled to match the coordinate system defined
by
[kernelUnitLength](#element-attrdef-feconvolvematrix-kernelunitlength) prior to convolution, or resampled to match
the device coordinate system after convolution, it is recommended that
high quality viewers make use of appropriate interpolation techniques,
for example bilinear or bicubic. Depending on the speed of the available
interpolents, this choice may be affected by the
[image-rendering](https://drafts.csswg.org/css-images-3/#propdef-image-rendering) property setting. Note that
implementations might choose approaches that minimize or eliminate
resampling when not necessary to produce proper results, such as when
the document is zoomed out such that
[kernelUnitLength]
is considerably smaller than a device pixel.

*Attribute definitions:*

[`order`] = \"*[\<number-optional-number\>](#typedef-number-optional-number)*\"

: Indicates the number of cells in each dimension for
 [kernelMatrix](#element-attrdef-feconvolvematrix-kernelmatrix). The values provided must be
 [\<integer\>](https://www.w3.org/TR/css3-values/#integer-value) s greater than zero. Values that
 are not integers will be truncated, i.e. rounded to the closest
 integer value towards zero. The first number, \<orderX\>, indicates
 the number of columns in the matrix. The second number, \<orderY\>,
 indicates the number of rows in the matrix. If \<orderY\> is not
 provided, it defaults to \<orderX\>.

 It is recommended that only small values (e.g., [3]) be used;
 higher values may result in very high CPU overhead and usually do
 not produce results that justify the impact on performance.

 The [initial
 value](https://svgwg.org/svg2-draft/types.html#TermInitialValue) for
 [order](#element-attrdef-order) is [3].

 Animatable: yes.

[`kernelMatrix`] = \"*\<list of numbers\>*\"

: The list of
 [\<number\>](https://www.w3.org/TR/css3-values/#number-value) s that make up the kernel matrix
 for the convolution. Values are separated by space characters and/or
 a comma. The number of entries in the list must equal \<orderX\>
 times \<orderY\>.

 If the result of `orderX * orderY` is not equal to the the number of
 entries in the value list, the filter primitive acts as a [pass
 through filter](#pass-through-filter).

 (#issue-4fd9d6f6) How to behave on invalid number of
 entries in the value list?
 [\<https://github.com/w3c/csswg-drafts/issues/237\>](https://github.com/w3c/csswg-drafts/issues/237)

 Animatable: yes.

[`divisor`] = \"*[\<number\>](https://www.w3.org/TR/css3-values/#number-value)*\"

: After applying the
 [kernelMatrix](#element-attrdef-feconvolvematrix-kernelmatrix) to the input image to yield a number, that
 number is divided by
 [divisor](#element-attrdef-feconvolvematrix-divisor) to yield the final destination color
 value. A divisor that is the sum of all the matrix values tends to
 have an evening effect on the overall color intensity of the result.
 If the specified divisor is [0] then the default value will be
 used instead.

 The [initial
 value](https://svgwg.org/svg2-draft/types.html#TermInitialValue) is the sum of all values in
 [kernelMatrix](#element-attrdef-feconvolvematrix-kernelmatrix), with the exception that if the sum is
 zero, then the divisor is set to [1].

 Animatable: yes.

[`bias`] = \"*[\<number\>](https://www.w3.org/TR/css3-values/#number-value)*\"

: After applying the
 [kernelMatrix](#element-attrdef-feconvolvematrix-kernelmatrix) to the input image to yield a number and
 applying the
 [divisor](#element-attrdef-feconvolvematrix-divisor), the
 [bias](#element-attrdef-feconvolvematrix-bias) attribute is added to each component. One
 application of
 [bias] is when it
 is desirable to have [.5] gray value be the zero response of
 the filter. The bias property shifts the range of the filter. This
 allows representation of values that would otherwise be clamped to 0
 or 1.

 The [initial
 value](https://svgwg.org/svg2-draft/types.html#TermInitialValue) for
 [bias](#element-attrdef-feconvolvematrix-bias) is [0].

 Animatable: yes.

[`targetX`] = \"[\<integer\>](https://www.w3.org/TR/css3-values/#integer-value)\"

: Determines the positioning in X of the convolution matrix relative
 to a given target pixel in the input image. The leftmost column of
 the matrix is column number zero. The value must be such that: 0 \<=
 targetX \< orderX. By default, the convolution matrix is centered in
 X over each pixel of the input image (i.e., targetX = floor ( orderX
 / 2 )).

 Animatable: yes.

[`targetY`] = \"[\<integer\>](https://www.w3.org/TR/css3-values/#integer-value)\"

: Determines the positioning in Y of the convolution matrix relative
 to a given target pixel in the input image. The topmost row of the
 matrix is row number zero. The value must be such that: 0 \<=
 targetY \< orderY. By default, the convolution matrix is centered in
 Y over each pixel of the input image (i.e., targetY = floor ( orderY
 / 2 )).

 Animatable: yes.

[`edgeMode`] = \"[duplicate](#attr-valuedef-edgemode-duplicate) \| [wrap](#attr-valuedef-edgemode-wrap) \| none\"

: Determines how to extend the input image as necessary with color
 values so that the matrix operations can be applied when the kernel
 is positioned at or near the edge of the input image.

 [duplicate] indicates that the input image is extended along
 each of its borders as necessary by duplicating the color values at
 the given edge of the input image.

 Original N-by-M image, where m=M-1 and n=N-1:

 $\begin{bmatrix}
 11 & 12 & {\text\text\text} & {1m} & {1M} \\
 21 & 22 & {\text\text\text} & {2m} & {2M} \\
 {\text\text\text} & {\text\text\text} & {\text\text\text} & {\text\text\text} & {\text\text\text} \\
 {n1} & {n2} & {\text\text\text} & {nm} & {nM} \\
 {N1} & {N2} & {\text\text\text} & {Nm} & {NM}
 \end{bmatrix}$

 Extended by two pixels using [duplicate]:

 $\begin{bmatrix}
 11 & 11 & 11 & 12 & \ldots & {1m} & {1M} & {1M} & {1M} \\
 11 & 11 & 11 & 12 & \ldots & {1m} & {1M} & {1M} & {1M} \\
 11 & 11 & 11 & 12 & \ldots & {1m} & {1M} & {1M} & {1M} \\
 21 & 21 & 21 & 22 & \ldots & {2m} & {2M} & {2M} & {2M} \\
 \ldots & \ldots & \ldots & \ldots & \ldots & \ldots & \ldots & \ldots & \ldots \\
 {n1} & {n1} & {n1} & {n2} & \ldots & {nm} & {nM} & {nM} & {nM} \\
 {N1} & {N1} & {N1} & {N2} & \ldots & {Nm} & {NM} & {NM} & {NM} \\
 {N1} & {N1} & {N1} & {N2} & \ldots & {Nm} & {NM} & {NM} & {NM} \\
 {N1} & {N1} & {N1} & {N2} & \ldots & {Nm} & {NM} & {NM} & {NM}
 \end{bmatrix}$

 [wrap](#attr-valuedef-edgemode-wrap) indicates that the input image is extended
 by taking the color values from the opposite edge of the image.

 Extended by two pixels using
 [wrap](#attr-valuedef-edgemode-wrap):

 $\begin{bmatrix}
 \mathit{nm} & \mathit{nM} & \mathit{n1} & \mathit{n2} & \ldots & \mathit{nm} & \mathit{nM} & \mathit{n1} & \mathit{n2} \\
 \mathit{Nm} & \mathit{NM} & \mathit{N1} & \mathit{N2} & \ldots & \mathit{Nm} & \mathit{NM} & \mathit{N1} & \mathit{N2} \\
 1m & 1M & 11 & 12 & \ldots & 1m & 1M & 11 & 12 \\
 2m & 2M & 21 & 22 & \ldots & 2m & 2M & 21 & 22 \\
 \ldots & \ldots & \ldots & \ldots & \ldots & \ldots & \ldots & \ldots & \ldots \\
 \mathit{nm} & \mathit{nM} & \mathit{n1} & \mathit{n2} & \ldots & \mathit{nm} & \mathit{nM} & \mathit{n1} & \mathit{n2} \\
 \mathit{Nm} & \mathit{NM} & \mathit{N1} & \mathit{N2} & \ldots & \mathit{Nm} & \mathit{NM} & \mathit{N1} & \mathit{N2} \\
 1m & 1M & 11 & 12 & \ldots & 1m & 1M & 11 & 12 \\
 2m & 2M & 21 & 22 & \ldots & 2m & 2M & 21 & 22
 \end{bmatrix}$

 The value [none] indicates that the input image is extended
 with pixel values of zero for R, G, B and A.

 The [initial
 value](https://svgwg.org/svg2-draft/types.html#TermInitialValue) for
 [edgeMode](#element-attrdef-feconvolvematrix-edgemode) is [duplicate].

 Animatable: yes.

[`kernelUnitLength`] = \"*[\<number-optional-number\>](#typedef-number-optional-number)*\"

: The first number is the \<dx\> value. The second number is the
 \<dy\> value. If the \<dy\> value is not specified, it defaults to
 the same value as \<dx\>. Indicates the intended distance in current
 filter units (i.e., units as determined by the value of attribute
 [primitiveUnits](#element-attrdef-filter-primitiveunits)) between successive columns and rows,
 respectively, in the
 [kernelMatrix](#element-attrdef-feconvolvematrix-kernelmatrix). By specifying value(s) for
 [kernelUnitLength](#element-attrdef-feconvolvematrix-kernelunitlength), the kernel becomes defined in a scalable,
 abstract coordinate system. If
 [kernelUnitLength]
 is not specified, the default value is one pixel in the offscreen
 bitmap, which is a pixel-based coordinate system, and thus
 potentially not scalable. For some level of consistency across
 display media and user agents, it is necessary that a value be
 provided for
 [kernelUnitLength].
 In some implementations, the most consistent results and the fastest
 performance will be achieved if the pixel grid of the temporary
 off-screen images aligns with the pixel grid of the kernel.

 If a negative or zero value is specified the default value will be
 used instead.

 Note: This attribute is deprecated and will be removed. It does not
 provide a reliable way to create platform independent results.
 Future versions of this specification will cover this use case.

 Animatable: yes.

[`preserveAlpha`] = \"*false \| true*\"

: A value of
 [false](https://drafts.csswg.org/mediaqueries-5/#valdef-custom-media-false) indicates that the convolution will apply to
 all channels, including the alpha channel. In this case the
 `ALPHA`~`X,Y`~ of the [convolution
 formula](#feConvolveMatrixElementFormula) for a given pixel is:

 ` ALPHA`~`X,Y`~` = ( `\
 `              SUM `~`I=0 to [`[`orderY`](#element-attrdef-order)`-1]`~` { `\
 `                SUM `~`J=0 to [`[`orderX`](#element-attrdef-order)`-1]`~` { `\
 `                  SOURCE `~`X-`[`targetX`](#element-attrdef-feconvolvematrix-targetx)`+J, Y-`[`targetY`](#element-attrdef-feconvolvematrix-targety)`+I`~` *  `[`kernelMatrix`](#element-attrdef-feconvolvematrix-kernelmatrix)~[`orderX`](#element-attrdef-order)`-J-1,  `[`orderY`](#element-attrdef-order)`-I-1`~` `\
 `                } `\
 `              } `\
 `            ) /  `[`divisor`](#element-attrdef-feconvolvematrix-divisor)` +  `[`bias`](#element-attrdef-feconvolvematrix-bias)` `\

 A value of \"true\" indicates that the convolution will only apply
 to the color channels. In this case, the filter will temporarily
 unpremultiply the color component values and apply the kernel. In
 this case the `ALPHA`~`X,Y`~ of the [convolution
 formula](#feConvolveMatrixElementFormula) for a given pixel is:

 `ALPHA`~`X,Y`~` = SOURCE`~`X,Y`~

 The [initial
 value](https://svgwg.org/svg2-draft/types.html#TermInitialValue) for
 [preserveAlpha](#element-attrdef-feconvolvematrix-preservealpha) is
 [false](https://drafts.csswg.org/mediaqueries-5/#valdef-custom-media-false).

 Animatable: yes.

### 9.10. Filter primitive [feDiffuseLighting]
Name:

[`feDiffuseLighting`]

Categories:

[filter primitive](#filter-primitive)

Content model:

Any number of [descriptive
elements](https://www.w3.org/TR/svg2/struct.html#TermDescriptiveElement),
[script](https://www.w3.org/TR/svg2/interact.html#elementdef-script) and exactly one [light
sources](#light-source) element,
in any order.

Attributes:

- [core
 attributes](https://www.w3.org/TR/2011/REC-SVG11-20110816/intro.html#TermCoreAttributes)[
 ---
 [[id]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#IDAttribute),
 [[xml:base]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#XMLBaseAttribute),
 [[xml:lang]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#XMLLangAttribute),
 [[xml:space]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#XMLSpaceAttribute)]
- [presentation
 attributes](https://www.w3.org/TR/2008/REC-SVGTiny12-20081222/intro.html#TermPresentationAttribute)[
 ---
 [alignment-baseline](https://www.w3.org/TR/SVG11/text.html#AlignmentBaselineProperty),
 [baseline-shift](https://www.w3.org/TR/SVG11/text.html#BaselineShiftProperty),
 [clip](https://www.w3.org/TR/css-masking-1/#propdef-clip),
 [clip-path](https://www.w3.org/TR/css-masking-1/#propdef-clip-path),
 [clip-rule](https://www.w3.org/TR/css-masking-1/#propdef-clip-rule),
 [color](https://www.w3.org/TR/css3-color/#color0),
 [color-interpolation](https://www.w3.org/TR/svg2/painting.html#ColorInterpolationProperty),
 [color-interpolation-filters](#propdef-color-interpolation-filters),
 [color-rendering](https://www.w3.org/TR/svg2/painting.html#ColorRenderingProperty),
 [cursor](https://www.w3.org/TR/css3-ui/#propdef-cursor),
 [direction](https://www.w3.org/TR/css-writing-modes-3/#propdef-direction),
 [display](https://www.w3.org/TR/css-display-3/#propdef-display),
 [dominant-baseline](https://www.w3.org/TR/SVG11/text.html#DominantBaselineProperty),
 [enable-background](https://www.w3.org/TR/SVG11/filters.html#EnableBackgroundProperty),
 [fill](https://www.w3.org/TR/svg2/painting.html#FillProperty),
 [fill-opacity](https://www.w3.org/TR/svg2/painting.html#FillOpacityProperty),
 [fill-rule](https://www.w3.org/TR/svg2/painting.html#FillRuleProperty),
 [filter](#propdef-filter),
 [flood-color](#propdef-flood-color),
 [flood-opacity](#propdef-flood-opacity),
 [font](https://www.w3.org/TR/css-fonts-3/#propdef-font),
 [font-family](https://www.w3.org/TR/css-fonts-3/#propdef-font-family),
 [font-size](https://www.w3.org/TR/css-fonts-3/#propdef-font-size),
 [font-size-adjust](https://www.w3.org/TR/css-fonts-4/#propdef-font-size-adjust),
 [font-stretch](https://www.w3.org/TR/css-fonts-3/#propdef-font-stretch),
 [font-style](https://www.w3.org/TR/css-fonts-3/#propdef-font-style),
 [font-variant](https://www.w3.org/TR/css-fonts-3/#propdef-font-variant),
 [font-weight](https://www.w3.org/TR/css-fonts-3/#propdef-font-weight),
 [glyph-orientation-horizontal](https://www.w3.org/TR/SVG11/text.html#GlyphOrientationHorizontalProperty),
 [glyph-orientation-vertical](https://www.w3.org/TR/SVG11/text.html#GlyphOrientationVerticalProperty),
 [image-rendering](https://drafts.csswg.org/css-images-3/#propdef-image-rendering),
 [isolation](https://www.w3.org/TR/compositing-1/#propdef-isolation),
 [kerning](https://www.w3.org/TR/SVG11/text.html#KerningProperty),
 [letter-spacing](https://www.w3.org/TR/css-text-3/#propdef-letter-spacing),
 [lighting-color](#propdef-lighting-color),
 [marker](https://www.w3.org/TR/svg2/painting.html#MarkerProperty),
 [marker-end](https://www.w3.org/TR/svg2/painting.html#MarkerEndProperty),
 [marker-mid](https://www.w3.org/TR/svg2/painting.html#MarkerMidProperty),
 [marker-start](https://www.w3.org/TR/svg2/painting.html#MarkerStartProperty),
 [mask](https://www.w3.org/TR/css-masking-1/#propdef-mask),
 [opacity](https://www.w3.org/TR/css-color-4/#propdef-opacity),
 [overflow](https://www.w3.org/TR/css-overflow-3/#propdef-overflow),
 [pointer-events](https://www.w3.org/TR/svg2/interact.html#PointerEventsProperty),
 [shape-rendering](https://www.w3.org/TR/svg2/painting.html#ShapeRenderingProperty),
 [stop-color](https://www.w3.org/TR/svg2/pservers.html#StopColorProperty),
 [stop-opacity](https://www.w3.org/TR/svg2/pservers.html#StopOpacityProperty),
 [stroke](https://www.w3.org/TR/svg2/painting.html#StrokeProperty),
 [stroke-dasharray](https://www.w3.org/TR/svg2/painting.html#StrokeDasharrayProperty),
 [stroke-dashoffset](https://www.w3.org/TR/svg2/painting.html#StrokeDashoffsetProperty),
 [stroke-linecap](https://www.w3.org/TR/svg2/painting.html#StrokeLinecapProperty),
 [stroke-linejoin](https://www.w3.org/TR/svg2/painting.html#StrokeLinejoinProperty),
 [stroke-miterlimit](https://www.w3.org/TR/svg2/painting.html#StrokeMiterlimitProperty),
 [stroke-opacity](https://www.w3.org/TR/svg2/painting.html#StrokeOpacityProperty),
 [stroke-width](https://www.w3.org/TR/svg2/painting.html#StrokeWidthProperty),
 [text-anchor](https://www.w3.org/TR/svg2/text.html#TextAnchorProperty),
 [text-decoration](https://www.w3.org/TR/css-text-decor-3/#propdef-text-decoration),
 [text-rendering](https://www.w3.org/TR/svg2/painting.html#TextRenderingProperty),
 [unicode-bidi](https://www.w3.org/TR/css-writing-modes-3/#propdef-unicode-bidi),
 [visibility](https://www.w3.org/TR/CSS21/visufx.html#propdef-visibility),
 [word-spacing](https://www.w3.org/TR/css-text-3/#propdef-word-spacing),
 [writing-mode](https://www.w3.org/TR/css-writing-modes-4/#propdef-writing-mode)]
- [filter primitive
 attributes](#filter-primitive-attributes)
 [
 ---[x](#element-attrdef-filter-primitive-x),
 [y](#element-attrdef-filter-primitive-y),
 [width](#element-attrdef-filter-primitive-width),
 [height](#element-attrdef-filter-primitive-height),
 [result](#element-attrdef-filter-primitive-result) ]
- [[class]](https://www.w3.org/TR/2011/REC-SVG11-20110816/styling.html#ClassAttribute)
- [[style]](https://www.w3.org/TR/2011/REC-SVG11-20110816/styling.html#StyleAttribute)
- [in](#element-attrdef-filter-primitive-in)
- [surfaceScale](#element-attrdef-fediffuselighting-surfacescale)
- [diffuseConstant](#element-attrdef-fediffuselighting-diffuseconstant)
- [kernelUnitLength](#element-attrdef-fediffuselighting-kernelunitlength)

DOM Interfaces:

[SVGFEDiffuseLightingElement](#InterfaceSVGFEDiffuseLightingElement)

This filter primitive lights an image using the alpha channel as a bump
map. The resulting image is an RGBA opaque image based on the light
color with alpha = 1.0 everywhere. The lighting calculation follows the
standard diffuse component of the Phong lighting model. The resulting
image depends on the light color, light position and surface geometry of
the input bump map.

The light map produced by this filter primitive can be combined with a
texture image using the multiply term of the *arithmetic*
[feComposite](#elementdef-fecomposite) compositing method. Multiple [light
sources](#light-source) can be
simulated by adding several of these light maps together before applying
it to the texture image.

The formulas below make use of 3x3 filters. Because they operate on
pixels, such filters are inherently resolution-dependent. To make
[feDiffuseLighting](#elementdef-fediffuselighting) produce resolution-independent results, an explicit
value should be provided for the attribute
[kernelUnitLength](#element-attrdef-fediffuselighting-kernelunitlength).

[kernelUnitLength](#element-attrdef-fediffuselighting-kernelunitlength), in combination with the other attributes,
defines an implicit pixel grid in the filter effects coordinate system
(i.e., the coordinate system established by the
[primitiveUnits](#element-attrdef-filter-primitiveunits) attribute). The input image will be
temporarily rescaled to match its pixels with
[kernelUnitLength].
The 3x3 filters are applied to the resampled image. After applying the
filter, the image is resampled back to its original resolution.

Note: Depending on the speed of the available interpolates, this choice
may be affected by the
[image-rendering](https://drafts.csswg.org/css-images-3/#propdef-image-rendering) property setting.

Note: Implementations might choose approaches that minimize or eliminate
resampling when not necessary to produce proper results, such as when
the document is zoomed out such that
[kernelUnitLength](#element-attrdef-fediffuselighting-kernelunitlength) is considerably smaller than a device pixel.

For the formulas that follow, the `Norm(A`~`x`~`,A`~`y`~`,A`~`z`~`)`
function is defined as:

$\mathit{Norm}{{({A_{x},A_{y},A_{z}})} = \sqrt{{A_{x}^{2} + A_{y}^{2}} + A_{z}^{2}}}$

Note: User agents may use the the \"fast inverse square root\" to
optimize the equation and avoid time differences on extrema color
values. See [Privacy and Security Considerations](#priv-sec) section for
more details about timing attacks.

The resulting RGBA image is computed as follows:

` D`~`r`~` = k`~`d`~` * N.L * L`~`r`~\
`D`~`g`~` = k`~`d`~` * N.L * L`~`g`~\
`D`~`b`~` = k`~`d`~` * N.L * L`~`b`~\
`D`~`a`~` = 1.0 `

where

k~d~ = diffuse lighting constant\
N = surface normal unit vector, a function of x and y\
L = unit vector pointing from surface to light, a function of x and y in
the point and spot light cases\
L~r~,L~g~,L~b~ = RGB components of light, a function of x and y in the
spot light case

N is a function of x and y and depends on the surface gradient as
follows:

The surface described by the input alpha image I(x,y) is:

`Z (x,y) = surfaceScale * I(x,y)`

Surface normal is calculated using the Sobel gradient 3x3 filter.
Different filter kernels are used depending on whether the given pixel
is on the interior or an edge. For each case, the formula is:

` N`~`x`~` (x,y) = - surfaceScale * FACTOR`~`x`~` *`\
`           (K`~`x`~`(0,0)*I(x-dx,y-dy) + K`~`x`~`(1,0)*I(x,y-dy) + K`~`x`~`(2,0)*I(x+dx,y-dy) +`\
`            K`~`x`~`(0,1)*I(x-dx,y)    + K`~`x`~`(1,1)*I(x,y)    + K`~`x`~`(2,1)*I(x+dx,y)    +`\
`            K`~`x`~`(0,2)*I(x-dx,y+dy) + K`~`x`~`(1,2)*I(x,y+dy) + K`~`x`~`(2,2)*I(x+dx,y+dy))`\
`N`~`y`~` (x,y) = - surfaceScale * FACTOR`~`y`~` *`\
`           (K`~`y`~`(0,0)*I(x-dx,y-dy) + K`~`y`~`(1,0)*I(x,y-dy) + K`~`y`~`(2,0)*I(x+dx,y-dy) +`\
`            K`~`y`~`(0,1)*I(x-dx,y)    + K`~`y`~`(1,1)*I(x,y)    + K`~`y`~`(2,1)*I(x+dx,y)    +`\
`            K`~`y`~`(0,2)*I(x-dx,y+dy) + K`~`y`~`(1,2)*I(x,y+dy) + K`~`y`~`(2,2)*I(x+dx,y+dy))`\
`N`~`z`~` (x,y) = 1.0`\
\
`N = (N`~`x`~`, N`~`y`~`, N`~`z`~`) / Norm((N`~`x`~`,N`~`y`~`,N`~`z`~`)) `

In these formulas, the `dx` and `dy` values (e.g., `I(x-dx,y-dy)`),
represent deltas relative to a given `(x,y)` position for the purpose of
estimating the slope of the surface at that point. These deltas are
determined by the value (explicit or implicit) of attribute
[kernelUnitLength](#element-attrdef-fediffuselighting-kernelunitlength).

Top/left corner:

Top row:

Top/right corner:

FACTOR~x~=2/(3\*dx)\
K~x~ =\
    \|  0  0  0 \|\
    \|  0 -2  2 \|\
    \|  0 -1  1 \|\
\
FACTOR~y~=2/(3\*dy)\
K~y~ =  \
    \|  0  0  0 \|\
    \|  0 -2 -1 \|\
    \|  0  2  1 \|

FACTOR~x~=1/(3\*dx)\
K~x~ =\
    \|  0  0  0 \|\
    \| -2  0  2 \|\
    \| -1  0  1 \|\
\
FACTOR~y~=1/(2\*dy)\
K~y~ =  \
    \|  0  0  0 \|\
    \| -1 -2 -1 \|\
    \|  1  2  1 \|

FACTOR~x~=2/(3\*dx)\
K~x~ =\
    \|  0  0  0 \|\
    \| -2  2  0 \|\
    \| -1  1  0 \|\
\
FACTOR~y~=2/(3\*dy)\
K~y~ =  \
    \|  0  0  0 \|\
    \| -1 -2  0 \|\
    \|  1  2  0 \|

Left column:

Interior pixels:

Right column:

FACTOR~x~=1/(2\*dx)\
K~x~ =\
    \| 0 -1  1 \|\
    \| 0 -2  2 \|\
    \| 0 -1  1 \|\
\
FACTOR~y~=1/(3\*dy)\
K~y~ =  \
    \|  0 -2 -1 \|\
    \|  0  0  0 \|\
    \|  0  2  1 \|

FACTOR~x~=1/(4\*dx)\
K~x~ =\
    \| -1  0  1 \|\
    \| -2  0  2 \|\
    \| -1  0  1 \|\
\
FACTOR~y~=1/(4\*dy)\
K~y~ =  \
    \| -1 -2 -1 \|\
    \|  0  0  0 \|\
    \|  1  2  1 \|

FACTOR~x~=1/(2\*dx)\
K~x~ =\
    \| -1  1  0\|\
    \| -2  2  0\|\
    \| -1  1  0\|\
\
FACTOR~y~=1/(3\*dy)\
K~y~ =  \
    \| -1 -2  0 \|\
    \|  0  0  0 \|\
    \|  1  2  0 \|

Bottom/left corner:

Bottom row:

Bottom/right corner:

FACTOR~x~=2/(3\*dx)\
K~x~ =\
    \| 0 -1  1 \|\
    \| 0 -2  2 \|\
    \| 0  0  0 \|\
\
FACTOR~y~=2/(3\*dy)\
K~y~ =  \
    \|  0 -2 -1 \|\
    \|  0  2  1 \|\
    \|  0  0  0 \|

FACTOR~x~=1/(3\*dx)\
K~x~ =\
    \| -1  0  1 \|\
    \| -2  0  2 \|\
    \|  0  0  0 \|\
\
FACTOR~y~=1/(2\*dy)\
K~y~ =  \
    \| -1 -2 -1 \|\
    \|  1  2  1 \|\
    \|  0  0  0 \|

FACTOR~x~=2/(3\*dx)\
K~x~ =\
    \| -1  1  0 \|\
    \| -2  2  0 \|\
    \|  0  0  0 \|\
\
FACTOR~y~=2/(3\*dy)\
K~y~ =  \
    \| -1 -2  0 \|\
    \|  1  2  0 \|\
    \|  0  0  0 \|

L, the unit vector from the image sample to the light, is calculated as
follows:

For Infinite [light sources](#light-source) it is constant:

` L`~`x`~` = cos(azimuth)*cos(elevation)`\
`L`~`y`~` = sin(azimuth)*cos(elevation)`\
`L`~`z`~` = sin(elevation) `

For Point and spot lights it is a function of position:

` L`~`x`~` = Light`~`x`~` - x`\
`L`~`y`~` = Light`~`y`~` - y`\
`L`~`z`~` = Light`~`z`~` - Z(x,y)`\
\
`L = (L`~`x`~`, L`~`y`~`, L`~`z`~`) / Norm(L`~`x`~`, L`~`y`~`, L`~`z`~`) `

where Light~x~, Light~y~, and Light~z~ are the input light position.

L~r~,L~g~,L~b~, the light color vector, is a function of position in the
spot light case only:

` L`~`r`~` = Light`~`r`~`*pow((-L.S),specularExponent)`\
`L`~`g`~` = Light`~`g`~`*pow((-L.S),specularExponent)`\
`L`~`b`~` = Light`~`b`~`*pow((-L.S),specularExponent) `

where S is the unit vector pointing from the light to the point
(pointsAtX, pointsAtY, pointsAtZ) in the x-y plane:

` S`~`x`~` = pointsAtX - Light`~`x`~\
`S`~`y`~` = pointsAtY - Light`~`y`~\
`S`~`z`~` = pointsAtZ - Light`~`z`~\
\
`S = (S`~`x`~`, S`~`y`~`, S`~`z`~`) / Norm(S`~`x`~`, S`~`y`~`, S`~`z`~`) `

If L.S is positive, no light is present. (L~r~ = L~g~ = L~b~ = 0). If
[limitingConeAngle](#element-attrdef-fespotlight-limitingconeangle) is specified, -L.S \< cos(limitingConeAngle)
also indicates that no light is present.

*Attribute definitions:*

[`surfaceScale`] = \"*[\<number\>](https://www.w3.org/TR/css3-values/#number-value)*\"

: height of surface when A~in~ = 1.

 If the attribute is not specified, then the effect is as if a value
 of [1] were specified.

 Animatable: yes.

[`diffuseConstant`] = \"*[\<number\>](https://www.w3.org/TR/css3-values/#number-value)*\"

: kd in Phong lighting model. In SVG, this can be any non-negative
 number.

 If the attribute is not specified, then the effect is as if a value
 of [1] were specified.

 Animatable: yes.

[`kernelUnitLength`] = \"*[\<number-optional-number\>](#typedef-number-optional-number)*\"

: The first number is the \<dx\> value. The second number is the
 \<dy\> value. If the \<dy\> value is not specified, it defaults to
 the same value as \<dx\>. Indicates the intended distance in current
 filter units (i.e., units as determined by the value of attribute
 [primitiveUnits](#element-attrdef-filter-primitiveunits)) for `dx` and `dy`, respectively, in the
 [surface normal calculation formulas](#SurfaceNormalCalculations).
 By specifying value(s) for
 [kernelUnitLength](#element-attrdef-fediffuselighting-kernelunitlength), the kernel becomes defined in a scalable,
 abstract coordinate system. If
 [kernelUnitLength]
 is not specified, the `dx` and `dy` values should represent very
 small deltas relative to a given `(x,y)` position, which might be
 implemented in some cases as one pixel in the intermediate image
 offscreen bitmap, which is a pixel-based coordinate system, and thus
 potentially not scalable. For some level of consistency across
 display media and user agents, it is necessary that a value be
 provided for
 [kernelUnitLength].

 If a negative or zero value is specified the default value will be
 used instead.

 Note: This attribute is deprecated and will be removed. It does not
 provide a reliable way to create platform independent results.
 Future versions of this specification will cover this use case.

 Animatable: yes.

The [light source](#light-source) is defined by one of the child elements
[feDistantLight](#elementdef-fedistantlight),
[fePointLight](#elementdef-fepointlight) or
[feSpotLight](#elementdef-fespotlight). The light color is specified by property
[lighting-color](#propdef-lighting-color).

### 9.11. Filter primitive [feDisplacementMap]
Name:

[`feDisplacementMap`]

Categories:

[filter primitive](#filter-primitive)

Content model:

Any number of [descriptive
elements](https://www.w3.org/TR/svg2/struct.html#TermDescriptiveElement),
[animate](https://www.w3.org/TR/SVG11/animate.html#AnimateElement),
[script](https://www.w3.org/TR/svg2/interact.html#elementdef-script),
[set](https://www.w3.org/TR/SVG11/animate.html#SetElement) elements, in any order.

Attributes:

- [core
 attributes](https://www.w3.org/TR/2011/REC-SVG11-20110816/intro.html#TermCoreAttributes)[
 ---
 [[id]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#IDAttribute),
 [[xml:base]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#XMLBaseAttribute),
 [[xml:lang]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#XMLLangAttribute),
 [[xml:space]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#XMLSpaceAttribute)]
- [presentation
 attributes](https://www.w3.org/TR/2008/REC-SVGTiny12-20081222/intro.html#TermPresentationAttribute)[
 ---
 [alignment-baseline](https://www.w3.org/TR/SVG11/text.html#AlignmentBaselineProperty),
 [baseline-shift](https://www.w3.org/TR/SVG11/text.html#BaselineShiftProperty),
 [clip](https://www.w3.org/TR/css-masking-1/#propdef-clip),
 [clip-path](https://www.w3.org/TR/css-masking-1/#propdef-clip-path),
 [clip-rule](https://www.w3.org/TR/css-masking-1/#propdef-clip-rule),
 [color](https://www.w3.org/TR/css3-color/#color0),
 [color-interpolation](https://www.w3.org/TR/svg2/painting.html#ColorInterpolationProperty),
 [color-interpolation-filters](#propdef-color-interpolation-filters),
 [color-rendering](https://www.w3.org/TR/svg2/painting.html#ColorRenderingProperty),
 [cursor](https://www.w3.org/TR/css3-ui/#propdef-cursor),
 [direction](https://www.w3.org/TR/css-writing-modes-3/#propdef-direction),
 [display](https://www.w3.org/TR/css-display-3/#propdef-display),
 [dominant-baseline](https://www.w3.org/TR/SVG11/text.html#DominantBaselineProperty),
 [enable-background](https://www.w3.org/TR/SVG11/filters.html#EnableBackgroundProperty),
 [fill](https://www.w3.org/TR/svg2/painting.html#FillProperty),
 [fill-opacity](https://www.w3.org/TR/svg2/painting.html#FillOpacityProperty),
 [fill-rule](https://www.w3.org/TR/svg2/painting.html#FillRuleProperty),
 [filter](#propdef-filter),
 [flood-color](#propdef-flood-color),
 [flood-opacity](#propdef-flood-opacity),
 [font](https://www.w3.org/TR/css-fonts-3/#propdef-font),
 [font-family](https://www.w3.org/TR/css-fonts-3/#propdef-font-family),
 [font-size](https://www.w3.org/TR/css-fonts-3/#propdef-font-size),
 [font-size-adjust](https://www.w3.org/TR/css-fonts-4/#propdef-font-size-adjust),
 [font-stretch](https://www.w3.org/TR/css-fonts-3/#propdef-font-stretch),
 [font-style](https://www.w3.org/TR/css-fonts-3/#propdef-font-style),
 [font-variant](https://www.w3.org/TR/css-fonts-3/#propdef-font-variant),
 [font-weight](https://www.w3.org/TR/css-fonts-3/#propdef-font-weight),
 [glyph-orientation-horizontal](https://www.w3.org/TR/SVG11/text.html#GlyphOrientationHorizontalProperty),
 [glyph-orientation-vertical](https://www.w3.org/TR/SVG11/text.html#GlyphOrientationVerticalProperty),
 [image-rendering](https://drafts.csswg.org/css-images-3/#propdef-image-rendering),
 [isolation](https://www.w3.org/TR/compositing-1/#propdef-isolation),
 [kerning](https://www.w3.org/TR/SVG11/text.html#KerningProperty),
 [letter-spacing](https://www.w3.org/TR/css-text-3/#propdef-letter-spacing),
 [lighting-color](#propdef-lighting-color),
 [marker](https://www.w3.org/TR/svg2/painting.html#MarkerProperty),
 [marker-end](https://www.w3.org/TR/svg2/painting.html#MarkerEndProperty),
 [marker-mid](https://www.w3.org/TR/svg2/painting.html#MarkerMidProperty),
 [marker-start](https://www.w3.org/TR/svg2/painting.html#MarkerStartProperty),
 [mask](https://www.w3.org/TR/css-masking-1/#propdef-mask),
 [opacity](https://www.w3.org/TR/css-color-4/#propdef-opacity),
 [overflow](https://www.w3.org/TR/css-overflow-3/#propdef-overflow),
 [pointer-events](https://www.w3.org/TR/svg2/interact.html#PointerEventsProperty),
 [shape-rendering](https://www.w3.org/TR/svg2/painting.html#ShapeRenderingProperty),
 [stop-color](https://www.w3.org/TR/svg2/pservers.html#StopColorProperty),
 [stop-opacity](https://www.w3.org/TR/svg2/pservers.html#StopOpacityProperty),
 [stroke](https://www.w3.org/TR/svg2/painting.html#StrokeProperty),
 [stroke-dasharray](https://www.w3.org/TR/svg2/painting.html#StrokeDasharrayProperty),
 [stroke-dashoffset](https://www.w3.org/TR/svg2/painting.html#StrokeDashoffsetProperty),
 [stroke-linecap](https://www.w3.org/TR/svg2/painting.html#StrokeLinecapProperty),
 [stroke-linejoin](https://www.w3.org/TR/svg2/painting.html#StrokeLinejoinProperty),
 [stroke-miterlimit](https://www.w3.org/TR/svg2/painting.html#StrokeMiterlimitProperty),
 [stroke-opacity](https://www.w3.org/TR/svg2/painting.html#StrokeOpacityProperty),
 [stroke-width](https://www.w3.org/TR/svg2/painting.html#StrokeWidthProperty),
 [text-anchor](https://www.w3.org/TR/svg2/text.html#TextAnchorProperty),
 [text-decoration](https://www.w3.org/TR/css-text-decor-3/#propdef-text-decoration),
 [text-rendering](https://www.w3.org/TR/svg2/painting.html#TextRenderingProperty),
 [unicode-bidi](https://www.w3.org/TR/css-writing-modes-3/#propdef-unicode-bidi),
 [visibility](https://www.w3.org/TR/CSS21/visufx.html#propdef-visibility),
 [word-spacing](https://www.w3.org/TR/css-text-3/#propdef-word-spacing),
 [writing-mode](https://www.w3.org/TR/css-writing-modes-4/#propdef-writing-mode)]
- [filter primitive
 attributes](#filter-primitive-attributes)
 [
 ---[x](#element-attrdef-filter-primitive-x),
 [y](#element-attrdef-filter-primitive-y),
 [width](#element-attrdef-filter-primitive-width),
 [height](#element-attrdef-filter-primitive-height),
 [result](#element-attrdef-filter-primitive-result) ]
- [[class]](https://www.w3.org/TR/2011/REC-SVG11-20110816/styling.html#ClassAttribute)
- [[style]](https://www.w3.org/TR/2011/REC-SVG11-20110816/styling.html#StyleAttribute)
- [in](#element-attrdef-filter-primitive-in)
- [in2](#element-attrdef-fedisplacementmap-in2)
- [scale](#element-attrdef-fedisplacementmap-scale)
- [xChannelSelector](#element-attrdef-fedisplacementmap-xchannelselector)
- [yChannelSelector](#element-attrdef-fedisplacementmap-ychannelselector)

DOM Interfaces:

[SVGFEDisplacementMapElement](#InterfaceSVGFEDisplacementMapElement)

Implementations do not match
specification.
[\<https://github.com/w3c/csswg-drafts/issues/113\>](https://github.com/w3c/csswg-drafts/issues/113)

This filter primitive uses the pixels values from the image from
[in2](#element-attrdef-fedisplacementmap-in2) to spatially displace the image from
[in](#element-attrdef-filter-primitive-in). This is the transformation to be performed:

 P'(x,y) ← P( x + scale * (XC(x,y) - .5), y + scale * (YC(x,y) - .5))

where P(x,y) is the input image,
[in](#element-attrdef-filter-primitive-in), and P\'(x,y) is the destination. XC(x,y) and
YC(x,y) are the component values of the channel designated by the
[xChannelSelector](#element-attrdef-fedisplacementmap-xchannelselector) and
[yChannelSelector](#element-attrdef-fedisplacementmap-ychannelselector). For example, to use the R component of
[in2](#element-attrdef-fedisplacementmap-in2) to control displacement in x and the G
component of Image2 to control displacement in y, set
[xChannelSelector]
to \"R\" and
[yChannelSelector]
to \"G\".

The displacement map,
[in2](#element-attrdef-fedisplacementmap-in2), defines the inverse of the mapping performed.

The input image
[in](#element-attrdef-filter-primitive-in) is to remain premultiplied for this filter
primitive. The calculations using the pixel values from
[in2](#element-attrdef-fedisplacementmap-in2) are performed using non-premultiplied color
values.

This filter can have arbitrary non-localized effect on the input which
might require substantial buffering in the processing pipeline. However
with this formulation, any intermediate buffering needs can be
determined by
[scale](#element-attrdef-fedisplacementmap-scale) which represents the maximum range of
displacement in either x or y.

When applying this filter, the source pixel location will often lie
between several source pixels.

Note: Depending on the speed of the available interpolents, this choice
may be affected by the
[image-rendering](https://drafts.csswg.org/css-images-3/#propdef-image-rendering) property setting.

Note: A future version of this spec will define the interpolation method
to be used when distorting the source image making UAs rendering result
more interoperable.

The
[color-interpolation-filters](#propdef-color-interpolation-filters) property only applies to the
[in2](#element-attrdef-fedisplacementmap-in2) source image and does not apply to the
[in](#element-attrdef-filter-primitive-in) source image. The
[in] source image must
remain in its current color space.

*Attribute definitions:*

[`scale`] = \"*[\<number\>](https://www.w3.org/TR/css3-values/#number-value)*\"

: Displacement scale factor. The amount is expressed in the coordinate
 system established by attribute
 [primitiveUnits](#element-attrdef-filter-primitiveunits) on the
 [filter](#elementdef-filter) element.

 When the value of this attribute is [0], this operation has no
 effect on the source image.

 The [initial
 value](https://svgwg.org/svg2-draft/types.html#TermInitialValue) for
 [scale](#element-attrdef-fedisplacementmap-scale) is [0].

 Animatable: yes.

[`xChannelSelector`] = \"*R \| G \| B \| A*\"

: Indicates which channel from
 [in2](#element-attrdef-fedisplacementmap-in2) to use to displace the pixels in
 [in](#element-attrdef-filter-primitive-in) along the x-axis.

 The [initial
 value](https://svgwg.org/svg2-draft/types.html#TermInitialValue) for
 [xChannelSelector](#element-attrdef-fedisplacementmap-xchannelselector) is [A].

 Animatable: yes.

[`yChannelSelector`] = \"*R \| G \| B \| A*\"

: Indicates which channel from
 [in2](#element-attrdef-fedisplacementmap-in2) to use to displace the pixels in
 [in](#element-attrdef-filter-primitive-in) along the y-axis.

 The [initial
 value](https://svgwg.org/svg2-draft/types.html#TermInitialValue) for
 [yChannelSelector](#element-attrdef-fedisplacementmap-ychannelselector) is [A].

 Animatable: yes.

[`in2`] = \"*(see [in](#element-attrdef-filter-primitive-in) attribute)*\"

: The second input image, which is used to displace the pixels in the
 image from attribute
 [in](#element-attrdef-filter-primitive-in). See defintion for
 [in] attribute.

 Animatable: yes.

### 9.12. Filter primitive [feDropShadow]
Name:

[`feDropShadow`]

Categories:

[filter primitive](#filter-primitive)

Content model:

Any number of [descriptive
elements](https://www.w3.org/TR/svg2/struct.html#TermDescriptiveElement),
[animate](https://www.w3.org/TR/SVG11/animate.html#AnimateElement),
[script](https://www.w3.org/TR/svg2/interact.html#elementdef-script),
[set](https://www.w3.org/TR/SVG11/animate.html#SetElement) elements, in any order.

Attributes:

- [core
 attributes](https://www.w3.org/TR/2011/REC-SVG11-20110816/intro.html#TermCoreAttributes)[
 ---
 [[id]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#IDAttribute),
 [[xml:base]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#XMLBaseAttribute),
 [[xml:lang]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#XMLLangAttribute),
 [[xml:space]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#XMLSpaceAttribute)]
- [presentation
 attributes](https://www.w3.org/TR/2008/REC-SVGTiny12-20081222/intro.html#TermPresentationAttribute)[
 ---
 [alignment-baseline](https://www.w3.org/TR/SVG11/text.html#AlignmentBaselineProperty),
 [baseline-shift](https://www.w3.org/TR/SVG11/text.html#BaselineShiftProperty),
 [clip](https://www.w3.org/TR/css-masking-1/#propdef-clip),
 [clip-path](https://www.w3.org/TR/css-masking-1/#propdef-clip-path),
 [clip-rule](https://www.w3.org/TR/css-masking-1/#propdef-clip-rule),
 [color](https://www.w3.org/TR/css3-color/#color0),
 [color-interpolation](https://www.w3.org/TR/svg2/painting.html#ColorInterpolationProperty),
 [color-interpolation-filters](#propdef-color-interpolation-filters),
 [color-rendering](https://www.w3.org/TR/svg2/painting.html#ColorRenderingProperty),
 [cursor](https://www.w3.org/TR/css3-ui/#propdef-cursor),
 [direction](https://www.w3.org/TR/css-writing-modes-3/#propdef-direction),
 [display](https://www.w3.org/TR/css-display-3/#propdef-display),
 [dominant-baseline](https://www.w3.org/TR/SVG11/text.html#DominantBaselineProperty),
 [enable-background](https://www.w3.org/TR/SVG11/filters.html#EnableBackgroundProperty),
 [fill](https://www.w3.org/TR/svg2/painting.html#FillProperty),
 [fill-opacity](https://www.w3.org/TR/svg2/painting.html#FillOpacityProperty),
 [fill-rule](https://www.w3.org/TR/svg2/painting.html#FillRuleProperty),
 [filter](#propdef-filter),
 [flood-color](#propdef-flood-color),
 [flood-opacity](#propdef-flood-opacity),
 [font](https://www.w3.org/TR/css-fonts-3/#propdef-font),
 [font-family](https://www.w3.org/TR/css-fonts-3/#propdef-font-family),
 [font-size](https://www.w3.org/TR/css-fonts-3/#propdef-font-size),
 [font-size-adjust](https://www.w3.org/TR/css-fonts-4/#propdef-font-size-adjust),
 [font-stretch](https://www.w3.org/TR/css-fonts-3/#propdef-font-stretch),
 [font-style](https://www.w3.org/TR/css-fonts-3/#propdef-font-style),
 [font-variant](https://www.w3.org/TR/css-fonts-3/#propdef-font-variant),
 [font-weight](https://www.w3.org/TR/css-fonts-3/#propdef-font-weight),
 [glyph-orientation-horizontal](https://www.w3.org/TR/SVG11/text.html#GlyphOrientationHorizontalProperty),
 [glyph-orientation-vertical](https://www.w3.org/TR/SVG11/text.html#GlyphOrientationVerticalProperty),
 [image-rendering](https://drafts.csswg.org/css-images-3/#propdef-image-rendering),
 [isolation](https://www.w3.org/TR/compositing-1/#propdef-isolation),
 [kerning](https://www.w3.org/TR/SVG11/text.html#KerningProperty),
 [letter-spacing](https://www.w3.org/TR/css-text-3/#propdef-letter-spacing),
 [lighting-color](#propdef-lighting-color),
 [marker](https://www.w3.org/TR/svg2/painting.html#MarkerProperty),
 [marker-end](https://www.w3.org/TR/svg2/painting.html#MarkerEndProperty),
 [marker-mid](https://www.w3.org/TR/svg2/painting.html#MarkerMidProperty),
 [marker-start](https://www.w3.org/TR/svg2/painting.html#MarkerStartProperty),
 [mask](https://www.w3.org/TR/css-masking-1/#propdef-mask),
 [opacity](https://www.w3.org/TR/css-color-4/#propdef-opacity),
 [overflow](https://www.w3.org/TR/css-overflow-3/#propdef-overflow),
 [pointer-events](https://www.w3.org/TR/svg2/interact.html#PointerEventsProperty),
 [shape-rendering](https://www.w3.org/TR/svg2/painting.html#ShapeRenderingProperty),
 [stop-color](https://www.w3.org/TR/svg2/pservers.html#StopColorProperty),
 [stop-opacity](https://www.w3.org/TR/svg2/pservers.html#StopOpacityProperty),
 [stroke](https://www.w3.org/TR/svg2/painting.html#StrokeProperty),
 [stroke-dasharray](https://www.w3.org/TR/svg2/painting.html#StrokeDasharrayProperty),
 [stroke-dashoffset](https://www.w3.org/TR/svg2/painting.html#StrokeDashoffsetProperty),
 [stroke-linecap](https://www.w3.org/TR/svg2/painting.html#StrokeLinecapProperty),
 [stroke-linejoin](https://www.w3.org/TR/svg2/painting.html#StrokeLinejoinProperty),
 [stroke-miterlimit](https://www.w3.org/TR/svg2/painting.html#StrokeMiterlimitProperty),
 [stroke-opacity](https://www.w3.org/TR/svg2/painting.html#StrokeOpacityProperty),
 [stroke-width](https://www.w3.org/TR/svg2/painting.html#StrokeWidthProperty),
 [text-anchor](https://www.w3.org/TR/svg2/text.html#TextAnchorProperty),
 [text-decoration](https://www.w3.org/TR/css-text-decor-3/#propdef-text-decoration),
 [text-rendering](https://www.w3.org/TR/svg2/painting.html#TextRenderingProperty),
 [unicode-bidi](https://www.w3.org/TR/css-writing-modes-3/#propdef-unicode-bidi),
 [visibility](https://www.w3.org/TR/CSS21/visufx.html#propdef-visibility),
 [word-spacing](https://www.w3.org/TR/css-text-3/#propdef-word-spacing),
 [writing-mode](https://www.w3.org/TR/css-writing-modes-4/#propdef-writing-mode)]
- [filter primitive
 attributes](#filter-primitive-attributes)
 [
 ---[x](#element-attrdef-filter-primitive-x),
 [y](#element-attrdef-filter-primitive-y),
 [width](#element-attrdef-filter-primitive-width),
 [height](#element-attrdef-filter-primitive-height),
 [result](#element-attrdef-filter-primitive-result) ]
- [[class]](https://www.w3.org/TR/2011/REC-SVG11-20110816/styling.html#ClassAttribute)
- [[style]](https://www.w3.org/TR/2011/REC-SVG11-20110816/styling.html#StyleAttribute)
- [in](#element-attrdef-filter-primitive-in)
- [stdDeviation](#element-attrdef-fedropshadow-stddeviation)
- [dx](#element-attrdef-fedropshadow-dx)
- [dy](#element-attrdef-fedropshadow-dy)

DOM Interfaces:

[SVGFEDropShadowElement](#InterfaceSVGFEDropShadowElement)

This filter creates a drop shadow of the input image. It is a shorthand
filter, and is defined in terms of combinations of other [filter
primitives](#filter-primitive). The expectation is that it can be optimized more
easily by implementations.

The result of a
[feDropShadow](#elementdef-fedropshadow) filter primitive is equivalent to the following:

``` highlight
<feGaussianBlur in="alpha-channel-of-feDropShadow-in" stdDeviation="stdDeviation-of-feDropShadow"/>
<feOffset dx="dx-of-feDropShadow" dy="dy-of-feDropShadow" resu/>
<feFlood flood-color="flood-color-of-feDropShadow" flood-opacity="flood-opacity-of-feDropShadow"/>
<feComposite in2="offsetblur" operator="in"/>
<feMerge>
 <feMergeNode/>
 <feMergeNode in="in-of-feDropShadow"/>
</feMerge>
```

The above divided into steps:

1. Take the alpha channel of the input to the
 [feDropShadow](#elementdef-fedropshadow) filter primitive and the
 [stdDeviation](#element-attrdef-fedropshadow-stddeviation) on the
 [feDropShadow] and do processing
 as if the following
 [feGaussianBlur](#elementdef-fegaussianblur) was applied:

 ``` highlight
 <feGaussianBlur in="alpha-channel-of-feDropShadow-in" stdDeviation="stdDeviation-of-feDropShadow"/>
 ```

2. Offset the result of step 1 by
 [dx](#element-attrdef-fedropshadow-dx) and
 [dy](#element-attrdef-fedropshadow-dy) as specified on the
 [feDropShadow](#elementdef-fedropshadow) element, equivalent to applying an
 [feOffset](#elementdef-feoffset) with these parameters:

 ``` highlight
 <feOffset dx="dx-of-feDropShadow" dy="dy-of-feDropShadow" resu/>
 ```

3. Do processing as if an
 [feFlood](#elementdef-feflood) element with
 [flood-color](#propdef-flood-color) and
 [flood-opacity](#propdef-flood-opacity) as specified on the
 [feDropShadow](#elementdef-fedropshadow) was applied:

 ``` highlight
 <feFlood flood-color="flood-color-of-feDropShadow" flood-opacity="flood-opacity-of-feDropShadow"/>
 ```

4. Composite the result of the
 [feFlood](#elementdef-feflood) in step 3 with the result of the
 [feOffset](#elementdef-feoffset) in step 2 as if an
 [feComposite](#elementdef-fecomposite) filter primitive with `operator="in"` was
 applied:

 ``` highlight
 <feComposite in2="offsetblur" operator="in"/>
 ```

5. Finally merge the result of the previous step, doing processing as
 if the following
 [feMerge](#elementdef-femerge) was performed:

 ``` highlight
 <feMerge>
 <feMergeNode/>
 <feMergeNode in="in-of-feDropShadow"/>
 </feMerge>
 ```

Note: that while the definition of the
[feDropShadow](#elementdef-fedropshadow) filter primitive says that it can be expanded into
an equivalent tree it is not required that it is implemented like that.
The expectation is that user agents can optimize the handling by not
having to do all the steps separately.

Beyond the DOM interface
[SVGFEDropShadowElement](#InterfaceSVGFEDropShadowElement) there is no
way of accessing the internals of the
[feDropShadow](#elementdef-fedropshadow) filter primitive, meaning [if the filter primitive
is implemented as an equivalent tree then that tree must not be exposed
to the DOM.]

*Attribute definitions:*

[`dx`] = \"*[\<number\>](https://www.w3.org/TR/css3-values/#number-value)*\"

: The x offset of the drop shadow.

 The [initial
 value](https://svgwg.org/svg2-draft/types.html#TermInitialValue) for
 [dx](#element-attrdef-fedropshadow-dx) is [2].

 This attribute is then forwarded to the
 [dx](#element-attrdef-feoffset-dx) attribute of the internal
 [feOffset](#elementdef-feoffset) element.

 Animatable: yes.

[`dy`] = \"*[\<number\>](https://www.w3.org/TR/css3-values/#number-value)*\"

: The y offset of the drop shadow.

 The [initial
 value](https://svgwg.org/svg2-draft/types.html#TermInitialValue) for
 [dy](#element-attrdef-fedropshadow-dy) is [2].

 This attribute is then forwarded to the
 [dy](#element-attrdef-feoffset-dy) attribute of the internal
 [feOffset](#elementdef-feoffset) element.

 Animatable: yes.

[`stdDeviation`] = \"*[\<number-optional-number\>](#typedef-number-optional-number)*\"

: The standard deviation for the blur operation in the drop shadow.

 The [initial
 value](https://svgwg.org/svg2-draft/types.html#TermInitialValue) for
 [stdDeviation](#element-attrdef-fedropshadow-stddeviation) is [2].

 This attribute is then forwarded to the
 [stdDeviation](#element-attrdef-fegaussianblur-stddeviation) attribute of the internal
 [feGaussianBlur](#elementdef-fegaussianblur) element.

 Animatable: yes.

### 9.13. Filter primitive [feFlood]
Name:

[`feFlood`]

Categories:

[filter primitive](#filter-primitive)

Content model:

Any number of [descriptive
elements](https://www.w3.org/TR/svg2/struct.html#TermDescriptiveElement),
[animate](https://www.w3.org/TR/SVG11/animate.html#AnimateElement),
[script](https://www.w3.org/TR/svg2/interact.html#elementdef-script),
[set](https://www.w3.org/TR/SVG11/animate.html#SetElement) elements, in any order.

Attributes:

- [core
 attributes](https://www.w3.org/TR/2011/REC-SVG11-20110816/intro.html#TermCoreAttributes)[
 ---
 [[id]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#IDAttribute),
 [[xml:base]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#XMLBaseAttribute),
 [[xml:lang]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#XMLLangAttribute),
 [[xml:space]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#XMLSpaceAttribute)]
- [presentation
 attributes](https://www.w3.org/TR/2008/REC-SVGTiny12-20081222/intro.html#TermPresentationAttribute)[
 ---
 [alignment-baseline](https://www.w3.org/TR/SVG11/text.html#AlignmentBaselineProperty),
 [baseline-shift](https://www.w3.org/TR/SVG11/text.html#BaselineShiftProperty),
 [clip](https://www.w3.org/TR/css-masking-1/#propdef-clip),
 [clip-path](https://www.w3.org/TR/css-masking-1/#propdef-clip-path),
 [clip-rule](https://www.w3.org/TR/css-masking-1/#propdef-clip-rule),
 [color](https://www.w3.org/TR/css3-color/#color0),
 [color-interpolation](https://www.w3.org/TR/svg2/painting.html#ColorInterpolationProperty),
 [color-interpolation-filters](#propdef-color-interpolation-filters),
 [color-rendering](https://www.w3.org/TR/svg2/painting.html#ColorRenderingProperty),
 [cursor](https://www.w3.org/TR/css3-ui/#propdef-cursor),
 [direction](https://www.w3.org/TR/css-writing-modes-3/#propdef-direction),
 [display](https://www.w3.org/TR/css-display-3/#propdef-display),
 [dominant-baseline](https://www.w3.org/TR/SVG11/text.html#DominantBaselineProperty),
 [enable-background](https://www.w3.org/TR/SVG11/filters.html#EnableBackgroundProperty),
 [fill](https://www.w3.org/TR/svg2/painting.html#FillProperty),
 [fill-opacity](https://www.w3.org/TR/svg2/painting.html#FillOpacityProperty),
 [fill-rule](https://www.w3.org/TR/svg2/painting.html#FillRuleProperty),
 [filter](#propdef-filter),
 [flood-color](#propdef-flood-color),
 [flood-opacity](#propdef-flood-opacity),
 [font](https://www.w3.org/TR/css-fonts-3/#propdef-font),
 [font-family](https://www.w3.org/TR/css-fonts-3/#propdef-font-family),
 [font-size](https://www.w3.org/TR/css-fonts-3/#propdef-font-size),
 [font-size-adjust](https://www.w3.org/TR/css-fonts-4/#propdef-font-size-adjust),
 [font-stretch](https://www.w3.org/TR/css-fonts-3/#propdef-font-stretch),
 [font-style](https://www.w3.org/TR/css-fonts-3/#propdef-font-style),
 [font-variant](https://www.w3.org/TR/css-fonts-3/#propdef-font-variant),
 [font-weight](https://www.w3.org/TR/css-fonts-3/#propdef-font-weight),
 [glyph-orientation-horizontal](https://www.w3.org/TR/SVG11/text.html#GlyphOrientationHorizontalProperty),
 [glyph-orientation-vertical](https://www.w3.org/TR/SVG11/text.html#GlyphOrientationVerticalProperty),
 [image-rendering](https://drafts.csswg.org/css-images-3/#propdef-image-rendering),
 [isolation](https://www.w3.org/TR/compositing-1/#propdef-isolation),
 [kerning](https://www.w3.org/TR/SVG11/text.html#KerningProperty),
 [letter-spacing](https://www.w3.org/TR/css-text-3/#propdef-letter-spacing),
 [lighting-color](#propdef-lighting-color),
 [marker](https://www.w3.org/TR/svg2/painting.html#MarkerProperty),
 [marker-end](https://www.w3.org/TR/svg2/painting.html#MarkerEndProperty),
 [marker-mid](https://www.w3.org/TR/svg2/painting.html#MarkerMidProperty),
 [marker-start](https://www.w3.org/TR/svg2/painting.html#MarkerStartProperty),
 [mask](https://www.w3.org/TR/css-masking-1/#propdef-mask),
 [opacity](https://www.w3.org/TR/css-color-4/#propdef-opacity),
 [overflow](https://www.w3.org/TR/css-overflow-3/#propdef-overflow),
 [pointer-events](https://www.w3.org/TR/svg2/interact.html#PointerEventsProperty),
 [shape-rendering](https://www.w3.org/TR/svg2/painting.html#ShapeRenderingProperty),
 [stop-color](https://www.w3.org/TR/svg2/pservers.html#StopColorProperty),
 [stop-opacity](https://www.w3.org/TR/svg2/pservers.html#StopOpacityProperty),
 [stroke](https://www.w3.org/TR/svg2/painting.html#StrokeProperty),
 [stroke-dasharray](https://www.w3.org/TR/svg2/painting.html#StrokeDasharrayProperty),
 [stroke-dashoffset](https://www.w3.org/TR/svg2/painting.html#StrokeDashoffsetProperty),
 [stroke-linecap](https://www.w3.org/TR/svg2/painting.html#StrokeLinecapProperty),
 [stroke-linejoin](https://www.w3.org/TR/svg2/painting.html#StrokeLinejoinProperty),
 [stroke-miterlimit](https://www.w3.org/TR/svg2/painting.html#StrokeMiterlimitProperty),
 [stroke-opacity](https://www.w3.org/TR/svg2/painting.html#StrokeOpacityProperty),
 [stroke-width](https://www.w3.org/TR/svg2/painting.html#StrokeWidthProperty),
 [text-anchor](https://www.w3.org/TR/svg2/text.html#TextAnchorProperty),
 [text-decoration](https://www.w3.org/TR/css-text-decor-3/#propdef-text-decoration),
 [text-rendering](https://www.w3.org/TR/svg2/painting.html#TextRenderingProperty),
 [unicode-bidi](https://www.w3.org/TR/css-writing-modes-3/#propdef-unicode-bidi),
 [visibility](https://www.w3.org/TR/CSS21/visufx.html#propdef-visibility),
 [word-spacing](https://www.w3.org/TR/css-text-3/#propdef-word-spacing),
 [writing-mode](https://www.w3.org/TR/css-writing-modes-4/#propdef-writing-mode)]
- [filter primitive
 attributes](#filter-primitive-attributes)
 [
 ---[x](#element-attrdef-filter-primitive-x),
 [y](#element-attrdef-filter-primitive-y),
 [width](#element-attrdef-filter-primitive-width),
 [height](#element-attrdef-filter-primitive-height),
 [result](#element-attrdef-filter-primitive-result) ]
- [[class]](https://www.w3.org/TR/2011/REC-SVG11-20110816/styling.html#ClassAttribute)
- [[style]](https://www.w3.org/TR/2011/REC-SVG11-20110816/styling.html#StyleAttribute)

DOM Interfaces:

[SVGFEFloodElement](#InterfaceSVGFEFloodElement)

This filter primitive creates a rectangle filled with the color and
opacity values from properties
[flood-color](#propdef-flood-color) and
[flood-opacity](#propdef-flood-opacity). The rectangle is as large as the
[filter primitive
subregion](#filter-primitive-subregion) established by the
[feFlood](#elementdef-feflood) element.

#### 9.13.1. The [flood-color property]
Name:

[flood-color]

[Value:](https://drafts.csswg.org/css-values/#value-defs)

[\<color\>](https://www.w3.org/TR/css3-color/#valuea-def-color "Expands to: indigo | gold | firebrick | indianred | yellow | darkolivegreen | darkseagreen | slategrey | darkslategrey | mediumvioletred | mediumorchid | transparent | chartreuse | mediumslateblue | black | springgreen | crimson | lightsalmon | brown | turquoise | olivedrab | cyan | silver | skyblue | gray | darkturquoise | goldenrod | darkgreen | darkviolet | darkgray | lightpink | teal | darkmagenta | lightgoldenrodyellow | lavender | yellowgreen | thistle | violet | navy | dimgrey | orchid | blue | ghostwhite | honeydew | cornflowerblue | darkblue | darkkhaki | mediumpurple | cornsilk | red | bisque | slategray | darkcyan | khaki | wheat | deepskyblue | rebeccapurple | darkred | steelblue | aliceblue | lightslategrey | gainsboro | mediumturquoise | floralwhite | coral | purple | lightgrey | lightcyan | darksalmon | beige | azure | lightsteelblue | oldlace | greenyellow | royalblue | lightseagreen | mistyrose | sienna | lightcoral | orangered | navajowhite | lime | palegreen | burlywood | seashell | mediumspringgreen | fuchsia | papayawhip | blanchedalmond | peru | aquamarine | white | darkslategray | tomato | ivory | dodgerblue | currentcolor | lemonchiffon | chocolate | orange | forestgreen | darkgrey | olive | mintcream | antiquewhite | darkorange | cadetblue | moccasin | limegreen | saddlebrown | grey | darkslateblue | lightskyblue | deeppink | plum | aqua | darkgoldenrod | maroon | sandybrown | magenta | tan | rosybrown | pink | lightblue | palevioletred | mediumseagreen | slateblue | dimgray | powderblue | seagreen | snow | mediumblue | midnightblue | paleturquoise | palegoldenrod | whitesmoke | darkorchid | salmon | lightslategray | lawngreen | lightgreen | lightgray | hotpink | lightyellow | lavenderblush | linen | mediumaquamarine | green | blueviolet | peachpuff")

[Initial:](https://drafts.csswg.org/css-cascade/#initial-values)

black

Applies to:

[feFlood](#elementdef-feflood) and
[feDropShadow](#elementdef-fedropshadow) elements

[Inherited:](https://drafts.csswg.org/css-cascade/#inherited-property)

no

[Percentages:](https://drafts.csswg.org/css-values/#percentages)

n/a

[Computed value:](https://drafts.csswg.org/css-cascade/#computed)

as specified

Canonical order:

per grammar

Media:

visual

[Animatable:](https://drafts.csswg.org/web-animations/#animation-type)

as [by computed
value](https://drafts.csswg.org/web-animations-1/#by-computed-value)

The [flood-color](#propdef-flood-color) property indicates what color to used to
flood the current [filter primitive
subregion](#filter-primitive-subregion).

The [flood-color](#propdef-flood-color) property is a [presentation
attribute](https://www.w3.org/TR/2011/REC-SVG11-20110816/intro.html#TermPresentationAttribute)
for SVG elements.

#### 9.13.2. The [flood-opacity property]
Name:

[flood-opacity]

[Value:](https://drafts.csswg.org/css-values/#value-defs)

[\<alpha-value\>](https://www.w3.org/TR/css-color-4/#typedef-alpha-value)

[Initial:](https://drafts.csswg.org/css-cascade/#initial-values)

1

Applies to:

[feFlood](#elementdef-feflood) and
[feDropShadow](#elementdef-fedropshadow) elements

[Inherited:](https://drafts.csswg.org/css-cascade/#inherited-property)

no

[Percentages:](https://drafts.csswg.org/css-values/#percentages)

n/a

[Computed value:](https://drafts.csswg.org/css-cascade/#computed)

the specified value converted to a number, clamped to the range \[0,1\]

Canonical order:

per grammar

Media:

visual

[Animatable:](https://drafts.csswg.org/web-animations/#animation-type)

[by computed
value](https://drafts.csswg.org/web-animations-1/#by-computed-value)

The
[flood-opacity](#propdef-flood-opacity) property defines the opacity value to
use across the entire [filter primitive
subregion](#filter-primitive-subregion). If the
[flood-color](#propdef-flood-color) value includes an alpha channel, the
alpha channel gets multiplied with the computed value of the
[flood-opacity] property.

The
[flood-opacity](#propdef-flood-opacity) property is a [presentation
attribute](https://www.w3.org/TR/2011/REC-SVG11-20110816/intro.html#TermPresentationAttribute)
for SVG elements.

### 9.14. Filter primitive [feGaussianBlur]
Name:

[`feGaussianBlur`]

Categories:

[filter primitive](#filter-primitive)

Content model:

Any number of [descriptive
elements](https://www.w3.org/TR/svg2/struct.html#TermDescriptiveElement),
[animate](https://www.w3.org/TR/SVG11/animate.html#AnimateElement),
[script](https://www.w3.org/TR/svg2/interact.html#elementdef-script),
[set](https://www.w3.org/TR/SVG11/animate.html#SetElement) elements, in any order.

Attributes:

- [core
 attributes](https://www.w3.org/TR/2011/REC-SVG11-20110816/intro.html#TermCoreAttributes)[
 ---
 [[id]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#IDAttribute),
 [[xml:base]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#XMLBaseAttribute),
 [[xml:lang]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#XMLLangAttribute),
 [[xml:space]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#XMLSpaceAttribute)]
- [presentation
 attributes](https://www.w3.org/TR/2008/REC-SVGTiny12-20081222/intro.html#TermPresentationAttribute)[
 ---
 [alignment-baseline](https://www.w3.org/TR/SVG11/text.html#AlignmentBaselineProperty),
 [baseline-shift](https://www.w3.org/TR/SVG11/text.html#BaselineShiftProperty),
 [clip](https://www.w3.org/TR/css-masking-1/#propdef-clip),
 [clip-path](https://www.w3.org/TR/css-masking-1/#propdef-clip-path),
 [clip-rule](https://www.w3.org/TR/css-masking-1/#propdef-clip-rule),
 [color](https://www.w3.org/TR/css3-color/#color0),
 [color-interpolation](https://www.w3.org/TR/svg2/painting.html#ColorInterpolationProperty),
 [color-interpolation-filters](#propdef-color-interpolation-filters),
 [color-rendering](https://www.w3.org/TR/svg2/painting.html#ColorRenderingProperty),
 [cursor](https://www.w3.org/TR/css3-ui/#propdef-cursor),
 [direction](https://www.w3.org/TR/css-writing-modes-3/#propdef-direction),
 [display](https://www.w3.org/TR/css-display-3/#propdef-display),
 [dominant-baseline](https://www.w3.org/TR/SVG11/text.html#DominantBaselineProperty),
 [enable-background](https://www.w3.org/TR/SVG11/filters.html#EnableBackgroundProperty),
 [fill](https://www.w3.org/TR/svg2/painting.html#FillProperty),
 [fill-opacity](https://www.w3.org/TR/svg2/painting.html#FillOpacityProperty),
 [fill-rule](https://www.w3.org/TR/svg2/painting.html#FillRuleProperty),
 [filter](#propdef-filter),
 [flood-color](#propdef-flood-color),
 [flood-opacity](#propdef-flood-opacity),
 [font](https://www.w3.org/TR/css-fonts-3/#propdef-font),
 [font-family](https://www.w3.org/TR/css-fonts-3/#propdef-font-family),
 [font-size](https://www.w3.org/TR/css-fonts-3/#propdef-font-size),
 [font-size-adjust](https://www.w3.org/TR/css-fonts-4/#propdef-font-size-adjust),
 [font-stretch](https://www.w3.org/TR/css-fonts-3/#propdef-font-stretch),
 [font-style](https://www.w3.org/TR/css-fonts-3/#propdef-font-style),
 [font-variant](https://www.w3.org/TR/css-fonts-3/#propdef-font-variant),
 [font-weight](https://www.w3.org/TR/css-fonts-3/#propdef-font-weight),
 [glyph-orientation-horizontal](https://www.w3.org/TR/SVG11/text.html#GlyphOrientationHorizontalProperty),
 [glyph-orientation-vertical](https://www.w3.org/TR/SVG11/text.html#GlyphOrientationVerticalProperty),
 [image-rendering](https://drafts.csswg.org/css-images-3/#propdef-image-rendering),
 [isolation](https://www.w3.org/TR/compositing-1/#propdef-isolation),
 [kerning](https://www.w3.org/TR/SVG11/text.html#KerningProperty),
 [letter-spacing](https://www.w3.org/TR/css-text-3/#propdef-letter-spacing),
 [lighting-color](#propdef-lighting-color),
 [marker](https://www.w3.org/TR/svg2/painting.html#MarkerProperty),
 [marker-end](https://www.w3.org/TR/svg2/painting.html#MarkerEndProperty),
 [marker-mid](https://www.w3.org/TR/svg2/painting.html#MarkerMidProperty),
 [marker-start](https://www.w3.org/TR/svg2/painting.html#MarkerStartProperty),
 [mask](https://www.w3.org/TR/css-masking-1/#propdef-mask),
 [opacity](https://www.w3.org/TR/css-color-4/#propdef-opacity),
 [overflow](https://www.w3.org/TR/css-overflow-3/#propdef-overflow),
 [pointer-events](https://www.w3.org/TR/svg2/interact.html#PointerEventsProperty),
 [shape-rendering](https://www.w3.org/TR/svg2/painting.html#ShapeRenderingProperty),
 [stop-color](https://www.w3.org/TR/svg2/pservers.html#StopColorProperty),
 [stop-opacity](https://www.w3.org/TR/svg2/pservers.html#StopOpacityProperty),
 [stroke](https://www.w3.org/TR/svg2/painting.html#StrokeProperty),
 [stroke-dasharray](https://www.w3.org/TR/svg2/painting.html#StrokeDasharrayProperty),
 [stroke-dashoffset](https://www.w3.org/TR/svg2/painting.html#StrokeDashoffsetProperty),
 [stroke-linecap](https://www.w3.org/TR/svg2/painting.html#StrokeLinecapProperty),
 [stroke-linejoin](https://www.w3.org/TR/svg2/painting.html#StrokeLinejoinProperty),
 [stroke-miterlimit](https://www.w3.org/TR/svg2/painting.html#StrokeMiterlimitProperty),
 [stroke-opacity](https://www.w3.org/TR/svg2/painting.html#StrokeOpacityProperty),
 [stroke-width](https://www.w3.org/TR/svg2/painting.html#StrokeWidthProperty),
 [text-anchor](https://www.w3.org/TR/svg2/text.html#TextAnchorProperty),
 [text-decoration](https://www.w3.org/TR/css-text-decor-3/#propdef-text-decoration),
 [text-rendering](https://www.w3.org/TR/svg2/painting.html#TextRenderingProperty),
 [unicode-bidi](https://www.w3.org/TR/css-writing-modes-3/#propdef-unicode-bidi),
 [visibility](https://www.w3.org/TR/CSS21/visufx.html#propdef-visibility),
 [word-spacing](https://www.w3.org/TR/css-text-3/#propdef-word-spacing),
 [writing-mode](https://www.w3.org/TR/css-writing-modes-4/#propdef-writing-mode)]
- [filter primitive
 attributes](#filter-primitive-attributes)
 [
 ---[x](#element-attrdef-filter-primitive-x),
 [y](#element-attrdef-filter-primitive-y),
 [width](#element-attrdef-filter-primitive-width),
 [height](#element-attrdef-filter-primitive-height),
 [result](#element-attrdef-filter-primitive-result) ]
- [[class]](https://www.w3.org/TR/2011/REC-SVG11-20110816/styling.html#ClassAttribute)
- [[style]](https://www.w3.org/TR/2011/REC-SVG11-20110816/styling.html#StyleAttribute)
- [in](#element-attrdef-filter-primitive-in)
- [stdDeviation](#element-attrdef-fegaussianblur-stddeviation)
- [edgeMode](#element-attrdef-fegaussianblur-edgemode)

DOM Interfaces:

[SVGFEGaussianBlurElement](#InterfaceSVGFEGaussianBlurElement)

This filter primitive performs a Gaussian blur on the input image.

The Gaussian blur kernel is an approximation of the normalized
convolution:

`G(x,y) = H(x)I(y)`

where

`H(x) = exp(-x`^`2`^`/ (2s`^`2`^`)) / sqrt(2π * s`^`2`^`)`

and

`I(y) = exp(-y`^`2`^`/ (2t`^`2`^`)) / sqrt(2π * t`^`2`^`)`

with \"s\" being the standard deviation in the x direction and \"t\"
being the standard deviation in the y direction, as specified by
[stdDeviation](#element-attrdef-fegaussianblur-stddeviation).

The value of
[stdDeviation](#element-attrdef-fegaussianblur-stddeviation) can be either one or two numbers. If two
numbers are provided, the first number represents a standard deviation
value along the x-axis of the current coordinate system and the second
value represents a standard deviation in Y. If one number is provided,
then that value is used for both X and Y.

Even if only one value is provided for
[stdDeviation](#element-attrdef-fegaussianblur-stddeviation), this can be implemented as a separable
convolution.

For larger values of \"s\" (s \>= 2.0), an approximation can be used:
Three successive box-blurs build a piece-wise quadratic convolution
kernel, which approximates the Gaussian kernel to within roughly 3%.

`let d = floor(s * 3 * sqrt(2 * π) / 4 + 0.5)`

\... if d is odd, use three box-blurs of size \"d\", centered on the
output pixel.

\... if d is even, two box-blurs of size \"d\" (the first one centered
on the pixel boundary between the output pixel and the one to the left,
the second one centered on the pixel boundary between the output pixel
and the one to the right) and one box blur of size \"d+1\" centered on
the output pixel.

The approximation formula also applies correspondingly to \"t\".

Frequently this operation will take place on alpha-only images, such as
that produced by the built-in input,
[SourceAlpha](#attr-valuedef-in-sourcealpha). The implementation may notice this and optimize
the single channel case. This optimization must be omitted if it leads
to privacy concerns of any matter. (See section [Privacy and Security
Considerations](#priv-sec) for more details about timing attacks.) If
the input has infinite extent and is constant (e.g
[FillPaint](#attr-valuedef-in-fillpaint) where the fill is a solid color), this operation
has no effect. If the input has infinite extent and the filter result
where the fill is a solid color) is the input to an
[feTile](#elementdef-fetile), the filter is evaluated with [periodic boundary
conditions](https://en.wikipedia.org/wiki/Periodic_boundary_conditions).

*Attribute definitions:*

[`stdDeviation`] = \"*[\<number-optional-number\>](#typedef-number-optional-number)*\"

: The standard deviation for the blur operation. If two
 [\<number\>](https://www.w3.org/TR/css3-values/#number-value) s are provided, the first number
 represents a standard deviation value along the x-axis of the
 coordinate system established by attribute
 [primitiveUnits](#element-attrdef-filter-primitiveunits) on the
 [filter](#elementdef-filter) element. The second value represents a standard
 deviation in Y. If one number is provided, then that value is used
 for both X and Y.

 A negative value or a value of zero disables the effect of the given
 filter primitive (i.e., the result is the filter input image).

 If
 [stdDeviation](#element-attrdef-fegaussianblur-stddeviation) is [0] in only one of X or Y, then
 the effect is that the blur is only applied in the direction that
 has a non-zero value.

 The [initial
 value](https://svgwg.org/svg2-draft/types.html#TermInitialValue) for
 [stdDeviation](#element-attrdef-fegaussianblur-stddeviation) is [0].

 Animatable: yes.

[`edgeMode`] = \"[duplicate](#attr-valuedef-edgemode-duplicate) \| [wrap](#attr-valuedef-edgemode-wrap) \| none\"

: Determines how to extend the input image as necessary with color
 values so that the matrix operations can be applied when the kernel
 is positioned at or near the edge of the input image.

 [`duplicate`] indicates that
 the input image is extended along each of its borders as necessary
 by duplicating the color values at the given edge of the input
 image.

 Original N-by-M image, where m=M-1 and n=N-1:

 [`wrap`] indicates that
 the input image is extended by taking the color values from the
 opposite edge of the image.

 The value [none] indicates that the input image is extended
 with pixel values of zero for R, G, B and A.

 The [initial
 value](https://svgwg.org/svg2-draft/types.html#TermInitialValue) for
 [edgeMode](#element-attrdef-fegaussianblur-edgemode) is [none].

 Animatable: yes.

[The example](#intro) at the start of this chapter makes use of the
[feGaussianBlur](#elementdef-fegaussianblur) filter primitive to create a drop shadow effect.

### 9.15. Filter primitive [feImage]
Name:

[`feImage`]

Categories:

[filter primitive](#filter-primitive)

Content model:

Any number of [descriptive
elements](https://www.w3.org/TR/svg2/struct.html#TermDescriptiveElement),
[animate](https://www.w3.org/TR/SVG11/animate.html#AnimateElement),
[animateTransform](https://www.w3.org/TR/SVG11/animate.html#AnimateTransformElement),
[script](https://www.w3.org/TR/svg2/interact.html#elementdef-script),
[set](https://www.w3.org/TR/SVG11/animate.html#SetElement) elements, in any order.

Attributes:

- [core
 attributes](https://www.w3.org/TR/2011/REC-SVG11-20110816/intro.html#TermCoreAttributes)[
 ---
 [[id]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#IDAttribute),
 [[xml:base]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#XMLBaseAttribute),
 [[xml:lang]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#XMLLangAttribute),
 [[xml:space]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#XMLSpaceAttribute)]
- [presentation
 attributes](https://www.w3.org/TR/2008/REC-SVGTiny12-20081222/intro.html#TermPresentationAttribute)[
 ---
 [alignment-baseline](https://www.w3.org/TR/SVG11/text.html#AlignmentBaselineProperty),
 [baseline-shift](https://www.w3.org/TR/SVG11/text.html#BaselineShiftProperty),
 [clip](https://www.w3.org/TR/css-masking-1/#propdef-clip),
 [clip-path](https://www.w3.org/TR/css-masking-1/#propdef-clip-path),
 [clip-rule](https://www.w3.org/TR/css-masking-1/#propdef-clip-rule),
 [color](https://www.w3.org/TR/css3-color/#color0),
 [color-interpolation](https://www.w3.org/TR/svg2/painting.html#ColorInterpolationProperty),
 [color-interpolation-filters](#propdef-color-interpolation-filters),
 [color-rendering](https://www.w3.org/TR/svg2/painting.html#ColorRenderingProperty),
 [cursor](https://www.w3.org/TR/css3-ui/#propdef-cursor),
 [direction](https://www.w3.org/TR/css-writing-modes-3/#propdef-direction),
 [display](https://www.w3.org/TR/css-display-3/#propdef-display),
 [dominant-baseline](https://www.w3.org/TR/SVG11/text.html#DominantBaselineProperty),
 [enable-background](https://www.w3.org/TR/SVG11/filters.html#EnableBackgroundProperty),
 [fill](https://www.w3.org/TR/svg2/painting.html#FillProperty),
 [fill-opacity](https://www.w3.org/TR/svg2/painting.html#FillOpacityProperty),
 [fill-rule](https://www.w3.org/TR/svg2/painting.html#FillRuleProperty),
 [filter](#propdef-filter),
 [flood-color](#propdef-flood-color),
 [flood-opacity](#propdef-flood-opacity),
 [font](https://www.w3.org/TR/css-fonts-3/#propdef-font),
 [font-family](https://www.w3.org/TR/css-fonts-3/#propdef-font-family),
 [font-size](https://www.w3.org/TR/css-fonts-3/#propdef-font-size),
 [font-size-adjust](https://www.w3.org/TR/css-fonts-4/#propdef-font-size-adjust),
 [font-stretch](https://www.w3.org/TR/css-fonts-3/#propdef-font-stretch),
 [font-style](https://www.w3.org/TR/css-fonts-3/#propdef-font-style),
 [font-variant](https://www.w3.org/TR/css-fonts-3/#propdef-font-variant),
 [font-weight](https://www.w3.org/TR/css-fonts-3/#propdef-font-weight),
 [glyph-orientation-horizontal](https://www.w3.org/TR/SVG11/text.html#GlyphOrientationHorizontalProperty),
 [glyph-orientation-vertical](https://www.w3.org/TR/SVG11/text.html#GlyphOrientationVerticalProperty),
 [image-rendering](https://drafts.csswg.org/css-images-3/#propdef-image-rendering),
 [isolation](https://www.w3.org/TR/compositing-1/#propdef-isolation),
 [kerning](https://www.w3.org/TR/SVG11/text.html#KerningProperty),
 [letter-spacing](https://www.w3.org/TR/css-text-3/#propdef-letter-spacing),
 [lighting-color](#propdef-lighting-color),
 [marker](https://www.w3.org/TR/svg2/painting.html#MarkerProperty),
 [marker-end](https://www.w3.org/TR/svg2/painting.html#MarkerEndProperty),
 [marker-mid](https://www.w3.org/TR/svg2/painting.html#MarkerMidProperty),
 [marker-start](https://www.w3.org/TR/svg2/painting.html#MarkerStartProperty),
 [mask](https://www.w3.org/TR/css-masking-1/#propdef-mask),
 [opacity](https://www.w3.org/TR/css-color-4/#propdef-opacity),
 [overflow](https://www.w3.org/TR/css-overflow-3/#propdef-overflow),
 [pointer-events](https://www.w3.org/TR/svg2/interact.html#PointerEventsProperty),
 [shape-rendering](https://www.w3.org/TR/svg2/painting.html#ShapeRenderingProperty),
 [stop-color](https://www.w3.org/TR/svg2/pservers.html#StopColorProperty),
 [stop-opacity](https://www.w3.org/TR/svg2/pservers.html#StopOpacityProperty),
 [stroke](https://www.w3.org/TR/svg2/painting.html#StrokeProperty),
 [stroke-dasharray](https://www.w3.org/TR/svg2/painting.html#StrokeDasharrayProperty),
 [stroke-dashoffset](https://www.w3.org/TR/svg2/painting.html#StrokeDashoffsetProperty),
 [stroke-linecap](https://www.w3.org/TR/svg2/painting.html#StrokeLinecapProperty),
 [stroke-linejoin](https://www.w3.org/TR/svg2/painting.html#StrokeLinejoinProperty),
 [stroke-miterlimit](https://www.w3.org/TR/svg2/painting.html#StrokeMiterlimitProperty),
 [stroke-opacity](https://www.w3.org/TR/svg2/painting.html#StrokeOpacityProperty),
 [stroke-width](https://www.w3.org/TR/svg2/painting.html#StrokeWidthProperty),
 [text-anchor](https://www.w3.org/TR/svg2/text.html#TextAnchorProperty),
 [text-decoration](https://www.w3.org/TR/css-text-decor-3/#propdef-text-decoration),
 [text-rendering](https://www.w3.org/TR/svg2/painting.html#TextRenderingProperty),
 [unicode-bidi](https://www.w3.org/TR/css-writing-modes-3/#propdef-unicode-bidi),
 [visibility](https://www.w3.org/TR/CSS21/visufx.html#propdef-visibility),
 [word-spacing](https://www.w3.org/TR/css-text-3/#propdef-word-spacing),
 [writing-mode](https://www.w3.org/TR/css-writing-modes-4/#propdef-writing-mode)]
- [filter primitive
 attributes](#filter-primitive-attributes)
 [
 ---[x](#element-attrdef-filter-primitive-x),
 [y](#element-attrdef-filter-primitive-y),
 [width](#element-attrdef-filter-primitive-width),
 [height](#element-attrdef-filter-primitive-height),
 [result](#element-attrdef-filter-primitive-result) ]
- [[class]](https://www.w3.org/TR/2011/REC-SVG11-20110816/styling.html#ClassAttribute)
- [[style]](https://www.w3.org/TR/2011/REC-SVG11-20110816/styling.html#StyleAttribute)
- [[externalResourcesRequired]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#ExternalResourcesRequiredAttribute)
- [preserveAspectRatio](#element-attrdef-feimage-preserveaspectratio)
- [xlink:href](#element-attrdef-feimage-xlinkhref)
- [href](#element-attrdef-feimage-href)
- [crossorigin](#element-attrdef-feimage-crossorigin)

DOM Interfaces:

[SVGFEImageElement](#InterfaceSVGFEImageElement)

This filter primitive refers to a graphic external to this filter
element, which is loaded or rendered into an RGBA raster and becomes the
result of the filter primitive.

This filter primitive can refer to an external image or can be a
reference to another piece of SVG. It produces an image similar to the
built-in image source
[SourceGraphic](#attr-valuedef-in-sourcegraphic) except that the graphic comes from an external
source.

If the
[href](#element-attrdef-feimage-href) references a stand-alone image resource such
as a JPEG, PNG or SVG file, then the image resource is rendered
according to the behavior of the
[image](https://www.w3.org/TR/svg2/embedded.html#elementdef-image) element; otherwise, the referenced resource is
rendered according to the behavior of the
[use](https://www.w3.org/TR/svg2/struct.html#elementdef-use) element. In either case, the current user
coordinate system depends on the value of attribute
[primitiveUnits](#element-attrdef-filter-primitiveunits) on the
[filter](#elementdef-filter) element. The processing of the
[preserveAspectRatio](#element-attrdef-feimage-preserveaspectratio) attribute on the
[feImage](#elementdef-feimage) element is identical to that of the
[image] element.

A
[href](#element-attrdef-feimage-href) reference that is an empty image (zero width
or zero height), that fails to download, is non-existent, or that cannot
be displayed (e.g. because it is not in a supported image format) fills
the filter primitive subregion with transparent black.

[When the referenced image must be resampled to match the device
coordinate system, it is recommended that high quality viewers make use
of appropriate interpolation techniques, for example bilinear or
bicubic.] Depending on the speed
of the available interpolents, this choice may be affected by the
[image-rendering](https://drafts.csswg.org/css-images-3/#propdef-image-rendering) property setting.

*Attribute definitions:*

[`xlink:href`] = \"[\<url\>](#typedef-filter-url)\"

: See
 [href](#element-attrdef-feimage-href) attribute.

 Animatable: yes.

 Note: This *xlink:href* attribute is deprecated and should not be
 used in new content, it's included for backwards compatibility
 reasons only. Authors should use the
 [href](#element-attrdef-feimage-href) attribute instead.

[`href`] = \"[\<url\>](#typedef-filter-url)\"

: An [\<url\>](#typedef-filter-url) to an image resource or to an
 element. If both, the
 [xlink:href](#element-attrdef-feimage-xlinkhref) and the
 [href](#element-attrdef-feimage-href) attribute are specified, the latter
 overrides the first definition.

 Animatable: yes.

[`preserveAspectRatio`] = \"*\[defer\] \<align\> \[\<meetOrSlice\>\]*\"

: See
 [preserveAspectRatio](#element-attrdef-feimage-preserveaspectratio).

 The [initial
 value](https://svgwg.org/svg2-draft/types.html#TermInitialValue) for
 [preserveAspectRatio](#element-attrdef-feimage-preserveaspectratio) is [xMidYMid meet].

 Animatable: yes.

[`crossorigin`] = \"*anonymous* \| *use-credentials*\"

: The
 [crossorigin](https://www.w3.org/TR/html5/infrastructure.html#cors-settings-attribute)
 attribute is a CORS settings attribute. Its purpose is to allow
 images from third-party sites that allow cross-origin access to be
 used with
 [feDisplacementMap](#elementdef-fedisplacementmap). For the defintion see
 [crossorigin](https://www.w3.org/TR/html5/infrastructure.html#cors-settings-attribute)
 attribute for the
 [img](https://html.spec.whatwg.org/multipage/embedded-content.html#the-img-element) tag
 [\[HTML5\]](#biblio-html5) and the [Privacy and
 Security Considerations](#priv-sec) section in this specification.

 Animatable: no.

The following example illustrates how
images are placed relative to an object. From left to right:

- The default placement of an image. Note that the image is centered in
 the [filter region](#filter-region) and has the maximum size that will fit in the region
 consistent with preserving the aspect ratio.

- The image stretched to fit the bounding box of an object.

- The image placed using user coordinates. Note that the image is first
 centered in a box the size of the [filter
 region](#filter-region) and
 has the maximum size that will fit in the box consistent with
 preserving the aspect ratio. This box is then shifted by the given
 [x](#element-attrdef-filter-primitive-x) and
 [y](#element-attrdef-filter-primitive-y) values relative to the viewport the object
 is in.

``` highlight
<svg width="600" height="250" viewBox="0 0 600 250"
 xmlns="http://www.w3.org/2000/svg"
 xmlns:xlink="http://www.w3.org/1999/xlink">
 <title>Example feImage - Examples of feImage use</title>
 <desc>Three examples of using feImage, the first showing the
 default rendering, the second showing the image fit
 to a box and the third showing the image
 shifted and clipped.</desc>
 <defs>
 <filter id="Default">
 <feImage xlink:href="smiley.png" />
 </filter>
 <filter id="Fitted" primitiveUnits="objectBoundingBox">
 <feImage xlink:href="smiley.png"
 x="0" y="0" width="100%" height="100%"
 preserveAspectRatio="none"/>
 </filter>
 <filter id="Shifted">
 <feImage xlink:href="smiley.png"
 x="500" y="5"/>
 </filter>
 </defs>
 <rect fill="none" stroke="blue"
 x="1" y="1" width="598" height="248"/>
 <g>
 <rect x="50" y="25" width="100" height="200" filter="url(#Default)"/>
 <rect x="50" y="25" width="100" height="200" fill="none" stroke="green"/>
 <rect x="250" y="25" width="100" height="200" filter="url(#Fitted)"/>
 <rect x="250" y="25" width="100" height="200" fill="none" stroke="green"/>
 <rect x="450" y="25" width="100" height="200" filter="url(#Shifted)"/>
 <rect x="450" y="25" width="100" height="200" fill="none" stroke="green"/>
 </g>
</svg>
```

![Example feImage --- Examples of feImage use](examples/feImage-01.png)

Example of feImage

[View this example as SVG](examples/feImage-01.svg)

### 9.16. Filter primitive [feMerge]
Name:

[`feMerge`]

Categories:

[filter primitive](#filter-primitive)

Content model:

Any number of [descriptive
elements](https://www.w3.org/TR/svg2/struct.html#TermDescriptiveElement),
[feMergeNode](#elementdef-femergenode),
[script](https://www.w3.org/TR/svg2/interact.html#elementdef-script) elements, in any order.

Attributes:

- [core
 attributes](https://www.w3.org/TR/2011/REC-SVG11-20110816/intro.html#TermCoreAttributes)[
 ---
 [[id]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#IDAttribute),
 [[xml:base]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#XMLBaseAttribute),
 [[xml:lang]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#XMLLangAttribute),
 [[xml:space]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#XMLSpaceAttribute)]
- [presentation
 attributes](https://www.w3.org/TR/2008/REC-SVGTiny12-20081222/intro.html#TermPresentationAttribute)[
 ---
 [alignment-baseline](https://www.w3.org/TR/SVG11/text.html#AlignmentBaselineProperty),
 [baseline-shift](https://www.w3.org/TR/SVG11/text.html#BaselineShiftProperty),
 [clip](https://www.w3.org/TR/css-masking-1/#propdef-clip),
 [clip-path](https://www.w3.org/TR/css-masking-1/#propdef-clip-path),
 [clip-rule](https://www.w3.org/TR/css-masking-1/#propdef-clip-rule),
 [color](https://www.w3.org/TR/css3-color/#color0),
 [color-interpolation](https://www.w3.org/TR/svg2/painting.html#ColorInterpolationProperty),
 [color-interpolation-filters](#propdef-color-interpolation-filters),
 [color-rendering](https://www.w3.org/TR/svg2/painting.html#ColorRenderingProperty),
 [cursor](https://www.w3.org/TR/css3-ui/#propdef-cursor),
 [direction](https://www.w3.org/TR/css-writing-modes-3/#propdef-direction),
 [display](https://www.w3.org/TR/css-display-3/#propdef-display),
 [dominant-baseline](https://www.w3.org/TR/SVG11/text.html#DominantBaselineProperty),
 [enable-background](https://www.w3.org/TR/SVG11/filters.html#EnableBackgroundProperty),
 [fill](https://www.w3.org/TR/svg2/painting.html#FillProperty),
 [fill-opacity](https://www.w3.org/TR/svg2/painting.html#FillOpacityProperty),
 [fill-rule](https://www.w3.org/TR/svg2/painting.html#FillRuleProperty),
 [filter](#propdef-filter),
 [flood-color](#propdef-flood-color),
 [flood-opacity](#propdef-flood-opacity),
 [font](https://www.w3.org/TR/css-fonts-3/#propdef-font),
 [font-family](https://www.w3.org/TR/css-fonts-3/#propdef-font-family),
 [font-size](https://www.w3.org/TR/css-fonts-3/#propdef-font-size),
 [font-size-adjust](https://www.w3.org/TR/css-fonts-4/#propdef-font-size-adjust),
 [font-stretch](https://www.w3.org/TR/css-fonts-3/#propdef-font-stretch),
 [font-style](https://www.w3.org/TR/css-fonts-3/#propdef-font-style),
 [font-variant](https://www.w3.org/TR/css-fonts-3/#propdef-font-variant),
 [font-weight](https://www.w3.org/TR/css-fonts-3/#propdef-font-weight),
 [glyph-orientation-horizontal](https://www.w3.org/TR/SVG11/text.html#GlyphOrientationHorizontalProperty),
 [glyph-orientation-vertical](https://www.w3.org/TR/SVG11/text.html#GlyphOrientationVerticalProperty),
 [image-rendering](https://drafts.csswg.org/css-images-3/#propdef-image-rendering),
 [isolation](https://www.w3.org/TR/compositing-1/#propdef-isolation),
 [kerning](https://www.w3.org/TR/SVG11/text.html#KerningProperty),
 [letter-spacing](https://www.w3.org/TR/css-text-3/#propdef-letter-spacing),
 [lighting-color](#propdef-lighting-color),
 [marker](https://www.w3.org/TR/svg2/painting.html#MarkerProperty),
 [marker-end](https://www.w3.org/TR/svg2/painting.html#MarkerEndProperty),
 [marker-mid](https://www.w3.org/TR/svg2/painting.html#MarkerMidProperty),
 [marker-start](https://www.w3.org/TR/svg2/painting.html#MarkerStartProperty),
 [mask](https://www.w3.org/TR/css-masking-1/#propdef-mask),
 [opacity](https://www.w3.org/TR/css-color-4/#propdef-opacity),
 [overflow](https://www.w3.org/TR/css-overflow-3/#propdef-overflow),
 [pointer-events](https://www.w3.org/TR/svg2/interact.html#PointerEventsProperty),
 [shape-rendering](https://www.w3.org/TR/svg2/painting.html#ShapeRenderingProperty),
 [stop-color](https://www.w3.org/TR/svg2/pservers.html#StopColorProperty),
 [stop-opacity](https://www.w3.org/TR/svg2/pservers.html#StopOpacityProperty),
 [stroke](https://www.w3.org/TR/svg2/painting.html#StrokeProperty),
 [stroke-dasharray](https://www.w3.org/TR/svg2/painting.html#StrokeDasharrayProperty),
 [stroke-dashoffset](https://www.w3.org/TR/svg2/painting.html#StrokeDashoffsetProperty),
 [stroke-linecap](https://www.w3.org/TR/svg2/painting.html#StrokeLinecapProperty),
 [stroke-linejoin](https://www.w3.org/TR/svg2/painting.html#StrokeLinejoinProperty),
 [stroke-miterlimit](https://www.w3.org/TR/svg2/painting.html#StrokeMiterlimitProperty),
 [stroke-opacity](https://www.w3.org/TR/svg2/painting.html#StrokeOpacityProperty),
 [stroke-width](https://www.w3.org/TR/svg2/painting.html#StrokeWidthProperty),
 [text-anchor](https://www.w3.org/TR/svg2/text.html#TextAnchorProperty),
 [text-decoration](https://www.w3.org/TR/css-text-decor-3/#propdef-text-decoration),
 [text-rendering](https://www.w3.org/TR/svg2/painting.html#TextRenderingProperty),
 [unicode-bidi](https://www.w3.org/TR/css-writing-modes-3/#propdef-unicode-bidi),
 [visibility](https://www.w3.org/TR/CSS21/visufx.html#propdef-visibility),
 [word-spacing](https://www.w3.org/TR/css-text-3/#propdef-word-spacing),
 [writing-mode](https://www.w3.org/TR/css-writing-modes-4/#propdef-writing-mode)]
- [filter primitive
 attributes](#filter-primitive-attributes)
 [
 ---[x](#element-attrdef-filter-primitive-x),
 [y](#element-attrdef-filter-primitive-y),
 [width](#element-attrdef-filter-primitive-width),
 [height](#element-attrdef-filter-primitive-height),
 [result](#element-attrdef-filter-primitive-result) ]
- [[class]](https://www.w3.org/TR/2011/REC-SVG11-20110816/styling.html#ClassAttribute)
- [[style]](https://www.w3.org/TR/2011/REC-SVG11-20110816/styling.html#StyleAttribute)

DOM Interfaces:

[SVGFEMergeElement](#InterfaceSVGFEMergeElement)

This filter primitive composites input image layers on top of each other
using the *over* operator with *Input1* (corresponding to the first
[feMergeNode](#elementdef-femergenode) child element) on the bottom and the last specified
input, *InputN* (corresponding to the last
[feMergeNode] child element), on top.

Many effects produce a number of intermediate layers in order to create
the final output image. This filter allows us to collapse those into a
single image. Although this could be done by using n-1
Composite-filters, it is more convenient to have this common operation
available in this form, and offers the implementation some additional
flexibility.

Each [feMerge](#elementdef-femerge) element can have any number of
[feMergeNode](#elementdef-femergenode) subelements, each of which has an
[in](#element-attrdef-filter-primitive-in) attribute.

The canonical implementation of feMerge is to render the entire effect
into one RGBA layer, and then render the resulting layer on the output
device. In certain cases (in particular if the output device itself is a
continuous tone device), and since merging is associative, it might be a
sufficient approximation to evaluate the effect one layer at a time and
render each layer individually onto the output device bottom to top.

If the topmost image input is
[SourceGraphic](#attr-valuedef-in-sourcegraphic) and this
[feMerge](#elementdef-femerge) is the last filter primitive in the filter, the
implementation is encouraged to render the layers up to that point, and
then render the
[SourceGraphic] directly from
its vector description on top.

[The example](#intro) at the start of this chapter makes use of the
[feMerge](#elementdef-femerge) filter primitive to composite two intermediate
filter results together.

#### 9.16.1. Merge node [feMergeNode]
Name:

[`feMergeNode`]

Categories:

None.

Content model:

Any number of [descriptive
elements](https://www.w3.org/TR/svg2/struct.html#TermDescriptiveElement),
[animate](https://www.w3.org/TR/SVG11/animate.html#AnimateElement),
[script](https://www.w3.org/TR/svg2/interact.html#elementdef-script),
[set](https://www.w3.org/TR/SVG11/animate.html#SetElement) elements, in any order.

Attributes:

- [core
 attributes](https://www.w3.org/TR/2011/REC-SVG11-20110816/intro.html#TermCoreAttributes)[
 ---
 [[id]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#IDAttribute),
 [[xml:base]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#XMLBaseAttribute),
 [[xml:lang]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#XMLLangAttribute),
 [[xml:space]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#XMLSpaceAttribute)]
- [in](#element-attrdef-filter-primitive-in)

DOM Interfaces:

[SVGFEMergeNodeElement](#InterfaceSVGFEMergeNodeElement)

### 9.17. Filter primitive [feMorphology]
Name:

[`feMorphology`]

Categories:

[filter primitive](#filter-primitive)

Content model:

Any number of [descriptive
elements](https://www.w3.org/TR/svg2/struct.html#TermDescriptiveElement),
[animate](https://www.w3.org/TR/SVG11/animate.html#AnimateElement),
[script](https://www.w3.org/TR/svg2/interact.html#elementdef-script),
[set](https://www.w3.org/TR/SVG11/animate.html#SetElement) elements, in any order.

Attributes:

- [core
 attributes](https://www.w3.org/TR/2011/REC-SVG11-20110816/intro.html#TermCoreAttributes)[
 ---
 [[id]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#IDAttribute),
 [[xml:base]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#XMLBaseAttribute),
 [[xml:lang]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#XMLLangAttribute),
 [[xml:space]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#XMLSpaceAttribute)]
- [presentation
 attributes](https://www.w3.org/TR/2008/REC-SVGTiny12-20081222/intro.html#TermPresentationAttribute)[
 ---
 [alignment-baseline](https://www.w3.org/TR/SVG11/text.html#AlignmentBaselineProperty),
 [baseline-shift](https://www.w3.org/TR/SVG11/text.html#BaselineShiftProperty),
 [clip](https://www.w3.org/TR/css-masking-1/#propdef-clip),
 [clip-path](https://www.w3.org/TR/css-masking-1/#propdef-clip-path),
 [clip-rule](https://www.w3.org/TR/css-masking-1/#propdef-clip-rule),
 [color](https://www.w3.org/TR/css3-color/#color0),
 [color-interpolation](https://www.w3.org/TR/svg2/painting.html#ColorInterpolationProperty),
 [color-interpolation-filters](#propdef-color-interpolation-filters),
 [color-rendering](https://www.w3.org/TR/svg2/painting.html#ColorRenderingProperty),
 [cursor](https://www.w3.org/TR/css3-ui/#propdef-cursor),
 [direction](https://www.w3.org/TR/css-writing-modes-3/#propdef-direction),
 [display](https://www.w3.org/TR/css-display-3/#propdef-display),
 [dominant-baseline](https://www.w3.org/TR/SVG11/text.html#DominantBaselineProperty),
 [enable-background](https://www.w3.org/TR/SVG11/filters.html#EnableBackgroundProperty),
 [fill](https://www.w3.org/TR/svg2/painting.html#FillProperty),
 [fill-opacity](https://www.w3.org/TR/svg2/painting.html#FillOpacityProperty),
 [fill-rule](https://www.w3.org/TR/svg2/painting.html#FillRuleProperty),
 [filter](#propdef-filter),
 [flood-color](#propdef-flood-color),
 [flood-opacity](#propdef-flood-opacity),
 [font](https://www.w3.org/TR/css-fonts-3/#propdef-font),
 [font-family](https://www.w3.org/TR/css-fonts-3/#propdef-font-family),
 [font-size](https://www.w3.org/TR/css-fonts-3/#propdef-font-size),
 [font-size-adjust](https://www.w3.org/TR/css-fonts-4/#propdef-font-size-adjust),
 [font-stretch](https://www.w3.org/TR/css-fonts-3/#propdef-font-stretch),
 [font-style](https://www.w3.org/TR/css-fonts-3/#propdef-font-style),
 [font-variant](https://www.w3.org/TR/css-fonts-3/#propdef-font-variant),
 [font-weight](https://www.w3.org/TR/css-fonts-3/#propdef-font-weight),
 [glyph-orientation-horizontal](https://www.w3.org/TR/SVG11/text.html#GlyphOrientationHorizontalProperty),
 [glyph-orientation-vertical](https://www.w3.org/TR/SVG11/text.html#GlyphOrientationVerticalProperty),
 [image-rendering](https://drafts.csswg.org/css-images-3/#propdef-image-rendering),
 [isolation](https://www.w3.org/TR/compositing-1/#propdef-isolation),
 [kerning](https://www.w3.org/TR/SVG11/text.html#KerningProperty),
 [letter-spacing](https://www.w3.org/TR/css-text-3/#propdef-letter-spacing),
 [lighting-color](#propdef-lighting-color),
 [marker](https://www.w3.org/TR/svg2/painting.html#MarkerProperty),
 [marker-end](https://www.w3.org/TR/svg2/painting.html#MarkerEndProperty),
 [marker-mid](https://www.w3.org/TR/svg2/painting.html#MarkerMidProperty),
 [marker-start](https://www.w3.org/TR/svg2/painting.html#MarkerStartProperty),
 [mask](https://www.w3.org/TR/css-masking-1/#propdef-mask),
 [opacity](https://www.w3.org/TR/css-color-4/#propdef-opacity),
 [overflow](https://www.w3.org/TR/css-overflow-3/#propdef-overflow),
 [pointer-events](https://www.w3.org/TR/svg2/interact.html#PointerEventsProperty),
 [shape-rendering](https://www.w3.org/TR/svg2/painting.html#ShapeRenderingProperty),
 [stop-color](https://www.w3.org/TR/svg2/pservers.html#StopColorProperty),
 [stop-opacity](https://www.w3.org/TR/svg2/pservers.html#StopOpacityProperty),
 [stroke](https://www.w3.org/TR/svg2/painting.html#StrokeProperty),
 [stroke-dasharray](https://www.w3.org/TR/svg2/painting.html#StrokeDasharrayProperty),
 [stroke-dashoffset](https://www.w3.org/TR/svg2/painting.html#StrokeDashoffsetProperty),
 [stroke-linecap](https://www.w3.org/TR/svg2/painting.html#StrokeLinecapProperty),
 [stroke-linejoin](https://www.w3.org/TR/svg2/painting.html#StrokeLinejoinProperty),
 [stroke-miterlimit](https://www.w3.org/TR/svg2/painting.html#StrokeMiterlimitProperty),
 [stroke-opacity](https://www.w3.org/TR/svg2/painting.html#StrokeOpacityProperty),
 [stroke-width](https://www.w3.org/TR/svg2/painting.html#StrokeWidthProperty),
 [text-anchor](https://www.w3.org/TR/svg2/text.html#TextAnchorProperty),
 [text-decoration](https://www.w3.org/TR/css-text-decor-3/#propdef-text-decoration),
 [text-rendering](https://www.w3.org/TR/svg2/painting.html#TextRenderingProperty),
 [unicode-bidi](https://www.w3.org/TR/css-writing-modes-3/#propdef-unicode-bidi),
 [visibility](https://www.w3.org/TR/CSS21/visufx.html#propdef-visibility),
 [word-spacing](https://www.w3.org/TR/css-text-3/#propdef-word-spacing),
 [writing-mode](https://www.w3.org/TR/css-writing-modes-4/#propdef-writing-mode)]
- [filter primitive
 attributes](#filter-primitive-attributes)
 [
 ---[x](#element-attrdef-filter-primitive-x),
 [y](#element-attrdef-filter-primitive-y),
 [width](#element-attrdef-filter-primitive-width),
 [height](#element-attrdef-filter-primitive-height),
 [result](#element-attrdef-filter-primitive-result) ]
- [[class]](https://www.w3.org/TR/2011/REC-SVG11-20110816/styling.html#ClassAttribute)
- [[style]](https://www.w3.org/TR/2011/REC-SVG11-20110816/styling.html#StyleAttribute)
- [in](#element-attrdef-filter-primitive-in)
- [operator](#element-attrdef-femorphology-operator)
- [radius](#element-attrdef-femorphology-radius)

DOM Interfaces:

[SVGFEMorphologyElement](#InterfaceSVGFEMorphologyElement)

This filter primitive performs \"fattening\" or \"thinning\" of artwork.
It is particularly useful for fattening or thinning an alpha channel.

The dilation (or erosion) kernel is a rectangle with a width of
2\**x-radius* and a height of 2\**y-radius*. In dilation, the output
pixel is the individual component-wise maximum of the corresponding
R,G,B,A values in the input image's kernel rectangle. In erosion, the
output pixel is the individual component-wise minimum of the
corresponding R,G,B,A values in the input image's kernel rectangle.

Frequently this operation will take place on alpha-only images, such as
that produced by the built-in input,
[SourceAlpha](#attr-valuedef-in-sourcealpha). In that case, the implementation might want to
optimize the single channel case. This optimization must be omitted if
it leads to privacy concerns of any matter. (See section [Privacy and
Security Considerations](#priv-sec) for more details.)

If the input has infinite extent and is constant (e.g
[FillPaint](#attr-valuedef-in-fillpaint) where the fill is a solid color), this operation
has no effect. If the input has infinite extent and the filter result is
the input to an [feTile](#elementdef-fetile), the filter is evaluated with [periodic boundary
conditions](https://en.wikipedia.org/wiki/Periodic_boundary_conditions).

Because
[feMorphology](#elementdef-femorphology) operates on premultipied color values, it will
always result in color values less than or equal to the alpha channel.

*Attribute definitions:*

[`operator`] = \"*erode \| dilate*\"

: A keyword indicating whether to erode (i.e., thin) or dilate
 (fatten) the source graphic.

 The [initial
 value](https://svgwg.org/svg2-draft/types.html#TermInitialValue) for
 [operator](#element-attrdef-femorphology-operator) is [erode].

 Animatable: yes.

[`radius`] = \"*[\<number-optional-number\>](#typedef-number-optional-number)*\"

: The radius (or radii) for the operation. If two
 [\<number\>](https://www.w3.org/TR/css3-values/#number-value) s are provided, the first number
 represents a x-radius and the second value represents a y-radius. If
 one number is provided, then that value is used for both X and Y.
 The values are in the coordinate system established by attribute
 [primitiveUnits](#element-attrdef-filter-primitiveunits) on the
 [filter](#elementdef-filter) element.

 A negative or zero value disables the effect of the given filter
 primitive (i.e., the result is the filter input image).

 The [initial
 value](https://svgwg.org/svg2-draft/types.html#TermInitialValue) for
 [radius](#element-attrdef-femorphology-radius) is [0].

 Animatable: yes.

``` highlight
<svg width="5cm" height="7cm" viewBox="0 0 700 500"
 xmlns="http://www.w3.org/2000/svg">
 <title>Example feMorphology - Examples of erode and dilate</title>
 <desc>Five text strings drawn as outlines.
 The first is unfiltered. The second and third use 'erode'.
 The fourth and fifth use 'dilate'.</desc>
 <defs>
 <filter id="Erode3">
 <feMorphology operator="erode" in="SourceGraphic" radius="3" />
 </filter>
 <filter id="Erode6">
 <feMorphology operator="erode" in="SourceGraphic" radius="6" />
 </filter>
 <filter id="Dilate3">
 <feMorphology operator="dilate" in="SourceGraphic" radius="3" />
 </filter>
 <filter id="Dilate6">
 <feMorphology operator="dilate" in="SourceGraphic" radius="6" />
 </filter>
 </defs>
 <rect fill="none" stroke="blue" stroke-width="2"
 x="1" y="1" width="698" height="498"/>
 <g isolation="isolate" >
 <g font-family="Verdana" font-size="75"
 fill="none" stroke="black" stroke-width="6" >
 <text x="50" y="90">Unfiltered</text>
 <text x="50" y="180" filter="url(#Erode3)" >Erode radius 3</text>
 <text x="50" y="270" filter="url(#Erode6)" >Erode radius 6</text>
 <text x="50" y="360" filter="url(#Dilate3)" >Dilate radius 3</text>
 <text x="50" y="450" filter="url(#Dilate6)" >Dilate radius 6</text>
 </g>
 </g>
</svg>
```

![Example of feMorphology](examples/feMorphology.png)

Example of feMorphology

[View this example as SVG](examples/feMorphology.svg)

### 9.18. Filter primitive [feOffset]
Name:

[`feOffset`]

Categories:

[filter primitive](#filter-primitive)

Content model:

Any number of [descriptive
elements](https://www.w3.org/TR/svg2/struct.html#TermDescriptiveElement),
[animate](https://www.w3.org/TR/SVG11/animate.html#AnimateElement),
[script](https://www.w3.org/TR/svg2/interact.html#elementdef-script),
[set](https://www.w3.org/TR/SVG11/animate.html#SetElement) elements, in any order.

Attributes:

- [core
 attributes](https://www.w3.org/TR/2011/REC-SVG11-20110816/intro.html#TermCoreAttributes)[
 ---
 [[id]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#IDAttribute),
 [[xml:base]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#XMLBaseAttribute),
 [[xml:lang]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#XMLLangAttribute),
 [[xml:space]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#XMLSpaceAttribute)]
- [presentation
 attributes](https://www.w3.org/TR/2008/REC-SVGTiny12-20081222/intro.html#TermPresentationAttribute)[
 ---
 [alignment-baseline](https://www.w3.org/TR/SVG11/text.html#AlignmentBaselineProperty),
 [baseline-shift](https://www.w3.org/TR/SVG11/text.html#BaselineShiftProperty),
 [clip](https://www.w3.org/TR/css-masking-1/#propdef-clip),
 [clip-path](https://www.w3.org/TR/css-masking-1/#propdef-clip-path),
 [clip-rule](https://www.w3.org/TR/css-masking-1/#propdef-clip-rule),
 [color](https://www.w3.org/TR/css3-color/#color0),
 [color-interpolation](https://www.w3.org/TR/svg2/painting.html#ColorInterpolationProperty),
 [color-interpolation-filters](#propdef-color-interpolation-filters),
 [color-rendering](https://www.w3.org/TR/svg2/painting.html#ColorRenderingProperty),
 [cursor](https://www.w3.org/TR/css3-ui/#propdef-cursor),
 [direction](https://www.w3.org/TR/css-writing-modes-3/#propdef-direction),
 [display](https://www.w3.org/TR/css-display-3/#propdef-display),
 [dominant-baseline](https://www.w3.org/TR/SVG11/text.html#DominantBaselineProperty),
 [enable-background](https://www.w3.org/TR/SVG11/filters.html#EnableBackgroundProperty),
 [fill](https://www.w3.org/TR/svg2/painting.html#FillProperty),
 [fill-opacity](https://www.w3.org/TR/svg2/painting.html#FillOpacityProperty),
 [fill-rule](https://www.w3.org/TR/svg2/painting.html#FillRuleProperty),
 [filter](#propdef-filter),
 [flood-color](#propdef-flood-color),
 [flood-opacity](#propdef-flood-opacity),
 [font](https://www.w3.org/TR/css-fonts-3/#propdef-font),
 [font-family](https://www.w3.org/TR/css-fonts-3/#propdef-font-family),
 [font-size](https://www.w3.org/TR/css-fonts-3/#propdef-font-size),
 [font-size-adjust](https://www.w3.org/TR/css-fonts-4/#propdef-font-size-adjust),
 [font-stretch](https://www.w3.org/TR/css-fonts-3/#propdef-font-stretch),
 [font-style](https://www.w3.org/TR/css-fonts-3/#propdef-font-style),
 [font-variant](https://www.w3.org/TR/css-fonts-3/#propdef-font-variant),
 [font-weight](https://www.w3.org/TR/css-fonts-3/#propdef-font-weight),
 [glyph-orientation-horizontal](https://www.w3.org/TR/SVG11/text.html#GlyphOrientationHorizontalProperty),
 [glyph-orientation-vertical](https://www.w3.org/TR/SVG11/text.html#GlyphOrientationVerticalProperty),
 [image-rendering](https://drafts.csswg.org/css-images-3/#propdef-image-rendering),
 [isolation](https://www.w3.org/TR/compositing-1/#propdef-isolation),
 [kerning](https://www.w3.org/TR/SVG11/text.html#KerningProperty),
 [letter-spacing](https://www.w3.org/TR/css-text-3/#propdef-letter-spacing),
 [lighting-color](#propdef-lighting-color),
 [marker](https://www.w3.org/TR/svg2/painting.html#MarkerProperty),
 [marker-end](https://www.w3.org/TR/svg2/painting.html#MarkerEndProperty),
 [marker-mid](https://www.w3.org/TR/svg2/painting.html#MarkerMidProperty),
 [marker-start](https://www.w3.org/TR/svg2/painting.html#MarkerStartProperty),
 [mask](https://www.w3.org/TR/css-masking-1/#propdef-mask),
 [opacity](https://www.w3.org/TR/css-color-4/#propdef-opacity),
 [overflow](https://www.w3.org/TR/css-overflow-3/#propdef-overflow),
 [pointer-events](https://www.w3.org/TR/svg2/interact.html#PointerEventsProperty),
 [shape-rendering](https://www.w3.org/TR/svg2/painting.html#ShapeRenderingProperty),
 [stop-color](https://www.w3.org/TR/svg2/pservers.html#StopColorProperty),
 [stop-opacity](https://www.w3.org/TR/svg2/pservers.html#StopOpacityProperty),
 [stroke](https://www.w3.org/TR/svg2/painting.html#StrokeProperty),
 [stroke-dasharray](https://www.w3.org/TR/svg2/painting.html#StrokeDasharrayProperty),
 [stroke-dashoffset](https://www.w3.org/TR/svg2/painting.html#StrokeDashoffsetProperty),
 [stroke-linecap](https://www.w3.org/TR/svg2/painting.html#StrokeLinecapProperty),
 [stroke-linejoin](https://www.w3.org/TR/svg2/painting.html#StrokeLinejoinProperty),
 [stroke-miterlimit](https://www.w3.org/TR/svg2/painting.html#StrokeMiterlimitProperty),
 [stroke-opacity](https://www.w3.org/TR/svg2/painting.html#StrokeOpacityProperty),
 [stroke-width](https://www.w3.org/TR/svg2/painting.html#StrokeWidthProperty),
 [text-anchor](https://www.w3.org/TR/svg2/text.html#TextAnchorProperty),
 [text-decoration](https://www.w3.org/TR/css-text-decor-3/#propdef-text-decoration),
 [text-rendering](https://www.w3.org/TR/svg2/painting.html#TextRenderingProperty),
 [unicode-bidi](https://www.w3.org/TR/css-writing-modes-3/#propdef-unicode-bidi),
 [visibility](https://www.w3.org/TR/CSS21/visufx.html#propdef-visibility),
 [word-spacing](https://www.w3.org/TR/css-text-3/#propdef-word-spacing),
 [writing-mode](https://www.w3.org/TR/css-writing-modes-4/#propdef-writing-mode)]
- [filter primitive
 attributes](#filter-primitive-attributes)
 [
 ---[x](#element-attrdef-filter-primitive-x),
 [y](#element-attrdef-filter-primitive-y),
 [width](#element-attrdef-filter-primitive-width),
 [height](#element-attrdef-filter-primitive-height),
 [result](#element-attrdef-filter-primitive-result) ]
- [[class]](https://www.w3.org/TR/2011/REC-SVG11-20110816/styling.html#ClassAttribute)
- [[style]](https://www.w3.org/TR/2011/REC-SVG11-20110816/styling.html#StyleAttribute)
- [in](#element-attrdef-filter-primitive-in)
- [dx](#element-attrdef-feoffset-dx)
- [dy](#element-attrdef-feoffset-dy)

DOM Interfaces:

[SVGFEOffsetElement](#InterfaceSVGFEOffsetElement)

This filter primitive offsets the input image relative to its current
position in the image space by the specified vector.

This is important for effects like drop shadows.

When applying this filter, the destination location may be offset by a
fraction of a pixel in device space. [In this case a high quality viewer
should make use of appropriate interpolation techniques, for example
bilinear or bicubic.] This
is especially recommended for dynamic viewers where this interpolation
provides visually smoother movement of images. For static viewers this
is less of a concern. Close attention should be made to the
[image-rendering](https://drafts.csswg.org/css-images-3/#propdef-image-rendering) property setting to determine the
authors intent.

*Attribute definitions:*

[`dx`] = \"*[\<number\>](https://www.w3.org/TR/css3-values/#number-value)*\"

: The amount to offset the input graphic along the x-axis. The offset
 amount is expressed in the coordinate system established by
 attribute
 [primitiveUnits](#element-attrdef-filter-primitiveunits) on the
 [filter](#elementdef-filter) element.

 The [initial
 value](https://svgwg.org/svg2-draft/types.html#TermInitialValue) for
 [dx](#element-attrdef-feoffset-dx) is [0].

 Animatable: yes.

[`dy`] = \"*[\<number\>](https://www.w3.org/TR/css3-values/#number-value)*\"

: The amount to offset the input graphic along the y-axis. The offset
 amount is expressed in the coordinate system established by
 attribute
 [primitiveUnits](#element-attrdef-filter-primitiveunits) on the
 [filter](#elementdef-filter) element.

 The [initial
 value](https://svgwg.org/svg2-draft/types.html#TermInitialValue) for
 [dy](#element-attrdef-feoffset-dy) is [0].

 Animatable: yes.

[The example](#intro) at the start of this chapter makes use of the
[feOffset](#elementdef-feoffset) filter primitive to offset the drop shadow from the
original source graphic.

### 9.19. Filter primitive [feSpecularLighting]
Name:

[`feSpecularLighting`]

Categories:

[filter primitive](#filter-primitive)

Content model:

Any number of [descriptive
elements](https://www.w3.org/TR/svg2/struct.html#TermDescriptiveElement),
[script](https://www.w3.org/TR/svg2/interact.html#elementdef-script) and exactly one [light
sources](#light-source) element,
in any order.

Attributes:

- [core
 attributes](https://www.w3.org/TR/2011/REC-SVG11-20110816/intro.html#TermCoreAttributes)[
 ---
 [[id]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#IDAttribute),
 [[xml:base]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#XMLBaseAttribute),
 [[xml:lang]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#XMLLangAttribute),
 [[xml:space]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#XMLSpaceAttribute)]
- [presentation
 attributes](https://www.w3.org/TR/2008/REC-SVGTiny12-20081222/intro.html#TermPresentationAttribute)[
 ---
 [alignment-baseline](https://www.w3.org/TR/SVG11/text.html#AlignmentBaselineProperty),
 [baseline-shift](https://www.w3.org/TR/SVG11/text.html#BaselineShiftProperty),
 [clip](https://www.w3.org/TR/css-masking-1/#propdef-clip),
 [clip-path](https://www.w3.org/TR/css-masking-1/#propdef-clip-path),
 [clip-rule](https://www.w3.org/TR/css-masking-1/#propdef-clip-rule),
 [color](https://www.w3.org/TR/css3-color/#color0),
 [color-interpolation](https://www.w3.org/TR/svg2/painting.html#ColorInterpolationProperty),
 [color-interpolation-filters](#propdef-color-interpolation-filters),
 [color-rendering](https://www.w3.org/TR/svg2/painting.html#ColorRenderingProperty),
 [cursor](https://www.w3.org/TR/css3-ui/#propdef-cursor),
 [direction](https://www.w3.org/TR/css-writing-modes-3/#propdef-direction),
 [display](https://www.w3.org/TR/css-display-3/#propdef-display),
 [dominant-baseline](https://www.w3.org/TR/SVG11/text.html#DominantBaselineProperty),
 [enable-background](https://www.w3.org/TR/SVG11/filters.html#EnableBackgroundProperty),
 [fill](https://www.w3.org/TR/svg2/painting.html#FillProperty),
 [fill-opacity](https://www.w3.org/TR/svg2/painting.html#FillOpacityProperty),
 [fill-rule](https://www.w3.org/TR/svg2/painting.html#FillRuleProperty),
 [filter](#propdef-filter),
 [flood-color](#propdef-flood-color),
 [flood-opacity](#propdef-flood-opacity),
 [font](https://www.w3.org/TR/css-fonts-3/#propdef-font),
 [font-family](https://www.w3.org/TR/css-fonts-3/#propdef-font-family),
 [font-size](https://www.w3.org/TR/css-fonts-3/#propdef-font-size),
 [font-size-adjust](https://www.w3.org/TR/css-fonts-4/#propdef-font-size-adjust),
 [font-stretch](https://www.w3.org/TR/css-fonts-3/#propdef-font-stretch),
 [font-style](https://www.w3.org/TR/css-fonts-3/#propdef-font-style),
 [font-variant](https://www.w3.org/TR/css-fonts-3/#propdef-font-variant),
 [font-weight](https://www.w3.org/TR/css-fonts-3/#propdef-font-weight),
 [glyph-orientation-horizontal](https://www.w3.org/TR/SVG11/text.html#GlyphOrientationHorizontalProperty),
 [glyph-orientation-vertical](https://www.w3.org/TR/SVG11/text.html#GlyphOrientationVerticalProperty),
 [image-rendering](https://drafts.csswg.org/css-images-3/#propdef-image-rendering),
 [isolation](https://www.w3.org/TR/compositing-1/#propdef-isolation),
 [kerning](https://www.w3.org/TR/SVG11/text.html#KerningProperty),
 [letter-spacing](https://www.w3.org/TR/css-text-3/#propdef-letter-spacing),
 [lighting-color](#propdef-lighting-color),
 [marker](https://www.w3.org/TR/svg2/painting.html#MarkerProperty),
 [marker-end](https://www.w3.org/TR/svg2/painting.html#MarkerEndProperty),
 [marker-mid](https://www.w3.org/TR/svg2/painting.html#MarkerMidProperty),
 [marker-start](https://www.w3.org/TR/svg2/painting.html#MarkerStartProperty),
 [mask](https://www.w3.org/TR/css-masking-1/#propdef-mask),
 [opacity](https://www.w3.org/TR/css-color-4/#propdef-opacity),
 [overflow](https://www.w3.org/TR/css-overflow-3/#propdef-overflow),
 [pointer-events](https://www.w3.org/TR/svg2/interact.html#PointerEventsProperty),
 [shape-rendering](https://www.w3.org/TR/svg2/painting.html#ShapeRenderingProperty),
 [stop-color](https://www.w3.org/TR/svg2/pservers.html#StopColorProperty),
 [stop-opacity](https://www.w3.org/TR/svg2/pservers.html#StopOpacityProperty),
 [stroke](https://www.w3.org/TR/svg2/painting.html#StrokeProperty),
 [stroke-dasharray](https://www.w3.org/TR/svg2/painting.html#StrokeDasharrayProperty),
 [stroke-dashoffset](https://www.w3.org/TR/svg2/painting.html#StrokeDashoffsetProperty),
 [stroke-linecap](https://www.w3.org/TR/svg2/painting.html#StrokeLinecapProperty),
 [stroke-linejoin](https://www.w3.org/TR/svg2/painting.html#StrokeLinejoinProperty),
 [stroke-miterlimit](https://www.w3.org/TR/svg2/painting.html#StrokeMiterlimitProperty),
 [stroke-opacity](https://www.w3.org/TR/svg2/painting.html#StrokeOpacityProperty),
 [stroke-width](https://www.w3.org/TR/svg2/painting.html#StrokeWidthProperty),
 [text-anchor](https://www.w3.org/TR/svg2/text.html#TextAnchorProperty),
 [text-decoration](https://www.w3.org/TR/css-text-decor-3/#propdef-text-decoration),
 [text-rendering](https://www.w3.org/TR/svg2/painting.html#TextRenderingProperty),
 [unicode-bidi](https://www.w3.org/TR/css-writing-modes-3/#propdef-unicode-bidi),
 [visibility](https://www.w3.org/TR/CSS21/visufx.html#propdef-visibility),
 [word-spacing](https://www.w3.org/TR/css-text-3/#propdef-word-spacing),
 [writing-mode](https://www.w3.org/TR/css-writing-modes-4/#propdef-writing-mode)]
- [filter primitive
 attributes](#filter-primitive-attributes)
 [
 ---[x](#element-attrdef-filter-primitive-x),
 [y](#element-attrdef-filter-primitive-y),
 [width](#element-attrdef-filter-primitive-width),
 [height](#element-attrdef-filter-primitive-height),
 [result](#element-attrdef-filter-primitive-result) ]
- [[class]](https://www.w3.org/TR/2011/REC-SVG11-20110816/styling.html#ClassAttribute)
- [[style]](https://www.w3.org/TR/2011/REC-SVG11-20110816/styling.html#StyleAttribute)
- [in](#element-attrdef-filter-primitive-in)
- [surfaceScale](#element-attrdef-fespecularlighting-surfacescale)
- [specularConstant](#element-attrdef-fespecularlighting-specularconstant)
- [specularExponent](#element-attrdef-fespecularlighting-specularexponent)
- [kernelUnitLength](#element-attrdef-fespecularlighting-kernelunitlength)

DOM Interfaces:

[SVGFESpecularLightingElement](#InterfaceSVGFESpecularLightingElement)

This filter primitive lights a source graphic using the alpha channel as
a bump map. The resulting image is an RGBA image based on the light
color. The lighting calculation follows the standard specular component
of the Blinn-Phong lighting model. The resulting image depends on the
light color, light position and surface geometry of the input bump map.
The result of the lighting calculation is added. The filter primitive
assumes that the viewer is at infinity in the z direction (i.e., the
unit vector in the eye direction is (0,0,1) everywhere).

Note: This filter primitive produces an image which contains the
specular reflection part of the lighting calculation. Such a map is
intended to be combined with a texture from a second filter primitive
using the *add* term of the *arithmetic*
[feComposite](#elementdef-fecomposite) method. Multiple [light
sources](#light-source) can be
simulated by adding several of these light maps before applying it to
the texture image.

The resulting RGBA image is computed as follows:

` S`~`r`~` = k`~`s`~` * pow(N.H, specularExponent) * L`~`r`\~
` S`~`g`~` = k`~`s`~` * pow(N.H, specularExponent) * L`~`g`\~
` S`~`b`~` = k`~`s`~` * pow(N.H, specularExponent) * L`~`b`\~
` S`~`a`~` = max(S`~`r,`~` S`~`g,`~` S`~`b`~`) `

where

k~s~ = specular lighting constant\
N = surface normal unit vector, a function of x and y\
H = \"halfway\" unit vector between eye unit vector and light unit
vector\
\
L~r~,L~g~,L~b~ = RGB components of light

See
[feDiffuseLighting](#elementdef-fediffuselighting) for definition of N and (L~r~, L~g~, L~b~).

The definition of H reflects our assumption of the constant eye vector E
= (0,0,1):

` H = (L + E) / Norm(L+E) `

where L is the light unit vector.

Unlike the
[feDiffuseLighting](#elementdef-fediffuselighting), the
[feSpecularLighting](#elementdef-fespecularlighting) filter produces a non-opaque image. This is due to
the fact that the specular result (S~r~,S~g~,S~b~,S~a~) is meant to be
added to the textured image. The alpha channel of the result is the max
of the color components, so that where the specular light is zero, no
additional coverage is added to the image and a fully white highlight
will add opacity.

The
[feDiffuseLighting](#elementdef-fediffuselighting) and
[feSpecularLighting](#elementdef-fespecularlighting) filters will often be applied together. An
implementation may detect this and calculate both maps in one pass,
instead of two.

*Attribute definitions:*

[`surfaceScale`] = \"*[\<number\>](https://www.w3.org/TR/css3-values/#number-value)*\"

: height of surface when A~in~ = 1.

 The [initial
 value](https://svgwg.org/svg2-draft/types.html#TermInitialValue) for
 [surfaceScale](#element-attrdef-fespecularlighting-surfacescale) is [1].

 Animatable: yes.

[`specularConstant`] = \"*[\<number\>](https://www.w3.org/TR/css3-values/#number-value)*\"

: ks in Phong lighting model. In SVG, this can be any non-negative
 number.

 The [initial
 value](https://svgwg.org/svg2-draft/types.html#TermInitialValue) for
 [specularConstant](#element-attrdef-fespecularlighting-specularconstant) is [1].

 Animatable: yes.

[`specularExponent`] = \"*[\<number\>](https://www.w3.org/TR/css3-values/#number-value)*\"

: Exponent for specular term, larger is more \"shiny\".

 The [initial
 value](https://svgwg.org/svg2-draft/types.html#TermInitialValue) for
 [specularExponent](#element-attrdef-fespecularlighting-specularexponent) is [1].

 Animatable: yes.

[`kernelUnitLength`] = \"*[\<number-optional-number\>](#typedef-number-optional-number)*\"

: The first number is the \<dx\> value. The second number is the
 \<dy\> value.

 If the \<dy\> value is not specified, it defaults to the same value
 as \<dx\>. Indicates the intended distance in current filter units
 (i.e., units as determined by the value of attribute
 [primitiveUnits](#element-attrdef-filter-primitiveunits)) for `dx` and `dy`, respectively, in the
 [surface normal calculation formulas](#SurfaceNormalCalculations).
 By specifying value(s) for
 [kernelUnitLength](#element-attrdef-fespecularlighting-kernelunitlength), the kernel becomes defined in a scalable,
 abstract coordinate system.

 If
 [kernelUnitLength](#element-attrdef-fespecularlighting-kernelunitlength) is not specified, the `dx` and `dy` values
 should represent very small deltas relative to a given `(x,y)`
 position, which might be implemented in some cases as one pixel in
 the intermediate image offscreen bitmap, which is a pixel-based
 coordinate system, and thus potentially not scalable. For some level
 of consistency across display media and user agents, it is necessary
 that a value be provided for
 [kernelUnitLength].

 Animatable: yes.

The light source is defined by one of the child elements
[feDistantLight](#elementdef-fedistantlight),
[fePointLight](#elementdef-fepointlight) or
[feSpotLight](#elementdef-fespotlight). The light color is specified by property
[lighting-color](#propdef-lighting-color).

[The example](#intro) at the start of this chapter makes use of the
[feSpecularLighting](#elementdef-fespecularlighting) filter primitive to achieve a highly reflective, 3D
glowing effect.

### 9.20. Filter primitive [feTile]
Name:

[`feTile`]

Categories:

[filter primitive](#filter-primitive)

Content model:

Any number of [descriptive
elements](https://www.w3.org/TR/svg2/struct.html#TermDescriptiveElement),
[animate](https://www.w3.org/TR/SVG11/animate.html#AnimateElement),
[script](https://www.w3.org/TR/svg2/interact.html#elementdef-script),
[set](https://www.w3.org/TR/SVG11/animate.html#SetElement) elements, in any order.

Attributes:

- [core
 attributes](https://www.w3.org/TR/2011/REC-SVG11-20110816/intro.html#TermCoreAttributes)[
 ---
 [[id]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#IDAttribute),
 [[xml:base]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#XMLBaseAttribute),
 [[xml:lang]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#XMLLangAttribute),
 [[xml:space]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#XMLSpaceAttribute)]
- [presentation
 attributes](https://www.w3.org/TR/2008/REC-SVGTiny12-20081222/intro.html#TermPresentationAttribute)[
 ---
 [alignment-baseline](https://www.w3.org/TR/SVG11/text.html#AlignmentBaselineProperty),
 [baseline-shift](https://www.w3.org/TR/SVG11/text.html#BaselineShiftProperty),
 [clip](https://www.w3.org/TR/css-masking-1/#propdef-clip),
 [clip-path](https://www.w3.org/TR/css-masking-1/#propdef-clip-path),
 [clip-rule](https://www.w3.org/TR/css-masking-1/#propdef-clip-rule),
 [color](https://www.w3.org/TR/css3-color/#color0),
 [color-interpolation](https://www.w3.org/TR/svg2/painting.html#ColorInterpolationProperty),
 [color-interpolation-filters](#propdef-color-interpolation-filters),
 [color-rendering](https://www.w3.org/TR/svg2/painting.html#ColorRenderingProperty),
 [cursor](https://www.w3.org/TR/css3-ui/#propdef-cursor),
 [direction](https://www.w3.org/TR/css-writing-modes-3/#propdef-direction),
 [display](https://www.w3.org/TR/css-display-3/#propdef-display),
 [dominant-baseline](https://www.w3.org/TR/SVG11/text.html#DominantBaselineProperty),
 [enable-background](https://www.w3.org/TR/SVG11/filters.html#EnableBackgroundProperty),
 [fill](https://www.w3.org/TR/svg2/painting.html#FillProperty),
 [fill-opacity](https://www.w3.org/TR/svg2/painting.html#FillOpacityProperty),
 [fill-rule](https://www.w3.org/TR/svg2/painting.html#FillRuleProperty),
 [filter](#propdef-filter),
 [flood-color](#propdef-flood-color),
 [flood-opacity](#propdef-flood-opacity),
 [font](https://www.w3.org/TR/css-fonts-3/#propdef-font),
 [font-family](https://www.w3.org/TR/css-fonts-3/#propdef-font-family),
 [font-size](https://www.w3.org/TR/css-fonts-3/#propdef-font-size),
 [font-size-adjust](https://www.w3.org/TR/css-fonts-4/#propdef-font-size-adjust),
 [font-stretch](https://www.w3.org/TR/css-fonts-3/#propdef-font-stretch),
 [font-style](https://www.w3.org/TR/css-fonts-3/#propdef-font-style),
 [font-variant](https://www.w3.org/TR/css-fonts-3/#propdef-font-variant),
 [font-weight](https://www.w3.org/TR/css-fonts-3/#propdef-font-weight),
 [glyph-orientation-horizontal](https://www.w3.org/TR/SVG11/text.html#GlyphOrientationHorizontalProperty),
 [glyph-orientation-vertical](https://www.w3.org/TR/SVG11/text.html#GlyphOrientationVerticalProperty),
 [image-rendering](https://drafts.csswg.org/css-images-3/#propdef-image-rendering),
 [isolation](https://www.w3.org/TR/compositing-1/#propdef-isolation),
 [kerning](https://www.w3.org/TR/SVG11/text.html#KerningProperty),
 [letter-spacing](https://www.w3.org/TR/css-text-3/#propdef-letter-spacing),
 [lighting-color](#propdef-lighting-color),
 [marker](https://www.w3.org/TR/svg2/painting.html#MarkerProperty),
 [marker-end](https://www.w3.org/TR/svg2/painting.html#MarkerEndProperty),
 [marker-mid](https://www.w3.org/TR/svg2/painting.html#MarkerMidProperty),
 [marker-start](https://www.w3.org/TR/svg2/painting.html#MarkerStartProperty),
 [mask](https://www.w3.org/TR/css-masking-1/#propdef-mask),
 [opacity](https://www.w3.org/TR/css-color-4/#propdef-opacity),
 [overflow](https://www.w3.org/TR/css-overflow-3/#propdef-overflow),
 [pointer-events](https://www.w3.org/TR/svg2/interact.html#PointerEventsProperty),
 [shape-rendering](https://www.w3.org/TR/svg2/painting.html#ShapeRenderingProperty),
 [stop-color](https://www.w3.org/TR/svg2/pservers.html#StopColorProperty),
 [stop-opacity](https://www.w3.org/TR/svg2/pservers.html#StopOpacityProperty),
 [stroke](https://www.w3.org/TR/svg2/painting.html#StrokeProperty),
 [stroke-dasharray](https://www.w3.org/TR/svg2/painting.html#StrokeDasharrayProperty),
 [stroke-dashoffset](https://www.w3.org/TR/svg2/painting.html#StrokeDashoffsetProperty),
 [stroke-linecap](https://www.w3.org/TR/svg2/painting.html#StrokeLinecapProperty),
 [stroke-linejoin](https://www.w3.org/TR/svg2/painting.html#StrokeLinejoinProperty),
 [stroke-miterlimit](https://www.w3.org/TR/svg2/painting.html#StrokeMiterlimitProperty),
 [stroke-opacity](https://www.w3.org/TR/svg2/painting.html#StrokeOpacityProperty),
 [stroke-width](https://www.w3.org/TR/svg2/painting.html#StrokeWidthProperty),
 [text-anchor](https://www.w3.org/TR/svg2/text.html#TextAnchorProperty),
 [text-decoration](https://www.w3.org/TR/css-text-decor-3/#propdef-text-decoration),
 [text-rendering](https://www.w3.org/TR/svg2/painting.html#TextRenderingProperty),
 [unicode-bidi](https://www.w3.org/TR/css-writing-modes-3/#propdef-unicode-bidi),
 [visibility](https://www.w3.org/TR/CSS21/visufx.html#propdef-visibility),
 [word-spacing](https://www.w3.org/TR/css-text-3/#propdef-word-spacing),
 [writing-mode](https://www.w3.org/TR/css-writing-modes-4/#propdef-writing-mode)]
- [filter primitive
 attributes](#filter-primitive-attributes)
 [
 ---[x](#element-attrdef-filter-primitive-x),
 [y](#element-attrdef-filter-primitive-y),
 [width](#element-attrdef-filter-primitive-width),
 [height](#element-attrdef-filter-primitive-height),
 [result](#element-attrdef-filter-primitive-result) ]
- [[class]](https://www.w3.org/TR/2011/REC-SVG11-20110816/styling.html#ClassAttribute)
- [[style]](https://www.w3.org/TR/2011/REC-SVG11-20110816/styling.html#StyleAttribute)
- [in](#element-attrdef-filter-primitive-in)

DOM Interfaces:

[SVGFETileElement](#InterfaceSVGFETileElement)

This filter primitive fills a target rectangle with a repeated, tiled
pattern of an input image. The target rectangle is as large as the
[filter primitive
subregion](#filter-primitive-subregion) established by the
[feTile](#elementdef-fetile) element.

Typically, the input image has been defined with its own [filter
primitive
subregion](#filter-primitive-subregion) in order to define a reference tile.
[feTile](#elementdef-fetile) replicates the reference tile in both X and Y to
completely fill the target rectangle. The top/left corner of each given
tile is at location `(x + i*width, y + j*height)`, where `(x,y)`
represents the top/left of the input image's [filter primitive
subregion], `width` and `height`
represent the width and height of the input image's [filter primitive
subregion], and `i` and `j` can
be any integer value. In most cases, the input image will have a smaller
[filter primitive subregion] than
the [feTile] in order to achieve a repeated
pattern effect.

Implementers must take appropriate measures in constructing the tiled
image to avoid artifacts between tiles, particularly in situations where
the user to device transform includes shear and/or rotation. Unless care
is taken, interpolation can lead to edge pixels in the tile having
opacity values lower or higher than expected due to the interaction of
painting adjacent tiles which each have partial overlap with particular
pixels.

### 9.21. Filter primitive [feTurbulence]
Name:

[`feTurbulence`]

Categories:

[filter primitive](#filter-primitive)

Content model:

Any number of [descriptive
elements](https://www.w3.org/TR/svg2/struct.html#TermDescriptiveElement),
[animate](https://www.w3.org/TR/SVG11/animate.html#AnimateElement),
[script](https://www.w3.org/TR/svg2/interact.html#elementdef-script),
[set](https://www.w3.org/TR/SVG11/animate.html#SetElement) elements, in any order.

Attributes:

- [core
 attributes](https://www.w3.org/TR/2011/REC-SVG11-20110816/intro.html#TermCoreAttributes)[
 ---
 [[id]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#IDAttribute),
 [[xml:base]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#XMLBaseAttribute),
 [[xml:lang]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#XMLLangAttribute),
 [[xml:space]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#XMLSpaceAttribute)]
- [presentation
 attributes](https://www.w3.org/TR/2008/REC-SVGTiny12-20081222/intro.html#TermPresentationAttribute)[
 ---
 [alignment-baseline](https://www.w3.org/TR/SVG11/text.html#AlignmentBaselineProperty),
 [baseline-shift](https://www.w3.org/TR/SVG11/text.html#BaselineShiftProperty),
 [clip](https://www.w3.org/TR/css-masking-1/#propdef-clip),
 [clip-path](https://www.w3.org/TR/css-masking-1/#propdef-clip-path),
 [clip-rule](https://www.w3.org/TR/css-masking-1/#propdef-clip-rule),
 [color](https://www.w3.org/TR/css3-color/#color0),
 [color-interpolation](https://www.w3.org/TR/svg2/painting.html#ColorInterpolationProperty),
 [color-interpolation-filters](#propdef-color-interpolation-filters),
 [color-rendering](https://www.w3.org/TR/svg2/painting.html#ColorRenderingProperty),
 [cursor](https://www.w3.org/TR/css3-ui/#propdef-cursor),
 [direction](https://www.w3.org/TR/css-writing-modes-3/#propdef-direction),
 [display](https://www.w3.org/TR/css-display-3/#propdef-display),
 [dominant-baseline](https://www.w3.org/TR/SVG11/text.html#DominantBaselineProperty),
 [enable-background](https://www.w3.org/TR/SVG11/filters.html#EnableBackgroundProperty),
 [fill](https://www.w3.org/TR/svg2/painting.html#FillProperty),
 [fill-opacity](https://www.w3.org/TR/svg2/painting.html#FillOpacityProperty),
 [fill-rule](https://www.w3.org/TR/svg2/painting.html#FillRuleProperty),
 [filter](#propdef-filter),
 [flood-color](#propdef-flood-color),
 [flood-opacity](#propdef-flood-opacity),
 [font](https://www.w3.org/TR/css-fonts-3/#propdef-font),
 [font-family](https://www.w3.org/TR/css-fonts-3/#propdef-font-family),
 [font-size](https://www.w3.org/TR/css-fonts-3/#propdef-font-size),
 [font-size-adjust](https://www.w3.org/TR/css-fonts-4/#propdef-font-size-adjust),
 [font-stretch](https://www.w3.org/TR/css-fonts-3/#propdef-font-stretch),
 [font-style](https://www.w3.org/TR/css-fonts-3/#propdef-font-style),
 [font-variant](https://www.w3.org/TR/css-fonts-3/#propdef-font-variant),
 [font-weight](https://www.w3.org/TR/css-fonts-3/#propdef-font-weight),
 [glyph-orientation-horizontal](https://www.w3.org/TR/SVG11/text.html#GlyphOrientationHorizontalProperty),
 [glyph-orientation-vertical](https://www.w3.org/TR/SVG11/text.html#GlyphOrientationVerticalProperty),
 [image-rendering](https://drafts.csswg.org/css-images-3/#propdef-image-rendering),
 [isolation](https://www.w3.org/TR/compositing-1/#propdef-isolation),
 [kerning](https://www.w3.org/TR/SVG11/text.html#KerningProperty),
 [letter-spacing](https://www.w3.org/TR/css-text-3/#propdef-letter-spacing),
 [lighting-color](#propdef-lighting-color),
 [marker](https://www.w3.org/TR/svg2/painting.html#MarkerProperty),
 [marker-end](https://www.w3.org/TR/svg2/painting.html#MarkerEndProperty),
 [marker-mid](https://www.w3.org/TR/svg2/painting.html#MarkerMidProperty),
 [marker-start](https://www.w3.org/TR/svg2/painting.html#MarkerStartProperty),
 [mask](https://www.w3.org/TR/css-masking-1/#propdef-mask),
 [opacity](https://www.w3.org/TR/css-color-4/#propdef-opacity),
 [overflow](https://www.w3.org/TR/css-overflow-3/#propdef-overflow),
 [pointer-events](https://www.w3.org/TR/svg2/interact.html#PointerEventsProperty),
 [shape-rendering](https://www.w3.org/TR/svg2/painting.html#ShapeRenderingProperty),
 [stop-color](https://www.w3.org/TR/svg2/pservers.html#StopColorProperty),
 [stop-opacity](https://www.w3.org/TR/svg2/pservers.html#StopOpacityProperty),
 [stroke](https://www.w3.org/TR/svg2/painting.html#StrokeProperty),
 [stroke-dasharray](https://www.w3.org/TR/svg2/painting.html#StrokeDasharrayProperty),
 [stroke-dashoffset](https://www.w3.org/TR/svg2/painting.html#StrokeDashoffsetProperty),
 [stroke-linecap](https://www.w3.org/TR/svg2/painting.html#StrokeLinecapProperty),
 [stroke-linejoin](https://www.w3.org/TR/svg2/painting.html#StrokeLinejoinProperty),
 [stroke-miterlimit](https://www.w3.org/TR/svg2/painting.html#StrokeMiterlimitProperty),
 [stroke-opacity](https://www.w3.org/TR/svg2/painting.html#StrokeOpacityProperty),
 [stroke-width](https://www.w3.org/TR/svg2/painting.html#StrokeWidthProperty),
 [text-anchor](https://www.w3.org/TR/svg2/text.html#TextAnchorProperty),
 [text-decoration](https://www.w3.org/TR/css-text-decor-3/#propdef-text-decoration),
 [text-rendering](https://www.w3.org/TR/svg2/painting.html#TextRenderingProperty),
 [unicode-bidi](https://www.w3.org/TR/css-writing-modes-3/#propdef-unicode-bidi),
 [visibility](https://www.w3.org/TR/CSS21/visufx.html#propdef-visibility),
 [word-spacing](https://www.w3.org/TR/css-text-3/#propdef-word-spacing),
 [writing-mode](https://www.w3.org/TR/css-writing-modes-4/#propdef-writing-mode)]
- [filter primitive
 attributes](#filter-primitive-attributes)
 [
 ---[x](#element-attrdef-filter-primitive-x),
 [y](#element-attrdef-filter-primitive-y),
 [width](#element-attrdef-filter-primitive-width),
 [height](#element-attrdef-filter-primitive-height),
 [result](#element-attrdef-filter-primitive-result) ]
- [[class]](https://www.w3.org/TR/2011/REC-SVG11-20110816/styling.html#ClassAttribute)
- [[style]](https://www.w3.org/TR/2011/REC-SVG11-20110816/styling.html#StyleAttribute)
- [baseFrequency](#element-attrdef-feturbulence-basefrequency)
- [numOctaves](#element-attrdef-feturbulence-numoctaves)
- [seed](#element-attrdef-feturbulence-seed)
- [stitchTiles](#element-attrdef-feturbulence-stitchtiles)
- [type](#element-attrdef-feturbulence-type)

DOM Interfaces:

[SVGFETurbulenceElement](#InterfaceSVGFETurbulenceElement)

This filter primitive creates an image using the Perlin turbulence
function. It allows the synthesis of artificial textures like clouds or
marble. For a detailed description the of the Perlin turbulence
function, see \"Texturing and Modeling\"
[\[TaM\]](#biblio-tam). The resulting image will
fill the entire [filter primitive
subregion](#filter-primitive-subregion) for this filter primitive.

It is possible to create bandwidth-limited noise by synthesizing only
one octave.

The C code below shows the exact algorithm used for this filter effect.
The [filter primitive
subregion](#filter-primitive-subregion) is to be passed as the arguments fTileX, fTileY,
fTileWidth and fTileHeight.

For fractalSum, you get a turbFunctionResult that is aimed at a range of
-1 to 1 (the actual result might exceed this range in some cases). To
convert to a color or alpha value, use the formula
`colorValue = (turbFunctionResult + 1) / 2`, then clamp to the range 0
to 1.

For turbulence, you get a turbFunctionResult that is aimed at a range of
0 to 1 (the actual result might exceed this range in some cases). To
convert to a color or alpha value, use the formula
`colorValue = turbFunctionResult`, then clamp to the range 0 to 1.

The following order is used for applying the pseudo random numbers. An
initial seed value is computed based on the
[seed](#element-attrdef-feturbulence-seed) attribute. Then the implementation computes
the lattice points for R, then continues getting additional pseudo
random numbers relative to the last generated pseudo random number and
computes the lattice points for G, and so on for B and A.

The generated color and alpha values are in the color space determined
by the
[color-interpolation-filters](#propdef-color-interpolation-filters) property:

``` svgsamplecompressed
/* Produces results in the range [1, 2**31 - 2].
Algorithm is: r = (a * r) mod m
where a = 16807 and m = 2**31 - 1 = 2147483647
See [Park & Miller], CACM vol. 31 no. 10 p. 1195, Oct. 1988
To test: the algorithm should produce the result 1043618065
as the 10,000th generated number if the original seed is 1.
*/
#define RAND_m 2147483647 /* 2**31 - 1 */
#define RAND_a 16807 /* 7**5; primitive root of m */
#define RAND_q 127773 /* m / a */
#define RAND_r 2836 /* m % a */
long setup_seed(long lSeed)
{
 if (lSeed <= 0) lSeed = -(lSeed % (RAND_m - 1)) + 1;
 if (lSeed > RAND_m - 1) lSeed = RAND_m - 1;
 return lSeed;
}
long random(long lSeed)
{
 long result;
 result = RAND_a * (lSeed % RAND_q) - RAND_r * (lSeed / RAND_q);
 if (result <= 0) result += RAND_m;
 return result;
}
#define BSize 0x100
#define BM 0xff
#define PerlinN 0x1000
#define NP 12 /* 2^PerlinN */
#define NM 0xfff
static uLatticeSelector[BSize + BSize + 2];
static double fGradient[4][BSize + BSize + 2][2];
struct StitchInfo
{
 int nWidth; // How much to subtract to wrap for stitching.
 int nHeight;
 int nWrapX; // Minimum value to wrap.
 int nWrapY;
};
static void init(long lSeed)
{
 double s;
 int i, j, k;
 lSeed = setup_seed(lSeed);
 for(k = 0; k < 4; k++)
 {
 for(i = 0; i < BSize; i++)
 {
 uLatticeSelector[i] = i;
 do {
 for (j = 0; j < 2; j++)
 fGradient[k][i][j] = (double)(((lSeed = random(lSeed)) % (BSize + BSize)) - BSize) / BSize;
 } while(fGradient[k][i][0] == 0 && fGradient[k][i][1] == 0);
 s = double(sqrt(fGradient[k][i][0] * fGradient[k][i][0] + fGradient[k][i][1] * fGradient[k][i][1]));
 if (s > 1) {
 i--; // discard the current random vector; try it again.
 continue;
 }
 fGradient[k][i][0] /= s;
 fGradient[k][i][1] /= s;
 }
 }
 while(--i)
 {
 k = uLatticeSelector[i];
 uLatticeSelector[i] = uLatticeSelector[j = (lSeed = random(lSeed)) % BSize];
 uLatticeSelector[j] = k;
 }
 for(i = 0; i < BSize + 2; i++)
 {
 uLatticeSelector[BSize + i] = uLatticeSelector[i];
 for(k = 0; k < 4; k++)
 for(j = 0; j < 2; j++)
 fGradient[k][BSize + i][j] = fGradient[k][i][j];
 }
}
#define s_curve(t) ( t * t * (3. - 2. * t) )
#define lerp(t, a, b) ( a + t * (b - a) )
double noise2(int nColorChannel, double vec[2], StitchInfo *pStitchInfo)
{
 int bx0, bx1, by0, by1, b00, b10, b01, b11;
 double rx0, rx1, ry0, ry1, *q, sx, sy, a, b, t, u, v;
 register i, j;
 t = vec[0] + PerlinN;
 bx0 = (int)t;
 bx1 = bx0+1;
 rx0 = t - (int)t;
 rx1 = rx0 - 1.0f;
 t = vec[1] + PerlinN;
 by0 = (int)t;
 by1 = by0+1;
 ry0 = t - (int)t;
 ry1 = ry0 - 1.0f;
 // If stitching, adjust lattice points accordingly.
 if(pStitchInfo != NULL)
 {
 if(bx0 >= pStitchInfo->nWrapX)
 bx0 -= pStitchInfo->nWidth;
 if(bx1 >= pStitchInfo->nWrapX)
 bx1 -= pStitchInfo->nWidth;
 if(by0 >= pStitchInfo->nWrapY)
 by0 -= pStitchInfo->nHeight;
 if(by1 >= pStitchInfo->nWrapY)
 by1 -= pStitchInfo->nHeight;
 }
 bx0 &= BM;
 bx1 &= BM;
 by0 &= BM;
 by1 &= BM;
 i = uLatticeSelector[bx0];
 j = uLatticeSelector[bx1];
 b00 = uLatticeSelector[i + by0];
 b10 = uLatticeSelector[j + by0];
 b01 = uLatticeSelector[i + by1];
 b11 = uLatticeSelector[j + by1];
 sx = double(s_curve(rx0));
 sy = double(s_curve(ry0));
 q = fGradient[nColorChannel][b00]; u = rx0 * q[0] + ry0 * q[1];
 q = fGradient[nColorChannel][b10]; v = rx1 * q[0] + ry0 * q[1];
 a = lerp(sx, u, v);
 q = fGradient[nColorChannel][b01]; u = rx0 * q[0] + ry1 * q[1];
 q = fGradient[nColorChannel][b11]; v = rx1 * q[0] + ry1 * q[1];
 b = lerp(sx, u, v);
 return lerp(sy, a, b);
}
double turbulence(int nColorChannel, double *point, double fBaseFreqX, double fBaseFreqY,
 int nNumOctaves, bool bFractalSum, bool bDoStitching,
 double fTileX, double fTileY, double fTileWidth, double fTileHeight)
{
 StitchInfo stitch;
 StitchInfo *pStitchInfo = NULL; // Not stitching when NULL.
 // Adjust the base frequencies if necessary for stitching.
 if(bDoStitching)
 {
 // When stitching tiled turbulence, the frequencies must be adjusted
 // so that the tile borders will be continuous.
 if(fBaseFreqX != 0.0)
 {
 double fLoFreq = double(floor(fTileWidth * fBaseFreqX)) / fTileWidth;
 double fHiFreq = double(ceil(fTileWidth * fBaseFreqX)) / fTileWidth;
 if(fBaseFreqX / fLoFreq < fHiFreq / fBaseFreqX)
 fBaseFreqX = fLoFreq;
 else
 fBaseFreqX = fHiFreq;
 }
 if(fBaseFreqY != 0.0)
 {
 double fLoFreq = double(floor(fTileHeight * fBaseFreqY)) / fTileHeight;
 double fHiFreq = double(ceil(fTileHeight * fBaseFreqY)) / fTileHeight;
 if(fBaseFreqY / fLoFreq < fHiFreq / fBaseFreqY)
 fBaseFreqY = fLoFreq;
 else
 fBaseFreqY = fHiFreq;
 }
 // Set up initial stitch values.
 pStitchInfo = &stitch;
 stitch.nWidth = int(fTileWidth * fBaseFreqX + 0.5f);
 stitch.nWrapX = fTileX * fBaseFreqX + PerlinN + stitch.nWidth;
 stitch.nHeight = int(fTileHeight * fBaseFreqY + 0.5f);
 stitch.nWrapY = fTileY * fBaseFreqY + PerlinN + stitch.nHeight;
 }
 double fSum = 0.0f;
 double vec[2];
 vec[0] = point[0] * fBaseFreqX;
 vec[1] = point[1] * fBaseFreqY;
 double ratio = 1;
 for(int nOctave = 0; nOctave < nNumOctaves; nOctave++)
 {
 if(bFractalSum)
 fSum += double(noise2(nColorChannel, vec, pStitchInfo) / ratio);
 else
 fSum += double(fabs(noise2(nColorChannel, vec, pStitchInfo)) / ratio);
 vec[0] *= 2;
 vec[1] *= 2;
 ratio *= 2;
 if(pStitchInfo != NULL)
 {
 // Update stitch values. Subtracting PerlinN before the multiplication and
 // adding it afterward simplifies to subtracting it once.
 stitch.nWidth *= 2;
 stitch.nWrapX = 2 * stitch.nWrapX - PerlinN;
 stitch.nHeight *= 2;
 stitch.nWrapY = 2 * stitch.nWrapY - PerlinN;
 }
 }
 return fSum;
}
```

*Attribute definitions:*

[`baseFrequency`] = \"*[\<number-optional-number\>](#typedef-number-optional-number)*\"

: The base frequency (frequencies) parameter(s) for the noise
 function. If two
 [\<number\>](https://www.w3.org/TR/css3-values/#number-value)s are provided, the first number
 represents a base frequency in the X direction and the second value
 represents a base frequency in the Y direction. If one number is
 provided, then that value is used for both X and Y.

 The [initial
 value](https://svgwg.org/svg2-draft/types.html#TermInitialValue) for
 [baseFrequency](#element-attrdef-feturbulence-basefrequency) is [0].

 Negative values are
 [unsupported](https://www.w3.org/TR/2008/REC-SVGTiny12-20081222/intro.html#TermUnsupportedValue).

 Animatable: yes.

[`numOctaves`] = \"*[\<integer\>](https://www.w3.org/TR/css3-values/#integer-value)*\"

: The numOctaves parameter for the noise function.

 The [initial
 value](https://svgwg.org/svg2-draft/types.html#TermInitialValue) for
 [numOctaves](#element-attrdef-feturbulence-numoctaves) is [1].

 Negative values are
 [unsupported](https://www.w3.org/TR/2008/REC-SVGTiny12-20081222/intro.html#TermUnsupportedValue).

 Animatable: yes.

 Note: The contribution of each additional octave to the color and
 alpha values in the final image is one-half of the preceding octave.
 At some point, the contribution of additional octaves becomes
 smaller than the color resolution for a given color depth. UAs may
 clamp the specified value for numOctaves during the processing
 depending on the supported color depth. (For example: For a color
 depth of 8 bits per channel, the UA may clamp the value of
 numOctaves to 9.)

[`seed`] = \"*[\<number\>](https://www.w3.org/TR/css3-values/#number-value)*\"

: The starting number for the pseudo random number generator.

 The [initial
 value](https://svgwg.org/svg2-draft/types.html#TermInitialValue) for
 [seed](#element-attrdef-feturbulence-seed) is [0].

 When the seed number is handed over to the algorithm above it must
 first be truncated, i.e. rounded to the closest integer value
 towards zero.

 Animatable: yes.

[`stitchTiles`] = \"*stitch \| noStitch*\"

: If `stitchTiles="noStitch"`, no attempt is made to achieve smooth
 transitions at the border of tiles which contain a turbulence
 function. Sometimes the result will show clear discontinuities at
 the tile borders.

 If `stitchTiles="stitch"`, then the user agent will automatically
 adjust baseFrequency-x and baseFrequency-y values such that the
 [feTurbulence](#elementdef-feturbulence) node's width and height (i.e., the width and
 height of the current subregion) contains an integral number of the
 Perlin tile width and height for the first octave. The baseFrequency
 will be adjusted up or down depending on which way has the smallest
 relative (not absolute) change as follows: Given the frequency,
 calculate `lowFreq=floor(width*frequency)/width` and
 `hiFreq=ceil(width*frequency)/width`. If frequency/lowFreq \<
 hiFreq/frequency then use lowFreq, else use hiFreq. While generating
 turbulence values, generate lattice vectors as normal for Perlin
 Noise, except for those lattice points that lie on the right or
 bottom edges of the active area (the size of the resulting tile). In
 those cases, copy the lattice vector from the opposite edge of the
 active area.

 The [initial
 value](https://svgwg.org/svg2-draft/types.html#TermInitialValue) for
 [stitchTiles](#element-attrdef-feturbulence-stitchtiles) is [noStitch].

 Animatable: yes.

[`type`] = \"*fractalNoise \| turbulence*\"

: Indicates whether the filter primitive should perform a noise or
 turbulence function.

 The [initial
 value](https://svgwg.org/svg2-draft/types.html#TermInitialValue) for
 [type](#element-attrdef-feturbulence-type) is [turbulence].

 Animatable: yes.

``` highlight
<svg width="450px" height="325px" viewBox="0 0 450 325"
 xmlns="http://www.w3.org/2000/svg">
 <title>Example feTurbulence - Examples of feTurbulence operations</title>
 <desc>Six rectangular areas showing the effects of
 various parameter settings for feTurbulence.</desc>
 <g font-family="Verdana" text-anchor="middle" font-size="10" >
 <defs>
 <filter id="Turb1" filterUnits="objectBoundingBox"
 x="0%" y="0%" width="100%" height="100%">
 <feTurbulence type="turbulence" baseFrequency="0.05" numOctaves="2"/>
 </filter>
 <filter id="Turb2" filterUnits="objectBoundingBox"
 x="0%" y="0%" width="100%" height="100%">
 <feTurbulence type="turbulence" baseFrequency="0.1" numOctaves="2"/>
 </filter>
 <filter id="Turb3" filterUnits="objectBoundingBox"
 x="0%" y="0%" width="100%" height="100%">
 <feTurbulence type="turbulence" baseFrequency="0.05" numOctaves="8"/>
 </filter>
 <filter id="Turb4" filterUnits="objectBoundingBox"
 x="0%" y="0%" width="100%" height="100%">
 <feTurbulence type="fractalNoise" baseFrequency="0.1" numOctaves="4"/>
 </filter>
 <filter id="Turb5" filterUnits="objectBoundingBox"
 x="0%" y="0%" width="100%" height="100%">
 <feTurbulence type="fractalNoise" baseFrequency="0.4" numOctaves="4"/>
 </filter>
 <filter id="Turb6" filterUnits="objectBoundingBox"
 x="0%" y="0%" width="100%" height="100%">
 <feTurbulence type="fractalNoise" baseFrequency="0.1" numOctaves="1"/>
 </filter>
 </defs>

 <rect x="1" y="1" width="448" height="323"
 fill="none" stroke="blue" stroke-width="1" />

 <rect x="25" y="25" width="100" height="75" filter="url(#Turb1)" />
 <text x="75" y="117">type=turbulence</text>
 <text x="75" y="129">baseFrequency=0.05</text>
 <text x="75" y="141">numOctaves=2</text>

 <rect x="175" y="25" width="100" height="75" filter="url(#Turb2)" />
 <text x="225" y="117">type=turbulence</text>
 <text x="225" y="129">baseFrequency=0.1</text>
 <text x="225" y="141">numOctaves=2</text>

 <rect x="325" y="25" width="100" height="75" filter="url(#Turb3)" />
 <text x="375" y="117">type=turbulence</text>
 <text x="375" y="129">baseFrequency=0.05</text>
 <text x="375" y="141">numOctaves=8</text>

 <rect x="25" y="180" width="100" height="75" filter="url(#Turb4)" />
 <text x="75" y="272">type=fractalNoise</text>
 <text x="75" y="284">baseFrequency=0.1</text>
 <text x="75" y="296">numOctaves=4</text>

 <rect x="175" y="180" width="100" height="75" filter="url(#Turb5)" />
 <text x="225" y="272">type=fractalNoise</text>
 <text x="225" y="284">baseFrequency=0.4</text>
 <text x="225" y="296">numOctaves=4</text>

 <rect x="325" y="180" width="100" height="75" filter="url(#Turb6)" />
 <text x="375" y="272">type=fractalNoise</text>
 <text x="375" y="284">baseFrequency=0.1</text>
 <text x="375" y="296">numOctaves=1</text>
 </g>
</svg>
```

![Example of feTurbulence](examples/feTurbulence.png)

Example of feTurbulence

[View this example as SVG](examples/feTurbulence.svg)

## 10. The [color-interpolation-filters property]
The description of the
[color-interpolation-filters](#propdef-color-interpolation-filters) property is as follows:

Name:

[color-interpolation-filters]

[Value:](https://drafts.csswg.org/css-values/#value-defs)

auto
[\|](https://www.w3.org/TR/css-values-4/#comb-one) sRGB [\|] linearRGB

[Initial:](https://drafts.csswg.org/css-cascade/#initial-values)

linearRGB

Applies to:

All [filter primitives](#filter-primitive)

[Inherited:](https://drafts.csswg.org/css-cascade/#inherited-property)

yes

[Percentages:](https://drafts.csswg.org/css-values/#percentages)

n/a

[Computed value:](https://drafts.csswg.org/css-cascade/#computed)

as specified

Canonical order:

per grammar

Media:

visual

[Animatable:](https://drafts.csswg.org/web-animations/#animation-type)

no

[auto(#valdef-color-interpolation-filters-auto)]

: Indicates that the user agent can choose either the
 [sRGB](#valdef-color-interpolation-filters-srgb) or
 [linearRGB](#valdef-color-interpolation-filters-linearrgb) spaces for filter effects color operations.
 This option indicates that the author doesn't require that color
 operations occur in a particular color space.

[sRGB]

: Indicates that filter effects color operations should occur in the
 sRGB color space.

[linearRGB]

: Indicates that filter effects color operations should occur in the
 linearized RGB color space.

The
[color-interpolation-filters](#propdef-color-interpolation-filters) property specifies the color space for
imaging operations performed via filter effects.

Note: The
[color-interpolation-filters](#propdef-color-interpolation-filters) property just has an affect on filter
operations. Therefore, it has no effect on filter primitives like
[feOffset](#elementdef-feoffset),
[feImage](#elementdef-feimage),
[feTile](#elementdef-fetile) or
[feFlood](#elementdef-feflood).

Note: The
[color-interpolation-filters](#propdef-color-interpolation-filters) has a different initial value than
[color-interpolation](https://www.w3.org/TR/svg2/painting.html#ColorInterpolationProperty).
[color-interpolation-filters] has an initial value of
[linearRGB](#valdef-color-interpolation-filters-linearrgb), where as
[color-interpolation]
has an initial value of
[sRGB](#valdef-color-interpolation-filters-srgb). Thus, in the default case, filter effects
operations occur in the linearRGB color space, whereas all other color
interpolations occur by default in the sRGB color space.

Note: The
[color-interpolation-filters](#propdef-color-interpolation-filters) property has no affect on Filter
Functions, which operate in the sRGB color space.

The
[color-interpolation-filters](#propdef-color-interpolation-filters) property is a [presentation
attribute](https://www.w3.org/TR/2011/REC-SVG11-20110816/intro.html#TermPresentationAttribute)
for SVG elements.

## 11. Light source elements and properties

### 11.1. Introduction

The following sections define the elements that define a [light
source],
[feDistantLight](#elementdef-fedistantlight),
[fePointLight](#elementdef-fepointlight) and
[feSpotLight](#elementdef-fespotlight), and property
[lighting-color](#propdef-lighting-color), which defines the color of the light.

### 11.2. Light source [feDistantLight]
Name:

[`feDistantLight`]

Categories:

[light source](#light-source)

Content model:

Any number of [descriptive
elements](https://www.w3.org/TR/svg2/struct.html#TermDescriptiveElement),
[animate](https://www.w3.org/TR/SVG11/animate.html#AnimateElement),
[script](https://www.w3.org/TR/svg2/interact.html#elementdef-script),
[set](https://www.w3.org/TR/SVG11/animate.html#SetElement) elements, in any order.

Attributes:

- [core
 attributes](https://www.w3.org/TR/2011/REC-SVG11-20110816/intro.html#TermCoreAttributes)[
 ---
 [[id]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#IDAttribute),
 [[xml:base]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#XMLBaseAttribute),
 [[xml:lang]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#XMLLangAttribute),
 [[xml:space]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#XMLSpaceAttribute)]
- [azimuth](#element-attrdef-fedistantlight-azimuth)
- [elevation](#element-attrdef-fedistantlight-elevation)

DOM Interfaces:

[SVGFEDistantLightElement](#InterfaceSVGFEDistantLightElement)

*Attribute definitions:*

[`azimuth`] = \"*[\<number\>](https://www.w3.org/TR/css3-values/#number-value)*\"

: Direction angle for the light source on the XY plane (clockwise), in
 degrees from the x axis.

 The [initial
 value](https://svgwg.org/svg2-draft/types.html#TermInitialValue) for
 [azimuth](#element-attrdef-fedistantlight-azimuth) is [0].

 Animatable: yes.

[`elevation`] = \"*[\<number\>](https://www.w3.org/TR/css3-values/#number-value)*\"

: Direction angle for the light source from the XY plane towards the
 Z-axis, in degrees. Note that the positive Z-axis points towards the
 viewer.

 The [initial
 value](https://svgwg.org/svg2-draft/types.html#TermInitialValue) for
 [elevation](#element-attrdef-fedistantlight-elevation) is [0].

 Animatable: yes.

The following diagram illustrates the angles which
[azimuth](#element-attrdef-fedistantlight-azimuth) and
[elevation](#element-attrdef-fedistantlight-elevation) represent in an XYZ coordinate system.

![Angles which azimuth and elevation
represent](examples/azimuth-elevation.svg){height="360" width="480"}

Angles which azimuth and elevation represent

### 11.3. Light source [fePointLight]
Name:

[`fePointLight`]

Categories:

[light source](#light-source)

Content model:

Any number of [descriptive
elements](https://www.w3.org/TR/svg2/struct.html#TermDescriptiveElement),
[animate](https://www.w3.org/TR/SVG11/animate.html#AnimateElement),
[script](https://www.w3.org/TR/svg2/interact.html#elementdef-script),
[set](https://www.w3.org/TR/SVG11/animate.html#SetElement) elements, in any order.

Attributes:

- [core
 attributes](https://www.w3.org/TR/2011/REC-SVG11-20110816/intro.html#TermCoreAttributes)[
 ---
 [[id]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#IDAttribute),
 [[xml:base]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#XMLBaseAttribute),
 [[xml:lang]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#XMLLangAttribute),
 [[xml:space]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#XMLSpaceAttribute)]
- [x](#element-attrdef-fepointlight-x)
- [y](#element-attrdef-fepointlight-y)
- [z](#element-attrdef-fepointlight-z)

DOM Interfaces:

[SVGFEPointLightElement](#InterfaceSVGFEPointLightElement)

*Attribute definitions:*

[`x`] = \"*[\<number\>](https://www.w3.org/TR/css3-values/#number-value)*\"

: X location for the light source in the coordinate system established
 by attribute
 [primitiveUnits](#element-attrdef-filter-primitiveunits) on the
 [filter](#elementdef-filter) element.

 The [initial
 value](https://svgwg.org/svg2-draft/types.html#TermInitialValue) for
 [x](#element-attrdef-fepointlight-x) is [0].

 Animatable: yes.

[`y`] = \"*[\<number\>](https://www.w3.org/TR/css3-values/#number-value)*\"

: Y location for the light source in the coordinate system established
 by attribute
 [primitiveUnits](#element-attrdef-filter-primitiveunits) on the
 [filter](#elementdef-filter) element.

 The [initial
 value](https://svgwg.org/svg2-draft/types.html#TermInitialValue) for
 [y](#element-attrdef-fepointlight-y) is [0].

 Animatable: yes.

[`z`] = \"*[\<number\>](https://www.w3.org/TR/css3-values/#number-value)*\"

: Z location for the light source in the coordinate system established
 by attribute
 [primitiveUnits](#element-attrdef-filter-primitiveunits) on the
 [filter](#elementdef-filter) element, assuming that, in the initial [local
 coordinate
 system](https://www.w3.org/TR/css-transforms-1/#local-coordinate-system) , the positive Z-axis comes out towards the person
 viewing the content and assuming that one unit along the Z-axis
 equals [one unit in X and
 Y](https://www.w3.org/TR/SVG11/coords.html#Units_viewport_percentage).

 The [initial
 value](https://svgwg.org/svg2-draft/types.html#TermInitialValue) for
 [z](#element-attrdef-fepointlight-z) is [0].

 Animatable: yes.

### 11.4. Light source [feSpotLight]
Name:

[`feSpotLight`]

Categories:

[light source](#light-source)

Content model:

Any number of [descriptive
elements](https://www.w3.org/TR/svg2/struct.html#TermDescriptiveElement),
[animate](https://www.w3.org/TR/SVG11/animate.html#AnimateElement),
[script](https://www.w3.org/TR/svg2/interact.html#elementdef-script),
[set](https://www.w3.org/TR/SVG11/animate.html#SetElement) elements, in any order.

Attributes:

- [core
 attributes](https://www.w3.org/TR/2011/REC-SVG11-20110816/intro.html#TermCoreAttributes)[
 ---
 [[id]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#IDAttribute),
 [[xml:base]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#XMLBaseAttribute),
 [[xml:lang]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#XMLLangAttribute),
 [[xml:space]](https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#XMLSpaceAttribute)]
- [x](#element-attrdef-fespotlight-x)
- [y](#element-attrdef-fespotlight-y)
- [z](#element-attrdef-fespotlight-z)
- [pointsAtX](#element-attrdef-fespotlight-pointsatx)
- [pointsAtY](#element-attrdef-fespotlight-pointsaty)
- [pointsAtZ](#element-attrdef-fespotlight-pointsatz)
- [specularExponent](#element-attrdef-fespotlight-specularexponent)
- [limitingConeAngle](#element-attrdef-fespotlight-limitingconeangle)

DOM Interfaces:

[SVGFESpotLightElement](#InterfaceSVGFESpotLightElement)

*Attribute definitions:*

[`x`] = \"*[\<number\>](https://www.w3.org/TR/css3-values/#number-value)*\"

: X location for the light source in the coordinate system established
 by attribute
 [primitiveUnits](#element-attrdef-filter-primitiveunits) on the
 [filter](#elementdef-filter) element.

 The [initial
 value](https://svgwg.org/svg2-draft/types.html#TermInitialValue) for
 [x](#element-attrdef-fespotlight-x) is [0].

 Animatable: yes.

[`y`] = \"*[\<number\>](https://www.w3.org/TR/css3-values/#number-value)*\"

: Y location for the light source in the coordinate system established
 by attribute
 [primitiveUnits](#element-attrdef-filter-primitiveunits) on the
 [filter](#elementdef-filter) element.

 The [initial
 value](https://svgwg.org/svg2-draft/types.html#TermInitialValue) for
 [y](#element-attrdef-fespotlight-y) is [0].

 Animatable: yes.

[`z`] = \"*[\<number\>](https://www.w3.org/TR/css3-values/#number-value)*\"

: Z location for the light source in the coordinate system established
 by attribute
 [primitiveUnits](#element-attrdef-filter-primitiveunits) on the
 [filter](#elementdef-filter) element, assuming that, in the initial [local
 coordinate
 system](https://www.w3.org/TR/css-transforms-1/#local-coordinate-system), the positive Z-axis comes out towards the person
 viewing the content and assuming that one unit along the Z-axis
 equals [one unit in X and
 Y](https://www.w3.org/TR/SVG11/coords.html#Units_viewport_percentage).

 The [initial
 value](https://svgwg.org/svg2-draft/types.html#TermInitialValue) for
 [z](#element-attrdef-fespotlight-z) is [0].

 Animatable: yes.

[`pointsAtX`] = \"*[\<number\>](https://www.w3.org/TR/css3-values/#number-value)*\"

: X location in the coordinate system established by attribute
 [primitiveUnits](#element-attrdef-filter-primitiveunits) on the
 [filter](#elementdef-filter) element of the point at which the light source
 is pointing.

 The [initial
 value](https://svgwg.org/svg2-draft/types.html#TermInitialValue) for
 [pointsAtX](#element-attrdef-fespotlight-pointsatx) is [0].

 Animatable: yes.

[`pointsAtY`] = \"*[\<number\>](https://www.w3.org/TR/css3-values/#number-value)*\"

: Y location in the coordinate system established by attribute
 [primitiveUnits](#element-attrdef-filter-primitiveunits) on the
 [filter](#elementdef-filter) element of the point at which the light source
 is pointing.

 The [initial
 value](https://svgwg.org/svg2-draft/types.html#TermInitialValue) for
 [pointsAtY](#element-attrdef-fespotlight-pointsaty) is [0].

 Animatable: yes.

[`pointsAtZ`] = \"*[\<number\>](https://www.w3.org/TR/css3-values/#number-value)*\"

: Z location in the coordinate system established by the attribute
 [primitiveUnits](#element-attrdef-filter-primitiveunits) on the
 [filter](#elementdef-filter) element of the point at which the light source
 is pointing, assuming that, in the initial [local coordinate
 system](https://www.w3.org/TR/css-transforms-1/#local-coordinate-system), the positive Z-axis comes out towards the person
 viewing the content and assuming that one unit along the Z-axis
 equals [one unit in X and
 Y](https://www.w3.org/TR/SVG11/coords.html#Units_viewport_percentage).

 The [initial
 value](https://svgwg.org/svg2-draft/types.html#TermInitialValue) for
 [pointsAtZ](#element-attrdef-fespotlight-pointsatz) is [0].

 Animatable: yes.

[`specularExponent`] = \"*[\<number\>](https://www.w3.org/TR/css3-values/#number-value)*\"

: Exponent value controlling the focus for the light source.

 The [initial
 value](https://svgwg.org/svg2-draft/types.html#TermInitialValue) for
 [specularExponent](#element-attrdef-fespotlight-specularexponent) is [1].

 See section [Filter primitive
 \<feDiffuseLighting\>](#feDiffuseLightingElement) for how to use
 [specularExponent](#element-attrdef-fespotlight-specularexponent).

 Note:
 [specularExponent](#element-attrdef-fespotlight-specularexponent) for
 [feSpotLight](#elementdef-fespotlight) serves a different use case than
 [specularExponent](#element-attrdef-fespecularlighting-specularexponent) for
 [feSpecularLighting](#elementdef-fespecularlighting).

 Animatable: yes.

[`limitingConeAngle`] = \"*[\<number\>](https://www.w3.org/TR/css3-values/#number-value)*\"

: A limiting cone which restricts the region where the light is
 projected. No light is projected outside the cone.
 [limitingConeAngle](#element-attrdef-fespotlight-limitingconeangle) represents the angle in degrees between
 the spot light axis (i.e. the axis between the light source and the
 point to which it is pointing at) and the spot light cone. [User
 agents should apply a smoothing technique such as anti-aliasing at
 the boundary of the cone.]

 If no value is specified, then no limiting cone will be applied.

 Animatable: yes.

### 11.5. The [lighting-color property]
Name:

[lighting-color]

[Value:](https://drafts.csswg.org/css-values/#value-defs)

[\<color\>](https://www.w3.org/TR/css3-color/#valuea-def-color "Expands to: indigo | gold | firebrick | indianred | yellow | darkolivegreen | darkseagreen | slategrey | darkslategrey | mediumvioletred | mediumorchid | transparent | chartreuse | mediumslateblue | black | springgreen | crimson | lightsalmon | brown | turquoise | olivedrab | cyan | silver | skyblue | gray | darkturquoise | goldenrod | darkgreen | darkviolet | darkgray | lightpink | teal | darkmagenta | lightgoldenrodyellow | lavender | yellowgreen | thistle | violet | navy | dimgrey | orchid | blue | ghostwhite | honeydew | cornflowerblue | darkblue | darkkhaki | mediumpurple | cornsilk | red | bisque | slategray | darkcyan | khaki | wheat | deepskyblue | rebeccapurple | darkred | steelblue | aliceblue | lightslategrey | gainsboro | mediumturquoise | floralwhite | coral | purple | lightgrey | lightcyan | darksalmon | beige | azure | lightsteelblue | oldlace | greenyellow | royalblue | lightseagreen | mistyrose | sienna | lightcoral | orangered | navajowhite | lime | palegreen | burlywood | seashell | mediumspringgreen | fuchsia | papayawhip | blanchedalmond | peru | aquamarine | white | darkslategray | tomato | ivory | dodgerblue | currentcolor | lemonchiffon | chocolate | orange | forestgreen | darkgrey | olive | mintcream | antiquewhite | darkorange | cadetblue | moccasin | limegreen | saddlebrown | grey | darkslateblue | lightskyblue | deeppink | plum | aqua | darkgoldenrod | maroon | sandybrown | magenta | tan | rosybrown | pink | lightblue | palevioletred | mediumseagreen | slateblue | dimgray | powderblue | seagreen | snow | mediumblue | midnightblue | paleturquoise | palegoldenrod | whitesmoke | darkorchid | salmon | lightslategray | lawngreen | lightgreen | lightgray | hotpink | lightyellow | lavenderblush | linen | mediumaquamarine | green | blueviolet | peachpuff")

[Initial:](https://drafts.csswg.org/css-cascade/#initial-values)

white

Applies to:

[feDiffuseLighting](#elementdef-fediffuselighting) and
[feSpecularLighting](#elementdef-fespecularlighting) elements

[Inherited:](https://drafts.csswg.org/css-cascade/#inherited-property)

no

[Percentages:](https://drafts.csswg.org/css-values/#percentages)

n/a

[Computed value:](https://drafts.csswg.org/css-cascade/#computed)

as specified

Canonical order:

per grammar

Media:

visual

[Animatable:](https://drafts.csswg.org/web-animations/#animation-type)

as [by computed
value](https://drafts.csswg.org/web-animations-1/#by-computed-value)

The
[lighting-color](#propdef-lighting-color) property defines the color of the light
source for [filter
primitives](#filter-primitive)
[feDiffuseLighting](#elementdef-fediffuselighting) and
[feSpecularLighting](#elementdef-fespecularlighting).

The
[lighting-color](#propdef-lighting-color) property is a [presentation
attribute](https://www.w3.org/TR/2011/REC-SVG11-20110816/intro.html#TermPresentationAttribute)
for SVG elements.

## [12. ][Filter CSS [\<image\>](https://www.w3.org/TR/css3-images/#image-type) values]
CSS
[\<image\>](https://www.w3.org/TR/css3-images/#image-type) values can be filtered with the
filter functions specified for the CSS
[filter](#propdef-filter) property. This specification introduces the
[\<image\>]
[\<filter()\>](#funcdef-filter) function with the following syntax:

``` prod
filter() = filter( [ <image> | <string> ], <filter-value-list> )
```

The [\<filter()\>](#funcdef-filter) function takes two arguments. The first
argument is an
[\<image\>](https://www.w3.org/TR/css3-images/#image-type). The second is a filter function list
as specified for the CSS
[filter](#propdef-filter) property. The function takes the
[\<image\>] parameter and applies the
filter rules, returning a processing image. Filter- and filter effect
regions are sized according to the [concrete object
size](https://drafts.csswg.org/css-images-3/#concrete-object-size) of the input [\<image\>].

Note: Since the dimension and origin of the original image must be
preserved, some filter effects like
[\<drop-shadow()\>](#funcdef-filter-drop-shadow) on a fully opaque image may not
have any affect.

For the [\<blur()\>](#funcdef-filter-blur) function the
[edgeMode](#element-attrdef-fegaussianblur-edgemode) attribute on the
[feGaussianBlur](#elementdef-fegaussianblur) element is set to [duplicate]. This produces
more pleasant results on the edges of the filtered input image.

### 12.1. Interpolating filter()

If both the starting and ending image are
[\<filter()\>](#funcdef-filter)s which may only differ by their used filter
functions, they must be interpolated by interpolating their filter
function lists as described in section [Interpolation of
Filters](#interpolation-of-filters). Otherwise, they must be
interpolated as generic
[\<image\>](https://www.w3.org/TR/css3-images/#image-type)s. If the filter function
interpolation can not be performed, the images must be interpolated as
generic [\<image\>]s.

## 13. Shorthands defined in terms of the [filter element]
### 13.1. Filter primitive representation

Below are the equivalents for each of the filter functions expressed in
terms of the \'filter element\' element. The parameters from the
function are labeled with brackets in the following style: \[amount\].
In the case of parameters that are percentage values, they are converted
to real numbers.

#### 13.1.1. grayscale

``` highlight
<filter id="grayscale">
 <feColorMatrix type="matrix"
 values="
 (0.2126 + 0.7874 * [1 - amount]) (0.7152 - 0.7152 * [1 - amount]) (0.0722 - 0.0722 * [1 - amount]) 0 0
 (0.2126 - 0.2126 * [1 - amount]) (0.7152 + 0.2848 * [1 - amount]) (0.0722 - 0.0722 * [1 - amount]) 0 0
 (0.2126 - 0.2126 * [1 - amount]) (0.7152 - 0.7152 * [1 - amount]) (0.0722 + 0.9278 * [1 - amount]) 0 0
 0 0 0 1 0"/>
</filter>
```

#### 13.1.2. sepia

``` highlight
<filter id="sepia">
 <feColorMatrix type="matrix"
 values="
 (0.393 + 0.607 * [1 - amount]) (0.769 - 0.769 * [1 - amount]) (0.189 - 0.189 * [1 - amount]) 0 0
 (0.349 - 0.349 * [1 - amount]) (0.686 + 0.314 * [1 - amount]) (0.168 - 0.168 * [1 - amount]) 0 0
 (0.272 - 0.272 * [1 - amount]) (0.534 - 0.534 * [1 - amount]) (0.131 + 0.869 * [1 - amount]) 0 0
 0 0 0 1 0"/>
</filter>
```

#### 13.1.3. saturate

``` highlight
<filter id="saturate">
 <feColorMatrix type="saturate" values="[amount]"/>
</filter>
```

#### 13.1.4. hue-rotate

``` highlight
<filter id="hue-rotate">
 <feColorMatrix type="hueRotate" values="[angle]"/>
</filter>
```

#### 13.1.5. invert

``` highlight
<filter id="invert">
 <feComponentTransfer>
 <feFuncR type="table" tableValues="[amount] (1 - [amount])"/>
 <feFuncG type="table" tableValues="[amount] (1 - [amount])"/>
 <feFuncB type="table" tableValues="[amount] (1 - [amount])"/>
 </feComponentTransfer>
</filter>
```

#### 13.1.6. opacity

``` highlight
<filter id="opacity">
 <feComponentTransfer>
 <feFuncA type="table" tableValues="0 [amount]"/>
 </feComponentTransfer>
</filter>
```

#### 13.1.7. brightness

``` highlight
<filter id="brightness">
 <feComponentTransfer>
 <feFuncR type="linear" slope="[amount]"/>
 <feFuncG type="linear" slope="[amount]"/>
 <feFuncB type="linear" slope="[amount]"/>
 </feComponentTransfer>
</filter>
```

#### 13.1.8. contrast

``` highlight
<filter id="contrast">
 <feComponentTransfer>
 <feFuncR type="linear" slope="[amount]" intercept="-(0.5 * [amount]) + 0.5"/>
 <feFuncG type="linear" slope="[amount]" intercept="-(0.5 * [amount]) + 0.5"/>
 <feFuncB type="linear" slope="[amount]" intercept="-(0.5 * [amount]) + 0.5"/>
 </feComponentTransfer>
</filter>
```

#### 13.1.9. blur

``` highlight
<filter id="blur">
 <feGaussianBlur stdDeviation="[radius radius]" edgeMode="[edge mode]" >
</filter>
```

Where edge mode computes to [none] for the
[filter](#propdef-filter) property and to [duplicate] for the CSS
Image [\<filter()\>](#funcdef-filter) function.

Note: The
[\<blur()\>](#funcdef-filter-blur) function may increase the UA
defined filter region. See [Filter region for
shorthands](#filter-region-for-shorthands).

#### 13.1.10. drop-shadow

``` highlight
<filter id="drop-shadow">
 <feGaussianBlur in="[alpha-channel-of-input]" stdDeviation="[radius]"/>
 <feOffset dx="[offset-x]" dy="[offset-y]" resu/>
 <feFlood flood-color="[color]"/>
 <feComposite in2="offsetblur" operator="in"/>
 <feMerge>
 <feMergeNode/>
 <feMergeNode in="[input-image]"/>
 </feMerge>
</filter>
```

Note: The
[\<drop-shadow()\>](#funcdef-filter-drop-shadow) function may increase the UA
defined filter region. See [Filter region for
shorthands](#filter-region-for-shorthands).

### 13.2. Filter region for shorthands

All shorthand filters implemented with filter primitives in the previous
subsection must have a UA defined [filter
region](#filter-region). The
filter region must cover the visual content of an element including
overflowing content, graphical control elements such as scrollbars,
[border](https://www.w3.org/TR/css3-background/#propdef-border)/[border-image](https://www.w3.org/TR/css3-background/#propdef-border-image),
[box-shadow](https://www.w3.org/TR/css3-background/#propdef-box-shadow),
[text-shadow](https://www.w3.org/TR/css-text-decor-3/#propdef-text-shadow) and
[outline](https://www.w3.org/TR/css3-ui/#propdef-outline). Furthermore, if a shorthand filter
expands this visible area like it is the case for
[\<blur()\>](#funcdef-filter-blur) or
[\<drop-shadow()\>](#funcdef-filter-drop-shadow) the filter region must cover this
area as well.

Note: For the handling of [filter sources](#FilterElement) see section
[Filter region](#FilterEffectsRegion).

## 14. Animation of Filters

### 14.1. Interpolation of Filter Function Lists

For interpolation between one filter and a second, the steps
corresponding to the first matching condition in the following list must
be run:

If both filters have a [\<filter-value-list\>](#typedef-filter-value-list) of same length without [\<url\>](#typedef-filter-url) and for each [\<filter-function\>](#typedef-filter-function) for which there is a corresponding item in each list
: Interpolate each
 [\<filter-function\>](#typedef-filter-function) pair following the rules in
 section [Interpolation of Filter
 Functions](#interpolation-of-filter-functions).

If both filters have a [\<filter-value-list\>](#typedef-filter-value-list) of different length without [\<url\>](#typedef-filter-url) and for each [\<filter-function\>](#typedef-filter-function) for which there is a corresponding item in each list

: 1. Append the missing equivalent
 [\<filter-function\>](#typedef-filter-function)s from the longer list to the
 end of the shorter list. The new added
 [\<filter-function\>]s must be initialized to their initial values for
 interpolation.
 2. Interpolate each
 [\<filter-function\>](#typedef-filter-function) pair following the rules in
 section [Interpolation of Filter
 Functions](#interpolation-of-filter-functions).

If one filter is [none] and the other is a [\<filter-value-list\>](#typedef-filter-value-list) without [\<url\>](#typedef-filter-url)

: 1. Replace [none] with the corresponding
 [\<filter-value-list\>](#typedef-filter-value-list) of the other filter. The new
 [\<filter-function\>](#typedef-filter-function)s must be initialized to their
 initial values for interpolation.
 2. Interpolate each
 [\<filter-function\>](#typedef-filter-function) pair following the rules in
 section [Interpolation of Filter
 Functions](#interpolation-of-filter-functions).

Otherwise
: Use discrete interpolation.

Compute distance of filter functions.
[\<https://github.com/w3c/csswg-drafts/issues/91\>](https://github.com/w3c/csswg-drafts/issues/91)

### 14.2. Addition

It is possible to combine independent animations of
[\<filter-value-list\>](#typedef-filter-value-list)s
[\[SVG11\]](#biblio-svg11).

Given two filter values representing an base value
(`base filter list`) and a value to add
(`added filter list`), returns the concatenation of the the
two lists: '`base filter list`
`added filter list`'.

The following SVG animation has two
[animate](https://www.w3.org/TR/SVG11/animate.html#AnimateElement) elements animating
[filter](#propdef-filter) property of the
[rect](https://www.w3.org/TR/svg2/shapes.html#elementdef-rect) element. Both specified animations are additive and
have a duration of `10s`.

``` highlight
<rect width="200px" filter="none" ...>
 <animate attributeName="filter" from="blur(0px)" to="blur(10px)" dur="10s"
 additive="sum"/>
 <animate attributeName="filter" from="sepia(0)" to="sepia(1)" dur="10s"
 additive="sum"/>
</rect>
```

After `5s`, the [used
value](https://www.w3.org/TR/css-cascade-4/#used-value) of [filter](#propdef-filter) is [blur(5px) sepia(0.5)].

### 14.3. Accumulation

Given two filter values `V`~`a`~ and
`V`~`b`~, returns the filter value,
`V`~`b`~.

## 15. Privacy and Security Considerations

### 15.1. Tainted Filter Primitives

It is important that the timing of any filter operation is independent
of pixel values derived from the filtered content or other sources
potentially containing privacy-sensitive information.

The following [filter
primitives](#filter-primitive) may have access to pixel values that potentially
contain privacy-sensitive information, either from the filtered object
itself or other sources such as CSS styling. These primitives must be
flagged as \"tainted\".

1. [feFlood](#elementdef-feflood) when the [specified
 value](https://www.w3.org/TR/css-cascade-4/#specified-value) of the
 [flood-color](#propdef-flood-color) property computes to
 [currentColor],

2. [feDropShadow](#elementdef-fedropshadow) when the [specified
 value](https://www.w3.org/TR/css-cascade-4/#specified-value) value of the
 [flood-color](#propdef-flood-color) property computes to
 [currentColor],

3. [feDiffuseLighting](#elementdef-fediffuselighting), when the [specified
 value](https://www.w3.org/TR/css-cascade-4/#specified-value) value of the
 [lighting-color](#propdef-lighting-color) property computes to
 [currentColor]

4. [feSpecularLighting](#elementdef-fespecularlighting) when the [specified
 value](https://www.w3.org/TR/css-cascade-4/#specified-value) value of the
 [lighting-color](#propdef-lighting-color) property computes to
 [currentColor],

5. [feImage](#elementdef-feimage), when the
 [\<url\>](#typedef-filter-url) reference points to an element or
 fetches a resource with the fetching mode *No-CORS* and

6. the filter primitives:
 [SourceGraphic](#attr-valuedef-in-sourcegraphic),
 [SourceAlpha](#attr-valuedef-in-sourcealpha),
 [BackgroundImage](#attr-valuedef-in-backgroundimage),
 [BackgroundAlpha](#attr-valuedef-in-backgroundalpha),
 [FillPaint](#attr-valuedef-in-fillpaint) and
 [StrokePaint](#attr-valuedef-in-strokepaint).

[feFlood](#elementdef-feflood),
[feDropShadow](#elementdef-fedropshadow),
[feDiffuseLighting](#elementdef-fediffuselighting) and
[feSpecularLighting](#elementdef-fespecularlighting) are primitives with one or more CSS properties that
take
[\<color\>](https://www.w3.org/TR/css3-color/#valuea-def-color "Expands to: indigo | gold | firebrick | indianred | yellow | darkolivegreen | darkseagreen | slategrey | darkslategrey | mediumvioletred | mediumorchid | transparent | chartreuse | mediumslateblue | black | springgreen | crimson | lightsalmon | brown | turquoise | olivedrab | cyan | silver | skyblue | gray | darkturquoise | goldenrod | darkgreen | darkviolet | darkgray | lightpink | teal | darkmagenta | lightgoldenrodyellow | lavender | yellowgreen | thistle | violet | navy | dimgrey | orchid | blue | ghostwhite | honeydew | cornflowerblue | darkblue | darkkhaki | mediumpurple | cornsilk | red | bisque | slategray | darkcyan | khaki | wheat | deepskyblue | rebeccapurple | darkred | steelblue | aliceblue | lightslategrey | gainsboro | mediumturquoise | floralwhite | coral | purple | lightgrey | lightcyan | darksalmon | beige | azure | lightsteelblue | oldlace | greenyellow | royalblue | lightseagreen | mistyrose | sienna | lightcoral | orangered | navajowhite | lime | palegreen | burlywood | seashell | mediumspringgreen | fuchsia | papayawhip | blanchedalmond | peru | aquamarine | white | darkslategray | tomato | ivory | dodgerblue | currentcolor | lemonchiffon | chocolate | orange | forestgreen | darkgrey | olive | mintcream | antiquewhite | darkorange | cadetblue | moccasin | limegreen | saddlebrown | grey | darkslateblue | lightskyblue | deeppink | plum | aqua | darkgoldenrod | maroon | sandybrown | magenta | tan | rosybrown | pink | lightblue | palevioletred | mediumseagreen | slateblue | dimgray | powderblue | seagreen | snow | mediumblue | midnightblue | paleturquoise | palegoldenrod | whitesmoke | darkorchid | salmon | lightslategray | lawngreen | lightgreen | lightgray | hotpink | lightyellow | lavenderblush | linen | mediumaquamarine | green | blueviolet | peachpuff") as property value.
[\<color\>]
consists of (amongst others) the [currentColor] keyword. The [used
value](https://www.w3.org/TR/css-cascade-4/#used-value) for [currentColor] derives from the
[color](https://www.w3.org/TR/css3-color/#color0) property. Since
[color] can be set by the
[:visited](https://www.w3.org/TR/selectors4/#visited-pseudo) pseudo selector, it potentially contains
privacy-sensitive information and therefore these primitives must be
marked as tainted.

[feImage](#elementdef-feimage) can reference cross-domain images as well as
document fragments such as SVG [graphics
elements](https://www.w3.org/TR/svg2/struct.html#graphics-element). These references potentially contain privacy-sensitive
information and therefore the primitive must be marked as tainted.

The filter primitives
[SourceGraphic](#attr-valuedef-in-sourcegraphic),
[SourceAlpha](#attr-valuedef-in-sourcealpha),
[BackgroundImage](#attr-valuedef-in-backgroundimage),
[BackgroundAlpha](#attr-valuedef-in-backgroundalpha),
[FillPaint](#attr-valuedef-in-fillpaint) and
[StrokePaint](#attr-valuedef-in-strokepaint) either reference document fragments such as SVG
[graphics
elements](https://www.w3.org/TR/svg2/struct.html#graphics-element) or style information that may derive directly or
indirectly from the
[color](https://www.w3.org/TR/css3-color/#color0) property. Therefore these primitives
must be marked as tainted.

Every [filter primitive](#filter-primitive) that has a \"tainted\" flagged [filter
primitive] as input must be flagged as
\"tainted\" as well.

Filter operations must be implemented in such a way that they always
take the same amount of time regardless of the pixel values if one of
the input filter primitives is flagged as \"tainted\".

Note: This specification aggravates the restrictions to filter
primitives based on implementation feedback from user agents.

### 15.2. [feDisplacementMap Restrictions]
If
[feDisplacementMap](#elementdef-fedisplacementmap) has a \"tainted\" flagged filter primitive as input
and this input filter primitive is used as displacement map (referenced
by
[in2](#element-attrdef-fedisplacementmap-in2)), then
[feDisplacementMap] must not
proceed with the filter operation and acts as a [pass through
filter](#pass-through-filter).

### 15.3. Origin Restrictions

User agents must use the [potentially CORS-enabled
fetch](https://fetch.spec.whatwg.org/#cors-request) method defined by
the [\[HTML5\]](#biblio-html5) specification for the
[filter](#propdef-filter) property. When fetching, user agents must use
\"Anonymous\" mode, set the referrer source to the stylesheet's URL and
set the origin to the URL of the containing document. If this results in
network errors, the effect is as if the value [none] had been
specified.

### 15.4. Timing Attacks

If any of the above rules are not followed, an attacker could infer
information and mount a timing attack.

A timing attack is a method of obtaining information about content that
is otherwise protected, based on studying the amount of time it takes
for an operation to occur. If, for example, red pixels took longer to
draw than green pixels, one might be able to reconstruct a rough image
of the element being rendered, without ever having access to the content
of the element. Security studies show that timing differences on
arithmetic operations can be caused by the hardware architecture or
compiler [\[ArTD\]](#biblio-artd).

## [Appendix A: The deprecated [enable-background](https://www.w3.org/TR/SVG11/filters.html#EnableBackgroundProperty) property]
SVG 1.1 introduced the
[enable-background](https://www.w3.org/TR/SVG11/filters.html#EnableBackgroundProperty) property
[\[SVG11\]](#biblio-svg11). The property defined the
back drop under the [filter
region](#filter-region) at the
time that the [filter](#elementdef-filter) element was invoked. The concept defined by this
property was identified to be incompatible with the model of stacking
context in CSS at the time writing this specification. UAs can choose to
implement the [enable-background] property as defined in SVG 1.1 but will not be compatible to
this specification or to CSS Compositing and Blending
[\[COMPOSITING-1\]](#biblio-compositing-1).

This specification does not support the
[enable-background](https://www.w3.org/TR/SVG11/filters.html#EnableBackgroundProperty) property. UAs must support the
[isolation](https://www.w3.org/TR/compositing-1/#propdef-isolation) property instead
[\[COMPOSITING-1\]](#biblio-compositing-1).

## [Appendix B: DOM interfaces]
### [Interface SVGFilterElement]
The [`SVGFilterElement`] interface corresponds to the
[filter](#elementdef-filter) element.

```
interface SVGFilterElement : SVGElement {
 readonly attribute SVGAnimatedEnumeration filterUnits;
 readonly attribute SVGAnimatedEnumeration primitiveUnits;
 readonly attribute SVGAnimatedLength x;
 readonly attribute SVGAnimatedLength y;
 readonly attribute SVGAnimatedLength width;
 readonly attribute SVGAnimatedLength height;
};

SVGFilterElement includes SVGURIReference;
```

Attributes:

:

 [`filterUnits`], of type [SVGAnimatedEnumeration](https://www.w3.org/TR/svg2/types.html#InterfaceSVGAnimatedEnumeration), readonly

 : Corresponds to attribute
 [filterUnits](#element-attrdef-filter-filterunits) on the given
 [filter](#elementdef-filter) element. Takes one of the constants defined
 in
 [SVGUnitTypes](https://www.w3.org/TR/svg2/types.html#InterfaceSVGUnitTypes).

 [`primitiveUnits`], of type [SVGAnimatedEnumeration](https://www.w3.org/TR/svg2/types.html#InterfaceSVGAnimatedEnumeration), readonly

 : Corresponds to attribute
 [primitiveUnits](#element-attrdef-filter-primitiveunits) on the given
 [filter](#elementdef-filter) element. Takes one of the constants defined
 in
 [SVGUnitTypes](https://www.w3.org/TR/svg2/types.html#InterfaceSVGUnitTypes).

 [`x`], of type [SVGAnimatedLength](https://www.w3.org/TR/svg2/types.html#InterfaceSVGAnimatedLength), readonly

 : Corresponds to attribute
 [x](#element-attrdef-filter-x) on the given
 [filter](#elementdef-filter) element.

 [`y`], of type [SVGAnimatedLength](https://www.w3.org/TR/svg2/types.html#InterfaceSVGAnimatedLength), readonly

 : Corresponds to attribute
 [y](#element-attrdef-filter-y) on the given
 [filter](#elementdef-filter) element.

 [`width`], of type [SVGAnimatedLength](https://www.w3.org/TR/svg2/types.html#InterfaceSVGAnimatedLength), readonly

 : Corresponds to attribute
 [width](#element-attrdef-filter-width) on the given
 [filter](#elementdef-filter) element.

 [`height`], of type [SVGAnimatedLength](https://www.w3.org/TR/svg2/types.html#InterfaceSVGAnimatedLength), readonly

 : Corresponds to attribute
 [height](#element-attrdef-filter-height) on the given
 [filter](#elementdef-filter) element.

### [Interface SVGFilterPrimitiveStandardAttributes]
```
interface mixin SVGFilterPrimitiveStandardAttributes {
 readonly attribute SVGAnimatedLength x;
 readonly attribute SVGAnimatedLength y;
 readonly attribute SVGAnimatedLength width;
 readonly attribute SVGAnimatedLength height;
 readonly attribute SVGAnimatedString result;
};
```

Attributes:

:

 [`x`], of type [SVGAnimatedLength](https://www.w3.org/TR/svg2/types.html#InterfaceSVGAnimatedLength), readonly

 : Corresponds to attribute
 [x](#element-attrdef-filter-primitive-x) on the given element.

 [`y`], of type [SVGAnimatedLength](https://www.w3.org/TR/svg2/types.html#InterfaceSVGAnimatedLength), readonly

 : Corresponds to attribute
 [y](#element-attrdef-filter-primitive-y) on the given element.

 [`width`], of type [SVGAnimatedLength](https://www.w3.org/TR/svg2/types.html#InterfaceSVGAnimatedLength), readonly

 : Corresponds to attribute
 [width](#element-attrdef-filter-primitive-width) on the given element.

 [`height`], of type [SVGAnimatedLength](https://www.w3.org/TR/svg2/types.html#InterfaceSVGAnimatedLength), readonly

 : Corresponds to attribute
 [height](#element-attrdef-filter-primitive-height) on the given element.

 [`result`], of type [SVGAnimatedString](https://www.w3.org/TR/svg2/types.html#InterfaceSVGAnimatedString), readonly

 : Corresponds to attribute
 [result](#element-attrdef-filter-primitive-result) on the given element.

### [Interface SVGFEBlendElement]
The [`SVGFEBlendElement`] interface corresponds to the
[feBlend](#elementdef-feblend) element.

```
interface SVGFEBlendElement : SVGElement {

 // Blend Mode Types
 const unsigned short SVG_FEBLEND_MODE_UNKNOWN = 0;
 const unsigned short SVG_FEBLEND_MODE_NORMAL = 1;
 const unsigned short SVG_FEBLEND_MODE_MULTIPLY = 2;
 const unsigned short SVG_FEBLEND_MODE_SCREEN = 3;
 const unsigned short SVG_FEBLEND_MODE_DARKEN = 4;
 const unsigned short SVG_FEBLEND_MODE_LIGHTEN = 5;
 const unsigned short SVG_FEBLEND_MODE_OVERLAY = 6;
 const unsigned short SVG_FEBLEND_MODE_COLOR_DODGE = 7;
 const unsigned short SVG_FEBLEND_MODE_COLOR_BURN = 8;
 const unsigned short SVG_FEBLEND_MODE_HARD_LIGHT = 9;
 const unsigned short SVG_FEBLEND_MODE_SOFT_LIGHT = 10;
 const unsigned short SVG_FEBLEND_MODE_DIFFERENCE = 11;
 const unsigned short SVG_FEBLEND_MODE_EXCLUSION = 12;
 const unsigned short SVG_FEBLEND_MODE_HUE = 13;
 const unsigned short SVG_FEBLEND_MODE_SATURATION = 14;
 const unsigned short SVG_FEBLEND_MODE_COLOR = 15;
 const unsigned short SVG_FEBLEND_MODE_LUMINOSITY = 16;

 readonly attribute SVGAnimatedString in1;
 readonly attribute SVGAnimatedString in2;
 readonly attribute SVGAnimatedEnumeration mode;
};

SVGFEBlendElement includes SVGFilterPrimitiveStandardAttributes;
```

Constants in group "Blend Mode Types":

:

 [`SVG_FEBLEND_MODE_UNKNOWN`]

 : The type is not one of predefined types. It is invalid to
 attempt to define a new value of this type or to attempt to
 switch an existing value to this type.

 [`SVG_FEBLEND_MODE_NORMAL`]

 : Corresponds to value
 [normal](https://www.w3.org/TR/compositing-1/#valdef-blend-mode-normal).

 [`SVG_FEBLEND_MODE_MULTIPLY`]

 : Corresponds to value
 [multiply](https://www.w3.org/TR/compositing-1/#valdef-blend-mode-multiply).

 [`SVG_FEBLEND_MODE_SCREEN`]

 : Corresponds to value
 [screen](https://www.w3.org/TR/compositing-1/#valdef-blend-mode-screen).

 [`SVG_FEBLEND_MODE_DARKEN`]

 : Corresponds to value
 [darken](https://www.w3.org/TR/compositing-1/#valdef-blend-mode-darken).

 [`SVG_FEBLEND_MODE_LIGHTEN`]

 : Corresponds to value
 [lighten](https://www.w3.org/TR/compositing-1/#valdef-blend-mode-lighten).

 [`SVG_FEBLEND_MODE_OVERLAY`]

 : Corresponds to value
 [overlay](https://www.w3.org/TR/compositing-1/#valdef-blend-mode-overlay).

 [`SVG_FEBLEND_MODE_COLOR_DODGE`]

 : Corresponds to value
 [color-dodge](https://www.w3.org/TR/compositing-1/#valdef-blend-mode-color-dodge).

 [`SVG_FEBLEND_MODE_COLOR_BURN`]

 : Corresponds to value
 [color-burn](https://www.w3.org/TR/compositing-1/#valdef-blend-mode-color-burn).

 [`SVG_FEBLEND_MODE_HARD_LIGHT`]

 : Corresponds to value
 [hard-light](https://www.w3.org/TR/compositing-1/#valdef-blend-mode-hard-light).

 [`SVG_FEBLEND_MODE_SOFT_LIGHT`]

 : Corresponds to value
 [soft-light](https://www.w3.org/TR/compositing-1/#valdef-blend-mode-soft-light).

 [`SVG_FEBLEND_MODE_DIFFERENCE`]

 : Corresponds to value
 [difference](https://www.w3.org/TR/compositing-1/#valdef-blend-mode-difference).

 [`SVG_FEBLEND_MODE_EXCLUSION`]

 : Corresponds to value
 [exclusion](https://www.w3.org/TR/compositing-1/#valdef-blend-mode-exclusion).

 [`SVG_FEBLEND_MODE_HUE`]

 : Corresponds to value
 [hue](https://www.w3.org/TR/compositing-1/#valdef-blend-mode-hue).

 [`SVG_FEBLEND_MODE_SATURATION`]

 : Corresponds to value
 [saturation](https://www.w3.org/TR/compositing-1/#valdef-blend-mode-saturation).

 [`SVG_FEBLEND_MODE_COLOR`]

 : Corresponds to value
 [color](https://www.w3.org/TR/compositing-1/#valdef-blend-mode-color).

 [`SVG_FEBLEND_MODE_LUMINOSITY`]

 : Corresponds to value
 [luminosity](https://www.w3.org/TR/compositing-1/#valdef-blend-mode-luminosity).

Attributes:

:

 [`in1`], of type [SVGAnimatedString](https://www.w3.org/TR/svg2/types.html#InterfaceSVGAnimatedString), readonly

 : Corresponds to attribute
 [in](#element-attrdef-filter-primitive-in) on the given
 [feBlend](#elementdef-feblend) element.

 [`in2`], of type [SVGAnimatedString](https://www.w3.org/TR/svg2/types.html#InterfaceSVGAnimatedString), readonly

 : Corresponds to attribute
 [in2](#element-attrdef-feblend-in2) on the given
 [feBlend](#elementdef-feblend) element.

 [`mode`], of type [SVGAnimatedEnumeration](https://www.w3.org/TR/svg2/types.html#InterfaceSVGAnimatedEnumeration), readonly

 : Corresponds to attribute
 [mode](#element-attrdef-feblend-mode) on the given
 [feBlend](#elementdef-feblend) element. Takes one of the
 SVG_FEBLEND_MODE\_\* constants defined on this interface.

### [Interface SVGFEColorMatrixElement]
The [`SVGFEColorMatrixElement`] interface
corresponds to the
[feColorMatrix](#elementdef-fecolormatrix) element.

```
interface SVGFEColorMatrixElement : SVGElement {

 // Color Matrix Types
 const unsigned short SVG_FECOLORMATRIX_TYPE_UNKNOWN = 0;
 const unsigned short SVG_FECOLORMATRIX_TYPE_MATRIX = 1;
 const unsigned short SVG_FECOLORMATRIX_TYPE_SATURATE = 2;
 const unsigned short SVG_FECOLORMATRIX_TYPE_HUEROTATE = 3;
 const unsigned short SVG_FECOLORMATRIX_TYPE_LUMINANCETOALPHA = 4;

 readonly attribute SVGAnimatedString in1;
 readonly attribute SVGAnimatedEnumeration type;
 readonly attribute SVGAnimatedNumberList values;
};

SVGFEColorMatrixElement includes SVGFilterPrimitiveStandardAttributes;
```

Constants in group "Color Matrix Types":

:

 [`SVG_FECOLORMATRIX_TYPE_UNKNOWN`]

 : The type is not one of predefined types. It is invalid to
 attempt to define a new value of this type or to attempt to
 switch an existing value to this type.

 [`SVG_FECOLORMATRIX_TYPE_MATRIX`]

 : Corresponds to value [matrix].

 [`SVG_FECOLORMATRIX_TYPE_SATURATE`]

 : Corresponds to value [saturate].

 [`SVG_FECOLORMATRIX_TYPE_HUEROTATE`]

 : Corresponds to value [hueRotate].

 [`SVG_FECOLORMATRIX_TYPE_LUMINANCETOALPHA`]

 : Corresponds to value [luminanceToAlpha].

Attributes:

:

 [`in1`], of type [SVGAnimatedString](https://www.w3.org/TR/svg2/types.html#InterfaceSVGAnimatedString), readonly

 : Corresponds to attribute
 [in](#element-attrdef-filter-primitive-in) on the given
 [feColorMatrix](#elementdef-fecolormatrix) element.

 [`type`], of type [SVGAnimatedEnumeration](https://www.w3.org/TR/svg2/types.html#InterfaceSVGAnimatedEnumeration), readonly

 : Corresponds to attribute
 [type](#element-attrdef-fecolormatrix-type) on the given
 [feColorMatrix](#elementdef-fecolormatrix) element. Takes one of the
 SVG_FECOLORMATRIX_TYPE\_\* constants defined on this interface.

 [`values`], of type [SVGAnimatedNumberList](https://www.w3.org/TR/svg2/types.html#InterfaceSVGAnimatedNumberList), readonly

 : Corresponds to attribute
 [values](#element-attrdef-fecolormatrix-values) on the given
 [feColorMatrix](#elementdef-fecolormatrix) element.

### [Interface SVGFEComponentTransferElement]
The [`SVGFEComponentTransferElement`] interface
corresponds to the
[feComponentTransfer](#elementdef-fecomponenttransfer) element.

```
interface SVGFEComponentTransferElement : SVGElement {
 readonly attribute SVGAnimatedString in1;
};

SVGFEComponentTransferElement includes SVGFilterPrimitiveStandardAttributes;
```

Attributes:

:

 [`in1`], of type [SVGAnimatedString](https://www.w3.org/TR/svg2/types.html#InterfaceSVGAnimatedString), readonly

 : Corresponds to attribute
 [in](#element-attrdef-filter-primitive-in) on the given
 [feComponentTransfer](#elementdef-fecomponenttransfer) element.

### [Interface SVGComponentTransferFunctionElement]
This interface defines a base interface used by the component transfer
function interfaces.

```
interface SVGComponentTransferFunctionElement : SVGElement {

 // Component Transfer Types
 const unsigned short SVG_FECOMPONENTTRANSFER_TYPE_UNKNOWN = 0;
 const unsigned short SVG_FECOMPONENTTRANSFER_TYPE_IDENTITY = 1;
 const unsigned short SVG_FECOMPONENTTRANSFER_TYPE_TABLE = 2;
 const unsigned short SVG_FECOMPONENTTRANSFER_TYPE_DISCRETE = 3;
 const unsigned short SVG_FECOMPONENTTRANSFER_TYPE_LINEAR = 4;
 const unsigned short SVG_FECOMPONENTTRANSFER_TYPE_GAMMA = 5;

 readonly attribute SVGAnimatedEnumeration type;
 readonly attribute SVGAnimatedNumberList tableValues;
 readonly attribute SVGAnimatedNumber slope;
 readonly attribute SVGAnimatedNumber intercept;
 readonly attribute SVGAnimatedNumber amplitude;
 readonly attribute SVGAnimatedNumber exponent;
 readonly attribute SVGAnimatedNumber offset;
};
```

Constants in group "Component Transfer Types":

:

 [`SVG_FECOMPONENTTRANSFER_TYPE_UNKNOWN`]

 : The type is not one of predefined types. It is invalid to
 attempt to define a new value of this type or to attempt to
 switch an existing value to this type.

 [`SVG_FECOMPONENTTRANSFER_TYPE_IDENTITY`]

 : Corresponds to value [identity].

 [`SVG_FECOMPONENTTRANSFER_TYPE_TABLE`]

 : Corresponds to value [table].

 [`SVG_FECOMPONENTTRANSFER_TYPE_DISCRETE`]

 : Corresponds to value [discrete].

 [`SVG_FECOMPONENTTRANSFER_TYPE_LINEAR`]

 : Corresponds to value [linear].

 [`SVG_FECOMPONENTTRANSFER_TYPE_GAMMA`]

 : Corresponds to value [gamma].

Attributes:

:

 [`type`], of type [SVGAnimatedEnumeration](https://www.w3.org/TR/svg2/types.html#InterfaceSVGAnimatedEnumeration), readonly

 : Corresponds to attribute
 [in](#element-attrdef-filter-primitive-in) on the given
 [feComponentTransfer](#elementdef-fecomponenttransfer) element. Takes one of the
 SVG_FECOMPONENTTRANSFER_TYPE\_\* constants defined on this
 interface.

 [`tableValues`], of type [SVGAnimatedNumberList](https://www.w3.org/TR/svg2/types.html#InterfaceSVGAnimatedNumberList), readonly

 : Corresponds to attribute
 [tableValues](#element-attrdef-fecomponenttransfer-tablevalues) on the given
 [feComponentTransfer](#elementdef-fecomponenttransfer) element. Takes one of the
 SVG_FECOLORMATRIX_TYPE\_\* constants defined on this interface.

 [`slope`], of type [SVGAnimatedNumber](https://www.w3.org/TR/svg2/types.html#InterfaceSVGAnimatedNumber), readonly

 : Corresponds to attribute
 [slope](#element-attrdef-fecomponenttransfer-slope) on the given
 [feComponentTransfer](#elementdef-fecomponenttransfer) element.

 [`intercept`], of type [SVGAnimatedNumber](https://www.w3.org/TR/svg2/types.html#InterfaceSVGAnimatedNumber), readonly

 : Corresponds to attribute
 [intercept](#element-attrdef-fecomponenttransfer-intercept) on the given
 [feComponentTransfer](#elementdef-fecomponenttransfer) element.

 [`amplitude`], of type [SVGAnimatedNumber](https://www.w3.org/TR/svg2/types.html#InterfaceSVGAnimatedNumber), readonly

 : Corresponds to attribute
 [amplitude](#element-attrdef-fecomponenttransfer-amplitude) on the given
 [feComponentTransfer](#elementdef-fecomponenttransfer) element.

 [`exponent`], of type [SVGAnimatedNumber](https://www.w3.org/TR/svg2/types.html#InterfaceSVGAnimatedNumber), readonly

 : Corresponds to attribute
 [exponent](#element-attrdef-fecomponenttransfer-exponent) on the given
 [feComponentTransfer](#elementdef-fecomponenttransfer) element.

 [`offset`], of type [SVGAnimatedNumber](https://www.w3.org/TR/svg2/types.html#InterfaceSVGAnimatedNumber), readonly

 : Corresponds to attribute
 [offset](#element-attrdef-fecomponenttransfer-offset) on the given
 [feComponentTransfer](#elementdef-fecomponenttransfer) element.

### [Interface SVGFEFuncRElement]
The [`SVGFEFuncRElement`] interface corresponds to the
[feFuncR](#elementdef-fefuncr) element.

```
interface SVGFEFuncRElement : SVGComponentTransferFunctionElement ;
```

### [Interface SVGFEFuncGElement]
The [`SVGFEFuncGElement`] interface corresponds to the
[feFuncG](#elementdef-fefuncg) element.

```
interface SVGFEFuncGElement : SVGComponentTransferFunctionElement ;
```

### [Interface SVGFEFuncBElement]
The [`SVGFEFuncBElement`] interface corresponds to the
[feFuncB](#elementdef-fefuncb) element.

```
interface SVGFEFuncBElement : SVGComponentTransferFunctionElement ;
```

### [Interface SVGFEFuncAElement]
The [`SVGFEFuncAElement`] interface corresponds to the
[feFuncA](#elementdef-fefunca) element.

```
interface SVGFEFuncAElement : SVGComponentTransferFunctionElement ;
```

### [Interface SVGFECompositeElement]
The [`SVGFECompositeElement`] interface corresponds to the
[feComposite](#elementdef-fecomposite) element.

```
interface SVGFECompositeElement : SVGElement {

 // Composite Operators
 const unsigned short SVG_FECOMPOSITE_OPERATOR_UNKNOWN = 0;
 const unsigned short SVG_FECOMPOSITE_OPERATOR_OVER = 1;
 const unsigned short SVG_FECOMPOSITE_OPERATOR_IN = 2;
 const unsigned short SVG_FECOMPOSITE_OPERATOR_OUT = 3;
 const unsigned short SVG_FECOMPOSITE_OPERATOR_ATOP = 4;
 const unsigned short SVG_FECOMPOSITE_OPERATOR_XOR = 5;
 const unsigned short SVG_FECOMPOSITE_OPERATOR_ARITHMETIC = 6;

 readonly attribute SVGAnimatedString in1;
 readonly attribute SVGAnimatedString in2;
 readonly attribute SVGAnimatedEnumeration operator;
 readonly attribute SVGAnimatedNumber k1;
 readonly attribute SVGAnimatedNumber k2;
 readonly attribute SVGAnimatedNumber k3;
 readonly attribute SVGAnimatedNumber k4;
};

SVGFECompositeElement includes SVGFilterPrimitiveStandardAttributes;
```

Constants in group "Composite Operators":

:

 [`SVG_FECOMPOSITE_OPERATOR_UNKNOWN`]

 : The type is not one of predefined types. It is invalid to
 attempt to define a new value of this type or to attempt to
 switch an existing value to this type.

 [`SVG_FECOMPOSITE_OPERATOR_OVER`]

 : Corresponds to value
 [over](#attr-valuedef-operator-over).

 [`SVG_FECOMPOSITE_OPERATOR_IN`]

 : Corresponds to value
 [in](#attr-valuedef-operator-in).

 [`SVG_FECOMPOSITE_OPERATOR_OUT`]

 : Corresponds to value
 [out](#attr-valuedef-operator-out).

 [`SVG_FECOMPOSITE_OPERATOR_ATOP`]

 : Corresponds to value
 [atop](#attr-valuedef-operator-atop).

 [`SVG_FECOMPOSITE_OPERATOR_XOR`]

 : Corresponds to value
 [xor](#attr-valuedef-operator-xor).

 [`SVG_FECOMPOSITE_OPERATOR_ARITHMETIC`]

 : Corresponds to value
 [arithmetic](#attr-valuedef-operator-arithmetic).

Attributes:

:

 [`in1`], of type [SVGAnimatedString](https://www.w3.org/TR/svg2/types.html#InterfaceSVGAnimatedString), readonly

 : Corresponds to attribute
 [in](#element-attrdef-filter-primitive-in) on the given
 [feComposite](#elementdef-fecomposite) element.

 [`in2`], of type [SVGAnimatedString](https://www.w3.org/TR/svg2/types.html#InterfaceSVGAnimatedString), readonly

 : Corresponds to attribute
 [in2](#element-attrdef-fecomposite-in2) on the given
 [feComposite](#elementdef-fecomposite) element.

 [`operator`], of type [SVGAnimatedEnumeration](https://www.w3.org/TR/svg2/types.html#InterfaceSVGAnimatedEnumeration), readonly

 : Corresponds to attribute
 [operator](#element-attrdef-fecomposite-operator) on the given
 [feComposite](#elementdef-fecomposite) element.

 [`k1`], of type [SVGAnimatedNumber](https://www.w3.org/TR/svg2/types.html#InterfaceSVGAnimatedNumber), readonly

 : Corresponds to attribute
 [k1](#element-attrdef-fecomposite-k1) on the given
 [feComposite](#elementdef-fecomposite) element.

 [`k2`], of type [SVGAnimatedNumber](https://www.w3.org/TR/svg2/types.html#InterfaceSVGAnimatedNumber), readonly

 : Corresponds to attribute
 [k2](#element-attrdef-fecomposite-k2) on the given
 [feComposite](#elementdef-fecomposite) element.

 [`k3`], of type [SVGAnimatedNumber](https://www.w3.org/TR/svg2/types.html#InterfaceSVGAnimatedNumber), readonly

 : Corresponds to attribute
 [k3](#element-attrdef-fecomposite-k3) on the given
 [feComposite](#elementdef-fecomposite) element.

 [`k4`], of type [SVGAnimatedNumber](https://www.w3.org/TR/svg2/types.html#InterfaceSVGAnimatedNumber), readonly

 : Corresponds to attribute
 [k4](#element-attrdef-fecomposite-k4) on the given
 [feComposite](#elementdef-fecomposite) element.

### [Interface SVGFEConvolveMatrixElement]
The [`SVGFEConvolveMatrixElement`] interface
corresponds to the
[feConvolveMatrix](#elementdef-feconvolvematrix) element.

```
interface SVGFEConvolveMatrixElement : SVGElement {

 // Edge Mode Values
 const unsigned short SVG_EDGEMODE_UNKNOWN = 0;
 const unsigned short SVG_EDGEMODE_DUPLICATE = 1;
 const unsigned short SVG_EDGEMODE_WRAP = 2;
 const unsigned short SVG_EDGEMODE_NONE = 3;

 readonly attribute SVGAnimatedString in1;
 readonly attribute SVGAnimatedInteger orderX;
 readonly attribute SVGAnimatedInteger orderY;
 readonly attribute SVGAnimatedNumberList kernelMatrix;
 readonly attribute SVGAnimatedNumber divisor;
 readonly attribute SVGAnimatedNumber bias;
 readonly attribute SVGAnimatedInteger targetX;
 readonly attribute SVGAnimatedInteger targetY;
 readonly attribute SVGAnimatedEnumeration edgeMode;
 readonly attribute SVGAnimatedNumber kernelUnitLengthX;
 readonly attribute SVGAnimatedNumber kernelUnitLengthY;
 readonly attribute SVGAnimatedBoolean preserveAlpha;
};

SVGFEConvolveMatrixElement includes SVGFilterPrimitiveStandardAttributes;
```

Constants in group "Edge Mode Values":

:

 [`SVG_EDGEMODE_UNKNOWN`]

 : The type is not one of predefined types. It is invalid to
 attempt to define a new value of this type or to attempt to
 switch an existing value to this type.

 [`SVG_EDGEMODE_DUPLICATE`]

 : Corresponds to value
 [duplicate](#attr-valuedef-edgemode-duplicate).

 [`SVG_EDGEMODE_WRAP`]

 : Corresponds to value
 [wrap](#attr-valuedef-edgemode-wrap).

 [`SVG_EDGEMODE_NONE`]

 : Corresponds to value [none].

Attributes:

:

 [`in1`], of type [SVGAnimatedString](https://www.w3.org/TR/svg2/types.html#InterfaceSVGAnimatedString), readonly

 : Corresponds to attribute
 [in](#element-attrdef-filter-primitive-in) on the given
 [feConvolveMatrix](#elementdef-feconvolvematrix) element.

 [`orderX`], of type [SVGAnimatedInteger](https://www.w3.org/TR/svg2/types.html#InterfaceSVGAnimatedInteger), readonly

 : Corresponds to attribute
 [order](#element-attrdef-order) on the given
 [feConvolveMatrix](#elementdef-feconvolvematrix) element.

 [`orderY`], of type [SVGAnimatedInteger](https://www.w3.org/TR/svg2/types.html#InterfaceSVGAnimatedInteger), readonly

 : Corresponds to attribute
 [order](#element-attrdef-order) on the given
 [feConvolveMatrix](#elementdef-feconvolvematrix) element.

 [`kernelMatrix`], of type [SVGAnimatedNumberList](https://www.w3.org/TR/svg2/types.html#InterfaceSVGAnimatedNumberList), readonly

 : Corresponds to attribute
 [kernelMatrix](#element-attrdef-feconvolvematrix-kernelmatrix) on the given
 [feConvolveMatrix](#elementdef-feconvolvematrix) element.

 [`divisor`], of type [SVGAnimatedNumber](https://www.w3.org/TR/svg2/types.html#InterfaceSVGAnimatedNumber), readonly

 : Corresponds to attribute
 [divisor](#element-attrdef-feconvolvematrix-divisor) on the given
 [feConvolveMatrix](#elementdef-feconvolvematrix) element.

 [`bias`], of type [SVGAnimatedNumber](https://www.w3.org/TR/svg2/types.html#InterfaceSVGAnimatedNumber), readonly

 : Corresponds to attribute
 [bias](#element-attrdef-feconvolvematrix-bias) on the given
 [feConvolveMatrix](#elementdef-feconvolvematrix) element.

 [`targetX`], of type [SVGAnimatedInteger](https://www.w3.org/TR/svg2/types.html#InterfaceSVGAnimatedInteger), readonly

 : Corresponds to attribute
 [targetX](#element-attrdef-feconvolvematrix-targetx) on the given
 [feConvolveMatrix](#elementdef-feconvolvematrix) element.

 [`targetY`], of type [SVGAnimatedInteger](https://www.w3.org/TR/svg2/types.html#InterfaceSVGAnimatedInteger), readonly

 : Corresponds to attribute
 [targetY](#element-attrdef-feconvolvematrix-targety) on the given
 [feConvolveMatrix](#elementdef-feconvolvematrix) element.

 [`edgeMode`], of type [SVGAnimatedEnumeration](https://www.w3.org/TR/svg2/types.html#InterfaceSVGAnimatedEnumeration), readonly

 : Corresponds to attribute
 [edgeMode](#element-attrdef-feconvolvematrix-edgemode) on the given
 [feConvolveMatrix](#elementdef-feconvolvematrix) element.

 [`kernelUnitLengthX`], of type [SVGAnimatedNumber](https://www.w3.org/TR/svg2/types.html#InterfaceSVGAnimatedNumber), readonly

 : Corresponds to attribute
 [kernelUnitLength](#element-attrdef-feconvolvematrix-kernelunitlength) on the given
 [feConvolveMatrix](#elementdef-feconvolvematrix) element.

 [`kernelUnitLengthY`], of type [SVGAnimatedNumber](https://www.w3.org/TR/svg2/types.html#InterfaceSVGAnimatedNumber), readonly

 : Corresponds to attribute
 [kernelUnitLength](#element-attrdef-feconvolvematrix-kernelunitlength) on the given
 [feConvolveMatrix](#elementdef-feconvolvematrix) element.

 [`preserveAlpha`], of type [SVGAnimatedBoolean](https://www.w3.org/TR/svg2/types.html#InterfaceSVGAnimatedBoolean), readonly

 : Corresponds to attribute
 [preserveAlpha](#element-attrdef-feconvolvematrix-preservealpha) on the given
 [feConvolveMatrix](#elementdef-feconvolvematrix) element.

### [Interface SVGFEDiffuseLightingElement]
The [`SVGFEDiffuseLightingElement`] interface
corresponds to the
[feDiffuseLighting](#elementdef-fediffuselighting) element.

```
interface SVGFEDiffuseLightingElement : SVGElement {
 readonly attribute SVGAnimatedString in1;
 readonly attribute SVGAnimatedNumber surfaceScale;
 readonly attribute SVGAnimatedNumber diffuseConstant;
 readonly attribute SVGAnimatedNumber kernelUnitLengthX;
 readonly attribute SVGAnimatedNumber kernelUnitLengthY;
};

SVGFEDiffuseLightingElement includes SVGFilterPrimitiveStandardAttributes;
```

Attributes:

:

 [`in1`], of type [SVGAnimatedString](https://www.w3.org/TR/svg2/types.html#InterfaceSVGAnimatedString), readonly

 : Corresponds to attribute
 [in](#element-attrdef-filter-primitive-in) on the given
 [feDiffuseLighting](#elementdef-fediffuselighting) element.

 [`surfaceScale`], of type [SVGAnimatedNumber](https://www.w3.org/TR/svg2/types.html#InterfaceSVGAnimatedNumber), readonly

 : Corresponds to attribute
 [surfaceScale](#element-attrdef-fediffuselighting-surfacescale) on the given
 [feDiffuseLighting](#elementdef-fediffuselighting) element.

 [`diffuseConstant`], of type [SVGAnimatedNumber](https://www.w3.org/TR/svg2/types.html#InterfaceSVGAnimatedNumber), readonly

 : Corresponds to attribute
 [diffuseConstant](#element-attrdef-fediffuselighting-diffuseconstant) on the given
 [feDiffuseLighting](#elementdef-fediffuselighting) element.

 [`kernelUnitLengthX`], of type [SVGAnimatedNumber](https://www.w3.org/TR/svg2/types.html#InterfaceSVGAnimatedNumber), readonly

 : Corresponds to attribute
 [kernelUnitLength](#element-attrdef-fediffuselighting-kernelunitlength) on the given
 [feDiffuseLighting](#elementdef-fediffuselighting) element.

 [`kernelUnitLengthY`], of type [SVGAnimatedNumber](https://www.w3.org/TR/svg2/types.html#InterfaceSVGAnimatedNumber), readonly

 : Corresponds to attribute
 [kernelUnitLength](#element-attrdef-fediffuselighting-kernelunitlength) on the given
 [feDiffuseLighting](#elementdef-fediffuselighting) element.

### [Interface SVGFEDistantLightElement]
The [`SVGFEDistantLightElement`] interface
corresponds to the
[feDistantLight](#elementdef-fedistantlight) element.

```
interface SVGFEDistantLightElement : SVGElement {
 readonly attribute SVGAnimatedNumber azimuth;
 readonly attribute SVGAnimatedNumber elevation;
};
```

Attributes:

:

 [`azimuth`], of type [SVGAnimatedNumber](https://www.w3.org/TR/svg2/types.html#InterfaceSVGAnimatedNumber), readonly

 : Corresponds to attribute
 [azimuth](#element-attrdef-fedistantlight-azimuth) on the given
 [feDistantLight](#elementdef-fedistantlight) element.

 [`elevation`], of type [SVGAnimatedNumber](https://www.w3.org/TR/svg2/types.html#InterfaceSVGAnimatedNumber), readonly

 : Corresponds to attribute
 [elevation](#element-attrdef-fedistantlight-elevation) on the given
 [feDistantLight](#elementdef-fedistantlight) element.

### [Interface SVGFEPointLightElement]
The [`SVGFEPointLightElement`] interface corresponds to the
[fePointLight](#elementdef-fepointlight) element.

```
interface SVGFEPointLightElement : SVGElement {
 readonly attribute SVGAnimatedNumber x;
 readonly attribute SVGAnimatedNumber y;
 readonly attribute SVGAnimatedNumber z;
};
```

Attributes:

:

 [`x`], of type [SVGAnimatedNumber](https://www.w3.org/TR/svg2/types.html#InterfaceSVGAnimatedNumber), readonly

 : Corresponds to attribute
 [x](#element-attrdef-fepointlight-x) on the given
 [fePointLight](#elementdef-fepointlight) element.

 [`y`], of type [SVGAnimatedNumber](https://www.w3.org/TR/svg2/types.html#InterfaceSVGAnimatedNumber), readonly

 : Corresponds to attribute
 [y](#element-attrdef-fepointlight-y) on the given
 [fePointLight](#elementdef-fepointlight) element.

 [`z`], of type [SVGAnimatedNumber](https://www.w3.org/TR/svg2/types.html#InterfaceSVGAnimatedNumber), readonly

 : Corresponds to attribute
 [z](#element-attrdef-fepointlight-z) on the given
 [fePointLight](#elementdef-fepointlight) element.

### [Interface SVGFESpotLightElement]
The [`SVGFESpotLightElement`] interface corresponds to the
[feSpotLight](#elementdef-fespotlight) element.

```
interface SVGFESpotLightElement : SVGElement {
 readonly attribute SVGAnimatedNumber x;
 readonly attribute SVGAnimatedNumber y;
 readonly attribute SVGAnimatedNumber z;
 readonly attribute SVGAnimatedNumber pointsAtX;
 readonly attribute SVGAnimatedNumber pointsAtY;
 readonly attribute SVGAnimatedNumber pointsAtZ;
 readonly attribute SVGAnimatedNumber specularExponent;
 readonly attribute SVGAnimatedNumber limitingConeAngle;
};
```

Attributes:

:

 [`x`], of type [SVGAnimatedNumber](https://www.w3.org/TR/svg2/types.html#InterfaceSVGAnimatedNumber), readonly

 : Corresponds to attribute
 [x](#element-attrdef-fespotlight-x) on the given
 [feSpotLight](#elementdef-fespotlight) element.

 [`y`], of type [SVGAnimatedNumber](https://www.w3.org/TR/svg2/types.html#InterfaceSVGAnimatedNumber), readonly

 : Corresponds to attribute
 [y](#element-attrdef-fespotlight-y) on the given
 [feSpotLight](#elementdef-fespotlight) element.

 [`z`], of type [SVGAnimatedNumber](https://www.w3.org/TR/svg2/types.html#InterfaceSVGAnimatedNumber), readonly

 : Corresponds to attribute
 [z](#element-attrdef-fespotlight-z) on the given
 [feSpotLight](#elementdef-fespotlight) element.

 [`pointsAtX`], of type [SVGAnimatedNumber](https://www.w3.org/TR/svg2/types.html#InterfaceSVGAnimatedNumber), readonly

 : Corresponds to attribute
 [pointsAtX](#element-attrdef-fespotlight-pointsatx) on the given
 [feSpotLight](#elementdef-fespotlight) element.

 [`pointsAtY`], of type [SVGAnimatedNumber](https://www.w3.org/TR/svg2/types.html#InterfaceSVGAnimatedNumber), readonly

 : Corresponds to attribute
 [pointsAtY](#element-attrdef-fespotlight-pointsaty) on the given
 [feSpotLight](#elementdef-fespotlight) element.

 [`pointsAtZ`], of type [SVGAnimatedNumber](https://www.w3.org/TR/svg2/types.html#InterfaceSVGAnimatedNumber), readonly

 : Corresponds to attribute
 [pointsAtZ](#element-attrdef-fespotlight-pointsatz) on the given
 [feSpotLight](#elementdef-fespotlight) element.

 [`specularExponent`], of type [SVGAnimatedNumber](https://www.w3.org/TR/svg2/types.html#InterfaceSVGAnimatedNumber), readonly

 : Corresponds to attribute
 [specularExponent](#element-attrdef-fespotlight-specularexponent) on the given
 [feSpotLight](#elementdef-fespotlight) element.

 [`limitingConeAngle`], of type [SVGAnimatedNumber](https://www.w3.org/TR/svg2/types.html#InterfaceSVGAnimatedNumber), readonly

 : Corresponds to attribute
 [limitingConeAngle](#element-attrdef-fespotlight-limitingconeangle) on the given
 [feSpotLight](#elementdef-fespotlight) element.

### [Interface SVGFEDisplacementMapElement]
The [`SVGFEDisplacementMapElement`] interface
corresponds to the
[feDisplacementMap](#elementdef-fedisplacementmap) element.

```
interface SVGFEDisplacementMapElement : SVGElement {

 // Channel Selectors
 const unsigned short SVG_CHANNEL_UNKNOWN = 0;
 const unsigned short SVG_CHANNEL_R = 1;
 const unsigned short SVG_CHANNEL_G = 2;
 const unsigned short SVG_CHANNEL_B = 3;
 const unsigned short SVG_CHANNEL_A = 4;

 readonly attribute SVGAnimatedString in1;
 readonly attribute SVGAnimatedString in2;
 readonly attribute SVGAnimatedNumber scale;
 readonly attribute SVGAnimatedEnumeration xChannelSelector;
 readonly attribute SVGAnimatedEnumeration yChannelSelector;
};

SVGFEDisplacementMapElement includes SVGFilterPrimitiveStandardAttributes;
```

Constants in group "Channel Selectors":

:

 [`SVG_CHANNEL_UNKNOWN`]

 : The type is not one of predefined types. It is invalid to
 attempt to define a new value of this type or to attempt to
 switch an existing value to this type.

 [`SVG_CHANNEL_R`]

 : Corresponds to value [R].

 [`SVG_CHANNEL_G`]

 : Corresponds to value [G].

 [`SVG_CHANNEL_B`]

 : Corresponds to value [B].

 [`SVG_CHANNEL_A`]

 : Corresponds to value [A].

Attributes:

:

 [`in1`], of type [SVGAnimatedString](https://www.w3.org/TR/svg2/types.html#InterfaceSVGAnimatedString), readonly

 : Corresponds to attribute
 [in](#element-attrdef-filter-primitive-in) on the given
 [feDisplacementMap](#elementdef-fedisplacementmap) element.

 [`in2`], of type [SVGAnimatedString](https://www.w3.org/TR/svg2/types.html#InterfaceSVGAnimatedString), readonly

 : Corresponds to attribute
 [in2](#element-attrdef-fedisplacementmap-in2) on the given
 [feDisplacementMap](#elementdef-fedisplacementmap) element.

 [`scale`], of type [SVGAnimatedNumber](https://www.w3.org/TR/svg2/types.html#InterfaceSVGAnimatedNumber), readonly

 : Corresponds to attribute
 [scale](#element-attrdef-fedisplacementmap-scale) on the given
 [feDisplacementMap](#elementdef-fedisplacementmap) element.

 [`xChannelSelector`], of type [SVGAnimatedEnumeration](https://www.w3.org/TR/svg2/types.html#InterfaceSVGAnimatedEnumeration), readonly

 : Corresponds to attribute
 [xChannelSelector](#element-attrdef-fedisplacementmap-xchannelselector) on the given
 [feDisplacementMap](#elementdef-fedisplacementmap) element. Takes one of the SVG_CHANNEL\_\*
 constants defined on this interface.

 [`yChannelSelector`], of type [SVGAnimatedEnumeration](https://www.w3.org/TR/svg2/types.html#InterfaceSVGAnimatedEnumeration), readonly

 : Corresponds to attribute
 [yChannelSelector](#element-attrdef-fedisplacementmap-ychannelselector) on the given
 [feDisplacementMap](#elementdef-fedisplacementmap) element. Takes one of the SVG_CHANNEL\_\*
 constants defined on this interface.

### [Interface SVGFEDropShadowElement]
The [`SVGFEDropShadowElement`] interface corresponds to the
[feDropShadow](#elementdef-fedropshadow) element.

```
interface SVGFEDropShadowElement : SVGElement {
 readonly attribute SVGAnimatedString in1;
 readonly attribute SVGAnimatedNumber dx;
 readonly attribute SVGAnimatedNumber dy;
 readonly attribute SVGAnimatedNumber stdDeviationX;
 readonly attribute SVGAnimatedNumber stdDeviationY;

 void setStdDeviation(float stdDeviationX, float stdDeviationY);
};

SVGFEDropShadowElement includes SVGFilterPrimitiveStandardAttributes;
```

Attributes:

:

 [`in1`], of type [SVGAnimatedString](https://www.w3.org/TR/svg2/types.html#InterfaceSVGAnimatedString), readonly

 : Corresponds to attribute
 [in](#element-attrdef-filter-primitive-in) on the given
 [feDropShadow](#elementdef-fedropshadow) element.

 [`dx`], of type [SVGAnimatedNumber](https://www.w3.org/TR/svg2/types.html#InterfaceSVGAnimatedNumber), readonly

 : Corresponds to attribute
 [dx](#element-attrdef-fedropshadow-dx) on the given
 [feDropShadow](#elementdef-fedropshadow) element.

 [`dy`], of type [SVGAnimatedNumber](https://www.w3.org/TR/svg2/types.html#InterfaceSVGAnimatedNumber), readonly

 : Corresponds to attribute
 [dy](#element-attrdef-fedropshadow-dy) on the given
 [feDropShadow](#elementdef-fedropshadow) element.

 [`stdDeviationX`], of type [SVGAnimatedNumber](https://www.w3.org/TR/svg2/types.html#InterfaceSVGAnimatedNumber), readonly

 : Corresponds to attribute
 [stdDeviation](#element-attrdef-fedropshadow-stddeviation) on the given
 [feDropShadow](#elementdef-fedropshadow) element. Contains the X component of
 attribute
 [stdDeviation].

 [`stdDeviationY`], of type [SVGAnimatedNumber](https://www.w3.org/TR/svg2/types.html#InterfaceSVGAnimatedNumber), readonly

 : Corresponds to attribute
 [stdDeviation](#element-attrdef-fedropshadow-stddeviation) on the given
 [feDropShadow](#elementdef-fedropshadow) element. Contains the Y component of
 attribute
 [stdDeviation].

Methods:

:

 [`setStdDeviation(stdDeviationX, stdDeviationY)`]

 : Sets the values for attribute
 [stdDeviation](#element-attrdef-fedropshadow-stddeviation).

 :::

 [`stdDeviationX`]

 : The X component of attribute
 [stdDeviation](#element-attrdef-fedropshadow-stddeviation).

 [`stdDeviationY`]

 : The Y component of attribute
 [stdDeviation](#element-attrdef-fedropshadow-stddeviation).
 :::

### [Interface SVGFEFloodElement]
The [`SVGFEFloodElement`] interface corresponds to the
[feFlood](#elementdef-feflood) element.

```
interface SVGFEFloodElement : SVGElement ;

SVGFEFloodElement includes SVGFilterPrimitiveStandardAttributes;
```

### [Interface SVGFEGaussianBlurElement]
The [`SVGFEGaussianBlurElement`] interface
corresponds to the
[feGaussianBlur](#elementdef-fegaussianblur) element.

```
interface SVGFEGaussianBlurElement : SVGElement {

 // Edge Mode Values
 const unsigned short SVG_EDGEMODE_UNKNOWN = 0;
 const unsigned short SVG_EDGEMODE_DUPLICATE = 1;
 const unsigned short SVG_EDGEMODE_WRAP = 2;
 const unsigned short SVG_EDGEMODE_NONE = 3;

 readonly attribute SVGAnimatedString in1;
 readonly attribute SVGAnimatedNumber stdDeviationX;
 readonly attribute SVGAnimatedNumber stdDeviationY;
 readonly attribute SVGAnimatedEnumeration edgeMode;

 void setStdDeviation(float stdDeviationX, float stdDeviationY);
};

SVGFEGaussianBlurElement includes SVGFilterPrimitiveStandardAttributes;
```

Constants in group "Edge Mode Values":

:

 [`SVG_EDGEMODE_UNKNOWN`]

 : The type is not one of predefined types. It is invalid to
 attempt to define a new value of this type or to attempt to
 switch an existing value to this type.

 [`SVG_EDGEMODE_DUPLICATE`]

 : Corresponds to value [duplicate].

 [`SVG_EDGEMODE_WRAP`]

 : Corresponds to value
 [wrap](#attr-valuedef-edgemode-wrap).

 [`SVG_EDGEMODE_NONE`]

 : Corresponds to value [none].

Attributes:

:

 [`in1`], of type [SVGAnimatedString](https://www.w3.org/TR/svg2/types.html#InterfaceSVGAnimatedString), readonly

 : Corresponds to attribute
 [in](#element-attrdef-filter-primitive-in) on the given
 [feGaussianBlur](#elementdef-fegaussianblur) element.

 [`stdDeviationX`], of type [SVGAnimatedNumber](https://www.w3.org/TR/svg2/types.html#InterfaceSVGAnimatedNumber), readonly

 : Corresponds to attribute
 [stdDeviation](#element-attrdef-fegaussianblur-stddeviation) on the given
 [feGaussianBlur](#elementdef-fegaussianblur) element. Contains the X component of
 attribute
 [stdDeviation].

 [`stdDeviationY`], of type [SVGAnimatedNumber](https://www.w3.org/TR/svg2/types.html#InterfaceSVGAnimatedNumber), readonly

 : Corresponds to attribute
 [stdDeviation](#element-attrdef-fegaussianblur-stddeviation) on the given
 [feGaussianBlur](#elementdef-fegaussianblur) element. Contains the Y component of
 attribute
 [stdDeviation].

 [`edgeMode`], of type [SVGAnimatedEnumeration](https://www.w3.org/TR/svg2/types.html#InterfaceSVGAnimatedEnumeration), readonly

 : Corresponds to attribute
 [edgeMode](#element-attrdef-fegaussianblur-edgemode) on the given
 [feGaussianBlur](#elementdef-fegaussianblur) element. Takes one of the SVG_EDGEMODE\_\*
 constants defined on this interface.

Methods:

:

 [`setStdDeviation(stdDeviationX, stdDeviationY)`]

 : Sets the values for attribute
 [stdDeviation](#element-attrdef-fegaussianblur-stddeviation).

 :::

 [`stdDeviationX`]

 : The X component of attribute
 [stdDeviation](#element-attrdef-fegaussianblur-stddeviation).

 [`stdDeviationY`]

 : The Y component of attribute
 [stdDeviation](#element-attrdef-fegaussianblur-stddeviation).
 :::

### [Interface SVGFEImageElement]
The [`SVGFEImageElement`] interface corresponds to the
[feImage](#elementdef-feimage) element.

```
interface SVGFEImageElement : SVGElement {
 readonly attribute SVGAnimatedPreserveAspectRatio preserveAspectRatio;
 readonly attribute SVGAnimatedString crossOrigin;
};

SVGFEImageElement includes SVGFilterPrimitiveStandardAttributes;
SVGFEImageElement includes SVGURIReference;
```

Attributes:

:

 [`preserveAspectRatio`], of type [SVGAnimatedPreserveAspectRatio](https://www.w3.org/TR/svg2/coords.html#InterfaceSVGAnimatedPreserveAspectRatio), readonly

 : Corresponds to attribute
 [preserveAspectRatio](#element-attrdef-feimage-preserveaspectratio) on the given
 [feImage](#elementdef-feimage) element.

 [`crossOrigin`], of type [SVGAnimatedString](https://www.w3.org/TR/svg2/types.html#InterfaceSVGAnimatedString), readonly

 : The crossOrigin IDL attribute must reflect the
 [crossorigin](#element-attrdef-feimage-crossorigin) content attribute, limited to only
 known values.

### [Interface SVGFEMergeElement]
The [`SVGFEMergeElement`] interface corresponds to the
[feMerge](#elementdef-femerge) element.

```
interface SVGFEMergeElement : SVGElement ;

SVGFEMergeElement includes SVGFilterPrimitiveStandardAttributes;
```

### [Interface SVGFEMergeNodeElement]
The [`SVGFEMergeNodeElement`] interface corresponds to the
[feMergeNode](#elementdef-femergenode) element.

```
interface SVGFEMergeNodeElement : SVGElement {
 readonly attribute SVGAnimatedString in1;
};
```

Attributes:

:

 [`in1`], of type [SVGAnimatedString](https://www.w3.org/TR/svg2/types.html#InterfaceSVGAnimatedString), readonly

 : Corresponds to attribute
 [in](#element-attrdef-filter-primitive-in) on the given
 [feMergeNode](#elementdef-femergenode) element.

### [Interface SVGFEMorphologyElement]
The [`SVGFEMorphologyElement`] interface corresponds to the
[feMorphology](#elementdef-femorphology) element.

```
interface SVGFEMorphologyElement : SVGElement {

 // Morphology Operators
 const unsigned short SVG_MORPHOLOGY_OPERATOR_UNKNOWN = 0;
 const unsigned short SVG_MORPHOLOGY_OPERATOR_ERODE = 1;
 const unsigned short SVG_MORPHOLOGY_OPERATOR_DILATE = 2;

 readonly attribute SVGAnimatedString in1;
 readonly attribute SVGAnimatedEnumeration operator;
 readonly attribute SVGAnimatedNumber radiusX;
 readonly attribute SVGAnimatedNumber radiusY;
};

SVGFEMorphologyElement includes SVGFilterPrimitiveStandardAttributes;
```

Constants in group "Morphology Operators":

:

 [`SVG_MORPHOLOGY_OPERATOR_UNKNOWN`]

 : The type is not one of predefined types. It is invalid to
 attempt to define a new value of this type or to attempt to
 switch an existing value to this type.

 [`SVG_MORPHOLOGY_OPERATOR_ERODE`]

 : Corresponds to value [erode].

 [`SVG_MORPHOLOGY_OPERATOR_DILATE`]

 : Corresponds to value [dilate].

Attributes:

:

 [`in1`], of type [SVGAnimatedString](https://www.w3.org/TR/svg2/types.html#InterfaceSVGAnimatedString), readonly

 : Corresponds to attribute
 [in](#element-attrdef-filter-primitive-in) on the given
 [feMorphology](#elementdef-femorphology) element.

 [`operator`], of type [SVGAnimatedEnumeration](https://www.w3.org/TR/svg2/types.html#InterfaceSVGAnimatedEnumeration), readonly

 : Corresponds to attribute
 [operator](#element-attrdef-femorphology-operator) on the given
 [feMorphology](#elementdef-femorphology) element. Takes one of the
 SVG_MORPHOLOGY_OPERATOR\_\* constants defined on this interface.

 [`radiusX`], of type [SVGAnimatedNumber](https://www.w3.org/TR/svg2/types.html#InterfaceSVGAnimatedNumber), readonly

 : Corresponds to attribute
 [radius](#element-attrdef-femorphology-radius) on the given
 [feMorphology](#elementdef-femorphology) element. Contains the X component of
 attribute
 [radius].

 [`radiusY`], of type [SVGAnimatedNumber](https://www.w3.org/TR/svg2/types.html#InterfaceSVGAnimatedNumber), readonly

 : Corresponds to attribute
 [radius](#element-attrdef-femorphology-radius) on the given
 [feMorphology](#elementdef-femorphology) element. Contains the Y component of
 attribute
 [radius].

### [Interface SVGFEOffsetElement]
The [`SVGFEOffsetElement`] interface corresponds to the
[feOffset](#elementdef-feoffset) element.

```
interface SVGFEOffsetElement : SVGElement {
 readonly attribute SVGAnimatedString in1;
 readonly attribute SVGAnimatedNumber dx;
 readonly attribute SVGAnimatedNumber dy;
};

SVGFEOffsetElement includes SVGFilterPrimitiveStandardAttributes;
```

Attributes:

:

 [`in1`], of type [SVGAnimatedString](https://www.w3.org/TR/svg2/types.html#InterfaceSVGAnimatedString), readonly

 : Corresponds to attribute
 [in](#element-attrdef-filter-primitive-in) on the given
 [feOffset](#elementdef-feoffset) element.

 [`dx`], of type [SVGAnimatedNumber](https://www.w3.org/TR/svg2/types.html#InterfaceSVGAnimatedNumber), readonly

 : Corresponds to attribute
 [dx](#element-attrdef-feoffset-dx) on the given
 [feOffset](#elementdef-feoffset) element.

 [`dy`], of type [SVGAnimatedNumber](https://www.w3.org/TR/svg2/types.html#InterfaceSVGAnimatedNumber), readonly

 : Corresponds to attribute
 [dy](#element-attrdef-feoffset-dy) on the given
 [feOffset](#elementdef-feoffset) element.

### [Interface SVGFESpecularLightingElement]
The [`SVGFESpecularLightingElement`] interface
corresponds to the
[feSpecularLighting](#elementdef-fespecularlighting) element.

```
interface SVGFESpecularLightingElement : SVGElement {
 readonly attribute SVGAnimatedString in1;
 readonly attribute SVGAnimatedNumber surfaceScale;
 readonly attribute SVGAnimatedNumber specularConstant;
 readonly attribute SVGAnimatedNumber specularExponent;
 readonly attribute SVGAnimatedNumber kernelUnitLengthX;
 readonly attribute SVGAnimatedNumber kernelUnitLengthY;
};

SVGFESpecularLightingElement includes SVGFilterPrimitiveStandardAttributes;
```

Attributes:

:

 [`in1`], of type [SVGAnimatedString](https://www.w3.org/TR/svg2/types.html#InterfaceSVGAnimatedString), readonly

 : Corresponds to attribute
 [in](#element-attrdef-filter-primitive-in) on the given
 [feSpecularLighting](#elementdef-fespecularlighting) element.

 [`surfaceScale`], of type [SVGAnimatedNumber](https://www.w3.org/TR/svg2/types.html#InterfaceSVGAnimatedNumber), readonly

 : Corresponds to attribute
 [surfaceScale](#element-attrdef-fespecularlighting-surfacescale) on the given
 [feSpecularLighting](#elementdef-fespecularlighting) element.

 [`specularConstant`], of type [SVGAnimatedNumber](https://www.w3.org/TR/svg2/types.html#InterfaceSVGAnimatedNumber), readonly

 : Corresponds to attribute
 [specularConstant](#element-attrdef-fespecularlighting-specularconstant) on the given
 [feSpecularLighting](#elementdef-fespecularlighting) element.

 [`specularExponent`], of type [SVGAnimatedNumber](https://www.w3.org/TR/svg2/types.html#InterfaceSVGAnimatedNumber), readonly

 : Corresponds to attribute
 [specularExponent](#element-attrdef-fespecularlighting-specularexponent) on the given
 [feSpecularLighting](#elementdef-fespecularlighting) element.

 [`kernelUnitLengthX`], of type [SVGAnimatedNumber](https://www.w3.org/TR/svg2/types.html#InterfaceSVGAnimatedNumber), readonly

 : Corresponds to attribute
 [kernelUnitLength](#element-attrdef-fespecularlighting-kernelunitlength) on the given
 [feSpecularLighting](#elementdef-fespecularlighting) element.

 [`kernelUnitLengthY`], of type [SVGAnimatedNumber](https://www.w3.org/TR/svg2/types.html#InterfaceSVGAnimatedNumber), readonly

 : Corresponds to attribute
 [kernelUnitLength](#element-attrdef-fespecularlighting-kernelunitlength) on the given
 [feSpecularLighting](#elementdef-fespecularlighting) element.

### [Interface SVGFETileElement]
The [`SVGFETileElement`] interface corresponds to the
[feTile](#elementdef-fetile) element.

```
interface SVGFETileElement : SVGElement {
 readonly attribute SVGAnimatedString in1;
};

SVGFETileElement includes SVGFilterPrimitiveStandardAttributes;
```

Attributes:

:

 [`in1`], of type [SVGAnimatedString](https://www.w3.org/TR/svg2/types.html#InterfaceSVGAnimatedString), readonly

 : Corresponds to attribute
 [in](#element-attrdef-filter-primitive-in) on the given
 [feTile](#elementdef-fetile) element.

### [Interface SVGFETurbulenceElement]
The [`SVGFETurbulenceElement`] interface corresponds to the
[feTurbulence](#elementdef-feturbulence) element.

```
interface SVGFETurbulenceElement : SVGElement {

 // Turbulence Types
 const unsigned short SVG_TURBULENCE_TYPE_UNKNOWN = 0;
 const unsigned short SVG_TURBULENCE_TYPE_FRACTALNOISE = 1;
 const unsigned short SVG_TURBULENCE_TYPE_TURBULENCE = 2;

 // Stitch Options
 const unsigned short SVG_STITCHTYPE_UNKNOWN = 0;
 const unsigned short SVG_STITCHTYPE_STITCH = 1;
 const unsigned short SVG_STITCHTYPE_NOSTITCH = 2;

 readonly attribute SVGAnimatedNumber baseFrequencyX;
 readonly attribute SVGAnimatedNumber baseFrequencyY;
 readonly attribute SVGAnimatedInteger numOctaves;
 readonly attribute SVGAnimatedNumber seed;
 readonly attribute SVGAnimatedEnumeration stitchTiles;
 readonly attribute SVGAnimatedEnumeration type;
};

SVGFETurbulenceElement includes SVGFilterPrimitiveStandardAttributes;
```

Constants in group "Turbulence Types":

:

 [`SVG_TURBULENCE_TYPE_UNKNOWN`]

 : The type is not one of predefined types. It is invalid to
 attempt to define a new value of this type or to attempt to
 switch an existing value to this type.

 [`SVG_TURBULENCE_TYPE_FRACTALNOISE`]

 : Corresponds to value [fractalNoise].

 [`SVG_TURBULENCE_TYPE_TURBULENCE`]

 : Corresponds to value [turbulence].

Constants in group "Stitch Options":

:

 [`SVG_STITCHTYPE_UNKNOWN`]

 : The type is not one of predefined types. It is invalid to
 attempt to define a new value of this type or to attempt to
 switch an existing value to this type.

 [`SVG_STITCHTYPE_STITCH`]

 : Corresponds to value [stitch].

 [`SVG_STITCHTYPE_NOSTITCH`]

 : Corresponds to value [noStitch].

Attributes:

:

 [`baseFrequencyX`], of type [SVGAnimatedNumber](https://www.w3.org/TR/svg2/types.html#InterfaceSVGAnimatedNumber), readonly

 : Corresponds to attribute
 [baseFrequency](#element-attrdef-feturbulence-basefrequency) on the given
 [feTurbulence](#elementdef-feturbulence) element. Contains the X component of the
 [baseFrequency]
 attribute.

 [`baseFrequencyY`], of type [SVGAnimatedNumber](https://www.w3.org/TR/svg2/types.html#InterfaceSVGAnimatedNumber), readonly

 : Corresponds to attribute
 [baseFrequency](#element-attrdef-feturbulence-basefrequency) on the given
 [feTurbulence](#elementdef-feturbulence) element. Contains the Y component of the
 [baseFrequency]
 attribute.

 [`numOctaves`], of type [SVGAnimatedInteger](https://www.w3.org/TR/svg2/types.html#InterfaceSVGAnimatedInteger), readonly

 : Corresponds to attribute
 [numOctaves](#element-attrdef-feturbulence-numoctaves) on the given
 [feTurbulence](#elementdef-feturbulence) element.

 [`seed`], of type [SVGAnimatedNumber](https://www.w3.org/TR/svg2/types.html#InterfaceSVGAnimatedNumber), readonly

 : Corresponds to attribute
 [seed](#element-attrdef-feturbulence-seed) on the given
 [feTurbulence](#elementdef-feturbulence) element.

 [`stitchTiles`], of type [SVGAnimatedEnumeration](https://www.w3.org/TR/svg2/types.html#InterfaceSVGAnimatedEnumeration), readonly

 : Corresponds to attribute
 [stitchTiles](#element-attrdef-feturbulence-stitchtiles) on the given
 [feTurbulence](#elementdef-feturbulence) element. Takes one of the
 SVG_TURBULENCE_TYPE\_\* constants defined on this interface.

 [`type`], of type [SVGAnimatedEnumeration](https://www.w3.org/TR/svg2/types.html#InterfaceSVGAnimatedEnumeration), readonly

 : Corresponds to attribute
 [type](#element-attrdef-feturbulence-type) on the given
 [feTurbulence](#elementdef-feturbulence) element. Takes one of the
 SVG_STITCHTYPE\_\* constants defined on this interface.

## [Changes]
The following significant changes were made since the [25 November 2014
Working
Draft](https://www.w3.org/TR/2014/WD-filter-effects-1-20141125/).

- Editorial changes.

- Add description elements to content model of all elements.

- Clarify that crossorigin is not animatable.

- [\<hue-rotate()\>](#funcdef-filter-hue-rotate) takes unitless zero.

- Allow author to change order of
 [\<color\>](https://www.w3.org/TR/css3-color/#valuea-def-color "Expands to: indigo | gold | firebrick | indianred | yellow | darkolivegreen | darkseagreen | slategrey | darkslategrey | mediumvioletred | mediumorchid | transparent | chartreuse | mediumslateblue | black | springgreen | crimson | lightsalmon | brown | turquoise | olivedrab | cyan | silver | skyblue | gray | darkturquoise | goldenrod | darkgreen | darkviolet | darkgray | lightpink | teal | darkmagenta | lightgoldenrodyellow | lavender | yellowgreen | thistle | violet | navy | dimgrey | orchid | blue | ghostwhite | honeydew | cornflowerblue | darkblue | darkkhaki | mediumpurple | cornsilk | red | bisque | slategray | darkcyan | khaki | wheat | deepskyblue | rebeccapurple | darkred | steelblue | aliceblue | lightslategrey | gainsboro | mediumturquoise | floralwhite | coral | purple | lightgrey | lightcyan | darksalmon | beige | azure | lightsteelblue | oldlace | greenyellow | royalblue | lightseagreen | mistyrose | sienna | lightcoral | orangered | navajowhite | lime | palegreen | burlywood | seashell | mediumspringgreen | fuchsia | papayawhip | blanchedalmond | peru | aquamarine | white | darkslategray | tomato | ivory | dodgerblue | currentcolor | lemonchiffon | chocolate | orange | forestgreen | darkgrey | olive | mintcream | antiquewhite | darkorange | cadetblue | moccasin | limegreen | saddlebrown | grey | darkslateblue | lightskyblue | deeppink | plum | aqua | darkgoldenrod | maroon | sandybrown | magenta | tan | rosybrown | pink | lightblue | palevioletred | mediumseagreen | slateblue | dimgray | powderblue | seagreen | snow | mediumblue | midnightblue | paleturquoise | palegoldenrod | whitesmoke | darkorchid | salmon | lightslategray | lawngreen | lightgreen | lightgray | hotpink | lightyellow | lavenderblush | linen | mediumaquamarine | green | blueviolet | peachpuff") and
 [\<length\>](https://www.w3.org/TR/css3-values/#length-value "Expands to: em | vb | ch | cm | vh | vi | in | ex | vw | ic | pt | px | lh | pc | rem | rlh | vmax | advance measure | vmin | mm | cap | q") values of
 [\<drop-shadow()\>](#funcdef-filter-drop-shadow). Change grammar to put
 [\<color\>]
 first. Differentiate between initial value for interpolation and
 default values for omitted values.

- Define animation type of CSS properties.

- Make
 [feColorMatrix](#elementdef-fecolormatrix) and
 [feConvolveMatrix](#elementdef-feconvolvematrix) a pass through on unfulfilled pre-conditions.

- Make
 [feTurbulence](#elementdef-feturbulence) algorithms respect uniformity.

- Apply properties that apply to all graphics elements to the use
 element as well.

- Corrected filter primitive representation of
 [\<saturate()\>](#funcdef-filter-saturate).

- Extend SVG DOM SVGFEBlendElement enumerations with new blend modes.

The following significant changes were made since the [26 November 2013
Working
Draft](https://www.w3.org/TR/2013/WD-filter-effects-1-20131126/).

- Removed Custom Filters.

- Allow the
 [script](https://www.w3.org/TR/svg2/interact.html#elementdef-script) element in the content model everywhere.

- Support all blend modes from CSS Blending specification for
 [feBlend](#elementdef-feblend).

- Support all non-duplicated compositing modes from CSS Blending
 specification for
 [feComposite](#elementdef-fecomposite).

- Added no-composite attribute to
 [feBlend](#elementdef-feblend) to avoid double compositing.

- Corrections on shorthands syntax.

- Added definition for shorthand filter regions.

The following significant changes were made since the [25 October 2012
Working Draft](https://www.w3.org/TR/2012/WD-filter-effects-20121025/).

- Correction of brightness short hand filter.

- New syntax for Custom Filter function.

- Add at-function rule for Custom Filters.

- Allow Custom Filter function to be used as extension for future filter
 features.

- Remove unnecessary attributes and uniforms on shaders.

- Redefine origin of shader coordinate space to bottom left.

- Remove now unnecessary filter-margin properties.

See more detailed and longterm changes in the [ChangeLog](ChangeLog).

## [Acknowledgments]
The editors would like to thank Robert O'Callahan, Coralie Mercier,
Chris Lilley, Nikos Andronikos, Stephen Chenney, Simon Fraser, Tavmjong
Bah, Robert Longson, Cameron McCormack, Brad Kemper, Tab Atkins, Brian
Birtles, Michael Mullany, Rik Cabanier, Anne van Kesteren, Boris
Zbarsky, Kristopher Giesing, Stephen White, Jasper van de Gronde,
Kang-Hao Lu, Paul LeBeau, Debarshi Ray, Jarek Foksa, Sebastian Zartner,
Yuqian Li, Amelia Bellamy-Royds and Max Vujovic for their careful
reviews, comments, and corrections.
