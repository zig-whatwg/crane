## 1. Introduction

*This section is not normative.*

This module adds a\\two new
[\<color\>](https://drafts.csswg.org/css-color-5/#typedef-color) functions:
[contrast-color()](#funcdef-contrast-color) and
[color-layers()](#funcdef-color-layers).

## 2. Computing a Contrasting Color: the [contrast-color() function]
The [contrast-color()] [functional
notation](https://drafts.csswg.org/css-values-4/#functional-notation) identifies a sufficiently contrasting color against a
specified background or foreground color without requiring manual
computation.

Its syntax is:

``` prod
<contrast-color()> = contrast-color(
 [ [ <color> && [ tbd-fg | tbd-bg ] && <target-contrast>? ] |
 [ <color> && [ tbd-fg | tbd-bg ] && <target-contrast>, <color># ] ] )
<target-contrast> = <wcag2>
```

Tests

- [contrast-color-001.html](https://wpt.fyi/results/css/css-color/contrast-color-001.html "css/css-color/contrast-color-001.html")
 [[(live
 test)]](http://wpt.live/css/css-color/contrast-color-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/contrast-color-001.html)
- [color-computed-contrast-color-function.html](https://wpt.fyi/results/css/css-color/parsing/color-computed-contrast-color-function.html "css/css-color/parsing/color-computed-contrast-color-function.html")
 [[(live
 test)]](http://wpt.live/css/css-color/parsing/color-computed-contrast-color-function.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/parsing/color-computed-contrast-color-function.html)
- [color-invalid-contrast-color-function.html](https://wpt.fyi/results/css/css-color/parsing/color-invalid-contrast-color-function.html "css/css-color/parsing/color-invalid-contrast-color-function.html")
 [[(live
 test)]](http://wpt.live/css/css-color/parsing/color-invalid-contrast-color-function.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/parsing/color-invalid-contrast-color-function.html)
- [color-valid-contrast-color-function.html](https://wpt.fyi/results/css/css-color/parsing/color-valid-contrast-color-function.html "css/css-color/parsing/color-valid-contrast-color-function.html")
 [[(live
 test)]](http://wpt.live/css/css-color/parsing/color-valid-contrast-color-function.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/parsing/color-valid-contrast-color-function.html)

The only mandatory argument is the [base color] against which the contrast is
computed. This is typically (but not necessarily) a background color.

The optional list of
[\<color\>](https://drafts.csswg.org/css-color-5/#typedef-color) values represents the [color
candidates].
If no candidates are provided, the default candidates are used: [white,
black].

The [tbd-fg] and [tbd-bg] keywords indicate the role of the
[base color](#contrast-base-color) in calculating the contrast: as text against a list of
[candidate](#contrast-color-candidates) background colors ([text]) or as a background against a list of
[candidate] text colors. (The
effective contrast of a pair of colors depends on their usage.)

The keywords to specify whether the
[base color](#contrast-base-color) is a foreground or background are [TBD]. [\[Issue
#7359\]](https://github.com/w3c/csswg-drafts/issues/7359)

The
[[\<target-contrast\>](#typedef-target-contrast)] argument specifies the contrast
algorithm(s) to use. If no [color
candidates](#contrast-color-candidates) have been provided,
[\<target-contrast\>](#typedef-target-contrast) may be omitted, in which case a
UA-chosen algorithm is used.

Arguments to a
[\<target-contrast\>](#typedef-target-contrast) [functional
notation](https://drafts.csswg.org/css-values-4/#functional-notation) indicate the [target contrast
level]. Multiple contrast algorithms with [target contrast
levels](#target-contrast-level) may be specified, in which case all their requirements
are simultaneously applied. A
[contrast-color()](#funcdef-contrast-color) function specifying multiple algorithms must
specify a [target contrast level] for
each algorithm, and is otherwise
[invalid](https://drafts.csswg.org/css-syntax-3/#css-invalid).

If the [target contrast
level](#target-contrast-level) is omitted, the color candidate with the greatest
contrast is returned. Otherwise, the returned color is the first color
candidate that meets or exceeds that level, defaulting to
[white](https://drafts.csswg.org/css-color-4/#valdef-color-white) or
[black](https://drafts.csswg.org/css-color-4/#valdef-color-black) if none qualify.

### 2.1. Finding the Winning Color

#### 2.1.1. If there is a target contrast

Candidate colors are tested sequentially, starting with the first color
in the list, and ending with an automatically appended [white,
black]. The first color to pass the specified level(s) of contrast
against the [base
color](#contrast-base-color) wins.

If no candidate color passes, then whichever of
[white](https://drafts.csswg.org/css-color-4/#valdef-color-white) or
[black](https://drafts.csswg.org/css-color-4/#valdef-color-black) has the highest contrast according to the first
specified algorithm wins. If they both have the same contrast,
[white] wins.

```
contrast-color(wheat tbd-bg wcag2(aa), bisque, darkgoldenrod, olive, sienna, darkgreen, maroon)
```

The calculation is as follows:

- wheat (#f5deb3), the background,
 has relative luminance 0.749

- bisque (#ffe4c4) has relative
 luminance 0.807 and contrast ratio **1.073**

- darkgoldenrod (#b8860b) has
 relative luminance 0.273 and contrast ratio **2.477**

- olive (#808000) has relative
 luminance 0.200 and contrast ratio **3.193**

- sienna (#a0522d) has relative
 luminance 0.137 and contrast ratio **4.274**

- darkgreen (#006400 ) has
 relative luminance 0.091 and contrast ratio **5.662**

- maroon (#800000) has relative
 luminance 0.046 and contrast ratio **8.333**

The first color in the list which meets the desired contrast ratio of
4.5 is darkgreen.

```
contrast-color(wheat tbd-bg wcag2(5.8), bisque, darkgoldenrod, olive, sienna, darkgreen, maroon)
```

The calculation is as follows:

- the relative luminances and contrast ratios are the same as the
 previous example.

The first color in the list which meets the desired contrast ratio of
5.8 is maroon.

```
contrast-color(wheat tbd-bg wcag2(AA), bisque, darkgoldenrod, olive)
```

The calculation is as follows:

- the relative luminances and contrast ratios are the same as the
 previous example.

No color in the list meets the desired contrast ratio of 4.5. The
contrast of
[white](https://drafts.csswg.org/css-color-4/#valdef-color-white) against the [base
color](#contrast-base-color) of
[wheat](https://drafts.csswg.org/css-color-4/#valdef-color-wheat) is 1.314, which is smaller than 4.5 (AA), and
thus does not pass the target contrast. Therefore,
[black](https://drafts.csswg.org/css-color-4/#valdef-color-black) is returned, which has a contrast of 15.982 \>
4.5.

#### 2.1.2. If no target contrast is specified

Candidate colors are tested sequentially, starting with the first color
in the list. A color is the `temporary winner` if it has the
highest contrast against the [base
color](#contrast-base-color) of all those tested so far.

Once the end of the list is reached, the current
`temporary winner` is the overall winner. Thus, if two colors
in the list happen to have the same contrast, the earlier one wins.

```
--myAccent: #b22222;
color: contrast-color(wheat tbd-bg wcag2, tan, sienna, var(--myAccent), #d2691e)
```

The calculation is as follows:

- wheat (#f5deb3), the background,
 has relative luminance 0.749

- tan (#d2b48c) has relative luminance
 0.482 and contrast ratio **1.501**

- sienna (#a0522d) has relative
 luminance 0.137 and contrast ratio **4.273**

- \--myAccent (#b22222) has
 relative luminance 0.107 and contrast ratio **5.081**

- #d2691e has relative luminance
 0.305 and contrast ratio **2.249**

The highest contrast ratio is **5.081** so [var(\--myAccent)] wins

```
foo {
 --bg: hsl(200 50% 80%);
 --purple-in-hsl: hsl(300 100% 25%);
 color: contrast-color(var(--bg) tbd-fg wcag2, hsl(200 83% 23%), purple, var(--purple-in-hsl));
}
```

The calculation is as follows:

- \--bg is rgb(179
 213 230) which has relative luminance 0.628835

- hsl(200 83% 23%) is
 rgb(10 75 107) which has relative luminance 0.061575 and contrast
 ratio **6.08409**

- purple is rgb(128 0 128) which has
 relative luminance 0.061487 and contrast ratio **6.08889**

- \--purple-in-hsl is
 also rgb(128 0 128) which has relative luminance 0.061487 and contrast
 ratio **6.08889**. This is not greater than the contrast for purple,
 so purple wins.

The calculated values here are shown to six significant figures, to
demonstrate that early rounding to a lower precision would have given
the wrong result (0.061575 is very close to 0.061487; 6.08409 is very
close to 6.08889).

### 2.2. Contrast algorithms

Currently only [WCAG
2.1](#luminance-contrast) is supported, however this algorithm is known
to have problems, particularly on dark backgrounds. Future revisions of
this module will likely introduce additional contrast algorithms.

#### 2.2.1. WCAG 2.1: the [wcag2 keyword and [wcag2()](#funcdef-contrast-color-wcag2) function ]
The [wcag2] keyword and
[wcag2()] [functional
notations](https://drafts.csswg.org/css-values-4/#functional-notation) indicate use of the
[\[WCAG21\]](#biblio-wcag21 "Web Content Accessibility Guidelines (WCAG) 2.1")
[luminance contrast](https://www.w3.org/TR/WCAG21/#contrast-minimum)
algorithm. Their syntax is:

``` prod
<wcag2> = wcag2 | wcag2([<number> | [ aa | aaa ] && large? ])
```

Its [target contrast
level](#target-contrast-level) keywords map as follows:

- [aa] computes to [4.5]

- [aa large] (or [large aa]) computes to [3]

- [aaa] computes to [7]

- [aaa large] (or [large aaa]) computes to [4.5]

To find the contrast of a pair of colors, first their CIE Luminance (Y)
is calculated relative to a
[D65](https://drafts.csswg.org/css-color-4/#d65) whitepoint. Then the WCAG 2.1 contrast is calculated:
contrast = (Y~l~ + 0.05) / (Y~d~ + 0.05) where Y~d~ is the luminance of
the darker color in the pair and Y~l~ is the luminance of the lighter
color. The factor 0.05 represents the luminance contribution of the
viewing flare.

Suppose that the [base
color](#contrast-base-color) were

```
color(display-p3 0.38 0.11 0.05)
```

while the first [color
candidate](#contrast-color-candidates) in the list is

```
yellow
```

The calculation is as follows:

-
 color(display-p3 0.38 0.11 0.05) is color(xyz 0.06191 0.03568
 0.00463) so the relative luminance is **0.03568**

- yellow is rgb(100% 100% 0%) which is color(xyz 0.76998 0.92781 0.13853) so the
 relative luminance is **0.92781**

- the contrast is (0.92781 + 0.05) / (0.03568 + 0.05) = **11.4123**

#### 2.2.2. Contrasting Semi-transparent Colors

This section applies only to contrast algorithms that require their
inputs to be opaque colors.

When calculating the contrast of a pair of colors:

1. The background color is first blended over an opaque canvas color
 using simple alpha compositing (see [Compositing 1 § 5.1 Simple
 alpha
 compositing](https://drafts.csswg.org/compositing-1/#simplealphacompositing))
 to find an opaque background color.

 :::
 (#issue-c8b8a00f)
 [#7358](https://github.com/w3c/csswg-drafts/issues/7358) Find a good
 opaque canvas color for this computation. Candidates are:
 - the foreground color with alpha = 1

 - the
 [canvas](https://drafts.csswg.org/css-color-4/#valdef-color-canvas) system color

 - some other color calculated to minimize the contrast for the
 algorithm used
 :::

2. The foreground color is then blended over this opaque background
 color to find an opaque foreground color.

## 3. Layering Multiple Colors: the [color-layers() function]
The [color-layers()] [functional
notation](https://drafts.csswg.org/css-values-4/#functional-notation) takes an optional
[\<blend-mode\>](https://drafts.csswg.org/compositing-2/#ltblendmodegt) followed by a list of two or more
[\<color\>](https://drafts.csswg.org/css-color-5/#typedef-color) layers.

Its syntax is:

``` prod
<color-layers()> = color-layers([ <blend-mode>, ]? <color># )
```

Tests

- [color-layers-no-blend-mode.html](https://wpt.fyi/results/css/css-color/color-layers-no-blend-mode.html "css/css-color/color-layers-no-blend-mode.html")
 [[(live
 test)]](http://wpt.live/css/css-color/color-layers-no-blend-mode.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/color-layers-no-blend-mode.html)
- [color-invalid-color-layers-function.html](https://wpt.fyi/results/css/css-color/parsing/color-invalid-color-layers-function.html "css/css-color/parsing/color-invalid-color-layers-function.html")
 [[(live
 test)]](http://wpt.live/css/css-color/parsing/color-invalid-color-layers-function.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/parsing/color-invalid-color-layers-function.html)
- [color-valid-color-layers-function.html](https://wpt.fyi/results/css/css-color/parsing/color-valid-color-layers-function.html "css/css-color/parsing/color-valid-color-layers-function.html")
 [[(live
 test)]](http://wpt.live/css/css-color/parsing/color-valid-color-layers-function.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-color/parsing/color-valid-color-layers-function.html)

It returns a
[\<color\>](https://drafts.csswg.org/css-color-5/#typedef-color) which is the result of compositing
these layers, using the [Compositing 1 § 9.1.4 Source
Over](https://drafts.csswg.org/compositing-1/#porterduffcompositingoperators_srcover)
compositing operator and the specified
[\<blend-mode\>](https://drafts.csswg.org/compositing-2/#ltblendmodegt).

If no
[\<blend-mode\>](https://drafts.csswg.org/compositing-2/#ltblendmodegt) is given,
[normal](https://drafts.csswg.org/compositing-1/#valdef-blend-mode-normal) blend-mode is used.

@@Add simple example with normal blend
mode and two colors, the first of which has non-unity alpha

@@Add simple example with normal blend
mode and three colors, the first two of which have non-unity alpha

@@Add simple example with normal blend
mode and two colors, both of which have non-unity alpha

@@Add example with overlay blend mode
and two colors, the first of which has non-unity alpha

## [4. ][ Resolving [\<color\>](https://drafts.csswg.org/css-color-5/#typedef-color) Values]
### 4.1. Resolving [contrast-color() values]
If all
[\<color\>](https://drafts.csswg.org/css-color-5/#typedef-color) parameters resolve to the
corresponding colors in their respective color spaces, the computed
value is the winning color resolved according to [CSS Color 4 §  15.
Resolving \<color\>
Values](https://drafts.csswg.org/css-color-4/#resolving-color-values).
Otherwise (if
[currentColor](https://drafts.csswg.org/css-color-4/#valdef-color-currentcolor) was used in the function), the computed value is
the
[contrast-color()](#funcdef-contrast-color) function with each component
[computed](https://drafts.csswg.org/css-cascade-5/#computed-value), thus preserving inheritance into child elements.

For example, given the value

```
contrast-color(rgb(179 213 230) tbd-bg wcag2(AA), cadetblue, hsl(200 83% 23%))
```

the contrast with cadetblue is **1.97** while the contrast with hsl(200
83% 23%) is **6.09** which exceeds 4.5, the value for [AA]; so it
has the computed value of the resolved hsl function:

```
rgb(10 75 107)
```

For example, given a current color value of rgb(179 213 230), the value

```
contrast-color(currentColor tbd-bg wcag2(AA), hsl(200 83% 23%), purple)
```

has the computed value

```
contrast-color(currentColor tbd-bg wcag2(4.5), rgb(10 75 107), rgb(128 0 128))
```

### 4.2. Resolving [color-layers() values]
If all
[\<color\>](https://drafts.csswg.org/css-color-5/#typedef-color) parameters resolve to the
corresponding colors in their respective color spaces, the computed
value is the composited color resolved according to [CSS Color 4 §  15.
Resolving \<color\>
Values](https://drafts.csswg.org/css-color-4/#resolving-color-values).
Otherwise (if
[currentColor](https://drafts.csswg.org/css-color-4/#valdef-color-currentcolor) was used in the function), the computed value is
the
[color-layers()](#funcdef-color-layers) function with an explicit
[\<blend-mode\>](https://drafts.csswg.org/compositing-2/#ltblendmodegt) and with each component
[computed](https://drafts.csswg.org/css-cascade-5/#computed-value), thus preserving inheritance into child elements.

## 5. Serialization

This section extends [CSS Color 4 §  16. Serializing \<color\>
Values](https://drafts.csswg.org/css-color-4/#serializing-color-values)
to add serialization of the results of the
[contrast-color()](#funcdef-contrast-color) function.

### 5.1. Serializing contrast-color()

The [declared
value](https://drafts.csswg.org/css-cascade-5/#declared-value) of the
[contrast-color()](#funcdef-contrast-color) function is serialized with each keyword value
as specified and each component in canonical order.

The [resolved
value](https://drafts.csswg.org/cssom-1/#resolved-value) of the
[contrast-color()](#funcdef-contrast-color) function is the [used
color](https://drafts.csswg.org/css-color-4/#used-color) serialized the same as any other
[\<color\>](https://drafts.csswg.org/css-color-5/#typedef-color).

### 5.2. Serializing color-layers()

@@TODO

## 6. Security Considerations

No new security considerations have been reported on this specification.

## 7. Privacy Considerations

No new privacy considerations have been reported on this specification.

## 8. Accessibility Considerations

This specification introduces a new feature to help stylesheet authors
write stylesheets which conform to WCAG 2.1 [section 1.4.3 Contrast
(Minimum)](https://www.w3.org/TR/WCAG21/#contrast-minimum).

## 9. Changes

### 9.1. Changes from Colors 5

The new
[contrast-color()](#funcdef-contrast-color) function allows one of a list of colors to be
chosen, based on the WCAG 2.1 contrast with a specified color. The new
[color-layers()](#funcdef-color-layers) function returns the result of compositing two
or more colors, using a given blend mode.
