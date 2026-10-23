## 1. Introduction

This module describes CSS properties which enable authors to style user
interface related properties and values.

[Section 2.1 of
CSS1](https://www.w3.org/TR/REC-CSS1#anchor-pseudo-classes)
[\[CSS1\]](#biblio-css1 "Cascading Style Sheets, level 1")
and [Chapter 18 of CSS2](https://www.w3.org/TR/CSS2/ui.html)
[\[CSS21\]](#biblio-css21 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")
introduced several user interface related properties and values. [User
Interface for CSS3 (16 February
2000)](https://www.w3.org/TR/2000/WD-css3-userint-20000216) introduced
several new user interface related features.

[\[CSS-UI-3\]](#biblio-css-ui-3 "CSS Basic User Interface Module Level 3 (CSS3 UI)")
was later introduced to incorporate, extend, and supersede these. This
specification continues this work, and in turn replaces
[\[CSS-UI-3\]](#biblio-css-ui-3 "CSS Basic User Interface Module Level 3 (CSS3 UI)").

### 1.1. Purpose

The purpose of this specification is to achieve the following
objectives:

- Extend the user interface features in
 [\[CSS21\]](#biblio-css21 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")
 and
 [\[CSS-UI-3\]](#biblio-css-ui-3 "CSS Basic User Interface Module Level 3 (CSS3 UI)")
- Provide additional CSS mechanisms to augment or replace other dynamic
 presentation related features in HTML.
- Introduce directional navigation properties to assist in the
 construction of user interfaces which make use of a directional
 navigation model.

## 2. Module Interactions

This document defines new features not present in earlier
specifications. In addition, it replaces and supersedes
[\[CSS-UI-3\]](#biblio-css-ui-3 "CSS Basic User Interface Module Level 3 (CSS3 UI)"),
which itself replaced and superseded the following:

- [Section 18.1](https://www.w3.org/TR/CSS21/ui.html#cursor-props),
 [section 18.4](https://www.w3.org/TR/CSS21/ui.html#dynamic-outlines),
 and Information on the stacking of outlines defined in [Appendix
 E](https://www.w3.org/TR/CSS21/zindex.html) of Cascading Style Sheets,
 level 2, revision 1
 [\[CSS21\]](#biblio-css21 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")
- [User Interface for CSS3 (16 February
 2000)](https://www.w3.org/TR/2000/WD-css3-userint-20000216)
 [\[CSS-UI-3\]](#biblio-css-ui-3 "CSS Basic User Interface Module Level 3 (CSS3 UI)")

 The
[box-sizing](https://www.w3.org/TR/css-sizing-3/#propdef-box-sizing) property was previously defined in
this section of the specification, but has been moved to [CSS Sizing 3
§ 3.3 Box Edges for Sizing: the box-sizing
property](https://www.w3.org/TR/css-sizing-3/#box-sizing).

 The
[text-overflow](https://www.w3.org/TR/css-overflow-4/#propdef-text-overflow) property was previously defined in
this section of the specification, but has been moved to [CSS Overflow 3
§ 5.1 Overflow Ellipsis: the text-overflow
property](https://www.w3.org/TR/css-overflow-3/#text-overflow).

### 2.1. Value Definitions

This specification follows the [CSS property definition
conventions](https://www.w3.org/TR/CSS2/about.html#property-defs) from
[\[CSS21\]](#biblio-css21 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")
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
keywords](https://www.w3.org/TR/css-values-4/#css-wide-keywords) as their property value. For readability they have not
been repeated explicitly.

## 3. Outline properties

At times, style sheet authors may want to create outlines around visual
objects such as buttons, active form fields, image maps, etc., to make
them stand out. Outlines differ from borders in the following ways:

1. Outlines do not take up space.
2. Outlines contribute to the [ink overflow
 area](https://www.w3.org/TR/css-overflow-3/#ink-overflow-region) of an element.
3. Outlines may be non-rectangular.
4. UAs often render outlines on elements in the
 [:focus-visible](https://www.w3.org/TR/selectors-4/#focus-visible-pseudo) state.

The outline properties control the style of these dynamic outlines.

The stacking of the rendering of these outlines is explicitly left up to
implementations to provide a better user experience per platform. This
supersedes the stacking of outlines as defined in [Appendix E of CSS
2.1](https://www.w3.org/TR/CSS21/zindex.html)
[\[CSS21\]](#biblio-css21 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification").

**Keyboard users, in particular people with disabilities who may not be
able to interact with the page in any other fashion, depend on the
outline being visible on elements in the
[:focus-visible](https://www.w3.org/TR/selectors-4/#focus-visible-pseudo) state, thus authors must not make the outline
invisible on such elements without making sure an alternative
highlighting mechanism is provided.**

The rendering of applying transforms to outlines is left explicitly
undefined.

### 3.1. Outlines Shorthand: the [outline property]
Name:

[outline]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<\'outline-width\'\>](#propdef-outline-width)
[\|\|](https://www.w3.org/TR/css-values-4/#comb-any)
[\<\'outline-style\'\>](#propdef-outline-style) [\|\|]
[\<\'outline-color\'\>](#propdef-outline-color)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

see individual properties

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[all
elements](https://www.w3.org/TR/css-pseudo/#generated-content "Includes ::before and ::after pseudo-elements.")

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

The [outline](#propdef-outline) property is a shorthand property and sets all
three of
[outline-style](#propdef-outline-style),
[outline-width](#propdef-outline-width), and
[outline-color](#propdef-outline-color). In the ambiguous case where a lone
[auto] value is specified, or if [auto] is specified
together with an [\<\'outline-width\'\>] value, but without an explicit
[\<\'outline-style\'\>] or
[\<\'outline-color\'\>]
value, both [outline-style]
and [outline-color] are set
to [auto].

 The shorthand purposefully omits the
[outline-offset](#propdef-outline-offset) property, which determines the
position rather than the appearance of the outline, so that it can
cascade independently, as well as for backwards compatibility reasons.

The outline created with the outline properties is drawn \"over\" a box,
i.e., the outline is always on top and doesn't influence the position or
size of the box, or of any other boxes. Therefore, displaying or
suppressing outlines does not cause reflow.

Outlines may be non-rectangular. For example, if the element is broken
across several lines, the outline should be an outline or minimum set of
outlines that encloses all the element's boxes.

Each part of the outline should be fully connected rather than open on
some sides (as borders on inline elements are when lines are broken).

The parts of the outline are not required to be rectangular. To the
extent that the outline follows the [border
edge](https://www.w3.org/TR/css-box-4/#border-edge), it should follow the
[border-radius](https://www.w3.org/TR/css-borders-4/#propdef-border-radius) curve, as well as the
[corner-shape](https://www.w3.org/TR/css-borders-4/#propdef-corner-shape).

The position of the outline may be affected by descendant boxes.

The dimensions of the drawn outline contribute to the [ink overflow
area](https://www.w3.org/TR/css-overflow-3/#ink-overflow-region) of an element.

User agents should use an algorithm for determining the outline that
encloses a region appropriate for conveying the concept of focus to the
user.

 This specification does not define the exact position
or shape of the outline, but it is typically drawn immediately outside
the border box.

 The outline is the same on all sides. In contrast to
borders, there are no [outline-top], [outline-left], etc.
properties.

This specification does not define how multiple overlapping outlines are
drawn or how outlines are drawn for boxes that are partially obscured
behind other elements.

Here's an example of drawing a thick
outline around a BUTTON element:

```
button { outline: thick solid }
```

Graphical user interfaces may use outlines around elements to tell the
user which element on the page has the focus. These outlines are shown
in addition to any borders, and switching outlines on and off should not
cause the document to reflow. The focus is the subject of user
interaction in a document (e.g. for entering text or selecting a
button).

For example, to draw a thick black
line around elements in the
[:focus-visible](https://www.w3.org/TR/selectors-4/#focus-visible-pseudo) state, and a thick red line when it is in the
[:active](https://www.w3.org/TR/selectors-4/#active-pseudo) state, the following rules can be used:

```
:focus-visible { outline: thick solid black }
:active { outline: thick solid red }
```

 Since the outline does not affect formatting (i.e., no
space is left for it in the box model), it may well overlap other
elements on the page.

### 3.2. Outline Thickness: the [outline-width property]
Name:

[outline-width]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<line-width\>](https://www.w3.org/TR/css-borders-4/#typedef-line-width)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

medium

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[all
elements](https://www.w3.org/TR/css-pseudo/#generated-content "Includes ::before and ::after pseudo-elements.")

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

The
[outline-width](#propdef-outline-width) property accepts the same values as
[border-width](https://www.w3.org/TR/css-borders-4/#propdef-border-width) ([CSS Backgrounds 3 § 3.3 Line
Thickness: the border-width
properties](https://www.w3.org/TR/css-backgrounds-3/#border-width)),
with the same meaning.

### 3.3. Outline Patterns: the [outline-style property]
Name:

[outline-style]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

auto
[\|](https://www.w3.org/TR/css-values-4/#comb-one)
[\<outline-line-style\>](#typedef-outline-line-style)

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

specified keyword

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value

[[\<outline-line-style\>](#typedef-outline-line-style)] accepts the same values as
[\<line-style\>](https://www.w3.org/TR/css-borders-4/#typedef-line-style) ([CSS Backgrounds 3 § 3.2 Line
Patterns: the border-style
properties](https://www.w3.org/TR/css-backgrounds-3/#border-style)) with
the same meaning, except that [hidden] is not a legal outline
style. In addition, the
[outline-style](#propdef-outline-style) property accepts the value
[auto].

The [auto] value permits the user agent to render a custom outline
style, typically a style which is either a user interface default for
the platform, or perhaps a style that is richer than can be described in
detail in CSS, e.g. a rounded edge outline with semi-translucent outer
pixels that appears to glow. User agents may enable authors to influence
the rendering of [auto] style outlines via the
[outline-color](#propdef-outline-color) property, but this specification
does not define how the rendering is impacted (if at all). The
[outline-width](#propdef-outline-width) property is ignored when
[outline-style](#propdef-outline-style) is [auto]. User agents may
treat [auto] as [solid].

### 3.4. Outline Colors: the [outline-color property]
Name:

[outline-color]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

auto
[\|](https://www.w3.org/TR/css-values-4/#comb-one)
[\<\'border-top-color\'\>](https://www.w3.org/TR/css-borders-4/#propdef-border-top-color)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

auto

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[all
elements](https://www.w3.org/TR/css-pseudo/#generated-content "Includes ::before and ::after pseudo-elements.")

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

N/A

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

see below

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value

The
[outline-color](#propdef-outline-color) property accepts all values of
[\<\'border-top-color\'\>](https://www.w3.org/TR/css-borders-4/#propdef-border-top-color), as well as the following
keywords:

[auto]

: When
 [outline-style](#propdef-outline-style) is [auto],
 [outline-color:
 auto](#propdef-outline-color) computes to [auto] and represents the
 [accent color](#accent-color).

 Otherwise, [outline-color:
 auto](#propdef-outline-color) computes to
 [currentColor](https://www.w3.org/TR/css-color-4/#valdef-color-currentcolor).

See [CSS Color 4 §  15. Resolving \<color\>
Values](https://www.w3.org/TR/css-color-4/#resolving-color-values) for
the computed value of
[\<color\>](https://www.w3.org/TR/css-color-5/#typedef-color) values, and [CSS Images 4 § 4 1D
Image Values: the \<image-1D\> type and stripes()
notation](https://www.w3.org/TR/css-images-4/#stripes) for
[\<image-1D\>](https://www.w3.org/TR/css-images-4/#typedef-image-1d) values.

Earlier versions of this
specification had an additional `invert` value, performing a color
inversion on the pixels on the screen. This is no longer supported, and
was removed for lack of implementations (and of intent to implement) in
modern user agents. See [CSS User Interface 3 § 4.4 Outline Colors: the
outline-color property](https://www.w3.org/TR/css-ui-3/#outline-color)
for details.

### 3.5. Offsetting the Outline: the [outline-offset property]
By default, the outline is drawn starting just outside the [border
edge](https://www.w3.org/TR/css-box-4/#border-edge). However, it is possible to offset the outline and draw
it beyond the [border edge].

Name:

[outline-offset]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<length\>](https://www.w3.org/TR/css-values-4/#length-value)

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

absolute length

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value

If the computed value of
[outline-offset](#propdef-outline-offset) is anything other than 0, then the
outline is outset from the [border
edge](https://www.w3.org/TR/css-box-4/#border-edge) by that amount.

For example, to leave 2 pixels of
space between a focus outline and the element that has the focus or is
active, the following rule can be used:

```
:focus,:active { outline-offset: 2px }
```

Negative values must cause the outline to shrink into the border box.
Both the height and the width of the outside of the shape drawn by the
outline should not become smaller than twice the computed value of the
[outline-width](#propdef-outline-width) property to make sure that an
outline can be rendered even with large negative values. User agents
should apply this constraint independently in each dimension. If the
outline is drawn as multiple disconnected shapes, this constraint
applies to each shape separately.

## 4. Resizing

CSS2.1 provides a mechanism for controlling the appearance of a
scrolling mechanism (e.g. scrollbars) on block container elements. This
specification adds a mechanism to that for controlling user resizability
of elements as well as the ability to specify text overflow behavior.

### 4.1. Resizing Boxes: the [resize property]
The [resize](#propdef-resize) property allows the author to specify whether or
not an element is resizable by the user, and if so, along which
axis/axes.

Name:

[resize]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

none
[\|](https://www.w3.org/TR/css-values-4/#comb-one) both [\|] horizontal
[\|] vertical [\|] block
[\|] inline

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

none

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

elements that are [scroll
containers](https://www.w3.org/TR/css-overflow-3/#scroll-container) and optionally replaced elements such as images,
videos, and iframes

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

none
: The UA does not present a resizing mechanism on the element, and the
 user is given no direct manipulation mechanism to resize the
 element.

both
: The UA presents a bidirectional resizing mechanism to allow the user
 to adjust both the height and the width of the element.

horizontal
: The UA presents a unidirectional horizontal resizing mechanism to
 allow the user to adjust only the width of the element.

vertical
: The UA presents a unidirectional vertical resizing mechanism to
 allow the user to adjust only the height of the element.

block
: The UA presents a unidirectional
 [block-axis](https://www.w3.org/TR/css-writing-modes-4/#block-axis) resizing mechanism to allow the user to adjust only
 the [block
 size](https://www.w3.org/TR/css-sizing-3/#block-size) of the element.

inline
: The UA presents a unidirectional
 [inline-axis](https://www.w3.org/TR/css-writing-modes-4/#inline-axis) resizing mechanism to allow the user to adjust only
 the [inline
 size](https://www.w3.org/TR/css-sizing-3/#inline-size) of the element.

Currently it is possible to control the appearance of the scrolling
mechanism (if any) on an element using the
[overflow](https://www.w3.org/TR/css-overflow-3/#propdef-overflow) property (e.g.
`overflow: scroll` vs.
`overflow: hidden` etc.). The purpose of the
[resize](#propdef-resize) property is to allow control over the appearance
and function of the resizing mechanism (e.g. a resize box or widget) on
the element.

 The resizing mechanism is NOT the same as the scrolling
mechanism, nor is it related to any UA mechanism for zooming. The
scrolling mechanism allows the user to determine which portion of the
contents of an element is shown. The resizing mechanism allows the user
to determine the size of the element.

The [resize](#propdef-resize) property applies to elements that are [scroll
containers](https://www.w3.org/TR/css-overflow-3/#scroll-container). UAs may also apply it, regardless of the value of the
[overflow](https://www.w3.org/TR/css-overflow-3/#propdef-overflow) property, to:

- Replaced elements representing images or videos, such as
 [`img`](https://html.spec.whatwg.org/multipage/embedded-content.html#the-img-element),
 [`video`](https://html.spec.whatwg.org/multipage/media.html#video),
 [`picture`](https://html.spec.whatwg.org/multipage/embedded-content.html#the-picture-element),
 [`svg`](https://www.w3.org/TR/SVG2/struct.html#elementdef-svg),
 [`object`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-object-element), or
 [`canvas`](https://html.spec.whatwg.org/multipage/canvas.html#canvas).
- The
 [`iframe`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-iframe-element) element.

The effect of the [resize](#propdef-resize) property on generated content is
undefined. Implementations should not apply the
[resize] property to generated
content.

 The [resize](#propdef-resize) property may apply to generated
content in the future if there is implementation of [Interface
CSSPseudoElement](https://drafts.csswg.org/css-pseudo/#CSSPseudoElement-interface).

When an element is resized by the user, the user agent sets the
[width](https://www.w3.org/TR/css-sizing-3/#propdef-width) and
[height](https://www.w3.org/TR/css-sizing-3/#propdef-height) properties to px unit length values
of the size indicated by the user in the element's [style
attribute](https://www.w3.org/TR/css-style-attr/#style-attribute) DOM,
replacing existing property declaration(s), if any, without
[!important], if any.

If an element is resized in only one dimension, only the corresponding
property is set, not both.

The precise direction of resizing (i.e. altering the top-left of the
element or altering the bottom-right) may depend on a number of CSS
layout factors, including whether the element is absolutely positioned,
whether it is positioned using the
[right](https://www.w3.org/TR/CSS2/visuren.html#propdef-right) and
[bottom](https://www.w3.org/TR/CSS2/visuren.html#propdef-bottom) properties, whether the language of
the element is right-to-left etc. The UA should consider the direction
of resizing (as determined by CSS layout), as well as platform
conventions and constraints, when deciding how to convey the resizing
mechanism to the user.

The user agent must allow the user to resize the element with no other
constraints than what is imposed by
[min-width](https://www.w3.org/TR/CSS2/visudet.html#propdef-min-width),
[max-width](https://www.w3.org/TR/CSS2/visudet.html#propdef-max-width),
[min-height](https://www.w3.org/TR/CSS2/visudet.html#propdef-min-height), and
[max-height](https://www.w3.org/TR/CSS2/visudet.html#propdef-max-height).

 There may be situations in which user attempts to
resize an element appear to be overridden or ignored, e.g. because of
[!important] cascading declarations that supersede that element's
[style attribute](https://www.w3.org/TR/css-style-attr/#style-attribute)
[width](https://www.w3.org/TR/css-sizing-3/#propdef-width) and
[height](https://www.w3.org/TR/css-sizing-3/#propdef-height) properties in the DOM.

Changes to the computed value of an element's
[resize](#propdef-resize) property do not reset changes to the [style
attribute](https://www.w3.org/TR/css-style-attr/#style-attribute) made
due to user resizing of that element.

For example, to make iframes
scrollable *and* resizable, the following rule can be used:

```
iframe,object[type^="text/"],
object[type$="+xml"],object[type="application/xml"]
{
 overflow:auto;
 resize:both;
}
```

## 5. Pointing Devices and Keyboards

### 5.1. Pointer interaction

#### 5.1.1. Styling the Cursor: the [cursor property]
Name:

[cursor]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

\[[\<cursor-image\>](#typedef-cursor-cursor-image)[,](https://www.w3.org/TR/css-values-4/#comb-comma)\][\*](https://www.w3.org/TR/css-values-4/#mult-zero-plus)
[\<cursor-predefined\>](#typedef-cursor-predefined)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

auto

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[all
elements](https://www.w3.org/TR/css-pseudo/#generated-content "Includes ::before and ::after pseudo-elements.")

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

yes

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

N/A

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

as specified, except with any relative URLs converted to absolute

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

This property specifies the type of cursor to be displayed for the
pointing device when the cursor's hotspot is within the element's
[border
edge](https://www.w3.org/TR/css-box-4/#border-edge).

 As per [CSS Backgrounds 3 § 4.1 Curve Radii: the
border-radius
properties](https://www.w3.org/TR/css-backgrounds-3/#border-radius), the
[border
edge](https://www.w3.org/TR/css-box-4/#border-edge) is affected by
[border-radius](https://www.w3.org/TR/css-borders-4/#propdef-border-radius).

In the case of overlapping elements, which element determines the type
of cursor is based on hit testing: the element determining the cursor is
the one that would receive a click initiated from this position.

 The specifics of hit testing are out of scope of this
specification. Hit testing will hopefully be defined in a future
revision of CSS or HTML.

User agents may ignore the cursor property over native user agent
controls such as scrollbars, resizers, or other native UI widgets e.g.
those that may be used inside some user agent specific implementations
of form elements. User agents may also ignore the
[cursor](#propdef-cursor) property and display a cursor of their choice to
indicate various states of the UA's user interface, such as a busy
cursor when the page is not responding, or a text cursor when the user
is performing text selection.

[\[HTML\]](#biblio-html "HTML Standard") defines
[special handling of image
maps](https://html.spec.whatwg.org/multipage/rendering.html#image-maps-2)
for the [cursor](#propdef-cursor) property.

Values have the following meanings:

[[\<cursor-image\>](#typedef-cursor-cursor-image)]

: The first (optional) component of the
 [cursor](#propdef-cursor) property is a list of image-based cursors. If
 the user agent cannot handle the first cursor of a list of cursors,
 it must attempt to handle the second, etc. If the user agent cannot
 handle any of these author-defined cursors, it must use the
 keyword-based cursor at the end of the list.

 A
 [\<cursor-image\>](#typedef-cursor-cursor-image) has the following syntax:

 ``` prod
 <cursor-image> = [ <url> | <url-set> ] <number>{2}?
 ```

 The user agent retrieves the cursor from the resource designated by
 the
 [\<url\>](https://www.w3.org/TR/css-values-4/#url-value) or
 [\<url-set\>](#typedef-cursor-url-set). Conforming user agents may,
 instead of [\<url\>] and
 [\<url-set\>], support
 [\<image\>](https://www.w3.org/TR/css-images-3/#typedef-image) which is a superset.

 [\<url-set\>] is a limited version of
 [image-set()](https://www.w3.org/TR/css-images-4/#funcdef-image-set), where the
 [\<image\>](https://www.w3.org/TR/css-images-3/#typedef-image) sub-production is restricted to
 [\<url\>](https://www.w3.org/TR/css-values-4/#url-value) only.

 The UA must support the following image file formats:

 - PNG, as defined in
 [\[PNG\]](#biblio-png "Portable Network Graphics (PNG) Specification (Third Edition)")
 - SVG, as defined in
 [\[SVG11\]](#biblio-svg11 "Scalable Vector Graphics (SVG) 1.1 (Second Edition)"),
 in [secure static
 mode](https://www.w3.org/TR/SVG2/conform.html#secure-static-mode)
 [\[SVG2\]](#biblio-svg2 "Scalable Vector Graphics (SVG) 2"),
 if it has a [natural
 size](https://www.w3.org/TR/css-images-3/#natural-size).
 - any other non-animated image file format that they support for
 [\<image\>](https://www.w3.org/TR/css-images-3/#typedef-image) in other properties, such as
 the
 [background-image](https://www.w3.org/TR/css-backgrounds-4/#propdef-background-image) property

 In addition, the UA should support the following image file formats:

 - SVG, as defined in
 [\[SVG11\]](#biblio-svg11 "Scalable Vector Graphics (SVG) 1.1 (Second Edition)"),
 in [secure animated
 mode](https://www.w3.org/TR/SVG2/conform.html#secure-animated-mode)
 [\[SVG2\]](#biblio-svg2 "Scalable Vector Graphics (SVG) 2"),
 if it has a [natural
 size](https://www.w3.org/TR/css-images-3/#natural-size).
 - any other animated image file format that they support for
 [\<image\>](https://www.w3.org/TR/css-images-3/#typedef-image) in other properties, such as
 the
 [background-image](https://www.w3.org/TR/css-backgrounds-4/#propdef-background-image) property

 The UA may also support additional file formats, including SVG, as
 defined in
 [\[SVG11\]](#biblio-svg11 "Scalable Vector Graphics (SVG) 1.1 (Second Edition)"),
 in secure static mode or secure animated mode
 [\[SVG2\]](#biblio-svg2 "Scalable Vector Graphics (SVG) 2"),
 even if it does not have a [natural
 size](https://www.w3.org/TR/css-images-3/#natural-size).

 The CSS Working Group initially intended support
 for all SVG, naturally sized or not. Support for non-naturally sized
 SVG was downgraded from mandatory to optional due to a lack of
 implementations.

 For a number of years, the only file formats
 supported for cursors in common desktop browsers were the .ico and
 .cur file formats, as designed by Microsoft. Although this is no
 longer the case (PNG and SVG have broad support), for compatibility
 with legacy content, UAs are encouraged to support these, even
 though the lack of an open specification makes it impossible to have
 a normative requirement about these formats. Some information on
 these formats can be found [on
 Wikipedia](https://en.wikipedia.org/wiki/ICO_%28file_format%29).

 The [default object
 size](https://www.w3.org/TR/css-images-3/#default-object-size) for cursor images is a UA-defined size that should
 be based on the size of a typical cursor on the UA's operating
 system.

 The [concrete object
 size](https://www.w3.org/TR/css-images-3/#concrete-object-size) is determined using the [default sizing
 algorithm](https://www.w3.org/TR/css-images-3/#default-sizing-algorithm). If an operating system is **incapable** of
 rendering a cursor above a given size, cursors larger than that size
 must be shrunk to within the OS-supported size bounds, while
 maintaining the cursor image's [natural aspect
 ratio](https://www.w3.org/TR/css-images-3/#natural-aspect-ratio), if any.

 The optional pair of
 [\<number\>](https://www.w3.org/TR/css-values-4/#number-value) values give the X and Y
 coordinates of the exact position within the image which is the
 pointer position (i.e., the hotspot), as offsets from the left/top
 of the image.

 This specification does not define how the
 coordinate systems of the various types of
 [\<image\>](https://www.w3.org/TR/css-images-3/#typedef-image) are established, and defers these
 definitions to
 [\[CSS4-IMAGES\]](#biblio-css4-images "CSS Images Module Level 4").

 If the values are omitted, then the natural hotspot defined inside
 the image resource itself is used. If it has no natural hotspot, the
 top left corner of the image is used, as if [0 0] were
 provided.

 If the X or Y coordinates of the hotspot (whether specified
 explicitly or taken from the image) fall outside of the cursor
 image, they must be clamped (independently) to fit.

[[\<cursor-predefined\>](#typedef-cursor-predefined)]

: The mandatory
 [\<cursor-predefined\>](#typedef-cursor-predefined) keyword specifies a predefined
 cursor to use, or the *fallback* cursor to be used if
 [\<url\>](https://www.w3.org/TR/css-values-4/#url-value)s were provided and none of them
 can be successfully used.

 See [§ 5.1.1.1 Predefined Cursors](#predefined-cursors) for the full
 set of
 [\<cursor-predefined\>](#typedef-cursor-predefined) keywords and their meanings.

Here is an example of using several
cursor values.

```
:link,:visited {
 cursor: url(example.svg),
 url(hyper.cur),
 url(hyper.png) 2 3,
 pointer
}
```

This example sets the cursor on all hyperlinks (whether visited or not)
to an external SVG image to be used as a cursor. If that fails to load,
user agents would simply skip to the next value and attempt to use the
\"hyper.cur\" cursor. If that cursor format was also not supported, the
UA could attempt to use the \"hyper.png\" cursor with the explicit
hotspot. Finally, if the UA cannot load any of those image cursors, the
UA would skip to the last value and render the
[pointer](#valdef-cursor-pointer) cursor.

##### 5.1.1.1. Predefined Cursors

The
[\<cursor-predefined\>](#typedef-cursor-predefined) production encompasses a broad
selection of predefined cursors, present on most operating systems. Its
syntax is:

``` prod
<cursor-predefined> = auto | default | none |
 context-menu | help | pointer | progress | wait |
 cell | crosshair | text | vertical-text |
 alias | copy | move | no-drop | not-allowed | grab | grabbing |
 e-resize | n-resize | ne-resize | nw-resize |
 s-resize | se-resize | sw-resize | w-resize |
 ew-resize | ns-resize | nesw-resize | nwse-resize |
 col-resize | row-resize |
 all-scroll |
 zoom-in | zoom-out
```

The
[\<cursor-predefined\>](#typedef-cursor-predefined) keywords have the following meanings
and likely renderings:

general purpose cursors

:

 [auto]
 : The UA determines the cursor to display based on the current
 context: [auto](#valdef-cursor-auto) behaves as
 [text](#valdef-cursor-text) over selectable text or editable elements,
 and
 [default](#valdef-cursor-default) otherwise.

 [default]
 : The platform-dependent default cursor. Often rendered as an
 arrow.

 [none]
 : No cursor is rendered for the element.

links and status cursors

:

 [context-menu]
 : A context menu is available for the object under the cursor.
 Often rendered as an arrow with a small menu-like graphic next
 to it.

 [help]
 : Help is available for the object under the cursor. Often
 rendered as a question mark or a balloon.

 [pointer]
 : The cursor is a pointer that indicates a link.

 [progress]
 : A progress indicator. The program is performing some processing,
 but is different from
 [wait](#valdef-cursor-wait) in that the user may still interact with the
 program. Often rendered as a spinning beach ball, or an arrow
 with a watch or hourglass.

 [wait]
 : Indicates that the program is busy and the user should wait.
 Often rendered as a watch or hourglass.

selection cursors

:

 [cell]
 : Indicates that a cell or set of cells may be selected. Often
 rendered as a thick plus-sign with a dot in the middle.

 [crosshair]
 : A simple crosshair (e.g., short line segments resembling a \"+\"
 sign). Often used to indicate a two dimensional bitmap selection
 mode.

 [text]
 : Indicates text that may be selected. Often rendered as a
 vertical I-beam. User agents may automatically display a
 horizontal I-beam/cursor (e.g. same as the
 [vertical-text](#valdef-cursor-vertical-text) keyword) for vertical text, or for that
 matter, any angle of I-beam/cursor for text that is rendered at
 any particular angle.

 [vertical-text]
 : Indicates vertical-text that may be selected. Often rendered as
 a horizontal I-beam.

drag and drop cursors

:

 [alias]
 : Indicates an alias of/shortcut to something is to be created.
 Often rendered as an arrow with a small curved arrow next to it.

 [copy]
 : Indicates something is to be copied. Often rendered as an arrow
 with a small plus sign next to it.

 [move]
 : Indicates something is to be moved.

 [no-drop]
 : Indicates that the dragged item cannot be dropped at the current
 cursor location. Often rendered as a hand or pointer with a
 small circle with a line through it.

 [not-allowed]
 : Indicates that the requested action will not be carried out.
 Often rendered as a circle with a line through it.

 [grab]
 : Indicates that something can be grabbed (dragged to be moved).
 Often rendered as the backside of an open hand.

 [grabbing]
 : Indicates that something is being grabbed (dragged to be moved).
 Often rendered as the backside of a hand with fingers closed
 mostly out of view.

resizing and scrolling cursors

:

 [e-resize]\
 [n-resize]\
 [ne-resize]\
 [nw-resize]\
 [s-resize]\
 [se-resize]\
 [sw-resize]\
 [w-resize]
 : Indicates that some edge is to be moved. For example, the
 [se-resize](#valdef-cursor-se-resize) cursor is used when the movement starts
 from the south-east corner of the box.

 [ew-resize]\
 [ns-resize]\
 [nesw-resize]\
 [nwse-resize]
 : Indicates a bidirectional resize cursor.

 [col-resize]
 : Indicates that the item/column can be resized horizontally.
 Often rendered as arrows pointing left and right with a vertical
 bar separating them.

 [row-resize]
 : Indicates that the item/row can be resized vertically. Often
 rendered as arrows pointing up and down with a horizontal bar
 separating them.

 [all-scroll]
 : Indicates that the something can be scrolled in any direction.
 Often rendered as arrows pointing up, down, left, and right with
 a dot in the middle.

zooming cursors

:

 [zoom-in]\
 [zoom-out]
 : Indicates that something can be zoomed (magnified) in or out,
 and often rendered as a magnifying glass with a \"+\" or \"-\"
 in the center of the glass, for
 [zoom-in](#valdef-cursor-zoom-in) and
 [zoom-out](#valdef-cursor-zoom-out) respectively.

##### 5.1.1.2. Cursor of the canvas

The document [canvas](https://www.w3.org/TR/CSS21/intro.html#the-canvas)
is the infinite surface over which the document is rendered
[\[CSS21\]](#biblio-css21 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification").
Since no element corresponds to the canvas, in order to allow styling of
the cursor when not over any element, the canvas cursor re-uses the root
element's cursor. However, if no boxes are generated for the root
element (for example, if the root element has [display:
none](https://www.w3.org/TR/css-display-3/#propdef-display)), then the canvas cursor is the
platform-dependent default cursor.

 An element might be invisible but still generate boxes.
For example, if the element has [visibility:
hidden](https://www.w3.org/TR/CSS2/visufx.html#propdef-visibility) but not [display:
none](https://www.w3.org/TR/css-display-3/#propdef-display), boxes are generated for it and its cursor is
used for the canvas.

### 5.2. Insertion caret

The [insertion caret] (or "caret" for short) is a
visible indicator of the insertion point in an element that [accepts
text input](#accept-text-input), where text (and potentially other content) can be
inserted by the user. The
[caret-color](#propdef-caret-color),
[caret-animation](#propdef-caret-animation), and
[caret-shape](#propdef-caret-shape) properties give the author some amount
of control over the appearance of the
[caret](#insertion-caret).

Text or elements are considered to [accept text
input]
if they are either an [editable
element](#editable-element)
or a descendent thereof, excluding any such element where the [used
value](https://www.w3.org/TR/css-cascade-5/#used-value) of
[user-select](#propdef-user-select) is
[none](#valdef-user-select-none), as well as subtrees rooted at an HTML element with a
[`contentEditable`](https://html.spec.whatwg.org/multipage/interaction.html#dom-contenteditable) attribute set to `false`.

Some user agents have other user interface mechanisms with a similar
appearance, also occasionally referred to as "carets". For example, some
UAs can show a "navigation caret", which acts similarly to an [insertion
caret](#insertion-caret) but
can be moved around in non-editable text. The
[caret-color](#propdef-caret-color),
[caret-animation](#propdef-caret-animation), and
[caret-shape](#propdef-caret-shape) properties are not intended to apply to
such mechanisms nor outside of [editable
elements](#editable-element), though user agents may choose to take them into
account. Whether to do so and to what extent is up to the user agent.

 The cursor image shown when hovering over text when the
[cursor](#propdef-cursor) property is
[auto](#valdef-cursor-auto), or when hovering over an element where the
[cursor] property is
[text](#valdef-cursor-text) or
[vertical-text](#valdef-cursor-vertical-text), though it sometimes resembles a caret, is not a
caret (it's a cursor).

Within the context of this section, [character] is to be understood as
*extended grapheme cluster*, as defined in
[\[UAX29\]](#biblio-uax29 "Unicode Text Segmentation"),
and [visible character] means a character with a non-zero advance
measure.

#### 5.2.1. Coloring the Insertion Caret: the [caret-color property]
Name:

[caret-color]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

auto
[\|](https://www.w3.org/TR/css-values-4/#comb-one)
[\<color\>](https://www.w3.org/TR/css-color-5/#typedef-color) \[auto [\|]
[\<color\>]\][?](https://www.w3.org/TR/css-values-4/#mult-opt)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

auto

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

text or elements that [accept text
input](#accept-text-input)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

yes

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

N/A

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

The computed value for
[auto](https://www.w3.org/TR/css-ui-3/#valdef-caret-color-auto) is [auto]. For
[\<color\>](https://www.w3.org/TR/css-color-5/#typedef-color) values, see [CSS Color 4 §  15.
Resolving \<color\>
Values](https://www.w3.org/TR/css-color-4/#resolving-color-values).

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value

This property controls the color of the [insertion
caret](#insertion-caret). It
takes one or two values. The first value has the following effects:

auto

: User agents should use
 [currentColor](https://www.w3.org/TR/css-color-4/#valdef-color-currentcolor). User agents may automatically adjust the
 color of [caret](#insertion-caret) to ensure good visibility and contrast with the
 surrounding content, possibly based on the currentColor, background,
 shadows, etc.

 When
 [caret-shape](#propdef-caret-shape) is
 [block](#valdef-caret-shape-block), ensuring good visibility and contrast is
 best achieved with a UA-determined color other than
 [currentColor](https://www.w3.org/TR/css-color-4/#valdef-color-currentcolor).

[\<color\>](https://www.w3.org/TR/css-color-5/#typedef-color)
: The [caret](#insertion-caret) is colored with the specified color.

Example: a textarea with
`caret-color:#00aacc;`

The second value has no effect when
[caret-shape](#propdef-caret-shape) is
[bar](#valdef-caret-shape-bar),
[underscore](#valdef-caret-shape-underscore), or
[auto](#valdef-caret-shape-auto) behaving as either of these values. If
[caret-shape] is
[block](#valdef-caret-shape-block)---​or [auto] behaving as [block]---​then it determines the color of the text [overlapping the
caret](#overlap-the-caret).
If the second value is omitted, the behavior is the same as if `auto`
had been specified.

auto
: User agents must automatically adjust the color of the text
 [overlapping the
 caret](#overlap-the-caret) to ensure good visibility and contrast between the
 text and the underlying
 [block](#valdef-caret-shape-block) caret, if using
 [currentColor](https://www.w3.org/TR/css-color-4/#valdef-color-currentcolor) would result in poor readability. The
 specifics of how to assess contrast and how to pick a sufficiently
 contrasty color are up to the user agent.

[\<color\>](https://www.w3.org/TR/css-color-5/#typedef-color)

: The color of text [overlapping the
 caret](#overlap-the-caret) is the specified color.

 Authors wishing to ensure that the color of the
 text remains constant regardless of the position of a
 [block](#valdef-caret-shape-block) caret can specify
 [currentColor](https://www.w3.org/TR/css-color-4/#valdef-color-currentcolor) as the second value of
 [caret-color](#propdef-caret-color).

Text considered to [overlap the caret] is the next [visible
character](#visible-character) after the insertion point, if any.

This illustrates the effect of the
second value of
[caret-color](#propdef-caret-color) on
[block](#valdef-caret-shape-block) carets. In each of the sample renderings below,
the insertion point is between the letters u and m.

\'caret-color:\'

Sample rendering

Your browser\
(focus each cell to see the
[caret](#insertion-caret))

[black](https://www.w3.org/TR/css-color-4/#valdef-color-black) (or [black auto])

Lorem
ipsu[m]{style="background: #000; color: #fff; animation: caret-color-2-ref 1s step-end infinite;"}

Lorem Ipsum

[black yellow]

Lorem
ipsu[m]{style="background: #000; color: yellow; animation: caret-color-2-ref 1s step-end infinite;"}

Lorem Ipsum

[black black]

Lorem
ipsu[m]{style="background: #000; animation: caret-color-2-ref 1s step-end infinite;"}

Lorem Ipsum

Optionally, user agents may treat as overlapping only those parts of
next [visible character](#visible-character) which visually intersect with the
[block](#valdef-caret-shape-block), and adjust the color of those parts only.

#### 5.2.2. Animation of the insertion caret: [caret-animation]
Name:

[caret-animation]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

auto
[\|](https://www.w3.org/TR/css-values-4/#comb-one) manual

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

auto

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

text or elements that [accept text
input](#accept-text-input)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

yes

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

N/A

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

specified keyword

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

On most platforms and in most UAs, the [insertion
caret](#insertion-caret)
blinks. This property allows the author to take control over the way the
[caret] is animated.

[auto]

: The UA determines how the
 [caret](#insertion-caret)
 should be animated, if at all, as well as the speed of any such
 animation. It should match platform conventions and settings, and
 may be adjusted based on context.

 This is typically rendered as a blinking
 [caret](#insertion-caret). Fading in and out instead of blinking is a variant
 that appears in some environments.

[manual]

: The UA must not animate the
 [caret](#insertion-caret).

 This is only about UA-driven animations of the
 [caret](#insertion-caret). When CSS animations are used to animate the
 [caret] color, they apply normally.

 It is recommended for authors to stop the
[caret](#insertion-caret)
from blinking or fading using [caret-animation:
manual](#propdef-caret-animation) when applying custom animations using
[\[CSS3-ANIMATIONS\]](#biblio-css3-animations "CSS Animations Level 1"),
to prevent the UA's animation and the CSS animation to interfere.

 See [Guideline 2.3: Seizures: Do not design content in
a way that is known to cause
seizures](https://www.w3.org/TR/WCAG20/#seizure)
[\[WCAG20\]](#biblio-wcag20 "Web Content Accessibility Guidelines (WCAG) 2.0").

A user who is disturbed by or has
adverse reactions to blinking or flashing visuals may want to make all
[carets](#insertion-caret)
static and non-blinking, regardless of platform defaults or author
settings. This can be accomplished with the following rule in the user
stylesheet.

```
/* prevent the caret from blinking/flashing */
:read-write { caret-animation: manual !important; }

/* prevent changes of caret-color, including animations */
:read-write { caret-color: auto !important; }
```

UAs that do not have an editable user stylesheet should provide a
setting to disable [blinking](https://www.w3.org/TR/WCAG20/#blinksdef),
[flashing](https://www.w3.org/TR/WCAG20/#flash-def), and animated
[carets](#insertion-caret).
UAs that do have an editable user stylesheet may want to provide this
setting as well. See
[\[WCAG\]](#biblio-wcag "Web Content Accessibility Guidelines (WCAG) 2.2")
[Guideline 2.2](https://www.w3.org/TR/WCAG20/#time-limits-pause) and
[Guideline 2.3](https://www.w3.org/TR/WCAG20/#seizure) for details.

Typically, the
[caret](#insertion-caret)
blinks on and off. This makes it alternate between 2 colors.

```
textarea {
 caret-animation: manual;
 caret-color: blue;
 animation: caret-alternate 2s step-end infinite;
}
@keyframes caret-alternate {
 50% { caret-color: red; }
}
```

The simulated rendering below illustrates how this is expected to look.

::: {style="border:inset; background: white; color: black; width: 10em;"}
Text area with color-alternating
caret{style="border-right: 2px solid blue; animation: caret-alternate-ref 2s step-end infinite;"}

Focus the element below to see how your browser renders it.

::: {contenteditable="true" style="border:inset; background: white; color: black; width: 10em;
 caret-animation: manual;
 caret-color: blue;
 animation: caret-alternate-test 2s step-end infinite;"}
Text area with color-alternating caret

If a user agent is unwilling to yield control of
[caret](#insertion-caret)
animations to page authors and would not honor [caret-animation:
manual](#propdef-caret-animation), it must not implement the property at all.

 This enables authors to use
`@supports (caret-animation: manual) { … }` to gate code
that would depend on this functionality. See
[\[CSS-CONDITIONAL-3\]](#biblio-css-conditional-3 "CSS Conditional Rules Module Level 3").

#### 5.2.3. Shape of the insertion caret: [caret-shape]
Name:

[caret-shape]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

auto
[\|](https://www.w3.org/TR/css-values-4/#comb-one) bar [\|] block
[\|] underscore

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

auto

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

text or elements that [accept text
input](#accept-text-input)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

yes

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

N/A

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

specified keyword

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value

This property allows authors to specify the desired shape of the
[insertion caret](#insertion-caret).

[auto]
: The UA determines the shape of the
 [caret](#insertion-caret). It should match platform conventions, and may be
 adjusted based on context. For example, if a UA switches between
 insert mode and overtype mode when the user presses the *insert* key
 on their keyboard, it may show a
 [bar](#valdef-caret-shape-bar) [caret] in insert
 mode, and a
 [block](#valdef-caret-shape-block) [caret] in
 overtype mode.

[bar]
: The UA must render the [insertion
 caret](#insertion-caret)
 as a thin bar placed at the insertion point. This means it is
 between, before, or after
 [characters](#character), not
 over them. It should be perpendicular to the inline progression
 direction, although UAs may render it slanted when inserting italic
 or oblique text.

[block]
: The UA must render the [insertion
 caret](#insertion-caret)
 as a rectangle overlapping the next [visible
 character](#visible-character) following the insertion point. If there is no
 [visible character] after the insertion
 point, the UA must render the caret after the last [visible
 character]. UAs may render it as a
 slanted rectangle when inserting italic or oblique text.

[underscore]
: The UA must render the [insertion
 caret](#insertion-caret)
 as a thin line
 [under](https://www.w3.org/TR/css-writing-modes-4/#under) (as defined in
 [\[CSS-WRITING-MODES-3\]](#biblio-css-writing-modes-3 "CSS Writing Modes Level 3"))
 the next [visible
 character](#visible-character) following the insertion point. If there is no
 [visible character] after the insertion
 point, the UA must render the caret after the last [visible
 character].

The width of the
[block](#valdef-caret-shape-block) and
[underscore](#valdef-caret-shape-underscore)
[carets](#insertion-caret)
should be the advance measure of the next [visible
character](#visible-character) after the insertion point, or [1ch] if there is
no next [visible character] or if this
information is impractical to determine.

When determining the orientation and appearance of the
[caret](#insertion-caret),
UAs must take into account the [writing
mode](https://www.w3.org/TR/css-writing-modes-4/#writing-mode)
[\[CSS-WRITING-MODES-3\]](#biblio-css-writing-modes-3 "CSS Writing Modes Level 3")
and must apply transformations
[\[CSS-TRANSFORMS-1\]](#biblio-css-transforms-1 "CSS Transforms Module Level 1").
If the edited text is laid out on a path, for instance by using the SVG
[`textPath`](https://www.w3.org/TR/SVG2/text.html#elementdef-textPath) element, UAs should also account for this.

The thickness of
[bar](#valdef-caret-shape-bar) and
[underscore](#valdef-caret-shape-underscore)
[carets](#insertion-caret)---​as well as that of
[auto](#valdef-caret-shape-auto) [carets] with a similar
rendering---​is determined by the user agent. When practical, the user
agent should choose a thickness that ensures the
[caret] remains visible even if it has been
scaled down via means such as transformations
[\[CSS-TRANSFORMS-1\]](#biblio-css-transforms-1 "CSS Transforms Module Level 1").

When there is not enough room at the end of a line to display the caret
positioned there, the user agents should still display it, even if that
means means painting past the bounds of the [scrollable overflow
area](https://www.w3.org/TR/css-overflow-3/#scrollable-overflow-region); user agents may impose limits on this and clip as
necessary. User agents may also visually reposition a caret in order to
display it within the
[scrollport](https://www.w3.org/TR/css-overflow-3/#scrollport) if it would otherwise be invisible.

The stacking position of the
[caret](#insertion-caret) is
left undefined within the following constraints:

- The [caret](#insertion-caret) must not be obscured by the background of the
 element.
- UAs must render
 [block](#valdef-caret-shape-block)
 [carets](#insertion-caret)
 so that the character it overlaps with is not obscured by the
 [caret].

This illustrates the typical
appearance of the various
[caret](#insertion-caret)
shapes. In each of the sample renderings below, the insertion point is
between the letters u and m.

[caret-shape](#propdef-caret-shape)

Sample rendering

Your browser\
(focus each cell to see the
[caret](#insertion-caret))

[bar](#valdef-caret-shape-bar)

Lorem
ipsu[​]{style="border: 1px solid black; margin: 0 -1px; animation: caret-bar-ref 2s step-end infinite;"}m

Lorem Ipsum

[block](#valdef-caret-shape-block)

Lorem
ipsu[m]{style="background: #bbb; animation: caret-block-ref 2s step-end infinite;"}

Lorem Ipsum

[underscore](#valdef-caret-shape-underscore)

Lorem
ispu[m]{style="border-bottom: 2px solid black; animation: caret-underscore-ref 2s step-end infinite;"}

Lorem Ipsum

[underscore](#valdef-caret-shape-underscore) or
[block](#valdef-caret-shape-block)
[carets](#insertion-caret)
are commonly used in terminals and command lines, as in this example.

```
.console {
 caret-shape: underscore;
 background: black;
 color: white;
 font-family: monospace;
 padding: 1ex;
}
```

The simulated rendering below illustrates how this is expected to look.

``` {style="background: black; color: white; font-family: monospace; padding: 1ex"}
user@host:css-ui-4 $ ls -a
. .. Overview.bs Overview.html
user@host:css-ui-4 $  
```

Focus the element below to see how your browser renders it.

``` {contenteditable="true" style="background: black; color: white; font-family: monospace; padding: 1ex; caret-shape: underscore;"}
user@host:css-ui-4 $ ls -a
. .. Overview.bs Overview.html
user@host:css-ui-4 $ 
```

#### 5.2.4. Insertion caret shorthand: [caret]
Name:

[caret]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<\'caret-color\'\>](#propdef-caret-color)
[\|\|](https://www.w3.org/TR/css-values-4/#comb-any)
[\<\'caret-animation\'\>](#propdef-caret-animation) [\|\|]
[\<\'caret-shape\'\>](#propdef-caret-shape)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

auto

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

text or elements that [accept text
input](#accept-text-input)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

yes

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

N/A

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

see individual properties

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

see individual properties

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

This property is a shorthand for setting
[caret-color](#propdef-caret-color),
[caret-animation](#propdef-caret-animation), and
[caret-shape](#propdef-caret-shape) in one declaration. Omitted values are
set to their initial values.

This example illustrates using the
various [caret](#insertion-caret)-related properties in combination. They are used here
to simulate the appearance of the [caret] on
an old phosphor computer monitor.

```
#old-screen {
 caret: block manual;
 animation: old-caret 2s infinite;
 /*styling of the screen omitted for brevity */
}
@keyframes old-caret {
 from, 50% { caret-color: green; }
 75%, to { caret-color: transparent; }
}
```

The simulated rendering below illustrates how this is expected to look.

\>  

Focus the element below to see how your browser renders it.

\>

### 5.3. Keyboard control

#### 5.3.1. Directional Focus Navigation: the [nav-up, [nav-right](#propdef-nav-right), [nav-down](#propdef-nav-down), [nav-left](#propdef-nav-left) properties]
Name:

[nav-up], [nav-right], [nav-down],
[nav-left]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

auto
[\|](https://www.w3.org/TR/css-values-4/#comb-one) [\<id\>](#typedef-id) \[ current [\|] root
[\|]
[\<target-name\>](#typedef-target-name)
\][?](https://www.w3.org/TR/css-values-4/#mult-opt)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

auto

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

all enabled elements

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

auto
: The user agent automatically determines which element to navigate
 the focus to in response to directional navigational input.

[[\<id\>](#typedef-id)]

: The [\<id\>](#typedef-id) value is an ID selector
 [\[SELECT\]](#biblio-select "Selectors Level 3").
 In response to directional navigation input corresponding to the
 property, the focus is navigated to the first element in tree order
 matching the selector.

 If this refers to the currently focused element, the directional
 navigation input respective to the nav- property is ignored ---
 there is no need to refocus the same element.

 If no element matches the selector, the user agent automatically
 determines which element to navigate the focus to.

 If the focus is navigated to an element that was not otherwise
 focusable, it becomes focusable only as the result of this
 directional navigation, and the
 [:focus](https://www.w3.org/TR/selectors-4/#focus-pseudo) pseudo-class matches the element while it is
 focused as such.

 there were other options under consideration for
 such \"not otherwise focusable\" elements, including focus to the
 next otherwise focusable element in the document tree (including
 descendants of such a not otherwise focusable element). Input on
 such other options is welcome and explicitly solicited, especially
 from implementation experiences and author experience using the
 directional navigation properties in their content.

[[\<target-name\>](#typedef-target-name)]
: The \<target-name\> parameter indicates the target frame for the
 focus navigation. It is a
 [\<string\>](https://www.w3.org/TR/css-values-4/#string-value) and it MUST NOT start with the
 underscore \"\_\" character. Error handling: if it does start with
 an underscore, \"\_parent\" navigates to the parent frame,
 \"\_root\" is treated as [root], and other values navigate to
 a frame by that name if it exists. If the specified target frame
 does not exist, the parameter will be treated as the keyword
 [current], which means to simply use the frame that the
 element is in. The keyword [root] indicates that the user
 agent should target the full window.

User agents for devices with directional navigation keys respond by
navigating the focus according to four respective nav-\* directional
navigation properties (nav-up, nav-right, nav-down, nav-left). This
specification does not define which keys of a device are directional
navigational keys.

 Typical personal computers have keyboards with four
arrow keys. One possible implementation would be to use those four arrow
keys for directional navigation. For accessibility and user convenience,
user agents should allow configuration of which keys on a keyboard are
used for directional navigation.

##### 5.3.1.1. Example: positioned buttons

Here is an example of buttons positioned in a diamond shape whose
directional focus navigation is set in such a way to navigate the focus
clockwise (or counter-clockwise) around the diamond shape when the user
chooses to navigate directionally.

```
button { position:absolute }

button#b1 {
 top:0; left:50%;
 nav-right:#b2; nav-left:#b4;
 nav-down:#b2; nav-up:#b4;
}

button#b2 {
 top:50%; left:100%;
 nav-right:#b3; nav-left:#b1;
 nav-down:#b3; nav-up:#b1;
}

button#b3 {
 top:100%; left:50%;
 nav-right:#b4; nav-left:#b2;
 nav-down:#b4; nav-up:#b2;
}

button#b4 {
 top:50%; left:0;
 nav-right:#b1; nav-left:#b3;
 nav-down:#b1; nav-up:#b3;
}
```

Whatever markup sequence the buttons may have (which is not specified in
this example) is irrelevant in this case because they are positioned,
and yet, it is still important to ensure focus navigation behaviors
which relate reasonably to the specified layout.

##### 5.3.1.2. Example: moving focus to inside a frame

Moving the focus to an element in a specific frame requires both the
element's id and the frame's name.

This example shows how to make navigating left from the button with id
\"foo\" move the focus to the element with id \"bar\" within the frame
named \"sidebar\".

```
button#foo { nav-left: #bar "sidebar"; }
```

#### 5.3.2. Obsolete: the ime-mode property

[ime-mode] is a property somewhat implemented in some browsers
that is problematic and officially obsoleted by this specification and
its predecessor
[\[CSS-UI-3\]](#biblio-css-ui-3 "CSS Basic User Interface Module Level 3 (CSS3 UI)").

User agents should not support the [ime-mode] property.

Authors must not use the ime-mode property.

Users may use the ime-mode property only for repair use cases where they
have to work around bad sites and legacy implementations, e.g. with a
user style sheet rule like:

Example: user preference

```
input[type=password] {
 ime-mode: auto !important;
 }
```

This example CSS may be placed into a user style sheet file to force
password input fields to behave in a default manner.

This specification deliberately does not attempt to document the
functionality of legacy ime-mode implementations nor what they
specifically support because it does not make sense to pursue or
recommend any such path.

Note: there are several
[\[HTML5\]](#biblio-html5 "HTML5") features which
authors should use to provide information to user agents that allow them
to provide a better input user experience:

- The global `lang` attribute
- The `inputmode`, `pattern`, and `type` attributes of the input element

## 6. User Interaction

### 6.1. Controlling content selection

The [user-select](#propdef-user-select) property enables authors to specify
which elements in the document can be selected by the user and how. This
allows for easier interactions when not all elements are equally useful
to select, avoiding accidental selections of neighboring content.

Name:

[user-select]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

auto
[\|](https://www.w3.org/TR/css-values-4/#comb-one) text [\|] none
[\|] contain [\|] all

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

auto

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

all elements, and optionally to the
[::before](https://www.w3.org/TR/css-pseudo-4/#selectordef-before) and
[::after](https://www.w3.org/TR/css-pseudo-4/#selectordef-after) pseudo-elements

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

specified keyword

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

User agents must not apply the
[user-select](#propdef-user-select) property to the
[::first-line](https://www.w3.org/TR/css-pseudo-4/#selectordef-first-line) and
[::first-letter](https://www.w3.org/TR/css-pseudo-4/#selectordef-first-letter) pseudo-elements.

 The UA may apply this property to the
[::before](https://www.w3.org/TR/css-pseudo-4/#selectordef-before) and
[::after](https://www.w3.org/TR/css-pseudo-4/#selectordef-after) pseudo-elements. If it does, the
[auto](#valdef-user-select-auto) value maps to a [used
value](https://www.w3.org/TR/css-cascade-5/#used-value) of
[none](#valdef-user-select-none) on these pseudos, but other values can be specified.
This preserves the legacy behavior of generated content not being
selectable or copyable, which is appropriate when these pseudos are used
for decorative purposes. However, this property allows them to become
selectable and copyable, as the user would expect in cases where they
are used to generate parts of the content, such as the issue numbers in
this document. **To the extent possible, authors should avoid using
generated content for non-decorative purposes, and should prefer
including all the content in the DOM.** *This feature is at risk.*

if we allow user-select to change to a
value other than
[none](#valdef-user-select-none), we need to figure out what this means for
copyability and DOM APIs.

When generated content in pseudo-elements becomes selectable through
this mechanism, UAs should also make this content findable through their
search function.

Should it also apply to
[::marker](https://www.w3.org/TR/css-pseudo-4/#selectordef-marker)? To [page-margin
boxes](https://www.w3.org/TR/css-page-3/#page-margin-boxes)? Should the [used
value](https://www.w3.org/TR/css-cascade-5/#used-value) of
[auto](#valdef-user-select-auto) also be
[none](#valdef-user-select-none), or would
[text](#valdef-user-select-text) be more appropriate?

The [used
value](https://www.w3.org/TR/css-cascade-5/#used-value) is the same as the [computed
value](https://www.w3.org/TR/css-cascade-5/#computed-value), except:

1. on [editable element](#editable-element)s where the [used
 value](https://www.w3.org/TR/css-cascade-5/#used-value) is always
 [contain](#valdef-user-select-contain) regardless of the [computed
 value](https://www.w3.org/TR/css-cascade-5/#computed-value)
2. when the [computed
 value](https://www.w3.org/TR/css-cascade-5/#computed-value) is
 [auto](#valdef-user-select-auto), in which case the [used
 value](https://www.w3.org/TR/css-cascade-5/#used-value) is one of the other values as defined below

For the purpose of this specification, an [editable
element]
is either an [editing
host](https://w3c.github.io/contentEditable/#dfn-editing-host) or a
[mutable](https://html.spec.whatwg.org/multipage/form-control-infrastructure.html#concept-fe-mutable) form control with textual content, such as
[`textarea`](https://html.spec.whatwg.org/multipage/form-elements.html#the-textarea-element).

Should there be constraints on what
happens to the used value on elements that are editable descendants of
editing hosts? The semantics are not obvious. Maybe
[none](#valdef-user-select-none) should map to
[text](#valdef-user-select-text), or maybe all values should map to
[text].

[auto]

: The [used
 value](https://www.w3.org/TR/css-cascade-5/#used-value) of
 [auto](#valdef-user-select-auto) is determined as follows:

 - On the
 [::before](https://www.w3.org/TR/css-pseudo-4/#selectordef-before) and
 [::after](https://www.w3.org/TR/css-pseudo-4/#selectordef-after) pseudo-elements, the used value is
 [none](#valdef-user-select-none)
 - If the element is an [editable
 element](#editable-element), the [used
 value](https://www.w3.org/TR/css-cascade-5/#used-value) is
 [contain](#valdef-user-select-contain)
 - Otherwise, if the [used
 value](https://www.w3.org/TR/css-cascade-5/#used-value) of
 [user-select](#propdef-user-select) on the parent of this element
 is [all](#valdef-user-select-all), the [used value] is
 [all]
 - Otherwise, if the [used
 value](https://www.w3.org/TR/css-cascade-5/#used-value) of
 [user-select](#propdef-user-select) on the parent of this element
 is
 [none](#valdef-user-select-none), the [used value]
 is [none]
 - Otherwise, the [used
 value](https://www.w3.org/TR/css-cascade-5/#used-value) is
 [text](#valdef-user-select-text)

 This unusual combination of a non-inherited
 property with an initial value of
 [auto](#valdef-user-select-auto) whose used value depends on the parent
 element makes it possible to create what is effectively selective
 inheritance. This was initially proposed by Microsoft in IE to
 introduce a behavior similar to inheritance, except that the
 [contain](#valdef-user-select-contain) value does not inherit.

[text]
: The element imposes no constraint on the selection.

[none]

: The UA must not allow selections to be started in this element.

 A selection started outside of this element must not end in this
 element. If the user attempts to create such a selection, the UA
 must instead end the selection range at the element boundary.

 As of the time of writing, experimental
 implementations do not all behave like this. Firefox does. Chrome
 and Safari almost do: for a selection started after the element and
 trying to go backwards into the element, they behave as specified
 here, but for a selection started before the element and trying to
 go into the element, they behave as if the element has
 [all](#valdef-user-select-all) and select it entirely. IE does not restrict
 selections started outside of the element from going into it at all.
 Another difference is that in Chrome and Safari, if the user
 attempts to start a selection inside a [user-select:
 none](#propdef-user-select), and to end the selection out of it, a
 selection will be created from the boundary of the element to the
 user-designated end point. Firefox and Internet Explorer behave as
 prescribed in this specification and do not create a selection at
 all.

 However, if this element has descendants on which the [used
 value](https://www.w3.org/TR/css-cascade-5/#used-value) of
 [user-select](#propdef-user-select) is not
 [none](#valdef-user-select-none), selections that start and end within these
 descendants are allowed.

 The UA must allow selections to extend across this element, and must
 exclude this element from such a selection. An exception is made for
 UAs which do not support multiple ranges per selection, and they may
 include this element. If the element has descendants on which the
 [used
 value](https://www.w3.org/TR/css-cascade-5/#used-value) of
 [user-select](#propdef-user-select) is not
 [none](#valdef-user-select-none), these descendants must be included in a
 selection extending across the element. [This specification makes no
 normative requirement about the behavior of the clipboard. However,
 UAs are encouraged to keep the visual selection consistent with what
 would get copied to the clipboard when copying. Copying text that
 does not appear to be selected, or vice versa, is highly confusing
 to users.]

 Attempting to start a selection in an element where
 [user-select](#propdef-user-select) is
 [none](#valdef-user-select-none), such as by clicking in it or starting a
 drag in it, must not cause a pre-existing selection to become
 unselected or to be affected in any way.

 As
 [user-select](#propdef-user-select) is a UI convenience mechanism,
 not a copy protection mechanism, the UA may provide an alternative
 way for the user to explicitly select the text even when
 [user-select] is
 [none](#valdef-user-select-none).

 [none](#valdef-user-select-none) is not a copy protection mechanism, and
 using it as such is ineffective: user agents are allowed to provide
 ways to bypass it, it will have no effect on legacy user agents that
 do not support it, and the user can disable it through the user
 style sheet or equivalent mechanisms on UAs that do anyway. Instead,
 [none] is meant to make it
 easier for the user to select the content they want by letting the
 author disable selection on UI elements that are not useful to
 select. Tools such as CSS validators, linters, or in-browser
 developer tools are encouraged to use heuristics to detect and warn
 against incorrect or abusive usage that would hamper usability or
 violate common user expectations.

 :::
 Authors should be careful about not constraining the user
 unnecessarily. For example, setting [user-select:
 none](#propdef-user-select) on the root element, and relaxing that
 restriction on a handful of elements the author judges useful to
 select can be frustrating to users:
 - Clicking in empty areas to undo the current selection will no
 longer be effective

 - The author may have overlooked some areas which should be
 selectable

 - Areas may be added later to the page without remembering to make
 them selectable

 - The user may want to select pieces of text other than the main
 content, for instance to look them up in a dictionary or in some
 translation tool, or to look for warnings and error messages in a
 search engine...

 Instead, a good practice is for authors is to selectively apply
 [user-select:
 none](#propdef-user-select) to elements which seem likely to be
 accidentally selected when doing so would interfere with the more
 likely intended action. Accidentally leaving parts of the page that
 are unlikely to be interacted with selectable will likely cause much
 less frustration to users than the opposite.
 :::

[contain]

: UAs must not allow a selection which is started in this element to
 be extended outside of this element.

 A selection started outside of this element must not end in this
 element. If the user attempts to create such a selection, the UA
 must instead end the selection range at the element boundary.

 The UA must allow selections to extend across this element, and such
 selections must include the content of the element.

 At the time of writing, experimental
 implementations behave differently from each other about selections
 started outside and selections going into the element. The behavior
 can be observed even on browsers that do not explicitly support
 [contain](#valdef-user-select-contain) by trying to select into a
 [`textarea`](https://html.spec.whatwg.org/multipage/form-elements.html#the-textarea-element) or a contenteditable element.

 This was initially introduced as an experimental
 feature in Internet Explorer, under the name `user-select: element`.

[all]

: The content of the element must be selected atomically: If a
 selection would contain part of the element, then the selection must
 contain the entire element including all its descendants. If the
 element is selected and the [used
 value](https://www.w3.org/TR/css-cascade-5/#used-value) of
 [user-select](#propdef-user-select) on its parent is
 [all](#valdef-user-select-all), then the parent must be included in the
 selection, recursively.

 If this element has descendants on which the [used
 value](https://www.w3.org/TR/css-cascade-5/#used-value) of
 [user-select](#propdef-user-select) is not
 [all](#valdef-user-select-all) and if a selection is entirely contained in these
 descendants, then the selection is not extended to include this
 whole element.

 Selections can include more than just text and extend
over images, tables, videos, etc. The behavior when copying and pasting
such selections is out of scope for this specification.

The following additions are made to the UA stylesheet for HTML:

```
button, meter, progress, select { user-select: none; }
```

the list above is incomplete and needs
to include at least the various button-like variants of
[`input`](https://html.spec.whatwg.org/multipage/input.html#the-input-element).

For compatibility with legacy content, UAs that support
[user-select](#propdef-user-select) must also support
[-webkit-user-select] as an alias.

 The details of the aliasing mechanism is intentionally
left up to the UA. Making [-webkit-user-select] a shorthand
property of
[user-select](#propdef-user-select) is known to be an effective approach,
and new implementers should consider it. However, UAs supporting
[-webkit-user-select] as an alias of
[user-select] through other
means exist without adverse consequences to compatibility, so this
specification allows flexibility.

### 6.2. Exclusion from Hit-testing: the [pointer-events property]
While this property modifies the normal
behavior of hit-testing, this normal [hit-testing] is currently not specified.
There is broad interoperability about the seemingly obvious parts of
this problem, but there are countless nuances and corner cases that
would greatly benefit from a detailed specification. The CSS-WG would
hugely appreciate help with writing such a specification.

Name:

[pointer-events]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

auto
[\|](https://www.w3.org/TR/css-values-4/#comb-one) none

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

[auto](#valdef-pointer-events-auto)

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[all
elements](https://www.w3.org/TR/css-pseudo/#generated-content "Includes ::before and ::after pseudo-elements.")

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

yes

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

N/A

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

specified keyword

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value type

The
[pointer-events](#propdef-pointer-events) property defines whether an
element's boxes can be targeted by point pointer events. Values have the
following meanings:

[auto]
: [Hit-testing](#hit-testing)
 occurs normally.

[none]

: [Hit-testing](#hit-testing)
 acts as if the boxes generated by the element (see
 [\[CSS-DISPLAY-3\]](#biblio-css-display-3 "CSS Display Module Level 3"))
 were not there, effectively causing the element behind the
 [pointer-events:
 none](#propdef-pointer-events) element to become the target of
 hit-testing-based events instead.

 (#issue-02391685) The statement above needs to be
 qualified; for some purposes, hit-testing continues to take the
 element into account. For instance, clicking and dragging to start a
 text selection will continue to work as usual. What is the precise
 set of things for which hit-testing is affected by
 [pointer-events](#propdef-pointer-events)?

[pointer-events:
none](#propdef-pointer-events) does not inhibit [sequential focus
navigation](https://html.spec.whatwg.org/multipage/interaction.html#sequential-focus-navigation).

 This [pointer-events:
none](#propdef-pointer-events) only excludes the element itself from
[hit-testing](#hit-testing), not
the whole subtree. While this property propagates to descendants via
inheritance, [pointer-events: auto] can be specified on a descendant of a [pointer-events:
none] element, and such an
element will participate normally in
[hit-testing].

 Events that target a [pointer-events:
auto](#propdef-pointer-events) descendant of a [pointer-events:
none] element can still be caught
by event handlers on [pointer-events:
none] ancestors of the targeted
element during the bubbling or capturing phases (see [DOM § 2
Events](https://dom.spec.whatwg.org/#events)).

 [SVG 2 § 15.6 The 'pointer-events'
property](https://www.w3.org/TR/SVG2/interact.html#PointerEventsProp)
defines a variant of this property for SVG elements, with more possible
values. The effect of such values outside of SVG is currently not
defined.

### 6.3. Preventing All Interaction: the [interactivity property]
Name:

[interactivity]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

auto
[\|](https://www.w3.org/TR/css-values-4/#comb-one) inert

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

auto

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[all
elements](https://www.w3.org/TR/css-pseudo/#generated-content "Includes ::before and ::after pseudo-elements.")

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

The
[interactivity](#propdef-interactivity) property specifies whether an
element and its [flat
tree](https://drafts.csswg.org/css-shadow-1/#flat-tree) descendants (including [text
nodes](https://www.w3.org/TR/css-display-4/#text-nodes)) are [inert](#inert) or
not.

[auto]

: The element's [inertness](#inert)
 is determined by the [host
 language](https://www.w3.org/TR/selectors-4/#host-language). [(This will *usually* mean the element is not
 [inert](#inert).)]

[inert]

: The element is [inert](#inert).

When an
[element](https://dom.spec.whatwg.org/#concept-element) or [text
node](https://www.w3.org/TR/css-display-4/#text-nodes) is [inert]:

- Hit-testing must act as if
 [pointer-events](#propdef-pointer-events) was
 [none](#valdef-pointer-events-none), regardless of its actual value.

- Text selection must act as if
 [user-select](#propdef-user-select) was
 [none](#valdef-user-select-none), regardless of its actual value.

- If the
 [element](https://dom.spec.whatwg.org/#concept-element) or [text
 node](https://www.w3.org/TR/css-display-4/#text-nodes) is editable, it must behave as if it was
 non-editable.

- The
 [element](https://dom.spec.whatwg.org/#concept-element) or [text
 node](https://www.w3.org/TR/css-display-4/#text-nodes) should be ignored for the purposes of find-in-page
 and similar searching actions.

User agents may allow the user to override the restrictions on
find-in-page and text selection.

 This property allows an author to force an element
[inert](#inert), but doesn't allow
making an element \*non\*-[inert], just deferring
inertness to the host language. For example, in HTML, while a modal
dialog is being displayed, the rest of the page is forced inert
automatically, regardless of the value of this property. In general,
host languages can make use of more information about the document than
CSS has easy access to to determine what the best inertness behavior is
for users.

 [Inert](#inert) nodes
generally cannot be focused, and user agents do not expose the inert
nodes to accessibility APIs or assistive technologies. An inert subtree
should not contain any content or controls which are critical to
understanding or using aspects of the page which are not in the inert
state. Content in an inert subtree will not be perceivable by all users,
or interactive. Authors should not specify elements as inert unless the
content they represent are also visually obscured in some way. In most
cases, authors should not specify the inert attribute on individual form
controls. In these instances, the
[`disabled`](https://html.spec.whatwg.org/multipage/form-control-infrastructure.html#attr-fe-disabled) attribute is probably more appropriate.

The following should be inserted into
the HTML stylesheet, to ensure that top-level modal dialogs become
uninert by default:

``` highlight
[inert] {
 interactivity: inert;
}
dialog:modal {
 interactivity: auto;
}
```

The [dialog:modal] selector above needs to be expanded for any
other elements that escape inertness by default.

### [6.4. ][ User Interest Delay: the [interest-delay-\*] properties]
Name:

[interest-delay-start],
[interest-delay-end]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

normal
[\|](https://www.w3.org/TR/css-values-4/#comb-one)
[\<time\>](https://www.w3.org/TR/css-values-4/#time-value)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

[normal](#valdef-interest-delay-normal)

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[all
elements](https://www.w3.org/TR/css-pseudo/#generated-content "Includes ::before and ::after pseudo-elements.")

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

yes

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

the keyword
[normal](#valdef-interest-delay-normal) or a computed time

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value type

Name:

[interest-delay]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<\'interest-delay-start\'\>](#propdef-interest-delay-start)[{1,2}](https://www.w3.org/TR/css-values-4/#mult-num-range)

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

Some [host
language](https://www.w3.org/TR/selectors-4/#host-language) features can be activated when a user [shows
interest](https://drafts.csswg.org/selectors-5/#show-interest) in an element. Exactly what this means is up to the
[host language] and [user
agent](https://infra.spec.whatwg.org/#user-agent) (for example, the HTML [`interestfor`]
attribute), but a common property of such features is that \"interest\"
shouldn't be gained or lost *instantly*.

For example, if \"interest\" can be shown by hovering the cursor over an
element, briefly passing the cursor over the element while moving the
cursor over the page should not (at least by default) indicate
\"interest\"---​that could result in UI confusingly popping up and
disappearing while the user is performing unrelated tasks.

Similarly, once interest has been shown, the [interest
source](https://www.w3.org/TR/selectors-5/#interest-source) should not (at least by default) *lose* interest
instantaneously either. Again, as an example, if the user [shows
interest](https://drafts.csswg.org/selectors-5/#show-interest) in a link by hovering the cursor over it, causing a
child popup list to appear next to it, moving the cursor from the link
to the popup likely involves briefly leaving both the link and the list,
but shouldn't cause the list to \"lose interest\" and close the popup.

The
[interest-delay](#propdef-interest-delay) shorthand, and its
[interest-delay-start](#propdef-interest-delay-start) and
[interest-delay-end](#propdef-interest-delay-end) longhands, allow control of the
[interest start delay] and [interest end delay] for these features on a
given element. Its possible values are:

[normal]

: The [interest start
 delay](#interest-start-delay) and/or the [interest end
 delay](#interest-end-delay) are UA-defined. They can be chosen to match
 platform conventions.

 These delays *should not* be zero. They *may* be different from each
 other, and may vary depending on the way the user is showing
 interest. (For example, a \"hover\" and a \"long press\" might use
 different delays for indicating interest.)

[[\<time\>](https://www.w3.org/TR/css-values-4/#time-value)]

: Specifies that the [interest start
 delay](#interest-start-delay) and/or the [interest end
 delay](#interest-end-delay) are the specified duration.

The
[interest-delay](#propdef-interest-delay) shorthand sets
[interest-delay-start](#propdef-interest-delay-start) to its first value, and
[interest-delay-end](#propdef-interest-delay-end) to its second value (or to the
first value, if only one value is passed).

 In the future, the syntax of these properties might be
expanded to allow for customizing the delay depending on feature and how
the user is showing interest. (For example, providing different delays
for hovering vs long-pressing.)

## 7. Styling Widgets

### 7.1. Widget Accent Colors: the [accent-color property]
Name:

[accent-color]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

auto
[\|](https://www.w3.org/TR/css-values-4/#comb-one)
[\<color\>](https://www.w3.org/TR/css-color-5/#typedef-color)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

[auto](#valdef-accent-color-auto)

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[all
elements](https://www.w3.org/TR/css-pseudo/#generated-content "Includes ::before and ::after pseudo-elements.")

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

yes

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

N/A

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

the keyword
[auto](#valdef-accent-color-auto) or a computed color

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value type

User interface controls on any given platform are typically designed as
a cohesive set, under a single, cohesive visual style. On many platforms
(though not all), the visual style includes the use of an [accent
color], a
typically bright color that contrasts markedly with the more utilitarian
background and foreground colors. Not every control uses the [accent
color](#accent-color) in every
state, but it is nonetheless a core part of the controls' color scheme.

The [accent-color](#propdef-accent-color) CSS property allows the author to
specify the [accent color](#accent-color) for user-interface controls generated by the element.
Values have the following meanings:

[auto]
: Represents a UA-chosen color, which should match the [accent
 color](#accent-color) of the
 platform, if any.

[[\<color\>](https://www.w3.org/TR/css-color-5/#typedef-color)]
: Specifies the color to be used as the [accent
 color](#accent-color).

The UA should use the specified
[accent-color](#propdef-accent-color) to draw whichever parts of the
element's control(s) would have otherwise been styled with an [accent
color](#accent-color). The UA
must maintain contrast for legibility of the control, and in order to do
so may adjust the luminance or brightness of the color or make color
substitutions in other parts of the control (e.g. switching an overlaid
glyph from using
[color](https://www.w3.org/TR/css-color-4/#propdef-color) to using
[background-color](https://www.w3.org/TR/css-backgrounds-3/#propdef-background-color)). It may also generate variations
of the color for gradients etc. to match the control to platform
conventions for the use of the accent color.

A radio button is typically composed
of a circle, potentially overlaid by a "dot" representing the checked
state. Certain visual styles use an [accent
color](#accent-color) for the
checked state: some of these use it for the background of the circle,
others for its foreground.

In both cases, the
[accent-color](#propdef-accent-color) property styles the affected parts
of the control. For visual styles that do not use an [accent
color](#accent-color) for radio
buttons, [accent-color] will
have no effect.

The following are all examples of radio buttons conformantly rendered
with a blue
[accent-color](#propdef-accent-color):

Platform

Sample

Notes

Firefox 79 / Win

![Unchecked: white-filled black-stroked
circle.](images/radio-ff79-empty.png){height="42" width="37"} ![Checked:
white-filled black-stroked circle with a filled black circle
inside.](images/radio-ff79-check.png){height="42" width="36"}

No use of [accent color](#accent-color).

Chrome 81 / Win

![Unchecked: light gray shaded circular
bubble.](images/radio-c81-empty.png){height="35" width="32"} ![Checked:
light gray shaded circular bubble overlaid with a dark grey
circle.](images/radio-c81-check.png){height="39" width="34"}

No use of [accent color](#accent-color).

Safari / Snow Leopard

![Unchecked: uncolored 3D-looking glassy
bubble.](images/radio-aqua-empty.png){height="31" width="32"} ![Checked:
light blue 3D-looking glassy bubble overlaid with a small black
dot.](images/radio-aqua-check.png){height="28" width="31"}

Accent color used to generate checked-state "background" gradient.

Safari 13 / Mac / Light

![Unchecked: light gray inset-shadowed
circle.](images/radio-s13L-empty.png){height="39" width="42"} ![Checked:
bright blue filled circle overlaid with a small, drop-shadowed white
dot.](images/radio-s13L-check.png){height="46" width="43"}

Accent color as checked-state "foreground".

Safari 13 / Mac / Dark

![Unchecked: dark gray circle shaded to look embossed but with a convex
surface.](images/radio-s13D-empty.png){height="42" width="44"}
![Checked: bright blue filled circle shaded to look embossed, overlaid
with a small white dot.](images/radio-s13D-check.png){height="42"
width="42"}

Accent color as checked-state "foreground".

Chrome 83 / Win / Light

![Unchecked: dark gray empty
circle.](images/radio-c83-empty.png){height="33" width="37"} ![Checked:
bright blue stroked circle overlaid with concentric bright blue filled
circle.](images/radio-c83-check.png){height="41" width="49"}

Accent color as checked-state "foreground".

Chrome 83 / Win / Dark

![Unchecked: light gray circle filled with dark
gray.](images/radio-c86-empty.png){height="36" width="34"} ![Checked:
bright powder-blue stroked circle overlaid with concentric powder-blue
filled circle.](images/radio-c86-check.png){height="34" width="33"}

Accent color as checked-state "foreground", contrast-adjusted for dark
mode backgrounds.

If the color supplied is partially or fully transparent, the user agent
must first pre-compose it over the
[Canvas](https://www.w3.org/TR/css-color-4/#valdef-color-canvas) system color and use the resulting (now opaque)
color as the accent color.

 Although it may vary based on user settings,
[Canvas](https://www.w3.org/TR/css-color-4/#valdef-color-canvas) is typically white when in a [light color
scheme](https://www.w3.org/TR/css-color-adjust-1/#light-color-scheme) and black when in a [dark color
scheme](https://www.w3.org/TR/css-color-adjust-1/#dark-color-scheme).

### 7.2. Switching appearance: the [appearance property]
Name:

[appearance]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[none](#valdef-appearance-none)
[\|](https://www.w3.org/TR/css-values-4/#comb-one)
[auto](#valdef-appearance-auto) [\|]
[base](#valdef-appearance-base) [\|]
[base-select](#valdef-appearance-base-select) [\|]
[\<compat-auto\>](#typedef-appearance-compat-auto) [\|]
[\<compat-special\>](#typedef-appearance-compat-special)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

none

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[all
elements](https://www.w3.org/TR/css-pseudo/#generated-content "Includes ::before and ::after pseudo-elements.")

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

specified keyword

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

While the way most elements in a document look can be fully controlled
by CSS, [widgets](#widget) are
typically rendered by UAs using native UI controls of the host operating
system, which can neither be replicated nor styled using CSS.

The term [widget] in
this specification denotes
[replaced](https://www.w3.org/TR/css-display-4/#replaced-element) elements that can have [native
appearance], meaning
that they are rendered like analogous native widgets or controls of the
host operating system or platform, or with a look and feel not otherwise
expressible in CSS. It is up to the host language (e.g., HTML
[\[HTML\]](#biblio-html "HTML Standard")) to define
which elements can have [native
appearance](#native-appearance).

This specification introduces the
[appearance](#propdef-appearance) property to provide some control over
this behavior. In particular, using [appearance:
none] allows authors to suppress the
[native appearance](#native-appearance) of [widgets](#widget), giving them a [primitive
appearance] where CSS can be used to restyle them.

Using [appearance:
base](#propdef-appearance) gives [widgets](#widget) a [base appearance].
[Widgets] in base appearance have their [native
appearance](#native-appearance) suppressed where CSS can be used to restyle them, just
like [primitive
appearance](#primitive-appearance), but also have default styles which are usable and
interoperable. This is unlike [primitive
appearance] which can cause some
[widgets] to disappear completely.

A widget can have some style sheet associated with it and those styles
can change based on whether the widget has a base appearance. Native
appearance and primitive appearance should have the same styles.

[appearance:base] is not ready to
ship until its stylesheet has been fully defined in the HTML
specification, and implemented accordingly for all HTML form controls.

Note on the history of this feature

This previously existed in prefixed form in most browsers. Before
standardization, in addition to
[none](#valdef-appearance-none), the possible values were a very long list of all the
ways an element could look; each value being responsible for giving form
controls their specific look and feel. This list was different across
browsers.

The CSS Working Group concluded this was impractical to standardize, in
part because many values applied to pseudo-elements that other browsers
don't have, as they construct form elements differently, and which
should not be standardized, since the ability to make form controls look
substantially different on different platforms should be preserved.

Also, the ability to turn any arbitrary element (including any form
control) into any (other) arbitrary form control is considered a
misfeature.

Instead, the design being specified is based on just having an \"auto\"
value that makes form controls look like whatever they need, and a
\"none\" value that suppresses [native
appearance](#native-appearance).

However, there is evidence that this alone is not web compatible, due in
part to uses such as:

``` highlight
input { appearance: none; }
input[type=checkbox] { appearance: checkbox; }
```

The design specified here is a compromise between the two, preserving
the simplicity of the [none \| auto] model while maintaining
compatibility with existing content via a few additional keywords.

The precise list of keywords needed for compatibility and their exact
behavior is likely to be refined in a future version of this
specification to better handle compatibility with existing content. The
CSS-WG welcomes relevant feedback.

[none]
: The element is rendered following the usual rules of CSS. Replaced
 elements other than [widgets](#widget) are not affected by this and remain replaced
 elements. [Widgets] must not have their [native
 appearance](#native-appearance), and instead must have their [primitive
 appearance](#primitive-appearance). See [§ 7.2.2 Effects of appearance on Decorative
 Aspects of Elements](#appearance-decorative) and [§ 7.2.3 Effects of
 appearance on Semantic Aspects of Elements](#appearance-semantics)
 for details.

[auto]

: The element's box is laid out like a regular replaced element.

 Within that box, elements representing
 [widgets](#widget) should have the
 [native appearance](#native-appearance) of that widget.

 The host language is responsible for defining which elements
 represent which [widgets](#widget).

 Elements other than [widgets](#widget) must be rendered as for
 [none](#valdef-appearance-none).

[base]
: The effect of
 [base](#valdef-appearance-base) depends on the element it is applied to:

 elements other than [widgets](#widget)

 : Elements other than [widgets](#widget) must be rendered as for
 [none](#valdef-appearance-none).

 [Widgets](#widget) which support [base appearance](#base-appearance)

 : Just like
 [none](#valdef-appearance-none), the element is rendered following the
 usual rules of CSS. [Widgets](#widget) must not have their [native
 appearance](#native-appearance), and instead must have their [base
 appearance](#base-appearance).

 [Widgets](#widget) which don't support [base appearance](#base-appearance)

 : [Widgets](#widget) which
 don't have a [base
 appearance](#base-appearance) must be rendered as for
 [auto](#valdef-appearance-auto). The host language is responsible for
 defining which [widgets] have a [base
 appearance].

[base-select]
: The effect of
 [base-select](#valdef-appearance-base-select) depends on the element it is applied to:

 The [`select`](https://html.spec.whatwg.org/multipage/form-elements.html#the-select-element) element or [::picker(select)]

 : The element is rendered as for
 [base](#valdef-appearance-base).

 Everything else

 : The element is rendered as for
 [auto](#valdef-appearance-auto).

[\<compat-auto\>]

: These values exist for compatibility of content developed for
 earlier non-standard versions of this property. They all have the
 same effect as
 [auto](#valdef-appearance-auto).

 ```
 <compat-auto> = searchfield | textarea | checkbox | radio | menulist | listbox | meter | progress-bar | button
 ```

 (#issue-fa64f3f3) When
 [auto](#valdef-appearance-auto) is widely supported, recommend using it
 instead.

 (#issue-7a288805) If any of these values are not
 needed for web compat, they should be dropped from this list;
 conversely, any value needed for compat not included in this list
 should be added.

 (#issue-1e87e1a4) It is possible that for compat
 reasons some of these values need to be promoted to being full blown
 values with effects on arbitrary elements, or that some of these
 values need to have some side effects on some
 [widgets](#widget).

[\<compat-special\>]

: These values exist for compatibility of content developed for
 earlier non-standard versions of this property. For the purpose of
 this specification, they all have the same effect as
 [auto](#valdef-appearance-auto). However, the host language may also take
 these values into account when defining the [native
 appearance](#native-appearance) of the element.

 ```
 <compat-special> = textfield | menulist-button
 ```

 :::
 (#example-37d558f3) For instance, in
 [\[HTML\]](#biblio-html "HTML Standard"):
 - The native appearance of
 [`input`](https://html.spec.whatwg.org/multipage/input.html#the-input-element) elements with a `"search"`
 [`type`](https://html.spec.whatwg.org/multipage/input.html#attr-input-type) attribute changes to match the appearance
 of
 [`input`](https://html.spec.whatwg.org/multipage/input.html#the-input-element) elements with a `"text"`
 [`type`](https://html.spec.whatwg.org/multipage/input.html#attr-input-type) attribute when
 [appearance](#propdef-appearance) is
 [textfield](#valdef-appearance-textfield).

 - The native appearance of drop-down box
 [`select`](https://html.spec.whatwg.org/multipage/form-elements.html#the-select-element) elements changes to match that of its
 [devolved](#devolved) state
 when
 [appearance](#propdef-appearance) is
 [menulist-button](#valdef-appearance-menulist-button).
 :::

The values `slider-vertical` and
`sliderthumb-vertical` are supported in some user agents to change the
orientation of `<input type=range>` elements.
These values are not specified because changing the orientation of this
control is better done with a separate mechanism. See issue
[whatwg/html#4177](https://github.com/whatwg/html/issues/4177).

An author wanting to customize the
look and feel of check boxes in HTML could use the following:

```
input[type=checkbox] {
 all: unset; /* this shorthand includes resetting appearance to none */
 width: 1em;
 height: 1em;
 display: inline-block;
 background: red;
}
input[type=checkbox]:checked {
 border-radius: 50%;
 background: green;
}
input[type=checkbox]:focus-visible {
 outline: auto;
}
```

`<input type="checkbox">` would be rendered as
{style="display: inline-block; width: 1em; height: 1em; background: red;"},
while `<input type="checkbox" checked>` would
be rendered as
{style="display: inline-block; width: 1em; height: 1em; background: green; border-radius: 50%;"},
and activating (for example by clicking) the element would toggle the
state as usual.

User agents may [disregard](#disregard) some CSS properties used to size and paint the contents
of [widgets](#widget) rendered with
their [native
appearance](#native-appearance) to ensure that the intended appearance is preserved, or
because these properties may not be meaningful for the chosen
appearance.

[Disregarding] a property means that the user agent treats
it as if it didn't [apply
to](https://www.w3.org/TR/css-cascade-5/#apply) the widget in question. Nevertheless, unless an
explicit exception is specified (for compatibility reasons), the user
agent must still determine the [computed
value](https://www.w3.org/TR/css-cascade-5/#computed-value) of any [disregarded](#disregard) property according to the usual rules.

In more detail, the rules for disregarding properties for [natively
rendered](#native-appearance) widgets are:

- CSS properties that impact the box sizing or position of the widget's
 box (such as the [sizing
 properties](https://www.w3.org/TR/css-sizing-3/#sizing-property)), or their visual appearance outside of the box (such
 as
 [transform](https://www.w3.org/TR/css-transforms-1/#propdef-transform),
 [filter](https://www.w3.org/TR/filter-effects-1/#propdef-filter) or
 [box-shadow](https://www.w3.org/TR/css-borders-4/#propdef-box-shadow)), must be applied to
 [widgets](#widget) rendered with
 their [native
 appearance](#native-appearance). The widget's box participates in the rest of layout
 like any other replaced element.
- Properties that affect the internal box model sizing of the widget's
 box (such as
 [box-sizing](https://www.w3.org/TR/css-sizing-3/#propdef-box-sizing),
 [padding](https://www.w3.org/TR/css-box-4/#propdef-padding),
 [border](https://www.w3.org/TR/css-borders-4/#propdef-border) or
 [margin](https://www.w3.org/TR/css-box-4/#propdef-margin)) may be disregarded when needed.
- Other properties that affect painting (like
 [background-color](https://www.w3.org/TR/css-backgrounds-3/#propdef-background-color)) may be disregarded when needed.
- User agents should take into account CSS properties that affect
 writing modes or font-related properties when possible, when rendering
 text within the widget.
- The
 [object-fit](https://www.w3.org/TR/css-images-4/#propdef-object-fit) property does not apply.

Some user agents respect the
[border](https://www.w3.org/TR/css-borders-4/#propdef-border) and
[padding](https://www.w3.org/TR/css-box-4/#propdef-padding) CSS properties for a \<select\>
rendered with [native
appearance](#native-appearance), but not for \<input type=checkbox\>.

Native rendering of widgets may overflow the size of its box if its
intrinsic sizing exceeds that size.

For compatibility with legacy content, UAs must also support
[-webkit-appearance] as a [legacy name
alias](https://www.w3.org/TR/css-cascade-5/#legacy-name-alias) of
[appearance](#propdef-appearance).

#### 7.2.1. Properties Disabling Native Appearance

Certain properties, when declared in the [Author
Origin](https://www.w3.org/TR/css-cascade-5/#cascade-origin-author), will disable the [native
appearance](#native-appearance) of certain [widgets](#widget). Specifically, if all the declarations of the [Author
Origin] pertaining to such a
[widget] are cascaded and a [cascaded
value](https://www.w3.org/TR/css-cascade-5/#cascaded-value) exists---​after having rolled back any number
[revert](https://www.w3.org/TR/css-cascade-5/#valdef-all-revert) or
[revert-layer](https://www.w3.org/TR/css-cascade-5/#valdef-all-revert-layer) values---​for any [property that disables native
appearance for
widgets](#property-that-disables-native-appearance-for-widgets), then that [widget] is rendered as a
[devolved widget](#devolved). The
rendering of a [devolved widget] is identical to
that of the [widget] in its [primitive
appearance](#primitive-appearance), except when specified otherwise by the host language.

The host language defines which elements represent [devolvable
widgets]. Widgets whose appearance remains
native regardless of any [properties that disable native appearance for
widgets](#property-that-disables-native-appearance-for-widgets) are called [non-devolvable widgets].

The [properties that disable native appearance for
widgets] are:

- [background-color](https://www.w3.org/TR/css-backgrounds-3/#propdef-background-color)
- [border-top-color](https://www.w3.org/TR/css-borders-4/#propdef-border-top-color)
- [border-top-style](https://www.w3.org/TR/css-borders-4/#propdef-border-top-style)
- [border-top-width](https://www.w3.org/TR/css-borders-4/#propdef-border-top-width)
- [border-right-color](https://www.w3.org/TR/css-borders-4/#propdef-border-right-color)
- [border-right-style](https://www.w3.org/TR/css-borders-4/#propdef-border-right-style)
- [border-right-width](https://www.w3.org/TR/css-borders-4/#propdef-border-right-width)
- [border-bottom-color](https://www.w3.org/TR/css-borders-4/#propdef-border-bottom-color)
- [border-bottom-style](https://www.w3.org/TR/css-borders-4/#propdef-border-bottom-style)
- [border-bottom-width](https://www.w3.org/TR/css-borders-4/#propdef-border-bottom-width)
- [border-left-color](https://www.w3.org/TR/css-borders-4/#propdef-border-left-color)
- [border-left-style](https://www.w3.org/TR/css-borders-4/#propdef-border-left-style)
- [border-left-width](https://www.w3.org/TR/css-borders-4/#propdef-border-left-width)
- [border-block-start-color](https://www.w3.org/TR/css-borders-4/#propdef-border-block-start-color)
- [border-block-end-color](https://www.w3.org/TR/css-borders-4/#propdef-border-block-end-color)
- [border-inline-start-color](https://www.w3.org/TR/css-borders-4/#propdef-border-inline-start-color)
- [border-inline-end-color](https://www.w3.org/TR/css-borders-4/#propdef-border-inline-end-color)
- [border-block-start-style](https://www.w3.org/TR/css-borders-4/#propdef-border-block-start-style)
- [border-block-end-style](https://www.w3.org/TR/css-borders-4/#propdef-border-block-end-style)
- [border-inline-start-style](https://www.w3.org/TR/css-borders-4/#propdef-border-inline-start-style)
- [border-inline-end-style](https://www.w3.org/TR/css-borders-4/#propdef-border-inline-end-style)
- [border-block-start-width](https://www.w3.org/TR/css-borders-4/#propdef-border-block-start-width)
- [border-block-end-width](https://www.w3.org/TR/css-borders-4/#propdef-border-block-end-width)
- [border-inline-start-width](https://www.w3.org/TR/css-borders-4/#propdef-border-inline-start-width)
- [border-inline-end-width](https://www.w3.org/TR/css-borders-4/#propdef-border-inline-end-width)
- [background-image](https://www.w3.org/TR/css-backgrounds-4/#propdef-background-image)
- [background-attachment](https://www.w3.org/TR/css-backgrounds-3/#propdef-background-attachment)
- [background-position](https://www.w3.org/TR/css-backgrounds-3/#propdef-background-position)
- [background-clip](https://www.w3.org/TR/css-backgrounds-3/#propdef-background-clip)
- [background-origin](https://www.w3.org/TR/css-backgrounds-3/#propdef-background-origin)
- [background-size](https://www.w3.org/TR/css-backgrounds-3/#propdef-background-size)
- [border-image-source](https://www.w3.org/TR/css-borders-4/#propdef-border-image-source)
- [border-image-slice](https://www.w3.org/TR/css-borders-4/#propdef-border-image-slice)
- [border-image-width](https://www.w3.org/TR/css-borders-4/#propdef-border-image-width)
- [border-image-outset](https://www.w3.org/TR/css-borders-4/#propdef-border-image-outset)
- [border-image-repeat](https://www.w3.org/TR/css-borders-4/#propdef-border-image-repeat)
- [border-top-left-radius](https://www.w3.org/TR/css-borders-4/#propdef-border-top-left-radius)
- [border-top-right-radius](https://www.w3.org/TR/css-borders-4/#propdef-border-top-right-radius)
- [border-bottom-right-radius](https://www.w3.org/TR/css-borders-4/#propdef-border-bottom-right-radius)
- [border-bottom-left-radius](https://www.w3.org/TR/css-borders-4/#propdef-border-bottom-left-radius)
- [border-start-start-radius](https://www.w3.org/TR/css-borders-4/#propdef-border-start-start-radius)
- [border-start-end-radius](https://www.w3.org/TR/css-borders-4/#propdef-border-start-end-radius)
- [border-end-start-radius](https://www.w3.org/TR/css-borders-4/#propdef-border-end-start-radius)
- [border-end-end-radius](https://www.w3.org/TR/css-borders-4/#propdef-border-end-end-radius)

#### 7.2.2. Effects of [appearance on Decorative Aspects of Elements]
All decorative visual aspects of a [widget](#widget) which are not caused by a CSS style rule must be
suppressed when the appearance is changed from
[native](#native-appearance) to
[primitive](#primitive-appearance) using
[appearance](#propdef-appearance), even if the UA's internal
representation for this element was composed of multiple elements or
pseudo-elements combined together.

For example, the
[\[HTML\]](#biblio-html "HTML Standard")
[`select`](https://html.spec.whatwg.org/multipage/form-elements.html#the-select-element) element is often rendered with an arrow on the
right side indicating that the list will be expanded if the element is
clicked. If the computed value of
[appearance](#propdef-appearance) on a
[`select`](https://html.spec.whatwg.org/multipage/form-elements.html#the-select-element) element is
[none](#valdef-appearance-none), this must disappear.

UAs should include in their user agent stylesheet style rules to give
[widgets](#widget) a recognizable
shape when
[appearance](#propdef-appearance) is
[none](#valdef-appearance-none).

 Authors may therefore need to override these UA style
rules to get the styling they intended.

Authors may find it convenient to use [all:
unset](https://www.w3.org/TR/css-cascade-5/#propdef-all) to get fully unstyled
[widgets](#widget), which they can
then style as they want without interference from the user agent's
stylesheet. However, this also suppresses the focus indicators provided
by the same UA stylesheet. In order to avoid damaging accessibility,
authors who do so should restore a focus indicator, for instance, by
using [:focus-visible { outline: auto; }].

#### 7.2.3. Effects of [appearance on Semantic Aspects of Elements]
When showing the [primitive
appearance](#primitive-appearance) of a [widget](#widget) or its [devolved](#devolved) state, user agents must preserve aspects of the
[widget] which are necessary to operate the
[widget] with its original semantics. The UA may,
however, give them a different look and feel as long as it remains
possible to operate the [widget]. Aspects of a
[widget] which are merely needed to observe the state
the [widget] is in and are not needed to operate it
should be suppressed as well when the same information can be conveyed
using ordinary CSS. Document languages should specify for each
[widget] that they define what needs to be preserved.

For example, the slider of an
`<input type=range>` is preserved (or replaced
by an equivalent mechanism) even if
[appearance](#propdef-appearance) is
[none](#valdef-appearance-none), as it would otherwise not be possible to change the
value of the range with the mouse or touchscreen.

On the other hand, the check mark in an
`<input type=checkbox checked>` must be
suppressed, as it merely indicates the state the element is in, which
can be styled in different ways using the
[:checked](https://www.w3.org/TR/selectors-4/#checked-pseudo) selector.

The behavior and semantics of elements remain defined by the document
language, and are not influenced by this property.

For example, regardless of the
computed value of
[appearance](#propdef-appearance):

- Elements which can be in different states keep this ability, and the
 relevant pseudo-classes match as usual.
- If a
 [`select`](https://html.spec.whatwg.org/multipage/form-elements.html#the-select-element) element is activated, the UI to choose one of the
 associated
 [`option`](https://html.spec.whatwg.org/multipage/form-elements.html#the-option-element) elements is shown (although it may look
 different).
- Event handlers attached to the element trigger as usual.

Conversely, changing the appearance of an element must not cause it to
acquire the semantics, pseudo-classes, event handlers, etc. that are
typical of the element whose appearance it acquires.

For example, neither
[:enabled](https://www.w3.org/TR/selectors-4/#enabled-pseudo) nor
[:disabled](https://www.w3.org/TR/selectors-4/#disabled-pseudo) match on a
[`div`](https://html.spec.whatwg.org/multipage/grouping-content.html#the-div-element) styled with [appearance:
button](#propdef-appearance). The ability for an element to be focused is also
not changed by the [appearance]
property.

### 7.3. Control-Specific Rules

Maybe some or all of this section should
be moved to the
[\[HTML\]](#biblio-html "HTML Standard") spec. at
some point.

On some elements, setting some
properties inhibits [appearance:
auto](#propdef-appearance). For instance, even if
[appearance] is
[auto](#valdef-appearance-auto), buttons lose their native appearance when a
[border](https://www.w3.org/TR/css-borders-4/#propdef-border) is set. This is not in
contradiction with the definition of
[auto], since [appearance:
auto] only means UAs *may* use a
native appearance, but for greater interoperability, it would be good to
document which properties on which elements have this effect.

Documenting what UAs need to put in
their UA stylesheet would be good.

#### 7.3.1. Single-Line Text Input Controls

When [appearance](#propdef-appearance) is
[auto](#valdef-appearance-auto), single-line text input controls such as
[\[HTML\]](#biblio-html "HTML Standard")
`<input type=text>` must be rendered so that:

- The content is clipped in the inline direction to the [content
 edge](https://www.w3.org/TR/css-box-4/#content-edge)

- The content is clipped in the block direction to the [padding
 edge](https://www.w3.org/TR/css-box-4/#padding-edge)

- The content is vertically centered

- The content does not wrap

- The
 [text-overflow](https://www.w3.org/TR/css-overflow-4/#propdef-text-overflow) property applies regardless of
 the value of the
 [overflow](https://www.w3.org/TR/css-overflow-3/#propdef-overflow) property

## 8. Window Interaction

### 8.1. Moving the window: the [window-drag property]
Name:

[window-drag]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

none
[\|](https://www.w3.org/TR/css-values-4/#comb-one) move

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

none

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[all
elements](https://www.w3.org/TR/css-pseudo/#generated-content "Includes ::before and ::after pseudo-elements.")

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

An installed application's window typically has a designated area where
it can be dragged to move the window. This area is generally at the top
of the window (usually part of the titlebar, toolbar, or both), outside
of the region that the page is actually rendered in. For installed web
apps, APIs or capabilities like
[\[WINDOW-CONTROLS-OVERLAY\]](#biblio-window-controls-overlay "Window Controls Overlay")
can alter and remove the surfaces where users can move a window. The
[window-drag](#propdef-window-drag) property allows the author to specify an
area *within* the page where a user can drag to move the window. Values
have the following meanings:

[none]
: Specifies that the element cannot be used as a drag area.

[move]
: Specifies that the element's [principal
 box](https://www.w3.org/TR/css-display-4/#principal-box) can be used as a [window drag
 area](#window-drag-area).

 Some UAs may support [app-region] as a [legacy
shorthand](https://www.w3.org/TR/css-cascade-5/#legacy-shorthand) for
[window-drag](#propdef-window-drag).

When a [box](https://www.w3.org/TR/css-display-4/#box) is a [window drag area], a drag gesture on that element
initiates a window move operation instead of normal web event
processing. The UA must not fire pointer events, mouse events, or drag
events on the element for the duration of the window move gesture.

 This means the
[\[HTML\]](#biblio-html "HTML Standard")
[`draggable`](https://html.spec.whatwg.org/multipage/dnd.html#attr-draggable) attribute has no effect on elements with
[window-drag: move](#propdef-window-drag); the window move behavior takes precedence.

------------------------------------------------------------------------

## [ Appendix A. Acknowledgments]
This appendix is *informative*.

This specification builds upon
[\[CSS-UI-3\]](#biblio-css-ui-3 "CSS Basic User Interface Module Level 3 (CSS3 UI)"),
which was edited and written for the most part by Tantek Çelik from 1999
to the present, first while representing Microsoft, then as an Invited
Expert, and most recently while representing Mozilla.

Thanks to feedback and contributions from [Rossen Atanassov],
[Tab Atkins], [L. David Baron], [Bert Bos],
[Matthew Brealey], [Rick Byers], [Ada Chan],
[James Craig], [Michael Cooper], [Axel
Dahmen], [Michael Day], [Micah Dubinko],
[Elika E.], [Steve Falkenburg], [Andrew
Fedoniouk], [Al Gilman], [Ian Hickson],
[Bjoern Hoehrmann], [Alan Hogan], [David
Hyatt], [Richard Ishida], [Sho Kuwamoto],
[Yves Lafon], [Stuart Langridge], [Susan
Lesch], [Peter Linss], [Kang-Hao Lu],
[Masayuki Nakano], [Mats Palmgren], [Brad
Pettit], [Chris Rebert], [François Remy],
[Andrey Rybka], [Simon Sapin], [Alexander
Savenkov], [Sebastian Schnitzenbaumer], [Lea
Verou], [Etan Wexler], [David Woolley],
[Frank Yan], [Boris Zbarsky], and [Domel].

## [ Appendix B. Changes]
This appendix is *informative*.

### [ Changes from the [16 March 2021 Working Draft](https://www.w3.org/TR/2021/WD-css-ui-4-20210316/)]
In addition to a number of editorial adjustments, the following
normative changes have been made:

- Introduced a definition for the
 [pointer-events](#propdef-pointer-events) property.
- Extended the image types required to be supported for the
 [cursor](#propdef-cursor) property from just
 [\<url\>](https://www.w3.org/TR/css-values-4/#url-value) to [\<url\>] and
 [\<url-set\>](#typedef-cursor-url-set). (Support for the broader
 [\<image\>](https://www.w3.org/TR/css-images-3/#typedef-image) type remains allowed but optional.)
- Disabled native apparence after
 [revert-layer](https://www.w3.org/TR/css-cascade-5/#valdef-all-revert-layer) if there's still a value in the author origin.
- Referred to [scroll
 containers](https://www.w3.org/TR/css-overflow-3/#scroll-container) instead of
 [overflow](https://www.w3.org/TR/css-overflow-3/#propdef-overflow) values other than
 [visible](https://www.w3.org/TR/css-overflow-3/#valdef-overflow-visible), so
 [clip](https://www.w3.org/TR/css-overflow-3/#valdef-overflow-clip) is included.
- Let the computed value of
 [outline-width](#propdef-outline-width) be [snapped as a border
 width](https://www.w3.org/TR/css-values-4/#snap-a-length-as-a-border-width).
- Removed [slider-horizontal], [square-button], and
 [push-button] keywords from
 [\<compat-auto\>](#typedef-appearance-compat-auto).
- Retired the `invert` value of
 [outline-color](#propdef-outline-color).
- Added the
 [auto](#valdef-outline-color-auto) value of
 [outline-color](#propdef-outline-color).
- Removed claims that
 [outline-width](#propdef-outline-width) may influence the rendering of
 [outline-style:
 auto](#propdef-outline-style) outlines. (See [Issue
 9201](https://github.com/w3c/csswg-drafts/issues/9201).)
- Clarified that outlines contribute to the [ink overflow
 area](https://www.w3.org/TR/css-overflow-3/#ink-overflow-region) of an element.
- Reintroduced the
 [caret-animation](#propdef-caret-animation) property.
- Defined what [disregarding a property](#disregard) means.
- Defined the behavior for (semi-)transparent accent colors.
- Added a note that
 [outline-offset](#propdef-outline-offset) is not part of the
 [outline](#propdef-outline) shorthand.
- Added the
 [base](#valdef-appearance-base) keyword to the
 [appearance](#propdef-appearance) property.
- Added the
 [interactivity](#propdef-interactivity) property.
- Clarified that end-of-line carets are shown even if they overflow.
- Defined the box rendering for [appearance: auto].
- Clarified that outlines follow corner shapes.
- Clarified the applicability of the [caret-\*] properties.
- Rearranged the syntax of the
 [cursor](#propdef-cursor) property for better readability.
- Added the
 [interest-delay](#propdef-interest-delay) property and its longhands
 [interest-delay-start](#propdef-interest-delay-start) and
 [interest-delay-end](#propdef-interest-delay-end).
- Let
 [outline-color](#propdef-outline-color) refer to
 [\<\'border-top-color\'\>](https://www.w3.org/TR/css-borders-4/#propdef-border-top-color), so additions to that
 property's values also apply to it.
- Removed the special case of
 [outline-width](#propdef-outline-width) having a computed value of
 [0] when
 [outline-style](#propdef-outline-style) is
 [none](https://www.w3.org/TR/css-borders-4/#valdef-line-style-none) or
 [hidden](https://www.w3.org/TR/css-borders-4/#valdef-line-style-hidden). ([Issue
 11494](https://github.com/w3c/csswg-drafts/issues/11494))

### [ Changes from the [24 January 2020 Working Draft](https://www.w3.org/TR/2020/WD-css-ui-4-20200124/)]
In addition to a number of editorial adjustments, the following
normative changes have been made:

- Changed appearance: button to only apply to buttons.
- Outline-width may be ignored if outline-style is auto.
- Ensured caret visibility despite transforms.
- Moved [resize: block](#propdef-resize) and [resize: inline] from css-logical-1 to this specification.
- Introduced the
 [accent-color](#propdef-accent-color) property.

### [ Changes from the [2 January 2020 Working Draft](https://www.w3.org/TR/2020/WD-css-ui-4-20200102/)]
In addition to a number of editorial adjustments, the following
normative changes have been made:

- Defined user-select to be discretely animatable, rather than not.
- Restricted the applicability of [appearance:
 button](#propdef-appearance) so that it can no longer give a buttony
 appearance to widgets that aren't buttons to start with.
- Add a clause to preserve visibility of carets even when scaled down
 via transforms.

### [ Changes from the [22 December 2017 Working Draft](https://www.w3.org/TR/2017/WD-css-ui-4-20171222/)]
In addition to a number of editorial adjustments, the following
normative changes have been made:

- Added details about form control-specific rendering rules
- Clarify interaction between text-overflow and anonymous block
 containers
- Require the
 [pointer](#valdef-cursor-pointer) cursor for hyperlinks in all document formats
- Moved the
 [box-sizing](https://www.w3.org/TR/css-sizing-3/#propdef-box-sizing) and
 [text-overflow](https://www.w3.org/TR/css-overflow-4/#propdef-text-overflow) properties to
 [\[CSS-SIZING-3\]](#biblio-css-sizing-3 "CSS Box Sizing Module Level 3")
 and
 [\[CSS-OVERFLOW-4\]](#biblio-css-overflow-4 "CSS Overflow Module Level 4")
 respectively.
- Changed the requirement that the
 [text](#valdef-cursor-text) cursor matches the writing mode from MAY to MUST
- The definition of the appearance property has been significantly
 reworked to make the design compatible with existing web content
- The logic that mapped [user-select:
 auto](#propdef-user-select) to various values at computed value time has
 been changed to used value time
- Clarify Author requirements on the [cursor:
 pointer](#propdef-cursor) value

### [ Changes from the [22 Sep 2015 First Public Working Draft](https://www.w3.org/TR/2015/WD-css-ui-4-20150922/)]
In addition to a number of editorial adjustments, the following
normative changes have been made:

- Introduced the
 [user-select](#propdef-user-select) property.
- The [caret-animation] property has been removed, as there
 weren't any known use cases for it.
- The [resize] property now also applies to replaced elements
 representing images or videos, and to iframes.
- The string values and dual values of the text-overflow property were
 moved to this specification from level 3.
- Move directional focus navigation properties from level 3 to level 4
- Content from the now-stable
 [\[CSS-UI-3\]](#biblio-css-ui-3 "CSS Basic User Interface Module Level 3 (CSS3 UI)")
 has been merged in.

### [ Changes from [CSS UI Level 3](https://www.w3.org/TR/css-ui-3/)]
- Introduced the
 [user-select](#propdef-user-select) property.
- Added the directional focus navigation properties
 [nav-up](#propdef-nav-up),
 [nav-down](#propdef-nav-down),
 [nav-left](#propdef-nav-left), and
 [nav-right](#propdef-nav-right).
- Added the
 [appearance](#propdef-appearance) property.
- Moved [resize: block](#propdef-resize) and [resize: inline] from
 [\[CSS-LOGICAL-1\]](#biblio-css-logical-1 "CSS Logical Properties and Values Module Level 1")
 to this specification.
- Added the
 [accent-color](#propdef-accent-color) property.
- Added the
 [interest-delay](#propdef-interest-delay) property and its longhands
 [interest-delay-start](#propdef-interest-delay-start) and
 [interest-delay-end](#propdef-interest-delay-end).
- Added the
 [pointer-events](#propdef-pointer-events) property.
- Extended the image types required to be supported for the
 [cursor](#propdef-cursor) property from just
 [\<url\>](https://www.w3.org/TR/css-values-4/#url-value) to [\<url\>] and
 [\<url-set\>](#typedef-cursor-url-set). (Support for the broader
 [\<image\>](https://www.w3.org/TR/css-images-3/#typedef-image) type remains allowed but optional.)
- Retired the `invert` value of
 [outline-color](#propdef-outline-color).
- Added the
 [auto](#valdef-outline-color-auto) value of
 [outline-color](#propdef-outline-color).
- Added the
 [caret-animation](#propdef-caret-animation) property.
- Added the
 [interactivity](#propdef-interactivity) property.
- Added the
 [interest-delay](#propdef-interest-delay) property and its longhands
 [interest-delay-start](#propdef-interest-delay-start) and
 [interest-delay-end](#propdef-interest-delay-end).
- Let
 [outline-color](#propdef-outline-color) refer to
 [\<\'border-top-color\'\>](https://www.w3.org/TR/css-borders-4/#propdef-border-top-color), so additions to that
 property's values also apply to it.

## [ Appendix C: Privacy Considerations]
This appendix is *informative*.

The W3C TAG is developing a [Self-Review Questionnaire: Security and
Privacy](https://w3ctag.github.io/security-questionnaire/) for editors
of specifications to informatively answer.

Per the [Questions to
Consider](https://w3ctag.github.io/security-questionnaire/#questions)

Does this specification deal with personally-identifiable information?
: No.

Does this specification deal with high-value data?
: No.

Does this specification introduce new state for an origin that persists across browsing sessions?
: No.

Does this specification expose persistent, cross-origin state to the web?
: No.

Does this specification expose any other data to an origin that it doesn't currently have access to?
: No.

Does this specification allow an origin access to a user's location?
: No.

Does this specification allow an origin access to sensors on a user's device?

: Yes.

 The directional focus navigation properties indirectly allow access
 to the device's keyboard navigation input mechanism such as arrow
 keys.

Does this specification allow an origin access to aspects of a user's local computing environment?
: No.

Does this specification allow an origin access to other devices?
: No.

Does this specification expose temporary identifiers to the web?
: No.

Does this specification distinguish between behavior in first-party and third-party contexts?
: No.

How should this specification work in the context of a user agent's \"incognito\" mode?
: No differently.

Does this specification persist data to a user's local device?
: No.

## [ Appendix D: Security Considerations]
This appendix is *informative*.

The W3C TAG is developing a [Self-Review Questionnaire: Security and
Privacy](https://w3ctag.github.io/security-questionnaire/) for editors
of specifications to informatively answer.

Per the [Questions to
Consider](https://w3ctag.github.io/security-questionnaire/#questions)

Does this specification enable new script execution/loading mechanisms?

: Yes to loading, but not to execution.

 The [cursor](#propdef-cursor) property accepts
 [\<image\>](https://www.w3.org/TR/css-images-3/#typedef-image) values which may include URLs to
 be loaded. These may be SVG documents which may contain scripts, but
 this specification requires that scripts must not be run.

Does this specification allow an origin some measure of control over a user agent's native UI?

: Yes.

 The [cursor](#propdef-cursor) and
 [caret](#propdef-caret) property and
 [sub-properties](https://www.w3.org/TR/css-cascade-5/#longhand) enable the page to change the display of the cursor
 and text insertion caret of the user agent's native UI. In addition
 the
 [outline-style](#propdef-outline-style) property's [auto] value
 (and thus [outline](#propdef-outline) shorthand) enable the page to
 potentially display a native focused element outline presentation
 around any element.

 The [appearance](#propdef-appearance) property also allows author to
 turn off native styling and replace it with css based styling.

Does this specification allow downgrading default security characteristics?
: No.

## [ Appendix E: Default style sheet additions for HTML]
This appendix is *informative*.

Potential additions to the base style sheet to express HTML form
controls, and a few dynamic presentation attributes:

```
:enabled:focus {
 outline: 2px inset;
}

button,
input[type=button],
input[type=reset],
input[type=submit],
input[type=checkbox],
input[type=radio],
textarea,
input,
input[type=text],
input[type=password],
input[type=image] {
 display: inline-block;
}

input[type=button],
input[type=reset],
input[type=submit],
input[type=checkbox],
input[type=radio],
input,
input[type=text],
input[type=password],
input[type=image] {
 white-space: nowrap;
}

button {
 /* white space handling of BUTTON tags in particular */
 white-space:normal;
}

input[type=reset]:lang(en) {
 /* default content of HTML input type=reset button, per language */
 content: "Reset";
}

input[type=submit]:lang(en) {
 /* default content of HTML input type=submit button, per language */
 content: "Submit";
}

/* UAs should use language-specific Reset/Submit rules for others. */

input[type=button],
input[type=reset][value],
input[type=submit][value] {
 /* text content/labels of HTML "input" buttons */
 content: attr(value);
}

textarea {
 /* white space handling of TEXTAREA tags in particular */
 white-space:pre-wrap;
 resize: both;
}

input[type=hidden] {
 /* appearance of the HTML hidden text field in particular */
 display: none !important;
}

input[type=image] {
 content: attr(src,url);
 border: none;
}

select[size] {
 /* HTML4/XHTML1 <select> w/ size more than 1 - appearance of list */
 display: inline-block;
 height: attr(size,em);
}

select,select[size=1] {
 /* HTML4/XHTML1 <select> without size, or size=1 - popup-menu */
 display: inline-block;
 height: 1em;
 overflow: hidden;
}

select[size]:active {
 /* active HTML <select> w/ size more than 1 - appearance of active list */
 display: inline-block;
}

optgroup, option {
 display: block;
 white-space: nowrap;
}

optgroup[label],option[label] {
 content: attr(label);
}

option[selected]::before {
 display: inline;
 content: check;
}

/* Though FRAME resizing is not directly addressed by this specification,
 the following rules may provide an approximation of reasonable behavior. */

/*

frame { resize:both }
frame[noresize] { resize:none }

*/
```
