## 1. Introduction

Efficiently rendering a website relies on the user agent being able to
detect what parts of the page are being displayed, which parts might
affect the currently-displayed section, and what can be ignored.

There are various heuristics that can be used to guess when a given
sub-tree is independent of the rest of the page in some manner, but
they're fragile, so innocuous changes to a page may inadvertently make
it fail such heuristic tests, causing rendering to fall into a slow code
path. There are also many things that would be good to isolate which are
difficult or impossible to detect in a heuristic manner.

To alleviate these problems and allow strong, predictable isolation of a
subtree from the rest of the page, this specification defines a
[contain](#propdef-contain) property.

To allow even further optimization of off-screen contents, this spec
also defines a
[content-visibility](#propdef-content-visibility) property, enabling the user agent
to skip an element's layout and painting *entirely* when not needed.

### 1.1. Module Interactions

This document defines new features not present in earlier
specifications. In addition, it aims to replace and supersede
[\[CSS-CONTAIN-1\]](#biblio-css-contain-1 "CSS Containment Module Level 1")
once stable.

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

## 2. Strong Containment: the [contain property]
Tests

The following tests are crash tests that relate to general usage of this
feature but are not particularly tied to any particular normative
statement.

- [contain-chrome-thcrash-001.html](https://wpt.fyi/results/css/css-contain/contain-chrome-thcrash-001.html "css/css-contain/contain-chrome-thcrash-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-chrome-thcrash-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-chrome-thcrash-001.html)
- [contain-crash.html](https://wpt.fyi/results/css/css-contain/contain-crash.html "css/css-contain/contain-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-crash.html)
- [contain-flexbox-outline.html](https://wpt.fyi/results/css/css-contain/contain-flexbox-outline.html "css/css-contain/contain-flexbox-outline.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-flexbox-outline.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-flexbox-outline.html)
- [contain-nested-crash-001.html](https://wpt.fyi/results/css/css-contain/crashtests/contain-nested-crash-001.html "css/css-contain/crashtests/contain-nested-crash-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/crashtests/contain-nested-crash-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/crashtests/contain-nested-crash-001.html)
- [contain-nested-crash-002.html](https://wpt.fyi/results/css/css-contain/crashtests/contain-nested-crash-002.html "css/css-contain/crashtests/contain-nested-crash-002.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/crashtests/contain-nested-crash-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/crashtests/contain-nested-crash-002.html)
- [contain-nested-crash-003.html](https://wpt.fyi/results/css/css-contain/crashtests/contain-nested-crash-003.html "css/css-contain/crashtests/contain-nested-crash-003.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/crashtests/contain-nested-crash-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/crashtests/contain-nested-crash-003.html)
- [contain-nested-crash-004.html](https://wpt.fyi/results/css/css-contain/crashtests/contain-nested-crash-004.html "css/css-contain/crashtests/contain-nested-crash-004.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/crashtests/contain-nested-crash-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/crashtests/contain-nested-crash-004.html)
- [contain-nested-relayout-boundary.html](https://wpt.fyi/results/css/css-contain/crashtests/contain-nested-relayout-boundary.html "css/css-contain/crashtests/contain-nested-relayout-boundary.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/crashtests/contain-nested-relayout-boundary.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/crashtests/contain-nested-relayout-boundary.html)
- [quote-scoping-shadow-dom-crash.html](https://wpt.fyi/results/css/css-contain/quote-scoping-shadow-dom-crash.html "css/css-contain/quote-scoping-shadow-dom-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/quote-scoping-shadow-dom-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/quote-scoping-shadow-dom-crash.html)
- [contain-style-remove-element-crash.html](https://wpt.fyi/results/css/css-contain/contain-style-remove-element-crash.html "css/css-contain/contain-style-remove-element-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-style-remove-element-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-style-remove-element-crash.html)

------------------------------------------------------------------------

Name:

[contain]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

none
[\|](https://drafts.csswg.org/css-values-4/#comb-one) strict [\|] content
[\|] \[ \[size [\|]
inline-size\]
[\|\|](https://drafts.csswg.org/css-values-4/#comb-any) layout [\|\|] style
[\|\|] paint \]

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

none

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

See [below](#contain-applies)

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

the keyword [none](#valdef-contain-none) or one or more of
[size](#valdef-contain-size),
[layout](#valdef-contain-layout),
[style](#valdef-contain-style),
[paint](#valdef-contain-paint)

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

not animatable

Tests

- [contain-animation-001.html](https://wpt.fyi/results/css/css-contain/contain-animation-001.html "css/css-contain/contain-animation-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-animation-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-animation-001.html)
- [inheritance.html](https://wpt.fyi/results/css/css-contain/inheritance.html "css/css-contain/inheritance.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/inheritance.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/inheritance.html)
- [contain-computed.html](https://wpt.fyi/results/css/css-contain/parsing/contain-computed.html "css/css-contain/parsing/contain-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/parsing/contain-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/parsing/contain-computed.html)
- [contain-invalid.html](https://wpt.fyi/results/css/css-contain/parsing/contain-invalid.html "css/css-contain/parsing/contain-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/parsing/contain-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/parsing/contain-invalid.html)
- [contain-valid.html](https://wpt.fyi/results/css/css-contain/parsing/contain-valid.html "css/css-contain/parsing/contain-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/parsing/contain-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/parsing/contain-valid.html)
- [contain-computed-children.html](https://wpt.fyi/results/css/css-contain/parsing/contain-computed-children.html "css/css-contain/parsing/contain-computed-children.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/parsing/contain-computed-children.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/parsing/contain-computed-children.html)
- [contain-layout-size-003.html](https://wpt.fyi/results/css/css-contain/contain-layout-size-003.html "css/css-contain/contain-layout-size-003.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-size-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-size-003.html)
- [contain-paint-size-001.html](https://wpt.fyi/results/css/css-contain/contain-paint-size-001.html "css/css-contain/contain-paint-size-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-size-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-size-001.html)
- [contain-paint-size-002.html](https://wpt.fyi/results/css/css-contain/contain-paint-size-002.html "css/css-contain/contain-paint-size-002.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-size-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-size-002.html)
- [contain-paint-size-003.html](https://wpt.fyi/results/css/css-contain/contain-paint-size-003.html "css/css-contain/contain-paint-size-003.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-size-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-size-003.html)

*User agents are expected to support this property on all media,
including non-visual ones.*

The [contain](#propdef-contain) property allows an author to indicate that an
element and its contents are, as much as possible, *independent* of the
rest of the document tree. This allows user agents to utilize much
stronger optimizations when rendering a page using
[contain] properly, and allows
authors to be confident that their page won't accidentally fall into a
slow code path due to an innocuous change.

[none]
: This value indicates that the property has no effect. The element
 renders as normal, with no containment effects applied.

[strict]
: This value computes to [size layout paint style], and thus
 turns on all forms of
 [containment](#containment)
 for the element.
 Tests
 - [contain-strict-001.html](https://wpt.fyi/results/css/css-contain/contain-strict-001.html "css/css-contain/contain-strict-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-strict-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-strict-001.html)
 - [contain-strict-002.html](https://wpt.fyi/results/css/css-contain/contain-strict-002.html "css/css-contain/contain-strict-002.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-strict-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-strict-002.html)
 - [contain-strict-003.html](https://wpt.fyi/results/css/css-contain/contain-strict-003.html "css/css-contain/contain-strict-003.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-strict-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-strict-003.html)
 - [contain-strict-011.html](https://wpt.fyi/results/css/css-contain/contain-strict-011.html "css/css-contain/contain-strict-011.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-strict-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-strict-011.html)
 - [contain-flexbox-outline.html](https://wpt.fyi/results/css/css-contain/contain-flexbox-outline.html "css/css-contain/contain-flexbox-outline.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-flexbox-outline.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-flexbox-outline.html)

[content]

: This value computes to [layout paint style], and thus turns on
 all forms of [containment](#containment) *except* [size
 containment](#size-containment) for the element.

 Tests

 - [contain-content-001.html](https://wpt.fyi/results/css/css-contain/contain-content-001.html "css/css-contain/contain-content-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-content-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-content-001.html)
 - [contain-content-002.html](https://wpt.fyi/results/css/css-contain/contain-content-002.html "css/css-contain/contain-content-002.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-content-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-content-002.html)
 - [contain-content-003.html](https://wpt.fyi/results/css/css-contain/contain-content-003.html "css/css-contain/contain-content-003.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-content-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-content-003.html)
 - [contain-content-004.html](https://wpt.fyi/results/css/css-contain/contain-content-004.html "css/css-contain/contain-content-004.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-content-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-content-004.html)
 - [contain-content-011.html](https://wpt.fyi/results/css/css-contain/contain-content-011.html "css/css-contain/contain-content-011.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-content-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-content-011.html)

 [contain:
 content](#propdef-contain) is reasonably \"safe\" to apply widely; its
 effects are fairly minor in practice, and most content won't run
 afoul of its restrictions. However, because it doesn't apply [size
 containment](#size-containment), the element can still respond to the size of its
 contents, which can cause layout-invalidation to percolate further
 up the tree than desired. Use [contain:
 strict] when possible, to gain as
 much containment as you can.

[size]
: The value turns on [size
 containment](#size-containment) for the element. This ensures that the [containment
 box](#size-containment-box) can be laid out without needing to examine its
 descendants.
 Tests
 - [contain-size-001.html](https://wpt.fyi/results/css/css-contain/contain-size-001.html "css/css-contain/contain-size-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-001.html)
 - [contain-size-002.html](https://wpt.fyi/results/css/css-contain/contain-size-002.html "css/css-contain/contain-size-002.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-002.html)
 - [contain-size-003.html](https://wpt.fyi/results/css/css-contain/contain-size-003.html "css/css-contain/contain-size-003.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-003.html)
 - [contain-size-004.html](https://wpt.fyi/results/css/css-contain/contain-size-004.html "css/css-contain/contain-size-004.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-004.html)
 - [contain-size-005.html](https://wpt.fyi/results/css/css-contain/contain-size-005.html "css/css-contain/contain-size-005.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-005.html)
 - [contain-size-006.html](https://wpt.fyi/results/css/css-contain/contain-size-006.html "css/css-contain/contain-size-006.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-006.html)
 - [contain-size-007.html](https://wpt.fyi/results/css/css-contain/contain-size-007.html "css/css-contain/contain-size-007.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-007.html)
 - [contain-size-008.html](https://wpt.fyi/results/css/css-contain/contain-size-008.html "css/css-contain/contain-size-008.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-008.html)
 - [contain-size-009.html](https://wpt.fyi/results/css/css-contain/contain-size-009.html "css/css-contain/contain-size-009.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-009.html)
 - [contain-size-010.html](https://wpt.fyi/results/css/css-contain/contain-size-010.html "css/css-contain/contain-size-010.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-010.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-010.html)
 - [contain-size-011.html](https://wpt.fyi/results/css/css-contain/contain-size-011.html "css/css-contain/contain-size-011.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-011.html)
 - [contain-size-012.html](https://wpt.fyi/results/css/css-contain/contain-size-012.html "css/css-contain/contain-size-012.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-012.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-012.html)
 - [contain-size-012b.html](https://wpt.fyi/results/css/css-contain/contain-size-012b.html "css/css-contain/contain-size-012b.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-012b.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-012b.html)
 - [contain-size-013.html](https://wpt.fyi/results/css/css-contain/contain-size-013.html "css/css-contain/contain-size-013.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-013.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-013.html)
 - [contain-size-021.html](https://wpt.fyi/results/css/css-contain/contain-size-021.html "css/css-contain/contain-size-021.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-021.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-021.html)
 - [contain-size-023.html](https://wpt.fyi/results/css/css-contain/contain-size-023.html "css/css-contain/contain-size-023.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-023.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-023.html)
 - [contain-size-025.html](https://wpt.fyi/results/css/css-contain/contain-size-025.html "css/css-contain/contain-size-025.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-025.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-025.html)
 - [contain-size-027.html](https://wpt.fyi/results/css/css-contain/contain-size-027.html "css/css-contain/contain-size-027.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-027.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-027.html)
 - [contain-size-041.html](https://wpt.fyi/results/css/css-contain/contain-size-041.html "css/css-contain/contain-size-041.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-041.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-041.html)
 - [contain-size-042.html](https://wpt.fyi/results/css/css-contain/contain-size-042.html "css/css-contain/contain-size-042.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-042.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-042.html)
 - [contain-size-051.html](https://wpt.fyi/results/css/css-contain/contain-size-051.html "css/css-contain/contain-size-051.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-051.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-051.html)
 - [contain-size-052.html](https://wpt.fyi/results/css/css-contain/contain-size-052.html "css/css-contain/contain-size-052.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-052.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-052.html)
 - [contain-size-056.html](https://wpt.fyi/results/css/css-contain/contain-size-056.html "css/css-contain/contain-size-056.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-056.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-056.html)
 - [contain-size-061.html](https://wpt.fyi/results/css/css-contain/contain-size-061.html "css/css-contain/contain-size-061.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-061.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-061.html)
 - [contain-size-062.html](https://wpt.fyi/results/css/css-contain/contain-size-062.html "css/css-contain/contain-size-062.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-062.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-062.html)
 - [contain-size-063.html](https://wpt.fyi/results/css/css-contain/contain-size-063.html "css/css-contain/contain-size-063.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-063.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-063.html)
 - [contain-size-baseline-001.html](https://wpt.fyi/results/css/css-contain/contain-size-baseline-001.html "css/css-contain/contain-size-baseline-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-baseline-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-baseline-001.html)
 - [contain-size-borders.html](https://wpt.fyi/results/css/css-contain/contain-size-borders.html "css/css-contain/contain-size-borders.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-borders.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-borders.html)
 - [contain-size-breaks-001.html](https://wpt.fyi/results/css/css-contain/contain-size-breaks-001.html "css/css-contain/contain-size-breaks-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-breaks-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-breaks-001.html)
 - [contain-size-button-001.html](https://wpt.fyi/results/css/css-contain/contain-size-button-001.html "css/css-contain/contain-size-button-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-button-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-button-001.html)
 - [contain-size-fieldset-001.html](https://wpt.fyi/results/css/css-contain/contain-size-fieldset-001.html "css/css-contain/contain-size-fieldset-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-fieldset-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-fieldset-001.html)
 - [contain-size-fieldset-002.html](https://wpt.fyi/results/css/css-contain/contain-size-fieldset-002.html "css/css-contain/contain-size-fieldset-002.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-fieldset-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-fieldset-002.html)
 - [contain-size-flexbox-001.html](https://wpt.fyi/results/css/css-contain/contain-size-flexbox-001.html "css/css-contain/contain-size-flexbox-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-flexbox-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-flexbox-001.html)
 - [contain-size-flexbox-002.html](https://wpt.fyi/results/css/css-contain/contain-size-flexbox-002.html "css/css-contain/contain-size-flexbox-002.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-flexbox-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-flexbox-002.html)
 - [contain-size-grid-001.html](https://wpt.fyi/results/css/css-contain/contain-size-grid-001.html "css/css-contain/contain-size-grid-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-grid-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-grid-001.html)
 - [contain-size-grid-002.html](https://wpt.fyi/results/css/css-contain/contain-size-grid-002.html "css/css-contain/contain-size-grid-002.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-grid-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-grid-002.html)
 - [contain-size-grid-003.html](https://wpt.fyi/results/css/css-contain/contain-size-grid-003.html "css/css-contain/contain-size-grid-003.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-grid-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-grid-003.html)
 - [contain-size-grid-004.html](https://wpt.fyi/results/css/css-contain/contain-size-grid-004.html "css/css-contain/contain-size-grid-004.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-grid-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-grid-004.html)
 - [contain-size-grid-005.html](https://wpt.fyi/results/css/css-contain/contain-size-grid-005.html "css/css-contain/contain-size-grid-005.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-grid-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-grid-005.html)
 - [contain-size-grid-006.html](https://wpt.fyi/results/css/css-contain/contain-size-grid-006.html "css/css-contain/contain-size-grid-006.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-grid-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-grid-006.html)
 - [contain-size-monolithic-001.html](https://wpt.fyi/results/css/css-contain/contain-size-monolithic-001.html "css/css-contain/contain-size-monolithic-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-monolithic-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-monolithic-001.html)
 - [contain-size-monolithic-002.html](https://wpt.fyi/results/css/css-contain/contain-size-monolithic-002.html "css/css-contain/contain-size-monolithic-002.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-monolithic-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-monolithic-002.html)
 - [contain-size-multicol-001.html](https://wpt.fyi/results/css/css-contain/contain-size-multicol-001.html "css/css-contain/contain-size-multicol-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-multicol-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-multicol-001.html)
 - [contain-size-multicol-as-flex-item.html](https://wpt.fyi/results/css/css-contain/contain-size-multicol-as-flex-item.html "css/css-contain/contain-size-multicol-as-flex-item.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-multicol-as-flex-item.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-multicol-as-flex-item.html)
 - [contain-size-replaced-001.html](https://wpt.fyi/results/css/css-contain/contain-size-replaced-001.html "css/css-contain/contain-size-replaced-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-replaced-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-replaced-001.html)
 - [contain-size-replaced-002.html](https://wpt.fyi/results/css/css-contain/contain-size-replaced-002.html "css/css-contain/contain-size-replaced-002.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-replaced-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-replaced-002.html)
 - [contain-size-replaced-003a.html](https://wpt.fyi/results/css/css-contain/contain-size-replaced-003a.html "css/css-contain/contain-size-replaced-003a.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-replaced-003a.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-replaced-003a.html)
 - [contain-size-replaced-003b.html](https://wpt.fyi/results/css/css-contain/contain-size-replaced-003b.html "css/css-contain/contain-size-replaced-003b.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-replaced-003b.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-replaced-003b.html)
 - [contain-size-replaced-003c.html](https://wpt.fyi/results/css/css-contain/contain-size-replaced-003c.html "css/css-contain/contain-size-replaced-003c.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-replaced-003c.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-replaced-003c.html)
 - [contain-size-replaced-004.html](https://wpt.fyi/results/css/css-contain/contain-size-replaced-004.html "css/css-contain/contain-size-replaced-004.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-replaced-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-replaced-004.html)
 - [contain-size-replaced-005.html](https://wpt.fyi/results/css/css-contain/contain-size-replaced-005.html "css/css-contain/contain-size-replaced-005.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-replaced-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-replaced-005.html)
 - [contain-size-replaced-006.html](https://wpt.fyi/results/css/css-contain/contain-size-replaced-006.html "css/css-contain/contain-size-replaced-006.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-replaced-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-replaced-006.html)
 - [contain-size-replaced-007.html](https://wpt.fyi/results/css/css-contain/contain-size-replaced-007.html "css/css-contain/contain-size-replaced-007.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-replaced-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-replaced-007.html)
 - [contain-size-select-001.html](https://wpt.fyi/results/css/css-contain/contain-size-select-001.html "css/css-contain/contain-size-select-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-select-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-select-001.html)
 - [contain-size-select-002.html](https://wpt.fyi/results/css/css-contain/contain-size-select-002.html "css/css-contain/contain-size-select-002.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-select-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-select-002.html)
 - [contain-size-scrollbars-001.html](https://wpt.fyi/results/css/css-contain/contain-size-scrollbars-001.html "css/css-contain/contain-size-scrollbars-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-scrollbars-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-scrollbars-001.html)
 - [contain-size-scrollbars-002.html](https://wpt.fyi/results/css/css-contain/contain-size-scrollbars-002.html "css/css-contain/contain-size-scrollbars-002.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-scrollbars-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-scrollbars-002.html)
 - [contain-size-scrollbars-003.html](https://wpt.fyi/results/css/css-contain/contain-size-scrollbars-003.html "css/css-contain/contain-size-scrollbars-003.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-scrollbars-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-scrollbars-003.html)
 - [contain-size-scrollbars-004.html](https://wpt.fyi/results/css/css-contain/contain-size-scrollbars-004.html "css/css-contain/contain-size-scrollbars-004.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-scrollbars-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-scrollbars-004.html)
 - [contain-layout-size-003.html](https://wpt.fyi/results/css/css-contain/contain-layout-size-003.html "css/css-contain/contain-layout-size-003.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-size-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-size-003.html)
 - [contain-paint-size-001.html](https://wpt.fyi/results/css/css-contain/contain-paint-size-001.html "css/css-contain/contain-paint-size-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-size-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-size-001.html)
 - [contain-paint-size-002.html](https://wpt.fyi/results/css/css-contain/contain-paint-size-002.html "css/css-contain/contain-paint-size-002.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-size-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-size-002.html)
 - [contain-paint-size-003.html](https://wpt.fyi/results/css/css-contain/contain-paint-size-003.html "css/css-contain/contain-paint-size-003.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-size-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-size-003.html)
 - [contain-size-removed.html](https://wpt.fyi/results/css/css-contain/contain-size-removed.html "css/css-contain/contain-size-removed.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-removed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-removed.html)
 - [contain-size-dynamic-001.html](https://wpt.fyi/results/css/css-contain/contain-size-dynamic-001.html "css/css-contain/contain-size-dynamic-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-dynamic-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-dynamic-001.html)
 - [contain-size-grid-indefinite-height-min-height-flex-row.html](https://wpt.fyi/results/css/css-contain/contain-size-grid-indefinite-height-min-height-flex-row.html "css/css-contain/contain-size-grid-indefinite-height-min-height-flex-row.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-grid-indefinite-height-min-height-flex-row.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-grid-indefinite-height-min-height-flex-row.html)
 - [contain-size-grid-stretches-auto-rows.html](https://wpt.fyi/results/css/css-contain/contain-size-grid-stretches-auto-rows.html "css/css-contain/contain-size-grid-stretches-auto-rows.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-grid-stretches-auto-rows.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-grid-stretches-auto-rows.html)

[inline-size]

: This value turns on [inline-size
 containment](#inline-size-containment) for the element. This prevents the
 [inline-size](https://drafts.csswg.org/css-writing-modes-4/#inline-size) of its [principal
 box](https://drafts.csswg.org/css-display-4/#principal-box) from directly depending on its contents.

 Tests

 - [contain-inline-size-bfc-floats-001.html](https://wpt.fyi/results/css/css-contain/contain-inline-size-bfc-floats-001.html "css/css-contain/contain-inline-size-bfc-floats-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-inline-size-bfc-floats-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-inline-size-bfc-floats-001.html)
 - [contain-inline-size-bfc-floats-002.html](https://wpt.fyi/results/css/css-contain/contain-inline-size-bfc-floats-002.html "css/css-contain/contain-inline-size-bfc-floats-002.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-inline-size-bfc-floats-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-inline-size-bfc-floats-002.html)
 - [contain-inline-size-fieldset.html](https://wpt.fyi/results/css/css-contain/contain-inline-size-fieldset.html "css/css-contain/contain-inline-size-fieldset.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-inline-size-fieldset.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-inline-size-fieldset.html)
 - [contain-inline-size-flex.html](https://wpt.fyi/results/css/css-contain/contain-inline-size-flex.html "css/css-contain/contain-inline-size-flex.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-inline-size-flex.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-inline-size-flex.html)
 - [contain-inline-size-flexitem.html](https://wpt.fyi/results/css/css-contain/contain-inline-size-flexitem.html "css/css-contain/contain-inline-size-flexitem.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-inline-size-flexitem.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-inline-size-flexitem.html)
 - [contain-inline-size-grid.html](https://wpt.fyi/results/css/css-contain/contain-inline-size-grid.html "css/css-contain/contain-inline-size-grid.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-inline-size-grid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-inline-size-grid.html)
 - [contain-inline-size-intrinsic.html](https://wpt.fyi/results/css/css-contain/contain-inline-size-intrinsic.html "css/css-contain/contain-inline-size-intrinsic.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-inline-size-intrinsic.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-inline-size-intrinsic.html)
 - [contain-inline-size-legend.html](https://wpt.fyi/results/css/css-contain/contain-inline-size-legend.html "css/css-contain/contain-inline-size-legend.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-inline-size-legend.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-inline-size-legend.html)
 - [contain-inline-size-multicol.html](https://wpt.fyi/results/css/css-contain/contain-inline-size-multicol.html "css/css-contain/contain-inline-size-multicol.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-inline-size-multicol.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-inline-size-multicol.html)
 - [contain-inline-size-regular-container.html](https://wpt.fyi/results/css/css-contain/contain-inline-size-regular-container.html "css/css-contain/contain-inline-size-regular-container.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-inline-size-regular-container.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-inline-size-regular-container.html)
 - [contain-inline-size-removed.html](https://wpt.fyi/results/css/css-contain/contain-inline-size-removed.html "css/css-contain/contain-inline-size-removed.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-inline-size-removed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-inline-size-removed.html)
 - [contain-inline-size-replaced.html](https://wpt.fyi/results/css/css-contain/contain-inline-size-replaced.html "css/css-contain/contain-inline-size-replaced.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-inline-size-replaced.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-inline-size-replaced.html)
 - [contain-inline-size-table.html](https://wpt.fyi/results/css/css-contain/contain-inline-size-table.html "css/css-contain/contain-inline-size-table.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-inline-size-table.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-inline-size-table.html)
 - [contain-inline-size-vertical-rl-.html](https://wpt.fyi/results/css/css-contain/contain-inline-size-vertical-rl-.html "css/css-contain/contain-inline-size-vertical-rl-.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-inline-size-vertical-rl-.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-inline-size-vertical-rl-.html)
 - [contain-inline-size-grid-indefinite-height-min-height-flex-row.html](https://wpt.fyi/results/css/css-contain/contain-inline-size-grid-indefinite-height-min-height-flex-row.html "css/css-contain/contain-inline-size-grid-indefinite-height-min-height-flex-row.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-inline-size-grid-indefinite-height-min-height-flex-row.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-inline-size-grid-indefinite-height-min-height-flex-row.html)
 - [contain-inline-size-grid-stretches-auto-rows.html](https://wpt.fyi/results/css/css-contain/contain-inline-size-grid-stretches-auto-rows.html "css/css-contain/contain-inline-size-grid-stretches-auto-rows.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-inline-size-grid-stretches-auto-rows.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-inline-size-grid-stretches-auto-rows.html)

 There can still be indirect dependencies, see
 [§ 3.2 Inline-Size Containment](#containment-inline-size).

[layout]
: This value turns on [layout
 containment](#layout-containment) for the element. This ensures that the [containment
 box](#layout-containment-box) is *totally opaque* for layout purposes; nothing
 outside can affect its internal layout, and vice versa.
 Tests
 - [contain-layout-001.html](https://wpt.fyi/results/css/css-contain/contain-layout-001.html "css/css-contain/contain-layout-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-001.html)
 - [contain-layout-002.html](https://wpt.fyi/results/css/css-contain/contain-layout-002.html "css/css-contain/contain-layout-002.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-002.html)
 - [contain-layout-003.html](https://wpt.fyi/results/css/css-contain/contain-layout-003.html "css/css-contain/contain-layout-003.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-003.html)
 - [contain-layout-004.html](https://wpt.fyi/results/css/css-contain/contain-layout-004.html "css/css-contain/contain-layout-004.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-004.html)
 - [contain-layout-005.html](https://wpt.fyi/results/css/css-contain/contain-layout-005.html "css/css-contain/contain-layout-005.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-005.html)
 - [contain-layout-006.html](https://wpt.fyi/results/css/css-contain/contain-layout-006.html "css/css-contain/contain-layout-006.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-006.html)
 - [contain-layout-007.html](https://wpt.fyi/results/css/css-contain/contain-layout-007.html "css/css-contain/contain-layout-007.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-007.html)
 - [contain-layout-009.html](https://wpt.fyi/results/css/css-contain/contain-layout-009.html "css/css-contain/contain-layout-009.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-009.html)
 - [contain-layout-010.html](https://wpt.fyi/results/css/css-contain/contain-layout-010.html "css/css-contain/contain-layout-010.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-010.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-010.html)
 - [contain-layout-011.html](https://wpt.fyi/results/css/css-contain/contain-layout-011.html "css/css-contain/contain-layout-011.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-011.html)
 - [contain-layout-012.html](https://wpt.fyi/results/css/css-contain/contain-layout-012.html "css/css-contain/contain-layout-012.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-012.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-012.html)
 - [contain-layout-013.html](https://wpt.fyi/results/css/css-contain/contain-layout-013.html "css/css-contain/contain-layout-013.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-013.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-013.html)
 - [contain-layout-014.html](https://wpt.fyi/results/css/css-contain/contain-layout-014.html "css/css-contain/contain-layout-014.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-014.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-014.html)
 - [contain-layout-016.html](https://wpt.fyi/results/css/css-contain/contain-layout-016.html "css/css-contain/contain-layout-016.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-016.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-016.html)
 - [contain-layout-017.html](https://wpt.fyi/results/css/css-contain/contain-layout-017.html "css/css-contain/contain-layout-017.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-017.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-017.html)
 - [contain-layout-018.html](https://wpt.fyi/results/css/css-contain/contain-layout-018.html "css/css-contain/contain-layout-018.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-018.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-018.html)
 - [contain-layout-019.html](https://wpt.fyi/results/css/css-contain/contain-layout-019.html "css/css-contain/contain-layout-019.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-019.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-019.html)
 - [contain-layout-020.html](https://wpt.fyi/results/css/css-contain/contain-layout-020.html "css/css-contain/contain-layout-020.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-020.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-020.html)
 - [contain-layout-021.html](https://wpt.fyi/results/css/css-contain/contain-layout-021.html "css/css-contain/contain-layout-021.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-021.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-021.html)
 - [contain-layout-baseline-001.html](https://wpt.fyi/results/css/css-contain/contain-layout-baseline-001.html "css/css-contain/contain-layout-baseline-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-baseline-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-baseline-001.html)
 - [contain-layout-baseline-002.html](https://wpt.fyi/results/css/css-contain/contain-layout-baseline-002.html "css/css-contain/contain-layout-baseline-002.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-baseline-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-baseline-002.html)
 - [contain-layout-baseline-003.html](https://wpt.fyi/results/css/css-contain/contain-layout-baseline-003.html "css/css-contain/contain-layout-baseline-003.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-baseline-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-baseline-003.html)
 - [contain-layout-baseline-004.html](https://wpt.fyi/results/css/css-contain/contain-layout-baseline-004.html "css/css-contain/contain-layout-baseline-004.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-baseline-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-baseline-004.html)
 - [contain-layout-baseline-005.html](https://wpt.fyi/results/css/css-contain/contain-layout-baseline-005.html "css/css-contain/contain-layout-baseline-005.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-baseline-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-baseline-005.html)
 - [contain-layout-breaks-001.html](https://wpt.fyi/results/css/css-contain/contain-layout-breaks-001.html "css/css-contain/contain-layout-breaks-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-breaks-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-breaks-001.html)
 - [contain-layout-breaks-002.html](https://wpt.fyi/results/css/css-contain/contain-layout-breaks-002.html "css/css-contain/contain-layout-breaks-002.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-breaks-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-breaks-002.html)
 - [contain-layout-cell-001.html](https://wpt.fyi/results/css/css-contain/contain-layout-cell-001.html "css/css-contain/contain-layout-cell-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-cell-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-cell-001.html)
 - [contain-layout-cell-002.html](https://wpt.fyi/results/css/css-contain/contain-layout-cell-002.html "css/css-contain/contain-layout-cell-002.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-cell-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-cell-002.html)
 - [contain-layout-flexbox-001.html](https://wpt.fyi/results/css/css-contain/contain-layout-flexbox-001.html "css/css-contain/contain-layout-flexbox-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-flexbox-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-flexbox-001.html)
 - [contain-layout-grid-001.html](https://wpt.fyi/results/css/css-contain/contain-layout-grid-001.html "css/css-contain/contain-layout-grid-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-grid-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-grid-001.html)
 - [contain-layout-ifc-022.html](https://wpt.fyi/results/css/css-contain/contain-layout-ifc-022.html "css/css-contain/contain-layout-ifc-022.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-ifc-022.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-ifc-022.html)
 - [contain-layout-independent-formatting-context-001.html](https://wpt.fyi/results/css/css-contain/contain-layout-independent-formatting-context-001.html "css/css-contain/contain-layout-independent-formatting-context-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-independent-formatting-context-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-independent-formatting-context-001.html)
 - [contain-layout-independent-formatting-context-002.html](https://wpt.fyi/results/css/css-contain/contain-layout-independent-formatting-context-002.html "css/css-contain/contain-layout-independent-formatting-context-002.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-independent-formatting-context-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-independent-formatting-context-002.html)
 - [contain-layout-independent-formatting-context-003.html](https://wpt.fyi/results/css/css-contain/contain-layout-independent-formatting-context-003.html "css/css-contain/contain-layout-independent-formatting-context-003.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-independent-formatting-context-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-independent-formatting-context-003.html)
 - [contain-layout-ink-overflow-013.html](https://wpt.fyi/results/css/css-contain/contain-layout-ink-overflow-013.html "css/css-contain/contain-layout-ink-overflow-013.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-ink-overflow-013.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-ink-overflow-013.html)
 - [contain-layout-ink-overflow-014.html](https://wpt.fyi/results/css/css-contain/contain-layout-ink-overflow-014.html "css/css-contain/contain-layout-ink-overflow-014.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-ink-overflow-014.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-ink-overflow-014.html)
 - [contain-layout-ink-overflow-015.html](https://wpt.fyi/results/css/css-contain/contain-layout-ink-overflow-015.html "css/css-contain/contain-layout-ink-overflow-015.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-ink-overflow-015.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-ink-overflow-015.html)
 - [contain-layout-ink-overflow-016.html](https://wpt.fyi/results/css/css-contain/contain-layout-ink-overflow-016.html "css/css-contain/contain-layout-ink-overflow-016.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-ink-overflow-016.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-ink-overflow-016.html)
 - [contain-layout-ink-overflow-017.html](https://wpt.fyi/results/css/css-contain/contain-layout-ink-overflow-017.html "css/css-contain/contain-layout-ink-overflow-017.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-ink-overflow-017.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-ink-overflow-017.html)
 - [contain-layout-ink-overflow-018.html](https://wpt.fyi/results/css/css-contain/contain-layout-ink-overflow-018.html "css/css-contain/contain-layout-ink-overflow-018.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-ink-overflow-018.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-ink-overflow-018.html)
 - [contain-layout-ink-overflow-019.html](https://wpt.fyi/results/css/css-contain/contain-layout-ink-overflow-019.html "css/css-contain/contain-layout-ink-overflow-019.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-ink-overflow-019.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-ink-overflow-019.html)
 - [contain-layout-ink-overflow-020.html](https://wpt.fyi/results/css/css-contain/contain-layout-ink-overflow-020.html "css/css-contain/contain-layout-ink-overflow-020.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-ink-overflow-020.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-ink-overflow-020.html)
 - [contain-layout-size-003.html](https://wpt.fyi/results/css/css-contain/contain-layout-size-003.html "css/css-contain/contain-layout-size-003.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-size-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-size-003.html)
 - [contain-subgrid-001.html](https://wpt.fyi/results/css/css-contain/contain-subgrid-001.html "css/css-contain/contain-subgrid-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-subgrid-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-subgrid-001.html)
 - [contain-layout-dynamic-001.html](https://wpt.fyi/results/css/css-contain/contain-layout-dynamic-001.html "css/css-contain/contain-layout-dynamic-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-dynamic-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-dynamic-001.html)
 - [contain-layout-dynamic-004.html](https://wpt.fyi/results/css/css-contain/contain-layout-dynamic-004.html "css/css-contain/contain-layout-dynamic-004.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-dynamic-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-dynamic-004.html)
 - [contain-layout-dynamic-005.html](https://wpt.fyi/results/css/css-contain/contain-layout-dynamic-005.html "css/css-contain/contain-layout-dynamic-005.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-dynamic-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-dynamic-005.html)

[style]
: This value turns on [style
 containment](#style-containment) for the element. This ensures that, for properties
 which can have effects on more than just an element and its
 descendants, those effects don't escape the element.
 Tests
 - [contain-style-baseline-001.html](https://wpt.fyi/results/css/css-contain/contain-style-baseline-001.html "css/css-contain/contain-style-baseline-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-style-baseline-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-style-baseline-001.html)
 - [contain-style-breaks-001.html](https://wpt.fyi/results/css/css-contain/contain-style-breaks-001.html "css/css-contain/contain-style-breaks-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-style-breaks-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-style-breaks-001.html)
 - [contain-style-breaks-002.html](https://wpt.fyi/results/css/css-contain/contain-style-breaks-002.html "css/css-contain/contain-style-breaks-002.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-style-breaks-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-style-breaks-002.html)
 - [contain-style-breaks-003.html](https://wpt.fyi/results/css/css-contain/contain-style-breaks-003.html "css/css-contain/contain-style-breaks-003.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-style-breaks-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-style-breaks-003.html)
 - [contain-style-breaks-004.html](https://wpt.fyi/results/css/css-contain/contain-style-breaks-004.html "css/css-contain/contain-style-breaks-004.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-style-breaks-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-style-breaks-004.html)
 - [contain-style-breaks-005.html](https://wpt.fyi/results/css/css-contain/contain-style-breaks-005.html "css/css-contain/contain-style-breaks-005.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-style-breaks-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-style-breaks-005.html)
 - [contain-style-counters-001.html](https://wpt.fyi/results/css/css-contain/contain-style-counters-001.html "css/css-contain/contain-style-counters-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-style-counters-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-style-counters-001.html)
 - [contain-style-counters-002.html](https://wpt.fyi/results/css/css-contain/contain-style-counters-002.html "css/css-contain/contain-style-counters-002.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-style-counters-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-style-counters-002.html)
 - [contain-style-counters-003.html](https://wpt.fyi/results/css/css-contain/contain-style-counters-003.html "css/css-contain/contain-style-counters-003.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-style-counters-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-style-counters-003.html)
 - [contain-style-counters-004.html](https://wpt.fyi/results/css/css-contain/contain-style-counters-004.html "css/css-contain/contain-style-counters-004.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-style-counters-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-style-counters-004.html)
 - [contain-style-counters-005.html](https://wpt.fyi/results/css/css-contain/contain-style-counters-005.html "css/css-contain/contain-style-counters-005.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-style-counters-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-style-counters-005.html)
 - [contain-style-ol-ordinal-li-container.html](https://wpt.fyi/results/css/css-contain/contain-style-ol-ordinal-li-container.html "css/css-contain/contain-style-ol-ordinal-li-container.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-style-ol-ordinal-li-container.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-style-ol-ordinal-li-container.html)
 - [contain-style-ol-ordinal-pseudo-reversed.html](https://wpt.fyi/results/css/css-contain/contain-style-ol-ordinal-pseudo-reversed.html "css/css-contain/contain-style-ol-ordinal-pseudo-reversed.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-style-ol-ordinal-pseudo-reversed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-style-ol-ordinal-pseudo-reversed.html)
 - [contain-style-ol-ordinal-pseudo.html](https://wpt.fyi/results/css/css-contain/contain-style-ol-ordinal-pseudo.html "css/css-contain/contain-style-ol-ordinal-pseudo.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-style-ol-ordinal-pseudo.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-style-ol-ordinal-pseudo.html)
 - [contain-style-ol-ordinal-reversed.html](https://wpt.fyi/results/css/css-contain/contain-style-ol-ordinal-reversed.html "css/css-contain/contain-style-ol-ordinal-reversed.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-style-ol-ordinal-reversed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-style-ol-ordinal-reversed.html)
 - [contain-style-ol-ordinal-start-reversed.html](https://wpt.fyi/results/css/css-contain/contain-style-ol-ordinal-start-reversed.html "css/css-contain/contain-style-ol-ordinal-start-reversed.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-style-ol-ordinal-start-reversed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-style-ol-ordinal-start-reversed.html)
 - [contain-style-ol-ordinal-start.html](https://wpt.fyi/results/css/css-contain/contain-style-ol-ordinal-start.html "css/css-contain/contain-style-ol-ordinal-start.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-style-ol-ordinal-start.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-style-ol-ordinal-start.html)
 - [contain-style-ol-ordinal.html](https://wpt.fyi/results/css/css-contain/contain-style-ol-ordinal.html "css/css-contain/contain-style-ol-ordinal.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-style-ol-ordinal.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-style-ol-ordinal.html)
 - [counter-scoping-001.html](https://wpt.fyi/results/css/css-contain/counter-scoping-001.html "css/css-contain/counter-scoping-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/counter-scoping-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/counter-scoping-001.html)
 - [counter-scoping-002.html](https://wpt.fyi/results/css/css-contain/counter-scoping-002.html "css/css-contain/counter-scoping-002.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/counter-scoping-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/counter-scoping-002.html)
 - [counter-scoping-003.html](https://wpt.fyi/results/css/css-contain/counter-scoping-003.html "css/css-contain/counter-scoping-003.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/counter-scoping-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/counter-scoping-003.html)
 - [counter-scoping-004.html](https://wpt.fyi/results/css/css-contain/counter-scoping-004.html "css/css-contain/counter-scoping-004.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/counter-scoping-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/counter-scoping-004.html)
 - [quote-scoping-001.html](https://wpt.fyi/results/css/css-contain/quote-scoping-001.html "css/css-contain/quote-scoping-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/quote-scoping-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/quote-scoping-001.html)
 - [quote-scoping-002.html](https://wpt.fyi/results/css/css-contain/quote-scoping-002.html "css/css-contain/quote-scoping-002.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/quote-scoping-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/quote-scoping-002.html)
 - [quote-scoping-003.html](https://wpt.fyi/results/css/css-contain/quote-scoping-003.html "css/css-contain/quote-scoping-003.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/quote-scoping-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/quote-scoping-003.html)
 - [quote-scoping-004.html](https://wpt.fyi/results/css/css-contain/quote-scoping-004.html "css/css-contain/quote-scoping-004.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/quote-scoping-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/quote-scoping-004.html)
 - [quote-scoping-invalidation-001.html](https://wpt.fyi/results/css/css-contain/quote-scoping-invalidation-001.html "css/css-contain/quote-scoping-invalidation-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/quote-scoping-invalidation-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/quote-scoping-invalidation-001.html)
 - [quote-scoping-invalidation-002.html](https://wpt.fyi/results/css/css-contain/quote-scoping-invalidation-002.html "css/css-contain/quote-scoping-invalidation-002.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/quote-scoping-invalidation-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/quote-scoping-invalidation-002.html)
 - [quote-scoping-invalidation-003.html](https://wpt.fyi/results/css/css-contain/quote-scoping-invalidation-003.html "css/css-contain/quote-scoping-invalidation-003.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/quote-scoping-invalidation-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/quote-scoping-invalidation-003.html)
 - [quote-scoping-invalidation-004.html](https://wpt.fyi/results/css/css-contain/quote-scoping-invalidation-004.html "css/css-contain/quote-scoping-invalidation-004.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/quote-scoping-invalidation-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/quote-scoping-invalidation-004.html)
 - [contain-style-dynamic-001.html](https://wpt.fyi/results/css/css-contain/contain-style-dynamic-001.html "css/css-contain/contain-style-dynamic-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-style-dynamic-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-style-dynamic-001.html)

[paint]
: This value turns on [paint
 containment](#paint-containment) for the element. This ensures that the descendants
 of the [containment
 box](#paint-containment-box) don't display outside its bounds, so if an element
 is off-screen or otherwise not visible, its descendants are also
 guaranteed to be not visible.
 Tests
 - [contain-paint-001.html](https://wpt.fyi/results/css/css-contain/contain-paint-001.html "css/css-contain/contain-paint-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-001.html)
 - [contain-paint-002.html](https://wpt.fyi/results/css/css-contain/contain-paint-002.html "css/css-contain/contain-paint-002.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-002.html)
 - [contain-paint-004.html](https://wpt.fyi/results/css/css-contain/contain-paint-004.html "css/css-contain/contain-paint-004.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-004.html)
 - [contain-paint-005.html](https://wpt.fyi/results/css/css-contain/contain-paint-005.html "css/css-contain/contain-paint-005.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-005.html)
 - [contain-paint-006.html](https://wpt.fyi/results/css/css-contain/contain-paint-006.html "css/css-contain/contain-paint-006.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-006.html)
 - [contain-paint-007.html](https://wpt.fyi/results/css/css-contain/contain-paint-007.html "css/css-contain/contain-paint-007.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-007.html)
 - [contain-paint-008.html](https://wpt.fyi/results/css/css-contain/contain-paint-008.html "css/css-contain/contain-paint-008.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-008.html)
 - [contain-paint-009.html](https://wpt.fyi/results/css/css-contain/contain-paint-009.html "css/css-contain/contain-paint-009.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-009.html)
 - [contain-paint-010.html](https://wpt.fyi/results/css/css-contain/contain-paint-010.html "css/css-contain/contain-paint-010.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-010.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-010.html)
 - [contain-paint-011.html](https://wpt.fyi/results/css/css-contain/contain-paint-011.html "css/css-contain/contain-paint-011.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-011.html)
 - [contain-paint-012.html](https://wpt.fyi/results/css/css-contain/contain-paint-012.html "css/css-contain/contain-paint-012.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-012.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-012.html)
 - [contain-paint-014.html](https://wpt.fyi/results/css/css-contain/contain-paint-014.html "css/css-contain/contain-paint-014.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-014.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-014.html)
 - [contain-paint-015.html](https://wpt.fyi/results/css/css-contain/contain-paint-015.html "css/css-contain/contain-paint-015.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-015.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-015.html)
 - [contain-paint-016.html](https://wpt.fyi/results/css/css-contain/contain-paint-016.html "css/css-contain/contain-paint-016.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-016.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-016.html)
 - [contain-paint-017.html](https://wpt.fyi/results/css/css-contain/contain-paint-017.html "css/css-contain/contain-paint-017.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-017.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-017.html)
 - [contain-paint-018.html](https://wpt.fyi/results/css/css-contain/contain-paint-018.html "css/css-contain/contain-paint-018.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-018.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-018.html)
 - [contain-paint-019.html](https://wpt.fyi/results/css/css-contain/contain-paint-019.html "css/css-contain/contain-paint-019.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-019.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-019.html)
 - [contain-paint-020.html](https://wpt.fyi/results/css/css-contain/contain-paint-020.html "css/css-contain/contain-paint-020.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-020.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-020.html)
 - [contain-paint-021.html](https://wpt.fyi/results/css/css-contain/contain-paint-021.html "css/css-contain/contain-paint-021.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-021.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-021.html)
 - [contain-paint-022.html](https://wpt.fyi/results/css/css-contain/contain-paint-022.html "css/css-contain/contain-paint-022.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-022.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-022.html)
 - [contain-paint-023.html](https://wpt.fyi/results/css/css-contain/contain-paint-023.html "css/css-contain/contain-paint-023.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-023.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-023.html)
 - [contain-paint-024.html](https://wpt.fyi/results/css/css-contain/contain-paint-024.html "css/css-contain/contain-paint-024.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-024.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-024.html)
 - [contain-paint-025.html](https://wpt.fyi/results/css/css-contain/contain-paint-025.html "css/css-contain/contain-paint-025.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-025.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-025.html)
 - [contain-paint-047.html](https://wpt.fyi/results/css/css-contain/contain-paint-047.html "css/css-contain/contain-paint-047.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-047.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-047.html)
 - [contain-paint-048.html](https://wpt.fyi/results/css/css-contain/contain-paint-048.html "css/css-contain/contain-paint-048.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-048.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-048.html)
 - [contain-paint-baseline-001.html](https://wpt.fyi/results/css/css-contain/contain-paint-baseline-001.html "css/css-contain/contain-paint-baseline-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-baseline-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-baseline-001.html)
 - [contain-paint-cell-001.html](https://wpt.fyi/results/css/css-contain/contain-paint-cell-001.html "css/css-contain/contain-paint-cell-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-cell-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-cell-001.html)
 - [contain-paint-cell-002.html](https://wpt.fyi/results/css/css-contain/contain-paint-cell-002.html "css/css-contain/contain-paint-cell-002.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-cell-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-cell-002.html)
 - [contain-paint-clip-011.html](https://wpt.fyi/results/css/css-contain/contain-paint-clip-011.html "css/css-contain/contain-paint-clip-011.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-clip-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-clip-011.html)
 - [contain-paint-clip-012.html](https://wpt.fyi/results/css/css-contain/contain-paint-clip-012.html "css/css-contain/contain-paint-clip-012.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-clip-012.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-clip-012.html)
 - [contain-paint-clip-013.html](https://wpt.fyi/results/css/css-contain/contain-paint-clip-013.html "css/css-contain/contain-paint-clip-013.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-clip-013.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-clip-013.html)
 - [contain-paint-clip-014.html](https://wpt.fyi/results/css/css-contain/contain-paint-clip-014.html "css/css-contain/contain-paint-clip-014.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-clip-014.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-clip-014.html)
 - [contain-paint-clip-015.html](https://wpt.fyi/results/css/css-contain/contain-paint-clip-015.html "css/css-contain/contain-paint-clip-015.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-clip-015.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-clip-015.html)
 - [contain-paint-clip-016.html](https://wpt.fyi/results/css/css-contain/contain-paint-clip-016.html "css/css-contain/contain-paint-clip-016.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-clip-016.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-clip-016.html)
 - [contain-paint-clip-017.html](https://wpt.fyi/results/css/css-contain/contain-paint-clip-017.html "css/css-contain/contain-paint-clip-017.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-clip-017.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-clip-017.html)
 - [contain-paint-clip-018.html](https://wpt.fyi/results/css/css-contain/contain-paint-clip-018.html "css/css-contain/contain-paint-clip-018.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-clip-018.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-clip-018.html)
 - [contain-paint-clip-019.html](https://wpt.fyi/results/css/css-contain/contain-paint-clip-019.html "css/css-contain/contain-paint-clip-019.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-clip-019.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-clip-019.html)
 - [contain-paint-ifc-011.html](https://wpt.fyi/results/css/css-contain/contain-paint-ifc-011.html "css/css-contain/contain-paint-ifc-011.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-ifc-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-ifc-011.html)
 - [contain-paint-independent-formatting-context-001.html](https://wpt.fyi/results/css/css-contain/contain-paint-independent-formatting-context-001.html "css/css-contain/contain-paint-independent-formatting-context-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-independent-formatting-context-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-independent-formatting-context-001.html)
 - [contain-paint-independent-formatting-context-002.html](https://wpt.fyi/results/css/css-contain/contain-paint-independent-formatting-context-002.html "css/css-contain/contain-paint-independent-formatting-context-002.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-independent-formatting-context-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-independent-formatting-context-002.html)
 - [contain-paint-independent-formatting-context-003.html](https://wpt.fyi/results/css/css-contain/contain-paint-independent-formatting-context-003.html "css/css-contain/contain-paint-independent-formatting-context-003.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-independent-formatting-context-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-independent-formatting-context-003.html)
 - [contain-paint-size-001.html](https://wpt.fyi/results/css/css-contain/contain-paint-size-001.html "css/css-contain/contain-paint-size-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-size-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-size-001.html)
 - [contain-paint-size-002.html](https://wpt.fyi/results/css/css-contain/contain-paint-size-002.html "css/css-contain/contain-paint-size-002.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-size-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-size-002.html)
 - [contain-paint-size-003.html](https://wpt.fyi/results/css/css-contain/contain-paint-size-003.html "css/css-contain/contain-paint-size-003.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-size-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-size-003.html)
 - [contain-paint-table-001.html](https://wpt.fyi/results/css/css-contain/contain-paint-table-001.html "css/css-contain/contain-paint-table-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-table-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-table-001.html)
 - [contain-paint-table-002.html](https://wpt.fyi/results/css/css-contain/contain-paint-table-002.html "css/css-contain/contain-paint-table-002.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-table-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-table-002.html)
 - [contain-subgrid-001.html](https://wpt.fyi/results/css/css-contain/contain-subgrid-001.html "css/css-contain/contain-subgrid-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-subgrid-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-subgrid-001.html)
 - [contain-paint-change-opacity.html](https://wpt.fyi/results/css/css-contain/contain-paint-change-opacity.html "css/css-contain/contain-paint-change-opacity.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-change-opacity.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-change-opacity.html)
 - [contain-paint-dynamic-001.html](https://wpt.fyi/results/css/css-contain/contain-paint-dynamic-001.html "css/css-contain/contain-paint-dynamic-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-dynamic-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-dynamic-001.html)
 - [contain-paint-dynamic-002.html](https://wpt.fyi/results/css/css-contain/contain-paint-dynamic-002.html "css/css-contain/contain-paint-dynamic-002.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-dynamic-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-dynamic-002.html)
 - [contain-paint-dynamic-003.html](https://wpt.fyi/results/css/css-contain/contain-paint-dynamic-003.html "css/css-contain/contain-paint-dynamic-003.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-dynamic-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-dynamic-003.html)
 - [contain-paint-dynamic-004.html](https://wpt.fyi/results/css/css-contain/contain-paint-dynamic-004.html "css/css-contain/contain-paint-dynamic-004.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-dynamic-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-dynamic-004.html)
 - [contain-paint-dynamic-005.html](https://wpt.fyi/results/css/css-contain/contain-paint-dynamic-005.html "css/css-contain/contain-paint-dynamic-005.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-dynamic-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-dynamic-005.html)

[This property generally applies to all elements (including [CSS
Pseudo-Elements 4 § 4.1 Generated Content Pseudo-elements: ::before and
::after](https://drafts.csswg.org/css-pseudo-4/#generated-content))],
although some types of containment have no effect on some elements, as
detailed in [§ 3 Types of Containment](#containment-types). In addition,
in the case of
[\[SVG2\]](#biblio-svg2 "Scalable Vector Graphics (SVG) 2"),
the [contain](#propdef-contain) property only applies to
[`svg`](https://w3c.github.io/svgwg/svg2-draft/struct.html#elementdef-svg) elements that have an associated CSS layout box.

[contain](#propdef-contain) is useful when used widely on a page, particularly
when a page contains a lot of \"widgets\" which are all independent.

For example, assume a micropost social network had markup something like
this:

``` highlight
<body>
 <aside>...</aside>
 <section>
 <h2>Messages</h2>
 <article>
 Lol, check out this dog: images.example.com/jsK3jkl
 </article>
 <article>
 I had a ham sandwich today. #goodtimes
 </article>
 <article>
 I have political opinions that you need to hear!
 </article>
 …
 </section>
</body>
```

There are probably a *lot* of messages displayed on the site, but each
is independent and won't affect anything else on the site. As such, each
can be marked with [contain:
content](#propdef-contain) to communicate this to the user agent, so it can
optimize the page and skip a lot of computation for messages that are
off-screen. If the size of each message is known ahead of time,
[contain: strict] can be applied to
communicate further restrictions.

Additionally, when any
[containments](#containment) are
active on either the HTML
[`html`](https://html.spec.whatwg.org/multipage/semantics.html#the-html-element) or
[`body`](https://html.spec.whatwg.org/multipage/sections.html#the-body-element) elements, propagation of properties from the
[`body`](https://html.spec.whatwg.org/multipage/sections.html#the-body-element) element to the [initial containing
block](https://drafts.csswg.org/css-display-4/#initial-containing-block), the viewport, or the [canvas
background](https://drafts.csswg.org/css-backgrounds-3/#canvas-background), is disabled. Notably, this affects:

- [writing-mode](https://drafts.csswg.org/css-writing-modes-4/#propdef-writing-mode),
 [direction](https://drafts.csswg.org/css-writing-modes-3/#propdef-direction), and
 [text-orientation](https://drafts.csswg.org/css-writing-modes-4/#propdef-text-orientation) (see [CSS Writing Modes 3 § 8 The
 Principal Writing
 Mode](https://drafts.csswg.org/css-writing-modes-3/#principal-flow))

- [overflow](https://drafts.csswg.org/css-overflow-3/#propdef-overflow) and its longhands (see [CSS
 Overflow 3 § 3.1.4 Overflow Viewport
 Propagation](https://drafts.csswg.org/css-overflow-3/#overflow-propagation))

- [background](https://drafts.csswg.org/css-backgrounds-3/#propdef-background) and its longhands (see [CSS
 Backgrounds 3 § 2.11.2 The Canvas Background and the HTML \<body\>
 Element](https://drafts.csswg.org/css-backgrounds-3/#body-background))

Tests

- [contain-body-bg-001.html](https://wpt.fyi/results/css/css-contain/contain-body-bg-001.html "css/css-contain/contain-body-bg-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-body-bg-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-body-bg-001.html)
- [contain-body-bg-002.html](https://wpt.fyi/results/css/css-contain/contain-body-bg-002.html "css/css-contain/contain-body-bg-002.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-body-bg-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-body-bg-002.html)
- [contain-body-bg-003.html](https://wpt.fyi/results/css/css-contain/contain-body-bg-003.html "css/css-contain/contain-body-bg-003.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-body-bg-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-body-bg-003.html)
- [contain-body-bg-004.html](https://wpt.fyi/results/css/css-contain/contain-body-bg-004.html "css/css-contain/contain-body-bg-004.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-body-bg-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-body-bg-004.html)
- [contain-body-dir-001.html](https://wpt.fyi/results/css/css-contain/contain-body-dir-001.html "css/css-contain/contain-body-dir-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-body-dir-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-body-dir-001.html)
- [contain-body-dir-002.html](https://wpt.fyi/results/css/css-contain/contain-body-dir-002.html "css/css-contain/contain-body-dir-002.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-body-dir-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-body-dir-002.html)
- [contain-body-dir-003.html](https://wpt.fyi/results/css/css-contain/contain-body-dir-003.html "css/css-contain/contain-body-dir-003.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-body-dir-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-body-dir-003.html)
- [contain-body-dir-004.html](https://wpt.fyi/results/css/css-contain/contain-body-dir-004.html "css/css-contain/contain-body-dir-004.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-body-dir-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-body-dir-004.html)
- [contain-body-overflow-001.html](https://wpt.fyi/results/css/css-contain/contain-body-overflow-001.html "css/css-contain/contain-body-overflow-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-body-overflow-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-body-overflow-001.html)
- [contain-body-overflow-002.html](https://wpt.fyi/results/css/css-contain/contain-body-overflow-002.html "css/css-contain/contain-body-overflow-002.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-body-overflow-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-body-overflow-002.html)
- [contain-body-overflow-003.html](https://wpt.fyi/results/css/css-contain/contain-body-overflow-003.html "css/css-contain/contain-body-overflow-003.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-body-overflow-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-body-overflow-003.html)
- [contain-body-overflow-004.html](https://wpt.fyi/results/css/css-contain/contain-body-overflow-004.html "css/css-contain/contain-body-overflow-004.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-body-overflow-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-body-overflow-004.html)
- [contain-body-t-o-001.html](https://wpt.fyi/results/css/css-contain/contain-body-t-o-001.html "css/css-contain/contain-body-t-o-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-body-t-o-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-body-t-o-001.html)
- [contain-body-t-o-002.html](https://wpt.fyi/results/css/css-contain/contain-body-t-o-002.html "css/css-contain/contain-body-t-o-002.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-body-t-o-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-body-t-o-002.html)
- [contain-body-t-o-003.html](https://wpt.fyi/results/css/css-contain/contain-body-t-o-003.html "css/css-contain/contain-body-t-o-003.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-body-t-o-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-body-t-o-003.html)
- [contain-body-t-o-004.html](https://wpt.fyi/results/css/css-contain/contain-body-t-o-004.html "css/css-contain/contain-body-t-o-004.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-body-t-o-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-body-t-o-004.html)
- [contain-body-w-m-001.html](https://wpt.fyi/results/css/css-contain/contain-body-w-m-001.html "css/css-contain/contain-body-w-m-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-body-w-m-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-body-w-m-001.html)
- [contain-body-w-m-002.html](https://wpt.fyi/results/css/css-contain/contain-body-w-m-002.html "css/css-contain/contain-body-w-m-002.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-body-w-m-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-body-w-m-002.html)
- [contain-body-w-m-003.html](https://wpt.fyi/results/css/css-contain/contain-body-w-m-003.html "css/css-contain/contain-body-w-m-003.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-body-w-m-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-body-w-m-003.html)
- [contain-body-w-m-004.html](https://wpt.fyi/results/css/css-contain/contain-body-w-m-004.html "css/css-contain/contain-body-w-m-004.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-body-w-m-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-body-w-m-004.html)
- [contain-html-bg-001.html](https://wpt.fyi/results/css/css-contain/contain-html-bg-001.html "css/css-contain/contain-html-bg-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-html-bg-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-html-bg-001.html)
- [contain-html-bg-002.html](https://wpt.fyi/results/css/css-contain/contain-html-bg-002.html "css/css-contain/contain-html-bg-002.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-html-bg-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-html-bg-002.html)
- [contain-html-bg-003.html](https://wpt.fyi/results/css/css-contain/contain-html-bg-003.html "css/css-contain/contain-html-bg-003.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-html-bg-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-html-bg-003.html)
- [contain-html-bg-004.html](https://wpt.fyi/results/css/css-contain/contain-html-bg-004.html "css/css-contain/contain-html-bg-004.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-html-bg-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-html-bg-004.html)
- [contain-html-dir-001.html](https://wpt.fyi/results/css/css-contain/contain-html-dir-001.html "css/css-contain/contain-html-dir-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-html-dir-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-html-dir-001.html)
- [contain-html-dir-002.html](https://wpt.fyi/results/css/css-contain/contain-html-dir-002.html "css/css-contain/contain-html-dir-002.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-html-dir-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-html-dir-002.html)
- [contain-html-dir-003.html](https://wpt.fyi/results/css/css-contain/contain-html-dir-003.html "css/css-contain/contain-html-dir-003.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-html-dir-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-html-dir-003.html)
- [contain-html-dir-004.html](https://wpt.fyi/results/css/css-contain/contain-html-dir-004.html "css/css-contain/contain-html-dir-004.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-html-dir-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-html-dir-004.html)
- [contain-html-overflow-001.html](https://wpt.fyi/results/css/css-contain/contain-html-overflow-001.html "css/css-contain/contain-html-overflow-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-html-overflow-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-html-overflow-001.html)
- [contain-html-overflow-002.html](https://wpt.fyi/results/css/css-contain/contain-html-overflow-002.html "css/css-contain/contain-html-overflow-002.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-html-overflow-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-html-overflow-002.html)
- [contain-html-overflow-003.html](https://wpt.fyi/results/css/css-contain/contain-html-overflow-003.html "css/css-contain/contain-html-overflow-003.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-html-overflow-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-html-overflow-003.html)
- [contain-html-overflow-004.html](https://wpt.fyi/results/css/css-contain/contain-html-overflow-004.html "css/css-contain/contain-html-overflow-004.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-html-overflow-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-html-overflow-004.html)
- [contain-html-t-o-001.html](https://wpt.fyi/results/css/css-contain/contain-html-t-o-001.html "css/css-contain/contain-html-t-o-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-html-t-o-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-html-t-o-001.html)
- [contain-html-t-o-002.html](https://wpt.fyi/results/css/css-contain/contain-html-t-o-002.html "css/css-contain/contain-html-t-o-002.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-html-t-o-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-html-t-o-002.html)
- [contain-html-t-o-003.html](https://wpt.fyi/results/css/css-contain/contain-html-t-o-003.html "css/css-contain/contain-html-t-o-003.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-html-t-o-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-html-t-o-003.html)
- [contain-html-t-o-004.html](https://wpt.fyi/results/css/css-contain/contain-html-t-o-004.html "css/css-contain/contain-html-t-o-004.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-html-t-o-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-html-t-o-004.html)
- [contain-html-w-m-001.html](https://wpt.fyi/results/css/css-contain/contain-html-w-m-001.html "css/css-contain/contain-html-w-m-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-html-w-m-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-html-w-m-001.html)
- [contain-html-w-m-002.html](https://wpt.fyi/results/css/css-contain/contain-html-w-m-002.html "css/css-contain/contain-html-w-m-002.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-html-w-m-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-html-w-m-002.html)
- [contain-html-w-m-003.html](https://wpt.fyi/results/css/css-contain/contain-html-w-m-003.html "css/css-contain/contain-html-w-m-003.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-html-w-m-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-html-w-m-003.html)
- [contain-html-w-m-004.html](https://wpt.fyi/results/css/css-contain/contain-html-w-m-004.html "css/css-contain/contain-html-w-m-004.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-html-w-m-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-html-w-m-004.html)

 Propagation to the [initial containing
block](https://drafts.csswg.org/css-display-4/#initial-containing-block), the viewport, or the [canvas
background](https://drafts.csswg.org/css-backgrounds-3/#canvas-background), of properties set on the
[`html`](https://html.spec.whatwg.org/multipage/semantics.html#the-html-element) element itself is unaffected.

 Several properties beyond
[contain](#propdef-contain) can turn on various
[containments](#containment) for
an element. These do not affect the value of
[contain]; an element can have
[contain: none] but still have [layout
containment](#layout-containment) turned on by
[content-visibility](#propdef-content-visibility), for example.

## 3. Types of Containment

There are several varieties of [containment] that an element can be subject
to, restricting the effects that its descendants can have on the rest of
the page in various ways.
[Containment](#containment)
enables much more powerful optimizations by user agents, and helps
authors compose their page out of functional units, as it limits how
widely a given change can affect a document.

**Specification authors introducing new properties or mechanisms need to
consider whether and how the various types of containment affect what
they are introducing, and include in their specification any effect not
described here.**

### 3.1. Size Containment

Giving an element [size containment] makes its [principal
box](https://drafts.csswg.org/css-display-4/#principal-box) a [size containment box] and has the following effects:

1. The [intrinsic
 sizes](https://drafts.csswg.org/css-sizing-3/#intrinsic-size) of the [size containment
 box](#size-containment-box) are determined as if the element had no content,
 following the same logic as when [sizing as if
 empty](#sizing-as-if-empty).

 This affects explicit invocations of the
 [min-content](https://drafts.csswg.org/css-sizing-3/#valdef-width-min-content) or
 [max-content](https://drafts.csswg.org/css-sizing-3/#valdef-width-max-content) keywords, as well as any calculation that
 depends on these measurement, such as sizing [[grid
 tracks](https://drafts.csswg.org/css-grid-2/#grid-track)] into which a size contained item is
 placed, or if [fit-content
 sizing](https://drafts.csswg.org/css-sizing-3/#fit-content-size) the containment box's parent.

 Tests

 - [contain-size-013.html](https://wpt.fyi/results/css/css-contain/contain-size-013.html "css/css-contain/contain-size-013.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-013.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-013.html)
 - [contain-size-041.html](https://wpt.fyi/results/css/css-contain/contain-size-041.html "css/css-contain/contain-size-041.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-041.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-041.html)
 - [contain-size-042.html](https://wpt.fyi/results/css/css-contain/contain-size-042.html "css/css-contain/contain-size-042.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-042.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-042.html)
 - [contain-size-replaced-001.html](https://wpt.fyi/results/css/css-contain/contain-size-replaced-001.html "css/css-contain/contain-size-replaced-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-replaced-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-replaced-001.html)
 - [contain-size-replaced-002.html](https://wpt.fyi/results/css/css-contain/contain-size-replaced-002.html "css/css-contain/contain-size-replaced-002.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-replaced-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-replaced-002.html)
 - [contain-size-replaced-003a.html](https://wpt.fyi/results/css/css-contain/contain-size-replaced-003a.html "css/css-contain/contain-size-replaced-003a.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-replaced-003a.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-replaced-003a.html)
 - [contain-size-replaced-003b.html](https://wpt.fyi/results/css/css-contain/contain-size-replaced-003b.html "css/css-contain/contain-size-replaced-003b.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-replaced-003b.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-replaced-003b.html)
 - [contain-size-replaced-003c.html](https://wpt.fyi/results/css/css-contain/contain-size-replaced-003c.html "css/css-contain/contain-size-replaced-003c.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-replaced-003c.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-replaced-003c.html)
 - [contain-size-replaced-004.html](https://wpt.fyi/results/css/css-contain/contain-size-replaced-004.html "css/css-contain/contain-size-replaced-004.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-replaced-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-replaced-004.html)
 - [contain-size-replaced-005.html](https://wpt.fyi/results/css/css-contain/contain-size-replaced-005.html "css/css-contain/contain-size-replaced-005.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-replaced-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-replaced-005.html)
 - [contain-size-replaced-006.html](https://wpt.fyi/results/css/css-contain/contain-size-replaced-006.html "css/css-contain/contain-size-replaced-006.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-replaced-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-replaced-006.html)
 - [contain-size-block-001.html](https://wpt.fyi/results/css/css-contain/contain-size-block-001.html "css/css-contain/contain-size-block-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-block-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-block-001.html)
 - [contain-size-block-002.html](https://wpt.fyi/results/css/css-contain/contain-size-block-002.html "css/css-contain/contain-size-block-002.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-block-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-block-002.html)
 - [contain-size-block-003.html](https://wpt.fyi/results/css/css-contain/contain-size-block-003.html "css/css-contain/contain-size-block-003.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-block-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-block-003.html)
 - [contain-size-block-004.html](https://wpt.fyi/results/css/css-contain/contain-size-block-004.html "css/css-contain/contain-size-block-004.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-block-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-block-004.html)
 - [contain-size-button-002.html](https://wpt.fyi/results/css/css-contain/contain-size-button-002.html "css/css-contain/contain-size-button-002.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-button-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-button-002.html)
 - [contain-size-fieldset-003.html](https://wpt.fyi/results/css/css-contain/contain-size-fieldset-003.html "css/css-contain/contain-size-fieldset-003.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-fieldset-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-fieldset-003.html)
 - [contain-size-flex-001.html](https://wpt.fyi/results/css/css-contain/contain-size-flex-001.html "css/css-contain/contain-size-flex-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-flex-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-flex-001.html)
 - [contain-size-grid-005.html](https://wpt.fyi/results/css/css-contain/contain-size-grid-005.html "css/css-contain/contain-size-grid-005.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-grid-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-grid-005.html)
 - [contain-size-grid-006.html](https://wpt.fyi/results/css/css-contain/contain-size-grid-006.html "css/css-contain/contain-size-grid-006.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-grid-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-grid-006.html)
 - [contain-size-inline-block-001.html](https://wpt.fyi/results/css/css-contain/contain-size-inline-block-001.html "css/css-contain/contain-size-inline-block-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-inline-block-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-inline-block-001.html)
 - [contain-size-inline-block-002.html](https://wpt.fyi/results/css/css-contain/contain-size-inline-block-002.html "css/css-contain/contain-size-inline-block-002.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-inline-block-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-inline-block-002.html)
 - [contain-size-inline-block-003.html](https://wpt.fyi/results/css/css-contain/contain-size-inline-block-003.html "css/css-contain/contain-size-inline-block-003.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-inline-block-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-inline-block-003.html)
 - [contain-size-inline-block-004.html](https://wpt.fyi/results/css/css-contain/contain-size-inline-block-004.html "css/css-contain/contain-size-inline-block-004.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-inline-block-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-inline-block-004.html)
 - [contain-size-inline-flex-001.html](https://wpt.fyi/results/css/css-contain/contain-size-inline-flex-001.html "css/css-contain/contain-size-inline-flex-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-inline-flex-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-inline-flex-001.html)
 - [contain-size-multicol-002.html](https://wpt.fyi/results/css/css-contain/contain-size-multicol-002.html "css/css-contain/contain-size-multicol-002.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-multicol-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-multicol-002.html)
 - [contain-size-multicol-003.html](https://wpt.fyi/results/css/css-contain/contain-size-multicol-003.html "css/css-contain/contain-size-multicol-003.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-multicol-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-multicol-003.html)
 - [contain-size-select-elem-001.html](https://wpt.fyi/results/css/css-contain/contain-size-select-elem-001.html "css/css-contain/contain-size-select-elem-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-select-elem-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-select-elem-001.html)
 - [contain-size-select-elem-002.html](https://wpt.fyi/results/css/css-contain/contain-size-select-elem-002.html "css/css-contain/contain-size-select-elem-002.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-select-elem-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-select-elem-002.html)
 - [contain-size-select-elem-003.html](https://wpt.fyi/results/css/css-contain/contain-size-select-elem-003.html "css/css-contain/contain-size-select-elem-003.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-select-elem-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-select-elem-003.html)
 - [contain-size-select-elem-004.html](https://wpt.fyi/results/css/css-contain/contain-size-select-elem-004.html "css/css-contain/contain-size-select-elem-004.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-select-elem-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-select-elem-004.html)
 - [contain-size-select-elem-005.html](https://wpt.fyi/results/css/css-contain/contain-size-select-elem-005.html "css/css-contain/contain-size-select-elem-005.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-select-elem-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-select-elem-005.html)

2. Laying out a [size containment
 box](#size-containment-box) and its content is conceptually done in two phases:

 [Sizing as if empty]

 : The
 [used](https://drafts.csswg.org/css-cascade-5/#used-value)
 [width](https://drafts.csswg.org/css-sizing-3/#propdef-width) and
 [height](https://drafts.csswg.org/css-sizing-3/#propdef-height) of the [containment
 box](#size-containment-box) are determined as if performing a normal layout
 of the box, except that it is treated as having no content---​not
 even through
 [pseudo-elements](https://drafts.csswg.org/selectors-4/#pseudo-element) such as
 [::before](https://drafts.csswg.org/css-pseudo-4/#selectordef-before),
 [::after](https://drafts.csswg.org/css-pseudo-4/#selectordef-after), or
 [::marker](https://drafts.csswg.org/css-pseudo-4/#selectordef-marker).

 Tests

 - [contain-size-021.html](https://wpt.fyi/results/css/css-contain/contain-size-021.html "css/css-contain/contain-size-021.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-021.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-021.html)
 - [contain-size-023.html](https://wpt.fyi/results/css/css-contain/contain-size-023.html "css/css-contain/contain-size-023.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-023.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-023.html)
 - [contain-size-025.html](https://wpt.fyi/results/css/css-contain/contain-size-025.html "css/css-contain/contain-size-025.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-025.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-025.html)
 - [contain-size-027.html](https://wpt.fyi/results/css/css-contain/contain-size-027.html "css/css-contain/contain-size-027.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-027.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-027.html)
 - [contain-size-061.html](https://wpt.fyi/results/css/css-contain/contain-size-061.html "css/css-contain/contain-size-061.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-061.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-061.html)
 - [contain-size-062.html](https://wpt.fyi/results/css/css-contain/contain-size-062.html "css/css-contain/contain-size-062.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-062.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-062.html)
 - [contain-size-063.html](https://wpt.fyi/results/css/css-contain/contain-size-063.html "css/css-contain/contain-size-063.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-063.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-063.html)
 - [contain-size-borders.html](https://wpt.fyi/results/css/css-contain/contain-size-borders.html "css/css-contain/contain-size-borders.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-borders.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-borders.html)
 - [contain-size-fieldset-001.html](https://wpt.fyi/results/css/css-contain/contain-size-fieldset-001.html "css/css-contain/contain-size-fieldset-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-fieldset-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-fieldset-001.html)
 - [contain-size-fieldset-002.html](https://wpt.fyi/results/css/css-contain/contain-size-fieldset-002.html "css/css-contain/contain-size-fieldset-002.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-fieldset-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-fieldset-002.html)
 - [contain-size-select-001.html](https://wpt.fyi/results/css/css-contain/contain-size-select-001.html "css/css-contain/contain-size-select-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-select-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-select-001.html)
 - [contain-size-select-002.html](https://wpt.fyi/results/css/css-contain/contain-size-select-002.html "css/css-contain/contain-size-select-002.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-select-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-select-002.html)
 - [contain-size-scrollbars-001.html](https://wpt.fyi/results/css/css-contain/contain-size-scrollbars-001.html "css/css-contain/contain-size-scrollbars-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-scrollbars-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-scrollbars-001.html)
 - [contain-size-scrollbars-002.html](https://wpt.fyi/results/css/css-contain/contain-size-scrollbars-002.html "css/css-contain/contain-size-scrollbars-002.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-scrollbars-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-scrollbars-002.html)
 - [contain-size-scrollbars-003.html](https://wpt.fyi/results/css/css-contain/contain-size-scrollbars-003.html "css/css-contain/contain-size-scrollbars-003.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-scrollbars-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-scrollbars-003.html)
 - [contain-size-scrollbars-004.html](https://wpt.fyi/results/css/css-contain/contain-size-scrollbars-004.html "css/css-contain/contain-size-scrollbars-004.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-scrollbars-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-scrollbars-004.html)
 - [contain-size-button-001.html](https://wpt.fyi/results/css/css-contain/contain-size-button-001.html "css/css-contain/contain-size-button-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-button-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-button-001.html)
 - [contain-size-flexbox-001.html](https://wpt.fyi/results/css/css-contain/contain-size-flexbox-001.html "css/css-contain/contain-size-flexbox-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-flexbox-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-flexbox-001.html)
 - [contain-size-flexbox-002.html](https://wpt.fyi/results/css/css-contain/contain-size-flexbox-002.html "css/css-contain/contain-size-flexbox-002.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-flexbox-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-flexbox-002.html)
 - [contain-size-grid-001.html](https://wpt.fyi/results/css/css-contain/contain-size-grid-001.html "css/css-contain/contain-size-grid-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-grid-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-grid-001.html)

 [Replaced
 elements](https://drafts.csswg.org/css-display-4/#replaced-element) must be treated as having a
 [natural](https://drafts.csswg.org/css-images-3/#natural-dimensions) width and height of 0 and no [natural aspect
 ratio](https://drafts.csswg.org/css-images-3/#natural-aspect-ratio).

 Size containment only suppresses the [natural
 aspect
 ratio](https://drafts.csswg.org/css-images-3/#natural-aspect-ratio), so properties like
 [aspect-ratio](https://drafts.csswg.org/css-sizing-4/#propdef-aspect-ratio) which affect that
 [preferred aspect
 ratio](https://drafts.csswg.org/css-sizing-4/#preferred-aspect-ratio) directly are honored.

 Tests

 - [contain-size-013.html](https://wpt.fyi/results/css/css-contain/contain-size-013.html "css/css-contain/contain-size-013.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-013.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-013.html)
 - [contain-size-041.html](https://wpt.fyi/results/css/css-contain/contain-size-041.html "css/css-contain/contain-size-041.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-041.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-041.html)
 - [contain-size-042.html](https://wpt.fyi/results/css/css-contain/contain-size-042.html "css/css-contain/contain-size-042.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-042.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-042.html)
 - [contain-size-replaced-001.html](https://wpt.fyi/results/css/css-contain/contain-size-replaced-001.html "css/css-contain/contain-size-replaced-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-replaced-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-replaced-001.html)
 - [contain-size-replaced-002.html](https://wpt.fyi/results/css/css-contain/contain-size-replaced-002.html "css/css-contain/contain-size-replaced-002.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-replaced-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-replaced-002.html)
 - [contain-size-replaced-003a.html](https://wpt.fyi/results/css/css-contain/contain-size-replaced-003a.html "css/css-contain/contain-size-replaced-003a.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-replaced-003a.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-replaced-003a.html)
 - [contain-size-replaced-003b.html](https://wpt.fyi/results/css/css-contain/contain-size-replaced-003b.html "css/css-contain/contain-size-replaced-003b.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-replaced-003b.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-replaced-003b.html)
 - [contain-size-replaced-003c.html](https://wpt.fyi/results/css/css-contain/contain-size-replaced-003c.html "css/css-contain/contain-size-replaced-003c.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-replaced-003c.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-replaced-003c.html)
 - [contain-size-replaced-004.html](https://wpt.fyi/results/css/css-contain/contain-size-replaced-004.html "css/css-contain/contain-size-replaced-004.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-replaced-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-replaced-004.html)
 - [contain-size-replaced-005.html](https://wpt.fyi/results/css/css-contain/contain-size-replaced-005.html "css/css-contain/contain-size-replaced-005.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-replaced-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-replaced-005.html)

 - [replaced-element-023.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/replaced-element-023.html "css/css-sizing/aspect-ratio/replaced-element-023.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/replaced-element-023.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/replaced-element-023.html)
 - [replaced-element-025.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/replaced-element-025.html "css/css-sizing/aspect-ratio/replaced-element-025.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/replaced-element-025.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/replaced-element-025.html)
 - [replaced-element-027.html](https://wpt.fyi/results/css/css-sizing/aspect-ratio/replaced-element-027.html "css/css-sizing/aspect-ratio/replaced-element-027.html")
 [[(live
 test)]](http://wpt.live/css/css-sizing/aspect-ratio/replaced-element-027.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-sizing/aspect-ratio/replaced-element-027.html)

 All CSS properties of the [size containment
 box](#size-containment-box) are taken into account as they would be when
 performing layout normally. Other specifications may make
 specific exemptions.

 Tests

 - [contain-size-replaced-006.html](https://wpt.fyi/results/css/css-contain/contain-size-replaced-006.html "css/css-contain/contain-size-replaced-006.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-replaced-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-replaced-006.html)

 Even when the element's [sizing
 properties](https://drafts.csswg.org/css-sizing-3/#sizing-property) specify an intrinsic size, this does not
 necessarily make the element zero-sized: properties set on the
 element itself continue to be taken into account, which can
 cause it to be larger.

 Tests

 - [contain-size-grid-002.html](https://wpt.fyi/results/css/css-contain/contain-size-grid-002.html "css/css-contain/contain-size-grid-002.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-grid-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-grid-002.html)
 - [contain-size-grid-003.html](https://wpt.fyi/results/css/css-contain/contain-size-grid-003.html "css/css-contain/contain-size-grid-003.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-grid-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-grid-003.html)
 - [contain-size-multicol-001.html](https://wpt.fyi/results/css/css-contain/contain-size-multicol-001.html "css/css-contain/contain-size-multicol-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-multicol-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-multicol-001.html)
 - [contain-size-multicol-as-flex-item.html](https://wpt.fyi/results/css/css-contain/contain-size-multicol-as-flex-item.html "css/css-contain/contain-size-multicol-as-flex-item.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-multicol-as-flex-item.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-multicol-as-flex-item.html)

 [Laying out in-place]
 : The [containment
 box](#size-containment-box)'s content (including any
 [pseudo-elements](https://drafts.csswg.org/selectors-4/#pseudo-element)) must then be laid out into the now fixed-size
 [containment box] normally.
 Tests
 - [contain-size-064.html](https://wpt.fyi/results/css/css-contain/contain-size-064.html "css/css-contain/contain-size-064.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-064.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-064.html)

 [Size
 containment](#size-containment) does not suppress baseline alignment. See [layout
 containment](#layout-containment) for that.

 Tests

 - [contain-size-baseline-001.html](https://wpt.fyi/results/css/css-contain/contain-size-baseline-001.html "css/css-contain/contain-size-baseline-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-baseline-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-baseline-001.html)
 - [contain-size-fieldset-004.html](https://wpt.fyi/results/css/css-contain/contain-size-fieldset-004.html "css/css-contain/contain-size-fieldset-004.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-fieldset-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-fieldset-004.html)
 - [contain-size-inline-block-001.html](https://wpt.fyi/results/css/css-contain/contain-size-inline-block-001.html "css/css-contain/contain-size-inline-block-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-inline-block-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-inline-block-001.html)
 - [contain-size-inline-block-002.html](https://wpt.fyi/results/css/css-contain/contain-size-inline-block-002.html "css/css-contain/contain-size-inline-block-002.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-inline-block-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-inline-block-002.html)
 - [contain-size-inline-block-003.html](https://wpt.fyi/results/css/css-contain/contain-size-inline-block-003.html "css/css-contain/contain-size-inline-block-003.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-inline-block-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-inline-block-003.html)
 - [contain-size-inline-block-004.html](https://wpt.fyi/results/css/css-contain/contain-size-inline-block-004.html "css/css-contain/contain-size-inline-block-004.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-inline-block-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-inline-block-004.html)
 - [contain-size-inline-flex-001.html](https://wpt.fyi/results/css/css-contain/contain-size-inline-flex-001.html "css/css-contain/contain-size-inline-flex-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-inline-flex-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-inline-flex-001.html)

3. [Size containment
 boxes](#size-containment-box) are
 [monolithic](https://drafts.csswg.org/css-break-3/#monolithic) (See [CSS Fragmentation 3 § 4.1 Possible Break
 Points](https://drafts.csswg.org/css-break-3/#possible-breaks)).

 Tests

 - [contain-size-breaks-001.html](https://wpt.fyi/results/css/css-contain/contain-size-breaks-001.html "css/css-contain/contain-size-breaks-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-breaks-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-breaks-001.html)
 - [contain-size-monolithic-001.html](https://wpt.fyi/results/css/css-contain/contain-size-monolithic-001.html "css/css-contain/contain-size-monolithic-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-monolithic-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-monolithic-001.html)
 - [contain-size-monolithic-002.html](https://wpt.fyi/results/css/css-contain/contain-size-monolithic-002.html "css/css-contain/contain-size-monolithic-002.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-monolithic-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-monolithic-002.html)
 - [contain-size-multicol-004.html](https://wpt.fyi/results/css/css-contain/contain-size-multicol-004.html "css/css-contain/contain-size-multicol-004.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-multicol-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-multicol-004.html)

Given the following markup and style,
the image would be sized to 100px by 100px, as the aspect ratio set by
the
[aspect-ratio](https://drafts.csswg.org/css-sizing-4/#propdef-aspect-ratio) property takes effect.

```
img {
 width: 100px;
 aspect-ratio: 1/1;
 contain: size;
}

<img src="https://www.example.com/300x100.jpg">
```

If the
[aspect-ratio](https://drafts.csswg.org/css-sizing-4/#propdef-aspect-ratio) property had not been declared, the
image would have been 100px by 0px, as its [natural aspect
ratio](https://drafts.csswg.org/css-images-3/#natural-aspect-ratio) is suppressed, and its [natural
height](https://drafts.csswg.org/css-images-3/#natural-height) is treated as 0.

However, giving an element [size
containment](#size-containment) has no effect if any of the following are true:

- if the element does not generate a [principal
 box](https://drafts.csswg.org/css-display-4/#principal-box) (as is the case with [display:
 contents](https://drafts.csswg.org/css-display-3/#propdef-display) or [display:
 none])

- if its [inner display
 type](https://drafts.csswg.org/css-display-4/#inner-display-type) is
 [table](https://drafts.csswg.org/css-display-4/#valdef-display-table)

 Tests

 - [contain-size-012.html](https://wpt.fyi/results/css/css-contain/contain-size-012.html "css/css-contain/contain-size-012.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-012.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-012.html)
 - [contain-size-012b.html](https://wpt.fyi/results/css/css-contain/contain-size-012b.html "css/css-contain/contain-size-012b.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-012b.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-012b.html)

- if its [principal
 box](https://drafts.csswg.org/css-display-4/#principal-box) is an [internal table
 box](https://drafts.csswg.org/css-display-3/#internal-table-box)

 Tests

 - [contain-size-006.html](https://wpt.fyi/results/css/css-contain/contain-size-006.html "css/css-contain/contain-size-006.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-006.html)
 - [contain-size-007.html](https://wpt.fyi/results/css/css-contain/contain-size-007.html "css/css-contain/contain-size-007.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-007.html)
 - [contain-size-008.html](https://wpt.fyi/results/css/css-contain/contain-size-008.html "css/css-contain/contain-size-008.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-008.html)
 - [contain-size-009.html](https://wpt.fyi/results/css/css-contain/contain-size-009.html "css/css-contain/contain-size-009.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-009.html)
 - [contain-size-010.html](https://wpt.fyi/results/css/css-contain/contain-size-010.html "css/css-contain/contain-size-010.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-010.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-010.html)
 - [contain-size-051.html](https://wpt.fyi/results/css/css-contain/contain-size-051.html "css/css-contain/contain-size-051.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-051.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-051.html)
 - [contain-size-052.html](https://wpt.fyi/results/css/css-contain/contain-size-052.html "css/css-contain/contain-size-052.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-052.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-052.html)

- if its [principal
 box](https://drafts.csswg.org/css-display-4/#principal-box) is an [internal ruby
 box](https://drafts.csswg.org/css-display-3/#internal-ruby-box) or a
 [non-atomic](https://drafts.csswg.org/css-display-3/#atomic-inline)
 [inline-level](https://drafts.csswg.org/css-display-3/#inline-level) box

 Tests

 - [contain-size-002.html](https://wpt.fyi/results/css/css-contain/contain-size-002.html "css/css-contain/contain-size-002.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-002.html)
 - [contain-size-003.html](https://wpt.fyi/results/css/css-contain/contain-size-003.html "css/css-contain/contain-size-003.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-003.html)
 - [contain-size-004.html](https://wpt.fyi/results/css/css-contain/contain-size-004.html "css/css-contain/contain-size-004.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-004.html)
 - [contain-size-005.html](https://wpt.fyi/results/css/css-contain/contain-size-005.html "css/css-contain/contain-size-005.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-005.html)
 - [contain-size-001.html](https://wpt.fyi/results/css/css-contain/contain-size-001.html "css/css-contain/contain-size-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-001.html)

 Internal table boxes, which do not include table
captions, are excluded, because the table layout algorithm does not
allow boxes to become smaller than their inflow content. Sizing a table
cell as if it was empty and then laying out its content inside without
changing the size is effectively an undefined operation. Manually
setting the
[width](https://drafts.csswg.org/css-sizing-3/#propdef-width) or
[height](https://drafts.csswg.org/css-sizing-3/#propdef-height) properties to [0] cannot make
it smaller than its content. This concern does not apply to table
captions, which are perfectly capable of having a fixed size that is
independent of their content.

Tests

- [contain-size-011.html](https://wpt.fyi/results/css/css-contain/contain-size-011.html "css/css-contain/contain-size-011.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-011.html)
- [contain-size-056.html](https://wpt.fyi/results/css/css-contain/contain-size-056.html "css/css-contain/contain-size-056.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-056.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-056.html)
- [contain-size-table-caption-001.html](https://wpt.fyi/results/css/css-contain/contain-size-table-caption-001.html "css/css-contain/contain-size-table-caption-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-size-table-caption-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-size-table-caption-001.html)

#### 3.1.1. Possible Size-Containment Optimizations

*This section is non-normative.*

By itself, [size
containment](#size-containment) does not offer much optimization opportunity. Its
primary benefit on its own is that tools which want to lay out the
[containment box](#size-containment-box)'s contents based on the [containment
box]'s size (such as a JS library
implementing the \"container query\" concept) can do so without fear of
\"infinite loops\", where having a child's size respond to the size of
the [containment box] causes the
[containment box]'s size to change as
well, possibly triggering *further* changes in how the child sizes
itself and possibly thus more changes to the [containment
box]'s size, ad infinitum.

When paired with [layout
containment](#layout-containment), though, possible optimizations that can be enabled
include (but are not limited to):

1. When the style or contents of a descendant of the [containment
 box](#size-containment-box) is changed, calculating what part of the DOM tree
 is \"dirtied\" and might need to be re-laid out can stop at the
 [containment box].

2. When laying out the page, if the [containment
 box](#size-containment-box) is off-screen or obscured, the layout of its
 contents (i.e. \"[laying out
 in-place](#laying-out-in-place)\") can be delayed or done at a lower priority.

### 3.2. Inline-Size Containment

Giving an element [inline-size containment] applies [size
containment](#size-containment) to the
[inline-axis](https://drafts.csswg.org/css-writing-modes-4/#inline-axis) sizing of its [principal
box](https://drafts.csswg.org/css-display-4/#principal-box). This means the [inline-axis]
[intrinsic
sizes](https://drafts.csswg.org/css-sizing-3/#intrinsic-size) of the [principal box] are
determined as if the element had no content. However, content continues
to impact the box's
[block-axis](https://drafts.csswg.org/css-writing-modes-4/#block-axis) [intrinsic sizes] as usual,
and the box is allowed to
[fragment](https://drafts.csswg.org/css-break-3/#fragmentation) normally in the [block axis].

 In some cases, a box's
[block-axis](https://drafts.csswg.org/css-writing-modes-4/#block-axis) [intrinsic
sizes](https://drafts.csswg.org/css-sizing-3/#intrinsic-size) can impact layout in the parent [formatting
context](https://drafts.csswg.org/css-display-4/#formatting-context) in ways that affect the box's [inline
size](https://drafts.csswg.org/css-sizing-3/#inline-size) (e.g. by triggering scrollbars on an ancestor element),
creating a dependency of the box's [inline size]
on its own content. If this changed [inline size]
results in a different [block
size](https://drafts.csswg.org/css-sizing-3/#block-size), that new [block size] can loop
into further impacting the parent formatting context, but not in a way
that reverts it to the previously-problematic layout.

For example, if scrollbars were introduced, they are then not removed,
even if the consequent [block
size](https://drafts.csswg.org/css-sizing-3/#block-size) is small enough to not need them; or if a box's logical
height collides with a lower-placed float and is cleared down to where
it also has more available inline space and thus becomes short enough to
not have collided, it is then not moved back up to its previous
problematic size and position.

Thus, although [inline-size
containment](#inline-size-containment) prevents the box's content from directly affecting its
[inline
size](https://drafts.csswg.org/css-sizing-3/#inline-size) through its
[inline-axis](https://drafts.csswg.org/css-writing-modes-4/#inline-axis) [intrinsic
sizes](https://drafts.csswg.org/css-sizing-3/#intrinsic-size), its [inline size] can still
indirectly depend on its contents by their effect on its [block
size](https://drafts.csswg.org/css-sizing-3/#block-size).

In general, the relationship between an
element's inline size and it's block size is unpredictable and
non-monotonic, with the block size capable of shifting up and down
arbitrarily as the inline size is changed. Infinite cycles are prevented
by ensuring that layout does not revert to a previous
(known-problematic) state, even if a naive analysis of the constraints
would allow for such; in other words, layout always "moves forward". We
believe that current CSS layout specifications incorporate such rules,
but to the extent that they don't, please [inform the
CSSWG](https://github.com/w3c/csswg-drafts/issues) so that these errors
can be corrected.

Consider this example, where float
placement creates a dependency of block sizes on inline sizes:

```
<section style="width: 200px; border: solid; display: flow-root;">
 <!-- floated elements that impact the available space -->
 <div style="float: left; width: 50px; height: 80px; background: blue;"></div>
 <div style="float: right; width: 50px; height: 80px; background: blue;"></div>
 <div style="float: left; width: 160px; height: 80px; background: navy;"></div>

 <!-- parent layout, determining context -->
 <article style="border: solid orangered; display: flow-root; min-width: min-content">
 <div style="background: orange; aspect-ratio: 1/1;">
 Article
 </div>
 </article>
</section>
```

<figure style="float: left; margin: 1em 0.5em">
<section style="width: 200px; border: solid; display: flow-root;">
<div style="float: left; width: 50px; height: 80px; background: blue;">

</div>
<div style="float: right; width: 50px; height: 80px; background: blue;">

</div>
<div style="float: left; width: 160px; height: 80px; background: navy;">

</div>
<div style="background: orange; aspect-ratio: 1/1;">
Article
</div>
</section>
</figure>

The block layout algorithm will first place the floating boxes, with the
first two sitting in the left and right corners of the container, and
the third, being too wide to fit between, being pushed below them.

The following `article` will then be laid out. Because it is [display:
flow-root](https://drafts.csswg.org/css-display-3/#propdef-display), it cannot intersect any floats, and thus
must take them into account when figuring out how to size and position
itself.

The layout engine first attempts to place the `article` flush with the
top of the container, resulting a [100px] width, plenty wide
enough to accommodate its [min-content
size](https://drafts.csswg.org/css-sizing-3/#min-content). However, due to the
[aspect-ratio](https://drafts.csswg.org/css-sizing-4/#propdef-aspect-ratio) of its child, this would cause the
`article` to be [100px] tall as well, which would intersect the
third float 80px below, so this layout opportunity is discarded.

It then attempts to position the `article` flush with the top of the
third float, in the narrow [40px]-wide space to its right.
However, since the `article`'s
[min-width](https://drafts.csswg.org/css-sizing-3/#propdef-min-width) makes it too large to fit in the
40px-wide space beside the third float, it shifts below that one as
well, forming a 200px square below all the floated boxes.

<figure style="float: right; margin: 1em 0.5em">
<section style="width: 200px; border: solid; display: flow-root;">
<div style="float: left; width: 50px; height: 80px; background: blue;">

</div>
<div style="float: right; width: 50px; height: 80px; background: blue;">

</div>
<div style="float: left; width: 160px; height: 80px; background: navy;">

</div>
<div style="background: orange; aspect-ratio: 1/1;">
Article
</div>
</section>
</figure>

If the
[min-width](https://drafts.csswg.org/css-sizing-3/#propdef-min-width) is removed from the `article`, or
if [inline-size
containment](#inline-size-containment) is added to either the `article` or `header` (causing
[min-width: min-content] to resolve to
zero), then the `article` will fit as a 40px square next to the final
floated `div` (possibly with some of its content overflowing).

At this point, the width and height of the `article` ([40px] each)
*would* fit back in the first considered space, flush with the top of
the container. However, the box is not returned to the previous
position, because the layout engine knows already that this position
would result in an invalid layout.

Giving an element [inline-size
containment](#inline-size-containment) has no effect if any of the following are true:

- if the element does not generate a [principal
 box](https://drafts.csswg.org/css-display-4/#principal-box) (as is the case with [display:
 contents](https://drafts.csswg.org/css-display-3/#propdef-display) or [display:
 none])

- if its [inner display
 type](https://drafts.csswg.org/css-display-4/#inner-display-type) is
 [table](https://drafts.csswg.org/css-display-4/#valdef-display-table)

- if its [principal
 box](https://drafts.csswg.org/css-display-4/#principal-box) is an [internal table
 box](https://drafts.csswg.org/css-display-3/#internal-table-box)

- if its [principal
 box](https://drafts.csswg.org/css-display-4/#principal-box) is an [internal ruby
 box](https://drafts.csswg.org/css-display-3/#internal-ruby-box) or a
 [non-atomic](https://drafts.csswg.org/css-display-3/#atomic-inline)
 [inline-level](https://drafts.csswg.org/css-display-3/#inline-level) box

### 3.3. Layout Containment

Giving an element [layout containment] makes its [principal
box](https://drafts.csswg.org/css-display-4/#principal-box) a [layout containment box] and has the following effects:

1. The [layout containment
 box](#layout-containment-box) [establishes an independent formatting
 context](https://drafts.csswg.org/css-display-4/#establish-an-independent-formatting-context).

 Tests

 - [contain-layout-ifc-022.html](https://wpt.fyi/results/css/css-contain/contain-layout-ifc-022.html "css/css-contain/contain-layout-ifc-022.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-ifc-022.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-ifc-022.html)
 - [contain-layout-independent-formatting-context-001.html](https://wpt.fyi/results/css/css-contain/contain-layout-independent-formatting-context-001.html "css/css-contain/contain-layout-independent-formatting-context-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-independent-formatting-context-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-independent-formatting-context-001.html)
 - [contain-layout-independent-formatting-context-002.html](https://wpt.fyi/results/css/css-contain/contain-layout-independent-formatting-context-002.html "css/css-contain/contain-layout-independent-formatting-context-002.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-independent-formatting-context-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-independent-formatting-context-002.html)
 - [contain-subgrid-001.html](https://wpt.fyi/results/css/css-contain/contain-subgrid-001.html "css/css-contain/contain-subgrid-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-subgrid-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-subgrid-001.html)
 - [contain-layout-formatting-context-float-001.html](https://wpt.fyi/results/css/css-contain/contain-layout-formatting-context-float-001.html "css/css-contain/contain-layout-formatting-context-float-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-formatting-context-float-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-formatting-context-float-001.html)
 - [contain-layout-formatting-context-margin-001.html](https://wpt.fyi/results/css/css-contain/contain-layout-formatting-context-margin-001.html "css/css-contain/contain-layout-formatting-context-margin-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-formatting-context-margin-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-formatting-context-margin-001.html)

2. If at least one [fragmentation
 container](https://drafts.csswg.org/css-break-3/#fragmentation-container) of a [fragmentation
 context](https://drafts.csswg.org/css-break-3/#fragmentation-context) has [layout
 containment](#layout-containment), or if at least one [fragmentation
 container] of a [fragmentation
 context] is a descendant of [layout
 containment
 box](#layout-containment-box) **and** at least one subsequent [fragmentation
 container] of the same
 [fragmentation context] is not a
 descendant of that same element with layout containment, then the
 first [layout containment box]
 which is either a [fragmentation
 container] itself or is an
 ancestor of a [fragmentation
 container] must "trap" the
 remainder of the [fragmented
 flow](https://drafts.csswg.org/css-break-3/#fragmented-flow):
 [fragmentation](https://drafts.csswg.org/css-break-3/#fragmentation) must not continue past the [layout
 containment] boundary, and the last
 [fragmentation container] within
 the first [layout containment]
 boundary is treated as if it is the last [fragmentation
 container] in its [fragmentation
 context].

 If subsequent [fragmentation
 containers](https://drafts.csswg.org/css-break-3/#fragmentation-container) in the [fragmentation
 context](https://drafts.csswg.org/css-break-3/#fragmentation-context) are only generated when more content remains in the
 [fragmented
 flow](https://drafts.csswg.org/css-break-3/#fragmented-flow), then they are not generated. If they would exist
 regardless, they remain part of the [fragmentation
 context], but do not receive any
 content from the [fragmented flow].

 At the time of writing, no stable specification is
 affected by this point. Only specifications that would enable some
 (but not all) fragmentation containers of a fragmentation context to
 be layout-contained (or descendants of a layout contained element)
 are concerned. This is not the case of
 [\[CSS-PAGE-3\]](#biblio-css-page-3 "CSS Paged Media Module Level 3")
 nor of
 [\[CSS-MULTICOL-1\]](#biblio-css-multicol-1 "CSS Multi-column Layout Module Level 1").
 This requirement is nonetheless included because several mechanisms
 that would make this a possibility have been considered (e.g.:
 [\[CSS-REGIONS-1\]](#biblio-css-regions-1 "CSS Regions Module Level 1"),
 [::nth-fragment()](https://drafts.csswg.org/css-overflow-5/#selectordef-nth-fragment), a hypothetical selector for individual
 columns of a multicol...), and the guarantees that layout
 containment is intended to offer would not be realized if such
 mechanisms did not abide by this rule.
 [\[CSS-REGIONS-1\]](#biblio-css-regions-1 "CSS Regions Module Level 1")
 has details over how [layout
 containment](#layout-containment) affects regions.

 :::
 (#example-2b10faa8)
 ``` highlight
 <article>Lorem ipsum…</article>
 <div id=a></div>
 <aside>
 <div id=b></div>
 <div id=c></div>
 </aside>
 <aside>
 <div id=d></div>
 <div id=e></div>
 </aside>
 <div id=f></div>
 ```

 ``` highlight
 article {flow-into: foo;}
 #a, #b, #c, #d, #e, #f {flow-from: foo;}
 aside {contain: layout}
 ```

 In this
 [\[CSS-REGIONS-1\]](#biblio-css-regions-1 "CSS Regions Module Level 1")
 example, content can flow from `#a` to `#b`, from `#b` to `#c`.
 However as `#c` is the last fragment container in the first [layout
 containment
 box](#layout-containment-box) it traps all the remaining content, and nothing
 gets flowed into `#d`, `#e`, or `#f`.
 :::

3. If the computed value of the
 [overflow](https://drafts.csswg.org/css-overflow-3/#propdef-overflow) property is either
 [visible](https://drafts.csswg.org/css-overflow-3/#valdef-overflow-visible) or
 [clip](https://drafts.csswg.org/css-overflow-3/#valdef-overflow-clip) or a combination thereof, any overflow must
 be treated as [ink
 overflow](https://drafts.csswg.org/css-overflow-3/#ink-overflow).

 Tests

 - [contain-layout-ink-overflow-013.html](https://wpt.fyi/results/css/css-contain/contain-layout-ink-overflow-013.html "css/css-contain/contain-layout-ink-overflow-013.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-ink-overflow-013.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-ink-overflow-013.html)
 - [contain-layout-ink-overflow-014.html](https://wpt.fyi/results/css/css-contain/contain-layout-ink-overflow-014.html "css/css-contain/contain-layout-ink-overflow-014.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-ink-overflow-014.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-ink-overflow-014.html)
 - [contain-layout-ink-overflow-015.html](https://wpt.fyi/results/css/css-contain/contain-layout-ink-overflow-015.html "css/css-contain/contain-layout-ink-overflow-015.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-ink-overflow-015.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-ink-overflow-015.html)
 - [contain-layout-ink-overflow-016.html](https://wpt.fyi/results/css/css-contain/contain-layout-ink-overflow-016.html "css/css-contain/contain-layout-ink-overflow-016.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-ink-overflow-016.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-ink-overflow-016.html)
 - [contain-layout-ink-overflow-017.html](https://wpt.fyi/results/css/css-contain/contain-layout-ink-overflow-017.html "css/css-contain/contain-layout-ink-overflow-017.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-ink-overflow-017.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-ink-overflow-017.html)
 - [contain-layout-ink-overflow-018.html](https://wpt.fyi/results/css/css-contain/contain-layout-ink-overflow-018.html "css/css-contain/contain-layout-ink-overflow-018.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-ink-overflow-018.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-ink-overflow-018.html)
 - [contain-layout-ink-overflow-019.html](https://wpt.fyi/results/css/css-contain/contain-layout-ink-overflow-019.html "css/css-contain/contain-layout-ink-overflow-019.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-ink-overflow-019.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-ink-overflow-019.html)
 - [contain-layout-ink-overflow-020.html](https://wpt.fyi/results/css/css-contain/contain-layout-ink-overflow-020.html "css/css-contain/contain-layout-ink-overflow-020.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-ink-overflow-020.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-ink-overflow-020.html)
 - [contain-layout-overflow-001.html](https://wpt.fyi/results/css/css-contain/contain-layout-overflow-001.html "css/css-contain/contain-layout-overflow-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-overflow-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-overflow-001.html)
 - [contain-layout-overflow-002.html](https://wpt.fyi/results/css/css-contain/contain-layout-overflow-002.html "css/css-contain/contain-layout-overflow-002.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-overflow-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-overflow-002.html)

4. The [layout containment
 box](#layout-containment-box) establishes an [absolute positioning containing
 block](https://drafts.csswg.org/css-position-3/#absolute-positioning-containing-block) and a [fixed positioning containing
 block](https://drafts.csswg.org/css-position-3/#fixed-positioning-containing-block).

 Tests

 - [contain-layout-006.html](https://wpt.fyi/results/css/css-contain/contain-layout-006.html "css/css-contain/contain-layout-006.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-006.html)
 - [contain-layout-007.html](https://wpt.fyi/results/css/css-contain/contain-layout-007.html "css/css-contain/contain-layout-007.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-007.html)
 - [contain-layout-cell-001.html](https://wpt.fyi/results/css/css-contain/contain-layout-cell-001.html "css/css-contain/contain-layout-cell-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-cell-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-cell-001.html)
 - [contain-layout-cell-002.html](https://wpt.fyi/results/css/css-contain/contain-layout-cell-002.html "css/css-contain/contain-layout-cell-002.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-cell-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-cell-002.html)
 - [contain-layout-021.html](https://wpt.fyi/results/css/css-contain/contain-layout-021.html "css/css-contain/contain-layout-021.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-021.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-021.html)
 - [contain-layout-containing-block-absolute-001.html](https://wpt.fyi/results/css/css-contain/contain-layout-containing-block-absolute-001.html "css/css-contain/contain-layout-containing-block-absolute-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-containing-block-absolute-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-containing-block-absolute-001.html)
 - [contain-layout-containing-block-fixed-001.html](https://wpt.fyi/results/css/css-contain/contain-layout-containing-block-fixed-001.html "css/css-contain/contain-layout-containing-block-fixed-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-containing-block-fixed-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-containing-block-fixed-001.html)

5. The [layout containment
 box](#layout-containment-box) creates a [stacking
 context](https://www.w3.org/TR/CSS2/visuren.html#x43).

 Tests

 - [contain-layout-016.html](https://wpt.fyi/results/css/css-contain/contain-layout-016.html "css/css-contain/contain-layout-016.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-016.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-016.html)
 - [contain-layout-017.html](https://wpt.fyi/results/css/css-contain/contain-layout-017.html "css/css-contain/contain-layout-017.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-017.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-017.html)
 - [contain-layout-018.html](https://wpt.fyi/results/css/css-contain/contain-layout-018.html "css/css-contain/contain-layout-018.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-018.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-018.html)
 - [contain-layout-stacking-context-001.html](https://wpt.fyi/results/css/css-contain/contain-layout-stacking-context-001.html "css/css-contain/contain-layout-stacking-context-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-stacking-context-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-stacking-context-001.html)

6. [Forced
 breaks](https://drafts.csswg.org/css-break-3/#forced-break) are allowed within [layout containment
 boxes](#layout-containment-box) but do not propagate to the parent as otherwise
 described in [CSS Fragmentation 3 § 3.1 Breaks Between Boxes: the
 break-before and break-after
 properties](https://drafts.csswg.org/css-break-3/#break-between).

 Tests

 - [contain-layout-breaks-001.html](https://wpt.fyi/results/css/css-contain/contain-layout-breaks-001.html "css/css-contain/contain-layout-breaks-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-breaks-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-breaks-001.html)
 - [contain-layout-breaks-002.html](https://wpt.fyi/results/css/css-contain/contain-layout-breaks-002.html "css/css-contain/contain-layout-breaks-002.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-breaks-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-breaks-002.html)

 This introduces the previously non-existent
 possibility that [forced
 breaks](https://drafts.csswg.org/css-break-3/#forced-break) may occur between a box and its container (See [CSS
 Fragmentation 3 § 4.1 Possible Break
 Points](https://drafts.csswg.org/css-break-3/#possible-breaks)).

7. For the purpose of the
 [vertical-align](https://drafts.csswg.org/css-inline-3/#propdef-vertical-align) property, or any other property
 whose effects need to relate the position of the [layout containment
 box](#layout-containment-box)'s baseline to something other than its descendants,
 the [containment box] is treated
 as having no baseline.

 Tests

 - [contain-layout-baseline-001.html](https://wpt.fyi/results/css/css-contain/contain-layout-baseline-001.html "css/css-contain/contain-layout-baseline-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-baseline-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-baseline-001.html)
 - [contain-layout-flexbox-001.html](https://wpt.fyi/results/css/css-contain/contain-layout-flexbox-001.html "css/css-contain/contain-layout-flexbox-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-flexbox-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-flexbox-001.html)
 - [contain-layout-grid-001.html](https://wpt.fyi/results/css/css-contain/contain-layout-grid-001.html "css/css-contain/contain-layout-grid-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-grid-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-grid-001.html)
 - [contain-layout-baseline-002.html](https://wpt.fyi/results/css/css-contain/contain-layout-baseline-002.html "css/css-contain/contain-layout-baseline-002.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-baseline-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-baseline-002.html)
 - [contain-layout-baseline-003.html](https://wpt.fyi/results/css/css-contain/contain-layout-baseline-003.html "css/css-contain/contain-layout-baseline-003.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-baseline-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-baseline-003.html)
 - [contain-layout-baseline-004.html](https://wpt.fyi/results/css/css-contain/contain-layout-baseline-004.html "css/css-contain/contain-layout-baseline-004.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-baseline-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-baseline-004.html)
 - [contain-layout-baseline-005.html](https://wpt.fyi/results/css/css-contain/contain-layout-baseline-005.html "css/css-contain/contain-layout-baseline-005.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-baseline-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-baseline-005.html)
 - [contain-layout-suppress-baseline-001.html](https://wpt.fyi/results/css/css-contain/contain-layout-suppress-baseline-001.html "css/css-contain/contain-layout-suppress-baseline-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-suppress-baseline-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-suppress-baseline-001.html)
 - [contain-layout-suppress-baseline-002.html](https://wpt.fyi/results/css/css-contain/contain-layout-suppress-baseline-002.html "css/css-contain/contain-layout-suppress-baseline-002.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-suppress-baseline-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-suppress-baseline-002.html)

However, giving an element [layout
containment](#layout-containment) has no effect if any of the following are true:

- if the element does not generate a [principal
 box](https://drafts.csswg.org/css-display-4/#principal-box) (as is the case with [display:
 contents](https://drafts.csswg.org/css-display-3/#propdef-display) or [display:
 none])

 Tests

 - [contain-layout-ignored-cases-no-principal-box-001.html](https://wpt.fyi/results/css/css-contain/contain-layout-ignored-cases-no-principal-box-001.html "css/css-contain/contain-layout-ignored-cases-no-principal-box-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-ignored-cases-no-principal-box-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-ignored-cases-no-principal-box-001.html)
 - [contain-layout-ignored-cases-no-principal-box-002.html](https://wpt.fyi/results/css/css-contain/contain-layout-ignored-cases-no-principal-box-002.html "css/css-contain/contain-layout-ignored-cases-no-principal-box-002.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-ignored-cases-no-principal-box-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-ignored-cases-no-principal-box-002.html)
 - [contain-layout-ignored-cases-no-principal-box-003.html](https://wpt.fyi/results/css/css-contain/contain-layout-ignored-cases-no-principal-box-003.html "css/css-contain/contain-layout-ignored-cases-no-principal-box-003.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-ignored-cases-no-principal-box-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-ignored-cases-no-principal-box-003.html)

- if its [principal
 box](https://drafts.csswg.org/css-display-4/#principal-box) is an [internal table
 box](https://drafts.csswg.org/css-display-3/#internal-table-box) other than
 [table-cell](https://drafts.csswg.org/css-display-4/#valdef-display-table-cell)

 Tests

 - [contain-layout-009.html](https://wpt.fyi/results/css/css-contain/contain-layout-009.html "css/css-contain/contain-layout-009.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-009.html)
 - [contain-layout-010.html](https://wpt.fyi/results/css/css-contain/contain-layout-010.html "css/css-contain/contain-layout-010.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-010.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-010.html)
 - [contain-layout-011.html](https://wpt.fyi/results/css/css-contain/contain-layout-011.html "css/css-contain/contain-layout-011.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-011.html)
 - [contain-layout-012.html](https://wpt.fyi/results/css/css-contain/contain-layout-012.html "css/css-contain/contain-layout-012.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-012.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-012.html)
 - [contain-layout-013.html](https://wpt.fyi/results/css/css-contain/contain-layout-013.html "css/css-contain/contain-layout-013.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-013.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-013.html)
 - [contain-layout-014.html](https://wpt.fyi/results/css/css-contain/contain-layout-014.html "css/css-contain/contain-layout-014.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-014.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-014.html)

- if its [principal
 box](https://drafts.csswg.org/css-display-4/#principal-box) is an [internal ruby
 box](https://drafts.csswg.org/css-display-3/#internal-ruby-box) or a
 [non-atomic](https://drafts.csswg.org/css-display-3/#atomic-inline)
 [inline-level](https://drafts.csswg.org/css-display-3/#inline-level) box

 Tests

 - [contain-layout-002.html](https://wpt.fyi/results/css/css-contain/contain-layout-002.html "css/css-contain/contain-layout-002.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-002.html)
 - [contain-layout-003.html](https://wpt.fyi/results/css/css-contain/contain-layout-003.html "css/css-contain/contain-layout-003.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-003.html)
 - [contain-layout-004.html](https://wpt.fyi/results/css/css-contain/contain-layout-004.html "css/css-contain/contain-layout-004.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-004.html)
 - [contain-layout-005.html](https://wpt.fyi/results/css/css-contain/contain-layout-005.html "css/css-contain/contain-layout-005.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-005.html)
 - [contain-layout-001.html](https://wpt.fyi/results/css/css-contain/contain-layout-001.html "css/css-contain/contain-layout-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-001.html)
 - [contain-layout-independent-formatting-context-003.html](https://wpt.fyi/results/css/css-contain/contain-layout-independent-formatting-context-003.html "css/css-contain/contain-layout-independent-formatting-context-003.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-independent-formatting-context-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-independent-formatting-context-003.html)
 - [contain-layout-ignored-cases-ib-split-001.html](https://wpt.fyi/results/css/css-contain/contain-layout-ignored-cases-ib-split-001.html "css/css-contain/contain-layout-ignored-cases-ib-split-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-layout-ignored-cases-ib-split-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-layout-ignored-cases-ib-split-001.html)

#### 3.3.1. Possible Layout-Containment Optimizations

*This section is non-normative.*

Possible optimizations that can be enabled by [layout
containment](#layout-containment) include (but are not limited to):

1. When laying out the page, the contents of separate [containment
 boxes](#layout-containment-box) can be laid out in parallel, as they're guaranteed
 not to affect each other.

2. When laying out the page, if the [containment
 box](#layout-containment-box) is off-screen or obscured and the layout of the
 visible parts of the screen do not depend on the size of the
 [containment box] (for example,
 if the [containment box] is near
 the end of a block container, and you're viewing the beginning of
 the block container), the layout of the [containment
 box]\' contents can be delayed or
 done at a lower priority.

 (When paired with [size
 containment](#size-containment), this optimization can be applied more liberally.)

### 3.4. Style Containment

Giving an element [style containment] has the following effects:

1. The
 [counter-increment](https://drafts.csswg.org/css-lists-3/#propdef-counter-increment) and
 [counter-set](https://drafts.csswg.org/css-lists-3/#propdef-counter-set) properties must be [scoped to
 the element's
 sub-tree](#property-scoped-to-a-sub-tree) and create a new counter.

 Tests

 - [contain-style-counters-001.html](https://wpt.fyi/results/css/css-contain/contain-style-counters-001.html "css/css-contain/contain-style-counters-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-style-counters-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-style-counters-001.html)
 - [contain-style-counters-002.html](https://wpt.fyi/results/css/css-contain/contain-style-counters-002.html "css/css-contain/contain-style-counters-002.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-style-counters-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-style-counters-002.html)
 - [contain-style-counters-003.html](https://wpt.fyi/results/css/css-contain/contain-style-counters-003.html "css/css-contain/contain-style-counters-003.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-style-counters-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-style-counters-003.html)
 - [contain-style-counters-004.html](https://wpt.fyi/results/css/css-contain/contain-style-counters-004.html "css/css-contain/contain-style-counters-004.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-style-counters-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-style-counters-004.html)
 - [contain-style-ol-ordinal-li-container.html](https://wpt.fyi/results/css/css-contain/contain-style-ol-ordinal-li-container.html "css/css-contain/contain-style-ol-ordinal-li-container.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-style-ol-ordinal-li-container.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-style-ol-ordinal-li-container.html)
 - [contain-style-ol-ordinal-pseudo-reversed.html](https://wpt.fyi/results/css/css-contain/contain-style-ol-ordinal-pseudo-reversed.html "css/css-contain/contain-style-ol-ordinal-pseudo-reversed.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-style-ol-ordinal-pseudo-reversed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-style-ol-ordinal-pseudo-reversed.html)
 - [contain-style-ol-ordinal-pseudo.html](https://wpt.fyi/results/css/css-contain/contain-style-ol-ordinal-pseudo.html "css/css-contain/contain-style-ol-ordinal-pseudo.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-style-ol-ordinal-pseudo.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-style-ol-ordinal-pseudo.html)
 - [contain-style-ol-ordinal-reversed.html](https://wpt.fyi/results/css/css-contain/contain-style-ol-ordinal-reversed.html "css/css-contain/contain-style-ol-ordinal-reversed.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-style-ol-ordinal-reversed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-style-ol-ordinal-reversed.html)
 - [contain-style-ol-ordinal-start-reversed.html](https://wpt.fyi/results/css/css-contain/contain-style-ol-ordinal-start-reversed.html "css/css-contain/contain-style-ol-ordinal-start-reversed.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-style-ol-ordinal-start-reversed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-style-ol-ordinal-start-reversed.html)
 - [contain-style-ol-ordinal-start.html](https://wpt.fyi/results/css/css-contain/contain-style-ol-ordinal-start.html "css/css-contain/contain-style-ol-ordinal-start.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-style-ol-ordinal-start.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-style-ol-ordinal-start.html)
 - [contain-style-ol-ordinal.html](https://wpt.fyi/results/css/css-contain/contain-style-ol-ordinal.html "css/css-contain/contain-style-ol-ordinal.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-style-ol-ordinal.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-style-ol-ordinal.html)

2. The effects of the
 [content](https://drafts.csswg.org/css-content-3/#propdef-content) property's
 [open-quote](https://drafts.csswg.org/css-content-3/#valdef-content-open-quote),
 [close-quote](https://drafts.csswg.org/css-content-3/#valdef-content-close-quote),
 [no-open-quote](https://drafts.csswg.org/css-content-3/#valdef-content-no-open-quote) and
 [no-close-quote](https://drafts.csswg.org/css-content-3/#valdef-content-no-close-quote) must be [scoped to the element's
 sub-tree](#property-scoped-to-a-sub-tree).

 This implies that the depth of quote nesting in the
 subtree is unchanged and starts at the value that its context
 normally implies, but that changes to the depth of quote nesting by
 these values inside the subtree do not affect the depth of quote
 nesting outside the subtree.

 Tests

 - [quote-scoping-001.html](https://wpt.fyi/results/css/css-contain/quote-scoping-001.html "css/css-contain/quote-scoping-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/quote-scoping-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/quote-scoping-001.html)
 - [quote-scoping-002.html](https://wpt.fyi/results/css/css-contain/quote-scoping-002.html "css/css-contain/quote-scoping-002.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/quote-scoping-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/quote-scoping-002.html)
 - [quote-scoping-003.html](https://wpt.fyi/results/css/css-contain/quote-scoping-003.html "css/css-contain/quote-scoping-003.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/quote-scoping-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/quote-scoping-003.html)
 - [quote-scoping-004.html](https://wpt.fyi/results/css/css-contain/quote-scoping-004.html "css/css-contain/quote-scoping-004.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/quote-scoping-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/quote-scoping-004.html)
 - [quote-scoping-empty-style-boundaries.html](https://wpt.fyi/results/css/css-contain/quote-scoping-empty-style-boundaries.html "css/css-contain/quote-scoping-empty-style-boundaries.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/quote-scoping-empty-style-boundaries.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/quote-scoping-empty-style-boundaries.html)
 - [quote-scoping-invalidation-001.html](https://wpt.fyi/results/css/css-contain/quote-scoping-invalidation-001.html "css/css-contain/quote-scoping-invalidation-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/quote-scoping-invalidation-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/quote-scoping-invalidation-001.html)
 - [quote-scoping-invalidation-002.html](https://wpt.fyi/results/css/css-contain/quote-scoping-invalidation-002.html "css/css-contain/quote-scoping-invalidation-002.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/quote-scoping-invalidation-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/quote-scoping-invalidation-002.html)
 - [quote-scoping-invalidation-003.html](https://wpt.fyi/results/css/css-contain/quote-scoping-invalidation-003.html "css/css-contain/quote-scoping-invalidation-003.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/quote-scoping-invalidation-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/quote-scoping-invalidation-003.html)
 - [quote-scoping-invalidation-004.html](https://wpt.fyi/results/css/css-contain/quote-scoping-invalidation-004.html "css/css-contain/quote-scoping-invalidation-004.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/quote-scoping-invalidation-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/quote-scoping-invalidation-004.html)

Tests

- [contain-style-baseline-001.html](https://wpt.fyi/results/css/css-contain/contain-style-baseline-001.html "css/css-contain/contain-style-baseline-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-style-baseline-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-style-baseline-001.html)
- [contain-style-breaks-001.html](https://wpt.fyi/results/css/css-contain/contain-style-breaks-001.html "css/css-contain/contain-style-breaks-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-style-breaks-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-style-breaks-001.html)
- [contain-style-breaks-002.html](https://wpt.fyi/results/css/css-contain/contain-style-breaks-002.html "css/css-contain/contain-style-breaks-002.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-style-breaks-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-style-breaks-002.html)
- [contain-style-breaks-003.html](https://wpt.fyi/results/css/css-contain/contain-style-breaks-003.html "css/css-contain/contain-style-breaks-003.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-style-breaks-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-style-breaks-003.html)
- [contain-style-breaks-004.html](https://wpt.fyi/results/css/css-contain/contain-style-breaks-004.html "css/css-contain/contain-style-breaks-004.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-style-breaks-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-style-breaks-004.html)
- [contain-style-breaks-005.html](https://wpt.fyi/results/css/css-contain/contain-style-breaks-005.html "css/css-contain/contain-style-breaks-005.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-style-breaks-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-style-breaks-005.html)

However, giving an element [style
containment](#style-containment) has no effect if any of the following are true:

- if the element does not generate a [principal
 box](https://drafts.csswg.org/css-display-4/#principal-box) (as is the case with [display:
 contents](https://drafts.csswg.org/css-display-3/#propdef-display) or [display:
 none])

[\[CSS-REGIONS-1\]](#biblio-css-regions-1 "CSS Regions Module Level 1")
has normative requirements on how [style
containment](#style-containment) affects regions.

A [scoped property] has its effects
scoped to a particular element or subtree.

- If [scoped to an element], it must act as if
 the scoping element was the root of the document for the purpose of
 evaluating the property's effects: any uses of the property outside
 the scoping element must have no effect on the uses of the property on
 or in the scoping element, and vice versa.

 "Scoping to an element" is currently unused. It is
 defined as an extension point for future specifications to use.

- If [scoped to a sub-tree],
 it's the same, except the scoping element itself is counted as
 \"outside\" the tree, like the rest of the document, and the effects
 of the property on that element are unaffected by scoping. When
 considering the effects of the scoped property on elements *inside*
 the subtree, the element at the base of the subtree is treated as if
 it was the root of the document.

 Tests

 - [counter-scoping-001.html](https://wpt.fyi/results/css/css-contain/counter-scoping-001.html "css/css-contain/counter-scoping-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/counter-scoping-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/counter-scoping-001.html)
 - [counter-scoping-002.html](https://wpt.fyi/results/css/css-contain/counter-scoping-002.html "css/css-contain/counter-scoping-002.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/counter-scoping-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/counter-scoping-002.html)
 - [counter-scoping-003.html](https://wpt.fyi/results/css/css-contain/counter-scoping-003.html "css/css-contain/counter-scoping-003.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/counter-scoping-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/counter-scoping-003.html)
 - [counter-scoping-004.html](https://wpt.fyi/results/css/css-contain/counter-scoping-004.html "css/css-contain/counter-scoping-004.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/counter-scoping-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/counter-scoping-004.html)
 - [contain-style-ol-ordinal-li-container.html](https://wpt.fyi/results/css/css-contain/contain-style-ol-ordinal-li-container.html "css/css-contain/contain-style-ol-ordinal-li-container.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-style-ol-ordinal-li-container.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-style-ol-ordinal-li-container.html)
 - [contain-style-ol-ordinal-pseudo-reversed.html](https://wpt.fyi/results/css/css-contain/contain-style-ol-ordinal-pseudo-reversed.html "css/css-contain/contain-style-ol-ordinal-pseudo-reversed.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-style-ol-ordinal-pseudo-reversed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-style-ol-ordinal-pseudo-reversed.html)
 - [contain-style-ol-ordinal-pseudo.html](https://wpt.fyi/results/css/css-contain/contain-style-ol-ordinal-pseudo.html "css/css-contain/contain-style-ol-ordinal-pseudo.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-style-ol-ordinal-pseudo.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-style-ol-ordinal-pseudo.html)
 - [contain-style-ol-ordinal-reversed.html](https://wpt.fyi/results/css/css-contain/contain-style-ol-ordinal-reversed.html "css/css-contain/contain-style-ol-ordinal-reversed.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-style-ol-ordinal-reversed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-style-ol-ordinal-reversed.html)
 - [contain-style-ol-ordinal-start-reversed.html](https://wpt.fyi/results/css/css-contain/contain-style-ol-ordinal-start-reversed.html "css/css-contain/contain-style-ol-ordinal-start-reversed.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-style-ol-ordinal-start-reversed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-style-ol-ordinal-start-reversed.html)
 - [contain-style-ol-ordinal-start.html](https://wpt.fyi/results/css/css-contain/contain-style-ol-ordinal-start.html "css/css-contain/contain-style-ol-ordinal-start.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-style-ol-ordinal-start.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-style-ol-ordinal-start.html)
 - [contain-style-ol-ordinal.html](https://wpt.fyi/results/css/css-contain/contain-style-ol-ordinal.html "css/css-contain/contain-style-ol-ordinal.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-style-ol-ordinal.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-style-ol-ordinal.html)

As
[counter-increment](https://drafts.csswg.org/css-lists-3/#propdef-counter-increment) is scoped to an element's subtree,
the first use of it within the subtree creates a fresh counter,
regardless of whether the counter had been used outside the scoping
element. Any increments made within the subtree have no effect on
counters of the same name outside the scoping element. However, the
[counter()] and [counters()] value of the
[content](https://drafts.csswg.org/css-content-3/#propdef-content) property is not itself scoped, and
can refer to counters established outside of the subtree.

For example, the following markup and style:

``` highlight
<div>
 <div style="contain: style;">
 <div></div>
 <div></div>
 </div>
 <div>
 <div></div>
 <div></div>
 </div>
</div>
```

``` highlight
body {
 counter-reset: foo;
}
div {
 counter-increment: foo;

 /* and to help observe nesting properly */
 margin: .2em;
 padding: .2em;
 background: #0001;
}
div::before {
 content: counters(foo, ".");
}
```

Will render like:

::::: {style="contain: style;"}
2

2.1

2.2

Here, the style-contained element still interacts with the [foo]
counter normally, incrementing it to 2. Its
[::before](https://drafts.csswg.org/css-pseudo-4/#selectordef-before)
[pseudo-element](https://drafts.csswg.org/selectors-4/#pseudo-element), which is effectively a child and thus within the
containment boundary, can still see that counter normally, and thus will
render the string \"`2`\".

Later siblings of the style-contained element don't see anything that
goes on within the boundary, so they increment the [foo] counter
to 3 and beyond.

Within the containment, however, the descendant divs aren't allowed to
modify the value of the outside counter, so instead they'll create a
fresh (nested) [foo] counter when they attempt to increment it.

#### 3.4.1. Possible Style-Containment Optimizations

*This section is non-normative.*

Possible optimizations that can be enabled by [style
containment](#style-containment) include (but are not limited to):

1. Whenever a property is changed on a descendant of an element with
 [style containment](#style-containment), calculating what part of the DOM tree is
 \"dirtied\" and might need to have its style recalculated can stop
 at the element with [style
 containment].

### 3.5. Paint Containment

Giving an element [paint containment] makes its [principal
box](https://drafts.csswg.org/css-display-4/#principal-box) a [paint containment box] and has the following effects:

1. The contents of the element including any
 [ink](https://drafts.csswg.org/css-overflow-3/#ink-overflow) or [scrollable
 overflow](https://drafts.csswg.org/css-overflow-3/#scrollable-overflow) must be clipped to the [overflow clip
 edge](https://drafts.csswg.org/css-overflow-4/#overflow-clip-edge) of the [paint containment
 box](#paint-containment-box), taking [corner
 clipping](https://drafts.csswg.org/css-backgrounds-3/#corner-clipping)
 into account. This does not include the creation of any mechanism to
 access or indicate the presence of the clipped content; nor does it
 inhibit the creation of any such mechanism through other properties,
 [such as
 [overflow](https://drafts.csswg.org/css-overflow-3/#propdef-overflow),
 [resize](https://drafts.csswg.org/css-ui-4/#propdef-resize), or
 [text-overflow](https://drafts.csswg.org/css-ui-3/#propdef-text-overflow)].

 Tests

 - [contain-paint-050.html](https://wpt.fyi/results/css/css-contain/contain-paint-050.html "css/css-contain/contain-paint-050.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-050.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-050.html)

 This clipping shape respects
 [overflow-clip-margin](https://drafts.csswg.org/css-overflow-4/#propdef-overflow-clip-margin), allowing an element with
 [paint containment](#paint-containment) to still slightly overflow its normal bounds.

 The behavior is described in this paragraph is
 equivalent to changing [overflow-x:
 visible](https://drafts.csswg.org/css-overflow-3/#propdef-overflow-x) into [overflow-x:
 clip] and [overflow-y:
 visible](https://drafts.csswg.org/css-overflow-3/#propdef-overflow-y) into [overflow-y:
 clip] at used value time, while
 leaving other values of [overflow-x] and [overflow-y]
 unchanged.

 Tests

 - [contain-paint-001.html](https://wpt.fyi/results/css/css-contain/contain-paint-001.html "css/css-contain/contain-paint-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-001.html)
 - [contain-paint-004.html](https://wpt.fyi/results/css/css-contain/contain-paint-004.html "css/css-contain/contain-paint-004.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-004.html)
 - [contain-paint-047.html](https://wpt.fyi/results/css/css-contain/contain-paint-047.html "css/css-contain/contain-paint-047.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-047.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-047.html)
 - [contain-paint-048.html](https://wpt.fyi/results/css/css-contain/contain-paint-048.html "css/css-contain/contain-paint-048.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-048.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-048.html)
 - [contain-paint-cell-001.html](https://wpt.fyi/results/css/css-contain/contain-paint-cell-001.html "css/css-contain/contain-paint-cell-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-cell-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-cell-001.html)
 - [contain-paint-cell-002.html](https://wpt.fyi/results/css/css-contain/contain-paint-cell-002.html "css/css-contain/contain-paint-cell-002.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-cell-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-cell-002.html)
 - [contain-paint-clip-011.html](https://wpt.fyi/results/css/css-contain/contain-paint-clip-011.html "css/css-contain/contain-paint-clip-011.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-clip-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-clip-011.html)
 - [contain-paint-clip-012.html](https://wpt.fyi/results/css/css-contain/contain-paint-clip-012.html "css/css-contain/contain-paint-clip-012.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-clip-012.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-clip-012.html)
 - [contain-paint-clip-013.html](https://wpt.fyi/results/css/css-contain/contain-paint-clip-013.html "css/css-contain/contain-paint-clip-013.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-clip-013.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-clip-013.html)
 - [contain-paint-clip-014.html](https://wpt.fyi/results/css/css-contain/contain-paint-clip-014.html "css/css-contain/contain-paint-clip-014.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-clip-014.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-clip-014.html)
 - [contain-paint-clip-015.html](https://wpt.fyi/results/css/css-contain/contain-paint-clip-015.html "css/css-contain/contain-paint-clip-015.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-clip-015.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-clip-015.html)
 - [contain-paint-clip-016.html](https://wpt.fyi/results/css/css-contain/contain-paint-clip-016.html "css/css-contain/contain-paint-clip-016.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-clip-016.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-clip-016.html)
 - [contain-paint-clip-017.html](https://wpt.fyi/results/css/css-contain/contain-paint-clip-017.html "css/css-contain/contain-paint-clip-017.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-clip-017.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-clip-017.html)
 - [contain-paint-clip-018.html](https://wpt.fyi/results/css/css-contain/contain-paint-clip-018.html "css/css-contain/contain-paint-clip-018.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-clip-018.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-clip-018.html)
 - [contain-paint-clip-019.html](https://wpt.fyi/results/css/css-contain/contain-paint-clip-019.html "css/css-contain/contain-paint-clip-019.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-clip-019.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-clip-019.html)
 - [contain-paint-table-001.html](https://wpt.fyi/results/css/css-contain/contain-paint-table-001.html "css/css-contain/contain-paint-table-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-table-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-table-001.html)
 - [contain-paint-table-002.html](https://wpt.fyi/results/css/css-contain/contain-paint-table-002.html "css/css-contain/contain-paint-table-002.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-table-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-table-002.html)
 - [contain-paint-026.html](https://wpt.fyi/results/css/css-contain/contain-paint-026.html "css/css-contain/contain-paint-026.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-026.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-026.html)
 - [contain-paint-049.html](https://wpt.fyi/results/css/css-contain/contain-paint-049.html "css/css-contain/contain-paint-049.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-049.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-049.html)
 - [contain-paint-clip-001.html](https://wpt.fyi/results/css/css-contain/contain-paint-clip-001.html "css/css-contain/contain-paint-clip-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-clip-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-clip-001.html)
 - [contain-paint-clip-002.html](https://wpt.fyi/results/css/css-contain/contain-paint-clip-002.html "css/css-contain/contain-paint-clip-002.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-clip-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-clip-002.html)
 - [contain-paint-clip-003.html](https://wpt.fyi/results/css/css-contain/contain-paint-clip-003.html "css/css-contain/contain-paint-clip-003.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-clip-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-clip-003.html)
 - [contain-paint-clip-004.html](https://wpt.fyi/results/css/css-contain/contain-paint-clip-004.html "css/css-contain/contain-paint-clip-004.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-clip-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-clip-004.html)
 - [contain-paint-clip-005.html](https://wpt.fyi/results/css/css-contain/contain-paint-clip-005.html "css/css-contain/contain-paint-clip-005.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-clip-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-clip-005.html)
 - [contain-paint-clip-006.html](https://wpt.fyi/results/css/css-contain/contain-paint-clip-006.html "css/css-contain/contain-paint-clip-006.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-clip-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-clip-006.html)

2. The [paint containment
 box](#paint-containment-box) establishes an [absolute positioning containing
 block](https://drafts.csswg.org/css-position-3/#absolute-positioning-containing-block) and a [fixed positioning containing
 block](https://drafts.csswg.org/css-position-3/#fixed-positioning-containing-block).

 Tests

 - [contain-paint-009.html](https://wpt.fyi/results/css/css-contain/contain-paint-009.html "css/css-contain/contain-paint-009.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-009.html)
 - [contain-paint-010.html](https://wpt.fyi/results/css/css-contain/contain-paint-010.html "css/css-contain/contain-paint-010.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-010.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-010.html)
 - [contain-paint-022.html](https://wpt.fyi/results/css/css-contain/contain-paint-022.html "css/css-contain/contain-paint-022.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-022.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-022.html)
 - [contain-paint-023.html](https://wpt.fyi/results/css/css-contain/contain-paint-023.html "css/css-contain/contain-paint-023.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-023.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-023.html)
 - [contain-paint-024.html](https://wpt.fyi/results/css/css-contain/contain-paint-024.html "css/css-contain/contain-paint-024.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-024.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-024.html)
 - [contain-paint-containing-block-absolute-001.html](https://wpt.fyi/results/css/css-contain/contain-paint-containing-block-absolute-001.html "css/css-contain/contain-paint-containing-block-absolute-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-containing-block-absolute-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-containing-block-absolute-001.html)
 - [contain-paint-containing-block-fixed-001.html](https://wpt.fyi/results/css/css-contain/contain-paint-containing-block-fixed-001.html "css/css-contain/contain-paint-containing-block-fixed-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-containing-block-fixed-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-containing-block-fixed-001.html)

3. The [paint containment
 box](#paint-containment-box) creates a [stacking
 context](https://www.w3.org/TR/CSS2/visuren.html#x43).

 Tests

 - [contain-paint-020.html](https://wpt.fyi/results/css/css-contain/contain-paint-020.html "css/css-contain/contain-paint-020.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-020.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-020.html)
 - [contain-paint-021.html](https://wpt.fyi/results/css/css-contain/contain-paint-021.html "css/css-contain/contain-paint-021.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-021.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-021.html)
 - [contain-paint-025.html](https://wpt.fyi/results/css/css-contain/contain-paint-025.html "css/css-contain/contain-paint-025.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-025.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-025.html)
 - [contain-subgrid-001.html](https://wpt.fyi/results/css/css-contain/contain-subgrid-001.html "css/css-contain/contain-subgrid-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-subgrid-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-subgrid-001.html)
 - [contain-paint-stacking-context-001a.html](https://wpt.fyi/results/css/css-contain/contain-paint-stacking-context-001a.html "css/css-contain/contain-paint-stacking-context-001a.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-stacking-context-001a.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-stacking-context-001a.html)
 - [contain-paint-stacking-context-001b.html](https://wpt.fyi/results/css/css-contain/contain-paint-stacking-context-001b.html "css/css-contain/contain-paint-stacking-context-001b.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-stacking-context-001b.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-stacking-context-001b.html)

4. The [paint containment
 box](#paint-containment-box) [establishes an independent formatting
 context](https://drafts.csswg.org/css-display-4/#establish-an-independent-formatting-context).

 Tests

 - [contain-paint-ifc-011.html](https://wpt.fyi/results/css/css-contain/contain-paint-ifc-011.html "css/css-contain/contain-paint-ifc-011.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-ifc-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-ifc-011.html)
 - [contain-paint-independent-formatting-context-001.html](https://wpt.fyi/results/css/css-contain/contain-paint-independent-formatting-context-001.html "css/css-contain/contain-paint-independent-formatting-context-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-independent-formatting-context-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-independent-formatting-context-001.html)
 - [contain-paint-independent-formatting-context-002.html](https://wpt.fyi/results/css/css-contain/contain-paint-independent-formatting-context-002.html "css/css-contain/contain-paint-independent-formatting-context-002.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-independent-formatting-context-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-independent-formatting-context-002.html)
 - [contain-paint-formatting-context-float-001.html](https://wpt.fyi/results/css/css-contain/contain-paint-formatting-context-float-001.html "css/css-contain/contain-paint-formatting-context-float-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-formatting-context-float-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-formatting-context-float-001.html)
 - [contain-paint-formatting-context-margin-001.html](https://wpt.fyi/results/css/css-contain/contain-paint-formatting-context-margin-001.html "css/css-contain/contain-paint-formatting-context-margin-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-formatting-context-margin-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-formatting-context-margin-001.html)
 - [contain-paint-baseline-001.html](https://wpt.fyi/results/css/css-contain/contain-paint-baseline-001.html "css/css-contain/contain-paint-baseline-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-baseline-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-baseline-001.html)

However, giving an element [paint
containment](#paint-containment) has no effect if any of the following are true:

- if the element does not generate a [principal
 box](https://drafts.csswg.org/css-display-4/#principal-box) (as is the case with [display:
 contents](https://drafts.csswg.org/css-display-3/#propdef-display) or [display:
 none])

 Tests

 - [contain-paint-ignored-cases-no-principal-box-001.html](https://wpt.fyi/results/css/css-contain/contain-paint-ignored-cases-no-principal-box-001.html "css/css-contain/contain-paint-ignored-cases-no-principal-box-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-ignored-cases-no-principal-box-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-ignored-cases-no-principal-box-001.html)

- if its [principal
 box](https://drafts.csswg.org/css-display-4/#principal-box) is an [internal table
 box](https://drafts.csswg.org/css-display-3/#internal-table-box) other than
 [table-cell](https://drafts.csswg.org/css-display-4/#valdef-display-table-cell)

 Tests

 - [contain-paint-014.html](https://wpt.fyi/results/css/css-contain/contain-paint-014.html "css/css-contain/contain-paint-014.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-014.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-014.html)
 - [contain-paint-015.html](https://wpt.fyi/results/css/css-contain/contain-paint-015.html "css/css-contain/contain-paint-015.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-015.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-015.html)
 - [contain-paint-016.html](https://wpt.fyi/results/css/css-contain/contain-paint-016.html "css/css-contain/contain-paint-016.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-016.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-016.html)
 - [contain-paint-017.html](https://wpt.fyi/results/css/css-contain/contain-paint-017.html "css/css-contain/contain-paint-017.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-017.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-017.html)
 - [contain-paint-018.html](https://wpt.fyi/results/css/css-contain/contain-paint-018.html "css/css-contain/contain-paint-018.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-018.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-018.html)
 - [contain-paint-019.html](https://wpt.fyi/results/css/css-contain/contain-paint-019.html "css/css-contain/contain-paint-019.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-019.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-019.html)
 - [contain-paint-ignored-cases-internal-table-001a.html](https://wpt.fyi/results/css/css-contain/contain-paint-ignored-cases-internal-table-001a.html "css/css-contain/contain-paint-ignored-cases-internal-table-001a.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-ignored-cases-internal-table-001a.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-ignored-cases-internal-table-001a.html)
 - [contain-paint-ignored-cases-internal-table-001b.html](https://wpt.fyi/results/css/css-contain/contain-paint-ignored-cases-internal-table-001b.html "css/css-contain/contain-paint-ignored-cases-internal-table-001b.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-ignored-cases-internal-table-001b.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-ignored-cases-internal-table-001b.html)

- if its [principal
 box](https://drafts.csswg.org/css-display-4/#principal-box) is an [internal ruby
 box](https://drafts.csswg.org/css-display-3/#internal-ruby-box) or a
 [non-atomic](https://drafts.csswg.org/css-display-3/#atomic-inline)
 [inline-level](https://drafts.csswg.org/css-display-3/#inline-level) box

 Tests

 - [contain-paint-005.html](https://wpt.fyi/results/css/css-contain/contain-paint-005.html "css/css-contain/contain-paint-005.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-005.html)
 - [contain-paint-006.html](https://wpt.fyi/results/css/css-contain/contain-paint-006.html "css/css-contain/contain-paint-006.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-006.html)
 - [contain-paint-007.html](https://wpt.fyi/results/css/css-contain/contain-paint-007.html "css/css-contain/contain-paint-007.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-007.html)
 - [contain-paint-008.html](https://wpt.fyi/results/css/css-contain/contain-paint-008.html "css/css-contain/contain-paint-008.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-008.html)
 - [contain-paint-ignored-cases-ruby-containing-block-001.html](https://wpt.fyi/results/css/css-contain/contain-paint-ignored-cases-ruby-containing-block-001.html "css/css-contain/contain-paint-ignored-cases-ruby-containing-block-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-ignored-cases-ruby-containing-block-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-ignored-cases-ruby-containing-block-001.html)
 - [contain-paint-ignored-cases-ruby-stacking-and-clipping-001.html](https://wpt.fyi/results/css/css-contain/contain-paint-ignored-cases-ruby-stacking-and-clipping-001.html "css/css-contain/contain-paint-ignored-cases-ruby-stacking-and-clipping-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-ignored-cases-ruby-stacking-and-clipping-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-ignored-cases-ruby-stacking-and-clipping-001.html)
 - [contain-paint-002.html](https://wpt.fyi/results/css/css-contain/contain-paint-002.html "css/css-contain/contain-paint-002.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-002.html)
 - [contain-paint-011.html](https://wpt.fyi/results/css/css-contain/contain-paint-011.html "css/css-contain/contain-paint-011.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-011.html)
 - [contain-paint-012.html](https://wpt.fyi/results/css/css-contain/contain-paint-012.html "css/css-contain/contain-paint-012.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-012.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-012.html)
 - [contain-paint-independent-formatting-context-003.html](https://wpt.fyi/results/css/css-contain/contain-paint-independent-formatting-context-003.html "css/css-contain/contain-paint-independent-formatting-context-003.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-independent-formatting-context-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-independent-formatting-context-003.html)
 - [contain-paint-ignored-cases-ib-split-001.html](https://wpt.fyi/results/css/css-contain/contain-paint-ignored-cases-ib-split-001.html "css/css-contain/contain-paint-ignored-cases-ib-split-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/contain-paint-ignored-cases-ib-split-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/contain-paint-ignored-cases-ib-split-001.html)

#### 3.5.1. Possible Paint-Containment Optimizations

*This section is non-normative.*

Possible optimizations that can be enabled by [paint
containment](#paint-containment) include (but are not limited to):

1. If the [containment
 box](#paint-containment-box) is off-screen or obscured, the UA can usually skip
 trying to paint its contents, as they're guaranteed to be
 off-screen/obscured as well.

 Some paint effects such as the
 [blur()](https://drafts.csswg.org/filter-effects-1/#funcdef-filter-blur) filter from
 [\[FILTER-EFFECTS-1\]](#biblio-filter-effects-1 "Filter Effects Module Level 1")
 have non local effects. The user agent needs to keep track of these,
 as it may need to repaint parts of an element with such a filter
 when its descendents change, even if they have [paint
 containment](#paint-containment) and could otherwise be skipped.

2. Unless the clipped content is made accessible via a separate
 mechanism such as the
 [overflow](https://drafts.csswg.org/css-overflow-3/#propdef-overflow) or
 [resize](https://drafts.csswg.org/css-ui-4/#propdef-resize) properties, the UA can reserve
 \"canvas\" space for the box exactly the box's size. (In similar,
 scrollable, situations, like [overflow:
 hidden], it's possible to scroll to
 the currently-clipped content, so UAs often predictively overpaint
 somewhat so there's something to see as soon as the scroll happens,
 rather than a frame later.)

3. Because they are guaranteed to be stacking contexts, scrolling
 elements can be painted into a single GPU layer.

## 4. Suppressing An Element's Contents Entirely: the [content-visibility property]
Tests

Tests related to content-visibility which haven\'t been triaged to any
particular point in the spec

- [content-visibility-085.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-085.html "css/css-contain/content-visibility/content-visibility-085.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-085.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-085.html)
- [content-visibility-086.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-086.html "css/css-contain/content-visibility/content-visibility-086.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-086.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-086.html)
- [content-visibility-087.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-087.html "css/css-contain/content-visibility/content-visibility-087.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-087.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-087.html)
- [content-visibility-088.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-088.html "css/css-contain/content-visibility/content-visibility-088.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-088.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-088.html)
- [content-visibility-089.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-089.html "css/css-contain/content-visibility/content-visibility-089.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-089.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-089.html)
- [content-visibility-090.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-090.html "css/css-contain/content-visibility/content-visibility-090.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-090.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-090.html)
- [content-visibility-091.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-091.html "css/css-contain/content-visibility/content-visibility-091.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-091.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-091.html)
- [content-visibility-092.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-092.html "css/css-contain/content-visibility/content-visibility-092.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-092.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-092.html)
- [content-visibility-093.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-093.html "css/css-contain/content-visibility/content-visibility-093.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-093.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-093.html)
- [content-visibility-094.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-094.html "css/css-contain/content-visibility/content-visibility-094.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-094.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-094.html)
- [content-visibility-095.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-095.html "css/css-contain/content-visibility/content-visibility-095.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-095.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-095.html)
- [content-visibility-096.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-096.html "css/css-contain/content-visibility/content-visibility-096.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-096.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-096.html)
- [content-visibility-097.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-097.html "css/css-contain/content-visibility/content-visibility-097.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-097.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-097.html)
- [content-visibility-098.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-098.html "css/css-contain/content-visibility/content-visibility-098.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-098.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-098.html)
- [content-visibility-099.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-099.html "css/css-contain/content-visibility/content-visibility-099.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-099.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-099.html)
- [content-visibility-animation-and-scroll.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-animation-and-scroll.html "css/css-contain/content-visibility/content-visibility-animation-and-scroll.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-animation-and-scroll.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-animation-and-scroll.html)
- [content-visibility-animation-becomes-visible.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-animation-becomes-visible.html "css/css-contain/content-visibility/content-visibility-animation-becomes-visible.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-animation-becomes-visible.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-animation-becomes-visible.html)
- [content-visibility-animation-in-auto-subtree.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-animation-in-auto-subtree.html "css/css-contain/content-visibility/content-visibility-animation-in-auto-subtree.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-animation-in-auto-subtree.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-animation-in-auto-subtree.html)
- [content-visibility-animation-with-scroll-timeline-in-auto-subtree.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-animation-with-scroll-timeline-in-auto-subtree.html "css/css-contain/content-visibility/content-visibility-animation-with-scroll-timeline-in-auto-subtree.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-animation-with-scroll-timeline-in-auto-subtree.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-animation-with-scroll-timeline-in-auto-subtree.html)
- [content-visibility-animation-with-scroll-timeline-in-hidden-subtree.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-animation-with-scroll-timeline-in-hidden-subtree.html "css/css-contain/content-visibility/content-visibility-animation-with-scroll-timeline-in-hidden-subtree.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-animation-with-scroll-timeline-in-hidden-subtree.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-animation-with-scroll-timeline-in-hidden-subtree.html)
- [content-visibility-auto-applied-to-th-crash.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-auto-applied-to-th-crash.html "css/css-contain/content-visibility/content-visibility-auto-applied-to-th-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-auto-applied-to-th-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-auto-applied-to-th-crash.html)
- [content-visibility-auto-first-observation-immediate.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-auto-first-observation-immediate.html "css/css-contain/content-visibility/content-visibility-auto-first-observation-immediate.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-auto-first-observation-immediate.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-auto-first-observation-immediate.html)
- [content-visibility-auto-nested-scroll.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-auto-nested-scroll.html "css/css-contain/content-visibility/content-visibility-auto-nested-scroll.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-auto-nested-scroll.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-auto-nested-scroll.html)
- [content-visibility-auto-nested.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-auto-nested.html "css/css-contain/content-visibility/content-visibility-auto-nested.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-auto-nested.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-auto-nested.html)
- [content-visibility-auto-relevancy-updates.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-auto-relevancy-updates.html "css/css-contain/content-visibility/content-visibility-auto-relevancy-updates.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-auto-relevancy-updates.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-auto-relevancy-updates.html)
- [content-visibility-auto-text-fragment.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-auto-text-fragment.html "css/css-contain/content-visibility/content-visibility-auto-text-fragment.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-auto-text-fragment.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-auto-text-fragment.html)
- [content-visibility-background-clip-crash.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-background-clip-crash.html "css/css-contain/content-visibility/content-visibility-background-clip-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-background-clip-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-background-clip-crash.html)
- [content-visibility-interpolation.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-interpolation.html "css/css-contain/content-visibility/content-visibility-interpolation.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-interpolation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-interpolation.html)
- [content-visibility-intrinsic-size-001.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-intrinsic-size-001.html "css/css-contain/content-visibility/content-visibility-intrinsic-size-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-intrinsic-size-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-intrinsic-size-001.html)
- [content-visibility-layout-containment-001.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-layout-containment-001.html "css/css-contain/content-visibility/content-visibility-layout-containment-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-layout-containment-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-layout-containment-001.html)
- [content-visibility-layout-paint-containment-001.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-layout-paint-containment-001.html "css/css-contain/content-visibility/content-visibility-layout-paint-containment-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-layout-paint-containment-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-layout-paint-containment-001.html)
- [content-visibility-on-g.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-on-g.html "css/css-contain/content-visibility/content-visibility-on-g.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-on-g.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-on-g.html)
- [content-visibility-on-root-svg.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-on-root-svg.html "css/css-contain/content-visibility/content-visibility-on-root-svg.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-on-root-svg.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-on-root-svg.html)
- [content-visibility-paint-containment-001.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-paint-containment-001.html "css/css-contain/content-visibility/content-visibility-paint-containment-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-paint-containment-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-paint-containment-001.html)
- [content-visibility-paint-containment-002.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-paint-containment-002.html "css/css-contain/content-visibility/content-visibility-paint-containment-002.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-paint-containment-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-paint-containment-002.html)
- [content-visibility-paint-containment-003.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-paint-containment-003.html "css/css-contain/content-visibility/content-visibility-paint-containment-003.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-paint-containment-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-paint-containment-003.html)
- [content-visibility-selection-crash.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-selection-crash.html "css/css-contain/content-visibility/content-visibility-selection-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-selection-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-selection-crash.html)
- [content-visibility-size-containment-001.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-size-containment-001.html "css/css-contain/content-visibility/content-visibility-size-containment-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-size-containment-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-size-containment-001.html)
- [content-visibility-style-containment-001.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-style-containment-001.html "css/css-contain/content-visibility/content-visibility-style-containment-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-style-containment-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-style-containment-001.html)
- [content-visibility-svg-path.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-svg-path.html "css/css-contain/content-visibility/content-visibility-svg-path.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-svg-path.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-svg-path.html)
- [content-visibility-svg-rect.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-svg-rect.html "css/css-contain/content-visibility/content-visibility-svg-rect.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-svg-rect.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-svg-rect.html)
- [content-visibility-svg-text.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-svg-text.html "css/css-contain/content-visibility/content-visibility-svg-text.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-svg-text.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-svg-text.html)
- [content-visibility-vs-scrollIntoView-001.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-vs-scrollIntoView-001.html "css/css-contain/content-visibility/content-visibility-vs-scrollIntoView-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-vs-scrollIntoView-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-vs-scrollIntoView-001.html)
- [content-visibility-vs-scrollIntoView-002.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-vs-scrollIntoView-002.html "css/css-contain/content-visibility/content-visibility-vs-scrollIntoView-002.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-vs-scrollIntoView-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-vs-scrollIntoView-002.html)
- [content-visibility-vs-scrollIntoView-003.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-vs-scrollIntoView-003.html "css/css-contain/content-visibility/content-visibility-vs-scrollIntoView-003.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-vs-scrollIntoView-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-vs-scrollIntoView-003.html)
- [content-visibility-web-animation-in-auto-subtree.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-web-animation-in-auto-subtree.html "css/css-contain/content-visibility/content-visibility-web-animation-in-auto-subtree.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-web-animation-in-auto-subtree.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-web-animation-in-auto-subtree.html)
- [content-visibility-with-float-crash.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-with-float-crash.html "css/css-contain/content-visibility/content-visibility-with-float-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-with-float-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-with-float-crash.html)
- [content-visibility-with-popover-top-layer-000.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-with-popover-top-layer-000.html "css/css-contain/content-visibility/content-visibility-with-popover-top-layer-000.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-with-popover-top-layer-000.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-with-popover-top-layer-000.html)
- [content-visibility-with-popover-top-layer-001.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-with-popover-top-layer-001.html "css/css-contain/content-visibility/content-visibility-with-popover-top-layer-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-with-popover-top-layer-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-with-popover-top-layer-001.html)
- [content-visibility-with-popover-top-layer-002.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-with-popover-top-layer-002.html "css/css-contain/content-visibility/content-visibility-with-popover-top-layer-002.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-with-popover-top-layer-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-with-popover-top-layer-002.html)
- [content-visibility-with-popover-top-layer-003.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-with-popover-top-layer-003.html "css/css-contain/content-visibility/content-visibility-with-popover-top-layer-003.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-with-popover-top-layer-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-with-popover-top-layer-003.html)
- [content-visibility-with-popover-top-layer-004.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-with-popover-top-layer-004.html "css/css-contain/content-visibility/content-visibility-with-popover-top-layer-004.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-with-popover-top-layer-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-with-popover-top-layer-004.html)
- [content-visibility-with-popover-top-layer-005.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-with-popover-top-layer-005.html "css/css-contain/content-visibility/content-visibility-with-popover-top-layer-005.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-with-popover-top-layer-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-with-popover-top-layer-005.html)
- [content-visibility-with-popover-top-layer-006.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-with-popover-top-layer-006.html "css/css-contain/content-visibility/content-visibility-with-popover-top-layer-006.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-with-popover-top-layer-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-with-popover-top-layer-006.html)
- [content-visibility-with-popover-top-layer-and-auto-descendant.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-with-popover-top-layer-and-auto-descendant.html "css/css-contain/content-visibility/content-visibility-with-popover-top-layer-and-auto-descendant.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-with-popover-top-layer-and-auto-descendant.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-with-popover-top-layer-and-auto-descendant.html)
- [content-visibility-with-popover-top-layer-hide-after-addition.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-with-popover-top-layer-hide-after-addition.html "css/css-contain/content-visibility/content-visibility-with-popover-top-layer-hide-after-addition.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-with-popover-top-layer-hide-after-addition.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-with-popover-top-layer-hide-after-addition.html)
- [content-visibility-with-top-layer-007.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-with-top-layer-007.html "css/css-contain/content-visibility/content-visibility-with-top-layer-007.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-with-top-layer-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-with-top-layer-007.html)
- [content-visibility-with-top-layer-008.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-with-top-layer-008.html "css/css-contain/content-visibility/content-visibility-with-top-layer-008.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-with-top-layer-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-with-top-layer-008.html)
- [content-visibility-with-top-layer-and-auto-descendant.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-with-top-layer-and-auto-descendant.html "css/css-contain/content-visibility/content-visibility-with-top-layer-and-auto-descendant.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-with-top-layer-and-auto-descendant.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-with-top-layer-and-auto-descendant.html)
- [content-visibility-with-top-layer-in-auto-subtree-removal.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-with-top-layer-in-auto-subtree-removal.html "css/css-contain/content-visibility/content-visibility-with-top-layer-in-auto-subtree-removal.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-with-top-layer-in-auto-subtree-removal.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-with-top-layer-in-auto-subtree-removal.html)

------------------------------------------------------------------------

Name:

[content-visibility]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

visible
[\|](https://drafts.csswg.org/css-values-4/#comb-one) auto [\|] hidden

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

visible

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

elements for which [size
containment](#size-containment) can apply

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

as specified

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

see [§ 4.1 Animating and Interpolating
content-visibility](#content-visibility-animation)

Tests

- [content-visibility-051.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-051.html "css/css-contain/content-visibility/content-visibility-051.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-051.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-051.html)
- [content-visibility-073.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-073.html "css/css-contain/content-visibility/content-visibility-073.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-073.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-073.html)
- [inheritance.html](https://wpt.fyi/results/css/css-contain/content-visibility/inheritance.html "css/css-contain/content-visibility/inheritance.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/inheritance.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/inheritance.html)
- [content-visibility-computed.html](https://wpt.fyi/results/css/css-contain/content-visibility/parsing/content-visibility-computed.html "css/css-contain/content-visibility/parsing/content-visibility-computed.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/parsing/content-visibility-computed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/parsing/content-visibility-computed.html)
- [content-visibility-invalid.html](https://wpt.fyi/results/css/css-contain/content-visibility/parsing/content-visibility-invalid.html "css/css-contain/content-visibility/parsing/content-visibility-invalid.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/parsing/content-visibility-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/parsing/content-visibility-invalid.html)
- [content-visibility-valid.html](https://wpt.fyi/results/css/css-contain/content-visibility/parsing/content-visibility-valid.html "css/css-contain/content-visibility/parsing/content-visibility-valid.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/parsing/content-visibility-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/parsing/content-visibility-valid.html)
- [content-visibility-077.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-077.html "css/css-contain/content-visibility/content-visibility-077.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-077.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-077.html)
- [content-visibility-resize-observer-no-error.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-resize-observer-no-error.html "css/css-contain/content-visibility/content-visibility-resize-observer-no-error.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-resize-observer-no-error.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-resize-observer-no-error.html)

The following tests are crash tests that relate to general usage of this
feature but are not particularly tied to any particular normative
statement.

- [content-visibility-069.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-069.html "css/css-contain/content-visibility/content-visibility-069.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-069.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-069.html)
- [content-visibility-auto-selection-crash.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-auto-selection-crash.html "css/css-contain/content-visibility/content-visibility-auto-selection-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-auto-selection-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-auto-selection-crash.html)
- [content-visibility-continuations-crash.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-continuations-crash.html "css/css-contain/content-visibility/content-visibility-continuations-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-continuations-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-continuations-crash.html)
- [content-visibility-form-controls-crash.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-form-controls-crash.html "css/css-contain/content-visibility/content-visibility-form-controls-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-form-controls-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-form-controls-crash.html)
- [content-visibility-hit-test-contents-crash.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-hit-test-contents-crash.html "css/css-contain/content-visibility/content-visibility-hit-test-contents-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-hit-test-contents-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-hit-test-contents-crash.html)
- [content-visibility-in-svg-000-crash.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-in-svg-000-crash.html "css/css-contain/content-visibility/content-visibility-in-svg-000-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-in-svg-000-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-in-svg-000-crash.html)
- [content-visibility-output-crash.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-output-crash.html "css/css-contain/content-visibility/content-visibility-output-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-output-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-output-crash.html)
- [contentvisibility-nestedslot-crash.html](https://wpt.fyi/results/css/css-contain/content-visibility/contentvisibility-nestedslot-crash.html "css/css-contain/content-visibility/contentvisibility-nestedslot-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/contentvisibility-nestedslot-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/contentvisibility-nestedslot-crash.html)
- [first-line-and-inline-block.html](https://wpt.fyi/results/css/css-contain/content-visibility/crashtests/first-line-and-inline-block.html "css/css-contain/content-visibility/crashtests/first-line-and-inline-block.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/crashtests/first-line-and-inline-block.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/crashtests/first-line-and-inline-block.html)
- [detach-locked-slot-children-crash.html](https://wpt.fyi/results/css/css-contain/content-visibility/detach-locked-slot-children-crash.html "css/css-contain/content-visibility/detach-locked-slot-children-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/detach-locked-slot-children-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/detach-locked-slot-children-crash.html)
- [hidden-execcommand-crash.html](https://wpt.fyi/results/css/css-contain/content-visibility/hidden-execcommand-crash.html "css/css-contain/content-visibility/hidden-execcommand-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/hidden-execcommand-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/hidden-execcommand-crash.html)
- [hidden-pseudo-element-removed-crash.html](https://wpt.fyi/results/css/css-contain/content-visibility/hidden-pseudo-element-removed-crash.html "css/css-contain/content-visibility/hidden-pseudo-element-removed-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/hidden-pseudo-element-removed-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/hidden-pseudo-element-removed-crash.html)
- [meter-selection-crash.html](https://wpt.fyi/results/css/css-contain/content-visibility/meter-selection-crash.html "css/css-contain/content-visibility/meter-selection-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/meter-selection-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/meter-selection-crash.html)
- [slot-content-visibility-1-crash.html](https://wpt.fyi/results/css/css-contain/content-visibility/slot-content-visibility-1-crash.html "css/css-contain/content-visibility/slot-content-visibility-1-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/slot-content-visibility-1-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/slot-content-visibility-1-crash.html)
- [slot-content-visibility-10-crash.html](https://wpt.fyi/results/css/css-contain/content-visibility/slot-content-visibility-10-crash.html "css/css-contain/content-visibility/slot-content-visibility-10-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/slot-content-visibility-10-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/slot-content-visibility-10-crash.html)
- [slot-content-visibility-11-crash.html](https://wpt.fyi/results/css/css-contain/content-visibility/slot-content-visibility-11-crash.html "css/css-contain/content-visibility/slot-content-visibility-11-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/slot-content-visibility-11-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/slot-content-visibility-11-crash.html)
- [slot-content-visibility-12-crash.html](https://wpt.fyi/results/css/css-contain/content-visibility/slot-content-visibility-12-crash.html "css/css-contain/content-visibility/slot-content-visibility-12-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/slot-content-visibility-12-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/slot-content-visibility-12-crash.html)
- [slot-content-visibility-13-crash.html](https://wpt.fyi/results/css/css-contain/content-visibility/slot-content-visibility-13-crash.html "css/css-contain/content-visibility/slot-content-visibility-13-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/slot-content-visibility-13-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/slot-content-visibility-13-crash.html)
- [slot-content-visibility-14-crash.html](https://wpt.fyi/results/css/css-contain/content-visibility/slot-content-visibility-14-crash.html "css/css-contain/content-visibility/slot-content-visibility-14-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/slot-content-visibility-14-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/slot-content-visibility-14-crash.html)
- [slot-content-visibility-15-crash.html](https://wpt.fyi/results/css/css-contain/content-visibility/slot-content-visibility-15-crash.html "css/css-contain/content-visibility/slot-content-visibility-15-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/slot-content-visibility-15-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/slot-content-visibility-15-crash.html)
- [slot-content-visibility-16-crash.html](https://wpt.fyi/results/css/css-contain/content-visibility/slot-content-visibility-16-crash.html "css/css-contain/content-visibility/slot-content-visibility-16-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/slot-content-visibility-16-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/slot-content-visibility-16-crash.html)
- [slot-content-visibility-17-crash.html](https://wpt.fyi/results/css/css-contain/content-visibility/slot-content-visibility-17-crash.html "css/css-contain/content-visibility/slot-content-visibility-17-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/slot-content-visibility-17-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/slot-content-visibility-17-crash.html)
- [slot-content-visibility-18-crash.html](https://wpt.fyi/results/css/css-contain/content-visibility/slot-content-visibility-18-crash.html "css/css-contain/content-visibility/slot-content-visibility-18-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/slot-content-visibility-18-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/slot-content-visibility-18-crash.html)
- [slot-content-visibility-19-crash.html](https://wpt.fyi/results/css/css-contain/content-visibility/slot-content-visibility-19-crash.html "css/css-contain/content-visibility/slot-content-visibility-19-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/slot-content-visibility-19-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/slot-content-visibility-19-crash.html)
- [slot-content-visibility-2-crash.html](https://wpt.fyi/results/css/css-contain/content-visibility/slot-content-visibility-2-crash.html "css/css-contain/content-visibility/slot-content-visibility-2-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/slot-content-visibility-2-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/slot-content-visibility-2-crash.html)
- [slot-content-visibility-20-crash.html](https://wpt.fyi/results/css/css-contain/content-visibility/slot-content-visibility-20-crash.html "css/css-contain/content-visibility/slot-content-visibility-20-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/slot-content-visibility-20-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/slot-content-visibility-20-crash.html)
- [slot-content-visibility-21-crash.html](https://wpt.fyi/results/css/css-contain/content-visibility/slot-content-visibility-21-crash.html "css/css-contain/content-visibility/slot-content-visibility-21-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/slot-content-visibility-21-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/slot-content-visibility-21-crash.html)
- [slot-content-visibility-22-crash.html](https://wpt.fyi/results/css/css-contain/content-visibility/slot-content-visibility-22-crash.html "css/css-contain/content-visibility/slot-content-visibility-22-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/slot-content-visibility-22-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/slot-content-visibility-22-crash.html)
- [slot-content-visibility-3-crash.html](https://wpt.fyi/results/css/css-contain/content-visibility/slot-content-visibility-3-crash.html "css/css-contain/content-visibility/slot-content-visibility-3-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/slot-content-visibility-3-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/slot-content-visibility-3-crash.html)
- [slot-content-visibility-4-crash.html](https://wpt.fyi/results/css/css-contain/content-visibility/slot-content-visibility-4-crash.html "css/css-contain/content-visibility/slot-content-visibility-4-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/slot-content-visibility-4-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/slot-content-visibility-4-crash.html)
- [slot-content-visibility-5-crash.html](https://wpt.fyi/results/css/css-contain/content-visibility/slot-content-visibility-5-crash.html "css/css-contain/content-visibility/slot-content-visibility-5-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/slot-content-visibility-5-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/slot-content-visibility-5-crash.html)
- [slot-content-visibility-6-crash.html](https://wpt.fyi/results/css/css-contain/content-visibility/slot-content-visibility-6-crash.html "css/css-contain/content-visibility/slot-content-visibility-6-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/slot-content-visibility-6-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/slot-content-visibility-6-crash.html)
- [slot-content-visibility-7-crash.html](https://wpt.fyi/results/css/css-contain/content-visibility/slot-content-visibility-7-crash.html "css/css-contain/content-visibility/slot-content-visibility-7-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/slot-content-visibility-7-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/slot-content-visibility-7-crash.html)
- [slot-content-visibility-8-crash.html](https://wpt.fyi/results/css/css-contain/content-visibility/slot-content-visibility-8-crash.html "css/css-contain/content-visibility/slot-content-visibility-8-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/slot-content-visibility-8-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/slot-content-visibility-8-crash.html)
- [slot-content-visibility-9-crash.html](https://wpt.fyi/results/css/css-contain/content-visibility/slot-content-visibility-9-crash.html "css/css-contain/content-visibility/slot-content-visibility-9-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/slot-content-visibility-9-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/slot-content-visibility-9-crash.html)
- [content-visibility-transition-finished-001.html](https://wpt.fyi/results/css/css-contain/content-visibility/crashtests/content-visibility-transition-finished-001.html "css/css-contain/content-visibility/crashtests/content-visibility-transition-finished-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/crashtests/content-visibility-transition-finished-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/crashtests/content-visibility-transition-finished-001.html)
- [grid-dynamic.html](https://wpt.fyi/results/css/css-contain/content-visibility/crashtests/grid-dynamic.html "css/css-contain/content-visibility/crashtests/grid-dynamic.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/crashtests/grid-dynamic.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/crashtests/grid-dynamic.html)
- [display-ruby-text-crash.html](https://wpt.fyi/results/css/css-contain/content-visibility/display-ruby-text-crash.html "css/css-contain/content-visibility/display-ruby-text-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/display-ruby-text-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/display-ruby-text-crash.html)
- [locked-frame-crash.html](https://wpt.fyi/results/css/css-contain/content-visibility/locked-frame-crash.html "css/css-contain/content-visibility/locked-frame-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/locked-frame-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/locked-frame-crash.html)
- [touch-action-beside-display-locked-fixedpos-iframe-crash.html](https://wpt.fyi/results/css/css-contain/content-visibility/touch-action-beside-display-locked-fixedpos-iframe-crash.html "css/css-contain/content-visibility/touch-action-beside-display-locked-fixedpos-iframe-crash.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/touch-action-beside-display-locked-fixedpos-iframe-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/touch-action-beside-display-locked-fixedpos-iframe-crash.html)

------------------------------------------------------------------------

these should be more accurately dispatched paragraph per paragraph to
the relevant points in the specification

------------------------------------------------------------------------

The
[content-visibility](#propdef-content-visibility) property controls whether or not an
element renders its contents at all, along with forcing a strong set of
[containments](#containment),
allowing user agents to potentially omit large swathes of layout and
rendering work until it becomes needed. It has the following values:

[visible]

: No effect. The element's contents are laid out and rendered as
 normal.

 Tests

 - [content-visibility-002.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-002.html "css/css-contain/content-visibility/content-visibility-002.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-002.html)
 - [content-visibility-012.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-012.html "css/css-contain/content-visibility/content-visibility-012.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-012.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-012.html)
 - [content-visibility-013.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-013.html "css/css-contain/content-visibility/content-visibility-013.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-013.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-013.html)
 - [content-visibility-014.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-014.html "css/css-contain/content-visibility/content-visibility-014.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-014.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-014.html)
 - [content-visibility-023.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-023.html "css/css-contain/content-visibility/content-visibility-023.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-023.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-023.html)
 - [content-visibility-024.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-024.html "css/css-contain/content-visibility/content-visibility-024.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-024.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-024.html)
 - [content-visibility-025.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-025.html "css/css-contain/content-visibility/content-visibility-025.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-025.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-025.html)
 - [content-visibility-042.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-042.html "css/css-contain/content-visibility/content-visibility-042.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-042.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-042.html)
 - [content-visibility-052.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-052.html "css/css-contain/content-visibility/content-visibility-052.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-052.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-052.html)
 - [content-visibility-057.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-057.html "css/css-contain/content-visibility/content-visibility-057.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-057.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-057.html)
 - [content-visibility-with-top-layer-003.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-with-top-layer-003.html "css/css-contain/content-visibility/content-visibility-with-top-layer-003.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-with-top-layer-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-with-top-layer-003.html)

[hidden]

: The element [skips its
 contents](#skips-its-contents).

 Tests

 - [content-visibility-001.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-001.html "css/css-contain/content-visibility/content-visibility-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-001.html)
 - [content-visibility-003.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-003.html "css/css-contain/content-visibility/content-visibility-003.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-003.html)
 - [content-visibility-004.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-004.html "css/css-contain/content-visibility/content-visibility-004.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-004.html)
 - [content-visibility-005.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-005.html "css/css-contain/content-visibility/content-visibility-005.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-005.html)
 - [content-visibility-006.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-006.html "css/css-contain/content-visibility/content-visibility-006.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-006.html)
 - [content-visibility-007.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-007.html "css/css-contain/content-visibility/content-visibility-007.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-007.html)
 - [content-visibility-008.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-008.html "css/css-contain/content-visibility/content-visibility-008.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-008.html)
 - [content-visibility-009.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-009.html "css/css-contain/content-visibility/content-visibility-009.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-009.html)
 - [content-visibility-010.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-010.html "css/css-contain/content-visibility/content-visibility-010.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-010.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-010.html)
 - [content-visibility-011.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-011.html "css/css-contain/content-visibility/content-visibility-011.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-011.html)
 - [content-visibility-015.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-015.html "css/css-contain/content-visibility/content-visibility-015.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-015.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-015.html)
 - [content-visibility-016.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-016.html "css/css-contain/content-visibility/content-visibility-016.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-016.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-016.html)
 - [content-visibility-017.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-017.html "css/css-contain/content-visibility/content-visibility-017.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-017.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-017.html)
 - [content-visibility-018.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-018.html "css/css-contain/content-visibility/content-visibility-018.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-018.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-018.html)
 - [content-visibility-019.sub.https.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-019.sub.https.html "css/css-contain/content-visibility/content-visibility-019.sub.https.html")
 [[(live
 test)]](https://wpt.live/css/css-contain/content-visibility/content-visibility-019.sub.https.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-019.sub.https.html)
 - [content-visibility-020.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-020.html "css/css-contain/content-visibility/content-visibility-020.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-020.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-020.html)
 - [content-visibility-021.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-021.html "css/css-contain/content-visibility/content-visibility-021.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-021.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-021.html)
 - [content-visibility-022.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-022.html "css/css-contain/content-visibility/content-visibility-022.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-022.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-022.html)
 - [content-visibility-026.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-026.html "css/css-contain/content-visibility/content-visibility-026.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-026.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-026.html)
 - [content-visibility-028.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-028.html "css/css-contain/content-visibility/content-visibility-028.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-028.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-028.html)
 - [content-visibility-029.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-029.html "css/css-contain/content-visibility/content-visibility-029.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-029.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-029.html)
 - [content-visibility-030.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-030.html "css/css-contain/content-visibility/content-visibility-030.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-030.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-030.html)
 - [content-visibility-031.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-031.html "css/css-contain/content-visibility/content-visibility-031.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-031.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-031.html)
 - [content-visibility-032.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-032.html "css/css-contain/content-visibility/content-visibility-032.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-032.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-032.html)
 - [content-visibility-033.sub.https.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-033.sub.https.html "css/css-contain/content-visibility/content-visibility-033.sub.https.html")
 [[(live
 test)]](https://wpt.live/css/css-contain/content-visibility/content-visibility-033.sub.https.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-033.sub.https.html)
 - [content-visibility-034.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-034.html "css/css-contain/content-visibility/content-visibility-034.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-034.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-034.html)
 - [content-visibility-036.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-036.html "css/css-contain/content-visibility/content-visibility-036.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-036.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-036.html)
 - [content-visibility-037.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-037.html "css/css-contain/content-visibility/content-visibility-037.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-037.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-037.html)
 - [content-visibility-038.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-038.html "css/css-contain/content-visibility/content-visibility-038.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-038.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-038.html)
 - [content-visibility-039.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-039.html "css/css-contain/content-visibility/content-visibility-039.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-039.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-039.html)
 - [content-visibility-040.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-040.html "css/css-contain/content-visibility/content-visibility-040.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-040.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-040.html)
 - [content-visibility-041.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-041.html "css/css-contain/content-visibility/content-visibility-041.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-041.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-041.html)
 - [content-visibility-043.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-043.html "css/css-contain/content-visibility/content-visibility-043.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-043.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-043.html)
 - [content-visibility-044.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-044.html "css/css-contain/content-visibility/content-visibility-044.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-044.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-044.html)
 - [content-visibility-045.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-045.html "css/css-contain/content-visibility/content-visibility-045.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-045.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-045.html)
 - [content-visibility-072.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-072.html "css/css-contain/content-visibility/content-visibility-072.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-072.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-072.html)
 - [content-visibility-078.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-078.html "css/css-contain/content-visibility/content-visibility-078.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-078.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-078.html)
 - [content-visibility-082.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-082.html "css/css-contain/content-visibility/content-visibility-082.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-082.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-082.html)
 - [content-visibility-canvas.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-canvas.html "css/css-contain/content-visibility/content-visibility-canvas.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-canvas.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-canvas.html)
 - [content-visibility-forced-layout-client-rects.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-forced-layout-client-rects.html "css/css-contain/content-visibility/content-visibility-forced-layout-client-rects.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-forced-layout-client-rects.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-forced-layout-client-rects.html)
 - [content-visibility-img.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-img.html "css/css-contain/content-visibility/content-visibility-img.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-img.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-img.html)
 - [content-visibility-input-image.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-input-image.html "css/css-contain/content-visibility/content-visibility-input-image.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-input-image.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-input-image.html)
 - [content-visibility-svg.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-svg.html "css/css-contain/content-visibility/content-visibility-svg.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-svg.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-svg.html)
 - [content-visibility-video.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-video.html "css/css-contain/content-visibility/content-visibility-video.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-video.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-video.html)
 - [content-visibility-fieldset-size.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-fieldset-size.html "css/css-contain/content-visibility/content-visibility-fieldset-size.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-fieldset-size.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-fieldset-size.html)
 - [content-visibility-with-top-layer-000.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-with-top-layer-000.html "css/css-contain/content-visibility/content-visibility-with-top-layer-000.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-with-top-layer-000.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-with-top-layer-000.html)
 - [content-visibility-with-top-layer-001.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-with-top-layer-001.html "css/css-contain/content-visibility/content-visibility-with-top-layer-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-with-top-layer-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-with-top-layer-001.html)
 - [content-visibility-with-top-layer-002.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-with-top-layer-002.html "css/css-contain/content-visibility/content-visibility-with-top-layer-002.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-with-top-layer-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-with-top-layer-002.html)
 - [document-element-computed-style.html](https://wpt.fyi/results/css/css-contain/content-visibility/document-element-computed-style.html "css/css-contain/content-visibility/document-element-computed-style.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/document-element-computed-style.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/document-element-computed-style.html)
 - [element-reassigned-to-skipped-slot.html](https://wpt.fyi/results/css/css-contain/content-visibility/element-reassigned-to-skipped-slot.html "css/css-contain/content-visibility/element-reassigned-to-skipped-slot.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/element-reassigned-to-skipped-slot.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/element-reassigned-to-skipped-slot.html)
 - [element-reassigned-to-slot-in-skipped-subtree.html](https://wpt.fyi/results/css/css-contain/content-visibility/element-reassigned-to-slot-in-skipped-subtree.html "css/css-contain/content-visibility/element-reassigned-to-slot-in-skipped-subtree.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/element-reassigned-to-slot-in-skipped-subtree.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/element-reassigned-to-slot-in-skipped-subtree.html)
 - [scrollIntoView-target-with-contents-hidden.html](https://wpt.fyi/results/css/css-contain/content-visibility/scrollIntoView-target-with-contents-hidden.html "css/css-contain/content-visibility/scrollIntoView-target-with-contents-hidden.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/scrollIntoView-target-with-contents-hidden.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/scrollIntoView-target-with-contents-hidden.html)
 - [scrollIntoView-with-focus-target-with-contents-hidden.html](https://wpt.fyi/results/css/css-contain/content-visibility/scrollIntoView-with-focus-target-with-contents-hidden.html "css/css-contain/content-visibility/scrollIntoView-with-focus-target-with-contents-hidden.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/scrollIntoView-with-focus-target-with-contents-hidden.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/scrollIntoView-with-focus-target-with-contents-hidden.html)
 - [content-visibility-with-top-layer-hide-after-addition.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-with-top-layer-hide-after-addition.html "css/css-contain/content-visibility/content-visibility-with-top-layer-hide-after-addition.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-with-top-layer-hide-after-addition.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-with-top-layer-hide-after-addition.html)
 - [dynamic-change-paint-fully-obscuring-child-001.html](https://wpt.fyi/results/css/css-contain/content-visibility/dynamic-change-paint-fully-obscuring-child-001.html "css/css-contain/content-visibility/dynamic-change-paint-fully-obscuring-child-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/dynamic-change-paint-fully-obscuring-child-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/dynamic-change-paint-fully-obscuring-child-001.html)

 The [skipped
 contents](#skips-its-contents) *must not* be accessible to user-agent features,
 such as find-in-page, tab-order navigation, etc., nor be selectable
 or focusable.

 Tests

 - [content-visibility-035.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-035.html "css/css-contain/content-visibility/content-visibility-035.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-035.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-035.html)
 - [content-visibility-047.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-047.html "css/css-contain/content-visibility/content-visibility-047.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-047.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-047.html)
 - [content-visibility-056.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-056.html "css/css-contain/content-visibility/content-visibility-056.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-056.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-056.html)
 - [content-visibility-060.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-060.html "css/css-contain/content-visibility/content-visibility-060.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-060.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-060.html)
 - [content-visibility-061.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-061.html "css/css-contain/content-visibility/content-visibility-061.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-061.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-061.html)
 - [content-visibility-067.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-067.html "css/css-contain/content-visibility/content-visibility-067.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-067.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-067.html)
 - [content-visibility-083.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-083.html "css/css-contain/content-visibility/content-visibility-083.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-083.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-083.html)
 - [content-visibility-084.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-084.html "css/css-contain/content-visibility/content-visibility-084.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-084.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-084.html)

 This is similar to giving the contents [display:
 none](https://drafts.csswg.org/css-display-3/#propdef-display).

 Tests

 - [content-visibility-041.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-041.html "css/css-contain/content-visibility/content-visibility-041.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-041.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-041.html)

[auto]

: Changes the [used
 value](https://drafts.csswg.org/css-cascade-5/#used-value) of the
 [contain](#propdef-contain) property so as to turn on [layout
 containment](#layout-containment), [style
 containment](#style-containment), and [paint
 containment](#paint-containment) for the element.

 Tests

 - [content-visibility-026.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-026.html "css/css-contain/content-visibility/content-visibility-026.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-026.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-026.html)
 - [content-visibility-027.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-027.html "css/css-contain/content-visibility/content-visibility-027.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-027.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-027.html)
 - [content-visibility-074.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-074.html "css/css-contain/content-visibility/content-visibility-074.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-074.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-074.html)
 - [content-visibility-auto-in-iframe.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-auto-in-iframe.html "css/css-contain/content-visibility/content-visibility-auto-in-iframe.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-auto-in-iframe.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-auto-in-iframe.html)
 - [content-visibility-auto-intrinsic-width.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-auto-intrinsic-width.html "css/css-contain/content-visibility/content-visibility-auto-intrinsic-width.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-auto-intrinsic-width.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-auto-intrinsic-width.html)
 - [content-visibility-auto-state-changed-first-observation.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-auto-state-changed-first-observation.html "css/css-contain/content-visibility/content-visibility-auto-state-changed-first-observation.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-auto-state-changed-first-observation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-auto-state-changed-first-observation.html)
 - [content-visibility-auto-state-changed-removed.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-auto-state-changed-removed.html "css/css-contain/content-visibility/content-visibility-auto-state-changed-removed.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-auto-state-changed-removed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-auto-state-changed-removed.html)
 - [content-visibility-auto-state-changed.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-auto-state-changed.html "css/css-contain/content-visibility/content-visibility-auto-state-changed.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-auto-state-changed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-auto-state-changed.html)
 - [content-visibility-with-top-layer-005.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-with-top-layer-005.html "css/css-contain/content-visibility/content-visibility-with-top-layer-005.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-with-top-layer-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-with-top-layer-005.html)
 - [content-visibility-with-top-layer-006.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-with-top-layer-006.html "css/css-contain/content-visibility/content-visibility-with-top-layer-006.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-with-top-layer-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-with-top-layer-006.html)

 If the element is not [relevant to the
 user](#relevant-to-the-user), it also [skips its
 contents](#skips-its-contents).

 Tests

 - [content-visibility-046.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-046.html "css/css-contain/content-visibility/content-visibility-046.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-046.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-046.html)
 - [content-visibility-050.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-050.html "css/css-contain/content-visibility/content-visibility-050.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-050.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-050.html)
 - [content-visibility-058.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-058.html "css/css-contain/content-visibility/content-visibility-058.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-058.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-058.html)
 - [content-visibility-064.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-064.html "css/css-contain/content-visibility/content-visibility-064.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-064.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-064.html)
 - [content-visibility-068.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-068.html "css/css-contain/content-visibility/content-visibility-068.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-068.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-068.html)
 - [content-visibility-072.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-072.html "css/css-contain/content-visibility/content-visibility-072.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-072.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-072.html)
 - [content-visibility-079.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-079.html "css/css-contain/content-visibility/content-visibility-079.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-079.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-079.html)
 - [content-visibility-with-top-layer-003.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-with-top-layer-003.html "css/css-contain/content-visibility/content-visibility-with-top-layer-003.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-with-top-layer-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-with-top-layer-003.html)
 - [content-visibility-auto-state-changed-first-observation.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-auto-state-changed-first-observation.html "css/css-contain/content-visibility/content-visibility-auto-state-changed-first-observation.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-auto-state-changed-first-observation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-auto-state-changed-first-observation.html)
 - [content-visibility-auto-state-changed.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-auto-state-changed.html "css/css-contain/content-visibility/content-visibility-auto-state-changed.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-auto-state-changed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-auto-state-changed.html)

 Unlike
 [hidden](#valdef-content-visibility-hidden), the [skipped
 contents](#skips-its-contents) *must* still be available as normal to user-agent
 features such as find-in-page, tab order navigation, etc., and must
 be focusable and selectable as normal.

 Tests

 - [content-visibility-048.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-048.html "css/css-contain/content-visibility/content-visibility-048.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-048.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-048.html)
 - [content-visibility-049.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-049.html "css/css-contain/content-visibility/content-visibility-049.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-049.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-049.html)
 - [content-visibility-050.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-050.html "css/css-contain/content-visibility/content-visibility-050.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-050.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-050.html)
 - [content-visibility-053.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-053.html "css/css-contain/content-visibility/content-visibility-053.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-053.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-053.html)
 - [content-visibility-054.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-054.html "css/css-contain/content-visibility/content-visibility-054.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-054.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-054.html)
 - [content-visibility-055.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-055.html "css/css-contain/content-visibility/content-visibility-055.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-055.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-055.html)
 - [content-visibility-058.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-058.html "css/css-contain/content-visibility/content-visibility-058.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-058.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-058.html)
 - [content-visibility-062.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-062.html "css/css-contain/content-visibility/content-visibility-062.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-062.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-062.html)
 - [content-visibility-063.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-063.html "css/css-contain/content-visibility/content-visibility-063.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-063.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-063.html)
 - [content-visibility-064.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-064.html "css/css-contain/content-visibility/content-visibility-064.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-064.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-064.html)
 - [content-visibility-065.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-065.html "css/css-contain/content-visibility/content-visibility-065.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-065.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-065.html)
 - [content-visibility-066.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-066.html "css/css-contain/content-visibility/content-visibility-066.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-066.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-066.html)
 - [content-visibility-068.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-068.html "css/css-contain/content-visibility/content-visibility-068.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-068.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-068.html)
 - [content-visibility-070.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-070.html "css/css-contain/content-visibility/content-visibility-070.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-070.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-070.html)
 - [content-visibility-071.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-071.html "css/css-contain/content-visibility/content-visibility-071.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-071.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-071.html)
 - [content-visibility-075.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-075.html "css/css-contain/content-visibility/content-visibility-075.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-075.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-075.html)
 - [content-visibility-076.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-076.html "css/css-contain/content-visibility/content-visibility-076.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-076.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-076.html)

When an element [skips its contents],
the user agent must change the [used
value](https://drafts.csswg.org/css-cascade-5/#used-value) of the
[contain](#propdef-contain) property so as to turn on [layout
containment](#layout-containment), [style
containment](#style-containment), [paint
containment](#paint-containment), and [size
containment](#size-containment). Further, its [contents] (the [flat
tree](https://drafts.csswg.org/css-shadow-1/#flat-tree) descendants of the element, including both text and
elements, or the replaced content of a [replaced
element](https://drafts.csswg.org/css-display-4/#replaced-element)) are not painted (as if they had [visibility:
hidden](https://drafts.csswg.org/css-display-4/#propdef-visibility)) and do not respond to hit-testing (as if
they had [pointer-events:
none](https://drafts.csswg.org/css-ui-4/#propdef-pointer-events)), and to a large extent do not update their
styles at all unless explicitly requested by script (see [§ 4.5
Restrictions and Clarifications](#cv-notes) for details).

Tests

- [content-visibility-001.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-001.html "css/css-contain/content-visibility/content-visibility-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-001.html)
- [content-visibility-003.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-003.html "css/css-contain/content-visibility/content-visibility-003.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-003.html)
- [content-visibility-004.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-004.html "css/css-contain/content-visibility/content-visibility-004.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-004.html)
- [content-visibility-005.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-005.html "css/css-contain/content-visibility/content-visibility-005.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-005.html)
- [content-visibility-006.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-006.html "css/css-contain/content-visibility/content-visibility-006.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-006.html)
- [content-visibility-007.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-007.html "css/css-contain/content-visibility/content-visibility-007.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-007.html)
- [content-visibility-008.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-008.html "css/css-contain/content-visibility/content-visibility-008.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-008.html)
- [content-visibility-009.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-009.html "css/css-contain/content-visibility/content-visibility-009.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-009.html)
- [content-visibility-010.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-010.html "css/css-contain/content-visibility/content-visibility-010.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-010.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-010.html)
- [content-visibility-011.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-011.html "css/css-contain/content-visibility/content-visibility-011.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-011.html)
- [content-visibility-015.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-015.html "css/css-contain/content-visibility/content-visibility-015.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-015.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-015.html)
- [content-visibility-016.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-016.html "css/css-contain/content-visibility/content-visibility-016.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-016.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-016.html)
- [content-visibility-017.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-017.html "css/css-contain/content-visibility/content-visibility-017.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-017.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-017.html)
- [content-visibility-018.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-018.html "css/css-contain/content-visibility/content-visibility-018.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-018.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-018.html)
- [content-visibility-020.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-020.html "css/css-contain/content-visibility/content-visibility-020.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-020.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-020.html)
- [content-visibility-021.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-021.html "css/css-contain/content-visibility/content-visibility-021.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-021.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-021.html)
- [content-visibility-022.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-022.html "css/css-contain/content-visibility/content-visibility-022.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-022.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-022.html)
- [content-visibility-026.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-026.html "css/css-contain/content-visibility/content-visibility-026.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-026.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-026.html)
- [content-visibility-028.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-028.html "css/css-contain/content-visibility/content-visibility-028.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-028.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-028.html)
- [content-visibility-034.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-034.html "css/css-contain/content-visibility/content-visibility-034.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-034.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-034.html)
- [content-visibility-035.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-035.html "css/css-contain/content-visibility/content-visibility-035.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-035.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-035.html)
- [content-visibility-036.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-036.html "css/css-contain/content-visibility/content-visibility-036.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-036.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-036.html)
- [content-visibility-037.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-037.html "css/css-contain/content-visibility/content-visibility-037.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-037.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-037.html)
- [content-visibility-038.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-038.html "css/css-contain/content-visibility/content-visibility-038.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-038.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-038.html)
- [content-visibility-039.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-039.html "css/css-contain/content-visibility/content-visibility-039.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-039.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-039.html)
- [content-visibility-040.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-040.html "css/css-contain/content-visibility/content-visibility-040.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-040.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-040.html)
- [content-visibility-041.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-041.html "css/css-contain/content-visibility/content-visibility-041.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-041.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-041.html)
- [content-visibility-045.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-045.html "css/css-contain/content-visibility/content-visibility-045.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-045.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-045.html)
- [content-visibility-051.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-051.html "css/css-contain/content-visibility/content-visibility-051.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-051.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-051.html)
- [content-visibility-072.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-072.html "css/css-contain/content-visibility/content-visibility-072.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-072.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-072.html)
- [content-visibility-078.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-078.html "css/css-contain/content-visibility/content-visibility-078.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-078.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-078.html)
- [content-visibility-080.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-080.html "css/css-contain/content-visibility/content-visibility-080.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-080.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-080.html)
- [content-visibility-canvas.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-canvas.html "css/css-contain/content-visibility/content-visibility-canvas.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-canvas.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-canvas.html)
- [content-visibility-fieldset-size.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-fieldset-size.html "css/css-contain/content-visibility/content-visibility-fieldset-size.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-fieldset-size.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-fieldset-size.html)
- [content-visibility-forced-layout-client-rects.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-forced-layout-client-rects.html "css/css-contain/content-visibility/content-visibility-forced-layout-client-rects.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-forced-layout-client-rects.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-forced-layout-client-rects.html)
- [content-visibility-img.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-img.html "css/css-contain/content-visibility/content-visibility-img.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-img.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-img.html)
- [content-visibility-input-image.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-input-image.html "css/css-contain/content-visibility/content-visibility-input-image.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-input-image.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-input-image.html)
- [content-visibility-svg.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-svg.html "css/css-contain/content-visibility/content-visibility-svg.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-svg.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-svg.html)
- [content-visibility-video.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-video.html "css/css-contain/content-visibility/content-visibility-video.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-video.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-video.html)
- [content-visibility-with-top-layer-hide-after-addition.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-with-top-layer-hide-after-addition.html "css/css-contain/content-visibility/content-visibility-with-top-layer-hide-after-addition.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-with-top-layer-hide-after-addition.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-with-top-layer-hide-after-addition.html)
- [document-element-computed-style.html](https://wpt.fyi/results/css/css-contain/content-visibility/document-element-computed-style.html "css/css-contain/content-visibility/document-element-computed-style.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/document-element-computed-style.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/document-element-computed-style.html)
- [element-reassigned-to-skipped-slot.html](https://wpt.fyi/results/css/css-contain/content-visibility/element-reassigned-to-skipped-slot.html "css/css-contain/content-visibility/element-reassigned-to-skipped-slot.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/element-reassigned-to-skipped-slot.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/element-reassigned-to-skipped-slot.html)
- [element-reassigned-to-slot-in-skipped-subtree.html](https://wpt.fyi/results/css/css-contain/content-visibility/element-reassigned-to-slot-in-skipped-subtree.html "css/css-contain/content-visibility/element-reassigned-to-slot-in-skipped-subtree.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/element-reassigned-to-slot-in-skipped-subtree.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/element-reassigned-to-slot-in-skipped-subtree.html)
- [content-visibility-auto-state-changed-first-observation.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-auto-state-changed-first-observation.html "css/css-contain/content-visibility/content-visibility-auto-state-changed-first-observation.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-auto-state-changed-first-observation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-auto-state-changed-first-observation.html)

The user agent *should* additionally avoid as much layout/rendering work
as possible for [skipped
contents](#skips-its-contents); the combination of heavy
[containment](#containment) and
making the contents invisible and untouchable enables heavy
optimizations. If rendering work is done at some point, the user-agent
should retain the previously computed layout state if possible, to allow
the [skipped contents] to be displayed
quickly at a later moment.

Tests

- [content-visibility-081.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-081.html "css/css-contain/content-visibility/content-visibility-081.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-081.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-081.html)

If an element has a value other than [content-visibility:
visible](#propdef-content-visibility), then the following properties hold:

- [layout
 containment](#layout-containment) ensures that the user-agent is able to omit layout
 work in skipped subtrees, since the results of such layouts will not
 affect elements outside of the container element.

- [style containment](#style-containment) ensures that counters do not have to be processed in
 skipped subtrees, since they do not affect counters outside of the
 container element.

- [paint containment](#paint-containment) ensures that ink overflow of painted contents is
 clipped; this, in turn, means that user-agent can reliably determine
 when the visible portion of the element approaches the viewport (and,
 for [content-visibility:
 auto](#propdef-content-visibility), start painting it).

- [size containment](#size-containment) ensures that the user-agent is able to omit layout in
 skipped subtrees, since the results of such layouts will not affect
 the container element's size.

Note that in the [content-visibility:
auto](#propdef-content-visibility) case, [layout
containment](#layout-containment), [style
containment](#style-containment), and [paint
containment](#paint-containment) persist even if the element is not
[skipped](#skips-its-contents). This is done to prevent layout changes that would be
incurred by [containment](#containment) changes as a result of an element entering and exiting
the [skipped] state.

An element that has [content-visibility:
auto](#propdef-content-visibility) is in one of three states when it comes to
its [proximity to the viewport]:

- The element is [close to the viewport]: In this state, the element
 is considered \"on-screen\": its [paint containment
 box](#paint-containment-box)'s [overflow clip
 edge](https://drafts.csswg.org/css-overflow-4/#overflow-clip-edge) intersects with the viewport, or a user-agent defined
 margin around the viewport.

 This margin is meant to allow the user agent to begin
 preparing for an element to be in the viewport soon. A margin of 50%
 is suggested as a reasonable default.

 If a filter (see
 [\[FILTER-EFFECTS-1\]](#biblio-filter-effects-1 "Filter Effects Module Level 1"))
 with non local effects includes the element as part of its input, the
 user agent should also treat the element as relevant to the user when
 the filter's output can affect the rendering within the viewport (or
 within the user-agent defined margin around the viewport), even if the
 element itself is still off-screen.

- The element is [far away from the
 viewport]: In this state, the element's proximity to the viewport
 has been computed and is not [close to the
 viewport](#close-to-the-viewport).

- The element's [proximity to the
 viewport](#proximity-to-the-viewport) is [not determined]: In this state, the computation to
 determine the element's [proximity to the
 viewport] has not been done since
 the last time the element was connected.

Initially, the element's [proximity to the
viewport](#proximity-to-the-viewport) is [not
determined](#not-determined).
Only connected elements with [content-visibility:
auto](#propdef-content-visibility) determine their [proximity to the
viewport]. When the element becomes
disconnected, the element's [proximity to the
viewport] becomes [not
determined].

All elements have a [currently relevant to the
user] flag, initially false.

To [update currently relevant to the
user] given an element `element`:

1. Let `currentlyRelevant` be true if `element`
 is [relevant to the
 user](#relevant-to-the-user), otherwise false.

2. If `element`'s [currently relevant to the
 user](#currently-relevant-to-the-user) flag is equal to `currentlyRelevant`,
 then return false.

3. Set `element`'s [currently relevant to the
 user](#currently-relevant-to-the-user) flag to `currentlyRelevant`.

4. return true.

To [update content relevancy for a
document] given a document `doc`, and a
boolean `updateNonInitial`:

1. Let `changed` be false.

2. For each `element`
 [connected](https://dom.spec.whatwg.org/#connected) to `doc` with
 [auto](#valdef-content-visibility-auto) used value of [content-visibility]:

 1. If `updateNonInitial` is true:

 1. If [update currently relevant to the
 user](#update-currently-relevant-to-the-user) for `element` returns true.

 1. Set `changed` to true.

 2. Let `isInitialDetermination` be true if
 `element`'s [proximity to the
 viewport](#proximity-to-the-viewport) is [not
 determined](#not-determined), otherwise false.

 3. Determine [proximity to the
 viewport](#proximity-to-the-viewport) for `element`.

 4. If `isInitialDetermination` is false, then
 [continue](https://infra.spec.whatwg.org/#iteration-continue).

 5. If [update currently relevant to the
 user](#update-currently-relevant-to-the-user) for `element` returns true.

 1. Set `changed` to true.

3. return `changed`.

The intent of the `changed` and `updateNonInitial`
variables is for the initial viewport proximity determination, which
takes effect immediately, to be reflected in the style and layout
calculation this frame.

Proximity determinations other than the initial one take effect at the
next rendering opportunity.

An element is [relevant to the user] if **any** of the following
conditions are true:

- The element is [close to the
 viewport](#close-to-the-viewport).

 Tests

 - [content-visibility-046.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-046.html "css/css-contain/content-visibility/content-visibility-046.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-046.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-046.html)
 - [content-visibility-079.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-079.html "css/css-contain/content-visibility/content-visibility-079.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-079.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-079.html)
 - [content-visibility-auto-in-iframe.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-auto-in-iframe.html "css/css-contain/content-visibility/content-visibility-auto-in-iframe.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-auto-in-iframe.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-auto-in-iframe.html)
 - [content-visibility-auto-intrinsic-width.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-auto-intrinsic-width.html "css/css-contain/content-visibility/content-visibility-auto-intrinsic-width.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-auto-intrinsic-width.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-auto-intrinsic-width.html)

- Either the element or its
 [contents](https://www.w3.org/TR/CSS2/conform.html#content) are focused, as described in the
 [focus](https://html.spec.whatwg.org/multipage/interaction.html#focus)
 section of the HTML spec.

 Tests

 - [content-visibility-050.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-050.html "css/css-contain/content-visibility/content-visibility-050.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-050.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-050.html)
 - [content-visibility-064.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-064.html "css/css-contain/content-visibility/content-visibility-064.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-064.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-064.html)
 - [content-visibility-068.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-068.html "css/css-contain/content-visibility/content-visibility-068.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-068.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-068.html)

- Either the element or its
 [contents](https://www.w3.org/TR/CSS2/conform.html#content) are selected, where selection is described in the
 [selection API](https://www.w3.org/TR/selection-api/#dfn-selection).

 Tests

 - [content-visibility-070.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-070.html "css/css-contain/content-visibility/content-visibility-070.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-070.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-070.html)
 - [content-visibility-071.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-071.html "css/css-contain/content-visibility/content-visibility-071.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-071.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-071.html)

- Either the element or its
 [contents](https://www.w3.org/TR/CSS2/conform.html#content) are placed in the [top
 layer](https://drafts.csswg.org/css-position-4/#document-top-layer).

 Tests

 - [content-visibility-with-top-layer-004.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-with-top-layer-004.html "css/css-contain/content-visibility/content-visibility-with-top-layer-004.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-with-top-layer-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-with-top-layer-004.html)
 - [content-visibility-with-top-layer-005.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-with-top-layer-005.html "css/css-contain/content-visibility/content-visibility-with-top-layer-005.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-with-top-layer-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-with-top-layer-005.html)
 - [content-visibility-with-top-layer-006.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-with-top-layer-006.html "css/css-contain/content-visibility/content-visibility-with-top-layer-006.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-with-top-layer-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-with-top-layer-006.html)

- The element has a [flat
 tree](https://drafts.csswg.org/css-shadow-1/#flat-tree) descendant that is [captured in a view
 transition](https://drafts.csswg.org/css-view-transitions-2/#element-captured-in-a-view-transition).

### 4.1. Animating and Interpolating [content-visibility]
In general, the
[content-visibility](#propdef-content-visibility) property's [animation
type](https://drafts.csswg.org/web-animations-1/#animation-type) is
[discrete](https://drafts.csswg.org/web-animations-1/#discrete). However, similar to interpolation of
[visibility](https://drafts.csswg.org/css-display-4/#propdef-visibility) (see [Web Animations §  Animation
of
visibility](https://drafts.csswg.org/web-animations-1/#animating-visibility)),
during interpolation between
[hidden](#valdef-content-visibility-hidden) and any other
[content-visibility]
value, `p` values between 0 and 1 map to the
non-[hidden] value.

### 4.2. Using [content-visibility: hidden]
*This section is non-normative.*

[content-visibility:
hidden](#propdef-content-visibility) lays powerful restrictions onto an element,
and so should be used with caution. It also enables some very useful
scenarios, often improving on existing techniques, a few of which are
outlined here.

1. If a page needs to take some measurements of elements or text which
 aren't themselves going to be rendered, commonly this is done by
 positioning the stuff-to-be-measured off-screen, using something
 like [position: absolute; left:
 -100000px;](https://drafts.csswg.org/css-position-3/#propdef-position), then calling an API like
 [`getBoundingClientRect()`](https://drafts.csswg.org/cssom-view-1/#dom-element-getboundingclientrect).

 Unfortunately, even though the page never intends to display this
 content, the user agent will still have to do full styling, layout,
 and rendering for the content, *just in case* it affects what's
 shown on screen. The author also can't, without further work,
 guarantee that the content *won't* accidentally show up on-screen;
 even a very negative
 [left](https://drafts.csswg.org/css-position-3/#propdef-left) value (like above) might not be
 enough, depending on the content.

 Wrapping this content in a [content-visibility:
 hidden](#propdef-content-visibility) container solves all of these problems.
 If the wrapper has no border, background, etc, then it and its
 [skipped contents](#skips-its-contents) are guaranteed to never render anything to the
 screen, no matter how big they get. Because the contents are
 [skipped], the user agent can also
 avoid styling or laying them out until absolutely necessary, when
 script finally asks for it.

2. A \"single-page app\" often consists of several independent panes or
 \"views\", of which only one is displayed at a time.

 If the author wants to avoid paying styling/layout/rendering/etc
 cost for the inactive views, they can remove them from the document
 entirely, or at minimum apply [display:none] to them.
 Unfortunately, this means that when the view *does* need to be
 displayed, all of the styling/layout/rendering/etc work needs to be
 done all at once, potentially causing a noticeable delay before the
 view actually shows up.

 Alternately, the view can just be positioned off-screen. This means
 it'll be immediately ready when it's time to be used, but it incurs
 the cost of styling/layout/rendering all the time, which might be
 significant, especially if there are a number of inactive views. The
 inactive views also might still show up to accessibility tooling,
 confusing users of screen-readers, people using Ctrl-F to
 find-in-page, etc.

 [content-visibility:
 hidden](#propdef-content-visibility) improves on both of these options.
 Because the contents are
 [skipped](#skips-its-contents), the user agent isn't spending time on them when
 they're not active. They're also not visible to screen readers,
 find-in-page, and other tools. And because user agents *should*
 preserve previous styling/layout work if possible, if the view was
 displayed before, re-rendering it might be very fast.

3. If an author wants to make an element \"invisible\", but still show
 up in the page for layout purposes, one option is [visibility:
 hidden](https://drafts.csswg.org/css-display-4/#propdef-visibility). However, descendants of a [visibility:
 hidden] element can set
 [visibility: visible] and start
 showing up again, which isn't always intuitive or expected.

 [content-visibility:
 hidden](#propdef-content-visibility) performs a very similar purpose, but
 descendants can't turn it \"off\" and start displaying; they stay
 \"hidden\" until the ancestor turns it off.

 Because [content-visibility:
 hidden](#propdef-content-visibility) also applies many
 [containment](#containment)
 values to the container, it's not always quite as usable as
 [visibility:
 hidden](https://drafts.csswg.org/css-display-4/#propdef-visibility) would be, but when its restrictions are
 acceptable, it can be a more reliable, more consistent way to hide
 an element's contents.

### 4.3. Using [content-visibility: auto]
*This section is non-normative.*

[content-visibility:
auto](#propdef-content-visibility) is a more complex value than
[hidden](#valdef-content-visibility-hidden); rather than being similar to [display:
none](https://drafts.csswg.org/css-display-3/#propdef-display), it adaptively hides/displays an element's
contents as they become [relevant to the
user](#relevant-to-the-user). It also doesn't hide its [skipped
contents](#skips-its-contents) from the user agent, so screen readers, find-in-page,
and other tools can still interact with it.

It is best to think of it as *an upgrade to
[containment](#containment)*: if
an author has a large amount of content to display that will often be
off-screen (such as a long scrollable list), and that content is okay
with heavy [containment](#containment), they should consider using [content-visibility:
auto](#propdef-content-visibility) to apply all of the
[containments] at once. This also strongly hints
to the user agent that it's acceptable to skip work on the contents
(possibly causing a small delay when they do come on-screen) because
it's more important to have a large amount of content in the document
and most of it won't be seen anyway.

 [content-visibility:
auto](#propdef-content-visibility) can thus be used *instead of* complicated
\"virtual list\" techniques, at least in many cases.

Because [content-visibility:
auto](#propdef-content-visibility) only causes the element to
[skip](#skips-its-contents) its contents when none of it is [relevant to the
user](#relevant-to-the-user), it's best to use at a reasonably fine granularity.

For example, on Twitter, applying
[content-visibility:
auto](#propdef-content-visibility) to the entire timeline wouldn't accomplish
much---​it's always on-screen, and so it will never [skip its
contents](#skips-its-contents).

Instead,
[content-visibility](#propdef-content-visibility) should be applied to *individual
tweets*, allowing each of them to be
[skipped](#skips-its-contents) as they go off-screen.

Because [content-visibility:
auto](#propdef-content-visibility) imposes [size
containment](#size-containment) when the element [skips its
contents](#skips-its-contents), if the element depends on its contents to determine
its size the layout of the page (or at least, the scrollbar position)
can \"jump around\" as elements go off-screen and start
[skipping].

This can be fixed in a number of ways:

- making the element fixed-size

- carefully arranging a layout such as Grid to size the element without
 depending on its contents

- using
 [contain-intrinsic-size](https://drafts.csswg.org/css-sizing-4/#propdef-contain-intrinsic-size) to set an *estimate* of the
 element's size

- using [contain-intrinsic-size:
 auto](https://drafts.csswg.org/css-sizing-4/#propdef-contain-intrinsic-size) to automatically \"snapshot\" the *exact*
 size of the element from the last time it was rendered, before it was
 [skipped](#skips-its-contents) (along with providing an estimate of the size to be
 used before it's rendered and can have its size snapshotted)

For example, on Twitter, the average tweet is approximately 200px tall,
so [contain-intrinsic-size: auto 500px
200px](https://drafts.csswg.org/css-sizing-4/#propdef-contain-intrinsic-size) will ensure that the scrollbar thumb is in
approximately the correct size and position even when preceding or
following tweets are
[skipped](#skips-its-contents), while still allowing the tweets to size according to
their contents when they're on-screen. As long as the tweets have all
been viewed at least once (and haven't changed size while they were
[skipped]), their sizes will be *exactly*
correct while they're [skipped], so the
scrollbar thumb will be as well; only freshly-loaded tweets (such as
those loaded at the top of the timeline while you are scrolling further
down) will be forced to rely on the [200px] height estimate.

### 4.4. Detecting [content-visibility: auto state changes: the [contentvisibilityautostatechange](#eventdef-element-contentvisibilityautostatechange) event]
The
[`contentvisibilityautostatechange`] event is fired on an element with [content-visibility:
auto](#propdef-content-visibility) style when the rendering state changes and
the element either becomes or stops being [relevant to the
user](#relevant-to-the-user).

Tests

- [content-visibility-auto-state-changed.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-auto-state-changed.html "css/css-contain/content-visibility/content-visibility-auto-state-changed.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-auto-state-changed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-auto-state-changed.html)
- [content-visibility-auto-state-changed-first-observation.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-auto-state-changed-first-observation.html "css/css-contain/content-visibility/content-visibility-auto-state-changed-first-observation.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-auto-state-changed-first-observation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-auto-state-changed-first-observation.html)
- [content-visibility-auto-state-changed-removed.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-auto-state-changed-removed.html "css/css-contain/content-visibility/content-visibility-auto-state-changed-removed.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-auto-state-changed-removed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-auto-state-changed-removed.html)
- [content-visibility-auto-state-changed.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-auto-state-changed.html "css/css-contain/content-visibility/content-visibility-auto-state-changed.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-auto-state-changed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-auto-state-changed.html)

This event is dispatched by posting a task at the time when the state
change occurs.

```
[Exposed=Window]
interface ContentVisibilityAutoStateChangeEvent : Event {
 constructor(DOMString type, optional ContentVisibilityAutoStateChangeEventInit eventInitDict = );
 readonly attribute boolean skipped;
};
dictionary ContentVisibilityAutoStateChangeEventInit : EventInit {
 boolean skipped = false;
};
```

Description of ContentVisibilityAutoStateChangeEvent attributes:

[`skipped`], of type [boolean](https://webidl.spec.whatwg.org/#idl-boolean), readonly

: Set to true if target changed state to [skip its
 contents](#skips-its-contents), and false otherwise.

 Tests

 - [content-visibility-auto-state-changed-first-observation.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-auto-state-changed-first-observation.html "css/css-contain/content-visibility/content-visibility-auto-state-changed-first-observation.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-auto-state-changed-first-observation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-auto-state-changed-first-observation.html)
 - [content-visibility-auto-state-changed.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-auto-state-changed.html "css/css-contain/content-visibility/content-visibility-auto-state-changed.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-auto-state-changed.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-auto-state-changed.html)

Description of ContentVisibilityAutoStateChangeEventInit members:

[`skipped`], of type [boolean](https://webidl.spec.whatwg.org/#idl-boolean), defaulting to `false`

: See the description of the
 [`skipped`](#dom-contentvisibilityautostatechangeevent-skipped) attribute.

Note that elements in [content-visibility:
auto](#propdef-content-visibility) subtrees remain semantically relevant even
for elements that [skip its
contents](#skips-its-contents). This means that it is inappropriate to use this signal
to indefinitely skip DOM updates in the subtree that is skipped.
Instead, it should be used to deprioritize updates, but ensure that the
content remains semantically relevant and reasonably up-to-date. This is
particularly important for assistive technologies which consume this
content even when the ancestor is set to [skip its
contents].

### 4.5. Restrictions and Clarifications

1. From the perspective of an
 [`IntersectionObserver`](https://w3c.github.io/IntersectionObserver/#intersectionobserver), the [skipped
 contents](#skips-its-contents) of an element are never intersecting the
 [intersection
 root](https://w3c.github.io/IntersectionObserver/#intersectionobserver-intersection-root). This is true even if both the root and the target
 elements are in the [skipped
 contents].

 Tests

 - [content-visibility-030.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-030.html "css/css-contain/content-visibility/content-visibility-030.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-030.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-030.html)

2. From the perspective of a
 [`ResizeObserver`](https://drafts.csswg.org/resize-observer-1/#resizeobserver), the [skipped
 contents](#skips-its-contents) of an element never change their size. If these
 elements become non-skipped later, the resize observation will be
 delivered if the new size differs from the last size used to notify
 the resize observer.

 Tests

 - [content-visibility-031.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-031.html "css/css-contain/content-visibility/content-visibility-031.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-031.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-031.html)

3. If an element starts or stops [skipping its
 contents](#skips-its-contents), this change happens when [update content relevancy
 for a
 document](#update-content-relevancy-for-a-document) runs.

 :::
 Determining the viewport intersection of the element can be done
 with an internal version of an IntersectionObserver. However, since
 the observations from this are dispatched at step 14 of [update the
 rendering](https://html.spec.whatwg.org/multipage/webappapis.html#update-the-rendering), any changes to the
 [skipped](#skips-its-contents) (and thus painted) state will not be visible to the
 user until the next frame's processing. For this reason, updating
 the [skipped] state, including
 containment adjustments, is deferred to that frame as well. This
 ensures that script accessing, for example, the containment value of
 the element between these two events (internal intersection
 observation and [skipped] state
 update) will retrieve values consistent with current painted state
 and not cause any forced layouts.
 :::

4. Elements with [content-visibility:
 auto](#propdef-content-visibility) that have not determined [proximity to
 the
 viewport](#proximity-to-the-viewport) must determine their proximity to the viewport in
 the next [update the
 rendering](https://html.spec.whatwg.org/multipage/webappapis.html#update-the-rendering) cycle. The effect of this determination must be
 reflected in the visual update which results from this [update the
 rendering] cycle. See [the event
 loop process
 model](https://html.spec.whatwg.org/multipage/webappapis.html#event-loop-processing-model:content-visibility-auto)
 for the concrete algorithm description.

 :::
 When an element first gains [content-visibility:
 auto](#propdef-content-visibility), it may or may not be positioned on
 screen. The determination of this state and thus determination of
 whether this element is
 [skipped](#skips-its-contents) must happen in the same frame. If it does not, then
 there is a possibility of producing blank content in the element's
 place since visibility check and
 [skipped] state update would be
 deferred to the next frame.
 :::

5. For the purposes of scrolling operations, such as
 [`scrollIntoView()`](https://drafts.csswg.org/cssom-view-1/#dom-element-scrollintoview), an element with [content-visibility:
 auto](#propdef-content-visibility) that is [skipping its
 contents](#skips-its-contents) has its size and location determined *with* [size
 containment](#size-containment) still active.

 Tests

 - [content-visibility-058.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-058.html "css/css-contain/content-visibility/content-visibility-058.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-058.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-058.html)

 Once it's scrolled into view, the element will no
 longer [skip its
 contents](#skips-its-contents), and so might not have [size
 containment](#size-containment); if this changes the element's size, it might not
 align in the viewport exactly as requested.

 If an element is not available to user-agent features (for example,
 if it is
 [skipped](#skips-its-contents) due to a [content-visibility:
 hidden](#propdef-content-visibility) ancestor), then scrolling operations must
 not scroll to it at all, as if it did not have a layout box.

 Tests

 - [content-visibility-043.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-043.html "css/css-contain/content-visibility/content-visibility-043.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-043.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-043.html)
 - [content-visibility-056.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-056.html "css/css-contain/content-visibility/content-visibility-056.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-056.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-056.html)

6. If an element with [content-visibility:
 auto](#propdef-content-visibility) that is [skipping its
 contents](#skips-its-contents) is focused (or its contents are), it becomes
 [relevant to the
 user](#relevant-to-the-user) (and thus stops [skipping its
 contents]) *before* it is scrolled
 into view due to the focusing.

 Tests

 - [content-visibility-064.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-064.html "css/css-contain/content-visibility/content-visibility-064.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-064.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-064.html)

 Thus, unlike the previous point, the element *will*
 be correctly sized and aligned in the viewport. This is consistent
 with the order of the steps for the
 [`focus()`](https://html.spec.whatwg.org/multipage/interaction.html#dom-window-focus) method.

7. If an
 [`iframe`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-iframe-element) [skips its
 contents](#skips-its-contents) or is part of an element's [skipped
 contents], the user agent should
 entirely skip the [Update The
 Rendering](https://html.spec.whatwg.org/multipage/webappapis.html#update-the-rendering) step in the iframe's event loop, if possible.

 Tests

 - [content-visibility-004.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-004.html "css/css-contain/content-visibility/content-visibility-004.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-004.html)
 - [content-visibility-020.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-020.html "css/css-contain/content-visibility/content-visibility-020.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-020.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-020.html)

 At the moment the
 [`iframe`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-iframe-element) starts being
 [skipped](#skips-its-contents), it needs to run that step at least once to remove
 the painted output.

8. [Skipped
 contents](#skips-its-contents) do not contribute to the result of
 [`innerText`](https://html.spec.whatwg.org/multipage/dom.html#dom-innertext).

 Tests

 - [content-visibility-029.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-029.html "css/css-contain/content-visibility/content-visibility-029.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-029.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-029.html)

9. While an element is
 [skipped](#skips-its-contents), CSS transitions and animations on the element do
 not update:

 - New animations are not created even if newly-applied style would
 start one.

 - Existing animations do not advance in their timeline.

 - Running animations on the element do not end.

 If script queries the style of a
 [skipped](#skips-its-contents) element (causing a [style change
 event](https://drafts.csswg.org/css-transitions-1/#style-change-event)) such that knowing the state of animations or
 transitions is required to return correct information, animation and
 transitions are sampled according to the styles at the time of that
 [style change event]:

 Tests

 - [animation-display-lock.html](https://wpt.fyi/results/css/css-contain/content-visibility/animation-display-lock.html "css/css-contain/content-visibility/animation-display-lock.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/animation-display-lock.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/animation-display-lock.html)

 [CSS Animations 2 § 5 Animation
 Events](https://drafts.csswg.org/css-animations-2/#events) and [CSS
 Transitions 2 § 5 Transition
 Events](https://drafts.csswg.org/css-transitions-2/#transition-events)
 defines what objects are created and what events are fired, with
 what data, when an animation or transition is updated,.

 When an element stops being
 [skipped](#skips-its-contents), animations and transitions are sampled and then
 resume advancing on their timelines as normal from that point.

 Overall, this is similar to the behavior of
 transitions/animations when a background tab is brought back to the
 foreground, allowing user agents to skip as much unnecessary
 animation work as possible without overly disrupting the animations
 when they become relevant again.

10. While an element is
 [skipped](#skips-its-contents), it must not start any transitions, even if a
 [style change
 event](https://drafts.csswg.org/css-transitions-1/#style-change-event) affects its computed styles.

 When an element stops being
 [skipped](#skips-its-contents), it must not start any transitions as a result of
 the [style change
 event](https://drafts.csswg.org/css-transitions-1/#style-change-event) associated with it no longer being
 [skipped].

 This is similar to an element switching from
 [display:none] to a
 non-[none](https://drafts.csswg.org/css-display-4/#valdef-display-none) value---​even though the styles are
 *technically* changing in that case (from their initial values to
 their \"proper\" values from the cascade), no transitions are
 started.

11. If an element has an ancestor with [content-visibility:
 hidden](#propdef-content-visibility), and it is placed in the [top
 layer](https://drafts.csswg.org/css-position-4/#document-top-layer), it does not generate any boxes, as if it were
 [display:
 none](https://drafts.csswg.org/css-display-3/#propdef-display).

 Tests

 - [content-visibility-with-top-layer-000.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-with-top-layer-000.html "css/css-contain/content-visibility/content-visibility-with-top-layer-000.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-with-top-layer-000.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-with-top-layer-000.html)
 - [content-visibility-with-top-layer-001.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-with-top-layer-001.html "css/css-contain/content-visibility/content-visibility-with-top-layer-001.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-with-top-layer-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-with-top-layer-001.html)
 - [content-visibility-with-top-layer-002.html](https://wpt.fyi/results/css/css-contain/content-visibility/content-visibility-with-top-layer-002.html "css/css-contain/content-visibility/content-visibility-with-top-layer-002.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/content-visibility/content-visibility-with-top-layer-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/content-visibility/content-visibility-with-top-layer-002.html)

 An element
 [skipped](#skips-its-contents) for other reasons, such as having a
 [content-visibility:
 auto](#propdef-content-visibility) ancestor, will still generate boxes as
 normal, and might thus become
 un-[skipped].

12. A [media
 element](https://html.spec.whatwg.org/multipage/media.html#media-element) that has [content-visibility:
 hidden](#propdef-content-visibility) or is in the [skipped
 contents](#skips-its-contents) of an element with [content-visibility:
 hidden] is not paused on
 account of being skipped. If it is playing, its playback position
 advances as if it were not skipped. Its audio output must be
 suppressed while skipped, without changing its
 [`muted`](https://html.spec.whatwg.org/multipage/media.html#dom-media-muted) or
 [`volume`](https://html.spec.whatwg.org/multipage/media.html#dom-media-volume) attributes.

 Events queued by the media element while skipped are not dispatched
 until it stops being skipped. Queries of the media element's state,
 such as
 [`currentTime`](https://html.spec.whatwg.org/multipage/media.html#dom-media-currenttime) or
 [`paused`](https://html.spec.whatwg.org/multipage/media.html#dom-media-paused), reflect the current playback state.

 If an
 [`iframe`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-iframe-element) has [content-visibility:
 hidden](#propdef-content-visibility) or is in the [skipped
 contents](#skips-its-contents) of an element with [content-visibility:
 hidden], this also
 applies to media elements in its document.

 Audio output need not be suppressed if the media is presented
 outside the skipped contents, for example in a picture-in-picture
 window.

 This does not apply to contents
 [skipped](#skips-its-contents) due to [content-visibility:
 auto](#propdef-content-visibility), which are off-screen but may remain
 [relevant to the
 user](#relevant-to-the-user), such as a playing audio element scrolled out of
 view.

### 4.6. Accessibility Implications

If a user agent exposes some form of \"accessibility tree\", akin to the
DOM tree but specialized for accessibility use-cases such as
screen-readers (thus providing the positions/etc of elements relevant to
accessibility APIs, such as focusable elements), then the [skipped
contents](#skips-its-contents) of [content-visibility:
hidden](#propdef-content-visibility) elements must similarly be \"skipped\"
(omitted) in the accessibility tree (similar to how [display:
none](https://drafts.csswg.org/css-display-3/#propdef-display) elements are omitted in all views of the
document).

[Skipped contents](#skips-its-contents) of [content-visibility:
auto](#propdef-content-visibility) elements must not expose the fact that a user
is interacting with the page via the accessibility tree, rather than via
rendering visually to the screen. In particular, if a user agent uses
[content-visibility: auto]
to avoid doing layout and painting work on off-screen content for
displaying to the screen, it must similarly avoid doing that work on
off-screen content for representing in the accessibility tree. If this
is not possible (for example, if the user agent's representation of a
focusable element in the accessibility tree requires knowledge of its
exact position, and thus requires a full layout to be done on it and
surrounding contents), then the user agent *must* omit the [skipped
contents] from the accessibility tree
entirely.

 This requirement is intended to protect users utilizing
accessibility tooling from being identified and profiled as such via
observation of timing channels; if a user agent can skip significant
amounts of work when rendering visually, but has to do all of the work
when rendering to an accessibility tree, then an author can tell how a
user is interacting with the page by observing the timing of layout
operations.

### 4.7. Examples

``` highlight
<style>
.sv {
 content-visibility: auto;
 min-height: 50px;
}
</style>

<div class=sv>
 ... some content goes here ...
</div>
```

The .sv element's [content-visibility:
auto](#propdef-content-visibility) value lets the user-agent manage whether the
element is [skipped](#skips-its-contents). Specifically when this element is near the viewport,
the user-agent will begin painting the element. When the element moves
away from the viewport, it will stop being painted. In addition, the
user-agent should skip as much of the rendering work as possible when
the element is [skipped].

``` highlight
<style>
.sv {
 content-visibility: hidden;
}
</style>

<div class=sv>
 ... some content goes here ...
</div>
```

In this case, the element is
[skipped](#skips-its-contents) regardless of viewport intersection. This means that
the only way to have the
[contents](https://www.w3.org/TR/CSS2/conform.html#content) painted is via script updating the value to remove
[content-visibility](#propdef-content-visibility) or change its value. As before, the
user-agent should skip as much of the rendering in the
[contents] as possible.

An additional effect of skipping rendering is that the layout state of
the
[contents](https://www.w3.org/TR/CSS2/conform.html#content) can be preserved by the user-agent, so that removing
the
[content-visibility](#propdef-content-visibility) property in the future will cause
the [contents] to be rendered quicker than if they
were hidden with [display:
none](https://drafts.csswg.org/css-display-3/#propdef-display) or similar.

``` highlight
<style>
body {
 margin: 0;
}
.sv {
 content-visibility: hidden;
 position: relative;
 left: 10px;
 top: 20px;
}
#child {
 position: relative;
 left: 1px;
 top: 2px;
 width: 100px;
 height: 200px;
}
</style>

<div id=target class=sv>
 <div id=child></div>
 ... some other content goes here ...
</div>
<script>
 ...
 // This will force rendering work, including layout,
 // if the UA previously avoided it.
 target.firstElementChild.getBoundingClientRect();
 ...
</script>
```

Similarly to the last example, the element is
[skipped](#skips-its-contents). The user-agent should avoid as much rendering work as
possible. However, in this example, at some point script accesses a
layout value in the element's
[contents](https://www.w3.org/TR/CSS2/conform.html#content). In this situation, the user-agent cannot avoid
rendering work and has to process any previously skipped rendering work
in order to return a correct value to the caller. In this example, the
result of
[`getBoundingClientRect()`](https://drafts.csswg.org/cssom-view-1/#dom-element-getboundingclientrect) is a rect positioned at (11, 22) with a size 100x200.

Note that repeated calls to the same layout value should not cause any
additional rendering work, since the user-agent should retain the last
updated rendering state.

Also note that this situation in which rendering work is required is not
unique. There may be other situations in which the user-agent cannot
avoid rendering work.

## 5. Privacy Considerations

There are no known privacy impacts of the features in this
specification.

## 6. Security Considerations

There are no known security impacts of the features in this
specification.

Like any other CSS specification, it affects the rendering of the
document, but does not introduce any special ability to present content
in a misleading way that was not previously available through other CSS
modules and that isn't inherent to the act of formatting the document.

## [Appendix A. Changes]
This appendix is *informative*.

### [ Changes from [2022-09-17 Working Draft](https://www.w3.org/TR/2022/WD-css-contain-2-20220917/) ]
- Updated relevant to the user selection to point to the selection API
 instead of highlight pseudos.

- Referenced the HTML event loop process model in the [§ 4.5
 Restrictions and Clarifications](#cv-notes), clarification 4.

- defined [proximity to the
 viewport](#proximity-to-the-viewport) and used it in the [§ 4.5 Restrictions and
 Clarifications](#cv-notes), clarification 4.

- [content-visibility](#propdef-content-visibility) applies to the same properties as
 [size containment](#size-containment) rather than [layout
 containment](#layout-containment)

- clarified that
 [content-visibility](#propdef-content-visibility) affects the used value, not
 computed value, of the
 [contain](#propdef-contain) property

- Updated the ContentVisibilityAutoStateChanged event name to
 ContentVisibilityAutoStateChange to follow the convention for event
 names.

- Move the definition of inline-size containement from the Level 3
 specification to this Level 2. ([Issue
 10433](https://github.com/w3c/csswg-drafts/issues/10433))

- Make the
 [content-visibility](#propdef-content-visibility) property animatable. ([Issue
 8627](https://github.com/w3c/csswg-drafts/issues/8627))

- Removed
 [text-overflow](https://drafts.csswg.org/css-ui-3/#propdef-text-overflow) from the non-normative list of
 properties that are claimed to be able to reserve \"canvas\" space in
 section [§ 3.5.1 Possible Paint-Containment
 Optimizations](#containment-paint-opt).

- Defined how media playback behaves while its contents are skipped.
 ([Issue 6468](https://github.com/w3c/csswg-drafts/issues/6468))

### [ Changes from [2020-12-16 Working Draft](https://www.w3.org/TR/2020/WD-css-contain-2-20201216/) ]
- Included [style
 containment](#style-containment) in the
 [strict](#valdef-contain-strict) and
 [content](#valdef-contain-content) keywords.

- Use the [overflow clip
 edge](https://drafts.csswg.org/css-overflow-4/#overflow-clip-edge) rather than the [border
 edge](https://drafts.csswg.org/css-box-4/#border-edge) when deciding if the element is "on screen", as part
 of determining if it is [relevant to the
 user](#relevant-to-the-user)

- Define how animations and transitions act on skipped elements

- Remove \"at risk\" marker from style containment

- Disable propagation from the HTML body element when containment is on

- Made style containment part of
 [strict](#valdef-contain-strict) and
 [content](#valdef-contain-content)

- Clarify that scrollIntoView() doesn't scroll to children of a
 [content-visibility:hidden] element

- Defined that elements having an ancestor with [content-visibility:
 hidden](#propdef-content-visibility) don't generate boxes in the top layer

- Defined that being in the top-layer makes an element relevant to the
 user

- Noted that paint effects with non-local effects can limit certain
 optimization opportunities.

- Add ContentVisibilityAutoStateChanged event

### [ Changes from [2020-06-03 Working Draft](https://www.w3.org/TR/2020/WD-css-contain-2-20200603/) ]
- Changed how the computed values of the contain property are determined

- Fixed a syntax error in the note about [contain:
 content](#propdef-contain)

- Change terminology: replace \"containing box\" with \"containment
 box\" (in sync with the same improvements made to Level 1)

- Editorial improvements and clarifications to size and paint
 containment (in sync with the same improvements made to Level 1)

- Be explicit that size containment suppresses natural aspect ratio (in
 sync with the same improvements made to Level 1)

- Change the animation type of content-visibility from discrete to not
 animatable

- Add constraint on the timing of the initial determination of
 visibility for [content-visibility:
 auto](#propdef-content-visibility) in [§ 4.5 Restrictions and
 Clarifications](#cv-notes)

### [ Changes from [2019-11-11 Working Draft](https://www.w3.org/TR/2019/WD-css-contain-2-20191111/) ]
- Define the interaction between [paint
 containment](#paint-containment) and
 [overflow-clip-margin](https://drafts.csswg.org/css-overflow-4/#propdef-overflow-clip-margin)

- Add the
 [content-visibility](#propdef-content-visibility) property

### [ Changes from [CSS Containment Level 1](https://www.w3.org/TR/css-contain-1/) ]
- Restored [style
 containment](#style-containment), which had been dropped from Level 1

Tests

- [container-type-important.html](https://wpt.fyi/results/css/css-contain/container-type-important.html "css/css-contain/container-type-important.html")
 [[(live
 test)]](http://wpt.live/css/css-contain/container-type-important.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-contain/container-type-important.html)
