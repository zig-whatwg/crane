## 1. Introduction

*This section is not normative.*

Tests

This section is not normative, it does not need tests.

------------------------------------------------------------------------

A [selector](#selector) is a boolean
predicate that takes an element in a tree structure and tests whether
the element matches the selector or not.

These expressions may be used for many things:

- directly on an element to test whether it matches some criteria, such
 as in the `element.matches()` function defined in
 [\[DOM\]](#biblio-dom "DOM Standard")
- applied to an entire tree of elements to filter it into a set of
 elements that match the criteria, such as in the
 `document.querySelectorAll()` function defined in
 [\[DOM\]](#biblio-dom "DOM Standard") or the
 selector of a CSS style rule.
- used \"in reverse\" to generate markup that would match a given
 selector, [ such as in [HAML](http://haml.info/) or
 [Emmet](https://en.wikipedia.org/wiki/Emmet_(software))
 ].

Selectors Levels 1, 2, and 3 are defined as the subsets of selector
functionality defined in the [CSS1](https://www.w3.org/TR/REC-CSS1),
[CSS2.1](https://www.w3.org/TR/CSS21/), and [Selectors Level
3](https://www.w3.org/TR/css3-selectors/) specifications, respectively.
This module defines Selectors Level 4.

### 1.1. Module Interactions

Tests

Tests not needed for this section.

------------------------------------------------------------------------

This module replaces the definitions of and extends the set of selectors
defined for CSS in
[\[SELECT\]](#biblio-select "Selectors Level 3") and
[\[CSS21\]](#biblio-css21 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification").

Pseudo-element selectors, which define abstract elements in a rendering
tree, are not part of this specification: their generic syntax is
described here, but, due to their close integration with the rendering
model and irrelevance to other uses such as DOM queries, they will be
defined in other modules.

## 2. Selectors Overview

*This section is non-normative, as it merely summarizes the following
sections.*

Tests

This section is not normative, it does not need tests.

------------------------------------------------------------------------

A selector represents a structure. This structure can be used as a
condition (e.g. in a CSS rule) that determines which elements a selector
matches in the document tree, or as a flat description of the HTML or
XML fragment corresponding to that structure.

Selectors may range from simple element names to rich contextual
representations.

The following table summarizes the Selector syntax:

Pattern

Represents

Section

Level

`*`

any element

[§ 5.2 Universal selector](#the-universal-selector)

2

`E`

an element of type E

[§ 5.1 Type (tag name) selector](#type-selectors)

1

`E:not(``s1``, ``s2``, …)`

an E element that does not match either [compound
selector](#compound) `s1`
or [compound selector] `s2`

[§ 4.3 The Negation (Matches-None) Pseudo-class: :not()](#negation)

3/4

`E:is(``s1``, ``s2``, …)`

an E element that matches [compound
selector](#compound) `s1`
and/or [compound selector] `s2`

[§ 4.2 The Matches-Any Pseudo-class: :is()](#matches)

4

`E:where(``s1``, ``s2``, …)`

an E element that matches [compound
selector](#compound) `s1`
and/or [compound selector] `s2` but
contributes no specificity.

[§ 4.4 The Specificity-adjustment Pseudo-class: :where()](#zero-matches)

4

`E:has(``rs1``, ``rs2``, …)`

an E element, if there exists an element that matches either of the
[relative selectors](#relative-selector) `rs1` or `rs2`, when evaluated
with E as the [anchor
elements](#relative-selector-anchor-elements)

[§ 4.5 The Relational Pseudo-class: :has()](#relational)

4

`E.warning`

an E element belonging to the class `warning` (the document language
specifies how class is determined).

[§ 6.6 Class selectors](#class-html)

1

`E#myid`

an E element with ID equal to `myid`.

[§ 6.7 ID selectors](#id-selectors)

1

`E[foo]`

an E element with a `foo` attribute

[§ 6.1 Attribute presence and value
selectors](#attribute-representation)

2

`E[foo="bar"]`

an E element whose `foo` attribute value is exactly equal to `bar`

[§ 6.1 Attribute presence and value
selectors](#attribute-representation)

2

`E[foo="bar" i]`

an E element whose `foo` attribute value is exactly equal to any
(ASCII-range) case-permutation of `bar`

[§ 6.3 Case-sensitivity](#attribute-case)

4

`E[foo="bar" s]`

an E element whose `foo` attribute value is [identical
to](https://infra.spec.whatwg.org/#is)
`bar`

[§ 6.3 Case-sensitivity](#attribute-case)

4

`E[foo~="bar"]`

an E element whose `foo` attribute value is a list of
whitespace-separated values, one of which is exactly equal to `bar`

[§ 6.1 Attribute presence and value
selectors](#attribute-representation)

2

`E[foo^="bar"]`

an E element whose `foo` attribute value begins exactly with the string
`bar`

[§ 6.2 Substring matching attribute selectors](#attribute-substrings)

3

`E[foo$="bar"]`

an E element whose `foo` attribute value ends exactly with the string
`bar`

[§ 6.2 Substring matching attribute selectors](#attribute-substrings)

3

`E[foo*="bar"]`

an E element whose `foo` attribute value contains the substring `bar`

[§ 6.2 Substring matching attribute selectors](#attribute-substrings)

3

`E[foo|="en"]`

an E element whose `foo` attribute value is a hyphen-separated list of
values beginning with `en`

[§ 6.1 Attribute presence and value
selectors](#attribute-representation)

2

`E:dir(ltr)`

an element of type E with left-to-right directionality (the document
language specifies how directionality is determined)

[§ 7.1 The Directionality Pseudo-class: :dir()](#the-dir-pseudo)

4

`E:lang(sr, "*-Cyrl")`

an element of type E tagged as being in Serbian, (which typically uses
Cyrillic, but can be written with Latin characters) but also anything
written with Cyrillic characters

[§ 7.2 The Language Pseudo-class: :lang()](#the-lang-pseudo)

2/4

`E:any-link`

an E element being the source anchor of a hyperlink

[§ 8.1 The Hyperlink Pseudo-class: :any-link](#the-any-link-pseudo)

4

`E:link`

an E element being the source anchor of a hyperlink of which the target
is not yet visited

[§ 8.2 The Link History Pseudo-classes: :link and :visited](#link)

1

`E:visited`

an E element being the source anchor of a hyperlink of which the target
is already visited

[§ 8.2 The Link History Pseudo-classes: :link and :visited](#link)

1

`E:target`

an E element being the target of the current URL

[§ 8.3 The Target Pseudo-class: :target](#the-target-pseudo)

3

`E:scope`

an E element being a [scoping root](#scoping-root)

[§ 8.4 The Reference Element Pseudo-class: :scope](#the-scope-pseudo)

4

`E:active`

an E element that is in an activated state

[§ 9.2 The Activation Pseudo-class: :active](#the-active-pseudo)

1

`E:hover`

an E element that is under the cursor, or that has a descendant under
the cursor

[§ 9.1 The Pointer Hover Pseudo-class: :hover](#the-hover-pseudo)

2

`E:focus`

an E element that has user input focus

[§ 9.3 The Input Focus Pseudo-class: :focus](#the-focus-pseudo)

2

`E:focus-within`

an E element that has user input focus or contains an element that has
input focus.

[§ 9.5 The Focus Container Pseudo-class:
:focus-within](#the-focus-within-pseudo)

4

`E:focus-visible`

an E element that has user input focus, and the UA has determined that a
focus ring or other indicator should be drawn for that element

[§ 9.4 The Focus-Indicated Pseudo-class:
:focus-visible](#the-focus-visible-pseudo)

4

`E:enabled`\
`E:disabled`

a user interface element E that is enabled or disabled, respectively

[§ 12.1.1 The :enabled and :disabled Pseudo-classes](#enableddisabled)

3

`E:read-write`\
`E:read-only`

a user interface element E that is user alterable, or not

[§ 12.1.2 The Mutability Pseudo-classes: :read-only and
:read-write](#rw-pseudos)

3-UI/4

`E:placeholder-shown`

an input control currently showing placeholder text

[§ 12.1.3 The Placeholder-shown Pseudo-class:
:placeholder-shown](#placeholder)

3-UI/4

`E:default`

a user interface element E that is the default item in a group of
related choices

[§ 12.1.5 The Default-option Pseudo-class:
:default](#the-default-pseudo)

3-UI/4

`E:checked`\
`E:unchecked`\
`E:indeterminate`

a user interface element E that is checked/selected (for instance a
radio-button or checkbox), unchecked, or in an indeterminate state
(neither checked nor unchecked)

[§ 12.2 Input Value States](#input-value-states)

3

`E:valid`\
`E:invalid`

a user-input element E that meets, or doesn't, its data validity
semantics

[§ 12.3.1 The Validity Pseudo-classes: :valid and
:invalid](#validity-pseudos)

3-UI/4

`E:in-range`\
`E:out-of-range`

a user-input element E whose value is in-range/out-of-range

[§ 12.3.2 The Range Pseudo-classes: :in-range and
:out-of-range](#range-pseudos)

3-UI/4

`E:required`\
`E:optional`

a user-input element E that requires/does not require input

[§ 12.3.3 The Optionality Pseudo-classes: :required and
:optional](#opt-pseudos)

3-UI/4

`E:user-invalid`

a user-altered user-input element E with incorrect input (invalid,
out-of-range, omitted-but-required)

[§ 12.3.4 The User-interaction Pseudo-classes: :user-valid and
:user-invalid](#user-pseudos)

4

`E:root`

an E element, root of the document

[§ 13.1 :root pseudo-class](#the-root-pseudo)

3

`E:empty`

an E element that has no children (neither elements nor text) except
perhaps white space

[§ 13.2 :empty pseudo-class](#the-empty-pseudo)

3

`E:nth-child(``n`` [of ``S``]?)`

an E element, the `n`-th child of its parent matching
`S`

[§ 13.3.1 :nth-child() pseudo-class](#the-nth-child-pseudo)

3/4

`E:nth-last-child(``n`` [of ``S``]?)`

an E element, the `n`-th child of its parent matching
`S`, counting from the last one

[§ 13.3.2 :nth-last-child() pseudo-class](#the-nth-last-child-pseudo)

3/4

`E:first-child`

an E element, first child of its parent

[§ 13.3.3 :first-child pseudo-class](#the-first-child-pseudo)

2

`E:last-child`

an E element, last child of its parent

[§ 13.3.4 :last-child pseudo-class](#the-last-child-pseudo)

3

`E:only-child`

an E element, only child of its parent

[§ 13.3.5 :only-child pseudo-class](#the-only-child-pseudo)

3

`E:nth-of-type(``n``)`

an E element, the `n`-th sibling of its type

[§ 13.4.1 :nth-of-type() pseudo-class](#the-nth-of-type-pseudo)

3

`E:nth-last-of-type(``n``)`

an E element, the `n`-th sibling of its type, counting from
the last one

[§ 13.4.2 :nth-last-of-type()
pseudo-class](#the-nth-last-of-type-pseudo)

3

`E:first-of-type`

an E element, first sibling of its type

[§ 13.4.3 :first-of-type pseudo-class](#the-first-of-type-pseudo)

3

`E:last-of-type`

an E element, last sibling of its type

[§ 13.4.4 :last-of-type pseudo-class](#the-last-of-type-pseudo)

3

`E:only-of-type`

an E element, only sibling of its type

[§ 13.4.5 :only-of-type pseudo-class](#the-only-of-type-pseudo)

3

`E F`

an F element descendant of an E element

[§ 14.1 Descendant combinator ( )](#descendant-combinators)

1

`E > F`

an F element child of an E element

[§ 14.2 Child combinator (\>)](#child-combinators)

2

`E + F`

an F element immediately preceded by an E element

[§ 14.3 Next-sibling combinator (+)](#adjacent-sibling-combinators)

2

`E ~ F`

an F element preceded by an E element

[§ 14.4 Subsequent-sibling combinator
(\~)](#general-sibling-combinators)

3

 Some Level 4 selectors (noted above as \"3-UI\") were
introduced in
[\[CSS3UI\]](#biblio-css3ui "CSS Basic User Interface Module Level 3 (CSS3 UI)").

Tests

- [css3-modsel-1.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-1.xml "css/selectors/old-tests/css3-modsel-1.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-1.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-1.xml)
- [css3-modsel-10.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-10.xml "css/selectors/old-tests/css3-modsel-10.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-10.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-10.xml)
- [css3-modsel-100.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-100.xml "css/selectors/old-tests/css3-modsel-100.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-100.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-100.xml)
- [css3-modsel-100b.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-100b.xml "css/selectors/old-tests/css3-modsel-100b.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-100b.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-100b.xml)
- [css3-modsel-101.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-101.xml "css/selectors/old-tests/css3-modsel-101.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-101.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-101.xml)
- [css3-modsel-101b.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-101b.xml "css/selectors/old-tests/css3-modsel-101b.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-101b.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-101b.xml)
- [css3-modsel-102.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-102.xml "css/selectors/old-tests/css3-modsel-102.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-102.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-102.xml)
- [css3-modsel-102b.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-102b.xml "css/selectors/old-tests/css3-modsel-102b.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-102b.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-102b.xml)
- [css3-modsel-103.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-103.xml "css/selectors/old-tests/css3-modsel-103.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-103.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-103.xml)
- [css3-modsel-103b.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-103b.xml "css/selectors/old-tests/css3-modsel-103b.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-103b.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-103b.xml)
- [css3-modsel-104.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-104.xml "css/selectors/old-tests/css3-modsel-104.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-104.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-104.xml)
- [css3-modsel-104b.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-104b.xml "css/selectors/old-tests/css3-modsel-104b.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-104b.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-104b.xml)
- [css3-modsel-105.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-105.xml "css/selectors/old-tests/css3-modsel-105.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-105.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-105.xml)
- [css3-modsel-105b.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-105b.xml "css/selectors/old-tests/css3-modsel-105b.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-105b.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-105b.xml)
- [css3-modsel-106.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-106.xml "css/selectors/old-tests/css3-modsel-106.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-106.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-106.xml)
- [css3-modsel-106b.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-106b.xml "css/selectors/old-tests/css3-modsel-106b.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-106b.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-106b.xml)
- [css3-modsel-107.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-107.xml "css/selectors/old-tests/css3-modsel-107.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-107.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-107.xml)
- [css3-modsel-107b.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-107b.xml "css/selectors/old-tests/css3-modsel-107b.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-107b.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-107b.xml)
- [css3-modsel-108.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-108.xml "css/selectors/old-tests/css3-modsel-108.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-108.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-108.xml)
- [css3-modsel-108b.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-108b.xml "css/selectors/old-tests/css3-modsel-108b.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-108b.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-108b.xml)
- [css3-modsel-109.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-109.xml "css/selectors/old-tests/css3-modsel-109.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-109.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-109.xml)
- [css3-modsel-109b.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-109b.xml "css/selectors/old-tests/css3-modsel-109b.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-109b.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-109b.xml)
- [css3-modsel-11.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-11.xml "css/selectors/old-tests/css3-modsel-11.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-11.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-11.xml)
- [css3-modsel-110.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-110.xml "css/selectors/old-tests/css3-modsel-110.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-110.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-110.xml)
- [css3-modsel-110b.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-110b.xml "css/selectors/old-tests/css3-modsel-110b.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-110b.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-110b.xml)
- [css3-modsel-111.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-111.xml "css/selectors/old-tests/css3-modsel-111.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-111.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-111.xml)
- [css3-modsel-111b.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-111b.xml "css/selectors/old-tests/css3-modsel-111b.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-111b.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-111b.xml)
- [css3-modsel-112.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-112.xml "css/selectors/old-tests/css3-modsel-112.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-112.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-112.xml)
- [css3-modsel-112b.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-112b.xml "css/selectors/old-tests/css3-modsel-112b.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-112b.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-112b.xml)
- [css3-modsel-113.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-113.xml "css/selectors/old-tests/css3-modsel-113.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-113.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-113.xml)
- [css3-modsel-113b.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-113b.xml "css/selectors/old-tests/css3-modsel-113b.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-113b.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-113b.xml)
- [css3-modsel-114.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-114.xml "css/selectors/old-tests/css3-modsel-114.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-114.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-114.xml)
- [css3-modsel-114b.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-114b.xml "css/selectors/old-tests/css3-modsel-114b.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-114b.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-114b.xml)
- [css3-modsel-115.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-115.xml "css/selectors/old-tests/css3-modsel-115.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-115.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-115.xml)
- [css3-modsel-115b.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-115b.xml "css/selectors/old-tests/css3-modsel-115b.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-115b.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-115b.xml)
- [css3-modsel-116.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-116.xml "css/selectors/old-tests/css3-modsel-116.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-116.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-116.xml)
- [css3-modsel-116b.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-116b.xml "css/selectors/old-tests/css3-modsel-116b.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-116b.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-116b.xml)
- [css3-modsel-117.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-117.xml "css/selectors/old-tests/css3-modsel-117.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-117.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-117.xml)
- [css3-modsel-117b.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-117b.xml "css/selectors/old-tests/css3-modsel-117b.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-117b.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-117b.xml)
- [css3-modsel-118.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-118.xml "css/selectors/old-tests/css3-modsel-118.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-118.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-118.xml)
- [css3-modsel-119.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-119.xml "css/selectors/old-tests/css3-modsel-119.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-119.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-119.xml)
- [css3-modsel-120.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-120.xml "css/selectors/old-tests/css3-modsel-120.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-120.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-120.xml)
- [css3-modsel-121.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-121.xml "css/selectors/old-tests/css3-modsel-121.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-121.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-121.xml)
- [css3-modsel-122.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-122.xml "css/selectors/old-tests/css3-modsel-122.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-122.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-122.xml)
- [css3-modsel-123.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-123.xml "css/selectors/old-tests/css3-modsel-123.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-123.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-123.xml)
- [css3-modsel-123b.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-123b.xml "css/selectors/old-tests/css3-modsel-123b.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-123b.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-123b.xml)
- [css3-modsel-124.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-124.xml "css/selectors/old-tests/css3-modsel-124.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-124.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-124.xml)
- [css3-modsel-124b.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-124b.xml "css/selectors/old-tests/css3-modsel-124b.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-124b.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-124b.xml)
- [css3-modsel-125.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-125.xml "css/selectors/old-tests/css3-modsel-125.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-125.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-125.xml)
- [css3-modsel-125b.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-125b.xml "css/selectors/old-tests/css3-modsel-125b.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-125b.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-125b.xml)
- [css3-modsel-126.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-126.xml "css/selectors/old-tests/css3-modsel-126.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-126.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-126.xml)
- [css3-modsel-126b.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-126b.xml "css/selectors/old-tests/css3-modsel-126b.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-126b.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-126b.xml)
- [css3-modsel-127.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-127.xml "css/selectors/old-tests/css3-modsel-127.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-127.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-127.xml)
- [css3-modsel-127b.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-127b.xml "css/selectors/old-tests/css3-modsel-127b.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-127b.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-127b.xml)
- [css3-modsel-128.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-128.xml "css/selectors/old-tests/css3-modsel-128.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-128.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-128.xml)
- [css3-modsel-128b.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-128b.xml "css/selectors/old-tests/css3-modsel-128b.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-128b.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-128b.xml)
- [css3-modsel-129.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-129.xml "css/selectors/old-tests/css3-modsel-129.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-129.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-129.xml)
- [css3-modsel-129b.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-129b.xml "css/selectors/old-tests/css3-modsel-129b.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-129b.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-129b.xml)
- [css3-modsel-13.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-13.xml "css/selectors/old-tests/css3-modsel-13.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-13.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-13.xml)
- [css3-modsel-130.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-130.xml "css/selectors/old-tests/css3-modsel-130.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-130.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-130.xml)
- [css3-modsel-130b.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-130b.xml "css/selectors/old-tests/css3-modsel-130b.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-130b.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-130b.xml)
- [css3-modsel-131.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-131.xml "css/selectors/old-tests/css3-modsel-131.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-131.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-131.xml)
- [css3-modsel-131b.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-131b.xml "css/selectors/old-tests/css3-modsel-131b.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-131b.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-131b.xml)
- [css3-modsel-132.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-132.xml "css/selectors/old-tests/css3-modsel-132.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-132.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-132.xml)
- [css3-modsel-132b.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-132b.xml "css/selectors/old-tests/css3-modsel-132b.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-132b.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-132b.xml)
- [css3-modsel-133.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-133.xml "css/selectors/old-tests/css3-modsel-133.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-133.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-133.xml)
- [css3-modsel-133b.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-133b.xml "css/selectors/old-tests/css3-modsel-133b.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-133b.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-133b.xml)
- [css3-modsel-134.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-134.xml "css/selectors/old-tests/css3-modsel-134.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-134.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-134.xml)
- [css3-modsel-134b.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-134b.xml "css/selectors/old-tests/css3-modsel-134b.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-134b.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-134b.xml)
- [css3-modsel-135.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-135.xml "css/selectors/old-tests/css3-modsel-135.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-135.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-135.xml)
- [css3-modsel-135b.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-135b.xml "css/selectors/old-tests/css3-modsel-135b.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-135b.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-135b.xml)
- [css3-modsel-136.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-136.xml "css/selectors/old-tests/css3-modsel-136.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-136.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-136.xml)
- [css3-modsel-136b.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-136b.xml "css/selectors/old-tests/css3-modsel-136b.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-136b.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-136b.xml)
- [css3-modsel-137.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-137.xml "css/selectors/old-tests/css3-modsel-137.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-137.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-137.xml)
- [css3-modsel-137b.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-137b.xml "css/selectors/old-tests/css3-modsel-137b.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-137b.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-137b.xml)
- [css3-modsel-138.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-138.xml "css/selectors/old-tests/css3-modsel-138.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-138.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-138.xml)
- [css3-modsel-138b.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-138b.xml "css/selectors/old-tests/css3-modsel-138b.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-138b.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-138b.xml)
- [css3-modsel-139.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-139.xml "css/selectors/old-tests/css3-modsel-139.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-139.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-139.xml)
- [css3-modsel-139b.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-139b.xml "css/selectors/old-tests/css3-modsel-139b.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-139b.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-139b.xml)
- [css3-modsel-14.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-14.xml "css/selectors/old-tests/css3-modsel-14.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-14.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-14.xml)
- [css3-modsel-140.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-140.xml "css/selectors/old-tests/css3-modsel-140.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-140.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-140.xml)
- [css3-modsel-140b.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-140b.xml "css/selectors/old-tests/css3-modsel-140b.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-140b.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-140b.xml)
- [css3-modsel-141.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-141.xml "css/selectors/old-tests/css3-modsel-141.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-141.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-141.xml)
- [css3-modsel-141b.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-141b.xml "css/selectors/old-tests/css3-modsel-141b.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-141b.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-141b.xml)
- [css3-modsel-142.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-142.xml "css/selectors/old-tests/css3-modsel-142.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-142.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-142.xml)
- [css3-modsel-142b.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-142b.xml "css/selectors/old-tests/css3-modsel-142b.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-142b.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-142b.xml)
- [css3-modsel-143.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-143.xml "css/selectors/old-tests/css3-modsel-143.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-143.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-143.xml)
- [css3-modsel-143b.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-143b.xml "css/selectors/old-tests/css3-modsel-143b.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-143b.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-143b.xml)
- [css3-modsel-144.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-144.xml "css/selectors/old-tests/css3-modsel-144.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-144.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-144.xml)
- [css3-modsel-145a.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-145a.xml "css/selectors/old-tests/css3-modsel-145a.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-145a.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-145a.xml)
- [css3-modsel-145b.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-145b.xml "css/selectors/old-tests/css3-modsel-145b.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-145b.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-145b.xml)
- [css3-modsel-146a.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-146a.xml "css/selectors/old-tests/css3-modsel-146a.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-146a.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-146a.xml)
- [css3-modsel-146b.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-146b.xml "css/selectors/old-tests/css3-modsel-146b.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-146b.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-146b.xml)
- [css3-modsel-147a.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-147a.xml "css/selectors/old-tests/css3-modsel-147a.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-147a.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-147a.xml)
- [css3-modsel-147b.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-147b.xml "css/selectors/old-tests/css3-modsel-147b.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-147b.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-147b.xml)
- [css3-modsel-148.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-148.xml "css/selectors/old-tests/css3-modsel-148.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-148.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-148.xml)
- [css3-modsel-149.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-149.xml "css/selectors/old-tests/css3-modsel-149.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-149.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-149.xml)
- [css3-modsel-149b.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-149b.xml "css/selectors/old-tests/css3-modsel-149b.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-149b.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-149b.xml)
- [css3-modsel-14b.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-14b.xml "css/selectors/old-tests/css3-modsel-14b.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-14b.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-14b.xml)
- [css3-modsel-14c.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-14c.xml "css/selectors/old-tests/css3-modsel-14c.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-14c.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-14c.xml)
- [css3-modsel-14d.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-14d.xml "css/selectors/old-tests/css3-modsel-14d.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-14d.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-14d.xml)
- [css3-modsel-14e.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-14e.xml "css/selectors/old-tests/css3-modsel-14e.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-14e.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-14e.xml)
- [css3-modsel-15.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-15.xml "css/selectors/old-tests/css3-modsel-15.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-15.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-15.xml)
- [css3-modsel-150.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-150.xml "css/selectors/old-tests/css3-modsel-150.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-150.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-150.xml)
- [css3-modsel-151.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-151.xml "css/selectors/old-tests/css3-modsel-151.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-151.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-151.xml)
- [css3-modsel-152.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-152.xml "css/selectors/old-tests/css3-modsel-152.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-152.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-152.xml)
- [css3-modsel-153.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-153.xml "css/selectors/old-tests/css3-modsel-153.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-153.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-153.xml)
- [css3-modsel-154.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-154.xml "css/selectors/old-tests/css3-modsel-154.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-154.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-154.xml)
- [css3-modsel-155.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-155.xml "css/selectors/old-tests/css3-modsel-155.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-155.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-155.xml)
- [css3-modsel-155a.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-155a.xml "css/selectors/old-tests/css3-modsel-155a.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-155a.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-155a.xml)
- [css3-modsel-155b.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-155b.xml "css/selectors/old-tests/css3-modsel-155b.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-155b.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-155b.xml)
- [css3-modsel-155c.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-155c.xml "css/selectors/old-tests/css3-modsel-155c.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-155c.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-155c.xml)
- [css3-modsel-155d.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-155d.xml "css/selectors/old-tests/css3-modsel-155d.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-155d.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-155d.xml)
- [css3-modsel-156.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-156.xml "css/selectors/old-tests/css3-modsel-156.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-156.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-156.xml)
- [css3-modsel-156b.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-156b.xml "css/selectors/old-tests/css3-modsel-156b.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-156b.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-156b.xml)
- [css3-modsel-156c.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-156c.xml "css/selectors/old-tests/css3-modsel-156c.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-156c.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-156c.xml)
- [css3-modsel-157.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-157.xml "css/selectors/old-tests/css3-modsel-157.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-157.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-157.xml)
- [css3-modsel-158.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-158.xml "css/selectors/old-tests/css3-modsel-158.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-158.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-158.xml)
- [css3-modsel-159.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-159.xml "css/selectors/old-tests/css3-modsel-159.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-159.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-159.xml)
- [css3-modsel-15b.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-15b.xml "css/selectors/old-tests/css3-modsel-15b.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-15b.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-15b.xml)
- [css3-modsel-16.xml (manual test)
 ][[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-16.xml)
- [css3-modsel-160.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-160.xml "css/selectors/old-tests/css3-modsel-160.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-160.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-160.xml)
- [css3-modsel-161.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-161.xml "css/selectors/old-tests/css3-modsel-161.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-161.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-161.xml)
- [css3-modsel-166.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-166.xml "css/selectors/old-tests/css3-modsel-166.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-166.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-166.xml)
- [css3-modsel-166a.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-166a.xml "css/selectors/old-tests/css3-modsel-166a.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-166a.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-166a.xml)
- [css3-modsel-167.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-167.xml "css/selectors/old-tests/css3-modsel-167.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-167.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-167.xml)
- [css3-modsel-167a.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-167a.xml "css/selectors/old-tests/css3-modsel-167a.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-167a.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-167a.xml)
- [css3-modsel-168.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-168.xml "css/selectors/old-tests/css3-modsel-168.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-168.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-168.xml)
- [css3-modsel-168a.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-168a.xml "css/selectors/old-tests/css3-modsel-168a.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-168a.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-168a.xml)
- [css3-modsel-169.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-169.xml "css/selectors/old-tests/css3-modsel-169.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-169.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-169.xml)
- [css3-modsel-169a.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-169a.xml "css/selectors/old-tests/css3-modsel-169a.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-169a.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-169a.xml)
- [css3-modsel-17.xml (manual test)
 ][[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-17.xml)
- [css3-modsel-170.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-170.xml "css/selectors/old-tests/css3-modsel-170.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-170.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-170.xml)
- [css3-modsel-170a.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-170a.xml "css/selectors/old-tests/css3-modsel-170a.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-170a.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-170a.xml)
- [css3-modsel-170b.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-170b.xml "css/selectors/old-tests/css3-modsel-170b.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-170b.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-170b.xml)
- [css3-modsel-170c.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-170c.xml "css/selectors/old-tests/css3-modsel-170c.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-170c.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-170c.xml)
- [css3-modsel-170d.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-170d.xml "css/selectors/old-tests/css3-modsel-170d.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-170d.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-170d.xml)
- [css3-modsel-171.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-171.xml "css/selectors/old-tests/css3-modsel-171.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-171.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-171.xml)
- [css3-modsel-172a.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-172a.xml "css/selectors/old-tests/css3-modsel-172a.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-172a.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-172a.xml)
- [css3-modsel-172b.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-172b.xml "css/selectors/old-tests/css3-modsel-172b.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-172b.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-172b.xml)
- [css3-modsel-173a.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-173a.xml "css/selectors/old-tests/css3-modsel-173a.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-173a.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-173a.xml)
- [css3-modsel-173b.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-173b.xml "css/selectors/old-tests/css3-modsel-173b.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-173b.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-173b.xml)
- [css3-modsel-174a.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-174a.xml "css/selectors/old-tests/css3-modsel-174a.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-174a.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-174a.xml)
- [css3-modsel-174b.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-174b.xml "css/selectors/old-tests/css3-modsel-174b.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-174b.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-174b.xml)
- [css3-modsel-175a.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-175a.xml "css/selectors/old-tests/css3-modsel-175a.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-175a.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-175a.xml)
- [css3-modsel-175b.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-175b.xml "css/selectors/old-tests/css3-modsel-175b.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-175b.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-175b.xml)
- [css3-modsel-175c.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-175c.xml "css/selectors/old-tests/css3-modsel-175c.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-175c.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-175c.xml)
- [css3-modsel-176.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-176.xml "css/selectors/old-tests/css3-modsel-176.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-176.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-176.xml)
- [css3-modsel-177a.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-177a.xml "css/selectors/old-tests/css3-modsel-177a.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-177a.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-177a.xml)
- [css3-modsel-177b.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-177b.xml "css/selectors/old-tests/css3-modsel-177b.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-177b.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-177b.xml)
- [css3-modsel-178.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-178.xml "css/selectors/old-tests/css3-modsel-178.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-178.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-178.xml)
- [css3-modsel-179.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-179.xml "css/selectors/old-tests/css3-modsel-179.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-179.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-179.xml)
- [css3-modsel-179a.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-179a.xml "css/selectors/old-tests/css3-modsel-179a.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-179a.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-179a.xml)
- [css3-modsel-18.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-18.xml "css/selectors/old-tests/css3-modsel-18.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-18.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-18.xml)
- [css3-modsel-180a.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-180a.xml "css/selectors/old-tests/css3-modsel-180a.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-180a.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-180a.xml)
- [css3-modsel-181.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-181.xml "css/selectors/old-tests/css3-modsel-181.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-181.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-181.xml)
- [css3-modsel-182.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-182.xml "css/selectors/old-tests/css3-modsel-182.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-182.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-182.xml)
- [css3-modsel-183.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-183.xml "css/selectors/old-tests/css3-modsel-183.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-183.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-183.xml)
- [css3-modsel-184a.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-184a.xml "css/selectors/old-tests/css3-modsel-184a.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-184a.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-184a.xml)
- [css3-modsel-184b.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-184b.xml "css/selectors/old-tests/css3-modsel-184b.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-184b.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-184b.xml)
- [css3-modsel-184c.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-184c.xml "css/selectors/old-tests/css3-modsel-184c.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-184c.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-184c.xml)
- [css3-modsel-184d.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-184d.xml "css/selectors/old-tests/css3-modsel-184d.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-184d.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-184d.xml)
- [css3-modsel-184e.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-184e.xml "css/selectors/old-tests/css3-modsel-184e.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-184e.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-184e.xml)
- [css3-modsel-184f.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-184f.xml "css/selectors/old-tests/css3-modsel-184f.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-184f.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-184f.xml)
- [css3-modsel-18a.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-18a.xml "css/selectors/old-tests/css3-modsel-18a.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-18a.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-18a.xml)
- [css3-modsel-18b.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-18b.xml "css/selectors/old-tests/css3-modsel-18b.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-18b.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-18b.xml)
- [css3-modsel-18c.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-18c.xml "css/selectors/old-tests/css3-modsel-18c.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-18c.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-18c.xml)
- [css3-modsel-19.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-19.xml "css/selectors/old-tests/css3-modsel-19.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-19.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-19.xml)
- [css3-modsel-19b.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-19b.xml "css/selectors/old-tests/css3-modsel-19b.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-19b.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-19b.xml)
- [css3-modsel-2.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-2.xml "css/selectors/old-tests/css3-modsel-2.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-2.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-2.xml)
- [css3-modsel-20.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-20.xml "css/selectors/old-tests/css3-modsel-20.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-20.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-20.xml)
- [css3-modsel-21.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-21.xml "css/selectors/old-tests/css3-modsel-21.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-21.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-21.xml)
- [css3-modsel-21b.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-21b.xml "css/selectors/old-tests/css3-modsel-21b.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-21b.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-21b.xml)
- [css3-modsel-21c.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-21c.xml "css/selectors/old-tests/css3-modsel-21c.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-21c.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-21c.xml)
- [css3-modsel-22.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-22.xml "css/selectors/old-tests/css3-modsel-22.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-22.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-22.xml)
- [css3-modsel-25.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-25.xml "css/selectors/old-tests/css3-modsel-25.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-25.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-25.xml)
- [css3-modsel-27.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-27.xml "css/selectors/old-tests/css3-modsel-27.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-27.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-27.xml)
- [css3-modsel-27a.xml (visual test)
 ][[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-27a.xml)
- [css3-modsel-27b.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-27b.xml "css/selectors/old-tests/css3-modsel-27b.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-27b.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-27b.xml)
- [css3-modsel-28.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-28.xml "css/selectors/old-tests/css3-modsel-28.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-28.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-28.xml)
- [css3-modsel-28b.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-28b.xml "css/selectors/old-tests/css3-modsel-28b.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-28b.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-28b.xml)
- [css3-modsel-29.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-29.xml "css/selectors/old-tests/css3-modsel-29.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-29.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-29.xml)
- [css3-modsel-29b.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-29b.xml "css/selectors/old-tests/css3-modsel-29b.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-29b.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-29b.xml)
- [css3-modsel-3.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-3.xml "css/selectors/old-tests/css3-modsel-3.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-3.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-3.xml)
- [css3-modsel-30.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-30.xml "css/selectors/old-tests/css3-modsel-30.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-30.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-30.xml)
- [css3-modsel-31.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-31.xml "css/selectors/old-tests/css3-modsel-31.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-31.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-31.xml)
- [css3-modsel-32.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-32.xml "css/selectors/old-tests/css3-modsel-32.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-32.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-32.xml)
- [css3-modsel-33.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-33.xml "css/selectors/old-tests/css3-modsel-33.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-33.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-33.xml)
- [css3-modsel-34.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-34.xml "css/selectors/old-tests/css3-modsel-34.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-34.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-34.xml)
- [css3-modsel-35.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-35.xml "css/selectors/old-tests/css3-modsel-35.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-35.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-35.xml)
- [css3-modsel-36.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-36.xml "css/selectors/old-tests/css3-modsel-36.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-36.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-36.xml)
- [css3-modsel-37.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-37.xml "css/selectors/old-tests/css3-modsel-37.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-37.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-37.xml)
- [css3-modsel-38.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-38.xml "css/selectors/old-tests/css3-modsel-38.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-38.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-38.xml)
- [css3-modsel-39.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-39.xml "css/selectors/old-tests/css3-modsel-39.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-39.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-39.xml)
- [css3-modsel-39a.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-39a.xml "css/selectors/old-tests/css3-modsel-39a.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-39a.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-39a.xml)
- [css3-modsel-39b.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-39b.xml "css/selectors/old-tests/css3-modsel-39b.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-39b.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-39b.xml)
- [css3-modsel-39c.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-39c.xml "css/selectors/old-tests/css3-modsel-39c.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-39c.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-39c.xml)
- [css3-modsel-3a.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-3a.xml "css/selectors/old-tests/css3-modsel-3a.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-3a.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-3a.xml)
- [css3-modsel-4.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-4.xml "css/selectors/old-tests/css3-modsel-4.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-4.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-4.xml)
- [css3-modsel-41.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-41.xml "css/selectors/old-tests/css3-modsel-41.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-41.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-41.xml)
- [css3-modsel-41a.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-41a.xml "css/selectors/old-tests/css3-modsel-41a.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-41a.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-41a.xml)
- [css3-modsel-42.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-42.xml "css/selectors/old-tests/css3-modsel-42.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-42.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-42.xml)
- [css3-modsel-42a.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-42a.xml "css/selectors/old-tests/css3-modsel-42a.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-42a.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-42a.xml)
- [css3-modsel-43.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-43.xml "css/selectors/old-tests/css3-modsel-43.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-43.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-43.xml)
- [css3-modsel-43b.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-43b.xml "css/selectors/old-tests/css3-modsel-43b.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-43b.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-43b.xml)
- [css3-modsel-44.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-44.xml "css/selectors/old-tests/css3-modsel-44.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-44.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-44.xml)
- [css3-modsel-44b.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-44b.xml "css/selectors/old-tests/css3-modsel-44b.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-44b.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-44b.xml)
- [css3-modsel-44c.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-44c.xml "css/selectors/old-tests/css3-modsel-44c.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-44c.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-44c.xml)
- [css3-modsel-44d.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-44d.xml "css/selectors/old-tests/css3-modsel-44d.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-44d.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-44d.xml)
- [css3-modsel-45.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-45.xml "css/selectors/old-tests/css3-modsel-45.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-45.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-45.xml)
- [css3-modsel-45b.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-45b.xml "css/selectors/old-tests/css3-modsel-45b.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-45b.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-45b.xml)
- [css3-modsel-45c.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-45c.xml "css/selectors/old-tests/css3-modsel-45c.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-45c.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-45c.xml)
- [css3-modsel-46.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-46.xml "css/selectors/old-tests/css3-modsel-46.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-46.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-46.xml)
- [css3-modsel-46b.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-46b.xml "css/selectors/old-tests/css3-modsel-46b.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-46b.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-46b.xml)
- [css3-modsel-47.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-47.xml "css/selectors/old-tests/css3-modsel-47.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-47.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-47.xml)
- [css3-modsel-48.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-48.xml "css/selectors/old-tests/css3-modsel-48.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-48.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-48.xml)
- [css3-modsel-49.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-49.xml "css/selectors/old-tests/css3-modsel-49.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-49.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-49.xml)
- [css3-modsel-5.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-5.xml "css/selectors/old-tests/css3-modsel-5.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-5.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-5.xml)
- [css3-modsel-50.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-50.xml "css/selectors/old-tests/css3-modsel-50.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-50.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-50.xml)
- [css3-modsel-51.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-51.xml "css/selectors/old-tests/css3-modsel-51.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-51.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-51.xml)
- [css3-modsel-52.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-52.xml "css/selectors/old-tests/css3-modsel-52.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-52.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-52.xml)
- [css3-modsel-53.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-53.xml "css/selectors/old-tests/css3-modsel-53.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-53.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-53.xml)
- [css3-modsel-54.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-54.xml "css/selectors/old-tests/css3-modsel-54.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-54.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-54.xml)
- [css3-modsel-55.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-55.xml "css/selectors/old-tests/css3-modsel-55.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-55.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-55.xml)
- [css3-modsel-56.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-56.xml "css/selectors/old-tests/css3-modsel-56.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-56.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-56.xml)
- [css3-modsel-57.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-57.xml "css/selectors/old-tests/css3-modsel-57.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-57.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-57.xml)
- [css3-modsel-57b.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-57b.xml "css/selectors/old-tests/css3-modsel-57b.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-57b.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-57b.xml)
- [css3-modsel-59.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-59.xml "css/selectors/old-tests/css3-modsel-59.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-59.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-59.xml)
- [css3-modsel-6.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-6.xml "css/selectors/old-tests/css3-modsel-6.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-6.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-6.xml)
- [css3-modsel-60.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-60.xml "css/selectors/old-tests/css3-modsel-60.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-60.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-60.xml)
- [css3-modsel-61.xml (manual test)
 ][[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-61.xml)
- [css3-modsel-62.xml (manual test)
 ][[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-62.xml)
- [css3-modsel-63.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-63.xml "css/selectors/old-tests/css3-modsel-63.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-63.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-63.xml)
- [css3-modsel-64.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-64.xml "css/selectors/old-tests/css3-modsel-64.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-64.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-64.xml)
- [css3-modsel-65.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-65.xml "css/selectors/old-tests/css3-modsel-65.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-65.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-65.xml)
- [css3-modsel-66.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-66.xml "css/selectors/old-tests/css3-modsel-66.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-66.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-66.xml)
- [css3-modsel-66b.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-66b.xml "css/selectors/old-tests/css3-modsel-66b.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-66b.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-66b.xml)
- [css3-modsel-67.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-67.xml "css/selectors/old-tests/css3-modsel-67.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-67.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-67.xml)
- [css3-modsel-7.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-7.xml "css/selectors/old-tests/css3-modsel-7.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-7.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-7.xml)
- [css3-modsel-70.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-70.xml "css/selectors/old-tests/css3-modsel-70.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-70.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-70.xml)
- [css3-modsel-72.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-72.xml "css/selectors/old-tests/css3-modsel-72.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-72.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-72.xml)
- [css3-modsel-72b.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-72b.xml "css/selectors/old-tests/css3-modsel-72b.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-72b.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-72b.xml)
- [css3-modsel-73.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-73.xml "css/selectors/old-tests/css3-modsel-73.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-73.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-73.xml)
- [css3-modsel-73b.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-73b.xml "css/selectors/old-tests/css3-modsel-73b.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-73b.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-73b.xml)
- [css3-modsel-74.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-74.xml "css/selectors/old-tests/css3-modsel-74.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-74.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-74.xml)
- [css3-modsel-74b.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-74b.xml "css/selectors/old-tests/css3-modsel-74b.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-74b.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-74b.xml)
- [css3-modsel-75.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-75.xml "css/selectors/old-tests/css3-modsel-75.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-75.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-75.xml)
- [css3-modsel-75b.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-75b.xml "css/selectors/old-tests/css3-modsel-75b.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-75b.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-75b.xml)
- [css3-modsel-76.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-76.xml "css/selectors/old-tests/css3-modsel-76.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-76.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-76.xml)
- [css3-modsel-76b.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-76b.xml "css/selectors/old-tests/css3-modsel-76b.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-76b.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-76b.xml)
- [css3-modsel-77.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-77.xml "css/selectors/old-tests/css3-modsel-77.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-77.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-77.xml)
- [css3-modsel-77b.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-77b.xml "css/selectors/old-tests/css3-modsel-77b.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-77b.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-77b.xml)
- [css3-modsel-78.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-78.xml "css/selectors/old-tests/css3-modsel-78.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-78.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-78.xml)
- [css3-modsel-78b.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-78b.xml "css/selectors/old-tests/css3-modsel-78b.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-78b.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-78b.xml)
- [css3-modsel-79.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-79.xml "css/selectors/old-tests/css3-modsel-79.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-79.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-79.xml)
- [css3-modsel-7b.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-7b.xml "css/selectors/old-tests/css3-modsel-7b.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-7b.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-7b.xml)
- [css3-modsel-8.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-8.xml "css/selectors/old-tests/css3-modsel-8.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-8.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-8.xml)
- [css3-modsel-80.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-80.xml "css/selectors/old-tests/css3-modsel-80.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-80.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-80.xml)
- [css3-modsel-81.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-81.xml "css/selectors/old-tests/css3-modsel-81.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-81.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-81.xml)
- [css3-modsel-81b.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-81b.xml "css/selectors/old-tests/css3-modsel-81b.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-81b.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-81b.xml)
- [css3-modsel-82.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-82.xml "css/selectors/old-tests/css3-modsel-82.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-82.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-82.xml)
- [css3-modsel-82b.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-82b.xml "css/selectors/old-tests/css3-modsel-82b.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-82b.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-82b.xml)
- [css3-modsel-83.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-83.xml "css/selectors/old-tests/css3-modsel-83.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-83.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-83.xml)
- [css3-modsel-86.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-86.xml "css/selectors/old-tests/css3-modsel-86.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-86.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-86.xml)
- [css3-modsel-87.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-87.xml "css/selectors/old-tests/css3-modsel-87.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-87.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-87.xml)
- [css3-modsel-87b.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-87b.xml "css/selectors/old-tests/css3-modsel-87b.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-87b.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-87b.xml)
- [css3-modsel-88.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-88.xml "css/selectors/old-tests/css3-modsel-88.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-88.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-88.xml)
- [css3-modsel-88b.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-88b.xml "css/selectors/old-tests/css3-modsel-88b.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-88b.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-88b.xml)
- [css3-modsel-89.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-89.xml "css/selectors/old-tests/css3-modsel-89.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-89.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-89.xml)
- [css3-modsel-9.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-9.xml "css/selectors/old-tests/css3-modsel-9.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-9.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-9.xml)
- [css3-modsel-90.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-90.xml "css/selectors/old-tests/css3-modsel-90.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-90.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-90.xml)
- [css3-modsel-90b.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-90b.xml "css/selectors/old-tests/css3-modsel-90b.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-90b.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-90b.xml)
- [css3-modsel-91.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-91.xml "css/selectors/old-tests/css3-modsel-91.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-91.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-91.xml)
- [css3-modsel-92.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-92.xml "css/selectors/old-tests/css3-modsel-92.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-92.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-92.xml)
- [css3-modsel-93.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-93.xml "css/selectors/old-tests/css3-modsel-93.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-93.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-93.xml)
- [css3-modsel-94.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-94.xml "css/selectors/old-tests/css3-modsel-94.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-94.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-94.xml)
- [css3-modsel-94b.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-94b.xml "css/selectors/old-tests/css3-modsel-94b.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-94b.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-94b.xml)
- [css3-modsel-95.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-95.xml "css/selectors/old-tests/css3-modsel-95.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-95.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-95.xml)
- [css3-modsel-96.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-96.xml "css/selectors/old-tests/css3-modsel-96.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-96.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-96.xml)
- [css3-modsel-96b.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-96b.xml "css/selectors/old-tests/css3-modsel-96b.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-96b.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-96b.xml)
- [css3-modsel-97.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-97.xml "css/selectors/old-tests/css3-modsel-97.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-97.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-97.xml)
- [css3-modsel-97b.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-97b.xml "css/selectors/old-tests/css3-modsel-97b.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-97b.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-97b.xml)
- [css3-modsel-98.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-98.xml "css/selectors/old-tests/css3-modsel-98.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-98.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-98.xml)
- [css3-modsel-98b.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-98b.xml "css/selectors/old-tests/css3-modsel-98b.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-98b.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-98b.xml)
- [css3-modsel-99.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-99.xml "css/selectors/old-tests/css3-modsel-99.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-99.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-99.xml)
- [css3-modsel-99b.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-99b.xml "css/selectors/old-tests/css3-modsel-99b.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-99b.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-99b.xml)
- [css3-modsel-d1.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-d1.xml "css/selectors/old-tests/css3-modsel-d1.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-d1.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-d1.xml)
- [css3-modsel-d1b.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-d1b.xml "css/selectors/old-tests/css3-modsel-d1b.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-d1b.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-d1b.xml)
- [css3-modsel-d2.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-d2.xml "css/selectors/old-tests/css3-modsel-d2.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-d2.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-d2.xml)
- [css3-modsel-d3.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-d3.xml "css/selectors/old-tests/css3-modsel-d3.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-d3.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-d3.xml)
- [css3-modsel-d4.xml](https://wpt.fyi/results/css/selectors/old-tests/css3-modsel-d4.xml "css/selectors/old-tests/css3-modsel-d4.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/old-tests/css3-modsel-d4.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/old-tests/css3-modsel-d4.xml)

Tests that do not relate to any section

- [eof-right-after-selector-crash.html](https://wpt.fyi/results/css/selectors/eof-right-after-selector-crash.html "css/selectors/eof-right-after-selector-crash.html")
 [[(live
 test)]](http://wpt.live/css/selectors/eof-right-after-selector-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/eof-right-after-selector-crash.html)
- [eof-some-after-selector-crash.html](https://wpt.fyi/results/css/selectors/eof-some-after-selector-crash.html "css/selectors/eof-some-after-selector-crash.html")
 [[(live
 test)]](http://wpt.live/css/selectors/eof-some-after-selector-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/eof-some-after-selector-crash.html)
- [hash-collision.html](https://wpt.fyi/results/css/selectors/hash-collision.html "css/selectors/hash-collision.html")
 [[(live
 test)]](http://wpt.live/css/selectors/hash-collision.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/hash-collision.html)
- [invalid-pseudos.html](https://wpt.fyi/results/css/selectors/parsing/invalid-pseudos.html "css/selectors/parsing/invalid-pseudos.html")
 [[(live
 test)]](http://wpt.live/css/selectors/parsing/invalid-pseudos.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/parsing/invalid-pseudos.html)
- [selector-after-font-family.html](https://wpt.fyi/results/css/selectors/selector-after-font-family.html "css/selectors/selector-after-font-family.html")
 [[(live
 test)]](http://wpt.live/css/selectors/selector-after-font-family.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/selector-after-font-family.html)

------------------------------------------------------------------------

## 3. Selector Syntax and Structure

### 3.1. Structure and Terminology

A [selector]
represents a particular pattern of element(s) in a tree structure. The
term [selector](#selector) can refer
to a [simple selector](#simple),
[compound selector](#compound),
[complex selector](#complex), or
[selector list](#selector-list).
The [subject of a selector] is any
element that selector is defined to be about; that is, any element
[matching]
that [selector].

A [simple selector]
is a single condition on an element. A [type
selector](#type-selector),
[universal selector](#universal-selector), [attribute
selector](#attribute-selector), [class
selector](#class-selector), [ID
selector](#id-selector), or
[pseudo-class](#pseudo-class) is
a [simple selector](#simple). (It is
represented by
[\<simple-selector\>](#typedef-simple-selector) in the selectors
[grammar](#grammar).) A given element is said to
[match](#match) a [simple
selector] when that [simple
selector], as defined in this specification and in
accordance with the [document
language](#document-language), accurately describes the element.

A [compound selector] is a sequence of [simple selectors](#simple) that are not separated by a
[combinator](#selector-combinator), and represents a set of simultaneous conditions on a
single element. If it contains a [type
selector](#type-selector) or
[universal selector](#universal-selector), that selector must come first in the sequence. Only
one type selector or universal selector is allowed in the sequence. (A
[compound selector](#compound) is
represented by
[\<compound-selector\>](#typedef-compound-selector) in the selectors
[grammar](#grammar).) A given element is said to
[match](#match) a [compound
selector] when it matches all [simple
selectors] in the [compound
selector].

 As whitespace represents the [descendant
combinator](#descendant-combinator), no whitespace is allowed between the [simple
selectors](#simple) in a [compound
selector](#compound).

A [pseudo-compound selector] is a
[pseudo-element](#pseudo-element) selector, optionally followed by additional
[pseudo-class](#pseudo-class)
selectors, and optionally preceded by a [compound
selector](#compound) or another
[pseudo-compound selector](#pseudo-compound), without any
[combinators](#selector-combinator). (A [pseudo-compound
selector] is represented by
[\<pseudo-compound-selector\>](#typedef-pseudo-compound-selector) in the selectors
[grammar](#grammar).) A [pseudo-element]
[matches](#match) a [pseudo-compound
selector] when it has the specified
pseudo-element name, matches the additional conditions represented by
any [pseudo-classes], and has an [originating
element](#originating-element) represented by the adjacent preceding selector. If
there is no adjacent preceding selector, the [universal
selector](#universal-selector) is assumed. (For example, [.foo ::before] is
equivalent to [.foo \*::before], and distinct from
[.foo::before].)

For example, in
[.foo::before:hover], the [.foo] is a [compound
selector](#compound), while the
[::before:hover] is a [pseudo-compound
selector](#pseudo-compound).
However, in [.foo::before::marker],
[::before](https://drafts.csswg.org/css-pseudo-4/#selectordef-before) and
[::marker](https://drafts.csswg.org/css-pseudo-4/#selectordef-marker) are separate [pseudo-compound
selectors].

 A [pseudo-compound
selector](#pseudo-compound)
**is not** a [compound selector](#compound), and can't be used in places that expect a [compound
selector] only. [Pseudo-compound
selectors] act as if they carry a
[combinator](#selector-combinator) with themselves, expressing their relationship with
their [originating
element](#originating-element), just as the
[\>](#selectordef-child) combinator expresses a relationship with a parent
element.

A [combinator] is a condition of relationship between two
elements represented by the [compound
selectors](#compound) on either
side. Combinators in Selectors Level 4 include: the [descendant
combinator](#descendant-combinator) (white space), the [child
combinator](#child-combinator) (U+003E, `>`), the [next-sibling
combinator](#next-sibling-combinator) (U+002B, `+`), and the [subsequent-sibling
combinator](#subsequent-sibling-combinator) (U+007E, `~`). Two given elements are said to
[match](#match) a
[combinator](#selector-combinator) when the condition of relationship between these
elements is true.

A [complex selector] is a sequence of one or more [compound
selectors](#compound) and/or
[pseudo-compound selectors](#pseudo-compound), with [compound selectors]
separated by
[combinators](#selector-combinator). It represents a set of simultaneous conditions on a
set of elements in the particular relationships described by its
[combinators]. (Complex selectors are
represented by
[\<complex-selector\>](#typedef-complex-selector) in the selectors
[grammar](#grammar).) A given element or pseudo-element is said to
[match](#match) a [complex
selector](#complex) when it matches
the final [compound]/[pseudo-compound
selector] in the sequence, and every
preceding unit of the sequence also [matches] an
element or [pseudo-element](#pseudo-element), with the correct relationship between consecutive
units as expressed by the combinators separating them (or, for
[pseudo-compound selectors], the correct
[originating
element](#originating-element) relationship).

For example, [.foo.bar] matches
an element with both \"foo\" and \"bar\" classes.

[.ancestor \> .foo.bar] matches a subset of those elements: only
those whose parent element (as indicated by the
[\>](#selectordef-child) combinator) has the \"ancestor\" class.

[.foo.bar::before] matches a
[::before](https://drafts.csswg.org/css-pseudo-4/#selectordef-before) pseudo-element, whose [originating
element](#originating-element) matches [.foo.bar].

A [list of simple/compound/complex selectors]
is a comma-separated list of [simple](#simple), [compound](#compound), or [complex selectors](#complex). This is also called just a [selector
list] when the type is either
unimportant or specified in the surrounding prose; if the type is
important and unspecified, it defaults to meaning a [list of complex
selectors](#list-of-simple-selectors). (See [§ 4.1 Selector Lists](#grouping) for additional
information on [selector lists](#selector-list) and the various \<\*-selector-list\> productions in the
[grammar](#grammar) for their formal syntax.) A given element is said to
[match](#match) a [selector
list] when it matches any (at least one) of the
[selectors](#selector) in that
[selector list].

### 3.2. Data Model

Selectors are evaluated against an element tree such as the DOM.
[\[DOM\]](#biblio-dom "DOM Standard") Within this
specification, this may be referred to as the \"document tree\" or
\"source document\".

Each element may have any of the following five aspects, which can be
selected against, all of which are matched as strings:

- The element's type (also known as its tag name).
- The element's namespace.
- An ID.
- Classes (named groups) to which it belongs.
- Attributes, which are name-value pairs.

Many of the selectors depend on the semantics of the [document
language]
(i.e. the language and semantics of the document tree) and/or the
semantics of the [host language] (i.e. the language that is using selectors
syntax). For example, the [:lang()](#lang-pseudo) selector depends on the [document
language](#document-language) (e.g. HTML) to define how an element is associated with
a language. As a slightly different example, the
[::first-line](https://drafts.csswg.org/css-pseudo-4/#selectordef-first-line) pseudo-element depends on the [host
language](#host-language) (e.g.
CSS) to define what a [::first-line] pseudo-element represents and what it can do.

#### 3.2.1. Featureless Elements

Tests

- [featureless-001.html](https://wpt.fyi/results/css/selectors/featureless-001.html "css/selectors/featureless-001.html")
 [[(live
 test)]](http://wpt.live/css/selectors/featureless-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/featureless-001.html)
- [featureless-002.html](https://wpt.fyi/results/css/selectors/featureless-002.html "css/selectors/featureless-002.html")
 [[(live
 test)]](http://wpt.live/css/selectors/featureless-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/featureless-002.html)
- [featureless-003.html](https://wpt.fyi/results/css/selectors/featureless-003.html "css/selectors/featureless-003.html")
 [[(live
 test)]](http://wpt.live/css/selectors/featureless-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/featureless-003.html)
- [featureless-004.html](https://wpt.fyi/results/css/selectors/featureless-004.html "css/selectors/featureless-004.html")
 [[(live
 test)]](http://wpt.live/css/selectors/featureless-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/featureless-004.html)
- [featureless-005.html](https://wpt.fyi/results/css/selectors/featureless-005.html "css/selectors/featureless-005.html")
 [[(live
 test)]](http://wpt.live/css/selectors/featureless-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/featureless-005.html)

While individual elements may lack any of the above features, some
elements are [featureless]. A [featureless](#featureless) element does not match *any selector at all*, except:

- [simple selectors](#simple) it is
 explicitly defined to match

- [compound selectors](#compound),
 if all contained [simple selectors](#simple) are allowed to match it

- [complex selectors](#complex), if
 the [compound selector](#compound) targeting the
 [subject](#selector-subject) is allowed to match it

- [selector lists](#selector-list), if at least one selector in the list is allowed to
 match it

- [logical combination
 pseudo-classes](#logical-combination-pseudo-classes), if their argument selector is allowed to match it

- the [:has()](#has-pseudo)
 pseudo-class, if and only if the [compound
 selector](#compound) it's part of
 contains at least one *other* [simple
 selector](#simple) that's allowed
 to match it.

If a selector would otherwise match a
[featureless](#featureless)
element, except for the existence of the default namespace
[\[CSS-NAMESPACES-3\]](#biblio-css-namespaces-3 "CSS Namespaces Module Level 3")
(because [featureless] elements do not have a
namespace unless otherwise defined), the default namespace does not
prevent the match.

For example, the [shadow
host](https://dom.spec.whatwg.org/#element-shadow-host) in a [shadow
tree](https://dom.spec.whatwg.org/#concept-shadow-tree) is [featureless](#featureless), and can't be matched by *any*
[pseudo-class](#pseudo-class)
except for
[:host](https://drafts.csswg.org/css-shadow-1/#selectordef-host) and
[:host-context()](https://drafts.csswg.org/css-shadow-1/#selectordef-host-context) (or combinations including those, such as
[:is(:host, :root)]).

Logical combinations like [:not(.foo:host)] will never match the
host element (even if it doesn't have a \"foo\" class), because not all
of the simple selectors in [.foo:host] are allowed to match the
[shadow
host](https://dom.spec.whatwg.org/#element-shadow-host).

Similarly, [:not(:host \> .foo)] will never match the [shadow
host](https://dom.spec.whatwg.org/#element-shadow-host), even tho the [shadow
host] is indeed \*not\* a descendant of
itself and doesn't have the \"foo\" class, because the subject of the
complex selector argument ([.foo]) isn't allowed to match the
[shadow host].

In general, you can't match a
[featureless](#featureless)
element without explicitly using one of the [simple
selectors](#simple) it's allowed to
match, to avoid accidentally selecting one of these elements (which are
otherwise *intentionally* easy to not think about). For example,
[\*](https://drafts.csswg.org/selectors-3/#x) will never match a
[featureless] element.

The rule for [:has()](#has-pseudo), above, works similarly. Even if a [shadow
host](https://dom.spec.whatwg.org/#element-shadow-host) contains a [.foo] descendant, [:has(.foo)]
will not match it, because *the rest* of the compound selector (empty)
doesn't contain a simple selector that can match the host. You have to
write [:host:has(.foo)] in order to match the host element.

### 3.3. Scoped Selectors

Some host applications may choose to [scope] selectors to a particular subtree or fragment of
the document, The root of the scoping subtree is called the [scoping
root].

When a selector is [scoped](#scoped-selector), it matches an element only if the element is a
descendant of the [scoping root](#scoping-root). (The rest of the selector can match unrestricted; it's
only the final matched elements that must be within the scope.)

For example, the
[`querySelector()`] method defined in
[\[DOM\]](#biblio-dom "DOM Standard") allows the
author to evaluate a
[scoped](#scoped-selector)
selector relative to the element it's called on.

A call like `widget.querySelector("a")` will thus only find
[`a`](https://html.spec.whatwg.org/multipage/text-level-semantics.html#the-a-element) elements inside of the `widget` element, ignoring
any other
[`a`](https://html.spec.whatwg.org/multipage/text-level-semantics.html#the-a-element)s that might be scattered throughout the document.

### 3.4. Relative Selectors

Certain contexts may accept [relative selectors], which are a shorthand for selectors that
represent elements relative to one or more [relative selector anchor
elements]. Relative selectors
begin with a
[combinator](#selector-combinator), with a selector representing the [anchor
element](#relative-selector-anchor-elements) implied at the start of the selector. (If no combinator
is present, the [descendant
combinator](#descendant-combinator) is implied.)

Relative selectors are represented by
[\<relative-selector\>](#typedef-relative-selector) in the selectors [grammar](#grammar),
and lists of them by
[\<relative-selector-list\>](#typedef-relative-selector-list).

### 3.5. Pseudo-classes

[Pseudo-classes] are [simple
selectors](#simple) that permit
selection based on information that lies outside of the document tree or
that can be awkward or impossible to express using the other simple
selectors. They can also be dynamic, in the sense that an element can
acquire or lose a pseudo-class while a user interacts with the document,
without the document itself changing.
[Pseudo-classes](#pseudo-class)
do not appear in or modify the document source or document tree.

The syntax of a [pseudo-class](#pseudo-class) consists of a \":\" (U+003A COLON) followed by the name
of the [pseudo-class] as a CSS
[identifier](https://drafts.csswg.org/css-values-4/#css-css-identifier), and, in the case of a [functional
pseudo-class], a pair of parentheses containing its arguments.

For example,
[:valid](#valid-pseudo) is
a regular pseudo-class, and
[:lang()](#lang-pseudo) is
a [functional
pseudo-class](#functional-pseudo-class).

Like all CSS keywords,
[pseudo-class](#pseudo-class)
names are [ASCII
case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive). No [white space](#whitespace) is allowed between the colon and the name of the
[pseudo-class], nor, as usual for CSS syntax,
between a [functional
pseudo-class](#functional-pseudo-class)'s name and its opening parenthesis (which thus form a
CSS [function token]). Also as usual, [white
space] is allowed around the arguments inside the
parentheses of a functional pseudo-class unless otherwise specified.

Like other [simple selectors](#simple), [pseudo-classes](#pseudo-class) are allowed in all [compound
selectors](#compound) contained in
a selector, and must follow the [type
selector](#type-selector) or
[universal selector](#universal-selector), if present.

 Some
[pseudo-classes](#pseudo-class)
are mutually exclusive (such that a [compound
selector](#compound) containing
them, while valid, will never match anything), while others can apply
simultaneously to the same element.

### 3.6. Pseudo-elements

Tests

- [x-pseudo-element.html](https://wpt.fyi/results/css/selectors/x-pseudo-element.html "css/selectors/x-pseudo-element.html")
 [[(live
 test)]](http://wpt.live/css/selectors/x-pseudo-element.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/x-pseudo-element.html)

Similar to how certain
[pseudo-classes](#pseudo-class)
represent additional state information not directly present in the
document tree, a [pseudo-element] represents an *element*
not directly present in the document tree. They are used to create
abstractions about the document tree beyond those provided by the
document tree. For example, pseudo-elements can be used to select
portions of the document that do not correspond to a document-language
element (including such ranges as don't align to element boundaries or
fit within its tree structure); that represent content not in the
document tree or in an alternate projection of the document tree; or
that rely on information provided by styling, layout, user interaction,
and other processes that are not reflected in the document tree.

For instance, document languages do
not offer mechanisms to access the first letter or first line of an
element's content, but there exist
[pseudo-elements](#pseudo-element)
([::first-letter](https://drafts.csswg.org/css-pseudo-4/#selectordef-first-letter) and
[::first-line](https://drafts.csswg.org/css-pseudo-4/#selectordef-first-line)) that allow those things to be styled. Notice
especially that in the case of
[::first-line], which portion of
content is represented by the pseudo-element depends on layout
information that cannot be inferred from the document tree.

[Pseudo-elements](#pseudo-element) can also represent content that doesn't exist in the
source document at all, such as the
[::before](https://drafts.csswg.org/css-pseudo-4/#selectordef-before) and
[::after](https://drafts.csswg.org/css-pseudo-4/#selectordef-after) pseudo-elements which allow additional content
to be inserted before or after the contents of any element.

Like [pseudo-classes](#pseudo-class),
[pseudo-elements](#pseudo-element) do not appear in or modify the document source or
document tree. Accordingly, they also do not affect the interpretation
of [structural
pseudo-classes](#structural-pseudo-classes) or other selectors pertaining to their [originating
element](#originating-element) or its tree.

The host language defines which pseudo-elements exist, their type, and
their abilities. Pseudo-elements that exist in CSS are defined in
[\[CSS21\]](#biblio-css21 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")
(Level 2),
[\[SELECT\]](#biblio-select "Selectors Level 3")
(Level 3), and
[\[CSS-PSEUDO-4\]](#biblio-css-pseudo-4 "CSS Pseudo-Elements Module Level 4")
(Level 4).

#### 3.6.1. Syntax

The syntax of a
[pseudo-element](#pseudo-element) is \"::\" (two U+003A COLON characters) followed by the
name of the [pseudo-element] as an
[identifier](https://drafts.csswg.org/css-values-4/#css-css-identifier), and, in the case of a [functional
pseudo-element], a pair of parentheses containing its
arguments. [Pseudo-element] names are [ASCII
case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive). No [white space](#whitespace) is allowed between the two colons, or between the
colons and the name.

Because [CSS Level 1](https://www.w3.org/TR/CSS1) and [CSS Level
2](https://www.w3.org/TR/CSS2) conflated pseudo-elements and
pseudo-classes by sharing a single-colon syntax for both, user agents
must also accept the previous one-colon notation for the Level 1 & 2
pseudo-elements
([::before](https://drafts.csswg.org/css-pseudo-4/#selectordef-before),
[::after](https://drafts.csswg.org/css-pseudo-4/#selectordef-after),
[::first-line](https://drafts.csswg.org/css-pseudo-4/#selectordef-first-line), and
[::first-letter](https://drafts.csswg.org/css-pseudo-4/#selectordef-first-letter)). This compatibility notation is not allowed for
any other [pseudo-elements](#pseudo-element). However, as this syntax is deprecated, authors should
use the Level 3+ double-colon syntax for these
[pseudo-elements].

[Pseudo-elements](#pseudo-element) are [featureless](#featureless), and so can't be matched by any other selector.

#### 3.6.2. Binding to the Document Tree

[Pseudo-elements](#pseudo-element) do not exist independently in the tree: they are always
bound to another element on the page, called their [originating
element]. Syntactically, a [pseudo-element]
immediately follows the [compound
selector](#compound) representing
its [originating
element](#originating-element). If this [compound selector] is
omitted, it is assumed to be the [universal
selector](#universal-selector)
[\*](https://drafts.csswg.org/selectors-3/#x).

For example, in the selector [div
a::before], the
[`a`](https://html.spec.whatwg.org/multipage/text-level-semantics.html#the-a-element) elements matched by the selector are the
[originating
elements](#originating-element) for the
[::before](https://drafts.csswg.org/css-pseudo-4/#selectordef-before) pseudo-elements attached to them.

The selector
[::first-line](https://drafts.csswg.org/css-pseudo-4/#selectordef-first-line) is equivalent to [\*::first-line], which
selects the [::first-line]
pseudo-element on *every* element in the document.

When a [pseudo-element](#pseudo-element) is encountered in a selector, the part of the selector
before the [pseudo-element] selects the
[originating
element](#originating-element) for the [pseudo-element];
the part of the selector after it, if any, applies to the
[pseudo-element] itself. (See below.)

#### 3.6.3. Pseudo-classing Pseudo-elements

Certain [pseudo-elements](#pseudo-element) may be immediately followed by any combination of
certain [pseudo-classes](#pseudo-class), in which case the
[pseudo-element] is represented only when it
is in the corresponding state. This specification allows any
[pseudo-element] to be followed by any
combination of the [logical combination
pseudo-classes](#logical-combination-pseudo-classes) and the [user action
pseudo-classes](#user-action-pseudo-class). Other specifications may allow additional
[pseudo-classes] to be attached to particular
[pseudo-elements]. Combinations that are not
explicitly allowed are [invalid
selectors](#invalid-selector).

 The [logical combination
pseudo-classes](#logical-combination-pseudo-classes) pass any restrictions on validity of selectors at their
position to their arguments.

For example, since the
[:hover](#hover-pseudo)
pseudo-class specifies that it can apply to any pseudo-element,
[::first-line:hover] will match when the first line is hovered.
However, since neither [:focus](#focus-pseudo) nor
[::first-line](https://drafts.csswg.org/css-pseudo-4/#selectordef-first-line) define that [:focus] can apply to [::first-line], the selector [::first-line:focus] will never match
anything.

Notice that [::first-line:hover] is very different from
[:hover::first-line], which matches the first line of any
originating element that is hovered! For example,
[:hover::first-line] also matches the first line of a paragraph
when the second line of the paragraph is hovered, whereas
[::first-line:hover] only matches if the first line itself is
hovered.

#### 3.6.4. Sub-pseudo-elements

Some [pseudo-elements](#pseudo-element) are able to be the [originating
element](#originating-element) of other [pseudo-elements],
which are defined as the [sub-pseudo-elements] of this
[originating pseudo-element]. For example, when
[::before](https://drafts.csswg.org/css-pseudo-4/#selectordef-before) is given a
[list-item](https://drafts.csswg.org/css-display-4/#valdef-display-list-item) [display
type](https://drafts.csswg.org/css-display-4/#display-type), it becomes the [originating
pseudo-element](#originating-pseudo-element) of its [::before::marker]
[sub-pseudo-element](#sub-pseudo-element).

Where disambiguation is needed, the term [ultimate originating
element] refers to the real (non-pseudo) element from which a
[pseudo-element](#pseudo-element) originates.

Unless the corresponding
[sub-pseudo-element](#sub-pseudo-element) is explicitly defined to exist in another
specification, pseudo-element selectors are not valid when compounded to
another pseudo-element selector. So, for example,
[::before::before] is an invalid selector, but
[::before::marker] is valid (in implementations that support the
[::before::marker]
[sub-pseudo-element]).

#### 3.6.5. Internal Structure

Some [pseudo-elements](#pseudo-element) are defined to have internal structure. These
[pseudo-elements] may be followed by
child/descendant combinators to express those relationships. Selectors
containing
[combinators](#selector-combinator) after the pseudo-element are otherwise invalid.

For example, [::first-letter +
span] and [::first-letter em] are invalid selectors.
However, if a new [::shadow] pseudo-element were defined to have
internal structure, [::shadow \> p] would be a valid selector.

 A future specification may expand the capabilities of
existing pseudo-elements, so some of these currently-invalid selectors
(e.g. [::first-line :any-link]) may become valid in the future.

The children of such
[pseudo-elements](#pseudo-element) can simultaneously be children of other elements, too.
However, at least in CSS, their rendering must be defined so as to
maintain the tree-ness of the [box
tree](https://drafts.csswg.org/css-display-4/#box-tree).

### 3.7. Characters and case sensitivity

Tests

- [quirks-mode-stylesheet-dynamic-add-001.html](https://wpt.fyi/results/css/selectors/invalidation/quirks-mode-stylesheet-dynamic-add-001.html "css/selectors/invalidation/quirks-mode-stylesheet-dynamic-add-001.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/quirks-mode-stylesheet-dynamic-add-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/quirks-mode-stylesheet-dynamic-add-001.html)
- [selectors-case-sensitive-001.html](https://wpt.fyi/results/css/selectors/selectors-case-sensitive-001.html "css/selectors/selectors-case-sensitive-001.html")
 [[(live
 test)]](http://wpt.live/css/selectors/selectors-case-sensitive-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/selectors-case-sensitive-001.html)
- [value-case-sensitivity-svg.html](https://wpt.fyi/results/css/selectors/attribute-selectors/attribute-case/value-case-sensitivity-svg.html "css/selectors/attribute-selectors/attribute-case/value-case-sensitivity-svg.html")
 [[(live
 test)]](http://wpt.live/css/selectors/attribute-selectors/attribute-case/value-case-sensitivity-svg.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/attribute-selectors/attribute-case/value-case-sensitivity-svg.html)

All syntax defined by the Selectors spec is [ASCII
case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive) (i.e. \[a-z\] and \[A-Z\] are equivalent), as usual for
CSS syntax---​this includes pseudo-class and pseudo-element names, and
keywords used in various places, such as the
[s](#valdef-attribute-selector-s) or
[i](#valdef-attribute-selector-i) keyword in attribute selectors.

When matching Selectors to names and values defined by the document, by
default this is done using the [identical
to](https://infra.spec.whatwg.org/#string-is) operation (aka \"case sensitive\"), unless otherwise
defined by the host language or another relevant specification. This
includes element names, class names, IDs, attribute names, and attribute
values.

For example, HTML has some mildly
complex rules about matching certain names on HTML elements, which are
*nearly* equivalent to being case-insensitive. See [HTML § 4.16.2
Case-sensitivity of
selectors](https://html.spec.whatwg.org/multipage/semantics-other.html#case-sensitivity-of-selectors)
for details---​this affects element names, attribute names, and *some*
attribute values.

(The HTML parser automatically ASCII-lowercases a number of these
values, so the rules it defines are *usually* equivalent to being [ASCII
case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive)), but it is possible to produce attributes via
scripting that retain their non-lowercase casing, and as a result cannot
be matched by Selectors due to these rules.)

Case sensitivity of namespace prefixes is defined in
[\[CSS3NAMESPACE\]](#biblio-css3namespace "CSS Namespaces Module Level 3").
Case sensitivity of [language
ranges](#language-range) is
defined in the [:lang()](#lang-pseudo) section.

[White space]
in Selectors consists of the code points SPACE (U+0020), TAB (U+0009),
LINE FEED (U+000A), CARRIAGE RETURN (U+000D), and FORM FEED (U+000C).
Other space-like code points, such as EM SPACE (U+2003) and IDEOGRAPHIC
SPACE (U+3000), are never considered syntactic white space.

Code points in Selectors can be escaped with a backslash according to
the same [escaping
rules](https://www.w3.org/TR/CSS21/syndata.html#characters) as CSS.
[\[CSS21\]](#biblio-css21 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")
Note that escaping a code point "cancels out" any special meaning it may
have in Selectors. For example, the selector [#foo\>a] contains a
combinator, but [#foo\\\>a] instead selects an element with the id
`foo>a`.

### 3.8. Declaring Namespace Prefixes

Certain selectors support namespace prefixes. The mechanism by which
namespace prefixes are [declared] should be specified by the language that
uses Selectors. If the language does not specify a namespace prefix
declaration mechanism, then no prefixes are declared. In CSS, namespace
prefixes are declared with the
[\@namespace](https://drafts.csswg.org/css-namespaces-3/#at-ruledef-namespace) rule.
[\[CSS3NAMESPACE\]](#biblio-css3namespace "CSS Namespaces Module Level 3")

### 3.9. Invalid Selectors and Error Handling

Tests

- [selectorText-dynamic-001.html](https://wpt.fyi/results/css/selectors/invalidation/selectorText-dynamic-001.html "css/selectors/invalidation/selectorText-dynamic-001.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/selectorText-dynamic-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/selectorText-dynamic-001.html)
- [sheet-going-away-001.html](https://wpt.fyi/results/css/selectors/invalidation/sheet-going-away-001.html "css/selectors/invalidation/sheet-going-away-001.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/sheet-going-away-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/sheet-going-away-001.html)
- [sheet-going-away-002.html](https://wpt.fyi/results/css/selectors/invalidation/sheet-going-away-002.html "css/selectors/invalidation/sheet-going-away-002.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/sheet-going-away-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/sheet-going-away-002.html)

User agents must observe the rules for handling [invalid
selectors]:

- a parsing error in a selector, e.g. an unrecognized token or a token
 which is not allowed at the current parsing point (see overall [§ 16
 Grammar](#grammar) and per-selector syntax definitions), causes that
 selector to be invalid.
- a simple selector containing an [undeclared namespace
 prefix](#namespaces) is invalid
- a selector containing an invalid simple selector, an invalid
 combinator or an invalid token is invalid.
- a selector list containing an invalid selector is invalid.
- an empty selector, i.e. one that contains no [compound
 selector](#compound), is invalid.

 Consistent with CSS's forwards-compatible parsing
principle, UAs *must* treat as
[invalid](#invalid-selector)
any pseudo-classes, pseudo-elements, combinators, or other syntactic
constructs for which they have no usable level of support. See [Partial
implementations](#w3c-partial).

An [invalid selector](#invalid-selector) represents, and therefore matches, nothing.

### 3.10. Legacy Aliases

Some selectors have a [legacy selector alias]. This is a name which, at
parse time, is converted to the standard name (and thus does not appear
anywhere in any object model representing the selector).

## 4. Logical Combinations

Tests

- [is-where-pseudo-containing-hard-pseudo-and-never-matching.html](https://wpt.fyi/results/css/selectors/invalidation/is-where-pseudo-containing-hard-pseudo-and-never-matching.html "css/selectors/invalidation/is-where-pseudo-containing-hard-pseudo-and-never-matching.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/is-where-pseudo-containing-hard-pseudo-and-never-matching.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/is-where-pseudo-containing-hard-pseudo-and-never-matching.html)
- [is-where-pseudo-containing-hard-pseudo.html](https://wpt.fyi/results/css/selectors/invalidation/is-where-pseudo-containing-hard-pseudo.html "css/selectors/invalidation/is-where-pseudo-containing-hard-pseudo.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/is-where-pseudo-containing-hard-pseudo.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/is-where-pseudo-containing-hard-pseudo.html)

Selector logic can be manipulated by
[compounding](#compound) (logical
AND), [selector lists](#selector-list) (logical OR), and the [logical combination
pseudo-classes]
[:is()](#matches-pseudo), [:where()](#where-pseudo), and
[:not()](#negation-pseudo). The [logical combination
pseudo-classes](#logical-combination-pseudo-classes) are allowed anywhere that any other
[pseudo-classes](#pseudo-class)
are allowed, but pass any restrictions to their arguments. (For example,
if only [compound selectors] are allowed, then only
[compound selectors] are valid within an
[:is()].)

 Since inside
[:is()](#matches-pseudo) and [:where()](#where-pseudo) invalid arguments are dropped without invaliding
the [pseudo-class](#pseudo-class) itself, selector arguments that are invalidated by
contextual restrictions likewise do not invalidate the
[:is()] pseudo-class itself.

### 4.1. Selector Lists

A comma-separated list of selectors represents the union of all elements
selected by each of the individual selectors in the [selector
list](#selector-list). (A comma
is U+002C.) For example, in CSS when several selectors share the same
declarations, they may be grouped into a comma-separated list. White
space may appear before and/or after the comma.

CSS example: In this example, we
condense three rules with identical declarations into one. Thus,

 h1 { font-family: sans-serif }
 h2 { font-family: sans-serif }
 h3 { font-family: sans-serif }

is equivalent to:

 h1, h2, h3 { font-family: sans-serif }

**Warning**: the equivalence is true in this example because all the
selectors are valid selectors. If just one of these selectors were
invalid, the entire [selector
list](#selector-list) would be
invalid. This would invalidate the rule for all three heading elements,
whereas in the former case only one of the three individual heading
rules would be invalidated.

Invalid CSS example:

 h1 { font-family: sans-serif }
 h2..foo { font-family: sans-serif }
 h3 { font-family: sans-serif }

is not equivalent to:

 h1, h2..foo, h3 { font-family: sans-serif }

because the above selector ([h1, h2..foo, h3]) is entirely invalid
and the entire style rule is dropped. (When the selectors are not
grouped, only the rule for [h2..foo] is dropped.)

### 4.2. The Matches-Any Pseudo-class: [:is()]
Tests

- [is.html](https://wpt.fyi/results/css/selectors/invalidation/is.html "css/selectors/invalidation/is.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/is.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/is.html)
- [is-default-ns-001.html](https://wpt.fyi/results/css/selectors/is-default-ns-001.html "css/selectors/is-default-ns-001.html")
 [[(live
 test)]](http://wpt.live/css/selectors/is-default-ns-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/is-default-ns-001.html)
- [is-default-ns-002.html](https://wpt.fyi/results/css/selectors/is-default-ns-002.html "css/selectors/is-default-ns-002.html")
 [[(live
 test)]](http://wpt.live/css/selectors/is-default-ns-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/is-default-ns-002.html)
- [is-default-ns-003.html](https://wpt.fyi/results/css/selectors/is-default-ns-003.html "css/selectors/is-default-ns-003.html")
 [[(live
 test)]](http://wpt.live/css/selectors/is-default-ns-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/is-default-ns-003.html)
- [is-default-ns-002.html](https://wpt.fyi/results/css/selectors/is-default-ns-002.html "css/selectors/is-default-ns-002.html")
 [[(live
 test)]](http://wpt.live/css/selectors/is-default-ns-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/is-default-ns-002.html)
- [is-default-ns-003.html](https://wpt.fyi/results/css/selectors/is-default-ns-003.html "css/selectors/is-default-ns-003.html")
 [[(live
 test)]](http://wpt.live/css/selectors/is-default-ns-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/is-default-ns-003.html)
- [is-nested.html](https://wpt.fyi/results/css/selectors/is-nested.html "css/selectors/is-nested.html")
 [[(live
 test)]](http://wpt.live/css/selectors/is-nested.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/is-nested.html)
- [is-specificity-shadow.html](https://wpt.fyi/results/css/selectors/is-specificity-shadow.html "css/selectors/is-specificity-shadow.html")
 [[(live
 test)]](http://wpt.live/css/selectors/is-specificity-shadow.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/is-specificity-shadow.html)
- [is-specificity.html](https://wpt.fyi/results/css/selectors/is-specificity.html "css/selectors/is-specificity.html")
 [[(live
 test)]](http://wpt.live/css/selectors/is-specificity.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/is-specificity.html)
- [is-where-basic.html](https://wpt.fyi/results/css/selectors/is-where-basic.html "css/selectors/is-where-basic.html")
 [[(live
 test)]](http://wpt.live/css/selectors/is-where-basic.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/is-where-basic.html)
- [is-where-error-crash.html](https://wpt.fyi/results/css/selectors/is-where-error-crash.html "css/selectors/is-where-error-crash.html")
 [[(live
 test)]](http://wpt.live/css/selectors/is-where-error-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/is-where-error-crash.html)
- [is-where-error-recovery.html](https://wpt.fyi/results/css/selectors/is-where-error-recovery.html "css/selectors/is-where-error-recovery.html")
 [[(live
 test)]](http://wpt.live/css/selectors/is-where-error-recovery.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/is-where-error-recovery.html)
- [is-where-not.html](https://wpt.fyi/results/css/selectors/is-where-not.html "css/selectors/is-where-not.html")
 [[(live
 test)]](http://wpt.live/css/selectors/is-where-not.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/is-where-not.html)
- [is-where-pseudo-classes.html](https://wpt.fyi/results/css/selectors/is-where-pseudo-classes.html "css/selectors/is-where-pseudo-classes.html")
 [[(live
 test)]](http://wpt.live/css/selectors/is-where-pseudo-classes.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/is-where-pseudo-classes.html)
- [is-where-pseudo-elements.html](https://wpt.fyi/results/css/selectors/is-where-pseudo-elements.html "css/selectors/is-where-pseudo-elements.html")
 [[(live
 test)]](http://wpt.live/css/selectors/is-where-pseudo-elements.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/is-where-pseudo-elements.html)
- [is-where-shadow.html](https://wpt.fyi/results/css/selectors/is-where-shadow.html "css/selectors/is-where-shadow.html")
 [[(live
 test)]](http://wpt.live/css/selectors/is-where-shadow.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/is-where-shadow.html)
- [is-where-visited.html](https://wpt.fyi/results/css/selectors/is-where-visited.html "css/selectors/is-where-visited.html")
 [[(live
 test)]](http://wpt.live/css/selectors/is-where-visited.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/is-where-visited.html)
- [parse-is-where.html](https://wpt.fyi/results/css/selectors/parsing/parse-is-where.html "css/selectors/parsing/parse-is-where.html")
 [[(live
 test)]](http://wpt.live/css/selectors/parsing/parse-is-where.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/parsing/parse-is-where.html)
- [parse-is.html](https://wpt.fyi/results/css/selectors/parsing/parse-is.html "css/selectors/parsing/parse-is.html")
 [[(live
 test)]](http://wpt.live/css/selectors/parsing/parse-is.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/parsing/parse-is.html)
- [query-is.html](https://wpt.fyi/results/css/selectors/query/query-is.html "css/selectors/query/query-is.html")
 [[(live
 test)]](http://wpt.live/css/selectors/query/query-is.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/query/query-is.html)

The matches-any pseudo-class, [:is()], is a functional
pseudo-class taking a
[\<forgiving-selector-list\>](#typedef-forgiving-selector-list) as its sole argument.

If the argument, after parsing, is an empty list, the pseudo-class is
valid but matches nothing. Otherwise, the pseudo-class matches any
element that matches any of the selectors in the list.

 The specificity of the
[:is()](#matches-pseudo) pseudo-class is replaced by the specificity of its
most specific argument. Thus, a selector written with
[:is()] does not necessarily have
equivalent specificity to the equivalent selector written without
[:is()] For example, if we have [:is(ul,
ol, .list) \> \[hidden\]] and [ul \> \[hidden\], ol \> \[hidden\],
.list \> \[hidden\]] a [\[hidden\]] child of an
[`ol`](https://html.spec.whatwg.org/multipage/grouping-content.html#the-ol-element) matches the first selector with a specificity of
(0,2,0) whereas it matches the second selector with a specificity of
(0,1,1). See [§ 15 Calculating a selector's
specificity](#specificity-rules).

Pseudo-elements cannot be represented by the matches-any pseudo-class;
they are not valid within
[:is()](#matches-pseudo).

Default namespace declarations do not affect the [compound
selector](#compound) representing
the [subject](#selector-subject) of any selector within a
[:is()](#matches-pseudo) pseudo-class, unless that compound selector contains
an explicit [universal
selector](#universal-selector) or [type
selector](#type-selector).

For example, the following selector
matches any element that is being hovered or focused, regardless of its
namespace. In particular, it is not limited to only matching elements in
the default namespace that are being hovered or focused.

 *|*:is(:hover, :focus)

The following selector, however, represents only hovered or focused
elements that are in the default namespace, because it uses an explicit
universal selector within the
[:is()](#matches-pseudo) notation:

 *|*:is(*:hover, *:focus)

As previous drafts of this specification used the name
[:matches()] for this pseudo-class, UAs may
additionally implement this obsolete name as a [legacy selector
alias](#legacy-selector-alias) for [:is()](#matches-pseudo) if needed for backwards-compatibility.

### 4.3. The Negation (Matches-None) Pseudo-class: [:not()]
Tests

- [not-001.html](https://wpt.fyi/results/css/selectors/invalidation/not-001.html "css/selectors/invalidation/not-001.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/not-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/not-001.html)
- [not-002.html](https://wpt.fyi/results/css/selectors/invalidation/not-002.html "css/selectors/invalidation/not-002.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/not-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/not-002.html)
- [not-complex.html](https://wpt.fyi/results/css/selectors/not-complex.html "css/selectors/not-complex.html")
 [[(live
 test)]](http://wpt.live/css/selectors/not-complex.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/not-complex.html)
- [not-default-ns-001.html](https://wpt.fyi/results/css/selectors/not-default-ns-001.html "css/selectors/not-default-ns-001.html")
 [[(live
 test)]](http://wpt.live/css/selectors/not-default-ns-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/not-default-ns-001.html)
- [not-default-ns-002.html](https://wpt.fyi/results/css/selectors/not-default-ns-002.html "css/selectors/not-default-ns-002.html")
 [[(live
 test)]](http://wpt.live/css/selectors/not-default-ns-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/not-default-ns-002.html)
- [not-default-ns-003.html](https://wpt.fyi/results/css/selectors/not-default-ns-003.html "css/selectors/not-default-ns-003.html")
 [[(live
 test)]](http://wpt.live/css/selectors/not-default-ns-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/not-default-ns-003.html)
- [not-links.html](https://wpt.fyi/results/css/selectors/not-links.html "css/selectors/not-links.html")
 [[(live
 test)]](http://wpt.live/css/selectors/not-links.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/not-links.html)
- [not-specificity.html](https://wpt.fyi/results/css/selectors/not-specificity.html "css/selectors/not-specificity.html")
 [[(live
 test)]](http://wpt.live/css/selectors/not-specificity.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/not-specificity.html)
- [parse-not.html](https://wpt.fyi/results/css/selectors/parsing/parse-not.html "css/selectors/parsing/parse-not.html")
 [[(live
 test)]](http://wpt.live/css/selectors/parsing/parse-not.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/parsing/parse-not.html)
- [query-where.html](https://wpt.fyi/results/css/selectors/query/query-where.html "css/selectors/query/query-where.html")
 [[(live
 test)]](http://wpt.live/css/selectors/query/query-where.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/query/query-where.html)

The negation pseudo-class, [:not()], is a functional
pseudo-class taking a
[\<complex-real-selector-list\>](#typedef-complex-real-selector-list) as an argument. It represents an
element that is not represented by its argument.

 In Selectors Level 3, only a single [simple
selector](#simple) was allowed as the
argument to [:not()](#negation-pseudo).

 The specificity of the
[:not()](#negation-pseudo) pseudo-class is replaced by the specificity of the
most specific selector in its argument; thus it has the exact behavior
of [:not(:is(`argument`))]. See [§ 15 Calculating a
selector's specificity](#specificity-rules).

Pseudo-elements cannot be represented by the negation pseudo-class; they
are not valid within
[:not()](#negation-pseudo).

For example, the following selector
matches all
[button](https://html.spec.whatwg.org/multipage/form-elements.html#the-button-element) elements in an HTML document that are not disabled.

 button:not([DISABLED])

The following selector represents all but FOO elements.

 *:not(FOO)

The following compound selector represents all HTML elements except
links.

 html|*:not(:link):not(:visited)

As with [:is()](#matches-pseudo), default namespace declarations do not affect the
[compound selector](#compound)
representing the [subject](#selector-subject) of any selector within a
[:not()](#negation-pseudo) pseudo-class, unless that compound selector contains
an explicit [universal
selector](#universal-selector) or [type
selector](#type-selector). (See
[:is()] for examples.)

 The
[:not()](#negation-pseudo) pseudo-class allows useless selectors to be written.
For instance [:not(\*\|\*)], which represents no element at all,
or [div:not(span)], which is equivalent to [div] but with a
higher specificity.

### 4.4. The Specificity-adjustment Pseudo-class: [:where()]
Tests

- [where.html](https://wpt.fyi/results/css/selectors/invalidation/where.html "css/selectors/invalidation/where.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/where.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/where.html)
- [parse-where.html](https://wpt.fyi/results/css/selectors/parsing/parse-where.html "css/selectors/parsing/parse-where.html")
 [[(live
 test)]](http://wpt.live/css/selectors/parsing/parse-where.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/parsing/parse-where.html)
- [pseudo-where-crash.html](https://wpt.fyi/results/css/selectors/pseudo-where-crash.html "css/selectors/pseudo-where-crash.html")
 [[(live
 test)]](http://wpt.live/css/selectors/pseudo-where-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/pseudo-where-crash.html)

The Specificity-adjustment pseudo-class, [:where()], is a functional
pseudo-class with the same syntax and functionality as
[:is()](#matches-pseudo). Unlike [:is()],
neither the [:where()](#where-pseudo) pseudo-class, nor any of its arguments, contribute to
the [specificity](#specificity) of
the selector---​its [specificity] is always zero.

This is useful for introducing filters in a selector while keeping the
associated style declarations easy to override.

Below is a common example where the
specificity heuristic fails to match author expectations:

 a:not(:hover) {
 text-decoration: none;
 }

 nav a {
 /* Has no effect */
 text-decoration: underline;
 }

However, by using [:where()](#where-pseudo) the author can explicitly declare their intent:

 a:where(:not(:hover)) {
 text-decoration: none;
 }

 nav a {
 /* Works now! */
 text-decoration: underline;
 }

 Future levels of Selectors may introduce an additional
argument to explicitly set the specificity of that instance of the
pseudo-class.

### 4.5. The Relational Pseudo-class: [:has()]
Tests

- [has-argument-with-explicit-scope.html](https://wpt.fyi/results/css/selectors/has-argument-with-explicit-scope.html "css/selectors/has-argument-with-explicit-scope.html")
 [[(live
 test)]](http://wpt.live/css/selectors/has-argument-with-explicit-scope.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/has-argument-with-explicit-scope.html)
- [has-basic.html](https://wpt.fyi/results/css/selectors/has-basic.html "css/selectors/has-basic.html")
 [[(live
 test)]](http://wpt.live/css/selectors/has-basic.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/has-basic.html)
- [has-display-none-checked.html](https://wpt.fyi/results/css/selectors/has-display-none-checked.html "css/selectors/has-display-none-checked.html")
 [[(live
 test)]](http://wpt.live/css/selectors/has-display-none-checked.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/has-display-none-checked.html)
- [has-focus-display-change.html](https://wpt.fyi/results/css/selectors/has-focus-display-change.html "css/selectors/has-focus-display-change.html")
 [[(live
 test)]](http://wpt.live/css/selectors/has-focus-display-change.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/has-focus-display-change.html)
- [has-matches-to-uninserted-elements.html](https://wpt.fyi/results/css/selectors/has-matches-to-uninserted-elements.html "css/selectors/has-matches-to-uninserted-elements.html")
 [[(live
 test)]](http://wpt.live/css/selectors/has-matches-to-uninserted-elements.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/has-matches-to-uninserted-elements.html)
- [has-nth-of-crash.html](https://wpt.fyi/results/css/selectors/has-nth-of-crash.html "css/selectors/has-nth-of-crash.html")
 [[(live
 test)]](http://wpt.live/css/selectors/has-nth-of-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/has-nth-of-crash.html)
- [has-relative-argument.html](https://wpt.fyi/results/css/selectors/has-relative-argument.html "css/selectors/has-relative-argument.html")
 [[(live
 test)]](http://wpt.live/css/selectors/has-relative-argument.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/has-relative-argument.html)
- [has-sibling-chrome-crash.html](https://wpt.fyi/results/css/selectors/has-sibling-chrome-crash.html "css/selectors/has-sibling-chrome-crash.html")
 [[(live
 test)]](http://wpt.live/css/selectors/has-sibling-chrome-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/has-sibling-chrome-crash.html)
- [has-specificity.html](https://wpt.fyi/results/css/selectors/has-specificity.html "css/selectors/has-specificity.html")
 [[(live
 test)]](http://wpt.live/css/selectors/has-specificity.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/has-specificity.html)
- [has-style-sharing-001.html](https://wpt.fyi/results/css/selectors/has-style-sharing-001.html "css/selectors/has-style-sharing-001.html")
 [[(live
 test)]](http://wpt.live/css/selectors/has-style-sharing-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/has-style-sharing-001.html)
- [has-style-sharing-002.html](https://wpt.fyi/results/css/selectors/has-style-sharing-002.html "css/selectors/has-style-sharing-002.html")
 [[(live
 test)]](http://wpt.live/css/selectors/has-style-sharing-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/has-style-sharing-002.html)
- [has-style-sharing-003.html](https://wpt.fyi/results/css/selectors/has-style-sharing-003.html "css/selectors/has-style-sharing-003.html")
 [[(live
 test)]](http://wpt.live/css/selectors/has-style-sharing-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/has-style-sharing-003.html)
- [has-style-sharing-004.html](https://wpt.fyi/results/css/selectors/has-style-sharing-004.html "css/selectors/has-style-sharing-004.html")
 [[(live
 test)]](http://wpt.live/css/selectors/has-style-sharing-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/has-style-sharing-004.html)
- [has-style-sharing-005.html](https://wpt.fyi/results/css/selectors/has-style-sharing-005.html "css/selectors/has-style-sharing-005.html")
 [[(live
 test)]](http://wpt.live/css/selectors/has-style-sharing-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/has-style-sharing-005.html)
- [has-style-sharing-006.html](https://wpt.fyi/results/css/selectors/has-style-sharing-006.html "css/selectors/has-style-sharing-006.html")
 [[(live
 test)]](http://wpt.live/css/selectors/has-style-sharing-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/has-style-sharing-006.html)
- [has-style-sharing-007.html](https://wpt.fyi/results/css/selectors/has-style-sharing-007.html "css/selectors/has-style-sharing-007.html")
 [[(live
 test)]](http://wpt.live/css/selectors/has-style-sharing-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/has-style-sharing-007.html)
- [has-style-sharing-pseudo-001.html](https://wpt.fyi/results/css/selectors/has-style-sharing-pseudo-001.html "css/selectors/has-style-sharing-pseudo-001.html")
 [[(live
 test)]](http://wpt.live/css/selectors/has-style-sharing-pseudo-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/has-style-sharing-pseudo-001.html)
- [has-style-sharing-pseudo-002.html](https://wpt.fyi/results/css/selectors/has-style-sharing-pseudo-002.html "css/selectors/has-style-sharing-pseudo-002.html")
 [[(live
 test)]](http://wpt.live/css/selectors/has-style-sharing-pseudo-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/has-style-sharing-pseudo-002.html)
- [has-style-sharing-pseudo-003.html](https://wpt.fyi/results/css/selectors/has-style-sharing-pseudo-003.html "css/selectors/has-style-sharing-pseudo-003.html")
 [[(live
 test)]](http://wpt.live/css/selectors/has-style-sharing-pseudo-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/has-style-sharing-pseudo-003.html)
- [has-style-sharing-pseudo-004.html](https://wpt.fyi/results/css/selectors/has-style-sharing-pseudo-004.html "css/selectors/has-style-sharing-pseudo-004.html")
 [[(live
 test)]](http://wpt.live/css/selectors/has-style-sharing-pseudo-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/has-style-sharing-pseudo-004.html)
- [has-style-sharing-pseudo-005.html](https://wpt.fyi/results/css/selectors/has-style-sharing-pseudo-005.html "css/selectors/has-style-sharing-pseudo-005.html")
 [[(live
 test)]](http://wpt.live/css/selectors/has-style-sharing-pseudo-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/has-style-sharing-pseudo-005.html)
- [has-style-sharing-pseudo-006.html](https://wpt.fyi/results/css/selectors/has-style-sharing-pseudo-006.html "css/selectors/has-style-sharing-pseudo-006.html")
 [[(live
 test)]](http://wpt.live/css/selectors/has-style-sharing-pseudo-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/has-style-sharing-pseudo-006.html)
- [has-style-sharing-pseudo-007.html](https://wpt.fyi/results/css/selectors/has-style-sharing-pseudo-007.html "css/selectors/has-style-sharing-pseudo-007.html")
 [[(live
 test)]](http://wpt.live/css/selectors/has-style-sharing-pseudo-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/has-style-sharing-pseudo-007.html)
- [has-style-sharing-pseudo-008.html](https://wpt.fyi/results/css/selectors/has-style-sharing-pseudo-008.html "css/selectors/has-style-sharing-pseudo-008.html")
 [[(live
 test)]](http://wpt.live/css/selectors/has-style-sharing-pseudo-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/has-style-sharing-pseudo-008.html)
- [has-visited.html](https://wpt.fyi/results/css/selectors/has-visited.html "css/selectors/has-visited.html")
 [[(live
 test)]](http://wpt.live/css/selectors/has-visited.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/has-visited.html)
- [attribute-or-elemental-selectors-in-has.html](https://wpt.fyi/results/css/selectors/invalidation/attribute-or-elemental-selectors-in-has.html "css/selectors/invalidation/attribute-or-elemental-selectors-in-has.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/attribute-or-elemental-selectors-in-has.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/attribute-or-elemental-selectors-in-has.html)
- [child-indexed-pseudo-classes-in-has.html](https://wpt.fyi/results/css/selectors/invalidation/child-indexed-pseudo-classes-in-has.html "css/selectors/invalidation/child-indexed-pseudo-classes-in-has.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/child-indexed-pseudo-classes-in-has.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/child-indexed-pseudo-classes-in-has.html)
- [has-pseudoclass-only-crash.html](https://wpt.fyi/results/css/selectors/invalidation/crashtests/has-pseudoclass-only-crash.html "css/selectors/invalidation/crashtests/has-pseudoclass-only-crash.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/crashtests/has-pseudoclass-only-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/crashtests/has-pseudoclass-only-crash.html)
- [defined-in-has.html](https://wpt.fyi/results/css/selectors/invalidation/defined-in-has.html "css/selectors/invalidation/defined-in-has.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/defined-in-has.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/defined-in-has.html)
- [dir-pseudo-class-in-has.html](https://wpt.fyi/results/css/selectors/invalidation/dir-pseudo-class-in-has.html "css/selectors/invalidation/dir-pseudo-class-in-has.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/dir-pseudo-class-in-has.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/dir-pseudo-class-in-has.html)
- [empty-pseudo-in-has.html](https://wpt.fyi/results/css/selectors/invalidation/empty-pseudo-in-has.html "css/selectors/invalidation/empty-pseudo-in-has.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/empty-pseudo-in-has.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/empty-pseudo-in-has.html)
- [empty-pseudo-in-has-display-none.html](https://wpt.fyi/results/css/selectors/invalidation/empty-pseudo-in-has-display-none.html "css/selectors/invalidation/empty-pseudo-in-has-display-none.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/empty-pseudo-in-has-display-none.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/empty-pseudo-in-has-display-none.html)
- [fullscreen-pseudo-class-in-has.html](https://wpt.fyi/results/css/selectors/invalidation/fullscreen-pseudo-class-in-has.html "css/selectors/invalidation/fullscreen-pseudo-class-in-has.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/fullscreen-pseudo-class-in-has.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/fullscreen-pseudo-class-in-has.html)
- [has-append-first-node.html](https://wpt.fyi/results/css/selectors/invalidation/has-append-first-node.html "css/selectors/invalidation/has-append-first-node.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/has-append-first-node.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/has-append-first-node.html)
- [has-complexity.html](https://wpt.fyi/results/css/selectors/invalidation/has-complexity.html "css/selectors/invalidation/has-complexity.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/has-complexity.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/has-complexity.html)
- [has-css-nesting-shared.html](https://wpt.fyi/results/css/selectors/invalidation/has-css-nesting-shared.html "css/selectors/invalidation/has-css-nesting-shared.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/has-css-nesting-shared.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/has-css-nesting-shared.html)
- [has-in-adjacent-position.html](https://wpt.fyi/results/css/selectors/invalidation/has-in-adjacent-position.html "css/selectors/invalidation/has-in-adjacent-position.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/has-in-adjacent-position.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/has-in-adjacent-position.html)
- [has-in-ancestor-position.html](https://wpt.fyi/results/css/selectors/invalidation/has-in-ancestor-position.html "css/selectors/invalidation/has-in-ancestor-position.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/has-in-ancestor-position.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/has-in-ancestor-position.html)
- [has-in-is-non-subject-compound.html](https://wpt.fyi/results/css/selectors/invalidation/has-in-is-non-subject-compound.html "css/selectors/invalidation/has-in-is-non-subject-compound.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/has-in-is-non-subject-compound.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/has-in-is-non-subject-compound.html)
- [has-in-parent-position.html](https://wpt.fyi/results/css/selectors/invalidation/has-in-parent-position.html "css/selectors/invalidation/has-in-parent-position.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/has-in-parent-position.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/has-in-parent-position.html)
- [has-in-sibling-position.html](https://wpt.fyi/results/css/selectors/invalidation/has-in-sibling-position.html "css/selectors/invalidation/has-in-sibling-position.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/has-in-sibling-position.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/has-in-sibling-position.html)
- [has-invalidation-after-removing-non-first-element.html](https://wpt.fyi/results/css/selectors/invalidation/has-invalidation-after-removing-non-first-element.html "css/selectors/invalidation/has-invalidation-after-removing-non-first-element.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/has-invalidation-after-removing-non-first-element.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/has-invalidation-after-removing-non-first-element.html)
- [has-invalidation-first-in-sibling-chain.html](https://wpt.fyi/results/css/selectors/invalidation/has-invalidation-first-in-sibling-chain.html "css/selectors/invalidation/has-invalidation-first-in-sibling-chain.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/has-invalidation-first-in-sibling-chain.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/has-invalidation-first-in-sibling-chain.html)
- [has-invalidation-for-wiping-an-element.html](https://wpt.fyi/results/css/selectors/invalidation/has-invalidation-for-wiping-an-element.html "css/selectors/invalidation/has-invalidation-for-wiping-an-element.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/has-invalidation-for-wiping-an-element.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/has-invalidation-for-wiping-an-element.html)
- [has-nested-pseudo-001-crash.html](https://wpt.fyi/results/css/selectors/invalidation/has-nested-pseudo-001-crash.html "css/selectors/invalidation/has-nested-pseudo-001-crash.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/has-nested-pseudo-001-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/has-nested-pseudo-001-crash.html)
- [has-nested-pseudo-002-crash.html](https://wpt.fyi/results/css/selectors/invalidation/has-nested-pseudo-002-crash.html "css/selectors/invalidation/has-nested-pseudo-002-crash.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/has-nested-pseudo-002-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/has-nested-pseudo-002-crash.html)
- [has-nested-pseudo-003-crash.html](https://wpt.fyi/results/css/selectors/invalidation/has-nested-pseudo-003-crash.html "css/selectors/invalidation/has-nested-pseudo-003-crash.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/has-nested-pseudo-003-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/has-nested-pseudo-003-crash.html)
- [has-pseudo-element.html](https://wpt.fyi/results/css/selectors/invalidation/has-pseudo-element.html "css/selectors/invalidation/has-pseudo-element.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/has-pseudo-element.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/has-pseudo-element.html)
- [has-pseudoclass-only.html](https://wpt.fyi/results/css/selectors/invalidation/has-pseudoclass-only.html "css/selectors/invalidation/has-pseudoclass-only.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/has-pseudoclass-only.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/has-pseudoclass-only.html)
- [has-pseudo-element-subject-child-mutation.html](https://wpt.fyi/results/css/selectors/invalidation/has-pseudo-element-subject-child-mutation.html "css/selectors/invalidation/has-pseudo-element-subject-child-mutation.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/has-pseudo-element-subject-child-mutation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/has-pseudo-element-subject-child-mutation.html)
- [has-sibling-insertion-removal.html](https://wpt.fyi/results/css/selectors/invalidation/has-sibling-insertion-removal.html "css/selectors/invalidation/has-sibling-insertion-removal.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/has-sibling-insertion-removal.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/has-sibling-insertion-removal.html)
- [has-sibling.html](https://wpt.fyi/results/css/selectors/invalidation/has-sibling.html "css/selectors/invalidation/has-sibling.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/has-sibling.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/has-sibling.html)
- [has-side-effect.html](https://wpt.fyi/results/css/selectors/invalidation/has-side-effect.html "css/selectors/invalidation/has-side-effect.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/has-side-effect.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/has-side-effect.html)
- [has-unstyled.html](https://wpt.fyi/results/css/selectors/invalidation/has-unstyled.html "css/selectors/invalidation/has-unstyled.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/has-unstyled.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/has-unstyled.html)
- [has-with-is-child-combinator.html](https://wpt.fyi/results/css/selectors/invalidation/has-with-is-child-combinator.html "css/selectors/invalidation/has-with-is-child-combinator.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/has-with-is-child-combinator.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/has-with-is-child-combinator.html)
- [has-with-nesting-parent-containing-complex.html](https://wpt.fyi/results/css/selectors/invalidation/has-with-nesting-parent-containing-complex.html "css/selectors/invalidation/has-with-nesting-parent-containing-complex.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/has-with-nesting-parent-containing-complex.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/has-with-nesting-parent-containing-complex.html)
- [has-with-nesting-parent-containing-hover.html](https://wpt.fyi/results/css/selectors/invalidation/has-with-nesting-parent-containing-hover.html "css/selectors/invalidation/has-with-nesting-parent-containing-hover.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/has-with-nesting-parent-containing-hover.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/has-with-nesting-parent-containing-hover.html)
- [has-with-not.html](https://wpt.fyi/results/css/selectors/invalidation/has-with-not.html "css/selectors/invalidation/has-with-not.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/has-with-not.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/has-with-not.html)
- [has-with-nth-child-sibling-remove.html](https://wpt.fyi/results/css/selectors/invalidation/has-with-nth-child-sibling-remove.html "css/selectors/invalidation/has-with-nth-child-sibling-remove.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/has-with-nth-child-sibling-remove.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/has-with-nth-child-sibling-remove.html)
- [has-with-nth-child.html](https://wpt.fyi/results/css/selectors/invalidation/has-with-nth-child.html "css/selectors/invalidation/has-with-nth-child.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/has-with-nth-child.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/has-with-nth-child.html)
- [has-with-pseudo-class.html](https://wpt.fyi/results/css/selectors/invalidation/has-with-pseudo-class.html "css/selectors/invalidation/has-with-pseudo-class.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/has-with-pseudo-class.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/has-with-pseudo-class.html)
- [host-context-pseudo-class-in-has.html](https://wpt.fyi/results/css/selectors/invalidation/host-context-pseudo-class-in-has.html "css/selectors/invalidation/host-context-pseudo-class-in-has.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/host-context-pseudo-class-in-has.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/host-context-pseudo-class-in-has.html)
- [host-has-shadow-tree-element-at-nonsubject-position.html](https://wpt.fyi/results/css/selectors/invalidation/host-has-shadow-tree-element-at-nonsubject-position.html "css/selectors/invalidation/host-has-shadow-tree-element-at-nonsubject-position.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/host-has-shadow-tree-element-at-nonsubject-position.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/host-has-shadow-tree-element-at-nonsubject-position.html)
- [host-has-shadow-tree-element-at-subject-position.html](https://wpt.fyi/results/css/selectors/invalidation/host-has-shadow-tree-element-at-subject-position.html "css/selectors/invalidation/host-has-shadow-tree-element-at-subject-position.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/host-has-shadow-tree-element-at-subject-position.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/host-has-shadow-tree-element-at-subject-position.html)
- [host-pseudo-class-in-has.html](https://wpt.fyi/results/css/selectors/invalidation/host-pseudo-class-in-has.html "css/selectors/invalidation/host-pseudo-class-in-has.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/host-pseudo-class-in-has.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/host-pseudo-class-in-has.html)
- [input-pseudo-classes-in-has.html](https://wpt.fyi/results/css/selectors/invalidation/input-pseudo-classes-in-has.html "css/selectors/invalidation/input-pseudo-classes-in-has.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/input-pseudo-classes-in-has.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/input-pseudo-classes-in-has.html)
- [input-in-range-in-has-with-readonly.html](https://wpt.fyi/results/css/selectors/invalidation/input-in-range-in-has-with-readonly.html "css/selectors/invalidation/input-in-range-in-has-with-readonly.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/input-in-range-in-has-with-readonly.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/input-in-range-in-has-with-readonly.html)
- [is-pseudo-containing-complex-in-has.html](https://wpt.fyi/results/css/selectors/invalidation/is-pseudo-containing-complex-in-has.html "css/selectors/invalidation/is-pseudo-containing-complex-in-has.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/is-pseudo-containing-complex-in-has.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/is-pseudo-containing-complex-in-has.html)
- [is-pseudo-containing-sibling-relationship-in-has.html](https://wpt.fyi/results/css/selectors/invalidation/is-pseudo-containing-sibling-relationship-in-has.html "css/selectors/invalidation/is-pseudo-containing-sibling-relationship-in-has.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/is-pseudo-containing-sibling-relationship-in-has.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/is-pseudo-containing-sibling-relationship-in-has.html)
- [lang-pseudo-class-in-has-document-element.html](https://wpt.fyi/results/css/selectors/invalidation/lang-pseudo-class-in-has-document-element.html "css/selectors/invalidation/lang-pseudo-class-in-has-document-element.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/lang-pseudo-class-in-has-document-element.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/lang-pseudo-class-in-has-document-element.html)
- [lang-pseudo-class-in-has-multiple-document-elements.html](https://wpt.fyi/results/css/selectors/invalidation/lang-pseudo-class-in-has-multiple-document-elements.html "css/selectors/invalidation/lang-pseudo-class-in-has-multiple-document-elements.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/lang-pseudo-class-in-has-multiple-document-elements.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/lang-pseudo-class-in-has-multiple-document-elements.html)
- [lang-pseudo-class-in-has-xhtml.xhtml](https://wpt.fyi/results/css/selectors/invalidation/lang-pseudo-class-in-has-xhtml.xhtml "css/selectors/invalidation/lang-pseudo-class-in-has-xhtml.xhtml")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/lang-pseudo-class-in-has-xhtml.xhtml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/lang-pseudo-class-in-has-xhtml.xhtml)
- [lang-pseudo-class-in-has.html](https://wpt.fyi/results/css/selectors/invalidation/lang-pseudo-class-in-has.html "css/selectors/invalidation/lang-pseudo-class-in-has.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/lang-pseudo-class-in-has.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/lang-pseudo-class-in-has.html)
- [link-pseudo-class-in-has.html](https://wpt.fyi/results/css/selectors/invalidation/link-pseudo-class-in-has.html "css/selectors/invalidation/link-pseudo-class-in-has.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/link-pseudo-class-in-has.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/link-pseudo-class-in-has.html)
- [link-pseudo-in-has.html](https://wpt.fyi/results/css/selectors/invalidation/link-pseudo-in-has.html "css/selectors/invalidation/link-pseudo-in-has.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/link-pseudo-in-has.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/link-pseudo-in-has.html)
- [location-pseudo-classes-in-has.html](https://wpt.fyi/results/css/selectors/invalidation/location-pseudo-classes-in-has.html "css/selectors/invalidation/location-pseudo-classes-in-has.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/location-pseudo-classes-in-has.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/location-pseudo-classes-in-has.html)
- [media-loading-pseudo-classes-in-has.sub.html](https://wpt.fyi/results/css/selectors/invalidation/media-loading-pseudo-classes-in-has.sub.html "css/selectors/invalidation/media-loading-pseudo-classes-in-has.sub.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/media-loading-pseudo-classes-in-has.sub.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/media-loading-pseudo-classes-in-has.sub.html)
- [media-pseudo-classes-in-has.html](https://wpt.fyi/results/css/selectors/invalidation/media-pseudo-classes-in-has.html "css/selectors/invalidation/media-pseudo-classes-in-has.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/media-pseudo-classes-in-has.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/media-pseudo-classes-in-has.html)
- [modal-pseudo-class-in-has.html](https://wpt.fyi/results/css/selectors/invalidation/modal-pseudo-class-in-has.html "css/selectors/invalidation/modal-pseudo-class-in-has.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/modal-pseudo-class-in-has.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/modal-pseudo-class-in-has.html)
- [negated-has-in-nonsubject-position.html](https://wpt.fyi/results/css/selectors/invalidation/negated-has-in-nonsubject-position.html "css/selectors/invalidation/negated-has-in-nonsubject-position.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/negated-has-in-nonsubject-position.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/negated-has-in-nonsubject-position.html)
- [not-pseudo-containing-complex-in-has.html](https://wpt.fyi/results/css/selectors/invalidation/not-pseudo-containing-complex-in-has.html "css/selectors/invalidation/not-pseudo-containing-complex-in-has.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/not-pseudo-containing-complex-in-has.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/not-pseudo-containing-complex-in-has.html)
- [not-pseudo-containing-sibling-relationship-in-has.html](https://wpt.fyi/results/css/selectors/invalidation/not-pseudo-containing-sibling-relationship-in-has.html "css/selectors/invalidation/not-pseudo-containing-sibling-relationship-in-has.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/not-pseudo-containing-sibling-relationship-in-has.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/not-pseudo-containing-sibling-relationship-in-has.html)
- [open-pseudo-class-in-has.html](https://wpt.fyi/results/css/selectors/invalidation/open-pseudo-class-in-has.html "css/selectors/invalidation/open-pseudo-class-in-has.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/open-pseudo-class-in-has.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/open-pseudo-class-in-has.html)
- [state-in-has.html](https://wpt.fyi/results/css/selectors/invalidation/state-in-has.html "css/selectors/invalidation/state-in-has.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/state-in-has.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/state-in-has.html)
- [subject-has-invalidation-with-display-none-anchor-element.html](https://wpt.fyi/results/css/selectors/invalidation/subject-has-invalidation-with-display-none-anchor-element.html "css/selectors/invalidation/subject-has-invalidation-with-display-none-anchor-element.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/subject-has-invalidation-with-display-none-anchor-element.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/subject-has-invalidation-with-display-none-anchor-element.html)
- [target-pseudo-in-has.html](https://wpt.fyi/results/css/selectors/invalidation/target-pseudo-in-has.html "css/selectors/invalidation/target-pseudo-in-has.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/target-pseudo-in-has.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/target-pseudo-in-has.html)
- [typed-child-indexed-pseudo-classes-in-has.html](https://wpt.fyi/results/css/selectors/invalidation/typed-child-indexed-pseudo-classes-in-has.html "css/selectors/invalidation/typed-child-indexed-pseudo-classes-in-has.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/typed-child-indexed-pseudo-classes-in-has.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/typed-child-indexed-pseudo-classes-in-has.html)
- [user-action-pseudo-classes-in-has.html](https://wpt.fyi/results/css/selectors/invalidation/user-action-pseudo-classes-in-has.html "css/selectors/invalidation/user-action-pseudo-classes-in-has.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/user-action-pseudo-classes-in-has.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/user-action-pseudo-classes-in-has.html)
- [parse-has-disallow-nesting-has-inside-has.html](https://wpt.fyi/results/css/selectors/parsing/parse-has-disallow-nesting-has-inside-has.html "css/selectors/parsing/parse-has-disallow-nesting-has-inside-has.html")
 [[(live
 test)]](http://wpt.live/css/selectors/parsing/parse-has-disallow-nesting-has-inside-has.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/parsing/parse-has-disallow-nesting-has-inside-has.html)
- [parse-has-forgiving-selector.html](https://wpt.fyi/results/css/selectors/parsing/parse-has-forgiving-selector.html "css/selectors/parsing/parse-has-forgiving-selector.html")
 [[(live
 test)]](http://wpt.live/css/selectors/parsing/parse-has-forgiving-selector.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/parsing/parse-has-forgiving-selector.html)
- [parse-has.html](https://wpt.fyi/results/css/selectors/parsing/parse-has.html "css/selectors/parsing/parse-has.html")
 [[(live
 test)]](http://wpt.live/css/selectors/parsing/parse-has.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/parsing/parse-has.html)

The relational pseudo-class, [:has()], is a functional pseudo-class taking a
[\<relative-selector-list\>](#typedef-relative-selector-list) as an argument. It represents an
element if any of the [relative
selectors](#relative-selector) would match at least one element when [anchored
against](#relative-selector-anchor-elements) this element.

The [:has()](#has-pseudo)
pseudo-class cannot be nested; [:has()] is
not valid within [:has()]. Also, unless
explicitly defined as a [:has-allowed
pseudo-element],
[pseudo-elements](#pseudo-element) are not valid selectors within
[:has()]. (This specification does not define
any [:has-allowed
pseudo-elements](#has-allowed-pseudo-element), but other specifications may do so.)

 Pseudo-elements are generally excluded from
[:has()](#has-pseudo)
because many of them exist conditionally, based on the styling of their
ancestors, so allowing these to be queried by
[:has()] would introduce cycles.

 Since [:has()](#has-pseudo) takes a
[\<relative-selector-list\>](#typedef-relative-selector-list), its arguments are *inherently*
[complex selectors](#complex)
(because they start, perhaps implicitly, with a combinator). This means
[:has()] cannot be used in contexts that
don't allow complex selectors; its arguments will be guaranteed to be
invalid.

For example, the following selector
matches only `<a>` elements that contain an `<img>` child:

 a:has(> img)

The following selector matches a `<dt>` element immediately followed by
another `<dt>` element:

 dt:has(+ dt)

The following selector matches `<section>` elements that don't contain
any heading elements:

 section:not(:has(h1, h2, h3, h4, h5, h6))

Note that ordering matters in the above selector. Swapping the nesting
of the two pseudo-classes, like:

 section:has(:not(h1, h2, h3, h4, h5, h6))

\...would result in matching any `<section>` element which contains
anything that's not a heading element.

## 5. Elemental selectors

### 5.1. Type (tag name) selector

A [type selector] is the name of a document language element type, and
represents an instance of that element type in the document tree.

For example, the selector [h1]
represents an
[h1](https://html.spec.whatwg.org/multipage/sections.html#the-h1-element) element in the document.

A [type selector](#type-selector) is written as a [CSS qualified
name](https://drafts.csswg.org/css-namespaces-3/#css-qualified-name): an
[identifier](https://drafts.csswg.org/css-values-4/#css-css-identifier) with an optional namespace prefix.
[\[CSS3NAMESPACE\]](#biblio-css3namespace "CSS Namespaces Module Level 3")
(See [§ 5.3 Namespaces in Elemental Selectors](#type-nmsp).)

### 5.2. Universal selector

Tests

- [parse-universal.html](https://wpt.fyi/results/css/selectors/parsing/parse-universal.html "css/selectors/parsing/parse-universal.html")
 [[(live
 test)]](http://wpt.live/css/selectors/parsing/parse-universal.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/parsing/parse-universal.html)

The [universal selector] is a special [type
selector](#type-selector), that
represents an element of any element type.

It is written as a [CSS qualified
name](https://drafts.csswg.org/css-namespaces-3/#css-qualified-name) with an asterisk (`*` U+002A) as the local name. Like a
[type selector](#type-selector), the [universal
selector](#universal-selector) can be qualified by a namespace, restricting it to only
elements belonging to that namespace, and is affected by a default
namespace as defined in [§ 5.3 Namespaces in Elemental
Selectors](#type-nmsp).

Unless an element is [featureless](#featureless), the presence of a [universal
selector](#universal-selector) has no effect on whether the element matches the
selector. ([Featureless] elements do not match
any selector, including the [universal
selector].)

- [\*\[hreflang\|=en\]] and [\[hreflang\|=en\]] are
 equivalent,
- [\*.warning] and [.warning] are equivalent,
- [\*#myid] and [#myid] are equivalent.

The [universal
selector](#universal-selector) follows the same syntax rules as other [type
selectors](#type-selector):
only one can appear per [compound
selector](#compound), and it must
be the first [simple selector](#simple) in the [compound selector].

 In some cases, adding a [universal
selector](#universal-selector) can make a selector easier to read, even though it has
no effect on the matching behavior. For example, [div
:first-child] and [div:first-child] are somewhat difficult
to tell apart at a quick glance, but writing the former as [div
\*:first-child] makes the difference obvious.

### 5.3. Namespaces in Elemental Selectors

[Type selectors](#type-selector) and [universal
selectors](#universal-selector) allow an optional namespace component: a namespace
prefix that has been previously [declared](#nsdecl) may
be prepended to the element name separated by the namespace separator
"vertical bar" (`|` U+007C). (See, e.g.,
[\[XML-NAMES\]](#biblio-xml-names "Namespaces in XML 1.0 (Third Edition)")
for the use of namespaces in XML.) It has the following meaning in each
form:

`ns|E`
: elements with name E in namespace ns

`*|E`
: elements with name E in any namespace, including those without a
 namespace

`|E`
: elements with name E without a namespace

`E`
: if no default namespace has been
 [declared](#nsdecl) for selectors, this is
 equivalent to \*\|E. Otherwise it is equivalent to ns\|E where ns is
 the default namespace.

CSS examples:

 @namespace foo url(http://www.example.com);
 foo|h1 { color: blue } /* first rule */
 foo|* { color: yellow } /* second rule */
 |h1 { color: red } /* ...*/
 *|h1 { color: green }
 h1 { color: green }

The first rule (not counting the
[\@namespace](https://drafts.csswg.org/css-namespaces-3/#at-ruledef-namespace) at-rule) will match only
[h1](https://html.spec.whatwg.org/multipage/sections.html#the-h1-element) elements in the \"http://www.example.com\"
namespace.

The second rule will match all elements in the
\"http://www.example.com\" namespace.

The third rule will match only
[h1](https://html.spec.whatwg.org/multipage/sections.html#the-h1-element) elements with no namespace.

The fourth rule will match
[h1](https://html.spec.whatwg.org/multipage/sections.html#the-h1-element) elements in any namespace (including those without
any namespace).

The last rule is equivalent to the fourth rule because no default
namespace has been defined.

If a [default
namespace](https://drafts.csswg.org/css-namespaces-3/#default-namespace) is declared, [compound
selectors](#compound) without [type
selectors](#type-selector) in
them still only match elements in that default namespace.

For example, in the following style
sheet:

 @namespace url("http://example.com/foo");

 .special { ... }

The [.special] selector only matches elements in the
\"http://example.com/foo\" namespace, even though no reference to the
type name (which is paired with the namespace in the DOM) appeared.

A [type selector](#type-selector) or [universal
selector](#universal-selector) containing a namespace prefix that has not been
previously [declared](#nsdecl) is an [invalid
selector](#invalid-selector).

### 5.4. The Defined Pseudo-class: [:defined]
Tests

- [defined.html](https://wpt.fyi/results/css/selectors/invalidation/defined.html "css/selectors/invalidation/defined.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/defined.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/defined.html)

In some host languages, elements can have a distinction between being
"defined"/"constructed" or not. The [:defined]
[pseudo-class](#pseudo-class)
matches elements that are fully defined, as dictated by the host
language.

If the host language does not have this sort of distinction, all
elements in it match
[:defined](#defined-pseudo).

In HTML, all built-in elements are
always considered to be defined, so the following example will always
match:

``` highlight
p:defined { ... }
```

[Custom
elements](https://html.spec.whatwg.org/multipage/custom-elements.html#custom-element), on the other hand, start out *un*defined, and only
become defined when [properly
registered](https://html.spec.whatwg.org/multipage/custom-elements.html#element-definition). This means the
[:defined](#defined-pseudo) pseudo-class can be used to hide a custom element
until it has been registered:

 custom-element { visibility: hidden }

 custom-element:defined { visibility: visible }

## 6. Attribute selectors

Tests

- [style-attribute-selector.html](https://wpt.fyi/results/css/selectors/attribute-selectors/style-attribute-selector.html "css/selectors/attribute-selectors/style-attribute-selector.html")
 [[(live
 test)]](http://wpt.live/css/selectors/attribute-selectors/style-attribute-selector.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/attribute-selectors/style-attribute-selector.html)
- [attribute.html](https://wpt.fyi/results/css/selectors/invalidation/attribute.html "css/selectors/invalidation/attribute.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/attribute.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/attribute.html)
- [class-id-attr.html](https://wpt.fyi/results/css/selectors/invalidation/class-id-attr.html "css/selectors/invalidation/class-id-attr.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/class-id-attr.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/class-id-attr.html)
- [missing-right-token.html](https://wpt.fyi/results/css/selectors/missing-right-token.html "css/selectors/missing-right-token.html")
 [[(live
 test)]](http://wpt.live/css/selectors/missing-right-token.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/missing-right-token.html)
- [parse-attribute.html](https://wpt.fyi/results/css/selectors/parsing/parse-attribute.html "css/selectors/parsing/parse-attribute.html")
 [[(live
 test)]](http://wpt.live/css/selectors/parsing/parse-attribute.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/parsing/parse-attribute.html)
- [selectors-attr-many.html](https://wpt.fyi/results/css/selectors/selectors-attr-many.html "css/selectors/selectors-attr-many.html")
 [[(live
 test)]](http://wpt.live/css/selectors/selectors-attr-many.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/selectors-attr-many.html)
- [selectors-attr-many-2.html](https://wpt.fyi/results/css/selectors/selectors-attr-many-2.html "css/selectors/selectors-attr-many-2.html")
 [[(live
 test)]](http://wpt.live/css/selectors/selectors-attr-many-2.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/selectors-attr-many-2.html)

Selectors allow the representation of an element's attributes. When a
selector is used as an expression to match against an element, an
[attribute selector] must be considered to match an element if that
element has an attribute that matches the attribute represented by the
attribute selector.

Add comma-separated syntax for
[multiple-value
matching](http://lists.w3.org/Archives/Public/www-style/2011Mar/0215.html)?
e.g. \[rel \~= next, prev, up, first, last\]

### 6.1. Attribute presence and value selectors

CSS2 introduced four attribute selectors:

[\[att\]]
: Represents an element with the `att` attribute, whatever the value
 of the attribute.

[\[att=val\]]
: Represents an element with the `att` attribute whose value is
 exactly \"val\".

[\[att\~=val\]]
: Represents an element with the `att` attribute whose value is a
 [whitespace](#whitespace)-separated list of
 words, one of which is exactly \"val\". If \"val\" contains
 whitespace, it will never represent anything (since the words are
 *separated* by spaces). Also if \"val\" is the empty string, it will
 never represent anything.

[\[att\|=val\]]
: Represents an element with the `att` attribute, its value either
 being exactly \"val\" or beginning with \"val\" immediately followed
 by \"-\" (U+002D). This is primarily intended to allow language
 subcode matches (e.g., the `hreflang` attribute on the
 [a](https://html.spec.whatwg.org/multipage/text-level-semantics.html#the-a-element) element in HTML) as described in BCP 47
 ([\[BCP47\]](#biblio-bcp47 "Tags for Identifying Languages")).
 For `lang` (or `xml:lang`) language subcode matching, please see the
 [:lang()](#lang-pseudo) pseudo-class.

Attribute values must be
[\<ident-token\>](https://drafts.csswg.org/css-syntax-3/#typedef-ident-token)s or
[\<string-token\>](https://drafts.csswg.org/css-syntax-3/#typedef-string-token)s.
[\[CSS3SYN\]](#biblio-css3syn "CSS Syntax Module Level 3")

Examples:

The following attribute selector represents an
[h1](https://html.spec.whatwg.org/multipage/sections.html#the-h1-element) element that carries the `title` attribute,
whatever its value:

 h1[title]

In the following example, the selector represents a
[span](https://html.spec.whatwg.org/multipage/text-level-semantics.html#the-span-element) element whose `class` attribute has exactly the
value \"example\":

 span[class="example"]

Multiple attribute selectors can be used to represent several attributes
of an element, or several conditions on the same attribute. Here, the
selector represents a
[span](https://html.spec.whatwg.org/multipage/text-level-semantics.html#the-span-element) element whose `hello` attribute has exactly the
value \"Cleveland\" and whose `goodbye` attribute has exactly the value
\"Columbus\":

 span[hello="Cleveland"][goodbye="Columbus"]

The following CSS rules illustrate the differences between \"=\" and
\"\~=\". The first selector would match, for example, an
[a](https://html.spec.whatwg.org/multipage/text-level-semantics.html#the-a-element) element with the value \"copyright copyleft
copyeditor\" on a `rel` attribute. The second selector would only match
an [a] element with an `href` attribute having
the exact value \"http://www.w3.org/\".

 a[rel~="copyright"] { ... }
 a[href="http://www.w3.org/"] { ... }

The following selector represents an
[a](https://html.spec.whatwg.org/multipage/text-level-semantics.html#the-a-element) element whose `hreflang` attribute is exactly
\"fr\".

 a[hreflang=fr]

The following selector represents an
[a](https://html.spec.whatwg.org/multipage/text-level-semantics.html#the-a-element) element for which the value of the `hreflang`
attribute begins with \"en\", including \"en\", \"en-US\", and
\"en-scouse\":

 a[hreflang|="en"]

The following selectors represent a [DIALOGUE]
element whenever it has one of two different values for an attribute
`character`:

 DIALOGUE[character=romeo]
 DIALOGUE[character=juliet]

### 6.2. Substring matching attribute selectors

Three additional attribute selectors are provided for matching
substrings in the value of an attribute:

[\[att\^=val\]]
: Represents an element with the `att` attribute whose value begins
 with the prefix \"val\". If \"val\" is the empty string then the
 selector does not represent anything.

[\[att\$=val\]]
: Represents an element with the `att` attribute whose value ends with
 the suffix \"val\". If \"val\" is the empty string then the selector
 does not represent anything.

[\[att\*=val\]]
: Represents an element with the `att` attribute whose value contains
 at least one instance of the substring \"val\". If \"val\" is the
 empty string then the selector does not represent anything.

Attribute values must be
[\<ident-token\>](https://drafts.csswg.org/css-syntax-3/#typedef-ident-token)s or
[\<string-token\>](https://drafts.csswg.org/css-syntax-3/#typedef-string-token)s.

Examples: The following selector
represents an HTML
[object](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-object-element) element, referencing an image:

 object[type^="image/"]

The following selector represents an HTML
[a](https://html.spec.whatwg.org/multipage/text-level-semantics.html#the-a-element) element with an `href` attribute whose value ends
with \".html\".

 a[href$=".html"]

The following selector represents an HTML paragraph with a `title`
attribute whose value contains the substring \"hello\"

 p[title*="hello"]

### 6.3. Case-sensitivity

Tests

- [cssom.html](https://wpt.fyi/results/css/selectors/attribute-selectors/attribute-case/cssom.html "css/selectors/attribute-selectors/attribute-case/cssom.html")
 [[(live
 test)]](http://wpt.live/css/selectors/attribute-selectors/attribute-case/cssom.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/attribute-selectors/attribute-case/cssom.html)
- [semantics.html](https://wpt.fyi/results/css/selectors/attribute-selectors/attribute-case/semantics.html "css/selectors/attribute-selectors/attribute-case/semantics.html")
 [[(live
 test)]](http://wpt.live/css/selectors/attribute-selectors/attribute-case/semantics.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/attribute-selectors/attribute-case/semantics.html)
- [syntax.html](https://wpt.fyi/results/css/selectors/attribute-selectors/attribute-case/syntax.html "css/selectors/attribute-selectors/attribute-case/syntax.html")
 [[(live
 test)]](http://wpt.live/css/selectors/attribute-selectors/attribute-case/syntax.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/attribute-selectors/attribute-case/syntax.html)

By default case-sensitivity of attribute names and values in selectors
depends on the document language.

To match attribute values [ASCII
case-insensitively](https://infra.spec.whatwg.org/#ascii-case-insensitive) regardless of document language rules, the attribute
selector may include the identifier [i] before the closing bracket (`]`). When this flag is present,
UAs must match the attribute's value [ASCII
case-insensitively] (i.e. \[a-z\] and
\[A-Z\] are considered equivalent).

For example, ASCII case insensitivity
allows `green` to match `GREEN`. However, `grün` would not match `GRÜN`.

Alternately, the attribute selector may include the identifier
[s] before the
closing bracket (`]`); in this case the UA must match the value
case-sensitively, with "[identical
to](https://infra.spec.whatwg.org/#is)"
semantics
[\[INFRA\]](#biblio-infra "Infra Standard"),
regardless of document language rules.

Like the rest of Selectors syntax, the `i` and `s` identifiers
themselves are [ASCII
case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive).

The following rule will style the
`frame` attribute when it has a value of `hsides`, whether that value is
represented as `hsides`, `HSIDES`, `hSides`, etc. even in an XML
environment where attribute values are case-sensitive.

 [frame=hsides i] { border-style: solid none; }

The following rule will style lists
with `type="a"` attributes differently than `type="A"` even though HTML
defines the `type` attribute to be case-insensitive.

 [type="a" s] { list-style: lower-alpha; }
 [type="A" s] { list-style: upper-alpha; }

 Some document models normalize case-insensitive
attribute values at parse time such that checking if a string is
case-sensitive matching is impossible. Case-sensitive matching via `s`
flags is only possible in systems that preserve the original case.

### 6.4. Attribute selectors and namespaces

Tests

- [selectors-namespace-001.xml](https://wpt.fyi/results/css/selectors/selectors-namespace-001.xml "css/selectors/selectors-namespace-001.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/selectors-namespace-001.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/selectors-namespace-001.xml)

The attribute name in an attribute selector is given as a [CSS qualified
name](https://drafts.csswg.org/css-namespaces-3/#css-qualified-name): a namespace prefix that has been previously
[declared](#nsdecl) may be prepended
to the attribute name separated by the namespace separator \"vertical
bar\" (`|`). In keeping with the Namespaces in the XML recommendation,
default namespaces do not apply to attributes, therefore attribute
selectors without a namespace component apply only to attributes that
have no namespace (equivalent to [\|attr]). An asterisk may be
used for the namespace prefix indicating that the selector is to match
all attribute names without regard to the attribute's namespace.

An attribute selector with an attribute name containing a namespace
prefix that has not been previously [declared](#nsdecl) is an invalid selector.

CSS examples:

 @namespace foo "http://www.example.com";
 [foo|att=val] { color: blue }
 [*|att] { color: yellow }
 [|att] { color: green }
 [att] { color: green }

The first rule will match only elements with the attribute `att` in the
\"http://www.example.com\" namespace with the value \"val\".

The second rule will match only elements with the attribute `att`
regardless of the namespace of the attribute (including no namespace).

The last two rules are equivalent and will match only elements with the
attribute `att` where the attribute is not in a namespace.

### 6.5. Default attribute values in DTDs

Attribute selectors represent attribute values in the document tree. How
that document tree is constructed is outside the scope of Selectors. In
some document formats default attribute values can be defined in a DTD
or elsewhere, but these can only be selected by attribute selectors if
they appear in the document tree. Selectors should be designed so that
they work whether or not the default values are included in the document
tree.

For example, a XML UA may, but is *not* required to, read an "external
subset" of the DTD, but *is* required to look for default attribute
values in the document's "internal subset". (See, e.g.,
[\[XML10\]](#biblio-xml10 "Extensible Markup Language (XML) 1.0 (Fifth Edition)")
for definitions of these subsets.) Depending on the UA, a default
attribute value defined in the external subset of the DTD might or might
not appear in the document tree.

A UA that recognizes an XML namespace may, but is not required to use
its knowledge of that namespace to treat default attribute values as if
they were present in the document. (For example, an XHTML UA is not
required to use its built-in knowledge of the XHTML DTD. See, e.g.,
[\[XML-NAMES\]](#biblio-xml-names "Namespaces in XML 1.0 (Third Edition)")
for details on namespaces in XML 1.0.)

 Typically, implementations choose to ignore external
subsets. This corresponds to the behavior of non-validating processors
as defined by the XML specification.

Example:

Consider an element `EXAMPLE` with an attribute `radix` that has a
default value of `"decimal"`. The DTD fragment might be

``` dtd-example
<!ATTLIST EXAMPLE radix (decimal,octal) "decimal">
```

If the style sheet contains the rules

 EXAMPLE[radix=decimal] { /*... default property settings ...*/ }
 EXAMPLE[radix=octal] { /*... other settings...*/ }

the first rule might not match elements whose `radix` attribute is set
by default, i.e. not set explicitly. To catch all cases, the attribute
selector for the default value must be dropped:

 EXAMPLE { /*... default property settings ...*/ }
 EXAMPLE[radix=octal] { /*... other settings...*/ }

Here, because the selector [EXAMPLE\[radix=octal\]] is more
specific than the type selector alone, the style declarations in the
second rule will override those in the first for elements that have a
`radix` attribute value of `"octal"`. Care has to be taken that all
property declarations that are to apply only to the default case are
overridden in the non-default cases\' style rules.

### 6.6. Class selectors

Tests

- [parse-class.html](https://wpt.fyi/results/css/selectors/parsing/parse-class.html "css/selectors/parsing/parse-class.html")
 [[(live
 test)]](http://wpt.live/css/selectors/parsing/parse-class.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/parsing/parse-class.html)
- [xml-class-selector.xml](https://wpt.fyi/results/css/selectors/xml-class-selector.xml "css/selectors/xml-class-selector.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/xml-class-selector.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/xml-class-selector.xml)

The [class selector] is given as a full stop (. U+002E) immediately followed by an
identifier. It represents an element belonging to the class identified
by the identifier, as defined by the document language. For example, in
[\[HTML\]](#biblio-html "HTML Standard"),
[\[SVG11\]](#biblio-svg11 "Scalable Vector Graphics (SVG) 1.1 (Second Edition)"),
and
[\[MATHML\]](#biblio-mathml "Mathematical Markup Language (MathML™) 1.01 Specification")
membership in a class is given by the `class` attribute: in these
languages it is equivalent to the `~=` notation applied to the local
`class` attribute (i.e. `[class~=``identifier``]`).

CSS examples:

We can assign style information to all elements with `class~="pastoral"`
as follows:

 *.pastoral { color: green } /* all elements with class~=pastoral */

or just

 .pastoral { color: green } /* all elements with class~=pastoral */

The following assigns style only to H1 elements with
`class~="pastoral"`:

 H1.pastoral { color: green } /* H1 elements with class~=pastoral */

Given these rules, the first `H1` instance below would not have green
text, while the second would:

 <H1>Not green</H1>
 <H1 class="pastoral">Very green</H1>

The following rule matches any
[P](https://html.spec.whatwg.org/multipage/grouping-content.html#the-p-element) element whose `class` attribute has been assigned a
list of [whitespace](#whitespace)-separated values
that includes both `pastoral` and `marine`:

 p.pastoral.marine { color: green }

This rule matches when `class="pastoral blue aqua marine"` but does not
match for `class="pastoral blue"`.

 Because CSS gives considerable power to the \"class\"
attribute, authors could conceivably design their own \"document
language\" based on elements with almost no associated presentation
(such as
[div](https://html.spec.whatwg.org/multipage/grouping-content.html#the-div-element) and
[span](https://html.spec.whatwg.org/multipage/text-level-semantics.html#the-span-element) in HTML) and assigning style information through
the \"class\" attribute. Authors should avoid this practice since the
structural elements of a document language often have recognized and
accepted meanings and author-defined classes may not.

 If an element has multiple class attributes, their
values must be concatenated with spaces between the values before
searching for the class. As of this time the working group is not aware
of any manner in which this situation can be reached, however, so this
behavior is explicitly non-normative in this specification.

When matching against a document which is in [quirks
mode](https://dom.spec.whatwg.org/#concept-document-quirks), class names must be matched [ASCII
case-insensitively](https://infra.spec.whatwg.org/#ascii-case-insensitive); class selectors are otherwise case-sensitive, only
matching class names they are [identical
to](https://infra.spec.whatwg.org/#is).
[\[INFRA\]](#biblio-infra "Infra Standard")

### 6.7. ID selectors

Tests

- [historical-xmlid.xht](https://wpt.fyi/results/css/selectors/historical-xmlid.xht "css/selectors/historical-xmlid.xht")
 [[(live
 test)]](http://wpt.live/css/selectors/historical-xmlid.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/historical-xmlid.xht)
- [parse-id.html](https://wpt.fyi/results/css/selectors/parsing/parse-id.html "css/selectors/parsing/parse-id.html")
 [[(live
 test)]](http://wpt.live/css/selectors/parsing/parse-id.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/parsing/parse-id.html)

Document languages may contain attributes that are declared to be of
type ID. What makes attributes of type ID special is that no two such
attributes can have the same value in a conformant document, regardless
of the type of the elements that carry them; whatever the document
language, an ID typed attribute can be used to uniquely identify its
element. In HTML all ID attributes are named `id`; XML applications may
name ID attributes differently, but the same restriction applies. Which
attribute on an element is considered the "ID attribute" is defined by
the document language.

An [ID selector] consists of a "number sign" (U+0023, `#`) immediately
followed by the ID value, which must be a CSS
[identifier](https://www.w3.org/TR/CSS21/syndata.html#value-def-identifier).
An ID selector represents an element instance that has an identifier
that matches the identifier in the ID selector. (It is possible in
non-conforming documents for multiple elements to match a single ID
selector.)

Examples: The following ID selector
represents an
[h1](https://html.spec.whatwg.org/multipage/sections.html#the-h1-element) element whose ID-typed attribute has the value
\"chapter1\":

 h1#chapter1

The following ID selector represents any element whose ID-typed
attribute has the value \"chapter1\":

 #chapter1

The following selector represents any element whose ID-typed attribute
has the value \"z98y\".

 *#z98y

 In XML 1.0
[\[XML10\]](#biblio-xml10 "Extensible Markup Language (XML) 1.0 (Fifth Edition)"),
the information about which attribute contains an element's IDs is
contained in a DTD or a schema. When parsing XML, UAs do not always read
the DTD, and thus may not know what the ID of an element is (though a UA
may have namespace-specific knowledge that allows it to determine which
attribute is the ID attribute for that namespace). If a style sheet
author knows or suspects that a UA may not know what the ID of an
element is, they should use normal attribute selectors instead:
[\[name=p371\]] instead of [#p371].

If an element has multiple ID attributes, all of them must be treated as
IDs for that element for the purposes of the ID selector. Such a
situation could be reached using mixtures of xml:id, DOM3 Core, XML
DTDs, and namespace-specific knowledge.

When matching against a document which is in [quirks
mode](https://dom.spec.whatwg.org/#concept-document-quirks), IDs must be matched [ASCII
case-insensitively](https://infra.spec.whatwg.org/#ascii-case-insensitive); ID selectors are otherwise case-sensitive, only
matching IDs they are [identical
to](https://infra.spec.whatwg.org/#is).
[\[INFRA\]](#biblio-infra "Infra Standard")

## 7. Linguistic Pseudo-classes

### 7.1. The Directionality Pseudo-class: [:dir()]
Tests

- [dir-pseudo-in-has.html](https://wpt.fyi/results/css/selectors/dir-pseudo-in-has.html "css/selectors/dir-pseudo-in-has.html")
 [[(live
 test)]](http://wpt.live/css/selectors/dir-pseudo-in-has.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/dir-pseudo-in-has.html)
- [dir-pseudo-on-bdi-element.html](https://wpt.fyi/results/css/selectors/dir-pseudo-on-bdi-element.html "css/selectors/dir-pseudo-on-bdi-element.html")
 [[(live
 test)]](http://wpt.live/css/selectors/dir-pseudo-on-bdi-element.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/dir-pseudo-on-bdi-element.html)
- [dir-pseudo-on-input-element.html](https://wpt.fyi/results/css/selectors/dir-pseudo-on-input-element.html "css/selectors/dir-pseudo-on-input-element.html")
 [[(live
 test)]](http://wpt.live/css/selectors/dir-pseudo-on-input-element.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/dir-pseudo-on-input-element.html)
- [dir-pseudo-update-document-element.html](https://wpt.fyi/results/css/selectors/dir-pseudo-update-document-element.html "css/selectors/dir-pseudo-update-document-element.html")
 [[(live
 test)]](http://wpt.live/css/selectors/dir-pseudo-update-document-element.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/dir-pseudo-update-document-element.html)
- [dir-selector-auto-direction-change-001.html](https://wpt.fyi/results/css/selectors/dir-selector-auto-direction-change-001.html "css/selectors/dir-selector-auto-direction-change-001.html")
 [[(live
 test)]](http://wpt.live/css/selectors/dir-selector-auto-direction-change-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/dir-selector-auto-direction-change-001.html)
- [dir-selector-auto.html](https://wpt.fyi/results/css/selectors/dir-selector-auto.html "css/selectors/dir-selector-auto.html")
 [[(live
 test)]](http://wpt.live/css/selectors/dir-selector-auto.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/dir-selector-auto.html)
- [dir-selector-change-001.html](https://wpt.fyi/results/css/selectors/dir-selector-change-001.html "css/selectors/dir-selector-change-001.html")
 [[(live
 test)]](http://wpt.live/css/selectors/dir-selector-change-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/dir-selector-change-001.html)
- [dir-selector-change-002.html](https://wpt.fyi/results/css/selectors/dir-selector-change-002.html "css/selectors/dir-selector-change-002.html")
 [[(live
 test)]](http://wpt.live/css/selectors/dir-selector-change-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/dir-selector-change-002.html)
- [dir-selector-change-003.html](https://wpt.fyi/results/css/selectors/dir-selector-change-003.html "css/selectors/dir-selector-change-003.html")
 [[(live
 test)]](http://wpt.live/css/selectors/dir-selector-change-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/dir-selector-change-003.html)
- [dir-selector-change-004.html](https://wpt.fyi/results/css/selectors/dir-selector-change-004.html "css/selectors/dir-selector-change-004.html")
 [[(live
 test)]](http://wpt.live/css/selectors/dir-selector-change-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/dir-selector-change-004.html)
- [dir-selector-ltr-001.html](https://wpt.fyi/results/css/selectors/dir-selector-ltr-001.html "css/selectors/dir-selector-ltr-001.html")
 [[(live
 test)]](http://wpt.live/css/selectors/dir-selector-ltr-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/dir-selector-ltr-001.html)
- [dir-selector-ltr-002.html](https://wpt.fyi/results/css/selectors/dir-selector-ltr-002.html "css/selectors/dir-selector-ltr-002.html")
 [[(live
 test)]](http://wpt.live/css/selectors/dir-selector-ltr-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/dir-selector-ltr-002.html)
- [dir-selector-ltr-003.html](https://wpt.fyi/results/css/selectors/dir-selector-ltr-003.html "css/selectors/dir-selector-ltr-003.html")
 [[(live
 test)]](http://wpt.live/css/selectors/dir-selector-ltr-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/dir-selector-ltr-003.html)
- [dir-selector-querySelector.html](https://wpt.fyi/results/css/selectors/dir-selector-querySelector.html "css/selectors/dir-selector-querySelector.html")
 [[(live
 test)]](http://wpt.live/css/selectors/dir-selector-querySelector.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/dir-selector-querySelector.html)
- [dir-selector-rtl-001.html](https://wpt.fyi/results/css/selectors/dir-selector-rtl-001.html "css/selectors/dir-selector-rtl-001.html")
 [[(live
 test)]](http://wpt.live/css/selectors/dir-selector-rtl-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/dir-selector-rtl-001.html)
- [dir-selector-white-space-001.html](https://wpt.fyi/results/css/selectors/dir-selector-white-space-001.html "css/selectors/dir-selector-white-space-001.html")
 [[(live
 test)]](http://wpt.live/css/selectors/dir-selector-white-space-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/dir-selector-white-space-001.html)
- [dir-style-01a.html](https://wpt.fyi/results/css/selectors/dir-style-01a.html "css/selectors/dir-style-01a.html")
 [[(live
 test)]](http://wpt.live/css/selectors/dir-style-01a.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/dir-style-01a.html)
- [dir-style-01b.html](https://wpt.fyi/results/css/selectors/dir-style-01b.html "css/selectors/dir-style-01b.html")
 [[(live
 test)]](http://wpt.live/css/selectors/dir-style-01b.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/dir-style-01b.html)
- [dir-style-02a.html](https://wpt.fyi/results/css/selectors/dir-style-02a.html "css/selectors/dir-style-02a.html")
 [[(live
 test)]](http://wpt.live/css/selectors/dir-style-02a.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/dir-style-02a.html)
- [dir-style-02b.html](https://wpt.fyi/results/css/selectors/dir-style-02b.html "css/selectors/dir-style-02b.html")
 [[(live
 test)]](http://wpt.live/css/selectors/dir-style-02b.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/dir-style-02b.html)
- [dir-style-03a.html](https://wpt.fyi/results/css/selectors/dir-style-03a.html "css/selectors/dir-style-03a.html")
 [[(live
 test)]](http://wpt.live/css/selectors/dir-style-03a.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/dir-style-03a.html)
- [dir-style-03b.html](https://wpt.fyi/results/css/selectors/dir-style-03b.html "css/selectors/dir-style-03b.html")
 [[(live
 test)]](http://wpt.live/css/selectors/dir-style-03b.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/dir-style-03b.html)
- [dir-style-04.html](https://wpt.fyi/results/css/selectors/dir-style-04.html "css/selectors/dir-style-04.html")
 [[(live
 test)]](http://wpt.live/css/selectors/dir-style-04.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/dir-style-04.html)
- [part-dir.html](https://wpt.fyi/results/css/selectors/invalidation/part-dir.html "css/selectors/invalidation/part-dir.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/part-dir.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/part-dir.html)

The [:dir()] pseudo-class allows the author to write selectors that
represent an element based on its directionality as determined by the
[document language](#document-language). For example,
[\[HTML\]](#biblio-html "HTML Standard") defines
[how to determine the directionality of an
element](https://html.spec.whatwg.org/multipage/dom.html#the-directionality),
based on a combination of the `dir` attribute, the surrounding text, and
other factors. As another example, the `its:dir` and `dirRule` element
of the Internationalization Tag Set
[\[ITS20\]](#biblio-its20 "Internationalization Tag Set (ITS) Version 2.0")
are able to define the directionality of an element in
[\[XML10\]](#biblio-xml10 "Extensible Markup Language (XML) 1.0 (Fifth Edition)").

The [:dir()](#dir-pseudo)
pseudo-class does not select based on stylistic states---for example,
the CSS
[direction](https://drafts.csswg.org/css-writing-modes-3/#propdef-direction) property does not affect whether it
matches.

The pseudo-class [:dir(ltr)] represents an element that has a
directionality of left-to-right (`ltr`). The pseudo-class
[:dir(rtl)] represents an element that has a directionality of
right-to-left (`rtl`). The argument to
[:dir()](#dir-pseudo) must
be a single identifier, otherwise the selector is invalid. White space
is optionally allowed between the identifier and the parentheses. Values
other than `ltr` and `rtl` are not invalid, but do not match anything.
(If a future markup spec defines other directionalities, then Selectors
may be extended to allow corresponding values.)

The difference between [:dir(C)] and [\[dir=C\]] is that
[\[dir=C\]] only performs a comparison against a given attribute
on the element, while the [:dir(C)] pseudo-class uses the UAs
knowledge of the document's semantics to perform the comparison. For
example, in HTML, the directionality of an element inherits so that a
child without a `dir` attribute will have the same directionality as its
closest ancestor with a valid `dir` attribute. As another example, in
HTML, an element that matches [\[dir=auto\]] will match either
[:dir(ltr)] or [:dir(rtl)] depending on the resolved
directionality of the elements as determined by its contents.
[\[HTML\]](#biblio-html "HTML Standard")

### 7.2. The Language Pseudo-class: [:lang()]
Tests

- [css3-selectors-lang-001.html](https://wpt.fyi/results/css/selectors/i18n/css3-selectors-lang-001.html "css/selectors/i18n/css3-selectors-lang-001.html")
 [[(live
 test)]](http://wpt.live/css/selectors/i18n/css3-selectors-lang-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/i18n/css3-selectors-lang-001.html)
- [css3-selectors-lang-002.html](https://wpt.fyi/results/css/selectors/i18n/css3-selectors-lang-002.html "css/selectors/i18n/css3-selectors-lang-002.html")
 [[(live
 test)]](http://wpt.live/css/selectors/i18n/css3-selectors-lang-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/i18n/css3-selectors-lang-002.html)
- [css3-selectors-lang-004.html](https://wpt.fyi/results/css/selectors/i18n/css3-selectors-lang-004.html "css/selectors/i18n/css3-selectors-lang-004.html")
 [[(live
 test)]](http://wpt.live/css/selectors/i18n/css3-selectors-lang-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/i18n/css3-selectors-lang-004.html)
- [css3-selectors-lang-005.html](https://wpt.fyi/results/css/selectors/i18n/css3-selectors-lang-005.html "css/selectors/i18n/css3-selectors-lang-005.html")
 [[(live
 test)]](http://wpt.live/css/selectors/i18n/css3-selectors-lang-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/i18n/css3-selectors-lang-005.html)
- [css3-selectors-lang-006.html](https://wpt.fyi/results/css/selectors/i18n/css3-selectors-lang-006.html "css/selectors/i18n/css3-selectors-lang-006.html")
 [[(live
 test)]](http://wpt.live/css/selectors/i18n/css3-selectors-lang-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/i18n/css3-selectors-lang-006.html)
- [css3-selectors-lang-007.html](https://wpt.fyi/results/css/selectors/i18n/css3-selectors-lang-007.html "css/selectors/i18n/css3-selectors-lang-007.html")
 [[(live
 test)]](http://wpt.live/css/selectors/i18n/css3-selectors-lang-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/i18n/css3-selectors-lang-007.html)
- [css3-selectors-lang-008.html](https://wpt.fyi/results/css/selectors/i18n/css3-selectors-lang-008.html "css/selectors/i18n/css3-selectors-lang-008.html")
 [[(live
 test)]](http://wpt.live/css/selectors/i18n/css3-selectors-lang-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/i18n/css3-selectors-lang-008.html)
- [css3-selectors-lang-009.html](https://wpt.fyi/results/css/selectors/i18n/css3-selectors-lang-009.html "css/selectors/i18n/css3-selectors-lang-009.html")
 [[(live
 test)]](http://wpt.live/css/selectors/i18n/css3-selectors-lang-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/i18n/css3-selectors-lang-009.html)
- [css3-selectors-lang-010.html](https://wpt.fyi/results/css/selectors/i18n/css3-selectors-lang-010.html "css/selectors/i18n/css3-selectors-lang-010.html")
 [[(live
 test)]](http://wpt.live/css/selectors/i18n/css3-selectors-lang-010.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/i18n/css3-selectors-lang-010.html)
- [css3-selectors-lang-011.html](https://wpt.fyi/results/css/selectors/i18n/css3-selectors-lang-011.html "css/selectors/i18n/css3-selectors-lang-011.html")
 [[(live
 test)]](http://wpt.live/css/selectors/i18n/css3-selectors-lang-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/i18n/css3-selectors-lang-011.html)
- [css3-selectors-lang-012.html](https://wpt.fyi/results/css/selectors/i18n/css3-selectors-lang-012.html "css/selectors/i18n/css3-selectors-lang-012.html")
 [[(live
 test)]](http://wpt.live/css/selectors/i18n/css3-selectors-lang-012.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/i18n/css3-selectors-lang-012.html)
- [css3-selectors-lang-014.html](https://wpt.fyi/results/css/selectors/i18n/css3-selectors-lang-014.html "css/selectors/i18n/css3-selectors-lang-014.html")
 [[(live
 test)]](http://wpt.live/css/selectors/i18n/css3-selectors-lang-014.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/i18n/css3-selectors-lang-014.html)
- [css3-selectors-lang-015.html](https://wpt.fyi/results/css/selectors/i18n/css3-selectors-lang-015.html "css/selectors/i18n/css3-selectors-lang-015.html")
 [[(live
 test)]](http://wpt.live/css/selectors/i18n/css3-selectors-lang-015.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/i18n/css3-selectors-lang-015.html)
- [css3-selectors-lang-016.html](https://wpt.fyi/results/css/selectors/i18n/css3-selectors-lang-016.html "css/selectors/i18n/css3-selectors-lang-016.html")
 [[(live
 test)]](http://wpt.live/css/selectors/i18n/css3-selectors-lang-016.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/i18n/css3-selectors-lang-016.html)
- [css3-selectors-lang-021.html](https://wpt.fyi/results/css/selectors/i18n/css3-selectors-lang-021.html "css/selectors/i18n/css3-selectors-lang-021.html")
 [[(live
 test)]](http://wpt.live/css/selectors/i18n/css3-selectors-lang-021.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/i18n/css3-selectors-lang-021.html)
- [css3-selectors-lang-022.html](https://wpt.fyi/results/css/selectors/i18n/css3-selectors-lang-022.html "css/selectors/i18n/css3-selectors-lang-022.html")
 [[(live
 test)]](http://wpt.live/css/selectors/i18n/css3-selectors-lang-022.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/i18n/css3-selectors-lang-022.html)
- [css3-selectors-lang-024.html](https://wpt.fyi/results/css/selectors/i18n/css3-selectors-lang-024.html "css/selectors/i18n/css3-selectors-lang-024.html")
 [[(live
 test)]](http://wpt.live/css/selectors/i18n/css3-selectors-lang-024.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/i18n/css3-selectors-lang-024.html)
- [css3-selectors-lang-025.html](https://wpt.fyi/results/css/selectors/i18n/css3-selectors-lang-025.html "css/selectors/i18n/css3-selectors-lang-025.html")
 [[(live
 test)]](http://wpt.live/css/selectors/i18n/css3-selectors-lang-025.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/i18n/css3-selectors-lang-025.html)
- [css3-selectors-lang-026.html](https://wpt.fyi/results/css/selectors/i18n/css3-selectors-lang-026.html "css/selectors/i18n/css3-selectors-lang-026.html")
 [[(live
 test)]](http://wpt.live/css/selectors/i18n/css3-selectors-lang-026.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/i18n/css3-selectors-lang-026.html)
- [css3-selectors-lang-027.html](https://wpt.fyi/results/css/selectors/i18n/css3-selectors-lang-027.html "css/selectors/i18n/css3-selectors-lang-027.html")
 [[(live
 test)]](http://wpt.live/css/selectors/i18n/css3-selectors-lang-027.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/i18n/css3-selectors-lang-027.html)
- [css3-selectors-lang-028.html](https://wpt.fyi/results/css/selectors/i18n/css3-selectors-lang-028.html "css/selectors/i18n/css3-selectors-lang-028.html")
 [[(live
 test)]](http://wpt.live/css/selectors/i18n/css3-selectors-lang-028.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/i18n/css3-selectors-lang-028.html)
- [css3-selectors-lang-029.html](https://wpt.fyi/results/css/selectors/i18n/css3-selectors-lang-029.html "css/selectors/i18n/css3-selectors-lang-029.html")
 [[(live
 test)]](http://wpt.live/css/selectors/i18n/css3-selectors-lang-029.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/i18n/css3-selectors-lang-029.html)
- [css3-selectors-lang-030.html](https://wpt.fyi/results/css/selectors/i18n/css3-selectors-lang-030.html "css/selectors/i18n/css3-selectors-lang-030.html")
 [[(live
 test)]](http://wpt.live/css/selectors/i18n/css3-selectors-lang-030.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/i18n/css3-selectors-lang-030.html)
- [css3-selectors-lang-031.html](https://wpt.fyi/results/css/selectors/i18n/css3-selectors-lang-031.html "css/selectors/i18n/css3-selectors-lang-031.html")
 [[(live
 test)]](http://wpt.live/css/selectors/i18n/css3-selectors-lang-031.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/i18n/css3-selectors-lang-031.html)
- [css3-selectors-lang-032.html](https://wpt.fyi/results/css/selectors/i18n/css3-selectors-lang-032.html "css/selectors/i18n/css3-selectors-lang-032.html")
 [[(live
 test)]](http://wpt.live/css/selectors/i18n/css3-selectors-lang-032.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/i18n/css3-selectors-lang-032.html)
- [css3-selectors-lang-034.html](https://wpt.fyi/results/css/selectors/i18n/css3-selectors-lang-034.html "css/selectors/i18n/css3-selectors-lang-034.html")
 [[(live
 test)]](http://wpt.live/css/selectors/i18n/css3-selectors-lang-034.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/i18n/css3-selectors-lang-034.html)
- [css3-selectors-lang-035.html](https://wpt.fyi/results/css/selectors/i18n/css3-selectors-lang-035.html "css/selectors/i18n/css3-selectors-lang-035.html")
 [[(live
 test)]](http://wpt.live/css/selectors/i18n/css3-selectors-lang-035.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/i18n/css3-selectors-lang-035.html)
- [css3-selectors-lang-036.html](https://wpt.fyi/results/css/selectors/i18n/css3-selectors-lang-036.html "css/selectors/i18n/css3-selectors-lang-036.html")
 [[(live
 test)]](http://wpt.live/css/selectors/i18n/css3-selectors-lang-036.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/i18n/css3-selectors-lang-036.html)
- [css3-selectors-lang-041.html](https://wpt.fyi/results/css/selectors/i18n/css3-selectors-lang-041.html "css/selectors/i18n/css3-selectors-lang-041.html")
 [[(live
 test)]](http://wpt.live/css/selectors/i18n/css3-selectors-lang-041.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/i18n/css3-selectors-lang-041.html)
- [css3-selectors-lang-042.html](https://wpt.fyi/results/css/selectors/i18n/css3-selectors-lang-042.html "css/selectors/i18n/css3-selectors-lang-042.html")
 [[(live
 test)]](http://wpt.live/css/selectors/i18n/css3-selectors-lang-042.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/i18n/css3-selectors-lang-042.html)
- [css3-selectors-lang-044.html](https://wpt.fyi/results/css/selectors/i18n/css3-selectors-lang-044.html "css/selectors/i18n/css3-selectors-lang-044.html")
 [[(live
 test)]](http://wpt.live/css/selectors/i18n/css3-selectors-lang-044.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/i18n/css3-selectors-lang-044.html)
- [css3-selectors-lang-045.html](https://wpt.fyi/results/css/selectors/i18n/css3-selectors-lang-045.html "css/selectors/i18n/css3-selectors-lang-045.html")
 [[(live
 test)]](http://wpt.live/css/selectors/i18n/css3-selectors-lang-045.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/i18n/css3-selectors-lang-045.html)
- [css3-selectors-lang-046.html](https://wpt.fyi/results/css/selectors/i18n/css3-selectors-lang-046.html "css/selectors/i18n/css3-selectors-lang-046.html")
 [[(live
 test)]](http://wpt.live/css/selectors/i18n/css3-selectors-lang-046.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/i18n/css3-selectors-lang-046.html)
- [css3-selectors-lang-047.html](https://wpt.fyi/results/css/selectors/i18n/css3-selectors-lang-047.html "css/selectors/i18n/css3-selectors-lang-047.html")
 [[(live
 test)]](http://wpt.live/css/selectors/i18n/css3-selectors-lang-047.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/i18n/css3-selectors-lang-047.html)
- [css3-selectors-lang-048.html](https://wpt.fyi/results/css/selectors/i18n/css3-selectors-lang-048.html "css/selectors/i18n/css3-selectors-lang-048.html")
 [[(live
 test)]](http://wpt.live/css/selectors/i18n/css3-selectors-lang-048.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/i18n/css3-selectors-lang-048.html)
- [css3-selectors-lang-049.html](https://wpt.fyi/results/css/selectors/i18n/css3-selectors-lang-049.html "css/selectors/i18n/css3-selectors-lang-049.html")
 [[(live
 test)]](http://wpt.live/css/selectors/i18n/css3-selectors-lang-049.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/i18n/css3-selectors-lang-049.html)
- [css3-selectors-lang-050.html](https://wpt.fyi/results/css/selectors/i18n/css3-selectors-lang-050.html "css/selectors/i18n/css3-selectors-lang-050.html")
 [[(live
 test)]](http://wpt.live/css/selectors/i18n/css3-selectors-lang-050.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/i18n/css3-selectors-lang-050.html)
- [css3-selectors-lang-051.html](https://wpt.fyi/results/css/selectors/i18n/css3-selectors-lang-051.html "css/selectors/i18n/css3-selectors-lang-051.html")
 [[(live
 test)]](http://wpt.live/css/selectors/i18n/css3-selectors-lang-051.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/i18n/css3-selectors-lang-051.html)
- [css3-selectors-lang-052.html](https://wpt.fyi/results/css/selectors/i18n/css3-selectors-lang-052.html "css/selectors/i18n/css3-selectors-lang-052.html")
 [[(live
 test)]](http://wpt.live/css/selectors/i18n/css3-selectors-lang-052.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/i18n/css3-selectors-lang-052.html)
- [css3-selectors-lang-054.html](https://wpt.fyi/results/css/selectors/i18n/css3-selectors-lang-054.html "css/selectors/i18n/css3-selectors-lang-054.html")
 [[(live
 test)]](http://wpt.live/css/selectors/i18n/css3-selectors-lang-054.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/i18n/css3-selectors-lang-054.html)
- [css3-selectors-lang-055.html](https://wpt.fyi/results/css/selectors/i18n/css3-selectors-lang-055.html "css/selectors/i18n/css3-selectors-lang-055.html")
 [[(live
 test)]](http://wpt.live/css/selectors/i18n/css3-selectors-lang-055.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/i18n/css3-selectors-lang-055.html)
- [css3-selectors-lang-056.html](https://wpt.fyi/results/css/selectors/i18n/css3-selectors-lang-056.html "css/selectors/i18n/css3-selectors-lang-056.html")
 [[(live
 test)]](http://wpt.live/css/selectors/i18n/css3-selectors-lang-056.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/i18n/css3-selectors-lang-056.html)
- [lang-pseudo-class-across-shadow-boundaries.html](https://wpt.fyi/results/css/selectors/i18n/lang-pseudo-class-across-shadow-boundaries.html "css/selectors/i18n/lang-pseudo-class-across-shadow-boundaries.html")
 [[(live
 test)]](http://wpt.live/css/selectors/i18n/lang-pseudo-class-across-shadow-boundaries.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/i18n/lang-pseudo-class-across-shadow-boundaries.html)
- [lang-pseudo-class-disconnected.html](https://wpt.fyi/results/css/selectors/i18n/lang-pseudo-class-disconnected.html "css/selectors/i18n/lang-pseudo-class-disconnected.html")
 [[(live
 test)]](http://wpt.live/css/selectors/i18n/lang-pseudo-class-disconnected.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/i18n/lang-pseudo-class-disconnected.html)
- [lang-pseudo-class-empty-attribute.xhtml](https://wpt.fyi/results/css/selectors/i18n/lang-pseudo-class-empty-attribute.xhtml "css/selectors/i18n/lang-pseudo-class-empty-attribute.xhtml")
 [[(live
 test)]](http://wpt.live/css/selectors/i18n/lang-pseudo-class-empty-attribute.xhtml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/i18n/lang-pseudo-class-empty-attribute.xhtml)
- [part-lang.html](https://wpt.fyi/results/css/selectors/invalidation/part-lang.html "css/selectors/invalidation/part-lang.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/part-lang.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/part-lang.html)
- [lang-000.html](https://wpt.fyi/results/css/selectors/selectors-4/lang-000.html "css/selectors/selectors-4/lang-000.html")
 [[(live
 test)]](http://wpt.live/css/selectors/selectors-4/lang-000.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/selectors-4/lang-000.html)
- [lang-001.html](https://wpt.fyi/results/css/selectors/selectors-4/lang-001.html "css/selectors/selectors-4/lang-001.html")
 [[(live
 test)]](http://wpt.live/css/selectors/selectors-4/lang-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/selectors-4/lang-001.html)
- [lang-002.html](https://wpt.fyi/results/css/selectors/selectors-4/lang-002.html "css/selectors/selectors-4/lang-002.html")
 [[(live
 test)]](http://wpt.live/css/selectors/selectors-4/lang-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/selectors-4/lang-002.html)
- [lang-003.html](https://wpt.fyi/results/css/selectors/selectors-4/lang-003.html "css/selectors/selectors-4/lang-003.html")
 [[(live
 test)]](http://wpt.live/css/selectors/selectors-4/lang-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/selectors-4/lang-003.html)
- [lang-004.html](https://wpt.fyi/results/css/selectors/selectors-4/lang-004.html "css/selectors/selectors-4/lang-004.html")
 [[(live
 test)]](http://wpt.live/css/selectors/selectors-4/lang-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/selectors-4/lang-004.html)
- [lang-005.html](https://wpt.fyi/results/css/selectors/selectors-4/lang-005.html "css/selectors/selectors-4/lang-005.html")
 [[(live
 test)]](http://wpt.live/css/selectors/selectors-4/lang-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/selectors-4/lang-005.html)
- [lang-006.html](https://wpt.fyi/results/css/selectors/selectors-4/lang-006.html "css/selectors/selectors-4/lang-006.html")
 [[(live
 test)]](http://wpt.live/css/selectors/selectors-4/lang-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/selectors-4/lang-006.html)
- [lang-007.html](https://wpt.fyi/results/css/selectors/selectors-4/lang-007.html "css/selectors/selectors-4/lang-007.html")
 [[(live
 test)]](http://wpt.live/css/selectors/selectors-4/lang-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/selectors-4/lang-007.html)
- [lang-008.html](https://wpt.fyi/results/css/selectors/selectors-4/lang-008.html "css/selectors/selectors-4/lang-008.html")
 [[(live
 test)]](http://wpt.live/css/selectors/selectors-4/lang-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/selectors-4/lang-008.html)
- [lang-009.html](https://wpt.fyi/results/css/selectors/selectors-4/lang-009.html "css/selectors/selectors-4/lang-009.html")
 [[(live
 test)]](http://wpt.live/css/selectors/selectors-4/lang-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/selectors-4/lang-009.html)
- [lang-010.html](https://wpt.fyi/results/css/selectors/selectors-4/lang-010.html "css/selectors/selectors-4/lang-010.html")
 [[(live
 test)]](http://wpt.live/css/selectors/selectors-4/lang-010.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/selectors-4/lang-010.html)
- [lang-011.html](https://wpt.fyi/results/css/selectors/selectors-4/lang-011.html "css/selectors/selectors-4/lang-011.html")
 [[(live
 test)]](http://wpt.live/css/selectors/selectors-4/lang-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/selectors-4/lang-011.html)
- [lang-012.html](https://wpt.fyi/results/css/selectors/selectors-4/lang-012.html "css/selectors/selectors-4/lang-012.html")
 [[(live
 test)]](http://wpt.live/css/selectors/selectors-4/lang-012.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/selectors-4/lang-012.html)
- [lang-013.html](https://wpt.fyi/results/css/selectors/selectors-4/lang-013.html "css/selectors/selectors-4/lang-013.html")
 [[(live
 test)]](http://wpt.live/css/selectors/selectors-4/lang-013.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/selectors-4/lang-013.html)
- [lang-014.html](https://wpt.fyi/results/css/selectors/selectors-4/lang-014.html "css/selectors/selectors-4/lang-014.html")
 [[(live
 test)]](http://wpt.live/css/selectors/selectors-4/lang-014.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/selectors-4/lang-014.html)
- [lang-015.html](https://wpt.fyi/results/css/selectors/selectors-4/lang-015.html "css/selectors/selectors-4/lang-015.html")
 [[(live
 test)]](http://wpt.live/css/selectors/selectors-4/lang-015.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/selectors-4/lang-015.html)
- [lang-016.html](https://wpt.fyi/results/css/selectors/selectors-4/lang-016.html "css/selectors/selectors-4/lang-016.html")
 [[(live
 test)]](http://wpt.live/css/selectors/selectors-4/lang-016.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/selectors-4/lang-016.html)
- [lang-017.html](https://wpt.fyi/results/css/selectors/selectors-4/lang-017.html "css/selectors/selectors-4/lang-017.html")
 [[(live
 test)]](http://wpt.live/css/selectors/selectors-4/lang-017.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/selectors-4/lang-017.html)
- [lang-018.html](https://wpt.fyi/results/css/selectors/selectors-4/lang-018.html "css/selectors/selectors-4/lang-018.html")
 [[(live
 test)]](http://wpt.live/css/selectors/selectors-4/lang-018.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/selectors-4/lang-018.html)
- [lang-019.html](https://wpt.fyi/results/css/selectors/selectors-4/lang-019.html "css/selectors/selectors-4/lang-019.html")
 [[(live
 test)]](http://wpt.live/css/selectors/selectors-4/lang-019.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/selectors-4/lang-019.html)
- [lang-020.html](https://wpt.fyi/results/css/selectors/selectors-4/lang-020.html "css/selectors/selectors-4/lang-020.html")
 [[(live
 test)]](http://wpt.live/css/selectors/selectors-4/lang-020.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/selectors-4/lang-020.html)
- [lang-021.html](https://wpt.fyi/results/css/selectors/selectors-4/lang-021.html "css/selectors/selectors-4/lang-021.html")
 [[(live
 test)]](http://wpt.live/css/selectors/selectors-4/lang-021.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/selectors-4/lang-021.html)
- [lang-022.html](https://wpt.fyi/results/css/selectors/selectors-4/lang-022.html "css/selectors/selectors-4/lang-022.html")
 [[(live
 test)]](http://wpt.live/css/selectors/selectors-4/lang-022.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/selectors-4/lang-022.html)
- [lang-023.html](https://wpt.fyi/results/css/selectors/selectors-4/lang-023.html "css/selectors/selectors-4/lang-023.html")
 [[(live
 test)]](http://wpt.live/css/selectors/selectors-4/lang-023.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/selectors-4/lang-023.html)
- [lang-024.html](https://wpt.fyi/results/css/selectors/selectors-4/lang-024.html "css/selectors/selectors-4/lang-024.html")
 [[(live
 test)]](http://wpt.live/css/selectors/selectors-4/lang-024.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/selectors-4/lang-024.html)
- [lang-025.html](https://wpt.fyi/results/css/selectors/selectors-4/lang-025.html "css/selectors/selectors-4/lang-025.html")
 [[(live
 test)]](http://wpt.live/css/selectors/selectors-4/lang-025.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/selectors-4/lang-025.html)
- [lang-singleton-subtag-matching.html](https://wpt.fyi/results/css/selectors/selectors-4/lang-singleton-subtag-matching.html "css/selectors/selectors-4/lang-singleton-subtag-matching.html")
 [[(live
 test)]](http://wpt.live/css/selectors/selectors-4/lang-singleton-subtag-matching.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/selectors-4/lang-singleton-subtag-matching.html)

If the document language specifies how the (human) [content
language](https://drafts.csswg.org/css-text-4/#content-language) of an element is determined, it is possible to write
selectors that represent an element based on its [content
language]. The [:lang()] pseudo-class, which
accepts a comma-separated list of one or more [language
ranges](#language-range),
represents an element whose [content
language] is one of the languages listed in
its argument. Each [language range] in
[:lang()](#lang-pseudo) is
an [extended language
range](https://www.rfc-editor.org/rfc/rfc4647.html#section-2.2), as
defined in BCP 47, and must be a valid CSS
[\<ident\>](https://drafts.csswg.org/css-values-4/#typedef-ident) or
[\<string\>](https://drafts.csswg.org/css-values-4/#string-value). (Thus language ranges containing
asterisks, for example, must be either correctly escaped or quoted as
strings, e.g. [:lang(\\\*-Latn)] or [:lang(\"\*-Latn\")].)

 The [content
language](https://drafts.csswg.org/css-text-4/#content-language) of an element is defined by the document language.

For example, in HTML
[\[HTML\]](#biblio-html "HTML Standard"), the
[content
language](https://drafts.csswg.org/css-text-4/#content-language) is determined by a combination of the `lang` attribute,
information from
[meta](https://html.spec.whatwg.org/multipage/semantics.html#meta) elements, and possibly also the protocol (e.g. from
HTTP headers). XML languages can use the `xml:lang` attribute to
indicate language information for an element.
[\[XML10\]](#biblio-xml10 "Extensible Markup Language (XML) 1.0 (Fifth Edition)")

The element's [content
language](https://drafts.csswg.org/css-text-4/#content-language) matches a [language
range](#language-range) if its
[content language], as represented in BCP 47
syntax, matches the given [language range] in
an *extended filtering* operation per
[\[RFC4647\]](#biblio-rfc4647 "Matching of Language Tags")
Matching of Language Tags (section 3.3.2). The [content
language] and the [language
range] must be *canonicalized* and converted
to *extlang form* as per section 4.5 of
[\[RFC5646\]](#biblio-rfc5646 "Tags for Identifying Languages")
prior to the *extended filtering* operation; language tags or ranges
that are not [valid](https://www.w3.org/TR/i18n-glossary/#dfn-valid) do
not match anything. The matching is performed [ASCII
case-insensitively](https://infra.spec.whatwg.org/#ascii-case-insensitive).

The [language range](#language-range) must be an extended language range according to BCP47.
Language ranges that are not
[well-formed](https://www.w3.org/TR/i18n-glossary/#dfn-well-formed)
language tags or which would not be a well-formed language tag if an
initial wildcard character \"\*\" were replaced with a valid subtag, do
not match anything.

For example,

```
:lang(åå)
```

would not match, because it containins non-ASCII characters so is
ill-formed.

On the other hand,

```
:lang(qq)
```

could match, even though qq is not a registered language code.

For this purpose, a wildcard [language
range](#language-range)
(`"*"`) does not match elements whose language is not tagged (e.g.
`lang=""`), but does match elements whose language is tagged as
undetermined (`lang=und`). A [language range]
consisting of an empty string ([:lang(\"\")]) matches (only)
elements whose language is not tagged.

 It is recommended that documents and protocols indicate
language using language tags from
[\[BCP47\]](#biblio-bcp47 "Tags for Identifying Languages"),
and in the case of XML-based formats, by means of `xml:lang` attributes.
[\[XML10\]](#biblio-xml10 "Extensible Markup Language (XML) 1.0 (Fifth Edition)")
See ["Choosing a Language
Tag"](https://www.w3.org/International/questions/qa-choosing-language-tags)

Examples: The two following selectors
represent an HTML document that is in Belgian French or German. The two
next selectors represent
[q](https://html.spec.whatwg.org/multipage/text-level-semantics.html#the-q-element) quotations in an arbitrary element in Belgian
French or German.

 html:lang(fr-be)
 html:lang(de)
 :lang(fr-be) > q
 :lang(de) > q

 One difference between [:lang(C)] and the
[\|=] operator is that the [\|=] operator only performs a
comparison against a given attribute on the element, while the
[:lang(C)] pseudo-class uses the UAs knowledge of the document's
semantics to perform the comparison.

In this HTML example, only the BODY
matches [\[lang\|=fr\]] (because it has a LANG attribute) but both
the BODY and the P match [:lang(fr)] (because both are in French).
The P does not match the [\[lang\|=fr\]] because it does not have
a LANG attribute.

 <body lang=fr>
 <p>Je suis français.</p>
 </body>

Another difference between
[:lang(C)] and the [\|=] operator is that [:lang(C)]
performs implicit wildcard matching.

For example, [:lang(de-DE)] will match all of [de-DE],
[de-DE-1996], [de-Latn-DE], [de-Latf-DE],
[de-Latn-DE-1996], whereas of those [\[lang\|=de-DE\]] will
only match [de-DE] and [de-DE-1996].

To perform wildcard matching on the first subtag (the primary language),
an asterisk must be used: [\*-CH] will match all of [de-CH],
[it-CH], [fr-CH], and [rm-CH].

To select against an element's lang attribute value using this type of
language range match, use both the attribute selector and language
pseudo-class together, e.g. [\[lang\]:lang(de-DE)].

 Wildcard language matching and comma-separated lists
are new in Level 4.

## 8. Location Pseudo-classes

### 8.1. The Hyperlink Pseudo-class: [:any-link]
Tests

- [any-link-attribute-removal.html](https://wpt.fyi/results/css/selectors/invalidation/any-link-attribute-removal.html "css/selectors/invalidation/any-link-attribute-removal.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/any-link-attribute-removal.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/any-link-attribute-removal.html)
- [any-link-pseudo.html](https://wpt.fyi/results/css/selectors/invalidation/any-link-pseudo.html "css/selectors/invalidation/any-link-pseudo.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/any-link-pseudo.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/any-link-pseudo.html)

The [:any-link] pseudo-class represents an element that
acts as the source anchor of a hyperlink. For example, in
[\[HTML\]](#biblio-html "HTML Standard"), any
[`a`](https://html.spec.whatwg.org/multipage/text-level-semantics.html#the-a-element) or
[`area`](https://html.spec.whatwg.org/multipage/image-maps.html#the-area-element) elements with an
[`href`](https://html.spec.whatwg.org/multipage/links.html#attr-hyperlink-href) attribute are hyperlinks, and thus match
`:any-link`. It matches an element if the element would match either
[:link](#link-pseudo) or
[:visited](#visited-pseudo), and is equivalent to [:is(:link, :visited)].

### 8.2. The Link History Pseudo-classes: [:link and [:visited](#visited-pseudo)]
Tests

- [caret-color-visited-inheritance.html](https://wpt.fyi/results/css/selectors/caret-color-visited-inheritance.html "css/selectors/caret-color-visited-inheritance.html")
 [[(live
 test)]](http://wpt.live/css/selectors/caret-color-visited-inheritance.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/caret-color-visited-inheritance.html)
- [text-emphasis-visited-inheritance.html](https://wpt.fyi/results/css/selectors/text-emphasis-visited-inheritance.html "css/selectors/text-emphasis-visited-inheritance.html")
 [[(live
 test)]](http://wpt.live/css/selectors/text-emphasis-visited-inheritance.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/text-emphasis-visited-inheritance.html)
- [text-fill-color-visited-inheritance.html](https://wpt.fyi/results/css/selectors/text-fill-color-visited-inheritance.html "css/selectors/text-fill-color-visited-inheritance.html")
 [[(live
 test)]](http://wpt.live/css/selectors/text-fill-color-visited-inheritance.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/text-fill-color-visited-inheritance.html)
- [text-stroke-color-visited-inheritance.html](https://wpt.fyi/results/css/selectors/text-stroke-color-visited-inheritance.html "css/selectors/text-stroke-color-visited-inheritance.html")
 [[(live
 test)]](http://wpt.live/css/selectors/text-stroke-color-visited-inheritance.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/text-stroke-color-visited-inheritance.html)
- [visited-in-visited-compound.html](https://wpt.fyi/results/css/selectors/visited-in-visited-compound.html "css/selectors/visited-in-visited-compound.html")
 [[(live
 test)]](http://wpt.live/css/selectors/visited-in-visited-compound.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/visited-in-visited-compound.html)
- [visited-inheritance.html](https://wpt.fyi/results/css/selectors/visited-inheritance.html "css/selectors/visited-inheritance.html")
 [[(live
 test)]](http://wpt.live/css/selectors/visited-inheritance.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/visited-inheritance.html)
- [visited-nested.html](https://wpt.fyi/results/css/selectors/visited-nested.html "css/selectors/visited-nested.html")
 [[(live
 test)]](http://wpt.live/css/selectors/visited-nested.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/visited-nested.html)
- [visited-part-crash.html](https://wpt.fyi/results/css/selectors/visited-part-crash.html "css/selectors/visited-part-crash.html")
 [[(live
 test)]](http://wpt.live/css/selectors/visited-part-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/visited-part-crash.html)

User agents commonly display unvisited
[hyperlinks](#the-any-link-pseudo) differently from previously visited
ones. Selectors provides the pseudo-classes [:link] and
[:visited] to distinguish them:

- The [:link](#link-pseudo) pseudo-class applies to links that have not yet
 been visited.
- The [:visited](#visited-pseudo) pseudo-class applies once the link has been visited
 by the user.

The two states are mutually exclusive.

After some amount of time, user agents may choose to return a visited
link to the (unvisited) [:link](#link-pseudo) state.

The [:visited](#visited-pseudo) pseudo-class comes with obvious privacy
implications---​letting random websites know what *other* websites you've
visited can be problematic for a number of reasons---​and so user agents
*must* preserve user privacy in their implementation of
[:visited].

This specification intentionally does not specify exactly how to
preserve user privacy in this regard, to allow for user agents to
innovate in this space. The following methods are suggested, however:

- Have [:visited](#visited-pseudo) never match, so all links match
 [:link](#link-pseudo)
 instead.

- Carefully track what history entries could have been observed by a
 given origin on their own, and only have links match
 [:visited](#visited-pseudo) if that visit would have been observable from the
 site's origin. A possible specific approach for this is described in
 [Appendix C: Example Privacy-Preserving :visited
 Restrictions](#visited-privacy).

- Allow links to match
 [:visited](#visited-pseudo) on any origin, but carefully restrict what styles
 they can apply and what information is returned by style-querying APIs
 like
 [`getComputedStyle()`](https://drafts.csswg.org/cssom-1/#dom-window-getcomputedstyle), to prevent sites from observing whether a link is
 styled with [:link](#link-pseudo) or [:visited]. (This
 is documented at
 [MDN](https://developer.mozilla.org/en-US/docs/Web/CSS/Privacy_and_the_:visited_selector),
 and was the historical approach browsers took, but is not perfect;
 there are several ways for a hostile page to still extract history
 information.)

For example, the selector
[.footnote:visited] would allow styling footnote links differently
if they've been previously followed, allowing users of the page to know
they might not need to click the footnote again.

### 8.3. The Target Pseudo-class: [:target]
In some document languages, the document's URL can further point to
specific elements *within* the document via the URL's
[fragment](https://url.spec.whatwg.org/#concept-url-fragment). The elements pointed to in this way are the target
elements of the document.

In HTML the fragment points to the
element in the page with the same ID. The url
`https://example.com/index.html#section2`, for example, points to the
element with `id="section2"` in the document at
`https://example.com/index.html`.

The [:target] pseudo-class matches the document's target elements. If the
document's URL has no fragment identifier, then the document has no
target elements.

Example:

 p.note:target

This selector represents a
[`p`](https://html.spec.whatwg.org/multipage/grouping-content.html#the-p-element) element of class `note` that is the target element
of the referring URL.

CSS example: Here, the
[:target](#target-pseudo) pseudo-class is used to make the target element red
and place an image before it, if there is one:

 :target { color : red }
 :target::before { content : url(target.png) }

 This specification previously defined a
[:target-within] pseudo-class, analogous to
[:focus-within](#focus-within-pseudo). It was removed in favor of [:has(:target)],
which should hopefully suffice to solve the same use-cases.

### 8.4. The Reference Element Pseudo-class: [:scope]
Tests

- [scope-selector.html](https://wpt.fyi/results/css/selectors/scope-selector.html "css/selectors/scope-selector.html")
 [[(live
 test)]](http://wpt.live/css/selectors/scope-selector.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/scope-selector.html)
- [scope-without-scoping.html](https://wpt.fyi/results/css/selectors/scope-without-scoping.html "css/selectors/scope-without-scoping.html")
 [[(live
 test)]](http://wpt.live/css/selectors/scope-without-scoping.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/scope-without-scoping.html)

In some contexts, selectors are matched with respect to one or more
[scoping roots](#scoping-root),
such as when calling the [`querySelector()`]
method in [\[DOM\]](#biblio-dom "DOM Standard"). The
[:scope] pseudo-class represents this [scoping
root], and may be either a true element or a
virtual one (such as a
[`DocumentFragment`](https://dom.spec.whatwg.org/#documentfragment)).

If there is no [scoping root](#scoping-root) then [:scope](#scope-pseudo) represents the root of the tree the element is
in (equivalent to
[:host](https://drafts.csswg.org/css-shadow-1/#selectordef-host) in a [shadow
tree](https://dom.spec.whatwg.org/#concept-shadow-tree), or [:root](#root-pseudo) otherwise). Specifications intending for this
pseudo-class to match specific elements rather than this tree root
element must define their [scoping root(s)].

A virtual [scoping root](#scoping-root) is some object representing the root of a document
fragment, and can be used in selector patterns to represent other
elements' relationships to this [scoping root],
acting as the parent of any root elements in the document fragment it
represents. A virtual [scoping root] is
[featureless](#featureless) and
cannot be the [subject of the
selector](#selector-subject).

For example, if you have a
[`DocumentFragment`](https://dom.spec.whatwg.org/#documentfragment) `df`, then
`df.querySelectorAll(":scope > .foo")` matches all the
[.foo] elements that are \"top-level\" in the document fragment
(those that have the document fragment as their
[`parentNode`](https://dom.spec.whatwg.org/#dom-node-parentnode)).

However, `df.querySelector(":scope")` will not match
anything, as the document fragment itself can't be the [subject of the
selector](#selector-subject).

## 9. User Action Pseudo-classes

Interactive user interfaces sometimes change the rendering in response
to user actions. Selectors provides several [user action
pseudo-classes] for the
selection of an element the user is acting on. (In non-interactive user
agents, these pseudo-classes are valid, but never match any element.)

The [user action
pseudo-classes](#user-action-pseudo-class) are not mutually exclusive. An element can match
several such pseudo-classes at the same time.

Examples:

 a:hover /* user hovers over the link */
 a:focus /* user focuses the link */

 a:focus:hover
 /* user hovers over the link while it's focused */

Some [user action
pseudo-classes](#user-action-pseudo-class), in addition to matching on the particular element with
the property in question, match on that element's ancestors as well:
[:hover](#hover-pseudo),
[:active](#active-pseudo),
[:focus-within](#focus-within-pseudo). Specifically, if these match on a given element,
they also match on the element's [flat
tree](https://drafts.csswg.org/css-shadow-1/#flat-tree) ancestors, up to and including the first [top
layer](https://drafts.csswg.org/css-position-4/#document-top-layer) element or the
[root](https://dom.spec.whatwg.org/#concept-tree-root) element, whichever is encountered first.

 The specifics of hit-testing, necessary to know when
several of the pseudo-classes defined in this section apply, are not yet
defined, but will be in the future.

Tests

- [active-display-none-001.html](https://wpt.fyi/results/css/selectors/active-display-none-001.html "css/selectors/active-display-none-001.html")
 [[(live
 test)]](http://wpt.live/css/selectors/active-display-none-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/active-display-none-001.html)
- [active-observable.html](https://wpt.fyi/results/css/selectors/active-observable.html "css/selectors/active-observable.html")
 [[(live
 test)]](http://wpt.live/css/selectors/active-observable.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/active-observable.html)
- [active-toplayer-001.html](https://wpt.fyi/results/css/selectors/active-toplayer-001.html "css/selectors/active-toplayer-001.html")
 [[(live
 test)]](http://wpt.live/css/selectors/active-toplayer-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/active-toplayer-001.html)
- [active-after-relayouts.html](https://wpt.fyi/results/css/selectors/active-after-relayouts.html "css/selectors/active-after-relayouts.html")
 [[(live
 test)]](http://wpt.live/css/selectors/active-after-relayouts.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/active-after-relayouts.html)
- [focus-within-toplayer-001.html](https://wpt.fyi/results/css/selectors/focus-within-toplayer-001.html "css/selectors/focus-within-toplayer-001.html")
 [[(live
 test)]](http://wpt.live/css/selectors/focus-within-toplayer-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/focus-within-toplayer-001.html)
- [hover-toplayer-001.html](https://wpt.fyi/results/css/selectors/hover-toplayer-001.html "css/selectors/hover-toplayer-001.html")
 [[(live
 test)]](http://wpt.live/css/selectors/hover-toplayer-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/hover-toplayer-001.html)
- [toplayer-transition-001.html](https://wpt.fyi/results/css/selectors/toplayer-transition-001.html "css/selectors/toplayer-transition-001.html")
 [[(live
 test)]](http://wpt.live/css/selectors/toplayer-transition-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/toplayer-transition-001.html)
- [user-action-pseudo-top-layer.html](https://wpt.fyi/results/css/selectors/user-action-pseudo-top-layer.html "css/selectors/user-action-pseudo-top-layer.html")
 [[(live
 test)]](http://wpt.live/css/selectors/user-action-pseudo-top-layer.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/user-action-pseudo-top-layer.html)

### 9.1. The Pointer Hover Pseudo-class: [:hover]
Tests

- [hover-001-manual.html (manual test)
 ][[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/hover-001-manual.html)
- [hover-002.html](https://wpt.fyi/results/css/selectors/hover-002.html "css/selectors/hover-002.html")
 [[(live
 test)]](http://wpt.live/css/selectors/hover-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/hover-002.html)
- [remove-hovered-element.html](https://wpt.fyi/results/css/selectors/remove-hovered-element.html "css/selectors/remove-hovered-element.html")
 [[(live
 test)]](http://wpt.live/css/selectors/remove-hovered-element.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/remove-hovered-element.html)

The [:hover] pseudo-class applies while the user designates an element (or
pseudo-element) with a pointing device, but does not necessarily
activate it. For example, a visual user agent could apply this
pseudo-class when the cursor (mouse pointer) hovers over a box generated
by the element. Interactive user agents that cannot detect hovering due
to hardware limitations (e.g., a pen device that does not detect
hovering) are still conforming; the selector will simply never match in
such a UA.

An element also matches [:hover](#hover-pseudo) if one of its descendants in the [flat
tree](https://drafts.csswg.org/css-shadow-1/#flat-tree) (including non-element nodes, such as text nodes)
matches the above conditions.

Document languages may define additional ways in which an element can
match [:hover](#hover-pseudo). For example,
[\[HTML\]](#biblio-html "HTML Standard") defines a
labeled control element as [matching
`:hover`](https://html.spec.whatwg.org/multipage/semantics-other.html#selector-hover)
when its
[label](https://html.spec.whatwg.org/multipage/forms.html#the-label-element) is hovered.

 Since the
[:hover](#hover-pseudo)
state can apply to an element because its child is designated by a
pointing device, it is possible for [:hover] to apply to an element that is not underneath the pointing device.

### 9.2. The Activation Pseudo-class: [:active]
The [:active] pseudo-class applies while an element is being "activated" by
the user, as defined by the host language; for example, while a
hyperlink is being triggered.

In addition, the [:active](#active-pseudo) pseudo-class applies while any generated box of *any*
element (or pseudo-element) is being actively indicated by a pointing
device (in the "down" state), e.g. between the time the user presses the
primary mouse button and releases it, or while a finger is pressing on a
touchscreen.

[\[HTML\]](#biblio-html "HTML Standard") defines
[specific conditions for HTML elements to be
activated](https://html.spec.whatwg.org/multipage/semantics-other.html#selector-active)
.

An element also matches
[:active](#active-pseudo) if one of its descendants in the [flat
tree](https://drafts.csswg.org/css-shadow-1/#flat-tree) (including non-element nodes, such as text nodes)
matches the above conditions.

### 9.3. The Input Focus Pseudo-class: [:focus]
Tests

- [focus-display-none-001.html](https://wpt.fyi/results/css/selectors/focus-display-none-001.html "css/selectors/focus-display-none-001.html")
 [[(live
 test)]](http://wpt.live/css/selectors/focus-display-none-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/focus-display-none-001.html)
- [focus-in-focus-event-001.html](https://wpt.fyi/results/css/selectors/focus-in-focus-event-001.html "css/selectors/focus-in-focus-event-001.html")
 [[(live
 test)]](http://wpt.live/css/selectors/focus-in-focus-event-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/focus-in-focus-event-001.html)
- [focus-in-focusin-event-001.html](https://wpt.fyi/results/css/selectors/focus-in-focusin-event-001.html "css/selectors/focus-in-focusin-event-001.html")
 [[(live
 test)]](http://wpt.live/css/selectors/focus-in-focusin-event-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/focus-in-focusin-event-001.html)

The [:focus] pseudo-class applies while an element (or pseudo-element) has
the focus (accepts keyboard or other forms of input).

There may be document language or implementation specific limits on
which elements can acquire
[:focus](#focus-pseudo).
For example,
[\[HTML\]](#biblio-html "HTML Standard") defines a
list of [focusable
areas](https://html.spec.whatwg.org/multipage/interaction.html#focusable-area).

Document languages may define additional ways in which an element can
match [:focus](#focus-pseudo), except that the [:focus] pseudo-class must not automatically propagate to the parent
element---​see
[:focus-within](#focus-within-pseudo) if matching on the parent is desired.
([:focus] may still apply to the parent
element if made to propagate due to other mechanisms, but not merely due
to being the parent.)

There's a desire from authors to
propagate [:focus](#focus-pseudo) from a form control to its associated
[`label`](https://html.spec.whatwg.org/multipage/forms.html#the-label-element) element; the main objection seems to be
implementation difficulty. See [CSSWG issue
(CSS)](https://github.com/w3c/csswg-drafts/issues/397) and [WHATWG issue
(HTML)](https://github.com/whatwg/html/issues/1632).

### 9.4. The Focus-Indicated Pseudo-class: [:focus-visible]
Tests

- [focus-visible-001.html](https://wpt.fyi/results/css/selectors/focus-visible-001.html "css/selectors/focus-visible-001.html")
 [[(live
 test)]](http://wpt.live/css/selectors/focus-visible-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/focus-visible-001.html)
- [focus-visible-002.html](https://wpt.fyi/results/css/selectors/focus-visible-002.html "css/selectors/focus-visible-002.html")
 [[(live
 test)]](http://wpt.live/css/selectors/focus-visible-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/focus-visible-002.html)
- [focus-visible-003.html](https://wpt.fyi/results/css/selectors/focus-visible-003.html "css/selectors/focus-visible-003.html")
 [[(live
 test)]](http://wpt.live/css/selectors/focus-visible-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/focus-visible-003.html)
- [focus-visible-004.html](https://wpt.fyi/results/css/selectors/focus-visible-004.html "css/selectors/focus-visible-004.html")
 [[(live
 test)]](http://wpt.live/css/selectors/focus-visible-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/focus-visible-004.html)
- [focus-visible-005.html](https://wpt.fyi/results/css/selectors/focus-visible-005.html "css/selectors/focus-visible-005.html")
 [[(live
 test)]](http://wpt.live/css/selectors/focus-visible-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/focus-visible-005.html)
- [focus-visible-006.html](https://wpt.fyi/results/css/selectors/focus-visible-006.html "css/selectors/focus-visible-006.html")
 [[(live
 test)]](http://wpt.live/css/selectors/focus-visible-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/focus-visible-006.html)
- [focus-visible-007.html](https://wpt.fyi/results/css/selectors/focus-visible-007.html "css/selectors/focus-visible-007.html")
 [[(live
 test)]](http://wpt.live/css/selectors/focus-visible-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/focus-visible-007.html)
- [focus-visible-008.html](https://wpt.fyi/results/css/selectors/focus-visible-008.html "css/selectors/focus-visible-008.html")
 [[(live
 test)]](http://wpt.live/css/selectors/focus-visible-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/focus-visible-008.html)
- [focus-visible-009.html](https://wpt.fyi/results/css/selectors/focus-visible-009.html "css/selectors/focus-visible-009.html")
 [[(live
 test)]](http://wpt.live/css/selectors/focus-visible-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/focus-visible-009.html)
- [focus-visible-010.html](https://wpt.fyi/results/css/selectors/focus-visible-010.html "css/selectors/focus-visible-010.html")
 [[(live
 test)]](http://wpt.live/css/selectors/focus-visible-010.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/focus-visible-010.html)
- [focus-visible-011.html](https://wpt.fyi/results/css/selectors/focus-visible-011.html "css/selectors/focus-visible-011.html")
 [[(live
 test)]](http://wpt.live/css/selectors/focus-visible-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/focus-visible-011.html)
- [focus-visible-012.html](https://wpt.fyi/results/css/selectors/focus-visible-012.html "css/selectors/focus-visible-012.html")
 [[(live
 test)]](http://wpt.live/css/selectors/focus-visible-012.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/focus-visible-012.html)
- [focus-visible-013.html](https://wpt.fyi/results/css/selectors/focus-visible-013.html "css/selectors/focus-visible-013.html")
 [[(live
 test)]](http://wpt.live/css/selectors/focus-visible-013.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/focus-visible-013.html)
- [focus-visible-014.html](https://wpt.fyi/results/css/selectors/focus-visible-014.html "css/selectors/focus-visible-014.html")
 [[(live
 test)]](http://wpt.live/css/selectors/focus-visible-014.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/focus-visible-014.html)
- [focus-visible-015.html](https://wpt.fyi/results/css/selectors/focus-visible-015.html "css/selectors/focus-visible-015.html")
 [[(live
 test)]](http://wpt.live/css/selectors/focus-visible-015.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/focus-visible-015.html)
- [focus-visible-016.html](https://wpt.fyi/results/css/selectors/focus-visible-016.html "css/selectors/focus-visible-016.html")
 [[(live
 test)]](http://wpt.live/css/selectors/focus-visible-016.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/focus-visible-016.html)
- [focus-visible-017-2.html](https://wpt.fyi/results/css/selectors/focus-visible-017-2.html "css/selectors/focus-visible-017-2.html")
 [[(live
 test)]](http://wpt.live/css/selectors/focus-visible-017-2.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/focus-visible-017-2.html)
- [focus-visible-017.html](https://wpt.fyi/results/css/selectors/focus-visible-017.html "css/selectors/focus-visible-017.html")
 [[(live
 test)]](http://wpt.live/css/selectors/focus-visible-017.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/focus-visible-017.html)
- [focus-visible-018-2.html](https://wpt.fyi/results/css/selectors/focus-visible-018-2.html "css/selectors/focus-visible-018-2.html")
 [[(live
 test)]](http://wpt.live/css/selectors/focus-visible-018-2.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/focus-visible-018-2.html)
- [focus-visible-018.html](https://wpt.fyi/results/css/selectors/focus-visible-018.html "css/selectors/focus-visible-018.html")
 [[(live
 test)]](http://wpt.live/css/selectors/focus-visible-018.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/focus-visible-018.html)
- [focus-visible-019.html](https://wpt.fyi/results/css/selectors/focus-visible-019.html "css/selectors/focus-visible-019.html")
 [[(live
 test)]](http://wpt.live/css/selectors/focus-visible-019.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/focus-visible-019.html)
- [focus-visible-020.html](https://wpt.fyi/results/css/selectors/focus-visible-020.html "css/selectors/focus-visible-020.html")
 [[(live
 test)]](http://wpt.live/css/selectors/focus-visible-020.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/focus-visible-020.html)
- [focus-visible-021.html](https://wpt.fyi/results/css/selectors/focus-visible-021.html "css/selectors/focus-visible-021.html")
 [[(live
 test)]](http://wpt.live/css/selectors/focus-visible-021.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/focus-visible-021.html)
- [focus-visible-023.html](https://wpt.fyi/results/css/selectors/focus-visible-023.html "css/selectors/focus-visible-023.html")
 [[(live
 test)]](http://wpt.live/css/selectors/focus-visible-023.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/focus-visible-023.html)
- [focus-visible-024.html](https://wpt.fyi/results/css/selectors/focus-visible-024.html "css/selectors/focus-visible-024.html")
 [[(live
 test)]](http://wpt.live/css/selectors/focus-visible-024.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/focus-visible-024.html)
- [focus-visible-025.html](https://wpt.fyi/results/css/selectors/focus-visible-025.html "css/selectors/focus-visible-025.html")
 [[(live
 test)]](http://wpt.live/css/selectors/focus-visible-025.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/focus-visible-025.html)
- [focus-visible-026.html](https://wpt.fyi/results/css/selectors/focus-visible-026.html "css/selectors/focus-visible-026.html")
 [[(live
 test)]](http://wpt.live/css/selectors/focus-visible-026.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/focus-visible-026.html)
- [focus-visible-027.html](https://wpt.fyi/results/css/selectors/focus-visible-027.html "css/selectors/focus-visible-027.html")
 [[(live
 test)]](http://wpt.live/css/selectors/focus-visible-027.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/focus-visible-027.html)
- [focus-visible-028.html](https://wpt.fyi/results/css/selectors/focus-visible-028.html "css/selectors/focus-visible-028.html")
 [[(live
 test)]](http://wpt.live/css/selectors/focus-visible-028.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/focus-visible-028.html)
- [focus-visible-script-focus-001.html](https://wpt.fyi/results/css/selectors/focus-visible-script-focus-001.html "css/selectors/focus-visible-script-focus-001.html")
 [[(live
 test)]](http://wpt.live/css/selectors/focus-visible-script-focus-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/focus-visible-script-focus-001.html)
- [focus-visible-script-focus-004.html](https://wpt.fyi/results/css/selectors/focus-visible-script-focus-004.html "css/selectors/focus-visible-script-focus-004.html")
 [[(live
 test)]](http://wpt.live/css/selectors/focus-visible-script-focus-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/focus-visible-script-focus-004.html)
- [focus-visible-script-focus-005.html](https://wpt.fyi/results/css/selectors/focus-visible-script-focus-005.html "css/selectors/focus-visible-script-focus-005.html")
 [[(live
 test)]](http://wpt.live/css/selectors/focus-visible-script-focus-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/focus-visible-script-focus-005.html)
- [focus-visible-script-focus-008-b.html](https://wpt.fyi/results/css/selectors/focus-visible-script-focus-008-b.html "css/selectors/focus-visible-script-focus-008-b.html")
 [[(live
 test)]](http://wpt.live/css/selectors/focus-visible-script-focus-008-b.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/focus-visible-script-focus-008-b.html)
- [focus-visible-script-focus-008.html](https://wpt.fyi/results/css/selectors/focus-visible-script-focus-008.html "css/selectors/focus-visible-script-focus-008.html")
 [[(live
 test)]](http://wpt.live/css/selectors/focus-visible-script-focus-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/focus-visible-script-focus-008.html)
- [focus-visible-script-focus-009.html](https://wpt.fyi/results/css/selectors/focus-visible-script-focus-009.html "css/selectors/focus-visible-script-focus-009.html")
 [[(live
 test)]](http://wpt.live/css/selectors/focus-visible-script-focus-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/focus-visible-script-focus-009.html)
- [focus-visible-script-focus-010.html](https://wpt.fyi/results/css/selectors/focus-visible-script-focus-010.html "css/selectors/focus-visible-script-focus-010.html")
 [[(live
 test)]](http://wpt.live/css/selectors/focus-visible-script-focus-010.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/focus-visible-script-focus-010.html)
- [focus-visible-script-focus-011.html](https://wpt.fyi/results/css/selectors/focus-visible-script-focus-011.html "css/selectors/focus-visible-script-focus-011.html")
 [[(live
 test)]](http://wpt.live/css/selectors/focus-visible-script-focus-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/focus-visible-script-focus-011.html)
- [focus-visible-script-focus-012.html](https://wpt.fyi/results/css/selectors/focus-visible-script-focus-012.html "css/selectors/focus-visible-script-focus-012.html")
 [[(live
 test)]](http://wpt.live/css/selectors/focus-visible-script-focus-012.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/focus-visible-script-focus-012.html)
- [focus-visible-script-focus-013.html](https://wpt.fyi/results/css/selectors/focus-visible-script-focus-013.html "css/selectors/focus-visible-script-focus-013.html")
 [[(live
 test)]](http://wpt.live/css/selectors/focus-visible-script-focus-013.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/focus-visible-script-focus-013.html)
- [focus-visible-script-focus-014.html](https://wpt.fyi/results/css/selectors/focus-visible-script-focus-014.html "css/selectors/focus-visible-script-focus-014.html")
 [[(live
 test)]](http://wpt.live/css/selectors/focus-visible-script-focus-014.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/focus-visible-script-focus-014.html)
- [focus-visible-script-focus-015.html](https://wpt.fyi/results/css/selectors/focus-visible-script-focus-015.html "css/selectors/focus-visible-script-focus-015.html")
 [[(live
 test)]](http://wpt.live/css/selectors/focus-visible-script-focus-015.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/focus-visible-script-focus-015.html)
- [focus-visible-script-focus-018.html](https://wpt.fyi/results/css/selectors/focus-visible-script-focus-018.html "css/selectors/focus-visible-script-focus-018.html")
 [[(live
 test)]](http://wpt.live/css/selectors/focus-visible-script-focus-018.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/focus-visible-script-focus-018.html)
- [focus-visible-script-focus-019.html](https://wpt.fyi/results/css/selectors/focus-visible-script-focus-019.html "css/selectors/focus-visible-script-focus-019.html")
 [[(live
 test)]](http://wpt.live/css/selectors/focus-visible-script-focus-019.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/focus-visible-script-focus-019.html)
- [focus-visible-script-focus-020.html](https://wpt.fyi/results/css/selectors/focus-visible-script-focus-020.html "css/selectors/focus-visible-script-focus-020.html")
 [[(live
 test)]](http://wpt.live/css/selectors/focus-visible-script-focus-020.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/focus-visible-script-focus-020.html)
- [parse-focus-visible.html](https://wpt.fyi/results/css/selectors/parsing/parse-focus-visible.html "css/selectors/parsing/parse-focus-visible.html")
 [[(live
 test)]](http://wpt.live/css/selectors/parsing/parse-focus-visible.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/parsing/parse-focus-visible.html)

While the [:focus](#focus-pseudo) [pseudo-class](#pseudo-class) always matches the currently-focused element, UAs only
sometimes visibly [indicate focus] (such as by drawing a "focus ring"), instead
using a variety of heuristics to visibly indicate the focus only when it
would be most helpful to the user. The
[:focus-visible] [pseudo-class]
matches a focused element (or pseudo-element) in these situations only,
allowing authors to change the appearance of the focus indicator without
changing *when* a focus indicator appears.

In this example, all focusable
elements get a strong yellow outline on
[:focus-visible](#focus-visible-pseudo), and links get both a yellow outline and a
yellow background on [:focus-visible]. These styles are consistent throughout the page and are easily
visible due to their bold styling, but do not appear unless the user is
likely to need to understand where page focus is.

``` highlight
:root {
 --focus-gold: #ffbf47;
}

:focus-visible {
 outline: 3px solid var(--focus-gold);
}

a:focus-visible {
 background-color: var(--focus-gold);
}
```

User agents can choose their own
heuristics for when to [indicate
focus](#indicate-focus);
however, the following (non-normative) suggestions can be used as a
starting point for when to [indicate focus] on
the currently focused element:

- If the user has expressed a preference (such as via a system
 preference or a browser setting) to always see a visible focus
 indicator, [indicate focus](#indicate-focus) regardless of any other factors. (Another option may
 be for the user agent to show its own focus indicator regardless of
 author styles.)

- If the element supports keyboard input (such as an
 [`input`](https://html.spec.whatwg.org/multipage/input.html#the-input-element) element, or any other element that would triggers
 a virtual keyboard to be shown on focus if a physical keyboard were
 not present), [indicate
 focus](#indicate-focus).

- If the user interacts with the page via keyboard or some other
 non-pointing device, [indicate
 focus](#indicate-focus).
 (This means keyboard usage may change whether this pseudo-class
 matches even if it doesn't affect
 [:focus](#focus-pseudo)).

- If the user interacts with the page via a pointing device (mouse,
 touchscreen, etc.) and the focused element does not support keyboard
 input, don't [indicate
 focus](#indicate-focus).

- If the previously-focused element [indicated
 focus](#indicate-focus), and
 a script causes focus to move elsewhere, [indicate
 focus] on the newly focused element.

 Conversely, if the previously-focused element did not [indicate
 focus](#indicate-focus), and
 a script causes focus to move elsewhere, don't [indicate
 focus] on the newly focused element.

- If a newly-displayed element automatically gains focus (such as an
 action button in a freshly opened dialog), that element should
 [indicate focus](#indicate-focus).

User agents should also use
[:focus-visible](#focus-visible-pseudo) to specify the default focus style, so that
authors using [:focus-visible] will
not also need to disable the default
[:focus](#focus-pseudo)
style.

### 9.5. The Focus Container Pseudo-class: [:focus-within]
Tests

- [focus-within-001.html](https://wpt.fyi/results/css/selectors/focus-within-001.html "css/selectors/focus-within-001.html")
 [[(live
 test)]](http://wpt.live/css/selectors/focus-within-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/focus-within-001.html)
- [focus-within-002.html](https://wpt.fyi/results/css/selectors/focus-within-002.html "css/selectors/focus-within-002.html")
 [[(live
 test)]](http://wpt.live/css/selectors/focus-within-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/focus-within-002.html)
- [focus-within-003.html](https://wpt.fyi/results/css/selectors/focus-within-003.html "css/selectors/focus-within-003.html")
 [[(live
 test)]](http://wpt.live/css/selectors/focus-within-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/focus-within-003.html)
- [focus-within-004.html](https://wpt.fyi/results/css/selectors/focus-within-004.html "css/selectors/focus-within-004.html")
 [[(live
 test)]](http://wpt.live/css/selectors/focus-within-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/focus-within-004.html)
- [focus-within-005.html](https://wpt.fyi/results/css/selectors/focus-within-005.html "css/selectors/focus-within-005.html")
 [[(live
 test)]](http://wpt.live/css/selectors/focus-within-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/focus-within-005.html)
- [focus-within-006.html](https://wpt.fyi/results/css/selectors/focus-within-006.html "css/selectors/focus-within-006.html")
 [[(live
 test)]](http://wpt.live/css/selectors/focus-within-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/focus-within-006.html)
- [focus-within-007.html](https://wpt.fyi/results/css/selectors/focus-within-007.html "css/selectors/focus-within-007.html")
 [[(live
 test)]](http://wpt.live/css/selectors/focus-within-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/focus-within-007.html)
- [focus-within-008.html](https://wpt.fyi/results/css/selectors/focus-within-008.html "css/selectors/focus-within-008.html")
 [[(live
 test)]](http://wpt.live/css/selectors/focus-within-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/focus-within-008.html)
- [focus-within-009.html](https://wpt.fyi/results/css/selectors/focus-within-009.html "css/selectors/focus-within-009.html")
 [[(live
 test)]](http://wpt.live/css/selectors/focus-within-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/focus-within-009.html)
- [focus-within-010.html](https://wpt.fyi/results/css/selectors/focus-within-010.html "css/selectors/focus-within-010.html")
 [[(live
 test)]](http://wpt.live/css/selectors/focus-within-010.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/focus-within-010.html)
- [focus-within-011.html](https://wpt.fyi/results/css/selectors/focus-within-011.html "css/selectors/focus-within-011.html")
 [[(live
 test)]](http://wpt.live/css/selectors/focus-within-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/focus-within-011.html)
- [focus-within-012.html](https://wpt.fyi/results/css/selectors/focus-within-012.html "css/selectors/focus-within-012.html")
 [[(live
 test)]](http://wpt.live/css/selectors/focus-within-012.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/focus-within-012.html)
- [focus-within-013.html](https://wpt.fyi/results/css/selectors/focus-within-013.html "css/selectors/focus-within-013.html")
 [[(live
 test)]](http://wpt.live/css/selectors/focus-within-013.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/focus-within-013.html)
- [focus-within-display-none-001.html](https://wpt.fyi/results/css/selectors/focus-within-display-none-001.html "css/selectors/focus-within-display-none-001.html")
 [[(live
 test)]](http://wpt.live/css/selectors/focus-within-display-none-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/focus-within-display-none-001.html)
- [focus-within-focus-move.html](https://wpt.fyi/results/css/selectors/focus-within-focus-move.html "css/selectors/focus-within-focus-move.html")
 [[(live
 test)]](http://wpt.live/css/selectors/focus-within-focus-move.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/focus-within-focus-move.html)
- [focus-within-removal.html](https://wpt.fyi/results/css/selectors/focus-within-removal.html "css/selectors/focus-within-removal.html")
 [[(live
 test)]](http://wpt.live/css/selectors/focus-within-removal.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/focus-within-removal.html)
- [focus-within-shadow-001.html](https://wpt.fyi/results/css/selectors/focus-within-shadow-001.html "css/selectors/focus-within-shadow-001.html")
 [[(live
 test)]](http://wpt.live/css/selectors/focus-within-shadow-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/focus-within-shadow-001.html)
- [focus-within-shadow-002.html](https://wpt.fyi/results/css/selectors/focus-within-shadow-002.html "css/selectors/focus-within-shadow-002.html")
 [[(live
 test)]](http://wpt.live/css/selectors/focus-within-shadow-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/focus-within-shadow-002.html)
- [focus-within-shadow-003.html](https://wpt.fyi/results/css/selectors/focus-within-shadow-003.html "css/selectors/focus-within-shadow-003.html")
 [[(live
 test)]](http://wpt.live/css/selectors/focus-within-shadow-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/focus-within-shadow-003.html)
- [focus-within-shadow-004.html](https://wpt.fyi/results/css/selectors/focus-within-shadow-004.html "css/selectors/focus-within-shadow-004.html")
 [[(live
 test)]](http://wpt.live/css/selectors/focus-within-shadow-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/focus-within-shadow-004.html)
- [focus-within-shadow-005.html](https://wpt.fyi/results/css/selectors/focus-within-shadow-005.html "css/selectors/focus-within-shadow-005.html")
 [[(live
 test)]](http://wpt.live/css/selectors/focus-within-shadow-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/focus-within-shadow-005.html)
- [focus-within-shadow-006.html](https://wpt.fyi/results/css/selectors/focus-within-shadow-006.html "css/selectors/focus-within-shadow-006.html")
 [[(live
 test)]](http://wpt.live/css/selectors/focus-within-shadow-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/focus-within-shadow-006.html)

The [:focus-within] pseudo-class applies to any element (or
pseudo-element) for which the
[:focus](#focus-pseudo)
pseudo-class applies, as well as to an element (or pseudo-element) whose
descendant in the [flat
tree](https://drafts.csswg.org/css-shadow-1/#flat-tree) (including non-element nodes, such as text nodes)
matches the conditions for matching [:focus].

## 10. Resource State Pseudo-classes

The pseudo-classes in this section apply to elements that represent
loaded resources, particularly images/videos, and allow authors to
select them based on some quality of their state.

### 10.1. Media Playback State: the [:playing, [:paused](#selectordef-paused), and [:seeking](#selectordef-seeking) pseudo-classes]
Tests

- [media-playback-state.html](https://wpt.fyi/results/css/selectors/media/media-playback-state.html "css/selectors/media/media-playback-state.html")
 [[(live
 test)]](http://wpt.live/css/selectors/media/media-playback-state.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/media/media-playback-state.html)
- [media-loading-state.sub.html](https://wpt.fyi/results/css/selectors/media/media-loading-state.sub.html "css/selectors/media/media-loading-state.sub.html")
 [[(live
 test)]](http://wpt.live/css/selectors/media/media-loading-state.sub.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/media/media-loading-state.sub.html)
- [media-playing-paused-style-invalidation.html](https://wpt.fyi/results/css/selectors/media/media-playing-paused-style-invalidation.html "css/selectors/media/media-playing-paused-style-invalidation.html")
 [[(live
 test)]](http://wpt.live/css/selectors/media/media-playing-paused-style-invalidation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/media/media-playing-paused-style-invalidation.html)

The [:playing] pseudo-class represents an element that
is capable of being "played" or "paused", when that element is
"playing". (This includes both when the element is explicitly playing,
and when it's temporarily stopped for some reason not connected to user
intent, but will automatically resume when that reason is resolved, such
as a "buffering" or "stalled" state.)

The [:paused] pseudo-class represents an element that
is capable of being "played" or "paused", when that element is "paused"
(i.e. *not* "playing"). (This includes both an explicit "paused" state,
and other non-playing states like "loaded, hasn't been activated yet",
etc.)

The [:seeking] pseudo-class represents an element that
is capable of "seeking" when that element is "seeking". (For the
[`audio`](https://html.spec.whatwg.org/multipage/media.html#audio) and
[`video`](https://html.spec.whatwg.org/multipage/media.html#video) elements of HTML, see [HTML § 4.8.11.9
Seeking](https://html.spec.whatwg.org/multipage/media.html#seeking).)

### 10.2. Media Loading State: the [:buffering and [:stalled](#selectordef-stalled) pseudo-classes]
Tests

- [media-loading-state-timing.sub.html](https://wpt.fyi/results/css/selectors/media/media-loading-state-timing.sub.html "css/selectors/media/media-loading-state-timing.sub.html")
 [[(live
 test)]](http://wpt.live/css/selectors/media/media-loading-state-timing.sub.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/media/media-loading-state-timing.sub.html)
- [media-playback-state-timing.html](https://wpt.fyi/results/css/selectors/media/media-playback-state-timing.html "css/selectors/media/media-playback-state-timing.html")
 [[(live
 test)]](http://wpt.live/css/selectors/media/media-playback-state-timing.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/media/media-playback-state-timing.html)

The [:buffering] pseudo-class represents an element that
is capable of being "played" or "paused", when that element cannot
continue playing because it is actively attempting to obtain [media
data](https://html.spec.whatwg.org/multipage/media.html#media-data) but has not yet obtained enough data to resume
playback. (Note that the element is still considered to be "playing"
when it is "buffering". Whenever
[:buffering](#selectordef-buffering) matches an element,
[:playing](#selectordef-playing) also matches the element.)

The [:stalled] pseudo-class represents an element when
that element cannot continue playing because it is actively attempting
to obtain [media
data](https://html.spec.whatwg.org/multipage/media.html#media-data) but it has failed to receive any data for some amount
of time. For the
[`audio`](https://html.spec.whatwg.org/multipage/media.html#audio) and
[`video`](https://html.spec.whatwg.org/multipage/media.html#video) elements of HTML, this amount of time is the [media
element stall
timeout](https://html.spec.whatwg.org/multipage/media.html#stall-timeout).
[\[HTML\]](#biblio-html "HTML Standard") (Note that,
like with the
[:buffering](#selectordef-buffering) pseudo-class, the element is still considered to
be "playing" when it is "stalled". Whenever
[:stalled](#selectordef-stalled) matches an element,
[:playing](#selectordef-playing) also matches the element.)

### 10.3. Sound State: the [:muted and [:volume-locked](#selectordef-volume-locked) pseudo-classes]
Tests

- [sound-state.html](https://wpt.fyi/results/css/selectors/media/sound-state.html "css/selectors/media/sound-state.html")
 [[(live
 test)]](http://wpt.live/css/selectors/media/sound-state.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/media/sound-state.html)

The [:muted] pseudo-class represents an element that
is capable of making sound, but is currently "muted" (forced silent).
(For the
[`audio`](https://html.spec.whatwg.org/multipage/media.html#audio) and
[`video`](https://html.spec.whatwg.org/multipage/media.html#video) elements of HTML, see
[muted](https://html.spec.whatwg.org/multipage/media.html#concept-media-muted).
[\[HTML\]](#biblio-html "HTML Standard"))

The [:volume-locked] pseudo-class represents an element that
is capable of making sound, and currently has its volume \"locked\" by
the UA or the user, so the page author cannot change it. (For the
[`audio`](https://html.spec.whatwg.org/multipage/media.html#audio) and
[`video`](https://html.spec.whatwg.org/multipage/media.html#video) elements of HTML, see the algorithm for setting the
element's [effective media
volume](https://html.spec.whatwg.org/multipage/media.html#effective-media-volume).
[\[HTML\]](#biblio-html "HTML Standard"))

## 11. Element Display State Pseudo-classes

### 11.1. Collapse State: the [:open pseudo-class]
Tests

- [open-pseudo.html](https://wpt.fyi/results/css/selectors/open-pseudo.html "css/selectors/open-pseudo.html")
 [[(live
 test)]](http://wpt.live/css/selectors/open-pseudo.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/open-pseudo.html)
- [details-open-pseudo-001.html](https://wpt.fyi/results/css/selectors/selectors-4/details-open-pseudo-001.html "css/selectors/selectors-4/details-open-pseudo-001.html")
 [[(live
 test)]](http://wpt.live/css/selectors/selectors-4/details-open-pseudo-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/selectors-4/details-open-pseudo-001.html)
- [details-open-pseudo-002.html](https://wpt.fyi/results/css/selectors/selectors-4/details-open-pseudo-002.html "css/selectors/selectors-4/details-open-pseudo-002.html")
 [[(live
 test)]](http://wpt.live/css/selectors/selectors-4/details-open-pseudo-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/selectors-4/details-open-pseudo-002.html)
- [details-open-pseudo-003.html](https://wpt.fyi/results/css/selectors/selectors-4/details-open-pseudo-003.html "css/selectors/selectors-4/details-open-pseudo-003.html")
 [[(live
 test)]](http://wpt.live/css/selectors/selectors-4/details-open-pseudo-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/selectors-4/details-open-pseudo-003.html)

<!-- -->

- [input-element-pseudo-open.optional.html](https://wpt.fyi/results/css/css-pseudo/input-element-pseudo-open.optional.html "css/css-pseudo/input-element-pseudo-open.optional.html")
 [[(live
 test)]](http://wpt.live/css/css-pseudo/input-element-pseudo-open.optional.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-pseudo/input-element-pseudo-open.optional.html)

The [:open] pseudo-class represents an element that has both "open" and
"closed" states, and which is currently in the "open" state.

Exactly what "open" and "closed" mean is host-language specific, but
exemplified by elements such as HTML's
[`details`](https://html.spec.whatwg.org/multipage/interactive-elements.html#the-details-element),
[`select`](https://html.spec.whatwg.org/multipage/form-elements.html#the-select-element),
[`dialog`](https://html.spec.whatwg.org/multipage/interactive-elements.html#the-dialog-element), and
[`input`](https://html.spec.whatwg.org/multipage/input.html#the-input-element) elements, all of which can be toggled "open" to
display more content (or any content at all, in the case of
[`dialog`](https://html.spec.whatwg.org/multipage/interactive-elements.html#the-dialog-element)).

 Being "open" or "closed" is a semantic state. An
element not currently being displayed (for example, one that has
[visibility:
collapse](https://drafts.csswg.org/css-display-4/#propdef-visibility), or belongs to a [display:
none](https://drafts.csswg.org/css-display-3/#propdef-display) subtree) can still be "open" and will match
[:open](#selectordef-open).

 A \":closed\" pseudo-class might be added in the future
once the full set of things that support
[:open](#selectordef-open) is known.

### 11.2. Popover State: the [:popover-open pseudo-class]
Tests

- [popover-open-with-has-sibling-selector.html](https://wpt.fyi/results/css/selectors/popover-open-with-has-sibling-selector.html "css/selectors/popover-open-with-has-sibling-selector.html")
 [[(live
 test)]](http://wpt.live/css/selectors/popover-open-with-has-sibling-selector.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/popover-open-with-has-sibling-selector.html)

The [:popover-open] pseudo-class represents an element that
has both "popover-showing" and "popover-hidden" states and which is
currently in the "popover-showing" state.

 This is distinct from
[:open](#selectordef-open) because an element can have element-specific open and
closed states and also have separate popover-showing and popover-hidden
states associated with being a popover.

Exactly what "popover-showing" and "popover-hidden" states mean is
host-language specific, but is exemplified by the presence of the HTML
[`popover`](https://html.spec.whatwg.org/multipage/popover.html#attr-popover) attribute and the associated [popover
visibility
state](https://html.spec.whatwg.org/multipage/popover.html#popover-visibility-state).

### 11.3. Modal (Exclusive Interaction) State: the [:modal pseudo-class]
Tests

- [modal-pseudo-class.html](https://wpt.fyi/results/css/selectors/modal-pseudo-class.html "css/selectors/modal-pseudo-class.html")
 [[(live
 test)]](http://wpt.live/css/selectors/modal-pseudo-class.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/modal-pseudo-class.html)

The [:modal] pseudo-class represents an element which
is in a state that excludes all interaction with elements outside it
until it has been dismissed. Multiple elements can be
[:modal](#selectordef-modal) simultaneously, with only one of them active (able to
receive input).

For example, the
[`dialog`](https://html.spec.whatwg.org/multipage/interactive-elements.html#the-dialog-element) element is
[:modal](#selectordef-modal) when opened with the
[`showModal()`](https://html.spec.whatwg.org/multipage/interactive-elements.html#dom-dialog-showmodal) API. Similarly, a
[:fullscreen](#selectordef-fullscreen) element is also
[:modal] when opened with the
[`requestFullscreen()`](https://fullscreen.spec.whatwg.org/#dom-element-requestfullscreen) API, since this prevents interaction with the rest of
the page.

### 11.4. Fullscreen Presentation State: the [:fullscreen pseudo-class]
The [:fullscreen] pseudo-class represents an element which
is displayed in a mode that takes up most (usually all) of the screen,
such as that defined by the Fullscreen API.
[\[FULLSCREEN\]](#biblio-fullscreen "Fullscreen API Standard")

### 11.5. Picture-in-Picture Presentation State: the [:picture-in-picture pseudo-class]
The [:picture-in-picture] pseudo-class represents an
element whose contents are being displayed in a "picture-in-picture"
mode (i.e. displayed in a window confined to part of the screen and
overlaying other content) rather than embedded in the document. For
example, this pseudo-class can be used to style a
[`video`](https://html.spec.whatwg.org/multipage/media.html#video) element's box while its contents are being played
in an overlaid window using the Picture-in-Picture API.
[\[picture-in-picture\]](#biblio-picture-in-picture "Picture-in-Picture")

## 12. The Input Pseudo-classes

The pseudo-classes in this section mostly apply to elements that take
user input, such as HTML's
[input](https://html.spec.whatwg.org/multipage/input.html#the-input-element) element.

### 12.1. Input Control States

#### 12.1.1. The [:enabled and [:disabled](#disabled-pseudo) Pseudo-classes]
Tests

- [enabled-disabled.html](https://wpt.fyi/results/css/selectors/invalidation/enabled-disabled.html "css/selectors/invalidation/enabled-disabled.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/enabled-disabled.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/enabled-disabled.html)
- [option-disabled-when-ancestor-changes.html](https://wpt.fyi/results/css/selectors/invalidation/option-disabled-when-ancestor-changes.html "css/selectors/invalidation/option-disabled-when-ancestor-changes.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/option-disabled-when-ancestor-changes.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/option-disabled-when-ancestor-changes.html)
- [pseudo-enabled-disabled.html](https://wpt.fyi/results/css/selectors/pseudo-enabled-disabled.html "css/selectors/pseudo-enabled-disabled.html")
 [[(live
 test)]](http://wpt.live/css/selectors/pseudo-enabled-disabled.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/pseudo-enabled-disabled.html)

The [:enabled] pseudo-class represents user interface
elements that are in an enabled state; such elements must have a
corresponding disabled state.

Conversely, the [:disabled] pseudo-class represents user interface
elements that are in a disabled state; such elements must have a
corresponding enabled state.

What constitutes an enabled state, a disabled state, and a user
interface element is host-language-dependent. In a typical document most
elements will be neither
[:enabled](#enabled-pseudo) nor
[:disabled](#disabled-pseudo). For example,
[\[HTML\]](#biblio-html "HTML Standard") defines
[non-disabled interactive
elements](https://html.spec.whatwg.org/multipage/semantics-other.html#selector-enabled)
to be [:enabled], and any such elements
that are [explicitly
disabled](https://html.spec.whatwg.org/multipage/semantics-other.html#selector-enabled)
to be [:disabled].

 CSS properties that might affect a user's ability to
interact with a given user interface element do not affect whether it
matches [:enabled](#enabled-pseudo) or
[:disabled](#disabled-pseudo); e.g., the
[display](https://drafts.csswg.org/css-display-3/#propdef-display) and
[visibility](https://drafts.csswg.org/css-display-4/#propdef-visibility) properties have no effect on the
enabled/disabled state of an element.

#### 12.1.2. The Mutability Pseudo-classes: [:read-only and [:read-write](#read-write-pseudo)]
Tests

- [selector-read-write-type-change-001.html](https://wpt.fyi/results/css/selectors/selector-read-write-type-change-001.html "css/selectors/selector-read-write-type-change-001.html")
 [[(live
 test)]](http://wpt.live/css/selectors/selector-read-write-type-change-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/selector-read-write-type-change-001.html)
- [selector-read-write-type-change-002.html](https://wpt.fyi/results/css/selectors/selector-read-write-type-change-002.html "css/selectors/selector-read-write-type-change-002.html")
 [[(live
 test)]](http://wpt.live/css/selectors/selector-read-write-type-change-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/selector-read-write-type-change-002.html)

An element matches [:read-write] if it is user-alterable, as
defined by the document language. Otherwise, it is
[:read-only].

For example, in
[\[HTML\]](#biblio-html "HTML Standard") a
[non-disabled non-readonly `<input>`
element](https://html.spec.whatwg.org/multipage/semantics-other.html#selector-read-only)
is [:read-write](#read-write-pseudo), as is any element with the `contenteditable`
attribute set to the true state.

#### 12.1.3. The Placeholder-shown Pseudo-class: [:placeholder-shown]
Tests

- [placeholder-shown.html](https://wpt.fyi/results/css/selectors/invalidation/placeholder-shown.html "css/selectors/invalidation/placeholder-shown.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/placeholder-shown.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/placeholder-shown.html)
- [placeholder-shown.html](https://wpt.fyi/results/css/selectors/placeholder-shown.html "css/selectors/placeholder-shown.html")
 [[(live
 test)]](http://wpt.live/css/selectors/placeholder-shown.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/placeholder-shown.html)
- [selector-placeholder-shown-emptify-placeholder.html](https://wpt.fyi/results/css/selectors/selector-placeholder-shown-emptify-placeholder.html "css/selectors/selector-placeholder-shown-emptify-placeholder.html")
 [[(live
 test)]](http://wpt.live/css/selectors/selector-placeholder-shown-emptify-placeholder.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/selector-placeholder-shown-emptify-placeholder.html)
- [selector-placeholder-shown-type-change-001.html](https://wpt.fyi/results/css/selectors/selector-placeholder-shown-type-change-001.html "css/selectors/selector-placeholder-shown-type-change-001.html")
 [[(live
 test)]](http://wpt.live/css/selectors/selector-placeholder-shown-type-change-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/selector-placeholder-shown-type-change-001.html)
- [selector-placeholder-shown-type-change-002.html](https://wpt.fyi/results/css/selectors/selector-placeholder-shown-type-change-002.html "css/selectors/selector-placeholder-shown-type-change-002.html")
 [[(live
 test)]](http://wpt.live/css/selectors/selector-placeholder-shown-type-change-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/selector-placeholder-shown-type-change-002.html)
- [selector-placeholder-shown-type-change-003.html](https://wpt.fyi/results/css/selectors/selector-placeholder-shown-type-change-003.html "css/selectors/selector-placeholder-shown-type-change-003.html")
 [[(live
 test)]](http://wpt.live/css/selectors/selector-placeholder-shown-type-change-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/selector-placeholder-shown-type-change-003.html)

Input elements can sometimes show placeholder text as a hint to the user
on what to type in. See, for example, the `placeholder` attribute in
[\[HTML\]](#biblio-html "HTML Standard"). The
[:placeholder-shown] pseudo-class matches an input element
that is showing such placeholder text, whether that text is given by an
attribute or a real element, or is otherwise implied by the UA.

For example, according to the
semantics of
[\[HTML\]](#biblio-html "HTML Standard") the
[`placeholder`](https://html.spec.whatwg.org/multipage/input.html#attr-input-placeholder) attribute on the
[`input`](https://html.spec.whatwg.org/multipage/input.html#the-input-element) and
[`textarea`](https://html.spec.whatwg.org/multipage/form-elements.html#the-textarea-element) elements provide placeholder text. The
[:placeholder-shown](#placeholder-shown-pseudo) class thus applies whenever such placeholder
text is shown.

#### 12.1.4. The Automatic Input Pseudo-class: [:autofill]
The [:autofill] pseudo-class represents input elements
that have been automatically filled by the user agent, and have not been
subsequently altered by the user.

#### 12.1.5. The Default-option Pseudo-class: [:default]
The [:default] pseudo-class applies to the one or more
UI elements that are the default among a set of similar elements.
Typically applies to context menu items, buttons and select lists/menus.

One example is the default submit button among a set of buttons. Another
example is the default option from a popup menu. In a select-many group
(such as for pizza toppings), multiple elements can match
[:default](#default-pseudo). For example,
[\[HTML\]](#biblio-html "HTML Standard") defines
that [:default] matches [the "default
button" in a form, the initially-selected `<option>`(s) in a `<select>`,
and a few other
elements.](https://html.spec.whatwg.org/multipage/semantics-other.html#selector-default)

### 12.2. Input Value States

#### 12.2.1. The Selected-option Pseudo-classes: [:checked, [:unchecked](#unchecked-pseudo), and [:indeterminate](#indeterminate-pseudo)]
Radio and checkbox elements can be toggled by the user, and some menu
items are "checked" when the user selects them. This state is reflected
by the [input value pseudo-classes].

When such elements are toggled "on" the [:checked] pseudo-class applies.
For example,
[\[HTML\]](#biblio-html "HTML Standard") defines
that [checked checkboxes, radio buttons, and selected `<option>`
elements](https://html.spec.whatwg.org/multipage/semantics-other.html#selector-checked)
match [:checked](#checked-pseudo). Similarly, when such elements are toggled "off", the
[:unchecked] pseudo-class applies.

If an element that *could* match
[:checked](#checked-pseudo) or
[:unchecked](#unchecked-pseudo) is neither \"on\" nor \"off\", the
[:indeterminate] pseudo-class applies.
[:indeterminate](#indeterminate-pseudo) also matches elements which do not have a notion
of being \"checked\", but whose \"value\" is still in an indeterminate
state, such as a progress meter whose progress percentage is unknown.

These three pseudo-classes are mutually exclusive; an element can only
match at most one of them at a time. (And might match none, if the
concept of being \"checked\" doesn't apply to them.) If the
\"indeterminate\" concept is not mutually exclusive with the
\"checked\"/\"unchecked\" concept in a host language (for example, in
HTML a checkbox's \"indeterminate\" state is a separate boolean from its
\"checked\" state boolean), being indeterminate wins over being
checked/unchecked for the purpose of matching these pseudo-classes.

For example, in HTML:

- Checkboxes match
 [:indeterminate](#indeterminate-pseudo) if their
 [`indeterminate`](https://html.spec.whatwg.org/multipage/input.html#dom-input-indeterminate) property is true; otherwise, they match
 [:checked](#checked-pseudo) or
 [:unchecked](#unchecked-pseudo) depending on their
 [`checked`](https://html.spec.whatwg.org/multipage/input.html#dom-input-checked) property.

- Radio buttons match
 [:checked](#checked-pseudo) if their
 [`checked`](https://html.spec.whatwg.org/multipage/input.html#dom-input-checked) property is true. Otherwise, they match
 [:unchecked](#unchecked-pseudo) if they're in a radio group that contains a
 [:checked] radio button. Otherwise
 (their
 [`checked`](https://html.spec.whatwg.org/multipage/input.html#dom-input-checked) property is false, but they're alone or in a radio
 group with no checked radio button), they match
 [:indeterminate](#indeterminate-pseudo).

- [`option`](https://html.spec.whatwg.org/multipage/form-elements.html#the-option-element) elements within a
 [`select`](https://html.spec.whatwg.org/multipage/form-elements.html#the-select-element) match
 [:checked](#checked-pseudo) or
 [:unchecked](#unchecked-pseudo) depending on their
 [`selected`](https://html.spec.whatwg.org/multipage/form-elements.html#dom-option-selected) property. (They're never
 [:indeterminate](#indeterminate-pseudo).)

- [`progress`](https://html.spec.whatwg.org/multipage/form-elements.html#the-progress-element) elements match
 [:indeterminate](#indeterminate-pseudo) if they lack a `value` attribute

While the [input value
pseudo-classes](#input-value-pseudo-classes) are dynamic in nature, and can altered by user action,
since they can also be based on the presence of semantic attributes in
the document (such as the `selected` and `checked` attributes in
[\[HTML\]](#biblio-html "HTML Standard")), they
apply to all media.

### 12.3. Input Value-checking

#### 12.3.1. The Validity Pseudo-classes: [:valid and [:invalid](#invalid-pseudo)]
An element is [:valid] or [:invalid] when its contents or value
is, respectively, valid or invalid with respect to data validity
semantics defined by the document language (e.g.
[\[XFORMS11\]](#biblio-xforms11 "XForms 1.1") or
[\[HTML\]](#biblio-html "HTML Standard")). An
element which lacks data validity semantics is neither
[:valid](#valid-pseudo)
nor [:invalid](#invalid-pseudo).

 There is a difference between an element which has no
constraints, and thus would always be
[:valid](#valid-pseudo),
and one which has no data validity semantics at all, and thus is neither
[:valid] nor
[:invalid](#invalid-pseudo). In HTML, for example, an `<input type="text">`
element may have no constraints, but a
[p](https://html.spec.whatwg.org/multipage/grouping-content.html#the-p-element) element has no validity semantics at all, and so it
never matches either of these pseudo-classes.

Tests

- [input-in-range-in-has-with-readonly.html](https://wpt.fyi/results/css/selectors/invalidation/input-in-range-in-has-with-readonly.html "css/selectors/invalidation/input-in-range-in-has-with-readonly.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/input-in-range-in-has-with-readonly.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/input-in-range-in-has-with-readonly.html)
- [media-loading-pseudo-classes-in-has.sub.html](https://wpt.fyi/results/css/selectors/invalidation/media-loading-pseudo-classes-in-has.sub.html "css/selectors/invalidation/media-loading-pseudo-classes-in-has.sub.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/media-loading-pseudo-classes-in-has.sub.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/media-loading-pseudo-classes-in-has.sub.html)

#### 12.3.2. The Range Pseudo-classes: [:in-range and [:out-of-range](#out-of-range-pseudo)]
The [:in-range] and [:out-of-range] pseudo-classes
apply only to elements that have range limitations. An element is
[:in-range](#in-range-pseudo) or
[:out-of-range](#out-of-range-pseudo) when the value that the element is bound to is in
range or out of range with respect to its range limits as defined by the
document language. An element that lacks data range limits or is not a
form control is neither [:in-range] nor
[:out-of-range]. E.g. a slider
element with a value of 11 presented as a slider control that only
represents the values from 1-10 is :out-of-range. Another example is a
menu element with a value of \"E\" that happens to be presented in a
popup menu that only has choices \"A\", \"B\" and \"C\".

#### 12.3.3. The Optionality Pseudo-classes: [:required and [:optional](#optional-pseudo)]
Tests

- [selector-required-type-change-001.html](https://wpt.fyi/results/css/selectors/selector-required-type-change-001.html "css/selectors/selector-required-type-change-001.html")
 [[(live
 test)]](http://wpt.live/css/selectors/selector-required-type-change-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/selector-required-type-change-001.html)
- [selector-required-type-change-002.html](https://wpt.fyi/results/css/selectors/selector-required-type-change-002.html "css/selectors/selector-required-type-change-002.html")
 [[(live
 test)]](http://wpt.live/css/selectors/selector-required-type-change-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/selector-required-type-change-002.html)
- [selector-required.html](https://wpt.fyi/results/css/selectors/selector-required.html "css/selectors/selector-required.html")
 [[(live
 test)]](http://wpt.live/css/selectors/selector-required.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/selector-required.html)

A form element is [:required] or [:optional] if a
value for it is, respectively, required or optional before the form it
belongs to can be validly submitted. Elements that are not form elements
are neither required nor optional.

#### 12.3.4. The User-interaction Pseudo-classes: [:user-valid and [:user-invalid](#user-invalid-pseudo)]
Tests

- [user-valid-user-invalid.html](https://wpt.fyi/results/css/selectors/invalidation/user-valid-user-invalid.html "css/selectors/invalidation/user-valid-user-invalid.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/user-valid-user-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/user-valid-user-invalid.html)
- [user-invalid-form-submission-invalidation.html](https://wpt.fyi/results/css/selectors/user-invalid-form-submission-invalidation.html "css/selectors/user-invalid-form-submission-invalidation.html")
 [[(live
 test)]](http://wpt.live/css/selectors/user-invalid-form-submission-invalidation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/user-invalid-form-submission-invalidation.html)
- [user-invalid.html](https://wpt.fyi/results/css/selectors/user-invalid.html "css/selectors/user-invalid.html")
 [[(live
 test)]](http://wpt.live/css/selectors/user-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/user-invalid.html)
- [user-valid.html](https://wpt.fyi/results/css/selectors/user-valid.html "css/selectors/user-valid.html")
 [[(live
 test)]](http://wpt.live/css/selectors/user-valid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/user-valid.html)
- [valid-invalid-form-fieldset.html](https://wpt.fyi/results/css/selectors/valid-invalid-form-fieldset.html "css/selectors/valid-invalid-form-fieldset.html")
 [[(live
 test)]](http://wpt.live/css/selectors/valid-invalid-form-fieldset.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/valid-invalid-form-fieldset.html)

The [:user-invalid] and the [:user-valid] pseudo-classes
represent an element with incorrect or correct input, respectively, but
only *after* the user has significantly interacted with it. Their
purpose is to help the user identify mistakes in their input.

These pseudo-classes must at least match their respective elements after
the user has attempted to submit the form and before the user has
interacted again with the input element or reset the form. They may also
match at other times, as would be appropriate for highlighting an error
to the user. For example,
[:user-invalid](#user-invalid-pseudo) could start matching an
[:invalid](#invalid-pseudo) input element once the user has changed its value and
focus has moved to another element; or stop matching only after the user
has successfully corrected the input.

Host languages may define more precise matching rules or defer to
platform conventions; otherwise the exact behavior is UA-defined.
Regardless, the
[:user-invalid](#user-invalid-pseudo) pseudo-class must only match
[:invalid](#invalid-pseudo) elements; and the
[:user-valid](#user-valid-pseudo) pseudo-class must only match
[:valid](#valid-pseudo)
elements. See the [HTML
specification](https://html.spec.whatwg.org/multipage/semantics-other.html#selector-user-invalid) for the specific rules pertaining to HTML
elements. [\[HTML\]](#biblio-html "HTML Standard")

For example, the
[`input`](https://html.spec.whatwg.org/multipage/input.html#the-input-element) element in the following document fragment would
match [:invalid](#invalid-pseudo) as soon as the page is loaded (because the
[`input`](https://html.spec.whatwg.org/multipage/input.html#the-input-element)'s initial value violates its max constraint) but it
won't match
[:user-invalid](#user-invalid-pseudo) until the user significantly interacts with the input
field or attempts to submit the form it's part of.

 <form>
 <label>
 Volume:
 <input name='vol' type=number min=0 max=10 value=11>
 </label>
 ...
 </form>

## 13. Tree-Structural pseudo-classes

Tests

- [selector-structural-pseudo-root.html](https://wpt.fyi/results/css/selectors/selector-structural-pseudo-root.html "css/selectors/selector-structural-pseudo-root.html")
 [[(live
 test)]](http://wpt.live/css/selectors/selector-structural-pseudo-root.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/selector-structural-pseudo-root.html)

Selectors introduces the concept of [structural
pseudo-classes] to permit selection based on extra information
that lies in the document tree but cannot be represented by other simple
selectors or combinators.

Standalone text and other non-element nodes are not counted when
calculating the position of an element in the list of children of its
parent. When calculating the position of an element in the list of
children of its parent, the index numbering starts at 1.

The [structural
pseudo-classes](#structural-pseudo-classes) only apply to elements in the document tree; they must
never match [pseudo-elements](#pseudo-element).

### 13.1. [:root pseudo-class]
Tests

- [root-siblings.html](https://wpt.fyi/results/css/selectors/root-siblings.html "css/selectors/root-siblings.html")
 [[(live
 test)]](http://wpt.live/css/selectors/root-siblings.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/root-siblings.html)

The [:root] pseudo-class represents an element that is the root of the
document.

For example, in a DOM document, the
[:root](#root-pseudo)
pseudo-class matches the [document
element](https://dom.spec.whatwg.org/#document-element). In HTML, this will be the
[`html`](https://html.spec.whatwg.org/multipage/semantics.html#the-html-element) element (unless scripting has been used to modify
the document).

### 13.2. [:empty pseudo-class]
Tests

- [selectors-empty-001.xml](https://wpt.fyi/results/css/selectors/selectors-empty-001.xml "css/selectors/selectors-empty-001.xml")
 [[(live
 test)]](http://wpt.live/css/selectors/selectors-empty-001.xml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/selectors-empty-001.xml)
- [empty-pseudo-in-has-display-none.html](https://wpt.fyi/results/css/selectors/invalidation/empty-pseudo-in-has-display-none.html "css/selectors/invalidation/empty-pseudo-in-has-display-none.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/empty-pseudo-in-has-display-none.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/empty-pseudo-in-has-display-none.html)

The [:empty] pseudo-class represents an element that has no children
except, optionally, [document white space
characters](https://drafts.csswg.org/css-text-4/#white-space). In terms of the document tree, only element nodes and
content nodes (such as
[\[DOM\]](#biblio-dom "DOM Standard") text nodes,
and entity references) whose data has a non-zero length must be
considered as affecting emptiness; comments, processing instructions,
and other nodes must not affect whether an element is considered empty
or not.

Examples: [p:empty] is a valid
representation of the
[`p`](https://html.spec.whatwg.org/multipage/grouping-content.html#the-p-element) elements in the following HTML fragment:

``` html
<p></p>
<p>
<p> </p>
<p> <!-- comment --></p>
```

[div:empty] is not a valid representation of the `<div>` elements
in the following fragment:

``` html
<div>text</div>
<div><p></p></div>
<div>&nbsp;</div>
<div><p>bla</p></div>
<div>this is not <p>:empty</p></div>
```

 In Level 2 and Level 3 of Selectors,
[:empty](#empty-pseudo)
did not match elements that contained only white space. This was changed
so that that---​given white space is largely collapsible in HTML and is
therefore used for source code formatting, and especially because
elements with omitted end tags are likely to absorb such white space
into their DOM text contents---​elements which authors perceive of as
empty can be selected by this selector, as they expect.

### 13.3. Child-indexed Pseudo-classes

Tests

- [child-indexed-during-parse.html](https://wpt.fyi/results/css/selectors/child-indexed-during-parse.html "css/selectors/child-indexed-during-parse.html")
 [[(live
 test)]](http://wpt.live/css/selectors/child-indexed-during-parse.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/child-indexed-during-parse.html)
- [child-indexed-no-parent.html](https://wpt.fyi/results/css/selectors/child-indexed-no-parent.html "css/selectors/child-indexed-no-parent.html")
 [[(live
 test)]](http://wpt.live/css/selectors/child-indexed-no-parent.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/child-indexed-no-parent.html)
- [child-indexed-pseudo-class.html](https://wpt.fyi/results/css/selectors/child-indexed-pseudo-class.html "css/selectors/child-indexed-pseudo-class.html")
 [[(live
 test)]](http://wpt.live/css/selectors/child-indexed-pseudo-class.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/child-indexed-pseudo-class.html)
- [negated-nth-child-when-ancestor-changes.html](https://wpt.fyi/results/css/selectors/invalidation/negated-nth-child-when-ancestor-changes.html "css/selectors/invalidation/negated-nth-child-when-ancestor-changes.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/negated-nth-child-when-ancestor-changes.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/negated-nth-child-when-ancestor-changes.html)
- [negated-nth-last-child-when-ancestor-changes.html](https://wpt.fyi/results/css/selectors/invalidation/negated-nth-last-child-when-ancestor-changes.html "css/selectors/invalidation/negated-nth-last-child-when-ancestor-changes.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/negated-nth-last-child-when-ancestor-changes.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/negated-nth-last-child-when-ancestor-changes.html)
- [nth-child-containing-ancestor.html](https://wpt.fyi/results/css/selectors/invalidation/nth-child-containing-ancestor.html "css/selectors/invalidation/nth-child-containing-ancestor.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/nth-child-containing-ancestor.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/nth-child-containing-ancestor.html)
- [nth-child-in-shadow-root.html](https://wpt.fyi/results/css/selectors/invalidation/nth-child-in-shadow-root.html "css/selectors/invalidation/nth-child-in-shadow-root.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/nth-child-in-shadow-root.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/nth-child-in-shadow-root.html)
- [nth-child-of-attr-largedom.html](https://wpt.fyi/results/css/selectors/invalidation/nth-child-of-attr-largedom.html "css/selectors/invalidation/nth-child-of-attr-largedom.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/nth-child-of-attr-largedom.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/nth-child-of-attr-largedom.html)
- [nth-child-of-attr.html](https://wpt.fyi/results/css/selectors/invalidation/nth-child-of-attr.html "css/selectors/invalidation/nth-child-of-attr.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/nth-child-of-attr.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/nth-child-of-attr.html)
- [nth-child-of-class-prefix.html](https://wpt.fyi/results/css/selectors/invalidation/nth-child-of-class-prefix.html "css/selectors/invalidation/nth-child-of-class-prefix.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/nth-child-of-class-prefix.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/nth-child-of-class-prefix.html)
- [nth-child-of-class.html](https://wpt.fyi/results/css/selectors/invalidation/nth-child-of-class.html "css/selectors/invalidation/nth-child-of-class.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/nth-child-of-class.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/nth-child-of-class.html)
- [nth-child-of-has.html](https://wpt.fyi/results/css/selectors/invalidation/nth-child-of-has.html "css/selectors/invalidation/nth-child-of-has.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/nth-child-of-has.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/nth-child-of-has.html)
- [nth-child-of-id-prefix.html](https://wpt.fyi/results/css/selectors/invalidation/nth-child-of-id-prefix.html "css/selectors/invalidation/nth-child-of-id-prefix.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/nth-child-of-id-prefix.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/nth-child-of-id-prefix.html)
- [nth-child-of-ids.html](https://wpt.fyi/results/css/selectors/invalidation/nth-child-of-ids.html "css/selectors/invalidation/nth-child-of-ids.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/nth-child-of-ids.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/nth-child-of-ids.html)
- [nth-child-of-in-ancestor.html](https://wpt.fyi/results/css/selectors/invalidation/nth-child-of-in-ancestor.html "css/selectors/invalidation/nth-child-of-in-ancestor.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/nth-child-of-in-ancestor.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/nth-child-of-in-ancestor.html)
- [nth-child-of-in-is.html](https://wpt.fyi/results/css/selectors/invalidation/nth-child-of-in-is.html "css/selectors/invalidation/nth-child-of-in-is.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/nth-child-of-in-is.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/nth-child-of-in-is.html)
- [nth-child-of-in-shadow-root.html](https://wpt.fyi/results/css/selectors/invalidation/nth-child-of-in-shadow-root.html "css/selectors/invalidation/nth-child-of-in-shadow-root.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/nth-child-of-in-shadow-root.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/nth-child-of-in-shadow-root.html)
- [nth-child-of-is.html](https://wpt.fyi/results/css/selectors/invalidation/nth-child-of-is.html "css/selectors/invalidation/nth-child-of-is.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/nth-child-of-is.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/nth-child-of-is.html)
- [nth-child-of-pseudo-class.html](https://wpt.fyi/results/css/selectors/invalidation/nth-child-of-pseudo-class.html "css/selectors/invalidation/nth-child-of-pseudo-class.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/nth-child-of-pseudo-class.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/nth-child-of-pseudo-class.html)
- [nth-child-of-sibling.html](https://wpt.fyi/results/css/selectors/invalidation/nth-child-of-sibling.html "css/selectors/invalidation/nth-child-of-sibling.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/nth-child-of-sibling.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/nth-child-of-sibling.html)
- [nth-child-when-ancestor-changes.html](https://wpt.fyi/results/css/selectors/invalidation/nth-child-when-ancestor-changes.html "css/selectors/invalidation/nth-child-when-ancestor-changes.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/nth-child-when-ancestor-changes.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/nth-child-when-ancestor-changes.html)
- [nth-child-when-sibling-changes.html](https://wpt.fyi/results/css/selectors/invalidation/nth-child-when-sibling-changes.html "css/selectors/invalidation/nth-child-when-sibling-changes.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/nth-child-when-sibling-changes.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/nth-child-when-sibling-changes.html)
- [nth-child-whole-subtree.html](https://wpt.fyi/results/css/selectors/invalidation/nth-child-whole-subtree.html "css/selectors/invalidation/nth-child-whole-subtree.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/nth-child-whole-subtree.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/nth-child-whole-subtree.html)
- [nth-last-child-containing-ancestor.html](https://wpt.fyi/results/css/selectors/invalidation/nth-last-child-containing-ancestor.html "css/selectors/invalidation/nth-last-child-containing-ancestor.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/nth-last-child-containing-ancestor.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/nth-last-child-containing-ancestor.html)
- [nth-last-child-in-shadow-root.html](https://wpt.fyi/results/css/selectors/invalidation/nth-last-child-in-shadow-root.html "css/selectors/invalidation/nth-last-child-in-shadow-root.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/nth-last-child-in-shadow-root.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/nth-last-child-in-shadow-root.html)
- [nth-last-child-of-attr.html](https://wpt.fyi/results/css/selectors/invalidation/nth-last-child-of-attr.html "css/selectors/invalidation/nth-last-child-of-attr.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/nth-last-child-of-attr.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/nth-last-child-of-attr.html)
- [nth-last-child-of-class-prefix.html](https://wpt.fyi/results/css/selectors/invalidation/nth-last-child-of-class-prefix.html "css/selectors/invalidation/nth-last-child-of-class-prefix.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/nth-last-child-of-class-prefix.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/nth-last-child-of-class-prefix.html)
- [nth-last-child-of-class.html](https://wpt.fyi/results/css/selectors/invalidation/nth-last-child-of-class.html "css/selectors/invalidation/nth-last-child-of-class.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/nth-last-child-of-class.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/nth-last-child-of-class.html)
- [nth-last-child-of-has.html](https://wpt.fyi/results/css/selectors/invalidation/nth-last-child-of-has.html "css/selectors/invalidation/nth-last-child-of-has.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/nth-last-child-of-has.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/nth-last-child-of-has.html)
- [nth-last-child-of-id-prefix.html](https://wpt.fyi/results/css/selectors/invalidation/nth-last-child-of-id-prefix.html "css/selectors/invalidation/nth-last-child-of-id-prefix.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/nth-last-child-of-id-prefix.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/nth-last-child-of-id-prefix.html)
- [nth-last-child-of-ids.html](https://wpt.fyi/results/css/selectors/invalidation/nth-last-child-of-ids.html "css/selectors/invalidation/nth-last-child-of-ids.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/nth-last-child-of-ids.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/nth-last-child-of-ids.html)
- [nth-last-child-of-in-ancestor.html](https://wpt.fyi/results/css/selectors/invalidation/nth-last-child-of-in-ancestor.html "css/selectors/invalidation/nth-last-child-of-in-ancestor.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/nth-last-child-of-in-ancestor.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/nth-last-child-of-in-ancestor.html)
- [nth-last-child-of-in-is.html](https://wpt.fyi/results/css/selectors/invalidation/nth-last-child-of-in-is.html "css/selectors/invalidation/nth-last-child-of-in-is.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/nth-last-child-of-in-is.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/nth-last-child-of-in-is.html)
- [nth-last-child-of-in-shadow-root.html](https://wpt.fyi/results/css/selectors/invalidation/nth-last-child-of-in-shadow-root.html "css/selectors/invalidation/nth-last-child-of-in-shadow-root.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/nth-last-child-of-in-shadow-root.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/nth-last-child-of-in-shadow-root.html)
- [nth-last-child-of-is.html](https://wpt.fyi/results/css/selectors/invalidation/nth-last-child-of-is.html "css/selectors/invalidation/nth-last-child-of-is.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/nth-last-child-of-is.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/nth-last-child-of-is.html)
- [nth-last-child-of-pseudo-class.html](https://wpt.fyi/results/css/selectors/invalidation/nth-last-child-of-pseudo-class.html "css/selectors/invalidation/nth-last-child-of-pseudo-class.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/nth-last-child-of-pseudo-class.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/nth-last-child-of-pseudo-class.html)
- [nth-last-child-of-sibling.html](https://wpt.fyi/results/css/selectors/invalidation/nth-last-child-of-sibling.html "css/selectors/invalidation/nth-last-child-of-sibling.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/nth-last-child-of-sibling.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/nth-last-child-of-sibling.html)
- [nth-last-child-when-ancestor-changes.html](https://wpt.fyi/results/css/selectors/invalidation/nth-last-child-when-ancestor-changes.html "css/selectors/invalidation/nth-last-child-when-ancestor-changes.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/nth-last-child-when-ancestor-changes.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/nth-last-child-when-ancestor-changes.html)
- [nth-last-child-when-sibling-changes.html](https://wpt.fyi/results/css/selectors/invalidation/nth-last-child-when-sibling-changes.html "css/selectors/invalidation/nth-last-child-when-sibling-changes.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/nth-last-child-when-sibling-changes.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/nth-last-child-when-sibling-changes.html)
- [nth-child-and-nth-last-child.html](https://wpt.fyi/results/css/selectors/nth-child-and-nth-last-child.html "css/selectors/nth-child-and-nth-last-child.html")
 [[(live
 test)]](http://wpt.live/css/selectors/nth-child-and-nth-last-child.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/nth-child-and-nth-last-child.html)
- [nth-child-large-anplusb-clamp.html](https://wpt.fyi/results/css/selectors/nth-child-large-anplusb-clamp.html "css/selectors/nth-child-large-anplusb-clamp.html")
 [[(live
 test)]](http://wpt.live/css/selectors/nth-child-large-anplusb-clamp.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/nth-child-large-anplusb-clamp.html)
- [nth-child-of-attribute.html](https://wpt.fyi/results/css/selectors/nth-child-of-attribute.html "css/selectors/nth-child-of-attribute.html")
 [[(live
 test)]](http://wpt.live/css/selectors/nth-child-of-attribute.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/nth-child-of-attribute.html)
- [nth-child-of-classname-002.html](https://wpt.fyi/results/css/selectors/nth-child-of-classname-002.html "css/selectors/nth-child-of-classname-002.html")
 [[(live
 test)]](http://wpt.live/css/selectors/nth-child-of-classname-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/nth-child-of-classname-002.html)
- [nth-child-of-classname.html](https://wpt.fyi/results/css/selectors/nth-child-of-classname.html "css/selectors/nth-child-of-classname.html")
 [[(live
 test)]](http://wpt.live/css/selectors/nth-child-of-classname.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/nth-child-of-classname.html)
- [nth-child-of-complex-selector-many-children-2.html](https://wpt.fyi/results/css/selectors/nth-child-of-complex-selector-many-children-2.html "css/selectors/nth-child-of-complex-selector-many-children-2.html")
 [[(live
 test)]](http://wpt.live/css/selectors/nth-child-of-complex-selector-many-children-2.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/nth-child-of-complex-selector-many-children-2.html)
- [nth-child-of-complex-selector-many-children.html](https://wpt.fyi/results/css/selectors/nth-child-of-complex-selector-many-children.html "css/selectors/nth-child-of-complex-selector-many-children.html")
 [[(live
 test)]](http://wpt.live/css/selectors/nth-child-of-complex-selector-many-children.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/nth-child-of-complex-selector-many-children.html)
- [nth-child-of-complex-selector.html](https://wpt.fyi/results/css/selectors/nth-child-of-complex-selector.html "css/selectors/nth-child-of-complex-selector.html")
 [[(live
 test)]](http://wpt.live/css/selectors/nth-child-of-complex-selector.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/nth-child-of-complex-selector.html)
- [nth-child-of-compound-selector.html](https://wpt.fyi/results/css/selectors/nth-child-of-compound-selector.html "css/selectors/nth-child-of-compound-selector.html")
 [[(live
 test)]](http://wpt.live/css/selectors/nth-child-of-compound-selector.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/nth-child-of-compound-selector.html)
- [nth-child-of-has.html](https://wpt.fyi/results/css/selectors/nth-child-of-has.html "css/selectors/nth-child-of-has.html")
 [[(live
 test)]](http://wpt.live/css/selectors/nth-child-of-has.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/nth-child-of-has.html)
- [nth-child-of-nesting.html](https://wpt.fyi/results/css/selectors/nth-child-of-nesting.html "css/selectors/nth-child-of-nesting.html")
 [[(live
 test)]](http://wpt.live/css/selectors/nth-child-of-nesting.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/nth-child-of-nesting.html)
- [nth-child-of-no-space-after-of.html](https://wpt.fyi/results/css/selectors/nth-child-of-no-space-after-of.html "css/selectors/nth-child-of-no-space-after-of.html")
 [[(live
 test)]](http://wpt.live/css/selectors/nth-child-of-no-space-after-of.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/nth-child-of-no-space-after-of.html)
- [nth-child-of-not.html](https://wpt.fyi/results/css/selectors/nth-child-of-not.html "css/selectors/nth-child-of-not.html")
 [[(live
 test)]](http://wpt.live/css/selectors/nth-child-of-not.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/nth-child-of-not.html)
- [nth-child-of-nth-child.html](https://wpt.fyi/results/css/selectors/nth-child-of-nth-child.html "css/selectors/nth-child-of-nth-child.html")
 [[(live
 test)]](http://wpt.live/css/selectors/nth-child-of-nth-child.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/nth-child-of-nth-child.html)
- [nth-child-of-pseudo.html](https://wpt.fyi/results/css/selectors/nth-child-of-pseudo.html "css/selectors/nth-child-of-pseudo.html")
 [[(live
 test)]](http://wpt.live/css/selectors/nth-child-of-pseudo.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/nth-child-of-pseudo.html)
- [nth-child-of-tagname.html](https://wpt.fyi/results/css/selectors/nth-child-of-tagname.html "css/selectors/nth-child-of-tagname.html")
 [[(live
 test)]](http://wpt.live/css/selectors/nth-child-of-tagname.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/nth-child-of-tagname.html)
- [nth-child-of-universal-selector.html](https://wpt.fyi/results/css/selectors/nth-child-of-universal-selector.html "css/selectors/nth-child-of-universal-selector.html")
 [[(live
 test)]](http://wpt.live/css/selectors/nth-child-of-universal-selector.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/nth-child-of-universal-selector.html)
- [nth-child-specificity-1.html](https://wpt.fyi/results/css/selectors/nth-child-specificity-1.html "css/selectors/nth-child-specificity-1.html")
 [[(live
 test)]](http://wpt.live/css/selectors/nth-child-specificity-1.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/nth-child-specificity-1.html)
- [nth-child-specificity-2.html](https://wpt.fyi/results/css/selectors/nth-child-specificity-2.html "css/selectors/nth-child-specificity-2.html")
 [[(live
 test)]](http://wpt.live/css/selectors/nth-child-specificity-2.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/nth-child-specificity-2.html)
- [nth-child-specificity-3.html](https://wpt.fyi/results/css/selectors/nth-child-specificity-3.html "css/selectors/nth-child-specificity-3.html")
 [[(live
 test)]](http://wpt.live/css/selectors/nth-child-specificity-3.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/nth-child-specificity-3.html)
- [nth-child-specificity-4.html](https://wpt.fyi/results/css/selectors/nth-child-specificity-4.html "css/selectors/nth-child-specificity-4.html")
 [[(live
 test)]](http://wpt.live/css/selectors/nth-child-specificity-4.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/nth-child-specificity-4.html)
- [nth-child-spurious-brace-crash.html](https://wpt.fyi/results/css/selectors/nth-child-spurious-brace-crash.html "css/selectors/nth-child-spurious-brace-crash.html")
 [[(live
 test)]](http://wpt.live/css/selectors/nth-child-spurious-brace-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/nth-child-spurious-brace-crash.html)
- [nth-last-child-invalid.html](https://wpt.fyi/results/css/selectors/nth-last-child-invalid.html "css/selectors/nth-last-child-invalid.html")
 [[(live
 test)]](http://wpt.live/css/selectors/nth-last-child-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/nth-last-child-invalid.html)
- [nth-last-child-of-classname.html](https://wpt.fyi/results/css/selectors/nth-last-child-of-classname.html "css/selectors/nth-last-child-of-classname.html")
 [[(live
 test)]](http://wpt.live/css/selectors/nth-last-child-of-classname.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/nth-last-child-of-classname.html)
- [nth-last-child-of-complex-selector.html](https://wpt.fyi/results/css/selectors/nth-last-child-of-complex-selector.html "css/selectors/nth-last-child-of-complex-selector.html")
 [[(live
 test)]](http://wpt.live/css/selectors/nth-last-child-of-complex-selector.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/nth-last-child-of-complex-selector.html)
- [nth-last-child-of-compound-selector.html](https://wpt.fyi/results/css/selectors/nth-last-child-of-compound-selector.html "css/selectors/nth-last-child-of-compound-selector.html")
 [[(live
 test)]](http://wpt.live/css/selectors/nth-last-child-of-compound-selector.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/nth-last-child-of-compound-selector.html)
- [nth-last-child-of-nesting.html](https://wpt.fyi/results/css/selectors/nth-last-child-of-nesting.html "css/selectors/nth-last-child-of-nesting.html")
 [[(live
 test)]](http://wpt.live/css/selectors/nth-last-child-of-nesting.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/nth-last-child-of-nesting.html)
- [nth-last-child-of-no-space-after-of.html](https://wpt.fyi/results/css/selectors/nth-last-child-of-no-space-after-of.html "css/selectors/nth-last-child-of-no-space-after-of.html")
 [[(live
 test)]](http://wpt.live/css/selectors/nth-last-child-of-no-space-after-of.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/nth-last-child-of-no-space-after-of.html)
- [nth-last-child-of-style-sharing-1.html](https://wpt.fyi/results/css/selectors/nth-last-child-of-style-sharing-1.html "css/selectors/nth-last-child-of-style-sharing-1.html")
 [[(live
 test)]](http://wpt.live/css/selectors/nth-last-child-of-style-sharing-1.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/nth-last-child-of-style-sharing-1.html)
- [nth-last-child-of-style-sharing-2.html](https://wpt.fyi/results/css/selectors/nth-last-child-of-style-sharing-2.html "css/selectors/nth-last-child-of-style-sharing-2.html")
 [[(live
 test)]](http://wpt.live/css/selectors/nth-last-child-of-style-sharing-2.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/nth-last-child-of-style-sharing-2.html)
- [nth-last-child-of-tagname.html](https://wpt.fyi/results/css/selectors/nth-last-child-of-tagname.html "css/selectors/nth-last-child-of-tagname.html")
 [[(live
 test)]](http://wpt.live/css/selectors/nth-last-child-of-tagname.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/nth-last-child-of-tagname.html)
- [nth-last-child-specificity-1.html](https://wpt.fyi/results/css/selectors/nth-last-child-specificity-1.html "css/selectors/nth-last-child-specificity-1.html")
 [[(live
 test)]](http://wpt.live/css/selectors/nth-last-child-specificity-1.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/nth-last-child-specificity-1.html)
- [nth-last-child-specificity-2.html](https://wpt.fyi/results/css/selectors/nth-last-child-specificity-2.html "css/selectors/nth-last-child-specificity-2.html")
 [[(live
 test)]](http://wpt.live/css/selectors/nth-last-child-specificity-2.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/nth-last-child-specificity-2.html)
- [nth-last-child-specificity-3.html](https://wpt.fyi/results/css/selectors/nth-last-child-specificity-3.html "css/selectors/nth-last-child-specificity-3.html")
 [[(live
 test)]](http://wpt.live/css/selectors/nth-last-child-specificity-3.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/nth-last-child-specificity-3.html)
- [nth-last-child-specificity-4.html](https://wpt.fyi/results/css/selectors/nth-last-child-specificity-4.html "css/selectors/nth-last-child-specificity-4.html")
 [[(live
 test)]](http://wpt.live/css/selectors/nth-last-child-specificity-4.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/nth-last-child-specificity-4.html)
- [sharing-in-svg-use.html](https://wpt.fyi/results/css/selectors/sharing-in-svg-use.html "css/selectors/sharing-in-svg-use.html")
 [[(live
 test)]](http://wpt.live/css/selectors/sharing-in-svg-use.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/sharing-in-svg-use.html)
- [parse-anplusb.html](https://wpt.fyi/results/css/selectors/parsing/parse-anplusb.html "css/selectors/parsing/parse-anplusb.html")
 [[(live
 test)]](http://wpt.live/css/selectors/parsing/parse-anplusb.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/parsing/parse-anplusb.html)

The pseudo-classes defined in this section select elements based on
their index amongst their [inclusive
siblings](https://dom.spec.whatwg.org/#concept-tree-inclusive-sibling).

 Selectors 3 described these selectors as selecting
elements based on their index in the child list of their parents. (This
description survives in the name of this very section, and the names of
several of the pseudo-classes.) As there was no reason to exclude them
from matching elements without parents, or with non-element parents,
they have been rephrased to refer to an element's relative index amongst
its siblings.

#### 13.3.1. [:nth-child() pseudo-class]
Tests

- [nth-of-invalid.html](https://wpt.fyi/results/css/selectors/nth-of-invalid.html "css/selectors/nth-of-invalid.html")
 [[(live
 test)]](http://wpt.live/css/selectors/nth-of-invalid.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/nth-of-invalid.html)
- [nth-of-selector-before.html](https://wpt.fyi/results/css/selectors/nth-of-selector-before.html "css/selectors/nth-of-selector-before.html")
 [[(live
 test)]](http://wpt.live/css/selectors/nth-of-selector-before.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/nth-of-selector-before.html)
- [nth-child-of-attribute-crash.html](https://wpt.fyi/results/css/selectors/invalidation/crashtests/nth-child-of-attribute-crash.html "css/selectors/invalidation/crashtests/nth-child-of-attribute-crash.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/crashtests/nth-child-of-attribute-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/crashtests/nth-child-of-attribute-crash.html)
- [nth-of-namespace-class-invalidation-crash.html](https://wpt.fyi/results/css/selectors/invalidation/nth-of-namespace-class-invalidation-crash.html "css/selectors/invalidation/nth-of-namespace-class-invalidation-crash.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/nth-of-namespace-class-invalidation-crash.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/nth-of-namespace-class-invalidation-crash.html)

The [:nth-child(`An+B` \[of `S`\]?
)] pseudo-class notation represents elements
that are among `An+B`th elements from the list composed of
their [inclusive
siblings](https://dom.spec.whatwg.org/#concept-tree-inclusive-sibling) that match the [selector
list](#selector-list)
`S`, which is a
[\<complex-real-selector-list\>](#typedef-complex-real-selector-list). If `S` is omitted, it
defaults to [\*\|\*].

The `An+B` notation and its interpretation are defined in
[CSS Syntax 3 § 6 The An+B
microsyntax](https://drafts.csswg.org/css-syntax-3/#anb-microsyntax); it
represents any index `i` = `A``n` +
`B` for any non-negative integer `n`.

 For these purposes, the list of elements is
**1-indexed**; that is, the first child of an element has index 1, and
will be matched by [:nth-child(2n+1)], because when `n=0` the
expression evaluates to [1].

For example, this selector could address every other row in a table, and
could be used to alternate the color of paragraph text in a cycle of
four.

Examples:

 :nth-child(even) /* represents the 2nd, 4th, 6th, etc elements
 :nth-child(10n-1) /* represents the 9th, 19th, 29th, etc elements */
 :nth-child(10n+9) /* Same */
 :nth-child(10n+-1) /* Syntactically invalid, and would be ignored */

 The specificity of the
[:nth-child()](#nth-child-pseudo) pseudo-class is the specificity of a single
pseudo-class plus, if `S` is specified, the specificity of
the most specific [complex selector](#complex) in `S`. See [§ 15 Calculating a selector's
specificity](#specificity-rules). Thus
[`S`:nth-child(`An+B`)] and
[:nth-child(`An+B` of `S`)] have the exact
same specificity, although they do differ in behavior (see example
below).

By passing a selector argument, we can
select the Nth element that matches that selector. For example, the
following selector matches the first three "important" list items,
denoted by the [.important] class:

 :nth-child(-n+3 of li.important)

Note that this is different from moving the selector outside of the
function, like:

 li.important:nth-child(-n+3)

This selector instead just selects the first three children if they also
happen to be \"important\" list items.

Here's another example of using the
selector argument, to ensure that zebra-striping a table works
correctly.

Normally, to zebra-stripe a table's rows, an author would use CSS
similar to the following:

 tr {
 background: white;
 }
 tr:nth-child(even) {
 background: silver;
 }

However, if some of the rows are hidden and not displayed, this can
break up the pattern, causing multiple adjacent rows to have the same
background color. Assuming that rows are hidden with the
[\[hidden\]] attribute in HTML, the following CSS would
zebra-stripe the table rows robustly, maintaining a proper alternating
background regardless of which rows are hidden:

 tr {
 background: white;
 }
 tr:nth-child(even of :not([hidden])) {
 background: silver;
 }

#### 13.3.2. [:nth-last-child() pseudo-class]
The [:nth-last-child(`An+B` \[of `S`\]?
)] pseudo-class notation represents
elements that are among `An+B`th elements from the list
composed of their [inclusive
siblings](https://dom.spec.whatwg.org/#concept-tree-inclusive-sibling) that match the [selector
list](#selector-list)
`S`, counting backwards from the end. `S` is
[\<complex-real-selector-list\>](#typedef-complex-real-selector-list). If `S` is omitted, it
defaults to [\*\|\*].

 The specificity of the
[:nth-last-child()](#nth-last-child-pseudo) pseudo-class, like the
[:nth-child()](#nth-child-pseudo) pseudo-class, combines the specificity of a regular
pseudo-class with that of its selector argument `S`. See
[§ 15 Calculating a selector's specificity](#specificity-rules).

The CSS Syntax Module
[\[CSS3SYN\]](#biblio-css3syn "CSS Syntax Module Level 3")
defines the [`An+B`
notation](https://drafts.csswg.org/css-syntax/#anb).

Examples:

 tr:nth-last-child(-n+2) /* represents the two last rows of an HTML table */

 foo:nth-last-child(odd) /* represents all odd foo elements in their parent element,
 counting from the last one */

#### 13.3.3. [:first-child pseudo-class]
Tests

- [first-child.html](https://wpt.fyi/results/css/selectors/first-child.html "css/selectors/first-child.html")
 [[(live
 test)]](http://wpt.live/css/selectors/first-child.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/first-child.html)
- [first-child-last-child.html](https://wpt.fyi/results/css/selectors/invalidation/first-child-last-child.html "css/selectors/invalidation/first-child-last-child.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/first-child-last-child.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/first-child-last-child.html)

The [:first-child] pseudo-class represents an element that
is first among its [inclusive
siblings](https://dom.spec.whatwg.org/#concept-tree-inclusive-sibling). Same as [:nth-child(1)].

Examples: The following selector
represents a
[p](https://html.spec.whatwg.org/multipage/grouping-content.html#the-p-element) element that is the first child of a
[div](https://html.spec.whatwg.org/multipage/grouping-content.html#the-div-element) element:

 div > p:first-child

This selector can represent the `p` inside the `div` of the following
fragment:

 <p> The last P before the note.</p>
 <div class="note">
 <p> The first P inside the note.</p>
 </div>

but cannot represent the second `p` in the following fragment:

 <p> The last P before the note.</p>
 <div class="note">
 <h2> Note </h2>
 <p> The first P inside the note.</p>
 </div>

The following two selectors are usually equivalent:

 * > a:first-child /* a is first child of any element */
 a:first-child /* Same (assuming a is not the root element) */

#### 13.3.4. [:last-child pseudo-class]
Tests

- [child-indexed-during-parse.html](https://wpt.fyi/results/css/selectors/child-indexed-during-parse.html "css/selectors/child-indexed-during-parse.html")
 [[(live
 test)]](http://wpt.live/css/selectors/child-indexed-during-parse.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/child-indexed-during-parse.html)
- [last-child.html](https://wpt.fyi/results/css/selectors/last-child.html "css/selectors/last-child.html")
 [[(live
 test)]](http://wpt.live/css/selectors/last-child.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/last-child.html)

The [:last-child] pseudo-class represents an element that
is last among its [inclusive
siblings](https://dom.spec.whatwg.org/#concept-tree-inclusive-sibling). Same as [:nth-last-child(1)].

Example: The following selector
represents a list item `li` that is the last child of an ordered list
`ol`.

 ol > li:last-child

#### 13.3.5. [:only-child pseudo-class]
Tests

- [child-indexed-during-parse.html](https://wpt.fyi/results/css/selectors/child-indexed-during-parse.html "css/selectors/child-indexed-during-parse.html")
 [[(live
 test)]](http://wpt.live/css/selectors/child-indexed-during-parse.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/child-indexed-during-parse.html)
- [only-child.html](https://wpt.fyi/results/css/selectors/only-child.html "css/selectors/only-child.html")
 [[(live
 test)]](http://wpt.live/css/selectors/only-child.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/only-child.html)

The [:only-child] pseudo-class represents an element that
has no siblings. Same as [:first-child:last-child] or
[:nth-child(1):nth-last-child(1)], but with a lower specificity.

### 13.4. Typed Child-indexed Pseudo-classes

Tests

- [nth-of-type-namespace.html](https://wpt.fyi/results/css/selectors/nth-of-type-namespace.html "css/selectors/nth-of-type-namespace.html")
 [[(live
 test)]](http://wpt.live/css/selectors/nth-of-type-namespace.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/nth-of-type-namespace.html)

The pseudo-classes in this section are similar to the [Child Index
Pseudo-classes](#child-index), but they resolve based on an element's
index **among elements of the same [type (tag name)](#type-selectors)**
in their sibling list.

#### 13.4.1. [:nth-of-type() pseudo-class]
The [:nth-of-type(`An+B`)]
pseudo-class notation represents the same elements that would be matched
by [:nth-child(\|An+B\| of `S`)], where `S`
is a [type selector](#type-selector) and namespace prefix matching the element in question.
For example, when considering whether an HTML
[`img`](https://html.spec.whatwg.org/multipage/embedded-content.html#the-img-element) element matches this
[pseudo-class](#pseudo-class),
the `S` in question is [html\|img] (assuming an
appropriate `html` namespace is declared).

CSS example: This allows an author to
alternate the position of floated images:

 img:nth-of-type(2n+1) { float: right; }
 img:nth-of-type(2n) { float: left; }

 If the type of the element is known ahead of time, this
pseudo-class is equivalent to using
[:nth-child()](#nth-child-pseudo) with a type selector. That is,
[img:nth-of-type(2)] is equivalent to [\*:nth-child(2 of
img)].

#### 13.4.2. [:nth-last-of-type() pseudo-class]
Tests

- [child-indexed-during-parse.html](https://wpt.fyi/results/css/selectors/child-indexed-during-parse.html "css/selectors/child-indexed-during-parse.html")
 [[(live
 test)]](http://wpt.live/css/selectors/child-indexed-during-parse.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/child-indexed-during-parse.html)
- [last-of-type.html](https://wpt.fyi/results/css/selectors/last-of-type.html "css/selectors/last-of-type.html")
 [[(live
 test)]](http://wpt.live/css/selectors/last-of-type.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/last-of-type.html)

The [:nth-last-of-type(`An+B`)] pseudo-class notation represents the same
elements that would be matched by [:nth-last-child(\|An+B\| of
`S`)], where `S` is a [type
selector](#type-selector) and
namespace prefix matching the element in question. For example, when
considering whether an HTML
[`img`](https://html.spec.whatwg.org/multipage/embedded-content.html#the-img-element) element matches this
[pseudo-class](#pseudo-class),
the `S` in question is [html\|img] (assuming an
appropriate `html` namespace is declared).

Example: To represent all `h2`
children of an XHTML `body` except the first and last, one could use the
following selector:

 body > h2:nth-of-type(n+2):nth-last-of-type(n+2)

In this case, one could also use
[:not()](#negation-pseudo), although the selector ends up being just as long:

 body > h2:not(:first-of-type):not(:last-of-type)

#### 13.4.3. [:first-of-type pseudo-class]
Tests

- [first-of-type.html](https://wpt.fyi/results/css/selectors/first-of-type.html "css/selectors/first-of-type.html")
 [[(live
 test)]](http://wpt.live/css/selectors/first-of-type.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/first-of-type.html)
- [negated-always-matches-negated-first-of-type-when-ancestor-changes.html](https://wpt.fyi/results/css/selectors/invalidation/negated-always-matches-negated-first-of-type-when-ancestor-changes.html "css/selectors/invalidation/negated-always-matches-negated-first-of-type-when-ancestor-changes.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/negated-always-matches-negated-first-of-type-when-ancestor-changes.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/negated-always-matches-negated-first-of-type-when-ancestor-changes.html)
- [negated-first-of-type-in-nonsubject-position.html](https://wpt.fyi/results/css/selectors/invalidation/negated-first-of-type-in-nonsubject-position.html "css/selectors/invalidation/negated-first-of-type-in-nonsubject-position.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/negated-first-of-type-in-nonsubject-position.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/negated-first-of-type-in-nonsubject-position.html)
- [negated-is-always-matches-negated-first-of-type-when-ancestor-changes.html](https://wpt.fyi/results/css/selectors/invalidation/negated-is-always-matches-negated-first-of-type-when-ancestor-changes.html "css/selectors/invalidation/negated-is-always-matches-negated-first-of-type-when-ancestor-changes.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/negated-is-always-matches-negated-first-of-type-when-ancestor-changes.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/negated-is-always-matches-negated-first-of-type-when-ancestor-changes.html)
- [negated-is-never-matches-negated-first-of-type-when-ancestor-changes.html](https://wpt.fyi/results/css/selectors/invalidation/negated-is-never-matches-negated-first-of-type-when-ancestor-changes.html "css/selectors/invalidation/negated-is-never-matches-negated-first-of-type-when-ancestor-changes.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/negated-is-never-matches-negated-first-of-type-when-ancestor-changes.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/negated-is-never-matches-negated-first-of-type-when-ancestor-changes.html)
- [negated-negated-first-of-type-when-ancestor-changes.html](https://wpt.fyi/results/css/selectors/invalidation/negated-negated-first-of-type-when-ancestor-changes.html "css/selectors/invalidation/negated-negated-first-of-type-when-ancestor-changes.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/negated-negated-first-of-type-when-ancestor-changes.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/negated-negated-first-of-type-when-ancestor-changes.html)
- [negated-never-matches-negated-first-of-type-when-ancestor-changes.html](https://wpt.fyi/results/css/selectors/invalidation/negated-never-matches-negated-first-of-type-when-ancestor-changes.html "css/selectors/invalidation/negated-never-matches-negated-first-of-type-when-ancestor-changes.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/negated-never-matches-negated-first-of-type-when-ancestor-changes.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/negated-never-matches-negated-first-of-type-when-ancestor-changes.html)
- [of-type-selectors.xhtml](https://wpt.fyi/results/css/selectors/of-type-selectors.xhtml "css/selectors/of-type-selectors.xhtml")
 [[(live
 test)]](http://wpt.live/css/selectors/of-type-selectors.xhtml)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/of-type-selectors.xhtml)

The [:first-of-type] pseudo-class represents the same element
as [:nth-of-type(1)].

Example: The following selector
represents a definition title `dt` inside a definition list `dl`, this
`dt` being the first of its type in the list of children of its parent
element.

 dl dt:first-of-type

It is a valid description for the first two `dt` elements in the
following example but not for the third one:

 <dl>
 <dt>gigogne</dt>
 <dd>
 <dl>
 <dt>fusée</dt>
 <dd>multistage rocket</dd>
 <dt>table</dt>
 <dd>nest of tables</dd>
 </dl>
 </dd>
 </dl>

#### 13.4.4. [:last-of-type pseudo-class]
Tests

- [child-indexed-during-parse.html](https://wpt.fyi/results/css/selectors/child-indexed-during-parse.html "css/selectors/child-indexed-during-parse.html")
 [[(live
 test)]](http://wpt.live/css/selectors/child-indexed-during-parse.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/child-indexed-during-parse.html)
- [negated-always-matches-negated-last-of-type-when-ancestor-changes.html](https://wpt.fyi/results/css/selectors/invalidation/negated-always-matches-negated-last-of-type-when-ancestor-changes.html "css/selectors/invalidation/negated-always-matches-negated-last-of-type-when-ancestor-changes.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/negated-always-matches-negated-last-of-type-when-ancestor-changes.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/negated-always-matches-negated-last-of-type-when-ancestor-changes.html)
- [negated-is-always-matches-negated-last-of-type-when-ancestor-changes.html](https://wpt.fyi/results/css/selectors/invalidation/negated-is-always-matches-negated-last-of-type-when-ancestor-changes.html "css/selectors/invalidation/negated-is-always-matches-negated-last-of-type-when-ancestor-changes.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/negated-is-always-matches-negated-last-of-type-when-ancestor-changes.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/negated-is-always-matches-negated-last-of-type-when-ancestor-changes.html)
- [negated-is-never-matches-negated-last-of-type-when-ancestor-changes.html](https://wpt.fyi/results/css/selectors/invalidation/negated-is-never-matches-negated-last-of-type-when-ancestor-changes.html "css/selectors/invalidation/negated-is-never-matches-negated-last-of-type-when-ancestor-changes.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/negated-is-never-matches-negated-last-of-type-when-ancestor-changes.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/negated-is-never-matches-negated-last-of-type-when-ancestor-changes.html)
- [negated-last-of-type-invalidation.html](https://wpt.fyi/results/css/selectors/invalidation/negated-last-of-type-invalidation.html "css/selectors/invalidation/negated-last-of-type-invalidation.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/negated-last-of-type-invalidation.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/negated-last-of-type-invalidation.html)
- [negated-negated-last-of-type-when-ancestor-changes.html](https://wpt.fyi/results/css/selectors/invalidation/negated-negated-last-of-type-when-ancestor-changes.html "css/selectors/invalidation/negated-negated-last-of-type-when-ancestor-changes.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/negated-negated-last-of-type-when-ancestor-changes.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/negated-negated-last-of-type-when-ancestor-changes.html)
- [negated-never-matches-negated-last-of-type-when-ancestor-changes.html](https://wpt.fyi/results/css/selectors/invalidation/negated-never-matches-negated-last-of-type-when-ancestor-changes.html "css/selectors/invalidation/negated-never-matches-negated-last-of-type-when-ancestor-changes.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/negated-never-matches-negated-last-of-type-when-ancestor-changes.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/negated-never-matches-negated-last-of-type-when-ancestor-changes.html)

The [:last-of-type] pseudo-class represents the same element
as [:nth-last-of-type(1)].

Example: The following selector
represents the last data cell `td` of a table row `tr`.

 tr > td:last-of-type

#### 13.4.5. [:only-of-type pseudo-class]
Tests

- [child-indexed-during-parse.html](https://wpt.fyi/results/css/selectors/child-indexed-during-parse.html "css/selectors/child-indexed-during-parse.html")
 [[(live
 test)]](http://wpt.live/css/selectors/child-indexed-during-parse.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/child-indexed-during-parse.html)
- [only-of-type.html](https://wpt.fyi/results/css/selectors/only-of-type.html "css/selectors/only-of-type.html")
 [[(live
 test)]](http://wpt.live/css/selectors/only-of-type.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/only-of-type.html)

The [:only-of-type] pseudo-class represents the same element
as [:first-of-type:last-of-type].

## 14. Combinators

### 14.1. Descendant combinator (` `)

Tests

- [parse-descendant.html](https://wpt.fyi/results/css/selectors/parsing/parse-descendant.html "css/selectors/parsing/parse-descendant.html")
 [[(live
 test)]](http://wpt.live/css/selectors/parsing/parse-descendant.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/parsing/parse-descendant.html)

At times, authors may want selectors to describe an element that is the
descendant of another element in the document tree (e.g., \"an
[em](https://html.spec.whatwg.org/multipage/text-level-semantics.html#the-em-element) element that is contained within an
[H1](https://html.spec.whatwg.org/multipage/sections.html#the-h1-element) element\"). The [descendant
combinator] expresses such a relationship.

A descendant combinator is whitespace that separates two [compound
selectors](#compound).

A selector of the form [A B] represents an element `B` that is an
arbitrary descendant of some ancestor element `A`.

Examples: For example, consider the
following selector:

 h1 em

It represents an
[em](https://html.spec.whatwg.org/multipage/text-level-semantics.html#the-em-element) element being the descendant of an
[h1](https://html.spec.whatwg.org/multipage/sections.html#the-h1-element) element. It is a correct and valid, but partial,
description of the following fragment:

 <h1>This <span class="myclass">headline
 is <em>very</em> important</span></h1>

The following selector:

 div * p

represents a
[p](https://html.spec.whatwg.org/multipage/grouping-content.html#the-p-element) element that is a grandchild or later descendant of
a
[div](https://html.spec.whatwg.org/multipage/grouping-content.html#the-div-element) element. Note the whitespace on either side of the
\"\*\" is not part of the universal selector; the whitespace is a
combinator indicating that the `div` must be the ancestor of some
element, and that that element must be an ancestor of the `p`. The
following selector, which combines descendant combinators and [attribute
selectors](#attribute-selectors), represents an element that (1) has the
`href` attribute set and (2) is inside a `p` that is itself inside a
`div`:

 div p *[href]

### 14.2. Child combinator (`>`)

Tests

- [parse-child.html](https://wpt.fyi/results/css/selectors/parsing/parse-child.html "css/selectors/parsing/parse-child.html")
 [[(live
 test)]](http://wpt.live/css/selectors/parsing/parse-child.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/parsing/parse-child.html)

A [child combinator] describes a childhood relationship between two elements. A
child combinator is made of the \"greater-than sign\" (U+003E,
[\>]) code point and separates two [compound
selectors](#compound).

Examples: The following selector
represents a
[p](https://html.spec.whatwg.org/multipage/grouping-content.html#the-p-element) element that is child of `body`:

 body > p

The following example combines descendant combinators and child
combinators.

 div ol>li p

It represents a
[p](https://html.spec.whatwg.org/multipage/grouping-content.html#the-p-element) element that is a descendant of an
[li](https://html.spec.whatwg.org/multipage/grouping-content.html#the-li-element) element; the [li] element
must be the child of an
[ol](https://html.spec.whatwg.org/multipage/grouping-content.html#the-ol-element) element; the [ol] element
must be a descendant of a `div`. Notice that the optional white space
around the \"\>\" combinator has been left out.

For information on selecting the first child of an element, please see
the section on the
[:first-child](#first-child-pseudo) pseudo-class above.

### 14.3. Next-sibling combinator (`+`)

Tests

- [insert-sibling-001.html](https://wpt.fyi/results/css/selectors/invalidation/insert-sibling-001.html "css/selectors/invalidation/insert-sibling-001.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/insert-sibling-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/insert-sibling-001.html)
- [insert-sibling-002.html](https://wpt.fyi/results/css/selectors/invalidation/insert-sibling-002.html "css/selectors/invalidation/insert-sibling-002.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/insert-sibling-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/insert-sibling-002.html)
- [insert-sibling-003.html](https://wpt.fyi/results/css/selectors/invalidation/insert-sibling-003.html "css/selectors/invalidation/insert-sibling-003.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/insert-sibling-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/insert-sibling-003.html)
- [insert-sibling-004.html](https://wpt.fyi/results/css/selectors/invalidation/insert-sibling-004.html "css/selectors/invalidation/insert-sibling-004.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/insert-sibling-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/insert-sibling-004.html)
- [sibling.html](https://wpt.fyi/results/css/selectors/invalidation/sibling.html "css/selectors/invalidation/sibling.html")
 [[(live
 test)]](http://wpt.live/css/selectors/invalidation/sibling.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/invalidation/sibling.html)
- [parse-sibling.html](https://wpt.fyi/results/css/selectors/parsing/parse-sibling.html "css/selectors/parsing/parse-sibling.html")
 [[(live
 test)]](http://wpt.live/css/selectors/parsing/parse-sibling.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/parsing/parse-sibling.html)

The [next-sibling combinator] is made of the "plus sign" (U+002B,
[+]) code point that separates two [compound
selectors](#compound). The elements
represented by the two [compound selectors] share
the same parent in the document tree and the element represented by the
first [compound selector] immediately precedes the
element represented by the second one. Non-element nodes (e.g. text
between elements) are ignored when considering the adjacency of
elements.

Examples: The following selector
represents a
[p](https://html.spec.whatwg.org/multipage/grouping-content.html#the-p-element) element immediately following a
[math](https://w3c.github.io/mathml-core/#dfn-math) element:

 math + p

The following selector is conceptually similar to the one in the
previous example, except that it adds an attribute selector --- it adds
a constraint to the
[h1](https://html.spec.whatwg.org/multipage/sections.html#the-h1-element) element, that it must have `class="opener"`:

 h1.opener + h2

### 14.4. Subsequent-sibling combinator (`~`)

The [subsequent-sibling combinator] is made of the \"tilde\" (U+007E,
[\~]) code point that separates two [compound
selectors](#compound). The elements
represented by the two [compound selectors] share
the same parent in the document tree and the element represented by the
first compound selector precedes (not necessarily immediately) the
element represented by the second one.

h1 ~ pre

represents a
[pre](https://html.spec.whatwg.org/multipage/grouping-content.html#the-pre-element) element following an `h1`. It is a correct and
valid, but partial, description of:

 <h1>Definition of the function a</h1>
 <p>Function a(x) has to be applied to all figures in the table.</p>
 <pre>function a(x) = 12x/13.5</pre>

## 15. Calculating a selector's specificity

A selector's [specificity] is calculated for a given element as follows:

- count the number of ID selectors in the selector (= `A`)
- count the number of class selectors, attributes selectors, and
 pseudo-classes in the selector (= `B`)
- count the number of type selectors and pseudo-elements in the selector
 (= `C`)
- ignore the universal selector

If the selector is a [selector
list](#selector-list), this
number is calculated for each selector in the list. For a given matching
process against the list, the specificity in effect is that of the most
specific selector in the list that matches.

A few pseudo-classes provide "evaluation contexts" for other selectors,
and so have their specificity defined specially:

- The specificity of an
 [:is()](#matches-pseudo),
 [:not()](#negation-pseudo), or [:has()](#has-pseudo) pseudo-class is replaced by the specificity of
 the most specific [complex selector](#complex) in its [selector
 list](#selector-list)
 argument.
- Analogously, the specificity of an
 [:nth-child()](#nth-child-pseudo) or
 [:nth-last-child()](#nth-last-child-pseudo) selector is the specificity of the
 pseudo-class itself (counting as one pseudo-class selector) plus the
 specificity of the most specific [complex
 selector](#complex) in its
 [selector list](#selector-list) argument (if any).
- The specificity of a [:where()](#where-pseudo) pseudo-class is replaced by zero.

For example:

- [:is(em, #foo)] has a specificity of (1,0,0)---​like an ID
 selector ([#foo])---​when matched against any of `<em>`,
 `<p id=foo>`, or `<em id=foo>`.
- [.qux:where(em, #foo#bar#baz)] has a specificity of (0,1,0):
 only the [.qux] outside the
 [:where()](#where-pseudo) contributes to selector specificity.
- [:nth-child(even of li, .item)] has a specificity of
 (0,2,0)---​like a class selector ([.item]) plus a
 pseudo-class---​when matched against any of `<li>`, `<ul class=item>`,
 or `<li class=item id=foo>`.
- [:not(em, strong#foo)] has a specificity of (1,0,1)---​like a tag
 selector ([strong]) combined with an ID selector
 ([#foo])---​when matched against any element.

Specificities are compared by comparing the three components in order:
the specificity with a larger `A` value is more specific; if
the two `A` values are tied, then the specificity with a
larger `B` value is more specific; if the two `B`
values are also tied, then the specificity with a larger `C`
value is more specific; if all the values are tied, the two
specificities are equal.

Due to storage limitations, implementations may have limitations on the
size of `A`, `B`, or `C`. If so, values
higher than the limit must be clamped to that limit, and not overflow.

Examples:

 * /* a=0 b=0 c=0 */
 LI /* a=0 b=0 c=1 */
 UL LI /* a=0 b=0 c=2 */
 UL OL+LI /* a=0 b=0 c=3 */
 H1 + *[REL=up] /* a=0 b=1 c=1 */
 UL OL LI.red /* a=0 b=1 c=3 */
 LI.red.level /* a=0 b=2 c=1 */
 #x34y /* a=1 b=0 c=0 */
 #s12:not(FOO) /* a=1 b=0 c=1 */
 .foo :is(.bar, #baz)
 /* a=1 b=1 c=0 */

 Repeated occurrences of the same simple selector are
allowed and do increase specificity.

 The specificity of the styles specified in an HTML
`style` attribute [is described in CSS Style
Attributes](https://www.w3.org/TR/css-style-attr/#interpret).
[\[CSSSTYLEATTR\]](#biblio-cssstyleattr "CSS Style Attributes")

## 16. Grammar

Tests

- [selectors-attr-white-space-001.html](https://wpt.fyi/results/css/selectors/selectors-attr-white-space-001.html "css/selectors/selectors-attr-white-space-001.html")
 [[(live
 test)]](http://wpt.live/css/selectors/selectors-attr-white-space-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/selectors-attr-white-space-001.html)

Selectors are
[parsed](https://drafts.csswg.org/css-syntax-3/#css-parse-something-according-to-a-css-grammar) according to the following grammar:

``` prod
<selector-list> = <complex-selector-list>

<complex-selector-list> = <complex-selector>#
<complex-real-selector-list> = <complex-real-selector>#

<compound-selector-list> = <compound-selector>#

<simple-selector-list> = <simple-selector>#

<relative-selector-list> = <relative-selector>#
<relative-real-selector-list> = <relative-real-selector>#

<complex-selector> = <complex-selector-unit> [ <combinator>? <complex-selector-unit> ]*
<complex-selector-unit> = [ <compound-selector>? <pseudo-compound-selector>* ]!
<complex-real-selector> = <compound-selector> [ <combinator>? <compound-selector> ]*

<relative-selector> = <combinator>? <complex-selector>
<relative-real-selector> = <combinator>? <complex-real-selector>

<compound-selector> = [ <type-selector>? <subclass-selector>* ]!
<pseudo-compound-selector> = <pseudo-element-selector> <pseudo-class-selector>*

<simple-selector> = <type-selector> | <subclass-selector>

<combinator> = '>' | '+' | '~'

<wq-name> = <ns-prefix>? <ident-token>
<ns-prefix> = [ <ident-token> | '*' ]? '|'

<type-selector> = <wq-name> | <ns-prefix>? '*'

<subclass-selector> = <id-selector> | <class-selector> |
 <attribute-selector> | <pseudo-class-selector>

<id-selector> = <hash-token>

<class-selector> = '.' <ident-token>

<attribute-selector> = '[' <wq-name> ']' |
 '[' <wq-name> <attr-matcher> [ <string-token> | <ident-token> ] <attr-modifier>? ']'
<attr-matcher> = [ '~' | '|' | '^' | '$' | '*' ]? '='
<attr-modifier> = i | s

<pseudo-class-selector> = : <ident-token> |
 : <function-token> <any-value> )

<pseudo-element-selector> = : <pseudo-class-selector> | <legacy-pseudo-element-selector>
<legacy-pseudo-element-selector> = : [before | after | first-line | first-letter]
```

In interpreting the above grammar, the following rules apply:

- [(#white-space) White space is forbidden:]

 - Between any of the top-level components of a
 [\<compound-selector\>](#typedef-compound-selector) or
 [\<complex-selector-unit\>](#typedef-complex-selector-unit) (that is, forbidden between the
 [\<type-selector\>](#typedef-type-selector) and
 [\<subclass-selector\>](#typedef-subclass-selector), or between the
 [\<pseudo-element-selector\>](#typedef-pseudo-element-selector) and
 [\<pseudo-class-selector\>](#typedef-pseudo-class-selector), etc).

 - Between *any* of the components of a
 [\<type-selector\>](#typedef-type-selector) or a
 [\<class-selector\>](#typedef-class-selector).

 - Between the \':\'s, or between the \':\' and
 [\<ident-token\>](https://drafts.csswg.org/css-syntax-3/#typedef-ident-token) or
 [\<function-token\>](https://drafts.csswg.org/css-syntax-3/#typedef-function-token), of a
 [\<pseudo-element-selector\>](#typedef-pseudo-element-selector) or a
 [\<pseudo-class-selector\>](#typedef-pseudo-class-selector).

 - Between *any* of the components of a
 [\<wq-name\>](#typedef-wq-name).

 - Between the components of an
 [\<attr-matcher\>](#typedef-attr-matcher).

 - Between the
 [\<compound-selector\>](#typedef-compound-selector) or
 [\<pseudo-compound-selector\>](#typedef-pseudo-compound-selector)s in a
 [\<complex-selector-unit\>](#typedef-complex-selector-unit)

 Whitespace is *required* between two
 [\<complex-selector-unit\>](#typedef-complex-selector-unit)s if the
 [\<combinator\>](#typedef-combinator) between them is omitted. (This
 indicates the descendant combinator is being used.)

- In
 [\<id-selector\>](#typedef-id-selector), the
 [\<hash-token\>](https://drafts.csswg.org/css-syntax-3/#typedef-hash-token)'s value must be an
 [identifier](https://drafts.csswg.org/css-values-4/#css-css-identifier).

- The
 [\<pseudo-class-selector\>](#typedef-pseudo-class-selector) production excludes the
 [\<legacy-pseudo-element-selector\>](#typedef-legacy-pseudo-element-selector) production. (That is,
 [:before](https://drafts.csswg.org/css2/#selectordef-before)/etc must never be parsed as a pseudo-class,
 even if doing so would cause the selector to become valid due to, for
 example, other simple selectors following it.)

 A selector is also subject to a variety of more
specific syntactic constraints, and adherence to the grammar above is
necessary *but not sufficient* for the selector to be considered valid.
See [§ 3.9 Invalid Selectors and Error Handling](#invalid) for
additional rules for parsing selectors.

 In general, a
[\<pseudo-element-selector\>](#typedef-pseudo-element-selector) is only valid if placed at the end of
the last
[\<compound-selector\>](#typedef-compound-selector) in a
[\<complex-selector\>](#typedef-complex-selector). In some circumstances, however, it
can be followed by more
[\<pseudo-element-selector\>]s or
[\<pseudo-class-selector\>](#typedef-pseudo-class-selector)s; but these are specified on a
case-by-case basis. (For example, the [user action
pseudo-classes](#user-action-pseudo-class) are allowed after any
[pseudo-element](#pseudo-element), and the [tree-abiding
pseudo-elements](https://drafts.csswg.org/css-pseudo-4/#tree-abiding) are allowed after the
[::slotted()](https://drafts.csswg.org/css-shadow-1/#selectordef-slotted) pseudo-element.)

The four [Level
2](https://www.w3.org/TR/CSS2/selectors.html#pseudo-element-selectors)
[pseudo-elements](#pseudo-element)
([::before](https://drafts.csswg.org/css-pseudo-4/#selectordef-before),
[::after](https://drafts.csswg.org/css-pseudo-4/#selectordef-after),
[::first-line](https://drafts.csswg.org/css-pseudo-4/#selectordef-first-line), and
[::first-letter](https://drafts.csswg.org/css-pseudo-4/#selectordef-first-letter)) may, for legacy reasons, be written with only a
single \":\" character at their front, making them resemble a
[\<pseudo-class-selector\>](#typedef-pseudo-class-selector).

### 16.1. [\<forgiving-selector-list\>]
For legacy reasons, the general behavior of a selector list is that if
any selector in the list fails to parse (because it uses new or
UA-specific selector features, for instance), the entire selector list
becomes invalid. This can make it hard to write CSS that uses new
selectors and still works correctly in older user agents.

The
[[\<forgiving-selector-list\>](#typedef-forgiving-selector-list)] production instead
parses each selector in the list individually, simply ignoring ones that
fail to parse, so the remaining selectors can still be used.

 Style rules still use the normal, unforgiving selector
list behavior.
[\<forgiving-selector-list\>](#typedef-forgiving-selector-list) is used in
[:is()](#matches-pseudo) and [:where()](#where-pseudo) only. Although it does have some minor
implications on specificity, wrapping a style rule's selector in
[:is()] effectively \"upgrades\" it to
become forgiving, so long as it doesn't contain any pseudo-elements
(which aren't valid in [:is()] or
[:where()]).

Syntactically,
[\<forgiving-selector-list\>](#typedef-forgiving-selector-list) is equivalent to
[`<any-value>`](https://drafts.csswg.org/css-syntax-3/#typedef-any-value)`?`. It is then [parsed as a forgiving
selector
list](#parse-as-a-forgiving-selector-list) to obtain its actual value.

To [parse as a forgiving selector
list] given an input `input`:

1. [Parse a
 list](https://drafts.csswg.org/css-syntax-3/#css-parse-a-comma-separated-list-according-to-a-css-grammar) of
 [\<complex-real-selector\>](#typedef-complex-real-selector)s from `input`, and let
 `selector list` be the result.

2. Remove all failure items from `selector list`, and all
 items that are [invalid
 selectors](#invalid-selector), then return a
 [\<selector-list\>](#typedef-selector-list) representing the remaining items
 in `selector list`. (This might be empty.)

Any items in a
[\<forgiving-selector-list\>](#typedef-forgiving-selector-list) that are invalid (whether explicitly,
by using unknown selectors or syntax, or merely contextually, using
known syntax but in an invalid context) must be treated as having zero
specificity.

[\<forgiving-selector-list\>](#typedef-forgiving-selector-list) is intentionally used only in
[:is()](#matches-pseudo) and [:where()](#where-pseudo), not in any other selector that takes a selector
argument.

## 17. API Hooks

To aid in the writing of specs that use Selectors concepts, this section
defines several API hooks that can be invoked by other specifications.

Are these still necessary now that we
have more rigorous definitions for [match](#match) and [invalid
selector](#invalid-selector)? Nouns are a lot easier to coordinate across
specification than predicates, and details like the exact order of
elements returned from `querySelector` seem to make more sense being
defined in the DOM specification than in Selectors.

### 17.1. Parse A Selector

This section defines how to [parse a selector] from a string
`source`. It returns either a complex selector list, or
failure.

1. Let `selector` be the result of
 [parsing](https://drafts.csswg.org/css-syntax-3/#css-parse-something-according-to-a-css-grammar) `source` as a
 [\<selector-list\>](#typedef-selector-list). If this returns failure, it's an
 [invalid selector](#invalid-selector); return failure.
2. If `selector` is an [invalid
 selector](#invalid-selector) for any other reason (such as, for example,
 containing an undeclared namespace prefix), return failure.
3. Otherwise, return `selector`.

### 17.2. Parse A Relative Selector

This section defines how to [parse a relative
selector] from a string `source`. It returns either a
complex selector list, or failure.

1. Let `selector` be the result of
 [parsing](https://drafts.csswg.org/css-syntax-3/#css-parse-something-according-to-a-css-grammar) `source` as a
 [\<relative-selector-list\>](#typedef-relative-selector-list). If this returns failure, it's an
 [invalid selector](#invalid-selector); return failure.
2. If `selector` is an [invalid
 selector](#invalid-selector) for any other reason (such as, for example,
 containing an undeclared namespace prefix), return failure.
3. Otherwise, return `selector`.

### 17.3. Match a Selector Against an Element

This section defines how to [match a selector against an
element].

APIs using this algorithm must provide a `selector` and an
`element`.

Callers may optionally provide:

- one or more [scoping roots](#scoping-root), for resolving the
 [:scope](#scope-pseudo)
 pseudo-class against.

This algorithm returns either success or failure.

For each [complex selector](#complex)
in the given `selector` (which is taken to be a [list of
complex
selectors](#list-of-simple-selectors)), match the complex selector against
`element`, as described in the following paragraph. If the
matching returns success for any complex selector, then the algorithm
return success; otherwise it returns failure.

To [match a complex selector against an
element], process it [compound
selector](#compound) at a time, in
right-to-left order. This process is defined recursively as follows:

- If any simple selectors in the rightmost compound selector does not
 match the element, return failure.
- Otherwise, if there is only one compound selector in the complex
 selector, return success.
- Otherwise, consider all possible elements that could be related to
 this element by the rightmost
 [combinator](#selector-combinator). If the operation of matching the selector consisting
 of this selector with the rightmost compound selector and rightmost
 combinator removed against any one of these elements returns success,
 then return success. Otherwise, return failure.

### 17.4. Match a Selector Against a Pseudo-element

This section defines how to [match a selector against a
pseudo-element].

APIs using this algorithm must provide a `selector` and a
`pseudo-element`. They may optionally provide the same things
they may optionally provide to the algorithm to [match a selector
against an
element](#match-a-selector-against-an-element).

This algorithm returns success or failure.

For each [complex selector](#complex)
in the given `selector`, if both:

- the rightmost [simple selector](#simple) in the complex selector matches
 `pseudo-element`, and
- the result of running [match a complex selector against an
 element](#match-a-complex-selector-against-an-element) on the remainder of the [complex
 selector](#complex) (with just the
 rightmost simple selector of its rightmost complex selector removed),
 `pseudo-element`'s corresponding element, and any optional
 parameters provided to this algorithm returns success,

then return success.

Otherwise (that is, if this doesn't happen for any of the complex
selectors in `selector`), return failure.

### 17.5. Match a Selector Against a Tree

This section defines how to [match a selector against a
tree].

APIs using this algorithm must provide a selector, and one or more
`root elements` indicating the
[subtrees](https://dom.spec.whatwg.org/#concept-tree) that will be searched by the selector. All of the
`root elements` must share the same
[root](https://dom.spec.whatwg.org/#concept-tree-root), or else calling this algorithm is invalid.

They may optionally provide:

- One or more [scoping roots](#scoping-root) indicating the selector is
 [scoped](#scoped-selector).

- A list of [pseudo-elements](#pseudo-element) that are allowed to show up in the match list. If not
 specified, this defaults to allowing all pseudo-elements.

 (#issue-15f3317f) Only the [tree-abiding
 pseudo-elements](https://drafts.csswg.org/css-pseudo-4/#tree-abiding) are really handled in any way remotely like this.

This algorithm returns a (possibly empty) list of elements.

1. Start with a list of `candidate elements`, which are the
 `root elements` and all of their descendant elements,
 sorted in [shadow-including tree
 order](https://dom.spec.whatwg.org/#concept-shadow-including-tree-order), unless otherwise specified.
2. If [scoping root](#scoping-root) were provided, then remove from the
 `candidate elements` any elements that are not
 [descendants](https://dom.spec.whatwg.org/#concept-tree-descendant) of at least one [scoping
 root].
3. Initialize the `selector match list` to empty.
4. For each `element` in the set of
 `candidate elements`:
 1. If the result of [match a selector against an
 element](#match-a-selector-against-an-element) for `element` and
 `selector` is success, add `element` to
 the `selector match list`.

 2. For each possible pseudo-element associated with
 `element` that is one of the pseudo-elements allowed
 to show up in the match list, if the result of [match a selector
 against a
 pseudo-element](#match-a-selector-against-a-pseudo-element) for the pseudo-element and
 `selector` is success, add the pseudo-element to the
 `selector match list`.

 (#issue-b7f52036) The relative position of
 pseudo-elements in `selector match list` is
 undefined. There's not yet a context that exposes this
 information, but we need to decide on something eventually,
 before something *is* exposed.

## [ Appendix A: Guidance on Mapping Source Documents & Data to an Element Tree]
*This section is informative.*

The element tree structure described by the DOM is powerful and useful,
but generic enough to model pretty much any language that describes
tree-based data (or even graph-based, with a suitable interpretation).

Some languages, like HTML, already have well-defined procedures for
producing a DOM object from a resource. If a given language does not,
such a procedure must be defined in order for Selectors to apply to
documents in that language.

At minimum, the document language must define what maps to the DOM
concept of an \"element\".

The primary one-to-many relationship between nodes---​parent/child in
tree-based structures, element/neighbors in graph-based
structures---​should be reflected as the child nodes of an element.

Other features of the element should be mapped to something that serves
a similar purpose to the same feature in DOM:

type

: If the elements in the document language have some notion of
 \"type\" as a basic distinguisher between different groups of
 elements, it should be reflected as the \"type\" feature.

 If this \"type\" can be separated into a \"basic\" name and a
 \"namespace\" that groups names into higher-level groups, the latter
 should be reflected as the \"namespace\" feature. Otherwise, the
 element shouldn't have a \"namespace\" feature, and the entire name
 should be reflected as the \"type\" feature.

id

: If some aspect of the element functions as a unique identifier
 across the document, it should be mapped to the \"id\" feature.

 While HTML only allows an element to have a single
 ID, this should not be taken as a general restriction. The important
 quality of an ID is that each ID should be associated with a single
 element; a single element can validly have multiple IDs.

classes and attributes
: Aspects of the element that are useful for identifying the element,
 but are not generally unique to elements within a document, should
 be mapped to the \"class\" or \"attribute\" features depending on if
 they're something equivalent to a \"label\" (a string by itself) or
 a \"property\" (a name/value pair)

pseudo-classes and pseudo-elements

: If any elements match any pseudo-classes or have any
 pseudo-elements, that must be explicitly defined.

 (#issue-772ec278) Some pseudo-classes are
 \*syntactical\*, like [:has()](#has-pseudo) and
 [:is()](#matches-pseudo), and thus should always work. Need to indicate
 that somewhere. Probably the structural pseudos always work whenever
 the child list is ordered.

In addition to the above, the document language must define how to match
strings originating from the document, if it differs from Selector's
default; see [§ 3.7 Characters and case sensitivity](#case-sensitive)
for details.

For example,
[JSONSelect](https://github.com/lloyd/JSONSelect) is a library that uses
selectors to extract information from JSON documents.

- The \"elements\" of the JSON document are each array, object, boolean,
 string, number, or null. The array and object elements have their
 contents as children.
- Each element's type is its JS type name: \"array\", \"object\", etc.
- Children of an object have their key as a class.
- Children of an array match the
 [:first-child](#first-child-pseudo),
 [:nth-child()](#nth-child-pseudo), etc pseudo-classes.
- The root object matches [:root](#root-pseudo).
- It additionally defines [:val()] and [:contains()]
 pseudo-classes, for matching boolean/number/string elements with a
 particular value or which contain a particular substring.

This structure is sufficient to allow powerful, compact querying of JSON
documents with selectors.

## [ Appendix B: Obsolete but Required `-webkit-` Parsing Quirks for Web Compat]
Tests

- [webkit-pseudo-element.html](https://wpt.fyi/results/css/selectors/webkit-pseudo-element.html "css/selectors/webkit-pseudo-element.html")
 [[(live
 test)]](http://wpt.live/css/selectors/webkit-pseudo-element.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/selectors/webkit-pseudo-element.html)

*This appendix is normative.*

Due to legacy Web-compat constraints, user agents expecting to parse Web
documents must support the following features:

- [:-webkit-autofill] must be treated as a [legacy selector
 alias](#legacy-selector-alias) of
 [:autofill](#selectordef-autofill).

- All other [pseudo-elements](#pseudo-element) whose names begin with the string "-webkit-" (matched
 [ASCII
 case-insensitively](https://infra.spec.whatwg.org/#ascii-case-insensitive)) and that are not functional notations must be
 treated as valid at parse time. (That is, [::-webkit-asdf] is
 valid at parse time, but [::-webkit-jkl()] is not.) If they're
 not otherwise recognized and supported, they must be treated as
 matching nothing, and are [unknown -webkit-
 pseudo-elements].

 [Unknown -webkit-
 pseudo-elements](#unknown--webkit--pseudo-elements) must be serialized in ASCII lowercase.

 What's this quirk about?

 Selectors have long had a behavior where a single unknown/invalid
 selector invalidates the entire selector list (rather than just
 invalidating the one complex selector it finds itself in). This is
 generally considered a legacy mistake by the WG, but can't be fixed at
 this point, as too many stylesheets depend on this behavior,
 intentionally or not.

 One aspect of this is that use of vendor-specific selectors
 invalidates the entire selector in other user agents that don't
 recognize them, and takes the entire style rule down with it. This has
 been used intentionally in the past---​in the severely-not-recommended
 practice of hiding style rules from some browsers by making them
 invalid in every other browser---​and unintentionally, with people
 styling an element and also applying those styles to a vendor-specific
 pseudo-element (such as the various
 [`input`](https://html.spec.whatwg.org/multipage/input.html#the-input-element)-related pseudos some browsers expose), not
 realizing that this hides the entire rule from other browsers.

 In addition to this more general reasoning, WebKit-derived user
 agents, such as Safari or Chrome, have an additional quirk related to
 their vendor-prefixed pseudo-elements, where any
 [::-webkit-]-prefixed selectors are considered valid at parse
 time. (This is probably a leftover quirk of an early CSS feature,
 since dropped, that intentionally treated all possible pseudo-elements
 as valid at parse time, in anticipation of a feature letting authors
 define their own pseudo-elements.)

 Similar to other legacy quirks, such as those documented in
 [\[QUIRKS\]](#biblio-quirks "Quirks Mode Standard"),
 this particular vendor-specific oddity has become common enough that
 other user agents are seeing sites breaking due to them depending on
 it, accidentally or not. As such, since the quirk is in practical
 terms *required* to render the modern web correctly, specifying it and
 requiring it for all user agents ensures that today's web pages are
 more likely to be correctly rendered in user agents both current and
 future.

 As usual with quirks, however, webpages intentionally relying on this
 will be met with shaming and derision from members of the CSSWG, and
 all right-thinking web developers.

## [ Appendix C: Example Privacy-Preserving [:visited](#visited-pseudo) Restrictions]
Previous attempts to protect user privacy in
[:visited](#visited-pseudo) involved [complex restrictions and
behaviors](https://developer.mozilla.org/en-US/docs/Web/CSS/Privacy_and_the_:visited_selector)
to \"lie\" about whether the link match
[:visited] or
[:link](#link-pseudo), to
reduce the chance that a hostile site could observe what unrelated sites
a user had visited while still allowing
[:visited] to work in all cases and help
the user know what links they'd already clicked. This is ultimately an
arms race that can't be won; there are multiple documented ways to still
extract a user's browsing history even with these mitigations.

This section describes an approach first developed and documented at
<https://github.com/explainers-by-googlers/Partitioning-visited-links-history>,
that partitions a user's browsing history information, to allow
[:visited](#visited-pseudo) to only match links corresponding to navigations that
the site's origin could have observed on its own. With this,
[:visited] can be treated as a normal
pseudo-class, without any of the complex mitigations described above, as
it doesn't expose any information not already theoretically available to
the site, while still preserving as much of the *usefulness* of
[:visited] as possible for the user.

1. Let `visited history` be a
 [set](https://infra.spec.whatwg.org/#ordered-set) containing
 [tuples](https://infra.spec.whatwg.org/#tuple) of three pieces of information:

 - a visited
 [URL](https://url.spec.whatwg.org/#concept-url)

 - an
 [origin](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin) for the site that started a navigation

 - a
 [site](https://html.spec.whatwg.org/multipage/browsers.html#site) for the top-level site containing the frame that
 started the navigation. (This will often be the same as the
 previous, but can differ if the user clicks a link in a iframe,
 for example.)

2. Whenever a navigation is triggered *from within a page*---​e.g., from
 the user clicking a link, or a script on the page initiating a
 navigation---​add an entry to `visited history` recording
 the navigation's destination URL, the origin of the page containing
 the link or script, and the (schemeful) site of the top-level site
 containing that page (which might be the same site as the previous
 origin).

 This allows a site to see
 [:visited](#visited-pseudo) information for links that the user has clicked
 from anywhere in that site's origin. In other words, any `A -> B`
 navigation where the site is A.

 Additionally, add an entry to `visited history` recording
 the destination's URL, the *destination's* origin, and the
 *destination's* site. Do this only for navigations from top-level
 frames or iframes which are same-origin with their top-level frame.

 This allows for a site to see
 [:visited](#visited-pseudo) information about its own pages (which is already
 observable by the site) regardless of what site initiated the
 navigation to that page. In other words, any `A -> B` navigation
 where the site is B.

 Notably, direct navigations triggered by the *user
 agent's* UI, such as typing into the address bar, clicking on
 bookmarks, or dragging a link from another program into the page,
 *do not* add a `visited history` entry. These can, of
 course, still add to the browser's record of visited sites that it
 uses for other purposes, such as suggesting URLs as the user types
 into the URL bar.

3. When determining if a link element should match
 [:link](#link-pseudo)
 or [:visited](#visited-pseudo), only allow it to match
 [:visited] if the link's
 destination, the origin of the page containing the link, and the
 top-level site containing the link match a tuple in
 `visited history`.

The inclusion of both page origin and top-level site prevents several
possible privacy attacks, such as:

- If history entries were *only* keyed by the starting site's URL, a
 tracking site could be embedded in a hidden iframe on multiple sites
 which triggers a navigation to a unique URL for a user on the first
 visit, and then uses many such links on subsequent visits to see which
 one had been visited, effectively becoming a new \"third-party
 cookie\" identifying the user across the web. By keying the history
 entry with the top-level site, this information can't be shared across
 different sites.

- If history entires were *only* keyed by the top-level site's URL, a
 hostile iframe, perhaps included in a page as part of an
 advertisement, could observe what sites were visited from the
 top-level site. By keying the history entry with the link's own site,
 the top-level site's information can't \"leak\" into cross-origin
 iframes.

::: non-normative
## 18. Changes

### 18.1. Changes since the 22 January 2026 Working Draft

Significant changes since the [22 January 2026 Working
Draft](https://www.w3.org/TR/2026/WD-selectors-4-20260122/):

- Updated HTML5 references to point to HTML LS instead

- Fixed explanation of HTML's case-matching rules. Defined the default
 matching of document-supplied strings. ([Issue
 2259](https://github.com/w3c/csswg-drafts/issues/2259))

- Used infra terminology for ascii case insensitivity (
 [Issue13427](https://github.com/w3c/csswg-drafts/pull/13427))

- Responded to review feedback on BCP 47 language codes ([Issue
 13647](https://github.com/w3c/csswg-drafts/issues/13647))

- Added example showing the difference between general
 case-insensitivity and strict ASCII case insensitivity ([Issue
 13645](https://github.com/w3c/csswg-drafts/issues/13645))

- Defined language range as BCP 47 extended language range ([Issue
 13646](https://github.com/w3c/csswg-drafts/issues/13646))

- Changed introductory :lang example from (zh, \"\*-hant\") to (sr,
 \"\*-Cyrl\") ([Issue
 13644](https://github.com/w3c/csswg-drafts/issues/13644))

- Moved the column combinator to Selectors 5

- Clarified that language codes must be well-formed to match ([Issue
 8720](https://github.com/w3c/csswg-drafts/issues/8720))

- Reworded constraints on language ranges ([Issue
 8720](https://github.com/w3c/csswg-drafts/issues/8720))

- Clarified that :picture-in-picture applies to the embedder element,
 not the PiP display ([Issue
 13720](https://github.com/w3c/csswg-drafts/issues/13720))

- Renamed \<an+b\> to \<a-n-plus-b\> ([Issue
 9473](https://github.com/w3c/csswg-drafts/issues/9473))

- Added CanIUse panels ([Issue
 1193](https://github.com/w3c/csswg-drafts/issues/1193))

- Forbade non-valid tags/ranges from ever matching ([Issue
 3022](https://github.com/w3c/csswg-drafts/issues/3022#issuecomment-4568519381))

### 18.2. Changes since the 11 November 2022 Working Draft

Significant changes since the [11 November 2022 Working
Draft](https://www.w3.org/TR/2022/WD-selectors-4-20221111/):

- Defined language range as BCP 47 extended language range ([Issue
 13646](https://github.com/w3c/csswg-drafts/issues/13646))

- Removed the at-risk status from
 [:read-write](#read-write-pseudo) and [:has()](#has-pseudo)

- Added
 [:popover-open](#selectordef-popover-open) pseudo-class. ([Issue
 8637](https://github.com/w3c/csswg-drafts/issues/8637))

- Made [:has()](#has-pseudo) and the selector argument of
 [:nth-child()](#nth-child-pseudo)/[:nth-last-child()](#nth-last-child-pseudo) no longer forgiving. ([Issue
 7676](https://github.com/w3c/csswg-drafts/issues/7676))

- Moved the legacy single-colon pseudo-element syntax into the grammar
 itself. ([Issue
 8122](https://github.com/w3c/csswg-drafts/issues/8122))

- Deferred the
 [:local-link](https://drafts.csswg.org/selectors-5/#local-link-pseudo) pseudo-class to Level 5. ([Issue
 12799](https://github.com/w3c/csswg-drafts/issues/12799))

- Deferred the
 [:interest-source](https://drafts.csswg.org/selectors-5/#selectordef-interest-source) and
 [:interest-target](https://drafts.csswg.org/selectors-5/#selectordef-interest-target) pseudo-classes to Level 5. ([Issue
 12799](https://github.com/w3c/csswg-drafts/issues/12799))

- Deferred the
 [:blank](https://drafts.csswg.org/selectors-5/#blank-pseudo) pseudo-class to Level 5. ([Issue
 12799](https://github.com/w3c/csswg-drafts/issues/12799))

- Deferred the [grid-structural (column)
 selectors](selectors-5#grid-structural-selectors) to Level 5. ([Issue
 12799](https://github.com/w3c/csswg-drafts/issues/12799))

- Deferred the [time-dimensional
 pseudo-classes](selectors-5#time-pseudos) to Level 5. ([Issue
 12799](https://github.com/w3c/csswg-drafts/issues/12799))

### 18.3. Changes since the 7 May 2022 Working Draft

Significant changes since the [7 May 2022 Working
Draft](https://www.w3.org/TR/2022/WD-selectors-4-20220507/):

- Added [:open](#selectordef-open) pseudo-class. ([Issue
 7319](https://github.com/w3c/csswg-drafts/issues/7319), [Issue
 11039](https://github.com/w3c/csswg-drafts/issues/11039))

- Disallowed
 [pseudo-elements](#pseudo-element) from [:has()](#has-pseudo) unless explicitly allowed by the pseudo-element's
 definition. ([Issue
 7463](https://github.com/w3c/csswg-drafts/issues/7463))

- Disallowed nesting of [:has()](#has-pseudo). ([Issue
 7344](https://github.com/w3c/csswg-drafts/issues/7344))

- Defined matching of [::lang(\"\")] and of elements not tagged
 with a language. ([Issue
 6915](https://github.com/w3c/csswg-drafts/issues/6915))

- Untangled the concepts of \"scoped\" and \"relative\" selectors
 completely. ([Issue
 6399](https://github.com/w3c/csswg-drafts/issues/6399))

 - Removed \"absolutize a selector\" as well, and just defined relative
 selector matching in terms of the anchoring element.

- Reverted compound selector limitation on
 [:nth-child()](#nth-child-pseudo). ([Issue
 3760](https://github.com/w3c/csswg-drafts/issues/3760))

- Defined [:-webkit-autofill] [legacy selector
 alias](#legacy-selector-alias). ([Issue
 7474](https://github.com/w3c/csswg-drafts/issues/7474))

### 18.4. Changes since the 21 November 2018 Working Draft

Significant changes since the [21 November 2018 Working
Draft](https://www.w3.org/TR/2018/WD-selectors-4-20181121/):

- Removed the Selector profiles, marked
 [:has()](#has-pseudo) as
 optional and at-risk instead. ([Issue
 3925](https://github.com/w3c/csswg-drafts/issues/3925))
- Added [§ 3.6.4 Sub-pseudo-elements](#sub-pseudo-elements) to define
 [sub-pseudo-elements](#sub-pseudo-element) and related terminology.
- Added [:defined](#defined-pseudo). ([Issue
 2258](https://github.com/w3c/csswg-drafts/issues/2258))
- Added [:modal](#selectordef-modal). ([Issue
 6965](https://github.com/w3c/csswg-drafts/issues/6965))
- Added
 [:fullscreen](#selectordef-fullscreen) and
 [:picture-in-picture](#selectordef-picture-in-picture). ([Issue
 3796](https://github.com/w3c/csswg-drafts/issues/3796))
- Added [:seeking](#selectordef-seeking),
 [:buffering](#selectordef-buffering), and
 [:stalled](#selectordef-stalled) media playback state pseudo-classes. ([Issue
 3821](https://github.com/w3c/csswg-drafts/issues/3821))
- Added [:muted](#selectordef-muted) and
 [:volume-locked](#selectordef-volume-locked) sound state pseudo-classes. ([Issue
 3821](https://github.com/w3c/csswg-drafts/issues/3821) and [Issue
 3933](https://github.com/w3c/csswg-drafts/issues/3933))
- Added
 [:autofill](#selectordef-autofill). ([Issue
 5775](https://github.com/w3c/csswg-drafts/issues/5775))
- Added [:user-valid](#user-valid-pseudo).
 ([Discussion](https://lists.w3.org/Archives/Public/www-style/2015Sep/0111.html))
- Defined [:is()](#matches-pseudo), [:where()](#where-pseudo), [:has()](#has-pseudo),
 [:nth-child()](#nth-child-pseudo), and
 [:nth-last-child()](#nth-last-child-pseudo) to not be themselves invalidated when
 containing an invalid selector. ([Issue
 3264](https://github.com/w3c/csswg-drafts/issues/3264))
- Limited selectors in
 [:nth-child()](#nth-child-pseudo) and
 [:nth-last-child()](#nth-last-child-pseudo) to [compound
 selectors](#compound) for now.
 ([Issue 3760](https://github.com/w3c/csswg-drafts/issues/3760))
- Clarified case-sensitive string matching by referencing string
 identity as defined in
 [\[INFRA\]](#biblio-infra "Infra Standard").
- Clarified that UA-provided placeholder text still triggers
 [:placeholder-shown](#placeholder-shown-pseudo).
- Rewrote
 [:focus-visible](#focus-visible-pseudo) definition for clarity.
- Switched reminder note in the grammar section to normative text
 describing the requirement of whitespace between
 [\<compound-selector\>](#typedef-compound-selector)s when a
 [\<combinator\>](#typedef-combinator) token is missing.

### 18.5. Changes since the 2 February 2018 Working Draft

Significant changes since the [2 February 2018 Working
Draft](https://www.w3.org/TR/2018/WD-selectors-4-20180202/):

- Named the zero-specificity selector to
 [:where()](#where-pseudo). ([Issue
 2143](https://github.com/w3c/csswg-drafts/issues/2143))
- Renamed
 [:matches()](#selectordef-matches) to
 [:is()](#matches-pseudo). ([Issue
 3258](https://github.com/w3c/csswg-drafts/issues/3258))
- Redefined [:empty](#empty-pseudo) to ignore white-space--only nodes. ([Issue
 1967](https://github.com/w3c/csswg-drafts/issues/1967))
- Redefined
 [:blank](https://drafts.csswg.org/selectors-5/#blank-pseudo) to represent empty user input, rather than
 empty elements. ([Issue
 1283](https://github.com/w3c/csswg-drafts/issues/1283))
- Changed the specificity of
 [:is()](#matches-pseudo), [:has()](#has-pseudo), and
 [:nth-child()](#nth-child-pseudo) to not depend on which selector argument matched.
 ([Issue 1027](https://github.com/w3c/csswg-drafts/issues/1027))
- Dropped the [:drop()] pseudo-classes since HTML dropped the
 related feature. ([Issue
 2257](https://github.com/w3c/csswg-drafts/issues/2257))
- Added the case-sensitive flag `s` to the attribute selector. ([Issue
 2101](https://github.com/w3c/csswg-drafts/issues/2101))
- Added further guidance on
 [:focus-visible](#focus-visible-pseudo).
- Added [Appendix B: Obsolete but Required -webkit- Parsing Quirks for
 Web Compat](#compat) defining [::-webkit-] pseudo-element
 parsing quirk. ([Issue
 3051](https://github.com/w3c/csswg-drafts/issues/3051))
- Rewrote grammar rules about where white space is allowed for clarity.
 (See [§ 16 Grammar](#grammar).)

### 18.6. Changes since the 2 May 2013 Working Draft

Significant changes since the [2 May 2013 Working
Draft](https://www.w3.org/TR/2013/WD-selectors4-20130502/) include:

- Added the [:target-within],
 [:focus-within](#focus-within-pseudo),
 [:focus-visible](#focus-visible-pseudo),
 [:playing](#selectordef-playing), and
 [:paused](#selectordef-paused) pseudo-classes.

- Added a zero-specificity
 [:matches()](#selectordef-matches)-type pseudo-class, with name TBD.

- Replaced subject indicator ([!]) feature with
 [:has()](#has-pseudo).

- Replaced the [:nth-match()] and [:nth-last-match()]
 selectors with [:nth-child(... of `selector`)] and
 [:nth-last-child(... of `selector`)].

- Changed the [:active-drop-target], [:valid-drop-target],
 [:invalid-drop-target] with [:drop()].

- Sketched out an empty-or-whitespace-only selector for discussion (See
 [open issue](https://github.com/w3c/csswg-drafts/issues/1967).)

- Renamed [:user-error] to
 [:user-invalid](#user-invalid-pseudo). (See
 [Discussion](https://www.w3.org/mid/CADhPm3v+WfeGQfBwwx8QBuiOjn2k38V_DcKW17Cm81VgZb1nbQ@mail.gmail.com))

- Renamed [:nth-column()]/[:nth-last-column()] to
 [:nth-col()](https://drafts.csswg.org/selectors-5/#nth-col-pseudo)/[:nth-last-col()](https://drafts.csswg.org/selectors-5/#nth-last-col-pseudo) to avoid naming confusion with a potential
 [::column](https://drafts.csswg.org/css-multicol-2/#selectordef-column) pseudo-class.

- Changed the non-functional form of the [:local-link]
 pseudo-class to account for fragment URLs.

- Removed the functional form of the `:local-link()` pseudo-class and
 reference combinator for lack of interest.

- Rewrote selectors grammar using the CSS Value Definition Syntax.

- Split out [relative
 selectors](#relative-selector) from [scoped
 selectors](#scoped-selector), as these are different concepts that can be
 independently invoked.

- Moved definition of
 [\<a-n-plus-b\>](https://drafts.csswg.org/css-syntax-3/#anb-production) microsyntax to CSS Syntax.

 (#issue-fb60ae39) Semantic definition should probably
 move back here.

- Added new sections:
 - [§ 3.2 Data Model](#data-model)

 (#issue-4ca3978c) Need to define tree for XML.

 - [§ 17 API Hooks](#api-hooks)
 - Note that earlier versions of this section defined a section on
 [evaluating a selector], but that section is no longer
 present. Specifications referencing that section should instead
 reference the algorithm to [match a selector against a
 tree](#match-a-selector-against-a-tree).

- Removed restriction on combinators within
 [:matches()](#selectordef-matches) and
 [:not()](#negation-pseudo); see
 [discussion](https://lists.w3.org/Archives/Public/www-style/2014Jan/0607.html).

- Defined [specificity](#specificity) of a [selector
 list](#selector-list).
 (Why?)

- Required quotes around [:lang()](#lang-pseudo) values involving an asterisk; only language
 codes which happen to be CSS identifiers can be used unquoted.

 The 1 February 2018 draft included an inadvertent
commit of unfinished work; 2 February 2018 has reverted this commit (and
fixed some links because why not).

### 18.7. Changes since the 23 August 2012 Working Draft

Significant changes since the [23 August 2012 Working
Draft](https://www.w3.org/TR/2012/WD-selectors4-20120823/) include:

- Added
 [:placeholder-shown](#placeholder-shown-pseudo) pseudo-classes.
- Released some restrictions on
 [:matches()](#selectordef-matches) and
 [:not()](#negation-pseudo).
- Defined fast and complete Selectors profiles (now called "live" and
 "snapshot").
- Improved definition of
 [specificity](#specificity) to
 better handle
 [:matches()](#selectordef-matches).
- Updated grammar.
- Cleaned up definition of
 [\<a-n-plus-b\>](https://drafts.csswg.org/css-syntax-3/#anb-production) notation.
- Added definition of *scope-relative* selectors, changed
 *scope-constrained* to scope-filtered for less confusion with
 scope-contained.
- The [:local-link()] pseudo-class now ignores trailing slashes.

### 18.8. Changes since the 29 September 2011 Working Draft

Significant changes since the [29 September 2011 Working
Draft](https://www.w3.org/TR/2011/WD-selectors4-20110929/) include:

- Added language variant handling per RFC 4647.
- Added scoped selectors.
- Added [:user-error] (now called
 [:user-invalid](#user-invalid-pseudo)).
- Added [:valid-drop-target].
- Changed [column
 combinator](https://drafts.csswg.org/selectors-5/#column-combinator) from double slash to double pipe.

::: non-normative
### 18.9. Changes Since Level 3

Additions since [Selectors Level 3](https://www.w3.org/TR/selectors-3/):

#### 18.9.1. Conditional Logic

- The matches-any [:is](#matches) pseudo-class, formerly called
 :matches(), has been added to allow stylesheet authors to group
 functionally related elements, such as any element that is either
 hovered or focussed.
- The specificity-adjusting [:where()](#zero-matches) pseudo-class has
 been added to construct zero-specificity filters, which are easy to
 override, replacing the many ugly hacks previously required to
 simulate this.

#### 18.9.2. Interaction, Input and Forms

- Added the [:modal](#modal-state) pseudo-class, to select elements
 which exclude interaction with all other elements until dismissed.
- Added [:open](#open-state) and [:popover-open](#popover-open-state)
 pseudo-classes, primarily but not exclusively to use with HTML forms.

*The following selectors were previously in [CSS Basic User Interface
Module Level 3 (CSS3
UI)](https://drafts.csswg.org/css-ui-3/){biblio-display="inline"
} and have been moved to the main Selectors 4
specification for ease of reference.*

- Added the [:valid](#valid-pseudo) and
 [:invalid](#invalid-pseudo) pseudo-classes.
- Added the
 [:user-valid](#user-valid-pseudo) and
 [:user-invalid](#user-invalid-pseudo)
 pseudo-classes. These only match after significant user interaction.
- Added the [:required](#required-pseudo) and
 [:optional](#optional-pseudo) optionality
 pseudo-classes
- Added the [:enabled](#enabled-pseudo) and
 [:disabled](#disabled-pseudo)
 pseudo-classes.
- Added the [:read-only](#read-only-pseudo)
 and [:read-write](#read-write-pseudo)
 mutability pseudo-classes.
- Added the automatic input [:autofill](#autofill) pseudo-class.
- Added the selected-option [:checked](#checked),
 [:unchecked](#unchecked-pseudo) and
 [:indeterminate](#indeterminate-pseudo)
 pseudo-classes.

#### 18.9.3. Hyperlinking Support

- Added [:any-link](#the-any-link-pseudo) to match any element that acts
 as the source anchor of a hyperlink.

#### 18.9.4. Clearer Expression of Authorial Intent

- Expanded the sibling-counting [:nth-child()](#the-nth-child-pseudo)
 and negation [:not()](#negation) pseudo-classes to accept a selector
 list.

#### 18.9.5. Media State

- Added the :playing, :paused and :seeking [media playback
 state](#video-state) pseudo classes, to enable selecting on the
 dynamic state of video elements, functionality which previously
 required JavaScript.
- Added the
 [:buffering](#selectordef-buffering)
 and [:stalled](#selectordef-stalled)
 [media loading state](#media-loading-state) pseudo-classes, again
 providing functionality that previously needed JavaScript,
- Added the [:fullscreen](#fullscreen-state) and
 [:picture-in-picture](#pip-state) pseudo-classes.
- Added the [:muted](#selectordef-muted)
 and
 [:volume-locked](#selectordef-volume-locked)
 pseudo-classes for sound-producing elements.

#### 18.9.6. Internationalization Improvements

- Expanded the content language [:lang()](#the-lang-pseudo) pseudo-class
 to accept wildcard matching, and comma-separated lists of language
 codes, for greater flexibility styling related languages.
- Added the content language writing direction [:dir()](#the-dir-pseudo)
 pseudo-class for convenient styling of left-to-right and right-to-left
 content.
- Clarified case-insensitive string matching.
- General improvements to closely align with BCP 47.

## 19. Acknowledgements

The CSS working group would like to thank everyone who contributed to
the [previous Selectors](https://www.w3.org/TR/css3-selectors)
specifications over the years, as those specifications formed the basis
for this one. In particular, the working group would like to extend
special thanks to the following for their specific contributions to
Selectors Level 4: L. David Baron, Andrew Fedoniouk, Daniel Glazman, Ian
Hickson, Grey Hodge, Lachlan Hunt, Anne van Kesteren, Jason Cranford
Teague, Lea Verou

## [Privacy Considerations]
- The [:visited](#visited-pseudo) pseudo-class can expose information about which
 sites a user has previously visited, if the UA is not careful to
 screen from scripting any information that would reveal which elements
 match it.
- The [:autofill](#selectordef-autofill) pseudo-class can expose whether a user has
 interacted with this form before; however the same information can be
 derived by observing how quickly the form is filled out.

## [Security Considerations]
The [Privacy Considerations](#privacy) could also be considered to
affect Security.
