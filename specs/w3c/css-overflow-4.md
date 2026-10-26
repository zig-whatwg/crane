## 1. Introduction

This specification extends
[\[CSS-OVERFLOW-3\]](#biblio-css-overflow-3 "CSS Overflow Module Level 3").
It contains several primary sections:

[Overflow Scrolling and Clipping Controls](#overflow-properties)

: This section defines relatively simple extensions to the
 [overflow-\*] properties [in Level
 3](https://drafts.csswg.org/css-overflow-3/#overflow-properties).

[Automatic Ellipses](#auto-ellipsis).

: This section defines some experimental extensions to the
 [\*-ellipsis] properties [in Level
 3](https://drafts.csswg.org/css-overflow-3/#auto-ellipsis).

 At the time of writing,
[\[CSS-OVERFLOW-3\]](#biblio-css-overflow-3 "CSS Overflow Module Level 3")
is not completely finalized yet. To avoid accidental divergences and
maintenance overhead, This specification is written as a delta
specification over css-overflow Level 3. Once the level 3 specification
is final, its content will be integrated into this specification, which
will then replace it. Until then, this specification only contains
additions and extensions to level 3.

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

### 1.2. Module Interactions

This module extends features defined in
[\[CSS-OVERFLOW-3\]](#biblio-css-overflow-3 "CSS Overflow Module Level 3").

## 2. Overflow Concepts and Terminology

Copy [Level 3
content](https://drafts.csswg.org/css-overflow-3/#overflow-concepts)
when final.

## 3. Scrolling and Clipping Overflow

(#issue-50246bc5①) Copy [Level 3
content](https://drafts.csswg.org/css-overflow-3/#overflow-properties)
when final.

### [3.1. ][ Managing Overflow: the [overflow-x](https://drafts.csswg.org/css-overflow-3/#propdef-overflow-x), [overflow-y](https://drafts.csswg.org/css-overflow-3/#propdef-overflow-y), and [overflow](https://drafts.csswg.org/css-overflow-3/#propdef-overflow) properties]
This level extends the
[overflow-x](https://drafts.csswg.org/css-overflow-3/#propdef-overflow-x) and
[overflow-y](https://drafts.csswg.org/css-overflow-3/#propdef-overflow-y) properties (and
[overflow](https://drafts.csswg.org/css-overflow-3/#propdef-overflow)
[shorthand](https://drafts.csswg.org/css-cascade-5/#shorthand-property)) to apply to [replaced
elements](https://drafts.csswg.org/css-display-4/#replaced-element).

On [replaced
elements](https://drafts.csswg.org/css-display-4/#replaced-element), the [used
values](https://drafts.csswg.org/css-cascade-5/#used-value) of all computed values other than
[visible](https://drafts.csswg.org/css-overflow-3/#valdef-overflow-visible) is
[clip](https://drafts.csswg.org/css-overflow-3/#valdef-overflow-clip). Host languages should define [UA style
sheet](https://drafts.csswg.org/css-cascade-5/#cascade-origin-ua) rules that apply a default value of
[clip] to such elements and set
their
[overflow-clip-margin](#propdef-overflow-clip-margin) to [content-box].

 Application of
[overflow](https://drafts.csswg.org/css-overflow-3/#propdef-overflow) to [replaced
elements](https://drafts.csswg.org/css-display-4/#replaced-element) was added to allow images to paint effects outside
their effective layout box; the recommended UA style sheet rules are to
effect their original behavior as a default. See discussion in [Issue
7059](https://github.com/w3c/csswg-drafts/issues/7058) and [Issue
7144](https://github.com/w3c/csswg-drafts/issues/7144). This is a change
from [CSS2.1](https://www.w3.org/TR/CSS2/) and is at-risk.

Application of
[overflow](https://drafts.csswg.org/css-overflow-3/#propdef-overflow) to [replaced
elements](https://drafts.csswg.org/css-display-4/#replaced-element) is still being worked out. [\[Issue
#7144\]](https://github.com/w3c/csswg-drafts/issues/7144)

### [3.2. ][ Changing Clipping Bounds: the [overflow-clip-margin-\*] properties]
Name:

[overflow-clip-margin-top],
[overflow-clip-margin-right],
[overflow-clip-margin-bottom],
[overflow-clip-margin-left],
[overflow-clip-margin-block-start],
[overflow-clip-margin-inline-start],
[overflow-clip-margin-block-end],
[overflow-clip-margin-inline-end]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<visual-box\>](https://drafts.csswg.org/css-box-4/#typedef-visual-box)
[\|\|](https://drafts.csswg.org/css-values-4/#comb-any)
[\<length\>](https://drafts.csswg.org/css-values-4/#length-value)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

[0px]

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

boxes to which
[overflow](https://drafts.csswg.org/css-overflow-3/#propdef-overflow) applies

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

see individual properties

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

the computed
[\<length\>](https://drafts.csswg.org/css-values-4/#length-value) and a
[\<visual-box\>](https://drafts.csswg.org/css-box-4/#typedef-visual-box) keyword

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

per computed value if the
[\<visual-box\>](https://drafts.csswg.org/css-box-4/#typedef-visual-box) values match; otherwise discrete

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Logical property
group:](https://drafts.csswg.org/css-logical-1/#logical-property-group)

[overflow-clip-margin](#propdef-overflow-clip-margin)

Name:

[overflow-clip-margin],
[overflow-clip-margin-inline],
[overflow-clip-margin-block]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<visual-box\>](https://drafts.csswg.org/css-box-4/#typedef-visual-box)
[\|\|](https://drafts.csswg.org/css-values-4/#comb-any)
[\<length\>](https://drafts.csswg.org/css-values-4/#length-value)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

[0px]

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

boxes to which
[overflow](https://drafts.csswg.org/css-overflow-3/#propdef-overflow) applies

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

These properties and their shorthands define the [overflow clip
edge] of
the box, i.e. precisely *how far* outside its bounds the box's content
is allowed to paint before being clipped by effects (such as [overflow:
clip](https://drafts.csswg.org/css-overflow-3/#propdef-overflow), above) that are defined to clip to the box's
[overflow clip edge](#overflow-clip-edge). The
[shorthand](https://drafts.csswg.org/css-cascade-5/#shorthand-property)/[longhand](https://drafts.csswg.org/css-cascade-5/#longhand) relationships are as for
[margin](https://drafts.csswg.org/css-box-4/#propdef-margin), but note that the
[shorthands] have a restricted syntax.

Values are defined as follows:

[[\<visual-box\>](https://drafts.csswg.org/css-box-4/#typedef-visual-box)]

: Specifies the box edge to use as the [overflow clip
 edge](#overflow-clip-edge) origin, i.e. when the specified offset is zero.

 If omitted, defaults to [padding-box] on
 non-[replaced](https://drafts.csswg.org/css-display-4/#replaced-element) elements, or [content-box] on
 [replaced] elements.

 (#issue-3d19a60f) Application of
 [overflow-clip-margin](#propdef-overflow-clip-margin) to [replaced
 elements](https://drafts.csswg.org/css-display-4/#replaced-element) is still being worked out. [\[Issue
 #7144\]](https://github.com/w3c/csswg-drafts/issues/7144)

[[\<length\>](https://drafts.csswg.org/css-values-4/#length-value)]

: The specified offset dictates how much the [overflow clip
 edge](#overflow-clip-edge) is expanded from the specified box edge. Negative
 values shrink the box, instead. Defaults to zero if omitted.

The [overflow clip
edge](#overflow-clip-edge)
is shaped in the corners exactly the same way as an [outer
box-shadow](https://drafts.csswg.org/css-backgrounds-3/#box-shadow-outer-box-shadow) with a spread radius of the same cumulative offset from
the box's [border
edge](https://drafts.csswg.org/css-box-4/#border-edge). See [CSS Backgrounds 3 § 4.2 Corner
Shaping](https://drafts.csswg.org/css-backgrounds-3/#corner-shaping) and
[CSS Backgrounds 3 § 6.1.1 Shadow Shape, Spread, and
Knockout](https://drafts.csswg.org/css-backgrounds-3/#shadow-shape),
noting in particular the formula for outsets beyond the [border
edge].

## 4. Automatic Ellipses

### 4.1. Inline Overflow Ellipsis: the [text-overflow property]
Name:

[text-overflow]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

\[ clip
[\|](https://drafts.csswg.org/css-values-4/#comb-one) ellipsis [\|]
[\<string\>](https://drafts.csswg.org/css-values-4/#string-value) [\|] fade
[\|]
[\<fade()\>](#funcdef-text-overflow-fade)
\][{1,2}](https://drafts.csswg.org/css-values-4/#mult-num-range)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

clip

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

block containers

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

refer to the width of the line box

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

as specified, with lengths made absolute

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value type

Tests

- [line-clamp-auto-009.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-auto-009.html "css/css-overflow/line-clamp/line-clamp-auto-009.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-auto-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-auto-009.html)
- [line-clamp-auto-010.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-auto-010.html "css/css-overflow/line-clamp/line-clamp-auto-010.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-auto-010.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-auto-010.html)
- [webkit-line-clamp-036.html](https://wpt.fyi/results/css/css-overflow/line-clamp/webkit-line-clamp-036.html "css/css-overflow/line-clamp/webkit-line-clamp-036.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/webkit-line-clamp-036.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/webkit-line-clamp-036.html)
- [webkit-line-clamp-037.html](https://wpt.fyi/results/css/css-overflow/line-clamp/webkit-line-clamp-037.html "css/css-overflow/line-clamp/webkit-line-clamp-037.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/webkit-line-clamp-037.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/webkit-line-clamp-037.html)
- [line-clamp-with-text-overflow-string-003.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-with-text-overflow-string-003.html "css/css-overflow/line-clamp/line-clamp-with-text-overflow-string-003.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-with-text-overflow-string-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-with-text-overflow-string-003.html)
- [line-clamp-with-text-overflow-string-010-crash.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-with-text-overflow-string-010-crash.html "css/css-overflow/line-clamp/line-clamp-with-text-overflow-string-010-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-with-text-overflow-string-010-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-with-text-overflow-string-010-crash.html)

This section might need to be re-synced
against
[\[CSS-OVERFLOW-3\]](#biblio-css-overflow-3 "CSS Overflow Module Level 3").

This property specifies rendering when inline content overflows its line
box edge in the inline progression direction of its block container
element (\"the block\") that has
[overflow](https://drafts.csswg.org/css-overflow-3/#propdef-overflow) other than
[visible](https://drafts.csswg.org/css-overflow-3/#valdef-overflow-visible).

Even though this property is not inherited, anonymous block container
boxes generated to establish the line box's [inline formatting
context](https://drafts.csswg.org/css-display-4/#inline-formatting-context) (see [block
container](https://drafts.csswg.org/css-display-4/#block-container)) are ignored, and the value of the property that
applies is the one on the non anonymous box. [This can be seen in the
"nested paragraph" part of [text-overflow examples](#example-a4ab7902):
even though the word "NESTED" is wrapped in an anonymous block container
whose
[text-overflow](#propdef-text-overflow) property has the initial value, it
is ellipsed.]

Text can overflow for example when it is prevented from wrapping (e.g.
due to `white-space: nowrap` or a single word is
too long to fit). Values have the following meanings:

[clip]
: Clip inline content that overflows its block container element.
 Characters may be only partially rendered.

[ellipsis]
: Render an ellipsis character (U+2026) to represent clipped inline
 content. Implementations may substitute a more language, script, or
 writing-mode appropriate ellipsis character, or three dots \"\...\"
 if the ellipsis character is unavailable.

[\<string\>](https://drafts.csswg.org/css-values-4/#string-value)

: Render the given string to represent clipped inline content.

 All forced line breaks inside the specified string (regardless of
 [white-space](https://drafts.csswg.org/css-text-4/#propdef-white-space) value) must be collapsed, as
 defined for collapsible segment breaks in [CSS Text 3 § 4.1.3
 Segment Break Transformation
 Rules](https://drafts.csswg.org/css-text-3/#line-break-transform).

[fade( \[ [\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage) \] )]

: Clip inline content that overflows its line box. Characters may be
 only partially rendered. In addition, the UA must apply a fade out
 effect near the edge of the line box, reaching complete transparency
 at the edge.

 (#issue-ebe65138) Do we need to define the way the
 fade out is calculated so that the fading is identical across
 browsers? It should probably be something like [mask-image:
 linear-gradient(to right, rgba(0,0,0,1),
 rgba(0,0,0,0))](https://drafts.csswg.org/css-masking-1/#propdef-mask-image), except applied to the relevant portion
 of the line only.

 The argument determines the distance over which the fade effect is
 applied. The
 [\<percentage\>](https://drafts.csswg.org/css-values-4/#percentage-value) is resolved against the width of
 the line box. Values lower than 0 are clipped to 0. Values greater
 than the width of the line box are clipped to the width of the line
 box.

 (#issue-2e22b1d9) If the line box is too short to
 display the fade effect at the desired length, should we drop the
 effect, or shrink the distance it is applied over until it fits, or
 clip the end of the fade?

 (#issue-948cb1ee) How should we deal with things
 overflowing out of the line box, or overlapping onto it? Should fade
 apply to the logical content of the line, or to the physical area of
 the line box, or the intersection of both?

[fade]
: Same as
 [fade()](#funcdef-text-overflow-fade), but the distance over which the fading
 effect is applied is determined by the UA. [1em] is suggested
 as a reasonable value.

The term \"character\" is used in this property definition for better
readability and means \"grapheme cluster\"
[\[UAX29\]](#biblio-uax29 "Unicode Text Segmentation")
for implementation purposes.

If there is one value, it applies only to the
[end](https://drafts.csswg.org/css-writing-modes-4/#css-end) line box edge. If there are two values, the first value
applies to the
[line-left](https://drafts.csswg.org/css-writing-modes-4/#line-left) edge, and the second value applies to the
[line-right](https://drafts.csswg.org/css-writing-modes-4/#line-right) edge. The terms [end],
[line-left] and [line-right]
are defined in
[\[CSS-WRITING-MODES-3\]](#biblio-css-writing-modes-3 "CSS Writing Modes Level 3").

 the use of
[line-left](https://drafts.csswg.org/css-writing-modes-4/#line-left) and
[line-right](https://drafts.csswg.org/css-writing-modes-4/#line-right) rather than
[start](https://drafts.csswg.org/css-writing-modes-4/#css-start) and
[end](https://drafts.csswg.org/css-writing-modes-4/#css-end) when there are two values is intentional, to facilitate
the use of directional characters such as arrows.

For the ellipsis and string values, implementations must hide characters
and [atomic inline-level
elements](https://www.w3.org/TR/CSS2/visuren.html#inline-boxes) at the
applicable edge(s) of the line as necessary to fit the ellipsis/string,
and place the ellipsis/string immediately adjacent to the applicable
edge(s) of the remaining inline content.

In order to avoid jitter in the position of the ellipsis as scrolling
reveals more content, user agents may adjust the position of the
ellipsis to be adjacent to the end of the line, or may fade/hide the
ellipsis during scrolling.

The first character or [atomic inline-level
element](https://www.w3.org/TR/CSS2/visuren.html#inline-boxes) on a line
must be clipped rather than ellipsed.

### [Bidi ellipsis examples]
These examples demonstrate which characters get hidden to make room for
the ellipsis in a bidi situation: those visually at the edge of the
line.

Sample CSS:

``` highlight
div {
 font-family: monospace;
 white-space: pre;
 overflow: hidden;
 width: 9ch;
 text-overflow: ellipsis;
}
```

Sample HTML fragments, renderings, and your browser:

HTML

Reference rendering

Your Browser

`<div>שלום 123456</div>`

::: {style="font-family:monospace"}
123456 ם...

::: {style="font-family: monospace; white-space: pre; overflow: hidden; width: 9ch; text-overflow: ellipsis"}
שלום 123456

`<div dir=rtl>שלום 123456</div>`

::: {style="font-family:monospace"}
...456 שלום

::: {dir="rtl" style="font-family: monospace; white-space: pre; overflow: hidden; width: 9ch; text-overflow: ellipsis"}
שלום 123456

### [ ellipsing details]
- Ellipsing only affects rendering and must not affect layout nor
 dispatching of pointer events: The UA should dispatch any pointer
 event on the ellipsis to the elided element, as if
 [text-overflow](#propdef-text-overflow) had been [none].
- The ellipsis is styled and baseline-aligned according to the block.
- If a line has a [block overflow
 ellipsis](#block-overflow-ellipsis), then any handling relating to it, including
 displacing content from the end of the line, occurs first. If the line
 still overflows after that (e.g. because the block overflow ellipsis
 is too long), then it is ellipsed according to the
 [text-overflow](#propdef-text-overflow) property.
 Tests
 - [line-clamp-text-overflow-001.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-text-overflow-001.html "css/css-overflow/line-clamp/line-clamp-text-overflow-001.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-text-overflow-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-text-overflow-001.html)
- Ellipsing occurs after relative positioning and other graphical
 transformations.
- If there is insufficient space for the ellipsis, then clip the
 rendering of the ellipsis itself (on the same side that neutral
 characters on the line would have otherwise been clipped with the
 [text-overflow:clip] value).
- For bidi purposes, the ellipsis and string values must be treated as
 if they were wrapped in an anonymous inline with [unicode-bidi:
 isolate](https://drafts.csswg.org/css-writing-modes-3/#propdef-unicode-bidi) which inherits [direction] from the
 [bidi
 paragraph](https://drafts.csswg.org/css-writing-modes-4/#bidi-paragraph).
 Tests
 - [text-overflow-string-006.html](https://wpt.fyi/results/css/css-overflow/text-overflow-string-006.html "css/css-overflow/text-overflow-string-006.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/text-overflow-string-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/text-overflow-string-006.html)
 - [text-overflow-string-007.html](https://wpt.fyi/results/css/css-overflow/text-overflow-string-007.html "css/css-overflow/text-overflow-string-007.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/text-overflow-string-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/text-overflow-string-007.html)
 - [text-overflow-string-008.html](https://wpt.fyi/results/css/css-overflow/text-overflow-string-008.html "css/css-overflow/text-overflow-string-008.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/text-overflow-string-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/text-overflow-string-008.html)

 <!-- -->

 - [line-clamp-with-text-overflow-string-004.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-with-text-overflow-string-004.html "css/css-overflow/line-clamp/line-clamp-with-text-overflow-string-004.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-with-text-overflow-string-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-with-text-overflow-string-004.html)
 - [line-clamp-with-text-overflow-string-005.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-with-text-overflow-string-005.html "css/css-overflow/line-clamp/line-clamp-with-text-overflow-string-005.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-with-text-overflow-string-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-with-text-overflow-string-005.html)
 - [line-clamp-with-text-overflow-string-006.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-with-text-overflow-string-006.html "css/css-overflow/line-clamp/line-clamp-with-text-overflow-string-006.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-with-text-overflow-string-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-with-text-overflow-string-006.html)
 - [line-clamp-with-text-overflow-string-007.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-with-text-overflow-string-007.html "css/css-overflow/line-clamp/line-clamp-with-text-overflow-string-007.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-with-text-overflow-string-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-with-text-overflow-string-007.html)
 - [line-clamp-with-text-overflow-string-008.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-with-text-overflow-string-008.html "css/css-overflow/line-clamp/line-clamp-with-text-overflow-string-008.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-with-text-overflow-string-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-with-text-overflow-string-008.html)
 - [line-clamp-with-text-overflow-string-009.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-with-text-overflow-string-009.html "css/css-overflow/line-clamp/line-clamp-with-text-overflow-string-009.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-with-text-overflow-string-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-with-text-overflow-string-009.html)

### [ user interaction with ellipsis]
- When the user is interacting with content (e.g. editing, selecting,
 scrolling), the user agent may treat
 [ellipsis](#overflow-ellipsis), string values, [fade] or [fade()] as
 [text-overflow:clip].
- Selecting the ellipsis should select the ellipsed text. If all of the
 ellipsed text is selected, UAs should show selection of the ellipsis.
 Behavior of partially-selected ellipsed text is up to the UA.

### [text-overflow examples]
These examples demonstrate setting the text-overflow of a block
container element that has text which overflows its dimensions:

sample CSS for a div:

```
div {
 font-family: Helvetica, sans-serif;
 line-height: 1.1;
 width: 3.1em;
 border: solid .1em black;
 padding: 0.2em; margin:1em 0;
}
```

sample HTML fragments, renderings, and your browser:

HTML

sample rendering

your browser

```
<div>
CSS IS AWESOME, YES
</div>
```

First, a box with text drawing outside of it.

::: {style="width:3.1em; border:solid .1em black; margin:1em 0; padding:.2em; font-family:Helvetica,sans-serif; line-height:1.1;"}
CSS IS AWESOME, YES

```
<div style="text-overflow:clip; overflow:hidden">
CSS IS AWESOME, YES
</div>
```

Second, a similar box with the text clipped outside the box.

::: {style="width:3.1em; border:solid .1em black; margin:1em 0; padding:.2em; font-family:Helvetica,sans-serif; line-height:1.1; overflow:hidden;text-overflow:clip;"}
CSS IS AWESOME, YES

```
<div style="text-overflow:ellipsis; overflow:hidden">
CSS IS AWESOME, YES
</div>
```

Third, a similar box with an ellipsis representing the clipped text.

::: {style="width:3.1em; border:solid .1em black; margin:1em 0; padding:.2em; font-family:Helvetica,sans-serif; line-height:1.1; overflow:hidden;text-overflow:ellipsis;"}
CSS IS AWESOME, YES

```
<div style="text-overflow:ellipsis; overflow:hidden">
NESTED
 <p>PARAGRAPH</p>
WON'T ELLIPSE.
</div>
```

Fourth, a box with a nested paragraph demonstrating anonymous block
boxes equivalency and non-inheritance into a nested element.

::: {style="width:3.1em; border:solid .1em black; margin:1em 0; padding:.2em; font-family:Helvetica,sans-serif; line-height:1.1; overflow:hidden;text-overflow:ellipsis;"}
NESTED

PARAGRAPH

WON'T ELLIPSE.

```
<div style="text-overflow:fade; overflow:hidden">
CSS IS AWESOME, YES
</div>
```

a box with the text fading out on overflow.

::: {style="width:3.1em; border:solid .1em black; padding:.2em; font-family:Helvetica,sans-serif; line-height:1.1; overflow:hidden;text-overflow:clip;"}
CSS IS AWESOME, YES

 the side of the line that the ellipsis is placed
depends on the
[direction](https://drafts.csswg.org/css-writing-modes-3/#propdef-direction) of the block. E.g. an overflow
hidden right-to-left (`direction: rtl`) block
clips inline content on the
[left](https://drafts.csswg.org/css-writing-modes-3/#physical-left) side, thus would place a text-overflow ellipsis on the
[left] to represent that clipped content.

insert RTL example diagram here to
illustrate note.

### [ ellipsis interaction with scrolling interfaces]
This section applies to elements with text-overflow other than
[text-overflow:clip] (non-clip text-overflow) and overflow:scroll.

When an element with non-clip text-overflow has overflow of scroll in
the inline progression dimension of the text, and the browser provides a
mechanism for scrolling (e.g. a scrollbar on the element, or a touch
interface to swipe-scroll, etc.), there are additional implementation
details that provide a better user experience:

When an element is scrolled (e.g. by the user, DOM manipulation), more
of the element's content is shown. The value of text-overflow should not
affect whether more of the element's content is shown or not. If a
non-clip text-overflow is set, then as more content is scrolled into
view, implementations should show whatever additional content fits, only
truncating content which would otherwise be clipped (or is necessary to
make room for the ellipsis/string), until the element is scrolled far
enough to display the edge of the content at which point that content
should be displayed rather than an ellipsis/string.

This example uses text-overflow on an
element with overflow scroll to demonstrate the above described
behavior.

sample CSS:

```
div.crawlbar {
 text-overflow: ellipsis;
 height: 2em;
 line-height: 1em;
 overflow: scroll;
 white-space: nowrap;
 width: 15em;
 border:1em solid black;
}
```

sample HTML fragment:

```
<div class="crawlbar">
CSS is awesome, especially when you can scroll
to see extra text instead of just
having it overlap other text by default.
</div>
```

demonstration of sample CSS and HTML:

::: {style="text-overflow: ellipsis; height: 2em; line-height:1; overflow: scroll; white-space: nowrap; width: 15em; border:1em solid black;"}
CSS is awesome, especially when you can scroll to see extra text instead
of just having it overlap other text by default.

As some content is scrolled into view, it is likely that other content
may scroll out of view on the other side. If that content's block
container element is the same that's doing the scrolling, and the
computed value of
[text-overflow](#propdef-text-overflow) has two values, with the value
applying to the start edge being a non-clip value, then implementations
must render an ellipsis/string in place of the clipped content, with the
same details as described in the value definition above, except that the
ellipsis/string is drawn in the
[start](https://drafts.csswg.org/css-writing-modes-4/#css-start) (rather than
[end](https://drafts.csswg.org/css-writing-modes-4/#css-end)) of the block's direction (per the direction property).

While the content is being scrolled, implementations may adjust their
rendering of ellipses/strings (e.g. align to the box edges rather than
line edges).

Same as previous example except with
`text-overflow: ellipsis ellipsis`, demonstrated:

::: {style="text-overflow: ellipsis ellipsis; height: 2em; line-height: 1em; overflow: scroll; white-space: nowrap; width: 15em; border:1em solid black;"}
CSS is awesome, especially when you can scroll to see extra text instead
of just having it overlap other text by default.

If there is insufficient space for both start and end ellipses/strings,
then only the end ellipsis/string should be rendered.

### 4.2. Indicating Block-Axis Overflow: the [block-ellipsis property]
Name:

[block-ellipsis]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

no-ellipsis
[\|](https://drafts.csswg.org/css-values-4/#comb-one) ellipsis [\|]
[\<string\>](https://drafts.csswg.org/css-values-4/#string-value)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

no-ellipsis

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[block
containers](https://drafts.csswg.org/css-display-4/#block-container)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

yes

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

N/A

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

specified value

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

Tests

- [block-ellipsis-invalid.html](https://wpt.fyi/results/css/css-overflow/parsing/block-ellipsis-invalid.html "css/css-overflow/parsing/block-ellipsis-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/parsing/block-ellipsis-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/parsing/block-ellipsis-invalid.html)
- [block-ellipsis-valid.html](https://wpt.fyi/results/css/css-overflow/parsing/block-ellipsis-valid.html "css/css-overflow/parsing/block-ellipsis-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/parsing/block-ellipsis-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/parsing/block-ellipsis-valid.html)

<!-- -->

- [continue-001.html](https://wpt.fyi/results/css/css-overflow/line-clamp/continue-001.html "css/css-overflow/line-clamp/continue-001.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/continue-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/continue-001.html)

This property allows inserting content into the last line box before a
[clamp point](#clamp-point) or a
(forced *or* unforced) [region
break](https://drafts.csswg.org/css-break-4/#region-break) to indicate the continuity of truncated / interrupted
content. It only affects line boxes contained directly by the [block
container](https://drafts.csswg.org/css-display-4/#block-container) itself, but as it inherits, will have an effect on
descendants' line boxes unless overridden.

Tests

- [block-ellipsis-011.html](https://wpt.fyi/results/css/css-overflow/line-clamp/block-ellipsis-011.html "css/css-overflow/line-clamp/block-ellipsis-011.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/block-ellipsis-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/block-ellipsis-011.html)
- [block-ellipsis-012.html](https://wpt.fyi/results/css/css-overflow/line-clamp/block-ellipsis-012.html "css/css-overflow/line-clamp/block-ellipsis-012.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/block-ellipsis-012.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/block-ellipsis-012.html)
- [block-ellipsis-022.html](https://wpt.fyi/results/css/css-overflow/line-clamp/block-ellipsis-022.html "css/css-overflow/line-clamp/block-ellipsis-022.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/block-ellipsis-022.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/block-ellipsis-022.html)
- [block-ellipsis-repaint-002.html](https://wpt.fyi/results/css/css-overflow/line-clamp/block-ellipsis-repaint-002.html "css/css-overflow/line-clamp/block-ellipsis-repaint-002.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/block-ellipsis-repaint-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/block-ellipsis-repaint-002.html)
- [line-clamp-auto-016.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-auto-016.html "css/css-overflow/line-clamp/line-clamp-auto-016.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-auto-016.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-auto-016.html)
- [line-clamp-auto-017.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-auto-017.html "css/css-overflow/line-clamp/line-clamp-auto-017.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-auto-017.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-auto-017.html)

Ignoring any intervening [absolutely
positioned](https://drafts.csswg.org/css-position-3/#absolute-position) elements or element closing boundaries, this property
affects a line box that immediately precedes a [region
break](https://drafts.csswg.org/css-break-4/#region-break) or a [clamp point](#clamp-point) when both participate in the same [independent
formatting
context](https://drafts.csswg.org/css-display-4/#independent-formatting-context).

Tests

- [line-clamp-auto-025.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-auto-025.html "css/css-overflow/line-clamp/line-clamp-auto-025.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-auto-025.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-auto-025.html)
- [line-clamp-auto-034.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-auto-034.html "css/css-overflow/line-clamp/line-clamp-auto-034.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-auto-034.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-auto-034.html)
- [line-clamp-auto-036.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-auto-036.html "css/css-overflow/line-clamp/line-clamp-auto-036.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-auto-036.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-auto-036.html)
- [line-clamp-auto-039.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-auto-039.html "css/css-overflow/line-clamp/line-clamp-auto-039.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-auto-039.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-auto-039.html)
- [line-clamp-auto-040.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-auto-040.html "css/css-overflow/line-clamp/line-clamp-auto-040.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-auto-040.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-auto-040.html)

 See [continue:
discard](#propdef-continue) for a way to generate boxes with such a [region
break](https://drafts.csswg.org/css-break-4/#region-break).

```
<div style="continue: collapse; block-ellipsis: ellipsis; max-height: 4lh">
 <div>
 <div>
 Line 1 <br>
 Line 2 <br>
 Line 3 <br>
 Line 4
 <div class="abspos"></div>
 </div>
 <div class="abspos"></div>
 </div>
 <div class="abspos"></div>
 <!-- the clamp point is here, not immediately after line 4 -->
 Line 5
</div>
```

Here the clamp point is not immediately after a line box, but the only
thing between it and the last line box are element closing boundaries
and abspos, and both are in the same independent formatting context, so
\"Line 4\" is ellipsized.

Meanwhile, in this example, there is
an in-flow element between the line box and the clamp point, so no
ellipsis is shown:

```
<div style="continue: collapse; block-ellipsis: ellipsis; max-lines: 2">
 Line 1 <br>
 Line 2
 <div></div>
 <!-- the clamp point is here -->
 Line 3
</div>
```

In this example, the last line box is
contained in an [independent formatting
context](https://drafts.csswg.org/css-display-4/#independent-formatting-context), so no ellipsis will be shown:

```
<div style="continue: collapse; max-height: 2lh; block-ellipsis: ellipsis">
 Line 1
 <div style="display: flow-root">Line 2</div>
 <!-- the clamp point is here -->
 Line 3
</div>
```

The inserted content is called the [block overflow
ellipsis]. Values have the following meanings:

[no-ellipsis]
: The rendering is unaffected.
 Tests
 - [block-ellipsis-023.html](https://wpt.fyi/results/css/css-overflow/line-clamp/block-ellipsis-023.html "css/css-overflow/line-clamp/block-ellipsis-023.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/block-ellipsis-023.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/block-ellipsis-023.html)
 - [block-ellipsis-037.html](https://wpt.fyi/results/css/css-overflow/line-clamp/block-ellipsis-037.html "css/css-overflow/line-clamp/block-ellipsis-037.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/block-ellipsis-037.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/block-ellipsis-037.html)

[ellipsis]
: Render an ellipsis character (U+2026)---​or a more
 typographically-appropriate equivalent---​as the [block overflow
 ellipsis](#block-overflow-ellipsis) at the end of the affected line box. UAs should use
 the conventions of the [content
 language](https://drafts.csswg.org/css-text-4/#content-language), writing system, and [writing
 mode](https://drafts.csswg.org/css-writing-modes-4/#writing-mode) to determine the most appropriate ellipsis string.
 Tests
 - [line-clamp-with-text-overflow-string-001.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-with-text-overflow-string-001.html "css/css-overflow/line-clamp/line-clamp-with-text-overflow-string-001.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-with-text-overflow-string-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-with-text-overflow-string-001.html)
 - [line-clamp-with-text-overflow-string-002.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-with-text-overflow-string-002.html "css/css-overflow/line-clamp/line-clamp-with-text-overflow-string-002.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-with-text-overflow-string-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-with-text-overflow-string-002.html)
 - [line-clamp-with-text-overflow-string-003.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-with-text-overflow-string-003.html "css/css-overflow/line-clamp/line-clamp-with-text-overflow-string-003.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-with-text-overflow-string-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-with-text-overflow-string-003.html)

[[\<string\>](https://drafts.csswg.org/css-values-4/#string-value)]

: Render the specified string as the [block overflow
 ellipsis](#block-overflow-ellipsis) at the end of the affected line box. The UA may
 truncate this string if it is absurdly long.

 Tests

 - [block-ellipsis-038.html](https://wpt.fyi/results/css/css-overflow/line-clamp/block-ellipsis-038.html "css/css-overflow/line-clamp/block-ellipsis-038.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/block-ellipsis-038.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/block-ellipsis-038.html)

 When set to the empty string, the behavior is identical to the
 [no-ellipsis](#valdef-block-ellipsis-no-ellipsis) value.

 Tests

 - [block-ellipsis-024.html](https://wpt.fyi/results/css/css-overflow/line-clamp/block-ellipsis-024.html "css/css-overflow/line-clamp/block-ellipsis-024.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/block-ellipsis-024.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/block-ellipsis-024.html)

 All forced line breaks inside the specified string (regardless of
 [white-space](https://drafts.csswg.org/css-text-4/#propdef-white-space) value) must be collapsed, as
 defined for collapsible segment breaks in [CSS Text 3 § 4.1.3
 Segment Break Transformation
 Rules](https://drafts.csswg.org/css-text-3/#line-break-transform).

When
[block-ellipsis](#propdef-block-ellipsis) is neither
[no-ellipsis](#valdef-block-ellipsis-no-ellipsis) nor the empty string, the [block overflow
ellipsis](#block-overflow-ellipsis) string is placed at the end of the line box reducing
the space available to the other contents of the line.

Tests

- [block-ellipsis-023.html](https://wpt.fyi/results/css/css-overflow/line-clamp/block-ellipsis-023.html "css/css-overflow/line-clamp/block-ellipsis-023.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/block-ellipsis-023.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/block-ellipsis-023.html)
- [block-ellipsis-024.html](https://wpt.fyi/results/css/css-overflow/line-clamp/block-ellipsis-024.html "css/css-overflow/line-clamp/block-ellipsis-024.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/block-ellipsis-024.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/block-ellipsis-024.html)
- [block-ellipsis-repaint-001.html](https://wpt.fyi/results/css/css-overflow/line-clamp/block-ellipsis-repaint-001.html "css/css-overflow/line-clamp/block-ellipsis-repaint-001.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/block-ellipsis-repaint-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/block-ellipsis-repaint-001.html)
- [block-ellipsis-repaint-003.html](https://wpt.fyi/results/css/css-overflow/line-clamp/block-ellipsis-repaint-003.html "css/css-overflow/line-clamp/block-ellipsis-repaint-003.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/block-ellipsis-repaint-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/block-ellipsis-repaint-003.html)
- [block-ellipsis-repaint-004.html](https://wpt.fyi/results/css/css-overflow/line-clamp/block-ellipsis-repaint-004.html "css/css-overflow/line-clamp/block-ellipsis-repaint-004.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/block-ellipsis-repaint-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/block-ellipsis-repaint-004.html)

More specifically:

- The [block overflow
 ellipsis](#block-overflow-ellipsis) is wrapped in an anonymous inline whose parent is the
 [block
 container](https://drafts.csswg.org/css-display-4/#block-container)'s [root inline
 box](https://drafts.csswg.org/css-inline-3/#root-inline-box). This inline is assigned [line-height:
 0](https://drafts.csswg.org/css2/#propdef-line-height).

 Tests

 - [block-ellipsis-002.html](https://wpt.fyi/results/css/css-overflow/line-clamp/block-ellipsis-002.html "css/css-overflow/line-clamp/block-ellipsis-002.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/block-ellipsis-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/block-ellipsis-002.html)
 - [block-ellipsis-003.html](https://wpt.fyi/results/css/css-overflow/line-clamp/block-ellipsis-003.html "css/css-overflow/line-clamp/block-ellipsis-003.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/block-ellipsis-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/block-ellipsis-003.html)
 - [block-ellipsis-004.html](https://wpt.fyi/results/css/css-overflow/line-clamp/block-ellipsis-004.html "css/css-overflow/line-clamp/block-ellipsis-004.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/block-ellipsis-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/block-ellipsis-004.html)
 - [block-ellipsis-005.html](https://wpt.fyi/results/css/css-overflow/line-clamp/block-ellipsis-005.html "css/css-overflow/line-clamp/block-ellipsis-005.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/block-ellipsis-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/block-ellipsis-005.html)
 - [block-ellipsis-006.html](https://wpt.fyi/results/css/css-overflow/line-clamp/block-ellipsis-006.html "css/css-overflow/line-clamp/block-ellipsis-006.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/block-ellipsis-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/block-ellipsis-006.html)
 - [block-ellipsis-010.html](https://wpt.fyi/results/css/css-overflow/line-clamp/block-ellipsis-010.html "css/css-overflow/line-clamp/block-ellipsis-010.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/block-ellipsis-010.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/block-ellipsis-010.html)

 For bidi purposes, the [block overflow
 ellipsis](#block-overflow-ellipsis) must be treated as an anonymous inline with
 [unicode-bidi:
 isolate](https://drafts.csswg.org/css-writing-modes-3/#propdef-unicode-bidi), with the same embedding level as the [bidi
 paragraph](https://drafts.csswg.org/css-writing-modes-4/#bidi-paragraph), and which inherits [direction] from the [bidi
 paragraph].

 Tests

 - [webkit-line-clamp-014.html](https://wpt.fyi/results/css/css-overflow/line-clamp/webkit-line-clamp-014.html "css/css-overflow/line-clamp/webkit-line-clamp-014.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/webkit-line-clamp-014.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/webkit-line-clamp-014.html)
 - [block-ellipsis-bidi-001.html](https://wpt.fyi/results/css/css-overflow/line-clamp/block-ellipsis-bidi-001.html "css/css-overflow/line-clamp/block-ellipsis-bidi-001.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/block-ellipsis-bidi-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/block-ellipsis-bidi-001.html)
 - [block-ellipsis-bidi-002.html](https://wpt.fyi/results/css/css-overflow/line-clamp/block-ellipsis-bidi-002.html "css/css-overflow/line-clamp/block-ellipsis-bidi-002.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/block-ellipsis-bidi-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/block-ellipsis-bidi-002.html)
 - [block-ellipsis-bidi-003.html](https://wpt.fyi/results/css/css-overflow/line-clamp/block-ellipsis-bidi-003.html "css/css-overflow/line-clamp/block-ellipsis-bidi-003.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/block-ellipsis-bidi-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/block-ellipsis-bidi-003.html)
 - [block-ellipsis-bidi-004.html](https://wpt.fyi/results/css/css-overflow/line-clamp/block-ellipsis-bidi-004.html "css/css-overflow/line-clamp/block-ellipsis-bidi-004.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/block-ellipsis-bidi-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/block-ellipsis-bidi-004.html)
 - [line-clamp-with-text-overflow-string-004.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-with-text-overflow-string-004.html "css/css-overflow/line-clamp/line-clamp-with-text-overflow-string-004.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-with-text-overflow-string-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-with-text-overflow-string-004.html)
 - [line-clamp-with-text-overflow-string-005.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-with-text-overflow-string-005.html "css/css-overflow/line-clamp/line-clamp-with-text-overflow-string-005.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-with-text-overflow-string-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-with-text-overflow-string-005.html)
 - [line-clamp-with-text-overflow-string-006.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-with-text-overflow-string-006.html "css/css-overflow/line-clamp/line-clamp-with-text-overflow-string-006.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-with-text-overflow-string-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-with-text-overflow-string-006.html)
 - [line-clamp-with-text-overflow-string-007.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-with-text-overflow-string-007.html "css/css-overflow/line-clamp/line-clamp-with-text-overflow-string-007.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-with-text-overflow-string-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-with-text-overflow-string-007.html)
 - [line-clamp-with-text-overflow-string-008.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-with-text-overflow-string-008.html "css/css-overflow/line-clamp/line-clamp-with-text-overflow-string-008.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-with-text-overflow-string-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-with-text-overflow-string-008.html)
 - [line-clamp-with-text-overflow-string-009.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-with-text-overflow-string-009.html "css/css-overflow/line-clamp/line-clamp-with-text-overflow-string-009.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-with-text-overflow-string-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-with-text-overflow-string-009.html)

- The user agent makes room as necessary of the [block overflow
 ellipsis](#block-overflow-ellipsis) by displacing content from the end of the line as if
 wrapping, until the last [soft wrap
 opportunity](https://drafts.csswg.org/css-text-4/#soft-wrap-opportunity) (see
 [\[CSS-TEXT-3\]](#biblio-css-text-3 "CSS Text Module Level 3"))
 that would still allow the entire [block overflow
 ellipsis] to fit on the line,
 applying [CSS Text 4 § 4.3 The White Space Processing
 Rules](https://drafts.csswg.org/css-text-4/#white-space-rules)
 including [CSS Text 4 § 4.3.2 Phase II: Trimming and
 Positioning](https://drafts.csswg.org/css-text-4/#white-space-phase-2)
 before insertion.

 Tests

 - [block-ellipsis-001.html](https://wpt.fyi/results/css/css-overflow/line-clamp/block-ellipsis-001.html "css/css-overflow/line-clamp/block-ellipsis-001.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/block-ellipsis-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/block-ellipsis-001.html)
 - [block-ellipsis-028.html](https://wpt.fyi/results/css/css-overflow/line-clamp/block-ellipsis-028.html "css/css-overflow/line-clamp/block-ellipsis-028.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/block-ellipsis-028.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/block-ellipsis-028.html)
 - [block-ellipsis-029.html](https://wpt.fyi/results/css/css-overflow/line-clamp/block-ellipsis-029.html "css/css-overflow/line-clamp/block-ellipsis-029.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/block-ellipsis-029.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/block-ellipsis-029.html)
 - [block-ellipsis-030.html](https://wpt.fyi/results/css/css-overflow/line-clamp/block-ellipsis-030.html "css/css-overflow/line-clamp/block-ellipsis-030.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/block-ellipsis-030.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/block-ellipsis-030.html)
 - [webkit-line-clamp-025.html](https://wpt.fyi/results/css/css-overflow/line-clamp/webkit-line-clamp-025.html "css/css-overflow/line-clamp/webkit-line-clamp-025.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/webkit-line-clamp-025.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/webkit-line-clamp-025.html)

 For this purpose, [soft wrap
 opportunities](https://drafts.csswg.org/css-text-4/#soft-wrap-opportunity) added by
 [overflow-wrap](https://drafts.csswg.org/css-text-4/#propdef-overflow-wrap) are ignored, as are those
 inhibited by [text-wrap-mode:
 nowrap](https://drafts.csswg.org/css-text-4/#propdef-text-wrap-mode).

 Tests

 - [block-ellipsis-013.html](https://wpt.fyi/results/css/css-overflow/line-clamp/block-ellipsis-013.html "css/css-overflow/line-clamp/block-ellipsis-013.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/block-ellipsis-013.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/block-ellipsis-013.html)
 - [block-ellipsis-014.html](https://wpt.fyi/results/css/css-overflow/line-clamp/block-ellipsis-014.html "css/css-overflow/line-clamp/block-ellipsis-014.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/block-ellipsis-014.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/block-ellipsis-014.html)
 - [block-ellipsis-015.tentative.html](https://wpt.fyi/results/css/css-overflow/line-clamp/block-ellipsis-015.tentative.html "css/css-overflow/line-clamp/block-ellipsis-015.tentative.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/block-ellipsis-015.tentative.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/block-ellipsis-015.tentative.html)
 - [block-ellipsis-016.html](https://wpt.fyi/results/css/css-overflow/line-clamp/block-ellipsis-016.html "css/css-overflow/line-clamp/block-ellipsis-016.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/block-ellipsis-016.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/block-ellipsis-016.html)
 - [block-ellipsis-017.html](https://wpt.fyi/results/css/css-overflow/line-clamp/block-ellipsis-017.html "css/css-overflow/line-clamp/block-ellipsis-017.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/block-ellipsis-017.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/block-ellipsis-017.html)
 - [block-ellipsis-027.html](https://wpt.fyi/results/css/css-overflow/line-clamp/block-ellipsis-027.html "css/css-overflow/line-clamp/block-ellipsis-027.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/block-ellipsis-027.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/block-ellipsis-027.html)

 If this results in the entire contents of the line box being
 displaced, the line box is considered to contain a
 [strut](https://www.w3.org/TR/CSS21/visudet.html#strut) styled according to the [root inline
 box](https://drafts.csswg.org/css-inline-3/#root-inline-box), as defined in [CSS 2 § 10.8.1 Leading and
 half-leading](https://www.w3.org/TR/CSS2/visudet.html#leading). [ This
 requirement applies regardless of the document's
 [mode](https://dom.spec.whatwg.org/#concept-document-mode), and is not affected by the [line-height
 quirk](https://quirks.spec.whatwg.org/#the-blocks-ignore-line-height-quirk).
 ]

 Tests

 - [block-ellipsis-016.html](https://wpt.fyi/results/css/css-overflow/line-clamp/block-ellipsis-016.html "css/css-overflow/line-clamp/block-ellipsis-016.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/block-ellipsis-016.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/block-ellipsis-016.html)
 - [block-ellipsis-018.html](https://wpt.fyi/results/css/css-overflow/line-clamp/block-ellipsis-018.html "css/css-overflow/line-clamp/block-ellipsis-018.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/block-ellipsis-018.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/block-ellipsis-018.html)
 - [block-ellipsis-025.html](https://wpt.fyi/results/css/css-overflow/line-clamp/block-ellipsis-025.html "css/css-overflow/line-clamp/block-ellipsis-025.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/block-ellipsis-025.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/block-ellipsis-025.html)
 - [block-ellipsis-036.html](https://wpt.fyi/results/css/css-overflow/line-clamp/block-ellipsis-036.html "css/css-overflow/line-clamp/block-ellipsis-036.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/block-ellipsis-036.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/block-ellipsis-036.html)
 - [block-ellipsis-039.html](https://wpt.fyi/results/css/css-overflow/line-clamp/block-ellipsis-039.html "css/css-overflow/line-clamp/block-ellipsis-039.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/block-ellipsis-039.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/block-ellipsis-039.html)
 - [block-ellipsis-quirk-001.html](https://wpt.fyi/results/css/css-overflow/line-clamp/block-ellipsis-quirk-001.html "css/css-overflow/line-clamp/block-ellipsis-quirk-001.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/block-ellipsis-quirk-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/block-ellipsis-quirk-001.html)
 - [block-ellipsis-quirk-002.html](https://wpt.fyi/results/css/css-overflow/line-clamp/block-ellipsis-quirk-002.html "css/css-overflow/line-clamp/block-ellipsis-quirk-002.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/block-ellipsis-quirk-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/block-ellipsis-quirk-002.html)

 Displacing content to make room for the [block overflow
 ellipsis](#block-overflow-ellipsis) can cause the [logical
 height](https://drafts.csswg.org/css-writing-modes-4/#logical-height) of line box where it is inserted to shrink. This must
 not cause a reevaluation of the effects of the
 [continue](#propdef-continue) property and must not change which
 line box is the last one before the truncated content.

 Tests

 - [line-clamp-auto-041.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-auto-041.html "css/css-overflow/line-clamp/line-clamp-auto-041.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-auto-041.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-auto-041.html)

 The user agent must not attempt to make room for the ellipsis by other
 means that displacing content from the end of the line; notably, user
 agent must not shift down the line box where the ellipsis is to be
 placed in order to clear a
 [float](https://drafts.csswg.org/css-page-floats-3/#float) or to be positioned in a wider subsequent
 [fragmentation
 container](https://drafts.csswg.org/css-break-4/#fragmentation-container) even if that would increase the available width.

 Tests

 - [block-ellipsis-040.html](https://wpt.fyi/results/css/css-overflow/line-clamp/block-ellipsis-040.html "css/css-overflow/line-clamp/block-ellipsis-040.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/block-ellipsis-040.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/block-ellipsis-040.html)

- The anonymous inline of [block overflow
 ellipsis](#block-overflow-ellipsis) is placed after any remaining content, after [CSS
 Text 4 § 4.3.2 Phase II: Trimming and
 Positioning](https://drafts.csswg.org/css-text-4/#white-space-phase-2),
 as a direct child of the [block
 container](https://drafts.csswg.org/css-display-4/#block-container)'s [root inline
 box](https://drafts.csswg.org/css-inline-3/#root-inline-box).

 Tests

 - [block-ellipsis-004.html](https://wpt.fyi/results/css/css-overflow/line-clamp/block-ellipsis-004.html "css/css-overflow/line-clamp/block-ellipsis-004.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/block-ellipsis-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/block-ellipsis-004.html)
 - [block-ellipsis-005.html](https://wpt.fyi/results/css/css-overflow/line-clamp/block-ellipsis-005.html "css/css-overflow/line-clamp/block-ellipsis-005.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/block-ellipsis-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/block-ellipsis-005.html)
 - [block-ellipsis-006.html](https://wpt.fyi/results/css/css-overflow/line-clamp/block-ellipsis-006.html "css/css-overflow/line-clamp/block-ellipsis-006.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/block-ellipsis-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/block-ellipsis-006.html)
 - [block-ellipsis-026.html](https://wpt.fyi/results/css/css-overflow/line-clamp/block-ellipsis-026.html "css/css-overflow/line-clamp/block-ellipsis-026.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/block-ellipsis-026.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/block-ellipsis-026.html)
 - [block-ellipsis-031.html](https://wpt.fyi/results/css/css-overflow/line-clamp/block-ellipsis-031.html "css/css-overflow/line-clamp/block-ellipsis-031.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/block-ellipsis-031.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/block-ellipsis-031.html)
 - [webkit-line-clamp-014.html](https://wpt.fyi/results/css/css-overflow/line-clamp/webkit-line-clamp-014.html "css/css-overflow/line-clamp/webkit-line-clamp-014.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/webkit-line-clamp-014.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/webkit-line-clamp-014.html)
 - [webkit-line-clamp-032.html](https://wpt.fyi/results/css/css-overflow/line-clamp/webkit-line-clamp-032.html "css/css-overflow/line-clamp/webkit-line-clamp-032.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/webkit-line-clamp-032.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/webkit-line-clamp-032.html)
 - [webkit-line-clamp-035.html](https://wpt.fyi/results/css/css-overflow/line-clamp/webkit-line-clamp-035.html "css/css-overflow/line-clamp/webkit-line-clamp-035.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/webkit-line-clamp-035.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/webkit-line-clamp-035.html)

- Sequences of [white
 space](https://drafts.csswg.org/css-text-4/#white-space), [other space
 separators](https://drafts.csswg.org/css-text-4/#other-space-separators) and/or
 [preserved](https://drafts.csswg.org/css-text-4/#preserved-white-space) tabs at the end of the line that would
 [hang](https://drafts.csswg.org/css-text-4/#hang)
 ([conditionally](https://drafts.csswg.org/css-text-4/#conditionally-hang) or not) had the ellipsis not been inserted get
 removed, and the ellipsis is then inserted.

 Tests

 - [block-ellipsis-032.html](https://wpt.fyi/results/css/css-overflow/line-clamp/block-ellipsis-032.html "css/css-overflow/line-clamp/block-ellipsis-032.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/block-ellipsis-032.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/block-ellipsis-032.html)
 - [block-ellipsis-033.html](https://wpt.fyi/results/css/css-overflow/line-clamp/block-ellipsis-033.html "css/css-overflow/line-clamp/block-ellipsis-033.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/block-ellipsis-033.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/block-ellipsis-033.html)

 The ellipsis is subject to the effects of the \'hanging punctuation\'
 property.

 Tests

 - [block-ellipsis-035.html](https://wpt.fyi/results/css/css-overflow/line-clamp/block-ellipsis-035.html "css/css-overflow/line-clamp/block-ellipsis-035.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/block-ellipsis-035.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/block-ellipsis-035.html)

 When the ellipsis is inserted after punctuation, that
 punctuation itself is no longer at the end of the line and thus cannot
 [hang](https://drafts.csswg.org/css-text-4/#hang).

 Tests

 - [block-ellipsis-034.html](https://wpt.fyi/results/css/css-overflow/line-clamp/block-ellipsis-034.html "css/css-overflow/line-clamp/block-ellipsis-034.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/block-ellipsis-034.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/block-ellipsis-034.html)

- Normally, if a line box that would have been placed next to a
 [float](https://drafts.csswg.org/css-page-floats-3/#float) is too short to contain any content, it is shifted
 downward until either some content fits or there are no more floats
 present. (See [Cascading Style Sheets Level 2 Revision 1 (CSS 2.1)
 Specification § floats](https://drafts.csswg.org/css2/#floats)).
 However, if, after displacing content to make room for the ellipsis
 and inserting the ellipsis, the content would be short enough for the
 line box to fit next to the float, the user agent must not shift the
 line box down, and must keep it at its original position.

 Tests

 - [block-ellipsis-041.html](https://wpt.fyi/results/css/css-overflow/line-clamp/block-ellipsis-041.html "css/css-overflow/line-clamp/block-ellipsis-041.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/block-ellipsis-041.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/block-ellipsis-041.html)
 - [line-clamp-with-floats-012.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-with-floats-012.html "css/css-overflow/line-clamp/line-clamp-with-floats-012.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-with-floats-012.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-with-floats-012.html)

Text [alignment and
justification](https://www.w3.org/TR/css-text-3/#justification) occurs
after placement, and measures the inserted [block overflow
ellipsis](#block-overflow-ellipsis) together with the rest of the line's content.

Tests

- [webkit-line-clamp-051.html](https://wpt.fyi/results/css/css-overflow/line-clamp/webkit-line-clamp-051.html "css/css-overflow/line-clamp/webkit-line-clamp-051.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/webkit-line-clamp-051.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/webkit-line-clamp-051.html)
- [webkit-line-clamp-052.html](https://wpt.fyi/results/css/css-overflow/line-clamp/webkit-line-clamp-052.html "css/css-overflow/line-clamp/webkit-line-clamp-052.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/webkit-line-clamp-052.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/webkit-line-clamp-052.html)
- [webkit-line-clamp-053.html](https://wpt.fyi/results/css/css-overflow/line-clamp/webkit-line-clamp-053.html "css/css-overflow/line-clamp/webkit-line-clamp-053.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/webkit-line-clamp-053.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/webkit-line-clamp-053.html)

 Setting the [block overflow
ellipsis](#block-overflow-ellipsis)'s
[line-height](https://drafts.csswg.org/css2/#propdef-line-height) to [0] makes sure that
inserting it cannot cause the line's height to grow, which could cause
further relayouts and potentially cycles. This is almost equivalent to
inserting the [block overflow
ellipsis] as a paint-time operation,
except that it still participates in alignment and justification. The
downside is that unusually tall / deep glyphs in the [block overflow
ellipsis] may overflow.

The [block overflow
ellipsis](#block-overflow-ellipsis) must not be included in either the
[::first-letter](https://drafts.csswg.org/css-pseudo-4/#selectordef-first-letter) nor the
[::first-line](https://drafts.csswg.org/css-pseudo-4/#selectordef-first-line) pseudo-elements.

Tests

- [block-ellipsis-007.html](https://wpt.fyi/results/css/css-overflow/line-clamp/block-ellipsis-007.html "css/css-overflow/line-clamp/block-ellipsis-007.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/block-ellipsis-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/block-ellipsis-007.html)
- [block-ellipsis-008.html](https://wpt.fyi/results/css/css-overflow/line-clamp/block-ellipsis-008.html "css/css-overflow/line-clamp/block-ellipsis-008.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/block-ellipsis-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/block-ellipsis-008.html)
- [block-ellipsis-009.html](https://wpt.fyi/results/css/css-overflow/line-clamp/block-ellipsis-009.html "css/css-overflow/line-clamp/block-ellipsis-009.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/block-ellipsis-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/block-ellipsis-009.html)
- [block-ellipsis-019.html](https://wpt.fyi/results/css/css-overflow/line-clamp/block-ellipsis-019.html "css/css-overflow/line-clamp/block-ellipsis-019.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/block-ellipsis-019.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/block-ellipsis-019.html)
- [block-ellipsis-020.html](https://wpt.fyi/results/css/css-overflow/line-clamp/block-ellipsis-020.html "css/css-overflow/line-clamp/block-ellipsis-020.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/block-ellipsis-020.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/block-ellipsis-020.html)
- [block-ellipsis-021.html](https://wpt.fyi/results/css/css-overflow/line-clamp/block-ellipsis-021.html "css/css-overflow/line-clamp/block-ellipsis-021.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/block-ellipsis-021.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/block-ellipsis-021.html)

If the [block overflow
ellipsis](#block-overflow-ellipsis) is placed before a [region
break](https://drafts.csswg.org/css-break-4/#region-break) and there is a subsequent [fragmentation
container](https://drafts.csswg.org/css-break-4/#fragmentation-container) in the [fragmentation
context](https://drafts.csswg.org/css-break-4/#fragmentation-context) that would receive subsequent content, then the content
displaced by the [block overflow
ellipsis] must be pushed to that
[fragmentation container]. If it is
placed before a [clamp point](#clamp-point), then the displaced content must be pushed to the
remainder of the [inline formatting
context](https://drafts.csswg.org/css-display-4/#inline-formatting-context).

The UA must treat the [block overflow
ellipsis](#block-overflow-ellipsis) as an unbreakable string, If any part of the [block
overflow ellipsis] overflows, it is
treated as [scrollable
overflow](https://drafts.csswg.org/css-overflow-3/#scrollable-overflow), and its rendering is affected by the
[text-overflow](#propdef-text-overflow) property.

Tests

- [line-clamp-text-overflow-001.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-text-overflow-001.html "css/css-overflow/line-clamp/line-clamp-text-overflow-001.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-text-overflow-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-text-overflow-001.html)
- [line-clamp-with-text-overflow-string-010-crash.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-with-text-overflow-string-010-crash.html "css/css-overflow/line-clamp/line-clamp-with-text-overflow-string-010-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-with-text-overflow-string-010-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-with-text-overflow-string-010-crash.html)

The [block overflow
ellipsis](#block-overflow-ellipsis) does not capture events: pointer events are dispatched
to whatever is underneath it.

It also has no effect on the intrinsic size of the box: its
[min-content](https://drafts.csswg.org/css-sizing-3/#min-content) and
[max-content](https://drafts.csswg.org/css-sizing-3/#max-content) sizes are calculated exactly as if
[block-ellipsis](#propdef-block-ellipsis) were
[no-ellipsis](#valdef-block-ellipsis-no-ellipsis).

Tests

- [line-clamp-intrinsic-size-001.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-intrinsic-size-001.html "css/css-overflow/line-clamp/line-clamp-intrinsic-size-001.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-intrinsic-size-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-intrinsic-size-001.html)
- [line-clamp-intrinsic-size-002.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-intrinsic-size-002.html "css/css-overflow/line-clamp/line-clamp-intrinsic-size-002.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-intrinsic-size-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-intrinsic-size-002.html)

 Future specifications may extend this feature, for
example by providing an [::ellipsis] pseudo-element to style the
text, or by allowing the selection of a child element of the block to
use as either an inline-level or block-level indicator (in which case,
it can capture events).

## 5. Suppressing Excess Content

### 5.1. Limiting Visible Lines: the [line-clamp shorthand property]
Name:

[line-clamp]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

none
[\|](https://drafts.csswg.org/css-values-4/#comb-one)
\[[\<\'max-lines\'\>](#propdef-max-lines)
[\|\|](https://drafts.csswg.org/css-values-4/#comb-any)
[\<\'block-ellipsis\'\>](#propdef-block-ellipsis)\]
[-webkit-legacy](#valdef-line-clamp--webkit-legacy)[?](https://drafts.csswg.org/css-values-4/#mult-opt)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

none

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

see individual properties

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

see individual properties

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

N/A

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

see individual properties

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

see individual properties

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

Tests

- [line-clamp-valid.html](https://wpt.fyi/results/css/css-overflow/parsing/line-clamp-valid.html "css/css-overflow/parsing/line-clamp-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/parsing/line-clamp-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/parsing/line-clamp-valid.html)
- [line-clamp-invalid.html](https://wpt.fyi/results/css/css-overflow/parsing/line-clamp-invalid.html "css/css-overflow/parsing/line-clamp-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/parsing/line-clamp-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/parsing/line-clamp-invalid.html)

<!-- -->

- [line-clamp-043-crash.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-043-crash.html "css/css-overflow/line-clamp/line-clamp-043-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-043-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-043-crash.html)

The [line-clamp](#propdef-line-clamp) property is a
[shorthand](https://drafts.csswg.org/css-cascade-5/#shorthand-property) for the
[max-lines](#propdef-max-lines),
[block-ellipsis](#propdef-block-ellipsis), and
[continue](#propdef-continue) properties.

It allows limiting the contents of a block container to the specified
number of lines; remaining content is fragmented away and neither
rendered nor measured. Optionally, it also allows inserting content into
the last line box to indicate the continuity of truncated/interrupted
content.

Tests

- [line-clamp-001.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-001.html "css/css-overflow/line-clamp/line-clamp-001.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-001.html)
- [webkit-line-clamp-034.html](https://wpt.fyi/results/css/css-overflow/line-clamp/webkit-line-clamp-034.html "css/css-overflow/line-clamp/webkit-line-clamp-034.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/webkit-line-clamp-034.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/webkit-line-clamp-034.html)

The values have the following meaning:

[none]
: Sets [max-lines](#propdef-max-lines) to
 [auto](#max-lines-auto),
 [continue](#propdef-continue) to
 [normal](#valdef-continue-normal), and
 [block-ellipsis](#propdef-block-ellipsis) to
 [no-ellipsis](#valdef-block-ellipsis-no-ellipsis).
 Tests
 - [line-clamp-020.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-020.html "css/css-overflow/line-clamp/line-clamp-020.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-020.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-020.html)
 - [line-clamp-auto-038.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-auto-038.html "css/css-overflow/line-clamp/line-clamp-auto-038.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-auto-038.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-auto-038.html)
 - [webkit-line-clamp-018.html](https://wpt.fyi/results/css/css-overflow/line-clamp/webkit-line-clamp-018.html "css/css-overflow/line-clamp/webkit-line-clamp-018.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/webkit-line-clamp-018.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/webkit-line-clamp-018.html)

[\<[max-lines](#propdef-max-lines)\>]\
[\<[block-ellipsis](#propdef-block-ellipsis)\>]

: Sets [continue](#propdef-continue) to
 [collapse](#valdef-continue-collapse) if either or both values are specified,
 unless the
 [-webkit-legacy](#valdef-line-clamp--webkit-legacy) keyword is also specified (see below).

 Sets [max-lines](#propdef-max-lines) and
 [block-ellipsis](#propdef-block-ellipsis) to the corresponding values, or
 to [max-lines: auto] and
 [block-ellipsis: ellipsis]
 respectively if omitted.

 Tests

 - [line-clamp-auto-001-crash.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-auto-001-crash.html "css/css-overflow/line-clamp/line-clamp-auto-001-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-auto-001-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-auto-001-crash.html)
 - [line-clamp-auto-002-crash.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-auto-002-crash.html "css/css-overflow/line-clamp/line-clamp-auto-002-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-auto-002-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-auto-002-crash.html)
 - [line-clamp-auto-001.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-auto-001.html "css/css-overflow/line-clamp/line-clamp-auto-001.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-auto-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-auto-001.html)
 - [block-ellipsis-038.html](https://wpt.fyi/results/css/css-overflow/line-clamp/block-ellipsis-038.html "css/css-overflow/line-clamp/block-ellipsis-038.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/block-ellipsis-038.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/block-ellipsis-038.html)
 - [line-clamp-040-crash.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-040-crash.html "css/css-overflow/line-clamp/line-clamp-040-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-040-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-040-crash.html)

[-webkit-legacy]
: Sets [continue](#propdef-continue) to
 [-webkit-legacy](#valdef-continue--webkit-legacy).

See the corresponding longhand properties for details about how this
mechanism operates.

In this example, the lead paragraph of
each article is listed in a shortened menu, truncated to fit within 5
lines that end with "... (continued on next page)":

``` highlight
li {
 line-clamp: 5 "… (continued on next page)";
}
strong {
 display: block;
 text-transform: uppercase;
}
```

``` highlight
<li><a href="cheese-is-milk">
 <strong>Cheese is Actually Made of Milk!</strong>
 Investigative reporters at the World Wide Web Press Corps
 have discovered the secret of cheese.
 Tracing through byzantine layers of bureaucracy and shadow corporations,
 our crack team of journalists have traced the source of camembert.
</a></li>
```

Sample rendering:

``` figure
+---------------------------------------+
| CHEESE IS ACTUALLY MADE OF MILK! |
| Investigative reporters at the World |
| Wide Web Press Corps have discovered |
| the secret of cheese. Tracing through |
| byzantine… (continued on next page) |
+---------------------------------------+
```

#### 5.1.1. Legacy compatibility

For compatibility with legacy content, UAs that support
[line-clamp](#propdef-line-clamp) must also support the
[-webkit-line-clamp](#propdef--webkit-line-clamp) property and the additional
[-webkit-legacy](#valdef-continue--webkit-legacy) value for the
[continue](#propdef-continue) property.

Name:

[-webkit-line-clamp]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

none
[\|](https://drafts.csswg.org/css-values-4/#comb-one) [\<integer
\[1,∞\]\>](https://drafts.csswg.org/css-values-4/#integer-value)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

none

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

see individual properties

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

see individual properties

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

N/A

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

see individual properties

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

see individual properties

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

Tests

- [webkit-line-clamp-041-crash.html](https://wpt.fyi/results/css/css-overflow/line-clamp/webkit-line-clamp-041-crash.html "css/css-overflow/line-clamp/webkit-line-clamp-041-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/webkit-line-clamp-041-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/webkit-line-clamp-041-crash.html)
- [webkit-line-clamp-042-crash.html](https://wpt.fyi/results/css/css-overflow/line-clamp/webkit-line-clamp-042-crash.html "css/css-overflow/line-clamp/webkit-line-clamp-042-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/webkit-line-clamp-042-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/webkit-line-clamp-042-crash.html)
- [webkit-line-clamp-bug-1926732-crash.html](https://wpt.fyi/results/css/css-overflow/line-clamp/webkit-line-clamp-bug-1926732-crash.html "css/css-overflow/line-clamp/webkit-line-clamp-bug-1926732-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/webkit-line-clamp-bug-1926732-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/webkit-line-clamp-bug-1926732-crash.html)
- [webkit-line-clamp-049.html](https://wpt.fyi/results/css/css-overflow/line-clamp/webkit-line-clamp-049.html "css/css-overflow/line-clamp/webkit-line-clamp-049.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/webkit-line-clamp-049.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/webkit-line-clamp-049.html)
- [webkit-line-clamp-050.html](https://wpt.fyi/results/css/css-overflow/line-clamp/webkit-line-clamp-050.html "css/css-overflow/line-clamp/webkit-line-clamp-050.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/webkit-line-clamp-050.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/webkit-line-clamp-050.html)
- [webkit-line-clamp-bug-2063759-crash.html](https://wpt.fyi/results/css/css-overflow/line-clamp/webkit-line-clamp-bug-2063759-crash.html "css/css-overflow/line-clamp/webkit-line-clamp-bug-2063759-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/webkit-line-clamp-bug-2063759-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/webkit-line-clamp-bug-2063759-crash.html)
- [webkit-line-clamp-054-crash.html](https://wpt.fyi/results/css/css-overflow/line-clamp/webkit-line-clamp-054-crash.html "css/css-overflow/line-clamp/webkit-line-clamp-054-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/webkit-line-clamp-054-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/webkit-line-clamp-054-crash.html)

<!-- -->

- [webkit-line-clamp-valid.html](https://wpt.fyi/results/css/css-overflow/parsing/webkit-line-clamp-valid.html "css/css-overflow/parsing/webkit-line-clamp-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/parsing/webkit-line-clamp-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/parsing/webkit-line-clamp-valid.html)
- [webkit-line-clamp-invalid.html](https://wpt.fyi/results/css/css-overflow/parsing/webkit-line-clamp-invalid.html "css/css-overflow/parsing/webkit-line-clamp-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/parsing/webkit-line-clamp-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/parsing/webkit-line-clamp-invalid.html)

Name:

[continue](#propdef-continue)

[New values:](https://www.w3.org/TR/css-values/#value-defs)

-webkit-legacy

Like [line-clamp](#propdef-line-clamp),
[-webkit-line-clamp](#propdef--webkit-line-clamp) is a shorthand of
[max-lines](#propdef-max-lines),
[block-ellipsis](#propdef-block-ellipsis), and
[continue](#propdef-continue), except that:

Tests

- [line-clamp-019.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-019.html "css/css-overflow/line-clamp/line-clamp-019.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-019.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-019.html)
- [line-clamp-034.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-034.html "css/css-overflow/line-clamp/line-clamp-034.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-034.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-034.html)
- [webkit-line-clamp-005.html](https://wpt.fyi/results/css/css-overflow/line-clamp/webkit-line-clamp-005.html "css/css-overflow/line-clamp/webkit-line-clamp-005.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/webkit-line-clamp-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/webkit-line-clamp-005.html)

<!-- -->

- its syntax is
 [none](#valdef-line-clamp-none) \| [\<integer
 \[1,∞\]\>](https://drafts.csswg.org/css-values-4/#integer-value)

- it unconditionally sets
 [block-ellipsis](#propdef-block-ellipsis) to
 [ellipsis](#valdef-block-ellipsis-ellipsis)

 Tests

 - [webkit-line-clamp-003.html](https://wpt.fyi/results/css/css-overflow/line-clamp/webkit-line-clamp-003.html "css/css-overflow/line-clamp/webkit-line-clamp-003.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/webkit-line-clamp-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/webkit-line-clamp-003.html)
 - [webkit-line-clamp-004.html](https://wpt.fyi/results/css/css-overflow/line-clamp/webkit-line-clamp-004.html "css/css-overflow/line-clamp/webkit-line-clamp-004.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/webkit-line-clamp-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/webkit-line-clamp-004.html)

- it sets [continue](#propdef-continue) to
 [-webkit-legacy](#valdef-continue--webkit-legacy) instead of
 [collapse](#valdef-continue-collapse) when an [\<integer
 \[1,∞\]\>](https://drafts.csswg.org/css-values-4/#integer-value) is specified (as if the
 [-webkit-legacy](#valdef-line-clamp--webkit-legacy) keyword was set on
 [line-clamp](#propdef-line-clamp))

 Tests

 - [webkit-line-clamp-001.html](https://wpt.fyi/results/css/css-overflow/line-clamp/webkit-line-clamp-001.html "css/css-overflow/line-clamp/webkit-line-clamp-001.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/webkit-line-clamp-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/webkit-line-clamp-001.html)
 - [webkit-line-clamp-002.html](https://wpt.fyi/results/css/css-overflow/line-clamp/webkit-line-clamp-002.html "css/css-overflow/line-clamp/webkit-line-clamp-002.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/webkit-line-clamp-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/webkit-line-clamp-002.html)
 - [webkit-line-clamp-003.html](https://wpt.fyi/results/css/css-overflow/line-clamp/webkit-line-clamp-003.html "css/css-overflow/line-clamp/webkit-line-clamp-003.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/webkit-line-clamp-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/webkit-line-clamp-003.html)
 - [webkit-line-clamp-004.html](https://wpt.fyi/results/css/css-overflow/line-clamp/webkit-line-clamp-004.html "css/css-overflow/line-clamp/webkit-line-clamp-004.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/webkit-line-clamp-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/webkit-line-clamp-004.html)

The [-webkit-legacy] value
behaves identically to
[collapse](#valdef-continue-collapse), except that it only takes effect if the
[specified
value](https://drafts.csswg.org/css-cascade-5/#specified-value) of the
[display](https://drafts.csswg.org/css-display-4/#propdef-display) property is
[-webkit-box](https://compat.spec.whatwg.org/#valdef-flex--webkit-box) or
[-webkit-inline-box](https://compat.spec.whatwg.org/#valdef-flex--webkit-inline-box) and the value of the
[-webkit-box-orient](https://compat.spec.whatwg.org/#propdef--webkit-box-orient) property is [vertical].

Tests

- [webkit-line-clamp-001.html](https://wpt.fyi/results/css/css-overflow/line-clamp/webkit-line-clamp-001.html "css/css-overflow/line-clamp/webkit-line-clamp-001.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/webkit-line-clamp-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/webkit-line-clamp-001.html)
- [webkit-line-clamp-002.html](https://wpt.fyi/results/css/css-overflow/line-clamp/webkit-line-clamp-002.html "css/css-overflow/line-clamp/webkit-line-clamp-002.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/webkit-line-clamp-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/webkit-line-clamp-002.html)
- [webkit-line-clamp-007.html](https://wpt.fyi/results/css/css-overflow/line-clamp/webkit-line-clamp-007.html "css/css-overflow/line-clamp/webkit-line-clamp-007.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/webkit-line-clamp-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/webkit-line-clamp-007.html)
- [webkit-line-clamp-015.html](https://wpt.fyi/results/css/css-overflow/line-clamp/webkit-line-clamp-015.html "css/css-overflow/line-clamp/webkit-line-clamp-015.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/webkit-line-clamp-015.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/webkit-line-clamp-015.html)
- [webkit-line-clamp-016.html](https://wpt.fyi/results/css/css-overflow/line-clamp/webkit-line-clamp-016.html "css/css-overflow/line-clamp/webkit-line-clamp-016.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/webkit-line-clamp-016.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/webkit-line-clamp-016.html)
- [webkit-line-clamp-024.html](https://wpt.fyi/results/css/css-overflow/line-clamp/webkit-line-clamp-024.html "css/css-overflow/line-clamp/webkit-line-clamp-024.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/webkit-line-clamp-024.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/webkit-line-clamp-024.html)
- [webkit-line-clamp-026.html](https://wpt.fyi/results/css/css-overflow/line-clamp/webkit-line-clamp-026.html "css/css-overflow/line-clamp/webkit-line-clamp-026.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/webkit-line-clamp-026.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/webkit-line-clamp-026.html)
- [webkit-line-clamp-048.html](https://wpt.fyi/results/css/css-overflow/line-clamp/webkit-line-clamp-048.html "css/css-overflow/line-clamp/webkit-line-clamp-048.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/webkit-line-clamp-048.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/webkit-line-clamp-048.html)

 Implementations of the legacy
[-webkit-line-clamp](#propdef--webkit-line-clamp) property have not behaved
identically to what is specified here. The historical behavior is quirky
and less robust, as documented for example in [this blog
post](https://medium.com/mofed/css-line-clamp-the-good-the-bad-and-the-straight-up-broken-865413f16e5).
The current design learns from the mistakes of that early experiment,
and is intended to be sufficiently compatible with existing content that
implementations can eventually be changed to follow to the specified
behavior. If further adjustments are found to be necessary, they will be
incorporated to this specification. In the meanwhile, authors should be
aware that there may be discrepancies.

### 5.2. Forcing a Break After a Set Number of Lines: the [max-lines property]
Name:

[max-lines]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

auto
[\|\|](https://drafts.csswg.org/css-values-4/#comb-any) [\<integer
\[1,∞\]\>](https://drafts.csswg.org/css-values-4/#integer-value)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

auto

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[block
containers](https://drafts.csswg.org/css-display-4/#block-container) which are also either [line-clamp
containers](#line-clamp-container) or [fragmentation
containers](https://drafts.csswg.org/css-break-4/#fragmentation-container) that capture [region
breaks](https://drafts.csswg.org/css-break-4/#region-break)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

N/A

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

the keyword [auto](#max-lines-auto), or an integer, or both

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value type

Tests

- [max-lines-valid.html](https://wpt.fyi/results/css/css-overflow/parsing/max-lines-valid.html "css/css-overflow/parsing/max-lines-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/parsing/max-lines-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/parsing/max-lines-valid.html)
- [max-lines-invalid.html](https://wpt.fyi/results/css/css-overflow/parsing/max-lines-invalid.html "css/css-overflow/parsing/max-lines-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/parsing/max-lines-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/parsing/max-lines-invalid.html)

<!-- -->

- [webkit-line-clamp-030.html](https://wpt.fyi/results/css/css-overflow/line-clamp/webkit-line-clamp-030.html "css/css-overflow/line-clamp/webkit-line-clamp-030.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/webkit-line-clamp-030.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/webkit-line-clamp-030.html)

The [max-lines](#propdef-max-lines) property sets the [clamp
point](#clamp-point) of a
[line-clamp
container](#line-clamp-container), or forces a [region
break](https://drafts.csswg.org/css-break-4/#region-break) on a [fragmentation
container](https://drafts.csswg.org/css-break-4/#fragmentation-container). Values have the following meanings:

[[\<integer \[1,∞\]\>](https://drafts.csswg.org/css-values-4/#integer-value)]

: Given an integer `N`, if the box is a [line-clamp
 container](#line-clamp-container), it has an [line-based clamp
 point], set to the first possible [clamp
 point](#clamp-point) after
 its `N`th descendant
 [in-flow](https://drafts.csswg.org/css-display-4/#in-flow) [line
 box](https://drafts.csswg.org/css-inline-3/#line-box). If fewer than `N` line boxes exist, or
 if there are no possible clamp points after the `N`th
 descendant [in-flow] [line
 box], then that line-clamp container has no
 [line-based clamp
 point](#line-based-clamp-point).

 if the [line-clamp
 container](#line-clamp-container) has exactly `N` lines, and there are no
 boxes after the `N`th line, then there are no possible
 [clamp points](#clamp-point)
 after it, so no [block overflow
 ellipsis](#block-overflow-ellipsis) is shown.

 Tests

 - [block-ellipsis-022.html](https://wpt.fyi/results/css/css-overflow/line-clamp/block-ellipsis-022.html "css/css-overflow/line-clamp/block-ellipsis-022.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/block-ellipsis-022.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/block-ellipsis-022.html)
 - [line-clamp-001.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-001.html "css/css-overflow/line-clamp/line-clamp-001.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-001.html)
 - [line-clamp-002.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-002.html "css/css-overflow/line-clamp/line-clamp-002.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-002.html)
 - [line-clamp-003.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-003.html "css/css-overflow/line-clamp/line-clamp-003.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-003.html)
 - [line-clamp-005.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-005.html "css/css-overflow/line-clamp/line-clamp-005.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-005.html)
 - [line-clamp-006.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-006.html "css/css-overflow/line-clamp/line-clamp-006.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-006.html)
 - [line-clamp-022.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-022.html "css/css-overflow/line-clamp/line-clamp-022.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-022.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-022.html)
 - [line-clamp-023.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-023.html "css/css-overflow/line-clamp/line-clamp-023.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-023.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-023.html)
 - [line-clamp-024.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-024.html "css/css-overflow/line-clamp/line-clamp-024.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-024.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-024.html)
 - [line-clamp-025.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-025.html "css/css-overflow/line-clamp/line-clamp-025.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-025.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-025.html)
 - [line-clamp-030.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-030.html "css/css-overflow/line-clamp/line-clamp-030.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-030.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-030.html)
 - [line-clamp-037.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-037.html "css/css-overflow/line-clamp/line-clamp-037.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-037.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-037.html)
 - [line-clamp-038.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-038.html "css/css-overflow/line-clamp/line-clamp-038.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-038.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-038.html)
 - [line-clamp-with-abspos-018.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-with-abspos-018.html "css/css-overflow/line-clamp/line-clamp-with-abspos-018.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-with-abspos-018.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-with-abspos-018.html)
 - [webkit-line-clamp-003.html](https://wpt.fyi/results/css/css-overflow/line-clamp/webkit-line-clamp-003.html "css/css-overflow/line-clamp/webkit-line-clamp-003.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/webkit-line-clamp-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/webkit-line-clamp-003.html)
 - [webkit-line-clamp-004.html](https://wpt.fyi/results/css/css-overflow/line-clamp/webkit-line-clamp-004.html "css/css-overflow/line-clamp/webkit-line-clamp-004.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/webkit-line-clamp-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/webkit-line-clamp-004.html)
 - [webkit-line-clamp-005.html](https://wpt.fyi/results/css/css-overflow/line-clamp/webkit-line-clamp-005.html "css/css-overflow/line-clamp/webkit-line-clamp-005.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/webkit-line-clamp-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/webkit-line-clamp-005.html)
 - [webkit-line-clamp-006.html](https://wpt.fyi/results/css/css-overflow/line-clamp/webkit-line-clamp-006.html "css/css-overflow/line-clamp/webkit-line-clamp-006.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/webkit-line-clamp-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/webkit-line-clamp-006.html)
 - [webkit-line-clamp-009.html](https://wpt.fyi/results/css/css-overflow/line-clamp/webkit-line-clamp-009.html "css/css-overflow/line-clamp/webkit-line-clamp-009.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/webkit-line-clamp-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/webkit-line-clamp-009.html)
 - [webkit-line-clamp-010.html](https://wpt.fyi/results/css/css-overflow/line-clamp/webkit-line-clamp-010.html "css/css-overflow/line-clamp/webkit-line-clamp-010.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/webkit-line-clamp-010.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/webkit-line-clamp-010.html)
 - [webkit-line-clamp-017.html](https://wpt.fyi/results/css/css-overflow/line-clamp/webkit-line-clamp-017.html "css/css-overflow/line-clamp/webkit-line-clamp-017.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/webkit-line-clamp-017.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/webkit-line-clamp-017.html)
 - [webkit-line-clamp-019.html](https://wpt.fyi/results/css/css-overflow/line-clamp/webkit-line-clamp-019.html "css/css-overflow/line-clamp/webkit-line-clamp-019.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/webkit-line-clamp-019.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/webkit-line-clamp-019.html)
 - [webkit-line-clamp-020.html](https://wpt.fyi/results/css/css-overflow/line-clamp/webkit-line-clamp-020.html "css/css-overflow/line-clamp/webkit-line-clamp-020.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/webkit-line-clamp-020.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/webkit-line-clamp-020.html)
 - [webkit-line-clamp-021.html](https://wpt.fyi/results/css/css-overflow/line-clamp/webkit-line-clamp-021.html "css/css-overflow/line-clamp/webkit-line-clamp-021.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/webkit-line-clamp-021.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/webkit-line-clamp-021.html)
 - [webkit-line-clamp-022.html](https://wpt.fyi/results/css/css-overflow/line-clamp/webkit-line-clamp-022.html "css/css-overflow/line-clamp/webkit-line-clamp-022.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/webkit-line-clamp-022.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/webkit-line-clamp-022.html)
 - [webkit-line-clamp-023.html](https://wpt.fyi/results/css/css-overflow/line-clamp/webkit-line-clamp-023.html "css/css-overflow/line-clamp/webkit-line-clamp-023.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/webkit-line-clamp-023.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/webkit-line-clamp-023.html)
 - [webkit-line-clamp-030.html](https://wpt.fyi/results/css/css-overflow/line-clamp/webkit-line-clamp-030.html "css/css-overflow/line-clamp/webkit-line-clamp-030.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/webkit-line-clamp-030.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/webkit-line-clamp-030.html)
 - [webkit-line-clamp-031.html](https://wpt.fyi/results/css/css-overflow/line-clamp/webkit-line-clamp-031.html "css/css-overflow/line-clamp/webkit-line-clamp-031.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/webkit-line-clamp-031.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/webkit-line-clamp-031.html)
 - [webkit-line-clamp-033.html](https://wpt.fyi/results/css/css-overflow/line-clamp/webkit-line-clamp-033.html "css/css-overflow/line-clamp/webkit-line-clamp-033.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/webkit-line-clamp-033.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/webkit-line-clamp-033.html)
 - [webkit-line-clamp-038.html](https://wpt.fyi/results/css/css-overflow/line-clamp/webkit-line-clamp-038.html "css/css-overflow/line-clamp/webkit-line-clamp-038.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/webkit-line-clamp-038.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/webkit-line-clamp-038.html)
 - [webkit-line-clamp-039.html](https://wpt.fyi/results/css/css-overflow/line-clamp/webkit-line-clamp-039.html "css/css-overflow/line-clamp/webkit-line-clamp-039.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/webkit-line-clamp-039.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/webkit-line-clamp-039.html)
 - [webkit-line-clamp-040.html](https://wpt.fyi/results/css/css-overflow/line-clamp/webkit-line-clamp-040.html "css/css-overflow/line-clamp/webkit-line-clamp-040.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/webkit-line-clamp-040.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/webkit-line-clamp-040.html)
 - [webkit-line-clamp-043.html](https://wpt.fyi/results/css/css-overflow/line-clamp/webkit-line-clamp-043.html "css/css-overflow/line-clamp/webkit-line-clamp-043.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/webkit-line-clamp-043.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/webkit-line-clamp-043.html)
 - [line-clamp-with-block-in-inline-001.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-with-block-in-inline-001.html "css/css-overflow/line-clamp/line-clamp-with-block-in-inline-001.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-with-block-in-inline-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-with-block-in-inline-001.html)
 - [webkit-line-clamp-block-in-inline-001.html](https://wpt.fyi/results/css/css-overflow/line-clamp/webkit-line-clamp-block-in-inline-001.html "css/css-overflow/line-clamp/webkit-line-clamp-block-in-inline-001.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/webkit-line-clamp-block-in-inline-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/webkit-line-clamp-block-in-inline-001.html)
 - [webkit-line-clamp-dynamic-001.html](https://wpt.fyi/results/css/css-overflow/line-clamp/webkit-line-clamp-dynamic-001.html "css/css-overflow/line-clamp/webkit-line-clamp-dynamic-001.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/webkit-line-clamp-dynamic-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/webkit-line-clamp-dynamic-001.html)
 - [webkit-line-clamp-with-line-height.html](https://wpt.fyi/results/css/css-overflow/line-clamp/webkit-line-clamp-with-line-height.html "css/css-overflow/line-clamp/webkit-line-clamp-with-line-height.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/webkit-line-clamp-with-line-height.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/webkit-line-clamp-with-line-height.html)
 - [webkit-line-clamp-with-max-height.html](https://wpt.fyi/results/css/css-overflow/line-clamp/webkit-line-clamp-with-max-height.html "css/css-overflow/line-clamp/webkit-line-clamp-with-max-height.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/webkit-line-clamp-with-max-height.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/webkit-line-clamp-with-max-height.html)
 - [line-clamp-content-height-with-dynamic-change.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-content-height-with-dynamic-change.html "css/css-overflow/line-clamp/line-clamp-content-height-with-dynamic-change.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-content-height-with-dynamic-change.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-content-height-with-dynamic-change.html)

 If the box is instead a [fragmentation
 container](https://drafts.csswg.org/css-break-4/#fragmentation-container) that captures [region
 breaks](https://drafts.csswg.org/css-break-4/#region-break), then a [region break] is
 forced after its `N`th descendant
 [in-flow](https://drafts.csswg.org/css-display-4/#in-flow) [line
 box](https://drafts.csswg.org/css-inline-3/#line-box). If fewer than `N` line boxes exist,
 then [max-lines](#propdef-max-lines) introduces no [region
 break].

 Only line boxes in the same [block formatting
 context](https://drafts.csswg.org/css-display-4/#block-formatting-context) are counted: the contents of descendants that
 establish [independent formatting
 contexts](https://drafts.csswg.org/css-display-4/#independent-formatting-context) are skipped over while counting line boxes.

 Tests

 - [line-clamp-006.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-006.html "css/css-overflow/line-clamp/line-clamp-006.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-006.html)
 - [line-clamp-007.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-007.html "css/css-overflow/line-clamp/line-clamp-007.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-007.html)
 - [webkit-line-clamp-011.html](https://wpt.fyi/results/css/css-overflow/line-clamp/webkit-line-clamp-011.html "css/css-overflow/line-clamp/webkit-line-clamp-011.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/webkit-line-clamp-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/webkit-line-clamp-011.html)
 - [webkit-line-clamp-012.html](https://wpt.fyi/results/css/css-overflow/line-clamp/webkit-line-clamp-012.html "css/css-overflow/line-clamp/webkit-line-clamp-012.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/webkit-line-clamp-012.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/webkit-line-clamp-012.html)
 - [webkit-line-clamp-013.html](https://wpt.fyi/results/css/css-overflow/line-clamp/webkit-line-clamp-013.html "css/css-overflow/line-clamp/webkit-line-clamp-013.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/webkit-line-clamp-013.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/webkit-line-clamp-013.html)
 - [webkit-line-clamp-027.html](https://wpt.fyi/results/css/css-overflow/line-clamp/webkit-line-clamp-027.html "css/css-overflow/line-clamp/webkit-line-clamp-027.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/webkit-line-clamp-027.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/webkit-line-clamp-027.html)
 - [webkit-line-clamp-029.html](https://wpt.fyi/results/css/css-overflow/line-clamp/webkit-line-clamp-029.html "css/css-overflow/line-clamp/webkit-line-clamp-029.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/webkit-line-clamp-029.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/webkit-line-clamp-029.html)
 - [line-clamp-with-floats-007.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-with-floats-007.html "css/css-overflow/line-clamp/line-clamp-with-floats-007.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-with-floats-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-with-floats-007.html)

 This implies that
 [max-lines](#propdef-max-lines) has no effect when applied to
 [multi-column
 containers](https://drafts.csswg.org/css-multicol-2/#multi-column-container), since any line box they contain are nested into
 [independent formatting
 contexts](https://drafts.csswg.org/css-display-4/#independent-formatting-context).

 Tests

 - [discard-multicol-004.html](https://wpt.fyi/results/css/css-overflow/line-clamp/discard/discard-multicol-004.html "css/css-overflow/line-clamp/discard/discard-multicol-004.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/discard/discard-multicol-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/discard/discard-multicol-004.html)

 Only positive integers are accepted. Zero or negative integers are
 invalid and must cause the declaration to be
 [ignored](https://drafts.csswg.org/css-syntax-3/#css-ignored).

[auto]
: If the box is a [line-clamp
 container](#line-clamp-container), it has an [auto clamp point], set to the
 last possible clamp point such that, for it and all previous
 possible clamp points, the container's [automatic block
 size](https://drafts.csswg.org/css-sizing-3/#automatic-block-size) (as determined in [§ 5.3.1 Line-clamp
 containers](#line-clamp-containers)) is not greater than the [block
 size](https://drafts.csswg.org/css-sizing-3/#block-size) the box would have if its automatic block size were
 infinite. If the [block size] would be
 infinite, then there is no [auto clamp
 point](#auto-clamp-point).
 Tests
 - [line-clamp-auto-001.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-auto-001.html "css/css-overflow/line-clamp/line-clamp-auto-001.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-auto-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-auto-001.html)
 - [line-clamp-auto-004.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-auto-004.html "css/css-overflow/line-clamp/line-clamp-auto-004.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-auto-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-auto-004.html)
 - [line-clamp-auto-005.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-auto-005.html "css/css-overflow/line-clamp/line-clamp-auto-005.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-auto-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-auto-005.html)
 - [line-clamp-auto-006.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-auto-006.html "css/css-overflow/line-clamp/line-clamp-auto-006.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-auto-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-auto-006.html)
 - [line-clamp-auto-007.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-auto-007.html "css/css-overflow/line-clamp/line-clamp-auto-007.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-auto-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-auto-007.html)
 - [line-clamp-auto-008.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-auto-008.html "css/css-overflow/line-clamp/line-clamp-auto-008.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-auto-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-auto-008.html)
 - [line-clamp-auto-011.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-auto-011.html "css/css-overflow/line-clamp/line-clamp-auto-011.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-auto-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-auto-011.html)
 - [line-clamp-auto-012.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-auto-012.html "css/css-overflow/line-clamp/line-clamp-auto-012.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-auto-012.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-auto-012.html)
 - [line-clamp-auto-013.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-auto-013.html "css/css-overflow/line-clamp/line-clamp-auto-013.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-auto-013.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-auto-013.html)
 - [line-clamp-auto-014.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-auto-014.html "css/css-overflow/line-clamp/line-clamp-auto-014.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-auto-014.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-auto-014.html)
 - [line-clamp-auto-016.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-auto-016.html "css/css-overflow/line-clamp/line-clamp-auto-016.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-auto-016.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-auto-016.html)
 - [line-clamp-auto-018.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-auto-018.html "css/css-overflow/line-clamp/line-clamp-auto-018.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-auto-018.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-auto-018.html)
 - [line-clamp-auto-019.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-auto-019.html "css/css-overflow/line-clamp/line-clamp-auto-019.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-auto-019.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-auto-019.html)
 - [line-clamp-auto-020.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-auto-020.html "css/css-overflow/line-clamp/line-clamp-auto-020.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-auto-020.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-auto-020.html)
 - [line-clamp-auto-021.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-auto-021.html "css/css-overflow/line-clamp/line-clamp-auto-021.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-auto-021.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-auto-021.html)
 - [line-clamp-auto-022.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-auto-022.html "css/css-overflow/line-clamp/line-clamp-auto-022.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-auto-022.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-auto-022.html)
 - [line-clamp-auto-023.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-auto-023.html "css/css-overflow/line-clamp/line-clamp-auto-023.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-auto-023.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-auto-023.html)
 - [line-clamp-auto-024.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-auto-024.html "css/css-overflow/line-clamp/line-clamp-auto-024.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-auto-024.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-auto-024.html)
 - [line-clamp-auto-027.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-auto-027.html "css/css-overflow/line-clamp/line-clamp-auto-027.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-auto-027.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-auto-027.html)
 - [line-clamp-auto-028.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-auto-028.html "css/css-overflow/line-clamp/line-clamp-auto-028.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-auto-028.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-auto-028.html)
 - [line-clamp-auto-029.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-auto-029.html "css/css-overflow/line-clamp/line-clamp-auto-029.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-auto-029.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-auto-029.html)
 - [line-clamp-auto-030.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-auto-030.html "css/css-overflow/line-clamp/line-clamp-auto-030.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-auto-030.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-auto-030.html)
 - [line-clamp-auto-031.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-auto-031.html "css/css-overflow/line-clamp/line-clamp-auto-031.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-auto-031.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-auto-031.html)
 - [line-clamp-auto-032.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-auto-032.html "css/css-overflow/line-clamp/line-clamp-auto-032.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-auto-032.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-auto-032.html)
 - [line-clamp-auto-035.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-auto-035.html "css/css-overflow/line-clamp/line-clamp-auto-035.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-auto-035.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-auto-035.html)
 - [line-clamp-auto-036.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-auto-036.html "css/css-overflow/line-clamp/line-clamp-auto-036.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-auto-036.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-auto-036.html)
 - [line-clamp-auto-037.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-auto-037.html "css/css-overflow/line-clamp/line-clamp-auto-037.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-auto-037.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-auto-037.html)
 - [line-clamp-auto-039.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-auto-039.html "css/css-overflow/line-clamp/line-clamp-auto-039.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-auto-039.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-auto-039.html)
 - [line-clamp-auto-040.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-auto-040.html "css/css-overflow/line-clamp/line-clamp-auto-040.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-auto-040.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-auto-040.html)
 - [line-clamp-auto-042.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-auto-042.html "css/css-overflow/line-clamp/line-clamp-auto-042.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-auto-042.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-auto-042.html)
 - [line-clamp-auto-043.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-auto-043.html "css/css-overflow/line-clamp/line-clamp-auto-043.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-auto-043.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-auto-043.html)
 - [line-clamp-auto-044.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-auto-044.html "css/css-overflow/line-clamp/line-clamp-auto-044.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-auto-044.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-auto-044.html)
 - [line-clamp-auto-045.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-auto-045.html "css/css-overflow/line-clamp/line-clamp-auto-045.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-auto-045.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-auto-045.html)
 - [line-clamp-auto-046.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-auto-046.html "css/css-overflow/line-clamp/line-clamp-auto-046.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-auto-046.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-auto-046.html)
 - [line-clamp-auto-047.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-auto-047.html "css/css-overflow/line-clamp/line-clamp-auto-047.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-auto-047.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-auto-047.html)
 - [line-clamp-auto-048.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-auto-048.html "css/css-overflow/line-clamp/line-clamp-auto-048.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-auto-048.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-auto-048.html)
 - [line-clamp-auto-049.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-auto-049.html "css/css-overflow/line-clamp/line-clamp-auto-049.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-auto-049.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-auto-049.html)
 - [line-clamp-auto-050.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-auto-050.html "css/css-overflow/line-clamp/line-clamp-auto-050.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-auto-050.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-auto-050.html)
 - [line-clamp-auto-051.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-auto-051.html "css/css-overflow/line-clamp/line-clamp-auto-051.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-auto-051.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-auto-051.html)
 - [line-clamp-auto-052.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-auto-052.html "css/css-overflow/line-clamp/line-clamp-auto-052.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-auto-052.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-auto-052.html)
 - [line-clamp-auto-053.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-auto-053.html "css/css-overflow/line-clamp/line-clamp-auto-053.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-auto-053.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-auto-053.html)
 - [line-clamp-auto-054.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-auto-054.html "css/css-overflow/line-clamp/line-clamp-auto-054.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-auto-054.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-auto-054.html)
 - [line-clamp-auto-055.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-auto-055.html "css/css-overflow/line-clamp/line-clamp-auto-055.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-auto-055.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-auto-055.html)
 - [line-clamp-auto-056.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-auto-056.html "css/css-overflow/line-clamp/line-clamp-auto-056.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-auto-056.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-auto-056.html)
 - [line-clamp-auto-057.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-auto-057.html "css/css-overflow/line-clamp/line-clamp-auto-057.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-auto-057.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-auto-057.html)
 - [line-clamp-auto-058.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-auto-058.html "css/css-overflow/line-clamp/line-clamp-auto-058.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-auto-058.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-auto-058.html)
 - [line-clamp-auto-059.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-auto-059.html "css/css-overflow/line-clamp/line-clamp-auto-059.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-auto-059.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-auto-059.html)
 - [line-clamp-auto-060.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-auto-060.html "css/css-overflow/line-clamp/line-clamp-auto-060.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-auto-060.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-auto-060.html)
 - [line-clamp-auto-061.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-auto-061.html "css/css-overflow/line-clamp/line-clamp-auto-061.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-auto-061.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-auto-061.html)
 - [line-clamp-auto-062.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-auto-062.html "css/css-overflow/line-clamp/line-clamp-auto-062.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-auto-062.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-auto-062.html)
 - [line-clamp-auto-063.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-auto-063.html "css/css-overflow/line-clamp/line-clamp-auto-063.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-auto-063.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-auto-063.html)
 - [line-clamp-auto-with-ruby-002.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-auto-with-ruby-002.html "css/css-overflow/line-clamp/line-clamp-auto-with-ruby-002.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-auto-with-ruby-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-auto-with-ruby-002.html)
 - [line-clamp-auto-with-ruby-003.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-auto-with-ruby-003.html "css/css-overflow/line-clamp/line-clamp-auto-with-ruby-003.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-auto-with-ruby-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-auto-with-ruby-003.html)
 - [line-clamp-auto-with-ruby-004.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-auto-with-ruby-004.html "css/css-overflow/line-clamp/line-clamp-auto-with-ruby-004.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-auto-with-ruby-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-auto-with-ruby-004.html)

If the box is a [line-clamp
container](#line-clamp-container), then its chosen [clamp
point](#clamp-point) is either
its [line-based clamp
point](#line-based-clamp-point) or its [auto clamp
point](#auto-clamp-point).
If both exist, then whichever comes earlier takes precedence. If neither
exist, then there is no [clamp point].

Tests

- [line-clamp-011.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-011.html "css/css-overflow/line-clamp/line-clamp-011.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-011.html)
- [line-clamp-035.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-035.html "css/css-overflow/line-clamp/line-clamp-035.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-035.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-035.html)
- [line-clamp-041.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-041.html "css/css-overflow/line-clamp/line-clamp-041.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-041.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-041.html)
- [line-clamp-042.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-042.html "css/css-overflow/line-clamp/line-clamp-042.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-042.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-042.html)
- [line-clamp-auto-057.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-auto-057.html "css/css-overflow/line-clamp/line-clamp-auto-057.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-auto-057.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-auto-057.html)

 The
[widows](https://drafts.csswg.org/css-break-4/#propdef-widows),
[orphans](https://drafts.csswg.org/css-break-3/#propdef-orphans), and
[break-inside](https://drafts.csswg.org/css-break-3/#propdef-break-inside) properties do not affect the
position of the forced [region
break](https://drafts.csswg.org/css-break-4/#region-break) introduced by the
[max-lines](#propdef-max-lines) property.

Note: Despite the "region break" name, this is not a dependency on
[\[CSS-REGIONS-1\]](#biblio-css-regions-1 "CSS Regions Module Level 1").
The word "region" is only used as a classifier for forced breaks: they
can be "page breaks" (breaks across pages
[\[css-page-3\]](#biblio-css-page-3 "CSS Paged Media Module Level 3")),
"column breaks" (breaks across multi-column layout columns
[\[css-multicol-1\]](#biblio-css-multicol-1 "CSS Multi-column Layout Module Level 1")),
or "region breaks" (breaks across any other kind of CSS-induced
[fragmentation
containers](https://drafts.csswg.org/css-break-4/#fragmentation-container)).

If an implementation supports neither
[\[CSS-REGIONS-1\]](#biblio-css-regions-1 "CSS Regions Module Level 1")
nor [continue: discard](#propdef-continue), then it will have had no occasion yet to run
into that kind of breaks, and this will be an addition. However the
addition does not involve bringing over any of the
[\[CSS-REGIONS-1\]](#biblio-css-regions-1 "CSS Regions Module Level 1")
functionality. All that is needed is:

- be able to fragment

- classify these fragmentation containers as "Category 3" (i.e. not
 pages nor columns) for the purpose of forced breaks.

### 5.3. Handling of Excess Content: the [continue property]
Name:

[continue]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

normal
[\|](https://drafts.csswg.org/css-values-4/#comb-one) discard [\|] collapse

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

normal

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[block
containers](https://drafts.csswg.org/css-display-4/#block-container) and [multicol
containers](https://drafts.csswg.org/css-multicol-2/#multi-column-container)

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

Tests

- [continue-valid.html](https://wpt.fyi/results/css/css-overflow/parsing/continue-valid.html "css/css-overflow/parsing/continue-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/parsing/continue-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/parsing/continue-valid.html)
- [continue-invalid.html](https://wpt.fyi/results/css/css-overflow/parsing/continue-invalid.html "css/css-overflow/parsing/continue-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/parsing/continue-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/parsing/continue-invalid.html)

<!-- -->

- [line-clamp-014.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-014.html "css/css-overflow/line-clamp/line-clamp-014.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-014.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-014.html)
- [line-clamp-015.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-015.html "css/css-overflow/line-clamp/line-clamp-015.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-015.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-015.html)
- [line-clamp-029.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-029.html "css/css-overflow/line-clamp/line-clamp-029.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-029.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-029.html)

The [continue](#propdef-continue) property gives authors the ability to
truncate/interrupt the content inside a box, either by [visually
suppressing](#visually-suppressed) the remaining content, or by turning the box into a
[fragmentation
container](https://drafts.csswg.org/css-break-4/#fragmentation-container) (see
[\[CSS-BREAK-3\]](#biblio-css-break-3 "CSS Fragmentation Module Level 3"))
and discarding the content after the [fragmentation
break](https://drafts.csswg.org/css-break-4/#fragmentation-break).

[normal]

: If the box has more content than can fit, the excess content is
 handled according to the usual rules.

[collapse]

: If the box is a [block
 container](https://drafts.csswg.org/css-display-4/#block-container), then it must [establish an independent formatting
 context](https://drafts.csswg.org/css-display-4/#establish-an-independent-formatting-context) that also becomes a [line-clamp
 container](#line-clamp-container). This causes all content after the [clamp
 point](#clamp-point) to be
 [visually
 suppressed](#visually-suppressed), and to not be taken into account for the box's
 [automatic block
 size](https://drafts.csswg.org/css-sizing-3/#automatic-block-size) (see [§ 5.3.1 Line-clamp
 containers](#line-clamp-containers) for details).

 Tests

 - [line-clamp-bfc.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-bfc.html "css/css-overflow/line-clamp/line-clamp-bfc.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-bfc.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-bfc.html)
 - [line-clamp-004.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-004.html "css/css-overflow/line-clamp/line-clamp-004.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-004.html)
 - [line-clamp-008.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-008.html "css/css-overflow/line-clamp/line-clamp-008.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-008.html)
 - [line-clamp-009.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-009.html "css/css-overflow/line-clamp/line-clamp-009.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-009.html)
 - [line-clamp-013.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-013.html "css/css-overflow/line-clamp/line-clamp-013.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-013.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-013.html)
 - [line-clamp-031.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-031.html "css/css-overflow/line-clamp/line-clamp-031.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-031.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-031.html)
 - [webkit-line-clamp-006.html](https://wpt.fyi/results/css/css-overflow/line-clamp/webkit-line-clamp-006.html "css/css-overflow/line-clamp/webkit-line-clamp-006.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/webkit-line-clamp-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/webkit-line-clamp-006.html)
 - [webkit-line-clamp-040.html](https://wpt.fyi/results/css/css-overflow/line-clamp/webkit-line-clamp-040.html "css/css-overflow/line-clamp/webkit-line-clamp-040.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/webkit-line-clamp-040.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/webkit-line-clamp-040.html)
 - [continue-001.html](https://wpt.fyi/results/css/css-overflow/line-clamp/continue-001.html "css/css-overflow/line-clamp/continue-001.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/continue-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/continue-001.html)

 [Visually suppressed] content is treated as content
 hidden by [overflow:
 clip](https://drafts.csswg.org/css-overflow-3/#propdef-overflow), and unlike content made
 [invisible](https://drafts.csswg.org/css-display-4/#invisible-box) by [visibility:
 hidden](https://drafts.csswg.org/css-display-4/#propdef-visibility) or excluded from the box tree by
 [display:
 none](https://drafts.csswg.org/css-display-4/#propdef-display): it is not painted, and like [ink
 overflow](https://drafts.csswg.org/css-overflow-3/#ink-overflow), does not affect layout or otherwise extend the
 [scrollable overflow
 area](https://drafts.csswg.org/css-overflow-3/#scrollable-overflow-region). However, it remains part of of [sequential focus
 navigation](https://html.spec.whatwg.org/multipage/interaction.html#sequential-focus-navigation), and remains exposed through the [accessibility
 tree](https://w3c.github.io/aria/#dfn-accessibility-tree). Any overflow [visually
 suppressed](#visually-suppressed) boxes and line boxes might have is itself counted
 as [ink overflow] rather than [scrollable
 overflow](https://drafts.csswg.org/css-overflow-3/#scrollable-overflow).

 Tests

 - [line-clamp-preserves-dom-content.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-preserves-dom-content.html "css/css-overflow/line-clamp/line-clamp-preserves-dom-content.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-preserves-dom-content.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-preserves-dom-content.html)
 - [line-clamp-preserves-tabbing.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-preserves-tabbing.html "css/css-overflow/line-clamp/line-clamp-preserves-tabbing.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-preserves-tabbing.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-preserves-tabbing.html)
 - [line-clamp-with-floats-010.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-with-floats-010.html "css/css-overflow/line-clamp/line-clamp-with-floats-010.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-with-floats-010.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-with-floats-010.html)
 - [line-clamp-021.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-021.html "css/css-overflow/line-clamp/line-clamp-021.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-021.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-021.html)
 - [line-clamp-with-abspos-019.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-with-abspos-019.html "css/css-overflow/line-clamp/line-clamp-with-abspos-019.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-with-abspos-019.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-with-abspos-019.html)

 [NOTE:] This differs from the [display:
 none](https://drafts.csswg.org/css-display-4/#propdef-display)-like behavior of not rendered content
 with [continue:
 discard](#propdef-continue).

 If the box is a [multicol
 container](https://drafts.csswg.org/css-multicol-2/#multi-column-container), the behavior is the same as
 [normal](#valdef-continue-normal).

 Tests

 - [line-clamp-039.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-039.html "css/css-overflow/line-clamp/line-clamp-039.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-039.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-039.html)

[discard]

: The box must [establish an independent formatting
 context](https://drafts.csswg.org/css-display-4/#establish-an-independent-formatting-context) and becomes a [fragmentation
 container](https://drafts.csswg.org/css-break-4/#fragmentation-container) that captures [region
 breaks](https://drafts.csswg.org/css-break-4/#region-break), if it is not already.
 [\[CSS-BREAK-3\]](#biblio-css-break-3 "CSS Fragmentation Module Level 3")
 Content after the first [region break] is
 not rendered.

 This [region
 break](https://drafts.csswg.org/css-break-4/#region-break) might be
 [forced](https://drafts.csswg.org/css-break-4/#forced-break) (e.g. imposed by
 [max-lines](#propdef-max-lines) or by another mechanism, such as the
 [break-before](https://drafts.csswg.org/css-break-3/#propdef-break-before)/[break-after](https://drafts.csswg.org/css-break-3/#propdef-break-after) properties) or
 [unforced](https://drafts.csswg.org/css-break-4/#unforced-break) (e.g. if the content would otherwise overflow this
 [fragmentation
 container](https://drafts.csswg.org/css-break-4/#fragmentation-container) due to its size constraints). Breaks applying to
 other [fragmentation
 contexts](https://drafts.csswg.org/css-break-4/#fragmentation-context) (such as pagination of this box itself) do not
 cause any content to be discarded.

 See [§ 5.3.2 Discarding Content](#discarding-content) for further
 details.

 (#issue-b97a50c8) [continue:
 discard](#propdef-continue) is meant to generalize and replace the
 `region-fragment` property from
 [\[CSS-REGIONS-1\]](#biblio-css-regions-1 "CSS Regions Module Level 1").
 Once it is sufficiently stable in this specification,
 `region-fragment` should be removed from the regions specification
 in favor of this.

 [continue:
 discard](#propdef-continue) is [at
 risk](https://www.w3.org/policies/process/#at-risk): it may be removed before advancement to
 [Recommendation](https://www.w3.org/policies/process/#RecsW3C) if criteria for advancement are not fulfilled.

Given, as in the illustration
bellow, an article with one excessively long overflowing line and four
more lines in the [block
dimension](https://drafts.csswg.org/css-writing-modes-4/#block-dimension) than can fit, different renderings are possible based
on the combination of the
[overflow](https://drafts.csswg.org/css-overflow-3/#propdef-overflow) and
[continue](#propdef-continue) property.

!(images/continue-flow.png){a
height="109" width="100"}

[continue: collapse](#propdef-continue) / [continue: discard]

[continue: normal](#propdef-continue)

[overflow:
visible](https://drafts.csswg.org/css-overflow-3/#propdef-overflow)

![rendering with continue:discard and
overflow:visible](images/continue-discard-visible.png){height="90"
width="88"}

![rendering with continue:auto and
overflow:visible](images/continue-auto-visible.png){height="116"
width="89"}

[overflow:
hidden](https://drafts.csswg.org/css-overflow-3/#propdef-overflow)

![rendering with continue:discard and
overflow:hidden](images/continue-discard-hidden.png){height="90"
width="78"}

![rendering with continue:auto and
overflow:hidden](images/continue-auto-hidden.png){height="90"
width="78"}

[text-wrap-style](https://drafts.csswg.org/css-text-4/#propdef-text-wrap-style) is set to
[balance](https://drafts.csswg.org/css-text-4/#valdef-text-wrap-style-balance) on a block container whose
[continue](#propdef-continue) has a value other than
[normal](#valdef-continue-normal), or which participates in the [block formatting
context](https://drafts.csswg.org/css-display-4/#block-formatting-context) established by an element whose
[continue] has a value other than
[normal], layout must first be
computed as if [text-wrap-style] were set to
[stable](https://drafts.csswg.org/css-text-4/#valdef-text-wrap-style-stable). Then, after any excess content has been
truncated and after any necessary [block overflow
ellipsis](#block-overflow-ellipsis) has been inserted, the remaining content must be
rebalanced, as per [text-wrap-style:
balance]. If this rebalancing
would cause the [logical
height](https://drafts.csswg.org/css-writing-modes-4/#logical-height) of the content to grow, the cutoff point ([clamp
point](#clamp-point) or
[fragmentation
break](https://drafts.csswg.org/css-break-4/#fragmentation-break)) must be reevaluated, and any necessary [block overflow
ellipsis] reapplied accordingly.
Whether to rebalance again after that is up to the user agent, but if it
does so, it must always ensure that the constraints about the placement
of the cutoff point are adhered to, no matter how many iterations it
choose to make.

Tests

- [line-clamp-balance-001.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-balance-001.html "css/css-overflow/line-clamp/line-clamp-balance-001.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-balance-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-balance-001.html)
- [line-clamp-balance-002.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-balance-002.html "css/css-overflow/line-clamp/line-clamp-balance-002.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-balance-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-balance-002.html)
- [line-clamp-balance-003.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-balance-003.html "css/css-overflow/line-clamp/line-clamp-balance-003.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-balance-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-balance-003.html)
- [line-clamp-balance-004.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-balance-004.html "css/css-overflow/line-clamp/line-clamp-balance-004.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-balance-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-balance-004.html)
- [line-clamp-balance-005.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-balance-005.html "css/css-overflow/line-clamp/line-clamp-balance-005.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-balance-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-balance-005.html)
- [line-clamp-balance-006.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-balance-006.html "css/css-overflow/line-clamp/line-clamp-balance-006.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-balance-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-balance-006.html)
- [line-clamp-balance-007.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-balance-007.html "css/css-overflow/line-clamp/line-clamp-balance-007.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-balance-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-balance-007.html)
- [line-clamp-balance-008.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-balance-008.html "css/css-overflow/line-clamp/line-clamp-balance-008.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-balance-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-balance-008.html)
- [line-clamp-balance-009.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-balance-009.html "css/css-overflow/line-clamp/line-clamp-balance-009.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-balance-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-balance-009.html)
- [line-clamp-balance-010.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-balance-010.html "css/css-overflow/line-clamp/line-clamp-balance-010.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-balance-010.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-balance-010.html)
- [line-clamp-balance-011.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-balance-011.html "css/css-overflow/line-clamp/line-clamp-balance-011.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-balance-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-balance-011.html)
- [line-clamp-balance-012.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-balance-012.html "css/css-overflow/line-clamp/line-clamp-balance-012.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-balance-012.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-balance-012.html)

For other values of
[text-wrap-style](https://drafts.csswg.org/css-text-4/#propdef-text-wrap-style), whether to apply them before the
effects of the [continue](#propdef-continue) property, after, or both, is
undefined in this level.

Additionally, for compatibility (see [§ 5.1.1 Legacy
compatibility](#webkit-line-clamp)), when the [computed
value](https://drafts.csswg.org/css-cascade-5/#computed-value) of the
[continue](#propdef-continue) property is
[collapse](#valdef-continue-collapse),
[-webkit-legacy](#valdef-continue--webkit-legacy), or
[discard](#valdef-continue-discard) and the [computed
value] of the
[-webkit-box-orient](https://compat.spec.whatwg.org/#propdef--webkit-box-orient) property is [vertical]:

- If the [specified
 value](https://drafts.csswg.org/css-cascade-5/#specified-value) of the
 [display](https://drafts.csswg.org/css-display-4/#propdef-display) property is
 [-webkit-box](https://compat.spec.whatwg.org/#valdef-flex--webkit-box), the [computed
 value](https://drafts.csswg.org/css-cascade-5/#computed-value) becomes
 [flow-root](https://drafts.csswg.org/css-display-4/#valdef-display-flow-root) and the box establishes a
 [BFC](https://drafts.csswg.org/css-display-4/#bfc).

 Tests

 - [line-clamp-016.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-016.html "css/css-overflow/line-clamp/line-clamp-016.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-016.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-016.html)
 - [line-clamp-017.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-017.html "css/css-overflow/line-clamp/line-clamp-017.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-017.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-017.html)
 - [line-clamp-018.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-018.html "css/css-overflow/line-clamp/line-clamp-018.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-018.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-018.html)
 - [webkit-line-clamp-007.html](https://wpt.fyi/results/css/css-overflow/line-clamp/webkit-line-clamp-007.html "css/css-overflow/line-clamp/webkit-line-clamp-007.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/webkit-line-clamp-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/webkit-line-clamp-007.html)
 - [webkit-line-clamp-008.html](https://wpt.fyi/results/css/css-overflow/line-clamp/webkit-line-clamp-008.html "css/css-overflow/line-clamp/webkit-line-clamp-008.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/webkit-line-clamp-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/webkit-line-clamp-008.html)
 - [webkit-line-clamp-045.html](https://wpt.fyi/results/css/css-overflow/line-clamp/webkit-line-clamp-045.html "css/css-overflow/line-clamp/webkit-line-clamp-045.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/webkit-line-clamp-045.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/webkit-line-clamp-045.html)
 - [webkit-line-clamp-046.html](https://wpt.fyi/results/css/css-overflow/line-clamp/webkit-line-clamp-046.html "css/css-overflow/line-clamp/webkit-line-clamp-046.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/webkit-line-clamp-046.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/webkit-line-clamp-046.html)

- If the [specified
 value](https://drafts.csswg.org/css-cascade-5/#specified-value) of the
 [display](https://drafts.csswg.org/css-display-4/#propdef-display) property is
 [-webkit-inline-box](https://compat.spec.whatwg.org/#valdef-flex--webkit-inline-box), the [computed
 value](https://drafts.csswg.org/css-cascade-5/#computed-value) becomes
 [inline-block](https://drafts.csswg.org/css-display-4/#valdef-display-inline-block) and the box establishes a
 [BFC](https://drafts.csswg.org/css-display-4/#bfc).

 Tests

 - [webkit-line-clamp-024.html](https://wpt.fyi/results/css/css-overflow/line-clamp/webkit-line-clamp-024.html "css/css-overflow/line-clamp/webkit-line-clamp-024.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/webkit-line-clamp-024.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/webkit-line-clamp-024.html)

Tests

- [webkit-box-computed.html](https://wpt.fyi/results/css/css-overflow/parsing/webkit-box-computed.html "css/css-overflow/parsing/webkit-box-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/parsing/webkit-box-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/parsing/webkit-box-computed.html)

 This means that
[line-clamp](#propdef-line-clamp) (set without
[-webkit-legacy](#valdef-line-clamp--webkit-legacy)) will work if both or neither of
[-webkit-box-orient:
vertical](https://compat.spec.whatwg.org/#propdef--webkit-box-orient) and [display:
-webkit-box](https://drafts.csswg.org/css-display-4/#propdef-display) or [display:
-webkit-inline-box] are set, but not if
[display: -webkit-box] or [display:
-webkit-inline-box] is set while
[-webkit-box-orient: vertical] isn't, as the box would be a [flex
container](https://drafts.csswg.org/css-flexbox-2/#flex-container) rather than a [block
container](https://drafts.csswg.org/css-display-4/#block-container), and thus the
[continue](#propdef-continue) property would not apply.

Tests

- [line-clamp-029.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-029.html "css/css-overflow/line-clamp/line-clamp-029.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-029.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-029.html)

#### 5.3.1. Line-clamp containers

A [line-clamp container] is an
[independent](https://drafts.csswg.org/css-display-4/#independent-formatting-context) [block formatting
context](https://drafts.csswg.org/css-display-4/#block-formatting-context) that additionally follows the rules in this section.
Line-clamp containers can have a [clamp point], which is one of the following
block-axis positions inside it:

- The start of the [line-clamp
 container](#line-clamp-container).

 Tests

 - [line-clamp-auto-011.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-auto-011.html "css/css-overflow/line-clamp/line-clamp-auto-011.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-auto-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-auto-011.html)
 - [line-clamp-auto-037.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-auto-037.html "css/css-overflow/line-clamp/line-clamp-auto-037.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-auto-037.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-auto-037.html)

- A point between two consecutive [line
 boxes](https://drafts.csswg.org/css-inline-3/#line-box) in an [inline formatting
 context](https://drafts.csswg.org/css-display-4/#inline-formatting-context) contained by the line-clamp container's [block
 formatting
 context](https://drafts.csswg.org/css-display-4/#block-formatting-context).

 Tests

 - [line-clamp-auto-004.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-auto-004.html "css/css-overflow/line-clamp/line-clamp-auto-004.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-auto-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-auto-004.html)
 - [line-clamp-auto-005.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-auto-005.html "css/css-overflow/line-clamp/line-clamp-auto-005.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-auto-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-auto-005.html)
 - [line-clamp-auto-013.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-auto-013.html "css/css-overflow/line-clamp/line-clamp-auto-013.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-auto-013.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-auto-013.html)
 - [line-clamp-auto-014.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-auto-014.html "css/css-overflow/line-clamp/line-clamp-auto-014.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-auto-014.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-auto-014.html)
 - [line-clamp-auto-016.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-auto-016.html "css/css-overflow/line-clamp/line-clamp-auto-016.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-auto-016.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-auto-016.html)
 - [line-clamp-auto-017.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-auto-017.html "css/css-overflow/line-clamp/line-clamp-auto-017.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-auto-017.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-auto-017.html)
 - [line-clamp-auto-with-ruby-001.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-auto-with-ruby-001.html "css/css-overflow/line-clamp/line-clamp-auto-with-ruby-001.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-auto-with-ruby-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-auto-with-ruby-001.html)
 - [line-clamp-auto-with-ruby-002.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-auto-with-ruby-002.html "css/css-overflow/line-clamp/line-clamp-auto-with-ruby-002.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-auto-with-ruby-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-auto-with-ruby-002.html)
 - [line-clamp-auto-with-ruby-003.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-auto-with-ruby-003.html "css/css-overflow/line-clamp/line-clamp-auto-with-ruby-003.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-auto-with-ruby-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-auto-with-ruby-003.html)
 - [line-clamp-auto-with-ruby-004.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-auto-with-ruby-004.html "css/css-overflow/line-clamp/line-clamp-auto-with-ruby-004.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-auto-with-ruby-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-auto-with-ruby-004.html)
 - [webkit-line-clamp-031.html](https://wpt.fyi/results/css/css-overflow/line-clamp/webkit-line-clamp-031.html "css/css-overflow/line-clamp/webkit-line-clamp-031.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/webkit-line-clamp-031.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/webkit-line-clamp-031.html)
 - [webkit-line-clamp-040.html](https://wpt.fyi/results/css/css-overflow/line-clamp/webkit-line-clamp-040.html "css/css-overflow/line-clamp/webkit-line-clamp-040.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/webkit-line-clamp-040.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/webkit-line-clamp-040.html)

 For this definition,
 [out-of-flow](https://drafts.csswg.org/css-display-4/#out-of-flow) boxes between two line boxes don't prevent them from
 being consecutive. This is the case even if the second line box is
 pushed down by
 [floats](https://drafts.csswg.org/css-page-floats-3/#float). Such out-of-flow boxes are considered to be after
 the clamp point.

 Tests

 - [line-clamp-auto-015.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-auto-015.html "css/css-overflow/line-clamp/line-clamp-auto-015.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-auto-015.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-auto-015.html)

- A point between two
 [in-flow](https://drafts.csswg.org/css-display-4/#in-flow)
 [block-level](https://drafts.csswg.org/css-display-4/#block-level) sibling boxes in the line-clamp container's [block
 formatting
 context](https://drafts.csswg.org/css-display-4/#block-formatting-context). Any
 [out-of-flow](https://drafts.csswg.org/css-display-4/#out-of-flow) boxes in between are considered to be after the clamp
 point.

 Tests

 - [line-clamp-auto-033.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-auto-033.html "css/css-overflow/line-clamp/line-clamp-auto-033.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-auto-033.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-auto-033.html)
 - [line-clamp-auto-034.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-auto-034.html "css/css-overflow/line-clamp/line-clamp-auto-034.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-auto-034.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-auto-034.html)
 - [line-clamp-auto-035.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-auto-035.html "css/css-overflow/line-clamp/line-clamp-auto-035.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-auto-035.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-auto-035.html)
 - [line-clamp-auto-036.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-auto-036.html "css/css-overflow/line-clamp/line-clamp-auto-036.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-auto-036.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-auto-036.html)
 - [line-clamp-036.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-036.html "css/css-overflow/line-clamp/line-clamp-036.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-036.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-036.html)

Tests

- [block-ellipsis-011.html](https://wpt.fyi/results/css/css-overflow/line-clamp/block-ellipsis-011.html "css/css-overflow/line-clamp/block-ellipsis-011.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/block-ellipsis-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/block-ellipsis-011.html)
- [block-ellipsis-012.html](https://wpt.fyi/results/css/css-overflow/line-clamp/block-ellipsis-012.html "css/css-overflow/line-clamp/block-ellipsis-012.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/block-ellipsis-012.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/block-ellipsis-012.html)
- [line-clamp-003.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-003.html "css/css-overflow/line-clamp/line-clamp-003.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-003.html)
- [line-clamp-auto-006.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-auto-006.html "css/css-overflow/line-clamp/line-clamp-auto-006.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-auto-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-auto-006.html)
- [line-clamp-auto-007.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-auto-007.html "css/css-overflow/line-clamp/line-clamp-auto-007.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-auto-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-auto-007.html)
- [line-clamp-auto-008.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-auto-008.html "css/css-overflow/line-clamp/line-clamp-auto-008.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-auto-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-auto-008.html)
- [line-clamp-auto-012.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-auto-012.html "css/css-overflow/line-clamp/line-clamp-auto-012.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-auto-012.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-auto-012.html)
- [line-clamp-auto-033.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-auto-033.html "css/css-overflow/line-clamp/line-clamp-auto-033.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-auto-033.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-auto-033.html)
- [webkit-line-clamp-004.html](https://wpt.fyi/results/css/css-overflow/line-clamp/webkit-line-clamp-004.html "css/css-overflow/line-clamp/webkit-line-clamp-004.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/webkit-line-clamp-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/webkit-line-clamp-004.html)
- [line-clamp-fragmentation-001.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-fragmentation-001.html "css/css-overflow/line-clamp/line-clamp-fragmentation-001.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-fragmentation-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-fragmentation-001.html)

The [max-lines](#propdef-max-lines) property determmines which of the
possible [clamp points](#clamp-point), if any, is chosen for a given line-clamp container.

Within a [line-clamp
container](#line-clamp-container), the following boxes and line boxes become [visually
suppressed](#visually-suppressed):

- Any
 [in-flow](https://drafts.csswg.org/css-display-4/#in-flow) or floating boxes that follow the [clamp
 point](#clamp-point) in the
 box tree. This includes [independent formatting
 contexts](https://drafts.csswg.org/css-display-4/#independent-formatting-context) and all of their descendants.

 Tests

 - [line-clamp-008.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-008.html "css/css-overflow/line-clamp/line-clamp-008.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-008.html)
 - [line-clamp-026.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-026.html "css/css-overflow/line-clamp/line-clamp-026.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-026.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-026.html)
 - [line-clamp-027.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-027.html "css/css-overflow/line-clamp/line-clamp-027.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-027.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-027.html)
 - [line-clamp-028.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-028.html "css/css-overflow/line-clamp/line-clamp-028.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-028.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-028.html)
 - [line-clamp-031.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-031.html "css/css-overflow/line-clamp/line-clamp-031.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-031.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-031.html)
 - [line-clamp-032.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-032.html "css/css-overflow/line-clamp/line-clamp-032.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-032.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-032.html)
 - [line-clamp-033.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-033.html "css/css-overflow/line-clamp/line-clamp-033.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-033.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-033.html)
 - [line-clamp-auto-033.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-auto-033.html "css/css-overflow/line-clamp/line-clamp-auto-033.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-auto-033.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-auto-033.html)
 - [line-clamp-auto-with-ruby-002.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-auto-with-ruby-002.html "css/css-overflow/line-clamp/line-clamp-auto-with-ruby-002.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-auto-with-ruby-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-auto-with-ruby-002.html)
 - [line-clamp-with-floats-003.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-with-floats-003.html "css/css-overflow/line-clamp/line-clamp-with-floats-003.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-with-floats-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-with-floats-003.html)
 - [line-clamp-with-floats-004.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-with-floats-004.html "css/css-overflow/line-clamp/line-clamp-with-floats-004.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-with-floats-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-with-floats-004.html)
 - [line-clamp-with-abspos-025.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-with-abspos-025.html "css/css-overflow/line-clamp/line-clamp-with-abspos-025.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-with-abspos-025.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-with-abspos-025.html)
 - [line-clamp-with-abspos-026.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-with-abspos-026.html "css/css-overflow/line-clamp/line-clamp-with-abspos-026.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-with-abspos-026.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-with-abspos-026.html)

- Any [line
 boxes](https://drafts.csswg.org/css-inline-3/#line-box) that follow the [clamp
 point](#clamp-point) inside an
 [inline formatting
 context](https://drafts.csswg.org/css-display-4/#inline-formatting-context).

 Tests

 - [line-clamp-010.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-010.html "css/css-overflow/line-clamp/line-clamp-010.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-010.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-010.html)
 - [line-clamp-012.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-012.html "css/css-overflow/line-clamp/line-clamp-012.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-012.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-012.html)
 - [line-clamp-013.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-013.html "css/css-overflow/line-clamp/line-clamp-013.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-013.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-013.html)
 - [line-clamp-026.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-026.html "css/css-overflow/line-clamp/line-clamp-026.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-026.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-026.html)
 - [line-clamp-027.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-027.html "css/css-overflow/line-clamp/line-clamp-027.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-027.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-027.html)
 - [line-clamp-028.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-028.html "css/css-overflow/line-clamp/line-clamp-028.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-028.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-028.html)
 - [webkit-line-clamp-040.html](https://wpt.fyi/results/css/css-overflow/line-clamp/webkit-line-clamp-040.html "css/css-overflow/line-clamp/webkit-line-clamp-040.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/webkit-line-clamp-040.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/webkit-line-clamp-040.html)

- Any [absolutely positioned
 box](https://drafts.csswg.org/css-position-3/#absolute-position) which has an [visually
 suppressed](#visually-suppressed) box within its [containing block
 chain](https://drafts.csswg.org/css-display-4/#containing-block-chain), and all of its descendants.

 Tests

 - [line-clamp-with-abspos-001.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-with-abspos-001.html "css/css-overflow/line-clamp/line-clamp-with-abspos-001.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-with-abspos-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-with-abspos-001.html)
 - [line-clamp-with-fixed-pos-001.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-with-fixed-pos-001.html "css/css-overflow/line-clamp/line-clamp-with-fixed-pos-001.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-with-fixed-pos-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-with-fixed-pos-001.html)
 - [line-clamp-with-abspos-002.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-with-abspos-002.html "css/css-overflow/line-clamp/line-clamp-with-abspos-002.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-with-abspos-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-with-abspos-002.html)
 - [line-clamp-with-fixed-pos-002.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-with-fixed-pos-002.html "css/css-overflow/line-clamp/line-clamp-with-fixed-pos-002.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-with-fixed-pos-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-with-fixed-pos-002.html)
 - [line-clamp-with-abspos-003.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-with-abspos-003.html "css/css-overflow/line-clamp/line-clamp-with-abspos-003.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-with-abspos-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-with-abspos-003.html)
 - [line-clamp-with-fixed-pos-003.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-with-fixed-pos-003.html "css/css-overflow/line-clamp/line-clamp-with-fixed-pos-003.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-with-fixed-pos-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-with-fixed-pos-003.html)
 - [line-clamp-with-abspos-004.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-with-abspos-004.html "css/css-overflow/line-clamp/line-clamp-with-abspos-004.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-with-abspos-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-with-abspos-004.html)
 - [line-clamp-with-fixed-pos-004.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-with-fixed-pos-004.html "css/css-overflow/line-clamp/line-clamp-with-fixed-pos-004.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-with-fixed-pos-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-with-fixed-pos-004.html)
 - [line-clamp-with-abspos-005.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-with-abspos-005.html "css/css-overflow/line-clamp/line-clamp-with-abspos-005.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-with-abspos-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-with-abspos-005.html)
 - [line-clamp-with-fixed-pos-005.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-with-fixed-pos-005.html "css/css-overflow/line-clamp/line-clamp-with-fixed-pos-005.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-with-fixed-pos-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-with-fixed-pos-005.html)
 - [line-clamp-with-abspos-006.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-with-abspos-006.html "css/css-overflow/line-clamp/line-clamp-with-abspos-006.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-with-abspos-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-with-abspos-006.html)
 - [line-clamp-with-fixed-pos-006.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-with-fixed-pos-006.html "css/css-overflow/line-clamp/line-clamp-with-fixed-pos-006.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-with-fixed-pos-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-with-fixed-pos-006.html)
 - [line-clamp-with-abspos-007.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-with-abspos-007.html "css/css-overflow/line-clamp/line-clamp-with-abspos-007.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-with-abspos-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-with-abspos-007.html)
 - [line-clamp-with-fixed-pos-007.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-with-fixed-pos-007.html "css/css-overflow/line-clamp/line-clamp-with-fixed-pos-007.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-with-fixed-pos-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-with-fixed-pos-007.html)
 - [line-clamp-with-abspos-008.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-with-abspos-008.html "css/css-overflow/line-clamp/line-clamp-with-abspos-008.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-with-abspos-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-with-abspos-008.html)
 - [line-clamp-with-fixed-pos-008.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-with-fixed-pos-008.html "css/css-overflow/line-clamp/line-clamp-with-fixed-pos-008.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-with-fixed-pos-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-with-fixed-pos-008.html)
 - [line-clamp-with-abspos-009.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-with-abspos-009.html "css/css-overflow/line-clamp/line-clamp-with-abspos-009.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-with-abspos-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-with-abspos-009.html)
 - [line-clamp-with-fixed-pos-009.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-with-fixed-pos-009.html "css/css-overflow/line-clamp/line-clamp-with-fixed-pos-009.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-with-fixed-pos-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-with-fixed-pos-009.html)
 - [line-clamp-with-abspos-010.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-with-abspos-010.html "css/css-overflow/line-clamp/line-clamp-with-abspos-010.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-with-abspos-010.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-with-abspos-010.html)
 - [line-clamp-with-fixed-pos-010.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-with-fixed-pos-010.html "css/css-overflow/line-clamp/line-clamp-with-fixed-pos-010.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-with-fixed-pos-010.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-with-fixed-pos-010.html)
 - [line-clamp-with-abspos-011.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-with-abspos-011.html "css/css-overflow/line-clamp/line-clamp-with-abspos-011.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-with-abspos-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-with-abspos-011.html)
 - [line-clamp-with-fixed-pos-011.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-with-fixed-pos-011.html "css/css-overflow/line-clamp/line-clamp-with-fixed-pos-011.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-with-fixed-pos-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-with-fixed-pos-011.html)
 - [line-clamp-with-abspos-012.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-with-abspos-012.html "css/css-overflow/line-clamp/line-clamp-with-abspos-012.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-with-abspos-012.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-with-abspos-012.html)
 - [line-clamp-with-fixed-pos-012.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-with-fixed-pos-012.html "css/css-overflow/line-clamp/line-clamp-with-fixed-pos-012.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-with-fixed-pos-012.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-with-fixed-pos-012.html)
 - [line-clamp-with-abspos-013.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-with-abspos-013.html "css/css-overflow/line-clamp/line-clamp-with-abspos-013.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-with-abspos-013.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-with-abspos-013.html)
 - [line-clamp-with-fixed-pos-013.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-with-fixed-pos-013.html "css/css-overflow/line-clamp/line-clamp-with-fixed-pos-013.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-with-fixed-pos-013.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-with-fixed-pos-013.html)
 - [line-clamp-with-abspos-014.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-with-abspos-014.html "css/css-overflow/line-clamp/line-clamp-with-abspos-014.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-with-abspos-014.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-with-abspos-014.html)
 - [line-clamp-with-fixed-pos-014.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-with-fixed-pos-014.html "css/css-overflow/line-clamp/line-clamp-with-fixed-pos-014.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-with-fixed-pos-014.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-with-fixed-pos-014.html)
 - [line-clamp-with-abspos-015.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-with-abspos-015.html "css/css-overflow/line-clamp/line-clamp-with-abspos-015.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-with-abspos-015.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-with-abspos-015.html)
 - [line-clamp-with-fixed-pos-015.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-with-fixed-pos-015.html "css/css-overflow/line-clamp/line-clamp-with-fixed-pos-015.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-with-fixed-pos-015.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-with-fixed-pos-015.html)
 - [line-clamp-with-abspos-016.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-with-abspos-016.html "css/css-overflow/line-clamp/line-clamp-with-abspos-016.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-with-abspos-016.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-with-abspos-016.html)
 - [line-clamp-with-fixed-pos-016.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-with-fixed-pos-016.html "css/css-overflow/line-clamp/line-clamp-with-fixed-pos-016.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-with-fixed-pos-016.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-with-fixed-pos-016.html)
 - [line-clamp-with-abspos-017.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-with-abspos-017.html "css/css-overflow/line-clamp/line-clamp-with-abspos-017.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-with-abspos-017.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-with-abspos-017.html)
 - [line-clamp-with-fixed-pos-017.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-with-fixed-pos-017.html "css/css-overflow/line-clamp/line-clamp-with-fixed-pos-017.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-with-fixed-pos-017.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-with-fixed-pos-017.html)
 - [line-clamp-with-abspos-020.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-with-abspos-020.html "css/css-overflow/line-clamp/line-clamp-with-abspos-020.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-with-abspos-020.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-with-abspos-020.html)
 - [line-clamp-with-abspos-021.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-with-abspos-021.html "css/css-overflow/line-clamp/line-clamp-with-abspos-021.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-with-abspos-021.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-with-abspos-021.html)
 - [line-clamp-with-abspos-022.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-with-abspos-022.html "css/css-overflow/line-clamp/line-clamp-with-abspos-022.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-with-abspos-022.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-with-abspos-022.html)
 - [line-clamp-with-abspos-023.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-with-abspos-023.html "css/css-overflow/line-clamp/line-clamp-with-abspos-023.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-with-abspos-023.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-with-abspos-023.html)
 - [line-clamp-with-abspos-024.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-with-abspos-024.html "css/css-overflow/line-clamp/line-clamp-with-abspos-024.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-with-abspos-024.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-with-abspos-024.html)
 - [line-clamp-with-abspos-025.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-with-abspos-025.html "css/css-overflow/line-clamp/line-clamp-with-abspos-025.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-with-abspos-025.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-with-abspos-025.html)
 - [line-clamp-with-abspos-026.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-with-abspos-026.html "css/css-overflow/line-clamp/line-clamp-with-abspos-026.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-with-abspos-026.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-with-abspos-026.html)
 - [webkit-line-clamp-abspos-001.html](https://wpt.fyi/results/css/css-overflow/line-clamp/webkit-line-clamp-abspos-001.html "css/css-overflow/line-clamp/webkit-line-clamp-abspos-001.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/webkit-line-clamp-abspos-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/webkit-line-clamp-abspos-001.html)
 - [line-clamp-auto-045.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-auto-045.html "css/css-overflow/line-clamp/line-clamp-auto-045.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-auto-045.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-auto-045.html)
 - [line-clamp-with-popover-001.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-with-popover-001.html "css/css-overflow/line-clamp/line-clamp-with-popover-001.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-with-popover-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-with-popover-001.html)

Within a [line-clamp
container](#line-clamp-container), floats which have not been made into [visually
suppressed](#visually-suppressed) boxes must be visually clipped to the
[unshaped](https://drafts.csswg.org/css-box-4/#unshaped-edge)
[block-end](https://drafts.csswg.org/css-writing-modes-4/#block-end) [content
edge](https://drafts.csswg.org/css-box-4/#content-edge) of the [line-clamp
container]. They do not introduce any
clearance that would make the [line-clamp
container] increase its height, and do
not contribute to the [scrollable overflow
area](https://drafts.csswg.org/css-overflow-3/#scrollable-overflow-region).

Tests

- [line-clamp-with-floats-001.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-with-floats-001.html "css/css-overflow/line-clamp/line-clamp-with-floats-001.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-with-floats-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-with-floats-001.html)
- [line-clamp-with-floats-002.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-with-floats-002.html "css/css-overflow/line-clamp/line-clamp-with-floats-002.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-with-floats-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-with-floats-002.html)
- [line-clamp-with-floats-005.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-with-floats-005.html "css/css-overflow/line-clamp/line-clamp-with-floats-005.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-with-floats-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-with-floats-005.html)
- [line-clamp-with-floats-006.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-with-floats-006.html "css/css-overflow/line-clamp/line-clamp-with-floats-006.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-with-floats-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-with-floats-006.html)
- [line-clamp-with-floats-008.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-with-floats-008.html "css/css-overflow/line-clamp/line-clamp-with-floats-008.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-with-floats-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-with-floats-008.html)
- [line-clamp-with-floats-009.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-with-floats-009.html "css/css-overflow/line-clamp/line-clamp-with-floats-009.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-with-floats-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-with-floats-009.html)
- [line-clamp-with-floats-010.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-with-floats-010.html "css/css-overflow/line-clamp/line-clamp-with-floats-010.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-with-floats-010.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-with-floats-010.html)
- [line-clamp-with-floats-011.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-with-floats-011.html "css/css-overflow/line-clamp/line-clamp-with-floats-011.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-with-floats-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-with-floats-011.html)
- [line-clamp-with-floats-012.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-with-floats-012.html "css/css-overflow/line-clamp/line-clamp-with-floats-012.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-with-floats-012.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-with-floats-012.html)
- [line-clamp-with-floats-013.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-with-floats-013.html "css/css-overflow/line-clamp/line-clamp-with-floats-013.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-with-floats-013.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-with-floats-013.html)
- [line-clamp-with-floats-014.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-with-floats-014.html "css/css-overflow/line-clamp/line-clamp-with-floats-014.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-with-floats-014.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-with-floats-014.html)

If a [block
container](https://drafts.csswg.org/css-display-4/#block-container) contains a [clamp
point](#clamp-point), within
itself or in any of its descendants, its [automatic block
size](https://drafts.csswg.org/css-sizing-3/#automatic-block-size) will not take into account any [visually
suppressed](#visually-suppressed) boxes, nor any clipped float. This also applies for the
[line-clamp
container](#line-clamp-container) itself.

Tests

- [line-clamp-004.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-004.html "css/css-overflow/line-clamp/line-clamp-004.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-004.html)
- [line-clamp-009.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-009.html "css/css-overflow/line-clamp/line-clamp-009.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-009.html)
- [line-clamp-auto-004.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-auto-004.html "css/css-overflow/line-clamp/line-clamp-auto-004.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-auto-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-auto-004.html)
- [line-clamp-auto-005.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-auto-005.html "css/css-overflow/line-clamp/line-clamp-auto-005.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-auto-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-auto-005.html)
- [line-clamp-intrinsic-size-003.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-intrinsic-size-003.html "css/css-overflow/line-clamp/line-clamp-intrinsic-size-003.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-intrinsic-size-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-intrinsic-size-003.html)
- [line-clamp-intrinsic-size-004.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-intrinsic-size-004.html "css/css-overflow/line-clamp/line-clamp-intrinsic-size-004.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-intrinsic-size-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-intrinsic-size-004.html)

The [first baseline
set](https://drafts.csswg.org/css-align-3/#first-baseline-set) and [last baseline
set](https://drafts.csswg.org/css-align-3/#last-baseline-set) of a [line-clamp
container](#line-clamp-container) is determined in the same way as for other [block
containers](https://drafts.csswg.org/css-display-4/#block-container), except that [visually
suppressed](#visually-suppressed) boxes are not taken into account.

Tests

- [line-clamp-baseline-001.html](https://wpt.fyi/results/css/css-overflow/line-clamp/line-clamp-baseline-001.html "css/css-overflow/line-clamp/line-clamp-baseline-001.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/line-clamp-baseline-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/line-clamp-baseline-001.html)

#### 5.3.2. Discarding Content

 [continue:
discard](#propdef-continue), and thus this subsection, is [at
risk](https://www.w3.org/policies/process/#at-risk): it may be removed before advancement to
[Recommendation](https://www.w3.org/policies/process/#RecsW3C) if criteria for advancement are not fulfilled.

Content that is "not rendered" due to [continue:
discard](#propdef-continue) is discarded, similar to [display:
none](https://drafts.csswg.org/css-display-4/#propdef-display):

- It is not rendered.

- It is also not made available for speech rendering.

- It does not allow user interaction.

- (#issue-0232c12f) Make sure effects on OM are well
 defined [\[Issue
 #2970\]](https://github.com/w3c/csswg-drafts/issues/2970)

- (#issue-70383456) What about
 [positioned](https://drafts.csswg.org/css-position-3/#positioned-box) elements whose static position is in the discarded
 content are not rendered? See also discussions in the [Sydney F2F
 meeting](https://lists.w3.org/Archives/Public/www-style/2018Jul/0030.html).
 [\[Issue #2971\]](https://github.com/w3c/csswg-drafts/issues/2971)

However, since intrinsic sizes are calculated across [fragmentation
containers](https://drafts.csswg.org/css-break-4/#fragmentation-container), this content *is* taken into account for the purpose
of finding the box's
[min-content](https://drafts.csswg.org/css-sizing-3/#min-content-inline-size) and
[max-content](https://drafts.csswg.org/css-sizing-3/#max-content) [inline
sizes](https://drafts.csswg.org/css-sizing-3/#inline-size) (see [CSS Fragmentation 3 § 5.1 Breaking into
Varying-size
Fragmentainers](https://drafts.csswg.org/css-break-3/#varying-size-boxes)).
[Min-content] and
[max-content] [block
sizes](https://drafts.csswg.org/css-sizing-3/#block-size) are calculated based on the content from the start of
the [fragmented
flow](https://drafts.csswg.org/css-break-4/#fragmented-flow) to the first [forced
break](https://drafts.csswg.org/css-break-4/#forced-break) if any, or to the end of the [fragmented
flow] if there is no forced break.

 This differs from the [visibility:
hidden](https://drafts.csswg.org/css-display-4/#propdef-visibility)-like behavior of content after the [clamp
point](#clamp-point) with
[continue: collapse](#propdef-continue).

 In the case of [parallel fragmentation
flows](https://www.w3.org/TR/css-break-3/#parallel-flows), content
occurring after the [fragmentation
break](https://drafts.csswg.org/css-break-4/#fragmentation-break) in the box tree could still be rendered, if it is laid
out above the position representing the end of this [fragmentation
container](https://drafts.csswg.org/css-break-4/#fragmentation-container).

Additionally, if the box is a [multi-column
container](https://drafts.csswg.org/css-multicol-2/#multi-column-container), any [overflow
columns](https://drafts.csswg.org/css-multicol-1/#overflow-columns) are also not rendered, nor is any subsequent
content---​including any [out of
flow](https://drafts.csswg.org/css-display-4/#out-of-flow) content whose static position is in or after overflow
columns, nor is any additional [multi-column
line](https://drafts.csswg.org/css-multicol-2/#multi-column-line) or [multi-column
row](https://drafts.csswg.org/css-multicol-2/#multi-column-row) that would be generated to hold such content.

Tests

- [discard-multicol-001.html](https://wpt.fyi/results/css/css-overflow/line-clamp/discard/discard-multicol-001.html "css/css-overflow/line-clamp/discard/discard-multicol-001.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/discard/discard-multicol-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/discard/discard-multicol-001.html)
- [discard-multicol-002.html](https://wpt.fyi/results/css/css-overflow/line-clamp/discard/discard-multicol-002.html "css/css-overflow/line-clamp/discard/discard-multicol-002.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/discard/discard-multicol-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/discard/discard-multicol-002.html)
- [discard-multicol-003.html](https://wpt.fyi/results/css/css-overflow/line-clamp/discard/discard-multicol-003.html "css/css-overflow/line-clamp/discard/discard-multicol-003.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/discard/discard-multicol-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/discard/discard-multicol-003.html)
- [discard-multicol-004.html](https://wpt.fyi/results/css/css-overflow/line-clamp/discard/discard-multicol-004.html "css/css-overflow/line-clamp/discard/discard-multicol-004.html")
 [[(live
 test)]](http://wpt.live/css/css-overflow/line-clamp/discard/discard-multicol-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-overflow/line-clamp/discard/discard-multicol-004.html)

In the absence of the
[continue](#propdef-continue) property, based on [CSS Multi-column Layout Module
Level 1](https://drafts.csswg.org/css-multicol/){biblio-display="inline"
}, the following markup and associated CSS would be
expected to render as follows.

``` highlight
<div class="multicol">
 <p>Column 1</p>
 <p>Column 2</p>
 <p>Column 3</p>
 <p>Overflow column
 <div class="spanner">Spanner 1</div>
 </p>
 <div class="spanner">Spanner 2</div>
 <p>Following 1</p>
 <p>Following 2</p>
 <p>Following 3</p>
 <div class="spanner">Spanner 3</div>
 <p>Following 4</p>
 <p>Following 5</p>
 <p>Following 6</p>
</div>
```

``` highlight
.multicol {
 columns: 3;
 border: solid 1px;
}
.multicol p {
 break-after: column;
 break-inside: avoid;
}
.spanner {
 column-span: all;
 text-align: center;
}
```

<figure>
<pre id="sample-rendering-overflow-multicolumn-1"
style="width: 63ch"><code>Column 1 Column 2 Column 3 Overflow column
 Spanner 1
 Spanner 2
Following 1 Following 2 Following 3
 Spanner 3
Following 4 Following 5 Following 6</code></pre>
</figure>

There is one overflow column, a spanner whose static position is within
that overflow column, another spanner whose static position is after the
overflow column, inflow content after the spanners and the overflow
column, and another spanner whose static position is in this subsequent
inflow content.

If we additionally apply the following style, everything starting from
and including the overflow column is discarded.

``` highlight
.multicol {
 continue: discard;
 block-ellipsis: ellipsis;
}
```

<figure>
<pre id="sample-rendering-overflow-multicolumn-2"><code>Column 1 Column 2 Column 3…</code></pre>
</figure>

## [ Appendix A: Possible extensions for [scrollbar-gutter]]
*This section is non-normative.*

::::: non-normative
This section documents current attempts
at extending the
[scrollbar-gutter](https://drafts.csswg.org/css-overflow-3/#propdef-scrollbar-gutter) property to solve additional use
cases. However, it does not currently have consensus. It is presented
here to encourage discussion, but non-experimental implementation is not
recommended.

This example exercises all the
additional values of the
[scrollbar-gutter](https://drafts.csswg.org/css-overflow-3/#propdef-scrollbar-gutter) property:

- [scrollbar-gutter:
 always](https://drafts.csswg.org/css-overflow-3/#propdef-scrollbar-gutter) on the scroll container

- [scrollbar-gutter:
 match-parent](https://drafts.csswg.org/css-overflow-3/#propdef-scrollbar-gutter) on each row inside the scroll container

<figure>

<figcaption>With classic scrollbars</figcaption>
</figure>

<figure>

<figcaption>With overlay scrollbars</figcaption>
</figure>

Name:

[scrollbar-gutter](https://drafts.csswg.org/css-overflow-3/#propdef-scrollbar-gutter)

[New values:](https://www.w3.org/TR/css-values/#value-defs)

auto
[\|](https://drafts.csswg.org/css-values-4/#comb-one) \[ \[ stable [\|] always \]
[&&](https://drafts.csswg.org/css-values-4/#comb-all)
both-edges[?](https://drafts.csswg.org/css-values-4/#mult-opt) \]
[\|\|](https://drafts.csswg.org/css-values-4/#comb-any) match-parent

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[all
elements](https://www.w3.org/TR/css-pseudo/#generated-content "Includes ::before and ::after pseudo-elements.")

For [overlay
scrollbars](https://drafts.csswg.org/css-overflow-3/#overlay-scrollbars), the precise width of the [scrollbar
gutter](https://drafts.csswg.org/css-overflow-3/#scrollbar-gutter), if present, is UA defined. However, it must not be 0,
and it must not change based on user interactions with the page or the
scrollbar even if the scrollbar itself changes, with the expectation
that it covers the width of the overlay scrollbar in its widest form, to
the extent that this is well defined.

The new values of this property have the following meaning:

[always]
: The [scrollbar
 gutter](https://drafts.csswg.org/css-overflow-3/#scrollbar-gutter) is always present when
 [overflow](https://drafts.csswg.org/css-overflow-3/#propdef-overflow) is
 [scroll](https://drafts.csswg.org/css-overflow-3/#valdef-overflow-scroll),
 [hidden](https://drafts.csswg.org/css-overflow-3/#valdef-overflow-hidden), or
 [auto](https://drafts.csswg.org/css-overflow-3/#valdef-overflow-auto), regardless of the type of scrollbar or of
 whether the box is overflowing.
 :::
 (#example-f3a5b27a) [scrollbar-gutter:
 always](https://drafts.csswg.org/css-overflow-3/#propdef-scrollbar-gutter) can be bused to solve the problem of
 (small) interactive elements near the edge of the element getting
 covered by an appearing overlay scrollbar. A representative case
 would be a basic todo list, with each line starting with some text
 and ending with a right-aligned checkbox. With a classic scrollbar,
 everything is fine, but an overlay scrollbar could obscure the check
 boxes and make them hard to interact with.
 ![Checkboxes adjacent to a classic
 scrollbar](images/todo-classic.png){a
 height="153" width="208"}

 ![Checkboxes and an overlay
 scrollbar](images/todo-overlay.png){a
 height="154" width="418"}

 Overlay Scrollbar are typically transient and disappear when not
 interacted with, so the checkboxes they cover are not impossible to
 use. But when the scrollbar is shown it does get in the way, and
 that makes for an awkward interaction. The author might try and
 solve the problem by adding some right padding, but (1) how much?,
 and (2) that padding isn't needed in the case of classic scrollbars.
 [scrollbar-gutter:
 always](https://drafts.csswg.org/css-overflow-3/#propdef-scrollbar-gutter) solves this problem, yielding an
 identical result in first case of classic scrollbars, but adding the
 desired gutter with overlay scrollbars:

 ![Checkboxes and an overlay scrollbar and [scrollbar-gutter:
 always](https://drafts.csswg.org/css-overflow-3/#propdef-scrollbar-gutter)](images/todo-overlay-always.png){a
 height="153" width="419"}
 :::

 :::
 (#issue-3f7416f3) Apple is reluctant to add this
 value, as authors may use it too broadly, inserting gutters with
 overlay scrollbars even when not justified by interactive elements,
 defeating the space-saving advantage of overlay scrollbars.
 An alternative solution has been suggested: as the focus is
 interactive elements, maybe we could have a property that applies to
 the elements that needs to avoid being under the scrollbar. When
 turned on, it would enlarge the right or left margin of the element
 as appropriate by just the right value to push it out from under an
 overlay scrollbar if that's where it would end up, but would leave
 the element unchanged otherwise.

 Possibly, an addition toggle would cause the element to enlarge both
 its inline-end and inline-start margins or neither, rather than just
 one. This could typically be useful for block-level descendants of
 the scroller with visible borders or background: adding space on one
 side to avoid collisions with the overlay scrollbar would make them
 look off-center when the scrollbar disappears. Increasing the margin
 on both sides avoids that.

 Yet another possibility is to have a choice between growing the
 margin to protect the element, or growing the padding to protect the
 element's content.

 The syntax could be something like
 `scrollbar-avoid: none | [self | content] && both-edges?`.

 An interesting consideration is that this may alleviate the need for
 [scrollbar-gutter:
 match-parent](https://drafts.csswg.org/css-overflow-3/#propdef-scrollbar-gutter), as it seems that situations that would
 have been addressed by [scrollbar-gutter:
 stable] or
 [scrollbar-gutter: always]
 on the parent and [scrollbar-gutter:
 match-parent] on the
 select children could instead be addressed by leaving the parent as
 [scrollbar-gutter: auto]
 and using `scrollbar-avoid: self` or `scrollbar-avoid: content` on
 the relevant children.
 :::

[match-parent]

: On a
 [block-level](https://drafts.csswg.org/css-display-4/#block-level) box whose parent has a [scrollbar
 gutter](https://drafts.csswg.org/css-overflow-3/#scrollbar-gutter) (or gutters on both edges), this causes the box to
 have [scrollbar gutter] on the same
 side(s) and of the same width as its parent's gutter(s). Moreover,
 that gutter is made to overlap that of the parent box.

 <figure>

 </figure>

 If the box with [scrollbar-gutter:
 match-parent](https://drafts.csswg.org/css-overflow-3/#propdef-scrollbar-gutter) has a non-zero border or margin on the
 side where the gutter is expected, then the size of that box's
 gutter is `parent.gutter - child.border - child.margin`, and the
 gutter+border+margin is what collapses with the parent's gutter.

 If the box with [scrollbar-gutter/ match-parent] is itself a
 [scroll
 container](https://drafts.csswg.org/css-overflow-3/#scroll-container), depending on the type of scrollbars, on its
 [overflow](https://drafts.csswg.org/css-overflow-3/#propdef-overflow) property, and on the other
 values of the
 [scrollbar-gutter](https://drafts.csswg.org/css-overflow-3/#propdef-scrollbar-gutter) property, it may need
 additional gutter for its own scrollbars. This comes in addition to
 the amount of gutter added for the sake of the
 [match-parent](#valdef-scrollbar-gutter-match-parent) value and does not collapse with the
 parent's gutter.

 :::
 (#example-08a122a1)
 <figure>

 <figcaption>A scroller with an child whose background intrudes into the
 gutter, thanks to <a href="#valdef-scrollbar-gutter-match-parent"
 id="ref-for-valdef-scrollbar-gutter-match-parent①" class="css"
 data->match-parent</a></figcaption>
 </figure>

 <figure>

 <figcaption>A <a href="#valdef-scrollbar-gutter-match-parent"
 id="ref-for-valdef-scrollbar-gutter-match-parent②" class="css"
 data->match-parent</a> box inside a scroll container
 with classic scrollbars, <a
 href="https://drafts.csswg.org/css-overflow-3/#propdef-overflow"
 id="ref-for-propdef-overflow①④" class="css"
 data->overflow: auto</a>, and <a
 href="https://drafts.csswg.org/css-overflow-3/#propdef-scrollbar-gutter"
 id="ref-for-propdef-scrollbar-gutter①⑤" class="css"
 data->scrollbar-gutter: stable</a></figcaption>
 </figure>

 <figure>

 <figcaption>A scrollable box with <a
 href="#valdef-scrollbar-gutter-match-parent"
 id="ref-for-valdef-scrollbar-gutter-match-parent③" class="css"
 data->match-parent</a> inside another scroll
 container</figcaption>
 </figure>

 <figure>

 <figcaption>A scrollable box with <a
 href="#valdef-scrollbar-gutter-match-parent"
 id="ref-for-valdef-scrollbar-gutter-match-parent④" class="css"
 data->match-parent</a> inside another scroll container,
 with bidi</figcaption>
 </figure>

 <figure>

 <figcaption>A scrollable box with <span
 class="css">scrollbar-gutter:match-parent stable</span> inside another
 scroll container, with bidi</figcaption>
 </figure>
 :::

Note: The following table summarizes the interaction of
[overflow](https://drafts.csswg.org/css-overflow-3/#propdef-overflow) and
[scrollbar-gutter](https://drafts.csswg.org/css-overflow-3/#propdef-scrollbar-gutter) for different types of scrollbars,
showing in which case space is reserved for the [scrollbar
gutter](https://drafts.csswg.org/css-overflow-3/#scrollbar-gutter).

Should space be reserved for the [scrollbar
gutter](https://drafts.csswg.org/css-overflow-3/#scrollbar-gutter)?

[overflow](https://drafts.csswg.org/css-overflow-3/#propdef-overflow)

[scrollbar-gutter](https://drafts.csswg.org/css-overflow-3/#propdef-scrollbar-gutter)

Classic scrollbars

Overlay scrollbars [(whether overflowing or not)]

Overflowing

Not overflowing

[scroll](https://drafts.csswg.org/css-overflow-3/#valdef-overflow-scroll)

[auto](https://drafts.csswg.org/css-overflow-3/#valdef-scrollbar-gutter-auto)

yes

yes

[stable](https://drafts.csswg.org/css-overflow-3/#valdef-scrollbar-gutter-stable)

yes

yes

[always](#valdef-scrollbar-gutter-always)

yes

yes

yes

[auto](https://drafts.csswg.org/css-overflow-3/#valdef-overflow-auto)

[auto](https://drafts.csswg.org/css-overflow-3/#valdef-scrollbar-gutter-auto)

yes

[stable](https://drafts.csswg.org/css-overflow-3/#valdef-scrollbar-gutter-stable)

yes

yes

[always](#valdef-scrollbar-gutter-always)

yes

yes

yes

[hidden](https://drafts.csswg.org/css-overflow-3/#valdef-overflow-hidden)

[auto](https://drafts.csswg.org/css-overflow-3/#valdef-scrollbar-gutter-auto)

[stable](https://drafts.csswg.org/css-overflow-3/#valdef-scrollbar-gutter-stable)

yes

yes

[always](#valdef-scrollbar-gutter-always)

yes

yes

yes

[visible](https://drafts.csswg.org/css-overflow-3/#valdef-overflow-visible),
[clip](https://drafts.csswg.org/css-overflow-3/#valdef-overflow-clip)

[auto](https://drafts.csswg.org/css-overflow-3/#valdef-scrollbar-gutter-auto)

[stable](https://drafts.csswg.org/css-overflow-3/#valdef-scrollbar-gutter-stable)

if
[force](https://www.w3.org/TR/css-overflow-4/#valdef-scrollbar-gutter-force)

if
[force](https://www.w3.org/TR/css-overflow-4/#valdef-scrollbar-gutter-force)

[always](#valdef-scrollbar-gutter-always)

if
[force](https://www.w3.org/TR/css-overflow-4/#valdef-scrollbar-gutter-force)

if
[force](https://www.w3.org/TR/css-overflow-4/#valdef-scrollbar-gutter-force)

if
[force](https://www.w3.org/TR/css-overflow-4/#valdef-scrollbar-gutter-force)

## [ Appendix B: Privacy Considerations](#privclass=nonum)

This specification introduces no new privacy considerations.

## [ Appendix C: Security Considerations]
This specification introduces no new security considerations.

## [ Changes]
### [ Recent Changes]
Significant changes since the [June 2017 Working
Draft](https://www.w3.org/TR/2017/WD-css-overflow-4-20170613/) include:

- Moved in the definition of
 [text-overflow](#propdef-text-overflow) from
 [\[CSS-UI-4\]](#biblio-css-ui-4 "CSS Basic User Interface Module Level 4").
- Moved the core definition of
 [scrollbar-gutter](https://drafts.csswg.org/css-overflow-3/#propdef-scrollbar-gutter) to
 [\[CSS-OVERFLOW-3\]](#biblio-css-overflow-3 "CSS Overflow Module Level 3")
 (it will be copied back here once this specification is undiffed) and
 shift exploratory
 [scrollbar-gutter]
 extension ideas into an appendix.
- Defined extension of
 [overflow](https://drafts.csswg.org/css-overflow-3/#propdef-overflow) and
 [overflow-clip-margin](#propdef-overflow-clip-margin) to apply to [replaced
 elements](https://drafts.csswg.org/css-display-4/#replaced-element). How exactly this works is still [still under
 discussion](https://github.com/w3c/csswg-drafts/issues/7144). ([Issue
 7144](https://github.com/w3c/csswg-drafts/issues/7144))
- Defined
 [longhands](https://drafts.csswg.org/css-cascade-5/#longhand) for
 [overflow-clip-margin](#propdef-overflow-clip-margin). ([Issue
 7245](https://github.com/w3c/csswg-drafts/issues/7245))
- Change the
 [line-clamp](#propdef-line-clamp) shorthand syntax to allow omitting the
 [max-lines](#propdef-max-lines) value ([Issue
 9368](https://github.com/w3c/csswg-drafts/issues/9368))
- Dropped the tentative `force` value for the
 [scrollbar-gutter](https://drafts.csswg.org/css-overflow-3/#propdef-scrollbar-gutter) property. ([Issue
 9815](https://github.com/w3c/csswg-drafts/issues/9815))
- Establish an Independent Formatting Context when [continue:
 discard](#propdef-continue) is used. ([Issue
 10323](https://github.com/w3c/csswg-drafts/issues/10323))
- Blockify elements with `(-webkit-)line-clamp`,
 `display: -webkit-(inline-)box` and `-webkit-box-orient: vertical`.
 ([Issue 10324](https://github.com/w3c/csswg-drafts/issues/10324))

### [ Changes Since Level 3]
TBD

## [ Acknowledgments]
Thanks especially to the feedback from Rossen Atanassov, Bert Bos,
Andreu Botella, Tantek Çelik, John Daggett, fantasai, Daniel Glazman,
Vincent Hardy, Håkon Wium Lie, Peter Linss, Robert O'Callahan, Florian
Rivoal, Alan Stearns, Steve Zilles, and all the rest of the
[www-style](http://lists.w3.org/Archives/Public/www-style/) community.
