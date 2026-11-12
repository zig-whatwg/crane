## 1. Introduction

The properties of this module deal with the decoration of the [border
area](https://www.w3.org/TR/css-box-4/#border-area). It also defines decorations that can be applied to the
box.

### 1.1. Module Interactions

This specification extends the parts related to borders and box
decorations of CSS Backgrounds and Borders Module Level 3
[\[CSS3BG\]](#biblio-css3bg "CSS Backgrounds and Borders Module Level 3").

It provides specifications for the added [corner-\*-shape] and
[border-shape](#propdef-border-shape) properties, as well as logical
shorthands for [border-\*-radius], [box-shadow-\*]
longhands, and partial borders via the
[border-limit](#propdef-border-limit) and [border-\*-clip] properties.

All properties in this module apply to the
[::first-letter](https://www.w3.org/TR/css-pseudo-4/#selectordef-first-letter)
[pseudo-element](https://www.w3.org/TR/selectors-4/#pseudo-element). The [border-radius properties](#corners) also apply to
the
[::first-line](https://www.w3.org/TR/css-pseudo-4/#selectordef-first-line) [pseudo-element]. The
UA may (but is not required to) apply the
[border-image](#propdef-border-image) or
[box-shadow](#propdef-box-shadow) properties to
[::first-line]. The UA must not
apply the [border-color/style/width properties](#borders) to
[::first-line].
[\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")

### 1.2. Value Definitions

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
value types. For example, combining with [CSS
Images](https://www.w3.org/TR/css-images/) allows for using CSS
gradients as
[background-image](https://www.w3.org/TR/css-backgrounds-3/#propdef-background-image) or
[border-image](#propdef-border-image) values.
[\[CSS-IMAGES-3\]](#biblio-css-images-3 "CSS Images Module Level 3")

In addition to the property-specific values listed in their definitions,
all properties defined in this specification also accept the [CSS-wide
keywords](https://www.w3.org/TR/css-values-4/#css-wide-keywords) as their property value. For readability they have not
been repeated explicitly.

## 2. Borders

The [border](https://www.w3.org/TR/css-box-4/#border) can either be a predefined style (solid line, double
line, dotted line, pseudo-3D border, etc.) or it can be an image. In the
former case, various properties define the style
([border-style](#propdef-border-style)), color
([border-color](#propdef-border-color)), and thickness
([border-width](#propdef-border-width)) of the border.

Tests

Tests for features Not yet incorporated from Backgrounds 3

- [border-image-gradient-zero-size-transform-crash.html](https://wpt.fyi/results/css/css-borders/border-image-gradient-zero-size-transform-crash.html "css/css-borders/border-image-gradient-zero-size-transform-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-borders/border-image-gradient-zero-size-transform-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-borders/border-image-gradient-zero-size-transform-crash.html)
- [border-image-width-interpolation-math-functions.html](https://wpt.fyi/results/css/css-borders/border-image-width-interpolation-math-functions.html "css/css-borders/border-image-width-interpolation-math-functions.html")
 [[(live
 test)]](http://wpt.live/css/css-borders/border-image-width-interpolation-math-functions.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-borders/border-image-width-interpolation-math-functions.html)

------------------------------------------------------------------------

### 2.1. Line Colors: the [border-color properties]
Name:

[border-top-color],
[border-right-color],
[border-bottom-color],
[border-left-color],
[border-block-start-color],
[border-block-end-color],
[border-inline-start-color],
[border-inline-end-color]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<color\>](https://www.w3.org/TR/css-color-5/#typedef-color)
[\|](https://www.w3.org/TR/css-values-4/#comb-one)
[\<image-1D\>](https://www.w3.org/TR/css-images-4/#typedef-image-1d)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

currentcolor

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

all elements except [ruby base
containers](https://www.w3.org/TR/css-ruby-1/#ruby-base-container-box) and [ruby annotation
containers](https://www.w3.org/TR/css-ruby-1/#ruby-annotation-container-box)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

N/A

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

the computed color and/or a one-dimensional image function

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

see prose

[Logical property
group:](https://drafts.csswg.org/css-logical-1/#logical-property-group)

[border-color](#propdef-border-color)

These properties set the foreground [color] of the
[border](https://www.w3.org/TR/css-box-4/#border) specified by the
[border-style](#propdef-border-style) properties.

The stripes defined by
[\<image-1D\>](https://www.w3.org/TR/css-images-4/#typedef-image-1d) follow the shape of the border on the
side to which they apply, and are drawn in bands starting from the
[padding
edge](https://www.w3.org/TR/css-box-4/#padding-edge) and progressing outwards. The border width at each
point defines the `total width` of the stripes at that point.

Using multiple colors for each side:

```
.foo {
 border: 30px solid;
 border-color: stripes(dodgerblue, skyblue) stripes(yellow, gold) stripes(lightgreen, limegreen) stripes(indianred, orange);
}
```

Sample rendering:

![A box with a border that has four sides, each side having two colors
in stripes. The top border is dodger blue and sky blue, the right border
is yellow and gold, the bottom border is light green and lime green, and
the left border is indian red and
orange.](images/multicolor-border.png){height="270" width="450"}

The same border colors with [border-style:
dotted](#propdef-border-style):

![A box with a border that has four sides, each side having two colors
in stripes. The top border is dodger blue and sky blue, the right border
is yellow and gold, the bottom border is light green and lime green, and
the left border is indian red and orange. The border style is dotted, so
the colors appear in dots along the
border.](images/multicolor-border-dotted.png){height="270" width="450"}

Name:

[border-color]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

\[
[\<color\>](https://www.w3.org/TR/css-color-5/#typedef-color)
[\|](https://www.w3.org/TR/css-values-4/#comb-one)
[\<image-1D\>](https://www.w3.org/TR/css-images-4/#typedef-image-1d)
\][{1,4}](https://www.w3.org/TR/css-values-4/#mult-num-range)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

see individual properties

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

see individual properties

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

see individual properties

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

see individual properties

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

see individual properties

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

see individual properties

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[border-color](#propdef-border-color) is a [shorthand
property](https://www.w3.org/TR/css-cascade-5/#shorthand-property) for the four physical [border-\*-color]
properties. The four values set the top, right, bottom and left border,
respectively. A missing left is the same as right, a missing bottom is
the same as top, and a missing right is also the same as top. This is
resolved individually for each list item.

The
[flow-relative](https://www.w3.org/TR/css-writing-modes-4/#flow-relative) properties
[border-block-start-color](#propdef-border-block-start-color),
[border-block-end-color](#propdef-border-block-end-color),
[border-inline-start-color](#propdef-border-inline-start-color), and
[border-inline-end-color](#propdef-border-inline-end-color) correspond to the
[physical](https://www.w3.org/TR/css-writing-modes-4/#physical) properties
[border-top-color](#propdef-border-top-color),
[border-bottom-color](#propdef-border-bottom-color),
[border-left-color](#propdef-border-left-color), and
[border-right-color](#propdef-border-right-color). The mapping depends on the
element's
[writing-mode](https://www.w3.org/TR/css-writing-modes-4/#propdef-writing-mode),
[direction](https://www.w3.org/TR/css-writing-modes-3/#propdef-direction), and
[text-orientation](https://www.w3.org/TR/css-writing-modes-4/#propdef-text-orientation).

Name:

[border-block-color],
[border-inline-color]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<\'border-top-color\'\>](#propdef-border-top-color)[{1,2}](https://www.w3.org/TR/css-values-4/#mult-num-range)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

see individual properties

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

see individual properties

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

see individual properties

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

see individual properties

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

see individual properties

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

see individual properties

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

These two [shorthand
properties](https://www.w3.org/TR/css-cascade-5/#shorthand-property) set the
[border-block-start-color](#propdef-border-block-start-color) &
[border-block-end-color](#propdef-border-block-end-color) and
[border-inline-start-color](#propdef-border-inline-start-color) &
[border-inline-end-color](#propdef-border-inline-end-color), respectively. The first value
represents the
[start](https://www.w3.org/TR/css-writing-modes-4/#start) side color, and the second value represents the
[end](https://www.w3.org/TR/css-writing-modes-4/#end) side color. If only one value is given, it applies to
both the [start] and [end] sides.

Tests

- [border-color-interpolation.html](https://wpt.fyi/results/css/css-backgrounds/animations/border-color-interpolation.html "css/css-backgrounds/animations/border-color-interpolation.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/animations/border-color-interpolation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/animations/border-color-interpolation.html)
- [border-image-displayed-with-transparent-border-color.html](https://wpt.fyi/results/css/css-backgrounds/border-image-displayed-with-transparent-border-color.html "css/css-backgrounds/border-image-displayed-with-transparent-border-color.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-image-displayed-with-transparent-border-color.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-image-displayed-with-transparent-border-color.html)
- [color-mix-currentcolor-border-repaint-parent.html](https://wpt.fyi/results/css/css-backgrounds/color-mix-currentcolor-border-repaint-parent.html "css/css-backgrounds/color-mix-currentcolor-border-repaint-parent.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/color-mix-currentcolor-border-repaint-parent.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/color-mix-currentcolor-border-repaint-parent.html)
- [color-mix-currentcolor-border-repaint.html](https://wpt.fyi/results/css/css-backgrounds/color-mix-currentcolor-border-repaint.html "css/css-backgrounds/color-mix-currentcolor-border-repaint.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/color-mix-currentcolor-border-repaint.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/color-mix-currentcolor-border-repaint.html)
- [currentcolor-border-repaint-parent.html](https://wpt.fyi/results/css/css-backgrounds/currentcolor-border-repaint-parent.html "css/css-backgrounds/currentcolor-border-repaint-parent.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/currentcolor-border-repaint-parent.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/currentcolor-border-repaint-parent.html)
- [inheritance.sub.html](https://wpt.fyi/results/css/css-backgrounds/inheritance.sub.html "css/css-backgrounds/inheritance.sub.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/inheritance.sub.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/inheritance.sub.html)
- [border-color-computed.html](https://wpt.fyi/results/css/css-backgrounds/parsing/border-color-computed.html "css/css-backgrounds/parsing/border-color-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/parsing/border-color-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/parsing/border-color-computed.html)
- [border-color-invalid.html](https://wpt.fyi/results/css/css-backgrounds/parsing/border-color-invalid.html "css/css-backgrounds/parsing/border-color-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/parsing/border-color-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/parsing/border-color-invalid.html)
- [border-color-shorthand.html](https://wpt.fyi/results/css/css-backgrounds/parsing/border-color-shorthand.html "css/css-backgrounds/parsing/border-color-shorthand.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/parsing/border-color-shorthand.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/parsing/border-color-shorthand.html)
- [border-color-valid.html](https://wpt.fyi/results/css/css-backgrounds/parsing/border-color-valid.html "css/css-backgrounds/parsing/border-color-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/parsing/border-color-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/parsing/border-color-valid.html)

### 2.2. Line Patterns: the [border-style properties]
Name:

[border-top-style],
[border-right-style],
[border-bottom-style],
[border-left-style],
[border-block-start-style],
[border-block-end-style],
[border-inline-start-style],
[border-inline-end-style]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<line-style\>](#typedef-line-style)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

none

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

all elements except [ruby base
containers](https://www.w3.org/TR/css-ruby-1/#ruby-base-container-box) and [ruby annotation
containers](https://www.w3.org/TR/css-ruby-1/#ruby-annotation-container-box)

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

[Logical property
group:](https://drafts.csswg.org/css-logical-1/#logical-property-group)

[border-style](#propdef-border-style)

These properties control whether a
[border](https://www.w3.org/TR/css-box-4/#border) appears, and if it does what [style] it's
drawn in (if it is not overridden by a [border image](#border-images)).

The
[flow-relative](https://www.w3.org/TR/css-writing-modes-4/#flow-relative) properties
[border-block-start-style](#propdef-border-block-start-style),
[border-block-end-style](#propdef-border-block-end-style),
[border-inline-start-style](#propdef-border-inline-start-style), and
[border-inline-end-style](#propdef-border-inline-end-style) correspond to the
[physical](https://www.w3.org/TR/css-writing-modes-4/#physical) properties
[border-top-style](#propdef-border-top-style),
[border-bottom-style](#propdef-border-bottom-style),
[border-left-style](#propdef-border-left-style), and
[border-right-style](#propdef-border-right-style). The mapping depends on the
element's
[writing-mode](https://www.w3.org/TR/css-writing-modes-4/#propdef-writing-mode),
[direction](https://www.w3.org/TR/css-writing-modes-3/#propdef-direction), and
[text-orientation](https://www.w3.org/TR/css-writing-modes-4/#propdef-text-orientation).

Name:

[border-block-style],
[border-inline-style]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<\'border-top-style\'\>](#propdef-border-top-style)[{1,2}](https://www.w3.org/TR/css-values-4/#mult-num-range)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

see individual properties

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

see individual properties

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

see individual properties

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

see individual properties

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

see individual properties

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

see individual properties

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

These two [shorthand
properties](https://www.w3.org/TR/css-cascade-5/#shorthand-property) set the
[border-block-start-style](#propdef-border-block-start-style) &
[border-block-end-style](#propdef-border-block-end-style) and
[border-inline-start-style](#propdef-border-inline-start-style) &
[border-inline-end-style](#propdef-border-inline-end-style), respectively. The first value
represents the
[start](https://www.w3.org/TR/css-writing-modes-4/#start) side style, and the second value represents the
[end](https://www.w3.org/TR/css-writing-modes-4/#end) side style. If only one value is given, it applies to
both the [start] and [end] sides.

Name:

[border-style]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<\'border-top-style\'\>](#propdef-border-top-style)[{1,4}](https://www.w3.org/TR/css-values-4/#mult-num-range)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

see individual properties

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

see individual properties

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

see individual properties

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

see individual properties

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

see individual properties

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

see individual properties

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[border-style](#propdef-border-style) is a [shorthand
property](https://www.w3.org/TR/css-cascade-5/#shorthand-property) for the four physical [border-\*-style]
properties. The four values set the top, right, bottom and left border,
respectively. A missing left is the same as right, a missing bottom is
the same as top, and a missing right is also the same as top. This is
resolved individually for each list item.

The style is specified as a
[\<line-style\>](#typedef-line-style) keyword, where

``` prod
<line-style> = none | hidden | dotted | dashed | solid | double | groove | ridge | inset | outset
```

Values have the following meanings:

[none]
: No border. Color and width are ignored (i.e., the border has width
 0). Note this means that the initial value of
 [border-image-width](#propdef-border-image-width) will also resolve to zero.

[hidden]
: Same as
 [none](#valdef-line-style-none), but has different behavior in the border
 conflict resolution rules for border-collapsed tables
 [\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification").

[dotted]
: A series of round dots.

[dashed]
: A series of square-ended dashes.

[solid]
: A single line segment.

[double]
: Two parallel solid lines with some space between them. (The
 thickness of the lines is not specified, but the sum of the lines
 and the space must equal
 [border-width](#propdef-border-width).)

[groove]
: Looks as if it were carved in the canvas. (This is typically
 achieved by creating a "shadow" from two colors that are slightly
 lighter and darker than the specified
 [border-color](#propdef-border-color).)

[ridge]
: Looks as if it were coming out of the canvas.

[inset]
: Looks as if the content on the inside of the border is sunken into
 the canvas. Treated as
 [ridge](#valdef-line-style-ridge) in the [collapsing border
 model](https://www.w3.org/TR/CSS2/tables.html#collapsing-borders).
 [\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")

[outset]
: Looks as if the content on the inside of the border is raised out of
 the canvas. Treated as
 [groove](#valdef-line-style-groove) in the [collapsing border
 model](https://www.w3.org/TR/CSS2/tables.html#collapsing-borders).
 [\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")

Borders are drawn in front of the element's background, but behind the
element's content (in case it overlaps).

![Example renderings of the predefined border
styles.](images/borderstyles.png){height="383" width="669"}

 Border colors close to black or white may need
different color calculations than colors in between in order to create
the required "3D" effect of
[groove](#valdef-line-style-groove),
[ridge](#valdef-line-style-ridge),
[inset](#valdef-line-style-inset), or
[outset](#valdef-line-style-outset).

 There is no control over the spacing of the dots and
dashes, nor over the length of the dashes. Implementations are
encouraged to choose a spacing that makes the corners symmetrical.

Tests

- [inheritance.sub.html](https://wpt.fyi/results/css/css-backgrounds/inheritance.sub.html "css/css-backgrounds/inheritance.sub.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/inheritance.sub.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/inheritance.sub.html)
- [border-style-computed.html](https://wpt.fyi/results/css/css-backgrounds/parsing/border-style-computed.html "css/css-backgrounds/parsing/border-style-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/parsing/border-style-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/parsing/border-style-computed.html)
- [border-style-invalid.html](https://wpt.fyi/results/css/css-backgrounds/parsing/border-style-invalid.html "css/css-backgrounds/parsing/border-style-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/parsing/border-style-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/parsing/border-style-invalid.html)
- [border-style-shorthand.html](https://wpt.fyi/results/css/css-backgrounds/parsing/border-style-shorthand.html "css/css-backgrounds/parsing/border-style-shorthand.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/parsing/border-style-shorthand.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/parsing/border-style-shorthand.html)
- [border-style-valid.html](https://wpt.fyi/results/css/css-backgrounds/parsing/border-style-valid.html "css/css-backgrounds/parsing/border-style-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/parsing/border-style-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/parsing/border-style-valid.html)

### 2.3. Line Thickness: the [border-width properties]
Name:

[border-top-width],
[border-right-width],
[border-bottom-width],
[border-left-width],
[border-block-start-width],
[border-block-end-width],
[border-inline-start-width],
[border-inline-end-width]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<line-width\>](#typedef-line-width)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

medium

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

all elements except [ruby base
containers](https://www.w3.org/TR/css-ruby-1/#ruby-base-container-box) and [ruby annotation
containers](https://www.w3.org/TR/css-ruby-1/#ruby-annotation-container-box)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

N/A

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

absolute length, [snapped as a border
width](https://www.w3.org/TR/css-values-4/#snap-a-length-as-a-border-width)

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value

[Logical property
group:](https://drafts.csswg.org/css-logical-1/#logical-property-group)

[border-width](#propdef-border-width)

These properties specify the thickness of the
[border](https://www.w3.org/TR/css-box-4/#border), i.e. the [border width]. Where

``` prod
<line-width> = <length [0,∞]> | hairline | thin | medium | thick
```

Negative values are invalid. The [thin], [medium], and [thick] keywords are equivalent to [1px],
[3px], and [5px], respectively. The
[hairline] keyword is a UA-defined length, less than or
equal to [1px] and equal to an integer number of device pixels at
the default page zoom, which represents a \"just visible\" line. (While
it can be as large as [1px], on many devices it will be
approximately [0.3px] to [0.5px].)

The [resolved
value](https://www.w3.org/TR/cssom-1/#resolved-value) for the
[border-width](#propdef-border-width) properties is the [used
value](https://www.w3.org/TR/css-cascade-5/#used-value).

If the
[border-style](#propdef-border-style) corresponding to a given
[border-width](#propdef-border-width) is
[none](#valdef-line-style-none) or
[hidden](#valdef-line-style-hidden), then the
[used](https://www.w3.org/TR/css-cascade-5/#used-value) width is 0.

The
[flow-relative](https://www.w3.org/TR/css-writing-modes-4/#flow-relative) properties
[border-block-start-width](#propdef-border-block-start-width),
[border-block-end-width](#propdef-border-block-end-width),
[border-inline-start-width](#propdef-border-inline-start-width), and
[border-inline-end-width](#propdef-border-inline-end-width) correspond to the
[physical](https://www.w3.org/TR/css-writing-modes-4/#physical) properties
[border-top-width](#propdef-border-top-width),
[border-bottom-width](#propdef-border-bottom-width),
[border-left-width](#propdef-border-left-width), and
[border-right-width](#propdef-border-right-width). The mapping depends on the
element's
[writing-mode](https://www.w3.org/TR/css-writing-modes-4/#propdef-writing-mode),
[direction](https://www.w3.org/TR/css-writing-modes-3/#propdef-direction), and
[text-orientation](https://www.w3.org/TR/css-writing-modes-4/#propdef-text-orientation).

Name:

[border-block-width],
[border-inline-width]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<\'border-top-width\'\>](#propdef-border-top-width)[{1,2}](https://www.w3.org/TR/css-values-4/#mult-num-range)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

see individual properties

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

see individual properties

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

see individual properties

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

see individual properties

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

see individual properties

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

see individual properties

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

These two [shorthand
properties](https://www.w3.org/TR/css-cascade-5/#shorthand-property) set the
[border-block-start-width](#propdef-border-block-start-width) &
[border-block-end-width](#propdef-border-block-end-width) and
[border-inline-start-width](#propdef-border-inline-start-width) &
[border-inline-end-width](#propdef-border-inline-end-width), respectively. The first value
represents the
[start](https://www.w3.org/TR/css-writing-modes-4/#start) side width, and the second value represents the
[end](https://www.w3.org/TR/css-writing-modes-4/#end) side width. If only one value is given, it applies to
both the [start] and [end] sides.

Name:

[border-width]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<\'border-top-width\'\>](#propdef-border-top-width)[{1,4}](https://www.w3.org/TR/css-values-4/#mult-num-range)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

see individual properties

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

see individual properties

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

see individual properties

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

see individual properties

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

see individual properties

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

see individual properties

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[border-width](#propdef-border-width) is a [shorthand
property](https://www.w3.org/TR/css-cascade-5/#shorthand-property) for the four physical [border-\*-width]
properties. The four values set the top, right, bottom and left border,
respectively. A missing left is the same as right, a missing bottom is
the same as top, and a missing right is also the same as top. This is
resolved individually for each list item.

 Although the
[initial](https://www.w3.org/TR/css-cascade-5/#initial-value) width is
[medium](#valdef-line-width-medium), the [initial] style is
[none](#valdef-line-style-none); therefore the
[used](https://www.w3.org/TR/css-cascade-5/#used-value) initial width is 0.

Tests

- [border-bottom-width-composition.html](https://wpt.fyi/results/css/css-backgrounds/animations/border-bottom-width-composition.html "css/css-backgrounds/animations/border-bottom-width-composition.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/animations/border-bottom-width-composition.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/animations/border-bottom-width-composition.html)
- [border-image-width-composition.html](https://wpt.fyi/results/css/css-backgrounds/animations/border-image-width-composition.html "css/css-backgrounds/animations/border-image-width-composition.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/animations/border-image-width-composition.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/animations/border-image-width-composition.html)
- [border-image-width-interpolation.html](https://wpt.fyi/results/css/css-backgrounds/animations/border-image-width-interpolation.html "css/css-backgrounds/animations/border-image-width-interpolation.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/animations/border-image-width-interpolation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/animations/border-image-width-interpolation.html)
- [border-left-width-composition.html](https://wpt.fyi/results/css/css-backgrounds/animations/border-left-width-composition.html "css/css-backgrounds/animations/border-left-width-composition.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/animations/border-left-width-composition.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/animations/border-left-width-composition.html)
- [border-right-width-composition.html](https://wpt.fyi/results/css/css-backgrounds/animations/border-right-width-composition.html "css/css-backgrounds/animations/border-right-width-composition.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/animations/border-right-width-composition.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/animations/border-right-width-composition.html)
- [border-top-width-composition.html](https://wpt.fyi/results/css/css-backgrounds/animations/border-top-width-composition.html "css/css-backgrounds/animations/border-top-width-composition.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/animations/border-top-width-composition.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/animations/border-top-width-composition.html)
- [border-width-interpolation.html](https://wpt.fyi/results/css/css-backgrounds/animations/border-width-interpolation.html "css/css-backgrounds/animations/border-width-interpolation.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/animations/border-width-interpolation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/animations/border-width-interpolation.html)
- [border-bottom-width-medium.html](https://wpt.fyi/results/css/css-backgrounds/border-bottom-width-medium.html "css/css-backgrounds/border-bottom-width-medium.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-bottom-width-medium.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-bottom-width-medium.html)
- [border-bottom-width-thick.html](https://wpt.fyi/results/css/css-backgrounds/border-bottom-width-thick.html "css/css-backgrounds/border-bottom-width-thick.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-bottom-width-thick.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-bottom-width-thick.html)
- [border-bottom-width-thin.html](https://wpt.fyi/results/css/css-backgrounds/border-bottom-width-thin.html "css/css-backgrounds/border-bottom-width-thin.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-bottom-width-thin.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-bottom-width-thin.html)
- [border-left-width-medium.html](https://wpt.fyi/results/css/css-backgrounds/border-left-width-medium.html "css/css-backgrounds/border-left-width-medium.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-left-width-medium.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-left-width-medium.html)
- [border-left-width-thick.html](https://wpt.fyi/results/css/css-backgrounds/border-left-width-thick.html "css/css-backgrounds/border-left-width-thick.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-left-width-thick.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-left-width-thick.html)
- [border-left-width-thin.html](https://wpt.fyi/results/css/css-backgrounds/border-left-width-thin.html "css/css-backgrounds/border-left-width-thin.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-left-width-thin.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-left-width-thin.html)
- [border-right-width-medium.html](https://wpt.fyi/results/css/css-backgrounds/border-right-width-medium.html "css/css-backgrounds/border-right-width-medium.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-right-width-medium.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-right-width-medium.html)
- [border-right-width-thick.html](https://wpt.fyi/results/css/css-backgrounds/border-right-width-thick.html "css/css-backgrounds/border-right-width-thick.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-right-width-thick.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-right-width-thick.html)
- [border-right-width-thin.html](https://wpt.fyi/results/css/css-backgrounds/border-right-width-thin.html "css/css-backgrounds/border-right-width-thin.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-right-width-thin.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-right-width-thin.html)
- [border-top-width-medium.html](https://wpt.fyi/results/css/css-backgrounds/border-top-width-medium.html "css/css-backgrounds/border-top-width-medium.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-top-width-medium.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-top-width-medium.html)
- [border-top-width-thick.html](https://wpt.fyi/results/css/css-backgrounds/border-top-width-thick.html "css/css-backgrounds/border-top-width-thick.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-top-width-thick.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-top-width-thick.html)
- [border-top-width-thin.html](https://wpt.fyi/results/css/css-backgrounds/border-top-width-thin.html "css/css-backgrounds/border-top-width-thin.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-top-width-thin.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-top-width-thin.html)
- [border-width-cssom.html](https://wpt.fyi/results/css/css-backgrounds/border-width-cssom.html "css/css-backgrounds/border-width-cssom.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-width-cssom.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-width-cssom.html)
- [border-width-pixel-snapping-001-a.html](https://wpt.fyi/results/css/css-backgrounds/border-width-pixel-snapping-001-a.html "css/css-backgrounds/border-width-pixel-snapping-001-a.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-width-pixel-snapping-001-a.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-width-pixel-snapping-001-a.html)
- [border-width-pixel-snapping-001-b.html](https://wpt.fyi/results/css/css-backgrounds/border-width-pixel-snapping-001-b.html "css/css-backgrounds/border-width-pixel-snapping-001-b.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-width-pixel-snapping-001-b.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-width-pixel-snapping-001-b.html)
- [border-width-small-values-001-a.html](https://wpt.fyi/results/css/css-backgrounds/border-width-small-values-001-a.html "css/css-backgrounds/border-width-small-values-001-a.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-width-small-values-001-a.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-width-small-values-001-a.html)
- [border-width-small-values-001-b.html](https://wpt.fyi/results/css/css-backgrounds/border-width-small-values-001-b.html "css/css-backgrounds/border-width-small-values-001-b.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-width-small-values-001-b.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-width-small-values-001-b.html)
- [border-width-small-values-001-c.html](https://wpt.fyi/results/css/css-backgrounds/border-width-small-values-001-c.html "css/css-backgrounds/border-width-small-values-001-c.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-width-small-values-001-c.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-width-small-values-001-c.html)
- [border-width-small-values-001-d.html](https://wpt.fyi/results/css/css-backgrounds/border-width-small-values-001-d.html "css/css-backgrounds/border-width-small-values-001-d.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-width-small-values-001-d.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-width-small-values-001-d.html)
- [border-width-small-values-001-e.html](https://wpt.fyi/results/css/css-backgrounds/border-width-small-values-001-e.html "css/css-backgrounds/border-width-small-values-001-e.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-width-small-values-001-e.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-width-small-values-001-e.html)
- [inheritance.sub.html](https://wpt.fyi/results/css/css-backgrounds/inheritance.sub.html "css/css-backgrounds/inheritance.sub.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/inheritance.sub.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/inheritance.sub.html)
- [border-width-computed.html](https://wpt.fyi/results/css/css-backgrounds/parsing/border-width-computed.html "css/css-backgrounds/parsing/border-width-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/parsing/border-width-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/parsing/border-width-computed.html)
- [border-width-invalid.html](https://wpt.fyi/results/css/css-backgrounds/parsing/border-width-invalid.html "css/css-backgrounds/parsing/border-width-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/parsing/border-width-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/parsing/border-width-invalid.html)
- [border-width-shorthand.html](https://wpt.fyi/results/css/css-backgrounds/parsing/border-width-shorthand.html "css/css-backgrounds/parsing/border-width-shorthand.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/parsing/border-width-shorthand.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/parsing/border-width-shorthand.html)
- [border-width-valid.html](https://wpt.fyi/results/css/css-backgrounds/parsing/border-width-valid.html "css/css-backgrounds/parsing/border-width-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/parsing/border-width-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/parsing/border-width-valid.html)

<!-- -->

- [borders-on-sub-unit-sized-elements.html](https://wpt.fyi/results/css/css-borders/borders-on-sub-unit-sized-elements.html "css/css-borders/borders-on-sub-unit-sized-elements.html")
 [[(live
 test)]](http://wpt.live/css/css-borders/borders-on-sub-unit-sized-elements.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-borders/borders-on-sub-unit-sized-elements.html)
- [subpixel-borders-with-child-border-box-sizing.html](https://wpt.fyi/results/css/css-borders/subpixel-borders-with-child-border-box-sizing.html "css/css-borders/subpixel-borders-with-child-border-box-sizing.html")
 [[(live
 test)]](http://wpt.live/css/css-borders/subpixel-borders-with-child-border-box-sizing.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-borders/subpixel-borders-with-child-border-box-sizing.html)
- [subpixel-borders-with-child.html](https://wpt.fyi/results/css/css-borders/subpixel-borders-with-child.html "css/css-borders/subpixel-borders-with-child.html")
 [[(live
 test)]](http://wpt.live/css/css-borders/subpixel-borders-with-child.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-borders/subpixel-borders-with-child.html)

### 2.4. Border Shorthand Properties

Name:

[border-top], [border-right],
[border-bottom], [border-left],
[border-block-start],
[border-block-end],
[border-inline-start],
[border-inline-end]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<line-width\>](#typedef-line-width)
[\|\|](https://www.w3.org/TR/css-values-4/#comb-any)
[\<line-style\>](#typedef-line-style) [\|\|]
[\<color\>](https://www.w3.org/TR/css-color-5/#typedef-color)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

See individual properties

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

all elements except [ruby base
containers](https://www.w3.org/TR/css-ruby-1/#ruby-base-container-box) and [ruby annotation
containers](https://www.w3.org/TR/css-ruby-1/#ruby-annotation-container-box)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

N/A

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

see individual properties

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

see individual properties

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

These [shorthand
properties](https://www.w3.org/TR/css-cascade-5/#shorthand-property) set the
[border-width](#propdef-border-width),
[border-color](#propdef-border-color), and
[border-style](#propdef-border-style) of one side of the
[borders](https://www.w3.org/TR/css-box-4/#border) of a box. Omitted values are set to their [initial
values](https://www.w3.org/TR/css-cascade-5/#initial-value).

The
[flow-relative](https://www.w3.org/TR/css-writing-modes-4/#flow-relative) properties
[border-block-start](#propdef-border-block-start),
[border-block-end](#propdef-border-block-end),
[border-inline-start](#propdef-border-inline-start), and
[border-inline-end](#propdef-border-inline-end) correspond to the
[physical](https://www.w3.org/TR/css-writing-modes-4/#physical) properties
[border-top](#propdef-border-top),
[border-bottom](#propdef-border-bottom),
[border-left](#propdef-border-left), and
[border-right](#propdef-border-right). The mapping depends on the element's
[writing-mode](https://www.w3.org/TR/css-writing-modes-4/#propdef-writing-mode),
[direction](https://www.w3.org/TR/css-writing-modes-3/#propdef-direction), and
[text-orientation](https://www.w3.org/TR/css-writing-modes-4/#propdef-text-orientation).

Name:

[border-block], [border-inline]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<\'border-block-start\'\>](#propdef-border-block-start)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

see individual properties

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

see individual properties

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

see individual properties

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

see individual properties

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

see individual properties

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

see individual properties

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

These two [shorthand
properties](https://www.w3.org/TR/css-cascade-5/#shorthand-property) set the
[border-block-start](#propdef-border-block-start) &
[border-block-end](#propdef-border-block-end) or
[border-inline-start](#propdef-border-inline-start) &
[border-inline-end](#propdef-border-inline-end), respectively, both to the same
style.

Name:

[border]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<line-width\>](#typedef-line-width)
[\|\|](https://www.w3.org/TR/css-values-4/#comb-any)
[\<line-style\>](#typedef-line-style) [\|\|]
[\<color\>](https://www.w3.org/TR/css-color-5/#typedef-color)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

see individual properties

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

see individual properties

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

see individual properties

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

see individual properties

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

see individual properties

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

see individual properties

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

Tests

- [border-invalid.html](https://wpt.fyi/results/css/css-backgrounds/parsing/border-invalid.html "css/css-backgrounds/parsing/border-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/parsing/border-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/parsing/border-invalid.html)
- [border-shorthand.html](https://wpt.fyi/results/css/css-backgrounds/parsing/border-shorthand.html "css/css-backgrounds/parsing/border-shorthand.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/parsing/border-shorthand.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/parsing/border-shorthand.html)
- [border-valid.html](https://wpt.fyi/results/css/css-backgrounds/parsing/border-valid.html "css/css-backgrounds/parsing/border-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/parsing/border-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/parsing/border-valid.html)

The [border](#propdef-border) property is a [shorthand
property](https://www.w3.org/TR/css-cascade-5/#shorthand-property) for setting the same
[border-width](#propdef-border-width),
[border-color](#propdef-border-color), and
[border-style](#propdef-border-style) for all four borders of a box.
Unlike the shorthand
[margin](https://www.w3.org/TR/css-box-4/#propdef-margin) and
[padding](https://www.w3.org/TR/css-box-4/#propdef-padding) properties, the
[border] property cannot set
different values on the four borders. To do so, one or more of the other
border properties must be used.

The [border](#propdef-border) shorthand also resets
[border-image](#propdef-border-image) to its initial value. It is
therefore recommended that authors use the
[border] shorthand, rather than
other shorthands or the individual properties, to override any border
settings earlier in the cascade. This will ensure that
[border-image] has also been
reset to allow the new styles to take effect.

 The CSS Working Group intends for the
[border](#propdef-border) shorthand to reset all border properties in future
levels of CSS as well. For example, if a [border-characters]
property is introduced in the future to allow glyphs as borders, it will
also be reset by the [border]
shorthand. By using the [border]
shorthand to reset borders, authors can be guaranteed a "blank canvas"
no matter what properties are introduced in the future.

For example, the first rule below is
equivalent to the set of five rules shown after it:

 p { border: solid red }
 p {
 border-top: solid red;
 border-right: solid red;
 border-bottom: solid red;
 border-left: solid red;
 border-image: none;
 }

Since, to some extent, the properties have overlapping functionality,
the order in which the rules are specified is important.

Consider this example:

 blockquote {
 border-color: red;
 border-left: double;
 color: black
 }

In the above example, the color of the left border is black, while the
other borders are red. This is due to
[border-left](#propdef-border-left) setting the width, style, and color.
Since the color value is not given by the
[border-left] property, it will
be taken from the
[color](https://www.w3.org/TR/css-color-4/#propdef-color) property. The fact that the
[color] property is set after the
[border-left] property is not
relevant.

## 3. Corners

The [padding
edge](https://www.w3.org/TR/css-box-4/#padding-edge) (inner border) radius is the outer border radius minus
the corresponding border thickness. In the case where this results in a
negative value, the inner radius is zero. (In such cases the center of
the border's inner curve might not coincide with that of its outer
curve.) Likewise the [content
edge](https://www.w3.org/TR/css-box-4/#content-edge) radius is the [padding edge]
radius minus the corresponding
[padding](https://www.w3.org/TR/css-box-4/#padding), or if that is negative, zero. The border and padding
thicknesses in the curved region are thus interpolated from the
adjoining sides, and when two adjoining borders are of different
thicknesses the corner will show a smooth transition between the thicker
and thinner borders.

All border styles
([solid](#valdef-line-style-solid),
[dotted](#valdef-line-style-dotted),
[inset](#valdef-line-style-inset), etc.) follow the curve of the border.

![The effect of a rounded corner when the two borders it connects are of
unequal thickness (left) and the effect of a rounded corner on borders
that are thicker than the radius of the corner
(right).](images/smooth-radius.png){height="176" width="407"}

 If the center of a corner's outer curve is past an
opposite [padding
edge](https://www.w3.org/TR/css-box-4/#padding-edge) (in the [border
area](https://www.w3.org/TR/css-box-4/#border-area) of a side opposite the corner), the inner curve will
not be a full quarter ellipse.

<figure>
<pre><code>p { width: 70px; height: 70px; border: solid 30px;
border-color: orange orange silver silver;
border-top-right-radius: 100%; }</code></pre>
<img src="images/partial-curve.png" width="141" height="142"
a />
<figcaption>Where the border-radius curve extends into the opposite
sides' borders, the arc of the padding edge is less than
90°.</figcaption>
</figure>

The [margin
edge](https://www.w3.org/TR/css-box-4/#margin-edge), being outside the [border
edge](https://www.w3.org/TR/css-box-4/#border-edge), calculates its radius by *adding* the corresponding
margin thickness to each border radius, with the corresponding
[outset-adjusted border
radius](#outset-adjusted-border-radius) applied.

When expanding an
[edge](https://www.w3.org/TR/css-box-4/#box-box-edge) that has a [border
radius](#border-radii), e.g. for
computing the [margin
edge](https://www.w3.org/TR/css-box-4/#margin-edge),
[box-shadow](#propdef-box-shadow) spread, or
[overflow-clip-margin](https://www.w3.org/TR/css-overflow-4/#propdef-overflow-clip-margin), the different [border
radius] values are adjusted so that a small
rounded corner with a big outset does not appear to be disproportionally
round.

This is done by computing the corresponding [outset-adjusted border
radius](#outset-adjusted-border-radius).

To compute the [outset-adjusted border
radius] given the 2-dimensional
[size](https://www.w3.org/TR/css-sizing-3/#size)'s `edge`, `radius`, and
`outset`:

1. Let `coverage` be
 `2 * min(``radius``’s `[`width`](https://www.w3.org/TR/css-sizing-3/#width)` / ``edge``’s `[`width`]`, ``radius``’s `[`height`](https://www.w3.org/TR/css-sizing-3/#height)` / ``edge``’s `[`height`]`)`.

2. Let `adjustedRadiusWidth` be the [adjusted radius
 dimension](#adjusted-radius-dimension) given `coverage`, `radius`'s
 [width](https://www.w3.org/TR/css-sizing-3/#width), and `outset`'s
 [width].

3. Let `adjustedRadiusHeight` be the [adjusted radius
 dimension](#adjusted-radius-dimension) given `coverage`, `radius`'s
 [height](https://www.w3.org/TR/css-sizing-3/#height), and `outset`'s
 [height].

4. Return (`adjustedRadiusWidth`,
 `adjustedRadiusHeight`).

To compute the [adjusted radius dimension] given numbers
`coverage`, `radius`, and `outset`:

1. If `radius` is greater than `outset`, or if
 `coverage` is greater than 1, then return
 `radius`` + ``outset`.

2. Let `ratio` be
 `radius`` / ``outset`.

3. Return
 `radius`` + ``outset`` * (1 - (1 - ``ratio``)`^`3`^` * (1 - ``coverage`^`3`^`))`.

 this algorithm is designed to reduce the effect of the
`outset` (or spread) on the shape of the corner. The
`coverage` factor makes this reduction more pronounced for
rectangular shapes (where the [border
radius](#border-radii) is close
to 0), and less pronounced for elliptical shapes (where the [border
radius] is close to 50%).

### 3.1. Corner Clipping

Although [border images](#border-image) are not affected by
[border-radius](#propdef-border-radius), other effects that clip painting
or event handling to the
[border](https://www.w3.org/TR/css-box-4/#border-edge),
[padding](https://www.w3.org/TR/css-box-4/#padding-edge), or
[content](https://www.w3.org/TR/css-box-4/#content-edge) edge must clip to their respective curves. For example,
backgrounds clip to the curve specified by
[background-clip](https://www.w3.org/TR/css-backgrounds-3/#propdef-background-clip),
[overflow](https://www.w3.org/TR/css-overflow-3/#propdef-overflow) values other than
[visible](https://www.w3.org/TR/css-overflow-3/#valdef-overflow-visible) to the curved [padding
edge] (when
[overflow] on both axes is not
[visible]), [replaced
element](https://www.w3.org/TR/css-display-4/#replaced-element) content to the curved [content
edge], pointer events to the curved [border
edge], etc.

 As
[border-radius](#propdef-border-radius) reduces the interactive area of an
element authors should make sure the remaining interactive area conforms
to recommended minima for the platforms they target; in particular,
conforming to recommended minimum touch target sizes may require larger
widths and heights when [border-radius] is used.

This example adds appropriate padding,
so that the contents do not overflow the corners. Note that there is no
border, but the background will still have rounded corners.

 DIV {
 background: black;
 color: white;
 border-radius: 1em;
 padding: 1em }

### 3.2. Color and Style Transitions

Color and style transitions must be contained within the segment of the
border that intersects the smallest rectangle that contains both border
radii as well as the center of the inner curve (which may be a point
representing the corner of the padding edge, if the border radii are
smaller than the [border
width](#border-width-dfn)).

If one of these borders is zero-width, then the other border takes up
the entire transitional area. Otherwise, the center of color and style
transitions between adjoining borders is a point along the curve that is
a continuous monotonic function of the ratio of the border widths.
However it is not defined what these transitions look like or what
function maps from this ratio to a point on the curve.

![Given these corner shapes, color and style transitions must be
contained within the green region. In case D the rectangle defined by
the border radii does not include the center of the inner curve (which
is a sharp corner), so the transition region is expanded to include that
corner. Transitions may take up the entire transition region, but are
not required to: For example, a gradient color transition between two
solid border styles might take up only the region bounded by the tips of
the outer radii and the tips of the inner radii (represented in case D
by the dark green region).](images/transition-region.png){height="178"
width="600"}

Tests

- [border-radius-currentcolor.html](https://wpt.fyi/results/css/css-borders/border-radius-currentcolor.html "css/css-borders/border-radius-currentcolor.html")
 [[(live
 test)]](http://wpt.live/css/css-borders/border-radius-currentcolor.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-borders/border-radius-currentcolor.html)

### 3.3. Overlapping Curves

Corner curves must not overlap: When the sum of any two adjacent border
radii exceeds the size of the border box, UAs must proportionally reduce
the used values of all border radii until none of them overlap. The
algorithm for reducing radii is as follows:

Let `f` = min(1, `L`~`i`~ /
`S`~`i`~), where `i` ∈ {top, right,
bottom, left}, `S`~`i`~ is the sum of the two
corresponding radii of the corners on side `i`, and
`L`~`top`~ = `L`~`bottom`~ =
the width of the box, and `L`~`left`~ =
`L`~`right`~ = the height of the box. If
`f` \< 1, then all corner radii are reduced by multiplying
them by `f`. The value of `f` is the [adjacent
corner scale factor].

 This formula ensures that quarter circles remain
quarter circles and large radii remain larger than smaller ones, but it
may reduce corners that were already small enough, which may make
borders of nearby elements that should look the same look different.

If the curve interferes with UI elements such as scrollbars, the UA may
further reduce the used value of the affected border radii (and only the
affected border radii) as much as necessary, but no more.

For example, the borders A of the
[figure below](#reduced-radius) might be the result of

 box-sizing: border-box;
 width: 6em;
 height: 2.5em;
 border-radius: 0.5em 2em 0.5em 2em

The height (2.5em) is enough for the specified radii (0.5em plus 2.0em).
However, if the height is only 2em,

 box-sizing: border-box;
 width: 6em;
 height: 2em;
 border-radius: 0.5em 2em 0.5em 2em

all corners need to be reduced by a factor 0.8 to make them fit. The
used border radii thus are 0.4em (instead of 0.5em) and 1.6em (instead
of 2em). See borders B in the figure.

![These rounded corner might be the result of [width: 6em; height:
2.5em; border-radius: 0.5em 2em 0.5em
2em](https://www.w3.org/TR/css-sizing-3/#propdef-width) for A; and ditto but with [height:
2em](https://www.w3.org/TR/css-sizing-3/#propdef-height) for
B.](images/corner-large-mix.png)

### 3.4. Effect on Tables

The
[border-radius](#propdef-border-radius) properties do apply to
[table](https://www.w3.org/TR/css-display-4/#valdef-display-table),
[inline-table](https://www.w3.org/TR/css-display-4/#valdef-display-inline-table), and
[table-cell](https://www.w3.org/TR/css-display-4/#valdef-display-table-cell) boxes in separated borders mode
([border-collapse:
separate](https://www.w3.org/TR/CSS2/tables.html#propdef-border-collapse)). When
[border-collapse] is
[collapse], they have no effect.

Tests

- [ttwf-reftest-borderRadius.html](https://wpt.fyi/results/css/css-backgrounds/ttwf-reftest-borderRadius.html "css/css-backgrounds/ttwf-reftest-borderRadius.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/ttwf-reftest-borderRadius.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/ttwf-reftest-borderRadius.html)

### [3.5. ][ Corner Sizing: the [border-\*-\*-radius] properties]
Name:

[border-top-left-radius],
[border-top-right-radius],
[border-bottom-right-radius],
[border-bottom-left-radius],
[border-start-start-radius],
[border-start-end-radius],
[border-end-start-radius],
[border-end-end-radius]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<border-radius\>](#typedef-border-radius)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

0

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

all elements (but see prose)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

Refer to corresponding dimension of the [border
box](https://www.w3.org/TR/css-box-4/#border-box).

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

pair of computed
[\<length-percentage\>](https://www.w3.org/TR/css-values-4/#typedef-length-percentage) values

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value

[Logical property
group:](https://drafts.csswg.org/css-logical-1/#logical-property-group)

[border-radius](#propdef-border-radius)

The radius is specified as a
[\<border-radius\>](#typedef-border-radius) value, where

``` prod
<border-radius> = <slash-separated-border-radius-syntax> | <legacy-border-radius-syntax>
<slash-separated-border-radius-syntax> = <length-percentage [0,∞]> [ / <length-percentage [0,∞]> ]?
<legacy-border-radius-syntax> = <length-percentage [0,∞]>{1,2}
```

The two
[\<length-percentage\>](https://www.w3.org/TR/css-values-4/#typedef-length-percentage) values of the
[border-\*-radius] properties define the [radii] of a
quarter ellipse that defines the shape of the corner of the outer
[border
edge](https://www.w3.org/TR/css-box-4/#border-edge) (see the diagram below). The first value is the
horizontal radius, the second the vertical radius. If the second value
is omitted it is copied from the first. If either length is zero, the
corner is square, not rounded. Percentages for the horizontal radius
refer to the width of the [border
box](https://www.w3.org/TR/css-box-4/#border-box), whereas percentages for the vertical radius refer to
the height of the [border box]. Negative values
are invalid.

 Authors *should* use the slash syntax, which is
preferred for new content, but the legacy syntax (two values separated
by whitespace) is supported for backwards compatibility.

![The two values of [border-top-left-radius: 55pt
25pt](#propdef-border-top-left-radius) define the size of the
corner.](images/corner.png){a
height="179" width="289"}

This example draws ovals of 15em wide
and 10em high:

 DIV.standout {
 width: 13em;
 height: 8em;
 border: solid black 1em;
 border-radius: 7.5em 5em }

[flow-relative](https://www.w3.org/TR/css-writing-modes-4/#flow-relative) properties
[border-start-start-radius](#propdef-border-start-start-radius),
[border-start-end-radius](#propdef-border-start-end-radius),
[border-end-start-radius](#propdef-border-end-start-radius), and
[border-end-end-radius](#propdef-border-end-end-radius) correspond to the
[physical](https://www.w3.org/TR/css-writing-modes-4/#physical) properties
[border-top-left-radius](#propdef-border-top-left-radius),
[border-bottom-left-radius](#propdef-border-bottom-left-radius),
[border-top-right-radius](#propdef-border-top-right-radius), and
[border-bottom-right-radius](#propdef-border-bottom-right-radius). The mapping depends on the
element's
[writing-mode](https://www.w3.org/TR/css-writing-modes-4/#propdef-writing-mode),
[direction](https://www.w3.org/TR/css-writing-modes-3/#propdef-direction), and
[text-orientation](https://www.w3.org/TR/css-writing-modes-4/#propdef-text-orientation), with the first start/end giving
the block axis side, and the second the inline-axis side (i.e. patterned
as \'border-`block`-`inline`-radius\').

### 3.6. Corner Sizing Shorthands: the [border-radius and [border-\*-radius] shorthand properties]
#### 3.6.1. Sizing The Corners Of One Side: The [border-top-radius, [border-right-radius](#propdef-border-right-radius), [border-bottom-radius](#propdef-border-bottom-radius), [border-left-radius](#propdef-border-left-radius), [border-block-start-radius](#propdef-border-block-start-radius), [border-block-end-radius](#propdef-border-block-end-radius), [border-inline-start-radius](#propdef-border-inline-start-radius), [border-inline-end-radius](#propdef-border-inline-end-radius) shorthands]
Name:

[border-top-radius],
[border-right-radius],
[border-bottom-radius],
[border-left-radius],
[border-block-start-radius],
[border-block-end-radius],
[border-inline-start-radius],
[border-inline-end-radius]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<length-percentage
\[0,∞\]\>](https://www.w3.org/TR/css-values-4/#typedef-length-percentage)[{1,2}](https://www.w3.org/TR/css-values-4/#mult-num-range) \[ / [\<length-percentage
\[0,∞\]\>][{1,2}]
\][?](https://www.w3.org/TR/css-values-4/#mult-opt)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

0

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

all elements (but see prose)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

Refer to corresponding dimension of the [border
box](https://www.w3.org/TR/css-box-4/#border-box).

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

see individual properties

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

see individual properties

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

The [border-\*-radius] shorthands set the two
[border-\*-\*-radius] longhand properties of the related side. If
values are given before and after the slash, then the values before the
slash set the horizontal radius and the values after the slash set the
vertical radius. If there is no slash, then the values set both radii
equally. The two values for the radii are given in the order top-left,
top-right for
[border-top-radius](#propdef-border-top-radius), top-right, bottom-right for
[border-right-radius](#propdef-border-right-radius), bottom-left, bottom-right for
[border-bottom-radius](#propdef-border-bottom-radius), top-left, bottom-left for
[border-left-radius](#propdef-border-left-radius), start-start, start-end for
[border-block-start-radius](#propdef-border-block-start-radius), end-start, end-end for
[border-block-end-radius](#propdef-border-block-end-radius) start-start, end-start for
[border-inline-start-radius](#propdef-border-inline-start-radius), and start-end, end-end for
[border-inline-end-radius](#propdef-border-inline-end-radius). If the second value is omitted it
is copied from the first.

Tests

- [border-radius-greater-than-width.html](https://wpt.fyi/results/css/css-borders/border-radius-greater-than-width.html "css/css-borders/border-radius-greater-than-width.html")
 [[(live
 test)]](http://wpt.live/css/css-borders/border-radius-greater-than-width.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-borders/border-radius-greater-than-width.html)
- [border-radius-side-shorthands-001.html](https://wpt.fyi/results/css/css-borders/tentative/border-radius-side-shorthands/border-radius-side-shorthands-001.html "css/css-borders/tentative/border-radius-side-shorthands/border-radius-side-shorthands-001.html")
 [[(live
 test)]](http://wpt.live/css/css-borders/tentative/border-radius-side-shorthands/border-radius-side-shorthands-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-borders/tentative/border-radius-side-shorthands/border-radius-side-shorthands-001.html)
- [border-radius-side-shorthands-002.html](https://wpt.fyi/results/css/css-borders/tentative/border-radius-side-shorthands/border-radius-side-shorthands-002.html "css/css-borders/tentative/border-radius-side-shorthands/border-radius-side-shorthands-002.html")
 [[(live
 test)]](http://wpt.live/css/css-borders/tentative/border-radius-side-shorthands/border-radius-side-shorthands-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-borders/tentative/border-radius-side-shorthands/border-radius-side-shorthands-002.html)
- [border-block-end-radius-computed.html](https://wpt.fyi/results/css/css-borders/tentative/parsing/border-block-end-radius-computed.html "css/css-borders/tentative/parsing/border-block-end-radius-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-borders/tentative/parsing/border-block-end-radius-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-borders/tentative/parsing/border-block-end-radius-computed.html)
- [border-block-end-radius-invalid.html](https://wpt.fyi/results/css/css-borders/tentative/parsing/border-block-end-radius-invalid.html "css/css-borders/tentative/parsing/border-block-end-radius-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-borders/tentative/parsing/border-block-end-radius-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-borders/tentative/parsing/border-block-end-radius-invalid.html)
- [border-block-end-radius-valid.html](https://wpt.fyi/results/css/css-borders/tentative/parsing/border-block-end-radius-valid.html "css/css-borders/tentative/parsing/border-block-end-radius-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-borders/tentative/parsing/border-block-end-radius-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-borders/tentative/parsing/border-block-end-radius-valid.html)
- [border-block-start-radius-computed.html](https://wpt.fyi/results/css/css-borders/tentative/parsing/border-block-start-radius-computed.html "css/css-borders/tentative/parsing/border-block-start-radius-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-borders/tentative/parsing/border-block-start-radius-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-borders/tentative/parsing/border-block-start-radius-computed.html)
- [border-block-start-radius-invalid.html](https://wpt.fyi/results/css/css-borders/tentative/parsing/border-block-start-radius-invalid.html "css/css-borders/tentative/parsing/border-block-start-radius-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-borders/tentative/parsing/border-block-start-radius-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-borders/tentative/parsing/border-block-start-radius-invalid.html)
- [border-block-start-radius-valid.html](https://wpt.fyi/results/css/css-borders/tentative/parsing/border-block-start-radius-valid.html "css/css-borders/tentative/parsing/border-block-start-radius-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-borders/tentative/parsing/border-block-start-radius-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-borders/tentative/parsing/border-block-start-radius-valid.html)
- [border-bottom-radius-computed.html](https://wpt.fyi/results/css/css-borders/tentative/parsing/border-bottom-radius-computed.html "css/css-borders/tentative/parsing/border-bottom-radius-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-borders/tentative/parsing/border-bottom-radius-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-borders/tentative/parsing/border-bottom-radius-computed.html)
- [border-bottom-radius-invalid.html](https://wpt.fyi/results/css/css-borders/tentative/parsing/border-bottom-radius-invalid.html "css/css-borders/tentative/parsing/border-bottom-radius-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-borders/tentative/parsing/border-bottom-radius-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-borders/tentative/parsing/border-bottom-radius-invalid.html)
- [border-bottom-radius-valid.html](https://wpt.fyi/results/css/css-borders/tentative/parsing/border-bottom-radius-valid.html "css/css-borders/tentative/parsing/border-bottom-radius-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-borders/tentative/parsing/border-bottom-radius-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-borders/tentative/parsing/border-bottom-radius-valid.html)
- [border-inline-end-radius-computed.html](https://wpt.fyi/results/css/css-borders/tentative/parsing/border-inline-end-radius-computed.html "css/css-borders/tentative/parsing/border-inline-end-radius-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-borders/tentative/parsing/border-inline-end-radius-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-borders/tentative/parsing/border-inline-end-radius-computed.html)
- [border-inline-end-radius-invalid.html](https://wpt.fyi/results/css/css-borders/tentative/parsing/border-inline-end-radius-invalid.html "css/css-borders/tentative/parsing/border-inline-end-radius-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-borders/tentative/parsing/border-inline-end-radius-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-borders/tentative/parsing/border-inline-end-radius-invalid.html)
- [border-inline-end-radius-valid.html](https://wpt.fyi/results/css/css-borders/tentative/parsing/border-inline-end-radius-valid.html "css/css-borders/tentative/parsing/border-inline-end-radius-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-borders/tentative/parsing/border-inline-end-radius-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-borders/tentative/parsing/border-inline-end-radius-valid.html)
- [border-inline-start-radius-computed.html](https://wpt.fyi/results/css/css-borders/tentative/parsing/border-inline-start-radius-computed.html "css/css-borders/tentative/parsing/border-inline-start-radius-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-borders/tentative/parsing/border-inline-start-radius-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-borders/tentative/parsing/border-inline-start-radius-computed.html)
- [border-inline-start-radius-invalid.html](https://wpt.fyi/results/css/css-borders/tentative/parsing/border-inline-start-radius-invalid.html "css/css-borders/tentative/parsing/border-inline-start-radius-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-borders/tentative/parsing/border-inline-start-radius-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-borders/tentative/parsing/border-inline-start-radius-invalid.html)
- [border-inline-start-radius-valid.html](https://wpt.fyi/results/css/css-borders/tentative/parsing/border-inline-start-radius-valid.html "css/css-borders/tentative/parsing/border-inline-start-radius-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-borders/tentative/parsing/border-inline-start-radius-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-borders/tentative/parsing/border-inline-start-radius-valid.html)
- [border-left-radius-computed.html](https://wpt.fyi/results/css/css-borders/tentative/parsing/border-left-radius-computed.html "css/css-borders/tentative/parsing/border-left-radius-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-borders/tentative/parsing/border-left-radius-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-borders/tentative/parsing/border-left-radius-computed.html)
- [border-left-radius-invalid.html](https://wpt.fyi/results/css/css-borders/tentative/parsing/border-left-radius-invalid.html "css/css-borders/tentative/parsing/border-left-radius-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-borders/tentative/parsing/border-left-radius-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-borders/tentative/parsing/border-left-radius-invalid.html)
- [border-left-radius-valid.html](https://wpt.fyi/results/css/css-borders/tentative/parsing/border-left-radius-valid.html "css/css-borders/tentative/parsing/border-left-radius-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-borders/tentative/parsing/border-left-radius-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-borders/tentative/parsing/border-left-radius-valid.html)
- [border-right-radius-computed.html](https://wpt.fyi/results/css/css-borders/tentative/parsing/border-right-radius-computed.html "css/css-borders/tentative/parsing/border-right-radius-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-borders/tentative/parsing/border-right-radius-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-borders/tentative/parsing/border-right-radius-computed.html)
- [border-right-radius-invalid.html](https://wpt.fyi/results/css/css-borders/tentative/parsing/border-right-radius-invalid.html "css/css-borders/tentative/parsing/border-right-radius-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-borders/tentative/parsing/border-right-radius-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-borders/tentative/parsing/border-right-radius-invalid.html)
- [border-right-radius-valid.html](https://wpt.fyi/results/css/css-borders/tentative/parsing/border-right-radius-valid.html "css/css-borders/tentative/parsing/border-right-radius-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-borders/tentative/parsing/border-right-radius-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-borders/tentative/parsing/border-right-radius-valid.html)
- [border-top-radius-computed.html](https://wpt.fyi/results/css/css-borders/tentative/parsing/border-top-radius-computed.html "css/css-borders/tentative/parsing/border-top-radius-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-borders/tentative/parsing/border-top-radius-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-borders/tentative/parsing/border-top-radius-computed.html)
- [border-top-radius-invalid.html](https://wpt.fyi/results/css/css-borders/tentative/parsing/border-top-radius-invalid.html "css/css-borders/tentative/parsing/border-top-radius-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-borders/tentative/parsing/border-top-radius-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-borders/tentative/parsing/border-top-radius-invalid.html)
- [border-top-radius-valid.html](https://wpt.fyi/results/css/css-borders/tentative/parsing/border-top-radius-valid.html "css/css-borders/tentative/parsing/border-top-radius-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-borders/tentative/parsing/border-top-radius-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-borders/tentative/parsing/border-top-radius-valid.html)

<!-- -->

- [border-bottom-left-radius-composition.html](https://wpt.fyi/results/css/css-backgrounds/animations/border-bottom-left-radius-composition.html "css/css-backgrounds/animations/border-bottom-left-radius-composition.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/animations/border-bottom-left-radius-composition.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/animations/border-bottom-left-radius-composition.html)
- [border-bottom-right-radius-composition.html](https://wpt.fyi/results/css/css-backgrounds/animations/border-bottom-right-radius-composition.html "css/css-backgrounds/animations/border-bottom-right-radius-composition.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/animations/border-bottom-right-radius-composition.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/animations/border-bottom-right-radius-composition.html)
- [border-radius-interpolation.html](https://wpt.fyi/results/css/css-backgrounds/animations/border-radius-interpolation.html "css/css-backgrounds/animations/border-radius-interpolation.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/animations/border-radius-interpolation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/animations/border-radius-interpolation.html)
- [border-top-left-radius-composition.html](https://wpt.fyi/results/css/css-backgrounds/animations/border-top-left-radius-composition.html "css/css-backgrounds/animations/border-top-left-radius-composition.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/animations/border-top-left-radius-composition.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/animations/border-top-left-radius-composition.html)
- [border-top-right-radius-composition.html](https://wpt.fyi/results/css/css-backgrounds/animations/border-top-right-radius-composition.html "css/css-backgrounds/animations/border-top-right-radius-composition.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/animations/border-top-right-radius-composition.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/animations/border-top-right-radius-composition.html)
- [border-bottom-left-radius-001.xht](https://wpt.fyi/results/css/css-backgrounds/border-bottom-left-radius-001.xht "css/css-backgrounds/border-bottom-left-radius-001.xht")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-bottom-left-radius-001.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-bottom-left-radius-001.xht)
- [border-bottom-left-radius-004.xht](https://wpt.fyi/results/css/css-backgrounds/border-bottom-left-radius-004.xht "css/css-backgrounds/border-bottom-left-radius-004.xht")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-bottom-left-radius-004.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-bottom-left-radius-004.xht)
- [border-bottom-left-radius-005.xht](https://wpt.fyi/results/css/css-backgrounds/border-bottom-left-radius-005.xht "css/css-backgrounds/border-bottom-left-radius-005.xht")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-bottom-left-radius-005.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-bottom-left-radius-005.xht)
- [border-bottom-left-radius-010.xht](https://wpt.fyi/results/css/css-backgrounds/border-bottom-left-radius-010.xht "css/css-backgrounds/border-bottom-left-radius-010.xht")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-bottom-left-radius-010.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-bottom-left-radius-010.xht)
- [border-bottom-left-radius-011.xht](https://wpt.fyi/results/css/css-backgrounds/border-bottom-left-radius-011.xht "css/css-backgrounds/border-bottom-left-radius-011.xht")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-bottom-left-radius-011.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-bottom-left-radius-011.xht)
- [border-bottom-left-radius-014.xht](https://wpt.fyi/results/css/css-backgrounds/border-bottom-left-radius-014.xht "css/css-backgrounds/border-bottom-left-radius-014.xht")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-bottom-left-radius-014.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-bottom-left-radius-014.xht)
- [border-bottom-right-radius-001.xht](https://wpt.fyi/results/css/css-backgrounds/border-bottom-right-radius-001.xht "css/css-backgrounds/border-bottom-right-radius-001.xht")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-bottom-right-radius-001.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-bottom-right-radius-001.xht)
- [border-bottom-right-radius-004.xht](https://wpt.fyi/results/css/css-backgrounds/border-bottom-right-radius-004.xht "css/css-backgrounds/border-bottom-right-radius-004.xht")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-bottom-right-radius-004.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-bottom-right-radius-004.xht)
- [border-bottom-right-radius-005.xht](https://wpt.fyi/results/css/css-backgrounds/border-bottom-right-radius-005.xht "css/css-backgrounds/border-bottom-right-radius-005.xht")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-bottom-right-radius-005.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-bottom-right-radius-005.xht)
- [border-bottom-right-radius-010.xht](https://wpt.fyi/results/css/css-backgrounds/border-bottom-right-radius-010.xht "css/css-backgrounds/border-bottom-right-radius-010.xht")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-bottom-right-radius-010.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-bottom-right-radius-010.xht)
- [border-bottom-right-radius-011.xht](https://wpt.fyi/results/css/css-backgrounds/border-bottom-right-radius-011.xht "css/css-backgrounds/border-bottom-right-radius-011.xht")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-bottom-right-radius-011.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-bottom-right-radius-011.xht)
- [border-bottom-right-radius-014.xht](https://wpt.fyi/results/css/css-backgrounds/border-bottom-right-radius-014.xht "css/css-backgrounds/border-bottom-right-radius-014.xht")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-bottom-right-radius-014.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-bottom-right-radius-014.xht)
- [border-radius-001.xht](https://wpt.fyi/results/css/css-backgrounds/border-radius-001.xht "css/css-backgrounds/border-radius-001.xht")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-radius-001.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-radius-001.xht)
- [border-radius-002.xht](https://wpt.fyi/results/css/css-backgrounds/border-radius-002.xht "css/css-backgrounds/border-radius-002.xht")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-radius-002.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-radius-002.xht)
- [border-radius-003.xht](https://wpt.fyi/results/css/css-backgrounds/border-radius-003.xht "css/css-backgrounds/border-radius-003.xht")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-radius-003.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-radius-003.xht)
- [border-radius-004.xht](https://wpt.fyi/results/css/css-backgrounds/border-radius-004.xht "css/css-backgrounds/border-radius-004.xht")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-radius-004.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-radius-004.xht)
- [border-radius-005.xht](https://wpt.fyi/results/css/css-backgrounds/border-radius-005.xht "css/css-backgrounds/border-radius-005.xht")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-radius-005.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-radius-005.xht)
- [border-radius-006.xht](https://wpt.fyi/results/css/css-backgrounds/border-radius-006.xht "css/css-backgrounds/border-radius-006.xht")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-radius-006.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-radius-006.xht)
- [border-radius-007.xht](https://wpt.fyi/results/css/css-backgrounds/border-radius-007.xht "css/css-backgrounds/border-radius-007.xht")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-radius-007.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-radius-007.xht)
- [border-radius-008.xht](https://wpt.fyi/results/css/css-backgrounds/border-radius-008.xht "css/css-backgrounds/border-radius-008.xht")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-radius-008.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-radius-008.xht)
- [border-radius-009.xht](https://wpt.fyi/results/css/css-backgrounds/border-radius-009.xht "css/css-backgrounds/border-radius-009.xht")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-radius-009.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-radius-009.xht)
- [border-radius-010.xht](https://wpt.fyi/results/css/css-backgrounds/border-radius-010.xht "css/css-backgrounds/border-radius-010.xht")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-radius-010.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-radius-010.xht)
- [border-radius-011.xht](https://wpt.fyi/results/css/css-backgrounds/border-radius-011.xht "css/css-backgrounds/border-radius-011.xht")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-radius-011.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-radius-011.xht)
- [border-radius-012.html](https://wpt.fyi/results/css/css-backgrounds/border-radius-012.html "css/css-backgrounds/border-radius-012.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-radius-012.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-radius-012.html)
- [border-radius-013.html](https://wpt.fyi/results/css/css-backgrounds/border-radius-013.html "css/css-backgrounds/border-radius-013.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-radius-013.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-radius-013.html)
- [border-radius-clip-001.html](https://wpt.fyi/results/css/css-backgrounds/border-radius-clip-001.html "css/css-backgrounds/border-radius-clip-001.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-radius-clip-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-radius-clip-001.html)
- [border-radius-clip-002.htm](https://wpt.fyi/results/css/css-backgrounds/border-radius-clip-002.htm "css/css-backgrounds/border-radius-clip-002.htm")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-radius-clip-002.htm)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-radius-clip-002.htm)
- [border-radius-clipping-002.html](https://wpt.fyi/results/css/css-backgrounds/border-radius-clipping-002.html "css/css-backgrounds/border-radius-clipping-002.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-radius-clipping-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-radius-clipping-002.html)
- [border-radius-clipping-with-transform-001.html](https://wpt.fyi/results/css/css-backgrounds/border-radius-clipping-with-transform-001.html "css/css-backgrounds/border-radius-clipping-with-transform-001.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-radius-clipping-with-transform-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-radius-clipping-with-transform-001.html)
- [border-radius-css-text.html](https://wpt.fyi/results/css/css-backgrounds/border-radius-css-text.html "css/css-backgrounds/border-radius-css-text.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-radius-css-text.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-radius-css-text.html)
- [border-radius-dynamic-from-no-radius.html](https://wpt.fyi/results/css/css-backgrounds/border-radius-dynamic-from-no-radius.html "css/css-backgrounds/border-radius-dynamic-from-no-radius.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-radius-dynamic-from-no-radius.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-radius-dynamic-from-no-radius.html)
- [border-radius-horizontal-value-is-zero.html](https://wpt.fyi/results/css/css-backgrounds/border-radius-horizontal-value-is-zero.html "css/css-backgrounds/border-radius-horizontal-value-is-zero.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-radius-horizontal-value-is-zero.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-radius-horizontal-value-is-zero.html)
- [border-radius-shorthand-002.html](https://wpt.fyi/results/css/css-backgrounds/border-radius-shorthand-002.html "css/css-backgrounds/border-radius-shorthand-002.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-radius-shorthand-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-radius-shorthand-002.html)
- [border-top-left-radius-001.xht](https://wpt.fyi/results/css/css-backgrounds/border-top-left-radius-001.xht "css/css-backgrounds/border-top-left-radius-001.xht")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-top-left-radius-001.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-top-left-radius-001.xht)
- [border-top-left-radius-004.xht](https://wpt.fyi/results/css/css-backgrounds/border-top-left-radius-004.xht "css/css-backgrounds/border-top-left-radius-004.xht")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-top-left-radius-004.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-top-left-radius-004.xht)
- [border-top-left-radius-005.xht](https://wpt.fyi/results/css/css-backgrounds/border-top-left-radius-005.xht "css/css-backgrounds/border-top-left-radius-005.xht")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-top-left-radius-005.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-top-left-radius-005.xht)
- [border-top-left-radius-010.xht](https://wpt.fyi/results/css/css-backgrounds/border-top-left-radius-010.xht "css/css-backgrounds/border-top-left-radius-010.xht")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-top-left-radius-010.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-top-left-radius-010.xht)
- [border-top-left-radius-011.xht](https://wpt.fyi/results/css/css-backgrounds/border-top-left-radius-011.xht "css/css-backgrounds/border-top-left-radius-011.xht")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-top-left-radius-011.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-top-left-radius-011.xht)
- [border-top-left-radius-014.xht](https://wpt.fyi/results/css/css-backgrounds/border-top-left-radius-014.xht "css/css-backgrounds/border-top-left-radius-014.xht")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-top-left-radius-014.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-top-left-radius-014.xht)
- [border-top-right-radius-001.xht](https://wpt.fyi/results/css/css-backgrounds/border-top-right-radius-001.xht "css/css-backgrounds/border-top-right-radius-001.xht")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-top-right-radius-001.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-top-right-radius-001.xht)
- [border-top-right-radius-004.xht](https://wpt.fyi/results/css/css-backgrounds/border-top-right-radius-004.xht "css/css-backgrounds/border-top-right-radius-004.xht")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-top-right-radius-004.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-top-right-radius-004.xht)
- [border-top-right-radius-005.xht](https://wpt.fyi/results/css/css-backgrounds/border-top-right-radius-005.xht "css/css-backgrounds/border-top-right-radius-005.xht")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-top-right-radius-005.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-top-right-radius-005.xht)
- [border-top-right-radius-010.xht](https://wpt.fyi/results/css/css-backgrounds/border-top-right-radius-010.xht "css/css-backgrounds/border-top-right-radius-010.xht")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-top-right-radius-010.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-top-right-radius-010.xht)
- [border-top-right-radius-011.xht](https://wpt.fyi/results/css/css-backgrounds/border-top-right-radius-011.xht "css/css-backgrounds/border-top-right-radius-011.xht")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-top-right-radius-011.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-top-right-radius-011.xht)
- [border-top-right-radius-014.xht](https://wpt.fyi/results/css/css-backgrounds/border-top-right-radius-014.xht "css/css-backgrounds/border-top-right-radius-014.xht")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-top-right-radius-014.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-top-right-radius-014.xht)
- [box-shadow-border-radius-001.html](https://wpt.fyi/results/css/css-backgrounds/box-shadow-border-radius-001.html "css/css-backgrounds/box-shadow-border-radius-001.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/box-shadow-border-radius-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/box-shadow-border-radius-001.html)
- [css-border-radius-001.html](https://wpt.fyi/results/css/css-backgrounds/css-border-radius-001.html "css/css-backgrounds/css-border-radius-001.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/css-border-radius-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/css-border-radius-001.html)
- [inheritance.sub.html](https://wpt.fyi/results/css/css-backgrounds/inheritance.sub.html "css/css-backgrounds/inheritance.sub.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/inheritance.sub.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/inheritance.sub.html)
- [inner-border-non-renderable.html](https://wpt.fyi/results/css/css-backgrounds/inner-border-non-renderable.html "css/css-backgrounds/inner-border-non-renderable.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/inner-border-non-renderable.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/inner-border-non-renderable.html)
- [border-radius-computed.html](https://wpt.fyi/results/css/css-backgrounds/parsing/border-radius-computed.html "css/css-backgrounds/parsing/border-radius-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/parsing/border-radius-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/parsing/border-radius-computed.html)
- [border-radius-invalid.html](https://wpt.fyi/results/css/css-backgrounds/parsing/border-radius-invalid.html "css/css-backgrounds/parsing/border-radius-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/parsing/border-radius-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/parsing/border-radius-invalid.html)
- [border-radius-valid.html](https://wpt.fyi/results/css/css-backgrounds/parsing/border-radius-valid.html "css/css-backgrounds/parsing/border-radius-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/parsing/border-radius-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/parsing/border-radius-valid.html)
- [webkit-border-radius-valid.html](https://wpt.fyi/results/css/css-backgrounds/parsing/webkit-border-radius-valid.html "css/css-backgrounds/parsing/webkit-border-radius-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/parsing/webkit-border-radius-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/parsing/webkit-border-radius-valid.html)

#### 3.6.2. Sizing All Corners At Once: The [border-radius shorthand]
Name:

[border-radius]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<length-percentage
\[0,∞\]\>](https://www.w3.org/TR/css-values-4/#typedef-length-percentage)[{1,4}](https://www.w3.org/TR/css-values-4/#mult-num-range) \[ / [\<length-percentage
\[0,∞\]\>][{1,4}]
\][?](https://www.w3.org/TR/css-values-4/#mult-opt)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

see individual properties

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

see individual properties

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

see individual properties

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

see individual properties

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

see individual properties

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

see individual properties

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

The
[border-radius](#propdef-border-radius) shorthand sets all four
[border-\*-radius] properties. If values are given before and
after the slash, then the values before the slash set the horizontal
radii and the values after the slash set the vertical radii. If there is
no slash, then the values set the radii in both axes equally. The four
values for each radii are given in the order top-left, top-right,
bottom-right, bottom-left. If bottom-left is omitted it is the same as
top-right. If bottom-right is omitted it is the same as top-left. If
top-right is omitted it is the same as top-left.

border-radius: 4em;

is equivalent to

 border-top-left-radius: 4em;
 border-top-right-radius: 4em;
 border-bottom-right-radius: 4em;
 border-bottom-left-radius: 4em;

and

 border-radius: 2em 1em 4em / 0.5em 3em;

is equivalent to

 border-top-left-radius: 2em 0.5em;
 border-top-right-radius: 1em 3em;
 border-bottom-right-radius: 4em 0.5em;
 border-bottom-left-radius: 1em 3em;

### [3.7. ][ Corner Shaping: the [corner-\*-shape] properties]
By default, non-zero
[border-radius](#propdef-border-radius) values define a quarter-ellipse
[corner shape]
that rounds the affected corners, filling the [corner area] defined by the
[border-radius] for that
corner. However in some cases, other [corner
shapes](#corner-shape) are
desired. The [corner-\*-shape] properties (and their shorthands)
specify exactly what [corner shapes] a box will
use for the region defined by its [border-\*-radius] values.

The different [corner shapes](#corner-shape) can all be expressed as different parameters to a
*superellipse*. A superellipse is a generalization of an ellipse, and
based on its \`k\` parameter can express all the shapes between a
square, an ellipse, and a notch.

How does a superellipse work?

A unit circle is defined by the equation:

<figure>
<span
class="math display"><em>x</em><sup>2</sup> + <em>y</em><sup>2</sup> = 1</span>
</figure>

The circle is made from all points (x,y) that satisfy the equation. A
given ellipse can then be produced by scaling this shape in the X and/or
Y axis.

The unit superellipse equation just changes the ^2^ exponent into a
variable. For this spec's purposes, we'll write it as 2^K^:

<figure>
<span
class="math display"><em>x</em><sup>2<sup><em>K</em></sup></sup> + <em>y</em><sup>2<sup><em>K</em></sup></sup> = 1</span>
</figure>

The `K` in this equation is the
[superellipse()](#funcdef-superellipse) argument.

`K` can be any value; setting `K` to 1 gives the
standard circle/ellipse equation, but other values define the entire
family of superellipse curves:

- Values larger than 1 make it more \"square\": the traditional
 \"squircle\" uses a `K` of 2, and a `K` of
 infinity is a perfect square. (A `K` of only 10 is already
 nearly indistinguishable from a square; it scales very quickly.)

- Values between 0 and 1 make it \"flatter\"; when `K` is 0
 it's a diamond with perfectly flat sides.

- Negative values define concave curves, exact opposite of what you get
 with positive values: a `K` of -1 gives an elliptical
 \"scoop\" that's the opposite of a `K` of 1, a
 `K` of -2 gives a \"squircle\" scoop, a `K` of
 negative infinity gives a square scoop, etc.

(Note that most literature on superellipses will write the equation with
a simpler $x^{n}$ exponent. The $x^{2^{K}}$ form was chosen here to make
the argument ranges easier to reason about: all possible values are
valid, the symmetrical shapes are just positive/negative, the \"middle\"
bevel is 0, etc.)

To allow full expression as well as interpolation, the
[corner-shape](#propdef-corner-shape) properties can provide the superellipse
parameter directly using the
[superellipse()](#funcdef-superellipse) function, or use one of the supplied keywords
which represent commonly used parameters. See the
[\<corner-shape-value\>](#typedef-corner-shape-value) definition for details.

Tests

- [corner-shape-backdrop-filter.html](https://wpt.fyi/results/css/css-borders/corner-shape/corner-shape-backdrop-filter.html "css/css-borders/corner-shape/corner-shape-backdrop-filter.html")
 [[(live
 test)]](http://wpt.live/css/css-borders/corner-shape/corner-shape-backdrop-filter.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-borders/corner-shape/corner-shape-backdrop-filter.html)
- [corner-shape-backdrop-filter-overflow.html](https://wpt.fyi/results/css/css-borders/corner-shape/corner-shape-backdrop-filter-overflow.html "css/css-borders/corner-shape/corner-shape-backdrop-filter-overflow.html")
 [[(live
 test)]](http://wpt.live/css/css-borders/corner-shape/corner-shape-backdrop-filter-overflow.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-borders/corner-shape/corner-shape-backdrop-filter-overflow.html)
- [corner-shape-bevel-overflow-composite.html](https://wpt.fyi/results/css/css-borders/corner-shape/corner-shape-bevel-overflow-composite.html "css/css-borders/corner-shape/corner-shape-bevel-overflow-composite.html")
 [[(live
 test)]](http://wpt.live/css/css-borders/corner-shape/corner-shape-bevel-overflow-composite.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-borders/corner-shape/corner-shape-bevel-overflow-composite.html)
- [corner-shape-bevel-overflow.html](https://wpt.fyi/results/css/css-borders/corner-shape/corner-shape-bevel-overflow.html "css/css-borders/corner-shape/corner-shape-bevel-overflow.html")
 [[(live
 test)]](http://wpt.live/css/css-borders/corner-shape/corner-shape-bevel-overflow.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-borders/corner-shape/corner-shape-bevel-overflow.html)
- [corner-shape-computed.html](https://wpt.fyi/results/css/css-borders/corner-shape/corner-shape-computed.html "css/css-borders/corner-shape/corner-shape-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-borders/corner-shape/corner-shape-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-borders/corner-shape/corner-shape-computed.html)
- [corner-shape-fill.html](https://wpt.fyi/results/css/css-borders/corner-shape/corner-shape-fill.html "css/css-borders/corner-shape/corner-shape-fill.html")
 [[(live
 test)]](http://wpt.live/css/css-borders/corner-shape/corner-shape-fill.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-borders/corner-shape/corner-shape-fill.html)
- [corner-shape-hittest.html](https://wpt.fyi/results/css/css-borders/corner-shape/corner-shape-hittest.html "css/css-borders/corner-shape/corner-shape-hittest.html")
 [[(live
 test)]](http://wpt.live/css/css-borders/corner-shape/corner-shape-hittest.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-borders/corner-shape/corner-shape-hittest.html)
- [corner-shape-iframe-border.html](https://wpt.fyi/results/css/css-borders/corner-shape/corner-shape-iframe-border.html "css/css-borders/corner-shape/corner-shape-iframe-border.html")
 [[(live
 test)]](http://wpt.live/css/css-borders/corner-shape/corner-shape-iframe-border.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-borders/corner-shape/corner-shape-iframe-border.html)
- [corner-shape-img-border.html](https://wpt.fyi/results/css/css-borders/corner-shape/corner-shape-img-border.html "css/css-borders/corner-shape/corner-shape-img-border.html")
 [[(live
 test)]](http://wpt.live/css/css-borders/corner-shape/corner-shape-img-border.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-borders/corner-shape/corner-shape-img-border.html)
- [corner-shape-img.html](https://wpt.fyi/results/css/css-borders/corner-shape/corner-shape-img.html "css/css-borders/corner-shape/corner-shape-img.html")
 [[(live
 test)]](http://wpt.live/css/css-borders/corner-shape/corner-shape-img.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-borders/corner-shape/corner-shape-img.html)
- [corner-shape-inset-shadow.html](https://wpt.fyi/results/css/css-borders/corner-shape/corner-shape-inset-shadow.html "css/css-borders/corner-shape/corner-shape-inset-shadow.html")
 [[(live
 test)]](http://wpt.live/css/css-borders/corner-shape/corner-shape-inset-shadow.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-borders/corner-shape/corner-shape-inset-shadow.html)
- [corner-shape-invalid.html](https://wpt.fyi/results/css/css-borders/corner-shape/corner-shape-invalid.html "css/css-borders/corner-shape/corner-shape-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-borders/corner-shape/corner-shape-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-borders/corner-shape/corner-shape-invalid.html)
- [corner-shape-notch.html](https://wpt.fyi/results/css/css-borders/corner-shape/corner-shape-notch.html "css/css-borders/corner-shape/corner-shape-notch.html")
 [[(live
 test)]](http://wpt.live/css/css-borders/corner-shape/corner-shape-notch.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-borders/corner-shape/corner-shape-notch.html)
- [corner-shape-outside-left.html](https://wpt.fyi/results/css/css-borders/corner-shape/corner-shape-outside-left.html "css/css-borders/corner-shape/corner-shape-outside-left.html")
 [[(live
 test)]](http://wpt.live/css/css-borders/corner-shape/corner-shape-outside-left.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-borders/corner-shape/corner-shape-outside-left.html)
- [corner-shape-outside-right.html](https://wpt.fyi/results/css/css-borders/corner-shape/corner-shape-outside-right.html "css/css-borders/corner-shape/corner-shape-outside-right.html")
 [[(live
 test)]](http://wpt.live/css/css-borders/corner-shape/corner-shape-outside-right.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-borders/corner-shape/corner-shape-outside-right.html)
- [corner-shape-overflow-clip-margin.html](https://wpt.fyi/results/css/css-borders/corner-shape/corner-shape-overflow-clip-margin.html "css/css-borders/corner-shape/corner-shape-overflow-clip-margin.html")
 [[(live
 test)]](http://wpt.live/css/css-borders/corner-shape/corner-shape-overflow-clip-margin.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-borders/corner-shape/corner-shape-overflow-clip-margin.html)
- [corner-shape-square.html](https://wpt.fyi/results/css/css-borders/corner-shape/corner-shape-square.html "css/css-borders/corner-shape/corner-shape-square.html")
 [[(live
 test)]](http://wpt.live/css/css-borders/corner-shape/corner-shape-square.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-borders/corner-shape/corner-shape-square.html)
- [corner-shape-svg-border.html](https://wpt.fyi/results/css/css-borders/corner-shape/corner-shape-svg-border.html "css/css-borders/corner-shape/corner-shape-svg-border.html")
 [[(live
 test)]](http://wpt.live/css/css-borders/corner-shape/corner-shape-svg-border.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-borders/corner-shape/corner-shape-svg-border.html)
- [corner-shape-valid.html](https://wpt.fyi/results/css/css-borders/corner-shape/corner-shape-valid.html "css/css-borders/corner-shape/corner-shape-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-borders/corner-shape/corner-shape-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-borders/corner-shape/corner-shape-valid.html)
- [corner-shape-video-border.html](https://wpt.fyi/results/css/css-borders/corner-shape/corner-shape-video-border.html "css/css-borders/corner-shape/corner-shape-video-border.html")
 [[(live
 test)]](http://wpt.live/css/css-borders/corner-shape/corner-shape-video-border.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-borders/corner-shape/corner-shape-video-border.html)
- [corner-shape-noop-keyframe.html](https://wpt.fyi/results/css/css-borders/corner-shape/corner-shape-noop-keyframe.html "css/css-borders/corner-shape/corner-shape-noop-keyframe.html")
 [[(live
 test)]](http://wpt.live/css/css-borders/corner-shape/corner-shape-noop-keyframe.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-borders/corner-shape/corner-shape-noop-keyframe.html)
- [corner-shape-zoom-overlap-extreme-values-crash.html](https://wpt.fyi/results/css/css-borders/corner-shape/corner-shape-zoom-overlap-extreme-values-crash.html "css/css-borders/corner-shape/corner-shape-zoom-overlap-extreme-values-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-borders/corner-shape/corner-shape-zoom-overlap-extreme-values-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-borders/corner-shape/corner-shape-zoom-overlap-extreme-values-crash.html)
- [render-corner-shape.html](https://wpt.fyi/results/css/css-borders/corner-shape/render-corner-shape.html "css/css-borders/corner-shape/render-corner-shape.html")
 [[(live
 test)]](http://wpt.live/css/css-borders/corner-shape/render-corner-shape.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-borders/corner-shape/render-corner-shape.html)

Name:

[corner-top-left-shape],
[corner-top-right-shape],
[corner-bottom-right-shape],
[corner-bottom-left-shape],
[corner-start-start-shape],
[corner-start-end-shape],
[corner-end-start-shape],
[corner-end-end-shape]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<corner-shape-value\>](#typedef-corner-shape-value)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

round

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

all elements where
[border-radius](#propdef-border-radius) can apply

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

the corresponding
[superellipse()](#funcdef-superellipse) value

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

see [superellipse
interpolation](#superellipse-interpolation)

[Logical property
group:](https://drafts.csswg.org/css-logical-1/#logical-property-group)

[corner-shape](#propdef-corner-shape)

The [corner-\*-\*-shape] longhand properties set the corner shape
for the given corner.

The
[flow-relative](https://www.w3.org/TR/css-writing-modes-4/#flow-relative) longhands
([corner-start-start-shape](#propdef-corner-start-start-shape), etc.) correspond to the
[physical](https://www.w3.org/TR/css-writing-modes-4/#physical) longhands
([corner-top-left-shape](#propdef-corner-top-left-shape), etc.) depending on the element's
[writing-mode](https://www.w3.org/TR/css-writing-modes-4/#propdef-writing-mode),
[direction](https://www.w3.org/TR/css-writing-modes-3/#propdef-direction), and
[text-orientation](https://www.w3.org/TR/css-writing-modes-4/#propdef-text-orientation). The first
[start]/[end] gives the block axis side, and the second the
inline-axis side (i.e. patterned as
[corner-`block`-`inline`-shape]).

``` prod
<corner-shape-value> = round | scoop | bevel | notch | square | squircle |
 <superellipse()>
superellipse() = superellipse(<number> | infinity | -infinity)
```

[round]

: The [corner shape](#corner-shape) is a quarter of a convex ellipse. Equivalent to
 [superellipse(1)].

 This is the initial value of
 [corner-shape](#propdef-corner-shape) properties, as it was the
 behavior of
 [border-radius](#propdef-border-radius) before
 [corner-shape] existed.

[squircle]
: The [corner shape](#corner-shape) is a quarter of a \"squircle\", a convex curve
 between
 [round](#valdef-corner-shape-value-round) and
 [square](#valdef-corner-shape-value-square). Equivalent to [superellipse(2)].

[square]

: The [corner shape](#corner-shape) is a convex 90deg angle. Equivalent to
 [superellipse(infinity)].

 This looks identical to the \"normal\" square
 corner you get from [border-radius:
 0](#propdef-border-radius), but it can smoothly animate with the other
 [corner-shape](#propdef-corner-shape) values.

[bevel]
: The [corner shape](#corner-shape) is a straight diagonal line, neither convex nor
 concave. Equivalent to [superellipse(0)].

[scoop]
: The [corner shape](#corner-shape) is a concave quarter-ellipse. Equivalent to
 [superellipse(-1)].

[notch]
: The [corner shape](#corner-shape) is a concave 90deg angle. Equivalent to
 [superellipse(-infinity)].

[superellipse(K)]

: The [corner shape](#corner-shape) is a quarter of a superellipse. The argument
 `K` is the [superellipse
 parameter], and it defines a superellipse using an
 exponent of 2^K^.

 See the note in [§ 3.7 Corner Shaping: the corner-\*-shape
 properties](#corner-shaping) for an explanation of the mathematical
 definition of a superellipse, and what various K values mean. See
 [§ 3.9.4 Rendering corner-shape](#corner-shape-rendering) for
 precise details of how the superellipse is computed and rendered.

![Different
[superellipse()](#funcdef-superellipse) values for the top right corner: infinity, 1, 0,
-1, and -infinity.](images/superellipse-param.svg){height="360"
width="480"}

[border-radius](#propdef-border-radius) is not specified (or is set to 0),
the [corner area](#corner-area) is
zero-sized as well, and
[corner-shape](#propdef-corner-shape) won't have any effect.

[corner-\*-shape] does not alter the
[overflow](https://www.w3.org/TR/css-overflow-3/#overflow) rules for [border-\*-radius], except insofar as
it shapes the corners differently; elements are still clipped by the
shaped border as normal.

The curve specified by [corner-\*-shape] defines the *outer* edge
of the border. The inner edge of the border follows the curve of the
outer edge (in a way that's not necessarily expressible as a
superellipse curve), with a nearly consistent distance from the outer
edge throughout, (or a linearly increasing distance if the
[border-width](#propdef-border-width) of the two border edges meeting at
the the corner are not uniform).

[corner-\*-shape] also affects the rendering of
[box-shadow](#propdef-box-shadow), and how the [overflow clip
edge](https://www.w3.org/TR/css-overflow-4/#overflow-clip-edge) is shaped when it's extended from the box, but these do
not directly follow the [corner-\*-shape] path like the inner
border edge does. Instead, it scales the
[corner-shape](#propdef-corner-shape) path in an axis-aligned manner.

### 3.8. Corner Shaping Shorthands: the [corner-shape and [corner-\*-shape] shorthand properties]
#### [3.8.1. ][ Shaping The Corners Of One Side: The [corner-\*-shape] shorthands:]
Name:

[corner-top-shape],
[corner-right-shape],
[corner-bottom-shape],
[corner-left-shape],
[corner-block-start-shape],
[corner-block-end-shape],
[corner-inline-start-shape],
[corner-inline-end-shape]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<\'corner-top-left-shape\'\>](#propdef-corner-top-left-shape)[{1,2}](https://www.w3.org/TR/css-values-4/#mult-num-range)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

see individual properties

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

see individual properties

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

see individual properties

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

see individual properties

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

see individual properties

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

see individual properties

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

The [corner-\*-shape] shorthands set the two
[corner-\*-\*-shape] properties of the related side. If only one
value is given, the second value defaults to the same value.

For the physical shorthands
([corner-top-shape](#propdef-corner-top-shape), etc.), the values are either in
left/right order, or top/bottom order, whichever axis is meaningful for
the property. That is, [corner-top-shape: round
square] sets
[corner-top-left-shape: round; corner-top-right-shape:
square;](#propdef-corner-top-left-shape).

For the logical shorthands
([corner-block-start-shape](#propdef-corner-block-start-shape), etc.), the values are always in
start/end order in the other axis. That is, [corner-block-start-shape:
round square] sets
[corner-start-start-shape: round; corner-start-end-shape:
square;](#propdef-corner-start-start-shape).

#### 3.8.2. Shaping All Corners At Once: The [corner-shape shorthand]
Name:

[corner-shape]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<\'corner-top-left-shape\'\>](#propdef-corner-top-left-shape)[{1,4}](https://www.w3.org/TR/css-values-4/#mult-num-range)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

round

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

all elements where
[border-radius](#propdef-border-radius) can apply

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

see individual properties

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

see individual properties

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

see individual properties

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

The [corner-shape](#propdef-corner-shape) property specifies the shape of the
box's corners, within the region specified by
[border-radius](#propdef-border-radius). The four values set the top,
right, bottom and left shape, respectively. A missing left is the same
as right, a missing bottom is the same as top, and a missing right is
also the same as top.

### 3.9. Corner Sizing & Shaping Shorthands: the [corner and [corner-\*] shorthand properties]
#### 3.9.1. Sizing & shaping a corner: The [corner-top-left, [corner-top-right](#propdef-corner-top-right), [corner-bottom-right](#propdef-corner-bottom-right), [corner-bottom-left](#propdef-corner-bottom-left), [corner-start-start](#propdef-corner-start-start), [corner-start-end](#propdef-corner-start-end), [corner-end-start](#propdef-corner-end-start), [corner-end-end](#propdef-corner-end-end) shorthands]
Name:

[corner-top-left],
[corner-top-right],
[corner-bottom-left],
[corner-bottom-right],
[corner-start-start],
[corner-start-end],
[corner-end-start], [corner-end-end]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<\'corner-top-left-shape\'\>](#propdef-corner-top-left-shape)
[\|\|](https://www.w3.org/TR/css-values-4/#comb-any)
[\<\'border-top-left-radius\'\>](#propdef-border-top-left-radius)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

0

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

all elements (but see prose)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

Refer to corresponding dimension of the [border
box](https://www.w3.org/TR/css-box-4/#border-box).

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

see individual properties

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

see individual properties

The [corner-\*-\*] shorthands set the two
[corner-\*-\*-shape] and [border-\*-\*-radius] longhand
properties of the related side. See the corresponding
[corner-\*-\*-shape] and [border-\*-\*-radius] properties
for further details.

#### 3.9.2. Sizing & shaping rhe Corners Of One Side: The [corner-top, [corner-right](#propdef-corner-right), [corner-bottom](#propdef-corner-bottom), [corner-left](#propdef-corner-left), [corner-block-start](#propdef-corner-block-start), [corner-block-end](#propdef-corner-block-end), [corner-inline-start](#propdef-corner-inline-start), [corner-inline-end](#propdef-corner-inline-end) shorthands]
Name:

[corner-top], [corner-right],
[corner-bottom], [corner-left],
[corner-block-start],
[corner-block-end],
[corner-inline-start],
[corner-inline-end]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<\'corner-top-shape\'\>](#propdef-corner-top-shape)
[\|\|](https://www.w3.org/TR/css-values-4/#comb-any)
[\<\'border-top-radius\'\>](#propdef-border-top-radius)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

0

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

all elements (but see prose)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

Refer to corresponding dimension of the [border
box](https://www.w3.org/TR/css-box-4/#border-box).

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

see individual properties

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

see individual properties

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

The [corner-\*] shorthands set the two [corner-\*-shape]
longhand properties and two [border-\*-radius] longhand properties
of the related side. See the corresponding [corner-\*-shape] and
[border-\*-radius] properties for further details.

#### 3.9.3. Sizing & Shaping All Corners At Once: The [corner shorthand]
Name:

[corner]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<\'corner-shape\'\>](#propdef-corner-shape)
[\|\|](https://www.w3.org/TR/css-values-4/#comb-any)
[\<\'border-radius\'\>](#propdef-border-radius)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

0

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

all elements (but see prose)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

Refer to corresponding dimension of the [border
box](https://www.w3.org/TR/css-box-4/#border-box).

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

see individual properties

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

see individual properties

The [corner](#propdef-corner) shorthand sets the [corner-\*-shape] and
[border-\*-radius] longhands all together.

#### 3.9.4. Rendering [corner-shape]
When rendering elements with shaped corners, the corner curves for
[border](#propdef-border),
[outline](https://www.w3.org/TR/css-ui-4/#propdef-outline),
[box-shadow](#propdef-box-shadow),
[overflow-clip-margin](https://www.w3.org/TR/css-overflow-4/#propdef-overflow-clip-margin), etc. are offset from the element's
[outer contour](#outer-contour)
by their respective insets.

An
[element](https://dom.spec.whatwg.org/#concept-element)'s [outer contour] is the [border contour
path](#border-contour-path) given `element` and an
[edge](https://www.w3.org/TR/css-box-4/#box-box-edge) whose values are zero.

An
[element](https://dom.spec.whatwg.org/#concept-element)'s [inner contour] is the [border contour
path](#border-contour-path) given `element` and an
[edge](https://www.w3.org/TR/css-box-4/#box-box-edge) whose values are the
[used](https://www.w3.org/TR/css-cascade-5/#used-value) [border
width](#border-width-dfn).

An
[element](https://dom.spec.whatwg.org/#concept-element)'s
[border](https://www.w3.org/TR/css-box-4/#border) is rendered in the area between its [outer
contour](#outer-contour) and
its [inner contour](#inner-contour).

An
[element](https://dom.spec.whatwg.org/#concept-element)'s
[outline](https://www.w3.org/TR/CSS2/ui.html#x2) follows the [outer
contour](#outer-contour) with
the
[used](https://www.w3.org/TR/css-cascade-5/#used-value)
[outline-width](https://www.w3.org/TR/css-ui-4/#propdef-outline-width) and
[outline-offset](https://www.w3.org/TR/css-ui-4/#propdef-outline-offset). The precise way in which it is
rendered is implementation-defined.

An
[element](https://dom.spec.whatwg.org/#concept-element)'s
[overflow](https://www.w3.org/TR/css-overflow-3/#overflow) area is shaped by its [inner
contour](#inner-contour).

An
[element](https://dom.spec.whatwg.org/#concept-element)'s [overflow clip
edge](https://www.w3.org/TR/css-overflow-4/#overflow-clip-edge) is shaped by the [border contour
path](#border-contour-path) given `element`, and the [inset
between](#inset-between-two-edges) `element`'s [border
edge](https://www.w3.org/TR/css-box-4/#border-edge) and [overflow clip edge].

Each shadow of
[element](https://dom.spec.whatwg.org/#concept-element)'s
[box-shadow](#propdef-box-shadow) is shaped by the [border contour
path](#border-contour-path) given `element`, and the [inset
between](#inset-between-two-edges) `element`'s [border
edge](https://www.w3.org/TR/css-box-4/#border-edge) and shadow's edge.

The [inset between two edges], given
[edges](https://www.w3.org/TR/css-box-4/#box-box-edge) `originalEdge` and `targetEdge`,
is an [edge] whose values are the signed insets
from `originalEdge` to `targetEdge`, positive
inward and negative outward.

##### 3.9.4.1. Vector Math Helpers

A [two-dimensional vector] is a pair of numbers (x, y).

A [point extended by vectors] given a
[`DOMPointReadOnly`](https://www.w3.org/TR/geometry-1/#dompointreadonly) `p` and a
[list](https://infra.spec.whatwg.org/#list) of [two-dimensional
vector](#two-dimensional-vector)s `vectors`:

1. Let `x` be `p`'s
 [`x`](https://www.w3.org/TR/geometry-1/#dom-dompointreadonly-x).

2. Let `y` be `p`'s
 [`y`](https://www.w3.org/TR/geometry-1/#dom-dompointreadonly-y).

3. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `v` in `vectors`:

 1. Increment `x` by `v`\[0\];

 2. Increment `y` by `v`\[1\];

4. Return a new
 [`DOMPointReadOnly`](https://www.w3.org/TR/geometry-1/#dompointreadonly) whose
 [`x`](https://www.w3.org/TR/geometry-1/#dom-dompointreadonly-x) is `x` and whose
 [`y`](https://www.w3.org/TR/geometry-1/#dom-dompointreadonly-y) is `y`.

To [scale] a
[two-dimensional
vector](#two-dimensional-vector) `v` by a number `factor`, return
`(``v``[0] ⋅ ``factor``, ``v``[1] ⋅ ``factor``)`.

To [normalize] a
[two-dimensional
vector](#two-dimensional-vector) `v`:

1. Let `l` be
 `hypot(``v``[0], ``v``[1])`.

2. If `l` is 0, return `v`.

3. Return
 `(``v``[0] / ``l``, ``v``[1] / ``l``)`.

The [perpendicular] of a [two-dimensional
vector](#two-dimensional-vector) `v` is
`(-``v``[1], ``v``[0])`.

The [vector between two points], given
[`DOMPoint`](https://www.w3.org/TR/geometry-1/#dompoint)s `a` and `b`, is
`(``b``’s `[`x`](https://www.w3.org/TR/geometry-1/#dom-dompointreadonly-x)` - ``a``’s `[`x`](https://www.w3.org/TR/geometry-1/#dom-dompointreadonly-x)`, ``b``’s `[`y`](https://www.w3.org/TR/geometry-1/#dom-dompointreadonly-y)` - ``a``’s `[`y`](https://www.w3.org/TR/geometry-1/#dom-dompointreadonly-y)`)`.

To [sum] a
[list](https://infra.spec.whatwg.org/#list) of [two-dimensional
vector](#two-dimensional-vector)s `vectors`:

1. Let `x` be `0`.

2. Let `y` be `0`.

3. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `v` in `vectors`:

 1. Increment `x` by `v`\[0\];

 2. Increment `y` by `v`\[1\];

4. Return `(``x``, ``y``)`.

The [dot product] of [two-dimensional
vector](#two-dimensional-vector)s `a` and `b`, is
`a``[0] ⋅ ``b``[0] + ``a``[1] ⋅ ``b``[1]`.

##### 3.9.4.2. Computing a contoured path

This algorithm describes how to compute a path with shaped corners. To
avoid the complexities of defining how superellipses intersect, the
algorithm simplifies the process by specifying that each corner is
\"clipped out\" of the path. The specific implementation details of this
clipping operation are left to implementations.

To compute the [border contour path] given an
[element](https://dom.spec.whatwg.org/#concept-element) `element`, numbers `topInset`,
`rightInset`, `bottomInset`,
`leftInset`:

1. Let `borderRect` be `element`'s [border
 box](https://www.w3.org/TR/css-box-4/#border-box).

2. Let `targetRect` be `borderRect`, inset by
 `topInset`, `rightInset`,
 `bottomInset`, `leftInset`.

 If this is a shadow or
 [overflow-clip-margin](https://www.w3.org/TR/css-overflow-4/#propdef-overflow-clip-margin), the insets may have negative
 values, in which case `targetRect` would become an outset
 of `borderRect`.

3. Let `path` be a path that traces `targetRect`.

4. Let `topRightRadius` be `element`'s [used
 value](https://www.w3.org/TR/css-cascade-5/#used-value) of
 [border-top-right-radius](#propdef-border-top-right-radius).

5. Let `bottomRightRadius` be `element`'s [used
 value](https://www.w3.org/TR/css-cascade-5/#used-value) of
 [border-bottom-right-radius](#propdef-border-bottom-right-radius).

6. Let `bottomLeftRadius` be `element`'s [used
 value](https://www.w3.org/TR/css-cascade-5/#used-value) of
 [border-bottom-left-radius](#propdef-border-bottom-left-radius).

7. Let `topLeftRadius` be `element`'s [used
 value](https://www.w3.org/TR/css-cascade-5/#used-value) of
 [border-top-left-radius](#propdef-border-top-left-radius).

8. Let `adjustedInset` be the following steps, given a
 radius `radius`, and numbers `insetX` and
 `insetY`:

 1. Let `adjustedRadius` be the [outset-adjusted border
 radius](#outset-adjusted-border-radius) given `borderRect`'s size,
 `radius`, and the outset
 `(-``insetX``, -``insetY``)`.

 2. Return the inset
 `(``radius``’s `[`width`](https://www.w3.org/TR/css-sizing-3/#width)` - ``adjustedRadius``’s `[`width`]`, ``radius``’s `[`height`](https://www.w3.org/TR/css-sizing-3/#height)` - ``adjustedRadius``’s `[`height`]`)`.

9. Let `adjustedTopRightInset` be the
 `adjustedInset` given `topRightRadius`,
 `rightInset`, and `topInset`.

10. Let `adjustedBottomRightInset` be the
 `adjustedInset` given `bottomRightRadius`,
 `rightInset`, and `bottomInset`.

11. Let `adjustedBottomLeftInset` be the
 `adjustedInset` given `bottomLeftRadius`,
 `leftInset`, and `bottomInset`.

12. Let `adjustedTopLeftInset` be the
 `adjustedInset` given `topLeftRadius`,
 `leftInset`, and `topInset`.

13. Clip out from `path`, the [border-aligned corner clip-out
 path](#border-aligned-corner-clip-out-path) given `topRightRadius`'s
 [height](https://www.w3.org/TR/css-sizing-3/#height), `topRightRadius`'s
 [width](https://www.w3.org/TR/css-sizing-3/#width), `adjustedTopRightInset`'s
 [height], `adjustedTopRightInset`'s
 [width], a
 [`DOMPointReadOnly`](https://www.w3.org/TR/geometry-1/#dompointreadonly) at
 `(``targetRect``’s right, ``targetRect``’s top)`,
 `(-1, 0)`, `(0, 1)`, `element`'s
 [computed](https://www.w3.org/TR/css-cascade-5/#computed-value)
 [corner-top-right-shape](#propdef-corner-top-right-shape).

14. Clip out from `path`, the [border-aligned corner clip-out
 path](#border-aligned-corner-clip-out-path) given `bottomRightRadius`'s
 [width](https://www.w3.org/TR/css-sizing-3/#width), `bottomRightRadius`'s
 [height](https://www.w3.org/TR/css-sizing-3/#height), `adjustedBottomRightInset`'s
 [width], `adjustedBottomRightInset`'s
 [height], a
 [`DOMPointReadOnly`](https://www.w3.org/TR/geometry-1/#dompointreadonly) at
 `(``targetRect``’s right, ``targetRect``’s bottom)`,
 `(0, -1)`, `(-1, 0)`, `element`'s
 [computed](https://www.w3.org/TR/css-cascade-5/#computed-value)
 [corner-bottom-right-shape](#propdef-corner-bottom-right-shape).

15. Clip out from `path`, the [border-aligned corner clip-out
 path](#border-aligned-corner-clip-out-path) given `bottomLeftRadius`'s
 [height](https://www.w3.org/TR/css-sizing-3/#height), `bottomLeftRadius`'s
 [width](https://www.w3.org/TR/css-sizing-3/#width), `adjustedBottomLeftInset`'s
 [height], `adjustedBottomLeftInset`'s
 [width], a
 [`DOMPointReadOnly`](https://www.w3.org/TR/geometry-1/#dompointreadonly) at
 `(``targetRect``’s left, ``targetRect``’s bottom)`,
 `(1, 0)`, `(0, -1)`, `element`'s
 [computed](https://www.w3.org/TR/css-cascade-5/#computed-value)
 [corner-bottom-left-shape](#propdef-corner-bottom-left-shape).

16. Clip out from `path`, the [border-aligned corner clip-out
 path](#border-aligned-corner-clip-out-path) given `topLeftRadius`'s
 [width](https://www.w3.org/TR/css-sizing-3/#width), `topLeftRadius`'s
 [height](https://www.w3.org/TR/css-sizing-3/#height), `adjustedTopLeftInset`'s
 [width], `adjustedTopLeftInset`'s
 [height], a
 [`DOMPointReadOnly`](https://www.w3.org/TR/geometry-1/#dompointreadonly) at
 `(``targetRect``’s left, ``targetRect``’s top)`,
 `(0, 1)`, `(1, 0)`, `element`'s
 [computed](https://www.w3.org/TR/css-cascade-5/#computed-value)
 [corner-top-left-shape](#propdef-corner-top-left-shape).

17. Return `path`.

To compute the [border-aligned corner clip-out
path] given numbers `startRadius`,
`endRadius`, `startInset`, `endInset`,
a
[`DOMPointReadOnly`](https://www.w3.org/TR/geometry-1/#dompointreadonly) `targetCornerOuter`, [two-dimensional
vector](#two-dimensional-vector)s `normalizedV3`, and
`normalizedV2`, a [superellipse
parameter](#superellipse-parameter) `K`:

This algorithm uses the following vector notation to work with corners
independently of their orientation.

![The corner vector notation overlaid on the top-right
corner.](images/corner-shape-notation.svg){a
height="200" width="200"}

1. If `startRadius` or `endRadius` is zero, then
 return an empty path.

2. If `K` is ∞, then return an empty path.

3. Let `vectorToOriginalCornerOuterV3` be
 `normalizedV3`, [scaled
 by](#two-dimensional-vector-scale) `-``endInset`.

4. Let `vectorToOriginalCornerOuterV2` be
 `normalizedV2`, [scaled
 by](#two-dimensional-vector-scale) `-``startInset`.

5. Let `originalCornerOuter` be
 `targetCornerOuter`, [extended
 by](#point-extended-by-vectors) « `vectorToOriginalCornerOuterV3`,
 `vectorToOriginalCornerOuterV2` ».

6. Let `originalCornerStart` be
 `originalCornerOuter`, [extended
 by](#point-extended-by-vectors) « `normalizedV3` [scaled
 by](#two-dimensional-vector-scale) `endRadius` ».

7. Let `originalCornerEnd` be
 `originalCornerOuter`, [extended
 by](#point-extended-by-vectors) « `normalizedV2` [scaled
 by](#two-dimensional-vector-scale) `startRadius` ».

8. Let `halfCornerX` be the [normalized superellipse half
 corner](#normalized-superellipse-half-corner) given `K`.

9. Let `controlPointX` be
 `clamp(0, 1/(sqrt(2) - 1) ⋅ ``halfCornerX`` - 1/sqrt(2), 1)`.

10. Let `insetDiff` be
 `clamp(-``startRadius``, ``endInset`` - ``startInset``, ``endRadius``)`.

11. If `K` is smaller than or equal to zero, and
 `insetDiff` is equal to `-``startRadius` or
 `endRadius`, then return an empty path.

12. Let `startControlPointX` be `controlPointX`.

13. Let `endControlPointX` be `controlPointX`.

14. If `insetDiff` is not zero:

 1. Let `bevelNormalVectorX` be
 `endRadius`` ⋅ ``insetDiff`` + ``startRadius`` ⋅ sqrt(``startRadius`^`2`^` + ``endRadius`^`2`^` - ``insetDiff`^`2`^`)`.

 2. Let `bevelNormalVectorY` be
 `-``startRadius`` ⋅ ``insetDiff`` + ``endRadius`` ⋅ sqrt(``startRadius`^`2`^` + ``endRadius`^`2`^` - ``insetDiff`^`2`^`)`.

 3. Let `bevelControlPointX` be
 `(``startRadius`` ⋅ ``bevelNormalVectorY``)/(``startRadius`` ⋅ ``bevelNormalVectorY`` + ``endRadius`` ⋅ ``bevelNormalVectorX``)`.

 4. Set `startControlPointX` to
 `bevelControlPointX`` · (2 · ``controlPointX``)`
 if `K` is less than zero,
 `1 - (1 - ``bevelControlPointX``) · (2 · (1 - ``controlPointX``))`
 otherwise.

 5. Set `endControlPointX` to
 `2 ⋅ ``controlPointX`` - ``startControlPointX`.

15. Let `unmappedStartNormalVector` be the [two-dimensional
 vector](#two-dimensional-vector)
 `((1 - ``startControlPointX``) ⋅ ``startRadius``, ``startControlPointX`` ⋅ ``endRadius``)`,
 [normalized](#two-dimensional-vector-normalize).

16. Let `unmappedEndNormalVector` be the [two-dimensional
 vector](#two-dimensional-vector)
 `(``endControlPointX`` ⋅ ``startRadius``, (1 - ``endControlPointX``) ⋅ ``endRadius``)`,
 [normalized](#two-dimensional-vector-normalize).

17. Let `startNormalVector` be the
 [sum](#two-dimensional-vector-list-sum) of « `normalizedV3` [scaled
 by](#two-dimensional-vector-scale) `unmappedStartNormalVector`\[0\],
 `normalizedV2` [scaled
 by]
 `unmappedStartNormalVector`\[1\] ».

18. Let `endNormalVector` be the
 [sum](#two-dimensional-vector-list-sum) of « `normalizedV3` [scaled
 by](#two-dimensional-vector-scale) `unmappedEndNormalVector`\[0\],
 `normalizedV2` [scaled
 by]
 `unmappedEndNormalVector`\[1\] ».

19. Let `adjustedCornerStart` be
 `originalCornerStart`, [extended
 by](#point-extended-by-vectors) « `startNormalVector` [scaled
 by](#two-dimensional-vector-scale) `startInset` ».

20. Let `adjustedCornerEnd` be
 `originalCornerEnd`, [extended
 by](#point-extended-by-vectors) « `endNormalVector` [scaled
 by](#two-dimensional-vector-scale) `endInset` ».

21. Let `startTangentVector` be the
 [perpendicular](#two-dimensional-vector-perpendicular) of `startNormalVector`, [scaled
 by](#two-dimensional-vector-scale) -1.

22. Let `endTangentVector` be the
 [perpendicular](#two-dimensional-vector-perpendicular) of `endNormalVector`.

23. Let `miterStart` be `adjustedCornerStart`.

24. Let `miterEnd` be `adjustedCornerEnd`.

25. If `startInset` is less than zero:

 1. Let `clipStart` be `targetCornerOuter`,
 [extended
 by](#point-extended-by-vectors) « `normalizedV3` ».

 2. Set `miterStart` to the intersection between the
 lines
 `(``adjustedCornerStart``, ``adjustedCornerStart`` `[`extended by`](#point-extended-by-vectors)` « ``startTangentVector`` »)` and
 `(``clipStart``, ``targetCornerOuter``)`.
 If the lines are parallel, let it be
 `adjustedCornerStart`.

 3. If `K` is greater than or equal to zero, set
 `adjustedCornerStart` to `miterStart`.

26. If `endInset` is less than zero:

 1. Let `clipEnd` be `targetCornerOuter`,
 [extended
 by](#point-extended-by-vectors) « `normalizedV2` ».

 2. Set `miterEnd` to the intersection between the lines
 `(``adjustedCornerEnd``, ``adjustedCornerEnd`` `[`extended by`](#point-extended-by-vectors)` « ``endTangentVector`` »)` and
 `(``clipEnd``, ``targetCornerOuter``)`. If
 the lines are parallel, let it be
 `adjustedCornerEnd`.

 3. If `K` is greater than or equal to zero, set
 `adjustedCornerEnd` to `miterEnd`.

27. Let `adjustedCornerDiagonalVector` be the [vector
 between](#vector-between-two-points) `adjustedCornerStart` and
 `adjustedCornerEnd`.

28. Let `adjustedCornerHeight` be the [dot
 product](#dot-product) of
 `adjustedCornerDiagonalVector` and
 `normalizedV2`.

29. Let `adjustedCornerOuter` be
 `adjustedCornerEnd`, [extended
 by](#point-extended-by-vectors) « `normalizedV2` [scaled
 by](#two-dimensional-vector-scale) `-``adjustedCornerHeight` ».

30. Let `adjustedCornerCenter` be
 `adjustedCornerStart`, [extended
 by](#point-extended-by-vectors) « `normalizedV2` [scaled
 by](#two-dimensional-vector-scale) `adjustedCornerHeight` ».

31. Let `mapPointToCorner` be the following steps, given
 numbers `x` and `y`,
 [`DOMPointReadOnly`](https://www.w3.org/TR/geometry-1/#dompointreadonly) `start`, `end`, and
 `center`:

 1. Let `v1` be [the vector
 between](#vector-between-two-points) `center` and `end`,
 [scaled
 by](#two-dimensional-vector-scale) `x`.

 2. Let `v4` be [the vector
 between](#vector-between-two-points) `center` and `start`,
 [scaled
 by](#two-dimensional-vector-scale) `y`.

 3. Return `center`, [extended
 by](#point-extended-by-vectors) « `v1`, `v4` ».

32. Let `selfIntersection` be undefined.

33. If `K`, `startInset`, and
 `endInset` are less than zero:

 1. If `-``endInset` is greater than or equal to
 `startRadius`:

 1. Set `selfIntersection` to the intersection
 between the segment
 `(``miterStart``, ``adjustedCornerStart``)`
 and the line
 `(``miterEnd``, ``adjustedCornerEnd``)`.

 2. If `-``startInset` is greater than or equal to
 `endRadius`, and `selfIntersection` is
 undefined:

 1. Set `selfIntersection` to the intersection
 between the segment
 `(``miterEnd``, ``adjustedCornerEnd``)`
 and the line
 `(``miterStart``, ``adjustedCornerStart``)`.

34. Let `path` be a path, starting at
 `miterStart`.

35. If `selfIntersection` is a defined point:

 1. Extend `path` to `selfIntersection`.

36. Otherwise, if `K` is -∞:

 1. Extend `path` to `adjustedCornerCenter`.

37. Otherwise, if `K` is greater than zero or less than or
 equal to -1:

 1. Let `n` be `2`^`abs(``K``)`^.

 2. Let `curveCenter` be `adjustedCornerOuter`
 if `K` is less than zero,
 `adjustedCornerCenter` otherwise.

 3. For every `T` between 0 and 1, in an
 [implementation-approximated](https://tc39.es/ecma262/multipage/overview.html#implementation-approximated) manner, extend `path` to the result
 of calling `mapPointToCorner` given
 `T`^`1/``n`^ and
 `(1 - ``T``)`^`1/``n`^,
 `adjustedCornerStart`,
 `adjustedCornerEnd`, and `curveCenter`.

38. Otherwise, if `K` is greater than -1 and less than zero:

 1. Let `tangentIntersection` be the intersection between
 the lines
 `(``adjustedCornerStart``, ``adjustedCornerStart`` `[`extended by`](#point-extended-by-vectors)` « ``startTangentVector`` »)` and
 `(``adjustedCornerEnd``, ``adjustedCornerEnd`` `[`extended by`](#point-extended-by-vectors)` « ``endTangentVector`` »)`. If the
 lines are parallel, let it be `adjustedCornerStart`.

 2. For every `T` between 0 and 1, in an
 [implementation-approximated](https://tc39.es/ecma262/multipage/overview.html#implementation-approximated) manner, extend `path` to the result
 of calling `mapPointToCorner` given
 `1 - (1 - ``T``)`^`1/2`^ and
 `1 - ``T`^`1/2`^, `adjustedCornerStart`,
 `adjustedCornerEnd`, and
 `tangentIntersection`.

39. Extend `path` to `miterEnd`.

40. Return `path`.

- [corners-invalid.html](https://wpt.fyi/results/css/css-borders/corner-shape/corners-invalid.html "css/css-borders/corner-shape/corners-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-borders/corner-shape/corners-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-borders/corner-shape/corners-invalid.html)

#### 3.9.5. Constraining opposite radii

When concave
[corner-shape](#propdef-corner-shape) values are present (the
[superellipse
parameter](#superellipse-parameter) is negative), diagonally opposite corners might overlap
each other.

The following example would create overlapping corners if not
constrained.

```
div {
 corner-shape: scoop;
 border-top-left-radius: 80%;
 border-bottom-right-radius: 80%;
}
```

To prevent this, the four radii are constrained to prevent overlaps.
This is done by computing a hull polygon for each of the opposite
corners, and finding the highest downscale factor which, if applied to
both corners, would make it so that the polygons would not intersect.
The used values of all border radii must be proportionally reduced by
multiplying them by the minimum of the [opposite corner scale
factor](#opposite-corner-scale-factor) and the [adjacent corner scale
factor](#adjacent-corner-scale-factor).

To compute the [opposite corner scale
factor] given an
[element](https://dom.spec.whatwg.org/#concept-element) `element`:

1. Let `rect` be `element`'s [border
 box](https://www.w3.org/TR/css-box-4/#border-box).

2. Let `topRightRadius` be `element`'s [computed
 value](https://www.w3.org/TR/css-cascade-5/#computed-value) of
 [border-top-right-radius](#propdef-border-top-right-radius).

3. Let `bottomRightRadius` be `element`'s
 [computed
 value](https://www.w3.org/TR/css-cascade-5/#computed-value) of
 [border-bottom-right-radius](#propdef-border-bottom-right-radius).

4. Let `bottomLeftRadius` be `element`'s
 [computed
 value](https://www.w3.org/TR/css-cascade-5/#computed-value) of
 [border-bottom-left-radius](#propdef-border-bottom-left-radius).

5. Let `topLeftRadius` be `element`'s [computed
 value](https://www.w3.org/TR/css-cascade-5/#computed-value) of
 [border-top-left-radius](#propdef-border-top-left-radius).

6. Let `unmappedTopRightHull` be the [normalized inner
 corner
 hull](#normalized-inner-corner-hull) given `element`'s
 [computed](https://www.w3.org/TR/css-cascade-5/#computed-value)
 [corner-top-right-shape](#propdef-corner-top-right-shape).

7. Let `unmappedBottomRightHull` be a the [normalized inner
 corner
 hull](#normalized-inner-corner-hull) given `element`'s
 [computed](https://www.w3.org/TR/css-cascade-5/#computed-value)
 [corner-bottom-right-shape](#propdef-corner-bottom-right-shape).

8. Let `unmappedBottomLeftHull` be a the [normalized inner
 corner
 hull](#normalized-inner-corner-hull) given `element`'s
 [computed](https://www.w3.org/TR/css-cascade-5/#computed-value)
 [corner-bottom-left-shape](#propdef-corner-bottom-left-shape).

9. Let `unmappedTopLeftHull` be a the [normalized inner
 corner
 hull](#normalized-inner-corner-hull) given `element`'s
 [computed](https://www.w3.org/TR/css-cascade-5/#computed-value)
 [corner-top-left-shape](#propdef-corner-top-left-shape).

10. Let `mapPolygonToCorner` be the following steps, given a
 [list](https://infra.spec.whatwg.org/#list) of
 [`DOMPointReadOnly`](https://www.w3.org/TR/geometry-1/#dompointreadonly) `polygon`,
 [`DOMPointReadOnly`](https://www.w3.org/TR/geometry-1/#dompointreadonly) `start`, `end`, and
 `center`:

 1. Let `mappedPolygon` be an empty
 [list](https://infra.spec.whatwg.org/#list).

 2. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `p` in `polygon`:

 1. Let `v1` be [the vector
 between](#vector-between-two-points) `center` and `end`,
 [scaled
 by](#two-dimensional-vector-scale) `p`'s
 [`x`](https://www.w3.org/TR/geometry-1/#dom-dompointreadonly-x).

 2. Let `v4` be [the vector
 between](#vector-between-two-points) `center` and `start`,
 [scaled
 by](#two-dimensional-vector-scale) `p`'s
 [`y`](https://www.w3.org/TR/geometry-1/#dom-dompointreadonly-y).

 3. Let `mappedPoint` be `center`,
 [extended
 by](#point-extended-by-vectors) « `v1`, `v4` ».

 4. [Append](https://infra.spec.whatwg.org/#list-append) `mappedPoint` to
 `mappedPolygon`.

 3. Return `mappedPolygon`.

11. Let `topRightHull` be `mapPolygonToCorner`
 given `unmappedTopRightHull`,
 [`DOMPointReadOnly`](https://www.w3.org/TR/geometry-1/#dompointreadonly) at
 `(``rect``’s `[`width dimension`](https://www.w3.org/TR/geometry-1/#rectangle-width-dimension)` - ``topRightRadius``’s `[`width`](https://www.w3.org/TR/css-sizing-3/#width)`, 0)`, at
 `(``rect``’s `[`width dimension`](https://www.w3.org/TR/geometry-1/#rectangle-width-dimension)`, ``topRightRadius``’s `[`height`](https://www.w3.org/TR/css-sizing-3/#height)`)`, and at
 `(``rect``’s `[`width dimension`](https://www.w3.org/TR/geometry-1/#rectangle-width-dimension)` - ``topRightRadius``’s `[`width`](https://www.w3.org/TR/css-sizing-3/#width)`, ``topRightRadius``’s `[`height`](https://www.w3.org/TR/css-sizing-3/#height)`)`.

12. Let `bottomRightHull` be `mapPolygonToCorner`
 given `unmappedBottomRightHull`,
 [`DOMPointReadOnly`](https://www.w3.org/TR/geometry-1/#dompointreadonly) at
 `(``rect``’s `[`width dimension`](https://www.w3.org/TR/geometry-1/#rectangle-width-dimension)`, ``rect``’s `[`height dimension`](https://www.w3.org/TR/geometry-1/#rectangle-height-dimension)` - ``bottomRightRadius``’s `[`height`](https://www.w3.org/TR/css-sizing-3/#height)`)`, at
 `(``rect``’s `[`width dimension`](https://www.w3.org/TR/geometry-1/#rectangle-width-dimension)` - ``bottomRightRadius``’s `[`width`](https://www.w3.org/TR/css-sizing-3/#width)`, ``rect``’s `[`height dimension`](https://www.w3.org/TR/geometry-1/#rectangle-height-dimension)`)`, and at
 `(``rect``’s `[`width dimension`](https://www.w3.org/TR/geometry-1/#rectangle-width-dimension)` - ``bottomRightRadius``’s `[`width`](https://www.w3.org/TR/css-sizing-3/#width)`, ``rect``’s `[`height dimension`](https://www.w3.org/TR/geometry-1/#rectangle-height-dimension)` - ``bottomRightRadius``’s `[`height`](https://www.w3.org/TR/css-sizing-3/#height)`)`.

13. Let `bottomLeftHull` be `mapPolygonToCorner`
 given `unmappedBottomLeftHull`,
 [`DOMPointReadOnly`](https://www.w3.org/TR/geometry-1/#dompointreadonly) at
 `(``bottomLeftRadius``’s `[`width`](https://www.w3.org/TR/css-sizing-3/#width)`, ``rect``’s `[`height dimension`](https://www.w3.org/TR/geometry-1/#rectangle-height-dimension)`)`, at
 `(0, ``rect``’s `[`height dimension`](https://www.w3.org/TR/geometry-1/#rectangle-height-dimension)` - ``bottomLeftRadius``’s `[`height`](https://www.w3.org/TR/css-sizing-3/#height)`)`, and at
 `(``bottomLeftRadius``’s `[`width`](https://www.w3.org/TR/css-sizing-3/#width)`, ``rect``’s `[`height dimension`](https://www.w3.org/TR/geometry-1/#rectangle-height-dimension)` - ``bottomLeftRadius``’s `[`height`](https://www.w3.org/TR/css-sizing-3/#height)`)`.

14. Let `topLeftHull` be `mapPolygonToCorner`
 given `unmappedTopLeftHull`,
 [`DOMPointReadOnly`](https://www.w3.org/TR/geometry-1/#dompointreadonly) at
 `(0, ``topLeftRadius``’s `[`height`](https://www.w3.org/TR/css-sizing-3/#height)`)`, at
 `(``topLeftRadius``’s `[`width`](https://www.w3.org/TR/css-sizing-3/#width)`, 0)`, and at
 `(``topLeftRadius``’s `[`width`](https://www.w3.org/TR/css-sizing-3/#width)`, ``topLeftRadius``’s `[`height`](https://www.w3.org/TR/css-sizing-3/#height)`)`.

15. Let `scaleFactorA` be the highest number which, if both
 `topLeftHull` and `bottomRightHull` were
 scaled by, using their first point as the origin, those polygons
 would not intersect.

16. Let `scaleFactorB` be the highest number which, if both
 `topRightHull` and `bottomLeftHull` were
 scaled by, using their first point as the origin, those polygons
 would not intersect.

17. Return
 `min(1, ``scaleFactorA``, ``scaleFactorB``)`.

To compute the [normalized inner corner
hull] given a [superellipse
parameter](#superellipse-parameter) `K`:

1. If `K` is greater than or equal to zero, return a
 triangle between the points « (1, 1), (1, 0), (0, 1) ».

2. Let `v4Line` be the line through the points `(0, 0)` and
 `(0, 1)`.

3. Let `v3Line` be the line through the points `(0, 0)` and
 `(1, 0)`.

4. Let `halfCornerX` be the [normalized superellipse half
 corner](#normalized-superellipse-half-corner) given `K`.

5. Let `halfCornerPoint` be a point at
 `(``halfCornerX``, ``halfCornerX``)`.

6. Let `diagonalLine` be the line through the points
 `(0, 0)` and `(1, 1)`.

7. Let `tangentLine` be the line perpendicular to
 `diagonalLine`, at `halfCornerPoint`.

8. Let `v4Intersection` be the intersection between
 `v4Line` and `tangentLine`.

9. Let `v3Intersection` be the intersection between
 `v3Line` and `tangentLine`.

10. Return a pentagon between the points « (1, 1), (1, 0),
 `v3Intersection`, `v4Intersection`, (0, 1) ».

#### 3.9.6. Interpolating corner shapes

Since a
[\<corner-shape-value\>](#typedef-corner-shape-value) can always be expressed by a
[superellipse()](#funcdef-superellipse) with an [superellipse
parameter](#superellipse-parameter) variable, interpolating between two
[\<corner-shape-value\>]s is done by interpolating the [superellipse
parameter] itself. Since the bevel,
round, and straight corner shapes correspond to parameter values of 0,
1, and infinity, respectively, interpolating between them linearly would
make the transition from a bevel to a straight corner shape appear to
start very quickly and slow down toward the end. To balance that, the
[superellipse interpolation] formula describes how a
[superellipse parameter] is converted
to a value between 0 and 1, and vice versa:

To compute the [normalized superellipse half
corner] given a [superellipse
parameter](#superellipse-parameter) `K`, return the first matching statement,
switching on `K`:

-∞

: Return 0.

∞

: Return 1.

Otherwise

: 1. Let `n` be `2`^`abs(``K``)`^.

 2. Let `convexHalfCorner` be `0.5`^`1/``n`^.

 3. If `K` is less than 0, return
 `1 - ``convexHalfCorner`.

 4. Return `convexHalfCorner`.

To interpolate a [superellipse
parameter](#superellipse-parameter) `K` to an interpolation value between 0 and
1, return the [normalized superellipse half
corner](#normalized-superellipse-half-corner) given `K`.

To convert a [\<number
\[0,1\]\>](https://www.w3.org/TR/css-values-4/#number-value) `interpolationValue` back
to a [superellipse
parameter](#superellipse-parameter), switch on `interpolationValue`:

0

: Return -∞.

0.5

: Return 0.

1

: Return ∞.

Otherwise

: 1. Let `convexHalfCorner` be
 `interpolationValue`.

 2. If `interpolationValue` is less than 0.5, set
 `convexHalfCorner` to
 `1 - ``interpolationValue`.

 3. Let `n` be
 `ln(0.5) / ln(``convexHalfCorner``)`.

 4. Let `K` be `log2(``n``)`.

 5. If `interpolationValue` is less than 0.5, return
 -`K`.

 6. Return `K`.

- [corner-shape-interpolation.html](https://wpt.fyi/results/css/css-borders/corner-shape/corner-shape-interpolation.html "css/css-borders/corner-shape/corner-shape-interpolation.html")
 [[(live
 test)]](http://wpt.live/css/css-borders/corner-shape/corner-shape-interpolation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-borders/corner-shape/corner-shape-interpolation.html)

## 4. Border Images

Authors can specify an image to be used in place of the border styles.
In this case, the border's design is taken from the sides and corners of
an image specified with
[border-image-source](#propdef-border-image-source), whose pieces may be sliced,
scaled, and stretched in various ways to fit the size of the [border
image area](#border-image-area). The border-image properties do not affect layout:
layout of the box, its content, and surrounding content is based on the
[border-width](#propdef-border-width) and
[border-style](#propdef-border-style) properties only.

This example creates a top and bottom
border consisting of a whole number of orange diamonds and a left and
right border of a single, stretched diamond. The corners are diamonds of
a different color. The image to tile is as follows. Apart from the
diamonds, it is transparent:

![Tile for border](images/border.png){height="81" width="81"}

The image is 81 by 81 pixels and has to be divided into 9 equal parts.
The style rules could thus be as follows:

 DIV {
 border: double orange 1em;
 border-image: url("border.png") 27 round stretch;
 }

The result, when applied to a DIV of 12 by 5em, will be similar to this:

![Element with a diamond border](images/borderresult.png){height="116"
width="239"}

This shows a more complicated example,
demonstrating how the border image corresponds to the fallback
border-style but can also extend beyond the border area. The border
image is a wavy green border with an extended corner effect:

![The
[border-image-source](#propdef-border-image-source) image, with the four
[border-image-slice](#propdef-border-image-slice) cuts at 124px dividing the image
into nine
parts.](images/groovy-border-image-slice.png){a
height="375" width="396"}

The rest of the border properties then interact to lay out the tiles as
follows:

![Diagram of all border-image properties and how they interact, and
showing the rendering with and without the border-image in
effect.](images/border-image.png){a
height="537" width="452"}

Here, even though the
[border-width](#propdef-border-width) is 12px, the
[border-image-width](#propdef-border-image-width) property computes to 124px. The
[border image area](#border-image-area) is then outset 31px from the [border
box](https://www.w3.org/TR/css-box-4/#border-box) and into the [margin
area](https://www.w3.org/TR/css-box-4/#margin-area). If the border-image fails to load (or if border images
are not supported by the UA), the fallback rendering uses a green double
border.

Notice that the
[border](#propdef-border) shorthand resets
[border-image](#propdef-border-image). This makes it easy to turn off or
reset all border effects:

 .notebox {
 border: double orange;
 /* must set 'border' shorthand first, otherwise it erases 'border-image' */
 border-image: url("border.png") 30 round;
 /* but other 'border' properties can be set after */
 border-width: thin thick;
 }
 ...
 .sidebar .notebox {
 box-shadow: 0 0 5px gray;
 border-radius: 5px;
 border: none; /* turn off all borders */
 /* 'border' shorthand resets 'border-image' */
 }

### 4.1. Image Source: the [border-image-source property]
Name:

[border-image-source]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

none
[\|](https://www.w3.org/TR/css-values-4/#comb-one)
[\<image\>](https://www.w3.org/TR/css-images-3/#typedef-image)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

none

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

All elements, except internal table elements when
[border-collapse](https://www.w3.org/TR/CSS2/tables.html#propdef-border-collapse) is [collapse]

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

N/A

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

the keyword [none] or the computed
[\<image\>](https://www.w3.org/TR/css-images-3/#typedef-image)

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

Tests

- [border-image-source-interpolation.html](https://wpt.fyi/results/css/css-backgrounds/animations/border-image-source-interpolation.html "css/css-backgrounds/animations/border-image-source-interpolation.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/animations/border-image-source-interpolation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/animations/border-image-source-interpolation.html)
- [css3-border-image-source.html](https://wpt.fyi/results/css/css-backgrounds/css3-border-image-source.html "css/css-backgrounds/css3-border-image-source.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/css3-border-image-source.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/css3-border-image-source.html)
- [border-image-source-computed.sub.html](https://wpt.fyi/results/css/css-backgrounds/parsing/border-image-source-computed.sub.html "css/css-backgrounds/parsing/border-image-source-computed.sub.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/parsing/border-image-source-computed.sub.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/parsing/border-image-source-computed.sub.html)
- [border-image-source-invalid.html](https://wpt.fyi/results/css/css-backgrounds/parsing/border-image-source-invalid.html "css/css-backgrounds/parsing/border-image-source-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/parsing/border-image-source-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/parsing/border-image-source-invalid.html)
- [border-image-source-valid.html](https://wpt.fyi/results/css/css-backgrounds/parsing/border-image-source-valid.html "css/css-backgrounds/parsing/border-image-source-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/parsing/border-image-source-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/parsing/border-image-source-valid.html)

Specifies an image to use as a border in place of the rendering
specified by the
[border-style](#propdef-border-style) properties and, if given the
[fill](#border-image-slice-fill) keyword in
[border-image-slice](#propdef-border-image-slice), as an additional image backdrop
for the element. If the value is [none] or if the image cannot be
displayed (or the property doesn't apply), the border styles will be
used; otherwise the element's
[border-style] borders are
not drawn and this [border image] is drawn as described in the sections below.

### 4.2. Image Slicing: the [border-image-slice property]
Name:

[border-image-slice]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

\[[\<number
\[0,∞\]\>](https://www.w3.org/TR/css-values-4/#number-value)
[\|](https://www.w3.org/TR/css-values-4/#comb-one) [\<percentage
\[0,∞\]\>](https://www.w3.org/TR/css-values-4/#percentage-value)\][{1,4}](https://www.w3.org/TR/css-values-4/#mult-num-range)
[&&](https://www.w3.org/TR/css-values-4/#comb-all)
fill[?](https://www.w3.org/TR/css-values-4/#mult-opt)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

100%

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

All elements, except internal table elements when
[border-collapse](https://www.w3.org/TR/CSS2/tables.html#propdef-border-collapse) is [collapse]

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

refer to size of the border image

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

four values, each either a number or percentage; plus a
[fill](#border-image-slice-fill) keyword if specified

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value

Tests

- [border-image-slice-composition.html](https://wpt.fyi/results/css/css-backgrounds/animations/border-image-slice-composition.html "css/css-backgrounds/animations/border-image-slice-composition.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/animations/border-image-slice-composition.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/animations/border-image-slice-composition.html)
- [border-image-slice-interpolation-stability.html](https://wpt.fyi/results/css/css-backgrounds/animations/border-image-slice-interpolation-stability.html "css/css-backgrounds/animations/border-image-slice-interpolation-stability.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/animations/border-image-slice-interpolation-stability.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/animations/border-image-slice-interpolation-stability.html)
- [border-image-slice-interpolation.html](https://wpt.fyi/results/css/css-backgrounds/animations/border-image-slice-interpolation.html "css/css-backgrounds/animations/border-image-slice-interpolation.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/animations/border-image-slice-interpolation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/animations/border-image-slice-interpolation.html)
- [border-image-slice-001.xht](https://wpt.fyi/results/css/css-backgrounds/border-image-slice-001.xht "css/css-backgrounds/border-image-slice-001.xht")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-image-slice-001.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-image-slice-001.xht)
- [border-image-slice-002.xht](https://wpt.fyi/results/css/css-backgrounds/border-image-slice-002.xht "css/css-backgrounds/border-image-slice-002.xht")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-image-slice-002.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-image-slice-002.xht)
- [border-image-slice-003.xht](https://wpt.fyi/results/css/css-backgrounds/border-image-slice-003.xht "css/css-backgrounds/border-image-slice-003.xht")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-image-slice-003.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-image-slice-003.xht)
- [border-image-slice-004.htm](https://wpt.fyi/results/css/css-backgrounds/border-image-slice-004.htm "css/css-backgrounds/border-image-slice-004.htm")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-image-slice-004.htm)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-image-slice-004.htm)
- [border-image-slice-005.htm](https://wpt.fyi/results/css/css-backgrounds/border-image-slice-005.htm "css/css-backgrounds/border-image-slice-005.htm")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-image-slice-005.htm)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-image-slice-005.htm)
- [border-image-slice-006.htm](https://wpt.fyi/results/css/css-backgrounds/border-image-slice-006.htm "css/css-backgrounds/border-image-slice-006.htm")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-image-slice-006.htm)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-image-slice-006.htm)
- [border-image-slice-007.htm](https://wpt.fyi/results/css/css-backgrounds/border-image-slice-007.htm "css/css-backgrounds/border-image-slice-007.htm")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-image-slice-007.htm)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-image-slice-007.htm)
- [border-image-slice-fill-001.html](https://wpt.fyi/results/css/css-backgrounds/border-image-slice-fill-001.html "css/css-backgrounds/border-image-slice-fill-001.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-image-slice-fill-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-image-slice-fill-001.html)
- [border-image-slice-fill-002.html](https://wpt.fyi/results/css/css-backgrounds/border-image-slice-fill-002.html "css/css-backgrounds/border-image-slice-fill-002.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-image-slice-fill-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-image-slice-fill-002.html)
- [border-image-slice-fill-003.html](https://wpt.fyi/results/css/css-backgrounds/border-image-slice-fill-003.html "css/css-backgrounds/border-image-slice-fill-003.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-image-slice-fill-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-image-slice-fill-003.html)
- [border-image-slice-percentage.html](https://wpt.fyi/results/css/css-backgrounds/border-image-slice-percentage.html "css/css-backgrounds/border-image-slice-percentage.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-image-slice-percentage.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-image-slice-percentage.html)
- [border-image-slice-shorthand-reset.html](https://wpt.fyi/results/css/css-backgrounds/border-image-slice-shorthand-reset.html "css/css-backgrounds/border-image-slice-shorthand-reset.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-image-slice-shorthand-reset.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-image-slice-shorthand-reset.html)
- [border-image-slice-computed.html](https://wpt.fyi/results/css/css-backgrounds/parsing/border-image-slice-computed.html "css/css-backgrounds/parsing/border-image-slice-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/parsing/border-image-slice-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/parsing/border-image-slice-computed.html)
- [border-image-slice-invalid.html](https://wpt.fyi/results/css/css-backgrounds/parsing/border-image-slice-invalid.html "css/css-backgrounds/parsing/border-image-slice-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/parsing/border-image-slice-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/parsing/border-image-slice-invalid.html)
- [border-image-slice-valid.html](https://wpt.fyi/results/css/css-backgrounds/parsing/border-image-slice-valid.html "css/css-backgrounds/parsing/border-image-slice-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/parsing/border-image-slice-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/parsing/border-image-slice-valid.html)

This property specifies inward offsets from the top, right, bottom, and
left edges of the image, dividing it into nine regions: four corners,
four edges and a middle. The middle image part is discarded (treated as
fully transparent) unless the
[fill](#border-image-slice-fill) keyword is present. (It is drawn over the background;
see [Drawing the Border Image](#border-image-process).)

If there is only one component value, it applies to all sides. If there
are two values, the top and bottom are set to the first value and the
right and left are set to the second. If there are three values, the top
is set to the first value, the left and right are set to the second, and
the bottom is set to the third. If there are four values they apply to
the top, right, bottom, and left, respectively.

[[\<percentage \[0,∞\]\>](https://www.w3.org/TR/css-values-4/#percentage-value)]
: Percentages are relative to the size of the image: the width of the
 image for the horizontal offsets, the height for vertical offsets.

[[\<number \[0,∞\]\>](https://www.w3.org/TR/css-values-4/#number-value)]
: Numbers represent pixels in the image (if the image is a raster
 image) or vector coordinates (if the image is a vector image).

[fill]
: The
 [fill](#border-image-slice-fill) keyword, if present, causes the middle part
 of the border-image to be preserved. (By default it is discarded,
 i.e., treated as empty.)

Negative values are invalid. Computed values larger than the size of the
image are interpreted as [100%].

The regions given by the
[border-image-slice](#propdef-border-image-slice) values may overlap. However if the
sum of the right and left widths is equal to or greater than the width
of the image, the images for the top and bottom edge and the middle part
are empty---​which has the same effect as if a nonempty transparent image
had been specified for those parts. Analogously for the top and bottom
values.

If the image must be sized to determine the slices (for example, for SVG
images with no [natural
dimensions](https://www.w3.org/TR/css-images-3/#natural-dimensions)), then it is sized using the [default sizing
algorithm](https://www.w3.org/TR/css3-images/#default-sizing) with no
[specified
size](https://www.w3.org/TR/css-images-3/#specified-size) and the [border image
area](#border-image-area)
as the [default object
size](https://www.w3.org/TR/css-images-3/#default-object-size).

![Diagram illustrating the cuts corresponding to the value [25% 30% 12%
20%]](images/slice.png){a
height="304" width="388"}

### 4.3. Drawing Areas: the [border-image-width property]
Name:

[border-image-width]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

\[ [\<length-percentage
\[0,∞\]\>](https://www.w3.org/TR/css-values-4/#typedef-length-percentage)
[\|](https://www.w3.org/TR/css-values-4/#comb-one) [\<number
\[0,∞\]\>](https://www.w3.org/TR/css-values-4/#number-value) [\|] auto
\][{1,4}](https://www.w3.org/TR/css-values-4/#mult-num-range)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

1

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

All elements, except internal table elements when
[border-collapse](https://www.w3.org/TR/CSS2/tables.html#propdef-border-collapse) is [collapse]

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

Relative to width/height of the [border image
area](#border-image-area)

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

four values, each either a number, the keyword
[auto](#valdef-border-image-width-auto), or a computed
[\<length-percentage\>](https://www.w3.org/TR/css-values-4/#typedef-length-percentage) value

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value

Tests

- [border-image-width-001.htm](https://wpt.fyi/results/css/css-backgrounds/border-image-width-001.htm "css/css-backgrounds/border-image-width-001.htm")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-image-width-001.htm)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-image-width-001.htm)
- [border-image-width-005.xht](https://wpt.fyi/results/css/css-backgrounds/border-image-width-005.xht "css/css-backgrounds/border-image-width-005.xht")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-image-width-005.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-image-width-005.xht)
- [border-image-width-006.xht](https://wpt.fyi/results/css/css-backgrounds/border-image-width-006.xht "css/css-backgrounds/border-image-width-006.xht")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-image-width-006.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-image-width-006.xht)
- [border-image-width-007.xht](https://wpt.fyi/results/css/css-backgrounds/border-image-width-007.xht "css/css-backgrounds/border-image-width-007.xht")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-image-width-007.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-image-width-007.xht)
- [border-image-width-008.html](https://wpt.fyi/results/css/css-backgrounds/border-image-width-008.html "css/css-backgrounds/border-image-width-008.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-image-width-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-image-width-008.html)
- [border-image-width-009.html](https://wpt.fyi/results/css/css-backgrounds/border-image-width-009.html "css/css-backgrounds/border-image-width-009.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-image-width-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-image-width-009.html)
- [border-image-width-should-extend-to-padding.html](https://wpt.fyi/results/css/css-backgrounds/border-image-width-should-extend-to-padding.html "css/css-backgrounds/border-image-width-should-extend-to-padding.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-image-width-should-extend-to-padding.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-image-width-should-extend-to-padding.html)
- [border-image-width-computed.html](https://wpt.fyi/results/css/css-backgrounds/parsing/border-image-width-computed.html "css/css-backgrounds/parsing/border-image-width-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/parsing/border-image-width-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/parsing/border-image-width-computed.html)
- [border-image-width-invalid.html](https://wpt.fyi/results/css/css-backgrounds/parsing/border-image-width-invalid.html "css/css-backgrounds/parsing/border-image-width-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/parsing/border-image-width-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/parsing/border-image-width-invalid.html)
- [border-image-width-valid.html](https://wpt.fyi/results/css/css-backgrounds/parsing/border-image-width-valid.html "css/css-backgrounds/parsing/border-image-width-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/parsing/border-image-width-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/parsing/border-image-width-valid.html)

The [border image](#border-image-dfn) is drawn inside an area called the [border image
area].
This is an area whose boundaries by default correspond to the [border
box](https://www.w3.org/TR/css-box-4/#border-box), see
[border-image-outset](#propdef-border-image-outset).

The four values of
[border-image-width](#propdef-border-image-width) specify offsets that are used to
divide the [border image
area](#border-image-area)
into nine [regions].
The offsets represent inward distances from the top, right, bottom, and
left sides of the area, respectively.

If there is only one component value, it applies to all sides. If there
are two values, the top and bottom are set to the first value and the
right and left are set to the second. If there are three values, the top
is set to the first value, the left and right are set to the second, and
the bottom is set to the third. If there are four values they apply to
the top, right, bottom, and left, respectively.

Values have the following meanings:

[[\<length-percentage \[0,∞\]\>](https://www.w3.org/TR/css-values-4/#typedef-length-percentage)]
: Percentages refer to the size of the [border image
 area](#border-image-area): the width of the area for horizontal offsets, the
 height for vertical offsets.

[[\<number \[0,∞\]\>](https://www.w3.org/TR/css-values-4/#number-value)]
: Numbers represent multiples of the corresponding computed
 [border-width](#border-width).

[auto]
: If
 [auto](#valdef-border-image-width-auto) is specified then the used
 [border-image-width](#propdef-border-image-width) is the
 [natural](https://www.w3.org/TR/css-images-3/#natural-size) width or height (whichever is applicable) of the
 corresponding image slice (see
 [border-image-slice](#propdef-border-image-slice)). If the image does not have
 the required [natural
 dimension](https://www.w3.org/TR/css-images-3/#natural-dimensions) then the corresponding computed
 [border-width](#propdef-border-width) is used instead.

Negative values are invalid for any
[border-image-width](#propdef-border-image-width) values.

If two opposite
[border-image-width](#propdef-border-image-width) offsets are large enough that they
overlap, then the [used
values](https://www.w3.org/TR/css-cascade-5/#used-value) of all
[border-image-width]
offsets are proportionally reduced until they no longer overlap. In
mathematical notation: Given `L`~`width`~ as the
width of the [border image
area](#border-image-area),
`L`~`height`~ as its height, and
`W`~`side`~ as the
[border-image-width]
offset for the `side` side, let `f` =
min(`L`~`width`~/(`W`~`left`~+`W`~`right`~),
`L`~`height`~/(`W`~`top`~+`W`~`bottom`~)).
If `f` \< 1, then all `W` are reduced by
multiplying them by `f`.

### 4.4. Edge Overhang: the [border-image-outset property]
Name:

[border-image-outset]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

\[ [\<length
\[0,∞\]\>](https://www.w3.org/TR/css-values-4/#length-value)
[\|](https://www.w3.org/TR/css-values-4/#comb-one) [\<number
\[0,∞\]\>](https://www.w3.org/TR/css-values-4/#number-value)
\][{1,4}](https://www.w3.org/TR/css-values-4/#mult-num-range)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

0

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

All elements, except internal table elements when
[border-collapse](https://www.w3.org/TR/CSS2/tables.html#propdef-border-collapse) is [collapse]

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

N/A

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

four values, each a number or absolute length

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value

Tests

- [border-image-outset-composition.html](https://wpt.fyi/results/css/css-backgrounds/animations/border-image-outset-composition.html "css/css-backgrounds/animations/border-image-outset-composition.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/animations/border-image-outset-composition.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/animations/border-image-outset-composition.html)
- [border-image-outset-interpolation.html](https://wpt.fyi/results/css/css-backgrounds/animations/border-image-outset-interpolation.html "css/css-backgrounds/animations/border-image-outset-interpolation.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/animations/border-image-outset-interpolation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/animations/border-image-outset-interpolation.html)
- [border-image-outset-003.html](https://wpt.fyi/results/css/css-backgrounds/border-image-outset-003.html "css/css-backgrounds/border-image-outset-003.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-image-outset-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-image-outset-003.html)
- [border-image-outset-computed.html](https://wpt.fyi/results/css/css-backgrounds/parsing/border-image-outset-computed.html "css/css-backgrounds/parsing/border-image-outset-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/parsing/border-image-outset-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/parsing/border-image-outset-computed.html)
- [border-image-outset-invalid.html](https://wpt.fyi/results/css/css-backgrounds/parsing/border-image-outset-invalid.html "css/css-backgrounds/parsing/border-image-outset-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/parsing/border-image-outset-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/parsing/border-image-outset-invalid.html)
- [border-image-outset-valid.html](https://wpt.fyi/results/css/css-backgrounds/parsing/border-image-outset-valid.html "css/css-backgrounds/parsing/border-image-outset-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/parsing/border-image-outset-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/parsing/border-image-outset-valid.html)

The values specify the amount by which the [border image
area](#border-image-area)
extends beyond the [border
box](https://www.w3.org/TR/css-box-4/#border-box).

If there is only one component value, it applies to all sides. If there
are two values, the top and bottom are set to the first value and the
right and left are set to the second. If there are three values, the top
is set to the first value, the left and right are set to the second, and
the bottom is set to the third. If there are four values they apply to
the top, right, bottom, and left, respectively.

[\<length \[0,∞\]\>](https://www.w3.org/TR/css-values-4/#length-value)
: Represents an outset of the specified length.

[\<number \[0,∞\]\>](https://www.w3.org/TR/css-values-4/#number-value)
: Represents an outset of the specified multiple of the corresponding
 computed [border-width](#border-width).

Negative values are invalid.

Portions of the border-image that are rendered outside the [border
box](https://www.w3.org/TR/css-box-4/#border-box) are [ink
overflow](https://www.w3.org/TR/css-overflow-3/#ink-overflow) and do not trigger scrolling. Also such portions are
invisible to mouse events and do not capture such events on behalf of
the element.

 Even though they never cause a scrolling mechanism,
outset images may still be clipped by an ancestor or by the viewport.

### 4.5. Image Tiling: the [border-image-repeat property]
Name:

[border-image-repeat]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

\[ stretch
[\|](https://www.w3.org/TR/css-values-4/#comb-one) repeat [\|] round
[\|] space
\][{1,2}](https://www.w3.org/TR/css-values-4/#mult-num-range)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

stretch

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

All elements, except internal table elements when
[border-collapse](https://www.w3.org/TR/CSS2/tables.html#propdef-border-collapse) is [collapse]

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

N/A

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

two keywords, one per axis

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

Tests

- [discrete-no-interpolation.html](https://wpt.fyi/results/css/css-backgrounds/animations/discrete-no-interpolation.html "css/css-backgrounds/animations/discrete-no-interpolation.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/animations/discrete-no-interpolation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/animations/discrete-no-interpolation.html)
- [border-image-repeat-002.htm](https://wpt.fyi/results/css/css-backgrounds/border-image-repeat-002.htm "css/css-backgrounds/border-image-repeat-002.htm")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-image-repeat-002.htm)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-image-repeat-002.htm)
- [border-image-repeat-004.htm](https://wpt.fyi/results/css/css-backgrounds/border-image-repeat-004.htm "css/css-backgrounds/border-image-repeat-004.htm")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-image-repeat-004.htm)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-image-repeat-004.htm)
- [border-image-repeat-005.html](https://wpt.fyi/results/css/css-backgrounds/border-image-repeat-005.html "css/css-backgrounds/border-image-repeat-005.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-image-repeat-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-image-repeat-005.html)
- [border-image-repeat-1.html](https://wpt.fyi/results/css/css-backgrounds/border-image-repeat-1.html "css/css-backgrounds/border-image-repeat-1.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-image-repeat-1.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-image-repeat-1.html)
- [border-image-repeat-repeat-001.html](https://wpt.fyi/results/css/css-backgrounds/border-image-repeat-repeat-001.html "css/css-backgrounds/border-image-repeat-repeat-001.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-image-repeat-repeat-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-image-repeat-repeat-001.html)
- [border-image-repeat-round-003.html](https://wpt.fyi/results/css/css-backgrounds/border-image-repeat-round-003.html "css/css-backgrounds/border-image-repeat-round-003.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-image-repeat-round-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-image-repeat-round-003.html)
- [border-image-repeat-round-1.html](https://wpt.fyi/results/css/css-backgrounds/border-image-repeat-round-1.html "css/css-backgrounds/border-image-repeat-round-1.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-image-repeat-round-1.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-image-repeat-round-1.html)
- [border-image-repeat-round-2.html](https://wpt.fyi/results/css/css-backgrounds/border-image-repeat-round-2.html "css/css-backgrounds/border-image-repeat-round-2.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-image-repeat-round-2.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-image-repeat-round-2.html)
- [border-image-repeat-round-stretch-001.html](https://wpt.fyi/results/css/css-backgrounds/border-image-repeat-round-stretch-001.html "css/css-backgrounds/border-image-repeat-round-stretch-001.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-image-repeat-round-stretch-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-image-repeat-round-stretch-001.html)
- [border-image-repeat-round.html](https://wpt.fyi/results/css/css-backgrounds/border-image-repeat-round.html "css/css-backgrounds/border-image-repeat-round.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-image-repeat-round.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-image-repeat-round.html)
- [border-image-repeat-space-011.html](https://wpt.fyi/results/css/css-backgrounds/border-image-repeat-space-011.html "css/css-backgrounds/border-image-repeat-space-011.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-image-repeat-space-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-image-repeat-space-011.html)
- [border-image-repeat-space-1.html](https://wpt.fyi/results/css/css-backgrounds/border-image-repeat-space-1.html "css/css-backgrounds/border-image-repeat-space-1.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-image-repeat-space-1.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-image-repeat-space-1.html)
- [border-image-repeat-space-10.html](https://wpt.fyi/results/css/css-backgrounds/border-image-repeat-space-10.html "css/css-backgrounds/border-image-repeat-space-10.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-image-repeat-space-10.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-image-repeat-space-10.html)
- [border-image-repeat-space-2.html](https://wpt.fyi/results/css/css-backgrounds/border-image-repeat-space-2.html "css/css-backgrounds/border-image-repeat-space-2.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-image-repeat-space-2.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-image-repeat-space-2.html)
- [border-image-repeat-space-3.html](https://wpt.fyi/results/css/css-backgrounds/border-image-repeat-space-3.html "css/css-backgrounds/border-image-repeat-space-3.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-image-repeat-space-3.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-image-repeat-space-3.html)
- [border-image-repeat-space-4-ref-1.html](https://wpt.fyi/results/css/css-backgrounds/border-image-repeat-space-4-ref-1.html "css/css-backgrounds/border-image-repeat-space-4-ref-1.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-image-repeat-space-4-ref-1.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-image-repeat-space-4-ref-1.html)
- [border-image-repeat-space-4.html](https://wpt.fyi/results/css/css-backgrounds/border-image-repeat-space-4.html "css/css-backgrounds/border-image-repeat-space-4.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-image-repeat-space-4.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-image-repeat-space-4.html)
- [border-image-repeat-space-5-ref-1.html](https://wpt.fyi/results/css/css-backgrounds/border-image-repeat-space-5-ref-1.html "css/css-backgrounds/border-image-repeat-space-5-ref-1.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-image-repeat-space-5-ref-1.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-image-repeat-space-5-ref-1.html)
- [border-image-repeat-space-5.html](https://wpt.fyi/results/css/css-backgrounds/border-image-repeat-space-5.html "css/css-backgrounds/border-image-repeat-space-5.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-image-repeat-space-5.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-image-repeat-space-5.html)
- [border-image-repeat-space-6.html](https://wpt.fyi/results/css/css-backgrounds/border-image-repeat-space-6.html "css/css-backgrounds/border-image-repeat-space-6.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-image-repeat-space-6.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-image-repeat-space-6.html)
- [border-image-repeat-space-7.html](https://wpt.fyi/results/css/css-backgrounds/border-image-repeat-space-7.html "css/css-backgrounds/border-image-repeat-space-7.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-image-repeat-space-7.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-image-repeat-space-7.html)
- [border-image-repeat-space-8.html](https://wpt.fyi/results/css/css-backgrounds/border-image-repeat-space-8.html "css/css-backgrounds/border-image-repeat-space-8.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-image-repeat-space-8.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-image-repeat-space-8.html)
- [border-image-repeat-space-9.html](https://wpt.fyi/results/css/css-backgrounds/border-image-repeat-space-9.html "css/css-backgrounds/border-image-repeat-space-9.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-image-repeat-space-9.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-image-repeat-space-9.html)
- [border-image-repeat-stretch-round-001.html](https://wpt.fyi/results/css/css-backgrounds/border-image-repeat-stretch-round-001.html "css/css-backgrounds/border-image-repeat-stretch-round-001.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-image-repeat-stretch-round-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-image-repeat-stretch-round-001.html)
- [border-image-repeat_repeatnegx_none_50px.html](https://wpt.fyi/results/css/css-backgrounds/border-image-repeat_repeatnegx_none_50px.html "css/css-backgrounds/border-image-repeat_repeatnegx_none_50px.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-image-repeat_repeatnegx_none_50px.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-image-repeat_repeatnegx_none_50px.html)
- [css3-border-image-repeat-repeat.html](https://wpt.fyi/results/css/css-backgrounds/css3-border-image-repeat-repeat.html "css/css-backgrounds/css3-border-image-repeat-repeat.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/css3-border-image-repeat-repeat.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/css3-border-image-repeat-repeat.html)
- [css3-border-image-repeat-stretch.html](https://wpt.fyi/results/css/css-backgrounds/css3-border-image-repeat-stretch.html "css/css-backgrounds/css3-border-image-repeat-stretch.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/css3-border-image-repeat-stretch.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/css3-border-image-repeat-stretch.html)
- [border-image-repeat-computed.html](https://wpt.fyi/results/css/css-backgrounds/parsing/border-image-repeat-computed.html "css/css-backgrounds/parsing/border-image-repeat-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/parsing/border-image-repeat-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/parsing/border-image-repeat-computed.html)
- [border-image-repeat-invalid.html](https://wpt.fyi/results/css/css-backgrounds/parsing/border-image-repeat-invalid.html "css/css-backgrounds/parsing/border-image-repeat-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/parsing/border-image-repeat-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/parsing/border-image-repeat-invalid.html)
- [border-image-repeat-valid.html](https://wpt.fyi/results/css/css-backgrounds/parsing/border-image-repeat-valid.html "css/css-backgrounds/parsing/border-image-repeat-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/parsing/border-image-repeat-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/parsing/border-image-repeat-valid.html)

This property specifies how the images for the sides and the middle part
of the [border image](#border-image-dfn) are scaled and tiled. The first keyword applies to the
horizontal scaling and tiling of the top, middle and bottom parts, the
second to the vertical scaling and tiling of the left, middle and right
parts; see [Drawing the Border Image](#border-image-process). If the
second keyword is absent, it is assumed to be the same as the first.
Values have the following meanings:

[stretch]
: The image is stretched to fill its corresponding
 [region](#border-image-region).

[repeat]
: The image is tiled (repeated) to fill its corresponding
 [region](#border-image-region).

[round]
: The image is tiled (repeated) to fill its corresponding
 [region](#border-image-region). If it does not fill the area with a whole number
 of tiles, the image is rescaled so that it does.

[space]
: The image is tiled (repeated) to fill its corresponding
 [region](#border-image-region). If it does not fill the region with a whole number
 of tiles, the extra space is distributed around the tiles.

The exact process for scaling and tiling the border-image parts is given
in the section below.

### 4.6. Drawing the Border Image

After the [border image](#border-image-dfn) given by
[border-image-source](#propdef-border-image-source) is sliced by the
[border-image-slice](#propdef-border-image-slice) values, the resulting nine images
are scaled, positioned, and tiled into their corresponding [border image
regions](#border-image-region) in four steps:

1. Scale to
 [border-image-width](#propdef-border-image-width).
 - The two images for the top and bottom edges are made as tall as
 the top and bottom [border image
 regions](#border-image-region), respectively, and their width is scaled
 proportionally.
 - The images for the left and right edges are made as wide as the
 left and right [border image
 regions](#border-image-region), respectively, and their height is scaled
 proportionally.
 - The corner images are scaled to be as wide and as tall as the
 their respective [border image
 regions](#border-image-region).
 - The middle image's width is scaled by the same factor as the top
 image unless that factor is zero or infinity, in which case the
 scaling factor of the bottom is substituted, and failing that, the
 width is not scaled. The height of the middle image is scaled by
 the same factor as the left image unless that factor is zero or
 infinity, in which case the scaling factor of the right image is
 substituted, and failing that, the height is not scaled.
2. Scale to
 [border-image-repeat](#propdef-border-image-repeat).
 - If the first keyword is
 [stretch](#valdef-border-image-repeat-stretch), the top, middle and bottom images are
 further scaled to be as wide as the middle region of the [border
 image area](#border-image-area). The height is not changed any further.
 - If the first keyword is
 [round](#valdef-border-image-repeat-round), the top, middle and bottom images are
 resized in width, so that exactly a whole number of them fit in
 the middle region of the [border image
 area](#border-image-area), exactly as for
 [round](https://www.w3.org/TR/css-backgrounds-3/#valdef-background-repeat-round) in the
 [background-repeat](https://www.w3.org/TR/css-backgrounds-3/#propdef-background-repeat) property.
 - If the first keyword is
 [repeat](#valdef-border-image-repeat-repeat) or
 [space](#valdef-border-image-repeat-space), the top, middle, and bottom images are
 not changed any further.
 - The effects of
 [stretch](#valdef-border-image-repeat-stretch),
 [round](#valdef-border-image-repeat-round),
 [repeat](#valdef-border-image-repeat-repeat), and
 [space](#valdef-border-image-repeat-space) for the second keyword are analogous,
 acting on the height of the left, middle and right images.
3. Position the first tile.
 - If the first keyword is
 [repeat](#valdef-border-image-repeat-repeat), the top, middle, and bottom images are
 centered horizontally in their respective regions. Otherwise the
 images are placed at the left edge of their respective regions of
 the [border image
 area](#border-image-area).
 - If the second keyword is
 [repeat](#valdef-border-image-repeat-repeat), the left, middle, and right images are
 centered vertically in their respective regions. Otherwise the
 images are placed at the top edge of their respective regions of
 the [border image
 area](#border-image-area).
4. Tile and draw.
 - The images are then tiled to fill their respective regions.
 - In the case of
 [space](#valdef-border-image-repeat-space), any partial tiles are discarded and the
 extra space distributed before, after, and between the tiles.
 (I.e. the gap before the first tile, the gap after the last tile,
 and the gaps between tiles are equalized.) [This can result in
 empty border-image side regions.]
 - The images are drawn at the same stacking level as normal borders:
 immediately in front of the background layers.
 - The middle image is not drawn unless
 [fill](#border-image-slice-fill) was specified for
 [border-image-source](#propdef-border-image-source).

### 4.7. Border Image Shorthand: the [border-image property]
Name:

[border-image]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<\'border-image-source\'\>](#propdef-border-image-source)
[\|\|](https://www.w3.org/TR/css-values-4/#comb-any)
[\<\'border-image-slice\'\>](#propdef-border-image-slice) \[ /
[\<\'border-image-width\'\>](#propdef-border-image-width)
[\|](https://www.w3.org/TR/css-values-4/#comb-one) /
[\<\'border-image-width\'\>][?](https://www.w3.org/TR/css-values-4/#mult-opt) /
[\<\'border-image-outset\'\>](#propdef-border-image-outset) \][?]
[\|\|]
[\<\'border-image-repeat\'\>](#propdef-border-image-repeat)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

See individual properties

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

See individual properties

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

N/A

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

See individual properties

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

See individual properties

Tests

- [border-image-002.html](https://wpt.fyi/results/css/css-backgrounds/border-image-002.html "css/css-backgrounds/border-image-002.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-image-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-image-002.html)
- [border-image-003.html](https://wpt.fyi/results/css/css-backgrounds/border-image-003.html "css/css-backgrounds/border-image-003.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-image-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-image-003.html)
- [border-image-004.html](https://wpt.fyi/results/css/css-backgrounds/border-image-004.html "css/css-backgrounds/border-image-004.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-image-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-image-004.html)
- [border-image-006.html](https://wpt.fyi/results/css/css-backgrounds/border-image-006.html "css/css-backgrounds/border-image-006.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-image-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-image-006.html)
- [border-image-007.html](https://wpt.fyi/results/css/css-backgrounds/border-image-007.html "css/css-backgrounds/border-image-007.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-image-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-image-007.html)
- [border-image-011.html](https://wpt.fyi/results/css/css-backgrounds/border-image-011.html "css/css-backgrounds/border-image-011.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-image-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-image-011.html)
- [border-image-012.html](https://wpt.fyi/results/css/css-backgrounds/border-image-012.html "css/css-backgrounds/border-image-012.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-image-012.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-image-012.html)
- [border-image-013.html](https://wpt.fyi/results/css/css-backgrounds/border-image-013.html "css/css-backgrounds/border-image-013.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-image-013.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-image-013.html)
- [border-image-017.xht](https://wpt.fyi/results/css/css-backgrounds/border-image-017.xht "css/css-backgrounds/border-image-017.xht")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-image-017.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-image-017.xht)
- [border-image-018.xht](https://wpt.fyi/results/css/css-backgrounds/border-image-018.xht "css/css-backgrounds/border-image-018.xht")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-image-018.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-image-018.xht)
- [border-image-019.xht](https://wpt.fyi/results/css/css-backgrounds/border-image-019.xht "css/css-backgrounds/border-image-019.xht")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-image-019.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-image-019.xht)
- [border-image-020.xht](https://wpt.fyi/results/css/css-backgrounds/border-image-020.xht "css/css-backgrounds/border-image-020.xht")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-image-020.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-image-020.xht)
- [border-image-calc.html](https://wpt.fyi/results/css/css-backgrounds/border-image-calc.html "css/css-backgrounds/border-image-calc.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-image-calc.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-image-calc.html)
- [border-image-image-type-001.htm](https://wpt.fyi/results/css/css-backgrounds/border-image-image-type-001.htm "css/css-backgrounds/border-image-image-type-001.htm")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-image-image-type-001.htm)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-image-image-type-001.htm)
- [border-image-image-type-002.htm](https://wpt.fyi/results/css/css-backgrounds/border-image-image-type-002.htm "css/css-backgrounds/border-image-image-type-002.htm")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-image-image-type-002.htm)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-image-image-type-002.htm)
- [border-image-image-type-003.htm](https://wpt.fyi/results/css/css-backgrounds/border-image-image-type-003.htm "css/css-backgrounds/border-image-image-type-003.htm")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-image-image-type-003.htm)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-image-image-type-003.htm)
- [border-image-image-type-004.htm](https://wpt.fyi/results/css/css-backgrounds/border-image-image-type-004.htm "css/css-backgrounds/border-image-image-type-004.htm")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-image-image-type-004.htm)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-image-image-type-004.htm)
- [border-image-image-type-005.htm](https://wpt.fyi/results/css/css-backgrounds/border-image-image-type-005.htm "css/css-backgrounds/border-image-image-type-005.htm")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-image-image-type-005.htm)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-image-image-type-005.htm)
- [border-image-round-and-stretch.html](https://wpt.fyi/results/css/css-backgrounds/border-image-round-and-stretch.html "css/css-backgrounds/border-image-round-and-stretch.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-image-round-and-stretch.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-image-round-and-stretch.html)
- [border-image-shorthand-001.htm](https://wpt.fyi/results/css/css-backgrounds/border-image-shorthand-001.htm "css/css-backgrounds/border-image-shorthand-001.htm")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-image-shorthand-001.htm)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-image-shorthand-001.htm)
- [border-image-shorthand-002.htm](https://wpt.fyi/results/css/css-backgrounds/border-image-shorthand-002.htm "css/css-backgrounds/border-image-shorthand-002.htm")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-image-shorthand-002.htm)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-image-shorthand-002.htm)
- [border-image-shorthand-003.htm](https://wpt.fyi/results/css/css-backgrounds/border-image-shorthand-003.htm "css/css-backgrounds/border-image-shorthand-003.htm")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-image-shorthand-003.htm)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-image-shorthand-003.htm)
- [border-image-space-001.html](https://wpt.fyi/results/css/css-backgrounds/border-image-space-001.html "css/css-backgrounds/border-image-space-001.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-image-space-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-image-space-001.html)
- [border-image-invalid.html](https://wpt.fyi/results/css/css-backgrounds/parsing/border-image-invalid.html "css/css-backgrounds/parsing/border-image-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/parsing/border-image-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/parsing/border-image-invalid.html)
- [border-image-shorthand.sub.html](https://wpt.fyi/results/css/css-backgrounds/parsing/border-image-shorthand.sub.html "css/css-backgrounds/parsing/border-image-shorthand.sub.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/parsing/border-image-shorthand.sub.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/parsing/border-image-shorthand.sub.html)
- [border-image-valid.html](https://wpt.fyi/results/css/css-backgrounds/parsing/border-image-valid.html "css/css-backgrounds/parsing/border-image-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/parsing/border-image-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/parsing/border-image-valid.html)

This is a shorthand property for setting
[border-image-source](#propdef-border-image-source),
[border-image-slice](#propdef-border-image-slice),
[border-image-width](#propdef-border-image-width),
[border-image-outset](#propdef-border-image-outset), and
[border-image-repeat](#propdef-border-image-repeat) in a single declaration. Omitted
values are set to their [initial
values](https://www.w3.org/TR/css-cascade-5/#initial-value).

### 4.8. Effect on Tables

The [border-image](#propdef-border-image) properties apply to the border of
tables and inline tables that have
[border-collapse](https://www.w3.org/TR/CSS2/tables.html#propdef-border-collapse) set to [collapse]. However,
this specification does not define how such an image border is rendered.
In particular, it does not define how the image border interacts with
the borders of cells, rows and row groups at the edges of the table (see
[border conflict
resolution](https://www.w3.org/TR/2011/REC-CSS2-20110607/tables.html#border-conflict-resolution)
in
[\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")).

It is expected that a future specification will define the rendering. It
is recommended that UAs do not apply border images to tables with
collapsed borders until then.

## 5. Partial borders

Not Ready For Implementation

This section is not yet ready for implementation. It exists in this
repository to record the ideas and promote discussion.

Before attempting to implement anything of this section, please contact
the CSSWG at www-style@w3.org.

CSS borders traditionally cover an entire border edge. Sometimes,
however, it can be useful to hide some parts of the border.

Here are two proposals for doing this:
the second one is from GCPM, the first one is an attempt to recast it
more readably. The names are terrible, known problem, proposals
accepted. There is a problem with conceiving this as clipping: if you
have dotted borders, you want whole dots always, not parts of dots. So
it should be a drawing limit, not a clip.

### 5.1. Partial Borders: the [border-limit property]
Name:

[border-limit]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

all
[\|](https://www.w3.org/TR/css-values-4/#comb-one) \[ sides [\|] corners \]
[\<length-percentage
\[0,∞\]\>](https://www.w3.org/TR/css-values-4/#typedef-length-percentage)[?](https://www.w3.org/TR/css-values-4/#mult-opt) [\|] \[ top
[\|] right [\|] bottom
[\|] left \] [\<length-percentage
\[0,∞\]\>]

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

all

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

all elements, except table element when
[border-collapse](https://www.w3.org/TR/CSS2/tables.html#propdef-border-collapse) is
[collapse](https://www.w3.org/TR/css-text-4/#valdef-white-space-collapse-collapse)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

relative to border-box

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

as specified

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

By default, the entire border is drawn. However, border rendering can be
limited to only part of a border. The keyword specifies which part, and
the length or percentage specifies how much.

[[all](#valdef-border-limit-all)]
: The entire border is drawn.

[[sides](#valdef-border-limit-sides)]
: The sides are drawn up to but not including the corners (as defined
 by the border radii). A length or percentage is measured from the
 center of each side: [50%] draws the middle 50% of the border;
 by default the entire side is drawn.

[[corners](#valdef-border-limit-corners)]
: The corners are drawn plus the specified distance into the sides if
 specified. A length is measured from the closest edge of the corner
 area. A percentage is measured from the absolute corner of the
 border box.

[[left](#valdef-border-limit-left)]\
[[right](#valdef-border-limit-right)]
: For the left and right (vertical) sides, draws the entire side and
 corner. For the top and bottom (horizontal) sides, draws the
 left/right portion, as specified. Distances are measured as for
 [corners](#valdef-border-limit-corners).

[[top](#valdef-border-limit-top)]\
[[bottom](#valdef-border-limit-bottom)]
: For the top and bottom (horizontal) sides, draws the entire side and
 corner. For the left and right (vertical) sides, draws the
 top/bottom portion, as specified. Distances are measured as for
 [corners](#valdef-border-limit-corners).

The following example draws only the middle 50% of the sides.

```
div {
 border: solid;
 border-limit: sides 50%;
}
```

The following example draws only the curved parts of the corners.

```
div {
 border: solid;
 border-radius: 1em 2em;
 border-limit: corners;
}
```

The following example draws only the left 4em of the top border.

```
div {
 border-top: solid;
 border-limit: left 4em;
}
```

The following example draws only the first 10px of each corner:

```
div {
 border: solid;
 border-limit: corners 10px;
}
```

The following example draws the curved part of the corner plus 5px along
the sides:

```
div {
 border: solid;
 border-radius: 5px;
 border-limit: corners 5px;
}
```

The following example draws the curved part of the corner and all of the
side except the middle 40%.

```
div {
 border: solid;
 border-radius: 5px;
 border-limit: corners 30%;
}
```

### 5.2. The [border-clip properties]
Name:

[border-top-clip],
[border-right-clip],
[border-bottom-clip],
[border-left-clip],
[border-block-start-clip],
[border-block-end-clip],
[border-inline-start-clip],
[border-inline-end-clip]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

none
[\|](https://www.w3.org/TR/css-values-4/#comb-one) \[ [\<length-percentage
\[0,∞\]\>](https://www.w3.org/TR/css-values-4/#typedef-length-percentage) [\|]
[\<flex\>](https://www.w3.org/TR/css-grid-2/#typedef-flex)
\][+](https://www.w3.org/TR/css-values-4/#mult-one-plus)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

none

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[all
elements](https://www.w3.org/TR/css-pseudo/#generated-content "Includes ::before and ::after pseudo-elements.")

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

refer to length of border-edge side

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

[none], or a list consisting of absolute lengths, or percentages
as specified

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value

[Logical property
group:](https://drafts.csswg.org/css-logical-1/#logical-property-group)

[border-clip](#propdef-border-clip)

These properties split their respective borders into parts along the
border edge. The first part is visible, the second is invisible, the
third part is visible, etc. Parts can be specified with lengths,
percentages, or flexible lengths (expressed by the
[fr](https://www.w3.org/TR/css-grid-2/#valdef-flex-fr) unit, as per
[\[CSS3GRID\]](#biblio-css3grid "CSS Grid Layout Module Level 1")).
The [none] value means that the border is not split, but shown
normally.

The
[flow-relative](https://www.w3.org/TR/css-writing-modes-4/#flow-relative) longhands
([border-block-start-clip](#propdef-border-block-start-clip), etc.) correspond to the
[physical](https://www.w3.org/TR/css-writing-modes-4/#physical) longhands
([border-top-clip](#propdef-border-top-clip), etc.) depending on the element's
[writing-mode](https://www.w3.org/TR/css-writing-modes-4/#propdef-writing-mode),
[direction](https://www.w3.org/TR/css-writing-modes-3/#propdef-direction), and
[text-orientation](https://www.w3.org/TR/css-writing-modes-4/#propdef-text-orientation).

Name:

[border-block-clip],
[border-inline-clip]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<\'border-top-clip\'\>](#propdef-border-top-clip)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

see individual properties

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

see individual properties

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

see individual properties

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

see individual properties

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

see individual properties

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

see individual properties

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

These two [shorthand
properties](https://www.w3.org/TR/css-cascade-5/#shorthand-property) set the
[border-block-start-clip](#propdef-border-block-start-clip) &
[border-block-end-clip](#propdef-border-block-end-clip) and
[border-inline-start-clip](#propdef-border-inline-start-clip) &
[border-inline-end-clip](#propdef-border-inline-end-clip), respectively.

Name:

[border-clip]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<\'border-top-clip\'\>](#propdef-border-top-clip)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

see individual properties

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

see individual properties

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

see individual properties

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

see individual properties

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

see individual properties

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

see individual properties

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[border-clip](#propdef-border-clip) is a [shorthand
property](https://www.w3.org/TR/css-cascade-5/#shorthand-property) for the longhand properties, setting all four sides to
the same value.

If the listed parts are shorter than the border, any remaining border is
split proportionally between the specified flexible lengths. If there
are no flexible lengths, the behavior is as if [1fr] had been
specified at the end of the list.

If the listed parts are longer than the border, the specified parts will
be shown in full until the end of the border. In this case, all flexible
lengths will be zero.

For horizontal borders, parts are listed from left to right. For
vertical borders, parts are listed from top to bottom.

The exact border parts are determined by laying out the specified border
parts with all flexible lengths initially set to zero. Any remaining
border is split proportionally between the flexible lengths specified.

border-clip: 10px 1fr 10px;

:::::: {style="position: relative; width: 250px; height: 150px; background: white;"}
::::: {style="border: 2px solid black; width: 200px; height: 100px; position: absolute; top: 20px; left: 20px"}
::: {style="position: absolute; background: white; left: 15px; top: -5px; height: 110px; width: 170px"}

::: {style="position: absolute; background: white; left: -5px; top: 15px; height: 70px; width: 210px"}

border-top-clip: 10px 1fr 10px;
 border-bottom-clip: 10px 1fr 10px;
 border-right-clip: 5px 1fr 5px;
 border-left-clip: 5px 1fr 5px;

:::::: {style="position: relative; width: 250px; height: 150px; background: white;"}
::::: {style="border: 2px solid black; width: 200px; height: 100px; position: absolute; top: 20px; left: 20px"}
::: {style="position: absolute; background: white; left: 15px; top: -5px; height: 110px; width: 170px"}

::: {style="position: absolute; background: white; left: -5px; top: 5px; height: 90px; width: 210px"}

By making the first part have zero length, the inverse border of the
previous example can easily be created:

 border-top-clip: 0 10px 1fr 10px;
 border-bottom-clip: 0 10px 1fr 10px;
 border-right-clip: 0 5px 1fr 5px;
 border-left-clip: 0 5px 1fr 5px;

:::::::: {style="position: relative; width: 250px; height: 150px; background: white;"}
::::::: {style="border: 2px solid black; width: 200px; height: 100px; position: absolute; top: 20px; left: 20px"}
::: {style="position: absolute; background: white; left: -5px; top: -5px; height: 10px; width: 15px"}

::: {style="position: absolute; background: white; right: -5px; top: -5px; height: 10px; width: 15px"}

::: {style="position: absolute; background: white; left: -5px; top: 95px; height: 10px; width: 15px"}

::: {style="position: absolute; background: white; right: -5px; top: 95px; height: 10px; width: 15px"}

border: thin solid black;
 border-clip: 0 1fr; /* hide borders */
 border-top-clip: 10px 1fr 10px; /* make certain borders visible */
 border-bottom-clip: 10px 1fr 10px;

:::::: {style="position: relative; width: 250px; height: 150px; background: white;"}
::::: {style="border: 2px solid black; width: 200px; height: 100px; position: absolute; top: 20px; left: 20px"}
::: {style="position: absolute; background: white; left: 15px; top: -5px; height: 110px; width: 170px"}

::: {style="position: absolute; background: white; left: -5px; top: 0px; height: 100px; width: 210px"}

border-top: thin solid black;
 border-bottom: thin solid black;
 border-top-clip: 10px;
 border-bottom-clip: 10px;

:::::: {style="position: relative; width: 250px; height: 150px; background: white;"}
::::: {style="border: 2px solid black; width: 200px; height: 100px; position: absolute; top: 20px; left: 20px"}
::: {style="position: absolute; background: white; left: 15px; top: -5px; height: 110px; width: 200px"}

::: {style="position: absolute; background: white; left: -5px; top: 0px; height: 100px; width: 210px"}

border-top: thin solid black;
 border-clip: 10px;

:::::: {style="position: relative; width: 250px; height: 150px; background: white;"}
::::: {style="border: 2px solid black; width: 200px; height: 100px; position: absolute; top: 20px; left: 20px"}
::: {style="position: absolute; background: white; left: 15px; top: -5px; height: 110px; width: 200px"}

::: {style="position: absolute; background: white; left: -5px; top: 0px; height: 110px; width: 210px"}

This rendering:

:::: {style="background: white; color: black; padding: 0.2em 0.5em"}
``` {style="margin-left: 0;"}
A sentence consists of words¹.
```

::: {style="width: 3em; height: 2px; background: black"}

``` {style="margin-left: 0"}
¹ Most often.
```

can be achieved with this style sheet:

 @footnote {
 border-top: thin solid black;
 border-clip: 4em;
 }

border: 4px solid black;
 border-top-clip: 40px 20px 0 1fr 20px 20px 0 1fr 40px;

In this example, there will be a visible 40px border part on each end of
the top border. Inside the 40px border parts, there will be an invisible
border part of at least 20px. Inside these invisible border parts, there
will be visible border parts, each 20px long with 20px invisible border
parts between them.

::::::::: {style="position: relative; width: 192px; background: white; padding: 40px"}
::: {style="border: 4px solid black; height: 40px"}

::: {style="position: absolute; background: white; width: 20px; height: 4px; top: 40px; left: 80px"}

::: {style="position: absolute; background: red; width: 6px; height: 4px; top: 40px; left: 100px"}

::: {style="position: absolute; background: white; width: 20px; height: 4px; top: 40px; left: 126px"}

::: {style="position: absolute; background: white; width: 20px; height: 4px; top: 40px; left: 166px"}

::: {style="position: absolute; background: red; width: 6px; height: 4px; top: 40px; left: 186px"}

The fragments are shown in red for illustrative purposes; they should
not be visible in compliant UAs.

border: 4px solid black;
 border-top-clip: 3fr 10px 2fr 10px 1fr 10px 10px 10px 1fr 10px 2fr 10px 3fr;

All but one of the visible border parts are represented as flexible
lengths in this example. The length of these border parts will change
when the width of the element changes. Here is one rendering where 1fr
ends up being 10px:

::::::::::::::::: {style="position: relative; width: 190px; background: white; padding: 40px"}
::: {style="border: 4px solid black; border-top: none; height: 40px"}

::: {style="position: absolute; background: red; width: 30px; height: 4px; top: 40px; left: 40px"}

::: {style="position: absolute; background: white; width: 10px; height: 4px; top: 40px; left: 70px"}

::: {style="position: absolute; background: red; width: 20px; height: 4px; top: 40px; left: 80px"}

::: {style="position: absolute; background: white; width: 10px; height: 4px; top: 40px; left: 100px"}

::: {style="position: absolute; background: red; width: 10px; height: 4px; top: 40px; left: 110px"}

::: {style="position: absolute; background: white; width: 10px; height: 4px; top: 40px; left: 120px"}

::: {style="position: absolute; background: black; width: 10px; height: 4px; top: 40px; left: 130px"}

::: {style="position: absolute; background: white; width: 10px; height: 4px; top: 40px; left: 140px"}

::: {style="position: absolute; background: red; width: 10px; height: 4px; top: 40px; left: 150px"}

::: {style="position: absolute; background: white; width: 10px; height: 4px; top: 40px; left: 160px"}

::: {style="position: absolute; background: red; width: 20px; height: 4px; top: 40px; left: 170px"}

::: {style="position: absolute; background: white; width: 10px; height: 4px; top: 40px; left: 190px"}

::: {style="position: absolute; background: red; width: 30px; height: 4px; top: 40px; left: 200px"}

Here is another rendering where 1fr ends up being 30px:

::::::::::::::::: {style="position: relative; width: 440px; background: white; padding: 40px"}
::: {style="border: 4px solid black; border-top: none; height: 40px"}

::: {style="position: absolute; background: red; width: 90px; height: 4px; top: 40px; left: 40px"}

::: {style="position: absolute; background: white; width: 10px; height: 4px; top: 40px; left: 130px"}

::: {style="position: absolute; background: red; width: 60px; height: 4px; top: 40px; left: 140px"}

::: {style="position: absolute; background: white; width: 10px; height: 4px; top: 40px; left: 200px"}

::: {style="position: absolute; background: red; width: 30px; height: 4px; top: 40px; left: 210px"}

::: {style="position: absolute; background: white; width: 10px; height: 4px; top: 40px; left: 240px"}

::: {style="position: absolute; background: black; width: 10px; height: 4px; top: 40px; left: 250px"}

::: {style="position: absolute; background: white; width: 10px; height: 4px; top: 40px; left: 260px"}

::: {style="position: absolute; background: red; width: 30px; height: 4px; top: 40px; left: 270px"}

::: {style="position: absolute; background: white; width: 10px; height: 4px; top: 40px; left: 300px"}

::: {style="position: absolute; background: red; width: 60px; height: 4px; top: 40px; left: 310px"}

::: {style="position: absolute; background: white; width: 10px; height: 4px; top: 40px; left: 370px"}

::: {style="position: absolute; background: red; width: 90px; height: 4px; top: 40px; left: 390px"}

The fragments are shown in red for illustrative purposes; they should be
black in compliant UAs.

- [border-clip-computed.html](https://wpt.fyi/results/css/css-borders/tentative/parsing/border-clip-computed.html "css/css-borders/tentative/parsing/border-clip-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-borders/tentative/parsing/border-clip-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-borders/tentative/parsing/border-clip-computed.html)
- [border-clip-invalid.html](https://wpt.fyi/results/css/css-borders/tentative/parsing/border-clip-invalid.html "css/css-borders/tentative/parsing/border-clip-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-borders/tentative/parsing/border-clip-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-borders/tentative/parsing/border-clip-invalid.html)
- [border-clip-valid.html](https://wpt.fyi/results/css/css-borders/tentative/parsing/border-clip-valid.html "css/css-borders/tentative/parsing/border-clip-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-borders/tentative/parsing/border-clip-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-borders/tentative/parsing/border-clip-valid.html)

## 6. Drop Shadows

### 6.1. Coloring shadows: the [box-shadow-color property]
Name:

[box-shadow-color]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<color\>](https://www.w3.org/TR/css-color-5/#typedef-color)[\#](https://www.w3.org/TR/css-values-4/#mult-comma)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

currentcolor

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[all
elements](https://www.w3.org/TR/css-pseudo/#generated-content "Includes ::before and ::after pseudo-elements.")

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

N/A

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

list, each item a computed color

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value

The
[box-shadow-color](#propdef-box-shadow-color) property defines one or more drop
shadow colors. The property accepts a comma-separated list of shadow
colors.

See the section ["Layering, Layout, and Other
Details"](https://www.w3.org/TR/css-backgrounds-3/#shadow-layers) for
how
[box-shadow-color](#propdef-box-shadow-color) interacts with other
comma-separated drop shadow properties to form each drop shadow layer.

Tests

- [box-shadow-color-computed.html](https://wpt.fyi/results/css/css-borders/tentative/parsing/box-shadow-color-computed.html "css/css-borders/tentative/parsing/box-shadow-color-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-borders/tentative/parsing/box-shadow-color-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-borders/tentative/parsing/box-shadow-color-computed.html)
- [box-shadow-color-invalid.html](https://wpt.fyi/results/css/css-borders/tentative/parsing/box-shadow-color-invalid.html "css/css-borders/tentative/parsing/box-shadow-color-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-borders/tentative/parsing/box-shadow-color-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-borders/tentative/parsing/box-shadow-color-invalid.html)
- [box-shadow-color-valid.html](https://wpt.fyi/results/css/css-borders/tentative/parsing/box-shadow-color-valid.html "css/css-borders/tentative/parsing/box-shadow-color-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-borders/tentative/parsing/box-shadow-color-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-borders/tentative/parsing/box-shadow-color-valid.html)

### 6.2. Offsetting shadows: the [box-shadow-offset property]
Name:

[box-shadow-offset]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

\[ none
[\|](https://www.w3.org/TR/css-values-4/#comb-one)
[\<length\>](https://www.w3.org/TR/css-values-4/#length-value)[{1,2}](https://www.w3.org/TR/css-values-4/#mult-num-range)
\][\#](https://www.w3.org/TR/css-values-4/#mult-comma)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

none

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[all
elements](https://www.w3.org/TR/css-pseudo/#generated-content "Includes ::before and ::after pseudo-elements.")

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

N/A

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

list, each item either
[none](#shadow-offset-none) or a pair of offsets (horizontal and vertical) from
the element's box

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value, treating
[none](#shadow-offset-none) as [0 0] when interpolated with
non-[none] values.

The
[box-shadow-offset](#propdef-box-shadow-offset) property defines one or more drop
shadow offsets. The property accepts a comma-separated list. Each item
in that list can either be the
[none](#shadow-offset-none) value, which indicates no shadow, a pair of
[\<length\>](https://www.w3.org/TR/css-values-4/#length-value) values, which define the horizontal
and vertical offsets, or a single [\<length\>] value, which sets both offsets to the same value.

[none]
: The shadow will not be rendered. The values of other box shadow
 properties corresponding to this shadow have no effect.

[1st [\<length\>](https://www.w3.org/TR/css-values-4/#length-value)]

: Specifies the [horizontal
 offset]
 of the shadow. A positive value draws a shadow that is offset to the
 right of the box, a negative length to the left.

 If only one
 [\<length\>](https://www.w3.org/TR/css-values-4/#length-value) value is specified, it sets both
 the horizontal and vertical offsets to that value.

[2nd [\<length\>](https://www.w3.org/TR/css-values-4/#length-value)]
: Specifies the [vertical
 offset]
 of the shadow. A positive value offsets the shadow down, a negative
 one up.

See the section ["Layering, Layout, and Other
Details"](https://www.w3.org/TR/css-backgrounds-3/#shadow-layers) for
how
[box-shadow-offset](#propdef-box-shadow-offset) interacts with other
comma-separated drop shadow properties to form each drop shadow layer.

Tests

- [box-shadow-offset-computed.html](https://wpt.fyi/results/css/css-borders/tentative/parsing/box-shadow-offset-computed.html "css/css-borders/tentative/parsing/box-shadow-offset-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-borders/tentative/parsing/box-shadow-offset-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-borders/tentative/parsing/box-shadow-offset-computed.html)
- [box-shadow-offset-invalid.html](https://wpt.fyi/results/css/css-borders/tentative/parsing/box-shadow-offset-invalid.html "css/css-borders/tentative/parsing/box-shadow-offset-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-borders/tentative/parsing/box-shadow-offset-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-borders/tentative/parsing/box-shadow-offset-invalid.html)
- [box-shadow-offset-valid.html](https://wpt.fyi/results/css/css-borders/tentative/parsing/box-shadow-offset-valid.html "css/css-borders/tentative/parsing/box-shadow-offset-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-borders/tentative/parsing/box-shadow-offset-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-borders/tentative/parsing/box-shadow-offset-valid.html)

### 6.3. Blurring shadows: the [box-shadow-blur property]
Name:

[box-shadow-blur]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<length
\[0,∞\]\>](https://www.w3.org/TR/css-values-4/#length-value)[\#](https://www.w3.org/TR/css-values-4/#mult-comma)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

0

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[all
elements](https://www.w3.org/TR/css-pseudo/#generated-content "Includes ::before and ::after pseudo-elements.")

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

N/A

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

list, each item a
[\<length\>](https://www.w3.org/TR/css-values-4/#length-value)

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value

The
[box-shadow-blur](#propdef-box-shadow-blur) property defines one or more blur
radii for drop shadows. The property accepts a comma-separated list of
[\<length\>](https://www.w3.org/TR/css-values-4/#length-value) values.

Negative values are invalid. If the blur value is zero, the shadow's
edge is sharp. Otherwise, the larger the value, the more the shadow's
edge is blurred. See [Shadow
Blurring](https://www.w3.org/TR/css-backgrounds-3/#shadow-blur), below.

See the section ["Layering, Layout, and Other
Details"](https://www.w3.org/TR/css-backgrounds-3/#shadow-layers) for
how
[box-shadow-blur](#propdef-box-shadow-blur) interacts with other
comma-separated drop shadow properties to form each drop shadow layer.

Tests

- [box-shadow-blur-computed.html](https://wpt.fyi/results/css/css-borders/tentative/parsing/box-shadow-blur-computed.html "css/css-borders/tentative/parsing/box-shadow-blur-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-borders/tentative/parsing/box-shadow-blur-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-borders/tentative/parsing/box-shadow-blur-computed.html)
- [box-shadow-blur-invalid.html](https://wpt.fyi/results/css/css-borders/tentative/parsing/box-shadow-blur-invalid.html "css/css-borders/tentative/parsing/box-shadow-blur-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-borders/tentative/parsing/box-shadow-blur-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-borders/tentative/parsing/box-shadow-blur-invalid.html)
- [box-shadow-blur-valid.html](https://wpt.fyi/results/css/css-borders/tentative/parsing/box-shadow-blur-valid.html "css/css-borders/tentative/parsing/box-shadow-blur-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-borders/tentative/parsing/box-shadow-blur-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-borders/tentative/parsing/box-shadow-blur-valid.html)

### 6.4. Spreading shadows: the [box-shadow-spread property]
Name:

[box-shadow-spread]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<length\>](https://www.w3.org/TR/css-values-4/#length-value)[\#](https://www.w3.org/TR/css-values-4/#mult-comma)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

0

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[all
elements](https://www.w3.org/TR/css-pseudo/#generated-content "Includes ::before and ::after pseudo-elements.")

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

N/A

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

list, each item a
[\<length\>](https://www.w3.org/TR/css-values-4/#length-value)

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value

The
[box-shadow-spread](#propdef-box-shadow-spread) property defines one or more spread
distances for drop shadows. The property accepts a comma-separated list
of
[\<length\>](https://www.w3.org/TR/css-values-4/#length-value) values.

Positive values cause the shadow to expand in all directions by the
specified radius. Negative values cause the shadow to contract. See
[Shadow Shape](https://www.w3.org/TR/css-backgrounds-3/#shadow-shape),
below.

Note that for inner shadows, expanding the shadow (creating more shadow
area) means contracting the shadow's perimeter shape.

See the section ["Layering, Layout, and Other
Details"](https://www.w3.org/TR/css-backgrounds-3/#shadow-layers) for
how
[box-shadow-spread](#propdef-box-shadow-spread) interacts with other
comma-separated drop shadow properties to form each drop shadow layer.

Tests

- [box-shadow-spread-computed.html](https://wpt.fyi/results/css/css-borders/tentative/parsing/box-shadow-spread-computed.html "css/css-borders/tentative/parsing/box-shadow-spread-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-borders/tentative/parsing/box-shadow-spread-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-borders/tentative/parsing/box-shadow-spread-computed.html)
- [box-shadow-spread-invalid.html](https://wpt.fyi/results/css/css-borders/tentative/parsing/box-shadow-spread-invalid.html "css/css-borders/tentative/parsing/box-shadow-spread-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-borders/tentative/parsing/box-shadow-spread-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-borders/tentative/parsing/box-shadow-spread-invalid.html)
- [box-shadow-spread-valid.html](https://wpt.fyi/results/css/css-borders/tentative/parsing/box-shadow-spread-valid.html "css/css-borders/tentative/parsing/box-shadow-spread-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-borders/tentative/parsing/box-shadow-spread-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-borders/tentative/parsing/box-shadow-spread-valid.html)

### 6.5. Spreading shadows: the [box-shadow-position property]
Name:

[box-shadow-position]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

\[ outset
[\|](https://www.w3.org/TR/css-values-4/#comb-one) inset
\][\#](https://www.w3.org/TR/css-values-4/#mult-comma)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

outset

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[all
elements](https://www.w3.org/TR/css-pseudo/#generated-content "Includes ::before and ::after pseudo-elements.")

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

N/A

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

list, each item one of the keywords

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value

The
[box-shadow-position](#propdef-box-shadow-position) property defines one or more drop
shadow positions. The property accepts a comma-separated list of
[outset](#valdef-box-shadow-position-outset) and
[inset](#valdef-box-shadow-position-inset) keywords.

[outset]
: Causes the drop shadow to be an [outer
 box-shadow]. That means, one that shadows the
 box onto the canvas, as if it were lifted above the canvas.

[inset]
: Causes the drop shadow to be an [inner
 box-shadow]. That means, one that shadows the
 canvas onto the box, as if the box were cut out of the canvas and
 shifted behind it.

See the section ["Layering, Layout, and Other
Details"](https://www.w3.org/TR/css-backgrounds-3/#shadow-layers) for
how
[box-shadow-position](#propdef-box-shadow-position) interacts with other
comma-separated drop shadow properties to form each drop shadow layer.

Tests

- [box-shadow-position-computed.html](https://wpt.fyi/results/css/css-borders/tentative/parsing/box-shadow-position-computed.html "css/css-borders/tentative/parsing/box-shadow-position-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-borders/tentative/parsing/box-shadow-position-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-borders/tentative/parsing/box-shadow-position-computed.html)
- [box-shadow-position-invalid.html](https://wpt.fyi/results/css/css-borders/tentative/parsing/box-shadow-position-invalid.html "css/css-borders/tentative/parsing/box-shadow-position-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-borders/tentative/parsing/box-shadow-position-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-borders/tentative/parsing/box-shadow-position-invalid.html)
- [box-shadow-position-valid.html](https://wpt.fyi/results/css/css-borders/tentative/parsing/box-shadow-position-valid.html "css/css-borders/tentative/parsing/box-shadow-position-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-borders/tentative/parsing/box-shadow-position-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-borders/tentative/parsing/box-shadow-position-valid.html)

### 6.6. Drop Shadows Shorthand: the [box-shadow property]
Name:

[box-shadow]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<spread-shadow\>](#typedef-spread-shadow)[\#](https://www.w3.org/TR/css-values-4/#mult-comma)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

none

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[all
elements](https://www.w3.org/TR/css-pseudo/#generated-content "Includes ::before and ::after pseudo-elements.")

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

N/A

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

see individual properties

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

see individual properties

The [box-shadow](#propdef-box-shadow) property attaches one or more
drop-shadows to the box. The property accepts a comma-separated list of
shadows, ordered front to back.

Each shadow is given as a
[\<spread-shadow\>](#typedef-spread-shadow), outlining the
[box-shadow-offset](#propdef-box-shadow-offset) defined by two
[\<length\>](https://www.w3.org/TR/css-values-4/#length-value) values, and optional values for the
[box-shadow-blur](#propdef-box-shadow-blur),
[box-shadow-spread](#propdef-box-shadow-spread),
[box-shadow-color](#propdef-box-shadow-color), and
[box-shadow-position](#propdef-box-shadow-position). Omitted lengths are [0];
omitted colors default to
[transparent](https://www.w3.org/TR/css-color-4/#valdef-color-transparent) when the specified offset is
[none](#shadow-offset-none) and to
[currentcolor](https://www.w3.org/TR/css-color-4/#valdef-color-currentcolor) otherwise.

 To avoid ambiguities in parsing the different
[\<length\>](https://www.w3.org/TR/css-values-4/#length-value) values, the offset has to be
specified as two [\<length\>]
values, in opposite to the
[box-shadow-offset](#propdef-box-shadow-offset) property, where a single
[\<length\>] value can be used to
specify both offsets.

``` prod
<spread-shadow> = <'box-shadow-color'>? && [ [ none | <length>{2} ] [ <'box-shadow-blur'> <'box-shadow-spread'>? ]? ] && <'box-shadow-position'>?
```

The example below demonstrates the
effects of spread and blur on the shadow:

 width: 100px; height: 100px;
 border: 12px solid blue; background-color: orange;
 border-top-left-radius: 60px 90px;
 border-bottom-right-radius: 60px 90px;
 box-shadow: 64px 64px 12px 40px rgba(0,0,0,0.4),
 12px 12px 0px 8px rgba(0,0,0,0.4) inset;

!(images/spread-blur.png){a
height="244" width="251"}

#### 6.6.1. Shadow Shape, Spread, and Knockout

An [outer
box-shadow](https://www.w3.org/TR/css-backgrounds-3/#box-shadow-outer-box-shadow) casts a shadow as if the border-box of the element were
opaque. Assuming a spread distance of zero, its perimeter has the exact
same size and shape as the border box. The shadow is drawn outside the
border edge only: it is clipped inside the border-box of the element.

An [inner
box-shadow](https://www.w3.org/TR/css-backgrounds-3/#box-shadow-inner-box-shadow) casts a shadow as if everything outside the padding
edge were opaque. Assuming a spread distance of zero, its perimeter has
the exact same size and shape as the padding box. The shadow is drawn
inside the padding edge only: it is clipped outside the padding box of
the element.

If a [spread
distance](https://www.w3.org/TR/css-backgrounds-3/#box-shadow-spread-distance) is defined, the shadow perimeter defined above is
expanded outward (for [outer
box-shadows](https://www.w3.org/TR/css-backgrounds-3/#box-shadow-outer-box-shadow)) or contracted inward (for [inner
box-shadows](https://www.w3.org/TR/css-backgrounds-3/#box-shadow-inner-box-shadow)) by outsetting (insetting, for inner shadows) the
shadow's straight edges by the [spread
distance] (and flooring the
resulting width/height at zero).

Below are some examples of an orange
box with a blue border being given a drop shadow.

 border:5px solid blue;
 background-color:orange;
 width: 144px;
 height: 144px;

 border-radius: 20px;

 border-radius: 0;

 box-shadow:
 rgba(0,0,0,0.4)
 10px 10px;

![A round-cornered box with a light gray shadow the same shape as the
border box offset 10px to the right and 10px down from directly
underneath the box.](images/shadow-outer-round.png){height="175"
width="175"}

![A square-cornered box with a light gray shadow the same shape as the
border box offset 10px to the right and 10px down from directly
underneath the box.](images/shadow-outer-square.png){height="175"
width="175"}

 box-shadow:
 rgba(0,0,0,0.4)
 10px 10px
 inset

![A round-cornered box with a light gray shadow the inverse shape of the
padding box filling 10px in from the top and left edges (just inside the
border).](images/shadow-inner-round.png){height="175" width="175"}

![A square-cornered box with a light gray shadow the inverse shape of
the padding box filling 10px in from the top and left edges (just inside
the border).](images/shadow-inner-square.png){height="175" width="175"}

 box-shadow:
 rgba(0,0,0,0.4)
 10px 10px 0
 10px /* spread */

![A round-cornered box with a light gray shadow the same shape as the
box but 20px taller and wider and offset so that the top and left edges
of the shadow are directly underneath the top and left edges of the
box.](images/shadow-outer-spread-round.png){height="175" width="175"}

![A square-cornered box with a light gray shadow the same shape as the
box but 20px taller and wider and offset so that the top and left edges
of the shadow are directly underneath the top and left edges of the
box.](images/shadow-outer-spread-square.png){height="175" width="175"}

 box-shadow:
 rgba(0,0,0,0.4)
 10px 10px 0
 10px /* spread */
 inset

![A round-cornered box with a light gray shadow the inverse shape of the
box but 20px narrower and shorter filling 20px in from the top and left
edges (just inside the
border).](images/shadow-inner-spread-round.png){height="175"
width="175"}

![A round-cornered box with a light gray shadow the inverse shape of the
box but 20px narrower and shorter filling 20px in from the top and left
edges (just inside the
border).](images/shadow-inner-spread-square.png){height="175"
width="175"}

To preserve the box's shape when spread is applied, the corner radii of
the shadow are also increased (decreased, for inner shadows) from the
border-box (padding-box) radii by adding (subtracting) the [spread
distance](https://www.w3.org/TR/css-backgrounds-3/#box-shadow-spread-distance) (and flooring at zero). For outer shadows, the [border
radius](#border-radii) is then
[adjusted](#outset-adjusted-border-radius), independently in each dimension, to preserve the
sharpness of rounded corners.

The [border-image](#propdef-border-image) does not affect the shape of the
box-shadow.

#### 6.6.2. Blurring Shadow Edges

A non-zero [blur
radius](https://www.w3.org/TR/css-backgrounds-3/#box-shadow-blur-radius) indicates that the resulting shadow should be blurred,
such as by a Gaussian filter. The exact algorithm is not defined;
however the resulting shadow must approximate (with each pixel being
within 5% of its expected value) the image that would be generated by
applying to the shadow a Gaussian blur with a standard deviation equal
to half the blur radius.

 This means for a long, straight shadow edge, the blur
radius will create a visibly apparent color transition approximately the
twice length of the blur radius that is perpendicular to and centered on
the shadow's edge, and that ranges from almost the full shadow color at
the endpoint inside the shadow to almost fully transparent at the
endpoint outside it.

### 6.7. Layering, Layout, and Other Details

Drop shadows are declared in the [coordinated value
list](https://www.w3.org/TR/css-values-4/#coordinated-value-list) constructed from the [box-shadow-\*] properties,
which form a [coordinating list property
group](https://www.w3.org/TR/css-values-4/#coordinating-list-property) with
[box-shadow-offset](#propdef-box-shadow-offset) as the [coordinating list base
property](https://www.w3.org/TR/css-values-4/#coordinating-list-base-property). See [CSS Values 4 § A Coordinating List-Valued
Properties](https://www.w3.org/TR/css-values-4/#linked-properties).

The shadow effects are applied front-to-back: the first shadow is on top
and the others are layered behind. Shadows do not influence layout and
may overlap (or be overlapped by) other boxes and text or their shadows.
In terms of stacking contexts and the painting order, the *outer
box-shadows* of an element are drawn immediately below the background of
that element, and the *inner shadows* of an element are drawn
immediately above the background of that element (below the borders and
border image, if any).

Unless otherwise specified, drop shadows are only applied to the
[principal
box](https://www.w3.org/TR/css-display-4/#principal-box). If the affected box has multiple fragments, the
shadows are applied as specified in
[box-decoration-break](https://www.w3.org/TR/css-break-4/#propdef-box-decoration-break).

Shadows do not trigger scrolling or increase the size of the scrollable
area.

Outer shadows have no effect on internal table elements in the
collapsing border model. If a shadow is defined for single border edge
in the collapsing border model that has multiple border thicknesses
(e.g. an outer shadow on a table where one row has thicker borders than
the others, or an inner shadow on a rowspanning table cell that adjoins
cells with different border thicknesses), the exact position and
rendering of its shadows are undefined.

## 7. Border Shaping

While
[corner-shape](#propdef-corner-shape) and
[border-radius](#propdef-border-radius) allow some expressiveness to
styling a border, they still work with the assumption that the border is
rectangular.

The [border-shape](#propdef-border-shape) property augments these
capabilities, by enabling the author to use any [basic
shape](https://www.w3.org/TR/SVG2/shapes.html#basic-shape) to specify the path of the border.

### 7.1. The [border-shape property]
Name:

[border-shape]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

none
[\|](https://www.w3.org/TR/css-values-4/#comb-one) \[
[\<basic-shape\>](https://www.w3.org/TR/css-shapes-1/#typedef-basic-shape)
[\<geometry-box\>](https://www.w3.org/TR/css-masking-1/#typedef-geometry-box)[?](https://www.w3.org/TR/css-values-4/#mult-opt)\][{1,2}](https://www.w3.org/TR/css-values-4/#mult-num-range)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

none

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[all
elements](https://www.w3.org/TR/css-pseudo/#generated-content "Includes ::before and ::after pseudo-elements.")

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

see prose

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

list, each item a computed color

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value

The [border-shape](#propdef-border-shape) property defines custom shapes for
element borders using one or two [basic
shape](https://www.w3.org/TR/SVG2/shapes.html#basic-shape) values.

### 7.2. Syntax and Usage Modes

The [border-shape](#propdef-border-shape) property accepts either a single
[\<basic-shape\>](https://www.w3.org/TR/css-shapes-1/#typedef-basic-shape) or two
[\<basic-shape\>]s:

Single [\<basic-shape\>](https://www.w3.org/TR/css-shapes-1/#typedef-basic-shape) (Stroke mode)

: The border is rendered as a stroke along the shape's path, with the
 stroke width determined by the [relevant
 side](#relevant-side-for-border-shape)'s
 [computed](https://www.w3.org/TR/css-cascade-5/#computed-value) [border
 width](#border-width-dfn). This mode is useful for creating outlined shapes.

Two [\<basic-shape\>](https://www.w3.org/TR/css-shapes-1/#typedef-basic-shape)s (Fill mode)

: The border is rendered as the area between the two paths. The first
 shape defines the outer boundary, and the second shape defines the
 inner boundary. This mode provides precise control over the border
 region's geometry. The fill color of the border is the [relevant
 side](#relevant-side-for-border-shape)'s
 [computed](https://www.w3.org/TR/css-cascade-5/#computed-value)
 [border-color](#propdef-border-color).

### 7.3. Geometry Box References

When a
[\<geometry-box\>](https://www.w3.org/TR/css-masking-1/#typedef-geometry-box) is not explicitly provided, the
default reference box depends on the number of
[\<basic-shape\>](https://www.w3.org/TR/css-shapes-1/#typedef-basic-shape) values:

Single [\<basic-shape\>](https://www.w3.org/TR/css-shapes-1/#typedef-basic-shape)

: The
 [\<geometry-box\>](https://www.w3.org/TR/css-masking-1/#typedef-geometry-box) defaults to the
 [half-border-box](https://drafts.csswg.org/css-shapes-1/#valdef-shape-box-half-border-box) value, which positions the stroke to match
 the default border behavior, with the border extending equally
 inward and outward from the shape path.

Two [\<basic-shape\>](https://www.w3.org/TR/css-shapes-1/#typedef-basic-shape)s

: The first (outer) shape defaults to the [border
 box](https://www.w3.org/TR/css-box-4/#border-box), and the second (inner) shape defaults to the
 [padding
 box](https://www.w3.org/TR/css-box-4/#padding-box). This allows the
 [border-width](#propdef-border-width) properties to naturally affect
 the final shape.

### 7.4. Examples

Creating a circular border using
stroke mode:

```
.circular-button {
 width: 100px;
 height: 100px;
 border: 5px solid blue;
 border-shape: circle(50%);
}
```

This creates a circular border with a 5px stroke width.

Creating a diamond-shaped border using
fill mode:

```
.diamond {
 width: 200px;
 height: 200px;
 border: 10px solid crimson;
 border-shape:
 polygon(50% 0%, 100% 50%, 50% 100%, 0% 50%)
 polygon(50% 10%, 90% 50%, 50% 90%, 10% 50%);
}
```

This creates a diamond border by defining outer and inner polygons.

Using a custom path shape:

```
.custom-shape {
 border: 8px solid green;
 border-shape: path('M 10,30 A 20,20 0,0,1 50,30 A 20,20 0,0,1 90,30 Q 90,60 50,90 Q 10,60 10,30 z');
}
```

This creates a heart-shaped border using an SVG path.

Combining
[border-shape](#propdef-border-shape) with different border widths:

```
.fancy-box {
 width: 100px;
 height: 100px;
 border-top-width: 10px;
 border-right-width: 5px;
 border-bottom-width: 10px;
 border-left-width: 5px;
 border-style: solid;
 border-color: purple;
 border-shape: ellipse(50% 40%);
}
```

The [relevant side for border
shape](#relevant-side-for-border-shape) determines which border width is used for the stroke.

### 7.5. Interactions with Other Properties

#### 7.5.1. Interaction with [border-radius and [corner-shape](#propdef-corner-shape)]
The [border-shape](#propdef-border-shape) property is not compatible with
[border-radius](#propdef-border-radius) and
[corner-shape](#propdef-corner-shape). When an element's [computed
value](https://www.w3.org/TR/css-cascade-5/#computed-value) of [border-shape] is not [none], its
[border-radius] is ignored,
as if it was set to 0. [corner-shape] is implicitly ignored, as it can only work in tandem with
[border-radius].

 Authors should use either
[border-shape](#propdef-border-shape) for custom shapes or
[border-radius](#propdef-border-radius)/[corner-shape](#propdef-corner-shape) for rectangular boxes with styled
corners, but not both simultaneously.

#### 7.5.2. Interaction with [box-shadow]
An [outer
box-shadow](https://www.w3.org/TR/css-backgrounds-3/#box-shadow-outer-box-shadow) is cast as if the shape defined by the outer path were
opaque. An [inner
box-shadow](https://www.w3.org/TR/css-backgrounds-3/#box-shadow-inner-box-shadow) is cast as if everything outside the shape defined by
the inner path were opaque. For both inner and outer shadows, the shadow
shape is expanded or contracted by the spread distance, blurred by the
blur radius, and then clipped by the
[border-shape](#propdef-border-shape), adhering to the standard
[box-shadow](#propdef-box-shadow) painting rules.

```
.shaped-shadow {
 border-shape: circle(50%);
 box-shadow: 0 4px 8px rgba(0, 0, 0, 0.3);
}
```

The shadow follows the circular shape rather than a rectangular box.

#### 7.5.3. Interaction with Overflow and Clipping

The inner
[border-shape](#propdef-border-shape) clips the
[overflow](https://www.w3.org/TR/css-overflow-3/#overflow) content of the element, in the same manner as
[border-radius](#propdef-border-radius), as described in [corner
clipping](https://drafts.csswg.org/css-backgrounds-3/#corner-clipping).

how should this affect clipping replaced
elements?

#### 7.5.4. Interaction with Layout

[border-shape](#propdef-border-shape) does not affect geometry or layout,
which is still computed using the existing
[border-width](#propdef-border-width) properties. The shaped border is
purely a visual effect.

[border-shape](#propdef-border-shape) does not affect the flow of content
inside the box.

 An author can use
[border-shape](#propdef-border-shape) in tandem with
[shape-inside](https://drafts.csswg.org/css-shapes-2/#propdef-shape-inside) to create effects that both
decorate the box and control its text flow.

### 7.6. Determining the Relevant Side

An element's [relevant side for border
shape] is the first side (in the order
[block-start](https://www.w3.org/TR/css-writing-modes-4/#block-start),
[inline-start](https://www.w3.org/TR/css-writing-modes-4/#inline-start),
[block-end](https://www.w3.org/TR/css-writing-modes-4/#block-end), and
[inline-end](https://www.w3.org/TR/css-writing-modes-4/#inline-end)) that has a
non-[none](#valdef-line-style-none) [border
style](#border-style-dfn), or
[block-start] if they're all
[none].

1. If `element`'s
 [computed](https://www.w3.org/TR/css-cascade-5/#computed-value)
 [border-block-start-style](#propdef-border-block-start-style) is not
 [none](#valdef-line-style-none), then return
 [block-start](https://www.w3.org/TR/css-writing-modes-4/#block-start).

2. If `element`'s
 [computed](https://www.w3.org/TR/css-cascade-5/#computed-value)
 [border-inline-start-style](#propdef-border-inline-start-style) is not
 [none](#valdef-line-style-none), then return
 [inline-start](https://www.w3.org/TR/css-writing-modes-4/#inline-start).

3. If `element`'s
 [computed](https://www.w3.org/TR/css-cascade-5/#computed-value)
 [border-block-end-style](#propdef-border-block-end-style) is not
 [none](#valdef-line-style-none), then return
 [block-end](https://www.w3.org/TR/css-writing-modes-4/#block-end).

4. If `element`'s
 [computed](https://www.w3.org/TR/css-cascade-5/#computed-value)
 [border-inline-end-style](#propdef-border-inline-end-style) is not
 [none](#valdef-line-style-none), then return
 [inline-end](https://www.w3.org/TR/css-writing-modes-4/#inline-end).

5. Return
 [block-start](https://www.w3.org/TR/css-writing-modes-4/#block-start).

 This algorithm ensures consistent behavior when
multiple border sides have different styles or widths. The first
non-none border side (in logical order) determines the border
characteristics used for the shaped border.

Tests

- [border-shape-computed.html](https://wpt.fyi/results/css/css-borders/tentative/parsing/border-shape-computed.html "css/css-borders/tentative/parsing/border-shape-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-borders/tentative/parsing/border-shape-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-borders/tentative/parsing/border-shape-computed.html)
- [border-shape-invalid.html](https://wpt.fyi/results/css/css-borders/tentative/parsing/border-shape-invalid.html "css/css-borders/tentative/parsing/border-shape-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-borders/tentative/parsing/border-shape-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-borders/tentative/parsing/border-shape-invalid.html)
- [border-shape-valid.html](https://wpt.fyi/results/css/css-borders/tentative/parsing/border-shape-valid.html "css/css-borders/tentative/parsing/border-shape-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-borders/tentative/parsing/border-shape-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-borders/tentative/parsing/border-shape-valid.html)

## [Privacy Considerations]
No new privacy considerations have been reported on this specification.

## [Security Considerations]
No new security considerations have been reported on this specification.

## [ Changes]
### [ Changes since the [First Public Working Draft](https://www.w3.org/TR/2025/WD-css-borders-4-20250722/) of 22 July 2025 ]
- Added [corner-\*] shorthands

- Renamed `corners` to
 [corner](#propdef-corner)

- Added Web Platform Tests coverage

- Incorporated full text of
 [\[CSS3BG\]](#biblio-css3bg "CSS Backgrounds and Borders Module Level 3")
 related to borders and shadows

- Renamed [border-clip-\*] properties to [border-\*-clip]
 and added logical longhands and shorthands

- Renamed [normal] value of [border-\*-clip] properties to
 [none]

- Added new syntax for [border-\*-\*-radius] longhands using a
 slash to separate horizontal and vertical radii

- Allowed a single
 [\<length\>](https://www.w3.org/TR/css-values-4/#length-value) value for
 [box-shadow-offset](#propdef-box-shadow-offset) to set both offsets to the same
 value

- Changed the special case of
 [border-width](#propdef-border-width) having a value of [0] when
 [border-style](#propdef-border-style) is
 [none](#valdef-line-style-none) or
 [hidden](#valdef-line-style-hidden) from a computed-value effect to a
 resolved-value effect. ([Issue
 11494](https://github.com/w3c/csswg-drafts/issues/11494))

### [ Additions since [\[CSS3BG\]](#biblio-css3bg "CSS Backgrounds and Borders Module Level 3")]
- [\<image-1D\>](https://www.w3.org/TR/css-images-4/#typedef-image-1d) as value for
 [border-color](#propdef-border-color) and its longhands

- Added physical and logical [border-\*-radius] shorthands

- Added
 [corner-shape](#propdef-corner-shape) and [corner-\*-shape]
 shorthands, plus related
 [corner](#propdef-corner) and [corner-\*] shorthands

- Added
 [border-shape](#propdef-border-shape)

- Added [partial borders](#partial-borders) via
 [border-limit](#propdef-border-limit) and [border-\*-clip]
 properties

- Added [box-shadow-\*] longhands and turned
 [box-shadow](#propdef-box-shadow) into a shorthand

- Moved logical border properties from
 [\[CSS-LOGICAL-1\]](#biblio-css-logical-1 "CSS Logical Properties and Values Module Level 1")
 to this spec.

## [ Acknowledgments]
In addition to the many contributors to the
[\[CSS1\]](#biblio-css1 "Cascading Style Sheets, level 1"),
[\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification"),
and
[\[CSS3BG\]](#biblio-css3bg "CSS Backgrounds and Borders Module Level 3")
predecessors to this module, the editors would like to thank Tab Atkins,
Noam Rosenthal, Håkon Wium Lie, Oriol Brufau, and Guillaume Lebas for
their suggestions and feedback specifically for this Level 4.
