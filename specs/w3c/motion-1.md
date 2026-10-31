## 1. Introduction

*This section is not normative.*

The
[transform](https://drafts.csswg.org/css-transforms-1/#propdef-transform) property and its related properties
allow a [box](https://drafts.csswg.org/css-display-4/#box) to be arbitrarily repositioned (and rotated, scaled,
etc) relative to its laid out position, without disrupting the layout of
any other elements on the page. These positions can be animated or
transitioned with CSS, but only in relatively simple ways: moving a box
in a straight line from its starting position to its ending position.

This specification introduces the
[offset](#propdef-offset) shorthand, and its suite of associated longhand
properties, which define an [offset transform]: a transform which aligns a
particular point on an element
([offset-anchor](#propdef-offset-anchor)) to an [offset
position]
on a *path*
([offset-path](#propdef-offset-path) and
[offset-distance](#propdef-offset-distance)), and optionally rotates it to
follow the path direction
([offset-rotate](#propdef-offset-rotate)).

This allows a number of powerful new transform possibilities, such as
positioning using polar coordinates (with the
[ray()](#funcdef-ray)
function) rather than the standard rectangular coordinates used by the
[translate()](https://drafts.csswg.org/css-transforms-1/#funcdef-transform-translate) function, or animating an element *along a
defined path*, making it easy to define complex and beautiful 2d spatial
transitions.

For example, the following picture
shows a curving path (indicated with dotted lines), and an airplane
graphic positioned at various points along the path. The plane faces in
the direction of the path at each position on the path.

<figure>
<img src="images/motion-path.svg" width="470" height="120"
a />
<p>The plane is shown at different <a href="#propdef-offset-distance"
id="ref-for-propdef-offset-distance①" class="css property"
data->offset-distance</a> values: <span
class="css">0%</span>, <span class="css">50%</span>, and <span
class="css">100%</span>.</p>
</figure>

### 1.1. Module interactions

This specification defines additional types of transforms (see
[\[css-transforms-1\]](#biblio-css-transforms-1 "CSS Transforms Module Level 1"))
that can be applied to an element.

As described in [CSS Transforms 2 § 6 Current Transformation
Matrix](https://drafts.csswg.org/css-transforms-2/#ctm), the transforms
defined by this document are layered after the individual transform
properties
([translate](https://drafts.csswg.org/css-transforms-2/#propdef-translate)/[rotate](https://drafts.csswg.org/css-transforms-2/#propdef-rotate)/[scale](https://drafts.csswg.org/css-transforms-2/#propdef-scale), defined in
[\[css-transforms-2\]](#biblio-css-transforms-2 "CSS Transforms Module Level 2"))
and before the
[transform](https://drafts.csswg.org/css-transforms-1/#propdef-transform) property (defined in
[\[css-transforms-1\]](#biblio-css-transforms-1 "CSS Transforms Module Level 1")).

### 1.2. Values

This specification follows the [CSS property definition
conventions](https://www.w3.org/TR/CSS21/about.html#property-defs) from
[\[CSS21\]](#biblio-css21 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification").
The
[\<basic-shape\>](https://drafts.csswg.org/css-shapes-1/#typedef-basic-shape) type is defined in CSS Shapes Module
Level 1
[\[CSS-SHAPES\]](#biblio-css-shapes "CSS Shapes Module Level 1").
The
[\<coord-box\>](https://drafts.csswg.org/css-box-4/#typedef-coord-box) type is defined in CSS Box Model
Module Level 3
[\[CSS-BOX-3\]](#biblio-css-box-3 "CSS Box Model Module Level 3").
Value types not defined in these specifications are defined in CSS
Values and Units Module Level 3
[\[CSS3VAL\]](#biblio-css3val "CSS Values and Units Module Level 3").

In addition to the property-specific values listed in their definitions,
all properties defined in this specification also accept CSS-wide
keywords such as
[initial](https://drafts.csswg.org/css-cascade-4/#valdef-all-initial)
and
[inherit](https://drafts.csswg.org/css-cascade-4/#valdef-all-inherit) as
their property value
[\[CSS3VAL\]](#biblio-css3val "CSS Values and Units Module Level 3").
For readability it has not been repeated explicitly.

## 2. Motion Paths

### 2.1. Defining A Path: the [offset-path property]
Name:

[offset-path]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

none
[\|](https://drafts.csswg.org/css-values-4/#comb-one)
[\<offset-path\>](#typedef-offset-path)
[\|\|](https://drafts.csswg.org/css-values-4/#comb-any)
[\<coord-box\>](https://drafts.csswg.org/css-box-4/#typedef-coord-box)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

none

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[transformable
elements](https://drafts.csswg.org/css-transforms-1/#transformable-element)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

as specified

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value

Media:

visual

Specifies the [offset path], a geometrical path the box gets positioned
on.

``` prod
<offset-path> = <ray()> | <url> | <basic-shape>
```

Values have the following meanings:

[none]

: The element does not have an [offset
 transform](#offset-transform).

[[\<offset-path\>](#typedef-offset-path) \|\| [\<coord-box\>](https://drafts.csswg.org/css-box-4/#typedef-coord-box)]

: The element has an [offset
 transform](#offset-transform), defined by some [offset
 path](#offset-path). See
 [§ 2.7 Calculating The Offset Transform](#transform) for details on
 how to calculate the [offset transform].

 All the usual effects of having a
 [transform](https://drafts.csswg.org/css-transforms-1/#propdef-transform) apply (such as creating a
 [stacking
 context](https://www.w3.org/TR/CSS2/visuren.html#x43), etc.) See [CSS Transforms 1 § 2 The Transform
 Rendering
 Model](https://drafts.csswg.org/css-transforms-1/#transform-rendering)
 for details.

 If
 [\<offset-path\>](#typedef-offset-path) is omitted, it defaults to
 [inset(0 round `X`)], where `X` is the
 value of
 [border-radius](https://drafts.csswg.org/css-backgrounds-3/#propdef-border-radius) on the element that establishes
 the [containing
 block](https://drafts.csswg.org/css-display-4/#containing-block) for this element. If
 [\<coord-box\>](https://drafts.csswg.org/css-box-4/#typedef-coord-box) is omitted, it defaults to
 [border-box](https://drafts.csswg.org/css-box-4/#valdef-box-border-box).

 See the specific values (below) for the interpretation of each
 component.

[[\<ray()\>](#funcdef-ray)]

: The [offset path](#offset-path) is a line extending from the
 [origin](#ray-origin) at some
 angle. See [§ 2.1.1 The ray() Function](#ray-function) for details.

 The
 [\<coord-box\>](https://drafts.csswg.org/css-box-4/#typedef-coord-box) provides the [reference
 box](https://drafts.csswg.org/css-shapes-1/#basic-shape-reference-box) for the ray.

[[\<url\>](https://drafts.csswg.org/css-values-4/#url-value)]

: A URL reference to an SVG [shape
 element](https://w3c.github.io/svgwg/svg2-draft/shapes.html#TermShapeElement). The [offset
 path](#offset-path) is the
 referenced element's [equivalent
 path](https://w3c.github.io/svgwg/svg2-draft/paths.html#TermEquivalentPath).
 [\[SVG2\]](#biblio-svg2 "Scalable Vector Graphics (SVG) 2")

 If the URL does not reference a [shape
 element](https://w3c.github.io/svgwg/svg2-draft/shapes.html#TermShapeElement) (because it references a different element, or
 resolves to a non-SVG document, or doesn't resolve at all, etc) this
 behaves as [path(\"m 0 0\")] (a
 [\<basic-shape\>](https://drafts.csswg.org/css-shapes-1/#typedef-basic-shape)) instead.

 The
 [\<coord-box\>](https://drafts.csswg.org/css-box-4/#typedef-coord-box) defines the viewport and user
 coordinate system for the [shape
 element](https://w3c.github.io/svgwg/svg2-draft/shapes.html#TermShapeElement), with the origin (the 0,0 point) at the top left
 corner, and units being [1px] in size.

[[\<basic-shape\>](https://drafts.csswg.org/css-shapes-1/#typedef-basic-shape)]

: The [offset path](#offset-path) is the [equivalent
 path](#basic-shape-equivalent-path) of the
 [\<basic-shape\>](https://drafts.csswg.org/css-shapes-1/#typedef-basic-shape) function.

 For all
 [\<basic-shape\>](https://drafts.csswg.org/css-shapes-1/#typedef-basic-shape)s, if they accept an [at
 [\<position\>](https://drafts.csswg.org/css-values-5/#typedef-position)] argument but that argument
 is omitted, and the element defines an [offset starting
 position](#offset-starting-position) via
 [offset-position](#propdef-offset-position), it uses the specified [offset
 starting position] for that
 argument. Otherwise it defaults as specified for each function.

 The
 [\<coord-box\>](https://drafts.csswg.org/css-box-4/#typedef-coord-box) provides the [reference
 box](https://drafts.csswg.org/css-shapes-1/#basic-shape-reference-box) for the
 [\<basic-shape\>](https://drafts.csswg.org/css-shapes-1/#typedef-basic-shape).

[[\<coord-box\>](https://drafts.csswg.org/css-box-4/#typedef-coord-box)]

: Defines the box that the
 [\<offset-path\>](#typedef-offset-path) sizes into.

 In CSS contexts, the boxes being referenced are from the element
 that establishes the [containing
 block](https://drafts.csswg.org/css-display-4/#containing-block) for this element.

 In SVG contexts, all values behave as
 [view-box](https://drafts.csswg.org/css-box-4/#valdef-box-view-box).

Tests

- [offset-path-composition.html](https://wpt.fyi/results/css/motion/animation/offset-path-composition.html "css/motion/animation/offset-path-composition.html")
 [[(live
 test)]](http://wpt.live/css/motion/animation/offset-path-composition.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/animation/offset-path-composition.html)
- [offset-path-coord-box-interpolation.html](https://wpt.fyi/results/css/motion/animation/offset-path-coord-box-interpolation.html "css/motion/animation/offset-path-coord-box-interpolation.html")
 [[(live
 test)]](http://wpt.live/css/motion/animation/offset-path-coord-box-interpolation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/animation/offset-path-coord-box-interpolation.html)
- [offset-path-interpolation-001.html](https://wpt.fyi/results/css/motion/animation/offset-path-interpolation-001.html "css/motion/animation/offset-path-interpolation-001.html")
 [[(live
 test)]](http://wpt.live/css/motion/animation/offset-path-interpolation-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/animation/offset-path-interpolation-001.html)
- [offset-path-interpolation-002.html](https://wpt.fyi/results/css/motion/animation/offset-path-interpolation-002.html "css/motion/animation/offset-path-interpolation-002.html")
 [[(live
 test)]](http://wpt.live/css/motion/animation/offset-path-interpolation-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/animation/offset-path-interpolation-002.html)
- [offset-path-interpolation-003.html](https://wpt.fyi/results/css/motion/animation/offset-path-interpolation-003.html "css/motion/animation/offset-path-interpolation-003.html")
 [[(live
 test)]](http://wpt.live/css/motion/animation/offset-path-interpolation-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/animation/offset-path-interpolation-003.html)
- [offset-path-interpolation-004.html](https://wpt.fyi/results/css/motion/animation/offset-path-interpolation-004.html "css/motion/animation/offset-path-interpolation-004.html")
 [[(live
 test)]](http://wpt.live/css/motion/animation/offset-path-interpolation-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/animation/offset-path-interpolation-004.html)
- [offset-path-interpolation-005.html](https://wpt.fyi/results/css/motion/animation/offset-path-interpolation-005.html "css/motion/animation/offset-path-interpolation-005.html")
 [[(live
 test)]](http://wpt.live/css/motion/animation/offset-path-interpolation-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/animation/offset-path-interpolation-005.html)
- [offset-path-interpolation-006.html](https://wpt.fyi/results/css/motion/animation/offset-path-interpolation-006.html "css/motion/animation/offset-path-interpolation-006.html")
 [[(live
 test)]](http://wpt.live/css/motion/animation/offset-path-interpolation-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/animation/offset-path-interpolation-006.html)
- [offset-path-interpolation-007.html](https://wpt.fyi/results/css/motion/animation/offset-path-interpolation-007.html "css/motion/animation/offset-path-interpolation-007.html")
 [[(live
 test)]](http://wpt.live/css/motion/animation/offset-path-interpolation-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/animation/offset-path-interpolation-007.html)
- [offset-path-interpolation-008.html](https://wpt.fyi/results/css/motion/animation/offset-path-interpolation-008.html "css/motion/animation/offset-path-interpolation-008.html")
 [[(live
 test)]](http://wpt.live/css/motion/animation/offset-path-interpolation-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/animation/offset-path-interpolation-008.html)
- [offset-path-path-interpolation-001.html](https://wpt.fyi/results/css/motion/animation/reftests/offset-path-path-interpolation-001.html "css/motion/animation/reftests/offset-path-path-interpolation-001.html")
 [[(live
 test)]](http://wpt.live/css/motion/animation/reftests/offset-path-path-interpolation-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/animation/reftests/offset-path-path-interpolation-001.html)
- [offset-path-with-transforms-001.html](https://wpt.fyi/results/css/motion/animation/reftests/offset-path-with-transforms-001.html "css/motion/animation/reftests/offset-path-with-transforms-001.html")
 [[(live
 test)]](http://wpt.live/css/motion/animation/reftests/offset-path-with-transforms-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/animation/reftests/offset-path-with-transforms-001.html)
- [change-offset-path.html](https://wpt.fyi/results/css/motion/change-offset-path.html "css/motion/change-offset-path.html")
 [[(live
 test)]](http://wpt.live/css/motion/change-offset-path.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/change-offset-path.html)
- [offset-path-coord-box-001.html](https://wpt.fyi/results/css/motion/offset-path-coord-box-001.html "css/motion/offset-path-coord-box-001.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-coord-box-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-coord-box-001.html)
- [offset-path-coord-box-002.html](https://wpt.fyi/results/css/motion/offset-path-coord-box-002.html "css/motion/offset-path-coord-box-002.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-coord-box-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-coord-box-002.html)
- [offset-path-coord-box-003.html](https://wpt.fyi/results/css/motion/offset-path-coord-box-003.html "css/motion/offset-path-coord-box-003.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-coord-box-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-coord-box-003.html)
- [offset-path-coord-box-004.html](https://wpt.fyi/results/css/motion/offset-path-coord-box-004.html "css/motion/offset-path-coord-box-004.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-coord-box-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-coord-box-004.html)
- [offset-path-huge-angle-deg-001-crash.html](https://wpt.fyi/results/css/motion/offset-path-huge-angle-deg-001-crash.html "css/motion/offset-path-huge-angle-deg-001-crash.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-huge-angle-deg-001-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-huge-angle-deg-001-crash.html)
- [offset-path-huge-angle-grad-001-crash.html](https://wpt.fyi/results/css/motion/offset-path-huge-angle-grad-001-crash.html "css/motion/offset-path-huge-angle-grad-001-crash.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-huge-angle-grad-001-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-huge-angle-grad-001-crash.html)
- [offset-path-huge-angle-turn-001-crash.html](https://wpt.fyi/results/css/motion/offset-path-huge-angle-turn-001-crash.html "css/motion/offset-path-huge-angle-turn-001-crash.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-huge-angle-turn-001-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-huge-angle-turn-001-crash.html)
- [offset-path-ray-001.html](https://wpt.fyi/results/css/motion/offset-path-ray-001.html "css/motion/offset-path-ray-001.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-ray-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-ray-001.html)
- [offset-path-ray-002.html](https://wpt.fyi/results/css/motion/offset-path-ray-002.html "css/motion/offset-path-ray-002.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-ray-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-ray-002.html)
- [offset-path-ray-003.html](https://wpt.fyi/results/css/motion/offset-path-ray-003.html "css/motion/offset-path-ray-003.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-ray-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-ray-003.html)
- [offset-path-ray-004.html](https://wpt.fyi/results/css/motion/offset-path-ray-004.html "css/motion/offset-path-ray-004.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-ray-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-ray-004.html)
- [offset-path-ray-005.html](https://wpt.fyi/results/css/motion/offset-path-ray-005.html "css/motion/offset-path-ray-005.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-ray-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-ray-005.html)
- [offset-path-ray-006.html](https://wpt.fyi/results/css/motion/offset-path-ray-006.html "css/motion/offset-path-ray-006.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-ray-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-ray-006.html)
- [offset-path-ray-007.html](https://wpt.fyi/results/css/motion/offset-path-ray-007.html "css/motion/offset-path-ray-007.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-ray-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-ray-007.html)
- [offset-path-ray-008.html](https://wpt.fyi/results/css/motion/offset-path-ray-008.html "css/motion/offset-path-ray-008.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-ray-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-ray-008.html)
- [offset-path-ray-009.html](https://wpt.fyi/results/css/motion/offset-path-ray-009.html "css/motion/offset-path-ray-009.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-ray-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-ray-009.html)
- [offset-path-ray-010.html](https://wpt.fyi/results/css/motion/offset-path-ray-010.html "css/motion/offset-path-ray-010.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-ray-010.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-ray-010.html)
- [offset-path-ray-011.html](https://wpt.fyi/results/css/motion/offset-path-ray-011.html "css/motion/offset-path-ray-011.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-ray-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-ray-011.html)
- [offset-path-ray-012.html](https://wpt.fyi/results/css/motion/offset-path-ray-012.html "css/motion/offset-path-ray-012.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-ray-012.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-ray-012.html)
- [offset-path-ray-013.html](https://wpt.fyi/results/css/motion/offset-path-ray-013.html "css/motion/offset-path-ray-013.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-ray-013.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-ray-013.html)
- [offset-path-ray-014.html](https://wpt.fyi/results/css/motion/offset-path-ray-014.html "css/motion/offset-path-ray-014.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-ray-014.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-ray-014.html)
- [offset-path-ray-015.html](https://wpt.fyi/results/css/motion/offset-path-ray-015.html "css/motion/offset-path-ray-015.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-ray-015.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-ray-015.html)
- [offset-path-ray-016.html](https://wpt.fyi/results/css/motion/offset-path-ray-016.html "css/motion/offset-path-ray-016.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-ray-016.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-ray-016.html)
- [offset-path-ray-017.html](https://wpt.fyi/results/css/motion/offset-path-ray-017.html "css/motion/offset-path-ray-017.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-ray-017.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-ray-017.html)
- [offset-path-ray-018.html](https://wpt.fyi/results/css/motion/offset-path-ray-018.html "css/motion/offset-path-ray-018.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-ray-018.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-ray-018.html)
- [offset-path-ray-019.html](https://wpt.fyi/results/css/motion/offset-path-ray-019.html "css/motion/offset-path-ray-019.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-ray-019.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-ray-019.html)
- [offset-path-ray-020.html](https://wpt.fyi/results/css/motion/offset-path-ray-020.html "css/motion/offset-path-ray-020.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-ray-020.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-ray-020.html)
- [offset-path-ray-021.html](https://wpt.fyi/results/css/motion/offset-path-ray-021.html "css/motion/offset-path-ray-021.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-ray-021.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-ray-021.html)
- [offset-path-ray-022.html](https://wpt.fyi/results/css/motion/offset-path-ray-022.html "css/motion/offset-path-ray-022.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-ray-022.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-ray-022.html)
- [offset-path-ray-contain-001.html](https://wpt.fyi/results/css/motion/offset-path-ray-contain-001.html "css/motion/offset-path-ray-contain-001.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-ray-contain-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-ray-contain-001.html)
- [offset-path-ray-contain-002.html](https://wpt.fyi/results/css/motion/offset-path-ray-contain-002.html "css/motion/offset-path-ray-contain-002.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-ray-contain-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-ray-contain-002.html)
- [offset-path-ray-contain-003.html](https://wpt.fyi/results/css/motion/offset-path-ray-contain-003.html "css/motion/offset-path-ray-contain-003.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-ray-contain-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-ray-contain-003.html)
- [offset-path-ray-contain-004.html](https://wpt.fyi/results/css/motion/offset-path-ray-contain-004.html "css/motion/offset-path-ray-contain-004.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-ray-contain-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-ray-contain-004.html)
- [offset-path-ray-contain-005.html](https://wpt.fyi/results/css/motion/offset-path-ray-contain-005.html "css/motion/offset-path-ray-contain-005.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-ray-contain-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-ray-contain-005.html)
- [offset-path-shape-circle-001.html](https://wpt.fyi/results/css/motion/offset-path-shape-circle-001.html "css/motion/offset-path-shape-circle-001.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-shape-circle-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-shape-circle-001.html)
- [offset-path-shape-circle-002.html](https://wpt.fyi/results/css/motion/offset-path-shape-circle-002.html "css/motion/offset-path-shape-circle-002.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-shape-circle-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-shape-circle-002.html)
- [offset-path-shape-circle-003.html](https://wpt.fyi/results/css/motion/offset-path-shape-circle-003.html "css/motion/offset-path-shape-circle-003.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-shape-circle-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-shape-circle-003.html)
- [offset-path-shape-circle-004.html](https://wpt.fyi/results/css/motion/offset-path-shape-circle-004.html "css/motion/offset-path-shape-circle-004.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-shape-circle-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-shape-circle-004.html)
- [offset-path-shape-circle-005.html](https://wpt.fyi/results/css/motion/offset-path-shape-circle-005.html "css/motion/offset-path-shape-circle-005.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-shape-circle-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-shape-circle-005.html)
- [offset-path-shape-circle-006.html](https://wpt.fyi/results/css/motion/offset-path-shape-circle-006.html "css/motion/offset-path-shape-circle-006.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-shape-circle-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-shape-circle-006.html)
- [offset-path-shape-circle-007.html](https://wpt.fyi/results/css/motion/offset-path-shape-circle-007.html "css/motion/offset-path-shape-circle-007.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-shape-circle-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-shape-circle-007.html)
- [offset-path-shape-circle-008.html](https://wpt.fyi/results/css/motion/offset-path-shape-circle-008.html "css/motion/offset-path-shape-circle-008.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-shape-circle-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-shape-circle-008.html)
- [offset-path-shape-ellipse-001.html](https://wpt.fyi/results/css/motion/offset-path-shape-ellipse-001.html "css/motion/offset-path-shape-ellipse-001.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-shape-ellipse-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-shape-ellipse-001.html)
- [offset-path-shape-ellipse-002.html](https://wpt.fyi/results/css/motion/offset-path-shape-ellipse-002.html "css/motion/offset-path-shape-ellipse-002.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-shape-ellipse-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-shape-ellipse-002.html)
- [offset-path-shape-ellipse-003.html](https://wpt.fyi/results/css/motion/offset-path-shape-ellipse-003.html "css/motion/offset-path-shape-ellipse-003.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-shape-ellipse-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-shape-ellipse-003.html)
- [offset-path-shape-ellipse-004.html](https://wpt.fyi/results/css/motion/offset-path-shape-ellipse-004.html "css/motion/offset-path-shape-ellipse-004.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-shape-ellipse-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-shape-ellipse-004.html)
- [offset-path-shape-ellipse-005.html](https://wpt.fyi/results/css/motion/offset-path-shape-ellipse-005.html "css/motion/offset-path-shape-ellipse-005.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-shape-ellipse-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-shape-ellipse-005.html)
- [offset-path-shape-ellipse-006.html](https://wpt.fyi/results/css/motion/offset-path-shape-ellipse-006.html "css/motion/offset-path-shape-ellipse-006.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-shape-ellipse-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-shape-ellipse-006.html)
- [offset-path-shape-ellipse-007.html](https://wpt.fyi/results/css/motion/offset-path-shape-ellipse-007.html "css/motion/offset-path-shape-ellipse-007.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-shape-ellipse-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-shape-ellipse-007.html)
- [offset-path-shape-inset-001.html](https://wpt.fyi/results/css/motion/offset-path-shape-inset-001.html "css/motion/offset-path-shape-inset-001.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-shape-inset-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-shape-inset-001.html)
- [offset-path-shape-inset-002.html](https://wpt.fyi/results/css/motion/offset-path-shape-inset-002.html "css/motion/offset-path-shape-inset-002.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-shape-inset-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-shape-inset-002.html)
- [offset-path-shape-polygon-001.html](https://wpt.fyi/results/css/motion/offset-path-shape-polygon-001.html "css/motion/offset-path-shape-polygon-001.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-shape-polygon-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-shape-polygon-001.html)
- [offset-path-shape-polygon-002.html](https://wpt.fyi/results/css/motion/offset-path-shape-polygon-002.html "css/motion/offset-path-shape-polygon-002.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-shape-polygon-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-shape-polygon-002.html)
- [offset-path-shape-polygon-003.html](https://wpt.fyi/results/css/motion/offset-path-shape-polygon-003.html "css/motion/offset-path-shape-polygon-003.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-shape-polygon-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-shape-polygon-003.html)
- [offset-path-shape-rect-001.html](https://wpt.fyi/results/css/motion/offset-path-shape-rect-001.html "css/motion/offset-path-shape-rect-001.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-shape-rect-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-shape-rect-001.html)
- [offset-path-shape-rect-002.html](https://wpt.fyi/results/css/motion/offset-path-shape-rect-002.html "css/motion/offset-path-shape-rect-002.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-shape-rect-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-shape-rect-002.html)
- [offset-path-shape-rect-003.html](https://wpt.fyi/results/css/motion/offset-path-shape-rect-003.html "css/motion/offset-path-shape-rect-003.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-shape-rect-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-shape-rect-003.html)
- [offset-path-shape-shape-001.html](https://wpt.fyi/results/css/motion/offset-path-shape-shape-001.html "css/motion/offset-path-shape-shape-001.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-shape-shape-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-shape-shape-001.html)
- [offset-path-shape-shape-002.html](https://wpt.fyi/results/css/motion/offset-path-shape-shape-002.html "css/motion/offset-path-shape-shape-002.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-shape-shape-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-shape-shape-002.html)
- [offset-path-shape-shape-003.html](https://wpt.fyi/results/css/motion/offset-path-shape-shape-003.html "css/motion/offset-path-shape-shape-003.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-shape-shape-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-shape-shape-003.html)
- [offset-path-shape-xywh-001.html](https://wpt.fyi/results/css/motion/offset-path-shape-xywh-001.html "css/motion/offset-path-shape-xywh-001.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-shape-xywh-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-shape-xywh-001.html)
- [offset-path-shape-xywh-002.html](https://wpt.fyi/results/css/motion/offset-path-shape-xywh-002.html "css/motion/offset-path-shape-xywh-002.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-shape-xywh-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-shape-xywh-002.html)
- [offset-path-shape-xywh-003.html](https://wpt.fyi/results/css/motion/offset-path-shape-xywh-003.html "css/motion/offset-path-shape-xywh-003.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-shape-xywh-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-shape-xywh-003.html)
- [offset-path-string-001.html](https://wpt.fyi/results/css/motion/offset-path-string-001.html "css/motion/offset-path-string-001.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-string-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-string-001.html)
- [offset-path-string-002.html](https://wpt.fyi/results/css/motion/offset-path-string-002.html "css/motion/offset-path-string-002.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-string-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-string-002.html)
- [offset-path-string-003.html](https://wpt.fyi/results/css/motion/offset-path-string-003.html "css/motion/offset-path-string-003.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-string-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-string-003.html)
- [offset-path-url-001.html](https://wpt.fyi/results/css/motion/offset-path-url-001.html "css/motion/offset-path-url-001.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-url-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-url-001.html)
- [offset-path-url-002.html](https://wpt.fyi/results/css/motion/offset-path-url-002.html "css/motion/offset-path-url-002.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-url-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-url-002.html)
- [offset-path-url-003.html](https://wpt.fyi/results/css/motion/offset-path-url-003.html "css/motion/offset-path-url-003.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-url-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-url-003.html)
- [offset-path-url-004.html](https://wpt.fyi/results/css/motion/offset-path-url-004.html "css/motion/offset-path-url-004.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-url-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-url-004.html)
- [offset-path-url-005.html](https://wpt.fyi/results/css/motion/offset-path-url-005.html "css/motion/offset-path-url-005.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-url-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-url-005.html)
- [offset-path-url-006.html](https://wpt.fyi/results/css/motion/offset-path-url-006.html "css/motion/offset-path-url-006.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-url-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-url-006.html)
- [offset-path-url-007.html](https://wpt.fyi/results/css/motion/offset-path-url-007.html "css/motion/offset-path-url-007.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-url-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-url-007.html)
- [offset-path-url-008.html](https://wpt.fyi/results/css/motion/offset-path-url-008.html "css/motion/offset-path-url-008.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-url-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-url-008.html)
- [offset-path-url-009.html](https://wpt.fyi/results/css/motion/offset-path-url-009.html "css/motion/offset-path-url-009.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-url-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-url-009.html)
- [offset-path-url-010.html](https://wpt.fyi/results/css/motion/offset-path-url-010.html "css/motion/offset-path-url-010.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-url-010.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-url-010.html)
- [offset-path-url-011.html](https://wpt.fyi/results/css/motion/offset-path-url-011.html "css/motion/offset-path-url-011.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-url-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-url-011.html)
- [offset-path-url-crash.html](https://wpt.fyi/results/css/motion/offset-path-url-crash.html "css/motion/offset-path-url-crash.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-url-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-url-crash.html)
- [offset-path-computed.html](https://wpt.fyi/results/css/motion/parsing/offset-path-computed.html "css/motion/parsing/offset-path-computed.html")
 [[(live
 test)]](http://wpt.live/css/motion/parsing/offset-path-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/parsing/offset-path-computed.html)
- [offset-path-parsing-invalid.html](https://wpt.fyi/results/css/motion/parsing/offset-path-parsing-invalid.html "css/motion/parsing/offset-path-parsing-invalid.html")
 [[(live
 test)]](http://wpt.live/css/motion/parsing/offset-path-parsing-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/parsing/offset-path-parsing-invalid.html)
- [offset-path-parsing-valid.html](https://wpt.fyi/results/css/motion/parsing/offset-path-parsing-valid.html "css/motion/parsing/offset-path-parsing-valid.html")
 [[(live
 test)]](http://wpt.live/css/motion/parsing/offset-path-parsing-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/parsing/offset-path-parsing-valid.html)
- [offset-path-shape-computed.html](https://wpt.fyi/results/css/motion/parsing/offset-path-shape-computed.html "css/motion/parsing/offset-path-shape-computed.html")
 [[(live
 test)]](http://wpt.live/css/motion/parsing/offset-path-shape-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/parsing/offset-path-shape-computed.html)
- [offset-path-shape-parsing.html](https://wpt.fyi/results/css/motion/parsing/offset-path-shape-parsing.html "css/motion/parsing/offset-path-shape-parsing.html")
 [[(live
 test)]](http://wpt.live/css/motion/parsing/offset-path-shape-parsing.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/parsing/offset-path-shape-parsing.html)

#### 2.1.1. The [ray() Function]
The [ray()](#funcdef-ray)
function defines an [offset path](#offset-path) as a straight line emerging from a point at some
defined angle:

``` prod
ray() = ray( <angle> && <ray-size>? && contain? && [at <position>]? )

<ray-size> = <radial-extent> | sides
```

Its arguments are:

[[\<angle\>](https://drafts.csswg.org/css-values-4/#angle-value)]

: The [offset path](#offset-path) is a single line segment that starts from the
 [offset starting
 position](#offset-starting-position) and proceeds in the direction defined by the
 specified
 [\<angle\>](https://drafts.csswg.org/css-values-4/#angle-value). (Its length is determined by the
 other arguments.) As with [gradient
 functions](https://drafts.csswg.org/css-images-4/#gradient-function), [\<angle\>]
 values are interpreted as bearing angles, with [0deg] pointing
 up and positive angles representing clockwise rotation.

[\<ray-size\>]

: Specifies the length of the [offset
 path](#offset-path) (the
 distance between the [offset-distance:
 0%](#propdef-offset-distance) and [offset-distance:
 100%] points) relative to
 the containing box.

 If no [\<ray-size\>](#typedef-ray-size) is specified it defaults to
 [closest-side](#size-closest-side).

 For [sides](#size-sides), the distance depends on the
 [\<angle\>](https://drafts.csswg.org/css-values-4/#angle-value) specified; for all other values,
 the distance is constant regardless of the
 [\<angle\>].

 Individual keywords are:

 [closest-side]

 : The distance from the ray's starting point to whichever side of
 the [containing
 block](https://drafts.csswg.org/css-display-4/#containing-block) is closest.

 [closest-corner]

 : The distance from the ray's starting point to whichever corner
 of the [containing
 block](https://drafts.csswg.org/css-display-4/#containing-block) is closest.

 [farthest-side]

 : The distance from the ray's starting point to whichever side of
 the [containing
 block](https://drafts.csswg.org/css-display-4/#containing-block) is farthest.

 [farthest-corner]

 : The distance from the ray's starting point to whichever corner
 of the [containing
 block](https://drafts.csswg.org/css-display-4/#containing-block) is farthest.

 [sides]

 : The distance from the ray's starting point to the point where
 the [offset path](#offset-path) intersects the [containing
 block's](https://drafts.csswg.org/css-display-4/#containing-block) boundary.

 If the ray's starting point is on the [containing
 block's](https://drafts.csswg.org/css-display-4/#containing-block) boundary, or outside its bounds entirely, the
 distance is zero.

 For
 [closest-side](#size-closest-side) and
 [closest-corner](#size-closest-corner), if the ray's starting point is *on* an
 edge/corner, that's the closest one. (In other words, the distance
 is zero.)

 For
 [closest-side](#size-closest-side) and
 [farthest-side](#size-farthest-side), if the ray's starting point is outside the
 [containing
 block](https://drafts.csswg.org/css-display-4/#containing-block) entirely, the edges of the [containing
 block] are considered to extend out to
 infinity.

[contain]

: The length of the [offset path](#offset-path) is reduced so that the element stays within the
 [containing
 block](https://drafts.csswg.org/css-display-4/#containing-block) even at [offset-distance:
 100%](#propdef-offset-distance).

 Specifically, the path's length is reduced by half the width or half
 the height of the element's border box, whichever is larger, and
 floored at zero.

 :::
 This behavior is optimized for a particular case---​the element's
 width and height are equal or nearly so; the element is either
 completely rounded by
 [border-radius](https://drafts.csswg.org/css-backgrounds-3/#propdef-border-radius) or the corners aren't relevant
 to its appearance; the [ray()](#funcdef-ray) uses
 [closest-side](#size-closest-side) positioning; and
 [offset-anchor](#propdef-offset-anchor) is set to [center].
 Under these conditions, which are common for situations like
 positioning elements around the edge of a round clock face, this
 ensures that each element is positioned fairly snugly against the
 inner edge of the clock face at [offset-distance:
 100%](#propdef-offset-distance).

 In other conditions this will act *similarly* but might not give
 quite as optimal a result.
 :::

[at [\<position\>](https://drafts.csswg.org/css-values-5/#typedef-position)]

: Specifies the [origin] of the ray, where the ray's line begins
 (the 0% position). It's resolved by using the
 [\<position\>](https://drafts.csswg.org/css-values-5/#typedef-position) to position a 0x0 object area
 within the box's [containing
 block](https://drafts.csswg.org/css-display-4/#containing-block).

 If omitted, it uses the [offset starting
 position](#offset-starting-position) of the element, given by
 [offset-position](#propdef-offset-position).

 If the element doesn't have an [offset starting
 position](#offset-starting-position) either, it behaves as [at center].

 [ray()](#funcdef-ray) is currently only usable as an [offset
 path](#offset-path). If it
 ever gets extended to other uses, its usage of
 [offset-position](#propdef-offset-position) will be limited solely to when
 it's an [offset path], similar to other
 [\<basic-shape\>](https://drafts.csswg.org/css-shapes-1/#typedef-basic-shape) functions.

Tests

- [ray-angle-interpolation-math-functions.html](https://wpt.fyi/results/css/motion/animation/ray-angle-interpolation-math-functions.html "css/motion/animation/ray-angle-interpolation-math-functions.html")
 [[(live
 test)]](http://wpt.live/css/motion/animation/ray-angle-interpolation-math-functions.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/animation/ray-angle-interpolation-math-functions.html)
- [offset-path-ray-001.html](https://wpt.fyi/results/css/motion/offset-path-ray-001.html "css/motion/offset-path-ray-001.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-ray-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-ray-001.html)
- [offset-path-ray-002.html](https://wpt.fyi/results/css/motion/offset-path-ray-002.html "css/motion/offset-path-ray-002.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-ray-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-ray-002.html)
- [offset-path-ray-003.html](https://wpt.fyi/results/css/motion/offset-path-ray-003.html "css/motion/offset-path-ray-003.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-ray-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-ray-003.html)
- [offset-path-ray-004.html](https://wpt.fyi/results/css/motion/offset-path-ray-004.html "css/motion/offset-path-ray-004.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-ray-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-ray-004.html)
- [offset-path-ray-005.html](https://wpt.fyi/results/css/motion/offset-path-ray-005.html "css/motion/offset-path-ray-005.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-ray-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-ray-005.html)
- [offset-path-ray-006.html](https://wpt.fyi/results/css/motion/offset-path-ray-006.html "css/motion/offset-path-ray-006.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-ray-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-ray-006.html)
- [offset-path-ray-007.html](https://wpt.fyi/results/css/motion/offset-path-ray-007.html "css/motion/offset-path-ray-007.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-ray-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-ray-007.html)
- [offset-path-ray-008.html](https://wpt.fyi/results/css/motion/offset-path-ray-008.html "css/motion/offset-path-ray-008.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-ray-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-ray-008.html)
- [offset-path-ray-009.html](https://wpt.fyi/results/css/motion/offset-path-ray-009.html "css/motion/offset-path-ray-009.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-ray-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-ray-009.html)
- [offset-path-ray-010.html](https://wpt.fyi/results/css/motion/offset-path-ray-010.html "css/motion/offset-path-ray-010.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-ray-010.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-ray-010.html)
- [offset-path-ray-011.html](https://wpt.fyi/results/css/motion/offset-path-ray-011.html "css/motion/offset-path-ray-011.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-ray-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-ray-011.html)
- [offset-path-ray-012.html](https://wpt.fyi/results/css/motion/offset-path-ray-012.html "css/motion/offset-path-ray-012.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-ray-012.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-ray-012.html)
- [offset-path-ray-013.html](https://wpt.fyi/results/css/motion/offset-path-ray-013.html "css/motion/offset-path-ray-013.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-ray-013.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-ray-013.html)
- [offset-path-ray-014.html](https://wpt.fyi/results/css/motion/offset-path-ray-014.html "css/motion/offset-path-ray-014.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-ray-014.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-ray-014.html)
- [offset-path-ray-015.html](https://wpt.fyi/results/css/motion/offset-path-ray-015.html "css/motion/offset-path-ray-015.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-ray-015.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-ray-015.html)
- [offset-path-ray-016.html](https://wpt.fyi/results/css/motion/offset-path-ray-016.html "css/motion/offset-path-ray-016.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-ray-016.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-ray-016.html)
- [offset-path-ray-017.html](https://wpt.fyi/results/css/motion/offset-path-ray-017.html "css/motion/offset-path-ray-017.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-ray-017.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-ray-017.html)
- [offset-path-ray-018.html](https://wpt.fyi/results/css/motion/offset-path-ray-018.html "css/motion/offset-path-ray-018.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-ray-018.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-ray-018.html)
- [offset-path-ray-019.html](https://wpt.fyi/results/css/motion/offset-path-ray-019.html "css/motion/offset-path-ray-019.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-ray-019.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-ray-019.html)
- [offset-path-ray-020.html](https://wpt.fyi/results/css/motion/offset-path-ray-020.html "css/motion/offset-path-ray-020.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-ray-020.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-ray-020.html)
- [offset-path-ray-021.html](https://wpt.fyi/results/css/motion/offset-path-ray-021.html "css/motion/offset-path-ray-021.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-ray-021.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-ray-021.html)
- [offset-path-ray-022.html](https://wpt.fyi/results/css/motion/offset-path-ray-022.html "css/motion/offset-path-ray-022.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-ray-022.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-ray-022.html)
- [offset-path-ray-contain-001.html](https://wpt.fyi/results/css/motion/offset-path-ray-contain-001.html "css/motion/offset-path-ray-contain-001.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-ray-contain-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-ray-contain-001.html)
- [offset-path-ray-contain-002.html](https://wpt.fyi/results/css/motion/offset-path-ray-contain-002.html "css/motion/offset-path-ray-contain-002.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-ray-contain-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-ray-contain-002.html)
- [offset-path-ray-contain-003.html](https://wpt.fyi/results/css/motion/offset-path-ray-contain-003.html "css/motion/offset-path-ray-contain-003.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-ray-contain-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-ray-contain-003.html)
- [offset-path-ray-contain-004.html](https://wpt.fyi/results/css/motion/offset-path-ray-contain-004.html "css/motion/offset-path-ray-contain-004.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-ray-contain-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-ray-contain-004.html)
- [offset-path-ray-contain-005.html](https://wpt.fyi/results/css/motion/offset-path-ray-contain-005.html "css/motion/offset-path-ray-contain-005.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-path-ray-contain-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-path-ray-contain-005.html)

all of these examples need to be
rewritten.

Here are some examples. The first
example shows that some parts of boxes are outside of the [offset
path](#offset-path).

``` highlight
<style>
 body {
 transform-style: preserve-3d;
 width: 200px;
 height: 200px;
 }
 .box {
 width: 50px;
 height: 50px;
 offset-position: 50% 50%;
 offset-distance: 100%;
 offset-rotate: 0deg;
 }
 #redBox {
 background-color: red;
 offset-path: ray(45deg closest-side);
 }
 #blueBox {
 background-color: blue;
 offset-path: ray(180deg closest-side);
 }
</style>
<body>
 <div class="box" id="redBox"></div>
 <div class="box" id="blueBox"></div>
</body>
```

![[offset-path](#propdef-offset-path) without
[contain](https://drafts.csswg.org/css-contain-2/#propdef-contain)](images/offset_distance_without_contain.png){a
height="220" width="200"}

In the second example,
[contain](https://drafts.csswg.org/css-contain-2/#propdef-contain) is given to the
[offset-path](#propdef-offset-path) value of each box to avoid overflowing.

``` highlight
<style>
 body {
 transform-style: preserve-3d;
 width: 200px;
 height: 200px;
 }
 .box {
 width: 50px;
 height: 50px;
 offset-position: 50% 50%;
 offset-distance: 100%;
 offset-rotate: 0deg;
 }
 #redBox {
 background-color: red;
 offset-path: ray(45deg closest-side contain);
 }
 #blueBox {
 background-color: blue;
 offset-path: ray(180deg closest-side contain);
 }
</style>
<body>
 <div class="box" id="redBox"></div>
 <div class="box" id="blueBox"></div>
</body>
```

![[offset-path](#propdef-offset-path) with
[contain](https://drafts.csswg.org/css-contain-2/#propdef-contain)](images/offset_distance_with_contain.png){a
height="220" width="200"}

In the third example, the path size is increased so that the box can be
contained. The [used offset
distance](#used-offset-distance) is negative.

``` highlight
<style>
 body {
 transform-style: preserve-3d;
 width: 250px;
 height: 250px;
 }
 .box {
 width: 60%;
 height: 10%;

 offset-position: 20% 20%;
 offset-distance: 0%;
 offset-rotate: 0deg;
 offset-anchor: 200% -300%;
 }
 #blueBox {
 background-color: blue;
 offset-path: ray(-90deg closest-side contain);
 }
</style>
<body>
 <div class="box" id="blueBox"></div>
</body>
```

![[offset-path](#propdef-offset-path) with path size
increased](images/increase-size.svg){a
height="335" width="400"}

In the fourth example, the initial position is outside the containing
block.

``` highlight
<style>
 #container {
 transform-style: preserve-3d;
 width: 200px;
 height: 200px;
 }
 .box {
 width: 20%;
 height: 20%;
 offset-position: 140% 70%;
 offset-distance: 100%;
 }
 #redBox {
 background-color: red;
 offset-path: ray(-90deg sides);
 }
 #blueBox {
 background-color: blue;
 offset-path: ray(180deg closest-side);
 }
</style>
<div id="container">
 <div class="box" id="redBox"></div>
 <div class="box" id="blueBox"></div>
</div>
```

![Initial position outside the containing
block](images/initial-outside.svg){a
height="460" width="700"}

#### [2.1.2. ][Examples Of [\<basic-shape\>](https://drafts.csswg.org/css-shapes-1/#typedef-basic-shape) Positioning]
This example uses a circle with
implicit center position.

``` highlight
<style>
 body {
 width: 323px;
 height: 131px;
 margin: 0px;
 border: 2px solid black;
 padding: 8px;
 transform-style: preserve-3d;
 }
 .item {
 width: 90px;
 height: 40px;
 background-color: violet;
 }
 #middle {
 offset-position: auto;
 offset-path: circle(60%) margin-box;
 offset-distance: 25%;
 offset-anchor: left top;
 }
</style>
<body>
 <div class="item"></div>
 <div class="item" id="middle"></div>
 <div class="item"></div>
</body>
```

![The circle center is determined by normal
flow.](images/normal-flow.svg){a
height="324" width="505"}

#### [2.1.3. ][Examples of [\<coord-box\>](https://drafts.csswg.org/css-box-4/#typedef-coord-box) Positioning]
This example shows how
[\<coord-box\>](https://drafts.csswg.org/css-box-4/#typedef-coord-box) [offset
path](#offset-path) works in
combination with
[border-radius](https://drafts.csswg.org/css-backgrounds-3/#propdef-border-radius).

``` highlight
<style>
 body {
 width: 500px;
 height: 300px;
 border-radius: 80px;
 border: dashed aqua;
 margin: 0;
 }
 #blueBox {
 width: 40px;
 height: 20px;
 background-color: blue;
 offset-path: margin-box;
 }
</style>
<body>
 <div id="blueBox"></div>
</body>
```

![The initial position is the left end of the top horizontal
line.](images/geometry-box.svg){a
height="270" width="470"}

### 2.2. Position On The Path: the [offset-distance property]
Name:

[offset-distance]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

0

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[transformable
elements](https://drafts.csswg.org/css-transforms-1/#transformable-element)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

relative to the [offset path](#offset-path) length

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

a computed
[\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage) value

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value

Media:

visual

Specifies where along the [offset
path](#offset-path) the [offset
position](#offset-position)
is.

[\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage)

: The [offset position](#offset-position) is the point that is the specified distance along
 the element's [offset path](#offset-path). See [§ 2.2.1 Calculating the computed distance
 along a path](#path-distance) for details about how to calculate
 distances along a path.

 Percentages are relative to the total length of the [offset
 path](#offset-path).

Tests

- [offset-distance-composition.html](https://wpt.fyi/results/css/motion/animation/offset-distance-composition.html "css/motion/animation/offset-distance-composition.html")
 [[(live
 test)]](http://wpt.live/css/motion/animation/offset-distance-composition.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/animation/offset-distance-composition.html)
- [offset-distance-interpolation.html](https://wpt.fyi/results/css/motion/animation/offset-distance-interpolation.html "css/motion/animation/offset-distance-interpolation.html")
 [[(live
 test)]](http://wpt.live/css/motion/animation/offset-distance-interpolation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/animation/offset-distance-interpolation.html)
- [offset-distance-interpolation-001.html](https://wpt.fyi/results/css/motion/animation/reftests/offset-distance-interpolation-001.html "css/motion/animation/reftests/offset-distance-interpolation-001.html")
 [[(live
 test)]](http://wpt.live/css/motion/animation/reftests/offset-distance-interpolation-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/animation/reftests/offset-distance-interpolation-001.html)
- [offset-distance-001.html](https://wpt.fyi/results/css/motion/offset-distance-001.html "css/motion/offset-distance-001.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-distance-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-distance-001.html)
- [offset-distance-002.html](https://wpt.fyi/results/css/motion/offset-distance-002.html "css/motion/offset-distance-002.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-distance-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-distance-002.html)
- [offset-distance-003.html](https://wpt.fyi/results/css/motion/offset-distance-003.html "css/motion/offset-distance-003.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-distance-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-distance-003.html)
- [offset-distance-004.html](https://wpt.fyi/results/css/motion/offset-distance-004.html "css/motion/offset-distance-004.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-distance-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-distance-004.html)
- [offset-distance-005.html](https://wpt.fyi/results/css/motion/offset-distance-005.html "css/motion/offset-distance-005.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-distance-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-distance-005.html)
- [offset-distance-006.html](https://wpt.fyi/results/css/motion/offset-distance-006.html "css/motion/offset-distance-006.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-distance-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-distance-006.html)
- [offset-distance-007.html](https://wpt.fyi/results/css/motion/offset-distance-007.html "css/motion/offset-distance-007.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-distance-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-distance-007.html)
- [offset-distance-008.html](https://wpt.fyi/results/css/motion/offset-distance-008.html "css/motion/offset-distance-008.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-distance-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-distance-008.html)
- [offset-distance-009.html](https://wpt.fyi/results/css/motion/offset-distance-009.html "css/motion/offset-distance-009.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-distance-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-distance-009.html)
- [offset-distance-computed.html](https://wpt.fyi/results/css/motion/parsing/offset-distance-computed.html "css/motion/parsing/offset-distance-computed.html")
 [[(live
 test)]](http://wpt.live/css/motion/parsing/offset-distance-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/parsing/offset-distance-computed.html)
- [offset-distance-parsing-invalid.html](https://wpt.fyi/results/css/motion/parsing/offset-distance-parsing-invalid.html "css/motion/parsing/offset-distance-parsing-invalid.html")
 [[(live
 test)]](http://wpt.live/css/motion/parsing/offset-distance-parsing-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/parsing/offset-distance-parsing-invalid.html)
- [offset-distance-parsing-valid.html](https://wpt.fyi/results/css/motion/parsing/offset-distance-parsing-valid.html "css/motion/parsing/offset-distance-parsing-valid.html")
 [[(live
 test)]](http://wpt.live/css/motion/parsing/offset-distance-parsing-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/parsing/offset-distance-parsing-valid.html)

 By animating the
[offset-distance](#propdef-offset-distance), an element can easily trace out a
complex path.

If the element does not have an [offset
path](#offset-path), this
property does nothing.

#### 2.2.1. Calculating the computed distance along a path

Processing the distance along an [offset
path](#offset-path) operates
differently depending upon the nature of the [offset
path]:

- References to
 [\<angle\>](https://drafts.csswg.org/css-values-4/#angle-value) [offset
 path](#offset-path)s with
 contain are unclosed intervals.

- References to
 [\<angle\>](https://drafts.csswg.org/css-values-4/#angle-value) [offset
 path](#offset-path)s without
 contain are unbounded rays.

- All basic CSS shapes are closed loops.

- [Offset path](#offset-path)s
 (including references to SVG Paths) are closed loops only if the final
 command in the path list is a closepath command (\"z\" or \"Z\"),
 otherwise they are unclosed intervals.

- References to SVG circles, ellipses, images, polygons and rects are
 closed loops.

- References to SVG lines and polylines are unclosed intervals.

To determine the [used offset distance] for a given [offset
path](#offset-path) and [offset
distance]:

1. Let the [total length] be the total length of [offset
 path](#offset-path) with all
 sub-paths.

2. Convert [offset distance](#offset-distance) to pixels, with 100% being converted to [total
 length](#total-length).

3.

 If [offset path](#offset-path) is an unbounded ray:

 : Let [used offset
 distance](#used-offset-distance) be equal to [offset
 distance](#offset-distance).

 Otherwise if [offset path](#offset-path) is an [\<angle\>](https://drafts.csswg.org/css-values-4/#angle-value) path with contain:

 : Let [used offset
 distance](#used-offset-distance) be equal to [offset
 distance](#offset-distance), clamped so that the box lies entirely within
 the path.

 If [offset path](#offset-path) is any other unclosed interval:

 : Let [used offset
 distance](#used-offset-distance) be equal to [offset
 distance](#offset-distance) clamped by 0 and the total length of the path.

 Otherwise [offset path](#offset-path) is a closed loop:

 : Let [used offset
 distance](#used-offset-distance) be equal to [offset
 distance](#offset-distance) modulo the total length of the path. If the
 total length of the path is 0, [used offset
 distance] is also 0.

 "Modulo" here uses the traditional mathematical
 definition, where the output is always non-negative.

This example shows boxes placed along
an unclosed interval.

``` highlight
<style>
 .item {
 width: 100px;
 height: 40px;
 offset-position: 0% 0%;
 offset-path: path('m 0 0 h 200 v 150');
 }
 #box1 {
 background-color: red;
 offset-distance: -280%;
 }
 #box2 {
 background-color: green;
 offset-distance: 190%;
 }
</style>
<body>
 <div class="item" id="box1"></div>
 <div class="item" id="box2"></div>
</body>
```

![An example of boxes placed along an unclosed
interval](images/offset-distance-unclosed.svg){height="270" width="700"}

This example shows boxes placed along
a closed interval.

``` highlight
<style>
 .item {
 width: 100px;
 height: 40px;
 offset-position: 0% 0%;
 offset-path: path('m 0 0 h 200 v 150 z');
 }
 #box1 {
 background-color: red;
 offset-distance: -280%;
 }
 #box2 {
 background-color: green;
 offset-distance: 190%;
 }
</style>
<body>
 <div class="item" id="box1"></div>
 <div class="item" id="box2"></div>
</body>
```

![An example of boxes placed along a closed
interval](images/offset-distance-closed.svg){height="270" width="700"}

This example shows a way to align
boxes within the polar coordinate system using
[offset-path](#propdef-offset-path),
[offset-distance](#propdef-offset-distance).

``` highlight
<style>
 body {
 transform-style: preserve-3d;
 width: 300px;
 height: 300px;
 border: dashed gray;
 border-radius: 50%;
 }
 .circleBox {
 position: absolute;
 left: 50%;
 top: 50%;
 width: 40px;
 height: 40px;
 background-color: red;
 border-radius: 50%;
 }
 #circle1 {
 offset-path: ray(0deg farthest-side);
 offset-distance: 50%;
 }
 #circle2 {
 offset-path: ray(90deg farthest-side);
 offset-distance: 20%;
 }
 #circle3 {
 offset-path: ray(225deg farthest-side);
 offset-distance: 100%;
 }
</style>
<body>
 <div class="circleBox" id="circle1"></div>
 <div class="circleBox" id="circle2"></div>
 <div class="circleBox" id="circle3"></div>
</body>
```

![An example of positioning box in polar
coordinates](images/simple_offset_position.png){a
height="300" width="300"}

### 2.3. Starting Point Of The Path: the [offset-position property]
Name:

[offset-position]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

normal
[\|](https://drafts.csswg.org/css-values-4/#comb-one) auto [\|]
[\<position\>](https://drafts.csswg.org/css-values-5/#typedef-position)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

normal

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[transformable
elements](https://drafts.csswg.org/css-transforms-1/#transformable-element)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

Refer to the size of containing block

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

The
[normal](#valdef-offset-position-normal) or
[auto](#valdef-offset-position-auto) keywords, or a computed
[\<position\>](https://drafts.csswg.org/css-values-5/#typedef-position)

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value

Media:

visual

Specifies the [offset starting position] that is used by the
[\<offset-path\>](#typedef-offset-path) functions if they don't specify their
own starting position.

Values are defined as follows:

[normal]

: The element does not have an [offset starting
 position](#offset-starting-position).

[auto]

: The [offset starting
 position](#offset-starting-position) is the top-left corner of the box.

 This is the top-left corner of the element's *own
 box*, not that of its [containing
 block](https://drafts.csswg.org/css-display-4/#containing-block)! It's completely different from specifiying [top
 left]. It's meant, for example, to allow a [path()] to
 start relative to the element's own position.

[[\<position\>](https://drafts.csswg.org/css-values-5/#typedef-position)]

: The [offset starting
 position](#offset-starting-position) is the result of using the
 [\<position\>](https://drafts.csswg.org/css-values-5/#typedef-position) to position a 0x0 object area
 within the box's [containing
 block](https://drafts.csswg.org/css-display-4/#containing-block).

Tests

- [offset-position-computed.html](https://wpt.fyi/results/css/motion/parsing/offset-position-computed.html "css/motion/parsing/offset-position-computed.html")
 [[(live
 test)]](http://wpt.live/css/motion/parsing/offset-position-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/parsing/offset-position-computed.html)
- [offset-position-parsing-invalid.html](https://wpt.fyi/results/css/motion/parsing/offset-position-parsing-invalid.html "css/motion/parsing/offset-position-parsing-invalid.html")
 [[(live
 test)]](http://wpt.live/css/motion/parsing/offset-position-parsing-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/parsing/offset-position-parsing-invalid.html)
- [offset-position-parsing-valid.html](https://wpt.fyi/results/css/motion/parsing/offset-position-parsing-valid.html "css/motion/parsing/offset-position-parsing-valid.html")
 [[(live
 test)]](http://wpt.live/css/motion/parsing/offset-position-parsing-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/parsing/offset-position-parsing-valid.html)

This example shows positioning a box
with
[offset-position](#propdef-offset-position).

``` highlight
<style>
 #wrap {
 position: relative;
 width: 300px;
 height: 300px;
 border: 1px solid black;
 }

 #box {
 width: 100px;
 height: 100px;
 background-color: green;
 position: absolute;
 top: 100px;
 left: 80px;
 offset-position: auto;
 offset-anchor: center;
 offset-path: ray(45deg);
 }
</style>
<body>
 <div id="wrap">
 <div id="box"></div>
 </div>
</body>
```

![An example when
[auto](#valdef-offset-position-auto) is given to
[offset-position](#propdef-offset-position)](images/offset_position_auto.png){a
height="279" width="300"}

This example shows the interaction
with the
[transform](https://drafts.csswg.org/css-transforms-1/#propdef-transform) property, and with an individual
transform property
([rotate](https://drafts.csswg.org/css-transforms-2/#propdef-rotate)). The motion path transform is a
vertical translation moving
([left](https://drafts.csswg.org/css-position-3/#propdef-left),
[top](https://drafts.csswg.org/css-position-3/#propdef-top)) to
[offset-position](#propdef-offset-position).

``` highlight
<style>
 #wrap {
 transform-style: preserve-3d;
 width: 400px;
 height: 350px;
 }
 .item {
 position: absolute;
 left: 200px;
 top: 0px;
 offset-position: 200px 100px; /* translates by 0px,100px */
 offset-anchor: left top;
 transform-origin: left top;
 width: 130px;
 height: 80px;
 border-top-right-radius: 23px;
 }
 #box1 {
 background-color: tomato;
 offset-position: auto;
 }
 #box2 {
 background-color: green;
 }
 #box3 {
 background-color: navy;
 rotate: 90deg; /* applied before motion path transform */
 }
 #box4 {
 background-color: gold;
 transform: rotate(90deg); /* applied after motion path transform */
 }
</style>
<body>
 <div id="wrap">
 <div class="item" id="box1"></div>
 <div class="item" id="box2"></div>
 <div class="item" id="box3"></div>
 <div class="item" id="box4"></div>
 </div>
</body>
```

![An example when motion path and other transforms
interact](images/position-transform.svg){height="350" width="400"}

This example uses
[position](https://drafts.csswg.org/css-position-3/#propdef-position)
[static](https://drafts.csswg.org/css-position-3/#valdef-position-static), so
[offset-position](#propdef-offset-position) generates translations from the
normal flow positions. By amplifying these translations using
[scale](https://drafts.csswg.org/css-transforms-2/#propdef-scale), the normal flow is rotated 180
degrees around the [offset-position], and the boxes are exploded away from each other.

``` highlight
<style>
 #wrap {
 transform-style: preserve-3d;
 width: 500px;
 height: 250px;
 line-height: 0px;
 }
 span {
 position: static;
 display: inline-block;
 width: 100px;
 height: 50px;
 border-top-right-radius: 23px;
 scale: 2.5 2.5; /* applied before motion path transform */
 offset-position: center;
 transform: scale(0.4); /* applied after motion path transform */
 }
 #box1 {
 background-color: tomato;
 }
 #box2 {
 background-color: green;
 }
 #box3 {
 background-color: navy;
 }
 #box4 {
 background-color: gold;
 }
</style>
<body>
 <div id="wrap">
 <div>
 <span id="box1"></span><span id="box2"></span>
 </div>
 <div>
 <span id="box3"></span><span id="box4"></span>
 </div>
 </div>
</body>
```

![An example when motion path and scale
interact](images/position-scale.svg){height="304" width="604"}

In this example, each
[offset-position](#propdef-offset-position) value is ignored as
[offset-path](#propdef-offset-path) is a
[\<geometry-box\>](https://drafts.csswg.org/css-masking-1/#typedef-geometry-box), but the other offset properties
combine to have an effect equivalent to that for
[offset-position] \'right
bottom\'.

``` highlight
<style>
 #wrap {
 transform-style: preserve-3d;
 width: 540px;
 height: 420px;
 }
 .item {
 position: absolute;
 width: 90px;
 height: 70px;
 border-top-right-radius: 23px;
 scale: 0.8 0.8; /* applied before motion path transform */
 offset-path: padding-box;
 offset-distance: 50%;
 offset-rotate: 0deg;
 offset-anchor: right bottom;
 transform: scale(1.25); /* applied after motion path transform */
 }
 #box1 {
 background-color: tomato;
 position: static;
 offset-position: auto; /* ignored */
 }
 #box2 {
 background-color: green;
 right: 0px;
 top: 0px;
 offset-position: 23% 45%; /* ignored */
 }
 #box3 {
 background-color: navy;
 left: 0px;
 bottom: 0px;
 offset-position: 34% 56px; /* ignored */
 }
 #box4 {
 background-color: gold;
 right: 0px;
 bottom: 0px;
 offset-position: 45px 67px; /* ignored */
 }
</style>
<body>
 <div id="wrap">
 <div class="item" id="box1"></div>
 <div class="item" id="box2"></div>
 <div class="item" id="box3"></div>
 <div class="item" id="box4"></div>
 </div>
</body>
```

![An example when offset-position is
ignored](images/position-absolute.svg){height="430" width="550"}

### 2.4. The Element's Anchor Point: the [offset-anchor property]
Name:

[offset-anchor]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

auto
[\|](https://drafts.csswg.org/css-values-4/#comb-one)
[\<position\>](https://drafts.csswg.org/css-values-5/#typedef-position)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

auto

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[transformable
elements](https://drafts.csswg.org/css-transforms-1/#transformable-element)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

relative to the width and the height of the element's [reference
box](https://drafts.csswg.org/css-shapes-1/#basic-shape-reference-box)

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

the
[auto](#valdef-offset-anchor-auto) keyword or a computed
[\<position\>](https://drafts.csswg.org/css-values-5/#typedef-position)

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value

Media:

visual

Defines the element's [offset anchor point]---​the
point that is aligned with the [offset
position](#offset-position)
along the [offset path](#offset-path).

Values have the following meanings:

[auto]

: The [anchor
 point](#offset-anchor-point) is the same as the point indicated by
 [transform-origin](https://drafts.csswg.org/css-transforms-1/#propdef-transform-origin).

 Specifically, the [computed
 value](https://drafts.csswg.org/css-cascade-5/#computed-value) of
 [transform-origin](https://drafts.csswg.org/css-transforms-1/#propdef-transform-origin) is resolved as a
 [\<position\>](https://drafts.csswg.org/css-values-5/#typedef-position) against the element's [reference
 box](https://drafts.csswg.org/css-shapes-1/#basic-shape-reference-box).

[[\<position\>](https://drafts.csswg.org/css-values-5/#typedef-position)]

: The [anchor
 point](#offset-anchor-point) is the result of resolving the
 [\<position\>](https://drafts.csswg.org/css-values-5/#typedef-position) against the element's [reference
 box](https://drafts.csswg.org/css-shapes-1/#basic-shape-reference-box).

Tests

- [offset-anchor-composition.html](https://wpt.fyi/results/css/motion/animation/offset-anchor-composition.html "css/motion/animation/offset-anchor-composition.html")
 [[(live
 test)]](http://wpt.live/css/motion/animation/offset-anchor-composition.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/animation/offset-anchor-composition.html)
- [offset-anchor-interpolation.html](https://wpt.fyi/results/css/motion/animation/offset-anchor-interpolation.html "css/motion/animation/offset-anchor-interpolation.html")
 [[(live
 test)]](http://wpt.live/css/motion/animation/offset-anchor-interpolation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/animation/offset-anchor-interpolation.html)
- [offset-anchor-transform-box-fill-box-001.html](https://wpt.fyi/results/css/motion/offset-anchor-transform-box-fill-box-001.html "css/motion/offset-anchor-transform-box-fill-box-001.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-anchor-transform-box-fill-box-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-anchor-transform-box-fill-box-001.html)
- [offset-anchor-transform-box-fill-box-002.html](https://wpt.fyi/results/css/motion/offset-anchor-transform-box-fill-box-002.html "css/motion/offset-anchor-transform-box-fill-box-002.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-anchor-transform-box-fill-box-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-anchor-transform-box-fill-box-002.html)
- [offset-anchor-transform-box-fill-box-003.html](https://wpt.fyi/results/css/motion/offset-anchor-transform-box-fill-box-003.html "css/motion/offset-anchor-transform-box-fill-box-003.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-anchor-transform-box-fill-box-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-anchor-transform-box-fill-box-003.html)
- [offset-anchor-computed.html](https://wpt.fyi/results/css/motion/parsing/offset-anchor-computed.html "css/motion/parsing/offset-anchor-computed.html")
 [[(live
 test)]](http://wpt.live/css/motion/parsing/offset-anchor-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/parsing/offset-anchor-computed.html)
- [offset-anchor-parsing-invalid.html](https://wpt.fyi/results/css/motion/parsing/offset-anchor-parsing-invalid.html "css/motion/parsing/offset-anchor-parsing-invalid.html")
 [[(live
 test)]](http://wpt.live/css/motion/parsing/offset-anchor-parsing-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/parsing/offset-anchor-parsing-invalid.html)
- [offset-anchor-parsing-valid.html](https://wpt.fyi/results/css/motion/parsing/offset-anchor-parsing-valid.html "css/motion/parsing/offset-anchor-parsing-valid.html")
 [[(live
 test)]](http://wpt.live/css/motion/parsing/offset-anchor-parsing-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/parsing/offset-anchor-parsing-valid.html)

Which box this is resolved against is
being discussed in [Issue
503](https://github.com/w3c/fxtf-drafts/issues/503).

The following explains how to set the
[anchor point](#offset-anchor-point) of the box.

``` highlight
#plane {
 offset-anchor: center;
}
```

The red dot in the middle of the shape indicates the [anchor
point](#offset-anchor-point) of the shape.

![A red dot in the middle of a plane shape indicates the shape's [anchor
point](#offset-anchor-point).](images/plane.svg){a
height="140" width="160"}

This example shows an alignment of
four boxes with different [anchor
point](#offset-anchor-point)s.

``` highlight
<style>
 body {
 transform-style: preserve-3d;
 width: 300px;
 height: 300px;
 border: 2px solid gray;
 border-radius: 50%;
 }
 .box {
 width: 50px;
 height: 50px;
 background-color: orange;
 offset-position: 50% 50%;
 offset-distance: 100%;
 offset-rotate: 0deg;
 }
 #item1 {
 offset-path: ray(45deg closest-side);
 offset-anchor: right top;
 }
 #item2 {
 offset-path: ray(135deg closest-side);
 offset-anchor: right bottom;
 }
 #item3 {
 offset-path: ray(225deg closest-side);
 offset-anchor: left bottom;
 }
 #item4 {
 offset-path: ray(315deg closest-side);
 offset-anchor: left top;
 }
</style>
<body>
 <div class="box" id="item1"></div>
 <div class="box" id="item2"></div>
 <div class="box" id="item3"></div>
 <div class="box" id="item4"></div>
</body>
```

![An example of
[offset-anchor](#propdef-offset-anchor)](images/offset_anchor.png){height="300"
width="300"}

This example shows boxes centered at
their offset-position.

``` highlight
<style>
 body {
 width: 500px;
 height: 500px;
 }
 .box {
 background-color: mediumpurple;
 offset-path: none;
 offset-anchor: center;
 }
 #item1 {
 offset-position: 90% 20%;
 width: 60%;
 height: 20%;
 }
 #item2 {
 offset-position: 100% 100%;
 width: 30%;
 height: 10%;
 }
 #item3 {
 offset-position: 50% 100%;
 width: 20%;
 height: 60%;
 }
 #item4 {
 offset-position: 0% 100%;
 width: 30%;
 height: 90%;
 }
</style>
<body>
 <div class="box" id="item1"></div>
 <div class="box" id="item2"></div>
 <div class="box" id="item3"></div>
 <div class="box" id="item4"></div>
</body>
```

![An example of \'offset-anchor:
center\'](images/offset_anchor_center.svg){a
height="790" width="700"}

This example shows how offset-anchor
computes to their offset-position.

``` highlight
<style>
 body {
 width: 500px;
 height: 500px;
 }
 .box {
 background-color: mediumpurple;
 offset-path: none;
 offset-anchor: auto;
 }
 #item1 {
 offset-position: 90% 20%;
 width: 60%;
 height: 20%;
 }
 #item2 {
 offset-position: 100% 100%;
 width: 30%;
 height: 10%;
 }
 #item3 {
 offset-position: 50% 100%;
 width: 20%;
 height: 60%;
 }
 #item4 {
 offset-position: 0% 100%;
 width: 30%;
 height: 90%;
 }
</style>
<body>
 <div class="box" id="item1"></div>
 <div class="box" id="item2"></div>
 <div class="box" id="item3"></div>
 <div class="box" id="item4"></div>
</body>
```

![An example of \'offset-anchor:
auto\'](images/offset_anchor_auto.svg){a
height="570" width="700"}

### 2.5. Rotating To Match The Path: the [offset-rotate property]
Name:

[offset-rotate]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

\[ auto
[\|](https://drafts.csswg.org/css-values-4/#comb-one) reverse \]
[\|\|](https://drafts.csswg.org/css-values-4/#comb-any)
[\<angle\>](https://drafts.csswg.org/css-values-4/#angle-value)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

auto

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[transformable
elements](https://drafts.csswg.org/css-transforms-1/#transformable-element)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

computed
[\<angle\>](https://drafts.csswg.org/css-values-4/#angle-value) value, optionally preceded by auto

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value

Media:

visual

Defines a rotation component of the [offset
transform](#offset-transform), possibly based on the direction of the [offset
path](#offset-path) at the
[offset position](#offset-position). Values have the following meanings:

[auto [\<angle\>](https://drafts.csswg.org/css-values-4/#angle-value)?]

: The [offset transform](#offset-transform) will have a rotation component equal to the
 difference between the [offset
 path's](#offset-path)
 direction at the [offset
 position](#offset-position) and the direction of the positive X axis (that is,
 a line going toward the right). See SVG's [direction of a
 path](https://w3c.github.io/svgwg/svg2-draft/paths.html#TermPathDirection) for details on how to calculate this.

 If specified with an
 [\<angle\>](https://drafts.csswg.org/css-values-4/#angle-value), the angle is added to the
 rotation component.

 In other words, if the [offset
 path](#offset-path) is
 moving to the right,
 [auto](#valdef-offset-rotate-auto) doesn't add any rotation. As it diverges
 from straight rightward, the rotation matches. By combining
 [auto] with an
 [\<angle\>](https://drafts.csswg.org/css-values-4/#angle-value), you can adjust the \"starting\"
 rotation.

[reverse [\<angle\>](https://drafts.csswg.org/css-values-4/#angle-value)?]

: Identical to
 [auto](#valdef-offset-rotate-auto), but adds an additional [180deg] to
 the rotation.

[[\<angle\>](https://drafts.csswg.org/css-values-4/#angle-value)]

: When specified on its own, adds a rotation component to the [offset
 transform](#offset-transform) of the specified angle. (That is, [offset-rotate:
 45deg;](#propdef-offset-rotate) is similar to [transform:
 rotate(45deg)](https://drafts.csswg.org/css-transforms-1/#propdef-transform); it's just ordered to be part of the
 [offset transform].)

Tests

- [offset-rotate-composition.html](https://wpt.fyi/results/css/motion/animation/offset-rotate-composition.html "css/motion/animation/offset-rotate-composition.html")
 [[(live
 test)]](http://wpt.live/css/motion/animation/offset-rotate-composition.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/animation/offset-rotate-composition.html)
- [offset-rotate-interpolation-math-functions.html](https://wpt.fyi/results/css/motion/animation/offset-rotate-interpolation-math-functions.html "css/motion/animation/offset-rotate-interpolation-math-functions.html")
 [[(live
 test)]](http://wpt.live/css/motion/animation/offset-rotate-interpolation-math-functions.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/animation/offset-rotate-interpolation-math-functions.html)
- [offset-rotate-interpolation.html](https://wpt.fyi/results/css/motion/animation/offset-rotate-interpolation.html "css/motion/animation/offset-rotate-interpolation.html")
 [[(live
 test)]](http://wpt.live/css/motion/animation/offset-rotate-interpolation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/animation/offset-rotate-interpolation.html)
- [offset-rotate-interpolation-001.html](https://wpt.fyi/results/css/motion/animation/reftests/offset-rotate-interpolation-001.html "css/motion/animation/reftests/offset-rotate-interpolation-001.html")
 [[(live
 test)]](http://wpt.live/css/motion/animation/reftests/offset-rotate-interpolation-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/animation/reftests/offset-rotate-interpolation-001.html)
- [offset-rotate-001.html](https://wpt.fyi/results/css/motion/offset-rotate-001.html "css/motion/offset-rotate-001.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-rotate-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-rotate-001.html)
- [offset-rotate-002.html](https://wpt.fyi/results/css/motion/offset-rotate-002.html "css/motion/offset-rotate-002.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-rotate-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-rotate-002.html)
- [offset-rotate-003.html](https://wpt.fyi/results/css/motion/offset-rotate-003.html "css/motion/offset-rotate-003.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-rotate-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-rotate-003.html)
- [offset-rotate-004.html](https://wpt.fyi/results/css/motion/offset-rotate-004.html "css/motion/offset-rotate-004.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-rotate-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-rotate-004.html)
- [offset-rotate-005.html](https://wpt.fyi/results/css/motion/offset-rotate-005.html "css/motion/offset-rotate-005.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-rotate-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-rotate-005.html)
- [offset-rotate-computed.html](https://wpt.fyi/results/css/motion/parsing/offset-rotate-computed.html "css/motion/parsing/offset-rotate-computed.html")
 [[(live
 test)]](http://wpt.live/css/motion/parsing/offset-rotate-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/parsing/offset-rotate-computed.html)
- [offset-rotate-parsing-invalid.html](https://wpt.fyi/results/css/motion/parsing/offset-rotate-parsing-invalid.html "css/motion/parsing/offset-rotate-parsing-invalid.html")
 [[(live
 test)]](http://wpt.live/css/motion/parsing/offset-rotate-parsing-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/parsing/offset-rotate-parsing-invalid.html)
- [offset-rotate-parsing-valid.html](https://wpt.fyi/results/css/motion/parsing/offset-rotate-parsing-valid.html "css/motion/parsing/offset-rotate-parsing-valid.html")
 [[(live
 test)]](http://wpt.live/css/motion/parsing/offset-rotate-parsing-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/parsing/offset-rotate-parsing-valid.html)

The following examples use the shape
of a plane. The red dot in the middle of the shape indicates the [anchor
point](#offset-anchor-point) of the shape. When no offset properties are set, the
shape is not translated or rotated along the path.

![A black plane at the beginning of the path, with no offset properties
set.](images/offset-initial.svg){a height="120"
width="470"}

When the shape's [anchor
point](#offset-anchor-point) is placed at different positions along the path and
[offset-rotate](#propdef-offset-rotate) is [0deg], the shape is not
rotated.

![A black plane at different positions on a blue dotted path without
rotation
transforms.](images/offset-rotate-none.svg){a
height="120" width="470"}

If the
[offset-rotate](#propdef-offset-rotate) property is set to
[auto](#valdef-offset-rotate-auto), and the shape's [anchor
point](#offset-anchor-point) is placed at different positions along the path, the
shape is rotated based on the gradient at the current position and faces
the direction of the path at this position.

![A black plane at different positions on a blue dotted path, rotated in
the direction of the
path.](images/offset-rotate-auto.svg){a
height="120" width="470"}

In this example, the
[offset-rotate](#propdef-offset-rotate) property is set to
[reverse](#valdef-offset-rotate-reverse). The plane faces the opposite direction of the
path at each position on the path.

![A black plane at different positions on a blue dotted path, rotated in
the opposite direction of the
path.](images/offset-rotate-reverse.svg){a
height="120" width="470"}

The last example sets the
[offset-rotate](#propdef-offset-rotate) property to [-45deg]. The
shape is rotated anticlockwise by 45 degree once and keeps the rotation
at each position on the path.

![A black plane at different positions on a blue dotted path, rotated by
a fixed amount of
degree.](images/offset-rotate-45.svg){a
height="120" width="470"}

This example shows how
[auto](#valdef-offset-rotate-auto) or
[reverse](#valdef-offset-rotate-reverse) work when specified in combination with
[\<angle\>](https://drafts.csswg.org/css-values-4/#angle-value). The computed value of
[\<angle\>] is added to the computed
value of [auto] or
[reverse].

``` highlight
<style>
 body {
 width: 300px;
 height: 300px;
 margin: 0px;
 border: solid gray;
 border-radius: 50%;
 }
 .circle {
 offset-position: 150px 150px;
 offset-distance: 86%;
 width: 42px;
 height: 42px;
 background-color: mediumpurple;
 border-radius: 50%;
 display: flex;
 align-items: center;
 justify-content: center;
 }
 #item1 {
 offset-path: ray(0deg closest-side);
 offset-rotate: auto 90deg;
 }
 #item2 {
 offset-path: ray(45deg closest-side);
 offset-rotate: auto 90deg;
 }
 #item3 {
 offset-path: ray(135deg closest-side);
 offset-rotate: auto -90deg;
 }
 #item4 {
 offset-path: ray(180deg closest-side);
 offset-rotate: auto -90deg;
 }
 #item5 {
 offset-path: ray(225deg closest-side);
 offset-rotate: reverse 90deg;
 }
 #item6 {
 offset-path: ray(-45deg closest-side);
 offset-rotate: reverse -90deg;
 }
</style>
<body>
 <div class="circle" id="item1">1</div>
 <div class="circle" id="item2">2</div>
 <div class="circle" id="item3">3</div>
 <div class="circle" id="item4">4</div>
 <div class="circle" id="item5">5</div>
 <div class="circle" id="item6">6</div>
</body>
```

![The boxes are rotated by the value of
[auto](#valdef-offset-rotate-auto) with a fixed amount of
degree.](images/rotate_by_angle_with_auto.png){a
height="250" width="250"}

### 2.6. The [offset Shorthand]
Name:

[offset]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

\[
[\<\'offset-position\'\>](#propdef-offset-position)[?](https://drafts.csswg.org/css-values-4/#mult-opt) \[
[\<\'offset-path\'\>](#propdef-offset-path) \[
[\<\'offset-distance\'\>](#propdef-offset-distance)
[\|\|](https://drafts.csswg.org/css-values-4/#comb-any)
[\<\'offset-rotate\'\>](#propdef-offset-rotate) \][?]
\][?]
\][!](https://drafts.csswg.org/css-values-4/#mult-req) [\[ /
[\<\'offset-anchor\'\>](#propdef-offset-anchor)
\][?](https://drafts.csswg.org/css-values-4/#mult-opt)]{style=";white-space:nowrap"}

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

see individual properties

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[transformable
elements](https://drafts.csswg.org/css-transforms-1/#transformable-element)

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

- [offset-interpolation.html](https://wpt.fyi/results/css/motion/animation/offset-interpolation.html "css/motion/animation/offset-interpolation.html")
 [[(live
 test)]](http://wpt.live/css/motion/animation/offset-interpolation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/animation/offset-interpolation.html)
- [offset-position-composition.html](https://wpt.fyi/results/css/motion/animation/offset-position-composition.html "css/motion/animation/offset-position-composition.html")
 [[(live
 test)]](http://wpt.live/css/motion/animation/offset-position-composition.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/animation/offset-position-composition.html)
- [offset-position-interpolation.html](https://wpt.fyi/results/css/motion/animation/offset-position-interpolation.html "css/motion/animation/offset-position-interpolation.html")
 [[(live
 test)]](http://wpt.live/css/motion/animation/offset-position-interpolation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/animation/offset-position-interpolation.html)
- [offset-parsing-invalid.html](https://wpt.fyi/results/css/motion/parsing/offset-parsing-invalid.html "css/motion/parsing/offset-parsing-invalid.html")
 [[(live
 test)]](http://wpt.live/css/motion/parsing/offset-parsing-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/parsing/offset-parsing-invalid.html)
- [offset-parsing-valid.html](https://wpt.fyi/results/css/motion/parsing/offset-parsing-valid.html "css/motion/parsing/offset-parsing-valid.html")
 [[(live
 test)]](http://wpt.live/css/motion/parsing/offset-parsing-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/parsing/offset-parsing-valid.html)
- [offset-shorthand.html](https://wpt.fyi/results/css/motion/parsing/offset-shorthand.html "css/motion/parsing/offset-shorthand.html")
 [[(live
 test)]](http://wpt.live/css/motion/parsing/offset-shorthand.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/parsing/offset-shorthand.html)
- [inheritance.html](https://wpt.fyi/results/css/motion/inheritance.html "css/motion/inheritance.html")
 [[(live
 test)]](http://wpt.live/css/motion/inheritance.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/inheritance.html)
- [offset-supports-calc.html](https://wpt.fyi/results/css/motion/offset-supports-calc.html "css/motion/offset-supports-calc.html")
 [[(live
 test)]](http://wpt.live/css/motion/offset-supports-calc.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/motion/offset-supports-calc.html)

This is a shorthand property for setting
[offset-position](#propdef-offset-position),
[offset-path](#propdef-offset-path),
[offset-distance](#propdef-offset-distance),
[offset-rotate](#propdef-offset-rotate) and
[offset-anchor](#propdef-offset-anchor). Omitted values are set to their
initial values.

### 2.7. Calculating The Offset Transform

The [offset transform](#offset-transform) is a 2d transform, a translation followed by a
rotation:

- Translate the element by the (X, Y) that aligns its [anchor
 point](#offset-anchor-point) with its [offset
 position](#offset-position).

- Rotate the element by the angle specified by
 [offset-rotate](#propdef-offset-rotate).

## [3. ][Equivalent Paths For [\<basic-shape\>](https://drafts.csswg.org/css-shapes-1/#typedef-basic-shape)]
The
[\<basic-shape\>](https://drafts.csswg.org/css-shapes-1/#typedef-basic-shape) definition given by
[\[css-shapes\]](#biblio-css-shapes "CSS Shapes Module Level 1")
defines each function as producing a *shape*---​a 2-dimensional figure
with an outline, an inside, and an outside.

This specification instead uses
[\<basic-shape\>](https://drafts.csswg.org/css-shapes-1/#typedef-basic-shape) as producing a *path*---​a line with a
starting point, ending point, and direction, that happens to trace out a
particular shape's outline. The details of what makes up a path are
defined by SVG.
[\[SVG2\]](#biblio-svg2 "Scalable Vector Graphics (SVG) 2")

The [equivalent path] for all the
[\<basic-shape\>](https://drafts.csswg.org/css-shapes-1/#typedef-basic-shape) values are:

[[\<path()\>](https://drafts.csswg.org/css-shapes-1/#funcdef-basic-shape-path)]\
[[\<shape()\>](https://drafts.csswg.org/css-shapes-1/#funcdef-basic-shape-shape)]

: The path is the defined path.
 [\[SVG11\]](#biblio-svg11 "Scalable Vector Graphics (SVG) 1.1 (Second Edition)")

[[\<circle()\>](https://drafts.csswg.org/css-shapes-1/#funcdef-basic-shape-circle)]\
[[\<ellipse()\>](https://drafts.csswg.org/css-shapes-1/#funcdef-basic-shape-ellipse)]

: The path is the outline of the circle/ellipse. It starts at the
 rightmost point of the circle/ellipse, and then is composed of four
 circular arcs, each comprising a quarter of the circle/ellipse,
 proceeding clockwise, ending with a [segment-completing close
 path] operation.

[rect()]\
[inset()]\
[xywh()]

: The path is the outline of the (possibly-rounded) rectangle,
 composed of four or eight segments (depending on whether rounded
 corners are specified or not), and ending with a [segment-completing
 close path] operation. It starts at the left end of the
 top straight edge, immediately to the right of any rounded corners,
 and continues to the right (clockwise).

[[\<polygon()\>](https://drafts.csswg.org/css-shapes-1/#funcdef-basic-shape-polygon)]

: The path is the outline of the polygon, composed of straight line
 segments connecting each coordinate pair to the following coordinate
 pair, and finally connecting the last back to the first, with a
 [segment-completing close path] operation.

For all of these, the direction at any point along the path is defined
by SVG; see [SVG 2 § 9.4 Path
directionality](https://w3c.github.io/svgwg/svg2-draft/paths.html#PathDirectionality).

 All of these are meant to match the \"equivalent
paths\" defined for the similar SVG [shape
elements](https://w3c.github.io/svgwg/svg2-draft/shapes.html#TermShapeElement).

 This list should be in sync with the full set of
[\<basic-shape\>](https://drafts.csswg.org/css-shapes-1/#typedef-basic-shape) functions defined in
[\[css-shapes\]](#biblio-css-shapes "CSS Shapes Module Level 1").
If anything is missing, this should be considered a specification bug.
This list might move to Shapes in the future, but for now is kept here
as this spec is the only consumer of this information.

## 4. Privacy Considerations

This specification introduces no new privacy considerations.

## 5. Security Considerations

This specification introduces no new security considerations.

## [Changes]
*This section is non-normative.*

### [Changes since the [18 December 2018](https://www.w3.org/TR/2018/WD-motion-1-20181218/) Working Draft]
- Added offset-position:normal that doesn't override the normal position
 defaulting, and add an \"at \<position\>\"\" to ray()
 [#504](https://github.com/w3c/fxtf-drafts/issues/504).

- Corrected offset-path to use \<url\> instead of \<url()\>
 [#508](https://github.com/w3c/fxtf-drafts/issues/508)

- Reworded the calculation of the offset transform, using terminology
 from CSS Transforms 1

- Clarified \"offset-distance\" and \"offset-rotate\"

- Simplified and clarified the behavior of the \"contain\" keyword
 [#363](https://github.com/w3c/fxtf-drafts/issues/363).

- Changed the equivalent path of a circle()/ellipse() to match SVG
 [#506](https://github.com/w3c/fxtf-drafts/issues/506).

- The element being referenced by coord-box is the element establishing
 the containing block for the transformed element, and in an SVG
 context coord-box is treated as view-box
 [#369](https://github.com/w3c/fxtf-drafts/issues/369#issuecomment-1457239856)

- Moved the definition of \<basic-shape\> paths to an appendix.

- Allowed \<coord-box\> to be combined with any of the path functions
 [#369](https://github.com/w3c/fxtf-drafts/issues/369#issuecomment-577787797)

- Added inline links to some issues:
 [#503](https://github.com/w3c/fxtf-drafts/issues/503),
 [#504](https://github.com/w3c/fxtf-drafts/issues/504)

- Clarified initial position

- Moved path() to the \<basic-shape\> section.

- Made \<ray-size\> optional, defaulting to \"closest-side\".

- Rewrote introduction.

- Moved ray() definition to its own subsection

- Clarified definition of offset path
 [#66](https://github.com/w3c/fxtf-drafts/issues/66)

- Clarified that the \<coord-box\> tpe is defined in CSS Box 3.

- Corrected \<ray()\> and \<path()\> type syntax.

- Clarified that \"modulo\" has its mathematical, not C/JS definition
 [#339](https://github.com/w3c/fxtf-drafts/issues/339).

- Fixed directionality at sharp path boundaries to match SVG.
 [#209](https://github.com/w3c/fxtf-drafts/issues/209).

- Reorganized offset-path section for better readability.

- Removed note describing the concept of polar angles.

- Changed computed value of offset-distance to a computed
 [\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage) value.

- Replaced animatable by Animation type.

### [Changes since the [9 April 2015](https://www.w3.org/TR/2015/WD-motion-1-20150409/) First Public Working Draft]
- Renamed
 [motion-path](https://www.w3.org/TR/2015/WD-motion-1-20150409/#motion-path-property)
 to [offset-path](#propdef-offset-path) for integrating with
 [polar-angle](https://www.w3.org/TR/2016/WD-css-round-display-1-20160301/#polar-angle-property).

 - Added the [ray()](#funcdef-ray) to define an [offset
 path](#offset-path) as a
 line segment which direction is specified by
 [\<angle\>](https://drafts.csswg.org/css-values-4/#angle-value).

 - Added [\<ray-size\>](#typedef-ray-size) and
 [contain](https://drafts.csswg.org/css-contain-2/#propdef-contain) value to
 [ray()](#funcdef-ray).

- Renamed
 [motion-offset](https://www.w3.org/TR/2015/WD-motion-1-20150409/#propdef-motion-offset)
 to
 [offset-distance](#propdef-offset-distance) for integrating with
 [polar-distance](https://www.w3.org/TR/2016/WD-css-round-display-1-20160301/#polar-distance-property).

- Renamed
 [motion-rotation](https://www.w3.org/TR/2015/WD-motion-1-20150409/#propdef-motion-rotation)
 to
 [offset-rotate](#propdef-offset-rotate).

- Added
 [offset-position](#propdef-offset-position) to specify the [offset starting
 position](#offset-starting-position) of the path by merging
 [polar-origin](https://www.w3.org/TR/2016/WD-css-round-display-1-20160301/#polar-origin-property)
 from
 [\[CSS-ROUND-DISPLAY-1\]](#biblio-css-round-display-1 "CSS Round Display Level 1").

- Added
 [offset-anchor](#propdef-offset-anchor) to specify the origin point of
 the element by merging
 [polar-anchor](https://www.w3.org/TR/2016/WD-css-round-display-1-20160301/#polar-anchor-property)
 from
 [\[CSS-ROUND-DISPLAY-1\]](#biblio-css-round-display-1 "CSS Round Display Level 1").

- Renamed the shorthand property
 [motion](https://www.w3.org/TR/2015/WD-motion-1-20150409/#propdef-motion)
 to [offset](#propdef-offset).

- Made
 [offset-rotate](#propdef-offset-rotate) specify the rotation
 transformation by
 [auto](#valdef-offset-rotate-auto) or
 [reverse](#valdef-offset-rotate-reverse) in combination with
 [\<angle\>](https://drafts.csswg.org/css-values-4/#angle-value).

## [Acknowledgments]
Thanks to fantasai, Hyojin Song, and all the rest of the CSS WG members
for their reviews, comments, and corrections.
