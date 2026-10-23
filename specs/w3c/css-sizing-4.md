## 1. Introduction

This is a diff spec over [CSS Sizing
Level 3](https://www.w3.org/TR/css-sizing-3/). It is currently an
Exploratory Working Draft: if you are implementing anything, please use
Level 3 as a reference. We will merge the Level 3 text into this draft
once it reaches CR.

Tests

General sizing tests

- [dynamic-available-size-iframe.html](https://wpt.fyi/results/css/css-sizing/dynamic-available-size-iframe.html "css/css-sizing/dynamic-available-size-iframe.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/dynamic-available-size-iframe.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/dynamic-available-size-iframe.html)
- [dynamic-change-inline-size-001.html](https://wpt.fyi/results/css/css-sizing/dynamic-change-inline-size-001.html "css/css-sizing/dynamic-change-inline-size-001.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/dynamic-change-inline-size-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/dynamic-change-inline-size-001.html)
- [dynamic-change-inline-size-002.html](https://wpt.fyi/results/css/css-sizing/dynamic-change-inline-size-002.html "css/css-sizing/dynamic-change-inline-size-002.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/dynamic-change-inline-size-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/dynamic-change-inline-size-002.html)
- [dynamic-change-inline-size-003.html](https://wpt.fyi/results/css/css-sizing/dynamic-change-inline-size-003.html "css/css-sizing/dynamic-change-inline-size-003.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/dynamic-change-inline-size-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/dynamic-change-inline-size-003.html)
- [dynamic-change-inline-size-004.html](https://wpt.fyi/results/css/css-sizing/dynamic-change-inline-size-004.html "css/css-sizing/dynamic-change-inline-size-004.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/dynamic-change-inline-size-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/dynamic-change-inline-size-004.html)
- [frameset-intrinsic-crash.html](https://wpt.fyi/results/css/css-sizing/frameset-intrinsic-crash.html "css/css-sizing/frameset-intrinsic-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/frameset-intrinsic-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/frameset-intrinsic-crash.html)
- [inheritance-001.html](https://wpt.fyi/results/css/css-sizing/inheritance-001.html "css/css-sizing/inheritance-001.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/inheritance-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/inheritance-001.html)
- [inheritance-002.html](https://wpt.fyi/results/css/css-sizing/inheritance-002.html "css/css-sizing/inheritance-002.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/inheritance-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/inheritance-002.html)
- [min-width-max-width-precedence.html](https://wpt.fyi/results/css/css-sizing/min-width-max-width-precedence.html "css/css-sizing/min-width-max-width-precedence.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/min-width-max-width-precedence.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/min-width-max-width-precedence.html)
- [min-width-max-width-precedence.html](https://wpt.fyi/results/css/css-sizing/min-width-max-width-precedence.html "css/css-sizing/min-width-max-width-precedence.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/min-width-max-width-precedence.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/min-width-max-width-precedence.html)
- [replaced-max-size-saturation.html](https://wpt.fyi/results/css/css-sizing/replaced-max-size-saturation.html "css/css-sizing/replaced-max-size-saturation.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/replaced-max-size-saturation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/replaced-max-size-saturation.html)
- [responsive-iframe-no-match-element.html](https://wpt.fyi/results/css/css-sizing/responsive-iframe/responsive-iframe-no-match-element.html "css/css-sizing/responsive-iframe/responsive-iframe-no-match-element.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/responsive-iframe/responsive-iframe-no-match-element.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/responsive-iframe/responsive-iframe-no-match-element.html)
- [textarea-large-padding-crash.html](https://wpt.fyi/results/css/css-sizing/textarea-large-padding-crash.html "css/css-sizing/textarea-large-padding-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/textarea-large-padding-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/textarea-large-padding-crash.html)

------------------------------------------------------------------------

### 1.1. Module interactions

This module extends the
[width](https://drafts.csswg.org/css-sizing-3/#propdef-width),
[height](https://drafts.csswg.org/css-sizing-3/#propdef-height),
[min-width](https://drafts.csswg.org/css2/#propdef-min-width),
[min-height](https://drafts.csswg.org/css2/#propdef-min-height),
[max-width](https://drafts.csswg.org/css2/#propdef-max-width),
[max-height](https://drafts.csswg.org/css2/#propdef-max-height), and
[column-width](https://drafts.csswg.org/css-multicol-2/#propdef-column-width) features defined in
[\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")
chapter 10 and in
[\[CSS3COL\]](#biblio-css3col "CSS Multi-column Layout Module Level 1")

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
value types.

In addition to the property-specific values listed in their definitions,
all properties defined in this specification also accept the [CSS-wide
keywords](https://drafts.csswg.org/css-values-4/#css-wide-keywords) as their property value. For readability they have not
been repeated explicitly.

## 2. Terminology

[CSS Sizing 3 § 2
Terminology](https://drafts.csswg.org/css-sizing-3/#terms)

## 3. Specifying Box Sizes

(#issue-d41d8cd9①) [CSS Sizing 3 § 3 Specifying Box
Sizes](https://drafts.csswg.org/css-sizing-3/#specifying-sizes)

### 3.1. Sizing Properties

(#issue-d41d8cd9②) [CSS Sizing 3 § 3.1 Sizing
Properties](https://drafts.csswg.org/css-sizing-3/#sizing-properties)

Name:

[size]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<\'width\'\>](https://drafts.csswg.org/css-sizing-3/#propdef-width)
[\<\'height\'\>](https://drafts.csswg.org/css-sizing-3/#propdef-height)[?](https://drafts.csswg.org/css-values-4/#mult-opt)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

auto

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[all
elements](https://www.w3.org/TR/css-pseudo/#generated-content "Includes ::before and ::after pseudo-elements.")

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

The [size](#propdef-size) property is a
[shorthand](https://drafts.csswg.org/css-cascade-5/#shorthand-property) that sets
[width](https://drafts.csswg.org/css-sizing-3/#propdef-width) and
[height](https://drafts.csswg.org/css-sizing-3/#propdef-height) in a single declaration. If the
second value is omitted, it is copied from the first.

The [size](#propdef-size) shorthand cannot be used in
[\@page](https://drafts.csswg.org/css-page-3/#at-ruledef-page) contexts, as [\@page] already has an unrelated
[size](https://drafts.csswg.org/css-page-3/#descdef-page-size) descriptor for setting the page size.

The
[size](#propdef-size) property needs to be omitted from the [preferred
shorthand
order](https://drafts.csswg.org/cssom-1/#concept-shorthands-preferred-order) in CSSOM, to avoid compat problems and conflicts with
[\@page](https://drafts.csswg.org/css-page-3/#at-ruledef-page).

Name:

[min-size]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<\'min-width\'\>](https://drafts.csswg.org/css2/#propdef-min-width)
[\<\'min-height\'\>](https://drafts.csswg.org/css2/#propdef-min-height)[?](https://drafts.csswg.org/css-values-4/#mult-opt)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

auto

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[all
elements](https://www.w3.org/TR/css-pseudo/#generated-content "Includes ::before and ::after pseudo-elements.")

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

The [min-size](#propdef-min-size) property is a
[shorthand](https://drafts.csswg.org/css-cascade-5/#shorthand-property) that sets
[min-width](https://drafts.csswg.org/css2/#propdef-min-width) and
[min-height](https://drafts.csswg.org/css2/#propdef-min-height) in a single declaration. If the
second value is omitted, it is copied from the first.

Name:

[max-size]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<\'max-width\'\>](https://drafts.csswg.org/css2/#propdef-max-width)
[\<\'max-height\'\>](https://drafts.csswg.org/css2/#propdef-max-height)[?](https://drafts.csswg.org/css-values-4/#mult-opt)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

none

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

[all
elements](https://www.w3.org/TR/css-pseudo/#generated-content "Includes ::before and ::after pseudo-elements.")

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

The [max-size](#propdef-max-size) property is a
[shorthand](https://drafts.csswg.org/css-cascade-5/#shorthand-property) that sets
[max-width](https://drafts.csswg.org/css2/#propdef-max-width) and
[max-height](https://drafts.csswg.org/css2/#propdef-max-height) in a single declaration. If the
second value is omitted, it is copied from the first.

### 3.2. New Sizing Values: the [contain, [stretch()](#funcdef-width-stretch), [fit-content()](#funcdef-width-fit-content), and [calc-size()](#funcdef-width-calc-size) values]
Integrate [CSS Sizing 3 § 3.2 Sizing
Values: the \<length-percentage\>, auto \| none, stretch, min-content,
max-content, and fit-content
values](https://drafts.csswg.org/css-sizing-3/#sizing-values)

Level 4 adds the ability to use the
[contain](#valdef-width-contain),
[fit-content()](#funcdef-width-fit-content), and
[calc-size()](#funcdef-width-calc-size) values in the [sizing
properties](https://drafts.csswg.org/css-sizing-3/#sizing-property), thus expanding the
[\<box-size\>](#typedef-box-size) production as follows:

``` prod
<box-size> = <length-percentage [0,∞]>
 | stretch | contain | min-content | max-content | fit-content
 | stretch(<length-percentage [0,∞]>) | fit-content(<length-percentage [0,∞]>)
 | <calc-size()>
```

[stretch([\<length-percentage \[0,∞\]\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage))]

: Fit the [margin
 box](https://drafts.csswg.org/css-box-4/#margin-box) to the size specified by the argument. For this
 purpose, treat [auto]
 [margins](https://drafts.csswg.org/css-box-4/#margin) as zero, and ignore [margin
 collapsing](https://www.w3.org/TR/CSS2/box.html#collapsing-margins),
 [margin-trim](https://drafts.csswg.org/css-box-4/#propdef-margin-trim), and other effects that
 suppress or truncate the margin.

 Although margin collapsing, etc. are ignored for
 the purpose of calculating this size, their effects are not
 otherwise suppressed, and apply as usual.

 The
 [\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage) argument is resolved exactly as
 for [\<length-percentage\>] values standing alone.

 (#issue-012bec6b) Open discussion wrt details here.
 [\[Issue #5715\]](https://github.com/w3c/csswg-drafts/issues/5715)

[fit-content([\<length-percentage \[0,∞\]\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage))]
: Use the fit-content formula with the [available
 space](https://drafts.csswg.org/css-sizing-3/#available) replaced by
 [stretch()](#funcdef-width-stretch) into the specified argument, i.e.
 `min(`[`max-content`](https://drafts.csswg.org/css-sizing-3/#valdef-width-max-content)`, max(`[`min-content`](https://drafts.csswg.org/css-sizing-3/#valdef-width-min-content)`, stretch(`[`<length-percentage>`](https://drafts.csswg.org/css-values-4/#typedef-length-percentage)`))`.
 Tests
 - [auto-scrollbar-inside-stf-abspos.html](https://wpt.fyi/results/css/css-sizing/auto-scrollbar-inside-stf-abspos.html "css/css-sizing/auto-scrollbar-inside-stf-abspos.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/auto-scrollbar-inside-stf-abspos.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/auto-scrollbar-inside-stf-abspos.html)
 - [block-fit-content-as-initial.html](https://wpt.fyi/results/css/css-sizing/block-fit-content-as-initial.html "css/css-sizing/block-fit-content-as-initial.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/block-fit-content-as-initial.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/block-fit-content-as-initial.html)
 - [fit-content-length-percentage-001.html](https://wpt.fyi/results/css/css-sizing/fit-content-length-percentage-001.html "css/css-sizing/fit-content-length-percentage-001.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/fit-content-length-percentage-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/fit-content-length-percentage-001.html)
 - [fit-content-length-percentage-002.html](https://wpt.fyi/results/css/css-sizing/fit-content-length-percentage-002.html "css/css-sizing/fit-content-length-percentage-002.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/fit-content-length-percentage-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/fit-content-length-percentage-002.html)
 - [fit-content-length-percentage-003.html](https://wpt.fyi/results/css/css-sizing/fit-content-length-percentage-003.html "css/css-sizing/fit-content-length-percentage-003.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/fit-content-length-percentage-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/fit-content-length-percentage-003.html)
 - [fit-content-length-percentage-004.html](https://wpt.fyi/results/css/css-sizing/fit-content-length-percentage-004.html "css/css-sizing/fit-content-length-percentage-004.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/fit-content-length-percentage-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/fit-content-length-percentage-004.html)
 - [fit-content-length-percentage-005.html](https://wpt.fyi/results/css/css-sizing/fit-content-length-percentage-005.html "css/css-sizing/fit-content-length-percentage-005.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/fit-content-length-percentage-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/fit-content-length-percentage-005.html)
 - [fit-content-length-percentage-006.html](https://wpt.fyi/results/css/css-sizing/fit-content-length-percentage-006.html "css/css-sizing/fit-content-length-percentage-006.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/fit-content-length-percentage-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/fit-content-length-percentage-006.html)
 - [fit-content-length-percentage-007.html](https://wpt.fyi/results/css/css-sizing/fit-content-length-percentage-007.html "css/css-sizing/fit-content-length-percentage-007.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/fit-content-length-percentage-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/fit-content-length-percentage-007.html)
 - [fit-content-length-percentage-008.html](https://wpt.fyi/results/css/css-sizing/fit-content-length-percentage-008.html "css/css-sizing/fit-content-length-percentage-008.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/fit-content-length-percentage-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/fit-content-length-percentage-008.html)
 - [fit-content-length-percentage-009.html](https://wpt.fyi/results/css/css-sizing/fit-content-length-percentage-009.html "css/css-sizing/fit-content-length-percentage-009.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/fit-content-length-percentage-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/fit-content-length-percentage-009.html)
 - [fit-content-length-percentage-010.html](https://wpt.fyi/results/css/css-sizing/fit-content-length-percentage-010.html "css/css-sizing/fit-content-length-percentage-010.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/fit-content-length-percentage-010.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/fit-content-length-percentage-010.html)
 - [fit-content-length-percentage-011.html](https://wpt.fyi/results/css/css-sizing/fit-content-length-percentage-011.html "css/css-sizing/fit-content-length-percentage-011.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/fit-content-length-percentage-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/fit-content-length-percentage-011.html)
 - [fit-content-length-percentage-012.html](https://wpt.fyi/results/css/css-sizing/fit-content-length-percentage-012.html "css/css-sizing/fit-content-length-percentage-012.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/fit-content-length-percentage-012.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/fit-content-length-percentage-012.html)
 - [fit-content-length-percentage-013.html](https://wpt.fyi/results/css/css-sizing/fit-content-length-percentage-013.html "css/css-sizing/fit-content-length-percentage-013.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/fit-content-length-percentage-013.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/fit-content-length-percentage-013.html)
 - [fit-content-length-percentage-014.html](https://wpt.fyi/results/css/css-sizing/fit-content-length-percentage-014.html "css/css-sizing/fit-content-length-percentage-014.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/fit-content-length-percentage-014.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/fit-content-length-percentage-014.html)
 - [fit-content-length-percentage-015.html](https://wpt.fyi/results/css/css-sizing/fit-content-length-percentage-015.html "css/css-sizing/fit-content-length-percentage-015.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/fit-content-length-percentage-015.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/fit-content-length-percentage-015.html)
 - [fit-content-length-percentage-016.html](https://wpt.fyi/results/css/css-sizing/fit-content-length-percentage-016.html "css/css-sizing/fit-content-length-percentage-016.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/fit-content-length-percentage-016.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/fit-content-length-percentage-016.html)

[contain]

: If the box has a [preferred aspect
 ratio](#preferred-aspect-ratio), applies [contain-fit
 sizing](#contain-fit-sizing), attempting to fit into the box's constraints while
 maintaining its [preferred aspect
 ratio] insofar as possible. See
 [§ 6.1 Contain-fit Sizing: stretching while maintaining an aspect
 ratio](#contain-fit-sizing).

 If the box has no [preferred aspect
 ratio](#preferred-aspect-ratio), applies [stretch-fit
 sizing](https://drafts.csswg.org/css-sizing-3/#stretch-fit-size).

[calc-size()]

: See [CSS Values 5 §  11. Calculating With Intrinsic Sizes: the
 calc-size()
 function](https://drafts.csswg.org/css-values-5/#calc-size).

 The
 [none](https://drafts.csswg.org/css-sizing-3/#valdef-max-width-none) keyword is not usable within
 [calc-size()](#funcdef-width-calc-size).

 These new values add to the set of values that the
definition of
[\<calc-size()\>](#funcdef-width-calc-size) refers to as "allowed in the
context".

## 4. Aspect Ratios

Images often have a [natural aspect
ratio](https://drafts.csswg.org/css-images-3/#natural-aspect-ratio), which the CSS layout algorithms attempt to preserve as
they resize the element.

The [aspect-ratio](#propdef-aspect-ratio) property allows specifying this
behavior for non-replaced elements, and for altering the effective
aspect ratio of replaced elements.

We are still working through the details
of this section. If there is any behavior specified here that would
cause [replaced
elements](https://drafts.csswg.org/css-display-4/#replaced-element) with a [preferred aspect
ratio](#preferred-aspect-ratio) to behave differently than they would under the
requirements of the [CSS2](https://www.w3.org/TR/CSS2/visudet.html),
[Flex Layout](https://www.w3.org/TR/css-flexbox-1/), and [Grid
Layout](https://www.w3.org/TR/css-grid-1/) specs combined (without this
specification in effect), **this is an error and should be
[reported](https://github.com/w3c/csswg-drafts/issues) to the CSSWG**.
There is a [list of open aspect-ratio
issues](https://github.com/w3c/csswg-drafts/issues?q=is%3Aissue%20state%3Aopen%20label%3Acss-sizing-4%20aspect-ratio%20label%3A%22Needs%20Edits%22).

### 4.1. Preferred Aspect Ratios: the [aspect-ratio property]
Name:

[aspect-ratio]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

auto
[\|\|](https://drafts.csswg.org/css-values-4/#comb-any)
[\<ratio\>](https://drafts.csswg.org/css-values-4/#ratio-value)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

auto

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

all elements except [inline
boxes](https://drafts.csswg.org/css-display-4/#inline-box) and internal ruby or table boxes

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

specified keyword or a pair of numbers

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value

Tests

- [aspect-ratio-interpolation.html](https://wpt.fyi/results/css/css-sizing/animation/aspect-ratio-interpolation.html "css/css-sizing/animation/aspect-ratio-interpolation.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/animation/aspect-ratio-interpolation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/animation/aspect-ratio-interpolation.html)
- [abspos-001.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/abspos-001.html "css/css-sizing/aspect-ratio/abspos-001.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/abspos-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/abspos-001.html)
- [abspos-002.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/abspos-002.html "css/css-sizing/aspect-ratio/abspos-002.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/abspos-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/abspos-002.html)
- [abspos-003.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/abspos-003.html "css/css-sizing/aspect-ratio/abspos-003.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/abspos-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/abspos-003.html)
- [abspos-004.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/abspos-004.html "css/css-sizing/aspect-ratio/abspos-004.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/abspos-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/abspos-004.html)
- [abspos-005.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/abspos-005.html "css/css-sizing/aspect-ratio/abspos-005.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/abspos-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/abspos-005.html)
- [abspos-006.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/abspos-006.html "css/css-sizing/aspect-ratio/abspos-006.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/abspos-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/abspos-006.html)
- [abspos-007.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/abspos-007.html "css/css-sizing/aspect-ratio/abspos-007.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/abspos-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/abspos-007.html)
- [abspos-008.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/abspos-008.html "css/css-sizing/aspect-ratio/abspos-008.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/abspos-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/abspos-008.html)
- [abspos-009.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/abspos-009.html "css/css-sizing/aspect-ratio/abspos-009.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/abspos-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/abspos-009.html)
- [abspos-010.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/abspos-010.html "css/css-sizing/aspect-ratio/abspos-010.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/abspos-010.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/abspos-010.html)
- [abspos-011.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/abspos-011.html "css/css-sizing/aspect-ratio/abspos-011.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/abspos-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/abspos-011.html)
- [abspos-012.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/abspos-012.html "css/css-sizing/aspect-ratio/abspos-012.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/abspos-012.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/abspos-012.html)
- [abspos-013.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/abspos-013.html "css/css-sizing/aspect-ratio/abspos-013.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/abspos-013.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/abspos-013.html)
- [abspos-014.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/abspos-014.html "css/css-sizing/aspect-ratio/abspos-014.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/abspos-014.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/abspos-014.html)
- [abspos-015.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/abspos-015.html "css/css-sizing/aspect-ratio/abspos-015.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/abspos-015.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/abspos-015.html)
- [abspos-016.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/abspos-016.html "css/css-sizing/aspect-ratio/abspos-016.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/abspos-016.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/abspos-016.html)
- [abspos-017.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/abspos-017.html "css/css-sizing/aspect-ratio/abspos-017.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/abspos-017.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/abspos-017.html)
- [abspos-018.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/abspos-018.html "css/css-sizing/aspect-ratio/abspos-018.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/abspos-018.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/abspos-018.html)
- [abspos-019.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/abspos-019.html "css/css-sizing/aspect-ratio/abspos-019.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/abspos-019.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/abspos-019.html)
- [abspos-020.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/abspos-020.html "css/css-sizing/aspect-ratio/abspos-020.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/abspos-020.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/abspos-020.html)
- [abspos-021.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/abspos-021.html "css/css-sizing/aspect-ratio/abspos-021.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/abspos-021.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/abspos-021.html)
- [auto-margins-001.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/auto-margins-001.html "css/css-sizing/aspect-ratio/auto-margins-001.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/auto-margins-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/auto-margins-001.html)
- [block-aspect-ratio-001.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/block-aspect-ratio-001.html "css/css-sizing/aspect-ratio/block-aspect-ratio-001.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/block-aspect-ratio-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/block-aspect-ratio-001.html)
- [block-aspect-ratio-002.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/block-aspect-ratio-002.html "css/css-sizing/aspect-ratio/block-aspect-ratio-002.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/block-aspect-ratio-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/block-aspect-ratio-002.html)
- [block-aspect-ratio-003.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/block-aspect-ratio-003.html "css/css-sizing/aspect-ratio/block-aspect-ratio-003.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/block-aspect-ratio-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/block-aspect-ratio-003.html)
- [block-aspect-ratio-004.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/block-aspect-ratio-004.html "css/css-sizing/aspect-ratio/block-aspect-ratio-004.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/block-aspect-ratio-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/block-aspect-ratio-004.html)
- [block-aspect-ratio-005.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/block-aspect-ratio-005.html "css/css-sizing/aspect-ratio/block-aspect-ratio-005.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/block-aspect-ratio-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/block-aspect-ratio-005.html)
- [block-aspect-ratio-006.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/block-aspect-ratio-006.html "css/css-sizing/aspect-ratio/block-aspect-ratio-006.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/block-aspect-ratio-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/block-aspect-ratio-006.html)
- [block-aspect-ratio-007.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/block-aspect-ratio-007.html "css/css-sizing/aspect-ratio/block-aspect-ratio-007.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/block-aspect-ratio-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/block-aspect-ratio-007.html)
- [block-aspect-ratio-008.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/block-aspect-ratio-008.html "css/css-sizing/aspect-ratio/block-aspect-ratio-008.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/block-aspect-ratio-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/block-aspect-ratio-008.html)
- [block-aspect-ratio-009.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/block-aspect-ratio-009.html "css/css-sizing/aspect-ratio/block-aspect-ratio-009.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/block-aspect-ratio-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/block-aspect-ratio-009.html)
- [block-aspect-ratio-010.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/block-aspect-ratio-010.html "css/css-sizing/aspect-ratio/block-aspect-ratio-010.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/block-aspect-ratio-010.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/block-aspect-ratio-010.html)
- [block-aspect-ratio-011.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/block-aspect-ratio-011.html "css/css-sizing/aspect-ratio/block-aspect-ratio-011.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/block-aspect-ratio-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/block-aspect-ratio-011.html)
- [block-aspect-ratio-012.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/block-aspect-ratio-012.html "css/css-sizing/aspect-ratio/block-aspect-ratio-012.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/block-aspect-ratio-012.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/block-aspect-ratio-012.html)
- [block-aspect-ratio-013.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/block-aspect-ratio-013.html "css/css-sizing/aspect-ratio/block-aspect-ratio-013.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/block-aspect-ratio-013.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/block-aspect-ratio-013.html)
- [block-aspect-ratio-014.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/block-aspect-ratio-014.html "css/css-sizing/aspect-ratio/block-aspect-ratio-014.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/block-aspect-ratio-014.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/block-aspect-ratio-014.html)
- [block-aspect-ratio-015.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/block-aspect-ratio-015.html "css/css-sizing/aspect-ratio/block-aspect-ratio-015.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/block-aspect-ratio-015.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/block-aspect-ratio-015.html)
- [block-aspect-ratio-016.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/block-aspect-ratio-016.html "css/css-sizing/aspect-ratio/block-aspect-ratio-016.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/block-aspect-ratio-016.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/block-aspect-ratio-016.html)
- [block-aspect-ratio-017.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/block-aspect-ratio-017.html "css/css-sizing/aspect-ratio/block-aspect-ratio-017.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/block-aspect-ratio-017.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/block-aspect-ratio-017.html)
- [block-aspect-ratio-018.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/block-aspect-ratio-018.html "css/css-sizing/aspect-ratio/block-aspect-ratio-018.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/block-aspect-ratio-018.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/block-aspect-ratio-018.html)
- [block-aspect-ratio-019.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/block-aspect-ratio-019.html "css/css-sizing/aspect-ratio/block-aspect-ratio-019.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/block-aspect-ratio-019.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/block-aspect-ratio-019.html)
- [block-aspect-ratio-020.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/block-aspect-ratio-020.html "css/css-sizing/aspect-ratio/block-aspect-ratio-020.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/block-aspect-ratio-020.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/block-aspect-ratio-020.html)
- [block-aspect-ratio-021.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/block-aspect-ratio-021.html "css/css-sizing/aspect-ratio/block-aspect-ratio-021.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/block-aspect-ratio-021.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/block-aspect-ratio-021.html)
- [block-aspect-ratio-022.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/block-aspect-ratio-022.html "css/css-sizing/aspect-ratio/block-aspect-ratio-022.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/block-aspect-ratio-022.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/block-aspect-ratio-022.html)
- [block-aspect-ratio-023.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/block-aspect-ratio-023.html "css/css-sizing/aspect-ratio/block-aspect-ratio-023.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/block-aspect-ratio-023.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/block-aspect-ratio-023.html)
- [block-aspect-ratio-024.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/block-aspect-ratio-024.html "css/css-sizing/aspect-ratio/block-aspect-ratio-024.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/block-aspect-ratio-024.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/block-aspect-ratio-024.html)
- [block-aspect-ratio-025.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/block-aspect-ratio-025.html "css/css-sizing/aspect-ratio/block-aspect-ratio-025.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/block-aspect-ratio-025.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/block-aspect-ratio-025.html)
- [block-aspect-ratio-026.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/block-aspect-ratio-026.html "css/css-sizing/aspect-ratio/block-aspect-ratio-026.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/block-aspect-ratio-026.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/block-aspect-ratio-026.html)
- [block-aspect-ratio-027.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/block-aspect-ratio-027.html "css/css-sizing/aspect-ratio/block-aspect-ratio-027.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/block-aspect-ratio-027.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/block-aspect-ratio-027.html)
- [block-aspect-ratio-028.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/block-aspect-ratio-028.html "css/css-sizing/aspect-ratio/block-aspect-ratio-028.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/block-aspect-ratio-028.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/block-aspect-ratio-028.html)
- [block-aspect-ratio-029-crash.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/block-aspect-ratio-029-crash.html "css/css-sizing/aspect-ratio/block-aspect-ratio-029-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/block-aspect-ratio-029-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/block-aspect-ratio-029-crash.html)
- [block-aspect-ratio-030.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/block-aspect-ratio-030.html "css/css-sizing/aspect-ratio/block-aspect-ratio-030.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/block-aspect-ratio-030.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/block-aspect-ratio-030.html)
- [block-aspect-ratio-031.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/block-aspect-ratio-031.html "css/css-sizing/aspect-ratio/block-aspect-ratio-031.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/block-aspect-ratio-031.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/block-aspect-ratio-031.html)
- [block-aspect-ratio-032.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/block-aspect-ratio-032.html "css/css-sizing/aspect-ratio/block-aspect-ratio-032.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/block-aspect-ratio-032.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/block-aspect-ratio-032.html)
- [block-aspect-ratio-033.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/block-aspect-ratio-033.html "css/css-sizing/aspect-ratio/block-aspect-ratio-033.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/block-aspect-ratio-033.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/block-aspect-ratio-033.html)
- [block-aspect-ratio-034.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/block-aspect-ratio-034.html "css/css-sizing/aspect-ratio/block-aspect-ratio-034.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/block-aspect-ratio-034.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/block-aspect-ratio-034.html)
- [block-aspect-ratio-035.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/block-aspect-ratio-035.html "css/css-sizing/aspect-ratio/block-aspect-ratio-035.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/block-aspect-ratio-035.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/block-aspect-ratio-035.html)
- [block-aspect-ratio-036.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/block-aspect-ratio-036.html "css/css-sizing/aspect-ratio/block-aspect-ratio-036.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/block-aspect-ratio-036.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/block-aspect-ratio-036.html)
- [block-aspect-ratio-037.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/block-aspect-ratio-037.html "css/css-sizing/aspect-ratio/block-aspect-ratio-037.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/block-aspect-ratio-037.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/block-aspect-ratio-037.html)
- [block-aspect-ratio-051-crash.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/block-aspect-ratio-051-crash.html "css/css-sizing/aspect-ratio/block-aspect-ratio-051-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/block-aspect-ratio-051-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/block-aspect-ratio-051-crash.html)
- [block-aspect-ratio-052.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/block-aspect-ratio-052.html "css/css-sizing/aspect-ratio/block-aspect-ratio-052.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/block-aspect-ratio-052.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/block-aspect-ratio-052.html)
- [block-aspect-ratio-053.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/block-aspect-ratio-053.html "css/css-sizing/aspect-ratio/block-aspect-ratio-053.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/block-aspect-ratio-053.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/block-aspect-ratio-053.html)
- [block-aspect-ratio-054.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/block-aspect-ratio-054.html "css/css-sizing/aspect-ratio/block-aspect-ratio-054.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/block-aspect-ratio-054.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/block-aspect-ratio-054.html)
- [block-aspect-ratio-055.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/block-aspect-ratio-055.html "css/css-sizing/aspect-ratio/block-aspect-ratio-055.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/block-aspect-ratio-055.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/block-aspect-ratio-055.html)
- [block-aspect-ratio-056.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/block-aspect-ratio-056.html "css/css-sizing/aspect-ratio/block-aspect-ratio-056.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/block-aspect-ratio-056.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/block-aspect-ratio-056.html)
- [block-aspect-ratio-058.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/block-aspect-ratio-058.html "css/css-sizing/aspect-ratio/block-aspect-ratio-058.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/block-aspect-ratio-058.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/block-aspect-ratio-058.html)
- [block-aspect-ratio-with-margin-collapsing-001.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/block-aspect-ratio-with-margin-collapsing-001.html "css/css-sizing/aspect-ratio/block-aspect-ratio-with-margin-collapsing-001.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/block-aspect-ratio-with-margin-collapsing-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/block-aspect-ratio-with-margin-collapsing-001.html)
- [block-aspect-ratio-with-margin-collapsing-002.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/block-aspect-ratio-with-margin-collapsing-002.html "css/css-sizing/aspect-ratio/block-aspect-ratio-with-margin-collapsing-002.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/block-aspect-ratio-with-margin-collapsing-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/block-aspect-ratio-with-margin-collapsing-002.html)
- [box-sizing-dimensions.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/box-sizing-dimensions.html "css/css-sizing/aspect-ratio/box-sizing-dimensions.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/box-sizing-dimensions.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/box-sizing-dimensions.html)
- [box-sizing-squashed.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/box-sizing-squashed.html "css/css-sizing/aspect-ratio/box-sizing-squashed.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/box-sizing-squashed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/box-sizing-squashed.html)
- [flex-aspect-ratio-001.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/flex-aspect-ratio-001.html "css/css-sizing/aspect-ratio/flex-aspect-ratio-001.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/flex-aspect-ratio-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/flex-aspect-ratio-001.html)
- [flex-aspect-ratio-003.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/flex-aspect-ratio-003.html "css/css-sizing/aspect-ratio/flex-aspect-ratio-003.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/flex-aspect-ratio-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/flex-aspect-ratio-003.html)
- [flex-aspect-ratio-005.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/flex-aspect-ratio-005.html "css/css-sizing/aspect-ratio/flex-aspect-ratio-005.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/flex-aspect-ratio-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/flex-aspect-ratio-005.html)
- [flex-aspect-ratio-006.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/flex-aspect-ratio-006.html "css/css-sizing/aspect-ratio/flex-aspect-ratio-006.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/flex-aspect-ratio-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/flex-aspect-ratio-006.html)
- [flex-aspect-ratio-007.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/flex-aspect-ratio-007.html "css/css-sizing/aspect-ratio/flex-aspect-ratio-007.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/flex-aspect-ratio-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/flex-aspect-ratio-007.html)
- [flex-aspect-ratio-008.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/flex-aspect-ratio-008.html "css/css-sizing/aspect-ratio/flex-aspect-ratio-008.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/flex-aspect-ratio-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/flex-aspect-ratio-008.html)
- [flex-aspect-ratio-009.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/flex-aspect-ratio-009.html "css/css-sizing/aspect-ratio/flex-aspect-ratio-009.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/flex-aspect-ratio-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/flex-aspect-ratio-009.html)
- [flex-aspect-ratio-010.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/flex-aspect-ratio-010.html "css/css-sizing/aspect-ratio/flex-aspect-ratio-010.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/flex-aspect-ratio-010.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/flex-aspect-ratio-010.html)
- [flex-aspect-ratio-011.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/flex-aspect-ratio-011.html "css/css-sizing/aspect-ratio/flex-aspect-ratio-011.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/flex-aspect-ratio-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/flex-aspect-ratio-011.html)
- [flex-aspect-ratio-012.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/flex-aspect-ratio-012.html "css/css-sizing/aspect-ratio/flex-aspect-ratio-012.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/flex-aspect-ratio-012.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/flex-aspect-ratio-012.html)
- [flex-aspect-ratio-013.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/flex-aspect-ratio-013.html "css/css-sizing/aspect-ratio/flex-aspect-ratio-013.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/flex-aspect-ratio-013.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/flex-aspect-ratio-013.html)
- [flex-aspect-ratio-014.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/flex-aspect-ratio-014.html "css/css-sizing/aspect-ratio/flex-aspect-ratio-014.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/flex-aspect-ratio-014.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/flex-aspect-ratio-014.html)
- [flex-aspect-ratio-015.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/flex-aspect-ratio-015.html "css/css-sizing/aspect-ratio/flex-aspect-ratio-015.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/flex-aspect-ratio-015.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/flex-aspect-ratio-015.html)
- [flex-aspect-ratio-016.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/flex-aspect-ratio-016.html "css/css-sizing/aspect-ratio/flex-aspect-ratio-016.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/flex-aspect-ratio-016.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/flex-aspect-ratio-016.html)
- [flex-aspect-ratio-017.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/flex-aspect-ratio-017.html "css/css-sizing/aspect-ratio/flex-aspect-ratio-017.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/flex-aspect-ratio-017.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/flex-aspect-ratio-017.html)
- [flex-aspect-ratio-018.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/flex-aspect-ratio-018.html "css/css-sizing/aspect-ratio/flex-aspect-ratio-018.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/flex-aspect-ratio-018.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/flex-aspect-ratio-018.html)
- [flex-aspect-ratio-019.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/flex-aspect-ratio-019.html "css/css-sizing/aspect-ratio/flex-aspect-ratio-019.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/flex-aspect-ratio-019.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/flex-aspect-ratio-019.html)
- [flex-aspect-ratio-020.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/flex-aspect-ratio-020.html "css/css-sizing/aspect-ratio/flex-aspect-ratio-020.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/flex-aspect-ratio-020.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/flex-aspect-ratio-020.html)
- [flex-aspect-ratio-021.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/flex-aspect-ratio-021.html "css/css-sizing/aspect-ratio/flex-aspect-ratio-021.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/flex-aspect-ratio-021.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/flex-aspect-ratio-021.html)
- [flex-aspect-ratio-022.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/flex-aspect-ratio-022.html "css/css-sizing/aspect-ratio/flex-aspect-ratio-022.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/flex-aspect-ratio-022.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/flex-aspect-ratio-022.html)
- [flex-aspect-ratio-023.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/flex-aspect-ratio-023.html "css/css-sizing/aspect-ratio/flex-aspect-ratio-023.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/flex-aspect-ratio-023.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/flex-aspect-ratio-023.html)
- [flex-aspect-ratio-024.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/flex-aspect-ratio-024.html "css/css-sizing/aspect-ratio/flex-aspect-ratio-024.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/flex-aspect-ratio-024.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/flex-aspect-ratio-024.html)
- [flex-aspect-ratio-027.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/flex-aspect-ratio-027.html "css/css-sizing/aspect-ratio/flex-aspect-ratio-027.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/flex-aspect-ratio-027.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/flex-aspect-ratio-027.html)
- [flex-aspect-ratio-028.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/flex-aspect-ratio-028.html "css/css-sizing/aspect-ratio/flex-aspect-ratio-028.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/flex-aspect-ratio-028.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/flex-aspect-ratio-028.html)
- [flex-aspect-ratio-029.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/flex-aspect-ratio-029.html "css/css-sizing/aspect-ratio/flex-aspect-ratio-029.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/flex-aspect-ratio-029.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/flex-aspect-ratio-029.html)
- [flex-aspect-ratio-030.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/flex-aspect-ratio-030.html "css/css-sizing/aspect-ratio/flex-aspect-ratio-030.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/flex-aspect-ratio-030.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/flex-aspect-ratio-030.html)
- [flex-aspect-ratio-032.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/flex-aspect-ratio-032.html "css/css-sizing/aspect-ratio/flex-aspect-ratio-032.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/flex-aspect-ratio-032.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/flex-aspect-ratio-032.html)
- [flex-aspect-ratio-033.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/flex-aspect-ratio-033.html "css/css-sizing/aspect-ratio/flex-aspect-ratio-033.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/flex-aspect-ratio-033.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/flex-aspect-ratio-033.html)
- [flex-aspect-ratio-034.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/flex-aspect-ratio-034.html "css/css-sizing/aspect-ratio/flex-aspect-ratio-034.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/flex-aspect-ratio-034.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/flex-aspect-ratio-034.html)
- [flex-aspect-ratio-035.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/flex-aspect-ratio-035.html "css/css-sizing/aspect-ratio/flex-aspect-ratio-035.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/flex-aspect-ratio-035.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/flex-aspect-ratio-035.html)
- [flex-aspect-ratio-036.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/flex-aspect-ratio-036.html "css/css-sizing/aspect-ratio/flex-aspect-ratio-036.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/flex-aspect-ratio-036.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/flex-aspect-ratio-036.html)
- [flex-aspect-ratio-037.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/flex-aspect-ratio-037.html "css/css-sizing/aspect-ratio/flex-aspect-ratio-037.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/flex-aspect-ratio-037.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/flex-aspect-ratio-037.html)
- [flex-aspect-ratio-038.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/flex-aspect-ratio-038.html "css/css-sizing/aspect-ratio/flex-aspect-ratio-038.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/flex-aspect-ratio-038.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/flex-aspect-ratio-038.html)
- [flex-aspect-ratio-045.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/flex-aspect-ratio-045.html "css/css-sizing/aspect-ratio/flex-aspect-ratio-045.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/flex-aspect-ratio-045.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/flex-aspect-ratio-045.html)
- [flex-aspect-ratio-046.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/flex-aspect-ratio-046.html "css/css-sizing/aspect-ratio/flex-aspect-ratio-046.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/flex-aspect-ratio-046.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/flex-aspect-ratio-046.html)
- [flex-aspect-ratio-047.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/flex-aspect-ratio-047.html "css/css-sizing/aspect-ratio/flex-aspect-ratio-047.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/flex-aspect-ratio-047.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/flex-aspect-ratio-047.html)
- [flex-aspect-ratio-048.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/flex-aspect-ratio-048.html "css/css-sizing/aspect-ratio/flex-aspect-ratio-048.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/flex-aspect-ratio-048.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/flex-aspect-ratio-048.html)
- [flex-aspect-ratio-049.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/flex-aspect-ratio-049.html "css/css-sizing/aspect-ratio/flex-aspect-ratio-049.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/flex-aspect-ratio-049.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/flex-aspect-ratio-049.html)
- [flex-aspect-ratio-050.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/flex-aspect-ratio-050.html "css/css-sizing/aspect-ratio/flex-aspect-ratio-050.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/flex-aspect-ratio-050.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/flex-aspect-ratio-050.html)
- [flex-aspect-ratio-051.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/flex-aspect-ratio-051.html "css/css-sizing/aspect-ratio/flex-aspect-ratio-051.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/flex-aspect-ratio-051.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/flex-aspect-ratio-051.html)
- [flex-aspect-ratio-052.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/flex-aspect-ratio-052.html "css/css-sizing/aspect-ratio/flex-aspect-ratio-052.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/flex-aspect-ratio-052.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/flex-aspect-ratio-052.html)
- [flex-aspect-ratio-053.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/flex-aspect-ratio-053.html "css/css-sizing/aspect-ratio/flex-aspect-ratio-053.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/flex-aspect-ratio-053.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/flex-aspect-ratio-053.html)
- [flex-aspect-ratio-054.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/flex-aspect-ratio-054.html "css/css-sizing/aspect-ratio/flex-aspect-ratio-054.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/flex-aspect-ratio-054.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/flex-aspect-ratio-054.html)
- [flex-aspect-ratio-055.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/flex-aspect-ratio-055.html "css/css-sizing/aspect-ratio/flex-aspect-ratio-055.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/flex-aspect-ratio-055.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/flex-aspect-ratio-055.html)
- [floats-aspect-ratio-001.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/floats-aspect-ratio-001.html "css/css-sizing/aspect-ratio/floats-aspect-ratio-001.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/floats-aspect-ratio-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/floats-aspect-ratio-001.html)
- [fractional-aspect-ratio.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/fractional-aspect-ratio.html "css/css-sizing/aspect-ratio/fractional-aspect-ratio.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/fractional-aspect-ratio.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/fractional-aspect-ratio.html)
- [grid-aspect-ratio-001.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/grid-aspect-ratio-001.html "css/css-sizing/aspect-ratio/grid-aspect-ratio-001.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/grid-aspect-ratio-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/grid-aspect-ratio-001.html)
- [grid-aspect-ratio-002.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/grid-aspect-ratio-002.html "css/css-sizing/aspect-ratio/grid-aspect-ratio-002.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/grid-aspect-ratio-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/grid-aspect-ratio-002.html)
- [grid-aspect-ratio-003.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/grid-aspect-ratio-003.html "css/css-sizing/aspect-ratio/grid-aspect-ratio-003.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/grid-aspect-ratio-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/grid-aspect-ratio-003.html)
- [grid-aspect-ratio-004.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/grid-aspect-ratio-004.html "css/css-sizing/aspect-ratio/grid-aspect-ratio-004.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/grid-aspect-ratio-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/grid-aspect-ratio-004.html)
- [grid-aspect-ratio-005.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/grid-aspect-ratio-005.html "css/css-sizing/aspect-ratio/grid-aspect-ratio-005.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/grid-aspect-ratio-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/grid-aspect-ratio-005.html)
- [grid-aspect-ratio-006.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/grid-aspect-ratio-006.html "css/css-sizing/aspect-ratio/grid-aspect-ratio-006.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/grid-aspect-ratio-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/grid-aspect-ratio-006.html)
- [grid-aspect-ratio-007.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/grid-aspect-ratio-007.html "css/css-sizing/aspect-ratio/grid-aspect-ratio-007.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/grid-aspect-ratio-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/grid-aspect-ratio-007.html)
- [grid-aspect-ratio-008.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/grid-aspect-ratio-008.html "css/css-sizing/aspect-ratio/grid-aspect-ratio-008.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/grid-aspect-ratio-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/grid-aspect-ratio-008.html)
- [grid-aspect-ratio-009.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/grid-aspect-ratio-009.html "css/css-sizing/aspect-ratio/grid-aspect-ratio-009.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/grid-aspect-ratio-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/grid-aspect-ratio-009.html)
- [grid-aspect-ratio-010.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/grid-aspect-ratio-010.html "css/css-sizing/aspect-ratio/grid-aspect-ratio-010.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/grid-aspect-ratio-010.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/grid-aspect-ratio-010.html)
- [grid-aspect-ratio-011.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/grid-aspect-ratio-011.html "css/css-sizing/aspect-ratio/grid-aspect-ratio-011.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/grid-aspect-ratio-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/grid-aspect-ratio-011.html)
- [grid-aspect-ratio-012.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/grid-aspect-ratio-012.html "css/css-sizing/aspect-ratio/grid-aspect-ratio-012.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/grid-aspect-ratio-012.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/grid-aspect-ratio-012.html)
- [grid-aspect-ratio-014.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/grid-aspect-ratio-014.html "css/css-sizing/aspect-ratio/grid-aspect-ratio-014.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/grid-aspect-ratio-014.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/grid-aspect-ratio-014.html)
- [grid-aspect-ratio-015.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/grid-aspect-ratio-015.html "css/css-sizing/aspect-ratio/grid-aspect-ratio-015.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/grid-aspect-ratio-015.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/grid-aspect-ratio-015.html)
- [grid-aspect-ratio-016.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/grid-aspect-ratio-016.html "css/css-sizing/aspect-ratio/grid-aspect-ratio-016.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/grid-aspect-ratio-016.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/grid-aspect-ratio-016.html)
- [grid-aspect-ratio-017.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/grid-aspect-ratio-017.html "css/css-sizing/aspect-ratio/grid-aspect-ratio-017.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/grid-aspect-ratio-017.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/grid-aspect-ratio-017.html)
- [grid-aspect-ratio-018.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/grid-aspect-ratio-018.html "css/css-sizing/aspect-ratio/grid-aspect-ratio-018.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/grid-aspect-ratio-018.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/grid-aspect-ratio-018.html)
- [grid-aspect-ratio-019.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/grid-aspect-ratio-019.html "css/css-sizing/aspect-ratio/grid-aspect-ratio-019.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/grid-aspect-ratio-019.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/grid-aspect-ratio-019.html)
- [grid-aspect-ratio-020.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/grid-aspect-ratio-020.html "css/css-sizing/aspect-ratio/grid-aspect-ratio-020.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/grid-aspect-ratio-020.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/grid-aspect-ratio-020.html)
- [grid-aspect-ratio-021.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/grid-aspect-ratio-021.html "css/css-sizing/aspect-ratio/grid-aspect-ratio-021.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/grid-aspect-ratio-021.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/grid-aspect-ratio-021.html)
- [grid-aspect-ratio-022.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/grid-aspect-ratio-022.html "css/css-sizing/aspect-ratio/grid-aspect-ratio-022.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/grid-aspect-ratio-022.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/grid-aspect-ratio-022.html)
- [grid-aspect-ratio-023.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/grid-aspect-ratio-023.html "css/css-sizing/aspect-ratio/grid-aspect-ratio-023.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/grid-aspect-ratio-023.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/grid-aspect-ratio-023.html)
- [grid-aspect-ratio-024.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/grid-aspect-ratio-024.html "css/css-sizing/aspect-ratio/grid-aspect-ratio-024.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/grid-aspect-ratio-024.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/grid-aspect-ratio-024.html)
- [grid-aspect-ratio-025.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/grid-aspect-ratio-025.html "css/css-sizing/aspect-ratio/grid-aspect-ratio-025.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/grid-aspect-ratio-025.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/grid-aspect-ratio-025.html)
- [grid-aspect-ratio-026.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/grid-aspect-ratio-026.html "css/css-sizing/aspect-ratio/grid-aspect-ratio-026.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/grid-aspect-ratio-026.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/grid-aspect-ratio-026.html)
- [grid-aspect-ratio-027.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/grid-aspect-ratio-027.html "css/css-sizing/aspect-ratio/grid-aspect-ratio-027.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/grid-aspect-ratio-027.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/grid-aspect-ratio-027.html)
- [grid-aspect-ratio-028.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/grid-aspect-ratio-028.html "css/css-sizing/aspect-ratio/grid-aspect-ratio-028.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/grid-aspect-ratio-028.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/grid-aspect-ratio-028.html)
- [grid-aspect-ratio-029.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/grid-aspect-ratio-029.html "css/css-sizing/aspect-ratio/grid-aspect-ratio-029.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/grid-aspect-ratio-029.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/grid-aspect-ratio-029.html)
- [grid-aspect-ratio-030.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/grid-aspect-ratio-030.html "css/css-sizing/aspect-ratio/grid-aspect-ratio-030.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/grid-aspect-ratio-030.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/grid-aspect-ratio-030.html)
- [grid-aspect-ratio-031.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/grid-aspect-ratio-031.html "css/css-sizing/aspect-ratio/grid-aspect-ratio-031.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/grid-aspect-ratio-031.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/grid-aspect-ratio-031.html)
- [grid-aspect-ratio-032.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/grid-aspect-ratio-032.html "css/css-sizing/aspect-ratio/grid-aspect-ratio-032.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/grid-aspect-ratio-032.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/grid-aspect-ratio-032.html)
- [grid-aspect-ratio-033.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/grid-aspect-ratio-033.html "css/css-sizing/aspect-ratio/grid-aspect-ratio-033.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/grid-aspect-ratio-033.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/grid-aspect-ratio-033.html)
- [grid-aspect-ratio-034.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/grid-aspect-ratio-034.html "css/css-sizing/aspect-ratio/grid-aspect-ratio-034.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/grid-aspect-ratio-034.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/grid-aspect-ratio-034.html)
- [grid-aspect-ratio-035.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/grid-aspect-ratio-035.html "css/css-sizing/aspect-ratio/grid-aspect-ratio-035.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/grid-aspect-ratio-035.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/grid-aspect-ratio-035.html)
- [grid-aspect-ratio-036.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/grid-aspect-ratio-036.html "css/css-sizing/aspect-ratio/grid-aspect-ratio-036.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/grid-aspect-ratio-036.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/grid-aspect-ratio-036.html)
- [grid-aspect-ratio-037.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/grid-aspect-ratio-037.html "css/css-sizing/aspect-ratio/grid-aspect-ratio-037.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/grid-aspect-ratio-037.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/grid-aspect-ratio-037.html)
- [grid-aspect-ratio-038.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/grid-aspect-ratio-038.html "css/css-sizing/aspect-ratio/grid-aspect-ratio-038.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/grid-aspect-ratio-038.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/grid-aspect-ratio-038.html)
- [grid-aspect-ratio-040.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/grid-aspect-ratio-040.html "css/css-sizing/aspect-ratio/grid-aspect-ratio-040.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/grid-aspect-ratio-040.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/grid-aspect-ratio-040.html)
- [grid-aspect-ratio-041.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/grid-aspect-ratio-041.html "css/css-sizing/aspect-ratio/grid-aspect-ratio-041.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/grid-aspect-ratio-041.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/grid-aspect-ratio-041.html)
- [inheritance.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/inheritance.html "css/css-sizing/aspect-ratio/inheritance.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/inheritance.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/inheritance.html)
- [intrinsic-size-001.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/intrinsic-size-001.html "css/css-sizing/aspect-ratio/intrinsic-size-001.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/intrinsic-size-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/intrinsic-size-001.html)
- [intrinsic-size-002.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/intrinsic-size-002.html "css/css-sizing/aspect-ratio/intrinsic-size-002.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/intrinsic-size-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/intrinsic-size-002.html)
- [intrinsic-size-003.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/intrinsic-size-003.html "css/css-sizing/aspect-ratio/intrinsic-size-003.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/intrinsic-size-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/intrinsic-size-003.html)
- [intrinsic-size-004.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/intrinsic-size-004.html "css/css-sizing/aspect-ratio/intrinsic-size-004.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/intrinsic-size-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/intrinsic-size-004.html)
- [intrinsic-size-005.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/intrinsic-size-005.html "css/css-sizing/aspect-ratio/intrinsic-size-005.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/intrinsic-size-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/intrinsic-size-005.html)
- [intrinsic-size-006.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/intrinsic-size-006.html "css/css-sizing/aspect-ratio/intrinsic-size-006.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/intrinsic-size-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/intrinsic-size-006.html)
- [intrinsic-size-007.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/intrinsic-size-007.html "css/css-sizing/aspect-ratio/intrinsic-size-007.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/intrinsic-size-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/intrinsic-size-007.html)
- [intrinsic-size-008.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/intrinsic-size-008.html "css/css-sizing/aspect-ratio/intrinsic-size-008.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/intrinsic-size-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/intrinsic-size-008.html)
- [intrinsic-size-009.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/intrinsic-size-009.html "css/css-sizing/aspect-ratio/intrinsic-size-009.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/intrinsic-size-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/intrinsic-size-009.html)
- [intrinsic-size-011.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/intrinsic-size-011.html "css/css-sizing/aspect-ratio/intrinsic-size-011.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/intrinsic-size-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/intrinsic-size-011.html)
- [intrinsic-size-012.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/intrinsic-size-012.html "css/css-sizing/aspect-ratio/intrinsic-size-012.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/intrinsic-size-012.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/intrinsic-size-012.html)
- [intrinsic-size-013.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/intrinsic-size-013.html "css/css-sizing/aspect-ratio/intrinsic-size-013.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/intrinsic-size-013.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/intrinsic-size-013.html)
- [intrinsic-size-014.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/intrinsic-size-014.html "css/css-sizing/aspect-ratio/intrinsic-size-014.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/intrinsic-size-014.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/intrinsic-size-014.html)
- [intrinsic-size-015.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/intrinsic-size-015.html "css/css-sizing/aspect-ratio/intrinsic-size-015.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/intrinsic-size-015.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/intrinsic-size-015.html)
- [intrinsic-size-016.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/intrinsic-size-016.html "css/css-sizing/aspect-ratio/intrinsic-size-016.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/intrinsic-size-016.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/intrinsic-size-016.html)
- [intrinsic-size-017.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/intrinsic-size-017.html "css/css-sizing/aspect-ratio/intrinsic-size-017.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/intrinsic-size-017.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/intrinsic-size-017.html)
- [intrinsic-size-018.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/intrinsic-size-018.html "css/css-sizing/aspect-ratio/intrinsic-size-018.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/intrinsic-size-018.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/intrinsic-size-018.html)
- [intrinsic-size-019.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/intrinsic-size-019.html "css/css-sizing/aspect-ratio/intrinsic-size-019.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/intrinsic-size-019.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/intrinsic-size-019.html)
- [intrinsic-size-020.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/intrinsic-size-020.html "css/css-sizing/aspect-ratio/intrinsic-size-020.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/intrinsic-size-020.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/intrinsic-size-020.html)
- [intrinsic-size-021.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/intrinsic-size-021.html "css/css-sizing/aspect-ratio/intrinsic-size-021.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/intrinsic-size-021.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/intrinsic-size-021.html)
- [intrinsic-size-022.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/intrinsic-size-022.html "css/css-sizing/aspect-ratio/intrinsic-size-022.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/intrinsic-size-022.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/intrinsic-size-022.html)
- [intrinsic-size-023.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/intrinsic-size-023.html "css/css-sizing/aspect-ratio/intrinsic-size-023.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/intrinsic-size-023.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/intrinsic-size-023.html)
- [intrinsic-size-024.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/intrinsic-size-024.html "css/css-sizing/aspect-ratio/intrinsic-size-024.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/intrinsic-size-024.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/intrinsic-size-024.html)
- [intrinsic-size-025.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/intrinsic-size-025.html "css/css-sizing/aspect-ratio/intrinsic-size-025.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/intrinsic-size-025.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/intrinsic-size-025.html)
- [large-aspect-ratio-crash.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/large-aspect-ratio-crash.html "css/css-sizing/aspect-ratio/large-aspect-ratio-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/large-aspect-ratio-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/large-aspect-ratio-crash.html)
- [aspect-ratio-computed.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/parsing/aspect-ratio-computed.html "css/css-sizing/aspect-ratio/parsing/aspect-ratio-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/parsing/aspect-ratio-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/parsing/aspect-ratio-computed.html)
- [aspect-ratio-invalid.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/parsing/aspect-ratio-invalid.html "css/css-sizing/aspect-ratio/parsing/aspect-ratio-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/parsing/aspect-ratio-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/parsing/aspect-ratio-invalid.html)
- [aspect-ratio-valid.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/parsing/aspect-ratio-valid.html "css/css-sizing/aspect-ratio/parsing/aspect-ratio-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/parsing/aspect-ratio-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/parsing/aspect-ratio-valid.html)
- [percentage-resolution-001.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/percentage-resolution-001.html "css/css-sizing/aspect-ratio/percentage-resolution-001.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/percentage-resolution-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/percentage-resolution-001.html)
- [percentage-resolution-002.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/percentage-resolution-002.html "css/css-sizing/aspect-ratio/percentage-resolution-002.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/percentage-resolution-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/percentage-resolution-002.html)
- [percentage-resolution-003.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/percentage-resolution-003.html "css/css-sizing/aspect-ratio/percentage-resolution-003.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/percentage-resolution-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/percentage-resolution-003.html)
- [percentage-resolution-004.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/percentage-resolution-004.html "css/css-sizing/aspect-ratio/percentage-resolution-004.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/percentage-resolution-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/percentage-resolution-004.html)
- [percentage-resolution-005.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/percentage-resolution-005.html "css/css-sizing/aspect-ratio/percentage-resolution-005.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/percentage-resolution-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/percentage-resolution-005.html)
- [quirks-mode-001.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/quirks-mode-001.html "css/css-sizing/aspect-ratio/quirks-mode-001.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/quirks-mode-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/quirks-mode-001.html)
- [quirks-mode-002.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/quirks-mode-002.html "css/css-sizing/aspect-ratio/quirks-mode-002.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/quirks-mode-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/quirks-mode-002.html)
- [quirks-mode-003.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/quirks-mode-003.html "css/css-sizing/aspect-ratio/quirks-mode-003.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/quirks-mode-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/quirks-mode-003.html)
- [replaced-element-001.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/replaced-element-001.html "css/css-sizing/aspect-ratio/replaced-element-001.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/replaced-element-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/replaced-element-001.html)
- [replaced-element-002.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/replaced-element-002.html "css/css-sizing/aspect-ratio/replaced-element-002.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/replaced-element-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/replaced-element-002.html)
- [replaced-element-003.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/replaced-element-003.html "css/css-sizing/aspect-ratio/replaced-element-003.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/replaced-element-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/replaced-element-003.html)
- [replaced-element-004.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/replaced-element-004.html "css/css-sizing/aspect-ratio/replaced-element-004.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/replaced-element-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/replaced-element-004.html)
- [replaced-element-005.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/replaced-element-005.html "css/css-sizing/aspect-ratio/replaced-element-005.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/replaced-element-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/replaced-element-005.html)
- [replaced-element-006.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/replaced-element-006.html "css/css-sizing/aspect-ratio/replaced-element-006.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/replaced-element-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/replaced-element-006.html)
- [replaced-element-007.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/replaced-element-007.html "css/css-sizing/aspect-ratio/replaced-element-007.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/replaced-element-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/replaced-element-007.html)
- [replaced-element-008.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/replaced-element-008.html "css/css-sizing/aspect-ratio/replaced-element-008.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/replaced-element-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/replaced-element-008.html)
- [replaced-element-009.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/replaced-element-009.html "css/css-sizing/aspect-ratio/replaced-element-009.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/replaced-element-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/replaced-element-009.html)
- [replaced-element-010.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/replaced-element-010.html "css/css-sizing/aspect-ratio/replaced-element-010.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/replaced-element-010.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/replaced-element-010.html)
- [replaced-element-011.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/replaced-element-011.html "css/css-sizing/aspect-ratio/replaced-element-011.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/replaced-element-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/replaced-element-011.html)
- [replaced-element-012.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/replaced-element-012.html "css/css-sizing/aspect-ratio/replaced-element-012.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/replaced-element-012.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/replaced-element-012.html)
- [replaced-element-013.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/replaced-element-013.html "css/css-sizing/aspect-ratio/replaced-element-013.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/replaced-element-013.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/replaced-element-013.html)
- [replaced-element-014.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/replaced-element-014.html "css/css-sizing/aspect-ratio/replaced-element-014.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/replaced-element-014.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/replaced-element-014.html)
- [replaced-element-015.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/replaced-element-015.html "css/css-sizing/aspect-ratio/replaced-element-015.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/replaced-element-015.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/replaced-element-015.html)
- [replaced-element-016.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/replaced-element-016.html "css/css-sizing/aspect-ratio/replaced-element-016.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/replaced-element-016.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/replaced-element-016.html)
- [replaced-element-017.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/replaced-element-017.html "css/css-sizing/aspect-ratio/replaced-element-017.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/replaced-element-017.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/replaced-element-017.html)
- [replaced-element-018.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/replaced-element-018.html "css/css-sizing/aspect-ratio/replaced-element-018.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/replaced-element-018.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/replaced-element-018.html)
- [replaced-element-019.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/replaced-element-019.html "css/css-sizing/aspect-ratio/replaced-element-019.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/replaced-element-019.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/replaced-element-019.html)
- [replaced-element-020.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/replaced-element-020.html "css/css-sizing/aspect-ratio/replaced-element-020.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/replaced-element-020.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/replaced-element-020.html)
- [replaced-element-021.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/replaced-element-021.html "css/css-sizing/aspect-ratio/replaced-element-021.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/replaced-element-021.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/replaced-element-021.html)
- [replaced-element-022.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/replaced-element-022.html "css/css-sizing/aspect-ratio/replaced-element-022.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/replaced-element-022.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/replaced-element-022.html)
- [replaced-element-023.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/replaced-element-023.html "css/css-sizing/aspect-ratio/replaced-element-023.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/replaced-element-023.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/replaced-element-023.html)
- [replaced-element-024.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/replaced-element-024.html "css/css-sizing/aspect-ratio/replaced-element-024.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/replaced-element-024.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/replaced-element-024.html)
- [replaced-element-025.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/replaced-element-025.html "css/css-sizing/aspect-ratio/replaced-element-025.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/replaced-element-025.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/replaced-element-025.html)
- [replaced-element-026.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/replaced-element-026.html "css/css-sizing/aspect-ratio/replaced-element-026.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/replaced-element-026.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/replaced-element-026.html)
- [replaced-element-027.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/replaced-element-027.html "css/css-sizing/aspect-ratio/replaced-element-027.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/replaced-element-027.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/replaced-element-027.html)
- [replaced-element-028.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/replaced-element-028.html "css/css-sizing/aspect-ratio/replaced-element-028.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/replaced-element-028.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/replaced-element-028.html)
- [replaced-element-029.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/replaced-element-029.html "css/css-sizing/aspect-ratio/replaced-element-029.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/replaced-element-029.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/replaced-element-029.html)
- [replaced-element-030.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/replaced-element-030.html "css/css-sizing/aspect-ratio/replaced-element-030.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/replaced-element-030.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/replaced-element-030.html)
- [replaced-element-031.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/replaced-element-031.html "css/css-sizing/aspect-ratio/replaced-element-031.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/replaced-element-031.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/replaced-element-031.html)
- [replaced-element-034.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/replaced-element-034.html "css/css-sizing/aspect-ratio/replaced-element-034.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/replaced-element-034.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/replaced-element-034.html)
- [replaced-element-035.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/replaced-element-035.html "css/css-sizing/aspect-ratio/replaced-element-035.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/replaced-element-035.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/replaced-element-035.html)
- [replaced-element-036.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/replaced-element-036.html "css/css-sizing/aspect-ratio/replaced-element-036.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/replaced-element-036.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/replaced-element-036.html)
- [replaced-element-037.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/replaced-element-037.html "css/css-sizing/aspect-ratio/replaced-element-037.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/replaced-element-037.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/replaced-element-037.html)
- [replaced-element-042.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/replaced-element-042.html "css/css-sizing/aspect-ratio/replaced-element-042.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/replaced-element-042.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/replaced-element-042.html)
- [replaced-element-045.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/replaced-element-045.html "css/css-sizing/aspect-ratio/replaced-element-045.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/replaced-element-045.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/replaced-element-045.html)
- [replaced-element-046.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/replaced-element-046.html "css/css-sizing/aspect-ratio/replaced-element-046.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/replaced-element-046.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/replaced-element-046.html)
- [replaced-element-049.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/replaced-element-049.html "css/css-sizing/aspect-ratio/replaced-element-049.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/replaced-element-049.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/replaced-element-049.html)
- [replaced-element-dynamic-aspect-ratio.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/replaced-element-dynamic-aspect-ratio.html "css/css-sizing/aspect-ratio/replaced-element-dynamic-aspect-ratio.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/replaced-element-dynamic-aspect-ratio.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/replaced-element-dynamic-aspect-ratio.html)
- [select-element-001.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/select-element-001.html "css/css-sizing/aspect-ratio/select-element-001.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/select-element-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/select-element-001.html)
- [sign-function-aspect-ratio.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/sign-function-aspect-ratio.html "css/css-sizing/aspect-ratio/sign-function-aspect-ratio.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/sign-function-aspect-ratio.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/sign-function-aspect-ratio.html)
- [small-aspect-ratio-crash.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/small-aspect-ratio-crash.html "css/css-sizing/aspect-ratio/small-aspect-ratio-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/small-aspect-ratio-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/small-aspect-ratio-crash.html)
- [table-element-001.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/table-element-001.html "css/css-sizing/aspect-ratio/table-element-001.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/table-element-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/table-element-001.html)
- [zero-or-infinity-001.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/zero-or-infinity-001.html "css/css-sizing/aspect-ratio/zero-or-infinity-001.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/zero-or-infinity-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/zero-or-infinity-001.html)
- [zero-or-infinity-002.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/zero-or-infinity-002.html "css/css-sizing/aspect-ratio/zero-or-infinity-002.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/zero-or-infinity-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/zero-or-infinity-002.html)
- [zero-or-infinity-003.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/zero-or-infinity-003.html "css/css-sizing/aspect-ratio/zero-or-infinity-003.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/zero-or-infinity-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/zero-or-infinity-003.html)
- [zero-or-infinity-004.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/zero-or-infinity-004.html "css/css-sizing/aspect-ratio/zero-or-infinity-004.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/zero-or-infinity-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/zero-or-infinity-004.html)
- [zero-or-infinity-005.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/zero-or-infinity-005.html "css/css-sizing/aspect-ratio/zero-or-infinity-005.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/zero-or-infinity-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/zero-or-infinity-005.html)
- [zero-or-infinity-006.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/zero-or-infinity-006.html "css/css-sizing/aspect-ratio/zero-or-infinity-006.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/zero-or-infinity-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/zero-or-infinity-006.html)
- [zero-or-infinity-007.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/zero-or-infinity-007.html "css/css-sizing/aspect-ratio/zero-or-infinity-007.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/zero-or-infinity-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/zero-or-infinity-007.html)
- [zero-or-infinity-008.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/zero-or-infinity-008.html "css/css-sizing/aspect-ratio/zero-or-infinity-008.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/zero-or-infinity-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/zero-or-infinity-008.html)
- [zero-or-infinity-009.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/zero-or-infinity-009.html "css/css-sizing/aspect-ratio/zero-or-infinity-009.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/zero-or-infinity-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/zero-or-infinity-009.html)
- [zero-or-infinity-010.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/zero-or-infinity-010.html "css/css-sizing/aspect-ratio/zero-or-infinity-010.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/zero-or-infinity-010.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/zero-or-infinity-010.html)

This property sets a [preferred aspect ratio] for the box, which will be
used in the calculation of
[auto](https://drafts.csswg.org/css-sizing-3/#valdef-width-auto) sizes and some other layout functions.

[auto]
: [Replaced
 elements](https://drafts.csswg.org/css-display-4/#replaced-element) with a [natural aspect
 ratio](https://drafts.csswg.org/css-images-3/#natural-aspect-ratio) use that aspect ratio; otherwise the box has no
 [preferred aspect
 ratio](#preferred-aspect-ratio). Size calculations involving the aspect ratio work
 with the [content
 box](https://drafts.csswg.org/css-box-4/#content-box) dimensions always.

[[\<ratio\>](https://drafts.csswg.org/css-values-4/#ratio-value)]

: The box's [preferred aspect
 ratio](#preferred-aspect-ratio) is the specified ratio of [`width` /
 `height`]. Size calculations involving the aspect
 ratio work with the dimensions of the box specified by
 [box-sizing](https://drafts.csswg.org/css-sizing-3/#propdef-box-sizing).

 If the
 [\<ratio\>](https://drafts.csswg.org/css-values-4/#ratio-value) is
 [degenerate](https://drafts.csswg.org/css-values-4/#degenerate-ratio), the property instead behaves as
 [auto](#valdef-aspect-ratio-auto).

[auto && [\<ratio\>](https://drafts.csswg.org/css-values-4/#ratio-value)]

: If both
 [auto](#valdef-aspect-ratio-auto) and a
 [\<ratio\>](https://drafts.csswg.org/css-values-4/#ratio-value) are specified together, the
 [preferred aspect
 ratio](#preferred-aspect-ratio) is the specified ratio of [`width` /
 `height`] unless it is a [replaced
 element](https://drafts.csswg.org/css-display-4/#replaced-element) with a [natural aspect
 ratio](https://drafts.csswg.org/css-images-3/#natural-aspect-ratio), in which case that aspect ratio is used instead.
 In all cases, size calculations involving the aspect ratio work with
 the [content
 box](https://drafts.csswg.org/css-box-4/#content-box) dimensions always.

 If the
 [\<ratio\>](https://drafts.csswg.org/css-values-4/#ratio-value) is
 [degenerate](https://drafts.csswg.org/css-values-4/#degenerate-ratio), the property instead behaves as
 [auto](#valdef-aspect-ratio-auto).

 Tests

 - [block-aspect-ratio-050.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/block-aspect-ratio-050.html "css/css-sizing/aspect-ratio/block-aspect-ratio-050.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/block-aspect-ratio-050.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/block-aspect-ratio-050.html)

 Having a [preferred aspect
ratio](#preferred-aspect-ratio) does not make a box into a [replaced
element](https://drafts.csswg.org/css-display-4/#replaced-element); layout rules specific to [replaced
elements] do not generally apply to
[non-replaced](https://drafts.csswg.org/css-display-4/#non-replaced) boxes with a [preferred aspect
ratio]. For example, a
[non-replaced]
[absolutely-positioned](https://drafts.csswg.org/css-position-3/#absolute-position) box treats [justify-self:
normal](https://drafts.csswg.org/css-align-3/#propdef-justify-self) as
[stretch](https://drafts.csswg.org/css-align-3/#valdef-justify-self-stretch), not as
[start](https://drafts.csswg.org/css-align-3/#valdef-self-position-start) ([CSS Box Alignment 3 § 6.1.2
Absolutely-Positioned
Boxes](https://drafts.csswg.org/css-align-3/#justify-abspos)), even if
it has a [preferred aspect ratio]

CSS2.1 does not cleanly differentiate
between replaced elements vs. elements with an aspect ratio; need to
figure out specific cases that are unclear and define them, either in
the appropriate Level 3 spec or here.

This example sets each item in the
grid to render as a square, determining the number of items and their
widths by the available space.

``` highlight
<ul>
 <li>…
 <li>…
 <li>…
 <li>…
</ul>
```

``` highlight
ul {
 display: grid;
 grid-template-columns: repeat(auto-fill, minmax(12em, 1fr));
}
li {
 aspect-ratio: 1/1;
 overflow: auto;
}
```

This example uses the
[`iframe`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-iframe-element) element's `width` and `height` attributes to set
the [aspect-ratio](#propdef-aspect-ratio) property, giving the iframe an
aspect ratio to use for sizing so that it behaves exactly like an image
with that aspect ratio.

``` highlight
<iframe
 src="https://www.youtube.com/embed/0Gr1XSyxZy0"
 width=560
 height=315>
```

``` highlight
@supports (aspect-ratio: attr(width number) / 1) {
 iframe {
 aspect-ratio: attr(width number) / attr(height number);
 width: 100%;
 height: auto;
 }
}
```

If a replaced element's only [natural
dimension](https://drafts.csswg.org/css-images-3/#natural-dimensions) is a [natural
width](https://drafts.csswg.org/css-images-3/#natural-width) or a [natural
height](https://drafts.csswg.org/css-images-3/#natural-height), giving it a [preferred aspect
ratio](#preferred-aspect-ratio) also gives it an
[natural] height or width, whichever was
missing, by transferring the existing size through the [preferred aspect
ratio].

### 4.2. Effects of Preferred Aspect Ratio on Automatic Sizes

When a box has a [preferred aspect
ratio](#preferred-aspect-ratio), its [automatic
sizes](https://drafts.csswg.org/css-sizing-3/#automatic-size) are calculated the same as for a [replaced
element](https://drafts.csswg.org/css-display-4/#replaced-element) with a [natural aspect
ratio](https://drafts.csswg.org/css-images-3/#natural-aspect-ratio) and no [natural
size](https://drafts.csswg.org/css-images-3/#natural-size) in that axis, see e.g. [CSS2
§ 10](https://www.w3.org/TR/CSS2/visudet.html) and [CSS Flexible Box
Model Level 1
§ 9.2](https://www.w3.org/TR/css-flexbox-1/#algo-main-item). The axis in
which the [preferred
size](https://drafts.csswg.org/css-sizing-3/#preferred-size) calculation depends on this aspect ratio is called the
[ratio-dependent axis], and the resulting size is
[definite](https://drafts.csswg.org/css-sizing-3/#definite) if its input sizes are also
[definite]. The opposite axis (on which the
[ratio-dependent
axis](#ratio-dependent-axis) size depends) is the [ratio-determining
axis].

 A [preferred aspect
ratio](#preferred-aspect-ratio) only ever has an effect if at least one of the box's
sizes is
[automatic](https://drafts.csswg.org/css-sizing-3/#automatic-size). If neither
[width](https://drafts.csswg.org/css-sizing-3/#propdef-width) nor
[height](https://drafts.csswg.org/css-sizing-3/#propdef-height) is an [automatic
size], it can have no effect on its [preferred
sizes](https://drafts.csswg.org/css-sizing-3/#preferred-size).

When we move all the sizing information
here, rather than crowbar-ing our way into 2.1, then the core principle
here is just: the resolved [preferred
size](https://drafts.csswg.org/css-sizing-3/#preferred-size) in the ratio-determining axis (before applying min/max)
gets transferred thru the ratio. Min/max constraints get transferred
afterwards, and then applied to each axis independently without regards
to aspect-ratio.

Tests

- [flex-aspect-ratio-031.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/flex-aspect-ratio-031.html "css/css-sizing/aspect-ratio/flex-aspect-ratio-031.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/flex-aspect-ratio-031.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/flex-aspect-ratio-031.html)
- [grid-aspect-ratio-align-items-center.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/grid-aspect-ratio-align-items-center.html "css/css-sizing/aspect-ratio/grid-aspect-ratio-align-items-center.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/grid-aspect-ratio-align-items-center.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/grid-aspect-ratio-align-items-center.html)

#### 4.2.1. Margin-collapsing

For the purpose of margin collapsing ([CSS 2 § 8.3.1 Collapsing
margins](https://www.w3.org/TR/CSS2/box.html#collapsing-margins)), if
the [block
axis](https://drafts.csswg.org/css-writing-modes-4/#block-axis) is the [ratio-dependent
axis](#ratio-dependent-axis), it is not considered to have a
[computed](https://drafts.csswg.org/css-cascade-5/#computed-value)
[block-size](https://drafts.csswg.org/css-logical-1/#propdef-block-size) of
[auto](https://drafts.csswg.org/css-sizing-3/#valdef-width-auto).

### 4.3. Automatic Content-based Minimum Sizes

In order to avoid unintentional overflow, the [automatic minimum
size](https://drafts.csswg.org/css-sizing-3/#automatic-minimum-size) in the [ratio-dependent
axis](#ratio-dependent-axis) of a box with a [preferred aspect
ratio](#preferred-aspect-ratio) that is neither a [replaced
element](https://drafts.csswg.org/css-display-4/#replaced-element), nor a [scroll
container](https://drafts.csswg.org/css-overflow-3/#scroll-container) in that axis, is its [min-content
size](https://drafts.csswg.org/css-sizing-3/#min-content) capped by its [maximum
size](https://drafts.csswg.org/css-sizing-3/#max-width).

In the following example, the box is
as wide as the container (as usual), and its height is as tall as needed
to contain its content but at least as tall as it is wide.

``` highlight
div {
 aspect-ratio: 1/1;
 /* 'width' and 'height' both default to 'auto' */
}
```

``` figure
+----------+ +----------+ +----------+
| ~~~~~~~~ | | ~~~~~~~~ | | ~~~~~~~~ |
| ~~~~~~~~ | | ~~~~~~~~ | | ~~~~~~~~ |
| ~~~~~~~ | | ~~~~~~~~ | | ~~~~~~~~ |
| | | ~~~ | | ~~~~~~~~ |
+----------+ +----------+ | ~~~~~~~~ |
 | ~~~~~~ |
 +----------+
```

When [overflow:
auto](https://drafts.csswg.org/css-overflow-3/#propdef-overflow) is specified, however, even the box with
excess content maintains the 1:1 aspect ratio (and handles overflow by
becoming scrollable instead, as usual).

``` highlight
div {
 overflow: auto;
 aspect-ratio: 1/1;
}
```

``` figure
+----------+ +----------+ +----------+
| ~~~~~~~~ | | ~~~~~~~~ | | ~~~~~~~~^|
| ~~~~~~~~ | | ~~~~~~~~ | | ~~~~~~~~ |
| ~~~~~~~ | | ~~~~~~~~ | | ~~~~~~~~ |
| | | ~~~ | | ~~~~~~~~v|
+----------+ +----------+ +----------+
```

Overriding the
[min-height](https://drafts.csswg.org/css2/#propdef-min-height) property also maintains the 1:1
aspect ratio, but will result in content overflowing the box if it is
not otherwise handled.

``` highlight
div {
 aspect-ratio: 1/1;
 min-height: 0;
}
```

``` figure
+----------+ +----------+ +----------+
| ~~~~~~~~ | | ~~~~~~~~ | | ~~~~~~~~ |
| ~~~~~~~~ | | ~~~~~~~~ | | ~~~~~~~~ |
| ~~~~~~~ | | ~~~~~~~~ | | ~~~~~~~~ |
| | | ~~~ | | ~~~~~~~~ |
+----------+ +----------+ +-~~~~~~~~-+
  ~~~~~~  
```

This automatic minimum operates in
both axes. Consider this example:

``` highlight
<div style="height: 100px; aspect-ratio: 1/1;">
 <span style="display: inline-block; width: 50px;"></span>
 <span style="display: inline-block; width: 150px;"></span>
</div>
```

The
[width](https://drafts.csswg.org/css-sizing-3/#propdef-width) of the container, being
[auto](https://drafts.csswg.org/css-sizing-3/#valdef-width-auto), resolves through the aspect ratio to 100px.
However, its
[min-width](https://drafts.csswg.org/css2/#propdef-min-width), being
[auto], resolves to 150px. The
resulting width of the container is thus 150px. To ignore the contents
when sizing the container, [min-width: 0] can be specified.

- [block-aspect-ratio-038.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/block-aspect-ratio-038.html "css/css-sizing/aspect-ratio/block-aspect-ratio-038.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/block-aspect-ratio-038.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/block-aspect-ratio-038.html)
- [block-aspect-ratio-039.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/block-aspect-ratio-039.html "css/css-sizing/aspect-ratio/block-aspect-ratio-039.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/block-aspect-ratio-039.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/block-aspect-ratio-039.html)
- [fieldset-element-001.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/fieldset-element-001.html "css/css-sizing/aspect-ratio/fieldset-element-001.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/fieldset-element-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/fieldset-element-001.html)
- [fieldset-element-002.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/fieldset-element-002.html "css/css-sizing/aspect-ratio/fieldset-element-002.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/fieldset-element-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/fieldset-element-002.html)
- [flex-aspect-ratio-002.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/flex-aspect-ratio-002.html "css/css-sizing/aspect-ratio/flex-aspect-ratio-002.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/flex-aspect-ratio-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/flex-aspect-ratio-002.html)
- [flex-aspect-ratio-004.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/flex-aspect-ratio-004.html "css/css-sizing/aspect-ratio/flex-aspect-ratio-004.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/flex-aspect-ratio-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/flex-aspect-ratio-004.html)
- [flex-aspect-ratio-025.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/flex-aspect-ratio-025.html "css/css-sizing/aspect-ratio/flex-aspect-ratio-025.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/flex-aspect-ratio-025.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/flex-aspect-ratio-025.html)
- [flex-aspect-ratio-026.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/flex-aspect-ratio-026.html "css/css-sizing/aspect-ratio/flex-aspect-ratio-026.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/flex-aspect-ratio-026.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/flex-aspect-ratio-026.html)
- [flex-aspect-ratio-040.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/flex-aspect-ratio-040.html "css/css-sizing/aspect-ratio/flex-aspect-ratio-040.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/flex-aspect-ratio-040.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/flex-aspect-ratio-040.html)
- [flex-aspect-ratio-041.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/flex-aspect-ratio-041.html "css/css-sizing/aspect-ratio/flex-aspect-ratio-041.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/flex-aspect-ratio-041.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/flex-aspect-ratio-041.html)
- [flex-aspect-ratio-042.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/flex-aspect-ratio-042.html "css/css-sizing/aspect-ratio/flex-aspect-ratio-042.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/flex-aspect-ratio-042.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/flex-aspect-ratio-042.html)
- [flex-aspect-ratio-043.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/flex-aspect-ratio-043.html "css/css-sizing/aspect-ratio/flex-aspect-ratio-043.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/flex-aspect-ratio-043.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/flex-aspect-ratio-043.html)
- [flex-aspect-ratio-044.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/flex-aspect-ratio-044.html "css/css-sizing/aspect-ratio/flex-aspect-ratio-044.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/flex-aspect-ratio-044.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/flex-aspect-ratio-044.html)
- [grid-aspect-ratio-039.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/grid-aspect-ratio-039.html "css/css-sizing/aspect-ratio/grid-aspect-ratio-039.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/grid-aspect-ratio-039.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/grid-aspect-ratio-039.html)
- [grid-aspect-ratio-042.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/grid-aspect-ratio-042.html "css/css-sizing/aspect-ratio/grid-aspect-ratio-042.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/grid-aspect-ratio-042.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/grid-aspect-ratio-042.html)
- [intrinsic-size-010.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/intrinsic-size-010.html "css/css-sizing/aspect-ratio/intrinsic-size-010.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/intrinsic-size-010.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/intrinsic-size-010.html)

### 4.4. Min/Max Size Transfers

Sizing constraints in either axis (the `origin` axis) are
transferred through the [preferred aspect
ratio](#preferred-aspect-ratio) and applied to any
[indefinite](https://drafts.csswg.org/css-sizing-3/#indefinite)
[minimum](https://drafts.csswg.org/css-sizing-3/#min-width),
[maximum](https://drafts.csswg.org/css-sizing-3/#max-width), or
[preferred](https://drafts.csswg.org/css-sizing-3/#preferred-size) size in the other axis (the `destination`
axis) as follows:

- First, any
 [definite](https://drafts.csswg.org/css-sizing-3/#definite) [minimum
 size](https://drafts.csswg.org/css-sizing-3/#min-width) is converted and transferred from the
 `origin` to `destination` axis. This transferred
 minimum is capped by any [definite]
 [preferred](https://drafts.csswg.org/css-sizing-3/#preferred-size) or [maximum
 size](https://drafts.csswg.org/css-sizing-3/#max-width) in the `destination` axis.

- Then, any
 [definite](https://drafts.csswg.org/css-sizing-3/#definite) [maximum
 size](https://drafts.csswg.org/css-sizing-3/#max-width) is converted and transferred from the
 `origin` to `destination`. This transferred
 maximum is floored by any [definite]
 [preferred](https://drafts.csswg.org/css-sizing-3/#preferred-size) or [minimum
 size](https://drafts.csswg.org/css-sizing-3/#min-width) in the `destination` axis as well as by
 the transferred minimum, if any.

 Thus, any definite sizes are completely unaffected by a
transferred constraint; and a transferred minimum will never cause an
element to exceed a definite preferred/maximum size, nor will a
transferred maximum cause an element to violate its preferred/minimum
size.

 The basic principle is that sizing constraints transfer
through the aspect-ratio to the other side to preserve the aspect ratio
to the extent that they can without violating any sizes specified
explicitly on that affected axis. (This is the principle that drove the
contents of the [constraint table in CSS2 Section
10.4](https://www.w3.org/TR/CSS2/visudet.html#min-max-widths).)

In the following example:

``` highlight
<div id=container style="height: 100px; float: left;">
 <div id=item style="height: 100%; aspect-ratio: 1/1;">content</div>
</div>
```

Since the height of the `#item` is a percentage that resolves against a
definite container, the width of the item resolves to 100px for both its
intrinsic size contributions as well as for final layout, so the
container also sizes to a width of 100px.

``` highlight
<div id=container style="height: auto; float: left;">
 <div id=item style="height: 100%; aspect-ratio: 1/1;">content</div>
</div>
```

In this next example, the percentage height of the item cannot be
resolved and [behaves as
auto](https://drafts.csswg.org/css-sizing-3/#behave-as-auto) (see [CSS 2 § 10.5 Content height: the \'height\'
property](https://www.w3.org/TR/CSS2/visudet.html#the-height-property)).
Since both axes now have an [automatic
size](https://drafts.csswg.org/css-sizing-3/#automatic-size), the height becomes the [ratio-dependent
axis](#ratio-dependent-axis). Calculating the [intrinsic size
contributions](https://drafts.csswg.org/css-sizing-3/#intrinsic-size-contribution) of the box produces a width derived from its content,
and a height calculated from that width and the aspect ratio, yielding a
square box (and a container) sized to the width of the word "content".

- [replaced-element-032.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/replaced-element-032.html "css/css-sizing/aspect-ratio/replaced-element-032.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/replaced-element-032.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/replaced-element-032.html)
- [replaced-element-033.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/replaced-element-033.html "css/css-sizing/aspect-ratio/replaced-element-033.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/replaced-element-033.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/replaced-element-033.html)
- [block-aspect-ratio-040.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/block-aspect-ratio-040.html "css/css-sizing/aspect-ratio/block-aspect-ratio-040.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/block-aspect-ratio-040.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/block-aspect-ratio-040.html)
- [block-aspect-ratio-041.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/block-aspect-ratio-041.html "css/css-sizing/aspect-ratio/block-aspect-ratio-041.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/block-aspect-ratio-041.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/block-aspect-ratio-041.html)
- [block-aspect-ratio-042.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/block-aspect-ratio-042.html "css/css-sizing/aspect-ratio/block-aspect-ratio-042.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/block-aspect-ratio-042.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/block-aspect-ratio-042.html)
- [block-aspect-ratio-043.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/block-aspect-ratio-043.html "css/css-sizing/aspect-ratio/block-aspect-ratio-043.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/block-aspect-ratio-043.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/block-aspect-ratio-043.html)
- [block-aspect-ratio-044.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/block-aspect-ratio-044.html "css/css-sizing/aspect-ratio/block-aspect-ratio-044.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/block-aspect-ratio-044.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/block-aspect-ratio-044.html)
- [block-aspect-ratio-045.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/block-aspect-ratio-045.html "css/css-sizing/aspect-ratio/block-aspect-ratio-045.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/block-aspect-ratio-045.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/block-aspect-ratio-045.html)
- [block-aspect-ratio-046.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/block-aspect-ratio-046.html "css/css-sizing/aspect-ratio/block-aspect-ratio-046.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/block-aspect-ratio-046.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/block-aspect-ratio-046.html)
- [block-aspect-ratio-047.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/block-aspect-ratio-047.html "css/css-sizing/aspect-ratio/block-aspect-ratio-047.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/block-aspect-ratio-047.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/block-aspect-ratio-047.html)
- [block-aspect-ratio-048.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/block-aspect-ratio-048.html "css/css-sizing/aspect-ratio/block-aspect-ratio-048.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/block-aspect-ratio-048.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/block-aspect-ratio-048.html)
- [block-aspect-ratio-049.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/block-aspect-ratio-049.html "css/css-sizing/aspect-ratio/block-aspect-ratio-049.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/block-aspect-ratio-049.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/block-aspect-ratio-049.html)
- [flex-aspect-ratio-039.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/flex-aspect-ratio-039.html "css/css-sizing/aspect-ratio/flex-aspect-ratio-039.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/flex-aspect-ratio-039.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/flex-aspect-ratio-039.html)
- [replaced-element-039.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/replaced-element-039.html "css/css-sizing/aspect-ratio/replaced-element-039.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/replaced-element-039.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/replaced-element-039.html)
- [replaced-element-040.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/replaced-element-040.html "css/css-sizing/aspect-ratio/replaced-element-040.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/replaced-element-040.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/replaced-element-040.html)
- [replaced-element-041.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/replaced-element-041.html "css/css-sizing/aspect-ratio/replaced-element-041.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/replaced-element-041.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/replaced-element-041.html)
- [replaced-element-043.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/replaced-element-043.html "css/css-sizing/aspect-ratio/replaced-element-043.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/replaced-element-043.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/replaced-element-043.html)
- [replaced-element-044.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/replaced-element-044.html "css/css-sizing/aspect-ratio/replaced-element-044.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/replaced-element-044.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/replaced-element-044.html)
- [image-max-width-and-height-behaves-as-auto.html](https://wpt.fyi/results/css/css-sizing/image-max-width-and-height-behaves-as-auto.html "css/css-sizing/image-max-width-and-height-behaves-as-auto.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/image-max-width-and-height-behaves-as-auto.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/image-max-width-and-height-behaves-as-auto.html)
- [min-max-content-orthogonal-flow-crash-001.html](https://wpt.fyi/results/css/css-sizing/min-max-content-orthogonal-flow-crash-001.html "css/css-sizing/min-max-content-orthogonal-flow-crash-001.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/min-max-content-orthogonal-flow-crash-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/min-max-content-orthogonal-flow-crash-001.html)

This section might not be written
correctly. [\[Issue
#6071\]](https://github.com/w3c/csswg-drafts/issues/6071)

## 5. Intrinsic Size Determination

### 5.1. Intrinsic Sizes

(#issue-d41d8cd9③) [CSS Sizing 3 § 5.1 Intrinsic
Sizes](https://drafts.csswg.org/css-sizing-3/#intrinsic-sizes)

### [5.2. ][ Overriding Contained Intrinsic Sizes: the [contain-intrinsic-\*] properties]
Name:

[contain-intrinsic-width],
[contain-intrinsic-height],
[contain-intrinsic-block-size],
[contain-intrinsic-inline-size]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

auto[?](https://drafts.csswg.org/css-values-4/#mult-opt) \[ none
[\|](https://drafts.csswg.org/css-values-4/#comb-one) [\<length
\[0,∞\]\>](https://drafts.csswg.org/css-values-4/#length-value) \]

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

none

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

elements with [size
containment](https://drafts.csswg.org/css-contain-2/#size-containment)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

as specified, with
[\<length\>](https://drafts.csswg.org/css-values-4/#length-value) values computed

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value type

[Logical property
group:](https://drafts.csswg.org/css-logical-1/#logical-property-group)

[contain-intrinsic-size](#propdef-contain-intrinsic-size)

Tests

- [auto-014.html](https://wpt.fyi/results/css/css-sizing/contain-intrinsic-size/auto-014.html "css/css-sizing/contain-intrinsic-size/auto-014.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/contain-intrinsic-size/auto-014.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/contain-intrinsic-size/auto-014.html)
- [auto-015.html](https://wpt.fyi/results/css/css-sizing/contain-intrinsic-size/auto-015.html "css/css-sizing/contain-intrinsic-size/auto-015.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/contain-intrinsic-size/auto-015.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/contain-intrinsic-size/auto-015.html)
- [auto-016.html](https://wpt.fyi/results/css/css-sizing/contain-intrinsic-size/auto-016.html "css/css-sizing/contain-intrinsic-size/auto-016.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/contain-intrinsic-size/auto-016.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/contain-intrinsic-size/auto-016.html)
- [auto-017.html](https://wpt.fyi/results/css/css-sizing/contain-intrinsic-size/auto-017.html "css/css-sizing/contain-intrinsic-size/auto-017.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/contain-intrinsic-size/auto-017.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/contain-intrinsic-size/auto-017.html)
- [auto-018.html](https://wpt.fyi/results/css/css-sizing/contain-intrinsic-size/auto-018.html "css/css-sizing/contain-intrinsic-size/auto-018.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/contain-intrinsic-size/auto-018.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/contain-intrinsic-size/auto-018.html)
- [contain-intrinsic-size-001.html](https://wpt.fyi/results/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-001.html "css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-001.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-001.html)
- [contain-intrinsic-size-002.html](https://wpt.fyi/results/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-002.html "css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-002.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-002.html)
- [contain-intrinsic-size-003.html](https://wpt.fyi/results/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-003.html "css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-003.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-003.html)
- [contain-intrinsic-size-004.html](https://wpt.fyi/results/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-004.html "css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-004.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-004.html)
- [contain-intrinsic-size-005.html](https://wpt.fyi/results/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-005.html "css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-005.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-005.html)
- [contain-intrinsic-size-006.html](https://wpt.fyi/results/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-006.html "css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-006.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-006.html)
- [contain-intrinsic-size-007.html](https://wpt.fyi/results/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-007.html "css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-007.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-007.html)
- [contain-intrinsic-size-008.html](https://wpt.fyi/results/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-008.html "css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-008.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-008.html)
- [contain-intrinsic-size-009.html](https://wpt.fyi/results/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-009.html "css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-009.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-009.html)
- [contain-intrinsic-size-010.html](https://wpt.fyi/results/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-010.html "css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-010.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-010.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-010.html)
- [contain-intrinsic-size-011.html](https://wpt.fyi/results/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-011.html "css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-011.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-011.html)
- [contain-intrinsic-size-012.html](https://wpt.fyi/results/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-012.html "css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-012.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-012.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-012.html)
- [contain-intrinsic-size-013.html](https://wpt.fyi/results/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-013.html "css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-013.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-013.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-013.html)
- [contain-intrinsic-size-014.html](https://wpt.fyi/results/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-014.html "css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-014.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-014.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-014.html)
- [contain-intrinsic-size-015.html](https://wpt.fyi/results/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-015.html "css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-015.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-015.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-015.html)
- [contain-intrinsic-size-016.html](https://wpt.fyi/results/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-016.html "css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-016.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-016.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-016.html)
- [contain-intrinsic-size-017.html](https://wpt.fyi/results/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-017.html "css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-017.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-017.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-017.html)
- [contain-intrinsic-size-018.html](https://wpt.fyi/results/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-018.html "css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-018.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-018.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-018.html)
- [contain-intrinsic-size-019.html](https://wpt.fyi/results/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-019.html "css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-019.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-019.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-019.html)
- [contain-intrinsic-size-020.html](https://wpt.fyi/results/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-020.html "css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-020.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-020.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-020.html)
- [contain-intrinsic-size-021.html](https://wpt.fyi/results/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-021.html "css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-021.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-021.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-021.html)
- [contain-intrinsic-size-022.html](https://wpt.fyi/results/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-022.html "css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-022.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-022.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-022.html)
- [contain-intrinsic-size-023.html](https://wpt.fyi/results/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-023.html "css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-023.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-023.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-023.html)
- [contain-intrinsic-size-024.html](https://wpt.fyi/results/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-024.html "css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-024.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-024.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-024.html)
- [contain-intrinsic-size-025.html](https://wpt.fyi/results/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-025.html "css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-025.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-025.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-025.html)
- [contain-intrinsic-size-026.html](https://wpt.fyi/results/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-026.html "css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-026.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-026.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-026.html)
- [contain-intrinsic-size-027.html](https://wpt.fyi/results/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-027.html "css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-027.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-027.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-027.html)
- [contain-intrinsic-size-028.html](https://wpt.fyi/results/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-028.html "css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-028.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-028.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-028.html)
- [contain-intrinsic-size-029.html](https://wpt.fyi/results/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-029.html "css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-029.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-029.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-029.html)
- [contain-intrinsic-size-030.html](https://wpt.fyi/results/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-030.html "css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-030.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-030.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-030.html)
- [contain-intrinsic-size-031.html](https://wpt.fyi/results/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-031.html "css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-031.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-031.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-031.html)
- [contain-intrinsic-size-032.html](https://wpt.fyi/results/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-032.html "css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-032.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-032.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-032.html)
- [contain-intrinsic-size-logical-001.html](https://wpt.fyi/results/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-logical-001.html "css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-logical-001.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-logical-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-logical-001.html)
- [contain-intrinsic-size-logical-002.html](https://wpt.fyi/results/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-logical-002.html "css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-logical-002.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-logical-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-logical-002.html)
- [contain-intrinsic-size-logical-003.html](https://wpt.fyi/results/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-logical-003.html "css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-logical-003.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-logical-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-logical-003.html)
- [forget-on-disconnect-in-iframe.html](https://wpt.fyi/results/css/css-sizing/contain-intrinsic-size/forget-on-disconnect-in-iframe.html "css/css-sizing/contain-intrinsic-size/forget-on-disconnect-in-iframe.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/contain-intrinsic-size/forget-on-disconnect-in-iframe.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/contain-intrinsic-size/forget-on-disconnect-in-iframe.html)
- [contain-intrinsic-size-computed.html](https://wpt.fyi/results/css/css-sizing/contain-intrinsic-size/parsing/contain-intrinsic-size-computed.html "css/css-sizing/contain-intrinsic-size/parsing/contain-intrinsic-size-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/contain-intrinsic-size/parsing/contain-intrinsic-size-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/contain-intrinsic-size/parsing/contain-intrinsic-size-computed.html)
- [contain-intrinsic-size-invalid.html](https://wpt.fyi/results/css/css-sizing/contain-intrinsic-size/parsing/contain-intrinsic-size-invalid.html "css/css-sizing/contain-intrinsic-size/parsing/contain-intrinsic-size-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/contain-intrinsic-size/parsing/contain-intrinsic-size-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/contain-intrinsic-size/parsing/contain-intrinsic-size-invalid.html)
- [contain-intrinsic-size-valid.html](https://wpt.fyi/results/css/css-sizing/contain-intrinsic-size/parsing/contain-intrinsic-size-valid.html "css/css-sizing/contain-intrinsic-size/parsing/contain-intrinsic-size-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/contain-intrinsic-size/parsing/contain-intrinsic-size-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/contain-intrinsic-size/parsing/contain-intrinsic-size-valid.html)

These properties allow elements with [size
containment](https://drafts.csswg.org/css-contain-2/#size-containment) to specify an [explicit intrinsic inner
size], causing the box to size as if its
[in-flow](https://drafts.csswg.org/css-display-4/#in-flow) content totals to a width and height matching the
specified [explicit intrinsic inner
size](#explicit-intrinsic-inner-size) (rather than sizing as if it were empty).

 This is not always equivalent to laying out as if the
element had one child of the specified [explicit intrinsic inner
size](#explicit-intrinsic-inner-size). For example, a [grid
container](https://drafts.csswg.org/css-grid-2/#grid-container) with one child of the specified size would still size
according to the specified grid, usually ending up with a larger content
size than specified.

Tests

- [contain-intrinsic-size-033.html](https://wpt.fyi/results/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-033.html "css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-033.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-033.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/contain-intrinsic-size/contain-intrinsic-size-033.html)

[none] \| [[\<length\>](https://drafts.csswg.org/css-values-4/#length-value)]

: If no other
 [contain-intrinsic-size](#propdef-contain-intrinsic-size) value (such as
 [auto](#valdef-contain-intrinsic-width-auto)) is providing an [explicit intrinsic inner
 size](#explicit-intrinsic-inner-size), the corresponding axis either doesn't have an
 [explicit intrinsic inner
 size] (if
 [none](#valdef-contain-intrinsic-width-none) is specified) or has an [explicit intrinsic
 inner size] of the
 specified
 [\<length\>](https://drafts.csswg.org/css-values-4/#length-value).

[auto]

: If
 [auto](#valdef-contain-intrinsic-width-auto) is specified and the element has a [last
 remembered size](#last-remembered) and is currently [skipping its
 contents](https://drafts.csswg.org/css-contain-2/#skips-its-contents), its [explicit intrinsic inner
 size](#explicit-intrinsic-inner-size) in the corresponding axis is the [last remembered
 size] in that axis.

 This occurs, for example, when an element with
 [content-visibility:
 auto](https://drafts.csswg.org/css-contain-2/#propdef-content-visibility) is off-screen.

 Tests

 - [content-visibility-058.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-058.html "css/css-contain/content-visibility/content-visibility-058.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-058.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-058.html)

If an element has an [explicit intrinsic inner
size](#explicit-intrinsic-inner-size) in an axis, then after laying out the element as normal
for [size
containment](https://drafts.csswg.org/css-contain-2/#size-containment), the size of the contents in that axis are instead
treated as being the [explicit intrinsic inner
size] instead of what was
calculated in layout, and layout is performed again if necessary. (If it
has an [explicit intrinsic inner
size] in both axises, this
implies the first layout can be skipped.)

These four properties are part of a [logical property
group](https://drafts.csswg.org/css-logical-1/#logical-property-group).

 An element with [size
containment](https://drafts.csswg.org/css-contain-2/#size-containment) is laid out as if it had no contents
[\[CSS-CONTAIN-1\]](#biblio-css-contain-1 "CSS Containment Module Level 1"),
which in many cases this will cause the element to collapse to zero
inner height. This can be corrected with an explicit
[height](https://drafts.csswg.org/css-sizing-3/#propdef-height) chosen to show the expected
contents, but that can have unintended effects in some layout systems,
such as Flex and Grid Layout, which treat an explicit
[height] as a stronger command than
an implicit content-based height. The element thus might lay out
substantially differently than it would have were it simply filled with
content up to that height. Providing an [explicit intrinsic inner
size](#explicit-intrinsic-inner-size) for the element preserves the performance benefits of
ignoring its contents for layout while still allowing it to size as if
it had content.

Name:

[contain-intrinsic-size]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

\[
auto[?](https://drafts.csswg.org/css-values-4/#mult-opt) \[ none
[\|](https://drafts.csswg.org/css-values-4/#comb-one) [\<length
\[0,∞\]\>](https://drafts.csswg.org/css-values-4/#length-value) \]
\][{1,2}](https://drafts.csswg.org/css-values-4/#mult-num-range)

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

- [contain-intrinsic-size-interpolation.html](https://wpt.fyi/results/css/css-sizing/contain-intrinsic-size/animation/contain-intrinsic-size-interpolation.html "css/css-sizing/contain-intrinsic-size/animation/contain-intrinsic-size-interpolation.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/contain-intrinsic-size/animation/contain-intrinsic-size-interpolation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/contain-intrinsic-size/animation/contain-intrinsic-size-interpolation.html)

[contain-intrinsic-size](#propdef-contain-intrinsic-size) is a shorthand property that sets
the
[contain-intrinsic-width](#propdef-contain-intrinsic-width) and
[contain-intrinsic-height](#propdef-contain-intrinsic-height) properties.

The first value represents the
[contain-intrinsic-width](#propdef-contain-intrinsic-width) value, and the second represents
the
[contain-intrinsic-height](#propdef-contain-intrinsic-height) value. If only one value is given,
it applies to both properties.

#### 5.2.1. Last Remembered Size

[Size
containment](https://drafts.csswg.org/css-contain-2/#size-containment) is very valuable for ensuring a page can render
efficiently, restricting the scope of layout work that can happen as a
result of an element changing its rendering. However, it's also very
restrictive for the author, requiring them to correctly predict what the
size of the element will be; if this guess is incorrect, even slightly,
it can cause unsightly scrollbars or accidentally-hidden content.

The
[auto](#valdef-contain-intrinsic-width-auto) keyword of [contain-intrinsic-size] allows
a middle-ground: if an element is ever *not*
[size-contained](https://drafts.csswg.org/css-contain-2/#size-containment), this value causes the element to remember its size
(calculated as normal by layout); then, if the element gains [size
containment] later, it will use the
remembered size, offering the performance benefits of [size
containment] while *probably* sizing
accurately to its contents.

Only elements capable of being
[`ResizeObserver`](https://drafts.csswg.org/resize-observer-1/#resizeobserver) targets can have a [last remembered
size](#last-remembered).

The [last remembered size](#last-remembered) of an element is determined by:

- At the time that
 [`ResizeObserver`](https://drafts.csswg.org/resize-observer-1/#resizeobserver) events are determined and delivered, if an element
 has a
 [auto](#valdef-contain-intrinsic-width-auto) keyword in [contain-intrinsic-size]
 property, is capable of being a
 [`ResizeObserver`](https://drafts.csswg.org/resize-observer-1/#resizeobserver) target, but does not have [size
 containment](https://drafts.csswg.org/css-contain-2/#size-containment), record the current inner dimensions of its
 [principal
 box](https://drafts.csswg.org/css-display-4/#principal-box) as its [last remembered
 size](#last-remembered).

- At the time that
 [`ResizeObserver`](https://drafts.csswg.org/resize-observer-1/#resizeobserver) events are determined and delivered, if an element
 has a [last remembered
 size](#last-remembered) but
 does *not* have
 [auto](#valdef-contain-intrinsic-width-auto) keyword in [contain-intrinsic-size]
 property, remove its [last remembered
 size].

 The [last remembered
size](#last-remembered) is
state attached to the *element*, not any particular box generated by the
element. So long as the element retains
[auto](#valdef-contain-intrinsic-width-auto) keyword in [contain-intrinsic-size]
property, it will remember its [last remembered
size] even across changes such as going
to/from [display:
none](https://drafts.csswg.org/css-display-4/#propdef-display).

- [auto-001.html](https://wpt.fyi/results/css/css-sizing/contain-intrinsic-size/auto-001.html "css/css-sizing/contain-intrinsic-size/auto-001.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/contain-intrinsic-size/auto-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/contain-intrinsic-size/auto-001.html)
- [auto-002.html](https://wpt.fyi/results/css/css-sizing/contain-intrinsic-size/auto-002.html "css/css-sizing/contain-intrinsic-size/auto-002.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/contain-intrinsic-size/auto-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/contain-intrinsic-size/auto-002.html)
- [auto-003.html](https://wpt.fyi/results/css/css-sizing/contain-intrinsic-size/auto-003.html "css/css-sizing/contain-intrinsic-size/auto-003.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/contain-intrinsic-size/auto-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/contain-intrinsic-size/auto-003.html)
- [auto-004.html](https://wpt.fyi/results/css/css-sizing/contain-intrinsic-size/auto-004.html "css/css-sizing/contain-intrinsic-size/auto-004.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/contain-intrinsic-size/auto-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/contain-intrinsic-size/auto-004.html)
- [auto-005.html](https://wpt.fyi/results/css/css-sizing/contain-intrinsic-size/auto-005.html "css/css-sizing/contain-intrinsic-size/auto-005.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/contain-intrinsic-size/auto-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/contain-intrinsic-size/auto-005.html)
- [auto-006.html](https://wpt.fyi/results/css/css-sizing/contain-intrinsic-size/auto-006.html "css/css-sizing/contain-intrinsic-size/auto-006.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/contain-intrinsic-size/auto-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/contain-intrinsic-size/auto-006.html)
- [auto-007.html](https://wpt.fyi/results/css/css-sizing/contain-intrinsic-size/auto-007.html "css/css-sizing/contain-intrinsic-size/auto-007.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/contain-intrinsic-size/auto-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/contain-intrinsic-size/auto-007.html)
- [auto-008.html](https://wpt.fyi/results/css/css-sizing/contain-intrinsic-size/auto-008.html "css/css-sizing/contain-intrinsic-size/auto-008.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/contain-intrinsic-size/auto-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/contain-intrinsic-size/auto-008.html)
- [auto-009.html](https://wpt.fyi/results/css/css-sizing/contain-intrinsic-size/auto-009.html "css/css-sizing/contain-intrinsic-size/auto-009.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/contain-intrinsic-size/auto-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/contain-intrinsic-size/auto-009.html)
- [auto-010.html](https://wpt.fyi/results/css/css-sizing/contain-intrinsic-size/auto-010.html "css/css-sizing/contain-intrinsic-size/auto-010.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/contain-intrinsic-size/auto-010.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/contain-intrinsic-size/auto-010.html)
- [auto-011.html](https://wpt.fyi/results/css/css-sizing/contain-intrinsic-size/auto-011.html "css/css-sizing/contain-intrinsic-size/auto-011.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/contain-intrinsic-size/auto-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/contain-intrinsic-size/auto-011.html)
- [auto-012.html](https://wpt.fyi/results/css/css-sizing/contain-intrinsic-size/auto-012.html "css/css-sizing/contain-intrinsic-size/auto-012.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/contain-intrinsic-size/auto-012.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/contain-intrinsic-size/auto-012.html)
- [auto-013.html](https://wpt.fyi/results/css/css-sizing/contain-intrinsic-size/auto-013.html "css/css-sizing/contain-intrinsic-size/auto-013.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/contain-intrinsic-size/auto-013.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/contain-intrinsic-size/auto-013.html)

#### [5.2.2. ][ Interaction With [overflow: auto](https://drafts.csswg.org/css-overflow-3/#propdef-overflow)]
The
[contain-intrinsic-size](#propdef-contain-intrinsic-size) property provides an estimate of
how large the author expects the content of an element to be, but this
estimate is not actual content and does not represent anything that
needs to be shown to the user. Therefore, an element with [overflow:
auto](https://drafts.csswg.org/css-overflow-3/#propdef-overflow) must not generate scrollbars as a consequence
of [contain-intrinsic-size].

However, if
[contain-intrinsic-size](#propdef-contain-intrinsic-size) indicates a size large enough that
the element would generate scrollbars if it contained actual content of
that size, then the element must be *sized* as if it generated those
scrollbar(s) in accordance with such hypothetical content.

In the following example code:

``` highlight
div {
 width: max-content;
 contain-intrinsic-size: 100px 100px;
 overflow: auto;
}
```

The element ends up being [100px] wide and [100px] tall:
[contain-intrinsic-size](#propdef-contain-intrinsic-size) provides the max-content width, and
also the height.

If the element then ended up with content that was [150px] tall,
it would show a vertical scrollbar; if the scrollbar is not overlay, it
will take up some of that [100px] width, leaving a smaller amount
(roughly [84px], typically) for the content to flow into. (See
[CSS Overflow 3 § 5 Scrollbars and
Layout](https://drafts.csswg.org/css-overflow-3/#scrollbar-layout).)

Even though there's now less than [100px] of horizontal space
available for the content, it will not generate a horizontal scrollbar
just because
[contain-intrinsic-size](#propdef-contain-intrinsic-size) indicates a [100px] width;
that would only happen if the actual content had something unbreakable
and wider than the remaining space.

In contrast, in the following example
code:

``` highlight
div {
 width: max-content;
 contain-intrinsic-size: 100px 100px;
 height: 50px;
 overflow: auto;
}
```

The element has a fixed [50px] height, but
[contain-intrinsic-size](#propdef-contain-intrinsic-size) indicates a [100px]
"estimated content height". The element thus assumes that it will need a
vertical scrollbar when it's filled with actual content, resulting in a
max-content width a little more than [100px] (roughly
[116px], typically), to accommodate the estimated [100px] of
max-content width from
[contain-intrinsic-size], and as well as the vertical scrollbar width (roughly
[16px], typically).

However, even though the element reserves space on the assumption of
needing a scrollbar, it will not actually generate one unless the actual
content overflows: if it ends up containing content that's less than
50px tall, no vertical scrollbar will be generated at all, but the
element will still be [116px] wide.

### 5.3. Responsively-sized iframes: the [frame-sizing property]
Name:

[frame-sizing]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

auto
[\|](https://drafts.csswg.org/css-values-4/#comb-one) content-width [\|]
content-height [\|] content-block-size
[\|] content-inline-size

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

auto

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

replaced elements (but see below for details)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

as specified

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

Some [replaced
elements](https://drafts.csswg.org/css-display-4/#replaced-element) can contain \"normal\" flowed content, such as HTML
[`iframe`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-iframe-element)s. For privacy and security reasons, these elements
do not, by default, expose any information about their internal
contents\' sizing to the outside page, instead just using a static,
predetermined intrinsic size, and making their contents scrollable. The
[frame-sizing](#propdef-frame-sizing) property allows these elements to
opt into exposing their actual content size, known as their [internal
layout intrinsic size]. Values have the following meaning:

[auto]

: The element's [internal layout intrinsic
 size](#internal-layout-intrinsic-size), if any, is ignored.

[content-width]\
[content-height]\
[content-block-size]\
[content-inline-size]

: If the element has an [internal layout intrinsic
 size](#internal-layout-intrinsic-size), its [intrinsic
 size](https://drafts.csswg.org/css-sizing-3/#intrinsic-size) takes the corresponding dimension (either width or
 height) from the [internal layout intrinsic
 size]. (The other
 dimension is determined normally.)

 Logical directions resolve based on the [writing
 mode](https://drafts.csswg.org/css-writing-modes-4/#writing-mode) of the element. (Not the embedded document.)

Which elements can have an [internal layout intrinsic
size](#internal-layout-intrinsic-size), and how it's determined, are decided by the [document
language](https://drafts.csswg.org/css2/#doclanguage). In HTML, only
[`iframe`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-iframe-element) elements can have an [internal layout intrinsic
size], and further, only when
the contained document has also opted in via a
`<meta name=responsive-embedded-sizing>` element. (See
[§ 5.3.1 HTML iframe Details](#iframe-frame-sizing).)

When the embedded document has the
following HTML:

``` highlight
<meta name="responsive-embedded-sizing">
<div style="height: 500px"></div>
```

and the embedding document has the following CSS:

``` highlight
iframe {
 frame-sizing: content-height;
}
```

The height of the
[`iframe`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-iframe-element) will initially be the default iframe height
(typically [150px]), but will be updated to [500px] once the
iframe's document loads.

In addition, the internal document can call
[`window.requestResize()`](#dom-window-requestresize) to update its [internal layout intrinsic
size](#internal-layout-intrinsic-size) later.

#### [5.3.1. ][ HTML [`iframe`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-iframe-element) Details]
In HTML, only the
[`iframe`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-iframe-element) element can have an [internal layout intrinsic
size](#internal-layout-intrinsic-size), and only when the
[`iframe`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-iframe-element)'s embedded document has opted in appropriately.

An HTML
[`Document`](https://dom.spec.whatwg.org/#document) object has an [responsive embedded sizing
flag] associated with it, which
is initially unset. It is set to true or false during the initial
document parse, depending on which of the following first occurs:

- If a `<meta name=responsive-embedded-sizing>` element is
 encountered, it is set to true.

- If the
 [`body`](https://html.spec.whatwg.org/multipage/sections.html#the-body-element) element is opened (explicitly or implicitly), or
 inserted into the document by the parser, it is set to false.

Once set to either true or false, the flag will not change its value
again for the lifetime of the
[`Document`](https://dom.spec.whatwg.org/#document).

 Currently, the HTML
[`meta`](https://html.spec.whatwg.org/multipage/semantics.html#meta) element appearing in the
[`head`](https://html.spec.whatwg.org/multipage/semantics.html#the-head-element) of an HTML document is the only way for an embedded
document to opt into this feature in HTML. This means that SVG documents
in
[`iframe`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-iframe-element) cannot do so.

 Due to quirks of the HTML parser, a
[`meta`](https://html.spec.whatwg.org/multipage/semantics.html#meta) element can technically appear *between* the
[`head`](https://html.spec.whatwg.org/multipage/semantics.html#the-head-element) and
[`body`](https://html.spec.whatwg.org/multipage/sections.html#the-body-element) elements, and will be reparented into the
[`head`](https://html.spec.whatwg.org/multipage/semantics.html#the-head-element). This is still a valid location for the
`<meta name=responsive-embedded-sizing>` element, as the
[`body`](https://html.spec.whatwg.org/multipage/sections.html#the-body-element) has not yet been opened. Note that most HTML
elements will implicitly open a
[`body`](https://html.spec.whatwg.org/multipage/sections.html#the-body-element) element even if the
[`body`](https://html.spec.whatwg.org/multipage/sections.html#the-body-element) start tag is not present, and if the document
completely lacks such an element, an empty one is automatically
generated and inserted.

The [internal layout intrinsic
size](#internal-layout-intrinsic-size) is first set by the results of the embedded document's
first layout after it fires its
[`DOMContentLoaded`](https://html.spec.whatwg.org/multipage/indices.html#event-domcontentloaded) event, and again when the
[`load`](https://html.spec.whatwg.org/multipage/indices.html#event-load) event is fired at the
[`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window). Subsequent changes to content, styling or layout of
the embedded document do not automatically affect the [internal layout
intrinsic size], but see
[`requestResize()`](#dom-window-requestresize).

An embedded document can additionally have a [locked embedded ICB
size], which is initially null. If the document's [responsive
embedded sizing
flag](#document-responsive-embedded-sizing-flag) is true when it performs a layout, and its [locked
embedded ICB
size](#locked-embedded-icb-size) is null, it records its current [initial containing
block](https://drafts.csswg.org/css-display-4/#initial-containing-block) size as its [locked embedded ICB
size]. On subsequent layouts, it
uses its [locked embedded ICB size]
instead of calculating its [initial containing
block] size normally.

 This freezing of the ICB reduces the chance of layout
loops (an iframe document sizing to slightly larger than its ICB, then
the parent iframe changing size to match, and the next layout again
making it slightly larger than the ICB, etc to infinity).

Do we want to have a way to force an
iframe to forget its [locked embedded ICB
size](#locked-embedded-icb-size)? Maybe turning
[frame-sizing](#propdef-frame-sizing) off and on again?

Navigating the iframe's document causes it to forget its [locked
embedded ICB
size](#locked-embedded-icb-size). It **does not** forget its [internal layout intrinsic
size](#internal-layout-intrinsic-size) as long as the new document's [responsive embedded
sizing
flag](#document-responsive-embedded-sizing-flag) is unset. Once the flag is set (to true *or* false),
the [internal layout intrinsic
size] is forgotten; if the
flag is set to true, both are then freshly computed as normal.

#### [5.3.2. ][ Extensions to the [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window) Interface]
```
partial interface Window {
 undefined requestResize();
};
```

When [`requestResize()`] is invoked:

1. Let `navigable` be the
 [navigable](https://html.spec.whatwg.org/multipage/document-sequences.html#navigable) that has
 [this](https://webidl.spec.whatwg.org/#this) as its [content
 window](https://html.spec.whatwg.org/multipage/document-sequences.html#content-window). If `navigable` is not a [child
 navigable](https://html.spec.whatwg.org/multipage/document-sequences.html#child-navigable),
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [`NotAllowedError`](https://webidl.spec.whatwg.org/#notallowederror)
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

2. Let `host element` be the [navigable
 container](https://html.spec.whatwg.org/multipage/document-sequences.html#navigable-container) whose [content
 navigable](https://html.spec.whatwg.org/multipage/document-sequences.html#content-navigable) is `navigable`. If
 `host element` is not an HTML
 [`iframe`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-iframe-element) element,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [`NotAllowedError`](https://webidl.spec.whatwg.org/#notallowederror)
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

3. Let `document` be
 [this's](https://webidl.spec.whatwg.org/#this) [active
 document](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-document). If `document`'s [responsive embedded
 sizing
 flag](#document-responsive-embedded-sizing-flag) is unset or false,
 [throw](https://webidl.spec.whatwg.org/#dfn-throw) a
 [`NotAllowedError`](https://webidl.spec.whatwg.org/#notallowederror)
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

4. If `document` has pending style or layout changes,
 perform them.

5. Set the [internal layout intrinsic
 size](#internal-layout-intrinsic-size) of `host element` to the width and
 height of the [scrolling
 area](https://drafts.csswg.org/cssom-view-1/#scrolling-area) of
 [this](https://webidl.spec.whatwg.org/#this).

### 5.4. Intrinsic Size Contributions

(#issue-d41d8cd9④) [CSS Sizing 3 § 5.2 Intrinsic
Contributions](https://drafts.csswg.org/css-sizing-3/#intrinsic-contribution)

### 5.5. Zeroing Min-Content Size Contributions: the [min-intrinsic-sizing property]
Name:

[min-intrinsic-sizing]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

legacy
[\|](https://drafts.csswg.org/css-values-4/#comb-one) zero-if-scroll
[\|\|](https://drafts.csswg.org/css-values-4/#comb-any) zero-if-extrinsic

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

legacy

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

all elements except [inline
boxes](https://drafts.csswg.org/css-display-4/#inline-box)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

as specified

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

This property seriously needs some name
bikeshedding.

This property defines whether the [min-content
contribution](https://drafts.csswg.org/css-sizing-3/#min-content-contribution) of a
[non-replaced](https://drafts.csswg.org/css-display-4/#non-replaced) box is "compressed" under certain circumstances. Values
have the following meanings:

[legacy]
: The box's [min-content
 contribution](https://drafts.csswg.org/css-sizing-3/#min-content-contribution) is handled as normal.

[zero-if-scroll]
: The box's [min-content
 contribution](https://drafts.csswg.org/css-sizing-3/#min-content-contribution) is "compressed" if it is a [scroll
 container](https://drafts.csswg.org/css-overflow-3/#scroll-container) in that axis.

[zero-if-extrinsic]

: The box's [min-content
 contribution](https://drafts.csswg.org/css-sizing-3/#min-content-contribution) is "compressed" if has an
 [extrinsic](https://drafts.csswg.org/css-sizing-3/#extrinsic-sizing)
 [preferred](https://drafts.csswg.org/css-sizing-3/#preferred-size) or
 [maximum](https://drafts.csswg.org/css-sizing-3/#max-width) size.

 This is the default behavior of most [replaced
 elements](https://drafts.csswg.org/css-display-4/#replaced-element).

The following rule will make all
[scroll
containers](https://drafts.csswg.org/css-overflow-3/#scroll-container) essentially ignore their contents when passing up their
size contributions (unless they specifically requested a content-based
size):

``` highlight
*, ::before, ::after { min-intrinsic-sizing: zero-if-scroll; }
```

This prevents the [scroll
container](https://drafts.csswg.org/css-overflow-3/#scroll-container) from blowing up the size of its ancestors if it
contains large items such as a table or long lines of unbreakable text.
Meanwhile, it allows boxes that are not scroll containers to continue
influencing the [min-content
size](https://drafts.csswg.org/css-sizing-3/#min-content) of their ancestors.

 The behavior of
[zero-if-scroll](#valdef-min-intrinsic-sizing-zero-if-scroll) would have been a better default, but due to
Web-compat, it cannot be the initial value. :(

The "compressed" [min-content
contributions](https://drafts.csswg.org/css-sizing-3/#min-content-contribution) is calculated by pretending the box were empty, except
when factoring in sizing constraints imposed by explicit
[min-content](https://drafts.csswg.org/css-sizing-3/#valdef-width-min-content),
[max-content](https://drafts.csswg.org/css-sizing-3/#valdef-width-max-content), and
[fit-content](https://drafts.csswg.org/css-sizing-3/#valdef-width-fit-content) values of the [sizing
properties](https://drafts.csswg.org/css-sizing-3/#sizing-property).

#### 5.5.1. Intrinsic Contributions of Percentage-Sized Boxes

Sometimes the size of a percentage-sized box's [containing
block](https://drafts.csswg.org/css-display-4/#containing-block) depends on the [intrinsic size
contribution](https://drafts.csswg.org/css-sizing-3/#intrinsic-size-contribution) of the box itself, creating a cyclic dependency. See
[CSS Sizing 3 § 5.2.1 Intrinsic Contributions of Percentage-Sized
Boxes](https://drafts.csswg.org/css-sizing-3/#cyclic-percentage-contribution)
for how to resolve these.

For
[fit-content()](#funcdef-width-fit-content), if the
[\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage) expression on its own would resolve
to the property's initial value, then instead:

- For a [maximum size property], treat it as
 [max-content](#valdef-column-width-max-content).

- For a [minimum size property], treat it as
 [min-content](#valdef-column-width-min-content).

- For a [preferred size
 property](https://drafts.csswg.org/css-sizing-3/#preferred-size-properties), treat it as
 [fit-content](#valdef-column-width-fit-content).

### 5.6. New Column Sizing Values: the [stretch, [min-content](#valdef-column-width-min-content), [max-content](#valdef-column-width-max-content), [fit-content](#valdef-column-width-fit-content), and [fit-content()](#valdef-column-width-fit-content-length-percentage) values]
Name:

[column-width](https://drafts.csswg.org/css-multicol-2/#propdef-column-width)

[New values:](https://www.w3.org/TR/css-values/#value-defs)

auto
[\|](https://drafts.csswg.org/css-values-4/#comb-one)
[\<box-size\>](#typedef-box-size)

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

as specified, with
[\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage) values computed

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value type

When used as values for
[column-width](https://drafts.csswg.org/css-multicol-2/#propdef-column-width), the new keywords specify the
optimal column width:

[stretch]
: Specifies the optimal column width as the [stretch-fit inline
 size](https://drafts.csswg.org/css-sizing-3/#stretch-fit-inline-size) of the multi-column container.

[min-content]
: Specifies the optimal column width as the [min-content inline
 size](https://drafts.csswg.org/css-sizing-3/#min-content-inline-size) of the multi-column container's contents.

[max-content]
: Specifies the optimal column width as the [max-content inline
 size](https://drafts.csswg.org/css-sizing-3/#max-content-inline-size) of the multi-column container's contents.

[fit-content]
: Specifies the optimal column width as
 `min(`[`max-content inline size`](https://drafts.csswg.org/css-sizing-3/#max-content-inline-size)`, max(`[`min-content inline size`](https://drafts.csswg.org/css-sizing-3/#min-content-inline-size)`, `[`stretch-fit inline size`](https://drafts.csswg.org/css-sizing-3/#stretch-fit-inline-size)`))`.

[fit-content([\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage))]
: Specifies the optimal column width as
 `min(`[`max-content size`](https://drafts.csswg.org/css-sizing-3/#max-content)`, max(`[`min-content size`](https://drafts.csswg.org/css-sizing-3/#min-content)`, `[`<length-percentage>`](https://drafts.csswg.org/css-values-4/#typedef-length-percentage)`))`

 The column width never varies by column. When the
column width is informed by the multi-column container's contents (as in
the keywords above), all of its contents are taken under consideration
and the calculated width is shared by all the columns.

## 6. Extrinsic Size Determination

(#issue-d41d8cd9⑤) [CSS Sizing 3 § 4 Extrinsic Size
Determination](https://drafts.csswg.org/css-sizing-3/#extrinsic)

### 6.1. Contain-fit Sizing: stretching while maintaining an aspect ratio

Contain-fit sizing essentially applies stretch-fit sizing, but reduces
the size of the box in one axis to maintain the box's [preferred aspect
ratio](#preferred-aspect-ratio), similar to the
[contain](https://drafts.csswg.org/css-images-4/#valdef-object-fit-contain) keyword of the
[object-fit](https://drafts.csswg.org/css-images-4/#propdef-object-fit) and
[background-size](https://drafts.csswg.org/css-backgrounds-3/#propdef-background-size) properties.

First, a target rectangle is determined:

1. The initial target rectangle is the size of the box's containing
 block, with any indefinite size assumed as infinity. If both
 dimensions are indefinite, the initial target rectangle is set to
 match the outer edges of the box were it [stretch-fit
 sized](https://drafts.csswg.org/css-sizing-3/#stretch-fit-size).
2. Next, if the box has a
 non-[none](https://drafts.csswg.org/css-sizing-3/#valdef-max-width-none)
 [max-width](https://drafts.csswg.org/css2/#propdef-max-width) or
 [max-height](https://drafts.csswg.org/css2/#propdef-max-height), the target rectangle is
 clamped in the affected dimension to less than or equal to the
 "maximum size" of the box's margin box, i.e. the size its margin box
 would be if the box was sized at its max-width/height. (Note that,
 consistent with normal [box-sizing
 rules](http://www.w3.org/TR/CSS2/visuren.html), this "maximum size"
 is floored by the effects of the box's
 [min-width](https://drafts.csswg.org/css2/#propdef-min-width)/[min-height](https://drafts.csswg.org/css2/#propdef-min-height).)
3. Last, the target rectangle is reduced in one dimension by the
 minimum necessary for it to match the box's [preferred aspect
 ratio](#preferred-aspect-ratio).

The contain-fit size in each dimension is the size that would result
from stretch-fitting into the target rectangle.

Copy whatever stretch-fit ends up doing
wrt margin collapsing.

If there is a minimum size in one
dimension that would cause overflow of the target rectangle if the
aspect ratio were honored, do we honor the aspect ratio or skew the
image? If the former, we need a step similar to #2 that applies the
relevant minimums.

### 6.2. Percentage Sizing

...

## [ Changes]
### [ Changes since 4 September 2026 Working Draft]
Significant changes since the [4 September 2026 Working
Draft](https://www.w3.org/TR/2026/WD-css-sizing-4-20260904/) include:

- Added the
 [stretch()](#funcdef-width-stretch) functional notation and redefined
 [fit-content()](#funcdef-width-fit-content) to use it. ([Issue
 5715](https://github.com/w3c/csswg-drafts/issues/5715))

- Clarified interaction of cyclic percentages and
 [fit-content()](#funcdef-width-fit-content). ([Issue
 11805](https://github.com/w3c/csswg-drafts/issues/11805))

### [ Changes since 5 May 2021 Working Draft]
Significant changes since the [5 May 2021 Working
Draft](https://www.w3.org/TR/2021/WD-css-sizing-4-20210520/) include:

- Added the [size](#propdef-size),
 [min-size](#propdef-min-size), and
 [max-size](#propdef-max-size) [shorthand
 properties](https://drafts.csswg.org/css-cascade-5/#shorthand-property). ([Issue
 820](https://github.com/w3c/csswg-drafts/issues/820))

- Added
 [calc-size()](#funcdef-width-calc-size) to the [sizing
 properties](https://drafts.csswg.org/css-sizing-3/#sizing-property). ([Issue
 6265](https://github.com/w3c/csswg-drafts/issues/6265))

- Added
 [frame-sizing](#propdef-frame-sizing) property definition.
 ([1771](https://github.com/w3c/csswg-drafts/issues/1771))

- Imported
 [fit-content()](#funcdef-width-fit-content) from Level 3, graduated [fit-content]
 and [stretch] back down to Level 3. ([Issue
 10601](https://github.com/w3c/csswg-drafts/issues/10601))

- Introduced
 [\<box-size\>](#typedef-box-size) grammar production to consolidate sizing
 values. ([Issue
 13478](https://github.com/w3c/csswg-drafts/issues/13478))

- Disallowed re-ordering of values in [contain-intrinsic-size].
 ([Issue 6391](https://github.com/w3c/csswg-drafts/issues/6391)).

- Only used the last remembered size for the
 [auto](#valdef-contain-intrinsic-width-auto) value of the [contain-intrinsic-\*]
 properties when the element is skipping its contents to avoid phantom
 sizes. ([Issue
 6308](https://github.com/w3c/csswg-drafts/issues/6308)).

- Clarify which elements get a last remembered size and when. ([Issue
 6220](https://github.com/w3c/csswg-drafts/issues/6220))

- Added logical property group for
 [contain-intrinsic-size](#propdef-contain-intrinsic-size) properties. ([Issue
 2822](https://github.com/w3c/csswg-drafts/issues/2822)).

- Changed syntax of
 [contain-intrinsic-size](#propdef-contain-intrinsic-size) to allow for more flexible
 combinations of values. ([Issue
 8407](https://github.com/w3c/csswg-drafts/issues/8407)).

- Disallowed negative lengths in [contain-intrinsic-\*]
 properties. ([Issue
 11945](https://github.com/w3c/csswg-drafts/issues/11945)).

- Added [responsively-sized
 iframes](#responsive-iframes) via \'contain-intrinsic-size/from-element\' value.
 ([Issue 1771](https://github.com/w3c/csswg-drafts/issues/1771)).

- Clarified that Flexbox's [stretch-fit
 sizing](https://drafts.csswg.org/css-sizing-3/#stretch-fit-size) behavior is slightly different from
 [stretch](https://drafts.csswg.org/css-align-3/#valdef-align-self-stretch). ([Issue
 11784](https://github.com/w3c/csswg-drafts/issues/11784)).

- Added Web Platform Tests coverage.

- Various other minor editorial fixes and improvements.

### [ Changes since 20 October 2020 Working Draft]
Significant changes since the [20 October 2020 Working
Draft](https://www.w3.org/TR/2020/WD-css-sizing-4-20201020/) include:

- Drafted
 [min-intrinsic-sizing](#propdef-min-intrinsic-sizing) property, to better control the
 min-content contributions of scroll containers. ([Issue
 1865](https://github.com/w3c/csswg-drafts/issues/1865), [Issue
 4585](https://github.com/w3c/csswg-drafts/issues/4585))

- Added longhands to
 [contain-intrinsic-size](#propdef-contain-intrinsic-size) for controlling each axis
 independently. ([Issue
 5432](https://github.com/w3c/csswg-drafts/issues/5432))

- Drafted
 [auto](#valdef-contain-intrinsic-width-auto) value to
 [contain-intrinsic-size](#propdef-contain-intrinsic-size) to allow "remembering" the
 previously-calculated size. ([Issue
 5668](https://github.com/w3c/csswg-drafts/issues/5668), [Issue
 5815](https://github.com/w3c/csswg-drafts/issues/5815))

- Defined handling of degenerate ratios in
 [aspect-ratio](#propdef-aspect-ratio). ([Issue
 5557](https://github.com/w3c/csswg-drafts/issues/5557))

- Defined how
 [aspect-ratio](#propdef-aspect-ratio) impacts a replaced element's
 natural sizes. ([Issue
 5306](https://github.com/w3c/csswg-drafts/issues/5306))

- Fixed some errors in the [§ 4.4 Min/Max Size
 Transfers](#aspect-ratio-size-transfers) section, aligning the
 behavior to not conflict with behavior defined by CSS2 / CSS Flex
 Layout / etc. ([Issue
 6071](https://github.com/w3c/csswg-drafts/issues/6071))

- Added [contain-intrinsic-size: auto
 none](#propdef-contain-intrinsic-size) syntax.

Significant changes since the [26 May 2020 First Public Working
Draft](https://www.w3.org/TR/2020/WD-css-sizing-4-20200526/) include:

- Define [ratio-determining
 axis](#ratio-determining-axis) as a term.

- Define that min/max sizing constraints are transferred across an
 aspect-ratio, ([Issue
 5257](https://github.com/w3c/csswg-drafts/issues/5257))

 > Additionally, sizing constraints in either axis (the
 > `origin` axis) are transferred through the [preferred
 > aspect
 > ratio](#preferred-aspect-ratio) to the other axis (the `destination`
 > axis) as follows:
 >
 > - First, any
 > [definite](https://drafts.csswg.org/css-sizing-3/#definite) [minimum
 > size](https://drafts.csswg.org/css-sizing-3/#min-width) is converted and transferred from the
 > `origin` to `destination` axis. This
 > transferred minimum is capped by any
 > [definite]
 > [preferred](https://drafts.csswg.org/css-sizing-3/#preferred-size) or [maximum
 > size](https://drafts.csswg.org/css-sizing-3/#max-width) in the `destination` axis.
 >
 > - Then, any
 > [definite](https://drafts.csswg.org/css-sizing-3/#definite) [maximum
 > size](https://drafts.csswg.org/css-sizing-3/#max-width) is converted and transferred from the
 > `origin` to `destination`. This transferred
 > maximum is floored by any [definite]
 > [preferred](https://drafts.csswg.org/css-sizing-3/#preferred-size) or [minimum
 > size](https://drafts.csswg.org/css-sizing-3/#min-width) in the `destination` axis as well as
 > by the transferred minimum, if any.
 >
 > The basic principle is that sizing constraints
 > transfer through the aspect-ratio to the other side to preserve the
 > aspect ratio to the extent that they can without violating any sizes
 > specified explicitly on that affected axis.

- Clarify that
 [aspect-ratio](#propdef-aspect-ratio) on a [replaced
 element](https://drafts.csswg.org/css-display-4/#replaced-element) with only one [natural
 size](https://drafts.csswg.org/css-images-3/#natural-size) determines the other dimension. ([Issue
 5306](https://github.com/w3c/csswg-drafts/issues/5306))

 > If a replaced element's only natural dimension is a natural width or
 > a natural height, giving it a [preferred aspect
 > ratio](#preferred-aspect-ratio) also gives it a natural height or width, whichever
 > was missing, by transferring the existing size through the
 > [preferred aspect ratio].

- Define that
 [aspect-ratio](#propdef-aspect-ratio) inhibits margin self-collapsing
 ([Issue 5328](https://github.com/w3c/csswg-drafts/issues/5328))

 > For the purpose of margin collapsing ([CSS 2 § 8.3.1 Collapsing
 > margins](https://www.w3.org/TR/CSS2/box.html#collapsing-margins)),
 > if the [block
 > axis](https://drafts.csswg.org/css-writing-modes-4/#block-axis) is the [ratio-dependent
 > axis](#ratio-dependent-axis), it is not considered to have a
 > [computed](https://drafts.csswg.org/css-cascade-5/#computed-value)
 > [block-size](https://drafts.csswg.org/css-logical-1/#propdef-block-size) of
 > [auto](https://drafts.csswg.org/css-sizing-3/#valdef-width-auto).

### [ Additions Since Level 3]
- Added
 [fit-content()](#funcdef-width-fit-content) function and
 [contain](#valdef-width-contain) keyword for sizing properties.
- Added
 [aspect-ratio](#propdef-aspect-ratio) property.
- Added
 [contain-intrinsic-width](#propdef-contain-intrinsic-width),
 [contain-intrinsic-height](#propdef-contain-intrinsic-height),
 [contain-intrinsic-block-size](#propdef-contain-intrinsic-block-size), and
 [contain-intrinsic-inline-size](#propdef-contain-intrinsic-inline-size) properties and their shorthand
 [contain-intrinsic-size](#propdef-contain-intrinsic-size).
- Added
 [min-intrinsic-sizing](#propdef-min-intrinsic-sizing) property.
- Added
 [frame-sizing](#propdef-frame-sizing) property.

## [ Acknowledgments]
Special thanks go to Aaron Gustafson, L. David Baron for their
contributions to this module.

## [ Privacy Considerations]
This specification introduces no new privacy considerations.

## [ Security Considerations]
This specification introduces no new security considerations.
