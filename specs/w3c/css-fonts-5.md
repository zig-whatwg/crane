## 1. Introduction

The CSS Fonts Level 4 specification
([\[CSS-FONTS-4\]](#biblio-css-fonts-4 "CSS Fonts Module Level 4"))
describes the controls CSS provides for selecting and using fonts within
documents, including support for variable fonts and color fonts. The
ideas here are additions or modifications to the properties and rules
defined in CSS Fonts Level 4.

This specification is currently a delta to the CSS Fonts Level 4
specification. Do not assume that if something is not here, it has been
dropped.

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

## [2. ][ Text-Scale [`meta`](https://html.spec.whatwg.org/multipage/semantics.html#meta) element]
User agents must calculate the computed value of
[medium](https://drafts.csswg.org/css2/#valdef-font-size-medium) by multiplying 16px by the [text scale
factor]. User agents must also apply this factor when determining
the computed sizes of the other
[\<absolute-size\>](https://drafts.csswg.org/css-fonts-4/#typedef-absolute-size) keywords. However, user agents should
scale these other keywords non-linearly to preserve readability.

 Applying a linear scale to all keywords would render
large fonts excessively large. See the [WCAG discussion on minimum and
maximum critical font
sizes](https://github.com/w3c/wcag3/issues/261#issuecomment-2598860630).

A document with a
[`meta`](https://html.spec.whatwg.org/multipage/semantics.html#meta) tag whose
[`name`](https://html.spec.whatwg.org/multipage/semantics.html#attr-meta-name) attribute is an [ASCII
case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive) match for [`"text-scale"`] is recognized as
controlling the [text scale
factor](#text-scale-factor).

The value of the
[`content`](https://html.spec.whatwg.org/multipage/semantics.html#attr-meta-content) attribute must be an [ASCII
case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive) match for one of the recognized keywords. Otherwise the
tag is ignored.

Documents without this
[`meta`](https://html.spec.whatwg.org/multipage/semantics.html#meta) tag will have an assumed default value of
[legacy](#text-scale-legacy).

```
<meta name="text-scale" content="scale" />
```

There must not be more than one
[`meta`](https://html.spec.whatwg.org/multipage/semantics.html#meta) element with its
[`name`](https://html.spec.whatwg.org/multipage/semantics.html#attr-meta-name) attribute value set to an [ASCII
case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive) match for [text-scale](#text-scale) per document.

### 2.1. Keywords

The recognized keywords in the
[text-scale](#text-scale)
[`meta`](https://html.spec.whatwg.org/multipage/semantics.html#meta) element are:

[legacy]

: The
 [preferred-text-scale](https://drafts.csswg.org/css-env-1/#valdef-env-preferred-text-scale) environment variable returns the user's
 OS-level font factor on mobile devices, but 1 on desktop devices.
 [text scale factor](#text-scale-factor) incorporates UA-level font preferences but OS-level
 font preferences are ignored.

 Equivalent to omitting a
 [text-scale](#text-scale)
 [`meta`](https://html.spec.whatwg.org/multipage/semantics.html#meta) tag or including an unrecognized content
 attribute keyword.

[scale]
: The
 [preferred-text-scale](https://drafts.csswg.org/css-env-1/#valdef-env-preferred-text-scale) environment variable returns the user's
 OS-level font preferences. [text scale
 factor](#text-scale-factor) incorporates both UA-level and OS-level font
 preferences.

### 2.2. The [legacy keyword]
When the value of the [text-scale](#text-scale) content attribute is
[legacy](#text-scale-legacy), the [text scale
factor](#text-scale-factor)
is the font scale factor the user has chosen from any settings provided
*only* by the user agent. The
[preferred-text-scale](https://drafts.csswg.org/css-env-1/#valdef-env-preferred-text-scale) environment variable value must be 1 on desktop
platforms.

On mobile platforms:

- If the operating system provides a text scale setting AND the UA
 hasn't already applied that factor to the
 [medium](https://drafts.csswg.org/css2/#valdef-font-size-medium) font size, the
 [preferred-text-scale](https://drafts.csswg.org/css-env-1/#valdef-env-preferred-text-scale) environment variable returns the multiplier
 that the user has chosen in the operating system's text scale setting.

 At the time of publishing, all combinations of
 Android, iOS, Firefox, Safari, and Chrome satisfy this first
 condition.

- Otherwise the
 [preferred-text-scale](https://drafts.csswg.org/css-env-1/#valdef-env-preferred-text-scale) environment variable returns 1.

### [2.3. ][The [scale](https://drafts.csswg.org/css-transforms-2/#propdef-scale) keyword]
When the value of the [text-scale](#text-scale) content attribute is
[scale](#text-scale-scale),
the [text scale factor](#text-scale-factor) matches the user's preferred paragraph text size (as
determined from a combination of OS and UA preferences) divided by 16px.

The
[preferred-text-scale](https://drafts.csswg.org/css-env-1/#valdef-env-preferred-text-scale) environment variable must return the [text scale
factor](#text-scale-factor).

Further, when the value of the
[text-scale](#text-scale) content
attribute is [scale](#text-scale-scale), the user agent should skip all font-sizing
interventions it would otherwise perform in an attempt to automatically
honor the user's preferences. E.g. text autosizing on mobile (See [CSS
Size Adjustment 1 § 1
Introduction](https://drafts.csswg.org/css-size-adjust-1/#intro)) and
full-application zoom ([popular browsers do this on
Windows)](https://github.com/w3c/csswg-drafts/blob/main/css-env-1/explainers/env-preferred-text-scale.md#windows-11).

 Authors are expected to use
`<meta name="text-scale" content="scale">` in stylesheets so
that the
[medium](https://drafts.csswg.org/css2/#valdef-font-size-medium) font size will reflect the user's font
preferences, whether those are specified at the OS level or the UA
level. The author will then be able to use
[rem](https://drafts.csswg.org/css-values-4/#rem) and
[em](https://drafts.csswg.org/css-values-4/#em) throughout the page to honor the user's font
preferences. Authors must only use this if they have tested their
website with scaled text. This requires care to do correctly, given the
very large font sizes some low-vision users need. Consider the extreme
case of an iPhone Mini set to iOS's largest font size of 53px. Only
\~12-15 characters fit on a line.

Assuming a page hasn't altered the
[:root](https://drafts.csswg.org/selectors-4/#root-pseudo) font size with an absolute length unit like
[px](https://drafts.csswg.org/css-values-4/#px), content sized with
[rem](https://drafts.csswg.org/css-values-4/#rem) units will be relative to the preferred text scale

```
<!DOCTYPE html>
<html> <!-- leave this element's font-size as the default -->
 <head>
 <meta name="text-scale" content="scale" />
 </head>
 <body>
 <div style="font-size: 1rem;">
 This font size obeys the user's font preferences, **whether
 those preferences are specified at the operating system level
 or the user agent level**
 </div>
 <div style="font-size: 20px;">
 This font size does NOT respect the user's font preferences.
 <div style="font-size: 1rem;">
 But this font size does!
 </div>
 </div>
 </body>
</html>
```

If an element such as a heading already
has large text, it is likely already large enough for a user who needs a
high text scale to read. If the large text scales at the same rate as
the body text, it could become too large to comfortably fit in the
user's viewport.

Therefore, authors should consider using a dampening formula to reduce
the rate that large text scales. There are various mathematical
approaches to achieve this; one possible formula is demonstrated below.

```
<meta name="viewport" content="width=device-width">
<meta name="text-scale" content="scale">
<style>
h1 {
 /*
 Multiply the 2em baseline by a dampening factor to ensure headers
 scale up slower than the body text, preventing them from becoming
 too large.

 The two values in the calc() (0.5 and 0.5) must sum to 1.0, so the
 multiplier evaluates to exactly 1 at a 1x text scale. As the user
 increases their text scale, the multiplier shrinks towards the first
 number (0.5). Because the shrinking multiplier is applied to a
 growing font size, the header continues to grow, but its growth
 rate is dampened.

 Here are the resulting font sizes at various text scale factors:
 h1 body
 ---- ----
 1x 32px 16px
 1.5x 40px 24px
 2x 48px 32px
 3x 64px 48px
 3.5x 72px 56px
 */
 --dampen-factor: calc(0.5 + (0.5 / env(preferred-text-scale)));
 font-size: calc(2rem * var(--dampen-factor));
}

</style>
<h1>Header</h1>
This is some body text. The header grows slower than the body text.
```

![Visual example of scaling headers vs body
text](images/text-scale-example.png){height="740" width="1238"}

An extreme version of the above, some text
content that starts larger than body text can and should become smaller
than body text as the user's font size increases. In this floating
button example, the button text is larger than the body text at 1x but
gets smaller at \~2.5x font scale.

```
<meta name="text-scale" content="scale" />
<style>
.floating-action-button {
 position: fixed;
 top: 30px;
 right: 30px;
 /*
 Grow slower than the h1 example. The two numbers must still add up
 to 1.0, but using a smaller first number (0.4 instead of 0.5)
 makes the text scale up at a slower rate.
 */
 --dampen-factor: calc(0.4 + (0.6 / env(preferred-text-scale)));
 font-size: calc(1.5rem * var(--dampen-factor));
 /* Resulting font sizes at various text scale factors:
 button body
 ------ ----
 1x 24px 16px
 1.5x 28.8px 24px
 2x 33.6px 32px
 3x 43.2px 48px <-- body passes button: inversion! */
}
</style>
<button class="floating-action-button">➕Add</button>
```

## 3. Basic Font Properties

[w3c/csswg-drafts/126](https://github.com/w3c/csswg-drafts/issues/126)[\[css-fonts\] Specifying changes to
parameters for fallback
fonts](https://github.com/w3c/csswg-drafts/issues/126)

### [3.1. ][ Font family: the [font-family](https://drafts.csswg.org/css-fonts-4/#propdef-font-family) property]
#### 3.1.1. Generic font families

In addition to the [CSS Fonts 4 § 2.1.5 Generic font
families](https://drafts.csswg.org/css-fonts-4/#generic-font-families)
in CSS Fonts Level 4, the following new generic font families are also
defined.

(#issue-d41d8cd9①)[w3c/csswg-drafts/4910](https://github.com/w3c/csswg-drafts/issues/4910)[\[meta\] \[css-fonts\] Criteria for generic
font families](https://github.com/w3c/csswg-drafts/issues/4910)

[xxx]
: Placeholder text for the xxx generic font family.

(#issue-d41d8cd9②)[w3c/csswg-drafts/4566](https://github.com/w3c/csswg-drafts/issues/4566)[\[css-fonts\] Should we start a registry
for additional generic
fonts?](https://github.com/w3c/csswg-drafts/issues/4566)

### [3.2. ][Font weight: the [font-weight](https://drafts.csswg.org/css-fonts-4/#propdef-font-weight) property]
(#issue-d41d8cd9③)[w3c/csswg-drafts/2690](https://github.com/w3c/csswg-drafts/issues/2690)[\[css-fonts-4\] Percentages in font-weight
for relative weights](https://github.com/w3c/csswg-drafts/issues/2690)

### [3.3. ][ Font style: the [font-style](https://drafts.csswg.org/css-fonts-4/#propdef-font-style) property]
(#issue-d41d8cd9④)[w3c/csswg-drafts/4044](https://github.com/w3c/csswg-drafts/issues/4044)[\[css-fonts\] Vertical text doesn\'t play
nicely with font-style and
font-stretch](https://github.com/w3c/csswg-drafts/issues/4044)

### 3.4. Relative sizing: the [font-size-adjust property]
Name:

[font-size-adjust]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

none
[\|](https://drafts.csswg.org/css-values-4/#comb-one) \[ ex-height [\|] cap-height
[\|] ch-width [\|] ic-width
[\|] ic-height
\][?](https://drafts.csswg.org/css-values-4/#mult-opt) \[ from-font [\|] [\<number
\[0,∞\]\>](https://drafts.csswg.org/css-values-4/#number-value) \]

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

none

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

all elements and text

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

yes

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

N/A

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

the keyword
[none](#valdef-font-size-adjust-none), or a pair of a metric keyword and a
[\<number\>](https://drafts.csswg.org/css-values-4/#number-value)

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete if the keywords differ, otherwise by computed value type

For any given font size, the apparent size and effective legibility of
text varies across fonts as a function of their design. For example, for
bicameral scripts such as Latin or Cyrillic that distinguish between
upper and lowercase letters, the relative height of lowercase letters
compared to their uppercase counterparts is a determining factor of
legibility. In situations where font fallback occurs, fallback fonts
might not share the same ratios as the desired font family for key
typographic metrics, and will thus appear to be a different size and
possibly be less readable.

Tests

- [font-size-adjust-ic-height.html](https://wpt.fyi/results/css/css-fonts/font-size-adjust-ic-height.html "css/css-fonts/font-size-adjust-ic-height.html")
 [[(live
 test)]](http://wpt.live/css/css-fonts/font-size-adjust-ic-height.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-fonts/font-size-adjust-ic-height.html)

(#issue-d41d8cd9⑤)[w3c/csswg-drafts/8792](https://github.com/w3c/csswg-drafts/issues/8792)[\[css-fonts-5\] font-size-adjust:
ic-height](https://github.com/w3c/csswg-drafts/issues/8792)

[font-size-adjust](#propdef-font-size-adjust) property provides a way to preserve
the readability and apparent size of text when font fallback occurs. It
does this by adjusting the used font size so that the specified metric
is the same regardless of the font used.

Values have the following meanings:

[none]
: No special
 [font-size](https://drafts.csswg.org/css-fonts-4/#propdef-font-size) adjustment is applied.

[ex-height \| cap-height \| ch-width \| ic-width \| ic-height]
: Specifies the font metric to normalize, defaulting to
 [ex-height](#valdef-font-size-adjust-ex-height):

 [ex-height]
 : Normalize the [aspect value] of the fonts, using the x-height divided by the
 font size.

 [cap-height]
 : Normalize the cap-height of the fonts, using the cap-height by
 the font size.

 [ch-width]
 : Normalize the horizontal narrow pitch of the fonts, using the
 advance width of "0" (ZERO, U+0030) divided by the font size.

 [ic-width]
 : Normalize the horizontal wide pitch of the font, using the
 advance width of "水" (CJK water ideograph, U+6C34) divided by
 the font size.

 [ic-height]
 : Normalize the vertical wide pitch of the font, using the advance
 height of "水" (CJK water ideograph, U+6C34) divided by the font
 size.

 :::
 (#issue-c72cd359)[w3c/csswg-drafts/6384](https://github.com/w3c/csswg-drafts/issues/6384)[\[css-fonts-5\] font-size-adjust with
 missing metrics](https://github.com/w3c/csswg-drafts/issues/6384)
 :::

[[\<number \[0,∞\]\>](https://drafts.csswg.org/css-values-4/#number-value)]

: Each font's
 [used](https://drafts.csswg.org/css-cascade-5/#used-value) size is normalized to match the chosen font metric
 to this specified proportion of the
 [computed](https://drafts.csswg.org/css-cascade-5/#computed-value)
 [font-size](https://drafts.csswg.org/css-fonts-4/#propdef-font-size). In other words, for each
 glyph, the adjusted font size to use `u` is calculated
 as:

 ``` highlight
 u = ( m / m′ ) s
 ```

 where:

 ``` highlight
 s = computed 'font-size!!property' value
 m = metric as specified by the 'font-size-adjust' property
 m′ = metric as specified in the actual font
 u = adjusted font-size to use
 ```

 Negative values are invalid.

[from-font]
: Computes to the
 [\<number\>](https://drafts.csswg.org/css-values-4/#number-value) corresponding to the specified
 metric of the [first available
 font](https://drafts.csswg.org/css-fonts-4/#first-available-font), if it exists. Otherwise, the same as
 [none](#valdef-font-size-adjust-none).

Tests

- [font-size-adjust-composition.html](https://wpt.fyi/results/css/css-fonts/animations/font-size-adjust-composition.html "css/css-fonts/animations/font-size-adjust-composition.html")
 [[(live
 test)]](http://wpt.live/css/css-fonts/animations/font-size-adjust-composition.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-fonts/animations/font-size-adjust-composition.html)
- [font-size-adjust-interpolation.html](https://wpt.fyi/results/css/css-fonts/animations/font-size-adjust-interpolation.html "css/css-fonts/animations/font-size-adjust-interpolation.html")
 [[(live
 test)]](http://wpt.live/css/css-fonts/animations/font-size-adjust-interpolation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-fonts/animations/font-size-adjust-interpolation.html)
- [font-size-adjust-013.html](https://wpt.fyi/results/css/css-fonts/font-size-adjust-013.html "css/css-fonts/font-size-adjust-013.html")
 [[(live
 test)]](http://wpt.live/css/css-fonts/font-size-adjust-013.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-fonts/font-size-adjust-013.html)
- [font-size-adjust-014.html](https://wpt.fyi/results/css/css-fonts/font-size-adjust-014.html "css/css-fonts/font-size-adjust-014.html")
 [[(live
 test)]](http://wpt.live/css/css-fonts/font-size-adjust-014.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-fonts/font-size-adjust-014.html)
- [font-size-adjust-metrics-override.html](https://wpt.fyi/results/css/css-fonts/font-size-adjust-metrics-override.html "css/css-fonts/font-size-adjust-metrics-override.html")
 [[(live
 test)]](http://wpt.live/css/css-fonts/font-size-adjust-metrics-override.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-fonts/font-size-adjust-metrics-override.html)
- [font-size-adjust-text-orientation.html](https://wpt.fyi/results/css/css-fonts/font-size-adjust-text-orientation.html "css/css-fonts/font-size-adjust-text-orientation.html")
 [[(live
 test)]](http://wpt.live/css/css-fonts/font-size-adjust-text-orientation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-fonts/font-size-adjust-text-orientation.html)
- [font-size-adjust-units-001.html](https://wpt.fyi/results/css/css-fonts/font-size-adjust-units-001.html "css/css-fonts/font-size-adjust-units-001.html")
 [[(live
 test)]](http://wpt.live/css/css-fonts/font-size-adjust-units-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-fonts/font-size-adjust-units-001.html)
- [font-size-adjust-computed.html](https://wpt.fyi/results/css/css-fonts/parsing/font-size-adjust-computed.html "css/css-fonts/parsing/font-size-adjust-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-fonts/parsing/font-size-adjust-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-fonts/parsing/font-size-adjust-computed.html)
- [font-size-adjust-invalid.html](https://wpt.fyi/results/css/css-fonts/parsing/font-size-adjust-invalid.html "css/css-fonts/parsing/font-size-adjust-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-fonts/parsing/font-size-adjust-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-fonts/parsing/font-size-adjust-invalid.html)
- [font-size-adjust-valid.html](https://wpt.fyi/results/css/css-fonts/parsing/font-size-adjust-valid.html "css/css-fonts/parsing/font-size-adjust-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-fonts/parsing/font-size-adjust-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-fonts/parsing/font-size-adjust-valid.html)

The style defined below defines
Verdana as the desired font family, but if Verdana is not available
Futura or Times will be used. One paragraph also has font-size-adjust
specified.

``` highlight
p {
 font-family: Verdana, Futura, Times;
}
p.adj {
 font-size-adjust: 0.545;
}

<p>Lorem ipsum dolor sit amet, ...</p>
<p class="adj">Lorem ipsum dolor sit amet, ...</p>
```

Verdana has a relatively high aspect value of 0.545, meaning lowercase
letters are relatively tall compared to uppercase letters, so at small
sizes text appears legible. Times has a lower aspect value of 0.447, and
so if fallback occurs, the text will be less legible at small sizes than
Verdana unless font-size-adjust is also specified.

 For text which uses diacritics, too large an x-height
will actually decrease legibility as the diacritics become cramped.

How text rendered in each of these fonts compares is shown below, the
columns show text rendered in Verdana, Futura and Times. The same
font-size value is used across cells within each row and red lines are
included to show the differences in x-height. In the upper half, each
row is rendered in the same font-size value. The same is true for the
lower half, but in this half the
[font-size-adjust](#propdef-font-size-adjust) property is also set to 0.545, so
that the actual font size is adjusted to preserve the x-height of
Verdana across each row. Note how small text remains relatively legible
across each row in the lower half.

![Text with and without the use of
[font-size-adjust](#propdef-font-size-adjust)](images/fontsizeadjust.png){height="667"
width="544"}

The value of
[font-size-adjust](#propdef-font-size-adjust) affects the
[used](https://drafts.csswg.org/css-cascade-5/#used-value) value of
[font-size](https://drafts.csswg.org/css-fonts-4/#propdef-font-size) but does not affect the
[computed](https://drafts.csswg.org/css-cascade-5/#computed-value) value. Therefore it can affect the size of relative
units that are based on font metrics such as `ex` and
`ch` but does not affect the size of `em` units.
Since numeric values of
[line-height](https://drafts.csswg.org/css2/#propdef-line-height) refer to the
[computed] size of
[font-size],
[font-size-adjust] also
does not affect the [used] value of
[line-height].

 Since
[font-size-adjust](#propdef-font-size-adjust) does not factor into the
[line-height](https://drafts.csswg.org/css2/#propdef-line-height), specifying a line height too
tightly can result in overlapping lines of text. For example, when a
fallback font with a low [aspect
value](#font-size-adjust-aspect-value) is normalized to match one with a high [aspect
value], its ascenders and
descenders are likely to extend outside the line box with [line-height:
1].

The
[font-size-adjust](#propdef-font-size-adjust) adjustment applies to any font that
is selected but in typical usage it would be based on the corresponding
metric value of the first (most desired) font in the
[font-family](https://drafts.csswg.org/css-fonts-4/#propdef-font-family) list. If this is specified
accurately, the
`(``m``/``m′``)`
term in the adjustment formula will resolve to `1` for the
first font and no adjustment occurs for that font; and the rest of the
fonts will resolve to match. If the value is specified inaccurately,
text rendered using the first font in the family list will display
differently in older user agents that don't support
[font-size-adjust].

Authors can calculate the [aspect
value](#font-size-adjust-aspect-value) for a given font by comparing spans with the same
content but different
[font-size-adjust](#propdef-font-size-adjust) properties. If the same font-size
is used, the spans will match when the
[font-size-adjust] value
is accurate for the given font.

Two spans with borders are used to determine the [aspect
value](#font-size-adjust-aspect-value) of a font. The
[font-size](https://drafts.csswg.org/css-fonts-4/#propdef-font-size) is the same for both spans but the
[font-size-adjust](#propdef-font-size-adjust) property is specified only for the
right span. Starting with a value of 0.5, the aspect value can be
adjusted until the borders around the two letters line up.

``` highlight
p {
 font-family: Futura;
 font-size: 500px;
}

span {
 border: solid 1px red;
}

.adjust {
 font-size-adjust: 0.5;
}

<p><span>b</span><span class="adjust">b</span></p>
```

![Futura with an [aspect
value](#font-size-adjust-aspect-value) of 0.5](images/beforefontsizeadjust.png){height="306"
width="281"}

The box on the right is a bit bigger than the one on the left, so the
[aspect
value](#font-size-adjust-aspect-value) of this font is something less than 0.5. Adjust the
value until the boxes align.

 If the specified metric has been overridden in
[\@font-face](#at-font-face-rule), e.g. by
[size-adjust](#descdef-font-face-size-adjust), then the overridden metric will
be used in the
[font-size-adjust](#propdef-font-size-adjust) calculation. Consequently, applying
[font-size-adjust] and
[size-adjust]
together means that
[size-adjust] appears
to have no effect.

## 4. Font Resources

### 4.1. The [[\@font-face] rule]
 Descriptors are applied per-font rather than
per-element. Multiple fonts can be used within an individual element
e.g. for characters not supported by the [first available
font](https://drafts.csswg.org/css-fonts-4/#first-available-font).

### [4.2. ][Font reference: the [src](https://drafts.csswg.org/css-fonts-4/#descdef-font-face-src) descriptor]
#### [4.2.1. ][Parsing the [src](https://drafts.csswg.org/css-fonts-4/#descdef-font-face-src) descriptor]
The
[src](https://drafts.csswg.org/css-fonts-4/#descdef-font-face-src) descriptor value must be parsed
according to section [CSS Syntax 3 § 5.4.10 Parse a comma-separated list
of component
values](https://drafts.csswg.org/css-syntax-3/#parse-comma-separated-list-of-component-values).
Then each component value is parsed according to this grammar:

``` highlight
<url> [ format(<font-format>)]? [ tech( <font-tech>#)]? | local(<font-family-name>)
```

```
<font-format>
 = [<string> | collection | embedded-opentype | opentype
 | svg | truetype | woff | woff2 ]
```

```
<font-tech>
 = [<font-features-tech> | <color-font-tech>
 | variations | palettes | incremental ]
```

```
<font-features-tech>
 = [features-opentype | features-aat | features-graphite]
```

```
<color-font-tech>
 = [color-COLRv0 | color-COLRv1 | color-SVG | color-sbix | color-CBDT ]
```

If a component value is parsed correctly and is a supported [CSS Fonts 4
§ 11.2 Font
formats](https://drafts.csswg.org/css-fonts-4/#font-format-definitions)
or [CSS Fonts 4 § 11.1 Font
tech](https://drafts.csswg.org/css-fonts-4/#font-tech-definitions), add
it to the list of supported sources. If parsing a component value
results in a parsing error or its format or tech are unsupported, do not
add it to the list of supported sources.

If there are no supported entries at the end of this process, the value
for the
[src](https://drafts.csswg.org/css-fonts-4/#descdef-font-face-src) descriptor is a parse error.

These parsing rules allow for graceful fallback of fonts for user agents
which don't support a particular font tech or font format.

For example, when incremental transfer
is not supported, a woff2 compressed version of the font is supplied,
for optimal performance. Then, for [incremental
transfer](https://w3c.github.io/IFT/Overview.html), the raw uncompressed
OpenType font is provided, portions of which will be loaded on demand.

``` highlight
@font-face {
 font-family: "MyIncrementallyLoadedWebFont";
 src: url("FallbackURLForBrowsersWhichDontSupportIncrementalLoading.woff2") format("woff2");
 src: url("MyIncrementallyLoadedWebFont.otf") format(opentype) tech(incremental);
}
```

### 4.3. Font property descriptors: the [font-size ]
(#issue-d41d8cd9⑥)[w3c/csswg-drafts/806](https://github.com/w3c/csswg-drafts/issues/806)[\[css-fonts-5\] Add font-size descriptor to
\@font-face which allows ranges (for optical
sizing)](https://github.com/w3c/csswg-drafts/issues/806)

(#issue-d41d8cd9⑦)[w3c/csswg-drafts/731](https://github.com/w3c/csswg-drafts/issues/731)[\[css-fonts\] font-size Descriptor for ex
Unit](https://github.com/w3c/csswg-drafts/issues/731)

Name:

[font-size]

For:

[\@font-face](#at-font-face-rule)

Value:

auto
[\|](https://drafts.csswg.org/css-values-4/#comb-one)
\[[\<number\>](https://drafts.csswg.org/css-values-4/#number-value)\][{1,2}](https://drafts.csswg.org/css-values-4/#mult-num-range)

Initial:

auto

[auto]
: The font matches any font size

[[\<number\>](https://drafts.csswg.org/css-values-4/#number-value)]
: If a single
 [\<number\>](https://drafts.csswg.org/css-values-4/#number-value) is given the font matches that
 specific font size, only. If two [\<number\>]s are given, they specify a range of font sizes which
 will match.

### 4.4. Glyph Size Multiplier: the [size-adjust descriptor]
Name:

[size-adjust]

For:

[\@font-face](#at-font-face-rule)

Value:

[\<percentage
\[0,∞\]\>](https://drafts.csswg.org/css-values-4/#percentage-value)

Initial:

100%

The
[size-adjust](#descdef-font-face-size-adjust) descriptor defines a multiplier
for glyph outlines and metrics associated with this font, to allow the
author to harmonize the designs of various fonts when rendered at the
same
[font-size](https://drafts.csswg.org/css-fonts-4/#propdef-font-size).

All metrics associated with this font---​including glyph advances,
baseline tables, and overrides provided by
[\@font-face](#at-font-face-rule) descriptors---​are scaled by the given percentage, as
are the rendered glyph images. Consequently, any values derived from
font metrics (such as
[ex](https://drafts.csswg.org/css-values-4/#ex) and
[ch](https://drafts.csswg.org/css-values-4/#ch) units, or the
[from-font](https://drafts.csswg.org/css-text-decor-4/#valdef-text-decoration-thickness-from-font) value of
[text-decoration-thickness](https://drafts.csswg.org/css-text-decor-4/#propdef-text-decoration-thickness)) are also affected when sourced
from this font. However, the
[computed](https://drafts.csswg.org/css-cascade-5/#computed-value)
[font-size](https://drafts.csswg.org/css-fonts-4/#propdef-font-size) (and thus any values that derive
from it, such as
[em](https://drafts.csswg.org/css-values-4/#em) units, percentages in
[text-underline-offset](https://drafts.csswg.org/css-text-decor-4/#propdef-text-underline-offset), etc.) remains unaffected.

 The
[size-adjust](#descdef-font-face-size-adjust) descriptor functions similarly to
the
[font-size-adjust](#propdef-font-size-adjust) property, which essentially
calculates an adjustment per font by matching ex heights, but likewise
does not affect the
[computed](https://drafts.csswg.org/css-cascade-5/#computed-value)
[font-size](https://drafts.csswg.org/css-fonts-4/#propdef-font-size).

Tests

- [font-size-adjust-metrics-override.html](https://wpt.fyi/results/css/css-fonts/font-size-adjust-metrics-override.html "css/css-fonts/font-size-adjust-metrics-override.html")
 [[(live
 test)]](http://wpt.live/css/css-fonts/font-size-adjust-metrics-override.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-fonts/font-size-adjust-metrics-override.html)
- [size-adjust-01.html](https://wpt.fyi/results/css/css-fonts/size-adjust-01.html "css/css-fonts/size-adjust-01.html")
 [[(live
 test)]](http://wpt.live/css/css-fonts/size-adjust-01.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-fonts/size-adjust-01.html)
- [size-adjust-02.html](https://wpt.fyi/results/css/css-fonts/size-adjust-02.html "css/css-fonts/size-adjust-02.html")
 [[(live
 test)]](http://wpt.live/css/css-fonts/size-adjust-02.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-fonts/size-adjust-02.html)
- [size-adjust-03.html](https://wpt.fyi/results/css/css-fonts/size-adjust-03.html "css/css-fonts/size-adjust-03.html")
 [[(live
 test)]](http://wpt.live/css/css-fonts/size-adjust-03.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-fonts/size-adjust-03.html)

### 4.5. Line Height Font Metrics Overrides: the [ascent-override, [descent-override](#descdef-font-face-descent-override), and [line-gap-override](#descdef-font-face-line-gap-override) descriptors]
Name:

[ascent-override]

For:

[\@font-face](#at-font-face-rule)

Value:

\[ normal
[\|](https://drafts.csswg.org/css-values-4/#comb-one) [\<percentage
\[0,∞\]\>](https://drafts.csswg.org/css-values-4/#percentage-value)
\][{1,2}](https://drafts.csswg.org/css-values-4/#mult-num-range)

Initial:

normal

Name:

[descent-override]

For:

[\@font-face](#at-font-face-rule)

Value:

\[ normal
[\|](https://drafts.csswg.org/css-values-4/#comb-one) [\<percentage
\[0,∞\]\>](https://drafts.csswg.org/css-values-4/#percentage-value)
\][{1,2}](https://drafts.csswg.org/css-values-4/#mult-num-range)

Initial:

normal

Name:

[line-gap-override]

For:

[\@font-face](#at-font-face-rule)

Value:

\[ normal
[\|](https://drafts.csswg.org/css-values-4/#comb-one) [\<percentage
\[0,∞\]\>](https://drafts.csswg.org/css-values-4/#percentage-value)
\][{1,2}](https://drafts.csswg.org/css-values-4/#mult-num-range)

Initial:

normal

The
[ascent-override](#descdef-font-face-ascent-override),
[descent-override](#descdef-font-face-descent-override), and
[line-gap-override](#descdef-font-face-line-gap-override) descriptors specify the [ascent
metric](https://drafts.csswg.org/css-inline-3/#ascent-metric), [descent
metric](https://drafts.csswg.org/css-inline-3/#descent-metric), and [line gap
metric](https://drafts.csswg.org/css-inline-3/#line-gap-metric) of the font, respectively. The first value provides the
value for the x axis, and the second value provides the value for the y
axis (defaulting to [normal] if omitted).

[normal]

: The corresponding metric value is obtained from the font as usual,
 as if this descriptor were absent from the `@font-face`
 block.

 Since there are multiple sources of such metrics in
 some font formats, this can result in text layout that varies across
 UAs/platforms.

[[\<percentage\>](https://drafts.csswg.org/css-values-4/#percentage-value)]
: The corresponding metric is replaced by the given percentage
 multiplied by the effective font size after adjustment.

Tests

- [ascent-descent-override.html](https://wpt.fyi/results/css/css-fonts/ascent-descent-override.html "css/css-fonts/ascent-descent-override.html")
 [[(live
 test)]](http://wpt.live/css/css-fonts/ascent-descent-override.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-fonts/ascent-descent-override.html)
- [font-size-adjust-metrics-override.html](https://wpt.fyi/results/css/css-fonts/font-size-adjust-metrics-override.html "css/css-fonts/font-size-adjust-metrics-override.html")
 [[(live
 test)]](http://wpt.live/css/css-fonts/font-size-adjust-metrics-override.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-fonts/font-size-adjust-metrics-override.html)
- [line-gap-override.html](https://wpt.fyi/results/css/css-fonts/line-gap-override.html "css/css-fonts/line-gap-override.html")
 [[(live
 test)]](http://wpt.live/css/css-fonts/line-gap-override.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-fonts/line-gap-override.html)
- [metrics-override-normal-keyword.html](https://wpt.fyi/results/css/css-fonts/metrics-override-normal-keyword.html "css/css-fonts/metrics-override-normal-keyword.html")
 [[(live
 test)]](http://wpt.live/css/css-fonts/metrics-override-normal-keyword.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-fonts/metrics-override-normal-keyword.html)
- [font-face-metric-overrides.html](https://wpt.fyi/results/css/css-fonts/parsing/font-face-metric-overrides.html "css/css-fonts/parsing/font-face-metric-overrides.html")
 [[(live
 test)]](http://wpt.live/css/css-fonts/parsing/font-face-metric-overrides.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-fonts/parsing/font-face-metric-overrides.html)

The
[font-size-adjust](#propdef-font-size-adjust) property is applied after the
[size-adjust](#descdef-font-face-size-adjust) descriptor.

 The consequence of applying
[font-size-adjust](#propdef-font-size-adjust) after
[size-adjust](#descdef-font-face-size-adjust) is that
[size-adjust] appears
to have no effect.

 None of these descriptors affect the
[computation](https://drafts.csswg.org/css-cascade-5/#computed-value) of
[font-size](https://drafts.csswg.org/css-fonts-4/#propdef-font-size),
[line-height](https://drafts.csswg.org/css2/#propdef-line-height), or [font-relative
lengths](https://drafts.csswg.org/css-values-4/#font-relative-length). They can, however, affect the behavior of
[line-height: normal] and more
generally the baseline alignment of
[inline-level](https://drafts.csswg.org/css-display-4/#inline-level) content.

 Since these metrics are only applicable in the [block
axis](https://drafts.csswg.org/css-writing-modes-4/#block-axis), the y-axis value will only be used when [typesetting
upright](https://drafts.csswg.org/css-writing-modes-4/#typeset-upright) in vertical [typographic
modes](https://drafts.csswg.org/css-writing-modes-4/#typographic-mode).

The percentage is resolved against
different font sizes for different elements.

``` highlight
@font-face {
 font-family: overridden-font;
 ascent-override: 50%;
 ...
}

<span style="font-family: overridden-font; font-size: 20px;">
 Outer span content
 <span style="font-size: 150%;">Inner span content</span>
</span>
```

The outer span uses an
[ascent](https://drafts.csswg.org/css-inline-3/#ascent-metric) value of 10px, whereas the inner span uses 15px.

We may override the metrics of a local
fallback font to match the primary font, which is a web font. This
reduces layout shifting when switching from fallback to the primary
font.

``` highlight
@font-face {
 font-family: cool-web-font;
 src: url("https://example.com/font.woff");
}

@font-face {
 font-family: fallback-to-local;
 src: local(Some Local Font);
 /* Override metric values to match cool-web-font */
 ascent-override: 125%;
 descent-override: 25%;
 line-gap-override: 0%;
 size-adjust: 96%;
}

<div style="font-family: cool-web-font, fallback-to-local">Title goes here</div>
<img src="https://example.com/largeimage" a>
```

The image will not be shifted as much when the user agent finishes
loading and switches to use the web font (assuming the override values
are similar to the web font's natural metrics).

### 4.6. Superscript and subscript metrics overrides: the [superscript-position-override, [subscript-position-override](#descdef-font-face-subscript-position-override),[superscript-size-override](#descdef-font-face-superscript-size-override) and [subscript-size-override](#descdef-font-face-subscript-size-override) descriptors]
Name:

[superscript-position-override]

For:

[\@font-face](#at-font-face-rule)

Value:

\[ normal
[\|](https://drafts.csswg.org/css-values-4/#comb-one) from-font [\|]
[\<percentage\>](https://drafts.csswg.org/css-values-4/#percentage-value)
\][{1,2}](https://drafts.csswg.org/css-values-4/#mult-num-range)

Initial:

normal

Name:

[subscript-position-override]

For:

[\@font-face](#at-font-face-rule)

Value:

\[ normal
[\|](https://drafts.csswg.org/css-values-4/#comb-one) from-font [\|]
[\<percentage\>](https://drafts.csswg.org/css-values-4/#percentage-value)
\][{1,2}](https://drafts.csswg.org/css-values-4/#mult-num-range)

Initial:

normal

Name:

[superscript-size-override]

For:

[\@font-face](#at-font-face-rule)

Value:

\[ normal
[\|](https://drafts.csswg.org/css-values-4/#comb-one) from-font [\|] [\<percentage
\[0,∞\]\>](https://drafts.csswg.org/css-values-4/#percentage-value)
\][{1,2}](https://drafts.csswg.org/css-values-4/#mult-num-range)

Initial:

normal

Name:

[subscript-size-override]

For:

[\@font-face](#at-font-face-rule)

Value:

\[ normal
[\|](https://drafts.csswg.org/css-values-4/#comb-one) from-font [\|] [\<percentage
\[0,∞\]\>](https://drafts.csswg.org/css-values-4/#percentage-value)
\][{1,2}](https://drafts.csswg.org/css-values-4/#mult-num-range)

Initial:

normal

The
[superscript-position-override](#descdef-font-face-superscript-position-override),
[subscript-position-override](#descdef-font-face-subscript-position-override),
[superscript-size-override](#descdef-font-face-superscript-size-override), and
[subscript-size-override](#descdef-font-face-subscript-size-override) descriptors specify the
superscript offset, subscript offset, superscript size, and subscript
size metrics of the font, respectively, which are used to synthesize
glyphs when required by
[font-variant-position](https://drafts.csswg.org/css-fonts-4/#propdef-font-variant-position). The first value provides the value
for the x axis, and the second value provides the value for the y axis
(defaulting to the first value if omitted).

[normal]
: The UA determines what metrics value to use, whether derived from
 the font or from some heuristic.

[from-font]
: The corresponding metric in the font data is used, if any. (If the
 metric is missing, same as [normal].)

[[\<percentage\>](https://drafts.csswg.org/css-values-4/#percentage-value)]
: The corresponding metric is replaced by the given percentage
 multiplied by the used font size.

 Since these metrics are only applicable in the [block
axis](https://drafts.csswg.org/css-writing-modes-4/#block-axis), the y-axis value will only be used when [typesetting
upright](https://drafts.csswg.org/css-writing-modes-4/#typeset-upright) in [vertical typographic
modes](https://drafts.csswg.org/css-writing-modes-4/#vertical-typographic-mode).

## 5. Font Feature Properties

### [5.1. ][Font language override: the [font-language-override](https://drafts.csswg.org/css-fonts-4/#propdef-font-language-override) property]
(#issue-d41d8cd9⑧)[w3c/csswg-drafts/5484](https://github.com/w3c/csswg-drafts/issues/5484)[\[css-fonts-5\] Removing
font-language-override](https://github.com/w3c/csswg-drafts/issues/5484)

## 6. Font Feature and Variation Resolution

(#issue-d41d8cd9⑨)[w3c/csswg-drafts/5635](https://github.com/w3c/csswg-drafts/issues/5635)[\[CSS-Fonts\] Need method to interpolate
variable font settings](https://github.com/w3c/csswg-drafts/issues/5635)

## 7. Font Variation Properties

### [7.1. ][ Optical sizing control: the [font-optical-sizing](https://drafts.csswg.org/css-fonts-4/#propdef-font-optical-sizing) property]
(#issue-d41d8cd9①⓪)[w3c/csswg-drafts/5466](https://github.com/w3c/csswg-drafts/issues/5466)[\[css-text\]\[css-fonts\] Optical bounds of
a line](https://github.com/w3c/csswg-drafts/issues/5466)

## 8. Font Technologies and Formats

### 8.1. Font tech

This section expands upon [CSS Fonts 4 § 11.1 Font
tech](https://drafts.csswg.org/css-fonts-4/#font-tech-definitions).

The [avar2] tech refers
to support for version 2 of OpenType axis variations
[\[avar2\]](#biblio-avar2 "avar — Axis Variations Table Version 2"),
for flexible variation axis remapping.

For example, a font using variation axis
remapping is loaded only if supported:

``` highlight
@font-face {
 font-family: 'Roboto Flex';
 src: url('RobotoFlex-VF-avar2.woff2') format(woff2) tech(variations, avar2);
 src: url('RobotoFlex-VF.woff2') format(woff2) tech(variations);
 font-weight: 100 1000;
 font-stretch: 25% 151%;
}
```

## 9. Object Model

This section expands upon [CSS Fonts 4 §  12. Object
Model](https://drafts.csswg.org/css-fonts-4/#object-model).

The contents of
[\@font-face](#at-font-face-rule) and
[\@font-feature-values](https://drafts.csswg.org/css-fonts-4/#at-ruledef-font-feature-values) rules can be accessed via the following
extensions to the CSS Object Model.

Tests

- [idlharness.html](https://wpt.fyi/results/css/css-fonts/idlharness.html "css/css-fonts/idlharness.html")
 [[(live
 test)]](http://wpt.live/css/css-fonts/idlharness.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-fonts/idlharness.html)

### 9.1. The `CSSFontFaceRule` interface

The [CSSFontFaceRule] interface represents a
[\<@font-face\>](#at-font-face-rule) rule.

```
[Exposed=Window]
interface CSSFontFaceDescriptors : CSSStyleDeclaration {
 attribute [LegacyNullToEmptyString] CSSOMString src;
 attribute [LegacyNullToEmptyString] CSSOMString fontFamily;
 attribute [LegacyNullToEmptyString] CSSOMString font-family;
 attribute [LegacyNullToEmptyString] CSSOMString fontStyle;
 attribute [LegacyNullToEmptyString] CSSOMString font-style;
 attribute [LegacyNullToEmptyString] CSSOMString fontWeight;
 attribute [LegacyNullToEmptyString] CSSOMString font-weight;
 attribute [LegacyNullToEmptyString] CSSOMString fontStretch;
 attribute [LegacyNullToEmptyString] CSSOMString font-stretch;
 attribute [LegacyNullToEmptyString] CSSOMString fontWidth;
 attribute [LegacyNullToEmptyString] CSSOMString font-width;
 attribute [LegacyNullToEmptyString] CSSOMString fontSize;
 attribute [LegacyNullToEmptyString] CSSOMString font-size;
 attribute [LegacyNullToEmptyString] CSSOMString sizeAdjust;
 attribute [LegacyNullToEmptyString] CSSOMString size-adjust;
 attribute [LegacyNullToEmptyString] CSSOMString unicodeRange;
 attribute [LegacyNullToEmptyString] CSSOMString unicode-range;
 attribute [LegacyNullToEmptyString] CSSOMString fontFeatureSettings;
 attribute [LegacyNullToEmptyString] CSSOMString font-feature-settings;
 attribute [LegacyNullToEmptyString] CSSOMString fontVariationSettings;
 attribute [LegacyNullToEmptyString] CSSOMString font-variation-settings;
 attribute [LegacyNullToEmptyString] CSSOMString fontNamedInstance;
 attribute [LegacyNullToEmptyString] CSSOMString font-named-instance;
 attribute [LegacyNullToEmptyString] CSSOMString fontDisplay;
 attribute [LegacyNullToEmptyString] CSSOMString font-display;
 attribute [LegacyNullToEmptyString] CSSOMString fontLanguageOverride;
 attribute [LegacyNullToEmptyString] CSSOMString font-language-override;
 attribute [LegacyNullToEmptyString] CSSOMString ascentOverride;
 attribute [LegacyNullToEmptyString] CSSOMString ascent-override;
 attribute [LegacyNullToEmptyString] CSSOMString descentOverride;
 attribute [LegacyNullToEmptyString] CSSOMString descent-override;
 attribute [LegacyNullToEmptyString] CSSOMString lineGapOverride;
 attribute [LegacyNullToEmptyString] CSSOMString line-gap-override;
 attribute [LegacyNullToEmptyString] CSSOMString superscriptPositionOverride;
 attribute [LegacyNullToEmptyString] CSSOMString superscript-position-override;
 attribute [LegacyNullToEmptyString] CSSOMString subscriptPositionOverride;
 attribute [LegacyNullToEmptyString] CSSOMString subscript-position-override;
 attribute [LegacyNullToEmptyString] CSSOMString superscriptSizeOverride;
 attribute [LegacyNullToEmptyString] CSSOMString superscript-size-override;
 attribute [LegacyNullToEmptyString] CSSOMString subscriptSizeOverride;
 attribute [LegacyNullToEmptyString] CSSOMString subscript-size-override;
};

[Exposed=Window]
interface CSSFontFaceRule : CSSRule {
 [SameObject, PutForwards=cssText] readonly attribute CSSFontFaceDescriptors style;
};
```

## 10. Security Considerations

No new security considerations have been reported on this specification.

## 11. Privacy Considerations

No new privacy considerations have been reported on this specification.

## 12. Acknowledgments

Firstly, the editors would like to thank all of the [contributors to the
previous level of this
module](https://www.w3.org/TR/css-fonts-4/#acknowledgments).

Secondly, we would like to acknowledge Dave Crossland from Google,
Bernhard Fey from RealObjects, Xiaocheng Hu from Google, Jonathan Kew
from Mozilla, and Laurence Penney for their contributions to the
improvements in this Level 5.

## 13. Changes

### [13.1. ][Changes since the [WD of 6 February 2024](https://www.w3.org/TR/2024/WD-css-fonts-5-20240206/)]
- Added text-scale meta tag and preferred-text-scale environment
 variable support, with example ([Issue
 12380](https://github.com/w3c/csswg-drafts/issues/12380)), ([Issue
 12475](https://github.com/w3c/csswg-drafts/issues/12475))
- Added missing CSSOM superscript-position-override,
 subscript-position-override, superscript-size-override and
 subscript-size-override descriptors
- Added missing CSSOM size-adjust and font-size descriptors
- Added the avar2 font tech ([Issue
 10599](https://github.com/w3c/csswg-drafts/issues/10599))
- Updated incremental example to latest IFT spec ([Issue
 6063](https://github.com/w3c/csswg-drafts/issues/6063))
- Explicitly stated that font-size-adjust precedes font metrics
 overrides ([Issue
 8967](https://github.com/w3c/csswg-drafts/issues/8967))

### [13.2. ][Changes since the [WD of 21 December 2021](https://www.w3.org/TR/2021/WD-css-fonts-5-20211221/) ]
- Corrected the initial value for the font-size descriptor
- Set a range for the grammar of font-size-adjust number
- Changed grammar of local() to use family-name instead for
 font-face-name
- Updated to current incremental font download keywords
- Made feature-\* plural for consistency with CSS Conditional 5, and
 11.1 Font tech
- Normalized infinity to ∞ in range notation
- Fixed a typo in the tech() function

### [13.3. ][Changes since the [WD of 2021-07-29](https://www.w3.org/TR/2021/WD-css-fonts-5-20210729/)]
- Renamed technology to tech
- Security and Privacy are now separate sections
- Fixed font-technology grammar
- Copied section on parsing src descriptor from CSS Fonts 4

### [13.4. ][Changes since the [FPWD of 2021-06-29](https://www.w3.org/TR/2021/WD-css-fonts-5-20210629/)]
- Removed scary warning notice
- Added incremental font technology to supports
