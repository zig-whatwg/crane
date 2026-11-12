## 1. Introduction

A common mechanism for displaying Web pages that were designed for large
desktop displays on much smaller displays such as those of mobile phones
involves allowing the user to pan and zoom around within a view of the
Web page drawn as though it were drawn into the width of a typical
desktop Web browser display. The ability to pan and zoom the page lets
the user both see an overview of the page and zoom in to specific parts
to read or interact with them.

One common problem with this type of interaction occurs when the user
wants to read a large block of text. It might be that a block of text
within this desktop-formatted page might be laid out so that when the
user zooms in so that the text is large enough to read, each line of
text is wider than the display on the small device. This means the user
needs to scroll side to side to read *each line of text*, which is a
serious inconvenience to the user.

One way for software that displays Web pages or other CSS-formatted
content on a mobile device is to make some of the text larger so that
this problem does not occur. The goal of this enlargement is to make the
text big enough so that when the block it is in is scaled to the width
of the display, the text is large enough to read. At the same time, this
needs to be done with minimal disruption to the overall design of the
page.

While implementations of CSS are not required to use this technique,
this module describes how implementations of CSS that do use this
technique must do so. In other words, while implementations of CSS are
not required to implement this module, this module nonetheless places
requirements on implementations of this module.

This module describes how this size adjustment works and describes a new
CSS property that authors of CSS can use to provide hints to the
implementation about which text or other elements should or should not
be enlarged.

### 1.1. Module interactions

This module adds additional features that are not defined in
[\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification").
These features may lead to a different size being computed than would be
computed when following
[\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")
alone.

### 1.2. Value Definitions

This specification follows the [CSS property definition
conventions](https://www.w3.org/TR/CSS2/about.html#property-defs) from
[\[CSS21\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")
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

## 2. Default size adjustment

This section defines the default size adjustment rules. These rules are
then referenced by the definition of the
[text-size-adjust](#propdef-text-size-adjust) property in the following section.

All of the subsections of this section
need significant refinement: additional detail, verification that the
detail already present is correct, etc.

It's not clear how much this section
should define precise behavior versus how much it should allow future
room for innovation and improvement.

### 2.1. Types of boxes adjusted

The default size adjustment affects text and form controls, whether
those form controls contain text (e.g., text inputs, selects) or do not
(e.g., radio buttons, checkboxes).

### 2.2. Conditions that suppress adjustment

A number of conditions suppress the default adjustment because these
conditions are associated with layouts for which the user experience
would be worsened by size adjustment rather than improved by it. These
conditions are:

- when the total amount of text in the block formatting context (see
 [\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification"))
 (excluding text inside descendant block formatting contexts) is
 approximately smaller than the amount that would require wrapping to
 more than one or two lines within that context's width,
- when the objects to be adjusted are inside a block-level or [display:
 inline-block](https://drafts.csswg.org/css-display-4/#propdef-display) element with a
 [height](https://drafts.csswg.org/css-sizing-3/#propdef-height) other than
 [auto](https://drafts.csswg.org/css-sizing-3/#valdef-width-auto) (see
 [\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")),
- when the objects to be adjusted are inside a [display:
 inline-block](https://drafts.csswg.org/css-display-4/#propdef-display) element with a
 [width](https://drafts.csswg.org/css-sizing-3/#propdef-width) other than
 [auto](https://drafts.csswg.org/css-sizing-3/#valdef-width-auto) (see
 [\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")),
- when the objects to be adjusted have
 [white-space](https://drafts.csswg.org/css-text-4/#propdef-white-space) of
 [pre](https://drafts.csswg.org/css-text-4/#valdef-white-space-pre) or
 [nowrap](https://drafts.csswg.org/css-text-3/#valdef-white-space-nowrap) (see
 [\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification"))
 or a
 [text-wrap](https://drafts.csswg.org/css-text-4/#propdef-text-wrap) of [nowrap] (see
 [\[CSS-TEXT-4\]](#biblio-css-text-4 "CSS Text Module Level 4")).

### 2.3. Calculation of default adjustment

The adjustment performed should be based on preferences (of the renderer
or the renderer's user) indicating the desired [minimum readable text
size]. Given this preference, for each containing block of text to
be adjusted, there is a [minimum block text
size]: the preference for the minimum readable text size, times the
width of the containing block, divided by the width of the device.

The size adjustment involves multiplication of sizes by a ratio
determined by the [minimum block text
size](#minimum-block-text-size) and the computed value of
[font-size](https://drafts.csswg.org/css-fonts-4/#propdef-font-size). This ratio must be at least the
first divided by the second; however, in order to maintain
differentiations between font sizes, it should often be slightly larger.
[(#issue-7a854497)Define this with more
detail/precision.]

## 3. Size adjustment control: the [text-size-adjust property]
Name:

[text-size-adjust]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

auto
[\|](https://drafts.csswg.org/css-values-4/#comb-one) none [\|] [\<percentage
\[0,∞\]\>](https://drafts.csswg.org/css-values-4/#percentage-value)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

auto

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[all
elements](https://www.w3.org/TR/css-pseudo/#generated-content "Includes ::before and ::after pseudo-elements.")

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

yes

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

see below

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

specified keyword or percentage

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

N/A

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value

[auto]
: Renderers must use the [default size
 adjustment](#default-adjustment) when displaying on a small device.

[none]
: Renderers must not do size adjustment when displaying on a small
 device.

[\<percentage \[0,∞\]\>]

: When displaying on a small device, renderers must not do size
 adjustment but instead the computed value of
 [font-size](https://drafts.csswg.org/css-fonts-4/#propdef-font-size) must be multiplied by this
 percentage.

 Note: This means that \'text-size-adjust: 100%;\' is equivalent to
 \'text-size-adjust: none;\'.

 Negative values are invalid.

\"Small device\" is not well defined. We
should clearly specify when text size adjustment should apply. For
example, in practice a large tablet is considered by vendors to be a
small device.

## 4. Acknowledgments

The editors would like to thank: .

## [Privacy Considerations]
No new privacy considerations have been reported on this specification.

## [Security Considerations]
No new security considerations have been reported on this specification.
