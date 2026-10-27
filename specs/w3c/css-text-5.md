## 1. Introduction

This module describes the typesetting controls of CSS; that is, the
features of CSS that control the translation of source text to
formatted, line-wrapped text.

This specification describes features introduced in Level 5; it is a
diff against
[\[css-text-4\]](#biblio-css-text-4 "CSS Text Module Level 4").

### 1.1. Text fitting: the [text-fit property]
Tests

This section has no coverage yet.

------------------------------------------------------------------------

Name:

[text-fit]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

\[ none
[\|](https://drafts.csswg.org/css-values-4/#comb-one) grow [\|] shrink \]
\[consistent [\|] per-line [\|]
per-line-all\][?](https://drafts.csswg.org/css-values-4/#mult-opt)
[\<percentage\>](https://drafts.csswg.org/css-values-4/#percentage-value)[?]

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

none

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[block
containers](https://drafts.csswg.org/css-display-4/#block-container)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

yes

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

N/A

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

specified keywords or computed
[\<percentage\>](https://drafts.csswg.org/css-values-4/#percentage-value) value

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

The [text-fit](#propdef-text-fit) property describes how
[inline-level](https://drafts.csswg.org/css-display-4/#inline-level) contents are scaled if they do not fit to the [line
box](https://drafts.csswg.org/css-inline-3/#line-box).

Values have the following meanings:

[none]
: The user agent doesn't scale
 [inline-level](https://drafts.csswg.org/css-display-4/#inline-level) contents to fit to the [line
 box](https://drafts.csswg.org/css-inline-3/#line-box).

[grow]
: The user agent scales up
 [inline-level](https://drafts.csswg.org/css-display-4/#inline-level) contents to fit to the [line
 box](https://drafts.csswg.org/css-inline-3/#line-box).

[shrink]
: The user agent scales down
 [inline-level](https://drafts.csswg.org/css-display-4/#inline-level) contents to fit to the [line
 box](https://drafts.csswg.org/css-inline-3/#line-box).

[consistent]
: Specifies that all lines in the container are scaled with a single
 scaling factor. This keyword has no effect if
 [none](#valdef-text-fit-none) is specified. If none of
 [consistent](#valdef-text-fit-consistent),
 [per-line](#valdef-text-fit-per-line), or
 [per-line-all](#valdef-text-fit-per-line-all) are specified,
 [consistent] is assumed.

[per-line]
: Specifies that each line is scaled with its own scaling factor.
 However, the last line of the block and lines that end in a forced
 break are not scaled. This keyword has no effect if
 [none](#valdef-text-fit-none) is specified.

[per-line-all]
: Specifies that each line is scaled with its own scaling factor,
 including the last line of the block and lines that end in a forced
 break. This keyword has no effect if
 [none](#valdef-text-fit-none) is specified.

[\<percentage\>]
: Specifies the limit of the scaling factor. If
 [grow](#valdef-text-fit-grow) is specified and the value is 100% or greater, it
 is the maximum scaling factor. If
 [shrink](#valdef-text-fit-shrink) is specified and the value is between 0% and
 100% inclusive, it is the minimum scaling factor. Otherwise, or if
 this component is omitted, there is no limit on the scaling factor.

This property provides a functionality to make
[inline-level](https://drafts.csswg.org/css-display-4/#inline-level) contents exactly fill the inline size of the [line
box](https://drafts.csswg.org/css-inline-3/#line-box). Unlike
[justify](https://drafts.csswg.org/css-text-4/#valdef-text-align-justify) of the
[text-align](https://drafts.csswg.org/css-text-3/#propdef-text-align) property, which achieves this by
adjusting spacing between characters, this property scales the font
size.

When [grow](#valdef-text-fit-grow) or
[shrink](#valdef-text-fit-shrink) is specified, a [line scaling
factor](#line-scaling-factor) is computed for each [line
box](https://drafts.csswg.org/css-inline-3/#line-box). If
[consistent](#valdef-text-fit-consistent) applies, all [line boxes]
are scaled by the smallest computed [line scaling
factor]. Otherwise, each [line
box] is scaled by its own [line scaling
factor].

This property does not affect the
[font-size](https://drafts.csswg.org/css-fonts-4/#propdef-font-size) [computed
value](https://drafts.csswg.org/css-cascade-5/#computed-value), and thus does not affect font-size-relative
[\<length\>](https://drafts.csswg.org/css-values-4/#length-value) values of other properties. For
example, \"line-height: 1.5em\" and \"letter-spacing: 0.1em\" are not
affected by this scaling.

The [used
value](https://drafts.csswg.org/css-cascade-5/#used-value) of the text
[font-size](https://drafts.csswg.org/css-fonts-4/#propdef-font-size) is its [computed
value](https://drafts.csswg.org/css-cascade-5/#computed-value) multiplied by the [line scaling
factor](#line-scaling-factor).

Scaling can change the [block
size](https://drafts.csswg.org/css-sizing-3/#block-size) of a [line
box](https://drafts.csswg.org/css-inline-3/#line-box), which can in turn change its position along the
[block-axis](https://drafts.csswg.org/css-writing-modes-4/#block-axis). If any feature is active that would cause the [inline
size](https://drafts.csswg.org/css-sizing-3/#inline-size) of the [line box] to change based
on its [block-axis] position (such as
[float](https://drafts.csswg.org/css2/#propdef-float) or
[initial-letter](https://drafts.csswg.org/css-inline-3/#propdef-initial-letter)), scaling is disabled for the
block.

If the [inline
size](https://drafts.csswg.org/css-sizing-3/#inline-size) of a block container depends on the size of the
viewport, its apparent [inline size] may not
change even if the user changes the page zoom level. In that case, if
text is fitted with this feature, the text size may not change at all
even though the zoom level has changed. There is no agreement yet on how
to deal with this issue. See
[csswg#12886](https://github.com/w3c/csswg-drafts/issues/12886).

#### 1.1.1. Computing line scaling factor

The parts of the [line
box](https://drafts.csswg.org/css-inline-3/#line-box)'s contents that can be scaled by this property are
called [scalable parts]. These include:

- Text, including text in [inline
 boxes](https://drafts.csswg.org/css-display-4/#inline-box), but excluding trailing white space.
- Spacing whose [inline
 size](https://drafts.csswg.org/css-sizing-3/#inline-size) is proportional to the
 [font-size](https://drafts.csswg.org/css-fonts-4/#propdef-font-size) used value. E.g. percentage-based
 [letter-spacing](https://drafts.csswg.org/css-text-4/#propdef-letter-spacing) or
 [word-spacing](https://drafts.csswg.org/css-text-4/#propdef-word-spacing), and
 [text-autospace](https://drafts.csswg.org/css-text-4/#propdef-text-autospace).

[text-indent](https://drafts.csswg.org/css-text-4/#propdef-text-indent),
[line-padding](https://drafts.csswg.org/css-text-4/#propdef-line-padding), non-percentage-based
[letter-spacing](https://drafts.csswg.org/css-text-4/#propdef-letter-spacing) and
[word-spacing](https://drafts.csswg.org/css-text-4/#propdef-word-spacing), and [atomic
inlines](https://drafts.csswg.org/css-display-4/#atomic-inline) are not [scalable
parts](#scalable-parts). The
[inline-axis](https://drafts.csswg.org/css-writing-modes-4/#inline-axis)
[padding](https://drafts.csswg.org/css-box-4/#propdef-padding),
[border](https://drafts.csswg.org/css-backgrounds-3/#propdef-border), and
[margin](https://drafts.csswg.org/css-box-4/#propdef-margin) of inline boxes are also not
[scalable parts].

A [line scaling factor] is the ratio by which the [scalable
parts](#scalable-parts) of a
line must be scaled in order to make its
[inline-level](https://drafts.csswg.org/css-display-4/#inline-level) content exactly fit the [line
box](https://drafts.csswg.org/css-inline-3/#line-box)'s [inline
size](https://drafts.csswg.org/css-sizing-3/#inline-size).

A [line scaling
factor](#line-scaling-factor) is computed from:

- The total [inline
 size](https://drafts.csswg.org/css-sizing-3/#inline-size) of the [scalable
 parts](#scalable-parts) in
 the line.
- The remaining space in the [line
 box](https://drafts.csswg.org/css-inline-3/#line-box), including any trailing whitespace (which may be
 negative if the content overflows the [line
 box]).

If a
[\<percentage\>](https://drafts.csswg.org/css-values-4/#percentage-value) is specified, it clamps the [line
scaling factor](#line-scaling-factor).

A simple calculation for the [line scaling
factor](#line-scaling-factor) would be `(A + B) / A`, where A is the total [inline
size](https://drafts.csswg.org/css-sizing-3/#inline-size) of [scalable
parts](#scalable-parts) and B
is the remaining space. However, due to [optical
sizing](https://drafts.csswg.org/css-fonts-4/#font-optical-sizing-def),
the [inline size] of text might not be perfectly
proportional to its
[font-size](https://drafts.csswg.org/css-fonts-4/#propdef-font-size). The exact method for determining a
reasonable [line scaling factor] is up to
the implementation.

The [line scaling
factor](#line-scaling-factor) for a [line
box](https://drafts.csswg.org/css-inline-3/#line-box) with no [scalable
parts](#scalable-parts) is 1.

## [ Appendix A: Text Processing Order of Operations]
- [text fitting](#text-fit-property) is applied after text wrapping and
 before text justification.

 - [font/glyph selection and
 positioning](https://www.w3.org/TR/css-fonts-3/)
 [\[CSS-FONTS-3\]](#biblio-css-fonts-3 "CSS Fonts Module Level 3")
 may be done again

 - [letter-spacing](https://drafts.csswg.org/css-text-4/#propdef-letter-spacing),
 [word-spacing](https://drafts.csswg.org/css-text-4/#propdef-word-spacing), and
 [text-spacing](https://drafts.csswg.org/css-text-4/#propdef-text-spacing) may be updated.

## [ Acknowledgements]
Tests

Tests not needed for this section.

------------------------------------------------------------------------

The [text-fit](#propdef-text-fit) property would not be here without the
efforts of Kent Tamura and Roman Komarov.

## [ Changes]
### [ Additions Since Level 4]
New features in Level 5:

- Added the [text-fit](#propdef-text-fit) property.
