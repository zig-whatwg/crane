## 1. Introduction

*This subsection is not normative.*

When elements are rendered according to the [CSS box
model](https://www.w3.org/TR/css-box-3/#box-model)
[\[CSS-BOX-3\]](#biblio-css-box-3 "CSS Box Model Module Level 3"),
each element is either not displayed at all, or formatted as one or more
rectangular boxes. Each box has a rectangular [content
area](https://drafts.csswg.org/css-box-4/#content-area), a band of
[padding](https://drafts.csswg.org/css-box-4/#padding) around the content, a
[border](https://drafts.csswg.org/css-box-4/#border) around the padding, and a
[margin](https://drafts.csswg.org/css-box-4/#margin) outside the border. (The margin may actually be
negative, but margins have no influence on the background and border.)

![The various areas and edges of a typical box. (This diagram is
explained in the CSS Box Model Module
[\[CSS-BOX-3\]](#biblio-css-box-3 "CSS Box Model Module Level 3").)](images/box.png){a
height="278" width="458"}

The properties of this module deal with the decoration of the [border
area](https://drafts.csswg.org/css-box-4/#border-area) and with the background of the
[content](https://drafts.csswg.org/css-box-4/#content-area),
[padding](https://drafts.csswg.org/css-box-4/#padding-area), and [border] areas.
Additionally the box may be given a "drop-shadow" effect with the
[box-shadow](#propdef-box-shadow) property.

If an element is broken into multiple [box
fragments](https://drafts.csswg.org/css-break-4/#box-fragment),
[box-decoration-break](https://drafts.csswg.org/css-break-4/#propdef-box-decoration-break)
[\[CSS-BREAK-3\]](#biblio-css-break-3 "CSS Fragmentation Module Level 3")
defines how the borders and background are divided over the various
fragments. (An element can result in more than one fragment if it is
broken at the end of a line, at the end of a column or at the end of a
page; and continued in the next line, column or page.)

The relative stacking order of backgrounds, borders, and shadows is
given in this module. For how these layers interact with other rendered
content, see Appendix E "Elaborate description of Stacking Contexts" in
[\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification").

### 1.1. Module Interactions

This module replaces and extends the background and border features
defined in
[\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")
sections 8.5 and 14.2.

All properties in this module apply to the
[::first-letter](https://drafts.csswg.org/selectors-3/#first-letter0)
[pseudo-element](https://drafts.csswg.org/selectors-4/#pseudo-element). The [background properties](#backgrounds) and
[border-radius properties](#corners) also apply to the
[::first-line](https://drafts.csswg.org/selectors-3/#sel-first-line) [pseudo-element]. The
UA may (but is not required to) apply the
[border-image](#propdef-border-image) or
[box-shadow](#propdef-box-shadow) properties to
[::first-line]. The UA must not apply the
[border-color/style/width properties](#borders) to
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
[background-image](#propdef-background-image) or
[border-image](#propdef-border-image) values.
[\[CSS-IMAGES-3\]](#biblio-css-images-3 "CSS Images Module Level 3")

In addition to the property-specific values listed in their definitions,
all properties defined in this specification also accept the [CSS-wide
keywords](https://drafts.csswg.org/css-values-4/#css-wide-keywords) as their property value. For readability they have not
been repeated explicitly.

## 2. Backgrounds

Each box has a background layer that may be fully transparent (the
default), or filled with a color and/or one or more images. The
background properties specify what color
([background-color](#propdef-background-color)) and images
([background-image](#propdef-background-image)) to use, and how they are sized,
positioned, tiled, etc.

The background properties are not inherited, but the parent box's
background will shine through by default because of the initial
[transparent](https://drafts.csswg.org/css-color-4/#valdef-color-transparent) value on
[background-color](#propdef-background-color).

### 2.1. Layering Multiple Background Images

The background of a box can have multiple [background image
layers]. The number of
layers is determined by the number of comma-separated values in the
[background-image](#propdef-background-image) property. Note that a value of
[none](#valdef-background-image-none) still creates a layer.

Tests

- [background-none-none-and-color.html](https://wpt.fyi/results/css/css-backgrounds/background-none-none-and-color.html "css/css-backgrounds/background-none-none-and-color.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-none-none-and-color.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-none-none-and-color.html)
- [order-of-images.htm](https://wpt.fyi/results/css/css-backgrounds/order-of-images.htm "css/css-backgrounds/order-of-images.htm")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/order-of-images.htm)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/order-of-images.htm)
- [scroll-positioned-multiple-background-images.html](https://wpt.fyi/results/css/css-backgrounds/scroll-positioned-multiple-background-images.html "css/css-backgrounds/scroll-positioned-multiple-background-images.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/scroll-positioned-multiple-background-images.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/scroll-positioned-multiple-background-images.html)

Each of the [background
images](#background-images)
is sized, positioned, and tiled according to the corresponding value in
the other background properties. The lists are matched up from the first
value: excess values at the end are not used. If a property doesn't have
enough comma-separated values to match the number of layers, the
[UA](https://drafts.csswg.org/css-2023/#user-agent) must calculate its [used
value](https://drafts.csswg.org/css-cascade-5/#used-value) by repeating the list of values until there are enough.

For example, this set of declarations:

 background-image: url(flower.png), url(ball.png), url(grass.png);
 background-position: center center, 20% 80%, top left, bottom right;
 background-origin: border-box, content-box;
 background-repeat: no-repeat;

has exactly the same effect as this set, with the extra position dropped
and the missing values for
[background-origin](#propdef-background-origin) and
[background-repeat](#propdef-background-repeat) filled in (emphasized for clarity):

 background-image: url(flower.png), url(ball.png), url(grass.png);
 background-position: center center, 20% 80%, top left;
 background-origin: border-box, content-box, border-box;
 background-repeat: no-repeat, no-repeat, no-repeat;

The first image in the list is the
[layer](#background-image-layer) closest to the user, the next one is painted behind the
first, and so on. The background color, if present, is painted below all
of the other [layers].

 The [border-image properties](#border-images) can also
define a background image, which, if present, is painted on top of the
background
[layers](#background-image-layer) created by the background properties.

### 2.2. Base Color: the [background-color property]
Name:

[background-color]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<color\>](https://drafts.csswg.org/css-color-5/#typedef-color)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

transparent

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[all
elements](https://www.w3.org/TR/css-pseudo/#generated-content "Includes ::before and ::after pseudo-elements.")

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

N/A

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

computed color

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value

Tests

- [background-color-animation-backdrop-infinite-duration-crash.html](https://wpt.fyi/results/css/css-backgrounds/animations/background-color-animation-backdrop-infinite-duration-crash.html "css/css-backgrounds/animations/background-color-animation-backdrop-infinite-duration-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/animations/background-color-animation-backdrop-infinite-duration-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/animations/background-color-animation-backdrop-infinite-duration-crash.html)
- [background-color-animation-element-not-visible-at-current-viewport.html](https://wpt.fyi/results/css/css-backgrounds/animations/background-color-animation-element-not-visible-at-current-viewport.html "css/css-backgrounds/animations/background-color-animation-element-not-visible-at-current-viewport.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/animations/background-color-animation-element-not-visible-at-current-viewport.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/animations/background-color-animation-element-not-visible-at-current-viewport.html)
- [background-color-animation-fallback-additive-keyframe.html](https://wpt.fyi/results/css/css-backgrounds/animations/background-color-animation-fallback-additive-keyframe.html "css/css-backgrounds/animations/background-color-animation-fallback-additive-keyframe.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/animations/background-color-animation-fallback-additive-keyframe.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/animations/background-color-animation-fallback-additive-keyframe.html)
- [background-color-animation-fallback-missing-0-percent.html](https://wpt.fyi/results/css/css-backgrounds/animations/background-color-animation-fallback-missing-0-percent.html "css/css-backgrounds/animations/background-color-animation-fallback-missing-0-percent.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/animations/background-color-animation-fallback-missing-0-percent.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/animations/background-color-animation-fallback-missing-0-percent.html)
- [background-color-animation-fallback-missing-100-percent.html](https://wpt.fyi/results/css/css-backgrounds/animations/background-color-animation-fallback-missing-100-percent.html "css/css-backgrounds/animations/background-color-animation-fallback-missing-100-percent.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/animations/background-color-animation-fallback-missing-100-percent.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/animations/background-color-animation-fallback-missing-100-percent.html)
- [background-color-animation-fallback-replace.html](https://wpt.fyi/results/css/css-backgrounds/animations/background-color-animation-fallback-replace.html "css/css-backgrounds/animations/background-color-animation-fallback-replace.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/animations/background-color-animation-fallback-replace.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/animations/background-color-animation-fallback-replace.html)
- [background-color-animation-field-crash.html](https://wpt.fyi/results/css/css-backgrounds/animations/background-color-animation-field-crash.html "css/css-backgrounds/animations/background-color-animation-field-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/animations/background-color-animation-field-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/animations/background-color-animation-field-crash.html)
- [background-color-animation-fragmented.html](https://wpt.fyi/results/css/css-backgrounds/animations/background-color-animation-fragmented.html "css/css-backgrounds/animations/background-color-animation-fragmented.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/animations/background-color-animation-fragmented.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/animations/background-color-animation-fragmented.html)
- [background-color-animation-half-opaque.html](https://wpt.fyi/results/css/css-backgrounds/animations/background-color-animation-half-opaque.html "css/css-backgrounds/animations/background-color-animation-half-opaque.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/animations/background-color-animation-half-opaque.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/animations/background-color-animation-half-opaque.html)
- [background-color-animation-in-body.html](https://wpt.fyi/results/css/css-backgrounds/animations/background-color-animation-in-body.html "css/css-backgrounds/animations/background-color-animation-in-body.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/animations/background-color-animation-in-body.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/animations/background-color-animation-in-body.html)
- [background-color-animation-non-empty-no-draw-crash.html](https://wpt.fyi/results/css/css-backgrounds/animations/background-color-animation-non-empty-no-draw-crash.html "css/css-backgrounds/animations/background-color-animation-non-empty-no-draw-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/animations/background-color-animation-non-empty-no-draw-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/animations/background-color-animation-non-empty-no-draw-crash.html)
- [background-color-animation-non-zero-size-element-change-to-zero.html](https://wpt.fyi/results/css/css-backgrounds/animations/background-color-animation-non-zero-size-element-change-to-zero.html "css/css-backgrounds/animations/background-color-animation-non-zero-size-element-change-to-zero.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/animations/background-color-animation-non-zero-size-element-change-to-zero.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/animations/background-color-animation-non-zero-size-element-change-to-zero.html)
- [background-color-animation-pseudo-element.html](https://wpt.fyi/results/css/css-backgrounds/animations/background-color-animation-pseudo-element.html "css/css-backgrounds/animations/background-color-animation-pseudo-element.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/animations/background-color-animation-pseudo-element.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/animations/background-color-animation-pseudo-element.html)
- [background-color-animation-removed-element-crash.html](https://wpt.fyi/results/css/css-backgrounds/animations/background-color-animation-removed-element-crash.html "css/css-backgrounds/animations/background-color-animation-removed-element-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/animations/background-color-animation-removed-element-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/animations/background-color-animation-removed-element-crash.html)
- [background-color-animation-single-keyframe.html](https://wpt.fyi/results/css/css-backgrounds/animations/background-color-animation-single-keyframe.html "css/css-backgrounds/animations/background-color-animation-single-keyframe.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/animations/background-color-animation-single-keyframe.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/animations/background-color-animation-single-keyframe.html)
- [background-color-animation-three-keyframes1.html](https://wpt.fyi/results/css/css-backgrounds/animations/background-color-animation-three-keyframes1.html "css/css-backgrounds/animations/background-color-animation-three-keyframes1.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/animations/background-color-animation-three-keyframes1.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/animations/background-color-animation-three-keyframes1.html)
- [background-color-animation-three-keyframes2.html](https://wpt.fyi/results/css/css-backgrounds/animations/background-color-animation-three-keyframes2.html "css/css-backgrounds/animations/background-color-animation-three-keyframes2.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/animations/background-color-animation-three-keyframes2.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/animations/background-color-animation-three-keyframes2.html)
- [background-color-animation-three-keyframes3.html](https://wpt.fyi/results/css/css-backgrounds/animations/background-color-animation-three-keyframes3.html "css/css-backgrounds/animations/background-color-animation-three-keyframes3.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/animations/background-color-animation-three-keyframes3.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/animations/background-color-animation-three-keyframes3.html)
- [background-color-animation-will-change-contents.html](https://wpt.fyi/results/css/css-backgrounds/animations/background-color-animation-will-change-contents.html "css/css-backgrounds/animations/background-color-animation-will-change-contents.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/animations/background-color-animation-will-change-contents.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/animations/background-color-animation-will-change-contents.html)
- [background-color-animation-with-blur.html](https://wpt.fyi/results/css/css-backgrounds/animations/background-color-animation-with-blur.html "css/css-backgrounds/animations/background-color-animation-with-blur.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/animations/background-color-animation-with-blur.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/animations/background-color-animation-with-blur.html)
- [background-color-animation-with-images.html](https://wpt.fyi/results/css/css-backgrounds/animations/background-color-animation-with-images.html "css/css-backgrounds/animations/background-color-animation-with-images.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/animations/background-color-animation-with-images.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/animations/background-color-animation-with-images.html)
- [background-color-animation-with-mask.html](https://wpt.fyi/results/css/css-backgrounds/animations/background-color-animation-with-mask.html "css/css-backgrounds/animations/background-color-animation-with-mask.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/animations/background-color-animation-with-mask.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/animations/background-color-animation-with-mask.html)
- [background-color-animation-with-table1.html](https://wpt.fyi/results/css/css-backgrounds/animations/background-color-animation-with-table1.html "css/css-backgrounds/animations/background-color-animation-with-table1.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/animations/background-color-animation-with-table1.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/animations/background-color-animation-with-table1.html)
- [background-color-animation-with-table2.html](https://wpt.fyi/results/css/css-backgrounds/animations/background-color-animation-with-table2.html "css/css-backgrounds/animations/background-color-animation-with-table2.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/animations/background-color-animation-with-table2.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/animations/background-color-animation-with-table2.html)
- [background-color-animation-with-table3.html](https://wpt.fyi/results/css/css-backgrounds/animations/background-color-animation-with-table3.html "css/css-backgrounds/animations/background-color-animation-with-table3.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/animations/background-color-animation-with-table3.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/animations/background-color-animation-with-table3.html)
- [background-color-animation-with-table4.html](https://wpt.fyi/results/css/css-backgrounds/animations/background-color-animation-with-table4.html "css/css-backgrounds/animations/background-color-animation-with-table4.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/animations/background-color-animation-with-table4.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/animations/background-color-animation-with-table4.html)
- [background-color-animation-with-zero-playbackRate.html](https://wpt.fyi/results/css/css-backgrounds/animations/background-color-animation-with-zero-playbackRate.html "css/css-backgrounds/animations/background-color-animation-with-zero-playbackRate.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/animations/background-color-animation-with-zero-playbackRate.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/animations/background-color-animation-with-zero-playbackRate.html)
- [background-color-animation-zero-size-element-change-to-non-zero.html](https://wpt.fyi/results/css/css-backgrounds/animations/background-color-animation-zero-size-element-change-to-non-zero.html "css/css-backgrounds/animations/background-color-animation-zero-size-element-change-to-non-zero.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/animations/background-color-animation-zero-size-element-change-to-non-zero.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/animations/background-color-animation-zero-size-element-change-to-non-zero.html)
- [background-color-animation-zero-size-element.html](https://wpt.fyi/results/css/css-backgrounds/animations/background-color-animation-zero-size-element.html "css/css-backgrounds/animations/background-color-animation-zero-size-element.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/animations/background-color-animation-zero-size-element.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/animations/background-color-animation-zero-size-element.html)
- [background-color-animation.html](https://wpt.fyi/results/css/css-backgrounds/animations/background-color-animation.html "css/css-backgrounds/animations/background-color-animation.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/animations/background-color-animation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/animations/background-color-animation.html)
- [background-color-interpolation.html](https://wpt.fyi/results/css/css-backgrounds/animations/background-color-interpolation.html "css/css-backgrounds/animations/background-color-interpolation.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/animations/background-color-interpolation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/animations/background-color-interpolation.html)
- [background-color-scroll-into-viewport.html](https://wpt.fyi/results/css/css-backgrounds/animations/background-color-scroll-into-viewport.html "css/css-backgrounds/animations/background-color-scroll-into-viewport.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/animations/background-color-scroll-into-viewport.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/animations/background-color-scroll-into-viewport.html)
- [background-color-transition-colormix.html](https://wpt.fyi/results/css/css-backgrounds/animations/background-color-transition-colormix.html "css/css-backgrounds/animations/background-color-transition-colormix.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/animations/background-color-transition-colormix.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/animations/background-color-transition-colormix.html)
- [background-color-transition-currentcolor.html](https://wpt.fyi/results/css/css-backgrounds/animations/background-color-transition-currentcolor.html "css/css-backgrounds/animations/background-color-transition-currentcolor.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/animations/background-color-transition-currentcolor.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/animations/background-color-transition-currentcolor.html)
- [background-color-transition.html](https://wpt.fyi/results/css/css-backgrounds/animations/background-color-transition.html "css/css-backgrounds/animations/background-color-transition.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/animations/background-color-transition.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/animations/background-color-transition.html)
- [background-color-transparent-animation-in-body.html](https://wpt.fyi/results/css/css-backgrounds/animations/background-color-transparent-animation-in-body.html "css/css-backgrounds/animations/background-color-transparent-animation-in-body.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/animations/background-color-transparent-animation-in-body.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/animations/background-color-transparent-animation-in-body.html)
- [background-color-animation-with-zero-alpha.html](https://wpt.fyi/results/css/css-backgrounds/animations/invalidation/background-color-animation-with-zero-alpha.html "css/css-backgrounds/animations/invalidation/background-color-animation-with-zero-alpha.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/animations/invalidation/background-color-animation-with-zero-alpha.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/animations/invalidation/background-color-animation-with-zero-alpha.html)
- [background-color-transition-obscured.html](https://wpt.fyi/results/css/css-backgrounds/animations/invalidation/background-color-transition-obscured.html "css/css-backgrounds/animations/invalidation/background-color-transition-obscured.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/animations/invalidation/background-color-transition-obscured.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/animations/invalidation/background-color-transition-obscured.html)
- [background-color-transition-with-delay.html](https://wpt.fyi/results/css/css-backgrounds/animations/invalidation/background-color-transition-with-delay.html "css/css-backgrounds/animations/invalidation/background-color-transition-with-delay.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/animations/invalidation/background-color-transition-with-delay.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/animations/invalidation/background-color-transition-with-delay.html)
- [background-color-transition-with-initially-transparent.html](https://wpt.fyi/results/css/css-backgrounds/animations/invalidation/background-color-transition-with-initially-transparent.html "css/css-backgrounds/animations/invalidation/background-color-transition-with-initially-transparent.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/animations/invalidation/background-color-transition-with-initially-transparent.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/animations/invalidation/background-color-transition-with-initially-transparent.html)
- [two-background-color-animation-diff-length1.html](https://wpt.fyi/results/css/css-backgrounds/animations/two-background-color-animation-diff-length1.html "css/css-backgrounds/animations/two-background-color-animation-diff-length1.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/animations/two-background-color-animation-diff-length1.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/animations/two-background-color-animation-diff-length1.html)
- [two-background-color-animation-diff-length2.html](https://wpt.fyi/results/css/css-backgrounds/animations/two-background-color-animation-diff-length2.html "css/css-backgrounds/animations/two-background-color-animation-diff-length2.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/animations/two-background-color-animation-diff-length2.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/animations/two-background-color-animation-diff-length2.html)
- [two-background-color-animation-diff-length3.html](https://wpt.fyi/results/css/css-backgrounds/animations/two-background-color-animation-diff-length3.html "css/css-backgrounds/animations/two-background-color-animation-diff-length3.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/animations/two-background-color-animation-diff-length3.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/animations/two-background-color-animation-diff-length3.html)
- [background-none-none-and-color.html](https://wpt.fyi/results/css/css-backgrounds/background-none-none-and-color.html "css/css-backgrounds/background-none-none-and-color.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-none-none-and-color.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-none-none-and-color.html)
- [background-color-body-propagation-001.html](https://wpt.fyi/results/css/css-backgrounds/background-color-body-propagation-001.html "css/css-backgrounds/background-color-body-propagation-001.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-color-body-propagation-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-color-body-propagation-001.html)
- [background-color-body-propagation-002.html](https://wpt.fyi/results/css/css-backgrounds/background-color-body-propagation-002.html "css/css-backgrounds/background-color-body-propagation-002.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-color-body-propagation-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-color-body-propagation-002.html)
- [background-color-body-propagation-003.html](https://wpt.fyi/results/css/css-backgrounds/background-color-body-propagation-003.html "css/css-backgrounds/background-color-body-propagation-003.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-color-body-propagation-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-color-body-propagation-003.html)
- [background-color-body-propagation-004.html](https://wpt.fyi/results/css/css-backgrounds/background-color-body-propagation-004.html "css/css-backgrounds/background-color-body-propagation-004.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-color-body-propagation-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-color-body-propagation-004.html)
- [background-color-body-propagation-005.html](https://wpt.fyi/results/css/css-backgrounds/background-color-body-propagation-005.html "css/css-backgrounds/background-color-body-propagation-005.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-color-body-propagation-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-color-body-propagation-005.html)
- [background-color-body-propagation-006.html](https://wpt.fyi/results/css/css-backgrounds/background-color-body-propagation-006.html "css/css-backgrounds/background-color-body-propagation-006.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-color-body-propagation-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-color-body-propagation-006.html)
- [background-color-body-propagation-007.html](https://wpt.fyi/results/css/css-backgrounds/background-color-body-propagation-007.html "css/css-backgrounds/background-color-body-propagation-007.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-color-body-propagation-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-color-body-propagation-007.html)
- [background-color-body-propagation-008.html](https://wpt.fyi/results/css/css-backgrounds/background-color-body-propagation-008.html "css/css-backgrounds/background-color-body-propagation-008.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-color-body-propagation-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-color-body-propagation-008.html)
- [background-color-body-propagation-009.html](https://wpt.fyi/results/css/css-backgrounds/background-color-body-propagation-009.html "css/css-backgrounds/background-color-body-propagation-009.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-color-body-propagation-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-color-body-propagation-009.html)
- [background-color-clip.html](https://wpt.fyi/results/css/css-backgrounds/background-color-clip.html "css/css-backgrounds/background-color-clip.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-color-clip.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-color-clip.html)
- [background-color-root-propagation-001.html](https://wpt.fyi/results/css/css-backgrounds/background-color-root-propagation-001.html "css/css-backgrounds/background-color-root-propagation-001.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-color-root-propagation-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-color-root-propagation-001.html)
- [background-color-root-propagation-002.html](https://wpt.fyi/results/css/css-backgrounds/background-color-root-propagation-002.html "css/css-backgrounds/background-color-root-propagation-002.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-color-root-propagation-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-color-root-propagation-002.html)
- [bg-color-with-gradient.html](https://wpt.fyi/results/css/css-backgrounds/bg-color-with-gradient.html "css/css-backgrounds/bg-color-with-gradient.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/bg-color-with-gradient.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/bg-color-with-gradient.html)
- [child-move-reveals-parent-background.html](https://wpt.fyi/results/css/css-backgrounds/child-move-reveals-parent-background.html "css/css-backgrounds/child-move-reveals-parent-background.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/child-move-reveals-parent-background.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/child-move-reveals-parent-background.html)
- [color-mix-currentcolor-background-repaint-parent.html](https://wpt.fyi/results/css/css-backgrounds/color-mix-currentcolor-background-repaint-parent.html "css/css-backgrounds/color-mix-currentcolor-background-repaint-parent.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/color-mix-currentcolor-background-repaint-parent.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/color-mix-currentcolor-background-repaint-parent.html)
- [color-mix-currentcolor-background-repaint.html](https://wpt.fyi/results/css/css-backgrounds/color-mix-currentcolor-background-repaint.html "css/css-backgrounds/color-mix-currentcolor-background-repaint.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/color-mix-currentcolor-background-repaint.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/color-mix-currentcolor-background-repaint.html)
- [simple-bg-color.html](https://wpt.fyi/results/css/css-backgrounds/hidpi/simple-bg-color.html "css/css-backgrounds/hidpi/simple-bg-color.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/hidpi/simple-bg-color.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/hidpi/simple-bg-color.html)
- [inheritance.sub.html](https://wpt.fyi/results/css/css-backgrounds/inheritance.sub.html "css/css-backgrounds/inheritance.sub.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/inheritance.sub.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/inheritance.sub.html)
- [inline-background-rtl-001.html](https://wpt.fyi/results/css/css-backgrounds/inline-background-rtl-001.html "css/css-backgrounds/inline-background-rtl-001.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/inline-background-rtl-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/inline-background-rtl-001.html)
- [background-color-computed.html](https://wpt.fyi/results/css/css-backgrounds/parsing/background-color-computed.html "css/css-backgrounds/parsing/background-color-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/parsing/background-color-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/parsing/background-color-computed.html)
- [background-color-invalid.html](https://wpt.fyi/results/css/css-backgrounds/parsing/background-color-invalid.html "css/css-backgrounds/parsing/background-color-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/parsing/background-color-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/parsing/background-color-invalid.html)
- [background-color-valid.html](https://wpt.fyi/results/css/css-backgrounds/parsing/background-color-valid.html "css/css-backgrounds/parsing/background-color-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/parsing/background-color-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/parsing/background-color-valid.html)
- [color-behind-images.htm (visual test)
 ][[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/color-behind-images.htm)

This property sets the [background color] of a box. This color is drawn
behind any background images.

Example:

 h1 { background-color: #F00 } /* Sets background to red. */

The [background
color](#background-color-layer) is clipped according to the
[background-clip](#propdef-background-clip) value associated with the
bottom-most [background image
layer](#background-image-layer).

### 2.3. Image Sources: the [background-image property]
Name:

[background-image]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<bg-image\>](#typedef-bg-image)[\#](https://drafts.csswg.org/css-values-4/#mult-comma)

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

list, each item either an
[\<image\>](https://drafts.csswg.org/css-images-3/#typedef-image) or the keyword
[none](#valdef-background-image-none)

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

Tests

- [background-image-001.html](https://wpt.fyi/results/css/css-backgrounds/background-image-001.html "css/css-backgrounds/background-image-001.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-image-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-image-001.html)
- [background-image-002.html](https://wpt.fyi/results/css/css-backgrounds/background-image-002.html "css/css-backgrounds/background-image-002.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-image-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-image-002.html)
- [background-image-003.html](https://wpt.fyi/results/css/css-backgrounds/background-image-003.html "css/css-backgrounds/background-image-003.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-image-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-image-003.html)
- [background-image-004.html](https://wpt.fyi/results/css/css-backgrounds/background-image-004.html "css/css-backgrounds/background-image-004.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-image-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-image-004.html)
- [background-image-005.html](https://wpt.fyi/results/css/css-backgrounds/background-image-005.html "css/css-backgrounds/background-image-005.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-image-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-image-005.html)
- [background-image-006.html](https://wpt.fyi/results/css/css-backgrounds/background-image-006.html "css/css-backgrounds/background-image-006.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-image-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-image-006.html)
- [background-image-007.html](https://wpt.fyi/results/css/css-backgrounds/background-image-007.html "css/css-backgrounds/background-image-007.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-image-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-image-007.html)
- [background-image-centered-with-border-radius.html](https://wpt.fyi/results/css/css-backgrounds/background-image-centered-with-border-radius.html "css/css-backgrounds/background-image-centered-with-border-radius.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-image-centered-with-border-radius.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-image-centered-with-border-radius.html)
- [background-image-centered.html](https://wpt.fyi/results/css/css-backgrounds/background-image-centered.html "css/css-backgrounds/background-image-centered.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-image-centered.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-image-centered.html)
- [background-image-cors-no-reload.html](https://wpt.fyi/results/css/css-backgrounds/background-image-cors-no-reload.html "css/css-backgrounds/background-image-cors-no-reload.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-image-cors-no-reload.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-image-cors-no-reload.html)
- [background-image-cover-zoomed-1.html](https://wpt.fyi/results/css/css-backgrounds/background-image-cover-zoomed-1.html "css/css-backgrounds/background-image-cover-zoomed-1.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-image-cover-zoomed-1.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-image-cover-zoomed-1.html)
- [background-image-first-letter.html](https://wpt.fyi/results/css/css-backgrounds/background-image-first-letter.html "css/css-backgrounds/background-image-first-letter.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-image-first-letter.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-image-first-letter.html)
- [background-image-first-line.html](https://wpt.fyi/results/css/css-backgrounds/background-image-first-line.html "css/css-backgrounds/background-image-first-line.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-image-first-line.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-image-first-line.html)
- [background-image-gradient-currentcolor-conic-repaint.html](https://wpt.fyi/results/css/css-backgrounds/background-image-gradient-currentcolor-conic-repaint.html "css/css-backgrounds/background-image-gradient-currentcolor-conic-repaint.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-image-gradient-currentcolor-conic-repaint.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-image-gradient-currentcolor-conic-repaint.html)
- [background-image-gradient-currentcolor-linear-repaint.html](https://wpt.fyi/results/css/css-backgrounds/background-image-gradient-currentcolor-linear-repaint.html "css/css-backgrounds/background-image-gradient-currentcolor-linear-repaint.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-image-gradient-currentcolor-linear-repaint.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-image-gradient-currentcolor-linear-repaint.html)
- [background-image-gradient-currentcolor-radial-repaint.html](https://wpt.fyi/results/css/css-backgrounds/background-image-gradient-currentcolor-radial-repaint.html "css/css-backgrounds/background-image-gradient-currentcolor-radial-repaint.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-image-gradient-currentcolor-radial-repaint.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-image-gradient-currentcolor-radial-repaint.html)
- [background-image-gradient-currentcolor-visited.html](https://wpt.fyi/results/css/css-backgrounds/background-image-gradient-currentcolor-visited.html "css/css-backgrounds/background-image-gradient-currentcolor-visited.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-image-gradient-currentcolor-visited.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-image-gradient-currentcolor-visited.html)
- [background-image-gradient-interpolation-repaint.html](https://wpt.fyi/results/css/css-backgrounds/background-image-gradient-interpolation-repaint.html "css/css-backgrounds/background-image-gradient-interpolation-repaint.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-image-gradient-interpolation-repaint.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-image-gradient-interpolation-repaint.html)
- [background-image-large-with-auto.html](https://wpt.fyi/results/css/css-backgrounds/background-image-large-with-auto.html "css/css-backgrounds/background-image-large-with-auto.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-image-large-with-auto.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-image-large-with-auto.html)
- [background-image-none-gradient-repaint.html](https://wpt.fyi/results/css/css-backgrounds/background-image-none-gradient-repaint.html "css/css-backgrounds/background-image-none-gradient-repaint.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-image-none-gradient-repaint.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-image-none-gradient-repaint.html)
- [background-image-shared-stylesheet.html](https://wpt.fyi/results/css/css-backgrounds/background-image-shared-stylesheet.html "css/css-backgrounds/background-image-shared-stylesheet.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-image-shared-stylesheet.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-image-shared-stylesheet.html)
- [background-image-table-cells-straddling-no-repeat.html](https://wpt.fyi/results/css/css-backgrounds/background-image-table-cells-straddling-no-repeat.html "css/css-backgrounds/background-image-table-cells-straddling-no-repeat.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-image-table-cells-straddling-no-repeat.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-image-table-cells-straddling-no-repeat.html)
- [background-image-table-cells-zoomed.html](https://wpt.fyi/results/css/css-backgrounds/background-image-table-cells-zoomed.html "css/css-backgrounds/background-image-table-cells-zoomed.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-image-table-cells-zoomed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-image-table-cells-zoomed.html)
- [background-image-with-border-radius-fidelity.html](https://wpt.fyi/results/css/css-backgrounds/background-image-with-border-radius-fidelity.html "css/css-backgrounds/background-image-with-border-radius-fidelity.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-image-with-border-radius-fidelity.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-image-with-border-radius-fidelity.html)
- [background-image-interpolation.html](https://wpt.fyi/results/css/css-backgrounds/animations/background-image-interpolation.html "css/css-backgrounds/animations/background-image-interpolation.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/animations/background-image-interpolation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/animations/background-image-interpolation.html)
- [inheritance.sub.html](https://wpt.fyi/results/css/css-backgrounds/inheritance.sub.html "css/css-backgrounds/inheritance.sub.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/inheritance.sub.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/inheritance.sub.html)
- [background-image-computed.sub.html](https://wpt.fyi/results/css/css-backgrounds/parsing/background-image-computed.sub.html "css/css-backgrounds/parsing/background-image-computed.sub.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/parsing/background-image-computed.sub.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/parsing/background-image-computed.sub.html)
- [background-image-invalid.html](https://wpt.fyi/results/css/css-backgrounds/parsing/background-image-invalid.html "css/css-backgrounds/parsing/background-image-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/parsing/background-image-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/parsing/background-image-invalid.html)
- [background-image-valid.html](https://wpt.fyi/results/css/css-backgrounds/parsing/background-image-valid.html "css/css-backgrounds/parsing/background-image-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/parsing/background-image-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/parsing/background-image-valid.html)

This property specifies the [background image(s)] of an element. Images are drawn with the first
specified one on top (closest to the user) and each subsequent image
behind the previous one. The property's value is given as a
comma-separated list of
[\<bg-image\>](#typedef-bg-image) values where

``` prod
<bg-image> = <image> | none
```

A value of [none] counts as a
[background image
layer](#background-image-layer) but draws nothing. An image that is empty (zero width
or zero height), that fails to download, or that cannot be displayed
(e.g., because it is not in a supported image format) likewise counts as
a [layer] but draws nothing.

See [§ 2.1 Layering Multiple Background Images](#layering) for how
[background-image](#propdef-background-image) interacts with other
comma-separated background properties to form each [background image
layer](#background-image-layer).

When setting a background image, authors should also specify a
[background-color](#propdef-background-color) that will preserve contrast with
the text for when the image is unavailable.

For accessibility reasons, authors should not use background images as
the sole method of conveying important information. See [Web Content
Accessibility Guideline
F3](https://www.w3.org/TR/2008/NOTE-WCAG20-TECHS-20081211/F3)
[\[WCAG20\]](#biblio-wcag20 "Web Content Accessibility Guidelines (WCAG) 2.0").
Images are not accessible in non-graphical presentations, and background
images specifically might be turned off in high-contrast display modes.

 Stylistic foreground images can be provided in CSS with
the
[content](https://drafts.csswg.org/css-content-3/#propdef-content) property. Semantically-important
foreground images should be provided in the document markup, e.g. with
the \<img\> tag in HTML.

 [Media
fragments](https://www.w3.org/TR/media-frags/#naming-space) can be used
to display a portion of an image. The [CSS
Images](https://www.w3.org/TR/css-images/) module will provide fallback
syntax for image formats and include additional controls for image
display.

Some examples specifying background
images:

 html { background-image: url("marble.svg") }
 p { background-image: none }
 div { background-image: url(tl.png), url(tr.png) }
 main { background-image: radial-gradient(at bottom right, transparent, white); }

Implementations may optimize by not downloading and drawing images that
are not visible (e.g., because they are behind other, fully opaque
images).

### 2.4. Tiling Images: the [background-repeat property]
Name:

[background-repeat]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<repeat-style\>](#typedef-repeat-style)[\#](https://drafts.csswg.org/css-values-4/#mult-comma)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

repeat

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[all
elements](https://www.w3.org/TR/css-pseudo/#generated-content "Includes ::before and ::after pseudo-elements.")

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

N/A

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

list, each item a pair of keywords, one per dimension

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

Tests

- [discrete-no-interpolation.html](https://wpt.fyi/results/css/css-backgrounds/animations/discrete-no-interpolation.html "css/css-backgrounds/animations/discrete-no-interpolation.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/animations/discrete-no-interpolation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/animations/discrete-no-interpolation.html)
- [background-repeat-round-1a.html](https://wpt.fyi/results/css/css-backgrounds/background-repeat-round-1a.html "css/css-backgrounds/background-repeat-round-1a.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-repeat-round-1a.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-repeat-round-1a.html)
- [background-repeat-round-1b.html](https://wpt.fyi/results/css/css-backgrounds/background-repeat-round-1b.html "css/css-backgrounds/background-repeat-round-1b.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-repeat-round-1b.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-repeat-round-1b.html)
- [background-repeat-round-1c.html](https://wpt.fyi/results/css/css-backgrounds/background-repeat-round-1c.html "css/css-backgrounds/background-repeat-round-1c.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-repeat-round-1c.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-repeat-round-1c.html)
- [background-repeat-round-1d.html](https://wpt.fyi/results/css/css-backgrounds/background-repeat-round-1d.html "css/css-backgrounds/background-repeat-round-1d.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-repeat-round-1d.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-repeat-round-1d.html)
- [background-repeat-round-1e.html](https://wpt.fyi/results/css/css-backgrounds/background-repeat-round-1e.html "css/css-backgrounds/background-repeat-round-1e.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-repeat-round-1e.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-repeat-round-1e.html)
- [background-repeat-round-2.html](https://wpt.fyi/results/css/css-backgrounds/background-repeat-round-2.html "css/css-backgrounds/background-repeat-round-2.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-repeat-round-2.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-repeat-round-2.html)
- [background-repeat-round-3.html](https://wpt.fyi/results/css/css-backgrounds/background-repeat-round-3.html "css/css-backgrounds/background-repeat-round-3.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-repeat-round-3.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-repeat-round-3.html)
- [background-repeat-round-4.html](https://wpt.fyi/results/css/css-backgrounds/background-repeat-round-4.html "css/css-backgrounds/background-repeat-round-4.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-repeat-round-4.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-repeat-round-4.html)
- [background-repeat-space-10.html](https://wpt.fyi/results/css/css-backgrounds/background-repeat-space-10.html "css/css-backgrounds/background-repeat-space-10.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-repeat-space-10.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-repeat-space-10.html)
- [background-repeat-space-1a.html](https://wpt.fyi/results/css/css-backgrounds/background-repeat-space-1a.html "css/css-backgrounds/background-repeat-space-1a.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-repeat-space-1a.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-repeat-space-1a.html)
- [background-repeat-space-1b.html](https://wpt.fyi/results/css/css-backgrounds/background-repeat-space-1b.html "css/css-backgrounds/background-repeat-space-1b.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-repeat-space-1b.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-repeat-space-1b.html)
- [background-repeat-space-1c.html](https://wpt.fyi/results/css/css-backgrounds/background-repeat-space-1c.html "css/css-backgrounds/background-repeat-space-1c.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-repeat-space-1c.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-repeat-space-1c.html)
- [background-repeat-space-2.html](https://wpt.fyi/results/css/css-backgrounds/background-repeat-space-2.html "css/css-backgrounds/background-repeat-space-2.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-repeat-space-2.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-repeat-space-2.html)
- [background-repeat-space-3.html](https://wpt.fyi/results/css/css-backgrounds/background-repeat-space-3.html "css/css-backgrounds/background-repeat-space-3.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-repeat-space-3.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-repeat-space-3.html)
- [background-repeat-space-4.html](https://wpt.fyi/results/css/css-backgrounds/background-repeat-space-4.html "css/css-backgrounds/background-repeat-space-4.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-repeat-space-4.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-repeat-space-4.html)
- [background-repeat-space-5.html](https://wpt.fyi/results/css/css-backgrounds/background-repeat-space-5.html "css/css-backgrounds/background-repeat-space-5.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-repeat-space-5.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-repeat-space-5.html)
- [background-repeat-space-6.html](https://wpt.fyi/results/css/css-backgrounds/background-repeat-space-6.html "css/css-backgrounds/background-repeat-space-6.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-repeat-space-6.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-repeat-space-6.html)
- [background-repeat-space-7.html](https://wpt.fyi/results/css/css-backgrounds/background-repeat-space-7.html "css/css-backgrounds/background-repeat-space-7.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-repeat-space-7.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-repeat-space-7.html)
- [background-repeat-space-8.html](https://wpt.fyi/results/css/css-backgrounds/background-repeat-space-8.html "css/css-backgrounds/background-repeat-space-8.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-repeat-space-8.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-repeat-space-8.html)
- [background-repeat-space-9.html](https://wpt.fyi/results/css/css-backgrounds/background-repeat-space-9.html "css/css-backgrounds/background-repeat-space-9.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-repeat-space-9.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-repeat-space-9.html)
- [background-repeat-no-repeat.xht](https://wpt.fyi/results/css/css-backgrounds/background-repeat/background-repeat-no-repeat.xht "css/css-backgrounds/background-repeat/background-repeat-no-repeat.xht")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-repeat/background-repeat-no-repeat.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-repeat/background-repeat-no-repeat.xht)
- [background-repeat-repeat-x.xht](https://wpt.fyi/results/css/css-backgrounds/background-repeat/background-repeat-repeat-x.xht "css/css-backgrounds/background-repeat/background-repeat-repeat-x.xht")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-repeat/background-repeat-repeat-x.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-repeat/background-repeat-repeat-x.xht)
- [background-repeat-repeat-y.xht](https://wpt.fyi/results/css/css-backgrounds/background-repeat/background-repeat-repeat-y.xht "css/css-backgrounds/background-repeat/background-repeat-repeat-y.xht")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-repeat/background-repeat-repeat-y.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-repeat/background-repeat-repeat-y.xht)
- [background-repeat-round-roundup.xht](https://wpt.fyi/results/css/css-backgrounds/background-repeat/background-repeat-round-roundup.xht "css/css-backgrounds/background-repeat/background-repeat-round-roundup.xht")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-repeat/background-repeat-round-roundup.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-repeat/background-repeat-round-roundup.xht)
- [background-repeat-round.xht](https://wpt.fyi/results/css/css-backgrounds/background-repeat/background-repeat-round.xht "css/css-backgrounds/background-repeat/background-repeat-round.xht")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-repeat/background-repeat-round.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-repeat/background-repeat-round.xht)
- [background-repeat-space.xht](https://wpt.fyi/results/css/css-backgrounds/background-repeat/background-repeat-space.xht "css/css-backgrounds/background-repeat/background-repeat-space.xht")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-repeat/background-repeat-space.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-repeat/background-repeat-space.xht)
- [gradient-repeat-spaced-with-borders.html](https://wpt.fyi/results/css/css-backgrounds/background-repeat/gradient-repeat-spaced-with-borders.html "css/css-backgrounds/background-repeat/gradient-repeat-spaced-with-borders.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-repeat/gradient-repeat-spaced-with-borders.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-repeat/gradient-repeat-spaced-with-borders.html)
- [inheritance.sub.html](https://wpt.fyi/results/css/css-backgrounds/inheritance.sub.html "css/css-backgrounds/inheritance.sub.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/inheritance.sub.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/inheritance.sub.html)
- [background-repeat-computed.html](https://wpt.fyi/results/css/css-backgrounds/parsing/background-repeat-computed.html "css/css-backgrounds/parsing/background-repeat-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/parsing/background-repeat-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/parsing/background-repeat-computed.html)
- [background-repeat-invalid.html](https://wpt.fyi/results/css/css-backgrounds/parsing/background-repeat-invalid.html "css/css-backgrounds/parsing/background-repeat-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/parsing/background-repeat-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/parsing/background-repeat-invalid.html)
- [background-repeat-valid.html](https://wpt.fyi/results/css/css-backgrounds/parsing/background-repeat-valid.html "css/css-backgrounds/parsing/background-repeat-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/parsing/background-repeat-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/parsing/background-repeat-valid.html)
- [subpixel-repeat-no-repeat-mix.html](https://wpt.fyi/results/css/css-backgrounds/subpixel-repeat-no-repeat-mix.html "css/css-backgrounds/subpixel-repeat-no-repeat-mix.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/subpixel-repeat-no-repeat-mix.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/subpixel-repeat-no-repeat-mix.html)

This property specifies how [background
images](#background-images)
are tiled after they have been [sized](#background-size) and
[positioned](#background-position). The property's value is given as a
comma-separated list of
[\<repeat-style\>](#typedef-repeat-style) values where

``` prod
<repeat-style> = repeat-x | repeat-y | [repeat | space | round | no-repeat]{1,2}
```

Single values for
[\<repeat-style\>](#typedef-repeat-style) have the following meanings:

[repeat-x]
: Computes to [repeat no-repeat].

[repeat-y]
: Computes to [no-repeat repeat].

[repeat](#valdef-background-repeat-repeat)
: Computes to [repeat repeat].

[space](#valdef-background-repeat-space)
: Computes to [space space]

[round](#valdef-background-repeat-round)
: Computes to [round round]

[no-repeat](#valdef-background-repeat-no-repeat)
: Computes to [no-repeat no-repeat]

If a
[\<repeat-style\>](#typedef-repeat-style) value has two keywords, the first one
applies to the horizontal axis, the second to the vertical one, as
follows:

[repeat]
: The [image](#background-images) is repeated in this direction as often as needed to
 cover the [background painting
 area](#background-painting-area).

[space]
: The [image](#background-images) is repeated as often as will fit within the
 [background positioning
 area](#background-positioning-area) without being clipped, and then the images are
 spaced out to fill the area. The first and last images touch the
 edges of the area. If the [background painting
 area](#background-painting-area) is larger than the [background positioning
 area], then the pattern
 repeats to fill the background painting area. The value of
 [background-position](#propdef-background-position) for this direction is ignored
 unless there is not enough space for two copies of the image in this
 axis, in which case only one image is placed, and
 [background-position] determines its position in this axis.

[round]
: The [image](#background-images) is repeated as often as will fit within the
 [background positioning
 area](#background-positioning-area). If it doesn't fit a whole number of times, it is
 rescaled so that it does. See the formula under
 [background-size](#propdef-background-size). If the [background painting
 area](#background-painting-area) is larger than the background positioning area,
 then the pattern repeats to fill the background painting area.

[no-repeat]
: The [image](#background-images) is placed once and not repeated in this direction.

Unless one of the two keywords is
[no-repeat](#valdef-background-repeat-no-repeat), the whole [background painting
area](#background-painting-area) will be tiled, i.e., not just one vertical strip and
one horizontal strip.

body {
 background: white url("pendant.png");
 background-repeat: repeat-y;
 background-position: center;
 }

![The effect of
[repeat-y](#valdef-background-repeat-repeat-y): One copy of the background image is centered,
and other copies are put above and below it to make a vertical band
behind the
element.](images/bg-repeat.png){a
height="334" width="243"}

body {
 background-image: url(dot.png) white;
 background-repeat: space
 }

![The effect of
[space](#valdef-background-repeat-space): the image of a dot is tiled to cover the whole
background and the images are equally
spaced.](images/bg-space.png){a
height="365" width="250"}

See [§ 2.1 Layering Multiple Background Images](#layering) for how
[background-repeat](#propdef-background-repeat) interacts with other
comma-separated background properties to form each [background image
layer](#background-image-layer).

### 2.5. Affixing Images: the [background-attachment property]
Name:

[background-attachment]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<attachment\>](#typedef-attachment)[\#](https://drafts.csswg.org/css-values-4/#mult-comma)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

scroll

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[all
elements](https://www.w3.org/TR/css-pseudo/#generated-content "Includes ::before and ::after pseudo-elements.")

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

N/A

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

list, each item the keyword as specified

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

Tests

- [discrete-no-interpolation.html](https://wpt.fyi/results/css/css-backgrounds/animations/discrete-no-interpolation.html "css/css-backgrounds/animations/discrete-no-interpolation.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/animations/discrete-no-interpolation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/animations/discrete-no-interpolation.html)
- [background-attachment-350.html](https://wpt.fyi/results/css/css-backgrounds/background-attachment-350.html "css/css-backgrounds/background-attachment-350.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-attachment-350.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-attachment-350.html)
- [background-attachment-353.html](https://wpt.fyi/results/css/css-backgrounds/background-attachment-353.html "css/css-backgrounds/background-attachment-353.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-attachment-353.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-attachment-353.html)
- [background-attachment-fixed-block-002.html](https://wpt.fyi/results/css/css-backgrounds/background-attachment-fixed-block-002.html "css/css-backgrounds/background-attachment-fixed-block-002.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-attachment-fixed-block-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-attachment-fixed-block-002.html)
- [background-attachment-fixed-border-radius-offset.html](https://wpt.fyi/results/css/css-backgrounds/background-attachment-fixed-border-radius-offset.html "css/css-backgrounds/background-attachment-fixed-border-radius-offset.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-attachment-fixed-border-radius-offset.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-attachment-fixed-border-radius-offset.html)
- [background-attachment-fixed-inline-002.html](https://wpt.fyi/results/css/css-backgrounds/background-attachment-fixed-inline-002.html "css/css-backgrounds/background-attachment-fixed-inline-002.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-attachment-fixed-inline-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-attachment-fixed-inline-002.html)
- [background-attachment-fixed-inline-scrolled.html](https://wpt.fyi/results/css/css-backgrounds/background-attachment-fixed-inline-scrolled.html "css/css-backgrounds/background-attachment-fixed-inline-scrolled.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-attachment-fixed-inline-scrolled.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-attachment-fixed-inline-scrolled.html)
- [background-attachment-fixed-inside-transform-1.html](https://wpt.fyi/results/css/css-backgrounds/background-attachment-fixed-inside-transform-1.html "css/css-backgrounds/background-attachment-fixed-inside-transform-1.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-attachment-fixed-inside-transform-1.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-attachment-fixed-inside-transform-1.html)
- [background-attachment-local-block-002.html](https://wpt.fyi/results/css/css-backgrounds/background-attachment-local-block-002.html "css/css-backgrounds/background-attachment-local-block-002.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-attachment-local-block-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-attachment-local-block-002.html)
- [background-attachment-local-hidden.html](https://wpt.fyi/results/css/css-backgrounds/background-attachment-local-hidden.html "css/css-backgrounds/background-attachment-local-hidden.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-attachment-local-hidden.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-attachment-local-hidden.html)
- [attachment-local-clipping-color-1.html](https://wpt.fyi/results/css/css-backgrounds/background-attachment-local/attachment-local-clipping-color-1.html "css/css-backgrounds/background-attachment-local/attachment-local-clipping-color-1.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-attachment-local/attachment-local-clipping-color-1.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-attachment-local/attachment-local-clipping-color-1.html)
- [attachment-local-clipping-color-2.html](https://wpt.fyi/results/css/css-backgrounds/background-attachment-local/attachment-local-clipping-color-2.html "css/css-backgrounds/background-attachment-local/attachment-local-clipping-color-2.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-attachment-local/attachment-local-clipping-color-2.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-attachment-local/attachment-local-clipping-color-2.html)
- [attachment-local-clipping-color-3.html](https://wpt.fyi/results/css/css-backgrounds/background-attachment-local/attachment-local-clipping-color-3.html "css/css-backgrounds/background-attachment-local/attachment-local-clipping-color-3.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-attachment-local/attachment-local-clipping-color-3.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-attachment-local/attachment-local-clipping-color-3.html)
- [attachment-local-clipping-color-4.html](https://wpt.fyi/results/css/css-backgrounds/background-attachment-local/attachment-local-clipping-color-4.html "css/css-backgrounds/background-attachment-local/attachment-local-clipping-color-4.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-attachment-local/attachment-local-clipping-color-4.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-attachment-local/attachment-local-clipping-color-4.html)
- [attachment-local-clipping-color-5.html](https://wpt.fyi/results/css/css-backgrounds/background-attachment-local/attachment-local-clipping-color-5.html "css/css-backgrounds/background-attachment-local/attachment-local-clipping-color-5.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-attachment-local/attachment-local-clipping-color-5.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-attachment-local/attachment-local-clipping-color-5.html)
- [attachment-local-clipping-color-6.html](https://wpt.fyi/results/css/css-backgrounds/background-attachment-local/attachment-local-clipping-color-6.html "css/css-backgrounds/background-attachment-local/attachment-local-clipping-color-6.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-attachment-local/attachment-local-clipping-color-6.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-attachment-local/attachment-local-clipping-color-6.html)
- [attachment-local-clipping-image-1.html](https://wpt.fyi/results/css/css-backgrounds/background-attachment-local/attachment-local-clipping-image-1.html "css/css-backgrounds/background-attachment-local/attachment-local-clipping-image-1.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-attachment-local/attachment-local-clipping-image-1.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-attachment-local/attachment-local-clipping-image-1.html)
- [attachment-local-clipping-image-2.html](https://wpt.fyi/results/css/css-backgrounds/background-attachment-local/attachment-local-clipping-image-2.html "css/css-backgrounds/background-attachment-local/attachment-local-clipping-image-2.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-attachment-local/attachment-local-clipping-image-2.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-attachment-local/attachment-local-clipping-image-2.html)
- [attachment-local-clipping-image-3.html](https://wpt.fyi/results/css/css-backgrounds/background-attachment-local/attachment-local-clipping-image-3.html "css/css-backgrounds/background-attachment-local/attachment-local-clipping-image-3.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-attachment-local/attachment-local-clipping-image-3.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-attachment-local/attachment-local-clipping-image-3.html)
- [attachment-local-clipping-image-4.html](https://wpt.fyi/results/css/css-backgrounds/background-attachment-local/attachment-local-clipping-image-4.html "css/css-backgrounds/background-attachment-local/attachment-local-clipping-image-4.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-attachment-local/attachment-local-clipping-image-4.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-attachment-local/attachment-local-clipping-image-4.html)
- [attachment-local-clipping-image-5.html](https://wpt.fyi/results/css/css-backgrounds/background-attachment-local/attachment-local-clipping-image-5.html "css/css-backgrounds/background-attachment-local/attachment-local-clipping-image-5.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-attachment-local/attachment-local-clipping-image-5.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-attachment-local/attachment-local-clipping-image-5.html)
- [attachment-local-clipping-image-6.html](https://wpt.fyi/results/css/css-backgrounds/background-attachment-local/attachment-local-clipping-image-6.html "css/css-backgrounds/background-attachment-local/attachment-local-clipping-image-6.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-attachment-local/attachment-local-clipping-image-6.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-attachment-local/attachment-local-clipping-image-6.html)
- [attachment-local-positioning-2.html](https://wpt.fyi/results/css/css-backgrounds/background-attachment-local/attachment-local-positioning-2.html "css/css-backgrounds/background-attachment-local/attachment-local-positioning-2.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-attachment-local/attachment-local-positioning-2.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-attachment-local/attachment-local-positioning-2.html)
- [attachment-local-positioning-3.html](https://wpt.fyi/results/css/css-backgrounds/background-attachment-local/attachment-local-positioning-3.html "css/css-backgrounds/background-attachment-local/attachment-local-positioning-3.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-attachment-local/attachment-local-positioning-3.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-attachment-local/attachment-local-positioning-3.html)
- [attachment-local-positioning-4.html](https://wpt.fyi/results/css/css-backgrounds/background-attachment-local/attachment-local-positioning-4.html "css/css-backgrounds/background-attachment-local/attachment-local-positioning-4.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-attachment-local/attachment-local-positioning-4.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-attachment-local/attachment-local-positioning-4.html)
- [attachment-local-positioning-5.html](https://wpt.fyi/results/css/css-backgrounds/background-attachment-local/attachment-local-positioning-5.html "css/css-backgrounds/background-attachment-local/attachment-local-positioning-5.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-attachment-local/attachment-local-positioning-5.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-attachment-local/attachment-local-positioning-5.html)
- [attachment-scroll-positioning-1.html](https://wpt.fyi/results/css/css-backgrounds/background-attachment-local/attachment-scroll-positioning-1.html "css/css-backgrounds/background-attachment-local/attachment-scroll-positioning-1.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-attachment-local/attachment-scroll-positioning-1.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-attachment-local/attachment-scroll-positioning-1.html)
- [background-attachment-margin-root-001.html](https://wpt.fyi/results/css/css-backgrounds/background-attachment-margin-root-001.html "css/css-backgrounds/background-attachment-margin-root-001.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-attachment-margin-root-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-attachment-margin-root-001.html)
- [background-attachment-margin-root-002.html](https://wpt.fyi/results/css/css-backgrounds/background-attachment-margin-root-002.html "css/css-backgrounds/background-attachment-margin-root-002.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-attachment-margin-root-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-attachment-margin-root-002.html)
- [inheritance.sub.html](https://wpt.fyi/results/css/css-backgrounds/inheritance.sub.html "css/css-backgrounds/inheritance.sub.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/inheritance.sub.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/inheritance.sub.html)
- [local-attachment-content-box-scroll.html](https://wpt.fyi/results/css/css-backgrounds/local-attachment-content-box-scroll.html "css/css-backgrounds/local-attachment-content-box-scroll.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/local-attachment-content-box-scroll.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/local-attachment-content-box-scroll.html)
- [background-attachment-computed.html](https://wpt.fyi/results/css/css-backgrounds/parsing/background-attachment-computed.html "css/css-backgrounds/parsing/background-attachment-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/parsing/background-attachment-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/parsing/background-attachment-computed.html)
- [background-attachment-invalid.html](https://wpt.fyi/results/css/css-backgrounds/parsing/background-attachment-invalid.html "css/css-backgrounds/parsing/background-attachment-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/parsing/background-attachment-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/parsing/background-attachment-invalid.html)
- [background-attachment-valid.html](https://wpt.fyi/results/css/css-backgrounds/parsing/background-attachment-valid.html "css/css-backgrounds/parsing/background-attachment-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/parsing/background-attachment-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/parsing/background-attachment-valid.html)

If [background images](#background-images) are specified, this property specifies whether they are
fixed with regard to the
[viewport](https://drafts.csswg.org/css2/#viewport%E2%91%A0)
([fixed](#valdef-background-attachment-fixed)) or scroll along with the box
([scroll](#valdef-background-attachment-scroll)) or its contents
([local](#valdef-background-attachment-local)). The property's value is given as a
comma-separated list of
[\<attachment\>](#typedef-attachment) keywords where

``` prod
<attachment> = scroll | fixed | local
```

[fixed]

: The background is fixed with regard to the viewport. In [paged
 media](https://drafts.csswg.org/mediaqueries-5/#paged-media) where there is no viewport, a
 [fixed](#valdef-background-attachment-fixed) background is fixed with respect to the
 [page box](https://www.w3.org/TR/CSS2/page.html#page-box) and
 therefore replicated on every page.

 There is only one viewport per view. Even if an box
 is a [scroll
 container](https://drafts.csswg.org/css-overflow-3/#scroll-container), a
 [fixed](#valdef-background-attachment-fixed) background doesn't move with the box.

[local]
: The background is fixed with regard to the box's contents: if the
 box has a scrolling mechanism, the background scrolls with the box's
 contents, and the [background painting
 area](#background-painting-area) and [background positioning
 area](#background-positioning-area) are relative to the [scrollable overflow
 area](https://drafts.csswg.org/css-overflow-3/#scrollable-overflow-region) of the box rather than to the border framing them.
 Because the [scrollable overflow
 area] does not include the
 [border
 area](https://drafts.csswg.org/css-box-4/#border-area), for [scroll
 containers](https://drafts.csswg.org/css-overflow-3/#scroll-container) the
 [border-box](#valdef-background-clip-border-box) value of
 [background-clip](#propdef-background-clip) may be treated the same as
 [padding-box](#valdef-background-clip-padding-box).

[scroll]
: The background is fixed with regard to the box itself and does not
 scroll with its contents. (It is effectively attached to the box's
 border.)

Even if the image is fixed, it is still only visible when it is in the
[background painting
area](#background-painting-area) of the box or otherwise unclipped. (See [§ 2.11
Backgrounds of Special Elements](#special-backgrounds) for the cases
when background images are not clipped.) Thus, unless the image is
tiled, it may be invisible.

This example creates an infinite
vertical band that remains "glued" to the viewport when the document is
scrolled.

 body {
 background: red url("pendant.gif");
 background-repeat: repeat-y;
 background-attachment: fixed;
 }

 User agents that do not support
[fixed](#valdef-background-attachment-fixed) backgrounds (for example due to limitations of
the hardware platform) [will ignore
declarations](https://www.w3.org/TR/CSS/#partial) with the keyword
[fixed]. For example:

```
body {
 /* For all UAs: */
 background: white url(paper.png) scroll;
 /* For UAs that do fixed backgrounds: */
 background: white url(ledger.png) fixed;
}
h1 {
 /* For all UAs: */
 background: silver;
 /* For UAs that do fixed backgrounds: */
 background: url(stripe.png) fixed, white url(ledger.png) fixed;
}
```

See [§ 2.1 Layering Multiple Background Images](#layering) for how
[background-attachment](#propdef-background-attachment) interacts with other
comma-separated background properties to form each [background image
layer](#background-image-layer).

### 2.6. Positioning Images: the [background-position property]
Name:

[background-position]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<bg-position\>](#typedef-bg-position)[\#](https://drafts.csswg.org/css-values-4/#mult-comma)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

0% 0%

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[all
elements](https://www.w3.org/TR/css-pseudo/#generated-content "Includes ::before and ::after pseudo-elements.")

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

refer to size of [background positioning
area](#background-positioning-area) *minus* size of background image; see text

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

list, each item a pair of offsets (horizontal and vertical) from the top
left origin each given as a computed
[\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage) value

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

repeatable list

Tests

- [background-position-composition.html](https://wpt.fyi/results/css/css-backgrounds/animations/background-position-composition.html "css/css-backgrounds/animations/background-position-composition.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/animations/background-position-composition.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/animations/background-position-composition.html)
- [background-position-interpolation.html](https://wpt.fyi/results/css/css-backgrounds/animations/background-position-interpolation.html "css/css-backgrounds/animations/background-position-interpolation.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/animations/background-position-interpolation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/animations/background-position-interpolation.html)
- [background-position-calc-minmax-001.html](https://wpt.fyi/results/css/css-backgrounds/background-position-calc-minmax-001.html "css/css-backgrounds/background-position-calc-minmax-001.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-position-calc-minmax-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-position-calc-minmax-001.html)
- [background-position-negative-percentage-comparison-002.html](https://wpt.fyi/results/css/css-backgrounds/background-position-negative-percentage-comparison-002.html "css/css-backgrounds/background-position-negative-percentage-comparison-002.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-position-negative-percentage-comparison-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-position-negative-percentage-comparison-002.html)
- [background-position-negative-percentage-comparison.html](https://wpt.fyi/results/css/css-backgrounds/background-position-negative-percentage-comparison.html "css/css-backgrounds/background-position-negative-percentage-comparison.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-position-negative-percentage-comparison.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-position-negative-percentage-comparison.html)
- [background-position-three-four-values.html](https://wpt.fyi/results/css/css-backgrounds/background-position-three-four-values.html "css/css-backgrounds/background-position-three-four-values.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-position-three-four-values.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-position-three-four-values.html)
- [background-position-bottom-right-repeat-round.html](https://wpt.fyi/results/css/css-backgrounds/background-position/background-position-bottom-right-repeat-round.html "css/css-backgrounds/background-position/background-position-bottom-right-repeat-round.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-position/background-position-bottom-right-repeat-round.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-position/background-position-bottom-right-repeat-round.html)
- [background-position-right-in-body.html](https://wpt.fyi/results/css/css-backgrounds/background-position/background-position-right-in-body.html "css/css-backgrounds/background-position/background-position-right-in-body.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-position/background-position-right-in-body.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-position/background-position-right-in-body.html)
- [inheritance.sub.html](https://wpt.fyi/results/css/css-backgrounds/inheritance.sub.html "css/css-backgrounds/inheritance.sub.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/inheritance.sub.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/inheritance.sub.html)
- [background-position-computed.html](https://wpt.fyi/results/css/css-backgrounds/parsing/background-position-computed.html "css/css-backgrounds/parsing/background-position-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/parsing/background-position-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/parsing/background-position-computed.html)
- [background-position-invalid.html](https://wpt.fyi/results/css/css-backgrounds/parsing/background-position-invalid.html "css/css-backgrounds/parsing/background-position-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/parsing/background-position-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/parsing/background-position-invalid.html)
- [background-position-valid.html](https://wpt.fyi/results/css/css-backgrounds/parsing/background-position-valid.html "css/css-backgrounds/parsing/background-position-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/parsing/background-position-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/parsing/background-position-valid.html)

If [background images](#background-images) have been specified, this property specifies their
initial position (after any [resizing](#background-size)) within their
corresponding [background positioning
area](#background-positioning-area).

The property's value is given as a comma-separated list of
[\<bg-position\>](#typedef-bg-position) values where

``` prod
<bg-position> = [
 [ left | center | right | top | bottom | <length-percentage> ]
|
 [ left | center | right | <length-percentage> ]
 [ top | center | bottom | <length-percentage> ]
|
 [ center | [ left | right ] <length-percentage>? ] &&
 [ center | [ top | bottom ] <length-percentage>? ]
]
```

If only one value is specified, the second value is assumed to be
[center](#valdef-background-position-center). If two values are given, a
[\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage) as the first value represents the
horizontal position (or offset) and a
[\<length-percentage\>]
as the second value represents the vertical position (or offset). The
[\<length-percentage\>]
values here represent an offset of the top left corner of the background
image from the top left corner of the [background positioning
area](#background-positioning-area).

 A pair of keywords can be reordered, while a
combination of keyword and length or percentage cannot. So [center
left] is valid while [50% left] is not.

If three or four values are given, then each
[\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage) represents an offset and must be
preceded by a keyword, which specifies from which edge the offset is
given. For example, [background-position: bottom 10px right
20px](#propdef-background-position) represents a [10px] vertical offset up
from the bottom edge and a [20px] horizontal offset leftward from
the right edge. If three values are given, the missing offset is assumed
to be zero.

Positive values represent an offset *inward* from the edge of the
[background positioning
area](#background-positioning-area). Negative values represent an offset *outward* from the
edge of the [background positioning
area].

The following declarations give the
stated (horizontal, vertical) offsets from the top left corner:

 background-position: left 10px top 15px; /* 10px, 15px */
 background-position: left top ; /* 0px, 0px */
 background-position: 10px 15px; /* 10px, 15px */
 background-position: left 15px; /* 0px, 15px */
 background-position: 10px top ; /* 10px, 0px */
 background-position: left top 15px; /* 0px, 15px */
 background-position: left 10px top ; /* 10px, 0px */

[[\<percentage\>](https://drafts.csswg.org/css-values-4/#percentage-value)]
: A percentage for the horizontal offset is relative to
 (`width of `[`background positioning area`](#background-positioning-area) -
 `width of `[`background image`](#background-images)). A percentage for the vertical offset is relative
 to
 (`height of `[`background positioning area`](#background-positioning-area) -
 `height of `[`background image`](#background-images)), where the size of the image is the size given by
 [background-size](#propdef-background-size).
 :::
 (#example-c27a0cea) For example, with a value pair of
 [0% 0%], the upper left corner of the image is aligned with
 the upper left corner of, usually, the box's [padding
 edge](https://drafts.csswg.org/css-box-4/#padding-edge). A value pair of [100% 100%] places the lower
 right corner of the image in the lower right corner of the area.
 With a value pair of [75% 50%], the point 75% across and 50%
 down the image is to be placed at the point 75% across and 50% down
 the area.
 ![Diagram of the meaning of [background-position: 75%
 50%](#propdef-background-position).](images/bg-pos.png){a
 height="269" width="397"}
 :::

[[\<length\>](https://drafts.csswg.org/css-values-4/#length-value)]
: A length value gives a fixed length as the offset. For example, with
 a value pair of [2cm 1cm], the upper left corner of the image
 is placed 2cm to the right and 1cm below the upper left corner of
 the [background positioning
 area](#background-positioning-area).

[[top](#valdef-background-position-top)]
: Computes to [0%] for the vertical position if one or two
 values are given, otherwise specifies the top edge as the origin for
 the next offset.

[[right](#valdef-background-position-right)]
: Computes to [100%] for the horizontal position if one or two
 values are given, otherwise specifies the right edge as the origin
 for the next offset.

[[bottom](#valdef-background-position-bottom)]
: Computes to [100%] for the vertical position if one or two
 values are given, otherwise specifies the bottom edge as the origin
 for the next offset.

[[left](#valdef-background-position-left)]
: Computes to [0%] for the horizontal position if one or two
 values are given, otherwise specifies the left edge as the origin
 for the next offset.

[[center](#valdef-background-position-center)]
: Computes to [50%] ([left 50%]) for the horizontal
 position if the horizontal position is not otherwise specified, or
 [50%] ([top 50%]) for the vertical position if it is.

The following
[background](#propdef-background) shorthand declarations use keywords to
set
[background-position](#propdef-background-position) to the stated percentage values.

 body { background: url("banner.jpeg") right top } /* 100% 0% */
 body { background: url("banner.jpeg") top center } /* 50% 0% */
 body { background: url("banner.jpeg") center } /* 50% 50% */
 body { background: url("banner.jpeg") bottom } /* 50% 100% */

In the example below, the (single)
image is placed in the lower-right corner of the viewport.

 body {
 background-image: url("logo.png");
 background-attachment: fixed;
 background-position: 100% 100%;
 background-repeat: no-repeat;
 }

Background positions can also be
relative to other corners than the top left. For example, the following
puts the background image 10px from the bottom and 3em from the right:

 background-position: right 3em bottom 10px

See [§ 2.1 Layering Multiple Background Images](#layering) for how
[background-position](#propdef-background-position) interacts with other
comma-separated background properties to form each [background image
layer](#background-image-layer).

#### 2.6.1. Serialization of [background-position values]
The [specified
value](https://drafts.csswg.org/css-cascade-5/#specified-value) and [computed
value](https://drafts.csswg.org/css-cascade-5/#computed-value) of the
[\<bg-position\>](#typedef-bg-position) type serialize exactly as defined in
[\[CSS-VALUES-4\]](#biblio-css-values-4 "CSS Values and Units Module Level 4")
for
[\<position\>](https://drafts.csswg.org/css-values-3/#typedef-position). For 3-value productions (which are
not valid in [\<position\>]),
the [specified value] serialization is
identical to the equivalent 4-value syntax except that the omitted
offset remains omitted.

### 2.7. Painting Area: the [background-clip property]
Name:

[background-clip]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<visual-box\>](https://drafts.csswg.org/css-box-4/#typedef-visual-box)[\#](https://drafts.csswg.org/css-values-4/#mult-comma)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

border-box

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[all
elements](https://www.w3.org/TR/css-pseudo/#generated-content "Includes ::before and ::after pseudo-elements.")

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

N/A

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

list, each item a keyword as specified

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

repeatable list

Tests

- [discrete-no-interpolation.html](https://wpt.fyi/results/css/css-backgrounds/animations/discrete-no-interpolation.html "css/css-backgrounds/animations/discrete-no-interpolation.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/animations/discrete-no-interpolation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/animations/discrete-no-interpolation.html)
- [background-clip-001.html](https://wpt.fyi/results/css/css-backgrounds/background-clip-001.html "css/css-backgrounds/background-clip-001.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-clip-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-clip-001.html)
- [background-clip-002.html](https://wpt.fyi/results/css/css-backgrounds/background-clip-002.html "css/css-backgrounds/background-clip-002.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-clip-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-clip-002.html)
- [background-clip-003.html](https://wpt.fyi/results/css/css-backgrounds/background-clip-003.html "css/css-backgrounds/background-clip-003.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-clip-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-clip-003.html)
- [background-clip-004.html](https://wpt.fyi/results/css/css-backgrounds/background-clip-004.html "css/css-backgrounds/background-clip-004.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-clip-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-clip-004.html)
- [background-clip-005.html](https://wpt.fyi/results/css/css-backgrounds/background-clip-005.html "css/css-backgrounds/background-clip-005.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-clip-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-clip-005.html)
- [background-clip-006.html](https://wpt.fyi/results/css/css-backgrounds/background-clip-006.html "css/css-backgrounds/background-clip-006.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-clip-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-clip-006.html)
- [background-clip-007.html](https://wpt.fyi/results/css/css-backgrounds/background-clip-007.html "css/css-backgrounds/background-clip-007.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-clip-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-clip-007.html)
- [background-clip-008.html](https://wpt.fyi/results/css/css-backgrounds/background-clip-008.html "css/css-backgrounds/background-clip-008.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-clip-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-clip-008.html)
- [background-clip-009.html](https://wpt.fyi/results/css/css-backgrounds/background-clip-009.html "css/css-backgrounds/background-clip-009.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-clip-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-clip-009.html)
- [background-clip-010.html](https://wpt.fyi/results/css/css-backgrounds/background-clip-010.html "css/css-backgrounds/background-clip-010.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-clip-010.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-clip-010.html)
- [background-clip-color-repaint.html](https://wpt.fyi/results/css/css-backgrounds/background-clip-color-repaint.html "css/css-backgrounds/background-clip-color-repaint.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-clip-color-repaint.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-clip-color-repaint.html)
- [background-clip-color.html](https://wpt.fyi/results/css/css-backgrounds/background-clip-color.html "css/css-backgrounds/background-clip-color.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-clip-color.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-clip-color.html)
- [background-clip-content-box-001.html](https://wpt.fyi/results/css/css-backgrounds/background-clip-content-box-001.html "css/css-backgrounds/background-clip-content-box-001.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-clip-content-box-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-clip-content-box-001.html)
- [background-clip-content-box-002.html](https://wpt.fyi/results/css/css-backgrounds/background-clip-content-box-002.html "css/css-backgrounds/background-clip-content-box-002.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-clip-content-box-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-clip-content-box-002.html)
- [background-clip-content-box-with-border-radius-002.html](https://wpt.fyi/results/css/css-backgrounds/background-clip-content-box-with-border-radius-002.html "css/css-backgrounds/background-clip-content-box-with-border-radius-002.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-clip-content-box-with-border-radius-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-clip-content-box-with-border-radius-002.html)
- [background-clip-content-box-with-border-radius-003.html](https://wpt.fyi/results/css/css-backgrounds/background-clip-content-box-with-border-radius-003.html "css/css-backgrounds/background-clip-content-box-with-border-radius-003.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-clip-content-box-with-border-radius-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-clip-content-box-with-border-radius-003.html)
- [background-clip-padding-box-with-border-radius-002.html](https://wpt.fyi/results/css/css-backgrounds/background-clip-padding-box-with-border-radius-002.html "css/css-backgrounds/background-clip-padding-box-with-border-radius-002.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-clip-padding-box-with-border-radius-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-clip-padding-box-with-border-radius-002.html)
- [background-clip-padding-box-with-border-radius-003.html](https://wpt.fyi/results/css/css-backgrounds/background-clip-padding-box-with-border-radius-003.html "css/css-backgrounds/background-clip-padding-box-with-border-radius-003.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-clip-padding-box-with-border-radius-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-clip-padding-box-with-border-radius-003.html)
- [background-clip-padding-box-001.html](https://wpt.fyi/results/css/css-backgrounds/background-clip-padding-box-001.html "css/css-backgrounds/background-clip-padding-box-001.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-clip-padding-box-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-clip-padding-box-001.html)
- [background-clip-padding-box-with-border-radius.html](https://wpt.fyi/results/css/css-backgrounds/background-clip-padding-box-with-border-radius.html "css/css-backgrounds/background-clip-padding-box-with-border-radius.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-clip-padding-box-with-border-radius.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-clip-padding-box-with-border-radius.html)
- [clip-border-area-background-geometry.html](https://wpt.fyi/results/css/css-backgrounds/background-clip/clip-border-area-background-geometry.html "css/css-backgrounds/background-clip/clip-border-area-background-geometry.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-clip/clip-border-area-background-geometry.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-clip/clip-border-area-background-geometry.html)
- [clip-border-area-border-image.html](https://wpt.fyi/results/css/css-backgrounds/background-clip/clip-border-area-border-image.html "css/css-backgrounds/background-clip/clip-border-area-border-image.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-clip/clip-border-area-border-image.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-clip/clip-border-area-border-image.html)
- [clip-border-area-border-on-top.html](https://wpt.fyi/results/css/css-backgrounds/background-clip/clip-border-area-border-on-top.html "css/css-backgrounds/background-clip/clip-border-area-border-on-top.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-clip/clip-border-area-border-on-top.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-clip/clip-border-area-border-on-top.html)
- [clip-border-area-box-decoration-break.html](https://wpt.fyi/results/css/css-backgrounds/background-clip/clip-border-area-box-decoration-break.html "css/css-backgrounds/background-clip/clip-border-area-box-decoration-break.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-clip/clip-border-area-box-decoration-break.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-clip/clip-border-area-box-decoration-break.html)
- [clip-border-area-multiple-backgrounds.html](https://wpt.fyi/results/css/css-backgrounds/background-clip/clip-border-area-multiple-backgrounds.html "css/css-backgrounds/background-clip/clip-border-area-multiple-backgrounds.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-clip/clip-border-area-multiple-backgrounds.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-clip/clip-border-area-multiple-backgrounds.html)
- [clip-border-area-on-body-not-propagated-to-root.html](https://wpt.fyi/results/css/css-backgrounds/background-clip/clip-border-area-on-body-not-propagated-to-root.html "css/css-backgrounds/background-clip/clip-border-area-on-body-not-propagated-to-root.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-clip/clip-border-area-on-body-not-propagated-to-root.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-clip/clip-border-area-on-body-not-propagated-to-root.html)
- [clip-border-area-on-body-propagated-to-root.html](https://wpt.fyi/results/css/css-backgrounds/background-clip/clip-border-area-on-body-propagated-to-root.html "css/css-backgrounds/background-clip/clip-border-area-on-body-propagated-to-root.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-clip/clip-border-area-on-body-propagated-to-root.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-clip/clip-border-area-on-body-propagated-to-root.html)
- [clip-border-area-on-root.html](https://wpt.fyi/results/css/css-backgrounds/background-clip/clip-border-area-on-root.html "css/css-backgrounds/background-clip/clip-border-area-on-root.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-clip/clip-border-area-on-root.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-clip/clip-border-area-on-root.html)
- [clip-text-ellipsis.html](https://wpt.fyi/results/css/css-backgrounds/background-clip/clip-text-ellipsis.html "css/css-backgrounds/background-clip/clip-text-ellipsis.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-clip/clip-text-ellipsis.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-clip/clip-text-ellipsis.html)
- [clip-text-on-body-not-propagated-to-root.html](https://wpt.fyi/results/css/css-backgrounds/background-clip/clip-text-on-body-not-propagated-to-root.html "css/css-backgrounds/background-clip/clip-text-on-body-not-propagated-to-root.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-clip/clip-text-on-body-not-propagated-to-root.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-clip/clip-text-on-body-not-propagated-to-root.html)
- [clip-text-on-body-propagated-to-root.html](https://wpt.fyi/results/css/css-backgrounds/background-clip/clip-text-on-body-propagated-to-root.html "css/css-backgrounds/background-clip/clip-text-on-body-propagated-to-root.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-clip/clip-text-on-body-propagated-to-root.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-clip/clip-text-on-body-propagated-to-root.html)
- [clip-text-on-root.html](https://wpt.fyi/results/css/css-backgrounds/background-clip/clip-text-on-root.html "css/css-backgrounds/background-clip/clip-text-on-root.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-clip/clip-text-on-root.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-clip/clip-text-on-root.html)
- [clip-text-out-of-flow-child.html](https://wpt.fyi/results/css/css-backgrounds/background-clip/clip-text-out-of-flow-child.html "css/css-backgrounds/background-clip/clip-text-out-of-flow-child.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-clip/clip-text-out-of-flow-child.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-clip/clip-text-out-of-flow-child.html)
- [clip-text-text-decorations.html](https://wpt.fyi/results/css/css-backgrounds/background-clip/clip-text-text-decorations.html "css/css-backgrounds/background-clip/clip-text-text-decorations.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-clip/clip-text-text-decorations.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-clip/clip-text-text-decorations.html)
- [clip-text-text-emphasis.html](https://wpt.fyi/results/css/css-backgrounds/background-clip/clip-text-text-emphasis.html "css/css-backgrounds/background-clip/clip-text-text-emphasis.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-clip/clip-text-text-emphasis.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-clip/clip-text-text-emphasis.html)
- [clip-rounded-corner.html](https://wpt.fyi/results/css/css-backgrounds/background-clip/clip-rounded-corner.html "css/css-backgrounds/background-clip/clip-rounded-corner.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-clip/clip-rounded-corner.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-clip/clip-rounded-corner.html)
- [clip-text-animated-text.html](https://wpt.fyi/results/css/css-backgrounds/background-clip/clip-text-animated-text.html "css/css-backgrounds/background-clip/clip-text-animated-text.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-clip/clip-text-animated-text.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-clip/clip-text-animated-text.html)
- [clip-text-dynamic-2.html](https://wpt.fyi/results/css/css-backgrounds/background-clip/clip-text-dynamic-2.html "css/css-backgrounds/background-clip/clip-text-dynamic-2.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-clip/clip-text-dynamic-2.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-clip/clip-text-dynamic-2.html)
- [clip-text-flex.html](https://wpt.fyi/results/css/css-backgrounds/background-clip/clip-text-flex.html "css/css-backgrounds/background-clip/clip-text-flex.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-clip/clip-text-flex.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-clip/clip-text-flex.html)
- [clip-text-multi-line.html](https://wpt.fyi/results/css/css-backgrounds/background-clip/clip-text-multi-line.html "css/css-backgrounds/background-clip/clip-text-multi-line.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-clip/clip-text-multi-line.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-clip/clip-text-multi-line.html)
- [background-clip_padding-box.html](https://wpt.fyi/results/css/css-backgrounds/background-clip_padding-box.html "css/css-backgrounds/background-clip_padding-box.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-clip_padding-box.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-clip_padding-box.html)
- [background-paint-order-001.html](https://wpt.fyi/results/css/css-backgrounds/background-paint-order-001.html "css/css-backgrounds/background-paint-order-001.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-paint-order-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-paint-order-001.html)
- [background-rounded-image-clip-001.html](https://wpt.fyi/results/css/css-backgrounds/background-rounded-image-clip-001.html "css/css-backgrounds/background-rounded-image-clip-001.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-rounded-image-clip-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-rounded-image-clip-001.html)
- [background-rounded-image-clip-002.html](https://wpt.fyi/results/css/css-backgrounds/background-rounded-image-clip-002.html "css/css-backgrounds/background-rounded-image-clip-002.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-rounded-image-clip-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-rounded-image-clip-002.html)
- [css3-background-clip-border-box.html](https://wpt.fyi/results/css/css-backgrounds/css3-background-clip-border-box.html "css/css-backgrounds/css3-background-clip-border-box.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/css3-background-clip-border-box.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/css3-background-clip-border-box.html)
- [css3-background-clip-content-box.html](https://wpt.fyi/results/css/css-backgrounds/css3-background-clip-content-box.html "css/css-backgrounds/css3-background-clip-content-box.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/css3-background-clip-content-box.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/css3-background-clip-content-box.html)
- [css3-background-clip-padding-box.html](https://wpt.fyi/results/css/css-backgrounds/css3-background-clip-padding-box.html "css/css-backgrounds/css3-background-clip-padding-box.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/css3-background-clip-padding-box.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/css3-background-clip-padding-box.html)
- [css3-background-clip.html](https://wpt.fyi/results/css/css-backgrounds/css3-background-clip.html "css/css-backgrounds/css3-background-clip.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/css3-background-clip.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/css3-background-clip.html)
- [inheritance.sub.html](https://wpt.fyi/results/css/css-backgrounds/inheritance.sub.html "css/css-backgrounds/inheritance.sub.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/inheritance.sub.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/inheritance.sub.html)
- [local-attachment-content-box-scroll.html](https://wpt.fyi/results/css/css-backgrounds/local-attachment-content-box-scroll.html "css/css-backgrounds/local-attachment-content-box-scroll.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/local-attachment-content-box-scroll.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/local-attachment-content-box-scroll.html)
- [background-clip-computed.html](https://wpt.fyi/results/css/css-backgrounds/parsing/background-clip-computed.html "css/css-backgrounds/parsing/background-clip-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/parsing/background-clip-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/parsing/background-clip-computed.html)
- [background-clip-invalid.html](https://wpt.fyi/results/css/css-backgrounds/parsing/background-clip-invalid.html "css/css-backgrounds/parsing/background-clip-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/parsing/background-clip-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/parsing/background-clip-invalid.html)
- [background-clip-valid.html](https://wpt.fyi/results/css/css-backgrounds/parsing/background-clip-valid.html "css/css-backgrounds/parsing/background-clip-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/parsing/background-clip-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/parsing/background-clip-valid.html)

Determines the [background painting area], which determines the area within
which the background is painted. Values have the following meanings:

[border-box]
: The background is painted within (clipped to) the [border
 box](https://drafts.csswg.org/css-box-4/#border-box).

[padding-box]
: The background is painted within (clipped to) the [padding
 box](https://drafts.csswg.org/css-box-4/#padding-box).

[content-box]
: The background is painted within (clipped to) the [content
 box](https://drafts.csswg.org/css-box-4/#content-box).

 The root element has a different [background painting
area](#background-painting-area) and thus the
[background-clip](#propdef-background-clip) property has no effect when
specified on it. See [§ 2.11 Backgrounds of Special
Elements](#special-backgrounds).

 The background is always drawn *behind* the border, if
any. See "Elaborate description of Stacking Contexts" in
[\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")
Appendix E.

See [§ 4.2 Corner Shaping](#corner-shaping) for how
[border-radius](#propdef-border-radius) affects the shape of the
[background painting
area](#background-painting-area).

See [§ 2.1 Layering Multiple Background Images](#layering) for how
[background-clip](#propdef-background-clip) interacts with other
comma-separated background properties to form each [background image
layer](#background-image-layer).

### 2.8. Positioning Area: the [background-origin property]
Name:

[background-origin]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<visual-box\>](https://drafts.csswg.org/css-box-4/#typedef-visual-box)[\#](https://drafts.csswg.org/css-values-4/#mult-comma)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

padding-box

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[all
elements](https://www.w3.org/TR/css-pseudo/#generated-content "Includes ::before and ::after pseudo-elements.")

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

N/A

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

list, each item a keyword as specified

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

repeatable list

Tests

- [discrete-no-interpolation.html](https://wpt.fyi/results/css/css-backgrounds/animations/discrete-no-interpolation.html "css/css-backgrounds/animations/discrete-no-interpolation.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/animations/discrete-no-interpolation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/animations/discrete-no-interpolation.html)
- [background-position-origin-interpolation.html](https://wpt.fyi/results/css/css-backgrounds/animations/background-position-origin-interpolation.html "css/css-backgrounds/animations/background-position-origin-interpolation.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/animations/background-position-origin-interpolation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/animations/background-position-origin-interpolation.html)
- [background-gradient-subpixel-fills-area.html](https://wpt.fyi/results/css/css-backgrounds/background-gradient-subpixel-fills-area.html "css/css-backgrounds/background-gradient-subpixel-fills-area.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-gradient-subpixel-fills-area.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-gradient-subpixel-fills-area.html)
- [background-origin-001.html](https://wpt.fyi/results/css/css-backgrounds/background-origin-001.html "css/css-backgrounds/background-origin-001.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-origin-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-origin-001.html)
- [background-origin-002.html](https://wpt.fyi/results/css/css-backgrounds/background-origin-002.html "css/css-backgrounds/background-origin-002.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-origin-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-origin-002.html)
- [background-origin-003.html](https://wpt.fyi/results/css/css-backgrounds/background-origin-003.html "css/css-backgrounds/background-origin-003.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-origin-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-origin-003.html)
- [background-origin-004.html](https://wpt.fyi/results/css/css-backgrounds/background-origin-004.html "css/css-backgrounds/background-origin-004.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-origin-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-origin-004.html)
- [background-origin-005.html](https://wpt.fyi/results/css/css-backgrounds/background-origin-005.html "css/css-backgrounds/background-origin-005.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-origin-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-origin-005.html)
- [background-origin-006.html](https://wpt.fyi/results/css/css-backgrounds/background-origin-006.html "css/css-backgrounds/background-origin-006.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-origin-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-origin-006.html)
- [background-origin-007.html](https://wpt.fyi/results/css/css-backgrounds/background-origin-007.html "css/css-backgrounds/background-origin-007.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-origin-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-origin-007.html)
- [background-origin-008.html](https://wpt.fyi/results/css/css-backgrounds/background-origin-008.html "css/css-backgrounds/background-origin-008.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-origin-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-origin-008.html)
- [origin-border-box.html](https://wpt.fyi/results/css/css-backgrounds/background-origin/origin-border-box.html "css/css-backgrounds/background-origin/origin-border-box.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-origin/origin-border-box.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-origin/origin-border-box.html)
- [origin-border-box_with_position.html](https://wpt.fyi/results/css/css-backgrounds/background-origin/origin-border-box_with_position.html "css/css-backgrounds/background-origin/origin-border-box_with_position.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-origin/origin-border-box_with_position.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-origin/origin-border-box_with_position.html)
- [origin-border-box_with_radius.html](https://wpt.fyi/results/css/css-backgrounds/background-origin/origin-border-box_with_radius.html "css/css-backgrounds/background-origin/origin-border-box_with_radius.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-origin/origin-border-box_with_radius.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-origin/origin-border-box_with_radius.html)
- [origin-border-box_with_size.html](https://wpt.fyi/results/css/css-backgrounds/background-origin/origin-border-box_with_size.html "css/css-backgrounds/background-origin/origin-border-box_with_size.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-origin/origin-border-box_with_size.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-origin/origin-border-box_with_size.html)
- [origin-content-box.html](https://wpt.fyi/results/css/css-backgrounds/background-origin/origin-content-box.html "css/css-backgrounds/background-origin/origin-content-box.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-origin/origin-content-box.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-origin/origin-content-box.html)
- [origin-content-box_with_position.html](https://wpt.fyi/results/css/css-backgrounds/background-origin/origin-content-box_with_position.html "css/css-backgrounds/background-origin/origin-content-box_with_position.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-origin/origin-content-box_with_position.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-origin/origin-content-box_with_position.html)
- [origin-content-box_with_radius.html](https://wpt.fyi/results/css/css-backgrounds/background-origin/origin-content-box_with_radius.html "css/css-backgrounds/background-origin/origin-content-box_with_radius.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-origin/origin-content-box_with_radius.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-origin/origin-content-box_with_radius.html)
- [origin-content-box_with_size.html](https://wpt.fyi/results/css/css-backgrounds/background-origin/origin-content-box_with_size.html "css/css-backgrounds/background-origin/origin-content-box_with_size.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-origin/origin-content-box_with_size.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-origin/origin-content-box_with_size.html)
- [origin-padding-box.html](https://wpt.fyi/results/css/css-backgrounds/background-origin/origin-padding-box.html "css/css-backgrounds/background-origin/origin-padding-box.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-origin/origin-padding-box.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-origin/origin-padding-box.html)
- [origin-padding-box_with_position.html](https://wpt.fyi/results/css/css-backgrounds/background-origin/origin-padding-box_with_position.html "css/css-backgrounds/background-origin/origin-padding-box_with_position.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-origin/origin-padding-box_with_position.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-origin/origin-padding-box_with_position.html)
- [origin-padding-box_with_radius.html](https://wpt.fyi/results/css/css-backgrounds/background-origin/origin-padding-box_with_radius.html "css/css-backgrounds/background-origin/origin-padding-box_with_radius.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-origin/origin-padding-box_with_radius.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-origin/origin-padding-box_with_radius.html)
- [origin-padding-box_with_size.html](https://wpt.fyi/results/css/css-backgrounds/background-origin/origin-padding-box_with_size.html "css/css-backgrounds/background-origin/origin-padding-box_with_size.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-origin/origin-padding-box_with_size.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-origin/origin-padding-box_with_size.html)
- [css3-background-origin-border-box.html](https://wpt.fyi/results/css/css-backgrounds/css3-background-origin-border-box.html "css/css-backgrounds/css3-background-origin-border-box.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/css3-background-origin-border-box.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/css3-background-origin-border-box.html)
- [css3-background-origin-content-box.html](https://wpt.fyi/results/css/css-backgrounds/css3-background-origin-content-box.html "css/css-backgrounds/css3-background-origin-content-box.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/css3-background-origin-content-box.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/css3-background-origin-content-box.html)
- [css3-background-origin-padding-box.html](https://wpt.fyi/results/css/css-backgrounds/css3-background-origin-padding-box.html "css/css-backgrounds/css3-background-origin-padding-box.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/css3-background-origin-padding-box.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/css3-background-origin-padding-box.html)
- [inheritance.sub.html](https://wpt.fyi/results/css/css-backgrounds/inheritance.sub.html "css/css-backgrounds/inheritance.sub.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/inheritance.sub.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/inheritance.sub.html)
- [background-origin-computed.html](https://wpt.fyi/results/css/css-backgrounds/parsing/background-origin-computed.html "css/css-backgrounds/parsing/background-origin-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/parsing/background-origin-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/parsing/background-origin-computed.html)
- [background-origin-invalid.html](https://wpt.fyi/results/css/css-backgrounds/parsing/background-origin-invalid.html "css/css-backgrounds/parsing/background-origin-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/parsing/background-origin-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/parsing/background-origin-invalid.html)
- [background-origin-valid.html](https://wpt.fyi/results/css/css-backgrounds/parsing/background-origin-valid.html "css/css-backgrounds/parsing/background-origin-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/parsing/background-origin-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/parsing/background-origin-valid.html)

This property determines the [background positioning
area]: the area within which any background images are positioned.
For elements rendered as multiple [box
fragments](https://drafts.csswg.org/css-break-4/#box-fragment) (e.g., inline boxes on several lines, boxes on several
pages), specifies which boxes
[box-decoration-break](https://drafts.csswg.org/css-break-4/#propdef-box-decoration-break)
[\[CSS-BREAK-3\]](#biblio-css-break-3 "CSS Fragmentation Module Level 3")
operates on to determine the background positioning area(s).

[padding-box]
: The position is relative to the [padding
 box](https://drafts.csswg.org/css-box-4/#padding-box). (For single boxes [0 0] is the upper left
 corner of the padding edge, [100% 100%] is the lower right
 corner.)

[border-box]
: The position is relative to the [border
 box](https://drafts.csswg.org/css-box-4/#border-box).

[content-box]
: The position is relative to the [content
 box](https://drafts.csswg.org/css-box-4/#content-box).

If the
[background-attachment](#propdef-background-attachment) value for this
[layer](#background-image-layer) is
[fixed](#valdef-background-attachment-fixed), then this property has no effect: in this case
the [background positioning
area](#background-positioning-area) is the [initial containing
block](https://drafts.csswg.org/css-display-4/#initial-containing-block).

 If
[background-clip](#propdef-background-clip) is
[padding-box](#valdef-background-clip-padding-box),
[background-origin](#propdef-background-origin) is
[border-box](#valdef-background-origin-border-box),
[background-position](#propdef-background-position) is [top left] (the initial
value), and the element has a non-zero border, then the top and left
edges of the [background
image](#background-images)
will be clipped.

See [§ 2.1 Layering Multiple Background Images](#layering) for how
[background-origin](#propdef-background-origin) interacts with other
comma-separated background properties to form each [background image
layer](#background-image-layer).

### 2.9. Sizing Images: the [background-size property]
Name:

[background-size]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<bg-size\>](#typedef-bg-size)[\#](https://drafts.csswg.org/css-values-4/#mult-comma)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

auto

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[all
elements](https://www.w3.org/TR/css-pseudo/#generated-content "Includes ::before and ::after pseudo-elements.")

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

see text

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

list, each item a pair of sizes (one per axis) each represented as
either a keyword or a computed
[\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage) value

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

repeatable list

Tests

- [background-size-composition.html](https://wpt.fyi/results/css/css-backgrounds/animations/background-size-composition.html "css/css-backgrounds/animations/background-size-composition.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/animations/background-size-composition.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/animations/background-size-composition.html)
- [background-size-interpolation.html](https://wpt.fyi/results/css/css-backgrounds/animations/background-size-interpolation.html "css/css-backgrounds/animations/background-size-interpolation.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/animations/background-size-interpolation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/animations/background-size-interpolation.html)
- [background-size-001.html](https://wpt.fyi/results/css/css-backgrounds/background-size-001.html "css/css-backgrounds/background-size-001.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size-001.html)
- [background-size-002.html](https://wpt.fyi/results/css/css-backgrounds/background-size-002.html "css/css-backgrounds/background-size-002.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size-002.html)
- [background-size-005.html](https://wpt.fyi/results/css/css-backgrounds/background-size-005.html "css/css-backgrounds/background-size-005.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size-005.html)
- [background-size-006.html](https://wpt.fyi/results/css/css-backgrounds/background-size-006.html "css/css-backgrounds/background-size-006.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size-006.html)
- [background-size-007.html](https://wpt.fyi/results/css/css-backgrounds/background-size-007.html "css/css-backgrounds/background-size-007.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size-007.html)
- [background-size-008.html](https://wpt.fyi/results/css/css-backgrounds/background-size-008.html "css/css-backgrounds/background-size-008.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size-008.html)
- [background-size-009.html](https://wpt.fyi/results/css/css-backgrounds/background-size-009.html "css/css-backgrounds/background-size-009.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size-009.html)
- [background-size-010.html](https://wpt.fyi/results/css/css-backgrounds/background-size-010.html "css/css-backgrounds/background-size-010.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size-010.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size-010.html)
- [background-size-011.html](https://wpt.fyi/results/css/css-backgrounds/background-size-011.html "css/css-backgrounds/background-size-011.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size-011.html)
- [background-size-012.html](https://wpt.fyi/results/css/css-backgrounds/background-size-012.html "css/css-backgrounds/background-size-012.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size-012.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size-012.html)
- [background-size-013.html](https://wpt.fyi/results/css/css-backgrounds/background-size-013.html "css/css-backgrounds/background-size-013.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size-013.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size-013.html)
- [background-size-014.html](https://wpt.fyi/results/css/css-backgrounds/background-size-014.html "css/css-backgrounds/background-size-014.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size-014.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size-014.html)
- [background-size-015.html](https://wpt.fyi/results/css/css-backgrounds/background-size-015.html "css/css-backgrounds/background-size-015.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size-015.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size-015.html)
- [background-size-016.html](https://wpt.fyi/results/css/css-backgrounds/background-size-016.html "css/css-backgrounds/background-size-016.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size-016.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size-016.html)
- [background-size-017.html](https://wpt.fyi/results/css/css-backgrounds/background-size-017.html "css/css-backgrounds/background-size-017.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size-017.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size-017.html)
- [background-size-018.html](https://wpt.fyi/results/css/css-backgrounds/background-size-018.html "css/css-backgrounds/background-size-018.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size-018.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size-018.html)
- [background-size-019.html](https://wpt.fyi/results/css/css-backgrounds/background-size-019.html "css/css-backgrounds/background-size-019.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size-019.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size-019.html)
- [background-size-020.html](https://wpt.fyi/results/css/css-backgrounds/background-size-020.html "css/css-backgrounds/background-size-020.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size-020.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size-020.html)
- [background-size-021.html](https://wpt.fyi/results/css/css-backgrounds/background-size-021.html "css/css-backgrounds/background-size-021.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size-021.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size-021.html)
- [background-size-025.html](https://wpt.fyi/results/css/css-backgrounds/background-size-025.html "css/css-backgrounds/background-size-025.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size-025.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size-025.html)
- [background-size-026.html](https://wpt.fyi/results/css/css-backgrounds/background-size-026.html "css/css-backgrounds/background-size-026.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size-026.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size-026.html)
- [background-size-027.html](https://wpt.fyi/results/css/css-backgrounds/background-size-027.html "css/css-backgrounds/background-size-027.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size-027.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size-027.html)
- [background-size-028.html](https://wpt.fyi/results/css/css-backgrounds/background-size-028.html "css/css-backgrounds/background-size-028.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size-028.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size-028.html)
- [background-size-029.html](https://wpt.fyi/results/css/css-backgrounds/background-size-029.html "css/css-backgrounds/background-size-029.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size-029.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size-029.html)
- [background-size-030.html](https://wpt.fyi/results/css/css-backgrounds/background-size-030.html "css/css-backgrounds/background-size-030.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size-030.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size-030.html)
- [background-size-031.html](https://wpt.fyi/results/css/css-backgrounds/background-size-031.html "css/css-backgrounds/background-size-031.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size-031.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size-031.html)
- [background-size-034.html](https://wpt.fyi/results/css/css-backgrounds/background-size-034.html "css/css-backgrounds/background-size-034.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size-034.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size-034.html)
- [background-size-041.html](https://wpt.fyi/results/css/css-backgrounds/background-size-041.html "css/css-backgrounds/background-size-041.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size-041.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size-041.html)
- [background-size-042.html](https://wpt.fyi/results/css/css-backgrounds/background-size-042.html "css/css-backgrounds/background-size-042.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size-042.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size-042.html)
- [background-size-043.html](https://wpt.fyi/results/css/css-backgrounds/background-size-043.html "css/css-backgrounds/background-size-043.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size-043.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size-043.html)
- [background-size-044.html](https://wpt.fyi/results/css/css-backgrounds/background-size-044.html "css/css-backgrounds/background-size-044.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size-044.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size-044.html)
- [background-size-contain-001.html](https://wpt.fyi/results/css/css-backgrounds/background-size-contain-001.html "css/css-backgrounds/background-size-contain-001.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size-contain-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size-contain-001.html)
- [background-size-contain-002.html](https://wpt.fyi/results/css/css-backgrounds/background-size-contain-002.html "css/css-backgrounds/background-size-contain-002.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size-contain-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size-contain-002.html)
- [background-size-cover-001.html](https://wpt.fyi/results/css/css-backgrounds/background-size-cover-001.html "css/css-backgrounds/background-size-cover-001.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size-cover-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size-cover-001.html)
- [background-size-cover-002.html](https://wpt.fyi/results/css/css-backgrounds/background-size-cover-002.html "css/css-backgrounds/background-size-cover-002.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size-cover-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size-cover-002.html)
- [background-size-cover-003.html](https://wpt.fyi/results/css/css-backgrounds/background-size-cover-003.html "css/css-backgrounds/background-size-cover-003.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size-cover-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size-cover-003.html)
- [background-size-one-value-1x1-image.html](https://wpt.fyi/results/css/css-backgrounds/background-size-one-value-1x1-image.html "css/css-backgrounds/background-size-one-value-1x1-image.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size-one-value-1x1-image.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size-one-value-1x1-image.html)
- [background-size-percentage-root.html](https://wpt.fyi/results/css/css-backgrounds/background-size-percentage-root.html "css/css-backgrounds/background-size-percentage-root.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size-percentage-root.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size-percentage-root.html)
- [background-size-with-negative-value.html](https://wpt.fyi/results/css/css-backgrounds/background-size-with-negative-value.html "css/css-backgrounds/background-size-with-negative-value.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size-with-negative-value.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size-with-negative-value.html)
- [background-size-contain-svg-view.html](https://wpt.fyi/results/css/css-backgrounds/background-size/background-size-contain-svg-view.html "css/css-backgrounds/background-size/background-size-contain-svg-view.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/background-size-contain-svg-view.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/background-size-contain-svg-view.html)
- [background-size-contain.xht](https://wpt.fyi/results/css/css-backgrounds/background-size/background-size-contain.xht "css/css-backgrounds/background-size/background-size-contain.xht")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/background-size-contain.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/background-size-contain.xht)
- [background-size-cover-contain-001.xht](https://wpt.fyi/results/css/css-backgrounds/background-size/background-size-cover-contain-001.xht "css/css-backgrounds/background-size/background-size-cover-contain-001.xht")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/background-size-cover-contain-001.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/background-size-cover-contain-001.xht)
- [background-size-cover-contain-002.xht](https://wpt.fyi/results/css/css-backgrounds/background-size/background-size-cover-contain-002.xht "css/css-backgrounds/background-size/background-size-cover-contain-002.xht")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/background-size-cover-contain-002.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/background-size-cover-contain-002.xht)
- [background-size-cover-svg-view.html](https://wpt.fyi/results/css/css-backgrounds/background-size/background-size-cover-svg-view.html "css/css-backgrounds/background-size/background-size-cover-svg-view.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/background-size-cover-svg-view.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/background-size-cover-svg-view.html)
- [background-size-cover-svg.html](https://wpt.fyi/results/css/css-backgrounds/background-size/background-size-cover-svg.html "css/css-backgrounds/background-size/background-size-cover-svg.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/background-size-cover-svg.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/background-size-cover-svg.html)
- [background-size-cover.xht](https://wpt.fyi/results/css/css-backgrounds/background-size/background-size-cover.xht "css/css-backgrounds/background-size/background-size-cover.xht")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/background-size-cover.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/background-size-cover.xht)
- [background-size-near-zero-color.html](https://wpt.fyi/results/css/css-backgrounds/background-size/background-size-near-zero-color.html "css/css-backgrounds/background-size/background-size-near-zero-color.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/background-size-near-zero-color.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/background-size-near-zero-color.html)
- [background-size-near-zero-gradient.html](https://wpt.fyi/results/css/css-backgrounds/background-size/background-size-near-zero-gradient.html "css/css-backgrounds/background-size/background-size-near-zero-gradient.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/background-size-near-zero-gradient.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/background-size-near-zero-gradient.html)
- [background-size-near-zero-png.html](https://wpt.fyi/results/css/css-backgrounds/background-size/background-size-near-zero-png.html "css/css-backgrounds/background-size/background-size-near-zero-png.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/background-size-near-zero-png.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/background-size-near-zero-png.html)
- [background-size-near-zero-svg.html](https://wpt.fyi/results/css/css-backgrounds/background-size/background-size-near-zero-svg.html "css/css-backgrounds/background-size/background-size-near-zero-svg.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/background-size-near-zero-svg.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/background-size-near-zero-svg.html)
- [background-size-vector-001.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/background-size-vector-001.html "css/css-backgrounds/background-size/vector/background-size-vector-001.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/background-size-vector-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/background-size-vector-001.html)
- [background-size-vector-002.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/background-size-vector-002.html "css/css-backgrounds/background-size/vector/background-size-vector-002.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/background-size-vector-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/background-size-vector-002.html)
- [background-size-vector-003.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/background-size-vector-003.html "css/css-backgrounds/background-size/vector/background-size-vector-003.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/background-size-vector-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/background-size-vector-003.html)
- [background-size-vector-004.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/background-size-vector-004.html "css/css-backgrounds/background-size/vector/background-size-vector-004.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/background-size-vector-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/background-size-vector-004.html)
- [background-size-vector-005.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/background-size-vector-005.html "css/css-backgrounds/background-size/vector/background-size-vector-005.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/background-size-vector-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/background-size-vector-005.html)
- [background-size-vector-006.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/background-size-vector-006.html "css/css-backgrounds/background-size/vector/background-size-vector-006.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/background-size-vector-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/background-size-vector-006.html)
- [background-size-vector-007.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/background-size-vector-007.html "css/css-backgrounds/background-size/vector/background-size-vector-007.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/background-size-vector-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/background-size-vector-007.html)
- [background-size-vector-008.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/background-size-vector-008.html "css/css-backgrounds/background-size/vector/background-size-vector-008.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/background-size-vector-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/background-size-vector-008.html)
- [background-size-vector-009.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/background-size-vector-009.html "css/css-backgrounds/background-size/vector/background-size-vector-009.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/background-size-vector-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/background-size-vector-009.html)
- [background-size-vector-010.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/background-size-vector-010.html "css/css-backgrounds/background-size/vector/background-size-vector-010.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/background-size-vector-010.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/background-size-vector-010.html)
- [background-size-vector-011.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/background-size-vector-011.html "css/css-backgrounds/background-size/vector/background-size-vector-011.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/background-size-vector-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/background-size-vector-011.html)
- [background-size-vector-012.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/background-size-vector-012.html "css/css-backgrounds/background-size/vector/background-size-vector-012.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/background-size-vector-012.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/background-size-vector-012.html)
- [background-size-vector-013.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/background-size-vector-013.html "css/css-backgrounds/background-size/vector/background-size-vector-013.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/background-size-vector-013.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/background-size-vector-013.html)
- [background-size-vector-014.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/background-size-vector-014.html "css/css-backgrounds/background-size/vector/background-size-vector-014.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/background-size-vector-014.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/background-size-vector-014.html)
- [background-size-vector-015.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/background-size-vector-015.html "css/css-backgrounds/background-size/vector/background-size-vector-015.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/background-size-vector-015.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/background-size-vector-015.html)
- [background-size-vector-016.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/background-size-vector-016.html "css/css-backgrounds/background-size/vector/background-size-vector-016.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/background-size-vector-016.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/background-size-vector-016.html)
- [background-size-vector-017.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/background-size-vector-017.html "css/css-backgrounds/background-size/vector/background-size-vector-017.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/background-size-vector-017.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/background-size-vector-017.html)
- [background-size-vector-018.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/background-size-vector-018.html "css/css-backgrounds/background-size/vector/background-size-vector-018.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/background-size-vector-018.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/background-size-vector-018.html)
- [background-size-vector-019.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/background-size-vector-019.html "css/css-backgrounds/background-size/vector/background-size-vector-019.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/background-size-vector-019.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/background-size-vector-019.html)
- [background-size-vector-020.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/background-size-vector-020.html "css/css-backgrounds/background-size/vector/background-size-vector-020.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/background-size-vector-020.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/background-size-vector-020.html)
- [background-size-vector-021.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/background-size-vector-021.html "css/css-backgrounds/background-size/vector/background-size-vector-021.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/background-size-vector-021.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/background-size-vector-021.html)
- [background-size-vector-022.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/background-size-vector-022.html "css/css-backgrounds/background-size/vector/background-size-vector-022.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/background-size-vector-022.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/background-size-vector-022.html)
- [background-size-vector-023.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/background-size-vector-023.html "css/css-backgrounds/background-size/vector/background-size-vector-023.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/background-size-vector-023.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/background-size-vector-023.html)
- [background-size-vector-024.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/background-size-vector-024.html "css/css-backgrounds/background-size/vector/background-size-vector-024.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/background-size-vector-024.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/background-size-vector-024.html)
- [background-size-vector-025.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/background-size-vector-025.html "css/css-backgrounds/background-size/vector/background-size-vector-025.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/background-size-vector-025.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/background-size-vector-025.html)
- [background-size-vector-026.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/background-size-vector-026.html "css/css-backgrounds/background-size/vector/background-size-vector-026.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/background-size-vector-026.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/background-size-vector-026.html)
- [background-size-vector-027.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/background-size-vector-027.html "css/css-backgrounds/background-size/vector/background-size-vector-027.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/background-size-vector-027.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/background-size-vector-027.html)
- [background-size-vector-028.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/background-size-vector-028.html "css/css-backgrounds/background-size/vector/background-size-vector-028.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/background-size-vector-028.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/background-size-vector-028.html)
- [background-size-vector-029.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/background-size-vector-029.html "css/css-backgrounds/background-size/vector/background-size-vector-029.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/background-size-vector-029.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/background-size-vector-029.html)
- [diagonal-percentage-vector-background.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/diagonal-percentage-vector-background.html "css/css-backgrounds/background-size/vector/diagonal-percentage-vector-background.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/diagonal-percentage-vector-background.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/diagonal-percentage-vector-background.html)
- [tall\--auto\--omitted-width-percent-height.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/tall--auto--omitted-width-percent-height.html "css/css-backgrounds/background-size/vector/tall--auto--omitted-width-percent-height.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/tall--auto--omitted-width-percent-height.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/tall--auto--omitted-width-percent-height.html)
- [tall\--auto\--percent-width-nonpercent-height-viewbox.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/tall--auto--percent-width-nonpercent-height-viewbox.html "css/css-backgrounds/background-size/vector/tall--auto--percent-width-nonpercent-height-viewbox.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/tall--auto--percent-width-nonpercent-height-viewbox.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/tall--auto--percent-width-nonpercent-height-viewbox.html)
- [tall\--auto\--percent-width-nonpercent-height.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/tall--auto--percent-width-nonpercent-height.html "css/css-backgrounds/background-size/vector/tall--auto--percent-width-nonpercent-height.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/tall--auto--percent-width-nonpercent-height.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/tall--auto--percent-width-nonpercent-height.html)
- [tall\--auto\--percent-width-omitted-height-viewbox.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/tall--auto--percent-width-omitted-height-viewbox.html "css/css-backgrounds/background-size/vector/tall--auto--percent-width-omitted-height-viewbox.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/tall--auto--percent-width-omitted-height-viewbox.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/tall--auto--percent-width-omitted-height-viewbox.html)
- [tall\--auto\--percent-width-omitted-height.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/tall--auto--percent-width-omitted-height.html "css/css-backgrounds/background-size/vector/tall--auto--percent-width-omitted-height.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/tall--auto--percent-width-omitted-height.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/tall--auto--percent-width-omitted-height.html)
- [tall\--auto\--percent-width-percent-height-viewbox.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/tall--auto--percent-width-percent-height-viewbox.html "css/css-backgrounds/background-size/vector/tall--auto--percent-width-percent-height-viewbox.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/tall--auto--percent-width-percent-height-viewbox.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/tall--auto--percent-width-percent-height-viewbox.html)
- [tall\--auto\--percent-width-percent-height.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/tall--auto--percent-width-percent-height.html "css/css-backgrounds/background-size/vector/tall--auto--percent-width-percent-height.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/tall--auto--percent-width-percent-height.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/tall--auto--percent-width-percent-height.html)
- [tall\--auto-32px\--nonpercent-width-nonpercent-height-viewbox.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/tall--auto-32px--nonpercent-width-nonpercent-height-viewbox.html "css/css-backgrounds/background-size/vector/tall--auto-32px--nonpercent-width-nonpercent-height-viewbox.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/tall--auto-32px--nonpercent-width-nonpercent-height-viewbox.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/tall--auto-32px--nonpercent-width-nonpercent-height-viewbox.html)
- [tall\--auto-32px\--nonpercent-width-nonpercent-height.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/tall--auto-32px--nonpercent-width-nonpercent-height.html "css/css-backgrounds/background-size/vector/tall--auto-32px--nonpercent-width-nonpercent-height.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/tall--auto-32px--nonpercent-width-nonpercent-height.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/tall--auto-32px--nonpercent-width-nonpercent-height.html)
- [tall\--auto-32px\--nonpercent-width-omitted-height-viewbox.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/tall--auto-32px--nonpercent-width-omitted-height-viewbox.html "css/css-backgrounds/background-size/vector/tall--auto-32px--nonpercent-width-omitted-height-viewbox.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/tall--auto-32px--nonpercent-width-omitted-height-viewbox.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/tall--auto-32px--nonpercent-width-omitted-height-viewbox.html)
- [tall\--auto-32px\--nonpercent-width-omitted-height.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/tall--auto-32px--nonpercent-width-omitted-height.html "css/css-backgrounds/background-size/vector/tall--auto-32px--nonpercent-width-omitted-height.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/tall--auto-32px--nonpercent-width-omitted-height.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/tall--auto-32px--nonpercent-width-omitted-height.html)
- [tall\--auto-32px\--nonpercent-width-percent-height-viewbox.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/tall--auto-32px--nonpercent-width-percent-height-viewbox.html "css/css-backgrounds/background-size/vector/tall--auto-32px--nonpercent-width-percent-height-viewbox.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/tall--auto-32px--nonpercent-width-percent-height-viewbox.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/tall--auto-32px--nonpercent-width-percent-height-viewbox.html)
- [tall\--auto-32px\--nonpercent-width-percent-height.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/tall--auto-32px--nonpercent-width-percent-height.html "css/css-backgrounds/background-size/vector/tall--auto-32px--nonpercent-width-percent-height.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/tall--auto-32px--nonpercent-width-percent-height.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/tall--auto-32px--nonpercent-width-percent-height.html)
- [tall\--auto-32px\--omitted-width-nonpercent-height-viewbox.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/tall--auto-32px--omitted-width-nonpercent-height-viewbox.html "css/css-backgrounds/background-size/vector/tall--auto-32px--omitted-width-nonpercent-height-viewbox.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/tall--auto-32px--omitted-width-nonpercent-height-viewbox.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/tall--auto-32px--omitted-width-nonpercent-height-viewbox.html)
- [tall\--auto-32px\--omitted-width-nonpercent-height.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/tall--auto-32px--omitted-width-nonpercent-height.html "css/css-backgrounds/background-size/vector/tall--auto-32px--omitted-width-nonpercent-height.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/tall--auto-32px--omitted-width-nonpercent-height.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/tall--auto-32px--omitted-width-nonpercent-height.html)
- [tall\--auto-32px\--omitted-width-omitted-height-viewbox.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/tall--auto-32px--omitted-width-omitted-height-viewbox.html "css/css-backgrounds/background-size/vector/tall--auto-32px--omitted-width-omitted-height-viewbox.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/tall--auto-32px--omitted-width-omitted-height-viewbox.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/tall--auto-32px--omitted-width-omitted-height-viewbox.html)
- [tall\--auto-32px\--omitted-width-omitted-height.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/tall--auto-32px--omitted-width-omitted-height.html "css/css-backgrounds/background-size/vector/tall--auto-32px--omitted-width-omitted-height.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/tall--auto-32px--omitted-width-omitted-height.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/tall--auto-32px--omitted-width-omitted-height.html)
- [tall\--auto-32px\--omitted-width-percent-height-viewbox.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/tall--auto-32px--omitted-width-percent-height-viewbox.html "css/css-backgrounds/background-size/vector/tall--auto-32px--omitted-width-percent-height-viewbox.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/tall--auto-32px--omitted-width-percent-height-viewbox.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/tall--auto-32px--omitted-width-percent-height-viewbox.html)
- [tall\--auto-32px\--omitted-width-percent-height.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/tall--auto-32px--omitted-width-percent-height.html "css/css-backgrounds/background-size/vector/tall--auto-32px--omitted-width-percent-height.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/tall--auto-32px--omitted-width-percent-height.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/tall--auto-32px--omitted-width-percent-height.html)
- [tall\--auto-32px\--percent-width-nonpercent-height-viewbox.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/tall--auto-32px--percent-width-nonpercent-height-viewbox.html "css/css-backgrounds/background-size/vector/tall--auto-32px--percent-width-nonpercent-height-viewbox.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/tall--auto-32px--percent-width-nonpercent-height-viewbox.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/tall--auto-32px--percent-width-nonpercent-height-viewbox.html)
- [tall\--auto-32px\--percent-width-nonpercent-height.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/tall--auto-32px--percent-width-nonpercent-height.html "css/css-backgrounds/background-size/vector/tall--auto-32px--percent-width-nonpercent-height.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/tall--auto-32px--percent-width-nonpercent-height.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/tall--auto-32px--percent-width-nonpercent-height.html)
- [tall\--auto-32px\--percent-width-omitted-height-viewbox.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/tall--auto-32px--percent-width-omitted-height-viewbox.html "css/css-backgrounds/background-size/vector/tall--auto-32px--percent-width-omitted-height-viewbox.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/tall--auto-32px--percent-width-omitted-height-viewbox.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/tall--auto-32px--percent-width-omitted-height-viewbox.html)
- [tall\--auto-32px\--percent-width-omitted-height.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/tall--auto-32px--percent-width-omitted-height.html "css/css-backgrounds/background-size/vector/tall--auto-32px--percent-width-omitted-height.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/tall--auto-32px--percent-width-omitted-height.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/tall--auto-32px--percent-width-omitted-height.html)
- [tall\--auto-32px\--percent-width-percent-height-viewbox.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/tall--auto-32px--percent-width-percent-height-viewbox.html "css/css-backgrounds/background-size/vector/tall--auto-32px--percent-width-percent-height-viewbox.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/tall--auto-32px--percent-width-percent-height-viewbox.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/tall--auto-32px--percent-width-percent-height-viewbox.html)
- [tall\--auto-32px\--percent-width-percent-height.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/tall--auto-32px--percent-width-percent-height.html "css/css-backgrounds/background-size/vector/tall--auto-32px--percent-width-percent-height.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/tall--auto-32px--percent-width-percent-height.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/tall--auto-32px--percent-width-percent-height.html)
- [tall\--contain\--height.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/tall--contain--height.html "css/css-backgrounds/background-size/vector/tall--contain--height.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/tall--contain--height.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/tall--contain--height.html)
- [tall\--contain\--nonpercent-width-nonpercent-height-viewbox.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/tall--contain--nonpercent-width-nonpercent-height-viewbox.html "css/css-backgrounds/background-size/vector/tall--contain--nonpercent-width-nonpercent-height-viewbox.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/tall--contain--nonpercent-width-nonpercent-height-viewbox.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/tall--contain--nonpercent-width-nonpercent-height-viewbox.html)
- [tall\--contain\--nonpercent-width-nonpercent-height.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/tall--contain--nonpercent-width-nonpercent-height.html "css/css-backgrounds/background-size/vector/tall--contain--nonpercent-width-nonpercent-height.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/tall--contain--nonpercent-width-nonpercent-height.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/tall--contain--nonpercent-width-nonpercent-height.html)
- [tall\--contain\--nonpercent-width-omitted-height-viewbox.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/tall--contain--nonpercent-width-omitted-height-viewbox.html "css/css-backgrounds/background-size/vector/tall--contain--nonpercent-width-omitted-height-viewbox.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/tall--contain--nonpercent-width-omitted-height-viewbox.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/tall--contain--nonpercent-width-omitted-height-viewbox.html)
- [tall\--contain\--nonpercent-width-omitted-height.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/tall--contain--nonpercent-width-omitted-height.html "css/css-backgrounds/background-size/vector/tall--contain--nonpercent-width-omitted-height.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/tall--contain--nonpercent-width-omitted-height.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/tall--contain--nonpercent-width-omitted-height.html)
- [tall\--contain\--nonpercent-width-percent-height-viewbox.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/tall--contain--nonpercent-width-percent-height-viewbox.html "css/css-backgrounds/background-size/vector/tall--contain--nonpercent-width-percent-height-viewbox.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/tall--contain--nonpercent-width-percent-height-viewbox.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/tall--contain--nonpercent-width-percent-height-viewbox.html)
- [tall\--contain\--nonpercent-width-percent-height.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/tall--contain--nonpercent-width-percent-height.html "css/css-backgrounds/background-size/vector/tall--contain--nonpercent-width-percent-height.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/tall--contain--nonpercent-width-percent-height.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/tall--contain--nonpercent-width-percent-height.html)
- [tall\--contain\--omitted-width-nonpercent-height-viewbox.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/tall--contain--omitted-width-nonpercent-height-viewbox.html "css/css-backgrounds/background-size/vector/tall--contain--omitted-width-nonpercent-height-viewbox.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/tall--contain--omitted-width-nonpercent-height-viewbox.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/tall--contain--omitted-width-nonpercent-height-viewbox.html)
- [tall\--contain\--omitted-width-nonpercent-height.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/tall--contain--omitted-width-nonpercent-height.html "css/css-backgrounds/background-size/vector/tall--contain--omitted-width-nonpercent-height.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/tall--contain--omitted-width-nonpercent-height.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/tall--contain--omitted-width-nonpercent-height.html)
- [tall\--contain\--omitted-width-omitted-height-viewbox.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/tall--contain--omitted-width-omitted-height-viewbox.html "css/css-backgrounds/background-size/vector/tall--contain--omitted-width-omitted-height-viewbox.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/tall--contain--omitted-width-omitted-height-viewbox.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/tall--contain--omitted-width-omitted-height-viewbox.html)
- [tall\--contain\--omitted-width-omitted-height.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/tall--contain--omitted-width-omitted-height.html "css/css-backgrounds/background-size/vector/tall--contain--omitted-width-omitted-height.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/tall--contain--omitted-width-omitted-height.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/tall--contain--omitted-width-omitted-height.html)
- [tall\--contain\--omitted-width-percent-height-viewbox.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/tall--contain--omitted-width-percent-height-viewbox.html "css/css-backgrounds/background-size/vector/tall--contain--omitted-width-percent-height-viewbox.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/tall--contain--omitted-width-percent-height-viewbox.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/tall--contain--omitted-width-percent-height-viewbox.html)
- [tall\--contain\--omitted-width-percent-height.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/tall--contain--omitted-width-percent-height.html "css/css-backgrounds/background-size/vector/tall--contain--omitted-width-percent-height.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/tall--contain--omitted-width-percent-height.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/tall--contain--omitted-width-percent-height.html)
- [tall\--contain\--percent-width-nonpercent-height-viewbox.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/tall--contain--percent-width-nonpercent-height-viewbox.html "css/css-backgrounds/background-size/vector/tall--contain--percent-width-nonpercent-height-viewbox.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/tall--contain--percent-width-nonpercent-height-viewbox.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/tall--contain--percent-width-nonpercent-height-viewbox.html)
- [tall\--contain\--percent-width-nonpercent-height.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/tall--contain--percent-width-nonpercent-height.html "css/css-backgrounds/background-size/vector/tall--contain--percent-width-nonpercent-height.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/tall--contain--percent-width-nonpercent-height.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/tall--contain--percent-width-nonpercent-height.html)
- [tall\--contain\--percent-width-omitted-height-viewbox.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/tall--contain--percent-width-omitted-height-viewbox.html "css/css-backgrounds/background-size/vector/tall--contain--percent-width-omitted-height-viewbox.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/tall--contain--percent-width-omitted-height-viewbox.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/tall--contain--percent-width-omitted-height-viewbox.html)
- [tall\--contain\--percent-width-omitted-height.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/tall--contain--percent-width-omitted-height.html "css/css-backgrounds/background-size/vector/tall--contain--percent-width-omitted-height.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/tall--contain--percent-width-omitted-height.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/tall--contain--percent-width-omitted-height.html)
- [tall\--contain\--percent-width-percent-height-viewbox.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/tall--contain--percent-width-percent-height-viewbox.html "css/css-backgrounds/background-size/vector/tall--contain--percent-width-percent-height-viewbox.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/tall--contain--percent-width-percent-height-viewbox.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/tall--contain--percent-width-percent-height-viewbox.html)
- [tall\--contain\--percent-width-percent-height.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/tall--contain--percent-width-percent-height.html "css/css-backgrounds/background-size/vector/tall--contain--percent-width-percent-height.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/tall--contain--percent-width-percent-height.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/tall--contain--percent-width-percent-height.html)
- [tall\--contain\--width.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/tall--contain--width.html "css/css-backgrounds/background-size/vector/tall--contain--width.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/tall--contain--width.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/tall--contain--width.html)
- [tall\--cover\--height.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/tall--cover--height.html "css/css-backgrounds/background-size/vector/tall--cover--height.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/tall--cover--height.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/tall--cover--height.html)
- [tall\--cover\--nonpercent-width-nonpercent-height\--crisp.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/tall--cover--nonpercent-width-nonpercent-height--crisp.html "css/css-backgrounds/background-size/vector/tall--cover--nonpercent-width-nonpercent-height--crisp.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/tall--cover--nonpercent-width-nonpercent-height--crisp.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/tall--cover--nonpercent-width-nonpercent-height--crisp.html)
- [tall\--cover\--nonpercent-width-nonpercent-height-viewbox\--crisp.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/tall--cover--nonpercent-width-nonpercent-height-viewbox--crisp.html "css/css-backgrounds/background-size/vector/tall--cover--nonpercent-width-nonpercent-height-viewbox--crisp.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/tall--cover--nonpercent-width-nonpercent-height-viewbox--crisp.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/tall--cover--nonpercent-width-nonpercent-height-viewbox--crisp.html)
- [tall\--cover\--nonpercent-width-nonpercent-height-viewbox.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/tall--cover--nonpercent-width-nonpercent-height-viewbox.html "css/css-backgrounds/background-size/vector/tall--cover--nonpercent-width-nonpercent-height-viewbox.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/tall--cover--nonpercent-width-nonpercent-height-viewbox.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/tall--cover--nonpercent-width-nonpercent-height-viewbox.html)
- [tall\--cover\--nonpercent-width-nonpercent-height.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/tall--cover--nonpercent-width-nonpercent-height.html "css/css-backgrounds/background-size/vector/tall--cover--nonpercent-width-nonpercent-height.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/tall--cover--nonpercent-width-nonpercent-height.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/tall--cover--nonpercent-width-nonpercent-height.html)
- [tall\--cover\--nonpercent-width-omitted-height-viewbox.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/tall--cover--nonpercent-width-omitted-height-viewbox.html "css/css-backgrounds/background-size/vector/tall--cover--nonpercent-width-omitted-height-viewbox.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/tall--cover--nonpercent-width-omitted-height-viewbox.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/tall--cover--nonpercent-width-omitted-height-viewbox.html)
- [tall\--cover\--nonpercent-width-omitted-height.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/tall--cover--nonpercent-width-omitted-height.html "css/css-backgrounds/background-size/vector/tall--cover--nonpercent-width-omitted-height.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/tall--cover--nonpercent-width-omitted-height.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/tall--cover--nonpercent-width-omitted-height.html)
- [tall\--cover\--nonpercent-width-percent-height-viewbox.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/tall--cover--nonpercent-width-percent-height-viewbox.html "css/css-backgrounds/background-size/vector/tall--cover--nonpercent-width-percent-height-viewbox.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/tall--cover--nonpercent-width-percent-height-viewbox.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/tall--cover--nonpercent-width-percent-height-viewbox.html)
- [tall\--cover\--nonpercent-width-percent-height.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/tall--cover--nonpercent-width-percent-height.html "css/css-backgrounds/background-size/vector/tall--cover--nonpercent-width-percent-height.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/tall--cover--nonpercent-width-percent-height.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/tall--cover--nonpercent-width-percent-height.html)
- [tall\--cover\--omitted-width-nonpercent-height-viewbox.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/tall--cover--omitted-width-nonpercent-height-viewbox.html "css/css-backgrounds/background-size/vector/tall--cover--omitted-width-nonpercent-height-viewbox.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/tall--cover--omitted-width-nonpercent-height-viewbox.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/tall--cover--omitted-width-nonpercent-height-viewbox.html)
- [tall\--cover\--omitted-width-nonpercent-height.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/tall--cover--omitted-width-nonpercent-height.html "css/css-backgrounds/background-size/vector/tall--cover--omitted-width-nonpercent-height.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/tall--cover--omitted-width-nonpercent-height.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/tall--cover--omitted-width-nonpercent-height.html)
- [tall\--cover\--omitted-width-omitted-height-viewbox.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/tall--cover--omitted-width-omitted-height-viewbox.html "css/css-backgrounds/background-size/vector/tall--cover--omitted-width-omitted-height-viewbox.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/tall--cover--omitted-width-omitted-height-viewbox.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/tall--cover--omitted-width-omitted-height-viewbox.html)
- [tall\--cover\--omitted-width-omitted-height.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/tall--cover--omitted-width-omitted-height.html "css/css-backgrounds/background-size/vector/tall--cover--omitted-width-omitted-height.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/tall--cover--omitted-width-omitted-height.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/tall--cover--omitted-width-omitted-height.html)
- [tall\--cover\--omitted-width-percent-height-viewbox.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/tall--cover--omitted-width-percent-height-viewbox.html "css/css-backgrounds/background-size/vector/tall--cover--omitted-width-percent-height-viewbox.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/tall--cover--omitted-width-percent-height-viewbox.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/tall--cover--omitted-width-percent-height-viewbox.html)
- [tall\--cover\--omitted-width-percent-height.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/tall--cover--omitted-width-percent-height.html "css/css-backgrounds/background-size/vector/tall--cover--omitted-width-percent-height.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/tall--cover--omitted-width-percent-height.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/tall--cover--omitted-width-percent-height.html)
- [tall\--cover\--percent-width-nonpercent-height-viewbox.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/tall--cover--percent-width-nonpercent-height-viewbox.html "css/css-backgrounds/background-size/vector/tall--cover--percent-width-nonpercent-height-viewbox.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/tall--cover--percent-width-nonpercent-height-viewbox.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/tall--cover--percent-width-nonpercent-height-viewbox.html)
- [tall\--cover\--percent-width-nonpercent-height.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/tall--cover--percent-width-nonpercent-height.html "css/css-backgrounds/background-size/vector/tall--cover--percent-width-nonpercent-height.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/tall--cover--percent-width-nonpercent-height.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/tall--cover--percent-width-nonpercent-height.html)
- [tall\--cover\--percent-width-omitted-height-viewbox.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/tall--cover--percent-width-omitted-height-viewbox.html "css/css-backgrounds/background-size/vector/tall--cover--percent-width-omitted-height-viewbox.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/tall--cover--percent-width-omitted-height-viewbox.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/tall--cover--percent-width-omitted-height-viewbox.html)
- [tall\--cover\--percent-width-omitted-height.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/tall--cover--percent-width-omitted-height.html "css/css-backgrounds/background-size/vector/tall--cover--percent-width-omitted-height.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/tall--cover--percent-width-omitted-height.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/tall--cover--percent-width-omitted-height.html)
- [tall\--cover\--percent-width-percent-height-viewbox.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/tall--cover--percent-width-percent-height-viewbox.html "css/css-backgrounds/background-size/vector/tall--cover--percent-width-percent-height-viewbox.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/tall--cover--percent-width-percent-height-viewbox.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/tall--cover--percent-width-percent-height-viewbox.html)
- [tall\--cover\--percent-width-percent-height.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/tall--cover--percent-width-percent-height.html "css/css-backgrounds/background-size/vector/tall--cover--percent-width-percent-height.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/tall--cover--percent-width-percent-height.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/tall--cover--percent-width-percent-height.html)
- [tall\--cover\--width.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/tall--cover--width.html "css/css-backgrounds/background-size/vector/tall--cover--width.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/tall--cover--width.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/tall--cover--width.html)
- [wide\--12px-auto\--nonpercent-width-nonpercent-height-viewbox.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/wide--12px-auto--nonpercent-width-nonpercent-height-viewbox.html "css/css-backgrounds/background-size/vector/wide--12px-auto--nonpercent-width-nonpercent-height-viewbox.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/wide--12px-auto--nonpercent-width-nonpercent-height-viewbox.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/wide--12px-auto--nonpercent-width-nonpercent-height-viewbox.html)
- [wide\--12px-auto\--nonpercent-width-nonpercent-height.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/wide--12px-auto--nonpercent-width-nonpercent-height.html "css/css-backgrounds/background-size/vector/wide--12px-auto--nonpercent-width-nonpercent-height.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/wide--12px-auto--nonpercent-width-nonpercent-height.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/wide--12px-auto--nonpercent-width-nonpercent-height.html)
- [wide\--12px-auto\--nonpercent-width-omitted-height-viewbox.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/wide--12px-auto--nonpercent-width-omitted-height-viewbox.html "css/css-backgrounds/background-size/vector/wide--12px-auto--nonpercent-width-omitted-height-viewbox.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/wide--12px-auto--nonpercent-width-omitted-height-viewbox.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/wide--12px-auto--nonpercent-width-omitted-height-viewbox.html)
- [wide\--12px-auto\--nonpercent-width-omitted-height.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/wide--12px-auto--nonpercent-width-omitted-height.html "css/css-backgrounds/background-size/vector/wide--12px-auto--nonpercent-width-omitted-height.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/wide--12px-auto--nonpercent-width-omitted-height.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/wide--12px-auto--nonpercent-width-omitted-height.html)
- [wide\--12px-auto\--nonpercent-width-percent-height-viewbox.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/wide--12px-auto--nonpercent-width-percent-height-viewbox.html "css/css-backgrounds/background-size/vector/wide--12px-auto--nonpercent-width-percent-height-viewbox.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/wide--12px-auto--nonpercent-width-percent-height-viewbox.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/wide--12px-auto--nonpercent-width-percent-height-viewbox.html)
- [wide\--12px-auto\--nonpercent-width-percent-height.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/wide--12px-auto--nonpercent-width-percent-height.html "css/css-backgrounds/background-size/vector/wide--12px-auto--nonpercent-width-percent-height.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/wide--12px-auto--nonpercent-width-percent-height.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/wide--12px-auto--nonpercent-width-percent-height.html)
- [wide\--12px-auto\--omitted-width-nonpercent-height-viewbox.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/wide--12px-auto--omitted-width-nonpercent-height-viewbox.html "css/css-backgrounds/background-size/vector/wide--12px-auto--omitted-width-nonpercent-height-viewbox.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/wide--12px-auto--omitted-width-nonpercent-height-viewbox.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/wide--12px-auto--omitted-width-nonpercent-height-viewbox.html)
- [wide\--12px-auto\--omitted-width-nonpercent-height.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/wide--12px-auto--omitted-width-nonpercent-height.html "css/css-backgrounds/background-size/vector/wide--12px-auto--omitted-width-nonpercent-height.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/wide--12px-auto--omitted-width-nonpercent-height.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/wide--12px-auto--omitted-width-nonpercent-height.html)
- [wide\--12px-auto\--omitted-width-omitted-height-viewbox.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/wide--12px-auto--omitted-width-omitted-height-viewbox.html "css/css-backgrounds/background-size/vector/wide--12px-auto--omitted-width-omitted-height-viewbox.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/wide--12px-auto--omitted-width-omitted-height-viewbox.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/wide--12px-auto--omitted-width-omitted-height-viewbox.html)
- [wide\--12px-auto\--omitted-width-omitted-height.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/wide--12px-auto--omitted-width-omitted-height.html "css/css-backgrounds/background-size/vector/wide--12px-auto--omitted-width-omitted-height.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/wide--12px-auto--omitted-width-omitted-height.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/wide--12px-auto--omitted-width-omitted-height.html)
- [wide\--12px-auto\--omitted-width-percent-height-viewbox.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/wide--12px-auto--omitted-width-percent-height-viewbox.html "css/css-backgrounds/background-size/vector/wide--12px-auto--omitted-width-percent-height-viewbox.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/wide--12px-auto--omitted-width-percent-height-viewbox.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/wide--12px-auto--omitted-width-percent-height-viewbox.html)
- [wide\--12px-auto\--omitted-width-percent-height.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/wide--12px-auto--omitted-width-percent-height.html "css/css-backgrounds/background-size/vector/wide--12px-auto--omitted-width-percent-height.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/wide--12px-auto--omitted-width-percent-height.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/wide--12px-auto--omitted-width-percent-height.html)
- [wide\--12px-auto\--percent-width-nonpercent-height-viewbox.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/wide--12px-auto--percent-width-nonpercent-height-viewbox.html "css/css-backgrounds/background-size/vector/wide--12px-auto--percent-width-nonpercent-height-viewbox.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/wide--12px-auto--percent-width-nonpercent-height-viewbox.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/wide--12px-auto--percent-width-nonpercent-height-viewbox.html)
- [wide\--12px-auto\--percent-width-nonpercent-height.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/wide--12px-auto--percent-width-nonpercent-height.html "css/css-backgrounds/background-size/vector/wide--12px-auto--percent-width-nonpercent-height.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/wide--12px-auto--percent-width-nonpercent-height.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/wide--12px-auto--percent-width-nonpercent-height.html)
- [wide\--12px-auto\--percent-width-omitted-height-viewbox.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/wide--12px-auto--percent-width-omitted-height-viewbox.html "css/css-backgrounds/background-size/vector/wide--12px-auto--percent-width-omitted-height-viewbox.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/wide--12px-auto--percent-width-omitted-height-viewbox.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/wide--12px-auto--percent-width-omitted-height-viewbox.html)
- [wide\--12px-auto\--percent-width-omitted-height.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/wide--12px-auto--percent-width-omitted-height.html "css/css-backgrounds/background-size/vector/wide--12px-auto--percent-width-omitted-height.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/wide--12px-auto--percent-width-omitted-height.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/wide--12px-auto--percent-width-omitted-height.html)
- [wide\--12px-auto\--percent-width-percent-height-viewbox.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/wide--12px-auto--percent-width-percent-height-viewbox.html "css/css-backgrounds/background-size/vector/wide--12px-auto--percent-width-percent-height-viewbox.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/wide--12px-auto--percent-width-percent-height-viewbox.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/wide--12px-auto--percent-width-percent-height-viewbox.html)
- [wide\--12px-auto\--percent-width-percent-height.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/wide--12px-auto--percent-width-percent-height.html "css/css-backgrounds/background-size/vector/wide--12px-auto--percent-width-percent-height.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/wide--12px-auto--percent-width-percent-height.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/wide--12px-auto--percent-width-percent-height.html)
- [wide\--auto\--nonpercent-width-nonpercent-height-viewbox.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/wide--auto--nonpercent-width-nonpercent-height-viewbox.html "css/css-backgrounds/background-size/vector/wide--auto--nonpercent-width-nonpercent-height-viewbox.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/wide--auto--nonpercent-width-nonpercent-height-viewbox.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/wide--auto--nonpercent-width-nonpercent-height-viewbox.html)
- [wide\--auto\--nonpercent-width-nonpercent-height.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/wide--auto--nonpercent-width-nonpercent-height.html "css/css-backgrounds/background-size/vector/wide--auto--nonpercent-width-nonpercent-height.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/wide--auto--nonpercent-width-nonpercent-height.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/wide--auto--nonpercent-width-nonpercent-height.html)
- [wide\--auto\--nonpercent-width-omitted-height-viewbox.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/wide--auto--nonpercent-width-omitted-height-viewbox.html "css/css-backgrounds/background-size/vector/wide--auto--nonpercent-width-omitted-height-viewbox.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/wide--auto--nonpercent-width-omitted-height-viewbox.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/wide--auto--nonpercent-width-omitted-height-viewbox.html)
- [wide\--auto\--nonpercent-width-omitted-height.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/wide--auto--nonpercent-width-omitted-height.html "css/css-backgrounds/background-size/vector/wide--auto--nonpercent-width-omitted-height.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/wide--auto--nonpercent-width-omitted-height.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/wide--auto--nonpercent-width-omitted-height.html)
- [wide\--auto\--nonpercent-width-percent-height-viewbox.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/wide--auto--nonpercent-width-percent-height-viewbox.html "css/css-backgrounds/background-size/vector/wide--auto--nonpercent-width-percent-height-viewbox.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/wide--auto--nonpercent-width-percent-height-viewbox.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/wide--auto--nonpercent-width-percent-height-viewbox.html)
- [wide\--auto\--nonpercent-width-percent-height.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/wide--auto--nonpercent-width-percent-height.html "css/css-backgrounds/background-size/vector/wide--auto--nonpercent-width-percent-height.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/wide--auto--nonpercent-width-percent-height.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/wide--auto--nonpercent-width-percent-height.html)
- [wide\--auto\--omitted-width-nonpercent-height-viewbox.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/wide--auto--omitted-width-nonpercent-height-viewbox.html "css/css-backgrounds/background-size/vector/wide--auto--omitted-width-nonpercent-height-viewbox.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/wide--auto--omitted-width-nonpercent-height-viewbox.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/wide--auto--omitted-width-nonpercent-height-viewbox.html)
- [wide\--auto\--omitted-width-nonpercent-height.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/wide--auto--omitted-width-nonpercent-height.html "css/css-backgrounds/background-size/vector/wide--auto--omitted-width-nonpercent-height.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/wide--auto--omitted-width-nonpercent-height.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/wide--auto--omitted-width-nonpercent-height.html)
- [wide\--auto\--omitted-width-omitted-height-viewbox.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/wide--auto--omitted-width-omitted-height-viewbox.html "css/css-backgrounds/background-size/vector/wide--auto--omitted-width-omitted-height-viewbox.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/wide--auto--omitted-width-omitted-height-viewbox.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/wide--auto--omitted-width-omitted-height-viewbox.html)
- [wide\--auto\--omitted-width-omitted-height.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/wide--auto--omitted-width-omitted-height.html "css/css-backgrounds/background-size/vector/wide--auto--omitted-width-omitted-height.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/wide--auto--omitted-width-omitted-height.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/wide--auto--omitted-width-omitted-height.html)
- [wide\--auto\--omitted-width-percent-height-viewbox.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/wide--auto--omitted-width-percent-height-viewbox.html "css/css-backgrounds/background-size/vector/wide--auto--omitted-width-percent-height-viewbox.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/wide--auto--omitted-width-percent-height-viewbox.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/wide--auto--omitted-width-percent-height-viewbox.html)
- [wide\--auto\--omitted-width-percent-height.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/wide--auto--omitted-width-percent-height.html "css/css-backgrounds/background-size/vector/wide--auto--omitted-width-percent-height.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/wide--auto--omitted-width-percent-height.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/wide--auto--omitted-width-percent-height.html)
- [wide\--auto\--percent-width-nonpercent-height-viewbox.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/wide--auto--percent-width-nonpercent-height-viewbox.html "css/css-backgrounds/background-size/vector/wide--auto--percent-width-nonpercent-height-viewbox.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/wide--auto--percent-width-nonpercent-height-viewbox.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/wide--auto--percent-width-nonpercent-height-viewbox.html)
- [wide\--auto\--percent-width-nonpercent-height.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/wide--auto--percent-width-nonpercent-height.html "css/css-backgrounds/background-size/vector/wide--auto--percent-width-nonpercent-height.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/wide--auto--percent-width-nonpercent-height.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/wide--auto--percent-width-nonpercent-height.html)
- [wide\--auto\--percent-width-omitted-height-viewbox.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/wide--auto--percent-width-omitted-height-viewbox.html "css/css-backgrounds/background-size/vector/wide--auto--percent-width-omitted-height-viewbox.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/wide--auto--percent-width-omitted-height-viewbox.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/wide--auto--percent-width-omitted-height-viewbox.html)
- [wide\--auto\--percent-width-omitted-height.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/wide--auto--percent-width-omitted-height.html "css/css-backgrounds/background-size/vector/wide--auto--percent-width-omitted-height.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/wide--auto--percent-width-omitted-height.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/wide--auto--percent-width-omitted-height.html)
- [wide\--auto\--percent-width-percent-height-viewbox.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/wide--auto--percent-width-percent-height-viewbox.html "css/css-backgrounds/background-size/vector/wide--auto--percent-width-percent-height-viewbox.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/wide--auto--percent-width-percent-height-viewbox.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/wide--auto--percent-width-percent-height-viewbox.html)
- [wide\--auto\--percent-width-percent-height.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/wide--auto--percent-width-percent-height.html "css/css-backgrounds/background-size/vector/wide--auto--percent-width-percent-height.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/wide--auto--percent-width-percent-height.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/wide--auto--percent-width-percent-height.html)
- [wide\--auto-32px\--nonpercent-width-nonpercent-height-viewbox.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/wide--auto-32px--nonpercent-width-nonpercent-height-viewbox.html "css/css-backgrounds/background-size/vector/wide--auto-32px--nonpercent-width-nonpercent-height-viewbox.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/wide--auto-32px--nonpercent-width-nonpercent-height-viewbox.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/wide--auto-32px--nonpercent-width-nonpercent-height-viewbox.html)
- [wide\--auto-32px\--nonpercent-width-nonpercent-height.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/wide--auto-32px--nonpercent-width-nonpercent-height.html "css/css-backgrounds/background-size/vector/wide--auto-32px--nonpercent-width-nonpercent-height.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/wide--auto-32px--nonpercent-width-nonpercent-height.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/wide--auto-32px--nonpercent-width-nonpercent-height.html)
- [wide\--auto-32px\--nonpercent-width-omitted-height-viewbox.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/wide--auto-32px--nonpercent-width-omitted-height-viewbox.html "css/css-backgrounds/background-size/vector/wide--auto-32px--nonpercent-width-omitted-height-viewbox.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/wide--auto-32px--nonpercent-width-omitted-height-viewbox.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/wide--auto-32px--nonpercent-width-omitted-height-viewbox.html)
- [wide\--auto-32px\--nonpercent-width-omitted-height.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/wide--auto-32px--nonpercent-width-omitted-height.html "css/css-backgrounds/background-size/vector/wide--auto-32px--nonpercent-width-omitted-height.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/wide--auto-32px--nonpercent-width-omitted-height.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/wide--auto-32px--nonpercent-width-omitted-height.html)
- [wide\--auto-32px\--nonpercent-width-percent-height-viewbox.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/wide--auto-32px--nonpercent-width-percent-height-viewbox.html "css/css-backgrounds/background-size/vector/wide--auto-32px--nonpercent-width-percent-height-viewbox.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/wide--auto-32px--nonpercent-width-percent-height-viewbox.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/wide--auto-32px--nonpercent-width-percent-height-viewbox.html)
- [wide\--auto-32px\--nonpercent-width-percent-height.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/wide--auto-32px--nonpercent-width-percent-height.html "css/css-backgrounds/background-size/vector/wide--auto-32px--nonpercent-width-percent-height.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/wide--auto-32px--nonpercent-width-percent-height.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/wide--auto-32px--nonpercent-width-percent-height.html)
- [wide\--auto-32px\--omitted-width-nonpercent-height-viewbox.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/wide--auto-32px--omitted-width-nonpercent-height-viewbox.html "css/css-backgrounds/background-size/vector/wide--auto-32px--omitted-width-nonpercent-height-viewbox.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/wide--auto-32px--omitted-width-nonpercent-height-viewbox.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/wide--auto-32px--omitted-width-nonpercent-height-viewbox.html)
- [wide\--auto-32px\--omitted-width-nonpercent-height.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/wide--auto-32px--omitted-width-nonpercent-height.html "css/css-backgrounds/background-size/vector/wide--auto-32px--omitted-width-nonpercent-height.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/wide--auto-32px--omitted-width-nonpercent-height.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/wide--auto-32px--omitted-width-nonpercent-height.html)
- [wide\--auto-32px\--omitted-width-omitted-height-viewbox.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/wide--auto-32px--omitted-width-omitted-height-viewbox.html "css/css-backgrounds/background-size/vector/wide--auto-32px--omitted-width-omitted-height-viewbox.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/wide--auto-32px--omitted-width-omitted-height-viewbox.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/wide--auto-32px--omitted-width-omitted-height-viewbox.html)
- [wide\--auto-32px\--omitted-width-omitted-height.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/wide--auto-32px--omitted-width-omitted-height.html "css/css-backgrounds/background-size/vector/wide--auto-32px--omitted-width-omitted-height.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/wide--auto-32px--omitted-width-omitted-height.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/wide--auto-32px--omitted-width-omitted-height.html)
- [wide\--auto-32px\--omitted-width-percent-height-viewbox.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/wide--auto-32px--omitted-width-percent-height-viewbox.html "css/css-backgrounds/background-size/vector/wide--auto-32px--omitted-width-percent-height-viewbox.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/wide--auto-32px--omitted-width-percent-height-viewbox.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/wide--auto-32px--omitted-width-percent-height-viewbox.html)
- [wide\--auto-32px\--omitted-width-percent-height.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/wide--auto-32px--omitted-width-percent-height.html "css/css-backgrounds/background-size/vector/wide--auto-32px--omitted-width-percent-height.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/wide--auto-32px--omitted-width-percent-height.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/wide--auto-32px--omitted-width-percent-height.html)
- [wide\--auto-32px\--percent-width-nonpercent-height-viewbox.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/wide--auto-32px--percent-width-nonpercent-height-viewbox.html "css/css-backgrounds/background-size/vector/wide--auto-32px--percent-width-nonpercent-height-viewbox.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/wide--auto-32px--percent-width-nonpercent-height-viewbox.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/wide--auto-32px--percent-width-nonpercent-height-viewbox.html)
- [wide\--auto-32px\--percent-width-nonpercent-height.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/wide--auto-32px--percent-width-nonpercent-height.html "css/css-backgrounds/background-size/vector/wide--auto-32px--percent-width-nonpercent-height.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/wide--auto-32px--percent-width-nonpercent-height.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/wide--auto-32px--percent-width-nonpercent-height.html)
- [wide\--auto-32px\--percent-width-omitted-height-viewbox.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/wide--auto-32px--percent-width-omitted-height-viewbox.html "css/css-backgrounds/background-size/vector/wide--auto-32px--percent-width-omitted-height-viewbox.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/wide--auto-32px--percent-width-omitted-height-viewbox.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/wide--auto-32px--percent-width-omitted-height-viewbox.html)
- [wide\--auto-32px\--percent-width-omitted-height.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/wide--auto-32px--percent-width-omitted-height.html "css/css-backgrounds/background-size/vector/wide--auto-32px--percent-width-omitted-height.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/wide--auto-32px--percent-width-omitted-height.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/wide--auto-32px--percent-width-omitted-height.html)
- [wide\--auto-32px\--percent-width-percent-height-viewbox.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/wide--auto-32px--percent-width-percent-height-viewbox.html "css/css-backgrounds/background-size/vector/wide--auto-32px--percent-width-percent-height-viewbox.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/wide--auto-32px--percent-width-percent-height-viewbox.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/wide--auto-32px--percent-width-percent-height-viewbox.html)
- [wide\--auto-32px\--percent-width-percent-height.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/wide--auto-32px--percent-width-percent-height.html "css/css-backgrounds/background-size/vector/wide--auto-32px--percent-width-percent-height.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/wide--auto-32px--percent-width-percent-height.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/wide--auto-32px--percent-width-percent-height.html)
- [wide\--contain\--height.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/wide--contain--height.html "css/css-backgrounds/background-size/vector/wide--contain--height.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/wide--contain--height.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/wide--contain--height.html)
- [wide\--contain\--nonpercent-width-nonpercent-height-viewbox.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/wide--contain--nonpercent-width-nonpercent-height-viewbox.html "css/css-backgrounds/background-size/vector/wide--contain--nonpercent-width-nonpercent-height-viewbox.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/wide--contain--nonpercent-width-nonpercent-height-viewbox.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/wide--contain--nonpercent-width-nonpercent-height-viewbox.html)
- [wide\--contain\--nonpercent-width-nonpercent-height.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/wide--contain--nonpercent-width-nonpercent-height.html "css/css-backgrounds/background-size/vector/wide--contain--nonpercent-width-nonpercent-height.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/wide--contain--nonpercent-width-nonpercent-height.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/wide--contain--nonpercent-width-nonpercent-height.html)
- [wide\--contain\--nonpercent-width-omitted-height-viewbox.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/wide--contain--nonpercent-width-omitted-height-viewbox.html "css/css-backgrounds/background-size/vector/wide--contain--nonpercent-width-omitted-height-viewbox.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/wide--contain--nonpercent-width-omitted-height-viewbox.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/wide--contain--nonpercent-width-omitted-height-viewbox.html)
- [wide\--contain\--nonpercent-width-omitted-height.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/wide--contain--nonpercent-width-omitted-height.html "css/css-backgrounds/background-size/vector/wide--contain--nonpercent-width-omitted-height.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/wide--contain--nonpercent-width-omitted-height.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/wide--contain--nonpercent-width-omitted-height.html)
- [wide\--contain\--nonpercent-width-percent-height-viewbox.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/wide--contain--nonpercent-width-percent-height-viewbox.html "css/css-backgrounds/background-size/vector/wide--contain--nonpercent-width-percent-height-viewbox.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/wide--contain--nonpercent-width-percent-height-viewbox.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/wide--contain--nonpercent-width-percent-height-viewbox.html)
- [wide\--contain\--nonpercent-width-percent-height.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/wide--contain--nonpercent-width-percent-height.html "css/css-backgrounds/background-size/vector/wide--contain--nonpercent-width-percent-height.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/wide--contain--nonpercent-width-percent-height.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/wide--contain--nonpercent-width-percent-height.html)
- [wide\--contain\--omitted-width-nonpercent-height-viewbox.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/wide--contain--omitted-width-nonpercent-height-viewbox.html "css/css-backgrounds/background-size/vector/wide--contain--omitted-width-nonpercent-height-viewbox.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/wide--contain--omitted-width-nonpercent-height-viewbox.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/wide--contain--omitted-width-nonpercent-height-viewbox.html)
- [wide\--contain\--omitted-width-nonpercent-height.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/wide--contain--omitted-width-nonpercent-height.html "css/css-backgrounds/background-size/vector/wide--contain--omitted-width-nonpercent-height.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/wide--contain--omitted-width-nonpercent-height.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/wide--contain--omitted-width-nonpercent-height.html)
- [wide\--contain\--omitted-width-omitted-height-viewbox.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/wide--contain--omitted-width-omitted-height-viewbox.html "css/css-backgrounds/background-size/vector/wide--contain--omitted-width-omitted-height-viewbox.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/wide--contain--omitted-width-omitted-height-viewbox.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/wide--contain--omitted-width-omitted-height-viewbox.html)
- [wide\--contain\--omitted-width-omitted-height.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/wide--contain--omitted-width-omitted-height.html "css/css-backgrounds/background-size/vector/wide--contain--omitted-width-omitted-height.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/wide--contain--omitted-width-omitted-height.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/wide--contain--omitted-width-omitted-height.html)
- [wide\--contain\--omitted-width-percent-height-viewbox.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/wide--contain--omitted-width-percent-height-viewbox.html "css/css-backgrounds/background-size/vector/wide--contain--omitted-width-percent-height-viewbox.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/wide--contain--omitted-width-percent-height-viewbox.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/wide--contain--omitted-width-percent-height-viewbox.html)
- [wide\--contain\--omitted-width-percent-height.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/wide--contain--omitted-width-percent-height.html "css/css-backgrounds/background-size/vector/wide--contain--omitted-width-percent-height.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/wide--contain--omitted-width-percent-height.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/wide--contain--omitted-width-percent-height.html)
- [wide\--contain\--percent-width-nonpercent-height-viewbox.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/wide--contain--percent-width-nonpercent-height-viewbox.html "css/css-backgrounds/background-size/vector/wide--contain--percent-width-nonpercent-height-viewbox.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/wide--contain--percent-width-nonpercent-height-viewbox.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/wide--contain--percent-width-nonpercent-height-viewbox.html)
- [wide\--contain\--percent-width-nonpercent-height.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/wide--contain--percent-width-nonpercent-height.html "css/css-backgrounds/background-size/vector/wide--contain--percent-width-nonpercent-height.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/wide--contain--percent-width-nonpercent-height.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/wide--contain--percent-width-nonpercent-height.html)
- [wide\--contain\--percent-width-omitted-height-viewbox.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/wide--contain--percent-width-omitted-height-viewbox.html "css/css-backgrounds/background-size/vector/wide--contain--percent-width-omitted-height-viewbox.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/wide--contain--percent-width-omitted-height-viewbox.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/wide--contain--percent-width-omitted-height-viewbox.html)
- [wide\--contain\--percent-width-omitted-height.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/wide--contain--percent-width-omitted-height.html "css/css-backgrounds/background-size/vector/wide--contain--percent-width-omitted-height.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/wide--contain--percent-width-omitted-height.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/wide--contain--percent-width-omitted-height.html)
- [wide\--contain\--percent-width-percent-height-viewbox.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/wide--contain--percent-width-percent-height-viewbox.html "css/css-backgrounds/background-size/vector/wide--contain--percent-width-percent-height-viewbox.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/wide--contain--percent-width-percent-height-viewbox.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/wide--contain--percent-width-percent-height-viewbox.html)
- [wide\--contain\--percent-width-percent-height.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/wide--contain--percent-width-percent-height.html "css/css-backgrounds/background-size/vector/wide--contain--percent-width-percent-height.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/wide--contain--percent-width-percent-height.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/wide--contain--percent-width-percent-height.html)
- [wide\--contain\--width.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/wide--contain--width.html "css/css-backgrounds/background-size/vector/wide--contain--width.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/wide--contain--width.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/wide--contain--width.html)
- [wide\--cover\--height.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/wide--cover--height.html "css/css-backgrounds/background-size/vector/wide--cover--height.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/wide--cover--height.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/wide--cover--height.html)
- [wide\--cover\--nonpercent-width-nonpercent-height-viewbox.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/wide--cover--nonpercent-width-nonpercent-height-viewbox.html "css/css-backgrounds/background-size/vector/wide--cover--nonpercent-width-nonpercent-height-viewbox.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/wide--cover--nonpercent-width-nonpercent-height-viewbox.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/wide--cover--nonpercent-width-nonpercent-height-viewbox.html)
- [wide\--cover\--nonpercent-width-nonpercent-height.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/wide--cover--nonpercent-width-nonpercent-height.html "css/css-backgrounds/background-size/vector/wide--cover--nonpercent-width-nonpercent-height.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/wide--cover--nonpercent-width-nonpercent-height.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/wide--cover--nonpercent-width-nonpercent-height.html)
- [wide\--cover\--nonpercent-width-omitted-height-viewbox.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/wide--cover--nonpercent-width-omitted-height-viewbox.html "css/css-backgrounds/background-size/vector/wide--cover--nonpercent-width-omitted-height-viewbox.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/wide--cover--nonpercent-width-omitted-height-viewbox.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/wide--cover--nonpercent-width-omitted-height-viewbox.html)
- [wide\--cover\--nonpercent-width-omitted-height.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/wide--cover--nonpercent-width-omitted-height.html "css/css-backgrounds/background-size/vector/wide--cover--nonpercent-width-omitted-height.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/wide--cover--nonpercent-width-omitted-height.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/wide--cover--nonpercent-width-omitted-height.html)
- [wide\--cover\--nonpercent-width-percent-height-viewbox.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/wide--cover--nonpercent-width-percent-height-viewbox.html "css/css-backgrounds/background-size/vector/wide--cover--nonpercent-width-percent-height-viewbox.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/wide--cover--nonpercent-width-percent-height-viewbox.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/wide--cover--nonpercent-width-percent-height-viewbox.html)
- [wide\--cover\--nonpercent-width-percent-height.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/wide--cover--nonpercent-width-percent-height.html "css/css-backgrounds/background-size/vector/wide--cover--nonpercent-width-percent-height.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/wide--cover--nonpercent-width-percent-height.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/wide--cover--nonpercent-width-percent-height.html)
- [wide\--cover\--omitted-width-nonpercent-height-viewbox.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/wide--cover--omitted-width-nonpercent-height-viewbox.html "css/css-backgrounds/background-size/vector/wide--cover--omitted-width-nonpercent-height-viewbox.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/wide--cover--omitted-width-nonpercent-height-viewbox.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/wide--cover--omitted-width-nonpercent-height-viewbox.html)
- [wide\--cover\--omitted-width-nonpercent-height.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/wide--cover--omitted-width-nonpercent-height.html "css/css-backgrounds/background-size/vector/wide--cover--omitted-width-nonpercent-height.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/wide--cover--omitted-width-nonpercent-height.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/wide--cover--omitted-width-nonpercent-height.html)
- [wide\--cover\--omitted-width-omitted-height-viewbox.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/wide--cover--omitted-width-omitted-height-viewbox.html "css/css-backgrounds/background-size/vector/wide--cover--omitted-width-omitted-height-viewbox.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/wide--cover--omitted-width-omitted-height-viewbox.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/wide--cover--omitted-width-omitted-height-viewbox.html)
- [wide\--cover\--omitted-width-omitted-height.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/wide--cover--omitted-width-omitted-height.html "css/css-backgrounds/background-size/vector/wide--cover--omitted-width-omitted-height.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/wide--cover--omitted-width-omitted-height.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/wide--cover--omitted-width-omitted-height.html)
- [wide\--cover\--omitted-width-percent-height-viewbox.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/wide--cover--omitted-width-percent-height-viewbox.html "css/css-backgrounds/background-size/vector/wide--cover--omitted-width-percent-height-viewbox.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/wide--cover--omitted-width-percent-height-viewbox.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/wide--cover--omitted-width-percent-height-viewbox.html)
- [wide\--cover\--omitted-width-percent-height.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/wide--cover--omitted-width-percent-height.html "css/css-backgrounds/background-size/vector/wide--cover--omitted-width-percent-height.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/wide--cover--omitted-width-percent-height.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/wide--cover--omitted-width-percent-height.html)
- [wide\--cover\--percent-width-nonpercent-height-viewbox.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/wide--cover--percent-width-nonpercent-height-viewbox.html "css/css-backgrounds/background-size/vector/wide--cover--percent-width-nonpercent-height-viewbox.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/wide--cover--percent-width-nonpercent-height-viewbox.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/wide--cover--percent-width-nonpercent-height-viewbox.html)
- [wide\--cover\--percent-width-nonpercent-height.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/wide--cover--percent-width-nonpercent-height.html "css/css-backgrounds/background-size/vector/wide--cover--percent-width-nonpercent-height.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/wide--cover--percent-width-nonpercent-height.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/wide--cover--percent-width-nonpercent-height.html)
- [wide\--cover\--percent-width-omitted-height-viewbox.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/wide--cover--percent-width-omitted-height-viewbox.html "css/css-backgrounds/background-size/vector/wide--cover--percent-width-omitted-height-viewbox.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/wide--cover--percent-width-omitted-height-viewbox.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/wide--cover--percent-width-omitted-height-viewbox.html)
- [wide\--cover\--percent-width-omitted-height.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/wide--cover--percent-width-omitted-height.html "css/css-backgrounds/background-size/vector/wide--cover--percent-width-omitted-height.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/wide--cover--percent-width-omitted-height.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/wide--cover--percent-width-omitted-height.html)
- [wide\--cover\--percent-width-percent-height-viewbox.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/wide--cover--percent-width-percent-height-viewbox.html "css/css-backgrounds/background-size/vector/wide--cover--percent-width-percent-height-viewbox.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/wide--cover--percent-width-percent-height-viewbox.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/wide--cover--percent-width-percent-height-viewbox.html)
- [wide\--cover\--percent-width-percent-height.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/wide--cover--percent-width-percent-height.html "css/css-backgrounds/background-size/vector/wide--cover--percent-width-percent-height.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/wide--cover--percent-width-percent-height.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/wide--cover--percent-width-percent-height.html)
- [wide\--cover\--width.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/wide--cover--width.html "css/css-backgrounds/background-size/vector/wide--cover--width.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/wide--cover--width.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/wide--cover--width.html)
- [zero-height-ratio-5px-auto.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/zero-height-ratio-5px-auto.html "css/css-backgrounds/background-size/vector/zero-height-ratio-5px-auto.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/zero-height-ratio-5px-auto.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/zero-height-ratio-5px-auto.html)
- [zero-height-ratio-auto-5px.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/zero-height-ratio-auto-5px.html "css/css-backgrounds/background-size/vector/zero-height-ratio-auto-5px.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/zero-height-ratio-auto-5px.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/zero-height-ratio-auto-5px.html)
- [zero-height-ratio-auto-auto.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/zero-height-ratio-auto-auto.html "css/css-backgrounds/background-size/vector/zero-height-ratio-auto-auto.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/zero-height-ratio-auto-auto.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/zero-height-ratio-auto-auto.html)
- [zero-height-ratio-contain.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/zero-height-ratio-contain.html "css/css-backgrounds/background-size/vector/zero-height-ratio-contain.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/zero-height-ratio-contain.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/zero-height-ratio-contain.html)
- [zero-height-ratio-cover.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/zero-height-ratio-cover.html "css/css-backgrounds/background-size/vector/zero-height-ratio-cover.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/zero-height-ratio-cover.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/zero-height-ratio-cover.html)
- [zero-ratio-no-dimensions-5px-auto.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/zero-ratio-no-dimensions-5px-auto.html "css/css-backgrounds/background-size/vector/zero-ratio-no-dimensions-5px-auto.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/zero-ratio-no-dimensions-5px-auto.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/zero-ratio-no-dimensions-5px-auto.html)
- [zero-ratio-no-dimensions-auto-5px.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/zero-ratio-no-dimensions-auto-5px.html "css/css-backgrounds/background-size/vector/zero-ratio-no-dimensions-auto-5px.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/zero-ratio-no-dimensions-auto-5px.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/zero-ratio-no-dimensions-auto-5px.html)
- [zero-ratio-no-dimensions-auto-auto.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/zero-ratio-no-dimensions-auto-auto.html "css/css-backgrounds/background-size/vector/zero-ratio-no-dimensions-auto-auto.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/zero-ratio-no-dimensions-auto-auto.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/zero-ratio-no-dimensions-auto-auto.html)
- [zero-ratio-no-dimensions-contain.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/zero-ratio-no-dimensions-contain.html "css/css-backgrounds/background-size/vector/zero-ratio-no-dimensions-contain.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/zero-ratio-no-dimensions-contain.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/zero-ratio-no-dimensions-contain.html)
- [zero-ratio-no-dimensions-cover.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/zero-ratio-no-dimensions-cover.html "css/css-backgrounds/background-size/vector/zero-ratio-no-dimensions-cover.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/zero-ratio-no-dimensions-cover.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/zero-ratio-no-dimensions-cover.html)
- [zero-width-ratio-5px-auto.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/zero-width-ratio-5px-auto.html "css/css-backgrounds/background-size/vector/zero-width-ratio-5px-auto.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/zero-width-ratio-5px-auto.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/zero-width-ratio-5px-auto.html)
- [zero-width-ratio-auto-5px.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/zero-width-ratio-auto-5px.html "css/css-backgrounds/background-size/vector/zero-width-ratio-auto-5px.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/zero-width-ratio-auto-5px.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/zero-width-ratio-auto-5px.html)
- [zero-width-ratio-auto-auto.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/zero-width-ratio-auto-auto.html "css/css-backgrounds/background-size/vector/zero-width-ratio-auto-auto.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/zero-width-ratio-auto-auto.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/zero-width-ratio-auto-auto.html)
- [zero-width-ratio-contain.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/zero-width-ratio-contain.html "css/css-backgrounds/background-size/vector/zero-width-ratio-contain.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/zero-width-ratio-contain.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/zero-width-ratio-contain.html)
- [zero-width-ratio-cover.html](https://wpt.fyi/results/css/css-backgrounds/background-size/vector/zero-width-ratio-cover.html "css/css-backgrounds/background-size/vector/zero-width-ratio-cover.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-size/vector/zero-width-ratio-cover.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-size/vector/zero-width-ratio-cover.html)
- [css3-background-size-001.html](https://wpt.fyi/results/css/css-backgrounds/css3-background-size-001.html "css/css-backgrounds/css3-background-size-001.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/css3-background-size-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/css3-background-size-001.html)
- [css3-background-size-contain.html](https://wpt.fyi/results/css/css-backgrounds/css3-background-size-contain.html "css/css-backgrounds/css3-background-size-contain.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/css3-background-size-contain.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/css3-background-size-contain.html)
- [css3-background-size.html](https://wpt.fyi/results/css/css-backgrounds/css3-background-size.html "css/css-backgrounds/css3-background-size.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/css3-background-size.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/css3-background-size.html)
- [inheritance.sub.html](https://wpt.fyi/results/css/css-backgrounds/inheritance.sub.html "css/css-backgrounds/inheritance.sub.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/inheritance.sub.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/inheritance.sub.html)
- [subpixel-repeat-no-repeat-mix.html](https://wpt.fyi/results/css/css-backgrounds/subpixel-repeat-no-repeat-mix.html "css/css-backgrounds/subpixel-repeat-no-repeat-mix.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/subpixel-repeat-no-repeat-mix.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/subpixel-repeat-no-repeat-mix.html)
- [background-size-computed.html](https://wpt.fyi/results/css/css-backgrounds/parsing/background-size-computed.html "css/css-backgrounds/parsing/background-size-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/parsing/background-size-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/parsing/background-size-computed.html)
- [background-size-invalid.html](https://wpt.fyi/results/css/css-backgrounds/parsing/background-size-invalid.html "css/css-backgrounds/parsing/background-size-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/parsing/background-size-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/parsing/background-size-invalid.html)
- [background-size-valid.html](https://wpt.fyi/results/css/css-backgrounds/parsing/background-size-valid.html "css/css-backgrounds/parsing/background-size-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/parsing/background-size-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/parsing/background-size-valid.html)

This property specifies the size of each [background
image](#background-images). The property's value is given as a comma-separated
list of [\<bg-size\>](#typedef-bg-size) values where

``` prod
<bg-size> = [ <length-percentage [0,∞]> | auto ]{1,2} | cover | contain
```

Values have the following meanings:

[contain]
: Scale the image, while preserving its [natural aspect
 ratio](https://drafts.csswg.org/css-images-3/#natural-aspect-ratio) (if any), to the largest size such that both its
 width and its height can fit inside the [background positioning
 area](#background-positioning-area).

[cover]
: Scale the image, while preserving its [natural aspect
 ratio](https://drafts.csswg.org/css-images-3/#natural-aspect-ratio) (if any), to the smallest size such that both its
 width and its height can completely cover the [background
 positioning
 area](#background-positioning-area).

\[ [[\<length-percentage \[0,∞\]\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage)] \| [auto] \]{1,2}

: The first value gives the width of the corresponding image, the
 second value its height. If only one value is given the second is
 assumed to be
 [auto](#valdef-background-size-auto).

 A
 [\<percentage\>](https://drafts.csswg.org/css-values-4/#percentage-value) is relative to the [background
 positioning
 area](#background-positioning-area).

 An
 [auto](#valdef-background-size-auto) value for one dimension is resolved by using
 the image's [natural aspect
 ratio](https://drafts.csswg.org/css-images-3/#natural-aspect-ratio) and the size of the other dimension, or failing
 that, using the image's [natural
 size](https://drafts.csswg.org/css-images-3/#natural-size), or failing that, treating it as [100%].

 If both values are
 [auto](#valdef-background-size-auto) then the [natural
 width](https://drafts.csswg.org/css-images-3/#natural-width) and/or
 [height](https://drafts.csswg.org/css-images-3/#natural-height) of the image should be used, if any, the missing
 dimension (if any) behaving as
 [auto] as described
 above. If the image has neither [natural
 size](https://drafts.csswg.org/css-images-3/#natural-size), its size is determined as for
 [contain](#valdef-background-size-contain).

 Negative values are invalid.

Here are some examples. The first
example stretches the background image independently in both dimensions
to completely cover the content area:

 div {
 background-image: url(plasma.png);
 background-repeat: no-repeat;
 background-size: 100% 100%;
 background-origin: content-box }

The second example stretches the image so that exactly two copies fit
horizontally. The aspect ratio is preserved:

 p {
 background-image: url(tubes.png);
 background-size: 50% auto;
 background-origin: border-box }

This example forces the background image to be 15 by 15 pixels:

 p {
 background-size: 15px 15px;
 background-image: url(tile.png)}

This example uses the image's natural size. Note that this is the only
possible behavior in CSS level 1 and 2.

 body {
 background-size: auto; /* default */
 background-image: url(flower.png) }

The following example rounds the height of the image to 33.3%, up from
the specified value of 30%. At 30%, three images would fit entirely and
a fourth only partially. After rounding, three images fit exactly. The
width of the image is 20% of the background positioning area width and
is not rounded.

 p {
 background-image: url(chain.png);
 background-repeat: no-repeat round;
 background-size: 20% 30% }

[background-repeat](#propdef-background-repeat) is
[round](#valdef-background-repeat-round) for one (or both) dimensions, there is a second
step. The UA must scale the image in that dimension (or both dimensions)
so that it fits a whole number of times in the [background positioning
area](#background-positioning-area). In the case of the width (height is analogous):

> If `X` ≠ 0 is the width of the image after step one and
> `W` is the width of the background positioning area, then
> the rounded width `X'` = `W` /
> round(`W` / `X`) where round() is a function
> that returns the nearest natural number (integer greater than zero).

If
[background-repeat](#propdef-background-repeat) is
[round](#valdef-background-repeat-round) for one dimension only and if
[background-size](#propdef-background-size) is
[auto](#valdef-background-size-auto) for the other dimension, then there is a third
step: that other dimension is scaled so that the original aspect ratio
is restored.

In this example the background image
is shown at its natural size:

 div {
 background-image: url(image1.png);
 background-repeat: repeat; /* default */
 background-size: auto } /* default */

In the following example, the background is shown with a width of 3em
and its height is scaled proportionally to keep the original aspect
ratio:

 div {
 background-image: url(image2.png);
 background-repeat: repeat; /* default */
 background-size: 3em } /* = '3em auto' */

In the following example, the background is shown with a width of
approximately 3em: scaled so that it fits a whole number of times in the
width of the background. The height is scaled proportionally to keep the
original aspect ratio:

 div {
 background-image: url(image3.png);
 background-repeat: round repeat;
 background-size: 3em auto }

In the following example, the background image is shown with a width of
3em and a height that is either the height corresponding to that width
at the original aspect ratio or slightly less:

 div {
 background-image: url(image4.png);
 background-repeat: repeat round;
 background-size: 3em auto }

In the following example, the background image is shown with a height of
approximately 4em: scaled slightly so that it fits a whole number of
times in the background height. The width is the approximately the width
that corresponds to a 4em height at the original aspect ratio: scaled
slightly so that it fits a whole number of times in the background
width.

 div {
 background-image: url(image5.png);
 background-repeat: round;
 background-size: auto 4em }

If the background image's width or height resolves to zero, this causes
the image not to be displayed. (The effect is the same as if it had been
a transparent image.)

See [§ 2.1 Layering Multiple Background Images](#layering) for how
[background-size](#propdef-background-size) interacts with other
comma-separated background properties to form each [background image
layer](#background-image-layer).

#### 2.9.1. Serialization of [background-size values]
The [specified
value](https://drafts.csswg.org/css-cascade-5/#specified-value) and [computed
value](https://drafts.csswg.org/css-cascade-5/#computed-value) of the
[\<bg-size\>](#typedef-bg-size) type always serialize as two values, even
when the second value is
[auto](#valdef-background-size-auto), due to the [shortest, most backwards-compatible
serialization
principle](https://drafts.csswg.org/cssom-1/#serializing-css-values).

### 2.10. Backgrounds Shorthand: the [background property]
Name:

[background]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<bg-layer\>](#typedef-bg-layer)[\#](https://drafts.csswg.org/css-values-4/#mult-comma)[?](https://drafts.csswg.org/css-values-4/#mult-opt)
[,](https://drafts.csswg.org/css-values-4/#comb-comma)
[\<final-bg-layer\>](#typedef-final-bg-layer)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

see individual properties

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[all
elements](https://www.w3.org/TR/css-pseudo/#generated-content "Includes ::before and ::after pseudo-elements.")

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

see individual properties

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

see individual properties

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

see individual properties

Tests

- [background-331.html](https://wpt.fyi/results/css/css-backgrounds/background-331.html "css/css-backgrounds/background-331.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-331.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-331.html)
- [background-332.html](https://wpt.fyi/results/css/css-backgrounds/background-332.html "css/css-backgrounds/background-332.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-332.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-332.html)
- [background-333.html](https://wpt.fyi/results/css/css-backgrounds/background-333.html "css/css-backgrounds/background-333.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-333.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-333.html)
- [background-334.html](https://wpt.fyi/results/css/css-backgrounds/background-334.html "css/css-backgrounds/background-334.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-334.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-334.html)
- [background-335.html](https://wpt.fyi/results/css/css-backgrounds/background-335.html "css/css-backgrounds/background-335.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-335.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-335.html)
- [background-336.html](https://wpt.fyi/results/css/css-backgrounds/background-336.html "css/css-backgrounds/background-336.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-336.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-336.html)
- [background-computed.html](https://wpt.fyi/results/css/css-backgrounds/parsing/background-computed.html "css/css-backgrounds/parsing/background-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/parsing/background-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/parsing/background-computed.html)
- [background-invalid.html](https://wpt.fyi/results/css/css-backgrounds/parsing/background-invalid.html "css/css-backgrounds/parsing/background-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/parsing/background-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/parsing/background-invalid.html)
- [background-shorthand-serialization.html](https://wpt.fyi/results/css/css-backgrounds/parsing/background-shorthand-serialization.html "css/css-backgrounds/parsing/background-shorthand-serialization.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/parsing/background-shorthand-serialization.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/parsing/background-shorthand-serialization.html)
- [background-valid.html](https://wpt.fyi/results/css/css-backgrounds/parsing/background-valid.html "css/css-backgrounds/parsing/background-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/parsing/background-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/parsing/background-valid.html)

The [background](#propdef-background) property is a [shorthand
property](https://drafts.csswg.org/css-cascade-5/#shorthand-property) for setting most background properties at the same
place in the style sheet. The number of comma-separated items defines
the number of [background image
layers](#background-image-layer). Given a valid declaration, for each layer the
shorthand first sets the corresponding value of each of
[background-image](#propdef-background-image),
[background-position](#propdef-background-position),
[background-size](#propdef-background-size),
[background-repeat](#propdef-background-repeat),
[background-origin](#propdef-background-origin),
[background-clip](#propdef-background-clip) and
[background-attachment](#propdef-background-attachment) to that property's [initial
value](https://drafts.csswg.org/css-cascade-5/#initial-value), then assigns any explicit values specified for this
layer in the declaration. Finally
[background-color](#propdef-background-color) is set to the specified color, if
any, else set to its initial value.

This property's value is given as a comma-separated list of values where

``` prod
<bg-layer> = <bg-image> || <bg-position> [ / <bg-size> ]? || <repeat-style> || <attachment> || <visual-box> || <visual-box>
<final-bg-layer> = <bg-image> || <bg-position> [ / <bg-size> ]? || <repeat-style> || <attachment> || <visual-box> || <visual-box> || <'background-color'>
```

 A color is permitted in
[\<final-bg-layer\>](#typedef-final-bg-layer), but not in
[\<bg-layer\>](#typedef-bg-layer).

If one
[\<visual-box\>](https://drafts.csswg.org/css-box-4/#typedef-visual-box) value is present then it sets both
[background-origin](#propdef-background-origin) and
[background-clip](#propdef-background-clip) to that value. If two values are
present, then the first sets
[background-origin] and
the second [background-clip].

In the first rule of the following
example, only a value for
[background-color](#propdef-background-color) has been given and the other
individual properties are set to their initial values. In the second
rule, many individual properties have been specified.

 body { background: red }
 p { background: url("chess.png") 40% / 10em gray
 round fixed border-box; }

The first rule is equivalent to:

 body {
 background-color: red;
 background-position: 0% 0%;
 background-size: auto;
 background-repeat: repeat;
 background-clip: border-box;
 background-origin: padding-box;
 background-attachment: scroll;
 background-image: none }

The second is equivalent to:

 p {
 background-color: gray;
 background-position: 40% 50%;
 background-size: 10em auto;
 background-repeat: round;
 background-clip: border-box;
 background-origin: border-box;
 background-attachment: fixed;
 background-image: url(chess.png) }

The following example shows how a both
a background color ([#CCC]) and a background image
([url(metal.jpg)]) are set. The image is rescaled to the full
width of the element:

 E { background: #CCC url("metal.jpg") top left / 100% auto no-repeat}

Another example shows equivalence:

 div { background: padding-box url(paper.jpg) white center }
 div {
 background-color: white;
 background-image: url(paper.jpg);
 background-repeat: repeat;
 background-attachment: scroll;
 background-position: center;
 background-clip: padding-box;
 background-origin: padding-box;
 background-size: auto auto }

The following declaration with
multiple, comma-separated values

 background: url(a.png) top left no-repeat,
 url(b.png) center / 100% 100% no-repeat,
 url(c.png) white;

is equivalent to

 background-image: url(a.png), url(b.png), url(c.png);
 background-position: top left, center, top left;
 background-repeat: no-repeat, no-repeat, repeat;
 background-clip: border-box, border-box, border-box;
 background-origin: padding-box, padding-box, padding-box;
 background-size: auto auto, 100% 100%, auto auto;
 background-attachment: scroll, scroll, scroll;
 background-color: white;

### 2.11. Backgrounds of Special Elements

The document [canvas](https://www.w3.org/TR/CSS2/intro.html#the-canvas)
is the infinite surface over which the document is rendered.
[\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")
Since no element corresponds to the canvas, in order to allow styling of
the canvas CSS propagates the background of the [root
element](https://drafts.csswg.org/css-display-4/#root-element) (or, in the case of HTML, the \<body\> element) as
described below. However, if the element whose background would be used
for the canvas is [display:
none](https://drafts.csswg.org/css2/#propdef-display), then the [canvas
background](#canvas-background) is transparent.

If the [canvas
background](#canvas-background) is not opaque, the [canvas surface] below it shows through. The
texture of the [canvas surface](#canvas-surface) is UA-dependent (but is typically an opaque white).

#### 2.11.1. The Canvas Background and the Root Element

The background of the [root
element](https://drafts.csswg.org/css-display-4/#root-element) becomes the [canvas background] and its [background painting
area](#background-painting-area) extends to cover the entire
[canvas](https://www.w3.org/TR/CSS2/intro.html#the-canvas). However, any
images are sized and positioned relative to the root element's box as if
they were painted for that element alone. (In other words, the
[background *positioning*
area](#background-positioning-area)
is determined as for the root element.) The root element does not paint
this background again, i.e., the [used
value](https://drafts.csswg.org/css-cascade-5/#used-value) of its background is
[transparent](https://drafts.csswg.org/css-color-4/#valdef-color-transparent).

Tests

- [background-margin-iframe-root.html](https://wpt.fyi/results/css/css-backgrounds/background-margin-iframe-root.html "css/css-backgrounds/background-margin-iframe-root.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-margin-iframe-root.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-margin-iframe-root.html)
- [background-margin-root.html](https://wpt.fyi/results/css/css-backgrounds/background-margin-root.html "css/css-backgrounds/background-margin-root.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-margin-root.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-margin-root.html)
- [background-margin-transformed-root.html](https://wpt.fyi/results/css/css-backgrounds/background-margin-transformed-root.html "css/css-backgrounds/background-margin-transformed-root.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-margin-transformed-root.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-margin-transformed-root.html)
- [background-margin-will-change-root.html](https://wpt.fyi/results/css/css-backgrounds/background-margin-will-change-root.html "css/css-backgrounds/background-margin-will-change-root.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-margin-will-change-root.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-margin-will-change-root.html)

#### 2.11.2. The Canvas Background and the HTML \<body\> Element

For documents whose root element is an HTML `HTML` element or an
XHTML `html` element
[\[HTML\]](#biblio-html "HTML Standard"): if the
[computed
value](https://drafts.csswg.org/css-cascade-5/#computed-value) of
[background-image](#propdef-background-image) on the [root
element](https://drafts.csswg.org/css-display-4/#root-element) is
[none](#valdef-background-image-none) and its
[background-color](#propdef-background-color) is
[transparent](https://drafts.csswg.org/css-color-4/#valdef-color-transparent), user agents must instead propagate the
[computed values] of the background properties
from that element's first HTML `BODY` or XHTML `body`
child element. The [used
values](https://drafts.csswg.org/css-cascade-5/#used-value) of that `BODY` element's background properties
are their [initial
values](https://drafts.csswg.org/css-cascade-5/#initial-value), and the propagated values are treated as if they were
specified on the root element. It is recommended that authors of HTML
documents specify the canvas background using the `BODY` element
rather than the `HTML` element.

Tests

- [document-canvas-remove-body.html](https://wpt.fyi/results/css/css-backgrounds/document-canvas-remove-body.html "css/css-backgrounds/document-canvas-remove-body.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/document-canvas-remove-body.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/document-canvas-remove-body.html)

 Using
[containment](https://drafts.csswg.org/css-contain-2/#containment) disables this special handling of the HTML
[`body`](https://html.spec.whatwg.org/multipage/sections.html#the-body-element) element. See the [CSS Containment 1 § 2 Strong
Containment: the contain
property](https://drafts.csswg.org/css-contain-1/#contain-property) for
details.

According to these rules, the canvas
underlying the following HTML document will have a "marble" background:

 <!DOCTYPE html PUBLIC '-//W3C//DTD HTML 4.0//EN'
 >
 <html>
 <head>
 <title>Setting the canvas background</title>
 <style type="text/css">
 body { background: url("http://example.org/marble.png") }
 </style>
 </head>
 <body>
 <p>My background is marble.</p>
 </body>
 </html>

#### [2.11.3. ][ The [::first-line](https://drafts.csswg.org/selectors-3/#sel-first-line) Pseudo-element's Background]
The
[::first-line](https://drafts.csswg.org/selectors-3/#sel-first-line) pseudo-element is like an inline-level element
for the purposes of the background (see section 5.12.1 of
[\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")).
That means, e.g., that in a left-justified first line, the background
does not necessarily extend all the way to the right edge.

Tests

- [linear-gradient-currentcolor-first-line.html](https://wpt.fyi/results/css/css-backgrounds/linear-gradient-currentcolor-first-line.html "css/css-backgrounds/linear-gradient-currentcolor-first-line.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/linear-gradient-currentcolor-first-line.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/linear-gradient-currentcolor-first-line.html)

## 3. Borders

The
[border](https://drafts.csswg.org/css-box-4/#border) can either be a predefined style (solid line, double
line, dotted line, pseudo-3D border, etc.) or it can be an image. In the
former case, various properties define the style
([border-style](#propdef-border-style)), color
([border-color](#propdef-border-color)), and thickness
([border-width](#propdef-border-width)) of the border.

### 3.1. Line Colors: the [border-color properties]
Name:

[border-top-color],
[border-right-color],
[border-bottom-color],
[border-left-color]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<color\>](https://drafts.csswg.org/css-color-5/#typedef-color)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

[currentColor](https://www.w3.org/TR/css-color-4/#currentcolor-color)

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

all elements except [ruby base
containers](https://drafts.csswg.org/css-ruby-1/#ruby-base-container-box) and [ruby annotation
containers](https://drafts.csswg.org/css-ruby-1/#ruby-annotation-container-box)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

N/A

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

computed color

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value

[Logical property
group:](https://drafts.csswg.org/css-logical-1/#logical-property-group)

[border-color](#propdef-border-color)

Name:

[border-color]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<color\>](https://drafts.csswg.org/css-color-5/#typedef-color)[{1,4}](https://drafts.csswg.org/css-values-4/#mult-num-range)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

see individual properties

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

all elements except [ruby base
containers](https://drafts.csswg.org/css-ruby-1/#ruby-base-container-box) and [ruby annotation
containers](https://drafts.csswg.org/css-ruby-1/#ruby-annotation-container-box)

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

These properties set the foreground [color] of the
[border](https://drafts.csswg.org/css-box-4/#border) specified by the
[border-style](#propdef-border-style) properties.

The [border-color](#propdef-border-color) property is a [shorthand
property](https://drafts.csswg.org/css-cascade-5/#shorthand-property) for setting
[border-top-color](#propdef-border-top-color),
[border-right-color](#propdef-border-right-color),
[border-bottom-color](#propdef-border-bottom-color), and
[border-left-color](#propdef-border-left-color) in a single declaration.

If there is only one component value, it applies to all sides. If there
are two values, the top and bottom are set to the first value and the
right and left are set to the second. If there are three values, the top
is set to the first value, the left and right are set to the second, and
the bottom is set to the third. If there are four values they apply to
the top, right, bottom, and left, respectively.

### 3.2. Line Patterns: the [border-style properties]
Name:

[border-top-style],
[border-right-style],
[border-bottom-style],
[border-left-style]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<line-style\>](#typedef-line-style)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

none

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

all elements except [ruby base
containers](https://drafts.csswg.org/css-ruby-1/#ruby-base-container-box) and [ruby annotation
containers](https://drafts.csswg.org/css-ruby-1/#ruby-annotation-container-box)

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

Name:

[border-style]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<line-style\>](#typedef-line-style)[{1,4}](https://drafts.csswg.org/css-values-4/#mult-num-range)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

see individual properties

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

all elements except [ruby base
containers](https://drafts.csswg.org/css-ruby-1/#ruby-base-container-box) and [ruby annotation
containers](https://drafts.csswg.org/css-ruby-1/#ruby-annotation-container-box)

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

These properties control whether a
[border](https://drafts.csswg.org/css-box-4/#border) appears, and if it does what [style] it's
drawn in (if it is not overridden by a [border image](#border-images)).

The [border-style](#propdef-border-style) property is a [shorthand
property](https://drafts.csswg.org/css-cascade-5/#shorthand-property) for setting
[border-top-style](#propdef-border-top-style),
[border-right-style](#propdef-border-right-style),
[border-bottom-style](#propdef-border-bottom-style), and
[border-left-style](#propdef-border-left-style) in a single declaration.

If there is only one component value, it applies to all sides. If there
are two values, the top and bottom are set to the first value and the
right and left are set to the second. If there are three values, the top
is set to the first value, the left and right are set to the second, and
the bottom is set to the third. If there are four values they apply to
the top, right, bottom, and left, respectively.

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

 This specification does not define how borders of
different styles should be joined in the corner. Also note that rounded
corners may cause the corners and the contents to overlap, if the
padding is less than the radius of the corner.

### 3.3. Line Thickness: the [border-width properties]
Name:

[border-top-width],
[border-right-width],
[border-bottom-width],
[border-left-width]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<line-width\>](#typedef-line-width)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

medium

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

all elements except [ruby base
containers](https://drafts.csswg.org/css-ruby-1/#ruby-base-container-box) and [ruby annotation
containers](https://drafts.csswg.org/css-ruby-1/#ruby-annotation-container-box)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

N/A

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

absolute length, [snapped as a border
width](https://drafts.csswg.org/css-values-4/#snap-as-a-line-width)

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value

[Logical property
group:](https://drafts.csswg.org/css-logical-1/#logical-property-group)

[border-width](#propdef-border-width)

Name:

[border-width]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<line-width\>](#typedef-line-width)[{1,4}](https://drafts.csswg.org/css-values-4/#mult-num-range)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

see individual properties

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

all elements except [ruby base
containers](https://drafts.csswg.org/css-ruby-1/#ruby-base-container-box) and [ruby annotation
containers](https://drafts.csswg.org/css-ruby-1/#ruby-annotation-container-box)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

see individual properties

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

see individual properties

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

see individual properties

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

These properties specify the thickness of the
[border](https://drafts.csswg.org/css-box-4/#border), i.e. the [border width]. Where

``` prod
<line-width> = <length [0,∞]> | thin | medium | thick
```

Negative values are invalid. The [thin], [medium], and [thick] keywords are equivalent to [1px],
[3px], and [5px], respectively.

The [border-width](#propdef-border-width) property is a [shorthand
property](https://drafts.csswg.org/css-cascade-5/#shorthand-property) for setting
[border-top-width](#propdef-border-top-width),
[border-right-width](#propdef-border-right-width),
[border-bottom-width](#propdef-border-bottom-width), and
[border-left-width](#propdef-border-left-width) in a single declaration.

If there is only one component value, it applies to all sides. If there
are two values, the top and bottom are set to the first value and the
right and left are set to the second. If there are three values, the top
is set to the first value, the left and right are set to the second, and
the bottom is set to the third. If there are four values they apply to
the top, right, bottom, and left, respectively.

The [resolved
value](https://drafts.csswg.org/cssom-1/#resolved-value) for the
[border-width](#propdef-border-width) properties is the [used
value](https://drafts.csswg.org/css-cascade-5/#used-value).

If the
[border-style](#propdef-border-style) corresponding to a given
[border-width](#propdef-border-width) is
[none](#valdef-line-style-none) or
[hidden](#valdef-line-style-hidden), then the
[used](https://drafts.csswg.org/css-cascade-5/#used-value) width is 0.

 Although the
[initial](https://drafts.csswg.org/css-cascade-5/#initial-value) width is
[medium](#valdef-line-width-medium), the [initial] style is
[none](#valdef-line-style-none); therefore the
[used](https://drafts.csswg.org/css-cascade-5/#used-value) initial width is 0.

### 3.4. Border Shorthand Properties

Name:

[border-top], [border-right],
[border-bottom], [border-left]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<line-width\>](#typedef-line-width)
[\|\|](https://drafts.csswg.org/css-values-4/#comb-any)
[\<line-style\>](#typedef-line-style) [\|\|]
[\<color\>](https://drafts.csswg.org/css-color-5/#typedef-color)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

See individual properties

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

all elements except [ruby base
containers](https://drafts.csswg.org/css-ruby-1/#ruby-base-container-box) and [ruby annotation
containers](https://drafts.csswg.org/css-ruby-1/#ruby-annotation-container-box)

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

These [shorthand
properties](https://drafts.csswg.org/css-cascade-5/#shorthand-property) set the
[border-width](#propdef-border-width),
[border-color](#propdef-border-color), and
[border-style](#propdef-border-style) of the top, right, bottom, and left
[borders](https://drafts.csswg.org/css-box-4/#border) of a box. Omitted values are set to their [initial
values](https://drafts.csswg.org/css-cascade-5/#initial-value).

Name:

[border]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<line-width\>](#typedef-line-width)
[\|\|](https://drafts.csswg.org/css-values-4/#comb-any)
[\<line-style\>](#typedef-line-style) [\|\|]
[\<color\>](https://drafts.csswg.org/css-color-5/#typedef-color)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

See individual properties

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

all elements except [ruby base
containers](https://drafts.csswg.org/css-ruby-1/#ruby-base-container-box) and [ruby annotation
containers](https://drafts.csswg.org/css-ruby-1/#ruby-annotation-container-box)

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
property](https://drafts.csswg.org/css-cascade-5/#shorthand-property) for setting the same
[border-width](#propdef-border-width),
[border-color](#propdef-border-color), and
[border-style](#propdef-border-style) for all four borders of a box.
Unlike the shorthand
[margin](https://drafts.csswg.org/css-box-4/#propdef-margin) and
[padding](https://drafts.csswg.org/css-box-4/#propdef-padding) properties, the
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
[color](https://drafts.csswg.org/css-color-4/#propdef-color) property. The fact that the
[color] property is set after the
[border-left] property is not
relevant.

## 4. Rounded Corners

### 4.1. Curve Radii: the [border-radius properties]
Name:

[border-top-left-radius],
[border-top-right-radius],
[border-bottom-right-radius],
[border-bottom-left-radius]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<length-percentage
\[0,∞\]\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage)[{1,2}](https://drafts.csswg.org/css-values-4/#mult-num-range)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

0

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

all elements (but see prose)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

Refer to corresponding dimension of the [border
box](https://drafts.csswg.org/css-box-4/#border-box).

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

pair of computed
[\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage) values

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value

[Logical property
group:](https://drafts.csswg.org/css-logical-1/#logical-property-group)

[border-radius](#propdef-border-radius)

Name:

[border-radius]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<length-percentage
\[0,∞\]\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage)[{1,4}](https://drafts.csswg.org/css-values-4/#mult-num-range) \[ / [\<length-percentage
\[0,∞\]\>][{1,4}]
\][?](https://drafts.csswg.org/css-values-4/#mult-opt)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

see individual properties

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

all elements (but see prose)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

Refer to corresponding dimension of the [border
box](https://drafts.csswg.org/css-box-4/#border-box).

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

see individual properties

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

see individual properties

Tests

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

The two
[\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage) values of the
[border-\*-radius] properties define the [radii] of a
quarter ellipse that defines the shape of the corner of the outer
[border
edge](https://drafts.csswg.org/css-box-4/#border-edge) (see the diagram below). The first value is the
horizontal radius, the second the vertical radius. If the second value
is omitted it is copied from the first. If either length is zero, the
corner is square, not rounded. Percentages for the horizontal radius
refer to the width of the [border
box](https://drafts.csswg.org/css-box-4/#border-box), whereas percentages for the vertical radius refer to
the height of the [border box]. Negative values
are invalid.

![The two values of [border-top-left-radius: 55pt
25pt](#propdef-border-top-left-radius) define the curvature of the
corner.](images/corner.png){a
height="179" width="289"}

This example draws ovals of 15em wide
and 10em high:

 DIV.standout {
 width: 13em;
 height: 8em;
 border: solid black 1em;
 border-radius: 7.5em 5em }

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

### 4.2. Corner Shaping

The [padding
edge](https://drafts.csswg.org/css-box-4/#padding-edge) (inner border) radius is the outer border radius minus
the corresponding border thickness. In the case where this results in a
negative value, the inner radius is zero. (In such cases the center of
the border's inner curve might not coincide with that of its outer
curve.) Likewise the [content
edge](https://drafts.csswg.org/css-box-4/#content-edge) radius is the [padding edge]
radius minus the corresponding
[padding](https://drafts.csswg.org/css-box-4/#padding), or if that is negative, zero. The border and padding
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
edge](https://drafts.csswg.org/css-box-4/#padding-edge) (in the [border
area](https://drafts.csswg.org/css-box-4/#border-area) of a side opposite the corner), the inner curve will
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
edge](https://drafts.csswg.org/css-box-4/#margin-edge), being outside the [border
edge](https://drafts.csswg.org/css-box-4/#border-edge), calculates its radius by *adding* the corresponding
margin thickness to each border radius, with the corresponding
[outset-adjusted border
radius](#outset-adjusted-border-radius) applied.

Tests

- [background-clip-content-box-with-border-radius-002.html](https://wpt.fyi/results/css/css-backgrounds/background-clip-content-box-with-border-radius-002.html "css/css-backgrounds/background-clip-content-box-with-border-radius-002.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-clip-content-box-with-border-radius-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-clip-content-box-with-border-radius-002.html)
- [background-clip-content-box-with-border-radius-003.html](https://wpt.fyi/results/css/css-backgrounds/background-clip-content-box-with-border-radius-003.html "css/css-backgrounds/background-clip-content-box-with-border-radius-003.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-clip-content-box-with-border-radius-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-clip-content-box-with-border-radius-003.html)
- [background-clip-padding-box-with-border-radius-002.html](https://wpt.fyi/results/css/css-backgrounds/background-clip-padding-box-with-border-radius-002.html "css/css-backgrounds/background-clip-padding-box-with-border-radius-002.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-clip-padding-box-with-border-radius-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-clip-padding-box-with-border-radius-002.html)
- [background-clip-padding-box-with-border-radius-003.html](https://wpt.fyi/results/css/css-backgrounds/background-clip-padding-box-with-border-radius-003.html "css/css-backgrounds/background-clip-padding-box-with-border-radius-003.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/background-clip-padding-box-with-border-radius-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/background-clip-padding-box-with-border-radius-003.html)

When expanding an
[edge](https://drafts.csswg.org/css-box-4/#box-box-edge) that has a [border
radius](#border-radii), e.g. for
computing the [margin
edge](https://drafts.csswg.org/css-box-4/#margin-edge),
[box-shadow](#propdef-box-shadow) spread, or
[overflow-clip-margin](https://drafts.csswg.org/css-overflow-4/#propdef-overflow-clip-margin), the different [border
radius] values are adjusted so that a small
rounded corner with a big outset does not appear to be disproportionally
round.

This is done by computing the corresponding [outset-adjusted border
radius](#outset-adjusted-border-radius).

To compute the [outset-adjusted border
radius] given the 2-dimensional
[size](https://drafts.csswg.org/css-sizing-3/#size)'s `edge`, `radius`, and
`outset`:

1. Let `coverage` be
 `2 * min(``radius``’s `[`width`](https://drafts.csswg.org/css-sizing-3/#width)` / ``edge``’s `[`width`]`, ``radius``’s `[`height`](https://drafts.csswg.org/css-sizing-3/#height)` / ``edge``’s `[`height`]`)`.

2. Let `adustedRadiusWidth` be the [adjusted radius
 dimension](#adjusted-radius-dimension) given `coverage`, `radius`'s
 [width](https://drafts.csswg.org/css-sizing-3/#width), and `outset`'s
 [width].

3. Let `adustedRadiusHeight` be the [adjusted radius
 dimension](#adjusted-radius-dimension) given `coverage`, `radius`'s
 [height](https://drafts.csswg.org/css-sizing-3/#height), and `outset`'s
 [height].

4. Return (`adustedRadiusWidth`,
 `adustedRadiusHeight`).

To compute the [adjusted radius dimension] given numbers
`coverage`, `radius`, and `outset`:

1. If `radius` is greater than `spread`, or if
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

### 4.3. Corner Clipping

Although [border images](#border-image) are not affected by
[border-radius](#propdef-border-radius), other effects that clip painting
or event handling to the
[border](https://drafts.csswg.org/css-box-4/#border-edge),
[padding](https://drafts.csswg.org/css-box-4/#padding-edge), or
[content](https://drafts.csswg.org/css-box-4/#content-edge) edge must clip to their respective curves. For example,
backgrounds clip to the curve specified by
[background-clip](#propdef-background-clip),
[overflow](https://drafts.csswg.org/css2/#propdef-overflow) values other than
[visible](https://drafts.csswg.org/css2/#valdef-overflow-visible) to the curved [padding
edge] (when
[overflow] on both axes is not
[visible]), [replaced
element](https://drafts.csswg.org/css-display-4/#replaced-element) content to the curved [content
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

### 4.4. Color and Style Transitions

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

### 4.5. Overlapping Curves

Corner curves must not overlap: When the sum of any two adjacent border
radii exceeds the size of the border box, UAs must proportionally reduce
the used values of all border radii until none of them overlap. The
algorithm for reducing radii is as follows:

Let `f` =
min(`L`~`i`~/`S`~`i`~),
where `i` ∈ {top, right, bottom, left},
`S`~`i`~ is the sum of the two corresponding radii
of the corners on side `i`, and
`L`~`top`~ = `L`~`bottom`~ =
the width of the box, and `L`~`left`~ =
`L`~`right`~ = the height of the box. If
`f` \< 1, then all corner radii are reduced by multiplying
them by `f`.

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
2em](https://drafts.csswg.org/css-sizing-3/#propdef-width) for A; and ditto but with [height:
2em](https://drafts.csswg.org/css-sizing-3/#propdef-height) for
B.](images/corner-large-mix.png)

### 4.6. Effect on Tables

The
[border-radius](#propdef-border-radius) properties do apply to
[table](https://drafts.csswg.org/css2/#value-def-table),
[inline-table](https://drafts.csswg.org/css2/#value-def-inline-table), and
[table-cell](https://drafts.csswg.org/css2/#value-def-table-cell) boxes in separated borders mode
([border-collapse:
separate](https://drafts.csswg.org/css2/#propdef-border-collapse)). When
[border-collapse] is
[collapse](https://drafts.csswg.org/css2/#valdef-border-collapse-collapse), they have no effect.

Tests

- [table-cell-background-local-002.html](https://wpt.fyi/results/css/css-backgrounds/table-cell-background-local-002.html "css/css-backgrounds/table-cell-background-local-002.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/table-cell-background-local-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/table-cell-background-local-002.html)
- [table-cell-background-local-003.html](https://wpt.fyi/results/css/css-backgrounds/table-cell-background-local-003.html "css/css-backgrounds/table-cell-background-local-003.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/table-cell-background-local-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/table-cell-background-local-003.html)
- [table-cell-background-local.html](https://wpt.fyi/results/css/css-backgrounds/table-cell-background-local.html "css/css-backgrounds/table-cell-background-local.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/table-cell-background-local.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/table-cell-background-local.html)
- [ttwf-reftest-borderRadius.html](https://wpt.fyi/results/css/css-backgrounds/ttwf-reftest-borderRadius.html "css/css-backgrounds/ttwf-reftest-borderRadius.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/ttwf-reftest-borderRadius.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/ttwf-reftest-borderRadius.html)

## 5. Border Images

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
box](https://drafts.csswg.org/css-box-4/#border-box) and into the [margin
area](https://drafts.csswg.org/css-box-4/#margin-area). If the border-image fails to load (or if border images
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

- [border-image-021.html](https://wpt.fyi/results/css/css-backgrounds/border-image-021.html "css/css-backgrounds/border-image-021.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-image-021.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-image-021.html)
- [border-image-outset-004.html](https://wpt.fyi/results/css/css-backgrounds/border-image-outset-004.html "css/css-backgrounds/border-image-outset-004.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/border-image-outset-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/border-image-outset-004.html)

### 5.1. Image Source: the [border-image-source property]
Name:

[border-image-source]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

none
[\|](https://drafts.csswg.org/css-values-4/#comb-one)
[\<image\>](https://drafts.csswg.org/css-images-3/#typedef-image)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

none

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

All elements, except internal table elements when
[border-collapse](https://drafts.csswg.org/css2/#propdef-border-collapse) is
[collapse](https://drafts.csswg.org/css2/#valdef-border-collapse-collapse)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

N/A

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

the keyword [none] or the computed
[\<image\>](https://drafts.csswg.org/css-images-3/#typedef-image)

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

### 5.2. Image Slicing: the [border-image-slice property]
Name:

[border-image-slice]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

\[[\<number
\[0,∞\]\>](https://drafts.csswg.org/css-values-4/#number-value)
[\|](https://drafts.csswg.org/css-values-4/#comb-one) [\<percentage
\[0,∞\]\>](https://drafts.csswg.org/css-values-4/#percentage-value)\][{1,4}](https://drafts.csswg.org/css-values-4/#mult-num-range)
[&&](https://drafts.csswg.org/css-values-4/#comb-all)
fill[?](https://drafts.csswg.org/css-values-4/#mult-opt)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

100%

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

All elements, except internal table elements when
[border-collapse](https://drafts.csswg.org/css2/#propdef-border-collapse) is
[collapse](https://drafts.csswg.org/css2/#valdef-border-collapse-collapse)

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

[[\<percentage \[0,∞\]\>](https://drafts.csswg.org/css-values-4/#percentage-value)]
: Percentages are relative to the size of the image: the width of the
 image for the horizontal offsets, the height for vertical offsets.

[[\<number \[0,∞\]\>](https://drafts.csswg.org/css-values-4/#number-value)]
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
dimensions](https://drafts.csswg.org/css-images-3/#natural-dimensions)), then it is sized using the [default sizing
algorithm](https://www.w3.org/TR/css3-images/#default-sizing) with no
[specified
size](https://drafts.csswg.org/css-images-3/#specified-size) and the [border image
area](#border-image-area)
as the [default object
size](https://drafts.csswg.org/css-images-3/#default-object-size).

![Diagram illustrating the cuts corresponding to the value [25% 30% 12%
20%]](images/slice.png){a
height="304" width="388"}

### 5.3. Drawing Areas: the [border-image-width property]
Name:

[border-image-width]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

\[ [\<length-percentage
\[0,∞\]\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage)
[\|](https://drafts.csswg.org/css-values-4/#comb-one) [\<number
\[0,∞\]\>](https://drafts.csswg.org/css-values-4/#number-value) [\|] auto
\][{1,4}](https://drafts.csswg.org/css-values-4/#mult-num-range)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

1

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

All elements, except internal table elements when
[border-collapse](https://drafts.csswg.org/css2/#propdef-border-collapse) is
[collapse](https://drafts.csswg.org/css2/#valdef-border-collapse-collapse)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

Relative to width/height of the [border image
area](#border-image-area)

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

four values, each either a number, the keyword
[auto](#valdef-border-image-width-auto), or a computed
[\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage) value

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
box](https://drafts.csswg.org/css-box-4/#border-box), see
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

[[\<length-percentage \[0,∞\]\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage)]
: Percentages refer to the size of the [border image
 area](#border-image-area): the width of the area for horizontal offsets, the
 height for vertical offsets.

[[\<number \[0,∞\]\>](https://drafts.csswg.org/css-values-4/#number-value)]
: Numbers represent multiples of the corresponding computed
 [border-width](#border-width).

[auto]
: If
 [auto](#valdef-border-image-width-auto) is specified then the used
 [border-image-width](#propdef-border-image-width) is the
 [natural](https://drafts.csswg.org/css-images-3/#natural-size) width or height (whichever is applicable) of the
 corresponding image slice (see
 [border-image-slice](#propdef-border-image-slice)). If the image does not have
 the required [natural
 dimension](https://drafts.csswg.org/css-images-3/#natural-dimensions) then the corresponding computed
 [border-width](#propdef-border-width) is used instead.

Negative values are invalid for any
[border-image-width](#propdef-border-image-width) values.

If two opposite
[border-image-width](#propdef-border-image-width) offsets are large enough that they
overlap, then the [used
values](https://drafts.csswg.org/css-cascade-5/#used-value) of all
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

### 5.4. Edge Overhang: the [border-image-outset property]
Name:

[border-image-outset]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

\[ [\<length
\[0,∞\]\>](https://drafts.csswg.org/css-values-4/#length-value)
[\|](https://drafts.csswg.org/css-values-4/#comb-one) [\<number
\[0,∞\]\>](https://drafts.csswg.org/css-values-4/#number-value)
\][{1,4}](https://drafts.csswg.org/css-values-4/#mult-num-range)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

0

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

All elements, except internal table elements when
[border-collapse](https://drafts.csswg.org/css2/#propdef-border-collapse) is
[collapse](https://drafts.csswg.org/css2/#valdef-border-collapse-collapse)

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
box](https://drafts.csswg.org/css-box-4/#border-box).

If there is only one component value, it applies to all sides. If there
are two values, the top and bottom are set to the first value and the
right and left are set to the second. If there are three values, the top
is set to the first value, the left and right are set to the second, and
the bottom is set to the third. If there are four values they apply to
the top, right, bottom, and left, respectively.

[\<length \[0,∞\]\>](https://drafts.csswg.org/css-values-4/#length-value)
: Represents an outset of the specified length.

[\<number \[0,∞\]\>](https://drafts.csswg.org/css-values-4/#number-value)
: Represents an outset of the specified multiple of the corresponding
 computed [border-width](#border-width).

Negative values are invalid.

Portions of the border-image that are rendered outside the [border
box](https://drafts.csswg.org/css-box-4/#border-box) are [ink
overflow](https://drafts.csswg.org/css-overflow-3/#ink-overflow) and do not trigger scrolling. Also such portions are
invisible to mouse events and do not capture such events on behalf of
the element.

 Even though they never cause a scrolling mechanism,
outset images may still be clipped by an ancestor or by the viewport.

### 5.5. Image Tiling: the [border-image-repeat property]
Name:

[border-image-repeat]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

\[ stretch
[\|](https://drafts.csswg.org/css-values-4/#comb-one) repeat [\|] round
[\|] space
\][{1,2}](https://drafts.csswg.org/css-values-4/#mult-num-range)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

stretch

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

All elements, except internal table elements when
[border-collapse](https://drafts.csswg.org/css2/#propdef-border-collapse) is
[collapse](https://drafts.csswg.org/css2/#valdef-border-collapse-collapse)

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

### 5.6. Drawing the Border Image

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
 [round](#valdef-background-repeat-round) in the
 [background-repeat](#propdef-background-repeat) property.
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

### 5.7. Border Image Shorthand: the [border-image property]
Name:

[border-image]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<\'border-image-source\'\>](#propdef-border-image-source)
[\|\|](https://drafts.csswg.org/css-values-4/#comb-any)
[\<\'border-image-slice\'\>](#propdef-border-image-slice) \[ /
[\<\'border-image-width\'\>](#propdef-border-image-width)
[\|](https://drafts.csswg.org/css-values-4/#comb-one) /
[\<\'border-image-width\'\>][?](https://drafts.csswg.org/css-values-4/#mult-opt) /
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
values](https://drafts.csswg.org/css-cascade-5/#initial-value).

### 5.8. Effect on Tables

The [border-image](#propdef-border-image) properties apply to the border of
tables and inline tables that have
[border-collapse](https://drafts.csswg.org/css2/#propdef-border-collapse) set to
[collapse](https://drafts.csswg.org/css2/#valdef-border-collapse-collapse). However, this specification does not define how
such an image border is rendered. In particular, it does not define how
the image border interacts with the borders of cells, rows and row
groups at the edges of the table (see [border conflict
resolution](https://www.w3.org/TR/2011/REC-CSS2-20110607/tables.html#border-conflict-resolution)
in
[\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")).

It is expected that a future specification will define the rendering. It
is recommended that UAs do not apply border images to tables with
collapsed borders until then.

## 6. Miscellaneous Effects

 The
[box-decoration-break](https://drafts.csswg.org/css-break-4/#propdef-box-decoration-break) property, which defines how
backgrounds and borders apply to a fragmented box, has been moved to the
[CSS Fragmentation Module](https://www.w3.org/TR/css-break/).
[\[CSS-BREAK-3\]](#biblio-css-break-3 "CSS Fragmentation Module Level 3")

### 6.1. Drop Shadows: the [box-shadow property]
Name:

[box-shadow]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

none
[\|](https://drafts.csswg.org/css-values-4/#comb-one)
[\<shadow\>](#typedef-shadow)[\#](https://drafts.csswg.org/css-values-4/#mult-comma)

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

either the keyword [none](#box-shadow-none) or a list, each item consisting of four absolute
lengths plus a computed color and optionally also a
[inset](#shadow-inset)
keyword

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value, treating
[none](#box-shadow-none) as a zero-item list and appending blank shadows
([transparent 0 0 0 0]) with a corresponding
[inset](#shadow-inset)
keyword as needed to match the longer list if the shorter list is
otherwise compatible with the longer one

Tests

- [box-shadow-composition.html](https://wpt.fyi/results/css/css-backgrounds/animations/box-shadow-composition.html "css/css-backgrounds/animations/box-shadow-composition.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/animations/box-shadow-composition.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/animations/box-shadow-composition.html)
- [box-shadow-interpolation.html](https://wpt.fyi/results/css/css-backgrounds/animations/box-shadow-interpolation.html "css/css-backgrounds/animations/box-shadow-interpolation.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/animations/box-shadow-interpolation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/animations/box-shadow-interpolation.html)
- [box-shadow-005.html](https://wpt.fyi/results/css/css-backgrounds/box-shadow-005.html "css/css-backgrounds/box-shadow-005.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/box-shadow-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/box-shadow-005.html)
- [box-shadow-029.html](https://wpt.fyi/results/css/css-backgrounds/box-shadow-029.html "css/css-backgrounds/box-shadow-029.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/box-shadow-029.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/box-shadow-029.html)
- [box-shadow-039.html](https://wpt.fyi/results/css/css-backgrounds/box-shadow-039.html "css/css-backgrounds/box-shadow-039.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/box-shadow-039.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/box-shadow-039.html)
- [box-shadow-040.html](https://wpt.fyi/results/css/css-backgrounds/box-shadow-040.html "css/css-backgrounds/box-shadow-040.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/box-shadow-040.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/box-shadow-040.html)
- [box-shadow-041.html](https://wpt.fyi/results/css/css-backgrounds/box-shadow-041.html "css/css-backgrounds/box-shadow-041.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/box-shadow-041.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/box-shadow-041.html)
- [box-shadow-042.html](https://wpt.fyi/results/css/css-backgrounds/box-shadow-042.html "css/css-backgrounds/box-shadow-042.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/box-shadow-042.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/box-shadow-042.html)
- [box-shadow-body.html](https://wpt.fyi/results/css/css-backgrounds/box-shadow-body.html "css/css-backgrounds/box-shadow-body.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/box-shadow-body.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/box-shadow-body.html)
- [box-shadow-border-radius-001.html](https://wpt.fyi/results/css/css-backgrounds/box-shadow-border-radius-001.html "css/css-backgrounds/box-shadow-border-radius-001.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/box-shadow-border-radius-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/box-shadow-border-radius-001.html)
- [box-shadow-calc.html](https://wpt.fyi/results/css/css-backgrounds/box-shadow-calc.html "css/css-backgrounds/box-shadow-calc.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/box-shadow-calc.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/box-shadow-calc.html)
- [box-shadow-currentcolor.html](https://wpt.fyi/results/css/css-backgrounds/box-shadow-currentcolor.html "css/css-backgrounds/box-shadow-currentcolor.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/box-shadow-currentcolor.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/box-shadow-currentcolor.html)
- [box-shadow-inset-without-border-radius.html](https://wpt.fyi/results/css/css-backgrounds/box-shadow-inset-without-border-radius.html "css/css-backgrounds/box-shadow-inset-without-border-radius.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/box-shadow-inset-without-border-radius.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/box-shadow-inset-without-border-radius.html)
- [box-shadow-invalid-001.html](https://wpt.fyi/results/css/css-backgrounds/box-shadow-invalid-001.html "css/css-backgrounds/box-shadow-invalid-001.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/box-shadow-invalid-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/box-shadow-invalid-001.html)
- [box-shadow-multiple-001.html](https://wpt.fyi/results/css/css-backgrounds/box-shadow-multiple-001.html "css/css-backgrounds/box-shadow-multiple-001.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/box-shadow-multiple-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/box-shadow-multiple-001.html)
- [box-shadow-outset-without-border-radius-001.html](https://wpt.fyi/results/css/css-backgrounds/box-shadow-outset-without-border-radius-001.html "css/css-backgrounds/box-shadow-outset-without-border-radius-001.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/box-shadow-outset-without-border-radius-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/box-shadow-outset-without-border-radius-001.html)
- [box-shadow-overlapping-001.html](https://wpt.fyi/results/css/css-backgrounds/box-shadow-overlapping-001.html "css/css-backgrounds/box-shadow-overlapping-001.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/box-shadow-overlapping-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/box-shadow-overlapping-001.html)
- [box-shadow-overlapping-002.html](https://wpt.fyi/results/css/css-backgrounds/box-shadow-overlapping-002.html "css/css-backgrounds/box-shadow-overlapping-002.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/box-shadow-overlapping-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/box-shadow-overlapping-002.html)
- [box-shadow-overlapping-003.html](https://wpt.fyi/results/css/css-backgrounds/box-shadow-overlapping-003.html "css/css-backgrounds/box-shadow-overlapping-003.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/box-shadow-overlapping-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/box-shadow-overlapping-003.html)
- [box-shadow-overlapping-004.html](https://wpt.fyi/results/css/css-backgrounds/box-shadow-overlapping-004.html "css/css-backgrounds/box-shadow-overlapping-004.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/box-shadow-overlapping-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/box-shadow-overlapping-004.html)
- [box-shadow-radius-000.html](https://wpt.fyi/results/css/css-backgrounds/box-shadow-radius-000.html "css/css-backgrounds/box-shadow-radius-000.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/box-shadow-radius-000.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/box-shadow-radius-000.html)
- [box-shadow-radius-001.html](https://wpt.fyi/results/css/css-backgrounds/box-shadow-radius-001.html "css/css-backgrounds/box-shadow-radius-001.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/box-shadow-radius-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/box-shadow-radius-001.html)
- [box-shadow-table-border-collapse-001.html](https://wpt.fyi/results/css/css-backgrounds/box-shadow-table-border-collapse-001.html "css/css-backgrounds/box-shadow-table-border-collapse-001.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/box-shadow-table-border-collapse-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/box-shadow-table-border-collapse-001.html)
- [slice-block-fragmentation-001.html](https://wpt.fyi/results/css/css-backgrounds/box-shadow/slice-block-fragmentation-001.html "css/css-backgrounds/box-shadow/slice-block-fragmentation-001.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/box-shadow/slice-block-fragmentation-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/box-shadow/slice-block-fragmentation-001.html)
- [slice-block-fragmentation-002.html](https://wpt.fyi/results/css/css-backgrounds/box-shadow/slice-block-fragmentation-002.html "css/css-backgrounds/box-shadow/slice-block-fragmentation-002.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/box-shadow/slice-block-fragmentation-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/box-shadow/slice-block-fragmentation-002.html)
- [slice-block-fragmentation-003.html](https://wpt.fyi/results/css/css-backgrounds/box-shadow/slice-block-fragmentation-003.html "css/css-backgrounds/box-shadow/slice-block-fragmentation-003.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/box-shadow/slice-block-fragmentation-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/box-shadow/slice-block-fragmentation-003.html)
- [slice-inline-fragmentation-001.html](https://wpt.fyi/results/css/css-backgrounds/box-shadow/slice-inline-fragmentation-001.html "css/css-backgrounds/box-shadow/slice-inline-fragmentation-001.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/box-shadow/slice-inline-fragmentation-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/box-shadow/slice-inline-fragmentation-001.html)
- [slice-inline-fragmentation-002.html](https://wpt.fyi/results/css/css-backgrounds/box-shadow/slice-inline-fragmentation-002.html "css/css-backgrounds/box-shadow/slice-inline-fragmentation-002.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/box-shadow/slice-inline-fragmentation-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/box-shadow/slice-inline-fragmentation-002.html)
- [slice-inline-fragmentation-003.html](https://wpt.fyi/results/css/css-backgrounds/box-shadow/slice-inline-fragmentation-003.html "css/css-backgrounds/box-shadow/slice-inline-fragmentation-003.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/box-shadow/slice-inline-fragmentation-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/box-shadow/slice-inline-fragmentation-003.html)
- [css-box-shadow-001.html](https://wpt.fyi/results/css/css-backgrounds/css-box-shadow-001.html "css/css-backgrounds/css-box-shadow-001.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/css-box-shadow-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/css-box-shadow-001.html)
- [css3-box-shadow.html](https://wpt.fyi/results/css/css-backgrounds/css3-box-shadow.html "css/css-backgrounds/css3-box-shadow.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/css3-box-shadow.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/css3-box-shadow.html)
- [fieldset-inset-shadow.html](https://wpt.fyi/results/css/css-backgrounds/fieldset-inset-shadow.html "css/css-backgrounds/fieldset-inset-shadow.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/fieldset-inset-shadow.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/fieldset-inset-shadow.html)
- [inset-box-shadow-scroll.html](https://wpt.fyi/results/css/css-backgrounds/inset-box-shadow-scroll.html "css/css-backgrounds/inset-box-shadow-scroll.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/inset-box-shadow-scroll.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/inset-box-shadow-scroll.html)
- [inset-box-shadow-stacking-context-scroll.html](https://wpt.fyi/results/css/css-backgrounds/inset-box-shadow-stacking-context-scroll.html "css/css-backgrounds/inset-box-shadow-stacking-context-scroll.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/inset-box-shadow-stacking-context-scroll.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/inset-box-shadow-stacking-context-scroll.html)
- [inheritance.sub.html](https://wpt.fyi/results/css/css-backgrounds/inheritance.sub.html "css/css-backgrounds/inheritance.sub.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/inheritance.sub.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/inheritance.sub.html)
- [box-shadow-computed.html](https://wpt.fyi/results/css/css-backgrounds/parsing/box-shadow-computed.html "css/css-backgrounds/parsing/box-shadow-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/parsing/box-shadow-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/parsing/box-shadow-computed.html)
- [box-shadow-invalid.html](https://wpt.fyi/results/css/css-backgrounds/parsing/box-shadow-invalid.html "css/css-backgrounds/parsing/box-shadow-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/parsing/box-shadow-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/parsing/box-shadow-invalid.html)
- [box-shadow-valid.html](https://wpt.fyi/results/css/css-backgrounds/parsing/box-shadow-valid.html "css/css-backgrounds/parsing/box-shadow-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/parsing/box-shadow-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/parsing/box-shadow-valid.html)

The [box-shadow](#propdef-box-shadow) property attaches one or more drop
shadows to the box. The property accepts either the
[none] value, which indicates no shadows, or a
comma-separated list of shadows, ordered front to back.

Each shadow is given as a
[\<shadow\>](#typedef-shadow), represented by 2-4 length values, an optional color,
and an optional [inset](#shadow-inset) keyword. Omitted lengths are 0; omitted colors
default to
[currentColor](https://drafts.csswg.org/css-color-4/#valdef-color-currentcolor).

``` prod
<shadow> = <color>? && [ <length>{2} [ <length [0,∞]> <length>? ]? ] && inset?
```

The components of each
[\<shadow\>](#typedef-shadow) are interpreted as follows:

[1st [\<length\>](https://drafts.csswg.org/css-values-4/#length-value)]
: Specifies the [horizontal offset] of the
 shadow. A positive value draws a shadow that is offset to the right
 of the box, a negative length to the left.

[2nd [\<length\>](https://drafts.csswg.org/css-values-4/#length-value)]
: Specifies the [vertical offset] of the
 shadow. A positive value offsets the shadow down, a negative one up.

[3rd [\<length \[0,∞\]\>](https://drafts.csswg.org/css-values-4/#length-value)]
: Specifies the [blur radius].
 Negative values are invalid. If the blur value is zero, the shadow's
 edge is sharp. Otherwise, the larger the value, the more the
 shadow's edge is blurred. See [Shadow Blurring](#shadow-blur),
 below.

[4th [\<length\>](https://drafts.csswg.org/css-values-4/#length-value)]

: Specifies the [spread distance].
 Positive values cause the shadow to expand in all directions by the
 specified radius. Negative values cause the shadow to contract. See
 [Shadow Shape](#shadow-shape), below.

 Note that for inner shadows, expanding the shadow (creating more
 shadow area) means contracting the shadow's perimeter shape.

[[\<color\>](https://drafts.csswg.org/css-color-5/#typedef-color)]
: Specifies the color of the shadow. If the color is absent, it
 defaults to
 [currentColor](https://drafts.csswg.org/css-color-4/#valdef-color-currentcolor).

[inset]
: If present, the [inset](#shadow-inset) keyword changes the drop shadow from an [outer
 box-shadow] (one that shadows the box onto the canvas,
 as if it were lifted above the canvas) to an [inner
 box-shadow] (one that shadows the canvas onto the box,
 as if the box were cut out of the canvas and shifted behind it).

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

#### 6.1.1. Shadow Shape, Spread, and Knockout

An [outer
box-shadow](#box-shadow-outer-box-shadow) casts a shadow as if the border-box of the element were
opaque. Assuming a spread distance of zero, its perimeter has the exact
same size and shape as the border box. The shadow is drawn outside the
border edge only: it is clipped inside the border-box of the element.

An [inner
box-shadow](#box-shadow-inner-box-shadow) casts a shadow as if everything outside the padding
edge were opaque. Assuming a spread distance of zero, its perimeter has
the exact same size and shape as the padding box. The shadow is drawn
inside the padding edge only: it is clipped outside the padding box of
the element.

If a [spread
distance](#box-shadow-spread-distance) is defined, the shadow perimeter defined above is
expanded outward (for [outer
box-shadows](#box-shadow-outer-box-shadow)) or contracted inward (for [inner
box-shadows](#box-shadow-inner-box-shadow)) by outsetting (insetting, for inner shadows) the
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
distance](#box-shadow-spread-distance) (and flooring at zero). For outer shadows, the [border
radius](#border-radii) is then
[adjusted](#outset-adjusted-border-radius), independently in each dimension, to preserve the
sharpness of rounded corners.

The [border-image](#propdef-border-image) does not affect the shape of the
box-shadow.

Tests

- [box-shadow-radius-generated.html](https://wpt.fyi/results/css/css-backgrounds/box-shadow-radius-generated.html "css/css-backgrounds/box-shadow-radius-generated.html")
 [[(live
 test)]](http://wpt.live/css/css-backgrounds/box-shadow-radius-generated.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-backgrounds/box-shadow-radius-generated.html)

#### 6.1.2. Blurring Shadow Edges

A non-zero [blur
radius](#box-shadow-blur-radius) indicates that the resulting shadow should be blurred,
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

#### 6.1.3. Layering, Layout, and Other Details

The shadow effects are applied front-to-back: the first shadow is on top
and the others are layered behind. Shadows do not influence layout and
may overlap (or be overlapped by) other boxes and text or their shadows.
In terms of stacking contexts and the painting order, the [outer
box-shadows](#box-shadow-outer-box-shadow) of an element are drawn immediately below the
background of that element, and the [inner
shadows](#box-shadow-inner-box-shadow) of an element are drawn immediately above the
background of that element (below the borders and border image, if any).

Unless otherwise specified, drop shadows are only applied to the
[principal
box](https://drafts.csswg.org/css-display-4/#principal-box). If the affected box has multiple fragments, the
shadows are applied as specified in
[box-decoration-break](https://drafts.csswg.org/css-break-4/#propdef-box-decoration-break).

Shadows are [ink
overflow](https://drafts.csswg.org/css-overflow-3/#ink-overflow); they do not trigger scrolling or increase the size of
the [scrollable overflow
area](https://drafts.csswg.org/css-overflow-3/#scrollable-overflow-region).

Outer shadows have no effect on internal table elements in the
collapsing border model. If a shadow is defined for single border edge
in the collapsing border model that has multiple border thicknesses
(e.g. an outer shadow on a table where one row has thicker borders than
the others, or an inner shadow on a rowspanning table cell that adjoins
cells with different border thicknesses), the exact position and
rendering of its shadows are undefined

## 7. Levels

*This section is informative.* CSS has different levels of features,
each a subset of the other. (See
[\[CSS-2017\]](#biblio-css-2017 "CSS Snapshot 2017")
for a full explanation.) The lists below describe which features from
this specification are in each level.

### 7.1. Level 1

- [background-color](#propdef-background-color)
- [background-image](#propdef-background-image) only one image (no layers)
- [background-repeat](#propdef-background-repeat): only
 [repeat](#valdef-background-repeat-repeat) \|
 [repeat-x](#valdef-background-repeat-repeat-x) \|
 [repeat-y](#valdef-background-repeat-repeat-y) \|
 [no-repeat](#valdef-background-repeat-no-repeat)
- [background-attachment](#propdef-background-attachment): only
 [scroll](#valdef-background-attachment-scroll) \|
 [fixed](#valdef-background-attachment-fixed)
- [background-position](#propdef-background-position): only one or two values allowed
- [background](#propdef-background) shorthand: only color, image, repeat,
 attachment and position
- [border-color](#propdef-border-color) properties
- [border-style](#propdef-border-style) properties
- [border-width](#propdef-border-width) properties
- [border-top](#propdef-border-top),
 [border-bottom](#propdef-border-bottom),
 [border-right](#propdef-border-right),
 [border-left](#propdef-border-left), and
 [border](#propdef-border) shorthands

### 7.2. Level 2

- [background-color](#propdef-background-color)
- [background-image](#propdef-background-image): only one image (no layers)
- [background-repeat](#propdef-background-repeat): only
 [repeat](#valdef-background-repeat-repeat) \|
 [repeat-x](#valdef-background-repeat-repeat-x) \|
 [repeat-y](#valdef-background-repeat-repeat-y) \|
 [no-repeat](#valdef-background-repeat-no-repeat)
- [background-attachment](#propdef-background-attachment): only
 [scroll](#valdef-background-attachment-scroll) \|
 [fixed](#valdef-background-attachment-fixed)
- [background-position](#propdef-background-position): only one or two values allowed
- [background](#propdef-background): only color, image, repeat, attachment
 and position
- [border-color](#propdef-border-color) properties
- [border-style](#propdef-border-style) properties
- [border-width](#propdef-border-width) properties
- [border-top](#propdef-border-top),
 [border-bottom](#propdef-border-bottom),
 [border-right](#propdef-border-right),
 [border-left](#propdef-border-left), and
 [border](#propdef-border) shorthands

### 7.3. Level 3

- All features described in the CSS Backgrounds and Borders Module Level
 3

## 8. Changes

### 8.1. Changes since the 11 March 2024 Candidate Recommendation Draft

- Changed the special case of
 [border-width](#propdef-border-width) having a value of [0] when
 [border-style](#propdef-border-style) is
 [none](#valdef-line-style-none) or
 [hidden](#valdef-line-style-hidden) from a computed-value effect to a
 resolved-value effect. ([Issue
 11494](https://github.com/w3c/csswg-drafts/issues/11494))
- Altered the border-radius outset adjustment, so the radius reduction
 factor in the minimum radius percentage of the corner, makes it less
 pronounced the closer the corner's border-radius gets to 50%. ([Issue
 7103](https://github.com/w3c/csswg-drafts/issues/7103))
- Fixed syntax of
 [box-shadow](#propdef-box-shadow) to avoid allowing negative blur radii,
 aligning it with the prose.
- Cross linked to \'ink overflow\' terminology

### 8.2. Changes since the 14 February 2023 Candidate Recommendation Snapshot

- Defined serialization of
 [background-position](#propdef-background-position) in [§ 2.6.1 Serialization of
 background-position values](#bg-position-serialization). ([Issue
 2274](https://github.com/w3c/csswg-drafts/issues/2274))
- Reverted [change moving \<color\> to the front of
 \<final-bg-layer\>](#bg-color-move) in the
 [background](#propdef-background) shorthand. ([Issue
 8496](https://github.com/w3c/csswg-drafts/issues/8496))
- Specified [rounding of border
 widths](https://drafts.csswg.org/css-values-4/#snap-as-a-line-width) to device pixels. ([Issue
 7434](https://github.com/w3c/csswg-drafts/issues/7434))
- Specified interaction of
 [border-radius](#propdef-border-radius) and per-axis
 [overflow](https://drafts.csswg.org/css2/#propdef-overflow) longhands. ([Issue
 5210](https://github.com/w3c/csswg-drafts/issues/5210))
- Fixed an error in the Computed Value line of
 [background-image](#propdef-background-image). ([Issue
 8604](https://github.com/w3c/csswg-drafts/issues/8604))
- Removed the \<box\> definition (replacing it with a
 [\<visual-box\>](https://drafts.csswg.org/css-box-4/#typedef-visual-box) reference), as the Box Module now
 defines these terms.
- Aligned property definition tables with the latest expectations to
 include "Animation Type" and "Logical Property Group".
- Streamlined property grammar definitions using the latest [value
 definition
 syntax](https://drafts.csswg.org/css-values-4/#css-value-definition-syntax).
- Fixed the definition for where box shadows apply. ([Issue
 9286](https://github.com/w3c/csswg-drafts/issues/9286))
- Defined serialization of
 [background-size](#propdef-background-size) in [§ 2.9.1 Serialization of
 background-size values](#bg-size-serialization). ([Issue
 7802](https://github.com/w3c/csswg-drafts/issues/7802))

### 8.3. Changes since the 22 December 2020 Candidate Recommendation Snapshot

- Clarified that the rule about not propagating backgrounds from the
 root when it doesn't generate boxes only applies to [display:
 none](https://drafts.csswg.org/css2/#propdef-display), not [display:
 contents]. ([Issue
 3779](https://github.com/w3c/csswg-drafts/issues/3779))
- Precisely defined the size of
 [border-width](#propdef-border-width)
 [thin](#valdef-line-width-thin),
 [medium](#valdef-line-width-medium), and
 [thick](#valdef-line-width-thick). ([Issue
 7254](https://github.com/w3c/csswg-drafts/issues/7254))
- Minor editorial improvements.

### 8.4. Changes since the 17 October 2017 Candidate Recommendation

- Inverted order of
 [\<shadow\>](#typedef-shadow) grammar to match browser serialization
 and
 [text-shadow](https://drafts.csswg.org/css-text-decor-4/#propdef-text-shadow)/[drop-shadow()](https://drafts.csswg.org/filter-effects-1/#funcdef-filter-drop-shadow). ([Issue
 2305](https://github.com/w3c/csswg-drafts/issues/2305))

 > <shadow> = inset<color>? && <length>{2,4} && <color>inset?

- Spread radius adjustment is only applied to shadows and margins where
 the radius of curvature grows, rather than shrinks. ([Issue
 1900](https://github.com/w3c/csswg-drafts/issues/1900))

 > To preserve the box's shape when spread is applied, the corner radii
 > of the shadow are also increased (decreased, for inner shadows) from
 > the border-box radii by adding (subtracting) the [spread
 > distance](#box-shadow-spread-distance) (and flooring at zero). However, in order to create
 > a sharper corner when the border radius is small [(and thus ensure
 > continuity between round and sharp corners)] , when the
 > [border radius](#border-radii) is less than the [spread
 > distance] [(or in the case of
 > an inner shadow, less than the absolute value of a negative [spread
 > distance](#box-shadow-spread-distance))] , the [spread
 > distance] is multiplied by the
 > proportion 1 + (`r`-1)^3^, where `r` is the
 > ratio of the border radius to the [spread
 > distance], in calculating the
 > corner radii of the spread shadow shape.

- Clarified that an omitted
 [\<color\>](https://drafts.csswg.org/css-color-5/#typedef-color) in a
 [\<shadow\>](#typedef-shadow) defaults to
 [currentColor](https://drafts.csswg.org/css-color-4/#valdef-color-currentcolor), not some mysterious unnamed value with the
 same behavior.
 ([2766](https://github.com/w3c/csswg-drafts/issues/2766))

 > If the color is absent, [it defaults to
 > [currentColor](https://drafts.csswg.org/css-color-4/#valdef-color-currentcolor)] ~~the used color is taken from
 > the
 > [color](https://drafts.csswg.org/css-color-4/#propdef-color) property.~~

- Cleaned up and regularized "Animation type" and "Computed value" lines
 in the property definition tables.

- Changed syntax to use the new [CSS bracketed range
 notation](https://drafts.csswg.org/css-values-4/#css-bracketed-range-notation) to reflect the prose restrictions on negative values,
 and corrected a few grammar definition errors introduced in the
 previous publication.

- Minor editorial improvements.

### 8.5. Changes since the 9 September 2014 Candidate Recommendation

The following (non-trivial) changes were made to this specification
since the [9 September 2014 Candidate
Recommendation](https://www.w3.org/TR/2014/CR-css3-background-20140909/):

- Added missing definition of [box-shadow:
 none](#propdef-box-shadow). (Apparently this was obvious enough that nobody
 noticed it was missing until now.)
- [(#bg-color-move)Moved
 [\<\'background-color\'\>](#propdef-background-color) component of
 [\<final-bg-layer\>](#typedef-final-bg-layer) to the front for serialization
 because some authors seem to expect this even though it makes less
 sense?]
- Dropped effect of
 [border-radius](#propdef-border-radius) from collapsed-borders tables.
- Renamed
 [\<position\>](https://drafts.csswg.org/css-values-3/#typedef-position) back to
 [\<bg-position\>](#typedef-bg-position) since other properties will be
 eliding the three-value syntax.

### 8.6. Changes since the 4 February 2014 Last Call Working Draft

The following (non-trivial) changes were made to this specification
since the [4 February 2014 Last Call Working
Draft](https://www.w3.org/TR/2014/WD-css3-background-20140204/):

- Fixed spread radius and margin radius calculations to only apply
 adjustment factor when spread/margin is larger than border radius.
- Defined handling of canvas background when root element has [display:
 none](https://drafts.csswg.org/css2/#propdef-display).

A full [Disposition of
Comments](https://drafts.csswg.org/css-backgrounds-3/issues-lc-2014) is
available.

### 8.7. Changes since the 24 July 2012 Candidate Recommendation

The following (non-trivial) changes were made to this specification
since the [24 July 2012 Candidate
Recommendation](https://www.w3.org/TR/2012/CR-css3-background-20120724/):

- Allow
 [\<\'background-clip\'\>](#propdef-background-clip) and
 [\<\'background-origin\'\>](#propdef-background-origin) to be separated by other
 component values in the
 [background](#propdef-background) shorthand, since this is what is
 implemented.
- Allow
 [\<color\>](https://drafts.csswg.org/css-color-5/#typedef-color) and
 [inset](#shadow-inset)
 to be interleaved in any order in
 [box-shadow](#propdef-box-shadow), since they are not ambiguous and CSS
 generally allows variant ordering where not ambiguous.
- Define gradually increasing corner radius formula for
 [box-shadow](#propdef-box-shadow) spread curvature to create continuity
 between sharp corners
 ([border-radius](#propdef-border-radius) = 0) and curved corners
 ([border-radius] \>
 `spread distance`). This also gives better results for all
 intermediate states.
- Add definition for how the margin edge is curved in response to
 border-radius. (This is relevant for
 [\[CSS-SHAPES\]](#biblio-css-shapes "CSS Shapes Module Level 1"),
 but does not change conformance to CSS Backgrounds and Borders Level
 3.)
- Removed
 [box-decoration-break](https://drafts.csswg.org/css-break-4/#propdef-box-decoration-break); it is now part of
 [\[CSS-BREAK-3\]](#biblio-css-break-3 "CSS Fragmentation Module Level 3").
- Tighten up the definition of spread for
 [box-shadow](#propdef-box-shadow).
- Clarify that a
 [border-style](#propdef-border-style) of
 [none](#valdef-line-style-none) also implies an initial
 [border-image-width](#propdef-border-image-width) of zero (since
 [border-image-width]
 is initially set to the computed
 [border-width](#propdef-border-width), which in this case is zero).
- Clarified how [background-attachment:
 local](#propdef-background-attachment) is affected by scrolling.
- Simplified computed value of
 [background-position](#propdef-background-position) to clarify that all
 [background-position] values are interpolable.
- Added "Animation Type" values to each property definition table.

### 8.8. Changes since the 17 April 2012 Candidate Recommendation

The following (non-editorial) changes were made to this specification
since the [17 April 2012 Candidate
Recommendation](https://www.w3.org/TR/2012/CR-css3-background-20120417/):

- Fix error in computed value of
 [background-position](#propdef-background-position): the computed value is a list of
 positions.
- Add a note pointing out that when
 [border-radius](#propdef-border-radius) reduces the interactive area, the
 width/height of the box might need to be increased.

### 8.9. Changes since the 14 February 2012 "Last Call" Working Draft

The following (non-editorial) changes were made to this specification
since the [14 February 2012 "Last Call" Working
Draft](https://www.w3.org/TR/2012/WD-css3-background-20120214/):

These changes were in response to comments received during the review
period. For details, see the full [Disposition of
Comments.](https://drafts.csswg.org/css-backgrounds-3/issues-lc-2012)

- [Section 2.1](#placement): Defined which properties from this module
 apply to the
 [::first-line](https://drafts.csswg.org/selectors-3/#sel-first-line) and
 [::first-letter](https://drafts.csswg.org/selectors-3/#first-letter0) pseudo-elements.
- [Section 3.4](#background-repeat): Fixed the incorrect definition of
 the computed value of
 [background-repeat](#propdef-background-repeat). The value is always a pair of
 keywords, never a single keyword.
- [Section 3.10](#background-image): Added the missing
 [background-image](#propdef-background-image) to the list of properties that
 the [background](#propdef-background) property reset.
- [Section 4.3](#border-width): Added that negative lengths are invalid
 on
 [border-width](#propdef-border-width).
- [Section 5.1](#border-radius): Added that negative lengths are invalid
 on
 [border-radius](#propdef-border-radius).
- [Section 6.8](#border-image-tables): Added a section about the effect
 of
 [border-image](#propdef-border-image) on tables with collapsed borders
 and added that the rendering will be defined later.

### 8.10. Changes Since the 15 February 2011 Candidate Recommendation

The following changes were made to this specification since the [15
February 2011 Candidate
Recommendation](https://www.w3.org/TR/2011/CR-css3-background-20110215/):

- [Section 3.9](#background-size): Defined what happens if
 [background-size](#propdef-background-size) has two
 [auto](#valdef-background-size-auto) values and the image is missing a natural
 size.

 > If both values are
 > [auto](#valdef-background-size-auto) then the natural width and/or height of the
 > image should be used, if any [, the missing dimension (if any)
 > behaving as 'auto' as described above] .

- [Section 5.4](#corner-transitions): Made center of [color and style
 transitions](#corner-transitions) undefined (within certain limits) on
 corner joins, since previous definition was wrong.

 > ~~The center of color and style transitions between adjoining
 > borders is at the point on the curve that is at an angle that is
 > proportional to the ratio of the border widths. For example, if the
 > top and right border widths are equal, that point is at a 45° angle
 > from the horizontal, and if the top is twice the width of the right
 > the point is at a 30° angle from the horizontal. The line
 > demarcating this transition is drawn between the point at that angle
 > on the outer arc and the point at that angle on the inner arc.~~ [If
 > one of these borders is zero-width, then the other border takes up
 > the entire transitional area. Otherwise, the center of color and
 > style transitions between adjoining borders must be proportional to
 > the ratio of the border widths such that a function of its location
 > is continuous with respect to this ratio. However it is not defined
 > what these transitions look like or how "proportional" maps to a
 > point on the curve.]

- [Section 6.2](#border-image-slice): Defined [slicing of border
 images](#border-image-slice) that must be sized first to determine
 slice positions. Added:

 > [If the image must be sized to determine the slices (for example,
 > for SVG images with no natural size), then it is sized as for an
 > auto-sized background, using the border image area as the default
 > object size in place of the background positioning
 > area.]

- [Section 7.1](#misc) Optionally added bidi-imposed breaks to the types
 of breaks affected by
 [box-decoration-break](https://drafts.csswg.org/css-break-4/#propdef-box-decoration-break). Added:

 > [UAs may also apply 'box-decoration-break' to control rendering at
 > bidi-imposed breaks, i.e. when bidi reordering causes an inline to
 > split into non-contiguous fragments. Otherwise such breaks are
 > always handled as 'slice'.]

- [Section 7.2](#box-shadow): Defined the default color of
 [box-shadow](#propdef-box-shadow).

 > The color is the color of the shadow. [If the color is absent, the
 > used color is taken from the 'color' property.]

- [Section 3.6](#background-position): Clarified computed value of
 [background-position](#propdef-background-position).

 > ~~If one or two values are specified, for a \<length\> the absolute
 > length, otherwise a percentage. If three or four values are
 > specified, two pairs of a keyword plus a length or percentage.~~
 > [Two keywords representing the origin and two offsets from that
 > origin, each given as an absolute length (if given a
 > [\<length\>](https://drafts.csswg.org/css-values-4/#length-value)), otherwise as a
 > percentage.]

 Changed ~~Equivalent~~ to [Computes] in definition of
 keywords.

- Added \"Animation Type\" line to property definition tables.

- [Section 3.6](#background-position): Renamed \<bg-position\>
 production to
 [\<position\>](https://drafts.csswg.org/css-values-3/#typedef-position) for easier re-use in other
 specifications and recast the grammar to be more verbose but easier to
 understand.

 > ``` prod
 > bg-position<position> = [
 > [ left | center | right | top | bottom | <length-percentage> ]
 > |
 > [ left | center | right | <length-percentage> ]
 > [ top | center | bottom | <length-percentage> ]?
 > |
 > [ center | [ left | right ] <length-percentage>? ] &&
 > [ center | [ top | bottom ] <length-percentage>? ]
 > ]
 > ```

- [Section 6.5](#border-image-repeat): Added
 [space](#valdef-border-image-repeat-space) keyword to
 [border-image-repeat](#propdef-border-image-repeat) property value table: it was
 included in the list of allowable values, but not in the syntax
 definition.

 > \[ stretch \| repeat \| round [\| space] \]{1,2}

- [Section 5.5](#corner-overlap): Corrected math error in border-radius
 example.

 > The height (2.5em) is enough for the specified radii (0.5em plus
 > ~~2.5em~~ [2.0em] ).

- [Section 4.3](#border-width): Marked Percentages field as N/A for
 [border-width](#propdef-border-width), since they are not included in
 the property.

### 8.11. Changes Since the 17 December 2009 Candidate Recommendation

The following changes were made to this specification since the [17
December 2009 Candidate
Recommendation](https://www.w3.org/TR/2009/CR-css3-background-20091217/):

- Addition of
 [content-box](#valdef-background-clip-content-box) value of
 [background-clip](#propdef-background-clip).
- Change to the
 [background](#propdef-background) shorthand syntax for
 [background-clip](#propdef-background-clip) and
 [background-origin](#propdef-background-origin).
- Removal of recommendation to use gradients for color transitions when
 [border-radius](#propdef-border-radius) produces a curve.
- (Re)Addition of [box-shadow] property.
- Various clarifications.

## 9. Acknowledgments

Tapas Roy was editor of the Border Module, before it was merged with the
Background Module.

Thanks to Ben Stucki for defining what happens with rounded corners if
the two adjoining borders are of unequal thickness or one of them is
zero; to Arjan Eising and Anne van Kesteren for the
[border-radius](#propdef-border-radius) syntax; to Zack Weinberg for the
corner transition regions diagram; and to Lea Verou, plinss, and dbaron
for the corner radius adjustment formula (with special thanks to Lea for
the live demo).

A set of properties for border images was initially proposed by
*fantasai*. The current simplification (one image cut into nine parts)
is due to Ian Hickson. (Though the original idea seems to originate with
some anonymous Microsoft engineers.)

Finally, special thanks go to Brad Kemper for his feedback and
suggestions for many of the features in the draft, for drawing all the
box-shadow examples, and for proposing some [radical
changes](http://www.bradclicks.com/cssplay/border-image/Thinking_Outside_The_Box.html)
to the
[border-image](#propdef-border-image) property that solved a number of
problems with the earlier definition.

## 10. Privacy Considerations

This specification introduces no new privacy considerations.

## 11. Security Considerations

This specification introduces no new security considerations.
