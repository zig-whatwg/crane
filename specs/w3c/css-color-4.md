## 1. Introduction

*This section is not normative.*

Tests

This section is not normative, it does not need tests.

------------------------------------------------------------------------

This module describes CSS properties which allow authors to specify the
foreground color and opacity of the text content of an element. This
module also describes in detail the CSS
[\<color\>](#typedef-color) value type.

It not only defines the color-related properties and values that already
exist in [CSS1](https://www.w3.org/TR/CSS1),
[CSS2](https://www.w3.org/TR/CSS2/), and [CSS Color
3](https://www.w3.org/TR/css-color-3/), but also defines new properties
and values.

In particular, it allows specifying colors in other [color
spaces](#color-space) than sRGB;
previously, the more saturated colors outside the sRGB gamut could not
be used in CSS even if the display device supported them.

A [draft implementation
report](https://drafts.csswg.org/css-color-4/test-coverage) is
available.

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

## 2. Color Terminology

Tests

This section provides definitions used later, it does not need tests.

------------------------------------------------------------------------

A [color] is a
definition (numeric or textual) of the human visual perception of a
light or a physical object illuminated with light. The objective study
of human color perception is termed [colorimetry].

The color of a physical object depends on how much light it reflects at
each visible wavelength, plus the actual color of the light illuminating
it (again, the amount of light at each wavelength). It is measured by a
*spectrophotometer* .

The color of something that emits light (including colors on a computer
screen) depends on how much light it emits at each visible wavelength.
It is measured by a *spectroradiometer*.

If two objects have different [spectra], but still produce the
same physical sensation, we say they have the same color. We can
calculate whether two colors are the same by converting the spectra to
CIE XYZ (three numbers).

For example a green leaf, a photograph of
that leaf displayed on a computer screen, and a print of that
photograph, are all producing a green sensation by different means. If
the screen and the printer are
[calibrated](#calibrated), the
green in the leaf, and the photo, and the print will look the same.

A [color space]
is an organization of colors with respect to an underlying
[colorimetric] model,
such that there is a clear, objectively-measurable meaning for any color
in that color space. This also means that the same color can be
expressed in multiple color spaces, or transformed from one color space
to another, while still looking the same.

A leaf is measured with a spectrophotometer and found to have the color

lch(51.2345% 21.2 130) which is lab(51.2345% -13.6271
16.2401).

This same color could be expressed in various color spaces:

```
 color(sRGB 0.41587 0.503670 0.36664);
 color(display-p3 0.43313 0.50108 0.37950);
 color(a98-rgb 0.44091 0.49971 0.37408);
 color(prophoto-rgb 0.36589 0.41717 0.31333);
 color(rec2020 0.6295 0.9657 0.3633);
```

An [additive color space] means that the coordinate system is linear in
light intensity. The [CIE]
XYZ color space is an additive color space. The Y component of XYZ is
the [luminance],
the light intensity per unit area, or \'how bright it is\'. Luminance is
measured in candelas per square meter. cd/m², also called *nits*.

In an additive color space, calculations can be done to *accurately
predict* color mixing. Most RGB spaces are not additive, because the
components are *gamma encoded*. Undoing this gamma encoding produces
linear-light values.

For example, if a light fixture contains
two identical colored lights, and only one is switched on, and the color
is measured to be
color(xyz 0.13 0.12 0.04), then the color when both are switched on will
be exactly twice that, color(xyz 0.26 0.24 0.08).

If we have two differently colored spotlights shining on a stage, and
one has the measured value color(xyz 0.15 0.24 0.17) while
the other is
color(xyz 0.11 0.06 0.06) then we can accurately predict that if the
colored beams are made to overlap, the color of the mixture will be the
sum of the XYZ component values, or color(xyz 0.26 0.30 0.23).

A [chromaticity] is a color measurement where the lightness component has been
factored out. From the identical lights example above, the *u\',v\'*
chromaticity with one light is (0.2537, 0.5268) and the chromaticity is
the same with both lights (they are the same color, it is just
brighter).

Chromaticities are additive, so they accurately predict the chromaticity
(but not the resulting lightness) of a mixture. Being two-dimensional,
chromaticity is easily represented on a *chromaticity diagram* to
predict the chromaticity of a color mixture. Any two colors can be
mixed, and the resulting colors will lie on the line joining them on the
diagram. Three colors form a plane, and the resulting colors will lie in
the triangle they form on the diagram.

![A chromaticity diagram showing (in solid colors) the
[display-p3](#valdef-color-display-p3) color space and for comparison (faded) the
[sRGB](#valdef-color-srgb) color space. The white point (D65) is also
shown.](images/UCS-display-p3.svg)

Thus, once linearized, RGB color spaces are additive, and their gamut is
defined by the chromaticities of the red, green and blue primaries, plus
the chromaticity of the [white point] (the color formed by all three primaries at
full intensity).

Most color spaces use one of a few daylight-simulating [white
points](#white-point), which are
named by the correlated color temperature (CCT)
[\[Understanding_CCT\]](#biblio-understanding_cct "What is CCT? A Guide to Choosing Correlated Color Temperature for Your Lighting")
of the corresponding black-body radiator. For example,
[D65](#d65) is a daylight whitepoint
corresponding to a correlated color temperature of 6500 Kelvin (actually
6504, because the value of Plank's constant has changed since the color
was originally defined).

To avoid cumulative round-trip errors, it is important that the
identical chromaticity values are used consistently, at all places in a
calculation. Thus, for maximum compatibility, for this specification,
the following two standard daylight-simulating [white
points](#white-point) are
defined:

Name 

x

y

CCT

[D50]

0.345700

0.358500

5003K

[D65]

0.312700

0.329000

6504K

When the measured physical characteristics (such as the
[chromaticities] of the primary colors
it uses, or the colors produced in response to a given set of inputs) of
a [color space](#color-space) or
a color-producing device are known, it is said to be
[characterized].

If in addition adjustments have been made so that a device meets
calibration targets such as white point, neutrality of greys,
predictability and consistency of tone response, then it is said to be
[calibrated].

Real physical devices cannot yet produce every possible color that the
human eye can see. The range of colors that a given device can produce
is termed the [gamut]
*(not to be confused with gamma)*. Devices with a limited gamut cannot
produce very saturated colors, like those found in a rainbow.

<figure id="fig-three-gamuts">
<p><img src="images/sRGB-DisplayP3-rec2020-in-Oklab.png"
width="1538" /></p>
<figcaption>A top-down view of three gamuts, plotted in Oklab with the
positive a-axis towards the right and the positive b-axis towards the
top; looking down the l-axis so white and neutrals are in the center.
The largest of the three gamuts is ITU Rec BT.2020; the medium-sized one
is Display P3, and the smallest is sRGB. Rendering by Alexey
Ardov.</figcaption>
</figure>

The gamuts of different [color
space](#color-space)s may be
compared by looking at the volume (in cubic Lab units) of colors that
can be expressed. The following table examines the
[predefined](#predefined) color spaces available in CSS.

color space

Volume (million Lab units)

sRGB

0.820

display-p3

1.233

a98-rgb

1.310

prophoto-rgb

2.896

rec2020

2.042

A color in CSS is either an [invalid color], as described below for each
syntactic form, or a [valid color](#valid-color).

Any color which is not an [invalid
color](#invalid-color) is a
[valid color].

A color may be a [valid color](#valid-color) but still be outside the range of colors that can be
produced by an output device (a screen, projector, or printer)

It is said to be [out of gamut].

Each [valid color](#valid-color)
is either [in-gamut] for a particular output device (screen, or printer) or it is
[out of gamut](#out-of-gamut).

For example, given a screen which covers 100% of
the display-p3 color space, but no more, the following color is out of
gamut:

``` highlight
 color(prophoto-rgb 0.88 0.45 0.10)
```

because, expressed in display-p3, one or more coordinates are either
greater that 1.0 or less than 0.0:

``` highlight
 color(display-p3 1.0844 0.43 0.1)
```

This color is valid, and could, for example, be used as a gradient stop,
but would need to be [CSS gamut
mapped](#css-gamut-mapped)
for display, producing a similar-looking but lower chroma (less
saturated) color.

## 3. Applying Color in CSS

### 3.1. Accessibility and Conveying Information By Color

Tests

This section provides authoring guidance, it does not need tests.

------------------------------------------------------------------------

Although colors can add significant information to documents and make
them more readable, color by itself should not be the sole means to
convey important information. Authors should consider the W3C Web
Content Accessibility Guidelines
[\[WCAG21\]](#biblio-wcag21 "Web Content Accessibility Guidelines (WCAG) 2.1")
when using color in their documents.

> [*1.4.1 Use of Color:* Color is not used as the only visual means of
> conveying information, indicating an action, prompting a response, or
> distinguishing a visual
> element](https://www.w3.org/TR/WCAG21/#use-of-color)

### 3.2. Foreground Color: the [color property]
Name:

[color]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<color\>](#typedef-color)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

CanvasText

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

all elements and text

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

yes

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

N/A

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

computed color, see [resolving color values](#resolving-color-values)

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value type

Tests

- [color-001.html](https://wpt.fyi/results/css/css-color/color-001.html "css/css-color/color-001.html")
 [[(live
 test)]](http://wpt.live/css/css-color/color-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/color-001.html)
- [color-002.html](https://wpt.fyi/results/css/css-color/color-002.html "css/css-color/color-002.html")
 [[(live
 test)]](http://wpt.live/css/css-color/color-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/color-002.html)
- [color-003.html](https://wpt.fyi/results/css/css-color/color-003.html "css/css-color/color-003.html")
 [[(live
 test)]](http://wpt.live/css/css-color/color-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/color-003.html)
- [inheritance.html](https://wpt.fyi/results/css/css-color/inheritance.html "css/css-color/inheritance.html")
 [[(live
 test)]](http://wpt.live/css/css-color/inheritance.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/inheritance.html)
- [color-interpolation.html](https://wpt.fyi/results/css/css-color/animation/color-interpolation.html "css/css-color/animation/color-interpolation.html")
 [[(live
 test)]](http://wpt.live/css/css-color/animation/color-interpolation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/animation/color-interpolation.html)
- [color-initial-canvastext.html](https://wpt.fyi/results/css/css-color/color-initial-canvastext.html "css/css-color/color-initial-canvastext.html")
 [[(live
 test)]](http://wpt.live/css/css-color/color-initial-canvastext.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/color-initial-canvastext.html)
- [color-valid.html](https://wpt.fyi/results/css/css-color/parsing/color-valid.html "css/css-color/parsing/color-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-color/parsing/color-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/parsing/color-valid.html)
- [color-invalid.html](https://wpt.fyi/results/css/css-color/parsing/color-invalid.html "css/css-color/parsing/color-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-color/parsing/color-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/parsing/color-invalid.html)

This property specifies the primary foreground color of the element.
This is used as the fill color of its text content, and in addition
specifies the [used
value](https://drafts.csswg.org/css-cascade-5/#used-value) that [currentcolor] resolves to, which allows
indirect references to this foreground color and affects the initial
values of various other color properties such as
[border-color](https://drafts.csswg.org/css-backgrounds-3/#propdef-border-color) and
[text-emphasis-color](https://drafts.csswg.org/css-text-decor-4/#propdef-text-emphasis-color).

[\<color\>](#typedef-color)
: Sets the primary foreground color to the specified
 [\<color\>](#typedef-color).

The
[\<color\>](#typedef-color) type provides multiple ways to syntactically specify a
given color. For example, the following declarations all specify the
sRGB color "lime":

```
em { color:  lime; } /* color keyword */
em { color:  rgb(0 255 0); } /* RGB range 0-255 */
em { color:  rgb(0% 100% 0%); } /* RGB range 0%-100% */
em { color:  color(sRGB 0 1 0); } /* sRGB range 0.0-1.0 */
```

When applied to text, this property, including its alpha component, has
no effect on "color glyphs" (such as the emoji in some fonts), which are
colored by a built-in palette. However, some colored fonts are able to
refer to a contextual "foreground color", such as by palette entry
[0xFFFF] in the `COLR` table of OpenType, or by the
[context-fill] value in SVG-in-OpenType. In such cases, the
foreground color is set by this property, identical to how it sets the
[currentcolor](#valdef-color-currentcolor) value.

### 3.3. Transparency: the [opacity property]
Opacity can be thought of as a postprocessing operation. Conceptually,
after the element (including its descendants) is rendered into an RGBA
offscreen image, the opacity setting specifies how to blend the
offscreen rendering into the current composite rendering. See [simple
alpha compositing](#alpha) for details.

Name:

[opacity]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<opacity-value\>](#typedef-opacity-opacity-value)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

1

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[all
elements](https://www.w3.org/TR/css-pseudo/#generated-content "Includes ::before and ::after pseudo-elements.")

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

map to the range \[0,1\]

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

specified number, clamped to the range \[0,1\]

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value type

Tests

- [clip-opacity-out-of-flow.html](https://wpt.fyi/results/css/css-color/clip-opacity-out-of-flow.html "css/css-color/clip-opacity-out-of-flow.html")
 [[(live
 test)]](http://wpt.live/css/css-color/clip-opacity-out-of-flow.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/clip-opacity-out-of-flow.html)
- [t32-opacity-basic-0.0-a.xht](https://wpt.fyi/results/css/css-color/t32-opacity-basic-0.0-a.xht "css/css-color/t32-opacity-basic-0.0-a.xht")
 [[(live
 test)]](http://wpt.live/css/css-color/t32-opacity-basic-0.0-a.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/t32-opacity-basic-0.0-a.xht)
- [t32-opacity-basic-0.6-a.xht](https://wpt.fyi/results/css/css-color/t32-opacity-basic-0.6-a.xht "css/css-color/t32-opacity-basic-0.6-a.xht")
 [[(live
 test)]](http://wpt.live/css/css-color/t32-opacity-basic-0.6-a.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/t32-opacity-basic-0.6-a.xht)
- [t32-opacity-basic-1.0-a.xht](https://wpt.fyi/results/css/css-color/t32-opacity-basic-1.0-a.xht "css/css-color/t32-opacity-basic-1.0-a.xht")
 [[(live
 test)]](http://wpt.live/css/css-color/t32-opacity-basic-1.0-a.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/t32-opacity-basic-1.0-a.xht)
- [t32-opacity-clamping-0.0-b.xht](https://wpt.fyi/results/css/css-color/t32-opacity-clamping-0.0-b.xht "css/css-color/t32-opacity-clamping-0.0-b.xht")
 [[(live
 test)]](http://wpt.live/css/css-color/t32-opacity-clamping-0.0-b.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/t32-opacity-clamping-0.0-b.xht)
- [t32-opacity-clamping-1.0-b.xht](https://wpt.fyi/results/css/css-color/t32-opacity-clamping-1.0-b.xht "css/css-color/t32-opacity-clamping-1.0-b.xht")
 [[(live
 test)]](http://wpt.live/css/css-color/t32-opacity-clamping-1.0-b.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/t32-opacity-clamping-1.0-b.xht)
- [t32-opacity-offscreen-b.xht](https://wpt.fyi/results/css/css-color/t32-opacity-offscreen-b.xht "css/css-color/t32-opacity-offscreen-b.xht")
 [[(live
 test)]](http://wpt.live/css/css-color/t32-opacity-offscreen-b.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/t32-opacity-offscreen-b.xht)
- [t32-opacity-offscreen-multiple-boxes-1-c.xht](https://wpt.fyi/results/css/css-color/t32-opacity-offscreen-multiple-boxes-1-c.xht "css/css-color/t32-opacity-offscreen-multiple-boxes-1-c.xht")
 [[(live
 test)]](http://wpt.live/css/css-color/t32-opacity-offscreen-multiple-boxes-1-c.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/t32-opacity-offscreen-multiple-boxes-1-c.xht)
- [t32-opacity-offscreen-multiple-boxes-2-c.xht](https://wpt.fyi/results/css/css-color/t32-opacity-offscreen-multiple-boxes-2-c.xht "css/css-color/t32-opacity-offscreen-multiple-boxes-2-c.xht")
 [[(live
 test)]](http://wpt.live/css/css-color/t32-opacity-offscreen-multiple-boxes-2-c.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/t32-opacity-offscreen-multiple-boxes-2-c.xht)
- [t32-opacity-offscreen-with-alpha-c.xht](https://wpt.fyi/results/css/css-color/t32-opacity-offscreen-with-alpha-c.xht "css/css-color/t32-opacity-offscreen-with-alpha-c.xht")
 [[(live
 test)]](http://wpt.live/css/css-color/t32-opacity-offscreen-with-alpha-c.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/t32-opacity-offscreen-with-alpha-c.xht)
- [t32-opacity-zorder-c.xht](https://wpt.fyi/results/css/css-color/t32-opacity-zorder-c.xht "css/css-color/t32-opacity-zorder-c.xht")
 [[(live
 test)]](http://wpt.live/css/css-color/t32-opacity-zorder-c.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/t32-opacity-zorder-c.xht)
- [opacity-computed.html](https://wpt.fyi/results/css/css-color/parsing/opacity-computed.html "css/css-color/parsing/opacity-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-color/parsing/opacity-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/parsing/opacity-computed.html)
- [opacity-valid.html](https://wpt.fyi/results/css/css-color/parsing/opacity-valid.html "css/css-color/parsing/opacity-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-color/parsing/opacity-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/parsing/opacity-valid.html)
- [opacity-invalid.html](https://wpt.fyi/results/css/css-color/parsing/opacity-invalid.html "css/css-color/parsing/opacity-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-color/parsing/opacity-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/parsing/opacity-invalid.html)
- [composited-filters-under-opacity.html](https://wpt.fyi/results/css/css-color/composited-filters-under-opacity.html "css/css-color/composited-filters-under-opacity.html")
 [[(live
 test)]](http://wpt.live/css/css-color/composited-filters-under-opacity.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/composited-filters-under-opacity.html)
- [filters-under-will-change-opacity.html](https://wpt.fyi/results/css/css-color/filters-under-will-change-opacity.html "css/css-color/filters-under-will-change-opacity.html")
 [[(live
 test)]](http://wpt.live/css/css-color/filters-under-will-change-opacity.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/filters-under-will-change-opacity.html)
- [color-composition.html](https://wpt.fyi/results/css/css-color/animation/color-composition.html "css/css-color/animation/color-composition.html")
 [[(live
 test)]](http://wpt.live/css/css-color/animation/color-composition.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/animation/color-composition.html)
- [opacity-interpolation.html](https://wpt.fyi/results/css/css-color/animation/opacity-interpolation.html "css/css-color/animation/opacity-interpolation.html")
 [[(live
 test)]](http://wpt.live/css/css-color/animation/opacity-interpolation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/animation/opacity-interpolation.html)
- [canvas-change-opacity.html](https://wpt.fyi/results/css/css-color/canvas-change-opacity.html "css/css-color/canvas-change-opacity.html")
 [[(live
 test)]](http://wpt.live/css/css-color/canvas-change-opacity.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/canvas-change-opacity.html)
- [opacity-animation-ending-correctly-001.html](https://wpt.fyi/results/css/css-color/animation/opacity-animation-ending-correctly-001.html "css/css-color/animation/opacity-animation-ending-correctly-001.html")
 [[(live
 test)]](http://wpt.live/css/css-color/animation/opacity-animation-ending-correctly-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/animation/opacity-animation-ending-correctly-001.html)
- [opacity-animation-ending-correctly-002.html](https://wpt.fyi/results/css/css-color/animation/opacity-animation-ending-correctly-002.html "css/css-color/animation/opacity-animation-ending-correctly-002.html")
 [[(live
 test)]](http://wpt.live/css/css-color/animation/opacity-animation-ending-correctly-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/animation/opacity-animation-ending-correctly-002.html)

[[\<opacity-value\>](#typedef-opacity-opacity-value)]

: The opacity to be applied to the element. The resulting opacity is
 applied to the entire element, rather than a particular color.

 Opacity values outside the range \[0,1\] are not invalid, and are
 preserved in specified values, but are clamped to the range \[0, 1\]
 in computed values.

Tests

- [inline-opacity-float-child.html](https://wpt.fyi/results/css/css-color/inline-opacity-float-child.html "css/css-color/inline-opacity-float-child.html")
 [[(live
 test)]](http://wpt.live/css/css-color/inline-opacity-float-child.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/inline-opacity-float-child.html)

Opacity in CSS is represented using the
[\<opacity-value\>](#typedef-opacity-opacity-value) syntax, for example in the
[opacity](#propdef-opacity) property.

```
<opacity-value> = <number> | <percentage>
```

Represented as a
[\<number\>](https://drafts.csswg.org/css-values-4/#number-value), the useful range of the value is
[0] (representing full transparency) to [1] (representing
full opacity). It can also be written as a
[\<percentage\>](https://drafts.csswg.org/css-values-4/#percentage-value), which [computes
to](https://drafts.csswg.org/css-cascade-5/#computed-value) the equivalent [\<number\>] ([0%] to [0], [100%] to [1]).

The [opacity](#propdef-opacity) property applies the specified opacity to the
element *as a whole*, including its contents, rather than applying it to
each descendant individually. This means that, for example, an opaque
child occluding part of the element's background will continue to do so
even when [opacity] is less than 1,
but the element and child as a whole will show the underlying page
through themselves.

It also means that the glyphs corresponding to all characters in the
element are treated *as a whole*; any overlapping portions do not
increase the opacity.

Tests

- [opacity-overlapping-letters.html](https://wpt.fyi/results/css/css-color/opacity-overlapping-letters.html "css/css-color/opacity-overlapping-letters.html")
 [[(live
 test)]](http://wpt.live/css/css-color/opacity-overlapping-letters.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/opacity-overlapping-letters.html)

![Correct and incorrect rendering of text with an
[opacity](#propdef-opacity) value of less than one, whose glyphs
overlap.](images/joining-and-transparency.svg)

If separate opacity for each glyph is desired, it can be achieved by
using a color value which includes alpha, rather than setting the
[opacity](#propdef-opacity) property.

If a box has [opacity](#propdef-opacity) less than 1, it forms a [stacking
context](https://drafts.csswg.org/css2/#stacking-context) for its children. (This prevents its contents from
interleaving in the z-axis with content outside it.)

Tests

- [body-opacity-0-to-1-stacking-context.html](https://wpt.fyi/results/css/css-color/body-opacity-0-to-1-stacking-context.html "css/css-color/body-opacity-0-to-1-stacking-context.html")
 [[(live
 test)]](http://wpt.live/css/css-color/body-opacity-0-to-1-stacking-context.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/body-opacity-0-to-1-stacking-context.html)

Furthermore, if the
[z-index](https://drafts.csswg.org/css2/#propdef-z-index) property applies to the box, the
[auto](https://drafts.csswg.org/css2/#valdef-z-index-auto) value is treated as [0] for the element;
it is otherwise painted on the same layer within its parent stacking
context as positioned elements with stack level 0 (as if it were a
positioned element with [z-index:0]).

See [section 9.9](https://www.w3.org/TR/CSS21/visuren.html#layers) and
[Appendix E](https://www.w3.org/TR/CSS21/zindex.html) of
[\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")
for more information on stacking contexts.

These rules about z-order do not apply to SVG elements, since SVG has
its own [rendering model](https://www.w3.org/TR/SVG11/render.html)
([\[SVG11\]](#biblio-svg11 "Scalable Vector Graphics (SVG) 1.1 (Second Edition)"),
Chapter 3).

The value of the [opacity](#propdef-opacity) property does *not* affect hit
testing.

### 3.4. Color Space of Tagged Images

An [tagged image] is an image that is explicitly assigned a color profile, as
defined by the image format. This is usually done by including an
International Color Consortium (ICC) profile
[\[ICC\]](#biblio-icc "ICC.1:2022 (Profile version 4.4.0.0)").

For example JPEG
[\[JPEG\]](#biblio-jpeg "JPEG File Interchange Format"),
PNG
[\[PNG\]](#biblio-png "Portable Network Graphics (PNG) Specification (Third Edition)")
and TIFF
[\[TIFF\]](#biblio-tiff "TIFF Revision 6.0") all
specify a means to embed an ICC profile.

Image formats may also use other, equivalent methods, often for brevity.

For example, PNG specifies a means (the [sRGB
chunk](https://www.w3.org/TR/PNG/#11sRGB)) to explicitly tag an image as
being in the sRGB color space, without including the sRGB ICC profile.

Similarly, PNG specifies a compact means (the [cICP
chunk](https://www.w3.org/TR/png-3/#cICP-chunk)) to explicitly tag an
image as being one of various SDR or HDR color spaces, such as Display
P3 or BT.2100 HLG, without including an ICC profile.

Tagged RGB images, and tagged images using a transformation of RGB such
as YCbCr, if the color profile or other identifying information is
valid, must be treated as being in the specified color space.

Tests

- [tagged-images-001.html](https://wpt.fyi/results/css/css-color/tagged-images-001.html "css/css-color/tagged-images-001.html")
 [[(live
 test)]](http://wpt.live/css/css-color/tagged-images-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/tagged-images-001.html)
- [tagged-images-002.html](https://wpt.fyi/results/css/css-color/tagged-images-002.html "css/css-color/tagged-images-002.html")
 [[(live
 test)]](http://wpt.live/css/css-color/tagged-images-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/tagged-images-002.html)
- [tagged-images-003.html](https://wpt.fyi/results/css/css-color/tagged-images-003.html "css/css-color/tagged-images-003.html")
 [[(live
 test)]](http://wpt.live/css/css-color/tagged-images-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/tagged-images-003.html)
- [tagged-images-004.html](https://wpt.fyi/results/css/css-color/tagged-images-004.html "css/css-color/tagged-images-004.html")
 [[(live
 test)]](http://wpt.live/css/css-color/tagged-images-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/tagged-images-004.html)

<!-- -->

- [cicp-chunk.html](https://wpt.fyi/results/png/cicp-chunk.html "png/cicp-chunk.html")
 [[(live
 test)]](http://wpt.live/png/cicp-chunk.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/png/cicp-chunk.html)
- [fDAT-inherits-cICP.html](https://wpt.fyi/results/png/apng/fDAT-inherits-cICP.html "png/apng/fDAT-inherits-cICP.html")
 [[(live
 test)]](http://wpt.live/png/apng/fDAT-inherits-cICP.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/png/apng/fDAT-inherits-cICP.html)

For example, when a browser running on a system with a Display P3
monitor displays an JPEG image tagged as being in the ITU Rec BT.2020
[\[Rec.2020\]](#biblio-rec2020 "Recommendation ITU-R BT.2020-2: Parameter values for ultra-high definition television systems for production and international programme exchange")
color space, it must convert the colors from ITU Rec BT.2020 to Display
P3 so that they display correctly. It must not treat the ITU Rec BT.2020
values as if they were Display P3 values, which would produce incorrect
colors.

If the color profile or other identifying information is invalid, the
image is treated as described for [untagged
images](#untagged-image).

### 3.5. Color Spaces of Untagged Colors

For compatibility, colors specified in HTML, and [untagged
images](#untagged-image) must
be treated as being in the sRGB color space
([\[SRGB\]](#biblio-srgb "Multimedia systems and equipment - Colour measurement and management - Part 2-1: Colour management - Default RGB colour space - sRGB"))
unless otherwise specified.

Tests

- [untagged-images-001.html](https://wpt.fyi/results/css/css-color/untagged-images-001.html "css/css-color/untagged-images-001.html")
 [[(live
 test)]](http://wpt.live/css/css-color/untagged-images-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/untagged-images-001.html)

An [untagged image] is an image that is not explicitly assigned a color profile,
as defined by the image format.

This rule does not apply to untagged videos, since [untagged
video]
should be presumed to be in an ITU-defined color space.

- At below 720p, it is Recommendation ITU-R BT.601
 [\[ITU-R-BT.601\]](#biblio-itu-r-bt601 "Recommendation ITU-R BT.601")

- At 720p, it is SMPTE ST 296 (same colorimetry as 709)
 [\[SMPTE296\]](#biblio-smpte296 "ST 296:2012, 1280 × 720 Progressive Image 4:2:2 and 4:4:4 Sample Structure — Analog and Digital Representation and Analog Interface")

- At 1080p, it is Recommendation ITU-R BT.709
 [\[ITU-R-BT.709\]](#biblio-itu-r-bt709 "Recommendation ITU-R BT.709")

- At 4k (UHDTV) and above, it is ITU-R BT.2020
 [\[Rec.2020\]](#biblio-rec2020 "Recommendation ITU-R BT.2020-2: Parameter values for ultra-high definition television systems for production and international programme exchange")
 for SDR video

## 4. Representing Colors: the [\<color\> type]
Tests

This section describes a type, it is primarily tested where that type is
used.

------------------------------------------------------------------------

Colors in CSS are represented as a list of color components, also
sometimes called "channels", representing axises in the color space.
Each component has a minimum and maximum value, and can take any value
between those two. Additionally, every color is accompanied by an [alpha
component], indicating how transparent it is,
and thus how much of the backdrop one can see through the color.

CSS has several syntaxes for specifying color values:

- the sRGB [hex color notation](#hex-color) which represents the RGB and alpha components in
 hexadecimal notation

- the various [color
 functions](#color-functions)
 which can represent colors using a variety of color spaces and
 coordinate systems

- the constant [named color](#named-color) keywords

- the variable
 [\<system-color\>](#typedef-system-color) keywords and
 [currentColor](#valdef-color-currentcolor) keyword.

The [color functions] use CSS [functional
notation](https://drafts.csswg.org/css-values-4/#functional-notation) to represent colors in a variety of [color
spaces](#color-space) by
specifying their component coordinates. Some of these use a [cylindrical
polar color] model, specifying color by a
[\<hue\>](#typedef-hue) angle, a central axis representing lightness
(black-to-white), and a radius representing saturation or chroma (how
far the color is from a neutral grey). The others use a [rectangular
orthogonal color] model, specifying color using three orthogonal
component axes.

The [color functions](#color-functions) available in Level 4 are

- [rgb()](#funcdef-rgb) and
 its [rgba()](#funcdef-rgba) alias, which (like the [hex color
 notation](#hex-color)) specify
 sRGB colors directly by their red/green/blue/alpha components.

- [hsl()](#funcdef-hsl) and
 its [hsla()](#funcdef-hsla) alias, which specify sRGB colors by hue,
 saturation, and lightness using the [HSL](#the-hsl-notation)
 cylindrical coordinate model.

- [hwb()](#funcdef-hwb),
 which specifies an sRGB color by hue, whiteness, and blackness using
 the [HWB](#the-hwb-notation) cylindrical coordinate model.

- [lab()](#funcdef-lab),
 which specifies a CIELAB color by CIE Lightness and its a- and b-axis
 hue coordinates (red/green-ness, and yellow/blue-ness) using the [CIE
 LAB rectangular coordinate model](#cie-lab).

- [lch()](#funcdef-lch) ,
 which specifies a CIELAB color by CIE Lightness, Chroma, and hue using
 the [CIE LCH cylindrical coordinate model](#cie-lab)

- [oklab()](#funcdef-oklab), which specifies an Oklab color by Oklab Lightness
 and its a- and b-axis hue coordinates (red/green-ness, and
 yellow/blue-ness) using the [Oklab](#ok-lab) rectangular coordinate
 model.

- [oklch()](#funcdef-oklch) , which specifies an Oklab color by Oklab
 Lightness, Chroma, and hue using the [OkLCh](#ok-lab) cylindrical
 coordinate model.

- [color()](#funcdef-color), which allows specifying colors in a variety of
 color spaces including [sRGB](#predefined-sRGB), [Linear-Light
 sRGB](#predefined-sRGB-linear), [Display P3](#predefined-display-p3),
 [Linear-Light Display P3](#predefined-display-p3-linear), [A98
 RGB](#predefined-a98-rgb), [ProPhoto RGB](#predefined-prophoto-rgb),
 [ITU-R BT.2020-2](#predefined-rec2020), and [CIE
 XYZ](#predefined-xyz).

For easy reference in other specifications, [opaque black] is defined as the color
[[rgb(0 0 0 / 100%)]]{style=";white-space:nowrap"}; [transparent
black] is
the same color, but fully transparent---​i.e. [[rgb(0 0 0 /
0%)]]{style=";white-space:nowrap"}.

Tests

- [color-computed-named-color.html](https://wpt.fyi/results/css/css-color/parsing/color-computed-named-color.html "css/css-color/parsing/color-computed-named-color.html")
 [[(live
 test)]](http://wpt.live/css/css-color/parsing/color-computed-named-color.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/parsing/color-computed-named-color.html)
- [color-computed.html](https://wpt.fyi/results/css/css-color/parsing/color-computed.html "css/css-color/parsing/color-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-color/parsing/color-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/parsing/color-computed.html)
- [color-valid.html](https://wpt.fyi/results/css/css-color/parsing/color-valid.html "css/css-color/parsing/color-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-color/parsing/color-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/parsing/color-valid.html)

### 4.1. The [\<color\> syntax]
Tests

This section provides definitions used later, it does not need tests.

------------------------------------------------------------------------

Colors in CSS are represented by the
[[\<color\>](#typedef-color)] type:

```
<color> = <color-base> | currentColor | <system-color>

<color-base> = <hex-color> | <color-function> | <named-color> | transparent
<color-function> = <rgb()> | <rgba()> |
 <hsl()> | <hsla()> | <hwb()> |
 <lab()> | <lch()> | <oklab()> | <oklch()> |
 <color()>
```

An [absolute color] is a [\<color\>](#typedef-color) whose computed value has an absolute,
colorimetric interpretation. This means that the value is not:

- [currentColor](#valdef-color-currentcolor) (which depends on the value of the
 [color](#propdef-color) property)

- a
 [\<system-color\>](#typedef-system-color) (which depends on the color mode)

The colors that [resolve to sRGB] are:

- [hex](#hex-notation) colors

- [rgb()](#funcdef-rgb)
 and [rgba()](#funcdef-rgba) values

- [hsl()](#funcdef-hsl)
 and [hsla()](#funcdef-hsla) values

- [hwb()](#funcdef-hwb)
 values

- [named](#named-colors) colors

The functions that [support legacy color
syntax] are:

- [rgb()](#funcdef-rgb)
 and [rgba()](#funcdef-rgba)

- [hsl()](#funcdef-hsl)
 and [hsla()](#funcdef-hsla)

The [\<hsl()\>](#funcdef-hsl),
[\<hsla()\>](#funcdef-hsla), [\<hwb()\>](#funcdef-hwb),
[\<lch()\>](#funcdef-lch), and
[\<oklch()\>](#funcdef-oklch) [color
functions](#color-functions)
are [cylindrical polar
color](#cylindrical-polar-color) representations using a
[\<hue\>](#typedef-hue) angle; the other [color
functions] use [rectangular orthogonal
color](#rectangular-orthogonal-color) representations.

#### 4.1.1. Modern (Space-separated) Color Function Syntax

All of the [absolute color](#absolute-color) functional forms first defined in this specification
use the [modern color syntax], meaning:

- color components are separated by whitespace

- the optional alpha term is separated by a solidus (\"/\")

- minimum required precision [when
 serializing](#serializing-color-values) is defined, and may be greater
 than 8 bits per component

- the [none](#valdef-color-none) value is allowed, to represent [missing
 components](#missing-color-component)

- components using
 [\<percentage\>](https://drafts.csswg.org/css-values-4/#percentage-value) and
 [\<number\>](https://drafts.csswg.org/css-values-4/#number-value) may be freely mixed

The following represents a saturated sRGB red that is 50% opaque:

``` highlight
rgb(100% 0% 0% / 50%)
```

#### 4.1.2. Legacy (Comma-separated) Color Function Syntax

For Web compatibility, the syntactic forms of
[rgb()](#funcdef-rgb),
[rgba()](#funcdef-rgba),
[hsl()](#funcdef-hsl), and
[hsla()](#funcdef-hsla),
(those defined in earlier specifications) also support a [legacy color
syntax]
which has the following differences:

- color components are separated by commas (optionally preceded and/or
 followed by whitespace)

- non-opaque forms use a separate notation (for example
 [hsla()](#funcdef-hsla)
 rather than [hsl()](#funcdef-hsl)) and the alpha term is separated by commas
 (optionally preceded and/or followed by whitespace)

- minimum required precision is lower, 8 bits per component

- the [none](#valdef-color-none) value is not allowed

- color components must be specified using either
 all-[\<percentage\>](https://drafts.csswg.org/css-values-4/#percentage-value) or
 all-[\<number\>](https://drafts.csswg.org/css-values-4/#number-value), they can not be mixed.

The following represents a saturated sRGB red that is 50% opaque:

``` highlight
rgba(100%, 0%, 0%, 0.5)
```

For the [color functions](#color-functions) introduced in this or subsequent levels, where there is
no Web compatibility issue, the [legacy color
syntax](#legacy-color-syntax) is invalid.

### 4.2. Representing Transparency in Colors: the [\<alpha-value\> syntax]
Tests

This section provides definitions used later, it does not need tests.

------------------------------------------------------------------------

```
<alpha-value> = <number> | <percentage>
```

 This syntax is used as-is for [legacy color
syntax](#legacy-color-syntax). For [modern color
syntax](#modern-color-syntax), it is extended so that alpha components can also take
the value [none](#valdef-color-none).

Unless otherwise specified, an
[\<alpha-value\>](#typedef-color-alpha-value) component of a color defaults to
[100%] when omitted. Values outside the range \[0,1\] are not
invalid, but are clamped to that range at parsed-value time.

### 4.3. Representing Cylindrical-coordinate Hues: the [\<hue\> syntax]
Tests

This section provides definitions used later, it does not need tests.

------------------------------------------------------------------------

Hue is represented as an angle of the color circle (the rainbow, twisted
around into a circle, and with purple added between violet and red).

```
<hue> = <number> | <angle>
```

Because this value is so often given in degrees, the argument can also
be given as a number, which is interpreted as a number of degrees and is
the [canonical
unit](https://drafts.csswg.org/css-values-4/#canonical-unit).

This number is normalized to the range \[0,360).

For example, in [hsl(-540 0 0)] or [hsl(540 0 0)], the
[\<hue\>](#typedef-hue) component is normalized to 180 degrees.

In [hsl(360 0 0)] the
[\<hue\>](#typedef-hue) component is normalized to 0 degrees.

In [hsl(calc(-infinity) 0 0)] or
 [hsl(calc(infinity) 0 0)], the
[\<hue\>](#typedef-hue) component is again normalized to 0 degrees.

 The angles and spacing corresponding to particular hues
depend on the color space. For example, in HSL and HWB, which use the
sRGB color space, sRGB green is 120 degrees. In LCH, sRGB green is
134.39 degrees, display-p3 green is 136.01 degrees, a98-rgb green is
145.97 degrees and prophoto-rgb green is 141.04 degrees (because these
are all different shades of green).

[\<hue\>](#typedef-hue) components are the most common components to become
[powerless](#powerless-color-component); any color sufficiently close to the central achromatic
axis will have a [powerless] hue
component.

### 4.4. "Missing" Color Components and the [none Keyword]
In certain cases, a color can have one or more [missing color
components].

In this specification, this happens automatically due to [hue-based
interpolation](#hue-interpolation) for some colors (such as
[white](#valdef-color-white)); other specifications can define additional
situations in which components are automatically missing.

It can also be specified explicitly, by providing the keyword
[none] for a component in a color function. All
color functions (with the exception of those using the [legacy color
syntax](#legacy-color-syntax)) allow any of their components to be specified as
[none](#valdef-color-none).

This should be done with care, and only when the particular effect of
doing so is desired.

Tests

- [none-components-treated-as-zero.html](https://wpt.fyi/results/css/css-color/none-components-treated-as-zero.html "css/css-color/none-components-treated-as-zero.html")
 [[(live
 test)]](http://wpt.live/css/css-color/none-components-treated-as-zero.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/none-components-treated-as-zero.html)
- [color-computed-color-function.html](https://wpt.fyi/results/css/css-color/parsing/color-computed-color-function.html "css/css-color/parsing/color-computed-color-function.html")
 [[(live
 test)]](http://wpt.live/css/css-color/parsing/color-computed-color-function.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/parsing/color-computed-color-function.html)
- [color-computed-hsl.html](https://wpt.fyi/results/css/css-color/parsing/color-computed-hsl.html "css/css-color/parsing/color-computed-hsl.html")
 [[(live
 test)]](http://wpt.live/css/css-color/parsing/color-computed-hsl.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/parsing/color-computed-hsl.html)
- [color-computed-hwb.html](https://wpt.fyi/results/css/css-color/parsing/color-computed-hwb.html "css/css-color/parsing/color-computed-hwb.html")
 [[(live
 test)]](http://wpt.live/css/css-color/parsing/color-computed-hwb.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/parsing/color-computed-hwb.html)
- [color-computed-lab.html](https://wpt.fyi/results/css/css-color/parsing/color-computed-lab.html "css/css-color/parsing/color-computed-lab.html")
 [[(live
 test)]](http://wpt.live/css/css-color/parsing/color-computed-lab.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/parsing/color-computed-lab.html)
- [color-computed-none.html](https://wpt.fyi/results/css/css-color/parsing/color-computed-none.html "css/css-color/parsing/color-computed-none.html")
 [[(live
 test)]](http://wpt.live/css/css-color/parsing/color-computed-none.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/parsing/color-computed-none.html)
- [color-computed-powerless.html](https://wpt.fyi/results/css/css-color/parsing/color-computed-powerless.html "css/css-color/parsing/color-computed-powerless.html")
 [[(live
 test)]](http://wpt.live/css/css-color/parsing/color-computed-powerless.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/parsing/color-computed-powerless.html)
- [color-computed-relative-color.html](https://wpt.fyi/results/css/css-color/parsing/color-computed-relative-color.html "css/css-color/parsing/color-computed-relative-color.html")
 [[(live
 test)]](http://wpt.live/css/css-color/parsing/color-computed-relative-color.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/parsing/color-computed-relative-color.html)
- [color-computed-rgb.html](https://wpt.fyi/results/css/css-color/parsing/color-computed-rgb.html "css/css-color/parsing/color-computed-rgb.html")
 [[(live
 test)]](http://wpt.live/css/css-color/parsing/color-computed-rgb.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/parsing/color-computed-rgb.html)
- [color-invalid-hsl.html](https://wpt.fyi/results/css/css-color/parsing/color-invalid-hsl.html "css/css-color/parsing/color-invalid-hsl.html")
 [[(live
 test)]](http://wpt.live/css/css-color/parsing/color-invalid-hsl.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/parsing/color-invalid-hsl.html)
- [color-invalid-rgb.html](https://wpt.fyi/results/css/css-color/parsing/color-invalid-rgb.html "css/css-color/parsing/color-invalid-rgb.html")
 [[(live
 test)]](http://wpt.live/css/css-color/parsing/color-invalid-rgb.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/parsing/color-invalid-rgb.html)
- [color-valid-color-function.html](https://wpt.fyi/results/css/css-color/parsing/color-valid-color-function.html "css/css-color/parsing/color-valid-color-function.html")
 [[(live
 test)]](http://wpt.live/css/css-color/parsing/color-valid-color-function.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/parsing/color-valid-color-function.html)
- [color-valid-color-mix-function.html](https://wpt.fyi/results/css/css-color/parsing/color-valid-color-mix-function.html "css/css-color/parsing/color-valid-color-mix-function.html")
 [[(live
 test)]](http://wpt.live/css/css-color/parsing/color-valid-color-mix-function.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/parsing/color-valid-color-mix-function.html)
- [color-valid-hsl.html](https://wpt.fyi/results/css/css-color/parsing/color-valid-hsl.html "css/css-color/parsing/color-valid-hsl.html")
 [[(live
 test)]](http://wpt.live/css/css-color/parsing/color-valid-hsl.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/parsing/color-valid-hsl.html)
- [color-valid-hwb.html](https://wpt.fyi/results/css/css-color/parsing/color-valid-hwb.html "css/css-color/parsing/color-valid-hwb.html")
 [[(live
 test)]](http://wpt.live/css/css-color/parsing/color-valid-hwb.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/parsing/color-valid-hwb.html)
- [color-valid-lab.html](https://wpt.fyi/results/css/css-color/parsing/color-valid-lab.html "css/css-color/parsing/color-valid-lab.html")
 [[(live
 test)]](http://wpt.live/css/css-color/parsing/color-valid-lab.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/parsing/color-valid-lab.html)
- [color-valid-relative-color.html](https://wpt.fyi/results/css/css-color/parsing/color-valid-relative-color.html "css/css-color/parsing/color-valid-relative-color.html")
 [[(live
 test)]](http://wpt.live/css/css-color/parsing/color-valid-relative-color.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/parsing/color-valid-relative-color.html)
- [color-valid-rgb.html](https://wpt.fyi/results/css/css-color/parsing/color-valid-rgb.html "css/css-color/parsing/color-valid-rgb.html")
 [[(live
 test)]](http://wpt.live/css/css-color/parsing/color-valid-rgb.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/parsing/color-valid-rgb.html)

For handling of [missing
components](#missing-color-component) in situations which combine two colors, such as color
interpolation, see [§ 13.3 Interpolating with Missing
Components](#interpolation-missing).

For all other purposes, a [missing
component](#missing-color-component) behaves as a zero value, in the appropriate unit for
that component: [0], [0%], or [0deg]. This includes
rendering the color directly, converting it to another color space,
performing computations on the color component values, etc.

If a color with a [missing
component](#missing-color-component) is serialized or otherwise presented directly to an
author, then for [legacy color
syntax](#legacy-color-syntax) it represents that component as a zero value;
otherwise, it represents that component as being the
[none](#valdef-color-none) keyword.

A missing hue is common when
interpolating in cylindrical color spaces. For example, using the
[color-mix()](https://drafts.csswg.org/css-color-5/#funcdef-color-mix) function specified in
[\[CSS-COLOR-5\]](#biblio-css-color-5 "CSS Color Module Level 5")
one could write [color-mix(in hsl, white 30%, green 70%)]. Since
[white](#valdef-color-white) is an achromatic color, it has a
[missing](#missing-color-component) hue when expressed in
[hsl()](#funcdef-hsl)
(effectively [hsl(none 0% 100%))], since *any* hue will produce
the same color) which means that the color-mix function will treat it as
having the same hue as
[green](#valdef-color-green) (effectively [hsl(120deg 0% 100%)]), and then
interpolate based on those components.

The result will be a color that truly looks like a blend of green and
white, rather than perhaps looking reddish (if
[white](#valdef-color-white)s hue was defaulted to [0deg]).

Explicitly specifying missing
components can be useful to achieve an effect where you only *want* to
interpolate certain components of a color.

For example, to animate a color to \"grayscale\", no matter what the
color is, one can interpolate it with [oklch(none 0 none)]. This
will take the hue and lightness from the starting color, but animate its
chroma down to 0, rendering it into an equal-lightness gray with a
steady hue across the whole animation.

Doing this manually would require matching the hue and lightness of the
starting color explicitly.

#### 4.4.1. "Powerless" Color Components

Individual color syntaxes can specify that, in some cases, a given
component of their syntax becomes a [powerless color
component]. This indicates that
the value of the component doesn't affect the rendered color; any value
you give it will result in the same color displayed in the screen.

For example, in [hsl()](#funcdef-hsl), the hue component is
[powerless](#powerless-color-component) when the saturation component is [0%]; a
[0%] saturation indicates a grayscale color, which has no hue at
all, so [0deg] and [180deg], or any other angle, will give
the exact same result.

If a [powerless
component](#powerless-color-component) is manually specified, it acts as normal; the fact that
it's [powerless] has no effect.

However, if a color is automatically produced by color space conversion,
then any [powerless
components](#powerless-color-component) in the result must instead be set to
[missing](#missing-color-component), instead of whatever value was produced by the
conversion process.

When performing color space conversion to a [cylindrical polar
color](#cylindrical-polar-color) space, user agents *shall* treat a hue component as
[powerless](#powerless-color-component) if the chroma (or other measure of colorfulness, such
as saturation in [hsl](#valdef-hsl-hsl)) is less than or equal to the epsilon (ε) specified
for that color space. For example, a gray color converted into
[oklch()](#funcdef-oklch) may, due to numerical errors, have an *extremely
small* chroma rather than precisely [0%]; as a result, the hue
component is [powerless].

When changing a powerless hue component to a [missing
component](#missing-color-component), the chroma (or other measure of colorfulness, such as
saturation in [hsl](#valdef-hsl-hsl); see [analogous
components](#analogous-components)) is set to zero to avoid amplifying floating-point
noise. Negative values are not clamped to zero, this value is only set
to zero when it is larger than zero but smaller or equal to ε. For
[hwb](#valdef-hwb-hwb)
follow these steps instead:

``` highlight
1. if W + B is greater than or equal to ε and W + B is less than 100
 1.1. if W and B are not missing
 1.1.1. set B to 100 - W
 1.2. else if W is not missing
 1.2.1. set W to 100
 1.3. else if B is not missing
 1.3.1. set B to 100
```

### 4.5. Parsing a [\<color\> Value]
Tests

This section provides a definition referenced elsewhere, it does not
need tests.

------------------------------------------------------------------------

To [parse a CSS [\<color\>](#typedef-color) value], given a
[string](https://infra.spec.whatwg.org/#string) `input`, and an optional context
[element](https://dom.spec.whatwg.org/#concept-element) `element`:

1. [Parse](https://drafts.csswg.org/css-syntax-3/#css-parse-something-according-to-a-css-grammar) `input` as a
 [\<color\>](#typedef-color). If the result is failure, return
 failure; otherwise, let `color` be the result.

2. Let `used color` be the result of
 [resolving](#resolving-color-values) `color` to a [used
 color](#used-color). If the
 value of other properties on the element a
 [\<color\>](#typedef-color) is on is required to do the resolution
 (such as resolving a
 [currentcolor](#valdef-color-currentcolor) or [system
 color](#css-system-colors)), use `element` if it was passed, or the
 [initial
 values](https://drafts.csswg.org/css-cascade-5/#initial-value) of the properties if not.

3. Return `used color`.

 This algorithm is not intented to parse a CSS
[\<color\>](#typedef-color) value specified in a CSS stylesheet or with a CSSOM
interface, but in other places like HTML attributes or Canvas
interfaces.

## 5. sRGB Colors

CSS colors in the [sRGB](#sRGB-space) color space are represented by a triplet of
values---​red, green, and blue---​identifying a point in the sRGB color
space
[\[SRGB\]](#biblio-srgb "Multimedia systems and equipment - Colour measurement and management - Part 2-1: Colour management - Default RGB colour space - sRGB").
This is an internationally-recognized, device-independent color space,
and so is useful for specifying colors that will be displayed on a
computer screen, but is also useful for specifying colors on other types
of devices, like printers.

CSS also allows the use of non-sRGB [color
space](#color-space)s, as
described in [§ 10 Predefined Color Spaces](#predefined).

CSS provides several methods of directly specifying an sRGB color: [hex
colors](#hex-color),
[rgb()](#funcdef-rgb)/[rgba()](#funcdef-rgba) [color
functions](#color-functions),
[hsl()](#funcdef-hsl)/[hsla()](#funcdef-hsla) [color functions],
[hwb()](#funcdef-hwb)
[color function], [named
colors](#named-color), and the
[transparent](#valdef-color-transparent) keyword.

### 5.1. The RGB functions: [rgb() and [rgba()](#funcdef-rgba)]
The [rgb()](#funcdef-rgb)
and [rgba()](#funcdef-rgba) functions define an sRGB color by specifying the r, g
and b (red, green, and blue) components directly. Their syntax is:

```
rgb() = [ <legacy-rgb-syntax> | <modern-rgb-syntax> ]
rgba() = [ <legacy-rgba-syntax> | <modern-rgba-syntax> ]
<legacy-rgb-syntax> = rgb( <percentage>#{3} , <alpha-value>? ) |
 rgb( <number>#{3} , <alpha-value>? )
<legacy-rgba-syntax> = rgba( <percentage>#{3} , <alpha-value>? ) |
 rgba( <number>#{3} , <alpha-value>? )
<modern-rgb-syntax> = rgb(
 [ <number> | <percentage> | none]{3}
 [ / [<alpha-value> | none] ]? )
<modern-rgba-syntax> = rgba(
 [ <number> | <percentage> | none]{3}
 [ / [<alpha-value> | none] ]? )
```

Percentages

Allowed for r, g and b

Percent reference range 

For r, g and b: 0% = 0.0, 100% = 255.0 For alpha: 0% = 0.0, 100% = 1.0

Tests

- [rgb-001.html](https://wpt.fyi/results/css/css-color/rgb-001.html "css/css-color/rgb-001.html")
 [[(live
 test)]](http://wpt.live/css/css-color/rgb-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/rgb-001.html)
- [rgb-002.html](https://wpt.fyi/results/css/css-color/rgb-002.html "css/css-color/rgb-002.html")
 [[(live
 test)]](http://wpt.live/css/css-color/rgb-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/rgb-002.html)
- [rgb-003.html](https://wpt.fyi/results/css/css-color/rgb-003.html "css/css-color/rgb-003.html")
 [[(live
 test)]](http://wpt.live/css/css-color/rgb-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/rgb-003.html)
- [rgb-004.html](https://wpt.fyi/results/css/css-color/rgb-004.html "css/css-color/rgb-004.html")
 [[(live
 test)]](http://wpt.live/css/css-color/rgb-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/rgb-004.html)
- [rgb-005.html](https://wpt.fyi/results/css/css-color/rgb-005.html "css/css-color/rgb-005.html")
 [[(live
 test)]](http://wpt.live/css/css-color/rgb-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/rgb-005.html)
- [rgb-006.html](https://wpt.fyi/results/css/css-color/rgb-006.html "css/css-color/rgb-006.html")
 [[(live
 test)]](http://wpt.live/css/css-color/rgb-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/rgb-006.html)
- [rgb-007.html](https://wpt.fyi/results/css/css-color/rgb-007.html "css/css-color/rgb-007.html")
 [[(live
 test)]](http://wpt.live/css/css-color/rgb-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/rgb-007.html)
- [rgb-008.html](https://wpt.fyi/results/css/css-color/rgb-008.html "css/css-color/rgb-008.html")
 [[(live
 test)]](http://wpt.live/css/css-color/rgb-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/rgb-008.html)
- [out-of-gamut-legacy-rgb.html](https://wpt.fyi/results/css/css-color/out-of-gamut-legacy-rgb.html "css/css-color/out-of-gamut-legacy-rgb.html")
 [[(live
 test)]](http://wpt.live/css/css-color/out-of-gamut-legacy-rgb.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/out-of-gamut-legacy-rgb.html)
- [color-valid.html](https://wpt.fyi/results/css/css-color/parsing/color-valid.html "css/css-color/parsing/color-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-color/parsing/color-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/parsing/color-valid.html)
- [color-computed-rgb.html](https://wpt.fyi/results/css/css-color/parsing/color-computed-rgb.html "css/css-color/parsing/color-computed-rgb.html")
 [[(live
 test)]](http://wpt.live/css/css-color/parsing/color-computed-rgb.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/parsing/color-computed-rgb.html)
- [color-invalid-rgb.html](https://wpt.fyi/results/css/css-color/parsing/color-invalid-rgb.html "css/css-color/parsing/color-invalid-rgb.html")
 [[(live
 test)]](http://wpt.live/css/css-color/parsing/color-invalid-rgb.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/parsing/color-invalid-rgb.html)
- [color-valid-rgb.html](https://wpt.fyi/results/css/css-color/parsing/color-valid-rgb.html "css/css-color/parsing/color-valid-rgb.html")
 [[(live
 test)]](http://wpt.live/css/css-color/parsing/color-valid-rgb.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/parsing/color-valid-rgb.html)

The first three arguments specify the r, g and b (red, green, and blue)
components of the color, respectively. [0%] represents the minimum
value for that color component in the sRGB gamut, and [100%]
represents the maximum value.

The percentage reference range of the color components comes from the
historical fact that many graphics engines stored the color components
internally as a single byte, which can hold integers between 0 and 255.
Implementations should honor the precision of the component as authored
or calculated wherever possible. If this is not possible, the component
should be [rounded towards
+∞](https://drafts.csswg.org/css-values-4/#combine-integers).

The final argument, the
[\<alpha-value\>](#typedef-color-alpha-value), specifies the alpha of the color. If
omitted, it defaults to [100%].

Tests

- [background-color-rgb-001.html](https://wpt.fyi/results/css/css-color/background-color-rgb-001.html "css/css-color/background-color-rgb-001.html")
 [[(live
 test)]](http://wpt.live/css/css-color/background-color-rgb-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/background-color-rgb-001.html)
- [background-color-rgb-002.html](https://wpt.fyi/results/css/css-color/background-color-rgb-002.html "css/css-color/background-color-rgb-002.html")
 [[(live
 test)]](http://wpt.live/css/css-color/background-color-rgb-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/background-color-rgb-002.html)
- [background-color-rgb-003.html](https://wpt.fyi/results/css/css-color/background-color-rgb-003.html "css/css-color/background-color-rgb-003.html")
 [[(live
 test)]](http://wpt.live/css/css-color/background-color-rgb-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/background-color-rgb-003.html)
- [color-valid.html](https://wpt.fyi/results/css/css-color/parsing/color-valid.html "css/css-color/parsing/color-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-color/parsing/color-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/parsing/color-valid.html)

Values outside these ranges are not invalid, but are clamped to the
ranges defined here at parsed-value time.

For historical reasons, [rgb()](#funcdef-rgb) and [rgba()](#funcdef-rgba) also support a [legacy color
syntax](#legacy-color-syntax).

Tests

- [rgba-001.html](https://wpt.fyi/results/css/css-color/rgba-001.html "css/css-color/rgba-001.html")
 [[(live
 test)]](http://wpt.live/css/css-color/rgba-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/rgba-001.html)
- [rgba-002.html](https://wpt.fyi/results/css/css-color/rgba-002.html "css/css-color/rgba-002.html")
 [[(live
 test)]](http://wpt.live/css/css-color/rgba-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/rgba-002.html)
- [rgba-003.html](https://wpt.fyi/results/css/css-color/rgba-003.html "css/css-color/rgba-003.html")
 [[(live
 test)]](http://wpt.live/css/css-color/rgba-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/rgba-003.html)
- [rgba-004.html](https://wpt.fyi/results/css/css-color/rgba-004.html "css/css-color/rgba-004.html")
 [[(live
 test)]](http://wpt.live/css/css-color/rgba-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/rgba-004.html)
- [rgba-005.html](https://wpt.fyi/results/css/css-color/rgba-005.html "css/css-color/rgba-005.html")
 [[(live
 test)]](http://wpt.live/css/css-color/rgba-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/rgba-005.html)
- [rgba-006.html](https://wpt.fyi/results/css/css-color/rgba-006.html "css/css-color/rgba-006.html")
 [[(live
 test)]](http://wpt.live/css/css-color/rgba-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/rgba-006.html)
- [rgba-007.html](https://wpt.fyi/results/css/css-color/rgba-007.html "css/css-color/rgba-007.html")
 [[(live
 test)]](http://wpt.live/css/css-color/rgba-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/rgba-007.html)
- [rgba-008.html](https://wpt.fyi/results/css/css-color/rgba-008.html "css/css-color/rgba-008.html")
 [[(live
 test)]](http://wpt.live/css/css-color/rgba-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/rgba-008.html)
- [color-valid.html](https://wpt.fyi/results/css/css-color/parsing/color-valid.html "css/css-color/parsing/color-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-color/parsing/color-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/parsing/color-valid.html)

### [5.2. ][ The RGB Hexadecimal Notations: [#RRGGBB]]
The CSS [hex color notation] allows an sRGB color to
be specified by giving the components as hexadecimal numbers, which is
similar to how colors are often written directly in computer code. It's
also shorter than writing the same color out in
[rgb()](#funcdef-rgb)
notation.

The syntax of a [\<hex-color\>] is a
[\<hash-token\>](https://drafts.csswg.org/css-syntax-3/#typedef-hash-token) token whose value consists of 3, 4,
6, or 8 hexadecimal digits. In other words, a hex color is written as a
hash character, \"#\", followed by some number of digits 0-9 or letters
a-f (the case of the letters doesn't matter - [#00ff00] is
identical to [#00FF00]).

The number of hex digits given determines how to decode the hex notation
into an RGB color:

6 digits
: The first pair of digits, interpreted as a hexadecimal number,
 specifies the red component of the color, where [00]
 represents the minimum value and [ff] (255 in decimal)
 represents the maximum. The next pair of digits, interpreted in the
 same way, specifies the green component, and the last pair specifies
 the blue. The alpha component of the color is fully opaque.
 :::
 (#ex-hex6) In other words, [#00ff00] represents the same color
 as [rgb(0 255 0)] (a lime
 green).
 :::

8 digits
: The first 6 digits are interpreted identically to the 6-digit
 notation. The last pair of digits, interpreted as a hexadecimal
 number, specifies the alpha component of the color, where [00]
 represents a fully transparent color and [ff] represent a
 fully opaque color.
 :::
 (#ex-hex8) In other words, [#0000ffcc] represents the same
 color as [rgb(0 0 100% /
 80%)] (a slightly-transparent blue).
 :::

3 digits
: This is a shorter variant of the 6-digit notation. The first digit,
 interpreted as a hexadecimal number, specifies the red component of
 the color, where [0] represents the minimum value and
 [f] represents the maximum. The next two digits represent the
 green and blue components, respectively, in the same way. The alpha
 component of the color is fully opaque.
 :::
 (#ex-hex3) This syntax is often explained by saying
 that it's identical to a 6-digit notation obtained by
 \"duplicating\" all of the digits. For example, the notation
 [#123] specifies the same
 color as the notation
 [#112233]. This method of specifying a color has lower
 \"resolution\" than the 6-digit notation; there are only 4096
 possible colors expressible in the 3-digit hex syntax, as opposed to
 approximately 17 million in 6-digit hex syntax.
 :::

4 digits
: This is a shorter variant of the 8-digit notation, \"expanded\" in
 the same way as the 3-digit notation is. The first digit,
 interpreted as a hexadecimal number, specifies the red component of
 the color, where [0] represents the minimum value and
 [f] represents the maximum. The next three digits represent
 the green, blue, and alpha components, respectively.

Tests

- [hex-001.html](https://wpt.fyi/results/css/css-color/hex-001.html "css/css-color/hex-001.html")
 [[(live
 test)]](http://wpt.live/css/css-color/hex-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/hex-001.html)
- [hex-002.html](https://wpt.fyi/results/css/css-color/hex-002.html "css/css-color/hex-002.html")
 [[(live
 test)]](http://wpt.live/css/css-color/hex-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/hex-002.html)
- [hex-003.html](https://wpt.fyi/results/css/css-color/hex-003.html "css/css-color/hex-003.html")
 [[(live
 test)]](http://wpt.live/css/css-color/hex-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/hex-003.html)
- [hex-004.html](https://wpt.fyi/results/css/css-color/hex-004.html "css/css-color/hex-004.html")
 [[(live
 test)]](http://wpt.live/css/css-color/hex-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/hex-004.html)
- [border-bottom-color.xht](https://wpt.fyi/results/css/css-color/border-bottom-color.xht "css/css-color/border-bottom-color.xht")
 [[(live
 test)]](http://wpt.live/css/css-color/border-bottom-color.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/border-bottom-color.xht)
- [border-left-color.xht](https://wpt.fyi/results/css/css-color/border-left-color.xht "css/css-color/border-left-color.xht")
 [[(live
 test)]](http://wpt.live/css/css-color/border-left-color.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/border-left-color.xht)
- [border-right-color.xht](https://wpt.fyi/results/css/css-color/border-right-color.xht "css/css-color/border-right-color.xht")
 [[(live
 test)]](http://wpt.live/css/css-color/border-right-color.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/border-right-color.xht)
- [border-top-color.xht](https://wpt.fyi/results/css/css-color/border-top-color.xht "css/css-color/border-top-color.xht")
 [[(live
 test)]](http://wpt.live/css/css-color/border-top-color.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/border-top-color.xht)
- [color-valid.html](https://wpt.fyi/results/css/css-color/parsing/color-valid.html "css/css-color/parsing/color-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-color/parsing/color-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/parsing/color-valid.html)
- [color-computed-hex-color.html](https://wpt.fyi/results/css/css-color/parsing/color-computed-hex-color.html "css/css-color/parsing/color-computed-hex-color.html")
 [[(live
 test)]](http://wpt.live/css/css-color/parsing/color-computed-hex-color.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/parsing/color-computed-hex-color.html)
- [color-invalid-hex-color.html](https://wpt.fyi/results/css/css-color/parsing/color-invalid-hex-color.html "css/css-color/parsing/color-invalid-hex-color.html")
 [[(live
 test)]](http://wpt.live/css/css-color/parsing/color-invalid-hex-color.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/parsing/color-invalid-hex-color.html)

## 6. Color Keywords

In addition to the various numeric syntaxes for
[\<color\>](#typedef-color)s, CSS defines several sets of color keywords that can
be used instead---​each with their own advantages or use cases.

### 6.1. Named Colors

CSS defines a large set of [named colors], so that common colors can be
written and read more easily. A [\<named-color\>] is written as an
[\<ident\>](https://drafts.csswg.org/css-values-4/#typedef-ident), accepted anywhere a
[\<color\>](#typedef-color) is. As usual for CSS-defined
[\<ident\>]s, all of these keywords
are [ASCII
case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive).

The names resolve to colors in sRGB.

16 of CSS's named colors come from the VGA palette originally, and were
then adopted into HTML: aqua, black, blue, fuchsia, gray, green, lime,
maroon, navy, olive, purple, red, silver, teal, white, and yellow. Most
of the rest come from one version of the X11 color system, used in
Unix-derived systems to specify colors for the console, and were then
adopted into SVG.

 these color names are standardized here, *not because
they are good*, but because their use and implementation has been
widespread for decades and the standard needs to reflect reality.
Indeed, it is often hard to imagine what each name will look like (hence
the list below); the names are not evenly distributed throughout the
sRGB color volume, the names are not even internally consistent
(
[darkgray](#valdef-color-darkgray) is lighter than
[gray](#valdef-color-gray), while
[lightpink](#valdef-color-lightpink) is darker than
[pink](#valdef-color-pink)), and some names (such as
[indianred](#valdef-color-indianred), which was originally named after a red pigment
from India), have been found to be offensive. Thus, their use is *not
encouraged*.

(Two special color values,
[transparent](#valdef-color-transparent) and
[currentcolor](#valdef-color-currentcolor), are specially defined in their own sections.)

The following table defines all of the opaque named colors, by giving
equivalent numeric specifications in the other color syntaxes.

Named

Numeric

Color name

Hex rgb

Decimal

[aliceblue]

#f0f8ff

240 248 255

[antiquewhite]

#faebd7

250 235 215

[aqua]

#00ffff

0 255 255

[aquamarine]

#7fffd4

127 255 212

[azure]

#f0ffff

240 255 255

[beige]

#f5f5dc

245 245 220

[bisque]

#ffe4c4

255 228 196

[black]

#000000

0 0 0

[blanchedalmond]

#ffebcd

255 235 205

[blue]

#0000ff

0 0 255

[blueviolet]

#8a2be2

138 43 226

[brown]

#a52a2a

165 42 42

[burlywood]

#deb887

222 184 135

[cadetblue]

#5f9ea0

95 158 160

[chartreuse]

#7fff00

127 255 0

[chocolate]

#d2691e

210 105 30

[coral]

#ff7f50

255 127 80

[cornflowerblue]

#6495ed

100 149 237

[cornsilk]

#fff8dc

255 248 220

[crimson]

#dc143c

220 20 60

[cyan]

#00ffff

0 255 255

[darkblue]

#00008b

0 0 139

[darkcyan]

#008b8b

0 139 139

[darkgoldenrod]

#b8860b

184 134 11

[darkgray]

#a9a9a9

169 169 169

[darkgreen]

#006400

0 100 0

[darkgrey]

#a9a9a9

169 169 169

[darkkhaki]

#bdb76b

189 183 107

[darkmagenta]

#8b008b

139 0 139

[darkolivegreen]

#556b2f

85 107 47

[darkorange]

#ff8c00

255 140 0

[darkorchid]

#9932cc

153 50 204

[darkred]

#8b0000

139 0 0

[darksalmon]

#e9967a

233 150 122

[darkseagreen]

#8fbc8f

143 188 143

[darkslateblue]

#483d8b

72 61 139

[darkslategray]

#2f4f4f

47 79 79

[darkslategrey]

#2f4f4f

47 79 79

[darkturquoise]

#00ced1

0 206 209

[darkviolet]

#9400d3

148 0 211

[deeppink]

#ff1493

255 20 147

[deepskyblue]

#00bfff

0 191 255

[dimgray]

#696969

105 105 105

[dimgrey]

#696969

105 105 105

[dodgerblue]

#1e90ff

30 144 255

[firebrick]

#b22222

178 34 34

[floralwhite]

#fffaf0

255 250 240

[forestgreen]

#228b22

34 139 34

[fuchsia]

#ff00ff

255 0 255

[gainsboro]

#dcdcdc

220 220 220

[ghostwhite]

#f8f8ff

248 248 255

[gold]

#ffd700

255 215 0

[goldenrod]

#daa520

218 165 32

[gray]

#808080

128 128 128

[green]

#008000

0 128 0

[greenyellow]

#adff2f

173 255 47

[grey]

#808080

128 128 128

[honeydew]

#f0fff0

240 255 240

[hotpink]

#ff69b4

255 105 180

[indianred]

#cd5c5c

205 92 92

[indigo]

#4b0082

75 0 130

[ivory]

#fffff0

255 255 240

[khaki]

#f0e68c

240 230 140

[lavender]

#e6e6fa

230 230 250

[lavenderblush]

#fff0f5

255 240 245

[lawngreen]

#7cfc00

124 252 0

[lemonchiffon]

#fffacd

255 250 205

[lightblue]

#add8e6

173 216 230

[lightcoral]

#f08080

240 128 128

[lightcyan]

#e0ffff

224 255 255

[lightgoldenrodyellow]

#fafad2

250 250 210

[lightgray]

#d3d3d3

211 211 211

[lightgreen]

#90ee90

144 238 144

[lightgrey]

#d3d3d3

211 211 211

[lightpink]

#ffb6c1

255 182 193

[lightsalmon]

#ffa07a

255 160 122

[lightseagreen]

#20b2aa

32 178 170

[lightskyblue]

#87cefa

135 206 250

[lightslategray]

#778899

119 136 153

[lightslategrey]

#778899

119 136 153

[lightsteelblue]

#b0c4de

176 196 222

[lightyellow]

#ffffe0

255 255 224

[lime]

#00ff00

0 255 0

[limegreen]

#32cd32

50 205 50

[linen]

#faf0e6

250 240 230

[magenta]

#ff00ff

255 0 255

[maroon]

#800000

128 0 0

[mediumaquamarine]

#66cdaa

102 205 170

[mediumblue]

#0000cd

0 0 205

[mediumorchid]

#ba55d3

186 85 211

[mediumpurple]

#9370db

147 112 219

[mediumseagreen]

#3cb371

60 179 113

[mediumslateblue]

#7b68ee

123 104 238

[mediumspringgreen]

#00fa9a

0 250 154

[mediumturquoise]

#48d1cc

72 209 204

[mediumvioletred]

#c71585

199 21 133

[midnightblue]

#191970

25 25 112

[mintcream]

#f5fffa

245 255 250

[mistyrose]

#ffe4e1

255 228 225

[moccasin]

#ffe4b5

255 228 181

[navajowhite]

#ffdead

255 222 173

[navy]

#000080

0 0 128

[oldlace]

#fdf5e6

253 245 230

[olive]

#808000

128 128 0

[olivedrab]

#6b8e23

107 142 35

[orange]

#ffa500

255 165 0

[orangered]

#ff4500

255 69 0

[orchid]

#da70d6

218 112 214

[palegoldenrod]

#eee8aa

238 232 170

[palegreen]

#98fb98

152 251 152

[paleturquoise]

#afeeee

175 238 238

[palevioletred]

#db7093

219 112 147

[papayawhip]

#ffefd5

255 239 213

[peachpuff]

#ffdab9

255 218 185

[peru]

#cd853f

205 133 63

[pink]

#ffc0cb

255 192 203

[plum]

#dda0dd

221 160 221

[powderblue]

#b0e0e6

176 224 230

[purple]

#800080

128 0 128

[rebeccapurple]

#663399

102 51 153

[red]

#ff0000

255 0 0

[rosybrown]

#bc8f8f

188 143 143

[royalblue]

#4169e1

65 105 225

[saddlebrown]

#8b4513

139 69 19

[salmon]

#fa8072

250 128 114

[sandybrown]

#f4a460

244 164 96

[seagreen]

#2e8b57

46 139 87

[seashell]

#fff5ee

255 245 238

[sienna]

#a0522d

160 82 45

[silver]

#c0c0c0

192 192 192

[skyblue]

#87ceeb

135 206 235

[slateblue]

#6a5acd

106 90 205

[slategray]

#708090

112 128 144

[slategrey]

#708090

112 128 144

[snow]

#fffafa

255 250 250

[springgreen]

#00ff7f

0 255 127

[steelblue]

#4682b4

70 130 180

[tan]

#d2b48c

210 180 140

[teal]

#008080

0 128 128

[thistle]

#d8bfd8

216 191 216

[tomato]

#ff6347

255 99 71

[turquoise]

#40e0d0

64 224 208

[violet]

#ee82ee

238 130 238

[wheat]

#f5deb3

245 222 179

[white]

#ffffff

255 255 255

[whitesmoke]

#f5f5f5

245 245 245

[yellow]

#ffff00

255 255 0

[yellowgreen]

#9acd32

154 205 50

 this list of colors and their definitions is a superset
of the list of [named colors defined by SVG
1.1](https://www.w3.org/TR/SVG11/types.html#ColorKeywords).

For historical reasons, this is also referred to as the X11 color set.

 The history of the X11 color system is interesting, and
was excellently summarized by [Alex Sexton in their talk "Peachpuffs and
Lemonchiffons"](https://www.youtube.com/watch?v=HmStJQzclHc).

Tests

- [named-001.html](https://wpt.fyi/results/css/css-color/named-001.html "css/css-color/named-001.html")
 [[(live
 test)]](http://wpt.live/css/css-color/named-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/named-001.html)
- [color-valid.html](https://wpt.fyi/results/css/css-color/parsing/color-valid.html "css/css-color/parsing/color-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-color/parsing/color-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/parsing/color-valid.html)
- [color-computed-named-color.html](https://wpt.fyi/results/css/css-color/parsing/color-computed-named-color.html "css/css-color/parsing/color-computed-named-color.html")
 [[(live
 test)]](http://wpt.live/css/css-color/parsing/color-computed-named-color.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/parsing/color-computed-named-color.html)
- [color-invalid-named-color.html](https://wpt.fyi/results/css/css-color/parsing/color-invalid-named-color.html "css/css-color/parsing/color-invalid-named-color.html")
 [[(live
 test)]](http://wpt.live/css/css-color/parsing/color-invalid-named-color.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/parsing/color-invalid-named-color.html)

### 6.2. System Colors

In general, the
[\<system-color\>](#typedef-system-color) keywords reflect *default* color
choices made by the user, the browser, or the OS. They are typically
used in the browser default stylesheet, for this reason.

To maintain legibility, the
[\<system-color\>](#typedef-system-color) keywords also respond to the [element
color
scheme](https://drafts.csswg.org/css-color-adjust-1/#element-color-scheme).

For example, traditional blue link text is legible on a white background (WCAG contrast 8.59:1, AAA pass)
but would not be legible on a black
background (WCAG contrast 2.44:1, AA fail). Instead, a lighter blue such
as #81D9FE would be used in dark
mode (WCAG contrast 13.28:1, AAA pass).

::: {style="margin:1em; margin-left: 2em; text-decoration: underline; background: inherit"}
Legible link text

Illegible link text

Legible link text

However, in [forced colors
mode](https://drafts.csswg.org/css-color-adjust-1/#forced-colors-mode), most colors on the page are forced into a restricted,
user-chosen palette, see [CSS Color Adjustment 1 § 5.2 Forced Colors
Mode Color
Palettes](https://drafts.csswg.org/css-color-adjust-1/#forced-color-palettes).
The [\<system-color\>] keywords expose these user-chosen colors so
that the rest of the page can integrate with this restricted palette.

When the
[forced-colors](https://drafts.csswg.org/mediaqueries-5/#descdef-media-forced-colors)
[media
feature](https://drafts.csswg.org/mediaqueries-5/#media-feature) is [active], authors *should* use the
[\<system-color\>](#typedef-system-color) keywords as color values in
properties other than those listed in [CSS Color Adjustment 1 § 3.1
Properties Affected by Forced Colors
Mode](https://drafts.csswg.org/css-color-adjust-1/#forced-colors-properties),
to ensure legibility and consistency across the page and avoid an
uncoordinated mishmash of user-forced and page-chosen colors.

Tests

- [system-color-consistency.html](https://wpt.fyi/results/css/css-color/system-color-consistency.html "css/css-color/system-color-consistency.html")
 [[(live
 test)]](http://wpt.live/css/css-color/system-color-consistency.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/system-color-consistency.html)
- [system-color-support.html](https://wpt.fyi/results/css/css-color/system-color-support.html "css/css-color/system-color-support.html")
 [[(live
 test)]](http://wpt.live/css/css-color/system-color-support.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/system-color-support.html)
- [color-valid-system-color.html](https://wpt.fyi/results/css/css-color/parsing/color-valid-system-color.html "css/css-color/parsing/color-valid-system-color.html")
 [[(live
 test)]](http://wpt.live/css/css-color/parsing/color-valid-system-color.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/parsing/color-valid-system-color.html)

When the values of
[\<system-color\>](#typedef-system-color) keywords come from the browser, (as
opposed to being OS defaults or user choices) the browser should ensure
that [matching foreground/background pairs](#system-color-pairs) have a
minimum of WCAG AA contrast. However, user preferences (for higher or
lower contrast), whether set as a browser preference, a user stylesheet,
or by altering the OS defaults, must take precedence over this
requirement.

Authors *may* also use these keywords at any time, but *should* be
careful to use the colors in [matching background-foreground
pairs](#system-color-pairs) to ensure appropriate contrast, as any
particular contrast relationship across non-matching pairs (e.g.
[Canvas](#valdef-color-canvas) and
[ButtonText](#valdef-color-buttontext)) is not guaranteed.

The
[\<system-color\>](#typedef-system-color) keywords are defined as follows:

[AccentColor]
:  Background of accented user
 interface controls.

[AccentColorText]
:  Text of accented user
 interface controls.

[ActiveText]
:  Text in active links. For
 light backgrounds, traditionally red.

[ButtonBorder]
:  The base border color for
 push buttons.

[ButtonFace]
:  The face background color
 for push buttons.

[ButtonText]
:  Text on push buttons.

[Canvas]
:  Background of application
 content or documents.

[CanvasText]
:  Text in application content
 or documents.

[Field]
:  Background of input fields.

[FieldText]
:  Text in input fields.

[GrayText]
:  Disabled text. (Often, but not
 necessarily, gray.)

[Highlight]
:  Background of selected text,
 for example from ::selection.

[HighlightText]
:  Text of selected text.

[LinkText]
:  Text in non-active,
 non-visited links. For light backgrounds, traditionally blue.

[Mark]
:  Background of text that has been
 specially marked (such as by the HTML
 [`mark`](https://html.spec.whatwg.org/multipage/text-level-semantics.html#the-mark-element) element).

[MarkText]
:  Text that has been specially
 marked (such as by the HTML
 [`mark`](https://html.spec.whatwg.org/multipage/text-level-semantics.html#the-mark-element) element).

[SelectedItem]
:  Background of selected
 items, for example a selected checkbox.

[SelectedItemText]
:  Text of selected
 items.

[VisitedText]
:  Text in visited links. For
 light backgrounds, traditionally purple.

Tests

- [color-valid.html](https://wpt.fyi/results/css/css-color/parsing/color-valid.html "css/css-color/parsing/color-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-color/parsing/color-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/parsing/color-valid.html)
- [relative-currentcolor-visited-getcomputedstyle.html](https://wpt.fyi/results/css/css-color/relative-currentcolor-visited-getcomputedstyle.html "css/css-color/relative-currentcolor-visited-getcomputedstyle.html")
 [[(live
 test)]](http://wpt.live/css/css-color/relative-currentcolor-visited-getcomputedstyle.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/relative-currentcolor-visited-getcomputedstyle.html)
- [system-color-compute.html](https://wpt.fyi/results/css/css-color/system-color-compute.html "css/css-color/system-color-compute.html")
 [[(live
 test)]](http://wpt.live/css/css-color/system-color-compute.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/system-color-compute.html)
- [system-color-hightlights-vs-getSelection-001.html](https://wpt.fyi/results/css/css-color/system-color-hightlights-vs-getSelection-001.html "css/css-color/system-color-hightlights-vs-getSelection-001.html")
 [[(live
 test)]](http://wpt.live/css/css-color/system-color-hightlights-vs-getSelection-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/system-color-hightlights-vs-getSelection-001.html)
- [system-color-hightlights-vs-getSelection-002.html](https://wpt.fyi/results/css/css-color/system-color-hightlights-vs-getSelection-002.html "css/css-color/system-color-hightlights-vs-getSelection-002.html")
 [[(live
 test)]](http://wpt.live/css/css-color/system-color-hightlights-vs-getSelection-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/system-color-hightlights-vs-getSelection-002.html)

 As with all other
[keywords](https://drafts.csswg.org/css-values-4/#css-keyword), these names are [ASCII
case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive).
They are shown here with mixed capitalization for legibility.

For systems that do not have a particular system UI concept, the
specified value should be mapped to the most closely related system
color value that exists. The following [system color
pairings] are expected to form legible background-foreground colors:

- [Canvas](#valdef-color-canvas) background with
 [CanvasText](#valdef-color-canvastext),
 [LinkText](#valdef-color-linktext),
 [VisitedText](#valdef-color-visitedtext),
 [ActiveText](#valdef-color-activetext) foreground.

- [Canvas](#valdef-color-canvas) background with a
 [ButtonBorder](#valdef-color-buttonborder) border and adjacent color
 [Canvas]

- [ButtonFace](#valdef-color-buttonface) background with
 [ButtonText](#valdef-color-buttontext) foreground.

- [Field](#valdef-color-field) background with
 [FieldText](#valdef-color-fieldtext) foreground.

- [Mark](#valdef-color-mark) background with
 [MarkText](#valdef-color-marktext) foreground

- [ButtonFace](#valdef-color-buttonface) or
 [Field](#valdef-color-field) background with a
 [ButtonBorder](#valdef-color-buttonborder) border and adjacent color
 [Canvas](#valdef-color-canvas)\'

- [Highlight](#valdef-color-highlight) background with
 [HighlightText](#valdef-color-highlighttext) foreground.

- [SelectedItem](#valdef-color-selecteditem) background with
 [SelectedItemText](#valdef-color-selecteditemtext) foreground.

- [AccentColor](#valdef-color-accentcolor) background with
 [AccentColorText](#valdef-color-accentcolortext) foreground.

Additionally,
[GrayText](#valdef-color-graytext) is expected to be readable, though possibly at a
lower contrast rating, over any of the backgrounds.

To maintain consistency with widget [accent
color](https://drafts.csswg.org/css-ui-4/#accent-color) styling,
[AccentColor](#valdef-color-accentcolor) takes its value from
[accent-color](https://drafts.csswg.org/css-ui-4/#propdef-accent-color), unless [Forced Colors
Mode](https://drafts.csswg.org/css-color-adjust-1/#forced-colors-mode) is enabled.
[AccentColorText](#valdef-color-accentcolortext) takes its value from the contrasting foreground
color to [AccentColor] as is
described for widget [accent color] styling.

For example, the system color
combinations in the browser you are currently using:

Canvas with CanvasText:
[CanvasText]{style="background-color:Canvas; color:CanvasText"}

Canvas with LinkText:
[LinkText]{style="background-color:Canvas; color:LinkText"}

Canvas with VisitedText:
[VisitedText]{style="background-color:Canvas; color:VisitedText"}

Canvas with ActiveText:
[ActiveText]{style="background-color:Canvas; color:ActiveText"}

Canvas with GrayText:
[GrayText]{style="background-color:Canvas; color:GrayText"}

Canvas with ButtonBorder and adjacent Canvas:
[CanvasText]{style="background-color:Canvas; border: ButtonBorder; color:CanvasText; padding: 3px"}[Adjacent]{style="background-color:Canvas; color:CanvasText"}

ButtonFace with ButtonText:
[ButtonText]{style="background-color:ButtonFace; color:ButtonText"}

ButtonFace with ButtonText and ButtonBorder:
[ButtonText]{style="background-color:ButtonFace; color:ButtonText; border:ButtonBorder; padding: 3px"}

ButtonFace with GrayText:
[GrayText]{style="background-color:ButtonFace; color:GrayText"}

Field with FieldText:
[FieldText]{style="background-color:Field; color:FieldText"}

Field with GrayText:
[GrayText]{style="background-color:Field; color:GrayText"}

Mark with MarkText:
[MarkText]{style="background-color:Mark; color:MarkText"}

Mark with GrayText:
[GrayText]{style="background-color:Mark; color:GrayText"}

Highlight with HighlightText:
[HighlightText]{style="background-color:Highlight; color:HighlightText"}

Highlight with GrayText:
[GrayText]{style="background-color:Highlight; color:GrayText"}

SelectedItem with SelectedItemText:
[SelectedItemText]{style="background-color:SelectedItem; color:SelectedItemText"}

AccentColor with AccentColorText:
[AccentColorText]{style="background-color:AccentColor; color:AccentColorText"}

AccentColor with GrayText:
[GrayText]{style="background-color:AccentColor; color:GrayText"}

Earlier versions of CSS defined additional
[\<system-color\>](#typedef-system-color)s, which have since been deprecated.
These are documented in [Appendix A: Deprecated CSS System
Colors](#deprecated-system-colors).

 The
[\<system-color\>](#typedef-system-color)s incur some privacy and security
risk, as detailed in [§ 22 Privacy Considerations](#privacy) and [§ 21
Security Considerations](#security).

User agents may, to mitigate privacy and security risks such as
fingerprinting, elect to return fixed values for the used value of
system colors which do not reflect customisation or theming choices made
by the user.

### 6.3. The [transparent keyword]
The keyword [transparent] specifies a
[transparent black](#transparent-black). It is a type of
[\<named-color\>](#typedef-named-color).

Tests

- [color-computed.html](https://wpt.fyi/results/css/css-color/parsing/color-computed.html "css/css-color/parsing/color-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-color/parsing/color-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/parsing/color-computed.html)
- [color-valid.html](https://wpt.fyi/results/css/css-color/parsing/color-valid.html "css/css-color/parsing/color-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-color/parsing/color-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/parsing/color-valid.html)
- [t423-transparent-1-a.xht](https://wpt.fyi/results/css/css-color/t423-transparent-1-a.xht "css/css-color/t423-transparent-1-a.xht")
 [[(live
 test)]](http://wpt.live/css/css-color/t423-transparent-1-a.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/t423-transparent-1-a.xht)
- [t423-transparent-2-a.xht](https://wpt.fyi/results/css/css-color/t423-transparent-2-a.xht "css/css-color/t423-transparent-2-a.xht")
 [[(live
 test)]](http://wpt.live/css/css-color/t423-transparent-2-a.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/t423-transparent-2-a.xht)

### 6.4. The [currentcolor keyword]
The keyword [currentcolor] represents
value of the [color](#propdef-color) property on the same element. Unlike
[\<named-color\>](#typedef-named-color)s, it is *not* restricted to sRGB; the
value can be any [\<color\>](#typedef-color). Its [used
values](https://drafts.csswg.org/css-cascade-5/#used-value) is determined by [resolving color
values](#resolving-other-colors).

Tests

- [border-color-currentcolor.html](https://wpt.fyi/results/css/css-color/border-color-currentcolor.html "css/css-color/border-color-currentcolor.html")
 [[(live
 test)]](http://wpt.live/css/css-color/border-color-currentcolor.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/border-color-currentcolor.html)
- [color-mix-currentcolor-nested-for-color-property.html](https://wpt.fyi/results/css/css-color/color-mix-currentcolor-nested-for-color-property.html "css/css-color/color-mix-currentcolor-nested-for-color-property.html")
 [[(live
 test)]](http://wpt.live/css/css-color/color-mix-currentcolor-nested-for-color-property.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/color-mix-currentcolor-nested-for-color-property.html)
- [currentcolor-001.html](https://wpt.fyi/results/css/css-color/currentcolor-001.html "css/css-color/currentcolor-001.html")
 [[(live
 test)]](http://wpt.live/css/css-color/currentcolor-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/currentcolor-001.html)
- [currentcolor-002.html](https://wpt.fyi/results/css/css-color/currentcolor-002.html "css/css-color/currentcolor-002.html")
 [[(live
 test)]](http://wpt.live/css/css-color/currentcolor-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/currentcolor-002.html)
- [currentcolor-003.html](https://wpt.fyi/results/css/css-color/currentcolor-003.html "css/css-color/currentcolor-003.html")
 [[(live
 test)]](http://wpt.live/css/css-color/currentcolor-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/currentcolor-003.html)
- [currentcolor-004.html](https://wpt.fyi/results/css/css-color/currentcolor-004.html "css/css-color/currentcolor-004.html")
 [[(live
 test)]](http://wpt.live/css/css-color/currentcolor-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/currentcolor-004.html)
- [currentcolor-visited-fallback.html](https://wpt.fyi/results/css/css-color/currentcolor-visited-fallback.html "css/css-color/currentcolor-visited-fallback.html")
 [[(live
 test)]](http://wpt.live/css/css-color/currentcolor-visited-fallback.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/currentcolor-visited-fallback.html)
- [color-valid.html](https://wpt.fyi/results/css/css-color/parsing/color-valid.html "css/css-color/parsing/color-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-color/parsing/color-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/parsing/color-valid.html)

Here's a simple example showing how to
use the
[currentcolor](#valdef-color-currentcolor) keyword:

```
.foo {
 color:  red;
 background-color:  currentcolor;
}
```

This is equivalent to writing:

```
.foo {
 color:  red;
 background-color:  red;
}
```

For example, the
[text-emphasis-color](https://drafts.csswg.org/css-text-decor-4/#propdef-text-emphasis-color) property
[\[CSS3-TEXT-DECOR\]](#biblio-css3-text-decor "CSS Text Decoration Module Level 3"),
whose initial value is
[currentcolor](#valdef-color-currentcolor), by default matches the text color even as the
[color](#propdef-color) property changes across elements.

```
<p><em>Some <strong>really</strong> emphasized text.</em>
<style>
p { color: black; }
em { text-emphasis: dot; }
strong { color: red; }
</style>
```

![rendered emphasized text with the word \'really\' in red with red
emphasis dots](images/text-emphasis.png){height="119" width="495"}

In the above example, the emphasis marks are black over the text
\"Some\" and \"emphasized text\", but red over the text \"really\".

Multi-word keywords in CSS
usually separate their component words with hyphens.
[currentcolor](#valdef-color-currentcolor) doesn't, because (deep breath) it was originally
introduced in SVG as a property value, \"current-color\" with the usual
CSS spelling. It (along with all other properties and their values) then
became presentation attributes and attribute values, as well as
properties, to make generation with XSLT easier. Then all of the
presentation attributes were changed from hyphenated to camelCase,
because the DOM had an issue with hyphen meaning \"minus\". But then,
they didn't follow CSS conventions anymore so all the properties and
property values that were *already* part of CSS were changed back to
hyphenated! [currentcolor] was
not a part of CSS at that time, so remained camelCased. Only later did
CSS pick it up, at which point the capitalization stopped mattering, as
CSS keywords are [ASCII
case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive).

## 7. HSL Colors: [hsl() and [hsla()](#funcdef-hsla) functions]
The RGB system for specifying colors, while convenient for machines and
graphic libraries, is often regarded as very difficult for humans to
gain an intuitive grasp on. It's not easy to tell, for example, how to
alter an RGB color to produce a lighter variant of the same hue.

There are several other color schemes possible. One such is the HSL
[\[HSL\]](#biblio-hsl "Color spaces for computer graphics")
color scheme, which is more intuitive to use, but still maps easily back
to RGB colors.

[HSL] colors are specified as a triplet of hue,
saturation, and lightness. The syntax of the
[hsl()](#funcdef-hsl) and
[hsla()](#funcdef-hsla)
functions is:

```
hsl() = [ <legacy-hsl-syntax> | <modern-hsl-syntax> ]
hsla() = [ <legacy-hsla-syntax> | <modern-hsla-syntax> ]
<modern-hsl-syntax> = hsl(
 [<hue> | none]
 [<percentage> | <number> | none]
 [<percentage> | <number> | none]
 [ / [<alpha-value> | none] ]? )
<modern-hsla-syntax> = hsla(
 [<hue> | none]
 [<percentage> | <number> | none]
 [<percentage> | <number> | none]
 [ / [<alpha-value> | none] ]? )
<legacy-hsl-syntax> = hsl( <hue>, <percentage>, <percentage>, <alpha-value>? )
<legacy-hsla-syntax> = hsla( <hue>, <percentage>, <percentage>, <alpha-value>? )
```

Percentages

Allowed for S and L

Percent reference range 

for S and L: 0% = 0.0, 100% = 100.0

Powerless hue ε

S \<= 0.001

Tests

- [hsl-001.html](https://wpt.fyi/results/css/css-color/hsl-001.html "css/css-color/hsl-001.html")
 [[(live
 test)]](http://wpt.live/css/css-color/hsl-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/hsl-001.html)
- [hsl-002.html](https://wpt.fyi/results/css/css-color/hsl-002.html "css/css-color/hsl-002.html")
 [[(live
 test)]](http://wpt.live/css/css-color/hsl-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/hsl-002.html)
- [hsl-003.html](https://wpt.fyi/results/css/css-color/hsl-003.html "css/css-color/hsl-003.html")
 [[(live
 test)]](http://wpt.live/css/css-color/hsl-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/hsl-003.html)
- [hsl-004.html](https://wpt.fyi/results/css/css-color/hsl-004.html "css/css-color/hsl-004.html")
 [[(live
 test)]](http://wpt.live/css/css-color/hsl-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/hsl-004.html)
- [hsl-005.html](https://wpt.fyi/results/css/css-color/hsl-005.html "css/css-color/hsl-005.html")
 [[(live
 test)]](http://wpt.live/css/css-color/hsl-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/hsl-005.html)
- [hsl-006.html](https://wpt.fyi/results/css/css-color/hsl-006.html "css/css-color/hsl-006.html")
 [[(live
 test)]](http://wpt.live/css/css-color/hsl-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/hsl-006.html)
- [hsl-007.html](https://wpt.fyi/results/css/css-color/hsl-007.html "css/css-color/hsl-007.html")
 [[(live
 test)]](http://wpt.live/css/css-color/hsl-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/hsl-007.html)
- [hsl-008.html](https://wpt.fyi/results/css/css-color/hsl-008.html "css/css-color/hsl-008.html")
 [[(live
 test)]](http://wpt.live/css/css-color/hsl-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/hsl-008.html)
- [hsl-clamp-negative-saturation.html](https://wpt.fyi/results/css/css-color/hsl-clamp-negative-saturation.html "css/css-color/hsl-clamp-negative-saturation.html")
 [[(live
 test)]](http://wpt.live/css/css-color/hsl-clamp-negative-saturation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/hsl-clamp-negative-saturation.html)
- [background-color-hsl-001.html](https://wpt.fyi/results/css/css-color/background-color-hsl-001.html "css/css-color/background-color-hsl-001.html")
 [[(live
 test)]](http://wpt.live/css/css-color/background-color-hsl-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/background-color-hsl-001.html)
- [background-color-hsl-002.html](https://wpt.fyi/results/css/css-color/background-color-hsl-002.html "css/css-color/background-color-hsl-002.html")
 [[(live
 test)]](http://wpt.live/css/css-color/background-color-hsl-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/background-color-hsl-002.html)
- [background-color-hsl-003.html](https://wpt.fyi/results/css/css-color/background-color-hsl-003.html "css/css-color/background-color-hsl-003.html")
 [[(live
 test)]](http://wpt.live/css/css-color/background-color-hsl-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/background-color-hsl-003.html)
- [background-color-hsl-004.html](https://wpt.fyi/results/css/css-color/background-color-hsl-004.html "css/css-color/background-color-hsl-004.html")
 [[(live
 test)]](http://wpt.live/css/css-color/background-color-hsl-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/background-color-hsl-004.html)
- [color-computed-hsl.html](https://wpt.fyi/results/css/css-color/parsing/color-computed-hsl.html "css/css-color/parsing/color-computed-hsl.html")
 [[(live
 test)]](http://wpt.live/css/css-color/parsing/color-computed-hsl.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/parsing/color-computed-hsl.html)
- [color-invalid-hsl.html](https://wpt.fyi/results/css/css-color/parsing/color-invalid-hsl.html "css/css-color/parsing/color-invalid-hsl.html")
 [[(live
 test)]](http://wpt.live/css/css-color/parsing/color-invalid-hsl.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/parsing/color-invalid-hsl.html)
- [color-valid-hsl.html](https://wpt.fyi/results/css/css-color/parsing/color-valid-hsl.html "css/css-color/parsing/color-valid-hsl.html")
 [[(live
 test)]](http://wpt.live/css/css-color/parsing/color-valid-hsl.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/parsing/color-valid-hsl.html)

The first argument specifies the hue angle.

In HSL (and HWB) the angle [0deg] represents sRGB primary red (as
does [360deg], [720deg], etc.), and the rest of the hues are
spread around the circle, so [120deg] represents sRGB primary
green, [240deg] represents sRGB primary blue, etc.

The next two arguments are the saturation and lightness, respectively.
For saturation, [100%] or [100] is a fully-saturated, bright
color, and [0%] or [0] is a fully-unsaturated gray. For
lightness, [50%] or [50] represents the \"normal\" color,
while [100%] or [100] is white and [0%] or [0]
is black.

For historical reasons, if the saturation is less than [0%] it is
clamped to [0%] at parsed-value time, before being converted to an
sRGB color.

Tests

- [color-valid-hsl.html](https://wpt.fyi/results/css/css-color/parsing/color-valid-hsl.html "css/css-color/parsing/color-valid-hsl.html")
 [[(live
 test)]](http://wpt.live/css/css-color/parsing/color-valid-hsl.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/parsing/color-valid-hsl.html)

The final argument specifies the alpha component of the color. It's
interpreted identically to the fourth argument of the
[rgb()](#funcdef-rgb)
function. If omitted, it defaults to [100%].

HSL colors resolve to sRGB.

If the saturation of an HSL color is [0%] or [0], then the
hue component is
[powerless](#powerless-color-component).

For example, an ordinary red, the
same color you would see from the keyword  [red](#valdef-color-red) or the hex notation  [#f00], is represented in HSL as  [hsl(0deg 100% 50%)].

An advantage of HSL over RGB is that it is more intuitive: people can
guess at the colors they want, and then tweak.

For example, the following colors can all
be generated off of the basic \"green\" hue, just by varying the other
two arguments:

```
hsl(120deg 100% 50%) lime green
hsl(120deg 100% 25%) dark green
hsl(120deg 100% 75%) light green
hsl(120deg 75% 85%) pastel green
```

A disadvantage of HSL over OkLCh is that hue manipulation changes the
visual lightness, and that hues are not evenly spaced apart.

It is thus easier in HSL to create sets of matching colors (by keeping
the hue the same and varying the saturation and lightness), compared to
manipulating the sRGB component values; however, because the lightness
is simply the mean of the gamma-corrected red, green and blue components
it does not correspond to the visual perception of lightness across
hues.

For example,  [blue](#valdef-color-blue) is represented in HSL as  [hsl(240deg 100% 50%)] while  [yellow](#valdef-color-yellow) is  [hsl(60deg 100% 50%)]. Both have an HSL
Lightness of 50%, but clearly the yellow looks much lighter than the
blue.

In OkLCh, sRGB blue is  [oklch(0.452
0.313 264.1)] while sRGB yellow is  [oklch(0.968 0.211 109.8)]. The OkLCh
Lightnesses of 0.452 and 0.968 clearly reflect the visual lightnesses of
the two colors.

The hue angle in HSL is not perceptually uniform; colors appear bunched
up in some areas and widely spaced in others.

For example, the pair of hues
 [hsl(220deg 100%
50%)] and  [hsl(250deg 100% 50%)] have an
HSL hue difference of 250-220 = **30**deg and look fairly similar, while
another pair of colors  [hsl(50deg 100% 50%)] and
 [hsl(80deg 100%
50%)], which *also* have a hue difference of 80-50 = **30**deg,
look very different.

In OkLCh, the same pair of colors  [oklch(0.533 0.26 262.6)] and
 [oklch(0.462 0.306
268.9)] have a hue difference of 268.9 - 262.6 = **6.3**deg while
the second pair  [oklch(0.882 0.181 94.24)] and
 [oklch(0.91 0.245
129.9)] have a hue difference of 129.9 - 94.24 = **35.66**deg,
correctly reflecting the visual separation of hues.

For historical reasons, [hsl()](#funcdef-hsl) and
[hsla()](#funcdef-hsla)
also support a [legacy color
syntax](#legacy-color-syntax).

Tests

- [hsla-001.html](https://wpt.fyi/results/css/css-color/hsla-001.html "css/css-color/hsla-001.html")
 [[(live
 test)]](http://wpt.live/css/css-color/hsla-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/hsla-001.html)
- [hsla-002.html](https://wpt.fyi/results/css/css-color/hsla-002.html "css/css-color/hsla-002.html")
 [[(live
 test)]](http://wpt.live/css/css-color/hsla-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/hsla-002.html)
- [hsla-003.html](https://wpt.fyi/results/css/css-color/hsla-003.html "css/css-color/hsla-003.html")
 [[(live
 test)]](http://wpt.live/css/css-color/hsla-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/hsla-003.html)
- [hsla-004.html](https://wpt.fyi/results/css/css-color/hsla-004.html "css/css-color/hsla-004.html")
 [[(live
 test)]](http://wpt.live/css/css-color/hsla-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/hsla-004.html)
- [hsla-005.html](https://wpt.fyi/results/css/css-color/hsla-005.html "css/css-color/hsla-005.html")
 [[(live
 test)]](http://wpt.live/css/css-color/hsla-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/hsla-005.html)
- [hsla-006.html](https://wpt.fyi/results/css/css-color/hsla-006.html "css/css-color/hsla-006.html")
 [[(live
 test)]](http://wpt.live/css/css-color/hsla-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/hsla-006.html)
- [hsla-007.html](https://wpt.fyi/results/css/css-color/hsla-007.html "css/css-color/hsla-007.html")
 [[(live
 test)]](http://wpt.live/css/css-color/hsla-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/hsla-007.html)
- [hsla-008.html](https://wpt.fyi/results/css/css-color/hsla-008.html "css/css-color/hsla-008.html")
 [[(live
 test)]](http://wpt.live/css/css-color/hsla-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/hsla-008.html)
- [hsla-clamp-negative-saturation.html](https://wpt.fyi/results/css/css-color/hsla-clamp-negative-saturation.html "css/css-color/hsla-clamp-negative-saturation.html")
 [[(live
 test)]](http://wpt.live/css/css-color/hsla-clamp-negative-saturation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/hsla-clamp-negative-saturation.html)
- [color-valid.html](https://wpt.fyi/results/css/css-color/parsing/color-valid.html "css/css-color/parsing/color-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-color/parsing/color-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/parsing/color-valid.html)

### 7.1. Converting HSL Colors to sRGB

Converting an HSL color to sRGB is straightforward mathematically.
Here's a sample implementation of the conversion algorithm in
JavaScript. It returns an array of three numbers representing the red,
green, and blue components of the colors, which for colors in the sRGB
gamut will be in the range \[0, 1\].

This code assumes that *parse-time* clamping of negative saturation has
already been applied.

```
/**
 * @param {number} hue - Hue as degrees 0..360
 * @param {number} sat - Saturation in reference range [0,100]
 * @param {number} light - Lightness in reference range [0,100]
 * @return {number} Array of sRGB components; in-gamut colors in range [0..1]
 */
function hslToRgb(hue, sat, light) {

 sat /= 100;
 light /= 100;

 function f(n) {
 let k = (n + hue/30) % 12;
 let a = sat * Math.min(light, 1 - light);
 return light - a * Math.max(-1, Math.min(k - 3, 9 - k, 1));
 }

 return [f(0), f(8), f(4)];
}
```

### 7.2. Converting sRGB Colors to HSL

Conversion in the reverse direction proceeds similarly.

Special care is taken to deal with intermediate negative values of
saturation, which can be produced by colors far outside the sRGB gamut.

```
/**
 * @param {number} red - Red component 0..1
 * @param {number} green - Green component 0..1
 * @param {number} blue - Blue component 0..1
 * @return {number} Array of HSL values: Hue as degrees 0..360, Saturation and Lightness in reference range [0,100]
 */
function rgbToHsl (red, green, blue) {
 let max = Math.max(red, green, blue);
 let min = Math.min(red, green, blue);
 let [hue, sat, light] = [NaN, 0, (min + max)/2];
 let d = max - min;
 let epsilon = 1 / 100000; // max Sat is 1, in this code

 if (d !== 0) {
 sat = (light === 0 || light === 1)
 ? 0
 : (max - light) / Math.min(light, 1 - light);

 switch (max) {
 case red: hue = (green - blue) / d + (green < blue ? 6 : 0); break;
 case green: hue = (blue - red) / d + 2; break;
 case blue: hue = (red - green) / d + 4;
 }

 hue = hue * 60;
 }

 // Very out of gamut colors can produce negative saturation
 // If so, just rotate the hue by 180 and use a positive saturation
 // see https://github.com/w3c/csswg-drafts/issues/9222
 if (sat < 0) {
 hue += 180;
 sat = Math.abs(sat);
 }

 if (hue >= 360) {
 hue -= 360;
 }

 if (sat <= epsilon) {
 hue = NaN;
 }

 return [hue, sat * 100, light * 100];
}
```

### 7.3. Examples of HSL Colors

*This section is not normative.*

Tests

This section is not normative, it does not need tests.

------------------------------------------------------------------------

The tables below illustrate a wide range of possible HSL colors. Each
table represents one hue, selected at 30° intervals, to illustrate the
common \"core\" hues: red, yellow, green, cyan, blue, magenta, and the
six intermediary colors between these.

In each table, the X axis represents the saturation while the Y axis
represents the lightness.

0° Reds

100%

80%

60%

40%

20%

0%

100%

90%

80%

70%

60%

50%

40%

30%

20%

10%

0%

30° Reds-Yellows (=Oranges)

100%

80%

60%

40%

20%

0%

100%

90%

80%

70%

60%

50%

40%

30%

20%

10%

0%

60° Yellows

100%

80%

60%

40%

20%

0%

100%

90%

80%

70%

60%

50%

40%

30%

20%

10%

0%

90° Yellow-Greens

100%

80%

60%

40%

20%

0%

100%

90%

80%

70%

60%

50%

40%

30%

20%

10%

0%

120° Greens

100%

80%

60%

40%

20%

0%

100%

90%

80%

70%

60%

50%

40%

30%

20%

10%

0%

150° Green-Cyans

100%

80%

60%

40%

20%

0%

100%

90%

80%

70%

60%

50%

40%

30%

20%

10%

0%

180° Cyans

100%

80%

60%

40%

20%

0%

100%

90%

80%

70%

60%

50%

40%

30%

20%

10%

0%

210° Cyan-Blues

100%

80%

60%

40%

20%

0%

100%

90%

80%

70%

60%

50%

40%

30%

20%

10%

0%

240° blues

100%

80%

60%

40%

20%

0%

100%

90%

80%

70%

60%

50%

40%

30%

20%

10%

0%

270° Blue-Magentas

100%

80%

60%

40%

20%

0%

100%

90%

80%

70%

60%

50%

40%

30%

20%

10%

0%

300° Magentas

100%

80%

60%

40%

20%

0%

100%

90%

80%

70%

60%

50%

40%

30%

20%

10%

0%

330° Magenta-Reds

100%

80%

60%

40%

20%

0%

100%

90%

80%

70%

60%

50%

40%

30%

20%

10%

0%

## 8. HWB Colors: [hwb() function]
[HWB] (short for Hue-Whiteness-Blackness)
[\[HWB\]](#biblio-hwb "HWB — A More Intuitive Hue-Based Color Model")
is another method of specifying sRGB colors, similar to
[HSL](#valdef-hsl-hsl)\', but often even easier for humans to work with. It
describes colors with a starting hue, then a degree of whiteness and
blackness to mix into that base hue.

Many color-pickers are based on the HWB color system, due to its
intuitiveness.

HWB colors resolve to sRGB.

![This is a screenshot of Chrome's color picker, shown when a user
activates an `<input type="color">`. The outer
wheel is used to select the hue, then the relative amounts of white and
black are selected by clicking on the inner
triangle.](images/color-picker.png)

The syntax of the [hwb()](#funcdef-hwb) function is:

```
hwb() = hwb(
 [<hue> | none]
 [<percentage> | <number> | none]
 [<percentage> | <number> | none]
 [ / [<alpha-value> | none] ]? )
```

Percentages

Allowed for W and B

Percent reference range 

for W and B: 0% = 0.0, 100% = 100.0

Powerless hue ε

W + B \>= 99.999

The first argument specifies the hue, and is defined identically to
[hsl()](#funcdef-hsl);
this means it [suffers the same disadvantages](#disadvantage-hsl) such
as hue uniformity.

The second argument specifies the amount of white to mix in, as a
percentage from [0%] (no whiteness) to [100%] (full
whiteness). Similarly, the third argument specifies the amount of black
to mix in, also from [0%] (no blackness) to [100%] (full
blackness).

For example,  hwb(150 20% 10%) is the same color as
 hsl(150 77.78% 55%) and
 rgb(20% 90% 55%).

 [hwb()](#funcdef-hwb) does not account for the Abney effect
[\[Abney\]](#biblio-abney "Abney effect") which is
the perceived hue shift that occurs when white light is added to a
monochromatic light source.

Values outside of these ranges are not invalid; hue angles outside the
range \[0,360) will be normalized to that range and values of white and
black which sum to 100% or greater will produce achromatic colors as
described below.

The resulting color can be thought of conceptually as a mixture of paint
in the chosen hue, white paint, and black paint, with the relative
amounts of each determined by the percentages.

If the sum white+black is greater than or equal to [100%], it
defines an achromatic color, i.e. a shade of gray; when converted to
sRGB the R, G and B values are identical and have the value white /
(white + black).

For example, in the color  hwb(45 40% 80%) white and
black adds to 120, so this is an achromatic color whose R, G and B
components are 40 / 40 + 80 = 0.33  rgb(33.33% 33.33% 33.33%).

Achromatic HWB colors no longer contain any hint of the chosen hue. In
this case, the hue component is
[powerless](#powerless-color-component).

The fourth argument specifies the alpha component of the color. It's
interpreted identically to the fourth argument of the
[rgb()](#funcdef-rgb)
function. If omitted, it defaults to [100%].

There is no Web compatibility issue with
[hwb](#valdef-hwb-hwb),
which is new in this level of the specification, and so
[hwb()](#funcdef-hwb) does
*not* support a [legacy color
syntax](#legacy-color-syntax) that separates all of its arguments with commas. Using
commas inside [hwb()] is an error.

Tests

- [hwb-001.html](https://wpt.fyi/results/css/css-color/hwb-001.html "css/css-color/hwb-001.html")
 [[(live
 test)]](http://wpt.live/css/css-color/hwb-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/hwb-001.html)
- [hwb-002.html](https://wpt.fyi/results/css/css-color/hwb-002.html "css/css-color/hwb-002.html")
 [[(live
 test)]](http://wpt.live/css/css-color/hwb-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/hwb-002.html)
- [hwb-003.html](https://wpt.fyi/results/css/css-color/hwb-003.html "css/css-color/hwb-003.html")
 [[(live
 test)]](http://wpt.live/css/css-color/hwb-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/hwb-003.html)
- [hwb-004.html](https://wpt.fyi/results/css/css-color/hwb-004.html "css/css-color/hwb-004.html")
 [[(live
 test)]](http://wpt.live/css/css-color/hwb-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/hwb-004.html)
- [hwb-005.html](https://wpt.fyi/results/css/css-color/hwb-005.html "css/css-color/hwb-005.html")
 [[(live
 test)]](http://wpt.live/css/css-color/hwb-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/hwb-005.html)
- [color-valid.html](https://wpt.fyi/results/css/css-color/parsing/color-valid.html "css/css-color/parsing/color-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-color/parsing/color-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/parsing/color-valid.html)
- [color-computed-hwb.html](https://wpt.fyi/results/css/css-color/parsing/color-computed-hwb.html "css/css-color/parsing/color-computed-hwb.html")
 [[(live
 test)]](http://wpt.live/css/css-color/parsing/color-computed-hwb.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/parsing/color-computed-hwb.html)
- [color-invalid-hwb.html](https://wpt.fyi/results/css/css-color/parsing/color-invalid-hwb.html "css/css-color/parsing/color-invalid-hwb.html")
 [[(live
 test)]](http://wpt.live/css/css-color/parsing/color-invalid-hwb.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/parsing/color-invalid-hwb.html)
- [color-valid-hwb.html](https://wpt.fyi/results/css/css-color/parsing/color-valid-hwb.html "css/css-color/parsing/color-valid-hwb.html")
 [[(live
 test)]](http://wpt.live/css/css-color/parsing/color-valid-hwb.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/parsing/color-valid-hwb.html)

### 8.1. Converting HWB Colors to sRGB

Converting an HWB color to sRGB is straightforward, and related to how
one converts HSL to RGB. The following Javascript implementation of the
algorithm first normalizes the white and black components, so their sum
is no larger than 100%.

```
/**
 * @param {number} hue - Hue as degrees 0..360
 * @param {number} white - Whiteness in reference range [0,100]
 * @param {number} black - Blackness in reference range [0,100]
 * @return {number} Array of RGB components 0..1
 */
function hwbToRgb(hue, white, black) {
 white /= 100;
 black /= 100;
 if (white + black >= 1) {
 let gray = white / (white + black);
 return [gray, gray, gray];
 }
 let rgb = hslToRgb(hue, 100, 50);
 for (let i = 0; i < 3; i++) {
 rgb[i] *= (1 - white - black);
 rgb[i] += white;
 }
 return rgb;
}
```

### 8.2. Converting sRGB Colors to HWB

Conversion in the reverse direction proceeds similarly.

```
/**
 * @param {number} red - Red component 0..1
 * @param {number} green - Green component 0..1
 * @param {number} blue - Blue component 0..1
 * @return {number} Hue as degrees 0..360
 */
function rgbToHue(red, green, blue) {
 // Similar to rgbToHsl, except that saturation and lightness are not calculated, and
 // potential negative saturation is ignored.
 let max = Math.max(red, green, blue);
 let min = Math.min(red, green, blue);
 let hue = NaN;
 let d = max - min;

 if (d !== 0) {
 switch (max) {
 case red: hue = (green - blue) / d + (green < blue ? 6 : 0); break;
 case green: hue = (blue - red) / d + 2; break;
 case blue: hue = (red - green) / d + 4;
 }

 hue *= 60;
 }

 if (hue >= 360) {
 hue -= 360;
 }

 return hue;
}

/**
 * @param {number} red - Red component 0..1
 * @param {number} green - Green component 0..1
 * @param {number} blue - Blue component 0..1
 * @return {number} Array of HWB values: Hue as degrees 0..360, Whiteness and Blackness in reference range [0,100]
 */
function rgbToHwb(red, green, blue) {
 let epsilon = 1 / 100000; // account for multiply by 100
 var hue = rgbToHue(red, green, blue);
 var white = Math.min(red, green, blue);
 var black = 1 - Math.max(red, green, blue);
 if (white + black >= 1 - epsilon) {
 hue = NaN;
 }
 return([hue, white*100, black*100]);
}
```

### 8.3. Examples of HWB Colors

*This section is not normative.*

Tests

This section is not normative, it does not need tests.

------------------------------------------------------------------------

::: color-table
0° Reds

[W]\\[B]

0%

20%

40%

60%

80%

100%

0%

20%

40%

60%

80%

100%

30° Red-Yellows (Oranges)

[W]\\[B]

0%

20%

40%

60%

80%

100%

0%

20%

40%

60%

80%

100%

60° Yellows

[W]\\[B]

0%

20%

40%

60%

80%

100%

0%

20%

40%

60%

80%

100%

90° Yellow-Greens

[W]\\[B]

0%

20%

40%

60%

80%

100%

0%

20%

40%

60%

80%

100%

120° Greens

[W]\\[B]

0%

20%

40%

60%

80%

100%

0%

20%

40%

60%

80%

100%

150° Green-Cyans

[W]\\[B]

0%

20%

40%

60%

80%

100%

0%

20%

40%

60%

80%

100%

180° Cyans

[W]\\[B]

0%

20%

40%

60%

80%

100%

0%

20%

40%

60%

80%

100%

210° Cyan-Blues

[W]\\[B]

0%

20%

40%

60%

80%

100%

0%

20%

40%

60%

80%

100%

240° Blues

[W]\\[B]

0%

20%

40%

60%

80%

100%

0%

20%

40%

60%

80%

100%

270° Blue-Magentas

[W]\\[B]

0%

20%

40%

60%

80%

100%

0%

20%

40%

60%

80%

100%

300° Magentas

[W]\\[B]

0%

20%

40%

60%

80%

100%

0%

20%

40%

60%

80%

100%

330° Magenta-Reds

[W]\\[B]

0%

20%

40%

60%

80%

100%

0%

20%

40%

60%

80%

100%

## 9. Device-independent Colors: CIE Lab and LCH, Oklab and OkLCh

### 9.1. CIE Lab and LCH

*This section is not normative.*

Tests

This section is not normative, it does not need tests.

------------------------------------------------------------------------

Physical measurements of a color are typically expressed in the CIE
L\*a\*b\*
[\[CIELAB\]](#biblio-cielab "ISO/CIE 11664-4:2019(E): Colorimetry — Part 4: CIE 1976 L*a*b* colour space")
color space, created in 1976 by the [CIE] and commonly referred
to simply as Lab. Color conversions from one device to another may also
use Lab as an intermediate step. Derived from human vision experiments,
Lab represents the entire range of color that humans can see.

Lab is a rectangular coordinate system with a central Lightness (L)
axis. This value is usually written as a unitless number; for
compatibility with the rest of CSS, it may also be written as a
percentage. 100% means an L value of 100, not 1.0. L=0% or 0 is deep
black (no light at all) while L=100% or 100 is a diffuse white.

Usefully, L=50% or 50 is mid gray, by design, and equal increments in L
are evenly spaced visually: the Lab color space is intended to be
*perceptually uniform*.

<figure id="lightness-vs-luminance">
<img src="images/L-axis.svg" width="240" height="575" /> <img
src="images/Luminance.svg" width="240" height="575" />
<figcaption>This figure shows, to the left, the Lightness axis of the
CIE Lab color space. Twenty-one neutral swatches are shown (L=0%, L=5%,
to L=100%). The steps are equally spaced, visually. To the right, the
same number of steps in <a href="#luminance" id="ref-for-luminance"
data->luminance</a> are equally spaced in light energy
but <strong>not</strong> equally spaced visually.</figcaption>
</figure>

The a and b axes convey hue; positive values along the a axis are a
purplish red while negative values are the complementary color, a green.
Similarly, positive values along the b axis are yellow and negative are
the complementary blue/violet. Desaturated colors have small values of a
and b and are close to the L axis; saturated colors lie far from the L
axis.

The illuminant is [D50](#d50) white, a
standardized daylight spectrum with a color temperature of 5000K, as
reflected by a perfect diffuse reflector; it approximates the color of
sunlight on a sunny day. D50 is also the whitepoint used for the profile
connection space in ICC color interconversion, the whitepoint used in
image editors which offer Lab editing, and the value used by physical
measurement devices such as spectrophotometers and spectroradiometers,
when they report measured colors in Lab.

Conversion from colors specified using other white points is called a
[chromatic adaptation transform], which models the changes in the
human visual system as we adapt to a new lighting condition. The linear
Bradford algorithm
[\[ICC\]](#biblio-icc "ICC.1:2022 (Profile version 4.4.0.0)")
(a simplification of the original Bradford algorithm
[\[Bradford-CAT\]](#biblio-bradford-cat "A Chromatic Adaptation Transform and a Colour Inconstancy Index. Color Research & Application 23(3) 154-158"))
is the industry standard chromatic adaptation transform, and is easy to
calculate as it is a simple matrix multiplication.

CIE LCH has the same L axis as Lab, but uses polar coordinates C
(chroma) and H (hue), making it a polar, cylindrical coordinate system.
C is the geometric distance from the L axis and H is the angle from the
positive a axis, towards the positive b axis.

![This figure shows the L=50 plane of the CIE Lab color space. 20 degree
increments in CIE LCH are displayed as circles at three levels of
Chroma: 20, 40 and 60. All the 20 Chroma colors fit inside sRGB gamut,
some of 40 and 60 Chroma are outside. These out of gamut colors are
visualized as grey, with a red warning outer
stroke.](images/CH-plane-wheel.svg)

Note: The L axis in Lab and LCH is not to be confused with the L axis in
HSL. For example, in HSL, the sRGB colors blue (#00F) and yellow (#FF0)
have the same value of L (50%) even though visually, blue is much
darker. This is much clearer in Lab: sRGB blue is lab(29.567% 68.298
-112.0294) while sRGB yellow is lab(97.607% -15.753 93.388). In Lab and
LCH, if two colors have the same measured L value, they have identical
visual lightness. HSL and related polar RGB models were developed in an
attempt to give similar usability benefits for RGB that LCH gave to Lab,
but are significantly less accurate.

Although the use of CIE Lab and LCH is widespread, it is known to have
some problems. In particular:

Hue linearity
: In the blue region (LCH Hue between 270° and 330°), visual hue
 departs from what LCH predicts. Plotting a set of blues of the same
 hue and differing Chroma, which should lie on a straight line from
 the neutral axis, instead form a curve. Put another way, as a
 saturated blue has it's Chroma progressively reduced, it becomes
 noticeably purple.

Hue uniformity
: While hues in LCH are in general evenly spaced, (and far better than
 HSL or HWB), uniformity is not perfect.

Over-prediction of high Chroma differences
: For high Chroma colors, changes in Chroma are less noticeable than
 for more neutral colors.

These deficiencies affect, for example, creation of evenly spaced
gradients, gamut mapping from one color space to a smaller one, and
computation of the visual difference between two colors.

To compensate for this, formulae to predict the visual difference
between two colors (delta E) have been made more accurate over time (but
also, much more complex to compute). The current industry standard
formula, delta E 2000, works well to mitigate some of the Lab and LCH
problems. A sample implementation is given in [§ 20.2
ΔE2000](#color-difference-2000).

This does not help with hue curvature, however.

### 9.2. Oklab and OkLCh

*This section is not normative.*

Tests

This section is not normative, it does not need tests.

------------------------------------------------------------------------

Recently, Oklab, an improved Lab-like space has been developed
[\[Oklab\]](#biblio-oklab "A perceptual color space for image processing").
The corresponding polar form is called OkLCh. It was produced by
numerical optimization of a large dataset of visually similar colors,
and has improved hue linearity, hue uniformity, and chroma uniformity
compared to CIE LCH.

Like CIE Lab, there is a central lightness L axis which is usually
written as a unitless number in the range \[0,1\]; for compatibility
with the rest of CSS, it may be written as a percentage. 100% means an L
value of 1.0. L=0% or 0.0 is deep black (no light at all) while L=100%
or 1.0 is a diffuse white.

 Unlike CIE Lab, which assumes adaptation to the diffuse
white, Oklab assumes adaptation to the color being defined, which is
intended to make it scale invariant.

As with CIE Lab, the a and b axes convey hue; positive values along the
a axis are a purplish red while negative values are the complementary
color, a green. Similarly, positive values along the b axis are yellow
and negative are the complementary blue/violet.

The illuminant is [D65](#d65), the same
white point as most RGB color spaces.

OkLCh has the same L axis as Oklab, but uses polar coordinates C
(chroma) and H (hue).

 Unlike CIE LCH, where Chroma can reach values of 200 or
more, OkLCh Chroma ranges to 0.5 or so. The hue angles between CIE LCH
and OkLCh are broadly similar, but not identical.

![A constant CIE LCH hue slice, showing the sRGB gamut around primary
blue. A noticeable purpling is immediately
evident.](images/CIELCH-blue-slice.png)

![A constant OkLCh hue slice, showing the sRGB gamut around primary
blue. The visual hue remains
constant.](images/OKLCH-blue-slice.png)

Because Oklab is more perceptually uniform than CIE Lab, the color
difference is a straightforward distance in 3D space (root sum of
squares). Although trivial, a sample implementation is give in [§ 20.3
ΔEOK](#color-difference-OK).

### 9.3. Specifying Lab and LCH: the [lab() and [lch()](#funcdef-lch) functional notations]
CSS allows colors to be directly expressed in Lab and LCH.

```
lab() = lab( [<percentage> | <number> | none]
 [ <percentage> | <number> | none]
 [ <percentage> | <number> | none]
 [ / [<alpha-value> | none] ]? )
```

Percentages

Allowed for L, a and b

Percent reference range 

for L: 0% = 0.0, 100% = 100.0\
for a and b: -100% = -125, 100% = 125

Tests

- [lab-001.html](https://wpt.fyi/results/css/css-color/lab-001.html "css/css-color/lab-001.html")
 [[(live
 test)]](http://wpt.live/css/css-color/lab-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/lab-001.html)
- [lab-002.html](https://wpt.fyi/results/css/css-color/lab-002.html "css/css-color/lab-002.html")
 [[(live
 test)]](http://wpt.live/css/css-color/lab-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/lab-002.html)
- [lab-003.html](https://wpt.fyi/results/css/css-color/lab-003.html "css/css-color/lab-003.html")
 [[(live
 test)]](http://wpt.live/css/css-color/lab-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/lab-003.html)
- [lab-004.html](https://wpt.fyi/results/css/css-color/lab-004.html "css/css-color/lab-004.html")
 [[(live
 test)]](http://wpt.live/css/css-color/lab-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/lab-004.html)
- [lab-005.html](https://wpt.fyi/results/css/css-color/lab-005.html "css/css-color/lab-005.html")
 [[(live
 test)]](http://wpt.live/css/css-color/lab-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/lab-005.html)
- [lab-006.html](https://wpt.fyi/results/css/css-color/lab-006.html "css/css-color/lab-006.html")
 [[(live
 test)]](http://wpt.live/css/css-color/lab-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/lab-006.html)
- [lab-007.html](https://wpt.fyi/results/css/css-color/lab-007.html "css/css-color/lab-007.html")
 [[(live
 test)]](http://wpt.live/css/css-color/lab-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/lab-007.html)
- [lab-008.html](https://wpt.fyi/results/css/css-color/lab-008.html "css/css-color/lab-008.html")
 [[(live
 test)]](http://wpt.live/css/css-color/lab-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/lab-008.html)
- [lab-l-over-100-1.html](https://wpt.fyi/results/css/css-color/lab-l-over-100-1.html "css/css-color/lab-l-over-100-1.html")
 [[(live
 test)]](http://wpt.live/css/css-color/lab-l-over-100-1.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/lab-l-over-100-1.html)
- [lab-l-over-100-2.html](https://wpt.fyi/results/css/css-color/lab-l-over-100-2.html "css/css-color/lab-l-over-100-2.html")
 [[(live
 test)]](http://wpt.live/css/css-color/lab-l-over-100-2.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/lab-l-over-100-2.html)
- [color-valid.html](https://wpt.fyi/results/css/css-color/parsing/color-valid.html "css/css-color/parsing/color-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-color/parsing/color-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/parsing/color-valid.html)
- [color-computed-lab.html](https://wpt.fyi/results/css/css-color/parsing/color-computed-lab.html "css/css-color/parsing/color-computed-lab.html")
 [[(live
 test)]](http://wpt.live/css/css-color/parsing/color-computed-lab.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/parsing/color-computed-lab.html)
- [color-invalid-lab.html](https://wpt.fyi/results/css/css-color/parsing/color-invalid-lab.html "css/css-color/parsing/color-invalid-lab.html")
 [[(live
 test)]](http://wpt.live/css/css-color/parsing/color-invalid-lab.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/parsing/color-invalid-lab.html)
- [color-valid-lab.html](https://wpt.fyi/results/css/css-color/parsing/color-valid-lab.html "css/css-color/parsing/color-valid-lab.html")
 [[(live
 test)]](http://wpt.live/css/css-color/parsing/color-valid-lab.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/parsing/color-valid-lab.html)

In [Lab], the first argument specifies the CIE
Lightness, L. This is a number between [0%] or 0 and [100%]
or 100 Values less than [0%] or 0 must be clamped to [0%] at
parsed-value time; values greater than [100%] or 100 are clamped
to [100%] at parsed-value time.

The second and third arguments are the distances along the \"a\" and
\"b\" axes in the Lab color space, as described in the previous section.
These values are signed (allow both positive and negative values) and
theoretically unbounded (but in practice do not exceed ±160 for
real-world colors).

There is an optional fourth
[\<alpha-value\>](#typedef-color-alpha-value) component, separated by a slash,
representing the [alpha
component](#alpha-channel).

If the lightness of a Lab color (after clamping) is [0%], or
[100%] the color will be displayed as black, or white,
respectively due to gamut mapping to the display.

```
 lab(29.2345% 39.3825 20.0664);
 lab(52.2345 40.1645 59.9971);
 lab(60.2345 -5.3654 58.956);
 lab(62.2345% -34.9638 47.7721);
 lab(67.5345 -8.6911 -41.6019);
 lab(29.69% 44.888% -29.04%)
```

```
lch() = lch( [<percentage> | <number> | none]
 [ <percentage> | <number> | none]
 [ <hue> | none]
 [ / [<alpha-value> | none] ]? )
```

Percentages

Allowed for L and C

Percent reference range 

for L: 0% = 0.0, 100% = 100.0\
for C: 0% = 0, 100% = 150

Powerless hue ε

C \<= 0.0015

Tests

- [lch-001.html](https://wpt.fyi/results/css/css-color/lch-001.html "css/css-color/lch-001.html")
 [[(live
 test)]](http://wpt.live/css/css-color/lch-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/lch-001.html)
- [lch-002.html](https://wpt.fyi/results/css/css-color/lch-002.html "css/css-color/lch-002.html")
 [[(live
 test)]](http://wpt.live/css/css-color/lch-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/lch-002.html)
- [lch-003.html](https://wpt.fyi/results/css/css-color/lch-003.html "css/css-color/lch-003.html")
 [[(live
 test)]](http://wpt.live/css/css-color/lch-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/lch-003.html)
- [lch-004.html](https://wpt.fyi/results/css/css-color/lch-004.html "css/css-color/lch-004.html")
 [[(live
 test)]](http://wpt.live/css/css-color/lch-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/lch-004.html)
- [lch-005.html](https://wpt.fyi/results/css/css-color/lch-005.html "css/css-color/lch-005.html")
 [[(live
 test)]](http://wpt.live/css/css-color/lch-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/lch-005.html)
- [lch-006.html](https://wpt.fyi/results/css/css-color/lch-006.html "css/css-color/lch-006.html")
 [[(live
 test)]](http://wpt.live/css/css-color/lch-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/lch-006.html)
- [lch-007.html](https://wpt.fyi/results/css/css-color/lch-007.html "css/css-color/lch-007.html")
 [[(live
 test)]](http://wpt.live/css/css-color/lch-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/lch-007.html)
- [lch-008.html](https://wpt.fyi/results/css/css-color/lch-008.html "css/css-color/lch-008.html")
 [[(live
 test)]](http://wpt.live/css/css-color/lch-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/lch-008.html)
- [lch-009.html](https://wpt.fyi/results/css/css-color/lch-009.html "css/css-color/lch-009.html")
 [[(live
 test)]](http://wpt.live/css/css-color/lch-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/lch-009.html)
- [lch-010.html](https://wpt.fyi/results/css/css-color/lch-010.html "css/css-color/lch-010.html")
 [[(live
 test)]](http://wpt.live/css/css-color/lch-010.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/lch-010.html)
- [lch-l-over-100-1.html](https://wpt.fyi/results/css/css-color/lch-l-over-100-1.html "css/css-color/lch-l-over-100-1.html")
 [[(live
 test)]](http://wpt.live/css/css-color/lch-l-over-100-1.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/lch-l-over-100-1.html)
- [lch-l-over-100-2.html](https://wpt.fyi/results/css/css-color/lch-l-over-100-2.html "css/css-color/lch-l-over-100-2.html")
 [[(live
 test)]](http://wpt.live/css/css-color/lch-l-over-100-2.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/lch-l-over-100-2.html)
- [color-valid.html](https://wpt.fyi/results/css/css-color/parsing/color-valid.html "css/css-color/parsing/color-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-color/parsing/color-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/parsing/color-valid.html)

In CIE [LCH] the first argument specifies the CIE
Lightness L, interpreted identically to the Lightness argument of
[lab()](#funcdef-lab).

The second argument is the chroma C, (roughly representing the \"amount
of color\"). Its minimum useful value is [0], while its maximum is
theoretically unbounded (but in practice does not exceed [230]).
If the provided value is negative, it is clamped to [0] at
parsed-value time.

The third argument is the hue angle H. It's interpreted similarly to the
[\<hue\>](#typedef-hue) argument of
[hsl()](#funcdef-hsl),
but doesn't map hues to angles in the same way because they are evenly
spaced perceptually. Instead, [0deg] points along the positive
\"a\" axis (toward purplish red), (as does [360deg],
[720deg], etc.); [90deg] points along the positive \"b\"
axis (toward mustard yellow), [180deg] points along the negative
\"a\" axis (toward greenish cyan), and [270deg] points along the
negative \"b\" axis (toward sky blue).

There is an optional fourth
[\<alpha-value\>](#typedef-color-alpha-value) component, separated by a slash,
representing the [alpha
component](#alpha-channel).

If the chroma of an LCH color is [0%], the hue component is
[powerless](#powerless-color-component). If the lightness of an LCH color (after clamping) is
[0%], or [100%], the color will be displayed as black, or
white, respectively due to gamut mapping to the display.

```
 lch(29.2345% 44.2 27);
 lch(52.2345% 72.2 56.2);
 lch(60.2345 59.2 95.2);
 lch(62.2345% 59.2 126.2);
 lch(67.5345% 42.5 258.2);
 lch(29.69% 45.553% 327.1)
```

There is no Web compatibility issue with
[lab](#valdef-lab-lab)
or [lch](#valdef-lch-lch)\', which are new in this level of the specification,
and so [lab()](#funcdef-lab) and [lch()](#funcdef-lch) do *not* support a [legacy color
syntax](#legacy-color-syntax) that separates all of their arguments with commas.
Using commas inside these functions is an error.

### 9.4. Specifying Oklab and OkLCh: the [oklab() and [oklch()](#funcdef-oklch) functional notations]
CSS allows colors to be directly expressed in Oklab and OkLCh.

```
oklab() = oklab( [ <percentage> | <number> | none]
 [ <percentage> | <number> | none]
 [ <percentage> | <number> | none]
 [ / [<alpha-value> | none] ]? )
```

Percentages

Allowed for L, a and b

Percent reference range 

for L: 0% = 0.0, 100% = 1.0\
for a and b: -100% = -0.4, 100% = 0.4

Tests

- [oklab-001.html](https://wpt.fyi/results/css/css-color/oklab-001.html "css/css-color/oklab-001.html")
 [[(live
 test)]](http://wpt.live/css/css-color/oklab-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/oklab-001.html)
- [oklab-002.html](https://wpt.fyi/results/css/css-color/oklab-002.html "css/css-color/oklab-002.html")
 [[(live
 test)]](http://wpt.live/css/css-color/oklab-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/oklab-002.html)
- [oklab-003.html](https://wpt.fyi/results/css/css-color/oklab-003.html "css/css-color/oklab-003.html")
 [[(live
 test)]](http://wpt.live/css/css-color/oklab-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/oklab-003.html)
- [oklab-004.html](https://wpt.fyi/results/css/css-color/oklab-004.html "css/css-color/oklab-004.html")
 [[(live
 test)]](http://wpt.live/css/css-color/oklab-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/oklab-004.html)
- [oklab-005.html](https://wpt.fyi/results/css/css-color/oklab-005.html "css/css-color/oklab-005.html")
 [[(live
 test)]](http://wpt.live/css/css-color/oklab-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/oklab-005.html)
- [oklab-006.html](https://wpt.fyi/results/css/css-color/oklab-006.html "css/css-color/oklab-006.html")
 [[(live
 test)]](http://wpt.live/css/css-color/oklab-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/oklab-006.html)
- [oklab-007.html](https://wpt.fyi/results/css/css-color/oklab-007.html "css/css-color/oklab-007.html")
 [[(live
 test)]](http://wpt.live/css/css-color/oklab-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/oklab-007.html)
- [oklab-008.html](https://wpt.fyi/results/css/css-color/oklab-008.html "css/css-color/oklab-008.html")
 [[(live
 test)]](http://wpt.live/css/css-color/oklab-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/oklab-008.html)
- [oklab-009.html](https://wpt.fyi/results/css/css-color/oklab-009.html "css/css-color/oklab-009.html")
 [[(live
 test)]](http://wpt.live/css/css-color/oklab-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/oklab-009.html)
- [oklab-l-almost-0.html](https://wpt.fyi/results/css/css-color/oklab-l-almost-0.html "css/css-color/oklab-l-almost-0.html")
 [[(live
 test)]](http://wpt.live/css/css-color/oklab-l-almost-0.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/oklab-l-almost-0.html)
- [oklab-l-almost-1.html](https://wpt.fyi/results/css/css-color/oklab-l-almost-1.html "css/css-color/oklab-l-almost-1.html")
 [[(live
 test)]](http://wpt.live/css/css-color/oklab-l-almost-1.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/oklab-l-almost-1.html)
- [oklab-l-over-1-1.html](https://wpt.fyi/results/css/css-color/oklab-l-over-1-1.html "css/css-color/oklab-l-over-1-1.html")
 [[(live
 test)]](http://wpt.live/css/css-color/oklab-l-over-1-1.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/oklab-l-over-1-1.html)
- [oklab-l-over-1-2.html](https://wpt.fyi/results/css/css-color/oklab-l-over-1-2.html "css/css-color/oklab-l-over-1-2.html")
 [[(live
 test)]](http://wpt.live/css/css-color/oklab-l-over-1-2.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/oklab-l-over-1-2.html)
- [color-valid.html](https://wpt.fyi/results/css/css-color/parsing/color-valid.html "css/css-color/parsing/color-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-color/parsing/color-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/parsing/color-valid.html)

In [Oklab] the first argument specifies the Oklab
Lightness. This is a number between [0%] or 0 and [100%] or
1.0.

Values less than [0%] or 0.0 must be clamped to [0%] at
parsed-value time; values greater than [100%] or 1.0 are clamped
to [100%] at parsed-value time.

The second and third arguments are the distances along the \"a\" and
\"b\" axes in the Oklab color space, as described in the previous
section. These values are signed (allow both positive and negative
values) and theoretically unbounded (but in practice do not exceed
±0.5).

There is an optional fourth
[\<alpha-value\>](#typedef-color-alpha-value) component, separated by a slash,
representing the [alpha
component](#alpha-channel).

If the lightness of an Oklab color is [0%] or 0, or [100%]
or 1.0, the color will be displayed as black, or white, respectively due
to gamut mapping to the display.

```
 oklab(40.101% 0.1147 0.0453);
 oklab(59.686% 0.1009 0.1192);
 oklab(0.65125 -0.0320 0.1274);
 oklab(66.016% -0.1084 0.1114);
 oklab(72.322% -0.0465 -0.1150);
 oklab(42.1% 41% -25%)
```

```
oklch() = oklch( [ <percentage> | <number> | none]
 [ <percentage> | <number> | none]
 [ <hue> | none]
 [ / [<alpha-value> | none] ]? )
```

Percentages

Allowed for L and C

Percent reference range 

for L: 0% = 0.0, 100% = 1.0\
for C: 0% = 0.0 100% = 0.4

Powerless hue ε

C \<= 0.000004

Tests

- [oklch-001.html](https://wpt.fyi/results/css/css-color/oklch-001.html "css/css-color/oklch-001.html")
 [[(live
 test)]](http://wpt.live/css/css-color/oklch-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/oklch-001.html)
- [oklch-002.html](https://wpt.fyi/results/css/css-color/oklch-002.html "css/css-color/oklch-002.html")
 [[(live
 test)]](http://wpt.live/css/css-color/oklch-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/oklch-002.html)
- [oklch-003.html](https://wpt.fyi/results/css/css-color/oklch-003.html "css/css-color/oklch-003.html")
 [[(live
 test)]](http://wpt.live/css/css-color/oklch-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/oklch-003.html)
- [oklch-004.html](https://wpt.fyi/results/css/css-color/oklch-004.html "css/css-color/oklch-004.html")
 [[(live
 test)]](http://wpt.live/css/css-color/oklch-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/oklch-004.html)
- [oklch-005.html](https://wpt.fyi/results/css/css-color/oklch-005.html "css/css-color/oklch-005.html")
 [[(live
 test)]](http://wpt.live/css/css-color/oklch-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/oklch-005.html)
- [oklch-006.html](https://wpt.fyi/results/css/css-color/oklch-006.html "css/css-color/oklch-006.html")
 [[(live
 test)]](http://wpt.live/css/css-color/oklch-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/oklch-006.html)
- [oklch-007.html](https://wpt.fyi/results/css/css-color/oklch-007.html "css/css-color/oklch-007.html")
 [[(live
 test)]](http://wpt.live/css/css-color/oklch-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/oklch-007.html)
- [oklch-008.html](https://wpt.fyi/results/css/css-color/oklch-008.html "css/css-color/oklch-008.html")
 [[(live
 test)]](http://wpt.live/css/css-color/oklch-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/oklch-008.html)
- [oklch-009.html](https://wpt.fyi/results/css/css-color/oklch-009.html "css/css-color/oklch-009.html")
 [[(live
 test)]](http://wpt.live/css/css-color/oklch-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/oklch-009.html)
- [oklch-010.html](https://wpt.fyi/results/css/css-color/oklch-010.html "css/css-color/oklch-010.html")
 [[(live
 test)]](http://wpt.live/css/css-color/oklch-010.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/oklch-010.html)
- [oklch-011.html](https://wpt.fyi/results/css/css-color/oklch-011.html "css/css-color/oklch-011.html")
 [[(live
 test)]](http://wpt.live/css/css-color/oklch-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/oklch-011.html)
- [oklch-l-almost-0.html](https://wpt.fyi/results/css/css-color/oklch-l-almost-0.html "css/css-color/oklch-l-almost-0.html")
 [[(live
 test)]](http://wpt.live/css/css-color/oklch-l-almost-0.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/oklch-l-almost-0.html)
- [oklch-l-almost-1.html](https://wpt.fyi/results/css/css-color/oklch-l-almost-1.html "css/css-color/oklch-l-almost-1.html")
 [[(live
 test)]](http://wpt.live/css/css-color/oklch-l-almost-1.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/oklch-l-almost-1.html)
- [oklch-l-over-1-1.html](https://wpt.fyi/results/css/css-color/oklch-l-over-1-1.html "css/css-color/oklch-l-over-1-1.html")
 [[(live
 test)]](http://wpt.live/css/css-color/oklch-l-over-1-1.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/oklch-l-over-1-1.html)
- [oklch-l-over-1-2.html](https://wpt.fyi/results/css/css-color/oklch-l-over-1-2.html "css/css-color/oklch-l-over-1-2.html")
 [[(live
 test)]](http://wpt.live/css/css-color/oklch-l-over-1-2.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/oklch-l-over-1-2.html)
- [color-valid.html](https://wpt.fyi/results/css/css-color/parsing/color-valid.html "css/css-color/parsing/color-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-color/parsing/color-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/parsing/color-valid.html)

In [OkLCh] the first argument specifies the OkLCh
Lightness L, interpreted identically to the Lightness argument of
[oklab()](#funcdef-oklab).

The second argument is the chroma C. Its minimum useful value is
[0], while its maximum is theoretically unbounded (but in practice
does not exceed [0.5]). If the provided value is negative, it is
clamped to [0] at parsed-value time.

The third argument is the hue angle H. It's interpreted similarly to the
[\<hue\>](#typedef-hue) arguments of
[hsl()](#funcdef-hsl) and
[lch()](#funcdef-lch), but
doesn't map hues to angles in the same way. [0deg] points along
the positive \"a\" axis (toward purplish red), (as does [360deg],
[720deg], etc.); [90deg] points along the positive \"b\"
axis (toward mustard yellow), [180deg] points along the negative
\"a\" axis (toward greenish cyan), and [270deg] points along the
negative \"b\" axis (toward sky blue).

There is an optional fourth
[\<alpha-value\>](#typedef-color-alpha-value) component, separated by a slash,
representing the [alpha
component](#alpha-channel).

If the chroma of an OkLCh color is [0%] or 0, the hue component is
[powerless](#powerless-color-component). If the lightness of an OkLCh color is [0%] or 0,
or [100%] or 1.0, the color will be displayed as black, or white,
respectively due to gamut mapping to the display.

```
 oklch(40.101% 0.12332 21.555);
 oklch(59.686% 0.15619 49.7694);
 oklch(0.65125 0.13138 104.097);
 oklch(0.66016 0.15546 134.231);
 oklch(72.322% 0.12403 247.996);
 oklch(42.1% 48.25% 328.4)
```

There is no Web compatibility issue with
[oklab](#valdef-oklab-oklab) or
[oklch](#valdef-oklch-oklch)\', which are new in this level of the specification,
and so [oklab()](#funcdef-oklab) and [oklch()](#funcdef-oklch) do *not* support a [legacy color
syntax](#legacy-color-syntax) that separates all of their arguments with commas.
Using commas inside these functions is an error.

### 9.5. Converting Lab or Oklab colors to LCH or OkLCh colors

Conversion to the polar form is trivial:

1. C = sqrt(a\^2 + b\^2)
2. if (C \> epsilon) H = atan2(b, a) else H is missing
3. L is the same

For extremely small values of a and b (near-zero Chroma), although the
visual color does not change from being on the neutral axis, small
changes to the values can result in the reported hue angle swinging
about wildly and being essentially random. In CSS, this means the hue is
[powerless](#powerless-color-component), and treated as
[missing](#missing-color-component) when converted into LCH or OkLCh; in non-CSS contexts
this might be reflected as a missing value, such as NaN.

### 9.6. Converting LCH or OkLCh colors to Lab or Oklab colors

Conversion to the rectangular form is trivial:

1. If H is missing, H = 0
 1. a = C cos(H)
 2. b = C sin(H)
2. L is the same

## 10. Predefined Color Spaces

CSS provides several predefined color spaces including
[display-p3](#valdef-color-display-p3)
[\[Display-P3\]](#biblio-display-p3 "Display P3"),
which is a wide gamut space typical of current wide-gamut monitors,
[prophoto-rgb](#valdef-color-prophoto-rgb), widely used by photographers and
[rec2020](#valdef-color-rec2020)
[\[Rec.2020\]](#biblio-rec2020 "Recommendation ITU-R BT.2020-2: Parameter values for ultra-high definition television systems for production and international programme exchange"),
which is a broadcast industry standard, ultra-wide gamut space capable
of representing almost all visible real-world colors.

### 10.1. Specifying Predefined Colors: the [color() function]
The [color()](#funcdef-color) function allows a color to be specified in a
particular, specified [color space](#color-space) (rather than the implicit sRGB color space that most of
the other color functions operate in). Its syntax is:

```
color() = color( <colorspace-params> [ / [ <alpha-value> | none ] ]? )
<colorspace-params> = [ <predefined-rgb-params> | <xyz-params>]
<predefined-rgb-params> = <predefined-rgb> [ <number> | <percentage> | none ]{3}
<predefined-rgb> = srgb | srgb-linear | display-p3 | display-p3-linear | a98-rgb | prophoto-rgb | rec2020
<xyz-params> = <xyz-space> [ <number> | <percentage> | none ]{3}
<xyz-space> = xyz | xyz-d50 | xyz-d65
```

Tests

- [color-computed-color-function.html](https://wpt.fyi/results/css/css-color/parsing/color-computed-color-function.html "css/css-color/parsing/color-computed-color-function.html")
 [[(live
 test)]](http://wpt.live/css/css-color/parsing/color-computed-color-function.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/parsing/color-computed-color-function.html)
- [color-invalid-color-function.html](https://wpt.fyi/results/css/css-color/parsing/color-invalid-color-function.html "css/css-color/parsing/color-invalid-color-function.html")
 [[(live
 test)]](http://wpt.live/css/css-color/parsing/color-invalid-color-function.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/parsing/color-invalid-color-function.html)
- [color-valid-color-function.html](https://wpt.fyi/results/css/css-color/parsing/color-valid-color-function.html "css/css-color/parsing/color-valid-color-function.html")
 [[(live
 test)]](http://wpt.live/css/css-color/parsing/color-valid-color-function.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/parsing/color-valid-color-function.html)

The color function takes parameters specifying a color, in an explicitly
listed color space.

It represents either an [invalid
color](#invalid-color), as
described below, or a [valid color](#valid-color).

The parameters have the following form:

- An
 [\<ident\>](https://drafts.csswg.org/css-values-4/#typedef-ident) denoting one of the [predefined
 color spaces](#predefined) (such as
 [display-p3](#valdef-color-display-p3)) Individual [predefined color
 spaces](#predefined) may further restrict whether
 [\<number\>](https://drafts.csswg.org/css-values-4/#number-value)s or
 [\<percentage\>](https://drafts.csswg.org/css-values-4/#percentage-value)s or both, may be used.

 If the
 [\<ident\>](https://drafts.csswg.org/css-values-4/#typedef-ident) names a non-existent color space (a
 name that does not match one of the [predefined color
 spaces](#predefined)), this argument represents an [invalid
 color](#invalid-color).

- The three parameter values that the color space takes (RGB or XYZ
 values).

An out of gamut color has component values less than 0 or 0%, or greater
than 1 or 100%. These are not invalid, and are retained for intermediate
computations; instead, for display, they are [css gamut
mapped](#css-gamut-mapped)
using a relative colorimetric intent which brings the values (in the
display color space) within the range 0/0% to 1/100% at actual-value
time.

- An optional slash-separated
 [\<alpha-value\>](#typedef-color-alpha-value).

Tests

- [color-valid.html](https://wpt.fyi/results/css/css-color/parsing/color-valid.html "css/css-color/parsing/color-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-color/parsing/color-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/parsing/color-valid.html)

There is no Web compatibility issue with
[color()](#funcdef-color), which is new in this level of the specification, and
so [color()] does *not* support a [legacy
color syntax](#legacy-color-syntax) that separates all of its arguments with commas. Using
commas inside this function is an error.

A color which is either an [invalid
color](#invalid-color) or an
[out of gamut](#out-of-gamut)
color [can't be displayed].

If the specified color [can be displayed], (that is, it isn't an [invalid
color](#invalid-color) and
isn't [out of gamut](#out-of-gamut)) then this is the actual value of the
[color()](#funcdef-color) function.

If the specified color is a [valid
color](#valid-color) but [can't
be displayed](#cant-be-displayed), the actual value is derived from the specified color,
[css gamut mapped](#css-gamut-mapped) for display.

If the color is an [invalid
color](#invalid-color), the
used value is [opaque black](#opaque-black).

This very intense lime color is in-gamut
for rec.2020:

```
color(rec2020 0.42053 0.979780 0.00579);
```

in LCH, that color is

```
lch(85.9017% 166.116 138.207);
```

in display-p3, that color is

```
color(display-p3 -0.350289 1.00707 -0.144209);
```

and is out of gamut for display-p3 (red and blue are negative, green is
greater than 1). If you have a display-p3 screen, that color is:

- *valid*
- *in gamut* (for rec.2020)
- *out of gamut* (for your display)
- and so *can't be displayed*

The color used for display will be a less intense color produced
automatically by gamut mapping.

This example has a typo! An intense
green is provided in profoto-rgb space (which doesn't exist). This makes
it invalid, so the used value is [opaque
black](#opaque-black)

```
color(profoto-rgb 0.4835 0.9167 0.2188)
```

### 10.2. The Predefined sRGB Color Space: the [sRGB keyword]
The [sRGB]
predefined color space defined below is the same as is used for legacy
sRGB colors, such as [rgb()](#funcdef-rgb).

[srgb]

: The [srgb](#valdef-color-srgb)
 [\[SRGB\]](#biblio-srgb "Multimedia systems and equipment - Colour measurement and management - Part 2-1: Colour management - Default RGB colour space - sRGB")
 color space accepts three numeric parameters, representing the red,
 green, and blue components of the color. In-gamut colors have all
 three components in the range \[0, 1\]. The whitepoint is
 [D65](#d65).

 [\[SRGB\]](#biblio-srgb "Multimedia systems and equipment - Colour measurement and management - Part 2-1: Colour management - Default RGB colour space - sRGB")
 specifies two viewing conditions, *encoding* and *typical*. The
 [\[ICC\]](#biblio-icc "ICC.1:2022 (Profile version 4.4.0.0)")
 recommends using the *encoding* conditions for color conversion and
 for optimal viewing, which are the values in the table below.

 sRGB is the default color space for CSS, used for all the legacy
 color functions.

 It has the following characteristics:

 x

 y

 Red chromaticity

 0.640

 0.330

 Green chromaticity

 0.300

 0.600

 Blue chromaticity

 0.150

 0.060

 White chromaticity

 [D65](#d65)

 Transfer function

 see below

 White luminance

 80.0 cd/m^2^

 Black luminance

 0.20 cd/m^2^

 Image state

 display-referred

 Percentages

 Allowed for R, G and B

 Percent reference range 

 for R,G,B: 0% = 0.0, 100% = 1.0

 ```
 let sign = c < 0? -1 : 1;
 let abs = Math.abs(c);

 if (abs <= 0.04045) {
 cl = c / 12.92;
 }
 else {
 cl = sign * (Math.pow((abs + 0.055) / 1.055, 2.4));
 }
 ```

 c is the gamma-encoded red, green or blue component. cl is the
 corresponding linear-light component.

 ![Visualization of the sRGB color space in Oklch. The primaries and
 secondaries are
 shown.](images/sRGB-prim-sec-oklch.svg)

Tests

- [predefined-001.html](https://wpt.fyi/results/css/css-color/predefined-001.html "css/css-color/predefined-001.html")
 [[(live
 test)]](http://wpt.live/css/css-color/predefined-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/predefined-001.html)
- [predefined-002.html](https://wpt.fyi/results/css/css-color/predefined-002.html "css/css-color/predefined-002.html")
 [[(live
 test)]](http://wpt.live/css/css-color/predefined-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/predefined-002.html)
- [color-valid.html](https://wpt.fyi/results/css/css-color/parsing/color-valid.html "css/css-color/parsing/color-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-color/parsing/color-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/parsing/color-valid.html)

<!-- -->

- [2d.color.type.u8p3.to.f16srgb.to.u8p3.html](https://wpt.fyi/results/html/canvas/element/color-type/2d.color.type.u8p3.to.f16srgb.to.u8p3.html "html/canvas/element/color-type/2d.color.type.u8p3.to.f16srgb.to.u8p3.html")
 [[(live
 test)]](http://wpt.live/html/canvas/element/color-type/2d.color.type.u8p3.to.f16srgb.to.u8p3.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/html/canvas/element/color-type/2d.color.type.u8p3.to.f16srgb.to.u8p3.html)
- [2d.color.type.u8p3.to.u8srgb.to.u8p3.html](https://wpt.fyi/results/html/canvas/element/color-type/2d.color.type.u8p3.to.u8srgb.to.u8p3.html "html/canvas/element/color-type/2d.color.type.u8p3.to.u8srgb.to.u8p3.html")
 [[(live
 test)]](http://wpt.live/html/canvas/element/color-type/2d.color.type.u8p3.to.u8srgb.to.u8p3.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/html/canvas/element/color-type/2d.color.type.u8p3.to.u8srgb.to.u8p3.html)
- [2d.color.type.u8srgb.to.f16p3.to.u8srgb.html](https://wpt.fyi/results/html/canvas/element/color-type/2d.color.type.u8srgb.to.f16p3.to.u8srgb.html "html/canvas/element/color-type/2d.color.type.u8srgb.to.f16p3.to.u8srgb.html")
 [[(live
 test)]](http://wpt.live/html/canvas/element/color-type/2d.color.type.u8srgb.to.f16p3.to.u8srgb.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/html/canvas/element/color-type/2d.color.type.u8srgb.to.f16p3.to.u8srgb.html)
- [2d.color.type.u8srgb.to.u8p3.to.u8srgb.html](https://wpt.fyi/results/html/canvas/element/color-type/2d.color.type.u8srgb.to.u8p3.to.u8srgb.html "html/canvas/element/color-type/2d.color.type.u8srgb.to.u8p3.to.u8srgb.html")
 [[(live
 test)]](http://wpt.live/html/canvas/element/color-type/2d.color.type.u8srgb.to.u8p3.to.u8srgb.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/html/canvas/element/color-type/2d.color.type.u8srgb.to.u8p3.to.u8srgb.html)

### 10.3. The Predefined Linear-Light sRGB Color Space: the [srgb-linear keyword]
The [sRGB-linear] predefined color space is the same as
[srgb](#valdef-color-srgb) *except* that the transfer function is linear-light
(there is no gamma-encoding).

[srgb-linear]

: The
 [srgb-linear](#valdef-color-srgb-linear)
 [\[SRGB\]](#biblio-srgb "Multimedia systems and equipment - Colour measurement and management - Part 2-1: Colour management - Default RGB colour space - sRGB")
 color space accepts three numeric parameters, representing the red,
 green, and blue components of the color. In-gamut colors have all
 three components in the range \[0, 1\]. The whitepoint is
 [D65](#d65).

 It has the following characteristics:

 x

 y

 Red chromaticity

 0.640

 0.330

 Green chromaticity

 0.300

 0.600

 Blue chromaticity

 0.150

 0.060

 White chromaticity

 [D65](#d65)

 Transfer function

 unity, see below

 White luminance

 80.0 cd/m^2^

 Black luminance

 0.20 cd/m^2^

 Image state

 display-referred

 Percentages

 Allowed for R, G and B

 Percent reference range 

 for R,G,B: 0% = 0.0, 100% = 1.0

 ```
 cl = c;
 ```

 c is the red, green or blue component. cl is the corresponding
 linear-light component, which is identical.

 To avoid banding artifacts, a [higher precision is
 required](#predefined-precision-table) for
 [srgb-linear](#valdef-color-srgb-linear) than for
 [srgb](#valdef-color-srgb).

 :::
 (#srgb-linear-swatches) For example, these are the
 same color
 ```
 color(srgb 0.691 0.139 0.259)
 color(srgb-linear 0.435 0.017 0.055)
 ```
 :::

Tests

- [srgb-linear-001.html](https://wpt.fyi/results/css/css-color/srgb-linear-001.html "css/css-color/srgb-linear-001.html")
 [[(live
 test)]](http://wpt.live/css/css-color/srgb-linear-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/srgb-linear-001.html)
- [srgb-linear-002.html](https://wpt.fyi/results/css/css-color/srgb-linear-002.html "css/css-color/srgb-linear-002.html")
 [[(live
 test)]](http://wpt.live/css/css-color/srgb-linear-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/srgb-linear-002.html)
- [srgb-linear-003.html](https://wpt.fyi/results/css/css-color/srgb-linear-003.html "css/css-color/srgb-linear-003.html")
 [[(live
 test)]](http://wpt.live/css/css-color/srgb-linear-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/srgb-linear-003.html)
- [srgb-linear-004.html](https://wpt.fyi/results/css/css-color/srgb-linear-004.html "css/css-color/srgb-linear-004.html")
 [[(live
 test)]](http://wpt.live/css/css-color/srgb-linear-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/srgb-linear-004.html)
- [color-valid.html](https://wpt.fyi/results/css/css-color/parsing/color-valid.html "css/css-color/parsing/color-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-color/parsing/color-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/parsing/color-valid.html)

<!-- -->

- [2d.color.type.u8p3.to.f16srgb.to.u8p3.html](https://wpt.fyi/results/html/canvas/element/color-type/2d.color.type.u8p3.to.f16srgb.to.u8p3.html "html/canvas/element/color-type/2d.color.type.u8p3.to.f16srgb.to.u8p3.html")
 [[(live
 test)]](http://wpt.live/html/canvas/element/color-type/2d.color.type.u8p3.to.f16srgb.to.u8p3.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/html/canvas/element/color-type/2d.color.type.u8p3.to.f16srgb.to.u8p3.html)
- [2d.color.type.u8p3.to.u8srgb.to.u8p3.html](https://wpt.fyi/results/html/canvas/element/color-type/2d.color.type.u8p3.to.u8srgb.to.u8p3.html "html/canvas/element/color-type/2d.color.type.u8p3.to.u8srgb.to.u8p3.html")
 [[(live
 test)]](http://wpt.live/html/canvas/element/color-type/2d.color.type.u8p3.to.u8srgb.to.u8p3.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/html/canvas/element/color-type/2d.color.type.u8p3.to.u8srgb.to.u8p3.html)
- [2d.color.type.u8srgb.to.f16p3.to.u8srgb.html](https://wpt.fyi/results/html/canvas/element/color-type/2d.color.type.u8srgb.to.f16p3.to.u8srgb.html "html/canvas/element/color-type/2d.color.type.u8srgb.to.f16p3.to.u8srgb.html")
 [[(live
 test)]](http://wpt.live/html/canvas/element/color-type/2d.color.type.u8srgb.to.f16p3.to.u8srgb.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/html/canvas/element/color-type/2d.color.type.u8srgb.to.f16p3.to.u8srgb.html)
- [2d.color.type.u8srgb.to.u8p3.to.u8srgb.html](https://wpt.fyi/results/html/canvas/element/color-type/2d.color.type.u8srgb.to.u8p3.to.u8srgb.html "html/canvas/element/color-type/2d.color.type.u8srgb.to.u8p3.to.u8srgb.html")
 [[(live
 test)]](http://wpt.live/html/canvas/element/color-type/2d.color.type.u8srgb.to.u8p3.to.u8srgb.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/html/canvas/element/color-type/2d.color.type.u8srgb.to.u8p3.to.u8srgb.html)

### 10.4. The Predefined Display P3 Color Space: the [display-p3 keyword]
[display-p3]

: The
 [display-p3](#valdef-color-display-p3)
 [\[Display-P3\]](#biblio-display-p3 "Display P3")
 color space accepts three numeric parameters, representing the red,
 green, and blue components of the color. In-gamut colors have all
 three components in the range \[0, 1\]. It uses the same primary
 chromaticities as
 [\[DCI-P3\]](#biblio-dci-p3 "SMPTE Recommended Practice - D-Cinema Quality — Reference Projector and Environment"),
 but with a [D65](#d65) whitepoint,
 and the same transfer curve as sRGB.

 Modern displays, TVs, laptop screens and phone screens are able to
 display all, or nearly all, of the display-p3 gamut.

 It has the following characteristics:

 x

 y

 Red chromaticity

 0.680

 0.320

 Green chromaticity

 0.265

 0.690

 Blue chromaticity

 0.150

 0.060

 White chromaticity

 [D65](#d65)

 Transfer function

 same as srgb

 White luminance

 80.0 cd/m^2^

 Black luminance

 0.80 cd/m^2^

 Image state

 display-referred

 Percentages

 Allowed for R, G and B

 Percent reference range 

 for R,G,B: 0% = 0.0, 100% = 1.0

 ![Visualization of the P3 color space in Oklch. The primaries and
 secondaries are shown (but in sRGB, not in the correct colors). For
 comparison, the sRGB primaries and secondaries are also shown, as
 dashed circles. P3 primaries have higher
 Chroma.](images/P3-prim-sec-oklch.svg)

Tests

- [predefined-005.html](https://wpt.fyi/results/css/css-color/predefined-005.html "css/css-color/predefined-005.html")
 [[(live
 test)]](http://wpt.live/css/css-color/predefined-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/predefined-005.html)
- [predefined-006.html](https://wpt.fyi/results/css/css-color/predefined-006.html "css/css-color/predefined-006.html")
 [[(live
 test)]](http://wpt.live/css/css-color/predefined-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/predefined-006.html)
- [display-p3-001.html](https://wpt.fyi/results/css/css-color/display-p3-001.html "css/css-color/display-p3-001.html")
 [[(live
 test)]](http://wpt.live/css/css-color/display-p3-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/display-p3-001.html)
- [display-p3-002.html](https://wpt.fyi/results/css/css-color/display-p3-002.html "css/css-color/display-p3-002.html")
 [[(live
 test)]](http://wpt.live/css/css-color/display-p3-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/display-p3-002.html)
- [display-p3-003.html](https://wpt.fyi/results/css/css-color/display-p3-003.html "css/css-color/display-p3-003.html")
 [[(live
 test)]](http://wpt.live/css/css-color/display-p3-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/display-p3-003.html)
- [display-p3-004.html](https://wpt.fyi/results/css/css-color/display-p3-004.html "css/css-color/display-p3-004.html")
 [[(live
 test)]](http://wpt.live/css/css-color/display-p3-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/display-p3-004.html)
- [display-p3-005.html](https://wpt.fyi/results/css/css-color/display-p3-005.html "css/css-color/display-p3-005.html")
 [[(live
 test)]](http://wpt.live/css/css-color/display-p3-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/display-p3-005.html)
- [display-p3-006.html](https://wpt.fyi/results/css/css-color/display-p3-006.html "css/css-color/display-p3-006.html")
 [[(live
 test)]](http://wpt.live/css/css-color/display-p3-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/display-p3-006.html)

<!-- -->

- [2d.color.type.u8p3.to.f16srgb.to.u8p3.html](https://wpt.fyi/results/html/canvas/element/color-type/2d.color.type.u8p3.to.f16srgb.to.u8p3.html "html/canvas/element/color-type/2d.color.type.u8p3.to.f16srgb.to.u8p3.html")
 [[(live
 test)]](http://wpt.live/html/canvas/element/color-type/2d.color.type.u8p3.to.f16srgb.to.u8p3.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/html/canvas/element/color-type/2d.color.type.u8p3.to.f16srgb.to.u8p3.html)
- [2d.color.type.u8p3.to.u8srgb.to.u8p3.html](https://wpt.fyi/results/html/canvas/element/color-type/2d.color.type.u8p3.to.u8srgb.to.u8p3.html "html/canvas/element/color-type/2d.color.type.u8p3.to.u8srgb.to.u8p3.html")
 [[(live
 test)]](http://wpt.live/html/canvas/element/color-type/2d.color.type.u8p3.to.u8srgb.to.u8p3.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/html/canvas/element/color-type/2d.color.type.u8p3.to.u8srgb.to.u8p3.html)
- [2d.color.type.u8srgb.to.f16p3.to.u8srgb.html](https://wpt.fyi/results/html/canvas/element/color-type/2d.color.type.u8srgb.to.f16p3.to.u8srgb.html "html/canvas/element/color-type/2d.color.type.u8srgb.to.f16p3.to.u8srgb.html")
 [[(live
 test)]](http://wpt.live/html/canvas/element/color-type/2d.color.type.u8srgb.to.f16p3.to.u8srgb.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/html/canvas/element/color-type/2d.color.type.u8srgb.to.f16p3.to.u8srgb.html)
- [2d.color.type.u8srgb.to.u8p3.to.u8srgb.html](https://wpt.fyi/results/html/canvas/element/color-type/2d.color.type.u8srgb.to.u8p3.to.u8srgb.html "html/canvas/element/color-type/2d.color.type.u8srgb.to.u8p3.to.u8srgb.html")
 [[(live
 test)]](http://wpt.live/html/canvas/element/color-type/2d.color.type.u8srgb.to.u8p3.to.u8srgb.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/html/canvas/element/color-type/2d.color.type.u8srgb.to.u8p3.to.u8srgb.html)

### 10.5. The Predefined Linear-Light Display P3 Color Space: the [display-p3-linear keyword]
[display-p3-linear]

: The
 [display-p3-linear](#valdef-color-display-p3-linear) predefined color space is the same as
 [display-p3](#valdef-color-display-p3) *except* that the transfer function is
 linear-light (there is no gamma-encoding).

 It has the following characteristics:

 x

 y

 Red chromaticity

 0.680

 0.320

 Green chromaticity

 0.265

 0.690

 Blue chromaticity

 0.150

 0.060

 White chromaticity

 [D65](#d65)

 Transfer function

 unity, see below

 White luminance

 80.0 cd/m^2^

 Black luminance

 0.80 cd/m^2^

 Image state

 display-referred

 Percentages

 Allowed for R, G and B

 Percent reference range 

 for R,G,B: 0% = 0.0, 100% = 1.0

 ```
 cl = c;
 ```

 c is the red, green or blue component. cl is the corresponding
 linear-light component, which is identical.

 To avoid banding artifacts, a [higher precision is
 required](#predefined-precision-table) for
 [display-p3-linear](#valdef-color-display-p3-linear) than for
 [display-p3](#valdef-color-display-p3).

 :::
 (#display-p3-linear-swatches) For example, these are
 the same color
 ```
 color(display-p3 0.591 0.123 0.264)
 color(display-p3-linear 0.3081 0.014 0.0567)
 ```
 :::

Tests

- [display-p3-linear-001.html](https://wpt.fyi/results/css/css-color/display-p3-linear-001.html "css/css-color/display-p3-linear-001.html")
 [[(live
 test)]](http://wpt.live/css/css-color/display-p3-linear-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/display-p3-linear-001.html)
- [display-p3-linear-002.html](https://wpt.fyi/results/css/css-color/display-p3-linear-002.html "css/css-color/display-p3-linear-002.html")
 [[(live
 test)]](http://wpt.live/css/css-color/display-p3-linear-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/display-p3-linear-002.html)
- [display-p3-linear-003.html](https://wpt.fyi/results/css/css-color/display-p3-linear-003.html "css/css-color/display-p3-linear-003.html")
 [[(live
 test)]](http://wpt.live/css/css-color/display-p3-linear-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/display-p3-linear-003.html)
- [display-p3-linear-004.html](https://wpt.fyi/results/css/css-color/display-p3-linear-004.html "css/css-color/display-p3-linear-004.html")
 [[(live
 test)]](http://wpt.live/css/css-color/display-p3-linear-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/display-p3-linear-004.html)
- [display-p3-linear-005.html](https://wpt.fyi/results/css/css-color/display-p3-linear-005.html "css/css-color/display-p3-linear-005.html")
 [[(live
 test)]](http://wpt.live/css/css-color/display-p3-linear-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/display-p3-linear-005.html)
- [display-p3-linear-006.html](https://wpt.fyi/results/css/css-color/display-p3-linear-006.html "css/css-color/display-p3-linear-006.html")
 [[(live
 test)]](http://wpt.live/css/css-color/display-p3-linear-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/display-p3-linear-006.html)

<!-- -->

- [2d.color.type.u8p3.to.f16srgb.to.u8p3.html](https://wpt.fyi/results/html/canvas/element/color-type/2d.color.type.u8p3.to.f16srgb.to.u8p3.html "html/canvas/element/color-type/2d.color.type.u8p3.to.f16srgb.to.u8p3.html")
 [[(live
 test)]](http://wpt.live/html/canvas/element/color-type/2d.color.type.u8p3.to.f16srgb.to.u8p3.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/html/canvas/element/color-type/2d.color.type.u8p3.to.f16srgb.to.u8p3.html)
- [2d.color.type.u8p3.to.u8srgb.to.u8p3.html](https://wpt.fyi/results/html/canvas/element/color-type/2d.color.type.u8p3.to.u8srgb.to.u8p3.html "html/canvas/element/color-type/2d.color.type.u8p3.to.u8srgb.to.u8p3.html")
 [[(live
 test)]](http://wpt.live/html/canvas/element/color-type/2d.color.type.u8p3.to.u8srgb.to.u8p3.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/html/canvas/element/color-type/2d.color.type.u8p3.to.u8srgb.to.u8p3.html)
- [2d.color.type.u8srgb.to.f16p3.to.u8srgb.html](https://wpt.fyi/results/html/canvas/element/color-type/2d.color.type.u8srgb.to.f16p3.to.u8srgb.html "html/canvas/element/color-type/2d.color.type.u8srgb.to.f16p3.to.u8srgb.html")
 [[(live
 test)]](http://wpt.live/html/canvas/element/color-type/2d.color.type.u8srgb.to.f16p3.to.u8srgb.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/html/canvas/element/color-type/2d.color.type.u8srgb.to.f16p3.to.u8srgb.html)
- [2d.color.type.u8srgb.to.u8p3.to.u8srgb.html](https://wpt.fyi/results/html/canvas/element/color-type/2d.color.type.u8srgb.to.u8p3.to.u8srgb.html "html/canvas/element/color-type/2d.color.type.u8srgb.to.u8p3.to.u8srgb.html")
 [[(live
 test)]](http://wpt.live/html/canvas/element/color-type/2d.color.type.u8srgb.to.u8p3.to.u8srgb.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/html/canvas/element/color-type/2d.color.type.u8srgb.to.u8p3.to.u8srgb.html)

### 10.6. The Predefined A98 RGB Color Space: the [a98-rgb keyword]
[a98-rgb]

: The [a98-rgb](#valdef-color-a98-rgb) color space accepts three numeric
 parameters, representing the red, green, and blue components of the
 color. In-gamut colors have all three components in the range \[0,
 1\]. The transfer curve is a gamma function, close to but not
 exactly 1/2.2.

 It has the following characteristics:

 x

 y

 Red chromaticity

 0.6400

 0.3300

 Green chromaticity

 0.2100

 0.7100

 Blue chromaticity

 0.1500

 0.0600

 White chromaticity

 [D65](#d65)

 Transfer function

 256/563

 White luminance

 160.0 cd/m^2^

 Black luminance

 0.5557 cd/m^2^

 Image state

 display-referred

 Percentages

 Allowed for R, G and B

 Percent reference range 

 for R,G,B: 0% = 0.0, 100% = 1.0

 ![Visualization of the A98 color space in Oklch. The primaries and
 secondaries are shown (but in sRGB, not in the correct colors). For
 comparison, the sRGB primaries and secondaries are also shown, as
 dashed circles. a98 primaries have higher Chroma, especially the
 yellow, green and
 cyan.](images/a98-prim-sec-oklch.svg)

Tests

- [predefined-007.html](https://wpt.fyi/results/css/css-color/predefined-007.html "css/css-color/predefined-007.html")
 [[(live
 test)]](http://wpt.live/css/css-color/predefined-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/predefined-007.html)
- [predefined-008.html](https://wpt.fyi/results/css/css-color/predefined-008.html "css/css-color/predefined-008.html")
 [[(live
 test)]](http://wpt.live/css/css-color/predefined-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/predefined-008.html)
- [a98rgb-001.html](https://wpt.fyi/results/css/css-color/a98rgb-001.html "css/css-color/a98rgb-001.html")
 [[(live
 test)]](http://wpt.live/css/css-color/a98rgb-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/a98rgb-001.html)
- [a98rgb-002.html](https://wpt.fyi/results/css/css-color/a98rgb-002.html "css/css-color/a98rgb-002.html")
 [[(live
 test)]](http://wpt.live/css/css-color/a98rgb-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/a98rgb-002.html)
- [a98rgb-003.html](https://wpt.fyi/results/css/css-color/a98rgb-003.html "css/css-color/a98rgb-003.html")
 [[(live
 test)]](http://wpt.live/css/css-color/a98rgb-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/a98rgb-003.html)
- [a98rgb-004.html](https://wpt.fyi/results/css/css-color/a98rgb-004.html "css/css-color/a98rgb-004.html")
 [[(live
 test)]](http://wpt.live/css/css-color/a98rgb-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/a98rgb-004.html)
- [color-valid.html](https://wpt.fyi/results/css/css-color/parsing/color-valid.html "css/css-color/parsing/color-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-color/parsing/color-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/parsing/color-valid.html)

### 10.7. The Predefined ProPhoto RGB Color Space: the [prophoto-rgb keyword]
[prophoto-rgb]

: The
 [prophoto-rgb](#valdef-color-prophoto-rgb) color space accepts three numeric
 parameters, representing the red, green, and blue components of the
 color. In-gamut colors have all three components in the range \[0,
 1\]. The transfer curve is a gamma function with a value of 1/1.8,
 and a small linear portion near black. The white point is
 [D50](#d50), the same as is used by
 CIE Lab. Thus, conversion to CIE Lab does not require the chromatic
 adaptation step.

 The ProPhoto RGB space uses hyper-saturated, non physically
 realizable primaries. These were chosen to allow a wide color gamut
 and in particular, to minimize hue shifts under tonal manipulation.
 It is often used in digital photography as a wide gamut color space
 for the archival version of photographic images. The
 [prophoto-rgb](#valdef-color-prophoto-rgb) color space allows CSS to specify colors
 that will match colors in such images having the same RGB values.

 The ProPhoto RGB space was originally developed by Kodak and is
 described in
 [\[Wolfe\]](#biblio-wolfe "Design and Optimization of the ProPhoto RGB Color Encodings").
 It was standardized by ISO as
 [\[ROMM\]](#biblio-romm "ISO 22028-2:2013 Photography and graphic technology — Extended colour encodings for digital image storage, manipulation and interchange — Part 2: Reference output medium metric RGB colour image encoding (ROMM RGB)"),[\[ROMM-RGB\]](#biblio-romm-rgb "ROMM RGB").

 The white luminance is given as a range, and the viewing flare (and
 thus, the black luminance) is 0.5% to 1.0% of this.

 It has the following characteristics:

 x

 y

 Red chromaticity

 0.734699

 0.265301

 Green chromaticity

 0.159597

 0.840403

 Blue chromaticity

 0.036598

 0.000105

 White chromaticity

 [D50](#d50)

 Transfer function

 see below

 White luminance

 160.0 to 640.0 cd/m^2^

 Black luminance

 See text

 Image state

 display-referred

 Percentages

 Allowed for R, G and B

 Percent reference range 

 for R,G,B: 0% = 0.0, 100% = 1.0

 ```
 const E = 16/512;
 let sign = c < 0? -1 : 1;
 let abs = Math.abs(c);

 if (abs <= E) {
 cl = c / 16;
 }
 else {
 cl = sign * Math.pow(c, 1.8);
 }
 ```

 c is the gamma-encoded red, green or blue component. cl is the
 corresponding linear-light component.

 ![Visualization of the prophoto-rgb color space in Oklch. The
 primaries and secondaries are shown (but in sRGB, not in the correct
 colors). For comparison, the sRGB primaries and secondaries are also
 shown, as dashed circles. prophoto-rgb primaries and secondaries
 have much higher Chroma, but much of this ultrawide gamut does not
 correspond to physically realizable
 colors.](images/prophoto-prim-sec-oklch.svg)

Tests

- [predefined-009.html](https://wpt.fyi/results/css/css-color/predefined-009.html "css/css-color/predefined-009.html")
 [[(live
 test)]](http://wpt.live/css/css-color/predefined-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/predefined-009.html)
- [predefined-010.html](https://wpt.fyi/results/css/css-color/predefined-010.html "css/css-color/predefined-010.html")
 [[(live
 test)]](http://wpt.live/css/css-color/predefined-010.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/predefined-010.html)
- [prophoto-rgb-001.html](https://wpt.fyi/results/css/css-color/prophoto-rgb-001.html "css/css-color/prophoto-rgb-001.html")
 [[(live
 test)]](http://wpt.live/css/css-color/prophoto-rgb-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/prophoto-rgb-001.html)
- [prophoto-rgb-002.html](https://wpt.fyi/results/css/css-color/prophoto-rgb-002.html "css/css-color/prophoto-rgb-002.html")
 [[(live
 test)]](http://wpt.live/css/css-color/prophoto-rgb-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/prophoto-rgb-002.html)
- [prophoto-rgb-003.html](https://wpt.fyi/results/css/css-color/prophoto-rgb-003.html "css/css-color/prophoto-rgb-003.html")
 [[(live
 test)]](http://wpt.live/css/css-color/prophoto-rgb-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/prophoto-rgb-003.html)
- [prophoto-rgb-004.html](https://wpt.fyi/results/css/css-color/prophoto-rgb-004.html "css/css-color/prophoto-rgb-004.html")
 [[(live
 test)]](http://wpt.live/css/css-color/prophoto-rgb-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/prophoto-rgb-004.html)
- [prophoto-rgb-005.html](https://wpt.fyi/results/css/css-color/prophoto-rgb-005.html "css/css-color/prophoto-rgb-005.html")
 [[(live
 test)]](http://wpt.live/css/css-color/prophoto-rgb-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/prophoto-rgb-005.html)
- [color-valid.html](https://wpt.fyi/results/css/css-color/parsing/color-valid.html "css/css-color/parsing/color-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-color/parsing/color-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/parsing/color-valid.html)

### 10.8. The Predefined ITU-R BT.2020-2 Color Space: the [rec2020 keyword]
[rec2020]

: The [rec2020](#valdef-color-rec2020)
 [\[Rec.2020\]](#biblio-rec2020 "Recommendation ITU-R BT.2020-2: Parameter values for ultra-high definition television systems for production and international programme exchange")
 color space accepts three numeric parameters, representing the red,
 green, and blue components of the color. In-gamut colors have all
 three components in the range \[0, 1\], (\"full-range\", in video
 terminology). ITU Reference 2020 is used for Ultra High Definition,
 4k and 8k television.

 The primaries are physically realizable, but with difficulty as they
 lie very close to the spectral locus.

 Current displays are unable to reproduce the full gamut of rec2020.
 Coverage is expected to increase over time as displays improve.

 It has the following characteristics:

 x

 y

 Red chromaticity

 0.708

 0.292

 Green chromaticity

 0.170

 0.797

 Blue chromaticity

 0.131

 0.046

 White chromaticity

 [D65](#d65)

 Transfer function

 gamma 2.40, from
 [\[REC_BT.1886\]](#biblio-rec_bt1886 "ITU-R BT.1886 Reference electro-optical transfer function for flat panel displays used in HDTV studio production")

 Image state

 display-referred

 Percentages

 Allowed for R, G and B

 Percent reference range 

 for R,G,B: 0% = 0.0, 100% = 1.0

 ![Visualization of the rec2020 color space in Oklch. The primaries
 and secondaries are shown (but in sRGB, not in the correct colors).
 For comparison, the sRGB primaries and secondaries are also shown,
 as dashed circles. rec2020 primaries have much higher
 Chroma.](images/2020-prim-sec-oklch.svg)

Tests

- [predefined-011.html](https://wpt.fyi/results/css/css-color/predefined-011.html "css/css-color/predefined-011.html")
 [[(live
 test)]](http://wpt.live/css/css-color/predefined-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/predefined-011.html)
- [predefined-012.html](https://wpt.fyi/results/css/css-color/predefined-012.html "css/css-color/predefined-012.html")
 [[(live
 test)]](http://wpt.live/css/css-color/predefined-012.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/predefined-012.html)
- [rec2020-001.html](https://wpt.fyi/results/css/css-color/rec2020-001.html "css/css-color/rec2020-001.html")
 [[(live
 test)]](http://wpt.live/css/css-color/rec2020-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/rec2020-001.html)
- [rec2020-002.html](https://wpt.fyi/results/css/css-color/rec2020-002.html "css/css-color/rec2020-002.html")
 [[(live
 test)]](http://wpt.live/css/css-color/rec2020-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/rec2020-002.html)
- [rec2020-003.html](https://wpt.fyi/results/css/css-color/rec2020-003.html "css/css-color/rec2020-003.html")
 [[(live
 test)]](http://wpt.live/css/css-color/rec2020-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/rec2020-003.html)
- [rec2020-004.html](https://wpt.fyi/results/css/css-color/rec2020-004.html "css/css-color/rec2020-004.html")
 [[(live
 test)]](http://wpt.live/css/css-color/rec2020-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/rec2020-004.html)
- [rec2020-005.html](https://wpt.fyi/results/css/css-color/rec2020-005.html "css/css-color/rec2020-005.html")
 [[(live
 test)]](http://wpt.live/css/css-color/rec2020-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/rec2020-005.html)
- [color-valid.html](https://wpt.fyi/results/css/css-color/parsing/color-valid.html "css/css-color/parsing/color-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-color/parsing/color-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/parsing/color-valid.html)

### 10.9. The Predefined CIE XYZ Color Spaces: the [xyz-d50, [xyz-d65](#valdef-color-xyz-d65), and [xyz](#valdef-color-xyz) keywords]
[xyz-d50], [xyz-d65], [xyz]

: The [xyz](#valdef-color-xyz) color space accepts three numeric parameters,
 representing the X,Y and Z values. It represents the CIE XYZ
 [\[COLORIMETRY\]](#biblio-colorimetry "Colorimetry, Fourth Edition. CIE 015:2018")
 color space, scaled such that diffuse white has a
 [luminance](#luminance) (Y) of
 1.0. and, if necessary, chromatically adapted to the reference
 white.

 The reference white for
 [xyz-d50](#valdef-color-xyz-d50) is [D50](#d50),
 while the reference white for
 [xyz-d65](#valdef-color-xyz-d65) and
 [xyz](#valdef-color-xyz) is [D65](#d65).

 Values greater than 1.0/100% are allowed and must not be clamped;
 colors where Y is greater than 1.0 represent colors brighter than
 diffuse white. Values less than 0/0% are uncommon, but can occur as
 a result of chromatic adaptation, and likewise must not be clamped.

 It has the following characteristics:

 Percentages

 Allowed for X,Y,Z

 Percent reference range 

 for X,Y,Z: 0% = 0.0, 100% = 1.0

 :::
 (#ex-xyz) These are exactly equivalent:
 ```
 #7654CD
 rgb(46.27% 32.94% 80.39%)
 lab(44.36% 36.05 -58.99)
 color(xyz-d50 0.2005 0.14089 0.4472)
 color(xyz-d65 0.21661 0.14602 0.59452)
 ```
 :::

 :::
 (#ex-xyz-white) These colors are exactly equivalent,
 and represent white:
 ```
 #FFFFFF
 color(xyz-d50 0.9643 1 0.8251)
 color(xyz-d65 0.9505 1 1.089)
 ```
 :::

Tests

- [predefined-016.html](https://wpt.fyi/results/css/css-color/predefined-016.html "css/css-color/predefined-016.html")
 [[(live
 test)]](http://wpt.live/css/css-color/predefined-016.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/predefined-016.html)
- [xyz-001.html](https://wpt.fyi/results/css/css-color/xyz-001.html "css/css-color/xyz-001.html")
 [[(live
 test)]](http://wpt.live/css/css-color/xyz-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/xyz-001.html)
- [xyz-002.html](https://wpt.fyi/results/css/css-color/xyz-002.html "css/css-color/xyz-002.html")
 [[(live
 test)]](http://wpt.live/css/css-color/xyz-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/xyz-002.html)
- [xyz-003.html](https://wpt.fyi/results/css/css-color/xyz-003.html "css/css-color/xyz-003.html")
 [[(live
 test)]](http://wpt.live/css/css-color/xyz-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/xyz-003.html)
- [xyz-004.html](https://wpt.fyi/results/css/css-color/xyz-004.html "css/css-color/xyz-004.html")
 [[(live
 test)]](http://wpt.live/css/css-color/xyz-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/xyz-004.html)
- [xyz-005.html](https://wpt.fyi/results/css/css-color/xyz-005.html "css/css-color/xyz-005.html")
 [[(live
 test)]](http://wpt.live/css/css-color/xyz-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/xyz-005.html)
- [xyz-d50-001.html](https://wpt.fyi/results/css/css-color/xyz-d50-001.html "css/css-color/xyz-d50-001.html")
 [[(live
 test)]](http://wpt.live/css/css-color/xyz-d50-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/xyz-d50-001.html)
- [xyz-d50-002.html](https://wpt.fyi/results/css/css-color/xyz-d50-002.html "css/css-color/xyz-d50-002.html")
 [[(live
 test)]](http://wpt.live/css/css-color/xyz-d50-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/xyz-d50-002.html)
- [xyz-d50-003.html](https://wpt.fyi/results/css/css-color/xyz-d50-003.html "css/css-color/xyz-d50-003.html")
 [[(live
 test)]](http://wpt.live/css/css-color/xyz-d50-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/xyz-d50-003.html)
- [xyz-d50-004.html](https://wpt.fyi/results/css/css-color/xyz-d50-004.html "css/css-color/xyz-d50-004.html")
 [[(live
 test)]](http://wpt.live/css/css-color/xyz-d50-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/xyz-d50-004.html)
- [xyz-d50-005.html](https://wpt.fyi/results/css/css-color/xyz-d50-005.html "css/css-color/xyz-d50-005.html")
 [[(live
 test)]](http://wpt.live/css/css-color/xyz-d50-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/xyz-d50-005.html)
- [xyz-d65-001.html](https://wpt.fyi/results/css/css-color/xyz-d65-001.html "css/css-color/xyz-d65-001.html")
 [[(live
 test)]](http://wpt.live/css/css-color/xyz-d65-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/xyz-d65-001.html)
- [xyz-d65-002.html](https://wpt.fyi/results/css/css-color/xyz-d65-002.html "css/css-color/xyz-d65-002.html")
 [[(live
 test)]](http://wpt.live/css/css-color/xyz-d65-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/xyz-d65-002.html)
- [xyz-d65-003.html](https://wpt.fyi/results/css/css-color/xyz-d65-003.html "css/css-color/xyz-d65-003.html")
 [[(live
 test)]](http://wpt.live/css/css-color/xyz-d65-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/xyz-d65-003.html)
- [xyz-d65-004.html](https://wpt.fyi/results/css/css-color/xyz-d65-004.html "css/css-color/xyz-d65-004.html")
 [[(live
 test)]](http://wpt.live/css/css-color/xyz-d65-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/xyz-d65-004.html)
- [xyz-d65-005.html](https://wpt.fyi/results/css/css-color/xyz-d65-005.html "css/css-color/xyz-d65-005.html")
 [[(live
 test)]](http://wpt.live/css/css-color/xyz-d65-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/xyz-d65-005.html)
- [color-valid.html](https://wpt.fyi/results/css/css-color/parsing/color-valid.html "css/css-color/parsing/color-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-color/parsing/color-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/parsing/color-valid.html)

### 10.10. Converting Predefined Color Spaces to Lab or Oklab

For all predefined RGB color spaces, conversion to Lab requires several
steps, although in practice all but the first step are linear
calculations and can be combined.

1. Convert from gamma-encoded RGB to linear-light RGB (undo gamma
 encoding)
2. Convert from linear RGB to CIE XYZ
3. If needed, convert from a [D65](#d65) whitepoint (used by
 [sRGB](#valdef-color-srgb),
 [display-p3](#valdef-color-display-p3),
 [a98-rgb](#valdef-color-a98-rgb) and
 [rec2020](#valdef-color-rec2020)) to the [D50](#d50) whitepoint used in Lab, with the linear Bradford
 transform.
 [prophoto-rgb](#valdef-color-prophoto-rgb) already has a [D50]
 whitepoint.
4. Convert D50-adapted XYZ to Lab

Conversion to Oklab is similar, but the chromatic adaptation step is
only needed for
[prophoto-rgb](#valdef-color-prophoto-rgb).

1. Convert from gamma-encoded RGB to linear-light RGB (undo gamma
 encoding)
2. Convert from linear RGB to CIE XYZ
3. If needed, convert from a [D50](#d50)
 whitepoint (used by
 [prophoto-rgb](#valdef-color-prophoto-rgb)) to the [D65](#d65) whitepoint used in Oklab, with the linear Bradford
 transform.
4. Convert D65-adapted XYZ to Oklab

There is sample JavaScript code for these conversions in [§ 19 Sample
code for Color Conversions](#color-conversion-code).

### 10.11. Converting Lab or Oklab to Predefined RGB Color Spaces

Conversion from Lab to predefined spaces like
[display-p3](#valdef-color-display-p3) or
[rec2020](#valdef-color-rec2020) also requires multiple steps, and again in practice
all but the last step are linear calculations and can be combined.

1. Convert Lab to (D50-adapted) XYZ
2. If needed, convert from a [D50](#d50)
 whitepoint (used by Lab) to the [D65](#d65) whitepoint used in sRGB and most other RGB spaces,
 with the linear Bradford transform.
 [prophoto-rgb](#valdef-color-prophoto-rgb)\' does not require this step.
3. Convert from (D65-adapted) CIE XYZ to linear RGB
4. Convert from linear-light RGB to RGB (do gamma encoding)

Conversion from Oklab is similar, but the chromatic adaptation step is
only needed for
[prophoto-rgb](#valdef-color-prophoto-rgb).

1. Convert Oklab to (D65-adapted) XYZ
2. If needed, convert from a [D65](#d65) whitepoint (used by Oklab) to the
 [D50](#d50) whitepoint used in
 [prophoto-rgb](#valdef-color-prophoto-rgb), with the linear Bradford transform.
3. Convert from (D65-adapted) CIE XYZ to linear RGB
4. Convert from linear-light RGB to RGB (do gamma encoding)

There is sample JavaScript code for these conversions in [§ 19 Sample
code for Color Conversions](#color-conversion-code).

Implementations may choose to implement these steps in some other way
(for example, using an ICC profile with relative colorimetric rendering
intent) provided the results are the same for colors inside both the
source and destination gamuts.

### 10.12. Converting Between Predefined RGB Color Spaces

Conversion from one predefined RGB color space to another requires
multiple steps, one of which is only needed when the whitepoints differ.
To convert from *src* to *dest*:

1. Convert from gamma-encoded *src*RGB to linear-light *src*RGB (undo
 gamma encoding)
2. Convert from linear *src*RGB to CIE XYZ
3. If *src* and *dest* have different whitepoints, convert the XYZ
 value from *src*White to *dest*White with the linear Bradford
 transform.
4. Convert from CIE XYZ to linear *dest*RGB
5. Convert from linear-light *dest*RGB to *dest*RGB (do gamma encoding)

There is sample JavaScript code for this conversion for the predefined
RGB color spaces, in [§ 19 Sample code for Color
Conversions](#color-conversion-code).

### 10.13. Simple Alpha Compositing

When drawing, implementations must handle alpha according to the rules
in [Section 5.1 Simple alpha
compositing](https://www.w3.org/TR/compositing-1/#simplealphacompositing)
of
[\[Compositing\]](#biblio-compositing "Compositing and Blending Level 1").

## 11. Converting Colors

Tests

This section provides algorithms used later, it does not need tests.

------------------------------------------------------------------------

### 11.1. Introduction to Converting Colors

Colors may be converted from one color space to another and, provided
that there is no gamut mapping and that each color space can represent
[out of gamut](#out-of-gamut)
colors, (for RGB spaces, this means that the transfer function is
defined over the extended range) then (subject to numerical precision
and round-off error) the two colors will look the same and represent the
same color sensation.

For example, these different syntactic
forms are all the same color:

- oklch(65% 0.15 270)
- lab(57.9% 11.4
 -53.7)
-
 color(display-p3 0.445 0.529 0.891)
-
 color(rec2020 0.522 0.557 0.892)
- #6c88ea

For historical reasons, at **parse time**, some [legacy color
syntax](#legacy-color-syntax) colors are clamped. In general though such clamping is
undesirable because it interferes with round-tripping and results in
errors accumulating over multiple color conversions.

Thus, the **results of color conversion** are **not clamped**, which may
result in out of gamut colors or indeed, imaginary colors such as colors
outside the spectral locus, or even colors with negative lightness or
lightness greater than the maximum allowed value.

For example, these are all the same
color, but it is outside the gamut of even rec2020 (the swatches have
been gamut mapped to sRGB for display, but the values have not):

- oklch(65% 0.25 270)
- lab(56.03% 32.3 -88.58)
- color(display-p3 0.3731 0.4673
 1.105)
- color(rec2020 0.4929 0.5062
 1.094)
- color(srgb 0.3475 0.4707 1.146)

For example, due to chromatic
adaptation, the lightness value of this XYZ color is slightly greater
than 100 when adapted to D50 Lab:

- color(xyz-d65 1 1 1)
- lab(100.1154% 9.064489 5.801761)

### 11.2. Algorithm for Converting Colors

To [prepare a color `col1` for
conversion]:

1. [(#powerless-to-missing)Change any [powerless
 component](#powerless-color-component)s in `src` to [missing
 component](#missing-color-component)s]
2. [(#convert-polrect)If `src` is in a
 [cylindrical polar
 color](#cylindrical-polar-color) representation, convert `col1` to the
 corresponding [rectangular orthogonal
 color](#rectangular-orthogonal-color) representation and let this be the new
 `col1`.]

To [convert a color] `col1` in a source color space `src`
with white point `src-white` to a color `col2` in
destination color space `dest` with white point
`dest-white`, where `src` and `dest`
are *different*:

1. prepare `col1` for conversion
2. [(#convert-missing)Replace any [missing
 component](#missing-color-component) with zero.]
3. [(#convert-tolinear)If `src` is not a
 linear-light representation, convert it to linear light (undo
 gamma-encoding) and let this be the new
 `col1`.]
4. [(#convert-toXYZ)Convert `col1` to CIE XYZ
 with a given whitepoint `src-white` and let this be
 `xyz`.]
5. [(#convert-CAT)If `dest-white` is not the
 same as `src-white`, chromatically adapt `xyz`
 to `dest-white` using a linear Bradford [chromatic
 adaptation
 transform](#chromatic-adaptation-transform), and let this be the new
 `xyz`.]
6. [(#convert-destpolar)If `dest` is a
 [cylindrical polar
 color](#cylindrical-polar-color) representation, let `dest-rect` be the
 corresponding [rectangular orthogonal
 color](#rectangular-orthogonal-color) representation. Otherwise, let
 `dest-rect` be `dest`.]
7. [(#convert-fromXYZ)Convert `xyz` to
 `dest`, followed by applying any transfer function (gamma
 encoding), producing `col2`.]
8. [(#convert-display)If `dest` is a physical
 output color space, such as a display, then `col2` must
 be [css gamut mapped](#css-gamut-mapped) so that it [can be
 displayed](#can-be-displayed).]
9. [(#convert-rectpol)If `dest-rect` is not
 the same as `dest`, in other words `dest` is a
 [cylindrical polar
 color](#cylindrical-polar-color) representation, convert from `dest-rect`
 to `dest`, and let this be `col2`. This may
 produce [missing
 component](#missing-color-component)s.]

## 12. Comparing [\<color\> Values]
Two [\<color\>](#typedef-color) values are [equivalent
colors]
when they compare as equal using the algorithm below. This comparison is
used, for example, by [style()] container queries
[\[CSS-CONDITIONAL-5\]](#biblio-css-conditional-5 "CSS Conditional Rules Module Level 5")
and by CSS Transitions
[\[CSS-TRANSITIONS-1\]](#biblio-css-transitions-1 "CSS Transitions Module Level 1")
to determine whether a color value has changed.

Given two [\<color\>](#typedef-color) values `C1` and
`C2`, they are [equivalent
colors](#equivalent-colors)
if and only if the following algorithm returns true:

1. For each of `C1` and `C2`, convert any
 [powerless
 component](#powerless-color-component)s to [missing
 component](#missing-color-component)s.
2. If `C1` and `C2` share the same
 [\<color-space\>](#typedef-color-space):
 1. Compare their components one by one, including the alpha
 channel. A [missing
 component](#missing-color-component) is only equal to another [missing
 component]. Two numeric
 components are considered equal if they differ by no more than a
 small implementation-defined ε.
 2. Return true if and only if all components compare as equal.
3. Otherwise, `C1` and `C2` are in different
 [\<color-space\>](#typedef-color-space)s. If either color has at least
 one [missing
 component](#missing-color-component), return false.
4. Otherwise, neither color has any [missing
 component](#missing-color-component). Convert both `C1` and `C2`
 to [oklab](#valdef-oklab-oklab), then return true if and only if all components
 (including alpha) of the converted colors compare as equal, using a
 standardized Oklab ε of **0.00001**.

 Two colors that are expressed in different syntactic
forms, in the same
[\<color-space\>](#typedef-color-space), but are colorimetrically
identical---for example,
[red](#valdef-color-red) and [color(srgb 1 0 0)]---are [equivalent
colors](#equivalent-colors)
by step 2 of this algorithm.

 Two colors that are expressed in different
[\<color-space\>](#typedef-color-space)s but are colorimetrically
identical---for example,
[red](#valdef-color-red) and [color(display-p3 0.91748756 0.20028681
0.13856059)]---are [equivalent
colors](#equivalent-colors)
by step 4 of this algorithm, since they convert to the same
[oklab](#valdef-oklab-oklab) value.

For the purposes of this comparison,
[rgb()](#funcdef-rgb),
[rgba()](#funcdef-rgba),
[hsl()](#funcdef-hsl),
[hsla()](#funcdef-hsla),
[hwb()](#funcdef-hwb),
[hex colors](#hex-color), [named
colors](#named-color), and
[system colors](#css-system-colors) are all considered to be in the
[srgb](#valdef-color-srgb)
[\<color-space\>](#typedef-color-space).

Tests

- [query-style-color.html](https://wpt.fyi/results/css/css-conditional/container-queries/query-style-color.html "css/css-conditional/container-queries/query-style-color.html")
 [[(live
 test)]](http://wpt.live/css/css-conditional/container-queries/query-style-color.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/container-queries/query-style-color.html)

 [red](#valdef-color-red) and  [rgb(255, 0, 0)] are [equivalent
colors](#equivalent-colors). Both are in the
[srgb](#valdef-color-srgb)
[\<color-space\>](#typedef-color-space), so step 2 compares their red, green,
blue and alpha components, which are all equal.

 [red](#valdef-color-red) and  [color(srgb 1 0 0)] are
[equivalent colors](#equivalent-colors). A [named color](#named-color) is considered to be in the
[srgb](#valdef-color-srgb)
[\<color-space\>](#typedef-color-space), which is also the
[\<color-space\>] of this
[color()](#funcdef-color) value, so the two are compared component by component
at step 2.

 [#ff000080] and
 [rgb(255 0 0 /
50%)] are *not* [equivalent
colors](#equivalent-colors), although they are hard to tell apart. The alpha
channel is compared like any other component, and 128 / 255 =
0.50196..., which differs from 0.5 by more than a small ε.

 [hsl(0 0% 50%)] and  [hsl(200 0% 50%)] are
[equivalent colors](#equivalent-colors), by either of two routes. Their saturation is 0%, so at
step 1 the hue of each becomes a [missing
component](#missing-color-component), and a [missing
component] is equal to another
[missing component]. Independently,
[hsl()](#funcdef-hsl) is
considered to be in the
[srgb](#valdef-color-srgb)
[\<color-space\>](#typedef-color-space), where the hue is not one of the
components being compared at all.

 [white](#valdef-color-white) and  [hwb(120 100% 0%)] are
[equivalent colors](#equivalent-colors). Whiteness and blackness sum to 100, so the hue is
[powerless](#powerless-color-component) and becomes
[missing](#missing-color-component) at step 1; and since
[hwb()](#funcdef-hwb) is
considered to be in the
[srgb](#valdef-color-srgb)
[\<color-space\>](#typedef-color-space), both colors are compared as R, G and
B of 100%.

 [oklch(50% 0
40)] and  [oklch(50% 0
200)] are [equivalent
colors](#equivalent-colors). The chroma is zero, so each hue is
[powerless](#powerless-color-component) and becomes
[missing](#missing-color-component) at step 1, leaving two colors whose every component
compares as equal.

 [lch(50% 0.001
30)] and  [lch(50% 0.001
200)] are [equivalent
colors](#equivalent-colors), even though their chroma is not exactly zero and their
hues are 170 degrees apart. A chroma of 0.001 is within the ε of 0.0015
that [lch()](#funcdef-lch)
defines for a
[powerless](#powerless-color-component) hue, so at step 1 both hues become
[missing](#missing-color-component) and both chromas are set to zero.

 [lch(50% 30 0)]
and  [lch(50% 30
360)] are [equivalent
colors](#equivalent-colors), but not because of anything this algorithm does: a
[\<hue\>](#typedef-hue) is normalized to the range \[0, 360) when it is
parsed, so by the time the two are compared both hue components are 0.

 [rgb(none 128 0)] and
 [rgb(0 128 0)]
are *not* [equivalent
colors](#equivalent-colors), although they render identically, since a [missing
component](#missing-color-component) behaves as zero when a color is displayed. For the
purposes of this comparison a [missing
component] is only ever equal to
another [missing component], never
to a component whose value happens to be zero.

 [oklch(50% 0
none)] and  [oklab(50% 0 0)]
are *not* [equivalent
colors](#equivalent-colors), despite being colorimetrically identical. They are in
different
[\<color-space\>](#typedef-color-space)s, and the first has a [missing
component](#missing-color-component), so step 3 returns false without any component values
being compared.

 [red](#valdef-color-red) and  [color(srgb-linear 1 0 0)] are
[equivalent colors](#equivalent-colors). They are in different
[\<color-space\>](#typedef-color-space)s and neither has a [missing
component](#missing-color-component), so step 4 converts both to
[oklab](#valdef-oklab-oklab), where they have the same value.

 [color(display-p3 1 1 1)]
and  [white](#valdef-color-white) are [equivalent
colors](#equivalent-colors). Converting each to
[oklab](#valdef-oklab-oklab) at step 4 leaves component differences of the order
of 10^-16^, which is why that step compares with an ε rather than for
exact equality.

 [lab(50% 0 0)]
and  [oklab(0.5 0 0)]
are *not* [equivalent
colors](#equivalent-colors). Both are achromatic with a lightness of 50%, but the
two lightness scales are not the same: converted to
[oklab](#valdef-oklab-oklab) at step 4 their lightness components are 0.56897 and
0.5, which differ by far more than the standardized ε.

## 13. Color Interpolation

Color interpolation happens with gradients, compositing, filters,
transitions, animations, and color mixing and color modification
functions.

Interpolation between two
[\<color\>](#typedef-color) values takes place by executing the following steps:

1. checking the two colors for [analogous
 components](#analogous-components) and [analogous
 sets](#analogous-set) which
 will be [carried forward]
2. (if conversion is required) changing any
 [powerless](#powerless-color-component) components to
 [missing](#missing-color-component) values
3. (if required) converting them both to a given color space which will
 be referred to as the [interpolation color
 space] below.
4. (if required) re-inserting [carried
 forward](#carried-forward)
 values in the converted colors
5. fill in missing components with the other color's component values
6. (if required) fixing up the hues, depending on the selected
 [\<hue-interpolation-method\>](#typedef-hue-interpolation-method)
7. changing the color components to
 [premultiplied](#premultiplied) form
8. linearly interpolating each component of the computed value of the
 color separately
9. undoing [premultiplication](#premultiplied)

Interpolating to or from
[currentcolor](#valdef-color-currentcolor) is possible. The numerical value used for this
purpose is the used value.

### 13.1. Component-wise Linear Interpolation

There are two ways to conceptualize how much each color component
contributes to the final result: [color
quantities](#color-quantities) and [color
progress](#color-progress).
Both give the same result; they are just different mental models.

For example, when mixing the
lightness components of two colors `La` and `Lb`,
the natural mental model is that of a **pair of quantities**: I want 70%
of `La` and 30% of `Lb`.

For example, when animating the
lightness component of a color, from a starting value of `La`
to en ending value of `Lb`, the natural mental model is of a
**single progress value** which is 0% at the start of the animation and
100% at the end of the animation. At a progress of 0%, the interpolated
component is equal to 100% `La` and 0% of `Lb`; at
a progress of 100%, the interpolated component is equal to 0%
`La` and 100% of `Lb`. Thus, at a progress of 30%,
the interpolated component is equal to 70% of `La` and 30% of
`Lb`.

[color quantities]
: Given a pair of percentage quantities `Qa` and
 `Qb`, which have been normalized to add to 100%, and a
 pair of color component values `Ca` and `Cb`,
 the interpolated result is (`Ca` × `Qa`) + (
 `Cb` × `Qb`).

[color progress]
: Given a percentage progress `P` and the starting and
 ending component values `Cs` and `Ce`, the
 interpolated result is (`Cs` × (1 - `P`) +
 `Ce` × `P`).

Thus, when converting from one model to another, the progress is the
amount of the *second* color.

### 13.2. Color Space for Interpolation

Various features in CSS depend on interpolating colors.

Examples include:

- [\<gradient\>](https://drafts.csswg.org/css-images-4/#typedef-gradient)

- [filter](https://drafts.csswg.org/filter-effects-1/#propdef-filter)

- [animation](https://drafts.csswg.org/css-animations-1/#propdef-animation)

- [transition](https://drafts.csswg.org/css-transitions-1/#propdef-transition)

- [color-mix()](https://drafts.csswg.org/css-color-5/#funcdef-color-mix)

- [relative
 color](https://drafts.csswg.org/css-color-5/#relative-color) syntax

To interpolate, the colors must be in (or be converted to) the same
color space.

Mixing or otherwise combining colors has different results depending on
the [interpolation color
space](#interpolation-color-space) used. Thus, different color spaces may be more
appropriate for each interpolation use case.

- In some cases, the result of physically mixing two colored lights is
 desired. In that case, the CIE
 [XYZ](#valdef-color-xyz),
 [display-p3-linear](#valdef-color-display-p3-linear) or
 [srgb-linear](#valdef-color-srgb-linear) color spaces are appropriate, because they are
 linear in light intensity.

- If colors need to be evenly spaced perceptually (such as in a
 gradient), the
 [Oklab](#valdef-oklab-oklab) color space (and to a lesser extent, the older
 [Lab](#valdef-lab-lab)), are designed to be perceptually uniform.

- If avoiding graying out in color mixing is desired, i.e. maximizing
 chroma throughout the transition,
 [OkLCh](#valdef-oklch-oklch) (and to a lesser extent, the older
 [LCH](#valdef-lch-lch)) work well for that.

- Lastly, compatibility with legacy Web content may be the most
 important consideration. The
 [sRGB](#valdef-color-srgb) color space, which is neither linear-light nor
 perceptually uniform, is the choice here, even though it produces
 poorer results (overly dark or greyish mixes).

These features are collectively termed the [host syntax].

To permit a host syntax to indicate the [interpolation color
space](#interpolation-color-space), this specification exports a
[color-interpolation-method](#color-interpolation-method)
production. It is not used by this specification itself, only exposed so
that other specifications can use it; [see e.g. use in [CSS Images 4
§ 3.1 Linear Gradients: the linear-gradient()
notation](https://drafts.csswg.org/css-images-4/#linear-gradients).]

The host syntax should define what the *default* [interpolation color
space](#interpolation-color-space) should be for each case, and preferably provide syntax
for authors to override this default. If such syntax is part of a
property value, it should use the
[color-interpolation-method](#color-interpolation-method)
production, defined below for easy reference from other specifications.
This ensures consistency across CSS, and that further customizations on
how color interpolation is performed can automatically percolate across
all of CSS.

```
<color-space> = <rectangular-color-space> | <polar-color-space>
<rectangular-color-space> = srgb | srgb-linear | display-p3 | display-p3-linear | a98-rgb | prophoto-rgb | rec2020 | lab | oklab | <xyz-space>
<polar-color-space> = hsl | hwb | lch | oklch
<hue-interpolation-method> = [ shorter | longer | increasing | decreasing ] hue
<color-interpolation-method> = in [ <rectangular-color-space> | <polar-color-space> <hue-interpolation-method>? ]
```

The keywords in the definitions of
[\<rectangular-color-space\>](#typedef-rectangular-color-space) and
[\<polar-color-space\>](#typedef-polar-color-space) each refer to their corresponding
color space, represented in CSS either by the functional syntax with the
same name, or (if no such function is present), by the corresponding
[\<ident\>](https://drafts.csswg.org/css-values-4/#typedef-ident) in the
[color()](#funcdef-color) function.

Tests

- [color-mix-percents-01.html](https://wpt.fyi/results/css/css-color/color-mix-percents-01.html "css/css-color/color-mix-percents-01.html")
 [[(live
 test)]](http://wpt.live/css/css-color/color-mix-percents-01.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/color-mix-percents-01.html)
- [color-mix-percents-02.html](https://wpt.fyi/results/css/css-color/color-mix-percents-02.html "css/css-color/color-mix-percents-02.html")
 [[(live
 test)]](http://wpt.live/css/css-color/color-mix-percents-02.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/color-mix-percents-02.html)

<!-- -->

- [gradients-with-transparent.html](https://wpt.fyi/results/css/css-images/gradients-with-transparent.html "css/css-images/gradients-with-transparent.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradients-with-transparent.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradients-with-transparent.html)
- [gradient-eval-001.html](https://wpt.fyi/results/css/css-images/gradient/gradient-eval-001.html "css/css-images/gradient/gradient-eval-001.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/gradient-eval-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/gradient-eval-001.html)
- [gradient-eval-002.html](https://wpt.fyi/results/css/css-images/gradient/gradient-eval-002.html "css/css-images/gradient/gradient-eval-002.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/gradient-eval-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/gradient-eval-002.html)
- [gradient-eval-003.html](https://wpt.fyi/results/css/css-images/gradient/gradient-eval-003.html "css/css-images/gradient/gradient-eval-003.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/gradient-eval-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/gradient-eval-003.html)
- [gradient-eval-004.html](https://wpt.fyi/results/css/css-images/gradient/gradient-eval-004.html "css/css-images/gradient/gradient-eval-004.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/gradient-eval-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/gradient-eval-004.html)
- [gradient-eval-005.html](https://wpt.fyi/results/css/css-images/gradient/gradient-eval-005.html "css/css-images/gradient/gradient-eval-005.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/gradient-eval-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/gradient-eval-005.html)
- [gradient-eval-006.html](https://wpt.fyi/results/css/css-images/gradient/gradient-eval-006.html "css/css-images/gradient/gradient-eval-006.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/gradient-eval-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/gradient-eval-006.html)
- [gradient-eval-007.html](https://wpt.fyi/results/css/css-images/gradient/gradient-eval-007.html "css/css-images/gradient/gradient-eval-007.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/gradient-eval-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/gradient-eval-007.html)
- [gradient-eval-008.html](https://wpt.fyi/results/css/css-images/gradient/gradient-eval-008.html "css/css-images/gradient/gradient-eval-008.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/gradient-eval-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/gradient-eval-008.html)
- [gradient-eval-009.html](https://wpt.fyi/results/css/css-images/gradient/gradient-eval-009.html "css/css-images/gradient/gradient-eval-009.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/gradient-eval-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/gradient-eval-009.html)
- [gradient-none-interpolation.html](https://wpt.fyi/results/css/css-images/gradient/gradient-none-interpolation.html "css/css-images/gradient/gradient-none-interpolation.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/gradient-none-interpolation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/gradient-none-interpolation.html)
- [oklab-gradient.html](https://wpt.fyi/results/css/css-images/gradient/oklab-gradient.html "css/css-images/gradient/oklab-gradient.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/oklab-gradient.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/oklab-gradient.html)
- [srgb-gradient.html](https://wpt.fyi/results/css/css-images/gradient/srgb-gradient.html "css/css-images/gradient/srgb-gradient.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/srgb-gradient.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/srgb-gradient.html)
- [srgb-linear-gradient.html](https://wpt.fyi/results/css/css-images/gradient/srgb-linear-gradient.html "css/css-images/gradient/srgb-linear-gradient.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/srgb-linear-gradient.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/srgb-linear-gradient.html)
- [xyz-gradient.html](https://wpt.fyi/results/css/css-images/gradient/xyz-gradient.html "css/css-images/gradient/xyz-gradient.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/xyz-gradient.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/xyz-gradient.html)
- [gradient-interpolation-method-valid.html](https://wpt.fyi/results/css/css-images/parsing/gradient-interpolation-method-valid.html "css/css-images/parsing/gradient-interpolation-method-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-images/parsing/gradient-interpolation-method-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/parsing/gradient-interpolation-method-valid.html)
- [gradient-interpolation-method-invalid.html](https://wpt.fyi/results/css/css-images/parsing/gradient-interpolation-method-invalid.html "css/css-images/parsing/gradient-interpolation-method-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-images/parsing/gradient-interpolation-method-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/parsing/gradient-interpolation-method-invalid.html)
- [gradient-interpolation-method-computed.html](https://wpt.fyi/results/css/css-images/parsing/gradient-interpolation-method-computed.html "css/css-images/parsing/gradient-interpolation-method-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-images/parsing/gradient-interpolation-method-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/parsing/gradient-interpolation-method-computed.html)

If the host syntax does not define what color space interpolation should
take place in, it defaults to Oklab.

For a
[\<polar-color-space\>](#typedef-polar-color-space) if the
[\<hue-interpolation-method\>](#typedef-hue-interpolation-method) is not specified, it defaults to
[shorter](#shorter).

However, user agents *must* handle interpolation between legacy sRGB
color formats (hex colors, named colors,
[rgb()](#funcdef-rgb),
[hsl()](#funcdef-hsl) or
[hwb()](#funcdef-hwb) and
the equivalent alpha-including forms) in gamma-encoded sRGB space. This
provides Web compatibility; legacy sRGB content interpolates in the sRGB
space by default.

Tests

- [legacy-color-gradient.html](https://wpt.fyi/results/css/css-images/gradient/legacy-color-gradient.html "css/css-images/gradient/legacy-color-gradient.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/legacy-color-gradient.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/legacy-color-gradient.html)

This also means that authors can choose to opt-in to better
interpolation, even between sRGB colors, by using the non-legacy
[color(srgb r g b)] form for at least one of their colors, or by
explicitly specifying an [interpolation color
space](#interpolation-color-space).

Tests

- [css-color-4-colors-default-to-oklab-gradient.html](https://wpt.fyi/results/css/css-images/gradient/css-color-4-colors-default-to-oklab-gradient.html "css/css-images/gradient/css-color-4-colors-default-to-oklab-gradient.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/css-color-4-colors-default-to-oklab-gradient.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/css-color-4-colors-default-to-oklab-gradient.html)

If the colors to be interpolated are outside the gamut of the
[interpolation color
space](#interpolation-color-space) , then once converted to that space, they will contain
out of range values.

These are not clipped; the values must be interpolated as-is.

### 13.3. Interpolating with Missing Components

In the course of converting the two colors to the [interpolation color
space](#interpolation-color-space), any [missing
components](#missing-color-component) would be replaced with the value 0.

Thus, the first stage in interpolating two colors is to classify any
[missing
components](#missing-color-component) in the input colors, and compare them to the components
of the [interpolation color
space](#interpolation-color-space). If any [analogous
components](#analogous-components) which are [missing
components] are found, they will be
**carried forward** and re-inserted in the converted color before
premultiplication, and before linear interpolation takes place.

Similarly, if every component of an [analogous
set](#analogous-set) (defined
below) in the original color is a [missing
component](#missing-color-component), they are all [carried
forward](#carried-forward)
and re-inserted in the corresponding [analogous
set] of the [interpolation color
space](#interpolation-color-space).

Alpha is its own analogous component (alpha is analogous to alpha), so a
[missing](#missing-color-component) alpha is [carried
forward](#carried-forward) in
exactly the same way as any other [missing
component].

The [analogous components] are as follows:

Category

Components

Reds

r,x

Greens

g,y

Blues

b,z

Lightness

L

Colorfulness

C, S

Hue

H

Opponent a

a

Opponent b

b

Alpha

alpha

 for the purposes of this classification, the XYZ spaces
are considered super-saturated RGB spaces. Also, despite Saturation
being Lightness-dependent, it falls in the same category as Chroma here.
The Whiteness and Blackness components of HWB have no analogs in other
color spaces.

Additionally, for any two color spaces, the components that remain after
removing all [analogous
components](#analogous-components) form an [analogous set] of components.

 Because the full set of all color components is the
[analogous set](#analogous-set)
that remains when there are no individual [analogous
components](#analogous-components), a color with all color components
[missing](#missing-color-component) will have all color components
[missing] in the [interpolation
color
space](#interpolation-color-space) as well.

When converting
`lab(50% none none)` to LCH for interpolation,
Lightness is individually
[analogous](#analogous-components). The remaining components
([a](https://drafts.csswg.org/css-color-5/#valdef-oklab-a) and
[b](https://drafts.csswg.org/css-color-5/#valdef-oklab-b) in Lab;
[C](https://drafts.csswg.org/css-color-5/#valdef-oklch-c) and
[H](https://drafts.csswg.org/css-color-5/#valdef-oklch-h) in LCH) form an [analogous
set](#analogous-set). Since
both [a] and [b] are
[missing](#missing-color-component), both [C] and
[H] are carried forward as
[missing], giving
`lch(50% none none)` rather than
`lch(50% 0 0)`.

Similarly, `rgb(none none none / 50%)` converted
to OKLab for interpolation yields
`oklab(none none none / 50%)`, because the three
color components form the [analogous
set](#analogous-set) (there are
no individual [analogous
components](#analogous-components) between sRGB and OKLab).

- [gradient-none-interpolation.html](https://wpt.fyi/results/css/css-images/gradient/gradient-none-interpolation.html "css/css-images/gradient/gradient-none-interpolation.html")
 [[(live
 test)]](http://wpt.live/css/css-images/gradient/gradient-none-interpolation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-images/gradient/gradient-none-interpolation.html)

For example, if these two colors are
to be interpolated in OkLCh, the missing hue in the CIE LCH color is
analogous to the hue component of OkLCh and will be carried forward
while the missing blue component in the second color is not analogous to
any OkLCh component and will not be carried forward:

``` highlight
 lch(50% 0.02 none)
 color(display-p3 0.7 0.5 none)
```

which convert to

``` highlight
 oklch(56.897% 0.0001 0)
 oklch(63.612% 0.1522 78.748)
```

and with carried forward [missing
component](#missing-color-component) re-inserted, the two colors to be interpolated are:

``` highlight
 oklch(56.897% 0.0001 none)
 oklch(63.612% 0.1522 78.748)
```

If a color with a carried forward [missing
component](#missing-color-component) is interpolated with another color which is not missing
that component, the [missing
component] is treated as having the
*other color's* component value.

Therefore, the identification of carried-forward components must be
performed *before* any [powerless
component](#powerless-color-component) handling; to prevent conversion of that value to zero.

For example, if these two colors
are interpolated, the second of which has a missing hue:

``` highlight
 oklch(78.3% 0.108 326.5)
 oklch(39.2% 0.4 none)
```

Then the actual colors to be interpolated are

``` highlight
 oklch(78.3% 0.108 326.5)
 oklch(39.2% 0.4 326.5)
```

::: {style="width: 100%; height: 5em; background: linear-gradient(to right, oklch(78.3% 0.108 326.5), oklch(73.956% 0.14044 326.5), oklch(69.611% 0.17289 326.5), oklch(65.267% 0.20533 326.5), oklch(60.922% 0.23778 326.5), oklch(56.578% 0.27022 326.5), oklch(52.233% 0.30267 326.5), oklch(47.889% 0.33511 326.5), oklch(43.544% 0.36756 326.5), oklch(39.2% 0.4 326.5))"}

and not

``` highlight
 oklch(78.3% 0.108 326.5)
 oklch(39.2% 0.4 0)
```

::: {style="width: 100%; height: 5em; background: linear-gradient(to right, oklch(78.3% 0.108 326.5), oklch(75.507% 0.12886 328.89), oklch(72.714% 0.14971 331.29), oklch(69.921% 0.17057 333.68), oklch(67.129% 0.19143 336.07), oklch(64.336% 0.21229 338.46), oklch(61.543% 0.23314 340.86), oklch(58.75% 0.254 343.25), oklch(55.957% 0.27486 345.64), oklch(53.164% 0.29571 348.04), oklch(50.371% 0.31657 350.43), oklch(47.579% 0.33743 352.82), oklch(44.786% 0.35829 355.21), oklch(41.993% 0.37914 357.61), oklch(39.2% 0.4 360))"}

If the carried forward [missing
component](#missing-color-component) is alpha, the color must be
[premultiplied](#premultiplied)
with this carried forward value, not with the zero value that would have
resulted from color conversion.

For example, if these two colors
are interpolated, the second of which has a missing alpha:

``` highlight
 oklch(0.783 0.108 326.5 / 0.5)
 oklch(0.392 0.4 0 / none)
```

Then the actual colors to be interpolated are

``` highlight
 oklch(78.3% 0.108 326.5 / 0.5)
 oklch(39.2% 0.4 0 / 0.5)
```

giving the premultiplied OkLCh values \[0.3915, 0.054, 326\] and
\[0.196, 0.2, 0\].

::: {style="width: 100%; height: 5em; background:linear-gradient(to right, oklch(78.3% 0.108 326.5 / 0.5), oklch(75.507% 0.12886 328.89 / 0.5), oklch(72.714% 0.14971 331.29 / 0.5), oklch(69.921% 0.17057 333.68 / 0.5), oklch(67.129% 0.19143 336.07 / 0.5), oklch(64.336% 0.21229 338.46 / 0.5), oklch(61.543% 0.23314 340.86 / 0.5), oklch(58.75% 0.254 343.25 / 0.5), oklch(55.957% 0.27486 345.64 / 0.5), oklch(53.164% 0.29571 348.04 / 0.5), oklch(50.371% 0.31657 350.43 / 0.5), oklch(47.579% 0.33743 352.82 / 0.5), oklch(44.786% 0.35829 355.21 / 0.5), oklch(41.993% 0.37914 357.61 / 0.5), oklch(39.2% 0.4 360 / 0.5))"}

If both colors are
[missing](#missing-color-component) a given component, the interpolated color will also be
[missing] that component.

### 13.4. Interpolating with Alpha

When the colors to be interpolated are not fully opaque, they are first
[premultiplied] as follows:

- If the alpha value is
 [none](#valdef-color-none), the premultiplied value is the un-premultiplied
 value. Otherwise,

- If any component value is
 [none](#valdef-color-none), the premultiplied value is also
 [none].

- For [rectangular orthogonal
 color](#rectangular-orthogonal-color) coordinate systems, all component values are
 multiplied by the alpha value.

- For [cylindrical polar
 color](#cylindrical-polar-color) coordinate systems, the hue angle is *not*
 premultiplied, but the other two axes *are* premultiplied.

To obtain a color value from a premultiplied color value,

- If the interpolated alpha value is zero or
 [none](#valdef-color-none), the un-premultiplied value is the premultiplied
 value. Otherwise,

- If any component value is
 [none](#valdef-color-none), the un-premultiplied value is also
 [none].

- otherwise, each component which had been premultiplied is divided by
 the interpolated alpha value.

Tests

- [color-transition-premultiplied.html](https://wpt.fyi/results/css/css-transitions/animations/color-transition-premultiplied.html "css/css-transitions/animations/color-transition-premultiplied.html")
 [[(live
 test)]](http://wpt.live/css/css-transitions/animations/color-transition-premultiplied.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-transitions/animations/color-transition-premultiplied.html)

Why is premultiplied alpha useful?

Interpolating colors using the premultiplied representations tends to
produce more attractive transitions than the non-premultiplied
representations, particularly when transitioning from a fully opaque
color to fully transparent.

Note that transitions where either the transparency or the color are
held constant (for example, transitioning between
[`rgba(255, 0, 0, 100%)`]{style=";white-space:nowrap"} (opaque red) and
[`rgba(0,0,255,100%)`]{style=";white-space:nowrap"} (opaque blue), or
[`rgba(255,0,0,100%)`]{style=";white-space:nowrap"} (opaque red) and
[`rgba(255,0,0,0%)`]{style=";white-space:nowrap"}
(transparent red)) have identical results whether the color
interpolation is done in premultiplied or non-premultiplied color-space.
Differences only arise when *both* the color and transparency differ
between the two endpoints.

The following
example illustrates the difference between a gradient transitioning via
pre-multiplied values (in this case sRGB, since all colors involved are
legacy colors) and one transitioning (incorrectly) via non-premultiplied
values. In both of these examples, the gradient is drawn over a white
background. Both gradients could be written with the following value:

``` highlight
linear-gradient(90deg, red, transparent, blue)
```

With premultiplied colors, transitions to or from \"transparent\" always
look nice:

(Image requires SVG)

On the other hand, if a gradient were to incorrectly transition in
non-premultiplied space, the center of the gradient would be a
noticeably grayish color, because \"transparent\" is actually a
shorthand for [rgba(0,0,0,0)], or transparent black, meaning that
the red transitions to a black as it loses opacity, and similarly with
the blue's transition:

(Image requires SVG)

For example, to interpolate, in
the sRGB color space, the two sRGB colors rgb(24% 12% 98% / 0.4) and
 rgb(62% 26% 64% /
0.6) they would first be converted to premultiplied form \[9.6% 4.8%
39.2% \] and \[37.2% 15.6% 38.4%\] before interpolation.

The midpoint of linearly interpolating these colors would be \[23.4%
10.2% 38.8%\] which, with an alpha value of 0.5, is rgb(46.8% 20.4% 77.6% /
0.5) when premultiplication is undone.

To interpolate, in the Lab color
space, the two colors rgb(76% 62% 03% / 0.4) and

color(display-p3 0.84 0.19 0.72 / 0.6) they are first converted to lab
 lab(66.927% 4.873
68.622 / 0.4) lab(53.503% 82.672
-33.901 / 0.6) then the L, a and b coordinates are premultiplied before
interpolation \[26.771% 1.949 27.449\] and \[32.102% 49.603 -20.341\].

The midpoint of linearly interpolating these would be \[29.4365% 25.776
3.554\] which, with an alpha value of 0.5, is lab(58.873% 51.552
7.108) / 0.5) when premultiplication is undone.

To interpolate, in the
chroma-preserving LCH color space, the same two colors rgb(76% 62% 03% / 0.4) and

color(display-p3 0.84 0.19 0.72 / 0.6) they are first converted to LCH
 lch(66.93% 68.79
85.94 / 0.4) lch(53.5% 89.35 337.7
/ 0.6) then the L and C coordinates (but not H) are premultiplied before
interpolation \[26.771% 27.516 85.94\] and \[32.102% 53.61 337.7\].

The midpoint of linearly interpolating these, along the [shorter]
hue arc (the default) would be \[29.4365% 40.563 31.82\] which, with an
alpha value of 0.5, is lch(58.873% 81.126
31.82) / 0.5) when premultiplication is undone.

There is sample JavaScript code for alpha premultiplication and
un-premultiplication, for both polar and rectangular color spaces, in
[§ 19 Sample code for Color Conversions](#color-conversion-code).

### 13.5. Hue Interpolation

For color functions with a hue angle (LCH, HSL, HWB etc), there are
multiple ways to interpolate. As arcs greater than 360° are rarely
desirable, hue angles are fixed up prior to interpolation so that
per-component interpolation is done over less than 360°, often less than
180°.

Host syntax can specify any of the following algorithms for hue
interpolation (angles in the following are in degrees, but the logic is
the same regardless of how they are specified). Specifying a hue
interpolation strategy is already part of the
[\<color-interpolation-method\>](#color-interpolation-method) syntax via the
[\<hue-interpolation-method\>](#typedef-hue-interpolation-method) token.

Unless otherwise specified, if no specific hue interpolation algorithm
is selected by the host syntax, the default is [shorter].

Tests

- [color-mix-percents-01.html](https://wpt.fyi/results/css/css-color/color-mix-percents-01.html "css/css-color/color-mix-percents-01.html")
 [[(live
 test)]](http://wpt.live/css/css-color/color-mix-percents-01.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/color-mix-percents-01.html)
- [color-mix-percents-02.html](https://wpt.fyi/results/css/css-color/color-mix-percents-02.html "css/css-color/color-mix-percents-02.html")
 [[(live
 test)]](http://wpt.live/css/css-color/color-mix-percents-02.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/color-mix-percents-02.html)

 As a reminder, if the interpolating colors were not
already in the specified interpolation color space, then converting them
will turn any [powerless
components](#powerless-color-component) into [missing
components](#missing-color-component).

#### [13.5.1. ][ [shorter]]
Hue angles are interpolated to take the *shorter* of the two arcs
between the starting and ending hues.

For example, the midpoint when interpolating in OkLCh from a red
 oklch(0.6 0.24 30)
to a yellow  oklch(0.8 0.15 90) would be
at a hue angle of 30 + (90 - 30) \* 0.5 = 60 degrees, along the shorter
arc between the two colors, giving a deep orange  oklch(0.7 0.195 60)

::: {style="width: 100%; height: 5em; background: linear-gradient(to right, color(display-p3 0.85564 0.2067 0.1305), color(display-p3 0.86525 0.25647 0.08503), color(display-p3 0.87307 0.30184 0.01956), color(display-p3 0.87915 0.34443 0), color(display-p3 0.88358 0.38509 0), color(display-p3 0.88645 0.42424 0), color(display-p3 0.88787 0.46214 0), color(display-p3 0.88795 0.49895 0), color(display-p3 0.88682 0.53474 0), color(display-p3 0.88463 0.56955 0.00893), color(display-p3 0.88154 0.60342 0.09436), color(display-p3 0.87773 0.63633 0.15435), color(display-p3 0.87339 0.66828 0.20709), color(display-p3 0.86872 0.69925 0.25696), color(display-p3 0.86396 0.72924 0.30547))"}

Angles are adjusted so that `θ₂ - θ₁` ∈ \[-180, 180\]. In
pseudo-Javascript:

``` highlight
if (θ₂ - θ₁ > 180) {
 θ₁ += 360;
}
else if (θ₂ - θ₁ < -180) {
 θ₂ += 360;
}
```

#### [13.5.2. ][ [longer]]
Hue angles are interpolated to take the *longer* of the two arcs between
the starting and ending hues.

For example, the midpoint when interpolating in OkLCh from a red
 oklch(0.6 0.24 30)
to a yellow  oklch(0.8 0.15 90) would be
at a hue angle of (30 + 360 + 90) \* 0.5 = 240 degrees, along the longer
arc between the two colors, giving a sky blue  oklch(0.7 0.195 240)

::: {style="width: 100%; height: 5em; background:linear-gradient(to right, color(display-p3 0.85564 0.2067 0.1305), color(display-p3 0.85667 0.20594 0.15629), color(display-p3 0.85754 0.20544 0.17925), color(display-p3 0.85825 0.2052 0.2003), color(display-p3 0.8588 0.2052 0.21997), color(display-p3 0.8592 0.20546 0.23859), color(display-p3 0.85944 0.20595 0.25639), color(display-p3 0.85953 0.20669 0.27354), color(display-p3 0.85946 0.20765 0.29014), color(display-p3 0.85924 0.20884 0.3063), color(display-p3 0.85887 0.21024 0.32207), color(display-p3 0.85835 0.21184 0.33752), color(display-p3 0.85768 0.21364 0.35269), color(display-p3 0.85686 0.21562 0.36761), color(display-p3 0.8559 0.21778 0.38231), color(display-p3 0.85478 0.2201 0.39681), color(display-p3 0.85353 0.22257 0.41114), color(display-p3 0.85213 0.22518 0.4253), color(display-p3 0.85059 0.22793 0.43932), color(display-p3 0.84891 0.23081 0.4532), color(display-p3 0.84708 0.23379 0.46694), color(display-p3 0.84512 0.23689 0.48057), color(display-p3 0.84303 0.24008 0.49407), color(display-p3 0.84079 0.24336 0.50746), color(display-p3 0.83843 0.24672 0.52075), color(display-p3 0.83593 0.25016 0.53392), color(display-p3 0.83329 0.25366 0.54698), color(display-p3 0.83053 0.25723 0.55994), color(display-p3 0.82764 0.26086 0.57279), color(display-p3 0.82462 0.26454 0.58554), color(display-p3 0.82148 0.26826 0.59818), color(display-p3 0.81821 0.27203 0.61071), color(display-p3 0.81482 0.27584 0.62313), color(display-p3 0.8113 0.27969 0.63543), color(display-p3 0.80767 0.28357 0.64763), color(display-p3 0.80391 0.28748 0.6597), color(display-p3 0.80004 0.29142 0.67166), color(display-p3 0.79605 0.29539 0.68349), color(display-p3 0.79195 0.29938 0.6952), color(display-p3 0.78773 0.3034 0.70677), color(display-p3 0.7834 0.30744 0.71822), color(display-p3 0.77895 0.31151 0.72953), color(display-p3 0.7744 0.31559 0.7407), color(display-p3 0.76973 0.3197 0.75173), color(display-p3 0.76496 0.32383 0.76261), color(display-p3 0.76008 0.32798 0.77334), color(display-p3 0.75509 0.33215 0.78391), color(display-p3 0.75 0.33634 0.79433), color(display-p3 0.74481 0.34056 0.80459), color(display-p3 0.73951 0.34479 0.81468), color(display-p3 0.73411 0.34905 0.8246), color(display-p3 0.7286 0.35334 0.83435), color(display-p3 0.723 0.35764 0.84392), color(display-p3 0.71729 0.36198 0.85331), color(display-p3 0.71149 0.36633 0.86252), color(display-p3 0.70558 0.37072 0.87154), color(display-p3 0.69958 0.37513 0.88037), color(display-p3 0.69348 0.37956 0.88901), color(display-p3 0.68728 0.38403 0.89745), color(display-p3 0.68098 0.38852 0.90568), color(display-p3 0.67459 0.39304 0.91371), color(display-p3 0.6681 0.39759 0.92154), color(display-p3 0.66151 0.40217 0.92915), color(display-p3 0.65483 0.40678 0.93655), color(display-p3 0.64805 0.41142 0.94374), color(display-p3 0.64117 0.41609 0.95071), color(display-p3 0.6342 0.42079 0.95745), color(display-p3 0.62713 0.42552 0.96397), color(display-p3 0.61996 0.43029 0.97026), color(display-p3 0.61269 0.43508 0.97633), color(display-p3 0.60533 0.4399 0.98216), color(display-p3 0.59786 0.44475 0.98777), color(display-p3 0.5903 0.44962 0.99313), color(display-p3 0.58263 0.45453 0.99827), color(display-p3 0.57486 0.45946 1), color(display-p3 0.56699 0.46442 1), color(display-p3 0.55901 0.46941 1), color(display-p3 0.55093 0.47441 1), color(display-p3 0.54274 0.47945 1), color(display-p3 0.53444 0.4845 1), color(display-p3 0.52603 0.48958 1), color(display-p3 0.51751 0.49467 1), color(display-p3 0.50886 0.49978 1), color(display-p3 0.50011 0.50491 1), color(display-p3 0.49122 0.51005 1), color(display-p3 0.48222 0.5152 1), color(display-p3 0.47308 0.52037 1), color(display-p3 0.46381 0.52554 1), color(display-p3 0.45441 0.53072 1), color(display-p3 0.44486 0.53591 1), color(display-p3 0.43517 0.5411 1), color(display-p3 0.42532 0.54629 1), color(display-p3 0.41532 0.55147 1), color(display-p3 0.40514 0.55666 1), color(display-p3 0.39479 0.56184 1), color(display-p3 0.38426 0.56701 1), color(display-p3 0.37352 0.57217 1), color(display-p3 0.36258 0.57731 1), color(display-p3 0.35142 0.58245 1), color(display-p3 0.34002 0.58756 1), color(display-p3 0.32836 0.59266 1), color(display-p3 0.31642 0.59773 1), color(display-p3 0.30418 0.60278 1), color(display-p3 0.2916 0.60781 1), color(display-p3 0.27864 0.6128 1), color(display-p3 0.26526 0.61777 1), color(display-p3 0.2514 0.6227 1), color(display-p3 0.237 0.62759 1), color(display-p3 0.22194 0.63245 1), color(display-p3 0.20612 0.63727 1), color(display-p3 0.18935 0.64204 1), color(display-p3 0.17139 0.64678 1), color(display-p3 0.15187 0.65146 1), color(display-p3 0.13019 0.6561 1), color(display-p3 0.10523 0.66069 1), color(display-p3 0.07454 0.66522 0.99755), color(display-p3 0.03037 0.6697 0.99279), color(display-p3 0 0.67412 0.98785), color(display-p3 0 0.67849 0.98273), color(display-p3 0 0.6828 0.97743), color(display-p3 0 0.68704 0.97197), color(display-p3 0 0.69122 0.96634), color(display-p3 0 0.69534 0.96054), color(display-p3 0 0.69939 0.95458), color(display-p3 0 0.70337 0.94847), color(display-p3 0 0.70728 0.94221), color(display-p3 0 0.71112 0.93581), color(display-p3 0 0.71489 0.92925), color(display-p3 0 0.71859 0.92257), color(display-p3 0 0.72221 0.91574), color(display-p3 0 0.72576 0.90879), color(display-p3 0 0.72923 0.90171), color(display-p3 0 0.73262 0.89451), color(display-p3 0 0.73593 0.88719), color(display-p3 0 0.73916 0.87975), color(display-p3 0 0.74231 0.87221), color(display-p3 0 0.74538 0.86457), color(display-p3 0 0.74837 0.85682), color(display-p3 0 0.75127 0.84898), color(display-p3 0 0.75409 0.84105), color(display-p3 0 0.75683 0.83303), color(display-p3 0 0.75948 0.82492), color(display-p3 0 0.76204 0.81674), color(display-p3 0 0.76452 0.80848), color(display-p3 0 0.76692 0.80016), color(display-p3 0 0.76922 0.79176), color(display-p3 0 0.77144 0.78331), color(display-p3 0 0.77358 0.7748), color(display-p3 0 0.77562 0.76623), color(display-p3 0 0.77758 0.75762), color(display-p3 0 0.77945 0.74896), color(display-p3 0 0.78124 0.74025), color(display-p3 0 0.78294 0.73152), color(display-p3 0 0.78455 0.72274), color(display-p3 0 0.78607 0.71394), color(display-p3 0.02324 0.78751 0.70512), color(display-p3 0.07355 0.78886 0.69627), color(display-p3 0.10755 0.79012 0.6874), color(display-p3 0.13486 0.7913 0.67853), color(display-p3 0.15854 0.79239 0.66964), color(display-p3 0.17986 0.7934 0.66074), color(display-p3 0.19954 0.79433 0.65185), color(display-p3 0.21797 0.79517 0.64295), color(display-p3 0.23542 0.79593 0.63406), color(display-p3 0.2521 0.7966 0.62518), color(display-p3 0.26812 0.79719 0.61632), color(display-p3 0.2836 0.7977 0.60747), color(display-p3 0.2986 0.79814 0.59864), color(display-p3 0.31319 0.79849 0.58983), color(display-p3 0.32742 0.79876 0.58105), color(display-p3 0.34132 0.79895 0.5723), color(display-p3 0.35492 0.79907 0.56359), color(display-p3 0.36826 0.79911 0.55492), color(display-p3 0.38136 0.79907 0.54629), color(display-p3 0.39423 0.79896 0.53771), color(display-p3 0.40688 0.79878 0.52918), color(display-p3 0.41934 0.79852 0.5207), color(display-p3 0.43162 0.7982 0.51228), color(display-p3 0.44372 0.7978 0.50393), color(display-p3 0.45565 0.79733 0.49565), color(display-p3 0.46742 0.7968 0.48743), color(display-p3 0.47904 0.7962 0.4793), color(display-p3 0.49051 0.79554 0.47124), color(display-p3 0.50184 0.79481 0.46327), color(display-p3 0.51303 0.79401 0.4554), color(display-p3 0.52409 0.79316 0.44762), color(display-p3 0.53502 0.79225 0.43994), color(display-p3 0.54582 0.79127 0.43238), color(display-p3 0.55649 0.79024 0.42492), color(display-p3 0.56704 0.78916 0.41759), color(display-p3 0.57747 0.78802 0.41039), color(display-p3 0.58778 0.78682 0.40333), color(display-p3 0.59797 0.78558 0.3964), color(display-p3 0.60805 0.78429 0.38963), color(display-p3 0.61801 0.78295 0.38301), color(display-p3 0.62785 0.78156 0.37657), color(display-p3 0.63758 0.78013 0.3703), color(display-p3 0.6472 0.77865 0.36421), color(display-p3 0.6567 0.77713 0.35832), color(display-p3 0.66609 0.77558 0.35263), color(display-p3 0.67537 0.77398 0.34716), color(display-p3 0.68454 0.77235 0.34192), color(display-p3 0.69359 0.77068 0.33691), color(display-p3 0.70253 0.76899 0.33215), color(display-p3 0.71136 0.76726 0.32764), color(display-p3 0.72008 0.7655 0.32341), color(display-p3 0.72869 0.76372 0.31946), color(display-p3 0.73718 0.76191 0.3158), color(display-p3 0.74556 0.76007 0.31244), color(display-p3 0.75382 0.75822 0.30939), color(display-p3 0.76198 0.75635 0.30667), color(display-p3 0.77001 0.75446 0.30427), color(display-p3 0.77794 0.75255 0.30222), color(display-p3 0.78575 0.75063 0.30051), color(display-p3 0.79344 0.7487 0.29915), color(display-p3 0.80102 0.74676 0.29816), color(display-p3 0.80849 0.74482 0.29752), color(display-p3 0.81583 0.74287 0.29725), color(display-p3 0.82306 0.74091 0.29734), color(display-p3 0.83017 0.73896 0.2978), color(display-p3 0.83717 0.737 0.29862), color(display-p3 0.84405 0.73505 0.29981), color(display-p3 0.8508 0.7331 0.30135), color(display-p3 0.85744 0.73117 0.30324), color(display-p3 0.86396 0.72924 0.30547))"}

Angles are adjusted so that `θ₂ - θ₁` ∈ {(-360, -180\],
\[180, 360)}. In pseudo-Javascript:

``` highlight
if (0 < θ₂ - θ₁ < 180) {
 θ₁ += 360;
}
else if (-180 < θ₂ - θ₁ <= 0) {
 θ₂ += 360;
}
```

#### [13.5.3. ][ [increasing]]
Hue angles are interpolated so that, as they progress from the first
color to the second, the angle is always *increasing*. If the angle
increases to 360 it is reset to zero, and then continues increasing.

Depending on the difference between the two angles, this will either
look the same as *shorter* or as *longer.* However, if one of the hue
angles is being animated, and the hue angle difference passes through
180 degrees, the interpolation will not flip to the other arc.

For example, the midpoint when interpolating in OkLCh from a deep brown
 oklch(0.5 0.1 30)
to a turquoise  oklch(0.7 0.1 190) would be
at a hue angle of (30 + 190) \* 0.5 = 110 degrees, giving a khaki
 oklch(0.6 0.1
110).

::: {style="width: 100%; height: 5em; background: linear-gradient(to right, color(display-p3 0.54199 0.30934 0.26448), color(display-p3 0.55468 0.33447 0.23887), color(display-p3 0.56187 0.36244 0.21736), color(display-p3 0.56349 0.39269 0.20288), color(display-p3 0.55963 0.42453 0.19879), color(display-p3 0.55051 0.45724 0.20779), color(display-p3 0.53651 0.4901 0.23046), color(display-p3 0.51821 0.52242 0.26531), color(display-p3 0.49644 0.55355 0.30991), color(display-p3 0.47232 0.58292 0.36193), color(display-p3 0.44742 0.61005 0.41942), color(display-p3 0.4238 0.63453 0.48072), color(display-p3 0.40417 0.65606 0.54429), color(display-p3 0.39164 0.67448 0.60863), color(display-p3 0.3893 0.68974 0.67222))"}

However, if the hue of the second color is animated to  oklch(0.7 0.1 230), the
midpoint of the interpolation will be (30 + 230) \* 0.5 = 130 degrees,
continuing in the same increasing direction, giving another green
 oklch(0.6 0.1
130) rather than flipping to the opponent color part-way through the
animation.

::: {style="width: 100%; height: 5em; background: linear-gradient(to right, color(display-p3 0.54199 0.30934 0.26448), color(display-p3 0.54838 0.32269 0.2462), color(display-p3 0.55265 0.3372 0.22912), color(display-p3 0.55477 0.35276 0.2138), color(display-p3 0.55473 0.36922 0.20096), color(display-p3 0.55255 0.38642 0.19142), color(display-p3 0.54827 0.40419 0.18607), color(display-p3 0.54193 0.42235 0.18568), color(display-p3 0.53362 0.44072 0.19077), color(display-p3 0.52343 0.45911 0.20138), color(display-p3 0.51148 0.47737 0.21721), color(display-p3 0.49794 0.49532 0.23765), color(display-p3 0.48299 0.51282 0.26203), color(display-p3 0.46685 0.52972 0.28969), color(display-p3 0.44982 0.54588 0.32004), color(display-p3 0.43223 0.5612 0.3526), color(display-p3 0.41451 0.57556 0.38691), color(display-p3 0.39715 0.58887 0.42259), color(display-p3 0.38079 0.60107 0.45928), color(display-p3 0.36614 0.61209 0.4966), color(display-p3 0.35401 0.62189 0.53422), color(display-p3 0.34525 0.63046 0.57177), color(display-p3 0.34069 0.6378 0.60889), color(display-p3 0.34095 0.64393 0.64523), color(display-p3 0.34643 0.64888 0.68042), color(display-p3 0.35714 0.65272 0.71412), color(display-p3 0.3728 0.65554 0.74598), color(display-p3 0.39286 0.65743 0.77568), color(display-p3 0.41667 0.65849 0.80292))"}

Angles are adjusted so that `θ₂ - θ₁` ∈ \[0, 360). In
pseudo-Javascript:

``` highlight
if (θ₂ < θ₁) {
 θ₂ += 360;
}
```

#### [13.5.4. ][ [decreasing]]
Hue angles are interpolated so that, as they progress from the first
color to the second, the angle is always *decreasing*. If the angle
decreases to 0 it is reset to 360, and then continues decreasing.

Depending on the difference between the two angles, this will either
look the same as *shorter* or as *longer.* However, if one of the hue
angles is being animated, and the hue angle difference passes through
180 degrees, the interpolation will not flip to the other arc.

For example, the midpoint when interpolating in OkLCh from a deep brown
 oklch(0.5 0.1 30)
to a turquoise  oklch(0.7 0.1 190) would be
at a hue angle of (30 + 360 + 190) \* 0.5 = 290 degrees, giving a purple
 oklch(0.6 0.1
290).

::: {style="width: 100%; height: 5em; background: linear-gradient(to right, color(display-p3 0.54199 0.30934 0.26448), color(display-p3 0.55783 0.31818 0.33366), color(display-p3 0.56548 0.33196 0.40432), color(display-p3 0.56507 0.35041 0.47454), color(display-p3 0.55696 0.37309 0.54199), color(display-p3 0.54171 0.39951 0.60414), color(display-p3 0.52008 0.42921 0.6585), color(display-p3 0.49308 0.46166 0.70284), color(display-p3 0.46215 0.4962 0.7354), color(display-p3 0.4294 0.53195 0.75506), color(display-p3 0.39801 0.56785 0.76144), color(display-p3 0.37269 0.6027 0.7549), color(display-p3 0.35949 0.63532 0.73659), color(display-p3 0.36418 0.66463 0.70825), color(display-p3 0.3893 0.68974 0.67222))"}

However, if the hue of the second color is animated to  oklch(0.7 0.1 230), the
midpoint of the interpolation will be (30 + 360 + 230) \* 0.5 = 310
degrees, continuing in the same decreasing direction, giving another
purple  oklch(0.6
0.1 310) rather than flipping to the opponent color part-way through the
animation.

::: {style="width: 100%; height: 5em; background: linear-gradient(to right, color(display-p3 0.54199 0.30934 0.26448), color(display-p3 0.55881 0.31921 0.32275), color(display-p3 0.5704 0.33226 0.38231), color(display-p3 0.57674 0.34842 0.44229), color(display-p3 0.57793 0.3675 0.50159), color(display-p3 0.57416 0.38928 0.55894), color(display-p3 0.56573 0.41352 0.613), color(display-p3 0.553 0.44 0.66246), color(display-p3 0.53648 0.46847 0.70607), color(display-p3 0.51682 0.49862 0.74276), color(display-p3 0.49493 0.53008 0.77168), color(display-p3 0.47202 0.56237 0.79226), color(display-p3 0.44976 0.59494 0.80424), color(display-p3 0.43039 0.6272 0.80767), color(display-p3 0.41667 0.65849 0.80292))"}

Angles are adjusted so that `θ₂ - θ₁` ∈ (-360, 0\]. In
pseudo-Javascript:

``` highlight
if (θ₁ < θ₂) {
 θ₁ += 360;
}
```

## 14. Gamut Mapping

### 14.1. An Introduction to Gamut Mapping

 This section provides important context for the
specific requirements described elsewhere in the document.

*This section is non-normative*

Tests

This section is not normative, it does not need tests.

------------------------------------------------------------------------

When a color in an origin color space is converted to another,
destination color space which has a smaller gamut, some colors will be
outside the destination gamut.

For intermediate color calculations, these out of gamut values are
preserved. However, if the destination is the display device (a screen,
or a printer) then out of gamut values must be converted to an in-gamut
color.

Gamut mapping is the process of finding an in-gamut color with the least
objectionable change in visual appearance.

Some out of gamut colors correspond to real-world colors (they could be
physically reproduced) while others are imaginary colors (they lie
outside the spectral locus and thus would need more than 100% of a
single wavelength) and could never be physically realized. Those colors
tend to come from calculations such as \"make this color 100x as
saturated\".

For example, while theoretically
unbounded, the CIE Lab *(a,b)* plane is often implemented such that *a*
and *b* are constrained to the range ±127.

Three of those four corners are outside the spectral locus and thus
correspond to imaginary colors.

<figure id="fig-lab-corners">

<figcaption>The four corners of the ±127 (a,b) plane, on a UCS
chromaticity diagram. The outer shape is the spectral locus. The larger
triangle is the rec2020 gamut, while the smaller is sRGB.</figcaption>
</figure>

#### 14.1.1. Clipping

The simplest and least acceptable method is simply to clip the component
values to the displayable range.

Since the motivation for this method is speed, clipping is commonly done
on gamma-encoded values rather than converting them to linear-light.

This changes the proportions of the three primary colors (for an RGB
display), resulting in a hue shift.

For example, consider the color
`color(srgb-linear 0.5 1 3)`. Because this is a linear-light
color space, we can compare the intensities of the three components and
see that the amount of blue light is three times the amount of green,
while the amount of red light is half that of green. There is six times
as much blue primary as red. In OkLCh, this color has a hue angle of
265.1°

If we now clip this color to bring it into gamut for sRGB, we get
`color(srgb-linear 0.5 1 1)`. The amount of blue light is
the same as green. In OkLCh, this color has a hue angle of 196.1°, a
substantial change of 69°.

When colors are not too far out of gamut, clipping can give acceptable
results. This is particularly true for darker (or negative) component
values.

For example, consider the color
`color(rec2020 0.54 0.9 0)` which is
`oklch(80.72% 0.3296 141.6)`.

Converting to p3 colorspace, the negative blue value shows the color is
out of gamut: `color(display-p3 0.3265 0.9165 -0.1262)`
which in linear-light is
`color(display-p3-linear 0.0871 0.8205 -0.0146)`.

Clipping the gamma-encoded p3 color to the p3 gamut gives
`color(display-p3 0.3265 0.9165 0)` which in linear-light is
`color(display-p3-linear 0.0871 0.8205 0)` which, for
comparison, is `oklch(80.79% 0.3221 142.3)`.

This is a good result; the hue angle and lightness have barely changed
but the chroma is somewhat reduced, as expected.

In terms of percentages of linear-light red green and blue, the red and
green are identical while the blue is -1.46% higher.

For example, consider the
color `color(prophoto-rgb 0.2 1.0 0.1)` which is
`oklch(85.07% 0.4873 151.4)`

Converting to p3 colorspace, the color is significantly out of gamut:
`color(display-p3 -0.5782 1.067 -0.2363)` which in
linear-light is
`color(display-p3-linear -0.2937 1.158 -0.0456)`.

Clipping the gamma-encoded p3 color to the p3 gamut gives
`color(display-p3 0 1 0)` which in linear-light is, again,
`color(display-p3-linear 0 1 0)` (component values of
exactly 0 or 1 are unaffected by gamma encoding) which, for comparison,
is `oklch(84.88% 0.3685 145.6)`.

A less good but still visually acceptable result. Here the hue is more
affected, a 5.8° change.

In terms of percentages of linear-light red green and blue, red is 57%
higher, green is 6.7% lower and blue is 23% higher.

#### 14.1.2. Closest Color (MINDE)

A better method is to map colors, in a perceptually uniform color space,
by finding the closest in-gamut color (so-called minimum ΔE or
[MINDE]). Clearly,
the success of this technique depends on the degree of uniformity of the
gamut mapping color space and the predictive accuracy of the deltaE
function used.

However, when doing gamut mapping changes in Hue are *particularly*
objectionable; changes in Chroma are more tolerable, and small changes
in Lightness can also be acceptable especially if the alternative is a
larger Chroma reduction. MINDE weights changes in each dimension
equally, and thus gives suboptimal results.

#### 14.1.3. Chroma Reduction

To implement MINDE, colors are mapped in a perceptually uniform, *polar*
color space by holding the hue constant, and reducing the chroma until
the color falls in gamut.

This could be done *algorithmically* by finding the geometric
intersection of a constant-lightness, constant-hue ray with the gamut
boundary; or *iteratively*, reducing the chroma until it falls in gamut.

 For performance reasons, iteration is typically
performed by binary search.

In this example, Display
P3 primary yellow (`color(display-p3 1 1 0)`) is being
mapped to an sRGB display. The gamut mapping color space is OkLCh.

```
color(display-p3 1 1 0)
```

is

```
color(srgb 1 1 -0.3463)
```

which is

```
color(oklch 0.96476 0.24503 110.23)
```

By progressively reducing the chroma component until the resulting color
falls inside the sRGB gamut (has no components negative, or greater than
one) a gamut mapped color is obtained.

```
 color(oklch 0.96476 0.21094 110.23)
```

which is

```
 color(srgb 0.99116 0.99733 0.00001)
```

![A constant-hue slice of OkLCh color space. The vertical axis
represents lightness, the horizontal axis is chroma. The color to be
mapped, shown as a yellow circle, has the chroma reduced while keeping
hue and lightness constant. The color therefore moves along the maroon
line in the diagram, towards the neutral axis on the left. The gamut
boundary of sRGB is shown in
green.](images/slice-ok-110.23.svg)

#### 14.1.4. Excessive Chroma Reduction

Also, this simple MINDE approach will give sub-optimal results for
certain colors, principally very light colors like yellow and cyan, if
the upper edge of the gamut boundary is shallow, or even slightly
concave. The line of constant lightness can skim just above the gamut
boundary, resulting in an excessively low chroma in those cases.

The choice of color space will affect the acceptability of the gamut
mapped colors.

In this example, Display P3
primary yellow (`color(display-p3 1 1 0`) has the chroma
progressively reduced in CIE LCH color space.

![In the upper part of this diagram, colors which are inside the gamut
of sRGB are displayed as-is. Colors inside the gamut of Display P3 (but
outside sRGB) are in salmon. Colors outside the gamut of Display P3 are
in red. The lower part of the diagram shows the linear-light intensities
of the Display P3 red, green and blue
components.](images/lab-yellow-LCH-fade.svg)

It can be seen that reduction in CIE LCH chroma makes the red intensity
curve up, out of Display P3 gamut; by the time it falls again the chroma
is very low. Simple gamut mapping in CIE LCH would give unsatisfactory
results.

In this example, Display P3
primary yellow (`color(display-p3 1 1 0`) has the chroma
progressively reduced, but this time in OkLCh color space.

![In the upper part of this diagram, colors which are inside the gamut
of sRGB are displayed as-is. Colors inside the gamut of Display P3 (but
outside sRGB) are in salmon. Colors outside the gamut of Display P3 are
in red. The lower part of the diagram shows the linear-light intensities
of the Display P3 red, green and blue
components.](images/p3-yellow-oklab.svg)

It can be seen that reduction in OkLCh chroma is better behaved. Colors
do not go outside the Display P3 gamut, and the resulting gamut-mapped
yellow has good chroma. Simple gamut mapping in OK LCH would give
acceptable results.

#### 14.1.5. Chroma Reduction with Local Clipping

The simple chroma-reduction algorithm can be improved: at each step, the
color difference is computed between the current mapped color and a
clipped version of that color. If the current color is outside the gamut
boundary, but the color difference between it and the clipped version is
below the threshold for a *just noticeable difference* (JND), the
clipped version of the color is returned as the mapped result.
Effectively, this is doing a MINDE mapping at each stage, but
constrained so the hue and lightness changes are very small, and thus
are not noticeable.

In this example, Display P3
primary yellow (`color(display-p3 1 1 0`) has the chroma
progressively reduced in CIE LCH color space, with the local clip
modification.

![In the upper part of this diagram, colors which are inside the gamut
of sRGB are displayed as-is. Colors inside the gamut of Display P3 (but
outside sRGB) are in salmon. Colors outside the gamut of Display P3 are
in red. The lower part of the diagram shows the linear-light intensities
of the Display P3 red, green and blue
components.](images/lab-yellow-LCH-clip-fade.svg)

It can be seen that reduction in CIE LCH chroma still makes the red
intensity curve up, out of Display P3 gamut; but less than before and
the sRGB boundary is found much more quickly. Gamut mapping in CIE LCH
with local clip would give acceptable results.

In this example, Display P3
primary yellow (`color(display-p3 1 1 0`) has the chroma
progressively reduced, but this time in OkLCh color space and with the
local clip modification.

![In the upper part of this diagram, colors which are inside the gamut
of sRGB are displayed as-is. Colors inside the gamut of Display P3 (but
outside sRGB) are in salmon. Colors outside the gamut of Display P3 are
in red. The lower part of the diagram shows the linear-light intensities
of the Display P3 red, green and blue
components.](images/p3-yellow-oklab-clip.svg)

It can be seen that reduction in OkLCh chroma, which was already good,
is further improved by the local clip modification. Simple gamut mapping
in CIE LCH with local clip would give excellent results.

#### 14.1.6. Deviations from Perceptual Uniformity: Hue Curvature

Performing gamut mapping in the CIE LCH color space even with the
deltaE2000 distance metric, is known to give suboptimal results with
significant hue shifts, for colors in the hue range 270° to 330°.

![A constant-hue slice of CIE LCH color space, at a hue angle of 301.37°
corresponding to sRGB primary blue. The vertical axis is Lightness, the
horizontal axis is Chroma. Between chroma of 25 and 75, the hue is
visibly purple, becoming more blue between 100 and 131. The same
phenomenon continues past 131, but cannot be shown on an sRGB
display.](images/CIELCH-blue-slice.png)

Using OkLCh color space and the deltaEOK distance metric avoids this
issue at all hue angles.

![A constant-hue slice of OkLCh color space, at a hue angle of 264.06°
corresponding to sRGB primary blue. The vertical axis is Lightness, the
horizontal axis is Chroma. The hue is visibly the same at all values of
chroma, up to 0.315 (the sRGB limit at this hue). It continues to be
constant beyond this point, although that cannot be shown on an sRGB
diagram.](images/OKLCH-blue-slice.png)

### 14.2. CSS Gamut Mapping to an RGB Destination

Tests

Actual values of color are not exposed to script, making this hard to
test in an automated manner. A choice of three algorithms also makes
this harder to test

------------------------------------------------------------------------

The three [CSS gamut mapping algorithms] apply to Standard Dynamic
Range (SDR) CSS colors which are out of gamut of:

- an RGB display (which cannot represent out of gamut values in the
 frame buffer)
- a canvas, with
 [unorm8](https://html.spec.whatwg.org/multipage/canvas.html#dom-canvascolortype-unorm8)
 backing store (thus, unable to store out of gamut values)

They thus require to be [css gamut mapped].

For example, given a Display P3
screen, attempting to display the color color(display-p3 1.1 0.4 0.2)
will trigger gamut mapping, because the red coordinate is outside the
range 0 to 1; gamut mapping will produce a similar, but lower chroma,
color, such as  color(display-p3 1
0.473 0.314).

For example, given a 2d context with
colorSpace set to \"display-p3\" and colorType set to \"unorm8\";
attempting to paint the color oklch(76% 0.27 60) will trigger gamut
mapping, because once converted to Display P3, the value
color(display-p3 1.062 0.4954 -0.3115) has a red coordinate greater than
1 and a negative blue coordinate. Gamut mapping will produce a similar,
but lower chroma, color, such as  color(display-p3 1 0.546 0).

Implementations my choose any of the three algorithms based on their
quality and runtime efficiency tradeoffs, and must use their chosen
algorithm wherever CSS mandates that gamut mapping be performed.

- [Binary Search Gamut Mapping with Local
 MINDE](#GMA-Binary-local-MINDE)
- [EdgeSeeker Gamut Mapping](#GMA-EdgeSeeker)
- [Ray Trace Gamut Mapping](#GMA-Raytrace)

They all implement a **relative colorimetric intent**, thus colors
inside the destination gamut are **unchanged**.

 other situations, in particular mapping to printer
gamuts where the maximum black level is significantly above zero, will
require different algorithms which align the respective black and white
points, which will result in lightness changes for very light and very
dark colors as chroma is reduced.

 these algorithms are for individuallly specified
colors, used either singly (on page elements) or in combination (as with
gradients); for photographic images, where relationships between
neighboring pixels are important and the aim is to preserve detail and
texture, a **perceptual rendering intent** is more appropriate and in
that case, colors *inside* the destination gamut **could be changed**.

All three CSS gamut mapping algorithms aim at constant-lightness,
constant-hue chroma reduction in the [OkLCh color space](#ok-lab).

For colors which are out of range on the Lightness axis, white is
returned in the destination color space if the Lightness is greater than
or equal to 1.0, while black is returned in the destination color space
if the Lightness is less than or equal to 0.0.

Tests

- [canvas-display-p3-gamut-mapping.html](https://wpt.fyi/results/css/css-color/canvas-display-p3-gamut-mapping.html "css/css-color/canvas-display-p3-gamut-mapping.html")
 [[(live
 test)]](http://wpt.live/css/css-color/canvas-display-p3-gamut-mapping.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/canvas-display-p3-gamut-mapping.html)
- [canvas-srgb-gamut-mapping.html](https://wpt.fyi/results/css/css-color/canvas-srgb-gamut-mapping.html "css/css-color/canvas-srgb-gamut-mapping.html")
 [[(live
 test)]](http://wpt.live/css/css-color/canvas-srgb-gamut-mapping.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/canvas-srgb-gamut-mapping.html)
- [lch-009.html](https://wpt.fyi/results/css/css-color/lch-009.html "css/css-color/lch-009.html")
 [[(live
 test)]](http://wpt.live/css/css-color/lch-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/lch-009.html)
- [lch-010.html](https://wpt.fyi/results/css/css-color/lch-010.html "css/css-color/lch-010.html")
 [[(live
 test)]](http://wpt.live/css/css-color/lch-010.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/lch-010.html)
- [lch-l-over-100-1.html](https://wpt.fyi/results/css/css-color/lch-l-over-100-1.html "css/css-color/lch-l-over-100-1.html")
 [[(live
 test)]](http://wpt.live/css/css-color/lch-l-over-100-1.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/lch-l-over-100-1.html)
- [lch-l-over-100-2.html](https://wpt.fyi/results/css/css-color/lch-l-over-100-2.html "css/css-color/lch-l-over-100-2.html")
 [[(live
 test)]](http://wpt.live/css/css-color/lch-l-over-100-2.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/lch-l-over-100-2.html)
- [oklch-009.html](https://wpt.fyi/results/css/css-color/oklch-009.html "css/css-color/oklch-009.html")
 [[(live
 test)]](http://wpt.live/css/css-color/oklch-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/oklch-009.html)
- [oklch-010.html](https://wpt.fyi/results/css/css-color/oklch-010.html "css/css-color/oklch-010.html")
 [[(live
 test)]](http://wpt.live/css/css-color/oklch-010.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/oklch-010.html)

#### 14.2.1. Binary Search Gamut Mapping with Local MINDE

For this binary search algorithm, the color difference formula used is
[deltaEOK](#color-difference-OK). The
[local-MINDE](#GM-chroma-local-MINDE) improvement is used. At each step
in the search, the deltaEOK is computed between the current mapped color
and a clipped version of that color.

If the current color is *outside* the gamut boundary, but the deltaEOK
between it and the clipped version is below a threshold for a *just
noticeable difference* (JND), the clipped version of the color is
returned as the mapped result. This gives good results with
non-notivceable hue shifts, and avoids excessive chroma reduction near
concave gamut surfaces, but can be computationally intensive.

For the OkLCh color space, one JND is is an OkLCh difference of 0.02.

 In CIE Lab color space, where the range of the
Lightness component is 0 to 100, using deltaE2000, one JND is 2. Because
the range of Lightness in Oklab and OkLCh is 0 to 1, using deltaEOK, one
JND is 100 times smaller.

 for the purposes of experimentation, and comparing
implementations, implementations of the Binary Search with Local MINDE
algorithm are available in the Coloriade library (in Python)
[\[Coloraide-MINDE\]](#biblio-coloraide-minde "OkLCh Chroma")
and the color.js library (in JavaScript)
[\[colorjs-MINDE\]](#biblio-colorjs-minde "Gamut mapping").

#### 14.2.2. Sample Pseudocode for the Binary Search Gamut Mapping with Local MINDE

To [Binary Search Gamut Map with Local
MINDE] a color `origin` in color space
`origin color space` to be in gamut of a destination color
space `destination`:

1. if `destination` has no gamut limits (XYZ-D65, XYZ-D50,
 Lab, LCH, Oklab, OkLCh) convert `origin` to
 `destination` and return it as the gamut mapped color
2. let `origin_OkLCh` be `origin` converted from
 `origin color space` to the OkLCh color space
3. if the Lightness of `origin_OkLCh` is greater than or
 equal to 100%, convert \`oklab(1 0 0 / origin.alpha)\` to
 `destination` and return it as the gamut mapped color
4. if the Lightness of `origin_OkLCh` is less than than or
 equal to 0%, convert \`oklab(0 0 0 / origin.alpha)\` to
 `destination` and return it as the gamut mapped color
5. let inGamut(`color`) be a function which returns true if,
 when passed a color, that color is inside the gamut of
 `destination`. For HSL and HWB, it returns true if the
 color is inside the gamut of sRGB.
6. if inGamut(`origin_OkLCh`) is true, convert
 `origin_OkLCh` to `destination` and return it
 as the gamut mapped color
7. otherwise, let delta(`one`, `two`) be a
 function which returns the deltaEOK of color `one`
 compared to color `two`
8. let `JND` be 0.02
9. let `epsilon` be 0.0001
10. let clip(`color`) be a function which converts
 `color` to `destination`, clamps each
 component to the bounds of the reference range for that component
 and returns the result
11. set `current` to `origin_OkLCh`
12. set `clipped` to clip(`current`)
13. set `E` to delta(`clipped`,
 `current`)
14. if `E` \< `JND`
 1. return `clipped` as the gamut mapped color
15. set `min` to zero
16. set `max` to the OkLCh chroma of
 `origin_OkLCh`
17. let `min_inGamut` be a boolean that represents when
 `min` is still in gamut, and set it to true
18. while (`max` - `min` is greater than
 `epsilon`) repeat the following steps
 1. set `chroma` to (`min` + `max`)
 /2
 2. set the chroma component of `current` to
 `chroma`
 3. if `min_inGamut` is true and also if
 inGamut(`current`) is true, set `min` to
 `chroma` and continue to repeat these steps
 4. otherwise, carry out these steps:
 1. set `clipped` to clip(`current`)
 2. set `E` to delta(`clipped`,
 `current`)
 3. if `E` \< `JND`
 1. if (`JND` - `E` \<
 `epsilon`) return `clipped` as the
 gamut mapped color
 2. otherwise,
 1. set `min_inGamut` to false
 2. set `min` to `chroma`
 4. otherwise, set `max` to `chroma` and
 continue to repeat these steps
19. return `clipped` as the gamut mapped color

#### 14.2.3. The EdgeSeeker Gamut Mapping

The EdgeSeeker algorithm is a geometric and lookup-table-based approach,
originally developed by Alexey Ardov for the color.js library
[\[colorjs-EdgeSeeker\]](#biblio-colorjs-edgeseeker "EdgeSeeker Gamut Mapping algorithm").

For any given hue, the gamut boundary slice is represented as a curved
top section and a linear bottom section, joning at the highest chroma
point for that hue.

To initialize this algorithm, for a given target RGB space, a lookup
table (LUT) is constructed containing the highest-chroma Oklch color on
each hue slice. Linear interpolation between closest LUT values is used
to then estimate the highest-chroma color for the exact hue of each
color to be gamut mapped.

Intersection of the constant-lightness ray with the gamut boundary is
then calculated, which is fast for the lower (linear) part of the
boundary and still fairly fast for the upper (curved) portion.

This gives good results, at the expense of memory for the LUT.

#### 14.2.4. Sample Pseudocode for the EdgeSeeker Gamut Mapping

add pseudocode for EdgeSeeker GMA

#### 14.2.5. The Ray Trace Gamut Mapping

The Ray Trace algorithm is a geometric approach to RGB gamut mapping,
for fast chroma reduction with constant lightness. It was originally
developed by Isaac Muse for the Coloraide Python Library
[\[Coloraide-Ray-Trace\]](#biblio-coloraide-ray-trace "Ray Tracing Chroma Reduction").

The color to be mapped is first converted to Oklch, and then the
achromatic version of that color is generated, which will be the neutral
axis anchor. These two colors are then converted to the linear-light
version of the target RGB space.

Because the gamut boundary is now an axis-aligned cube, finding the
intersection is faster.

A ray is cast from the inside of the RGB cube, from the anchor point to
the current color. The intersection along this path with the RGB gamut
surface is then found; this is the first approximation to the gamut
mapped color.

As RGB spaces are not perceptually uniform, a constant hue, constant
lightness ray is actually a curved path in RGB space.

The first approximation is converted back to Oklch to correct the color
in the perceptual color space by projecting the point back onto the
chroma reduction path, correcting the color's hue and lightness. The
corrected color becomes the new current color and should be a much
closer color on the reduced chroma line.

This process is repeated (a maximum of three more times), each time
finding a better, closer color on the path. Finally, simple clipping is
used to account for floating point math errors.

The results are comparable to binary search with local MINDE using a low
JND, but resolves much faster and within more predictable, consistent
time.

![Ray Trace gamut mpping to the sRGB gamut, showing the curved path of
chroma reduction as approximated over a maximum of four iterations.\
Image copyright Isaac Muse.](./images/raytrace-gma.png){height="800"
width="800"}

 for the purposes of experimentation, and comparing
implementations, implementations of the Ray Trace are available in the
Coloriade library (in Python)
[\[Coloraide-Ray-Trace\]](#biblio-coloraide-ray-trace "Ray Tracing Chroma Reduction")
and the color.js library (in JavaScript)
[\[colorjs-RayTrace\]](#biblio-colorjs-raytrace "Ray Trace Gamut Mapping").

#### 14.2.6. Sample Pseudocode for the Ray Trace Gamut Mapping

To [Ray Trace Gamut Map] a color `origin` in color space
`origin color space` to be in gamut of an RGB destination
color space `destination`:

1. if `destination` has no gamut limits (XYZ-D65, XYZ-D50,
 Lab, LCH, Oklab, OkLCh) convert `origin` to
 `destination` and return it as the gamut mapped color
2. let `origin_OkLCh` be `origin` converted from
 `origin color space` to the OkLCh color space
3. if the Lightness of `origin_OkLCh` is greater than or
 equal to 100%, convert \`oklab(1 0 0 / origin.alpha)\` to
 `destination` and return it as the gamut mapped color
4. if the Lightness of `origin_OkLCh` is less than than or
 equal to 0%, convert \`oklab(0 0 0 / origin.alpha)\` to
 `destination` and return it as the gamut mapped color
5. let `l_origin` be the OkLCh lightness component of
 `origin_OkLCh`
6. let `h_origin` be the OkLCh hue component of
 `origin_OkLCh`
7. let `anchor` be an achromatic OkLCh color formed with
 `l_origin` as lightness, 0 as chroma and
 `h_origin` as hue, converted to the *linear-light* form
 of `destination`
8. let `origin_rgb` be `origin_OkLCh` converted
 to the *linear-light* form of `destination`
9. if `origin_rgb` is not in gamut
 - let `low` be 0.0 + 1E-12 [^1^](#raytrace-footnote-1)
 - let `high` be 1.0 - 1E-12 [^2^](#raytrace-footnote-2)
 - let `last` be `origin_rgb`
 - for (i=0; i\<4; i++)
 - if (i \> 0)
 - let `current_OkLCh` be `origin_rgb`
 converted to OkLCh
 - let the lightness of `current_OkLCh` be
 `l_origin`
 - let the hue of `current_OkLCh` be
 `h_origin` [^3^](#raytrace-footnote-3)
 - let `origin_rgb` be `current_OkLCh`
 converted to the *linear-light* form of
 `destination`
 - **Cast a ray** from `start` = `anchor` to
 `end` = `origin_rgb` and let
 `intersection` be the intersection of this ray with
 the gamut boundary
 - if an intersection was not found, let `origin_rgb` be
 `last` and exit the loop [^5^](#raytrace-footnote-5)
 - if (i \>0) AND (each component of `origin_rgb` is
 between `low` and `high`) then let
 `anchor` be `origin_rgb`
 [^4^](#raytrace-footnote-4)
 - let `origin_rgb` be `intersection`
 - let `last` be `intersection`
10. let clip(`color`) be a function which converts
 `color` to `destination`, clamps each
 component to the bounds of the reference range for that component
 and returns the result
11. set `clipped` to clip(`origin_rgb`)
12. return `clipped` as the gamut mapped color

To [cast a ray]
through a linear-light RGB space from `start` to
`end` (in gamut mapping, `start` is an anchor
within the RGB gamut and `end` is the gamut mapped color, on
the cubical gamut surface):

1. let `bmin` and `bmax` be 3-element arrays with
 the gamut's lower and upper bounds, respectively
 [^6^](#raytrace-footnote-6)
2. let `tfar` be infinity (or some very large number)
3. let `tnear` be -infinity (or some very large, negative
 number)
4. let `direction` be a 3-element array
5. for (i = 0; i \< 3; i++):
 - let `a` be `start` *\[i\]*
 - let `b` be `end` *\[i\]*
 - let `d` be `b` - `a`
 - let `direction` *\[i\]* be `d`
 - if abs(`d`) \> 1E-12 [^7^](#raytrace-footnote-7)
 - let `inv_d` be 1 / `d`
 - let `t1` be (`bmin` *\[i\]* -
 `a` ) \* `inv_d`
 - let `t2` be (`bmax` *\[i\]* -
 `a` ) \* `inv_d`
 - let `tnear` be max(min(`t1`,
 `t2`), `tnear` )
 - let `tfar` be min(max(`t1`,
 `t2`), `tfar` )
 - else if (`a` \< `bmin`*\[i\]* or
 `a` \> `bmax`*\[i\]*)
 - return INTERSECTION NOT FOUND
6. if (`tnear` \> `tfar` or `tfar` \<
 0)
 - return INTERSECTION NOT FOUND
7. if `tnear` \< 0
 - let `tnear` be `tfar`
 [^8^](#raytrace-footnote-8)
8. if `tnear` is infinite (or matches the initial very large
 value)
 - return INTERSECTION NOT FOUND
9. for (i =0; i \< 3; i++):
 - let `result` *\[i\]* be `start` *\[i\]* +
 `direction` *\[i\]* \* `tnear`
10. return `result`

##### 14.2.6.1. Footnotes for Ray Trace algorithm

1. [(#raytrace-footnote-1) It is assumed the minimum
 value is 0 and that all channels have the same minimum. The value
 should be small relative to the unit type. The specifed value of
 1e-12 is for 64-bit, but for 32-bit, 1e-6 should be
 used.]
2. [(#raytrace-footnote-2) 1.0 represents the maximum
 in-gamut channel value, and it is assumed all channels have the same
 maximum.]
3. [(#raytrace-footnote-3) This places the current color
 back on the chroma reduction curve, if it has
 deviated.]
4. [(#raytrace-footnote-4) This means
 `origin_rgb` is below the gamut surface, so we use it as
 an anchor closer to the gamut surface.]
5. [(#raytrace-footnote-5) This is provided for
 catastrophic failures where a specific, perceptual mapping space
 completely breaks down due to ridiculously wide colors (outside the
 visible spectrum). It is expected that non-imaginary colors in CSS
 should never trigger this.]
6. [(#raytrace-footnote-6) For typical RGB spaces where
 the gamut bounds are 0 and 1 for each component this simplifies to a
 single constant rather than a 3-element
 array.]
7. [(#raytrace-footnote-7) The value should be small
 relative to the unit type. The specifed value of 1e-12 is for
 64-bit, but for 32-bit, 1e-6 should be used.]
8. [(#raytrace-footnote-8) favoring the first
 intersection in the direction `start` -\>
 `end` .]

## 15. Resolving [\<color\> Values]
Unless otherwise specified for a particular property,
[specified](https://drafts.csswg.org/css-cascade-5/#specified-value) colors are resolved to
[[computed](https://drafts.csswg.org/css-cascade-5/#computed-value) colors] and then further to
[[used](https://drafts.csswg.org/css-cascade-5/#used-value) colors] as described below.

The [resolved
value](https://drafts.csswg.org/cssom-1/#resolved-value) of a
[\<color\>](#typedef-color) is its [used
value](https://drafts.csswg.org/css-cascade-5/#used-value).

Tests

- [color-computed-hex-color.html](https://wpt.fyi/results/css/css-color/parsing/color-computed-hex-color.html "css/css-color/parsing/color-computed-hex-color.html")
 [[(live
 test)]](http://wpt.live/css/css-color/parsing/color-computed-hex-color.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/parsing/color-computed-hex-color.html)
- [color-computed-named-color.html](https://wpt.fyi/results/css/css-color/parsing/color-computed-named-color.html "css/css-color/parsing/color-computed-named-color.html")
 [[(live
 test)]](http://wpt.live/css/css-color/parsing/color-computed-named-color.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/parsing/color-computed-named-color.html)
- [color-invalid-hex-color.html](https://wpt.fyi/results/css/css-color/parsing/color-invalid-hex-color.html "css/css-color/parsing/color-invalid-hex-color.html")
 [[(live
 test)]](http://wpt.live/css/css-color/parsing/color-invalid-hex-color.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/parsing/color-invalid-hex-color.html)
- [color-invalid-named-color.html](https://wpt.fyi/results/css/css-color/parsing/color-invalid-named-color.html "css/css-color/parsing/color-invalid-named-color.html")
 [[(live
 test)]](http://wpt.live/css/css-color/parsing/color-invalid-named-color.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/parsing/color-invalid-named-color.html)
- [system-color-compute.html](https://wpt.fyi/results/css/css-color/system-color-compute.html "css/css-color/system-color-compute.html")
 [[(live
 test)]](http://wpt.live/css/css-color/system-color-compute.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/system-color-compute.html)

### 15.1. Resolving sRGB values

This applies to:

- [hex colors](#hex-color)

- [rgb()](#funcdef-rgb)
 and [rgba()](#funcdef-rgba) values

- [hsl()](#funcdef-hsl)
 and [hsla()](#funcdef-hsla) values

- [hwb()](#funcdef-hwb)
 values

- [named colors](#named-color)

It does *not* apply to:

- [color()](#funcdef-color) values using the
 [srgb](#valdef-color-srgb) or
 [srgb-linear](#valdef-color-srgb-linear) [color
 space](#color-space)s.

If the sRGB color was explicitly specified by the author as a [named
color](#named-color), the
[declared
value](https://drafts.csswg.org/css-cascade-5/#declared-value) is that named color, converted to [ASCII
lowercase](https://infra.spec.whatwg.org/#ascii-lowercase). The computed
and used value is the corresponding sRGB color, paired with the
specified alpha component (after clamping to \[0, 1\]) and defaulting to
opaque if unspecified).

The author-provided mixed-case form below has a declared value in all
lowercase.

```
 pUrPlE

 purple
```

Otherwise, the declared, computed and used value is the corresponding
sRGB color, paired with the specified alpha component (after clamping to
\[0, 1\]) and defaulting to opaque if unspecified).

For historical reasons, when
[calc()](https://drafts.csswg.org/css-values-4/#funcdef-calc) in sRGB colors resolves to a single value, the
declared value serialises without the \"calc(\" \")\" wrapper.

For example, if a color is given
as rgb(calc(64 \* 2) 127
255) the declared value will be rgb(128 127 255) and not rgb(calc(128)
127 255).

For example, if a color is
given as hsl(38.82 calc(2
\* 50%) 50%) the declared value will be rgb(255 165.2 0) because the
[calc()](https://drafts.csswg.org/css-values-4/#funcdef-calc) is lost during HSL to RGB conversion.

Also for historical reasons, when calc() is simplified down to a single
value, the color values are clamped to \[0.0, 255.0\].

For example, if a color
is given as rgb(calc(100 \*
4) 127 calc(20 - 35)) the declared value will be rgb(255 127 0) and not
rgb(calc(400) 127 calc(-15)).

This clamping also takes care of values such as
[Infinity](https://drafts.csswg.org/css-values-4/#valdef-calc-infinity),
[-Infinity](https://drafts.csswg.org/css-values-4/#valdef-calc--infinity), and
[NaN](https://drafts.csswg.org/css-values-4/#valdef-calc-nan) which will clamp at 255, 0 and 0 respectively.

For example, the computed value of

```
 hsl(38.824 100% 50%)
```

is

```
 rgb(255, 165, 0)
```

- [color-computed-hsl.html](https://wpt.fyi/results/css/css-color/parsing/color-computed-hsl.html "css/css-color/parsing/color-computed-hsl.html")
 [[(live
 test)]](http://wpt.live/css/css-color/parsing/color-computed-hsl.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/parsing/color-computed-hsl.html)
- [color-computed-hwb.html](https://wpt.fyi/results/css/css-color/parsing/color-computed-hwb.html "css/css-color/parsing/color-computed-hwb.html")
 [[(live
 test)]](http://wpt.live/css/css-color/parsing/color-computed-hwb.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/parsing/color-computed-hwb.html)
- [color-computed-rgb.html](https://wpt.fyi/results/css/css-color/parsing/color-computed-rgb.html "css/css-color/parsing/color-computed-rgb.html")
 [[(live
 test)]](http://wpt.live/css/css-color/parsing/color-computed-rgb.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/parsing/color-computed-rgb.html)

### 15.2. Resolving Lab and LCH values

This applies to [lab()](#funcdef-lab) and [lch()](#funcdef-lch) values.

The declared, computed and used value is the corresponding CIE Lab or
LCH color (after clamping of L, C and H) paired with the specified alpha
component (as a
[\<number\>](https://drafts.csswg.org/css-values-4/#number-value), not a
[\<percentage\>](https://drafts.csswg.org/css-values-4/#percentage-value); and defaulting to opaque if
unspecified).

For example, the computed value of

```
 lch(52.2345% 72.2 56.2 / 1)
```

is

```
 lch(52.2345% 72.2 56.2)
```

Although the values of a, b and C are theoretically unbounded, there may
be an [implementation-defined limit for values approaching
infinity](https://drafts.csswg.org/css-values-4/#implementation-defined-limit-for-values-approaching-infinity).

Tests

- [color-computed-lab.html](https://wpt.fyi/results/css/css-color/parsing/color-computed-lab.html "css/css-color/parsing/color-computed-lab.html")
 [[(live
 test)]](http://wpt.live/css/css-color/parsing/color-computed-lab.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/parsing/color-computed-lab.html)

### 15.3. Resolving Oklab and OkLCh values

This applies to [oklab()](#funcdef-oklab) and [oklch()](#funcdef-oklch) values.

The declared, computed and used value is the corresponding Oklab or
OkLCh color (after clamping of L, C and H) paired with the specified
alpha component (as a
[\<number\>](https://drafts.csswg.org/css-values-4/#number-value), not a
[\<percentage\>](https://drafts.csswg.org/css-values-4/#percentage-value); and defaulting to opaque if
unspecified).

For example, the computed value of

```
 oklch(42.1% 0.192 328.6 / 1)
```

is

```
 oklch(42.1% 0.192 328.6)
```

Although the values of a, b and C are theoretically unbounded, there may
be an [implementation-defined limit for values approaching
infinity](https://drafts.csswg.org/css-values-4/#implementation-defined-limit-for-values-approaching-infinity).

Tests

- [color-computed-lab.html](https://wpt.fyi/results/css/css-color/parsing/color-computed-lab.html "css/css-color/parsing/color-computed-lab.html")
 [[(live
 test)]](http://wpt.live/css/css-color/parsing/color-computed-lab.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/parsing/color-computed-lab.html)

### 15.4. Resolving values of the [color() function]
The declared, computed and used value is the color in the specified
[color space](#color-space),
paired with the specified alpha component (as a
[\<number\>](https://drafts.csswg.org/css-values-4/#number-value), not a
[\<percentage\>](https://drafts.csswg.org/css-values-4/#percentage-value); and defaulting to opaque if
unspecified).

For example, the computed value of

```
 color(display-p3 0.823 0.6554 0.2537 /1)
```

is

```
 color(display-p3 0.823 0.6554 0.2537)
```

For colors specified in the
[xyz](#valdef-color-xyz) [color space](#color-space), which is an alias of the
[xyz-d65](#valdef-color-xyz-d65) [color space], the computed
and used value is in the [xyz-d65]
[color space].

For example, the computed value of

```
 color(xyz 0.472 0.372 0.131)
```

is

```
 color(xyz-d65 0.472 0.372 0.131)
```

Although the values of r, g, b, x, y and z are theoretically unbounded,
there may be an [implementation-defined limit for values approaching
infinity](https://drafts.csswg.org/css-values-4/#implementation-defined-limit-for-values-approaching-infinity).

Tests

- [color-computed-color-function.html](https://wpt.fyi/results/css/css-color/parsing/color-computed-color-function.html "css/css-color/parsing/color-computed-color-function.html")
 [[(live
 test)]](http://wpt.live/css/css-color/parsing/color-computed-color-function.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/parsing/color-computed-color-function.html)

### 15.5. Resolving other colors

This applies to

- [system colors](#css-system-colors),

- [deprecated system colors](#deprecated-system-colors)

- [transparent](#valdef-color-transparent)

- [currentcolor](#valdef-color-currentcolor).

If the color was explicitly specified by the author as a [system
color](#css-system-colors)
or as a deprecated system color, the [declared
value](https://drafts.csswg.org/css-cascade-5/#declared-value) is itself, converted to [ASCII
lowercase](https://infra.spec.whatwg.org/#ascii-lowercase).

For example, in this html:

```
<mark style="color: MarkText; background: Mark">example</mark>
```

The declared value for background-color is \"mark\".

For [system colors](#css-system-colors), the computed and used value is the corresponding color
in its color space, paired with the specified alpha component (after
clamping to \[0, 1\]).

For [deprecated system colors](#deprecated-system-colors), the computed
and used value is the color of the corresponding [system
color](#css-system-colors)
(as listed in [Appendix A: Deprecated CSS System
Colors](#deprecated-system-colors)) in its color space, paired with the
specified alpha component (after clamping to \[0, 1\]).

For example, given this css:

```
.foo {
 color: InfoText;
 }
```

The corresponding system color for
[InfoText](#valdef-color-infotext) is
[CanvasText](#valdef-color-canvastext). Suppose that
[CanvasText] is #333; then the
computed value for [InfoText] will
also be #333;

For example, in this html:

```
<button style="color: ButtonText; background: ButtonFace"></button>
```

The declared value of the color property is \"buttontext\" while the
computed value could be, for example,
rgb(0, 0, 0).

However, system colors and deprecated system colors must not be altered
by [forced colors
mode](https://drafts.csswg.org/css-color-adjust-1/#forced-colors-mode).

The declared value of
[transparent](#valdef-color-transparent) is \"transparent\" while the computed and used
value is [transparent
black](#transparent-black).

The
[currentcolor](#valdef-color-currentcolor) keyword computes to itself.

In the [color](#propdef-color) property, the used value of [currentcolor]
is the resolved [inherited
value](https://drafts.csswg.org/css-cascade-5/#inherited-value). In any other property, its used value is the used
value of the [color] property on the
same element.

 This means that if the
[currentcolor](#valdef-color-currentcolor) value is inherited, it's inherited as a keyword,
not as the value of the [color](#propdef-color) property, so descendants will use
their own [color] property to resolve
it.

For example, given this html:

```
<div>
 <p>Assume this example text is long enough
 to wrap on multiple lines.
 </p>
</div>
```

and this css:

```
div {
 color: forestgreen;
 text-shadow: currentColor;
}
p {
 color: mediumseagreen;
}
p::firstline {
 color: yellowgreen;
}
```

The used value of the inherited property text-shadow on the first line
fragment would be yellowgreen.

- [currentcolor-001.html](https://wpt.fyi/results/css/css-color/currentcolor-001.html "css/css-color/currentcolor-001.html")
 [[(live
 test)]](http://wpt.live/css/css-color/currentcolor-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/currentcolor-001.html)
- [currentcolor-002.html](https://wpt.fyi/results/css/css-color/currentcolor-002.html "css/css-color/currentcolor-002.html")
 [[(live
 test)]](http://wpt.live/css/css-color/currentcolor-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/currentcolor-002.html)
- [currentcolor-003.html](https://wpt.fyi/results/css/css-color/currentcolor-003.html "css/css-color/currentcolor-003.html")
 [[(live
 test)]](http://wpt.live/css/css-color/currentcolor-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/currentcolor-003.html)
- [currentcolor-005.html](https://wpt.fyi/results/css/css-color/currentcolor-005.html "css/css-color/currentcolor-005.html")
 [[(live
 test)]](http://wpt.live/css/css-color/currentcolor-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/currentcolor-005.html)
- [system-color-compute.html](https://wpt.fyi/results/css/css-color/system-color-compute.html "css/css-color/system-color-compute.html")
 [[(live
 test)]](http://wpt.live/css/css-color/system-color-compute.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/system-color-compute.html)

## 16. Serializing [\<color\> Values]
This section updates and replaces that part of CSS Object Model, section
[Serializing CSS
Values](https://drafts.csswg.org/cssom-1/#serializing-css-values), which
relates to serializing
[\<color\>](#typedef-color) values.

In this section, the strings used in the specification and the
corresponding characters are as follows.

String

Character(s)

\" \"

U+0020 SPACE

\"#\"

U+0023 NUMBER SIGN

\",\"

U+002C COMMA

\"-\"

U+002D HYPHEN-MINUS

\".\"

U+002E FULL STOP

\"/\"

U+002F SOLIDUS

\"none\"

U+006E LATIN SMALL LETTER N\
U+006F LATIN SMALL LETTER O\
U+006E LATIN SMALL LETTER N\
U+0065 LATIN SMALL LETTER E

The string \".\" shall be used as a decimal separator, regardless of
locale, and there shall be no thousands separator.

For syntactic forms which support [missing color
components](#missing-color-component), the value
[none](#valdef-color-none) (equivalently NONE, nOnE, etc), shall be serialized
in all-lowercase as the string \"none\".

### 16.1. Serializing alpha values

This applies to any [\<color\>](#typedef-color) value which can take an optional
alpha value. It does not apply to the [opacity] property.

If, after clamping to the range \[0, 1\] the alpha is 1, it is omitted
from the serialization; an implicit value of 1 (fully opaque) is the
default.

If the alpha is any other value than 1, it is explicitly included in the
serialization as described below.

For historical reasone, the serialization of alpha depends on whether
the color was specified using [legacy color
syntax](#legacy-color-syntax) or [modern color
syntax](#modern-color-syntax).

#### 16.1.1. Serializing legacy alpha values

If the value is internally represented as an integer between 0 and 255
inclusive (i.e. 8-bit unsigned integer), follow these steps:

1. Let `alpha` be the given integer.
2. If there exists an integer between 0 and 100 inclusive that, when
 multiplied with 2.55 and rounded to the closest integer (rounding up
 if two values are equally close), equals `alpha`, let
 `rounded` be that integer divided by 100.
3. Otherwise, let `rounded` be `alpha` divided by
 0.255 and rounded to the closest integer (rounding up if two values
 are equally close), divided by 1000.
4. Return the result of serializing `rounded` as a
 [\<number\>](https://drafts.csswg.org/css-values-4/#number-value).

Otherwise, return the result of serializing the given value (as a
[\<number\>](https://drafts.csswg.org/css-values-4/#number-value), not a
[\<percentage\>](https://drafts.csswg.org/css-values-4/#percentage-value)), the same as the modern alpha
serialization.

For example, if the alpha is stored as the 8-bit unsigned integer 237,
the integer 93 satisfies the criterion because Math.round(93 \* 2.55) is
237, and so the alpha is serialized as \"0.93\".

However, if the alpha is stored as the 8-bit unsigned integer 236, there
is no such integer (92 maps to 235 while 94 maps to 240), and so since
236 ÷ 0.255 = 925.490196078 the alpha is serialized as \"0.92549\" (no
more than 6 figures, trailing zeroes omitted).

For [legacy color
syntax](#legacy-color-syntax), the precision with which alpha values are retained,
and thus the number of decimal places in the serialized value, must at
least be sufficient to round-trip integer percentage values. Thus, the
serialized value must contain at least two decimal places (unless
trailing zeroes have been removed). Values must be [rounded towards
+∞](https://drafts.csswg.org/css-values-4/#combine-integers), not
truncated.

For example, an alpha value of 12.3456789% could be serialized as the
strings \"0.12\" or \"0.123\" or \"0.1234\" or \"0.12346\" (rounding the
value of 5 towards +∞ because the following digit is 6) or any longer,
rounded serialization of the same form.

#### 16.1.2. Serializing modern alpha values

Return the result of serializing the given value (as a
[\<number\>](https://drafts.csswg.org/css-values-4/#number-value), not a
[\<percentage\>](https://drafts.csswg.org/css-values-4/#percentage-value)).

The
[\<number\>](https://drafts.csswg.org/css-values-4/#number-value) value is expressed in base ten, with
the \".\" character as decimal separator. The leading zero must not be
omitted. Trailing zeroes must be omitted.

For example, an alpha value of 70% will be serialized as the string
\"0.7\" which has a leading zero before the decimal separator, \".\" as
decimal separator (even if the current locale would use some other
character, such as \",\"), and all digits after the \"7\" would be \"0\"
and are omitted.

For [modern color
syntax](#modern-color-syntax), the precision with which
[\<alpha-value\>](#typedef-color-alpha-value)s are retained, and thus the number of
decimal places in the serialized value, is required to be sufficient to
round-trip 16-bit decimal values.

The serialized value must contain six decimal places (unless trailing
zeroes have been removed).

Values must be [rounded towards
+∞](https://drafts.csswg.org/css-values-4/#combine-integers), not
truncated.

For example, an alpha value of 12.3456789% will be serialized as the
string \"0.123457\" (rounding the value towards +∞).

For example, given the color color(srgb 1 0 0 / 0.5), the alpha value is
to be serialized as the string \"0.5\". If it were stored at only 10-bit
precision, the internal value would be 512/1023 which is 0.50048875855,
or \"0.500489\" to six significant figures, close to the desired value
but not exact. At 12-bit that would be 2048/4095 which is 0.50012210012,
which is 0.500122 to six significant figures, still not exact.

It would also be incorrect to store it as 128/255 which is
0.50196078431, or 0.501960 to six significant figures.

To avoid cumulative round-off errors, 16bit, half-float, or float per
alpha component is recommended for internal storage.

Because
[\<alpha-value\>](#typedef-color-alpha-value)s which were specified outside the
valid range are clamped at parse time, the declared value will be
clamped. However, per [CSS Values 4 § 10.12 Range
Checking](https://drafts.csswg.org/css-values-4/#calc-range),
[\<alpha-value\>]s
specified using calc() are not clamped when the specified form is
serialized; but the computed values are clamped.

For example an alpha value which was specified directly as 120% would be
serialized as the string \"1\". However, if it was specified as
calc(2\*60%) the declared value would be serialized as the string
\"calc(1.2)\".

### 16.2. Serializing sRGB values

The serialized form of the following sRGB values:

- [hex colors](#hex-color)

- [rgb()](#funcdef-rgb)
 and [rgba()](#funcdef-rgba) values

- [hsl()](#funcdef-hsl)
 and [hsla()](#funcdef-hsla) values

- [hwb()](#funcdef-hwb)
 values

- [named colors](#named-color)

- [system colors](#css-system-colors)

- [deprecated-colors](#deprecated-system-colors)

- [transparent](#valdef-color-transparent)

is derived from the [declared
value](https://drafts.csswg.org/css-cascade-5/#declared-value).

When serializing the value of a property which was set by the author to
a CSS [named color](#named-color), a [system
color](#css-system-colors),
a [deprecated-color](#deprecated-system-colors), or
[transparent](#valdef-color-transparent) therefore, for the [declared
value](https://drafts.csswg.org/css-cascade-5/#declared-value), the [ASCII
lowercase](https://infra.spec.whatwg.org/#ascii-lowercase) keyword value
is retained. For the computed and used value, the corresponding sRGB
value is used.

Tests

- [system-color-compute.html](https://wpt.fyi/results/css/css-color/system-color-compute.html "css/css-color/system-color-compute.html")
 [[(live
 test)]](http://wpt.live/css/css-color/system-color-compute.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/system-color-compute.html)

Thus, the serialized declared value of
[transparent](#valdef-color-transparent) is the string \"transparent\", while the
serialized computed value of
[transparent] is the string
\"rgba(0, 0, 0, 0)\".

For all other sRGB values, the declared, computed and used value is the
corresponding sRGB value.

During serialization, any
[missing](#missing-color-component) values are converted to 0 if the chosen serialization
form (such as the [legacy color
syntax](#legacy-color-syntax) with comma separators, or the [HTML-compatible
serialization](#HTML-compatible-serialization-of-srgb) of sRGB values)
cannot represent the
[none](#valdef-color-none) keyword. When at least one component is
[missing] and the value can be
serialized in a form which supports [none], the form is chosen as described in [§ 16.2.2 CSS serialization of
sRGB values](#css-serialization-of-srgb) so that [missing color
components] are preserved as
[none].

#### 16.2.1. HTML-compatible serialization of sRGB values

If the following conditions are all true:

1. The color space is sRGB
2. The alpha is 1
3. The RGB component values are internally represented as integers
 between 0 and 255 inclusive (i.e. 8-bit unsigned integer)
4. [HTML-compatible serialization is
 requested]

Then corresponding sRGB values are serialized in 6-digit [hex color
notation](#hex-color) as follows:

A seven-character string consisting of the character \"#\", followed
immediately by the two-digit hexadecimal representations of the red
component, the green component, and the blue component, in that order,
using [ASCII lower hex
digits](https://infra.spec.whatwg.org/#ascii-lower-hex-digit). No spaces
are permitted.

For example, fill style is set to
 magenta:

```
context.fillStyle = "rgb(255, 0, 255)"
console.log(context.fillStyle); // "#ff00ff"
```

The color space is sRGB, the representation is 8 bits per component, the
data format does not produce
[none](#valdef-color-none) values nor does it support extended range values, and
the alpha is 1.

The HTML-compatible serialization is the string \"#ff00ff\" (not
\"#FF00FF\").

Otherwise, for sRGB the [CSS serialization of sRGB values is
used](#css-serialization-of-srgb) and for other color spaces, the
relevant [serialization](#serializing-color-values) of the
[\<color\>](#typedef-color) value.

For example, fill style is set to
 a dark brown, in
CIE Lab:

```
context.fillStyle = "lab(29% 39 20)";
console.log(context.fillStyle); // "lab(29 39 20)"
```

The CSS serialization is the string \"lab(29 39 20)\".

For example, fill style is set to
 semi-transparent magenta:

```
context.fillStyle = "#ff00ffed";
console.log(context.fillStyle); // "rgba(255, 0, 255, 0.93)"
```

The alpha is not 1, so the CSS serialization is the string \"rgba(255,
0, 255, 0.93)\".

#### 16.2.2. CSS serialization of sRGB values

If the value has no [missing color
components](#missing-color-component), corresponding sRGB values use either the
[rgb()](#funcdef-rgb) or
[rgba()](#funcdef-rgba)
form (depending on whether the (clamped) alpha is exactly 1, or not),
with all [ASCII
lowercase](https://infra.spec.whatwg.org/#ascii-lowercase) letters for
the function name.

For compatibility, the sRGB component values are serialized in
[\<number\>](https://drafts.csswg.org/css-values-4/#number-value) form, not
[\<percentage\>](https://drafts.csswg.org/css-values-4/#percentage-value). Also for compatibility, the
component values are serialized in base 10, with a range of \[0-255\],
regardless of the bit depth with which they are stored.

[As noted earlier](#serializing-alpha-values), unitary alpha values are
not explicitly serialized. Also, for compatibility, if the alpha is
exactly 1, the [rgb()](#funcdef-rgb) form is used, with an implicit alpha; otherwise, the
[rgba()](#funcdef-rgba)
form is used, with an explicit alpha value.

For compatibility, the legacy form with comma separators is used;
exactly one ASCII space follows each comma. This includes the comma (not
slash) used to separate the blue component of
[rgba()](#funcdef-rgba)
from the alpha value.

However, the [legacy color
syntax](#legacy-color-syntax) with comma separators cannot represent
[none](#valdef-color-none). If the value has at least one [missing color
component](#missing-color-component), the serialization form is chosen to preserve those
components as the [none] keyword,
based on the color function of the [declared
value](https://drafts.csswg.org/css-cascade-5/#declared-value):

- For [rgb()](#funcdef-rgb) and [rgba()](#funcdef-rgba) values (the only sRGB form in this list whose
 syntax accepts [none](#valdef-color-none); [hex colors](#hex-color), [named colors](#named-color), [system
 colors](#css-system-colors), [deprecated-colors](#deprecated-system-colors), and
 [transparent](#valdef-color-transparent) have no parametric syntax and so never have
 [missing color
 components](#missing-color-component)), the value is serialized as a
 [color()](#funcdef-color) function in the
 [srgb](#valdef-color-srgb) [color space](#color-space) rather than as the modern space-separated form of
 [rgb()], even though that form would also
 accept [none]: \"color(srgb\"
 followed by a single space, followed by a space-separated list of the
 three non-alpha components serialized as
 [\<number\>](https://drafts.csswg.org/css-values-4/#number-value)s in the \[0, 1\] reference range
 (or as [none] if
 [missing]), followed (only if the
 alpha is non-unity or [missing])
 by \" / \" and the alpha component (serialized per the [alpha
 rules](#serializing-alpha-values), or as
 [none] if
 [missing]), followed by \")\".

- For [hsl()](#funcdef-hsl) and [hsla()](#funcdef-hsla) values, the value is serialized using the
 modern (whitespace-separated) [hsl()]
 syntax, with a slash before the alpha component when present. The
 function name is \"hsl\" (in [ASCII
 lowercase](https://infra.spec.whatwg.org/#ascii-lowercase)) regardless
 of whether the value was authored using the
 [hsla()] alias. The hue is serialized as
 a canonicalized
 [\<number\>](https://drafts.csswg.org/css-values-4/#number-value) in degrees, the saturation and
 lightness as
 [\<percentage\>](https://drafts.csswg.org/css-values-4/#percentage-value)s, and the alpha (included only if
 non-unity or
 [missing](#missing-color-component)) per the [alpha rules](#serializing-alpha-values);
 any [missing component] is
 serialized as the
 [none](#valdef-color-none) keyword.

- For [hwb()](#funcdef-hwb) values, the value is serialized using the modern
 (whitespace-separated) [hwb()] syntax,
 with a slash before the alpha component when present. The function
 name is \"hwb\" in [ASCII
 lowercase](https://infra.spec.whatwg.org/#ascii-lowercase). The hue is
 serialized as a canonicalized
 [\<number\>](https://drafts.csswg.org/css-values-4/#number-value) in degrees, the whiteness and
 blackness as
 [\<percentage\>](https://drafts.csswg.org/css-values-4/#percentage-value)s, and the alpha (included only if
 non-unity or
 [missing](#missing-color-component)) per the [alpha rules](#serializing-alpha-values);
 any [missing component] is
 serialized as the
 [none](#valdef-color-none) keyword.

 this means that an
[hsl()](#funcdef-hsl) or
[hwb()](#funcdef-hwb)
value containing [none](#valdef-color-none) round-trips through serialization in its own
color function, rather than degrading to
[rgba()](#funcdef-rgba)
(whose legacy form cannot represent [none]), while an [rgb()](#funcdef-rgb) value containing [none] is serialized via [color(srgb ...)]. The modern
space-separated form of [rgb()] could
itself represent [none], but the
[sRGB CSS serialization](#serializing-color-values) uses [color(srgb
...)] instead for consistency with how all other [color
spaces](#color-space) are
serialized in their non-legacy form. This parallels the behavior of
relative color syntax defined in [CSS Color 5 § 11.2 Serializing Origin
Colors](https://drafts.csswg.org/css-color-5/#serial-origin-color).

Tests

- [computed-color.html](https://wpt.fyi/results/css/css-color/computed-color.html "css/css-color/computed-color.html")
 [[(live
 test)]](http://wpt.live/css/css-color/computed-color.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/computed-color.html)

For example, the serialized value of

```
 rgb(29 164 192 / 95%)
```

is the string \"rgba(29, 164, 192, 0.95)\"

For example, an author-supplied value:

```
 hwb(740deg 20% 30% / 50%)
```

Would be normalized first to

```
 hwb(20 20% 30% / 50%)
```

and then converted to sRGB and serialized as

```
 rgba(178.5, 93.5, 51, 0.5)
```

The precision of the returned result is [described
below](#sRGB-precision).

For example, the author-supplied
value

```
hwb(20 none 30% / none)
```

contains [missing color
components](#missing-color-component) (both the whiteness and the alpha are
[none](#valdef-color-none)), so it is *not* serialized through
[rgba()](#funcdef-rgba).
Instead, it is serialized using the modern
[hwb()](#funcdef-hwb)
syntax as

```
hwb(20 none 30% / none)
```

preserving each [none](#valdef-color-none) value.

Similarly, the author-supplied value

```
rgb(none 0 0)
```

is serialized as

```
color(srgb none 0 0)
```

because [rgb()](#funcdef-rgb) (in its serialized legacy comma form) cannot
represent [none](#valdef-color-none).

 contrary to CSS Color 3, the parameters of the
[rgb()](#funcdef-rgb)
function are of type
[\<number\>](https://drafts.csswg.org/css-values-4/#number-value), not
[\<integer\>](https://drafts.csswg.org/css-values-4/#integer-value). Thus, any higher precision than
eight bits is indicated with a fractional part.

The precision with which sRGB component values are retained, and thus
the number of significant figures in the serialized value, is not
defined in this specification, but must at least be sufficient to
round-trip eight bit values. Values must be [rounded towards
+∞](https://drafts.csswg.org/css-values-4/#combine-integers), not
truncated.

 authors of scripts which expect color values returned
from [getComputedStyle]{style="font-family:monospace"} to have
[\<integer\>](https://drafts.csswg.org/css-values-4/#integer-value) component values, are advised to
update them to also cope with
[\<number\>](https://drafts.csswg.org/css-values-4/#number-value).

For example,

```
 rgb(146.064 107.457 131.223)
```

is now valid, and equal to

```
 rgb(57.28% 42.14% 51.46%)
```

A conformant serialized form for both, is the string \"rgb(146.06,
107.46, 131.2)\".

Trailing fractional zeroes in any component values must be omitted; if
the fractional part consists of all zeroes, the decimal point must also
be omitted. This means that sRGB colors specified with integer component
values will serialize with backwards-compatible integer values.

The serialized computed value of

```
 ''goldenrod''
```

is the string \"rgb(218, 165, 32)\" and not the string \"rgb(218.000,
165.000, 32.000)\"

### 16.3. Serializing Lab and LCH values

The serialized form of [lch()](#funcdef-lch) and [lab()](#funcdef-lab) values is derived from the [computed
value](https://drafts.csswg.org/css-cascade-5/#computed-value) and uses the [lab()] or
[lch()] forms, with [ASCII
lowercase](https://infra.spec.whatwg.org/#ascii-lowercase) letters for
the function name.

The component values are serialized in base 10; the L, a, b and C
component values are serialized as
[\<number\>](https://drafts.csswg.org/css-values-4/#number-value), using the [Lab percentage reference
ranges](#prr-lab) or the [LCH percentage reference ranges](#prr-lch) as
appropriate to perform percentage to number conversion; thus 0% L maps
to 0 and 100% L maps to 100. A single ASCII space character \" \" must
be used as the separator between the component values.

Tests

- [color-computed.html](https://wpt.fyi/results/css/css-color/parsing/color-computed.html "css/css-color/parsing/color-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-color/parsing/color-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/parsing/color-computed.html)

The serialized value of

```
 lab(56.200% 0.000 83.600)
```

is the string \"lab(56.2 0 83.6)\"

The serialized value of

```
 lab(56.200% 0.000 66.88%)
```

is the string \"lab(56.2 0 83.6)\"

Trailing fractional zeroes in any component values must be omitted; if
the fractional part consists of all zeroes, the decimal point must also
be omitted.

The serialized value of

```
 lch(37% 105.0 305.00)
```

is the string \"lch(37 105 305)\", not \"lch(37 105.0 305.00)\".

The precision with which [lab()](#funcdef-lab) component values are retained, and thus the
number of significant figures in the serialized value, is not defined in
this specification, but due to the wide gamut must be sufficient to
round-trip L values between 0 and 100, and a and b values between ±127,
with at least sixteen bit precision; this will result in at least three
decimal places unless trailing zeroes have been omitted. (half float or
float, is recommended for internal storage). Values must be [rounded
towards +∞](https://drafts.csswg.org/css-values-4/#combine-integers),
not truncated.

 a and b values outside ±125 are possible with ultrawide
gamut spaces. For example, *all* of the
[prophoto-rgb](#valdef-color-prophoto-rgb) primaries and secondaries exceed this range, but
are within ±200.

[As noted earlier](#serializing-alpha-values), unitary alpha values are
not explicitly serialized. Non-unitary alpha values must be explicitly
serialized, and the string \" / \" (an ASCII space, then forward slash,
then another space) must be used to separate the b component value from
the alpha value.

The serialized value of

```
 lch(56.2% 83.6 357.4 /93%)
```

is the string \"lch(56.2 83.6 357.4 / 0.93)\" not \"lch(56.2% 83.6 357.4
/ 0.93)\"

### 16.4. Serializing Oklab and OkLCh values

The serialized form of [oklch()](#funcdef-oklch) and
[oklab()](#funcdef-oklab) values is derived from the [computed
value](https://drafts.csswg.org/css-cascade-5/#computed-value) and uses the [oklab()] or
[oklch()] forms, with [ASCII
lowercase](https://infra.spec.whatwg.org/#ascii-lowercase) letters for
the function name.

The component values are serialized in base 10; the L, a, b and C
component values are serialized as
[\<number\>](https://drafts.csswg.org/css-values-4/#number-value) using the [Oklab percentage reference
ranges](#prr-oklab) or the [OkLCh percentage reference
ranges](#prr-oklch) as appropriate to perform percentage to number
conversion; thus 0% L maps to 0 and 100% L maps to 1.0. A single ASCII
space character \" \" must be used as the separator between the
component values.

Tests

- [color-computed.html](https://wpt.fyi/results/css/css-color/parsing/color-computed.html "css/css-color/parsing/color-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-color/parsing/color-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/parsing/color-computed.html)

The serialized value of

```
 oklab(54.0% -0.10 -0.02)
```

is the string \"oklab(0.54 -0.1 -0.02)\" not \"oklab(54 -0.1 -0.02)\" or
\"oklab(54% -0.1 -0.02)\"

The serialized value of

```
 oklab(54.0 -25% -5%)
```

is the string \"oklab(0.54 -0.1 -0.02)\" not \"oklab(54 -0.25 -0.05)\"

Trailing fractional zeroes in any component values must be omitted; if
the fractional part consists of all zeroes, the decimal point must also
be omitted.

The serialized value of

```
 oklch(56.43% 0.0900 123.40)
```

is the string \"oklch(0.5643 0.09 123.4)\", not \"oklch(0.5643 0.0900
123.40)\".

The precision with which
[oklab()](#funcdef-oklab) component values are retained, and thus the number of
significant figures in the serialized value, is not defined in this
specification, but due to the wide gamut must be sufficient to
round-trip L values between 0 and 1 (0% and 100%), and a, b and C values
between ±0.5, with at least sixteen bit precision; this will result in
at least five decimal places unless trailing zeroes have been omitted.
(half float or float, is recommended for internal storage). Values must
be [rounded towards
+∞](https://drafts.csswg.org/css-values-4/#combine-integers), not
truncated.

 a, b and C values outside ±0.5 are possible with
ultrawide gamut spaces. For example, the
[prophoto-rgb](#valdef-color-prophoto-rgb) green and blue primaries exceed this range, with
C of 0.526 and 1.413 respectively.

[As noted earlier](#serializing-alpha-values), unitary alpha values are
not explicitly serialized. Non-unitary alpha values must be explicitly
serialized, and the string \" / \" (an ASCII space, then forward slash,
then another space) must be used to separate the final color component
(b, or C) value from the alpha value.

The serialized value of

```
 oklch(53.85% 0.1725 320.67 / 70%)
```

is the string \"oklch(0.5385 0.1725 320.67 / 0.7)\"

### 16.5. Serializing values of the [color() function]
The serialized form of
[color()](#funcdef-color) values is derived from the [computed
value](https://drafts.csswg.org/css-cascade-5/#computed-value) and uses the [color()]
form, with [ASCII
lowercase](https://infra.spec.whatwg.org/#ascii-lowercase) letters for
the function name and the color space name.

The component values are serialized in base 10, as
[\<number\>](https://drafts.csswg.org/css-values-4/#number-value). A single ASCII space character \" \"
must be used as the separator between the component values, and also
between the color space name and the first color component.

Tests

- [computed-color.html](https://wpt.fyi/results/css/css-color/computed-color.html "css/css-color/computed-color.html")
 [[(live
 test)]](http://wpt.live/css/css-color/computed-color.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/computed-color.html)
- [color-computed.html](https://wpt.fyi/results/css/css-color/parsing/color-computed.html "css/css-color/parsing/color-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-color/parsing/color-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/parsing/color-computed.html)

The serialized value of

```
 color(dIsPlAy-P3 0.964 0.763 0.787)
```

is the string \"color(display-p3 0.96 0.76 0.79)\", if two decimal
places are retained. Notice that 0.787 has rounded up to 0.79, rather
than being truncated to 0.78.

Trailing fractional zeroes in any component values must be omitted; if
the fractional part consists of all zeroes, the decimal point must also
be omitted.

The serialized value of

```
 color(rec2020 0.400 0.660 0.340)
```

is the string \"color(rec2020 0.4 0.66 0.34)\", not \"color(rec2020
0.400 0.660 0.340)\".

If the color space is sRGB, the color space is still explicitly required
in the serialized result.

For the predefined color spaces, the *minimum* precision for
round-tripping is as follows:

color space

Minimum bits

[srgb](#valdef-color-srgb)

10

[srgb-linear](#valdef-color-srgb-linear)

12

[display-p3](#valdef-color-display-p3)

10

[display-p3-linear](#valdef-color-display-p3-linear)

12

[a98-rgb](#valdef-color-a98-rgb)

10

[prophoto-rgb](#valdef-color-prophoto-rgb)

12

[rec2020](#valdef-color-rec2020)

12

[xyz](#valdef-color-xyz),
[xyz-d50](#valdef-color-xyz-d50),
[xyz-d65](#valdef-color-xyz-d65)

16

(16bit, half-float, or float *per component* is recommended for internal
storage). Values must be [rounded towards
+∞](https://drafts.csswg.org/css-values-4/#combine-integers), not
truncated.

 compared to the legacy forms such as
[rgb()](#funcdef-rgb),
[hsl()](#funcdef-hsl) and
so on, [color(srgb)] has a higher minimum precision requirement.
Stylesheet authors who prefer higher precision are thus encouraged to
use the [color(srgb)] form.

[As noted earlier](#serializing-alpha-values), unitary alpha values are
not explicitly serialized. Non-unitary alpha values must be explicitly
serialized, and the string \" / \" (an ASCII space, then forward slash,
then another space) must be used to separate the final color component
value from the alpha value.

The serialized value of

```
 color(prophoto-rgb 0.2804 0.40283 0.42259/85%)
```

is the string \"color(prophoto-rgb 0.28 0.403 0.423 / 0.85)\", if three
decimal places are retained.

### 16.6. Serializing other colors

This applies to
[currentcolor](#valdef-color-currentcolor).

The serialized form of this value is derived from the [computed
value](https://drafts.csswg.org/css-cascade-5/#computed-value) and uses [ASCII
lowercase](https://infra.spec.whatwg.org/#ascii-lowercase) letters for
the color name.

The serialized form of
[currentColor](#valdef-color-currentcolor) is the string \"currentcolor\".

## 17. Serializing [\<opacity-value\>]
This applies to the [opacity] property, and to properties whose
value includes
[\<opacity-value\>](#typedef-opacity-opacity-value), such as
[shape-image-threshold](https://drafts.csswg.org/css-shapes-1/#propdef-shape-image-threshold).

If the specified value for an opacity value matches a literal
[\<percentage-token\>](https://drafts.csswg.org/css-syntax-3/#typedef-percentage-token) (i.e. does not use
[calc()](https://drafts.csswg.org/css-values-4/#funcdef-calc)) it should be serialized as the equivalent
[\<number\>](https://drafts.csswg.org/css-values-4/#number-value) (0% maps to 0, 100% maps to 1) value.
value. Otherwise, the specified value for an opacity value should
serialize using the standard serialization for the grammar.

This
[\<number\>](https://drafts.csswg.org/css-values-4/#number-value) value is expressed in base ten, with
the \".\" character as decimal separator. The leading zero must not be
omitted. Trailing zeroes must be omitted.

Opacity values outside the range \[0,1\] are preserved, without
clamping, in the serialized specified value.

The precision with which opacity values are retained, and thus the
number of decimal places in the serialized value, is not defined in this
specification, but must at least be sufficient to round-trip integer
percentage values. Thus, the serialized value must contain at least two
decimal places (unless trailing zeroes have been removed). Values must
be [rounded towards
+∞](https://drafts.csswg.org/css-values-4/#combine-integers), not
truncated.

## 18. Default Style Rules

The following stylesheet is informative, not normative. This style sheet
could be used by an implementation as part of its default styling of
HTML documents.

```
/* traditional desktop user agent colors for hyperlinks */
:link { color: LinkText; }
:visited { color: VisitedText; }
:active { color: ActiveText; }
```

## 19. Sample code for Color Conversions

*This section is not normative.*

Tests

This section is not normative, it does not need tests.

------------------------------------------------------------------------

For clarity, [a library](multiply-matrices.js) is used for matrix
multiplication. (This is more readable than inlining all the multiplies
and adds). The matrices are in [column-major
order](https://www.scratchapixel.com/lessons/mathematics-physics-for-computer-graphics/geometry/row-major-vs-column-major-vector).

```
// Sample code for color conversions
// Conversion can also be done using ICC profiles and a Color Management System
// For clarity, a library is used for matrix multiplication (multiply-matrices.js)

// standard white points, defined by 4-figure CIE x,y chromaticities
const D50 = [0.3457 / 0.3585, 1.00000, (1.0 - 0.3457 - 0.3585) / 0.3585];
const D65 = [0.3127 / 0.3290, 1.00000, (1.0 - 0.3127 - 0.3290) / 0.3290];

// sRGB-related functions

function lin_sRGB(RGB) {
 // convert an array of sRGB values
 // where in-gamut values are in the range [0 - 1]
 // to linear light (un-companded) form.
 // https://en.wikipedia.org/wiki/SRGB
 // Extended transfer function:
 // for negative values, linear portion is extended on reflection of axis,
 // then reflected power function is used.
 return RGB.map(function (val) {
 let sign = val < 0? -1 : 1;
 let abs = Math.abs(val);

 if (abs <= 0.04045) {
 return val / 12.92;
 }

 return sign * (Math.pow((abs + 0.055) / 1.055, 2.4));
 });
}

function gam_sRGB(RGB) {
 // convert an array of linear-light sRGB values in the range 0.0-1.0
 // to gamma corrected form
 // https://en.wikipedia.org/wiki/SRGB
 // Extended transfer function:
 // For negative values, linear portion extends on reflection
 // of axis, then uses reflected pow below that
 return RGB.map(function (val) {
 let sign = val < 0? -1 : 1;
 let abs = Math.abs(val);

 if (abs > 0.0031308) {
 return sign * (1.055 * Math.pow(abs, 1/2.4) - 0.055);
 }

 return 12.92 * val;
 });
}

function lin_sRGB_to_XYZ(rgb) {
 // convert an array of linear-light sRGB values to CIE XYZ
 // using sRGB's own white, D65 (no chromatic adaptation)

 var M = [
 [ 506752 / 1228815, 87881 / 245763, 12673 / 70218 ],
 [ 87098 / 409605, 175762 / 245763, 12673 / 175545 ],
 [ 7918 / 409605, 87881 / 737289, 1001167 / 1053270 ],
 ];
 return multiplyMatrices(M, rgb);
}

function XYZ_to_lin_sRGB(XYZ) {
 // convert XYZ to linear-light sRGB

 var M = [
 [ 12831 / 3959, -329 / 214, -1974 / 3959 ],
 [ -851781 / 878810, 1648619 / 878810, 36519 / 878810 ],
 [ 705 / 12673, -2585 / 12673, 705 / 667 ],
 ];

 return multiplyMatrices(M, XYZ);
}

// display-p3-related functions

function lin_P3(RGB) {
 // convert an array of display-p3 RGB values in the range 0.0 - 1.0
 // to linear light (un-companded) form.

 return lin_sRGB(RGB); // same as sRGB
}

function gam_P3(RGB) {
 // convert an array of linear-light display-p3 RGB in the range 0.0-1.0
 // to gamma corrected form

 return gam_sRGB(RGB); // same as sRGB
}

function lin_P3_to_XYZ(rgb) {
 // convert an array of linear-light display-p3 values to CIE XYZ
 // using D65 (no chromatic adaptation)
 // http://www.brucelindbloom.com/index.html?Eqn_RGB_XYZ_Matrix.html
 var M = [
 [ 608311 / 1250200, 189793 / 714400, 198249 / 1000160 ],
 [ 35783 / 156275, 247089 / 357200, 198249 / 2500400 ],
 [ 0 / 1, 32229 / 714400, 5220557 / 5000800 ],
 ];

 return multiplyMatrices(M, rgb);
}

function XYZ_to_lin_P3(XYZ) {
 // convert XYZ to linear-light P3
 var M = [
 [ 446124 / 178915, -333277 / 357830, -72051 / 178915 ],
 [ -14852 / 17905, 63121 / 35810, 423 / 17905 ],
 [ 11844 / 330415, -50337 / 660830, 316169 / 330415 ],
 ];

 return multiplyMatrices(M, XYZ);
}

// prophoto-rgb functions

function lin_ProPhoto(RGB) {
 // convert an array of prophoto-rgb values
 // where in-gamut colors are in the range [0.0 - 1.0]
 // to linear light (un-companded) form.
 // Transfer curve is gamma 1.8 with a small linear portion
 // Extended transfer function
 const Et2 = 16/512;
 return RGB.map(function (val) {
 let sign = val < 0? -1 : 1;
 let abs = Math.abs(val);

 if (abs <= Et2) {
 return val / 16;
 }

 return sign * Math.pow(abs, 1.8);
 });
}

function gam_ProPhoto(RGB) {
 // convert an array of linear-light prophoto-rgb in the range 0.0-1.0
 // to gamma corrected form
 // Transfer curve is gamma 1.8 with a small linear portion
 // TODO for negative values, extend linear portion on reflection of axis, then add pow below that
 const Et = 1/512;
 return RGB.map(function (val) {
 let sign = val < 0? -1 : 1;
 let abs = Math.abs(val);

 if (abs >= Et) {
 return sign * Math.pow(abs, 1/1.8);
 }

 return 16 * val;
 });
}

function lin_ProPhoto_to_XYZ(rgb) {
 // convert an array of linear-light prophoto-rgb values to CIE D50 XYZ
 // matrix cannot be expressed in rational form, but is calculated to 64 bit accuracy
 // see https://github.com/w3c/csswg-drafts/issues/7675
 var M = [
 [ 0.79776664490064230, 0.13518129740053308, 0.03134773412839220 ],
 [ 0.28807482881940130, 0.71183523424187300, 0.00008993693872564 ],
 [ 0.00000000000000000, 0.00000000000000000, 0.82510460251046020 ]
 ];

 return multiplyMatrices(M, rgb);
}

function XYZ_to_lin_ProPhoto(XYZ) {
 // convert D50 XYZ to linear-light prophoto-rgb
 var M = [
 [ 1.34578688164715830, -0.25557208737979464, -0.05110186497554526 ],
 [ -0.54463070512490190, 1.50824774284514680, 0.02052744743642139 ],
 [ 0.00000000000000000, 0.00000000000000000, 1.21196754563894520 ]
 ];

 return multiplyMatrices(M, XYZ);
}

// a98-rgb functions

function lin_a98rgb(RGB) {
 // convert an array of a98-rgb values in the range 0.0 - 1.0
 // to linear light (un-companded) form.
 // negative values are also now accepted
 return RGB.map(function (val) {
 let sign = val < 0? -1 : 1;
 let abs = Math.abs(val);

 return sign * Math.pow(abs, 563/256);
 });
}

function gam_a98rgb(RGB) {
 // convert an array of linear-light a98-rgb in the range 0.0-1.0
 // to gamma corrected form
 // negative values are also now accepted
 return RGB.map(function (val) {
 let sign = val < 0? -1 : 1;
 let abs = Math.abs(val);

 return sign * Math.pow(abs, 256/563);
 });
}

function lin_a98rgb_to_XYZ(rgb) {
 // convert an array of linear-light a98-rgb values to CIE XYZ
 // http://www.brucelindbloom.com/index.html?Eqn_RGB_XYZ_Matrix.html
 // has greater numerical precision than section 4.3.5.3 of
 // https://www.adobe.com/digitalimag/pdfs/AdobeRGB1998.pdf
 // but the values below were calculated from first principles
 // from the chromaticity coordinates of R G B W
 // see matrixmaker.html
 var M = [
 [ 573536 / 994567, 263643 / 1420810, 187206 / 994567 ],
 [ 591459 / 1989134, 6239551 / 9945670, 374412 / 4972835 ],
 [ 53769 / 1989134, 351524 / 4972835, 4929758 / 4972835 ],
 ];

 return multiplyMatrices(M, rgb);
}

function XYZ_to_lin_a98rgb(XYZ) {
 // convert XYZ to linear-light a98-rgb
 var M = [
 [ 1829569 / 896150, -506331 / 896150, -308931 / 896150 ],
 [ -851781 / 878810, 1648619 / 878810, 36519 / 878810 ],
 [ 16779 / 1248040, -147721 / 1248040, 1266979 / 1248040 ],
 ];

 return multiplyMatrices(M, XYZ);
}

//Rec. 2020-related functions

function lin_2020(RGB) {
 // convert an array of rec2020 RGB values in the range 0.0 - 1.0
 // to linear light (un-companded) form.
 // Reference electro-optical transfer function from Rec. ITU-R BT.1886 Annex 1
 // with b (black lift) = 0 and a (user gain) = 1
 // defined over the extended range, not clamped

 return RGB.map(function (val) {
 let sign = val < 0? -1 : 1;
 let abs = Math.abs(val);
 return sign * Math.pow(abs, 2.4);
 });
}

function gam_2020(RGB) {
 // convert an array of linear-light rec2020 RGB in the range 0.0-1.0
 // to gamma corrected form
 // Reference electro-optical transfer function from Rec. ITU-R BT.1886 Annex 1
 // with b (black lift) = 0 and a (user gain) = 1
 // defined over the extended range, not clamped

 return RGB.map(function (val) {
 let sign = val < 0? -1 : 1;
 let abs = Math.abs(val);
 return sign * Math.pow(abs, 1 / 2.4);
 });
}

function lin_2020_to_XYZ(rgb) {
 // convert an array of linear-light rec2020 values to CIE XYZ
 // using D65 (no chromatic adaptation)
 var M = [
 [ 63426534 / 99577255, 20160776 / 139408157, 47086771 / 278816314 ],
 [ 26158966 / 99577255, 472592308 / 697040785, 8267143 / 139408157 ],
 [ 0 / 1, 19567812 / 697040785, 295819943 / 278816314 ],
 ];
 // 0 is actually calculated as 4.994106574466076e-17

 return multiplyMatrices(M, rgb);
}

function XYZ_to_lin_2020(XYZ) {
 // convert XYZ to linear-light rec2020
 var M = [
 [ 30757411 / 17917100, -6372589 / 17917100, -4539589 / 17917100 ],
 [ -19765991 / 29648200, 47925759 / 29648200, 467509 / 29648200 ],
 [ 792561 / 44930125, -1921689 / 44930125, 42328811 / 44930125 ],
 ];

 return multiplyMatrices(M, XYZ);
}

// Chromatic adaptation

function D65_to_D50(XYZ) {
 // Bradford chromatic adaptation from D65 to D50
 // The matrix below is the result of three operations:
 // - convert from XYZ to retinal cone domain
 // - scale components from one reference white to another
 // - convert back to XYZ
 // see https://github.com/LeaVerou/color.js/pull/354/files

 var M = [
 [ 1.0479297925449969, 0.022946870601609652, -0.05019226628920524 ],
 [ 0.02962780877005599, 0.9904344267538799, -0.017073799063418826 ],
 [ -0.009243040646204504, 0.015055191490298152, 0.7518742814281371 ]
 ];

 return multiplyMatrices(M, XYZ);
}

function D50_to_D65(XYZ) {
 // Bradford chromatic adaptation from D50 to D65
 // See https://github.com/LeaVerou/color.js/pull/360/files
 var M = [
 [ 0.955473421488075, -0.02309845494876471, 0.06325924320057072 ],
 [ -0.0283697093338637, 1.0099953980813041, 0.021041441191917323 ],
 [ 0.012314014864481998, -0.020507649298898964, 1.330365926242124 ]
 ];

 return multiplyMatrices(M, XYZ);
}

// CIE Lab and LCH

function XYZ_to_Lab(XYZ) {
 // Assuming XYZ is relative to D50, convert to CIE Lab
 // from CIE standard, which now defines these as a rational fraction
 var ε = 216/24389; // 6^3/29^3
 var κ = 24389/27; // 29^3/3^3

 // compute xyz, which is XYZ scaled relative to reference white
 var xyz = XYZ.map((value, i) => value / D50[i]);

 // now compute f
 var f = xyz.map(value => value > ε ? Math.cbrt(value) : (κ * value + 16)/116);

 return [
 (116 * f[1]) - 16, // L
 500 * (f[0] - f[1]), // a
 200 * (f[1] - f[2]) // b
 ];
 // L in range [0,100]. For use in CSS, add a percent
}

function Lab_to_XYZ(Lab) {
 // Convert Lab to D50-adapted XYZ
 // http://www.brucelindbloom.com/index.html?Eqn_Lab_to_XYZ.html
 var κ = 24389/27; // 29^3/3^3
 var ε = 216/24389; // 6^3/29^3
 var f = ;

 // compute f, starting with the luminance-related term
 f[1] = (Lab[0] + 16)/116;
 f[0] = Lab[1]/500 + f[1];
 f[2] = f[1] - Lab[2]/200;

 // compute xyz
 var xyz = [
 Math.pow(f[0],3) > ε ? Math.pow(f[0],3) : (116*f[0]-16)/κ,
 Lab[0] > κ * ε ? Math.pow((Lab[0]+16)/116,3) : Lab[0]/κ,
 Math.pow(f[2],3) > ε ? Math.pow(f[2],3) : (116*f[2]-16)/κ
 ];

 // Compute XYZ by scaling xyz by reference white
 return xyz.map((value, i) => value * D50[i]);
}

function Lab_to_LCH(Lab) {
 var epsilon = 0.0015;
 var chroma = Math.sqrt(Math.pow(Lab[1], 2) + Math.pow(Lab[2], 2)); // Chroma
 var hue = Math.atan2(Lab[2], Lab[1]) * 180 / Math.PI;
 if (hue < 0) {
 hue = hue + 360;
 }
 if (chroma <= epsilon) {
 hue = NaN;
 }
 return [
 Lab[0], // L is still L
 chroma, // Chroma
 hue // Hue, in degrees [0 to 360)
 ];
}

function LCH_to_Lab(LCH) {
 // Convert from polar form
 return [
 LCH[0], // L is still L
 LCH[1] * Math.cos(LCH[2] * Math.PI / 180), // a
 LCH[1] * Math.sin(LCH[2] * Math.PI / 180) // b
 ];
}

// OKLab and OKLCH
// https://bottosson.github.io/posts/oklab/

// XYZ <-> LMS matrices recalculated for consistent reference white
// see https://github.com/w3c/csswg-drafts/issues/6642#issuecomment-943521484
// recalculated for 64bit precision
// see https://github.com/color-js/color.js/pull/357

function XYZ_to_OKLab(XYZ) {
 // Given XYZ relative to D65, convert to OKLab
 var XYZtoLMS = [
 [ 0.8190224379967030, 0.3619062600528904, -0.1288737815209879 ],
 [ 0.0329836539323885, 0.9292868615863434, 0.0361446663506424 ],
 [ 0.0481771893596242, 0.2642395317527308, 0.6335478284694309 ]
 ];
 var LMStoOKLab = [
 [ 0.2104542683093140, 0.7936177747023054, -0.0040720430116193 ],
 [ 1.9779985324311684, -2.4285922420485799, 0.4505937096174110 ],
 [ 0.0259040424655478, 0.7827717124575296, -0.8086757549230774 ]
 ];

 var LMS = multiplyMatrices(XYZtoLMS, XYZ);
 // JavaScript Math.cbrt returns a sign-matched cube root
 // beware if porting to other languages
 // especially if tempted to use a general power function
 return multiplyMatrices(LMStoOKLab, LMS.map(c => Math.cbrt(c)));
 // L in range [0,1]. For use in CSS, multiply by 100 and add a percent
}

function OKLab_to_XYZ(OKLab) {
 // Given OKLab, convert to XYZ relative to D65
 var LMStoXYZ = [
 [ 1.2268798758459243, -0.5578149944602171, 0.2813910456659647 ],
 [ -0.0405757452148008, 1.1122868032803170, -0.0717110580655164 ],
 [ -0.0763729366746601, -0.4214933324022432, 1.5869240198367816 ]
 ];
 var OKLabtoLMS = [
 [ 1.0000000000000000, 0.3963377773761749, 0.2158037573099136 ],
 [ 1.0000000000000000, -0.1055613458156586, -0.0638541728258133 ],
 [ 1.0000000000000000, -0.0894841775298119, -1.2914855480194092 ]
 ];

 var LMSnl = multiplyMatrices(OKLabtoLMS, OKLab);
 return multiplyMatrices(LMStoXYZ, LMSnl.map(c => c ** 3));
}

function OKLab_to_OKLCH(OKLab) {
 var epsilon = 0.000004;
 var hue = Math.atan2(OKLab[2], OKLab[1]) * 180 / Math.PI;
 var chroma = Math.sqrt(OKLab[1] ** 2 + OKLab[2] ** 2);
 if (hue < 0) {
 hue = hue + 360;
 }
 if (chroma <= epsilon) {
 hue = NaN;
 }
 return [
 OKLab[0], // L is still L
 chroma,
 hue
 ];
}

function OKLCH_to_OKLab(OKLCH) {
 return [
 OKLCH[0], // L is still L
 OKLCH[1] * Math.cos(OKLCH[2] * Math.PI / 180), // a
 OKLCH[1] * Math.sin(OKLCH[2] * Math.PI / 180) // b
 ];
}

// Premultiplied alpha conversions

function rectangular_premultiply(color, alpha) {
// given a color in a rectangular orthogonal colorspace
// and an alpha value
// return the premultiplied form
 return color.map((c) => c * alpha)
}

function rectangular_un_premultiply(color, alpha) {
// given a premultiplied color in a rectangular orthogonal colorspace
// and an alpha value
// return the actual color
 if (alpha === 0) {
 return color; // avoid divide by zero
 }
 return color.map((c) => c / alpha)
}

function polar_premultiply(color, alpha, hueIndex) {
 // given a color in a cylindicalpolar colorspace
 // and an alpha value
 // return the premultiplied form.
 // the index says which entry in the color array corresponds to hue angle
 // for example, in OKLCH it would be 2
 // while in HSL it would be 0
 return color.map((c, i) => c * (hueIndex === i? 1 : alpha))
}

function polar_un_premultiply(color, alpha, hueIndex) {
 // given a color in a cylindicalpolar colorspace
 // and an alpha value
 // return the actual color.
 // the hueIndex says which entry in the color array corresponds to hue angle
 // for example, in OKLCH it would be 2
 // while in HSL it would be 0
 if (alpha === 0) {
 return color; // avoid divide by zero
 }
 return color.map((c, i) => c / (hueIndex === i? 1 : alpha))
}

// Convenience functions can easily be defined, such as
function hsl_premultiply(color, alpha) {
 return polar_premultiply(color, alpha, 0);
}
```

## 20. Color Difference Formulae

*This section is not normative.*

Tests

This section is not normative, it does not need tests.

------------------------------------------------------------------------

### 20.1. Introduction to Color Difference metrics.

A color difference formula estimates how different two colors *appear*.
It can be used for quality assurance (measuring whether a reproduced
color is correct), or for some types of gamut mapping, where the color
difference between the out of gamut and in-gamut colors is minimized.

Historically, the general class of color difference formulae is called
ΔE (delta E); where the E is short for Empfindung, the German word for
\"sensation\".

The simplest color difference metric, ΔE76, is simply the Euclidean
distance in CIE Lab color space, which first became an International
Standard in 1976.

While ΔE76 is a good first approximation, color-critical industries such
as printing and fabric dyeing soon developed improved formulae as the
limitations of CIE Lab became evident.

As formulae became more complex, practical implementations needed to
trade off predictive accuracy against computational complexity (and
thus, speed).

### 20.2. ΔE2000

Currently, the most widely used formula for standard dynamic range
colors is ΔE2000. It corrects a number of known asymmetries and
non-linearities compared to ΔE76. Because the formula is complex, and
critically dependent on the sign of various intermediate calculations,
implementations are often incorrect
[\[Sharma\]](#biblio-sharma "The CIEDE2000 Color-Difference Formula: Implementation Notes, Supplementary Test Data, and Mathematical Observations").

The sample code below has been
[validated](https://colorjs.io/test/?test=delta) to five significant
figures against the test suite of paired Lab values and expected ΔE2000
published by
[\[Sharma\]](#biblio-sharma "The CIEDE2000 Color-Difference Formula: Implementation Notes, Supplementary Test Data, and Mathematical Observations")
and is correct.

```
// deltaE2000 is a statistically significant improvement
// over deltaE76 and deltaE94,
// and is recommended by the CIE and Idealliance
// especially for color differences less than 10 deltaE76
// but is wicked complicated
// and many implementations have small errors!

/**
 * @param {number} reference - Array of CIE Lab values: L as 0..100, a and b as around -150..150
 * @param {number} sample - Array of CIE Lab values: L as 0..100, a and b as around -150..150
 * @return {number} How different a color sample is from reference
 */

function deltaE2000 (reference, sample) {

 // Given a reference and a sample color,
 // both in CIE Lab,
 // calculate deltaE 2000.

 // This implementation assumes the parametric
 // weighting factors kL, kC and kH
 // (for the influence of viewing conditions)
 // are all 1, as seems typical.

 let [L1, a1, b1] = reference;
 let [L2, a2, b2] = sample;
 let C1 = Math.sqrt(a1 ** 2 + b1 ** 2);
 let C2 = Math.sqrt(a2 ** 2 + b2 ** 2);

 let Cbar = (C1 + C2)/2; // mean Chroma

 // calculate a-axis asymmetry factor from mean Chroma
 // this turns JND ellipses for near-neutral colors back into circles
 let C7 = Math.pow(Cbar, 7);
 const Gfactor = Math.pow(25, 7);
 let G = 0.5 * (1 - Math.sqrt(C7/(C7+Gfactor)));

 // scale a axes by asymmetry factor
 // this by the way is why there is no Lab2000 color space
 let adash1 = (1 + G) * a1;
 let adash2 = (1 + G) * a2;

 // calculate new Chroma from scaled a and original b axes
 let Cdash1 = Math.sqrt(adash1 ** 2 + b1 ** 2);
 let Cdash2 = Math.sqrt(adash2 ** 2 + b2 ** 2);

 // calculate new hues, with zero hue for true neutrals
 // and in degrees, not radians
 const π = Math.PI;
 const r2d = 180 / π;
 const d2r = π / 180;
 let h1 = (adash1 === 0 && b1 === 0)? 0: Math.atan2(b1, adash1);
 let h2 = (adash2 === 0 && b2 === 0)? 0: Math.atan2(b2, adash2);

 if (h1 < 0) {
 h1 += 2 * π;
 }
 if (h2 < 0) {
 h2 += 2 * π;
 }

 h1 *= r2d;
 h2 *= r2d;

 // Lightness and Chroma differences; sign matters
 let ΔL = L2 - L1;
 let ΔC = Cdash2 - Cdash1;

 // Hue difference, taking care to get the sign correct
 let hdiff = h2 - h1;
 let hsum = h1 + h2;
 let habs = Math.abs(hdiff);
 let Δh;

 if (Cdash1 * Cdash2 === 0) {
 Δh = 0;
 }
 else if (habs <= 180) {
 Δh = hdiff;
 }
 else if (hdiff > 180) {
 Δh = hdiff - 360;
 }
 else if (hdiff < -180) {
 Δh = hdiff + 360;
 }
 else {
 console.log("the unthinkable has happened");
 }

 // weighted Hue difference, more for larger Chroma
 let ΔH = 2 * Math.sqrt(Cdash2 * Cdash1) * Math.sin(Δh * d2r / 2);

 // calculate mean Lightness and Chroma
 let Ldash = (L1 + L2)/2;
 let Cdash = (Cdash1 + Cdash2)/2;
 let Cdash7 = Math.pow(Cdash, 7);

 // Compensate for non-linearity in the blue region of Lab.
 // Four possibilities for hue weighting factor,
 // depending on the angles, to get the correct sign
 let hdash;
 if (Cdash1 * Cdash2 === 0) {
 hdash = hsum;
 }
 else if (habs <= 180) {
 hdash = hsum / 2;
 }
 else if (hsum < 360) {
 hdash = (hsum + 360) / 2;
 }
 else {
 hdash = (hsum - 360) / 2;
 }

 // positional corrections to the lack of uniformity of CIELAB
 // These are all trying to make JND ellipsoids more like spheres

 // SL Lightness crispening factor
 // a background with L=50 is assumed
 let lsq = (Ldash - 50) ** 2;
 let SL = 1 + ((0.015 * lsq) / Math.sqrt(20 + lsq));

 // SC Chroma factor, similar to those in CMC and deltaE 94 formulae
 let SC = 1 + 0.045 * Cdash;

 // Cross term T for blue non-linearity
 let T = 1;
 T -= (0.17 * Math.cos(( hdash - 30) * d2r));
 T += (0.24 * Math.cos( 2 * hdash * d2r));
 T += (0.32 * Math.cos(((3 * hdash) + 6) * d2r));
 T -= (0.20 * Math.cos(((4 * hdash) - 63) * d2r));

 // SH Hue factor depends on Chroma,
 // as well as adjusted hue angle like deltaE94.
 let SH = 1 + 0.015 * Cdash * T;

 // RT Hue rotation term compensates for rotation of JND ellipses
 // and Munsell constant hue lines
 // in the medium-high Chroma blue region
 // (Hue 225 to 315)
 let Δθ = 30 * Math.exp(-1 * (((hdash - 275)/25) ** 2));
 let RC = 2 * Math.sqrt(Cdash7/(Cdash7 + Gfactor));
 let RT = -1 * Math.sin(2 * Δθ * d2r) * RC;

 // Finally calculate the deltaE, term by term as root sum of squares
 let dE = (ΔL / SL) ** 2;
 dE += (ΔC / SC) ** 2;
 dE += (ΔH / SH) ** 2;
 dE += RT * (ΔC / SC) * (ΔH / SH);
 return Math.sqrt(dE);
 // Yay!!!
};
```

### 20.3. ΔEOK

Because Oklab does not suffer from the hue linearity, hue uniformity,
and chroma non-linearities of CIE Lab, the color difference metric does
not need to correct for them and so ΔEOK is simply the Euclidean
distance in Oklab color space.

```
// Calculate deltaE OK
// simple root sum of squares
/**
 * @param {number} reference - Array of OKLab values: L as 0..1, a and b as -1..1
 * @param {number} sample - Array of OKLab values: L as 0..1, a and b as -1..1
 * @return {number} How different a color sample is from reference
 */
function deltaEOK (reference, sample) {
 let [L1, a1, b1] = reference;
 let [L2, a2, b2] = sample;
 let ΔL = L1 - L2;
 let Δa = a1 - a2;
 let Δb = b1 - b2;
 return Math.sqrt(ΔL ** 2 + Δa ** 2 + Δb ** 2);
}
```

### 20.4. ΔEOK2

As a color difference metric, ΔEOK under-estimates differences in
colorfulness, compared to differences in lightness. Experimentation
revealed that
[scaling](https://github.com/w3c/csswg-drafts/issues/6642#issuecomment-945714988)
[a](https://drafts.csswg.org/css-color-5/#valdef-oklab-a) and
[b](https://drafts.csswg.org/css-color-5/#valdef-oklab-b) by a factor of 2, greatly [increased the
predictive accuracy of an Oklab-based
ΔE](https://github.com/svgeesus/deltaE-OK2/tree/main), when compared to
ΔE2000. Instead of changing the definition of Oklab, which is now widely
adopted, this produces another distance metric ΔEOK2.

```
// Calculate deltaE OK2
// root sum of squares, scale a and b by 2
/**
 * @param {number} reference - Array of OKLab values: L as 0..1, a and b as -1..1
 * @param {number} sample - Array of OKLab values: L as 0..1, a and b as -1..1
 * @return {number} How different a color sample is from reference
 */
function deltaEOK2 (reference, sample) {
 let [L1, a1, b1] = reference;
 let [L2, a2, b2] = sample;
 let ΔL = L1 - L2;
 let Δa = 2 * (a1 - a2);
 let Δb = 2 * (b1 - b2);
 return Math.sqrt(ΔL ** 2 + Δa ** 2 + Δb ** 2);
}
```

### 20.5. ΔEOKr2

A further improvement can be made by modifying the Lightness axis [to
add a
\"toe\"](https://bottosson.github.io/posts/colorpicker/#intermission---a-new-lightness-estimate-for-oklab).
This is particularly helpful where there is a significant white adaptive
stimulus (for example, a light-mode web page with a white background).
It also makes the lighness curve more similar to that of CIE Lab.

![Lightness functions of Oklrab and CIE Lab compared to
Oklab.](./images/oklab-Lr-vs-L.svg){height="520" width="560"}

In a color difference metric, this is used in combination with the
[a](https://drafts.csswg.org/css-color-5/#valdef-oklab-a) and
[b](https://drafts.csswg.org/css-color-5/#valdef-oklab-b) scaling.

While this is somewhat more complex than the original ΔEOK, it agrees
significantly better with ΔE2000, while still being far less complex
than ΔE2000.

**Implementations which are performance-sensitive are encouraged to use
ΔEOKr2 as a color difference metric.**

```
// Calculate deltaE OKr2
// root sum of squares, lightness toe, scale a and b by 2
/**
 * @param {number} reference - Array of OKLab values: L as 0..1, a and b as -1..1
 * @param {number} sample - Array of OKLab values: L as 0..1, a and b as -1..1
 * @return {number} How different a color sample is from reference
 */
function deltaEOKr2 (reference, sample) {
 let [L1, a1, b1] = reference;
 let [L2, a2, b2] = sample;
 L1 = toe(L1);
 L2 = toe(L2);
 let ΔL = L1 - L2;
 let Δa = 2 * (a1 - a2);
 let Δb = 2 * (b1 - b2);
 return Math.sqrt(ΔL ** 2 + Δa ** 2 + Δb ** 2);
}

// Add a lightness toe
// https://bottosson.github.io/posts/colorpicker/#intermission---a-new-lightness-estimate-for-oklab
/**
 * @param {number} x - Oklab lightness
 * @return {number} Toed lightness
 */
function toe (x) {
 const K1 = 0.206;
 const K2 = 0.03;
 const K3 = (1.0 + K1) / (1.0 + K2);
 return 0.5 * (K3 * x - K1 + Math.sqrt((K3 * x - K1) * (K3 * x - K1) + 4 * K2 * K3 * x));
}
```

## [ Appendix A: Deprecated CSS System Colors]
Earlier versions of CSS defined several additional [system
colors](#css-system-colors). These color keywords have been **deprecated**,
however, as they are insufficient for their original purpose (making
website elements look like their native OS counterparts), represent a
security risk by making it easier for a webpage to "spoof" a native OS
dialog, and increase fingerprinting surface, compromising user privacy.

User agents must support these keywords, and to mitigate fingerprinting
must map them to the (undeprecated) [system
colors](#css-system-colors) as listed below. **Authors must not use these
keywords.**

The deprecated system colors are represented as the
[[\<deprecated-color\>](#typedef-deprecated-color)] sub-type, and are defined as:

[ActiveBorder]
: Active window border. Computes to the color of
 [ButtonBorder](#valdef-color-buttonborder).

[ActiveCaption]
: Active window caption. Computes to the color of
 [Canvas](#valdef-color-canvas).

[AppWorkspace]
: Background color of multiple document interface. Computes to the
 color of
 [Canvas](#valdef-color-canvas).

[Background]
: Desktop background. Computes to the color of
 [Canvas](#valdef-color-canvas).

[ButtonHighlight]
: The color of the border facing the light source for 3-D elements
 that appear 3-D due to one layer of surrounding border. Computes to
 the color of
 [ButtonFace](#valdef-color-buttonface).

[ButtonShadow]
: The color of the border away from the light source for 3-D elements
 that appear 3-D due to one layer of surrounding border. Computes to
 the color of
 [ButtonFace](#valdef-color-buttonface).

[CaptionText]
: Text in caption, size box, and scrollbar arrow box. Computes to the
 color of
 [CanvasText](#valdef-color-canvastext).

[InactiveBorder]
: Inactive window border. Computes to the color of
 [ButtonBorder](#valdef-color-buttonborder).

[InactiveCaption]
: Inactive window caption. Computes to the color of
 [Canvas](#valdef-color-canvas).

[InactiveCaptionText]
: Color of text in an inactive caption. Computes to the color of
 [GrayText](#valdef-color-graytext).

[InfoBackground]
: Background color for tooltip controls. Computes to the color of
 [Canvas](#valdef-color-canvas).

[InfoText]
: Text color for tooltip controls. Computes to the color of
 [CanvasText](#valdef-color-canvastext).

[Menu]
: Menu background. Computes to the color of
 [Canvas](#valdef-color-canvas).

[MenuText]
: Text in menus. Computes to the color of
 [CanvasText](#valdef-color-canvastext).

[Scrollbar]
: Scroll bar gray area. Computes to the color of
 [Canvas](#valdef-color-canvas).

[ThreeDDarkShadow]
: The color of the darker (generally outer) of the two borders away
 from the light source for 3-D elements that appear 3-D due to two
 concentric layers of surrounding border. Computes to the color of
 [ButtonBorder](#valdef-color-buttonborder).

[ThreeDFace]
: The face background color for 3-D elements that appear 3-D due to
 two concentric layers of surrounding border. Computes to the color
 of
 [ButtonFace](#valdef-color-buttonface).

[ThreeDHighlight]
: The color of the lighter (generally outer) of the two borders facing
 the light source for 3-D elements that appear 3-D due to two
 concentric layers of surrounding border. Computes to the color of
 [ButtonBorder](#valdef-color-buttonborder).

[ThreeDLightShadow]
: The color of the darker (generally inner) of the two borders facing
 the light source for 3-D elements that appear 3-D due to two
 concentric layers of surrounding border. Computes to the color of
 [ButtonBorder](#valdef-color-buttonborder).

[ThreeDShadow]
: The color of the lighter (generally inner) of the two borders away
 from the light source for 3-D elements that appear 3-D due to two
 concentric layers of surrounding border. Computes to the color of
 [ButtonBorder](#valdef-color-buttonborder).

[Window]
: Window background. Computes to the color of
 [Canvas](#valdef-color-canvas).

[WindowFrame]
: Window frame. Computes to the color of
 [ButtonBorder](#valdef-color-buttonborder).

[WindowText]
: Text in windows. Computes to the color of
 [CanvasText](#valdef-color-canvastext).

Tests

- [deprecated-sameas-001.html](https://wpt.fyi/results/css/css-color/deprecated-sameas-001.html "css/css-color/deprecated-sameas-001.html")
 [[(live
 test)]](http://wpt.live/css/css-color/deprecated-sameas-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/deprecated-sameas-001.html)
- [deprecated-sameas-002.html](https://wpt.fyi/results/css/css-color/deprecated-sameas-002.html "css/css-color/deprecated-sameas-002.html")
 [[(live
 test)]](http://wpt.live/css/css-color/deprecated-sameas-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/deprecated-sameas-002.html)
- [deprecated-sameas-003.html](https://wpt.fyi/results/css/css-color/deprecated-sameas-003.html "css/css-color/deprecated-sameas-003.html")
 [[(live
 test)]](http://wpt.live/css/css-color/deprecated-sameas-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/deprecated-sameas-003.html)
- [deprecated-sameas-004.html](https://wpt.fyi/results/css/css-color/deprecated-sameas-004.html "css/css-color/deprecated-sameas-004.html")
 [[(live
 test)]](http://wpt.live/css/css-color/deprecated-sameas-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/deprecated-sameas-004.html)
- [deprecated-sameas-005.html](https://wpt.fyi/results/css/css-color/deprecated-sameas-005.html "css/css-color/deprecated-sameas-005.html")
 [[(live
 test)]](http://wpt.live/css/css-color/deprecated-sameas-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/deprecated-sameas-005.html)
- [deprecated-sameas-006.html](https://wpt.fyi/results/css/css-color/deprecated-sameas-006.html "css/css-color/deprecated-sameas-006.html")
 [[(live
 test)]](http://wpt.live/css/css-color/deprecated-sameas-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/deprecated-sameas-006.html)
- [deprecated-sameas-007.html](https://wpt.fyi/results/css/css-color/deprecated-sameas-007.html "css/css-color/deprecated-sameas-007.html")
 [[(live
 test)]](http://wpt.live/css/css-color/deprecated-sameas-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/deprecated-sameas-007.html)
- [deprecated-sameas-008.html](https://wpt.fyi/results/css/css-color/deprecated-sameas-008.html "css/css-color/deprecated-sameas-008.html")
 [[(live
 test)]](http://wpt.live/css/css-color/deprecated-sameas-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/deprecated-sameas-008.html)
- [deprecated-sameas-009.html](https://wpt.fyi/results/css/css-color/deprecated-sameas-009.html "css/css-color/deprecated-sameas-009.html")
 [[(live
 test)]](http://wpt.live/css/css-color/deprecated-sameas-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/deprecated-sameas-009.html)
- [deprecated-sameas-010.html](https://wpt.fyi/results/css/css-color/deprecated-sameas-010.html "css/css-color/deprecated-sameas-010.html")
 [[(live
 test)]](http://wpt.live/css/css-color/deprecated-sameas-010.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/deprecated-sameas-010.html)
- [deprecated-sameas-011.html](https://wpt.fyi/results/css/css-color/deprecated-sameas-011.html "css/css-color/deprecated-sameas-011.html")
 [[(live
 test)]](http://wpt.live/css/css-color/deprecated-sameas-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/deprecated-sameas-011.html)
- [deprecated-sameas-012.html](https://wpt.fyi/results/css/css-color/deprecated-sameas-012.html "css/css-color/deprecated-sameas-012.html")
 [[(live
 test)]](http://wpt.live/css/css-color/deprecated-sameas-012.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/deprecated-sameas-012.html)
- [deprecated-sameas-013.html](https://wpt.fyi/results/css/css-color/deprecated-sameas-013.html "css/css-color/deprecated-sameas-013.html")
 [[(live
 test)]](http://wpt.live/css/css-color/deprecated-sameas-013.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/deprecated-sameas-013.html)
- [deprecated-sameas-014.html](https://wpt.fyi/results/css/css-color/deprecated-sameas-014.html "css/css-color/deprecated-sameas-014.html")
 [[(live
 test)]](http://wpt.live/css/css-color/deprecated-sameas-014.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/deprecated-sameas-014.html)
- [deprecated-sameas-015.html](https://wpt.fyi/results/css/css-color/deprecated-sameas-015.html "css/css-color/deprecated-sameas-015.html")
 [[(live
 test)]](http://wpt.live/css/css-color/deprecated-sameas-015.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/deprecated-sameas-015.html)
- [deprecated-sameas-016.html](https://wpt.fyi/results/css/css-color/deprecated-sameas-016.html "css/css-color/deprecated-sameas-016.html")
 [[(live
 test)]](http://wpt.live/css/css-color/deprecated-sameas-016.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/deprecated-sameas-016.html)
- [deprecated-sameas-017.html](https://wpt.fyi/results/css/css-color/deprecated-sameas-017.html "css/css-color/deprecated-sameas-017.html")
 [[(live
 test)]](http://wpt.live/css/css-color/deprecated-sameas-017.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/deprecated-sameas-017.html)
- [deprecated-sameas-018.html](https://wpt.fyi/results/css/css-color/deprecated-sameas-018.html "css/css-color/deprecated-sameas-018.html")
 [[(live
 test)]](http://wpt.live/css/css-color/deprecated-sameas-018.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/deprecated-sameas-018.html)
- [deprecated-sameas-019.html](https://wpt.fyi/results/css/css-color/deprecated-sameas-019.html "css/css-color/deprecated-sameas-019.html")
 [[(live
 test)]](http://wpt.live/css/css-color/deprecated-sameas-019.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/deprecated-sameas-019.html)
- [deprecated-sameas-020.html](https://wpt.fyi/results/css/css-color/deprecated-sameas-020.html "css/css-color/deprecated-sameas-020.html")
 [[(live
 test)]](http://wpt.live/css/css-color/deprecated-sameas-020.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/deprecated-sameas-020.html)
- [deprecated-sameas-021.html](https://wpt.fyi/results/css/css-color/deprecated-sameas-021.html "css/css-color/deprecated-sameas-021.html")
 [[(live
 test)]](http://wpt.live/css/css-color/deprecated-sameas-021.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/deprecated-sameas-021.html)
- [deprecated-sameas-022.html](https://wpt.fyi/results/css/css-color/deprecated-sameas-022.html "css/css-color/deprecated-sameas-022.html")
 [[(live
 test)]](http://wpt.live/css/css-color/deprecated-sameas-022.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/deprecated-sameas-022.html)
- [deprecated-sameas-023.html](https://wpt.fyi/results/css/css-color/deprecated-sameas-023.html "css/css-color/deprecated-sameas-023.html")
 [[(live
 test)]](http://wpt.live/css/css-color/deprecated-sameas-023.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/deprecated-sameas-023.html)

## [ Appendix B: Deprecated Quirky Hex Colors]
When CSS is being parsed in [quirks
mode](https://dom.spec.whatwg.org/#concept-document-quirks),
[[\<quirky-color\>](#typedef-quirky-color)] is a type of
[\<color\>](#typedef-color) that is only valid in certain properties:

- [background-color](https://drafts.csswg.org/css-backgrounds-3/#propdef-background-color)

- [border-color](https://drafts.csswg.org/css-backgrounds-3/#propdef-border-color)

- [border-top-color](https://drafts.csswg.org/css-backgrounds-3/#propdef-border-top-color)

- [border-right-color](https://drafts.csswg.org/css-backgrounds-3/#propdef-border-right-color)

- [border-bottom-color](https://drafts.csswg.org/css-backgrounds-3/#propdef-border-bottom-color)

- [border-left-color](https://drafts.csswg.org/css-backgrounds-3/#propdef-border-left-color)

- [color](#propdef-color)

It is *not* valid in properties that include or reference these
properties, such as the
[background](https://drafts.csswg.org/css-backgrounds-3/#propdef-background) shorthand, or inside [functional
notations](https://drafts.csswg.org/css-values-4/#functional-notation) [such as
[color-mix()](https://drafts.csswg.org/css-color-5/#funcdef-color-mix)]

Additionally, while
[\<quirky-color\>](#typedef-quirky-color) must be valid as a
[\<color\>](#typedef-color) when parsing the affected properties in the
[\@supports](https://drafts.csswg.org/css-conditional-3/#at-ruledef-supports) rule, it is *not* valid for those properties
when used in the
[`CSS.supports()`](https://drafts.csswg.org/css-conditional-3/#dom-css-supports-conditiontext) method.

A
[\<quirky-color\>](#typedef-quirky-color) can be represented as a
[\<number-token\>](https://drafts.csswg.org/css-syntax-3/#typedef-number-token),
[\<dimension-token\>](https://drafts.csswg.org/css-syntax-3/#typedef-dimension-token), or
[\<ident-token\>](https://drafts.csswg.org/css-syntax-3/#typedef-ident-token), according to the following rules:

- If it's an
 [\<ident-token\>](https://drafts.csswg.org/css-syntax-3/#typedef-ident-token), the token's representation must
 contain exactly 3 or 6 characters, all hexadecimal digits. It
 represents a
 [\<hex-color\>](#typedef-hex-color) with the same value.

- If it's a
 [\<number-token\>](https://drafts.csswg.org/css-syntax-3/#typedef-number-token), it must have its integer flag set.

 Serialize the integer's value. If the serialization has less than 6
 characters, prepend \"0\" characters to it until it is 6 characters
 long. It represents a
 [\<hex-color\>](#typedef-hex-color) with the same value.

- If it's a
 [\<dimension-token\>](https://drafts.csswg.org/css-syntax-3/#typedef-dimension-token), it must have its integer flag set.

 Serialize the integer's value, and append the representation of the
 token's unit. If the result has less than 6 characters, prepend \"0\"
 characters to it until it is 6 characters long. It represents a
 [\<hex-color\>](#typedef-hex-color) with the same value.

(In other words, Quirks Mode allows hex colors to be written without the
leading \"#\", but with weird parsing rules.)

Tests

quirky hex colors

------------------------------------------------------------------------

## [ Acknowledgments]
In addition to [those who contributed to CSS Color
3](https://www.w3.org/TR/css-color-3/#acknowledgments), the editors
would like to thank Emilio Cobos Álvarez, Alexey Ardov, Chris Bai,
Amelia Bellamy-Royds, Lars Borg, Mike Bremford, Andreu Botella, Dan
Burzo, Max Derhak, fantasai, Simon Fraser, Devon Govett, Phil Green,
Dean Jackson, Andreas Kraushaar, Pierre-Anthony Lemieux, Tiaan Louw,
Cameron McCormack, Romain Menke, Chris Murphy, Isaac Muse, Jonathan
Neal, Chris Needham, Björn Ottosson, Christoph Päper, Brad Pettit,
Xidorn Quan, Craig Revie, Melanie Richards, Florian Rivoal, Jacob Rus,
Joseph Salowey, Simon Sapin, Igor Snitkin, Lea Verou, Mark Watson, James
Stuckey Weber, Sam Weinig, and Natalie Weizenbaum.

## [ Changes]
### [Changes since the [Candidate Recommendation Draft of 24 April 2025](https://www.w3.org/TR/2025/CRD-css-color-4-20250424/)]
- Clarified that serialization of opacity-value applies to all
 properties which allow that as a value, not just the opacity property.
 ([Issue 10426](https://github.com/w3c/csswg-drafts/issues/10426))
- Removed \"If H is missing, a = b = 0\" from LCH and Oklch conversion
 code, which hindered round-tripping ([Issue
 14530](https://github.com/w3c/csswg-drafts/issues/14530))
- Clarified wording around equivalent colors, added many worked examples
- Clarified that intermediate values from color space conversion are not
 clamped, to enble error-free roundtripping [Issue
 9484](https://github.com/w3c/csswg-drafts/issues/9484)
- Gamut mapping applies to unorm8 canvas as well as displays ([Issue
 10112](https://github.com/w3c/csswg-drafts/issues/10112))
- Clarified that relative colorimetric is good for gradients, while
 perceptual is for photographic images ([Issue
 14051](https://github.com/w3c/csswg-drafts/issues/14051))
- Explained relationship between progress and quantities, in color
 interpolation. Defined linear interpolation precisely. ([Issue
 14201](https://github.com/w3c/csswg-drafts/issues/14021))
- Force chroma to zero when hue is powerless during conversion ([Issue
 14133](https://github.com/w3c/csswg-drafts/issues/14133))
- Clarified the individual steps in interpolation, and their effects
 ([Issue 14347](https://github.com/w3c/csswg-drafts/issues/14347))
- Explained color difference metrics better, and added ΔΕOKr2 ([Issue
 14207](https://github.com/w3c/csswg-drafts/issues/14207))
- Added Oklab a,b plane diagrams for the sRGB, display-p3, a98-rgb,
 prophoto-rgb, and rec2020 predefined color spaces, alongside the
 existing CIE Lab diagrams
- Avoid referencing \"prepare for conversion\", just state directly
 ([Issue 14049](https://github.com/w3c/csswg-drafts/issues/14049))
- Clarified that the computed value of a deprecated system color is the
 color of the corresponding (non-deprecated) system color ([Issue
 3873](https://github.com/w3c/csswg-drafts/issues/3873), [Issue
 13459\>](https://github.com/w3c/csswg-drafts/issues/13459), [Issue
 13719](https://github.com/w3c/csswg-drafts/issues/13719))
- Consolidated the resolution of system colors and deprecated system
 colors ([Issue
 13450](https://github.com/w3c/csswg-drafts/issues/13450))
- Clarified carry-forward in color interpolation ([Issue
 14134](https://github.com/w3c/csswg-drafts/issues/14134))
- Split serialization of alpha values by whether legacy and modern
 syntax was used; require 16bit alpha ([Issue
 13994](https://github.com/w3c/csswg-drafts/issues/13994))
- Consistent mention of display-p3-linear in color(\...) syntax ([PR
 14024](https://github.com/w3c/csswg-drafts/pull/14024))
- Rework the color-scheme section to use the concepts of \'page color
 scheme\' and \'element color scheme\' ([Issue
 13857](https://github.com/w3c/csswg-drafts/pull/13857))
- Pick sRGB serialization form by presence of none ([Issue
 10254](https://github.com/w3c/csswg-drafts/issues/10254))
- For color comparisons in Oklab, standardized ε to be **0.00001**
 ([Issue
 13157](https://github.com/w3c/csswg-drafts/issues/13157#issuecomment-4329625711))
- Added a new section defining when two
 [\<color\>](#typedef-color) values are [equivalent
 colors](#equivalent-colors), covering same-color-space component comparison, the
 treatment of [missing
 component](#missing-color-component)s, and cross-color-space comparison via
 [oklab](#valdef-oklab-oklab). ([Issue
 13157](https://github.com/w3c/csswg-drafts/issues/13157))
- Clarified in the main Color interpolation section that, if the hue
 interpolaton method is not specified, shorter is the default. (This
 was already specified in the Hue Interpolation section). ([Issue
 13788](https://github.com/w3c/csswg-drafts/issues/13788))
- Expanded the concept of analogous components to analogous sets of
 components, to minimize
 [none](#valdef-color-none) → [0] conversions ([Issue
 10210](https://github.com/w3c/csswg-drafts/issues/10210))
- Split color conversion into two stages ([Issue
 10211](https://github.com/w3c/csswg-drafts/issues/10211))
- Clarified how system colors react to the used color scheme ([Issue
 13719](https://github.com/w3c/csswg-drafts/issues/13719))
- Updated abstract to mention color interpolation and gamut mapping.
- Clarified wording regarding the aims of CSS gamut mapping
- Corrected ray trace algorithm to not overwrite *end* ([Issue
 10579](https://github.com/w3c/csswg-drafts/issues/10579))
- Added pseudocode for the ray trace gamut mapping algorithm ([Issue
 10579](https://github.com/w3c/csswg-drafts/issues/10579))
- Added EdgeSeeker and Ray Trace Gamut Mapping Algorithms. Allowed
 choice of three GMA ([Issue
 10579](https://github.com/w3c/csswg-drafts/issues/10579))
- Added a diagram showing imaginary colors in CIE Lab
- Differentiated between out of gamut but physically realizable colors,
 and imaginary colors
- More even-handed description of clipping, showing some cases which
 give acceptable results ([Issue
 10579](https://github.com/w3c/csswg-drafts/issues/10579))
- Fixed discrepency in ΔE2000 sample implementation ([Issue
 13322](https://github.com/w3c/csswg-drafts/issues/13322))
- Updated
 [AccentColor](#valdef-color-accentcolor) to take its value from
 [accent-color](https://drafts.csswg.org/css-ui-4/#propdef-accent-color), unless in [Forced Colors
 Mode](https://drafts.csswg.org/css-color-adjust-1/#forced-colors-mode) ([Issue
 5900](https://github.com/w3c/csswg-drafts/issues/5900))
- Defined rec2020 color space to use display-referred, 2.4 gamma ([Issue
 12574](https://github.com/w3c/csswg-drafts/issues/12574))
- Added display-p3-linear to predefined colorspaces ([Issue
 11250](https://github.com/w3c/csswg-drafts/issues/11250))
- Clarified serializing opacity values with calc() ([Issue
 10426](https://github.com/w3c/csswg-drafts/issues/10426))
- Interpolation between legacy sRGB colors is (once again) in sRGB
 space, for compatibility ([Issue
 7949](https://github.com/w3c/csswg-drafts/issues/7949))
- Clarified real-world CIE Lab range for a and b ([Issue
 12208](https://github.com/w3c/csswg-drafts/issues/12208))
- Clarified that Opacity value does not affect hit testing ([Issue
 11339](https://github.com/w3c/csswg-drafts/issues/11339))

### [Changes since the [Candidate Recommendation Draft of 13 Feb 2024](https://www.w3.org/TR/2024/CRD-css-color-4-20240213/)]
- Clarified that inside the color property, it is the resolved inherited
 value (not the raw inherited value) that is used
- Listed categories of colors, such as those that resolve to sRGB or
 support legacy color syntax
- Added hue normalization examples
- Corrected table of analogous components, alpha was missing, but
 described as analogous in prose
- Collected together and clarified serialization of opacity values into
 one section
- Clarified wording around color-interpolation-method and host syntax
- Defined epsilon for returning missing hue
- Used a more precise definition of achromatic colors with missing hues
 (sufficiently close to the central axis)
- Consistently use \"color component\" rather than \"color channel\"
 (both were being used).
- Correlated Color Temperature was used without being defined or
 explained. Added informative reference.
- Exported term premultiplied, linked to it consistently
- Equivalence of deprecated and un-deprecated system colors is no longer
 at-risk
- Clarified intended use of the \"parse a CSS
 [\<color\>](#typedef-color)\" algorithm
- Added corrected examples for HTML-compatible serialization
- Removed check on missing values for HTML-compatible serialization,
 they will already have been converted to zero
- Moved note about missing values becoming 0, so it applies to both
 HTML-compatible and CSS serializations
- Added an HTML-Compatible hex serialization for sRGB
- Added another xyz-d65 and xyz-d50 example
- Clarify which component (Y) in XYZ corresponds to brightness
- Clarified that CSS gamut mapping applies on actual, not used, values
- Removed hue normalization from the hslToRgb sample code, as the input
 is already normalized at parse time
- Corrected the pseudo-code for step 4 of the gamut mapping algorithm
- Clarified that interpolation is the most common situation which
 combines two colors, but not the only one.
- Ensured adequate contrast for text in the deltaE table
- Removed remaining use of the term \<absolute-color-function\>, use
 \<absolute-color\> function instead for consistency
- Updated acknowledgements section
- Added gamut mesh diagram
- Described CSSOM serialization in terms of declared values rather than
 specified values
- Added exported definition of luminance
- Added production rule for \<opacity-value\>
- Clarified when results from hslToRgb will be in \[0,1\]
- Clarified that once linearized, RGB spaces are additive

### [Changes since the [Candidate Recommendation Draft of 1 November 2022](https://www.w3.org/TR/2022/CRD-css-color-4-20221101/) ]
- Added steps for serializing a uint8_t alpha, moved from cssom-1
- Restored parse-time clamping of HSL negative saturation to 0, which is
 current interop behavior from CSS Color 3
- When interpolating, always convert color space, so that powerless
 components become missing
- Clarified when alpha 1 is omitted from serialization
- Removed redundant constraining of hue angles to \[0,360\] as this is
 already done.
- Corrected description of ActiveCaption, which is a background.
- Disambiguated opacity and alpha. Opacity property now uses
 opacity-value (which has different clamping behavior to alpha-value)
- Clarified that carrying forward happens before premultiplication
- Updated gamut mapping algorithm
- Fixed a few issues regarding hue interpolation
- Clarified that HWB white or black at 100% is insufficient criterion
 for an achromatic color; it is the sum which matters.
- Avoid returning negative saturation in rgb to hsl conversion; adjust
 the hue to point to \"the other side\" instead
- Use 64 bit accurate matrices for ProPhoto, which does not have a
 rational form
- Oklab matrices recalculated for 64bit precision (returns same results
 as before, at 32 bit precision)
- Consistently return output of GMA in the destination color space, even
 if no mapping is performed because the destination is unbounded
- Added explanation for why one JND for Oklab is 0.02, not 2
- Clarified that resolving sRGB values does not apply to the color()
 function
- Moved alpha value definition up to the opacity property, clarified
 that opacity specified values are not clamped.
- System Colors now explicitly permit spoofing, to preserve privacy
- Corrected the inverse chromatic adaptation matrix for D50 to D65
- Consistently distinguish linear Bradfrod from the original, more
 complicated, Bradford chromatic adaptation algorithm
- In the gamut mapping algorithm, return clipped as the gamut mapped
 result, avoiding un-necessary steps
- Updated chromatic adaptation matrices to higher precision
- Added Add \'parse a css color\' algorithm, so non-CSS specs using
 colors don't have to reinvent the machinery here.
- Clarified that geometric gamut mapping must not project chroma back
 beyond the original color
- Use the term \"geometric\" rather than \"analytical\" in gamut mapping
 discussion
- Aligned prose for HSL into line with the grammar (percent and number
 both allowed)
- Fixed an LCH alpha interpolation example, which was erroneously
 un-premultiplying the hue angle
- Corrected the sRGB and display-p3 transfer function. (This only
 affected the result if a component had the exact value 10.31475 / 255,
 which is not possible at 8 or 10 bits per component)
- Clarified that the specified values of system colors are still
 themselves
- Added mention of PNG cICP chunk for tagging images
- Described behaviour of hue increasing and decreasing when 0/360 is
 passed
- Aligned description of powerlessnes in HSL with the other polar color
 models
- Explicitly defined order of operations for color interpolation
- Added mention of degenerate numeric constants in calc()
- Clarified that calc() in sRGB has early resolution, and clamps the
 result
- Clarified that HWB hue has the same disadvantages as HSL hue
- Added luminance to lightness comparison and figure
- Added descriptions and examples for hue interpolation keywords
- Use normative prose for achromatic HWB colors
- Corrected hue interpolation angle range; \[0,360) not \[0,360\]
- Expressed that displaying as black or white when L=0% or 100% is due
 to gamut mapping. Removed incorrect assertions of powerlessness
- Dropped the confusing \"representing black\" and \"representing
 white\" comments
- Clarified that opponent a and b are analogous
- Specified RGB components using reference ranges rather than prose, for
 consistency
- Explicitly referenced percent reference ranges for percentage to
 number conversion when serializing Lab, LCH, Oklab, OkLCh
- Required Oklab interpolation, remove previous \"may\", describe
 explicit opt-out
- Labelled the Lab, LCH, Oklab and OkLCh tutorial sections as
 non-normative. Moved some definitions out of the non-normative
 section.
- Clarified that, when interpolating, checking for analogous components
 happens before color space conversion
- Back-ported hwb() syntax changes and reference ranges from CSS Color 5
- Defined carry-forward operations must happen before powerless
 operations
- Clarified it is *color* components which must be all-number or
 all-percentage, in legacy rgb() syntax
- Clarified for legacy syntax that color components must be
 all-percentage or all-number
- Added examples of specified out of range alpha, with and without
 calc()
- Placed examples of serializing with trimmed trailing zeroes colorer to
 the relevant text
- clarified example, used value of text-shadow
- Clarified resolving currentColor
- Updated acknowledgments
- Stop claiming that achromatic colors have missing a,b, or chroma
- HSL and HWB changed to unbounded gamut, to promote round-tripping
- Defined percentage reference range for HSL
- Modern color syntax hsl() and hsla() allow mixed number and percentage
 components
- Modern color syntax rgb() and rgba() allow mixed number and percentage
 components
- Define the term \"modern color syntax\" (legacy color syntax already
 defined).
- Consistently use the term \"analogous components\"
- Changed to allow all predefined color spaces for interpolation
- Clarified that for color(), three parameters (RGB or XYZ) are required
- Clarified serialization of named colors, system colors, and
 transparent
- Define specified value for Lab, LCH, Oklab, OkLCh
- Define specified value for other sRGB colors
- Define specified values for named and system colors
- Clamp alpha, Lightness, Chroma and Hue at parsed-value time
- Remove passing mention of specular white and CIE Lightness
- No longer require as-specified Hue to be retained; clamp to \[0, 360\]
- Consistent serialization of Lightness and number in examples
- Minor typos and editorial clarifications

### [Changes since the [Candidate Recommendation of 5 July 2022](https://www.w3.org/TR/2022/CR-css-color-4-20220705/) ]
- Removed hue interpolation \"specified\" value
- Defined hue interpolation angle more precisely, maintaining
 differences of 360deg
- Added example of carried forward alpha for premultiplication
- Clarified a,b and C,h powerless at L=100% representing white.
- Removed handwavy mention of L=400 which applies to hdr-CIELAB not CIE
 Lab
- Consistent capitalization of Oklab and OkLCh
- Moved definitions of valid color, invalid color, out of gamut and in
 gamut to terminology section
- Fixed definition of \"longer\" hue interpolation
- Further clarified the concept of a host syntax
- Accessibility improvements for color swatches
- Made explicit that legacy forms do not support \"none\"
- Remove \"none\" from the hue production, as it is not allowed in
 legacy syntax
- Removed some dangling references to CMYK and CMYKOGV, moved to CSS
 Color5
- Clarified how missing values in colors to be interpolated are carried
 forward
- Updated syntax of xyz-params so they take numbers and percentage, to
 align with prose
- Ensure all examples and figures have IDs, self-links
- Clarified importance to implementors of reading the gamut mapping
 introduction
- Removed left-over mention of custom color spaces (feature was moved to
 CSS Color 5)
- Refactor syntax of \<color\> and \<alpha-value\>
- Editorial refactoring for better reading order.
- Updated pseudocode for gamut mapping algorithm, remove un-needed
 deltaE calls

### [Changes since the [Working Draft of 28 June 2022](https://www.w3.org/TR/2022/WD-css-color-4-20220628/) ]
- Updated status for Candidate Recommendation

### [Changes since the [Working Draft of 28 April 2022](https://www.w3.org/TR/2022/WD-css-color-4-20220428/) ]
- Moved opacity property up to the top of the module, next to color
 property, before getting into details.
- Improved description of the color property, in particular effect on
 other properties
- Corrected longer hue adjust equation, for equal-modulo-360 colors
- Added two new System colors: AccentColor and AccentColorText
- Described overall color space conversion steps in new section
- Accounted for [none](#valdef-color-none) alpha in premultiplication and
 un-premultiplication

### [Changes since the [Working Draft of 15 December 2021](https://www.w3.org/TR/2021/WD-css-color-4-20211215/) ]
- Made system colors fully resolve, but forbid their alteration in
 forced colors mode
- Removed forgiveness for incorrect number of parameters in color()
 function
- Changed serialization of CIE Lightness and OK Lightness to number
 rather than percentage.
- Marked deprecated system color equivalences as at-risk
- Added reference ranges to percentage values for CIE and OK L,a,b,C
- Noted that there is sample code for performing and undoing
 premultiplication, for both rectangular and polar color spaces.
- Added out of range clamping to the gamut mapping prose, as well as the
 pseudocode
- Added normative reference for ProPhoto RGB / ROMM
- Corrected sRGB and Display P3 black point value for reference surround
- Added normative reference for Display P3
- Avoided an infinite loop in gamut reduction, with colors whiter than
 white or darker than black
- Clarified serialization of the
 [none](#valdef-color-none) value
- Clarified the opt-in to interpolation in Oklab, for non-legacy colors
- Defined how premultiplication works, with the
 [none](#valdef-color-none) value
- Clarified that missing values in rgb serialize as 0
- Clarified the use of calc() with the
 [none](#valdef-color-none) value
- Typo, inconsistent casing on System Colors
- Added example of SelectedItem with SelectedItemText
- Explicitly noted the presence or absence of legacy colors
- Added normative reference for CIE XYZ
- Added normative reference for HWB and HSL
- Clarified that [hwb()](#funcdef-hwb) is not a legacy syntax so does not support the
 older, comma-separated syntactic form
- Clarified that only legacy colors will gamut map, the others are
 unbounded
- Use distinct terms, spectrophotometer and spectroradiometer
- Assorted minor typos fixed, and grammatical improvements

### [Changes since the [Working Draft of 1 June 2021](https://www.w3.org/TR/2021/WD-css-color-4-20210601/) ]
- Added gamut mapping section and defined a CSS gamut mapping algorithm
 as chroma reduction in OkLCh with local MINDE.
- Computed value of color(xyz \...) is color(xyz-d65 \...)
- Added srgb-linear to interpolation color spaces
- Updated Changes from Colors 3 section
- Added Resolving Oklab and OkLCh values section
- Added srgb-linear color space
- Moved \@color-profile and device-cmyk to level 5 per CSSWG resolution
- Defined interpolation color space
- Clarified that matrices are row-major and linked to the matrix
 multiplication library
- Split old Security & Privacy section into separate sections
- Defined quirks-mode quirky hex colors
- Removed fallback colors from device-cmyk
- Host syntax that does not declare a default now uses Oklab by default
- Added sample code for deltaE OK
- Added sample conversion code for OKlab and OkLCh
- Added oklab() and oklch() functions *Added description of Oklab and
 OkLCh*
- Added description of CIE LCH deficiencies
- Allowed all components of a color to be \"missing\" via the
 [none](#valdef-color-none) keyword, defined when components are \"powerless\"
 and automatically become missing in some cases, and fixed all
 references to \"NaN\" components to use the \"missing\" concept.
- Defined explicit x,y whitepoint values, use consistently throughout
- Defined the term host syntax
- Defined context for resolving override-color colors
- Added a new pair of system colors
- Corrected HSL and HWB sample code
- Replaced table of HSL values with error-free version
- Added Lea Verou as co-editor by WG resolution
- Clarified that hue angle is unbounded
- MarkText example corrected
- Added diagrams, corrected examples
- Some editorial clarifications
- Minor typos corrected, markup corrections

### [Changes since the [Working Draft of 12 November 2020](https://www.w3.org/TR/2020/WD-css-color-4-20201112/) ]
- Noted indeterminate hue ssue on near-neutral Lab values converted to
 LCH
- Clarified which steps are linear combinations in RGB Lab
 interconversion
- Added components descriptor to \@color-profile, for use in CSS Color 5
- All predefined RGB color spaces are defined over the extended range
- Clarified that there is no gamut mapping or gamut clipping step prior
 to color interpolation
- Clarified interpolation of legacy sRGB syntaxes
- Removed the lab option from
 [color()](#funcdef-color)
- List steps to interconvert between predefined color spaces
- Consistent use of the term color space (two words)
- Provided more guidance on selecting color space for mixing
- Recalculated an example to increase precision
- Added hue interpolation example
- Simplified [color()](#funcdef-color) syntax by removing the fallback options
- Clarified the types of ICC profile that may be linked from
 \@color-profile
- Support for the rare ICC Named Colors was removed
- Improved precision of standard whitepoint chromaticities
- Removed a trademark from description of one predefined color space
- Rephrased interpolation to be more generic wrt to interpolation space
- Corrected Accessibility Considerations section
- Clarified that the color space argument for
 [color()](#funcdef-color) is mandatory, even for sRGB
- Clarified that currentColor is not restricted to sRGB
- Small correction to the sRGB to XYZ to sRGB matrices, improve
 round-tripping
- Clarified the rec2020 transfer function, citing the correct ITU Rec
 BT.2020-2 reference
- Correct fallback examples to use the correct syntax
- Don't force non-legacy colors to interpolate in a gamma-encoded space
- Define premultiplied alpha interpolation
- Start to address interpolation to and from currentColor
- Define hue interpolation with NaN
- Generalize color interpolation
- Define interpolation to be in Lab, with override to LCG
- Corrections to hue interpolation
- Defined hue angle interpolation
- Added interpolation section
- Corrected syntax in some examples
- Clarify exactly which components are allowed percentages, in
 [color()](#funcdef-color)
- Change to serialize [lch()](#funcdef-lch) as itself rather than as
 [lab()](#funcdef-lab)
- Minimum 10 bits per component precision for non-legacy sRGB in
 [color()](#funcdef-color)
- color space no longer optional in
 [color()](#funcdef-color)
- Consistent minimum precision between lab() and color(lab)
- Clarified fallback procedure for the color() function -- first valid
 in-gamut color, else first valid color which is then gamut mapped,
 else transparent black
- Clarified difference between opacity property and colors with opacity,
 notably for rendering overlapping text glyphs
- Added sample (but verified correct) code for ΔE2000
- Added definition of previously-undefined term chromaticity, with
 examples; define chromaticity diagram.
- Added explanation of color additivity, with examples
- Added source links to WPT tests
- Export definition of color, and valid color, for other specifications
 to reference
- Define minimum number of bits per component, for serialization
- Updated \"applies to\" definitions (CSS-wide change)
- Added image state (display referred or scene referred) for predefined
 color spaces
- Listed white point correlated color temperature (e.g. D65) alongside
 chromaticity coordinates, for clarity
- Clarified that rounding is towards +∞
- Correction of typos, markup corrections, link fixes

### [Changes since [Working Draft of 5 November 2019](https://www.w3.org/TR/2019/WD-css-color-4-20191105/)]
- Export some terms for use in other specifications
- Update requirement from WCAG 2.0 to 2.1
- Fully specify Unicode characters used for serialization
- Define serialization of special named colors
- Define serialization of device-cmyk()
- Define serialization of
 [color()](#funcdef-color)
- Fully define RGB serialization, in maximally web-compatible way
- Define serialization of Lab and LCH
- Fully define serialization of alpha values
- Consistency pass to avoid accidental RFC2119
- Add IDs to all the examples, to enable referencing
- Separate resolved color and serialized color sections
- (Security) ICC profiles have no executable code
- Define what out-of-range means for profiled colors
- Clarify out-of-range clamping
- Add examples of specified values
- Clarify computed values
- Resist fingerprinting, with mandatory mappings for deprecated system
 colors
- Added explanatory note on history and reason for standardizing X11
 colors
- Correct hwb sample code
- Add table of DeltaE2000 values for MacBeth patches
- Add note on ICC profile Internet Media type
- Add reference to PNG sRGB chunk
- Clarify CMYK to Lab interconversion
- Clarify RGB to Lab interconversion
- More comparison of HSL vs. LCH
- More description for Rec BT.2020 color space
- Updated description of prophoto-rgb
- Removed duplicate \"keywords\" from Value Definitions section
- Added an example of an invalid color
- Added example with multiple fallbacks
- Assorted typos and markup fixes
- Clarify handling for undeclared custom color spaces
- Clarify some examples and explanatory notes
- Handling for valid and invalid ICC profiles
- Define handling for images with explicit tagged color space
- Define color space for 4k, SDR video
- State that user contrast settings mst take precedence
- Clarify meaning of system colors outside for forced-color mode
- Update default style rules
- Add CIE XYZ color space to
 [color()](#funcdef-color)
- Greater clarity on hue angles, NaN explicitly allowed
- Improve section on system color pairings, require AA accessible
 contrast
- Warn of interaction between overlapping glyphs and the opacity
 property
- Correct grammar in color definition
- Improve description of Highlight/HighlightText
- Correct prophoto-rgb transfer function
- More precision for prophoto-rgb primaries
- Started to define \"can't be displayed\"
- Removed paragraph about canvas surface
- Added the buttonborder, mark, and marktext system colors
- Added reverse conversion, sRGB to HWB
- Clarified polar spaces are cylindrical, not spherical
- Added an Accessibility Considerations section
- Started to describe chroma-reduction gamut mapping rather than
 per-component clipping
- Corrected white chromaticity for rec2020
- Made device-cmyk available by \@color-profile; updated CMYK to color
 algorithm to only use naive conversion as a last resort
- Added print-oriented CMYK and KCMYOGV examples
- User-defined color spaces now dashed-ident, making predefined color
 spaces extensible without clashes
- Added lab option to the color() function
- Added normative reference for CIE Lab
- Clarified that prophoto-rgb uses [D50](#d50) whitepoint so does not require adaptation
- Clarified direction of increasing angle in LCH
- Clarified that color names are ASCII case insensitive
- Initial value of the \"color\" property is now CanvasText
- Removed confusing gray() function per CSS WG resolution
- Collect scattered definitions into new [Color
 terminology](#terminology) section
- Add helpful figures and more examples
- Minor editorial clarifications, spell check, fixing typos, bikeshed
 markup fixes

### [Changes since [Working Draft of 05 July 2016](http://www.w3.org/TR/2016/WD-css-color-4-20160705/)]
- Changed Lightness in Lab and LCH to be a percentage, for CSS
 compatibility
- Clamping of color values clarified
- Percentage opacity is now allowed
- Define terms sRGB and linear-light sRGB, for use by other specs
- Add new list of CSS system colors; renaming Text to CanvasText
- Make system color keywords compute to themselves
- Add computed/used entry for system colors
- Rewrite intro to non-deprecated system colors to center their use
 around forced-colors mode rather than generic use
- Consistent hyphenation of predefined color spaces
- Restore text about non-opaque elements painting at layers even when
 not positioned
- Initial value of the \"color\" property is now black
- Clarify hue in LCH is modulo 360deg (change now reverted)
- Clarify allowed range of L in LCH and Lab, and meaning of L=100
- Update references for color spaces used in video
- Add prophoto-rgb predefined color space
- Correct black and white luminance levels for display-p3
- Clarify display-p3 transfer function
- Add a98-rgb color space, correct table of primary chromaticities
- Clarify that currentColor's computed value is not the resolved color
- Update syntax is examples to conform to latest specification
- Remove the color-mod() function
- Drop the \"media\" from propdef tables
- Export, and consistently use, \"transparent black\" and \"opaque
 black\"
- Clarify calculated values such as percents
- Clarify required precision and rounding behavior for color components
- Clarify \"color\" property has no effect on color font glyphs (unless
 specifically referenced, e.g. with currentColor)
- Clarify how color values are resolved
- Clarify that HSL, HWB and named colors resolve to sRGB
- Simplify conversion from device-cmyk to sRGB
- Describe previous, comma-using color syntaxes as \"legacy\"; change
 examples to commaless form
- Remove superfluous requirement that displayed colors be restricted to
 device gamut (like there was any other option!)
- Rename P3 to display-p3; avoid claiming this is DCI P3, as these are
 not the same
- Improved description of the parameters to the \"color()\" function
- Disallow predefined spaces from \"@color-profile\" identifier
- Add canonical order to \"color\", \"color-adjust\" and \"opacity\"
 property definitions
- Switch definition of alpha compositing from SVG11 to CSS Compositing
- Clarify sample conversion code is non-normative
- Add Security and Privacy Considerations
- Update several references to most current versions
- Convert inline issues to links to GitHub issues
- Minor editorial clarifications, formatting and markup improvements

### [ Changes from Colors 3]
The primary change, compared to CSS Color 3, is that CSS colors are no
longer restricted to the narrow gamut of sRGB.

To support this, several brand new features have been added:

1. predefined, wide color gamut RGB color spaces
2. [lab()](#funcdef-lab), [lch()](#funcdef-lch),
 [oklab()](#funcdef-oklab) and
 [oklch()](#funcdef-oklch) functions, for device-independent color

Other technical changes:

1. Serialization of
 [\<color\>](#typedef-color) is now specified here, rather than in
 the CSS Object Model
2. [hwb()](#funcdef-hwb)
 function, for specifying sRGB colors in the HWB notation.
3. Addition of named color
 [rebeccapurple](#valdef-color-rebeccapurple).

In addition, there have been some syntactic changes:

1. [rgb()](#funcdef-rgb)
 and [rgba()](#funcdef-rgba) functions now accept
 [\<number\>](https://drafts.csswg.org/css-values-4/#number-value) rather than
 [\<integer\>](https://drafts.csswg.org/css-values-4/#integer-value).
2. [hsl()](#funcdef-hsl)
 and [hsla()](#funcdef-hsla) functions now accept
 [\<angle\>](https://drafts.csswg.org/css-values-4/#angle-value) as well as
 [\<number\>](https://drafts.csswg.org/css-values-4/#number-value) for hues.
3. [rgb()](#funcdef-rgb)
 and [rgba()](#funcdef-rgba), and [hsl()](#funcdef-hsl) and
 [hsla()](#funcdef-hsla) are now aliases of each other (all of them have
 an optional alpha).
4. [rgb()](#funcdef-rgb), [rgba()](#funcdef-rgba),
 [hsl()](#funcdef-hsl), and
 [hsla()](#funcdef-hsla) have all gained a new syntax consisting of
 space-separated arguments and an optional slash-separated opacity.
 All the color functions use this syntax form now, in keeping with
 [CSS's functional-notation design
 principles](https://wiki.csswg.org/ideas/functional-notation#general-principles).
5. All uses of
 [\<alpha-value\>](#typedef-color-alpha-value) now accept
 [\<percentage\>](https://drafts.csswg.org/css-values-4/#percentage-value) as well as
 [\<number\>](https://drafts.csswg.org/css-values-4/#number-value).
6. 4 and 8-digit hex colors have been added, to specify transparency.
7. The [none](#valdef-color-none) value has been added, to represent powerless
 components.

## 21. Security Considerations

The system colors, if they actually correspond to the user's system
colors, pose a security risk, as they make it easier for a malware site
to create user interfaces that appear to be from the system. However, as
several system colors are now defined to be \"generic\", this risk is
believed to be mitigated.

## 22. Privacy Considerations

This specification defines \"system\" colors, which theoretically can
expose details of the user's OS settings, which is a fingerprinting
risk.

## 23. Accessibility Considerations

This specification [encourages authors to not use color
alone](#accessibility) as a distinguishing feature.

This specification [encourages browsers to ensure adequate contrast for
specific system color foreground/background
pairs](#css-system-colors). A harder
requirement with specific AA or AAA contrast ratios was considered, but
since browsers are often just passing along color choices made by the
OS, or selected by users (who may have particular requirements,
including lower contrast for people living with migraines or epileptic
seizures), the CSSWG was unable to require a specific contrast level.
